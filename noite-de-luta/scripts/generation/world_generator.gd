class_name WorldGenerator
extends RefCounted
## Cria o mundo de uma carreira nova: as 12 categorias cheias (do campeão ao estreante), as
## equipes rivais espalhadas pelos países que formam lutadores, os prospectos sem equipe, os
## campeões e os primeiros rankings e eventos.

const DEFAULT_SEED := 2027
const TEAM_COLORS := [
	["#B3262E", "#F1F0EC"], ["#1D3557", "#F1F0EC"], ["#111111", "#D3A94A"], ["#0B6E4F", "#F1F0EC"],
	["#6A1B9A", "#F1F0EC"], ["#E07A1F", "#111111"], ["#2E5C9E", "#F2C14E"], ["#7A1C1C", "#D3A94A"],
	["#222831", "#00ADB5"], ["#F1F0EC", "#B3262E"], ["#3A5A40", "#DAD7CD"], ["#264653", "#E9C46A"],
	["#8D0801", "#111111"], ["#0F4C5C", "#E36414"], ["#1B263B", "#E0E1DD"], ["#5F0F40", "#FB8B24"],
]

## Quantas equipes rivais por país (o resto dos países divide as equipes internacionais).
const TEAMS_BY_NATION := {"USA": 6, "BRA": 6, "RUS": 4, "ENG": 2, "POL": 2, "MEX": 2, "CAN": 2, "AUS": 2, "JPN": 2,
	"CHN": 2, "KAZ": 1, "GEO": 1, "UKR": 1, "FRA": 1, "NED": 1, "SWE": 1, "GER": 1, "IRL": 1, "KOR": 1, "PER": 1,
	"ARG": 1, "ESP": 1, "ITA": 1, "CZE": 1, "THA": 1, "NGA": 1, "RSA": 1, "UZB": 1, "NZL": 1}


static func generate(seed_v: int) -> GameWorld:
	var w := GameWorld.new()
	w.seed = seed_v
	w.rng.seed = seed_v
	_make_teams(w)
	for d: Dictionary in DataDB.divisions():
		_fill_division(w, d)
	_assign_teams(w)
	Rankings.rebuild(w)
	_crown_champions(w)
	Rankings.rebuild(w)
	StaffMarket.refresh(w)
	Calendar.ensure_events(w)
	for _i in 2:
		Matchmaker.book_cpu(w)
	return w


static func _make_teams(w: GameWorld) -> void:
	var m: Dictionary = DataDB.mma()
	var words: Array = (m["team_words"] as Array).duplicate()
	RngUtil.shuffle(w.rng, words)
	var pats: Array = m["team_patterns"]
	var wi := 0
	var ci := 0
	for nat: String in TEAMS_BY_NATION:
		for _k in int(TEAMS_BY_NATION[nat]):
			var t := Team.new()
			t.id = w.new_id()
			t.nation = nat
			var cities: Array = DataDB.cities(nat)
			t.city = String((cities[w.rng.randi_range(0, mini(cities.size() - 1, 6))] as Array)[0]) if not cities.is_empty() else ""
			var word := String(words[wi % words.size()])
			wi += 1
			var pat := String(pats[w.rng.randi_range(0, pats.size() - 1)])
			t.name = pat.format({"w": word, "c": t.city if t.city != "" else word})
			t.short = short_of(t.name)
			var cc: Array = TEAM_COLORS[ci % TEAM_COLORS.size()]
			ci += 1
			t.color1 = Color(String(cc[0]))
			t.color2 = Color(String(cc[1]))
			t.reputation = clampf(w.rng.randfn(48.0, 14.0), 20.0, 88.0)
			t.balance = t.reputation * 20000.0
			w.teams[t.id] = t


## Sigla de até 3 letras a partir das palavras que importam do nome.
static func short_of(name: String) -> String:
	var skip := ["equipe", "clube", "mma", "fight", "club", "academy", "combat", "team", "lutas", "de", "da", "do"]
	var words: Array = []
	for p in name.split(" ", false):
		if not skip.has(p.to_lower()):
			words.append(p)
	if words.is_empty():
		words = Array(name.split(" ", false))
	var out := ""
	if words.size() == 1:
		out = String(words[0]).substr(0, 3)
	else:
		for p: String in words:
			out += p.substr(0, 1)
	return out.to_upper().substr(0, 3)


## Do campeão ao estreante: o nível cai com a posição (poucos de elite, muitos medianos).
static func _fill_division(w: GameWorld, d: Dictionary) -> void:
	var div := String(d["id"])
	var n := int(d["count"])
	for r in n:
		var q := (r + 0.5) / float(n)
		var lvl := 45.0 + 43.0 * pow(1.0 - q, 1.55) + w.rng.randfn(0.0, 2.2)
		var f := FighterGenerator.make(w, div, lvl)
		w.fighters[f.id] = f
	# Prospectos amadores (sem equipe): o primeiro mercado do jogador.
	var am := maxi(4, int(n * 0.14))
	for _i in am:
		var f := FighterGenerator.make(w, div, w.rng.randf_range(36.0, 54.0), 0, true)
		w.fighters[f.id] = f


## Cada lutador fica numa equipe do país dele quando há; senão numa equipe forte de fora ou
## fica sem equipe (mercado). Os melhores tendem às equipes de mais reputação.
static func _assign_teams(w: GameWorld) -> void:
	var by_nation := {}
	var all_teams: Array = w.teams.values()
	all_teams.sort_custom(func(a: Team, b: Team) -> bool: return a.reputation > b.reputation)
	for t: Team in all_teams:
		if not by_nation.has(t.nation):
			by_nation[t.nation] = []
		by_nation[t.nation].append(t)
	var top_teams: Array = all_teams.slice(0, 10)
	for f: Fighter in w.fighters.values():
		if not f.is_pro():
			continue # amadores começam sem equipe
		var r := w.rng.randf()
		if r < 0.1:
			continue # sem equipe: está no mercado
		var pool: Array = by_nation.get(f.nation, [])
		var t: Team
		if not pool.is_empty() and r < 0.82:
			# Os melhores do país nas equipes de mais reputação.
			var idx := 0 if f.level() >= 72 else w.rng.randi_range(0, pool.size() - 1)
			t = pool[mini(idx, pool.size() - 1)]
		else:
			t = top_teams[w.rng.randi_range(0, top_teams.size() - 1)]
		f.team_id = t.id
		f.contract = {"cut": 0.2, "fights": w.rng.randi_range(2, 6)}


static func _crown_champions(w: GameWorld) -> void:
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var lst: Array = w.rankings.get(div, [])
		if lst.is_empty():
			w.champions[div] = -1
			continue
		var champ: Fighter = w.fighter(int(lst[0]))
		w.champions[div] = champ.id
		champ.titles_won = maxi(1, champ.titles_won)
		champ.title_defenses = w.rng.randi_range(0, 3)
		champ.popularity = clampf(champ.popularity + 20.0, 0.0, 100.0)
		if champ.team_id < 0:
			var teams: Array = w.teams.values()
			champ.team_id = (teams[w.rng.randi_range(0, teams.size() - 1)] as Team).id
			champ.contract = {"cut": 0.2, "fights": 4}
