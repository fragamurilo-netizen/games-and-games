class_name PortraitService
extends Node
## Fotos dos lutadores (Game Design Bible §5). Não há segundo gerador de rostos:
## o retrato usa o mesmo `drawFace` e catálogo do Fight Studio (estilo ilustrado
## `STYLE` da biblioteca), rodando num WebView invisível com os scripts originais
## extraídos de studio.cobundle. Cada PNG
## volta pela ponte do WebView e fica em cache (memória + user://portraits/).
## Android: plugin CornerOfficeStudio (render_portraits). Desktop: godot_wry.
## Sem WebView (headless, testes) a UI mostra as iniciais.

signal portrait_ready(key: String)

const W := 192
const H := 240
const STYLE := "flat"      # estilo de identity.js (STYLES); mudar invalida o cache
const CACHE_DIR := "user://portraits"
const BATCH := 24
const SHEET := "res://presentation/portraits/portrait_sheet.js"
const BUNDLE := "res://presentation/fight/studio.cobundle"

static var _instance: PortraitService

var _textures := {}      # key -> Texture2D
var _queue := {}         # key -> payload aguardando render
var _inflight := {}      # key -> true no lote atual
var _bridge: Object
var _web: Control
var _scripts := ""       # scripts do Fight Studio (sem o shell da transmissão)


## Instância única, criada sob demanda e presa à raiz da árvore.
static func service() -> PortraitService:
	if _instance == null or not is_instance_valid(_instance):
		_instance = PortraitService.new()
		_instance.name = "PortraitService"
		var tree := Engine.get_main_loop() as SceneTree
		if tree: tree.root.add_child.call_deferred(_instance)
	return _instance


## Mesmos campos que FightReplayBuilder entrega ao Fight Studio.
static func payload(f: Fighter) -> Dictionary:
	var profiles: Dictionary = ContentDB.load_json("combat_profiles.json").get("fighters", {})
	return {"name": f.first_name + " " + f.last_name, "sex": f.sex, "appearance": f.appearance.duplicate(true),
		"appearance_index": profiles.get(f.id, {}).get("appearance_index", null)}


## Chave estável: muda só quando a aparência muda.
static func key_for(f: Fighter) -> String:
	var p := payload(f)
	p.erase("name")
	p.style = STYLE; p.size = [W, H]; p.frame = 2
	return "%08x" % (hash(JSON.stringify(p, "", true)) & 0xffffffff)


static func initials(f: Fighter) -> String:
	var a := f.first_name.left(1) if not f.first_name.is_empty() else ""
	var b := f.last_name.left(1) if not f.last_name.is_empty() else ""
	return (a + b).to_upper()


## Textura pronta, ou null (e o retrato entra na fila; `portrait_ready` avisa).
func texture_for(f: Fighter) -> Texture2D:
	var key := key_for(f)
	if _textures.has(key): return _textures[key]
	var path := "%s/%s.png" % [CACHE_DIR, key]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img:
			_textures[key] = ImageTexture.create_from_image(img)
			return _textures[key]
	if not _inflight.has(key) and available():
		_queue[key] = payload(f)
		_flush.call_deferred()
	return null


## Há um WebView capaz de desenhar nesta plataforma?
static func available() -> bool:
	if OS.get_name() == "Android": return Engine.has_singleton("CornerOfficeStudio") and Engine.get_singleton("CornerOfficeStudio").has_method("render_portraits")
	return ClassDB.class_exists("WebView") and DisplayServer.get_name() != "headless"


## Recebe um PNG em data URL, grava no cache e avisa a UI.
func accept(key: String, data_url: String) -> bool:
	_inflight.erase(key)
	var comma := data_url.find(",")
	if not data_url.begins_with("data:image/png;base64,") or comma < 0: return false
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(data_url.substr(comma + 1))) != OK: return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
	img.save_png(ProjectSettings.globalize_path("%s/%s.png" % [CACHE_DIR, key]))
	_textures[key] = ImageTexture.create_from_image(img)
	portrait_ready.emit(key)
	return true


## HTML do lote: scripts originais do Fight Studio + portrait_sheet.js.
func sheet_html(jobs: Array) -> String:
	if _scripts.is_empty():
		var packed := FileAccess.get_file_as_bytes(BUNDLE)
		if packed.is_empty(): return ""
		var studio := packed.decompress_dynamic(16000000, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
		var re := RegEx.create_from_string("<script>([\\s\\S]*?)</script>")
		for m in re.search_all(studio):
			var code := m.get_string(1)
			if code.begins_with("/* Fight Night broadcast shell"): continue
			_scripts += "<script>" + code + "</script>"
	var sheet := FileAccess.get_file_as_string(SHEET).replace("__CO_PORTRAIT_W__", str(W)).replace("__CO_PORTRAIT_H__", str(H)).replace("__CO_PORTRAIT_STYLE__", STYLE)
	var data := JSON.stringify(jobs).replace("<", "\\u003c")
	return "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>" + _scripts \
		+ "<script id=\"co-portraits\" type=\"application/json\">" + data + "</script><script>" \
		+ sheet.replace("</script", "<\\/script") + "</script></body></html>"


func _flush() -> void:
	if not _inflight.is_empty() or _queue.is_empty(): return
	var jobs: Array = []
	for key: String in _queue.keys().slice(0, BATCH):
		jobs.append({"key": key, "fighter": _queue[key]})
		_inflight[key] = true
		_queue.erase(key)
	var html := sheet_html(jobs)
	if html.is_empty(): _inflight.clear(); return
	if OS.get_name() == "Android": _render_android(html)
	else: _render_desktop(html)


func _render_android(html: String) -> void:
	if _bridge == null:
		_bridge = Engine.get_singleton("CornerOfficeStudio")
		_bridge.connect("portrait", func(key: String, png: String): accept(key, png))
		_bridge.connect("portraits_done", _on_done)
	_bridge.render_portraits(html)


func _render_desktop(html: String) -> void:
	if _web: _web.queue_free()
	_web = ClassDB.instantiate("WebView")
	_web.set("full_window_size", false)
	_web.set("transparent", true)
	_web.set("html", html)
	_web.set("forward_input_events", false)
	_web.position = Vector2(-4, -4)
	_web.size = Vector2(2, 2)
	_web.connect("ipc_message", _on_ipc)
	add_child(_web)


func _on_ipc(message: String) -> void:
	var data: Variant = JSON.parse_string(message)
	if typeof(data) != TYPE_DICTIONARY: return
	if data.get("type") == "portrait": accept(str(data.key), str(data.png))
	elif data.get("type") == "done": _on_done()


func _on_done() -> void:
	# Chaves que o lote não devolveu (erro de desenho) ficam com as iniciais.
	_inflight.clear()
	if _web: _web.queue_free(); _web = null
	_flush()
