extends Node
## Navegação entre telas (pilha), diálogos, folhas inferiores, toasts e botão "voltar" do Android.
## Veio do Mais Uma Rodada; as telas aqui são scripts que montam o próprio esqueleto (BaseScreen).

const SCREENS := {
	"menu": "res://scripts/ui/screens/menu_screen.gd",
	"new_career": "res://scripts/ui/screens/new_career_screen.gd",
	"hub": "res://scripts/ui/screens/hub_screen.gd",
	"team": "res://scripts/ui/screens/team_screen.gd",
	"rankings": "res://scripts/ui/screens/rankings_screen.gd",
	"market": "res://scripts/ui/screens/market_screen.gd",
	"gym": "res://scripts/ui/screens/gym_screen.gd",
	"fighter": "res://scripts/ui/screens/fighter_screen.gd",
	"offer": "res://scripts/ui/screens/offer_screen.gd",
	"challenge": "res://scripts/ui/screens/challenge_screen.gd",
	"fight_plan": "res://scripts/ui/screens/fight_plan_screen.gd",
	"fight": "res://scripts/ui/screens/fight_screen.gd",
	"event": "res://scripts/ui/screens/event_screen.gd",
	"settings": "res://scripts/ui/screens/settings_screen.gd",
	# Os dois papéis (acompanhar o mundo como fã)
	"titles": "res://scripts/ui/screens/titles_screen.gd",
	"results": "res://scripts/ui/screens/results_screen.gd",
	# Presidente da organização
	"org_hub": "res://scripts/ui/screens/org_hub_screen.gd",
	"events": "res://scripts/ui/screens/org_events_screen.gd",
	"org_event": "res://scripts/ui/screens/org_event_screen.gd",
	"book": "res://scripts/ui/screens/book_screen.gd",
	"night": "res://scripts/ui/screens/night_screen.gd",
	"org": "res://scripts/ui/screens/org_screen.gd",
}
## As cinco áreas da carreira de cada papel. Cada área guarda a própria pilha: trocar de área e
## voltar devolve a tela como o jogador deixou (filtros, busca, rolagem).
const TABS_BY_ROLE := {
	"empresario": ["hub", "team", "rankings", "market", "gym"],
	"presidente": ["hub", "events", "rankings", "titles", "org"],
}
## O Início do presidente é outra tela, com o mesmo nome de área.
const ROLE_SCREENS := {"presidente": {"hub": "org_hub"}}

var main: Node = null # scripts/ui/main.gd
var area := "hub"
var stacks: Dictionary = {} # área -> Array[BaseScreen]
var stack: Array = [] # pilha da área atual (a mesma instância de stacks[area])
var _modals: Array = []
var _script_cache: Dictionary = {}


func register_main(m: Node) -> void:
	main = m


## Reconstrói a tela atual agora.
func refresh_current() -> bool:
	var cur := current()
	if not is_instance_valid(cur) or cur.is_queued_for_deletion():
		return false
	cur.refresh()
	return true


func current() -> BaseScreen:
	return stack.back() if not stack.is_empty() else null


func tabs() -> Array:
	var role := GameManager.world.role if GameManager.has_career() else "empresario"
	return TABS_BY_ROLE.get(role, TABS_BY_ROLE["empresario"])


func _instance(name: String, params: Dictionary) -> BaseScreen:
	var real := name
	if GameManager.has_career():
		real = String((ROLE_SCREENS.get(GameManager.world.role, {}) as Dictionary).get(name, name))
	if not _script_cache.has(real):
		_script_cache[real] = load(SCREENS[real])
	var node: BaseScreen = _script_cache[real].new()
	node.screen_name = name
	node.setup(params)
	return node


## Abre uma tela do zero. Área (Início, Elenco...): recomeça a pilha dela. Fora das áreas
## (menu, boas-vindas, nova carreira): descarta todas as pilhas.
func goto(name: String, params: Dictionary = {}) -> void:
	close_all_modals()
	if name in tabs():
		_hide_top()
		_free_stack(name)
		_set_area(name)
		_show(_instance(name, params), 0.0)
		return
	for a in stacks.keys():
		_free_stack(a)
	_set_area("hub")
	_show(_instance(name, params), 0.0)


## Toque na barra de navegação: volta à área como ela estava. Tocar na área atual sobe
## para a raiz dela (ou para o topo da lista, se já estiver na raiz).
func switch_area(a: String) -> void:
	close_all_modals()
	if a == area:
		if stack.size() > 1:
			pop_to_root()
		elif current() != null:
			current().scroll_to_top()
		return
	_hide_top()
	_set_area(a)
	if stack.is_empty():
		_show(_instance(a, {}), 0.0)
		return
	var top := current()
	top.visible = true
	top.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_chrome(top)
	top.on_show()
	_restore_scroll(top)
	_animate_in(top, 0.0)


func pop_to_root() -> void:
	close_all_modals()
	while stack.size() > 1:
		var s: BaseScreen = stack.pop_back()
		s.queue_free()
	var root := current()
	root.visible = true
	_apply_chrome(root)
	root.on_show()
	_animate_in(root, -40.0)


## A tela reconstrói o conteúdo ao reaparecer; a rolagem volta ao ponto em que o jogador estava.
func _remember_scroll(s: BaseScreen) -> void:
	var sc := s.scroll()
	if sc != null:
		s.set_meta(&"scroll_y", sc.scroll_vertical)


func _restore_scroll(s: BaseScreen) -> void:
	var y := int(s.get_meta(&"scroll_y", 0))
	var sc := s.scroll()
	if y <= 0 or sc == null:
		return
	for i in 2:
		await get_tree().process_frame
		if not is_instance_valid(sc):
			return
	sc.scroll_vertical = y


func _set_area(a: String) -> void:
	area = a
	if not stacks.has(a):
		stacks[a] = []
	stack = stacks[a]


func _hide_top() -> void:
	var cur := current()
	if cur != null:
		_remember_scroll(cur)
		cur.visible = false
		cur.on_hide()
		# Telas de outras áreas ficam guardadas, paradas.
		cur.process_mode = Node.PROCESS_MODE_DISABLED


func _free_stack(a: String) -> void:
	for s in stacks.get(a, []):
		s.queue_free()
	if stacks.has(a):
		stacks[a].clear()


## Empilha uma tela (perfil, negociação...). "Voltar" retorna à anterior.
func push(name: String, params: Dictionary = {}) -> void:
	close_all_modals()
	var cur := current()
	if cur != null:
		_remember_scroll(cur)
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
	prev.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_chrome(prev)
	prev.on_show()
	_restore_scroll(prev)
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
	if AppSettings.reduce_motion:
		from_x = 0.0
	screen.position.x = from_x
	var tw := screen.create_tween().set_parallel()
	tw.tween_property(screen, "modulate:a", 1.0, 0.16 if from_x != 0.0 else 0.12)
	if from_x != 0.0:
		tw.tween_property(screen, "position:x", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_chrome(screen: BaseScreen) -> void:
	if main == null:
		return
	main.apply_chrome(screen, stack.size() > 1)
	Sfx.screen_changed(screen.screen_name)


## Atualiza título/barras da tela atual (quando os dados mudam).
func refresh_chrome() -> void:
	var cur := current()
	if cur != null:
		_apply_chrome(cur)


func _redraw_tree(n: Node) -> void:
	if n is CanvasItem:
		(n as CanvasItem).queue_redraw()
	for c in n.get_children():
		_redraw_tree(c)


## Botão voltar do Android / Esc.
func handle_back() -> void:
	if back():
		return
	var cur := current()
	if cur == null:
		return
	if cur.screen_name == "menu":
		get_tree().quit()
	elif area != "hub" and GameManager.has_career() and cur.screen_name == area:
		switch_area("hub")
	elif cur.screen_name == "hub":
		confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
			GameManager.close_career()
			goto("menu"))
	elif cur.screen_name == "fight":
		toast("A luta está em andamento.")


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
	# Telas largas (paisagem, tablet): folha e diálogo ficam numa coluna central com largura de
	# leitura, em vez de atravessar a tela inteira.
	var side := 0 if as_sheet else 28
	var vw := layer.get_viewport_rect().size.x
	var cap := 820.0 if as_sheet else 680.0
	if vw > cap + 2.0 * side:
		side = int((vw - cap) / 2.0)
	holder.add_theme_constant_override(&"margin_left", side)
	holder.add_theme_constant_override(&"margin_right", side)
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
	# Conteúdo com largura mínima fixa (pensada para telas maiores) nunca vaza para os lados.
	var psb := panel.get_theme_stylebox(&"panel")
	_clamp_width(content, vw - side * 2.0 - (psb.get_minimum_size().x if psb != null else 0.0), 2)
	# Conteúdo maior que a tela rola dentro do modal em vez de vazar para fora dela.
	var reserved := safe.position.y + 60.0 + (safe.size.y if as_sheet else safe.size.y + 60.0)
	var body := _fit_to_screen(content, layer, panel, reserved)
	if as_sheet:
		var inner := MarginContainer.new()
		inner.add_theme_constant_override(&"margin_bottom", int(safe.size.y))
		var col := VBoxContainer.new()
		col.add_theme_constant_override(&"separation", 14)
		# Alça da folha: o traço no topo que diz "isto desliza e fecha".
		var grab := ColorRect.new()
		grab.color = Color(UIColors.TEXT, 0.22)
		grab.custom_minimum_size = Vector2(64, 6)
		grab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		grab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(grab)
		col.add_child(body)
		inner.add_child(col)
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
func _clamp_width(n: Control, max_w: float, depth: int) -> void:
	if n.custom_minimum_size.x > max_w:
		n.custom_minimum_size.x = maxf(0.0, max_w)
	if depth <= 0:
		return
	for ch in n.get_children():
		if ch is Control:
			_clamp_width(ch, max_w, depth - 1)


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
	# Não segue o foco: no toque, a folha rolava sob o dedo (main.gd rola no teclado).
	sc.follow_focus = false
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	var fit := func() -> void:
		if is_instance_valid(sc) and is_instance_valid(content):
			sc.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, max_h.call())
	content.minimum_size_changed.connect(fit)
	sc.ready.connect(fit)
	return sc


## Popover: informação curta presa ao elemento tocado (o que é um atributo, a forma de um
## jogador, a origem de um número). Não escurece a tela; tocar fora fecha. Um popover novo
## fecha o anterior (nunca um sobre o outro).
func popover(content: Control, anchor: Control, width: float = 460.0) -> Control:
	if not _modals.is_empty() and bool(_modals.back().get_meta(&"popover", false)):
		close_modal()
	var layer: Control = main.modal_host
	var catcher := Control.new()
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.set_meta(&"popover", true)
	layer.add_child(catcher)
	_modals.append(catcher)
	catcher.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			if _modals.has(catcher):
				_modals.erase(catcher)
				catcher.queue_free())
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Popover"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if content is Label:
		(content as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(content)
	panel.custom_minimum_size.x = width
	catcher.add_child(panel)
	var place := func() -> void:
		if not is_instance_valid(panel) or not is_instance_valid(anchor):
			return
		var vr := layer.get_viewport_rect().size
		var a := anchor.get_global_rect()
		var sz := panel.get_combined_minimum_size()
		panel.size = sz
		var x := clampf(a.position.x, 16.0, vr.x - sz.x - 16.0)
		var y := a.end.y + 8.0
		if y + sz.y > vr.y - main.safe_margins().size.y - 16.0:
			y = a.position.y - sz.y - 8.0
		panel.position = Vector2(x, maxf(main.safe_margins().position.y + 8.0, y))
	place.call_deferred()
	panel.minimum_size_changed.connect(place)
	return catcher


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
	var t := UIKit.label(title, "H2", true)
	v.add_child(t)
	if body != "":
		var bl := UIKit.label(body, "", true)
		bl.add_theme_color_override(&"font_color", UIColors.MUTED)
		v.add_child(bl)
	# Dois botões lado a lado (confirmar e cancelar), com o principal à direita, como nos
	# diálogos de console; mais de dois, empilhados.
	var row: BoxContainer = UIKit.vbox(10)
	if buttons.size() == 2:
		row = UIKit.hbox(12)
		buttons = [buttons[1], buttons[0]]
	for b in buttons:
		var cb: Callable = b.get("cb", Callable())
		var btn := UIKit.button(b.get("text", "OK"), b.get("style", ""), func():
			close_modal()
			if cb.is_valid():
				cb.call())
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	v.add_child(row)
	show_modal(v)


func confirm(title: String, body: String, yes_text: String, cb: Callable) -> void:
	# Ações que destroem algo (apagar, demitir, vender...) ganham o botão vermelho.
	var danger := false
	for word in ["Apagar", "Excluir", "Remover", "Demitir", "Dispensar", "Rescindir", "Sair"]:
		if yes_text.begins_with(word):
			danger = true
	dialog(title, body, [{"text": yes_text, "style": "DangerButton" if danger else "PrimaryButton", "cb": cb}, {"text": "Cancelar", "style": "GhostButton"}])


func info(title: String, body: String) -> void:
	dialog(title, body, [{"text": "OK", "style": "PrimaryButton"}])


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------

func toast(text: String, color: Color = UIColors.TEXT) -> void:
	if main == null:
		print(text)
		return
	_toast_sound(color)
	var p := PanelContainer.new()
	p.theme_type_variation = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Faixa de cor à esquerda diz o tipo do aviso (verde bom, vermelho ruim, neutro).
	var row := UIKit.hbox(14)
	var bar := ColorRect.new()
	bar.color = color if color != UIColors.TEXT else UIColors.ACCENT
	bar.custom_minimum_size = Vector2(5, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var l := UIKit.label(text, "", true)
	l.add_theme_color_override(&"font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	p.add_child(row)
	main.toast_host.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


var _toast_sfx_at := -10.0


## Aviso com som discreto (bom, ruim ou neutro), no máximo um a cada meio segundo.
func _toast_sound(color: Color) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _toast_sfx_at < 0.5:
		return
	_toast_sfx_at = now
	if color == UIColors.GREEN:
		Sfx.play("notify_good", -10.0)
	elif color == UIColors.RED:
		Sfx.play("notify_bad", -10.0)
	else:
		Sfx.play("notify", -12.0)
