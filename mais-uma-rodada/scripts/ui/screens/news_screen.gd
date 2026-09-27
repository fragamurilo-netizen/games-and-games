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
	screen_subtitle = "Temporada %d" % w.year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var chips := ScrollContainer.new()
	chips.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chips.custom_minimum_size.y = 56
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for f in FILTERS:
		var key: String = f[0]
		var chip := UIKit.chip(f[1], key == _filter, g, func():
			_filter = key
			_limit = PAGE
			refresh())
		chip.add_theme_font_size_override(&"font_size", 18)
		chip.custom_minimum_size.x = 0
		row.add_child(chip)
	chips.add_child(row)
	c.add_child(chips)
	var items: Array = []
	var user := w.user_club()
	for i in range(w.news.size() - 1, -1, -1):
		var n: NewsEvent = w.news[i]
		if _passes(w, n, user):
			items.append(n)
	if items.is_empty():
		c.add_child(UIKit.label("Nenhuma notícia com esse filtro.", "Muted"))
		return
	# Manchete: a notícia mais forte entre as mais recentes (as do seu país e com foto primeiro).
	var hero: NewsEvent = items[0]
	var best := -1
	for k in mini(10, items.size()):
		var n: NewsEvent = items[k]
		if n.year != (items[0] as NewsEvent).year or n.day < (items[0] as NewsEvent).day - 2:
			break
		var score := n.importance * 10 + (0 if NewsRow.is_foreign(w, n) else 3) + (1 if not n.media.is_empty() else 0)
		if score > best:
			best = score
			hero = n
	c.add_child(NewsRow.feature(w, hero, 400, true))
	var shown := 0
	var last_key := ""
	for n: NewsEvent in items:
		if n == hero:
			continue
		if shown >= _limit:
			var more := UIKit.button("Mostrar mais notícias", "GhostButton", func():
				_limit += PAGE
				refresh(), "list")
			c.add_child(more)
			break
		var key := "%d-%d" % [n.year, n.day]
		if key != last_key:
			last_key = key
			c.add_child(UIKit.section("Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else "Temporada %d" % n.year))
		if n.importance >= NewsEvent.IMP_HEADLINE or (n.importance >= NewsEvent.IMP_HIGH and String(n.media.get("type", "")) == "signing"):
			c.add_child(NewsRow.feature(w, n, 280, false))
		else:
			c.add_child(NewsRow.item(w, n))
		shown += 1


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
