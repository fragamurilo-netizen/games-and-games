class_name MatchEngine
extends RefCounted
## Monta uma MatchSimulation para um jogo do calendário com todo o contexto
## (clássico, importância, público, sede neutra, mata-mata). A simulação fica em MatchSimulation.


static func is_derby(world: GameWorld, home_id: int, away_id: int) -> bool:
	var h := world.club(home_id)
	var a := world.club(away_id)
	return h.is_rival(away_id) or a.is_rival(home_id)


## Importância 0..1: fim de temporada + briga por título/vaga/acesso/rebaixamento, fase da copa, clássico.
static func importance_of(world: GameWorld, f: Fixture) -> float:
	var imp := 0.3
	if f.is_league() and world.season != null:
		var league := world.league(f.comp)
		if league != null:
			var total := float(league.rounds.size())
			var progress := float(f.round) / maxf(1.0, total - 1.0)
			if progress >= 0.6:
				var teams := league.club_ids.size()
				var zone_top := maxi(maxi(1, league.promoted_count()), CupManager.continental_spots(league)) + 1
				var zone_bottom := teams - league.relegated_count() - 1
				for cid in [f.home, f.away]:
					var pos := CompetitionManager.position_of(league, cid)
					if pos <= zone_top or (league.relegated_count() > 0 and pos >= zone_bottom):
						imp += 0.2 * progress
			if f.round == league.rounds.size() - 1:
				imp += 0.1
	elif f.stage == Fixture.STAGE_GROUP:
		imp = 0.45 + 0.05 * f.round
	elif f.stage == Fixture.STAGE_KO and world.league(f.comp) != null:
		imp = 0.75 + 0.08 * f.round # playoffs de liga
	elif f.stage == Fixture.STAGE_KO:
		imp = CupManager.stage_importance(world, f)
	if is_derby(world, f.home, f.away):
		imp += 0.2
	return clampf(imp, 0.0, 1.0)


static func context_for(world: GameWorld, f: Fixture) -> Dictionary:
	var home := world.club(f.home)
	var away := world.club(f.away)
	var derby := is_derby(world, f.home, f.away)
	var att := 0
	if f.neutral:
		att = int(minf(float(maxi(home.capacity, away.capacity)) * 1.2, 78000.0) * world.rng.randf_range(0.75, 1.0))
	else:
		att = FinanceManager.expected_attendance(home, away, derby, world.rng)
		if not f.is_league():
			att = mini(home.capacity, int(att * 1.12)) # noite de copa enche o estádio
	var ctx := {
		"derby": derby,
		"importance": importance_of(world, f),
		"attendance": att,
		"competition": f.comp,
		"neutral": f.neutral,
	}
	if f.stage == Fixture.STAGE_KO and CupManager.is_deciding_leg(world, f):
		ctx["ko"] = true
		ctx["agg"] = CupManager.aggregate_before(world, f)
	elif f.stage == Fixture.STAGE_KO and LeagueFormat.is_deciding_leg(world, f):
		ctx["ko"] = true
		ctx["agg"] = LeagueFormat.aggregate_before(world, f)
	return ctx


static func create(world: GameWorld, f: Fixture, home_sheet: TeamSheet, away_sheet: TeamSheet, detail: bool, seed_value: int = -1) -> MatchSimulation:
	var sim := MatchSimulation.new()
	var ctx := context_for(world, f)
	var sd := seed_value if seed_value >= 0 else world.rng.randi()
	sim.setup(world, world.club(f.home), world.club(f.away), home_sheet, away_sheet, ctx, sd, detail)
	return sim


## Jogo amistoso/teste entre dois clubes quaisquer (usado nos testes de calibração), minuto a minuto.
static func quick_match(world: GameWorld, home: Club, away: Club, seed_value: int) -> MatchSimulation:
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	var sim := MatchSimulation.new()
	sim.setup(world, home, away, hs, as_, _test_ctx(home), seed_value, false)
	sim.run_to_end()
	return sim


## Jogo de teste no formato comum de resultado: minuto a minuto ou modo rápido.
static func test_match(world: GameWorld, home: Club, away: Club, seed_value: int, quick: bool) -> Dictionary:
	if not quick:
		return quick_match(world, home, away, seed_value).to_result()
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	return QuickMatch.play(world, home, away, hs, as_, _test_ctx(home), seed_value)


static func _test_ctx(home: Club) -> Dictionary:
	return {"derby": false, "importance": 0.3, "attendance": int(home.capacity * 0.6), "competition": "F"}
