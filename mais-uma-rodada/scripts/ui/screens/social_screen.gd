extends BaseScreen
## Redes sociais: o que clubes, jogadores, imprensa e torcida estão postando sobre o mundo do jogo
## (SocialFeed). Filtros por assunto; lançamentos de uniforme aparecem com a reação da torcida.

var _filter := "all"
var _limit := 30


func _init() -> void:
	show_nav = false
	screen_title = "Redes sociais"


var _club := -1
var _player := -1


func setup(p: Dictionary) -> void:
	super.setup(p)
	_filter = String(p.get("filter", "all"))
	_club = int(p.get("club", -1))
	_player = int(p.get("player", -1))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var pl := w.player(_player) if _player >= 0 else null
	var cl := w.club(_club) if _club >= 0 else w.user_club()
	var acc := SocialFeed.player_acc(w, pl) if pl != null else SocialFeed.club_acc(cl)
	var fol := SocialFeed.player_followers(pl, w) if pl != null else SocialFeed.followers(cl, w)
	var growth := 0.0 if pl != null else SocialFeed.season_growth(cl, w)
	screen_subtitle = String(acc["handle"]) if (pl != null or _club >= 0) else "Feed"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var own := SocialFeed.posts(w, "all", 200, cl.id if pl == null else -1, _player)
	c.add_child(SocialPost.profile_header(w, acc, fol, growth, own.size()))
	if pl != null or _club >= 0:
		var list := SocialFeed.posts(w, "all", _limit + 1, _club if pl == null else -1, _player)
		_list(w, c, list)
		return
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
	_list(w, c, SocialFeed.posts(w, _filter, _limit + 1))


func _list(w: GameWorld, c: VBoxContainer, posts: Array) -> void:
	if posts.is_empty():
		c.add_child(UIKit.label("Nada por aqui ainda. Jogos, contratações, coletivas e lançamentos de uniforme viram posts ao longo da temporada.", "Muted", true))
		return
	for i in mini(_limit, posts.size()):
		c.add_child(SocialPost.make(w, posts[i]))
	if posts.size() > _limit:
		c.add_child(UIKit.button("Carregar mais", "GhostButton", func():
			_limit += 30
			refresh(), "down"))
