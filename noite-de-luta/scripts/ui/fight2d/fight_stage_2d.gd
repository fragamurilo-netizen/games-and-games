class_name FightStage2D
extends Control
## A luta animada em 2D, de lado, como numa transmissão: dois `Rig2D` no octógono que encenam os
## lances estruturados do motor (`FightEngine.beats`). A tela da luta entrega cada lance quando o
## relógio passa por ele (`add_beat`); aqui eles tocam em fila, um depois do outro, e a fila acelera
## quando acumula (velocidade rápida, "Pular").
##
## Cada quadro: pose de base do momento (em pé na guarda da escola, clinch, posição no chão, fim)
## + o movimento do lance em andamento (golpe com preparação, extensão e volta; queda; ground and
## pound; finalização...) + vida (balanço, cansaço) → as poses andam suavemente até esse alvo.

const ARENA := 15.0 ## meia largura do octógono, em U
const GAP := [5.4, 4.3, 3.3] ## distância entre as cinturas por distância do motor (longa, média, curta)
## Duração base de cada lance, em segundos de tela.
const DUR := {"golpe": 0.42, "chute": 0.58, "giro": 0.75, "kd": 1.7, "balanca": 0.9, "clinch": 0.55, "solta": 0.5, "estudo": 0.7,
	"queda": 1.15, "puxa_guarda": 0.9, "segura_chute": 1.0, "pega_pescoco": 0.9, "gnp": 0.34, "passa": 0.75, "levanta": 0.9,
	"mat_return": 1.0, "raspa": 1.0, "repoe": 0.7, "fin": 1.5, "escapa": 0.7, "fim": 2.2, "round": 0.2, "fim_round": 0.6}
## Em que ponto do lance o corpo já vai para a posição nova (quedas, raspagens).
const SWITCH := {"queda": 0.5, "puxa_guarda": 0.35, "segura_chute": 0.6, "raspa": 0.5, "levanta": 0.35, "mat_return": 0.55, "passa": 0.3}
const THROWS := ["suplex", "uchi_mata", "seoi", "harai", "quadril", "corpo", "levantamento", "pegada_cinto"]
const KICKS := ["chute_baixo", "chute_corpo", "chute_alto", "chute_frontal", "chute_panturrilha", "chute_obliquo", "joelhada", "joelhada_voadora"]
const SPINS := ["chute_giratorio", "chute_rodado"]
## Golpes: pose estendida. Chaves com L/R são o braço/perna da frente/de trás (La_s, Rl_h...).
const STRIKE := {
	"jab": {"La_s": 97.0, "La_e": 2.0, "torso": 10.0, "head": 6.0, "x": 0.75},
	"direto": {"Ra_s": 94.0, "Ra_e": 4.0, "La_s": 70.0, "La_e": 130.0, "torso": 20.0, "x": 0.75, "Rl_h": -32.0, "Rl_k": 10.0},
	"gancho": {"La_s": 92.0, "La_e": 75.0, "torso": 6.0, "head": 4.0, "x": 0.35, "crouch": 0.3},
	"uppercut": {"Ra_s": 55.0, "Ra_e": 95.0, "torso": 10.0, "x": 0.5, "crouch": 0.35},
	"overhand": {"Ra_s": 150.0, "Ra_e": -55.0, "torso": 32.0, "x": 0.9, "crouch": 0.3},
	"backfist": {"La_s": 102.0, "La_e": 0.0, "torso": -4.0, "x": 0.5},
	"superman": {"Ra_s": 100.0, "Ra_e": 4.0, "La_s": 30.0, "La_e": 40.0, "torso": 24.0, "x": 1.3, "y": 0.7, "Rl_h": -60.0, "Rl_k": 70.0},
	"cotovelada": {"La_s": 100.0, "La_e": 150.0, "torso": 14.0, "x": 0.8},
	"joelhada": {"Rl_h": 100.0, "Rl_k": 125.0, "torso": -6.0, "La_s": 115.0, "La_e": 40.0, "Ra_s": 105.0, "Ra_e": 50.0, "x": 0.5},
	"joelhada_voadora": {"Rl_h": 105.0, "Rl_k": 130.0, "Ll_h": 15.0, "Ll_k": 90.0, "y": 1.1, "torso": -8.0, "x": 1.1, "La_s": 40.0, "La_e": 40.0},
	"chute_baixo": {"Rl_h": 58.0, "Rl_k": 8.0, "torso": -18.0, "Ra_s": -20.0, "Ra_e": 20.0, "x": 0.3},
	"chute_panturrilha": {"Rl_h": 42.0, "Rl_k": 4.0, "torso": -14.0, "Ra_s": -15.0, "Ra_e": 25.0, "x": 0.35},
	"chute_obliquo": {"Ll_h": 55.0, "Ll_k": 0.0, "torso": -16.0, "x": 0.2},
	"chute_corpo": {"Rl_h": 88.0, "Rl_k": 6.0, "torso": -28.0, "Ra_s": -25.0, "Ra_e": 10.0, "x": 0.35},
	"chute_alto": {"Rl_h": 142.0, "Rl_k": 8.0, "torso": -44.0, "Ra_s": -30.0, "Ra_e": 10.0, "x": 0.4},
	"chute_frontal": {"Ll_h": 92.0, "Ll_k": 0.0, "torso": -18.0, "x": 0.25},
	"chute_giratorio": {"Rl_h": -96.0, "Rl_k": 0.0, "torso": 34.0, "head": -20.0, "x": -0.4},
	"chute_rodado": {"Rl_h": -125.0, "Rl_k": 6.0, "torso": 45.0, "head": -25.0, "x": -0.4},
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

var rigs: Array = []
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
var _zoom := 1.0


func setup(w: GameWorld, fa: Fighter, fb: Fighter, org_color: Color = Color("#C8102E")) -> void:
	rigs = [Rig2D.from_fighter(w, fa, 1.0), Rig2D.from_fighter(w, fb, -1.0)]
	for i in 2:
		var r: Rig2D = rigs[i]
		r.corner = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
		if w.team(([fa, fb][i] as Fighter).team_id) == null:
			r.shorts = r.corner.darkened(0.35)
			r.trim = Color("#F1F0EC")
	# Equipes com a mesma cor: o corner azul usa calção azul para dar para distinguir.
	var c0: Color = (rigs[0] as Rig2D).shorts
	var c1: Color = (rigs[1] as Rig2D).shorts
	if Vector3(c0.r - c1.r, c0.g - c1.g, c0.b - c1.b).length() < 0.3:
		(rigs[1] as Rig2D).shorts = UIColors.CORNER_BLUE.darkened(0.35)
		(rigs[1] as Rig2D).trim = Color("#F1F0EC")
	(rigs[0] as Rig2D).px = -GAP[1] * 0.5
	(rigs[1] as Rig2D).px = GAP[1] * 0.5
	_org = org_color
	custom_minimum_size = Vector2(0, 300)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = hash(fa.id * 7919 + fb.id)
	ref = Rig2D.referee(_rng)
	for i in 150:
		_crowd.append(Vector3(_rng.randf_range(-40.0, 40.0), _rng.randf(), _rng.randf()))


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
	if not last_big.is_empty():
		_start(last_big)


func idle() -> bool:
	return _act.is_empty() and _queue.is_empty() and replay.is_empty()


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
	match type:
		"round":
			_between = false
			_ended = false
			_replayed = false
			_cx = 0.0
			_plum = -1
			for i in 2:
				(rigs[i] as Rig2D).dir = 1.0 if i == 0 else -1.0
		"fim_round":
			_between = true
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
	match type:
		"kd":
			_caption = "KNOCKDOWN!"
			_caption_t = 1.6
			_shake = 1.0
			_slowmo = 0.7
			Sfx.vibrate(40)
		"fim":
			_caption_for(b)
			if _method in ["KO", "TKO"]:
				_slowmo = 1.0
				_shake = 1.2
		"fin":
			if bool(b.get("lock", false)):
				_caption = "ENCAIXOU!"
				_caption_t = 1.2
		"queda":
			if bool(b.get("ok", false)) and String(b.get("td", "")) in THROWS:
				_shake = 0.6


func _caption_for(b: Dictionary) -> void:
	var m := String(b.get("m", ""))
	_caption = {"KO": "NOCAUTE!", "TKO": "NOCAUTE TÉCNICO!", "FIN": "FINALIZAÇÃO!"}.get(m, "FIM DE LUTA")
	_caption_t = 99.0


# --- Quadro a quadro -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if rigs.is_empty():
		return
	if AppSettings.reduce_motion:
		_shake = 0.0
		_slowmo = 0.0
	var dt := delta * (0.35 if _slowmo > 0.0 else 1.0)
	_slowmo -= delta
	_time += dt
	if not replay.is_empty():
		_play_replay(delta)
		return
	var speed := time_scale * (1.0 + 0.22 * float(_queue.size()))
	if not _act.is_empty():
		_act["p"] = float(_act["p"]) + dt * speed / float(_act["dur"])
		_impact()
		# Combinação: o golpe seguinte do mesmo lutador sai antes do anterior voltar inteiro.
		var chain := String(_act["type"]) in ["golpe", "gnp"] and float(_act["p"]) >= 0.68 and _queue.size() > 0 \
			and String((_queue[0] as Dictionary)["type"]) == String(_act["type"]) and int((_queue[0] as Dictionary)["side"]) == int(_act["side"])
		if float(_act["p"]) >= 1.0 or chain:
			var was_ko := String(_act["type"]) == "fim" and _method in ["KO", "TKO"]
			_act = {}
			if was_ko and not _replayed and _hist.size() > 30 and not AppSettings.reduce_motion:
				_replayed = true
				replay = {"frames": _hist.duplicate(), "t": 0.0}
				_caption_t = 0.0
	if _act.is_empty() and _queue.size() > 0:
		_start(_queue.pop_front())
	_animate(dt)
	_animate_ref(dt)
	_record(dt)
	_shake = maxf(0.0, _shake - delta * 2.5)
	_zoom = lerpf(_zoom, 1.0, 1.0 - exp(-3.0 * delta))
	_caption_t -= delta
	_tick_fx(delta)
	queue_redraw()


func _tick_fx(delta: float) -> void:
	for f: Dictionary in _fx:
		f["t"] = float(f["t"]) + delta
	_fx = _fx.filter(func(f: Dictionary) -> bool: return float(f["t"]) < (0.9 if String(f["kind"]) == "blood" else 0.5))


# --- Replay ------------------------------------------------------------------------------

## Grava o quadro (poses, posições, brilhos) para o replay; guarda uns 4 segundos.
func _record(dt: float) -> void:
	var fr := {"dt": dt, "p": [], "x": [], "d": [], "f": [], "fx": _fx.duplicate(true)}
	for r: Rig2D in [rigs[0], rigs[1], ref]:
		fr["p"].append(r.pose.duplicate())
		fr["x"].append(r.px)
		fr["d"].append(r.dir)
		fr["f"].append(r.flash)
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


## O replay toca os quadros gravados devagar, com zoom, e depois volta para o fim de luta.
func _play_replay(delta: float) -> void:
	var frames: Array = replay["frames"]
	replay["t"] = float(replay["t"]) + delta * 0.4
	var acc := 0.0
	var idx := frames.size() - 1
	for i in frames.size():
		acc += float((frames[i] as Dictionary)["dt"])
		if acc >= float(replay["t"]):
			idx = i
			break
	var fr: Dictionary = frames[idx]
	var all := [rigs[0], rigs[1], ref]
	for i in 3:
		var r: Rig2D = all[i]
		r.pose = (fr["p"][i] as Dictionary).duplicate()
		r.px = float(fr["x"][i])
		r.dir = float(fr["d"][i])
		if i < 2:
			r.flash = float(fr["f"][i])
	_fx = (fr["fx"] as Array).duplicate(true)
	_zoom = lerpf(_zoom, 1.12, 1.0 - exp(-3.0 * delta))
	_time += delta * 0.4
	if idx >= frames.size() - 1:
		replay = {}
		_fx = []
		_caption_t = 99.0
	queue_redraw()


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
	p["crouch"] = float(p.get("crouch", 0.0)) + 0.03 * sin(_time * 3.0)
	ref.pose = Rig2D.blend(ref.pose, p, 1.0 - exp(-8.0 * dt))
	ref.px = lerpf(ref.px, tx, 1.0 - exp(-(4.0 if _ended else 2.2) * dt))


func _animate(dt: float) -> void:
	var tg := _targets()
	var poses: Array = tg[0]
	var pxs: Array = tg[1]
	var dirs: Array = tg[2]
	var fast := not _act.is_empty() and String(_act["type"]) in ["golpe", "gnp", "estudo", "balanca", "fin", "escapa"]
	var rate := 34.0 if fast else 9.0
	var a := 1.0 - exp(-rate * dt)
	var ap := 1.0 - exp(-(10.0 if fast else 4.5) * dt)
	for i in 2:
		var r: Rig2D = rigs[i]
		if not is_equal_approx(r.dir, float(dirs[i])):
			r.dir = float(dirs[i])
			r.pose = (poses[i] as Dictionary).duplicate()
		else:
			r.pose = Rig2D.blend(r.pose, poses[i], a)
		r.px = clampf(lerpf(r.px, float(pxs[i]), ap), -ARENA + 0.6, ARENA - 0.6)
		r.flash = maxf(0.0, r.flash - dt * 3.0)
	var mid := ((rigs[0] as Rig2D).px + (rigs[1] as Rig2D).px) * 0.5
	var half := size.x / maxf(1.0, _U) * 0.5
	var lim := maxf(0.0, ARENA + 1.0 - half)
	_cam = lerpf(_cam, clampf(mid, -lim, lim), 1.0 - exp(-3.0 * dt))


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
	var target_cx := sin(_time * 0.17) * 3.0
	if bool(s["cage"]):
		target_cx = _cage_side * (ARENA - 1.4 - gap * 0.5)
	_cx = lerpf(_cx, target_cx, 0.02)
	pxs = [_cx - gap * 0.5, _cx + gap * 0.5]
	return [poses, pxs, dirs]


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
			B.merge({"sit": 1.0, "rot": 90.0, "head": 20.0, "na_s": 75.0, "na_e": 70.0, "fa_s": 40.0, "fa_e": 80.0, "nl_h": 40.0, "nl_k": 80.0, "fl_h": 25.0, "fl_k": 70.0}, true)
			T.merge({"torso": 78.0, "head": 10.0, "na_s": 30.0, "na_e": 40.0, "fa_s": 60.0, "fa_e": 30.0, "nl_h": -15.0, "nl_k": 75.0, "fl_h": -40.0, "fl_k": 55.0}, true)
			t_off = 0.4
			T.merge({"lz": 0.5, "zz": 0.95}, true)
		"montada":
			B.merge({"sit": 1.0, "rot": 90.0, "head": 25.0, "na_s": 90.0, "na_e": 30.0, "fa_s": 75.0, "fa_e": 45.0, "nl_h": 45.0, "nl_k": 90.0, "fl_h": 35.0, "fl_k": 85.0}, true)
			T.merge({"sit": 1.0, "y": 0.1, "torso": 8.0, "head": 5.0, "na_s": 65.0, "na_e": 30.0, "fa_s": 50.0, "fa_e": 40.0, "nl_h": 70.0, "nl_k": 155.0, "fl_h": 62.0, "fl_k": 150.0}, true)
			t_off = -0.5
			T["lz"] = 2.0
		"costas":
			B.merge({"sit": 1.0, "rot": 0.0, "torso": -12.0, "head": 10.0, "na_s": 70.0, "na_e": 60.0, "fa_s": 60.0, "fa_e": 70.0, "nl_h": 86.0, "nl_k": 8.0, "fl_h": 82.0, "fl_k": 12.0}, true)
			T.merge({"sit": 1.0, "torso": 6.0, "head": 12.0, "na_s": 88.0, "na_e": 55.0, "fa_s": 70.0, "fa_e": 70.0, "nl_h": 86.0, "nl_k": 6.0, "fl_h": 82.0, "fl_k": 10.0}, true)
			t_off = -1.15
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
	var bob := absf(sin(_time * 5.0)) * 0.25
	poses[w] = _relaxed(rigs[w])
	(poses[w] as Dictionary).merge({"na_s": 168.0, "na_e": 12.0, "fa_s": 160.0, "fa_e": 18.0, "head": -18.0, "torso": -6.0, "y": bob}, true)
	if _winner < 0:
		poses[l] = _relaxed(rigs[l])
		(poses[l] as Dictionary).merge({"head": 20.0, "torso": 10.0}, true)
		poses[w] = _relaxed(rigs[w])
	elif _method in ["KO", "TKO"]:
		poses[l] = {"sit": 1.0, "rot": 92.0, "torso": 0.0, "head": -10.0, "na_s": 8.0, "na_e": 15.0, "fa_s": -10.0, "fa_e": 20.0,
			"nl_h": 15.0, "nl_k": 25.0, "fl_h": 5.0, "fl_k": 10.0, "x": 0.0, "y": 0.0, "crouch": 0.0}
	else:
		poses[l] = _relaxed(rigs[l])
		(poses[l] as Dictionary).merge({"head": 28.0, "torso": 14.0, "na_s": 20.0}, true)
	var pxs := [0.0, 0.0]
	var c := _cx
	if String(s["pos"]) == "chao" or _method in ["KO", "TKO"]:
		pxs[l] = c - dl * 0.8
		pxs[w] = pxs[l] + dl * 3.6
	else:
		pxs = [c - 2.2, c + 2.2]
	return [poses, pxs, dirs]


## Vida: balanço da base, cabeça do boxeador, mãos caindo com o cansaço.
func _life(s: Dictionary, poses: Array) -> void:
	var pos := String(s["pos"])
	for i in 2:
		var r: Rig2D = rigs[i]
		var p: Dictionary = poses[i]
		var tired := clampf(1.0 - float(stamina[i]), 0.0, 1.0)
		var ph := _time * (7.5 if r.guard in ["karate", "thai"] else 5.5) + float(i) * 1.7
		if pos == "solto" and not _between:
			p["crouch"] = float(p.get("crouch", 0.0)) + 0.05 * sin(ph) * (1.0 - tired * 0.6)
			p["x"] = float(p.get("x", 0.0)) + (0.35 if r.guard == "karate" else 0.15) * sin(ph * 0.31)
			if r.guard == "boxe":
				p["head"] = float(p.get("head", 0.0)) + 8.0 * sin(_time * 2.6 + float(i))
				p["torso"] = float(p.get("torso", 0.0)) + 6.0 * sin(_time * 2.6 + float(i))
			for side: String in ["na", "fa"]:
				p[side + "_s"] = float(p.get(side + "_s", 0.0)) - 28.0 * tired + 3.0 * sin(ph * 0.5)
				p[side + "_e"] = float(p.get(side + "_e", 0.0)) - 25.0 * tired
			p["torso"] = float(p.get("torso", 0.0)) + 6.0 * tired
		elif pos == "chao":
			p["torso"] = float(p.get("torso", 0.0)) + 2.5 * sin(_time * 2.0 + float(i))
		else:
			p["x"] = float(p.get("x", 0.0)) + 0.12 * sin(_time * 1.6 + float(i) * 2.0)


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
			_fx.append({"t": 0.0, "kind": "dust", "x": float(pxs[d]), "pw": 1.0})


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


## Contato do golpe: brilho no ponto, o rosto/corpo avermelha, a tela treme nos fortes.
func _impact() -> void:
	if bool(_act["hit"]) or float(_act["p"]) < 0.42:
		return
	_act["hit"] = true
	var type := String(_act["type"])
	if type not in ["golpe", "gnp"]:
		return
	var b: Dictionary = _act["b"]
	if not bool(b.get("hit", false)):
		return
	var d := 1 - clampi(int(_act["side"]), 0, 1)
	var rd: Rig2D = rigs[d]
	var dmg := float(b.get("dmg", 0.3))
	rd.flash = clampf(0.25 + dmg * 0.35, 0.0, 0.7)
	var j := rd.joints(_origin_x(), _ground, _U)
	var z := String(b.get("z", "head"))
	var pt: Vector2 = j["head"]
	if z == "body":
		pt = (j["neck"] as Vector2).lerp(j["hip"], 0.45)
	elif z == "leg":
		pt = (j[rd.lead() + "l_kn"] as Vector2).lerp(j["hip"], 0.3)
	_fx.append({"t": 0.0, "kind": "hit", "x": (pt.x - _origin_x()) / _U, "y": (_ground - pt.y) / _U, "pw": dmg, "z": z})
	if z == "head" and (rd.cut > 0.25 or dmg > 1.1):
		var away := -rd.dir
		_fx.append({"t": 0.0, "kind": "blood", "x": (pt.x - _origin_x()) / _U, "y": (_ground - pt.y) / _U, "pw": clampf(rd.cut + dmg * 0.3, 0.3, 1.5), "v": away, "seed": _rng.randi() % 1000})
		if stains.size() < 30:
			stains.append({"x": rd.px + away * _rng.randf_range(0.5, 2.5), "z": _rng.randf(), "w": _rng.randf_range(0.2, 0.55) * (0.6 + rd.cut)})
	if dmg > 0.9:
		_shake = maxf(_shake, minf(1.0, dmg * 0.5))
		if z == "head":
			Sfx.vibrate(25)


# --- Desenho -------------------------------------------------------------------------------

func _origin_x() -> float:
	return size.x * 0.5 - _cam * _U


func _draw() -> void:
	var w := size.x
	var h := size.y
	if rigs.is_empty() or w < 10.0:
		return
	_U = h / 9.6 * _zoom
	_ground = h * 0.88
	var sh := Vector2(sin(_time * 70.0), cos(_time * 53.0)) * _shake * _U * 0.18
	draw_set_transform(sh, 0.0, Vector2.ONE)
	_draw_arena(w, h)
	var ox := _origin_x()
	# Sangue na lona.
	for stn: Dictionary in stains:
		var sp := Vector2(ox + float(stn["x"]) * _U, _ground - _U * 0.55 + float(stn["z"]) * _U * 0.5)
		var sw := float(stn["w"]) * _U
		draw_set_transform(sp, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, sw, Color(0.45, 0.03, 0.04, 0.55))
		draw_circle(Vector2(sw * 0.8, sw * 0.3), sw * 0.35, Color(0.45, 0.03, 0.04, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Árbitro: um pouco mais atrás (menor e mais alto na tela).
	if ref != null:
		var ur := _U * 0.88
		ref.draw(self, ox + ref.px * (_U - ur), _ground - _U * 0.5, ur)
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
	_draw_fx(ox)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_front_fence(w, h)
	if not replay.is_empty():
		var font2 := get_theme_default_font()
		var blink := 0.6 + 0.4 * sin(_time * 12.0)
		draw_rect(Rect2(10, 10, _U * 3.6, _U * 0.95), Color(0, 0, 0, 0.6))
		draw_circle(Vector2(10 + _U * 0.45, 10 + _U * 0.48), _U * 0.2, Color(0.9, 0.1, 0.1, blink))
		draw_string(font2, Vector2(10 + _U * 0.8, 10 + _U * 0.72), "REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, int(_U * 0.6), Color.WHITE)
	if _caption_t > 0.0 and _caption != "":
		var font := get_theme_default_font()
		var fs := int(_U * 1.15)
		var a := clampf(_caption_t * 2.0, 0.0, 1.0)
		var y := h * 0.2
		draw_string_outline(font, Vector2(0, y), _caption, HORIZONTAL_ALIGNMENT_CENTER, w, fs, maxi(2, int(_U * 0.2)), Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(0, y), _caption, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(UIColors.GOLD, a))


func _draw_arena(w: float, h: float) -> void:
	# Fundo escuro do ginásio, com a luz caindo no octógono.
	draw_rect(Rect2(0, 0, w, h), Color("#0C0E13"))
	var glow := PackedVector2Array([Vector2(w * 0.5 - _U * 3.0, 0), Vector2(w * 0.5 + _U * 3.0, 0), Vector2(w + _U * 4.0, _ground), Vector2(-_U * 4.0, _ground)])
	draw_colored_polygon(glow, Color(1.0, 0.95, 0.85, 0.05))
	# Torcida (parallax lento), com flashes de celular.
	var par := 0.35
	for c: Vector3 in _crowd:
		var x := w * 0.5 + (c.x - _cam * par) * _U
		x = fposmod(x, w + _U * 4.0) - _U * 2.0
		var y := h * 0.12 + c.y * h * 0.38
		var r := _U * (0.22 + c.y * 0.2)
		var col := Color(0.16, 0.17, 0.21).lerp(Color(0.24, 0.24, 0.28), c.z)
		draw_circle(Vector2(x, y), r, col)
		draw_rect(Rect2(x - r * 1.1, y + r * 0.7, r * 2.2, r * 1.4), col.darkened(0.2))
		if fmod(c.z * 97.0 + _time * 0.7, 9.0) < 0.06:
			draw_circle(Vector2(x, y - r), r * 0.5, Color(1, 1, 1, 0.9))
	# Grade do fundo: tela de alambrado com postes e o acolchoado de cima.
	var fence_top := _ground - _U * 7.6
	var fence_bot := _ground - _U * 0.75
	draw_rect(Rect2(0, fence_top, w, fence_bot - fence_top), Color(0, 0, 0, 0.25))
	var fp := 0.8
	var step := _U * 0.55
	var off := fposmod(-_cam * fp * _U, step)
	var x0 := -step * 2.0 + off
	var mesh := Color(0.62, 0.64, 0.7, 0.16)
	var hh := fence_bot - fence_top
	while x0 < w + hh:
		draw_line(Vector2(x0, fence_top), Vector2(x0 - hh * 0.6, fence_bot), mesh, 1.0)
		draw_line(Vector2(x0 - hh * 0.6, fence_top), Vector2(x0, fence_bot), mesh, 1.0)
		x0 += step
	var post_step := _U * 7.0
	var poff := fposmod(w * 0.5 - _cam * fp * _U, post_step)
	var px := poff - post_step
	while px < w + post_step:
		draw_rect(Rect2(px - _U * 0.18, fence_top - _U * 0.3, _U * 0.36, fence_bot - fence_top + _U * 0.3), Color("#15171C"))
		draw_rect(Rect2(px - _U * 0.18, fence_top - _U * 0.3, _U * 0.36, _U * 0.9), _org.darkened(0.35))
		px += post_step
	draw_rect(Rect2(0, fence_top - _U * 0.35, w, _U * 0.4), Color("#1D1F25"))
	draw_rect(Rect2(0, fence_top - _U * 0.35, w, _U * 0.08), _org.darkened(0.2))
	# Lona: clara, com a marca no centro e o anel colorido.
	var floor_top := _ground - _U * 0.75
	draw_polygon(PackedVector2Array([Vector2(0, floor_top), Vector2(w, floor_top), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color("#B9B5AC"), Color("#B9B5AC"), Color("#E4E1D9"), Color("#E4E1D9")]))
	var cx := w * 0.5 - _cam * _U
	draw_set_transform(Vector2(cx, _ground + _U * 0.15), 0.0, Vector2(1.0, 0.12))
	draw_circle(Vector2.ZERO, _U * 5.5, Color(_org, 0.22))
	draw_arc(Vector2.ZERO, _U * 5.5, 0.0, TAU, 48, Color(_org, 0.5), _U * 0.9)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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


func _draw_fx(ox: float) -> void:
	for f: Dictionary in _fx:
		var t := float(f["t"])
		var pw := float(f["pw"])
		if String(f["kind"]) == "blood":
			var o := Vector2(ox + float(f["x"]) * _U, _ground - float(f["y"]) * _U)
			var sd := int(f["seed"])
			for i in 9:
				var a := -0.9 + float((sd + i * 37) % 100) / 100.0 * 1.2
				var sp := (2.5 + float((sd * 3 + i * 17) % 100) / 40.0) * _U
				var v := Vector2(cos(a) * float(f["v"]), sin(a)) * sp
				var q := o + v * t + Vector2(0, 14.0 * _U) * t * t
				if q.y > _ground:
					continue
				draw_circle(q, _U * (0.07 + 0.05 * float(i % 3)) * pw, Color(0.6, 0.02, 0.03, clampf(1.0 - t, 0.0, 1.0)))
			continue
		if String(f["kind"]) == "dust":
			var c := Vector2(ox + float(f["x"]) * _U, _ground)
			for i in 6:
				var a := PI + PI * float(i) / 5.0
				var v := Vector2(cos(a), sin(a) * 0.4) * _U * (0.6 + t * 5.0)
				draw_circle(c + v, _U * (0.35 - t * 0.5), Color(0.85, 0.82, 0.75, 0.6 * (1.0 - t * 2.0)))
			continue
		var p := Vector2(ox + float(f["x"]) * _U, _ground - float(f["y"]) * _U)
		var al := clampf(1.0 - t * 2.2, 0.0, 1.0)
		var rad := _U * (0.3 + pw * 0.45) * (0.5 + t * 3.0)
		var core := Color(1.0, 0.95, 0.75, al)
		draw_circle(p, rad * 0.45, Color(1, 1, 1, al * 0.7))
		for i in 8:
			var a := TAU * float(i) / 8.0 + float(f["x"])
			var dv := Vector2(cos(a), sin(a))
			draw_line(p + dv * rad * 0.5, p + dv * rad * (1.0 + 0.4 * float(i % 2)), core, maxf(1.0, _U * 0.08))
		if String(f.get("z", "")) == "head" and pw > 0.6:
			for i in 5:
				var a := -PI * 0.5 + float(i - 2) * 0.35
				draw_circle(p + Vector2(cos(a) * -signf(float(f["x"]) - _cam), sin(a)) * _U * (0.4 + t * 4.0), _U * 0.08, Color(0.75, 0.88, 1.0, al))
