extends TestCase
## FighterGenerator (Game Design Bible §§4,5,13; MMA Bible §§1,7,18).


func _generated(w: WorldState) -> Array:
	return w.fighters.values().filter(func(f: Fighter): return f.id.begins_with("ftr_") and not f.appearance.is_empty() and f.appearance.has("pop"))


func test_same_seed_generates_same_fighters() -> void:
	var a := WorldGenerator.generate(5, "regional_promoter")
	var b := WorldGenerator.generate(5, "regional_promoter")
	var fa: Array = _generated(a)
	var fb: Array = _generated(b)
	check(fa.size() > 100, "população gerada")
	check_eq(fa.size(), fb.size(), "mesma quantidade")
	for i in mini(fa.size(), 40):
		check_eq(fa[i].display_name(), fb[i].display_name(), "mesmo nome")
		check_eq(fa[i].striking, fb[i].striking, "mesmos atributos")
		check_eq(fa[i].appearance, fb[i].appearance, "mesma aparência")


func test_generated_fighters_are_coherent() -> void:
	var w := WorldGenerator.generate(11, "regional_promoter")
	var cfg: Dictionary = ContentDB.load_json("fighter_generation.json")
	var fighters: Array = _generated(w)
	check(fighters.size() >= 150, "população gerada (%d)" % fighters.size())
	var names := {}
	for f: Fighter in fighters:
		var age := f.age_on(w.date)
		check(age >= 19 and age <= 40, "idade plausível (%d)" % age)
		check(cfg.countries.has(f.country), "país conhecido")
		var group := FighterGenerator.group_by_id(f.country, f.origin_group)
		check(not group.is_empty(), "grupo cultural do país")
		check(f.city in group.get("cities", []), "cidade do grupo")
		check(cfg.archetypes.has(f.martial_base), "base marcial conhecida")
		check(FighterGenerator.martial_arts().has(f.discipline), "arte marcial real conhecida")
		check_eq(FighterGenerator.martial_arts()[f.discipline].family, f.martial_base, "família coerente")
		check(f.reach_cm - f.height_cm >= -4 and f.reach_cm - f.height_cm <= 13, "envergadura plausível")
		check(f.natural_weight_kg > 45.0, "peso natural definido")
		check(f.record.wins + f.record.losses + f.record.draws >= 1, "ao menos uma luta")
		check(f.appearance.pop in group.get("populations", {}), "rosto coerente com a origem")
		check(not f.personality.is_empty() and int(f.personality.temperament) >= 0 and int(f.personality.temperament) <= 100, "personalidade")
		check_eq(f.appearance.age, age, "idade do rosto = idade do atleta")
		check_eq(f.appearance.sex, "f" if f.sex == Fighter.Sex.FEMALE else "m", "sexo do rosto")
		check(not f.bio.is_empty(), "bio gerada")
		check(cfg.fight_styles.has(f.fight_style), "estilo de luta conhecido")
		check(not f.hidden.is_empty() and f.hidden.has("injury_risk"), "atributos ocultos")
		names[f.first_name + " " + f.last_name] = true
	check_eq(names.size(), fighters.size(), "nomes únicos")


func test_martial_base_shapes_the_skill_profile() -> void:
	var w := WorldGenerator.generate(3, "regional_promoter")
	var sums := {"striker": [0.0, 0.0, 0], "wrestler": [0.0, 0.0, 0]}
	for f: Fighter in _generated(w):
		var key := "striker" if f.martial_base in ["boxing", "kickboxing", "muay_thai"] else "wrestler" if f.martial_base == "wrestling" else ""
		if key.is_empty():
			continue
		sums[key][0] += _avg(f.striking)
		sums[key][1] += _avg(f.grappling)
		sums[key][2] += 1
	check(sums.striker[2] > 5 and sums.wrestler[2] > 5, "amostra suficiente")
	var kinds := {}
	for f: Fighter in _generated(w):
		kinds[f.discipline] = true
	check(kinds.size() >= 18, "variedade de artes marciais (%d)" % kinds.size())
	check(sums.striker[0] / sums.striker[2] > sums.striker[1] / sums.striker[2] + 6, "trocador troca mais do que derruba")
	check(sums.wrestler[1] / sums.wrestler[2] > sums.wrestler[0] / sums.wrestler[2] + 6, "wrestler derruba mais do que troca")


func test_record_follows_skill() -> void:
	var w := WorldGenerator.generate(8, "regional_promoter")
	var fighters: Array = _generated(w)
	fighters.sort_custom(func(a: Fighter, b: Fighter): return _skill(a) > _skill(b))
	var quarter := fighters.size() / 4
	check(_win_rate(fighters.slice(0, quarter)) > _win_rate(fighters.slice(fighters.size() - quarter)) + 0.12, "os melhores vencem mais")


func test_monthly_intake_adds_prospects_and_retires_old_free_agents() -> void:
	var w := WorldGenerator.generate(4, "regional_promoter")
	var veteran: Fighter
	for f: Fighter in w.fighters.values():
		if f.organization_id.is_empty() and not f.retired:
			veteran = f
			break
	veteran.birth_date = {"year": int(w.date.year) - 45, "month": 1, "day": 1}
	var before := w.fighters.size()
	var known := w.fighters.duplicate()
	var sim := WorldSim.new(w)
	for i in 31:
		sim.advance_day()
	var created: Array = w.fighters.values().filter(func(f: Fighter): return not known.has(f.id) and f.age_on(w.date) <= 24 and f.record.wins + f.record.losses + f.record.draws <= 6)
	check(w.fighters.size() >= before + 1, "chegaram prospectos (%d → %d)" % [before, w.fighters.size()])
	check(created.size() >= 1, "prospectos jovens e com poucas lutas")
	check(veteran.retired, "veterano de 45 anos sem contrato se aposenta")
	var restored := SaveSystem.decode(SaveSystem.encode(w))
	check_eq(restored.fighters.size(), w.fighters.size(), "prospectos sobrevivem ao save")


func _avg(values: Dictionary) -> float:
	var total := 0.0
	for v in values.values():
		total += float(v)
	return total / maxf(1.0, values.size())


func _skill(f: Fighter) -> float:
	return _avg(f.striking) + _avg(f.grappling) + _avg(f.jiu_jitsu)


func _win_rate(list: Array) -> float:
	var wins := 0.0
	var fights := 0.0
	for f: Fighter in list:
		wins += f.record.wins
		fights += f.record.wins + f.record.losses
	return wins / maxf(1.0, fights)


func test_origins_look_and_sound_real() -> void:
	var w := WorldGenerator.generate(12, "regional_promoter")
	var east_asian_only := ["JP", "KR", "CN"]
	for i in 60:
		var jp := FighterGenerator.create(w, {"country": east_asian_only[i % 3], "division": "m_lightweight"})
		check_eq(jp.appearance.pop, "leste_asiatico", "rosto leste-asiático para %s" % jp.country)
	var dagestan := 0
	for i in 40:
		var f := FighterGenerator.create(w, {"country": "RU", "origin_group": "ru_dagestan", "division": "m_lightweight"})
		check_eq(f.appearance.pop, "caucaso", "daguestanês tem traços do Cáucaso")
		check(f.city in ["Makhachkala", "Khasavyurt", "Kaspiysk", "Derbent", "Buynaksk", "Kizlyar", "Izberbash", "Gunib"], "cidade do Daguestão")
		check(f.first_name in FighterGenerator.origins().name_pools.dagestani.male, "nome daguestanês")
		if f.discipline in ["freestyle_wrestling", "combat_sambo", "sambo"]:
			dagestan += 1
	check(dagestan >= 25, "Daguestão luta olímpica e sambo (%d/40)" % dagestan)
	var woman := FighterGenerator.create(w, {"country": "RU", "origin_group": "ru_russian", "division": "w_strawweight"})
	check(woman.last_name.ends_with("a"), "sobrenome russo no feminino (%s)" % woman.last_name)
	check_eq(FighterGenerator.female_surname("Kowalski", "polish"), "Kowalska", "polonês no feminino")
	check_eq(FighterGenerator.female_surname("Galiullin", "slavic"), "Galiullina", "tártaro no feminino")


func test_names_are_massive_and_varied() -> void:
	var o := FighterGenerator.origins()
	var total := 0
	for pool: Dictionary in o.name_pools.values():
		total += pool.male.size() + pool.female.size() + pool.last.size()
	check(total >= 3500, "milhares de nomes (%d)" % total)
	var w := WorldGenerator.generate(13, "regional_promoter")
	var names := {}
	for i in 400:
		var f := FighterGenerator.create(w, {"division": "m_welterweight"})
		names[f.first_name + " " + f.last_name] = true
	check(names.size() >= 390, "quase sem repetição em 400 sorteios (%d)" % names.size())


func test_personality_follows_origin_and_feeds_charisma() -> void:
	var w := WorldGenerator.generate(14, "regional_promoter")
	var counts := {}
	for i in 120:
		var f := FighterGenerator.create(w, {"country": "RU", "origin_group": "ru_dagestan", "division": "m_lightweight"})
		counts[f.personality.archetype] = int(counts.get(f.personality.archetype, 0)) + 1
	check(int(counts.get("warrior_code", 0)) > int(counts.get("showman", 0)) * 3, "código de guerreiro é comum no Daguestão, showman é raro")
	var showman := FighterGenerator.create(w, {"personality": "showman", "division": "m_lightweight"})
	check(int(showman.personality.trash_talk) >= 55, "showman provoca")
