extends BaseScreen
## Treino: foco coletivo da semana, intensidade e treino individual de cada jogador.


func _init() -> void:
	show_nav = false
	screen_title = "Treino"


const FOCUS_ICONS := {"equilibrado": "list", "fisico": "bolt", "tecnico": "ball", "tatico": "tactics",
	"ataque": "up", "defesa": "shield", "recuperacao": "heart"}


func refresh() -> void:
	var w := world()
	if w == null:
		return
	max_content_width = 1700
	var club := w.user_club()
	screen_subtitle = "Semana de treino"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var f := TrainingManager.focus_of(club)
	var it: Dictionary = TrainingManager.INTENSITY[int(club.training.get("int", 1))]
	c.add_child(UIKit.stat_grid([
		UIKit.stat_tile(String(f["name"]), "Foco da semana", UIColors.ACCENT),
		UIKit.stat_tile(String(it["name"]), "Intensidade"),
		UIKit.stat_tile(str(int(club.cohesion)), "Entrosamento", UIColors.morale_color(club.cohesion)),
		UIKit.stat_tile(str(club.facilities), "Estrutura"),
	], content_width()))
	var start := c.get_child_count()
	c.add_child(_focus_card(club))
	c.add_child(_intensity_card(club))
	c.add_child(_players_card(w, club))
	columnize(c, start, 2, 0)


func _pct(v: Variant) -> int:
	return int(round((float(v) - 1.0) * 100.0))


func _focus_card(club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section_header("Foco coletivo"))
	var cur := String(club.training.get("focus", "equilibrado"))
	var items: Array = []
	for key in TrainingManager.FOCUS_ORDER:
		var k: String = key
		items.append([k, String(TrainingManager.TEAM_FOCUS[k]["name"]), "", String(FOCUS_ICONS.get(k, "list"))])
	card.add_child(UIKit.option_grid(items, cur, func(k: String):
		club.training["focus"] = k
		refresh(), 2))
	var f := TrainingManager.focus_of(club)
	var detail := UIKit.card("CardInset", 8)
	detail.add_child(UIKit.eyebrow(String(f["name"])))
	detail.add_child(UIKit.label(String(f["desc"]), "", true))
	if not Array(f["attrs"]).is_empty():
		var names: Array = []
		for a in f["attrs"]:
			names.append(Attr.NAMES[int(a)])
		detail.add_child(UIKit.label(tr("Prioriza: %s") % ", ".join(names), "Small", true))
	detail.add_child(UIKit.effect_pills([["Evolução", _pct(f["growth"]), true], ["Recuperação", _pct(f["recovery"]), true], ["Risco de lesão", _pct(f["injury"]), false]]))
	if float(f["cohesion"]) > 0.0:
		detail.add_child(UIKit.pill("Entrosamento sobe mais rápido", UIColors.GREEN, 16))
	card.add_child(UIKit.card_panel(detail))
	return UIKit.card_panel(card)


func _intensity_card(club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section_header("Intensidade"))
	var cur := int(club.training.get("int", 1))
	var items: Array = []
	for i in TrainingManager.INTENSITY.size():
		items.append([str(i), String(TrainingManager.INTENSITY[i]["name"])])
	card.add_child(UIKit.segment(items, str(cur), func(k: String):
		club.training["int"] = int(k)
		refresh()))
	var it: Dictionary = TrainingManager.INTENSITY[cur]
	card.add_child(UIKit.effect_pills([["Evolução", _pct(it["growth"]), true], ["Recuperação", _pct(it["recovery"]), true], ["Risco de lesão", _pct(it["injury"]), false]]))
	return UIKit.card_panel(card)


func _players_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("Treino individual"))
	card.add_child(UIKit.label("Toque num jogador para escolher o foco dele ou ensinar uma posição nova.", "Small", true))
	var squad := w.squad(club)
	squad.sort_custom(func(a: Player, b: Player): return a.position < b.position if a.position != b.position else a.overall > b.overall)
	var last_group := -1
	for p: Player in squad:
		if Pos.group(p.position) != last_group:
			last_group = Pos.group(p.position)
			card.add_child(UIKit.eyebrow(["Goleiros", "Defensores", "Meio-campistas", "Atacantes"][clampi(last_group, 0, 3)], Pos.group_color(p.position)))
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
