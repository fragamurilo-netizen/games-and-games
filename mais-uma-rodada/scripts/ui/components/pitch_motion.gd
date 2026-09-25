class_name PitchMotion
extends RefCounted
## Motor visual da partida 2D: 22 jogadores com movimento próprio, bola com altura e efeito,
## árbitro e bandeirinhas. Encena as jogadas que a MatchSimulation decidiu (quem tem a bola, em
## que zona, quem finaliza, quem dá o passe e como termina): troca de passes, condução, virada de
## jogo, lançamento, cruzamento, cabeceio, chute, defesa, rebote, escanteio, falta com barreira,
## pênalti, tiro de meta, impedimento com bandeira e comemoração.
## Só apresentação, com RNG próprio: assistir nunca muda o placar.
##
## Coordenadas em metros no referencial canônico da PitchView: x = comprimento (0 = gol do
## mandante, 105 = gol do visitante; o mandante ataca para x = 105), y = largura (0..68).

const L := 105.0
const W := 68.0
const GOAL_HW := 3.66
const BOX_D := 16.5
const JOG := 5.0
const RUN := 7.2
const SPRINT := 8.8

class Ag:
	var side := 0
	var idx := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var fx := 0.5 # vaga: lateral (0..1, visão de quem ataca)
	var fy := 0.3 # vaga: profundidade (0 próprio gol .. 1 gol adversário)
	var role := "CM"
	var on := true
	var gk := false
	var number := 0
	var name := ""
	var down := 0.0 # caído (s)
	var card := 0 # 1 amarelo, 2 vermelho (enquanto o árbitro mostra)
	var card_t := 0.0
	var hurt := 0.0 # atendimento médico (s)
	var dive := 0.0 # goleiro se esticando (s)
	var run := 0.0 # fase da passada
	var face := Vector2.RIGHT
	var arms := 0.0 # braços para cima (comemoração/reclamação)

var agents: Array = [[], []]
var ball := Vector2(L * 0.5, W * 0.5)
var ball_h := 0.0
var ball_spin := 0.0
var owner: Ag = null
var poss := 0
var zone := 0.5 # profundidade para onde a posse caminha (visão de quem tem a bola)
var tempo := 1.3
var frozen := false
var mode := "play" # play | set | goal | kickoff
var ref_pos := Vector2(L * 0.5, W * 0.6)
var ref_face := Vector2.RIGHT
var ref_run := 0.0
var ref_card := 0
var ref_card_t := 0.0
var ref_var := 0.0
var ar_pos: Array = [Vector2(L * 0.75, -1.4), Vector2(L * 0.25, W + 1.4)]
var ar_flag: Array = [0.0, 0.0]
var whistle := 0.0
var net_hit := -1 # rede que balançou: 0 = gol em x=0, 1 = gol em x=105
var net_t := 0.0
var trail: Array = [] # rastro da bola nos chutes: [Vector2, h, idade]
var rng := RandomNumberGenerator.new()

var _t := 0.0
var _queue: Array = []
var _act: Dictionary = {}
var _act_t := 0.0
var _fl: Dictionary = {} # voo da bola {from, to, dur, t, loft, kind, curve}
var _ovr: Dictionary = {} # Ag -> {to, spd, t}
var _set: Dictionary = {} # bola parada {kind, side, at, taker, wall}
var _amb_t := 0.8
var _line: Array = [0.2, 0.2] # profundidade da penúltima linha de cada time (visão própria)
var _press: Array = [null, null]
var _cover: Array = [null, null]
var _celebr: Dictionary = {}


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value


# ---------------------------------------------------------------------------
# Conversões
# ---------------------------------------------------------------------------

## Profundidade/lateral na visão de quem ataca → metros canônicos.
static func own(side: int, d: float, l: float) -> Vector2:
	if side == 0:
		return Vector2(d * L, l * W)
	return Vector2((1.0 - d) * L, (1.0 - l) * W)


static func depth(side: int, p: Vector2) -> float:
	return p.x / L if side == 0 else 1.0 - p.x / L


static func lat(side: int, p: Vector2) -> float:
	return p.y / W if side == 0 else 1.0 - p.y / W


static func goal_x(side: int) -> float:
	return L if side == 0 else 0.0


static func dir(side: int) -> float:
	return 1.0 if side == 0 else -1.0


func ag(side: int, idx: int) -> Ag:
	if side < 0 or side > 1 or idx < 0 or idx >= agents[side].size():
		return null
	var a: Ag = agents[side][idx]
	return a if a.on else null


func keeper(side: int) -> Ag:
	for a: Ag in agents[side]:
		if a.on and a.gk:
			return a
	return null


func busy() -> bool:
	return not _queue.is_empty() or not _act.is_empty() or not _fl.is_empty()


## Tempo (em segundos reais) que a jogada roteirizada ainda deve levar.
func busy_time() -> float:
	var t := 0.0
	for a in _queue:
		t += float(a.get("est", 0.5))
	if not _act.is_empty():
		t += maxf(0.0, float(_act.get("est", 0.5)) - _act_t)
	return t / maxf(0.3, tempo)


# ---------------------------------------------------------------------------
# Elencos (vêm do _sync_slots da tela)
# ---------------------------------------------------------------------------

## slots: [{x, y, number, on, name, role, gk}] na ordem das vagas.
func set_team(side: int, slots: Array) -> void:
	var arr: Array = agents[side]
	var fresh := arr.is_empty()
	while arr.size() < slots.size():
		var a := Ag.new()
		a.side = side
		a.idx = arr.size()
		arr.append(a)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var a: Ag = arr[i]
		var was_on := a.on
		var old_num := a.number
		a.fx = float(s.get("x", 0.5))
		a.fy = float(s.get("y", 0.3))
		a.role = String(s.get("role", "CM"))
		a.gk = bool(s.get("gk", i == 0))
		a.number = int(s.get("number", 0))
		a.name = String(s.get("name", ""))
		a.on = bool(s.get("on", true))
		if fresh:
			a.pos = _kick_shape(a)
		elif a.on and (not was_on or old_num != a.number):
			# Quem entra vem da beira do campo, na linha do meio.
			a.pos = Vector2(L * 0.5 + rng.randf_range(-3, 3), W + 1.5)
			a.down = 0.0
			a.card = 0
		if not a.on and owner == a:
			owner = null
	for i in range(slots.size(), arr.size()):
		(arr[i] as Ag).on = false


# ---------------------------------------------------------------------------
# API de jogadas
# ---------------------------------------------------------------------------

## Saída de bola: `side` dá a saída. instant: todos já posicionados (início de tempo).
func kickoff(side: int, instant: bool) -> void:
	_clear()
	mode = "kickoff"
	poss = side
	zone = 0.45
	ball = Vector2(L * 0.5, W * 0.5)
	ball_h = 0.0
	_celebr = {}
	net_hit = -1
	for s in 2:
		for a: Ag in agents[s]:
			a.down = 0.0
			a.dive = 0.0
			a.arms = 0.0
			if instant and a.on:
				a.pos = _kick_shape(a)
				a.vel = Vector2.ZERO
	ref_pos = Vector2(L * 0.5 - 6.0, W * 0.5 + 9.0)
	var k := _forward(side)
	owner = null
	if k != null:
		_ovr[k] = {"to": ball - Vector2(dir(side) * 0.6, 0), "spd": JOG, "t": 9.0}
		if instant:
			k.pos = ball - Vector2(dir(side) * 0.6, 0)
	_q({"k": "wait", "dur": 0.9 if instant else 2.6, "est": 1.2})
	_q({"k": "give", "ag": k, "est": 0.1})
	_q({"k": "whistle", "est": 0.1})
	var back := _pick_mid(side, true)
	if back != null:
		_q({"k": "pass", "to": back, "loft": 0.0, "spd": 14.0, "est": 0.8})
	_q({"k": "mode", "m": "play", "est": 0.0})


## Troca de posse/zona sem lance marcante (a bola rola).
func ambient(side: int, to_depth: float) -> void:
	zone = clampf(to_depth, 0.12, 0.85)
	if busy() or mode == "goal":
		return
	if side != poss:
		_turnover(side)


## Jogada roteirizada a partir do lance da simulação. info:
## {kind, side, ct, res, sh, as, p, p2, gk, card, danger, line, zone, own}
func play(info: Dictionary) -> void:
	if mode == "goal" and String(info.get("kind", "")) != "kickoff":
		return
	_finish_now()
	var kind := String(info.get("kind", ""))
	var side := int(info.get("side", 0))
	zone = clampf(float(info.get("zone", zone)), 0.1, 0.9)
	match kind:
		"chance":
			_script_chance(info)
		"foul":
			_script_foul(info)
		"offside":
			_script_offside(info)
		"corner":
			_script_corner(side, ag(side, int(info.get("p", -1))), null)
		"skill":
			_script_skill(side, ag(side, int(info.get("p", -1))), ag(1 - side, int(info.get("p2", -1))))
		"tackle":
			_script_tackle(side, ag(side, int(info.get("p", -1))), ag(1 - side, int(info.get("p2", -1))))
		"keeper":
			_script_keeper(side)
		"injury":
			var v := ag(side, int(info.get("p", -1)))
			if v != null:
				v.down = 4.0
				v.hurt = 4.0
				_q({"k": "whistle", "est": 0.1})
				_q({"k": "stop", "est": 0.1})
				_q({"k": "wait", "dur": 1.8, "est": 1.8})
		_:
			ambient(side, zone)


func show_card(side: int, idx: int, red: bool) -> void:
	var a := ag(side, idx)
	if a == null:
		return
	a.card = 2 if red else 1
	a.card_t = 2.4
	ref_card = a.card
	ref_card_t = 2.4
	_ovr[a] = {"to": a.pos, "spd": 1.0, "t": 2.0}


func var_check(t: float) -> void:
	ref_var = t


func player_down(side: int, idx: int, t: float) -> void:
	var a := ag(side, idx)
	if a != null:
		a.down = t


## Gol: a bola já está na rede. Quem fez corre para a bandeira de escanteio.
func celebrate(side: int, scorer_idx: int) -> void:
	mode = "goal"
	_queue.clear()
	_act = {}
	owner = null
	var sc := ag(side, scorer_idx)
	if sc == null:
		sc = _forward(side)
	var gx := goal_x(side)
	var corner := Vector2(gx - dir(side) * 4.0, 2.5 if sc != null and sc.pos.y < W * 0.5 else W - 2.5)
	_celebr = {"side": side, "sc": sc, "at": corner}
	if sc != null:
		_ovr[sc] = {"to": corner, "spd": SPRINT, "t": 30.0}
		sc.arms = 30.0
	for a: Ag in agents[side]:
		if a.on and a != sc and not a.gk:
			a.arms = 30.0
	for a: Ag in agents[1 - side]:
		if a.on:
			a.arms = 0.0


# ---------------------------------------------------------------------------
# Laço
# ---------------------------------------------------------------------------

func update(delta: float) -> void:
	if frozen:
		return
	var dt := delta * tempo
	_t += dt
	_compute_lines()
	_run_actions(dt)
	_update_ball(dt)
	_update_agents(dt)
	_update_officials(dt)
	whistle = maxf(0.0, whistle - delta)
	net_t = maxf(0.0, net_t - delta)
	ref_card_t = maxf(0.0, ref_card_t - dt)
	if ref_card_t <= 0.0:
		ref_card = 0
	ref_var = maxf(0.0, ref_var - dt)
	for i in 2:
		ar_flag[i] = maxf(0.0, float(ar_flag[i]) - dt)
	for tr in trail:
		tr[2] += delta
	while not trail.is_empty() and float(trail[0][2]) > 0.35:
		trail.pop_front()
	if mode == "play" and not busy():
		_amb_t -= dt
		if _amb_t <= 0.0:
			_ambient_action()


func _run_actions(dt: float) -> void:
	var guard := 0
	while guard < 6:
		guard += 1
		if _act.is_empty():
			if _queue.is_empty():
				return
			_act = _queue.pop_front()
			_act_t = 0.0
			if not _start_action(_act):
				_act = {}
				continue
		_act_t += dt
		if _action_done(_act):
			_end_action(_act)
			_act = {}
			continue
		return


func _q(a: Dictionary) -> void:
	_queue.append(a)


func _clear() -> void:
	_queue.clear()
	_act = {}
	_fl = {}
	_ovr.clear()
	_set = {}
	if mode == "set":
		mode = "play"


## Conclui na hora o que estava em andamento (nova jogada chegou): bola vai ao destino.
func _finish_now() -> void:
	if not _fl.is_empty():
		ball = _fl["to"]
		ball_h = 0.0
		var rc: Ag = _fl.get("rc", null)
		if rc != null and rc.on:
			owner = rc
			poss = rc.side
		_fl = {}
	_queue.clear()
	_act = {}
	_ovr.clear()
	_set = {}
	if mode == "set" or mode == "kickoff":
		mode = "play"
	for s in 2:
		for a: Ag in agents[s]:
			a.dive = 0.0


# ---------------------------------------------------------------------------
# Ações
# ---------------------------------------------------------------------------

## Retorna false se a ação não pode começar (e é descartada).
func _start_action(a: Dictionary) -> bool:
	match String(a["k"]):
		"wait":
			return true
		"give":
			var g: Ag = a.get("ag", null)
			if g == null or not g.on:
				return false
			owner = g
			poss = g.side
			return true
		"steal":
			var g2: Ag = a.get("ag", null)
			if g2 == null or not g2.on:
				return false
			owner = null
			poss = g2.side
			_fly(g2.pos + g2.face * 0.6, 0.0, 16.0, "pass", g2)
			_ovr[g2] = {"to": g2.pos, "spd": RUN, "t": 0.6}
			return true
		"carry":
			if owner == null:
				return false
			var to: Vector2 = _clamp_field(a["to"])
			_ovr[owner] = {"to": to, "spd": float(a.get("spd", RUN)), "t": 9.0}
			return true
		"pass":
			if owner == null:
				return false
			var rc: Ag = a.get("to", null)
			if rc != null and not rc.on:
				rc = null
			var at: Vector2 = a.get("at", rc.pos + rc.vel * 0.4 if rc != null else ball)
			at = _clamp_field(at) if not a.get("free", false) else at
			var from_ag := owner
			owner = null
			from_ag.face = (at - from_ag.pos).normalized() if at != from_ag.pos else from_ag.face
			_fly(at, float(a.get("loft", 0.0)), float(a.get("spd", 17.0)), String(a.get("kind", "pass")), rc, float(a.get("curve", 0.0)))
			if rc != null:
				_ovr[rc] = {"to": at, "spd": SPRINT, "t": float(_fl["dur"]) + 0.3}
			return true
		"shot":
			if owner == null:
				return false
			var sh := owner
			owner = null
			var at2: Vector2 = a["at"]
			sh.face = (at2 - sh.pos).normalized()
			_fly(at2, float(a.get("loft", 0.5)), float(a.get("spd", 26.0)), "shot", null, float(a.get("curve", 0.0)))
			var gk: Ag = a.get("gk", null)
			if gk != null and a.has("gk_to"):
				_ovr[gk] = {"to": a["gk_to"], "spd": float(a.get("gk_spd", 8.5)), "t": float(_fl["dur"]) + 0.5}
				gk.dive = float(_fl["dur"]) + 0.5 if a.get("dive", false) else 0.0
			var bl: Ag = a.get("blocker", null)
			if bl != null:
				_ovr[bl] = {"to": a["at"], "spd": SPRINT, "t": float(_fl["dur"]) + 0.3}
			return true
		"fly":
			# Bola solta (rebote, desvio, afastada): sem dono até alguém chegar.
			owner = null
			_fly(a["at"], float(a.get("loft", 0.0)), float(a.get("spd", 15.0)), "loose", a.get("to", null))
			var rc2: Ag = a.get("to", null)
			if rc2 != null:
				_ovr[rc2] = {"to": a["at"], "spd": SPRINT, "t": float(_fl["dur"]) + 0.4}
			return true
		"set":
			_set = a.duplicate()
			mode = "set"
			owner = null
			var at3: Vector2 = a["at"]
			if ball.distance_to(at3) > 1.0:
				_fly(at3, 0.8 if ball.distance_to(at3) > 12.0 else 0.0, 22.0, "place", null)
			var tk: Ag = a.get("taker", null)
			if tk != null:
				var back := (at3 - _goal_center(1 - int(a["side"]))).normalized() if String(a.get("sk", "")) != "throw" else Vector2(0, signf(at3.y - W * 0.5))
				_ovr[tk] = {"to": at3 + back * 1.2, "spd": RUN, "t": 30.0}
			return true
		"endset":
			_set = {}
			if mode == "set":
				mode = "play"
			return true
		"mode":
			mode = String(a["m"])
			return true
		"whistle":
			whistle = 0.6
			return true
		"stop":
			owner = null
			_fl = {}
			return true
		"flag":
			ar_flag[int(a.get("i", 0))] = 1.8
			return true
		"down":
			var v: Ag = a.get("ag", null)
			if v != null:
				v.down = float(a.get("t", 1.4))
			return true
		"card":
			var c: Ag = a.get("ag", null)
			if c != null and c.on:
				show_card(c.side, c.idx, bool(a.get("red", false)))
			return true
		"run":
			var r: Ag = a.get("ag", null)
			if r != null and r.on:
				_ovr[r] = {"to": _clamp_field(a["to"]), "spd": float(a.get("spd", SPRINT)), "t": float(a.get("t", 2.0))}
			return true
		"poss":
			poss = int(a["side"])
			return true
		"net":
			net_hit = int(a["i"])
			net_t = 1.0
			return true
		"call":
			var cb: Callable = a["f"]
			cb.call()
			return true
	return false


func _action_done(a: Dictionary) -> bool:
	match String(a["k"]):
		"wait":
			return _act_t >= float(a["dur"])
		"carry":
			if owner == null:
				return true
			var to: Vector2 = _clamp_field(a["to"])
			return owner.pos.distance_to(to) < 0.9 or _act_t > float(a.get("max", 3.0))
		"pass", "shot", "fly", "steal":
			return _fl.is_empty()
		"set":
			return _act_t >= float(a.get("dur", 1.0)) and _fl.is_empty()
	return true


func _end_action(a: Dictionary) -> void:
	match String(a["k"]):
		"carry":
			if owner != null:
				_ovr.erase(owner)


func _fly(to: Vector2, loft: float, spd: float, kind: String, rc: Ag, curve: float = 0.0) -> void:
	var dist := ball.distance_to(to)
	var dur := clampf(dist / maxf(1.0, spd), 0.12, 3.0)
	if loft > 1.5:
		dur *= 1.15
	_fl = {"from": ball, "to": to, "dur": dur, "t": 0.0, "loft": loft, "kind": kind, "rc": rc, "curve": curve}
	ball_spin = (1.0 if rng.randf() < 0.5 else -1.0) * spd * 0.6


func _update_ball(dt: float) -> void:
	if not _fl.is_empty():
		_fl["t"] = float(_fl["t"]) + dt
		var k := clampf(float(_fl["t"]) / float(_fl["dur"]), 0.0, 1.0)
		var kind := String(_fl["kind"])
		var e := k
		if kind == "pass" or kind == "loose" or kind == "place":
			e = 1.0 - pow(1.0 - k, 1.5) # a bola perde velocidade na grama
		var from: Vector2 = _fl["from"]
		var to: Vector2 = _fl["to"]
		var p := from.lerp(to, e)
		var curve := float(_fl.get("curve", 0.0))
		if curve != 0.0:
			var n := (to - from).orthogonal().normalized()
			p += n * curve * sin(PI * e) * from.distance_to(to) * 0.12
		ball = p
		ball_h = float(_fl["loft"]) * 4.0 * e * (1.0 - e)
		if kind == "shot":
			trail.append([ball, ball_h, 0.0])
		if k >= 1.0:
			var rc: Ag = _fl.get("rc", null)
			_fl = {}
			ball_h = 0.0
			if rc != null and rc.on:
				owner = rc
				poss = rc.side
		ball_spin *= 0.98
		return
	ball_h = 0.0
	if owner != null and owner.on:
		if owner.down > 0.0:
			owner = null
			return
		var lead := owner.face * (0.75 + 0.25 * sin(_t * 9.0))
		ball = ball.lerp(owner.pos + lead, clampf(dt * 14.0, 0.0, 1.0))
		ball_spin = owner.vel.length()
	else:
		ball_spin *= 0.95


func _update_agents(dt: float) -> void:
	for s in 2:
		for a: Ag in agents[s]:
			if not a.on:
				continue
			a.card_t = maxf(0.0, a.card_t - dt)
			if a.card_t <= 0.0:
				a.card = 0
			a.hurt = maxf(0.0, a.hurt - dt)
			a.dive = maxf(0.0, a.dive - dt)
			a.arms = maxf(0.0, a.arms - dt)
			if a.down > 0.0:
				a.down -= dt
				a.vel = a.vel.move_toward(Vector2.ZERO, 30.0 * dt)
				a.pos += a.vel * dt
				continue
			var tgt: Vector2
			var spd := JOG
			if _ovr.has(a):
				var o: Dictionary = _ovr[a]
				o["t"] = float(o["t"]) - dt
				tgt = o["to"]
				spd = float(o["spd"])
				if float(o["t"]) <= 0.0:
					_ovr.erase(a)
			else:
				tgt = _target(a)
				var far := a.pos.distance_to(tgt)
				spd = JOG if far < 6.0 else (RUN if far < 14.0 else SPRINT)
				if mode == "goal":
					spd = 3.0
			_steer(a, tgt, spd, dt)
	# Ninguém atravessa ninguém: afastamento leve entre jogadores próximos.
	for s in 2:
		for a: Ag in agents[s]:
			if not a.on or a.down > 0.0:
				continue
			for s2 in 2:
				for b: Ag in agents[s2]:
					if b == a or not b.on:
						continue
					var d := a.pos - b.pos
					var dl := d.length()
					if dl < 1.3 and dl > 0.001:
						a.pos += d / dl * (1.3 - dl) * 0.25


func _steer(a: Ag, tgt: Vector2, spd: float, dt: float) -> void:
	var d := tgt - a.pos
	var dist := d.length()
	var want := Vector2.ZERO
	if dist > 0.08:
		want = d / dist * minf(spd, dist * 2.4)
	var acc := 16.0 if a.dive <= 0.0 else 40.0
	a.vel = a.vel.move_toward(want, acc * dt)
	a.pos += a.vel * dt
	var v := a.vel.length()
	if v > 0.5:
		a.face = a.face.lerp(a.vel / v, clampf(dt * 7.0, 0.0, 1.0)).normalized()
	elif owner != null and owner != a:
		a.face = a.face.lerp((ball - a.pos).normalized(), clampf(dt * 3.0, 0.0, 1.0)).normalized()
	a.run += v * dt * 1.7


func _update_officials(dt: float) -> void:
	# Árbitro: diagonal, a uns 15 m da bola, sem ficar na linha do passe.
	var side_y := W * 0.5 + (9.0 if ball.y < W * 0.5 else -9.0)
	var tgt := Vector2(ball.x - dir(poss) * 11.0, lerpf(ball.y, side_y, 0.7))
	if ref_card > 0 or ref_var > 0.0:
		tgt = ref_pos
	if mode == "set" and not _set.is_empty():
		var at: Vector2 = _set["at"]
		tgt = at + Vector2(-dir(int(_set["side"])) * 8.0, (6.0 if at.y < W * 0.5 else -6.0))
	tgt = Vector2(clampf(tgt.x, 4.0, L - 4.0), clampf(tgt.y, 3.0, W - 3.0))
	var d := tgt - ref_pos
	var dist := d.length()
	if dist > 0.3:
		var v := d / dist * minf(RUN if dist > 8.0 else JOG, dist * 2.0)
		ref_pos += v * dt
		ref_face = ref_face.lerp(v.normalized(), clampf(dt * 5.0, 0.0, 1.0)).normalized()
		ref_run += v.length() * dt * 1.7
	# Bandeirinhas: cada um no seu lado do campo, na linha do penúltimo defensor.
	for i in 2:
		var def_side := 1 if i == 0 else 0 # AR 0 cobre o gol em x=105 (defendido pelo visitante)
		var line_x := own(def_side, _line[def_side], 0.5).x
		var bx := ball.x
		var x := maxf(line_x, bx) if i == 0 else minf(line_x, bx)
		x = clampf(x, L * 0.5, L) if i == 0 else clampf(x, 0.0, L * 0.5)
		var p: Vector2 = ar_pos[i]
		p.x = move_toward(p.x, x, RUN * dt)
		ar_pos[i] = p


func _compute_lines() -> void:
	for s in 2:
		var ds: Array = []
		for a: Ag in agents[s]:
			if a.on:
				ds.append(depth(s, a.pos))
		ds.sort()
		_line[s] = float(ds[1]) if ds.size() > 1 else 0.2
		# Quem marca a bola: o mais perto pressiona, o segundo faz a cobertura.
		var best: Ag = null
		var best_d := 1e9
		var second: Ag = null
		var second_d := 1e9
		if poss != s:
			for a: Ag in agents[s]:
				if not a.on or a.gk or a.down > 0.0:
					continue
				var dd := a.pos.distance_squared_to(ball)
				if dd < best_d:
					second = best
					second_d = best_d
					best = a
					best_d = dd
				elif dd < second_d:
					second = a
					second_d = dd
		_press[s] = best
		_cover[s] = second


# ---------------------------------------------------------------------------
# Posicionamento sem bola
# ---------------------------------------------------------------------------

func _kick_shape(a: Ag) -> Vector2:
	if a.gk:
		return own(a.side, 0.02, 0.5)
	var d := minf(0.06 + a.fy * 0.64, 0.47)
	return own(a.side, d, a.fx)


func _target(a: Ag) -> Vector2:
	var s := a.side
	if mode == "kickoff":
		return _kick_shape(a)
	if mode == "goal" and not _celebr.is_empty():
		var cs := int(_celebr["side"])
		if s == cs and not a.gk:
			var sc: Ag = _celebr.get("sc", null)
			var hub: Vector2 = sc.pos if sc != null else _celebr["at"]
			var off := Vector2(cos(a.idx * 2.1), sin(a.idx * 2.1)) * (1.4 + (a.idx % 3) * 0.6)
			return hub + off
		if a.gk and s != cs:
			return own(s, 0.015, 0.5)
		return _kick_shape(a).lerp(a.pos, 0.6)
	if mode == "set" and not _set.is_empty():
		var sp := _set_target(a)
		if sp != Vector2.INF:
			return sp
	if a == owner:
		return a.pos + a.face * 0.5
	var bd := depth(s, ball)
	var bl := lat(s, ball)
	var has := poss == s
	if a.gk:
		var gd := clampf(0.012 + bd * 0.1, 0.012, 0.13)
		if not has and bd < 0.25:
			gd = 0.018
		var gl := 0.5 + (bl - 0.5) * (0.3 if bd < 0.3 else 0.12)
		return own(s, gd, gl)
	if not has:
		if a == _press[s]:
			return ball + (_goal_center(s) - ball).normalized() * 1.4
		if a == _cover[s]:
			return ball + (_goal_center(s) - ball).normalized() * 7.0
	var fy := clampf(a.fy, 0.08, 0.8)
	var fx := a.fx
	var d: float
	var l: float
	var wob := sin(_t * 0.55 + a.idx * 1.9 + s * 0.7) * 0.012
	if has:
		var back := clampf(bd - 0.4, 0.13, 0.55)
		var span := 0.48 + 0.1 * clampf(bd, 0.0, 1.0)
		d = back + (fy - 0.15) / 0.55 * span
		var width := 1.2 if bd > 0.35 else 1.05
		l = 0.5 + (fx - 0.5) * width + (bl - 0.5) * 0.16
		# Atacantes jogam na linha do penúltimo defensor (sem ficar impedidos) e pedem profundidade.
		var cap := maxf(1.0 - float(_line[1 - s]) - 0.008, bd)
		if a.role in ["ST", "W", "AM"] and bd > 0.5:
			var runner := sin(_t * 0.9 + a.idx * 3.1) > 0.55
			d = maxf(d, cap - (0.0 if runner else 0.05))
		d = minf(d, cap)
		# Aproximação: quem está perto da bola oferece linha de passe.
		if owner != null and owner.side == s and a.pos.distance_to(ball) < 16.0:
			var off := (a.pos - ball)
			if off.length() > 0.1:
				var want := ball + off.normalized() * 11.0
				d = lerpf(d, depth(s, want), 0.35)
				l = lerpf(l, lat(s, want), 0.35)
	else:
		var line := clampf(bd - 0.3, 0.06, 0.42)
		d = line + (fy - 0.15) / 0.55 * 0.36
		l = 0.5 + (fx - 0.5) * 0.76 + (bl - 0.5) * 0.36
		# Marcação no último terço: os zagueiros ficam entre o atacante e o gol.
		if bd < 0.3:
			d = minf(d, 0.2 + fy * 0.25)
	d += wob
	return own(s, clampf(d, 0.02, 0.97), clampf(l, 0.03, 0.97))


func _goal_center(side: int) -> Vector2:
	# Gol que `side` defende.
	return Vector2(0.0 if side == 0 else L, W * 0.5)


func _clamp_field(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.5, L - 0.5), clampf(p.y, 0.5, W - 0.5))


## Posição de cada um numa bola parada (INF = segue o posicionamento normal).
func _set_target(a: Ag) -> Vector2:
	var sk := String(_set.get("sk", ""))
	var att := int(_set["side"])
	var at: Vector2 = _set["at"]
	if a == _set.get("taker", null):
		return Vector2.INF if _ovr.has(a) else at
	var s := a.side
	var i := a.idx
	match sk:
		"corner", "fk_box":
			if s == att:
				if a.gk:
					return own(s, 0.1, 0.5)
				if a.fy >= 0.3 or a.role == "CB":
					var k := (i * 37) % 7
					return own(s, 0.86 + (k % 3) * 0.035, 0.36 + k * 0.047)
				return own(s, 0.62 + (i % 3) * 0.04, 0.3 + (i % 4) * 0.13)
			else:
				if a.gk:
					return own(s, 0.008, 0.5 + (0.03 if at.y > W * 0.5 else -0.03) * dir(s))
				var wall: Array = _set.get("wall", [])
				var wi := wall.find(a)
				if wi >= 0:
					var gc := _goal_center(s)
					var toward := (gc - at).normalized()
					var perp := toward.orthogonal()
					return at + toward * 9.15 + perp * (float(wi) - (wall.size() - 1) * 0.5) * 0.7
				if a.fy >= 0.55:
					return own(s, 0.3, 0.5 + (i % 3 - 1) * 0.15)
				var k2 := (i * 53) % 8
				return own(s, 0.02 + (k2 % 4) * 0.025, 0.36 + k2 * 0.04)
		"pen":
			if a.gk and s != att:
				return own(s, 0.0, 0.5)
			var edge := 0.78 if s == att else 0.2
			var d := edge if s == att else 1.0 - 0.22
			var lat2 := 0.25 + ((i * 29) % 11) * 0.05
			if s == att:
				return own(s, d - (i % 2) * 0.03, lat2)
			return own(att, d - (i % 2) * 0.03, lat2)
		"goalkick":
			if s == att:
				if a.gk:
					return Vector2.INF
				if a.role == "CB":
					return own(s, 0.06, 0.5 + (a.fx - 0.5) * 2.2)
				return own(s, 0.25 + a.fy * 0.45, a.fx)
			return own(s, 0.45 + a.fy * 0.25, a.fx)
		"throw":
			return Vector2.INF
		"fk":
			return Vector2.INF
	return Vector2.INF


# ---------------------------------------------------------------------------
# Escolhas de jogadores
# ---------------------------------------------------------------------------

func _on_list(side: int) -> Array:
	var out: Array = []
	for a: Ag in agents[side]:
		if a.on and a.down <= 0.0:
			out.append(a)
	return out


func _forward(side: int) -> Ag:
	var best: Ag = null
	for a: Ag in agents[side]:
		if a.on and not a.gk and (best == null or a.fy > best.fy):
			best = a
	return best


func _pick_mid(side: int, central: bool) -> Ag:
	var cands: Array = []
	for a: Ag in _on_list(side):
		if a.gk or a == owner:
			continue
		if a.fy > 0.28 and a.fy < 0.55 and (not central or absf(a.fx - 0.5) < 0.3):
			cands.append(a)
	if cands.is_empty():
		cands = _on_list(side).filter(func(x: Ag): return not x.gk and x != owner)
	return cands[rng.randi_range(0, cands.size() - 1)] if not cands.is_empty() else null


func _pick_wide(side: int, left: bool) -> Ag:
	var best: Ag = null
	var best_v := -1e9
	for a: Ag in _on_list(side):
		if a.gk:
			continue
		var wide := (1.0 - a.fx) if left else a.fx
		var v := wide * 2.0 + a.fy
		if v > best_v:
			best_v = v
			best = a
	return best


func _nearest(side: int, p: Vector2, skip_gk: bool = true, exclude: Ag = null) -> Ag:
	var best: Ag = null
	var bd := 1e9
	for a: Ag in _on_list(side):
		if (skip_gk and a.gk) or a == exclude:
			continue
		var d := a.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = a
	return best


## Bola muda de dono sem lance marcante: desarme, interceptação ou passe errado.
func _turnover(side: int) -> void:
	var g := _nearest(side, ball)
	if g == null:
		poss = side
		return
	var k := rng.randf()
	if k < 0.45 or owner == null:
		_q({"k": "steal", "ag": g, "est": 0.4})
	else:
		# Passe interceptado: a bola sai do dono e cai no pé do adversário.
		_q({"k": "pass", "to": g, "loft": 0.0, "spd": 16.0, "est": 0.6})
	_q({"k": "wait", "dur": 0.25, "est": 0.25})


## Com a bola rolando e nada roteirizado: passes, conduções e viradas de jogo em direção à zona.
func _ambient_action() -> void:
	_amb_t = rng.randf_range(0.35, 1.1)
	if owner == null:
		if _fl.is_empty():
			var g := _nearest(poss, ball, false)
			if g != null:
				_q({"k": "run", "ag": g, "to": ball, "spd": RUN, "t": 1.0, "est": 0.0})
				if g.pos.distance_to(ball) < 1.6:
					owner = g
		return
	var s := owner.side
	var bd := depth(s, ball)
	var push := zone - bd
	var r := rng.randf()
	# Conduzir para o espaço.
	if r < 0.28 and owner.role != "GK":
		var fwd := clampf(push * 30.0, -4.0, 12.0) + rng.randf_range(2.0, 7.0)
		var side_step := rng.randf_range(-6.0, 6.0)
		var to := owner.pos + Vector2(dir(s) * fwd, side_step * (1.0 if s == 0 else -1.0))
		_q({"k": "carry", "to": to, "spd": RUN, "max": 1.6, "est": 1.0})
		return
	# Passe: pesa quem avança em direção à zona, quem está livre e a distância.
	var best: Ag = null
	var best_v := -1e9
	for a: Ag in _on_list(s):
		if a == owner:
			continue
		var dist := a.pos.distance_to(owner.pos)
		if dist < 5.0 or dist > 48.0:
			continue
		var gain := depth(s, a.pos) - bd
		var v := -absf(depth(s, a.pos) - zone) * 3.0 + gain * (2.0 if push > 0.05 else 0.6)
		var opp := _nearest(1 - s, a.pos, false)
		if opp != null:
			v += clampf(opp.pos.distance_to(a.pos) / 8.0, 0.0, 1.2)
		v -= dist / 60.0
		if a.gk:
			v -= 1.8 if bd > 0.2 else 0.4
		v += rng.randf_range(0.0, 1.1)
		if v > best_v:
			best_v = v
			best = a
	if best == null:
		return
	var d2 := best.pos.distance_to(owner.pos)
	var loft := 0.0
	var spd := 15.0 + d2 * 0.18
	var curve := 0.0
	if d2 > 30.0:
		loft = rng.randf_range(4.0, 9.0) # virada de jogo / lançamento
		spd = 22.0
		curve = rng.randf_range(-0.5, 0.5)
	var lead := best.vel * 0.5 + Vector2(dir(s) * (1.5 if push > 0 else 0.0), 0)
	_q({"k": "pass", "to": best, "at": best.pos + lead, "loft": loft, "spd": spd, "curve": curve, "est": 0.8})


# ---------------------------------------------------------------------------
# Roteiros
# ---------------------------------------------------------------------------

func _ensure_ball(side: int, g: Ag) -> void:
	if g == null:
		g = _pick_mid(side, false)
	if g == null:
		return
	if owner == g:
		return
	if owner != null and owner.side == side:
		_q({"k": "pass", "to": g, "loft": 0.0 if owner.pos.distance_to(g.pos) < 28.0 else 5.0, "spd": 19.0, "est": 0.7})
	else:
		_q({"k": "steal", "ag": g, "est": 0.4})
	_q({"k": "poss", "side": side, "est": 0.0})


func _script_chance(info: Dictionary) -> void:
	var side := int(info.get("side", 0))
	var dfn := 1 - side
	var ct := int(info.get("ct", 0))
	var res := String(info.get("res", "miss"))
	var sh := ag(side, int(info.get("sh", -1)))
	if sh == null:
		sh = _forward(side)
	var asg := ag(side, int(info.get("as", -1)))
	if asg == sh:
		asg = null
	var gk := keeper(dfn)
	var own_goal := bool(info.get("own", false))
	if own_goal:
		# Gol contra: o cruzamento desvia no defensor e entra.
		var og := ag(dfn, int(info.get("sh", -1)))
		sh = _forward(side)
		_ensure_ball(side, asg if asg != null else _pick_wide(side, rng.randf() < 0.5))
		var left := rng.randf() < 0.5
		_q({"k": "carry", "to": own(side, 0.86, 0.06 if left else 0.94), "spd": RUN, "max": 1.4, "est": 1.0})
		var spot := own(side, 0.955, 0.5 + rng.randf_range(-0.08, 0.08))
		if og != null:
			_q({"k": "run", "ag": og, "to": spot, "t": 1.4, "est": 0.0})
		_q({"k": "pass", "to": null, "at": spot, "loft": 3.0, "spd": 22.0, "est": 0.7})
		_q({"k": "fly", "at": Vector2(goal_x(side) + dir(side) * 1.2, W * 0.5 + rng.randf_range(-2.5, 2.5)), "loft": 0.6, "spd": 18.0, "est": 0.4})
		_q({"k": "net", "i": 1 if side == 0 else 0, "est": 0.0})
		return
	var lat0 := rng.randf_range(0.3, 0.7)
	match ct:
		MatchSimulation.CH_THROUGH:
			var giver := asg if asg != null else _pick_mid(side, true)
			_ensure_ball(side, giver)
			_q({"k": "carry", "to": own(side, 0.6, lat0), "spd": RUN, "max": 1.5, "est": 0.9})
			var land := own(side, 0.84, clampf(lat0 + rng.randf_range(-0.12, 0.12), 0.3, 0.7))
			_q({"k": "run", "ag": sh, "to": land, "t": 2.0, "est": 0.0})
			_q({"k": "pass", "to": sh, "at": land, "loft": 0.0, "spd": 21.0, "est": 0.8, "kind": "pass"})
			_q({"k": "carry", "to": own(side, 0.88, 0.5 + (lat(side, land) - 0.5) * 0.6), "spd": SPRINT, "max": 0.9, "est": 0.5})
		MatchSimulation.CH_CROSS, MatchSimulation.CH_CORNER:
			if ct == MatchSimulation.CH_CORNER:
				_script_corner(side, asg, sh)
				_queue_shot(side, sh, gk, res, ct, info)
				return
			var left := rng.randf() < 0.5
			var crosser := asg if asg != null else _pick_wide(side, left)
			if crosser != null:
				left = crosser.fx < 0.5
			_ensure_ball(side, crosser)
			var wing := 0.06 if left else 0.94
			_q({"k": "carry", "to": own(side, 0.84, wing), "spd": SPRINT, "max": 1.8, "est": 1.2})
			var head := own(side, 0.905, 0.5 + rng.randf_range(-0.1, 0.1))
			_q({"k": "run", "ag": sh, "to": head, "t": 2.0, "est": 0.0})
			_q({"k": "pass", "to": sh, "at": head, "loft": rng.randf_range(3.5, 5.5), "spd": 22.0, "curve": 0.35 if left else -0.35, "est": 0.9})
		MatchSimulation.CH_LONG:
			_ensure_ball(side, asg if asg != null else _pick_mid(side, true))
			var spot := own(side, rng.randf_range(0.7, 0.76), lat0)
			_q({"k": "run", "ag": sh, "to": spot, "t": 1.6, "est": 0.0})
			_q({"k": "pass", "to": sh, "at": spot, "loft": 0.0, "spd": 18.0, "est": 0.7})
			_q({"k": "carry", "to": spot + Vector2(dir(side) * 2.5, 0), "spd": RUN, "max": 0.6, "est": 0.4})
		MatchSimulation.CH_DRIBBLE:
			var start := own(side, 0.68, 0.2 if rng.randf() < 0.5 else 0.8)
			_q({"k": "run", "ag": sh, "to": start, "t": 1.4, "est": 0.0})
			_ensure_ball(side, asg if asg != null else _pick_mid(side, false))
			_q({"k": "pass", "to": sh, "at": start, "loft": 0.0, "spd": 18.0, "est": 0.7})
			var mk := _nearest(dfn, start)
			if mk != null:
				_q({"k": "run", "ag": mk, "to": own(side, 0.76, lat(side, start) * 0.7 + 0.15), "t": 1.2, "est": 0.0})
			_q({"k": "carry", "to": own(side, 0.76, lat(side, start) * 0.7 + 0.15), "spd": RUN, "max": 0.8, "est": 0.6})
			# O drible: corte para dentro e o marcador fica para trás.
			if mk != null:
				_q({"k": "down", "ag": mk, "t": 0.6, "est": 0.0})
				_q({"k": "run", "ag": mk, "to": own(side, 0.74, lat(side, start)), "spd": 3.0, "t": 1.0, "est": 0.0})
			_q({"k": "carry", "to": own(side, 0.85, 0.42 + rng.randf_range(0.0, 0.16)), "spd": SPRINT, "max": 0.9, "est": 0.6})
		MatchSimulation.CH_COUNTER:
			var thief := _nearest(side, ball)
			if thief != null and owner != thief:
				_q({"k": "steal", "ag": thief, "est": 0.4})
				_q({"k": "poss", "side": side, "est": 0.0})
			var launch := own(side, 0.66, lat0)
			_q({"k": "run", "ag": sh, "to": launch, "t": 2.0, "est": 0.0})
			_q({"k": "pass", "to": sh, "at": launch, "loft": 2.5, "spd": 25.0, "est": 1.0})
			_q({"k": "carry", "to": own(side, 0.86, 0.5 + (lat0 - 0.5) * 0.4), "spd": SPRINT, "max": 1.6, "est": 1.2})
		MatchSimulation.CH_SCRAMBLE:
			_ensure_ball(side, asg if asg != null else _pick_wide(side, rng.randf() < 0.5))
			var box := own(side, 0.9, 0.5 + rng.randf_range(-0.12, 0.12))
			var clr := _nearest(dfn, box)
			_q({"k": "pass", "to": clr, "at": box, "loft": 4.0, "spd": 20.0, "est": 0.8})
			var loose := own(side, 0.87, 0.5 + rng.randf_range(-0.15, 0.15))
			_q({"k": "run", "ag": sh, "to": loose, "t": 1.4, "est": 0.0})
			_q({"k": "fly", "at": loose, "loft": 1.2, "spd": 10.0, "to": sh, "est": 0.5})
		MatchSimulation.CH_FREEKICK:
			var at := own(side, rng.randf_range(0.73, 0.79), rng.randf_range(0.3, 0.7))
			var wall := _wall_for(dfn, at, 4 if depth(side, at) > 0.75 else 3)
			_q({"k": "set", "sk": "fk_box", "side": side, "at": at, "taker": sh, "wall": wall, "dur": 1.6, "est": 1.6})
			_q({"k": "give", "ag": sh, "est": 0.0})
			_q({"k": "wait", "dur": 0.5, "est": 0.5})
		MatchSimulation.CH_PENALTY:
			var pa: Dictionary = info.get("pen", {})
			var victim := ag(side, int(pa.get("victim", -1)))
			var fouler := ag(dfn, int(pa.get("fouler", -1)))
			if victim != null:
				_ensure_ball(side, victim)
				_q({"k": "carry", "to": own(side, 0.88, 0.42 + rng.randf_range(0.0, 0.16)), "spd": SPRINT, "max": 1.2, "est": 0.9})
				if fouler != null:
					_q({"k": "run", "ag": fouler, "to": own(side, 0.9, 0.5), "t": 0.6, "est": 0.0})
				_q({"k": "down", "ag": victim, "t": 1.8, "est": 0.0})
				_q({"k": "whistle", "est": 0.0})
				_q({"k": "stop", "est": 0.0})
				_q({"k": "wait", "dur": 0.9, "est": 0.9})
			var spot2 := own(side, 1.0 - 11.0 / L, 0.5)
			_q({"k": "set", "sk": "pen", "side": side, "at": spot2, "taker": sh, "dur": 2.0, "est": 2.0})
			_q({"k": "give", "ag": sh, "est": 0.0})
			_q({"k": "whistle", "est": 0.0})
			_q({"k": "wait", "dur": 0.5, "est": 0.5})
		MatchSimulation.CH_ERROR:
			var culprit := ag(dfn, int(info.get("culprit", -1)))
			if culprit == null:
				culprit = _nearest(dfn, own(dfn, 0.15, 0.5))
			if culprit != null:
				_q({"k": "steal", "ag": culprit, "est": 0.4})
				_q({"k": "poss", "side": dfn, "est": 0.0})
			var gift := own(side, 0.8, lat0)
			_q({"k": "run", "ag": sh, "to": gift, "t": 1.5, "est": 0.0})
			_q({"k": "pass", "to": sh, "at": gift, "loft": 0.0, "spd": 14.0, "est": 0.8})
			_q({"k": "carry", "to": own(side, 0.87, 0.5 + (lat0 - 0.5) * 0.4), "spd": SPRINT, "max": 0.8, "est": 0.5})
		_:
			_ensure_ball(side, sh)
			_q({"k": "carry", "to": own(side, 0.84, lat0), "spd": RUN, "max": 1.2, "est": 0.8})
	_queue_shot(side, sh, gk, res, ct, info)


func _wall_for(dfn: int, at: Vector2, n: int) -> Array:
	var cands: Array = []
	for a: Ag in _on_list(dfn):
		if not a.gk:
			cands.append(a)
	cands.sort_custom(func(x: Ag, y: Ag): return x.pos.distance_squared_to(at) < y.pos.distance_squared_to(at))
	return cands.slice(0, mini(n, cands.size()))


func _queue_shot(side: int, sh: Ag, gk: Ag, res: String, ct: int, info: Dictionary) -> void:
	var gx := goal_x(side)
	var dr := dir(side)
	var cy := W * 0.5
	var header := ct == MatchSimulation.CH_CROSS or ct == MatchSimulation.CH_CORNER
	var loft := 0.9 if header else 0.6
	var spd := 17.0 if header else 27.0
	var curve := 0.0
	if ct == MatchSimulation.CH_LONG:
		loft = 1.8
		spd = 30.0
		curve = rng.randf_range(-0.25, 0.25)
	elif ct == MatchSimulation.CH_FREEKICK:
		loft = 3.2
		spd = 25.0
		curve = rng.randf_range(0.35, 0.6) * (1.0 if rng.randf() < 0.5 else -1.0)
	elif ct == MatchSimulation.CH_PENALTY:
		loft = 0.5
		spd = 26.0
	var y := cy + rng.randf_range(-3.0, 3.0)
	var shot := {"k": "shot", "loft": loft, "spd": spd, "curve": curve, "gk": gk, "est": 0.6}
	var gk_line := Vector2(gx - dr * 0.9, cy)
	var after: Array = []
	match res:
		"goal":
			shot["at"] = Vector2(gx + dr * 1.3, y)
			# Goleiro chega atrasado (ou pula para o outro lado no pênalti).
			var wrong := ct == MatchSimulation.CH_PENALTY and rng.randf() < 0.6
			var gy := cy - (y - cy) * 0.6 if wrong else cy + (y - cy) * 0.45
			shot["gk_to"] = Vector2(gx - dr * 0.8, gy)
			shot["dive"] = absf(gy - cy) > 1.2
			after.append({"k": "net", "i": 1 if side == 0 else 0, "est": 0.0})
		"save", "pen_save":
			var hold := rng.randf() < 0.5 and res != "pen_save"
			var at := Vector2(gx - dr * 1.0, y)
			shot["at"] = at
			shot["gk_to"] = at
			shot["gk_spd"] = 11.0
			shot["dive"] = absf(y - cy) > 1.2
			if hold:
				after.append({"k": "give", "ag": gk, "est": 0.0})
				after.append({"k": "poss", "side": 1 - side, "est": 0.0})
				after.append({"k": "wait", "dur": 0.8, "est": 0.8})
				if gk != null:
					var fb := _pick_wide(1 - side, rng.randf() < 0.5)
					after.append({"k": "pass", "to": fb, "loft": 1.0, "spd": 16.0, "est": 0.8})
			else:
				# Espalma para escanteio ou para a área.
				var out := Vector2(gx + dr * 1.5, cy + signf(y - cy + 0.01) * rng.randf_range(6.0, 12.0))
				after.append({"k": "fly", "at": out, "loft": 2.0, "spd": 14.0, "free": true, "est": 0.5})
		"post":
			var py := cy + (GOAL_HW if y > cy else -GOAL_HW)
			shot["at"] = Vector2(gx, py)
			shot["gk_to"] = Vector2(gx - dr * 0.8, cy + (py - cy) * 0.6)
			shot["dive"] = true
			var reb := Vector2(gx - dr * rng.randf_range(9.0, 16.0), cy + rng.randf_range(-10.0, 10.0))
			var clr := _nearest(1 - side, reb)
			after.append({"k": "fly", "at": reb, "loft": 1.5, "spd": 16.0, "to": clr, "est": 0.6})
		"block":
			var dl := int(info.get("line", -1))
			var blk: Ag = ag(1 - side, dl) if dl >= 0 else null
			if blk != null:
				# Salvou em cima da linha.
				var at2 := Vector2(gx - dr * 0.4, y)
				shot["at"] = at2
				shot["blocker"] = blk
				shot["gk_to"] = Vector2(gx - dr * 1.2, cy + (y - cy) * 0.3)
				shot["dive"] = true
			else:
				var from := sh.pos if sh != null else own(side, 0.85, 0.5)
				blk = _nearest(1 - side, from.lerp(Vector2(gx, cy), 0.25))
				var at3 := from.lerp(Vector2(gx, y), 0.18)
				shot["at"] = at3
				shot["blocker"] = blk
			var away := Vector2(gx - dr * rng.randf_range(12.0, 22.0), cy + rng.randf_range(-18.0, 18.0))
			after.append({"k": "fly", "at": away, "loft": 3.0, "spd": 18.0, "to": _nearest(1 - side, away), "est": 0.6})
		_:
			# Para fora (ou por cima) → tiro de meta.
			var over := rng.randf() < 0.35 and not header
			var my := y if over else cy + (1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(4.6, 11.0)
			shot["at"] = Vector2(gx + dr * 3.0, my)
			shot["free"] = true
			if over:
				shot["loft"] = 5.5
			shot["gk_to"] = Vector2(gx - dr * 0.8, cy + clampf(my - cy, -2.5, 2.5))
			after.append({"k": "wait", "dur": 0.7, "est": 0.7})
			_goal_kick(1 - side, after)
	if ct == MatchSimulation.CH_PENALTY:
		shot["est"] = 0.8
	_q(shot)
	_q({"k": "endset", "est": 0.0})
	for a in after:
		_q(a)


func _goal_kick(side: int, out: Array) -> void:
	var gk := keeper(side)
	var at := own(side, 5.5 / L, 0.5 + rng.randf_range(-0.12, 0.12))
	out.append({"k": "set", "sk": "goalkick", "side": side, "at": at, "taker": gk, "dur": 1.2, "est": 1.2})
	out.append({"k": "give", "ag": gk, "est": 0.0})
	out.append({"k": "endset", "est": 0.0})
	var tgt := _pick_mid(side, false)
	var short := rng.randf() < 0.4
	if short:
		var cb := _nearest(side, own(side, 0.08, 0.2 if rng.randf() < 0.5 else 0.8))
		if cb != null:
			tgt = cb
	if tgt != null:
		out.append({"k": "pass", "to": tgt, "loft": 0.0 if short else rng.randf_range(10.0, 16.0), "spd": 14.0 if short else 27.0, "est": 1.2})


func _script_corner(side: int, taker: Ag, target: Ag) -> void:
	var dfn := 1 - side
	var near_left := rng.randf() < 0.5
	var at := own(side, 1.0, 0.0 if near_left else 1.0)
	at = Vector2(clampf(at.x, 0.3, L - 0.3), clampf(at.y, 0.3, W - 0.3))
	if taker == null:
		taker = _pick_wide(side, near_left)
	_q({"k": "set", "sk": "corner", "side": side, "at": at, "taker": taker, "dur": 1.6, "est": 1.6})
	_q({"k": "give", "ag": taker, "est": 0.0})
	_q({"k": "wait", "dur": 0.3, "est": 0.3})
	var aim := own(side, 0.91 + rng.randf_range(-0.02, 0.03), 0.5 + rng.randf_range(-0.1, 0.1))
	if target != null:
		_q({"k": "run", "ag": target, "to": aim, "t": 1.5, "est": 0.0})
		_q({"k": "pass", "to": target, "at": aim, "loft": 5.0, "spd": 21.0, "curve": 0.4 if near_left else -0.4, "est": 0.9})
		_q({"k": "endset", "est": 0.0})
	else:
		# Sem finalização: a zaga afasta.
		var hd := _nearest(dfn, aim)
		_q({"k": "pass", "to": hd, "at": aim, "loft": 5.0, "spd": 21.0, "curve": 0.4 if near_left else -0.4, "est": 0.9})
		_q({"k": "endset", "est": 0.0})
		var away := own(side, rng.randf_range(0.55, 0.68), rng.randf_range(0.2, 0.8))
		_q({"k": "fly", "at": away, "loft": 6.0, "spd": 20.0, "to": _nearest(side, away), "est": 0.8})


func _script_foul(info: Dictionary) -> void:
	var side := int(info.get("side", 0)) # quem sofre (ataca)
	var dfn := 1 - side
	var victim := ag(side, int(info.get("p2", -1)))
	var fouler := ag(dfn, int(info.get("p", -1)))
	if victim == null:
		victim = _pick_mid(side, false)
	if victim == null:
		return
	_ensure_ball(side, victim)
	var d0 := clampf(zone, 0.2, 0.88)
	var spot := own(side, d0, clampf(lat(side, victim.pos), 0.1, 0.9))
	_q({"k": "carry", "to": spot, "spd": RUN, "max": 1.2, "est": 0.8})
	if fouler != null:
		_q({"k": "run", "ag": fouler, "to": spot, "spd": SPRINT, "t": 0.8, "est": 0.0})
	_q({"k": "wait", "dur": 0.25, "est": 0.25})
	_q({"k": "down", "ag": victim, "t": 1.3, "est": 0.0})
	_q({"k": "whistle", "est": 0.0})
	_q({"k": "stop", "est": 0.0})
	_q({"k": "wait", "dur": 0.8, "est": 0.8})
	var card := int(info.get("card", 0))
	if card > 0 and fouler != null:
		_q({"k": "card", "ag": fouler, "red": card == 2, "est": 0.0})
		_q({"k": "wait", "dur": 1.2, "est": 1.2})
	if bool(info.get("danger", false)) and d0 > 0.62:
		var wall := _wall_for(dfn, spot, 3 if depth(side, spot) > 0.72 else 2)
		_q({"k": "set", "sk": "fk_box", "side": side, "at": spot, "taker": _pick_mid(side, true), "wall": wall, "dur": 1.4, "est": 1.4})
	else:
		var tk := _nearest(side, spot, true, victim)
		_q({"k": "set", "sk": "fk", "side": side, "at": spot, "taker": tk, "dur": 0.9, "est": 0.9})
		_q({"k": "give", "ag": tk, "est": 0.0})
		_q({"k": "endset", "est": 0.0})
		_q({"k": "pass", "to": _pick_mid(side, false), "loft": 0.0, "spd": 15.0, "est": 0.7})


func _script_offside(info: Dictionary) -> void:
	var side := int(info.get("side", 0))
	var dfn := 1 - side
	var runner := ag(side, int(info.get("p", -1)))
	if runner == null:
		runner = _forward(side)
	_ensure_ball(side, _pick_mid(side, true))
	var beyond := own(side, clampf(1.0 - float(_line[dfn]) + 0.06, 0.6, 0.9), rng.randf_range(0.3, 0.7))
	_q({"k": "run", "ag": runner, "to": beyond, "t": 1.6, "est": 0.0})
	_q({"k": "pass", "to": runner, "at": beyond, "loft": 1.5, "spd": 22.0, "est": 0.8})
	_q({"k": "flag", "i": 0 if side == 0 else 1, "est": 0.0})
	_q({"k": "whistle", "est": 0.0})
	_q({"k": "stop", "est": 0.0})
	_q({"k": "wait", "dur": 0.7, "est": 0.7})
	var tk := _nearest(dfn, beyond)
	_q({"k": "set", "sk": "fk", "side": dfn, "at": beyond, "taker": tk, "dur": 1.0, "est": 1.0})
	_q({"k": "give", "ag": tk, "est": 0.0})
	_q({"k": "endset", "est": 0.0})
	_q({"k": "pass", "to": _pick_mid(dfn, false), "loft": 6.0, "spd": 22.0, "est": 1.0})


func _script_skill(side: int, dr: Ag, mk: Ag) -> void:
	if dr == null:
		return
	_ensure_ball(side, dr)
	var p0 := own(side, clampf(zone, 0.35, 0.8), clampf(lat(side, dr.pos), 0.15, 0.85))
	_q({"k": "carry", "to": p0, "spd": RUN, "max": 1.0, "est": 0.7})
	if mk != null:
		_q({"k": "run", "ag": mk, "to": p0 + Vector2(dir(side) * 2.0, 0), "spd": SPRINT, "t": 0.7, "est": 0.0})
	_q({"k": "wait", "dur": 0.2, "est": 0.2})
	var jink := 5.0 * (1.0 if rng.randf() < 0.5 else -1.0)
	_q({"k": "carry", "to": p0 + Vector2(dir(side) * 1.5, jink), "spd": SPRINT, "max": 0.4, "est": 0.3})
	_q({"k": "carry", "to": p0 + Vector2(dir(side) * 9.0, jink * 0.6), "spd": SPRINT, "max": 0.9, "est": 0.6})


func _script_tackle(side: int, df: Ag, vic: Ag) -> void:
	# side = quem desarma.
	if vic == null or df == null:
		return
	_ensure_ball(1 - side, vic)
	var p0 := vic.pos + Vector2(dir(1 - side) * 5.0, 0)
	_q({"k": "carry", "to": p0, "spd": RUN, "max": 0.8, "est": 0.6})
	_q({"k": "run", "ag": df, "to": p0, "spd": SPRINT, "t": 0.7, "est": 0.0})
	_q({"k": "wait", "dur": 0.35, "est": 0.35})
	_q({"k": "steal", "ag": df, "est": 0.3})
	_q({"k": "poss", "side": side, "est": 0.0})


func _script_keeper(side: int) -> void:
	var gk := keeper(side)
	if gk == null:
		return
	var att := 1 - side
	_ensure_ball(att, _pick_wide(att, rng.randf() < 0.5))
	var box := own(att, 0.95, 0.5 + rng.randf_range(-0.12, 0.12))
	_q({"k": "run", "ag": gk, "to": box, "spd": RUN, "t": 1.5, "est": 0.0})
	_q({"k": "pass", "to": gk, "at": box, "loft": 4.5, "spd": 20.0, "est": 0.9})
	_q({"k": "poss", "side": side, "est": 0.0})
	_q({"k": "wait", "dur": 0.9, "est": 0.9})
	var out := _pick_wide(side, rng.randf() < 0.5)
	_q({"k": "pass", "to": out, "loft": 1.2, "spd": 18.0, "est": 0.8})
