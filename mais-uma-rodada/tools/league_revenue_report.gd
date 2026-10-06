extends SceneTree
## Receita média (e do maior clube) de cada liga, em € milhões, para calibrar com os números reais.
## godot --headless --path . --script res://tools/league_revenue_report.gd


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = -1
	for lid in DatabaseManager.league_ids():
		var cl: Array = w.clubs_in_league(lid)
		if cl.is_empty():
			continue
		var tot := 0.0
		var top := 0.0
		var bill := 0.0
		var name := ""
		for c: Club in cl:
			var rev := float(FinanceManager.expected_revenue(c) + c.income_tv - FinanceManager.tv_income(c))
			tot += rev
			bill += FinanceManager.wage_bill(w, c) * 12.0
			if rev > top:
				top = rev
				name = c.short_name
		print("%s\t%d clubes\tmédia %.1f\tfolha média %.1f\tmaior %.1f (%s)" % [lid, cl.size(), tot / cl.size() / 1e6, bill / cl.size() / 1e6, top / 1e6, name])
	quit()
