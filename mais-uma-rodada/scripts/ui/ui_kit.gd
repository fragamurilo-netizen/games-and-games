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
	var old: Variant = t.get_meta(&"press_tw") if t.has_meta(&"press_tw") else null
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
	var old: Variant = t.get_meta(&"press_tw") if t.has_meta(&"press_tw") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	t.scale = Vector2.ONE


## Garante que `root` caiba em `max_w`: textos de uma linha que empurram a largura mínima
## além da tela passam a cortar com "…" (o texto inteiro fica na dica). Sem isso a tela
## inteira ficava mais larga que o celular e parecia "com zoom".
static func fit_width(root: Control, max_w: float) -> void:
	for _i in 24:
		if layout_need(root) <= max_w + 0.5:
			return
		var worst: Control = null
		var worst_w := 0.0
		for n in root.find_children("*", "", true, false):
			if not (n is Label or n is Button) or not (n as Control).is_visible_in_tree():
				continue
			if n is Label:
				var l := n as Label
				if l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
					continue
			else:
				var b := n as Button
				# Numa FlowContainer eles precisam do tamanho natural
				if b.clip_text or b.text == "" or b.autowrap_mode != TextServer.AUTOWRAP_OFF or b.get_parent() is FlowContainer:
					continue
			var w := (n as Control).get_combined_minimum_size().x
			if w > worst_w:
				worst_w = w
				worst = n
		if worst == null:
			return
		if worst is Button and not (worst.get_parent() is HBoxContainer):
			# Botão sozinho numa coluna: o texto quebra em linhas.
			(worst as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			continue
		if worst is Button:
			# Todos os botões da linha encolhem juntos (as abas continuam do mesmo tamanho)
			for sib in worst.get_parent().get_children():
				if sib is Button and (sib as Button).text != "":
					shrink_button(sib)
			continue
		var wl := worst as Label
		wl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		wl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wl.custom_minimum_size.x = minf(worst_w, max_w * 0.22)
		if wl.tooltip_text == "":
			wl.tooltip_text = wl.text


## Largura mínima que o conteúdo de `root` exige. Uma tela é um Control simples (não um
## container): o mínimo dela é 0 e quem cresce são os filhos ancorados (Body), então medimos eles.
static func layout_need(root: Control) -> float:
	var need := root.get_combined_minimum_size().x
	if root is Container:
		return need
	for ch in root.get_children():
		if ch is Control and (ch as Control).visible and not (ch as Control).top_level:
			need = maxf(need, (ch as Control).get_combined_minimum_size().x)
	return need


## Botão de linha que pode encolher (texto com "…") em vez de alargar a tela.
static func shrink_button(b: Button) -> void:
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if b.tooltip_text == "":
		b.tooltip_text = b.text


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


static func kit(k: Dictionary, px: int, number: int = 0, crest_spec: Dictionary = {}) -> KitView:
	var v := KitView.new()
	v.crest = crest_spec
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


## Costas da camisa do clube com o número (no lugar de "camisa 10").
static func shirt_back(club: Club, number: int, px: int, away: bool = false, goalkeeper: bool = false) -> KitView:
	var k := KitView.new()
	var kd: Dictionary = (club.gk_kit() if goalkeeper else (club.kit_away if away else club.kit_home)) if club != null else {}
	k.kit = kd if not kd.is_empty() else {"pattern": "plain", "c1": "#2A3A50", "c2": "#FFFFFF"}
	k.back = true
	k.number = number
	if club != null:
		k.crest = club.crest
	k.custom_minimum_size = Vector2(px, px)
	k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	k.mouse_filter = Control.MOUSE_FILTER_IGNORE
	k.tooltip_text = "Camisa %d" % number if number > 0 else "Sem número"
	return k


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


## Título de seção dentro de cartões: caixa alta espaçada na cor de destaque do clube.
static func section(text: String) -> Label:
	return label(text.to_upper(), "Eyebrow")


static func separator() -> HSeparator:
	var s := HSeparator.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


## Bloco "valor grande + legenda pequena".
static func stat(value: String, caption: String, color: Color = UIColors.TEXT) -> VBoxContainer:
	var v := vbox(0)
	var l := label(value, "Stat")
	l.add_theme_color_override(&"font_color", UIColors.ink(color))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := label(caption.to_upper(), "Caps")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	v.add_child(c)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


static func icon_rect(name: String, px: int, tint: Color = Color(0, 0, 0, 0)) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(px, px)
	# Sem cor definida, o ícone acompanha a cor do texto (branco no escuro, grafite no claro).
	t.modulate = tint if tint.a > 0.0 else UIColors.TEXT
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
	var v := CrestView.new()
	v.crest = CompText.logo(comp)
	v.custom_minimum_size = Vector2(px, px)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


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
	v.add_theme_color_override(&"font_color", UIColors.ink(value_color))
	if value.length() > 22:
		# Valor longo quebra em linhas à direita em vez de alargar a tela.
		k.size_flags_horizontal = Control.SIZE_FILL
		k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_fit_overlay(p, b)
	press_fx(b, p, 0.98)
	if cb.is_valid():
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
	p.add_child(b)
	return p


## A camada clicável fica dentro das margens do painel; os estados dela (passar por cima,
## selecionado) crescem até a borda do painel, com o mesmo arredondamento, para o destaque
## cobrir a linha inteira em vez de um contorno solto por dentro.
static func _fit_overlay(p: PanelContainer, b: Button) -> void:
	var th := ThemeDB.get_project_theme()
	if th == null or not th.has_stylebox(&"panel", p.theme_type_variation):
		return
	var ps := th.get_stylebox(&"panel", p.theme_type_variation)
	var rad := 0
	if ps is StyleBoxFlat:
		rad = (ps as StyleBoxFlat).corner_radius_top_left
	for st in [&"hover", &"pressed", &"hover_pressed"]:
		var src := th.get_stylebox(st, &"RowOverlay") as StyleBoxFlat
		if src == null:
			continue
		var box := src.duplicate() as StyleBoxFlat
		box.expand_margin_left = ps.content_margin_left
		box.expand_margin_right = ps.content_margin_right
		box.expand_margin_top = ps.content_margin_top
		box.expand_margin_bottom = ps.content_margin_bottom
		box.set_corner_radius_all(rad)
		b.add_theme_stylebox_override(st, box)


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
	# Texto legível sobre o fundo tingido (cores claras escurecem no modo claro e vice-versa).
	var under := UIColors.SURFACE.lerp(Color(color, 1.0), 0.16)
	color = UIColors.readable_on(color, [under, UIColors.SURFACE_2.lerp(Color(color, 1.0), 0.16)], 4.5)
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


# --- Sistema de design: componentes compostos -------------------------------------------

## Rótulo pequeno em caixa alta na cor de destaque (acima de títulos: "PRÓXIMA PARTIDA").
static func eyebrow(text: String, color: Color = Color(0, 0, 0, 0)) -> Label:
	var l := label(text.to_upper(), "Eyebrow")
	if color.a > 0.0:
		l.add_theme_color_override(&"font_color", color)
	return l


## Cabeçalho de seção: filete na cor do clube, título em caixa alta e, opcional, um link à
## direita ("VER TUDO").
static func section_header(text: String, action: String = "", cb: Callable = Callable()) -> HBoxContainer:
	var h := hbox(10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tick := ColorRect.new()
	tick.color = UIColors.ACCENT
	tick.custom_minimum_size = Vector2(4, 20)
	tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tick)
	var l := label(text.to_upper(), "Caps")
	l.add_theme_color_override(&"font_color", UIColors.MUTED)
	l.add_theme_font_size_override(&"font_size", 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	if action != "" and cb.is_valid():
		var b := Button.new()
		b.theme_type_variation = "TextButton"
		b.text = action.to_upper()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			AudioManager.click()
			cb.call())
		h.add_child(b)
	return h


## Abas de uma tela: `items` = [[chave, texto], ...]; `cb` recebe a chave escolhida.
## Todas com a mesma largura, sublinhado na cor do clube na aba ativa.
static func tabs(items: Array, selected: String, cb: Callable) -> HBoxContainer:
	var h := hbox(0)
	var g := ButtonGroup.new()
	for it: Array in items:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.text = String(it[1]).to_upper()
		b.toggle_mode = true
		b.button_group = g
		b.button_pressed = String(it[0]) == selected
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = UITokens.H_TAB
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var key: String = it[0]
		b.pressed.connect(func():
			AudioManager.click()
			cb.call(key))
		h.add_child(b)
	return h


## Seletor compacto em cápsula (Geral/Casa/Fora, filtros de posição).
static func segment(items: Array, selected: String, cb: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "Segment"
	var h := hbox(4)
	var g := ButtonGroup.new()
	for it: Array in items:
		var b := Button.new()
		b.theme_type_variation = "SegmentButton"
		b.text = String(it[1])
		b.toggle_mode = true
		b.button_group = g
		b.button_pressed = String(it[0]) == selected
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size.y = 48
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		var key: String = it[0]
		b.pressed.connect(func():
			AudioManager.click()
			cb.call(key))
		h.add_child(b)
	p.add_child(h)
	return p


## Linha de menu: ícone num ladrilho, título (e subtítulo) alinhados à esquerda e uma seta.
static func menu_row(icon_name: String, title: String, subtitle: String, cb: Callable, trailing: Control = null) -> PanelContainer:
	var h := hbox(14)
	if icon_name != "":
		var tile := PanelContainer.new()
		tile.theme_type_variation = "IconTile"
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_child(icon_rect(icon_name, 28, UIColors.ACCENT))
		h.add_child(tile)
	var tv := vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var t := label(title, "H3")
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(t)
	if subtitle != "":
		var s := label(subtitle, "Small")
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		tv.add_child(s)
	h.add_child(tv)
	if trailing != null:
		trailing.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(trailing)
	h.add_child(icon_rect("forward", 22, UIColors.DIM))
	var row := tap_row(h, cb)
	row.custom_minimum_size.y = 76
	return row


## Grupo de linhas de menu dentro de um único cartão, separadas por filetes.
static func menu_group(rows: Array) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardFlat"
	var v := vbox(0)
	for i in rows.size():
		var r: PanelContainer = rows[i]
		var clear := StyleBoxEmpty.new()
		clear.content_margin_left = 6
		clear.content_margin_right = 6
		clear.content_margin_top = 8
		clear.content_margin_bottom = 8
		r.add_theme_stylebox_override(&"panel", clear)
		if i > 0:
			var line := ColorRect.new()
			line.color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
			line.custom_minimum_size.y = 1
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(line)
		v.add_child(r)
	p.add_child(v)
	return p


## Ladrilho de número: valor grande, legenda em caixa alta embaixo.
static func stat_tile(value: String, caption: String, color: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "CardFlat"
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := vbox(2)
	var l := label(value, "Stat")
	l.add_theme_color_override(&"font_color", UIColors.ink(color) if color.a > 0.0 else UIColors.TEXT)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	var c := label(caption.to_upper(), "Caps")
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(c)
	p.add_child(v)
	return p


## Abas que rolam para o lado quando não cabem (tabelas com muitas seções). Cada aba tem a
## largura do texto; um filete corre por baixo de todas.
static func scroll_tabs(items: Array, selected: String, cb: Callable) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size.y = UITokens.H_TAB
	var h := hbox(0)
	var g := ButtonGroup.new()
	var sel: Button = null
	for it: Array in items:
		var b := Button.new()
		b.theme_type_variation = "TabButton"
		b.text = String(it[1]).to_upper()
		b.toggle_mode = true
		b.button_group = g
		b.button_pressed = String(it[0]) == selected
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, UITokens.H_TAB)
		var key: String = it[0]
		b.pressed.connect(func():
			AudioManager.click()
			cb.call(key))
		h.add_child(b)
		if b.button_pressed:
			sel = b
	sc.add_child(h)
	if sel != null:
		# A aba ativa fica visível mesmo quando está no fim da lista.
		sel.ready.connect(func(): sc.ensure_control_visible.call_deferred(sel), CONNECT_ONE_SHOT)
	return sc


## Responsivo: coloca os cartões em `c` numa coluna (celular em retrato) ou distribui em
## colunas lado a lado (paisagem, tablet), sempre equilibrando a altura das colunas.
## `pinned` = quantos dos primeiros cartões ocupam a largura toda (o destaque da tela).
static func columns(c: Container, cards: Array, width: float, max_cols: int = 2, pinned: int = 0) -> void:
	var n := UILayout.columns_for(width, max_cols)
	var i := 0
	while i < mini(pinned, cards.size()):
		c.add_child(cards[i])
		i += 1
	if n <= 1:
		for k in range(i, cards.size()):
			c.add_child(cards[k])
		return
	var row := hbox(UITokens.S4)
	var cols: Array = []
	var load: Array = []
	for _k in n:
		var v := vbox(UITokens.S4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_stretch_ratio = 1.0
		row.add_child(v)
		cols.append(v)
		load.append(0.0)
	for k in range(i, cards.size()):
		var card: Control = cards[k]
		var best := 0
		for j in n:
			if load[j] < load[best] - 0.5:
				best = j
		(cols[best] as VBoxContainer).add_child(card)
		load[best] += _weight(card)
	c.add_child(row)


## Altura estimada de um cartão antes do layout (textos quebrados ainda não têm largura).
static func _weight(n: Node) -> float:
	var h := 40.0
	for ch in n.find_children("*", "", true, false):
		if ch is Label:
			h += 30.0 if (ch as Label).autowrap_mode == TextServer.AUTOWRAP_OFF else 48.0
		elif ch is Button:
			h += 60.0
		elif ch is Control and not (ch is Container) and (ch as Control).custom_minimum_size.y > 0:
			h += (ch as Control).custom_minimum_size.y * 0.6
	return h


static var _sized_icons: Dictionary = {}


## Ícone redimensionado para `px` (campos de texto e outros lugares que desenham a textura no
## tamanho original, sem escala).
static func icon_sized(name: String, px: int) -> Texture2D:
	var key := "%s@%d" % [name, px]
	if not _sized_icons.has(key):
		var tex := icon(name)
		if tex == null:
			return null
		var img := tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(px, px, Image.INTERPOLATE_LANCZOS)
		_sized_icons[key] = ImageTexture.create_from_image(img)
	return _sized_icons[key]


## Grade de ladrilhos de número: 2 por linha no celular em retrato, todos lado a lado em
## telas largas.
static func stat_grid(tiles: Array, width: float) -> GridContainer:
	var g := GridContainer.new()
	g.columns = tiles.size() if UILayout.columns_for(width) > 1 or tiles.size() <= 3 else 2
	g.add_theme_constant_override(&"h_separation", 10)
	g.add_theme_constant_override(&"v_separation", 10)
	for t: Control in tiles:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(t)
	return g


## Ladrilho de ação (menus em grade): ícone no alto, título e uma linha de apoio.
static func action_tile(icon_name: String, title: String, subtitle: String, cb: Callable, highlight: bool = false) -> PanelContainer:
	var v := vbox(8)
	var tile := PanelContainer.new()
	tile.theme_type_variation = "IconTile"
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.add_child(icon_rect(icon_name, 30, UIColors.ON_ACCENT if highlight else UIColors.ACCENT))
	if highlight:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.ACCENT
		sb.set_corner_radius_all(UITokens.R_SM)
		sb.set_content_margin_all(10)
		tile.add_theme_stylebox_override(&"panel", sb)
	v.add_child(tile)
	var t := label(title, "H3")
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	if subtitle != "":
		var s := label(subtitle, "Small", true)
		v.add_child(s)
	var row := tap_row(v, cb, "CardHighlight" if highlight else "Card")
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 150
	return row


## Estado vazio: ícone num círculo, título, explicação e (opcional) um botão para resolver.
static func empty_state(icon_name: String, title: String, body: String, action: String = "", cb: Callable = Callable()) -> PanelContainer:
	var box := card("Card", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := PanelContainer.new()
	ic.theme_type_variation = "IconTile"
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.add_child(icon_rect(icon_name, 40, UIColors.ACCENT))
	box.add_child(gap(8))
	box.add_child(ic)
	var t := label(title, "H3", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	if body != "":
		var b := label(body, "Muted", true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(b)
	if action != "" and cb.is_valid():
		var btn := button(action, "PrimaryButton", cb)
		box.add_child(btn)
	box.add_child(gap(4))
	return card_panel(box)


## Grade de ladrilhos com colunas fixas (2 no celular, mais em telas largas).
static func tile_grid(tiles: Array, cols: int = 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override(&"h_separation", UITokens.S3)
	g.add_theme_constant_override(&"v_separation", UITokens.S3)
	for t: Control in tiles:
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(t)
	return g


## Grade de opções escolhíveis (foco de treino, setor de captação...): cada opção é um ladrilho
## com ícone, nome e uma linha de efeito; a escolhida fica destacada. Substitui fileiras de chips
## quando a escolha merece explicação. `items` = [[chave, título, subtítulo, ícone], ...].
static func option_grid(items: Array, selected: String, cb: Callable, cols: int = 2) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override(&"h_separation", UITokens.S3)
	grid.add_theme_constant_override(&"v_separation", UITokens.S3)
	for it: Array in items:
		var key := String(it[0])
		var on := key == selected
		var v := vbox(2)
		var head := hbox(10)
		if it.size() > 3 and String(it[3]) != "":
			head.add_child(icon_rect(String(it[3]), 24, UIColors.ACCENT if on else UIColors.MUTED))
		var t := label(String(it[1]), "H3")
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		if on:
			head.add_child(icon_rect("check", 22, UIColors.ACCENT))
		v.add_child(head)
		if it.size() > 2 and String(it[2]) != "":
			var s := label(String(it[2]), "Small", true)
			s.max_lines_visible = 2
			v.add_child(s)
		var tile := tap_row(v, func(): cb.call(key), "CardHighlight" if on else "CardFlat")
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
	return grid


## Efeitos em porcentagem como selos coloridos ("Evolução +10%" em verde, "Lesão +15%" em
## vermelho). `items` = [[nome, delta_em_%, maior_é_melhor], ...]; zeros ficam de fora.
static func effect_pills(items: Array) -> HFlowContainer:
	var f := flow(8)
	for it: Array in items:
		var d := int(it[1])
		if d == 0:
			continue
		var good := (d > 0) == bool(it[2])
		f.add_child(pill("%s %+d%%" % [tr_static(String(it[0])), d], UIColors.GREEN if good else UIColors.RED, 16))
	return f


static func tr_static(s: String) -> String:
	return I18n.t(s)


## Linha de comparação entre dois lados (estatísticas de jogo): valores nas pontas, o nome no
## meio e uma barra dividida na proporção, com o lado maior em destaque.
static func versus_row(caption: String, a_text: String, b_text: String, a_val: float, b_val: float) -> VBoxContainer:
	var v := vbox(4)
	var r := hbox(8)
	var total := a_val + b_val
	var a_win := a_val > b_val
	var b_win := b_val > a_val
	var a := label(a_text, "H3")
	a.custom_minimum_size.x = 90
	if a_win:
		a.add_theme_color_override(&"font_color", UIColors.ACCENT)
	r.add_child(a)
	var n := label(caption, "Caps")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(n)
	var b := label(b_text, "H3")
	b.custom_minimum_size.x = 90
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if b_win:
		b.add_theme_color_override(&"font_color", UIColors.ACCENT)
	r.add_child(b)
	v.add_child(r)
	var bars := hbox(4)
	var left := ColorRect.new()
	left.color = UIColors.ACCENT if a_win else UIColors.SURFACE_3
	left.custom_minimum_size.y = 6
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = maxf(0.05, a_val / total) if total > 0.0 else 1.0
	var right := ColorRect.new()
	right.color = UIColors.ACCENT if b_win else UIColors.SURFACE_3
	right.custom_minimum_size.y = 6
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = maxf(0.05, b_val / total) if total > 0.0 else 1.0
	bars.add_child(left)
	bars.add_child(right)
	v.add_child(bars)
	return v
