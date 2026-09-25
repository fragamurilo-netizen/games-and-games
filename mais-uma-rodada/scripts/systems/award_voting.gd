class_name AwardVoting
extends RefCounted
## Premiações votadas, como na vida real: indicados anunciados antes do fim, júri com viés e pontos.
##   Bola de Ouro: 30 indicados; um jornalista de cada país ranqueia 10 (15-12-10-8-7-5-4-3-2-1).
##     Pesam a temporada, os títulos (do clube e da seleção, incluindo o torneio de verão), o nível
##     da liga e a fama. Jornalista puxa um pouco para o próprio país e para a própria liga.
##   Craque do campeonato: 5 finalistas; os técnicos da liga votam em 3 (5-3-1) e ninguém vota no
##     próprio elenco. Treinador da temporada: mesmo júri, julgando o que o time fez acima do esperado.
##   Luva de Ouro (liga), melhor goleiro do mundo, treinador do ano e seleção do ano (mundo).
## Todo prêmio vira registro em world.history[i]["aw"] e é consultado por records() — a porta de
## entrada para a enciclopédia do save (inclui os anos anteriores gravados no formato antigo).

const BALLON_POINTS: Array[int] = [15, 12, 10, 8, 7, 5, 4, 3, 2, 1]
const JURY_POINTS: Array[int] = [5, 3, 1]
const BALLON_NOMINEES := 30
const FINALISTS := 5
## Fração da liga do usuário jogada quando saem os indicados.
const NOMINEE_AT := 0.8

## Prêmios que não são de jogador (o registro leva o técnico em vez do jogador).
const COACH_KEYS: Array[String] = ["coach", "coach_world"]


static func _rng(world: GameWorld, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, world.year * 131 + salt, 777001)
	return r


# ---------------------------------------------------------------------------
# Méritos
# ---------------------------------------------------------------------------

static func _league_level(league_id: String) -> float:
	return float(DatabaseManager.league_cfg(league_id).get("level", [60, 70])[1])


## Peso dos títulos do ano (clube e seleção). Título grande decide Bola de Ouro.
static func title_bonus(world: GameWorld, p: Player) -> float:
	var b := 0.0
	for t: Dictionary in p.trophies:
		if int(t.get("y", 0)) != world.year:
			continue
		var k := String(t.get("k", ""))
		var id := k.substr(2)
		match k.substr(0, 2):
			"L:":
				var tier := int(DatabaseManager.league_cfg(id).get("tier", 1))
				b += clampf((_league_level(id) - 62.0) * 0.35, 1.0, 6.0) if tier == 1 else 1.0
			"C:":
				b += [0.0, 8.0, 4.0, 2.5][clampi(CupManager.cup_level(id), 1, 3)]
			"W:":
				b += 3.0
			"D:":
				b += 1.5
			"U:", "S:":
				b += 0.4
			"N:":
				b += 12.0 if id == "WC" else (8.0 if id in ["EURO", "CA"] else 4.0)
	return b


## Bônus do torneio de seleções do verão: finalistas, semifinalistas e artilheiro.
static func summer_bonus(summer: Array) -> Dictionary:
	var out := {}
	for rec: Dictionary in summer:
		var big := 1.0 if String(rec.get("t", "")) == "WC" else (0.7 if String(rec.get("t", "")) in ["EURO", "CA"] else 0.4)
		var sc: Dictionary = rec.get("scorer", {})
		if not sc.is_empty():
			out[int(sc["id"])] = float(out.get(int(sc["id"]), 0.0)) + 4.0 * big
	return out


## Mérito de temporada para a Bola de Ouro (e para a seleção do ano).
static func ballon_merit(world: GameWorld, p: Player, extra: Dictionary = {}) -> float:
	if p.club_id < 0:
		return -1.0
	var tot := p.season_totals()
	if int(tot[0]) < 18:
		return -1.0
	var c: Club = world.clubs[p.club_id]
	var v := p.avg_rating() * 10.0 + int(tot[1]) * 0.3 + int(tot[2]) * 0.18 + (_league_level(c.league_id) - 70.0) * 0.5 + p.overall * 0.35
	if Pos.group(p.position) == Pos.G_GK:
		v += p.stats[Player.S_CLEAN] * 0.3 + p.stats[Player.S_SAVES] * 0.015
	elif Pos.group(p.position) == Pos.G_DEF:
		v += p.stats[Player.S_CLEAN] * 0.12 + (p.stats[Player.S_TACKLES] + p.stats[Player.S_INTERCEPTIONS]) * 0.01
	for k in p.cup_stats:
		v += int(p.cup_stats[k][Player.C_GOALS]) * 0.12
	v += title_bonus(world, p) + float(extra.get(p.id, 0.0))
	return v


## Mérito de um técnico na temporada: o que o time fez acima do esperado, títulos e aproveitamento.
static func coach_merit(world: GameWorld, league: League, club_id: int, pos: int) -> float:
	var row: Dictionary = league.table[club_id]
	var pl := maxi(1, int(row["pl"]))
	var exp := SeasonManager.expected_rank(world, club_id, league.club_ids.size())
	var v := (exp - pos) * 1.3 + float(row["pts"]) / pl * 3.0
	if pos == 1:
		v += 6.0
	elif pos <= league.promoted_count() and league.tier > 1:
		v += 3.0
	for cid in world.season.cups:
		var cup: Cup = world.season.cups[cid]
		if cup.champion == club_id:
			v += 5.0 if CupManager.is_international(cid) else 2.5
	return v


# ---------------------------------------------------------------------------
# Votação genérica
# ---------------------------------------------------------------------------

## cands: [{id, m (mérito), ...}]; bias(voter_index, cand) -> float (-INF = não pode votar nele).
## Cada eleitor ordena por mérito + viés + ruído e distribui `points`. Retorna os candidatos com
## "pts" e "first" (votos de primeiro lugar), do mais votado ao menos.
static func vote(r: RandomNumberGenerator, cands: Array, n_voters: int, points: Array, sd: float, bias: Callable) -> Array:
	var tally := {}
	var firsts := {}
	for c: Dictionary in cands:
		tally[c["id"]] = 0
		firsts[c["id"]] = 0
	for vi in n_voters:
		var ranked: Array = []
		for c: Dictionary in cands:
			var b: float = bias.call(vi, c)
			if b == -INF:
				continue
			ranked.append([c["id"], float(c["m"]) + b + RngUtil.gauss(r, 0.0, sd)])
		ranked.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else str(a[0]) < str(b[0]))
		for i in mini(points.size(), ranked.size()):
			tally[ranked[i][0]] = int(tally[ranked[i][0]]) + int(points[i])
			if i == 0:
				firsts[ranked[i][0]] = int(firsts[ranked[i][0]]) + 1
	var out: Array = []
	for c: Dictionary in cands:
		var d := c.duplicate()
		d["pts"] = int(tally[c["id"]])
		d["first"] = int(firsts[c["id"]])
		out.append(d)
	out.sort_custom(func(a, b):
		if a["pts"] != b["pts"]:
			return int(a["pts"]) > int(b["pts"])
		if a["first"] != b["first"]:
			return int(a["first"]) > int(b["first"])
		return float(a["m"]) > float(b["m"]))
	return out


## Países com jornalista no júri mundial (os que têm liga ou seleção nos dados).
static func jury_nations() -> Array:
	var out: Array = []
	var ns := DatabaseManager.nations()
	for code in ns:
		if ns[code] is Dictionary and ns[code].has("confed"):
			out.append(String(code))
	out.sort()
	return out


# ---------------------------------------------------------------------------
# Indicados (anunciados com a temporada ainda em curso)
# ---------------------------------------------------------------------------

## Os `n` melhores pelo mérito da Bola de Ouro (jogadores com liga, 18+ jogos, overall 70+).
static func ballon_candidates(world: GameWorld, n: int, max_age: int = 99, only_gk: bool = false, extra: Dictionary = {}) -> Array:
	var arr: Array = []
	for p: Player in world.players.values():
		if p.overall < (60 if max_age <= 21 else 70) or p.age(world.year) > max_age:
			continue
		if only_gk and Pos.group(p.position) != Pos.G_GK:
			continue
		var m := ballon_merit(world, p, extra)
		if m > 0.0:
			arr.append([p, m])
	arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else (a[0] as Player).id < (b[0] as Player).id)
	return arr.slice(0, n)


## Finalistas de craque da liga pela nota de premiação.
static func league_finalists(world: GameWorld, league_id: String, n: int = FINALISTS, max_age: int = 99) -> Array:
	var league: League = world.season.leagues.get(league_id, null)
	if league == null:
		return []
	var min_apps := maxi(5, int(league.rounds.size() * 0.45 * league.rounds_played() / maxf(1.0, league.rounds.size())))
	var arr: Array = []
	for cid in league.club_ids:
		for pid in world.club(cid).player_ids:
			var p := world.player(pid)
			if p == null or p.stats[Player.S_APPS] < min_apps or p.age(world.year) > max_age:
				continue
			arr.append([p, AwardManager.score(p) + title_bonus(world, p) * 0.02])
	arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else (a[0] as Player).id < (b[0] as Player).id)
	var out: Array = []
	for i in mini(n, arr.size()):
		out.append((arr[i][0] as Player).id)
	return out


## Finalistas de treinador da liga (clubes).
static func coach_finalists(world: GameWorld, league_id: String, n: int = 3) -> Array:
	var league: League = world.season.leagues.get(league_id, null)
	if league == null:
		return []
	var ids := CompetitionManager.sorted_ids(league)
	var arr: Array = []
	for i in ids.size():
		arr.append([ids[i], coach_merit(world, league, ids[i], i + 1)])
	arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else int(a[0]) < int(b[0]))
	return arr.slice(0, n).map(func(x): return int(x[0]))


## Chamado depois de cada data: quando a liga do usuário passa de NOMINEE_AT, saem os indicados
## da Bola de Ouro e os finalistas da liga (uma vez por ano, com notícia).
static func maybe_announce(world: GameWorld) -> void:
	if not world.has_user():
		return
	var nom: Dictionary = world.stats.get("aw_nom", {})
	if int(nom.get("y", 0)) == world.year:
		return
	var lid := world.user_league_id()
	var league: League = world.season.leagues.get(lid, null)
	if league == null or league.rounds.is_empty() or league.rounds_played() < int(ceil(league.rounds.size() * NOMINEE_AT)):
		return
	var bo: Array = ballon_candidates(world, BALLON_NOMINEES).map(func(x): return (x[0] as Player).id)
	nom = {"y": world.year, "l": lid, "bo": bo, "mvp": league_finalists(world, lid), "young": league_finalists(world, lid, 3, 21),
		"coach": coach_finalists(world, lid)}
	world.stats["aw_nom"] = nom
	var user := world.user_club()
	# Bola de Ouro
	if not bo.is_empty():
		var names: Array = []
		var mine: Array = []
		var local: Array = []
		for pid in bo:
			var p := world.player(int(pid))
			if p == null:
				continue
			if names.size() < 6:
				names.append(p.display_name())
			if p.club_id == user.id:
				mine.append(p.display_name())
			elif p.nationality == user.nation and local.size() < 3:
				local.append(p.display_name())
		var body := "A lista tem %d nomes. Entre os favoritos: %s." % [bo.size(), ", ".join(names)]
		if not local.is_empty():
			body += " Do país: %s." % ", ".join(local)
		body += " O vencedor sai da votação de jornalistas de %d países no fim da temporada." % jury_nations().size()
		var title := "Saem os %d indicados à Bola de Ouro" % bo.size()
		if not mine.is_empty():
			title = "%s entre os indicados à Bola de Ouro" % (mine[0] if mine.size() == 1 else "%d jogadores do %s" % [mine.size(), user.short_name])
		NewsManager.post_raw(world, title, body, user.id if not mine.is_empty() else -1, -1,
			NewsEvent.IMP_HIGH if not mine.is_empty() else NewsEvent.IMP_NORMAL, "premio")
	# Liga do usuário
	var fin: Array = nom["mvp"].map(func(pid): return world.player(int(pid))).filter(func(p): return p != null)
	if not fin.is_empty():
		var parts: Array = fin.map(func(p: Player): return "%s (%s)" % [p.display_name(), world.club(p.club_id).short_name])
		var ours: Array = fin.filter(func(p: Player): return p.club_id == user.id)
		NewsManager.post_raw(world, "Finalistas de craque da %s: %s" % [league.name, ", ".join(fin.slice(0, 3).map(func(p: Player): return p.display_name()))],
			"Os técnicos da liga votam no fim da temporada, sem poder escolher o próprio elenco. Concorrem: %s." % ", ".join(parts),
			user.id if not ours.is_empty() else -1, -1, NewsEvent.IMP_HIGH if not ours.is_empty() else NewsEvent.IMP_NORMAL, "premio")
	if Array(nom["coach"]).has(user.id):
		NewsManager.post_raw(world, "%s é finalista de treinador da temporada" % world.manager_name,
			"O trabalho no %s entrou na lista final da %s ao lado de %s." % [user.short_name, league.name,
				" e ".join(Array(nom["coach"]).filter(func(cid): return int(cid) != user.id).map(func(cid): return People.coach_name(world, int(cid))))],
			user.id, -1, NewsEvent.IMP_HIGH, "premio")


static func _nominees(world: GameWorld, key: String, league_id: String = "") -> Array:
	var nom: Dictionary = world.stats.get("aw_nom", {})
	if int(nom.get("y", 0)) != world.year or (league_id != "" and String(nom.get("l", "")) != league_id):
		return []
	return Array(nom.get(key, [])).filter(func(pid): return world.player(int(pid)) != null and world.player(int(pid)).club_id >= 0)


# ---------------------------------------------------------------------------
# Votações de fim de temporada
# ---------------------------------------------------------------------------

## Craque do campeonato votado pelos técnicos da liga. Retorna [{id, m, pts, first}] (vazio sem candidatos).
static func league_mvp_vote(world: GameWorld, league_id: String, max_age: int = 99) -> Array:
	var league: League = world.season.leagues[league_id]
	var key := "young" if max_age <= 21 else "mvp"
	var ids: Array = _nominees(world, key, league_id)
	if ids.size() < 2:
		ids = league_finalists(world, league_id, FINALISTS if max_age > 21 else 3, max_age)
	if ids.is_empty():
		return []
	var cands: Array = []
	for pid in ids:
		var p := world.player(int(pid))
		cands.append({"id": p.id, "m": AwardManager.score(p) * 10.0 + title_bonus(world, p) * 0.4, "c": p.club_id})
	var voters: Array = league.club_ids.duplicate()
	var r := _rng(world, league_id.hash() % 9973 + (1 if max_age <= 21 else 0))
	return vote(r, cands, voters.size(), JURY_POINTS, 1.2, func(vi: int, c: Dictionary) -> float:
		return -INF if int(c["c"]) == int(voters[vi]) else 0.0)


## Treinador da temporada de uma liga: {co (id do técnico, -1 = usuário), n, c, cn, nat, pts, m} ou {}.
static func league_coach_vote(world: GameWorld, league_id: String) -> Dictionary:
	var league: League = world.season.leagues[league_id]
	var ids := CompetitionManager.sorted_ids(league)
	if ids.size() < 4 or league.rounds_played() == 0:
		return {}
	var fin: Array = []
	var nom: Dictionary = world.stats.get("aw_nom", {})
	if int(nom.get("y", 0)) == world.year and String(nom.get("l", "")) == league_id:
		fin = Array(nom.get("coach", [])).filter(func(cid): return league.club_ids.has(int(cid)))
	if fin.size() < 2:
		fin = coach_finalists(world, league_id)
	var cands: Array = []
	for cid in fin:
		cands.append({"id": int(cid), "m": coach_merit(world, league, int(cid), ids.find(int(cid)) + 1)})
	var r := _rng(world, league_id.hash() % 9973 + 5)
	var res := vote(r, cands, ids.size(), JURY_POINTS, 1.5, func(vi: int, c: Dictionary) -> float:
		return -INF if int(c["id"]) == int(ids[vi]) else 0.0)
	if res.is_empty():
		return {}
	var w: Dictionary = res[0]
	var club := world.club(int(w["id"]))
	var co := People.coach_of(world, club.id)
	var pos := ids.find(club.id) + 1
	return {"co": int(co.get("id", -1)), "n": People.coach_name(world, club.id), "c": club.id, "cn": club.short_name,
		"nat": String(co.get("nat", club.nation)) if not co.is_empty() else club.nation, "pts": int(w["pts"]), "m": float(w["m"]),
		"v": "%dº lugar · %d pts" % [pos, int(league.table[club.id]["pts"])], "user": world.is_user_club(club.id),
		"fin": res.map(func(x): return [int(x["id"]), int(x["pts"])])}


## Bola de Ouro: votação do júri mundial sobre os indicados. `summer`: torneios do verão (pesam).
## Retorna o ranking [{id, name, club, nat, goals, apps, pts, first}] (10 primeiros).
static func ballon_vote(world: GameWorld, summer: Array = [], n: int = 10) -> Array:
	var extra := summer_bonus(summer)
	var ids: Array = _nominees(world, "bo")
	# Quem brilhou no torneio de verão entra na lista mesmo sem ter sido indicado.
	for x in ballon_candidates(world, 8, 99, false, extra):
		if not ids.has((x[0] as Player).id):
			ids.append((x[0] as Player).id)
	if ids.size() < 12:
		ids = ballon_candidates(world, BALLON_NOMINEES, 99, false, extra).map(func(x): return (x[0] as Player).id)
	return _world_vote(world, ids, extra, 11, n)


## Revelação mundial (até 21 anos) e melhor goleiro do mundo: mesma votação, lista própria.
static func world_young_vote(world: GameWorld, summer: Array = []) -> Array:
	var extra := summer_bonus(summer)
	return _world_vote(world, ballon_candidates(world, 10, 21, false, extra).map(func(x): return (x[0] as Player).id), extra, 12, 5)


static func gk_vote(world: GameWorld, summer: Array = []) -> Array:
	var extra := summer_bonus(summer)
	return _world_vote(world, ballon_candidates(world, 10, 99, true, extra).map(func(x): return (x[0] as Player).id), extra, 13, 5)


static func _world_vote(world: GameWorld, ids: Array, extra: Dictionary, salt: int, n: int) -> Array:
	var cands: Array = []
	for pid in ids:
		var p := world.player(int(pid))
		if p == null or p.club_id < 0:
			continue
		var m := ballon_merit(world, p, extra)
		if m <= 0.0:
			continue
		cands.append({"id": p.id, "m": m, "nat": p.nationality, "ln": world.club(p.club_id).nation})
	if cands.is_empty():
		return []
	var jury := jury_nations()
	var res := vote(_rng(world, salt), cands, jury.size(), BALLON_POINTS, 2.2, func(vi: int, c: Dictionary) -> float:
		var b := 0.0
		if String(c["nat"]) == String(jury[vi]):
			b += 2.5
		if String(c["ln"]) == String(jury[vi]):
			b += 1.0
		return b)
	var out: Array = []
	for i in mini(n, res.size()):
		var p := world.player(int(res[i]["id"]))
		var tot := p.season_totals()
		out.append({"id": p.id, "name": p.display_name(), "full": p.first_name + " " + p.last_name, "club": world.club(p.club_id).short_name,
			"nat": p.nationality, "goals": int(tot[1]), "apps": int(tot[0]), "pts": int(res[i]["pts"]), "first": int(res[i]["first"]), "votes": jury.size()})
	return out


## Treinador do ano: os treinadores da temporada das ligas fortes e os campeões continentais.
static func world_coach_vote(world: GameWorld, league_coaches: Dictionary) -> Dictionary:
	var cands: Array = []
	var seen := {}
	for lid in league_coaches:
		var lc: Dictionary = league_coaches[lid]
		if lc.is_empty() or int(DatabaseManager.league_cfg(lid).get("tier", 1)) != 1 or _league_level(lid) < 70.0:
			continue
		seen[int(lc["c"])] = true
		cands.append({"id": int(lc["c"]), "m": float(lc["m"]) + (_league_level(lid) - 70.0) * 0.4, "nat": String(lc["nat"]), "d": lc})
	for cid in world.season.cups:
		var cup: Cup = world.season.cups[cid]
		if CupManager.is_international(cid) and CupManager.cup_level(cid) == 1 and cup.champion >= 0 and not seen.has(cup.champion):
			var club := world.club(cup.champion)
			if club == null:
				continue
			var co := People.coach_of(world, club.id)
			seen[club.id] = true
			var league := world.league_of(club.id)
			var m := 8.0 + (_league_level(club.league_id) - 70.0) * 0.4
			if league != null:
				m += coach_merit(world, league, club.id, CompetitionManager.position_of(league, club.id))
			cands.append({"id": club.id, "m": m, "nat": String(co.get("nat", club.nation)) if not co.is_empty() else club.nation,
				"d": {"co": int(co.get("id", -1)), "n": People.coach_name(world, club.id), "c": club.id, "cn": club.short_name,
					"nat": String(co.get("nat", club.nation)) if not co.is_empty() else club.nation, "user": world.is_user_club(club.id),
					"v": "Campeão da %s" % CupManager.cup_name(cid)}})
	if cands.size() < 2:
		return {}
	var jury := jury_nations()
	var res := vote(_rng(world, 14), cands, jury.size(), JURY_POINTS, 2.0, func(vi: int, c: Dictionary) -> float:
		return 1.5 if String(c["nat"]) == String(jury[vi]) else 0.0)
	var out: Dictionary = Dictionary(res[0]["d"]).duplicate()
	out["pts"] = int(res[0]["pts"])
	return out


## Seleção do ano (mundo): os melhores por setor no formato da seleção do campeonato.
static func world_xi(world: GameWorld, summer: Array = []) -> Array:
	var extra := summer_bonus(summer)
	var groups: Array = [[], [], [], []]
	for p: Player in world.players.values():
		if p.overall < 72:
			continue
		var m := ballon_merit(world, p, extra)
		if m > 0.0:
			groups[Pos.group(p.position)].append([p.id, m])
	var ids: Array = []
	for gi in 4:
		var arr: Array = groups[gi]
		arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else int(a[0]) < int(b[0]))
		for i in mini(AwardManager.TEAM_SHAPE[gi], arr.size()):
			ids.append(int(arr[i][0]))
	return ids if ids.size() == 11 else []


## Luva de Ouro de cada liga: goleiro com mais jogos sem sofrer gols (desempate: menos jogos, nota).
static func golden_gloves(world: GameWorld) -> Dictionary:
	var best := {}
	for p: Player in world.players.values():
		if p.club_id < 0 or Pos.group(p.position) != Pos.G_GK:
			continue
		var cs := p.stats[Player.S_CLEAN]
		if cs <= 0 or p.stats[Player.S_APPS] < 5:
			continue
		var lid: String = world.clubs[p.club_id].league_id
		var cur: Array = best.get(lid, [])
		if cur.is_empty() or cs > int(cur[1]) or (cs == int(cur[1]) and (p.stats[Player.S_APPS] < (cur[0] as Player).stats[Player.S_APPS]
				or (p.stats[Player.S_APPS] == (cur[0] as Player).stats[Player.S_APPS] and p.id < (cur[0] as Player).id))):
			best[lid] = [p, cs]
	var out := {}
	for lid in best:
		var p: Player = best[lid][0]
		out[lid] = {"id": p.id, "name": p.display_name(), "club": world.club(p.club_id).short_name, "v": "%d sem sofrer gol" % int(best[lid][1])}
	return out


# ---------------------------------------------------------------------------
# Registro e consulta (enciclopédia)
# ---------------------------------------------------------------------------

## Registro de um prêmio: {k, l, pos, id (jogador, -1 se técnico), co (técnico, -1 = usuário ou jogador),
## n (nome), c (clube), cn (nome do clube), nat, v (texto), pts}.
static func rec(k: String, l: String, pos: int, d: Dictionary, world: GameWorld) -> Dictionary:
	var pid := int(d.get("id", -1)) if not COACH_KEYS.has(k) else -1
	var p := world.player(pid) if pid >= 0 else null
	var cid := int(d.get("c", p.club_id if p != null else -1))
	var cl := world.club(cid) if cid >= 0 else null
	return {"k": k, "l": l, "pos": pos, "id": pid, "co": int(d.get("co", -1)) if COACH_KEYS.has(k) else -1,
		"n": String(d.get("n", d.get("name", p.display_name() if p != null else ""))),
		"c": cid, "cn": String(d.get("cn", d.get("club", cl.short_name if cl != null else ""))),
		"nat": String(d.get("nat", p.nationality if p != null else "")), "v": str(d.get("v", "")), "pts": int(d.get("pts", 0)),
		"user": bool(d.get("user", false))}


## Todos os prêmios de uma temporada num registro plano (gravado em world.history[i]["aw"]).
static func season_ledger(world: GameWorld, awards: Dictionary, extra: Dictionary, coaches: Dictionary, bo_rank: Array,
		wy_rank: Array, gk_rank: Array, wcoach: Dictionary, months: Array) -> Array:
	var out: Array = []
	for lid in awards:
		for k in awards[lid]:
			var a: Dictionary = awards[lid][k]
			out.append(rec(String(k), String(lid), 1, a, world))
			# Finalistas votados também ficam (2º e 3º), como nas listas oficiais.
			var fin: Array = a.get("fin", [])
			for i in range(1, mini(3, fin.size())):
				out.append(rec(String(k), String(lid), i + 1, {"id": int(fin[i][0]), "pts": int(fin[i][1])}, world))
	for lid in extra.get("teams", {}):
		for pid in extra["teams"][lid]:
			out.append(rec("team", String(lid), 1, {"id": int(pid)}, world))
	for cid in extra.get("cups", {}):
		out.append(rec("cup_mvp", String(cid), 1, extra["cups"][cid], world))
	for lid in coaches:
		var co: Dictionary = coaches[lid]
		if co.is_empty():
			continue
		out.append(rec("coach", String(lid), 1, co, world))
	for pair in [["ballon", bo_rank], ["world_young", wy_rank], ["gk_world", gk_rank]]:
		var rk: Array = pair[1]
		for i in mini(3 if pair[0] != "ballon" else rk.size(), rk.size()):
			out.append(rec(String(pair[0]), "", i + 1, rk[i], world))
	for k in ["boot"]:
		var d: Dictionary = extra.get(k, {})
		if not d.is_empty():
			out.append(rec(k, "", 1, d, world))
	for pid in extra.get("world_xi", []):
		out.append(rec("world_xi", "", 1, {"id": int(pid)}, world))
	if not wcoach.is_empty():
		out.append(rec("coach_world", "", 1, wcoach, world))
	var cp: Dictionary = extra.get("club", {})
	if not cp.is_empty():
		out.append(rec("club", str(world.user_club_id), 1, cp, world))
	for m: Dictionary in months:
		if int(m.get("best", -1)) >= 0:
			out.append(rec("potm", world.user_league_id(), 1, {"id": int(m["best"]), "v": WeeklyAwards.month_label(int(m["m"]))}, world))
	return out


## Consulta os prêmios de todas as temporadas gravadas. Filtros opcionais: k (prêmio), l (liga ou
## copa), id (jogador), co (técnico), c (clube), nat, y (ano), user (true = só os do treinador do
## usuário), pos (1 = só vencedores). Retorna registros com "y", do mais antigo ao mais novo.
static func records(world: GameWorld, f: Dictionary = {}) -> Array:
	var out: Array = []
	for h: Dictionary in world.history:
		if h.get("pre", false):
			continue
		var y := int(h.get("y", 0))
		if f.has("y") and int(f["y"]) != y:
			continue
		var list: Array = h["aw"] if h.has("aw") else legacy_records(world, h)
		for r: Dictionary in list:
			if f.has("k") and String(f["k"]) != String(r["k"]):
				continue
			if f.has("l") and String(f["l"]) != String(r["l"]):
				continue
			if f.has("id") and int(f["id"]) != int(r["id"]):
				continue
			if f.has("co") and int(f["co"]) != int(r.get("co", -1)):
				continue
			if f.has("c") and int(f["c"]) != int(r["c"]):
				continue
			if f.has("nat") and String(f["nat"]) != String(r["nat"]):
				continue
			if f.has("user") and bool(f["user"]) != bool(r.get("user", false)):
				continue
			if f.has("pos") and int(f["pos"]) != int(r.get("pos", 1)):
				continue
			var d := r.duplicate()
			d["y"] = y
			out.append(d)
	return out


## Vencedores de um prêmio ano a ano (atalho de records).
static func winners(world: GameWorld, k: String, l: String = "") -> Array:
	var f := {"k": k, "pos": 1}
	if l != "":
		f["l"] = l
	return records(world, f)


## Converte um ano gravado antes da votação (sem "aw") em registros.
static func legacy_records(world: GameWorld, h: Dictionary) -> Array:
	var out: Array = []
	var leagues: Dictionary = h.get("leagues", {})
	for lid in leagues:
		var aw: Dictionary = leagues[lid].get("awards", {})
		for k in aw:
			out.append(rec(String(k), String(lid), 1, aw[k], world))
		for pid in leagues[lid].get("team", []):
			out.append(rec("team", String(lid), 1, {"id": int(pid)}, world))
	var cups: Dictionary = h.get("cups", {})
	for cid in cups:
		var mvp: Dictionary = cups[cid].get("mvp", {})
		if not mvp.is_empty():
			out.append(rec("cup_mvp", String(cid), 1, mvp, world))
	for pair in [["ballon", "ballon"], ["wy", "world_young"], ["boot", "boot"]]:
		var d: Dictionary = h.get(pair[0], {})
		if not d.is_empty():
			out.append(rec(pair[1], "", 1, d, world))
	var cp: Dictionary = h.get("cp", {})
	if not cp.is_empty():
		out.append(rec("club", str(h.get("club", -1)), 1, cp, world))
	return out
