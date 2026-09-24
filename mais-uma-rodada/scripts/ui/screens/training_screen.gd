extends BaseScreen
## Treino: foco coletivo da semana, intensidade e treino individual de cada jogador.


func _init() -> void:
	show_nav = false
	screen_title = "Treino"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_subtitle = "Entrosamento %d · estrutura %d" % [int(club.cohesion), club.facilities]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_focus_card(club))
	c.add_child(_intensity_card(club))
	c.add_child(_players_card(w, club))


func _focus_card(club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Foco coletivo"))
	var cur := String(club.training.get("focus", "equilibrado"))
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for key in TrainingManager.FOCUS_ORDER:
		var k: String = key
		flow.add_child(UIKit.chip(String(TrainingManager.TEAM_FOCUS[k]["name"]), k == cur, g, func():
			club.training["focus"] = k
			refresh()))
	card.add_child(flow)
	var f := TrainingManager.focus_of(club)
	card.add_child(UIKit.label(String(f["desc"]), "", true))
	var fx: Array = []
	if not Array(f["attrs"]).is_empty():
		var names: Array = []
		for a in f["attrs"]:
			names.append(Attr.NAMES[int(a)])
		fx.append("Prioriza: " + ", ".join(names))
	if float(f["growth"]) != 1.0:
		fx.append("Evolução %+d%%" % int(round((float(f["growth"]) - 1.0) * 100.0)))
	if float(f["recovery"]) != 1.0:
		fx.append("Recuperação %+d%%" % int(round((float(f["recovery"]) - 1.0) * 100.0)))
	if float(f["injury"]) != 1.0:
		fx.append("Risco de lesão %+d%%" % int(round((float(f["injury"]) - 1.0) * 100.0)))
	if float(f["cohesion"]) > 0.0:
		fx.append("Entrosamento sobe mais rápido")
	for line in fx:
		card.add_child(UIKit.colored("• " + line, UIColors.MUTED, "Small", true))
	return UIKit.card_panel(card)


func _intensity_card(club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Intensidade"))
	var cur := int(club.training.get("int", 1))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in TrainingManager.INTENSITY.size():
		var idx := i
		var chip := UIKit.chip(String(TrainingManager.INTENSITY[i]["name"]), i == cur, g, func():
			club.training["int"] = idx
			refresh())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	card.add_child(row)
	var it: Dictionary = TrainingManager.INTENSITY[cur]
	card.add_child(UIKit.label("Evolução %+d%% · recuperação %+d%% · risco de lesão %+d%%" % [
		int(round((float(it["growth"]) - 1.0) * 100.0)), int(round((float(it["recovery"]) - 1.0) * 100.0)), int(round((float(it["injury"]) - 1.0) * 100.0))], "Small", true))
	return UIKit.card_panel(card)


func _players_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Treino individual"))
	card.add_child(UIKit.label("Toque em um jogador para escolher o foco dele ou ensinar uma nova posição.", "Small", true))
	var squad := w.squad(club)
	squad.sort_custom(func(a: Player, b: Player): return a.position < b.position if a.position != b.position else a.overall > b.overall)
	for p: Player in squad:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(p.position))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3"))
		var bits: Array = []
		var fk := String(p.train.get("f", ""))
		bits.append(String(TrainingManager.PLAYER_FOCUS[fk]["name"]) if TrainingManager.PLAYER_FOCUS.has(fk) else "Sem foco")
		var lp := int(p.train.get("pos", -1))
		if lp >= 0:
			bits.append("aprendendo %s (%d%%)" % [Pos.code(lp), int(float(p.train.get("prog", 0.0)) * 100.0)])
		col.add_child(UIKit.colored(" · ".join(bits), UIColors.ACCENT if fk != "" or lp >= 0 else UIColors.MUTED, "Small"))
		row.add_child(col)
		row.add_child(UIKit.label("%d anos" % p.age(w.year), "Small"))
		row.add_child(UIKit.badge(p.overall, 52, 38, 22))
		var pp := p
		card.add_child(UIKit.tap_row(row, func(): TrainingSheet.open(pp, func(): refresh())))
	return UIKit.card_panel(card)
