@tool
class_name StarsView
extends Control
## Estrelas (0–5, com meia estrela) desenhadas: reputação, potencial percebido etc.

@export var stars: float = 3.5:
	set(v):
		stars = v
		queue_redraw()
@export var star_size: float = 20.0:
	set(v):
		star_size = v
		custom_minimum_size = Vector2(star_size * 5 + 4 * 3, star_size)
		queue_redraw()
@export var color: Color = UIColors.ACCENT
## Upper edge of an uncertain assessment. Negative keeps ordinary stars.
var upper_stars: float = -1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(star_size * 5 + 12, star_size)


func _draw() -> void:
	var y := size.y * 0.5
	for i in 5:
		var c := Vector2(i * (star_size + 3.0) + star_size * 0.5, y)
		var poly := CrestView._star(c, star_size * 0.5, star_size * 0.22, 5)
		draw_colored_polygon(poly, UIColors.SURFACE_3)
		if upper_stars > stars and float(i) < upper_stars:
			var upper_fill := clampf(upper_stars-i,0.0,1.0)
			var bounds := PackedVector2Array([Vector2(c.x-star_size,c.y-star_size),Vector2(c.x-star_size*0.5+star_size*upper_fill,c.y-star_size),Vector2(c.x-star_size*0.5+star_size*upper_fill,c.y+star_size),Vector2(c.x-star_size,c.y+star_size)])
			for piece in Geometry2D.intersect_polygons(poly,bounds):
				draw_colored_polygon(piece, Color(UIColors.MUTED,0.65))
		var fill := clampf(stars - i, 0.0, 1.0)
		if fill >= 0.99:
			draw_colored_polygon(poly, color)
		elif fill > 0.0:
			var clip := PackedVector2Array([Vector2(c.x - star_size, c.y - star_size), Vector2(c.x - star_size * 0.5 + star_size * fill, c.y - star_size),
				Vector2(c.x - star_size * 0.5 + star_size * fill, c.y + star_size), Vector2(c.x - star_size, c.y + star_size)])
			for piece in Geometry2D.intersect_polygons(poly, clip):
				draw_colored_polygon(piece, color)


## Reputação 1–100 → 0,5–5 estrelas.
static func from_reputation(rep: float) -> float:
	return clampf(snappedf(rep / 20.0, 0.5), 0.5, 5.0)
