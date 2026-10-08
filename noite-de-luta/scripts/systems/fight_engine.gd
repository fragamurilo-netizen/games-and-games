class_name FightEngine
extends RefCounted
## Motor de luta, round a round (para o jogador mudar o plano no intervalo, como no LEATHER).
## Cada lance dura alguns segundos: disputa de distância em pé, trocação com combinações e
## contragolpes, quedas, clinch na grade, posições no chão, ground and pound e finalizações.
## Os atributos decidem cada disputa; o plano de luta decide o que cada um tenta. Três juízes
## com gostos diferentes pontuam os rounds (10-9, 10-8). Nada aqui conhece a interface.

const ROUND_S := 300.0

## Golpes: precisão-base, força, atributo técnico, alvo padrão e custo de fôlego.
const STRIKES := {
	"jab": {"acc": 0.50, "pow": 0.32, "skill": "maos", "zone": "head", "cost": 0.0022},
	"direto": {"acc": 0.41, "pow": 0.78, "skill": "maos", "zone": "head", "cost": 0.0030},
	"gancho": {"acc": 0.36, "pow": 0.95, "skill": "maos", "zone": "head", "cost": 0.0034},
	"uppercut": {"acc": 0.33, "pow": 1.0, "skill": "maos", "zone": "head", "cost": 0.0034},
	"overhand": {"acc": 0.29, "pow": 1.2, "skill": "maos", "zone": "head", "cost": 0.0040},
	"chute_baixo": {"acc": 0.68, "pow": 0.55, "skill": "chutes", "zone": "legs", "cost": 0.0040},
	"chute_corpo": {"acc": 0.55, "pow": 0.78, "skill": "chutes", "zone": "body", "cost": 0.0048},
	"chute_alto": {"acc": 0.27, "pow": 1.55, "skill": "chutes", "zone": "head", "cost": 0.0060},
	"chute_frontal": {"acc": 0.50, "pow": 0.5, "skill": "chutes", "zone": "body", "cost": 0.0040},
	"joelhada": {"acc": 0.48, "pow": 0.95, "skill": "clinch", "zone": "body", "cost": 0.0045},
	"cotovelada": {"acc": 0.44, "pow": 0.85, "skill": "clinch", "zone": "head", "cost": 0.0035},
	# Golpes de escola: raros no geral, frequentes em quem vem da arte certa (ver styles.json).
	"chute_panturrilha": {"acc": 0.62, "pow": 0.6, "skill": "chutes", "zone": "legs", "cost": 0.0038},
	"chute_obliquo": {"acc": 0.55, "pow": 0.45, "skill": "chutes", "zone": "legs", "cost": 0.0034},
	"chute_giratorio": {"acc": 0.33, "pow": 1.25, "skill": "chutes", "zone": "body", "cost": 0.0060},
	"chute_rodado": {"acc": 0.18, "pow": 1.8, "skill": "chutes", "zone": "head", "cost": 0.0070},
	"backfist": {"acc": 0.24, "pow": 1.1, "skill": "maos", "zone": "head", "cost": 0.0050},
	"superman": {"acc": 0.30, "pow": 1.0, "skill": "maos", "zone": "head", "cost": 0.0045},
	"joelhada_voadora": {"acc": 0.22, "pow": 1.7, "skill": "clinch", "zone": "head", "cost": 0.0070},
}
const SPINNING := ["chute_giratorio", "chute_rodado", "backfist"]
## Chutes que dá para segurar (o chute baixo e o oblíquo não).
const CATCHABLE := ["chute_corpo", "chute_alto", "chute_frontal", "chute_giratorio", "chute_rodado"]
## Peso de cada golpe por distância (0 longa, 1 média, 2 curta).
const POOL := [
	{"jab": 3.0, "direto": 2.0, "chute_baixo": 1.8, "chute_corpo": 1.4, "chute_alto": 0.5, "chute_frontal": 0.8,
		"chute_panturrilha": 0.5, "chute_obliquo": 0.2, "chute_giratorio": 0.1, "chute_rodado": 0.04, "superman": 0.05},
	{"jab": 2.2, "direto": 2.2, "gancho": 2.0, "uppercut": 0.5, "overhand": 0.8, "chute_baixo": 1.0, "chute_corpo": 0.8, "chute_alto": 0.25,
		"chute_panturrilha": 0.5, "chute_obliquo": 0.1, "chute_giratorio": 0.06, "chute_rodado": 0.04, "backfist": 0.05, "superman": 0.05, "joelhada_voadora": 0.04},
	{"gancho": 2.4, "uppercut": 1.6, "direto": 1.0, "jab": 0.7, "joelhada": 0.9, "cotovelada": 0.4},
]
const GROUND_ORDER := ["guarda", "meia", "lateral", "montada"]
const GPOS_NAME := {"guarda": "guarda", "meia": "meia-guarda", "lateral": "cem quilos", "montada": "montada", "costas": "pegada nas costas"}
## Como cada um fica depois da queda ({a} = quem derrubou, {b} = quem caiu).
const GPOS_IN := {"guarda": "{b} cai e fecha a guarda.", "meia": "{b} cai na meia-guarda.", "lateral": "{a} cai direto nos cem quilos.",
	"montada": "{a} já cai montado.", "costas": "{a} cai pegando as costas de {b}."}

var f: Array[Fighter] = [] # [vermelho, azul]
var rounds: int = 3
var title := false
var plans: Array = [{}, {}]
var narrate := true
var rng: RandomNumberGenerator
var round_no := 0
var t := 0.0
var finished := false
var result: Dictionary = {}
var s: Array = [] # estado de cada lado
var pos := "solto" # solto | clinch | chao
var dist := 1
var cage := false
var top := -1
var gpos := ""
var judges: Array = []
var ref_stop := 1.0
var cards: Array = [[], [], []]
var round_stats: Array = []
var events: Array = []
var ko_factor := 1.0
var mods: Array = [{}, {}]
var _round_events: Array = []
var _last_strike := ""
## Repertório de cada lado (Styles.profile): golpes, quedas, finalizações e marcas da escola.
var prof: Array = [{}, {}]


## `opts`: {narrate, mods: [{atributo: ajuste}, {}], ko (fator de nocaute da categoria)}
func setup(fa: Fighter, fb: Fighter, n_rounds: int, is_title: bool, r: RandomNumberGenerator, opts: Dictionary = {}) -> void:
	f.assign([fa, fb])
	rounds = n_rounds
	title = is_title
	rng = r
	narrate = bool(opts.get("narrate", true))
	mods = opts.get("mods", [{}, {}])
	# Fator de nocaute da categoria, achatado: o pesado nocauteia mais, mas o mosca também derruba.
	ko_factor = 1.0 + (float(opts.get("ko", 1.0)) - 1.0) * 0.5
	plans = [FightPlan.suggest(fa, fb), FightPlan.suggest(fb, fa)]
	prof = [Styles.profile(fa), Styles.profile(fb)]
	# Forma do dia: ninguém luta sempre igual (é o que faz a zebra existir).
	var m2: Array = []
	for i in 2:
		var m: Dictionary = (mods[i] as Dictionary).duplicate() if i < mods.size() else {}
		var form := rng.randfn(0.0, 6.0)
		for k: String in Fighter.ATTRS:
			if k != "queixo":
				m[k] = float(m.get(k, 0.0)) + form
		m2.append(m)
	mods = m2
	s = []
	for i in 2:
		s.append({"st": 1.0, "head": 0.0, "body": 0.0, "legs": 0.0, "cut": 0.0, "rock": 0.0, "kd": 0, "unans": 0,
			"total": _blank_stats()})
	for _j in 3:
		judges.append({"st": rng.randf_range(0.8, 1.2), "gr": rng.randf_range(0.55, 1.1), "ag": rng.randf_range(0.2, 0.55), "noise": rng.randf_range(0.6, 1.6)})
	# Árbitro: uns param cedo, outros deixam trabalhar.
	ref_stop = rng.randf_range(0.75, 1.3)


func ref_label() -> String:
	if ref_stop > 1.12:
		return "Árbitro que para cedo"
	if ref_stop < 0.88:
		return "Árbitro que deixa trabalhar"
	return "Árbitro de critério normal"


func set_plan(side: int, plan: Dictionary) -> void:
	plans[side] = plan.duplicate()


func _blank_stats() -> Dictionary:
	return {"sig_att": 0, "sig_land": 0, "head": 0, "body": 0, "legs": 0, "kd": 0, "td_att": 0, "td": 0,
		"sub_att": 0, "ctrl": 0.0, "rev": 0, "adv": 0, "dmg": 0.0}


func is_over() -> bool:
	return finished or round_no >= rounds


func run_all() -> Dictionary:
	while not is_over():
		run_round()
		if not finished and round_no < rounds:
			between_rounds()
			for i in 2:
				var lost := _rounds_lost(i)
				plans[i] = FightPlan.adjust(plans[i], f[i], lost, float(s[i]["st"]), rounds - round_no)
	return finalize()


## Corre um round inteiro e devolve os lances dele.
func run_round() -> Array:
	round_no += 1
	t = 0.0
	pos = "solto"
	top = -1
	gpos = ""
	cage = false
	dist = 1
	_round_events = []
	var rs: Array = [_blank_stats(), _blank_stats()]
	round_stats.append(rs)
	_log(-1, "info", "Começa o %dº round." % round_no)
	while t < ROUND_S and not finished:
		var dt: float
		if pos == "chao":
			dt = rng.randf_range(7.0, 14.0)
		elif pos == "clinch":
			dt = rng.randf_range(6.0, 11.0)
		else:
			var pace := _rate(0) + _rate(1)
			dt = rng.randf_range(4.0, 9.0) * clampf(2.0 / maxf(0.5, pace), 0.65, 1.5)
		dt = minf(dt, ROUND_S - t + 0.01)
		t += dt
		_drain(dt)
		match pos:
			"solto":
				_tick_standing(dt)
			"clinch":
				_tick_clinch(dt)
			"chao":
				_tick_ground(dt)
		for i in 2:
			s[i]["rock"] = maxf(0.0, float(s[i]["rock"]) - dt * 0.011 * (0.6 + _at(i, "coracao") / 120.0))
	if not finished:
		t = ROUND_S
		_score_round()
		_log(-1, "round", "Fim do %dº round." % round_no)
	return _round_events


## Intervalo: recupera fôlego, o corte é tratado e o médico olha.
func between_rounds() -> void:
	for i in 2:
		var cap := 1.0 - float(s[i]["body"]) * 0.22
		s[i]["st"] = minf(cap, float(s[i]["st"]) + 0.34 * (0.55 + _at(i, "cardio") / 220.0))
		s[i]["rock"] = 0.0
		s[i]["unans"] = 0
		if float(s[i]["cut"]) > 1.15 and rng.randf() < (float(s[i]["cut"]) - 1.15) * 0.7:
			_finish(1 - i, "TKO", "interrupção médica (corte)")
			_log(i, "fim", "O médico olha o corte de %s e não deixa voltar. Fim de luta!" % f[i].short_name())
			return
		if float(s[i]["head"]) > 2.6 and float(s[i]["st"]) < 0.45 and rng.randf() < 0.25:
			_finish(1 - i, "TKO", "desistência no corner")
			_log(i, "fim", "O corner de %s joga a toalha no intervalo." % f[i].short_name())
			return


## Placar dos juízes até aqui do ponto de vista do lado `i`: rounds perdidos menos ganhos.
func _rounds_lost(i: int) -> int:
	var lost := 0
	for c: Array in cards[0]:
		if int(c[i]) < int(c[1 - i]):
			lost += 1
		elif int(c[i]) > int(c[1 - i]):
			lost -= 1
	return lost


# --- Atributos efetivos -------------------------------------------------------------------

func _at(i: int, key: String) -> float:
	var v := f[i].a(key) + float(mods[i].get(key, 0.0))
	var st := float(s[i]["st"])
	match key:
		"movimentacao", "velocidade", "chutes":
			v -= float(s[i]["legs"]) * 20.0
		"cardio":
			v -= float(s[i]["body"]) * 12.0
		"queixo":
			v -= f[i].wear * 1.5
			return v
		"coracao", "qi":
			return v
	return v * (0.62 + 0.38 * st)


## Golpes por lance que o lado `i` quer soltar (ritmo × postura × fôlego).
func _rate(i: int) -> float:
	var p: Dictionary = plans[i]
	var r: float = [0.55, 0.85, 1.15][int(p["ritmo"])] * [0.78, 1.0, 1.28][int(p["postura"])]
	r *= (0.55 + 0.45 * float(s[i]["st"])) * (0.85 + _at(i, "velocidade") / 300.0)
	r *= 1.0 - float(s[i]["rock"]) * 0.6
	return r


func _drain(dt: float) -> void:
	for i in 2:
		var p: Dictionary = plans[i]
		var base: float = [0.55, 0.85, 1.2][int(p["ritmo"])] * [0.85, 1.0, 1.18][int(p["postura"])]
		if pos == "chao":
			base = 0.9 if i == top else 1.1
		var cost := dt / ROUND_S * 0.24 * base * (1.35 - _at(i, "cardio") / 160.0)
		s[i]["st"] = maxf(0.05, float(s[i]["st"]) - cost)


func _spend(i: int, amount: float) -> void:
	s[i]["st"] = maxf(0.05, float(s[i]["st"]) - amount * (1.3 - f[i].a("cardio") / 200.0))


## Força de uma marca do estilo do lado `i` (0 a 1).
func _tr(i: int, t: String) -> float:
	return Styles.mark(prof[i], t)


# --- Em pé --------------------------------------------------------------------------------

func _tick_standing(dt: float) -> void:
	# Distância: quem controla o espaço leva a luta para a sua.
	var want := [int(plans[0]["distancia"]), int(plans[1]["distancia"])]
	if want[0] == want[1]:
		dist = want[0]
	else:
		var c := [0.0, 0.0]
		for i in 2:
			c[i] = _at(i, "movimentacao") * 0.6 + _at(i, "velocidade") * 0.25 + _at(i, "qi") * 0.15
			if int(plans[i]["postura"]) == 2 and want[i] > want[1 - i]:
				c[i] += 10.0
			# Caratê e taekwondo mandam na distância longa; o greco e o tailandês encurtam.
			if want[i] == 0:
				c[i] += 8.0 * _tr(i, "blitz")
			elif want[i] == 2:
				c[i] += 6.0 * maxf(_tr(i, "cage"), _tr(i, "plum"))
		var p0: float = pow(c[0], 2.0) / (pow(c[0], 2.0) + pow(c[1], 2.0))
		dist = want[0] if rng.randf() < p0 else want[1]
	# Quedas
	var order := [0, 1] if rng.randf() < 0.5 else [1, 0]
	for i: int in order:
		var intent: float = [0.0, 0.05, 0.17][int(plans[i]["jogo"])] * (0.5 + _at(i, "queda") / 100.0)
		intent *= [0.6, 1.0, 1.4][dist]
		if float(s[1 - i]["rock"]) > 0.4:
			intent *= 1.6
		if rng.randf() < intent * dt / 6.5:
			_takedown(i, false)
			return
	# Clinch
	if dist == 2:
		for i: int in order:
			if int(plans[i]["distancia"]) == 2 and rng.randf() < 0.22 + (_at(i, "clinch") - _at(1 - i, "movimentacao")) / 250.0 + 0.06 * maxf(_tr(i, "cage"), _tr(i, "plum")):
				pos = "clinch"
				cage = rng.randf() < 0.55 + 0.3 * _tr(i, "cage")
				if _tr(i, "plum") >= 0.6 and not cage:
					_log(i, "info", "%s prende %s pela nuca no clinch tailandês." % [f[i].short_name(), f[1 - i].short_name()])
				else:
					_log(i, "info", "%s amarra no clinch%s." % [f[i].short_name(), " e prensa na grade" if cage else ""])
				return
	_exchange()


func _exchange() -> void:
	var r: Array[float] = [_rate(0), _rate(1)]
	var tot: float = r[0] + r[1]
	if rng.randf() < 0.22 / maxf(0.4, tot):
		if narrate and rng.randf() < 0.18:
			var i := rng.randi_range(0, 1)
			_log(i, "info", _say(["{a} finta e circula.", "{a} mede a distância.", "{a} corta o caminho de {b}.", "Estudo dos dois no centro do octógono."], i))
		return
	var att := 0 if rng.randf() < r[0] / tot else 1
	var d := 1 - att
	var combo: int = [1, rng.randi_range(2, 3), rng.randi_range(3, 5)][int(plans[att]["combinacoes"])]
	var landed_any := false
	var missed_any := false
	for k in combo:
		var hit := _strike(att, k, false)
		landed_any = landed_any or hit
		missed_any = missed_any or not hit
		if finished or pos != "solto":
			return
	# Resposta: contragolpe planejado ou a troca natural.
	var counter_p := 0.0
	if int(plans[d]["contra"]) == 1:
		counter_p = 0.34 + (_at(d, "velocidade") + _at(d, "defesa") - _at(att, "velocidade") - _at(att, "defesa")) / 220.0
		if int(plans[att]["postura"]) == 2 or combo >= 3:
			counter_p += 0.1
	elif int(plans[d]["postura"]) >= 1:
		counter_p = 0.18
	if missed_any:
		counter_p += 0.06
	counter_p += 0.08 * _tr(d, "counter")
	if rng.randf() < counter_p * (1.0 - float(s[d]["rock"])):
		_strike(d, 0, int(plans[d]["contra"]) == 1)


func _pick_strike(i: int, zone_dist: int) -> String:
	var pool: Dictionary = POOL[zone_dist].duplicate()
	var kick_pref := pow(clampf(_at(i, "chutes") / maxf(20.0, _at(i, "maos")), 0.4, 2.2), 1.6)
	var alvo := int(plans[i]["alvo"])
	for k: String in pool.keys():
		var w: float = pool[k] * Styles.strike_mult(prof[i], k)
		if k.begins_with("chute"):
			w *= kick_pref
		if k in ["joelhada", "cotovelada", "joelhada_voadora"]:
			w *= clampf(_at(i, "clinch") / 60.0, 0.3, 1.8)
		# Giratório e voador só saem de quem tem técnica para isso.
		if k in SPINNING or k in ["joelhada_voadora", "superman"]:
			w *= clampf((_at(i, String(STRIKES[k]["skill"])) - 45.0) / 30.0, 0.05, 1.5)
		if k in ["chute_baixo", "chute_panturrilha"]:
			w *= 1.0 + 0.8 * _tr(i, "low_kicks")
		if STRIKES[k]["zone"] == "body":
			w *= 1.0 + 0.5 * _tr(i, "body")
		var z: String = STRIKES[k]["zone"]
		if alvo == 1 and z == "head":
			w *= 1.6
		elif alvo == 2 and (z == "body" or k in ["gancho", "direto"]):
			w *= 1.7
		elif alvo == 3 and k == "chute_baixo":
			w *= 3.0
		pool[k] = w
	return String(RngUtil.weighted_key(rng, pool))


## Um golpe de `att`. Devolve se acertou.
func _strike(att: int, idx: int, counter: bool, forced: String = "", zone_dist: int = -1) -> bool:
	var d := 1 - att
	var kind := forced if forced != "" else _pick_strike(att, dist if zone_dist < 0 else zone_dist)
	var sp: Dictionary = STRIKES[kind]
	var zone: String = sp["zone"]
	if kind in ["gancho", "direto"] and int(plans[att]["alvo"]) == 2 and rng.randf() < 0.45:
		zone = "body"
	elif kind in ["gancho", "direto", "uppercut"] and rng.randf() < 0.3 * _tr(att, "body"):
		zone = "body"
	if kind == "joelhada" and rng.randf() < 0.35:
		zone = "head"
	if kind == "chute_giratorio" and rng.randf() < 0.25:
		zone = "head"
	var rs: Array = round_stats.back()
	rs[att]["sig_att"] += 1
	s[att]["total"]["sig_att"] += 1
	_spend(att, float(sp["cost"]))
	var off := _at(att, String(sp["skill"])) * 0.55 + _at(att, "velocidade") * 0.2 + _at(att, "qi") * 0.1 + 15.0
	var dfn := _at(d, "defesa") * 0.6 + _at(d, "movimentacao") * 0.25 + _at(d, "velocidade") * 0.15
	if String(sp["skill"]) == "maos":
		dfn += 7.0 * _tr(d, "head_movement")
	var acc := float(sp["acc"]) - 0.04 + (off - dfn) / 210.0
	if kind in SPINNING:
		acc += 0.04 * _tr(att, "spin")
	acc += float(s[d]["rock"]) * 0.28 - 0.03 * idx
	if int(plans[d]["postura"]) == 0:
		acc -= 0.05
	if counter:
		acc += 0.08
	if kind in ["jab", "direto", "chute_baixo", "chute_corpo", "chute_frontal"] and dist == 0:
		acc += clampf((f[att].reach_cm - f[d].reach_cm) / 400.0, -0.05, 0.05)
	acc += _stance_edge(att, kind)
	acc = clampf(acc, 0.05, 0.9)
	if rng.randf() >= acc:
		s[d]["unans"] = 0
		if kind in CATCHABLE and _catch_kick(d, att, false):
			return false
		if narrate and (rng.randf() < 0.16 or kind in ["chute_alto", "overhand"] or kind in SPINNING):
			_log(att, "info", _miss_text(att, kind))
		return false
	# Acertou
	rs[att]["sig_land"] += 1
	s[att]["total"]["sig_land"] += 1
	rs[att][zone] += 1
	s[att]["total"][zone] += 1
	s[att]["unans"] = 0
	s[d]["unans"] = int(s[d]["unans"]) + 1
	var dmg := float(sp["pow"]) * (0.5 + _at(att, "potencia") / 100.0 * 0.6 + _at(att, "forca") / 1000.0) * ko_factor * rng.randf_range(0.5, 1.5) * 0.9
	if counter:
		dmg *= 1.25
	if float(s[d]["rock"]) > 0.0:
		dmg *= 1.0 + float(s[d]["rock"]) * 0.2
	rs[att]["dmg"] += dmg
	s[att]["total"]["dmg"] += dmg
	match zone:
		"head":
			return _head_hit(att, kind, dmg, counter)
		"body":
			var bd := dmg * (1.0 - 0.2 * _tr(d, "tough"))
			s[d]["body"] = float(s[d]["body"]) + bd * 0.1
			s[d]["st"] = maxf(0.05, float(s[d]["st"]) - bd * 0.045 * (1.0 + 0.3 * _tr(att, "body")))
			if narrate and (dmg > 0.9 or rng.randf() < 0.45):
				_log(att, "golpe" if dmg < 1.1 else "forte", _hit_text(att, kind, "body", dmg))
			if float(s[d]["body"]) > 1.3 and rng.randf() < bd * 0.05:
				_finish(att, "TKO", "golpe no corpo")
				_log(att, "fim", "%s se curva com a dor no fígado e o árbitro interrompe!" % f[d].short_name())
			elif kind in CATCHABLE and rng.randf() < 0.35:
				_catch_kick(d, att, true)
		"legs":
			var lk := (1.0 + 0.35 * _tr(att, "low_kicks")) * (1.3 if kind == "chute_panturrilha" else 1.0) * (1.15 if kind == "chute_baixo" else 1.0)
			s[d]["legs"] = float(s[d]["legs"]) + dmg * 0.085 * lk
			if narrate and (dmg > 0.8 or rng.randf() < 0.4):
				_log(att, "golpe", _hit_text(att, kind, "legs", dmg))
			if float(s[d]["legs"]) > 1.5 and rng.randf() < 0.05:
				_finish(att, "TKO", "chutes nas pernas")
				_log(att, "fim", "A perna de %s não aguenta mais. Interrompida!" % f[d].short_name())
	return true


func _head_hit(att: int, kind: String, dmg: float, counter: bool) -> bool:
	var d := 1 - att
	var chin := _at(d, "queixo")
	var shock := dmg * (1.0 + float(s[d]["head"]) * 0.55) * (1.3 - chin / 100.0 * 0.6)
	s[d]["head"] = float(s[d]["head"]) + dmg * 0.09
	var cut_k := 3.0 * (1.0 + _tr(att, "elbows")) if kind == "cotovelada" else (1.6 if kind in ["joelhada_voadora", "backfist"] else 1.0)
	if rng.randf() < dmg * 0.045 * cut_k:
		s[d]["cut"] = float(s[d]["cut"]) + rng.randf_range(0.2, 0.45)
		if narrate:
			_log(att, "forte", "%s abre um corte em %s. O sangue escorre." % [f[att].short_name(), f[d].short_name()])
	var rock_p := clampf((shock - 0.64) * 0.5, 0.0, 0.6)
	if rng.randf() < rock_p:
		var ko_p := clampf((shock - 1.0) * 0.45 + float(s[d]["rock"]) * 0.14 - _at(d, "coracao") / 650.0, 0.0, 0.6)
		if rng.randf() < ko_p:
			_finish(att, "KO", "nocaute (%s)" % _strike_name(kind, false, att))
			_log(att, "fim", _ko_text(att, kind))
			return true
		s[d]["rock"] = minf(1.0, float(s[d]["rock"]) + 0.25 + shock * 0.15)
		if shock > 0.95 and rng.randf() < 0.4:
			s[d]["kd"] = int(s[d]["kd"]) + 1
			var rs: Array = round_stats.back()
			rs[att]["kd"] += 1
			s[att]["total"]["kd"] += 1
			_log(att, "kd", "%s vai ao chão com %s de %s!" % [f[d].short_name(), _strike_name(kind, true, att), f[att].short_name()])
			# Quem derrubou parte para cima no chão ou deixa levantar.
			if int(plans[att]["por_cima"]) != 3 and rng.randf() < 0.7:
				pos = "chao"
				top = att
				gpos = "guarda" if rng.randf() < 0.5 else "lateral"
				for _k in rng.randi_range(2, 4):
					_gnp(att)
					if finished:
						break
			return true
		_log(att, "forte", "%s acerta %s e %s sente! %s está balançado." % [f[att].short_name(), _strike_name(kind, true, att), f[d].short_name(), f[d].short_name()])
	elif narrate and (dmg > 0.85 or rng.randf() < 0.35):
		_log(att, "golpe" if dmg < 1.0 else "forte", _hit_text(att, kind, "head", dmg, counter))
	_check_tko(att)
	return true


## Parada do árbitro: balançado e apanhando sem responder.
func _check_tko(att: int) -> void:
	var d := 1 - att
	if finished:
		return
	if float(s[d]["rock"]) > 0.42 and int(s[d]["unans"]) >= 3:
		var p := (float(s[d]["rock"]) - 0.3) * 0.85 * ref_stop
		if rng.randf() < p:
			_finish(att, "TKO", "nocaute técnico (socos)" if pos != "chao" else "nocaute técnico (socos no chão)")
			_log(att, "fim", "%s não se defende mais e o árbitro entra. Nocaute técnico!" % f[d].short_name())


func _stance_edge(att: int, kind: String) -> float:
	var sa := _stance(att)
	var sd := _stance(1 - att)
	var e := 0.0
	if sa != sd and kind in ["direto", "chute_corpo"]:
		e += 0.03
	if sa == 1 and sd == 0:
		e += 0.015
	var natural := 1 if f[att].southpaw else 0
	if sa != natural and f[att].a("qi") < 75.0:
		e -= 0.035
	return e


## 0 ortodoxa, 1 canhota (a escolhida no plano ou a natural).
func _stance(i: int) -> int:
	var b := int(plans[i]["base"])
	if b == 0:
		return 1 if f[i].southpaw else 0
	return b - 1


# --- Quedas e clinch ----------------------------------------------------------------------

func _takedown(i: int, from_clinch: bool, depth: int = 0) -> void:
	var o := 1 - i
	var tech := _pick_td(i, from_clinch)
	# Puxar para a guarda: só quem confia no jogo de costas e quer finalizar de lá.
	if tech == "puxar_guarda":
		if int(plans[i]["por_baixo"]) == 2 and _at(i, "por_baixo") >= _at(o, "por_cima"):
			pos = "chao"
			top = o
			gpos = "guarda"
			_spend(i, 0.006)
			_log(i, "chao", _say(Styles.takedown(tech).get("texts", ["{a} puxa {b} para a guarda."]), i))
			return
		tech = "single"
	var td := Styles.takedown(tech)
	var rs: Array = round_stats.back()
	rs[i]["td_att"] += 1
	s[i]["total"]["td_att"] += 1
	var off := _at(i, "queda") * 0.65 + _at(i, "forca") * 0.15 + _at(i, "velocidade") * 0.2
	var dfn := _at(o, "def_queda") * 0.7 + _at(o, "forca") * 0.15 + _at(o, "movimentacao") * 0.15
	var p := 0.36 + (off - dfn) / 150.0 + float(s[o]["legs"]) * 0.1 + float(s[o]["rock"]) * 0.3
	p += (float(s[i]["st"]) - float(s[o]["st"])) * 0.15
	if from_clinch:
		p += 0.08 + (_at(i, "clinch") - _at(o, "clinch")) / 300.0 + 0.05 * _tr(i, "throws")
	if depth > 0:
		p += 0.04
	p = clampf(p, 0.05, 0.9)
	_spend(i, 0.022)
	_spend(o, 0.008)
	if rng.randf() < p:
		rs[i]["td"] += 1
		s[i]["total"]["td"] += 1
		pos = "chao"
		top = i
		# Onde cai: cada técnica tem o seu lugar (o judoca cai nos cem quilos, a baiana na guarda);
		# quem é melhor por cima ainda melhora a posição.
		var land: Dictionary = (td.get("land", {"guarda": 5, "meia": 3, "lateral": 1}) as Dictionary).duplicate()
		var edge := clampf((_at(i, "por_cima") - _at(o, "por_baixo")) / 60.0, -0.6, 0.8)
		if land.has("lateral"):
			land["lateral"] = float(land["lateral"]) * (1.0 + edge)
		gpos = String(RngUtil.weighted_key(rng, land))
		var texts: Array = td.get("texts", ["{a} derruba {b}."])
		_log(i, "queda", "%s %s" % [_say(texts, i), _say([GPOS_IN[gpos]], i)])
		# Arremesso e slam machucam.
		var dmg := float(td.get("dmg", 0.0))
		if dmg > 0.0:
			var hit := dmg * rng.randf_range(0.6, 1.3) * (1.0 + _at(i, "forca") / 200.0)
			s[o]["head"] = float(s[o]["head"]) + hit * 0.05
			s[o]["body"] = float(s[o]["body"]) + hit * 0.06
			s[o]["st"] = maxf(0.05, float(s[o]["st"]) - hit * 0.05)
			rs[i]["dmg"] += hit
			s[i]["total"]["dmg"] += hit
			if hit > 0.7 and rng.randf() < 0.3:
				s[o]["rock"] = minf(1.0, float(s[o]["rock"]) + 0.2)
				_log(i, "forte", "O impacto balança %s!" % f[o].short_name())
		return
	# Errou a queda: quem pega pescoço pune a entrada; quem encadeia tenta de novo.
	if not from_clinch and _front_headlock(o):
		return
	if depth == 0 and rng.randf() < 0.3 * _tr(i, "chain"):
		pos = "clinch"
		cage = true
		_log(i, "info", _say(["{a} não solta: emenda a segunda entrada e prensa {b} na grade.", "{b} defende, mas {a} já está na outra perna.", "{a} corre {b} até a grade e continua na queda."], i))
		_takedown(i, true, depth + 1)
		return
	if narrate:
		_log(o, "info", _say(["{a} defende a queda e se solta.", "{a} sprawla e anula a entrada de {b}.", "{a} mantém a luta em pé."], o))
	if not from_clinch and rng.randf() < 0.3:
		pos = "clinch"
		cage = true


## Técnica de queda do lado `i`, pelo repertório e por onde a luta está.
func _pick_td(i: int, from_clinch: bool) -> String:
	var w := {}
	var tds: Dictionary = prof[i]["td"]
	for k: String in tds:
		var fr := String(Styles.takedown(k).get("from", "ambos"))
		if fr == "ambos" or (fr == "clinch") == from_clinch:
			w[k] = float(tds[k])
	if w.is_empty():
		return "corpo" if from_clinch else "duas_pernas"
	return String(RngUtil.weighted_key(rng, w))


## Quem defende a queda de cabeça baixa do outro pode pegar o pescoço: guilhotina puxando para a
## guarda, ou sprawl e d'arce/anaconda por cima. Devolve se aconteceu.
func _front_headlock(o: int) -> bool:
	var i := 1 - o
	var ch := (0.03 + 0.12 * _tr(o, "guillotine")) * clampf((_at(o, "finalizacao") - 40.0) / 40.0, 0.2, 1.4)
	if rng.randf() >= ch:
		return false
	var w := {}
	var subs: Dictionary = prof[o]["subs"]
	for k: String in subs:
		if bool(Styles.sub(k).get("pe", false)):
			w[k] = float(subs[k])
	var sid := "guilhotina" if w.is_empty() else String(RngUtil.weighted_key(rng, w))
	pos = "chao"
	if sid == "guilhotina":
		top = i
		gpos = "guarda"
		_log(o, "fin", _say(["{a} abraça o pescoço de {b} na entrada e puxa a guilhotina!", "{b} entra de cabeça baixa e {a} fecha a guilhotina!"], o))
	else:
		top = o
		gpos = "meia"
		_log(o, "fin", "%s sprawla, passa o braço por baixo e cai n%s %s!" % [f[o].short_name(), String(Styles.sub(sid).get("art", "o")), String(Styles.sub(sid)["name"])])
	_sub_attempt(o, sid, true)
	return true


## O especialista segura o chute e derruba (sanda, tailandês). `landed`: depois de levar o chute
## no corpo. Devolve se tentou.
func _catch_kick(d: int, att: int, landed: bool) -> bool:
	var ch := 0.1 * _tr(d, "catch") + (0.01 if landed else 0.02)
	if pos != "solto" or finished or rng.randf() >= ch:
		return false
	var rs: Array = round_stats.back()
	rs[d]["td_att"] += 1
	s[d]["total"]["td_att"] += 1
	var p := 0.5 + (_at(d, "queda") + _at(d, "clinch") - _at(att, "def_queda") - _at(att, "movimentacao")) / 200.0
	if rng.randf() < clampf(p, 0.15, 0.85):
		rs[d]["td"] += 1
		s[d]["total"]["td"] += 1
		pos = "chao"
		top = d
		gpos = "guarda" if rng.randf() < 0.6 else "meia"
		_log(d, "queda", _say(["{a} segura o chute de {b} e derruba com uma rasteira!", "{a} prende a perna de {b} debaixo do braço e varre o pé de apoio."], d))
	elif narrate:
		_log(d, "info", _say(["{a} segura o chute, mas {b} se equilibra num pé só e solta.", "{a} agarra a perna, {b} pula e se livra."], d))
	return true


func _tick_clinch(dt: float) -> void:
	var c := [0.0, 0.0]
	for i in 2:
		c[i] = _at(i, "clinch") * 0.6 + _at(i, "forca") * 0.4 + 8.0 * maxf(_tr(i, "plum"), _tr(i, "cage")) + 4.0 * _tr(i, "throws")
	var dom := 0 if rng.randf() < c[0] / (c[0] + c[1]) else 1
	var rs: Array = round_stats.back()
	if cage:
		rs[dom]["ctrl"] += dt * 0.5
		s[dom]["total"]["ctrl"] += dt * 0.5
	# Quem não quer o clinch tenta sair.
	for i in 2:
		if int(plans[i]["distancia"]) < 2 and int(plans[i]["jogo"]) < 2:
			var pb := 0.24 + (_at(i, "movimentacao") + _at(i, "forca") - _at(1 - i, "clinch") - _at(1 - i, "forca")) / 220.0
			if rng.randf() < pb:
				pos = "solto"
				dist = 1
				if narrate and rng.randf() < 0.5:
					_log(i, "info", "%s desfaz o clinch e volta para o centro." % f[i].short_name())
				return
	# Queda do clinch
	for i in 2:
		var intent: float = [0.02, 0.16, 0.36][int(plans[i]["jogo"])] * (0.5 + _at(i, "queda") / 100.0)
		intent *= 1.0 + 0.5 * _tr(i, "throws") + 0.3 * _tr(i, "cage")
		if rng.randf() < intent * (1.3 if i == dom else 0.7):
			_takedown(i, true)
			return
	# Golpes curtos
	var att := dom if rng.randf() < 0.7 else 1 - dom
	var n := rng.randi_range(1, 3)
	for k in n:
		var dirty := 1.0 + _tr(att, "dirty")
		var kind: String = RngUtil.weighted_key(rng, {"joelhada": 1.6 * (1.0 + _tr(att, "plum")), "cotovelada": 0.6 * (1.0 + _tr(att, "elbows") + 0.5 * _tr(att, "plum")),
			"gancho": 1.0 * dirty, "uppercut": 0.8 * dirty})
		_strike(att, k, false, kind, 2)
		if finished or pos != "clinch":
			return
	_spend(0, 0.004)
	_spend(1, 0.004)
	if narrate and rng.randf() < 0.2:
		_log(dom, "info", "%s trabalha %s." % [f[dom].short_name(), "prensando na grade" if cage else ("as joelhadas pela nuca" if _tr(dom, "plum") >= 0.6 else "no clinch pelo pescoço")])


# --- Chão ---------------------------------------------------------------------------------

func _tick_ground(dt: float) -> void:
	var tp := top
	var bt := 1 - top
	var rs: Array = round_stats.back()
	rs[tp]["ctrl"] += dt
	s[tp]["total"]["ctrl"] += dt
	var p_top := 0.6 + (_at(tp, "por_cima") - _at(bt, "por_baixo")) / 200.0 + 0.04 * _tr(tp, "ride") - 0.04 * _tr(bt, "guard")
	if rng.randf() < p_top:
		match int(plans[tp]["por_cima"]):
			0:
				for _k in rng.randi_range(1, 3):
					_gnp(tp)
					if finished:
						return
				if rng.randf() < 0.14:
					_advance(tp)
			1:
				if _can_sub_from_top() and rng.randf() < 0.16 + 0.05 * (_tr(tp, "back") + _tr(tp, "legs")):
					_sub_attempt(tp, _pick_sub(tp, true))
				else:
					_advance(tp)
			2:
				if rng.randf() < 0.4:
					_advance(tp)
				elif rng.randf() < 0.35:
					_gnp(tp)
			3:
				pos = "solto"
				dist = 1
				_log(tp, "info", "%s se levanta e deixa %s voltar." % [f[tp].short_name(), f[bt].short_name()])
				return
	else:
		match int(plans[bt]["por_baixo"]):
			0:
				_get_up(bt)
			1:
				if gpos in ["guarda", "meia"]:
					# Quem joga de perna entra no pé do outro em vez de raspar.
					if rng.randf() < 0.25 * _tr(bt, "legs"):
						_sub_attempt(bt, _pick_sub(bt, false, true))
					else:
						_sweep(bt)
				else:
					_recover(bt)
			2:
				if gpos in ["guarda", "meia"] and rng.randf() < 0.22 + 0.12 * _tr(bt, "guard") + 0.08 * _tr(bt, "legs"):
					_sub_attempt(bt, _pick_sub(bt, false))
				else:
					_recover(bt)
	_spend(tp, 0.003)
	_spend(bt, 0.005)


func _gnp(tp: int) -> void:
	var bt := 1 - tp
	var rs: Array = round_stats.back()
	rs[tp]["sig_att"] += 1
	s[tp]["total"]["sig_att"] += 1
	var pos_acc: float = {"guarda": -0.08, "meia": 0.0, "lateral": 0.08, "montada": 0.15, "costas": 0.12}.get(gpos, 0.0)
	var acc := clampf(0.52 + (_at(tp, "por_cima") - _at(bt, "por_baixo")) / 150.0 + pos_acc + float(s[bt]["rock"]) * 0.2 + 0.04 * _tr(tp, "gnp"), 0.15, 0.9)
	_spend(tp, 0.003)
	if rng.randf() >= acc:
		s[bt]["unans"] = 0
		return
	rs[tp]["sig_land"] += 1
	s[tp]["total"]["sig_land"] += 1
	var mult: float = {"guarda": 0.75, "meia": 0.9, "lateral": 1.05, "montada": 1.3, "costas": 1.1}.get(gpos, 1.0)
	var dmg := 0.55 * mult * (0.5 + _at(tp, "potencia") / 100.0 * 0.5 + _at(tp, "forca") / 250.0) * ko_factor * rng.randf_range(0.6, 1.3) * (1.0 + 0.25 * _tr(tp, "gnp"))
	rs[tp]["dmg"] += dmg
	s[tp]["total"]["dmg"] += dmg
	s[bt]["unans"] = int(s[bt]["unans"]) + 1
	if rng.randf() < 0.75:
		rs[tp]["head"] += 1
		s[tp]["total"]["head"] += 1
		var chin := _at(bt, "queixo")
		var shock := dmg * (1.0 + float(s[bt]["head"]) * 0.55) * (1.3 - chin / 100.0 * 0.6)
		s[bt]["head"] = float(s[bt]["head"]) + dmg * 0.08
		if rng.randf() < clampf((shock - 0.8) * 0.45, 0.0, 0.5):
			s[bt]["rock"] = minf(1.0, float(s[bt]["rock"]) + 0.25)
		if rng.randf() < dmg * 0.04 * (2.5 if rng.randf() < 0.25 else 1.0):
			s[bt]["cut"] = float(s[bt]["cut"]) + rng.randf_range(0.15, 0.4)
		if narrate and (dmg > 0.8 or rng.randf() < 0.3):
			_log(tp, "golpe" if dmg < 0.95 else "forte", _say(["{a} castiga {b} com socos por cima.", "Cotovelada de {a} de cima para baixo em {b}!", "{a} solta o peso das mãos em {b}.", "Martelada de {a} na cabeça de {b}."], tp))
		# No chão o árbitro para quando quem está embaixo não se defende mais.
		if gpos in ["lateral", "montada", "costas"] or float(s[bt]["rock"]) > 0.55:
			if float(s[bt]["rock"]) > 0.35 and int(s[bt]["unans"]) >= 4:
				var p := (float(s[bt]["rock"]) * 0.5 + int(s[bt]["unans"]) * 0.03) * ref_stop * 0.55
				if rng.randf() < p:
					_finish(tp, "TKO", "nocaute técnico (socos no chão)")
					_log(tp, "fim", "%s só cobre o rosto, %s continua batendo e o árbitro encerra!" % [f[bt].short_name(), f[tp].short_name()])
	else:
		rs[tp]["body"] += 1
		s[tp]["total"]["body"] += 1
		s[bt]["body"] = float(s[bt]["body"]) + dmg * 0.08
		s[bt]["st"] = maxf(0.05, float(s[bt]["st"]) - dmg * 0.04)


func _advance(tp: int) -> void:
	var bt := 1 - tp
	var p := 0.24 + (_at(tp, "por_cima") - _at(bt, "por_baixo")) / 150.0
	if rng.randf() >= p:
		if narrate and rng.randf() < 0.25:
			_log(bt, "info", "%s segura bem por baixo e não deixa %s passar." % [f[bt].short_name(), f[tp].short_name()])
		return
	var i := GROUND_ORDER.find(gpos)
	var nxt := gpos
	if gpos == "costas":
		return
	if gpos in ["lateral", "montada"] and rng.randf() < 0.3 + 0.25 * _tr(tp, "back"):
		nxt = "costas"
	elif gpos == "meia" and rng.randf() < 0.12 * maxf(_tr(tp, "back"), _tr(tp, "ride")):
		nxt = "costas"
	elif i >= 0 and i < GROUND_ORDER.size() - 1:
		nxt = GROUND_ORDER[i + 1]
	if nxt == gpos:
		return
	gpos = nxt
	var rs: Array = round_stats.back()
	rs[tp]["adv"] += 1
	s[tp]["total"]["adv"] += 1
	var txt := {"meia": "{a} passa para a meia-guarda.", "lateral": "{a} passa a guarda e estabiliza nos cem quilos.", "montada": "{a} monta! Posição perigosa para {b}.", "costas": "{a} pega as costas de {b}!"}
	_log(tp, "chao", _say([txt[gpos]], tp))


func _get_up(bt: int) -> void:
	var tp := 1 - bt
	var pen: float = {"guarda": 0.05, "meia": 0.0, "lateral": -0.08, "montada": -0.13, "costas": -0.1}.get(gpos, 0.0)
	var p := 0.22 + (_at(bt, "por_baixo") * 0.4 + _at(bt, "forca") * 0.3 + _at(bt, "velocidade") * 0.3 - _at(tp, "por_cima") * 0.7 - _at(tp, "forca") * 0.3) / 120.0 + pen
	p += 0.06 * _tr(bt, "scramble") - 0.05 * _tr(tp, "ride")
	_spend(bt, 0.012)
	if rng.randf() < clampf(p, 0.04, 0.75):
		# Wrestler de controle devolve ao chão quem levanta (o "mat return").
		if rng.randf() < 0.22 * _tr(tp, "ride") * clampf(_at(tp, "queda") / 70.0, 0.5, 1.3):
			var rs: Array = round_stats.back()
			rs[tp]["td_att"] += 1
			rs[tp]["td"] += 1
			s[tp]["total"]["td_att"] += 1
			s[tp]["total"]["td"] += 1
			gpos = "costas" if rng.randf() < 0.25 * _tr(tp, "back") + 0.1 else "meia"
			_spend(bt, 0.01)
			_log(tp, "queda", _say(["{b} levanta, mas {a} cola nas costas e devolve ao chão.", "{b} quase sai, {a} prende a cintura e derruba de novo.", "Mat return de {a}: {b} volta para o chão."], tp))
			return
		if rng.randf() < 0.4:
			pos = "clinch"
			cage = true
			_log(bt, "info", "%s levanta pela grade, ainda preso no clinch." % f[bt].short_name())
		else:
			pos = "solto"
			dist = 1
			_log(bt, "info", "%s consegue se levantar." % f[bt].short_name())
	elif narrate and rng.randf() < 0.2:
		_log(bt, "info", "%s tenta levantar, mas %s segura." % [f[bt].short_name(), f[tp].short_name()])


func _sweep(bt: int) -> void:
	var tp := 1 - bt
	var p := 0.17 + (_at(bt, "por_baixo") - _at(tp, "por_cima")) / 130.0
	_spend(bt, 0.01)
	if rng.randf() < clampf(p, 0.03, 0.6):
		top = bt
		gpos = "meia" if rng.randf() < 0.5 else "guarda"
		var rs: Array = round_stats.back()
		rs[bt]["rev"] += 1
		s[bt]["total"]["rev"] += 1
		_log(bt, "chao", "%s raspa e fica por cima de %s!" % [f[bt].short_name(), f[tp].short_name()])


func _recover(bt: int) -> void:
	var tp := 1 - bt
	var p := 0.18 + (_at(bt, "por_baixo") - _at(tp, "por_cima")) / 140.0
	if gpos in ["lateral", "montada", "costas"] and rng.randf() < p:
		gpos = "meia" if gpos != "costas" else "lateral"
		if narrate and rng.randf() < 0.5:
			_log(bt, "info", "%s repõe a guarda." % f[bt].short_name())
	else:
		_get_up(bt)


func _can_sub_from_top() -> bool:
	return gpos in ["meia", "lateral", "montada", "costas"]


## Finalização do lado `i` pelo repertório e pela posição (por cima ou por baixo). `legs_only`:
## só chave de perna.
func _pick_sub(i: int, on_top: bool, legs_only: bool = false) -> String:
	var w := {}
	var subs: Dictionary = prof[i]["subs"]
	var side := "top" if on_top else "bottom"
	for k: String in subs:
		var info := Styles.sub(k)
		if legs_only and not bool(info.get("leg", false)):
			continue
		if gpos in (info.get(side, []) as Array):
			w[k] = float(subs[k])
	if w.is_empty():
		if legs_only:
			return "chave_calcanhar" if gpos != "guarda" else "botinha"
		match gpos:
			"costas":
				return "mata_leao"
			"montada":
				return "chave_braco"
			"lateral":
				return "kimura"
			"meia":
				return "guilhotina" if not on_top else "kimura"
		return "triangulo" if not on_top else "katagatame"
	return String(RngUtil.weighted_key(rng, w))


## Tentativa de finalização `sid` (ver styles.json › subs). `announced`: o lance já foi narrado.
func _sub_attempt(i: int, sid: String, announced: bool = false) -> void:
	var o := 1 - i
	var info := Styles.sub(sid)
	var name := String(info.get("name", sid))
	var art := "a" if String(info.get("art", "a")) == "a" else ""
	var rs: Array = round_stats.back()
	rs[i]["sub_att"] += 1
	s[i]["total"]["sub_att"] += 1
	var off := _at(i, "finalizacao") * 0.75 + _at(i, "forca") * 0.1 + _at(i, "qi") * 0.15
	var dfn := _at(o, "def_finalizacao") * 0.75 + _at(o, "forca") * 0.1 + _at(o, "qi") * 0.15
	var bonus: float = {"costas": 0.14, "montada": 0.08, "lateral": 0.05, "meia": 0.02, "guarda": 0.0}.get(gpos, 0.0)
	if i != top:
		bonus = -0.04
	# Chave de perna contra quem nunca treinou isso: o calcanhar estoura antes de bater.
	if bool(info.get("leg", false)):
		bonus += 0.03 * _tr(i, "legs") + (0.05 if _tr(o, "legs") < 0.3 else -0.03)
	var p_lock := clampf(0.17 + (off - dfn) / 130.0 + bonus + (1.0 - float(s[o]["st"])) * 0.15 + float(s[o]["rock"]) * 0.25, 0.03, 0.75)
	_spend(i, 0.018)
	if rng.randf() >= p_lock:
		if narrate and not announced:
			_log(o, "info", "%s ameaça um%s %s, mas %s se defende." % [f[i].short_name(), art, name, f[o].short_name()])
		elif narrate:
			_log(o, "info", "%s tira a cabeça e escapa da %s." % [f[o].short_name(), name] if art == "a" else "%s escapa do %s." % [f[o].short_name(), name])
		if i != top and rng.randf() < 0.25:
			_advance(top)
		return
	if not announced:
		_log(i, "fin", "%s encaixa um%s %s!" % [f[i].short_name(), art, name])
	var p_tap := clampf(0.32 + (off - dfn) / 120.0 + (1.0 - float(s[o]["st"])) * 0.2 + float(s[o]["rock"]) * 0.25 - _at(o, "coracao") / 900.0, 0.06, 0.85)
	if rng.randf() < p_tap:
		_finish(i, "FIN", "finalização (%s)" % name)
		_log(i, "fim", "%s bate! Vitória de %s por finalização." % [f[o].short_name(), f[i].short_name()])
	else:
		_spend(o, 0.05)
		_log(o, "info", "%s aguenta firme e escapa d%s %s." % [f[o].short_name(), "a" if art == "a" else "o", name])
		if i != top and rng.randf() < 0.3:
			top = i
			gpos = "guarda"


# --- Fim de luta, pontuação ----------------------------------------------------------------

func _finish(winner: int, method: String, detail: String) -> void:
	finished = true
	result = {"winner": winner, "method": method, "detail": detail, "round": round_no, "time": minf(ROUND_S, t)}


func _score_round() -> void:
	var rs: Array = round_stats.back()
	var raw := [0.0, 0.0]
	for j in 3:
		var jd: Dictionary = judges[j]
		var sc := [0.0, 0.0]
		for i in 2:
			var st: Dictionary = rs[i]
			var strike := float(st["head"]) * 1.0 + float(st["body"]) * 0.8 + float(st["legs"]) * 0.6 + float(st["kd"]) * 10.0 + float(st["dmg"]) * 2.5
			var grap := float(st["td"]) * 2.5 + float(st["ctrl"]) / 20.0 + float(st["sub_att"]) * 2.0 + float(st["rev"]) * 1.5 + float(st["adv"]) * 1.0
			var agg := float(st["sig_att"]) * 0.08 + float(st["td_att"]) * 0.3
			sc[i] = strike * float(jd["st"]) + grap * float(jd["gr"]) + agg * float(jd["ag"]) + rng.randfn(0.0, float(jd["noise"]))
			raw[i] += sc[i]
		var diff: float = sc[0] - sc[1]
		var card := [10, 10]
		if absf(diff) >= 0.04:
			var w := 0 if diff > 0 else 1
			var l := 1 - w
			card[l] = 9
			var dominant: bool = sc[l] <= 0.0 or sc[w] / maxf(0.5, sc[l]) > 4.0
			if dominant and (int(rs[w]["kd"]) >= 1 or float(rs[w]["dmg"]) > 10.0 or float(rs[w]["ctrl"]) > 220.0) and rng.randf() < 0.4:
				card[l] = 8
		cards[j].append(card)


func finalize() -> Dictionary:
	if finished:
		result["stats"] = [s[0]["total"], s[1]["total"]]
		return result
	var votes := [0, 0]
	var totals: Array = []
	for j in 3:
		var tot := [0, 0]
		for c: Array in cards[j]:
			tot[0] += int(c[0])
			tot[1] += int(c[1])
		totals.append(tot)
		if tot[0] > tot[1]:
			votes[0] += 1
		elif tot[1] > tot[0]:
			votes[1] += 1
	var method := "DEC"
	var winner := -1
	var detail := ""
	if votes[0] >= 2 or votes[1] >= 2:
		winner = 0 if votes[0] > votes[1] else 1
		var against: int = votes[1 - winner]
		if votes[winner] == 3:
			detail = "decisão unânime"
		elif against == 1:
			detail = "decisão dividida"
		else:
			detail = "decisão majoritária"
	else:
		method = "EMP"
		detail = "empate"
	result = {"winner": winner, "method": method, "detail": detail, "round": rounds, "time": ROUND_S, "cards": totals,
		"stats": [s[0]["total"], s[1]["total"]]}
	return result


# --- Narração -----------------------------------------------------------------------------

func _log(side: int, kind: String, text: String) -> void:
	var ev := {"r": round_no, "t": t, "side": side, "kind": kind, "text": text,
		"st": [float(s[0]["st"]), float(s[1]["st"])], "hd": [float(s[0]["head"]), float(s[1]["head"])],
		"pos": pos if pos != "chao" else "chao:" + gpos + ":" + str(top)}
	if not narrate and kind != "fim":
		return
	_round_events.append(ev)
	events.append(ev)


func _pick(arr: Array) -> String:
	return String(arr[rng.randi_range(0, arr.size() - 1)])


const STRIKE_NAMES := {"jab": "o jab", "direto": "um direto", "gancho": "um gancho", "uppercut": "um uppercut",
	"overhand": "um overhand", "chute_baixo": "um chute baixo", "chute_corpo": "um chute no corpo",
	"chute_alto": "um chute alto", "chute_frontal": "um chute frontal", "joelhada": "uma joelhada", "cotovelada": "uma cotovelada",
	"chute_panturrilha": "um chute na panturrilha", "chute_obliquo": "um chute oblíquo no joelho", "chute_giratorio": "um chute giratório",
	"chute_rodado": "um chute rodado", "backfist": "um backfist giratório", "superman": "um superman punch", "joelhada_voadora": "uma joelhada voadora"}


## Nome do golpe ("um chute circular" para o tailandês, "uma meia-lua de compasso" para o capoeirista).
func _strike_name(kind: String, with_article: bool = false, att: int = -1) -> String:
	var custom := _custom_name(att, kind)
	if custom != "":
		var first := custom.split(" ")[0]
		var t3 := ("uma " if first.ends_with("a") else "um ") + custom
		return t3 if with_article else custom
	var t2: String = STRIKE_NAMES.get(kind, "um golpe")
	if with_article:
		return t2
	return t2.split(" ", true, 1)[1]


func _custom_name(att: int, kind: String) -> String:
	if att < 0 or att > 1 or prof.size() < 2 or (prof[att] as Dictionary).is_empty():
		return ""
	return String((prof[att]["names"] as Dictionary).get(kind, ""))


func _hit_text(att: int, kind: String, zone: String, _dmg: float, counter: bool = false) -> String:
	var a := f[att].short_name()
	var b := f[1 - att].short_name()
	var t2 := ""
	var custom := _custom_name(att, kind)
	if custom != "" and rng.randf() < 0.6:
		var where: String = {"head": "na cabeça de", "body": "no corpo de", "legs": "na perna de"}.get(zone, "em")
		t2 = "%s acerta %s %s %s." % [a, _strike_name(kind, true, att), where, b]
		return ("No contragolpe: " + t2) if counter else t2
	match kind:
		"jab":
			t2 = _pick(["%s encaixa o jab em %s.", "Jab firme de %s na cara de %s.", "%s pontua com o jab em %s."]) % [a, b]
		"direto":
			if zone == "head":
				t2 = _pick(["Direto de %s entra limpo em %s.", "%s conecta o direto no queixo de %s.", "%s acerta a reta em %s."]) % [a, b]
			else:
				t2 = "%s afunda um direto no estômago de %s." % [a, b]
		"gancho":
			if zone == "head":
				t2 = _pick(["Gancho de %s pega em cheio em %s!", "%s acha o gancho na têmpora de %s.", "%s vira o gancho e acerta %s."]) % [a, b]
			else:
				t2 = "%s solta um gancho no fígado de %s." % [a, b]
		"uppercut":
			t2 = "Uppercut de %s levanta o queixo de %s." % [a, b]
		"overhand":
			t2 = "%s acerta um overhand por cima da guarda de %s." % [a, b]
		"chute_baixo":
			t2 = _pick(["%s castiga a perna da frente de %s com um chute baixo.", "Chute baixo de %s estala na coxa de %s.", "%s acerta o chute na panturrilha de %s."]) % [a, b]
		"chute_corpo":
			t2 = _pick(["Chute no corpo de %s ecoa no ginásio. %s sente.", "%s acerta o chute nas costelas de %s."]) % [a, b]
		"chute_alto":
			t2 = "Chute alto de %s raspa a cabeça de %s!" % [a, b]
		"chute_frontal":
			t2 = "%s afasta %s com um chute frontal na linha da cintura." % [a, b]
		"joelhada":
			t2 = "Joelhada de %s no %s de %s." % [a, "rosto" if zone == "head" else "corpo", b]
		"cotovelada":
			t2 = _pick(["%s acerta uma cotovelada curta em %s.", "Cotovelada de %s rasga a sobrancelha de %s.", "%s gira a cotovelada na saída do clinch e pega %s."]) % [a, b]
		"chute_panturrilha":
			t2 = _pick(["Chute na panturrilha de %s: a perna de %s dobra.", "%s castiga a panturrilha de %s.", "%s acha de novo a panturrilha de %s. Já está mancando."]) % [a, b]
		"chute_obliquo":
			t2 = "%s pisa no joelho da frente de %s com um chute oblíquo." % [a, b]
		"chute_giratorio":
			t2 = ("%s gira e crava o chute no fígado de %s!" if zone == "body" else "%s gira e acerta o chute na cabeça de %s!") % [a, b]
		"chute_rodado":
			t2 = "Chute rodado de %s pega a cabeça de %s!" % [a, b]
		"backfist":
			t2 = "Backfist giratório de %s estala no rosto de %s!" % [a, b]
		"superman":
			t2 = "%s salta num superman punch e acerta %s." % [a, b]
		"joelhada_voadora":
			t2 = "%s voa com a joelhada e acerta o rosto de %s!" % [a, b]
		_:
			t2 = "%s acerta %s." % [a, b]
	if counter:
		return "No contragolpe: " + t2
	return t2


func _miss_text(att: int, kind: String) -> String:
	if kind in SPINNING:
		return _say(["{a} tenta o giratório e {b} sai do caminho.", "{a} gira, erra e quase fica de costas para {b}."], att)
	if kind == "joelhada_voadora":
		return _say(["{a} voa com a joelhada, {b} desvia e {a} cai desequilibrado."], att)
	if kind.begins_with("chute"):
		return _say(["{a} chuta e {b} bloqueia com a canela.", "{b} segura o chute e empurra {a}.", "{b} recua e o chute de {a} passa no vazio."], att)
	return _say(["{a} solta a combinação e {b} esquiva.", "{b} bloqueia o golpe de {a}.", "{b} gira a cintura e {a} erra."], att)


## Uma frase sorteada com {a} = lado `i` e {b} = o outro.
func _say(templates: Array, i: int) -> String:
	return _pick(templates).format({"a": f[i].short_name(), "b": f[1 - i].short_name()})


func _ko_text(att: int, kind: String) -> String:
	var a := f[att].short_name()
	var b := f[1 - att].short_name()
	if rng.randf() < 0.5:
		return "%s acerta %s e %s apaga! Nocaute!" % [a, _strike_name(kind, true, att), b]
	if kind in SPINNING or kind == "joelhada_voadora":
		return "Que golpe! %s acerta %s e %s cai duro. Nocaute de destaque da noite!" % [a, _strike_name(kind, true, att), b]
	return "Que golpe! %s derruba %s com %s e o árbitro abraça. Nocaute!" % [a, b, _strike_name(kind, true, att)]
