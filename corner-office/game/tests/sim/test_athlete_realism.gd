extends TestCase
## Realismo da população gerada (Game Design Bible §0, §21 "Auditar
## diversidade regional e de estilos"). Faixas amplas: pegam regressões
## grosseiras, não exigem números exatos.

const Stats := preload("res://tools/athlete_stats.gd")


func test_population_looks_like_a_real_league() -> void:
	var w := WorldGenerator.generate(2027, "flagship")
	var s: Dictionary = Stats.summarize(w)
	var league: Dictionary = s.tiers.flagship
	var circuit: Dictionary = s.tiers.circuit
	print("  Liga: %s" % JSON.stringify({"n": league.count, "idade": league.age_mean, "lutas": league.bouts_mean, "vit": league.win_pct_mean, "invictos": league.undefeated, "países": league.countries, "top": league.top_countries.slice(0, 5)}))
	print("  Circuito: %s" % JSON.stringify({"n": circuit.count, "idade": circuit.age_mean, "lutas": circuit.bouts_mean, "vit": circuit.win_pct_mean}))
	print("  Métodos por divisão: %s" % JSON.stringify(s.finish_by_division))
	check(league.age_mean >= 29.0 and league.age_mean <= 32.0, "Idade média da liga ~30: %s" % league.age_mean)
	check(league.age_min >= 20.0 and league.age_max <= 43.0, "Faixa etária da liga")
	check(circuit.age_mean >= 24.5 and circuit.age_mean <= 28.5, "Circuito mais jovem: %s" % circuit.age_mean)
	check(league.bouts_mean >= 12.0 and league.bouts_mean <= 21.0, "Experiência média da liga: %s" % league.bouts_mean)
	check(league.win_pct_mean >= 0.63 and league.win_pct_mean <= 0.77, "Liga seleciona vencedores: %s" % league.win_pct_mean)
	check(circuit.win_pct_mean >= 0.5 and circuit.win_pct_mean <= 0.66, "Circuito tem journeymen: %s" % circuit.win_pct_mean)
	check(league.max_wins <= 42, "Sem cartéis inflados: %d" % league.max_wins)
	check(league.undefeated >= 8 and league.undefeated <= 80, "Invictos existem mas são raros: %d" % league.undefeated)
	check(league.women_share >= 0.16 and league.women_share <= 0.24, "Participação feminina: %s" % league.women_share)
	check(league.countries >= 28, "Liga internacional: %d países" % league.countries)
	var by_country := {}
	for f: Fighter in w.fighters.values():
		if f.organization_id == w.player_org_id:
			by_country[f.country] = int(by_country.get(f.country, 0)) + 1
	var n := float(league.count)
	check(by_country.get("US", 0) / n >= 0.24 and by_country.get("US", 0) / n <= 0.42, "EUA ~1/3 do elenco")
	check(by_country.get("BR", 0) / n >= 0.1 and by_country.get("BR", 0) / n <= 0.24, "Brasil forte")
	check(by_country.get("RU", 0) / n >= 0.03 and by_country.get("RU", 0) / n <= 0.13, "Rússia/Daguestão presente sem dominar")
	var fin: Dictionary = s.finish_by_division
	check(fin.m_heavyweight.dec < fin.m_lightweight.dec and fin.m_lightweight.dec < fin.m_flyweight.dec, "Mais decisões nas divisões leves")
	check(fin.m_heavyweight.ko > 0.45, "Pesados nocauteiam: %s" % fin.m_heavyweight.ko)
	check(fin.w_strawweight.dec > fin.m_welterweight.dec, "Palha feminino decide mais nos pontos")
	for d: String in s.height_by_division:
		check(absf(float(s.height_by_division[d][0]) - float(CareerModel.division(d).height[0])) < 2.0, "Altura média da divisão %s" % d)


func test_ethnicity_follows_country_without_being_destiny() -> void:
	var w := WorldGenerator.generate(2028, "flagship")
	var pops := {}
	var bases := {}
	for f: Fighter in w.fighters.values():
		if not pops.has(f.country):
			pops[f.country] = {}
			bases[f.country] = {}
		pops[f.country][f.appearance.pop] = int(pops[f.country].get(f.appearance.pop, 0)) + 1
		bases[f.country][f.martial_base] = int(bases[f.country].get(f.martial_base, 0)) + 1
	check(float(pops.JP.get("leste_asiatico", 0)) / pops.JP.values().reduce(func(a, b): return a + b, 0) > 0.9, "Japão: leste asiático")
	check(pops.BR.size() >= 4, "Brasil é miscigenado: %s" % str(pops.BR))
	check(pops.US.size() >= 4, "EUA são diversos: %s" % str(pops.US))
	check(pops.RU.has("caucaso") and pops.RU.has("leste_europeu"), "Rússia: eslavos e caucasianos (Daguestão)")
	check(bases.BR.get("bjj", 0) > bases.BR.get("wrestling", 0), "Brasil: mais jiu-jitsu que wrestling")
	check(bases.US.get("wrestling", 0) > bases.US.get("bjj", 0), "EUA: wrestling na frente")
	check(bases.BR.size() >= 6, "Base marcial não é destino: %s" % str(bases.BR))
