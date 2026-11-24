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
	"look": "res://scripts/ui/screens/look_screen.gd",
	"offer": "res://scripts/ui/screens/offer_screen.gd",
	"challenge": "res://scripts/ui/screens/challenge_screen.gd",
	"fight_plan": "res://scripts/ui/screens/fight_plan_screen.gd",
	"fight": "res://scripts/ui/screens/fight_screen.gd",
	"event": "res://scripts/ui/screens/event_screen.gd",
	"settings": "res://scripts/ui/screens/settings_screen.gd",
	"credits": "res://scripts/ui/screens/credits_screen.gd",
	"licenses": "res://scripts/ui/screens/licenses_screen.gd",
	# Os dois papéis (acompanhar o mundo como fã)
	"titles": "res://scripts/ui/screens/titles_screen.gd",
	"results": "res://scripts/ui/screens/results_screen.gd",
	"legacy": "res://scripts/ui/screens/legacy_screen.gd",
	"inbox": "res://scripts/ui/screens/inbox_screen.gd",
	"season": "res://scripts/ui/screens/season_screen.gd",
	"gala": "res://scripts/ui/screens/gala_screen.gd",
	# Presidente da organização
	"org_hub": "res://scripts/ui/screens/org_hub_screen.gd",
	"events": "res://scripts/ui/screens/org_events_screen.gd",
	"org_event": "res://scripts/ui/screens/org_event_screen.gd",
	"book": "res://scripts/ui/screens/book_screen.gd",
	"venue": "res://scripts/ui/screens/venue_screen.gd",
	"tv": "res://scripts/ui/screens/tv_screen.gd",
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
## Quadro da última troca de tela (main.gd usa para saber se um toque só navegou).
var nav_frame := -1


func register_main(m: Node) -> void:
	main = m
	# Os scripts das telas são lidos em segundo plano logo na abertura: a primeira visita a cada
	# tela não paga a leitura e a compilação do script.
	for path: String in SCREENS.values():
		ResourceLoader.load_threaded_request(path)


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
		var path: String = SCREENS[real]
		var res: Resource = null
		if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			res = ResourceLoader.load_threaded_get(path)
		_script_cache[real] = res if res != null else load(path)
	var node: BaseScreen = _script_cache[real].new()
	node.screen_name = name
	node.setup(params)
	return node


## Abre uma tela do zero. Área (Início, Elenco...): recomeça a pilha dela. Fora das áreas
## (menu, boas-vindas, nova carreira): descarta todas as pilhas.
func goto(name: String, params: Dictionary = {}) -> void:
	nav_frame = Engine.get_process_frames()
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
	nav_frame = Engine.get_process_frames()
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
	nav_frame = Engine.get_process_frames()
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
		_stop_nav_tween(cur)
		cur.visible = false
		cur.position.x = 0.0
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
	nav_frame = Engine.get_process_frames()
	close_all_modals()
	var cur := current()
	if cur != null:
		_remember_scroll(cur)
		cur.on_hide()
		_animate_out(cur, -20.0, false)
	_show(_instance(name, params), 36.0)


## Substitui a tela do topo (fluxos lineares: pré-jogo → partida → resultados).
func replace(name: String, params: Dictionary = {}) -> void:
	nav_frame = Engine.get_process_frames()
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
	nav_frame = Engine.get_process_frames()
	var cur: BaseScreen = stack.pop_back()
	cur.on_hide()
	# A tela que sai vai para baixo da que volta: o toque já é da tela de trás.
	if cur.get_parent() != null:
		cur.get_parent().move_child(cur, 0)
	_animate_out(cur, 28.0, true)
	var prev := current()
	prev.visible = true
	prev.process_mode = Node.PROCESS_MODE_INHERIT
	_apply_chrome(prev)
	prev.on_show()
	_restore_scroll(prev)
	_animate_in(prev, -24.0)
	return true


func _show(screen: BaseScreen, from_x: float) -> void:
	stack.append(screen)
	main.screen_host.add_child(screen)
	_apply_chrome(screen)
	screen.on_show()
	_animate_in(screen, from_x)
	screen.play_intro()


## Transição curta: a tela entra deslizando do lado de onde veio (avançar = da direita,
## voltar = da esquerda) enquanto aparece. Trocar de aba é só um fade rápido.
func _animate_in(screen: Control, from_x: float) -> void:
	_stop_nav_tween(screen)
	screen.modulate.a = 0.0
	if AppSettings.reduce_motion:
		from_x = 0.0
	screen.position.x = from_x
	if not Anim.on():
		screen.modulate.a = 1.0
		screen.position.x = 0.0
		return
	var tw := screen.create_tween().set_parallel()
	screen.set_meta(&"nav_tw", tw)
	tw.tween_property(screen, "modulate:a", 1.0, 0.09 if from_x != 0.0 else 0.07)
	if from_x != 0.0:
		tw.tween_property(screen, "position:x", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## A tela que sai some deslizando para o lado contrário de quem entra. Com `free_after` ela é
## descartada no fim (voltar); sem, fica guardada e escondida (empilhar outra por cima).
func _animate_out(screen: Control, to_x: float, free_after: bool) -> void:
	_stop_nav_tween(screen)
	if AppSettings.reduce_motion or not screen.is_inside_tree() or DisplayServer.get_name() == "headless":
		if free_after:
			screen.queue_free()
		else:
			screen.visible = false
		return
	var tw := screen.create_tween().set_parallel()
	screen.set_meta(&"nav_tw", tw)
	tw.tween_property(screen, "modulate:a", 0.0, 0.07)
	tw.tween_property(screen, "position:x", to_x, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func():
		if free_after:
			screen.queue_free()
		else:
			screen.visible = false
			screen.position.x = 0.0
			screen.modulate.a = 1.0)


func _stop_nav_tween(screen: Control) -> void:
	if screen.has_meta(&"nav_tw"):
		var old: Tween = screen.get_meta(&"nav_tw")
		if old != null and old.is_valid():
			old.kill()
		screen.remove_meta(&"nav_tw")


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
		GameManager.flush()
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
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
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
	if as_sheet:
		Sfx.play("sheet", -9.0)
	# Entrada: o fundo escurece e o painel sobe um pouco (a folha inferior vem de baixo).
	dim.modulate.a = 0.0
	holder.position.y = 60.0 if as_sheet else 16.0
	var tw := dim.create_tween().set_parallel()
	tw.tween_property(dim, "modulate:a", 1.0, 0.09)
	tw.tween_property(holder, "position:y", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	if AppSettings.reduce_motion or not m.is_inside_tree() or DisplayServer.get_name() == "headless":
		m.queue_free()
		return
	# Saída: o painel desce um pouco enquanto o fundo clareia. Um escudo por cima engole os
	# toques até o modal sumir (um segundo toque no mesmo botão não repete a ação).
	var shield := Control.new()
	shield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shield.mouse_filter = Control.MOUSE_FILTER_STOP
	m.add_child(shield)
	var holder := m.get_child(0) as Control
	var tw := m.create_tween().set_parallel()
	tw.tween_property(m, "modulate:a", 0.0, 0.08)
	if holder != null:
		tw.tween_property(holder, "position:y", holder.position.y + 20.0, 0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(m.queue_free)


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

var _toast_live: Control


## Aviso curto no alto da tela. Um de cada vez: o novo toma o lugar do anterior.
func toast(text: String, color: Color = UIColors.TEXT) -> void:
	if main == null:
		print(text)
		return
	_toast_sound(color)
	if is_instance_valid(_toast_live):
		_toast_live.queue_free()
	var p := PanelContainer.new()
	_toast_live = p
	p.theme_type_variation = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A bolinha de cor diz o tipo do aviso (verde bom, vermelho ruim, dourado neutro).
	var row := UIKit.hbox(12)
	var dot := Dot.new()
	dot.color = color if color != UIColors.TEXT else UIColors.ACCENT
	row.add_child(dot)
	var l := UIKit.label(text, "", true)
	l.add_theme_font_size_override(&"font_size", UITokens.F_BODY_SMALL + 1)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	p.add_child(row)
	main.toast_host.add_child(p)
	main.toast_host.move_child(p, 0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.1)
	tw.tween_interval(clampf(1.3 + text.length() * 0.022, 1.6, 3.2))
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	tw.tween_callback(p.queue_free)


class Dot extends Control:
	var color := Color.WHITE

	func _init() -> void:
		custom_minimum_size = Vector2(12, 12)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 6.0, color, true, -1.0, true)


## A semana que começou, com o que mudou, num aviso só no alto da tela: o título e, embaixo, os
## itens lado a lado, cada um na sua cor. Não segura o toque e não cobre o conteúdo.
func banner(title: String, lines: Array = []) -> void:
	if main == null or DisplayServer.get_name() == "headless":
		return
	if is_instance_valid(_toast_live):
		_toast_live.queue_free()
	var p := PanelContainer.new()
	_toast_live = p
	p.theme_type_variation = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(0)
	v.add_child(UIKit.kicker(title))
	if not lines.is_empty():
		var row := UIKit.hbox(14)
		for ln: Array in lines:
			var l := UIKit.label(String(ln[0]), "H3")
			l.add_theme_font_size_override(&"font_size", UITokens.F_BODY_SMALL + 1)
			if ln.size() > 1 and (ln[1] as Color).a > 0.0:
				l.add_theme_color_override(&"font_color", ln[1])
			row.add_child(l)
		v.add_child(row)
	p.add_child(v)
	main.toast_host.add_child(p)
	main.toast_host.move_child(p, 0)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.1)
	tw.tween_interval(1.7)
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
	tw.tween_callback(p.queue_free)


## Aviso no meio da tela enquanto o jogo faz uma conta pesada (a virada da semana), para a
## tela não parecer travada em celular fraco. Segura o toque. Use com `await`: a função volta
## depois de o aviso ter sido desenhado, e quem chamou faz a conta e chama `busy_done`.
var _busy: Control
var _busy_label: Label
## O jogador tocou no aviso enquanto ele estava na tela (quem adianta várias semanas para aqui).
var busy_tapped := false


func busy(text: String, hint: String = "") -> void:
	busy_done()
	busy_tapped = false
	if main == null or DisplayServer.get_name() == "headless":
		return
	# Fundo escurecido (segura o toque) e, no meio, o aviso com o arco dourado girando.
	var layer := ColorRect.new()
	layer.color = Color(UIColors.BG, 0.78)
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIKit.vbox(UITokens.S2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.custom_minimum_size.x = 340
	var sp := Spinner.new()
	sp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sp)
	var l := UIKit.label(text, "Section")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	_busy_label = l
	if hint != "":
		var hl := UIKit.label(hint, "Muted", true)
		hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(hl)
		layer.gui_input.connect(func(ev: InputEvent):
			if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.is_pressed():
				busy_tapped = true)
	var box := PanelContainer.new()
	box.theme_type_variation = "Popover"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(UIKit.margin(v, 20, 16, 20, 16))
	holder.add_child(box)
	layer.add_child(holder)
	main.modal_host.add_child(layer)
	_busy = layer
	layer.modulate.a = 0.0
	layer.create_tween().tween_property(layer, "modulate:a", 1.0, 0.08)
	await get_tree().process_frame
	await get_tree().process_frame


## Arco que gira enquanto o jogo faz uma conta comprida.
class Spinner extends Control:
	var _a := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(72, 72)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_a = fmod(_a + delta * 5.2, TAU)
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_arc(c, 28.0, 0.0, TAU, 40, Color(1, 1, 1, 0.1), 6.0, true)
		draw_arc(c, 28.0, _a, _a + 1.9, 20, UIColors.GOLD, 6.0, true)


## Troca o texto do aviso sem tirá-lo da tela.
func busy_text(text: String) -> void:
	if is_instance_valid(_busy) and is_instance_valid(_busy_label):
		_busy_label.text = text


func busy_done() -> void:
	if is_instance_valid(_busy):
		_busy.queue_free()
	_busy = null
	_busy_label = null


## Aviso de comemoração (meta cumprida, conquista): ícone, título e uma linha, com filete
## dourado e o som de conquista. Fica um pouco mais na tela do que um aviso comum. Quando vários
## saem juntos, aparecem dois por vez e os outros esperam na fila, para não cobrir a tela.
const AWARD_LIVE_MAX := 1
var _award_queue: Array = []
var _award_live := 0
var _award_sfx_at := -10.0


func award_toast(title: String, text: String, icon_name: String = "trophy", _sound: bool = true) -> void:
	if main == null:
		print("%s: %s" % [title, text])
		return
	_award_queue.append([title, text, icon_name])
	_award_pump()


func _award_pump() -> void:
	if main == null or not is_instance_valid(main) or not is_instance_valid(main.toast_host):
		_award_queue.clear()
		_award_live = 0
		return
	while _award_live < AWARD_LIVE_MAX and not _award_queue.is_empty():
		var a: Array = _award_queue.pop_front()
		if _award_queue.size() >= 2:
			# Muitos de uma vez (uma virada de semana cheia): o primeiro aparece e o resto vira um
			# aviso só, em vez de uma fila que cobre a tela por dez segundos.
			var more := _award_queue.size()
			_award_queue.clear()
			_award_queue.append(["E mais %d" % more, "Veja em Temporada › Conquistas", "trophy"])
		_award_show(String(a[0]), String(a[1]), String(a[2]), 1.5 if not _award_queue.is_empty() else 2.2)


func _award_done() -> void:
	_award_live = maxi(0, _award_live - 1)
	if is_inside_tree():
		_award_pump.call_deferred()


func _award_show(title: String, text: String, icon_name: String, hold: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _award_sfx_at >= 1.0:
		_award_sfx_at = now
		Sfx.play("achievement", -6.0)
	_award_live += 1
	var p := PanelContainer.new()
	p.tree_exited.connect(_award_done)
	p.theme_type_variation = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := UIKit.hbox(14)
	var ic := UIKit.icon_rect(icon_name, 30, UIColors.GOLD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var v := UIKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.kicker(title))
	var tl := UIKit.label(text, "H3", true)
	tl.add_theme_font_size_override(&"font_size", UITokens.F_BODY_SMALL + 1)
	v.add_child(tl)
	row.add_child(v)
	p.add_child(row)
	main.toast_host.add_child(p)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.1)
	tw.tween_interval(hold)
	tw.tween_property(p, "modulate:a", 0.0, 0.2)
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
