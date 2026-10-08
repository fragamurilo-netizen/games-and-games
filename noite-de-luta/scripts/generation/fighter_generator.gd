class_name FighterGenerator
extends RefCounted
## Cria lutadores coerentes: país → origem (nome e rosto) → arte marcial de base → atributos
## puxados pela base e pelo físico da categoria → idade, potencial e cartel compatíveis com o
## nível. O nível alvo vem de fora (o gerador do mundo distribui do campeão ao estreante).

const ATTR_MIN := 18.0
const ATTR_MAX := 99.0

static var _nation_keys: Array = []
static var _nation_w: Array = []
static var _nation_w_f: Array = []


static func _prepare_nations() -> void:
	if not _nation_keys.is_empty():
		return
	var n: Dictionary = DataDB.fight_nations()
	for k in n:
		_nation_keys.append(String(k))
		var w := float(n[k]["w"])
		_nation_w.append(w)
		_nation_w_f.append(w * float(n[k].get("fem", 1.0)))


static func pick_nation(rng: RandomNumberGenerator, fem: bool) -> String:
	_prepare_nations()
	return _nation_keys[maxi(0, RngUtil.weighted_index(rng, _nation_w_f if fem else _nation_w))]


static func pick_base(rng: RandomNumberGenerator, nation: String) -> String:
	var t: Dictionary = DataDB.mma().get("base_by_nation", {})
	var w: Dictionary = t.get(nation, t["*"])
	return String(RngUtil.weighted_key(rng, w))


static func _gauss(rng: RandomNumberGenerator, sd: float) -> float:
	return rng.randfn(0.0, sd)


## Altura média por categoria (homens) e por categoria feminina.
const HEIGHT := {"M57": 165, "M61": 169, "M66": 173, "M70": 176, "M77": 180, "M84": 184, "M93": 188, "M120": 192,
	"F52": 161, "F57": 165, "F61": 168, "F66": 171}


## Um lutador da categoria `div` com nível alvo `level` e idade `age_` (0 = sorteia).
## `amateur`: ainda sem luta profissional (prospecto do mercado).
static func make(w: GameWorld, div: String, level: float, age_: int = 0, amateur: bool = false, nation: String = "") -> Fighter:
	var rng := w.rng
	var d := DataDB.division(div)
	var fem := String(d.get("sex", "m")) == "f"
	var f := Fighter.new()
	f.id = w.new_id()
	f.sex = "f" if fem else "m"
	f.division = div
	f.nation = nation if nation != "" else pick_nation(rng, fem)
	var origin := NameGenerator.pick_origin(rng, f.nation)
	f.eth = int(origin["eth"])
	var nm := NameGenerator.generate(rng, String(origin["c"]), _used(w), fem)
	f.first = String(nm["first"])
	f.last = String(nm["last"])
	f.family_first = bool(nm.get("family_first", false))
	var cities: Array = DataDB.cities(f.nation)
	if not cities.is_empty():
		f.city = String((cities[rng.randi_range(0, mini(cities.size() - 1, 14))] as Array)[0])
	f.base = pick_base(rng, f.nation)
	# Idade
	var age := age_
	if age <= 0:
		if amateur:
			age = rng.randi_range(18, 24)
		else:
			# A elite já tem estrada: nível alto pede idade de quem lutou bastante.
			var lo := 21 + int(clampf((level - 62.0) / 5.0, 0.0, 5.0))
			age = clampi(int(round(rng.randfn(29.0 + maxf(0.0, level - 70.0) * 0.08, 4.0))), lo, 40)
	f.birth_month = rng.randi_range(1, 12)
	f.birth_year = w.year() - age - (1 if f.birth_month > w.month() else 0)
	f.peak_age = clampi(int(round(rng.randfn(29.5 + float(d.get("wt", 0.5)) * 1.5, 1.6))), 26, 34)
	# Físico
	var hmean: int = HEIGHT.get(div, 176)
	f.height_cm = clampi(int(round(rng.randfn(hmean, 5.0))), hmean - 14, hmean + 14)
	f.reach_cm = clampi(f.height_cm + int(round(rng.randfn(2.0, 5.0))), f.height_cm - 8, f.height_cm + 16)
	f.southpaw = rng.randf() < (0.24 if f.base in ["boxe", "karate", "kickboxing"] else 0.17)
	var limit := float(d.get("limit_kg", 70.0))
	if div == "M120":
		f.natural_kg = snappedf(limit - rng.randf_range(0.0, 14.0), 0.1)
	else:
		f.natural_kg = snappedf(limit * (1.0 + rng.randf_range(0.04, 0.155)), 0.1)
	_make_attrs(f, rng, level, age, d)
	# Potencial: os jovens ainda têm para onde crescer.
	var gap := 0.0
	if age < 29:
		gap = maxf(0.0, (29.0 - age) * rng.randf_range(0.6, 2.4))
	f.potential = clampf(level + gap + rng.randf_range(0.0, 3.0), level, 96.0)
	# Rosto
	f.face_seed = rng.randi()
	f.look = {"wt": float(d.get("wt", 0.5))}
	if fem:
		f.look["fem"] = 1
	# Cartel e fama
	if amateur:
		f.amateur = {"w": rng.randi_range(2, 11), "l": rng.randi_range(0, 3)}
	else:
		_make_record(f, rng, level, age)
	f.rating = 1000.0 + (level - 44.0) * 17.0 + rng.randfn(0.0, 25.0)
	f.rating += (int(f.record["w"]) - int(f.record["l"])) * 2.0
	f.popularity = clampf((level - 45.0) * 1.3 + int(f.record["w"]) * 0.8 + rng.randf_range(0.0, 10.0), 1.0, 90.0)
	if not amateur and rng.randf() < clampf(0.25 + (level - 50.0) / 80.0, 0.2, 0.75):
		f.nickname = _nickname(w, rng, String(origin["c"]))
	f.condition = rng.randf_range(88.0, 100.0)
	if f.is_pro():
		f.last_fight_week = w.week - rng.randi_range(2, 22)
	f.wear = maxf(0.0, f.fights() * rng.randf_range(0.02, 0.06))
	return f


static func _used(w: GameWorld) -> Dictionary:
	if not w.has_meta(&"used_names"):
		var u := {}
		for f: Fighter in w.fighters.values():
			u[f.first + " " + f.last] = true
		w.set_meta(&"used_names", u)
	return w.get_meta(&"used_names")


static func _nickname(w: GameWorld, rng: RandomNumberGenerator, culture: String) -> String:
	var m: Dictionary = DataDB.mma()
	var lang := String((m.get("nick_lang", {}) as Dictionary).get(NameGenerator.base_culture(culture), "en"))
	# Muita gente de fora usa apelido em inglês no MMA.
	if lang != "en" and rng.randf() < 0.3:
		lang = "en"
	var pool: Array = (m.get("nicknames", {}) as Dictionary).get(lang, [])
	if pool.is_empty():
		return ""
	var counts: Dictionary = w.get_meta(&"nick_counts") if w.has_meta(&"nick_counts") else {}
	for _i in 6:
		var n := String(pool[rng.randi_range(0, pool.size() - 1)])
		if int(counts.get(n, 0)) < 2:
			counts[n] = int(counts.get(n, 0)) + 1
			w.set_meta(&"nick_counts", counts)
			return n
	return ""


## Atributos: nível alvo + viés da arte marcial + físico da categoria + pontos fortes e fracos
## individuais; depois um ajuste para o nível calculado bater com o alvo.
static func _make_attrs(f: Fighter, rng: RandomNumberGenerator, level: float, age: int, d: Dictionary) -> void:
	var bias: Dictionary = ((DataDB.mma()["bases"] as Dictionary).get(f.base, {}) as Dictionary).get("attrs", {})
	var wt := float(d.get("wt", 0.5))
	var ko := float(d.get("ko", 1.0))
	var at := {}
	for k: String in Fighter.ATTRS:
		at[k] = level + float(bias.get(k, 0.0)) * rng.randf_range(0.6, 1.15) + _gauss(rng, 5.5)
	# Físico pela categoria: pesados batem mais forte e cansam mais; leves são rápidos.
	at["potencia"] += (ko - 1.0) * 22.0
	at["velocidade"] -= (wt - 0.5) * 14.0
	at["cardio"] -= (wt - 0.5) * 10.0
	at["forca"] += (wt - 0.5) * 8.0
	at["movimentacao"] -= (wt - 0.5) * 6.0
	# Pontos fortes e fracos de cada um.
	var keys: Array = Fighter.ATTRS.duplicate()
	for _i in 2:
		var k: String = keys[rng.randi_range(0, keys.size() - 1)]
		at[k] += rng.randf_range(6.0, 14.0)
	for _i in 2:
		var k: String = keys[rng.randi_range(0, keys.size() - 1)]
		at[k] -= rng.randf_range(5.0, 13.0)
	# Idade: o jovem ainda não lê a luta; o veterano perdeu velocidade e fôlego.
	if age < 24:
		at["qi"] -= (24 - age) * 2.0
	if age > 32:
		var dec := float(age - 32)
		at["velocidade"] -= dec * 1.8
		at["cardio"] -= dec * 1.2
		at["queixo"] -= dec * 1.0
		at["qi"] += dec * 1.0
	for k: String in at:
		at[k] = clampf(at[k], ATTR_MIN, ATTR_MAX)
	f.attrs = at
	# Ajuste fino: desloca tudo até o nível calculado ficar perto do alvo.
	for _i in 4:
		var diff := level - float(f.level())
		if absf(diff) < 0.6:
			break
		for k: String in at:
			at[k] = clampf(float(at[k]) + diff, ATTR_MIN, ATTR_MAX)
	for k: String in at:
		at[k] = roundf(float(at[k]))
	f.attrs = at


## Cartel coerente com idade e nível: mais lutas para quem é mais velho, mais vitórias para
## quem é melhor; os métodos seguem o estilo (pancadeiro nocauteia, faixa-preta finaliza).
static func _make_record(f: Fighter, rng: RandomNumberGenerator, level: float, age: int) -> void:
	var debut := rng.randi_range(19, 25)
	var years := maxf(0.4, age - debut + rng.randf())
	var n := maxi(1, int(round(years * rng.randf_range(1.6, 3.0))))
	n = maxi(n, int((level - 60.0) / 2.0))
	n = mini(n, 42)
	var p := clampf(0.36 + 0.62 * pow(clampf((level - 42.0) / 46.0, 0.0, 1.0), 0.85), 0.3, 0.93)
	var rec := {"w": 0, "l": 0, "d": 0, "nc": 0, "ko_w": 0, "sub_w": 0, "dec_w": 0, "ko_l": 0, "sub_l": 0, "dec_l": 0}
	var ko_share := clampf(0.18 + (f.a("potencia") - 55.0) / 90.0 + (f.a("maos") + f.a("chutes") - 110.0) / 300.0, 0.08, 0.6)
	var sub_share := clampf(0.1 + (f.a("finalizacao") - 55.0) / 80.0, 0.03, 0.55)
	if f.is_female():
		ko_share *= 0.55
	var streak := 0
	for i in n:
		var r := rng.randf()
		if r < 0.012:
			rec["d"] += 1
			streak = 0
			continue
		if rng.randf() < p:
			rec["w"] += 1
			streak = streak + 1 if streak >= 0 else 1
			var m := rng.randf()
			if m < ko_share:
				rec["ko_w"] += 1
			elif m < ko_share + sub_share:
				rec["sub_w"] += 1
			else:
				rec["dec_w"] += 1
		else:
			rec["l"] += 1
			streak = streak - 1 if streak <= 0 else -1
			var m2 := rng.randf()
			if m2 < (0.32 if not f.is_female() else 0.18) + (55.0 - f.a("queixo")) / 200.0:
				rec["ko_l"] += 1
			elif m2 < 0.55:
				rec["sub_l"] += 1
			else:
				rec["dec_l"] += 1
	f.record = rec
	f.streak = streak
	f.amateur = {"w": rng.randi_range(2, 9), "l": rng.randi_range(0, 3)}
