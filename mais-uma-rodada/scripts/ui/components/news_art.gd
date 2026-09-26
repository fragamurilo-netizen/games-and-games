class_name NewsArt
extends Control
## Imagem das notícias, desenhada a partir do que aconteceu: apresentação do reforço segurando a
## camisa, placar com os escudos sobre as cores dos dois clubes, bandeiras das seleções, o
## jogador em estúdio nas cores do clube ou o escudo com o troféu. Sem mídia guardada, a imagem
## sai da categoria e do jogador/clube da notícia.

const TROPHY_CATS := ["campeao", "copa_campeao", "estadual_campeao", "mundial_campeao", "premio", "acesso"]

var kind := ""
var c1 := Color("#1B3A8C")
var c2 := Color("#FFFFFF")
var d1 := Color("#B3122E") # segundo clube / segunda seleção
var d2 := Color("#FFFFFF")
var score_text := ""
var caption := ""
var trophy := false


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Mídia da notícia (a guardada ou a deduzida). Vazio = notícia sem imagem.
static func media_of(w: GameWorld, n: NewsEvent) -> Dictionary:
	if not n.media.is_empty():
		return n.media
	var cat := n.category
	var p := w.player(n.player_id) if n.player_id >= 0 else null
	if p != null:
		return {"type": "player", "player": p.id, "club": n.club_id if n.club_id >= 0 else p.club_id}
	if n.club_id >= 0 and w.club(n.club_id) != null:
		return {"type": "crest", "club": n.club_id, "trophy": cat in TROPHY_CATS or cat.ends_with("_campeao")}
	if cat == "selecao" and w.has_user():
		return {"type": "nation", "code": w.user_nation()}
	return {}


## Imagem pronta, com cantos arredondados. Nulo se a notícia não tem imagem.
static func make(w: GameWorld, n: NewsEvent, height: int, compact: bool) -> Control:
	var m := media_of(w, n)
	if m.is_empty():
		return null
	var inner: Control = null
	match String(m.get("type", "")):
		"signing":
			inner = SigningPhoto.from_media(w, m, n.year, compact)
			if inner != null and compact and height < 160:
				(inner as SigningPhoto).show_tag = false
		"score":
			inner = _score(w, m, height)
		"nation":
			inner = _nation(m, height)
		"player":
			inner = _player(w, m, n.year)
		"crest":
			inner = _crest(w, m, height)
	if inner == null:
		return null
	inner.custom_minimum_size = Vector2(0, height)
	return _rounded(inner, 12 if height >= 160 else 10)


static func _rounded(inner: Control, radius: int) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE_2
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", box)
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(inner)
	return p


static func _club_cols(c: Club) -> Array:
	var a := Color(c.color1)
	var b := Color(c.color2)
	if absf(a.get_luminance() - b.get_luminance()) < 0.12:
		b = Color.WHITE if a.get_luminance() < 0.5 else Color("#111111")
	return [a, b]


static func _score(w: GameWorld, m: Dictionary, height: int) -> Control:
	var h := w.club(int(m.get("home", -1)))
	var a := w.club(int(m.get("away", -1)))
	if h == null or a == null:
		return null
	var art := NewsArt.new()
	art.kind = "score"
	var ch := _club_cols(h)
	var ca := _club_cols(a)
	art.c1 = ch[0]
	art.c2 = ch[1]
	art.d1 = ca[0]
	art.d2 = ca[1]
	art.score_text = "%d  x  %d" % [int(m.get("hg", 0)), int(m.get("ag", 0))]
	var comp := String(m.get("comp", ""))
	art.caption = FootballMemory.comp_name(w, comp).to_upper() if comp != "" else ""
	var cs := int(height * 0.5)
	for side in 2:
		var cv := UIKit.crest(h if side == 0 else a, cs)
		cv.set_meta(&"side", side)
		art.add_child(cv)
	art.resized.connect(art._place_children)
	return art


static func _nation(m: Dictionary, height: int) -> Control:
	var code := String(m.get("code", ""))
	if code == "":
		return null
	var art := NewsArt.new()
	art.kind = "nation"
	var vs := String(m.get("vs", ""))
	var codes := [code] if vs == "" else [code, vs]
	for i in codes.size():
		var f := FlagView.new()
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.code = codes[i]
		f.set_meta(&"side", i if codes.size() == 2 else -1)
		art.add_child(f)
	if vs != "":
		art.score_text = "%d  x  %d" % [int(m.get("ga", 0)), int(m.get("gb", 0))]
	art.trophy = bool(m.get("trophy", false))
	art.caption = DatabaseManager.nation_name(code).to_upper() if vs == "" else ""
	if art.trophy:
		var t := UIKit.icon_rect("trophy", int(height * 0.42), UIColors.D_GOLD)
		t.set_meta(&"side", 9)
		art.add_child(t)
	art.resized.connect(art._place_children)
	return art


static func _player(w: GameWorld, m: Dictionary, year: int) -> Control:
	var p := w.player(int(m.get("player", -1)))
	if p == null:
		return null
	var c := w.club(int(m.get("club", -1)))
	var art := NewsArt.new()
	art.kind = "studio"
	if c != null:
		var cc := _club_cols(c)
		art.c1 = cc[0]
		art.c2 = cc[1]
	else:
		art.c1 = Color("#2A3140")
		art.c2 = Color("#FFFFFF")
	var pv := PortraitView.new()
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.cutout = true
	pv.set_player(p, c, year)
	pv.set_meta(&"side", 5)
	art.add_child(pv)
	if c != null:
		var cv := UIKit.crest(c, 40)
		cv.set_meta(&"side", 6)
		art.add_child(cv)
	art.resized.connect(art._place_children)
	return art


static func _crest(w: GameWorld, m: Dictionary, height: int) -> Control:
	var c := w.club(int(m.get("club", -1)))
	if c == null:
		return null
	var art := NewsArt.new()
	art.kind = "crest"
	var cc := _club_cols(c)
	art.c1 = cc[0]
	art.c2 = cc[1]
	art.trophy = bool(m.get("trophy", false))
	var cv := UIKit.crest(c, int(height * 0.62))
	cv.set_meta(&"side", 7)
	art.add_child(cv)
	if art.trophy:
		var t := UIKit.icon_rect("trophy", int(height * 0.4), UIColors.D_GOLD)
		t.set_meta(&"side", 9)
		art.add_child(t)
	art.resized.connect(art._place_children)
	return art


func _place_children() -> void:
	var w := size.x
	var h := size.y
	for ch in get_children():
		if not ch is Control:
			continue
		var cc := ch as Control
		var side := int(cc.get_meta(&"side", -1))
		match kind:
			"score":
				var s := h * 0.5
				cc.size = Vector2(s, s)
				var cx := w * (0.2 if side == 0 else 0.8)
				cc.position = Vector2(cx - s * 0.5, h * 0.44 - s * 0.5)
			"nation":
				if side == 9:
					var s2 := h * 0.42
					cc.size = Vector2(s2, s2)
					cc.position = Vector2(w * 0.5 - s2 * 0.5, h * 0.5 - s2 * 0.5)
				elif side == -1:
					# Bandeira cobrindo tudo (3:2 cortada pelos lados ou em cima e embaixo).
					var fw := maxf(w, h * 1.5)
					cc.size = Vector2(fw, fw / 1.5)
					cc.position = Vector2((w - fw) * 0.5, (h - fw / 1.5) * 0.5)
				else:
					var fh := h * 0.46
					cc.size = Vector2(fh * 1.5, fh)
					var fx := w * (0.22 if side == 0 else 0.78)
					cc.position = Vector2(fx - fh * 0.75, h * 0.5 - fh * 0.5)
			"studio":
				if side == 5:
					var ps := h * 1.06
					cc.size = Vector2(ps, ps)
					cc.position = Vector2(w * 0.5 - ps * 0.5, h * 0.06)
				else:
					var s3 := h * 0.2
					cc.size = Vector2(s3, s3)
					cc.position = Vector2(w - s3 - h * 0.05, h * 0.05)
			"crest":
				if side == 9:
					var s4 := h * 0.4
					cc.size = Vector2(s4, s4)
					cc.position = Vector2(w * 0.5 + h * 0.2, h * 0.52)
				else:
					var s5 := h * 0.62
					cc.size = Vector2(s5, s5)
					cc.position = Vector2(w * 0.5 - s5 * 0.5 - (h * 0.12 if trophy else 0.0), h * 0.19)
	queue_redraw()
	if _fg == null:
		_fg = Control.new()
		_fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fg.draw.connect(_draw_fg)
		add_child(_fg)
	_fg.position = Vector2.ZERO
	_fg.size = size
	_fg.queue_redraw()


var _fg: Control = null


## Fundo: cores dos clubes com faixas diagonais e luz de estúdio.
func _draw() -> void:
	var w := size.x
	var h := size.y
	match kind:
		"score":
			var mid := w * 0.5
			var slant := h * 0.28
			draw_rect(Rect2(Vector2.ZERO, size), d1.darkened(0.35))
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(mid + slant, 0), Vector2(mid - slant, h), Vector2(0, h)]), c1.darkened(0.35))
			draw_line(Vector2(mid + slant, 0), Vector2(mid - slant, h), Color(1, 1, 1, 0.35), 3.0, true)
			_stripes(Color(1, 1, 1, 0.05))
			_light(Vector2(w * 0.5, h * 0.35), h)
		"nation":
			draw_rect(Rect2(Vector2.ZERO, size), Color("#101216"))
		"studio", "crest":
			var base := c1.darkened(0.5)
			var steps := 10
			for i in steps:
				var t := float(i) / float(steps)
				draw_rect(Rect2(0, h * t, w, h / steps + 1.0), base.lerp(c1.darkened(0.15), 1.0 - absf(t - 0.35) * 1.4))
			_stripes(Color(c2.r, c2.g, c2.b, 0.08))
			_light(Vector2(w * 0.5, h * 0.42), h)


func _stripes(col: Color) -> void:
	var h := size.y
	var x := -h
	while x < size.x + h:
		draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + h * 0.1, h), Vector2(x + h * 1.1, 0), Vector2(x + h, 0)]), col)
		x += h * 0.38


func _light(c: Vector2, h: float) -> void:
	for i in 7:
		draw_circle(c, h * (0.7 - i * 0.08), Color(1, 1, 1, 0.03), true, -1.0, true)


## Frente: placar, legenda, vinheta e véu nas bandeiras.
func _draw_fg() -> void:
	var cv := _fg
	var w := size.x
	var h := size.y
	var font := get_theme_font(&"font", &"Title") if has_theme_font(&"font", &"Title") else get_theme_default_font()
	var caps := get_theme_font(&"font", &"Stat") if has_theme_font(&"font", &"Stat") else font
	if kind == "nation":
		# Véu escuro para a legenda ficar legível sobre a bandeira.
		for i in (8 if score_text == "" else 0):
			var t := float(i) / 8.0
			cv.draw_rect(Rect2(0, h * (0.5 + t * 0.5), w, h * 0.0625 + 1.0), Color(0, 0, 0, 0.08 + 0.5 * t))
	if score_text != "":
		var fs := int(clampf(minf(h * 0.26, w * 0.1), 12.0, 72.0))
		var tw := font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var sy := h * (0.5 if kind == "nation" else 0.44)
		var box := Rect2(w * 0.5 - tw * 0.5 - fs * 0.35, sy - fs * 0.62, tw + fs * 0.7, fs * 1.24)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.04, 0.06, 0.82)
		sb.set_corner_radius_all(int(fs * 0.2))
		sb.anti_aliasing = true
		cv.draw_style_box(sb, box)
		cv.draw_string(font, Vector2(w * 0.5 - tw * 0.5, sy + fs * 0.36), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	if caption != "" and h >= 120.0:
		var cfs := int(clampf(h * 0.075, 10.0, 22.0))
		var cw := caps.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		if cw > w - 20.0:
			cfs = maxi(8, int(cfs * (w - 20.0) / cw))
			cw = caps.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs).x
		cv.draw_string(caps, Vector2(w * 0.5 - cw * 0.5, h - cfs * 0.9), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, cfs, Color(1, 1, 1, 0.9))
	# Vinheta leve nas bordas (cara de foto).
	for i in 4:
		var g := float(i + 1) * h * 0.02
		cv.draw_rect(Rect2(Vector2(g, g) * 0.0, size).grow(-g), Color(0, 0, 0, 0.035), false, h * 0.04)
