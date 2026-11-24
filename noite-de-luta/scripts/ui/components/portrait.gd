class_name Portrait
extends Control
## Retrato leve: a imagem guardada pelo PortraitCache (autoload `Portraits`) sobre um fundo em
## degradê com cantos arredondados, tudo num quadrilátero só. Enquanto a imagem não chega aparece
## a silhueta; quando chega, ela surge por cima.
##
## `tone` é a cor do fundo (a do corner na luta, a da equipe, dourado para o campeão). Com
## `cutout` não há fundo: só o lutador recortado, sumindo na base (cartazes e cabeçalhos).

## A cor do vértice traz o tom do fundo multiplicado pelo `modulate` do nó (no Godot 4 o modulate
## chega pelo vértice): o alfa é a opacidade do conjunto, como em qualquer outro item.
const SHADER_TILE := "
shader_type canvas_item;
uniform float radius = 0.17;
uniform float empty = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	// A textura vem com a cor já multiplicada pela opacidade (foto de um SubViewport transparente).
	// O arquivo em disco é comprimido: cor que sobra onde a opacidade é zero é ruído, e sai aqui.
	vec4 t = texture(TEXTURE, UV) * (1.0 - empty);
	t.rgb = min(t.rgb, vec3(t.a));
	vec3 base = tint.rgb;
	vec3 bg = mix(base * 1.25, base * 0.42, smoothstep(0.0, 1.0, UV.y));
	float glow = max(0.0, 1.0 - length((UV - vec2(0.5, 0.2)) * vec2(1.25, 1.5)));
	bg += vec3(0.14) * glow * glow;
	if (empty > 0.5) {
		vec2 hp = (UV - vec2(0.5, 0.42)) * vec2(1.0, 0.86);
		float head = 1.0 - smoothstep(0.17, 0.19, length(hp));
		vec2 sp = (UV - vec2(0.5, 1.02)) * vec2(0.62, 1.0);
		float body = 1.0 - smoothstep(0.27, 0.29, length(sp));
		bg = mix(bg, bg * 0.62, max(head, body));
	}
	vec3 rgb = bg * (1.0 - t.a) + t.rgb;
	vec2 q = abs(UV - 0.5) - (0.5 - radius);
	float d = length(max(q, 0.0)) - radius;
	float aa = fwidth(d) + 0.0005;
	COLOR = vec4(rgb, (1.0 - smoothstep(-aa, aa, d)) * tint.a);
}
"
const SHADER_CUT := "
shader_type canvas_item;
render_mode blend_premul_alpha;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	t.rgb = min(t.rgb, vec3(t.a)) * tint.rgb;
	COLOR = t * (smoothstep(1.0, 0.84, UV.y) * tint.a);
}
"

static var _mat_tile: ShaderMaterial
static var _mat_empty: ShaderMaterial
static var _mat_cut: ShaderMaterial
static var _blank: Texture2D

## Cor do fundo. Transparente = o tom neutro do tema.
var tone := Color(0, 0, 0, 0):
	set(v):
		tone = v
		queue_redraw()
var cutout := false:
	set(v):
		cutout = v
		_pick_material()
		queue_redraw()
## Espelha o retrato (o lutador do corner azul olha para a esquerda).
var flip := false:
	set(v):
		flip = v
		queue_redraw()

var _spec: Dictionary = {}
var _px := 64
var _key := 0
var _tex: Texture2D
var _asked := false


static func _prepare() -> void:
	if _mat_tile != null:
		return
	var a := Shader.new()
	a.code = SHADER_TILE
	_mat_tile = ShaderMaterial.new()
	_mat_tile.shader = a
	_mat_empty = ShaderMaterial.new()
	_mat_empty.shader = a
	_mat_empty.set_shader_parameter(&"empty", 1.0)
	var b := Shader.new()
	b.code = SHADER_CUT
	_mat_cut = ShaderMaterial.new()
	_mat_cut.shader = b
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_blank = ImageTexture.create_from_image(img)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prepare()
	_pick_material()


func _pick_material() -> void:
	material = _mat_cut if cutout else (_mat_tile if _tex != null else _mat_empty)


## `spec` no formato do PortraitCache; `px` é o lado na tela (escolhe o tamanho guardado).
func setup(spec: Dictionary, px: int) -> Portrait:
	_spec = spec
	_px = px
	custom_minimum_size = Vector2(px, px)
	if is_inside_tree():
		_ask()
	return self


func _enter_tree() -> void:
	if not _spec.is_empty():
		_ask()


func _exit_tree() -> void:
	if _asked and _tex == null:
		Portraits.release(_key, self)
	_asked = false


func _ask() -> void:
	if _asked and _tex == null:
		Portraits.release(_key, self)
	_asked = true
	_key = Portraits.want(_spec, _px, self)
	_tex = Portraits.texture(_key)
	_pick_material()
	queue_redraw()


## O pedido foi descartado quando ninguém olhava e alguém voltou a olhar: pede de novo.
func _retry() -> void:
	_asked = false
	if is_inside_tree():
		_ask()


func _on_texture(tex: Texture2D) -> void:
	_tex = tex
	_pick_material()
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 2.0:
		return
	var r := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	if flip:
		r = Rect2(r.position, Vector2(-s, s))
	if cutout:
		if _tex != null:
			draw_texture_rect(_tex, r, false)
		return
	var base := tone if tone.a > 0.0 else UIColors.PORTRAIT
	draw_texture_rect(_tex if _tex != null else _blank, r, false, Color(base.r, base.g, base.b, 1.0))
