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
	max_content_width = 1500
	var pl := w.player(_player) if _player >= 0 else null
	var cl := w.club(_club) if _club >= 0 else w.user_club()
	var acc := SocialFeed.player_acc(w, pl) if pl != null else SocialFeed.club_acc(cl)
	var fol := SocialFeed.player_followers(pl, w) if pl != null else SocialFeed.followers(cl, w)
	var growth := 0.0 if pl != null else SocialFeed.season_growth(cl, w)
	var profile := pl != null or _club >= 0
	screen_subtitle = String(acc["handle"]) if profile else "Feed"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var own := SocialFeed.posts(w, "all", 200, cl.id if pl == null else -1, _player)
	var header := SocialPost.profile_header(w, acc, fol, growth, own.size())
	var filters: Control = null
	if not profile:
		var items: Array = []
		for f in SocialFeed.FILTERS:
			items.append([f[0], f[1]])
		filters = UIKit.scroll_tabs(items, _filter, func(k: String):
			_filter = k
			_limit = 30
			refresh())
	var feed := UIKit.vbox(UITokens.S3)
	feed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := SocialFeed.posts(w, "all", _limit + 1, _club if pl == null else -1, _player) if profile else SocialFeed.posts(w, _filter, _limit + 1)
	_list(w, feed, list)
	if not UILayout.is_wide():
		c.add_child(header)
		if filters != null:
			c.add_child(filters)
		c.add_child(feed)
		return
	# Tela larga: perfil e filtros numa coluna fixa, o feed ao lado (como a versão de computador
	# de uma rede social), com largura de leitura.
	var split := UIKit.hbox(UITokens.S6)
	c.add_child(split)
	var side := UIKit.vbox(UITokens.S4)
	side.custom_minimum_size.x = 440
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	side.add_child(header)
	if filters != null:
		var rows: Array = []
		for f in SocialFeed.FILTERS:
			var key: String = f[0]
			var tick: Control = UIKit.icon_rect("check", 22, UIColors.ACCENT) if key == _filter else null
			rows.append(UIKit.menu_row("", f[1], "", func():
				_filter = key
				_limit = 30
				refresh(), tick))
		side.add_child(UIKit.section_header("Assuntos"))
		side.add_child(UIKit.menu_group(rows))
	split.add_child(side)
	feed.custom_minimum_size.x = 0
	split.add_child(feed)


func _list(w: GameWorld, c: VBoxContainer, posts: Array) -> void:
	if posts.is_empty():
		var empty := UIKit.card("CardFlat", 10)
		empty.add_child(UIKit.icon_rect("chat", 48, UIColors.DIM))
		empty.add_child(UIKit.label("Nada por aqui ainda.", "Muted", true))
		c.add_child(UIKit.card_panel(empty))
		return
	for i in mini(_limit, posts.size()):
		c.add_child(SocialPost.make(w, posts[i]))
	if posts.size() > _limit:
		c.add_child(UIKit.button("Carregar mais", "GhostButton", func():
			_limit += 30
			refresh(), "down"))
