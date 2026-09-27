class_name FaceCache
extends RefCounted
## Retratos prontos viram textura. Na primeira vez o PortraitView desenha ao vivo (malhas e shaders
## da pele e do cabelo) e pede uma cópia aqui: um SubViewport fora da tela desenha o mesmo retrato
## na resolução real da tela, a imagem é lida uma única vez e vira uma ImageTexture (memória) e um
## WebP em user://face_cache (disco). Depois disso o retrato é só uma textura: nenhum shader por
## pixel a cada quadro e nenhuma geração ao reabrir o jogo.
##
## A chave é o conteúdo do retrato (semente, etnia, idade, aparência, uniforme, tamanho em pixels)
## com FaceDNA.VERSION e a versão do motor: mudar o gerador invalida tudo de uma vez (as pastas de
## outras versões são apagadas). Não funciona no editor nem sem vídeo (testes headless);
## `enabled = false` força o desenho ao vivo. `hold` segura a fila (partida em andamento): os
## retratos continuam ao vivo e a fila anda depois.

static var enabled := true
static var hold := false

## Orçamento da memória: ~16 MB de textura (RGBA8).
const MEM_BUDGET_PX := 4_000_000
## Arquivos no disco: acima de DISK_MAX os mais antigos saem até sobrar DISK_KEEP.
const DISK_MAX := 600
const DISK_KEEP := 450
const WEBP_QUALITY := 0.95

static var _mem: Dictionary = {}      # chave -> ImageTexture
static var _mem_px: Dictionary = {}   # chave -> pixels
static var _lru: Array = []
static var _used_px := 0
static var _queue: Array = []         # [chave, WeakRef do retrato, px, escala]
static var _queued: Dictionary = {}
static var _missing: Dictionary = {}  # chaves que já se sabe que não estão no disco
static var _job: Array = []
static var _vp: SubViewport = null
static var _dir := ""
static var _pumping := false
static var _waiting := false
static var _tasks: Array[int] = []
static var _premult: CanvasItemMaterial = null
static var stats := {"mem": 0, "disk": 0, "rendered": 0, "live": 0}


## O cache pode ser usado agora? (jogo rodando com vídeo, fora do editor)
static func active() -> bool:
	return enabled and not Engine.is_editor_hint() and DisplayServer.get_name() != "headless"


## Textura pronta para a chave (memória, depois disco), ou null.
static func lookup(key: int) -> Texture2D:
	if _mem.has(key):
		_touch(key)
		stats["mem"] += 1
		return _mem[key]
	if _missing.has(key):
		return null
	var path := _path(key)
	if not FileAccess.file_exists(path):
		_missing[key] = true
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		_missing[key] = true
		return null
	var tex := ImageTexture.create_from_image(img)
	_store(key, tex, img.get_width() * img.get_height())
	stats["disk"] += 1
	return tex


## Pede a cópia em textura de um retrato que acabou de ser desenhado ao vivo.
static func request(view: PortraitView, key: int, px: int, scale: float) -> void:
	if _queued.has(key) or _mem.has(key) or px < 8 or px > 1024:
		return
	_queued[key] = true
	_queue.append([key, weakref(view), px, scale])
	stats["live"] += 1
	_pump.call_deferred()


## Material para desenhar a textura: o SubViewport transparente guarda a cor já multiplicada pelo
## alfa (borda do círculo, recorte), então ela é composta como "premultiplied".
static func premult_material() -> CanvasItemMaterial:
	if _premult == null:
		_premult = CanvasItemMaterial.new()
		_premult.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	return _premult


## Esvazia a memória (o disco fica). Testes e o laboratório de rostos.
static func clear_memory() -> void:
	_mem.clear()
	_mem_px.clear()
	_lru.clear()
	_used_px = 0
	_missing.clear()


static func _path(key: int) -> String:
	if _dir == "":
		_dir = "user://face_cache/v%d_%s" % [FaceDNA.VERSION, str(hash(Engine.get_version_info()["string"])).substr(0, 6)]
		DirAccess.make_dir_recursive_absolute(_dir)
		var dir := _dir
		_tasks.append(WorkerThreadPool.add_task(func() -> void: FaceCache._tidy(dir), false, "FaceCache.tidy"))
	return "%s/%d.webp" % [_dir, key & 0x7FFFFFFFFFFFFFFF]


static func _touch(key: int) -> void:
	_lru.erase(key)
	_lru.append(key)


static func _store(key: int, tex: Texture2D, px: int) -> void:
	_mem[key] = tex
	_mem_px[key] = px
	_used_px += px
	_missing.erase(key)
	_touch(key)
	# Os retratos na tela guardam a própria referência à textura: sair daqui não os apaga
	while _used_px > MEM_BUDGET_PX and _lru.size() > 1:
		var old: int = _lru.pop_front()
		_used_px -= int(_mem_px.get(old, 0))
		_mem.erase(old)
		_mem_px.erase(old)


## Um retrato por vez: monta a cópia no SubViewport, espera um quadro (a cópia se desenha), manda
## o SubViewport pintar e lê a imagem depois que o quadro seguinte termina.
static func _pump() -> void:
	_reap()
	if _pumping or _queue.is_empty() or not active():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if hold:
		# Tenta de novo daqui a pouco, sem ocupar a partida
		if not _waiting:
			_waiting = true
			tree.create_timer(1.0).timeout.connect(func() -> void:
				FaceCache._waiting = false
				FaceCache._pump())
		return
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var view := (job[1] as WeakRef).get_ref() as PortraitView
		# O retrato mudou (outro jogador, outro tamanho) ou saiu da tela: não vale a pena
		if view == null or not is_instance_valid(view) or not view.is_inside_tree() or view.cache_key() != int(job[0]):
			_queued.erase(job[0])
			continue
		if _vp == null or not is_instance_valid(_vp):
			_vp = SubViewport.new()
			_vp.transparent_bg = true
			_vp.disable_3d = true
			_vp.gui_disable_input = true
			_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			tree.root.add_child(_vp)
		var px: int = job[2]
		var k: float = job[3]
		var clone := view.cache_clone()
		_vp.size = Vector2i(px, px)
		_vp.canvas_transform = Transform2D(0.0, Vector2(k, k), 0.0, Vector2.ZERO)
		_vp.add_child(clone)
		_job = [job[0], clone, view.get_instance_id(), int(job[4]) if job.size() > 4 else 0]
		_pumping = true
		tree.process_frame.connect(_paint, CONNECT_ONE_SHOT)
		return


static func _paint() -> void:
	if _vp == null or not is_instance_valid(_vp) or _job.is_empty():
		_pumping = false
		return
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_grab, CONNECT_ONE_SHOT)


static func _grab() -> void:
	_pumping = false
	if _job.is_empty():
		return
	var key: int = _job[0]
	var clone: Node = _job[1]
	var view_id: int = _job[2]
	var tries: int = _job[3]
	_job = []
	_queued.erase(key)
	if _vp != null and is_instance_valid(_vp):
		var img := _vp.get_texture().get_image()
		# Conferência: o centro do retrato (rosto) tem de estar pintado; senão a cópia não chegou a
		# ser desenhada e tenta de novo (uma vez) em vez de guardar um retrato vazio
		var c := _vp.size / 2
		if img != null and not img.is_empty() and img.get_pixel(c.x, c.y).a > 0.5:
			if img.get_format() != Image.FORMAT_RGBA8:
				img.convert(Image.FORMAT_RGBA8)
			_store(key, ImageTexture.create_from_image(img), img.get_width() * img.get_height())
			stats["rendered"] += 1
			var path := _path(key)
			_tasks.append(WorkerThreadPool.add_task(func() -> void: img.save_webp(path, true, WEBP_QUALITY), false, "FaceCache.save"))
		elif tries < 1:
			var v := instance_from_id(view_id) as PortraitView
			if v != null and is_instance_valid(v):
				_queued[key] = true
				_queue.push_front([key, weakref(v), _vp.size.x, _vp.canvas_transform.get_scale().x, tries + 1])
	if is_instance_valid(clone):
		clone.queue_free()
	var view := instance_from_id(view_id) as PortraitView
	if view != null and is_instance_valid(view):
		view.queue_redraw()
	# Próximo da fila no quadro seguinte (um por quadro: sem travar a rolagem)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not _queue.is_empty():
		tree.process_frame.connect(_pump, CONNECT_ONE_SHOT)


## Libera as tarefas de disco já terminadas (toda tarefa do WorkerThreadPool precisa ser esperada).
static func _reap() -> void:
	var left: Array[int] = []
	for id in _tasks:
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
		else:
			left.append(id)
	_tasks = left


## Em segundo plano: apaga pastas de versões antigas e, se passou do limite, os arquivos mais velhos.
static func _tidy(current: String) -> void:
	var root := "user://face_cache"
	for d in DirAccess.get_directories_at(root):
		var full := root + "/" + d
		if full != current:
			for f in DirAccess.get_files_at(full):
				DirAccess.remove_absolute(full + "/" + f)
			DirAccess.remove_absolute(full)
	var files := DirAccess.get_files_at(current)
	if files.size() <= DISK_MAX:
		return
	var aged: Array = []
	for f in files:
		aged.append([FileAccess.get_modified_time(current + "/" + f), f])
	aged.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for i in aged.size() - DISK_KEEP:
		DirAccess.remove_absolute(current + "/" + String(aged[i][1]))
