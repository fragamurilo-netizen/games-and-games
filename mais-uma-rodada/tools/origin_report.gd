extends SceneTree
## Nome × etnia × país dos jogadores gerados: quantos de cada etnia por nacionalidade e exemplos
## de nomes de cada combinação (para achar "negro basco com nome basco" e parecidos).
## godot --headless --path . --script res://tools/origin_report.gd [-- --nations=ESP,ENG --n=6 --club=Athletic Club]


func _initialize() -> void:
	var only: Array = []
	var per := 6
	var club_name := "Athletic Club"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--nations="):
			only = Array(a.substr(10).split(","))
		elif a.begins_with("--n="):
			per = int(a.substr(4))
		elif a.begins_with("--club="):
			club_name = a.substr(7)
	var eth: Array = DatabaseManager.ethnicities()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var by_nat := {}
	for p: Player in w.players.values():
		if not by_nat.has(p.nationality):
			by_nat[p.nationality] = {}
		var e := String(eth[p.eth])
		if not by_nat[p.nationality].has(e):
			by_nat[p.nationality][e] = []
		by_nat[p.nationality][e].append(p)
	var nats: Array = by_nat.keys()
	nats.sort_custom(func(a, b): return _count(by_nat[a]) > _count(by_nat[b]))
	for nat in nats:
		if not only.is_empty() and not only.has(nat):
			continue
		if only.is_empty() and _count(by_nat[nat]) < 120:
			continue
		var total := _count(by_nat[nat])
		print("\n== %s · %d jogadores" % [nat, total])
		var es: Array = by_nat[nat].keys()
		es.sort_custom(func(a, b): return by_nat[nat][a].size() > by_nat[nat][b].size())
		for e in es:
			var ps: Array = by_nat[nat][e]
			var names: Array = []
			for i in mini(per, ps.size()):
				var p: Player = ps[i]
				var pp := NationalityManager.passports(p)
				names.append("%s %s%s" % [p.first_name, p.last_name, "" if pp.size() < 2 else " [" + ",".join(pp.slice(1)) + "]"])
			print("  %-4s %5.1f%%  %s" % [e, 100.0 * ps.size() / total, " · ".join(names)])
	for c: Club in w.clubs:
		if c.name == club_name:
			print("\n== %s" % c.name)
			for p: Player in w.squad(c):
				print("  %-4s %-3s %s %s (%s)" % [String(eth[p.eth]), p.nationality, p.first_name, p.last_name, p.hometown])
	quit()


func _count(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += d[k].size()
	return n
