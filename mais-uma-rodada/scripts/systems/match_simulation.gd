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
# Lances só de narração (sorteados com vis_rng, nunca mudam o resultado)
const EV_SKILL := 27 # p dribla p2 (adversário)
const EV_TACKLE := 28 # p (defensor) desarma p2 (atacante)
const EV_KEEPER := 29 # goleiro p fica com a bola
const EV_CROWD := 30 # clima: x = {kind}
const EV_VAR := 31 # revisão do VAR: x = {kind}
const EV_KNOCK := 32 # p2 fica caído após falta de p, mas segue em campo
const EV_CRAMP := 33 # p sente câimbra (fim de jogo e prorrogação): rende muito menos até sair

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
const BASE_XG: Array[float] = [0.132, 0.075, 0.027, 0.094, 0.162, 0.11, 0.07, 0.065, 0.76, 0.27]

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
const BASE_CHANCE := 0.19 # prob. de chance por minuto de posse, times iguais
const BETA := 0.05 # sensibilidade da taxa de chances à diferença ATA×DEF (por ponto)
const GAMMA := 0.021 # sensibilidade da posse à diferença de meio-campo (por ponto)
const DELTA := 0.005 # sensibilidade da qualidade da chance
const EPS := 0.006 # finalizador × goleiro
const HOME_CHANCE := 0.11 # empurrão da torcida na taxa de chances do mandante
const AWAY_CHANCE := 0.05 # pressão sobre o visitante
const FOUL_RATE := 0.235
const INJURY_RATE := 0.0014
const FATIGUE_RATE := 0.17
## Desvio do "dia do time" (1,0 ± ~3,5%): times iguais podem ter jogos bem diferentes.
const DAY_SIGMA := 0.035
## Modificadores de tática, moral, forma, entrosamento e dia valem esta fração do efeito nominal: a
## qualidade dos jogadores decide mais que os ajustes (senão jogar no ataque sempre compensa).
const MOD_DAMP := 0.35
## Ajuste fino do xG geométrico do motor posicional para a média de gols bater com a do sorteio.
const LIVE_XG := 0.72


static func damp(x: float) -> float:
	return 1.0 + (x - 1.0) * MOD_DAMP
## Contra o time do usuário a IA se motiva mais conforme a dificuldade (fácil, normal, difícil).
const USER_OPP_BOOST: Array[float] = [1.0, 1.035, 1.07]
## Força do efeito do placar (no começo do jogo e somado até o fim).
## Quem finaliza: o centroavante recebe mais bolas, o zagueiro sobe nas bolas aéreas. Calibrado para
## a divisão real dos gols (atacantes ~55–60%, meias ~28%, defensores ~12%).
const ST_SHOOT := 1.3
const OWN_GOAL_P := 0.1
const CB_HEAD := 0.5
const STATE_BASE := 0.04
const STATE_LATE := 0.07
const STATE_BEATEN := 0.3 # quem perde de 2+ ainda empurra, mas sem a mesma força
const STATE_LEAD2 := 0.75
const STATE_LEAD3 := 0.55
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
## Pressão por minuto (só com detail): [tempo, minuto, valor] — valor > 0 mandante, < 0 visitante.
var pressure: Array = []
var year: int = 2026
var crowd: float = 0.8
## Cultura da liga (LeagueCulture): multiplicadores de chances e de cartões.
var goal_f: float = 1.0
## Clima da partida (Weather.for_fixture): muda gols, erros, cansaço, faltas, lesões e jogadas.
var wx: Dictionary = {}
var wx_fx: Dictionary = {"goals": 1.0, "fatigue": 1.0, "errors": 1.0, "long": 1.0, "cross": 1.0, "pass": 1.0, "fouls": 1.0, "injury": 1.0}
var card_f: float = 1.0
var ref: Array = [] # árbitro [nação, id] (Referees)
var ref_pens: float = 1.0
var ref_fouls: float = 1.0
## Raio-X tático (jogos do usuário): chances com corredor e contexto, avanços dos laterais,
## entradas no último terço e na área, e trechos entre as mudanças do técnico.
var xray_on: bool = false
var xr_chances: Array = []
var xr_adv: Dictionary = {} # player_id -> avanços ao ataque
var xr_ft: Array[int] = [0, 0] # entradas no último terço
var xr_box: Array[int] = [0, 0] # entradas na área (chances de jogada)
var xr_segments: Array = []
const OPEN_PLAY := [CH_THROUGH, CH_CROSS, CH_LONG, CH_DRIBBLE, CH_COUNTER, CH_SCRAMBLE, CH_ERROR]
const LANE_BASE := [0.28, 0.44, 0.28]
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
	var cul := LeagueCulture.for_match(world, competition, home)
	goal_f = float(cul["goals"])
	card_f = float(cul["cards"])
	ref = Array(ctx.get("ref", []))
	var rf := Referees.factors(world, ref)
	card_f *= float(rf["cards"])
	ref_pens = float(rf["pens"])
	ref_fouls = float(rf["fouls"])
	wx = ctx.get("wx", {})
	if not wx.is_empty():
		wx_fx = wx.get("fx", wx_fx)
		goal_f *= float(wx_fx["goals"])
		ref_fouls *= float(wx_fx["fouls"])
		_type_w[CH_LONG] = BASE_TYPE_W[CH_LONG] * float(wx_fx["long"])
		_type_w[CH_CROSS] = BASE_TYPE_W[CH_CROSS] * float(wx_fx["cross"])
	crowd *= float(cul["home"])
	var adv := float(DatabaseManager.tactics().get("home_advantage", 0.05))
	teams[0].home_f = 1.0 + adv * crowd * 0.5
	teams[1].home_f = 1.0
	for t: MatchTeam in teams:
		t.day_f = clampf(rng.randfn(1.0, DAY_SIGMA), 0.93, 1.07) # entra no home_f, atenuado em refresh_factors
	for side in 2:
		if teams[side].is_user and not teams[1 - side].is_user:
			teams[1 - side].day_f *= USER_OPP_BOOST[clampi(world.difficulty, 0, 2)]
	for t: MatchTeam in teams:
		t.home_f *= t.day_f
	# Os times se estudaram: cada um sabe onde o outro sofre (TacticalScout).
	for t: MatchTeam in teams:
		var opp_club: Club = teams[1 - t.side].club
		t.vuln = TacticalScout.vulnerability(world, opp_club)
		t.study = TacticalScout.study(world, t.club)
		t.adapt = float(ClubPhilosophy.of(t.club).get("adapt", 0.4))
		t.opp_ref = weakref(teams[1 - t.side])
		# Contra o time do usuário a IA estuda mais (e mais ainda nas dificuldades altas).
		if teams[1 - t.side].is_user and not t.is_user:
			t.study = minf(1.0, t.study + 0.05 + 0.1 * clampi(world.difficulty, 0, 2))
			t.adapt = minf(1.0, t.adapt + 0.1 * clampi(world.difficulty, 0, 2))
	for t: MatchTeam in teams:
		t.refresh_tactics()
		t.recompute_units()
	_refresh_rates()
	xray_on = teams[0].is_user or teams[1].is_user
	if xray_on:
		xr_segments = [{"m": 0, "label": "Início", "snap": _xr_snap()}]


## Contadores acumulados por time (a diferença entre dois retratos é o trecho).
func _xr_snap() -> Array:
	var out: Array = []
	for t: MatchTeam in teams:
		out.append({"sh": t.shots, "xg": t.xg, "poss": t.poss_ticks, "ft": xr_ft[t.side], "box": xr_box[t.side], "g": score[t.side]})
	return out


## Marca uma mudança do técnico: começa um trecho novo para comparar antes e depois.
func xr_mark(label: String) -> void:
	if not xray_on or xr_segments.is_empty():
		return
	var last: Dictionary = xr_segments[xr_segments.size() - 1]
	if minute - int(last["m"]) < 3:
		last["label"] = label # mudanças seguidas contam como uma só
		return
	xr_segments.append({"m": minute, "label": label, "snap": _xr_snap()})


func _build_team(world: GameWorld, side: int, club: Club, sheet: TeamSheet) -> MatchTeam:
	var t := MatchTeam.new()
	t.side = side
	t.club = club
	t.sheet = sheet
	t.formation = DatabaseManager.formation(sheet.formation)
	t.formation_name = sheet.formation if DatabaseManager.has_formation(sheet.formation) else "4-4-2"
	t.max_subs = int(DatabaseManager.squad_rules()["max_subs"])
	t.is_user = world.is_user_club(club.id)
	t.auto_subs = sheet.auto_subs if t.is_user else true
	t.mentality = sheet.mentality
	t.base_mentality = sheet.mentality
	t.style = sheet.style
	t.intensity = sheet.intensity
	t.line = sheet.line
	t.pressing = sheet.pressing
	t.width_i = sheet.width
	t.deep = sheet.deep_values()
	t.evo_f = TeamEvolution.factor(world, club)
	t.cohesion_base = 0.96 + clampf(club.cohesion, 0.0, 100.0) / 100.0 * 0.08
	t.cohesion_f = t.cohesion_base * TacticsManager.fam_factor(club, sheet)
	var um := TrainingManager.unit_mults(world, club)
	t.train_att = damp(float(um[0]))
	t.train_def = damp(float(um[1]))
	t.sp_bonus = TrainingManager.set_piece_bonus(world, club)
	var inj_m := TrainingManager.injury_mult(world, club.id)
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
		var mp := _make_mp(pl, big, inj_m * TrainingManager.player_injury_mult(world, pl))
		mp.instr = sheet.instruction_of(pl.id)
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
		var mp := _make_mp(pl, big, inj_m * TrainingManager.player_injury_mult(world, pl))
		mp.instr = sheet.instruction_of(pl.id)
		t.bench.append(mp)
		t.all.append(mp)
		t.by_id[pid] = mp
	var cm := ManagerProfile.card_mult(world, club.id)
	if cm != 1.0:
		for mp2: MatchPlayer in t.all:
			mp2.card_mult *= cm
	return t


func _make_mp(pl: Player, big: bool, inj_m: float = 1.0) -> MatchPlayer:
	var mp := MatchPlayer.new()
	mp.p = pl
	mp.cond = pl.condition
	var sigma := 0.015 + (20 - pl.consistency) * 0.0025
	mp.perf = clampf(rng.randfn(1.0, sigma), 0.86, 1.14)
	mp.ctx = 1.0 + (pl.trait_sum("big_game") if big else 0.0)
	mp.card_mult = pl.trait_mult("card_mult")
	mp.clutch = pl.trait_sum("clutch")
	mp.injury_f = (1.0 + pl.injury_prone / 10.0) * pl.trait_mult("injury_mult") * inj_m
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
	if not mp.instr.is_empty() and mp.pos != Pos.GK:
		mp.w_def = maxf(0.0, mp.w_def + float(mp.instr["def"]))
		mp.w_mid = maxf(0.0, mp.w_mid + float(mp.instr["mid"]))
		mp.w_att = maxf(0.0, mp.w_att + float(mp.instr["att"]))
		mp.card_mult = mp.p.trait_mult("card_mult") * float(mp.instr["foul"])
	mp.fam = Pos.familiarity(mp.p.position, mp.p.secondary, mp.pos)
	mp.slot_rating = mp.p.rating_at(mp.pos)
	mp.apply_side(mp.pos)


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
		_game_state()
		_refresh_rates()
		# No vestiário, o técnico da IA relê o primeiro tempo.
		for t: MatchTeam in teams:
			if not t.is_user:
				_ai_read(t)
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
		_pen_order[side] = _build_pen_order(side)
	_emit(EV_SHOOTOUT, 0, -1, -1, {"ps": [0, 0]})


## Batedores em campo: primeiro os da ordem escolhida no TeamSheet, depois o resto pela
## habilidade, com o goleiro por último. Só ordena, não sorteia.
func _build_pen_order(side: int) -> Array:
	var t: MatchTeam = teams[side]
	var chosen: Array = []
	var rest: Array = []
	for mp: MatchPlayer in t.slots:
		if mp != null and mp.on_pitch:
			rest.append(mp)
	if t.sheet != null:
		for pid in t.sheet.shootout_order:
			for mp: MatchPlayer in rest:
				if mp.p.id == int(pid):
					chosen.append(mp)
					rest.erase(mp)
					break
	rest.sort_custom(func(a, b): return _pen_skill(a) > _pen_skill(b))
	# O goleiro bate por último.
	rest.sort_custom(func(a, b): return (1 if a.slot == 0 else 0) < (1 if b.slot == 0 else 0))
	return chosen + rest


## Batedores da disputa na ordem atual (MatchPlayer).
func shootout_kickers(side: int) -> Array:
	return _pen_order[side]


## O técnico define a ordem antes da primeira cobrança do time. Guarda no TeamSheet
## para a próxima disputa.
func set_shootout_order(side: int, ids: Array) -> bool:
	var t: MatchTeam = teams[side]
	if t.sheet != null:
		t.sheet.shootout_order = ids.duplicate()
	if not shootout or pen_taken[side] > 0:
		return false
	_pen_order[side] = _build_pen_order(side)
	return true


## Última cobrança da disputa (canto, goleiro, resultado), para a tela encenar.
var last_pen: Dictionary = {}


## Lado da próxima cobrança da disputa (-1 fora dela).
func next_kick_side() -> int:
	if not shootout:
		return -1
	return 0 if pen_taken[0] == pen_taken[1] else 1


func _pen_skill(mp: MatchPlayer) -> float:
	return mp.attr(Attr.FIN) * 0.45 + mp.attr(Attr.FRI) * 0.35 + mp.attr(Attr.DEC) * 0.1 + mp.attr(Attr.INT) * 0.1 + mp.clutch * 20.0 + HiddenPersona.penalty_nerve(mp.p) * 60.0


func _shootout_kick() -> void:
	var side := 0 if pen_taken[0] == pen_taken[1] else 1
	var order: Array = _pen_order[side]
	if order.is_empty():
		_end_shootout()
		return
	var kicker: MatchPlayer = order[pen_taken[side] % order.size()]
	var gk := teams[1 - side].goalkeeper()
	# Na disputa a pressão cresce a cada cobrança; nas alternadas e no "se errar, acabou", é máxima
	var pressure := 0.55 + 0.05 * mini(pen_taken[side], 4) + (0.2 if pen_taken[side] >= 5 else 0.0)
	var left_me := maxi(0, 5 - pen_taken[side])
	if pen_score[side] + left_me < pen_score[1 - side] + maxi(0, 5 - pen_taken[1 - side]) + 1:
		pressure += 0.1 # errar pode eliminar
	var pk := PenaltyKick.kick(rng, kicker.p, gk.p if gk != null else null, {"f": kicker.f, "gk_f": gk.f if gk != null else 1.0,
		"cond": kicker.cond, "pressure": clampf(pressure + importance * 0.2, 0.0, 1.0), "away": side == 1 and not neutral,
		"study": teams[1 - side].study})
	var ok := String(pk["res"]) == "goal"
	last_pen = pk
	pen_taken[side] += 1
	if ok:
		pen_score[side] += 1
		kicker.rating_pts += 0.1
	else:
		kicker.rating_pts -= 0.4
		if gk != null:
			gk.rating_pts += 0.35
	_emit(EV_SHOOT_KICK, side, kicker.p.id, gk.p.id if gk != null else -1, {"ok": ok, "n": pen_taken[side], "ps": [pen_score[0], pen_score[1]], "res": String(pk["res"]), "dir": int(pk["dir"]), "dive": int(pk["dive"]), "panenka": bool(pk["panenka"])})
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
	for t: MatchTeam in teams:
		if t.sh_until >= 0 and minute >= t.sh_until:
			_clear_shout(t)
	if minute % 5 == 0:
		for t: MatchTeam in teams:
			_apply_fatigue(t, 5.0)
		if minute % 10 == 0:
			for t: MatchTeam in teams:
				t.recompute_units()
			_game_state()
			_refresh_rates()
	_ai_decisions()
	var poss := clampf(_poss_base + (momentum[0] - momentum[1]) * 0.15, 0.25, 0.75)
	var s := 0 if rng.randf() < poss else 1
	var att: MatchTeam = teams[s]
	var dfn: MatchTeam = teams[1 - s]
	att.poss_ticks += 1
	if xray_on:
		_xr_tick(att, dfn)
	var p_chance := clampf(_rate_chance[s] * (1.0 + momentum[s]) * _time_factor(), 0.02, 0.6)
	var p_foul := _rate_foul[1 - s]
	var p_off := _rate_off[s]
	var p_corner := _rate_corner[s]
	var r := rng.randf()
	var xg0 := att.xg
	var danger := 0.18
	if r < p_chance:
		_resolve_chance(att, dfn, -1)
		danger = 0.5 + minf(0.5, (att.xg - xg0) * 2.5)
	elif r < p_chance + p_foul:
		_resolve_foul(att, dfn)
		danger = 0.3 + minf(0.5, (att.xg - xg0) * 2.5)
	elif r < p_chance + p_foul + p_off:
		_offside(att)
		danger = 0.32
	elif r < p_chance + p_foul + p_off + p_corner:
		_corner(att, dfn)
		danger = 0.42 + minf(0.5, (att.xg - xg0) * 2.5)
	elif detail:
		var z0 := vis_rng.randf_range(0.25, 0.55)
		last_phase = {"side": s, "from": z0, "to": clampf(z0 + vis_rng.randf_range(-0.1, 0.25), 0.1, 0.8), "ev": -1}
		danger = 0.1 + z0 * 0.3
		_flavor(att, dfn)
	if detail:
		pressure.append([half, minute, danger if s == 0 else -danger])
	for t: MatchTeam in teams:
		if rng.randf() < INJURY_RATE * t.i_fatigue * float(wx_fx["injury"]):
			_injury(t, _pick_injury_victim(t))


## O jogo abre com o tempo: pernas cansadas, espaços e pressa. Começa ~10% abaixo da média e
## termina ~10% acima (média 1 nos 90 minutos, então o total de gols não muda).
func _time_factor() -> float:
	if half >= 3:
		return 1.05
	return 0.86 + 0.28 * clampf(float(minute) / 90.0, 0.0, 1.0)


## Raio-X: laterais que sobem ao ataque e chegadas ao último terço (só vis_rng: não muda o jogo).
func _xr_tick(att: MatchTeam, dfn: MatchTeam) -> void:
	for mp: MatchPlayer in att.slots:
		if mp != null and (mp.role == "FB" or mp.role == "WB") and vis_rng.randf() < mp.w_att * 1.4:
			xr_adv[mp.p.id] = int(xr_adv.get(mp.p.id, 0)) + 1
	var dom := clampf(0.3 + (_att_power(att) - _def_power(dfn)) / 120.0, 0.12, 0.55)
	if vis_rng.randf() < dom:
		xr_ft[att.side] += 1


## Corredor do ataque: o lado em que quem ataca leva mais vantagem sobre quem defende é o mais
## usado, e a chance fica melhor (ou pior) conforme esse confronto. Retorna [corredor, fator de xG]
## com o fator normalizado para a média ficar em 1 (o motor continua calibrado).
func _pick_lane(att: MatchTeam, dfn: MatchTeam, ctype: int) -> Array:
	var base: Array = LANE_BASE
	if ctype == CH_CROSS:
		base = [0.5, 0.0, 0.5]
	elif ctype == CH_LONG:
		base = [0.2, 0.6, 0.2]
	var ratio: Array = []
	var mean := 0.0
	var wsum := 0.0
	for l in 3:
		var r := att.lane_att[l] / maxf(1.0, dfn.lane_def[2 - l]) # meu lado esquerdo enfrenta o direito deles
		ratio.append(r)
		mean += r * float(base[l])
		wsum += float(base[l])
	mean /= maxf(0.01, wsum)
	var w: Array = []
	var fac: Array = []
	var e := 0.0
	var tw := 0.0
	for l in 3:
		var rel := float(ratio[l]) / maxf(0.01, mean)
		var wl := float(base[l]) * clampf(rel, 0.5, 2.0)
		var fl := clampf(pow(rel, 0.3), 0.82, 1.22)
		w.append(wl)
		fac.append(fl)
		e += wl * fl
		tw += wl
	var lane := RngUtil.weighted_index(rng, w)
	if lane < 0:
		lane = 1
	return [lane, float(fac[lane]) / maxf(0.01, e / maxf(0.01, tw))]


## Minuto sem lance de perigo: troca de passes, dribles, desarmes, goleiro e torcida.
## Só apresentação (vis_rng): assistir nunca muda o placar.
func _flavor(att: MatchTeam, dfn: MatchTeam) -> void:
	# Narração do minuto sem lance de perigo: quase todo minuto tem alguma coisa para contar
	# (só vis_rng: não mexe no resultado). Os nomes vêm de quem está com a bola de verdade.
	var s := att.side
	var r := vis_rng.randf()
	var carrier := _pick_weighted(att, PK_MID, vis_rng)
	var mate := _pick_weighted(att, PK_PASS, vis_rng)
	if mate == carrier:
		mate = _pick_weighted(att, PK_COUNTER, vis_rng)
	var cid := carrier.p.id if carrier != null else -1
	var mid := mate.p.id if mate != null and mate != carrier else -1
	if r < 0.46:
		var kinds := ["switch", "long", "press", "build", "throw", "goalkick", "back", "tabela", "wing", "carry", "hold", "patience",
			"tabela", "wing", "carry", "build", "back"]
		var k: String = kinds[vis_rng.randi_range(0, kinds.size() - 1)]
		if (k in ["tabela", "wing"]) and mid < 0:
			k = "carry"
		_emit(EV_POSSESSION, s, cid, mid, {"kind": k})
	elif r < 0.56:
		var d := _pick_weighted(dfn, PK_DEFEND, vis_rng)
		_emit(EV_POSSESSION, s, cid, mid, {"kind": "intercept" if vis_rng.randf() < 0.6 else "cross_cut", "d": d.p.id if d != null else -1})
	elif r < 0.66:
		var dr := _pick_weighted(att, PK_DRIBBLE, vis_rng)
		var dm := _pick_weighted(dfn, PK_DEFEND, vis_rng)
		if dr != null and dm != null:
			_emit(EV_SKILL, s, dr.p.id, dm.p.id)
	elif r < 0.76:
		var dm2 := _pick_weighted(dfn, PK_DEFEND, vis_rng)
		var vic := _pick_weighted(att, PK_DRIBBLE, vis_rng)
		if dm2 != null and vic != null:
			_emit(EV_TACKLE, dfn.side, dm2.p.id, vic.p.id)
	elif r < 0.81:
		var gk := dfn.goalkeeper()
		if gk != null:
			_emit(EV_KEEPER, dfn.side, gk.p.id)
	elif r < 0.87:
		var cr := crowd_mood()
		if not cr.is_empty():
			_emit(EV_CROWD, int(cr["side"]), -1, -1, {"kind": cr["kind"]})
	elif r < 0.95:
		# Leitura do jogo: quem manda, jogo truncado, ritmo
		var poss := possession_pct(s)
		var k2 := "read_even"
		if poss >= 0.58:
			k2 = "read_dom"
		elif att.xg - dfn.xg >= 0.6:
			k2 = "read_danger"
		elif minute >= 70 and score[0] == score[1]:
			k2 = "read_tense"
		elif fouls_total() >= minute / 4:
			k2 = "read_rough"
		_emit(EV_POSSESSION, s, cid, mid, {"kind": k2})


func fouls_total() -> int:
	return teams[0].fouls + teams[1].fouls


## Clima do estádio conforme placar e minuto: {side, kind} ou vazio.
func crowd_mood() -> Dictionary:
	var diff := score[0] - score[1]
	var late := half >= 2 and minute >= 78
	if half >= 2 and absi(diff) >= 2 and vis_rng.randf() < 0.6:
		return {"side": 0 if diff > 0 else 1, "kind": "ole"}
	if late and absi(diff) == 1 and vis_rng.randf() < 0.5:
		return {"side": 0 if diff > 0 else 1, "kind": "time"}
	if not neutral and half >= 2 and diff < 0 and vis_rng.randf() < 0.5:
		return {"side": 0, "kind": "boo"}
	if late and diff == 0:
		return {"side": -1, "kind": "tension"}
	if derby and vis_rng.randf() < 0.5:
		return {"side": 0, "kind": "derby"}
	if neutral:
		return {"side": vis_rng.randi_range(0, 1), "kind": "away"}
	if vis_rng.randf() < 0.25:
		return {"side": 1, "kind": "away"}
	return {"side": 0, "kind": "home"}


## Efeito do placar, como na vida real: quem está atrás ocupa o campo e finaliza mais (de
## fora, com a área cheia), quem está na frente recua e acha espaço no contra-ataque.
## Cresce com o tempo de jogo e com a diferença (até 2 gols).
func _game_state() -> void:
	for t: MatchTeam in teams:
		var sm := state_mods(score[t.side] - score[1 - t.side], minute, half)
		t.g_rate = sm[0]
		t.g_quality = sm[1]
		t.g_poss = sm[2]
	for t: MatchTeam in teams:
		t.apply_state(score[t.side] - score[1 - t.side]) # cera de quem vence (instrução de equipe)


## Efeito do placar sobre [taxa de chances, qualidade da chance, posse] de um time com saldo `diff`
## no minuto dado. O mesmo para o minuto a minuto e para o modo rápido.
## Atrás: ocupa o campo e finaliza mais (de fora, com a área cheia); perdendo de muito, desanima.
## Na frente: recua e explora o contra-ataque; com dois ou três gols de vantagem, os dois tiram o pé
## (jogo resolvido: goleadas de 6 ou 7 existem, mas são raras).
## Empate nos minutos finais: ninguém quer se expor (o empate real é mais comum que o sorteio puro).
static func state_mods(diff: int, minute: int, half: int) -> Array:
	if diff == 0:
		return [0.9 if minute >= 80 and half == 2 else 1.0, 1.0, 0.0]
	var t_f := clampf(float(minute) / 90.0, 0.0, 1.3)
	var k := (STATE_BASE + STATE_LATE * t_f) * (1.0 if absi(diff) == 1 else 1.35)
	if diff < 0:
		return [1.0 + k * (1.5 if diff == -1 else STATE_BEATEN), 1.0 - k * 0.5, k * 0.15]
	var rate := 1.0 - k * 0.7
	if diff == 2:
		rate *= STATE_LEAD2
	elif diff >= 3:
		rate *= STATE_LEAD3
	return [rate, 1.0 + k * 0.35, -k * 0.15]


## Recalcula as probabilidades por minuto (chamado quando setores ou táticas mudam).
func _refresh_rates() -> void:
	var h: MatchTeam = teams[0]
	var a: MatchTeam = teams[1]
	var tilt_h := h.m_poss + h.s_poss + h.l_poss + (0.0 if a.s_ignores_press else h.pr_poss) + h.g_poss + h.sh_poss + h.x_poss
	var tilt_a := a.m_poss + a.s_poss + a.l_poss + (0.0 if h.s_ignores_press else a.pr_poss) + a.g_poss + a.sh_poss + a.x_poss
	var x := GAMMA * (h.u_mid - a.u_mid)
	var mu := TacticalMatchup.edges(h.matchup_desc(), a.matchup_desc())
	_poss_base = clampf(1.0 / (1.0 + exp(-x)) + (tilt_h - tilt_a) * 0.8 + 0.02 * crowd + float(mu["poss"]), 0.25, 0.75)
	for s in 2:
		var att: MatchTeam = teams[s]
		var dfn: MatchTeam = teams[1 - s]
		_rate_chance[s] = _chance_prob(att, dfn) * goal_f * float(mu["rate_a" if s == 0 else "rate_b"]) * TacticsManager.clash(att.clash_desc(dfn), dfn.clash_desc(att))
		_rate_foul[s] = _foul_prob(att)
		var direct := att.style == TeamSheet.STYLE_DIRETO or att.style == TeamSheet.STYLE_CONTRA or att.style == TeamSheet.STYLE_LONGA
		_rate_off[s] = 0.028 * dfn.l_offside * (1.25 if direct else 1.0) * dfn.x_offside * att.x_offside_own
		_rate_corner[s] = 0.04 * clampf(0.6 + att.width / 4.0, 0.6, 1.5)


## Quanto a diferença ataque × defesa multiplica as chances: forte perto de zero (times de nível
## parecido se separam bem) e cada vez mais suave nos extremos (goleada existe, mas 6 × 0 é raro).
static func chance_mult(diff: float) -> float:
	var d := signf(diff) * 12.0 * log(1.0 + absf(diff) / 12.0)
	return exp(BETA * d)


func _att_power(t: MatchTeam) -> float:
	return t.u_att * t.m_att * t.sh_att * (1.0 + t.style_fit * MOD_DAMP)


func _def_power(t: MatchTeam) -> float:
	return t.u_def * t.m_def * t.sh_def


func _chance_prob(att: MatchTeam, dfn: MatchTeam) -> float:
	var p := BASE_CHANCE * chance_mult(_att_power(att) - _def_power(dfn))
	p *= att.s_rate * att.g_rate
	# Contra-ataque rende mais contra times que se lançam.
	if att.style == TeamSheet.STYLE_CONTRA and (dfn.mentality >= 3 or dfn.style == TeamSheet.STYLE_POSSE or dfn.style == TeamSheet.STYLE_PRESSAO):
		p *= 1.0 + att.s_vs_open
	# Jogo pelos lados contra formação estreita.
	if att.style == TeamSheet.STYLE_LADOS and dfn.width < 2.0:
		p *= 1.0 + att.s_vs_narrow
	p *= dfn.l_opp_rate * dfn.pr_opp_rate * dfn.sh_opp_rate * att.x_rate * dfn.x_opp_rate
	p *= 1.0 + HOME_CHANCE * crowd if att.side == 0 else 1.0 - AWAY_CHANCE * crowd
	# Time com menos jogadores sofre mais.
	p *= 1.0 + (11 - dfn.on_pitch_count) * 0.08
	p *= 1.0 - (11 - att.on_pitch_count) * 0.06
	return clampf(p, 0.02, 0.6)


func _foul_prob(dfn: MatchTeam) -> float:
	var p := FOUL_RATE * dfn.i_fouls * dfn.pr_fouls * dfn.sh_fouls * dfn.x_fouls * ref_fouls * (1.3 - dfn.discipline / 100.0 * 0.6)
	if derby:
		p *= 1.12
	return clampf(p, 0.05, 0.45)


## Fadiga aplicada em blocos de `minutes` minutos (barato e suficiente).
func _apply_fatigue(t: MatchTeam, minutes: float) -> void:
	var mult: float = FATIGUE_RATE * float(wx_fx["fatigue"]) * (1.25 if half >= 3 else 1.0) * (float(wx.get("away_fatigue", 1.0)) if t.side == 1 else 1.0) * minutes * t.i_fatigue * t.s_fatigue * t.pr_fatigue * t.sh_fatigue * t.x_fatigue
	for mp: MatchPlayer in t.slots:
		if mp == null:
			continue
		var gk_f := (0.35 if mp.slot == 0 else 1.0) * mp.fat_f
		mp.cond = maxf(5.0, mp.cond - mult * (1.25 - mp.a_res / 100.0 * 0.6) * gk_f)
		# Câimbra: perna no limite no fim do jogo e, principalmente, na prorrogação
		if mp.slot != 0 and mp.cond < 32.0 and (half >= 3 or minute >= 80) and rng.randf() < (0.05 if half >= 3 else 0.02) * minutes / 5.0:
			mp.cond = minf(mp.cond, 10.0)
			mp.rating_pts -= 0.1
			_emit(EV_CRAMP, t.side, mp.p.id)


# ---------------------------------------------------------------------------
# Chances e gols
# ---------------------------------------------------------------------------

func _pick_chance_type(att: MatchTeam, dfn: MatchTeam) -> int:
	var w: Array = []
	for i in 6:
		var v: float = _type_w[i] * att.s_types[i] * att.exploit_w[i] * att.t_types[i] * dfn.t_opp_types[i]
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


## Quem pode dar a assistência em cada tipo de jogada: [modo de escolha, chance de haver passe].
## Compartilhado com o modo rápido.
static func assist_profile(ctype: int) -> Array:
	match ctype:
		CH_CROSS, CH_CORNER:
			return [PK_CROSS, 0.9]
		CH_DRIBBLE:
			return [PK_PASS, 0.3]
		CH_LONG:
			return [PK_PASS, 0.45]
		CH_SCRAMBLE:
			return [PK_PASS, 0.35]
		CH_COUNTER:
			return [PK_PASS, 0.7]
		CH_ERROR, CH_FREEKICK, CH_PENALTY:
			return [PK_PASS, 0.0]
	return [PK_PASS, 0.75]


func _pick_assister(att: MatchTeam, ctype: int, shooter: MatchPlayer) -> MatchPlayer:
	var ap := assist_profile(ctype)
	if rng.randf() >= float(ap[1]):
		return null
	for _i in 4:
		var a := _pick_weighted(att, int(ap[0]))
		if a != null and a != shooter:
			return a
	return null


## Resolve uma chance do time `att`. forced_type >= 0 força o tipo (escanteio, falta, pênalti).
func _resolve_chance(att: MatchTeam, dfn: MatchTeam, forced_type: int, forced_shooter: MatchPlayer = null) -> void:
	var s := att.side
	var ctype := forced_type
	# Erro defensivo: zaga indecisa entrega a bola.
	if ctype < 0 and rng.randf() < 0.04 * clampf((75.0 - dfn.avg_decision) / 25.0 + 0.6, 0.4, 1.6) * float(wx_fx["errors"]):
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
	var lane := -1
	var lane_f := 1.0
	if OPEN_PLAY.has(ctype):
		var lp := _pick_lane(att, dfn, ctype)
		lane = int(lp[0])
		lane_f = float(lp[1])
		xr_box[s] += 1
	# Qualidade da chance
	var xg: float = _xg[ctype] * lane_f
	if ctype != CH_PENALTY and ctype != CH_FREEKICK:
		xg *= clampf(exp(DELTA * (_att_power(att) - _def_power(dfn))), 0.6, 1.6)
		xg *= att.s_quality * dfn.l_opp_quality * att.g_quality * att.x_quality * dfn.x_opp_quality
		# Linha alta sofre com atacantes rápidos.
		if dfn.line == 2 and (ctype == CH_THROUGH or ctype == CH_COUNTER):
			xg *= 1.0 + clampf((att.pace_att - dfn.pace_def) / 100.0, 0.0, 0.25)
		# O jogo aéreo decide cruzamentos e escanteios.
		if ctype == CH_CROSS:
			xg *= clampf(exp(0.012 * (att.aerial_att - dfn.aerial_def)), 0.7, 1.4)
		elif ctype == CH_CORNER: # jogada ensaiada: 1º pau, 2º pau ou curto (peso da altura e qualidade)
			xg *= clampf(exp(0.012 * att.x_aerial * (att.aerial_att - dfn.aerial_def)), 0.6, 1.5) * att.x_corner_q
	if ctype == CH_CORNER or ctype == CH_FREEKICK:
		xg *= 1.0 + att.sp_bonus # bola parada ensaiada no treino
	if ctype < 6:
		xg *= att.exploit_q[ctype]
	# Leitura do jogo: onde e como cada time está sofrendo.
	dfn.ct_conc[ctype] += 1
	dfn.xg_conc += xg
	if lane >= 0:
		dfn.lane_conc[2 - lane] += 1
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
	var pk := {}
	if ctype == CH_PENALTY:
		# Cobrança de verdade: canto, goleiro, pressão do momento, cansaço e torcida
		var must := half == 2 and minute >= 80 and score[s] <= score[1 - s]
		pk = PenaltyKick.kick(rng, shooter.p, gk.p if gk != null else null, {"f": shooter.f, "gk_f": gk.f if gk != null else 1.0,
			"cond": shooter.cond, "pressure": clampf(importance * 0.6 + (0.3 if must else 0.0) + (0.15 if derby else 0.0), 0.0, 1.0),
			"away": s == 1 and not neutral, "study": dfn.study})
		p_goal = 1.0 if String(pk["res"]) == "goal" else 0.0
	att.shots += 1
	att.xg += xg
	shooter.shots += 1
	var rec := {}
	if xray_on:
		rec = _xr_record(att, dfn, ctype, lane, xg, shooter, assister)
	var z_from := vis_rng.randf_range(0.45, 0.7)
	if ctype == CH_COUNTER:
		z_from = vis_rng.randf_range(0.2, 0.4)
	elif ctype == CH_CORNER:
		z_from = 0.97
	if rng.randf() < p_goal:
		_goal(att, dfn, shooter, assister, ctype, culprit)
		if not rec.is_empty():
			rec["r"] = "gol"
		if detail:
			last_phase = {"side": s, "from": z_from, "to": 1.0, "ev": EV_GOAL, "ct": ctype}
		return
	var r := rng.randf()
	var ev := EV_MISS
	if ctype == CH_PENALTY:
		if String(pk.get("res", "save")) == "save":
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
	if not rec.is_empty():
		rec["r"] = {EV_SAVE: "defesa", EV_POST: "trave", EV_BLOCK: "bloqueio", EV_PEN_SAVE: "defesa"}.get(ev, "fora")
	if detail:
		var ex := {"ct": ctype, "xg": snappedf(xg, 0.01), "gk": gk.p.id if gk != null else -1}
		if not pk.is_empty():
			ex["res"] = String(pk["res"])
			ex["dir"] = int(pk["dir"])
			ex["dive"] = int(pk["dive"])
		if ev == EV_BLOCK and xg >= 0.1 and vis_rng.randf() < 0.25:
			var cl := _pick_weighted(dfn, PK_DEFEND, vis_rng)
			if cl != null:
				ex["line"] = cl.p.id # salvou em cima da linha
		if ctype != CH_PENALTY and not ex.has("line"):
			var fin := _finish_kind(ctype, ev, shooter, xg)
			if fin != "":
				ex["fin"] = fin
		_emit(ev, s, shooter.p.id, assister.p.id if assister != null else -1, ex)
	if detail:
		last_phase = {"side": s, "from": z_from, "to": vis_rng.randf_range(0.85, 0.98), "ev": ev, "ct": ctype}
	if (ev == EV_SAVE and rng.randf() < 0.3) or (ev == EV_BLOCK and rng.randf() < 0.4):
		_corner(att, dfn)


# ---------------------------------------------------------------------------
# Variações de lance (só apresentação: vis_rng e só com detail)
# ---------------------------------------------------------------------------

## Como o lance termina na tela e na narração: cavadinha, voleio, bicicleta, rebote, arrancada,
## travessão, defesa dupla, gol anulado pelo VAR... O placar, as finalizações e o xG já foram
## decididos antes; aqui só se escolhe a encenação, pelo tipo de jogada e pelas qualidades de
## quem finaliza. "" = encenação padrão.
func _finish_kind(ctype: int, ev: int, shooter: MatchPlayer, xg: float) -> String:
	var tec := shooter.a_tec if shooter != null else 50.0
	var vel := shooter.a_vel if shooter != null else 50.0
	var opts: Array = []
	match ev:
		EV_GOAL:
			match ctype:
				CH_THROUGH:
					opts = [["", 3.0], ["chip", 0.6 + maxf(0.0, tec - 65.0) / 25.0], ["round_gk", 0.9], ["rebound", 0.7], ["near", 0.6]]
				CH_CROSS:
					opts = [["", 2.6], ["diving", 0.8], ["volley", 0.5 + maxf(0.0, tec - 65.0) / 30.0], ["flick", 0.7],
						["bicycle", 0.12 if tec >= 70.0 else 0.0]]
				CH_LONG:
					opts = [["", 1.6], ["screamer", 1.4], ["curler", 1.2], ["deflected", 0.6]]
				CH_DRIBBLE:
					opts = [["", 2.0], ["solo", 0.35 + maxf(0.0, vel - 68.0) / 20.0], ["cut_inside", 1.2], ["round_gk", 0.6]]
				CH_COUNTER:
					opts = [["", 2.0], ["square", 1.3], ["chip", 0.5], ["solo", 0.25 + maxf(0.0, vel - 72.0) / 25.0]]
				CH_SCRAMBLE:
					opts = [["", 1.5], ["rebound", 1.5], ["tap_in", 1.2], ["deflected", 0.6]]
				CH_CORNER:
					opts = [["", 2.5], ["flick", 0.8], ["volley", 0.5], ["diving", 0.4]]
				CH_FREEKICK:
					opts = [["top_corner", 2.0], ["under_wall", 0.5], ["power", 1.0], ["", 0.8]]
		EV_SAVE:
			match ctype:
				CH_CROSS, CH_CORNER:
					opts = [["", 2.0], ["reflex", 1.0], ["punch", 1.0]]
				CH_LONG, CH_FREEKICK:
					opts = [["", 1.6], ["fingertip", 1.6]]
				CH_THROUGH, CH_COUNTER, CH_DRIBBLE, CH_ERROR:
					opts = [["", 2.0], ["one_on_one", 1.4 if xg >= 0.15 else 0.4], ["reflex", 0.7], ["double", 0.35]]
				_:
					opts = [["", 2.0], ["reflex", 1.0], ["double", 0.5]]
		EV_MISS:
			if xg >= 0.12 and vis_rng.randf() < 0.06:
				return "var_off" # a bola entrou, mas o VAR anula (no placar sempre foi para fora)
			match ctype:
				CH_FREEKICK:
					opts = [["", 1.0], ["wall", 1.4]]
				CH_CROSS, CH_CORNER:
					opts = [["", 2.0], ["header_over", 1.0]]
				_:
					opts = [["", 2.0], ["sky", 0.6 if xg >= 0.2 else 0.2], ["fresh_air", 0.12]]
		EV_POST:
			opts = [["", 1.4], ["bar", 1.2], ["inside_out", 0.35]]
		EV_BLOCK:
			opts = [["", 2.0], ["last_ditch", 0.9]]
	if opts.is_empty():
		return ""
	var w: Array = []
	for o in opts:
		w.append(float(o[1]))
	var i := RngUtil.weighted_index(vis_rng, w)
	return String(opts[i][0]) if i >= 0 else ""


## Como saiu o pênalti (só narração e encenação): arrancada na área, calço, puxão, mão na bola
## ou carrinho atrasado.
func _penalty_how(victim: MatchPlayer) -> Dictionary:
	var dri := victim.a_tec if victim != null else 50.0
	var w := [0.8 + maxf(0.0, dri - 60.0) / 15.0, 1.0, 0.6, 0.7, 0.5]
	var i := RngUtil.weighted_index(vis_rng, w)
	return {"how": ["dribble", "trip", "pull", "hand", "late"][maxi(0, i)]}


## Registro da chance para o Raio-X, com o contexto do corredor do lado de quem defendeu:
## lateral que estava no ataque, ponta que não voltou, superioridade de 2 contra 1.
func _xr_record(att: MatchTeam, dfn: MatchTeam, ctype: int, lane: int, xg: float, shooter: MatchPlayer, assister: MatchPlayer) -> Dictionary:
	var rec := {"m": minute, "s": att.side, "l": lane, "ct": ctype, "xg": snappedf(xg, 0.01), "sh": shooter.p.id,
		"as": assister.p.id if assister != null else -1, "r": "fora"}
	if lane >= 0:
		var dl := 2 - lane # o corredor de quem defende
		var fb: MatchPlayer = null
		var wing: MatchPlayer = null
		var defenders := 0
		for mp: MatchPlayer in dfn.slots:
			if mp == null or mp.slot == 0 or dfn.lane_of(mp) != dl:
				continue
			if mp.w_def >= 0.4:
				defenders += 1
			if mp.role == "FB" or mp.role == "WB":
				fb = mp
			elif mp.role == "W" or mp.role == "WM":
				wing = mp
		var attackers := 0
		for mp: MatchPlayer in att.slots:
			if mp != null and mp.slot != 0 and att.lane_of(mp) == lane and mp.w_att >= 0.3:
				attackers += 1
		if fb != null:
			rec["fb"] = fb.p.id
			rec["fb_up"] = fb.w_att >= 0.25
		if wing != null:
			rec["wg"] = wing.p.id
			rec["wg_off"] = wing.w_def < 0.15
		rec["x2"] = lane != 1 and attackers >= 2 and defenders <= 1
	xr_chances.append(rec)
	return rec


## Cada gol muda a cabeça de quem está em campo: os determinados crescem atrás do placar,
## os que não são se entregam (personalidade oculta).
func _score_mood() -> void:
	for side in 2:
		var diff: int = score[side] - score[1 - side]
		for mp: MatchPlayer in teams[side].all:
			mp.sc_f = HiddenPersona.score_factor(mp.p, diff)


func _goal(att: MatchTeam, dfn: MatchTeam, shooter: MatchPlayer, assister: MatchPlayer, ctype: int, culprit: MatchPlayer) -> void:
	var s := att.side
	var before_diff := score[s] - score[1 - s]
	var own_goal := false
	# Gol contra: cruzamento ou escanteio desviado pela zaga (~3% dos gols, como na vida real).
	if (ctype == CH_CROSS or ctype == CH_CORNER) and rng.randf() < OWN_GOAL_P:
		var og := _pick_weighted(dfn, PK_DEFEND)
		if og != null:
			own_goal = true
			og.own_goals += 1
			og.rating_pts -= 1.0
			shooter = og
			assister = null
	score[s] += 1
	_score_mood()
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
	_game_state()
	_refresh_rates()
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
	if not own_goal and (ctype == CH_LONG or ctype == CH_FREEKICK or (ctype == CH_DRIBBLE and shooter.attr(Attr.DRI) >= 70)) and rng.randf() < 0.6:
		tags.append("golaco")
	if ctype == CH_ERROR:
		tags.append("error")
	if ctype == CH_COUNTER:
		tags.append("counter")
	half_events += 1
	var gx := {"ct": ctype, "imp": imp, "tags": tags, "culprit": culprit.p.id if culprit != null else -1}
	if detail and not own_goal:
		var fin := _finish_kind(ctype, EV_GOAL, shooter, 0.0)
		if fin != "":
			gx["fin"] = fin
	_emit(EV_OWN_GOAL if own_goal else EV_GOAL, s, shooter.p.id, assister.p.id if assister != null else -1, gx)
	if detail:
		if vis_rng.randf() < 0.2:
			_emit(EV_VAR, s, shooter.p.id, -1, {"kind": "goal_ok"})
		if imp >= 0.55 and vis_rng.randf() < 0.45:
			_emit(EV_CROWD, 1 - s, -1, -1, {"kind": "coach"})


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
	var p_yellow := 0.155 * fouler.card_mult * card_f * (1.4 - dis / 100.0) * (1.15 if dfn.intensity == 2 else 1.0) * dfn.x_cards
	var p_red := 0.0026 * fouler.card_mult * card_f * (1.3 - dis / 100.0)
	if dangerous:
		p_yellow *= 1.3
	if fouler.yellow >= 1:
		p_yellow *= 0.45 # pendurado alivia na dividida (e o juiz pensa duas vezes antes do segundo)
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
	elif detail and victim != null and victim.on_pitch and vis_rng.randf() < 0.07:
		_emit(EV_KNOCK, att.side, fouler.p.id, victim.p.id)
	if dangerous:
		if rng.randf() < 0.045 * ref_pens:
			_emit(EV_PENALTY_AWARDED, att.side, victim.p.id if victim != null else -1, fouler.p.id, _penalty_how(victim) if detail else {})
			if detail and vis_rng.randf() < 0.35:
				_emit(EV_VAR, att.side, victim.p.id if victim != null else -1, fouler.p.id, {"kind": "pen_ok"})
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
			base *= 0.4
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
				v = mp.attr(Attr.FIN) * 0.45 + mp.attr(Attr.FRI) * 0.35 + mp.attr(Attr.DEC) * 0.1 + mp.attr(Attr.INT) * 0.1
			"fk":
				v = mp.attr(Attr.CHL) * 0.45 + mp.attr(Attr.TEC) * 0.35 + mp.attr(Attr.PAS) * 0.2
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
	# Técnico reage à expulsão: quem ficou com dez fecha a casinha (se não estiver perdendo no
	# fim); o rival com um a mais se lança.
	var o: MatchTeam = teams[1 - t.side]
	var d0: int = score[t.side] - score[o.side]
	if not t.is_user and not (d0 < 0 and minute >= 70) and t.mentality > 1:
		set_mentality(t.side, t.mentality - 1)
	if not o.is_user and d0 >= 0 and o.mentality < 3:
		set_mentality(o.side, o.mentality + 1)
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
	if rng.randf() < 0.28 * att.x_corner_ch * (1.0 + att.sp_bonus * 0.5):
		_resolve_chance(att, dfn, CH_CORNER)


func _offside(att: MatchTeam) -> void:
	att.offsides += 1
	var who := _pick_weighted(att, PK_SHOOT)
	if detail and who != null:
		_emit(EV_OFFSIDE, att.side, who.p.id, -1, {"goal": true} if vis_rng.randf() < 0.1 else {})
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
	if t.is_user:
		xr_mark("Entrou %s" % in_mp.p.short_name())
	return ""


# ---------------------------------------------------------------------------
# Gritos da beira do campo
# ---------------------------------------------------------------------------

## Duração do efeito e intervalo mínimo entre dois gritos (minutos de jogo).
const SHOUT_MINUTES := 10
const SHOUT_COOLDOWN := 6
## Efeito de cada grito (multiplicadores; "poss" soma à inclinação da posse). "rx": reação
## individual ("inc" incentivo, "cob" cobrança) que depende da personalidade e do placar.
const SHOUTS := {
	"pressao": {"name": "Pressão lá na frente!", "short": "Pressão", "icon": "bolt", "desc": "Rouba a bola mais alto. Cansa e faz mais faltas.",
		"opp_rate": 0.93, "poss": 0.02, "fouls": 1.18, "fatigue": 1.35},
	"calma": {"name": "Calma, toca a bola!", "short": "Calma", "icon": "clock", "desc": "Mais posse e menos faltas; ataca um pouco menos.",
		"poss": 0.035, "att": 0.97, "fouls": 0.88, "fatigue": 0.9},
	"frente": {"name": "Pra frente! Vamos buscar!", "short": "Pra frente", "icon": "up", "desc": "Mais gente no ataque. Deixa espaço atrás.",
		"att": 1.09, "def": 0.94, "fatigue": 1.1},
	"atencao": {"name": "Concentração atrás!", "short": "Atenção", "icon": "shield", "desc": "Fecha a defesa; o ataque perde força.",
		"def": 1.06, "att": 0.96},
	"incentivo": {"name": "Vamos, acredita!", "short": "Incentivar", "icon": "heart", "desc": "Levanta quem está abatido. Rende mais atrás no placar.", "rx": "inc"},
	"cobranca": {"name": "Cobrar o time", "short": "Cobrar", "icon": "whistle", "desc": "Líderes respondem; os mais sensíveis podem sentir.", "rx": "cob"},
}
const SHOUT_ORDER: Array[String] = ["pressao", "calma", "frente", "atencao", "incentivo", "cobranca"]


## Minutos até poder gritar de novo (0 = liberado).
func shout_wait(side: int) -> int:
	return maxi(0, teams[side].sh_next - minute)


## O técnico grita da beira do campo. Efeito por SHOUT_MINUTES; repetir o mesmo grito rende
## cada vez menos (o time para de ouvir). Retorna {"ok", "msg", "react": [[player_id, +1/-1]]}.
func shout(side: int, key: String) -> Dictionary:
	if finished or not started or not SHOUTS.has(key):
		return {"ok": false, "msg": "Agora não dá."}
	var t: MatchTeam = teams[side]
	if minute < t.sh_next:
		return {"ok": false, "msg": "O time ainda está digerindo o último grito (%d')." % (t.sh_next - minute)}
	_clear_shout(t)
	var cfg: Dictionary = SHOUTS[key]
	var used := int(t.sh_uses.get(key, 0))
	t.sh_uses[key] = used + 1
	var eff := 1.0 / (1.0 + 0.6 * used)
	t.sh_key = key
	t.sh_until = minute + SHOUT_MINUTES
	t.sh_next = minute + SHOUT_COOLDOWN
	t.sh_att = 1.0 + (float(cfg.get("att", 1.0)) - 1.0) * eff
	t.sh_def = 1.0 + (float(cfg.get("def", 1.0)) - 1.0) * eff
	t.sh_poss = float(cfg.get("poss", 0.0)) * eff
	t.sh_fouls = 1.0 + (float(cfg.get("fouls", 1.0)) - 1.0) * eff
	t.sh_fatigue = 1.0 + (float(cfg.get("fatigue", 1.0)) - 1.0) * eff
	t.sh_opp_rate = 1.0 + (float(cfg.get("opp_rate", 1.0)) - 1.0) * eff
	var react: Array = []
	var rx := String(cfg.get("rx", ""))
	if rx != "":
		var diff := score[side] - score[1 - side]
		for mp: MatchPlayer in t.slots:
			if mp == null:
				continue
			var d := _shout_reaction(mp, rx, diff) * eff
			mp.sh_f = 1.0 + d
			if absf(d) >= 0.03:
				react.append([mp.p.id, 1 if d > 0 else -1])
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"shout": key, "react": react})
	if t.is_user:
		xr_mark("Grito: %s" % String(cfg["short"]).to_lower())
	var msg := "\"%s\"" % String(cfg["name"])
	if used >= 2:
		msg += " O time já não escuta como antes."
	return {"ok": true, "msg": msg, "react": react}


## Reação de um jogador ao incentivo ou à cobrança: personalidade, moral e placar.
func _shout_reaction(mp: MatchPlayer, rx: String, diff: int) -> float:
	var p := mp.p
	var sensitive := p.has_trait("timido") or p.has_trait("inseguro") or p.hid("pre") <= 5
	var hard := p.has_trait("lider") or p.has_trait("cascudo") or p.has_trait("competitivo") or p.has_trait("profissional") or p.hid("det") >= 16
	var low := p.morale < 45.0
	if rx == "inc":
		var d := 0.015
		if diff < 0:
			d += 0.015
		if sensitive or low:
			d += 0.02
		if p.has_trait("estrela") or p.has_trait("acomodado"):
			d -= 0.01
		return d
	# Cobrança
	var c := 0.01
	if hard:
		c = 0.04
	if sensitive or low:
		c = -0.035
	if HiddenPersona.hot_head(p):
		c = -0.02
		mp.card_mult *= 1.15 # esquenta
	if diff > 0:
		c -= 0.01 # cobrar ganhando soa injusto
	return c


# ---------------------------------------------------------------------------
# Palestra no vestiário (antes do jogo e no intervalo)
# ---------------------------------------------------------------------------

const TALKS := {
	"motivar": {"name": "Vamos pra cima, o jogo é nosso!", "short": "Motivar", "desc": "Acende o time. Rende mais para quem está atrás ou é azarão."},
	"tranquilizar": {"name": "Calma, joguem o nosso jogo.", "short": "Tranquilizar", "desc": "Tira o peso dos mais nervosos. Bom em jogo grande ou vencendo."},
	"elogiar": {"name": "Estão de parabéns, continuem assim.", "short": "Elogiar", "desc": "Mantém o embalo de quem está bem. Perdendo, soa acomodado."},
	"exigir": {"name": "Só a vitória interessa hoje.", "short": "Exigir vitória", "desc": "Líderes crescem; os inseguros sentem. Pesa mais quando se é favorito."},
	"sem_pressao": {"name": "Sem pressão. Divirtam-se.", "short": "Sem pressão", "desc": "Solta o azarão. Para o favorito, pode relaxar demais."},
	"cobrar": {"name": "Isso está inaceitável!", "short": "Cobrar", "desc": "Chacoalha quem está mal. Ganhando, é injusto e pesa contra."},
}
const TALK_ORDER: Array[String] = ["motivar", "tranquilizar", "elogiar", "exigir", "sem_pressao", "cobrar"]


## Dá para falar com o time agora? Antes do pontapé inicial ou no intervalo, uma vez por pausa.
func can_talk(side: int) -> bool:
	if finished:
		return false
	var at := 0 if not started else half
	if started and not (halftime_pending or et_pending):
		return false
	return teams[side].talk_half != at


## Palestra: reação individual pela personalidade, moral, placar, favoritismo e peso do jogo.
## Vale até a próxima palestra. Retorna {"ok", "msg", "up": [ids], "down": [ids]}.
func team_talk(side: int, key: String) -> Dictionary:
	if not TALKS.has(key) or not can_talk(side):
		return {"ok": false, "msg": "Agora não dá para falar com o time."}
	var t: MatchTeam = teams[side]
	var o: MatchTeam = teams[1 - side]
	t.talk_half = 0 if not started else half
	t.talk_key = key
	var diff := score[side] - score[1 - side]
	var fav := (t.u_att + t.u_mid + t.u_def) - (o.u_att + o.u_mid + o.u_def) # >0: somos favoritos
	var up: Array = []
	var down: Array = []
	for mp: MatchPlayer in t.all:
		var d := _talk_reaction(mp.p, key, diff, fav)
		mp.talk_f = 1.0 + d
		if not mp.on_pitch:
			continue
		if d >= 0.025:
			up.append(mp.p.id)
		elif d <= -0.02:
			down.append(mp.p.id)
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"talk": key, "up": up, "down": down})
	var msg := "Palestra: \"%s\"" % String(TALKS[key]["name"])
	if up.size() > down.size() + 2:
		msg += " O vestiário comprou a ideia."
	elif down.size() > up.size():
		msg += " Nem todo mundo gostou."
	return {"ok": true, "msg": msg, "up": up, "down": down}


func _talk_reaction(p: Player, key: String, diff: int, fav: float) -> float:
	var sensitive := p.has_trait("timido") or p.has_trait("inseguro") or p.hid("pre") <= 5
	var hard := p.has_trait("lider") or p.has_trait("cascudo") or p.has_trait("competitivo") or p.has_trait("profissional") or p.hid("det") >= 16
	var loose := p.has_trait("acomodado") or p.has_trait("festeiro")
	var low := p.morale < 45.0
	var big := importance >= 0.6 or derby
	var d := 0.0
	match key:
		"motivar":
			d = 0.012 + (0.015 if diff < 0 else 0.0) + (0.012 if fav < -3.0 else 0.0) - (0.01 if diff >= 2 else 0.0)
			if p.has_trait("competitivo") or p.has_trait("estrela"):
				d += 0.008
		"tranquilizar":
			d = 0.006 + (0.02 if sensitive or low else 0.0) + (0.01 if big else 0.0) + (0.006 if diff > 0 else 0.0) - (0.012 if diff < 0 else 0.0)
		"elogiar":
			d = (0.02 if diff > 0 else (0.004 if diff == 0 else -0.015))
			if loose and diff > 0:
				d -= 0.02 # relaxa
			if sensitive:
				d += 0.008
		"exigir":
			d = 0.01 + (0.008 if fav > 3.0 else 0.0)
			if hard:
				d += 0.02
			if sensitive or low:
				d = -0.03 - (0.01 if big else 0.0)
		"sem_pressao":
			d = (0.018 if fav < -3.0 else -0.004) + (0.012 if sensitive else 0.0)
			if loose:
				d -= 0.02 if fav > 0.0 else 0.0
		"cobrar":
			d = (0.02 if diff < 0 else (-0.006 if diff == 0 else -0.025))
			if hard:
				d += 0.015
			if sensitive or low:
				d = -0.035
			if HiddenPersona.hot_head(p):
				d -= 0.015
	return clampf(d, -0.05, 0.05)


func _clear_shout(t: MatchTeam) -> void:
	if t.sh_key == "":
		return
	t.sh_key = ""
	t.sh_until = -1
	t.sh_att = 1.0
	t.sh_def = 1.0
	t.sh_poss = 0.0
	t.sh_fouls = 1.0
	t.sh_fatigue = 1.0
	t.sh_opp_rate = 1.0
	for mp: MatchPlayer in t.all:
		mp.sh_f = 1.0
	t.recompute_units()
	_refresh_rates()


func set_mentality(side: int, m: int) -> void:
	var t: MatchTeam = teams[side]
	if t.mentality == m:
		return
	t.mentality = clampi(m, 0, 4)
	t.refresh_tactics()
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"mentality": t.mentality})
	if t.is_user:
		xr_mark("Mentalidade %s" % String(DatabaseManager.tactics()["mentalities"][t.mentality]["name"]).to_lower())


func set_style(side: int, st: int) -> void:
	var t: MatchTeam = teams[side]
	if t.style == st:
		return
	t.style = clampi(st, 0, 5)
	_refresh_fam(t)
	t.refresh_tactics()
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"style": t.style})
	if t.is_user:
		xr_mark("Estilo %s" % String(DatabaseManager.tactics()["styles"][t.style]["short"]).to_lower())


## Troca o desenho tático durante o jogo. Quem está em campo é redistribuído pelas vagas novas
## (cada um onde rende mais); o goleiro fica no gol. Não gasta substituição, mas uma formação
## pouco treinada rende menos (entrosamento). Retorna false se nada mudou.
func set_formation(side: int, fname: String) -> bool:
	var t: MatchTeam = teams[side]
	if fname == t.formation_name or not DatabaseManager.has_formation(fname):
		return false
	var nf := DatabaseManager.formation(fname)
	var fslots: Array = nf["slots"]
	var field: Array[MatchPlayer] = []
	for i in range(1, t.slots.size()):
		if t.slots[i] != null:
			field.append(t.slots[i])
	var new_slots: Array[MatchPlayer] = []
	new_slots.resize(fslots.size())
	new_slots[0] = t.slots[0] if t.slots.size() > 0 else null
	# Pares (jogador, vaga) do melhor encaixe para o pior; cada um fica com o melhor que sobrar.
	var pairs: Array = []
	for mp: MatchPlayer in field:
		for i in range(1, fslots.size()):
			var pos: int = fslots[i]["pos"]
			# Leve preferência por vagas parecidas com a atual (menos bagunça na troca).
			var near := 1.5 if pos == mp.pos else 0.0
			pairs.append([mp.p.rating_at(pos) + near, mp, i])
	pairs.sort_custom(func(a, b): return a[0] > b[0])
	var placed := {}
	for pr in pairs:
		var mp: MatchPlayer = pr[1]
		var i: int = pr[2]
		if placed.has(mp) or new_slots[i] != null:
			continue
		placed[mp] = true
		new_slots[i] = mp
	for i in fslots.size():
		var mp: MatchPlayer = new_slots[i]
		if mp != null:
			_assign_slot(mp, i, fslots[i])
	t.formation = nf
	t.formation_name = fname
	t.formation_changed = true
	t.slots = new_slots
	_refresh_fam(t)
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, side, -1, -1, {"formation": fname})
	if t.is_user:
		xr_mark("Mudou para %s" % DatabaseManager.formation_base(fname))
	return true


func set_pressing(side: int, v: int) -> void:
	var t: MatchTeam = teams[side]
	v = clampi(v, 0, 2)
	if t.pressing == v:
		return
	t.pressing = v
	_retune(t, {"pressing": v}, "Pressão %s" % String(DatabaseManager.tactics()["pressing"][v]["name"]).to_lower())


func set_line(side: int, v: int) -> void:
	var t: MatchTeam = teams[side]
	v = clampi(v, 0, 2)
	if t.line == v:
		return
	t.line = v
	_retune(t, {"line": v}, "Linha %s" % String(DatabaseManager.tactics()["line"][v]["name"]).to_lower())


func set_width(side: int, v: int) -> void:
	var t: MatchTeam = teams[side]
	v = clampi(v, 0, 2)
	if t.width_i == v:
		return
	t.width_i = v
	_retune(t, {"width": v}, "Largura: %s" % TeamSheet.WIDTH_NAMES[v].to_lower())


func set_intensity(side: int, v: int) -> void:
	var t: MatchTeam = teams[side]
	v = clampi(v, 0, 2)
	if t.intensity == v:
		return
	t.intensity = v
	_retune(t, {"intensity": v}, "Intensidade %s" % String(DatabaseManager.tactics()["intensity"][v]["name"]).to_lower())


## Instrução de equipe no meio do jogo (key = TacticsManager.DEEP: "tempo", "passing"...).
func set_deep(side: int, key: String, v: int) -> void:
	var t: MatchTeam = teams[side]
	var k := TacticsManager.DEEP.find(key)
	if k < 0:
		return
	v = clampi(v, 0, TacticsManager.deep_options(key).size() - 1)
	if int(t.deep[k]) == v:
		return
	t.set_deep(k, v)
	_retune(t, {key: v}, "%s: %s" % [String(TacticsManager.DEEP_TITLES[key]), TacticsManager.deep_name(key, v).to_lower()])


## Instrução individual no meio do jogo ("" tira a instrução).
func set_instruction(side: int, pid: int, key: String) -> void:
	var t: MatchTeam = teams[side]
	var mp: MatchPlayer = t.by_id.get(pid, null)
	if mp == null or not mp.on_pitch or mp.slot <= 0:
		return
	var ins: Dictionary = TeamSheet.INSTRUCTIONS.get(key, {})
	if ins == mp.instr:
		return
	mp.instr = ins
	_assign_slot(mp, mp.slot, t.formation["slots"][mp.slot])
	_retune(t, {"instr": key}, "%s: %s" % [mp.p.display_name(), String(ins.get("name", "sem instrução")).to_lower()], pid)


func _retune(t: MatchTeam, x: Dictionary, label: String, pid: int = -1) -> void:
	t.refresh_tactics()
	t.recompute_units()
	_refresh_rates()
	_emit(EV_TACTIC, t.side, pid, -1, x)
	if t.is_user:
		xr_mark(label)


## O técnico da IA lê o jogo (no intervalo e duas vezes no segundo tempo) e corrige o que está
## dando errado: cansaço, pressão sofrida, linha alta contra velocistas, um lado que só sofre,
## domínio sem gol, bloco baixo que não se abre. No máximo uma mudança por leitura; técnico
## que estuda mais (TacticalScout.study) enxerga mais e reage mais.
func _ai_read(t: MatchTeam) -> void:
	if t.ai_reads >= 4 or t.on_pitch_count < 10:
		return
	t.ai_reads += 1
	if rng.randf() > 0.3 + t.study * 0.65:
		return
	var o: MatchTeam = teams[1 - t.side]
	var diff: int = score[t.side] - score[o.side]
	var poss := possession_pct(t.side)
	var cond := 0.0
	var n := 0
	for mp: MatchPlayer in t.slots:
		if mp != null and mp.slot > 0:
			cond += mp.cond
			n += 1
	cond /= maxf(1.0, n)
	var conc_total: int = t.lane_conc[0] + t.lane_conc[1] + t.lane_conc[2]
	# 1. Fôlego: pressão e intensidade não se sustentam
	if t.pressing == 2 and cond < 68.0:
		set_pressing(t.side, 1)
		return
	if t.intensity == 2 and cond < 64.0:
		set_intensity(t.side, 1)
		return
	# 2. Sufocado pela pressão rival: ligação direta
	if (o.pressing == 2 or o.style == TeamSheet.STYLE_PRESSAO) and poss < 0.42 and t.press_tech < o.press_tech and t.style != TeamSheet.STYLE_LONGA and t.adapt >= 0.4:
		set_style(t.side, TeamSheet.STYLE_LONGA)
		return
	# 3. Linha alta sofrendo com bolas nas costas
	if t.line == 2 and t.ct_conc[CH_THROUGH] + t.ct_conc[CH_COUNTER] >= 3:
		set_line(t.side, 1)
		return
	# 4. Um lado que só sofre: quem joga ali segura a posição
	if conc_total >= 4:
		for l in 3:
			if l != 1 and t.lane_conc[l] >= 3 and float(t.lane_conc[l]) / conc_total >= 0.55:
				var who := _lane_player(t, l)
				if who != null and String(who.instr.get("name", "")) != String(TeamSheet.INSTRUCTIONS["segurar"]["name"]):
					set_instruction(t.side, who.p.id, "segurar")
					return
	# 5. Domina e não marca: abre o campo
	if diff <= 0 and t.xg - o.xg >= 0.8 and t.width_i < 2:
		set_width(t.side, 2)
		return
	# 6. Bloco baixo do rival que não se abre: jogo pelos lados
	if diff <= 0 and o.line == 0 and o.mentality <= TeamSheet.MENT_DEFENSIVA and t.xg < 0.6 and t.style == TeamSheet.STYLE_POSSE and t.adapt >= 0.4:
		set_style(t.side, TeamSheet.STYLE_LADOS)
		return
	# 7. Vencendo e sofrendo muito: baixa a linha e fecha o meio
	if diff > 0 and o.xg - t.xg >= 0.7 and t.line > 0:
		set_line(t.side, t.line - 1)


## Lateral (ou ala/meia aberto) que cobre o corredor `lane` (do ponto de vista de quem defende).
func _lane_player(t: MatchTeam, lane: int) -> MatchPlayer:
	var best: MatchPlayer = null
	for mp: MatchPlayer in t.slots:
		if mp == null or mp.slot <= 0 or t.lane_of(mp) != lane:
			continue
		if mp.role == "FB" or mp.role == "WB":
			return mp
		if best == null or mp.w_def > best.w_def:
			best = mp
	return best


## Entrosamento com a formação/estilo em uso agora (muda quando o técnico mexe no time).
func _refresh_fam(t: MatchTeam) -> void:
	var fam := (TacticsManager.formation_fam(t.club, t.formation_name) + TacticsManager.style_fam(t.club, t.style)) * 0.5
	t.cohesion_f = t.cohesion_base * (TacticsManager.FAM_MIN_F + TacticsManager.FAM_SPAN * fam / 100.0)


## Soma dos pesos de ataque (ou defesa) das vagas de uma formação.
static func formation_weight(fname: String, key: String) -> float:
	var total := 0.0
	for sl in DatabaseManager.formation(fname)["slots"]:
		total += float(sl[key])
	return total


## A IA mexe no desenho uma vez, no fim do jogo: perdendo, vai para o ataque;
## segurando vitória magra nos minutos finais, fecha a casinha.
func _ai_formation(t: MatchTeam) -> void:
	if t.formation_changed or t.on_pitch_count < 10:
		return
	var diff: int = score[t.side] - score[1 - t.side]
	var key := ""
	if diff < 0 and (minute == 72 or minute == 82):
		key = "att"
	elif diff == 1 and minute == 84:
		key = "def"
	# Nem todo técnico mexe no desenho: alguns só trocam peças ou a mentalidade.
	if key == "" or rng.randf() > (0.45 if key == "att" else 0.3):
		return
	var best := t.formation_name
	# Só troca se for bem diferente do que já está em campo.
	var best_v := formation_weight(best, key) + TacticsManager.formation_fam(t.club, best) / 100.0 * 0.3 + 0.4
	for fname in DatabaseManager.formation_names():
		var v := formation_weight(fname, key)
		# Prefere o que o time já conhece.
		v += TacticsManager.formation_fam(t.club, fname) / 100.0 * 0.3
		if v > best_v:
			best_v = v
			best = fname
	if best != t.formation_name:
		set_formation(t.side, best)


func _ai_decisions() -> void:
	if half >= 2:
		for t: MatchTeam in teams:
			if t.is_user:
				_user_plan(t)
	# Primeiro tempo: quem está levando um baile não espera o intervalo para mexer.
	if half == 1 and minute == 32:
		for t: MatchTeam in teams:
			if not t.is_user and (score[t.side] - score[1 - t.side] <= -2 or teams[1 - t.side].xg - t.xg >= 1.0):
				_ai_read(t)
	if half != 2:
		return
	for t: MatchTeam in teams:
		# Conversa do intervalo: o técnico corrige o que viu no primeiro tempo.
		if minute == 46 and not t.is_user:
			_ai_read(t)
		if (minute == 60 or minute == 68 or minute == 76 or minute == 84) and (not t.is_user or t.auto_subs):
			_auto_subs(t)
		if t.is_user:
			continue
		if minute == 58 or minute == 70:
			_ai_read(t)
		_ai_formation(t)
		if minute % 5 == 0 and minute >= 55:
			var target := ai_target_mentality(t.base_mentality, score[t.side] - score[1 - t.side], minute, _rel_strength(t))
			if target != t.mentality:
				set_mentality(t.side, target)


## Diferença de nível em campo agora (setores de quem está jogando, com cansaço e expulsões):
## positivo = `t` é melhor que o rival. Na escala dos setores (~ pontos de atributo).
func _rel_strength(t: MatchTeam) -> float:
	var o: MatchTeam = teams[1 - t.side]
	return (t.u_att + t.u_mid + t.u_def) / 3.0 - (o.u_att + o.u_mid + o.u_def) / 3.0 + (o.on_pitch_count - t.on_pitch_count) * -4.0


## Mentalidade que o técnico da IA quer com este placar, minuto e diferença de nível (rel > 0: o time
## é melhor). O favorito que empata ou perde se lança mais cedo; o azarão que vence se fecha antes e
## aceita o empate; ninguém se fecha com dois gols de vantagem antes da hora.
static func ai_target_mentality(base: int, diff: int, minute: int, rel: float) -> int:
	var fav := rel >= 3.0
	var dog := rel <= -3.0
	if minute < 60 and not (fav and diff < 0):
		return base
	if diff < 0:
		if diff <= -3 and minute >= 70:
			return mini(base, 2) # jogo perdido: evita o vexame
		if minute >= 80:
			return 4
		return maxi(base, 3)
	if diff == 0:
		if fav and minute >= 70:
			return maxi(base, 3)
		if dog and minute >= 75:
			return mini(base, 1) # o ponto fora de casa contra o grande vale muito
		return base
	if diff == 1:
		if minute >= (65 if dog else 75):
			return mini(base, 1)
		return base
	return mini(base, 2)


## Plano de jogo do usuário: muda a mentalidade quando o placar muda de situação
## (perdendo / empatando / vencendo) a partir do minuto escolhido. Só age na mudança,
## então uma troca manual no meio do jogo é respeitada até o placar mudar de novo.
func _user_plan(t: MatchTeam) -> void:
	var sh := t.sheet
	if (sh.plan_losing < 0 and sh.plan_winning < 0) or minute < sh.plan_minute:
		return
	var diff: int = score[t.side] - score[1 - t.side]
	var state := signi(diff) + 1
	if state == t.plan_state:
		return
	t.plan_state = state
	var target := t.base_mentality
	if diff < 0 and sh.plan_losing >= 0:
		target = sh.plan_losing
	elif diff > 0 and sh.plan_winning >= 0:
		target = sh.plan_winning
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
	# Sai primeiro quem está gasto, quem está jogando mal e quem está pendurado com cartão.
	var urgency := func(mp: MatchPlayer) -> float:
		return mp.cond + mp.rating_pts * 8.0 - (12.0 if mp.yellow > 0 and mp.w_def >= 0.5 else 0.0)
	cands.sort_custom(func(a, b): return urgency.call(a) < urgency.call(b))
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
		if mp.rating_pts <= -0.8:
			need -= 0.06 # jogando mal: troca mesmo que o reserva seja um pouco pior
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
		var team_bonus := RATING_WIN if diff > 0 else (RATING_LOSS if diff < 0 else 0.0)
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
			mp.final_rating = rating_from(pts, team_bonus, perf_c, rng.randfn(0.0, 0.25), mins)


## Nota do jogo no estilo das plataformas de estatística: começa perto de 6,6, os lances somam
## com retorno decrescente (um hat-trick passa de 9, mas sofrer quatro gols não derruba ninguém a 3),
## e o resultado e o rendimento em relação ao time ajustam. Quem jogou pouco fica perto do neutro.
const RATING_BASE := 6.55
const RATING_SPAN := 2.6
const RATING_WIN := 0.22
const RATING_LOSS := -0.18


static func rating_from(pts: float, team_bonus: float, perf_c: float, noise: float, mins: int) -> float:
	var r: float
	if mins < 20:
		r = 6.5 + 0.9 * tanh(pts / 1.2) + team_bonus * 0.4
	else:
		r = RATING_BASE + RATING_SPAN * tanh(pts / RATING_SPAN) + team_bonus + perf_c * 0.8 + noise
	return clampf(snappedf(r, 0.1), 3.0, 10.0)


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
	var pstats := {}
	for t: MatchTeam in teams:
		for mp: MatchPlayer in t.all:
			if mp.used:
				pstats[mp.p.id] = [mp.shots, mp.shots_on, mp.saves]
	return {"hg": score[0], "sh": [teams[0].shots, teams[1].shots], "ag": score[1], "att": attendance, "goals": goals, "motm": motm.p.id if motm != null else -1, "pstats": pstats,
		"et": half >= 3, "pens": [pen_score[0], pen_score[1]] if pen_taken[0] + pen_taken[1] > 0 else [],
		"derby": derby, "importance": importance, "yc": [teams[0].yellows, teams[1].yellows], "rc": [teams[0].reds, teams[1].reds],
		"lines": lines, "poss": possession_pct(0), "ref": ref, "tac": tactical_result()}


## Gols por tipo de jogada e xG, para o diário tático (TacticalScout): {ct: [[lado, tipo, min, tempo]], xg}.
func tactical_result() -> Dictionary:
	var cts: Array = []
	for ev in events:
		var t: int = ev["t"]
		if t == EV_GOAL or t == EV_OWN_GOAL:
			var ct := CH_CROSS if t == EV_OWN_GOAL else int(ev.get("x", {}).get("ct", CH_THROUGH))
			cts.append([int(ev["s"]), ct, int(ev["m"]), int(ev["h"])])
	return {"ct": cts, "xg": [snappedf(teams[0].xg, 0.01), snappedf(teams[1].xg, 0.01)]}


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
