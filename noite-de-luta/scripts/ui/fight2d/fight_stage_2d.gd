class_name FightStage2D
extends Control
## A luta animada em 2D, de lado, como numa transmissão: dois `Rig2D` no octógono que encenam os
## lances estruturados do motor (`FightEngine.beats`). A tela da luta entrega cada lance quando o
## relógio passa por ele (`add_beat`); aqui eles tocam em fila, um depois do outro, e a fila acelera
## quando acumula (velocidade rápida, "Pular").
##
## Cada quadro: pose de base do momento (em pé na guarda da escola, clinch, posição no chão, fim)
## + o movimento do lance em andamento (golpe com preparação, extensão e volta; queda; ground and
## pound; finalização...) + vida (balanço, cansaço, passos) → as poses andam suavemente até esse alvo.
##
## Por cima disso, a transmissão: uma câmera que enquadra a ação (abre nas quedas, fecha no clinch
## e no chão), a pausa de impacto e os efeitos do golpe (onda, suor, rastro, clarão), a
## apresentação dos dois no round 1 e as legendas. A vista 3D lê as mesmas poses e lances; o que é
## só desta vista (câmera, placas, rastro) fica no desenho.

const ARENA := 15.0 ## meia largura do octógono, em U
const GAP := [5.4, 4.3, 3.3] ## distância entre as cinturas por distância do motor (longa, média, curta)
## Duração base de cada lance, em segundos de tela.
const DUR := {"golpe": 0.42, "chute": 0.58, "giro": 0.75, "kd": 1.7, "balanca": 0.9, "clinch": 0.55, "solta": 0.5, "estudo": 0.7,
	"queda": 1.15, "puxa_guarda": 0.9, "segura_chute": 1.0, "pega_pescoco": 0.9, "gnp": 0.34, "passa": 0.75, "levanta": 0.9,
	"mat_return": 1.0, "raspa": 1.0, "repoe": 0.7, "fin": 1.5, "escapa": 0.7, "fim": 2.2, "round": 1.1, "fim_round": 0.6}
## Apresentação do round 1: duração e onde cada um espera (no seu canto), em U.
const INTRO_S := 4.4
const CORNER_X := 11.0
## Quanto cada efeito fica na tela, em segundos.
const FX_LIFE := {"hit": 0.5, "blood": 0.9, "dust": 0.5, "ring": 0.42, "sweat": 0.7, "block": 0.3, "mouth": 1.3}
## Em que ponto do lance o corpo já vai para a posição nova (quedas, raspagens).
const SWITCH := {"queda": 0.5, "puxa_guarda": 0.35, "segura_chute": 0.6, "raspa": 0.5, "levanta": 0.35, "mat_return": 0.55, "passa": 0.3}
const THROWS := ["suplex", "uchi_mata", "seoi", "harai", "quadril", "corpo", "levantamento", "pegada_cinto"]
const KICKS := ["chute_baixo", "chute_corpo", "chute_alto", "chute_frontal", "chute_panturrilha", "chute_obliquo", "joelhada", "joelhada_voadora"]
const SPINS := ["chute_giratorio", "chute_rodado"]
## Golpes: pose estendida. Chaves com L/R são o braço/perna da frente/de trás (La_s, Rl_h...).
const STRIKE := {
	"jab": {"tw": 12.0, "La_s": 97.0, "La_e": 2.0, "torso": 10.0, "head": 6.0, "x": 0.75},
	"direto": {"tw": 48.0, "Ra_s": 94.0, "Ra_e": 4.0, "La_s": 70.0, "La_e": 130.0, "torso": 20.0, "x": 0.75, "Rl_h": -32.0, "Rl_k": 10.0},
	"gancho": {"tw": -38.0, "La_s": 92.0, "La_e": 75.0, "torso": 6.0, "head": 4.0, "x": 0.35, "crouch": 0.3},
	"uppercut": {"tw": 28.0, "Ra_s": 55.0, "Ra_e": 95.0, "torso": 10.0, "x": 0.5, "crouch": 0.35},
	"overhand": {"tw": 55.0, "Ra_s": 150.0, "Ra_e": -55.0, "torso": 32.0, "x": 0.9, "crouch": 0.3},
	"backfist": {"tw": -25.0, "La_s": 102.0, "La_e": 0.0, "torso": -4.0, "x": 0.5},
	"superman": {"tw": 45.0, "Ra_s": 100.0, "Ra_e": 4.0, "La_s": 30.0, "La_e": 40.0, "torso": 24.0, "x": 1.3, "y": 0.7, "Rl_h": -60.0, "Rl_k": 70.0},
	"cotovelada": {"tw": -30.0, "La_s": 100.0, "La_e": 150.0, "torso": 14.0, "x": 0.8},
	"joelhada": {"tw": 20.0, "Rl_h": 100.0, "Rl_k": 125.0, "torso": -6.0, "La_s": 115.0, "La_e": 40.0, "Ra_s": 105.0, "Ra_e": 50.0, "x": 0.5},
	"joelhada_voadora": {"tw": 25.0, "Rl_h": 105.0, "Rl_k": 130.0, "Ll_h": 15.0, "Ll_k": 90.0, "y": 1.1, "torso": -8.0, "x": 1.1, "La_s": 40.0, "La_e": 40.0},
	"chute_baixo": {"tw": 45.0, "Rl_h": 58.0, "Rl_k": 8.0, "torso": -18.0, "Ra_s": -20.0, "Ra_e": 20.0, "x": 0.3},
	"chute_panturrilha": {"tw": 40.0, "Rl_h": 42.0, "Rl_k": 4.0, "torso": -14.0, "Ra_s": -15.0, "Ra_e": 25.0, "x": 0.35},
	"chute_obliquo": {"tw": -10.0, "Ll_h": 55.0, "Ll_k": 0.0, "torso": -16.0, "x": 0.2},
	"chute_corpo": {"tw": 55.0, "Rl_h": 88.0, "Rl_k": 6.0, "torso": -28.0, "Ra_s": -25.0, "Ra_e": 10.0, "x": 0.35},
	"chute_alto": {"tw": 65.0, "Rl_h": 142.0, "Rl_k": 8.0, "torso": -44.0, "Ra_s": -30.0, "Ra_e": 10.0, "x": 0.4},
	"chute_frontal": {"tw": 5.0, "Ll_h": 92.0, "Ll_k": 0.0, "torso": -18.0, "x": 0.25},
	"chute_giratorio": {"tw": 30.0, "Rl_h": -96.0, "Rl_k": 0.0, "torso": 34.0, "head": -20.0, "x": -0.4},
	"chute_rodado": {"tw": 40.0, "Rl_h": -125.0, "Rl_k": 6.0, "torso": 45.0, "head": -25.0, "x": -0.4},
}
## Preparação (meio do caminho) de alguns golpes, para o movimento não ser uma linha reta.
const CHAMBER := {
	"chute_frontal": {"Ll_h": 95.0, "Ll_k": 110.0, "torso": -8.0},
	"chute_corpo": {"Rl_h": 60.0, "Rl_k": 80.0, "torso": -15.0},
	"chute_alto": {"Rl_h": 85.0, "Rl_k": 90.0, "torso": -25.0},
	"overhand": {"Ra_s": 125.0, "Ra_e": 40.0, "torso": 10.0},
	"uppercut": {"Ra_s": 20.0, "Ra_e": 120.0, "crouch": 0.5},
	"gancho": {"La_s": 75.0, "La_e": 100.0, "torso": -4.0},
	"chute_giratorio": {"Rl_h": -30.0, "Rl_k": 90.0, "torso": 20.0},
	"chute_rodado": {"Rl_h": -60.0, "Rl_k": 60.0, "torso": 25.0},
}

## Mola de cada junta: [frequência parado, frequência no lance, amortecimento]. Braço e cabeça passam
## do ponto e voltam (chicote); tronco e perna pesam.
const SPRING := {
	"x": [12.0, 26.0, 0.9], "y": [20.0, 32.0, 1.0], "crouch": [12.0, 24.0, 0.8], "sit": [16.0, 16.0, 1.0], "rot": [11.0, 15.0, 0.85],
	"torso": [11.0, 25.0, 0.7], "head": [13.0, 23.0, 0.48], "tw": [12.0, 32.0, 0.8],
	"na_s": [13.0, 50.0, 0.68], "na_e": [14.0, 56.0, 0.62], "fa_s": [13.0, 50.0, 0.68], "fa_e": [14.0, 56.0, 0.62],
	"nl_h": [13.0, 40.0, 0.8], "nl_k": [14.0, 44.0, 0.75], "fl_h": [13.0, 40.0, 0.8], "fl_k": [14.0, 44.0, 0.75],
}
## Golpes em que a perna sai da lona (o pé deixa de ficar plantado).
const LEG_FREE := ["chute_baixo", "chute_corpo", "chute_alto", "chute_frontal", "chute_panturrilha", "chute_obliquo", "joelhada", "joelhada_voadora",
	"chute_giratorio", "chute_rodado", "superman"]

var rigs: Array = []
## Velocidade de cada junta (mola) e o empurrão que o golpe dá no corpo inteiro.
## Como o nocauteado cai (0 de costas, 1 de cara, 2 desaba sentado, 3 duro) e há quanto tempo acabou.
var _ko_kind := 0
var _last_k := ""
var _end_t := 0.0
var _pv := [{}, {}]
var _push := [0.0, 0.0]
var _push_v := [0.0, 0.0]
var time_scale := 1.0
var stamina := [1.0, 1.0]
var st := {"pos": "solto", "g": "", "top": -1, "cage": false, "dist": 1}
var _prev := {}
var _queue: Array = []
var _act: Dictionary = {}
var _cx := 0.0
var _cam := 0.0
var _cage_side := 1.0
var _plum := -1
var _between := false
var _ended := false
var _winner := -1
var _method := ""
var _shake := 0.0
var _slowmo := 0.0
var _fx: Array = []
var _caption := ""
var _caption_t := 0.0
var _time := 0.0
var _U := 20.0
var _ground := 100.0
var _org := Color("#C8102E")
var _crowd: Array = []
var _rng := RandomNumberGenerator.new()
## Árbitro: terceiro boneco, atrás da dupla.
var ref: Rig2D
## Manchas de sangue na lona: {x, z (0 perto da câmera, 1 longe), w}.
var stains: Array = []
## Replay do nocaute: últimos quadros gravados e o replay em andamento.
var _hist: Array = []
var replay: Dictionary = {}
var _replayed := false
## Tremor da câmera no golpe forte (deslocamento do quadro).
var _sh := Vector2.ZERO
## Câmera: zoom do quadro (alvo e valor suave), quanto o chão desce (fração da altura), o empurrão
## no golpe forte e a origem do quadro neste desenho.
var _vz := 1.0
var _vz_t := 1.0
var _vy := 0.0
var _vzd := 1.0
var _vo := Vector2.ZERO
var _punch := 0.0
## Quem a câmera segue: -1 a dupla; 0 ou 1 um lutador só (apresentação).
var _focus := -1
## Pausa de impacto (segundos que faltam), clarão do golpe forte e empolgação da torcida (0 a 1).
var _hitstop := 0.0
var _flash := 0.0
var _hype := 0.0
## Rastro do golpe: pontos {x, y (em U, a partir do chão), a, w, n (qual lance)}.
var _trail: Array = []
var _act_n := 0
## Passos: fase e velocidade de cada um.
var _step := [0.0, 0.0]
var _vel := [0.0, 0.0]
var _cap_age := 0.0
var _cap_big := false
## Relógio de tela (não para na pausa de impacto) e o dos flashes da torcida.
var _rt := 0.0
var _fclock := 0.0
## Apresentação do round 1 com as placas de nome (a tela desliga na vista 3D e no modo texto).
var intro := true
var _info: Array = []
## Nome que vai pintado na lona (a tela põe o do evento).
var logo := "NOITE DE LUTA"
## Intervalo no canto (só na vista 2D): tempo de intervalo, os técnicos e quanto cada um já sentou.
var coaches: Array = []
var _bt := 0.0
var _seated := [0.0, 0.0]
## Números do round que a placa do canto mostra: golpes certos e quedas de cada um.
var _stat := [{"g": 0, "q": 0}, {"g": 0, "q": 0}]
## Quadro de impacto do golpe enorme: ponto (em U), tempo que falta.
var _slam := Vector2.ZERO
var _slam_t := 0.0
var _snd_t := 0.0


func setup(w: GameWorld, fa: Fighter, fb: Fighter, org_color: Color = Color("#C8102E")) -> void:
	rigs = [Rig2D.from_fighter(w, fa, 1.0), Rig2D.from_fighter(w, fb, -1.0)]
	for i in 2:
		var r: Rig2D = rigs[i]
		r.corner = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
	# Calções parecidos: o do corner azul inverte as cores; se ainda confundir, vai de azul.
	var c0: Color = (rigs[0] as Rig2D).shorts
	var r1: Rig2D = rigs[1]
	var near := func(a: Color, b: Color) -> bool: return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() < 0.3
	if near.call(c0, r1.shorts):
		var sw := r1.shorts
		r1.shorts = r1.trim
		r1.trim = sw
		if near.call(c0, r1.shorts):
			r1.shorts = UIColors.CORNER_BLUE.darkened(0.35)
			r1.trim = Color("#F1F0EC")
	(rigs[0] as Rig2D).px = -GAP[1] * 0.5
	(rigs[1] as Rig2D).px = GAP[1] * 0.5
	for r: Rig2D in rigs:
		r.plant = true
		r.reset_feet()
	_org = org_color
	_info = []
	for f: Fighter in [fa, fb]:
		# Nome comprido demais para a placa: primeiro nome e sobrenome, ou só o sobrenome.
		var nm := f.display_name()
		if nm.length() > 18 and not f.family_first:
			nm = f.first.get_slice(" ", 0) + " " + f.last
		if nm.length() > 22:
			nm = f.short_name()
		_info.append({"name": nm.to_upper(), "nick": f.nickname, "sub": "%s  ·  %s  ·  %s" % [f.record_text(), f.nation, f.style_label()]})
	custom_minimum_size = Vector2(0, stage_height())
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = hash(fa.id * 7919 + fb.id)
	ref = Rig2D.referee(_rng)
	ref.plant = true
	for i in 170:
		_crowd.append(Vector3(_rng.randf_range(-40.0, 40.0), _rng.randf(), _rng.randf()))
	_crowd.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	# Técnicos: entram no intervalo com a camisa da equipe.
	coaches = []
	for i in 2:
		var c := Rig2D.referee(_rng)
		c.shirt = (rigs[i] as Rig2D).shorts.lerp(Color("#101216"), 0.25)
		c.shorts = Color("#23252C")
		c.hand = c.skin
		c.px = (-1.0 if i == 0 else 1.0) * (ARENA + 2.6)
		c.dir = 1.0 if i == 0 else -1.0
		c.plant = true
		c.reset_feet()
		coaches.append(c)


## Altura do palco: maior nas telas altas, para os lutadores aparecerem grandes.
static func stage_height() -> float:
	return clampf(UILayout.viewport.y * 0.47, 300.0, 860.0)


## Um lance do motor, na ordem. A fila acumulada demais (velocidade alta, "Pular") é resumida:
## os lances do começo só mudam o estado, sem animação.
func add_beat(b: Dictionary) -> void:
	_queue.append(b)
	while _queue.size() > 14:
		_apply_state(_queue.pop_front(), true)


## Pula para o fim do que já chegou (botão "Pular").
func skip() -> void:
	var last_big: Dictionary = {}
	while _queue.size() > 0:
		var b: Dictionary = _queue.pop_front()
		_apply_state(b, true)
		if String(b["type"]) in ["fim", "kd"]:
			last_big = b
	_act = {}
	replay = {}
	_replayed = true
	_focus = -1
	_hitstop = 0.0
	_trail = []
	if not last_big.is_empty():
		_start(last_big)


func idle() -> bool:
	return _act.is_empty() and _queue.is_empty() and replay.is_empty()


## Apresentação em andamento: a tela segura o relógio do round até ela acabar.
func holding() -> bool:
	return _intro_p() >= 0.0


## Progresso da apresentação do round 1 (0 a 1), ou -1 fora dela.
func _intro_p() -> float:
	if _act.is_empty() or not bool(_act.get("intro", false)):
		return -1.0
	return float(_act["p"])


## Legenda na tela por `t` segundos. `big`: entra grande no meio do quadro (nocaute, knockdown)
## antes de assentar na faixa de cima.
func _say(text: String, t: float, big: bool = false) -> void:
	_caption = I18n.t(text)
	_caption_t = t
	_cap_age = 0.0
	_cap_big = big


# --- Fila e estado -------------------------------------------------------------------------

func _apply_state(b: Dictionary, silent: bool) -> void:
	var was_cage := bool(st.get("cage", false))
	st = {"pos": String(b["pos"]), "g": String(b["g"]), "top": int(b["top"]), "cage": bool(b["cage"]), "dist": int(b["dist"])}
	var type := String(b["type"])
	var side := int(b["side"])
	if b.has("cut"):
		for i in 2:
			(rigs[i] as Rig2D).cut = float((b["cut"] as Array)[i])
			(rigs[i] as Rig2D).bruise = clampf(float((b["head"] as Array)[i]) / 2.5, 0.0, 1.0)
	if bool(st["cage"]) and not was_cage and side >= 0:
		# Quem leva para a grade empurra o outro: a grade fica atrás de quem é empurrado.
		_cage_side = -1.0 if side == 1 else 1.0
	if type == "golpe" and bool(b.get("hit", false)) and side >= 0 and String(b["pos"]) != "chao":
		# O castigo fica no corpo: coxa da frente vermelha dos chutes baixos, costela marcada.
		var hurt: Rig2D = rigs[1 - side]
		var dmg := float(b.get("dmg", 0.3))
		match String(b.get("z", "head")):
			"leg":
				hurt.leg_dmg = minf(1.0, hurt.leg_dmg + 0.06 + dmg * 0.1)
			"body":
				hurt.body_dmg = minf(1.0, hurt.body_dmg + 0.04 + dmg * 0.08)
	if side >= 0 and type in ["golpe", "gnp"] and bool(b.get("hit", type == "gnp")):
		_stat[side]["g"] = int(_stat[side]["g"]) + 1
	elif side >= 0 and type == "queda" and bool(b.get("ok", false)):
		_stat[side]["q"] = int(_stat[side]["q"]) + 1
	match type:
		"round":
			for r: Rig2D in rigs:
				r.ko = false
			if int(b.get("n", 1)) > 1:
				_stat = [{"g": 0, "q": 0}, {"g": 0, "q": 0}]
			_between = false
			_ended = false
			_replayed = false
			_cx = 0.0
			_plum = -1
			for i in 2:
				(rigs[i] as Rig2D).dir = 1.0 if i == 0 else -1.0
		"fim_round":
			_between = true
			_bt = 0.0
		"clinch":
			_plum = side if bool(b.get("plum", false)) else -1
		"solta":
			_plum = -1
		"fim":
			_ended = true
			_winner = side
			_method = String(b.get("m", ""))
	if silent and type == "fim":
		_caption_for(b)


func _start(b: Dictionary) -> void:
	_prev = st.duplicate()
	_apply_state(b, false)
	var type := String(b["type"])
	var k := String(b.get("k", ""))
	var d: float = DUR.get(type, 0.5)
	if type == "golpe":
		d = DUR["giro"] if k in SPINS else (DUR["chute"] if k in KICKS else DUR["golpe"])
	_act = {"type": type, "side": int(b["side"]), "b": b, "p": 0.0, "dur": d, "hit": false}
	if type == "golpe" and bool(b.get("hit", false)):
		_last_k = k
	_act_n += 1
	_focus = -1
	match type:
		"round":
			var n := int(b.get("n", 1))
			if n == 1 and intro and not AppSettings.reduce_motion and is_visible_in_tree():
				# Apresentação: cada um no seu canto, a câmera passa pelos dois, eles vêm ao centro.
				_act["dur"] = INTRO_S
				_act["intro"] = true
				for i in 2:
					var r: Rig2D = rigs[i]
					r.px = (-CORNER_X if i == 0 else CORNER_X)
					r.pose = _relaxed(r)
					r.reset_feet()
					_pv[i] = {}
				ref.px = 0.0
				_focus = 0
				_camera(0.0, true)
			else:
				_say("ROUND %d" % n, 1.3)
				_sound("gongo", -8.0)
		"fim_round":
			_say("FIM DO ROUND %d" % int(b.get("n", 1)), 1.3)
			_sound("gongo", -8.0)
		"kd":
			(rigs[1 - clampi(int(b["side"]), 0, 1)] as Rig2D).ko = true
			_say("KNOCKDOWN!", 1.6, true)
			_shake = 1.0
			_slowmo = 0.7
			_hype = 1.0
			Sfx.vibrate(40)
		"fim":
			_caption_for(b)
			_hype = 1.0
			_end_t = 0.0
			# O jeito de cair sai do último golpe: gancho e cruzado derrubam de cara, golpe reto de costas.
			var lk := _last_k
			if lk in ["gancho", "overhand", "cotovelada", "chute_alto", "chute_giratorio", "chute_rodado"]:
				_ko_kind = [1, 3, 1, 0][_act_n % 4]
			elif lk in ["uppercut", "joelhada", "joelhada_voadora", "chute_corpo"]:
				_ko_kind = [2, 0, 2, 3][_act_n % 4]
			else:
				_ko_kind = [0, 3, 2, 0][_act_n % 4]
			if _method == "KO" and int(b["side"]) >= 0:
				var out: Rig2D = rigs[1 - int(b["side"])]
				out.ko = true
				# O protetor bucal voa no nocaute.
				var jo := out.joints(0.0, 0.0, 1.0)
				var hp: Vector2 = jo["head"]
				_fx.append({"t": 0.0, "kind": "mouth", "x": hp.x, "y": -hp.y, "pw": 1.0, "v": -out.dir, "seed": _rng.randi() % 1000})
			if _method in ["KO", "TKO"]:
				_slowmo = 1.0
				_shake = 1.2
				_flash = 1.0
		"fin":
			if bool(b.get("lock", false)):
				_say("ENCAIXOU!", 1.3, true)
				_hype = maxf(_hype, 0.7)
		"queda":
			if bool(b.get("ok", false)) and String(b.get("td", "")) in THROWS:
				_shake = 0.6


func _caption_for(b: Dictionary) -> void:
	var m := String(b.get("m", ""))
	_say({"KO": "NOCAUTE!", "TKO": "NOCAUTE TÉCNICO!", "FIN": "FINALIZAÇÃO!"}.get(m, "FIM DE LUTA"), 99.0, true)


# --- Quadro a quadro -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if rigs.is_empty():
		return
	if AppSettings.reduce_motion:
		_shake = 0.0
		_slowmo = 0.0
		_hitstop = 0.0
		_flash = 0.0
		_punch = 0.0
	var dt := delta * (0.35 if _slowmo > 0.0 else 1.0)
	_slowmo -= delta
	_cap_age += delta
	_rt += delta
	_fclock += delta * (0.7 + 4.0 * _hype)
	_flash = maxf(0.0, _flash - delta * 5.0)
	_slam_t = maxf(0.0, _slam_t - delta)
	_snd_t = maxf(0.0, _snd_t - delta)
	_punch = maxf(0.0, _punch - delta * 3.5)
	_hype = maxf(0.0, _hype - delta * 0.2)
	if not replay.is_empty():
		_time += dt
		_play_replay(delta)
		return
	# Pausa de impacto: o quadro quase para no contato do golpe forte; os efeitos seguem.
	if _hitstop > 0.0:
		_hitstop -= delta
		dt *= 0.06
	_time += dt
	if _ended:
		_end_t += dt
	var speed := time_scale * (1.0 + 0.22 * float(_queue.size()))
	if not _act.is_empty():
		_act["p"] = float(_act["p"]) + dt * speed / float(_act["dur"])
		_impact()
		# Combinação: o golpe seguinte do mesmo lutador sai antes do anterior voltar inteiro.
		var chain := String(_act["type"]) in ["golpe", "gnp"] and float(_act["p"]) >= 0.68 and _queue.size() > 0 \
			and String((_queue[0] as Dictionary)["type"]) == String(_act["type"]) and int((_queue[0] as Dictionary)["side"]) == int(_act["side"])
		if float(_act["p"]) >= 1.0 or chain:
			var was_ko := String(_act["type"]) == "fim" and _method in ["KO", "TKO"]
			if String(_act["type"]) == "kd" and not _ended:
				for r: Rig2D in rigs:
					r.ko = false
			if bool(_act.get("intro", false)):
				_say("ROUND 1", 1.2)
				_sound("gongo", -8.0)
			_act = {}
			_focus = -1
			if was_ko and not _replayed and _hist.size() > 30 and not AppSettings.reduce_motion:
				_replayed = true
				replay = {"frames": _hist.duplicate(), "t": 0.0, "take": 0}
				_caption_t = 0.0
	if _act.is_empty() and _queue.size() > 0:
		_start(_queue.pop_front())
	_animate(dt)
	_animate_ref(dt)
	_animate_coaches(delta)
	_tick_trail(dt)
	_camera(delta)
	_record(dt)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_caption_t -= delta
	_tick_fx(delta)
	queue_redraw()


func _tick_fx(delta: float) -> void:
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < float(FX_LIFE.get(String(f["kind"]), 0.5)))


## Rastro do golpe: a luva (ou a canela, o joelho, o cotovelo) deixa um risco enquanto viaja.
func _tick_trail(dt: float) -> void:
	for pt: Dictionary in _trail:
		pt["a"] = float(pt["a"]) - dt * 6.5
	_trail = _trail.filter(func(pt: Dictionary) -> bool: return float(pt["a"]) > 0.0)
	if _act.is_empty() or AppSettings.reduce_motion:
		return
	var type := String(_act["type"])
	var p := float(_act["p"])
	if type not in ["golpe", "gnp"] or p < 0.15 or p > 0.5:
		return
	var a := clampi(int(_act["side"]), 0, 1)
	var r: Rig2D = rigs[a]
	var key := ""
	var wd := 0.42
	if type == "gnp" or String(st["pos"]) == "chao":
		key = String(_act.get("arm", "na")) + "_wr"
	else:
		var k := String((_act["b"] as Dictionary).get("k", "jab"))
		for sk: String in (STRIKE.get(k, STRIKE["jab"]) as Dictionary):
			if sk.begins_with("L") or sk.begins_with("R"):
				var side := (r.lead() if sk.begins_with("L") else r.rear())
				if sk[1] == "l":
					key = side + ("l_kn" if k.begins_with("joelhada") else "l_an")
					wd = 0.5
				else:
					key = side + ("a_el" if k == "cotovelada" else "a_wr")
				break
	if key == "":
		return
	var j := r.joints(0.0, 0.0, 1.0)
	var q: Vector2 = j[key]
	_trail.append({"x": q.x, "y": -q.y, "a": 1.0, "w": wd, "n": _act_n, "c": r.corner.lerp(Color.WHITE, 0.62)})
	if _trail.size() > 16:
		_trail.pop_front()


# --- Replay ------------------------------------------------------------------------------

## Grava o quadro (poses, posições, brilhos) para o replay; guarda uns 4 segundos.
func _record(dt: float) -> void:
	var fr := {"dt": dt, "p": [], "x": [], "d": [], "f": [], "ft": [], "fx": _fx.duplicate(true), "tr": _trail.duplicate(true)}
	for r: Rig2D in [rigs[0], rigs[1], ref]:
		fr["p"].append(r.pose.duplicate())
		fr["x"].append(r.px)
		fr["d"].append(r.dir)
		fr["f"].append(r.flash)
		fr["ft"].append([float(r.feet["nl"]), float(r.feet["fl"]), float(r.feet_up["nl"]), float(r.feet_up["fl"]), float(r._free_w["nl"]), float(r._free_w["fl"])])
	_hist.append(fr)
	var total := 0.0
	var cut_at := 0
	for i in range(_hist.size() - 1, -1, -1):
		total += float((_hist[i] as Dictionary)["dt"])
		if total > 4.2:
			cut_at = i
			break
	if cut_at > 0:
		_hist = _hist.slice(cut_at)


## O replay toca o nocaute duas vezes: o lance inteiro a 0,5× e depois o golpe final a 0,22×, de
## outro ângulo no 3D. No 2D ganha faixas pretas de cinema e a câmera fecha na segunda vez.
func _play_replay(delta: float) -> void:
	var frames: Array = replay["frames"]
	var take := int(replay.get("take", 0))
	replay["t"] = float(replay["t"]) + delta * (0.5 if take == 0 else 0.22)
	var total := 0.0
	for fr0: Dictionary in frames:
		total += float(fr0["dt"])
	var start := 0.0 if take == 0 else maxf(0.0, total - 3.0)
	var want := start + float(replay["t"])
	var acc := 0.0
	var idx := frames.size() - 1
	for i in frames.size():
		acc += float((frames[i] as Dictionary)["dt"])
		if acc >= want:
			idx = i
			break
	var fr: Dictionary = frames[idx]
	var all := [rigs[0], rigs[1], ref]
	for i in 3:
		var r: Rig2D = all[i]
		r.pose = (fr["p"][i] as Dictionary).duplicate()
		r.px = float(fr["x"][i])
		r.dir = float(fr["d"][i])
		var ft: Array = fr["ft"][i]
		r.feet = {"nl": ft[0], "fl": ft[1]}
		r.feet_up = {"nl": ft[2], "fl": ft[3]}
		r._free_w = {"nl": ft[4], "fl": ft[5]}
		if i < 2:
			r.flash = float(fr["f"][i])
	_fx = (fr["fx"] as Array).duplicate(true)
	_trail = (fr.get("tr", []) as Array).duplicate(true)
	_time += delta * 0.3
	if idx >= frames.size() - 1:
		if take == 0:
			replay["take"] = 1
			replay["t"] = 0.0
		else:
			replay = {}
			_fx = []
			_trail = []
			_caption_t = 99.0
			_cap_age = 0.0
	_camera(delta)
	queue_redraw()


func replay_take() -> int:
	return int(replay.get("take", -1))


func in_replay() -> bool:
	return not replay.is_empty()


# --- Árbitro -------------------------------------------------------------------------------

## Acompanha a dupla pelo lado com mais espaço; separa o clinch, aponta no knockdown, entra para
## parar a luta e levanta a mão do vencedor.
func _animate_ref(dt: float) -> void:
	var r0: Rig2D = rigs[0]
	var r1: Rig2D = rigs[1]
	var mid := (r0.px + r1.px) * 0.5
	var off := 3.4 if mid < 0.0 else -3.4
	var pos := String(st.get("pos", "solto"))
	var p := _relaxed(ref)
	p.merge({"na_s": 45.0, "na_e": 70.0, "fa_s": 35.0, "fa_e": 80.0, "crouch": 0.12, "torso": 8.0}, true)
	var tx := mid + off
	var type := String(_act.get("type", ""))
	var pa := float(_act.get("p", 0.0))
	if _between:
		tx = 0.0
		p = _relaxed(ref)
	elif _ended and _winner >= 0:
		var wr: Rig2D = rigs[_winner]
		var lr: Rig2D = rigs[1 - _winner]
		if type == "fim" and pa < 0.7 and _method in ["KO", "TKO", "FIN"]:
			# Entra correndo e abraça/protege quem perdeu.
			tx = lr.px + (wr.px - lr.px) * 0.25
			p.merge({"crouch": 0.5, "torso": 45.0, "na_s": 110.0 + 35.0 * sin(_time * 14.0), "na_e": 20.0, "fa_s": 95.0 - 35.0 * sin(_time * 14.0), "fa_e": 25.0}, true)
		else:
			# Mão do vencedor para o alto.
			tx = wr.px - signf(wr.px - lr.px + 0.001) * 1.3
			p = _relaxed(ref)
			p.merge({"na_s": 160.0, "na_e": 10.0, "torso": -4.0}, true)
	elif _ended:
		tx = mid
		p.merge({"na_s": 150.0, "na_e": 20.0, "fa_s": 150.0, "fa_e": 20.0}, true)
	elif type == "round":
		tx = mid
		var intro_on := bool(_act.get("intro", false))
		# Na apresentação ele espera no centro e só dá o sinal quando os dois chegam.
		var up := smoothstep(0.8, 0.88, pa) if intro_on else 1.0
		var chop := smoothstep(0.92, 0.98, pa) if intro_on else smoothstep(0.3, 0.6, pa)
		if intro_on:
			tx = 0.0
			p = _relaxed(ref)
		if up > 0.0:
			p.merge({"na_s": lerpf(float(p.get("na_s", 12.0)), lerpf(165.0, 75.0, chop), up), "na_e": 5.0, "fa_s": 20.0, "torso": 6.0 + 14.0 * chop}, true)
	elif type == "balanca":
		var dfd: Rig2D = rigs[1 - clampi(int(_act.get("side", 0)), 0, 1)]
		tx = dfd.px + off * 0.45
		p.merge({"torso": 22.0, "head": 12.0, "na_s": 70.0, "na_e": 30.0}, true)
	elif type == "solta":
		tx = mid
		p.merge({"na_s": 92.0, "na_e": 6.0, "fa_s": 86.0, "fa_e": 10.0}, true)
	elif type == "kd":
		tx = mid + off * 0.6
		p.merge({"torso": 28.0, "na_s": 75.0, "na_e": 0.0}, true)
	elif pos == "chao":
		tx = mid + off * 0.75
		p.merge({"crouch": 0.7, "torso": 40.0, "na_s": 25.0, "na_e": 20.0, "fa_s": 20.0, "fa_e": 25.0}, true)
	elif pos == "clinch":
		tx = mid + off * 0.6
	tx = clampf(tx, -ARENA + 1.0, ARENA - 1.0)
	var dirt := signf(mid - ref.px)
	if _ended and _winner >= 0 and not (type == "fim" and pa < 0.7):
		dirt = signf((rigs[_winner] as Rig2D).px - ref.px)
	if dirt != 0.0 and not is_equal_approx(dirt, ref.dir):
		ref.dir = dirt
		ref.pose = Rig2D.swap_sides(ref.pose)
		ref.reset_feet()
	p["crouch"] = float(p.get("crouch", 0.0)) + 0.03 * sin(_time * 3.0)
	ref.pose = Rig2D.blend(ref.pose, p, 1.0 - exp(-8.0 * dt))
	ref.px = lerpf(ref.px, tx, 1.0 - exp(-(4.0 if _ended else 2.2) * dt))
	ref.step_feet(dt)


func _animate(dt: float) -> void:
	var tg := _targets()
	var poses: Array = tg[0]
	var pxs: Array = tg[1]
	var dirs: Array = tg[2]
	var fast := not _act.is_empty() and String(_act["type"]) in ["golpe", "gnp", "estudo", "balanca", "fin", "escapa"]
	var ap := 1.0 - exp(-(10.0 if fast else 4.5) * dt)
	_free_legs(dirs)
	for i in 2:
		var r: Rig2D = rigs[i]
		if not is_equal_approx(r.dir, float(dirs[i])):
			r.dir = float(dirs[i])
			r.pose = (poses[i] as Dictionary).duplicate()
			_pv[i] = {}
			r.reset_feet()
		else:
			_spring(i, poses[i], dt, fast)
		# Empurrão do golpe: o corpo vai para trás e volta para a distância com os próprios passos.
		_push_v[i] = float(_push_v[i]) + (-36.0 * float(_push[i]) - 12.0 * float(_push_v[i])) * dt
		_push[i] = clampf(float(_push[i]) + float(_push_v[i]) * dt, -2.2, 2.2)
		var was := r.px
		# Ninguém desliza mais rápido do que um passo largo (as idas ao canto são caminhadas).
		var vmax := (18.0 if fast else 9.0) * dt
		var want := float(pxs[i]) + float(_push[i])
		r.px = clampf(r.px + clampf(lerpf(r.px, want, ap) - r.px, -vmax, vmax), -ARENA + 0.6, ARENA - 0.6)
		if dt > 0.0005:
			_vel[i] = lerpf(float(_vel[i]), (r.px - was) / dt, 1.0 - exp(-14.0 * dt))
			_step[i] = float(_step[i]) + absf(r.px - was) * TAU / 3.0
		r.step_feet(dt)
		r.flash = maxf(0.0, r.flash - dt * 3.0)


## Um quadro das molas: cada junta persegue o alvo com massa, em vez de escorregar até ele. Cansado,
## o corpo responde mais mole.
func _spring(i: int, target: Dictionary, dt: float, fast: bool) -> void:
	var r: Rig2D = rigs[i]
	var v: Dictionary = _pv[i]
	var tired := clampf(1.0 - float(stamina[i]), 0.0, 1.0)
	var n := clampi(int(ceil(dt * 150.0)), 1, 6)
	var h := dt / float(n)
	var soft := 1.0 - 0.25 * tired
	var a := 1.0 - exp(-(34.0 if fast else 9.0) * dt)
	for k: String in Rig2D.KEYS:
		var cur := float(r.pose.get(k, 0.0))
		var want := float(target.get(k, cur))
		if not SPRING.has(k):
			r.pose[k] = lerpf(cur, want, a)
			continue
		var sp: Array = SPRING[k]
		var w := float(sp[1] if fast else sp[0]) * soft
		var z := float(sp[2]) - 0.08 * tired
		var vel := float(v.get(k, 0.0))
		for _s in n:
			vel += (w * w * (want - cur) - 2.0 * z * w * vel) * h
			cur += vel * h
		v[k] = vel
		r.pose[k] = cur
	if float(r.pose.get("y", 0.0)) < 0.0:
		r.pose["y"] = 0.0
		v["y"] = maxf(0.0, float(v.get("y", 0.0)))


## Solavanco: soma velocidade nas juntas (o golpe que entra, o bloqueio que treme).
func _jolt(i: int, amounts: Dictionary) -> void:
	var v: Dictionary = _pv[i]
	for k: String in amounts:
		v[k] = float(v.get(k, 0.0)) + float(amounts[k])


## Quais pernas estão fora da lona neste lance: a de quem chuta, a de quem levanta para checar.
func _free_legs(dirs: Array) -> void:
	for r: Rig2D in rigs:
		r.free["nl"] = false
		r.free["fl"] = false
	if _act.is_empty() or String(st["pos"]) == "chao":
		return
	var type := String(_act["type"])
	var p := float(_act["p"])
	var a := clampi(int(_act["side"]), 0, 1)
	var b: Dictionary = _act["b"]
	if type == "golpe":
		var k := String(b.get("k", ""))
		if k in LEG_FREE and p > 0.05 and p < 0.88:
			var over := _resolve(rigs[a], float(dirs[a]), STRIKE.get(k, {}))
			for sd: String in ["nl", "fl"]:
				if over.has(sd + "_h") and absf(float(over[sd + "_h"])) > 35.0:
					(rigs[a] as Rig2D).free[sd] = true
		if not bool(b.get("hit", false)) and String(b.get("z", "")) == "leg" and p > 0.14 and p < 0.7:
			var rd: Rig2D = rigs[1 - a]
			rd.free[("n" if (float(dirs[1 - a]) > 0.0) != rd.southpaw else "f") + "l"] = true
	elif type == "segura_chute" and p < 0.72:
		var rk: Rig2D = rigs[1 - a]
		rk.free[("f" if (float(dirs[1 - a]) > 0.0) != rk.southpaw else "n") + "l"] = true


## Técnicos: fora da grade durante o round; no intervalo entram, param na frente do lutador
## sentado e falam com as mãos. Só existem na vista 2D.
func _animate_coaches(delta: float) -> void:
	var on := _corner_on()
	for i in coaches.size():
		var c: Rig2D = coaches[i]
		var sgn := -1.0 if i == 0 else 1.0
		var tx := sgn * (ARENA + 2.6)
		if on and _bt > 1.2:
			tx = sgn * (ARENA - 6.3)
		var was := c.px
		c.px += clampf(tx - c.px, -7.5 * delta, 7.5 * delta)
		var moving := absf(c.px - was) > 0.0005
		var want := signf(c.px - was) if moving else sgn
		if want != 0.0 and not is_equal_approx(want, c.dir):
			c.dir = want
			c.pose = Rig2D.swap_sides(c.pose)
			c.reset_feet()
		var p := _relaxed(c)
		if moving:
			p.merge({"torso": 8.0, "na_s": 12.0 + 14.0 * sin(c.px * 2.1), "fa_s": -6.0 - 14.0 * sin(c.px * 2.1)}, true)
		else:
			# Abaixado na frente dele, uma mão no joelho e a outra marcando as instruções.
			p.merge({"crouch": 0.45, "torso": 30.0, "head": -6.0, "na_s": 66.0 + 20.0 * sin(_rt * 5.2 + float(i) * 2.0), "na_e": 58.0 + 18.0 * sin(_rt * 7.3 + float(i)),
				"fa_s": 30.0, "fa_e": 46.0, "nl_h": 18.0, "nl_k": 10.0, "fl_h": -16.0, "fl_k": 12.0}, true)
		c.pose = Rig2D.blend(c.pose, p, 1.0 - exp(-9.0 * delta))
		c.step_feet(delta)


## O intervalo no canto só acontece com a vista 2D na tela (a 3D lê as poses e segue como era).
func _corner_on() -> bool:
	return _between and not _ended and is_visible_in_tree()


## Passos: quem está em pé e se deslocando mexe as pernas (uma vai, a outra empurra) em vez de
## deslizar. A fase anda com a distância percorrida; a amplitude, com a velocidade.
func _footwork(i: int, pose: Dictionary, _dt: float) -> void:
	if (rigs[i] as Rig2D).plant:
		return
	if float(pose.get("sit", 0.0)) > 0.5 or absf(float(pose.get("rot", 0.0))) > 20.0 or float(pose.get("y", 0.0)) > 0.3:
		return
	var sp := absf(float(_vel[i]))
	if sp < 0.3:
		return
	var amp := clampf((sp - 0.3) / 3.2, 0.0, 1.0)
	var ph := float(_step[i])
	var s1 := sin(ph)
	var walk := 1.0 if _intro_p() >= 0.0 else 0.55
	pose["nl_h"] = float(pose.get("nl_h", 0.0)) + 24.0 * walk * amp * s1
	pose["fl_h"] = float(pose.get("fl_h", 0.0)) - 24.0 * walk * amp * s1
	pose["nl_k"] = float(pose.get("nl_k", 0.0)) + 26.0 * walk * amp * maxf(0.0, cos(ph))
	pose["fl_k"] = float(pose.get("fl_k", 0.0)) + 26.0 * walk * amp * maxf(0.0, -cos(ph))
	pose["y"] = float(pose.get("y", 0.0)) + 0.06 * amp * absf(s1)


# --- Câmera -------------------------------------------------------------------------------

## Plano do momento: [zoom máximo, quanto o chão pode descer do quadro (fração da altura)]. Com o
## chão descendo, os pés saem do quadro e os lutadores crescem (plano americano da transmissão).
func _shot() -> Array:
	if not replay.is_empty():
		return [1.12, 0.06] if replay_take() == 0 else [1.32, 0.17]
	if _focus >= 0:
		return [1.34, 0.0] if _between else [1.24, 0.13]
	if _ended:
		# No nocaute quem caiu tem de aparecer inteiro na lona: plano aberto, o chão quase não desce.
		return [1.0, 0.0] if _method in ["KO", "TKO"] else [1.1, 0.05]
	if _between:
		return [1.0, 0.0]
	var type := String(_act.get("type", ""))
	if type in ["queda", "mat_return", "raspa", "kd", "puxa_guarda", "levanta", "round", "segura_chute"]:
		return [1.06, 0.03]
	var pos := String(st.get("pos", "solto"))
	if pos == "chao":
		# Finalização encaixada: fecha mais um pouco.
		return [1.62, 0.0] if (type == "fin" and bool((_act["b"] as Dictionary).get("lock", false))) else [1.5, 0.0]
	if type == "balanca" or pos == "clinch":
		return [1.3, 0.16]
	return [[1.05, 0.02], [1.14, 0.07], [1.22, 0.11]][clampi(int(st.get("dist", 1)), 0, 2)]


## Enquadra quem está em cena: o centro segue a dupla, o zoom fecha até onde o plano deixa e os
## dois cabem na largura, e o quadro desce o que for preciso para não cortar a cabeça de ninguém.
func _camera(delta: float, snap: bool = false) -> void:
	var w := size.x
	var h := size.y
	if w < 10.0 or h < 10.0 or rigs.is_empty() or not is_visible_in_tree():
		return
	if _corner_on() and replay.is_empty():
		# Intervalo: abre enquanto eles vão para os cantos, depois corta de um canto para o outro.
		_bt += delta
		var want := -1 if _bt < 0.8 else int((_bt - 0.8) / 3.8) % 2
		if want != _focus:
			_focus = want
			snap = snap or want >= 0
	# Num quadro alto (celular em pé) a escala vem da largura: sobra altura, e a câmera pode
	# fechar mais (`tall`), até os lutadores encherem o palco.
	var u0 := minf(h / 9.6, w / 12.5)
	var hk := h / u0
	var tall := hk / 9.6
	var x0 := INF
	var x1 := -INF
	var top := 0.0
	var down := false
	for i in 2:
		if _focus >= 0 and i != _focus:
			continue
		var r: Rig2D = rigs[i]
		var j := r.joints(0.0, 0.0, 1.0)
		for k: String in ["hip", "head", "nl_kn", "fl_kn"]:
			var q: Vector2 = j[k]
			x0 = minf(x0, q.x)
			x1 = maxf(x1, q.x)
		top = maxf(top, -(j["head"] as Vector2).y + 0.5 * float(j["U"]) + 0.4)
		down = down or -(j["head"] as Vector2).y < 2.6
		if _ended and i == _winner and replay.is_empty():
			# Braços para o alto na comemoração.
			for k: String in ["na_wr", "fa_wr"]:
				top = maxf(top, -(j[k] as Vector2).y + 0.4)
	if _caption_t > 0.0 and _caption != "" and not _ended:
		# Folga em cima para a faixa da legenda não tampar o rosto de ninguém.
		top += 0.7
	var shot := _shot()
	var drop := float(shot[1])
	var slack := 0.06
	if down:
		# Alguém na lona: o chão fica no quadro (quem caiu não pode sair pela borda de baixo).
		drop = 0.0
		# No fim o quadro desce um pouco mais: cabem as luvas de quem comemora e quem está deitado.
		slack = 0.06 if (_ended and replay.is_empty()) else 0.02
	var z := minf(float(shot[0]) * tall, (w / u0) / maxf(4.0, x1 - x0 + 3.4))
	z = clampf(minf(z, (0.84 + drop) * hk / maxf(1.0, top)), 1.0, 1.6 * tall)
	if AppSettings.reduce_motion:
		z = 1.0
	var cx := (x0 + x1) * 0.5
	if _focus >= 0:
		# Apresentação: o lutador fica num terço do quadro e a placa dele no outro lado.
		cx += (3.0 if _focus == 0 else -3.0)
	if snap:
		_vz_t = z
		_vz = z
	# Fecha devagar e abre depressa (ninguém pode sair do quadro na queda).
	var rate := 2.0 if z > _vz_t else 6.0
	_vz_t = lerpf(_vz_t, z, 1.0 - exp(-rate * delta))
	_vz = lerpf(_vz, _vz_t, 1.0 - exp(-7.0 * delta))
	var vy := clampf(top * _vz / hk - 0.84, 0.0, drop + slack)
	_vy = vy if snap else lerpf(_vy, vy, 1.0 - exp(-8.0 * delta))
	var half := w / u0 * 0.5 / _vz
	var lim := maxf(0.0, ARENA + 1.0 - half)
	var pan := 3.0
	if _focus >= 0 or _intro_p() >= 0.0:
		pan = 5.5
	cx = clampf(cx, -lim, lim)
	_cam = cx if snap else lerpf(_cam, cx, 1.0 - exp(-pan * delta))


## [poses, posições, direções] de cada um neste quadro.
func _targets() -> Array:
	var s := st
	if not _act.is_empty() and float(_act["p"]) < float(SWITCH.get(String(_act["type"]), 0.0)):
		s = _prev
	var out := _base(s)
	var poses: Array = out[0]
	if not _ended:
		_life(s, poses)
	if not _act.is_empty():
		_overlay(s, out)
	return out


# --- Posições de base ----------------------------------------------------------------------

func _base(s: Dictionary) -> Array:
	var r0: Rig2D = rigs[0]
	var r1: Rig2D = rigs[1]
	var dirs := [1.0, -1.0]
	var poses := [r0.stance(), r1.stance()]
	var pxs := [0.0, 0.0]
	var pos := String(s["pos"])
	if _ended:
		return _end_pose(s)
	var ip := _intro_p()
	if ip >= 0.0:
		return _intro_base(ip)
	if _corner_on():
		return _corner_base()
	_seated = [0.0, 0.0]
	if _between:
		for i in 2:
			poses[i] = _relaxed(rigs[i])
		_cx = lerpf(_cx, 0.0, 0.03)
		return [poses, [_cx - 5.5, _cx + 5.5], dirs]
	if pos == "chao":
		return _ground_base(s)
	var gap: float = GAP[clampi(int(s["dist"]), 0, 2)]
	if pos == "clinch":
		gap = 1.75
		for i in 2:
			var p: Dictionary = poses[i]
			p.merge({"crouch": 0.25, "torso": 24.0, "head": 10.0, "na_s": 84.0, "na_e": 22.0, "fa_s": 74.0, "fa_e": 35.0}, true)
			if _plum == i:
				p.merge({"na_s": 80.0, "na_e": 12.0, "fa_s": 76.0, "fa_e": 16.0, "torso": 8.0}, true)
			elif _plum == 1 - i:
				p.merge({"torso": 50.0, "head": 25.0, "na_s": 80.0, "na_e": 70.0}, true)
	else:
		gap += sin(_time * 0.9) * 0.3
	var target_cx := sin(_time * 0.17) * 3.0 + (float(r0.manner["press"]) - float(r1.manner["press"])) * 3.2
	if bool(s["cage"]):
		target_cx = _cage_side * (ARENA - 1.4 - gap * 0.5)
	_cx = lerpf(_cx, target_cx, 0.02)
	pxs = [_cx - gap * 0.5, _cx + gap * 0.5]
	return [poses, pxs, dirs]


## Intervalo: cada um anda até o seu canto, senta no banquinho e respira fundo (mais fundo quanto
## mais cansado), com os antebraços nas coxas.
func _corner_base() -> Array:
	var poses := [{}, {}]
	var pxs := [0.0, 0.0]
	var dirs := [1.0, -1.0]
	for i in 2:
		var r: Rig2D = rigs[i]
		var sgn := -1.0 if i == 0 else 1.0
		var seat := sgn * (ARENA - 2.4)
		var far := absf(r.px - seat)
		var down := 1.0 - smoothstep(0.2, 1.3, far)
		var tired := clampf(1.0 - float(stamina[i]), 0.0, 1.0)
		var breath := sin(_time * (2.6 + 2.2 * tired) + float(i))
		var sit := {"x": 0.0, "y": 0.0, "crouch": 0.0, "sit": 0.0, "rot": 0.0, "torso": 12.0 + (2.0 + 4.5 * tired) * breath, "head": 8.0 + 10.0 * tired - 2.0 * breath,
			"na_s": 40.0 + 2.0 * breath, "na_e": 40.0, "fa_s": 32.0 + 2.0 * breath, "fa_e": 48.0, "nl_h": 84.0, "nl_k": 86.0, "fl_h": 76.0, "fl_k": 82.0}
		poses[i] = Rig2D.blend(_relaxed(r), sit, down)
		pxs[i] = seat
		_seated[i] = down
		# Vai de frente para o canto e vira para sentar.
		if far > 1.3:
			dirs[i] = sgn
	return [poses, pxs, dirs]


## Apresentação do round 1: cada um solta o corpo no seu canto enquanto a câmera passa por ele;
## depois os dois vêm ao centro, tocam as luvas e armam a guarda.
func _intro_base(p: float) -> Array:
	_focus = 0 if p < 0.33 else (1 if p < 0.66 else -1)
	var walk := smoothstep(0.68, 0.9, p)
	var guard := smoothstep(0.78, 0.92, p)
	var touch := smoothstep(0.85, 0.9, p) * (1.0 - smoothstep(0.93, 0.99, p))
	var poses := [{}, {}]
	var pxs := [0.0, 0.0]
	var loose := 1.0 - smoothstep(0.66, 0.74, p)
	for i in 2:
		var r: Rig2D = rigs[i]
		var sgn := -1.0 if i == 0 else 1.0
		var ph := _time * 7.5 + float(i) * 1.9
		var hop := absf(sin(ph)) * loose
		# No canto: pulinhos na ponta do pé, mãos soltas na altura do peito e uma sombra leve.
		var warm := _relaxed(r)
		warm.merge({"y": 0.13 * hop, "crouch": 0.14 * (loose - hop), "torso": 8.0, "head": 2.0 + 6.0 * sin(_time * 2.3 + float(i)) * loose,
			"na_s": 42.0 + 6.0 * sin(ph), "na_e": 104.0 + 8.0 * sin(ph + 0.8), "fa_s": 28.0 - 6.0 * sin(ph), "fa_e": 112.0 - 8.0 * sin(ph + 0.8)}, true)
		var sb := _time * 4.6 + float(i) * 2.4
		_mix(warm, _resolve(r, -sgn, {"La_s": 92.0, "La_e": 6.0, "torso": 12.0}), pow(maxf(0.0, sin(sb)), 6.0) * 0.9 * loose)
		_mix(warm, _resolve(r, -sgn, {"Ra_s": 90.0, "Ra_e": 8.0, "tw": 40.0, "torso": 18.0}), pow(maxf(0.0, sin(sb - 1.1)), 6.0) * 0.9 * loose)
		var pose := Rig2D.blend(warm, r.stance(), guard)
		_mix(pose, _resolve(r, -sgn, {"La_s": 80.0, "La_e": 6.0, "torso": 10.0, "head": 4.0}), touch)
		poses[i] = pose
		pxs[i] = sgn * lerpf(CORNER_X, GAP[1] * 0.5 + 0.3 * touch, walk)
	return [poses, pxs, [1.0, -1.0]]


func _relaxed(_r: Rig2D) -> Dictionary:
	return {"crouch": 0.0, "torso": 4.0, "head": -4.0, "na_s": 12.0, "na_e": 20.0, "fa_s": -6.0, "fa_e": 18.0,
		"nl_h": 8.0, "nl_k": 4.0, "fl_h": -8.0, "fl_k": 6.0, "x": 0.0, "y": 0.0, "rot": 0.0, "sit": 0.0}


## Chão: quem está por baixo deitado de costas (rot 90, pés para o outro), quem está por cima
## ajoelhado na guarda, mais deitado na meia e no cem quilos, sentado na montada, atrás nas costas.
func _ground_base(s: Dictionary) -> Array:
	var tp := clampi(int(s["top"]), 0, 1)
	var bt := 1 - tp
	var dB := 1.0 if bt == 0 else -1.0
	var g := String(s["g"])
	var poses := [{}, {}]
	var pxs := [0.0, 0.0]
	var dirs := [1.0, -1.0]
	var base := {"x": 0.0, "y": 0.0, "crouch": 0.0, "sit": 0.0, "rot": 0.0, "torso": 0.0, "head": 0.0}
	var B := base.duplicate()
	var T := base.duplicate()
	var t_off := 2.0
	match g:
		"meia":
			B.merge({"sit": 1.0, "rot": 88.0, "head": 25.0, "na_s": 55.0, "na_e": 60.0, "fa_s": 70.0, "fa_e": 50.0, "nl_h": 35.0, "nl_k": 85.0, "fl_h": 12.0, "fl_k": 40.0}, true)
			T.merge({"torso": 58.0, "head": 15.0, "na_s": 100.0, "na_e": 40.0, "fa_s": 80.0, "fa_e": 50.0, "nl_h": 25.0, "nl_k": 110.0, "fl_h": -15.0, "fl_k": 85.0}, true)
			t_off = 1.3
			B["lz"] = 0.6
			T.merge({"lz": 0.5, "zz": 0.35}, true)
		"lateral":
			B.merge({"sit": 1.0, "rot": 90.0, "head": 20.0, "na_s": 95.0, "na_e": 60.0, "fa_s": 40.0, "fa_e": 80.0, "nl_h": 50.0, "nl_k": 95.0, "fl_h": 30.0, "fl_k": 75.0}, true)
			T.merge({"torso": 70.0, "head": 18.0, "na_s": 20.0, "na_e": 30.0, "fa_s": 55.0, "fa_e": 25.0, "nl_h": 10.0, "nl_k": 100.0, "fl_h": -30.0, "fl_k": 70.0}, true)
			t_off = 0.7
			T.merge({"lz": 0.5, "zz": 0.95}, true)
		"montada":
			B.merge({"sit": 1.0, "rot": 90.0, "head": 25.0, "na_s": 90.0, "na_e": 30.0, "fa_s": 75.0, "fa_e": 45.0, "nl_h": 45.0, "nl_k": 90.0, "fl_h": 35.0, "fl_k": 85.0}, true)
			T.merge({"sit": 1.0, "y": 0.1, "torso": 8.0, "head": 5.0, "na_s": 65.0, "na_e": 30.0, "fa_s": 50.0, "fa_e": 40.0, "nl_h": 70.0, "nl_k": 155.0, "fl_h": 62.0, "fl_k": 150.0}, true)
			t_off = -0.5
			T["lz"] = 2.0
		"costas":
			B.merge({"sit": 1.0, "rot": 0.0, "torso": -6.0, "head": 14.0, "na_s": 75.0, "na_e": 80.0, "fa_s": 65.0, "fa_e": 85.0, "nl_h": 84.0, "nl_k": 25.0, "fl_h": 78.0, "fl_k": 15.0}, true)
			T.merge({"sit": 1.0, "rot": -18.0, "torso": 0.0, "head": 20.0, "na_s": 100.0, "na_e": 75.0, "fa_s": 85.0, "fa_e": 70.0, "nl_h": 70.0, "nl_k": 45.0, "fl_h": 95.0, "fl_k": 20.0}, true)
			t_off = -1.55
			dirs[tp] = dB
			T.merge({"lz": 1.5, "az": 0.25}, true)
		_:
			B.merge({"sit": 1.0, "rot": 90.0, "head": 25.0, "na_s": 60.0, "na_e": 30.0, "fa_s": 70.0, "fa_e": 40.0, "nl_h": 45.0, "nl_k": 78.0, "fl_h": 40.0, "fl_k": 70.0}, true)
			T.merge({"torso": 30.0, "head": 0.0, "na_s": 58.0, "na_e": 20.0, "fa_s": 50.0, "fa_e": 28.0, "nl_h": -2.0, "nl_k": 95.0, "fl_h": -12.0, "fl_k": 80.0, "lz": 0.7}, true)
			B["lz"] = 1.4
	dirs[bt] = dB
	var target_cx := 0.0
	if bool(s["cage"]):
		target_cx = -dB * (ARENA - 4.0)
	_cx = lerpf(_cx, target_cx, 0.02)
	pxs[bt] = _cx - dB * 0.8
	pxs[tp] = pxs[bt] + dB * t_off
	poses[bt] = B
	poses[tp] = T
	return [poses, pxs, dirs]


## Fim de luta: o vencedor comemora; no nocaute o outro fica no chão.
func _end_pose(s: Dictionary) -> Array:
	var w := clampi(_winner, 0, 1)
	var l := 1 - w
	var dirs := [1.0, -1.0]
	var poses := [{}, {}]
	var dl := 1.0 if l == 0 else -1.0
	var wr: Rig2D = rigs[w]
	var cele := String(wr.manner.get("cele", ""))
	var away := 4.5
	poses[w] = _relaxed(wr)
	if _winner < 0:
		poses[l] = _relaxed(rigs[l])
		(poses[l] as Dictionary).merge({"head": 20.0, "torso": 10.0}, true)
	else:
		# Cada um comemora do seu jeito.
		var pw: Dictionary = poses[w]
		match cele:
			"frio":
				# Vira as costas e sai andando, sem olhar para trás.
				pw.merge({"head": 6.0, "torso": 6.0, "na_s": 10.0, "na_e": 14.0, "fa_s": -8.0, "fa_e": 12.0}, true)
				dirs[w] = -float(dirs[w])
				away = 4.5 + minf(4.0, _end_t * 1.3)
			"humilde":
				# Ajoelha, mãos juntas, cabeça baixa.
				pw.merge({"crouch": 1.0, "torso": 30.0, "head": 24.0, "na_s": 62.0, "na_e": 112.0, "fa_s": 58.0, "fa_e": 116.0,
					"nl_h": 30.0, "nl_k": 60.0, "fl_h": -30.0, "fl_k": 80.0}, true)
			"guerra":
				# Braços abertos, peito para fora, grito para a arquibancada.
				var roar := sin(_time * 11.0)
				pw.merge({"crouch": 0.2, "torso": -10.0 + 2.5 * roar, "head": -24.0, "na_s": 96.0, "na_e": 112.0 + 5.0 * roar, "fa_s": 84.0, "fa_e": 122.0 - 5.0 * roar}, true)
			"show":
				# Pula socando o ar.
				var hop := absf(sin(_time * 5.2))
				var pump := sin(_time * 10.4)
				pw.merge({"y": 0.55 * hop, "crouch": 0.18 * (1.0 - hop), "head": -14.0, "torso": -6.0, "na_s": 150.0 + 18.0 * pump, "na_e": 30.0 - 20.0 * pump,
					"fa_s": 60.0, "fa_e": 120.0, "nl_k": 20.0 * hop, "fl_k": 35.0 * hop}, true)
			_:
				pw.merge({"na_s": 168.0, "na_e": 12.0, "fa_s": 160.0, "fa_e": 18.0, "head": -18.0, "torso": -6.0, "y": absf(sin(_time * 5.0)) * 0.25}, true)
		if _method in ["KO", "TKO"]:
			match _ko_kind:
				1:
					# Cai para a frente, de cara na lona.
					poses[l] = {"sit": 1.0, "rot": -94.0, "torso": 0.0, "head": 12.0, "na_s": -20.0, "na_e": 12.0, "fa_s": 30.0, "fa_e": 60.0,
						"nl_h": -6.0, "nl_k": 8.0, "fl_h": -18.0, "fl_k": 40.0, "x": 0.0, "y": 0.0, "crouch": 0.0}
					away = 5.2
				2:
					# Desaba sentado e deita, joelhos para cima.
					poses[l] = {"sit": 1.0, "rot": 90.0, "torso": 0.0, "head": -4.0, "na_s": 40.0, "na_e": 30.0, "fa_s": -20.0, "fa_e": 30.0,
						"nl_h": 62.0, "nl_k": 105.0, "fl_h": 48.0, "fl_k": 90.0, "x": 0.0, "y": 0.0, "crouch": 0.0}
				3:
					# Cai duro, braços travados no ar.
					poses[l] = {"sit": 1.0, "rot": 92.0, "torso": 0.0, "head": -14.0, "na_s": 78.0, "na_e": 14.0, "fa_s": 64.0, "fa_e": 22.0,
						"nl_h": 10.0, "nl_k": 6.0, "fl_h": 2.0, "fl_k": 4.0, "x": 0.0, "y": 0.0, "crouch": 0.0}
				_:
					poses[l] = {"sit": 1.0, "rot": 92.0, "torso": 0.0, "head": -10.0, "na_s": 8.0, "na_e": 15.0, "fa_s": -10.0, "fa_e": 20.0,
						"nl_h": 15.0, "nl_k": 25.0, "fl_h": 5.0, "fl_k": 10.0, "x": 0.0, "y": 0.0, "crouch": 0.0}
		else:
			poses[l] = _relaxed(rigs[l])
			(poses[l] as Dictionary).merge({"head": 28.0, "torso": 14.0, "na_s": 20.0}, true)
	var pxs := [0.0, 0.0]
	var c := _cx
	if String(s["pos"]) == "chao" or _method in ["KO", "TKO"]:
		pxs[l] = c - dl * 0.8
		pxs[w] = pxs[l] + dl * away
	else:
		pxs = [c - 2.2, c + 2.2]
		if cele == "frio" and _winner >= 0:
			pxs[w] = float(pxs[w]) + (-1.0 if w == 0 else 1.0) * minf(4.0, _end_t * 1.3)
	return [poses, pxs, dirs]


## Vida: balanço da base, cabeça do boxeador, mãos caindo com o cansaço.
func _life(s: Dictionary, poses: Array) -> void:
	var pos := String(s["pos"])
	for i in 2:
		var r: Rig2D = rigs[i]
		var p: Dictionary = poses[i]
		var m: Dictionary = r.manner
		var tired := clampf(1.0 - float(stamina[i]), 0.0, 1.0)
		var tempo := float(m["tempo"]) * (1.0 - 0.3 * tired)
		var bn := float(m["bounce"]) * (1.0 - 0.6 * tired) * (1.0 - 0.5 * r.bruise)
		var sw := float(m["sway"])
		var t := _time * tempo + float(m["phase"])
		var ld := r.lead()
		var rr := r.rear()
		r.feet_tap["nl"] = 0.0
		r.feet_tap["fl"] = 0.0
		if pos == "solto" and not _between:
			match r.guard:
				"boxe":
					# Cabeça que não para: pêndulo e mergulho, ombros rodando.
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.07 * bn * sin(t * 5.5) + 0.1 * sw * maxf(0.0, sin(t * 1.3))
					p["head"] = float(p.get("head", 0.0)) + 9.0 * sw * sin(t * 2.6)
					p["torso"] = float(p.get("torso", 0.0)) + 7.0 * sw * sin(t * 2.6 + 0.7)
					p["tw"] = float(p.get("tw", 0.0)) + 9.0 * sin(t * 1.3)
					p["x"] = float(p.get("x", 0.0)) + 0.2 * sin(t * 1.7)
				"dutch":
					# Guarda fechada, andando para a frente, sem pressa.
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.03 * bn * sin(t * 5.0)
					p["x"] = float(p.get("x", 0.0)) + 0.28 * sin(t * 1.1)
					p["head"] = float(p.get("head", 0.0)) + 3.0 * sin(t * 2.2)
					p[ld + "a_e"] = float(p.get(ld + "a_e", 0.0)) + 5.0 * sin(t * 5.0)
				"thai":
					# Marcha: a perna da frente bate no chão no ritmo e a mão longa mede a distância.
					var beat := pow(maxf(0.0, sin(t * 3.4)), 3.0)
					r.feet_tap[ld + "l"] = 0.13 * beat * bn
					p["crouch"] = float(p.get("crouch", 0.0)) - 0.04 * beat
					p["torso"] = float(p.get("torso", 0.0)) - 3.0 * beat
					p[ld + "a_s"] = float(p.get(ld + "a_s", 0.0)) + 9.0 * sin(t * 1.7)
					p[ld + "a_e"] = float(p.get(ld + "a_e", 0.0)) - 16.0 * maxf(0.0, sin(t * 1.7))
					p["x"] = float(p.get("x", 0.0)) + 0.12 * sin(t * 1.2)
				"karate", "tkd":
					# Pulinho na ponta dos pés, entrando e saindo.
					var hop := absf(sin(t * 7.2))
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.09 * bn * (1.0 - hop)
					r.feet_tap["nl"] = 0.05 * bn * hop
					r.feet_tap["fl"] = 0.05 * bn * hop
					p["y"] = float(p.get("y", 0.0)) + 0.05 * bn * hop
					p["x"] = float(p.get("x", 0.0)) + (0.5 if r.guard == "tkd" else 0.38) * sin(t * 2.1)
					p[ld + "a_s"] = float(p.get(ld + "a_s", 0.0)) + 6.0 * sin(t * 3.6)
				"capoeira":
					# Ginga: o corpo vai de um lado ao outro, um braço protege enquanto o outro abre.
					var g := sin(t * 2.6)
					p["x"] = float(p.get("x", 0.0)) + 0.75 * g
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.14 * absf(g)
					p["torso"] = float(p.get("torso", 0.0)) + 9.0 * g
					p["na_s"] = float(p.get("na_s", 0.0)) + 34.0 * g
					p["fa_s"] = float(p.get("fa_s", 0.0)) - 34.0 * g
					p["na_e"] = float(p.get("na_e", 0.0)) - 20.0 * g
					p["head"] = float(p.get("head", 0.0)) - 6.0 * absf(g)
				"wrestler":
					# Base baixa, mãos ciscando, e de vez em quando a ameaça de entrar nas pernas.
					var lvl := pow(maxf(0.0, sin(t * 0.9 + float(i))), 8.0)
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.04 * bn * sin(t * 5.0) + 0.22 * lvl
					p["torso"] = float(p.get("torso", 0.0)) + 12.0 * lvl
					p["na_e"] = float(p.get("na_e", 0.0)) + 15.0 * sin(t * 3.9)
					p["fa_e"] = float(p.get("fa_e", 0.0)) + 13.0 * sin(t * 3.9 + 1.6)
					p["head"] = float(p.get("head", 0.0)) + 5.0 * sin(t * 2.4)
					p["x"] = float(p.get("x", 0.0)) + 0.22 * sin(t * 1.5)
				"judo":
					# Em pé, as mãos buscando a pegada, uma de cada vez.
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.03 * bn * sin(t * 4.4)
					p["na_s"] = float(p.get("na_s", 0.0)) + 10.0 * sin(t * 3.1)
					p["na_e"] = float(p.get("na_e", 0.0)) - 20.0 * maxf(0.0, sin(t * 3.1))
					p["fa_s"] = float(p.get("fa_s", 0.0)) + 10.0 * sin(t * 3.1 + PI)
					p["fa_e"] = float(p.get("fa_e", 0.0)) - 18.0 * maxf(0.0, sin(t * 3.1 + PI))
					p["x"] = float(p.get("x", 0.0)) + 0.16 * sin(t * 1.3)
				"bjj":
					# Pé no chão, pouca pressa, mãos abertas medindo.
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.025 * bn * sin(t * 3.8)
					p["na_e"] = float(p.get("na_e", 0.0)) + 10.0 * sin(t * 2.3)
					p["fa_e"] = float(p.get("fa_e", 0.0)) + 8.0 * sin(t * 2.3 + 1.2)
					p["x"] = float(p.get("x", 0.0)) + 0.14 * sin(t * 0.9)
				_:
					p["crouch"] = float(p.get("crouch", 0.0)) + 0.055 * bn * sin(t * 5.5)
					p["head"] = float(p.get("head", 0.0)) + 4.0 * sw * sin(t * 2.3)
					p["torso"] = float(p.get("torso", 0.0)) + 3.0 * sw * sin(t * 2.3 + 0.6)
					p["x"] = float(p.get("x", 0.0)) + 0.2 * sin(t * 1.6)
					p[ld + "a_s"] = float(p.get(ld + "a_s", 0.0)) + 4.0 * sin(t * 2.75)
			# Altura das mãos de cada um; quem pressiona pende para a frente.
			var hd := float(m["hands"]) * (1.0 - r.bruise)
			p["na_s"] = float(p.get("na_s", 0.0)) + hd
			p["fa_s"] = float(p.get("fa_s", 0.0)) + hd * 0.7
			p["torso"] = float(p.get("torso", 0.0)) + 4.0 * float(m["press"])
			_habit(r, p, m, t)
			# Cansaço: as mãos caem, o tronco pesa e o peito sobe e desce.
			for side: String in ["na", "fa"]:
				p[side + "_s"] = float(p.get(side + "_s", 0.0)) - 28.0 * tired
				p[side + "_e"] = float(p.get(side + "_e", 0.0)) - 25.0 * tired
			p["torso"] = float(p.get("torso", 0.0)) + 6.0 * tired + 3.5 * tired * sin(_time * 4.2 + float(i))
			p["head"] = float(p.get("head", 0.0)) + 6.0 * tired
			# Castigo que aparece no corpo: a perna batida quase não apoia, a costela marcada fecha
			# os cotovelos, o rosto machucado sobe a guarda.
			if r.leg_dmg > 0.3:
				var lg := (r.leg_dmg - 0.3) / 0.7
				p[ld + "l_h"] = float(p.get(ld + "l_h", 0.0)) - 9.0 * lg
				p[ld + "l_k"] = float(p.get(ld + "l_k", 0.0)) - 8.0 * lg
				p["torso"] = float(p.get("torso", 0.0)) - 5.0 * lg
				r.feet_tap[ld + "l"] = maxf(float(r.feet_tap[ld + "l"]), 0.07 * lg * pow(maxf(0.0, sin(_time * 2.2 + float(i))), 2.0))
			if r.body_dmg > 0.3:
				var bd := (r.body_dmg - 0.3) / 0.7
				p[rr + "a_s"] = float(p.get(rr + "a_s", 0.0)) - 16.0 * bd
				p[ld + "a_s"] = float(p.get(ld + "a_s", 0.0)) - 9.0 * bd
				p["torso"] = float(p.get("torso", 0.0)) + 7.0 * bd
			if r.bruise > 0.4:
				var br := (r.bruise - 0.4) / 0.6
				p["na_e"] = float(p.get("na_e", 0.0)) + 10.0 * br
				p["fa_e"] = float(p.get("fa_e", 0.0)) + 8.0 * br
				p["head"] = float(p.get("head", 0.0)) + 7.0 * br
		elif pos == "chao":
			p["torso"] = float(p.get("torso", 0.0)) + 2.5 * sin(_time * 2.0 + float(i)) + 2.0 * tired * sin(_time * 4.2)
		else:
			p["x"] = float(p.get("x", 0.0)) + 0.12 * sin(_time * 1.6 + float(i) * 2.0)
			p["crouch"] = float(p.get("crouch", 0.0)) + 0.04 * sin(_time * 3.1 + float(i) * 1.3)
			p["torso"] = float(p.get("torso", 0.0)) + 3.0 * tired * sin(_time * 4.2 + float(i))


## Cacoete de cada lutador, de tempos em tempos: bate as luvas, solta os ombros, estala o pescoço,
## baixa a mão para provocar.
func _habit(r: Rig2D, p: Dictionary, m: Dictionary, t: float) -> void:
	var habit := String(m["habit"])
	if habit == "" or not _act.is_empty():
		return
	var every := float(m["every"])
	var u := fmod(t, every) / 0.9
	if u >= 1.0:
		return
	var k := sin(u * PI)
	match habit:
		"luvas":
			var tap := absf(sin(u * PI * 2.0))
			_mix(p, {"na_s": 58.0, "na_e": 100.0 + 22.0 * tap, "fa_s": 54.0, "fa_e": 104.0 + 22.0 * tap}, k)
		"ombros":
			_add(p, {"na_s": -22.0, "fa_s": -20.0, "tw": 14.0 * sin(u * TAU * 1.5), "head": -6.0}, k)
		"pescoco":
			_add(p, {"head": 16.0 * sin(u * TAU * 1.5), "torso": -3.0}, k)
		"pendulo":
			_add(p, {"x": 0.5 * sin(u * TAU), "crouch": 0.06}, k)
		"mao_baixa":
			var ld := r.lead()
			_mix(p, {ld + "a_s": 14.0, ld + "a_e": 30.0}, k)
			_add(p, {"head": -8.0, "torso": -4.0}, k)


# --- Lances --------------------------------------------------------------------------------

## Curva de um golpe: 0 → 1 (sai) → segura → 0 (volta).
static func _ext(p: float, a: float = 0.18, b: float = 0.42, c: float = 0.6) -> float:
	if p < a:
		return 0.0
	if p < b:
		return smoothstep(0.0, 1.0, (p - a) / (b - a))
	if p < c:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (p - c) / (1.0 - c))


func _resolve(r: Rig2D, dir: float, over: Dictionary) -> Dictionary:
	var ld := "n" if (dir > 0.0) != r.southpaw else "f"
	var rr := "f" if ld == "n" else "n"
	var o := {}
	for k: String in over:
		var key := k
		if k.begins_with("L"):
			key = ld + k.substr(1)
		elif k.begins_with("R"):
			key = rr + k.substr(1)
		o[key] = over[k]
	return o


static func _mix(p: Dictionary, over: Dictionary, amt: float) -> void:
	if amt <= 0.0:
		return
	for k: String in over:
		var base := float(p.get(k, 0.0))
		if k in ["x", "y", "crouch"]:
			p[k] = base + float(over[k]) * amt
		else:
			p[k] = lerpf(base, float(over[k]), amt)


static func _add(p: Dictionary, over: Dictionary, amt: float) -> void:
	for k: String in over:
		p[k] = float(p.get(k, 0.0)) + float(over[k]) * amt


func _overlay(s: Dictionary, out: Array) -> void:
	var poses: Array = out[0]
	var pxs: Array = out[1]
	var dirs: Array = out[2]
	var type := String(_act["type"])
	var p := float(_act["p"])
	var a := clampi(int(_act["side"]), 0, 1)
	var d := 1 - a
	var b: Dictionary = _act["b"]
	var pa: Dictionary = poses[a]
	var pd: Dictionary = poses[d]
	var ra: Rig2D = rigs[a]
	var rd: Rig2D = rigs[d]
	var pos := String(s["pos"])
	match type:
		"golpe":
			var k := String(b.get("k", "jab"))
			if pos == "chao":
				_gnp(pa, pd, p, b, ra, float(dirs[a]))
				return
			var e := _ext(p)
			if k in SPINS and p > 0.12 and p < 0.82:
				dirs[a] = -float(dirs[a])
			# Antecipação: recolhe um instante antes de soltar o golpe.
			_add(pa, {"x": -0.22, "crouch": 0.08, "torso": -5.0}, smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.12, 0.26, p)))
			if CHAMBER.has(k):
				_mix(pa, _resolve(ra, float(dirs[a]), CHAMBER[k]), smoothstep(0.0, 0.2, p) * (1.0 - e) * (1.0 if p < 0.6 else 0.0))
			var over: Dictionary = STRIKE.get(k, STRIKE["jab"])
			if pos == "clinch":
				over = over.duplicate()
				over["x"] = 0.0
			_mix(pa, _resolve(ra, float(dirs[a]), over), e)
			_react(pd, rd, float(dirs[d]), b, p)
		"balanca":
			var w := sin(p * PI)
			_add(pd, {"crouch": 0.35, "x": -0.8, "torso": -12.0, "na_s": -35.0, "fa_s": -30.0, "nl_k": 25.0}, w)
			pd["head"] = float(pd.get("head", 0.0)) + 22.0 * sin(p * 22.0) * w
			pd["rot"] = float(pd.get("rot", 0.0)) - 8.0 * sin(p * 9.0) * w
			_add(pa, {"x": 0.6}, w)
		"kd":
			var u := smoothstep(0.0, 0.35, p)
			var down := {"sit": 1.0, "rot": 72.0, "torso": 0.0, "head": -15.0, "na_s": 20.0, "na_e": 30.0, "fa_s": 5.0, "fa_e": 40.0,
				"nl_h": 55.0, "nl_k": 30.0, "fl_h": 40.0, "fl_k": 50.0}
			_mix(pd, down, u * (1.0 - smoothstep(0.85, 1.0, p)))
			if u > 0.5:
				pd["sit"] = 1.0
			_add(pa, {"x": 0.9, "torso": 10.0}, u)
		"clinch":
			_add(pa, {"x": 0.6, "na_s": 30.0, "fa_s": 30.0}, sin(p * PI))
		"solta":
			var w2 := sin(p * PI)
			_mix(pa, {"na_s": 92.0, "na_e": 10.0, "fa_s": 88.0, "fa_e": 15.0}, w2)
			_add(pd, {"x": -0.7}, w2)
		"estudo":
			var who := int(float(b["t"]) * 10.0) % 2
			var pe: Dictionary = poses[who]
			var re: Rig2D = rigs[who]
			match int(float(b["t"])) % 3:
				0:
					_mix(pe, _resolve(re, float(dirs[who]), {"La_s": 85.0, "La_e": 50.0, "torso": 10.0}), sin(p * PI))
				1:
					_add(pe, {"x": 0.8, "crouch": 0.15}, sin(p * PI))
				_:
					_add(pe, {"x": -0.6, "head": -6.0}, sin(p * PI))
		"queda":
			_takedown(pa, pd, p, b, pxs, a, d)
		"puxa_guarda":
			if p < 0.35:
				_mix(pa, {"na_s": 110.0, "na_e": 40.0, "fa_s": 105.0, "fa_e": 50.0, "torso": 20.0}, p / 0.35)
		"segura_chute":
			# `a` segurou o chute de `d`.
			var hold := smoothstep(0.0, 0.2, p) * (1.0 - smoothstep(0.55, 0.7, p))
			_mix(pd, _resolve(rd, float(dirs[d]), {"Rl_h": 80.0, "Rl_k": 12.0, "torso": -24.0, "na_s": 60.0, "fa_s": 70.0}), hold)
			_mix(pa, {"na_s": 75.0, "na_e": 70.0, "fa_s": 70.0, "fa_e": 80.0, "torso": 10.0}, hold)
			if p < 0.6:
				pxs[a] = float(pxs[d]) - float(dirs[d]) * -2.8
		"pega_pescoco":
			var w3 := smoothstep(0.0, 0.3, p)
			_mix(pa, {"na_s": 135.0, "na_e": 75.0, "fa_s": 125.0, "fa_e": 85.0, "torso": 22.0}, w3)
			if pos != "chao":
				_mix(pd, {"torso": 70.0, "head": 30.0, "crouch": 0.3}, w3)
				pxs[a] = float(pxs[d]) - float(dirs[d]) * -1.7
		"gnp":
			_gnp(pa, pd, p, b, ra, float(dirs[a]))
		"passa", "repoe", "levanta":
			_add(pa, {"crouch": 0.2, "torso": 10.0, "y": 0.25}, sin(p * PI))
		"mat_return":
			var w4 := sin(clampf(p / 0.6, 0.0, 1.0) * PI)
			_add(pd, {"y": 1.2, "rot": 40.0}, w4)
			_mix(pa, {"na_s": 95.0, "na_e": 60.0, "fa_s": 90.0, "fa_e": 70.0, "torso": 30.0}, w4)
			if p > 0.55 and not bool(_act.get("slam", false)):
				_act["slam"] = true
				_shake = 0.5
		"raspa":
			var w5 := sin(p * PI)
			_add(pa, {"y": 0.5, "rot": -25.0}, w5)
			_add(pd, {"y": 0.9, "rot": 35.0}, w5)
		"fin":
			_submission(pa, pd, p, b, s)
		"escapa":
			_add(pa, {"x": -0.4, "torso": -12.0, "head": -15.0}, sin(p * PI))
		"fim":
			pass


## Reação de quem recebe o golpe: cabeça que estala, corpo que dobra, perna que cede; ou esquiva e
## bloqueio quando erra.
func _react(pd: Dictionary, rd: Rig2D, dir: float, b: Dictionary, p: float) -> void:
	var z := String(b.get("z", "head"))
	var k := String(b.get("k", ""))
	if bool(b.get("hit", false)):
		var amt := _ext(p, 0.4, 0.47, 0.62)
		var pw := clampf(0.6 + float(b.get("dmg", 0.3)) * 0.55, 0.6, 1.6)
		match z:
			"body":
				_add(pd, {"torso": 24.0 * pw, "crouch": 0.22 * pw, "na_s": -25.0, "fa_s": -20.0, "head": 10.0, "x": -0.25}, amt)
			"leg":
				_add(pd, _resolve(rd, dir, {"Ll_k": 40.0 * pw, "Ll_h": -12.0, "crouch": 0.18 * pw, "torso": -6.0, "x": -0.15}), amt)
			_:
				var up := -1.0 if k == "uppercut" else 1.0
				_add(pd, {"head": -32.0 * pw * up, "torso": -14.0 * pw, "x": -0.45 * pw, "na_s": -15.0, "fa_s": -10.0}, amt)
	else:
		var amt2 := _ext(p, 0.15, 0.38, 0.65)
		if z == "leg":
			_mix(pd, _resolve(rd, dir, {"Ll_h": 70.0, "Ll_k": 95.0}), amt2)
		elif z == "body":
			_mix(pd, {"na_s": 25.0, "na_e": 140.0, "fa_s": 20.0, "fa_e": 145.0}, amt2)
			_add(pd, {"x": -0.4}, amt2)
		else:
			match int(float(b["t"]) * 7.0 + float(k.length())) % 3:
				0:
					_add(pd, {"head": 18.0, "torso": 16.0, "crouch": 0.3}, amt2)
				1:
					_mix(pd, {"na_s": 95.0, "na_e": 140.0, "fa_s": 85.0, "fa_e": 150.0}, amt2)
					_add(pd, {"head": 10.0}, amt2)
				_:
					_add(pd, {"x": -0.7, "torso": -10.0}, amt2)


func _gnp(pa: Dictionary, pd: Dictionary, p: float, b: Dictionary, ra: Rig2D, dir: float) -> void:
	var arm := "na" if int(float(b["t"]) * 13.0 + p) % 2 == 0 else "fa"
	_act["arm"] = arm
	var e := _ext(p, 0.12, 0.42, 0.55)
	var cham := smoothstep(0.0, 0.15, p) * (1.0 - e)
	_mix(pa, {arm + "_s": 150.0, arm + "_e": 35.0}, cham)
	_mix(pa, {arm + "_s": 40.0, arm + "_e": 2.0, "torso": float(pa.get("torso", 0.0)) + 14.0}, e)
	if bool(b.get("hit", true)):
		var amt := _ext(p, 0.38, 0.45, 0.6)
		_add(pd, {"head": -30.0, "torso": -4.0}, amt)
	else:
		_mix(pd, {"na_s": 120.0, "na_e": 120.0, "fa_s": 110.0, "fa_e": 130.0}, _ext(p, 0.1, 0.35, 0.6))


## Queda: entrada nas pernas (baixa, joelho no chão) ou pegada de arremesso que levanta e derruba;
## quando falha, o outro sprawla por cima.
func _takedown(pa: Dictionary, pd: Dictionary, p: float, b: Dictionary, pxs: Array, a: int, d: int) -> void:
	var td := String(b.get("td", ""))
	var ok := bool(b.get("ok", false))
	var throw := td in THROWS
	var da := 1.0 if a == 0 else -1.0
	if p < 0.5:
		var u := smoothstep(0.0, 0.3, p)
		if throw:
			_mix(pa, {"torso": 15.0, "crouch": 0.35, "na_s": 105.0, "na_e": 60.0, "fa_s": 100.0, "fa_e": 70.0}, u)
			pxs[a] = float(pxs[d]) - da * lerpf(3.0, 1.6, u)
			if ok and p > 0.25:
				var v := (p - 0.25) / 0.25
				_add(pd, {"y": sin(v * PI * 0.5) * 1.6, "rot": (130.0 if td in ["suplex", "seoi", "uchi_mata", "harai"] else 60.0) * v}, 1.0)
		else:
			var lvl := 1.0 if td in ["duas_pernas", "single", "single_baixa", "baiana"] else 0.5
			_mix(pa, {"torso": 55.0 * lvl + 10.0, "crouch": 0.9 * lvl, "head": -15.0, "na_s": 100.0, "na_e": 20.0, "fa_s": 95.0, "fa_e": 30.0}, u)
			pxs[a] = float(pxs[d]) - da * lerpf(3.6, 1.4, u)
			if not ok and p > 0.25:
				var v2 := smoothstep(0.25, 0.45, p)
				_mix(pd, {"torso": 78.0, "crouch": 0.3, "nl_h": -55.0, "nl_k": 5.0, "fl_h": -65.0, "fl_k": 5.0, "na_s": 70.0, "na_e": 20.0, "fa_s": 75.0, "fa_e": 30.0}, v2)
				_add(pd, {"x": -0.5}, v2)
	elif not ok:
		var w := 1.0 - smoothstep(0.5, 1.0, p)
		_mix(pd, {"torso": 78.0, "crouch": 0.3, "nl_h": -55.0, "nl_k": 5.0, "fl_h": -65.0, "fl_k": 5.0}, w)
		_mix(pa, {"torso": 70.0, "crouch": 0.8}, w)
	else:
		var v3 := smoothstep(0.5, 0.8, p)
		_add(pd, {"y": (1.0 - v3) * (1.2 if throw else 0.4)}, 1.0)
		if v3 > 0.6 and not bool(_act.get("slam", false)):
			_act["slam"] = true
			_shake = 0.7 if throw else 0.35
			_hype = minf(1.0, _hype + (0.6 if throw else 0.3))
			_punch = 1.0 if throw else 0.5
			_fx.append({"t": 0.0, "kind": "dust", "x": float(pxs[d]), "y": 0.0, "pw": 1.0})
			_sound("queda", -6.0 if throw else -10.0)


func _submission(pa: Dictionary, pd: Dictionary, p: float, b: Dictionary, s: Dictionary) -> void:
	var sub := String(b.get("sub", ""))
	var lock := bool(b.get("lock", false))
	var sq := smoothstep(0.0, 0.3, p)
	var pulse := sin(p * 16.0) * 0.5 + 0.5
	var standing := String(s["pos"]) != "chao"
	var bottom_sub := String(s["pos"]) == "chao" and int(s["top"]) != int(_act["side"])
	match sub:
		"mata_leao", "neck_crank", "ezekiel", "norte_sul", "twister":
			_mix(pa, {"na_s": 92.0, "na_e": 80.0, "fa_s": 118.0, "fa_e": 105.0}, sq)
			_mix(pd, {"na_s": 120.0, "na_e": 115.0, "fa_s": 110.0, "fa_e": 125.0}, sq)
			_add(pa, {"torso": -10.0 * pulse}, sq)
		"guilhotina", "darce", "anaconda":
			_mix(pa, {"na_s": 125.0, "na_e": 85.0, "fa_s": 115.0, "fa_e": 95.0, "torso": 30.0 if standing else 10.0}, sq)
			_add(pa, {"torso": -12.0 * pulse}, sq)
			_mix(pd, {"head": 35.0}, sq)
		"triangulo", "omoplata":
			if bottom_sub:
				_mix(pa, {"nl_h": 115.0, "nl_k": 105.0, "fl_h": 100.0, "fl_k": 95.0}, sq)
				_mix(pd, {"torso": 55.0, "head": 30.0}, sq)
		"chave_braco", "kimura", "americana":
			_mix(pa, {"na_s": 70.0, "na_e": 40.0, "fa_s": 85.0, "fa_e": 30.0}, sq)
			if bottom_sub:
				_mix(pa, {"nl_h": 130.0, "nl_k": 40.0, "fl_h": 115.0, "fl_k": 50.0}, sq)
			_mix(pd, {"na_s": 110.0, "na_e": 0.0}, sq)
			_add(pa, {"rot": -10.0 * pulse}, sq)
		"chave_calcanhar", "chave_joelho", "botinha":
			_mix(pa, {"torso": -20.0, "na_s": 70.0, "na_e": 90.0, "fa_s": 75.0, "fa_e": 100.0}, sq)
			_mix(pd, {"nl_h": 80.0, "nl_k": 0.0}, sq)
		_:
			_mix(pa, {"na_s": 110.0, "na_e": 90.0}, sq)
	# Quem está preso briga; se encaixou, bate.
	if lock and p > 0.6:
		var tap := sin(p * 55.0)
		pd["na_s"] = 85.0 + 25.0 * tap
		pd["na_e"] = 10.0
	else:
		pd["fa_s"] = float(pd.get("fa_s", 0.0)) + 25.0 * sin(p * 10.0) * sq


## Som do lance: só com a luta na tela (2D ou 3D; no modo texto ela toca escondida), sem
## embolar quando os lances vêm em rajada (velocidade alta, "Pular").
func _sound(sound: String, db: float) -> void:
	var host := get_parent() as CanvasItem
	if host == null or not host.is_visible_in_tree() or _snd_t > 0.0 or _queue.size() > 5:
		return
	_snd_t = 0.06
	Sfx.play(sound, db)


## Contato do golpe: brilho no ponto, onda de choque, suor que voa, o rosto/corpo avermelha; nos
## fortes o quadro para um instante, a câmera dá um tranco e a torcida levanta. Bloqueio solta uma
## faísca curta onde a defesa pegou.
func _impact() -> void:
	if bool(_act["hit"]) or float(_act["p"]) < 0.42:
		return
	_act["hit"] = true
	var type := String(_act["type"])
	if type not in ["golpe", "gnp"]:
		return
	var b: Dictionary = _act["b"]
	var d := 1 - clampi(int(_act["side"]), 0, 1)
	var rd: Rig2D = rigs[d]
	var j := rd.joints(0.0, 0.0, 1.0)
	var z := String(b.get("z", "head"))
	var pt: Vector2 = j["head"]
	if z == "body":
		pt = (j["neck"] as Vector2).lerp(j["hip"], 0.45)
	elif z == "leg":
		pt = (j[rd.lead() + "l_kn"] as Vector2).lerp(j["hip"], 0.3)
	var fx := pt.x
	var fy := -pt.y
	if not bool(b.get("hit", false)):
		var standing := String(st["pos"]) != "chao"
		var blocked := z != "head" or int(float(b["t"]) * 7.0 + float(String(b.get("k", "")).length())) % 3 == 1
		if type == "golpe" and standing and blocked:
			_jolt(d, {"na_e": 150.0, "fa_e": 120.0, "x": -1.6, "torso": -50.0, "head": -90.0})
			_push_v[d] = float(_push_v[d]) - rd.dir * 1.6
			_fx.append({"t": 0.0, "kind": "block", "x": fx + rd.dir * 0.55, "y": fy - (0.3 if z == "leg" else 0.0), "pw": 0.5})
			_sound("bloqueio", -14.0)
		return
	var dmg := float(b.get("dmg", 0.3))
	var away := -rd.dir
	rd.flash = clampf(0.25 + dmg * 0.35, 0.0, 0.7)
	if String(st["pos"]) != "chao":
		var pk := clampf(0.45 + dmg * 0.75, 0.45, 1.7)
		match z:
			"body":
				_jolt(d, {"torso": 210.0 * pk, "crouch": 1.3 * pk, "head": 110.0 * pk, "x": -1.8 * pk, "na_s": -120.0 * pk, "fa_s": -90.0 * pk})
			"leg":
				_jolt(d, _resolve(rd, rd.dir, {"Ll_k": 330.0 * pk, "Ll_h": -120.0 * pk, "crouch": 1.0 * pk, "torso": 70.0 * pk}))
			_:
				var upk := -0.6 if String(b.get("k", "")) == "uppercut" else 1.0
				_jolt(d, {"head": -520.0 * pk * upk, "torso": -170.0 * pk, "x": -2.4 * pk, "na_s": -150.0 * pk, "fa_s": -110.0 * pk, "tw": 160.0 * pk})
		if String(st["pos"]) == "solto":
			_push_v[d] = float(_push_v[d]) + away * (0.9 + 2.6 * dmg) * (0.5 if z == "leg" else 1.0)
			_cx = clampf(_cx + away * dmg * 0.35, -ARENA + 4.0, ARENA - 4.0)
	_fx.append({"t": 0.0, "kind": "hit", "x": fx, "y": fy, "pw": dmg, "z": z, "v": away})
	if dmg > 0.7:
		_fx.append({"t": 0.0, "kind": "ring", "x": fx, "y": fy, "pw": dmg})
	if z == "head" and dmg > 0.45:
		_fx.append({"t": 0.0, "kind": "sweat", "x": fx, "y": fy, "pw": clampf(0.4 + dmg * 0.5, 0.5, 1.4), "v": away, "seed": _rng.randi() % 1000})
	if z == "head" and rd.cut > 0.3:
		(rigs[1 - d] as Rig2D).glove_blood += 0.12
	if z == "head" and (rd.cut > 0.25 or dmg > 1.1):
		_fx.append({"t": 0.0, "kind": "blood", "x": fx, "y": fy, "pw": clampf(rd.cut + dmg * 0.3, 0.3, 1.5), "v": away, "seed": _rng.randi() % 1000})
		if stains.size() < 30:
			stains.append({"x": rd.px + away * _rng.randf_range(0.5, 2.5), "z": _rng.randf(), "w": _rng.randf_range(0.2, 0.55) * (0.6 + rd.cut)})
	_hype = minf(1.0, _hype + 0.1 + dmg * 0.22)
	_punch = maxf(_punch, clampf(dmg * 0.7, 0.0, 1.0))
	if dmg > 0.55 and time_scale < 2.0 and _queue.size() < 4 and not AppSettings.reduce_motion:
		_hitstop = clampf(0.03 + dmg * 0.05, 0.045, 0.13)
	if dmg > 0.9:
		_shake = maxf(_shake, minf(1.0, dmg * 0.5))
		if z == "head":
			Sfx.vibrate(25)
	if z == "head" and dmg > 1.1:
		_flash = maxf(_flash, minf(1.0, dmg * 0.55))
	if dmg >= 1.3 and _hitstop > 0.0:
		# Golpe enorme: quadro de impacto (a tela escurece e riscos correm para o ponto do golpe).
		_slam = Vector2(fx, fy)
		_slam_t = 0.15
	var kk := String(b.get("k", ""))
	_sound("soco_forte" if dmg > 0.95 else ("chute" if (kk in KICKS or kk in SPINS) else "soco"), -13.0 + minf(7.0, dmg * 5.0))


# --- Desenho -------------------------------------------------------------------------------

func _origin_x() -> float:
	return size.x * 0.5 - _cam * _U


## Daqui em diante o desenho segue a câmera: zoom em volta do centro da linha do chão, o quadro
## descendo `_vy` e o tremor. `pos` e `scale` são o deslocamento e a escala de quem desenha.
func _view(pos: Vector2 = Vector2.ZERO, scale: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(_vo + pos * _vzd, 0.0, scale * _vzd)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if rigs.is_empty() or w < 10.0:
		return
	# A escala vem da altura; num quadro alto demais (tablet deitado) a largura segura, para os
	# dois lutadores caberem, e o que sobra em cima é o teto escuro do ginásio.
	_U = minf(h / 9.6, w / 12.5)
	_ground = h * 0.88
	_sh = Vector2(sin(_rt * 70.0), cos(_rt * 53.0)) * _shake * _U * 0.18
	# O tranco do golpe forte fecha um pouco o quadro (e dá folga para o tremor nas bordas).
	_vzd = _vz * (1.0 + 0.045 * _punch) + 0.03 * minf(1.0, _shake)
	_vo = Vector2(w * 0.5, _ground) * (1.0 - _vzd) + Vector2(0.0, _vy * h) + _sh
	# Ginásio escuro, fixo no quadro: o teto some no preto (a câmera desce sem abrir buraco em cima).
	_quad(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("#05060A"), Color("#05060A"), Color("#141722"), Color("#141722")]))
	_view()
	_draw_arena(w, h)
	var ox := _origin_x()
	# Sangue na lona.
	for stn: Dictionary in stains:
		var sp := Vector2(ox + float(stn["x"]) * _U, _ground - _U * 0.55 + float(stn["z"]) * _U * 0.5)
		var sw := float(stn["w"]) * _U
		draw_colored_polygon(Rig2D._oval(sp, Vector2(sw, 0), Vector2(0, sw * 0.3), 12), Color(0.45, 0.03, 0.04, 0.55))
		draw_colored_polygon(Rig2D._oval(sp + Vector2(sw * 0.8, sw * 0.09), Vector2(sw * 0.35, 0), Vector2(0, sw * 0.1), 8), Color(0.45, 0.03, 0.04, 0.45))
	# Árbitro: um pouco mais atrás (menor e mais alto na tela).
	if ref != null:
		var ur := _U * 0.88
		ref.draw(self, ox + ref.px * (_U - ur), _ground - _U * 0.5, ur)
	# Intervalo: o banquinho de cada canto e os técnicos (um pouco atrás, como o árbitro).
	for i in 2:
		var sd := float(_seated[i])
		if sd > 0.02:
			var sx := ox + (-1.0 if i == 0 else 1.0) * (ARENA - 2.4) * _U
			var top := _ground - _U * 1.66
			var steel := Color(0.56, 0.58, 0.63, sd)
			draw_line(Vector2(sx - _U * 0.4, top), Vector2(sx - _U * 0.56, _ground), steel, maxf(1.5, _U * 0.07))
			draw_line(Vector2(sx + _U * 0.4, top), Vector2(sx + _U * 0.56, _ground), steel, maxf(1.5, _U * 0.07))
			draw_rect(Rect2(sx - _U * 0.62, top - _U * 0.16, _U * 1.24, _U * 0.2), Color((UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE).darkened(0.35), sd))
	var seen := size.x / maxf(1.0, _U) * 0.5 + 2.0
	for c: Rig2D in coaches:
		if absf(c.px - _cam) < seen:
			var uc := _U * 0.9
			c.draw(self, ox + c.px * (_U - uc), _ground - _U * 0.36, uc)
	var order := [0, 1]
	var layered := -1
	if String(st["pos"]) == "chao" and not _ended:
		var tp := clampi(int(st["top"]), 0, 1)
		order = [1 - tp, tp]
		if String(st["g"]) == "costas":
			order = [tp, 1 - tp]
			layered = tp
	elif _ended and _method in ["KO", "TKO"] and _winner >= 0:
		order = [1 - _winner, _winner]
	elif not _act.is_empty() and int(_act["side"]) >= 0:
		order = [1 - int(_act["side"]), int(_act["side"])]
	# Quem sai do plano (zz) desce um pouco na tela: fica "na frente" do outro no chão.
	for i: int in order:
		var rg: Rig2D = rigs[i]
		rg.draw(self, ox, _ground + float(rg.pose.get("zz", 0.0)) * _U * 0.35, _U, 1 if i == layered else 0)
	if layered >= 0:
		(rigs[layered] as Rig2D).draw(self, ox, _ground, _U, 2)
	_draw_trail(ox)
	_draw_fx(ox)
	_draw_front_fence(w, h)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Vinheta: bordas do quadro mais escuras, como na transmissão.
	var vg := Color(0.01, 0.01, 0.03, 0.38)
	var v0 := Color(0.01, 0.01, 0.03, 0.0)
	_quad(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.16, 0), Vector2(w * 0.16, h), Vector2(0, h)]), PackedColorArray([vg, v0, v0, vg]))
	_quad(PackedVector2Array([Vector2(w, 0), Vector2(w * 0.84, 0), Vector2(w * 0.84, h), Vector2(w, h)]), PackedColorArray([vg, v0, v0, vg]))
	if _flash > 0.0:
		# Clarão do golpe que entra limpo na cabeça.
		draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.98, 0.94, 0.16 * _flash))
	if _slam_t > 0.0:
		# Quadro de impacto: a tela escurece e riscos brancos correm das bordas para o golpe.
		var ks := _slam_t / 0.15
		var sp2 := _vo + Vector2(ox + _slam.x * _U, _ground - _slam.y * _U) * _vzd
		draw_rect(Rect2(0, 0, w, h), Color(0.0, 0.0, 0.02, 0.3 * ks))
		var diag := Vector2(w, h).length()
		for i in 28:
			var a := TAU * (float(i) + 0.5 * sin(float(i) * 12.9898)) / 28.0
			var dv := Vector2(cos(a), sin(a))
			var nv := Vector2(-dv.y, dv.x)
			var r1 := diag * (0.24 + 0.14 * absf(sin(float(i) * 78.233)))
			var wd := diag * (0.006 + 0.012 * absf(sin(float(i) * 37.7)))
			draw_colored_polygon(PackedVector2Array([sp2 + dv * diag - nv * wd, sp2 + dv * r1, sp2 + dv * diag + nv * wd]), Color(1, 1, 1, 0.5 * ks))
	if not replay.is_empty():
		var bar := h * 0.07
		draw_rect(Rect2(0, 0, w, bar), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, h - bar, w, bar), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, 0, w, h), Color(0.15, 0.1, 0.05, 0.12))
		var font2 := get_theme_default_font()
		var blink := 0.6 + 0.4 * sin(_rt * 12.0)
		var ty := bar * 0.5
		draw_circle(Vector2(14 + _U * 0.2, ty), _U * 0.18, Color(0.9, 0.1, 0.1, blink))
		var lbl := "REPLAY" if replay_take() == 0 else I18n.t("REPLAY · CÂMERA LENTA")
		draw_string(font2, Vector2(14 + _U * 0.55, ty + _U * 0.2), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, int(_U * 0.55), Color.WHITE)
	_draw_plates(w, h)
	_draw_caption(w, h)


## Tamanho de fonte que faz o texto caber em `maxw`.
static func _fit(font: Font, text: String, fs: int, maxw: float) -> int:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw <= maxw or tw <= 0.0:
		return fs
	return maxi(8, int(floor(float(fs) * maxw / tw)))


## Legenda: faixa escura inclinada com filetes dourados, presa no alto do quadro (a câmera deixa
## uma folga em cima para ela). O texto entra maior e assenta; a dos lances grandes (`_cap_big`)
## aparece enorme no meio do quadro por um instante antes de subir para a faixa.
func _draw_caption(w: float, h: float) -> void:
	if _caption_t <= 0.0 or _caption == "":
		return
	var font := get_theme_default_font()
	var still := AppSettings.reduce_motion
	var dock := 1.0 if (still or not _cap_big) else smoothstep(0.4, 0.66, _cap_age)
	var fs := _fit(font, _caption, int(_U * lerpf(1.3, 0.66, dock)), w * 0.86)
	var tw := font.get_string_size(_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var a := clampf(_caption_t * 3.0, 0.0, 1.0)
	var grow := 1.0 if still else smoothstep(0.0, 0.14, _cap_age)
	var pop := 1.0 if still else 1.0 + 0.6 * exp(-_cap_age * 12.0)
	var c := Vector2(w * 0.5, h * lerpf(0.33, 0.078, dock))
	var bw := (tw * 0.5 + _U * 0.8) * grow
	var bh := float(fs) * 0.74
	var sl := bh * 0.45
	var gold := Color(UIColors.GOLD, a)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-bw + sl, -bh), c + Vector2(bw + sl, -bh), c + Vector2(bw - sl, bh), c + Vector2(-bw - sl, bh)]),
		Color(0.03, 0.03, 0.05, 0.82 * a))
	var lw := maxf(1.5, _U * 0.07)
	draw_line(c + Vector2(-bw + sl, -bh), c + Vector2(bw + sl, -bh), gold, lw)
	draw_line(c + Vector2(-bw - sl, bh), c + Vector2(bw - sl, bh), gold, lw)
	draw_set_transform(c, 0.0, Vector2(pop, pop))
	var at := Vector2(-tw * 0.5, float(fs) * 0.36)
	draw_string_outline(font, at, _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(2, int(_U * 0.16)), Color(0, 0, 0, 0.8 * a))
	draw_string(font, at, _caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, gold)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Placas: na apresentação, canto, nome e cartel de cada um enquanto a câmera está nele; no
## intervalo, os números do round de quem está em quadro.
func _draw_plates(w: float, h: float) -> void:
	if _info.size() < 2:
		return
	var p := _intro_p()
	if p >= 0.0:
		for i in 2:
			var a0 := 0.03 if i == 0 else 0.36
			var a1 := 0.33 if i == 0 else 0.66
			var info: Dictionary = _info[i]
			var tag := ("CANTO VERMELHO" if i == 0 else "CANTO AZUL")
			if String(info["nick"]) != "":
				tag += "  ·  “%s”" % String(info["nick"])
			_plate(w, h, i, smoothstep(a0, a0 + 0.05, p) * (1.0 - smoothstep(a1 - 0.04, a1, p)), tag, String(info["name"]), String(info["sub"]))
	elif _corner_on() and _focus >= 0 and replay.is_empty():
		var t := fmod(_bt - 0.8, 3.8)
		var stt: Dictionary = _stat[_focus]
		_plate(w, h, _focus, smoothstep(0.7, 0.95, t) * (1.0 - smoothstep(3.5, 3.75, t)), "NO CANTO VERMELHO" if _focus == 0 else "NO CANTO AZUL",
			String((_info[_focus] as Dictionary)["name"]), "No round:  %s   ·   %s" % [Fmt.plural(int(stt["g"]), "golpe certo", "golpes certos"), Fmt.plural(int(stt["q"]), "queda", "quedas")])


## Uma placa (terço inferior): faixa escura inclinada com a cor do canto, entrando pelo lado
## oposto ao lutador (a do canto vermelho à direita, para onde ele olha; a do azul à esquerda).
## `k`: 0 fora da tela, 1 no lugar.
func _plate(w: float, h: float, i: int, k: float, tag: String, title: String, sub: String) -> void:
	tag = I18n.t(tag)
	sub = I18n.t(sub)
	if k <= 0.0:
		return
	var font := get_theme_default_font()
	var col := UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
	var pw := minf(w * 0.6, _U * 8.6)
	var ph := _U * 2.3
	var sl := _U * 0.5
	var y := h * 0.66
	var slide := (1.0 - k) * (pw + sl + 4.0)
	var tx := 0.0
	if i == 0:
		var x := w - pw + slide
		draw_colored_polygon(PackedVector2Array([Vector2(x + sl, y), Vector2(w + slide + 2.0, y), Vector2(w + slide + 2.0, y + ph), Vector2(x, y + ph)]), Color(0.04, 0.045, 0.06, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(x + sl, y), Vector2(x + sl + _U * 0.2, y), Vector2(x + _U * 0.2, y + ph), Vector2(x, y + ph)]), col)
		tx = x + sl + _U * 0.5
	else:
		var x2 := pw - slide
		draw_colored_polygon(PackedVector2Array([Vector2(-slide - 2.0, y), Vector2(x2, y), Vector2(x2 - sl, y + ph), Vector2(-slide - 2.0, y + ph)]), Color(0.04, 0.045, 0.06, 0.9))
		draw_colored_polygon(PackedVector2Array([Vector2(x2 - _U * 0.2, y), Vector2(x2, y), Vector2(x2 - sl, y + ph), Vector2(x2 - sl - _U * 0.2, y + ph)]), col)
		tx = _U * 0.4 - slide
	var maxw := pw - sl - _U * 1.2
	draw_string(font, Vector2(tx, y + _U * 0.58), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(font, tag, int(_U * 0.4), maxw), col.lightened(0.35))
	draw_string(font, Vector2(tx, y + _U * 1.38), title, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(font, title, int(_U * 0.8), maxw), Color.WHITE)
	draw_string(font, Vector2(tx, y + _U * 1.98), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, _fit(font, sub, int(_U * 0.4), maxw), Color(0.8, 0.82, 0.87))


## Tons de camisa e de pele da torcida (escurecidos pela penumbra do ginásio).
const CROWD_SHIRTS := [Color("#3A3F4C"), Color("#2B2E38"), Color("#5A2A30"), Color("#27384F"), Color("#6B6E78"), Color("#3E4A3A"), Color("#8A8780"), Color("#4A3A52")]
const CROWD_SKIN := [Color("#C99E7C"), Color("#8E6243"), Color("#E0B896"), Color("#5E3D28"), Color("#B5825C")]


## Quadrilátero com cor por vértice, sem triangulação.
const QUAD_IDX := [0, 1, 2, 0, 2, 3]
var _bake_key := Vector2.ZERO
## Torcida pronta em três camadas de profundidade: [pontos, cores, índices] cada.
var _crowd_layers: Array = []
var _flashes: Array = []
var _fence_pts := PackedVector2Array()


func _quad(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(QUAD_IDX), pts, cols)


## Monta de uma vez a torcida e o alambrado (não mudam de um quadro para o outro; só deslizam
## com a câmera), para o desenho de cada quadro ficar leve no celular.
func _bake_arena(w: float, h: float) -> void:
	if _bake_key == Vector2(w, h) and not _crowd_layers.is_empty():
		return
	_bake_key = Vector2(w, h)
	var period := w + _U * 4.0
	_crowd_layers = []
	_flashes = []
	for l in 3:
		_crowd_layers.append([PackedVector2Array(), PackedColorArray(), PackedInt32Array()])
	var ring: Array = []
	for i in 8:
		ring.append(Vector2.RIGHT.rotated(TAU * float(i) / 8.0))
	for c: Vector3 in _crowd:
		var dpt := c.y
		var lay: Array = _crowd_layers[mini(2, int(dpt * 3.0))]
		var pts: PackedVector2Array = lay[0]
		var cols: PackedColorArray = lay[1]
		var idx: PackedInt32Array = lay[2]
		var x := fposmod(w * 0.5 + c.x * _U, period) - _U * 2.0
		var r := _U * (0.2 + dpt * 0.22)
		var y := h * 0.1 + dpt * h * 0.4
		var lum := lerpf(0.34, 0.8, dpt)
		var shirt: Color = CROWD_SHIRTS[int(c.z * 7.99)]
		var skin: Color = CROWD_SKIN[int(fposmod(c.z * 31.0, 1.0) * 4.99)]
		shirt = Color(shirt.r * lum, shirt.g * lum, shirt.b * lum * 1.08)
		skin = Color(skin.r * lum * 0.62, skin.g * lum * 0.6, skin.b * lum * 0.66)
		# Ombros e tronco.
		var b0 := pts.size()
		for q: Vector2 in [Vector2(-0.75, 0.8), Vector2(0.75, 0.8), Vector2(1.35, 1.5), Vector2(1.35, 2.6), Vector2(-1.35, 2.6), Vector2(-1.35, 1.5)]:
			pts.append(Vector2(x, y) + q * r)
			cols.append(shirt)
		for t in 4:
			idx.append_array([b0, b0 + t + 1, b0 + t + 2])
		if fposmod(c.z * 7.0, 1.0) < 0.14:
			# Braço para o alto.
			b0 = pts.size()
			for q: Vector2 in [Vector2(0.9, 1.4), Vector2(1.3, 1.4), Vector2(1.7, -2.1), Vector2(1.3, -2.1)]:
				pts.append(Vector2(x, y) + q * r)
				cols.append(skin)
			idx.append_array([b0, b0 + 1, b0 + 2, b0, b0 + 2, b0 + 3])
		# Cabeça e cabelo.
		for part in 2:
			b0 = pts.size()
			var hc := Vector2(x, y) if part == 0 else Vector2(x, y - r * 0.28)
			var hr := r if part == 0 else r * 0.86
			var hcol := skin if part == 0 else skin.darkened(0.45)
			for v: Vector2 in ring:
				pts.append(hc + v * hr)
				cols.append(hcol)
			for t in 6:
				idx.append_array([b0, b0 + t + 1, b0 + t + 2])
		lay[0] = pts
		lay[1] = cols
		lay[2] = idx
		if fposmod(c.z * 5.0, 1.0) < 0.2:
			_flashes.append([Vector2(x + r * 0.9, y - r * 0.6), r, c.z, mini(2, int(dpt * 3.0))])
	# Alambrado do fundo: losangos numa largura que cobre a tela toda.
	var fence_top := _ground - _U * 7.6
	var fence_bot := _ground - _U * 0.75
	var step := _U * 0.55
	var hh := fence_bot - fence_top
	_fence_pts = PackedVector2Array()
	var x0 := -step * 2.0
	while x0 < w + hh + step:
		_fence_pts.append_array(PackedVector2Array([Vector2(x0, fence_top), Vector2(x0 - hh * 0.6, fence_bot), Vector2(x0 - hh * 0.6, fence_top), Vector2(x0, fence_bot)]))
		x0 += step


func _draw_arena(w: float, h: float) -> void:
	_bake_arena(w, h)
	var rid := get_canvas_item()
	var fence_top := _ground - _U * 7.6
	var fence_bot := _ground - _U * 0.75
	var cx := w * 0.5 - _cam * _U
	# Torcida em profundidade: quem está longe é menor e mais apagado; pula no golpe forte.
	var par := 0.35
	var period := w + _U * 4.0
	var offs := [0.0, 0.0, 0.0]
	for l in 3:
		var lay: Array = _crowd_layers[l]
		var off := fposmod(-_cam * par * (0.7 + 0.5 * (float(l) + 0.5) / 3.0) * _U, period)
		# A torcida pula com a empolgação: cada fileira no seu tempo.
		var bob := sin(_rt * 1.7 + float(l) * 2.1) * _U * 0.02 - _shake * _U * (0.06 + 0.05 * float(l)) \
			- absf(sin(_rt * (5.2 + 0.7 * float(l)) + float(l) * 1.3)) * _U * 0.17 * _hype
		offs[l] = off
		if (lay[2] as PackedInt32Array).is_empty():
			continue
		for k in 2:
			_view(Vector2(off - period * float(k), bob))
			RenderingServer.canvas_item_add_triangle_array(rid, lay[2], lay[0], lay[1])
	_view()
	# Flashes das câmeras: poucos na luta morna, muitos quando o ginásio levanta.
	for f: Array in _flashes:
		if fmod(float(f[2]) * 97.0 + _fclock, 9.0) < 0.06 + 0.07 * _hype:
			var fp0: Vector2 = f[0]
			var fx := fposmod(fp0.x + float(offs[int(f[3])]) + _U * 2.0, period) - _U * 2.0
			draw_circle(Vector2(fx, fp0.y), float(f[1]) * 0.75, Color(1, 1, 1, 0.25))
			draw_circle(Vector2(fx, fp0.y), float(f[1]) * 0.3, Color(1, 1, 1, 0.95))
	# Névoa do ginásio por cima da torcida e os fachos dos refletores.
	draw_rect(Rect2(0, -h * 0.5, w, h * 0.5), Color(0.02, 0.03, 0.05, 0.75))
	_quad(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, fence_bot), Vector2(0, fence_bot)]),
		PackedColorArray([Color(0.02, 0.03, 0.05, 0.75), Color(0.02, 0.03, 0.05, 0.75), Color(0.1, 0.12, 0.18, 0.0), Color(0.1, 0.12, 0.18, 0.0)]))
	var truss_y := h * 0.035
	var beam_c := PackedColorArray([Color(1.0, 0.96, 0.86, 0.075), Color(1.0, 0.96, 0.86, 0.075), Color(1.0, 0.96, 0.86, 0.0), Color(1.0, 0.96, 0.86, 0.0)])
	for i in 5:
		var lx := w * 0.5 + (float(i) - 2.0) * _U * 4.6 - _cam * _U * 0.12
		var spread := _U * (3.4 + 0.6 * absf(float(i) - 2.0))
		var tx := cx + (float(i) - 2.0) * _U * 2.2
		_quad(PackedVector2Array([Vector2(lx - _U * 0.2, truss_y), Vector2(lx + _U * 0.2, truss_y), Vector2(tx + spread, _ground), Vector2(tx - spread, _ground)]), beam_c)
	draw_rect(Rect2(0, truss_y - _U * 0.22, w, _U * 0.2), Color("#0B0C10"))
	for i in 5:
		var lx2 := w * 0.5 + (float(i) - 2.0) * _U * 4.6 - _cam * _U * 0.12
		draw_rect(Rect2(lx2 - _U * 0.32, truss_y - _U * 0.1, _U * 0.64, _U * 0.3), Color("#16181E"))
		draw_circle(Vector2(lx2, truss_y + _U * 0.2), _U * 0.55, Color(1.0, 0.95, 0.82, 0.1))
		draw_circle(Vector2(lx2, truss_y + _U * 0.2), _U * 0.2, Color(1.0, 0.97, 0.9, 0.9))
	# Grade do fundo: tela de alambrado com postes e o acolchoado de cima.
	draw_rect(Rect2(0, fence_top, w, fence_bot - fence_top), Color(0, 0, 0, 0.25))
	var fp := 0.8
	var step := _U * 0.55
	_view(Vector2(fposmod(-_cam * fp * _U, step), 0))
	draw_multiline(_fence_pts, Color(0.62, 0.64, 0.7, 0.16), 1.0)
	_view()
	# Rodapé acolchoado da grade, com as placas dos patrocinadores.
	var band_h := _U * 0.62
	draw_rect(Rect2(0, fence_bot - band_h, w, band_h), Color("#0E1014"))
	draw_rect(Rect2(0, fence_bot - band_h, w, _U * 0.07), Color(_org, 0.75))
	var ad_step := _U * 4.2
	var ax := fposmod(w * 0.5 - _cam * fp * _U, ad_step) - ad_step
	var ad_i := int(floor((_cam * fp * _U - w * 0.5) / ad_step))
	while ax < w + ad_step:
		ad_i += 1
		var light := posmod(ad_i, 2) == 0
		var ar := Rect2(ax + _U * 0.5, fence_bot - band_h + _U * 0.16, _U * 2.6, band_h - _U * 0.26)
		draw_rect(ar, Color(_org.darkened(0.25), 0.9) if light else Color(0.86, 0.85, 0.82, 0.85))
		draw_rect(Rect2(ar.position + Vector2(_U * 0.25, ar.size.y * 0.3), Vector2(_U * 1.3, ar.size.y * 0.4)), Color(1, 1, 1, 0.8) if light else Color(_org.darkened(0.4), 0.85))
		draw_rect(Rect2(ar.position + Vector2(_U * 1.75, ar.size.y * 0.3), Vector2(_U * 0.55, ar.size.y * 0.4)), Color(1, 1, 1, 0.45) if light else Color(0.1, 0.1, 0.12, 0.6))
		ax += ad_step
	var post_step := _U * 7.0
	var poff := fposmod(w * 0.5 - _cam * fp * _U, post_step)
	var px := poff - post_step
	while px < w + post_step:
		draw_rect(Rect2(px - _U * 0.2, fence_top - _U * 0.3, _U * 0.4, fence_bot - fence_top + _U * 0.3), Color("#15171C"))
		draw_rect(Rect2(px - _U * 0.2, fence_top - _U * 0.3, _U * 0.12, fence_bot - fence_top + _U * 0.3), Color(1, 1, 1, 0.05))
		draw_rect(Rect2(px - _U * 0.2, fence_top - _U * 0.3, _U * 0.4, _U * 0.9), _org.darkened(0.35))
		px += post_step
	draw_rect(Rect2(0, fence_top - _U * 0.35, w, _U * 0.4), Color("#1D1F25"))
	draw_rect(Rect2(0, fence_top - _U * 0.35, w, _U * 0.08), _org.darkened(0.2))
	draw_rect(Rect2(0, fence_top - _U * 0.05, w, _U * 0.1), Color(0, 0, 0, 0.35))
	# Lona: clara no meio (onde a luz bate) e mais escura nas pontas; marca da liga no centro.
	var floor_top := _ground - _U * 0.75
	_quad(PackedVector2Array([Vector2(0, floor_top), Vector2(w, floor_top), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("#9D9A93"), Color("#9D9A93"), Color("#DEDBD3"), Color("#DEDBD3")]))
	draw_rect(Rect2(0, h, w, _U), Color("#DEDBD3"))
	draw_rect(Rect2(0, floor_top, w, maxf(1.0, _U * 0.08)), Color(0, 0, 0, 0.3))
	var ec := Vector2(cx, _ground + _U * 0.15)
	_view(ec, Vector2(1.0, 0.12))
	draw_circle(Vector2.ZERO, _U * 9.5, Color(1.0, 0.98, 0.92, 0.16))
	draw_circle(Vector2.ZERO, _U * 5.9, Color(_org, 0.5))
	draw_circle(Vector2.ZERO, _U * 4.6, Color(_org.lerp(Color("#E4E1D9"), 0.72), 0.95))
	draw_arc(Vector2.ZERO, _U * 4.6, 0.0, TAU, 40, Color(1, 1, 1, 0.55), maxf(1.0, _U * 0.2))
	var font := get_theme_default_font()
	var fs := _fit(font, logo, maxi(8, int(_U * 1.1)), _U * 8.4)
	var tw := font.get_string_size(logo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_view(ec + Vector2(0, _U * 0.2), Vector2(1.0, 0.34))
	draw_string(font, Vector2(-tw * 0.5, fs * 0.36), logo, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(_org.darkened(0.3), 0.6))
	_view()
	# Pontas da lona na penumbra.
	for sgn2: float in [-1.0, 1.0]:
		var e0 := cx + sgn2 * _U * 8.0
		var e1 := cx + sgn2 * _U * 17.0
		_quad(PackedVector2Array([Vector2(e0, floor_top), Vector2(e1, floor_top), Vector2(e1, h + _U), Vector2(e0, h + _U)]),
			PackedColorArray([Color(0.05, 0.06, 0.1, 0.0), Color(0.05, 0.06, 0.1, 0.42), Color(0.05, 0.06, 0.1, 0.42), Color(0.05, 0.06, 0.1, 0.0)]))
		draw_rect(Rect2(minf(e1, e1 + sgn2 * w), floor_top, w, h + _U - floor_top), Color(0.05, 0.06, 0.1, 0.42))
	# Cantos azul e vermelho nas pontas da arena.
	for sgn: float in [-1.0, 1.0]:
		var ex := w * 0.5 + (sgn * (ARENA + 0.4) - _cam) * _U
		var col := UIColors.CORNER_RED if sgn < 0.0 else UIColors.CORNER_BLUE
		draw_rect(Rect2(ex - _U * 0.3, fence_top - _U * 0.4, _U * 0.6, _ground - fence_top + _U * 0.4), Color("#101216"))
		draw_rect(Rect2(ex - _U * 0.3, fence_top - _U * 0.4, _U * 0.6, _U * 1.4), col)


## Grade da frente nas pontas: o alambrado por cima de quem está encostado.
func _draw_front_fence(w: float, h: float) -> void:
	for sgn: float in [-1.0, 1.0]:
		var ex := w * 0.5 + (sgn * (ARENA + 0.4) - _cam) * _U
		var x_in := ex
		var x_out := ex + sgn * w
		var r := Rect2(minf(x_in, x_out), 0, absf(x_out - x_in), h)
		if r.end.x < 0.0 or r.position.x > w:
			continue
		draw_rect(r, Color(0.04, 0.05, 0.07, 0.55))
		var step := _U * 0.5
		var x := r.position.x
		while x < r.end.x:
			draw_line(Vector2(x, 0), Vector2(x + h * 0.5, h), Color(0.7, 0.72, 0.78, 0.22), 1.0)
			draw_line(Vector2(x + h * 0.5, 0), Vector2(x, h), Color(0.7, 0.72, 0.78, 0.22), 1.0)
			x += step


## Rastro do golpe: fita branca que afina e some atrás da luva (ou da canela).
func _draw_trail(ox: float) -> void:
	var n := _trail.size()
	if n < 2:
		return
	var pts := PackedVector2Array()
	for pt: Dictionary in _trail:
		pts.append(Vector2(ox + float(pt["x"]) * _U, _ground - float(pt["y"]) * _U))
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in n:
		var same_prev := i > 0 and int((_trail[i - 1] as Dictionary)["n"]) == int((_trail[i] as Dictionary)["n"])
		var same_next := i < n - 1 and int((_trail[i + 1] as Dictionary)["n"]) == int((_trail[i] as Dictionary)["n"])
		var dv := (pts[i + 1] if same_next else pts[i]) - (pts[i - 1] if same_prev else pts[i])
		var nn := Vector2(-dv.y, dv.x).normalized() if dv.length() > 0.01 else Vector2.ZERO
		var hw := float((_trail[i] as Dictionary)["w"]) * _U * 0.5 * float((_trail[i] as Dictionary)["a"])
		left.append(pts[i] + nn * hw)
		right.append(pts[i] - nn * hw)
	for i in range(1, n):
		var a: Dictionary = _trail[i - 1]
		var b: Dictionary = _trail[i]
		if int(a["n"]) != int(b["n"]):
			continue
		var ca := Color(a.get("c", Color.WHITE) as Color, 0.34 * float(a["a"]) * float(a["a"]))
		var cb := Color(b.get("c", Color.WHITE) as Color, 0.34 * float(b["a"]) * float(b["a"]))
		_quad(PackedVector2Array([left[i - 1], left[i], right[i], right[i - 1]]), PackedColorArray([ca, cb, cb, ca]))


func _draw_fx(ox: float) -> void:
	for f: Dictionary in _fx:
		var t := float(f["t"])
		var pw := float(f["pw"])
		var p := Vector2(ox + float(f["x"]) * _U, _ground - float(f.get("y", 0.0)) * _U)
		match String(f["kind"]):
			"blood":
				var sd := int(f["seed"])
				for i in 9:
					var a := -0.9 + float((sd + i * 37) % 100) / 100.0 * 1.2
					var sp := (2.5 + float((sd * 3 + i * 17) % 100) / 40.0) * _U
					var v := Vector2(cos(a) * float(f["v"]), sin(a)) * sp
					var q := p + v * t + Vector2(0, 14.0 * _U) * t * t
					if q.y > _ground:
						continue
					draw_circle(q, _U * (0.07 + 0.05 * float(i % 3)) * pw, Color(0.6, 0.02, 0.03, clampf(1.0 - t, 0.0, 1.0)))
			"sweat":
				# Suor que voa da cabeça: gotas em leque para o lado da força, com um risquinho atrás.
				var sd2 := int(f["seed"])
				var al2 := clampf(1.0 - t / 0.7, 0.0, 1.0)
				for i in 11:
					var a := -1.3 + float((sd2 + i * 37) % 100) / 100.0 * 1.7
					var sp := (2.6 + float((sd2 * 3 + i * 17) % 100) / 26.0) * _U * pw
					var v := Vector2(cos(a) * float(f["v"]), sin(a)) * sp
					var q := p + v * t + Vector2(0, 11.0 * _U) * t * t
					if q.y > _ground:
						continue
					var vel := v + Vector2(0, 22.0 * _U) * t
					draw_line(q - vel.normalized() * _U * 0.2, q, Color(0.86, 0.94, 1.0, 0.8 * al2), maxf(1.0, _U * 0.055))
			"ring":
				# Onda de choque do golpe forte.
				var k := clampf(t / 0.42, 0.0, 1.0)
				var out := 1.0 - (1.0 - k) * (1.0 - k)
				draw_arc(p, _U * (0.3 + (1.0 + minf(pw, 2.0) * 0.7) * out), 0.0, TAU, 32, Color(1.0, 0.97, 0.9, 0.42 * (1.0 - k)), maxf(1.0, _U * 0.1 * (1.0 - k)))
			"block":
				# Defesa: faísca curta e fria onde o golpe parou.
				var k2 := clampf(t / 0.3, 0.0, 1.0)
				var c2 := Color(0.8, 0.88, 1.0, 0.75 * (1.0 - k2))
				for i in 5:
					var a := TAU * float(i) / 5.0 + float(f["x"]) * 3.0
					var dv := Vector2(cos(a), sin(a))
					draw_line(p + dv * _U * (0.15 + 0.35 * k2), p + dv * _U * (0.32 + 0.55 * k2), c2, maxf(1.0, _U * 0.06))
			"mouth":
				# Protetor bucal: sai girando da boca e fica caído na lona.
				var v2 := Vector2(float(f["v"]) * 3.4, -5.2) * _U
				var q2 := p + v2 * t + Vector2(0, 9.0 * _U) * t * t
				var spin := t * 16.0
				if q2.y > _ground - _U * 0.1:
					q2.y = _ground - _U * 0.1
					spin = 0.4
				draw_arc(q2, _U * 0.12, spin, spin + PI, 8, Color(0.96, 0.96, 0.92, clampf((1.3 - t) * 4.0, 0.0, 1.0)), maxf(1.5, _U * 0.07))
			"dust":
				for i in 6:
					var a := PI + PI * float(i) / 5.0
					var v := Vector2(cos(a), sin(a) * 0.4) * _U * (0.6 + t * 5.0)
					draw_circle(Vector2(p.x, _ground) + v, _U * (0.35 - t * 0.5), Color(0.85, 0.82, 0.75, 0.6 * (1.0 - t * 2.0)))
			_:
				# Faísca do contato: clarão branco que fecha, brilho quente em volta e farpas afiadas
				# de tamanhos desiguais; as do lado para onde o golpe empurra são mais compridas.
				var k3 := clampf(t / 0.24, 0.0, 1.0)
				if k3 >= 1.0:
					continue
				var grow := 1.0 - (1.0 - k3) * (1.0 - k3)
				var r0 := _U * (0.26 + minf(pw, 2.0) * 0.26)
				var vx := float(f.get("v", 0.0))
				draw_circle(p, r0 * (1.6 + 0.8 * grow), Color(1.0, 0.82, 0.45, 0.2 * (1.0 - k3)))
				var sd3 := int(absf(float(f["x"])) * 977.0) % 97
				for i in 9:
					var a := TAU * (float(i) + float((sd3 + i * 31) % 10) * 0.06) / 9.0
					var dv := Vector2(cos(a), sin(a))
					var push := maxf(0.0, dv.x * vx)
					var ln := r0 * (1.3 + float((sd3 * 7 + i * 13) % 10) * 0.12 + 1.5 * push) * (0.45 + 0.75 * grow)
					var hw := r0 * 0.2 * (1.0 - k3)
					var nv := Vector2(-dv.y, dv.x)
					var b0 := p + dv * r0 * 0.35 * grow
					draw_colored_polygon(PackedVector2Array([b0 - nv * hw, b0 + dv * ln, b0 + nv * hw]), Color(1.0, 0.96, 0.8, 0.95 * (1.0 - k3 * k3)))
				draw_circle(p, r0 * 0.8 * (1.0 - 0.75 * k3), Color(1, 1, 1, 0.95 * (1.0 - k3)))
