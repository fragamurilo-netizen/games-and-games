extends Node
## Navegação entre telas (pilha), diálogos, folhas inferiores, toasts e botão "voltar" do Android.

const SCREENS := {
	"menu": "res://scenes/screens/main_menu.tscn",
	"new_career": "res://scenes/screens/new_career.tscn",
	"hub": "res://scenes/screens/hub.tscn",
	"squad": "res://scenes/screens/squad.tscn",
	"player": "res://scenes/screens/player_profile.tscn",
	"prematch": "res://scenes/screens/prematch.tscn",
	"match": "res://scenes/screens/match.tscn",
	"results": "res://scenes/screens/round_results.tscn",
	"table": "res://scenes/screens/table.tscn",
	"market": "res://scenes/screens/market.tscn",
	"club": "res://scenes/screens/club.tscn",
	"season_end": "res://scenes/screens/season_end.tscn",
	"load": "res://scenes/screens/load_game.tscn",
	"news": "res://scenes/screens/news.tscn",
	"settings": "res://scenes/screens/settings.tscn",
	"training": "res://scenes/screens/training.tscn",
	"academy": "res://scenes/screens/academy.tscn",
	"history": "res://scenes/screens/history.tscn",
	"national": "res://scenes/screens/national.tscn",
	"editor": "res://scenes/screens/editor.tscn",
	"kit": "res://scenes/screens/kit.tscn",
	"preseason": "res://scenes/screens/preseason.tscn",
	"relations": "res://scenes/screens/relations.tscn",
}
const TABS := ["hub", "squad", "market", "table", "club"]

var main: Node = null # scripts/ui/main.gd
var stack: Array = [] # BaseScreen
var _modals: Array = []
var _scene_cache: Dictionary = {}


func register_main(m: Node) -> void:
	main = m


func current() -> BaseScreen:
	return stack.back() if not stack.is_empty() else null


func _instance(name: String, params: Dictionary) -> BaseScreen:
	if not _scene_cache.has(name):
		_scene_cache[name] = load(SCREENS[name])
	var node: BaseScreen = _scene_cache[name].instantiate()
	node.screen_name = name
	node.setup(params)
	return node


## Troca a pilha inteira pela nova tela (abas, menu).
func goto(name: String, params: Dictionary = {}) -> void:
	close_all_modals()
	for s in stack:
		s.queue_free()
	stack.clear()
	_show(_instance(name, params), 0.0)


## Empilha uma tela (perfil, negociação...). "Voltar" retorna à anterior.
func push(name: String, params: Dictionary = {}) -> void:
	close_all_modals()
	var cur := current()
	if cur != null:
		cur.visible = false
		cur.on_hide()
	_show(_instance(name, params), 56.0)


## Substitui a tela do topo (fluxos lineares: pré-jogo → partida → resultados).
func replace(name: String, params: Dictionary = {}) -> void:
	close_all_modals()
	var cur := current()
	if cur != null:
		stack.pop_back()
		cur.queue_free()
	_show(_instance(name, params), 24.0)


func back() -> bool:
	if not _modals.is_empty():
		close_modal()
		return true
	if stack.size() <= 1:
		return false
	var cur: BaseScreen = stack.pop_back()
	cur.queue_free()
	var prev := current()
	prev.visible = true
	_apply_chrome(prev)
	prev.on_show()
	_animate_in(prev, -40.0)
	return true


func _show(screen: BaseScreen, from_x: float) -> void:
	stack.append(screen)
	main.screen_host.add_child(screen)
	_apply_chrome(screen)
	screen.on_show()
	_animate_in(screen, from_x)


## Transição curta: a tela entra deslizando do lado de onde veio (avançar = da direita,
## voltar = da esquerda) enquanto aparece. Trocar de aba é só um fade rápido.
func _animate_in(screen: Control, from_x: float) -> void:
	screen.modulate.a = 0.0
	screen.position.x = from_x
	var tw := screen.create_tween().set_parallel()
	tw.tween_property(screen, "modulate:a", 1.0, 0.16 if from_x != 0.0 else 0.12)
	if from_x != 0.0:
		tw.tween_property(screen, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_chrome(screen: BaseScreen) -> void:
	if main == null:
		return
	main.apply_chrome(screen, stack.size() > 1)


## Atualiza título/barras da tela atual (quando os dados mudam).
func refresh_chrome() -> void:
	var cur := current()
	if cur != null:
		_apply_chrome(cur)


## Botão voltar do Android / Esc.
func handle_back() -> void:
	if back():
		return
	var cur := current()
	if cur == null:
		return
	if cur.screen_name == "menu":
		get_tree().quit()
	elif TABS.has(cur.screen_name) and cur.screen_name != "hub":
		goto("hub")
	elif cur.screen_name == "hub":
		confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
			GameManager.close_career()
			goto("menu"))
	elif cur.screen_name == "match":
		toast("A partida está em andamento.")


# ---------------------------------------------------------------------------
# Modais
# ---------------------------------------------------------------------------

## Mostra um conteúdo como modal centralizado (dialog) ou folha inferior (sheet).
func show_modal(content: Control, as_sheet: bool = false, dismissable: bool = true) -> Control:
	var layer: Control = main.modal_host
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var holder := MarginContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe: Rect2 = main.safe_margins()
	holder.add_theme_constant_override(&"margin_left", 0 if as_sheet else 28)
	holder.add_theme_constant_override(&"margin_right", 0 if as_sheet else 28)
	holder.add_theme_constant_override(&"margin_top", int(safe.position.y) + 60)
	holder.add_theme_constant_override(&"margin_bottom", 0 if as_sheet else int(safe.size.y) + 60)
	dim.add_child(holder)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)
	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top_spacer)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Sheet" if as_sheet else "Dialog"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(panel)
	# Conteúdo maior que a tela rola dentro do modal em vez de vazar para fora dela.
	var reserved := safe.position.y + 60.0 + (safe.size.y if as_sheet else safe.size.y + 60.0)
	var body := _fit_to_screen(content, layer, panel, reserved)
	if as_sheet:
		var inner := MarginContainer.new()
		inner.add_theme_constant_override(&"margin_bottom", int(safe.size.y))
		inner.add_child(body)
		panel.add_child(inner)
	else:
		panel.add_child(body)
		var bottom_spacer := Control.new()
		bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bottom_spacer)
	if dismissable:
		dim.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				close_modal())
	_modals.append(dim)
	# Entrada: o fundo escurece e o painel sobe um pouco (a folha inferior vem de baixo).
	dim.modulate.a = 0.0
	holder.position.y = 90.0 if as_sheet else 24.0
	var tw := dim.create_tween().set_parallel()
	tw.tween_property(dim, "modulate:a", 1.0, 0.14)
	tw.tween_property(holder, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return dim


## Limita a altura do conteúdo do modal ao espaço da tela. Se o conteúdo já é uma rolagem
## (listas longas), só limita sua altura; senão, embrulha num ScrollContainer que cresce
## junto com o conteúdo até o limite e então passa a rolar.
func _fit_to_screen(content: Control, layer: Control, panel: PanelContainer, reserved: float) -> Control:
	var max_h := func() -> float:
		var style := panel.get_theme_stylebox(&"panel")
		var pad := style.get_minimum_size().y if style != null else 0.0
		return maxf(200.0, layer.get_viewport_rect().size.y - reserved - pad)
	if content is ScrollContainer:
		var want := content.custom_minimum_size.y
		content.custom_minimum_size.y = minf(want, max_h.call()) if want > 0.0 else want
		return content
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 14
	sc.follow_focus = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	var fit := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(content):
			sc.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, max_h.call())
	content.minimum_size_changed.connect(fit)
	sc.ready.connect(fit)
	return sc


func close_modal() -> void:
	if _modals.is_empty():
		return
	var m: Control = _modals.pop_back()
	m.queue_free()


func close_all_modals() -> void:
	while not _modals.is_empty():
		close_modal()


func has_modal() -> bool:
	return not _modals.is_empty()


## Diálogo com título, texto e botões [{text, style, cb}] (cb pode ser vazio = só fecha).
func dialog(title: String, body: String, buttons: Array) -> void:
	var v := UIKit.vbox(18)
	v.custom_minimum_size.x = 560
	var t := UIKit.label(title, "Title", true)
	v.add_child(t)
	if body != "":
		v.add_child(UIKit.label(body, "", true))
	var row := UIKit.vbox(10)
	for b in buttons:
		var cb: Callable = b.get("cb", Callable())
		var btn := UIKit.button(b.get("text", "OK"), b.get("style", ""), func():
			close_modal()
			if cb.is_valid():
				cb.call())
		row.add_child(btn)
	v.add_child(row)
	show_modal(v)


func confirm(title: String, body: String, yes_text: String, cb: Callable) -> void:
	dialog(title, body, [{"text": yes_text, "style": "PrimaryButton", "cb": cb}, {"text": "Cancelar", "style": "GhostButton"}])


func info(title: String, body: String) -> void:
	dialog(title, body, [{"text": "OK", "style": "PrimaryButton"}])


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------

func toast(text: String, color: Color = UIColors.TEXT) -> void:
	if main == null:
		print(text)
		return
	var p := PanelContainer.new()
	p.theme_type_variation = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIKit.label(text, "", true)
	l.add_theme_color_override(&"font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	main.toast_host.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
