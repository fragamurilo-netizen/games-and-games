class_name YouthCups
extends RefCounted
## Competições de base além das ligas sub-20 e sub-17 (YouthManager):
##   - "cup20": copa nacional de juniores em mata-mata (no Brasil, a Copinha), no começo do ano;
##   - "cup17": copa nacional sub-17, também em mata-mata, no meio do ano;
##   - "cont": liga jovem continental dos grandes clubes (fase de grupos + mata-mata);
##   - "intl": Mundial de seleções (sub-20 nos anos ímpares, sub-17 nos pares), disputado de uma vez
##     numa data do meio da temporada, com os melhores garotos de cada país — da base e dos elencos.
## Tudo fica em world.youth["comps"] (dados simples, vão no save). Os jogos do clube do usuário
## escalam os garotos de verdade (YouthManager.pick_team) e contam minutos, gols e notas; os outros
## clubes entram com a força derivada da base deles e três destaques com nome (artilharia).
## Ganchos: YouthManager.build_league (monta), play_slot (joga) e finish_league (fecha) — nada novo
## no fluxo da temporada. Saves antigos montam as copas na primeira data jogada (só o que falta).

const CUP_NAMES := {
	"BRA": ["Copa São Paulo de Futebol Júnior", "Copinha"],
	"ENG": ["FA Youth Cup", "Youth Cup"],
	"ESP": ["Copa del Rey Juvenil", "Copa Juvenil"],
	"ITA": ["Coppa Italia Primavera", "Coppa Primavera"],
	"POR": ["Taça Revelação", "Taça Revelação"],
	"ARG": ["Copa de Juveniles", "Copa Juvenil"],
	"GER": ["DFB-Junioren-Pokal", "Junioren-Pokal"],
	"FRA": ["Coupe Gambardella", "Gambardella"],
}
const CONT_NAMES := {
	"UEFA": ["Liga Jovem da UEFA", "Youth League"],
	"CONMEBOL": ["Libertadores Sub-20", "Liberta Sub-20"],
}

const CUP20_SIZE := 32
const CUP17_SIZE := 16
const CONT_SIZE := 16
const INTL_SIZE := 16
const KO_NAMES := {32: "1ª fase", 16: "Oitavas", 8: "Quartas", 4: "Semifinal", 2: "Final"}


# ---------------------------------------------------------------------------
# Estado
# ---------------------------------------------------------------------------

static func comps(world: GameWorld) -> Dictionary:
	if not world.youth.has("comps") or not world.youth["comps"] is Dictionary:
		world.youth["comps"] = {}
	return world.youth["comps"]


static func comp(world: GameWorld, key: String) -> Dictionary:
	return comps(world).get(key, {})


## Ordem de exibição (só as que existem nesta temporada).
static func keys(world: GameWorld) -> Array:
	var out: Array = []
	for k in ["cup20", "cup17", "cont", "intl"]:
		if not comp(world, k).is_empty():
			out.append(k)
	return out


## Monta as competições da temporada (a partir da data `from_day`: saves antigos no meio do ano).
static func build(world: GameWorld, from_day: int = 0) -> void:
	world.youth["comps"] = {}
	if not world.has_user() or world.season == null:
		return
	var weekends := _free_weekends(world, from_day)
	if weekends.size() < 4:
		return
	var c := comps(world)
	var cup20 := _build_cup(world, "cup20", weekends, 0.0, 0.4)
	if not cup20.is_empty():
		c["cup20"] = cup20
	var cup17 := _build_cup(world, "cup17", weekends, 0.35, 0.75)
	if not cup17.is_empty():
		c["cup17"] = cup17
	var cont := _build_cont(world, weekends)
	if not cont.is_empty():
		c["cont"] = cont
	var intl := _build_intl(world, weekends)
	if not intl.is_empty():
		c["intl"] = intl
	world.youth["comps_y"] = world.year


## Saves antigos (ou carreira começada antes das copas existirem): monta o que ainda dá.
static func ensure(world: GameWorld) -> void:
	if not world.has_user() or world.season == null:
		return
	if int(world.youth.get("comps_y", -1)) == world.year:
		return
	build(world, world.season.day)


## Datas de fim de semana livres das ligas da base (a partir de `from_day`).
static func _free_weekends(world: GameWorld, from_day: int) -> Array:
	var busy := {}
	for key in ["u20", "u17"]:
		var yl := YouthManager.league(world, key)
		for s in yl.get("slots", []):
			busy[int(s)] = true
	var free: Array = []
	var all: Array = []
	for i in range(from_day, world.season.calendar.size()):
		if world.season.is_weekend(i):
			all.append(i)
			if not busy.has(i):
				free.append(i)
	# Poucas datas livres: divide com as ligas (os garotos que já jogaram ficam de fora).
	return free if free.size() >= 12 else all


## `n` datas dentro da faixa [a, b] da temporada (fração), espalhadas; completa com as vizinhas.
static func _pick_slots(world: GameWorld, weekends: Array, n: int, a: float, b: float, taken: Dictionary) -> Array:
	var total := float(world.season.calendar.size())
	var pool: Array = []
	for s in weekends:
		var f := float(s) / total
		if f >= a and f <= b and not taken.has(int(s)):
			pool.append(int(s))
	if pool.size() < n:
		for s in weekends:
			if not taken.has(int(s)) and not pool.has(int(s)):
				pool.append(int(s))
		pool.sort()
	if pool.size() < n:
		return []
	var out: Array = []
	for i in n:
		out.append(pool[int(floor(float(i) * pool.size() / float(n)))])
	for s in out:
		taken[s] = true
	return out


static func _taken(world: GameWorld) -> Dictionary:
	var t := {}
	for k in comps(world):
		for r in comps(world)[k].get("rounds", []):
			t[int(r.get("slot", -1))] = true
	return t


static func _rng(world: GameWorld, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.world_seed, world.year, salt])
	return r


## Força de um time de base de clube (mesma escala dos garotos de verdade) e três destaques.
static func _club_team(world: GameWorld, c: Club, age_key: String, rng: RandomNumberGenerator, into: Dictionary, used_names: Dictionary) -> void:
	var yl := YouthManager.league(world, age_key)
	var cid := c.id
	if yl.get("str", {}).has(cid):
		into["str"][cid] = float(yl["str"][cid])
	else:
		var offset := 16.5 if age_key == "u20" else 22.0
		into["str"][cid] = PlayerGenerator.league_level(c) - offset + c.youth_level * 0.07 + rng.randfn(0.0, 2.5)
	if world.is_user_club(cid):
		return
	if yl.get("stars", {}).has(cid):
		into["stars"][cid] = yl["stars"][cid]
		return
	var names: Array = []
	for _k in 3:
		var origin := NameGenerator.pick_origin(rng, c.nation)
		var nm := NameGenerator.generate(rng, origin["c"], {"pos": Pos.ST, "height": 178, "foot": 0, "attrs": PackedByteArray(), "region": ""}, used_names)
		names.append(String(nm["known_as"]) if String(nm["known_as"]) != "" else String(nm["last"]))
	into["stars"][cid] = names


static func _base(key: String, name: String, short: String, kind: String, age_key: String, year: int) -> Dictionary:
	return {"key": key, "name": name, "short": short, "kind": kind, "age": age_key, "year": year,
		"teams": [], "str": {}, "stars": {}, "scorers": {}, "rounds": [], "alive": [], "groups": [],
		"gtable": {}, "champion": -1, "runner": -1, "user_in": false, "user_out": "", "done": false}


# ---------------------------------------------------------------------------
# Copas nacionais (mata-mata)
# ---------------------------------------------------------------------------

static func cup_name(nation: String, key: String) -> Array:
	var nn := DatabaseManager.nation_name(nation)
	if key == "cup17":
		return ["Copa do Brasil Sub-17", "Copa Sub-17"] if nation == "BRA" else ["Copa Sub-17 · %s" % nn, "Copa Sub-17"]
	return CUP_NAMES.get(nation, ["Copa de Juniores · %s" % nn, "Copa Juniores"])


static func _build_cup(world: GameWorld, key: String, weekends: Array, a: float, b: float) -> Dictionary:
	var user := world.user_club()
	var pool: Array = world.clubs_of_nation(user.nation).duplicate()
	var size := CUP20_SIZE if key == "cup20" else CUP17_SIZE
	while size > 8 and pool.size() < size:
		size /= 2
	if pool.size() < size:
		return {}
	var rng := _rng(world, key)
	# Os convidados: os clubes de base mais forte e mais tradicionais do país.
	pool.sort_custom(func(x: Club, y: Club):
		var vx := x.youth_level * 0.6 + x.reputation * 0.4
		var vy := y.youth_level * 0.6 + y.reputation * 0.4
		return vx > vy if vx != vy else x.id < y.id)
	var teams: Array = [user.id]
	for c: Club in pool:
		if teams.size() >= size:
			break
		if c.id != user.id:
			teams.append(c.id)
	var nm := cup_name(user.nation, key)
	var age_key := "u20" if key == "cup20" else "u17"
	var d := _base(key, nm[0], nm[1], "ko", age_key, world.year)
	var used := {}
	for cid in teams:
		_club_team(world, world.club(cid), age_key, rng, d, used)
	var n_rounds := int(round(log(float(size)) / log(2.0)))
	var slots := _pick_slots(world, weekends, n_rounds, a, b, _taken(world))
	if slots.is_empty():
		return {}
	var order: Array = teams.duplicate()
	RngUtil.shuffle(rng, order)
	d["teams"] = teams
	d["alive"] = order
	d["user_in"] = true
	var left := size
	for i in n_rounds:
		d["rounds"].append({"name": KO_NAMES.get(left, "Fase"), "slot": slots[i], "games": [], "ko": true})
		left /= 2
	_draw_ko(d, 0)
	return d


## Sorteia os confrontos da rodada `r` com os classificados (em ordem).
static func _draw_ko(d: Dictionary, r: int) -> void:
	var alive: Array = d["alive"]
	var games: Array = []
	for i in range(0, alive.size() - 1, 2):
		games.append({"h": int(alive[i]), "a": int(alive[i + 1]), "hg": -1, "ag": -1, "w": -1})
	d["rounds"][r]["games"] = games


# ---------------------------------------------------------------------------
# Liga jovem continental (grupos + mata-mata)
# ---------------------------------------------------------------------------

static func _build_cont(world: GameWorld, weekends: Array) -> Dictionary:
	var user := world.user_club()
	var confed := String(DatabaseManager.nation(user.nation).get("confed", ""))
	if confed == "":
		return {}
	var cands: Array = []
	for c: Club in world.clubs:
		if c.tier != 1:
			continue
		if String(DatabaseManager.nation(c.nation).get("confed", "")) != confed:
			continue
		cands.append(c)
	if cands.size() < CONT_SIZE:
		return {}
	cands.sort_custom(func(x: Club, y: Club): return x.reputation > y.reputation if x.reputation != y.reputation else x.id < y.id)
	var per_nation := {}
	var teams: Array = []
	var user_rank := -1
	for c: Club in cands:
		var cnt := int(per_nation.get(c.nation, 0))
		if cnt >= 3:
			continue
		per_nation[c.nation] = cnt + 1
		if c.id == user.id:
			user_rank = teams.size()
		teams.append(c.id)
		if teams.size() >= 24:
			break
	# Os 16 melhores entram; o usuário entra se estiver entre os 24 e jogar a primeira divisão.
	var chosen: Array = teams.slice(0, CONT_SIZE)
	var user_in := chosen.has(user.id)
	if not user_in and user_rank >= 0:
		chosen[CONT_SIZE - 1] = user.id
		user_in = true
	var nm: Array = CONT_NAMES.get(confed, ["Liga Jovem %s" % confed, "Liga Jovem"])
	var d := _base("cont", nm[0], nm[1], "groups", "u20", world.year)
	var rng := _rng(world, "cont")
	var used := {}
	for cid in chosen:
		_club_team(world, world.club(cid), "u20", rng, d, used)
	var slots := _pick_slots(world, weekends, 9, 0.12, 0.9, _taken(world))
	if slots.is_empty():
		return {}
	# Potes pela força: um cabeça de chave por grupo
	var seeded: Array = chosen.duplicate()
	seeded.sort_custom(func(x, y): return float(d["str"][x]) > float(d["str"][y]))
	var groups: Array = [[], [], [], []]
	for pot in 4:
		var slice: Array = seeded.slice(pot * 4, pot * 4 + 4)
		RngUtil.shuffle(rng, slice)
		for g in 4:
			groups[g].append(slice[g])
	d["groups"] = groups
	d["teams"] = chosen
	d["user_in"] = user_in
	for cid in chosen:
		d["gtable"][cid] = CompetitionManager.empty_row()
	# Turno e returno no grupo: 6 rodadas (1-2 3-4 / 1-3 2-4 / 1-4 2-3, depois invertido)
	var pat: Array = [[[0, 1], [2, 3]], [[2, 0], [3, 1]], [[0, 3], [1, 2]]]
	for leg in 2:
		for r in 3:
			var games: Array = []
			for g in groups:
				for pr in pat[r]:
					var h: int = g[pr[0]] if leg == 0 else g[pr[1]]
					var a: int = g[pr[1]] if leg == 0 else g[pr[0]]
					games.append({"h": h, "a": a, "hg": -1, "ag": -1, "w": -1})
			d["rounds"].append({"name": "Grupos · %dª rodada" % (leg * 3 + r + 1), "slot": slots[leg * 3 + r], "games": games, "ko": false})
	for i in 3:
		d["rounds"].append({"name": ["Quartas", "Semifinal", "Final"][i], "slot": slots[6 + i], "games": [], "ko": true})
	return d


static func group_order(d: Dictionary, g: int) -> Array:
	return CompetitionManager.sort_table(d["groups"][g], d["gtable"])


## Fim dos grupos: 1º de um grupo contra o 2º de outro nas quartas.
static func _groups_to_ko(d: Dictionary) -> void:
	var o: Array = []
	for g in 4:
		o.append(group_order(d, g))
	d["alive"] = [o[0][0], o[1][1], o[2][0], o[3][1], o[1][0], o[0][1], o[3][0], o[2][1]]
	for g in 4:
		for i in range(2, o[g].size()):
			_mark_out(d, int(o[g][i]), "fase de grupos")


# ---------------------------------------------------------------------------
# Mundial de seleções de base
# ---------------------------------------------------------------------------

static func intl_age_key(year: int) -> String:
	return "u20" if year % 2 == 1 else "u17"


static func _build_intl(world: GameWorld, weekends: Array) -> Dictionary:
	var age_key := intl_age_key(world.year)
	var max_age := 19 if age_key == "u20" else 16
	var slots := _pick_slots(world, weekends, 1, 0.5, 0.62, _taken(world))
	if slots.is_empty():
		return {}
	var name := "Mundial Sub-20" if age_key == "u20" else "Mundial Sub-17"
	var d := _base("intl", name, name, "intl", age_key, world.year)
	d["max_age"] = max_age
	d["rounds"] = [{"name": "Torneio", "slot": slots[0], "games": [], "ko": false}]
	return d


## Nível típico de uma seleção de base do país (os garotos sem nome dos outros clubes).
static func _nation_level(code: String, age_key: String) -> float:
	var nd := DatabaseManager.nation(code)
	return 40.0 + float(nd.get("coef", 40)) * 0.2 + float(nd.get("youth", 0.0)) * 1.2 - (6.0 if age_key == "u17" else 0.0)


## Convocação: os garotos elegíveis de cada país (elencos + a base do usuário) que estão acima do
## nível da seleção — no máximo 5 do mesmo clube e 18 no total. O resto do grupo são garotos sem
## nome dos outros clubes (o nível do país).
static func _intl_squads(world: GameWorld, max_age: int, age_key: String) -> Dictionary:
	var by_nat := {}
	var add := func(p: Player):
		if p.age(world.year) > max_age or p.retiring or p.nationality == "":
			return
		if not by_nat.has(p.nationality):
			by_nat[p.nationality] = []
		by_nat[p.nationality].append(p)
	for p: Player in world.players.values():
		add.call(p)
	for p: Player in world.academy.values():
		add.call(p)
	for k in by_nat:
		var arr: Array = by_nat[k]
		arr.sort_custom(func(a: Player, b: Player): return a.ovr_f > b.ovr_f if a.ovr_f != b.ovr_f else a.id < b.id)
		var bar := _nation_level(String(k), age_key) - 3.0
		var per_club := {}
		var keep: Array = []
		for p: Player in arr:
			if p.ovr_f < bar or keep.size() >= 18:
				break
			var n := int(per_club.get(p.club_id, 0))
			if p.club_id >= 0 and n >= 5:
				continue
			per_club[p.club_id] = n + 1
			keep.append(p)
		by_nat[k] = keep
	return by_nat


## Força de uma seleção: média dos 11 melhores, completando com o nível do país.
static func _nation_strength(code: String, squad: Array, age_key: String) -> float:
	var level := _nation_level(code, age_key)
	var total := 0.0
	for i in 11:
		total += (squad[i] as Player).ovr_f if i < squad.size() else level
	return total / 11.0


static func _play_intl(world: GameWorld, d: Dictionary) -> void:
	var rng := _rng(world, "intl_play")
	var age_key := String(d["age"])
	var squads := _intl_squads(world, int(d.get("max_age", 19)), age_key)
	var cands: Array = []
	for code in DatabaseManager.nations():
		var sq: Array = squads.get(code, [])
		var s := _nation_strength(code, sq, age_key) + rng.randfn(0.0, 1.5)
		cands.append([code, s])
	cands.sort_custom(func(x, y): return float(x[1]) > float(y[1]))
	var teams: Array = []
	var per_confed := {}
	var user_nat := world.user_club().nation
	for e in cands:
		var confed := String(DatabaseManager.nation(String(e[0])).get("confed", ""))
		if int(per_confed.get(confed, 0)) >= (6 if confed == "UEFA" else 4):
			continue
		per_confed[confed] = int(per_confed.get(confed, 0)) + 1
		teams.append(e)
		if teams.size() >= INTL_SIZE:
			break
	var strength := {}
	for e in teams:
		strength[String(e[0])] = float(e[1])
	var codes: Array = []
	for e in teams:
		codes.append(String(e[0]))
	d["teams"] = codes
	d["str"] = strength
	var groups: Array = [[], [], [], []]
	for pot in 4:
		var slice: Array = codes.slice(pot * 4, pot * 4 + 4)
		RngUtil.shuffle(rng, slice)
		for g in slice.size():
			groups[g].append(slice[g])
	d["groups"] = groups
	var table := {}
	for c in codes:
		table[c] = CompetitionManager.empty_row()
	d["gtable"] = table
	var called := {} # id → {n, c (clube), nat, a, g}
	for c in codes:
		for p: Player in squads.get(c, []):
			called[p.id] = {"n": p.display_name(), "c": p.club_id, "nat": c, "a": 0, "g": 0, "ac": world.academy.has(p.id)}
	d["called"] = called
	var sq_ids := {}
	for c in codes:
		var ids: Array = []
		for p: Player in squads.get(c, []):
			ids.append(p.id)
		sq_ids[c] = ids
	var games: Array = []
	var pat: Array = [[0, 1], [2, 3], [0, 2], [1, 3], [0, 3], [1, 2]]
	for g in groups:
		for pr in pat:
			if pr[1] >= g.size():
				continue
			games.append(_intl_game(world, rng, d, g[pr[0]], g[pr[1]], sq_ids, squads, false))
	d["rounds"][0]["games"] = games
	var o: Array = []
	for g in groups:
		o.append(CompetitionManager.sort_table(g, table))
	var alive: Array = [o[0][0], o[1][1], o[2][0], o[3][1], o[1][0], o[0][1], o[3][0], o[2][1]]
	for name in ["Quartas", "Semifinal", "Final"]:
		var kg: Array = []
		var nxt: Array = []
		for i in range(0, alive.size() - 1, 2):
			var gm := _intl_game(world, rng, d, alive[i], alive[i + 1], sq_ids, squads, true)
			kg.append(gm)
			nxt.append(gm["w"])
			if name == "Final":
				d["champion"] = gm["w"]
				d["runner"] = alive[i + 1] if gm["w"] == alive[i] else alive[i]
		d["rounds"].append({"name": name, "slot": d["rounds"][0]["slot"], "games": kg, "ko": true})
		alive = nxt
	d["done"] = true
	d["user_nat"] = user_nat
	_after_intl(world, d, squads)


static func _intl_game(world: GameWorld, rng: RandomNumberGenerator, d: Dictionary, h: String, a: String, sq_ids: Dictionary, squads: Dictionary, ko: bool) -> Dictionary:
	var sh := float(d["str"][h])
	var sa := float(d["str"][a])
	var hg := YouthManager._poisson(rng, clampf(1.3 * exp((sh - sa) / 11.0), 0.2, 5.0))
	var ag := YouthManager._poisson(rng, clampf(1.3 * exp((sa - sh) / 11.0), 0.2, 5.0))
	var gm := {"h": h, "a": a, "hg": hg, "ag": ag, "w": ""}
	if not ko:
		var f := Fixture.new()
		f.home = 0
		f.away = 1
		f.hg = hg
		f.ag = ag
		var t := {0: d["gtable"][h], 1: d["gtable"][a]}
		CompetitionManager.apply_to_table(t, f)
	else:
		if hg != ag:
			gm["w"] = h if hg > ag else a
		else:
			gm["pen"] = true
			gm["w"] = h if rng.randf() < 0.5 + (sh - sa) * 0.02 else a
	_intl_credit(world, rng, d, h, hg, squads)
	_intl_credit(world, rng, d, a, ag, squads)
	return gm


static func _intl_credit(world: GameWorld, rng: RandomNumberGenerator, d: Dictionary, code: String, goals: int, squads: Dictionary) -> void:
	var sq: Array = squads.get(code, [])
	var called: Dictionary = d["called"]
	var xi: Array = sq.slice(0, mini(14, sq.size()))
	var wg: Array = []
	for p: Player in xi:
		called[p.id]["a"] = int(called[p.id]["a"]) + 1
		wg.append(float(p.attrs[Attr.FIN] + p.attrs[Attr.POS]) * [0.0, 0.25, 1.2, 3.0][Pos.group(p.position)] + 1.0)
	wg.append(maxf(0.0, 11.0 - xi.size()) * 80.0) # gols dos garotos sem nome
	var sc: Dictionary = d["scorers"]
	for _i in goals:
		var k := RngUtil.weighted_index(rng, wg)
		if k < 0 or k >= xi.size():
			continue
		var p: Player = xi[k]
		called[p.id]["g"] = int(called[p.id]["g"]) + 1
		var key := "p%d" % p.id
		if not sc.has(key):
			sc[key] = {"n": p.display_name(), "c": p.club_id, "nat": code, "g": 0, "pid": p.id}
		sc[key]["g"] = int(sc[key]["g"]) + 1


## Depois do Mundial: notícias, moral e um empurrão na evolução de quem jogou.
static func _after_intl(world: GameWorld, d: Dictionary, squads: Dictionary) -> void:
	var called: Dictionary = d["called"]
	var mine: Array = []
	for pid in called:
		var e: Dictionary = called[pid]
		var p: Player = world.academy.get(pid, null)
		if p == null:
			p = world.players.get(pid, null)
		if p == null:
			continue
		if int(e["a"]) > 0:
			PlayerDevelopment.apply_growth(world, p, 0.25 + int(e["a"]) * 0.05)
			p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
		var ours := world.academy.has(p.id) or (p.club_id >= 0 and world.is_user_club(p.club_id))
		if ours:
			mine.append(e)
			if world.academy.has(p.id):
				_add_cs(world, p.id, "intl", int(e["a"]), int(e["g"]), 0)
				_shine(world, p.id, 1 + (1 if int(e["g"]) >= 2 else 0))
	var champ := String(d["champion"])
	var cn := DatabaseManager.nation_name(champ)
	var top := top_scorers(d, 1)
	var body := "A seleção %s de %s conquistou o %s." % [String(DatabaseManager.nation(champ).get("adj", "")), cn, d["name"]]
	if not top.is_empty():
		body += " Artilheiro: %s (%s), com %d gols." % [top[0]["n"], DatabaseManager.nation_name(String(top[0]["nat"])), int(top[0]["g"])]
	NewsManager.post_raw(world, "%s é campeão do %s" % [cn, d["name"]], body, -1, -1, NewsEvent.IMP_NORMAL, "base")
	if not mine.is_empty():
		var parts: Array = []
		for e in mine:
			parts.append("%s (%s%s)" % [e["n"], DatabaseManager.nation_name(String(e["nat"])), (", %d gols" % int(e["g"])) if int(e["g"]) > 0 else ""])
		NewsManager.post_raw(world, "Garotos do %s no %s" % [world.user_club().short_name, d["name"]],
			"Convocados pelo clube: %s. A vitrine valoriza os garotos e acelera a evolução." % ", ".join(PackedStringArray(parts)),
			world.user_club_id, -1, NewsEvent.IMP_NORMAL, "base")


# ---------------------------------------------------------------------------
# Rodadas
# ---------------------------------------------------------------------------

## Joga as partidas marcadas para esta data. `used`: garotos que já jogaram hoje (ligas).
static func play_slot(world: GameWorld, slot: int, used: Dictionary) -> void:
	ensure(world)
	var c := comps(world)
	for k in c:
		var d: Dictionary = c[k]
		if bool(d.get("done", false)):
			continue
		var rounds: Array = d["rounds"]
		for r in rounds.size():
			if int(rounds[r].get("slot", -1)) != slot:
				continue
			if d["kind"] == "intl":
				_play_intl(world, d)
				break
			_play_round(world, d, r, used)


static func _team_str(world: GameWorld, d: Dictionary, cid: int) -> float:
	var progress := float(world.season.day) / maxf(1.0, float(world.season.calendar.size()))
	return float(d["str"].get(cid, 45.0)) + progress * 2.0


static func _round_done(d: Dictionary, r: int) -> bool:
	var games: Array = d["rounds"][r]["games"]
	if games.is_empty():
		return false
	for g in games:
		if int(g["hg"]) < 0:
			return false
	return true


static func _play_round(world: GameWorld, d: Dictionary, r: int, used: Dictionary) -> void:
	if r > 0 and not _round_done(d, r - 1):
		_play_round(world, d, r - 1, used) # data pulada: a rodada anterior vem antes
	var round: Dictionary = d["rounds"][r]
	if round["games"].is_empty() and bool(round.get("ko", false)):
		if d["kind"] == "groups" and r == 6:
			_groups_to_ko(d)
		_draw_ko(d, r)
	var ko := bool(round.get("ko", false))
	var final: bool = ko and r == d["rounds"].size() - 1
	var winners: Array = []
	for g in round["games"]:
		if int(g["hg"]) >= 0:
			winners.append(g["w"])
			continue
		var h := int(g["h"])
		var a := int(g["a"])
		var mine := world.is_user_club(h) or world.is_user_club(a)
		var team := {}
		if mine:
			team = YouthManager.pick_team(world, String(d["age"]), used)
			for e in team["xi"]:
				used[e[0].id] = true
			for bp: Player in team["bench"]:
				used[bp.id] = true
		var sh: float = float(team["str"]) if world.is_user_club(h) else _team_str(world, d, h)
		var sa: float = float(team["str"]) if world.is_user_club(a) else _team_str(world, d, a)
		var adv := 1.0 if final else 1.08 # final em campo neutro
		var hg := YouthManager._poisson(world.rng, clampf(1.45 * exp((sh - sa) / 11.0) * adv, 0.2, 5.0))
		var ag := YouthManager._poisson(world.rng, clampf(1.25 * exp((sa - sh) / 11.0) * (1.08 if final else 1.0), 0.2, 5.0))
		g["hg"] = hg
		g["ag"] = ag
		if not ko:
			var f := Fixture.new()
			f.home = h
			f.away = a
			f.hg = hg
			f.ag = ag
			CompetitionManager.apply_to_table(d["gtable"], f)
		else:
			if hg != ag:
				g["w"] = h if hg > ag else a
			else:
				g["pen"] = true
				g["w"] = h if world.rng.randf() < 0.5 + (sh - sa) * 0.02 else a
			winners.append(g["w"])
		if world.is_user_club(h):
			g["info"] = YouthManager._credit_user(world, d, team, hg, ag, d["key"])
			YouthManager._credit_goals(world, d, a, ag)
		elif world.is_user_club(a):
			YouthManager._credit_goals(world, d, h, hg)
			g["info"] = YouthManager._credit_user(world, d, team, ag, hg, d["key"])
		else:
			YouthManager._credit_goals(world, d, h, hg)
			YouthManager._credit_goals(world, d, a, ag)
		if mine:
			_user_game_news(world, d, round, g, team)
	if ko:
		for g in round["games"]:
			var loser := int(g["a"]) if int(g["w"]) == int(g["h"]) else int(g["h"])
			_mark_out(d, loser, String(round["name"]).to_lower())
		d["alive"] = winners
		if final and not round["games"].is_empty():
			var fg: Dictionary = round["games"][0]
			d["champion"] = int(fg["w"])
			d["runner"] = int(fg["a"]) if int(fg["w"]) == int(fg["h"]) else int(fg["h"])
			_finish_comp(world, d)


static func _mark_out(d: Dictionary, cid: int, stage: String) -> void:
	var out: Dictionary = d.get("out", {})
	out[cid] = stage
	d["out"] = out


## Notícias do jogo do usuário: hat-trick, eliminação e classificação para a final.
static func _user_game_news(world: GameWorld, d: Dictionary, round: Dictionary, g: Dictionary, team: Dictionary) -> void:
	var uid := world.user_club_id
	var home := int(g["h"]) == uid
	var opp := world.club(int(g["a"]) if home else int(g["h"]))
	var info: Dictionary = g.get("info", {})
	var count := {}
	for n in info.get("g", []):
		count[n] = int(count.get(n, 0)) + 1
	for n in count:
		if int(count[n]) >= 3:
			NewsManager.post_raw(world, "%s marca %d vezes pelo %s" % [n, int(count[n]), d["short"]],
				"Noite de gala na base: %s fez %d gols contra o %s pela %s (%s)." % [n, int(count[n]), opp.short_name, d["name"], String(round["name"]).to_lower()],
				uid, -1, NewsEvent.IMP_NORMAL, "base")
	if bool(round.get("ko", false)) and int(g["w"]) != uid and int(g["w"]) >= 0:
		d["user_out"] = String(round["name"])
		var pen := " nos pênaltis" if g.get("pen", false) else ""
		NewsManager.post_raw(world, "Base do %s cai na %s da %s" % [world.user_club().short_name, String(round["name"]).to_lower(), d["short"]],
			"A garotada perdeu para o %s%s e se despediu da %s." % [opp.short_name, pen, d["name"]], uid, -1, NewsEvent.IMP_LOW, "base")
	elif bool(round.get("ko", false)) and String(round["name"]) == "Semifinal" and int(g["w"]) == uid:
		NewsManager.post_raw(world, "Base do %s na final da %s" % [world.user_club().short_name, d["short"]],
			"Os garotos passaram pelo %s e disputam o título da %s." % [opp.short_name, d["name"]], uid, -1, NewsEvent.IMP_NORMAL, "base")
		for e in team.get("xi", []):
			(e[0] as Player).morale = clampf((e[0] as Player).morale + 3.0, 0.0, 100.0)


## Campeão definido: notícia, honraria da base e moral.
static func _finish_comp(world: GameWorld, d: Dictionary) -> void:
	if bool(d.get("done", false)):
		return
	d["done"] = true
	var champ := world.club(int(d["champion"]))
	if champ == null:
		return
	var top := top_scorers(d, 1)
	var tail := ""
	if not top.is_empty():
		var tc := world.club(int(top[0]["c"]))
		tail = " Artilheiro: %s (%s), %d gols." % [top[0]["n"], tc.short_name if tc != null else "?", int(top[0]["g"])]
	if world.is_user_club(champ.id):
		_honour(world, d, "Campeão")
		for p: Player in world.academy.values():
			if YouthManager.category(p, world.year) == (YouthManager.CAT_U20 if d["age"] == "u20" else YouthManager.CAT_U17):
				p.morale = clampf(p.morale + 8.0, 0.0, 100.0)
		world.user_club().fan_mood = clampf(world.user_club().fan_mood + 1.5, 0.0, 100.0)
		NewsManager.post_raw(world, "%s é campeão da %s!" % [champ.short_name, d["short"]],
			"A base do %s conquistou a %s. Os garotos ganham moral e vitrine.%s" % [champ.short_name, d["name"], tail], champ.id, -1, NewsEvent.IMP_HIGH, "base")
	else:
		if world.is_user_club(int(d.get("runner", -1))):
			_honour(world, d, "Vice-campeão")
		NewsManager.post_raw(world, "%s conquista a %s" % [champ.short_name, d["short"]],
			"O %s ficou com o título da %s.%s" % [champ.short_name, d["name"], tail], champ.id, -1, NewsEvent.IMP_LOW, "base")
	if not top.is_empty() and top[0].has("pid") and world.academy.has(int(top[0]["pid"])):
		_shine(world, int(top[0]["pid"]), 2)
		NewsManager.post_raw(world, "%s é o artilheiro da %s" % [top[0]["n"], d["short"]],
			"O garoto da base do %s terminou a %s com %d gols." % [world.user_club().short_name, d["name"], int(top[0]["g"])],
			world.user_club_id, int(top[0]["pid"]), NewsEvent.IMP_NORMAL, "base")


static func _honour(world: GameWorld, d: Dictionary, what: String) -> void:
	var hon: Array = world.youth.get("hon", [])
	hon.append({"y": world.year, "n": String(d["name"]), "r": what, "c": world.user_club_id})
	world.youth["hon"] = hon


## Garoto que brilhou: aumenta a chance de estirão no balanço do ano.
static func _shine(world: GameWorld, pid: int, pts: int) -> void:
	var sh: Dictionary = world.youth.get("shine", {})
	sh[str(pid)] = int(sh.get(str(pid), 0)) + pts
	world.youth["shine"] = sh


## Números da temporada por competição: world.youth["cs"][id][comp] = [jogos, gols, assistências].
static func _add_cs(world: GameWorld, pid: int, key: String, apps: int, goals: int, assists: int) -> void:
	var cs: Dictionary = world.youth.get("cs", {})
	var k := str(pid)
	var e: Dictionary = cs.get(k, {})
	var v: Array = e.get(key, [0, 0, 0])
	e[key] = [int(v[0]) + apps, int(v[1]) + goals, int(v[2]) + assists]
	cs[k] = e
	world.youth["cs"] = cs


## Fim da temporada: completa o que faltou (datas puladas) e resume para a tela de fim de ano.
static func finish(world: GameWorld) -> Array:
	var out: Array = []
	var c := comps(world)
	for k in keys(world):
		var d: Dictionary = c[k]
		if not bool(d.get("done", false)):
			if d["kind"] == "intl":
				_play_intl(world, d)
			else:
				for r in d["rounds"].size():
					_play_round(world, d, r, {})
		var e := {"key": k, "name": d["name"], "champion": d["champion"]}
		if d["kind"] != "intl":
			e["user"] = result_text(world, d)
		out.append(e)
	return out


# ---------------------------------------------------------------------------
# Consultas para a interface
# ---------------------------------------------------------------------------

static func top_scorers(d: Dictionary, n: int) -> Array:
	var arr: Array = d.get("scorers", {}).values()
	arr.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["g"]) > int(b["g"]) if int(a["g"]) != int(b["g"]) else String(a["n"]) < String(b["n"]))
	return arr.slice(0, n)


## Situação do clube do usuário na competição ("Campeão", "Caiu nas quartas", "Na semifinal"...).
static func result_text(world: GameWorld, d: Dictionary) -> String:
	if d.is_empty():
		return ""
	var uid := world.user_club_id
	if not d["teams"].has(uid):
		return "Não classificado"
	if int(d["champion"]) == uid:
		return "Campeão"
	if int(d.get("runner", -1)) == uid:
		return "Vice-campeão"
	var out: Dictionary = d.get("out", {})
	if out.has(uid):
		return "Eliminado (%s)" % String(out[uid])
	for r in d["rounds"]:
		for g in r["games"]:
			if (int(g["h"]) == uid or int(g["a"]) == uid) and int(g["hg"]) < 0:
				return "Na disputa · %s" % String(r["name"]).to_lower()
	return "Na disputa"


## Próxima data de jogo (ou -1) — para a interface mostrar quando começa.
static func next_slot(world: GameWorld, d: Dictionary) -> int:
	for r in d.get("rounds", []):
		var played := false
		for g in r["games"]:
			if int(g["hg"]) >= 0:
				played = true
		if not played and int(r["slot"]) >= world.season.day:
			return int(r["slot"])
	return -1


## Convocados do clube do usuário no Mundial: [{n, nat, a, g}].
static func user_called(world: GameWorld, d: Dictionary) -> Array:
	var out: Array = []
	for pid in d.get("called", {}):
		var e: Dictionary = d["called"][pid]
		if world.is_user_club(int(e.get("c", -1))):
			out.append(e)
	return out
