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


## Telas abertas pelo menu há pouco (as mais recentes primeiro), para voltar a elas num toque.
static var recent: Array = []
const RECENT_MAX := 4


## Grupos do menu: [título, [[rótulo, tela, ícone], ...]]. Os parâmetros que dependem do clube
## entram em _params(). As cinco áreas já estão na barra de navegação.
const GROUPS := [
	["Caixa de entrada", [["Mensagens", "inbox", "mail"], ["Notícias", "news", "news"], ["Redes", "social", "chat"]]],
	["Elenco", [["Treino", "training", "cone"], ["Base", "academy", "boot"], ["Contratos", "contracts", "card"],
		["Numeração", "numbers", "hash"], ["Vestiário", "dressing_room", "heart"], ["Relações", "relations", "users"],
		["Raio-X tático", "xray", "pitch"], ["Revelados pela base", "graduates", "medal"]]],
	["Clube", [["Competições", "table", "table"], ["Estatísticas", "team_stats", "goal"], ["Estatísticas da liga", "league_stats", "podium"],
		["Confrontos", "rivalry", "swap"], ["Uniformes", "kit", "shirt"], ["Camisas antigas", "kit_history", "palette"],
		["Elencos antigos", "past_squads", "list"]]],
	["Carreira e mundo", [["Treinador", "manager", "user"], ["Reputação", "reputation", "star"], ["Conquistas", "achievements", "trophy"],
		["Seleções", "national", "globe"], ["Mercado de técnicos", "jobs", "whistle"], ["Dança das cadeiras", "coach_moves", "fast"],
		["Escolas de técnicos", "coach_schools", "info"], ["História", "history", "book"], ["Joias", "nextgen", "gem"],
		["Gerações", "generations", "up"]]],
]


static func _params(w: GameWorld, screen: String) -> Dictionary:
	var cid := w.user_club_id
	match screen:
		"graduates", "kit_history", "past_squads":
			return {"id": cid}
		"rivalry":
			return {"a": cid}
	return {}


static func _badge(w: GameWorld, screen: String) -> int:
	match screen:
		"inbox":
			return InboxManager.unread_count(w)
		"news":
			return w.unread_news_count()
	return 0


static func _item(screen: String) -> Array:
	for g in GROUPS:
		for it in g[1]:
			if it[1] == screen:
				return it
	return []


## Menu do ☰: ladrilhos com ícone em grade (duas colunas no celular, quatro na tela larga), as
## telas usadas há pouco no alto e as ações do jogo numa fileira de ícones no pé. Antes era uma
## lista de 30 linhas que pedia várias rolagens para chegar ao fim.
static func open() -> void:
	var w: GameWorld = GameManager.world
	if w == null or not w.has_user():
		return
	# O menu é do técnico: sempre nas cores do clube dele, mesmo aberto sobre uma tabela (cor da
	# liga) ou sobre a tela de outro clube. Ao fechar, a tela de baixo volta às cores dela.
	UIColors.apply_colors_for(w.user_club())
	var v := UIKit.vbox(UITokens.S2)
	v.tree_exited.connect(_restore_colors)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Menu", "H2")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal(), "Fechar"))
	v.add_child(head)
	var vw: float = UIManager.main.get_viewport_rect().size.x if UIManager.main != null else 600.0
	# A folha tem no máximo 820 px (UIManager.show_modal): cabem colunas de ~260 px.
	var cols := clampi(int(minf(vw, 820.0) / 260.0), 2, 4)
	var recent_items: Array = []
	for screen: String in recent:
		var it := _item(screen)
		if not it.is_empty():
			recent_items.append(it)
	if not recent_items.is_empty():
		v.add_child(_group(w, "Usados há pouco", recent_items, cols))
	for g in GROUPS:
		v.add_child(_group(w, String(g[0]), g[1], cols))
	v.add_child(_game_actions())
	UIManager.show_modal(v, true)


static func _restore_colors() -> void:
	var cur := UIManager.current()
	if cur == null or not GameManager.has_career():
		return
	UIColors.apply_context(GameManager.user_club(), cur.color_context())
	if UIManager.main != null:
		UIManager.main.restyle()


static func _group(w: GameWorld, title: String, items: Array, cols: int) -> Control:
	var g := UIKit.vbox(UITokens.S1)
	g.add_child(UIKit.section_header(title))
	var tiles: Array = []
	for it in items:
		var screen := String(it[1])
		tiles.append(UIKit.link_tile(String(it[2]), String(it[0]), "", _go.bind(screen, _params(w, screen)), _here(screen), _badge(w, screen)))
	g.add_child(UIKit.link_grid(tiles, cols))
	return g


## Ações do jogo numa fileira: ícone com o nome embaixo, cada uma com alvo de toque inteiro.
static func _game_actions() -> Control:
	var g := UIKit.vbox(UITokens.S1)
	g.add_child(UIKit.section_header("Jogo"))
	var row := UIKit.hbox(UITokens.S1)
	var acts := [
		["Salvar", "save", func():
			UIManager.close_modal()
			if GameManager.save_now():
				UIManager.toast("Salvando...", UIColors.ACCENT)
			else:
				UIManager.toast("Não foi possível salvar agora.", UIColors.RED)],
		["Carregar", "archive", _go.bind("load", {})],
		["Editor", "palette", _go.bind("editor", {})],
		["Opções", "gear", _go.bind("settings", {})],
		["Sair", "back", func():
			UIManager.close_modal()
			UIManager.confirm("Sair para o menu?", "Seu progresso é salvo automaticamente.", "Sair", func():
				GameManager.close_career_async(func() -> void: UIManager.goto("menu")))],
	]
	for a in acts:
		var col := UIKit.vbox(2)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := UIKit.icon_rect(String(a[1]), 28)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(ic)
		var l := UIKit.label(String(a[0]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(l)
		var tile := UIKit.tap_row(col, a[2], "CardFlat")
		tile.custom_minimum_size.y = UITokens.H_ROW
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tile)
	g.add_child(row)
	return g


static func _tab_name(tab: String) -> String:
	return {"hub": "Início", "squad": "Elenco", "tactics": "Tática", "market": "Mercado", "club": "Clube"}.get(tab, tab)


static func _here(screen: String) -> bool:
	var cur := UIManager.current()
	return cur != null and cur.screen_name == screen


static func _go(screen: String, params: Dictionary) -> void:
	UIManager.close_modal()
	if not _item(screen).is_empty():
		recent.erase(screen)
		recent.push_front(screen)
		recent.resize(mini(recent.size(), RECENT_MAX))
	if _here(screen):
		return
	if screen in UIManager.TABS:
		UIManager.goto(screen, params)
	else:
		UIManager.push(screen, params)
