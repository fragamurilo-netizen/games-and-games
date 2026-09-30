class_name FighterEditor
extends RefCounted
## Criar e editar lutadores dentro do jogo (Game Design Bible §§4,5,22).
## Toda validação mora aqui; a UI só monta o formulário e envia os campos.
## O histórico de lutas é preservado: cartel só é editável antes da primeira
## luta no save, e troca de categoria é bloqueada com luta marcada.

const GROUPS := ["striking", "grappling", "jiu_jitsu", "physical", "mental"]
const STANCES := ["orthodox", "southpaw", "switch"]


## p: division, country, martial_base, fight_style, age, level, population,
## prospect (bool), to_roster (bool). Campos vazios = sorteio do gerador.
static func create(world: WorldState, p: Dictionary) -> Dictionary:
	var opts := _generation_opts(world, p)
	if opts.has("error"):
		return _error(opts.error)
	var f := FighterGenerator.create(world, opts)
	world.add("fighters", f)
	if bool(p.get("to_roster", false)):
		_sign_to_player(world, f)
	for org_id: String in ["wci", f.organization_id]:
		if not org_id.is_empty():
			Rankings.new().update(world, org_id, f.division)
	return {"ok": true, "fighter_id": f.id, "message": "%s criado. Ajuste o que quiser e salve." % f.display_name()}


## Sorteia de novo um atleta que ainda não lutou neste save, mantendo id,
## contrato e organização. Aceita as mesmas opções de `create`.
static func reroll(world: WorldState, id: String, p: Dictionary) -> Dictionary:
	var f: Fighter = world.fighters.get(id)
	if f == null:
		return _error("INVALID_FIGHTER")
	if not f.fight_ids.is_empty():
		return _error("FIGHTER_HAS_HISTORY")
	if f.division != str(p.get("division", f.division)) and _is_booked(world, f):
		return _error("FIGHTER_BOOKED")
	var opts := _generation_opts(world, p)
	if opts.has("error"):
		return _error(opts.error)
	var fresh := FighterGenerator.create(world, opts)
	var old_division := f.division
	for key: String in ["first_name", "last_name", "nickname", "country", "city", "languages", "sex", "birth_date", "gym_id",
			"height_cm", "reach_cm", "stance", "body_type", "division", "natural_weight_kg", "martial_base", "fight_style", "style",
			"striking", "grappling", "jiu_jitsu", "physical", "mental", "hidden", "potential", "record", "career_goals",
			"popularity_by_region", "charisma", "appearance", "bio"]:
		f.set(key, fresh.get(key))
	_refresh_rankings(world, f, old_division)
	return {"ok": true, "fighter_id": f.id, "message": "Novo sorteio: %s." % f.display_name()}


## Aplica só os campos presentes em p. Retorna reasons se algo for inválido
## e, nesse caso, não altera nada.
static func edit(world: WorldState, id: String, p: Dictionary) -> Dictionary:
	var f: Fighter = world.fighters.get(id)
	if f == null:
		return _error("INVALID_FIGHTER")
	var cfg: Dictionary = ContentDB.load_json(FighterGenerator.CONTENT)
	var reasons: Array = []
	var first := _clean(p.get("first_name", f.first_name), 24)
	var last := _clean(p.get("last_name", f.last_name), 24)
	if first.is_empty() or last.is_empty():
		reasons.append(Reason.make("INVALID_NAME"))
	var country := str(p.get("country", f.country))
	if country != f.country and not cfg.countries.has(country):
		reasons.append(Reason.make("UNKNOWN_COUNTRY"))
	var division := str(p.get("division", f.division))
	if division != f.division:
		if not _division_exists(division):
			reasons.append(Reason.make("INVALID_DIVISION"))
		elif _is_booked(world, f):
			reasons.append(Reason.make("FIGHTER_BOOKED"))
	var base := str(p.get("martial_base", f.martial_base))
	if not cfg.archetypes.has(base):
		reasons.append(Reason.make("INVALID_STYLE"))
	var fight_style := str(p.get("fight_style", f.fight_style))
	if not fight_style.is_empty() and not cfg.fight_styles.has(fight_style):
		reasons.append(Reason.make("INVALID_STYLE"))
	var stance := str(p.get("stance", f.stance))
	if not stance in STANCES:
		reasons.append(Reason.make("INVALID_STYLE"))
	var body_type := str(p.get("body_type", f.body_type))
	if not cfg.body_type_names.has(body_type):
		reasons.append(Reason.make("INVALID_BODY"))
	var population := str(p.get("population", f.appearance.get("pop", "")))
	if p.has("population") and not cfg.population_names.has(population):
		reasons.append(Reason.make("INVALID_BODY"))
	if p.has("record") and not f.fight_ids.is_empty():
		reasons.append(Reason.make("FIGHTER_HAS_HISTORY"))
	if not reasons.is_empty():
		return {"ok": false, "reasons": reasons}

	var old_division := f.division
	f.first_name = first
	f.last_name = last
	if p.has("nickname"):
		f.nickname = _clean(p.nickname, 24)
	if country != f.country:
		f.country = country
		f.languages = cfg.countries[country].languages.duplicate()
		f.city = str(cfg.countries[country].cities[0])
	if p.has("city") and not _clean(p.city, 32).is_empty():
		f.city = _clean(p.city, 32)
	if division != f.division:
		f.division = division
		f.sex = Fighter.Sex.FEMALE if division.begins_with("w_") else Fighter.Sex.MALE
	f.martial_base = base
	if fight_style != f.fight_style:
		f.fight_style = fight_style
		f.style = cfg.fight_styles[fight_style]["style"].duplicate() if not fight_style.is_empty() else {}
	f.stance = stance
	f.body_type = body_type
	if p.has("age"):
		var age := clampi(int(p.age), 18, 45)
		f.birth_date = {"year": int(world.date.year) - age, "month": int(f.birth_date.get("month", 1)), "day": int(f.birth_date.get("day", 1))}
		if f.age_on(world.date) != age:
			f.birth_date.year -= 1
	if p.has("height_cm"):
		f.height_cm = clampi(int(p.height_cm), 140, 215)
	if p.has("reach_cm"):
		f.reach_cm = clampi(int(p.reach_cm), f.height_cm - 10, f.height_cm + 20)
	else:
		f.reach_cm = clampi(f.reach_cm, f.height_cm - 10, f.height_cm + 20)
	if p.has("charisma"):
		f.charisma = clampi(int(p.charisma), 1, 99)
	if p.has("bio"):
		f.bio = _clean(p.bio, 280)
	for group: String in p.get("group_levels", {}):
		if group in GROUPS and not f.get(group).is_empty():
			var values: Dictionary = f.get(group)
			var shift := int(round(float(p.group_levels[group]) - _avg(values)))
			for attribute: String in values:
				values[attribute] = clampi(int(values[attribute]) + shift, 1, 99)
	var attributes: Dictionary = p.get("attributes", {})
	for group: String in attributes:
		if not group in GROUPS:
			continue
		var values: Dictionary = f.get(group)
		for attribute: String in attributes[group]:
			if values.has(attribute):
				values[attribute] = clampi(int(attributes[group][attribute]), 1, 99)
	if p.has("record"):
		for key: String in ["wins", "losses", "draws"]:
			f.record[key] = clampi(int(p.record.get(key, f.record[key])), 0, 99)
	_sync_appearance(world, f, cfg, population, bool(p.get("reroll_face", false)))
	_refresh_rankings(world, f, old_division)
	return {"ok": true, "fighter_id": f.id, "message": "Alterações salvas: %s." % f.display_name()}


## Listas para o formulário (ids + nomes vindos do conteúdo).
static func options() -> Dictionary:
	var cfg: Dictionary = ContentDB.load_json(FighterGenerator.CONTENT)
	var out := {"countries": [], "martial_bases": [], "fight_styles": [], "populations": [], "body_types": [], "stances": [], "divisions": []}
	var codes: Array = cfg.countries.keys()
	codes.sort_custom(func(a, b): return str(cfg.country_names.get(a, a)) < str(cfg.country_names.get(b, b)))
	for code: String in codes:
		out.countries.append({"id": code, "label": str(cfg.country_names.get(code, code))})
	for base: String in cfg.archetypes:
		out.martial_bases.append({"id": base, "label": FighterGenerator.base_name(base, cfg)})
	for style: String in cfg.fight_styles:
		out.fight_styles.append({"id": style, "label": str(cfg.fight_styles[style].name)})
	for pop: String in cfg.population_names:
		out.populations.append({"id": pop, "label": str(cfg.population_names[pop])})
	for body: String in cfg.body_type_names:
		out.body_types.append({"id": body, "label": str(cfg.body_type_names[body])})
	for stance: String in STANCES:
		out.stances.append({"id": stance, "label": {"orthodox": "Ortodoxa", "southpaw": "Canhota", "switch": "Troca a guarda"}[stance]})
	var tuning: Dictionary = ContentDB.load_json("career_tuning.json")
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):
		if d.id in tuning.player_divisions:
			out.divisions.append({"id": d.id, "label": "%s · %s" % [d.name, "feminino" if d.sex == "F" else "masculino"]})
	return out


static func group_level(f: Fighter, group: String) -> int:
	return int(round(_avg(f.get(group))))


static func _generation_opts(world: WorldState, p: Dictionary) -> Dictionary:
	var cfg: Dictionary = ContentDB.load_json(FighterGenerator.CONTENT)
	var opts := {"cfg": cfg, "prospect": bool(p.get("prospect", false))}
	var used := {}
	for old: Fighter in world.fighters.values():
		used[old.first_name + " " + old.last_name] = true
	opts.used_names = used
	var division := str(p.get("division", ""))
	if not division.is_empty():
		if not _division_exists(division):
			return {"error": "INVALID_DIVISION"}
		opts.division = division
	for key: String in ["country", "martial_base", "fight_style", "population"]:
		var value := str(p.get(key, ""))
		if not value.is_empty():
			opts[key] = value
	if opts.has("country") and not cfg.countries.has(opts.country):
		return {"error": "UNKNOWN_COUNTRY"}
	if p.has("age") and int(p.age) > 0:
		opts.age = clampi(int(p.age), 18, 45)
	if p.has("level") and float(p.level) > 0:
		opts.level = float(p.level)
	return opts


static func _sync_appearance(world: WorldState, f: Fighter, cfg: Dictionary, population: String, reroll: bool) -> void:
	var age := f.age_on(world.date)
	var base_height := int(ContentDB.load_json("career_tuning.json").division_height.get(f.division, 175))
	var height := clampf((f.height_cm - base_height) / 24.0 + 0.5, 0.0, 1.0)
	var sex := "f" if f.sex == Fighter.Sex.FEMALE else "m"
	var a: Dictionary = f.appearance
	var body_changed: bool = a.get("body_type", "") != f.body_type
	# Atletas canônicos usam o retrato autoral até alguém pedir um rosto novo.
	if not a.has("pop") and not reroll:
		return
	if reroll or a.get("sex", sex) != sex:
		f.appearance = FaceGenerator.create_appearance(world.rng, f.country, f.body_type, age, sex, {"height": height, "pop": population})
		return
	if cfg.population_names.has(population):
		a.pop = population
	a.age = age
	a.country = f.country
	if body_changed:
		var fresh := FaceGenerator.create_appearance(world.rng, f.country, f.body_type, age, sex, {"height": height, "pop": a.pop})
		a.body = fresh.body
		a.body_type = f.body_type
	var body: Dictionary = a.get("body", {})
	body.height = snappedf(height, 0.01)
	a.body = body


static func _sign_to_player(world: WorldState, f: Fighter) -> void:
	var cfg: Dictionary = ContentDB.load_json("career_tuning.json")
	var offer := Contract.new()
	offer.fighter_id = f.id
	offer.organization_id = world.player_org_id
	offer.show_money = Contracts.market_price(world, f)
	offer.win_bonus = int(offer.show_money * float(cfg.contracts.win_bonus_ratio))
	offer.bouts_total = int(cfg.contracts.bouts)
	offer.bouts_remaining = offer.bouts_total
	offer.expires_on = GameDate.add_days(world.date, int(cfg.contracts.term_days))
	Contracts.new().sign(world, offer)


static func _refresh_rankings(world: WorldState, f: Fighter, old_division: String) -> void:
	var orgs: Array = ["wci"]
	if not f.organization_id.is_empty():
		orgs.append(f.organization_id)
	for org_id: String in orgs:
		Rankings.new().update(world, org_id, f.division)
		if old_division != f.division:
			Rankings.new().update(world, org_id, old_division)


static func _is_booked(world: WorldState, f: Fighter) -> bool:
	for fight: Fight in world.fights.values():
		if fight.status in ["booked", "proposed"] and f.id in [fight.fighter_a_id, fight.fighter_b_id]:
			return true
	return false


static func _division_exists(id: String) -> bool:
	for d: Dictionary in ContentDB.load_json("weight_classes.json"):
		if d.id == id:
			return true
	return false


static func _clean(value: Variant, limit: int) -> String:
	return str(value).strip_edges().replace("\n", " ").left(limit)


static func _avg(values: Dictionary) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values.values():
		total += float(v)
	return total / values.size()


static func _error(code: String) -> Dictionary:
	return {"ok": false, "reasons": [Reason.make(code)]}
