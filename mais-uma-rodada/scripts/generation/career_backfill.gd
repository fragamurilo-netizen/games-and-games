class_name CareerBackfill
extends RefCounted
## Passado de cada jogador antes do primeiro ano do jogo: de onde saiu, por quais clubes passou
## (com empréstimos na juventude), quantos jogos, gols e assistências fez por temporada, a nota
## média, como o overall evoluiu, os títulos que ganhou (cruzando com os campeões reais do
## histórico) e os prêmios de artilheiro, craque e revelação de cada liga.
##
## Tudo coerente com quem ele é hoje: a curva de overall volta no tempo pela idade e pela curva
## de desenvolvimento, os clubes do passado têm o nível que ele tinha na época, os estrangeiros
## começam no país natal e os jogadores de países sem liga no jogo passam por clubes reais de lá
## (data/world/foreign_clubs.json). RNG próprio: o resto do mundo não muda.

const MAX_SEASONS := 20
## Para onde os jogadores de cada confederação costumam ir quando crescem demais para casa.
const ROUTES := {
	"CONMEBOL": {"BRA": 3.0, "ARG": 1.5, "POR": 2.5, "ESP": 2.5, "ITA": 1.5, "MEX": 1.2, "USA": 0.8, "ENG": 1.0, "FRA": 0.6, "KSA": 0.6},
	"CAF": {"FRA": 4.0, "BEL": 2.0, "POR": 1.5, "ENG": 2.0, "ESP": 1.0, "ITA": 1.0, "GER": 1.0, "TUR": 1.0, "KSA": 0.8, "EGY": 0.6},
	"AFC": {"JPN": 1.5, "KOR": 1.2, "KSA": 1.5, "QAT": 1.0, "UAE": 1.0, "GER": 1.0, "ENG": 0.8, "NED": 0.8, "BEL": 0.8, "POR": 0.5},
	"CONCACAF": {"MEX": 2.5, "USA": 2.5, "ESP": 0.8, "ENG": 1.0, "NED": 0.8, "BEL": 0.6, "GER": 0.6},
	"UEFA": {"ENG": 3.0, "ESP": 2.0, "GER": 2.0, "ITA": 2.0, "FRA": 1.5, "POR": 1.0, "NED": 1.0, "BEL": 0.8, "TUR": 0.8, "SCO": 0.4},
	"OFC": {"AUS": 3.0, "ENG": 0.8, "NED": 0.4},
}


static func build(world: GameWorld) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed * 53 + 11)
	var ctx := _context(world)
	var ids: Array = world.players.keys()
	ids.sort()
	for pid in ids:
		var p: Player = world.players[pid]
		_backfill(world, rng, ctx, p)
	_season_awards(world, ctx)


# ---------------------------------------------------------------------------
# Contexto: clubes por país e nível, campeões por ano
# ---------------------------------------------------------------------------

static func _context(world: GameWorld) -> Dictionary:
	var top := {} # nação -> nível do clube mais forte
	var by_nation := {} # nação -> [[nível, club_id ou -1, nome, liga]]
	for c: Club in world.clubs:
		if not by_nation.has(c.nation):
			by_nation[c.nation] = []
		by_nation[c.nation].append([PlayerGenerator.club_level(c), c.id, c.short_name, c.league_id])
	var foreign: Dictionary = (DatabaseManager.get_data("foreign_clubs") as Dictionary).get("clubs", {}) if DatabaseManager.get_data("foreign_clubs") is Dictionary else {}
	for nat in foreign:
		if by_nation.has(nat):
			continue
		var arr: Array = []
		for e in foreign[nat]:
			arr.append([float(e[1]), -1, String(e[0]), ""])
		by_nation[nat] = arr
	# Campeões: ano -> {club_id: [chaves de título]}
	var champs := {}
	for s: Dictionary in world.history:
		var y := int(s.get("y", 0))
		var m := {}
		for lid in s.get("leagues", {}):
			var cid := int(s["leagues"][lid].get("champion", -1))
			if cid >= 0:
				if not m.has(cid):
					m[cid] = []
				m[cid].append("L:" + String(lid))
		for cup in s.get("cups", {}):
			var cid2 := int(s["cups"][cup].get("champion", -1))
			if cid2 >= 0:
				if not m.has(cid2):
					m[cid2] = []
				m[cid2].append(("W:" if String(cup) == CupManager.CWC else "C:") + String(cup))
		champs[y] = m
	for nat in by_nation:
		var best := 0.0
		for e: Array in by_nation[nat]:
			best = maxf(best, float(e[0]))
		top[nat] = best
	return {"nations": by_nation, "top": top, "champs": champs, "rows": {}, "wcache": {}}


## País onde ele jogava naquele ano: em casa enquanto cabe na liga de lá; quando fica bom
## demais, nas rotas da confederação (sul-americanos em Brasil, Portugal, Espanha...).
static func _pick_nation(rng: RandomNumberGenerator, ctx: Dictionary, home: String, current: String, level: float, age: int) -> String:
	var tops: Dictionary = ctx["top"]
	var cands := {}
	if tops.has(home):
		cands[home] = 6.0 if age <= 20 else 3.0
	if tops.has(current) and current != home:
		cands[current] = 0.3 if age <= 19 else 1.6
	var confed := String(DatabaseManager.nation(home).get("confed", "UEFA"))
	var routes: Dictionary = ROUTES.get(confed, ROUTES["UEFA"])
	for nat in routes:
		if tops.has(nat):
			cands[nat] = float(cands.get(nat, 0.0)) + float(routes[nat]) * (0.15 if age <= 19 else 0.5)
	# A liga precisa ter clube do nível dele (sem ficar anos jogando muito abaixo)
	for nat in cands.keys():
		var gap := level - float(tops[nat]) - 3.0
		if gap > 0.0:
			cands[nat] = float(cands[nat]) * exp(-gap * gap / 10.0)
	if cands.is_empty():
		return current if tops.has(current) else home
	var pick: Variant = RngUtil.pick_weighted(rng, cands)
	return String(pick) if pick != null else home


## Clube do passado para quem tinha `level` de overall: um onde ele caberia no elenco.
## Os pesos por (país, nível desejado) ficam em cache: são milhares de jogadores.
static func _pick_club(rng: RandomNumberGenerator, ctx: Dictionary, nation: String, level: float, role: float, avoid: Array) -> Array:
	var pool: Array = ctx["nations"].get(nation, [])
	if pool.is_empty():
		return []
	# `role` > 0: clube mais fraco que ele (titular); < 0: clube mais forte (reserva, aposta)
	var want := int(round(level - role))
	var key := "%s:%d" % [nation, want]
	var cache: Dictionary = ctx["wcache"]
	if not cache.has(key):
		var cum := PackedFloat32Array()
		var total := 0.0
		for e: Array in pool:
			var d := float(e[0]) - want
			total += exp(-(d * d) / 18.0) + 0.0001
			cum.append(total)
		cache[key] = cum
	var cw: PackedFloat32Array = cache[key]
	for _try in 4:
		var i := cw.bsearch(rng.randf() * cw[cw.size() - 1])
		i = clampi(i, 0, pool.size() - 1)
		var e2: Array = pool[i]
		if int(e2[1]) < 0 or not avoid.has(int(e2[1])):
			return e2
	return pool[rng.randi_range(0, pool.size() - 1)]


# ---------------------------------------------------------------------------
# Carreira de um jogador
# ---------------------------------------------------------------------------

static func _backfill(world: GameWorld, rng: RandomNumberGenerator, ctx: Dictionary, p: Player) -> void:
	var year := world.year
	var age := p.age(year)
	var debut_age := 18
	if p.overall >= 76 or (age <= 21 and p.potential >= 80):
		debut_age = 17
	if p.position == Pos.GK:
		debut_age += 1
	debut_age += rng.randi_range(0, 1)
	var first_y := maxi(year - MAX_SEASONS, year - (age - debut_age))
	if first_y >= year:
		return
	# Overall de cada ano, voltando no tempo
	var ovr := {}
	var o := float(p.overall)
	for y in range(year - 1, first_y - 1, -1):
		o -= _growth(p, age - (year - 1 - y), rng)
		ovr[y] = clampf(o, 25.0, float(p.overall) + 6.0)
	# Clubes: o atual desde joined_year; antes, passagens de 1 a 4 anos com empréstimos na juventude
	var cur := world.club(p.club_id) if p.club_id >= 0 else null
	var join := p.joined_year if cur != null else year
	join = clampi(join, first_y, year)
	var plan := {} # ano -> [club_id, nome, liga, nível, empréstimo, nação]
	for y in range(join, year):
		plan[y] = [cur.id, cur.short_name, cur.league_id, PlayerGenerator.club_level(cur), false, cur.nation]
	var home := p.nationality
	var y2 := join - 1
	var avoid: Array = [cur.id] if cur != null else []
	var later_level := PlayerGenerator.club_level(cur) if cur != null else float(p.overall)
	while y2 >= first_y:
		var yr_age := age - (year - y2)
		var lvl: float = ovr[y2]
		var nation := _pick_nation(rng, ctx, home, cur.nation if cur != null else home, lvl, yr_age)
		var span := 1 + RngUtil.weighted_index(rng, [30.0, 30.0, 22.0, 12.0])
		if yr_age <= 19:
			span = maxi(span, 2)
		var role := rng.randfn(1.5 if yr_age >= 22 else -1.0, 3.0)
		var club := _pick_club(rng, ctx, nation, lvl, role, avoid)
		if club.is_empty():
			break
		# Empréstimo: o jovem do clube grande roda por um ano num menor
		var loan := yr_age <= 22 and float(club[0]) < later_level - 3.0 and rng.randf() < 0.45
		if loan:
			span = 1
		for k in span:
			var yy := y2 - k
			if yy < first_y:
				break
			plan[yy] = [int(club[1]), String(club[2]), String(club[3]), float(club[0]), loan and k == 0, nation]
		if not loan:
			later_level = float(club[0])
		avoid = [int(club[1])]
		y2 -= span
	# Estreia quase sempre em casa: o primeiro ano vai para um clube do país natal (o mais
	# próximo do nível dele) quando o país tem clubes conhecidos
	if plan.has(first_y) and String(plan[first_y][5]) != home and ctx["nations"].has(home) and rng.randf() < 0.85 \
			and (cur == null or int(plan[first_y][0]) != cur.id):
		var hc := _pick_club(rng, ctx, home, minf(float(ovr[first_y]), float(ctx["top"][home])), 0.5, [])
		if not hc.is_empty():
			plan[first_y] = [int(hc[1]), String(hc[2]), String(hc[3]), float(hc[0]), false, home]
	# Temporadas
	var hist: Array = []
	var ys: Array = plan.keys()
	ys.sort()
	for y in ys:
		var e: Array = plan[y]
		var row := _season_row(rng, p, y, e, float(ovr.get(y, p.overall)), float(ovr.get(y - 1, float(ovr.get(y, p.overall)) - 1.0)), age - (year - y))
		hist.append(row)
		p.career_apps += int(row["a"])
		p.career_goals += int(row["g"])
		p.career_assists += int(row["as"])
		# Títulos do clube naquele ano (tendo jogado)
		var cid := int(e[0])
		if cid >= 0 and int(row["a"]) >= 5:
			for key in ctx["champs"].get(int(y), {}).get(cid, []):
				p.win_title(int(y), key, cid)
		# Guarda para os prêmios da liga
		var lid := String(e[2])
		if lid != "":
			var key2 := "%d|%s" % [y, lid]
			if not ctx["rows"].has(key2):
				ctx["rows"][key2] = []
			ctx["rows"][key2].append([p, row])
	p.history = hist + p.history
	# Passagens (em ordem); a atual continua aberta e soma o que ele já jogou lá
	var spells: Array = []
	for row: Dictionary in hist:
		var last: Dictionary = spells.back() if not spells.is_empty() else {}
		if not last.is_empty() and int(last["c"]) == int(row["c"]) and String(last["cn"]) == String(row["cn"]) and bool(last.get("lo", false)) == bool(row.get("lo", false)):
			last["to"] = int(row["y"])
			last["a"] = int(last["a"]) + int(row["a"])
			last["g"] = int(last["g"]) + int(row["g"])
			last["as"] = int(last["as"]) + int(row["as"])
		else:
			var sp := {"c": int(row["c"]), "cn": String(row["cn"]), "from": int(row["y"]), "to": int(row["y"]), "a": int(row["a"]), "g": int(row["g"]), "as": int(row["as"])}
			if bool(row.get("lo", false)):
				sp["lo"] = true
			spells.append(sp)
	if cur != null:
		var open := {"c": cur.id, "cn": cur.short_name, "from": join, "to": 0, "a": 0, "g": 0, "as": 0}
		if not spells.is_empty() and int(spells.back()["c"]) == cur.id and not bool(spells.back().get("lo", false)):
			var sp2: Dictionary = spells.pop_back()
			open["from"] = int(sp2["from"])
			open["a"] = int(sp2["a"])
			open["g"] = int(sp2["g"])
			open["as"] = int(sp2["as"])
		spells.append(open)
		p.joined_year = int(open["from"])
	p.spells = spells
	_earned_traits(rng, p, year, age)


## Traços que se ganham com a estrada: ídolo de quem tem anos de clube, cascudo de quem já
## viu de tudo (quem gerou o jogador não tinha como saber o passado dele).
static func _earned_traits(rng: RandomNumberGenerator, p: Player, year: int, age: int) -> void:
	var conflicts: Array = DatabaseManager.personalities().get("conflicts", [])
	var add: Array = []
	var cur_spell: Dictionary = p.spells.back() if not p.spells.is_empty() else {}
	if p.club_id >= 0 and not cur_spell.is_empty() and year - p.joined_year >= 6 and int(cur_spell.get("a", 0)) >= 150 and rng.randf() < 0.45:
		add.append("idolo")
	if age >= 31 and p.career_apps >= 300 and rng.randf() < 0.35:
		add.append("cascudo")
	if add.is_empty() or p.traits.size() >= 3:
		return
	var tr: Array = p.traits.duplicate()
	for t in add:
		if tr.has(t) or tr.size() >= 3:
			continue
		var clash := false
		for other in tr:
			if PlayerGenerator._conflicts(conflicts, t, other):
				clash = true
		if not clash:
			tr.append(t)
	p.set_traits(tr)


## Quanto o overall subiu (ou caiu) no ano em que o jogador tinha `age`.
static func _growth(p: Player, age: int, rng: RandomNumberGenerator) -> float:
	var g := 0.0
	if age <= 18:
		g = 4.0
	elif age <= 19:
		g = 3.5
	elif age <= 20:
		g = 3.0
	elif age <= 21:
		g = 2.4
	elif age <= 22:
		g = 1.9
	elif age <= 23:
		g = 1.4
	elif age <= 24:
		g = 0.9
	elif age <= 27:
		g = 0.4
	elif age <= 29:
		g = 0.0
	elif age <= 30:
		g = -0.8
	elif age <= 31:
		g = -1.3
	elif age <= 32:
		g = -1.9
	else:
		g = -2.6
	match p.dev_curve:
		Player.CURVE_PRECOCE:
			g *= 1.25 if age <= 22 else 1.0
			if age >= 28:
				g -= 0.5
		Player.CURVE_TARDIO:
			g *= 0.7 if age <= 21 else 1.0
			if age >= 22 and age <= 27:
				g += 0.7
		Player.CURVE_DECLINIO_PRECOCE:
			if age >= 27:
				g -= 1.0
		Player.CURVE_LONGEVO:
			if age >= 30:
				g += 1.0
	return g + rng.randfn(0.0, 0.8)


## Números de uma temporada, pelo papel que ele tinha no clube.
static func _season_row(rng: RandomNumberGenerator, p: Player, y: int, e: Array, o: float, o0: float, age: int) -> Dictionary:
	var lvl := float(e[3])
	var q := o - lvl
	var lid := String(e[2])
	var rounds := _rounds(lid)
	var share := 0.0 # fração dos jogos
	if q >= 3.0:
		share = rng.randf_range(0.72, 0.95)
	elif q >= 0.0:
		share = rng.randf_range(0.55, 0.85)
	elif q >= -3.0:
		share = rng.randf_range(0.3, 0.62)
	elif q >= -6.0:
		share = rng.randf_range(0.1, 0.35)
	else:
		share = rng.randf_range(0.0, 0.14)
	if bool(e[4]):
		share = maxf(share, rng.randf_range(0.5, 0.85)) # emprestado para jogar
	if p.position == Pos.GK and q < 0.0:
		share *= 0.45 # goleiro reserva quase não joga
	share *= 1.0 - clampf((p.injury_prone - 10) * 0.025, -0.05, 0.25) * rng.randf()
	var apps := int(round(rounds * clampf(share, 0.0, 1.0)))
	var starts := int(round(apps * clampf(0.35 + share * 0.7, 0.0, 1.0)))
	var fin := float(p.attrs[Attr.FIN])
	var g_rate := 0.0
	var a_rate := 0.0
	match Pos.group(p.position):
		Pos.G_GK:
			g_rate = 0.0
			a_rate = 0.005
		Pos.G_DEF:
			g_rate = 0.02 + maxf(0.0, float(p.attrs[Attr.CAB]) - 60.0) * 0.0015
			a_rate = 0.03 + (0.05 if p.position != Pos.CB else 0.0)
		Pos.G_MID:
			g_rate = 0.04 + maxf(0.0, fin - 50.0) * 0.004
			a_rate = 0.06 + maxf(0.0, float(p.attrs[Attr.PAS]) - 55.0) * 0.004
		_:
			g_rate = 0.12 + maxf(0.0, fin - 45.0) * 0.0085
			a_rate = 0.07 + maxf(0.0, float(p.attrs[Attr.VIS]) - 50.0) * 0.003
	if p.position in [Pos.AM, Pos.RW, Pos.LW]:
		g_rate *= 0.75
		a_rate *= 1.5
	# Em time melhor que ele marca menos; em time mais fraco, é a referência
	var k := clampf(1.0 + q * 0.03, 0.7, 1.3) * (0.55 + 0.45 * float(starts) / maxf(1.0, apps))
	var goals := _poisson(rng, apps * g_rate * k)
	var assists := _poisson(rng, apps * a_rate * k)
	var rating := clampf(6.45 + q * 0.045 + rng.randfn(0.0, 0.18) + minf(0.35, goals * 0.012), 5.8, 8.3)
	var row := {"y": y, "c": int(e[0]), "cn": String(e[1]), "a": apps, "g": goals, "as": assists,
		"r": snappedf(rating if apps > 0 else 0.0, 0.01), "o": int(round(o)), "o0": int(round(o0)), "pre": true}
	if lid != "":
		row["l"] = lid
	if bool(e[4]):
		row["lo"] = true
	if Pos.group(p.position) <= Pos.G_DEF and apps > 0:
		row["cs"] = int(round(starts * clampf(0.28 + q * 0.015 + rng.randfn(0.0, 0.05), 0.08, 0.55)))
	if starts > 0:
		row["mo"] = _poisson(rng, starts * clampf(0.03 + (rating - 6.6) * 0.06, 0.0, 0.25))
	return row


static var _rounds_cache := {}


## Rodadas de uma temporada na liga (sem liga no jogo: 34).
static func _rounds(lid: String) -> int:
	if lid == "":
		return 34
	if not _rounds_cache.has(lid):
		var cfg := DatabaseManager.league_cfg(lid)
		_rounds_cache[lid] = clampi((int(cfg.get("teams", 20)) - 1) * int(cfg.get("rr", 2)), 18, 46)
	return _rounds_cache[lid]


static func _poisson(rng: RandomNumberGenerator, lam: float) -> int:
	if lam <= 0.0:
		return 0
	if lam > 30.0:
		return maxi(0, int(round(rng.randfn(lam, sqrt(lam)))))
	var l := exp(-lam)
	var n := 0
	var prod := rng.randf()
	while prod > l:
		n += 1
		prod *= rng.randf()
	return n


# ---------------------------------------------------------------------------
# Prêmios das temporadas passadas
# ---------------------------------------------------------------------------

## Artilheiro, craque e revelação de cada liga em cada ano do passado, entre os jogadores do
## mundo que jogaram nela (os números batem com o que aparece no perfil de cada um).
static func _season_awards(world: GameWorld, ctx: Dictionary) -> void:
	var rows: Dictionary = ctx["rows"]
	var best_world := {} # ano -> [player, nota]
	for key in rows:
		var y := int(String(key).get_slice("|", 0))
		var lid := String(key).get_slice("|", 1)
		var tier := int(DatabaseManager.league_cfg(lid).get("tier", 1))
		if tier != 1:
			continue
		var top_g: Array = []
		var top_r: Array = []
		var top_y: Array = []
		for pr: Array in rows[key]:
			var p: Player = pr[0]
			var row: Dictionary = pr[1]
			if top_g.is_empty() or int(row["g"]) > int(top_g[1]["g"]):
				top_g = pr
			if int(row["a"]) >= 18 and (top_r.is_empty() or float(row["r"]) > float(top_r[1]["r"])):
				top_r = pr
			if p.age(y) <= 21 and int(row["a"]) >= 14 and (top_y.is_empty() or float(row["r"]) > float(top_y[1]["r"])):
				top_y = pr
		if not top_g.is_empty() and int(top_g[1]["g"]) >= 8:
			(top_g[0] as Player).awards.append({"y": y, "k": "scorer", "l": lid})
		if not top_r.is_empty():
			(top_r[0] as Player).awards.append({"y": y, "k": "mvp", "l": lid})
			var lvl := FinanceManager.league_mid_level(DatabaseManager.league_cfg(lid))
			var score := float(top_r[1]["r"]) + lvl * 0.04
			if not best_world.has(y) or score > float(best_world[y][1]):
				best_world[y] = [top_r[0], score]
		if not top_y.is_empty():
			(top_y[0] as Player).awards.append({"y": y, "k": "young", "l": lid})
	# Bola de Ouro do passado: o melhor craque das ligas mais fortes
	for y in best_world:
		(best_world[y][0] as Player).awards.append({"y": int(y), "k": "ballon", "l": ""})
	for p: Player in world.players.values():
		if p.awards.size() > 1:
			p.awards.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]))
