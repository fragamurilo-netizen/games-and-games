extends SceneTree
## Uma temporada e a revisão anual: quantos floresceram tarde, explodiram cedo e descarrilharam.


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	var guard := 0
	while not w.season.finished and guard < 400:
		SeasonManager.play_matchday_instant(w)
		guard += 1
	var r := PlayerDevelopment.yearly_review(w)
	for k in ["explosions", "busts", "late", "derail"]:
		var arr: Array = r[k]
		var ex := ""
		for p: Player in arr.slice(0, 4):
			var c := w.club(p.club_id)
			ex += "%s (%d, %d→pot %d, %s) · " % [p.display_name(), p.age(w.year), p.overall, p.potential, c.short_name if c != null else "-"]
		print("%-10s %4d  %s" % [k, arr.size(), ex])
	quit()
