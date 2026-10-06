class_name WeatherIcon
extends Control
## Ícone desenhado do clima da partida (sol, nuvem, chuva, temporal, neve, calor, vento, neblina, noite).

var kind := "cloud"
var night := false


func _init(k: String = "cloud", is_night: bool = false, px: int = 30) -> void:
	kind = k
	night = is_night
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var sun_col := Color("#FFC940")
	var cloud_col := Color("#DCE3EA")
	if kind in ["sun", "heat"]:
		if night:
			_moon(c, s * 0.3)
		else:
			var col := sun_col if kind == "sun" else Color("#FF8A3D")
			draw_circle(c, s * 0.2, col)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.28, c + Vector2(cos(a), sin(a)) * s * 0.42, col, maxf(1.5, s * 0.07))
		return
	if kind == "wind":
		for k in 3:
			var y := c.y + (k - 1) * s * 0.2
			draw_line(Vector2(s * 0.12, y), Vector2(s * (0.7 + 0.1 * k), y), cloud_col, maxf(1.5, s * 0.08))
			draw_arc(Vector2(s * (0.7 + 0.1 * k), y - s * 0.06), s * 0.06, -PI * 0.5, PI * 0.9, 8, cloud_col, maxf(1.5, s * 0.07))
		return
	if kind == "fog":
		for k in 4:
			var y := s * (0.3 + k * 0.14)
			draw_line(Vector2(s * (0.12 + 0.05 * (k % 2)), y), Vector2(s * (0.85 - 0.05 * (k % 2)), y), cloud_col, maxf(1.5, s * 0.08))
		return
	# Nuvem (com lua atrás se for noite)
	if night:
		_moon(c + Vector2(s * 0.14, -s * 0.16), s * 0.18)
	var base := Vector2(c.x, c.y - s * 0.04)
	var cc := cloud_col if kind != "storm" else Color("#8A96A3")
	draw_circle(base + Vector2(-s * 0.16, s * 0.04), s * 0.15, cc)
	draw_circle(base + Vector2(s * 0.02, -s * 0.06), s * 0.2, cc)
	draw_circle(base + Vector2(s * 0.2, s * 0.05), s * 0.14, cc)
	draw_rect(Rect2(base + Vector2(-s * 0.16, s * 0.04), Vector2(s * 0.36, s * 0.15)), cc)
	var y0 := base.y + s * 0.26
	match kind:
		"rain", "storm":
			for k in 3:
				var x := base.x + (k - 1) * s * 0.16
				draw_line(Vector2(x, y0), Vector2(x - s * 0.05, y0 + s * 0.14), Color("#6FB7FF"), maxf(1.5, s * 0.06))
			if kind == "storm":
				var pts := PackedVector2Array([Vector2(base.x + s * 0.05, y0 - s * 0.04), Vector2(base.x - s * 0.06, y0 + s * 0.1), Vector2(base.x + s * 0.01, y0 + s * 0.1), Vector2(base.x - s * 0.07, y0 + s * 0.24), Vector2(base.x + s * 0.1, y0 + s * 0.05), Vector2(base.x + s * 0.03, y0 + s * 0.05)])
				draw_colored_polygon(pts, sun_col)
		"snow":
			for k in 3:
				var p := Vector2(base.x + (k - 1) * s * 0.17, y0 + s * 0.07 * (k % 2))
				for j in 3:
					var a := PI * j / 3.0
					draw_line(p - Vector2(cos(a), sin(a)) * s * 0.06, p + Vector2(cos(a), sin(a)) * s * 0.06, Color.WHITE, maxf(1.0, s * 0.04))


func _moon(c: Vector2, r: float) -> void:
	draw_circle(c, r, Color("#F1E7C2"))
	draw_circle(c + Vector2(r * 0.45, -r * 0.3), r * 0.85, Color("#101318"))
