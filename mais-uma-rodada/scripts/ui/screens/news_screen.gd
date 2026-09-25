extends BaseScreen
## Notícias do mundo, geradas a partir do que realmente aconteceu no save.

const FILTERS := [["all", "Todas"], ["mine", "Meu clube"], ["div", "Divisão"], ["market", "Mercado"]]
const MARKET_CATS := ["transferencia", "transferencia_rival", "transferencia_livre", "venda_usuario", "proposta_recebida", "janela_abre", "janela_fecha", "contrato_fim"]

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
	screen_subtitle = "Temporada %d" % w.year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for f in FILTERS:
		var key: String = f[0]
		var chip := UIKit.chip(f[1], key == _filter, g, func():
			_filter = key
			refresh())
		UIKit.shrink_button(chip)
		chip.add_theme_font_size_override(&"font_size", 18)
		row.add_child(chip)
	c.add_child(row)
	var items: Array = w.news.duplicate()
	items.reverse()
	var user := w.user_club()
	var shown := 0
	var last_key := ""
	for n: NewsEvent in items:
		if not _passes(w, n, user):
			continue
		var key := "%d-%d" % [n.year, n.day]
		if key != last_key:
			last_key = key
			c.add_child(UIKit.section("Rodada %d · %d" % [n.day + 1, n.year] if n.day < 38 else "Temporada %d" % n.year))
		c.add_child(NewsRow.make(w, n, false))
		shown += 1
	if shown == 0:
		c.add_child(UIKit.label("Nenhuma notícia com esse filtro.", "Muted"))


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
