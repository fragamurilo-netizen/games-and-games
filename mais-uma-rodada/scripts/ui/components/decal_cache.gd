class_name DecalCache
extends RefCounted
## Texturas de estampas (escudo do clube, nome do patrocinador) desenhadas uma vez num
## SubViewport e copiadas para ImageTexture: o retrato as "imprime" no peito da camisa com a
## curvatura e a luz do tecido. Sem vídeo (testes headless) as texturas nunca ficam prontas e o
## retrato simplesmente não mostra a estampa.

const CREST_PX := 128
const TEXT_H := 72
const MAX_ENTRIES := 96

static var _entries: Dictionary = {} # chave -> {vp, tex, image, ready, aspect, waiting: Array[WeakRef]}
static var _order: Array = []
static var _by_tex: Dictionary = {} # instance_id da textura -> chave
static var _pending: Array = []
static var _hooked := false


static func crest_texture(crest: Dictionary, requester: CanvasItem) -> Texture2D:
	var key := "c" + str(hash(crest))
	if not _entries.has(key):
		var cv := CrestView.new()
		cv.crest = crest
		cv.size = Vector2(CREST_PX, CREST_PX)
		_make(key, cv, Vector2i(CREST_PX, CREST_PX), 1.0)
	return _lookup(key, requester)


static func text_texture(text: String, requester: CanvasItem) -> Texture2D:
	if text == "":
		return null
	var key := "t" + text
	if not _entries.has(key):
		var font := _font()
		var fs := 60
		var w := int(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) + 8 if font != null else text.length() * 34
		w = clampi(w, 16, 1024)
		var lbl := Label.new()
		lbl.text = text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.size = Vector2(w, TEXT_H)
		if font != null:
			lbl.add_theme_font_override(&"font", font)
		lbl.add_theme_font_size_override(&"font_size", fs)
		lbl.add_theme_color_override(&"font_color", Color.WHITE)
		_make(key, lbl, Vector2i(w, TEXT_H), float(w) / TEXT_H)
	return _lookup(key, requester)


## Logo completo da marca (BrandLogo) em branco, para o retrato imprimir na camisa com a tinta certa.
static func brand_texture(brand: Dictionary, requester: CanvasItem) -> Texture2D:
	var name := String(brand.get("n", ""))
	if name == "":
		return null
	var key := "b" + name
	if not _entries.has(key):
		var asp := clampf(BrandLogo.aspect(brand), 1.0, 8.0)
		var w := clampi(int(TEXT_H * asp) + 8, 16, 1024)
		var lc := LogoCanvas.new()
		lc.brand = brand
		lc.size = Vector2(w, TEXT_H)
		_make(key, lc, Vector2i(w, TEXT_H), float(w) / TEXT_H)
	return _lookup(key, requester)


class LogoCanvas:
	extends Control
	var brand: Dictionary = {}

	func _draw() -> void:
		BrandLogo.draw(self, brand, Rect2(Vector2.ZERO, size).grow(-2.0), Color.WHITE)


## Volta do segundo plano: restaura as estampas a partir da cópia em memória, sem manter
## render targets vivos para cada clube visitado.
static func refresh() -> void:
	for e: Dictionary in _entries.values():
		if bool(e["ready"]):
			(e["tex"] as ImageTexture).update(e["image"])


## A textura já foi desenhada ao menos uma vez?
static func is_ready(tex: Texture2D) -> bool:
	if tex == null:
		return false
	var key: Variant = _by_tex.get(tex.get_instance_id())
	return key != null and _entries.has(key) and bool(_entries[key]["ready"])


static func aspect(tex: Texture2D) -> float:
	if tex == null:
		return 1.0
	var key: Variant = _by_tex.get(tex.get_instance_id())
	if key == null or not _entries.has(key):
		return float(tex.get_width()) / maxf(1.0, tex.get_height())
	return float(_entries[key]["aspect"])


static func _font() -> Font:
	var th := ThemeDB.get_project_theme()
	if th != null and th.has_font(&"font", &"Big"):
		return th.get_font(&"font", &"Big")
	return ThemeDB.fallback_font


static func _make(key: String, content: Control, px: Vector2i, asp: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		content.free()
		return
	var vp := SubViewport.new()
	vp.size = px
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(content)
	# Um pedido feito dentro de _draw só entra na árvore depois. Não capturar o quadro
	# anterior à entrada: isso marcava texturas ainda vazias como prontas.
	if DisplayServer.get_name() != "headless":
		vp.tree_entered.connect(_schedule.bind(key), CONNECT_ONE_SHOT)
	tree.root.add_child.call_deferred(vp)
	# O cache de comandos do PortraitView retém esta textura mesmo após a expulsão
	# da entrada. Uma ViewportTexture ficava inválida quando o viewport era liberado.
	var tex := ImageTexture.new()
	_entries[key] = {"vp": vp, "tex": tex, "image": null, "ready": false, "aspect": asp, "waiting": []}
	_by_tex[tex.get_instance_id()] = key
	_order.append(key)
	while _order.size() > MAX_ENTRIES:
		var old: String = _order.pop_front()
		var e: Dictionary = _entries.get(old, {})
		if not e.is_empty():
			_by_tex.erase((e["tex"] as Texture2D).get_instance_id())
			if is_instance_valid(e["vp"]):
				(e["vp"] as SubViewport).queue_free()
		_entries.erase(old)


static func _lookup(key: String, requester: CanvasItem) -> Texture2D:
	if not _entries.has(key):
		return null
	var e: Dictionary = _entries[key]
	if not bool(e["ready"]) and requester != null:
		(e["waiting"] as Array).append(weakref(requester))
	return e["tex"]


## Depois do próximo quadro desenhado (quando o SubViewport já pintou a estampa), marca as
## pendentes como prontas e pede para quem as usa redesenhar. Uma única conexão atende todas.
static func _schedule(key: String) -> void:
	_pending.append(key)
	if not _hooked:
		_hooked = true
		RenderingServer.frame_post_draw.connect(_on_post_draw, CONNECT_ONE_SHOT)


static func _on_post_draw() -> void:
	_hooked = false
	var keys := _pending
	_pending = []
	for key in keys:
		if not _entries.has(key):
			continue
		var e: Dictionary = _entries[key]
		var vp := e["vp"] as SubViewport
		if not is_instance_valid(vp) or not vp.is_inside_tree() or vp.is_queued_for_deletion():
			continue
		var img := vp.get_texture().get_image()
		if img == null or img.is_empty():
			continue
		(e["tex"] as ImageTexture).set_image(img)
		e["image"] = img
		e["ready"] = true
		e["vp"] = null
		vp.queue_free()
		for w: WeakRef in e["waiting"]:
			var ci := w.get_ref() as CanvasItem
			if ci != null and is_instance_valid(ci):
				ci.queue_redraw()
		(e["waiting"] as Array).clear()
