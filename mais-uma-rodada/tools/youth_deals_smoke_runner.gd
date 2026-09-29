extends Node
## Lógica de youth_deals_smoke.gd (carregada depois dos autoloads).


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club: Club = w.clubs_in_league("BRA1")[0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--club="):
			for c: Club in w.clubs:
				if c.name.to_lower().contains(a.substr(7).to_lower()):
					club = c
					break
	w.user_club_id = club.id
	YouthManager.ensure_academy(w)
	YouthManager.build_league(w)
	print("clube: %s (%s) · base %d · calendário %d datas" % [club.name, club.league_id, club.youth_level, w.season.calendar.size()])
	for k in YouthCups.keys(w):
		var d := YouthCups.comp(w, k)
		var slots: Array = []
		for r in d["rounds"]:
			slots.append(int(r["slot"]))
		print("  %s: %s · %d times · usuário: %s · datas %s" % [k, d["name"], d["teams"].size(), str(d["user_in"]), str(slots)])
	var kid: Player = YouthManager.academy(w)[0]
	YouthAcademy.set_plan(w, kid, "finalizacao", 2)
	for slot in w.season.calendar.size():
		if not w.season.is_weekend(slot):
			continue
		w.season.day = slot
		YouthManager.weekly(w)
		YouthManager.play_slot(w, slot)
	var fin := YouthManager.finish_league(w)
	for e in fin.get("cups", []):
		var ch: Variant = e["champion"]
		var cname := DatabaseManager.nation_name(String(ch)) if ch is String else w.club(int(ch)).short_name
		print("  fim %s: campeão %s · usuário: %s" % [e["name"], cname, e.get("user", "-")])
		var d := YouthCups.comp(w, String(e["key"]))
		for s in YouthCups.top_scorers(d, 3):
			print("      artilharia: %s %d" % [s["n"], int(s["g"])])
	var intl := YouthCups.comp(w, "intl")
	if not intl.is_empty():
		print("  convocados do usuário no %s: %s" % [intl["name"], str(YouthCups.user_called(w, intl))])
	print("  por competição (%s): %s" % [kid.display_name(), str(YouthAcademy.season_by_comp(w, kid.id))])
	w.year += 1
	var turn := YouthManager.season_turnover(w)
	print("  virada: %d novos, %d saíram, custo técnicos %s" % [turn["new"].size(), turn["left"].size(), Fmt.money(int(turn["staff_cost"]))])
	print("  histórico %s: %s" % [kid.display_name(), str(YouthAcademy.history(w, kid.id))])
	YouthManager.build_league(w)
	print("  nova temporada: %s" % str(YouthCups.keys(w)))
	print("honrarias: %s" % str(w.youth.get("hon", [])))
	print("ok em %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()
