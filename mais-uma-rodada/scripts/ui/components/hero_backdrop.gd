class_name HeroBackdrop
extends Control
## Fundo "premium" dos cabeçalhos (perfil do jogador e página do clube): degradê nas cores do
## clube, faixas diagonais discretas e o escudo gigante, meio transparente, saindo pela direita.
## Vai como primeiro filho do PanelContainer do card (fica atrás do conteúdo).

var club: Club = null
var crest_alpha := 0.13
var _crest: CrestView = null


static func make(c: Club, alpha: float = 0.13) -> HeroBackdrop:
	var h := HeroBackdrop.new()
	h.club = c
	h.crest_alpha = alpha
	return h


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
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	if club != null:
		_crest = CrestView.new()
		_crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_crest.set_club(club)
		_crest.modulate = Color(1, 1, 1, crest_alpha)
		add_child(_crest)
	_layout()
	resized.connect(_layout)


func _layout() -> void:
	if _crest == null:
		return
	var s := clampf(size.y * 1.35, 220.0, 420.0)
	_crest.size = Vector2(s, s)
	var y := (size.y - s) * 0.5 + s * 0.08 if size.y * 1.35 <= 420.0 else -s * 0.1
	_crest.position = Vector2(size.x - s * 0.62, y)
	_crest.rotation = deg_to_rad(-8.0)
	_crest.pivot_offset = Vector2(s, s) * 0.5
	queue_redraw()


func _draw() -> void:
	if club == null or size.x <= 1.0:
		return
	var c1 := club.primary_color()
	var c2 := club.secondary_color()
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
