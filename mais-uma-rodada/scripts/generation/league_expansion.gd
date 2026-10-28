class_name LeagueExpansion
extends RefCounted
## Só acrescenta ligas ausentes na virada do ano. IDs, elencos, resultados e
## partidas da carreira existente permanecem válidos durante a temporada.

static func apply(w: GameWorld) -> Array:
	var added: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(w.world_seed, w.year, 140219)
	var names := WorldGenerator.used_names_of(w)
	var clubs: Array = []
	for id in DatabaseManager.league_ids():
		if not w.clubs_in_league(id).is_empty():
			continue
		var cfg := DatabaseManager.league_cfg(id)
		var authored: Array = DatabaseManager.club_data(cfg["nation"]).filter(func(cd): return cd.get("league", "") == id)
		if authored.size() != int(cfg["teams"]):
			continue
		for cd in authored:
			var c := ClubGenerator.from_data(w, rng, cd, w.clubs.size(), cfg)
			Overrides.apply_club(c)
			ClubGenerator._derive(w, rng, c)
			w.clubs.append(c)
			clubs.append(c)
		added.append(id)
	for c: Club in clubs:
		PlayerGenerator.create_squad(w, rng, c, PlayerGenerator.club_level(c), names)
		for p: Player in w.squad(c):
			p.compact()
	if not clubs.is_empty():
		w.reset_indexes()
		SponsorManager.ensure_all(w)
	return added
