class_name MatchSimulation
extends RefCounted
## Simulação estatística minuto a minuto. Incremental: a UI pode chamar step() aos poucos,
## pausar, substituir e mudar a tática; o resultado continua coerente.
##
## Modelo: tudo é comparado em "pontos de rating" com curvas exponenciais suaves.
## Uma diferença de ~11 pontos entre times dá ~2,2× mais gols esperados ao melhor;
## ~30 pontos (1ª × 4ª divisão) dá ~9×: zebras raras, mas possíveis.

# --- Tipos de evento ---
const EV_KICKOFF := 0
const EV_HALFTIME := 1
const EV_FULLTIME := 2
const EV_GOAL := 3
const EV_SAVE := 4
const EV_MISS := 5
const EV_POST := 6
const EV_BLOCK := 7
const EV_FOUL := 8
const EV_YELLOW := 9
const EV_RED := 10
const EV_INJURY := 11
const EV_SUB := 12
const EV_OFFSIDE := 13
const EV_CORNER := 14
const EV_PEN_MISS := 15
const EV_PEN_SAVE := 16
const EV_POSSESSION := 17
const EV_SECOND_HALF := 18
const EV_TACTIC := 19
const EV_FREEKICK := 20
const EV_PENALTY_AWARDED := 21
const EV_OWN_GOAL := 22
const EV_EXTRA_TIME := 23 # início da prorrogação (pausa na UI)
const EV_ET_SECOND := 24 # segundo tempo da prorrogação
const EV_SHOOTOUT := 25 # início da disputa de pênaltis
const EV_SHOOT_KICK := 26 # cobrança na disputa: x = {ok, n, ps}

# --- Tipos de chance ---
const CH_THROUGH := 0
const CH_CROSS := 1
const CH_LONG := 2
const CH_DRIBBLE := 3
const CH_COUNTER := 4
const CH_SCRAMBLE := 5
const CH_CORNER := 6
const CH_FREEKICK := 7
const CH_PENALTY := 8
const CH_ERROR := 9
const CH_KEYS: Array[String] = ["through", "cross", "long", "dribble", "counter", "scramble"]
const BASE_TYPE_W: Array[float] = [0.26, 0.22, 0.18, 0.14, 0.10, 0.10]
const BASE_XG: Array[float] = [0.155, 0.088, 0.032, 0.11, 0.19, 0.13, 0.07, 0.065, 0.76, 0.3]

# --- Modos de escolha de jogador ---
const PK_SHOOT := 0
const PK_HEAD := 1
const PK_LONG := 2
const PK_DRIBBLE := 3
const PK_COUNTER := 4
const PK_PASS := 5
const PK_CROSS := 6
const PK_MID := 7
const PK_DEFEND := 8

# --- Calibração (ver tests/season_simulator.gd) ---
const BASE_CHANCE := 0.178 # prob. de chance por minuto de posse, times iguais
const BETA := 0.0118 # sensibilidade da taxa de chances à diferença ATA×DEF (por ponto)
const GAMMA := 0.0128 # sensibilidade da posse à diferença de meio-campo (por ponto)
const DELTA := 0.003 # sensibilidade da qualidade da chance
const EPS := 0.003 # finalizador × goleiro
const HOME_CHANCE := 0.12 # empurrão da torcida na taxa de chances do mandante
const AWAY_CHANCE := 0.06 # pressão sobre o visitante
const FOUL_RATE := 0.235
const INJURY_RATE := 0.0014
const FATIGUE_RATE := 0.17
## Janelas de substituição automática: minutos 60, 68, 76 e 84 (ver _ai_decisions).

var rng := RandomNumberGenerator.new()
## Sorteios só de apresentação (posição da bola, lances sem perigo): usar um gerador separado
## garante que assistir à partida (detail) nunca muda o resultado em relação ao instantâneo.
var vis_rng := RandomNumberGenerator.new()
var detail: bool = false
var teams: Array[MatchTeam] = [] # [casa, fora]
var minute: int = 0
var half: int = 1
var started: bool = false
var finished: bool = false
var halftime_pending: bool = false
var stoppage: Array[int] = [0, 0, 0, 0]
## Mata-mata: `agg` são os gols das partidas anteriores do confronto ([mandante, visitante] deste jogo).
## Empate no agregado ao fim do tempo normal → prorrogação (half 3 e 4) → pênaltis.
var knockout: bool = false
var agg: Array[int] = [0, 0]
var et_pending: bool = false
var shootout: bool = false
var pen_score: Array[int] = [0, 0]
var pen_taken: Array[int] = [0, 0]
var _pen_order: Array = [[], []]
var events: Array = []
var score: Array[int] = [0, 0]
var momentum: Array[float] = [0.0, 0.0]
var trailed: Array[bool] = [false, false]
var half_events: int = 0
var derby: bool = false
var importance: float = 0.3
var neutral: bool = false
var attendance: int = 0
var competition: String = "L"
## Última fase de jogo (para a animação 2D): lado com a bola, zona inicial/final (0..1) e evento.
var last_phase: Dictionary = {}
var last_events: Array = []
var year: int = 2026
var crowd: float = 0.8
# Cópias locais das tabelas (acesso sem contenção quando várias partidas rodam em threads)
var _type_w: PackedFloat32Array = PackedFloat32Array(BASE_TYPE_W)
var _xg: PackedFloat32Array = PackedFloat32Array(BASE_XG)
# Taxas cacheadas (recalculadas quando setores/táticas mudam)
var _rate_chance: Array[float] = [0.2, 0.2]
var _rate_foul: Array[float] = [0.2, 0.2]
var _rate_off: Array[float] = [0.03, 0.03]
var _rate_corner: Array[float] = [0.04, 0.04]
var _poss_base: float = 0.5


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

func setup(world: GameWorld, home: Club, away: Club, home_sheet: TeamSheet, away_sheet: TeamSheet, ctx: Dictionary, seed_value: int, with_detail: bool) -> void:
	rng.seed = seed_value
	vis_rng.seed = seed_value ^ 0x5bd1e995
	detail = with_detail
	year = world.year
	derby = ctx.get("derby", false)
	importance = ctx.get("importance", 0.3)
	neutral = ctx.get("neutral", false)
	attendance = ctx.get("attendance", 0)
	competition = ctx.get("competition", "L")
	knockout = bool(ctx.get("ko", false))
	var ag: Array = ctx.get("agg", [0, 0])
	agg = [int(ag[0]), int(ag[1])]
	teams = [
		_build_team(world, 0, home, home_sheet),
		_build_team(world, 1, away, away_sheet),
	]
	crowd = 0.0 if neutral else 0.6 + 0.4 * clampf(float(attendance) / maxf(1.0, home.capacity), 0.0, 1.0)
	var adv := float(DatabaseManager.tactics().get("home_advantage", 0.05))
	teams[0].home_f = 1.0 + adv * crowd * 0.5
	teams[1].home_f = 1.0
	for t: MatchTeam in teams:
		t.refresh_tactics()
		t.recompute_units()
	_refresh_rates()


func _build_team(world: GameWorld, side: int, club: Club, sheet: TeamSheet) -> MatchTeam:
	var t := MatchTeam.new()
	t.side = side
	t.club = club
	t.sheet = sheet
	t.formation = DatabaseManager.formation(sheet.formation)
	t.max_subs = int(DatabaseManager.squad_rules()["max_subs"])
	t.is_user = world.is_user_club(club.id)
	t.auto_subs = sheet.auto_subs if t.is_user else true
	t.mentality = sheet.mentality
	t.base_mentality = sheet.mentality
	t.style = sheet.style
	t.intensity = sheet.intensity
	t.line = sheet.line
	t.pressing = sheet.pressing
	t.cohesion_f = 0.96 + clampf(club.cohesion, 0.0, 100.0) / 100.0 * 0.08
	var norms := DatabaseManager.formation_norms()
	t.norm_def = float(norms["def"])
	t.norm_mid = float(norms["mid"])
	t.norm_att = float(norms["att"])
	var big := derby or importance >= 0.7
	var fslots: Array = t.formation["slots"]
	for i in fslots.size():
		var pid: int = sheet.starters[i] if i < sheet.starters.size() and sheet.starters[i] != null else -1
		var pl: Player = world.player(pid)
		if pl == null:
			t.slots.append(null)
			continue
		var mp := _make_mp(pl, big)
		_assign_slot(mp, i, fslots[i])
		mp.on_pitch = true
		mp.used = true
		mp.start_min = 0
		t.slots.append(mp)
		t.all.append(mp)
		t.by_id[pl.id] = mp
	for pid in sheet.bench:
		var pl: Player = world.player(pid)
		if pl == null or t.by_id.has(pid):
			continue
		var mp := _make_mp(pl, big)
		t.bench.append(mp)
		t.all.append(mp)
		t.by_id[pid] = mp
	return t


func _make_mp(pl: Player, big: bool) -> MatchPlayer:
	var mp := MatchPlayer.new()
	mp.p = pl
	mp.cond = pl.condition
	var sigma := 0.015 + (20 - pl.consistency) * 0.0025
	mp.perf = clampf(rng.randfn(1.0, sigma), 0.86, 1.14)
	mp.ctx = 1.0 + (pl.trait_sum("big_game") if big else 0.0)
	mp.card_mult = pl.trait_mult("card_mult")
	mp.clutch = pl.trait_sum("clutch")
	mp.injury_f = (1.0 + pl.injury_prone / 10.0) * pl.trait_mult("injury_mult")
	mp.prepare()
	return mp


func _assign_slot(mp: MatchPlayer, i: int, s: Dictionary) -> void:
	mp.slot = i
	mp.pos = s["pos"]
	mp.role = s["role"]
	mp.w_def = s["def"]
	mp.w_mid = s["mid"]
	mp.w_att = s["att"]
	mp.w_wide = s["wide"]
	mp.fam = Pos.familiarity(mp.p.position, mp.p.secondary, mp.pos)
	mp.slot_rating = mp.p.rating_at(mp.pos)


# ---------------------------------------------------------------------------
# Laço principal
# ---------------------------------------------------------------------------

func run_to_end() -> void:
	var guard := 0
	while not finished and guard < 400:
		step()
		guard += 1


## Avança um minuto. Retorna os eventos gerados neste passo.
func step() -> Array:
	if detail or not last_events.is_empty():
		last_events = []
	if finished:
		return last_events
	if not started:
		started = true
		_emit(EV_KICKOFF, 0, -1)
		if detail:
			last_phase = {"side": 0, "from": 0.5, "to": 0.5, "ev": EV_KICKOFF}
		return last_events
	if halftime_pending:
		halftime_pending = false
		half = 2
		minute = 45
		half_events = 0
		for t: MatchTeam in teams:
			for mp: MatchPlayer in t.slots:
				if mp != null:
					mp.cond = minf(100.0, mp.cond + 4.0) # o intervalo recupera um pouco
			t.recompute_units()
		_refresh_rates()
		_emit(EV_SECOND_HALF, 1, -1)
		if detail:
			last_phase = {"side": 1, "from": 0.5, "to": 0.5, "ev": EV_SECOND_HALF}
		return last_events
	if et_pending:
		et_pending = false
		half = 3
		minute = 90
		half_events = 0
		for t: MatchTeam in teams:
			if t.max_subs < 6:
				t.max_subs += 1 # a prorrogação libera uma troca extra
			for mp: MatchPlayer in t.slots:
				if mp != null:
					mp.cond = minf(100.0, mp.cond + 3.0)
			t.recompute_units()
		_refresh_rates()
		_emit(EV_EXTRA_TIME, 0, -1)
		if detail:
			last_phase = {"side": 0, "from": 0.5, "to": 0.5, "ev": EV_EXTRA_TIME}
		return last_events
	if shootout:
		_shootout_kick()
		return last_events
	minute += 1
	_simulate_minute()
	if half == 1 and minute == 45:
		stoppage[0] = clampi(1 + int(round(half_events * 0.35)), 1, 5)
	if half == 2 and minute == 90:
		stoppage[1] = clampi(2 + int(round(half_events * 0.3)), 2, 8)
	if half == 3 and minute == 105:
		stoppage[2] = 1
	if half == 4 and minute == 120:
		stoppage[3] = clampi(1 + int(round(half_events * 0.2)), 1, 3)
	if half == 1 and stoppage[0] > 0 and minute >= 45 + stoppage[0]:
		_emit(EV_HALFTIME, -1, -1)
		halftime_pending = true
	elif half == 2 and stoppage[1] > 0 and minute >= 90 + stoppage[1]:
		if _needs_decision():
			et_pending = true
			_emit(EV_HALFTIME, -1, -1, -1, {"et": true})
		else:
			_finish()
	elif half == 3 and stoppage[2] > 0 and minute >= 105 + stoppage[2]:
		half = 4
		minute = 105
		_emit(EV_ET_SECOND, 1, -1)
	elif half == 4 and stoppage[3] > 0 and minute >= 120 + stoppage[3]:
		if _needs_decision():
			_start_shootout()
		else:
			_finish()
	return last_events


## Mata-mata empatado no agregado (considera as partidas anteriores do confronto).
func _needs_decision() -> bool:
	return knockout and score[0] + agg[0] == score[1] + agg[1]


func is_extra_time() -> bool:
	return half >= 3


# ---------------------------------------------------------------------------
# Disputa de pênaltis (uma cobrança por passo, para a UI acompanhar)
# ---------------------------------------------------------------------------

func _start_shootout() -> void:
	shootout = true
	pen_score = [0, 0]
	pen_taken = [0, 0]
	for side in 2:
		var t: MatchTeam = teams[side]
		var kickers: Array = []
		for mp: MatchPlayer in t.slots:
			if mp != null and mp.on_pitch:
				kickers.append(mp)
		kickers.sort_custom(func(a, b): return _pen_skill(a) > _pen_skill(b))
		# O goleiro bate por último.
		kickers.sort_custom(func(a, b): return (1 if a.slot == 0 else 0) < (1 if b.slot == 0 else 0))
		_pen_order[side] = kickers
	_emit(EV_SHOOTOUT, 0, -1, -1, {"ps": [0, 0]})


func _pen_skill(mp: MatchPlayer) -> float:
	return mp.attr(Attr.FIN) * 0.6 + mp.attr(Attr.DEC) * 0.3 + mp.attr(Attr.INT) * 0.1 + mp.clutch * 20.0


func _shootout_kick() -> void:
	var side := 0 if pen_taken[0] == pen_taken[1] else 1
	var order: Array = _pen_order[side]
	if order.is_empty():
		_end_shootout()
		return
	var kicker: MatchPlayer = order[pen_taken[side] % order.size()]
	var gk := teams[1 - side].goalkeeper()
	var gk_val := gk.gk_comp() * gk.f if gk != null else 20.0
	var p := clampf(0.76 + (kicker.finishing() * kicker.f - gk_val) * 0.004 + kicker.clutch * 0.05, 0.55, 0.9)
	if pen_taken[side] >= 5:
		p -= 0.03 # alternadas: pressão máxima
	var ok := rng.randf() < p
	pen_taken[side] += 1
	if ok:
		pen_score[side] += 1
		kicker.rating_pts += 0.1
	else:
		kicker.rating_pts -= 0.4
		if gk != null:
			gk.rating_pts += 0.35
	_emit(EV_SHOOT_KICK, side, kicker.p.id, gk.p.id if gk != null else -1, {"ok": ok, "n": pen_taken[side], "ps": [pen_score[0], pen_score[1]]})
	# Decidido?
	var a := pen_taken[0]
	var b := pen_taken[1]
	if a <= 5 and b <= 5:
		var left_a := 5 - a
		var left_b := 5 - b
		if pen_score[0] > pen_score[1] + left_b or pen_score[1] > pen_score[0] + left_a:
			_end_shootout()
	elif a == b and pen_score[0] != pen_score[1]:
		_end_shootout()


func _end_shootout() -> void:
	shootout = false
	_finish()


## Vencedor do jogo decisivo (0 mandante, 1 visitante, -1 sem decisão): agregado e pênaltis.
func decided_winner() -> int:
	var h := score[0] + agg[0]
	var a := score[1] + agg[1]
	if h != a:
		return 0 if h > a else 1
	if pen_score[0] != pen_score[1]:
		return 0 if pen_score[0] > pen_score[1] else 1
	return -1


func is_halftime_pause() -> bool:
	return halftime_pending or et_pending


func display_minute() -> String:
	return Fmt.minute(minute, half)


func _simulate_minute() -> void:
	momentum[0] *= 0.88
	momentum[1] *= 0.88
	if minute % 5 == 0:
		for t: MatchTeam in teams:
			_apply_fatigue(t, 5.0)
		if minute % 10 == 0:
			for t: MatchTeam in teams:
				t.recompute_units()
			_refresh_rates()
	_ai_decisions()
	var poss := clampf(_poss_base + (momentum[0] - momentum[1]) * 0.15, 0.25, 0.75)
	var s := 0 if rng.randf() < poss else 1
	var att: MatchTeam = teams[s]
	var dfn: MatchTeam = teams[1 - s]
	att.poss_ticks += 1
	var p_chance := clampf(_rate_chance[s] * (1.0 + momentum[s]), 0.02, 0.6)
	var p_foul := _rate_foul[1 - s]
	var p_off := _rate_off[s]
	var p_corner := _rate_corner[s]
	var r := rng.randf()
	if r < p_chance:
		_resolve_chance(att, dfn, -1)
	elif r < p_chance + p_foul:
		_resolve_foul(att, dfn)
	elif r < p_chance + p_foul + p_off:
		_offside(att)
	elif r < p_chance + p_foul + p_off + p_corner:
		_corner(att, dfn)
	elif detail:
		var z0 := vis_rng.randf_range(0.25, 0.55)
		last_phase = {"side": s, "from": z0, "to": clampf(z0 + vis_rng.randf_range(-0.1, 0.25), 0.1, 0.8), "ev": -1}
		if vis_rng.randf() < 0.22:
			var carrier := _pick_weighted(att, PK_MID, vis_rng)
			_emit(EV_POSSESSION, s, carrier.p.id if carrier != null else -1)
	for t: MatchTeam in teams:
		if rng.randf() < INJURY_RATE * t.i_fatigue:
			_injury(t, _pick_injury_victim(t))


## Recalcula as probabilidades por minuto (chamado quando setores ou táticas mudam).
func _refresh_rates() -> void:
	var h: MatchTeam = teams[0]
	var a: MatchTeam = teams[1]
	var tilt_h := h.m_poss + h.s_poss + h.l_poss + (0.0 if a.s_ignores_press else h.pr_poss)
	var tilt_a := a.m_poss + a.s_poss + a.l_poss + (0.0 if h.s_ignores_press else a.pr_poss)
	var x := GAMMA * (h.u_mid - a.u_mid)
	_poss_base = clampf(1.0 / (1.0 + exp(-x)) + (tilt_h - tilt_a) * 0.8 + 0.02 * crowd, 0.25, 0.75)
	for s in 2:
		var att: MatchTeam = teams[s]
		var dfn: MatchTeam = teams[1 - s]
		_rate_chance[s] = _chance_prob(att, dfn)
		_rate_foul[s] = _foul_prob(att)
		var direct := att.style == TeamSheet.STYLE_DIRETO or att.style == TeamSheet.STYLE_CONTRA or att.style == TeamSheet.STYLE_LONGA
		_rate_off[s] = 0.028 * dfn.l_offside * (1.25 if direct else 1.0)
		_rate_corner[s] = 0.04 * clampf(0.6 + att.width / 4.0, 0.6, 1.5)


func _att_power(t: MatchTeam) -> float:
	return t.u_att * t.m_att * (1.0 + t.style_fit)


func _def_power(t: MatchTeam) -> float:
	return t.u_def * t.m_def


func _chance_prob(att: MatchTeam, dfn: MatchTeam) -> float:
	var p := BASE_CHANCE * exp(BETA * (_att_power(att) - _def_power(dfn)))
	p *= att.s_rate
	# Contra-ataque rende mais contra times que se lançam.
	if att.style == TeamSheet.STYLE_CONTRA and (dfn.mentality >= 3 or dfn.style == TeamSheet.STYLE_POSSE or dfn.style == TeamSheet.STYLE_PRESSAO):
		p *= 1.0 + att.s_vs_open
	# Jogo pelos lados contra formação estreita.
	if att.style == TeamSheet.STYLE_LADOS and dfn.width < 2.0:
		p *= 1.0 + att.s_vs_narrow
	p *= dfn.l_opp_rate * dfn.pr_opp_rate
	p *= 1.0 + HOME_CHANCE * crowd if att.side == 0 else 1.0 - AWAY_CHANCE * crowd
	# Time com menos jogadores sofre mais.
	p *= 1.0 + (11 - dfn.on_pitch_count) * 0.08
	p *= 1.0 - (11 - att.on_pitch_count) * 0.06
	return clampf(p, 0.02, 0.6)


func _foul_prob(dfn: MatchTeam) -> float:
	var p := FOUL_RATE * dfn.i_fouls * dfn.pr_fouls * (1.3 - dfn.discipline / 100.0 * 0.6)
	if derby:
		p *= 1.12
	return clampf(p, 0.05, 0.45)


## Fadiga aplicada em blocos de `minutes` minutos (barato e suficiente).
func _apply_fatigue(t: MatchTeam, minutes: float) -> void:
	var mult: float = FATIGUE_RATE * minutes * t.i_fatigue * t.s_fatigue * t.pr_fatigue
	for mp: MatchPlayer in t.slots:
		if mp == null:
			continue
		var gk_f := 0.35 if mp.slot == 0 else 1.0
		mp.cond = maxf(5.0, mp.cond - mult * (1.25 - mp.a_res / 100.0 * 0.6) * gk_f)


# ---------------------------------------------------------------------------
# Chances e gols
# ---------------------------------------------------------------------------

func _pick_chance_type(att: MatchTeam, dfn: MatchTeam) -> int:
	var w: Array = []
	for i in 6:
		var v: float = _type_w[i] * att.s_types[i]
		match i:
			CH_CROSS:
				v *= clampf(0.5 + att.width / 4.0, 0.5, 1.6)
			CH_COUNTER:
				v *= clampf(0.6 + att.pace_att / 150.0, 0.7, 1.4) * (1.0 + maxf(0.0, dfn.mentality - 2) * 0.35)
				if dfn.line == 2:
					v *= 1.15
			CH_THROUGH:
				if dfn.line == 2:
					v *= 1.1
			CH_LONG:
				if dfn.line == 0:
					v *= 1.25
		w.append(v)
	return RngUtil.weighted_index(rng, w)


## Escolhe um jogador de campo ponderando por papel e atributo (tabelas pré-calculadas no time).
func _pick_weighted(t: MatchTeam, mode: int, gen: RandomNumberGenerator = null) -> MatchPlayer:
	var total: float = t.pick_total[mode]
	if total <= 0.0:
		return null
	var arr: PackedFloat32Array = t.pick_w[mode]
	var r := (gen if gen != null else rng).randf() * total
	for i in arr.size():
		var v := arr[i]
		if v <= 0.0:
			continue
		r -= v
		if r <= 0.0:
			return t.slots[i]
	for i in range(arr.size() - 1, -1, -1):
		if arr[i] > 0.0:
			return t.slots[i]
	return null


func _pick_assister(att: MatchTeam, ctype: int, shooter: MatchPlayer) -> MatchPlayer:
	var mode := PK_PASS
	var chance_assist := 0.75
	match ctype:
		CH_CROSS, CH_CORNER:
			mode = PK_CROSS
			chance_assist = 0.9
		CH_DRIBBLE:
			chance_assist = 0.3
		CH_LONG:
			chance_assist = 0.45
		CH_SCRAMBLE:
			chance_assist = 0.35
		CH_COUNTER:
			chance_assist = 0.7
		CH_ERROR, CH_FREEKICK, CH_PENALTY:
			chance_assist = 0.0
	if rng.randf() >= chance_assist:
		return null
	for _i in 4:
		var a := _pick_weighted(att, mode)
		if a != null and a != shooter:
			return a
	return null


## Resolve uma chance do time `att`. forced_type >= 0 força o tipo (escanteio, falta, pênalti).
func _resolve_chance(att: MatchTeam, dfn: MatchTeam, forced_type: int, forced_shooter: MatchPlayer = null) -> void:
	var s := att.side
	var ctype := forced_type
	# Erro defensivo: zaga indecisa entrega a bola.
	if ctype < 0 and rng.randf() < 0.04 * clampf((75.0 - dfn.avg_decision) / 25.0 + 0.6, 0.4, 1.6):
		ctype = CH_ERROR
	if ctype < 0:
		ctype = _pick_chance_type(att, dfn)
	var shooter: MatchPlayer = forced_shooter
	if shooter == null:
		match ctype:
			CH_CROSS, CH_CORNER:
				shooter = _pick_weighted(att, PK_HEAD)
			CH_LONG, CH_FREEKICK:
				shooter = _pick_weighted(att, PK_LONG)
			CH_DRIBBLE:
				shooter = _pick_weighted(att, PK_DRIBBLE)
			CH_COUNTER:
				shooter = _pick_weighted(att, PK_COUNTER)
			_:
				shooter = _pick_weighted(att, PK_SHOOT)
	if shooter == null:
		return
	var assister := _pick_assister(att, ctype, shooter)
	var culprit: MatchPlayer = null
	if ctype == CH_ERROR:
		culprit = _pick_weighted(dfn, PK_DEFEND)
	# Qualidade da chance
	var xg: float = _xg[ctype]
	if ctype != CH_PENALTY and ctype != CH_FREEKICK:
		xg *= clampf(exp(DELTA * (_att_power(att) - _def_power(dfn))), 0.6, 1.6)
		xg *= att.s_quality * dfn.l_opp_quality
		# Linha alta sofre com atacantes rápidos.
		if dfn.line == 2 and (ctype == CH_THROUGH or ctype == CH_COUNTER):
			xg *= 1.0 + clampf((att.pace_att - dfn.pace_def) / 100.0, 0.0, 0.25)
		# O jogo aéreo decide cruzamentos e escanteios.
		if ctype == CH_CROSS or ctype == CH_CORNER:
			xg *= clampf(exp(0.012 * (att.aerial_att - dfn.aerial_def)), 0.7, 1.4)
	var skill: float
	match ctype:
		CH_CROSS, CH_CORNER:
			skill = shooter.heading()
		CH_LONG, CH_FREEKICK:
			skill = shooter.long_shot()
		_:
			skill = shooter.finishing()
	skill *= shooter.f
	if shooter.clutch > 0.0 and half == 2 and minute >= 75 and absi(score[0] - score[1]) <= 1:
		skill *= 1.0 + shooter.clutch * 0.2
	var gk := dfn.goalkeeper()
	var gk_val := gk.gk_comp() * gk.f if gk != null else 20.0
	var p_goal := clampf(xg * exp(EPS * (skill - gk_val)), 0.01, 0.92)
	if ctype == CH_PENALTY:
		p_goal = clampf(0.75 + (shooter.finishing() - gk_val) * 0.004, 0.55, 0.9)
	att.shots += 1
	att.xg += xg
	shooter.shots += 1
	var z_from := vis_rng.randf_range(0.45, 0.7)
	if ctype == CH_COUNTER:
		z_from = vis_rng.randf_range(0.2, 0.4)
	elif ctype == CH_CORNER:
		z_from = 0.97
	if rng.randf() < p_goal:
		_goal(att, dfn, shooter, assister, ctype, culprit)
		if detail:
			last_phase = {"side": s, "from": z_from, "to": 1.0, "ev": EV_GOAL, "ct": ctype}
		return
	var r := rng.randf()
	var ev := EV_MISS
	if ctype == CH_PENALTY:
		if r < 0.7:
			ev = EV_PEN_SAVE
			att.on_target += 1
			shooter.shots_on += 1
			if gk != null:
				gk.saves += 1
				gk.rating_pts += 0.7
				dfn.saves += 1
		else:
			ev = EV_PEN_MISS
		shooter.rating_pts -= 0.6
	elif r < 0.04:
		ev = EV_POST
		shooter.rating_pts += 0.05
	elif r < 0.34:
		ev = EV_SAVE
		att.on_target += 1
		shooter.shots_on += 1
		shooter.rating_pts += 0.15
		if gk != null:
			gk.saves += 1
			gk.rating_pts += 0.25 + xg * 0.8
			dfn.saves += 1
	elif r < 0.56:
		ev = EV_BLOCK
	else:
		shooter.rating_pts -= 0.03
	if assister != null:
		assister.rating_pts += 0.06
	if detail:
		_emit(ev, s, shooter.p.id, assister.p.id if assister != null else -1, {"ct": ctype, "xg": snappedf(xg, 0.01), "gk": gk.p.id if gk != null else -1})
	if detail:
		last_phase = {"side": s, "from": z_from, "to": vis_rng.randf_range(0.85, 0.98), "ev": ev, "ct": ctype}
	if (ev == EV_SAVE and rng.randf() < 0.3) or (ev == EV_BLOCK and rng.randf() < 0.4):
		_corner(att, dfn)


func _goal(att: MatchTeam, dfn: MatchTeam, shooter: MatchPlayer, assister: MatchPlayer, ctype: int, culprit: MatchPlayer) -> void:
	var s := att.side
	var before_diff := score[s] - score[1 - s]
	var own_goal := false
	if ctype == CH_CROSS and rng.randf() < 0.05:
		var og := _pick_weighted(dfn, PK_DEFEND)
		if og != null:
			own_goal = true
			og.own_goals += 1
			og.rating_pts -= 1.0
			shooter = og
			assister = null
	score[s] += 1
	att.on_target += 1
	if not own_goal:
		shooter.goals += 1
		shooter.shots_on += 1
		shooter.rating_pts += 0.85 if ctype == CH_PENALTY else 1.1
		if assister != null:
			assister.assists += 1
			assister.rating_pts += 0.65
	if culprit != null:
		culprit.rating_pts -= 0.8
	momentum[s] = 0.12
	for mp: MatchPlayer in dfn.slots:
		if mp == null:
			continue
		if mp.slot == 0:
			mp.rating_pts -= 0.35
		elif mp.w_def >= 0.8:
			mp.rating_pts -= 0.15
		elif mp.w_def >= 0.5:
			mp.rating_pts -= 0.07
	# Quem ficou atrás no placar em algum momento pode protagonizar uma virada.
	if score[s] > score[1 - s]:
		trailed[1 - s] = true
	var imp := _goal_importance(before_diff)
	var tags: Array = []
	var after_diff := score[s] - score[1 - s]
	if own_goal:
		tags.append("own_goal")
	if ctype == CH_PENALTY:
		tags.append("penalty")
	if ctype == CH_CROSS or ctype == CH_CORNER:
		tags.append("header")
	if after_diff == 0:
		tags.append("equalizer")
	elif after_diff == 1 and trailed[s]:
		tags.append("virada")
	elif after_diff == 1 and before_diff == 0 and half == 2 and minute >= 80:
		tags.append("winner")
	if after_diff >= 3:
		tags.append("blowout")
	if half == 2 and minute >= 85:
		tags.append("late")
	if half == 2 and minute > 90:
		tags.append("stoppage")
	if not own_goal and shooter.goals == 3:
		tags.append("hattrick")
	if score[0] + score[1] == 1:
		tags.append("first")
	if not own_goal and (ctype == CH_LONG or ctype == CH_FREEKICK or (ctype == CH_DRIBBLE and shooter.attr(Attr.TEC) >= 70)) and rng.randf() < 0.6:
		tags.append("golaco")
	if ctype == CH_ERROR:
		tags.append("error")
	if ctype == CH_COUNTER:
		tags.append("counter")
	half_events += 1
	_emit(EV_OWN_GOAL if own_goal else EV_GOAL, s, shooter.p.id, assister.p.id if assister != null else -1,
		{"ct": ctype, "imp": imp, "tags": tags, "culprit": culprit.p.id if culprit != null else -1})


## 0..1: quão marcante é o gol (minuto, placar, clássico, decisão).
func _goal_importance(before_diff: int) -> float:
	var after := before_diff + 1
	var imp := 0.3
	if after == 0:
		imp += 0.3
	elif after == 1:
		imp += 0.35
	elif after == 2:
		imp += 0.1
	elif after >= 3:
		imp -= 0.15
	if before_diff < -1:
		imp -= 0.1
	var m := minute if half == 2 else 0
	if m >= 85:
		imp += 0.3
	elif m >= 75:
		imp += 0.15
	if half == 2 and minute > 90:
		imp += 0.15
	if derby:
		imp += 0.1
	imp += (importance - 0.3) * 0.3
	return clampf(imp, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Faltas, cartões, escanteios, impedimentos, lesões
# ---------------------------------------------------------------------------

func _resolve_foul(att: MatchTeam, dfn: MatchTeam) -> void:
	var fouler := _pick_fouler(dfn)
	if fouler == null:
		return
	var victim := _pick_weighted(att, PK_DRIBBLE)
	dfn.fouls += 1
	fouler.fouls += 1
	fouler.rating_pts -= 0.05
	var dangerous := rng.randf() < 0.3
	var zone := vis_rng.randf_range(0.35, 0.65)
	if dangerous:
		zone = vis_rng.randf_range(0.72, 0.9)
	if detail:
		last_phase = {"side": att.side, "from": zone - 0.1, "to": zone, "ev": EV_FOUL}
	if detail:
		_emit(EV_FOUL, dfn.side, fouler.p.id, victim.p.id if victim != null else -1, {"danger": dangerous})
	var dis := fouler.a_dis
	var p_yellow := 0.155 * fouler.card_mult * (1.4 - dis / 100.0) * (1.15 if dfn.intensity == 2 else 1.0)
	var p_red := 0.0045 * fouler.card_mult * (1.3 - dis / 100.0)
	if dangerous:
		p_yellow *= 1.3
	if fouler.yellow >= 1:
		p_yellow *= 0.55 # pendurado alivia na dividida
	if rng.randf() < p_red:
		_send_off(dfn, fouler, false)
	elif rng.randf() < p_yellow:
		fouler.yellow += 1
		dfn.yellows += 1
		fouler.rating_pts -= 0.35
		half_events += 1
		if fouler.yellow >= 2:
			_send_off(dfn, fouler, true)
		else:
			_emit(EV_YELLOW, dfn.side, fouler.p.id)
	if victim != null and rng.randf() < 0.005:
		_injury(att, victim)
	if dangerous:
		if rng.randf() < 0.045:
			_emit(EV_PENALTY_AWARDED, att.side, victim.p.id if victim != null else -1, fouler.p.id)
			var taker := att.by_id.get(att.sheet.penalty_taker, null) as MatchPlayer
			if taker == null or not taker.on_pitch:
				taker = _best_on_pitch(att, "pen")
			_resolve_chance(att, dfn, CH_PENALTY, taker)
		elif rng.randf() < 0.13:
			var fk := att.by_id.get(att.sheet.freekick_taker, null) as MatchPlayer
			if fk == null or not fk.on_pitch:
				fk = _best_on_pitch(att, "fk")
			if detail:
				_emit(EV_FREEKICK, att.side, fk.p.id if fk != null else -1)
			_resolve_chance(att, dfn, CH_FREEKICK, fk)


func _pick_fouler(t: MatchTeam) -> MatchPlayer:
	var cands: Array[MatchPlayer] = []
	var w: Array = []
	for mp: MatchPlayer in t.slots:
		if mp == null:
			continue
		var base := 0.6
		match mp.pos:
			Pos.GK:
				base = 0.05
			Pos.DM:
				base = 1.5
			Pos.CB:
				base = 1.2
			Pos.CM:
				base = 1.1
			Pos.RB, Pos.LB:
				base = 1.0
			Pos.ST:
				base = 0.8
		if mp.yellow >= 1:
			base *= 0.45
		cands.append(mp)
		w.append(base * mp.card_mult * (1.5 - mp.a_dis / 100.0))
	if cands.is_empty():
		return null
	return cands[RngUtil.weighted_index(rng, w)]


func _best_on_pitch(t: MatchTeam, kind: String) -> MatchPlayer:
	var best: MatchPlayer = null
	var best_v := -1.0
	for mp: MatchPlayer in t.slots:
		if mp == null or mp.slot == 0:
			continue
		var v := 0.0
		match kind:
			"pen":
				v = mp.attr(Attr.FIN) * 0.6 + mp.attr(Attr.DEC) * 0.3 + mp.attr(Attr.INT) * 0.1
			"fk":
				v = mp.attr(Attr.TEC) * 0.5 + mp.attr(Attr.FIN) * 0.3 + mp.attr(Attr.PAS) * 0.2
			"corner":
				v = mp.attr(Attr.CRU) * 0.7 + mp.attr(Attr.TEC) * 0.3
		if v > best_v:
			best_v = v
			best = mp
	return best


func _send_off(t: MatchTeam, mp: MatchPlayer, second_yellow: bool) -> void:
	mp.red = true
	t.reds += 1
	mp.rating_pts -= 1.5
	half_events += 1
	_emit(EV_RED, t.side, mp.p.id, -1, {"second": second_yellow})
	var was_gk := mp.slot == 0
	_remove_from_pitch(t, mp)
	# Goleiro expulso: sacrifica um atacante para colocar o reserva no gol.
	if was_gk and t.subs_used < t.max_subs:
		var gk_bench: MatchPlayer = null
		for b: MatchPlayer in t.bench:
			if not b.used and b.p.position == Pos.GK:
				gk_bench = b
				break
		if gk_bench != null:
			var victim: MatchPlayer = null
			var low := 1e9
			for o: MatchPlayer in t.slots:
				if o != null and o.slot != 0 and o.w_att >= 0.45 and o.p.rating_at(o.pos) < low:
					low = o.p.rating_at(o.pos)
					victim = o
			if victim != null:
				var vslot := victim.slot
				_do_sub(t, victim, gk_bench, 0)
				t.slots[vslot] = null
	t.recompute_units()
	_refresh_rates()


func _remove_from_pitch(t: MatchTeam, mp: MatchPlayer) -> void:
	mp.on_pitch = false
	mp.end_min = minute
	if mp.slot >= 0 and mp.slot < t.slots.size() and t.slots[mp.slot] == mp:
		t.slots[mp.slot] = null


func _corner(att: MatchTeam, dfn: MatchTeam) -> void:
	att.corners += 1
	var taker := att.by_id.get(att.sheet.corner_taker, null) as MatchPlayer
	if taker == null or not taker.on_pitch:
		taker = _best_on_pitch(att, "corner")
	if detail:
		_emit(EV_CORNER, att.side, taker.p.id if taker != null else -1)
	if detail:
		last_phase = {"side": att.side, "from": 0.9, "to": 0.97, "ev": EV_CORNER}
	if rng.randf() < 0.28:
		_resolve_chance(att, dfn, CH_CORNER)


func _offside(att: MatchTeam) -> void:
	att.offsides += 1
	var who := _pick_weighted(att, PK_SHOOT)
	if detail and who != null:
		_emit(EV_OFFSIDE, att.side, who.p.id)
	if detail:
		last_phase = {"side": att.side, "from": 0.55, "to": 0.8, "ev": EV_OFFSIDE}


func _pick_injury_victim(t: MatchTeam) -> MatchPlayer:
	var cands: Array[MatchPlayer] = []
	var w: Array = []
	for mp: MatchPlayer in t.slots:
		if mp == null:
			continue
		cands.append(mp)
		w.append(mp.injury_f * (1.6 - mp.cond / 100.0) * (0.3 if mp.slot == 0 else 1.0))
	if cands.is_empty():
		return null
	return cands[RngUtil.weighted_index(rng, w)]


func _injury(t: MatchTeam, mp: MatchPlayer) -> void:
	if mp == null or mp.injured or not mp.on_pitch:
		return
	mp.injured = true
	mp.injury_weeks = InjuryTable.roll_weeks(rng)
	half_events += 1
	_emit(EV_INJURY, t.side, mp.p.id, -1, {"weeks": mp.injury_weeks})
	if t.subs_used < t.max_subs:
		var sub := _best_bench_for(t, mp.pos)
		if sub != null:
			_do_sub(t, mp, sub, mp.slot)
			return
	_remove_from_pitch(t, mp)
	t.recompute_units()
	_refresh_rates()


# ---------------------------------------------------------------------------
# Substituições e decisões da IA
# ---------------------------------------------------------------------------

func _best_bench_for(t: MatchTeam, pos: int) -> MatchPlayer:
	var best: MatchPlayer = null
	var best_v := -1.0
	for b: MatchPlayer in t.bench:
		if b.used or b.injured:
			continue
		if (pos == Pos.GK) != (b.p.position == Pos.GK):
			continue
		var v := b.p.rating_at(pos) * (0.72 + 0.28 * b.cond / 100.0)
		if v > best_v:
			best_v = v
			best = b
	return best


func _do_sub(t: MatchTeam, out_mp: MatchPlayer, in_mp: MatchPlayer, slot: int) -> void:
	var fslot: Dictionary = t.formation["slots"][slot]
	out_mp.on_pitch = false
	out_mp.end_min = minute
	_assign_slot(in_mp, slot, fslot)
	in_mp.on_pitch = true
	in_mp.used = true
	in_mp.start_min = minute
	t.slots[slot] = in_mp
	t.subs_used += 1
	half_events += 1
	_emit(EV_SUB, t.side, in_mp.p.id, out_mp.p.id)
	t.recompute_units()
	_refresh_rates()


## Substituição pedida pela UI. Retorna mensagem de erro ("" se ok).
func user_substitution(side: int, out_id: int, in_id: int) -> String:
	var t: MatchTeam = teams[side]
	if t.subs_used >= t.max_subs:
		return "Limite de substituições atingido."
	var out_mp: MatchPlayer = t.by_id.get(out_id, null)
	var in_mp: MatchPlayer = t.by_id.get(in_id, null)
	if out_mp == null or not out_mp.on_pitch:
		return "Esse jogador não está em campo."
	if in_mp == null or in_mp.used:
		return "Esse jogador não pode entrar."
	_do_sub(t, out_mp, in_mp, out_mp.slot)
	return ""


func set_mentality(side: int, m: int) -> void:
	var t: MatchTeam = teams[side]
	if t.mentality == m:
		return
	t.mentality = clampi(m, 0, 4)
	t.refresh_tactics()
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"mentality": t.mentality})


func set_style(side: int, st: int) -> void:
	var t: MatchTeam = teams[side]
	if t.style == st:
		return
	t.style = clampi(st, 0, 5)
	t.refresh_tactics()
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"style": t.style})


func _ai_decisions() -> void:
	if half != 2:
		return
	for t: MatchTeam in teams:
		if (minute == 60 or minute == 68 or minute == 76 or minute == 84) and (not t.is_user or t.auto_subs):
			_auto_subs(t)
		if t.is_user:
			continue
		if minute % 10 == 0 and minute >= 60:
			var diff: int = score[t.side] - score[1 - t.side]
			var target := t.base_mentality
			if diff < 0:
				target = maxi(t.base_mentality, 3 if minute < 80 else 4)
			elif diff == 1 and minute >= 75:
				target = mini(t.base_mentality, 1)
			elif diff >= 2:
				target = mini(t.base_mentality, 2)
			if target != t.mentality:
				set_mentality(t.side, target)


## Trocas automáticas em janelas: sai quem está mais gasto se o reserva render quase o mesmo.
func _auto_subs(t: MatchTeam) -> void:
	var reserve := 1 if minute < 84 else 0
	var limit := t.max_subs - reserve
	if t.subs_used >= limit:
		return
	var cands: Array[MatchPlayer] = []
	for mp: MatchPlayer in t.slots:
		if mp != null and mp.slot != 0 and mp.start_min == 0:
			cands.append(mp)
	cands.sort_custom(func(a, b): return a.cond < b.cond)
	var per_window := 2 if minute < 84 else 3
	var done := 0
	for mp: MatchPlayer in cands:
		if t.subs_used >= limit or done >= per_window:
			break
		var sub := _best_bench_for(t, mp.pos)
		if sub == null:
			continue
		var c1 := mp.cond / 100.0
		var c2 := sub.cond / 100.0
		var cur := mp.p.rating_at(mp.pos) * (0.72 + 0.28 * c1 * c1)
		var new_v := sub.p.rating_at(mp.pos) * (0.72 + 0.28 * c2 * c2)
		var need := 0.92 if mp.yellow == 0 else 0.85
		if new_v >= cur * need:
			_do_sub(t, mp, sub, mp.slot)
			done += 1


# ---------------------------------------------------------------------------
# Encerramento
# ---------------------------------------------------------------------------

func _finish() -> void:
	finished = true
	_emit(EV_FULLTIME, -1, -1)
	var end_minute := minute
	for t: MatchTeam in teams:
		var diff: int = score[t.side] - score[1 - t.side]
		var team_bonus := 0.3 if diff > 0 else (-0.25 if diff < 0 else 0.0)
		var clean := score[1 - t.side] == 0
		var avg := 0.0
		var n := 0
		for mp: MatchPlayer in t.all:
			if mp.used:
				avg += mp.p.rating_at(mp.pos) * mp.perf
				n += 1
		avg = avg / maxf(1.0, n)
		for mp: MatchPlayer in t.all:
			if not mp.used:
				continue
			var mins := mp.minutes_played(end_minute)
			var pts := mp.rating_pts
			if clean and mins >= 60:
				if mp.pos == Pos.GK:
					pts += 0.8
				elif mp.w_def >= 0.8:
					pts += 0.45
			var perf_c := clampf((mp.p.rating_at(mp.pos) * mp.perf / maxf(1.0, avg) - 1.0) * 4.0, -0.5, 0.5)
			var r := 6.0 + pts + team_bonus + perf_c + rng.randfn(0.0, 0.25)
			if mins < 20:
				r = 6.0 + clampf(pts, -1.0, 1.5) + team_bonus * 0.5
			mp.final_rating = clampf(snappedf(r, 0.1), 3.0, 10.0)


## Resumo no formato comum dos resultados (o mesmo de QuickMatch.play) para aplicar ao mundo.
func to_result() -> Dictionary:
	var goals: Array = []
	for ev in events:
		var t: int = ev["t"]
		if t == EV_GOAL or t == EV_OWN_GOAL:
			var kind := Fixture.GOAL_NORMAL
			if t == EV_OWN_GOAL:
				kind = Fixture.GOAL_OWN
			elif ev.has("x") and int(ev["x"].get("ct", -1)) == CH_PENALTY:
				kind = Fixture.GOAL_PENALTY
			goals.append([int(ev["m"]), int(ev["s"]), int(ev["p"]), kind, int(ev["h"])])
	var lines: Array = [[], []]
	for t: MatchTeam in teams:
		for mp: MatchPlayer in t.all:
			if not mp.used:
				continue
			# Mesmo formato de linha do QuickMatch (índices QuickMatch.L_*).
			lines[t.side].append([mp.p, mp.pos, mp.f, mp.w_def, mp.w_att, 0.0, 0.0, 0.0, mp.slot_rating, mp.c_fin,
				1 if mp.on_pitch else 0, mp.start_min, mp.end_min, mp.goals, mp.assists, mp.yellow, mp.red,
				mp.injury_weeks if mp.injured else 0, mp.rating_pts, mp.minutes_played(minute), mp.final_rating, mp.cond,
				mp.pos == Pos.GK or mp.w_def >= 0.8])
	var motm := man_of_the_match()
	return {"hg": score[0], "ag": score[1], "att": attendance, "goals": goals, "motm": motm.p.id if motm != null else -1,
		"et": half >= 3, "pens": [pen_score[0], pen_score[1]] if pen_taken[0] + pen_taken[1] > 0 else [],
		"derby": derby, "importance": importance, "yc": [teams[0].yellows, teams[1].yellows], "rc": [teams[0].reds, teams[1].reds],
		"lines": lines, "poss": possession_pct(0)}


## Craque do jogo: maior nota (desempate: time vencedor).
func man_of_the_match() -> MatchPlayer:
	var best: MatchPlayer = null
	var best_v := -1.0
	for t: MatchTeam in teams:
		var won: bool = score[t.side] > score[1 - t.side]
		for mp: MatchPlayer in t.all:
			if not mp.used:
				continue
			var v := mp.final_rating + (0.05 if won else 0.0)
			if v > best_v:
				best_v = v
				best = mp
	return best


func possession_pct(side: int) -> float:
	var total: int = teams[0].poss_ticks + teams[1].poss_ticks
	if total == 0:
		return 0.5
	return float(teams[side].poss_ticks) / total


func _emit(type: int, side: int, pid: int, pid2: int = -1, extra: Dictionary = {}) -> void:
	var ev := {"t": type, "m": minute, "h": half, "s": side, "p": pid, "p2": pid2, "hs": score[0], "as": score[1]}
	if not extra.is_empty():
		ev["x"] = extra
	events.append(ev)
	last_events.append(ev)
