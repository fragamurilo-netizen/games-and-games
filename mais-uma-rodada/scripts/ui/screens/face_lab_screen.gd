extends BaseScreen
## Laboratório de rostos: bancada para revisar e ajustar o gerador procedural. Semente, etnia e
## idade (mais ajustes finos do DNA) → retrato grande, resumo do DNA facial, validação anatômica,
## tempo de geração e FPS. "Gerar 100 rostos" monta uma grade para conferir a variedade; tocar num
## rosto da grade o abre em destaque. Nada aqui mexe na carreira.

const ETH_NAMES := ["Nórdico", "Europeu", "Mediterrâneo", "Árabe", "Latino", "Andino", "Miscigenado",
	"Africano", "Leste asiático", "Sul asiático", "Chifre da África", "Pacífico", "Sudeste asiático"]
const LAB_NAMES := {
	"fw": "Largura do rosto", "fh": "Altura do rosto", "jaw": "Mandíbula", "chin": "Queixo",
	"cheek": "Maçãs do rosto", "eye_dx": "Distância dos olhos", "eye_size": "Tamanho dos olhos",
	"nose_w": "Largura do nariz", "nose_len": "Comprimento do nariz", "mouth_w": "Largura da boca",
}
const SAVE_PATH := "user://face_lab.json"
const GRID_N := 100

var _seed := 1001
var _eth := 4
var _age := 24
var _lab := {}
var _sk := -99.0
var _hs := -1
var _bd := -1
var _saved: Array = []
var _built := false
var _view: PortraitView = null
var _title: Label = null
var _stats: Label = null
var _check: Label = null
var _dna: Label = null
var _saved_box: HFlowContainer = null
var _grid_box: VBoxContainer = null
var _grid_views: Array = []
var _grid_t0 := 0
var _grid_info: Label = null
var _sliders: Dictionary = {}
var _dna_usec := 0
var _fps_t := 0.0


func _init() -> void:
	show_nav = false
	screen_title = "Laboratório de rostos"
	screen_subtitle = "Gerador procedural · FaceDNA v%d" % FaceDNA.VERSION


func on_show() -> void:
	if not _built:
		_load_saved()
		_build()
	set_process(true)


func on_hide() -> void:
	set_process(false)
	# A luz do laboratório não vaza para o resto do jogo
	FaceLighting.contrast = 1.0


func _exit_tree() -> void:
	FaceLighting.contrast = 1.0


func refresh() -> void:
	if _built:
		_update()


func _process(delta: float) -> void:
	_fps_t += delta
	if _fps_t < 0.25:
		return
	_fps_t = 0.0
	if _view != null and _stats != null:
		_stats.text = "Geração do DNA %.2f ms · desenho %.1f ms · %d FPS" % [_dna_usec / 1000.0, _view.last_draw_usec / 1000.0, Engine.get_frames_per_second()]
	if not _grid_views.is_empty() and _grid_info != null:
		var total := 0
		var drawn := 0
		for v: PortraitView in _grid_views:
			if v.last_draw_usec > 0:
				total += v.last_draw_usec
				drawn += 1
		if drawn > 0:
			_grid_info.text = "%d rostos · média %.1f ms por retrato (desenho) · %d FPS" % [drawn, total / 1000.0 / drawn, Engine.get_frames_per_second()]


func _build() -> void:
	_built = true
	max_content_width = 1500
	var c := content()
	UIKit.clear(c)
	var wide := UILayout.is_wide()
	# --- Retrato + informações
	var top: BoxContainer = UIKit.hbox(20) if wide else UIKit.vbox(12)
	_view = PortraitView.new()
	_view.no_cache = true
	_view.custom_minimum_size = Vector2(300, 300) if wide else Vector2(240, 240)
	_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_view.bg_color = Color("#3A3F46")
	_view.shirt_color = Color("#2B3440")
	_view.trim_color = Color("#DDE3EA")
	top.add_child(_view)
	var info := UIKit.card("Card", 8)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title = UIKit.label("", "H2")
	info.add_child(_title)
	_stats = UIKit.label("", "Muted")
	info.add_child(_stats)
	_check = UIKit.label("", "Small", true)
	info.add_child(_check)
	_dna = UIKit.label("", "Small", true)
	info.add_child(_dna)
	top.add_child(UIKit.card_panel(info))
	c.add_child(top)
	# --- Navegação entre sementes
	var nav := HFlowContainer.new()
	nav.add_theme_constant_override(&"h_separation", 8)
	nav.add_theme_constant_override(&"v_separation", 8)
	nav.add_child(UIKit.button("Aleatório", "PrimaryButton", func():
		_seed = randi() % 10000000
		_eth = randi() % FaceGen.ETH_COUNT
		_age = randi_range(17, 36)
		_sync_sliders()
		_update(), "bolt"))
	nav.add_child(UIKit.button("Anterior", "", func():
		_seed = maxi(0, _seed - 1)
		_update(), "back"))
	nav.add_child(UIKit.button("Próximo", "", func():
		_seed += 1
		_update(), "forward"))
	nav.add_child(UIKit.button("Salvar semente", "GhostButton", _save_current, "star"))
	nav.add_child(UIKit.button("Zerar ajustes", "GhostButton", func():
		_lab = {}
		_sk = -99.0
		_hs = -1
		_bd = -1
		FaceLighting.contrast = 1.0
		_sync_sliders()
		_update(), "swap"))
	c.add_child(nav)
	# --- Etnia
	var eth := OptionButton.new()
	for i in ETH_NAMES.size():
		eth.add_item(ETH_NAMES[i], i)
	eth.selected = _eth
	eth.custom_minimum_size.y = 48
	eth.item_selected.connect(func(i: int):
		_eth = i
		_update())
	_sliders["eth"] = eth
	var eth_row := UIKit.hbox(10)
	var el := UIKit.label("Etnia", "Muted")
	el.custom_minimum_size.x = 120
	eth_row.add_child(el)
	eth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eth_row.add_child(eth)
	c.add_child(eth_row)
	# --- Controles
	var sl_card := UIKit.card("Card", 4)
	sl_card.add_child(UIKit.section("Pessoa"))
	var cols := GridContainer.new()
	cols.columns = 2 if wide else 1
	cols.add_theme_constant_override(&"h_separation", 24)
	cols.add_theme_constant_override(&"v_separation", 2)
	cols.add_child(_slider("age", "Idade", 16, 45, 1, float(_age), func(v: float): _age = int(v), func(v: float): return "%d anos" % int(v)))
	cols.add_child(_slider("sk", "Pele", FaceGen.SKIN_MIN - 0.5, FaceGen.SKIN_MAX, 0.25, _sk if _sk > -50.0 else FaceGen.SKIN_MIN - 0.5,
		func(v: float): _sk = v if v >= FaceGen.SKIN_MIN else -99.0,
		func(v: float): return "do DNA" if v < FaceGen.SKIN_MIN else "%.2f" % v))
	cols.add_child(_slider("hs", "Cabelo", -1, FaceGen.HAIR_STYLES.size() - 1, 1, _hs,
		func(v: float): _hs = int(v),
		func(v: float): return "do DNA" if v < 0 else FaceGen.HAIR_STYLES[int(v)]))
	cols.add_child(_slider("bd", "Barba", -1, FaceGen.BEARDS.size() - 1, 1, _bd,
		func(v: float): _bd = int(v),
		func(v: float): return "do DNA" if v < 0 else FaceGen.BEARDS[int(v)]))
	cols.add_child(_slider("light", "Luz (contraste)", 0.0, 1.5, 0.05, FaceLighting.contrast,
		func(v: float): FaceLighting.contrast = v,
		func(v: float): return "padrão" if is_equal_approx(v, 1.0) else "%.2f" % v))
	sl_card.add_child(cols)
	sl_card.add_child(UIKit.section("Estrutura do rosto"))
	var cols2 := GridContainer.new()
	cols2.columns = 2 if wide else 1
	cols2.add_theme_constant_override(&"h_separation", 24)
	cols2.add_theme_constant_override(&"v_separation", 2)
	for key: String in FaceVariation.LAB_KEYS:
		var k := key
		cols2.add_child(_slider(k, String(LAB_NAMES[k]), -1.0, 1.0, 0.05, float(_lab.get(k, 0.0)),
			func(v: float):
				if is_zero_approx(v):
					_lab.erase(k)
				else:
					_lab[k] = v,
			func(v: float): return "0" if is_zero_approx(v) else "%+.2f" % v))
	sl_card.add_child(cols2)
	c.add_child(UIKit.card_panel(sl_card))
	# --- Sementes salvas
	c.add_child(UIKit.section_header("Sementes salvas"))
	_saved_box = HFlowContainer.new()
	_saved_box.add_theme_constant_override(&"h_separation", 8)
	_saved_box.add_theme_constant_override(&"v_separation", 8)
	c.add_child(_saved_box)
	_fill_saved()
	# --- Grade de 100
	c.add_child(UIKit.section_header("Variedade"))
	var grow := UIKit.hbox(10)
	grow.add_child(UIKit.button("Gerar 100 rostos", "PrimaryButton", func(): _gen_grid(false), "table"))
	grow.add_child(UIKit.button("100 desta etnia", "", func(): _gen_grid(true), "table"))
	c.add_child(grow)
	_grid_info = UIKit.label("Toque num rosto da grade para abri-lo em destaque.", "Small", true)
	c.add_child(_grid_info)
	_grid_box = UIKit.vbox(0)
	c.add_child(_grid_box)
	_update()


func _slider(key: String, text: String, lo: float, hi: float, step: float, value: float, on_change: Callable, fmt: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 0)
	var head := UIKit.hbox(8)
	var l := UIKit.label(text, "Muted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var val := UIKit.label(String(fmt.call(value)), "Small")
	head.add_child(val)
	box.add_child(head)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = value
	sl.custom_minimum_size.y = 40
	sl.focus_mode = Control.FOCUS_NONE
	sl.value_changed.connect(func(v: float):
		val.text = String(fmt.call(v))
		on_change.call(v)
		_update())
	box.add_child(sl)
	_sliders[key] = sl
	return box


## Põe os controles de acordo com o estado (depois de "Aleatório", "Zerar" ou abrir uma semente).
func _sync_sliders() -> void:
	var vals := {"age": float(_age), "sk": _sk if _sk > -50.0 else FaceGen.SKIN_MIN - 0.5, "hs": float(_hs), "bd": float(_bd), "light": FaceLighting.contrast}
	for key: String in FaceVariation.LAB_KEYS:
		vals[key] = float(_lab.get(key, 0.0))
	for key in vals:
		var sl := _sliders.get(key) as HSlider
		if sl != null:
			sl.set_value_no_signal(float(vals[key]))
			sl.value_changed.emit(sl.value)
	var eth := _sliders.get("eth") as OptionButton
	if eth != null:
		eth.selected = _eth


func _look() -> Dictionary:
	var lk := {}
	if not _lab.is_empty():
		lk["lab"] = _lab.duplicate()
	if _sk > -50.0:
		lk["sk"] = _sk
	if _hs >= 0:
		lk["hs"] = _hs
	if _bd >= 0:
		lk["bd"] = _bd
	return lk


func _update() -> void:
	if _view == null:
		return
	var lk := _look()
	var t0 := Time.get_ticks_usec()
	var f := FaceDNA.from_seed(_seed, _eth, _age, lk)
	_dna_usec = Time.get_ticks_usec() - t0
	_view.face_seed = _seed
	_view.eth = _eth
	_view.age = _age
	_view.look = lk
	_view.queue_redraw()
	_title.text = "Semente %d · %s · %d anos" % [_seed, ETH_NAMES[_eth], _age]
	var probs := FaceDNA.validate(f)
	if probs.is_empty():
		_check.text = "Anatomia: OK (nenhum problema encontrado)"
		_check.add_theme_color_override(&"font_color", UIColors.GREEN)
	else:
		_check.text = "Anatomia: " + "; ".join(probs)
		_check.add_theme_color_override(&"font_color", UIColors.ORANGE)
	_dna.text = FaceDNA.summary(f)


func _gen_grid(same_eth: bool) -> void:
	UIKit.clear(_grid_box)
	_grid_views.clear()
	var px := 84 if UILayout.is_wide() else 72
	var grid := GridContainer.new()
	grid.columns = maxi(3, int((content_width() + 6) / (px + 6)))
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in GRID_N:
		var v := PortraitView.new()
		v.no_cache = true
		v.custom_minimum_size = Vector2(px, px)
		var sd := rng.randi() % 10000000
		var e := _eth if same_eth else rng.randi() % FaceGen.ETH_COUNT
		var a := rng.randi_range(17, 36)
		v.face_seed = sd
		v.eth = e
		v.age = a
		var hue := rng.randf()
		v.shirt_color = Color.from_hsv(hue, 0.6, 0.7)
		v.bg_color = v.shirt_color.darkened(0.6)
		v.mouse_filter = Control.MOUSE_FILTER_STOP
		v.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_seed = sd
				_eth = e
				_age = a
				_sync_sliders()
				_update()
				scroll_to_top())
		grid.add_child(v)
		_grid_views.append(v)
	_grid_box.add_child(grid)
	_grid_info.text = "Gerando %d rostos…" % GRID_N


func _save_current() -> void:
	var entry := {"seed": _seed, "eth": _eth, "age": _age, "look": _look()}
	for e in _saved:
		if var_to_str(e) == var_to_str(entry):
			return
	_saved.append(entry)
	var fa := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa != null:
		fa.store_string(var_to_str(_saved))
	_fill_saved()


func _load_saved() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var v: Variant = str_to_var(FileAccess.get_file_as_string(SAVE_PATH))
	if v is Array:
		_saved = v


func _fill_saved() -> void:
	if _saved_box == null:
		return
	UIKit.clear(_saved_box)
	if _saved.is_empty():
		_saved_box.add_child(UIKit.label("Nenhuma ainda. \"Salvar semente\" guarda o rosto atual (com os ajustes) para voltar depois.", "Small", true))
		return
	for e: Dictionary in _saved:
		var entry := e
		var lk: Dictionary = entry.get("look", {})
		_saved_box.add_child(UIKit.button("#%d · %s · %d" % [int(entry["seed"]), ETH_NAMES[clampi(int(entry["eth"]), 0, 12)], int(entry["age"])], "", func():
			_seed = int(entry["seed"])
			_eth = int(entry["eth"])
			_age = int(entry["age"])
			_lab = (lk.get("lab", {}) as Dictionary).duplicate()
			_sk = float(lk.get("sk", -99.0))
			_hs = int(lk.get("hs", -1))
			_bd = int(lk.get("bd", -1))
			_sync_sliders()
			_update()))
