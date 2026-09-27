extends BaseScreen
## Vestiário: clima, hierarquia (capitão, líderes, influentes, isolados), panelinhas com o humor e
## a confiança de cada uma, e a reunião com o elenco.

const TIER_COL := {"capitão": Color("#E8C547"), "líder": Color("#3DBE5A"), "influente": Color("#5AA9E6"), "grupo": Color("#9AA0A6"), "isolado": Color("#E5484D")}


func _init() -> void:
	show_nav = false
	screen_title = "Vestiário"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = w.user_club().short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_atmosphere_card(w))
	c.add_child(_meeting_card(w))
	c.add_child(_hierarchy_card(w))
	for cl: Dictionary in DressingRoom.cliques(w):
		c.add_child(_clique_card(w, cl))


func _atmosphere_card(w: GameWorld) -> Control:
	var at := DressingRoom.atmosphere(w)
	var v: float = at[0]
	var card := UIKit.card("CardHighlight", 8)
	card.add_child(UIKit.section("Clima do vestiário"))
	var col := Fmt.rating_color(int(v))
	var row := UIKit.hbox(10)
	var big := UIKit.colored("%d" % int(v), col, "Score")
	row.add_child(big)
	var lab := "Ótimo" if v >= 75.0 else ("Bom" if v >= 60.0 else ("Instável" if v >= 45.0 else "Pesado"))
	var l := UIKit.label(lab, "H2")
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l)
	card.add_child(row)
	card.add_child(UIKit.bar(v, 100.0, col, 10))
	if String(at[1]) != "":
		card.add_child(UIKit.label(String(at[1]), "Small", true))
	return UIKit.card_panel(card)


func _meeting_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Reunião com o elenco"))
	var wait := DressingRoom.wait_turns(w)
	if wait > 0:
		card.add_child(UIKit.label("Nova reunião em %d rodada(s): reunião demais perde o efeito." % wait, "Small", true))
		return UIKit.card_panel(card)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for m in [["cobrar", "Cobrar o grupo", "card"], ["motivar", "Motivar", "star"], ["uniao", "Pedir união", "heart"], ["lideres", "Falar com os líderes", "shield"]]:
		var kind: String = m[0]
		var b := UIKit.button(m[1], "GhostButton", func(): _meet(kind), m[2])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	card.add_child(grid)
	card.add_child(UIKit.label("Cobrança funciona com os líderes do seu lado e o time devendo; em boa fase soa injusta.", "Small", true))
	return UIKit.card_panel(card)


func _meet(kind: String) -> void:
	var w := world()
	var r := DressingRoom.meeting(w, kind)
	var root := UIKit.vbox(10)
	root.add_child(UIKit.label(String(r["title"]), "H2", true))
	root.add_child(UIKit.colored(String(r["summary"]), UIColors.GREEN if r["ok"] else UIColors.RED, "", true))
	for ln in r["lines"]:
		var p: Player = ln[0]
		var h := UIKit.hbox(10)
		h.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 56))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(p.display_name(), "H3"))
		v.add_child(UIKit.label("“%s”" % String(ln[1]), "", true))
		h.add_child(v)
		root.add_child(h)
	root.add_child(UIKit.button("Fechar", "PrimaryButton", func():
		UIManager.close_modal()
		refresh()))
	GameManager.save_now()
	UIManager.show_modal(root, true)


func _hierarchy_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Hierarquia"))
	for row: Dictionary in DressingRoom.hierarchy(w):
		var tier := String(row["tier"])
		if tier == "grupo":
			continue
		var p: Player = row["p"]
		var h := UIKit.hbox(10)
		h.add_child(UIKit.pill(tier.to_upper(), TIER_COL[tier], 14))
		var n := UIKit.label(p.display_name(), "H3")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		h.add_child(n)
		h.add_child(UIKit.label(People.trust_label(People.trust_of(w, p)), "Small"))
		var pid := p.id
		card.add_child(UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	return UIKit.card_panel(card)


func _clique_card(w: GameWorld, cl: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	var head := UIKit.hbox(8)
	var t := UIKit.label(String(cl["name"]), "H3")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.label("%d jogadores" % (cl["members"] as Array).size(), "Small"))
	card.add_child(head)
	var lp: Player = cl["leader"]
	if lp != null:
		card.add_child(UIKit.label("Líder: %s" % lp.display_name(), "Small"))
	for m in [["Humor", float(cl["mood"])], ["Confiança em você", float(cl["trust"])]]:
		var r := UIKit.hbox(8)
		var l := UIKit.label(m[0], "Small")
		l.custom_minimum_size.x = 220
		r.add_child(l)
		var b := UIKit.bar(float(m[1]), 100.0, Fmt.rating_color(int(m[1])), 10)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b)
		card.add_child(r)
	var fl := UIKit.flow(6)
	for p: Player in cl["members"]:
		fl.add_child(UIKit.pill(p.short_name(), UIColors.BLUE, 14))
	card.add_child(fl)
	return UIKit.card_panel(card)
