class_name MatchMapView
extends Control
## Mapa da partida sobre o campo deitado (mandante ataca para a direita):
##   "shots"  finalizações dos dois times. O tamanho do ponto é a qualidade da chance (xG); gol é
##            um alvo (miolo, aro grosso, aro fino), no gol é ponto cheio, para fora, na trave ou
##            bloqueada é só o aro.
##   "heat0" / "heat1"  onde o mandante / o visitante jogou (mapa de calor).
## Os dados vêm de MatchMaps. O campo é o mesmo gramado do resto do jogo (Grass).

const LEGEND_H := 40.0
const HEAT_RAMP: Array[Color] = [Color("#F2C230"), Color("#F08A3C"), Color("#E5484D")]

var mode := "shots":
	set(v):
		mode = v
		queue_redraw()
var shots: Array = []
var grids: Array = []
var colors: Array[Color] = [Color.WHITE, Color.BLACK]
var names: Array[String] = ["", ""]
var _heat_tex: Array = [null, null]
var _font: Font = null


## Bloco pronto: seletor (finalizações, calor de cada time) e o mapa embaixo. `on_mode` recebe a
## escolha, para quem remonta a tela guardar qual mapa estava aberto.
static func panel(sim: MatchSimulation, max_half: int, side_colors: Array[Color], start_mode: String = "shots", on_mode: Callable = Callable()) -> VBoxContainer:
	var v := UIKit.vbox(UITokens.S2)
	var view := MatchMapView.new()
	view.shots = MatchMaps.shots(sim.events, max_half)
	view.grids = MatchMaps.heat(sim, max_half)
	view.colors = side_colors
	view.names = [sim.teams[0].club.abbr, sim.teams[1].club.abbr]
	view.mode = start_mode
	var items := [["shots", "Finalizações"], ["heat0", I18n.t("Calor %s") % sim.teams[0].club.abbr], ["heat1", I18n.t("Calor %s") % sim.teams[1].club.abbr]]
	var seg := UIKit.segment(items, start_mode, func(k: String) -> void:
		view.mode = k
		if on_mode.is_valid():
			on_mode.call(k))
	v.add_child(seg)
	v.add_child(view)
	return v


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	custom_minimum_size = Vector2(0, 300)


func _ready() -> void:
	_font = get_theme_font(&"font", &"Caps")
	resized.connect(_fit)
	_fit()


## A altura acompanha a largura (campo de 105 × 68) e sobra a faixa da legenda embaixo.
func _fit() -> void:
	var h := minf(size.x * MatchMaps.W / MatchMaps.L, 420.0) + LEGEND_H
	if size.x > 1.0 and absf(custom_minimum_size.y - h) > 1.0:
		custom_minimum_size.y = h
	queue_redraw()


func _field() -> Rect2:
	var h := size.y - LEGEND_H
	var w := minf(size.x, h * MatchMaps.L / MatchMaps.W)
	return Rect2((size.x - w) * 0.5, 0.0, w, h)


func _pt(f: Rect2, m: Vector2) -> Vector2:
	return f.position + Vector2(m.x / MatchMaps.L * f.size.x, m.y / MatchMaps.W * f.size.y)


func _draw() -> void:
	var f := _field()
	if f.size.x < 8.0:
		return
	Grass.stripes(self, f, f.size.x / 10.0, 0.22)
	if mode != "shots":
		_draw_heat(f, 1 if mode == "heat1" else 0)
	_draw_lines(f)
	if mode == "shots":
		_draw_shots(f)
	_draw_legend(f)


func _draw_lines(f: Rect2) -> void:
	var c := Grass.chalk(0.55)
	var k := f.size.x / MatchMaps.L
	var w := 2.0
	draw_rect(f.grow(-1.0), c, false, w)
	draw_line(_pt(f, Vector2(52.5, 0)), _pt(f, Vector2(52.5, 68)), c, w)
	draw_arc(_pt(f, Vector2(52.5, 34)), 9.15 * k, 0.0, TAU, 40, c, w, true)
	for side in 2:
		var gx := 0.0 if side == 0 else 105.0
		var dir := 1.0 if side == 0 else -1.0
		# Grande área, pequena área, marca do pênalti e meia-lua.
		var a := _pt(f, Vector2(gx, 34 - 20.16))
		var b := _pt(f, Vector2(gx + dir * 16.5, 34 + 20.16))
		draw_rect(Rect2(Vector2(minf(a.x, b.x), a.y), Vector2(absf(b.x - a.x), b.y - a.y)), c, false, w)
		var a2 := _pt(f, Vector2(gx, 34 - 9.16))
		var b2 := _pt(f, Vector2(gx + dir * 5.5, 34 + 9.16))
		draw_rect(Rect2(Vector2(minf(a2.x, b2.x), a2.y), Vector2(absf(b2.x - a2.x), b2.y - a2.y)), c, false, w)
		var spot := _pt(f, Vector2(gx + dir * 11.0, 34))
		draw_circle(spot, 2.5, c)
		var ang := 0.93 # a meia-lua é o pedaço do círculo de 9,15 m fora da área
		if side == 0:
			draw_arc(spot, 9.15 * k, -ang, ang, 16, c, w, true)
		else:
			draw_arc(spot, 9.15 * k, PI - ang, PI + ang, 16, c, w, true)
		# O gol
		var g1 := _pt(f, Vector2(gx, 34 - 3.66))
		var g2 := _pt(f, Vector2(gx, 34 + 3.66))
		draw_line(g1, g2, Grass.chalk(0.95), 5.0)


## Cor do time para desenhar sobre a grama: time verde (ou escuro demais) clareia, senão some.
func _ink(side: int) -> Color:
	var c: Color = colors[side]
	var grassy := c.s > 0.25 and c.h > 0.2 and c.h < 0.5
	if grassy and c.get_luminance() < 0.5:
		return c.lightened(0.5)
	if c.get_luminance() < 0.08:
		return c.lightened(0.18)
	return c


## Contorno que separa o ponto da grama e dos outros pontos: cal para cor escura, escuro para clara.
func _edge(ink: Color) -> Color:
	return Grass.chalk(0.95) if ink.get_luminance() < 0.32 else Color(0.04, 0.07, 0.09, 0.8)


func _draw_shots(f: Rect2) -> void:
	# Os gols por último: ficam por cima dos outros pontos.
	for pass_goals in [false, true]:
		for sh: Dictionary in shots:
			var goal := String(sh["res"]) == "goal"
			if goal != pass_goals:
				continue
			var p := _pt(f, sh["pos"])
			var r := 5.0 + clampf(float(sh["xg"]), 0.0, 0.8) * 18.0
			var col := _ink(int(sh["s"]))
			var edge := _edge(col)
			match String(sh["res"]):
				"goal":
					# Alvo: miolo na cor do time, aro grosso de contraste, aro fino do time por fora.
					draw_circle(p, r + 6.5, col)
					draw_circle(p, r + 4.5, edge)
					draw_circle(p, r, col)
				"save":
					draw_circle(p, r + 1.5, edge)
					draw_circle(p, r, col)
				_:
					draw_arc(p, r, 0.0, TAU, 24, edge, 5.5, true)
					draw_arc(p, r, 0.0, TAU, 24, col, 3.0, true)


func _draw_heat(f: Rect2, side: int) -> void:
	if grids.size() <= side:
		return
	if _heat_tex[side] == null:
		var g: PackedFloat32Array = grids[side]
		var img := Image.create(MatchMaps.GX, MatchMaps.GY, false, Image.FORMAT_RGBA8)
		for y in MatchMaps.GY:
			for x in MatchMaps.GX:
				var v := g[y * MatchMaps.GX + x]
				var col := HEAT_RAMP[0].lerp(HEAT_RAMP[1], clampf(v * 2.0, 0.0, 1.0)) if v < 0.5 else HEAT_RAMP[1].lerp(HEAT_RAMP[2], clampf(v * 2.0 - 1.0, 0.0, 1.0))
				col.a = clampf((v - 0.08) * 1.25, 0.0, 0.88)
				img.set_pixel(x, y, col)
		_heat_tex[side] = ImageTexture.create_from_image(img)
	draw_texture_rect(_heat_tex[side], f, false)


## Faixa de baixo: o que os pontos querem dizer, ou para que lado o time ataca.
func _draw_legend(f: Rect2) -> void:
	var y := f.end.y + LEGEND_H * 0.5 + 2.0
	var fs := 18
	var ink := UIColors.MUTED
	if mode == "shots":
		var x := f.position.x + 4.0
		for side in 2:
			draw_circle(Vector2(x + 8.0, y), 8.0, _ink(side))
			draw_arc(Vector2(x + 8.0, y), 8.0, 0.0, TAU, 20, UIColors.LINE, 1.5, true)
			x = _legend_text(names[side], x + 22.0, y, fs, ink) + 18.0
		var items := [["goal", "Gol"], ["save", "No gol"], ["miss", "Para fora"]]
		var total := 0.0
		for it: Array in items:
			total += 26.0 + _font.get_string_size(I18n.t(String(it[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
		x = maxf(x, f.end.x - total + 12.0)
		for it: Array in items:
			var c := Vector2(x + 9.0, y)
			match String(it[0]):
				"goal":
					draw_circle(c, 10.0, UIColors.DIM)
					draw_circle(c, 8.0, UIColors.TEXT)
					draw_circle(c, 4.5, UIColors.DIM)
				"save":
					draw_circle(c, 7.5, UIColors.DIM)
				_:
					draw_arc(c, 7.0, 0.0, TAU, 20, UIColors.DIM, 2.5, true)
			x = _legend_text(I18n.t(String(it[1])), x + 24.0, y, fs, ink) + 16.0
	else:
		var side := 1 if mode == "heat1" else 0
		var txt := I18n.t("%s ataca para a direita") % names[side] if side == 0 else I18n.t("%s ataca para a esquerda") % names[side]
		var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_legend_text(txt, f.position.x + (f.size.x - w) * 0.5, y, fs, ink)


func _legend_text(txt: String, x: float, y: float, fs: int, col: Color) -> float:
	draw_string(_font, Vector2(x, y + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return x + _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
