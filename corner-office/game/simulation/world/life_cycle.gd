class_name LifeCycle
extends RefCounted
## Passagem do tempo para os atletas (Game Design Bible §4, §13; MMA Bible §15, §18).
## Todo dia: lesões cicatrizam. Todo dia 1º: atributos evoluem pela curva de
## idade (potencial dinâmico, atividade e dano acumulado), popularidade esfria
## na inatividade, veteranos se aposentam e uma nova safra entra no mundo.
## Parâmetros em content/world_tuning.json.

var _cfg: Dictionary = {}
static var _regions: Array = []

# Traços de estilo, não de habilidade: não mudam com a idade.
const STYLE_ATTRIBUTES := ["aggression", "patience"]


func _init() -> void:
	_cfg = ContentDB.load_json("world_tuning.json")


## Chamado uma vez por dia pelo WorldSim. Devolve o que mudou no mês (para o
## resumo da passagem de tempo); vazio fora do dia 1º.
func daily(world: WorldState) -> Dictionary:
	_heal(world)
	if int(world.date.day) != 1:
		return {}
	return monthly(world)


func monthly(world: WorldState) -> Dictionary:
	for f: Fighter in world.fighters.values():
		if f.retired:
			continue
		_develop(world, f)
		_cool_down(world, f)
		_expire_bids(world, f)
	var retired := _retirements(world)
	var prospects := _regen(world, retired)
	return {"retired": retired.map(func(f: Fighter): return f.id), "prospects": prospects}


static func curve(points: Array, x: float) -> float:
	if x <= float(points[0][0]):
		return float(points[0][1])
	for i in range(1, points.size()):
		var a: Array = points[i - 1]
		var b: Array = points[i]
		if x <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (x - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(points[-1][1])


static func region_of(country: String) -> String:
	if _regions.is_empty():
		_regions = ContentDB.load_json("regions.json")
	for r: Dictionary in _regions:
		if country in r.countries:
			return r.id
	return ""


static func last_fight_date(world: WorldState, f: Fighter) -> Dictionary:
	for i in range(f.fight_ids.size() - 1, -1, -1):
		var fight: Fight = world.fights.get(f.fight_ids[i])
		if fight and world.events.has(fight.event_id):
			return world.events[fight.event_id].date
	return f.debut_on


## Arredondamento estocástico: variações mensais pequenas acumulam sem viés.
static func _round(world: WorldState, x: float) -> int:
	var whole := floorf(x)
	return int(whole) + (1 if world.rng.chance(x - whole) else 0)


# ---------------------------------------------------------------- evolução

func _develop(world: WorldState, f: Fighter) -> void:
	var d: Dictionary = _cfg.development
	var age := float(f.age_on(world.date))
	var last := last_fight_date(world, f)
	var active := not last.is_empty() and GameDate.days_between(last, world.date) <= int(d.active_days)
	var potential := float(f.potential.get("mean", 50.0))
	var ceiling := float(d.ceiling_base) + potential * float(d.ceiling_per_potential)
	var talent := clampf(potential / 50.0, .5, 1.8)
	var head_wear := float(f.damage_history.get("head", 0.0)) * float(d.chin_wear_per_head_damage)
	for group: String in ["striking", "grappling", "jiu_jitsu", "physical", "mental"]:
		var base := curve(d["physical_curve" if group == "physical" else "mental_curve" if group == "mental" else "technical_curve"], age)
		var values: Dictionary = f.get(group)
		for key: String in values.keys():
			if key in STYLE_ATTRIBUTES:
				continue
			var v := float(values[key])
			var delta := base
			if delta > 0.0:
				delta *= talent * clampf((ceiling - v) / 20.0, 0.0, 1.0)
				if not active:
					delta *= float(d.inactive_growth_factor)
			if group == "physical" and key in d.wear_attributes:
				delta -= head_wear
			delta += world.rng.normal(0.0, float(d.noise))
			values[key] = clampi(int(v) + _round(world, delta), int(d.min_value), int(d.max_value))


func _cool_down(world: WorldState, f: Fighter) -> void:
	var p: Dictionary = _cfg.popularity
	var last := last_fight_date(world, f)
	if not last.is_empty() and GameDate.days_between(last, world.date) <= int(p.inactive_days):
		return
	if last.is_empty() and f.fight_ids.is_empty() and not f.debut_on.is_empty() and GameDate.days_between(f.debut_on, world.date) <= int(p.inactive_days):
		return
	for region: String in f.popularity_by_region:
		f.popularity_by_region[region] = maxf(0.0, float(f.popularity_by_region[region]) - float(p.inactive_decay))


func _expire_bids(world: WorldState, f: Fighter) -> void:
	for org_id: String in f.rival_interest.keys():
		if GameDate.days_between(world.date, f.rival_interest[org_id].until) < 0:
			f.rival_interest.erase(org_id)


# ---------------------------------------------------------------- lesões

func _heal(world: WorldState) -> void:
	for f: Fighter in world.fighters.values():
		if f.injuries.is_empty():
			continue
		f.injuries = f.injuries.filter(func(i: Dictionary): return i.has("until") and GameDate.days_between(world.date, i.until) > 0)


## Lesão aguda depois da luta, proporcional ao dano sofrido (MMA Bible §15).
func after_fight(world: WorldState, fight: Fight) -> void:
	var cfg: Dictionary = _cfg.injuries
	for id: String in [fight.fighter_a_id, fight.fighter_b_id]:
		var dmg: Dictionary = fight.damage.get(id, {})
		var zones := {"head": float(dmg.get("head", 0.0)), "body": float(dmg.get("body", 0.0)), "leg": float(dmg.get("leg", 0.0))}
		var total: float = zones.head + zones.body + zones.leg
		if not world.rng.chance(float(cfg.post_fight_base) + total * float(cfg.per_damage)):
			continue
		var zone := "head"
		for z: String in zones:
			if zones[z] > zones[zone]:
				zone = z
		var kind: String = world.rng.weighted(cfg.weights_by_zone[zone])
		var days: Array = cfg.types[kind]
		var f: Fighter = world.fighters[id]
		var until := GameDate.add_days(world.date, world.rng.range_i(int(days[0]), int(days[1])))
		f.injuries.append({"type": kind, "until": until, "fight_id": fight.id})
		if f.organization_id == world.player_org_id:
			story(world, "fighter_injured", "injury", {"fighter": f.display_name(), "injury": _cfg.labels.injuries.get(kind, kind), "date": GameDate.format(until)}, [f.id, fight.id])


# ---------------------------------------------------------------- aposentadoria

func _retirements(world: WorldState) -> Array:
	var r: Dictionary = _cfg.retirement
	var booked := {}
	for fight: Fight in world.fights.values():
		if fight.status == "booked":
			booked[fight.fighter_a_id] = true
			booked[fight.fighter_b_id] = true
	var out: Array = []
	for f: Fighter in world.fighters.values():
		if f.retired or booked.has(f.id):
			continue
		var age := f.age_on(world.date)
		var p := curve(r.age_curve, age)
		p += float(f.damage_history.get("head", 0.0)) * float(r.head_damage_per_unit)
		if _losing_streak(world, f, 3):
			p += float(r.losing_streak_bonus)
		if f.organization_id.is_empty() and age >= int(r.unsigned_veteran_age):
			p += float(r.unsigned_bonus)
		if _is_top_ranked(world, f):
			p *= float(r.champion_factor)
		if p > 0.0 and world.rng.chance(p):
			retire(world, f)
			out.append(f)
	return out


func retire(world: WorldState, f: Fighter) -> void:
	var was_player := f.organization_id == world.player_org_id
	var org_id := f.organization_id
	f.retired = true
	f.retired_on = world.date.duplicate()
	f.rival_interest = {}
	var c: Contract = world.contracts.get(f.contract_id)
	if c and c.active:
		c.active = false
	if not org_id.is_empty():
		world.organizations[org_id].roster.erase(f.id)
		f.organization_id = ""
		Rankings.new().update(world, org_id, f.division)
	Rankings.new().update(world, Rankings.WCI_ORG_ID, f.division)
	EventBus.fighter_retired.emit(f.id)
	if was_player or f.record.wins >= 12 or _fame(f) >= 30.0:
		story(world, "fighter_retired", "retired", {"fighter": f.display_name(), "age": f.age_on(world.date), "record": f.record_string()}, [f.id])


static func _losing_streak(world: WorldState, f: Fighter, n: int) -> bool:
	if f.fight_ids.size() < n:
		return false
	for id: String in f.fight_ids.slice(-n):
		var fight: Fight = world.fights.get(id)
		if fight == null or fight.winner_id.is_empty() or fight.winner_id == f.id:
			return false
	return true


static func _is_top_ranked(world: WorldState, f: Fighter) -> bool:
	if f.organization_id.is_empty():
		return false
	var ranking := Rankings.new().latest(world, f.organization_id, f.division)
	return ranking != null and not ranking.entries.is_empty() and ranking.entries[0] == f.id


static func _fame(f: Fighter) -> float:
	var best := 0.0
	for v in f.popularity_by_region.values():
		best = maxf(best, float(v))
	return best


# ---------------------------------------------------------------- nova safra

func _regen(world: WorldState, retired: Array) -> Array:
	var g: Dictionary = _cfg.regen
	var free := 0
	for f: Fighter in world.fighters.values():
		if not f.retired and f.organization_id.is_empty():
			free += 1
	var divisions: Array = retired.map(func(f: Fighter): return f.division)
	if free < int(g.maximum_free_agents) and world.rng.chance(float(g.extra_prospect_chance)):
		divisions.append("")
	for i in maxi(0, int(g.minimum_free_agents) - free - divisions.size()):
		divisions.append("")
	var out: Array = []
	for division: String in divisions:
		out.append(make_prospect(world, division).id)
	return out


## Jovem atleta gerado durante a carreira (Game Design Bible §13). Mesmo
## vocabulário do PopulationGenerator, mas com idade baixa e potencial largo.
func make_prospect(world: WorldState, division: String = "") -> Fighter:
	var g: Dictionary = _cfg.regen
	var cfg: Dictionary = ContentDB.load_json("career_tuning.json")
	var attrs: Dictionary = ContentDB.load_json("attributes.json")
	var profiles: Array = ContentDB.load_json("combat_profiles.json").fighters.values()
	var styles: Array = ContentDB.load_json("fight_tuning.json").styles.keys()
	var used := {}
	for other: Fighter in world.fighters.values():
		used[other.first_name + " " + other.last_name] = true
	var f := Fighter.new()
	f.id = world.new_id("ftr")
	var region: Dictionary = world.rng.pick(cfg.names)
	f.division = division if not division.is_empty() else str(world.rng.pick(cfg.player_divisions))
	f.sex = Fighter.Sex.FEMALE if f.division.begins_with("w_") else Fighter.Sex.MALE
	for attempt in 200:
		f.first_name = world.rng.pick(region.female if f.sex == Fighter.Sex.FEMALE else region.male)
		f.last_name = world.rng.pick(region.last)
		if not used.has(f.first_name + " " + f.last_name):
			break
	f.country = region.country
	f.city = region.city
	var age := world.rng.range_i(int(g.age[0]), int(g.age[1]))
	f.birth_date = {"year": int(world.date.year) - age, "month": world.rng.range_i(1, 12), "day": world.rng.range_i(1, 28)}
	f.height_cm = int(cfg.division_height.get(f.division, 175)) + world.rng.range_i(-8, 8)
	f.reach_cm = f.height_cm + world.rng.range_i(-3, 11)
	f.martial_base = world.rng.pick(styles)
	f.stance = world.rng.weighted({"orthodox": .68, "southpaw": .25, "switch": .07})
	var level := world.rng.range_i(int(g.level[0]), int(g.level[1]))
	var template: Dictionary = world.rng.pick(profiles)
	for group: String in ["striking", "grappling", "jiu_jitsu", "physical", "mental"]:
		var values := {}
		for attribute: String in attrs[group]:
			values[attribute] = clampi(level + world.rng.range_i(-13, 13) + int(template[group].get(attribute, 65)) - 75, 20, 90)
		f.set(group, values)
	f.potential = {"mean": world.rng.range_f(float(g.potential_mean[0]), float(g.potential_mean[1])), "spread": world.rng.range_f(float(g.potential_spread[0]), float(g.potential_spread[1]))}
	f.record = {"wins": world.rng.range_i(int(g.wins[0]), int(g.wins[1])), "losses": world.rng.range_i(int(g.losses[0]), int(g.losses[1])), "draws": 0, "nc": 0}
	f.popularity_by_region = {region.region: world.rng.range_i(int(g.popularity[0]), int(g.popularity[1]))}
	f.charisma = world.rng.range_i(20, 80)
	f.appearance = {"seed": world.rng.range_i(1, 2000000000), "sex": "f" if f.sex == Fighter.Sex.FEMALE else "m", "pop": "misto"}
	f.debut_on = world.date.duplicate()
	world.add("fighters", f)
	return f


## Notícia factual gerada pela passagem do tempo (MMA Bible §27).
static func story(world: WorldState, topic: String, key: String, vars: Dictionary, ids: Array) -> NewsItem:
	var templates: Dictionary = ContentDB.load_json("world_tuning.json").stories
	var item := Media.new().publish(world, topic, [Reason.make(topic.to_upper(), 0.0, vars)], ids)
	item.headline = str(templates[key]).format(vars)
	item.body = str(templates.get(key + "_body", "")).format(vars)
	return item
