class_name ClubPolicy
extends RefCounted
## Filosofias reais de contratação e formação (data/gameplay/club_policies.json): quem o clube aceita
## (Athletic só bascos, Chivas só mexicanos), de onde prefere, idade de quem compra e força da base.

const REGION_NATION := {"EUS": "ESP"}


static func of(club: Club) -> Dictionary:
	if club == null:
		return {}
	var d: Variant = DatabaseManager.get_data("club_policies")
	if not (d is Dictionary):
		return {}
	return d.get("clubs", {}).get(club.key, {})


static func has_rule(club: Club) -> bool:
	return of(club).has("only")


## O jogador cumpre a condição `rule` ("region:EUS", "nation:MEX")? Formado no clube também vale.
static func matches(world: GameWorld, club: Club, p: Player, rule: String) -> bool:
	if rule == "":
		return true
	var parts := rule.split(":")
	var kind := parts[0]
	var val := parts[1] if parts.size() > 1 else ""
	match kind:
		"nation":
			return p.nationality == val
		"region":
			if p.nationality == String(REGION_NATION.get(val, p.nationality)) and ClubGenerator.region_of_city(p.nationality, p.hometown) == val:
				return true
			return formed_at(p, club)
	return true


## Formado na base do clube: a primeira passagem da carreira foi lá, antes dos 20 anos.
static func formed_at(p: Player, club: Club) -> bool:
	if club == null or p.spells.is_empty():
		return false
	var first: Dictionary = p.spells[0]
	return int(first.get("c", -1)) == club.id and int(first.get("from", 9999)) - p.birth_year <= 19


## Pode jogar no clube (regra dura)?
static func eligible(world: GameWorld, club: Club, p: Player) -> bool:
	var pol := of(club)
	if not pol.has("only"):
		return true
	return matches(world, club, p, String(pol["only"]))


## Pode ser comprado pela IA do clube (regra dura + idade típica das contratações).
static func ai_wants(world: GameWorld, club: Club, p: Player) -> bool:
	var pol := of(club)
	if pol.is_empty():
		return true
	if not eligible(world, club, p):
		return false
	var age := p.age(world.year)
	if pol.has("buy_age_max") and age > int(pol["buy_age_max"]):
		return false
	if pol.has("buy_age_min") and age < int(pol["buy_age_min"]) and p.overall < PlayerGenerator.club_level(club) + 4.0:
		return false # jovem só se for craque
	return true


## Bônus de interesse (mercado): quem cumpre a preferência vale mais para o clube.
static func preference_bonus(world: GameWorld, club: Club, p: Player) -> float:
	var pol := of(club)
	if pol.has("prefer") and matches(world, club, p, String(pol["prefer"])):
		return 4.0
	return 0.0


## Regra usada na geração: "only" ou, com chance, "prefer".
static func generation_rule(rng: RandomNumberGenerator, club: Club) -> String:
	var pol := of(club)
	if pol.has("only"):
		return String(pol["only"])
	if pol.has("prefer") and rng.randf() < 0.6:
		return String(pol["prefer"])
	return ""


## Nacionalidade de quem segue a regra.
static func rule_nation(rule: String) -> String:
	var parts := rule.split(":")
	if parts[0] == "nation":
		return parts[1]
	if parts[0] == "region":
		return String(REGION_NATION.get(parts[1], ""))
	return ""


## Cidades da região (para a cidade natal de quem segue "region:").
static func region_cities(nation: String, region: String) -> Array:
	var out: Array = []
	for cd in DatabaseManager.nation(nation).get("cities", []):
		if cd.size() > 2 and String(cd[2]) == region:
			out.append(String(cd[0]))
	return out


## Faz um jogador recém-gerado seguir a regra: nacionalidade, cidade natal e nome da região.
static func apply_rule(world: GameWorld, rng: RandomNumberGenerator, club: Club, p: Player, rule: String, used: Dictionary) -> void:
	if rule == "" or matches(world, club, p, rule):
		return
	var nation := rule_nation(rule)
	if nation == "":
		return
	var parts := rule.split(":")
	p.nationality = nation
	var origin := NameGenerator.pick_origin(rng, nation)
	p.eth = int(origin["eth"])
	var culture := String(origin["c"])
	if parts[0] == "region":
		var cities := region_cities(nation, parts[1])
		if not cities.is_empty():
			p.hometown = String(RngUtil.pick(rng, cities))
		culture = String(of(club).get("culture", culture))
	else:
		p.hometown = PlayerGenerator.pick_hometown(rng, nation, club.city)
	var names := NameGenerator.generate(rng, culture, {"pos": p.position, "height": p.height, "foot": p.foot, "attrs": p.attrs,
		"region": ClubGenerator.region_of_city(nation, p.hometown)}, used)
	p.first_name = names["first"]
	p.last_name = names["last"]
	p.nickname = names["nickname"]
	p.known_as = names["known_as"]


static func youth_bonus(club: Club) -> int:
	return int(of(club).get("youth", 0))


static func homegrown_share(club: Club) -> float:
	return float(of(club).get("homegrown", 0.0))


## Texto curto para a página do clube.
static func label(club: Club) -> String:
	var pol := of(club)
	if pol.is_empty():
		return ""
	return String(pol.get("name", ""))
