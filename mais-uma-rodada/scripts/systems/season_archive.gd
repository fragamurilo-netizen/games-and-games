class_name SeasonArchive
extends RefCounted
## Arquivo das temporadas passadas: classificação final, líderes estatísticos e o elenco do
## usuário, gravados no fim de cada ano dentro de `world.history` (chaves "arch" e "sq").
## Guarda as ligas do país do usuário, a liga dele e as grandes ligas do mundo — o bastante
## para rever qualquer ano sem inchar o save.

const TOP := 10


## Ligas que entram no arquivo deste ano.
static func leagues_to_keep(world: GameWorld) -> Array:
	var out: Array = []
	var nat := world.user_nation()
	var s := world.season
	for id in s.league_order:
		var league: League = s.leagues[id]
		if league.nation == nat or id == world.user_league_id() or (league.tier == 1 and DatabaseManager.nation(league.nation).get("coef", 0) >= SeasonManager.MAJOR_COEF):
			out.append(id)
	return out


## {liga: {tb: [[club, nome, pts, v, e, d, gp, gc]], sc, as, rt: [[jogador, nome, clube, valor]]}}
static func snapshot_leagues(world: GameWorld) -> Dictionary:
	var out := {}
	for id in leagues_to_keep(world):
		var league: League = world.season.leagues[id]
		var ids := CompetitionManager.sorted_ids(league)
		var tb: Array = []
		for cid in ids:
			var row: Dictionary = league.table[cid]
			tb.append([cid, world.club(cid).short_name, int(row["pts"]), int(row["w"]), int(row["d"]), int(row["l"]), int(row["gf"]), int(row["ga"])])
		out[id] = {"tb": tb, "sc": _leaders(world, id, Player.S_GOALS), "as": _leaders(world, id, Player.S_ASSISTS), "rt": _rating_leaders(world, id, league)}
	return out


static func _leaders(world: GameWorld, league_id: String, stat: int) -> Array:
	var out: Array = []
	for p: Player in CompetitionManager.player_ranking(world, league_id, stat, TOP):
		out.append([p.id, p.display_name(), world.club(p.club_id).short_name, p.stats[stat]])
	return out


static func _rating_leaders(world: GameWorld, league_id: String, league: League) -> Array:
	var min_apps := maxi(5, int(league.rounds.size() * 0.45))
	var arr: Array = []
	for cid in league.club_ids:
		for pid in world.club(cid).player_ids:
			var p := world.player(pid)
			if p != null and p.stats[Player.S_APPS] >= min_apps:
				arr.append(p)
	arr.sort_custom(func(a: Player, b: Player): return a.avg_rating() > b.avg_rating() if a.avg_rating() != b.avg_rating() else a.id < b.id)
	var out: Array = []
	for i in mini(TOP, arr.size()):
		var p: Player = arr[i]
		out.append([p.id, p.display_name(), world.club(p.club_id).short_name, snappedf(p.avg_rating(), 0.01)])
	return out


## Elenco do usuário na temporada: [[id, nome, pos, jogos, gols, assist., nota, overall, variação]].
static func snapshot_squad(world: GameWorld) -> Array:
	var out: Array = []
	if not world.has_user():
		return out
	for p: Player in world.squad(world.user_club()):
		var tot := p.season_totals()
		if int(tot[0]) <= 0:
			continue
		out.append([p.id, p.display_name(), p.position, int(tot[0]), int(tot[1]), int(tot[2]), snappedf(p.avg_rating(), 0.01), p.overall, p.season_delta()])
	out.sort_custom(func(a, b): return int(a[3]) > int(b[3]) if a[3] != b[3] else int(a[0]) < int(b[0]))
	return out


# ---------------------------------------------------------------------------
# Fins de temporada guardados (para rever a tela de fim de temporada de qualquer ano)
# ---------------------------------------------------------------------------

const SUMMARY_KEY := "send"
const MAX_SUMMARIES := 40


## Guarda o resumo do fim de temporada (o mesmo que a tela mostra), sem objetos, por ano.
static func store_summary(world: GameWorld, summary: Dictionary) -> void:
	if summary.is_empty():
		return
	var all: Dictionary = world.stats.get(SUMMARY_KEY, {})
	all[str(int(summary.get("year", world.year)))] = _plain(summary)
	var keys := all.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	while keys.size() > MAX_SUMMARIES:
		all.erase(keys.pop_front())
	world.stats[SUMMARY_KEY] = all


static func summary_of(world: GameWorld, year: int) -> Dictionary:
	return Dictionary(world.stats.get(SUMMARY_KEY, {})).get(str(year), {})


## Anos com fim de temporada guardado, do mais antigo ao mais novo.
static func summary_years(world: GameWorld) -> Array:
	var out: Array = []
	for k in Dictionary(world.stats.get(SUMMARY_KEY, {})).keys():
		out.append(int(k))
	out.sort()
	return out


## Cópia sem objetos (jogador e clube viram o id): o save só grava dados simples.
static func _plain(v: Variant) -> Variant:
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _plain(v[k])
		return d
	if v is Array:
		var a: Array = []
		for x in v:
			a.append(_plain(x))
		return a
	if v is Player:
		return (v as Player).id
	if v is Club:
		return (v as Club).id
	if v is Object:
		return null
	return v
