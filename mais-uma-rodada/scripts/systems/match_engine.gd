class_name MatchEngine
extends RefCounted
## Monta uma MatchSimulation para um jogo do calendário com todo o contexto
## (clássico, importância da rodada, público). A simulação em si fica em MatchSimulation.


static func is_derby(world: GameWorld, home_id: int, away_id: int) -> bool:
	var h := world.club(home_id)
	var a := world.club(away_id)
	return h.is_rival(away_id) or a.is_rival(home_id)


## Importância 0..1: fim de temporada + briga por título/acesso/rebaixamento + clássico.
static func importance_of(world: GameWorld, f: Fixture) -> float:
	var imp := 0.3
	if f.competition == "L" and world.season != null:
		var league: League = world.season.leagues[f.division]
		var total := float(league.rounds.size())
		var progress := float(f.round) / maxf(1.0, total - 1.0)
		if progress >= 0.6:
			var teams := league.club_ids.size()
			var cfg := DatabaseManager.division_config(f.division)
			var zone_top := maxi(1, int(cfg["promoted"])) + 1
			var zone_bottom := teams - int(cfg["relegated"]) - 1
			for cid in [f.home, f.away]:
				var pos := CompetitionManager.position_of(league, cid)
				if pos <= zone_top or (int(cfg["relegated"]) > 0 and pos >= zone_bottom):
					imp += 0.2 * progress
		if f.round == league.rounds.size() - 1:
			imp += 0.1
	if is_derby(world, f.home, f.away):
		imp += 0.2
	return clampf(imp, 0.0, 1.0)


static func context_for(world: GameWorld, f: Fixture) -> Dictionary:
	var home := world.club(f.home)
	var away := world.club(f.away)
	var derby := is_derby(world, f.home, f.away)
	return {
		"derby": derby,
		"importance": importance_of(world, f),
		"attendance": FinanceManager.expected_attendance(home, away, derby, world.rng),
		"competition": f.competition,
		"neutral": false,
	}


static func create(world: GameWorld, f: Fixture, home_sheet: TeamSheet, away_sheet: TeamSheet, detail: bool) -> MatchSimulation:
	var sim := MatchSimulation.new()
	var ctx := context_for(world, f)
	sim.setup(world, world.club(f.home), world.club(f.away), home_sheet, away_sheet, ctx, world.rng.randi(), detail)
	return sim


## Jogo amistoso/teste entre dois clubes quaisquer (usado nos testes de calibração).
static func quick_match(world: GameWorld, home: Club, away: Club, seed_value: int) -> MatchSimulation:
	var hs := ClubAI.prepare_ai_sheet(world, home, away, true)
	var as_ := ClubAI.prepare_ai_sheet(world, away, home, false)
	var sim := MatchSimulation.new()
	sim.setup(world, home, away, hs, as_, {"derby": false, "importance": 0.3, "attendance": int(home.capacity * 0.6), "competition": "F"}, seed_value, false)
	sim.run_to_end()
	return sim
