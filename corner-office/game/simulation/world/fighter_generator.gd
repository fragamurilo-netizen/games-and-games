class_name FighterGenerator
extends RefCounted
## Gerador de lutadores fictícios (Game Design Bible §§4,5,13; MMA Bible §§1,7,14,18).
##
## Um atleta nasce de uma origem (país → base marcial, população facial, nomes),
## de uma idade (curva de auge, potencial e experiência) e de um nível técnico.
## O cartel é consequência do nível e da idade; a aparência é desacoplada da
## habilidade. Parâmetros em content/fighter_generation.json.
##
## Usado no início da carreira (PopulationGenerator) e todo mês pela WorldSim,
## quando novos prospectos chegam ao mercado e veteranos sem contrato se aposentam.

const CONTENT := "fighter_generation.json"


## Cria (sem registrar no mundo) um atleta. opts aceita:
##  division, country, age, prospect (bool), used_names (Dictionary), cfg (conteúdo já carregado).
static func create(world: WorldState, opts: Dictionary = {}) -> Fighter:
	var cfg: Dictionary = opts.get("cfg", {})
	if cfg.is_empty():
		cfg = ContentDB.load_json(CONTENT)
	var tuning: Dictionary = ContentDB.load_json("career_tuning.json")
	var rng := world.rng
	var prospect: bool = opts.get("prospect", false)
	var f := Fighter.new()
	f.id = world.new_id("ftr")
	f.division = str(opts.get("division", rng.pick(tuning.player_divisions)))
	f.sex = Fighter.Sex.FEMALE if f.division.begins_with("w_") else Fighter.Sex.MALE

	# Origem
	var country: String = str(opts.get("country", ""))
	if not cfg.countries.has(country):
		country = _weighted_key(rng, cfg.countries, "weight")
	var origin: Dictionary = cfg.countries[country]
	f.country = country
	f.city = rng.pick(origin.cities)
	f.languages = origin.languages.duplicate()
	var used: Dictionary = opts.get("used_names", {})
	for attempt in 200:
		f.first_name = rng.pick(origin.female if f.sex == Fighter.Sex.FEMALE else origin.male)
		f.last_name = rng.pick(origin.last)
		if not used.has(f.first_name + " " + f.last_name):
			break
	used[f.first_name + " " + f.last_name] = true
	var arts: Dictionary = martial_arts()
	f.discipline = pick_discipline(rng, arts, origin.disciplines, str(opts.get("discipline", "")), str(opts.get("martial_base", "")))
	var art: Dictionary = arts[f.discipline]
	f.martial_base = str(art.family)
	var arch: Dictionary = cfg.archetypes.get(f.martial_base, cfg.archetypes.mma)
	f.fight_style = str(opts.get("fight_style", ""))
	if not cfg.fight_styles.has(f.fight_style):
		f.fight_style = pick_fight_style(rng, cfg, art)
	f.style = style_weights(cfg, f.fight_style, art)
	f.stance = str(rng.weighted(arch.stance))
	f.gym_id = _pick_gym(rng, country, f.martial_base)

	# Idade: prospectos entram jovens; a população inicial concentra-se perto do auge.
	var age: int
	if opts.has("age"):
		age = int(opts.age)
	elif prospect:
		age = rng.range_i(int(cfg.age.prospect[0]), int(cfg.age.prospect[1]))
	else:
		var lo := int(cfg.age.population[0])
		var hi := int(cfg.age.population[1])
		age = clampi(int(round((rng.range_f(lo, hi) + rng.range_f(lo, hi) + float(cfg.age.peak)) / 3.0)), lo, hi)
	f.birth_date = {"year": int(world.date.year) - age, "month": rng.range_i(1, 12), "day": rng.range_i(1, 28)}
	if GameDate.to_unix({"year": world.date.year, "month": f.birth_date.month, "day": f.birth_date.day}) > GameDate.to_unix(world.date):
		f.birth_date.year -= 1  # aniversário ainda não chegou: mantém a idade sorteada

	# Biometria
	var base_height := int(tuning.division_height.get(f.division, 175))
	var dev := float(cfg.height_deviation)
	f.height_cm = base_height + int(round(clampf(rng.normal(0.0, dev), -2.4 * dev, 2.4 * dev)))
	var reach: Dictionary = cfg.reach_offset
	f.reach_cm = f.height_cm + int(round(clampf(rng.normal(float(reach.mean), float(reach.deviation)), float(reach.range[0]), float(reach.range[1]))))
	f.body_type = str(rng.weighted(arch.body_types))
	var limit := _division_limit_kg(f.division)
	var over: Array = cfg.natural_weight_over_limit
	f.natural_weight_kg = snappedf(limit * (rng.range_f(float(over[0]), float(over[1])) + float(cfg.body_weight_factor.get(f.body_type, 0.0))), 0.1)

	# Nível técnico e curva de idade (a simulação nunca lê Overall; MMA Bible §30).
	var lv: Dictionary = cfg.level
	var level := clampf(rng.normal(float(lv.mean), float(lv.deviation)), float(lv.range[0]), float(lv.range[1]))
	if opts.has("level"):
		level = clampf(float(opts.level), 25.0, 92.0)
	var prime: Dictionary = cfg.prime
	if age < int(prime.start):
		level -= (int(prime.start) - age) * float(prime.young_penalty_per_year)
	_roll_attributes(world, f, cfg, arch, level, cfg.fight_styles[f.fight_style]["keys"], art.attributes)
	_apply_age(f, cfg, age)
	f.hidden = _roll_hidden(rng, cfg, f.martial_base)
	var growth := 0.0
	var peak := int(cfg.age.peak)
	var pot: Dictionary = cfg.potential
	if age < peak:
		growth = (peak - age) * rng.range_f(float(pot.growth_per_year_below_peak[0]), float(pot.growth_per_year_below_peak[1]))
	f.potential = {
		"mean": snappedf(clampf(level + growth + rng.normal(0.0, 3.0), 30.0, 95.0), 0.1),
		"spread": snappedf(float(pot.base_spread) + maxf(0.0, peak - age) * float(pot.spread_per_year_below_peak), 0.1),
	}

	# Cartel = consequência de nível e idade.
	f.record = _roll_record(rng, cfg.record, level, age, prospect)

	# Mercado (popularidade regional e separada de skill; MMA Bible §18).
	f.charisma = clampi(int(round(rng.normal(float(cfg.charisma.mean), float(cfg.charisma.deviation)))), 5, 95)
	var pop: Dictionary = cfg.popularity
	var fame: float = float(pop.base) + f.record.wins * float(pop.per_win) + (f.charisma - 50) * float(pop.per_charisma) + rng.normal(0.0, float(pop.noise))
	f.popularity_by_region = {str(origin.region): clampi(int(round(fame)), int(pop.range[0]), int(pop.range[1]))}
	var goals := {}
	var goal_total := 0.0
	for goal: String in cfg.career_goals:
		goals[goal] = rng.range_f(0.1, 1.0)
		goal_total += goals[goal]
	for goal: String in goals:
		goals[goal] = snappedf(goals[goal] / goal_total, 0.01)
	f.career_goals = goals

	f.nickname = _roll_nickname(rng, cfg, f)
	f.bio = _bio(rng, cfg, f, age)
	f.appearance = FaceGenerator.create_appearance(rng, country, f.body_type, age, "f" if f.sex == Fighter.Sex.FEMALE else "m",
		{"height": clampf((f.height_cm - base_height) / 24.0 + 0.5, 0.0, 1.0), "pop": str(opts.get("population", ""))})
	return f


## Chegada mensal de prospectos e aposentadoria de veteranos sem contrato.
## Retorna os ids dos novos atletas.
static func monthly_intake(world: WorldState) -> Array:
	var cfg: Dictionary = ContentDB.load_json(CONTENT)
	var intake: Dictionary = cfg.intake
	var tuning: Dictionary = ContentDB.load_json("career_tuning.json")
	for f: Fighter in world.fighters.values():
		if f.retired or not f.organization_id.is_empty() or f.birth_date.is_empty():
			continue
		var age := f.age_on(world.date)
		var fading: bool = age >= int(intake.retire_age) or (age >= int(intake.journeyman_age) and f.record.losses - f.record.wins >= int(intake.journeyman_loss_margin))
		if age >= int(intake.forced_retire_age) or (fading and world.rng.chance(float(intake.retire_chance))):
			f.retired = true
	var used := {}
	for old: Fighter in world.fighters.values():
		used[old.first_name + " " + old.last_name] = true
	var created: Array = []
	var count := world.rng.range_i(int(intake.per_month[0]), int(intake.per_month[1]))
	for i in count:
		var f := create(world, {"prospect": true, "used_names": used, "cfg": cfg,
			"division": world.rng.pick(tuning.player_divisions)})
		world.add("fighters", f)
		created.append(f.id)
		# Notícia só com fato público: invicto com vitórias suficientes (MMA Bible §27).
		if f.record.losses == 0 and f.record.wins >= int(intake.news_min_wins):
			var item := Media.new().publish(world, "prospect_turns_pro",
				[Reason.make("UNBEATEN_PROSPECT", f.record.wins, {"fighter_id": f.id})], [f.id])
			var story: Dictionary = tuning.story
			item.headline = str(story.get("prospect_headline", "{fighter} chega ao mercado")).format({"fighter": f.display_name()})
			item.body = str(story.get("prospect_body", "")).format({
				"age": f.age_on(world.date), "record": f.record_string(), "city": f.city,
				"division": f.division, "base": discipline_name(f)})
	return created


static func _roll_attributes(world: WorldState, f: Fighter, cfg: Dictionary, arch: Dictionary, level: float, style_keys: Array = [], art_offsets: Dictionary = {}) -> void:
	var attrs: Dictionary = ContentDB.load_json("attributes.json")
	var noise := float(cfg.attribute_noise)
	var bonus := float(cfg.key_attribute_bonus)
	var lo := int(cfg.attribute_range[0])
	var hi := int(cfg.attribute_range[1])
	for group: String in ["striking", "grappling", "jiu_jitsu", "physical", "mental"]:
		var values := {}
		for attribute: String in attrs[group]:
			var v := level + float(arch.groups.get(group, 0)) + world.rng.normal(0.0, noise)
			if attribute in arch["keys"]:
				v += bonus
			if attribute in style_keys:
				v += float(cfg.fight_style_key_bonus)
			v += float(art_offsets.get(attribute, 0))
			values[attribute] = clampi(int(round(v)), lo, hi)
		f.set(group, values)


static func _apply_age(f: Fighter, cfg: Dictionary, age: int) -> void:
	var prime: Dictionary = cfg.prime
	var lo := int(cfg.attribute_range[0])
	var hi := int(cfg.attribute_range[1])
	if age > int(prime.end):
		var years := age - int(prime.end)
		for attribute: String in prime.decline_attributes:
			if f.physical.has(attribute):
				f.physical[attribute] = clampi(f.physical[attribute] - int(round(years * float(prime.decline_per_year))), lo, hi)
	if age > int(prime.start):
		var calm := int(round((age - int(prime.start)) * float(prime.veteran_mental_per_year)))
		for attribute: String in ["fight_iq", "composure", "patience"]:
			f.mental[attribute] = clampi(f.mental[attribute] + calm, lo, hi)


static func _roll_hidden(rng: SimRandom, cfg: Dictionary, base: String) -> Dictionary:
	var attrs: Dictionary = ContentDB.load_json("attributes.json")
	var h: Dictionary = cfg.hidden
	var out := {}
	for attribute: String in attrs.hidden:
		if attribute == "preference":
			continue
		out[attribute] = clampi(int(round(rng.normal(float(h.mean), float(h.deviation)))), int(h.range[0]), int(h.range[1]))
	var strikers := ["boxing", "muay_thai", "kickboxing", "karate", "taekwondo"]
	out.preference = "striking" if base in strikers else "balanced" if base == "mma" else "grappling"
	return out


static func _roll_record(rng: SimRandom, rc: Dictionary, level: float, age: int, prospect: bool) -> Dictionary:
	var fights: int
	var p := clampf(float(rc.win_base) + (level - 56.0) * float(rc.win_per_level) + rng.normal(0.0, float(rc.win_noise)), float(rc.win_range[0]), float(rc.win_range[1]))
	if prospect:
		fights = rng.range_i(int(rc.prospect_fights[0]), int(rc.prospect_fights[1]))
		p = minf(float(rc.win_range[1]), p + float(rc.prospect_win_bonus))
	else:
		var per_year := rng.range_f(float(rc.fights_per_year[0]), float(rc.fights_per_year[1]))
		fights = clampi(int(round((age - 19.5) * per_year)), 1, int(rc.max_fights))
	var record := {"wins": 0, "losses": 0, "draws": 0, "nc": 0}
	for i in fights:
		if rng.chance(float(rc.draw_chance)):
			record.draws += 1
		elif rng.chance(p):
			record.wins += 1
		else:
			record.losses += 1
	return record


static func _roll_nickname(rng: SimRandom, cfg: Dictionary, f: Fighter) -> String:
	var nc: Dictionary = cfg.nickname_chance
	var chance := minf(float(nc.max), float(nc.base) + f.record.wins * float(nc.per_win))
	if not rng.chance(chance):
		return ""
	var pool: Array = []
	for language: String in f.languages:
		pool.append_array(cfg.nicknames.get(language, []))
	if pool.is_empty() or rng.chance(0.25):
		pool = cfg.nicknames.en
	return str(rng.pick(pool))


static func _bio(rng: SimRandom, cfg: Dictionary, f: Fighter, age: int) -> String:
	var phase := "prospect" if age < int(cfg.prime.start) else "veteran" if age > int(cfg.prime.end) + 1 else "prime"
	var gym := str(cfg.get("gym_fallback", ""))
	for g: Dictionary in ContentDB.load_json("gyms.json"):
		if g.id == f.gym_id:
			gym = g.name
	return str(rng.pick(cfg.bios[phase])).format({
		"age": age, "city": f.city, "base": discipline_name(f), "gym": gym,
		"record": f.record_string(), "fights": f.record.wins + f.record.losses + f.record.draws})


static func martial_arts() -> Dictionary:
	return ContentDB.load_json("martial_arts.json").disciplines


## Arte marcial: a escolhida; senão uma do país dentro da família pedida;
## senão sorteio pelos pesos do país.
static func pick_discipline(rng: SimRandom, arts: Dictionary, country_weights: Dictionary, wanted: String, family: String) -> String:
	if arts.has(wanted):
		return wanted
	if not family.is_empty():
		var weights := {}
		for id: String in arts:
			if arts[id].family == family:
				weights[id] = float(country_weights.get(id, 0.05))
		if not weights.is_empty():
			return str(rng.weighted(weights))
	return str(rng.weighted(country_weights))


static func pick_fight_style(rng: SimRandom, cfg: Dictionary, art: Dictionary) -> String:
	var weights := {}
	for id: String in cfg.fight_styles:
		weights[id] = float(art.fight_styles.get(id, 0.15))
	return str(rng.weighted(weights))


## Pesos por categoria de técnica: estilo de luta × tendência da arte marcial.
static func style_weights(cfg: Dictionary, fight_style: String, art: Dictionary) -> Dictionary:
	var out: Dictionary = cfg.fight_styles[fight_style]["style"].duplicate() if cfg.fight_styles.has(fight_style) else {}
	for category: String in art.get("intent", {}):
		out[category] = snappedf(float(out.get(category, 1.0)) * float(art.intent[category]), 0.01)
	return out


## Nome legível da arte marcial do atleta (canônicos sem arte usam a família).
static func discipline_name(f: Fighter) -> String:
	var arts := martial_arts()
	if arts.has(f.discipline):
		return str(arts[f.discipline].name)
	return base_name(f.martial_base)


## Nome legível da família marcial (conteúdo, não código).
static func base_name(base: String, cfg: Dictionary = {}) -> String:
	if cfg.is_empty():
		cfg = ContentDB.load_json(CONTENT)
	return str(cfg.family_names.get(base, base))


static func _pick_gym(rng: SimRandom, country: String, base: String) -> String:
	var weights := {}
	for g: Dictionary in ContentDB.load_json("gyms.json"):
		if g.country != country:
			continue
		weights[g.id] = 2.0 if base in g.specialties or "complete" in g.specialties else 1.0
	# Nem todo atleta treina numa academia de elite: a maioria fica em equipes locais.
	if weights.is_empty() or rng.chance(0.55):
		return ""
	return str(rng.weighted(weights))


static func _division_limit_kg(division: String) -> float:
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):
		if d.id == division:
			return float(d.limit_kg)
	return 70.0


static func _weighted_key(rng: SimRandom, table: Dictionary, field: String) -> String:
	var weights := {}
	for key: String in table:
		weights[key] = float(table[key].get(field, 1.0))
	return str(rng.weighted(weights))
