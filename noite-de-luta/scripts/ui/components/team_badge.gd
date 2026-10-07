@tool
class_name TeamBadge
extends Control
## Selo da equipe: escudo nas duas cores com a sigla. Equipes de lutadores não têm escudo de
## clube; o selo é o "logo da camiseta da academia".

var team: Team = null:
	set(v):
		team = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func shield(r: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := r.size.x
	var h := r.size.y
	pts.append(r.position + Vector2(w * 0.08, h * 0.04))
	pts.append(r.position + Vector2(w * 0.92, h * 0.04))
	pts.append(r.position + Vector2(w * 0.92, h * 0.52))
	for i in range(1, 12):
		var t := float(i) / 12.0
		var a := lerpf(0.0, PI, t)
		pts.append(r.position + Vector2(w * 0.5 + cos(a) * w * 0.42, h * 0.52 + sin(a) * h * 0.44))
	pts.append(r.position + Vector2(w * 0.08, h * 0.52))
	return pts


func _draw() -> void:
	var s := minf(size.x, size.y)
	var r := Rect2((size.x - s) * 0.5, (size.y - s) * 0.5, s, s)
	var c1 := team.color1 if team != null else UIColors.SURFACE_3
	var c2 := team.color2 if team != null else UIColors.LINE
	var poly := shield(r)
	draw_colored_polygon(poly, c1)
	# Faixa diagonal na segunda cor, recortada pelo escudo.
	var band := PackedVector2Array([r.position + Vector2(s * 0.58, 0), r.position + Vector2(s * 0.78, 0), r.position + Vector2(s * 0.42, s), r.position + Vector2(s * 0.22, s)])
	for piece in Geometry2D.intersect_polygons(poly, band):
		draw_colored_polygon(piece, c2)
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(0, 0, 0, 0.35), maxf(1.0, s * 0.03), true)
	if team == null:
		return
	var font := get_theme_font(&"font", &"Title")
	var fs := int(s * 0.34)
	var txt := team.short
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var ink := UIColors.on_color(c1)
	var pos := Vector2(r.get_center().x - tw.x * 0.5, r.position.y + s * 0.5 + fs * 0.32)
	draw_string(font, pos + Vector2(0, maxf(1.0, s * 0.02)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.35))
	draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
