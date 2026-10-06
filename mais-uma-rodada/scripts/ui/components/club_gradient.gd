class_name ClubGradient
extends Control
## Fundo em degradê na cor do clube, no lugar das faixas diagonais: a cor nasce funda num canto e
## some na superfície, com uma segunda luz bem fraca na outra cor e um pontilhado fino que tira as
## faixas de 8 bits do degradê. Desenho num shader (liso em qualquer tamanho).
##
## Modos:
##   LEFT   cor forte à esquerda, sumindo para a direita (cabeçalho do clube/jogador)
##   RIGHT  o contrário
##   DUAL   mandante à esquerda e visitante à direita, escuro no meio onde fica o texto (jogo)
##   TOP    cor no alto, sumindo para baixo (cartões de destaque)

const LEFT := 0
const RIGHT := 1
const DUAL := 2
const TOP := 3

const SHADER := """
shader_type canvas_item;
uniform vec4 base : source_color;
uniform vec4 c1 : source_color;
uniform vec4 c2 : source_color;
uniform vec4 d1 : source_color;
uniform vec4 d2 : source_color;
uniform int mode = 0;
uniform float reach = 0.75;
uniform float strength = 0.9;
uniform vec2 size_px = vec2(600.0, 200.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec3 col = base.rgb;
	float asp = size_px.x / max(size_px.y, 1.0);
	if (mode == 2) {
		// Dois clubes: cada um nasce na sua borda; o meio fica na superfície
		float wl = 1.0 - smoothstep(0.0, reach * 0.62, uv.x);
		float wr = smoothstep(1.0 - reach * 0.62, 1.0, uv.x);
		wl = wl * wl * (3.0 - 2.0 * wl);
		wr = wr * wr * (3.0 - 2.0 * wr);
		col = mix(col, c1.rgb, wl * strength);
		col = mix(col, d1.rgb, wr * strength);
		// Segunda cor de cada um, bem fraca, na base
		float lb = (1.0 - smoothstep(0.0, 0.35, uv.x)) * smoothstep(0.55, 1.0, uv.y);
		float rb = smoothstep(0.65, 1.0, uv.x) * smoothstep(0.55, 1.0, uv.y);
		col = mix(col, c2.rgb, lb * 0.18);
		col = mix(col, d2.rgb, rb * 0.18);
	} else {
		float t;
		if (mode == 0) {
			t = uv.x;
		} else if (mode == 1) {
			t = 1.0 - uv.x;
		} else {
			t = uv.y;
		}
		// Curva longa (não linear): a cor segura no começo e some devagar
		float w = 1.0 - smoothstep(0.0, reach, t);
		w = pow(w, 1.35);
		// Um leve caimento na vertical dá volume (mais claro no alto)
		float v = mode == 3 ? 1.0 : mix(1.0, 0.82, uv.y);
		col = mix(col, c1.rgb * v, w * strength);
		// Luz fraca da segunda cor no canto oposto de baixo
		vec2 corner = mode == 1 ? vec2(0.0, 1.0) : vec2(1.0, 1.0);
		vec2 dd = (uv - corner) * vec2(asp, 1.0);
		float g = 1.0 - smoothstep(0.0, 0.9 * max(asp, 1.0) * 0.6, length(dd));
		col = mix(col, c2.rgb, g * 0.12);
	}
	// Pontilhado: tira os degraus do degradê
	col += (hash(floor(UV * size_px)) - 0.5) / 255.0;
	COLOR = vec4(col, 1.0);
}
"""

static var _shader: Shader = null

var mode := LEFT
var reach := 0.75
var strength := 0.9
var color1 := Color.BLACK
var color2 := Color.BLACK
var away1 := Color.BLACK
var away2 := Color.BLACK
## Fundo de onde a cor nasce (transparente = a superfície da interface). Os grafismos de TV usam o
## fundo do pacote da competição.
var base_color := Color(0, 0, 0, 0)
var _rect: ColorRect


## Cor funda e legível para o degradê: clara demais (branco, amarelo) escurece para o texto de giz
## continuar legível por cima.
static func deep(c: Color) -> Color:
	var l := c.get_luminance()
	if l > 0.55:
		return c.darkened(0.62)
	if l > 0.35:
		return c.darkened(0.35)
	return c.darkened(0.08)


## Cores de um clube para o degradê: [principal funda, segunda].
static func club_colors(club: Club) -> Array:
	if club == null:
		return [UIColors.SURFACE_2, UIColors.SURFACE_3]
	var a := Color(club.color1)
	var b := Color(club.color2)
	# Camisa clara (branca, creme): a cor da identidade vira a segunda
	var main := a if a.get_luminance() <= 0.75 or b.get_luminance() > 0.75 else b
	var other := b if main == a else a
	return [deep(main), other]


## Fundo para um card: vai como primeiro filho do PanelContainer e cobre o card inteiro.
static func attach(panel: PanelContainer, club: Club, mode_: int = LEFT, away: Club = null) -> PanelContainer:
	var g := ClubGradient.new()
	g.mode = mode_
	var cc := club_colors(club)
	g.color1 = cc[0]
	g.color2 = cc[1]
	if away != null:
		var ca := club_colors(away)
		g.away1 = ca[0]
		g.away2 = ca[1]
	panel.add_child(g)
	panel.move_child(g, 0)
	panel.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	return panel


## Como attach, mas devolve o degradê (para ajustar alcance, força e o fundo). Em Control comum
## (não PanelContainer) o degradê ocupa o controle inteiro.
static func fill(parent: Control, club: Club, mode_: int = LEFT, base: Color = Color(0, 0, 0, 0), reach_: float = 0.75, strength_: float = 0.9) -> ClubGradient:
	var g := ClubGradient.new()
	g.mode = mode_
	g.reach = reach_
	g.strength = strength_
	g.base_color = base
	var cc := club_colors(club)
	g.color1 = cc[0]
	g.color2 = cc[1]
	if not parent is Container:
		g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(g)
	parent.move_child(g, 0)
	parent.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	return g


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	_rect.material = mat
	add_child(_rect)
	var panel := get_parent() as Control
	if panel != null and panel is PanelContainer:
		# Cobre o card até a borda (o próprio card arredonda os cantos)
		var sb := panel.get_theme_stylebox(&"panel")
		if sb != null:
			_rect.position = Vector2(-sb.get_margin(SIDE_LEFT), -sb.get_margin(SIDE_TOP))
			_margins = Vector2(sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT), sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM))
	resized.connect(_apply)
	_apply()


var _margins := Vector2.ZERO


func _apply() -> void:
	if _rect == null:
		return
	_rect.size = size + _margins
	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter(&"base", base_color if base_color.a > 0.0 else UIColors.SURFACE)
	mat.set_shader_parameter(&"c1", color1)
	mat.set_shader_parameter(&"c2", color2)
	mat.set_shader_parameter(&"d1", away1)
	mat.set_shader_parameter(&"d2", away2)
	mat.set_shader_parameter(&"mode", mode)
	mat.set_shader_parameter(&"reach", reach)
	mat.set_shader_parameter(&"strength", strength)
	mat.set_shader_parameter(&"size_px", _rect.size)
