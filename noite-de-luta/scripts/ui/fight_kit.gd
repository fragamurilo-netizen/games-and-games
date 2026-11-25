class_name FightKit
extends RefCounted
## Peças de interface próprias do jogo de luta: retrato do lutador, linha de lista, barras de
## atributo, cartel, ficha comparativa (tale of the tape) e textos de resultado.


## Retrato do lutador: a imagem guardada pelo PortraitCache num quadro de cantos arredondados.
## `tone` pinta o fundo (corner, equipe, campeão); sem ele, o tom neutro do tema.
static func portrait(w: GameWorld, f: Fighter, px: int, tone: Color = Color(0, 0, 0, 0)) -> Portrait:
	var v := Portrait.new()
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.tone = tone
	v.setup(Portraits.spec_of(w, f), px)
	return v


## O lutador recortado, sem quadro (cartazes, cabeçalho da ficha).
static func cutout(w: GameWorld, f: Fighter, px: int, flip: bool = false) -> Portrait:
	var v := portrait(w, f, px)
	v.cutout = true
	v.flip = flip
	return v


static func staff_portrait(s: Dictionary, px: int, accent: Color) -> Portrait:
	var v := Portrait.new()
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var look := {"fem": 1} if bool(s.get("fem", false)) else {}
	v.setup({"seed": int(s.get("face", 1)), "eth": int(s.get("eth", 1)), "age": int(s.get("age", 40)), "look": look, "suit": true, "accent": accent}, px)
	return v


static func level_color(v: float) -> Color:
	return UIColors.ink(UIColors.attr_color(v))


## Nível em número grande com a cor da escala.
static func level_label(lvl: int, variation: String = "H3") -> Label:
	var l := UIKit.label(str(lvl), variation)
	l.add_theme_color_override(&"font_color", level_color(lvl))
	l.add_theme_font_override(&"font", DataTable.tabular_font())
	l.tooltip_text = "Nível geral"
	return l


## "18-3-0 · 9 KO, 4 FIN, 5 DEC"
static func record_detail(f: Fighter) -> String:
	var r := f.record
	if not f.is_pro():
		return "Amador %d-%d" % [int(f.amateur.get("w", 0)), int(f.amateur.get("l", 0))]
	return "%s · %d KO, %d FIN, %d DEC" % [f.record_text(), int(r["ko_w"]), int(r["sub_w"]), int(r["dec_w"])]


## Situação do lutador para listas da equipe.
static func status_text(w: GameWorld, f: Fighter) -> Array:
	if f.retired:
		return ["Aposentado", UIColors.DIM]
	if not f.injury.is_empty():
		return ["%s · %d sem." % [String(f.injury["name"]), int(f.injury["weeks"])], UIColors.RED]
	if f.suspension > 0:
		return ["Suspensão médica · %d sem." % f.suspension, UIColors.ORANGE]
	var b := w.bout(f.bout_id)
	if b != null:
		var o := w.fighter(b.other(f.id))
		return ["Luta %s contra %s" % [w.weeks_from_now(b.week), o.short_name()], UIColors.TEXT]
	var rest := Matchmaker.rest_weeks(f) - (w.week - f.last_fight_week)
	if rest > 0:
		return ["Descansando · livre em %d sem." % rest, UIColors.MUTED]
	return ["Disponível · condição %d%%" % int(f.condition), UIColors.GREEN]


## Tom do fundo do retrato: a cor da equipe para quem é da casa, dourado para o campeão, neutro
## para o resto do mundo.
static func tone_of(w: GameWorld, f: Fighter) -> Color:
	if w == null or f == null:
		return Color(0, 0, 0, 0)
	if w.is_user_fighter(f):
		return UIColors.TEAM_TONE.darkened(0.25)
	if w.rank_of(f) == 0:
		return UIColors.GOLD.darkened(0.35)
	return Color(0, 0, 0, 0)


## Linha de lista: retrato, nome e segunda linha; à direita o ranking e o nível num quadrinho.
## `right_node` troca o ranking por outra coisa (as estrelas do olheiro, no mercado).
static func fighter_row(w: GameWorld, f: Fighter, cb: Callable, line2: String = "", line2_color: Color = Color(0, 0, 0, 0), right: String = "", right_node: Control = null, tag: String = "", tag_color: Color = Color(0, 0, 0, 0)) -> PanelContainer:
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(portrait(w, f, 72, tone_of(w, f)))
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := UIKit.hbox(8)
	var fl := UIKit.flag(f.nation, 28)
	fl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(fl)
	var n := UIKit.label(f.display_name(), "H3")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	tv.add_child(top)
	var sub := UIKit.label(line2 if line2 != "" else "%s · %s" % [Matchmaker.division_short(f.division), f.record_text()], "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if line2_color.a > 0.0:
		sub.add_theme_color_override(&"font_color", UIColors.ink(line2_color))
	tv.add_child(sub)
	# Etiqueta curta (o humor, por exemplo) embaixo, em cápsula: não disputa espaço com o nome.
	if tag != "":
		tv.add_child(UIKit.pill(tag, tag_color if tag_color.a > 0.0 else UIColors.MUTED, 17))
	h.add_child(tv)
	var rv := UIKit.vbox(4)
	rv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if right_node != null:
		right_node.size_flags_horizontal = Control.SIZE_SHRINK_END
		rv.add_child(right_node)
	else:
		var rk := UIKit.label(right if right != "" else w.rank_text(f), "Caps")
		rk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if w.rank_of(f) == 0:
			rk.add_theme_color_override(&"font_color", UIColors.GOLD)
		rv.add_child(rk)
	var lv := UIKit.badge(str(f.level()), UIColors.attr_color(f.level()))
	lv.tooltip_text = "Nível geral"
	rv.add_child(lv)
	h.add_child(rv)
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = 96
	return row


## Estrelas do potencial como a equipe enxerga (faixa quando há dúvida). Null sem olheiro.
static func potential_stars(w: GameWorld, f: Fighter, px: float = 15.0) -> StarsView:
	var est := Scouting.estimate(w, f)
	if bool(est.get("none", false)):
		return null
	var sv := StarsView.new()
	sv.star_size = px
	sv.stars = StarsView.from_value(float(est["lo"]))
	var up := StarsView.from_value(float(est["hi"]))
	sv.upper_stars = up if up > sv.stars else -1.0
	return sv


## Atributo: nome, número e uma barra fina na cor da escala.
static func attr_row(key: String, value: float, other: float = -1.0) -> VBoxContainer:
	var v := UIKit.vbox(4)
	var h := UIKit.hbox(8)
	var n := UIKit.label(String(Fighter.ATTR_NAMES.get(key, key)), "Small")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.tooltip_text = String(Fighter.ATTR_HELP.get(key, ""))
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(n)
	if other >= 0.0:
		var d := int(round(value - other))
		if d != 0:
			var dl := UIKit.label(Fmt.signed(d), "Caps")
			dl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.GREEN if d > 0 else UIColors.RED))
			h.add_child(dl)
	var val := UIKit.label(str(int(value)), "H3")
	val.add_theme_color_override(&"font_color", level_color(value))
	val.add_theme_font_override(&"font", DataTable.tabular_font())
	val.custom_minimum_size.x = 40
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(val)
	v.add_child(h)
	v.add_child(UIKit.bar(value, 100.0, UIColors.attr_color(value), 6))
	return v


## Os 18 atributos em três blocos (Em pé · Luta agarrada · Físico e mental).
static func attr_blocks(f: Fighter, against: Fighter = null) -> Array:
	var out: Array = []
	for g: Array in Fighter.GROUPS:
		var card := UIKit.card("Card", UITokens.S2)
		var head := UIKit.hbox(8)
		var t := UIKit.label(String(g[0]), "Section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(level_label(int(round(f.avg(g[1])))))
		card.add_child(head)
		for k: String in g[1]:
			card.add_child(attr_row(k, f.a(k), against.a(k) if against != null else -1.0))
		out.append(UIKit.card_panel(card))
	return out


## Nomes curtos para a ficha em duas colunas.
const ATTR_SHORT := {"def_finalizacao": "Def. finalização", "def_queda": "Def. de queda", "defesa": "Defesa em pé"}


## Os 18 atributos num cartão só: cada grupo com a média e os seis atributos em duas colunas.
## Cabe numa dobra da tela (os três blocos empilhados ocupavam duas).
static func attr_card(f: Fighter, against: Fighter = null) -> Control:
	var card := UIKit.card("Card", UITokens.S2)
	var first := true
	for g: Array in Fighter.GROUPS:
		if not first:
			card.add_child(UIKit.separator())
		first = false
		var head := UIKit.hbox(8)
		var t := UIKit.kicker(String(g[0]))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(UIKit.badge(str(int(round(f.avg(g[1])))), UIColors.attr_color(f.avg(g[1])), 22, 48))
		card.add_child(head)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 24)
		grid.add_theme_constant_override(&"v_separation", 10)
		for k: String in g[1]:
			var cell := UIKit.vbox(3)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var h := UIKit.hbox(6)
			var n := UIKit.label(String(ATTR_SHORT.get(k, Fighter.ATTR_NAMES.get(k, k))), "Small")
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			n.tooltip_text = String(Fighter.ATTR_HELP.get(k, ""))
			n.mouse_filter = Control.MOUSE_FILTER_PASS
			h.add_child(n)
			var value := f.a(k)
			if against != null:
				var d := int(round(value - against.a(k)))
				if d != 0:
					var dl := UIKit.label(Fmt.signed(d), "Caps")
					dl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.GREEN if d > 0 else UIColors.RED))
					h.add_child(dl)
			var val := UIKit.label(str(int(value)), "H3")
			val.add_theme_color_override(&"font_color", level_color(value))
			val.add_theme_font_override(&"font", DataTable.tabular_font())
			val.custom_minimum_size.x = 36
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(val)
			cell.add_child(h)
			cell.add_child(UIKit.bar(value, 100.0, UIColors.attr_color(value), 5))
			grid.add_child(cell)
		card.add_child(grid)
	return UIKit.card_panel(card)


## Texto do resultado do ponto de vista do lutador `fid` ("Vitória por nocaute (gancho), R2 3:12").
static func result_text(b: Bout, fid: int = -1) -> String:
	var r := b.result
	if r.is_empty():
		return ""
	var wid := int(r.get("winner_id", -1))
	var how := String(r.get("detail", ""))
	var method := String(r.get("method", ""))
	var when := ""
	if method != "DEC" and method != "EMP":
		when = ", %dº round, %s" % [int(r.get("round", 1)), Fmt.elapsed(float(r.get("time", 0.0)))]
	if wid < 0:
		return "Empate" + (" (%s)" % how if how != "empate" else "")
	if fid < 0:
		return how.substr(0, 1).to_upper() + how.substr(1) + when
	return ("Vitória" if wid == fid else "Derrota") + " por " + how + when


## Cartões dos juízes: "29-28, 29-28, 28-29".
static func cards_text(b: Bout) -> String:
	var cards: Array = b.result.get("cards", [])
	var parts: Array = []
	for c: Array in cards:
		parts.append("%d-%d" % [int(c[0]), int(c[1])])
	return ", ".join(parts)


## Ficha comparativa (tale of the tape): linhas "valor A · rótulo · valor B".
static func tape(w: GameWorld, fa: Fighter, fb: Fighter) -> VBoxContainer:
	var v := UIKit.vbox(0)
	v.add_child(bodies(w, fa, fb, 300))
	var rows := [
		["Cartel", fa.record_text() if fa.is_pro() else "Amador", fb.record_text() if fb.is_pro() else "Amador"],
		["Ranking", w.rank_text(fa), w.rank_text(fb)],
		["Idade", str(w.age_of(fa)), str(w.age_of(fb))],
		["Altura", Fmt.height(fa.height_cm), Fmt.height(fb.height_cm)],
		["Envergadura", "%d cm" % fa.reach_cm, "%d cm" % fb.reach_cm],
		["Base", "Canhota" if fa.southpaw else "Ortodoxa", "Canhota" if fb.southpaw else "Ortodoxa"],
		["Estilo", fa.style_label(), fb.style_label()],
		["Arte de base", Styles.describe(fa), Styles.describe(fb)],
		["Nível", str(fa.level()), str(fb.level())],
	]
	for r: Array in rows:
		var h := UIKit.hbox(8)
		h.custom_minimum_size.y = 46
		var a := UIKit.label(String(r[1]), "H3")
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		a.size_flags_stretch_ratio = 1.2
		a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(a)
		var c := UIKit.label(String(r[0]), "Caps")
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(c)
		var b := UIKit.label(String(r[2]), "H3")
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 1.2
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(b)
		v.add_child(h)
		var line := ColorRect.new()
		line.color = UITokens.HAIRLINE
		line.custom_minimum_size.y = 1
		v.add_child(line)
	return v


## Corpo inteiro do lutador (pesagem): `ref_cm` igual nos dois lados compara a altura de verdade.
static func body(w: GameWorld, f: Fighter, h: int, ref_cm: int = 0) -> BodyView:
	var b := BodyView.new()
	b.live = false
	b.set_fighter(w, f)
	b.ref_cm = ref_cm if ref_cm > 0 else f.height_cm + 4
	b.custom_minimum_size = Vector2(h * 0.48, h)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


## Os dois corpos lado a lado, na mesma escala (quem é mais alto aparece mais alto).
static func bodies(w: GameWorld, fa: Fighter, fb: Fighter, h: int) -> HBoxContainer:
	var row := UIKit.hbox(0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ref := maxi(fa.height_cm, fb.height_cm) + 4
	for f: Fighter in [fa, fb]:
		var b := body(w, f, h, ref)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	return row


## Como o corpo dele aparece em palavras (pela ficha do físico).
static func physique_text(f: Fighter) -> String:
	var lk := f.look
	var parts: Array = []
	var ms := float(lk.get("ms", 0.5))
	var bf := float(lk.get("bf", 0.15))
	var fem := f.is_female()
	if bf >= 0.32:
		parts.append("corpo cheio" if fem else "corpo pesado, de barriga")
	elif bf <= 0.12 and ms >= 0.55:
		parts.append("seca e definida" if fem else "seco e definido")
	elif bf <= 0.12:
		parts.append("magra" if fem else "magro")
	if ms >= 0.8:
		parts.append("muito forte")
	elif ms >= 0.6:
		parts.append("forte")
	elif ms < 0.35:
		parts.append("pouco músculo")
	if float(lk.get("tr", 0.0)) >= 0.6:
		parts.append("pescoço e trapézio de quem vive no clinch")
	var tt := int(lk.get("tt", 0))
	if tt > 0:
		parts.append(["", "uma tatuagem no ombro", "tatuagens no peito e nos ombros", "braço fechado de tatuagem"][mini(tt, 3)])
	if lk.has("er"):
		parts.append("orelha de couve-flor")
	if lk.has("ns"):
		parts.append("nariz quebrado")
	if parts.is_empty():
		return "Físico comum para a categoria."
	var t := ", ".join(parts)
	return t.substr(0, 1).to_upper() + t.substr(1) + "."


## Frente a frente em forma de cartaz: os dois recortados sobre o campo do seu corner (vermelho à
## esquerda, azul à direita, cortados em diagonal), o "VS" no meio e, embaixo, o sobrenome em
## letra de cartaz, o apelido ou o primeiro nome, a bandeira e o cartel. `px` é a altura do palco.
## `corners` falso: antes de a luta ser marcada ainda não há corner (campos neutros).
static func faceoff(w: GameWorld, fa: Fighter, fb: Fighter, px: int = 150, corners: bool = true) -> VBoxContainer:
	var big := px >= 100
	var box := UIKit.vbox(6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, px)
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ca := UIColors.CORNER_RED if corners else UIColors.SURFACE_3
	var cb := UIColors.CORNER_BLUE if corners else UIColors.SURFACE_3
	stage.draw.connect(func(): _poster_fields(stage, ca, cb))
	var side := roundi(px * 1.08)
	var pair: Array = []
	for i in 2:
		var p := cutout(w, fa if i == 0 else fb, side, i == 1)
		p.size = Vector2(side, side)
		stage.add_child(p)
		pair.append(p)
	# Os dois ficam perto do meio mesmo em tela larga (deitado, tablet): frente a frente.
	var place := func():
		var off := minf(stage.size.x * 0.25, px * 1.15)
		for i in 2:
			(pair[i] as Control).position = Vector2(stage.size.x * 0.5 + (-off if i == 0 else off) - side * 0.5, stage.size.y - side + px * 0.04)
	stage.resized.connect(place)
	place.call()
	var vs := UIKit.label("VS", "Section" if not big else "Title")
	vs.add_theme_color_override(&"font_color", UIColors.GOLD)
	vs.add_theme_color_override(&"font_outline_color", UIColors.BG)
	vs.add_theme_constant_override(&"outline_size", 10)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(vs)
	box.add_child(stage)
	var names := UIKit.hbox(UITokens.S2)
	for i in 2:
		var f := fa if i == 0 else fb
		var al := HORIZONTAL_ALIGNMENT_LEFT if i == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if big:
			var first := UIKit.label(f.nickname if f.nickname != "" else f.first, "Caps")
			first.uppercase = true
			first.horizontal_alignment = al
			first.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if f.nickname != "":
				first.add_theme_color_override(&"font_color", UIColors.GOLD)
			v.add_child(first)
		var n := UIKit.label(f.short_name(), "Title" if px >= 126 else "Section")
		n.horizontal_alignment = al
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(n)
		var fl := UIKit.hbox(6)
		fl.alignment = BoxContainer.ALIGNMENT_BEGIN if i == 0 else BoxContainer.ALIGNMENT_END
		var fg := UIKit.flag(f.nation, 28)
		fg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var rec := UIKit.label(f.record_text() if f.is_pro() else "Estreia", "Small")
		if i == 0:
			fl.add_child(fg)
			fl.add_child(rec)
		else:
			fl.add_child(rec)
			fl.add_child(fg)
		v.add_child(fl)
		names.add_child(v)
	box.add_child(names)
	return box


## Fundo do cartaz: o campo de cada corner, cortado em diagonal no meio, escurecendo para baixo.
static func _poster_fields(c: Control, ca: Color, cb: Color) -> void:
	var sz := c.size
	var mid := sz.x * 0.5
	var k := sz.y * 0.16
	var dark := UIColors.BG
	var a_top := ca.lerp(dark, 0.1)
	var a_bot := ca.lerp(dark, 0.72)
	var b_top := cb.lerp(dark, 0.1)
	var b_bot := cb.lerp(dark, 0.72)
	c.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(mid + k, 0), Vector2(mid - k, sz.y), Vector2(0, sz.y)]),
		PackedColorArray([a_top, a_top, a_bot, a_bot]))
	c.draw_polygon(PackedVector2Array([Vector2(mid + k, 0), Vector2(sz.x, 0), Vector2(sz.x, sz.y), Vector2(mid - k, sz.y)]),
		PackedColorArray([b_top, b_top, b_bot, b_bot]))
	c.draw_line(Vector2(mid + k, 0), Vector2(mid - k, sz.y), dark, 5.0, true)
