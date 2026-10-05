class_name MatchStats
extends RefCounted
## Estatísticas detalhadas de cada jogador numa partida (finalizações, no alvo, passes decisivos,
## desarmes, interceptações, dribles certos, defesas, % de passes e xG), calibradas pelas médias
## reais por jogo de um time (≈ 12 finalizações, 4 no alvo, 16 desarmes, 9 interceptações,
## 8 dribles certos, 80% de passes certos).
##
## O minuto a minuto conta finalizações e defesas de verdade (res["pstats"]); o modo rápido só
## tem gols e assistências, e o resto é distribuído de forma coerente com o placar, a posse, a
## função de cada um em campo e os atributos. Sempre com um gerador próprio: não mexe no mundo.

const SH := 0 # finalizações
const SO := 1 # no alvo
const KP := 2 # passes decisivos
const TK := 3 # desarmes
const IT := 4 # interceptações
const DR := 5 # dribles certos
const SV := 6 # defesas
const PP := 7 # % de passes certos (0..100)
const XG := 8 # xG × 100
const AD := 9 # duelos aéreos ganhos
const FC := 10 # faltas cometidas
const N := 11


## {player_id: [SH, SO, KP, TK, IT, DR, SV, PP, XG, AD, FC]} dos dois times.
static func build(world: GameWorld, f: Fixture, res: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, f.home, f.away, f.slot, f.hg, f.ag, "stats"])
	var poss := float(res.get("poss", 0.5))
	var real: Dictionary = res.get("pstats", {})
	var score: Array = [int(res["hg"]), int(res["ag"])]
	var out := {}
	var on_target := [0, 0]
	for side in 2:
		var lines: Array = res["lines"][side]
		var ps := poss if side == 0 else 1.0 - poss
		var g: int = score[side]
		# Finalizações do time
		var shots := 0
		var on := 0
		if not real.is_empty():
			for ln in lines:
				var e: Array = real.get((ln[QuickMatch.L_P] as Player).id, [0, 0, 0])
				shots += int(e[0])
				on += int(e[1])
		else:
			# O modo rápido conta os lances de perigo de verdade (res["sh"]); resultados antigos não.
			var sh_real: Array = res.get("sh", [])
			if sh_real.size() == 2:
				shots = maxi(g, int(sh_real[side]))
			else:
				shots = maxi(g, int(round(rng.randfn(9.5 + 2.3 * g + (ps - 0.5) * 12.0, 2.8))))
			shots = mini(shots, 32)
			on = g
			for _i in shots - g:
				if rng.randf() < 0.26:
					on += 1
		on_target[side] = on
		var rows := {}
		for ln in lines:
			var row: Array = []
			row.resize(N)
			row.fill(0)
			rows[(ln[QuickMatch.L_P] as Player).id] = row
		_shots(rng, lines, rows, real, shots, on)
		_spread(rng, lines, rows, KP, maxi(0, int(round(shots * 0.72)) - _assists(lines)), QuickMatch.L_ASSIST, true)
		for ln in lines:
			rows[(ln[QuickMatch.L_P] as Player).id][KP] += int(ln[QuickMatch.L_A])
		_spread(rng, lines, rows, TK, maxi(4, int(round(rng.randfn(16.0 + (0.5 - ps) * 10.0, 3.0)))), QuickMatch.L_DEF, false)
		_spread(rng, lines, rows, IT, maxi(2, int(round(rng.randfn(9.0 + (0.5 - ps) * 6.0, 2.5)))), QuickMatch.L_DEF, false)
		_spread(rng, lines, rows, DR, maxi(1, int(round(rng.randfn(8.0 + (ps - 0.5) * 6.0, 2.5)))), QuickMatch.L_ATT, false, true)
		# xG de cada um: parte do xG real do time (res.tac.xg) pelo que finalizou, acertou e marcou.
		var raw := {}
		var raw_sum := 0.0
		for ln in lines:
			var p: Player = ln[QuickMatch.L_P]
			var row: Array = rows[p.id]
			row[PP] = _pass_pct(rng, p, int(ln[QuickMatch.L_POS]), ps)
			var rv := (int(ln[QuickMatch.L_G]) * 0.3 + int(row[SH]) * 0.075 + int(row[SO]) * 0.06) * rng.randf_range(0.85, 1.15)
			raw[p.id] = rv
			raw_sum += rv
			out[p.id] = row
		var team_xg := raw_sum
		var tx: Array = res.get("tac", {}).get("xg", [])
		if tx.size() == 2:
			team_xg = float(tx[side])
		for ln in lines:
			var pid: int = (ln[QuickMatch.L_P] as Player).id
			out[pid][XG] = int(round(float(raw[pid]) / maxf(0.001, raw_sum) * team_xg * 100.0)) if raw_sum > 0.0 else 0
	# Defesas: o que o goleiro segurou do que foi no alvo
	for side in 2:
		var saved := maxi(0, on_target[1 - side] - score[1 - side])
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			if int(ln[QuickMatch.L_POS]) == Pos.GK:
				var e: Array = real.get(p.id, [])
				out[p.id][SV] = int(e[2]) if e.size() > 2 else saved
				saved = 0
	# Duelos aéreos ganhos (≈ 15 por time) e faltas cometidas (≈ 12, mais para quem tem menos a
	# bola). Sorteados por último para não mudar os números acima.
	for side in 2:
		var lines2: Array = res["lines"][side]
		var ps2 := poss if side == 0 else 1.0 - poss
		var rows2 := {}
		for ln in lines2:
			rows2[(ln[QuickMatch.L_P] as Player).id] = out[(ln[QuickMatch.L_P] as Player).id]
		var aw: Array = []
		var fw: Array = []
		for ln in lines2:
			var p: Player = ln[QuickMatch.L_P]
			var mf := float(ln[QuickMatch.L_MINS]) / 90.0
			var h := clampf((p.height - 168.0) / 18.0, 0.25, 1.7)
			aw.append(AERIAL_POS[int(ln[QuickMatch.L_POS])] * h * (0.4 + p.attrs[Attr.CAB] / 100.0 + p.attrs[Attr.FOR] / 250.0) * mf)
			var fv := float(ln[QuickMatch.L_FOUL])
			if fv <= 0.0:
				fv = float(ln[QuickMatch.L_DEF]) * 0.8 + 0.1
			if int(ln[QuickMatch.L_POS]) == Pos.GK:
				fv = 0.03
			fw.append(fv * (1.25 - p.attrs[Attr.DIS] / 160.0) * mf)
			# Cada cartão veio de uma falta.
			rows2[p.id][FC] += int(ln[QuickMatch.L_Y]) + (1 if bool(ln[QuickMatch.L_RED]) else 0)
		var n_air := maxi(4, int(round(rng.randfn(15.0, 4.0))))
		for _i in n_air:
			var k := RngUtil.weighted_index(rng, aw)
			if k < 0:
				break
			rows2[(lines2[k][QuickMatch.L_P] as Player).id][AD] += 1
		var n_foul := maxi(3, int(round(rng.randfn(11.5 + (0.5 - ps2) * 6.0, 3.0))))
		for ln in lines2:
			n_foul -= int(rows2[(ln[QuickMatch.L_P] as Player).id][FC])
		for _i in maxi(0, n_foul):
			var k := RngUtil.weighted_index(rng, fw)
			if k < 0:
				break
			rows2[(lines2[k][QuickMatch.L_P] as Player).id][FC] += 1
	return out


## Peso de cada posição nas bolas aéreas.
const AERIAL_POS: Array[float] = [0.25, 0.75, 1.7, 0.75, 1.1, 0.8, 0.5, 0.45, 0.45, 0.45, 0.45, 1.45]


static func _assists(lines: Array) -> int:
	var n := 0
	for ln in lines:
		n += int(ln[QuickMatch.L_A])
	return n


static func _shots(rng: RandomNumberGenerator, lines: Array, rows: Dictionary, real: Dictionary, shots: int, on: int) -> void:
	if not real.is_empty():
		for ln in lines:
			var p: Player = ln[QuickMatch.L_P]
			var e: Array = real.get(p.id, [0, 0, 0])
			rows[p.id][SH] = int(e[0])
			rows[p.id][SO] = int(e[1])
		return
	# Quem marcou finalizou (no alvo) pelo menos uma vez por gol; o resto vai pelo perfil ofensivo.
	var left_sh := shots
	var left_on := on
	for ln in lines:
		var g := int(ln[QuickMatch.L_G])
		if g > 0:
			var p: Player = ln[QuickMatch.L_P]
			rows[p.id][SH] += g
			rows[p.id][SO] += g
			left_sh -= g
			left_on -= g
	var w: Array = []
	for ln in lines:
		var p: Player = ln[QuickMatch.L_P]
		var base := float(ln[QuickMatch.L_SHOOT])
		if base <= 0.0:
			base = float(ln[QuickMatch.L_ATT]) * 0.8 + 0.08
		w.append(base * float(ln[QuickMatch.L_MINS]) / 90.0 * (0.7 + p.attrs[Attr.CHL] / 200.0))
	for _i in maxi(0, left_sh):
		var k := RngUtil.weighted_index(rng, w)
		if k < 0:
			break
		var pid: int = (lines[k][QuickMatch.L_P] as Player).id
		rows[pid][SH] += 1
		if left_on > 0 and rng.randf() < float(left_on) / maxf(1.0, float(left_sh)):
			rows[pid][SO] += 1
			left_on -= 1
		left_sh -= 1


## Espalha `total` ações entre os jogadores pelo peso da coluna (defesa, ataque ou assistência),
## pelos minutos e, nos dribles, pelo atributo de drible.
static func _spread(rng: RandomNumberGenerator, lines: Array, rows: Dictionary, key: int, total: int, col: int, assist: bool, dribble: bool = false) -> void:
	var w: Array = []
	for ln in lines:
		var p: Player = ln[QuickMatch.L_P]
		var v := float(ln[col])
		if assist and v <= 0.0:
			v = float(ln[QuickMatch.L_ATT]) * 0.6 + 0.15
		if key == TK or key == IT:
			v = float(ln[QuickMatch.L_DEF]) + 0.12
			if int(ln[QuickMatch.L_POS]) == Pos.GK:
				v = 0.02
			v *= 0.6 + (p.attrs[Attr.DES] if key == TK else p.attrs[Attr.POS]) / 150.0
		if dribble:
			v = (float(ln[QuickMatch.L_ATT]) + 0.1) * (0.3 + p.attrs[Attr.DRI] / 100.0)
			if int(ln[QuickMatch.L_POS]) == Pos.GK:
				v = 0.0
		w.append(maxf(0.0, v) * float(ln[QuickMatch.L_MINS]) / 90.0)
	for _i in total:
		var k := RngUtil.weighted_index(rng, w)
		if k < 0:
			return
		rows[(lines[k][QuickMatch.L_P] as Player).id][key] += 1


static func _pass_pct(rng: RandomNumberGenerator, p: Player, pos: int, poss: float) -> int:
	var adj := 0.0
	match Pos.group(pos):
		Pos.G_GK:
			adj = -12.0
		Pos.G_DEF:
			adj = 3.0 if pos == Pos.CB else -1.0
		Pos.G_MID:
			adj = 3.0 if pos == Pos.DM or pos == Pos.CM else -2.0
		_:
			adj = -7.0
	var v := 74.0 + (p.attrs[Attr.PAS] - 60.0) * 0.32 + (p.attrs[Attr.TEC] - 60.0) * 0.08 + (poss - 0.5) * 22.0 + adj + rng.randfn(0.0, 3.0)
	return clampi(int(round(v)), 45, 97)
