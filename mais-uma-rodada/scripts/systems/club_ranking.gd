class_name ClubRanking
extends RefCounted
## Ranking mundial de clubes (no espírito do coeficiente da UEFA): soma dos pontos das últimas
## cinco temporadas, contando a atual ao vivo.
##
## Pontos de uma temporada:
##   liga  → força da liga (coeficiente do país × peso da divisão) × (8 + 32 × posição relativa), +10 × força ao campeão;
##   copas → 2 por vitória, 1 por empate, bônus por participar, por fase de mata-mata e pelo título,
##           tudo multiplicado pelo peso da confederação.
## Temporadas que o save ainda não jogou são preenchidas por uma estimativa a partir da reputação,
## para o ranking fazer sentido desde a primeira rodada.

const SEASONS := 5
const TIER_WEIGHT := [1.0, 0.4, 0.18, 0.08]
const CONFED_WEIGHT := {"UEFA": 1.0, "CONMEBOL": 0.8, "AFC": 0.55, "CONCACAF": 0.5, "CAF": 0.45, "FIFA": 1.0}


## Força de uma liga para o ranking (1.0 = primeira divisão do país mais forte).
static func league_strength(league_id: String) -> float:
	var cfg := DatabaseManager.league_cfg(league_id)
	var coef := float(DatabaseManager.nation(String(cfg.get("nation", ""))).get("coef", 40)) / 100.0
	var tier := clampi(int(cfg.get("tier", 1)), 1, TIER_WEIGHT.size())
	return coef * float(TIER_WEIGHT[tier - 1])


static func league_points(league_id: String, pos: int, teams: int) -> float:
	var s := league_strength(league_id)
	var t := float(teams - pos) / maxf(1.0, teams - 1)
	return s * (8.0 + 32.0 * t) + (10.0 * s if pos == 1 else 0.0)


static func cup_weight(cup_id: String) -> float:
	return float(CONFED_WEIGHT.get(String(CupManager.cfg(cup_id).get("confed", "")), 0.5))


## Pontos de copa da temporada atual para todos os clubes: {club_id: pontos}.
static func cup_points(world: GameWorld) -> Dictionary:
	var out := {}
	if world.season == null:
		return out
	for cid in world.season.cups:
		var cup: Cup = world.season.cups[cid]
		var wgt := cup_weight(cid)
		var bonus := 4.0 if not cup.groups.is_empty() else 2.0
		for club_id in cup.club_ids:
			out[club_id] = float(out.get(club_id, 0.0)) + bonus * wgt
		for f: Fixture in cup.fixtures:
			if not f.played:
				continue
			var ph := 1.0 if f.hg == f.ag else (2.0 if f.hg > f.ag else 0.0)
			var pa := 1.0 if f.hg == f.ag else (2.0 if f.ag > f.hg else 0.0)
			out[f.home] = float(out.get(f.home, 0.0)) + ph * wgt
			out[f.away] = float(out.get(f.away, 0.0)) + pa * wgt
		for t in cup.ties:
			for k in ["a", "b"]:
				var id := int(t[k])
				if id >= 0:
					out[id] = float(out.get(id, 0.0)) + 3.0 * wgt
		if cup.champion >= 0:
			out[cup.champion] = float(out.get(cup.champion, 0.0)) + 8.0 * wgt
	return out


## Pontos de liga da temporada atual (proporcionais aos jogos já disputados).
static func live_league_points(world: GameWorld, club: Club) -> float:
	var league := world.league_of(club.id)
	if league == null or not league.table.has(club.id):
		return 0.0
	var pl := int(league.table[club.id]["pl"])
	if pl <= 0:
		return 0.0
	var teams := league.club_ids.size()
	var total := maxf(1.0, (teams - 1) * int(league.cfg().get("rr", 2)))
	var pos := CompetitionManager.position_of(league, club.id)
	return league_points(club.league_id, pos, teams) * minf(1.0, pl / total)


## Estimativa de uma temporada típica do clube a partir da reputação (preenche o passado).
static func legacy_points(club: Club) -> float:
	var cfg := club.league_cfg()
	var rr: Array = cfg.get("rep", [40, 70])
	var t := clampf((club.reputation - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), 0.0, 1.0)
	var s := league_strength(club.league_id)
	var pts := s * (8.0 + 32.0 * t)
	if club.tier == 1 and club.reputation > 65.0:
		var confed := String(DatabaseManager.nation(club.nation).get("confed", ""))
		pts += (club.reputation - 65.0) * 1.2 * float(CONFED_WEIGHT.get(confed, 0.5))
	return pts


## Pontos no ranking. live = true soma a temporada em andamento às quatro anteriores;
## live = false usa só as cinco temporadas já arquivadas (virada de ano).
static func total(world: GameWorld, club: Club, cups: Dictionary = {}, live: bool = true) -> float:
	var n := SEASONS - 1 if live else SEASONS
	var past: Array = club.rank_hist.slice(maxi(0, club.rank_hist.size() - n))
	var sum := 0.0
	for v in past:
		sum += float(v)
	sum += legacy_points(club) * (n - past.size())
	if live:
		sum += live_league_points(world, club) + float(cups.get(club.id, 0.0))
	return sum


## Ranking ordenado: [{id, pts}]. scope: "" mundo, "C:<confed>" confederação, "N:<nação>" país.
static func table(world: GameWorld, scope: String = "", live: bool = true) -> Array:
	var cups := cup_points(world) if live else {}
	var out: Array = []
	for c: Club in world.clubs:
		if scope.begins_with("N:") and c.nation != scope.substr(2):
			continue
		if scope.begins_with("C:") and String(DatabaseManager.nation(c.nation).get("confed", "")) != scope.substr(2):
			continue
		out.append({"id": c.id, "pts": total(world, c, cups, live)})
	out.sort_custom(func(a, b): return a["pts"] > b["pts"] or (a["pts"] == b["pts"] and a["id"] < b["id"]))
	return out


## Posição mundial de um clube (1 = melhor).
static func world_position(world: GameWorld, club_id: int) -> int:
	var t := table(world)
	for i in t.size():
		if int(t[i]["id"]) == club_id:
			return i + 1
	return 0


## Fim de temporada (antes das mudanças de divisão): arquiva os pontos do ano em cada clube
## e guarda a posição final para mostrar quem subiu e quem caiu no ranking.
static func close_season(world: GameWorld) -> void:
	var cups := cup_points(world)
	for id in world.season.league_order:
		var league: League = world.season.leagues[id]
		var ids := CompetitionManager.sorted_ids(league)
		for i in ids.size():
			var c := world.club(ids[i])
			var pts := league_points(id, i + 1, ids.size()) + float(cups.get(c.id, 0.0))
			c.rank_hist.append(snappedf(pts, 0.1))
			if c.rank_hist.size() > SEASONS:
				c.rank_hist = c.rank_hist.slice(c.rank_hist.size() - SEASONS)
	# Clubes só de estadual: pontuam pelas copas que jogaram
	for id in DatabaseManager.pool_ids():
		var pool: League = world.season.leagues.get(id, null)
		if pool == null:
			continue
		for cid in pool.club_ids:
			var pc := world.club(cid)
			pc.rank_hist.append(snappedf(float(cups.get(pc.id, 0.0)), 0.1))
			if pc.rank_hist.size() > SEASONS:
				pc.rank_hist = pc.rank_hist.slice(pc.rank_hist.size() - SEASONS)
	var t := table(world, "", false)
	for i in t.size():
		world.club(int(t[i]["id"])).rank_prev = i + 1


## Manchetes da virada: quem lidera o mundo e como o clube do usuário terminou o ano.
static func season_news(world: GameWorld) -> void:
	if not world.has_user():
		return
	var leader := -1
	for c: Club in world.clubs:
		if c.rank_prev == 1:
			leader = c.id
			break
	if leader >= 0:
		var lc := world.club(leader)
		NewsManager.post_raw(world, "%s lidera o ranking mundial" % lc.short_name,
			"Com %.1f pontos nas últimas %d temporadas, o %s fecha %d como o melhor clube do planeta." % [total(world, lc, {}, false), SEASONS, lc.name, world.year],
			lc.id, -1, NewsEvent.IMP_NORMAL, "clube")
	var u := world.user_club()
	var prev: Array = world.stats.get("user_rank_prev", [-1, 0])
	var before := int(prev[1]) if int(prev[0]) == u.id else 0
	var now := u.rank_prev
	world.stats["user_rank_prev"] = [u.id, now]
	if before > 0 and now != before:
		var up := now < before
		NewsManager.post_raw(world, "%s %s no ranking mundial" % [u.short_name, "sobe" if up else "cai"],
			"O %s termina %d em %dº no ranking mundial de clubes (era %dº)." % [u.name, world.year, now, before],
			u.id, -1, NewsEvent.IMP_NORMAL, "clube")
