class_name LiveEngine
extends RefCounted
## Motor posicional da partida assistida, inspirado no 2D do Football Manager 2008: os 22 jogadores
## e a bola existem de verdade no campo (metros), a cada 0,25 s cada um decide para onde ir e quem
## tem a bola decide o que fazer — passe curto, enfiada, virada, lançamento, cruzamento, condução,
## drible, chute, proteção ou chutão — pelos atributos, pela pressão em volta e pela tática.
## Nada é roteirizado: o passe pode ser interceptado, o atacante pode estar impedido no momento do
## passe, o chute pode ser bloqueado por quem está na linha, o goleiro pode soltar o rebote.
##
## O que a tática muda no campo: altura da linha e do bloco (linha), largura, pressão (quem sai
## no portador e a partir de que altura), mentalidade (risco, quanto o time sobe, vontade de
## finalizar), estilo (paciência e passe curto, verticalidade, contra-ataque, lados e cruzamentos,
## bola longa) e instruções individuais (quem apoia o ataque). Moral, forma, cansaço, entrosamento,
## mando e as palestras entram pelo fator individual de cada jogador (MatchPlayer.f).
##
## Integra com a MatchSimulation: ela continua cuidando do relógio, cartões, trocas, IA do banco,
## notas e estatísticas; este motor substitui só o sorteio de lances do minuto (run_minute) e
## grava os quadros do minuto para a tela encenar exatamente o que aconteceu.
##
## Coordenadas: x = comprimento (0 = gol do mandante, 105 = gol do visitante; o mandante ataca para
## x = 105), y = largura (0..68), como na PitchView.

const L := 105.0
const W := 68.0
const DT := 0.25
const GOAL_HW := 3.66
const BOX_D := 16.5
const BOX_HW := 20.16
const TICKS := 240 # 60 s / DT
## Valor de manter a posse (na mesma escala da ameaça ≈ gols esperados da sequência).
const KEEP := 0.03
## Vontade geral de finalizar (calibra o volume de chutes).
const SHOT_BIAS := 0.62

class A:
	var side := 0
	var slot := 0
	var mp: MatchPlayer = null
	var on := true
	var gk := false
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var face := Vector2.RIGHT
	var ax := 0.5 # âncora lateral (0 esquerda … 1 direita, vista de quem ataca)
	var ay := 0.3 # âncora de profundidade (0 próprio gol … 1 gol adversário)
	var role := "CM"
	var spd := 7.5
	var acc := 5.0
	var pas := 0.5
	var vis := 0.5
	var tec := 0.5
	var dri := 0.5
	var fin := 0.5
	var lng := 0.5
	var hed := 0.5
	var tck := 0.5
	var mar := 0.5
	var psn := 0.5
	var dec := 0.5
	var strn := 0.5
	var cro := 0.5
	var gkv := 0.5
	var agg := 0.5
	var wa := 0.2
	var stun := 0.0
	var run_t := 0.0
	var run_to := Vector2.ZERO
	var tgt := Vector2.ZERO

var sim: MatchSimulation
var rng := RandomNumberGenerator.new()
var ag: Array = [[], []]
var ball := Vector2(L * 0.5, W * 0.5)
var bvel := Vector2.ZERO
var bh := 0.0
var bvh := 0.0
var owner: A = null
var last_touch: A = null
var last_side := 0
## Passe em andamento: {from, to (A), kind, t, off (impedido), at}
var pz: Dictionary = {}
## Chute em andamento (só visual): {res, t}
var shot_fx: Dictionary = {}
var t := 0.0 # segundo dentro do minuto
var clock := 0.0 # segundos de jogo corridos
var dead := 0.0 # bola parada: tempo que falta para a reposição
var restart: Dictionary = {} # {kind, side, at, taker}
var decide_t := 0.0
var turnover_t := -99.0
var turnover_d := 0.5 # profundidade (de quem roubou) onde a bola trocou de dono
var poss_t: Array[float] = [0.0, 0.0]
var carry_t := 0.0 # tempo com a bola no pé (quem conduz muito é desarmado)
var assist_by: A = null
var assist_t := -99.0
var assist_kind := ""
var in_poss: Array[bool] = [true, false]
var ball_d: Array[float] = [0.5, 0.5]
var off_line: Array[float] = [0.5, 0.5]
var presser: Array = [[], []]
var frames: Array = [] # [t, PackedFloat32Array(22 × (x, y) + bola x, y, h + dono)]
var keys: Array = [] # [t, peso] lances que merecem replay
## Contadores (para calibração e para a tela)
var passes: Array[int] = [0, 0]
var passes_ok: Array[int] = [0, 0]
var tackles: Array[int] = [0, 0]
var fail_int: Array[int] = [0, 0]
var fail_out: Array[int] = [0, 0]
var shot_log: Array = [] # [lado, distância, xG, marcadores a menos de 3 m, tempo de condução, cabeça]


func _init(s: MatchSimulation, seed_value: int) -> void:
	sim = s
	rng.seed = seed_value
	sync_teams(true)
	kickoff(0)


# ---------------------------------------------------------------------------
# Geometria
# ---------------------------------------------------------------------------

static func dirx(side: int) -> float:
	return 1.0 if side == 0 else -1.0


## Profundidade de um ponto na visão de `side` (0 = próprio gol, 1 = gol adversário).
static func depth(side: int, p: Vector2) -> float:
	return p.x / L if side == 0 else 1.0 - p.x / L


## Lateral na visão de `side` (0 = esquerda de quem ataca, 1 = direita).
static func lat(side: int, p: Vector2) -> float:
	return p.y / W if side == 0 else 1.0 - p.y / W


static func pt(side: int, l: float, d: float) -> Vector2:
	if side == 0:
		return Vector2(d * L, l * W)
	return Vector2((1.0 - d) * L, (1.0 - l) * W)


static func goal_of(side: int) -> Vector2:
	## Gol que `side` ataca.
	return Vector2(L if side == 0 else 0.0, W * 0.5)


static func own_goal(side: int) -> Vector2:
	return Vector2(0.0 if side == 0 else L, W * 0.5)


static func _clampf_field(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.5, L - 0.5), clampf(p.y, 0.5, W - 0.5))


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * tt)


## "Ameaça" de ter a bola num ponto (≈ chance de virar gol na sequência): quase nada no próprio
## campo, cresce muito no último terço e dentro da área, mais pelo meio.
static func threat(side: int, p: Vector2) -> float:
	var d := depth(side, p)
	var c := absf(lat(side, p) - 0.5) * 2.0
	var v := 0.004 + 0.13 * pow(d, 5.0) * (1.0 - 0.75 * c * c)
	if d > 0.84 and c < 0.6:
		v += 0.035 * (1.0 - c / 0.6) * smoothstep(0.84, 0.97, d)
	return v


# ---------------------------------------------------------------------------
# Elencos
# ---------------------------------------------------------------------------

## Monta (ou atualiza depois de trocas, expulsões e mudança de formação) os jogadores em campo.
func sync_teams(fresh: bool = false) -> void:
	for side in 2:
		var tm: MatchTeam = sim.teams[side]
		var fslots: Array = tm.formation["slots"]
		var arr: Array = ag[side]
		while arr.size() < fslots.size():
			var a := A.new()
			a.side = side
			a.slot = arr.size()
			a.on = false
			arr.append(a)
		for i in arr.size():
			var a: A = arr[i]
			var mp: MatchPlayer = tm.slots[i] if i < tm.slots.size() else null
			if mp == null or i >= fslots.size():
				if a.on and owner == a:
					owner = null
				a.on = false
				a.mp = null
				continue
			var sd: Dictionary = fslots[i]
			a.ax = float(sd.get("x", 0.5))
			a.ay = float(sd.get("y", 0.3))
			a.role = String(sd.get("role", "CM"))
			a.gk = i == 0
			if a.mp != mp:
				var entering := not fresh and a.mp != null
				a.mp = mp
				if fresh or not a.on:
					a.pos = _shape_pos(a, side == 0)
				elif entering:
					# Quem entra vem da linha lateral, no meio-campo
					a.pos = Vector2(L * 0.5, W - 0.5)
				a.vel = Vector2.ZERO
				a.stun = 0.0
			a.on = true
			_load_attrs(a)


func _load_attrs(a: A) -> void:
	var mp := a.mp
	var f := clampf(mp.f, 0.6, 1.25)
	var q := func(i: int) -> float: return clampf(float(mp.p.attrs[i]) * f / 100.0, 0.05, 1.0)
	var c := clampf(mp.cond / 100.0, 0.2, 1.0)
	var heavy := Physique.pace_penalty(mp.p)
	a.spd = (5.9 + 3.1 * clampf((float(mp.p.attrs[Attr.VEL]) - heavy) * f / 100.0, 0.05, 1.0)) * (0.8 + 0.2 * c)
	a.acc = 3.2 + 3.6 * clampf((float(mp.p.attrs[Attr.ACE]) - heavy) * f / 100.0, 0.05, 1.0)
	a.pas = q.call(Attr.PAS)
	a.vis = q.call(Attr.VIS)
	a.tec = q.call(Attr.TEC)
	a.dri = q.call(Attr.DRI)
	a.fin = clampf(mp.c_fin * f / 100.0, 0.05, 1.0)
	a.lng = clampf(mp.c_long * f / 100.0, 0.05, 1.0)
	a.hed = clampf(mp.c_head * f / 110.0, 0.05, 1.0)
	a.tck = q.call(Attr.DES)
	a.mar = q.call(Attr.MAR)
	a.psn = q.call(Attr.POS)
	a.dec = q.call(Attr.DEC)
	a.strn = clampf((float(mp.p.attrs[Attr.FOR]) + Physique.strength(mp.p)) * f / 100.0, 0.05, 1.0)
	a.cro = clampf(mp.a_cru * f / 100.0, 0.05, 1.0)
	a.gkv = clampf(mp.c_gk * f / 100.0, 0.05, 1.0)
	a.agg = clampf(1.15 - float(mp.p.attrs[Attr.DIS]) / 100.0, 0.2, 1.0) * mp.card_mult
	a.wa = mp.w_att


## Posição de saída (cada time no próprio campo).
func _shape_pos(a: A, _home: bool) -> Vector2:
	var d := clampf(a.ay * 0.78, 0.03, 0.46)
	return pt(a.side, 0.5 + (a.ax - 0.5) * 0.9, d)


func _on(side: int) -> Array:
	var out: Array = []
	for a: A in ag[side]:
		if a.on:
			out.append(a)
	return out


func keeper(side: int) -> A:
	var arr: Array = ag[side]
	if not arr.is_empty() and (arr[0] as A).on:
		return arr[0]
	return null


## Saída de bola (início de tempo ou depois de gol).
func kickoff(side: int) -> void:
	for s in 2:
		for a: A in ag[s]:
			if a.on:
				a.pos = _shape_pos(a, s == 0)
				a.vel = Vector2.ZERO
				a.stun = 0.0
				a.run_t = 0.0
	ball = Vector2(L * 0.5, W * 0.5)
	bvel = Vector2.ZERO
	bh = 0.0
	bvh = 0.0
	pz = {}
	shot_fx = {}
	var k := _nearest(side, ball, true)
	if k != null:
		k.pos = ball - Vector2(dirx(side) * 0.6, 0.0)
	owner = k
	last_touch = k
	last_side = side
	decide_t = 0.6
	dead = 0.0
	restart = {}


# ---------------------------------------------------------------------------
# Laço
# ---------------------------------------------------------------------------

## Um minuto de jogo (240 passos de 0,25 s). Os eventos saem pela MatchSimulation com o segundo
## do lance ("sec"); os quadros ficam em `frames` para a tela.
func run_minute() -> void:
	frames.clear()
	keys.clear()
	sync_teams()
	for i in TICKS:
		t = i * DT
		sim.live_sec = t
		_tick()
		clock += DT
		frames.append([t, _snapshot()])
		if sim.finished:
			break


func _snapshot() -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(49)
	var k := 0
	for side in 2:
		var arr: Array = ag[side]
		for i in 11:
			if i < arr.size() and (arr[i] as A).on:
				var a: A = arr[i]
				f[k] = a.pos.x
				f[k + 1] = a.pos.y
			else:
				f[k] = -100.0
				f[k + 1] = -100.0
			k += 2
	f[44] = ball.x
	f[45] = ball.y
	f[46] = bh
	f[47] = (owner.side * 11 + owner.slot) if owner != null else -1.0
	f[48] = dead
	return f


func _tick() -> void:
	for side in 2:
		for a: A in ag[side]:
			if a.stun > 0.0:
				a.stun -= DT
			if a.run_t > 0.0:
				a.run_t -= DT
	if dead > 0.0:
		_dead_tick()
		return
	_team_state()
	_move_all()
	_ball_step()
	if owner != null and dead <= 0.0:
		poss_t[owner.side] += DT
		_holder_tick()
		if owner != null and dead <= 0.0:
			_duel()


## Linhas de cada time: quem tem a bola, profundidade da bola e linha de impedimento.
func _team_state() -> void:
	var s_poss := owner.side if owner != null else last_side
	for side in 2:
		in_poss[side] = side == s_poss
		ball_d[side] = depth(side, ball)
		# Linha de impedimento de quem ataca: o penúltimo adversário (goleiro conta)
		var ds: Array[float] = []
		for o: A in ag[1 - side]:
			if o.on:
				ds.append(depth(side, o.pos))
		ds.sort()
		var second := ds[ds.size() - 2] if ds.size() >= 2 else 0.5
		off_line[side] = maxf(maxf(second, ball_d[side]), 0.5)
	# Quem pressiona: os mais perto da bola no time sem a bola
	for side in 2:
		presser[side] = []
		if in_poss[side]:
			continue
		var tm: MatchTeam = sim.teams[side]
		var prs := tm.pressing
		if tm.style == TeamSheet.STYLE_PRESSAO:
			prs = 2
		var zone: float = [0.5, 0.64, 1.01][clampi(prs, 0, 2)]
		# Profundidade da bola vista por quem defende: perto do próprio gol = pequena
		var bd := ball_d[side]
		var n := 1 if prs == 0 else 2
		if bd > zone:
			n = 0 # não sai: fecha o espaço e espera
		var cands: Array = []
		for a: A in ag[side]:
			if a.on and not a.gk and a.stun <= 0.0:
				cands.append([a.pos.distance_squared_to(ball), a])
		cands.sort_custom(func(x, y): return x[0] < y[0])
		for i in mini(maxi(n, 1), cands.size()):
			presser[side].append(cands[i][1])
		if n == 0 and not presser[side].is_empty():
			presser[side] = [presser[side][0]]
			presser[side][0].set_meta("contain", true)


func _move_all() -> void:
	for side in 2:
		for a: A in ag[side]:
			if not a.on or a == owner:
				continue
			var urg := 0.45
			var tg: Vector2
			if a.gk:
				tg = _gk_target(a)
				urg = 0.7
			elif owner == null and _chaser(a):
				tg = _ball_intercept_point(a)
				urg = 1.0
			elif owner == null and not pz.is_empty() and int(pz["from"].side) != side and _lane_cutter(a):
				# Passe no ar: quem está perto da linha vai cortar
				tg = _lane_point(a)
				urg = 1.0
			elif not in_poss[side] and presser[side].has(a):
				tg = _press_target(a)
				urg = 1.0 if not a.has_meta("contain") else 0.6
			else:
				tg = _formation_target(a)
				if a.run_t > 0.0:
					urg = 1.0
				elif a.pos.distance_to(tg) > 9.0:
					urg = 0.8
			if a.has_meta("contain"):
				a.remove_meta("contain")
			a.tgt = tg
			_steer(a, tg, urg)
	_separate()


func _steer(a: A, tg: Vector2, urg: float) -> void:
	if a.stun > 0.0:
		a.vel *= 0.6
		a.pos += a.vel * DT
		return
	var to := tg - a.pos
	var dist := to.length()
	var vmax := a.spd * (0.5 + 0.5 * urg)
	var desired := Vector2.ZERO
	if dist > 0.15:
		desired = to / dist * minf(vmax, dist * 1.8)
	var dv := desired - a.vel
	var mx := a.acc * DT
	if dv.length() > mx:
		dv = dv.normalized() * mx
	a.vel += dv
	a.pos = _clampf_field(a.pos + a.vel * DT)
	if a.vel.length_squared() > 0.3:
		a.face = a.vel.normalized()


## Colegas não se amontoam (empurrão leve de quem está a menos de 2 m) e adversários não se
## atravessam (ninguém ocupa o mesmo espaço de outro corpo).
func _separate() -> void:
	for a: A in ag[0]:
		if not a.on:
			continue
		for b: A in ag[1]:
			if not b.on:
				continue
			var d := a.pos - b.pos
			var l2 := d.length_squared()
			if l2 < 0.81 and l2 > 1e-4:
				var push := d / sqrt(l2) * (0.9 - sqrt(l2)) * 0.5
				a.pos += push
				b.pos -= push
	for side in 2:
		var arr: Array = ag[side]
		for i in arr.size():
			var a: A = arr[i]
			if not a.on or a == owner:
				continue
			for j in range(i + 1, arr.size()):
				var b: A = arr[j]
				if not b.on:
					continue
				var d := a.pos - b.pos
				var l2 := d.length_squared()
				if l2 < 4.0 and l2 > 1e-4:
					var push := d / sqrt(l2) * (2.0 - sqrt(l2)) * 0.25
					a.pos += push
					if b != owner:
						b.pos -= push


## O mais perto da bola solta de cada time vai nela (dois do time que a perdeu por último).
func _chaser(a: A) -> bool:
	if not pz.is_empty() and pz.get("to") == a:
		return true
	var best: A = null
	var bd := INF
	for o: A in ag[a.side]:
		if not o.on or o.gk:
			continue
		var d := o.pos.distance_squared_to(ball)
		if d < bd:
			bd = d
			best = o
	return best == a


func _lane_cutter(a: A) -> bool:
	var to: Vector2 = pz["at"]
	return seg_dist(a.pos, ball, to) < 5.0 + a.psn * 3.0


func _lane_point(a: A) -> Vector2:
	var to: Vector2 = pz["at"]
	var ab := to - ball
	var tt := clampf((a.pos - ball).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.1, 1.0)
	return ball + ab * tt


func _ball_intercept_point(a: A) -> Vector2:
	# Mira onde a bola vai estar quando ele chegar
	var tt := a.pos.distance_to(ball) / maxf(3.0, a.spd)
	return _clampf_field(ball + bvel * minf(tt, 1.5))


func _press_target(a: A) -> Vector2:
	var og := own_goal(a.side)
	var to_goal := (og - ball).normalized()
	if a.has_meta("contain"):
		return ball + to_goal * 6.0
	return ball + to_goal * 0.8


## Posição de quem não está na bola: âncora da formação encaixada no bloco do time, que sobe,
## desce e desliza com a bola; depois os comportamentos (marcação, corrida em profundidade,
## apoio, largura).
func _formation_target(a: A) -> Vector2:
	var s := a.side
	var tm: MatchTeam = sim.teams[s]
	var bd := ball_d[s]
	var att := in_poss[s]
	var line_bias: float = [-0.06, 0.0, 0.07][clampi(tm.line, 0, 2)]
	var m := float(tm.mentality - 2) * 0.025
	var lo: float
	var hi: float
	if att:
		# Com a bola o time sobe junto: a zaga acompanha (~25 m atrás da bola)
		lo = clampf(bd - 0.25 + m + line_bias * 0.5, 0.15, 0.55)
		hi = clampf(lo + 0.45 + m, 0.5, 0.97)
		hi = minf(hi, off_line[s] - 0.006)
	else:
		lo = clampf(bd - 0.28 + line_bias + m * 0.6, 0.05, 0.45)
		# Bloco compacto: ~30 m entre a zaga e o ataque (mais curto no próprio terço)
		hi = clampf(lo + 0.3 - 0.03 * float(tm.pressing - 1) - (0.04 if bd < 0.35 else 0.0), lo + 0.2, 0.8)
	var k := clampf((a.ay - 0.15) / 0.51, 0.0, 1.05)
	var d := lerpf(lo, hi, k)
	var width_k := 0.6 # sem a bola o time fecha por dentro
	if att:
		width_k = [0.84, 1.0, 1.12][clampi(tm.sheet.width if tm.sheet != null else 1, 0, 2)]
		if tm.style == TeamSheet.STYLE_LADOS:
			width_k += 0.08
	var lx := 0.5 + (a.ax - 0.5) * width_k
	lx = lerpf(lx, lat(s, ball), 0.1 if att else 0.3)
	if att:
		# Quem tem instrução de apoiar sobe (laterais passando pelo ponta)
		var side_ball := absf(lat(s, ball) - a.ax) < 0.3
		d += a.wa * (0.08 if side_ball else 0.04)
		if a.run_t > 0.0:
			return a.run_to
		_maybe_run(a, d)
		d = minf(d, off_line[s] - 0.004)
		var p := pt(s, lx, d)
		# Apoio: os dois mais perto do portador abrem linha de passe
		if owner != null and owner.side == s and a.pos.distance_squared_to(owner.pos) < 400.0 and a.ay < 0.55:
			var off := Vector2(0.0, 9.0 if lat(s, a.pos) > lat(s, owner.pos) else -9.0)
			if s == 1:
				off.y = -off.y
			p = p.lerp(owner.pos + off + Vector2(dirx(s) * -3.0, 0.0), 0.35)
		return p
	var p2 := pt(s, lx, d)
	# Marcação por zona com encaixe: pega o atacante mais perto da sua zona
	var mk: A = null
	var md := 12.0 * 12.0 * (0.6 + a.mar * 0.8)
	for o: A in ag[1 - s]:
		if not o.on or o.gk:
			continue
		var dd := o.pos.distance_squared_to(p2)
		if dd < md:
			md = dd
			mk = o
	if mk != null:
		var og := own_goal(s)
		var mpos := mk.pos
		if mk.run_t > 0.0:
			# Atacante arrancou: o marcador acompanha a corrida
			mpos = mk.pos.lerp(mk.run_to, clampf(0.3 + a.mar * 0.4, 0.0, 0.8))
		var goal_side := mpos + (og - mpos).normalized() * 1.6
		p2 = p2.lerp(goal_side, clampf(0.35 + a.mar * 0.4 + (0.2 if depth(s, mk.pos) < 0.3 else 0.0), 0.0, 0.85))
	return p2


## Corrida em profundidade: atacantes e quem tem instrução de apoiar arrancam para as costas da
## defesa quando um colega pode lançar.
func _maybe_run(a: A, _d: float) -> void:
	if owner == null or owner.side != a.side or owner == a:
		return
	if a.ay < 0.5 and a.wa < 0.45:
		return
	var s := a.side
	var rate := 0.05 + 0.08 * a.dec + 0.03 * float(sim.teams[s].mentality - 2)
	if sim.teams[s].style == TeamSheet.STYLE_CONTRA and clock - turnover_t < 8.0:
		rate *= 2.0
	if rng.randf() > rate * DT * 4.0:
		return
	# Corre até a linha (sem passar dela): quem decide a hora de ir para as costas é o passe
	# Nem todo mundo acerta o tempo: às vezes passa da linha antes da hora
	var target_d := minf(off_line[s] + rng.randf_range(-0.012, 0.014) * (1.4 - a.dec), 0.93)
	var l := clampf(lat(s, a.pos) + rng.randf_range(-0.12, 0.12), 0.15, 0.85)
	a.run_to = pt(s, l, target_d)
	a.run_t = 2.0


func _gk_target(a: A) -> Vector2:
	var s := a.side
	var og := own_goal(s)
	var d := ball.distance_to(og)
	# Bola solta perto: sai para abafar
	if owner == null and pz.is_empty() and d < 12.0 and _chaser_gk(a):
		return ball
	# Enfiada para a área: o goleiro sai no ponto da bola
	if not pz.is_empty() and int(pz["from"].side) != s and String(pz.get("kind", "")) in ["through", "long"]:
		var at: Vector2 = pz["at"]
		if at.distance_to(og) < 22.0:
			return at
	var out := clampf(d * 0.12, 1.0, 5.5)
	if in_poss[s]:
		out = clampf(d * 0.2, 2.0, 14.0)
	return og + (ball - og).normalized() * out


func _chaser_gk(a: A) -> bool:
	var dg := a.pos.distance_squared_to(ball)
	for o: A in ag[1 - a.side]:
		if o.on and o.pos.distance_squared_to(ball) < dg * 0.8:
			return false
	return true


func _nearest(side: int, p: Vector2, skip_gk: bool = true, exclude: A = null) -> A:
	var best: A = null
	var bd := INF
	for a: A in ag[side]:
		if not a.on or a == exclude or (skip_gk and a.gk):
			continue
		var d := a.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = a
	return best


# ---------------------------------------------------------------------------
# Bola
# ---------------------------------------------------------------------------

func _ball_step() -> void:
	if owner != null:
		ball = owner.pos + owner.face * 0.55
		bvel = owner.vel
		bh = 0.0
		bvh = 0.0
		return
	ball += bvel * DT
	if bh > 0.0 or bvh > 0.0:
		bvh -= 9.8 * DT
		bh += bvh * DT
		bvel *= 0.992
		if bh <= 0.0:
			bh = 0.0
			if absf(bvh) > 2.5:
				bvh = -bvh * 0.4
				bvel *= 0.8
			else:
				bvh = 0.0
	else:
		var sp := bvel.length()
		if sp > 0.0:
			bvel = bvel / sp * maxf(0.0, sp - 2.4 * DT)
	if not shot_fx.is_empty():
		shot_fx["t"] = float(shot_fx["t"]) - DT
		if float(shot_fx["t"]) <= 0.0:
			_shot_land()
		return
	if _out_check():
		return
	_control_check()


## Bola saiu: lateral, escanteio ou tiro de meta.
func _out_check() -> bool:
	if (ball.y < 0.0 or ball.y > W or ball.x < 0.0 or ball.x > L) and not pz.is_empty():
		fail_out[int(pz["from"].side)] += 1
	if ball.y < 0.0 or ball.y > W:
		var side := 1 - last_side
		_set_restart("throw", side, Vector2(clampf(ball.x, 1.0, L - 1.0), clampf(ball.y, 0.0, W)))
		return true
	if ball.x < 0.0 or ball.x > L:
		var def_side := 0 if ball.x < 0.0 else 1 # dono do gol daquela linha de fundo
		if last_side == def_side:
			_set_restart("corner", 1 - def_side, Vector2(0.3 if ball.x < 0.0 else L - 0.3, 0.3 if ball.y < W * 0.5 else W - 0.3))
		else:
			_set_restart("goal_kick", def_side, Vector2(5.5 if def_side == 0 else L - 5.5, W * 0.5 + (9.0 if ball.y > W * 0.5 else -9.0)))
		return true
	return false


## Quem está ao alcance da bola tenta dominar: o destinatário tem prioridade; adversários no
## caminho interceptam conforme posicionamento e técnica; bola alta vira disputa de cabeça.
func _control_check() -> void:
	var sp := bvel.length()
	var high := bh > 1.9
	var cands: Array = []
	for side in 2:
		for a: A in ag[side]:
			if not a.on or a.stun > 0.0:
				continue
			var reach := 1.1 if not a.gk else 1.9
			if not pz.is_empty() and pz.get("to") == a:
				reach = 1.5
			if not a.gk and not pz.is_empty() and a.side != int(pz["from"].side):
				reach = 1.3 + a.psn * 0.4 # quem defende se estica para cortar
			if a.gk and depth(a.side, ball) < 0.16 and absf(lat(a.side, ball) - 0.5) < 0.3:
				reach = 2.4
			var d := a.pos.distance_to(ball)
			if d < reach and (bh < 2.6 or a.gk and bh < 3.0):
				cands.append([d, a])
	if cands.is_empty():
		return
	cands.sort_custom(func(x, y): return x[0] < y[0])
	if high and bh < 3.0:
		_aerial(cands)
		return
	for c in cands:
		var a: A = c[1]
		var intended: bool = not pz.is_empty() and pz.get("to") == a
		var p := 0.0
		if a.gk and depth(a.side, ball) < 0.17:
			p = 0.75 + 0.2 * a.gkv
		elif intended:
			p = 0.93 + 0.06 * a.tec - clampf((sp - 18.0) * 0.02, 0.0, 0.25)
			# Marcador colado disputa a bola na recepção (mais ainda dentro da área)
			var tight := _nearest(1 - a.side, a.pos, false)
			if tight != null and not tight.gk and tight.stun <= 0.0 and tight.pos.distance_to(a.pos) < 2.0:
				var in_box := depth(a.side, a.pos) > 1.0 - BOX_D / L and absf(a.pos.y - W * 0.5) < BOX_HW
				var p_def := clampf(0.2 + 0.35 * tight.mar + 0.15 * tight.psn - 0.25 * a.tec - 0.1 * a.strn + (0.12 if in_box else 0.0), 0.05, 0.7)
				if rng.randf() < p_def:
					_gain(tight)
					return
		elif not pz.is_empty() and a.side != int(pz["from"].side):
			p = 0.45 + 0.35 * a.psn - clampf((sp - 14.0) * 0.025, 0.0, 0.25)
		else:
			p = 0.75 + 0.22 * a.tec - clampf((sp - 10.0) * 0.03, 0.0, 0.5)
		if rng.randf() < p:
			_gain(a)
			return


func _aerial(cands: Array) -> void:
	var best: A = null
	var bv := -1.0
	for c in cands:
		var a: A = c[1]
		var v := (a.hed * 0.6 + a.strn * 0.3 + rng.randf() * 0.5) * (1.4 if a.gk and depth(a.side, ball) < 0.16 else 1.0)
		if v > bv:
			bv = v
			best = a
	if best == null:
		return
	if best.gk and depth(best.side, ball) < 0.17:
		_gain(best)
		sim.live_keeper_claim(best.mp)
		return
	var s := best.side
	var in_box := depth(s, best.pos) > 0.84 and absf(lat(s, best.pos) - 0.5) < 0.32
	if in_box and _cross_active(s):
		_shoot(best, true)
		return
	# Zagueiro afasta de cabeça na área: às vezes manda para escanteio
	if not in_box and depth(s, best.pos) < 0.18 and rng.randf() < 0.22:
		last_touch = best
		last_side = s
		_set_restart("corner", 1 - s, Vector2(0.3 if s == 0 else L - 0.3, 0.3 if best.pos.y < W * 0.5 else W - 0.3))
		return
	# Cabeçada para longe (defesa) ou para um colega (ataque)
	last_touch = best
	last_side = s
	pz = {}
	var dirv := (goal_of(s) - best.pos).normalized().rotated(rng.randf_range(-0.8, 0.8))
	bvel = dirv * rng.randf_range(9.0, 16.0)
	bvh = rng.randf_range(2.0, 5.0)
	bh = maxf(bh, 1.5)


func _cross_active(side: int) -> bool:
	return not pz.is_empty() and int(pz["from"].side) == side and String(pz.get("kind", "")) in ["cross", "corner", "fk_cross"]


## `a` domina a bola: fecha passe (certo ou interceptado), impedimento, troca de posse.
func _gain(a: A) -> void:
	var prev_side := last_side
	if not pz.is_empty():
		var from: A = pz["from"]
		if from.side == a.side:
			if bool(pz.get("off", false)) and a == pz.get("to"):
				pz = {}
				owner = null
				sim.live_offside(a.side, a.mp)
				_set_restart("fk", 1 - a.side, a.pos)
				return
			passes_ok[a.side] += 1
			assist_by = from
			assist_t = clock
			assist_kind = String(pz.get("kind", "pass"))
			sim.live_pass(from.mp, a.mp, true, threat(a.side, a.pos) > 0.05)
		else:
			fail_int[from.side] += 1
			sim.live_pass(from.mp, null, false, false)
			sim.live_intercept(a.mp)
	pz = {}
	owner = a
	last_touch = a
	last_side = a.side
	a.vel *= 0.4
	decide_t = 1.5 + (1.0 - a.dec) * 0.7 # domina, levanta a cabeça e só então decide
	carry_t = 0.0
	if prev_side != a.side:
		turnover_t = clock
		turnover_d = depth(a.side, a.pos)
		assist_by = null


# ---------------------------------------------------------------------------
# Decisões de quem tem a bola
# ---------------------------------------------------------------------------

func _holder_tick() -> void:
	var h := owner
	var s := h.side
	var tm: MatchTeam = sim.teams[s]
	carry_t += DT
	decide_t -= DT
	var press := _pressure(h)
	# No último terço o jogo é de decisões rápidas: reavalia a cada passo
	var dh := depth(s, h.pos)
	if dh > 0.68:
		decide_t = minf(decide_t, 0.25)
	if decide_t > 0.0 and press < 0.75:
		_carry(h, press)
		return
	var style := tm.style
	var ment := tm.mentality
	# Opções
	var best_v := -1.0
	var best: Dictionary = {}
	var here := threat(s, h.pos)
	# Chute
	var gd := h.pos.distance_to(goal_of(s))
	if gd < 32.0 and not h.gk:
		var xg := _xg_at(h, h.pos, false)
		var eager := 1.0 + 0.12 * float(ment - 2) + (0.15 if style == TeamSheet.STYLE_DIRETO else 0.0) - (0.2 if style == TeamSheet.STYLE_POSSE else 0.0)
		if gd > 19.0:
			eager *= 0.5 + h.lng * 0.7
		# Chutar entrega a bola: só vale se a chance for melhor do que manter a posse
		var g := goal_of(s)
		var blockers := 0
		for o: A in ag[1 - s]:
			if o.on and not o.gk and seg_dist(o.pos, h.pos, g) < 1.2 and o.pos.distance_to(h.pos) < 12.0:
				blockers += 1
		xg *= pow(0.8, blockers)
		# Na cara do gol chutar é quase sempre o certo; de longe só quem tem chute
		# Mesma escala dos passes: o chute troca o valor da posse atual pelo xG (+ sobra/escanteio)
		var v := xg * eager * SHOT_BIAS - (here + KEEP)
		if v > best_v:
			best_v = v
			best = {"k": "shoot"}
	# Passes
	for r: A in ag[s]:
		if not r.on or r == h:
			continue
		for kind in _pass_kinds(h, r, style):
			var o := _eval_pass(h, r, kind, press, style, ment)
			if o.is_empty():
				continue
			if float(o["v"]) > best_v:
				best_v = float(o["v"])
				best = o
	# Conduzir (ganho de terreno se houver espaço)
	var cv := _carry_value(h, press, here, style)
	if cv > best_v:
		best_v = cv
		best = {"k": "carry"}
	# Chutão quando pressionado no próprio terço sem opção
	if depth(s, h.pos) < 0.3 and press > 0.8 and best_v < 0.004:
		best = {"k": "clear"}
	# Um jogador com decisão ruim escolhe pior (ruído)
	decide_t = clampf(1.9 + (1.0 - h.dec) * 0.7 - press * 0.9, 0.3, 2.6)
	if style == TeamSheet.STYLE_POSSE:
		decide_t += 0.12
	match String(best.get("k", "carry")):
		"shoot":
			_shoot(h, false)
		"pass":
			_do_pass(h, best)
		"clear":
			_clearance(h)
		_:
			_carry(h, press)


## 0 (livre) … 1+ (cercado): adversários perto e na frente.
func _pressure(h: A) -> float:
	var p := 0.0
	var fwd := Vector2(dirx(h.side), 0.0)
	for o: A in ag[1 - h.side]:
		if not o.on:
			continue
		var d := o.pos.distance_to(h.pos)
		if d < 5.0:
			var front := 1.0 if (o.pos - h.pos).dot(fwd) > 0.0 else 0.6
			p += (5.0 - d) / 5.0 * front
	return p


func _pass_kinds(h: A, r: A, style: int) -> Array:
	var out: Array = ["pass"]
	var s := h.side
	var dr := depth(s, r.pos)
	if r.run_t > 0.0 or (dr > depth(s, h.pos) + 0.08 and dr > 0.55):
		out.append("through")
	var dh := depth(s, h.pos)
	var wide := absf(lat(s, h.pos) - 0.5) > 0.3
	if dh > 0.72 and wide and dr > 0.8 and absf(lat(s, r.pos) - 0.5) < 0.3:
		out.append("cross")
	var dist := h.pos.distance_to(r.pos)
	if dist > 28.0 and (style == TeamSheet.STYLE_DIRETO or style == TeamSheet.STYLE_LONGA or dr > 0.6):
		out.append("long")
	return out


## Avalia um passe: onde a bola chega, risco de interceptação, precisão e o que se ganha.
func _eval_pass(h: A, r: A, kind: String, press: float, style: int, ment: int) -> Dictionary:
	var s := h.side
	var spd := 15.0
	var loft := false
	var to := r.pos + r.vel * 0.6
	match kind:
		"through":
			# Bola no espaço às costas da linha: o recebedor arranca na hora do passe
			to = r.pos + Vector2(dirx(s) * (7.0 + r.spd * 0.6), (r.vel.y * 0.4))
			spd = 16.0
		"cross":
			spd = 19.0
			loft = true
			to = r.pos + Vector2(dirx(s) * 1.5, 0.0)
		"long":
			spd = 22.0
			loft = true
			to = r.pos + r.vel * 1.2
	to = Vector2(clampf(to.x, 1.5, L - 1.5), clampf(to.y, 2.0, W - 2.0))
	var dist := h.pos.distance_to(to)
	if dist < 4.0 or dist > 60.0:
		return {}
	if not loft:
		# Força na medida: a bola chega ao pé sem passar direto
		spd = clampf(dist * 0.75 + 6.0, 9.0, spd)
	if r.gk and depth(s, h.pos) > 0.35:
		return {}
	# Impedido: recebedor à frente da linha no momento do passe (no campo adversário)
	var off := depth(s, r.pos) > off_line[s] + 0.004 and depth(s, r.pos) > 0.5
	# Interceptação: adversários que chegam na linha do passe antes da bola
	var risk := 0.0
	var tb := dist / spd
	for o: A in ag[1 - s]:
		if not o.on:
			continue
		var sd := seg_dist(o.pos, h.pos, to)
		if loft:
			# Bola alta só é cortada perto do destino
			sd = o.pos.distance_to(to) * 1.2
		var proj := clampf((o.pos - h.pos).dot(to - h.pos) / maxf(1.0, dist * dist), 0.0, 1.0)
		var t_ball := tb * proj
		var t_o := maxf(0.0, sd - 1.0) / maxf(4.0, o.spd * 0.8) + 0.25
		var ri := clampf(0.5 + (t_ball - t_o) * 1.6, 0.0, 0.95)
		if loft and proj < 0.8:
			ri *= 0.3
		risk = 1.0 - (1.0 - risk) * (1.0 - ri)
	# Corrida pela bola: na enfiada e no lançamento, quem chega antes no ponto (goleiro incluído)
	if kind == "through" or kind == "long" or dist > 25.0:
		var t_r := maxf(tb, r.pos.distance_to(to) / maxf(3.0, r.spd))
		var t_d := INF
		for o3: A in ag[1 - s]:
			if o3.on:
				var reach_o := maxf(0.0, o3.pos.distance_to(to) - (2.0 if o3.gk else 1.0))
				t_d = minf(t_d, reach_o / maxf(3.0, o3.spd * 0.95) + 0.2)
		var race := clampf(0.5 + (t_d - t_r) * 1.1, 0.03, 0.97)
		risk = 1.0 - (1.0 - risk) * race
	# Área cheia: passe para dentro dela é muito mais cortado
	if depth(s, to) > 1.0 - BOX_D / L and absf(to.y - W * 0.5) < BOX_HW:
		var crowd := 0
		for o6: A in ag[1 - s]:
			if o6.on and o6.pos.distance_to(to) < 5.0:
				crowd += 1
		risk = 1.0 - (1.0 - risk) * pow(0.8, crowd)
	var skill := h.pas * 0.7 + h.vis * 0.15 + h.tec * 0.15
	if kind == "cross":
		skill = h.cro * 0.8 + h.tec * 0.2
	elif kind == "long":
		skill = h.pas * 0.6 + h.vis * 0.25 + h.lng * 0.15
	var acc := clampf(1.0 - (1.0 - skill) * (dist / 38.0) * (1.0 + press * 0.5) - (0.12 if loft else 0.0), 0.2, 0.98)
	var ok := (1.0 - minf(0.99, risk * 1.2)) * acc # o jogador superestima um pouco o risco (joga seguro)
	# Valor de ter a bola = ameaça do lugar + o valor da própria posse (KEEP): perder a bola custa
	# isso e a ameaça que o rival ganha; por isso o time circula em vez de arriscar sempre
	var gain := threat(s, to) + KEEP
	# Espaço de quem recebe (um recebedor marcado vale menos)
	var space := 99.0
	for o2: A in ag[1 - s]:
		if o2.on:
			space = minf(space, o2.pos.distance_to(to))
	gain += clampf((space - 3.0) * 0.0015, -0.006, 0.01)
	if kind == "cross":
		gain = _xg_at(r, to, true) * 0.6 + KEEP * 0.3
	var loss := threat(1 - s, to) * 0.9 + KEEP
	var v := ok * gain - (1.0 - ok) * loss - (threat(s, h.pos) + KEEP)
	# Estilo e mentalidade
	var fwd := depth(s, to) - depth(s, h.pos)
	match style:
		TeamSheet.STYLE_POSSE:
			v += 0.004 * ok - (0.004 if fwd > 0.2 else 0.0)
		TeamSheet.STYLE_DIRETO:
			v += fwd * 0.01
		TeamSheet.STYLE_LADOS:
			if absf(lat(s, to) - 0.5) > 0.3 or kind == "cross":
				v += 0.004
		TeamSheet.STYLE_LONGA:
			if kind == "long":
				v += 0.006
		TeamSheet.STYLE_CONTRA:
			if clock - turnover_t < 7.0:
				v += fwd * 0.02
	v += fwd * 0.003 * float(ment - 2)
	if off:
		v -= 0.06 * (0.3 + h.vis * 0.7) # quem tem visão enxerga o impedimento
	v += rng.randf_range(-0.004, 0.004) * (1.5 - h.dec)
	return {"k": "pass", "r": r, "kind": kind, "to": to, "spd": spd, "loft": loft, "ok": ok, "off": off, "v": v}


func _carry_value(h: A, press: float, here: float, style: int) -> float:
	var s := h.side
	var ahead := h.pos + Vector2(dirx(s) * 7.0, 0.0)
	var space := 99.0
	for o: A in ag[1 - s]:
		if o.on:
			space = minf(space, seg_dist(o.pos, h.pos, ahead))
	var keep := clampf(0.55 + space * 0.08 + h.dri * 0.25 - press * 0.3, 0.1, 0.97)
	# Conduzir para dentro da área cheia de zagueiros é perder a bola
	var dd := depth(s, h.pos)
	if dd > 0.78:
		var close := 0
		for o5: A in ag[1 - s]:
			if o5.on and not o5.gk and o5.pos.distance_to(h.pos) < 4.0:
				close += 1
		keep -= 0.15 * close + 0.2 * smoothstep(0.78, 0.9, dd)
		keep = clampf(keep, 0.05, 0.95)
	var gain := threat(s, ahead) + KEEP
	var v := keep * gain - (1.0 - keep) * (threat(1 - s, h.pos) * 0.8 + KEEP) - (here + KEEP)
	if style == TeamSheet.STYLE_POSSE:
		v -= 0.002
	v -= carry_t * 0.0015 # não fica eternamente com a bola
	return v + rng.randf_range(-0.003, 0.003)


func _carry(h: A, press: float) -> void:
	var s := h.side
	var g := goal_of(s)
	var dirv := (g - h.pos).normalized()
	# Desvia do adversário mais próximo à frente
	var near := _nearest(1 - s, h.pos, false)
	if near != null and near.pos.distance_to(h.pos) < 6.0:
		var away := (h.pos - near.pos).normalized()
		dirv = (dirv + away * 0.8).normalized()
	# Ponta abre para a linha de fundo; ninguém corre para a lateral
	if absf(lat(s, h.pos) - 0.5) > 0.35 and depth(s, h.pos) < 0.85:
		dirv = (dirv + Vector2(dirx(s), 0.0)).normalized()
	var spd := h.spd * (0.62 + 0.12 * h.dri) * (0.8 if press > 0.6 else 1.0)
	# Corpo a corpo: com um marcador colado na frente não dá para passar reto
	if near != null:
		var rel := near.pos - h.pos
		if rel.length() < 1.4 and rel.dot(dirv) > 0.0:
			spd *= 0.35
			dirv = (dirv + rel.normalized().orthogonal() * (1.0 if rel.cross(dirv) > 0.0 else -1.0)).normalized()
	var desired := dirv * spd
	var dv := desired - h.vel
	var mx := h.acc * DT
	if dv.length() > mx:
		dv = dv.normalized() * mx
	h.vel += dv
	h.pos = _clampf_field(h.pos + h.vel * DT)
	h.face = dirv


func _do_pass(h: A, o: Dictionary) -> void:
	var r: A = o["r"]
	var kind := String(o["kind"])
	var to: Vector2 = o["to"]
	var s := h.side
	passes[s] += 1
	# Erro de execução proporcional à falta de precisão
	var ok := float(o["ok"])
	var err := (1.0 - clampf(ok * 1.08, 0.0, 1.0)) * h.pos.distance_to(to) * 0.2 + (1.0 - h.pas) * 0.8
	to += Vector2(rng.randfn(0.0, err), rng.randfn(0.0, err))
	var dist := h.pos.distance_to(to)
	var spd := float(o["spd"])
	owner = null
	last_touch = h
	last_side = s
	bvel = (to - h.pos).normalized() * spd
	if bool(o["loft"]):
		var tt := dist / spd
		bvh = 9.8 * tt * 0.5 # chega ao destino descendo
		bh = 0.3
	else:
		bh = 0.0
		bvh = 0.0
	pz = {"from": h, "to": r, "kind": kind, "t": clock, "off": bool(o["off"]), "at": to}
	h.vel *= 0.5
	# Quem recebe vai na bola (na enfiada, arranca para o espaço)
	r.run_t = 0.0
	if kind == "through":
		r.run_to = to
		r.run_t = 1.5
	if kind == "cross":
		keys.append([t, 0.6])
		sim.live_cross(s, h.mp, r.mp)
	elif kind == "through" and depth(s, to) > 0.75:
		keys.append([t, 0.5])


func _clearance(h: A) -> void:
	var s := h.side
	owner = null
	last_touch = h
	last_side = s
	pz = {}
	var to := pt(s, rng.randf_range(0.2, 0.8), rng.randf_range(0.55, 0.8))
	bvel = (to - h.pos).normalized() * rng.randf_range(20.0, 27.0)
	bvh = rng.randf_range(7.0, 11.0)
	bh = 0.3


## Carrinho/bote em quem conduz: desarme, drible ou falta.
func _duel() -> void:
	var h := owner
	var s := h.side
	for o: A in ag[1 - s]:
		if not o.on or o.gk or o.stun > 0.0:
			continue
		var d := o.pos.distance_to(h.pos)
		if d > 2.0:
			continue
		var tm: MatchTeam = sim.teams[o.side]
		var intensity: float = [0.75, 1.0, 1.3][clampi(tm.intensity, 0, 2)]
		var behind := (o.pos - h.pos).dot(Vector2(dirx(s), 0.0)) < -0.3
		var attempt: float = 0.16 * intensity * (0.6 + o.tck * 0.6 + o.agg * 0.2) * (1.0 + carry_t * 0.3) * (1.8 if d < 1.2 and not behind else 1.0)
		if rng.randf() > attempt:
			continue
		tackles[o.side] += 1
		var foul_p: float = (0.2 + 0.16 * o.agg) * (1.9 if behind else 1.0) * sim.ref_fouls * (1.1 if sim.derby else 1.0) * intensity
		foul_p *= 1.0 + h.dri * 0.35
		var in_own_box := depth(s, h.pos) > 1.0 - BOX_D / L and absf(h.pos.y - W * 0.5) < BOX_HW
		if in_own_box:
			foul_p *= 0.2 # na área o zagueiro evita o contato
		if rng.randf() < foul_p:
			_foul(o, h)
			return
		var win := clampf(0.42 + (o.tck - h.dri) * 0.55 + (o.strn - h.strn) * 0.15 - (0.1 if behind else 0.0), 0.12, 0.85)
		if rng.randf() < win:
			sim.live_tackle(o.mp, h.mp, true)
			if rng.randf() < 0.55:
				owner = null
				_gain(o)
			else:
				owner = null
				last_touch = o
				last_side = o.side
				pz = {}
				bvel = Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
		else:
			sim.live_tackle(o.mp, h.mp, false)
			o.stun = 0.8
			h.vel *= 1.1
			if depth(s, h.pos) > 0.7:
				keys.append([t, 0.35])
		return


func _foul(fouler: A, victim: A) -> void:
	var s := victim.side
	owner = null
	pz = {}
	var at := victim.pos
	var in_box := depth(s, at) > 1.0 - BOX_D / L and absf(at.y - W * 0.5) < BOX_HW
	var danger := depth(s, at) > 0.7
	keys.append([t, 0.7 if in_box else (0.45 if danger else 0.2)])
	var res := sim.live_foul(fouler.mp, victim.mp, in_box, danger)
	if bool(res.get("pen", false)):
		_set_restart("pen", s, pt(s, 0.5, 1.0 - 11.0 / L))
	else:
		_set_restart("fk", s, at)
	victim.stun = 1.0


# ---------------------------------------------------------------------------
# Finalização
# ---------------------------------------------------------------------------

## xG pela geometria: distância, ângulo do gol, cabeçada e marcação em cima.
func _xg_at(sh: A, p: Vector2, header: bool) -> float:
	var s := sh.side
	var g := goal_of(s)
	var d := p.distance_to(g)
	var a1 := (g + Vector2(0, GOAL_HW) - p).angle()
	var a2 := (g - Vector2(0, GOAL_HW) - p).angle()
	var ang := absf(angle_difference(a1, a2))
	var xg := 0.92 * exp(-0.105 * d) * clampf(ang / 0.8, 0.12, 1.15)
	if header:
		xg *= 0.5
	# Marcação em volta: cada zagueiro perto fecha ângulo, apressa e tira a qualidade do chute
	var near := 99.0
	var dens := 0.0
	var to_goal := (g - p).normalized()
	for o: A in ag[1 - s]:
		if o.on and not o.gk:
			var od := o.pos.distance_to(p)
			near = minf(near, od)
			var front := 1.3 if (o.pos - p).dot(to_goal) > 0.0 else 0.7
			dens += maxf(0.0, 1.0 - od / 5.0) * front
	xg *= exp(-0.4 * dens)
	if near < 1.2:
		xg *= 0.75
	# Goleiro fora do lugar
	var k := keeper(1 - s)
	if k != null and k.pos.distance_to(own_goal(1 - s)) > 12.0 and d < 25.0 and k.pos.distance_to(p) > 5.0:
		xg *= 1.25
	return clampf(xg, 0.005, 0.8)


func _shoot(sh: A, header: bool) -> void:
	var s := sh.side
	var p := sh.pos
	var xg := _xg_at(sh, p, header)
	var ctype := _chance_type(sh, header)
	# Bloqueio: defensores entre o chute e o gol
	var g := goal_of(s)
	var block := 0.0
	for o: A in ag[1 - s]:
		if not o.on or o.gk:
			continue
		if seg_dist(o.pos, p, g) < 1.0 and o.pos.distance_to(p) < 11.0:
			block = 1.0 - (1.0 - block) * (1.0 - 0.33)
	block = minf(block, 0.6)
	var near_n := 0
	for o4: A in ag[1 - s]:
		if o4.on and not o4.gk and o4.pos.distance_to(p) < 3.0:
			near_n += 1
	shot_log.append([s, snappedf(p.distance_to(g), 0.1), snappedf(xg, 0.01), near_n, snappedf(carry_t, 0.1), header])
	var assister: A = assist_by if assist_by != null and assist_by != sh and clock - assist_t < 9.0 else null
	var k := keeper(1 - s)
	var res := sim.live_shot(s, sh.mp, assister.mp if assister != null else null, xg, ctype, block, k.mp if k != null else null, header)
	keys.append([t, 1.0 if res == "goal" else 0.8])
	owner = null
	pz = {}
	last_touch = sh
	last_side = s
	# Visual: a bola vai para o gol, para o goleiro, para fora ou no zagueiro
	var aim := g + Vector2(0.0, rng.randf_range(-GOAL_HW * 0.85, GOAL_HW * 0.85))
	match res:
		"miss":
			aim = g + Vector2(dirx(s) * 1.0, (GOAL_HW + rng.randf_range(0.6, 5.0)) * (1.0 if rng.randf() < 0.5 else -1.0))
		"post":
			aim = g + Vector2(0.0, GOAL_HW * (1.0 if rng.randf() < 0.5 else -1.0))
		"block":
			var blk := _nearest(1 - s, p.lerp(g, 0.25), true)
			aim = blk.pos if blk != null else p.lerp(g, 0.2)
		"save":
			if k != null:
				aim = k.pos.lerp(aim, 0.5)
	var dist := p.distance_to(aim)
	var spd := 26.0 if not header else 15.0
	bvel = (aim - p).normalized() * spd
	bh = 0.4 if not header else 2.0
	bvh = rng.randf_range(0.5, 3.0) if res != "miss" else rng.randf_range(1.5, 5.0)
	shot_fx = {"res": res, "t": dist / spd, "side": s, "aim": aim}
	assist_by = null


func _chance_type(sh: A, header: bool) -> int:
	if header:
		var pk := String(pz.get("kind", "")) if not pz.is_empty() else assist_kind
		return MatchSimulation.CH_CORNER if pk == "corner" else MatchSimulation.CH_CROSS
	var s := sh.side
	if clock - turnover_t < 10.0 and turnover_d < 0.5:
		return MatchSimulation.CH_COUNTER
	if sh.pos.distance_to(goal_of(s)) > 20.0:
		return MatchSimulation.CH_LONG
	if assist_kind == "through" and clock - assist_t < 6.0:
		return MatchSimulation.CH_THROUGH
	if assist_by == null or clock - assist_t > 6.0:
		return MatchSimulation.CH_DRIBBLE if carry_t > 2.0 else MatchSimulation.CH_SCRAMBLE
	return MatchSimulation.CH_THROUGH


## Fim do voo do chute (o resultado já foi decidido e contado na MatchSimulation).
func _shot_land() -> void:
	var res := String(shot_fx["res"])
	var s := int(shot_fx["side"])
	var aim: Vector2 = shot_fx["aim"]
	shot_fx = {}
	match res:
		"goal":
			ball = aim + Vector2(dirx(s) * 1.2, 0.0)
			bvel = Vector2.ZERO
			bh = 0.8
			bvh = 0.0
			dead = 7.0
			restart = {"kind": "kickoff", "side": 1 - s}
		"save":
			var k := keeper(1 - s)
			if k != null and rng.randf() < 0.72:
				ball = k.pos
				bvel = Vector2.ZERO
				bh = 0.0
				bvh = 0.0
				_gain(k)
				decide_t = 1.4
			else:
				# Rebote: a bola espirra na área (segunda bola de verdade)
				ball = aim
				bvel = Vector2(-dirx(s) * rng.randf_range(3.0, 7.0), rng.randf_range(8.0, 14.0) * (1.0 if rng.randf() < 0.5 else -1.0))
				bh = 0.3
				bvh = 1.0
				last_touch = k
				last_side = 1 - s
				if rng.randf() < 0.3:
					_set_restart("corner", s, Vector2(L - 0.3 if s == 0 else 0.3, 0.3 if aim.y < W * 0.5 else W - 0.3))
		"post":
			ball = aim
			bvel = Vector2(-dirx(s) * rng.randf_range(5.0, 12.0), rng.randf_range(-9.0, 9.0))
			bh = 0.5
			bvh = 1.5
		"block":
			ball = aim
			last_side = 1 - s
			if rng.randf() < 0.35:
				_set_restart("corner", s, Vector2(L - 0.3 if s == 0 else 0.3, 0.3 if aim.y < W * 0.5 else W - 0.3))
			else:
				bvel = Vector2(-dirx(s) * rng.randf_range(4.0, 12.0), rng.randf_range(-10.0, 10.0))
				bh = 0.2
		_:
			_set_restart("goal_kick", 1 - s, Vector2(5.5 if s == 1 else L - 5.5, W * 0.5))


# ---------------------------------------------------------------------------
# Bola parada
# ---------------------------------------------------------------------------

func _set_restart(kind: String, side: int, at: Vector2) -> void:
	owner = null
	pz = {}
	shot_fx = {}
	bvel = Vector2.ZERO
	bh = 0.0
	bvh = 0.0
	ball = _clampf_field(at) if kind != "corner" else at
	restart = {"kind": kind, "side": side, "at": ball}
	match kind:
		"throw":
			dead = rng.randf_range(4.0, 8.0)
		"goal_kick":
			dead = rng.randf_range(6.0, 10.0)
		"corner":
			dead = rng.randf_range(10.0, 15.0)
			sim.live_corner(side)
			keys.append([t, 0.5])
		"fk":
			dead = rng.randf_range(6.0, 10.0)
			if depth(side, at) > 0.72:
				dead += 8.0
				keys.append([t, 0.5])
		"pen":
			dead = 18.0
		_:
			dead = 5.0


## Durante a bola parada os jogadores vão para as posições da cobrança; ao fim, cobra.
func _dead_tick() -> void:
	dead -= DT
	var kind := String(restart.get("kind", ""))
	var s := int(restart.get("side", 0))
	var at: Vector2 = restart.get("at", ball)
	for side in 2:
		for a: A in ag[side]:
			if not a.on:
				continue
			_steer(a, _set_piece_target(a, kind, s, at), 0.55)
	if kind != "kickoff":
		ball = at
	if dead > 0.0:
		return
	restart = {}
	match kind:
		"kickoff":
			kickoff(s)
		"throw":
			var tk := _nearest(s, at, true)
			if tk != null:
				tk.pos = at
				owner = tk
				_gain(tk)
				decide_t = 0.0
		"goal_kick":
			var k := keeper(s)
			if k != null:
				k.pos = at
				_gain(k)
				decide_t = 0.2
		"corner":
			_take_corner(s, at)
		"fk":
			_take_fk(s, at)
		"pen":
			_take_pen(s)


func _set_piece_target(a: A, kind: String, s: int, at: Vector2) -> Vector2:
	if a.gk:
		return own_goal(a.side) + (at - own_goal(a.side)).normalized() * 1.5
	match kind:
		"corner", "fk":
			var near_goal := depth(s, at) > 0.72
			if near_goal and (kind == "corner" or absf(lat(s, at) - 0.5) > 0.2 or depth(s, at) < 0.8):
				# Área cheia: quem ataca entra, quem defende marca
				if a.ay > 0.3 or a.role == "CB":
					var l := 0.5 + (a.ax - 0.5) * 0.45
					var d := 0.9 + (a.ay - 0.5) * 0.06
					if a.side != s:
						d = 0.9
						return pt(s, l, clampf(d + 0.02, 0.86, 0.97))
					return pt(s, l, clampf(d, 0.83, 0.95))
			if a == _nearest(s, at, true) and a.side == s:
				return at - Vector2(dirx(s) * 0.8, 0.0)
		"pen":
			if a.side == s and a == _pen_taker_agent(s):
				return pt(s, 0.5, 1.0 - 12.0 / L)
			return pt(s, 0.5 + (a.ax - 0.5) * 0.7, 0.78)
		"throw", "goal_kick":
			if a.side == s and a == _nearest(s, at, true):
				return at
	return _formation_target(a)


func _take_corner(s: int, at: Vector2) -> void:
	var tm: MatchTeam = sim.teams[s]
	var taker := _agent_of(s, tm.by_id.get(tm.sheet.corner_taker, null) as MatchPlayer)
	if taker == null:
		taker = _nearest(s, at, true)
	if taker == null:
		return
	taker.pos = at
	# Alvo: o melhor cabeceador na área
	var tgt: A = null
	var bv := -1.0
	for a: A in ag[s]:
		if a.on and not a.gk and a != taker and depth(s, a.pos) > 0.8:
			var v := a.hed + rng.randf() * 0.3
			if v > bv:
				bv = v
				tgt = a
	var to := pt(s, 0.5 + rng.randf_range(-0.12, 0.12), 1.0 - rng.randf_range(5.0, 12.0) / L) if tgt == null else tgt.pos
	_launch(taker, to, 20.0, true, "corner", tgt)


func _take_fk(s: int, at: Vector2) -> void:
	var tm: MatchTeam = sim.teams[s]
	var dg := at.distance_to(goal_of(s))
	var central := absf(lat(s, at) - 0.5) < 0.22
	if dg < 30.0 and central:
		var fk := _agent_of(s, tm.by_id.get(tm.sheet.freekick_taker, null) as MatchPlayer)
		if fk == null:
			fk = _nearest(s, at, true)
		if fk == null:
			return
		fk.pos = at
		var xg := clampf(0.12 - (dg - 17.0) * 0.006, 0.03, 0.11)
		var k := keeper(1 - s)
		sim.live_freekick(s, fk.mp)
		var res := sim.live_shot(s, fk.mp, null, xg, MatchSimulation.CH_FREEKICK, 0.2, k.mp if k != null else null, false)
		keys.append([t, 1.0 if res == "goal" else 0.8])
		_after_set_shot(s, fk, res)
		return
	var tk := _nearest(s, at, true)
	if tk == null:
		return
	tk.pos = at
	if depth(s, at) > 0.68:
		var tgt := _best_header_in_box(s, tk)
		if tgt != null:
			_launch(tk, tgt.pos, 19.0, true, "fk_cross", tgt)
			return
	_gain(tk)
	decide_t = 0.0


func _take_pen(s: int) -> void:
	var tk := _pen_taker_agent(s)
	if tk == null:
		return
	var k := keeper(1 - s)
	var res := sim.live_penalty(s, tk.mp, k.mp if k != null else null)
	keys.append([t, 1.0])
	tk.pos = pt(s, 0.5, 1.0 - 11.0 / L)
	_after_set_shot(s, tk, res)


func _after_set_shot(s: int, sh: A, res: String) -> void:
	owner = null
	pz = {}
	last_touch = sh
	last_side = s
	var g := goal_of(s)
	var aim := g + Vector2(0.0, rng.randf_range(-GOAL_HW * 0.8, GOAL_HW * 0.8))
	if res == "miss":
		aim = g + Vector2(dirx(s), (GOAL_HW + rng.randf_range(0.5, 3.0)) * (1.0 if rng.randf() < 0.5 else -1.0))
	var dist := sh.pos.distance_to(aim)
	ball = sh.pos + Vector2(dirx(s) * 0.5, 0.0)
	bvel = (aim - ball).normalized() * 25.0
	bh = 0.3
	bvh = 2.5
	shot_fx = {"res": res if res != "wall" else "block", "t": dist / 25.0, "side": s, "aim": aim}


func _best_header_in_box(s: int, exclude: A) -> A:
	var best: A = null
	var bv := -1.0
	for a: A in ag[s]:
		if a.on and not a.gk and a != exclude and depth(s, a.pos) > 0.78:
			var v := a.hed + rng.randf() * 0.25
			if v > bv:
				bv = v
				best = a
	return best


func _launch(from: A, to: Vector2, spd: float, loft: bool, kind: String, r: A) -> void:
	owner = null
	last_touch = from
	last_side = from.side
	var err := (1.0 - from.cro) * 3.0
	to += Vector2(rng.randfn(0.0, err), rng.randfn(0.0, err))
	ball = from.pos
	bvel = (to - ball).normalized() * spd
	var tt := ball.distance_to(to) / spd
	if loft:
		bvh = 9.8 * tt * 0.5
		bh = 0.3
	pz = {"from": from, "to": r, "kind": kind, "t": clock, "off": false, "at": to}


func _agent_of(side: int, mp: MatchPlayer) -> A:
	if mp == null:
		return null
	for a: A in ag[side]:
		if a.on and a.mp == mp:
			return a
	return null


func _pen_taker_agent(s: int) -> A:
	var tm: MatchTeam = sim.teams[s]
	var a := _agent_of(s, tm.by_id.get(tm.sheet.penalty_taker, null) as MatchPlayer)
	if a != null:
		return a
	var best: A = null
	var bv := -1.0
	for o: A in ag[s]:
		if o.on and not o.gk and o.fin > bv:
			bv = o.fin
			best = o
	return best
