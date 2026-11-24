class_name FightKit
extends RefCounted
## Peças de interface próprias do jogo de luta: retrato do lutador, linha de lista, barras de
## atributo, cartel, ficha comparativa (tale of the tape) e textos de resultado.


## Retrato quadrado (DESIGN.md › Retrato). Até 64 px: quadro liso de `surface-raised`; acima,
## o fundo de arena do próprio retrato (luz de octógono).
static func portrait(w: GameWorld, f: Fighter, px: int) -> PortraitView:
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := w.team(f.team_id) if w != null else null
	if t != null:
		v.gear_trim = t.color1
	v.stage = px > 64
	v.set_face(f.face_seed, f.eth, w.age_of(f) if w != null else 28, f.look)
	if px <= 64:
		var r := ColorRect.new()
		r.color = UIColors.SURFACE_2
		r.show_behind_parent = true
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.add_child(r)
	return v


static func staff_portrait(s: Dictionary, px: int, accent: Color) -> PortraitView:
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.fight_body = false
	v.stage = false
	var look := {"fem": 1} if bool(s.get("fem", false)) else {}
	v.set_person(int(s.get("face", 1)), int(s.get("eth", 1)), int(s.get("age", 40)), accent, look)
	var r := ColorRect.new()
	r.color = UIColors.SURFACE_2
	r.show_behind_parent = true
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_child(r)
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
	if w.week - f.last_fight_week < Matchmaker.rest_weeks(f):
		return ["Descansando · condição %d%%" % int(f.condition), UIColors.MUTED]
	return ["Disponível · condição %d%%" % int(f.condition), UIColors.GREEN]


## Linha de lista: retrato, nome e segunda linha; à direita o ranking e o nível.
## `right_node` troca o ranking por outra coisa (as estrelas do olheiro, no mercado).
static func fighter_row(w: GameWorld, f: Fighter, cb: Callable, line2: String = "", line2_color: Color = Color(0, 0, 0, 0), right: String = "", right_node: Control = null) -> PanelContainer:
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(portrait(w, f, 56))
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var top := UIKit.hbox(8)
	top.add_child(UIKit.flag(f.nation, 30))
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
	h.add_child(tv)
	var rv := UIKit.vbox(0)
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
	var lv := level_label(f.level())
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rv.add_child(lv)
	h.add_child(rv)
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
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


## Faixa dos corners: retratos frente a frente, vermelho à esquerda e azul à direita.
## `corners` falso: antes de a luta ser marcada ainda não há corner (barra neutra).
static func faceoff(w: GameWorld, fa: Fighter, fb: Fighter, px: int = 150, corners: bool = true) -> HBoxContainer:
	var h := UIKit.hbox(UITokens.S2)
	for i in 2:
		var f := fa if i == 0 else fb
		var v := UIKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var p := portrait(w, f, px)
		v.add_child(p)
		var bar := ColorRect.new()
		bar.color = (UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE) if corners else UIColors.LINE
		bar.custom_minimum_size = Vector2(px, 4)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(bar)
		var n := UIKit.label(f.display_name(), "H3")
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(n)
		if f.nickname != "":
			var nk := UIKit.label("“%s”" % f.nickname, "Small")
			nk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(nk)
		var fl := UIKit.hbox(6)
		fl.alignment = BoxContainer.ALIGNMENT_CENTER
		fl.add_child(UIKit.flag(f.nation, 30))
		fl.add_child(UIKit.label(f.record_text() if f.is_pro() else "Estreia", "Small"))
		v.add_child(fl)
		h.add_child(v)
		if i == 0:
			var vs := UIKit.label("×", "Title")
			vs.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			vs.custom_minimum_size.y = px
			vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			vs.add_theme_color_override(&"font_color", UIColors.DIM)
			h.add_child(vs)
	return h
