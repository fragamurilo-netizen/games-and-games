extends TestCase
## Geração de atletas e da liga principal. Game Bible §0, §4, §5, §13.

static var _world: WorldState = null


func _flagship() -> WorldState:
	if _world == null:
		_world = WorldGenerator.generate(2027, "flagship")
	return _world


func test_generation_is_deterministic() -> void:
	var a := WorldGenerator.generate(99, "flagship")
	var b := WorldGenerator.generate(99, "flagship")
	check_eq(SaveSystem.encode(a), SaveSystem.encode(b), "Mesma seed, mesmo mundo")


func test_league_structure() -> void:
	var w := _flagship()
	var org := w.player_org()
	check_eq(org.tier, "global", "Nossa liga é a principal")
	check(org.roster.size() >= 590 and org.roster.size() <= 610, "Elenco de grande liga: %d" % org.roster.size())
	check_eq(org.titles.size(), 12, "Um campeão por divisão")
	for d: String in org.titles:
		var champ: Fighter = w.fighters[org.titles[d].champion_id]
		check_eq(champ.division, d, "Campeão da própria divisão")
		check_eq(champ.organization_id, org.id, "Campeão é da liga")
	for org_id: String in w.organizations:
		if org_id != org.id:
			check_eq(w.organizations[org_id].tier, "national", "Demais ligas são nacionais")
	for id: String in org.roster:
		var f: Fighter = w.fighters[id]
		check(CareerModel.pro_bouts(f) >= 5, "Liga só contrata com experiência: %s %d" % [id, CareerModel.pro_bouts(f)])
		var c: Contract = w.contracts[f.contract_id]
		check(c.active and c.organization_id == org.id and c.bouts_remaining >= 1, "Contrato válido")


func test_identity_is_coherent() -> void:
	var w := _flagship()
	var pools: Dictionary = AthleteFactory.names()
	for f: Fighter in w.fighters.values():
		var c := AthleteFactory.country(f.country)
		var pops := {}
		var firsts := {}
		for g: Dictionary in c.groups:
			pops[g.pop] = true
			var pool: Dictionary = pools[g.first]
			for n: String in (pool.f if f.sex == Fighter.Sex.FEMALE else pool.m):
				firsts[n] = true
		if f.id.begins_with("ftr_0"):
			check(pops.has(f.appearance.pop), "Rosto vem de um grupo do país: %s %s" % [f.country, f.appearance.pop])
			check(firsts.has(f.first_name), "Nome coerente com o país: %s %s" % [f.country, f.first_name])
		check(f.division.begins_with("w_") == (f.sex == Fighter.Sex.FEMALE), "Divisão e sexo")
		var d := CareerModel.division(f.division)
		check(absf(f.height_cm - float(d.height[0])) < float(d.height[1]) * 4.5, "Altura plausível para a divisão: %s %d" % [f.division, f.height_cm])
		check(absi(f.reach_cm - f.height_cm) <= 20, "Envergadura plausível")
		check(f.natural_weight_kg > 45.0 and f.natural_weight_kg < 130.0, "Peso natural plausível")
		for group: String in CareerModel.GROUPS:
			for v in f.get(group).values():
				check(int(v) >= 12 and int(v) <= 98, "Atributo dentro da escala")


func test_records_are_consistent() -> void:
	var w := _flagship()
	for f: Fighter in w.fighters.values():
		var r := f.record
		check_eq(int(r.get("ko_wins", 0)) + int(r.get("sub_wins", 0)) + int(r.get("dec_wins", 0)), int(r.wins), "Métodos somam as vitórias: " + f.id)
		check_eq(int(r.get("ko_losses", 0)) + int(r.get("sub_losses", 0)) + int(r.get("dec_losses", 0)), int(r.losses), "Métodos somam as derrotas: " + f.id)
		check(f.history.get("results", []).size() == mini(CareerModel.pro_bouts(f) + int(r.get("nc", 0)), CareerHistory.RESULT_LIMIT), "Resumo recente coerente: " + f.id)
		if CareerModel.pro_bouts(f) > 0:
			check(GameDate.days_between(f.last_fight_on, w.date) >= 0, "Última luta no passado")


func test_flagship_world_survives_save() -> void:
	var w := _flagship()
	var loaded := SaveSystem.decode(SaveSystem.encode(w))
	check(loaded != null, "Save carrega")
	check_eq(loaded.fighters.size(), w.fighters.size(), "Todos os atletas")
	var id: String = w.player_org().roster[10]
	check_eq(JSON.stringify(JSON.from_native(loaded.fighters[id].history)), JSON.stringify(JSON.from_native(w.fighters[id].history)), "História preservada")
	check_eq(JSON.stringify(JSON.from_native(loaded.fighters[id].hidden)), JSON.stringify(JSON.from_native(w.fighters[id].hidden)), "Modelo latente preservado")
	check_eq(SaveSystem.encode(loaded), SaveSystem.encode(w), "Save estável após recarregar")
