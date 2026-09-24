class_name CompetitionManager
extends RefCounted
## Classificação, desempate, zonas de acesso/rebaixamento e rankings individuais.

const ZONE_NONE := 0
const ZONE_TITLE := 1
const ZONE_PROMOTION := 2
const ZONE_RELEGATION := 3


static func empty_row() -> Dictionary:
	return {"pl": 0, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0, "pts": 0, "form": "", "yc": 0, "rc": 0}


static func init_table(league: League) -> void:
	league.table.clear()
	for cid in league.club_ids:
		league.table[cid] = empty_row()


static func apply_result(league: League, f: Fixture) -> void:
	var comp := DatabaseManager.competitions()
	var pw := int(comp["points_win"])
	var pd := int(comp["points_draw"])
	var h: Dictionary = league.table[f.home]
	var a: Dictionary = league.table[f.away]
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
	var ids: Array = league.club_ids.duplicate()
	var t := league.table
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
	var cfg := DatabaseManager.division_config(league.division)
	var teams := league.club_ids.size()
	if position == 1 and league.division == 0:
		return ZONE_TITLE
	if int(cfg["promoted"]) > 0 and position <= int(cfg["promoted"]):
		return ZONE_PROMOTION
	if int(cfg["relegated"]) > 0 and position > teams - int(cfg["relegated"]):
		return ZONE_RELEGATION
	return ZONE_NONE


static func zone_color(zone: int) -> Color:
	match zone:
		ZONE_TITLE:
			return Color("#FFC940")
		ZONE_PROMOTION:
			return Color("#3DBE7A")
		ZONE_RELEGATION:
			return Color("#E5484D")
	return Color(0, 0, 0, 0)


## Rodadas restantes de um clube na liga.
static func remaining_rounds(league: League, club_id: int) -> int:
	var n := 0
	for r in league.rounds:
		for f in r:
			if f.involves(club_id) and not f.played:
				n += 1
	return n


## Ranking individual de uma divisão: stat_index = Player.S_GOALS, S_ASSISTS...
static func player_ranking(world: GameWorld, division: int, stat_index: int, count: int) -> Array:
	var out: Array = []
	for p in world.players.values():
		if p.club_id < 0:
			continue
		var c: Club = world.clubs[p.club_id]
		if c.division != division:
			continue
		var v: int = p.stats[stat_index]
		if v <= 0:
			continue
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
