extends BaseScreen
## Pré-temporada: metas e orçamento, raio-x do elenco por setor contra a liga, pendências do
## elenco (contratos, veteranos, sobras, promessas), intertemporada e amistosos.

const LEVELS: Array[String] = ["Mais fraco", "Mesmo nível", "Mais forte"]


func _init() -> void:
	show_nav = false
	screen_title = "Pré-temporada"


func on_show() -> void:
	PreseasonManager.mark_plan_seen(world())
	refresh()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = "%s · temporada %d" % [w.user_club().short_name, w.year]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var pre := PreseasonManager.state(w)
	c.add_child(_intro_card(w, pre))
	c.add_child(_plan_card(w))
	var notes := _notes_card(w)
	if notes != null:
		c.add_child(notes)
	c.add_child(_camp_card(w, pre))
	c.add_child(_friendlies_card(w, pre))
	_footer(w)


func _intro_card(w: GameWorld, pre: Dictionary) -> Control:
	var club := w.user_club()
	var card := UIKit.card("CardHighlight", 12)
	var row := UIKit.hbox(14)
	row.add_child(UIKit.crest(club, 80))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Hora de preparar o %s" % club.short_name, "Title", true))
	col.add_child(UIKit.label("Revise o elenco, escolha a intertemporada e faça os amistosos antes da estreia.", "Muted", true))
	row.add_child(col)
	card.add_child(row)
	var steps := PreseasonManager.steps(w)
	var names := ["Planejar o elenco", "Escolher a intertemporada", "Jogar os amistosos"]
	var flow := UIKit.flow(8)
	for i in 3:
		flow.add_child(UIKit.pill(("✓ " if steps[i] else "") + names[i], UIColors.GREEN if steps[i] else UIColors.MUTED, 16))
	card.add_child(flow)
	card.add_child(UIKit.separator())
	var goal := SeasonManager.goal_of(w, club.id)
	card.add_child(UIKit.kv("Meta da diretoria", String(goal[0]), UIColors.ACCENT))
	card.add_child(UIKit.kv("Verba para contratações", Fmt.money(club.transfer_budget)))
	var bill := FinanceManager.wage_bill(w, club)
	card.add_child(UIKit.kv("Folha salarial / limite", "%s / %s" % [Fmt.money_month(bill), Fmt.money_month(club.wage_budget)], UIColors.RED if bill > club.wage_budget else UIColors.TEXT))
	card.add_child(UIKit.kv("Entrosamento", "%d" % int(club.cohesion), UIColors.morale_color(club.cohesion)))
	return UIKit.card_panel(card)


## Raio-x por setor: titulares contra a média da liga, quantidade e idade.
func _plan_card(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Raio-x do elenco"))
	card.add_child(UIKit.label("Nível dos titulares de cada setor comparado com a média da liga. Toque num setor para buscar reforços.", "Small", true))
	for g in PreseasonManager.squad_plan(w):
		var tone := int(g["tone"])
		var color := UIColors.GREEN if tone > 0 else (UIColors.RED if tone < 0 else UIColors.BLUE)
		var v := UIKit.vbox(4)
		var head := UIKit.hbox(10)
		var name := UIKit.label(Pos.GROUP_NAMES[int(g["group"])], "H3")
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		head.add_child(UIKit.pill(String(g["verdict"]), color, 15))
		v.add_child(head)
		var bars := UIKit.hbox(10)
		var bcol := UIKit.vbox(3)
		bcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bcol.add_child(UIKit.bar(float(g["quality"]), 99.0, color, 12))
		bcol.add_child(UIKit.bar(float(g["league"]), 99.0, UIColors.DIM, 6))
		bars.add_child(bcol)
		var num := UIKit.label("%d" % int(round(float(g["quality"]))), "Stat")
		num.add_theme_color_override(&"font_color", color)
		bars.add_child(num)
		v.add_child(bars)
		var info := "%d jogadores · idade média %.1f · liga %d" % [int(g["count"]), float(g["age"]), int(round(float(g["league"])))]
		if int(g["old"]) > 0:
			info += " · %d com 32+" % int(g["old"])
		v.add_child(UIKit.label(info, "Small", true))
		if String(g["depth"]) != "":
			v.add_child(UIKit.colored(String(g["depth"]), UIColors.ORANGE, "Small"))
		var grp := int(g["group"]) + 1
		var need := tone < 0 or String(g["depth"]).begins_with("Poucas")
		card.add_child(UIKit.tap_row(v, func(): UIManager.push("market", {"group": grp, "upgrades": need}), "CardFlat"))
	return UIKit.card_panel(card)


func _notes_card(w: GameWorld) -> Control:
	var n := PreseasonManager.squad_notes(w)
	var blocks: Array = [
		["expiring", "Contrato termina nesta temporada", "Renove quem é importante antes que o interesse de fora cresça.", UIColors.ORANGE, "clock"],
		["veterans", "Veteranos em queda", "Acima de 32 anos e abaixo dos titulares do setor: bom momento para vender ou dar minutos a outros.", UIColors.MUTED, "down"],
		["surplus", "Sobrando no elenco", "Reservas num setor lotado. Vender ou emprestar libera folha salarial.", UIColors.BLUE, "swap"],
		["prospects", "Promessas para dar minutos", "Jovens com potencial bem acima do nível atual.", UIColors.GREEN, "up"],
	]
	var any := false
	for b in blocks:
		any = any or not (n[b[0]] as Array).is_empty()
	if not any:
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Pendências do elenco"))
	for b in blocks:
		var list: Array = n[b[0]]
		if list.is_empty():
			continue
		var head := UIKit.hbox(10)
		head.add_child(UIKit.icon_rect(String(b[4]), 26, b[3]))
		head.add_child(UIKit.colored(String(b[1]).to_upper() + " (%d)" % list.size(), b[3], "Caps"))
		card.add_child(head)
		card.add_child(UIKit.label(String(b[2]), "Small", true))
		for p: Player in list.slice(0, 4):
			var pid := p.id
			card.add_child(PlayerRowView.make(w, p, {"mode": "squad"}, func(): UIManager.push("player", {"id": pid})))
		if list.size() > 4:
			card.add_child(UIKit.label("e mais %d" % (list.size() - 4), "Small"))
	return UIKit.card_panel(card)


func _camp_card(w: GameWorld, pre: Dictionary) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Intertemporada"))
	var chosen := String(pre.get("camp", ""))
	if chosen != "":
		var cfg: Dictionary = PreseasonManager.CAMPS[chosen]
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(cfg["icon"]), 40, UIColors.ACCENT))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(cfg["name"]), "H2", true))
		for line in pre.get("notes", []):
			col.add_child(UIKit.label("• " + String(line), "", true))
		row.add_child(col)
		card.add_child(row)
		return UIKit.card_panel(card)
	card.add_child(UIKit.label("Escolha como o grupo vai se preparar. Só dá para fazer uma por temporada.", "Small", true))
	for key in PreseasonManager.CAMP_ORDER:
		var cfg: Dictionary = PreseasonManager.CAMPS[key]
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(cfg["icon"]), 36, UIColors.ACCENT))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(cfg["name"]), "H3", true))
		col.add_child(UIKit.label(String(cfg["desc"]), "Small", true))
		col.add_child(UIKit.colored("+ " + String(cfg["pros"]), UIColors.GREEN, "Small", true))
		col.add_child(UIKit.colored("− " + String(cfg["cons"]), UIColors.ORANGE, "Small", true))
		row.add_child(col)
		var k: String = key
		card.add_child(UIKit.tap_row(row, func():
			UIManager.confirm(String(cfg["name"]) + "?", String(cfg["pros"]) + "\n" + String(cfg["cons"]), "Escolher", func():
				var notes := PreseasonManager.choose_camp(world(), k)
				if not notes.is_empty():
					AudioManager.play("whistle")
					UIManager.toast(String(notes[0]), UIColors.GREEN)
				GameManager.save_now()
				refresh()), "CardFlat"))
	return UIKit.card_panel(card)


func _friendlies_card(w: GameWorld, pre: Dictionary) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Amistosos de preparação"))
	var played: Array = pre.get("friendlies", [])
	if not played.is_empty():
		for r in played:
			var opp := w.club(int(r["opp"]))
			var row := UIKit.hbox(10)
			row.add_child(UIKit.text_badge(String(r["r"]), UIColors.result_color(String(r["r"])), 40, 36, 20))
			row.add_child(UIKit.crest(opp, 40))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label(("vs " if bool(r["home"]) else "@ ") + opp.short_name, "H3", true))
			var sc: Array = r.get("scorers", [])
			if not sc.is_empty():
				col.add_child(UIKit.label("Gols: " + ", ".join(PackedStringArray(sc)), "Small", true))
			row.add_child(col)
			row.add_child(UIKit.label("%d x %d" % [int(r["gf"]), int(r["ga"])], "Stat"))
			card.add_child(row)
		var gate := int(pre.get("gate", 0))
		card.add_child(UIKit.label("Ritmo de jogo: entrosamento +%d.%s" % [2 * played.size(), (" Bilheteria: %s." % Fmt.money(gate)) if gate > 0 else ""], "Small", true))
		return UIKit.card_panel(card)
	var opps: Array = pre.get("opponents", [])
	for i in opps.size():
		var opp := w.club(int(opps[i]))
		if opp == null:
			continue
		var row := UIKit.hbox(10)
		row.add_child(UIKit.crest(opp, 44))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(opp.short_name, "H3", true))
		col.add_child(UIKit.label("%s · %s · %s" % [DatabaseManager.nation_name(opp.nation), w.league_short(opp.league_id), "fora" if i == 1 else "em casa"], "Small", true))
		row.add_child(col)
		row.add_child(UIKit.label(LEVELS[mini(i, 2)], "Small"))
		card.add_child(row)
	var b := UIKit.button("JOGAR AMISTOSOS", "PrimaryButton", func():
		var res := PreseasonManager.play_friendlies(world())
		var wins := 0
		for r in res:
			wins += 1 if r["r"] == "V" else 0
		AudioManager.play("win" if wins >= 2 else "whistle")
		GameManager.save_now()
		refresh(), "play")
	card.add_child(b)
	return UIKit.card_panel(card)


func _footer(w: GameWorld) -> void:
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("INICIAR A TEMPORADA", "PrimaryButton", func():
		PreseasonManager.finish(world())
		GameManager.save_now()
		UIManager.goto("hub"), "whistle"))
