class_name NationalTeamManager
extends RefCounted
## Futebol de seleções: convocações pelos melhores jogadores de cada nacionalidade, ranking de
## seleções (pontos no estilo Elo), eliminatórias disputadas nas datas FIFA da temporada e os
## torneios de verão (Copa do Mundo, Eurocopa, Copa América, Copa Africana, Copa da Ásia e Copa Ouro),
## jogados entre uma temporada e a outra.
##
## As seleções jogam num modelo próprio e leve (força do time titular → gols de Poisson), sem
## passar pelo motor de clubes. Tudo fica em world.stats["intl"]:
##   elo: {nação: pontos}, pl: {id do jogador: [jogos, gols]}, squads: {nação: [ids]},
##   camps: eliminatórias em andamento, tours: torneios já disputados (mais recente no fim),
##   fifa: datas FIFA já disputadas na temporada.

const KEY := "intl"
const SQUAD_SIZE := 26
const SQUAD_SHAPE := [3, 9, 8, 6] # goleiros, defensores, meias, atacantes
const XI_SHAPE := [1, 4, 3, 3]
const HOME_BONUS := 2.5 # pontos de força para o mandante (sede do torneio ou jogo em casa)
const BASE_GOALS := 1.22
const GOAL_SLOPE := 0.07
const ELO_START := 1500.0
const ROUND_NAMES := {32: "16 avos de final", 16: "Oitavas de final", 8: "Quartas de final", 4: "Semifinal", 2: "Final"}
const CONFED_NAMES := {"UEFA": "Europa", "CONMEBOL": "América do Sul", "CONCACAF": "Américas do Norte e Central",
	"CAF": "África", "AFC": "Ásia", "OFC": "Oceania"}


# ---------------------------------------------------------------------------
# Estado e consultas
# ---------------------------------------------------------------------------

static func data(world: GameWorld) -> Dictionary:
	if not world.stats.has(KEY):
		world.stats[KEY] = {"elo": {}, "pl": {}, "squads": {}, "camps": [], "tours": [], "fifa": 0}
	return world.stats[KEY]


static func cfg() -> Dictionary:
	return DatabaseManager.international_cfg()


static func tournament_ids() -> Array:
	return cfg().get("tournaments", {}).keys()


static func tcfg(id: String) -> Dictionary:
	return DatabaseManager.tournament_cfg(id)


static func tournament_name(id: String) -> String:
	return String(tcfg(id).get("name", id))


static func nations_of(confed: String) -> Array:
	var out: Array = []
	var all: Dictionary = DatabaseManager.nations()
	for code in all:
		if String(all[code].get("confed", "")) == confed:
			out.append(code)
	return out


## Ano da próxima edição de um torneio a partir de `year` (inclusive).
static func next_edition(id: String, year: int) -> int:
	var c := tcfg(id)
	var first := int(c.get("first", 2030))
	var every := maxi(1, int(c.get("every", 4)))
	if year <= first:
		return first
	return first + int(ceil(float(year - first) / every)) * every


static func host_of(id: String, year: int) -> String:
	var c := tcfg(id)
	var hosts: Array = c.get("hosts", [])
	if hosts.is_empty():
		return ""
	var idx := (year - int(c.get("first", year))) / maxi(1, int(c.get("every", 4)))
	return String(hosts[posmod(idx, hosts.size())])


## Jogos e gols de um jogador pela seleção.
static func caps_of(world: GameWorld, pid: int) -> Array:
	var pl: Dictionary = data(world)["pl"]
	var v: Variant = pl.get(pid, null)
	if v == null:
		v = pl.get(str(pid), null)
	return [int(v[0]), int(v[1])] if v != null else [0, 0]


static func elo_of(world: GameWorld, code: String) -> float:
	var elo: Dictionary = data(world)["elo"]
	if not elo.has(code):
		elo[code] = _initial_elo(world, code)
	return float(elo[code])


## Ranking de seleções: [[nação, pontos]] do melhor para o pior.
static func ranking(world: GameWorld) -> Array:
	var out: Array = []
	for code in DatabaseManager.nations():
		out.append([code, elo_of(world, code)])
	out.sort_custom(func(a, b): return float(a[1]) > float(b[1]) or (float(a[1]) == float(b[1]) and String(a[0]) < String(b[0])))
	return out


static func rank_of(world: GameWorld, code: String) -> int:
	var r := ranking(world)
	for i in r.size():
		if r[i][0] == code:
			return i + 1
	return 0


## Seleções em que o jogador está convocado (a última lista da nação dele).
static func is_called(world: GameWorld, p: Player) -> bool:
	var sq: Variant = data(world)["squads"].get(p.nationality, [])
	return (sq as Array).has(p.id)


# ---------------------------------------------------------------------------
# Convocação e força
# ---------------------------------------------------------------------------

## Jogadores disponíveis por nacionalidade (um passe só pelo mundo).
static func _pool(world: GameWorld) -> Dictionary:
	var out := {}
	for p: Player in world.players.values():
		if p.club_id < 0 or p.injury_weeks > 0 or p.retiring:
			continue
		if not out.has(p.nationality):
			out[p.nationality] = []
		out[p.nationality].append(p)
	return out


## Convoca os melhores por setor (3 goleiros, 9 defensores, 8 meias, 6 atacantes; completa com quem sobrar).
static func call_up(pool: Array) -> Array:
	var by_group: Array = [[], [], [], []]
	for p: Player in pool:
		by_group[Pos.group(p.position)].append(p)
	for g in by_group:
		g.sort_custom(func(a, b): return a.ovr_f > b.ovr_f or (a.ovr_f == b.ovr_f and a.id < b.id))
	var out: Array = []
	var rest: Array = []
	for gi in 4:
		out.append_array(by_group[gi].slice(0, SQUAD_SHAPE[gi]))
		rest.append_array(by_group[gi].slice(SQUAD_SHAPE[gi]))
	rest.sort_custom(func(a, b): return a.ovr_f > b.ovr_f or (a.ovr_f == b.ovr_f and a.id < b.id))
	for p in rest:
		if out.size() >= SQUAD_SIZE:
			break
		if Pos.group(p.position) != Pos.G_GK:
			out.append(p)
	return out


## Time titular (1-4-3-3) de uma lista de convocados.
static func starting_xi(squad: Array) -> Array:
	var by_group: Array = [[], [], [], []]
	for p: Player in squad:
		by_group[Pos.group(p.position)].append(p)
	var xi: Array = []
	var spare: Array = []
	for gi in 4:
		by_group[gi].sort_custom(func(a, b): return a.ovr_f > b.ovr_f or (a.ovr_f == b.ovr_f and a.id < b.id))
		xi.append_array(by_group[gi].slice(0, XI_SHAPE[gi]))
		if gi != Pos.G_GK:
			spare.append_array(by_group[gi].slice(XI_SHAPE[gi]))
	spare.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	while xi.size() < 11 and not spare.is_empty():
		xi.append(spare.pop_front())
	return xi


## Nível de reposição para vagas sem jogador convocável (seleções pequenas no mundo do jogo).
static func _filler(code: String) -> float:
	return 32.0 + float(DatabaseManager.nation(code).get("coef", 30)) * 0.22


## Força da seleção: média do time titular (vagas vazias contam como reposição, com penalidade).
static func strength_of(code: String, squad: Array) -> float:
	var xi := starting_xi(squad)
	var total := 0.0
	for p: Player in xi:
		total += p.ovr_f
	total += (11 - xi.size()) * _filler(code)
	return total / 11.0


static func _initial_elo(world: GameWorld, code: String) -> float:
	var pool: Array = []
	for p: Player in world.players.values():
		if p.nationality == code and p.club_id >= 0:
			pool.append(p)
	return ELO_START + (strength_of(code, call_up(pool)) - 62.0) * 22.0


static func _ensure_elo(world: GameWorld, pool: Dictionary) -> void:
	var elo: Dictionary = data(world)["elo"]
	for code in DatabaseManager.nations():
		if not elo.has(code):
			elo[code] = ELO_START + (strength_of(code, call_up(pool.get(code, []))) - 62.0) * 22.0


# ---------------------------------------------------------------------------
# Partida entre seleções
# ---------------------------------------------------------------------------

## Ambiente de uma rodada de jogos: convocações, forças e o RNG próprio (não mexe no RNG do mundo).
class Env:
	var world: GameWorld
	var rng := RandomNumberGenerator.new()
	var squads := {} # nação -> [Player]
	var strength := {} # nação -> float
	var host := ""
	var k := 30.0 # peso do jogo no ranking
	var called := {} # id -> true (quem entrou em campo nesta data ou torneio)
	var goals := {} # id -> gols nesta data ou torneio

	func squad(code: String) -> Array:
		return squads.get(code, [])


static func _make_env(world: GameWorld, seed_key: int, k: float) -> Env:
	var env := Env.new()
	env.world = world
	env.rng.seed = RngUtil.hash_i(world.world_seed, world.year * 131 + seed_key, 7719)
	env.k = k
	var pool := _pool(world)
	_ensure_elo(world, pool)
	var squads_d: Dictionary = data(world)["squads"]
	for code in DatabaseManager.nations():
		var sq := call_up(pool.get(code, []))
		env.squads[code] = sq
		env.strength[code] = strength_of(code, sq)
		squads_d[code] = sq.map(func(p: Player): return p.id)
	return env


static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l or k > 12:
			break
		k += 1
	return k


static func _lambda(env: Env, a: String, b: String, a_home: bool, b_home: bool) -> float:
	var diff: float = float(env.strength[a]) - float(env.strength[b])
	if a_home:
		diff += HOME_BONUS
	if b_home:
		diff -= HOME_BONUS
	return clampf(BASE_GOALS * exp(GOAL_SLOPE * diff), 0.15, 4.5)


## Joga uma partida. home_adv: o mandante `a` joga em casa (eliminatórias) — em torneio só a sede tem.
## ko: empate vai para prorrogação e pênaltis. Retorna {a, b, ga, gb, et, pa, pb, w, sc: [[pid, nação]]}.
static func play(env: Env, a: String, b: String, home_adv: bool, ko: bool) -> Dictionary:
	var a_home := home_adv or a == env.host
	var b_home := (not home_adv) and b == env.host
	var la := _lambda(env, a, b, a_home, b_home)
	var lb := _lambda(env, b, a, b_home, a_home)
	var ga := _poisson(env.rng, la)
	var gb := _poisson(env.rng, lb)
	var res := {"a": a, "b": b, "ga": ga, "gb": gb, "et": false, "pa": -1, "pb": -1, "w": "", "sc": []}
	if ko and ga == gb:
		res["et"] = true
		ga += _poisson(env.rng, la / 3.0)
		gb += _poisson(env.rng, lb / 3.0)
		res["ga"] = ga
		res["gb"] = gb
		if ga == gb:
			var pens := _shootout(env)
			res["pa"] = pens[0]
			res["pb"] = pens[1]
	if int(res["ga"]) != int(res["gb"]):
		res["w"] = a if int(res["ga"]) > int(res["gb"]) else b
	elif int(res["pa"]) >= 0:
		res["w"] = a if int(res["pa"]) > int(res["pb"]) else b
	_credit_players(env, a, int(res["ga"]), res)
	_credit_players(env, b, int(res["gb"]), res)
	_update_elo(env, a, b, int(res["ga"]), int(res["gb"]), a_home, b_home, String(res["w"]))
	return res


static func _shootout(env: Env) -> Array:
	var pa := 0
	var pb := 0
	for i in 5:
		pa += 1 if env.rng.randf() < 0.76 else 0
		pb += 1 if env.rng.randf() < 0.76 else 0
	while pa == pb:
		var x := 1 if env.rng.randf() < 0.72 else 0
		var y := 1 if env.rng.randf() < 0.72 else 0
		pa += x
		pb += y
	return [pa, pb]


## Jogos e gols para quem entrou em campo (titulares e três reservas).
static func _credit_players(env: Env, code: String, goals: int, res: Dictionary) -> void:
	var sq := env.squad(code)
	if sq.is_empty():
		return
	var xi := starting_xi(sq)
	var bench: Array = sq.filter(func(p): return not xi.has(p) and Pos.group(p.position) != Pos.G_GK)
	var used: Array = xi.duplicate()
	for i in mini(3, bench.size()):
		used.append(bench[env.rng.randi_range(0, bench.size() - 1)])
	var pl: Dictionary = data(env.world)["pl"]
	var seen := {}
	for p: Player in used:
		if seen.has(p.id):
			continue
		seen[p.id] = true
		var v: Array = pl.get(p.id, [0, 0])
		pl[p.id] = [int(v[0]) + 1, int(v[1])]
		env.called[p.id] = true
	var weights: Array = []
	for p: Player in xi:
		var gw: float = [0.0, 0.45, 1.4, 4.0][Pos.group(p.position)]
		weights.append(gw * (p.attr(Attr.FIN) + 25.0) / 75.0)
	for g in goals:
		if xi.is_empty():
			break
		var idx := RngUtil.weighted_index(env.rng, weights)
		if idx < 0:
			continue
		var s: Player = xi[idx]
		var v: Array = pl[s.id]
		pl[s.id] = [int(v[0]), int(v[1]) + 1]
		env.goals[s.id] = int(env.goals.get(s.id, 0)) + 1
		res["sc"].append([s.id, code])


static func _update_elo(env: Env, a: String, b: String, ga: int, gb: int, a_home: bool, b_home: bool, winner: String) -> void:
	var elo: Dictionary = data(env.world)["elo"]
	var ea := float(elo.get(a, ELO_START)) + (60.0 if a_home else 0.0)
	var eb := float(elo.get(b, ELO_START)) + (60.0 if b_home else 0.0)
	var exp_a := 1.0 / (1.0 + pow(10.0, (eb - ea) / 400.0))
	var score := 0.5
	if ga != gb:
		score = 1.0 if ga > gb else 0.0
	elif winner != "":
		score = 0.6 if winner == a else 0.4
	var margin := absi(ga - gb)
	var mult := 1.0 if margin <= 1 else (1.5 if margin == 2 else (11.0 + margin) / 8.0)
	var delta := env.k * mult * (score - exp_a)
	elo[a] = float(elo.get(a, ELO_START)) + delta
	elo[b] = float(elo.get(b, ELO_START)) - delta


# ---------------------------------------------------------------------------
# Tabelas de grupo
# ---------------------------------------------------------------------------

static func _row() -> Dictionary:
	return {"pl": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0}


static func _apply(table: Dictionary, a: String, b: String, ga: int, gb: int) -> void:
	var rules := DatabaseManager.rules()
	var pw := int(rules["points_win"])
	var pd := int(rules["points_draw"])
	var ra: Dictionary = table[a]
	var rb: Dictionary = table[b]
	ra["pl"] += 1
	rb["pl"] += 1
	ra["gf"] += ga
	ra["ga"] += gb
	rb["gf"] += gb
	rb["ga"] += ga
	if ga > gb:
		ra["w"] += 1
		rb["l"] += 1
		ra["pts"] += pw
	elif gb > ga:
		rb["w"] += 1
		ra["l"] += 1
		rb["pts"] += pw
	else:
		ra["d"] += 1
		rb["d"] += 1
		ra["pts"] += pd
		rb["pts"] += pd


static func _better(ra: Dictionary, rb: Dictionary) -> bool:
	if int(ra["pts"]) != int(rb["pts"]):
		return int(ra["pts"]) > int(rb["pts"])
	var da := int(ra["gf"]) - int(ra["ga"])
	var db := int(rb["gf"]) - int(rb["ga"])
	if da != db:
		return da > db
	return int(ra["gf"]) > int(rb["gf"])


static func sort_group(g: Dictionary) -> Array:
	var ids: Array = Array(g["teams"]).duplicate()
	var table: Dictionary = g["table"]
	ids.sort_custom(func(a, b):
		if _better(table[a], table[b]):
			return true
		if _better(table[b], table[a]):
			return false
		return a < b)
	return ids


## Divide as seleções (já ordenadas por força) em `n` grupos por potes, para equilibrar.
static func _draw_groups(rng: RandomNumberGenerator, teams: Array, n: int) -> Array:
	var groups: Array = []
	for i in n:
		groups.append({"n": char(65 + i), "teams": [], "table": {}})
	var pots := int(ceil(float(teams.size()) / n))
	for pot in pots:
		var ids: Array = teams.slice(pot * n, (pot + 1) * n)
		RngUtil.shuffle(rng, ids)
		for i in ids.size():
			groups[i]["teams"].append(ids[i])
	for g in groups:
		for t in g["teams"]:
			g["table"][t] = _row()
	return groups


## Rodadas de pontos corridos (método do círculo) sobre índices; `turns` = 2 para ida e volta.
static func _rounds(size: int, turns: int) -> Array:
	var idx: Array = range(size)
	if size % 2 == 1:
		idx.append(-1)
	var n := idx.size()
	var first: Array = []
	for r in n - 1:
		var pairs: Array = []
		for i in n / 2:
			var a: int = idx[i]
			var b: int = idx[n - 1 - i]
			if a >= 0 and b >= 0:
				pairs.append([a, b] if (r + i) % 2 == 0 else [b, a])
		first.append(pairs)
		idx.insert(1, idx.pop_back())
	var out: Array = []
	for t in turns:
		for pairs in first:
			out.append(pairs if t % 2 == 0 else pairs.map(func(p): return [p[1], p[0]]))
	return out


# ---------------------------------------------------------------------------
# Eliminatórias
# ---------------------------------------------------------------------------

## Abre as eliminatórias que começam nesta temporada (chamado ao montar cada temporada).
static func start_season(world: GameWorld) -> void:
	var d := data(world)
	d["fifa"] = 0
	for id in tournament_ids():
		var c := tcfg(id)
		var q: Dictionary = c.get("qualifying", {})
		if q.is_empty():
			continue
		var y := next_edition(id, world.year + 1)
		var seasons := int(q.get("seasons", 1))
		# A temporada `world.year` termina no meio de `world.year + 1`: as eliminatórias ocupam as
		# `seasons` temporadas antes do torneio (a primeira do jogo pode pegar o ciclo andando).
		if world.year < y - seasons or world.year > y - 1:
			continue
		if _has_campaigns(d, id, y):
			continue
		_open_campaigns(world, id, y)


static func _has_campaigns(d: Dictionary, id: String, y: int) -> bool:
	for camp in d["camps"]:
		if String(camp["t"]) == id and int(camp["y"]) == y:
			return true
	return false


static func _open_campaigns(world: GameWorld, id: String, y: int) -> void:
	var c := tcfg(id)
	var q: Dictionary = c.get("qualifying", {})
	var host := host_of(id, y)
	var entry: Dictionary = c.get("entry", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(world.world_seed, y, id.hash())
	for confed in q:
		if confed == "seasons" or not entry.has(confed):
			continue
		var teams: Array = nations_of(confed).filter(func(n): return n != host)
		var spots := int(entry[confed]) - (1 if DatabaseManager.nation(host).get("confed", "") == confed else 0)
		if teams.size() <= spots:
			continue # todos passam direto
		teams.sort_custom(func(a, b): return elo_of(world, a) > elo_of(world, b) or (elo_of(world, a) == elo_of(world, b) and a < b))
		var n_groups := clampi(int(q[confed].get("groups", 1)), 1, maxi(1, teams.size() / 3))
		var camp := {"t": id, "y": y, "confed": confed, "name": "Eliminatórias %s · %s" % [String(c.get("short", id)), CONFED_NAMES.get(confed, confed)],
			"groups": _draw_groups(rng, teams, n_groups), "fx": [], "md": 0, "mdt": 0, "spots": spots, "done": false, "q": [],
			"end": y - 1}
		var mdt := 0
		for gi in camp["groups"].size():
			var g: Dictionary = camp["groups"][gi]
			var rounds := _rounds(g["teams"].size(), 2)
			for r in rounds.size():
				for pair in rounds[r]:
					camp["fx"].append([r, gi, g["teams"][pair[0]], g["teams"][pair[1]], -1, -1])
			mdt = maxi(mdt, rounds.size())
		camp["mdt"] = mdt
		data(world)["camps"].append(camp)


## Datas FIFA restantes (esta temporada incluída) até o fim da campanha.
static func _fifa_left(world: GameWorld, camp: Dictionary) -> int:
	var per := (cfg().get("fifa_dates", []) as Array).size()
	var this_season := maxi(0, per - int(data(world)["fifa"]))
	return this_season + per * maxi(0, int(camp["end"]) - world.year)


## Depois de cada fim de semana: se for data FIFA, joga as rodadas das eliminatórias.
## Retorna as notícias relevantes ao usuário (convocações e resultados da sua nação).
static func after_weekend(world: GameWorld, weekend_index: int) -> Array:
	var dates: Array = cfg().get("fifa_dates", []).map(func(x): return int(x))
	if not dates.has(weekend_index):
		return []
	var d := data(world)
	var active: Array = d["camps"].filter(func(c): return not bool(c["done"]))
	var env := _make_env(world, 1000 + weekend_index, 30.0)
	var lines: Array = []
	for camp in active:
		var left := _fifa_left(world, camp)
		var remaining := int(camp["mdt"]) - int(camp["md"])
		var n := remaining if left <= 1 else int(ceil(float(remaining) / left))
		for i in n:
			lines.append_array(_play_matchday(env, camp))
	d["fifa"] = int(d["fifa"]) + 1
	# Amistosos para quem não tem eliminatória (mantêm o ranking e os jogos dos convocados vivos).
	var busy := {}
	for camp in active:
		for g in camp["groups"]:
			for t in g["teams"]:
				busy[t] = true
	var free: Array = []
	for code in DatabaseManager.nations():
		if not busy.has(code):
			free.append(code)
	RngUtil.shuffle(env.rng, free)
	env.k = 12.0
	for i in range(0, free.size() - 1, 2):
		play(env, free[i], free[i + 1], true, false)
	_after_date(world, env, lines)
	return lines


static func _play_matchday(env: Env, camp: Dictionary) -> Array:
	var md := int(camp["md"])
	if md >= int(camp["mdt"]):
		return []
	var out: Array = []
	for f in camp["fx"]:
		if int(f[0]) != md or int(f[4]) >= 0:
			continue
		var r := play(env, String(f[2]), String(f[3]), true, false)
		f[4] = int(r["ga"])
		f[5] = int(r["gb"])
		_apply(camp["groups"][int(f[1])]["table"], String(f[2]), String(f[3]), int(r["ga"]), int(r["gb"]))
		out.append(r)
	camp["md"] = md + 1
	if int(camp["md"]) >= int(camp["mdt"]):
		_close_campaign(env.world, camp)
	return out


## Fim das eliminatórias: primeiros de cada grupo, depois segundos... e os melhores da faixa seguinte.
static func _close_campaign(world: GameWorld, camp: Dictionary) -> void:
	camp["done"] = true
	camp["q"] = _best_by_position(camp["groups"], int(camp["spots"]))
	var user_nat := _user_nation(world)
	if user_nat != "" and _in_campaign(camp, user_nat):
		var ok: bool = camp["q"].has(user_nat)
		NewsManager.post_raw(world, "%s %s para a %s %d" % [DatabaseManager.nation_name(user_nat), "se classifica" if ok else "fica fora", tournament_name(camp["t"]), int(camp["y"])],
			"Terminaram as %s. Classificados: %s." % [String(camp["name"]).to_lower(), _names(camp["q"])], -1, -1, NewsEvent.IMP_HIGH, "selecao")


static func _in_campaign(camp: Dictionary, code: String) -> bool:
	for g in camp["groups"]:
		if g["teams"].has(code):
			return true
	return false


## Os `n` melhores de um conjunto de grupos: todos os 1º, depois todos os 2º... (por pontos dentro da faixa).
static func _best_by_position(groups: Array, n: int) -> Array:
	var out: Array = []
	var orders: Array = groups.map(func(g): return sort_group(g))
	var pos := 0
	while out.size() < n:
		var tier: Array = []
		for gi in groups.size():
			if pos < orders[gi].size():
				tier.append([orders[gi][pos], groups[gi]["table"][orders[gi][pos]]])
		if tier.is_empty():
			break
		tier.sort_custom(func(a, b): return _better(a[1], b[1]) or (not _better(b[1], a[1]) and String(a[0]) < String(b[0])))
		for t in tier:
			if out.size() < n:
				out.append(t[0])
		pos += 1
	return out


static func _user_nation(world: GameWorld) -> String:
	return world.user_nation() if world.has_user() else ""


static func _names(codes: Array) -> String:
	return ", ".join(codes.map(func(c): return DatabaseManager.nation_name(String(c))))


## Efeitos de uma data FIFA: moral de quem foi convocado, lesões raras e notícias para o usuário.
static func _after_date(world: GameWorld, env: Env, results: Array) -> void:
	for pid in env.called:
		var p := world.player(int(pid))
		if p == null:
			continue
		p.morale = clampf(p.morale + 2.0, 0.0, 100.0)
		if env.rng.randf() < 0.012 * (0.6 + p.injury_prone / 20.0):
			p.injury_weeks = maxi(p.injury_weeks, env.rng.randi_range(1, 4))
			p.injury_name = InjuryTable.name_for(p.injury_weeks, p.id + world.year)
			if world.has_user() and p.club_id == world.user_club_id:
				NewsManager.post_raw(world, "%s volta machucado da seleção" % p.display_name(),
					"O jogador se lesionou a serviço da seleção (%s) e desfalca o time por %d semana(s)." % [DatabaseManager.nation_name(p.nationality), p.injury_weeks],
					world.user_club_id, p.id, NewsEvent.IMP_HIGH, "selecao")
	if not world.has_user():
		return
	# Convocados do clube do usuário
	var mine: Array = []
	for pid in env.called:
		var p := world.player(int(pid))
		if p != null and p.club_id == world.user_club_id:
			mine.append(p)
	if not mine.is_empty():
		mine.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
		var parts: Array = mine.map(func(p: Player): return "%s (%s)" % [p.display_name(), DatabaseManager.nation_name(p.nationality)])
		NewsManager.post_raw(world, "Data FIFA: %d convocado(s) do %s" % [mine.size(), world.user_club().short_name],
			"Defenderam suas seleções: %s." % ", ".join(parts), world.user_club_id, int(mine[0].id), NewsEvent.IMP_NORMAL, "selecao")
	# Resultados da seleção do país do usuário
	var nat := _user_nation(world)
	var mine_r: Array = results.filter(func(r): return r["a"] == nat or r["b"] == nat)
	if not mine_r.is_empty():
		var txt: Array = mine_r.map(func(r): return result_text(r))
		NewsManager.post_raw(world, "Eliminatórias: %s" % txt[0], "Resultados da %s na data FIFA: %s." % [DatabaseManager.nation_name(nat), "; ".join(txt)],
			-1, -1, NewsEvent.IMP_NORMAL, "selecao")


static func result_text(r: Dictionary) -> String:
	var s := "%s %d x %d %s" % [DatabaseManager.nation_name(r["a"]), int(r["ga"]), int(r["gb"]), DatabaseManager.nation_name(r["b"])]
	if int(r.get("pa", -1)) >= 0:
		s += " (pên. %d x %d)" % [int(r["pa"]), int(r["pb"])]
	elif bool(r.get("et", false)):
		s += " (prorr.)"
	return s


# ---------------------------------------------------------------------------
# Torneios
# ---------------------------------------------------------------------------

## Torneios de verão disputados entre a temporada `world.year` e a próxima. Chamado no fim de
## temporada, antes da virada do ano. Retorna os resumos (também guardados em data.tours).
static func play_summer(world: GameWorld) -> Array:
	var y := world.year + 1
	var out: Array = []
	var d := data(world)
	# Termina eliminatórias que ainda tenham rodadas (salvaguarda).
	var env_q := _make_env(world, 2000, 30.0)
	for camp in d["camps"]:
		if not bool(camp["done"]) and int(camp["y"]) <= y:
			while not bool(camp["done"]):
				_play_matchday(env_q, camp)
	var ids := tournament_ids()
	for id in ids:
		if next_edition(id, y) != y:
			continue
		var rec := _play_tournament(world, id, y)
		if not rec.is_empty():
			out.append(rec)
			d["tours"].append(rec)
	# Campanhas encerradas e já usadas saem da memória.
	d["camps"] = d["camps"].filter(func(c): return int(c["y"]) > y)
	if d["tours"].size() > 60:
		d["tours"] = d["tours"].slice(d["tours"].size() - 60)
	return out


## Participantes: sede, classificados pelas eliminatórias, vagas pelo ranking, convidados e repescagem.
static func participants(world: GameWorld, id: String, y: int, env: Env) -> Array:
	var c := tcfg(id)
	var host := host_of(id, y)
	var out: Array = []
	if host != "":
		out.append(host)
	var entry: Dictionary = c.get("entry", {})
	var camps: Array = data(world)["camps"].filter(func(k): return String(k["t"]) == id and int(k["y"]) == y)
	for confed in entry:
		var spots := int(entry[confed]) - (1 if DatabaseManager.nation(host).get("confed", "") == confed else 0)
		var from_camp: Array = []
		for k in camps:
			if String(k["confed"]) == confed:
				from_camp = k["q"]
		var picks: Array = from_camp.slice(0, spots) if not from_camp.is_empty() else _top_ranked(world, nations_of(confed), out, spots)
		for p in picks:
			if not out.has(p):
				out.append(p)
	var guests: Dictionary = c.get("guests", {})
	for confed in guests:
		for p in _top_ranked(world, nations_of(confed), out, int(guests[confed])):
			out.append(p)
	var po := int(c.get("playoff", 0))
	if po > 0:
		out.append_array(_playoff(world, env, out, po, id, y))
	var teams := int(c.get("teams", out.size()))
	if out.size() < teams:
		var all: Array = DatabaseManager.nations().keys()
		out.append_array(_top_ranked(world, all, out, teams - out.size()))
	return out.slice(0, teams)


static func _top_ranked(world: GameWorld, pool: Array, exclude: Array, n: int) -> Array:
	var cands: Array = pool.filter(func(x): return not exclude.has(x))
	cands.sort_custom(func(a, b): return elo_of(world, a) > elo_of(world, b) or (elo_of(world, a) == elo_of(world, b) and a < b))
	return cands.slice(0, maxi(0, n))


## Repescagem intercontinental: os 2n melhores do ranking fora da UEFA que não se classificaram,
## em jogo único (o melhor ranqueado em casa). Os vencedores ficam com as vagas.
static func _playoff(world: GameWorld, env: Env, qualified: Array, n: int, id: String, y: int) -> Array:
	var pool: Array = []
	for confed in CONFED_NAMES:
		if confed != "UEFA":
			pool.append_array(nations_of(confed))
	var cands := _top_ranked(world, pool, qualified, n * 2)
	var winners: Array = []
	var lines: Array = []
	for i in range(0, cands.size() - 1, 2):
		var r := play(env, cands[i], cands[cands.size() - 1 - i], true, true)
		winners.append(r["w"])
		lines.append(result_text(r))
		if winners.size() >= n:
			break
	if not lines.is_empty():
		NewsManager.post_raw(world, "Repescagem da %s %d" % [tournament_name(id), y], "Classificados na repescagem: %s. Jogos: %s." % [_names(winners), "; ".join(lines)],
			-1, -1, NewsEvent.IMP_NORMAL, "selecao")
	return winners


static func _play_tournament(world: GameWorld, id: String, y: int) -> Dictionary:
	var c := tcfg(id)
	var env := _make_env(world, 3000 + id.hash() % 997, 50.0)
	env.host = host_of(id, y)
	var teams := participants(world, id, y, env)
	var n_groups := int(c.get("groups", 4))
	if teams.size() < n_groups * 2:
		return {}
	var seeded: Array = teams.duplicate()
	seeded.sort_custom(func(a, b):
		if a == env.host:
			return b != env.host
		if b == env.host:
			return false
		return elo_of(world, a) > elo_of(world, b) or (elo_of(world, a) == elo_of(world, b) and a < b))
	var groups := _draw_groups(env.rng, seeded, n_groups)
	var matches: Array = [] # [fase, a, b, ga, gb, pa, pb, et]
	for gi in groups.size():
		var g: Dictionary = groups[gi]
		for rnd in _rounds(g["teams"].size(), 1):
			for pair in rnd:
				var a: String = g["teams"][pair[0]]
				var b: String = g["teams"][pair[1]]
				var r := play(env, a, b, false, false)
				_apply(g["table"], a, b, int(r["ga"]), int(r["gb"]))
				matches.append(["G" + String(g["n"]), a, b, int(r["ga"]), int(r["gb"]), -1, -1, false])
	# Mata-mata: os dois primeiros e os melhores terceiros até a potência de 2.
	var ko_size := 2
	while ko_size < n_groups * 2:
		ko_size *= 2
	var firsts: Array = []
	var seconds: Array = []
	var thirds: Array = []
	for g in groups:
		var order := sort_group(g)
		firsts.append([order[0], g["table"][order[0]], g["n"]])
		seconds.append([order[1], g["table"][order[1]], g["n"]])
		if order.size() > 2:
			thirds.append([order[2], g["table"][order[2]], g["n"]])
	var by_row := func(a, b): return _better(a[1], b[1]) or (not _better(b[1], a[1]) and String(a[0]) < String(b[0]))
	firsts.sort_custom(by_row)
	seconds.sort_custom(by_row)
	thirds.sort_custom(by_row)
	var seeds: Array = firsts + seconds + thirds.slice(0, ko_size - n_groups * 2)
	var bracket := _bracket(seeds.map(func(s): return s[0]), seeds.map(func(s): return s[2]))
	var ko_rounds: Array = []
	var alive: Array = bracket
	var runner_up := ""
	var semis: Array = []
	while alive.size() >= 2:
		var rname: String = ROUND_NAMES.get(alive.size(), "Mata-mata")
		var next: Array = []
		var round_res: Array = []
		for i in range(0, alive.size(), 2):
			var r := play(env, alive[i], alive[i + 1], false, true)
			next.append(r["w"])
			round_res.append([alive[i], alive[i + 1], int(r["ga"]), int(r["gb"]), int(r["pa"]), int(r["pb"]), bool(r["et"]), r["w"]])
			matches.append([rname, alive[i], alive[i + 1], int(r["ga"]), int(r["gb"]), int(r["pa"]), int(r["pb"]), bool(r["et"])])
			if alive.size() == 2:
				runner_up = alive[i] if r["w"] == alive[i + 1] else alive[i + 1]
			elif alive.size() == 4:
				semis.append(alive[i] if r["w"] == alive[i + 1] else alive[i + 1])
		ko_rounds.append({"n": rname, "m": round_res})
		alive = next
	var champion: String = alive[0]
	# Artilharia do torneio
	var scorer := {}
	var best_pid := -1
	var best_goals := 0
	for pid in env.goals:
		if int(env.goals[pid]) > best_goals or (int(env.goals[pid]) == best_goals and best_pid >= 0 and int(pid) < best_pid):
			best_goals = int(env.goals[pid])
			best_pid = int(pid)
	if best_pid >= 0:
		var sp := world.player(best_pid)
		if sp != null:
			scorer = {"id": sp.id, "name": sp.display_name(), "nation": sp.nationality, "goals": best_goals}
	var gs: Array = []
	for g in groups:
		gs.append({"n": g["n"], "order": sort_group(g), "table": g["table"]})
	var rec := {"t": id, "y": y, "name": tournament_name(id), "host": env.host, "teams": teams, "champion": champion, "runner_up": runner_up,
		"semis": semis, "scorer": scorer, "groups": gs, "ko": ko_rounds,
		"squad": env.squad(champion).map(func(p: Player): return p.id)}
	_tournament_effects(world, env, rec)
	return rec


## Chave do mata-mata: cabeças de chave em lados opostos; evita duelo de grupo na primeira fase.
static func _bracket(seeds: Array, group_of: Array) -> Array:
	var n := seeds.size()
	var order: Array = [0]
	while order.size() < n:
		var m := order.size() * 2
		var nxt: Array = []
		for s in order:
			nxt.append(s)
			nxt.append(m - 1 - s)
		order = nxt
	var slots: Array = order.map(func(i): return seeds[i])
	var groups: Array = order.map(func(i): return group_of[i])
	# Troca adversários do mesmo grupo na primeira fase com o jogo seguinte.
	for i in range(0, n, 2):
		if groups[i] == groups[i + 1]:
			for j in range(i + 2, n, 2):
				if groups[j + 1] != groups[i] and groups[i + 1] != groups[j]:
					var t: String = slots[i + 1]
					slots[i + 1] = slots[j + 1]
					slots[j + 1] = t
					var tg: String = groups[i + 1]
					groups[i + 1] = groups[j + 1]
					groups[j + 1] = tg
					break
	return slots


## Títulos, moral e notícias de um torneio.
static func _tournament_effects(world: GameWorld, env: Env, rec: Dictionary) -> void:
	var champ: String = rec["champion"]
	for p: Player in env.squad(champ):
		p.win_title(world.year, "N:" + String(rec.get("t", rec.get("id", ""))), -1)
		p.morale = clampf(p.morale + 15.0, 0.0, 100.0)
	for code in rec["teams"]:
		for p: Player in env.squad(code):
			if code != champ:
				p.morale = clampf(p.morale + (3.0 if code == rec["runner_up"] else -1.0), 0.0, 100.0)
	var sc: Dictionary = rec["scorer"]
	var body := "%s bateu %s na final%s." % [DatabaseManager.nation_name(champ), DatabaseManager.nation_name(rec["runner_up"]), _final_suffix(rec)]
	if not sc.is_empty():
		body += " Artilheiro: %s (%s), com %d gols." % [sc["name"], DatabaseManager.nation_name(sc["nation"]), int(sc["goals"])]
	var imp := NewsEvent.IMP_HIGH
	var nat := _user_nation(world)
	if champ == nat or String(rec["t"]) == "WC":
		imp = NewsEvent.IMP_HEADLINE
	NewsManager.post_raw(world, "%s é campeã da %s %d" % [DatabaseManager.nation_name(champ), rec["name"], int(rec["y"])], body, -1, -1, imp, "selecao")
	if world.has_user():
		var mine: Array = []
		for code in rec["teams"]:
			for p: Player in env.squad(code):
				if p.club_id == world.user_club_id:
					mine.append(p.display_name())
		if not mine.is_empty():
			NewsManager.post_raw(world, "%d jogador(es) do %s na %s" % [mine.size(), world.user_club().short_name, rec["name"]],
				"Convocados: %s." % ", ".join(mine), world.user_club_id, -1, NewsEvent.IMP_NORMAL, "selecao")


static func _final_suffix(rec: Dictionary) -> String:
	var ko: Array = rec["ko"]
	if ko.is_empty():
		return ""
	var f: Array = ko[ko.size() - 1]["m"][0]
	var s := " por %d x %d" % [maxi(int(f[2]), int(f[3])), mini(int(f[2]), int(f[3]))]
	if int(f[4]) >= 0:
		s = " nos pênaltis (%d x %d)" % [maxi(int(f[4]), int(f[5])), mini(int(f[4]), int(f[5]))]
	elif bool(f[6]):
		s += " na prorrogação"
	return s


## Último torneio disputado de um tipo, ou {}.
static func last_edition(world: GameWorld, id: String) -> Dictionary:
	var tours: Array = data(world)["tours"]
	for i in range(tours.size() - 1, -1, -1):
		if String(tours[i]["t"]) == id:
			return tours[i]
	return {}


## Títulos de seleção conquistados por um jogador: [[torneio, ano]].
static func player_titles(world: GameWorld, pid: int) -> Array:
	var out: Array = []
	for r in data(world)["tours"]:
		if Array(r.get("squad", [])).has(pid):
			out.append([String(r["t"]), int(r["y"])])
	return out


## Títulos de uma seleção no save: [[torneio, ano]].
static func titles_of(world: GameWorld, code: String) -> Array:
	var out: Array = []
	for r in data(world)["tours"]:
		if String(r["champion"]) == code:
			out.append([String(r["t"]), int(r["y"])])
	return out
