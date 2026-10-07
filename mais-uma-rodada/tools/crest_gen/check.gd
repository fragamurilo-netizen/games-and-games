extends SceneTree
## Valida o catálogo real em tamanhos de lista: contornos trianguláveis, erro
## visual máximo de 0,4 px e catálogo original preservado pela simplificação.
## godot --headless --path . --script res://tools/crest_gen/check.gd


func _initialize() -> void:
	var checked := 0
	var original_points := 0
	var icon_points := 0
	for name: String in CrestArt.PATHS:
		for poly: PackedVector2Array in CrestArt.polys(name):
			if Geometry2D.triangulate_polygon(poly).is_empty():
				if name.begins_with("club_") or name.begins_with("match_"):
					push_error("desenho novo não triangulável: " + name)
					quit(1)
					return
				continue # desenhos legados que o renderer já ignora
			var original_hash := hash(poly)
			for radius: float in [6.0, 10.0, 16.0, 23.0]:
				var icon := CrestView._charge_contour(poly, radius)
				if Geometry2D.triangulate_polygon(icon).is_empty() or hash(poly) != original_hash:
					push_error("contorno inválido ou catálogo alterado: " + name)
					quit(1)
					return
				for point in poly:
					var nearest := INF
					for i in icon.size():
						var on_edge := Geometry2D.get_closest_point_to_segment(point, icon[i], icon[(i + 1) % icon.size()])
						nearest = minf(nearest, point.distance_to(on_edge))
					if nearest * radius > 0.401:
						push_error("erro acima de 0,4 px: " + name)
						quit(1)
						return
				checked += 1
				original_points += poly.size()
				icon_points += icon.size()
	print("contornos: %d, pontos: %d -> %d, com erro: 0" % [checked, original_points, icon_points])
	quit()
