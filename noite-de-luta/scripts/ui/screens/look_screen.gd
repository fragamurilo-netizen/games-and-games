extends BaseScreen
## Editor de visual: cabelo, rosto, maquiagem, corpo e barba de um lutador, com o resultado ao vivo
## no retrato, na ficha (corpo inteiro) e no boneco da luta. Cada ajuste vai direto para
## `Fighter.look` (as chaves que o FaceGen lê) e vale no jogo inteiro; o visual de antes da primeira
## edição fica em `Fighter.look0`, para o botão "Original".

const HAIR_CATS := [["sug", "Sugeridos"], ["longo", "Longos"], ["preso", "Presos"], ["tranca", "Tranças"],
	["cacho", "Cachos"], ["medio", "Médios"], ["curto", "Curtos"], ["raspado", "Raspados"]]
const BEARD_CATS := [["0", "Sem barba"], ["1", "Por fazer"], ["2", "Bigode"], ["3", "Cavanhaque"], ["4", "Curta"],
	["5", "Média"], ["6", "Longa"]]
## Cortes que mais se vê em lutador, para a aba Sugeridos deles.
const MALE_HAIR := [1, 4, 17, 0, 3, 26, 16, 2, 12, 113, 115, 130, 131, 14, 46, 10, 54, 5, 30, 47, 6, 25, 13, 7, 8, 22, 9, 27, 21, 11]
const TATTOO_OPTS := [["0", "Sem"], ["1", "Ombro"], ["2", "Peito"], ["3", "Manga"]]
const MAKEUP_OPTS := [["0", "Sem"], ["1", "Natural"], ["2", "Marcada"], ["3", "Gala"]]
const TILE_SEP := 8
const TILE_LABEL_H := 46


## Amostra de cor redonda (cabelo, olhos, batom, sombra).
class Swatch extends Button:
	var col := Color.WHITE
	var on := false

	func _init(c: Color, selected: bool) -> void:
		col = c
		on = selected
		flat = true
		custom_minimum_size = Vector2(60, 60)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for st: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 8.0
		if on:
			draw_circle(c, r + 7.0, UIColors.ACCENT)
			draw_circle(c, r + 3.5, UIColors.BG)
		draw_circle(c, r, col)
		# Brilho de esmalte em cima e borda fina: a cor lê como amostra, não como botão chapado.
		draw_arc(c, r - 3.0, PI * 1.12, PI * 1.6, 12, Color(1, 1, 1, 0.3), 3.0, true)
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.16), 1.5, true)


## O boneco da luta 2D, parado na guarda.
class RigPreview extends Control:
	var rig: Rig2D = null

	func _draw() -> void:
		if rig == null:
			return
		draw_rect(Rect2(0, size.y - 14.0, size.x, 14.0), Color(1, 1, 1, 0.05))
		# Enquadra a guarda inteira: a do wrestler é larga (tronco para a frente, braços estendidos).
		var U := size.y / 8.6
		var j := rig.joints(0.0, 0.0, U)
		var lo := INF
		var hi := -INF
		for k: String in j:
			if j[k] is Vector2:
				lo = minf(lo, (j[k] as Vector2).x)
				hi = maxf(hi, (j[k] as Vector2).x)
		var k_fit := minf(1.0, size.x / (hi - lo + U * 1.5))
		rig.draw(self, size.x * 0.5 - (lo + hi) * 0.5 * k_fit, size.y - 8.0, U * k_fit)


var _f: Fighter
var _tab := "cabelo"
var _hair_cat := "sug"
var _beard_cat := ""
var _feat: Dictionary = {}
var _portrait: PortraitView
var _body: BodyView
var _rig: RigPreview
var _tabs_host: Control
var _timer: Timer
var _dirty := false
var _pending: Array = []
var _tiles: Dictionary = {}
var _tile_key := ""
var _sel_label: Label
static var _grabber: Texture2D = null


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Visual"
	show_nav = false
	_tab = String(p.get("tab", "cabelo"))
	_build_preview()
	set_process(false)


## Quadro fixo no alto (retrato, corpo inteiro e boneco da luta) e as abas; só os controles rolam.
func _build_preview() -> void:
	var body := get_node("Body") as VBoxContainer
	var top := PanelContainer.new()
	top.name = "Preview"
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE
	sb.border_color = UIColors.LINE
	sb.border_width_bottom = 1
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 0
	top.add_theme_stylebox_override(&"panel", sb)
	var v := UIKit.vbox(4)
	var row := UIKit.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_portrait = PortraitView.new()
	_portrait.blank = true
	_portrait.custom_minimum_size = Vector2(232, 232)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)
	_body = BodyView.new()
	_body.custom_minimum_size = Vector2(132, 268)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_body)
	_rig = RigPreview.new()
	_rig.custom_minimum_size = Vector2(150, 268)
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.clip_contents = true
	row.add_child(_rig)
	v.add_child(row)
	_tabs_host = UIKit.vbox(0)
	v.add_child(_tabs_host)
	top.add_child(v)
	body.add_child(top)
	body.move_child(top, 0)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = 0.05
	_timer.timeout.connect(_update_preview)
	add_child(_timer)


func refresh() -> void:
	var w := world()
	_f = w.fighter(int(params["id"]))
	if _f == null:
		return
	var fem := _f.is_female()
	screen_subtitle = _f.display_name()
	UIManager.refresh_chrome()
	if _tab == "maquiagem" and not fem or _tab == "barba" and fem:
		_tab = "cabelo"
	_feat = FaceGen.features(_f.face_seed, _f.eth, w.age_of(_f), _f.look)
	var tabs := [["cabelo", "Cabelo"], ["rosto", "Rosto"]]
	tabs.append(["maquiagem", "Maquiagem"] if fem else ["barba", "Barba"])
	tabs.append(["corpo", "Corpo"])
	UIKit.clear(_tabs_host)
	_tabs_host.add_child(UIKit.tabs(tabs, _tab, func(k: String):
		_tab = k
		scroll().scroll_vertical = 0
		refresh()))
	var c := reset()
	_pending.clear()
	_tiles.clear()
	_sel_label = null
	match _tab:
		"rosto":
			_tab_face(c)
		"maquiagem":
			_tab_makeup(c)
		"barba":
			_tab_beard(c)
		"corpo":
			_tab_body(c, fem)
		_:
			_tab_hair(c, fem)
	var foot := footer()
	var h := UIKit.hbox(UITokens.S2)
	var rnd := UIKit.button("Sortear", "GhostButton", _randomize)
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rnd)
	var orig := UIKit.button("Original", "GhostButton", _restore)
	orig.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orig.disabled = _f.look0.is_empty()
	h.add_child(orig)
	var done := UIKit.button("Pronto", "PrimaryButton", func():
		_save()
		UIManager.back())
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.size_flags_stretch_ratio = 1.3
	h.add_child(done)
	foot.add_child(h)
	_update_preview()
	set_process(not _pending.is_empty())


func _exit_tree() -> void:
	_save()


func _save() -> void:
	if _dirty and is_instance_valid(GameManager):
		GameManager.save_now()
		_dirty = false


## Grava um ajuste. Na primeira edição guarda o visual de antes (`look0`); a marca `ed` avisa a
## virada do ano (Development.yearly_look) para não trocar cabelo e barba de quem foi editado.
func _put(key: String, value: Variant, rebuild: bool = true) -> void:
	if _f.look0.is_empty():
		_f.look0 = _f.look.duplicate(true)
		_f.look0["o"] = 1
	_f.look[key] = value
	_f.look["ed"] = 1
	_dirty = true
	if rebuild:
		refresh()
	else:
		_timer.start()


func _restore() -> void:
	if _f.look0.is_empty():
		return
	_f.look = _f.look0.duplicate(true)
	_f.look.erase("o")
	_f.look0 = {}
	_dirty = true
	UIManager.toast("%s voltou ao visual original." % _f.short_name())
	refresh()


## Um visual novo de uma vez: penteado, e maquiagem (elas) ou barba (eles).
func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fem := _f.is_female()
	var hair := _suggested(fem)
	_put("hs", int(hair[rng.randi() % hair.size()]), false)
	if fem:
		_put("mk", 1 + rng.randi() % 3, false)
		_put("lp", rng.randi() % FaceGen.LIP_COLORS.size(), false)
		_put("sd", rng.randi() % FaceGen.SHADOW_COLORS.size(), false)
	else:
		var beards := [0, 0, 1, 10, 2, 3, 4, 6, 7, 26, 36, 9]
		_put("bd", int(beards[rng.randi() % beards.size()]), false)
	refresh()


func _update_preview() -> void:
	if _f == null or _portrait == null:
		return
	var w := world()
	var t := w.team(_f.team_id)
	if t != null:
		_portrait.gear_trim = t.color1
	# O retrato e a cabeça da figura são montados fora da thread principal: o ajuste responde na
	# hora e a imagem troca quando fica pronta.
	_portrait.set_face_async(_f.face_seed, _f.eth, w.age_of(_f), _f.look.duplicate())
	_body.live = false
	_body.set_fighter(w, _f)
	_body.look = _f.look.duplicate()
	_body.ref_cm = _f.height_cm + 4
	_body.queue_redraw()
	_rig.rig = Rig2D.from_fighter(w, _f, 1.0)
	_rig.queue_redraw()


# --- Abas ------------------------------------------------------------------------------------

func _tab_hair(c: VBoxContainer, fem: bool) -> void:
	var hc := int(_feat.get("hair_i", 0))
	_swatches(c, "Cor do cabelo", FaceGen.HAIR_COLOR_NAMES, FaceGen.HAIR_COLORS, hc, "hc")
	var cur := int(_feat.get("style", 1))
	c.add_child(_title("Penteado", FaceGen.HAIR_STYLES[cur], true))
	c.add_child(UIKit.scroll_tabs(HAIR_CATS, _hair_cat, func(k: String):
		_hair_cat = k
		refresh()))
	var ids: Array = []
	if _hair_cat == "sug":
		ids = _suggested(fem)
		if not ids.has(cur):
			ids.push_front(cur)
	else:
		for i in FaceGen.HAIR_STYLES.size():
			if _hair_cat_of(i) == _hair_cat:
				ids.append(i)
	_thumbs(c, "hs", ids, FaceGen.HAIR_STYLES, cur)


func _tab_beard(c: VBoxContainer) -> void:
	var cur := int(_feat.get("beard", 0))
	if _beard_cat == "":
		_beard_cat = str(HairShape.beard(cur))
	c.add_child(_title("Barba", FaceGen.BEARDS[cur], true))
	c.add_child(UIKit.scroll_tabs(BEARD_CATS, _beard_cat, func(k: String):
		_beard_cat = k
		refresh()))
	var ids: Array = []
	for i in FaceGen.BEARDS.size():
		if str(HairShape.beard(i)) == _beard_cat:
			ids.append(i)
	_thumbs(c, "bd", ids, FaceGen.BEARDS, cur)


func _tab_face(c: VBoxContainer) -> void:
	var fem := _f.is_female()
	_slider(c, "Beleza", "bt", float(_feat.get("beauty", 0.6)), 0.3, 1.0,
		["comum", "boa aparência", "marcante", "de capa de revista"])
	_slider(c, "Tom de pele", "sk", float(_feat.get("skin_i", 4.0)), FaceGen.SKIN_MIN, FaceGen.SKIN_MAX,
		["bem claro", "claro", "moreno", "escuro", "retinto"])
	_swatches(c, "Cor dos olhos", FaceGen.EYE_NAMES, FaceGen.EYE_COLORS, int(_feat.get("eye_i", 0)), "ey")
	var card := UIKit.card("Card", 0)
	_stepper(card, "Formato", "fs", FaceGen.FACE_SHAPES, int(_feat.get("face_shape", 0)))
	_stepper(card, "Olhos", "es", FaceGen.EYE_SHAPES, int(_feat.get("eye_shape", 0)))
	_stepper(card, "Sobrancelha", "bw", FaceGen.BROW_TYPES, int(_feat.get("brow_type", 0)))
	_stepper(card, "Nariz", "ns", FaceGen.NOSE_TYPES, int(_feat.get("nose_type", 0)))
	_stepper(card, "Boca", "mt", FaceGen.MOUTH_TYPES, int(_feat.get("mouth_type", 0)))
	_stepper(card, "Queixo", "cn", FaceGen.CHIN_TYPES, int(_feat.get("chin_type", 0)))
	_stepper(card, "Expressão", "ex", FaceGen.EXPRESSIONS, int(_feat.get("expr", 0)))
	c.add_child(UIKit.card_panel(card))
	if fem:
		c.add_child(UIKit.label("Nas lutadoras o rosto sempre sai mais oval e suave do que o formato escolhido.", "Small", true))


func _tab_makeup(c: VBoxContainer) -> void:
	var mk := int(_feat.get("makeup", 1))
	c.add_child(_title("Maquiagem", FaceGen.MAKEUP_NAMES[mk]))
	c.add_child(UIKit.segment(MAKEUP_OPTS, str(mk), func(k: String): _put("mk", int(k))))
	_swatches(c, "Batom", FaceGen.LIP_NAMES, FaceGen.LIP_COLORS, int(_feat.get("lip_i", 0)), "lp")
	_swatches(c, "Sombra", FaceGen.SHADOW_NAMES, FaceGen.SHADOW_COLORS, int(_feat.get("shadow_i", 0)), "sd")
	if mk == 0:
		c.add_child(UIKit.label("Sem maquiagem a sombra não aparece e o batom fica só como um tom nos lábios.", "Small", true))


func _tab_body(c: VBoxContainer, fem: bool) -> void:
	if fem:
		_slider(c, "Busto", "bu", float(_feat.get("bust", 0.5)), 0.0, 1.0, ["pequeno", "médio", "cheio", "farto"])
		_slider(c, "Cintura", "ws", float(_feat.get("waist", 0.4)), 0.0, 1.0, ["bem fina", "fina", "média", "reta"])
		_slider(c, "Quadril", "hp", float(_feat.get("hips", 0.5)), 0.0, 1.0, ["estreito", "médio", "largo", "bem largo"])
	_slider(c, "Músculos", "ms", float(_f.look.get("ms", 0.5)), 0.1, 1.0, ["leves", "definidos", "fortes", "muito fortes"])
	_slider(c, "Gordura", "bf", float(_f.look.get("bf", 0.15)), 0.04, 0.5, ["mínima", "baixa", "média", "alta"])
	if not fem:
		_slider(c, "Trapézio e pescoço", "tr", float(_f.look.get("tr", 0.0)), 0.0, 1.0, ["normal", "forte", "de wrestler", "de touro"])
	var tt := clampi(int(_f.look.get("tt", 0)), 0, 3)
	c.add_child(_title("Tatuagens", ["Nenhuma", "Um ombro", "Ombros e peito", "Manga fechada"][tt]))
	c.add_child(UIKit.segment(TATTOO_OPTS, str(tt), func(k: String): _put("tt", int(k))))


# --- Peças ------------------------------------------------------------------------------------

## Título de um grupo com o valor atual ao lado ("Batom · Vermelho").
func _title(text: String, value: String = "", keep: bool = false) -> Control:
	var h := UIKit.hbox(10)
	h.add_child(UIKit.label(text, "H3"))
	var v := UIKit.label(value, "Small")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.clip_text = true
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(v)
	if keep:
		_sel_label = v
	return h


func _swatches(c: VBoxContainer, title: String, names: Array, colors: Array, cur: int, key: String) -> void:
	c.add_child(_title(title, String(names[clampi(cur, 0, names.size() - 1)])))
	var fl := UIKit.flow(4)
	for i in colors.size():
		var s := Swatch.new(colors[i], i == cur)
		s.tooltip_text = String(names[i])
		s.pressed.connect(func():
			Sfx.play("tab", -6.0)
			_put(key, i))
		fl.add_child(s)
	c.add_child(fl)


## Linha "nome ‹ valor ›": passa pelos tipos (formato do rosto, nariz, boca...).
func _stepper(card: VBoxContainer, title: String, key: String, names: Array, cur: int) -> void:
	var n := names.size()
	cur = clampi(cur, 0, n - 1)
	var h := UIKit.hbox(6)
	h.custom_minimum_size.y = 64
	var t := UIKit.label(title, "Muted")
	t.custom_minimum_size.x = 150
	t.clip_text = true
	h.add_child(t)
	var prev := UIKit.icon_button("back", func(): _put(key, (cur - 1 + n) % n), "Anterior")
	prev.custom_minimum_size = Vector2(56, 56)
	h.add_child(prev)
	var v := UIKit.label(String(names[cur]), "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.clip_text = true
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(v)
	var next := UIKit.icon_button("forward", func(): _put(key, (cur + 1) % n), "Próximo")
	next.custom_minimum_size = Vector2(56, 56)
	h.add_child(next)
	card.add_child(h)


## Barra de ajuste contínuo (beleza, busto, cintura...). O retrato acompanha enquanto arrasta.
func _slider(c: VBoxContainer, title: String, key: String, cur: float, lo: float, hi: float, words: Array) -> void:
	var v := UIKit.vbox(0)
	var word := func(x: float) -> String:
		var t := clampf((x - lo) / (hi - lo), 0.0, 0.999)
		return String(words[int(t * words.size())])
	var head := _title(title, word.call(cur))
	var val := head.get_child(1) as Label
	v.add_child(head)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 40.0
	s.value = clampf(cur, lo, hi)
	s.custom_minimum_size.y = 52
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.add_theme_icon_override(&"grabber", _grab())
	s.add_theme_icon_override(&"grabber_highlight", _grab())
	s.value_changed.connect(func(x: float):
		val.text = word.call(x)
		_put(key, snappedf(x, 0.01), false))
	v.add_child(s)
	c.add_child(v)


## Botão redondo da barra (o do tema padrão é pequeno demais para o dedo).
static func _grab() -> Texture2D:
	if _grabber == null:
		var n := 36
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var ctr := Vector2(n, n) * 0.5 - Vector2(0.5, 0.5)
		for y in n:
			for x in n:
				var d := Vector2(x, y).distance_to(ctr)
				var a := clampf(n * 0.5 - 1.0 - d, 0.0, 1.0)
				var col := UIColors.TEXT.lerp(UIColors.ACCENT, smoothstep(n * 0.5 - 6.0, n * 0.5 - 4.0, d))
				img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
		_grabber = ImageTexture.create_from_image(img)
	return _grabber


## Grade de miniaturas: o próprio rosto com cada opção de `key` (penteado ou barba). Os retratos
## entram aos poucos (uns por quadro) para a aba abrir na hora mesmo com dezenas deles.
func _thumbs(c: VBoxContainer, key: String, ids: Array, names: Array, cur: int) -> void:
	var cw := content_width()
	var cols := maxi(4, int(cw / 150.0))
	var tw := floorf((cw - TILE_SEP * (cols - 1)) / cols)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override(&"h_separation", TILE_SEP)
	grid.add_theme_constant_override(&"v_separation", TILE_SEP)
	_tile_key = key
	for id: int in ids:
		var b := Button.new()
		b.custom_minimum_size = Vector2(tw, tw + TILE_LABEL_H)
		b.focus_mode = Control.FOCUS_ALL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.clip_contents = true
		_tile_style(b, id == cur)
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2(4, 4)
		holder.size = Vector2(tw - 8, tw - 8)
		holder.clip_contents = true
		b.add_child(holder)
		var l := UIKit.label(String(names[id]), "Caps")
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.max_lines_visible = 2
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_constant_override(&"line_spacing", -2)
		l.add_theme_color_override(&"font_color", UIColors.TEXT if id == cur else UIColors.MUTED)
		l.position = Vector2(4, tw - 2)
		l.size = Vector2(tw - 8, TILE_LABEL_H)
		b.add_child(l)
		b.pressed.connect(func():
			Sfx.play("tab", -6.0)
			_pick(key, id, String(names[id])))
		grid.add_child(b)
		_tiles[id] = b
		var lk := _f.look.duplicate()
		lk[key] = id
		_pending.append([holder, lk])
	c.add_child(grid)


func _tile_style(b: Button, on: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.SURFACE_2 if on else UIColors.SURFACE
	sb.set_corner_radius_all(UITokens.CUT)
	sb.corner_detail = 1
	sb.set_border_width_all(2)
	sb.border_color = UIColors.ACCENT if on else UIColors.LINE
	for st: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, sb)


## Escolha numa grade de miniaturas: troca o destaque sem refazer a grade (as miniaturas são as
## mesmas, só o retrato grande muda).
func _pick(key: String, id: int, name: String) -> void:
	for k: int in _tiles:
		var b := _tiles[k] as Button
		if is_instance_valid(b):
			_tile_style(b, k == id)
			(b.get_child(1) as Label).add_theme_color_override(&"font_color", UIColors.TEXT if k == id else UIColors.MUTED)
	if _sel_label != null and is_instance_valid(_sel_label):
		_sel_label.text = name
	_put(key, id, false)


func _process(_dt: float) -> void:
	var n := 0
	var w := world()
	var t := w.team(_f.team_id)
	while not _pending.is_empty() and n < 8:
		var it: Array = _pending.pop_front()
		var holder := it[0] as Control
		if not is_instance_valid(holder):
			continue
		# Miniatura em imagem (feita fora da tela e guardada na memória): trinta retratos vivos,
		# redesenhados a cada quadro, deixavam o editor pesado.
		var p := Portrait.new()
		p.cutout = true
		# Retrato maior que o quadro, cortado em volta do que importa: cabelo e ombros no penteado,
		# do nariz ao queixo na barba.
		var beard := _tile_key == "bd"
		var z := 1.9 if beard else 1.45
		p.setup({"seed": _f.face_seed, "eth": _f.eth, "age": w.age_of(_f), "look": it[1],
			"trim": t.color1 if t != null else Color("#C8102E"), "temp": true}, 220 if beard else 150)
		p.custom_minimum_size = Vector2.ZERO
		p.size = holder.size * z
		p.position = Vector2(-(z - 1.0) * 0.5 * holder.size.x, -holder.size.y * z * (0.15 if beard else 0.03))
		holder.add_child(p)
		n += 1
	if _pending.is_empty():
		set_process(false)


func _suggested(fem: bool) -> Array:
	if not fem:
		return MALE_HAIR.duplicate()
	# Elas: os penteados que o gerador usa, primeiro os do tipo de fio dela, depois os outros.
	var tex := clampi(int(_feat.get("texture", 0)), 0, FaceGen.FEM_STYLE_W.size() - 1)
	var out: Array = []
	var order := [tex]
	for t in FaceGen.FEM_STYLE_W.size():
		if t != tex:
			order.append(t)
	for t: int in order:
		var tab: Dictionary = FaceGen.FEM_STYLE_W[t]
		var ks := tab.keys()
		ks.sort_custom(func(a: int, b: int) -> bool: return float(tab[a]) > float(tab[b]))
		for k: int in ks:
			if not out.has(k):
				out.append(k)
	return out


static func _hair_cat_of(i: int) -> String:
	var n := FaceGen.HAIR_STYLES[i].to_lower()
	var has := func(words: Array) -> bool:
		for wd: String in words:
			if n.contains(wd):
				return true
		return false
	if has.call(["raspado", "careca", "máquina", "buzz", "militar"]):
		return "raspado"
	if has.call(["trança", "nagô", "dread", "locs", "twist", "box braids", "freeform", "tufinhos"]):
		return "tranca"
	if has.call(["coque", "rabo", "preso", "puff", "samurai", "rabinho"]):
		return "preso"
	if has.call(["longo", "longa", "ombro", "chanel", "surfista", "wolf", "mullet", "flow", "até a nuca"]):
		return "longo"
	if has.call(["cach", "afro", "black power", "cresp", "esponja", "high top", "waves", "blowout", "frohawk", "permanente", "flat top"]):
		return "cacho"
	if has.call(["médio", "ondulado", "franja", "cortina", "tigela", "repartido", "desarrumado"]):
		return "medio"
	return "curto"
