class_name WorldGenerator
extends RefCounted
## Monta o universo inicial a partir do seed. Mesmo seed + mesmo tipo = mesmo mundo.
## "padrao": os clubes dos dados com suas reputações; "aleatorio": outra história — reputações
## e perfis oscilam e todos os jogadores são outros.

const DEFAULT_SEED := 19031911


static func random_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi_range(1, 999_999_999)


static func generate(seed_value: int, world_type: String = "padrao") -> GameWorld:
	DatabaseManager.load_all()
	Valuation.load_scale()
	Valuation.shift = 0.0
	var w := GameWorld.new()
	w.world_seed = seed_value
	w.world_type = world_type
	w.rng.seed = seed_value
	w.year = DatabaseManager.start_year()
	var rng := w.rng
	ClubGenerator.build_all(w, rng, world_type == "aleatorio")
	for c in w.clubs:
		Overrides.apply_club(c)
	var used_names := {}
	for c in w.clubs:
		PlayerGenerator.create_squad(w, rng, c, PlayerGenerator.club_level(c), used_names)
	var n_free := int(w.clubs.size() * float(DatabaseManager.rules().get("free_agents_per_club", 0.5)))
	for i in n_free:
		PlayerGenerator.create_free_agent(w, rng, random_league_level(rng), used_names)
	PlayerMods.apply(w) # jogadores do Editor geral e de mods (RNG próprio: o sorteio não muda)
	Valuation.refresh_shift(w)
	w.stats["talent_ref"] = PlayerDevelopment.talent_index(w)
	w.stats["talent_drift"] = 0.0
	PreHistory.build(w)
	CareerBackfill.build(w)
	SeasonManager.setup_first_season(w)
	return w


## Nível médio de uma liga sorteada pelo número de vagas (para agentes livres).
static func random_league_level(rng: RandomNumberGenerator) -> float:
	var ids := DatabaseManager.league_ids()
	var weights: Array = []
	for id in ids:
		weights.append(float(DatabaseManager.league_cfg(id)["teams"]))
	var cfg := DatabaseManager.league_cfg(ids[RngUtil.weighted_index(rng, weights)])
	return FinanceManager.league_mid_level(cfg) - 2.0


## Conjunto de nomes completos em uso (para gerar novos jogadores sem repetição).
static func used_names_of(world: GameWorld) -> Dictionary:
	var used := {}
	for p in world.players.values():
		used[p.first_name + " " + p.last_name] = true
	return used
