class_name Face3DStudio
extends Node
## Estúdio de retratos 3D: uma cena escondida (SubViewport com câmera e luz de estúdio) que monta o
## busto do jogador (malha do MakeHuman deformada pelos ~220 alvos, pele procedural, cabelo, barba e
## sobrancelhas procedurais, olhos, camisa do clube), fotografa uma vez e guarda a foto em memória e
## em disco (user://face3d/). O PortraitView pede com `request()`; até a foto ficar pronta ele
## desenha o retrato 2D.

const VERSION := 3
const PX := 448
const MEM_MAX := 260
const DISK_DIR := "user://face3d/"
const SCALP_LAYERS := 22
const BEARD_LAYERS := 12

static var _inst: Face3DStudio = null
static var _mem := {}
static var _mem_order: Array = []
static var enabled := true
## Qualidade das mechas (1 = cheio; celulares fracos podem usar menos).
static var quality := 1.0

var _vp: SubViewport
var _kit_vp: SubViewport
var _kit_view: KitView
var _rig: Node3D
var _mi := {}
var _mats := {}
var _scalp: Array = []
var _beard: Array = []
var _queue: Array = []
var _waiting := {}
var _busy := false


## Foto pronta (ou null, e aí entra na fila). `who` é redesenhado quando a foto ficar pronta.
static func request(spec: Dictionary, who: CanvasItem) -> Texture2D:
	if not enabled or not Face3DKit.available() or DisplayServer.get_name() == "headless":
		return null
	var key := key_of(spec)
	if _mem.has(key):
		return _mem[key]
	var disk := DISK_DIR + "%d.webp" % key
	if FileAccess.file_exists(disk):
		var img := Image.load_from_file(disk)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			var tex := ImageTexture.create_from_image(img)
			_remember(key, tex)
			return tex
	var st := _studio()
	if st == null:
		return null
	if not st._waiting.has(key):
		st._waiting[key] = []
		st._queue.append([key, spec])
	if who != null:
		(st._waiting[key] as Array).append(weakref(who))
	return null


static func key_of(spec: Dictionary) -> int:
	return hash([VERSION, spec.get("seed", 0), spec.get("eth", 0), spec.get("age", 0), spec.get("look", {}),
		spec.get("kit", {}), spec.get("crest", {}), spec.get("suit", false), spec.get("shirt", Color.WHITE), spec.get("trim", Color.WHITE)])


static func _remember(key: int, tex: Texture2D) -> void:
	_mem[key] = tex
	_mem_order.append(key)
	if _mem_order.size() > MEM_MAX:
		_mem.erase(_mem_order.pop_front())


static func _studio() -> Face3DStudio:
	if _inst != null and is_instance_valid(_inst):
		return _inst
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	_inst = Face3DStudio.new()
	_inst.name = "Face3DStudio"
	tree.root.add_child.call_deferred(_inst)
	return _inst


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.size = Vector2i(PX, PX)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_kit_vp = SubViewport.new()
	_kit_vp.size = Vector2i(512, 512)
	_kit_vp.transparent_bg = true
	_kit_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_kit_view = KitView.new()
	_kit_view.size = Vector2(512, 512)
	_kit_vp.add_child(_kit_view)
	add_child(_kit_vp)
	_rig = Node3D.new()
	_vp.add_child(_rig)
	_build_stage()


func _build_stage() -> void:
	var cam := Camera3D.new()
	cam.fov = 20.0
	cam.position = Vector3(0.0, 0.79, 1.18)
	cam.rotation = Vector3(deg_to_rad(-1.5), 0.0, 0.0)
	cam.current = true
	_vp.add_child(cam)
	# Luz de retrato: principal suave e quente (de cima, à esquerda do jogador), preenchimento frio
	# fraco, dois recortes (separam cabelo e ombros do fundo) e rebatida quente de baixo.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30.0, -35.0, 0.0)
	key.light_energy = 0.95
	key.light_color = Color(1.0, 0.95, 0.88)
	_vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, 50.0, 0.0)
	fill.light_energy = 0.3
	fill.light_color = Color(0.82, 0.88, 1.0)
	_vp.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	rim.light_energy = 0.75
	rim.light_color = Color(1.0, 0.97, 0.92)
	_vp.add_child(rim)
	var rim2 := DirectionalLight3D.new()
	rim2.rotation_degrees = Vector3(-15.0, -150.0, 0.0)
	rim2.light_energy = 0.35
	rim2.light_color = Color(0.85, 0.9, 1.0)
	_vp.add_child(rim2)
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(35.0, 10.0, 0.0)
	bounce.light_energy = 0.12
	bounce.light_color = Color(1.0, 0.85, 0.7)
	_vp.add_child(bounce)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	e.tonemap_exposure = 1.0
	env.environment = e
	_vp.add_child(env)
	for k in ["body", "hair", "beardc", "brows", "eyes", "lashes", "shirt"]:
		var mi := MeshInstance3D.new()
		_rig.add_child(mi)
		_mi[k] = mi
	var skin := ShaderMaterial.new()
	skin.shader = load("res://scripts/ui/face3d/skin.gdshader")
	skin.set_shader_parameter("pores", Face3DKit.texture("pores.png"))
	_mats["body"] = skin
	for k in ["hair", "beardc", "brows", "lashes"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://scripts/ui/face3d/hair.gdshader")
		_mats[k] = m
	var eyes := ShaderMaterial.new()
	eyes.shader = load("res://scripts/ui/face3d/eye.gdshader")
	eyes.set_shader_parameter("tex", Face3DKit.texture("eye_brown.png"))
	_mats["eyes"] = eyes
	var shirt := ShaderMaterial.new()
	shirt.shader = load("res://scripts/ui/face3d/shirt.gdshader")
	shirt.set_shader_parameter("kit_tex", _kit_vp.get_texture())
	_mats["shirt"] = shirt
	for k in _mi:
		(_mi[k] as MeshInstance3D).material_override = _mats[k]
	var shell_sh: Shader = load("res://scripts/ui/face3d/shell.gdshader")
	var fur := Face3DKit.texture("fur.png")
	for i in SCALP_LAYERS + BEARD_LAYERS:
		var mi := MeshInstance3D.new()
		var m := ShaderMaterial.new()
		m.shader = shell_sh
		m.set_shader_parameter("fur", fur)
		m.render_priority = i
		mi.material_override = m
		_rig.add_child(mi)
		if i < SCALP_LAYERS:
			_scalp.append(mi)
		else:
			_beard.append(mi)


func _process(_delta: float) -> void:
	if _busy or _queue.is_empty():
		return
	_busy = true
	var job: Array = _queue.pop_front()
	_shoot(int(job[0]), job[1])


func _shoot(key: int, spec: Dictionary) -> void:
	var box := {}
	var tid := WorkerThreadPool.add_task(func() -> void: box["d"] = Face3DStudio.prepare(spec))
	while not WorkerThreadPool.is_task_completed(tid):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(tid)
	if not box.has("d"):
		_busy = false
		return
	_apply(spec, box["d"])
	# o uniforme (2D) primeiro; a foto 3D usa essa textura no quadro seguinte
	_kit_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.generate_mipmaps()
		var tex := ImageTexture.create_from_image(img)
		_remember(key, tex)
		DirAccess.make_dir_recursive_absolute(DISK_DIR)
		img.save_webp(DISK_DIR + "%d.webp" % key, true, 0.92)
	for wr: WeakRef in _waiting.get(key, []):
		var ci: Variant = wr.get_ref()
		if ci != null and is_instance_valid(ci):
			(ci as CanvasItem).queue_redraw()
	_waiting.erase(key)
	_busy = false


## Monta o busto do jogador (público para as ferramentas de prévia).
func setup(spec: Dictionary) -> void:
	_apply(spec, prepare(spec))


## Parte pesada (CPU, sem tocar na cena): pode rodar numa thread.
static func prepare(spec: Dictionary) -> Dictionary:
	var sd := int(spec.get("seed", 0))
	var f: Dictionary = FaceGen.features(sd, int(spec.get("eth", 1)), int(spec.get("age", 25)), spec.get("look", {}))
	var L := Face3DLook.build(f, sd)
	if OS.get_environment("F3D_ZEROW") != "":
		L["weights"] = {}
	var bp := Face3DKit.body_positions(L["weights"])
	var d := {"L": L}
	d["body"] = Face3DKit.body_mesh(bp)
	var field := Face3DHair.head_field(bp)
	d["hair"] = Face3DHair.build_hair(L["style"], bp, field, L["hp"], sd, quality)
	d["beardc"] = Face3DHair.build_beard(L["beard"], bp, field, sd + 7, quality, float(L["beard_curly"]))
	d["brows"] = Face3DHair.build_brows(L["brow_shape"], bp, field, sd + 11, L["brow_var"])
	d["lashes"] = Face3DKit.proxy_mesh("lashes", bp)
	d["eyes"] = Face3DKit.proxy_mesh("eyes", bp)
	d["shirt"] = Face3DKit.proxy_mesh("shirt", bp)
	return d


func _apply(spec: Dictionary, d: Dictionary) -> void:
	var sd := int(spec.get("seed", 0))
	var L: Dictionary = d["L"]
	var body_mesh: ArrayMesh = d["body"]
	(_mi["body"] as MeshInstance3D).mesh = body_mesh
	var st: Dictionary = L["style"]
	var hp: Dictionary = L["hp"]
	var hc: Color = L["hair_col"]
	var seedf: float = L["seed"]
	# --- Pele ---------------------------------------------------------------------------
	var skin: ShaderMaterial = _mats["body"]
	var info := Face3DKit.info()
	var avg: Dictionary = info.get("skin_avg", {})
	skin.set_shader_parameter("detail_tex", Face3DKit.texture("skin_%s.png" % L["detail"]))
	skin.set_shader_parameter("detail_avg", _lin(avg.get(L["detail"], [0.8, 0.52, 0.43])))
	var sl := (L["skin"] as Color).srgb_to_linear()
	skin.set_shader_parameter("target", Vector3(sl.r, sl.g, sl.b))
	for k in ["dark", "rosy", "age", "wr_fore", "wr_eyes", "wr_naso", "eyebags", "circles", "freckles", "spots", "acne", "oily", "lip_dark"]:
		skin.set_shader_parameter(k, float(L[k]))
	skin.set_shader_parameter("mole1", L["mole1"])
	skin.set_shader_parameter("mole2", L["mole2"])
	skin.set_shader_parameter("scar", L["scar"])
	skin.set_shader_parameter("seed", seedf)
	skin.set_shader_parameter("hair_col", hc)
	var bald := String(L["style_name"]) == "bald"
	skin.set_shader_parameter("scalp", 0.0 if bald else 0.55)
	_hair_params(skin, st, hp)
	var bd: Dictionary = L["beard"]
	_beard_params(skin, bd)
	skin.set_shader_parameter("beard_col", L["beard_col"])
	skin.set_shader_parameter("shadow", L["shadow"])
	var ln := float(bd.get("ln", 0.0))
	var op := float(bd.get("op", 0.0))
	skin.set_shader_parameter("b_op", op if ln < 0.03 else op * 0.8)
	skin.set_shader_parameter("b_pt", L["beard_pt"])
	# --- Camadas de cabelo curto / base -----------------------------------------------------
	var s_len: Array = st.get("s", [0, 0, 0, 0, 0])
	var has_cards: bool = st.has("c") or st.has("extra")
	var max_mm := 0.0
	for v in s_len:
		max_mm = maxf(max_mm, float(v))
	var nl := 0 if bald or max_mm <= 0.0 else clampi(int(ceil(max_mm / 1.6)) + 3, 4, SCALP_LAYERS)
	var coily := float(st.get("coily", 0.0))
	for i in SCALP_LAYERS:
		var mi: MeshInstance3D = _scalp[i]
		mi.visible = i < nl
		if not mi.visible:
			continue
		mi.mesh = body_mesh
		var m: ShaderMaterial = mi.material_override
		m.set_shader_parameter("mode", 0.0)
		m.set_shader_parameter("layer", float(i) / maxf(1.0, nl - 1))
		m.set_shader_parameter("len_a", Vector4(float(s_len[0]), float(s_len[1]), float(s_len[2]), float(s_len[3])) * 0.001)
		m.set_shader_parameter("len_nape", float(s_len[4]) * 0.001)
		m.set_shader_parameter("coily", coily)
		m.set_shader_parameter("density", 1.0 if not has_cards else 0.95)
		m.set_shader_parameter("color", hc)
		m.set_shader_parameter("seed", seedf)
		m.set_shader_parameter("lighten", float(L["lighten"]) + float(L["tips"]) * 0.5)
		m.set_shader_parameter("gray", L["gray"])
		m.set_shader_parameter("flat_top", float(st.get("flat", 0.0)))
		m.set_shader_parameter("tile", 0.55 if coily < 0.5 else 0.45)
		m.set_shader_parameter("patchy", 0.0)
		_hair_params(m, st, hp)
	# --- Camadas da barba ---------------------------------------------------------------
	var beard_mm := 0.0
	if op > 0.55:
		beard_mm = 2.0 + ln * 28.0
	var nb := 0 if beard_mm <= 0.0 else clampi(int(ceil(beard_mm / 1.2)) + 2, 3, BEARD_LAYERS)
	for i in BEARD_LAYERS:
		var mi: MeshInstance3D = _beard[i]
		mi.visible = i < nb
		if not mi.visible:
			continue
		mi.mesh = body_mesh
		var m: ShaderMaterial = mi.material_override
		m.set_shader_parameter("mode", 1.0)
		m.set_shader_parameter("layer", float(i) / maxf(1.0, nb - 1))
		m.set_shader_parameter("beard_len", minf(beard_mm, 14.0) * 0.001)
		m.set_shader_parameter("coily", float(L["beard_curly"]) * 0.6)
		m.set_shader_parameter("density", op)
		m.set_shader_parameter("patchy", L["beard_pt"])
		m.set_shader_parameter("color", L["beard_col"])
		m.set_shader_parameter("seed", seedf + 3.0)
		m.set_shader_parameter("lighten", 0.0)
		m.set_shader_parameter("gray", float(L["gray"]) * 1.2)
		m.set_shader_parameter("tile", 0.6)
		_beard_params(m, bd)
	# --- Mechas, barba longa e sobrancelhas -----------------------------------------------
	var hm: ArrayMesh = d["hair"]
	var hmi: MeshInstance3D = _mi["hair"]
	hmi.visible = hm != null
	if hm != null:
		hmi.mesh = hm
		var m: ShaderMaterial = _mats["hair"]
		m.set_shader_parameter("tex", Face3DKit.texture("strands_%s.png" % String(st.get("tex", "straight"))))
		m.set_shader_parameter("color", hc)
		m.set_shader_parameter("shine", float(st.get("gloss", 0.55)))
		m.set_shader_parameter("lighten", L["lighten"])
		m.set_shader_parameter("tips", maxf(float(L["tips"]), float(L["highlights"]) * 0.6))
		m.set_shader_parameter("gray", L["gray"])
		m.set_shader_parameter("cutoff", 0.35)
	var bm: ArrayMesh = d["beardc"]
	var bmi: MeshInstance3D = _mi["beardc"]
	bmi.visible = bm != null
	if bm != null:
		bmi.mesh = bm
		var m2: ShaderMaterial = _mats["beardc"]
		m2.set_shader_parameter("tex", Face3DKit.texture("strands_%s.png" % ("curly" if float(L["beard_curly"]) > 0.5 else "wavy")))
		m2.set_shader_parameter("color", L["beard_col"])
		m2.set_shader_parameter("shine", 0.35)
		m2.set_shader_parameter("gray", float(L["gray"]) * 1.2)
		m2.set_shader_parameter("cutoff", 0.35)
	var brm: ArrayMesh = d["brows"]
	var brmi: MeshInstance3D = _mi["brows"]
	brmi.visible = brm != null
	if brm != null:
		brmi.mesh = brm
		var m3: ShaderMaterial = _mats["brows"]
		m3.set_shader_parameter("tex", Face3DKit.texture("strands_fine.png"))
		m3.set_shader_parameter("color", L["brow_col"])
		m3.set_shader_parameter("shine", 0.25)
		m3.set_shader_parameter("gray", float(L["gray"]) * 0.6)
		m3.set_shader_parameter("cutoff", 0.3)
	var lm: ArrayMesh = d["lashes"]
	(_mi["lashes"] as MeshInstance3D).mesh = lm
	var m4: ShaderMaterial = _mats["lashes"]
	m4.set_shader_parameter("tex", Face3DKit.texture("lashes.png"))
	m4.set_shader_parameter("color", (L["brow_col"] as Color).darkened(0.4))
	m4.set_shader_parameter("shine", 0.1)
	m4.set_shader_parameter("cutoff", 0.3)
	# --- Olhos ------------------------------------------------------------------------------
	(_mi["eyes"] as MeshInstance3D).mesh = d["eyes"]
	var em: ShaderMaterial = _mats["eyes"]
	em.set_shader_parameter("iris_col", L["iris"])
	em.set_shader_parameter("iris_in", L["iris_in"])
	em.set_shader_parameter("iris_b", L["iris_b"])
	em.set_shader_parameter("ring", L["iris_ring"])
	em.set_shader_parameter("limbal", L["limbal"])
	em.set_shader_parameter("pupil", L["pupil"])
	em.set_shader_parameter("hetero", float(L["hetero"]))
	em.set_shader_parameter("seed", seedf)
	em.set_shader_parameter("sclera_tint", L["sclera"])
	# --- Camisa -----------------------------------------------------------------------------
	var shirt: ShaderMaterial = _mats["shirt"]
	(_mi["shirt"] as MeshInstance3D).mesh = d["shirt"]
	var kit: Dictionary = spec.get("kit", {})
	var suit := bool(spec.get("suit", false))
	var c1: Color = spec.get("shirt", Color("#1B3A8C"))
	var tr: Color = spec.get("trim", Color.WHITE)
	if not kit.is_empty() and not suit:
		c1 = Color(String(kit.get("c1", c1.to_html())))
		tr = Color(String(kit.get("c3", kit.get("c2", tr.to_html()))))
		_kit_view.kit = kit
		_kit_view.crest = spec.get("crest", {})
	shirt.set_shader_parameter("use_kit", not kit.is_empty() and not suit)
	shirt.set_shader_parameter("c1", Color("#23262D") if suit else c1)
	shirt.set_shader_parameter("trim", tr)
	shirt.set_shader_parameter("suit", 1.0 if suit else 0.0)


static func _hair_params(m: ShaderMaterial, st: Dictionary, hp: Dictionary) -> void:
	m.set_shader_parameter("hairline", float(hp.get("hairline", 8.72)))
	m.set_shader_parameter("temples", float(hp.get("temples", 0.0)))
	m.set_shader_parameter("crown", float(hp.get("crown", 0.0)))
	m.set_shader_parameter("widow", float(hp.get("widow", 0.0)))
	m.set_shader_parameter("fade_h", float(st.get("fade", 0.0)))
	m.set_shader_parameter("fade_sharp", float(st.get("sharp", 0.0)))
	m.set_shader_parameter("hawk_w", float(st.get("hawk", 0.0)))
	m.set_shader_parameter("rows", float(st.get("rows", 0.0)))
	m.set_shader_parameter("waves", float(st.get("waves", 0.0)))
	m.set_shader_parameter("design", float(st.get("design", 0.0)))
	m.set_shader_parameter("part_x", float(st.get("part", 0.0)) * float(hp.get("part_side", 1.0)))


static func _beard_params(m: ShaderMaterial, bd: Dictionary) -> void:
	for k in ["ch", "sd", "jw", "cn", "mu", "so", "nk", "sh"]:
		m.set_shader_parameter("b_" + k, float(bd.get(k, 0.0)))
	m.set_shader_parameter("b_cnw", float(bd.get("cnw", 1.0)))


static func _lin(a: Array) -> Vector3:
	var c := Color(float(a[0]), float(a[1]), float(a[2])).srgb_to_linear()
	return Vector3(c.r, c.g, c.b)
