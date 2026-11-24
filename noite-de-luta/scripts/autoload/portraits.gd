extends Node
## Retratos em textura. O PortraitView desenha cada rosto com dezenas de milhares de triângulos e
## leva de 90 a 180 ms para montar um (várias vezes isso em celular fraco); posto direto na tela,
## ele travava a abertura das listas e pesava em cada quadro da rolagem. Aqui cada retrato é
## montado uma vez, fora da tela e em outra thread, vira uma imagem e fica guardado na memória e
## em disco. As telas mostram a imagem com o `Portrait` (um quadrilátero).
##
## Caminho de um pedido: memória → arquivo em `user://cache/retratos` → montar (thread) e
## fotografar num SubViewport (thread principal, um ou dois por quadro) → gravar o arquivo.

## Muda quando o desenho do retrato muda (os arquivos antigos deixam de valer).
const VERSION := 3
const DIR := "user://cache/retratos"
## Tamanhos guardados: [lado em que o retrato é montado, lado da textura].
const SIZES := [[64, 144], [112, 256], [220, 512]]
## Memória de textura que os retratos podem ocupar.
const BUDGET := 80 * 1024 * 1024
## Arquivos guardados em disco antes de apagar os mais antigos.
const DISK_MAX := 4000
const RENDERS_PER_FRAME := 2

class Job:
	var key := 0
	var bucket := 0
	var frame := 0
	var seq := 0
	var want := 0
	var keep := false
	var pv: PortraitView
	var layers: Array = []
	var image: Image
	var save := false
	var path := ""
	## Retrato de passagem (as miniaturas do editor de visual): não vai para o disco.
	var temp := false

var _mem: Dictionary = {} # chave -> [textura, bytes]
var _order: Array = [] # chaves, da menos para a mais recente
var _bytes := 0
var _jobs: Dictionary = {} # chave -> Job (pedidos em andamento)
var _waiters: Dictionary = {} # chave -> Array de Portrait
var _threads: Array = []
var _sem := Semaphore.new()
var _lock := Mutex.new()
var _queue: Array = [] # esperando uma thread
var _done: Array = [] # prontos para a thread principal
var _exit := false
var _seq := 0
var _rendering := 0
var _disk_ok := false
## Contadores para as sondas de desempenho.
var made := 0
var loaded := 0
var read_ms := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	# As tabelas preguiçosas do gerador nascem aqui, antes de qualquer thread precisar delas.
	FaceGen.features(1, 1, 25, {})
	_disk_ok = DirAccess.make_dir_recursive_absolute(DIR) == OK or DirAccess.dir_exists_absolute(DIR)
	var n := 2 if OS.get_processor_count() >= 4 else 1
	for i in n:
		var t := Thread.new()
		t.start(_worker)
		_threads.append(t)
	if _disk_ok:
		WorkerThreadPool.add_task(_trim_disk, false, "retratos: limpar cache")


func _exit_tree() -> void:
	_exit = true
	for t: Thread in _threads:
		_sem.post()
	for t: Thread in _threads:
		t.wait_to_finish()
	_threads.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_OS_MEMORY_WARNING:
		_trim_mem(BUDGET / 4)


## Qual dos tamanhos guardados serve para um retrato de `px` na tela.
static func bucket_for(px: int) -> int:
	if px <= 84:
		return 0
	if px <= 150:
		return 1
	return 2


## O que identifica um retrato: {seed, eth, age, look, trim, suit, accent}.
static func spec_of(w: GameWorld, f: Fighter) -> Dictionary:
	var t := w.team(f.team_id) if w != null else null
	return {"seed": f.face_seed, "eth": f.eth, "age": w.age_of(f) if w != null else 28, "look": f.look,
		"trim": t.color1 if t != null else Color("#C8102E")}


static func key_of(spec: Dictionary, bucket: int) -> int:
	return hash([VERSION, bucket, int(spec.get("seed", 0)), int(spec.get("eth", 0)), int(spec.get("age", 0)), spec.get("look", {}),
		bool(spec.get("suit", false)), spec.get("trim", Color.BLACK), spec.get("accent", Color.BLACK)])


## A textura, se já estiver na memória.
func texture(key: int) -> Texture2D:
	if not _mem.has(key):
		return null
	if _order.is_empty() or int(_order.back()) != key:
		_order.erase(key)
		_order.append(key)
	return _mem[key][0]


## Pede um retrato para mostrar em `who` (um Portrait). Devolve a chave; a textura chega por
## `who._on_texture` quando não estava na memória.
func want(spec: Dictionary, px: int, who: Object = null) -> int:
	var bucket := bucket_for(px)
	var key := key_of(spec, bucket)
	if _mem.has(key):
		return key
	if who != null:
		if not _waiters.has(key):
			_waiters[key] = []
		(_waiters[key] as Array).append(who)
	var job: Job = _jobs.get(key)
	_lock.lock()
	if job != null:
		job.want += 1 if who != null else 0
		job.keep = job.keep or who == null
		job.frame = maxi(job.frame, Engine.get_process_frames() if who != null else 0)
		_lock.unlock()
		return key
	job = Job.new()
	job.key = key
	job.bucket = bucket
	job.want = 1 if who != null else 0
	job.keep = who == null
	job.frame = Engine.get_process_frames() if who != null else 0
	_seq += 1
	job.seq = _seq
	job.path = "%s/%d.webp" % [DIR, key]
	job.temp = bool(spec.get("temp", false))
	job.pv = _view(spec, int(SIZES[bucket][0]))
	_jobs[key] = job
	_queue.append(job)
	_lock.unlock()
	_sem.post()
	set_process(true)
	return key


## Quem pediu saiu da tela antes de o retrato ficar pronto.
func release(key: int, who: Object) -> void:
	if _waiters.has(key):
		var lst: Array = _waiters[key]
		lst.erase(who)
		if lst.is_empty():
			_waiters.erase(key)
	var job: Job = _jobs.get(key)
	if job != null:
		_lock.lock()
		job.want = maxi(0, job.want - 1)
		_lock.unlock()


## Deixa prontos, sem pressa, retratos que o jogador deve ver logo (a equipe, os campeões).
func prewarm(w: GameWorld, fighters: Array, px: int = 72) -> void:
	for f: Fighter in fighters:
		if f != null:
			want(spec_of(w, f), px)


## Retratos (e cabeças das figuras de corpo inteiro) ainda sendo feitos em segundo plano.
func pending() -> int:
	return _jobs.size() + BodyView.pending + PortraitView.async_pending


func _view(spec: Dictionary, logical: int) -> PortraitView:
	var v := PortraitView.new()
	v.stage = false
	v.size = Vector2(logical, logical)
	if bool(spec.get("suit", false)):
		v.fight_body = false
		v.set_person(int(spec.get("seed", 1)), int(spec.get("eth", 1)), int(spec.get("age", 40)), spec.get("accent", Color("#C8102E")), spec.get("look", {}))
	else:
		v.gear_trim = spec.get("trim", Color("#C8102E"))
		v.set_face(int(spec.get("seed", 1)), int(spec.get("eth", 1)), int(spec.get("age", 28)), spec.get("look", {}))
	return v


# ---------------------------------------------------------------------------
# Threads
# ---------------------------------------------------------------------------

func _worker() -> void:
	while true:
		_sem.wait()
		if _exit:
			return
		_lock.lock()
		var job := _pick()
		_lock.unlock()
		if job == null:
			continue
		if job.save:
			if job.image != null:
				job.image.save_webp(job.path, true, 0.92)
			continue
		if job.want > 0 or job.keep:
			if _disk_ok and FileAccess.file_exists(job.path):
				var img := Image.load_from_file(job.path)
				if img != null and not img.is_empty() and img.get_width() == int(SIZES[job.bucket][1]):
					job.image = img
			if job.image == null:
				job.layers = job.pv.build_layers()
		_lock.lock()
		_done.append(job)
		_lock.unlock()


## O pedido mais recente primeiro e, dentro do mesmo quadro, na ordem em que a tela pediu (de
## cima para baixo). Gravar em disco fica para quando não há retrato esperando.
func _pick() -> Job:
	var best := -1
	for i in _queue.size():
		var j: Job = _queue[i]
		if j.save:
			if best < 0:
				best = i
			continue
		if best < 0 or (_queue[best] as Job).save:
			best = i
			continue
		var b: Job = _queue[best]
		var ja := j.want > 0
		var ba := b.want > 0
		if ja != ba:
			if ja:
				best = i
			continue
		if j.frame > b.frame or (j.frame == b.frame and j.seq < b.seq):
			best = i
	if best < 0:
		return null
	var out: Job = _queue[best]
	_queue.remove_at(best)
	return out


func _trim_disk() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	var files := d.get_files()
	if files.size() <= DISK_MAX:
		return
	var rows: Array = []
	for name in files:
		rows.append([FileAccess.get_modified_time(DIR + "/" + name), name])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	for i in rows.size() - DISK_MAX * 3 / 4:
		d.remove(String(rows[i][1]))


# ---------------------------------------------------------------------------
# Thread principal
# ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if _jobs.is_empty() and _rendering == 0:
		set_process(false)
		return
	var room := RENDERS_PER_FRAME - _rendering
	while true:
		_lock.lock()
		var job: Job = null
		for i in _done.size():
			var j: Job = _done[i]
			if j.image != null or j.layers.is_empty() or room > 0:
				job = j
				_done.remove_at(i)
				break
		_lock.unlock()
		if job == null:
			break
		if job.image != null:
			loaded += 1
			_finish(job, job.image, false)
		elif job.layers.is_empty():
			# Ninguém mais queria: o pedido some sem custo.
			_drop(job)
		else:
			room -= 1
			_render(job)


func _drop(job: Job) -> void:
	_jobs.erase(job.key)
	if is_instance_valid(job.pv):
		job.pv.free()
	job.pv = null
	if _waiters.has(job.key):
		# Alguém voltou a pedir enquanto o pedido era descartado: recomeça.
		var lst: Array = (_waiters[job.key] as Array).duplicate()
		_waiters.erase(job.key)
		for who in lst:
			if is_instance_valid(who):
				who.call(&"_retry")


## Fotografa o retrato montado: um SubViewport transparente desenhado uma vez.
func _render(job: Job) -> void:
	_rendering += 1
	var logical := float(SIZES[job.bucket][0])
	var px := int(SIZES[job.bucket][1])
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var r := Replayer.new()
	r.layers = job.layers
	r.size = Vector2(logical, logical)
	r.scale = Vector2(px / logical, px / logical)
	vp.add_child(r)
	add_child(vp)
	await RenderingServer.frame_post_draw
	var img: Image = null
	if is_instance_valid(vp):
		var t0 := Time.get_ticks_usec()
		img = vp.get_texture().get_image()
		read_ms += float(Time.get_ticks_usec() - t0) / 1000.0
		vp.queue_free()
	_rendering -= 1
	job.layers = []
	if img == null or img.is_empty():
		_drop(job)
		return
	made += 1
	_finish(job, img, true)


func _finish(job: Job, img: Image, fresh: bool) -> void:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	var bytes := img.get_width() * img.get_height() * 4
	_mem[job.key] = [tex, bytes]
	_order.append(job.key)
	_bytes += bytes
	_jobs.erase(job.key)
	if is_instance_valid(job.pv):
		job.pv.free()
	job.pv = null
	if _waiters.has(job.key):
		var lst: Array = _waiters[job.key]
		_waiters.erase(job.key)
		for who in lst:
			if is_instance_valid(who):
				who.call(&"_on_texture", tex)
	if fresh and _disk_ok and not job.temp:
		var s := Job.new()
		s.save = true
		s.image = img
		s.path = job.path
		_lock.lock()
		_queue.append(s)
		_lock.unlock()
		_sem.post()
	_trim_mem(BUDGET)


func _trim_mem(limit: int) -> void:
	while _bytes > limit and _order.size() > 24:
		var k: int = _order.pop_front()
		if _mem.has(k):
			_bytes -= int(_mem[k][1])
			_mem.erase(k)


## Desenha as camadas gravadas de um retrato (dentro do SubViewport).
class Replayer extends Control:
	var layers: Array = []

	func _init() -> void:
		clip_contents = true

	func _draw() -> void:
		for l: Array in layers:
			PortraitView.replay_to(self, l[1])
