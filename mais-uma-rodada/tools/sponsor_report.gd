extends SceneTree
## Relatório dos patrocínios por país: confere que toda marca no peito, na manga e na fornecedora
## é do país do clube (ou multinacional que anuncia na confederação) e que as proibições locais
## valem. godot --headless --path . --script res://tools/sponsor_report.gd


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var wrong := 0
	var banned := 0
	var no_master := 0
	var no_sup := 0
	var by_nation := {}
	for c: Club in w.clubs:
		if not c.sponsors.has("master"):
			no_master += 1
		if not c.sponsors.has("fornecedor"):
			no_sup += 1
		for slot in c.sponsors:
			var ct: Dictionary = c.sponsors[slot]
			var e := BrandCatalog.find(String(ct["n"]))
			var origin := String(e.get("o", c.nation)) # marcas de bairro não estão no índice
			var reach: Array = e.get("r", [])
			var ok := origin == c.nation or reach.has("all") or reach.has(BrandCatalog.confed_of(c.nation)) or reach.has(c.nation)
			if not ok:
				wrong += 1
				print("  fora do país: %s (%s) %s = %s" % [c.short_name, c.nation, slot, ct["n"]])
			if slot != "fornecedor" and not BrandCatalog.allowed(c.nation, String(ct.get("s", "")), slot, c.tier):
				banned += 1
				print("  proibida: %s (%s) %s = %s" % [c.short_name, c.nation, slot, ct["n"]])
		if not by_nation.has(c.nation):
			by_nation[c.nation] = []
		if by_nation[c.nation].size() < 4:
			by_nation[c.nation].append("%s: %s / %s" % [c.short_name, c.sponsors.get("master", {}).get("n", "-"), c.sponsors.get("fornecedor", {}).get("n", "-")])
	for n in by_nation:
		print("%s  %s" % [n, " | ".join(by_nation[n])])
	print("clubes: %d  marca fora do país: %d  proibida: %d  sem master: %d  sem fornecedora: %d" % [w.clubs.size(), wrong, banned, no_master, no_sup])
	quit(1 if wrong + banned > 0 else 0)
