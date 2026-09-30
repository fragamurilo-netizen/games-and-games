extends TestCase


func test_generator_loads_canonical_content() -> void:
	var w := WorldGenerator.generate(42, "regional_promoter")
	check_eq(w.organizations.size(), 8, "7 globais + org do jogador")
	check(w.fighters.has("ftr_carter"), "Malik Carter existe")
	check(w.organizations.org_crown.roster.has("ftr_carter"), "Carter está no roster da Crown")
	check(w.player_org() != null and w.player_org().is_player, "org do jogador criada")


func test_ids_are_never_reused() -> void:
	var w := WorldState.new()
	var a := w.new_id("ftr")
	var b := w.new_id("ftr")
	check(a != b, "ids sequenciais distintos")


func test_rng_is_deterministic() -> void:
	var r1 := SimRandom.new(7)
	var r2 := SimRandom.new(7)
	for i in 100:
		check_eq(r1.range_i(0, 1000), r2.range_i(0, 1000), "mesma seed, mesma sequência")


func test_world_roundtrip_serialization() -> void:
	var w := WorldGenerator.generate(1, "regional_promoter")
	w.rng.range_i(0, 10)
	var restored := SaveSystem.decode(SaveSystem.encode(w))
	check_eq(restored.fighters.size(), w.fighters.size(), "fighters preservados")
	check_eq(restored.fighters.ftr_carter.record.wins, 24, "recorde preservado")
	check_eq(restored.rng.range_i(0, 1_000_000), w.rng.range_i(0, 1_000_000), "estado do RNG preservado")
	check_eq(restored.date, w.date, "data preservada")
	check_eq(typeof(restored.fighters.ftr_carter.birth_date.year), TYPE_INT, "ints aninhados continuam int")


func test_save_migration_rejects_future_versions() -> void:
	check(SaveSystem.migrate({"schema_version": WorldState.SCHEMA_VERSION + 1}) == null, "save do futuro é rejeitado")
