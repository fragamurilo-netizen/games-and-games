class_name MatchHero
extends Control
## Fundo do cartão de dia de jogo (hub, pré-jogo): faixa superior na identidade da competição
## (cores da transmissão da liga ou copa, ScoreboardTheme) e, embaixo, o gramado visto de cima:
## faixas de corte, linha do meio e círculo central de cal, com a cor de cada clube nascendo da
## sua borda (mandante à esquerda) e sumindo antes do meio-campo. Vai como primeiro filho de um PanelContainer sem
## margens internas (ver `wrap`).

var band_h := 58.0
var band_bg := Color("#0F1012")
var band_bg2 := Color("#18191C")
var band_accent := Color("#FFC940")
var left_color := Color(0, 0, 0, 0)
var right_color := Color(0, 0, 0, 0)
var left_color2 := Color(0, 0, 0, 0)
var right_color2 := Color(0, 0, 0, 0)
var radius := float(UITokens.R_SM)
## Degradê dos clubes no corpo do cartão (abaixo da faixa da competição).
var body_bg: ClubGradient = null
## Onde fica o centro do círculo central, medido do alto do gramado (a altura do "×" entre os
## escudos); 0 = meio do gramado.
var center_y := 0.0
## Corpo no gramado (ver `wrap`).
var pitch := false
## Quanto a grama escurece para o texto de cal ler por cima.
const GRASS_DARK := 0.36


## Monta o painel: devolve [painel, caixa da faixa, caixa do corpo]. Os filhos vão nas caixas.
## Com `pitch`, o corpo é o gramado (bloco do próximo jogo); sem ele, a superfície da interface
## (confrontos e comparações, que têm muita leitura por cima).
static func wrap(w: GameWorld, comp: String, home: Club, away: Club, pitch: bool = false) -> Array:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE
	box.set_corner_radius_all(UITokens.R_SM)
	box.anti_aliasing = true
	box.corner_detail = 8
	p.add_theme_stylebox_override(&"panel", box)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW # a grama respeita os cantos do cartão
	var bg := MatchHero.new()
	bg.pitch = pitch
	var st := ScoreboardTheme.for_competition(w, comp)
	bg.band_bg = st["bg"]
	bg.band_bg2 = st["bg2"]
	bg.band_accent = st["accent"]
	if home != null:
		bg.left_color = home.primary_color()
		bg.left_color2 = home.secondary_color()
	if away != null:
		bg.right_color = away.primary_color()
		bg.right_color2 = away.secondary_color()
	p.add_child(bg)
	# Corpo: mandante nasce na borda esquerda, visitante na direita, escuro no meio (sem faixas)
	var g := ClubGradient.new()
	g.mode = ClubGradient.DUAL
	g.reach = 0.82 if pitch else 0.9
	g.strength = 0.92 if pitch else 0.85
	g.veil = pitch
	var ch := ClubGradient.club_colors(home)
	var ca := ClubGradient.club_colors(away)
	g.color1 = ch[0]
	g.color2 = ch[1]
	g.away1 = ca[0]
	g.away2 = ca[1]
	bg.add_child(g)
	bg.body_bg = g
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


## Prende o círculo central à altura de um controle do corpo (o "×" ou o placar entre os escudos).
static func pin_center(panel: PanelContainer, at: Control) -> void:
	var bg := panel.get_child(0) as MatchHero
	if bg == null or at == null:
		return
	var upd := func() -> void:
		if not is_instance_valid(bg) or not is_instance_valid(at) or not at.is_inside_tree() or not bg.is_inside_tree():
			return
		var y := at.global_position.y + at.size.y * 0.5 - bg.global_position.y - (bg.band_h + 12.0)
		if absf(y - bg.center_y) > 0.5:
			bg.center_y = y
			bg.queue_redraw()
	at.item_rect_changed.connect(upd)
	bg.resized.connect(upd)
	upd.call_deferred()


## Texto de cal em tudo o que está sobre o gramado, no modo escuro e no claro (o que já tem cor
## própria, como um aviso em vermelho, fica como está). Chamar depois de montar o corpo.
static func chalk_text(root: Node) -> void:
	for n in root.get_children():
		if n is Label and not (n as Label).has_theme_color_override(&"font_color"):
			var soft := String((n as Label).theme_type_variation) in ["Small", "Muted", "Meta", "Caps"]
			(n as Label).add_theme_color_override(&"font_color", Grass.chalk(0.8) if soft else Grass.CHALK)
		if not n is BaseButton:
			chalk_text(n)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(queue_redraw)


func _draw() -> void:
	if size.x <= 1.0:
		return
	var inset := 0.0 # o cartão não tem borda
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
	# Lados nas cores dos clubes (mandante à esquerda): faixas chapadas com corte diagonal,
	# como no grafismo de uma transmissão. Cor cheia, sem degradê nem brilho.
	# Gramado: faixas de corte, linha do meio e círculo central.
	if pitch:
		var field := Rect2(0, top, size.x, maxf(0.0, bottom - top))
		Grass.stripes(self, field, size.x / 8.0, GRASS_DARK)
		var cy := top + (center_y if center_y > 0.0 else field.size.y * 0.5)
		Grass.center_mark(self, Vector2(size.x * 0.5, cy), minf(size.x * 0.13, 78.0), field, 0.32)
	if body_bg != null:
		body_bg.position = Vector2(0, top)
		body_bg.size = Vector2(size.x, maxf(0.0, bottom - top))
	elif left_color.a > 0.0 or right_color.a > 0.0:
		if left_color.a > 0.0:
			_slab(top, bottom, left_color, left_color2, false)
		if right_color.a > 0.0:
			_slab(top, bottom, right_color, right_color2, true)


func _slab(top: float, bottom: float, c1: Color, c2: Color, right: bool) -> void:
	var w := size.x
	var h := bottom - top
	var a := 12.0
	var b := 7.0
	var cut := minf(h * 0.07, 22.0)
	var outer := w if right else 0.0
	var dir := -1.0 if right else 1.0
	var main := PackedVector2Array([
		Vector2(outer, top), Vector2(outer + dir * (a + cut), top),
		Vector2(outer + dir * a, bottom), Vector2(outer, bottom)])
	draw_colored_polygon(main, Color(c1, 1.0))
	if c2.a > 0.0:
		var x0 := outer + dir * (a + 4.0)
		var sec := PackedVector2Array([
			Vector2(x0 + dir * cut, top), Vector2(x0 + dir * (cut + b), top),
			Vector2(x0 + dir * b, bottom), Vector2(x0, bottom)])
		draw_colored_polygon(sec, Color(c2, 1.0))


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
