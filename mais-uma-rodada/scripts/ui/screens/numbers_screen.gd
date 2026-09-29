extends BaseScreen
## Numeração do elenco. Toque num jogador e depois na camisa: se o número já tem dono, os dois
## trocam mediante confirmação. Alterar números não gera bônus artificial de moral.

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
	max_content_width = 1700
	c.add_child(UIKit.label("Selecione um jogador e escolha uma camisa. Números ocupados exigem confirmação da troca.", "Small", true))
	c.add_child(UIKit.button("Selecionar outro jogador" if _sel >= 0 else "Selecionar jogador", "GhostButton", _pick_player, "users"))

	# Camisas
	var last := 99 if _all else maxi(40, top + 5)
	c.add_child(UIKit.section_header("Camisas 1–%d" % last))
	var grid := GridContainer.new()
	grid.columns = grid_columns(content_width())
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 8)
	for n in range(1, mini(99, last) + 1):
		grid.add_child(_cell(club, n, owners.get(n, null)))
	c.add_child(grid)
	if not _all and last < 99:
		c.add_child(UIKit.button("Mostrar até a 99", "GhostButton", func():
			_all = true
			refresh(), "plus"))


func _pick_player() -> void:
	var w:=world()
	if w==null:return
	var col:=UIKit.vbox(8)
	col.add_child(UIKit.section_header("Escolha quem vai trocar de número"))
	for p:Player in w.squad(w.user_club()):
		var pid:=p.id
		col.add_child(UIKit.button("%02d · %s · %s" % [p.shirt,Pos.code(p.position),p.display_name()],"GhostButton",func():
			UIManager.close_modal()
			if not is_inside_tree() or is_queued_for_deletion():return
			_sel=pid
			refresh()
			scroll_to_top()))
	UIManager.show_modal(col,true)


func _head(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	var p := w.player(_sel) if _sel >= 0 else null
	if p == null or p.club_id != club.id:
		_sel = -1
		card.add_child(UIKit.label("Escolha uma camisa ou selecione um jogador.", "H3", true))
		return UIKit.card_panel(card)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.portrait(p, club, w.year, 72))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.display_name(), "H2", true))
	col.add_child(UIKit.label("%s · hoje com a %d" % [Pos.name_of(p.position), p.shirt], "Small", true))
	row.add_child(col)
	row.add_child(UIKit.button("Cancelar", "GhostButton", func():
		_sel = -1
		refresh()))
	card.add_child(row)
	return UIKit.card_panel(card)


## Camisa vista de costas (como no vestiário): número grande e o nome do dono em cima.
func _cell(club: Club, n: int, owner: Player) -> Control:
	var col := UIKit.vbox(0)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var kit := KitView.new()
	kit.kit = club.kit_for(owner) if owner != null else club.kit_home
	kit.back = true
	kit.back_name = owner.short_name() if owner != null else ""
	kit.number = n
	kit.crest = club.crest
	kit.custom_minimum_size = Vector2(104, 112)
	kit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if owner == null:
		kit.modulate = Color(1, 1, 1, 0.38)
	col.add_child(kit)
	var who := UIKit.label(owner.short_name() if owner != null else "livre", "Small")
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	who.clip_text = true
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.custom_minimum_size.x = 104
	who.tooltip_text = owner.display_name() if owner != null else "Número disponível"
	if owner != null and owner.id == _sel:
		who.add_theme_color_override(&"font_color", UIColors.ACCENT)
	elif owner == null:
		who.add_theme_color_override(&"font_color", UIColors.MUTED)
	col.add_child(who)
	var variation := "CardHighlight" if owner != null and owner.id == _sel else "CardFlat"
	var tile := UIKit.tap_row(col, func(): _tap_number(n), variation)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return tile


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
	var pid := p.id
	var oid := owner.id if owner != null else -1
	if owner != null:
		UIManager.confirm("Confirmar troca de camisas?", "%s passa para a %d. %s fica com a %d." % [p.display_name(), n, owner.display_name(), p.shirt], "Trocar", func(): _assign_number(n, pid, oid))
	else:
		_assign_number(n, pid, oid)


static func grid_columns(available: float) -> int:
	# Largura de cada célula inclui margem do painel, texto e espaço entre camisas.
	return clampi(int(floor((maxf(0.0, available) + 8.0) / 152.0)), 2, 8)


func _assign_number(n: int, player_id: int, owner_id: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var w := world()
	if w == null or n < 1 or n > 99:
		return
	var club := w.user_club()
	var p := w.player(player_id)
	if p == null or p.club_id != club.id:
		return
	var owner: Player = null
	for q: Player in w.squad(club):
		if q.shirt == n:
			owner = q
	if (owner.id if owner != null else -1) != owner_id or owner == p:
		UIManager.toast("A numeração mudou. Selecione novamente.")
		refresh()
		return
	var old := p.shirt
	p.shirt = n
	if owner != null:
		owner.shirt = old
	# Operação administrativa, não uma fonte repetível de pontos de moral.
	_sel = -1
	UIManager.toast("Numeração atualizada.", UIColors.GREEN)
	GameManager.save_now()
	refresh()
