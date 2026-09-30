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
	p.clip_contents = true   # a bandeira é cortada nas bordas do card
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


## Moldura de card: bandeira do país ao fundo (cortada para preencher),
## véu escuro para o busto ilustrado se destacar e filete na cor do corner.
## Sem bandeira conhecida: fundo liso com a faixa diagonal do corner.
func _draw() -> void:
	var w := size.x; var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.SURFACE)
	if FlagView.has_flag(fighter.country):
		var fw := maxf(w, h * 1.5)
		FlagView.paint(self, Rect2((w - fw) * 0.5, (h - fw / 1.5) * 0.5, fw, fw / 1.5), fighter.country)
		var veil := Tokens.CANVAS; veil.a = 0.28
		draw_rect(Rect2(Vector2.ZERO, size), veil)
		var foot := Tokens.CANVAS; foot.a = 0.45
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.72), Vector2(w, h * 0.58), Vector2(w, h), Vector2(0, h)]), foot)
	else:
		var slab := accent; slab.a = 0.9
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.34), Vector2(w, h), Vector2(0, h)]), slab)
	if _texture:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	else:
		var text := PortraitService.initials(fighter)
		var fs := int(w * 0.36)
		var tw := Tokens.DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(Tokens.DISPLAY_FONT, Vector2((w - tw) / 2, h / 2 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.INK)
	draw_rect(Rect2(0, h - 4, w, 4), accent)
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.CANVAS, false, 2.0)
