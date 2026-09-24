class_name WorldGenerator
extends RefCounted
## Monta o universo inicial a partir do seed. Mesmo seed + mesmo tipo = mesmo mundo.

const DEFAULT_SEED := 19031911
const FREE_AGENTS := 90


static func random_seed() -> int:
	var r := RandomNumberGenerator.new()
	r.randomize()
	return r.randi_range(1, 999_999_999)


static func generate(seed_value: int, world_type: String = "padrao") -> GameWorld:
	DatabaseManager.load_all()
	var w := GameWorld.new()
	w.world_seed = seed_value
	w.world_type = world_type
	w.rng.seed = seed_value
	w.year = int(DatabaseManager.competitions()["start_year"])
	var rng := w.rng
	if world_type == "aleatorio":
		ClubGenerator.random_clubs(w, rng)
	else:
		var datas := DatabaseManager.clubs_default()
		for i in datas.size():
			w.clubs.append(ClubGenerator.from_default(w, rng, datas[i], i))
		ClubGenerator.resolve_rivals(w, datas)
	var used_names := {}
	for c in w.clubs:
		var level := PlayerGenerator.club_level(c.division, c.reputation, c.arch())
		PlayerGenerator.create_squad(w, rng, c, level, used_names)
	for i in FREE_AGENTS:
		var div := RngUtil.weighted_index(rng, [1.0, 2.0, 3.0, 4.0])
		var lr: Array = DatabaseManager.division_config(div)["level_range"]
		PlayerGenerator.create_free_agent(w, rng, (float(lr[0]) + float(lr[1])) * 0.5, used_names)
	Valuation.refresh_shift(w)
	w.stats["talent_ref"] = PlayerDevelopment.talent_index(w)
	w.stats["talent_drift"] = 0.0
	SeasonManager.setup_first_season(w)
	return w


## Conjunto de nomes completos em uso (para gerar novos jogadores sem repetição).
static func used_names_of(world: GameWorld) -> Dictionary:
	var used := {}
	for p in world.players.values():
		used[p.first_name + " " + p.last_name] = true
	return used
