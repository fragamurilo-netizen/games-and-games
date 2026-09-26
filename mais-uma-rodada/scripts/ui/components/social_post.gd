class_name SocialPost
extends RefCounted
## Cartão de um post das redes (SocialFeed): avatar, nome com selo, @, texto, mídia (uniformes,
## placar, jogador, taça, sala de imprensa), números de engajamento e as respostas da torcida.


static func make(w: GameWorld, p: Dictionary, show_replies: bool = true) -> Control:
	var card := UIKit.card("Card", 10)
	var acc: Dictionary = p["acc"]
	var head := UIKit.hbox(12)
	head.add_child(avatar(w, acc, 56))
	var who := UIKit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.hbox(6)
	var nl := UIKit.label(String(acc["name"]), "H3")
	nm.add_child(nl)
	if bool(acc.get("verified", false)):
		var vb := UIKit.icon_rect("check", 22, UIColors.BLUE)
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_child(vb)
	nm.add_child(UIKit.spacer())
	who.add_child(nm)
	var sub := String(acc["handle"])
	if String(acc.get("outlet", "")) != "":
		sub += " · " + String(acc["outlet"])
	var hl := UIKit.label(sub, "Small")
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(hl)
	head.add_child(who)
	head.add_child(UIKit.label(when(w, p), "Caps"))
	var cid := int(p.get("club", -1))
	var pid := int(p.get("player", -1))
	if int(acc.get("player", -1)) >= 0:
		pid = int(acc["player"])
	if pid >= 0 or cid >= 0:
		card.add_child(UIKit.tap_row(head, func():
			if pid >= 0 and w.player(pid) != null:
				UIManager.push("player", {"id": pid})
			elif cid >= 0 and w.club(cid) != null:
				UIManager.push("club", {"id": cid}), "RowPanel"))
	else:
		card.add_child(head)
	card.add_child(_rich(String(p["text"])))
	var media := _media(w, p)
	if media != null:
		card.add_child(media)
	card.add_child(_counts(p))
	if show_replies:
		var reps: Array = p.get("replies", [])
		if not reps.is_empty():
			var box := UIKit.vbox(8)
			for rp: Dictionary in reps:
				box.add_child(_reply(w, rp))
			var inner := UIKit.card("CardFlat", 8)
			inner.add_child(box)
			card.add_child(UIKit.card_panel(inner))
	return UIKit.card_panel(card)


static func when(w: GameWorld, p: Dictionary) -> String:
	var y := int(p["y"])
	if String(p.get("cat", "")) == "uniforme":
		return "Pré-temp. %d" % y
	if y == w.year and w.season != null:
		var lbl := w.season.date_label(int(p.get("d", 0)), false)
		if lbl != "":
			return lbl
	return str(y)


## Hashtags e @ destacados na cor de destaque.
static func _rich(text: String) -> Control:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var acc := UIColors.ACCENT.to_html(false)
	var out := ""
	for ln in text.split("\n"):
		var words: Array = []
		for wd in String(ln).split(" "):
			if wd.begins_with("#") or (wd.begins_with("@") and wd.length() > 1):
				words.append("[color=#%s]%s[/color]" % [acc, wd])
			else:
				words.append(wd.replace("[", "[lb]"))
		out += ("\n" if out != "" else "") + " ".join(words)
	l.text = out
	l.add_theme_color_override(&"default_color", UIColors.TEXT)
	return l


static func _counts(p: Dictionary) -> Control:
	var row := UIKit.hbox(22)
	for it in [["chat", int(p.get("n_rep", 0))], ["swap", int(p.get("rts", 0))], ["heart", int(p.get("likes", 0))]]:
		var h := UIKit.hbox(6)
		h.add_child(UIKit.icon_rect(String(it[0]), 22, UIColors.RED if it[0] == "heart" else UIColors.MUTED))
		h.add_child(UIKit.label(SocialFeed.count(int(it[1])), "Small"))
		row.add_child(h)
	var rec: Dictionary = p.get("reception", {})
	if not rec.is_empty():
		row.add_child(UIKit.spacer())
		var s := int(rec["score"])
		row.add_child(UIKit.pill(String(rec["label"]), UIColors.GREEN if s >= 56 else (UIColors.ORANGE if s >= 40 else UIColors.RED), 15))
	return row


static func _reply(w: GameWorld, rp: Dictionary) -> Control:
	var acc: Dictionary = rp["acc"]
	var row := UIKit.hbox(10)
	var av := avatar(w, acc, 34)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(av)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(String(acc["handle"]), "Caps"))
	v.add_child(UIKit.label(String(rp["text"]), "Small", true))
	row.add_child(v)
	var h := UIKit.hbox(4)
	h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(UIKit.icon_rect("heart", 16, UIColors.DIM))
	h.add_child(UIKit.label(SocialFeed.count(int(rp.get("likes", 0))), "Caps"))
	row.add_child(h)
	return row


## Avatar: escudo (clube e organizada), rosto (jogador) ou iniciais (imprensa e torcedor).
static func avatar(w: GameWorld, acc: Dictionary, px: int) -> Control:
	match String(acc["kind"]):
		"club":
			var c := w.club(int(acc["club"]))
			if c != null:
				return _ring(UIKit.crest(c, px - 10), px, Color(String(acc.get("color", "#FFFFFF"))))
		"player":
			var pl := w.player(int(acc["player"]))
			if pl != null:
				var pv := UIKit.portrait(pl, w.club(pl.club_id), w.year, px)
				return pv
		"fans":
			var cf := w.club(int(acc["club"]))
			if cf != null:
				var d := InitialsDot.new()
				d.text = _initials(String(acc["name"]))
				d.bg = Color(cf.color1)
				d.fg = Color(cf.color2)
				d.custom_minimum_size = Vector2(px, px)
				d.flag = true
				return d
	var dot := InitialsDot.new()
	dot.text = _initials(String(acc["name"]))
	dot.bg = Color(String(acc.get("color", "#4EA8DE")))
	dot.custom_minimum_size = Vector2(px, px)
	return dot


## Iniciais das duas primeiras palavras que contam ("Torcida Jovem do Sport" → "TJ").
static func _initials(name: String) -> String:
	var ini := ""
	for part in name.split(" ", false):
		if part.length() <= 3 and part.to_lower() in ["do", "da", "de", "dos", "das", "the", "la", "el", "del", "los"]:
			continue
		ini += part.substr(0, 1).to_upper()
		if ini.length() >= 2:
			break
	return ini


static func _ring(inner: Control, px: int, col: Color) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE_3
	box.border_color = col
	box.set_border_width_all(2)
	box.set_corner_radius_all(px / 2)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	p.add_theme_stylebox_override(&"panel", box)
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(inner)
	return p


# ---------------------------------------------------------------------------
# Mídia
# ---------------------------------------------------------------------------

static func _media(w: GameWorld, p: Dictionary) -> Control:
	var m: Dictionary = p.get("media", {})
	match String(m.get("type", "")):
		"kits":
			return kit_stage(w, w.club(int(m["club"])), m, int(p["y"]))
		"score":
			return _score(w, m)
		"player":
			var pl := w.player(int(m["player"]))
			return _player(w, pl) if pl != null else null
		"trophy":
			return _trophy(w, m)
		"press":
			var c := w.club(int(m["club"]))
			if c == null:
				return null
			var room := PressRoomView.new()
			room.setup(w, c)
			room.compact = true
			room.custom_minimum_size = Vector2(0, 200)
			return _framed(room)
	return null


static func _framed(inner: Control) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE_2
	box.border_color = UIColors.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(14)
	box.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", box)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(inner)
	return p


## Foto de lançamento: os três uniformes lado a lado sobre um fundo nas cores do clube.
static func kit_stage(w: GameWorld, c: Club, m: Dictionary, year: int) -> Control:
	var stage := KitStage.new()
	stage.col1 = Color(c.color1) if c != null else UIColors.SURFACE_3
	stage.col2 = Color(c.color2) if c != null else UIColors.SURFACE_2
	stage.caption = ("%s · %d" % [c.short_name, year]).to_upper() if c != null else str(year)
	stage.custom_minimum_size = Vector2(0, 250)
	var row := UIKit.hbox(4)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 16
	row.offset_bottom = -30
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in ["a", "h", "t"]:
		var kd: Dictionary = m.get(k, {})
		if kd.is_empty():
			continue
		var kv := UIKit.kit(kd, 110 if k == "h" else 92, 0, c.crest if c != null else {})
		kv.full = true
		kv.custom_minimum_size = Vector2(124 if k == "h" else 104, 204 if k == "h" else 176)
		kv.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(kv)
	stage.add_child(row)
	return _framed(stage)


static func _score(w: GameWorld, m: Dictionary) -> Control:
	var v := UIKit.vbox(6)
	var comp := UIKit.label(FootballMemory.comp_name(w, String(m.get("comp", ""))).to_upper(), "Caps")
	comp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(comp)
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var h := w.club(int(m["home"]))
	var a := w.club(int(m["away"]))
	for i in 3:
		if i == 1:
			var s := UIKit.label("%d  x  %d" % [int(m["hg"]), int(m["ag"])], "Title")
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s.custom_minimum_size.x = 150
			row.add_child(s)
			continue
		var c := h if i == 0 else a
		var col := UIKit.vbox(4)
		col.custom_minimum_size.x = 150
		var cr := UIKit.crest(c, 64)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(cr)
		var n := UIKit.label(c.short_name if c != null else "?", "H3")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		col.add_child(n)
		row.add_child(col)
	v.add_child(row)
	if int(m.get("pen_h", -1)) >= 0:
		var pl := UIKit.label("Pênaltis: %d x %d" % [int(m["pen_h"]), int(m["pen_a"])], "Small")
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(pl)
	return _framed(UIKit.margin(v, 12, 12, 12, 12))


static func _player(w: GameWorld, pl: Player) -> Control:
	var c := w.club(pl.club_id) if pl.club_id >= 0 else null
	var row := UIKit.hbox(14)
	row.add_child(UIKit.portrait(pl, c, w.year, 96))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(UIKit.label(pl.display_name(), "H2"))
	v.add_child(UIKit.label("%s · %d anos%s" % [Pos.code(pl.position), pl.age(w.year), (" · " + c.short_name) if c != null else ""], "Small"))
	row.add_child(v)
	if c != null:
		var cr := UIKit.crest(c, 56)
		cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cr)
	return _framed(UIKit.margin(row, 12, 10, 16, 10))


static func _trophy(w: GameWorld, m: Dictionary) -> Control:
	var c := w.club(int(m["club"]))
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(UIKit.icon_rect("trophy", 72, UIColors.GOLD))
	if c != null:
		row.add_child(UIKit.crest(c, 72))
	return _framed(UIKit.margin(row, 12, 14, 12, 14))


# ---------------------------------------------------------------------------
# Apresentação dos uniformes
# ---------------------------------------------------------------------------

## Depois do lançamento: o post oficial com os uniformes da temporada e como a torcida reagiu.
static func show_launch(w: GameWorld) -> void:
	var club := w.user_club()
	var hist := KitDesign.history(club)
	var kits: Dictionary = {"h": club.kit_home, "a": club.kit_away, "t": club.third_kit()}
	var prev: Dictionary = {}
	for h in hist:
		if int(h[0]) < w.year:
			prev = h[1]
			break
	var p := SocialFeed.kit_post(w, club, w.year, kits, prev)
	var rec: Dictionary = p["reception"]
	var v := UIKit.vbox(14)
	v.custom_minimum_size.x = 620
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect("chat", 48, UIColors.ACCENT))
	var t := UIKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UIKit.label("Uniformes %d apresentados" % w.year, "Title", true))
	t.add_child(UIKit.label("O post oficial já está nas redes. Veja como a torcida recebeu.", "Small", true))
	head.add_child(t)
	v.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 560
	var inner := UIKit.vbox(12)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(make(w, p))
	var notes := UIKit.card("CardFlat", 6)
	var s := int(rec["score"])
	var top := UIKit.hbox(10)
	var cap := UIKit.label("Aprovação da torcida", "Caps")
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(cap)
	var col := UIColors.GREEN if s >= 56 else (UIColors.ORANGE if s >= 40 else UIColors.RED)
	top.add_child(UIKit.colored("%d%%" % s, col, "H2"))
	notes.add_child(top)
	notes.add_child(UIKit.bar(s, 100, col, 10))
	for n in rec["notes"]:
		notes.add_child(UIKit.label("• " + String(n), "Small", true))
	inner.add_child(UIKit.card_panel(notes))
	scroll.add_child(inner)
	v.add_child(scroll)
	v.add_child(UIKit.button("VER NAS REDES", "PrimaryButton", func():
		UIManager.close_modal()
		UIManager.push("social", {"filter": "kits"}), "chat"))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


# ---------------------------------------------------------------------------
# Perfis
# ---------------------------------------------------------------------------

## Cabeçalho de perfil: avatar, nome, @, seguidores, crescimento na temporada e posts.
static func profile_header(w: GameWorld, acc: Dictionary, followers: int, growth: float, n_posts: int) -> Control:
	var card := UIKit.card("CardHighlight", 10)
	var row := UIKit.hbox(14)
	row.add_child(avatar(w, acc, 88))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.hbox(6)
	nm.add_child(UIKit.label(String(acc["name"]), "H2", true))
	if bool(acc.get("verified", false)):
		var vb := UIKit.icon_rect("check", 24, UIColors.BLUE)
		vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nm.add_child(vb)
	col.add_child(nm)
	col.add_child(UIKit.label(String(acc["handle"]), "Small"))
	row.add_child(col)
	card.add_child(row)
	var stats := UIKit.hbox(10)
	for it in [[SocialFeed.count(followers), "seguidores"], [str(n_posts), "posts recentes"],
			[("%+.1f%%" % (growth * 100.0)).replace(".", ","), "na temporada"]]:
		var s := UIKit.stat(String(it[0]), String(it[1]), (UIColors.GREEN if growth > 0.001 else (UIColors.RED if growth < -0.001 else UIColors.TEXT)) if it[1] == "na temporada" else UIColors.TEXT)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(s)
	card.add_child(stats)
	return UIKit.card_panel(card)


## Cartão "Redes sociais" para o perfil de um clube ou jogador: seguidores e o último post.
static func mini_card(w: GameWorld, club_id: int, player_id: int) -> Control:
	var posts := SocialFeed.posts(w, "all", 1, club_id, player_id)
	var card := UIKit.card("Card", 10)
	var head := UIKit.hbox(8)
	var sec := UIKit.section("Redes sociais")
	sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sec)
	var f := 0
	var handle := ""
	if player_id >= 0:
		var p := w.player(player_id)
		f = SocialFeed.player_followers(p, w)
		handle = String(SocialFeed.player_acc(w, p)["handle"])
	else:
		var c := w.club(club_id)
		f = SocialFeed.followers(c, w)
		handle = String(SocialFeed.club_acc(c)["handle"])
	head.add_child(UIKit.label("%s · %s seguidores" % [handle, SocialFeed.count(f)], "Small"))
	card.add_child(head)
	if posts.is_empty():
		card.add_child(UIKit.label("Nenhum post recente.", "Muted"))
	else:
		card.add_child(make(w, posts[0], false))
	card.add_child(UIKit.button("Ver o perfil nas redes", "GhostButton", func():
		UIManager.push("social", {"club": club_id, "player": player_id}), "chat"))
	return UIKit.card_panel(card)
