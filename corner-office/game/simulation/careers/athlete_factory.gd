class_name AthleteFactory
extends RefCounted
## Geração realista de atletas (Game Design Bible §0, §4, §5, §13 "Geração de
## novos lutadores"; MMA Bible §7, §14, §18).
##
## Ordem: país (peso do país no MMA profissional, talento regional) → grupo
## étnico do país → nome coerente com o grupo → população facial do gerador de
## rostos → sexo/divisão (tamanho corporal por país) → altura/envergadura/peso
## pela divisão → base marcial (tendência regional, nunca destino) → modelo
## latente de carreira → atributos → carreira pregressa → popularidade.
## Todo sorteio passa por `rng` (world.rng na criação do mundo).

static var _countries: Array = []
static var _names: Dictionary = {}
static var _blocked: Dictionary = {}
static var _weights: Dictionary = {}
static var _classes: Array = []
static var _regions: Array = []


static func weight_classes() -> Array:
	if _classes.is_empty():
		_classes = ContentDB.load_json("weight_classes.json")
	return _classes


static func regions() -> Array:
	if _regions.is_empty():
		_regions = ContentDB.load_json("regions.json")
	return _regions


static func countries() -> Array:
	if _countries.is_empty():
		_countries = ContentDB.load_json("countries.json")
	return _countries


static func names() -> Dictionary:
	if _names.is_empty():
		_names = ContentDB.load_json("name_pools.json")
		for n: String in ContentDB.load_json("name_blocklist.json"):
			_blocked[n] = true
	return _names


static func country(code: String) -> Dictionary:
	for c: Dictionary in countries():
		if c.code == code:
			return c
	return countries()[0]


static func region_of(code: String) -> String:
	return str(country(code).get("region", ""))


## Peso de cada país. `talent_bias` > 0 favorece países de tradição (elite).
static func country_weights(sex: int, talent_bias: float) -> Dictionary:
	var key := "%d:%.2f" % [sex, talent_bias]
	if _weights.has(key):
		return _weights[key]
	var out := {}
	for c: Dictionary in countries():
		var share := float(c.female_share) if sex == Fighter.Sex.FEMALE else 1.0 - float(c.female_share)
		out[c.code] = float(c.weight) * share * exp(float(c.talent) * talent_bias)
	_weights[key] = out
	return out


## Sobrenomes que flexionam no feminino (Morozov → Morozova, Kowalski → Kowalska).
const SURNAME_RULES := {"ru": "slavic", "dag": "slavic", "az": "slavic", "uk": "slavic", "kz": "kazakh", "pl": "polish"}


static func _full_name(first: String, last: String) -> String:
	return first + " " + last


## Nome inventado para adversários do circuito (não viram entidades).
static func phantom_name(_world: WorldState, rng: SimRandom, country_code: String, sex: int) -> String:
	var c := country(country_code) if not country_code.is_empty() else country(rng.weighted(country_weights(sex, 0.0)))
	var group: Dictionary = rng.weighted(_group_weights(c))
	var pools := names()
	var first_pool: Dictionary = pools[group.first]
	var firsts: Array = first_pool.f if sex == Fighter.Sex.FEMALE and not first_pool.f.is_empty() else first_pool.m
	return _full_name(rng.pick(firsts), rng.pick(pools[group.last].last))


static func _group_weights(c: Dictionary) -> Dictionary:
	var out := {}
	for g: Dictionary in c.groups:
		out[g] = float(g.w)
	return out


static func _pick_division(rng: SimRandom, sex: int, height_offset: float) -> String:
	var weights := {}
	var ids: Array = []
	for d: Dictionary in weight_classes():
		if (d.sex == "F") == (sex == Fighter.Sex.FEMALE):
			ids.append(d.id)
	var center := (ids.size() - 1) / 2.0
	for i in ids.size():
		# Países mais altos produzem mais atletas pesados (e vice-versa).
		weights[ids[i]] = float(CareerModel.division(ids[i]).share) * exp(height_offset * 0.12 * (i - center))
	return rng.weighted(weights)


## spec: {tier, division?, sex?, country?, age?, used_names (Dictionary)}
static func create(world: WorldState, rng: SimRandom, spec: Dictionary) -> Fighter:
	var cm := CareerModel.cfg()
	var tier: String = spec.get("tier", "circuit")
	var tier_cfg: Dictionary = cm.tiers[tier]
	var f := Fighter.new()
	f.id = world.new_id("ftr")
	# --- sexo, país, divisão
	var division: String = spec.get("division", "")
	if not division.is_empty():
		f.sex = Fighter.Sex.FEMALE if division.begins_with("w_") else Fighter.Sex.MALE
	else:
		f.sex = int(spec.get("sex", Fighter.Sex.FEMALE if rng.chance(0.19) else Fighter.Sex.MALE))
	var talent_bias := 0.35 if tier == "flagship" else 0.15 if tier == "national" else 0.0
	var c := country(spec.get("country", rng.weighted(country_weights(f.sex, talent_bias))))
	f.country = c.code
	f.languages = c.languages.duplicate()
	f.division = division if not division.is_empty() else _pick_division(rng, f.sex, float(c.height_offset))
	# --- etnia e nome coerentes (Bible §13: coerentes entre si e variados)
	var group: Dictionary = rng.weighted(_group_weights(c))
	# Cidade do grupo quando o país tem regiões marcadas (ex.: Daguestão × Moscou).
	f.city = rng.pick(group.get("cities", c.cities))
	var pools := names()
	var used: Dictionary = spec.get("used_names", {})
	var first_pool: Dictionary = pools[group.first]
	var firsts: Array = first_pool.f if f.sex == Fighter.Sex.FEMALE else first_pool.m
	for attempt in 60:
		f.first_name = rng.pick(firsts)
		f.last_name = rng.pick(pools[group.last].last)
		if f.sex == Fighter.Sex.FEMALE:
			f.last_name = FighterGenerator.female_surname(f.last_name, str(SURNAME_RULES.get(group.last, "")))
		var full := _full_name(f.first_name, f.last_name)
		if not used.has(full) and not _blocked.has(full):
			break
	used[_full_name(f.first_name, f.last_name)] = true
	# --- idade
	var age: float = spec.get("age", clampf(rng.normal(float(tier_cfg.age[0]), float(tier_cfg.age[1])), float(tier_cfg.range[0]), float(tier_cfg.range[1])))
	f.birth_date = GameDate.add_days(world.date, -roundi(age * 365.25) - rng.range_i(0, 364))
	age = CareerModel.age_on(f, world.date)
	# --- corpo (MMA Bible §14: quatro pesos; aqui altura, envergadura e peso natural)
	var d := CareerModel.division(f.division)
	f.height_cm = roundi(rng.normal(float(d.height[0]) + float(c.height_offset) * 0.35, float(d.height[1])))
	var ape: Array = cm.reach_ape_index
	f.reach_cm = f.height_cm + roundi(rng.normal(float(ape[0]), float(ape[1])))
	var limit := _limit_kg(f.division)
	f.natural_weight_kg = snappedf(limit * rng.normal(float(d.weight_ratio), 0.035), 0.1)
	if f.division == "m_heavyweight":
		f.natural_weight_kg = snappedf(clampf(f.natural_weight_kg, 95.0, 122.0), 0.1)
	# --- base marcial: tendência do país, nunca destino
	f.martial_base = rng.weighted(c.bases)
	var stance: Dictionary = cm.stance.duplicate()
	if f.martial_base in ["karate", "taekwondo", "kickboxing"]:
		stance["switch"] = float(stance.switch) * 2.2
	f.stance = rng.weighted(stance)
	f.body_type = _body_type(f, limit)
	# --- modelo latente
	var h := {}
	var prime := float(d.prime) + float(cm.style_prime_shift.get(f.martial_base, 0.0)) + rng.normal(0.0, float(cm.prime_sd))
	if f.sex == Fighter.Sex.FEMALE:
		prime -= 0.3
	h["prime_age"] = snappedf(prime, 0.1)
	var blue: Dictionary = cm.blue_chip
	var gap_cfg: Array = cm.growth_gap
	if age <= float(blue.max_age) and rng.chance(float(blue.chance)):
		gap_cfg = blue.growth_gap
		h["blue_chip"] = true
	h["growth_gap"] = snappedf(maxf(6.0, rng.normal(float(gap_cfg[0]), float(gap_cfg[1]))), 0.1)
	h["decline_rate"] = snappedf(maxf(0.05, rng.normal(float(cm.decline_rate[0]), float(cm.decline_rate[1]))), 0.001)
	for trait_key: String in CareerModel.attribute_keys().hidden:
		h[trait_key] = clampi(roundi(rng.normal(55.0, 15.0)), 5, 95)
	h["weight_cut_ease"] = clampi(roundi(80.0 - (f.natural_weight_kg / limit - 1.0) * 300.0 + rng.normal(0.0, 10.0)), 5, 95)
	var noise := {}
	var keys := CareerModel.attribute_keys()
	for group_name: String in CareerModel.GROUPS:
		for key: String in keys[group_name]:
			noise[key] = snappedf(rng.normal(0.0, float(cm.attribute_noise)), 0.1)
	h["attr_noise"] = noise
	var bias := {}
	for key: String in ["boxing", "kicks", "takedown", "submission", "movement"]:
		bias[key] = snappedf(rng.normal(0.0, 0.1), 0.01)
	h["style_bias"] = bias
	f.hidden = h
	var current: float = spec.get("ability", rng.normal(float(tier_cfg.ability[0]), float(tier_cfg.ability[1])) + float(c.talent))
	current = clampf(current, 25.0, 90.0)
	h["ability_peak"] = snappedf(clampf(CareerModel.peak_for(f, current, age), 30.0, 97.0), 0.1)
	f.potential = {"mean": h.ability_peak, "spread": snappedf(4.0 + maxf(0.0, float(h.prime_age) - age) * 1.2, 0.1)}
	# --- mercado e identidade pública
	f.charisma = clampi(roundi(rng.normal(50.0, 16.0)), 5, 98)
	h["natural_charisma"] = f.charisma
	f.hidden["background"] = background(rng, f)
	f.appearance = {"seed": rng.range_i(1, 2000000000), "sex": "f" if f.sex == Fighter.Sex.FEMALE else "m", "pop": group.pop}
	# --- carreira pregressa e atributos resultantes. Liga principal contrata
	# quem tem lutas e vem vencendo (sobrevivência, Bible §0): refaz se não.
	var min_bouts: int = {"flagship": 5, "national": 3}.get(tier, 0)
	var info := {}
	for attempt in 6:
		f.record = {"wins": 0, "losses": 0, "draws": 0, "nc": 0}
		f.damage_history = {"head": 0.0, "body": 0.0, "legs": 0.0}
		f.history = {"background": f.hidden.background, "results": [], "streak": 0}
		f.rating = float(CareerModel.cfg().elo.start)
		f.last_fight_on = {}
		info = CareerHistory.backstory(world, rng, f, world.date, tier, current)
		if CareerModel.pro_bouts(f) >= min_bouts and (tier != "flagship" or info.get("in_league", true)):
			break
	f.history["flagship_debut_on"] = info.flagship_debut_on
	f.history["flagship_bouts"] = info.flagship_bouts
	CareerModel.refresh_attributes(f, world.date)
	_popularity(f, rng, tier)
	return f


## Origem esportiva coerente com base, país e nível (um "wrestler olímpico"
## precisa ter tido nível para isso).
static func background(rng: SimRandom, f: Fighter) -> String:
	var weights := {}
	for b: Dictionary in CareerModel.bases().backgrounds.get(f.martial_base, []):
		if b.has("countries") and f.country not in b.countries:
			continue
		if float(f.hidden.get("ability_peak", 60.0)) < float(b.get("min_peak", 0)):
			continue
		weights[b.text] = float(b.w)
	return "Formado no MMA" if weights.is_empty() else str(rng.weighted(weights))


static func _limit_kg(division: String) -> float:
	for d: Dictionary in weight_classes():
		if d.id == division:
			return float(d.limit_kg)
	return 70.3


static func _body_type(f: Fighter, limit: float) -> String:
	if f.division == "m_heavyweight":
		return "heavy" if f.natural_weight_kg > 110.0 else "muscular"
	var bmi := f.natural_weight_kg / pow(f.height_cm / 100.0, 2)
	var expected := limit * 1.1 / pow(float(CareerModel.division(f.division).height[0]) / 100.0, 2)
	if bmi < expected * 0.94:
		return "lean"
	if bmi > expected * 1.07:
		return "compact" if f.height_cm < float(CareerModel.division(f.division).height[0]) else "muscular"
	return "athletic"


## Popularidade regional separada de skill (MMA Bible §18): exposição da
## liga, finalizações, sequência e carisma. Casa > vizinhos > resto.
static func _popularity(f: Fighter, rng: SimRandom, tier: String) -> void:
	var exposure: float = {"flagship": 12.0, "national": 5.0, "circuit": 1.0}[tier]
	var finishes := int(f.record.get("ko_wins", 0)) + int(f.record.get("sub_wins", 0))
	var streak := maxi(0, int(f.history.get("streak", 0)))
	var tenure := int(f.history.get("flagship_bouts", 0))
	var home: float = (exposure + finishes * 1.1 + streak * 2.0 + tenure * 1.3) * (0.55 + f.charisma / 100.0) + rng.normal(0.0, 4.0)
	var region := region_of(f.country)
	f.popularity_by_region = {region: clampi(roundi(home), 1, 95)}
	if tier == "flagship":
		for r: Dictionary in regions():
			if r.id != region:
				f.popularity_by_region[r.id] = clampi(roundi(home * rng.range_f(0.08, 0.35)), 0, 80)
