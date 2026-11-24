class_name Anim
extends RefCounted
## Animações curtas da interface, todas desligadas por "Menos animação" (AppSettings) e quando o
## jogo roda sem tela (ferramentas e testes): entrada escalonada dos cartões, números que
## contam, barras que enchem e o pulso de quem mudou de valor.

const STEP := 0.035
const MAX_STAGGER := 9


static func on() -> bool:
	return not AppSettings.reduce_motion and DisplayServer.get_name() != "headless"


## Os cartões entram um depois do outro: aparecem e assentam (escala de 0,97 a 1). Só os
## primeiros `MAX_STAGGER`; o resto entra junto com o último, para a lista não demorar.
static func stagger(nodes: Array, start: float = 0.0) -> void:
	if not on():
		return
	var i := 0
	for n in nodes:
		var c := n as Control
		if c == null or not c.visible:
			continue
		var d := start + STEP * mini(i, MAX_STAGGER)
		i += 1
		c.modulate.a = 0.0
		c.scale = Vector2(0.97, 0.97)
		_center_pivot(c)
		var tw := c.create_tween().set_parallel()
		tw.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(d)
		tw.tween_property(c, "scale", Vector2.ONE, 0.26).set_delay(d).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


static func _center_pivot(c: Control) -> void:
	if c.size.x > 1.0:
		c.pivot_offset = c.size * 0.5
	else:
		(func():
			if is_instance_valid(c):
				c.pivot_offset = c.size * 0.5).call_deferred()


## O número anda de `from` a `to`; `fmt` transforma o valor em texto.
static func count(l: Label, from: float, to: float, fmt: Callable, dur: float = 0.55) -> void:
	l.text = String(fmt.call(to))
	if not on() or is_equal_approx(from, to):
		return
	l.text = String(fmt.call(from))
	var tw := l.create_tween()
	tw.tween_method(func(v: float):
		if is_instance_valid(l):
			l.text = String(fmt.call(v)), from, to, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(l):
			l.text = String(fmt.call(to)))


## Uma propriedade numérica (valor de barra, termômetro, revelação da linha) vai de 0 ao valor.
static func grow(node: Object, prop: String, to: float, dur: float = 0.5, delay: float = 0.0, from: float = 0.0) -> void:
	if not on():
		node.set(prop, to)
		return
	node.set(prop, from)
	var tw := (node as Node).create_tween()
	tw.tween_property(node, prop, to, dur).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Pulso de atenção: cresce um pouco e volta (número que mudou, botão principal liberado).
static func pulse(c: Control, amount: float = 1.08, dur: float = 0.28) -> void:
	if not on() or not is_instance_valid(c):
		return
	_center_pivot(c)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(amount, amount), dur * 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, dur * 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## Pisca a cor do texto e volta (verde quando o caixa sobe, vermelho quando cai).
static func flash(l: Label, color: Color, back: Color, dur: float = 0.9) -> void:
	if not on():
		return
	l.add_theme_color_override(&"font_color", color)
	var tw := l.create_tween()
	tw.tween_interval(dur * 0.55)
	tw.tween_method(func(k: float):
		if is_instance_valid(l):
			l.add_theme_color_override(&"font_color", color.lerp(back, k)), 0.0, 1.0, dur * 0.45)
