extends BaseScreen
## Personalizar o treinador: nome, nacionalidade, idade, rosto e estilo de trabalho.

var _nations: Array = []


func _init() -> void:
	show_nav = false
	screen_title = "Seu treinador"


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
	c.add_child(_look(w, m))
	c.add_child(_styles(w, m))


func _changed() -> void:
	GameManager.save_now()
	refresh()


func _preview(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(16)
	row.add_child(ManagerProfile.portrait(w, 150))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(w.manager_name, "Title", true))
	var nrow := UIKit.hbox(8)
	nrow.add_child(UIKit.flag(String(m["nat"]), 34))
	nrow.add_child(UIKit.label("%s · %d anos" % [DatabaseManager.nation_name(String(m["nat"])), ManagerProfile.age(w)], "Small", true))
	col.add_child(nrow)
	col.add_child(UIKit.pill(ManagerProfile.style_name(String(m["style"])).to_upper(), UIColors.ACCENT, 16))
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
	le.text_submitted.connect(func(t: String):
		if t.strip_edges() != "":
			w.manager_name = t.strip_edges()
			_changed())
	le.focus_exited.connect(func():
		if le.text.strip_edges() != "" and le.text.strip_edges() != w.manager_name:
			w.manager_name = le.text.strip_edges()
			_changed())
	card.add_child(le)
	if _nations.is_empty():
		_nations = DatabaseManager.nations().keys()
		_nations.sort_custom(func(a, b): return DatabaseManager.nation_name(a) < DatabaseManager.nation_name(b))
	var idx := maxi(0, _nations.find(String(m["nat"])))
	var nrow := UIKit.hbox(6)
	var nl := UIKit.label("Nacionalidade", "Small")
	nl.custom_minimum_size.x = 150
	nrow.add_child(nl)
	nrow.add_child(UIKit.icon_button("back", func():
		m["nat"] = _nations[posmod(idx - 1, _nations.size())]
		_changed(), "Anterior"))
	nrow.add_child(UIKit.flag(String(m["nat"]), 34))
	var nv := UIKit.label(DatabaseManager.nation_name(String(m["nat"])), "H3")
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nrow.add_child(nv)
	nrow.add_child(UIKit.icon_button("forward", func():
		m["nat"] = _nations[posmod(idx + 1, _nations.size())]
		_changed(), "Próxima"))
	card.add_child(nrow)
	var arow := UIKit.hbox(6)
	var al := UIKit.label("Idade", "Small")
	al.custom_minimum_size.x = 150
	arow.add_child(al)
	arow.add_child(UIKit.icon_button("minus", func():
		m["by"] = mini(int(m["by"]) + 1, w.year - 28)
		_changed(), "Menos"))
	var av := UIKit.label("%d anos" % ManagerProfile.age(w), "H3")
	av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	av.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arow.add_child(av)
	arow.add_child(UIKit.icon_button("plus", func():
		m["by"] = maxi(int(m["by"]) - 1, w.year - 75)
		_changed(), "Mais"))
	card.add_child(arow)
	return UIKit.card_panel(card)


func _look(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Aparência"))
	var look: Dictionary = m["look"]
	var feats := FaceGen.features(int(m["seed"]), int(m["eth"]), ManagerProfile.age(w), look)
	var eths := DatabaseManager.ethnicities()
	card.add_child(_cycler("Origem", ["Nórdica", "Europeia", "Mediterrânea", "Árabe", "Latina", "Andina", "Miscigenada", "Africana", "Leste asiático", "Sul asiático", "Havaiana", "Pacífico", "Sudeste asiático"].slice(0, eths.size()), int(m["eth"]), func(v: int):
		m["eth"] = v
		m["look"] = {}))
	card.add_child(_cycler("Penteado", FaceGen.HAIR_STYLES, int(feats["style"]), func(v: int): look["hs"] = v))
	card.add_child(_cycler("Barba", FaceGen.BEARDS, int(feats["beard"]), func(v: int): look["bd"] = v))
	card.add_child(_cycler("Cabelo", FaceGen.HAIR_COLOR_NAMES, int(feats["hair_i"]), func(v: int): look["hc"] = v))
	card.add_child(_cycler("Rosto", FaceGen.FACE_SHAPES, int(feats["face_shape"]), func(v: int): look["fs"] = v))
	card.add_child(_cycler("Olhos", FaceGen.EYE_NAMES, int(feats["eye_i"]), func(v: int): look["ey"] = v))
	card.add_child(UIKit.label("Tom de pele", "Small"))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 9.0
	sl.step = 0.25
	sl.value = float(feats["skin_i"])
	sl.custom_minimum_size.y = 48
	sl.drag_ended.connect(func(_c: bool):
		look["sk"] = sl.value
		_changed())
	card.add_child(sl)
	card.add_child(UIKit.button("Rosto aleatório", "", func():
		m["seed"] = randi() & 0x7FFFFFFF
		m["look"] = {}
		_changed(), "bolt"))
	return UIKit.card_panel(card)


func _cycler(caption: String, names: Array, current: int, set_value: Callable) -> Control:
	var row := UIKit.hbox(6)
	var cl := UIKit.label(caption, "Small")
	cl.custom_minimum_size.x = 150
	row.add_child(cl)
	row.add_child(UIKit.icon_button("back", func():
		set_value.call(posmod(current - 1, names.size()))
		_changed(), "Anterior"))
	var v := UIKit.label(String(names[clampi(current, 0, names.size() - 1)]), "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(v)
	row.add_child(UIKit.icon_button("forward", func():
		set_value.call(posmod(current + 1, names.size()))
		_changed(), "Próximo"))
	return row


func _styles(w: GameWorld, m: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Estilo de trabalho"))
	card.add_child(UIKit.label("Muda como o elenco, a torcida e a diretoria enxergam você. O efeito é pequeno: o estilo é tempero, não atalho.", "Small", true))
	for st in People.COACH_STYLES:
		var key: String = st
		var sel := String(m["style"]) == key
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(String(People.COACH_STYLES[key]["name"]), "H3")
		if sel:
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(nl)
		col.add_child(UIKit.label(String(People.COACH_STYLES[key]["desc"]), "Small", true))
		col.add_child(UIKit.colored(String(ManagerProfile.STYLE_FX.get(key, "")), UIColors.GREEN, "Small", true))
		var line := UIKit.hbox(10)
		line.add_child(col)
		var mark := UIKit.icon_rect("check", 30, UIColors.ACCENT)
		mark.modulate.a = 1.0 if sel else 0.0
		line.add_child(mark)
		card.add_child(UIKit.tap_row(line, func():
			m["style"] = key
			_changed()))
	return UIKit.card_panel(card)
