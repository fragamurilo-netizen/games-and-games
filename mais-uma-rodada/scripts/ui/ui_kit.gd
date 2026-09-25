class_name UIKit
extends RefCounted
## Fábrica de widgets padronizados (mantém todas as telas com o mesmo visual).

static var _icons: Dictionary = {}


static func icon(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://assets/icons/%s.svg" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


static func label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func colored(text: String, color: Color, variation: String = "", wrap: bool = false) -> Label:
	var l := label(text, variation, wrap)
	l.add_theme_color_override(&"font_color", color)
	return l


static func button(text: String, variation: String = "", cb: Callable = Callable(), icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text
	if variation != "":
		b.theme_type_variation = variation
	if icon_name != "":
		b.icon = icon(icon_name)
		b.expand_icon = false # largura limitada por icon_max_width do tema
	if cb.is_valid():
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
	b.custom_minimum_size.y = 72 if variation != "ChipButton" else 52
	b.focus_mode = Control.FOCUS_NONE
	press_fx(b)
	return b


static func icon_button(icon_name: String, cb: Callable, tip: String = "") -> Button:
	var b := Button.new()
	b.theme_type_variation = "IconButton"
	b.icon = icon(icon_name)
	b.expand_icon = false
	b.custom_minimum_size = Vector2(64, 64)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	press_fx(b, null, 0.9)
	if cb.is_valid():
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
	return b


## Chip selecionável; com ButtonGroup vira um seletor exclusivo.
static func chip(text: String, pressed: bool, group: ButtonGroup, cb: Callable) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ChipButton"
	b.text = text
	b.toggle_mode = true
	b.button_group = group
	b.button_pressed = pressed
	b.custom_minimum_size.y = 52
	b.focus_mode = Control.FOCUS_NONE
	press_fx(b, null, 0.94)
	if cb.is_valid():
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
	return b


## Resposta ao toque: o alvo (o próprio botão, ou o card/linha que ele cobre) encolhe um
## pouco enquanto está pressionado e volta ao soltar ou quando o toque vira rolagem.
static func press_fx(b: BaseButton, target: Control = null, amount: float = 0.96) -> void:
	var t: Control = target if target != null else b
	b.button_down.connect(func(): _press_scale(t, amount))
	b.button_up.connect(func(): _press_scale(t, 1.0))
	b.mouse_exited.connect(func(): _press_scale(t, 1.0))
	# Sumiu no meio do toque (troca de tela, rolagem): volta ao tamanho normal na hora
	b.visibility_changed.connect(func(): _press_reset(t))


static func _press_scale(t: Control, s: float) -> void:
	if not is_instance_valid(t) or not t.is_inside_tree():
		return
	# Um único tween por alvo: apertar e soltar rápido não deixa dois brigando (e o alvo
	# nunca fica preso encolhido).
	var old: Variant = t.get_meta(&"press_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	if is_equal_approx(t.scale.x, s):
		t.scale = Vector2(s, s)
		return
	t.pivot_offset = t.size / 2.0
	var tw := t.create_tween()
	tw.tween_property(t, "scale", Vector2(s, s), 0.07 if s < 1.0 else 0.12)
	t.set_meta(&"press_tw", tw)


static func _press_reset(t: Control) -> void:
	if not is_instance_valid(t):
		return
	var old: Variant = t.get_meta(&"press_tw", null)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	t.scale = Vector2.ONE


## Garante que `root` caiba em `max_w`: textos de uma linha que empurram a largura mínima
## além da tela passam a cortar com "…" (o texto inteiro fica na dica). Sem isso a tela
## inteira ficava mais larga que o celular e parecia "com zoom".
static func fit_width(root: Control, max_w: float) -> void:
	for _i in 16:
		if root.get_combined_minimum_size().x <= max_w + 0.5:
			return
		var worst: Label = null
		var worst_w := 0.0
		for n in root.find_children("*", "Label", true, false):
			var l := n as Label
			if not l.is_visible_in_tree() or l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.clip_text \
					or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
				continue
			var w := l.get_combined_minimum_size().x
			if w > worst_w:
				worst_w = w
				worst = l
		if worst == null:
			return
		worst.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		worst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		worst.custom_minimum_size.x = minf(worst_w, max_w * 0.22)
		if worst.tooltip_text == "":
			worst.tooltip_text = worst.text


static func hbox(sep: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", sep)
	return h


static func vbox(sep: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", sep)
	return v


## Card com um VBox interno. Retorna o VBox (o card é o pai).
static func card(variation: String = "Card", sep: int = 10) -> VBoxContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = variation
	var v := vbox(sep)
	p.add_child(v)
	return v


static func card_panel(v: VBoxContainer) -> PanelContainer:
	return v.get_parent() as PanelContainer


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func gap(px: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func crest(c: Club, px: int) -> CrestView:
	var v := CrestView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c != null:
		v.set_club(c)
	return v


static func flag(code: String, w: int) -> FlagView:
	var v := FlagView.new()
	v.custom_minimum_size = Vector2(w, roundi(w / 1.5))
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.code = code
	return v


static func kit(k: Dictionary, px: int, number: int = 0) -> KitView:
	var v := KitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.kit = k
	v.number = number
	return v


static func badge(value: int, w: int = 56, h: int = 40, fs: int = 26) -> RatingBadge:
	var b := RatingBadge.new()
	b.value = value
	b.custom_minimum_size = Vector2(w, h)
	b.font_size = fs
	return b


static func text_badge(text: String, color: Color, w: int = 60, h: int = 34, fs: int = 20) -> RatingBadge:
	var b := RatingBadge.new()
	b.text_override = text
	b.color_override = color
	b.custom_minimum_size = Vector2(w, h)
	b.font_size = fs
	return b


static func pos_badge(pos: int) -> RatingBadge:
	return text_badge(Pos.code(pos), Pos.group_color(pos), 58, 34, 20)


static func portrait(p: Player, club: Club, year: int, px: int) -> PortraitView:
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_player(p, club, year)
	return v


static func bar(value: float, max_value: float, color: Color, h: int = 10) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = max_value
	pb.value = value
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, h)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(h / 2)
	pb.add_theme_stylebox_override(&"fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.SURFACE_3
	bg.set_corner_radius_all(h / 2)
	pb.add_theme_stylebox_override(&"background", bg)
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb


static func section(text: String) -> Label:
	return label(text.to_upper(), "Caps")


static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Bloco "valor grande + legenda pequena".
static func stat(value: String, caption: String, color: Color = UIColors.TEXT) -> VBoxContainer:
	var v := vbox(0)
	var l := label(value, "Stat")
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := label(caption, "Small")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	v.add_child(c)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func icon_rect(name: String, px: int, tint: Color = Color.WHITE) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	t.modulate = tint
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Logo de uma competição: a imagem importada no editor ou um selo com as cores da liga/copa.
static func comp_logo(comp: String, px: int) -> Control:
	var tex := Overrides.logo_of(comp)
	if tex != null:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(px, px)
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tr
	var cols := CompText.colors(comp)
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = cols[0]
	box.border_color = cols[1]
	box.set_border_width_all(maxi(2, px / 16))
	box.set_corner_radius_all(px / 4)
	p.add_theme_stylebox_override(&"panel", box)
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint: Color = cols[1]
	if absf(tint.get_luminance() - cols[0].get_luminance()) < 0.25:
		tint = UIColors.on_color(cols[0])
	var ic := icon_rect("trophy", int(px * 0.6), tint)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(ic)
	return p


## Faixa fina com as duas cores de uma competição (abaixo de cabeçalhos).
static func comp_stripe(comp: String, h: int = 6) -> Control:
	var cols := CompText.colors(comp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 2:
		var r := ColorRect.new()
		r.color = cols[i]
		r.custom_minimum_size = Vector2(0, h)
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.size_flags_stretch_ratio = 3.0 if i == 0 else 1.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(r)
	return row


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## Linha "rótulo ........ valor".
static func kv(key: String, value: String, value_color: Color = UIColors.TEXT) -> HBoxContainer:
	var h := hbox(8)
	var k := label(key, "Muted")
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(k)
	var v := label(value, "H3")
	v.add_theme_color_override(&"font_color", value_color)
	h.add_child(v)
	return h


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_left", l)
	m.add_theme_constant_override(&"margin_top", t)
	m.add_theme_constant_override(&"margin_right", r)
	m.add_theme_constant_override(&"margin_bottom", b)
	m.add_child(child)
	return m


## Linha clicável que se ajusta ao conteúdo: painel + botão transparente por cima.
## toggle=true mantém o destaque de selecionado (use set_row_selected).
static func tap_row(inner: Control, cb: Callable, panel_variation: String = "RowPanel", toggle: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = panel_variation
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ignore_mouse(inner)
	p.add_child(inner)
	var b := Button.new()
	b.theme_type_variation = "RowOverlay"
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = toggle
	b.name = "Tap"
	press_fx(b, p, 0.98)
	if cb.is_valid():
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
	p.add_child(b)
	return p


static func set_row_selected(row: PanelContainer, selected: bool) -> void:
	var b := row.get_node_or_null("Tap") as Button
	if b != null:
		b.set_pressed_no_signal(selected)


static func _ignore_mouse(n: Node) -> void:
	for c in n.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse(c)


## Etiqueta arredondada que se ajusta ao texto (tags de perfil, arquétipos, zonas).
static func pill(text: String, color: Color, font_size: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.16)
	box.border_color = Color(color.r, color.g, color.b, 0.7)
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	p.add_theme_stylebox_override(&"panel", box)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, "Caps")
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_font_size_override(&"font_size", font_size)
	p.add_child(l)
	return p


## Container que quebra linha automaticamente (para listas de etiquetas).
static func flow(sep: int = 8) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override(&"h_separation", sep)
	f.add_theme_constant_override(&"v_separation", sep)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f
