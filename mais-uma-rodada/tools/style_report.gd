extends SceneTree
## Distribuição dos estilos de jogo (PlayStyle) e dos traços por função no mundo gerado.
## Uso: godot --headless --path . --script res://tools/style_report.gd


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var by_role := {}
	var traits := {}
	var none := 0
	var n := 0
	for p: Player in w.players.values():
		if p.club_id < 0:
			continue
		var r := PlayStyle.role_of(p.position)
		var d: Dictionary = by_role.get(r, {})
		var k := PlayStyle.of(p)
		d[k] = int(d.get(k, 0)) + 1
		by_role[r] = d
		var sec := PlayStyle.secondary(p)
		n += 1
		if sec.is_empty():
			none += 1
		else:
			traits[String(sec["n"])] = int(traits.get(String(sec["n"]), 0)) + 1
	for r in by_role:
		var d: Dictionary = by_role[r]
		var tot := 0
		for k in d:
			tot += int(d[k])
		var parts: Array = []
		for k in d:
			parts.append("%s %.0f%%" % [k, 100.0 * int(d[k]) / tot])
		print("%s (%d): %s" % [r, tot, ", ".join(PackedStringArray(parts))])
	var tp: Array = []
	for k in traits:
		tp.append("%s %.0f%%" % [k, 100.0 * int(traits[k]) / n])
	print("traços: sem traço %.0f%% | %s" % [100.0 * none / n, ", ".join(PackedStringArray(tp))])
	quit()
