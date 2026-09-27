extends SceneTree
## Confere as seleções da rodada/mês das outras ligas depois de algumas semanas.


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	for i in 60:
		SeasonManager.play_matchday_instant(w)
	for lid in ["ENG1", "ESP1", "ARG1", "GER1", "BRA1"]:
		var t := WeeklyAwards.league_teams(w, lid)
		var tw: Dictionary = t["totw"]
		print("%s: rodada %s · %d meses fechados · craque %s" % [lid, str(tw.get("r", "-")), (t["list"] as Array).size(), w.player(int(tw.get("best", -1))).display_name() if not tw.is_empty() else "-"])
	quit()
