extends SceneTree
## Uma temporada inteira: quantos clubes foram comprados, viraram SAF, faliram, perderam pontos...


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	var guard := 0
	while not w.season.finished and guard < 400:
		SeasonManager.play_matchday_instant(w)
		guard += 1
	var cnt := {"compra": 0, "saf": 0, "falência": 0, "ban": 0, "portões": 0, "pontos": 0, "presidente": 0}
	var ex := {}
	for c: Club in w.clubs:
		var a: Dictionary = c.affairs
		if a.has("owner") and not a.has("saf"):
			cnt["compra"] += 1
			ex["compra"] = "%s (%s) ← %s" % [c.short_name, c.nation, a["owner"]]
		if a.has("saf"):
			cnt["saf"] += 1
			ex["saf"] = "%s ← %s" % [c.short_name, a["owner"]]
		if a.has("admin"):
			cnt["falência"] += 1
			ex["falência"] = "%s (%s)" % [c.short_name, c.nation]
		if int(a.get("ban", 0)) > 0:
			cnt["ban"] += 1
		if a.has("pres"):
			cnt["presidente"] += 1
		var lg := w.league(c.league_id)
		if lg != null and lg.table.has(c.id) and int(lg.table[c.id].get("ded", 0)) > 0:
			cnt["pontos"] += 1
			ex["pontos"] = "%s (%s) -%d" % [c.short_name, c.nation, int(lg.table[c.id]["ded"])]
	var closed := 0
	var late := 0
	for n: NewsEvent in w.news:
		if n.title.contains("portões fechados"):
			closed += 1
		if n.title.contains("Salários atrasados"):
			late += 1
	print("datas: %d · clubes: %d" % [guard, w.clubs.size()])
	print(cnt)
	print("notícias: portões fechados %d · salários atrasados %d (só as visíveis ao usuário)" % [closed, late])
	for k in ex:
		print("  ex. %s: %s" % [k, ex[k]])
	quit()
