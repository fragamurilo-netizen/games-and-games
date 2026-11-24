extends SceneTree
## Gera um save (JSON) de uma carreira de teste com N semanas, para testar a migração.
func _initialize() -> void:
	var out := "/tmp/save.json"
	var weeks := 40
	var role := "empresario"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--weeks="):
			weeks = int(a.substr(8))
		elif a.begins_with("--role="):
			role = a.substr(7)
	var w: GameWorld
	if role == "presidente":
		w = Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	else:
		w = Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 500000.0, 2027)
		var y := w.year()
		var m := w.month()
		var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
		pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
		for f: Fighter in [pros[2], pros[5], pros[9]]:
			f.team_id = w.user_team_id
			f.contract = {"cut": 0.2, "fights": 8}
		StaffMarket.hire(w, w.staff_market[0])
	for i in weeks:
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(w.to_dict()))
	f.close()
	print("save escrito: ", out, " semana ", w.week, " lutadores ", w.fighters.size())
	quit()
