class_name EvolutionChart
extends Control
## Notas médias de atuação de um jogador, temporada a temporada (e a atual, em aberto).
## Escala fixa de 0 a 10; apenas atuações observadas, nunca CA arquivada.

var _pts: Array = [] # [[ano, nota média, nota média, atual?]]


func setup(p: Player, year: int) -> void:
	_pts.clear()
	for h in p.history:
		var o := float(h.get("r", 0))
		if o > 0 and int(h.get("a", 0)) > 0:
			_pts.append([int(h.get("y", 0)), o, float(h.get("r", 0.0)), false])
	if p.stats[Player.S_APPS] > 0:
		_pts.append([year, p.avg_rating(), p.avg_rating(), true])
	if _pts.size() > 12:
		_pts = _pts.slice(_pts.size() - 12)
	queue_redraw()


func _draw() -> void:
	if _pts.size() < 1 or size.x < 40.0:
		return
	var font := get_theme_default_font()
	var fs := 18
	var top := 26.0
	var bottom := size.y - 24.0
	var left := 12.0
	var right := size.x - 12.0
	var lo := 0.0
	var hi := 10.0
	var n := _pts.size()
	var step := (right - left) / maxf(1.0, n - 1.0) if n > 1 else 0.0
	var pos := func(i: int) -> Vector2:
		var x := left + step * i if n > 1 else (left + right) * 0.5
		var t := (float(_pts[i][1]) - lo) / maxf(1.0, float(hi - lo))
		return Vector2(x, bottom - t * (bottom - top))
	draw_line(Vector2(left, bottom), Vector2(right, bottom), UIColors.LINE, 1.0)
	for i in range(1, n):
		var a: Vector2 = pos.call(i - 1)
		var b: Vector2 = pos.call(i)
		var up := float(_pts[i][1]) >= float(_pts[i - 1][1])
		draw_line(a, b, UIColors.GREEN if up else UIColors.RED, 3.0, true)
	for i in n:
		var p: Vector2 = pos.call(i)
		var cur: bool = _pts[i][3]
		draw_circle(p, 6.0, UIColors.ACCENT if cur else UIColors.TEXT)
		var val := ("%.1f" % float(_pts[i][1])).replace(".",",")
		var vw := font.get_string_size(val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, p + Vector2(-vw * 0.5, -10.0), val, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIColors.TEXT)
		if n <= 8 or i % 2 == (n - 1) % 2:
			var yl := "%02d" % (int(_pts[i][0]) % 100)
			var yw := font.get_string_size(yl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			draw_string(font, Vector2(p.x - yw * 0.5, size.y - 4.0), yl, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UIColors.MUTED)
