extends BaseScreen
## Fundar a academia: nome, país e cidade, cores e o caixa inicial (como no LEATHER, quem
## escolhe o tamanho do desafio é o jogador).

const NATIONS := ["BRA", "USA", "POR", "ENG", "IRL", "MEX", "ARG", "POL", "RUS", "JPN", "AUS", "CAN", "FRA", "ESP"]

var _name := "Equipe Nova Era"
var _nation := "BRA"
var _city := ""
var _colors := 0
var _funds := 1
var _name_edit: LineEdit


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Nova academia"
	show_nav = false


func refresh() -> void:
	var c := reset()
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
	pv.add_child(UIKit.label("%s · %s" % [_city, DataDB.nation_name(_nation)], "Small"))
	ph.add_child(pv)
	prev.add_child(ph)
	c.add_child(UIKit.card_panel(prev))
	# Nome
	c.add_child(UIKit.section_header("Nome da academia"))
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
	c.add_child(UIKit.section_header("País da academia"))
	var fl := UIKit.flow(8)
	var g := ButtonGroup.new()
	for code: String in NATIONS:
		fl.add_child(UIKit.chip(DataDB.nation_name(code), code == _nation, g, func():
			_nation = code
			_city = ""
			refresh()))
	c.add_child(fl)
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
	c.add_child(UIKit.segment([["0", "US$ 100 mil"], ["1", "US$ 250 mil"], ["2", "US$ 500 mil"]], str(_funds), func(k: String):
		_funds = int(k)))
	var hint := UIKit.label("Com menos dinheiro, cada contratação e cada técnico pesam mais. US$ 250 mil é o padrão.", "Small", true)
	c.add_child(hint)
	var f := footer()
	f.add_child(UIKit.button("Fundar a academia", "PrimaryButton", _start))


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
		UIManager.toast("Dê um nome à academia.", UIColors.RED)
		return
	var pair: Array = WorldGenerator.TEAM_COLORS[_colors]
	UIManager.toast("Criando o mundo do MMA…")
	await get_tree().process_frame
	await get_tree().process_frame
	GameManager.delete_save()
	var w := Career.new_career(_name, "", _nation, _city, Color(String(pair[0])), Color(String(pair[1])), Career.START_FUNDS[_funds], int(Time.get_unix_time_from_system()) % 100000)
	GameManager.start_career(w)
	UIManager.goto("hub")
