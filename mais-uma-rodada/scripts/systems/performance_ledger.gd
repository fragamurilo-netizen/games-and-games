class_name PerformanceLedger
extends RefCounted
## Medidas observadas a partir da 0.5.1. Liga e copas são separadas; seleção/base não entram.
## Uma linha por jogador/clube/competição/ano, sem guardar eventos de todas as partidas.
const KEY := "performance_v1"

static func record(world: GameWorld, fixture: Fixture, result: Dictionary) -> void:
	if not bool(result.get("stats_observed", false)):
		return
	var store: Dictionary = world.stats.get(KEY, {})
	if int(store.get("year", -1)) != world.year:
		store = {"year": world.year, "rows": {}, "seen": {}}
	var match_id := "%s:%d:%d:%d:%d" % [fixture.comp, fixture.slot, fixture.home, fixture.away, fixture.round]
	if store["seen"].has(match_id):
		return
	store["seen"][match_id] = true
	var ps: Dictionary = result.get("pstats", {})
	for side in 2:
		var club_id := fixture.home if side == 0 else fixture.away
		for ln in result["lines"][side]:
			var minutes := int(ln[QuickMatch.L_MINS])
			if minutes <= 0:
				continue
			var p: Player = ln[QuickMatch.L_P]
			var key := "%d:%d:%s" % [club_id, p.id, fixture.comp]
			var row: Dictionary = store["rows"].get(key, {"id": p.id, "club": club_id, "comp": fixture.comp, "league": fixture.is_league(), "n": p.short_name(), "pos": p.position, "apps": 0, "minutes": 0, "goals": 0, "assists": 0, "pen_goals": 0, "xg": 0.0, "xa": 0.0, "pxg": 0.0, "shots": 0, "on": 0, "kp": 0, "saves": 0})
			var v: Array = ps.get(p.id, [0, 0, 0, 0.0, 0, 0.0, 0.0, 0])
			row["apps"] += 1
			row["minutes"] += minutes
			row["goals"] += int(ln[QuickMatch.L_G])
			row["assists"] += int(ln[QuickMatch.L_A])
			for pair in [["shots",0], ["on",1], ["saves",2], ["xg",3], ["kp",4], ["xa",5], ["pxg",6], ["pen_goals",7]]:
				if v.size() > int(pair[1]):
					row[pair[0]] += v[int(pair[1])]
			store["rows"][key] = row
	world.stats[KEY] = store

static func rows(world: GameWorld, club_id: int, league_only: bool = false) -> Array:
	var store: Dictionary = world.stats.get(KEY, {})
	if int(store.get("year", -1)) != world.year:
		return []
	var by_player := {}
	for value in store.get("rows", {}).values():
		var row: Dictionary = value
		if int(row["club"]) != club_id or (league_only and not bool(row["league"])):
			continue
		var pid := int(row["id"])
		if not by_player.has(pid):
			by_player[pid] = row.duplicate()
		else:
			for k in ["apps", "minutes", "goals", "assists", "pen_goals", "xg", "xa", "pxg", "shots", "on", "kp", "saves"]:
				by_player[pid][k] += row[k]
	return by_player.values()

static func per90(value: float, minutes: int) -> float:
	return value * 90.0 / minutes if minutes > 0 else 0.0

static func card(world: GameWorld, club: Club) -> Control:
	var body := UIKit.card("Card", 12)
	body.add_child(UIKit.section_header("Produção por 90 minutos"))
	body.add_child(UIKit.label("Clube · liga + copas · apenas jogos registrados desde a 0.5.1. Seleção e base ficam fora. xG é a qualidade anterior ao chute. xA de finalização soma o xG das chances criadas pelo passe; ambos usam o modelo próprio do jogo.", "Small", true))
	var data := rows(world, club.id)
	data.sort_custom(func(a,b): return int(a["minutes"]) > int(b["minutes"]))
	if data.is_empty():
		body.add_child(UIKit.label("Os indicadores aparecem após a primeira partida nesta versão. O histórico antigo não é inventado.", "Muted", true))
	for row: Dictionary in data.slice(0, 18):
		var mins := int(row["minutes"])
		var group := UIKit.vbox(4)
		group.add_child(UIKit.label("%s · %d min%s" % [row["n"], mins, " · amostra pequena" if mins < 450 else ""], "H3", true))
		group.add_child(UIKit.label("G/90 %.2f   A/90 %.2f   npxG/90 %.2f   xA/90 %.2f" % [per90(float(row["goals"]), mins), per90(float(row["assists"]), mins), per90(maxf(0.0, float(row["xg"])-float(row["pxg"])), mins), per90(float(row["xa"]), mins)], "Small", true))
		group.add_child(UIKit.label("%d gols (%d pên.) · %d assist. · %d chutes · %d no alvo · %d passes decisivos" % [row["goals"], row["pen_goals"], row["assists"], row["shots"], row["on"], row["kp"]], "Small", true))
		body.add_child(group)
	return UIKit.card_panel(body)
