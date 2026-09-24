class_name BoardManager
extends RefCounted
## Diretoria: confiança no treinador a partir da meta da temporada, resultados, clássicos,
## torcida e finanças. A demissão só acontece no fim da temporada (nunca no meio de uma
## sequência ruim sem aviso): abaixo de 30 a diretoria dá um ultimato visível no hub.

const ULTIMATUM := 30.0
const FIRE_LIMIT: Array[float] = [-1.0, 12.0, 20.0] # por dificuldade (fácil nunca demite)


static func label(conf: float) -> String:
	if conf >= 80.0:
		return "Total confiança"
	if conf >= 60.0:
		return "Satisfeita"
	if conf >= 42.0:
		return "Atenta"
	if conf >= ULTIMATUM:
		return "Preocupada"
	return "Ultimato"


static func color(conf: float) -> Color:
	return UIColors.morale_color(conf)


## Depois de cada jogo do clube do usuário.
static func after_match(world: GameWorld, club: Club, res: String, derby: bool) -> void:
	var league := world.league_of(club.id)
	if league == null:
		return
	var goal := SeasonManager.goal_of(world, club.id)
	var pos := CompetitionManager.position_of(league, club.id)
	var played: int = league.table[club.id]["pl"]
	var d := 1.1 if res == "V" else (0.1 if res == "E" else -1.5)
	if derby:
		d *= 1.6
	# A posição em relação à meta pesa mais conforme a temporada avança.
	var weight := clampf(played / 19.0, 0.2, 1.0)
	d += clampf((int(goal[1]) - pos) * 0.12, -1.2, 0.8) * weight
	d += (club.fan_mood - 55.0) * 0.012
	if club.balance < 0:
		d -= 0.3
	if FinanceManager.wage_bill(world, club) > int(club.wage_budget * 1.02):
		d -= 0.4
	var before := club.board_confidence
	club.board_confidence = clampf(club.board_confidence + d, 0.0, 100.0)
	if before >= ULTIMATUM and club.board_confidence < ULTIMATUM:
		NewsManager.post(world, "diretoria_ultimato", {"club": club.short_name, "goal": String(goal[0]).to_lower()}, club.id, -1, NewsEvent.IMP_HEADLINE)


## Balanço da temporada. Atualiza a confiança e decide a demissão.
## Retorna {"delta": float, "fired": bool, "offers": [club_id]}.
static func season_review(world: GameWorld, club: Club, user: Dictionary) -> Dictionary:
	var d := 0.0
	if user.get("champion", false):
		d += 25.0
	elif user.get("promoted", false):
		d += 20.0
	elif user.get("goal_met", false):
		d += 12.0
	else:
		d -= 16.0
	if user.get("relegated", false):
		d -= 22.0
	var conf := clampf(club.board_confidence + d, 0.0, 100.0)
	var limit: float = FIRE_LIMIT[clampi(world.difficulty, 0, 2)]
	var fired := conf < limit
	var out := {"delta": d, "fired": fired, "offers": []}
	if fired:
		out["offers"] = job_offers(world, club)
		world.stats["fired"] = {"from": club.id, "offers": out["offers"], "year": world.year}
		club.board_confidence = 50.0 # o próximo técnico começa do zero
		NewsManager.post(world, "demissao", {"club": club.short_name, "manager": world.manager_name}, club.id, -1, NewsEvent.IMP_HEADLINE)
	else:
		# Nova temporada, nova paciência: puxa a confiança para o meio e nunca começa em ultimato
		# (a cobrança do ano anterior já foi feita no balanço).
		club.board_confidence = clampf(maxf(conf + (60.0 - conf) * 0.3, ULTIMATUM + 4.0), 0.0, 100.0)
	return out


## Clubes que aceitariam um técnico recém-demitido: reputação igual ou menor, de preferência
## uma divisão abaixo — a volta por cima começa de baixo.
static func job_offers(world: GameWorld, from_club: Club) -> Array:
	var cands: Array = []
	for c: Club in world.clubs:
		if c.id == from_club.id:
			continue
		if c.reputation > from_club.reputation + 3.0:
			continue
		var score := -absf(c.reputation - (from_club.reputation - 8.0))
		if c.nation == from_club.nation:
			score += 10.0
			if c.tier == from_club.tier + 1:
				score += 6.0
		score += world.rng.randf() * 6.0
		cands.append([score, c.id])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	var out: Array = []
	for i in mini(3, cands.size()):
		out.append(cands[i][1])
	return out


static func pending_job_offers(world: GameWorld) -> Array:
	var f: Dictionary = world.stats.get("fired", {})
	return f.get("offers", [])


## Assume um novo clube (depois de demitido).
static func take_job(world: GameWorld, club_id: int) -> void:
	var c := world.club(club_id)
	if c == null:
		return
	world.user_club_id = club_id
	world.stats.erase("fired")
	c.board_confidence = 60.0
	FinanceManager.set_budgets(world, c)
	c.sheet = ClubAI.auto_sheet(world, c, "")
	for p in world.squad(c):
		p.scout_noise = int(p.scout_noise * 0.3)
	world.offers.clear()
	NewsManager.post(world, "novo_tecnico", {"club": c.short_name, "manager": world.manager_name}, c.id, -1, NewsEvent.IMP_HEADLINE)
