class_name PastFights
extends RefCounted
## As lutas de antes do jogo: o cartel com que cada lutador chega (`Fighter.record` menos o que já
## está em `history`) vira uma lista de lutas com adversário, evento, data, método e round.
##
## Nada disso vai para o save: a lista sai sempre igual da semente do lutador, e o que amarra a
## data e a sequência é o que ele tinha ao estrear no jogo (`pre_week`, `pre_streak`, guardados
## na primeira luta dentro do jogo). Os adversários são gente de fora do mundo do jogo (nome e
## cartel da época), então a linha não abre ficha.
##
## Cada item tem as mesmas chaves de `Fighter.history` mais `past` (true), `opp_rec` e `opp` -1.

const KO_HOW := ["direto", "gancho", "cruzado", "uppercut", "overhand", "chute alto", "joelhada", "cotovelada", "joelhada voadora"]
const SUB_W := {"mata_leao": 30, "guilhotina": 18, "chave_braco": 16, "triangulo": 12, "kimura": 7, "katagatame": 6, "darce": 4, "americana": 3, "chave_calcanhar": 3, "anaconda": 1}

static var _cache: Dictionary = {}


## Quantas lutas ele tinha antes do jogo, por resultado e método.
static func counts(f: Fighter) -> Dictionary:
	var c := {"ko_w": int(f.record["ko_w"]), "sub_w": int(f.record["sub_w"]), "dec_w": int(f.record["dec_w"]),
		"ko_l": int(f.record["ko_l"]), "sub_l": int(f.record["sub_l"]), "dec_l": int(f.record["dec_l"]),
		"d": int(f.record["d"]), "nc": int(f.record.get("nc", 0))}
	for h: Dictionary in f.history:
		var res := String(h.get("res", ""))
		var m := String(h.get("method", ""))
		var kind := "ko" if m in ["KO", "TKO"] else ("sub" if m == "FIN" else "dec")
		if res == "V":
			c[kind + "_w"] -= 1
		elif res == "D":
			c[kind + "_l"] -= 1
		elif res == "E":
			c["d"] -= 1
		else:
			c["nc"] -= 1
	for k: String in c:
		c[k] = maxi(0, int(c[k]))
	return c


static func total(f: Fighter) -> int:
	var n := 0
	var c := counts(f)
	for k: String in c:
		n += int(c[k])
	return n


## A lista, da mais antiga para a mais nova.
static func of(w: GameWorld, f: Fighter) -> Array:
	if f == null or f.fights() <= f.history.size():
		return []
	var c := counts(f)
	var key := "%d|%s|%d|%d|%d" % [f.id, str(c.values()), f.pre_week, f.last_fight_week if f.history.is_empty() else 0, f.history.size()]
	var hit: Dictionary = _cache.get(f.id, {})
	if String(hit.get("key", "")) == key:
		return hit["list"]
	var list := _build(w, f, c)
	if _cache.size() > 400:
		_cache.clear()
	_cache[f.id] = {"key": key, "list": list}
	return list


## A última luta dele, de dentro ou de antes do jogo ({} se nunca lutou).
static func last(w: GameWorld, f: Fighter) -> Dictionary:
	if not f.history.is_empty():
		return f.history.back()
	var l := of(w, f)
	return {} if l.is_empty() else l.back()


static func _rng(f: Fighter, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d:%d:%d:passado" % [f.id, f.face_seed, salt])
	return r


static func _build(w: GameWorld, f: Fighter, c: Dictionary) -> Array:
	var rng := _rng(f, 0)
	# 1. Os resultados, embaralhados, com o fim acertado pela sequência com que ele chegou.
	var outs: Array = []
	for k: String in ["ko_w", "sub_w", "dec_w"]:
		for i in int(c[k]):
			outs.append(["V", k.left(k.length() - 2)])
	for k: String in ["ko_l", "sub_l", "dec_l"]:
		for i in int(c[k]):
			outs.append(["D", k.left(k.length() - 2)])
	for i in int(c["d"]):
		outs.append(["E", "dec"])
	for i in int(c["nc"]):
		outs.append(["SR", "nc"])
	var n := outs.size()
	if n == 0:
		return []
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Array = outs[i]
		outs[i] = outs[j]
		outs[j] = tmp
	# Derrota pesa mais no começo e no fim da carreira; quem chega em alta ganhou as últimas.
	var streak := f.pre_streak if not f.history.is_empty() else f.streak
	if f.history.is_empty() or f.pre_week > -900:
		_fix_tail(outs, streak)
	# 2. Quantas valeram cinturão: as últimas vitórias de quem chegou campeão.
	var belts := f.titles_won + f.title_defenses
	for h: Dictionary in f.history:
		if bool(h.get("title", false)) and String(h.get("res", "")) == "V":
			belts -= 1
	# 3. Até onde ele chegou antes do jogo (regional, continental, liga).
	var wins := int(c["ko_w"]) + int(c["sub_w"]) + int(c["dec_w"])
	var rate := float(wins) / float(n)
	var peak := 0
	if belts > 0 or (wins >= 9 and rate >= 0.7):
		peak = 2
	elif wins >= 5 and rate >= 0.55:
		peak = 1
	# 4. As datas, de trás para a frente.
	var end_w := f.last_fight_week if f.history.is_empty() else f.pre_week
	if end_w < -900:
		end_w = (int((f.history[0] as Dictionary).get("week", 0)) if not f.history.is_empty() else w.week) - rng.randi_range(8, 22)
	var gaps: Array = []
	var span := 0
	for i in n - 1:
		var g := rng.randi_range(11, 26)
		if rng.randf() < 0.12:
			g += rng.randi_range(14, 40)
		gaps.append(g)
		span += g
	# Ninguém estreia no profissional antes dos 18.
	var w18 := _week_of_age(f, 18)
	if n > 1 and end_w - span < w18:
		var k := maxf(0.2, float(maxi(n * 5, end_w - w18)) / float(span))
		for i in gaps.size():
			gaps[i] = maxi(4, int(float(gaps[i]) * k))
	var weeks: Array = []
	weeks.resize(n)
	var wk := end_w
	for i in range(n - 1, -1, -1):
		weeks[i] = wk
		if i > 0:
			wk -= int(gaps[i - 1])
	# 5. Cada luta.
	var fem := f.is_female()
	var used := {f.display_name(): true}
	var short := w.league_short()
	var confed := String(DataDB.nation(f.nation).get("confed", "UEFA"))
	var cont := String((DataDB.mma()["continental"] as Dictionary).get(confed, "Circuito Continental"))
	var pats: Array = DataDB.mma()["regional_patterns"]
	var home := f.city if f.city != "" else DataDB.nation_name(f.nation)
	var list: Array = []
	var belt_left := belts
	# As lutas de cinturão são as últimas vitórias, uma a uma, de trás para a frente.
	var title_idx := {}
	for i in range(n - 1, -1, -1):
		if belt_left <= 0:
			break
		if String(outs[i][0]) == "V":
			title_idx[i] = true
			belt_left -= 1
		elif String(outs[i][0]) == "D":
			break
	for i in n:
		var res := String(outs[i][0])
		var kind := String(outs[i][1])
		var p := float(i) / float(n)
		var tier := 0
		if peak == 2:
			tier = 2 if (p >= 0.62 or title_idx.has(i)) else (1 if p >= 0.3 else 0)
		elif peak == 1:
			tier = 1 if p >= 0.5 else 0
		var title := title_idx.has(i)
		var rounds := 5 if title else 3
		var method := "DEC"
		var detail := ""
		var rd := rounds
		var tm := 300.0
		if res == "SR":
			method = "SR"
			detail = ["sem resultado (dedo no olho)", "sem resultado (golpe ilegal)", "sem resultado (choque de cabeças)"][rng.randi() % 3]
			rd = rng.randi_range(1, 2)
			tm = rng.randf_range(40.0, 280.0)
		elif res == "E":
			method = "EMP"
			detail = "empate"
		elif kind == "dec":
			var r := rng.randf()
			detail = "decisão unânime" if r < 0.68 else ("decisão dividida" if r < 0.9 else "decisão majoritária")
		else:
			rd = _round(rng, rounds)
			tm = rng.randf_range(18.0, 296.0)
			if kind == "ko":
				var r2 := rng.randf()
				if r2 < 0.5:
					method = "KO"
					detail = "nocaute (%s)" % String(KO_HOW[rng.randi() % KO_HOW.size()])
				else:
					method = "TKO"
					detail = "nocaute técnico (socos)" if r2 < 0.72 else ("nocaute técnico (socos no chão)" if r2 < 0.93 else ("interrupção médica (corte)" if r2 < 0.97 else "chutes nas pernas"))
			else:
				method = "FIN"
				detail = "finalização (%s)" % String(Styles.sub(String(RngUtil.weighted_key(rng, SUB_W)))["name"])
		# Adversário: no começo, gente da terra; mais para cima, do mundo todo.
		var nat := f.nation if rng.randf() < [0.78, 0.4, 0.12][tier] else FighterGenerator.pick_nation(rng, fem)
		var origin := NameGenerator.pick_origin(rng, nat, fem)
		var nm := NameGenerator.generate(rng, String(origin["c"]), used, fem)
		var opp_name := (String(nm["last"]) + " " + String(nm["first"])) if bool(nm.get("family_first", false)) else (String(nm["first"]) + " " + String(nm["last"]))
		var o_w := maxi(0, int(float(i) * rng.randf_range(0.55, 1.15)) + rng.randi_range(0, 3) + tier * 2)
		var o_l := int(float(o_w) * rng.randf_range(0.08, 0.6)) + (rng.randi_range(0, 2) if tier == 0 else 0)
		# Evento.
		var week_i := int(weeks[i])
		var ev := ""
		if tier == 2:
			if w.is_president():
				var kind2 := "ppv" if title or rng.randf() < 0.4 else "fn"
				var np := Calendar.num_at(w, kind2, "", week_i)
				ev = ("%s %d" % [short, np] if kind2 == "ppv" else "%s Fight Night %d" % [short, np]) if np >= 1 else "%s Fight Night" % short
			else:
				var num := Calendar.num_at(w, "lgc", "", week_i)
				ev = "%s %d" % [short, num] if num >= 1 else "%s Fight Night" % short
		elif tier == 1:
			var num2 := Calendar.num_at(w, "cont", confed, week_i)
			ev = "%s %d" % [cont, num2] if num2 >= 1 else cont
		else:
			var city := home
			if nat != f.nation or rng.randf() < 0.35:
				var cs: Array = DataDB.cities(f.nation)
				if not cs.is_empty():
					city = String((cs[rng.randi_range(0, mini(cs.size() - 1, 9))] as Array)[0])
			var key := String(pats[abs(hash(city)) % pats.size()]).format({"c": city})
			var num3 := Calendar.num_at(w, "reg", key, week_i)
			ev = "%s %d" % [key, num3] if num3 >= 1 else key
		list.append({"week": week_i, "opp": -1, "opp_name": opp_name, "opp_rec": "%d-%d" % [o_w, o_l], "opp_nation": nat, "res": res, "method": method,
			"detail": detail, "round": rd, "time": tm, "event": ev, "tier": tier, "title": title, "bout": -1, "past": true})
	return list


## Acerta o fim da lista para bater com a sequência (+3 = três vitórias seguidas, -2 = duas derrotas).
static func _fix_tail(outs: Array, streak: int) -> void:
	var n := outs.size()
	if n == 0:
		return
	if streak == 0:
		# Sequência zerada: a última foi empate ou sem resultado, se ele tem algum.
		for i in range(n - 1, -1, -1):
			if not String(outs[i][0]) in ["V", "D"]:
				var it: Array = outs[i]
				outs.remove_at(i)
				outs.append(it)
				return
		return
	var want := "V" if streak > 0 else "D"
	var need := mini(absi(streak), n)
	# Traz para o fim `need` resultados do tipo certo.
	var pos := n - 1
	for k in need:
		var found := -1
		for i in range(pos, -1, -1):
			if String(outs[i][0]) == want:
				found = i
				break
		if found < 0:
			return
		var item: Array = outs[found]
		outs.remove_at(found)
		outs.insert(pos, item)
		pos -= 1
	# O que vem logo antes da sequência precisa ser outro resultado (senão ela seria maior).
	if pos >= 0 and String(outs[pos][0]) == want:
		for i in range(pos - 1, -1, -1):
			if String(outs[i][0]) != want:
				var tmp: Array = outs[i]
				outs[i] = outs[pos]
				outs[pos] = tmp
				break


static func _round(rng: RandomNumberGenerator, rounds: int) -> int:
	var r := rng.randf()
	if rounds >= 5:
		return 1 if r < 0.3 else (2 if r < 0.55 else (3 if r < 0.75 else (4 if r < 0.9 else 5)))
	return 1 if r < 0.46 else (2 if r < 0.78 else 3)


## A semana do jogo em que ele fez `age` anos (negativa: antes do início).
static func _week_of_age(f: Fighter, age: int) -> int:
	var start: Dictionary = GameWorld.START
	var months := (f.birth_year + age - int(start["year"])) * 12 + (f.birth_month - int(start["month"]))
	return int(round(float(months) * 52.0 / 12.0))
