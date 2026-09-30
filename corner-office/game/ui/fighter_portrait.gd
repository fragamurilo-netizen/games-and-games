class_name FighterPortrait
extends Control
## Foto do lutador (PortraitService); iniciais enquanto não há imagem.
## Cores só via Tokens (DESIGN.md).

var fighter: Fighter
var _texture: Texture2D
var _key := ""


static func make(f: Fighter, width: float) -> FighterPortrait:
	var p := FighterPortrait.new()
	p.fighter = f
	p.custom_minimum_size = Vector2(width, width * PortraitService.H / PortraitService.W)
	p.mouse_filter = MOUSE_FILTER_IGNORE
	return p


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
	draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Tokens.STEEL, 2)
