class_name MatchMaps
extends RefCounted
## Mapas da partida: de onde saíram as finalizações e onde cada time jogou.
##
## A simulação resolve o jogo minuto a minuto por estatística (quem ataca, por qual corredor, que
## tipo de jogada, quanto vale a chance), sem guardar coordenadas. Estes mapas colocam cada lance
## no campo a partir do que a simulação registrou, com as mesmas regras que o campo 2D usa para
## encenar a jogada (PitchMotion): pênalti na marca, falta de fora da área, cabeçada na pequena
## área, chute de longe da intermediária, e o corredor (esquerda, meio, direita) em que a jogada
## aconteceu. O espalhamento é fixo por lance (sem sorteio): o mapa não muda ao reabrir.
##
## Coordenadas em metros, campo de 105 × 68. O mandante ataca para a direita (x = 105) e o
## visitante para a esquerda, nos dois tempos (os mapas não trocam de lado no intervalo).

const L := 105.0
const W := 68.0
## Grade do mapa de calor (células de ~5 m).
const GX := 21
const GY := 14

const SHOT_EVENTS: Array[int] = [MatchSimulation.EV_GOAL, MatchSimulation.EV_SAVE, MatchSimulation.EV_MISS,
	MatchSimulation.EV_POST, MatchSimulation.EV_BLOCK, MatchSimulation.EV_PEN_SAVE, MatchSimulation.EV_PEN_MISS]
## Distância do gol (m) de cada zona de finalização da simulação (MatchSimulation.shot_zone):
## pequena área, dentro da área, entrada da área, de longe.
const ZONE_RANGE: Array = [[2.5, 6.5], [6.5, 16.0], [15.0, 22.5], [23.0, 33.0]]
const LANE_L: Array[float] = [0.24, 0.5, 0.76]


## Profundidade/lateral na visão de quem ataca → metros (mandante ataca para a direita).
static func to_pitch(side: int, d: float, l: float) -> Vector2:
	if side == 0:
		return Vector2(d * L, l * W)
	return Vector2((1.0 - d) * L, (1.0 - l) * W)


static func result_of(t: int) -> String:
	match t:
		MatchSimulation.EV_GOAL:
			return "goal"
		MatchSimulation.EV_SAVE, MatchSimulation.EV_PEN_SAVE:
			return "save"
		MatchSimulation.EV_POST:
			return "post"
		MatchSimulation.EV_BLOCK:
			return "block"
	return "miss"


## Finalizações até o fim do tempo `max_half` (1 = primeiro tempo, 2 = jogo, 4 = com prorrogação):
## [{s, pos, xg, res, m, h, p, pen}], na ordem em que aconteceram. Gol anulado não entra.
static func shots(events: Array, max_half: int = 99) -> Array:
	var out: Array = []
	for i in events.size():
		var ev: Dictionary = events[i]
		var t := int(ev["t"])
		if not t in SHOT_EVENTS or int(ev["h"]) > max_half:
			continue
		var x: Dictionary = ev.get("x", {})
		if String(x.get("fin", "")) == "var_off":
			continue
		var s := int(ev["s"])
		var ct := int(x.get("ct", MatchSimulation.CH_THROUGH))
		var xg := float(x.get("xg", 0.08))
		var pid := int(ev.get("p", -1))
		var key := int(ev["m"]) * 131 + int(ev["h"]) * 7919 + i
		var zone := int(x.get("zone", MatchSimulation.shot_zone(ct, xg)))
		var dl := _shot_spot(ct, int(x.get("ln", -1)), zone, String(x.get("body", "")) == "head", key, pid)
		out.append({"s": s, "pos": to_pitch(s, dl.x, dl.y), "xg": xg, "res": result_of(t), "m": int(ev["m"]), "h": int(ev["h"]),
			"p": pid, "pen": ct == MatchSimulation.CH_PENALTY})
	return out


## [profundidade, lateral] de uma finalização, na visão de quem ataca. A faixa de distância é a
## zona que a simulação já deu ao lance (a mesma da narração e do campo 2D).
static func _shot_spot(ct: int, ln: int, zone: int, head: bool, key: int, pid: int) -> Vector2:
	if ct == MatchSimulation.CH_PENALTY:
		return Vector2(1.0 - 11.0 / L, 0.5)
	var rg: Array = ZONE_RANGE[clampi(zone, 0, 3)]
	var u := RngUtil.noise(key, pid, 11) * 0.5 + 0.5
	var dist := lerpf(float(rg[0]), float(rg[1]), u)
	if head:
		dist = minf(dist, 5.0 + u * 7.5) # ninguém cabeceia da meia-lua
	var lat := 0.5
	if ln >= 0:
		# De perto todo mundo finaliza de frente para o gol; de longe o corredor aparece mais.
		var spread := clampf(dist / 18.0, 0.3, 1.0)
		lat = 0.5 + (LANE_L[clampi(ln, 0, 2)] - 0.5) * spread
	if ct == MatchSimulation.CH_CROSS or ct == MatchSimulation.CH_CORNER or ct == MatchSimulation.CH_SCRAMBLE:
		lat = 0.5 + (lat - 0.5) * 0.45 # bola na área: a conclusão é na frente do gol
	lat += RngUtil.noise(key, pid, 23) * (0.05 + dist * 0.005)
	return Vector2(1.0 - dist / L, clampf(lat, 0.08, 0.92))


## Mapa de calor dos dois times até o fim do tempo `max_half`: [grade do mandante, grade do
## visitante], cada uma com GX × GY valores de 0 a 1 (linha a linha, de cima para baixo).
## Entra: o avanço de cada minuto de posse (até onde o time chegou e por qual corredor), cada
## lance com jogador (na zona do jogador, pela formação) e as finalizações.
static func heat(sim: MatchSimulation, max_half: int = 99) -> Array:
	var grids: Array = [PackedFloat32Array(), PackedFloat32Array()]
	for g: PackedFloat32Array in grids:
		g.resize(GX * GY)
	# 1. Território: um registro por minuto, com o lado que teve a bola e o perigo que levou.
	for i in sim.pressure.size():
		var pr: Array = sim.pressure[i]
		if int(pr[0]) > max_half:
			continue
		var v := float(pr[2])
		var s := 0 if v >= 0.0 else 1
		var danger := absf(v)
		var d := (danger - 0.1) / 0.3 + 0.08 if danger < 0.29 else 0.62 + (danger - 0.3) * 0.45
		d = clampf(d, 0.2, 0.95)
		var key := int(pr[0]) * 977 + int(pr[1]) * 37 + i
		var lat := LANE_L[_lane(sim.teams[s], key)] + RngUtil.noise(key, s, 5) * 0.1
		# A jogada sobe o campo: marca o caminho, mais forte onde ela chegou.
		_stamp(grids[s], to_pitch(s, d - 0.24, 0.5 + (lat - 0.5) * 0.6), 0.35)
		_stamp(grids[s], to_pitch(s, d - 0.11, 0.5 + (lat - 0.5) * 0.85), 0.6)
		_stamp(grids[s], to_pitch(s, d, lat), 1.0)
	# 2. Lances com jogador: na zona dele em campo.
	for ev: Dictionary in sim.events:
		if int(ev["h"]) > max_half:
			continue
		var t := int(ev["t"])
		var s2 := int(ev["s"])
		if s2 < 0 or t in SHOT_EVENTS:
			continue
		if t in [MatchSimulation.EV_POSSESSION, MatchSimulation.EV_SKILL, MatchSimulation.EV_TACKLE, MatchSimulation.EV_KEEPER,
				MatchSimulation.EV_FOUL, MatchSimulation.EV_OFFSIDE]:
			var at: Variant = _player_zone(sim.teams[s2], int(ev.get("p", -1)))
			if at != null:
				_stamp(grids[s2], at, 0.55)
		elif t == MatchSimulation.EV_CORNER:
			var left := RngUtil.noise(int(ev["m"]), int(ev["h"]), 3) < 0.0
			_stamp(grids[s2], to_pitch(s2, 0.985, 0.03 if left else 0.97), 0.6)
	# 3. Finalizações.
	for sh: Dictionary in shots(sim.events, max_half):
		_stamp(grids[int(sh["s"])], sh["pos"], 0.9)
	for g2: PackedFloat32Array in grids:
		var mx := 0.0
		for v2 in g2:
			mx = maxf(mx, v2)
		if mx > 0.0:
			for k in g2.size():
				# Raiz: as zonas de passagem aparecem, sem a área dominar o mapa inteiro.
				g2[k] = sqrt(g2[k] / mx)
	return grids


## Corredor do minuto: os lados em que o time ataca mais (MatchTeam.lane_att) recebem mais jogadas.
static func _lane(team: MatchTeam, key: int) -> int:
	var w: Array = [0.28, 0.44, 0.28]
	var tot := 0.0
	for l in 3:
		w[l] = float(w[l]) * maxf(0.2, team.lane_att[l])
		tot += float(w[l])
	var r := (RngUtil.noise(key, 17, 3) * 0.5 + 0.5) * tot
	for l in 3:
		r -= float(w[l])
		if r <= 0.0:
			return l
	return 1


## Zona de um jogador em campo, pela vaga dele na formação (null se já saiu).
static func _player_zone(team: MatchTeam, pid: int) -> Variant:
	if pid < 0:
		return null
	var mp: MatchPlayer = team.by_id.get(pid, null)
	if mp == null or mp.slot < 0:
		return null
	var slots: Array = team.formation.get("slots", [])
	if mp.slot >= slots.size():
		return null
	var s: Dictionary = slots[mp.slot]
	var fy := float(s.get("y", 0.3))
	return to_pitch(team.side, clampf(0.08 + fy * 0.74, 0.03, 0.9), clampf(float(s.get("x", 0.5)), 0.05, 0.95))


## Soma uma mancha (3 × 3 células, mais forte no centro) na grade.
static func _stamp(grid: PackedFloat32Array, at: Vector2, weight: float) -> void:
	var cx := clampi(int(at.x / L * GX), 0, GX - 1)
	var cy := clampi(int(at.y / W * GY), 0, GY - 1)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cx + dx
			var y := cy + dy
			if x < 0 or y < 0 or x >= GX or y >= GY:
				continue
			grid[y * GX + x] += weight * (1.0 if dx == 0 and dy == 0 else (0.45 if dx == 0 or dy == 0 else 0.25))
