extends SceneTree
## Relatório de uniformes parecidos: quantos clubes têm reserva (ou terceiro) da cor do titular.
## godot --headless --path . --script res://tools/kit_clash_report.gd


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var n := 0
	var bad_a := 0
	var bad_t := 0
	var dists: Array = []
	for c: Club in w.clubs:
		n += 1
		var d := KitDesign.distance(c.kit_home, c.kit_away)
		dists.append(d)
		if KitDesign.clash(c.kit_home, c.kit_away):
			bad_a += 1
			if bad_a <= 12:
				print("  reserva parecida: %s  d=%.1f  %s/%s x %s/%s" % [c.short_name, d, c.kit_home.get("pattern"), c.kit_home.get("c1"), c.kit_away.get("pattern"), c.kit_away.get("c1")])
		var t := c.third_kit()
		if KitDesign.clash(c.kit_home, t) or KitDesign.clash(c.kit_away, t):
			bad_t += 1
	dists.sort()
	print("clubes: %d  reserva parecida: %d  terceiro parecido: %d  distância mediana: %.1f  mínima: %.1f" % [n, bad_a, bad_t, dists[dists.size() / 2], dists[0]])
	# Três viradas de temporada: os clubes da IA lançam uniformes novos, sempre sem repetir cor.
	var renew_bad := 0
	var changed := 0
	for y in 3:
		w.year += 1
		for c: Club in w.clubs:
			var before := String(c.kit_home.get("pattern", "")) + String(c.kit_away.get("c1", ""))
			KitDesign.renew_ai(w, c)
			if before != String(c.kit_home.get("pattern", "")) + String(c.kit_away.get("c1", "")):
				changed += 1
			if KitDesign.clash(c.kit_home, c.kit_away):
				renew_bad += 1
	print("renovações: %d uniformes mudaram, %d reservas parecidos" % [changed, renew_bad])
	# Coleções do editor
	var col_bad := 0
	for c: Club in w.clubs.slice(0, 200):
		for i in 3:
			var col := KitDesign.collection(c, w.year, i)
			if KitDesign.clash(col["h"], col["a"]) or KitDesign.clash(col["h"], col["t"]) or KitDesign.clash(col["a"], col["t"]):
				col_bad += 1
	print("coleções com cores repetidas: %d de 600" % col_bad)
	quit()
