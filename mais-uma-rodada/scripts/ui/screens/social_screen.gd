extends BaseScreen
## Redes sociais: o que clubes, jogadores, imprensa e torcida estão postando sobre o mundo do jogo
## (SocialFeed). Filtros por assunto; lançamentos de uniforme aparecem com a reação da torcida.

var _filter := "all"
var _limit := 30


func _init() -> void:
	show_nav = false
	screen_title = "Redes sociais"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_filter = String(p.get("filter", "all"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var user := w.user_club()
	screen_subtitle = "%s · %s seguidores" % [SocialFeed.club_acc(user)["handle"], SocialFeed.count(SocialFeed.followers(user))]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for f in SocialFeed.FILTERS:
		var key: String = f[0]
		var chip := UIKit.chip(f[1], key == _filter, g, func():
			_filter = key
			_limit = 30
			refresh())
		UIKit.shrink_button(chip)
		chip.add_theme_font_size_override(&"font_size", 18)
		row.add_child(chip)
	c.add_child(row)
	var posts := SocialFeed.posts(w, _filter, _limit + 1)
	if posts.is_empty():
		c.add_child(UIKit.label("Nada por aqui ainda. Jogos, contratações, coletivas e lançamentos de uniforme viram posts ao longo da temporada.", "Muted", true))
		return
	for i in mini(_limit, posts.size()):
		c.add_child(SocialPost.make(w, posts[i]))
	if posts.size() > _limit:
		c.add_child(UIKit.button("Carregar mais", "GhostButton", func():
			_limit += 30
			refresh(), "down"))
