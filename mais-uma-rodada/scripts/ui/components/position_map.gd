@tool
class_name PositionMap
extends Control
## Mini campo (vertical, ataque para cima) com as posições do jogador: a principal acesa com o
## código, as secundárias em verde e as vizinhas (onde ainda rende bem) em pontos discretos.

var main_pos: int = Pos.CM
var secondary: Array = []
## Mostra também as posições vizinhas (familiaridade ≥ 0,85).
var show_related := true

## Onde cada posição fica no campo (x, y em 0..1; y = 0 é o gol adversário).
const SPOTS := {
	Pos.GK: Vector2(0.5, 0.91), Pos.RB: Vector2(0.84, 0.7), Pos.CB: Vector2(0.5, 0.75), Pos.LB: Vector2(0.16, 0.7),
	Pos.DM: Vector2(0.5, 0.58), Pos.CM: Vector2(0.5, 0.45), Pos.AM: Vector2(0.5, 0.31), Pos.RM: Vector2(0.84, 0.45),
	Pos.LM: Vector2(0.16, 0.45), Pos.RW: Vector2(0.82, 0.2), Pos.LW: Vector2(0.18, 0.2), Pos.ST: Vector2(0.5, 0.11),
}
const GRASS := Color("#1F6B3A")
const GRASS_2 := Color("#236F3F")
const LINE := Color(1, 1, 1, 0.35)


static func make(p: Player, w: float) -> PositionMap:
	var m := PositionMap.new()
	m.main_pos = p.position
	m.secondary = p.secondary.duplicate()
	m.custom_minimum_size = Vector2(w, w * 1.3)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var rad := minf(size.x, size.y) * 0.06
	var sb := StyleBoxFlat.new()
	sb.bg_color = GRASS
	sb.set_corner_radius_all(int(rad))
	draw_style_box(sb, r)
	for i in 6:
		if i % 2 == 1:
			draw_rect(Rect2(r.position.x, r.size.y * i / 6.0, r.size.x, r.size.y / 6.0), GRASS_2)
	var lw := maxf(1.0, size.x * 0.012)
	var pad := size.x * 0.06
	var f := Rect2(pad, pad, size.x - pad * 2.0, size.y - pad * 2.0)
	draw_rect(f, LINE, false, lw)
	draw_line(Vector2(f.position.x, f.get_center().y), Vector2(f.end.x, f.get_center().y), LINE, lw)
	draw_arc(f.get_center(), f.size.x * 0.16, 0, TAU, 32, LINE, lw)
	var bw := f.size.x * 0.5
	var bh := f.size.y * 0.13
	draw_rect(Rect2(f.get_center().x - bw * 0.5, f.position.y, bw, bh), LINE, false, lw)
	draw_rect(Rect2(f.get_center().x - bw * 0.5, f.end.y - bh, bw, bh), LINE, false, lw)
	var font := get_theme_font(&"font", &"Caps")
	var dot := size.x * 0.085
	if show_related:
		for k in Pos.RELATED[main_pos]:
			if float(Pos.RELATED[main_pos][k]) >= 0.85 and not secondary.has(k):
				draw_circle(_at(f, k), dot * 0.32, Color(1, 1, 1, 0.45))
	for s in secondary:
		_marker(f, int(s), dot * 0.8, Color("#3DBE7A"), font)
	_marker(f, main_pos, dot, Color("#FFC940"), font)


func _marker(f: Rect2, pos: int, rad: float, col: Color, font: Font) -> void:
	var c := _at(f, pos)
	draw_circle(c, rad + maxf(1.0, rad * 0.14), Color(0, 0, 0, 0.35))
	draw_circle(c, rad, col)
	var txt := Pos.code(pos)
	var fs := int(rad * 0.95)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(c.x - tw * 0.5, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#0E1621"))


func _at(f: Rect2, pos: int) -> Vector2:
	var sp: Vector2 = SPOTS.get(pos, Vector2(0.5, 0.5))
	return f.position + Vector2(sp.x * f.size.x, sp.y * f.size.y)
