class_name NavMenu
extends RefCounted
## Menu do botão ☰ da barra superior: atalho para todas as telas da carreira, de qualquer
## lugar (as telas internas escondem a navegação inferior). Grade de ícones por seção, para
## caber quase tudo sem rolar; a tela atual fica destacada.

## Telas em que o menu fica escondido: fluxos que precisam terminar antes de sair.
const HIDDEN_ON := ["menu", "new_career", "match", "welcome", "season_end", "preseason", "paywall"]


static func available(screen: BaseScreen) -> bool:
	if not GameManager.has_career() or screen == null:
		return false
	if screen.screen_name in HIDDEN_ON:
		return false
	# Hub sem navegação = treinador escolhendo emprego.
	return not (screen.screen_name == "hub" and not screen.show_nav)


static func open() -> void:
	var w: GameWorld = GameManager.world
	if w == null or not w.has_user():
		return
	var cid := w.user_club_id
	var unread := InboxManager.unread_count(w)
	var news := w.unread_news_count()
	var v := UIKit.vbox(10)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Menu", "Title")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal(), "Fechar"))
	v.add_child(head)
	_group(v, "Dia a dia", [
		["home", "Início", "hub", {}, 0],
		["list", "Elenco", "squad", {}, 0],
		["swap", "Mercado", "market", {}, 0],
		["table", "Tabelas", "table", {}, 0],
		["shield", "Clube", "club", {}, 0],
		["mail", "Mensagens", "inbox", {}, unread],
		["news", "Notícias", "news", {}, news],
		["chat", "Redes", "social", {}, 0],
	])
	_group(v, "Time", [
		["tactics", "Treino", "training", {}, 0],
		["up", "Base", "academy", {}, 0],
		["star", "Revelados", "graduates", {"id": cid}, 0],
		["money", "Contratos", "contracts", {}, 0],
		["shirt", "Numeração", "numbers", {}, 0],
		["heart", "Vestiário", "dressing_room", {}, 0],
		["search", "Raio-X", "xray", {}, 0],
		["chat", "Relações", "relations", {}, 0],
	])
	_group(v, "Clube e carreira", [
		["shirt", "Uniformes", "kit", {}, 0],
		["shirt", "Camisas antigas", "kit_history", {"id": cid}, 0],
		["clock", "Elencos antigos", "past_squads", {"id": cid}, 0],
		["star", "Treinador", "manager", {}, 0],
		["swap", "Técnicos", "coach_moves", {}, 0],
		["shield", "Seleções", "national", {}, 0],
		["trophy", "História", "history", {}, 0],
		["ball", "Joias", "nextgen", {}, 0],
	])
	v.add_child(UIKit.section("Jogo"))
	var tiles: Array = [
		_tile("trophy", "Conquistas", _go.bind("achievements", {}), false, 0),
		_tile("save", "Salvar", func():
			UIManager.close_modal()
			if GameManager.save_now():
				UIManager.toast("Jogo salvo.", UIColors.GREEN)
			else:
				UIManager.toast("Não foi possível salvar agora.", UIColors.RED), false, 0),
		_tile("list", "Carregar", _go.bind("load", {}), _here("load"), 0),
		_tile("palette", "Editor", _go.bind("editor", {}), _here("editor"), 0),
		_tile("gear", "Opções", _go.bind("settings", {}), _here("settings"), 0),
		_tile("back", "Sair", func():
			UIManager.close_modal()
			UIManager.confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
				GameManager.close_career()
				UIManager.goto("menu")), false, 0),
	]
	v.add_child(_grid(tiles))
	UIManager.show_modal(v, true)


static func _group(v: VBoxContainer, title: String, items: Array) -> void:
	v.add_child(UIKit.section(title))
	var tiles: Array = []
	for it in items:
		var screen := String(it[2])
		tiles.append(_tile(String(it[0]), String(it[1]), _go.bind(screen, it[3]), _here(screen), int(it[4])))
	v.add_child(_grid(tiles))


static func _grid(tiles: Array) -> GridContainer:
	var g := UIKit.tile_grid(tiles, 4)
	g.add_theme_constant_override(&"h_separation", 8)
	g.add_theme_constant_override(&"v_separation", 8)
	return g


static func _here(screen: String) -> bool:
	var cur := UIManager.current()
	return cur != null and cur.screen_name == screen


static func _go(screen: String, params: Dictionary) -> void:
	UIManager.close_modal()
	if _here(screen):
		return
	if screen in UIManager.TABS:
		UIManager.goto(screen, params)
	else:
		UIManager.push(screen, params)


## Ladrilho compacto: ícone e nome curto, contador de não lidos no canto.
static func _tile(icon_name: String, title: String, cb: Callable, here: bool, badge: int) -> PanelContainer:
	var box := UIKit.vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := UIKit.icon_rect(icon_name, 34, UIColors.ON_ACCENT if here else UIColors.ACCENT)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ic)
	var l := UIKit.label(title, "Small")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = 2
	l.add_theme_color_override(&"font_color", UIColors.ON_ACCENT if here else UIColors.TEXT)
	box.add_child(l)
	var row := UIKit.tap_row(box, cb, "CardHighlight" if here else "Card")
	if here:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.ACCENT
		sb.set_corner_radius_all(UITokens.R_SM)
		sb.set_content_margin_all(8)
		row.add_theme_stylebox_override(&"panel", sb)
	else:
		var sb := row.get_theme_stylebox(&"panel") as StyleBoxFlat
		if sb != null:
			sb = sb.duplicate()
			sb.set_content_margin_all(8)
			row.add_theme_stylebox_override(&"panel", sb)
	row.custom_minimum_size = Vector2(0, 112)
	if badge > 0:
		var b := UIKit.pill(str(badge) if badge < 100 else "99+", UIColors.RED, 16)
		b.size_flags_horizontal = Control.SIZE_SHRINK_END
		b.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(b)
		row.move_child(b, 1)
	return row
