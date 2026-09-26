class_name HeroBackdrop
extends Control
## Fundo "premium" dos cabeçalhos (perfil do jogador e página do clube): degradê nas cores do
## clube, faixas diagonais discretas e o escudo gigante, meio transparente, saindo pela direita.
## Vai como primeiro filho do PanelContainer do card (fica atrás do conteúdo).

var club: Club = null
var crest_alpha := 0.13
## Estilo limpo (perfil do jogador): brilho na cor do clube atrás do retrato, escudo como marca
## d'água monocromática saindo pela direita, sem faixas diagonais.
var clean := false
## Centro do brilho no modo limpo (px dentro do card); negativo = sem brilho.
var glow_at := Vector2(-1, -1)
var _crest: CrestView = null
## Margens do card (modo limpo): o fundo cobre o card inteiro, não só a área do conteúdo.
var _m := Vector4.ZERO

const WATERMARK_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(tint.rgb, tint.a * step(0.02, COLOR.a));
}
"""


static func make(c: Club, alpha: float = 0.13) -> HeroBackdrop:
	var h := HeroBackdrop.new()
	h.club = c
	h.crest_alpha = alpha
	return h


## Versão limpa para o cabeçalho do perfil: brilho atrás do retrato e escudo em marca d'água.
static func attach_clean(panel: PanelContainer, c: Club, glow: Vector2) -> PanelContainer:
	if c == null:
		return panel
	var h := make(c, 0.07)
	h.clean = true
	h.glow_at = glow
	panel.add_child(h)
	panel.move_child(h, 0)
	return panel


## Coloca o fundo atrás do conteúdo de um card já montado (UIKit.card_panel).
static func attach(panel: PanelContainer, c: Club, alpha: float = 0.13) -> PanelContainer:
	if c == null:
		return panel
	var h := make(c, alpha)
	panel.add_child(h)
	panel.move_child(h, 0)
	return panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	var panel := get_parent() as Control
	if clean and panel != null:
		# Desenha além da área de conteúdo, até a borda do card; o próprio card (cantos
		# arredondados) recorta o desenho.
		clip_contents = false
		var sb := panel.get_theme_stylebox(&"panel")
		if sb != null:
			_m = Vector4(sb.get_margin(SIDE_LEFT), sb.get_margin(SIDE_TOP), sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_BOTTOM))
		panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if club != null:
		_crest = CrestView.new()
		_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crest.set_club(club)
		if clean:
			# Silhueta branca bem fraca: cada camada do escudo vira o mesmo tom, sem as cores
			var mat := ShaderMaterial.new()
			var sh := Shader.new()
			sh.code = WATERMARK_SHADER
			mat.shader = sh
			mat.set_shader_parameter(&"tint", Color(1, 1, 1, 0.035) if not UIColors.light else Color(0, 0, 0, 0.035))
			_crest.material = mat
		else:
			_crest.modulate = Color(1, 1, 1, crest_alpha)
		add_child(_crest)
	_layout()
	resized.connect(_layout)


func _layout() -> void:
	if _crest == null:
		return
	# O escudo fica inteiro dentro do card (encostado à direita), sem alargar o layout.
	if clean:
		# Grande, inclinado e cortado pela borda direita, longe do nome e do retrato
		var full := _full()
		var sc := clampf(full.size.y * 1.0, 220.0, 480.0)
		_crest.size = Vector2(sc, sc)
		_crest.pivot_offset = Vector2(sc, sc) * 0.5
		_crest.position = Vector2(full.end.x - sc * 0.6, full.position.y - sc * 0.1)
		_crest.rotation = deg_to_rad(-12.0)
		queue_redraw()
		return
	var s := clampf(minf(size.y * 1.1, size.x * 0.55), 160.0, 360.0)
	_crest.size = Vector2(s, s)
	var y := (size.y - s) * 0.5 if size.y <= s * 1.3 else 8.0
	_crest.position = Vector2(size.x - s - 6.0, y)
	_crest.rotation = 0.0
	queue_redraw()


func _draw() -> void:
	if club == null or size.x <= 1.0:
		return
	var c1 := club.primary_color()
	var c2 := club.secondary_color()
	if clean:
		_draw_clean(c1, c2)
		return
	# Degradê: a cor do clube nasce à direita e some antes da metade.
	var steps := 24
	for i in steps:
		var t := float(i) / steps
		var x0 := size.x * (0.35 + 0.65 * t)
		var w := size.x * 0.65 / steps + 1.0
		var col := c1
		col.a = 0.02 + 0.2 * t * t
		draw_rect(Rect2(x0, 0, w, size.y), col)
	# Faixas diagonais finas na segunda cor, como textura de camisa.
	var band := c2
	band.a = 0.05
	var step := 34.0
	var x := size.x * 0.45
	while x < size.x + size.y:
		draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 12.0, 0), Vector2(x + 12.0 - size.y, size.y), Vector2(x - size.y, size.y)]), band)
		x += step
	# Filete na cor do clube na base do card.
	var line := c1
	line.a = 0.85
	draw_rect(Rect2(0, size.y - 4.0, size.x, 4.0), line)


func _full() -> Rect2:
	return Rect2(-_m.x, -_m.y, size.x + _m.x + _m.z, size.y + _m.y + _m.w)


func _draw_clean(c1: Color, c2: Color) -> void:
	var full := _full()
	# Topo tingido pela cor do clube, sumindo até pouco depois da metade (faixas com vértices
	# coloridos que dividem as bordas exatas: sem linhas de sobreposição)
	var steps := 8
	var band := full.size.y * 0.6
	for i in steps:
		var t0 := float(i) / steps
		var t1 := float(i + 1) / steps
		var y0 := full.position.y + band * t0
		var y1 := full.position.y + band * t1
		var a0 := Color(c1, 0.22 * pow(1.0 - t0, 1.8))
		var a1 := Color(c1, 0.22 * pow(1.0 - t1, 1.8))
		draw_polygon(PackedVector2Array([Vector2(full.position.x, y0), Vector2(full.end.x, y0), Vector2(full.end.x, y1), Vector2(full.position.x, y1)]),
			PackedColorArray([a0, a0, a1, a1]))
	# Brilho macio atrás do retrato
	if glow_at.x >= 0.0:
		var r := minf(full.size.y * 0.7, 260.0)
		for i in 18:
			var t := float(i) / 17.0
			var col := c1.lightened(0.15)
			col.a = 0.035
			draw_circle(glow_at, r * (1.0 - t * 0.85), col)
	# Filete na base: cor principal que passa para a segunda e some à direita
	var c_end := c2 if c2.get_luminance() > 0.15 else c1.lightened(0.3)
	var n := 12
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var k0 := Color(c1.lerp(c_end, t0), 0.95 * (1.0 - smoothstep(0.55, 1.0, t0)))
		var k1 := Color(c1.lerp(c_end, t1), 0.95 * (1.0 - smoothstep(0.55, 1.0, t1)))
		var x0 := full.position.x + full.size.x * t0
		var x1 := full.position.x + full.size.x * t1
		draw_polygon(PackedVector2Array([Vector2(x0, full.end.y - 3.0), Vector2(x1, full.end.y - 3.0), Vector2(x1, full.end.y), Vector2(x0, full.end.y)]),
			PackedColorArray([k0, k1, k1, k0]))
