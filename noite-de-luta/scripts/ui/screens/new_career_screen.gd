extends BaseScreen
## Nova carreira: o papel (empresário de uma academia, como no LEATHER, ou presidente da
## organização de elite), o nome, o país, as cores e o caixa inicial. Nos dois papéis o mundo é o
## mesmo e anda sozinho; o papel é o jeito de participar dele.

const NATIONS := ["BRA", "USA", "POR", "ENG", "IRL", "MEX", "ARG", "POL", "RUS", "JPN", "AUS", "CAN", "FRA", "ESP"]

var _role := "empresario"
var _name := "Equipe Nova Era"
var _nation := "BRA"
var _city := ""
var _colors := 0
var _funds := 1
var _name_edit: LineEdit


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Nova carreira"
	show_nav = false


func refresh() -> void:
	var c := reset()
	var pres := _role == "presidente"
	c.add_child(UIKit.segment([["empresario", "Empresário"], ["presidente", "Presidente"]], _role, func(k: String):
		if k == _role:
			return
		_role = k
		_name = "Liga Global de Combate" if k == "presidente" else "Equipe Nova Era"
		_funds = 1
		refresh()))
	c.add_child(UIKit.label("Dono de uma academia: contrata, treina, aceita lutas e leva alguém até o cinturão." if not pres else "Presidente da liga de elite: marca as noites, monta os cards, decide quem disputa o cinturão e cuida das contas.", "Small", true))
	var cities: Array = DataDB.cities(_nation)
	if _city == "" or not cities.any(func(x: Array) -> bool: return String(x[0]) == _city):
		_city = String((cities[0] as Array)[0]) if not cities.is_empty() else ""
	# Prévia: o selo e o nome como vão aparecer na barra.
	var prev := UIKit.card("CardHighlight", UITokens.S2)
	var ph := UIKit.hbox(UITokens.S3)
	var badge := TeamBadge.new()
	badge.custom_minimum_size = Vector2(88, 88)
	badge.team = _preview_team()
	ph.add_child(badge)
	var pv := UIKit.vbox(2)
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm := UIKit.label(_name, "Section")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(nm)
	pv.add_child(UIKit.label(("%s · %s" % [_city, DataDB.nation_name(_nation)]) if not pres else "Sede em %s" % DataDB.nation_name(_nation), "Small"))
	ph.add_child(pv)
	prev.add_child(ph)
	c.add_child(UIKit.card_panel(prev))
	# Nome
	c.add_child(UIKit.section_header("Nome da academia" if not pres else "Nome da organização"))
	_name_edit = LineEdit.new()
	_name_edit.text = _name
	_name_edit.max_length = 28
	_name_edit.custom_minimum_size.y = UITokens.H_BUTTON
	_name_edit.text_changed.connect(func(t: String):
		_name = t.strip_edges()
		nm.text = _name
		badge.team = _preview_team())
	c.add_child(_name_edit)
	# País
	c.add_child(UIKit.section_header("País da academia" if not pres else "País da sede"))
	var fl := UIKit.flow(8)
	var g := ButtonGroup.new()
	for code: String in NATIONS:
		fl.add_child(UIKit.chip(DataDB.nation_name(code), code == _nation, g, func():
			_nation = code
			_city = ""
			refresh()))
	c.add_child(fl)
	if not pres:
		c.add_child(UIKit.section_header("Cidade"))
		var cf := UIKit.flow(8)
		var g2 := ButtonGroup.new()
		for i in mini(cities.size(), 10):
			var cn := String((cities[i] as Array)[0])
			cf.add_child(UIKit.chip(cn, cn == _city, g2, func():
				_city = cn
				refresh()))
		c.add_child(cf)
	# Cores
	c.add_child(UIKit.section_header("Cores"))
	var grid := GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	for i in WorldGenerator.TEAM_COLORS.size():
		var pair: Array = WorldGenerator.TEAM_COLORS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		b.toggle_mode = true
		b.button_pressed = i == _colors
		b.theme_type_variation = "ChipButton"
		var sw := TeamBadge.new()
		var t := Team.new()
		t.color1 = Color(String(pair[0]))
		t.color2 = Color(String(pair[1]))
		sw.team = t
		sw.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sw.offset_left = 6
		sw.offset_top = 6
		sw.offset_right = -6
		sw.offset_bottom = -6
		b.add_child(sw)
		var idx := i
		b.pressed.connect(func():
			_colors = idx
			refresh())
		grid.add_child(b)
	c.add_child(grid)
	# Caixa inicial
	c.add_child(UIKit.section_header("Caixa inicial"))
	if pres:
		c.add_child(UIKit.segment([["0", "US$ 6 mi"], ["1", "US$ 12 mi"], ["2", "US$ 25 mi"]], str(_funds), func(k: String):
			_funds = int(k)))
		c.add_child(UIKit.label("Uma noite fraca dá prejuízo; um pay-per-view com estrelas paga meses de folha. US$ 12 mi é o padrão.", "Small", true))
	else:
		c.add_child(UIKit.segment([["0", "US$ 100 mil"], ["1", "US$ 250 mil"], ["2", "US$ 500 mil"]], str(_funds), func(k: String):
			_funds = int(k)))
		c.add_child(UIKit.label("Com menos dinheiro, cada contratação e cada técnico pesam mais. US$ 250 mil é o padrão.", "Small", true))
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("Fundar a academia" if not pres else "Assumir a organização", "PrimaryButton", _start))


func _preview_team() -> Team:
	var t := Team.new()
	var pair: Array = WorldGenerator.TEAM_COLORS[_colors]
	t.color1 = Color(String(pair[0]))
	t.color2 = Color(String(pair[1]))
	t.name = _name
	t.short = WorldGenerator.short_of(_name if _name != "" else "Equipe")
	return t


func _start() -> void:
	if _name.length() < 3:
		UIManager.toast("Dê um nome à %s." % ("organização" if _role == "presidente" else "academia"), UIColors.RED)
		return
	var pair: Array = WorldGenerator.TEAM_COLORS[_colors]
	UIManager.toast("Criando o mundo do MMA…")
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.delete_save()
	var seed_v := int(Time.get_unix_time_from_system()) % 100000
	var w: GameWorld
	if _role == "presidente":
		w = Org.new_career(_name, "", _nation, Color(String(pair[0])), Color(String(pair[1])), Org.START_FUNDS[_funds], seed_v)
	else:
		w = Career.new_career(_name, "", _nation, _city, Color(String(pair[0])), Color(String(pair[1])), Career.START_FUNDS[_funds], seed_v)
	GameManager.start_career(w)
	UIManager.goto("hub")
