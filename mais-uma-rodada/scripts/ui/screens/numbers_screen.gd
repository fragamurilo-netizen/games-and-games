extends BaseScreen
## Numeração do elenco. Toque num jogador e depois na camisa: se o número já tem dono, os dois
## trocam. Camisa de peso mexe com o ego — o centroavante que ganha a 9 (ou o craque que ganha
## a 10) fica orgulhoso; o titular que perde a camisa dele pode não gostar.

## Camisas históricas e quem "combina" com elas.
const HEAVY := {
	1: [Pos.GK], 9: [Pos.ST], 10: [Pos.AM, Pos.CM, Pos.ST, Pos.RW, Pos.LW],
	7: [Pos.RW, Pos.LW, Pos.RM, Pos.LM, Pos.ST], 11: [Pos.LW, Pos.RW, Pos.LM, Pos.ST], 5: [Pos.DM, Pos.CB], 4: [Pos.CB], 3: [Pos.CB, Pos.LB], 2: [Pos.RB], 8: [Pos.CM, Pos.DM], 6: [Pos.LB, Pos.DM, Pos.CB],
}

var _sel := -1
var _all := false


func _init() -> void:
	show_nav = false
	screen_title = "Numeração"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var squad := w.squad(club)
	squad.sort_custom(func(a, b): return Pos.DISPLAY_ORDER.find(a.position) < Pos.DISPLAY_ORDER.find(b.position) if a.position != b.position else a.overall > b.overall)
	var owners := {}
	var top := 0
	for p: Player in squad:
		owners[p.shirt] = p
		top = maxi(top, p.shirt)
	c.add_child(_head(w, club))
	# Jogadores
	c.add_child(UIKit.section("Jogadores"))
	var flow := UIKit.flow(8)
	for p: Player in squad:
		var inner := UIKit.hbox(6)
		inner.add_child(UIKit.pos_badge(p.position))
		inner.add_child(UIKit.label(p.short_name(), "H3" if p.id == _sel else ""))
		var num := UIKit.pill(str(p.shirt), UIColors.ACCENT if p.id == _sel else UIColors.BLUE, 16)
		inner.add_child(num)
		var pid := p.id
		var row := UIKit.tap_row(inner, func():
			_sel = pid if _sel != pid else -1
			refresh(), "CardHighlight" if p.id == _sel else "CardFlat")
		flow.add_child(row)
	c.add_child(flow)
	# Camisas
	var last := 99 if _all else maxi(40, top + 5)
	c.add_child(UIKit.section("Camisas 1–%d" % last))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for n in range(1, mini(99, last) + 1):
		grid.add_child(_cell(club, n, owners.get(n, null)))
	c.add_child(grid)
	if not _all and last < 99:
		c.add_child(UIKit.button("Mostrar até a 99", "GhostButton", func():
			_all = true
			refresh(), "plus"))


func _head(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	var p := w.player(_sel) if _sel >= 0 else null
	if p == null or p.club_id != club.id:
		_sel = -1
		card.add_child(UIKit.label("Toque num jogador e depois na camisa nova.", "H3", true))
		card.add_child(UIKit.label("Se o número tiver dono, os dois trocam.", "Muted", true))
		return UIKit.card_panel(card)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.portrait(p, club, w.year, 72))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.display_name(), "Title", true))
	col.add_child(UIKit.label("%s · hoje com a %d" % [Pos.name_of(p.position), p.shirt], "Small", true))
	col.add_child(UIKit.colored("Escolha a camisa nova abaixo.", UIColors.ACCENT, "Small", true))
	row.add_child(col)
	row.add_child(UIKit.button("Cancelar", "GhostButton", func():
		_sel = -1
		refresh()))
	card.add_child(row)
	return UIKit.card_panel(card)


## Camisa: a miniatura no uniforme do clube, com o número e o dono embaixo.
func _cell(club: Club, n: int, owner: Player) -> Control:
	var col := UIKit.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var kit := KitView.new()
	kit.kit = club.kit_for(owner) if owner != null else club.kit_home
	kit.number = n
	kit.crest = club.crest
	kit.custom_minimum_size = Vector2(96, 78)
	kit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owner == null:
		kit.modulate = Color(1, 1, 1, 0.38)
	col.add_child(kit)
	var who := UIKit.label(owner.short_name() if owner != null else "livre", "Small")
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size.x = 96
	if owner != null and owner.id == _sel:
		who.add_theme_color_override(&"font_color", UIColors.ACCENT)
	elif owner == null:
		who.add_theme_color_override(&"font_color", UIColors.MUTED)
	col.add_child(who)
	var variation := "CardHighlight" if owner != null and owner.id == _sel else "CardFlat"
	return UIKit.tap_row(col, func(): _tap_number(n), variation)


func _tap_number(n: int) -> void:
	var w := world()
	var club := w.user_club()
	var owner: Player = null
	for q: Player in w.squad(club):
		if q.shirt == n:
			owner = q
	if _sel < 0:
		# Sem jogador escolhido: tocar numa camisa ocupada escolhe o dono
		if owner != null:
			_sel = owner.id
			refresh()
		return
	var p := w.player(_sel)
	if p == null or owner == p:
		_sel = -1
		refresh()
		return
	var old := p.shirt
	p.shirt = n
	var msg := "%s agora veste a %d." % [p.display_name(), n]
	if owner != null:
		owner.shirt = old
		msg = "%s fica com a %d e %s com a %d." % [p.short_name(), n, owner.short_name(), old]
	var color := UIColors.GREEN
	# Ego: camisa de peso para quem combina com ela
	if HEAVY.has(n) and (HEAVY[n] as Array).has(p.position) and p.squad_status <= Player.STATUS_STARTER:
		p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
		msg += " Ele gostou da camisa de peso."
	if owner != null and HEAVY.has(n) and (HEAVY[n] as Array).has(owner.position) and owner.squad_status <= Player.STATUS_STARTER:
		var hit := 6.0 if owner.has_trait("estrela") or owner.has_trait("ambicioso") else 3.0
		owner.morale = clampf(owner.morale - hit, 0.0, 100.0)
		msg += " %s não gostou de perder a %d." % [owner.short_name(), n]
		color = UIColors.ORANGE
	_sel = -1
	UIManager.toast(msg, color)
	GameManager.save_now()
	refresh()
