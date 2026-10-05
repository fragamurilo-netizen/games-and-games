class_name NavMenu
extends RefCounted
## Menu do botão ☰ da barra superior: lista de todas as telas da carreira que não estão na
## barra de navegação, agrupadas pelo assunto, e as ações do jogo no pé.

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
	# O menu é do técnico: sempre nas cores do clube dele, mesmo aberto sobre uma tabela (cor da
	# liga) ou sobre a tela de outro clube. Ao fechar, a tela de baixo volta às cores dela.
	UIColors.apply_colors_for(w.user_club())
	var v := UIKit.vbox(6)
	v.tree_exited.connect(_restore_colors)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Menu", "H2")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal(), "Fechar"))
	v.add_child(head)
	# Lista em duas colunas quando cabe; as cinco áreas já estão na barra de navegação.
	var cols := UIKit.hbox(28)
	var left := UIKit.vbox(6)
	var right := UIKit.vbox(6)
	for c: VBoxContainer in [left, right]:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wide: bool = UIManager.main != null and UIManager.main.get_viewport_rect().size.x >= 1000.0
	if wide:
		cols.add_child(left)
		cols.add_child(right)
	else:
		cols.free()
		right.free()
	_group(left, "Caixa de entrada", [
		["Mensagens", "inbox", {}, InboxManager.unread_count(w)],
		["Notícias", "news", {}, w.unread_news_count()],
		["Redes", "social", {}, 0],
	])
	_group(left, "Elenco", [
		["Treino", "training", {}, 0],
		["Base", "academy", {}, 0],
		["Contratos", "contracts", {}, 0],
		["Numeração", "numbers", {}, 0],
		["Vestiário", "dressing_room", {}, 0],
		["Relações", "relations", {}, 0],
		["Raio-X tático", "xray", {}, 0],
		["Revelados pela base", "graduates", {"id": cid}, 0],
	])
	var r := right if wide else left
	_group(r, "Clube", [
		["Competições", "table", {}, 0],
		["Estatísticas", "team_stats", {}, 0],
		["Confrontos", "rivalry", {"a": cid}, 0],
		["Uniformes", "kit", {}, 0],
		["Camisas antigas", "kit_history", {"id": cid}, 0],
		["Elencos antigos", "past_squads", {"id": cid}, 0],
	])
	_group(r, "Carreira e mundo", [
		["Treinador", "manager", {}, 0],
		["Reputação", "reputation", {}, 0],
		["Conquistas", "achievements", {}, 0],
		["Seleções", "national", {}, 0],
		["Dança das cadeiras", "coach_moves", {}, 0],
		["História", "history", {}, 0],
		["Joias", "nextgen", {}, 0],
	])
	var game := UIKit.vbox(0)
	game.add_child(UIKit.section_header("Jogo"))
	game.add_child(_row("Salvar", func():
		UIManager.close_modal()
		if GameManager.save_now():
			UIManager.toast("Jogo salvo.", UIColors.GREEN)
		else:
			UIManager.toast("Não foi possível salvar agora.", UIColors.RED), false, 0))
	game.add_child(_row("Carregar", _go.bind("load", {}), _here("load"), 0))
	game.add_child(_row("Editor", _go.bind("editor", {}), _here("editor"), 0))
	game.add_child(_row("Opções", _go.bind("settings", {}), _here("settings"), 0))
	game.add_child(_row("Sair para o menu", func():
		UIManager.close_modal()
		UIManager.confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
			GameManager.close_career_async(func() -> void: UIManager.goto("menu"))), false, 0))
	r.add_child(game)
	v.add_child(cols if wide else left)
	UIManager.show_modal(v, true)


static func _restore_colors() -> void:
	var cur := UIManager.current()
	if cur == null or not GameManager.has_career():
		return
	UIColors.apply_context(GameManager.user_club(), cur.color_context())
	if UIManager.main != null:
		UIManager.main.restyle()


static func _group(v: VBoxContainer, title: String, items: Array) -> void:
	var g := UIKit.vbox(0)
	g.add_child(UIKit.section_header(title))
	for it in items:
		var screen := String(it[1])
		g.add_child(_row(String(it[0]), _go.bind(screen, it[2]), _here(screen), int(it[3])))
	g.add_child(UIKit.gap(10))
	v.add_child(g)


## Linha do menu: nome à esquerda, contador de não lidos à direita. A tela atual fica marcada.
static func _row(title: String, cb: Callable, here: bool, badge: int) -> PanelContainer:
	var h := UIKit.hbox(10)
	var l := UIKit.label(title)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if here:
		l.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	h.add_child(l)
	if badge > 0:
		h.add_child(UIKit.colored(str(badge) if badge < 100 else "99+", UIColors.RED, "Caps"))
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


static func _tab_name(tab: String) -> String:
	return {"hub": "Início", "squad": "Elenco", "tactics": "Tática", "market": "Mercado", "club": "Clube"}.get(tab, tab)


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
