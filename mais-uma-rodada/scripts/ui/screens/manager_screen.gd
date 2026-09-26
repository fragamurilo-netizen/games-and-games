extends BaseScreen
## Personalizar o treinador: nome, nacionalidade, idade, rosto e estilo de trabalho.
## Cada toque só atualiza a prévia e a linha mexida; o save (o mundo inteiro) acontece uma vez,
## ao sair da tela.

var _nations: Array = []
var _dirty := false
var _portrait_box: Control = null
var _info_label: Label = null
var _flag_box: Control = null
var _style_pill_box: Control = null
var _look_card: Control = null
var _look_slot: VBoxContainer = null


func _init() -> void:
	show_nav = false
	screen_title = "Seu treinador"


func on_hide() -> void:
	if _dirty:
		_dirty = false
		GameManager.save_now()
	super.on_hide()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var m := ManagerProfile.data(w)
	screen_subtitle = w.manager_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_preview(w, m))
	c.add_child(_identity(w, m))
	_look_slot = UIKit.vbox(0)
	c.add_child(_look_slot)
	_rebuild_look(w, m)
	c.add_child(_styles(w, m))


## Marca para salvar na saída e redesenha só a prévia.
func _touch() -> void:
	_dirty = true
	_update_preview()


func _update_preview() -> void:
	var w := world()
	var m := ManagerProfile.data(w)
	if _portrait_box != null:
		UIKit.clear(_portrait_box)
		_portrait_box.add_child(ManagerProfile.portrait(w, 150))
	if _info_label != null:
		_info_label.text = "%s · %d anos" % [DatabaseManager.nation_name(String(m["nat"])), ManagerProfile.age(w)]
	if _flag_box != null:
		UIKit.clear(_flag_box)
		_flag_box.add_child(UIKit.flag(String(m["nat"]), 34))
	if _style_pill_box != null:
		UIKit.clear(_style_pill_box)
		_style_pill_box.add_child(UIKit.pill(ManagerProfile.style_name(String(m["style"])).to_upper(), UIColors.ACCENT, 16))


func _preview(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(16)
	_portrait_box = UIKit.vbox(0)
	_portrait_box.add_child(ManagerProfile.portrait(w, 150))
	row.add_child(_portrait_box)
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(w.manager_name, "Title", true))
	var nrow := UIKit.hbox(8)
	_flag_box = UIKit.hbox(0)
	_flag_box.add_child(UIKit.flag(String(m["nat"]), 34))
	nrow.add_child(_flag_box)
	_info_label = UIKit.label("%s · %d anos" % [DatabaseManager.nation_name(String(m["nat"])), ManagerProfile.age(w)], "Small", true)
	nrow.add_child(_info_label)
	col.add_child(nrow)
	_style_pill_box = UIKit.hbox(0)
	_style_pill_box.add_child(UIKit.pill(ManagerProfile.style_name(String(m["style"])).to_upper(), UIColors.ACCENT, 16))
	col.add_child(_style_pill_box)
	col.add_child(UIKit.label("Técnico do %s" % w.user_club().short_name, "Small"))
	row.add_child(col)
	card.add_child(row)
	return HeroBackdrop.attach(UIKit.card_panel(card), w.user_club())


func _identity(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Identidade"))
	var le := LineEdit.new()
	le.text = w.manager_name
	le.max_length = 28
	le.placeholder_text = "Nome do treinador"
	var set_name := func(t: String):
		var v := t.strip_edges()
		if v != "" and v != w.manager_name:
			w.manager_name = v
			_dirty = true
			refresh()
	le.text_submitted.connect(set_name)
	le.focus_exited.connect(func(): set_name.call(le.text))
	card.add_child(le)
	if _nations.is_empty():
		_nations = DatabaseManager.nations().keys()
		_nations.sort_custom(func(a, b): return DatabaseManager.nation_name(a) < DatabaseManager.nation_name(b))
	# Nacionalidade
	var nrow := UIKit.hbox(6)
	var nl := UIKit.label("Nacionalidade", "Small")
	nl.custom_minimum_size.x = 150
	nrow.add_child(nl)
	var flag_box := UIKit.hbox(0)
	var nv := UIKit.label("", "H3")
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var show_nat := func():
		UIKit.clear(flag_box)
		flag_box.add_child(UIKit.flag(String(m["nat"]), 34))
		nv.text = DatabaseManager.nation_name(String(m["nat"]))
	var step_nat := func(d: int):
		var idx := maxi(0, _nations.find(String(m["nat"])))
		m["nat"] = _nations[posmod(idx + d, _nations.size())]
		show_nat.call()
		_touch()
	nrow.add_child(UIKit.icon_button("back", func(): step_nat.call(-1), "Anterior"))
	nrow.add_child(flag_box)
	nrow.add_child(nv)
	nrow.add_child(UIKit.icon_button("forward", func(): step_nat.call(1), "Próxima"))
	show_nat.call()
	card.add_child(nrow)
	# Idade
	var arow := UIKit.hbox(6)
	var al := UIKit.label("Idade", "Small")
	al.custom_minimum_size.x = 150
	arow.add_child(al)
	var av := UIKit.label("", "H3")
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var step_age := func(d: int):
		m["by"] = clampi(int(m["by"]) - d, w.year - 75, w.year - 28)
		av.text = "%d anos" % ManagerProfile.age(w)
		_touch()
	arow.add_child(UIKit.icon_button("minus", func(): step_age.call(-1), "Menos"))
	arow.add_child(av)
	arow.add_child(UIKit.icon_button("plus", func(): step_age.call(1), "Mais"))
	av.text = "%d anos" % ManagerProfile.age(w)
	card.add_child(arow)
	return UIKit.card_panel(card)


## Aparência: reconstruída só quando a origem ou o rosto base mudam (os traços dependem deles).
func _rebuild_look(w: GameWorld, m: Dictionary) -> void:
	if _look_slot == null:
		return
	UIKit.clear(_look_slot)
	_look_slot.add_child(_look(w, m))


func _look(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Aparência"))
	var look: Dictionary = m["look"]
	var feats := FaceGen.features(int(m["seed"]), int(m["eth"]), ManagerProfile.age(w), look)
	var eths := DatabaseManager.ethnicities()
	card.add_child(_cycler("Origem", ["Nórdica", "Europeia", "Mediterrânea", "Árabe", "Latina", "Andina", "Miscigenada", "Africana", "Leste asiático", "Sul asiático", "Havaiana", "Pacífico", "Sudeste asiático"].slice(0, eths.size()), int(m["eth"]), func(v: int):
		m["eth"] = v
		m["look"] = {}
		_touch()
		_rebuild_look.call_deferred(w, m)))
	card.add_child(_cycler("Penteado", FaceGen.HAIR_STYLES, int(feats["style"]), func(v: int):
		look["hs"] = v
		_touch()))
	card.add_child(_cycler("Barba", FaceGen.BEARDS, int(feats["beard"]), func(v: int):
		look["bd"] = v
		_touch()))
	card.add_child(_cycler("Cabelo", FaceGen.HAIR_COLOR_NAMES, int(feats["hair_i"]), func(v: int):
		look["hc"] = v
		_touch()))
	card.add_child(_cycler("Rosto", FaceGen.FACE_SHAPES, int(feats["face_shape"]), func(v: int):
		look["fs"] = v
		_touch()))
	card.add_child(_cycler("Olhos", FaceGen.EYE_NAMES, int(feats["eye_i"]), func(v: int):
		look["ey"] = v
		_touch()))
	card.add_child(UIKit.label("Tom de pele", "Small"))
	var sl := HSlider.new()
	sl.min_value = FaceGen.SKIN_MIN
	sl.max_value = FaceGen.SKIN_MAX
	sl.step = 0.25
	sl.value = float(feats["skin_i"])
	sl.custom_minimum_size.y = 48
	sl.drag_ended.connect(func(_c: bool):
		look["sk"] = sl.value
		_touch())
	card.add_child(sl)
	card.add_child(UIKit.button("Rosto aleatório", "", func():
		m["seed"] = randi() & 0x7FFFFFFF
		m["look"] = {}
		_touch()
		_rebuild_look.call_deferred(w, m), "bolt"))
	return UIKit.card_panel(card)


## Linha "‹ valor ›": troca só o próprio texto e avisa quem chamou.
func _cycler(caption: String, names: Array, current: int, set_value: Callable) -> Control:
	var row := UIKit.hbox(6)
	var cl := UIKit.label(caption, "Small")
	cl.custom_minimum_size.x = 150
	row.add_child(cl)
	var cur := [clampi(current, 0, names.size() - 1)]
	var v := UIKit.label(String(names[cur[0]]), "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var step := func(d: int):
		cur[0] = posmod(cur[0] + d, names.size())
		v.text = String(names[cur[0]])
		set_value.call(cur[0])
	row.add_child(UIKit.icon_button("back", func(): step.call(-1), "Anterior"))
	row.add_child(v)
	row.add_child(UIKit.icon_button("forward", func(): step.call(1), "Próximo"))
	return row


func _styles(_w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Estilo de trabalho"))
	var marks := {}
	var names := {}
	var paint := func():
		for k in marks:
			var sel := String(m["style"]) == String(k)
			(marks[k] as Control).modulate.a = 1.0 if sel else 0.0
			if sel:
				(names[k] as Label).add_theme_color_override(&"font_color", UIColors.ACCENT)
			else:
				(names[k] as Label).remove_theme_color_override(&"font_color")
	for st in People.COACH_STYLES:
		var key: String = st
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(People.COACH_STYLES[key]["name"]), "H3")
		names[key] = nl
		col.add_child(nl)
		col.add_child(UIKit.label(String(People.COACH_STYLES[key]["desc"]), "Small", true))
		col.add_child(UIKit.colored(String(ManagerProfile.STYLE_FX.get(key, "")), UIColors.GREEN, "Small", true))
		var line := UIKit.hbox(10)
		line.add_child(col)
		var mark := UIKit.icon_rect("check", 30, UIColors.ACCENT)
		marks[key] = mark
		line.add_child(mark)
		card.add_child(UIKit.tap_row(line, func():
			m["style"] = key
			paint.call()
			_touch()))
	paint.call()
	return UIKit.card_panel(card)
