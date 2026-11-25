class_name Bio
extends RefCounted
## A vida de cada lutador: de onde veio (cidade e região pela cultura), como começou, o que fazia
## antes, o que o move, uma mania, o dom raro (quando tem) e a linha do tempo da carreira (das
## lutas de antes do jogo e das de dentro). Os textos saem de `data/world/bio.json` e da semente
## do lutador: nada vai para o save além do dom (`Fighter.gift`) e da cidade.

static var _doc: Dictionary = {}
static var _region_of: Dictionary = {}


static func doc() -> Dictionary:
	if _doc.is_empty():
		var f := FileAccess.open("res://data/world/bio.json", FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_doc = parsed if parsed is Dictionary else {"homes": {}}
	return _doc


static func _rng(f: Fighter, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%d:%s" % [f.id, f.face_seed, salt])
	return r


## A cultura de nome do lutador ("dag", "us"...; a de casa em "us+dag").
static func culture(f: Fighter) -> String:
	return String(f.look.get("cu", "")).split("+")[0]


static func family_culture(f: Fighter) -> String:
	var c := String(f.look.get("cu", "")).split("+")
	return String(c[1]) if c.size() > 1 and String(c[1]) != "m" else ""


# --- Terra ---------------------------------------------------------------------------------

## Cidade natal de quem tem a cultura `cult` no país `nation` ("" = a lista comum do país).
static func home(rng: RandomNumberGenerator, nation: String, cult: String) -> String:
	var h: Dictionary = ((doc().get("homes", {}) as Dictionary).get(nation, {}) as Dictionary).get(cult.split("+")[0], {})
	var cities: Array = h.get("cities", [])
	if cities.is_empty():
		return ""
	# As primeiras da lista são as maiores: saem mais.
	var i := int(floor(pow(rng.randf(), 1.6) * float(cities.size())))
	return String(cities[clampi(i, 0, cities.size() - 1)])


static func region(f: Fighter) -> String:
	var key := f.nation + ":" + f.city
	if _region_of.has(key):
		return _region_of[key]
	var out := ""
	var homes: Dictionary = (doc().get("homes", {}) as Dictionary).get(f.nation, {})
	for c: String in homes:
		if ((homes[c] as Dictionary).get("cities", []) as Array).has(f.city):
			out = String((homes[c] as Dictionary).get("region", ""))
			break
	if out == "":
		for c: Array in DataDB.cities(f.nation):
			if String(c[0]) == f.city and c.size() > 2:
				out = String(c[2])
				break
	_region_of[key] = out
	return out


## "Grozny, Chechênia" ou "Recife, Nordeste" ou só a cidade.
static func hometown(f: Fighter) -> String:
	var r := region(f)
	if f.city == "":
		return DataDB.nation_name(f.nation)
	return "%s, %s" % [f.city, r] if r != "" else f.city


## "chechena" para quem tem nome de uma cultura que não é a do país (a família veio de fora).
static func heritage(f: Fighter) -> String:
	var her: Dictionary = doc().get("heritage", {})
	var fam := family_culture(f)
	if fam != "" and her.has(fam):
		return String(her[fam])
	var c := culture(f)
	var main := ""
	var best := -1.0
	for o: Dictionary in DataDB.origins(f.nation):
		if float(o.get("w", 0.0)) > best and not o.has("h"):
			best = float(o["w"])
			main = String(o["c"])
	# Dentro do próprio país (o daguestanês na Rússia) a terra já diz tudo.
	if c == "" or c == main or not her.has(c) or ((doc().get("homes", {}) as Dictionary).get(f.nation, {}) as Dictionary).has(c):
		return ""
	return String(her[c])


# --- Raridades -----------------------------------------------------------------------------

static func gift(f: Fighter) -> Dictionary:
	if f.gift == "":
		return {}
	return (doc().get("gifts", {}) as Dictionary).get(f.gift, {})


static func gift_name(f: Fighter) -> String:
	return String(gift(f).get("name", ""))


## Uma arte rara para o país dele, de vez em quando ("" = segue a escola da terra).
static func rare_base(rng: RandomNumberGenerator, fem: bool) -> String:
	if rng.randf() >= float(doc().get("rare_base_chance", 0.0)):
		return ""
	var w := {}
	var table: Dictionary = doc().get("rare_bases", {})
	for k: String in table:
		var m := float(Styles.base(k).get("fem", 1.0)) if fem else 1.0
		if m > 0.0:
			w[k] = float(table[k]) * m
	return "" if w.is_empty() else String(RngUtil.weighted_key(rng, w))


## Sorteia o dom (ou nenhum) e soma os pontos dele aos atributos e ao teto.
static func roll_gift(rng: RandomNumberGenerator, f: Fighter) -> void:
	if rng.randf() >= float(doc().get("gift_chance", 0.0)):
		return
	var fam := Styles.family(f.base)
	var w := {}
	var gifts: Dictionary = doc().get("gifts", {})
	for k: String in gifts:
		var need := String((gifts[k] as Dictionary).get("fam", ""))
		if need == "" or need == fam or fam == "completa":
			w[k] = float((gifts[k] as Dictionary).get("w", 1.0))
	if w.is_empty():
		return
	f.gift = String(RngUtil.weighted_key(rng, w))
	var g: Dictionary = gifts[f.gift]
	for a: String in (g.get("attrs", {}) as Dictionary):
		f.attrs[a] = clampf(float(f.attrs.get(a, 50.0)) + float(g["attrs"][a]), 20.0, 99.0)
	f.potential = clampf(maxf(f.potential, float(f.level())) + float(g.get("potential", 0.0)), 0.0, 97.0)


# --- Vida ----------------------------------------------------------------------------------

static func _fill(t: String, f: Fighter, age: int) -> String:
	var fem := f.is_female()
	return t.format({"age": age, "city": f.city if f.city != "" else DataDB.nation_name(f.nation), "art": Styles.name(f.base).to_lower(),
		"o": "a" if fem else "o", "ao": "ã" if fem else "ão"})


## De três a cinco frases curtas sobre ele: terra, começo, a vida antes, o que o move, a mania.
static func lines(w: GameWorld, f: Fighter) -> Array:
	var d := doc()
	var rng := _rng(f, "vida")
	var out: Array = []
	var fem := f.is_female()
	var her := heritage(f)
	var born := "Nascid%s em %s" % ["a" if fem else "o", hometown(f)]
	out.append("%s, de família %s." % [born, her] if her != "" else born + ".")
	# Como começou: a frase da cultura quando a arte bate, senão a da arte.
	var st: Dictionary = (d.get("start", {}) as Dictionary).get(f.base, (d.get("start", {}) as Dictionary).get("*", {}))
	var sc: Dictionary = (d.get("start_by_culture", {}) as Dictionary).get(culture(f), {})
	if not sc.is_empty() and (sc.get("arts", []) as Array).has(f.base) and rng.randf() < 0.75:
		st = sc
	var ages: Array = st.get("age", [10, 16])
	var debut := debut_age(w, f)
	var age := mini(rng.randi_range(int(ages[0]), int(ages[1])), maxi(5, debut - 2))
	var ls: Array = st.get("lines", [])
	if not ls.is_empty():
		out.append(_fill(String(ls[rng.randi() % ls.size()]), f, age))
	var jobs: Array = d.get("jobs", [])
	if not jobs.is_empty() and rng.randf() < 0.6:
		out.append(_fill(String(jobs[rng.randi() % jobs.size()]), f, age))
	var drive: Array = d.get("drive", [])
	var quirk: Array = d.get("quirk", [])
	var r := rng.randf()
	if not drive.is_empty() and r < 0.7:
		out.append(_fill(String(drive[rng.randi() % drive.size()]), f, age))
	if not quirk.is_empty() and (r >= 0.45 or out.size() < 3):
		out.append(_fill(String(quirk[rng.randi() % quirk.size()]), f, age))
	return out


## Idade na estreia profissional (a de hoje para quem ainda é amador).
static func debut_age(w: GameWorld, f: Fighter) -> int:
	var past := PastFights.of(w, f)
	var wk := w.week
	if not past.is_empty():
		wk = int((past[0] as Dictionary)["week"])
	elif not f.history.is_empty():
		wk = int((f.history[0] as Dictionary)["week"])
	var dt := GameWorld.date_of(wk)
	return f.age(int(dt["year"]), int(dt["month"]))


## Os momentos da carreira, do mais antigo para o mais novo: [{week, year, title, text, tone}]
## (tone: "gold" cinturão, "good", "bad", "").
static func timeline(w: GameWorld, f: Fighter) -> Array:
	var all: Array = PastFights.of(w, f).duplicate()
	all.append_array(f.history)
	var out: Array = []
	if all.is_empty():
		return out
	var add := func(h: Dictionary, title: String, text: String, tone: String) -> void:
		out.append({"week": int(h["week"]), "year": int(GameWorld.date_of(int(h["week"]))["year"]), "title": title, "text": text, "tone": tone})
	var how := func(h: Dictionary) -> String:
		var t := String(h.get("detail", ""))
		if not String(h.get("method", "")) in ["DEC", "EMP"]:
			t += ", %dº round" % int(h.get("round", 1))
		return t
	var first: Dictionary = all[0]
	var verb: String = {"V": "Vence", "D": "Perde para", "E": "Empata com"}.get(String(first["res"]), "Enfrenta")
	add.call(first, "Estreia profissional", "%s %s por %s. %s." % [verb, String(first["opp_name"]), how.call(first), String(first.get("event", ""))], "")
	var streak := 0
	var best := 0
	var best_end := -1
	var first_loss := false
	var belts := 0
	var top := -1
	var top_w := -1
	for i in all.size():
		var h: Dictionary = all[i]
		var res := String(h["res"])
		if res == "V":
			streak += 1
			if streak > best:
				best = streak
				best_end = i
			if bool(h.get("title", false)):
				belts += 1
				if belts == 1:
					add.call(h, "Campe%s" % ("ã" if f.is_female() else "ão"), "Conquista o cinturão contra %s: %s. %s." % [String(h["opp_name"]), how.call(h), String(h.get("event", ""))], "gold")
			elif i > 0 and h.has("opp_rec"):
				var ow := int(String(h["opp_rec"]).split("-")[0])
				if ow > top_w and int(h.get("tier", 0)) >= 1:
					top_w = ow
					top = i
		else:
			if res == "D":
				if not first_loss and i >= 3:
					add.call(h, "Primeira derrota", "Cai para %s: %s." % [String(h["opp_name"]), how.call(h)], "bad")
				first_loss = true
				if bool(h.get("dethroned", false)) or (bool(h.get("title", false)) and belts > 0):
					add.call(h, "Perde o cinturão", "%s leva o título: %s." % [String(h["opp_name"]), how.call(h)], "bad")
			streak = 0
	if belts > 1:
		var last_def: Dictionary = {}
		for h: Dictionary in all:
			if bool(h.get("title", false)) and String(h["res"]) == "V":
				last_def = h
		add.call(last_def, "%d defesas de cinturão" % (belts - 1), "A mais recente contra %s." % String(last_def["opp_name"]), "gold")
	if top >= 0 and belts == 0:
		var h2: Dictionary = all[top]
		add.call(h2, "A maior vitória", "Bate %s (%s): %s." % [String(h2["opp_name"]), String(h2["opp_rec"]), how.call(h2)], "good")
	if best >= 4:
		add.call(all[best_end], "%d vitórias seguidas" % best, "A maior sequência da carreira.", "good")
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["week"]) < int(b["week"]))
	return out
