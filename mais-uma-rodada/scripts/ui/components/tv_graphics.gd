class_name TvGraphics
extends RefCounted
## Peças do grafismo de TV da partida, no pacote da competição (TvPackage):
##   goal_banner   faixa do gol na cor do clube: sigla | escudo | palavra do gol | minuto
##   scorer_card   tarja do goleador com o recorte do jogador saindo da peça
##   stat_card     números lado a lado com barra dividida nas cores dos times
##   table_card    tabela ao vivo ("se terminasse agora"), com setas e os times em campo marcados
##   sub_card      substituição (entra/sai) · booking_card  cartão · info_card  estádio, público...
##   potm_card     melhor em campo · sector_card  escalação por setor com recortes (abertura)
## As cores vêm do pacote (dados), não da paleta da interface: é a "TV" dentro do jogo.

const IN_COLOR := Color("#3DDC84")
const OUT_COLOR := Color("#FF5A5F")
const YELLOW := Color("#F5D547")
const RED := Color("#E5484D")


# ---------------------------------------------------------------------------
# Peças básicas
# ---------------------------------------------------------------------------

static func panel(bg: Color, radius: int = 0, mx: int = 0, my: int = 0, skew: float = 0.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = mx
	s.content_margin_right = mx
	s.content_margin_top = my
	s.content_margin_bottom = my
	s.skew = Vector2(skew, 0)
	s.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func style(p: PanelContainer) -> StyleBoxFlat:
	return p.get_theme_stylebox(&"panel") as StyleBoxFlat


static func lbl(text: String, variation: String, col: Color, size: int = 0) -> Label:
	var l := UIKit.label(text, variation)
	l.add_theme_color_override(&"font_color", col)
	if size > 0:
		l.add_theme_font_size_override(&"font_size", size)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Margem que ocupa a sobra da linha (o MarginContainer do kit não se expande sozinho).
static func _mx(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := UIKit.margin(child, l, t, r, b)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


static func _fit(l: Label) -> Label:
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Sobrenome da TV (em caixa alta) e o primeiro nome que vai em cima, menor ("" se não couber).
static func names(p: Player) -> Array:
	var shown := p.display_name()
	if p.first_name != "" and p.last_name != "" and (shown == p.last_name or shown == "%s %s" % [p.first_name, p.last_name]):
		return [p.first_name, p.last_name.to_upper()]
	return ["", shown.to_upper()]


## Cor de time que aparece sobre o fundo escuro do pacote (preto e azul-marinho clareiam).
static func team_tone(c: Color, bg: Color) -> Color:
	if UIColors.contrast(c, bg) < 1.8:
		return c.lightened(0.45) if bg.get_luminance() < 0.5 else c.darkened(0.45)
	return c


static func cutout(p: Player, club: Club, year: int, px: Vector2, bust: bool = false) -> PhotoPortrait:
	var ph := PhotoPortrait.new()
	ph.custom_minimum_size = px
	ph.transparent = true
	ph.bust = bust
	ph.mood = PhotoPortrait.STUDIO
	ph.set_player(p, club, year)
	return ph


## Logo da competição num ladrilho (o "selo" do canto das peças).
static func logo_tile(pk: Dictionary, comp: String, px: int) -> Control:
	var bgc: Color = pk.get("logo_bg", Color(0, 0, 0, 0))
	var t := panel(bgc, mini(int(pk["radius"]), 8), 6, 4)
	t.size_flags_vertical = Control.SIZE_FILL
	var l := UIKit.comp_logo(comp, px)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.add_child(l)
	return t


## Faixa fina com a cor de destaque do pacote (base das legendas).
static func strip(pk: Dictionary, text: String, left_pad: int = 16) -> PanelContainer:
	var acc: Color = pk["accent"]
	var s := panel(acc, 0, 0, 3)
	style(s).content_margin_left = left_pad
	style(s).content_margin_right = 14
	var l := _fit(lbl(text, "Caps", UIColors.on_color(acc), 18))
	s.add_child(l)
	return s


# ---------------------------------------------------------------------------
# Gol
# ---------------------------------------------------------------------------

## Faixa do gol: a cor do clube nasce na sigla e some no fundo do pacote; escudo grande em marca
## d'água na ponta, a palavra do gol na língua da transmissão e o minuto na aba do tempo.
static func goal_banner(pk: Dictionary, club: Club, minute: String) -> PanelContainer:
	var p := panel(pk["bg"], int(pk["radius"]), 0, 0)
	var sb := style(p)
	var c2 := club.secondary_color()
	sb.border_color = c2 if UIColors.contrast(c2, ClubGradient.deep(club.primary_color())) > 1.6 else pk["accent"]
	sb.border_width_bottom = 6
	p.custom_minimum_size.y = 136
	ClubGradient.fill(p, club, ClubGradient.LEFT, pk["bg"], 0.85, 0.95)
	# Marca d'água: o escudo grande saindo pela direita
	var wm := Control.new()
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := UIKit.crest(club, 240)
	big.modulate = Color(1, 1, 1, 0.13)
	big.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	big.offset_left = -170
	big.offset_right = 70
	big.offset_top = -120
	big.offset_bottom = 120
	wm.add_child(big)
	p.add_child(wm)
	var row := UIKit.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tile := panel(Color(0, 0, 0, 0.3), 0, 16, 0)
	tile.custom_minimum_size.x = 112
	var ab := lbl(club.abbr, "Score", Color.WHITE, 46)
	ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.add_child(ab)
	row.add_child(tile)
	var cr := UIKit.crest(club, 84)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(UIKit.margin(cr, 16, 0, 10, 0))
	var word := _fit(lbl(String(pk.get("goal", "GOL")), "Huge", Color.WHITE, 84))
	word.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	word.name = "Word"
	row.add_child(word)
	var mt := panel(pk["time_bg"], mini(int(pk["radius"]), 6), 14, 6)
	mt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mt.add_child(lbl(minute, "H3", pk["time_ink"], 30))
	row.add_child(UIKit.margin(mt, 6, 0, 18, 0))
	p.add_child(row)
	return p


## Tarja do goleador: recorte saindo da peça à esquerda, bandeira e número, nome e sobrenome e a
## legenda do gol na cor do pacote.
static func scorer_card(pk: Dictionary, w: GameWorld, p: Player, club: Club, caption: String, facts: String) -> Control:
	return _person_card(pk, w, p, club, caption, facts, 150, Vector2(172, 206), null)


## Melhor em campo: a mesma peça, maior, com a nota.
static func potm_card(pk: Dictionary, w: GameWorld, p: Player, club: Club, rating: float, facts: String) -> Control:
	var r := panel(pk["bg"], mini(int(pk["radius"]), 6), 14, 4)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rl := lbl(Fmt.rating(rating), "Big", Fmt.match_rating_color(rating), 54)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.add_child(rl)
	return _person_card(pk, w, p, club, "Melhor em campo", facts, 176, Vector2(196, 236), r)


static func _person_card(pk: Dictionary, w: GameWorld, p: Player, club: Club, caption: String, facts: String, body_h: int, photo: Vector2, right: Control) -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.custom_minimum_size = Vector2(0, photo.y + 4)
	var pc := TvPackage.panel_colors(pk)
	var body := panel(pc[0], int(pk["radius"]), 0, 0)
	body.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	body.offset_top = -body_h
	body.offset_bottom = 0
	ClubGradient.fill(body, club, ClubGradient.LEFT, pc[0], 0.42, 0.95)
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := UIKit.hbox(12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nm := UIKit.vbox(0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nr := names(p)
	var head := UIKit.hbox(10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fl := UIKit.flag(p.nationality, 36)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(fl)
	if p.shirt > 0:
		head.add_child(lbl(str(p.shirt), "Section", pk["accent"] if not bool(pk.get("light", false)) else pk["paper_ink"], 32))
	if String(nr[0]) != "":
		head.add_child(_fit(lbl(String(nr[0]), "H3", Color(pc[1], 0.85), 24)))
	nm.add_child(head)
	var ln := String(nr[1]).length()
	var last := _fit(lbl(String(nr[1]), "Title", pc[1], 46 if ln <= 9 else (40 if ln <= 12 else 34)))
	nm.add_child(last)
	nm.add_child(_fit(lbl(facts if facts != "" else club.short_name, "Small", Color(pc[1], 0.8), 21)))
	top.add_child(nm)
	if right != null:
		top.add_child(right)
	v.add_child(UIKit.margin(top, int(photo.x) + 12, 8, 16, 6))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sp)
	v.add_child(strip(pk, caption, int(photo.x) + 12))
	body.add_child(v)
	root.add_child(body)
	var ph := cutout(p, club, w.year, photo)
	ph.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ph.offset_left = 4
	ph.offset_right = 4 + photo.x
	ph.offset_top = -photo.y
	ph.offset_bottom = 0
	root.add_child(ph)
	return root


# ---------------------------------------------------------------------------
# Números e tabela
# ---------------------------------------------------------------------------

## Números lado a lado. rows: [[nome, valor casa, valor fora, fração da casa 0..1]].
## colors: [cor casa, cor fora].
static func stat_card(pk: Dictionary, home: Club, away: Club, title: String, rows: Array, colors: Array) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 18, 14)
	var v := UIKit.vbox(10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hdr := UIKit.hbox(8)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(UIKit.crest(home, 40))
	hdr.add_child(lbl(home.abbr, "H3", pc[1], 26))
	var t := _fit(lbl(title, "Caps", pk["accent"] if not bool(pk.get("light", false)) else pk["paper_ink"], 18))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.add_child(t)
	hdr.add_child(lbl(away.abbr, "H3", pc[1], 26))
	hdr.add_child(UIKit.crest(away, 40))
	v.add_child(hdr)
	var ch: Color = team_tone(colors[0], pc[0])
	var ca: Color = team_tone(colors[1], pc[0])
	for r in rows:
		var box := UIKit.vbox(3)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var line := UIKit.hbox(8)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var hv := lbl(String(r[1]), "H3", pc[1], 28)
		hv.custom_minimum_size.x = 84
		line.add_child(hv)
		var nl := _fit(lbl(String(r[0]), "Small", Color(pc[1], 0.8), 21))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(nl)
		var av := lbl(String(r[2]), "H3", pc[1], 28)
		av.custom_minimum_size.x = 84
		av.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		line.add_child(av)
		box.add_child(line)
		var bar := SplitBar.new()
		bar.share = float(r[3])
		bar.c_home = ch
		bar.c_away = ca
		bar.track = Color(pc[1], 0.12)
		bar.custom_minimum_size = Vector2(0, 8)
		box.add_child(bar)
		v.add_child(box)
	p.add_child(v)
	return p


## Fração da casa para a barra dividida (0,5 quando os dois têm zero).
static func share(h: float, a: float) -> float:
	return 0.5 if h + a <= 0.0 else h / (h + a)


## Tabela ao vivo. rows: [{pos, before, cid, pl, gd, pts, live, gap}] (gap = linha de "…" antes).
static func table_card(pk: Dictionary, w: GameWorld, comp: String, title: String, rows: Array) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 0, 0)
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head := panel(pk["bg"], 0, 14, 8)
	var hr := UIKit.hbox(10)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hr.add_child(UIKit.comp_logo(comp, 34))
	hr.add_child(_fit(lbl(title, "H3", pk["ink"], 24)))
	var live := panel(pk["accent"], 3, 8, 1)
	live.add_child(lbl("AO VIVO", "Caps", UIColors.on_color(pk["accent"]), 18))
	live.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(live)
	head.add_child(hr)
	v.add_child(head)
	var body := UIKit.vbox(2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cols := UIKit.hbox(6)
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spc := Control.new()
	spc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cols.add_child(spc)
	for k in ["J", "SG", "Pts"]:
		var cl := lbl(k, "Caps", Color(pc[1], 0.6), 18)
		cl.custom_minimum_size.x = 52
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cols.add_child(cl)
	body.add_child(cols)
	for r: Dictionary in rows:
		if bool(r.get("gap", false)):
			var g := lbl("…", "Small", Color(pc[1], 0.5), 21)
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			body.add_child(g)
		body.add_child(_table_row(pk, pc, w, r))
	v.add_child(UIKit.margin(body, 12, 6, 14, 10))
	p.add_child(v)
	return p


static func _table_row(pk: Dictionary, pc: Array, w: GameWorld, r: Dictionary) -> Control:
	var club := w.club(int(r["cid"]))
	var on := bool(r.get("live", false))
	var acc: Color = pk["accent"]
	var row_bg := panel(Color(acc, 0.18) if on else Color(0, 0, 0, 0), 2, 6, 3)
	if on:
		style(row_bg).border_color = acc
		style(row_bg).border_width_left = 4
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pos := int(r["pos"])
	var before := int(r.get("before", pos))
	var pl := lbl(str(pos), "H3", pc[1], 24)
	pl.custom_minimum_size.x = 34
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	var mv := ""
	var mv_col := Color(pc[1], 0.4)
	if before > 0 and pos < before:
		mv = "▲"
		mv_col = IN_COLOR if not bool(pk.get("light", false)) else Color("#1F8A4C")
	elif before > 0 and pos > before:
		mv = "▼"
		mv_col = OUT_COLOR if not bool(pk.get("light", false)) else Color("#C0392B")
	var ml := lbl(mv, "Small", mv_col, 18)
	ml.custom_minimum_size.x = 20
	h.add_child(ml)
	h.add_child(UIKit.crest(club, 28))
	h.add_child(_fit(lbl(club.short_name if club != null else "?", "H3" if on else "", pc[1], 23)))
	var vals: Array = [str(r["pl"]), Fmt.signed(int(r["gd"])), str(r["pts"])]
	for i in vals.size():
		var l := lbl(String(vals[i]), "H3" if i == 2 else "", pc[1], 24 if i == 2 else 22)
		l.custom_minimum_size.x = 52
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	row_bg.add_child(h)
	return row_bg


# ---------------------------------------------------------------------------
# Substituição, cartão, informação
# ---------------------------------------------------------------------------

static func _club_tile(pk: Dictionary, club: Club, h: int) -> PanelContainer:
	var t := panel(ClubGradient.deep(club.primary_color()), 0, 12, 0)
	t.custom_minimum_size = Vector2(0, h)
	var v := UIKit.vbox(2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cr := UIKit.crest(club, 44)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var ab := lbl(club.abbr, "H3", Color.WHITE, 22)
	ab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ab)
	t.add_child(v)
	return t


static func _minute_tile(pk: Dictionary, minute: String) -> PanelContainer:
	var m := panel(pk["time_bg"], 0, 14, 0)
	var l := lbl(minute, "H3", pk["time_ink"], 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.add_child(l)
	return m


static func sub_card(pk: Dictionary, club: Club, p_in: Player, p_out: Player, minute: String) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 0, 0)
	var row := UIKit.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_club_tile(pk, club, 112))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lbl("Substituição", "Caps", Color(pc[1], 0.7), 18))
	for pair in [[p_in, "▲", IN_COLOR, true], [p_out, "▼", OUT_COLOR, false]]:
		var pl: Player = pair[0]
		if pl == null:
			continue
		var r := UIKit.hbox(10)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var arrow_col: Color = pair[2]
		if bool(pk.get("light", false)):
			arrow_col = arrow_col.darkened(0.3)
		r.add_child(lbl(String(pair[1]), "H3", arrow_col, 22))
		var num := lbl(str(pl.shirt) if pl.shirt > 0 else "", "H3", Color(pc[1], 0.7), 24)
		num.custom_minimum_size.x = 34
		r.add_child(num)
		r.add_child(_fit(lbl(pl.display_name().to_upper(), "H3" if bool(pair[3]) else "", Color(pc[1], 1.0 if bool(pair[3]) else 0.75), 26 if bool(pair[3]) else 23)))
		v.add_child(r)
	row.add_child(_mx(v, 16, 8, 12, 8))
	row.add_child(_minute_tile(pk, minute))
	p.add_child(row)
	return p


static func booking_card(pk: Dictionary, club: Club, pl: Player, red: bool, minute: String, second: bool) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 0, 0)
	var row := UIKit.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_club_tile(pk, club, 104))
	var card := CardGlyph.new()
	card.color = RED if red else YELLOW
	card.second = second
	card.custom_minimum_size = Vector2(54, 0)
	row.add_child(UIKit.margin(card, 14, 0, 0, 0))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var what := "Expulso" if red else "Cartão amarelo"
	if red and second:
		what = "Expulso · segundo amarelo"
	v.add_child(lbl(what, "Caps", Color(pc[1], 0.75), 18))
	var nr := UIKit.hbox(10)
	nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pl.shirt > 0:
		nr.add_child(lbl(str(pl.shirt), "H3", Color(pc[1], 0.7), 26))
	nr.add_child(_fit(lbl(pl.display_name().to_upper(), "Section", pc[1], 30)))
	v.add_child(nr)
	row.add_child(_mx(v, 12, 6, 12, 6))
	row.add_child(_minute_tile(pk, minute))
	p.add_child(row)
	return p


## Estádio, público, árbitro, clima: blocos de rótulo e valor ([[rótulo, valor]]).
static func info_card(pk: Dictionary, comp: String, rows: Array) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 0, 0)
	var row := UIKit.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(logo_tile(pk, comp, 52))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for r in rows:
		var b := UIKit.vbox(0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lbl(String(r[0]), "Caps", pk["accent"] if not bool(pk.get("light", false)) else Color(pc[1], 0.65), 18))
		b.add_child(_fit(lbl(String(r[1]), "H3", pc[1], 23)))
		grid.add_child(b)
	row.add_child(_mx(grid, 16, 10, 14, 10))
	p.add_child(row)
	return p


# ---------------------------------------------------------------------------
# Escalação por setor (abertura)
# ---------------------------------------------------------------------------

## Um setor do time titular: recortes lado a lado no degradê do clube, número grande, bandeira e
## sobrenome embaixo (como as artes de escalação das transmissões).
static func sector_card(pk: Dictionary, w: GameWorld, club: Club, title: String, players: Array) -> PanelContainer:
	var p := panel(pk["bg"], int(pk["radius"]), 12, 10)
	var v := UIKit.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hdr := UIKit.hbox(10)
	hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr.add_child(_fit(lbl(title, "Section", pk["ink"], 28)))
	hdr.add_child(UIKit.crest(club, 34))
	v.add_child(hdr)
	var n := players.size()
	var grid := GridContainer.new()
	grid.columns = n if n <= 5 else int(ceil(n / 2.0))
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pl: Player in players:
		grid.add_child(_sector_tile(pk, w, club, pl))
	v.add_child(grid)
	p.add_child(v)
	return p


static func _sector_tile(pk: Dictionary, w: GameWorld, club: Club, pl: Player) -> Control:
	var t := Control.new()
	t.custom_minimum_size = Vector2(96, 176)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ClubGradient.fill(t, club, ClubGradient.TOP, pk["bg2"], 0.95, 0.85)
	if pl.shirt > 0:
		var num := lbl(str(pl.shirt), "Score", Color(1, 1, 1, 0.9), 44)
		num.position = Vector2(8, 0)
		t.add_child(num)
	var ph := cutout(pl, club, w.year, Vector2(80, 120), true)
	ph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ph.offset_top = 24
	ph.offset_bottom = -38
	t.add_child(ph)
	var fl := UIKit.flag(pl.nationality, 26)
	fl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fl.offset_left = -32
	fl.offset_right = -6
	fl.offset_top = 10
	fl.offset_bottom = 27
	t.add_child(fl)
	var foot := panel(Color(0, 0, 0, 0.6), 0, 4, 2)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -38
	var nl := _fit(lbl(pl.short_name().to_upper(), "Caps", Color.WHITE, 18))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(nl)
	t.add_child(foot)
	return t


## Os titulares em três setores (goleiro e defesa, meio-campo, ataque).
static func sectors(t: MatchTeam) -> Array:
	var groups := [[], [], []]
	var xi: Array = []
	for mp in t.slots:
		if mp != null:
			xi.append(mp)
	xi.sort_custom(func(a: MatchPlayer, b: MatchPlayer): return Pos.DISPLAY_ORDER.find(a.pos) < Pos.DISPLAY_ORDER.find(b.pos))
	for mp: MatchPlayer in xi:
		var g := Pos.group(mp.pos)
		var k := 0 if g <= Pos.G_DEF else (1 if g == Pos.G_MID else 2)
		groups[k].append(mp.p)
	var out: Array = []
	var titles := ["Defesa", "Meio-campo", "Ataque"]
	for i in 3:
		if not groups[i].is_empty():
			out.append([titles[i], groups[i]])
	return out


# ---------------------------------------------------------------------------
# Desenhos pequenos
# ---------------------------------------------------------------------------

## Barra dividida: a casa da esquerda até a fração, o visitante no resto, com um respiro no meio.
class SplitBar extends Control:
	var share := 0.5
	var c_home := Color.WHITE
	var c_away := Color.GRAY
	var track := Color(1, 1, 1, 0.1)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), track)
		var cut := clampf(share, 0.0, 1.0) * size.x
		if cut > 2.0:
			draw_rect(Rect2(0, 0, cut - 2.0, h), c_home)
		if size.x - cut > 2.0:
			draw_rect(Rect2(cut + 2.0, 0, size.x - cut - 2.0, h), c_away)


## Cartão do árbitro (levemente inclinado); no segundo amarelo, o amarelo aparece atrás do vermelho.
class CardGlyph extends Control:
	var color := Color.YELLOW
	var second := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := Vector2(30, 42)
		if second:
			draw_set_transform(c + Vector2(-8, 2), -0.28, Vector2.ONE)
			draw_rect(Rect2(-s * 0.5, s), TvGraphics.YELLOW)
		draw_set_transform(c, 0.12, Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, s), color)
		draw_rect(Rect2(-s * 0.5, s), Color(0, 0, 0, 0.35), false, 1.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Gol em outro jogo da rodada: aviso fino no alto (palavra do gol, siglas, placar e autor).
static func other_goal(pk: Dictionary, home: Club, away: Club, hs: int, as_: int, scoring_side: int, scorer: String) -> PanelContainer:
	var pc := TvPackage.panel_colors(pk)
	var p := panel(pc[0], int(pk["radius"]), 0, 0)
	var row := UIKit.hbox(0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := panel(pk["accent"], 0, 12, 0)
	tag.add_child(lbl(String(pk.get("goal", "GOL")), "H3", UIColors.on_color(pk["accent"]), 22))
	row.add_child(tag)
	var mid := UIKit.hbox(8)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(UIKit.crest(home, 30))
	mid.add_child(lbl(home.abbr, "H3" if scoring_side == 0 else "", pc[1], 22))
	mid.add_child(lbl("%d–%d" % [hs, as_], "H3", pc[1], 26))
	mid.add_child(lbl(away.abbr, "H3" if scoring_side == 1 else "", pc[1], 22))
	mid.add_child(UIKit.crest(away, 30))
	mid.add_child(_fit(lbl(scorer, "Small", Color(pc[1], 0.8), 21)))
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_mx(mid, 12, 6, 12, 6))
	p.add_child(row)
	return p
