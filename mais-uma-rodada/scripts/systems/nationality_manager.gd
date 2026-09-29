class_name NationalityManager
extends RefCounted
## Fictional careers: citizenship, birthplace, residence and sporting allegiance.
## FIFA senior eligibility is separate from the simplified citizenship process.
## No inference from a player's name, face, skin or ethnicity.

const VERSION := 1
const UK := ["ENG", "SCO", "WAL", "NIR"]
const SPANISH_TWO := ["BRA", "ARG", "URU", "PAR", "CHI", "BOL", "PER", "ECU", "COL", "VEN", "MEX", "CRC", "PAN", "SLV", "HON", "NCA", "GUA", "CUB", "DOM", "PUR", "POR", "AND", "PHI", "EQG"]
## Career balancing defaults, not a legal nationality-law database. Gulf naturalisation is
## discretionary and UK sporting eligibility has a special home-association agreement.
const YEARS := {"BRA":4, "ESP":10, "ITA":10, "SUI":10, "AUT":10, "DEN":9, "NOR":8, "ARG":2, "URU":5, "PAR":3, "PER":2}
const DISCRETIONARY := ["KSA", "QAT", "UAE", "BHR", "KUW", "OMA"]
## Explicit fictional family routes: these describe generated biography, not population statistics.
const FAMILY := {
	"CMR":["FRA","BEL"], "SEN":["FRA"], "CIV":["FRA"], "MLI":["FRA"], "ALG":["FRA"],
	"MAR":["FRA","BEL","NED","ESP"], "COD":["BEL","FRA"], "NGA":["ENG"], "GHA":["ENG","GER"],
	"ANG":["POR"], "CPV":["POR"], "GNB":["POR"], "MOZ":["POR"], "JAM":["ENG","CAN"],
	"TUR":["GER","NED"], "ALB":["SUI","ITA"], "BIH":["GER","AUT"], "SRB":["AUT","SUI"],
	"BRA":["POR","ITA"], "ARG":["ITA","ESP"], "MEX":["USA"], "USA":["MEX"], "AUS":["ENG","NZL"],
	"FRA":["ALG","MAR","SEN","CMR"], "GER":["TUR","POL"], "POR":["BRA","ANG","CPV"],
	"BEL":["MAR","COD"], "NED":["MAR"], "SUI":["ALB","ITA"], "ENG":["NGA","JAM","IRL"]
}
static var _cities: Dictionary = {}

static func cities_of(nation: String) -> Array:
	var out: Array = []
	for city in DatabaseManager.nation(nation).get("cities", []): out.append(String(city[0]))
	return out

static func city_in(city: String, nation: String) -> bool:
	if _cities.is_empty():
		for code in DatabaseManager.nations():
			for town in cities_of(code):
				var key: String = town.to_lower()
				if not _cities.has(key): _cities[key] = []
				_cities[key].append(code)
	return Array(_cities.get(city.to_lower(), [])).has(nation)

static func team(p: Player) -> String:
	return String(p.origin.get("team", p.nationality))

static func birth_country(p: Player) -> String:
	return String(p.origin.get("birth", p.nationality))

static func passports(p: Player) -> Array:
	var out: Array = p.origin.get("passports", {}).keys()
	if p.nationality != "" and not out.has(p.nationality): out.push_front(p.nationality)
	return out

static func generate(p: Player) -> void:
	# Separate RNG: changing biographical variety does not re-roll ability or appearance.
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(p.face_seed, p.id, 62926)
	p.origin = {"v":VERSION, "birth":p.nationality, "team":p.nationality,
		"passports":{p.nationality:{"since":p.birth_year,"basis":"birth","eligible":true}},
		"parents":[p.nationality], "residence":{}, "records":{}, "events":[], "switched":false}
	var routes: Array = FAMILY.get(p.nationality, [])
	if not routes.is_empty() and rng.randf() < 0.10:
		var other := String(routes[rng.randi_range(0, routes.size()-1)])
		p.origin["parents"].append(other)
		p.origin["passports"][other] = {"since":p.birth_year,"basis":"parent","eligible":true}
		if rng.randf() < 0.55 and not cities_of(other).is_empty():
			p.origin["birth"] = other
			p.hometown = PlayerGenerator.pick_hometown(rng, other, "")

static func ensure(w: GameWorld, p: Player) -> void:
	if not p.origin.is_empty(): return
	# Old saves have no family/second-nationality evidence. Repair only known foreign cities;
	# preserve user-entered towns and do not invent a passport to explain a generation bug.
	city_in(p.hometown, p.nationality)
	if _cities.has(p.hometown.to_lower()) and not city_in(p.hometown, p.nationality):
		var rng := RandomNumberGenerator.new()
		rng.seed = RngUtil.hash_i(w.world_seed, p.id, 62927)
		p.hometown = PlayerGenerator.pick_hometown(rng, p.nationality, "")
	p.origin = {"v":VERSION,"birth":p.nationality,"team":p.nationality,
		"passports":{p.nationality:{"since":p.birth_year,"basis":"birth","eligible":true}},
		"parents":[p.nationality],"residence":{},"records":{},"events":[],"switched":false}
	_import_caps(w, p)
	sync_residence(w, p)

static func _import_caps(w: GameWorld, p: Player) -> void:
	if not p.origin.get("records", {}).is_empty(): return
	var caps := NationalTeamManager.caps_of(w, p.id)
	if caps[0] > 0:
		p.origin["records"][team(p)] = {"apps":caps[0],"goals":caps[1],"assists":caps[2],"legacy":true}

static func ensure_world(w: GameWorld) -> void:
	for p: Player in w.players.values():
		ensure(w, p)
		_import_caps(w, p)
	for p: Player in w.academy.values(): ensure(w, p)
	w.stats["nationalities"] = VERSION

static func sync_residence(w: GameWorld, p: Player, moving: bool = false) -> void:
	if p.origin.is_empty(): ensure(w, p)
	var c := w.club(p.club_id)
	var r: Dictionary = p.origin.get("residence", {})
	if c == null:
		# Unemployment alone is not evidence of emigration, but do not accrue unknown residence.
		if not r.is_empty(): r["paused"] = true
		return
	if String(r.get("nation", "")) != c.nation or bool(r.get("paused", false)):
		var since := w.year
		if r.is_empty() and not moving:
			since = clampi(p.joined_year, p.birth_year, w.year) if p.joined_year > 0 else w.year
			# Adjacent documented spells in the same country keep the residence clock.
			for i in range(p.spells.size()-1, -1, -1):
				var sp: Dictionary = p.spells[i]
				var cl := w.club(int(sp.get("c", -1)))
				if cl == null or cl.nation != c.nation or int(sp.get("to", w.year)) > 0 and int(sp.get("to", 0)) < since: break
				since = mini(since, int(sp.get("from", since)))
		p.origin["residence"] = {"nation":c.nation,"since":since,"paused":false}

static func years_required(p: Player, nation: String) -> int:
	if DISCRETIONARY.has(nation) or UK.has(nation): return -1
	if nation == "ESP" and SPANISH_TWO.has(p.nationality): return 2
	if nation == "ITA" and SquadRules.EU.has(p.nationality): return 4
	return int(YEARS.get(nation, 5))

static func progress(w: GameWorld, p: Player) -> Dictionary:
	ensure(w, p)
	sync_residence(w, p)
	var r: Dictionary = p.origin.get("residence", {})
	var nation := String(r.get("nation", ""))
	var required := years_required(p, nation)
	var elapsed := maxi(0, w.year - int(r.get("since", w.year)))
	return {"nation":nation,"years":elapsed,"required":required,"paused":bool(r.get("paused", false)),
		"ready":nation != "" and not passports(p).has(nation) and required > 0 and elapsed >= required and not bool(r.get("paused", false)) and p.age(w.year) >= 18}

static func naturalize(w: GameWorld, p: Player, announce: bool = true) -> bool:
	var status := progress(w, p)
	if not bool(status["ready"]): return false
	var nation := String(status["nation"])
	# Acquisition and permission to represent a team are distinct: a Brazilian may receive
	# Spanish citizenship after two years, but still lack the five-year sporting link.
	p.origin["passports"][nation] = {"since":w.year,"basis":"residence","eligible":int(status["years"]) >= 5}
	p.origin["events"].append({"y":w.year,"kind":"citizenship","nation":nation})
	if announce and w.is_user_club(p.club_id):
		NewsManager.post_raw(w, "%s obtém nova nacionalidade" % p.display_name(),
			"%s recebeu a nacionalidade de %s após %d temporadas de residência. Sua seleção continua sendo %s." % [p.display_name(),DatabaseManager.nation_name(nation),status["years"],DatabaseManager.nation_name(team(p))], p.club_id, p.id)
	return true

static func eligible(w: GameWorld, p: Player, nation: String) -> bool:
	if nation == team(p): return true
	var pass_info: Dictionary = p.origin.get("passports", {}).get(nation, {})
	if pass_info.is_empty(): return false
	if not bool(pass_info.get("eligible", false)): return false
	var rec: Dictionary = p.origin.get("records", {}).get(team(p), {})
	if bool(rec.get("legacy", false)): return false # no invented first/last-match dates
	if bool(p.origin.get("switched", false)): return false
	if int(rec.get("official", 0)) == 0: return true # friendlies do not bind an association
	return int(rec.get("apps", 0)) <= 3 and int(rec.get("last_official_age", 99)) < 21 \
		and w.year - int(rec.get("last_year", w.year)) >= 3 and not bool(rec.get("finals", false)) \
		and int(pass_info.get("since", 9999)) <= int(rec.get("first_official", 0))

static func choose(w: GameWorld, p: Player, nation: String) -> bool:
	ensure(w, p)
	if nation == team(p) or not eligible(w, p, nation): return false
	var old := team(p)
	var rec: Dictionary = p.origin.get("records", {}).get(old, {})
	if int(rec.get("official", 0)) > 0: p.origin["switched"] = true
	p.origin["team"] = nation
	p.origin["events"].append({"y":w.year,"kind":"selection","nation":nation,"from":old})
	# A player cannot remain in two published lists after a change of allegiance.
	var intl := NationalTeamManager.data(w)
	for key in ["squads", "next"]:
		for ids: Array in intl.get(key, {}).values(): ids.erase(p.id)
	if w.is_user_club(p.club_id):
		NewsManager.post_raw(w, "%s escolhe sua seleção" % p.display_name(),
			"%s passa a representar %s. O local de nascimento e as cidadanias permanecem no seu histórico." % [p.display_name(),DatabaseManager.nation_name(nation)], p.club_id, p.id)
	return true

static func record_match(w: GameWorld, p: Player, nation: String, official: bool, finals: bool) -> void:
	ensure(w, p)
	var rec: Dictionary = p.origin["records"].get(nation, {"apps":0,"goals":0,"assists":0,"official":0})
	rec["apps"] = int(rec.get("apps", 0)) + 1
	rec["last_year"] = w.year
	if official:
		if not rec.has("first_official"): rec["first_official"] = w.year
		rec["official"] = int(rec.get("official", 0)) + 1
		rec["last_official_age"] = p.age(w.year)
	if finals: rec["finals"] = true
	p.origin["records"][nation] = rec

static func season_start(w: GameWorld) -> void:
	ensure_world(w)
	for p: Player in w.players.values():
		sync_residence(w, p)
		var r: Dictionary = p.origin.get("residence", {})
		var nation := String(r.get("nation", ""))
		var pp: Dictionary = p.origin["passports"].get(nation, {})
		if not pp.is_empty() and String(pp.get("basis", "")) == "residence" and not bool(r.get("paused", false)) and w.year-int(r.get("since", w.year)) >= 5:
			pp["eligible"] = true
		naturalize(w, p)
		# Fictional personal decision, weighted by a credible chance of playing; never a face edit.
		if p.age(w.year) < 21 or p.id % 3 != 0: continue
		var current := team(p)
		if p.ovr_f >= NationalTeamManager._filler(current) - 3.0: continue
		for code in passports(p):
			if code != current and eligible(w, p, code) and p.ovr_f >= NationalTeamManager._filler(code) - 1.0:
				choose(w, p, code)
				break

static func birthplace(p: Player) -> String:
	var country := DatabaseManager.nation_name(birth_country(p))
	return "%s, %s" % [p.hometown, country] if p.hometown != "" and p.hometown != country else country

static func names(p: Player) -> String:
	return " · ".join(passports(p).map(func(code): return DatabaseManager.nation_name(code)))
