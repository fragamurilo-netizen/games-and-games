extends SceneTree
## Escolas de técnicos (CoachSchools): gera o mundo e mostra as escolas fundadas, quantos técnicos
## cada uma tem e a árvore da maior. Com --user: simula o seu auxiliar virando técnico.
## godot --headless --path . --script res://tools/coach_schools_report.gd


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	People.ensure(w)
	var d := CoachSchools.data(w)
	var list: Array = (d["list"] as Dictionary).values()
	list.sort_custom(func(a: Dictionary, b: Dictionary): return CoachSchools.members(w, int(a["id"])).size() > CoachSchools.members(w, int(b["id"])).size())
	var total := CoachSchools.all_coaches(w).size()
	var with_school := 0
	for co: Dictionary in CoachSchools.all_coaches(w):
		if int(co.get("sch", 0)) > 0:
			with_school += 1
	print("Técnicos: %d · com escola: %d · escolas: %d" % [total, with_school, list.size()])
	for s: Dictionary in list:
		print("  %s (%s, %d) · %d técnicos · %s" % [s["n"], s["nat"], int(s["y"]), CoachSchools.members(w, int(s["id"])).size(), ", ".join(PackedStringArray(CoachSchools.trait_names(s["tr"])))])
	if not list.is_empty():
		print("Árvore da %s:" % list[0]["n"])
		for row in CoachSchools.tree(w, list[0]).slice(0, 12):
			print("  " + "  ".repeat(int(row[0])) + "%s (%d)" % [row[1], int(row[2])])
	quit()
