class_name IntroOverlay
extends Control
## Abertura do jogo. Começa igual à imagem de abertura da engine (o emblema parado no meio, no
## mesmo tamanho e sobre a mesma cor), para a passagem não dar salto: os dois fachos de luz
## chegam, o gongo toca, o emblema pulsa e abre espaço para o nome e a chamada. Depois some e
## deixa o menu. Um toque pula.

## O menu (por baixo) pode começar a entrar.
signal leaving

## A cor de `boot_splash/bg_color` (project.godot).
const BG := Color(0.054902, 0.054902, 0.062745)
## O emblema ocupa esta fração do lado menor da tela (como em assets/brand/abertura.png).
const EMBLEM_SHARE := 0.40
const HOLD := 2.25

var _back: BrandBackdrop
var _logo: BrandLogo
var _tw: Tween
var _gone := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var view := get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_back = BrandBackdrop.new()
	_back.beam = 0.0
	add_child(_back)
	var side := minf(view.x, view.y)
	var emblem_px := side * EMBLEM_SHARE
	# Celular deitado: o nome vai ao lado do emblema (embaixo não cabe).
	_logo = BrandLogo.new(emblem_px, int(round(emblem_px * 0.49)), view.x > view.y and view.y < 900.0)
	_logo.custom_minimum_size = Vector2.ZERO
	_logo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_logo)
	_logo.mix = 0.0
	_logo.bar_grow = 0.0
	_logo.word_a.modulate.a = 0.0
	_logo.word_b.modulate.a = 0.0
	_logo.tagline.modulate.a = 0.0
	_logo.place()
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(_back, "beam", 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.10)
	_tw.tween_callback(_bell).set_delay(0.40)
	_tw.tween_property(_logo, "mix", 1.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT).set_delay(0.66)
	_tw.tween_property(_logo.word_a, "modulate:a", 1.0, 0.24).set_delay(0.86)
	_logo.word_b.scale = Vector2(1.16, 1.16)
	_tw.tween_property(_logo.word_b, "modulate:a", 1.0, 0.2).set_delay(0.98)
	_tw.tween_property(_logo.word_b, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.98)
	_tw.tween_property(_logo, "bar_grow", 1.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(1.2)
	_tw.tween_property(_logo.tagline, "modulate:a", 1.0, 0.3).set_delay(1.32)
	_tw.tween_callback(leave).set_delay(HOLD)


func _process(_delta: float) -> void:
	if _back != null and _logo != null:
		_back.focus = _logo.emblem_focus()


## O gongo: som, vibração, o emblema pulsa e solta um eco que cresce e some.
func _bell() -> void:
	Sfx.play("gongo", -5.0)
	Sfx.vibrate(30)
	var e := _logo.emblem
	var tw := e.create_tween()
	tw.tween_property(e, "scale", Vector2(1.09, 1.09), 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(e, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var ghost := TextureRect.new()
	ghost.texture = e.texture
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = e.size
	ghost.position = e.position
	ghost.pivot_offset = e.size * 0.5
	ghost.modulate = Color(1, 1, 1, 0.5)
	_logo.add_child(ghost)
	_logo.move_child(ghost, 0)
	var gt := ghost.create_tween().set_parallel(true)
	gt.tween_property(ghost, "scale", Vector2(1.8, 1.8), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gt.tween_property(ghost, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	gt.chain().tween_callback(ghost.queue_free)
	var st := _back.create_tween()
	st.tween_property(_back, "strength", 1.6, 0.08)
	st.tween_property(_back, "strength", 1.0, 0.5)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		accept_event()
		leave()


## Sai de cena: o toque passa a valer para o menu na hora, e a abertura some por cima dele.
func leave() -> void:
	if _gone:
		return
	_gone = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _tw != null:
		_tw.kill()
	leaving.emit()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(queue_free)
