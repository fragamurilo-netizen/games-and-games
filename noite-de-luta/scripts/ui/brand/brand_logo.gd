class_name BrandLogo
extends Control
## A marca do jogo: o emblema, "NOITE DE", "LUTA", o filete dourado e a chamada. As peças são
## postas à mão (não por contêiner) porque a abertura anima cada uma: `mix` vai de 0 (só o
## emblema, no meio) a 1 (o conjunto todo no meio). Em tela deitada o nome fica ao lado.

const EMBLEM := preload("res://assets/brand/emblema.png")
const FONT := preload("res://assets/fonts/Saira-Variable.ttf")
## O desenho ocupa 94% da textura do emblema.
const EMBLEM_FILL := 0.94
const TAGLINE := "Sua equipe. Sua liga. Sua noite."

var emblem: TextureRect
var word_a: Label
var word_b: Label
var bar: ColorRect
var tagline: Label

## Diâmetro do emblema, em unidades de tela.
var emblem_px := 200.0
var big_px := 118
var side_by_side := false
var mix := 1.0:
	set(v):
		mix = v
		place()
## Quanto do filete já apareceu (0 a 1).
var bar_grow := 1.0:
	set(v):
		bar_grow = v
		place()


static func font(weight: float, width: float, spacing: int = 0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = FONT
	f.variation_opentype = {"weight": weight, "width": width}
	f.spacing_glyph = spacing
	f.spacing_top = -2
	f.spacing_bottom = -3
	return f


func _init(p_emblem := 200.0, p_big := 118, p_side := false, with_tagline := false) -> void:
	emblem_px = p_emblem
	big_px = p_big
	side_by_side = p_side
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	emblem = TextureRect.new()
	emblem.texture = EMBLEM
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(emblem)
	word_a = _word("NOITE DE", int(round(big_px * 0.39)), 800.0, maxi(1, int(round(big_px * 0.022))))
	word_b = _word("LUTA", big_px, 900.0, 1)
	bar = ColorRect.new()
	bar.color = UIColors.D_GOLD
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	tagline = UIKit.label(TAGLINE, "Muted")
	tagline.add_theme_font_size_override(&"font_size", maxi(20, int(round(big_px * 0.2))))
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline.visible = with_tagline
	add_child(tagline)
	resized.connect(place)
	_fit_min()


func _word(text: String, px: int, weight: float, spacing: int) -> Label:
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.add_theme_font_override(&"font", font(weight, 87.5, spacing))
	l.add_theme_font_size_override(&"font_size", px)
	l.add_theme_color_override(&"font_color", UIColors.D_TEXT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _emblem_side() -> float:
	return emblem_px / EMBLEM_FILL


func _bar_size() -> Vector2:
	return Vector2(round(big_px * 0.62), maxf(4.0, round(big_px * 0.045)))


## A fonte (Saira) guarda muito espaço acima das maiúsculas e abaixo da linha de base; o bloco
## é medido pela tinta: do topo de "NOITE DE" até a base da chamada.
const ASCENT := 1.135
const CAP := 0.69


func _px(l: Label) -> float:
	return float(l.get_theme_font_size(&"font_size"))


## Altura das duas palavras e do filete (sem a chamada), pela tinta.
func _mark_height() -> float:
	return _px(word_a) * CAP + big_px * 0.15 + big_px * CAP + big_px * 0.17 + _bar_size().y


func _words_size() -> Vector2:
	var w := maxf(word_a.get_minimum_size().x, word_b.get_minimum_size().x)
	var h := _mark_height()
	if tagline.visible:
		var t := tagline.get_minimum_size()
		w = maxf(w, t.x)
		h += big_px * 0.10 + t.y
	return Vector2(w, h)


func _gap() -> float:
	return emblem_px * (0.16 if side_by_side else 0.10)


## Tamanho do conjunto inteiro (com `mix` = 1).
func full_size() -> Vector2:
	var w := _words_size()
	if side_by_side:
		return Vector2(emblem_px + _gap() + w.x, maxf(emblem_px, w.y))
	return Vector2(maxf(emblem_px, w.x), emblem_px + _gap() + w.y)


func _fit_min() -> void:
	custom_minimum_size = full_size()


## Põe cada peça no lugar. O conjunto fica centrado no controle; com `mix` menor que 1 tudo
## anda de volta até o emblema ficar sozinho no centro.
func place() -> void:
	if emblem == null:
		return
	var full := full_size()
	var w := _words_size()
	var center := size * 0.5
	var origin := center - full * 0.5
	var e_center: Vector2
	var words_at: Vector2
	if side_by_side:
		e_center = origin + Vector2(emblem_px * 0.5, full.y * 0.5)
		words_at = origin + Vector2(emblem_px + _gap(), (full.y - w.y) * 0.5)
	else:
		e_center = origin + Vector2(full.x * 0.5, emblem_px * 0.5)
		words_at = origin + Vector2((full.x - w.x) * 0.5, emblem_px + _gap())
	var shift := (center - e_center) * (1.0 - clampf(mix, 0.0, 1.0))
	var side := _emblem_side()
	emblem.size = Vector2(side, side)
	emblem.position = e_center + shift - emblem.size * 0.5
	emblem.pivot_offset = emblem.size * 0.5
	var y := words_at.y + shift.y
	var x := words_at.x + shift.x
	for l: Label in [word_a, word_b]:
		var m := l.get_minimum_size()
		var px := _px(l)
		l.size = m
		# `y` é o topo das maiúsculas; a caixa do texto começa acima dele.
		l.position = Vector2(x if side_by_side else x + (w.x - m.x) * 0.5, y - px * (ASCENT - CAP) + 2.0)
		l.pivot_offset = Vector2(m.x * 0.5, px * (ASCENT - CAP * 0.5))
		y += px * CAP + big_px * (0.15 if l == word_a else 0.17)
	var bs := _bar_size()
	bar.size = Vector2(bs.x * clampf(bar_grow, 0.0, 1.0), bs.y)
	bar.position = Vector2(x if side_by_side else x + (w.x - bs.x) * 0.5, y)
	y += bs.y + big_px * 0.10
	if tagline.visible:
		var t := tagline.get_minimum_size()
		tagline.size = t
		tagline.position = Vector2(x if side_by_side else x + (w.x - t.x) * 0.5, y)


## Centro do emblema, em fração do tamanho do controle (para a luz de fundo mirar nele).
func emblem_focus() -> Vector2:
	if size.x < 1.0 or size.y < 1.0:
		return Vector2(0.5, 0.5)
	return (emblem.position + emblem.size * 0.5) / size
