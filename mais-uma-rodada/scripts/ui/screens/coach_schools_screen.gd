extends BaseScreen
## Escolas de técnicos: cada escola com o fundador, de onde veio, o jeito de jogar de hoje (e o da
## fundação, quando mudou), quantos técnicos tem e os títulos grandes. Tocar abre a árvore
## (fundador, discípulos, discípulos dos discípulos) e quem está em atividade. No fim, o que
## aconteceu nas escolas nos últimos anos.

var _focus := 0


func _init() -> void:
	screen_title = "Escolas de técnicos"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_focus = int(p.get("school", 0))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var d := CoachSchools.data(w)
	var list: Array = (d["list"] as Dictionary).values()
	list.sort_custom(func(a: Dictionary, b: Dictionary):
		var fa := 1 if int(a.get("fim", 0)) > 0 else 0
		var fb := 1 if int(b.get("fim", 0)) > 0 else 0
		if fa != fb:
			return fa < fb
		var ta := int(a["t"]) * 3 + CoachSchools.members(w, int(a["id"])).size()
		var tb := int(b["t"]) * 3 + CoachSchools.members(w, int(b["id"])).size()
		return ta > tb)
	screen_subtitle = Fmt.plural(list.size(), "escola", "escolas")
	c.add_child(UIKit.label("Quem trabalhou com um técnico marcante leva o jeito dele adiante. As escolas mudam com quem vence, e escolas novas nascem no seu save.", "Small", true))
	var us := CoachSchools.user_school(w)
	if not us.is_empty():
		c.add_child(_school_card(w, us))
	for s: Dictionary in list:
		if s == us:
			continue
		c.add_child(_school_card(w, s))
	var ev: Array = d.get("ev", [])
	if not ev.is_empty():
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section("Nas escolas"))
		for i in range(ev.size() - 1, maxi(-1, ev.size() - 11), -1):
			card.add_child(UIKit.kv(str(int(ev[i][0])), String(ev[i][1])))
		c.add_child(UIKit.card_panel(card))
	max_content_width = 1400
	columnize(c, 1, 2, 0)
	if _focus > 0:
		var s2 := CoachSchools.school(w, _focus)
		_focus = 0
		if not s2.is_empty():
			_school_sheet.call_deferred(w, s2)


func _school_card(w: GameWorld, s: Dictionary) -> Control:
	var card := UIKit.vbox(4)
	var head := UIKit.hbox(10)
	if String(s.get("nat", "")) != "":
		head.add_child(UIKit.flag(String(s["nat"]), 34))
	var t := UIKit.label(String(s["n"]), "Section", true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	card.add_child(head)
	var origin := "Fundada por %s em %d" % [String(s["fn"]), int(s["y"])]
	if int(s["f"]) == -2:
		origin = "A sua escola, desde %d" % int(s["y"])
	var par := CoachSchools.school(w, int(s.get("par", 0)))
	if not par.is_empty():
		origin += ", vinda da %s" % String(par["n"])
	card.add_child(UIKit.label(origin, "Small", true))
	var pills := UIKit.flow(6)
	for n in CoachSchools.trait_names(s["tr"]):
		pills.add_child(UIKit.pill(String(n), UIColors.ACCENT, 18))
	card.add_child(pills)
	if s["tr0"] != s["tr"]:
		card.add_child(UIKit.label("Na fundação: %s" % ", ".join(PackedStringArray(CoachSchools.trait_names(s["tr0"]))).to_lower(), "Small", true))
	var ms := CoachSchools.members(w, int(s["id"]))
	var line := "%s em atividade" % Fmt.plural(ms.size(), "técnico", "técnicos")
	if int(s["t"]) > 0:
		line += " · %s" % Fmt.plural(int(s["t"]), "título grande", "títulos grandes")
	if int(s.get("fim", 0)) > 0:
		line = "Sem técnicos em atividade desde %d" % int(s["fim"])
	card.add_child(UIKit.label(line, "H3"))
	var ss := s
	return UIKit.tap_row(card, func(): _school_sheet(w, ss), "CardHighlight" if int(s["f"]) == -2 else "Card")


func _school_sheet(w: GameWorld, s: Dictionary) -> void:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label(String(s["n"]), "Title", true))
	v.add_child(UIKit.label(", ".join(PackedStringArray(CoachSchools.trait_names(s["tr"]))), "H3", true))
	v.add_child(UIKit.section("Árvore"))
	var tr := CoachSchools.tree(w, s)
	for row in tr.slice(0, 40):
		var depth := int(row[0])
		var h := UIKit.hbox(6)
		var pad := Control.new()
		pad.custom_minimum_size.x = 24 * depth
		h.add_child(pad)
		if depth > 0:
			h.add_child(UIKit.label("└", "Muted"))
		var nl := UIKit.label(String(row[1]), "H3" if depth == 0 else "", true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		h.add_child(UIKit.label(str(int(row[2])), "Small"))
		v.add_child(h)
	if tr.size() > 40:
		v.add_child(UIKit.label("e mais %d" % (tr.size() - 40), "Muted"))
	var ms := CoachSchools.members(w, int(s["id"]))
	if not ms.is_empty():
		v.add_child(UIKit.section("Em atividade"))
		for co: Dictionary in ms.slice(0, 16):
			var row2 := UIKit.hbox(10)
			var club := w.club(int(co.get("c", -1)))
			if club != null:
				row2.add_child(UIKit.crest(club, 34))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label(String(co["n"]), "H3", true))
			col.add_child(UIKit.label(club.short_name if club != null else "Sem clube", "Small"))
			row2.add_child(col)
			var cid := int(co["id"])
			v.add_child(UIKit.tap_row(row2, func():
				UIManager.close_modal()
				UIManager.push("coach", {"coach": cid}), "CardFlat"))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)
