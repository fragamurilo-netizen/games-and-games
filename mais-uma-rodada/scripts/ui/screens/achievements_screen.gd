extends BaseScreen
## Conquistas do treinador: total desbloqueado, pontos por nível, medalhas por categoria com a
## barra de progresso das que têm meta e quando cada uma foi conquistada.

var _cat := "all"


func _init() -> void:
	show_nav = false
	screen_title = "Conquistas"


func on_show() -> void:
	var w := world()
	if w != null:
		Achievements.check_counters(w)
	refresh()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var have := Achievements.unlocked(w)
	var total := Achievements.CATALOG.size()
	var got := 0
	for id in have:
		if Achievements.CATALOG.has(id):
			got += 1
	screen_subtitle = "%d de %d desbloqueadas" % [got, total]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_summary(w, got, total))
	var chips := ScrollContainer.new()
	chips.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chips.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	chips.custom_minimum_size.y = 56
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for f in [["all", "Todas"]] + Achievements.CATEGORIES:
		var key: String = f[0]
		var chip := UIKit.chip(f[1], key == _cat, g, func():
			_cat = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 18)
		row.add_child(chip)
	chips.add_child(row)
	c.add_child(chips)
	var when: Dictionary = w.stats.get("ach_when", {})
	for cat in Achievements.CATEGORIES:
		if _cat != "all" and _cat != cat[0]:
			continue
		var ids: Array = []
		for id in Achievements.CATALOG:
			if String(Achievements.CATALOG[id]["cat"]) == cat[0]:
				ids.append(id)
		# Desbloqueadas primeiro; depois as mais perto de sair.
		ids.sort_custom(func(a, b):
			var ha := have.has(a)
			var hb := have.has(b)
			if ha != hb:
				return ha
			return _ratio(w, a) > _ratio(w, b))
		var n_got := ids.filter(func(i): return have.has(i)).size()
		var head := UIKit.hbox(8)
		var sec := UIKit.section(cat[1])
		sec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(sec)
		head.add_child(UIKit.label("%d/%d" % [n_got, ids.size()], "Caps"))
		c.add_child(head)
		for id in ids:
			c.add_child(_row(w, id, have.has(id), when.get(id, [])))


func _ratio(w: GameWorld, id: String) -> float:
	var a: Dictionary = Achievements.CATALOG[id]
	if not a.has("goal"):
		return 0.0
	return float(Achievements.progress(w, id)) / float(a["goal"])


func _summary(w: GameWorld, got: int, total: int) -> Control:
	var card := UIKit.card("Card", 12)
	var top := UIKit.hbox(16)
	var big := UIKit.vbox(0)
	big.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	big.add_child(UIKit.label("CARREIRA DE %s" % w.manager_name.to_upper(), "Caps"))
	big.add_child(UIKit.label("%d / %d" % [got, total], "Big"))
	big.add_child(UIKit.label("%d de %d pontos" % [Achievements.points(w), Achievements.max_points()], "Small"))
	top.add_child(big)
	var tiers := UIKit.hbox(10)
	for t in ["bronze", "prata", "ouro", "platina"]:
		var n := 0
		var of := 0
		for id in Achievements.CATALOG:
			if String(Achievements.CATALOG[id]["tier"]) == t:
				of += 1
				if Achievements.has(w, id):
					n += 1
		var col := UIKit.vbox(2)
		var dot := ColorRect.new()
		dot.color = Color(String(Achievements.TIERS[t]["color"]))
		dot.custom_minimum_size = Vector2(34, 8)
		col.add_child(dot)
		var l := UIKit.label("%d/%d" % [n, of], "H3")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var tl := UIKit.label(String(Achievements.TIERS[t]["name"]), "Caps")
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(tl)
		tiers.add_child(col)
	top.add_child(tiers)
	card.add_child(top)
	card.add_child(UIKit.bar(got, maxi(1, total), UIColors.ACCENT, 12))
	return UIKit.card_panel(card)


func _row(w: GameWorld, id: String, got: bool, when: Array) -> Control:
	var a: Dictionary = Achievements.CATALOG[id]
	var row := UIKit.hbox(14)
	var medal := AchievementMedal.new()
	medal.custom_minimum_size = Vector2(72, 72)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.setup(id, got)
	row.add_child(medal)
	var v := UIKit.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := UIKit.label(String(a["name"]), "H3", true)
	if not got:
		name.add_theme_color_override(&"font_color", UIColors.MUTED)
	v.add_child(name)
	v.add_child(UIKit.label(String(a["desc"]), "Small", true))
	var tier_name := String(Achievements.TIERS[a["tier"]]["name"]).to_upper()
	if a.has("goal") and not got:
		var goal := int(a["goal"])
		var cur := mini(Achievements.progress(w, id), goal)
		var pr := UIKit.hbox(10)
		var b := UIKit.bar(cur, goal, Achievements.tier_color(id), 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(b)
		pr.add_child(UIKit.label("%d/%d" % [cur, goal], "Caps"))
		v.add_child(pr)
	var meta := tier_name
	if got and when.size() >= 2:
		var d := int(when[1])
		meta += "  ·  " + ("rodada %d de %d" % [d + 1, int(when[0])] if d < 38 else "temporada %d" % int(when[0]))
	elif got:
		meta += "  ·  desbloqueada"
	var ml := UIKit.label(meta, "Caps")
	ml.add_theme_color_override(&"font_color", Achievements.tier_color(id) if got else UIColors.DIM)
	v.add_child(ml)
	row.add_child(v)
	var p := PanelContainer.new()
	p.theme_type_variation = "RowPanel"
	p.add_child(row)
	if not got:
		p.modulate.a = 0.78
	return p
