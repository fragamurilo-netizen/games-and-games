class_name FightView3D
extends Control
## A mesma luta animada, em 3D: octógono com grade, lona, torcida e luz de arena, câmera de TV
## por fora da grade. Quem decide o movimento é o `FightStage2D` (o "cérebro", escondido aqui
## dentro): ele toca a fila de lances e calcula as poses; esta vista só monta os bonecos 3D a
## partir das juntas de cada quadro, com profundidade (ombros e quadril abertos para os lados).
## Roda no renderizador de compatibilidade (o mesmo do celular).

const R_OCT := 16.8 ## raio do octógono (vértices), em U; o lado plano fica em ARENA + 0.5
const FENCE_H := 7.0

var brain: FightStage2D
var _vp: SubViewport
var _cam: Camera3D
var _figs: Array = []
var _fx: Array = []
var _cap: Label
var _t := 0.0
var _org := Color("#C8102E")
var _cam_pos := Vector3(0, 6, 18)
var _cam_look := Vector3(0, 3, 0)
var _ref_fig: Dictionary = {}
var _drops: Array = []
var _stains: Array = []
var _rep: Label
var _was_replay := false
var _canvas_label: Label3D
## Lados da grade ([peças], centro no chão): os que ficam entre a câmera e a luta somem.
var _fence: Array = []
var _logo := ""


func setup(brain_: FightStage2D, org_color: Color = Color("#C8102E"), logo: String = "") -> void:
	brain = brain_
	_org = org_color
	_logo = logo
	custom_minimum_size = Vector2(0, 300)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# O cérebro fica escondido, com um tamanho fixo (as contas dele usam o tamanho).
	brain.visible = false
	brain.size = Vector2(400, 300)
	add_child(brain)
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	_vp = SubViewport.new()
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.own_world_3d = true
	svc.add_child(_vp)
	_build_world()
	for i in 2:
		_figs.append(_build_fighter(brain.rigs[i]))
	if brain.ref != null:
		_ref_fig = _build_fighter(brain.ref)
	var bm := _mat(Color(0.5, 0.02, 0.03), 0.3)
	for i in 14:
		var d := _part(_sphere(), bm)
		d.visible = false
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_drops.append(d)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.01
	disc.radial_segments = 14
	var stm := _mat(Color(0.42, 0.03, 0.04), 0.35)
	for i in 30:
		var d2 := _part(disc, stm)
		d2.visible = false
		d2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_stains.append(d2)
	for i in 4:
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		m.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(1, 0.95, 0.7, 0.8)
		m.material_override = mat
		m.visible = false
		_vp.add_child(m)
		_fx.append(m)
	_cap = Label.new()
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_cap.offset_top = 16
	_cap.add_theme_font_size_override(&"font_size", 30)
	_cap.add_theme_color_override(&"font_color", UIColors.GOLD)
	_cap.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_cap.add_theme_constant_override(&"outline_size", 6)
	add_child(_cap)
	_rep = Label.new()
	_rep.text = "● REPLAY"
	_rep.position = Vector2(12, 10)
	_rep.add_theme_font_size_override(&"font_size", 18)
	_rep.add_theme_color_override(&"font_color", Color.WHITE)
	_rep.add_theme_color_override(&"font_outline_color", Color(0.75, 0.05, 0.05))
	_rep.add_theme_constant_override(&"outline_size", 5)
	_rep.visible = false
	add_child(_rep)


## Devolve o cérebro para quem vai mostrar a luta de outro jeito.
func release() -> FightStage2D:
	if brain != null and brain.get_parent() == self:
		remove_child(brain)
	brain.visible = true
	return brain


# --- Arena ---------------------------------------------------------------------------------

static func _mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot_y: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation.y = rot_y
	_vp.add_child(mi)
	return mi


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#07080B")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.57, 0.65)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 14, 10)
	fill.omni_range = 40.0
	fill.light_energy = 0.6
	_vp.add_child(fill)
	# Lona: octógono claro com o anel e a marca no centro.
	var fl := CylinderMesh.new()
	fl.top_radius = R_OCT
	fl.bottom_radius = R_OCT
	fl.height = 0.4
	fl.radial_segments = 8
	_add(fl, _mat(Color("#7F7B74"), 0.95), Vector3(0, -0.2, 0), deg_to_rad(22.5))
	var apron := CylinderMesh.new()
	apron.top_radius = R_OCT + 3.0
	apron.bottom_radius = R_OCT + 3.0
	apron.height = 0.4
	apron.radial_segments = 8
	_add(apron, _mat(Color("#16181D")), Vector3(0, -0.45, 0), deg_to_rad(22.5))
	var ring := TorusMesh.new()
	ring.inner_radius = 5.0
	ring.outer_radius = 5.9
	var rm := _mat(_org.darkened(0.1))
	_add(ring, rm, Vector3(0, -0.1, 0)).scale = Vector3(1, 0.08, 1)
	var logo := CylinderMesh.new()
	logo.top_radius = 5.0
	logo.bottom_radius = 5.0
	logo.height = 0.02
	var lm := _mat(Color(_org, 1.0).lerp(Color("#7F7B74"), 0.85))
	_add(logo, lm, Vector3(0, 0.005, 0))
	# Grade: painéis de alambrado, postes pretos e acolchoado em cima.
	var link := _chain_texture()
	var apothem := R_OCT * cos(deg_to_rad(22.5))
	var side := 2.0 * R_OCT * sin(deg_to_rad(22.5))
	for k in 8:
		var a := deg_to_rad(45.0 * float(k))
		var q := QuadMesh.new()
		q.size = Vector2(side, FENCE_H)
		var fm := StandardMaterial3D.new()
		fm.albedo_texture = link
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		fm.alpha_scissor_threshold = 0.4
		fm.cull_mode = BaseMaterial3D.CULL_DISABLED
		fm.uv1_scale = Vector3(side / 0.9, FENCE_H / 0.9, 1)
		fm.albedo_color = Color(0.75, 0.77, 0.82)
		fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var p := _add(q, fm, Vector3(sin(a) * apothem, FENCE_H * 0.5, cos(a) * apothem), a)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pad := BoxMesh.new()
		pad.size = Vector3(side, 0.45, 0.5)
		var pm := _add(pad, _mat(Color("#121317")), Vector3(sin(a) * apothem, FENCE_H + 0.2, cos(a) * apothem), a)
		_fence.append([[p, pm], Vector3(sin(a) * apothem, 0, cos(a) * apothem)])
		var va := deg_to_rad(45.0 * float(k) + 22.5)
		var post := CylinderMesh.new()
		post.top_radius = 0.28
		post.bottom_radius = 0.28
		post.height = FENCE_H + 0.6
		var pc := Color("#101114")
		if k == 6:
			pc = UIColors.CORNER_RED
		elif k == 2:
			pc = UIColors.CORNER_BLUE
		var pst := _add(post, _mat(pc), Vector3(sin(va) * R_OCT, (FENCE_H + 0.6) * 0.5, cos(va) * R_OCT))
		_fence.append([[pst], Vector3(sin(va) * R_OCT, 0, cos(va) * R_OCT)])
	# Torcida: arquibancada em volta, blocos escuros com camisas variadas.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var person := BoxMesh.new()
	person.size = Vector3(0.9, 1.5, 0.7)
	mm.mesh = person
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var n := 0
	var spots: Array = []
	for row in 7:
		var r := R_OCT + 6.0 + float(row) * 1.6
		var cnt := int(TAU * r / 1.15)
		for i in cnt:
			var a := TAU * float(i) / float(cnt) + rng.randf() * 0.02
			spots.append([Vector3(sin(a) * r, 0.2 + float(row) * 0.9 + rng.randf() * 0.25, cos(a) * r), a])
			n += 1
	mm.instance_count = n
	for i in n:
		var s: Array = spots[i]
		var tr := Transform3D(Basis(Vector3.UP, float(s[1])), s[0])
		mm.set_instance_transform(i, tr)
		var c := Color.from_hsv(rng.randf(), rng.randf_range(0.05, 0.3), rng.randf_range(0.07, 0.2))
		mm.set_instance_color(i, c)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.roughness = 1.0
	mmi.material_override = cm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vp.add_child(mmi)
	# Nome do evento pintado na lona.
	if _logo != "":
		_canvas_label = Label3D.new()
		_canvas_label.text = _logo.to_upper()
		_canvas_label.font_size = 160
		_canvas_label.pixel_size = 0.012
		_canvas_label.outline_size = 0
		_canvas_label.modulate = Color(1, 1, 1, 0.55)
		_canvas_label.rotation_degrees = Vector3(-90, 0, 0)
		_canvas_label.position = Vector3(0, 0.03, 0)
		_canvas_label.shaded = true
		_canvas_label.double_sided = false
		_vp.add_child(_canvas_label)
	# Grid de luz em cima: treliça, refletores acesos, fachos no ar e dois spots no octógono.
	var truss := _mat(Color("#1B1C20"), 0.6)
	for k in 4:
		var bx := BoxMesh.new()
		bx.size = Vector3(26.0, 0.6, 0.6)
		var tb := _add(bx, truss, Vector3(0, 17.0, 0), deg_to_rad(90.0 * float(k)))
		tb.position = Vector3(sin(deg_to_rad(90.0 * float(k))) * 13.0, 17.0, cos(deg_to_rad(90.0 * float(k))) * 13.0)
		tb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp := StandardMaterial3D.new()
	lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.albedo_color = Color(1.0, 0.97, 0.88)
	var beam := StandardMaterial3D.new()
	beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.albedo_color = Color(1.0, 0.95, 0.85, 0.035)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 4.0
	cone.height = 16.5
	cone.radial_segments = 16
	cone.cap_top = false
	cone.cap_bottom = false
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.4
		var lp := Vector3(sin(a) * 12.5, 16.6, cos(a) * 12.5)
		var lb := BoxMesh.new()
		lb.size = Vector3(0.7, 0.35, 0.7)
		_add(lb, lamp, lp).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if k % 2 == 0:
			var tgt := Vector3(sin(a) * 4.0, 0, cos(a) * 4.0)
			var cmi := MeshInstance3D.new()
			cmi.mesh = cone
			cmi.material_override = beam
			cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var d := (lp - tgt).normalized()
			var x := d.cross(Vector3.FORWARD).normalized()
			var z := x.cross(d).normalized()
			cmi.transform = Transform3D(Basis(x, d, z), (lp + tgt) * 0.5)
			_vp.add_child(cmi)
	for k in 2:
		var sp := SpotLight3D.new()
		sp.position = Vector3(-9.0 + 18.0 * float(k), 16.0, 6.0)
		sp.spot_range = 30.0
		sp.spot_angle = 32.0
		sp.light_energy = 1.1
		sp.light_color = Color(1.0, 0.96, 0.9)
		_vp.add_child(sp)
		sp.look_at_from_position(sp.position, Vector3(0, 0, 0))
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.current = true
	_vp.add_child(_cam)


## Alambrado: losangos claros num fundo transparente, repetido na grade.
static func _chain_texture() -> ImageTexture:
	var s := 32
	var img := Image.create(s, s, true, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in s:
		for w in 2:
			img.set_pixel((i + w) % s, i, Color(1, 1, 1, 1))
			img.set_pixel((s - 1 - i + w) % s, i, Color(1, 1, 1, 1))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# --- Lutadores ---------------------------------------------------------------------------

## Malhas compartilhadas: cilindros afinando (membros), esfera (músculos, juntas, cabeça), caixa.
var _meshes := {}


func _taper(k: float) -> CylinderMesh:
	var key := "c%.2f" % k
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.bottom_radius = 0.5
		c.top_radius = 0.5 * k
		c.height = 1.0
		c.radial_segments = 14
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]


func _sphere() -> SphereMesh:
	if not _meshes.has("s"):
		var m := SphereMesh.new()
		m.radius = 0.5
		m.height = 1.0
		m.radial_segments = 18
		m.rings = 10
		_meshes["s"] = m
	return _meshes["s"]


## Monta o boneco: membros que afinam, deltoide, bíceps, quadríceps e panturrilha, peito em dois
## peitorais, trapézio, abdômen, calção com cós, luvas com polegar e punho do corner, rosto com
## mandíbula, orelhas, olhos, sobrancelhas, nariz, cabelo, barba, corte e inchaço.
func _build_fighter(r: Rig2D) -> Dictionary:
	var f := {"rig": r}
	var is_ref := r.outfit == "ref"
	var skin := _mat(r.skin, 0.55)
	var shorts := _mat(r.shorts, 0.85)
	var shirt := _mat(r.shirt, 0.8)
	var trim := _mat(r.trim, 0.7)
	var glove := _mat(r.glove, 0.4)
	var band := _mat(r.corner, 0.6)
	var hair := _mat(r.hair, 0.95)
	var dark := _mat(Color(0.06, 0.05, 0.05), 0.3)
	var blood := _mat(Color(0.55, 0.02, 0.03), 0.25)
	var bruise := _mat(Color(0.38, 0.12, 0.2), 0.6)
	bruise.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	skin.rim_enabled = true
	skin.rim = 0.3
	skin.rim_tint = 0.5
	f["skin"] = skin
	f["glove_m"] = glove
	f["bruise_m"] = bruise
	var top_m: StandardMaterial3D = shirt if is_ref else skin
	var leg_m: StandardMaterial3D = shorts if is_ref else skin
	var sph := _sphere()
	var box := BoxMesh.new()
	for sd: String in ["na", "fa"]:
		f[sd + "_delt"] = _part(sph, top_m)
		f[sd + "_u"] = _part(_taper(0.78), top_m)
		f[sd + "_bi"] = _part(sph, top_m)
		f[sd + "_el"] = _part(sph, skin)
		f[sd + "_f"] = _part(_taper(0.7), skin)
		f[sd + "_fm"] = _part(sph, skin)
		if is_ref:
			f[sd + "_g"] = _part(sph, _mat(Color("#8DB6DA"), 0.35))
		else:
			f[sd + "_g"] = _part(sph, glove)
			f[sd + "_th"] = _part(sph, glove)
			f[sd + "_fing"] = _part(sph, skin)
			f[sd + "_band"] = _part(_taper(1.0), band)
	for sd: String in ["nl", "fl"]:
		f[sd + "_t"] = _part(_taper(0.7), leg_m)
		f[sd + "_q"] = _part(sph, leg_m)
		f[sd + "_kn"] = _part(sph, leg_m)
		f[sd + "_s"] = _part(_taper(0.58), leg_m)
		f[sd + "_calf"] = _part(sph, leg_m)
		f[sd + "_an"] = _part(sph, skin)
		f[sd + "_ft"] = _part(sph, dark if is_ref else skin)
		if not is_ref:
			f[sd + "_sh"] = _part(_taper(0.9), shorts)
			f[sd + "_hem"] = _part(_taper(1.0), trim)
			f[sd + "_stripe"] = _part(_taper(1.0), trim)
	f["pelvis"] = _part(sph, shorts)
	f["band"] = _part(_taper(1.0), shirt if is_ref else trim)
	f["abs"] = _part(sph, top_m)
	f["ribs"] = _part(sph, top_m)
	f["pec_n"] = _part(sph, top_m)
	f["pec_f"] = _part(sph, top_m)
	f["trap"] = _part(sph, top_m)
	f["lat_n"] = _part(sph, top_m)
	f["lat_f"] = _part(sph, top_m)
	for k in 6:
		f["ab%d" % k] = _part(sph, top_m)
	if is_ref:
		f["collar"] = _part(_taper(1.0), shirt)
		f["badge"] = _part(box, _mat(Color("#E8E6E0"), 0.6))
	f["cheek_n"] = _part(sph, skin)
	f["cheek_f"] = _part(sph, skin)
	f["chin"] = _part(sph, skin)
	f["lips"] = _part(sph, _mat(r.skin.darkened(0.3).lerp(Color(0.55, 0.25, 0.25), 0.3), 0.5))
	f["white_n"] = _part(sph, _mat(Color(0.92, 0.9, 0.86), 0.3))
	f["white_f"] = _part(sph, _mat(Color(0.92, 0.9, 0.86), 0.3))
	f["nosebleed"] = _part(_taper(0.5), blood)
	f["neck"] = _part(_taper(0.92), skin)
	f["head"] = _part(sph, skin)
	f["jaw"] = _part(sph, skin)
	f["ear_n"] = _part(sph, skin)
	f["ear_f"] = _part(sph, skin)
	f["eye_n"] = _part(sph, dark)
	f["eye_f"] = _part(sph, dark)
	f["brow_n"] = _part(box, hair)
	f["brow_f"] = _part(box, hair)
	f["nose"] = _part(sph, skin)
	f["hair"] = _part(sph, hair)
	(f["hair"] as MeshInstance3D).visible = not r.bald
	f["beard"] = _part(sph, _mat(r.beard, 0.95))
	(f["beard"] as MeshInstance3D).visible = r.has_beard
	f["cut"] = _part(sph, blood)
	f["drip"] = _part(_taper(0.4), blood)
	f["chest_blood"] = _part(_taper(0.5), blood)
	f["bruise"] = _part(sph, bruise)
	if r.fem and not is_ref:
		f["top"] = _part(sph, _mat(r.shorts.darkened(0.15)))
	return f


func _part(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	_vp.add_child(mi)
	return mi


static func _v(p: Vector2, z: float) -> Vector3:
	return Vector3(p.x, -p.y, z)


## Peça de altura 1 entre dois pontos (o topo da malha fica em `b`), com grossura `w`.
static func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3, w: float, extra: float = 0.0) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return
	var y := d / l
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * w, y * (l + extra), z * w), (a + b) * 0.5)


## Elipsoide em `c` com eixos (frente, cima, lado) e tamanhos.
static func _ell(mi: MeshInstance3D, c: Vector3, fw: Vector3, up: Vector3, _sd: Vector3, size: Vector3) -> void:
	# Base sempre destra (o lado sai de frente × cima), senão a malha vira do avesso.
	var sd := fw.cross(up).normalized()
	mi.transform = Transform3D(Basis(fw * size.x, up * size.y, sd * size.z), c)


static func _frame(up: Vector3, dir: float) -> Array:
	var u := up.normalized()
	var fw := u.cross(Vector3.BACK) * dir
	if fw.length() < 0.01:
		fw = Vector3.RIGHT * dir
	fw = fw.normalized()
	var sd := fw.cross(u).normalized()
	return [fw, u, sd]


func _pose_fighter(f: Dictionary, zoff: float = 0.0) -> void:
	var r: Rig2D = f["rig"]
	var j := r.joints(0.0, 0.0, 1.0)
	var Uh: float = j["U"]
	var is_ref := r.outfit == "ref"
	var skin: StandardMaterial3D = f["skin"]
	skin.albedo_color = r.skin.lerp(Color(0.8, 0.22, 0.18), r.flash * 0.35)
	var zz := zoff + float(r.pose.get("zz", 0.0))
	var lz := 1.0 + float(r.pose.get("lz", 0.0))
	var az := 1.0 + float(r.pose.get("az", 0.0))
	var mus := clampf((r.arm_k - 0.85) / 0.5, 0.0, 1.0)
	var sw := 0.66 * r.chest_k * Uh
	var hw := 0.36 * Uh * lz
	var aw := 0.5 * r.arm_k * Uh
	var lw := 0.72 * r.leg_k * Uh
	var hip := _v(j["hip"], zz)
	var neck := _v(j["neck"], zz)
	var sh := _v(j["sh"], zz)
	var tf := _frame(neck - hip, r.dir)
	var fw: Vector3 = tf[0]
	var up: Vector3 = tf[1]
	var side: Vector3 = Vector3.BACK
	# Braços
	var tw := deg_to_rad(float(r.pose.get("tw", 0.0)))
	var rear := r.rear()
	for sd: String in ["na", "fa"]:
		# Giro: o ombro de trás vai para a frente e o da frente recua; o soco esticado fecha no centro.
		var sg := 1.0 if sd.begins_with(rear) else -1.0
		var fo := fw * sin(tw) * sw * sg
		var z := (sw if sd == "na" else -sw) * az * cos(tw)
		var s := sh + fo + Vector3(0, 0, z)
		var reach := clampf(((j[sd + "_wr"] as Vector2).distance_to(j["sh"]) / ((Rig2D.L_UARM + Rig2D.L_FARM) * Uh) - 0.6) / 0.35, 0.0, 1.0)
		var el := _v(j[sd + "_el"], zz + z * 1.08) + fo
		var wr := _v(j[sd + "_wr"], zz + z * 0.85 * (1.0 - 0.85 * reach)) + fo
		_ell(f[sd + "_delt"], s + up * Uh * 0.02, fw, up, side, Vector3(aw * 1.55, aw * 1.35, aw * 1.45) * (1.0 + 0.15 * mus))
		_seg(f[sd + "_u"], s, el, aw)
		var ud := (el - s).normalized()
		var uf := _frame(ud, r.dir)
		_ell(f[sd + "_bi"], s.lerp(el, 0.45) + (uf[0] as Vector3) * aw * 0.18, uf[0], ud, side, Vector3(aw * (1.0 + 0.25 * mus), s.distance_to(el) * 0.7, aw * 0.95))
		_ell(f[sd + "_el"], el, fw, up, side, Vector3.ONE * aw * 0.82)
		_seg(f[sd + "_f"], el, wr, aw * 0.92)
		var gd := (wr - el).normalized()
		var gf := _frame(gd, r.dir)
		_ell(f[sd + "_fm"], el.lerp(wr, 0.3) + (gf[0] as Vector3) * aw * 0.1, gf[0], gd, side, Vector3(aw * (0.95 + 0.2 * mus), el.distance_to(wr) * 0.55, aw * 0.9))
		if is_ref:
			_ell(f[sd + "_g"], wr + gd * Uh * 0.12, gf[0], gd, side, Vector3(aw * 0.7, aw * 0.95, aw * 0.6))
		else:
			# Luva de MMA: almofada nos nós dos dedos, dedos dobrados por baixo, polegar e punho.
			_ell(f[sd + "_g"], wr + gd * Uh * 0.22 + (gf[0] as Vector3) * Uh * 0.06, gf[0], gd, side, Vector3(Uh * 0.56, Uh * 0.66, Uh * 0.6))
			_ell(f[sd + "_fing"], wr + gd * Uh * 0.3 - (gf[0] as Vector3) * Uh * 0.16, gf[0], gd, side, Vector3(Uh * 0.3, Uh * 0.36, Uh * 0.5))
			_ell(f[sd + "_th"], wr + gd * Uh * 0.1 + (gf[0] as Vector3) * Uh * 0.24, gf[0], gd, side, Vector3(Uh * 0.24, Uh * 0.36, Uh * 0.24))
			_seg(f[sd + "_band"], wr - gd * Uh * 0.12, wr + gd * Uh * 0.02, Uh * 0.55)
	# Pernas
	for sd: String in ["nl", "fl"]:
		var sg := 1.0 if sd.begins_with(rear) else -1.0
		var fo := fw * sin(tw * 0.6) * hw * sg
		var z := (hw if sd == "nl" else -hw) * cos(tw * 0.6)
		var h := hip + fo + Vector3(0, 0, z)
		# Perna que sobe (chute, joelhada) fecha para o centro.
		var rise := clampf(((j[sd + "_an"] as Vector2).y * -1.0 - (-(j["hip"] as Vector2).y - 3.2 * Uh)) / (2.6 * Uh), 0.0, 1.0)
		var kn := _v(j[sd + "_kn"], zz + z * 1.05 * (1.0 - 0.5 * rise)) + fo
		var an := _v(j[sd + "_an"], zz + z * (1.0 - 0.8 * rise)) + fo
		var toe := _v(j[sd + "_toe"], zz + z * (1.0 - 0.8 * rise)) + fo
		_seg(f[sd + "_t"], h, kn, lw)
		var td := (kn - h).normalized()
		var tfr := _frame(td, r.dir)
		_ell(f[sd + "_q"], h.lerp(kn, 0.5) + (tfr[0] as Vector3) * lw * 0.15, tfr[0], td, side, Vector3(lw * 1.0, h.distance_to(kn) * 0.8, lw * 0.95))
		_ell(f[sd + "_kn"], kn, fw, up, side, Vector3.ONE * lw * 0.72)
		_seg(f[sd + "_s"], kn, an, lw * 0.66)
		var sdv := (an - kn).normalized()
		var sfr := _frame(sdv, r.dir)
		_ell(f[sd + "_calf"], kn.lerp(an, 0.32) - (sfr[0] as Vector3) * lw * 0.12, sfr[0], sdv, side, Vector3(lw * 0.72, kn.distance_to(an) * 0.55, lw * 0.66))
		_ell(f[sd + "_an"], an, fw, up, side, Vector3.ONE * lw * 0.42)
		var fd := (toe - an).normalized()
		var ffr := _frame(fd, r.dir)
		_ell(f[sd + "_ft"], an.lerp(toe, 0.55), ffr[0], fd, side, Vector3(lw * 0.36, an.distance_to(toe) * 1.25, lw * 0.5))
		if f.has(sd + "_sh"):
			var send := h.lerp(kn, 0.52)
			_seg(f[sd + "_sh"], h - td * Uh * 0.15, send, lw * 1.28)
			_seg(f[sd + "_hem"], send - td * Uh * 0.06, send + td * Uh * 0.03, lw * 1.2)
			var outv := Vector3(0, 0, signf(z) if absf(z) > 0.01 else 1.0) * lw * 0.6
			_seg(f[sd + "_stripe"], h + outv - td * Uh * 0.1, send + outv, lw * 0.22)
	# Tronco
	var tl := hip.distance_to(neck)
	var depth := 0.9 * Uh * r.chest_k
	var belly := r.belly
	var chest_c := neck - up * Uh * 0.78
	_ell(f["pelvis"], hip + up * Uh * 0.1, fw, up, side, Vector3(depth * 1.05, Uh * 1.0, hw * 2.0 + Uh * 0.75))
	(f["band"] as MeshInstance3D).transform = Transform3D(Basis(fw * depth * 1.08, up * Uh * 0.2, fw.cross(up) * (hw * 2.0 + Uh * 0.82)), hip + up * Uh * 0.52)
	_ell(f["abs"], hip.lerp(neck, 0.38) + fw * Uh * 0.05 * belly, fw, up, side, Vector3(depth * (0.95 + 0.4 * belly), tl * 0.62, sw * 1.7 * (1.0 + 0.15 * belly)))
	_ell(f["ribs"], chest_c, fw, up, side, Vector3(depth * 1.05, Uh * 1.55, sw * 2.15))
	for pk: String in ["pec_n", "pec_f"]:
		var zs := 1.0 if pk == "pec_n" else -1.0
		_ell(f[pk], chest_c + up * Uh * 0.12 + fw * depth * 0.3 + side * zs * sw * 0.48, fw, up, side, Vector3(depth * 0.55, Uh * 0.62, sw * 0.95) * (1.0 + 0.2 * mus))
	for li: int in 2:
		var zs := 1.0 if li == 0 else -1.0
		_ell(f["lat_n" if li == 0 else "lat_f"], chest_c - up * Uh * 0.45 + side * zs * sw * 0.95 - fw * depth * 0.1, fw, up, side, Vector3(depth * 0.62, Uh * 1.15, sw * 0.42) * (1.0 + 0.15 * mus))
	for k in 6:
		var abm: MeshInstance3D = f["ab%d" % k]
		abm.visible = belly < 0.25 and not is_ref
		if abm.visible:
			var row := float(k / 2)
			var zs2 := 1.0 if k % 2 == 0 else -1.0
			_ell(abm, hip + up * Uh * (0.8 + 0.4 * row) + fw * depth * 0.4 + side * zs2 * sw * 0.26, fw, up, side, Vector3(depth * 0.22, Uh * 0.36, sw * 0.3))
	if is_ref:
		_seg(f["collar"], neck - up * Uh * 0.15, neck + up * Uh * 0.12, Uh * 0.68)
		_ell(f["badge"], chest_c + up * Uh * 0.25 + fw * depth * 0.5 + side * sw * 0.5, fw, up, side, Vector3(0.05, Uh * 0.28, Uh * 0.36))
	_ell(f["trap"], neck - up * Uh * 0.2 - fw * depth * 0.12, fw, up, side, Vector3(depth * 0.7, Uh * 0.55, sw * 1.6) * (1.0 + 0.2 * mus))
	if f.has("top"):
		_ell(f["top"], chest_c + up * Uh * 0.05 + fw * depth * 0.06, fw, up, side, Vector3(depth * 1.12, Uh * 0.85, sw * 2.25))
	# Cabeça
	var head := _v(j["head"], zz)
	_seg(f["neck"], neck - up * Uh * 0.2, head - up * 0.0, Uh * 0.5 * r.chest_k)
	var hfr := _frame(head - neck, r.dir)
	var hf: Vector3 = hfr[0]
	var hu: Vector3 = hfr[1]
	var hr := Uh
	_ell(f["head"], head, hf, hu, side, Vector3(hr * 1.0, hr * 1.12, hr * 0.9))
	_ell(f["jaw"], head - hu * hr * 0.25 + hf * hr * 0.12, hf, hu, side, Vector3(hr * 0.78, hr * 0.68, hr * 0.78))
	_ell(f["ear_n"], head + side * hr * 0.45 - hf * hr * 0.05, hf, hu, side, Vector3(hr * 0.18, hr * 0.28, hr * 0.12))
	_ell(f["ear_f"], head - side * hr * 0.45 - hf * hr * 0.05, hf, hu, side, Vector3(hr * 0.18, hr * 0.28, hr * 0.12))
	for ek: String in ["n", "f"]:
		var zs := 1.0 if ek == "n" else -1.0
		var ep := head + hf * hr * 0.44 + hu * hr * 0.08 + side * zs * hr * 0.17
		_ell(f["eye_" + ek], ep + hf * hr * 0.02, hf, hu, side, Vector3(hr * 0.06, hr * (0.02 if r.ko else 0.08), hr * 0.08))
		_ell(f["brow_" + ek], ep + hu * hr * 0.11 + hf * hr * 0.03, hf, hu, side, Vector3(hr * 0.06, hr * 0.05, hr * 0.2))
	for ck: String in ["n", "f"]:
		var zs := 1.0 if ck == "n" else -1.0
		_ell(f["cheek_" + ck], head + hf * hr * 0.3 - hu * hr * 0.1 + side * zs * hr * 0.24, hf, hu, side, Vector3(hr * 0.3, hr * 0.26, hr * 0.26))
		var wm: MeshInstance3D = f["white_" + ck]
		var ep2 := head + hf * hr * 0.41 + hu * hr * 0.08 + side * zs * hr * 0.17
		_ell(wm, ep2, hf, hu, side, Vector3(hr * 0.06, hr * (0.02 if r.ko else 0.1), hr * 0.17))
	_ell(f["chin"], head - hu * hr * 0.5 + hf * hr * 0.3, hf, hu, side, Vector3(hr * 0.3, hr * 0.26, hr * 0.34))
	_ell(f["lips"], head - hu * hr * 0.27 + hf * hr * 0.44, hf, hu, side, Vector3(hr * 0.1, hr * 0.08, hr * 0.26))
	var nb: MeshInstance3D = f["nosebleed"]
	nb.visible = r.bruise > 0.6 and not is_ref
	if nb.visible:
		_seg(nb, head + hf * hr * 0.5 - hu * hr * 0.15, head + hf * hr * 0.48 - hu * hr * (0.35 + 0.3 * r.bruise), hr * 0.1)
	if f.has("glove_m"):
		(f["glove_m"] as StandardMaterial3D).albedo_color = r.glove.lerp(Color(0.42, 0.03, 0.03), clampf(r.glove_blood, 0.0, 0.8) * 0.6)
	_ell(f["nose"], head + hf * hr * 0.5 - hu * hr * 0.05, hf, hu, side, Vector3(hr * 0.2, hr * 0.26, hr * 0.15))
	_ell(f["hair"], head + hu * hr * 0.13 - hf * hr * 0.09, hf, hu, side, Vector3(hr * 1.0, hr * 1.0, hr * 0.96))
	_ell(f["beard"], head - hu * hr * 0.3 + hf * hr * 0.17, hf, hu, side, Vector3(hr * 0.72, hr * 0.6, hr * 0.8))
	# Corte, sangue escorrendo e olho inchado.
	var cut := r.cut
	var cm: MeshInstance3D = f["cut"]
	cm.visible = cut > 0.2
	(f["drip"] as MeshInstance3D).visible = cut > 0.35
	(f["chest_blood"] as MeshInstance3D).visible = cut > 0.8
	if cut > 0.2:
		var cp := head + hf * hr * 0.42 + hu * hr * 0.3 + side * hr * 0.12
		_ell(cm, cp, hf, hu, side, Vector3(hr * 0.12, hr * 0.12, hr * (0.12 + 0.15 * cut)))
		_seg(f["drip"], cp, head + hf * hr * 0.48 - hu * hr * (0.2 + 0.4 * minf(cut, 1.0)) + side * hr * 0.15, hr * 0.09 * (1.0 + cut))
		_seg(f["chest_blood"], neck + fw * depth * 0.45, chest_c + fw * depth * 0.5 - up * Uh * 0.5, Uh * 0.15)
	var bm: MeshInstance3D = f["bruise"]
	bm.visible = r.bruise > 0.25
	if bm.visible:
		(f["bruise_m"] as StandardMaterial3D).albedo_color = Color(0.38, 0.12, 0.2, clampf((r.bruise - 0.25) * 0.8, 0.0, 0.6))
		_ell(bm, head + hf * hr * 0.4 + hu * hr * 0.05 + side * hr * 0.17, hf, hu, side, Vector3(hr * 0.12, hr * 0.22, hr * 0.26) * (1.0 + 0.4 * r.bruise))


# --- Direção de TV ---------------------------------------------------------------------------

## Planos: aberto (geral alto), lateral (na altura da cintura, por fora da grade), fechado (perto
## e de lado) e de cima (no chão mostra bem quem está por cima). Corta de plano a cada poucos
## segundos, corta para o fechado no knockdown e no fim, e enquadra a dupla inteira sozinho
## (cabeça e pés sempre dentro).
const SHOTS := {
	"aberto": {"yaw": 0.2, "pitch": 17.0, "pad": 1.45},
	"lateral": {"yaw": -0.05, "pitch": 5.0, "pad": 1.3},
	"fechado": {"yaw": 0.55, "pitch": 9.0, "pad": 1.0},
	"cima": {"yaw": 0.1, "pitch": 64.0, "pad": 1.3},
	"replay1": {"yaw": -0.7, "pitch": 4.0, "pad": 1.25},
	"replay2": {"yaw": 1.0, "pitch": 10.0, "pad": 1.05},
}
var _shot := "aberto"
var _shot_left := 6.0
var _shot_n := 0
var _last_kd := false


func _pick_shot() -> String:
	var ground := String(brain.st.get("pos", "solto")) == "chao"
	_shot_n += 1
	var seq: Array = ["cima", "fechado", "aberto", "cima", "lateral"] if ground else ["aberto", "lateral", "fechado", "aberto", "fechado", "lateral"]
	return String(seq[_shot_n % seq.size()])


func _bbox() -> AABB:
	var box := AABB()
	var first := true
	for f: Dictionary in _figs:
		var r: Rig2D = f["rig"]
		var j := r.joints(0.0, 0.0, 1.0)
		for k: String in ["hip", "head", "neck", "na_wr", "fa_wr", "nl_an", "fl_an", "nl_kn", "fl_kn"]:
			var p := _v(j[k], float(r.pose.get("zz", 0.0)))
			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box.grow(0.35)


func _direct(delta: float) -> void:
	var cut := false
	var rep := brain.in_replay()
	var want := _shot
	if rep:
		want = "replay1" if brain.replay_take() == 0 else "replay2"
	elif brain._ended:
		want = "fechado"
	else:
		var kd: bool = String(brain._act.get("type", "")) == "kd"
		if kd and not _last_kd:
			want = "fechado"
			_shot_left = 3.0
		_last_kd = kd
		_shot_left -= delta
		var ground := String(brain.st.get("pos", "solto")) == "chao"
		if _shot_left <= 0.0 or (_shot == "cima" and not ground) or _shot.begins_with("replay"):
			want = _pick_shot()
			_shot_left = 4.5 + float(_shot_n % 3) * 1.5
	if want != _shot:
		_shot = want
		cut = true
	var sp: Dictionary = SHOTS[_shot]
	var box := _bbox()
	var c := box.get_center()
	var yaw := float(sp["yaw"])
	if _shot == "aberto":
		yaw += 0.2 * sin(_t * 0.08)
	elif _shot == "replay2":
		yaw += _t * 0.08
	var pitch := deg_to_rad(float(sp["pitch"]))
	var pad := float(sp["pad"])
	var aspect := maxf(0.5, float(_vp.size.x) / maxf(1.0, float(_vp.size.y)))
	var tv := tan(deg_to_rad(_cam.fov * 0.5))
	var dirv := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	# Tamanho da dupla visto deste ângulo.
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var upv := dirv.cross(right).normalized() * -1.0
	var hw := 0.0
	var hh := 0.0
	for i in 8:
		var corner := box.get_endpoint(i) - c
		hw = maxf(hw, absf(corner.dot(right)))
		hh = maxf(hh, absf(corner.dot(upv)))
	var dist := maxf(hh * pad / tv, hw * pad / (tv * aspect)) + box.size.length() * 0.05
	dist = clampf(dist, 5.5, 30.0)
	var tgt := c + dirv * dist
	tgt.y = maxf(tgt.y, 0.8)
	var k := 1.0 if cut else 1.0 - exp(-3.0 * delta)
	_cam_pos = _cam_pos.lerp(tgt, k)
	_cam_look = _cam_look.lerp(c, k)


# --- Quadro --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if brain == null or _figs.is_empty():
		return
	_t += delta
	for f: Dictionary in _figs:
		_pose_fighter(f)
	if _ref_fig.size() > 0:
		_pose_fighter(_ref_fig, -3.4)
	_direct(delta)
	var shake := Vector3(sin(_t * 70.0), cos(_t * 53.0), 0) * brain._shake * 0.25
	_cam.look_at_from_position(_cam_pos + shake, _cam_look + shake * 0.5)
	var cflat := Vector3(_cam_pos.x, 0, _cam_pos.z)
	var lflat := Vector3(_cam_look.x, 0, _cam_look.z)
	var outside := cflat.length() > R_OCT * 0.8
	for fs: Array in _fence:
		var ctr: Vector3 = fs[1]
		var hide := outside and (ctr - lflat).normalized().dot((cflat - lflat).normalized()) > 0.55 and _cam_pos.y < FENCE_H + 6.0
		for m: MeshInstance3D in fs[0]:
			m.visible = not hide
	if _canvas_label != null:
		_canvas_label.modulate.a = 0.55
	# Brilho dos golpes, gotas de sangue e manchas na lona.
	var fxl: Array = brain._fx
	var hits: Array = fxl.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "hit")
	for i in _fx.size():
		var m: MeshInstance3D = _fx[i]
		if i < hits.size():
			var e: Dictionary = hits[i]
			var t := float(e["t"])
			m.visible = true
			m.position = Vector3(float(e["x"]), float(e["y"]), 0.6)
			m.scale = Vector3.ONE * (0.4 + float(e["pw"]) * 0.5) * (0.6 + t * 4.0)
			(m.material_override as StandardMaterial3D).albedo_color = Color(1, 0.95, 0.7, clampf(0.8 - t * 1.8, 0.0, 0.8))
		else:
			m.visible = false
	var drops: Array = []
	for e: Dictionary in fxl:
		if String(e["kind"]) != "blood":
			continue
		var t := float(e["t"])
		var sd := int(e["seed"])
		for i in 9:
			var a := -0.9 + float((sd + i * 37) % 100) / 100.0 * 1.2
			var sp := 2.5 + float((sd * 3 + i * 17) % 100) / 40.0
			var p := Vector3(float(e["x"]) + cos(a) * float(e["v"]) * sp * t, float(e["y"]) - sin(a) * sp * t - 14.0 * t * t, 0.3 + float(i % 3 - 1) * 0.5 * t)
			if p.y > 0.0:
				drops.append([p, (0.07 + 0.05 * float(i % 3)) * float(e["pw"]) * 0.9])
	for i in _drops.size():
		var dm: MeshInstance3D = _drops[i]
		dm.visible = i < drops.size()
		if dm.visible:
			dm.position = drops[i][0]
			dm.scale = Vector3.ONE * float(drops[i][1])
	for i in _stains.size():
		var sm: MeshInstance3D = _stains[i]
		sm.visible = i < brain.stains.size()
		if sm.visible:
			var stn: Dictionary = brain.stains[i]
			var w := float(stn["w"]) * 2.0
			sm.position = Vector3(float(stn["x"]), 0.012 + float(i) * 0.0004, lerpf(1.6, -2.4, float(stn["z"])))
			sm.scale = Vector3(w, 1.0, w * 0.8)
	_cap.text = brain._caption if brain._caption_t > 0.0 else ""
	_rep.visible = brain.in_replay()
	_rep.text = "● REPLAY" if brain.replay_take() <= 0 else "● REPLAY · CÂMERA LENTA"
