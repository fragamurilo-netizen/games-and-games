extends BaseScreen
## Academia: identidade e reputação, caixa e lançamentos, staff contratado, opções e sair.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Academia"


func refresh() -> void:
	var w := world()
	var t := w.user_team()
	screen_subtitle = t.name
	UIManager.refresh_chrome()
	var c := reset()
	var id := UIKit.card("CardHighlight", UITokens.S2)
	var h := UIKit.hbox(UITokens.S3)
	var badge := TeamBadge.new()
	badge.team = t
	badge.custom_minimum_size = Vector2(96, 96)
	h.add_child(badge)
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(t.name, "Section", true))
	v.add_child(UIKit.label("%s · %s" % [t.city, DataDB.nation_name(t.nation)], "Small"))
	var st := StarsView.new()
	st.star_size = 20
	st.stars = StarsView.from_value(t.reputation)
	v.add_child(st)
	v.add_child(UIKit.label(_rep_text(t.reputation), "Small", true))
	h.add_child(v)
	id.add_child(h)
	c.add_child(UIKit.card_panel(id))
	# Finanças
	var fin := UIKit.card("Card", UITokens.S1)
	var net := Career.weekly_net(w)
	var sp := Season.sponsor(w)
	var income := Career.tuition(w) + sp
	var costs := Career.upkeep(w) + t.weekly_wages()
	var fh := UIKit.hbox(8)
	var ft := UIKit.label("Finanças", "Section")
	ft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fh.add_child(ft)
	fh.add_child(UIKit.pill(("+" if net > 0.0 else "") + Fmt.money(net) + " por semana", UIColors.GREEN if net >= 0.0 else UIColors.RED))
	fin.add_child(fh)
	var tiles := UIKit.hbox(0)
	for it: Array in [[Fmt.money(t.balance), "Caixa", UIColors.RED if t.balance < 0.0 else Color(0, 0, 0, 0)],
			["+" + Fmt.money(income), "Entra por semana", UIColors.GREEN], [Fmt.money(-costs), "Sai por semana", UIColors.RED]]:
		var tile := UIKit.stat_tile(String(it[0]), String(it[1]), it[2])
		for l in tile.find_children("*", "Label", true, false):
			if (l as Label).theme_type_variation == &"Stat":
				(l as Label).add_theme_font_size_override(&"font_size", UITokens.F_SECTION)
		tiles.add_child(tile)
	fin.add_child(tiles)
	fin.add_child(UIKit.separator())
	fin.add_child(UIKit.kv("Mensalidades (%s)" % Fmt.plural(Career.students(w), "aluno", "alunos"), "+" + Fmt.money(Career.tuition(w)), UIColors.GREEN))
	if sp > 0.0:
		fin.add_child(UIKit.kv("Patrocínio do comércio local", "+" + Fmt.money(sp), UIColors.GREEN))
	fin.add_child(UIKit.kv("Aluguel e despesas", Fmt.money(-Career.upkeep(w))))
	fin.add_child(UIKit.kv("Salários do staff", Fmt.money(-t.weekly_wages())))
	var want := Career.student_demand(w)
	var room := Career.student_capacity(w)
	if want > room:
		fin.add_child(UIKit.colored("%d querem treinar aqui, a casa atende %d. Falta staff." % [want, room], UIColors.ORANGE, "Small", true))
	elif room - want >= 40 and net < 0.0 and not t.staff.is_empty():
		fin.add_child(UIKit.colored("A casa atende %d, só %d querem treinar aqui. Sobra staff." % [room, want], UIColors.ORANGE, "Small", true))
	if t.balance < 0.0:
		var lim := Career.debt_limit(w)
		fin.add_child(UIKit.colored("Caixa negativo paga juros toda semana. Passando de %s de dívida, os salários atrasam e o staff começa a sair." % Fmt.money(lim), UIColors.RED if -t.balance >= lim * 0.6 else UIColors.ORANGE, "Small", true))
	var recent := t.ledger.slice(maxi(0, t.ledger.size() - 5))
	recent.reverse()
	if not recent.is_empty():
		fin.add_child(UIKit.label("Últimos lançamentos", "Caps"))
		for e: Dictionary in recent:
			var val := float(e["value"])
			fin.add_child(UIKit.kv(String(e["label"]), ("+" if val > 0 else "") + Fmt.money(val), UIColors.GREEN if val > 0 else UIColors.MUTED))
	c.add_child(UIKit.card_panel(fin))
	# Staff
	var sc := UIKit.card("Card", UITokens.S1)
	sc.add_child(UIKit.label("Staff", "Section"))
	if t.staff.is_empty():
		sc.add_child(UIKit.label("Ninguém contratado. Sem técnicos, seus lutadores evoluem bem devagar.", "Muted", true))
		sc.add_child(UIKit.button("Ver candidatos", "GhostButton", func(): UIManager.switch_area("market")))
	for s: Dictionary in t.staff:
		var sid := int(s["id"])
		var row := StaffRow.make(w, s, func():
			UIManager.confirm("Dispensar %s?" % String(s["name"]), "Custa duas semanas de salário.", "Dispensar", func():
				StaffMarket.fire(w, sid)
				GameManager.save_now()
				UIManager.refresh_chrome()
				refresh()))
		sc.add_child(row)
		sc.add_child(UIKit.label(StaffMarket.role_name(String(s["role"])), "Caps"))
	c.add_child(UIKit.card_panel(sc))
	var menu := UIKit.menu_group([
		UIKit.menu_row("gear", "Opções", "", func(): UIManager.push("settings")),
		UIKit.menu_row("save", "Salvar e sair", "", func():
			GameManager.close_career()
			UIManager.goto("menu")),
	])
	c.add_child(menu)
	columnize(c, 1, 2, 1)
	TutorialKit.tip(self, "gym")


func _rep_text(r: float) -> String:
	if r < 20:
		return "Academia desconhecida. Só amadores e gente sem opção atendem o telefone."
	if r < 40:
		return "Começando a ser notada no circuito regional."
	if r < 60:
		return "Respeitada: profissionais aceitam conversar."
	if r < 80:
		return "Uma das grandes. Bons lutadores querem treinar aqui."
	return "Referência mundial."
