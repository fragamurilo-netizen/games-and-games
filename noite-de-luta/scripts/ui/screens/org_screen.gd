extends BaseScreen
## Organização (presidente): prestígio, caixa, o que entra e o que sai por noite e por semana,
## as últimas noites e os lançamentos.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Organização"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var t := w.user_team()
	screen_subtitle = t.name
	UIManager.refresh_chrome()
	var c := reset()
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var h := UIKit.hbox(UITokens.S3)
	var badge := TeamBadge.new()
	badge.team = t
	badge.custom_minimum_size = Vector2(88, 88)
	h.add_child(badge)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(t.name, "Section", true))
	v.add_child(UIKit.label("Sigla %s · sede em %s" % [t.short, DataDB.nation_name(t.nation)], "Small"))
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_value(t.reputation)
	v.add_child(st)
	h.add_child(v)
	card.add_child(h)
	card.add_child(UIKit.label("Prestígio %d de 100: atrai público, patrocínio, contrato de TV e compras de pay-per-view. Cresce com noites cheias de estrelas e finalizações; cai com cards vazios, lutas tiradas e noites canceladas." % int(t.reputation), "Small", true))
	c.add_child(UIKit.card_panel(card))
	var fin := UIKit.card("Card", UITokens.S1)
	fin.add_child(UIKit.label("Finanças", "Section"))
	fin.add_child(UIKit.kv("Caixa", Fmt.money(t.balance), UIColors.GREEN if t.balance >= 0.0 else UIColors.RED))
	fin.add_child(UIKit.kv("Folha da organização", Fmt.money(-Org.OVERHEAD) + "/sem.", UIColors.RED))
	fin.add_child(UIKit.kv("Bônus da noite", "4 × " + Fmt.money(Org.BONUS)))
	var past := Org.past_events(w)
	var total := 0.0
	for ev: FightEvent in past.slice(0, 6):
		total += float(ev.report.get("profit", 0.0))
	if not past.is_empty():
		fin.add_child(UIKit.kv("Últimas %d noites" % mini(6, past.size()), Fmt.money(total), UIColors.GREEN if total >= 0.0 else UIColors.RED))
	c.add_child(UIKit.card_panel(fin))
	if not past.is_empty():
		c.add_child(UIKit.section_header("Últimas noites", "Todas", func(): UIManager.switch_area("events")))
		for ev: FightEvent in past.slice(0, 3):
			var id := ev.id
			c.add_child(OrgKit.event_card(w, ev, func(): UIManager.push("org_event", {"id": id})))
	c.add_child(UIKit.section_header("Lançamentos"))
	var shown := 0
	for i in range(t.ledger.size() - 1, -1, -1):
		var l: Dictionary = t.ledger[i]
		var val := float(l["value"])
		c.add_child(UIKit.kv(String(l["label"]), Fmt.money(val), UIColors.GREEN if val >= 0.0 else UIColors.RED))
		shown += 1
		if shown >= 30:
			break
	columnize(c, 0, 2, 1)
