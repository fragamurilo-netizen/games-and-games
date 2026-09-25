class_name CompetitionManager
extends RefCounted
## Classificação, desempate, zonas de acesso/rebaixamento e rankings individuais.

const ZONE_NONE := 0
const ZONE_TITLE := 1
const ZONE_PROMOTION := 2
const ZONE_RELEGATION := 3
const ZONE_CONTINENTAL := 4
const ZONE_CONTINENTAL_2 := 5 # Liga Europa, Sul-Americana
const ZONE_CONTINENTAL_3 := 6 # Liga Conferência


static func empty_row() -> Dictionary:
	return {"pl": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0, "form": "", "yc": 0, "rc": 0}


static func init_table(league: League) -> void:
	league.table.clear()
	for cid in league.club_ids:
		league.table[cid] = empty_row()


static func apply_result(league: League, f: Fixture) -> void:
	apply_to_table(league.table, f)


## Soma o resultado de um jogo numa tabela {club_id: linha} (ligas e grupos de copa).
static func apply_to_table(table: Dictionary, f: Fixture) -> void:
	var rules := DatabaseManager.rules()
	var pw := int(rules["points_win"])
	var pd := int(rules["points_draw"])
	var h: Dictionary = table[f.home]
	var a: Dictionary = table[f.away]
	h["pl"] += 1
	a["pl"] += 1
	h["gf"] += f.hg
	h["ga"] += f.ag
	a["gf"] += f.ag
	a["ga"] += f.hg
	if f.hg > f.ag:
		h["w"] += 1
		a["l"] += 1
		h["pts"] += pw
		_push_form(h, "V")
		_push_form(a, "D")
	elif f.hg < f.ag:
		a["w"] += 1
		h["l"] += 1
		a["pts"] += pw
		_push_form(h, "D")
		_push_form(a, "V")
	else:
		h["d"] += 1
		a["d"] += 1
		h["pts"] += pd
		a["pts"] += pd
		_push_form(h, "E")
		_push_form(a, "E")


static func _push_form(row: Dictionary, r: String) -> void:
	var s: String = row["form"] + r
	if s.length() > 5:
		s = s.substr(s.length() - 5)
	row["form"] = s


## Ids ordenados: pontos, vitórias, saldo, gols pró, menos vermelhos, id.
static func sorted_ids(league: League) -> Array:
	return LeagueFormat.sorted_ids(league)


static func sort_table(club_ids: Array, t: Dictionary) -> Array:
	var ids: Array = club_ids.duplicate()
	ids.sort_custom(func(x, y):
		var a: Dictionary = t[x]
		var b: Dictionary = t[y]
		if a["pts"] != b["pts"]:
			return a["pts"] > b["pts"]
		if a["w"] != b["w"]:
			return a["w"] > b["w"]
		var sa: int = a["gf"] - a["ga"]
		var sb: int = b["gf"] - b["ga"]
		if sa != sb:
			return sa > sb
		if a["gf"] != b["gf"]:
			return a["gf"] > b["gf"]
		if a["rc"] != b["rc"]:
			return a["rc"] < b["rc"]
		return x < y)
	return ids


static func position_of(league: League, club_id: int) -> int:
	return sorted_ids(league).find(club_id) + 1


static func zone_of(league: League, position: int) -> int:
	var cfg := league.cfg()
	var teams := league.club_ids.size()
	if position == 1:
		return ZONE_TITLE
	var up := int(cfg.get("up", 0))
	if up > 0 and position <= up:
		return ZONE_PROMOTION
	var down := int(cfg.get("down", 0))
	if down > 0 and position > teams - down:
		return ZONE_RELEGATION
	var cup := CupManager.cup_for_position(league, position)
	if cup != "":
		return [ZONE_CONTINENTAL, ZONE_CONTINENTAL, ZONE_CONTINENTAL_2, ZONE_CONTINENTAL_3][clampi(CupManager.cup_level(cup), 1, 3)]
	return ZONE_NONE


static func zone_color(zone: int) -> Color:
	match zone:
		ZONE_TITLE:
			return Color("#FFC940")
		ZONE_PROMOTION:
			return Color("#3DBE7A")
		ZONE_RELEGATION:
			return Color("#E5484D")
		ZONE_CONTINENTAL:
			return Color("#3D8BFD")
		ZONE_CONTINENTAL_2:
			return Color("#F28C28")
		ZONE_CONTINENTAL_3:
			return Color("#2BB3A3")
	return Color(0, 0, 0, 0)


## Rodadas restantes de um clube na liga.
static func remaining_rounds(league: League, club_id: int) -> int:
	var n := 0
	for r in league.rounds:
		for f in r:
			if f.involves(club_id) and not f.played:
				n += 1
	return n


## Ranking individual de uma liga: stat_index = Player.S_GOALS, S_ASSISTS...
static func player_ranking(world: GameWorld, league_id: String, stat_index: int, count: int) -> Array:
	var out: Array = []
	for c in world.clubs:
		if c.league_id != league_id:
			continue
		for pid in c.player_ids:
			var p: Player = world.players.get(pid, null)
			if p != null and p.stats[stat_index] > 0:
				out.append(p)
	out.sort_custom(func(a, b):
		if a.stats[stat_index] != b.stats[stat_index]:
			return a.stats[stat_index] > b.stats[stat_index]
		return a.stats[Player.S_MINUTES] < b.stats[Player.S_MINUTES])
	return out.slice(0, count)


## Melhor ataque / melhor defesa da divisão.
static func best_attack(league: League) -> int:
	var best := -1
	var best_v := -1
	for cid in league.club_ids:
		var v: int = league.table[cid]["gf"]
		if v > best_v:
			best_v = v
			best = cid
	return best


static func best_defense(league: League) -> int:
	var best := -1
	var best_v := 1 << 30
	for cid in league.club_ids:
		var row: Dictionary = league.table[cid]
		if row["pl"] == 0:
			continue
		var v: int = row["ga"]
		if v < best_v:
			best_v = v
			best = cid
	return best
