class_name FighterPortrait
extends Control
## Foto do lutador (PortraitService); iniciais enquanto não há imagem.
## Cores só via Tokens (DESIGN.md).

var fighter: Fighter
var accent: Color = Tokens.STEEL
var _texture: Texture2D
var _key := ""


## Componente único de retrato: use em qualquer tela com lutador.
## `accent` é a faixa de base (vermelho/azul no confronto).
static func make(f: Fighter, width: float, accent_color: Color = Tokens.STEEL) -> FighterPortrait:
	var p := FighterPortrait.new()
	p.fighter = f
	p.accent = accent_color
	p.custom_minimum_size = Vector2(width, width * PortraitService.H / PortraitService.W)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p


## Troca o lutador exibido (editor/criador reaproveitam o mesmo nó).
func set_fighter(f: Fighter) -> void:
	fighter = f
	if is_inside_tree():
		_key = PortraitService.key_for(f)
		_texture = PortraitService.service().texture_for(f)
		queue_redraw()


func _ready() -> void:
	var service := PortraitService.service()
	_key = PortraitService.key_for(fighter)
	service.portrait_ready.connect(_on_ready)
	_texture = service.texture_for(fighter)


func _on_ready(key: String) -> void:
	if key != _key: return
	_texture = PortraitService.service().texture_for(fighter)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.SURFACE)
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	else:
		var text := PortraitService.initials(fighter)
		var fs := int(size.x * 0.36)
		var w := Tokens.DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(Tokens.DISPLAY_FONT, Vector2((size.x - w) / 2, size.y / 2 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.MUTED)
	draw_rect(Rect2(0, size.y - 3, size.x, 3), accent)
