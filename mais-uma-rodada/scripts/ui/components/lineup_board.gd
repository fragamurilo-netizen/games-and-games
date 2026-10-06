class_name LineupBoard
extends Control
## Escalação no estilo das transmissões: meio-campo em perspectiva com o desenho do time, cada
## jogador com a camisa (número) e o nome embaixo; no rodapé o técnico e o banco. Cores da liga.

var team: MatchTeam = null
var accent := Color("#FFC940")
var bg := Color("#10141A")
var shirt := Color.WHITE
var shirt2 := Color("#15171B")
var coach := ""
var _font: Font


static func make(t: MatchTeam, acc: Color, back: Color, c1: Color, c2: Color, coach_name: String) -> LineupBoard:
	var v := LineupBoard.new()
	v.team = t
	v.accent = acc
	v.bg = back
	v.shirt = c1
	v.shirt2 = c2
	v.coach = coach_name
	v.custom_minimum_size = Vector2(0, 640)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _draw() -> void:
	if team == null:
		return
	_font = get_theme_default_font()
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	# Faixa do título
	draw_rect(Rect2(0, 0, w, 54), accent)
	var title := "%s · %s" % [team.club.short_name.to_upper(), team.formation_name]
	_text(title, Vector2(w * 0.5, 36), 26, UIColors.on_color(accent), w - 20)
	# Campo em perspectiva (trapézio)
	var top := 72.0
	var bot := h - 128.0
	var tw := w * 0.62
	var bw := w * 0.96
	var poly := PackedVector2Array([Vector2((w - tw) * 0.5, top), Vector2((w + tw) * 0.5, top), Vector2((w + bw) * 0.5, bot), Vector2((w - bw) * 0.5, bot)])
	draw_colored_polygon(poly, Color("#1F6B3A"))
	for k in 6:
		if k % 2 == 0:
			var y0 := lerpf(top, bot, k / 6.0)
			var y1 := lerpf(top, bot, (k + 1) / 6.0)
			var s0 := lerpf(tw, bw, k / 6.0)
			var s1 := lerpf(tw, bw, (k + 1) / 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2((w - s0) * 0.5, y0), Vector2((w + s0) * 0.5, y0), Vector2((w + s1) * 0.5, y1), Vector2((w - s1) * 0.5, y1)]), Color("#23753F"))
	draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]), Color(1, 1, 1, 0.55), 2.0)
	# Área e meia-lua do lado de baixo (o gol do time fica embaixo)
	var bx := func(fx: float, fy: float) -> Vector2:
		var y := lerpf(top, bot, fy)
		var sw := lerpf(tw, bw, fy)
		return Vector2(w * 0.5 + (fx - 0.5) * sw, y)
	draw_polyline(PackedVector2Array([bx.call(0.2, 1.0), bx.call(0.2, 0.8), bx.call(0.8, 0.8), bx.call(0.8, 1.0)]), Color(1, 1, 1, 0.5), 2.0)
	draw_line(bx.call(0.0, 0.0), bx.call(1.0, 0.0), Color(1, 1, 1, 0.5), 2.0)
	# Jogadores pelas posições da formação (y da formação: 0 = próprio gol)
	var slots: Array = DatabaseManager.formation(team.formation_name)["slots"]
	for mp in team.slots:
		if mp == null or mp.slot < 0 or mp.slot >= slots.size():
			continue
		var sl: Dictionary = slots[mp.slot]
		var fy := 1.0 - clampf(float(sl["y"]) * 1.12, 0.03, 0.97)
		var p: Vector2 = bx.call(1.0 - float(sl["x"]), fy)
		var sc := lerpf(0.78, 1.08, fy)
		_player(p, sc, mp)
	# Técnico e banco
	var by := h - 84.0
	draw_rect(Rect2(0, by, w, 84), Color(0, 0, 0, 0.35))
	_text("Técnico: %s" % coach, Vector2(w * 0.5, by + 30), 20, accent, w - 20)
	var bench: Array = []
	for b: MatchPlayer in team.bench:
		bench.append(b.p.short_name())
	_text("Banco: " + ", ".join(bench.slice(0, 7)), Vector2(w * 0.5, by + 62), 16, Color(1, 1, 1, 0.8), w - 20)


func _player(p: Vector2, sc: float, mp: MatchPlayer) -> void:
	var r := 22.0 * sc
	var gk := mp.slot == 0
	var c1 := shirt if not gk else Color("#2E2E2E").lerp(accent, 0.3)
	var c2 := shirt2 if not gk else Color.WHITE
	# Camisa: corpo e mangas
	var body := PackedVector2Array([p + Vector2(-r * 0.7, -r * 0.8), p + Vector2(r * 0.7, -r * 0.8), p + Vector2(r * 1.25, -r * 0.35),
		p + Vector2(r * 0.9, 0), p + Vector2(r * 0.7, -r * 0.3), p + Vector2(r * 0.7, r * 0.95), p + Vector2(-r * 0.7, r * 0.95),
		p + Vector2(-r * 0.7, -r * 0.3), p + Vector2(-r * 0.9, 0), p + Vector2(-r * 1.25, -r * 0.35)])
	draw_colored_polygon(body, c1)
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0, 0, 0, 0.5), 1.5)
	_text(str(mp.p.shirt), p + Vector2(0, r * 0.45), int(22 * sc), c2, r * 2.0)
	var name_s := mp.p.short_name()
	var fs := int(17 * sc)
	var tw := _font.get_string_size(name_s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_rect(Rect2(p + Vector2(-tw * 0.5 - 6, r * 1.1), Vector2(tw + 12, fs + 8)), Color(0, 0, 0, 0.72))
	_text(name_s, p + Vector2(0, r * 1.1 + fs + 1), fs, Color.WHITE, 200)


func _text(t: String, center: Vector2, fs: int, col: Color, max_w: float) -> void:
	var f := _font if _font != null else get_theme_default_font()
	var s := fs
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	while w > max_w and s > 9:
		s -= 1
		w = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
	draw_string(f, center - Vector2(w * 0.5, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)
