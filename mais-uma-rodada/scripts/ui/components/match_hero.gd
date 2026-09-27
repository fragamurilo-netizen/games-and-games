class_name MatchHero
extends Control
## Fundo do cartão de dia de jogo (hub, pré-jogo): faixa superior na identidade da competição
## (cores da transmissão da liga ou copa, ScoreboardTheme) e o campo dividido nas cores dos
## dois clubes, que se dissolvem no centro. Vai como primeiro filho de um PanelContainer sem
## margens internas (ver `wrap`).

var band_h := 58.0
var band_bg := Color("#0F1012")
var band_bg2 := Color("#18191C")
var band_accent := Color("#FFC940")
var left_color := Color(0, 0, 0, 0)
var right_color := Color(0, 0, 0, 0)
var radius := float(UITokens.R_LG)


## Monta o painel: devolve [painel, caixa da faixa, caixa do corpo]. Os filhos vão nas caixas.
static func wrap(w: GameWorld, comp: String, home: Club, away: Club) -> Array:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE
	box.set_corner_radius_all(UITokens.R_LG)
	box.border_color = UIColors.ACCENT
	box.set_border_width_all(2)
	box.anti_aliasing = true
	box.corner_detail = 8
	p.add_theme_stylebox_override(&"panel", box)
	var bg := MatchHero.new()
	var st := ScoreboardTheme.for_competition(w, comp)
	bg.band_bg = st["bg"]
	bg.band_bg2 = st["bg2"]
	bg.band_accent = st["accent"]
	if home != null:
		bg.left_color = UIColors.club_tone(home)
	if away != null:
		bg.right_color = UIColors.club_tone(away)
	p.add_child(bg)
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var band := UIKit.hbox(12)
	band.custom_minimum_size.y = bg.band_h
	var bm := UIKit.margin(band, 20, 6, 20, 6)
	v.add_child(bm)
	var body := UIKit.vbox(14)
	v.add_child(UIKit.margin(body, 22, 18, 22, 20))
	return [p, band, body]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 1.0:
		return
	var inset := 2.0 # borda do cartão
	var w := size.x - inset * 2.0
	var r := radius - inset
	var top := inset + band_h + 12.0
	var bottom := size.y - inset
	# Faixa da competição: degradê horizontal entre os dois tons da transmissão.
	var band := _rounded_rect(Rect2(inset, inset, w, band_h + 12.0), r, true, false)
	var cols := PackedColorArray()
	for pt in band:
		cols.append(band_bg.lerp(band_bg2, (pt.x - inset) / w))
	draw_polygon(band, cols)
	draw_rect(Rect2(inset, inset + band_h + 9.0, w, 3.0), band_accent)
	# Lados nas cores dos clubes (mandante à esquerda), sumindo antes do centro.
	var a := 0.34 if not UIColors.light else 0.2
	if left_color.a > 0.0:
		_side(Rect2(inset, top, w * 0.5, bottom - top), r, left_color, a, false)
	if right_color.a > 0.0:
		_side(Rect2(inset + w * 0.5, top, w * 0.5, bottom - top), r, right_color, a, true)


func _side(rect: Rect2, r: float, col: Color, a: float, right: bool) -> void:
	var pts := PackedVector2Array()
	var steps := 6
	if right:
		pts.append(Vector2(rect.position.x, rect.position.y))
		pts.append(Vector2(rect.end.x, rect.position.y))
		for i in range(steps + 1):
			var ang := float(i) / steps * PI * 0.5
			pts.append(Vector2(rect.end.x - r + cos(ang) * r, rect.end.y - r + sin(ang) * r))
		pts.append(Vector2(rect.position.x, rect.end.y))
	else:
		pts.append(Vector2(rect.position.x, rect.position.y))
		pts.append(Vector2(rect.end.x, rect.position.y))
		pts.append(Vector2(rect.end.x, rect.end.y))
		for i in range(steps + 1):
			var ang := PI * 0.5 + float(i) / steps * PI * 0.5
			pts.append(Vector2(rect.position.x + r + cos(ang) * r, rect.end.y - r + sin(ang) * r))
	var cols := PackedColorArray()
	for pt in pts:
		var t := (pt.x - rect.position.x) / rect.size.x
		if not right:
			t = 1.0 - t
		# t = 1 na borda externa, 0 no centro do cartão.
		var fade := clampf(t, 0.0, 1.0)
		var vy := clampf((pt.y - rect.position.y) / rect.size.y, 0.0, 1.0)
		cols.append(Color(col, a * fade * fade * (0.55 + 0.45 * vy)))
	draw_polygon(pts, cols)


## Retângulo com cantos arredondados só em cima (top) e/ou embaixo (bottom).
func _rounded_rect(rect: Rect2, r: float, top: bool, bottom: bool) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var steps := 6
	var corners := [
		[Vector2(rect.position.x + r, rect.position.y + r), PI, top],
		[Vector2(rect.end.x - r, rect.position.y + r), PI * 1.5, top],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, bottom],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, bottom],
	]
	var sharp := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for k in 4:
		if corners[k][2]:
			for i in range(steps + 1):
				var ang: float = corners[k][1] + float(i) / steps * PI * 0.5
				pts.append(corners[k][0] + Vector2(cos(ang), sin(ang)) * r)
		else:
			pts.append(sharp[k])
	return pts
