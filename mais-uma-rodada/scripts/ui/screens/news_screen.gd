extends BaseScreen
## Notícias do mundo, geradas a partir do que realmente aconteceu no save: manchete com foto no
## alto, matérias importantes com imagem grande e o resto do feed com miniaturas. Filtros por
## editoria (seu clube, sua liga, mercado, pelo mundo, seleções).

const FILTERS := [["all", "Destaques"], ["mine", "Meu clube"], ["div", "Minha liga"], ["market", "Mercado"], ["world", "Pelo mundo"], ["nat", "Seleções"]]
const PAGE := 30

var _filter := "all"
var _limit := PAGE


func _init() -> void:
	show_nav = false
	screen_title = "Notícias"


func on_show() -> void:
	refresh()
	# O que foi exibido agora conta como lido (os marcadores de "nova" ficam até sair da tela).
	var w := world()
	if w != null:
		for n: NewsEvent in w.news:
			n.read = true


func refresh() -> void:
	var w := world()
	if w == null:
		return
	max_content_width = 1700
	screen_subtitle = "Temporada %d" % w.year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)

	# Navegação do redesign novo, mas mantendo todos os filtros adicionados depois.
	c.add_child(UIKit.tabs(FILTERS, _filter, func(k: String):
		_filter = k
		_limit = PAGE
		refresh()))

	var items: Array = []
	var user := w.user_club()
	for i in range(w.news.size() - 1, -1, -1):
		var n: NewsEvent = w.news[i]
		if _passes(w, n, user):
			items.append(n)
	if items.is_empty():
		var empty := UIKit.card("CardFlat", 10)
		empty.add_child(UIKit.icon_rect("news", 48, UIColors.DIM))
		empty.add_child(UIKit.label("Nenhuma notícia com esse filtro.", "Muted"))
		c.add_child(UIKit.card_panel(empty))
		return

	# Manchete: preserva o algoritmo mais recente, que considera importância, país e arte.
	var lead: NewsEvent = items[0]
	var best := -1
	for k in mini(10, items.size()):
		var n: NewsEvent = items[k]
		if n.year != (items[0] as NewsEvent).year or n.day < (items[0] as NewsEvent).day - 2:
			break
		var score := n.importance * 10 + (0 if NewsRow.is_foreign(w, n) else 3) + (1 if not n.media.is_empty() else 0)
		if score > best:
			best = score
			lead = n
	c.add_child(NewsRow.hero(w, lead))

	# Feed do redesign: rodadas viram cartões e se distribuem em colunas no desktop.
	var cards: Array = []
	var last_key := ""
	var group: Array = []
	var title := ""
	var shown := 0
	var has_more := false
	for n: NewsEvent in items:
		if n == lead:
			continue
		if shown >= _limit:
			has_more = true
			break
		var key := "%d-%d" % [n.year, n.day]
		if key != last_key:
			if not group.is_empty():
				cards.append(_round_card(title, group))
			group = []
			last_key = key
			title = tr("Rodada %d · %d") % [n.day + 1, n.year] if n.day < 38 else tr("Temporada %d") % n.year
		if n.importance >= NewsEvent.IMP_HEADLINE or (n.importance >= NewsEvent.IMP_HIGH and String(n.media.get("type", "")) == "signing"):
			group.append(NewsRow.feature(w, n, 220, false))
		else:
			group.append(NewsRow.item(w, n))
		shown += 1
	if not group.is_empty():
		cards.append(_round_card(title, group))

	var holder := UIKit.vbox(UITokens.S4)
	c.add_child(holder)
	UIKit.columns(holder, cards, content_width())
	if has_more:
		c.add_child(UIKit.button("Mostrar mais notícias", "GhostButton", func():
			_limit += PAGE
			refresh(), "list"))


func _round_card(title: String, rows: Array) -> Control:
	var v := UIKit.vbox(UITokens.S2)
	v.add_child(UIKit.section_header(title))
	v.add_child(UIKit.menu_group(rows))
	return v

func _passes(w: GameWorld, n: NewsEvent, user: Club) -> bool:
	match _filter:
		"mine":
			if n.club_id == user.id:
				return true
			var p := w.player(n.player_id) if n.player_id >= 0 else null
			return p != null and p.club_id == user.id
		"div":
			var c := w.club(n.club_id) if n.club_id >= 0 else null
			return c != null and c.league_id == user.league_id
		"market":
			return NewsRow.MARKET_CATS.has(n.category)
		"world":
			return NewsRow.is_foreign(w, n)
		"nat":
			return n.category == "selecao"
	return true
