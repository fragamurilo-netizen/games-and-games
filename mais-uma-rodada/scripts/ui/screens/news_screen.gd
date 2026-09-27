extends BaseScreen
## Notícias do mundo, geradas a partir do que realmente aconteceu no save.

const FILTERS := [["all", "Todas"], ["mine", "Meu clube"], ["div", "Divisão"], ["market", "Mercado"]]
const MARKET_CATS := ["transferencia", "transferencia_rival", "transferencia_livre", "venda_usuario", "proposta_recebida", "janela_abre", "janela_fecha", "contrato_fim", "rumor"]

var _filter := "all"


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
	c.add_child(UIKit.tabs(FILTERS, _filter, func(k: String):
		_filter = k
		refresh()))
	var items: Array = w.news.duplicate()
	items.reverse()
	var user := w.user_club()
	var shown: Array = []
	for n: NewsEvent in items:
		if _passes(w, n, user):
			shown.append(n)
	if shown.is_empty():
		var empty := UIKit.card("CardFlat", 10)
		empty.add_child(UIKit.icon_rect("news", 48, UIColors.DIM))
		empty.add_child(UIKit.label("Nenhuma notícia com esse filtro.", "Muted"))
		c.add_child(UIKit.card_panel(empty))
		return
	# Manchete: a notícia mais importante da rodada mais recente.
	var lead: NewsEvent = shown[0]
	for n: NewsEvent in shown:
		if n.year != lead.year or n.day != shown[0].day:
			break
		if n.importance > lead.importance:
			lead = n
	c.add_child(NewsRow.hero(w, lead))
	# O resto, rodada a rodada, cada uma num cartão.
	var cards: Array = []
	var last_key := ""
	var group: Array = []
	var title := ""
	for n: NewsEvent in shown:
		if n == lead:
			continue
		var key := "%d-%d" % [n.year, n.day]
		if key != last_key:
			if not group.is_empty():
				cards.append(_round_card(title, group))
			group = []
			last_key = key
			title = tr("Rodada %d · %d") % [n.day + 1, n.year] if n.day < 38 else tr("Temporada %d") % n.year
		group.append(NewsRow.make(w, n, false))
	if not group.is_empty():
		cards.append(_round_card(title, group))
	var holder := UIKit.vbox(UITokens.S4)
	c.add_child(holder)
	UIKit.columns(holder, cards, content_width())


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
			return MARKET_CATS.has(n.category)
	return true
