class_name CareerStats
extends RefCounted
## Os números da carreira de cada lutador: o que cada luta deixa (golpes, quedas, finalizações,
## controle, tempo), as médias no padrão das estatísticas do MMA, a curva de evolução do nível e
## os marcos da carreira (10 vitórias, primeiro cinturão...).
##
## O cartel de antes do jogo também tem números: `ensure` estima o passado pelos atributos, com
## as mesmas relações que o motor de luta produz (calibrado em 2.600 lutas simuladas), para o
## perfil não começar vazio. O que acontece no jogo entra por `on_bout`.

## Nível guardado a cada tantas semanas (curva de evolução).
const SAMPLE_WEEKS := 13
const MAX_SAMPLES := 130

## Marcos: chave -> [texto, fama que rende].
const MARKS := {
	"estreia": ["Estreia como profissional", 0.0],
	"v1": ["Primeira vitória como profissional", 0.5],
	"v5": ["5 vitórias na carreira", 0.5],
	"v10": ["10 vitórias na carreira", 1.5],
	"v15": ["15 vitórias na carreira", 1.5],
	"v20": ["20 vitórias na carreira", 2.5],
	"v25": ["25 vitórias na carreira", 2.5],
	"v30": ["30 vitórias na carreira", 4.0],
	"ko1": ["Primeiro nocaute", 0.5],
	"ko5": ["5 nocautes na carreira", 1.0],
	"ko10": ["10 nocautes na carreira", 2.5],
	"ko15": ["15 nocautes na carreira", 3.0],
	"fin1": ["Primeira finalização", 0.5],
	"fin5": ["5 finalizações na carreira", 1.0],
	"fin10": ["10 finalizações na carreira", 2.5],
	"seq5": ["5 vitórias seguidas", 1.5],
	"seq8": ["8 vitórias seguidas", 2.5],
	"seq12": ["12 vitórias seguidas", 4.0],
	"l10": ["10 lutas como profissional", 0.5],
	"l20": ["20 lutas como profissional", 1.0],
	"l30": ["30 lutas como profissional", 1.5],
	"main1": ["Primeira luta principal", 1.0],
	"top15": ["Entrou no ranking", 1.0],
	"top5": ["Chegou ao top 5", 2.0],
	"disputa1": ["Primeira disputa de cinturão", 1.0],
	"cinturao1": ["Primeiro cinturão", 0.0],
	"def1": ["Primeira defesa de cinturão", 0.0],
	"def3": ["3 defesas de cinturão", 2.0],
	"def5": ["5 defesas de cinturão", 3.0],
	"def10": ["10 defesas de cinturão", 5.0],
}
## Escadas de contagem: [prefixo, degraus, nome para "a seguir"].
const LADDERS := [
	["v", [1, 5, 10, 15, 20, 25, 30], "vitórias"],
	["ko", [1, 5, 10, 15], "nocautes"],
	["fin", [1, 5, 10], "finalizações"],
	["l", [10, 20, 30], "lutas"],
	["seq", [5, 8, 12], "vitórias seguidas"],
	["def", [1, 3, 5, 10], "defesas de cinturão"],
]


static func blank() -> Dictionary:
	return {"n": 0, "t": 0.0, "sl": 0, "sa": 0, "ab": 0, "oa": 0, "td": 0, "ta": 0, "otd": 0, "ota": 0, "sub": 0, "kd": 0, "kdt": 0, "ctrl": 0.0}


static func _rng(f: Fighter, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([f.id, f.face_seed, salt])
	return r


# --- Números -----------------------------------------------------------------------------

## Garante os totais da carreira (estima as lutas de antes do jogo na primeira vez).
static func ensure(f: Fighter) -> Dictionary:
	if not f.stats.is_empty():
		return f.stats
	f.stats = blank()
	var n := f.fights() - f.history.size()
	if n <= 0:
		return f.stats
	var r := _rng(f, "numeros")
	var rec := f.record
	# Decisões e lutas encerradas antes do jogo (o cartel menos o que já está no histórico).
	var dec := int(rec["dec_w"]) + int(rec["dec_l"]) + int(rec["d"])
	for h: Dictionary in f.history:
		if String(h.get("method", "")) in ["DEC", "EMP"]:
			dec -= 1
	dec = clampi(dec, 0, n)
	var t := float(dec) * 900.0 + float(n - dec) * 445.0 * r.randf_range(0.9, 1.12)
	var lv := float(f.level())
	var k := func() -> float: return r.randf_range(0.9, 1.1)
	var att_pm := clampf(-0.49 + 0.058 * f.a("maos") + 0.0104 * f.a("velocidade") + 0.0443 * f.a("cardio") - 0.0427 * f.a("finalizacao")
		+ 0.0107 * f.a("movimentacao") - 0.014 * f.a("clinch") + 0.0171 * f.a("qi"), 1.6, 8.5) * float(k.call())
	var acc := clampf(0.484 + 0.0009 * (f.a("qi") - lv) + 0.0013 * (f.a("velocidade") - lv) + r.randfn(0.0, 0.02), 0.34, 0.64)
	var opp_acc := clampf(0.484 - 0.0016 * (f.a("defesa") - lv) - 0.0003 * (f.a("movimentacao") - lv) - 0.0007 * (f.a("velocidade") - lv) + r.randfn(0.0, 0.02), 0.3, 0.66)
	var td_att := clampf(1.763 + 0.1393 * f.a("queda") + 0.0443 * f.a("por_cima") - 0.043 * f.a("maos") - 0.0442 * f.a("chutes")
		- 0.0211 * f.a("forca") - 0.0354 * f.a("finalizacao"), 0.0, 14.0) * float(k.call())
	var td_acc := clampf(0.414 + 0.0045 * (f.a("queda") - lv) + 0.0017 * (f.a("forca") - lv) + r.randfn(0.0, 0.03), 0.12, 0.8)
	var opp_td_acc := clampf(0.414 - 0.0045 * (f.a("def_queda") - lv) - 0.0017 * (f.a("forca") - lv) + r.randfn(0.0, 0.03), 0.05, 0.85)
	var sub15 := clampf(-0.69 + 0.0766 * f.a("finalizacao") + 0.013 * f.a("por_baixo") - 0.0117 * f.a("queda") - 0.046 * f.a("maos"), 0.0, 6.0) * float(k.call())
	var kd_f := clampf(-0.0876 + 0.0062 * f.a("potencia") + 0.0056 * f.a("maos") - 0.0066 * lv, 0.0, 1.2)
	var kdt_f := clampf(-0.0876 + 0.0118 * lv - 0.0047 * f.a("queixo") - 0.0019 * f.a("defesa"), 0.0, 1.2)
	var ctrl15 := clampf(-66.4 + 7.26 * f.a("queda") + 4.75 * f.a("por_cima") - 2.21 * f.a("forca") - 0.87 * f.a("clinch") - 4.03 * f.a("finalizacao"), 0.0, 620.0) * float(k.call())
	var mins := t / 60.0
	var p15 := t / 900.0
	var st := f.stats
	st["n"] = n
	st["t"] = t
	st["sa"] = int(round(att_pm * mins))
	st["sl"] = int(round(float(st["sa"]) * acc))
	st["oa"] = int(round(4.45 * mins * float(k.call())))
	st["ab"] = int(round(float(st["oa"]) * opp_acc))
	st["ta"] = int(round(td_att * p15))
	st["td"] = int(round(float(st["ta"]) * td_acc))
	st["ota"] = int(round(4.5 * p15 * float(k.call())))
	st["otd"] = int(round(float(st["ota"]) * opp_td_acc))
	st["sub"] = maxi(int(round(sub15 * p15)), int(rec["sub_w"]) - _count(f, "FIN", "V"))
	st["kd"] = int(round(kd_f * n + (int(rec["ko_w"]) - _count(f, "KO", "V")) * 0.35))
	st["kdt"] = int(round(kdt_f * n))
	st["ctrl"] = ctrl15 * p15
	return st


static func _count(f: Fighter, method: String, res: String) -> int:
	var c := 0
	for h: Dictionary in f.history:
		var m := String(h.get("method", ""))
		if String(h.get("res", "")) == res and (m == method or (method == "KO" and m == "TKO")):
			c += 1
	return c


## Depois de cada luta: soma na carreira dos dois e guarda a linha da luta no histórico
## (`st`: [golpes certos, tentados, quedas, tentadas, finalizações tentadas, knockdowns,
## controle em s, golpes sofridos]).
static func on_bout(w: GameWorld, b: Bout, res: Dictionary, e: FightEngine) -> void:
	if e == null or e.s.size() < 2:
		return
	var t := float(int(res.get("round", b.rounds)) - 1) * 300.0 + float(res.get("time", 300.0))
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		if f == null:
			continue
		var me: Dictionary = e.s[i]["total"]
		var op: Dictionary = e.s[1 - i]["total"]
		var st := ensure(f)
		st["n"] = int(st["n"]) + 1
		st["t"] = float(st["t"]) + t
		st["sl"] = int(st["sl"]) + int(me["sig_land"])
		st["sa"] = int(st["sa"]) + int(me["sig_att"])
		st["ab"] = int(st["ab"]) + int(op["sig_land"])
		st["oa"] = int(st["oa"]) + int(op["sig_att"])
		st["td"] = int(st["td"]) + int(me["td"])
		st["ta"] = int(st["ta"]) + int(me["td_att"])
		st["otd"] = int(st["otd"]) + int(op["td"])
		st["ota"] = int(st["ota"]) + int(op["td_att"])
		st["sub"] = int(st["sub"]) + int(me["sub_att"])
		st["kd"] = int(st["kd"]) + int(me["kd"])
		st["kdt"] = int(st["kdt"]) + int(op["kd"])
		st["ctrl"] = float(st["ctrl"]) + float(me["ctrl"])
		if not f.history.is_empty() and int((f.history.back() as Dictionary).get("bout", -1)) == b.id:
			(f.history.back() as Dictionary)["st"] = [int(me["sig_land"]), int(me["sig_att"]), int(me["td"]), int(me["td_att"]), int(me["sub_att"]),
				int(me["kd"]), int(round(float(me["ctrl"]))), int(op["sig_land"])]


## Médias da carreira no padrão das estatísticas do MMA.
static func rates(f: Fighter) -> Dictionary:
	var st := ensure(f)
	var t := maxf(1.0, float(st["t"]))
	var mins := t / 60.0
	var p15 := t / 900.0
	var n := maxi(1, int(st["n"]))
	return {
		"n": int(st["n"]),
		"slpm": float(st["sl"]) / mins,
		"acc": float(st["sl"]) / maxf(1.0, float(st["sa"])),
		"sapm": float(st["ab"]) / mins,
		"def": 1.0 - float(st["ab"]) / maxf(1.0, float(st["oa"])),
		"td15": float(st["td"]) / p15,
		"tdacc": float(st["td"]) / maxf(1.0, float(st["ta"])),
		"tddef": 1.0 - float(st["otd"]) / maxf(1.0, float(st["ota"])),
		"sub15": float(st["sub"]) / p15,
		"kd": float(st["kd"]) / float(n),
		"ctrl15": float(st["ctrl"]) / p15,
		"avg_t": t / float(n),
	}


## Média da categoria (lutadores profissionais em atividade), para comparar no perfil.
static func division_rates(w: GameWorld, div: String) -> Dictionary:
	var sum := {}
	var c := 0
	for f: Fighter in w.in_division(div):
		if not f.is_pro():
			continue
		var r := rates(f)
		if int(r["n"]) <= 0:
			continue
		for k: String in r:
			sum[k] = float(sum.get(k, 0.0)) + float(r[k])
		c += 1
	for k: String in sum:
		sum[k] = float(sum[k]) / float(maxi(1, c))
	return sum


## Linha curta de uma luta do histórico: "58 golpes · 2 quedas · 1 knockdown".
static func bout_line(h: Dictionary) -> String:
	var st: Array = h.get("st", [])
	if st.size() < 8:
		return ""
	var parts: Array = ["%d de %d golpes" % [int(st[0]), int(st[1])]]
	if int(st[3]) > 0:
		parts.append("%d de %s" % [int(st[2]), Fmt.plural(int(st[3]), "queda", "quedas")])
	if int(st[4]) > 0:
		parts.append(Fmt.plural(int(st[4]), "tentativa de finalização", "tentativas de finalização"))
	if int(st[5]) > 0:
		parts.append(Fmt.plural(int(st[5]), "knockdown", "knockdowns"))
	return " · ".join(parts)


# --- Curva de evolução ---------------------------------------------------------------------

## Garante a curva do nível: reconstrói o passado (desde o começo da carreira até a última
## marcação) pela idade, pelo auge e pelo nível de hoje.
static func ensure_curve(w: GameWorld, f: Fighter) -> void:
	if not f.curve.is_empty():
		return
	var r := _rng(f, "curva")
	var last := int(floor(float(w.week) / float(SAMPLE_WEEKS))) * SAMPLE_WEEKS
	if f.retired and f.retired_week >= 0:
		last = mini(last, int(floor(float(f.retired_week) / float(SAMPLE_WEEKS))) * SAMPLE_WEEKS)
	var age_now := _age_at(w, f, last)
	var start := 17.5 + r.randf_range(0.0, 2.5)
	var n := clampi(int((age_now - start) * 52.0 / float(SAMPLE_WEEKS)), 1, MAX_SAMPLES - 8)
	var k := r.randf_range(1.0, 1.7)
	var d := r.randf_range(0.5, 0.95)
	var peak := float(f.peak_age)
	var shape := func(a: float) -> float:
		return -k * pow(maxf(0.0, peak - a), 1.25) - d * pow(maxf(0.0, a - peak - 1.0), 1.2)
	var lvl := float(f.level())
	var base: float = shape.call(age_now)
	var out: Array = []
	for i in n:
		var a := age_now - float(n - 1 - i) * float(SAMPLE_WEEKS) / 52.0
		var v := lvl + float(shape.call(a)) - base + (r.randfn(0.0, 0.5) if i < n - 1 else 0.0)
		out.append(clampi(int(round(v)), 20, 99))
	f.curve = out
	f.curve_w0 = last - (n - 1) * SAMPLE_WEEKS


static func _age_at(w: GameWorld, f: Fighter, week: int) -> float:
	var d := GameWorld.date_of(week)
	return float(int(d["year"]) - f.birth_year) + float(int(d["month"]) - f.birth_month) / 12.0


## Marcação do nível (a cada `SAMPLE_WEEKS`).
static func sample(w: GameWorld, f: Fighter) -> void:
	if f.curve.is_empty():
		ensure_curve(w, f)
		return
	var idx := int((w.week - f.curve_w0) / SAMPLE_WEEKS)
	while f.curve.size() < idx:
		f.curve.append(int(f.curve.back()))
	if f.curve.size() == idx:
		f.curve.append(f.level())
	if f.curve.size() > MAX_SAMPLES:
		var cut := f.curve.size() - MAX_SAMPLES
		f.curve = f.curve.slice(cut)
		f.curve_w0 += cut * SAMPLE_WEEKS


## Pontos da curva para o gráfico: [[idade, nível], ...], terminando no nível de agora.
static func curve_points(w: GameWorld, f: Fighter) -> Array:
	ensure_curve(w, f)
	var out: Array = []
	for i in f.curve.size():
		out.append([_age_at(w, f, f.curve_w0 + i * SAMPLE_WEEKS), float(f.curve[i])])
	if not f.retired:
		var a := _age_at(w, f, w.week)
		if out.is_empty() or a > float((out.back() as Array)[0]) + 0.01:
			out.append([a, float(f.level())])
		else:
			(out.back() as Array)[1] = float(f.level())
	return out


## Foto dos atributos (equipe do jogador e lutadores seguidos): até três, uma a cada marcação,
## para mostrar o que subiu e o que caiu nos últimos meses.
static func snapshot(w: GameWorld, f: Fighter) -> void:
	f.snaps.append({"w": w.week, "a": f.attrs.duplicate()})
	if f.snaps.size() > 3:
		f.snaps = f.snaps.slice(f.snaps.size() - 3)


## Quanto cada atributo mudou desde a foto mais antiga: {atributo: diferença}.
static func trend(f: Fighter) -> Dictionary:
	var out := {}
	if f.snaps.is_empty():
		return out
	var old: Dictionary = (f.snaps[0] as Dictionary)["a"]
	for k: String in Fighter.ATTRS:
		var d := int(round(f.a(k) - float(old.get(k, f.a(k)))))
		if d != 0:
			out[k] = d
	return out


static func trend_weeks(w: GameWorld, f: Fighter) -> int:
	if f.snaps.is_empty():
		return 0
	return w.week - int((f.snaps[0] as Dictionary)["w"])


# --- Marcos ------------------------------------------------------------------------------

static func has_mark(f: Fighter, key: String) -> bool:
	for m: Array in f.marks:
		if String(m[0]) == key:
			return true
	return false


## Marcos que o cartel de antes do jogo já garante (sem data).
static func ensure_marks(f: Fighter) -> void:
	if not f.marks.is_empty() or not f.is_pro():
		return
	for key: String in _reached(f, true):
		f.marks.append([key, -9999])


static func _value(f: Fighter, prefix: String) -> int:
	match prefix:
		"v":
			return int(f.record["w"])
		"ko":
			return int(f.record["ko_w"])
		"fin":
			return int(f.record["sub_w"])
		"l":
			return f.fights()
		"seq":
			return maxi(0, f.streak)
		"def":
			return f.title_defenses
	return 0


## Chaves de marco que os números de hoje garantem. `past`: também o que só o passado explica
## (a sequência de vitórias de antes do jogo não entra, porque não dá para saber).
static func _reached(f: Fighter, past: bool) -> Array:
	var out: Array = []
	if f.is_pro():
		out.append("estreia")
	for lad: Array in LADDERS:
		var p := String(lad[0])
		if p == "seq" and past:
			continue
		var v := _value(f, p)
		for step: int in lad[1]:
			if v >= step:
				out.append("%s%d" % [p, step])
	if f.titles_won > 0:
		out.append("cinturao1")
		if past:
			out.append("disputa1")
			out.append("main1")
			out.append("top15")
			out.append("top5")
	return out


## Depois de cada luta: marca o que o lutador acabou de alcançar e avisa.
static func check_marks(w: GameWorld, f: Fighter, b: Bout = null) -> void:
	ensure_marks(f)
	var keys := _reached(f, false)
	if b != null:
		var ev := w.event(b.event_id)
		if b.main_event and ev != null and ev.tier >= 1:
			keys.append("main1")
		if b.title:
			keys.append("disputa1")
	var r := w.rank_of(f)
	if r >= 0 and r <= 15:
		keys.append("top15")
	if r >= 0 and r <= 5:
		keys.append("top5")
	for key: String in keys:
		if has_mark(f, key):
			continue
		f.marks.append([key, w.week])
		var info: Array = MARKS.get(key, [key, 0.0])
		f.popularity = minf(100.0, f.popularity + float(info[1]))
		if key == "estreia":
			continue
		var mine := w.is_user_fighter(f)
		if mine or w.is_followed(f) or (float(info[1]) >= 2.5 and f.level() >= 68):
			w.add_news("marco", "%s: %s." % [f.display_name(), mark_sentence(key)], [f.id], mine)


static func mark_name(key: String) -> String:
	return String((MARKS.get(key, [key, 0.0]) as Array)[0])


static func mark_sentence(key: String) -> String:
	var t := mark_name(key)
	return t.substr(0, 1).to_lower() + t.substr(1)


## Ranking muda sem luta (os outros perdem): confere o top 15 e o top 5 de cada categoria.
static func weekly_marks(w: GameWorld) -> void:
	for div: String in w.rankings:
		var lst: Array = w.rankings[div]
		for i in mini(15, lst.size()):
			var f := w.fighter(int(lst[i]))
			if f == null or f.retired:
				continue
			if not has_mark(f, "top15") or (i < 5 and not has_mark(f, "top5")):
				check_marks(w, f)


## Próximos marcos ao alcance: [[texto, feito, alvo], ...] (os três mais perto).
static func next_marks(f: Fighter) -> Array:
	var out: Array = []
	for lad: Array in LADDERS:
		var p := String(lad[0])
		if p == "def" and f.titles_won <= 0:
			continue
		var v := _value(f, p)
		for step: int in lad[1]:
			if v < step and not has_mark(f, "%s%d" % [p, step]):
				if p == "seq" and v < 2:
					break
				out.append(["%d %s" % [step, String(lad[2])] if step > 1 else mark_name("%s1" % p), v, step])
				break
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) / float(a[2]) > float(b[1]) / float(b[2]))
	return out.slice(0, 3)
