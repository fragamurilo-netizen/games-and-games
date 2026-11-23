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


func setup(brain_: FightStage2D, org_color: Color = Color("#C8102E")) -> void:
	brain = brain_
	_org = org_color
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
	sun.light_energy = 0.95
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
	_add(fl, _mat(Color("#A39F96"), 0.95), Vector3(0, -0.2, 0), deg_to_rad(22.5))
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
	var lm := _mat(Color(_org, 1.0).lerp(Color("#A39F96"), 0.78))
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
		_add(pad, _mat(Color("#121317")), Vector3(sin(a) * apothem, FENCE_H + 0.2, cos(a) * apothem), a)
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
		_add(post, _mat(pc), Vector3(sin(va) * R_OCT, (FENCE_H + 0.6) * 0.5, cos(va) * R_OCT))
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


# --- Lutadores -----------------------------------------------------------------------------

func _build_fighter(r: Rig2D) -> Dictionary:
	var f := {"rig": r}
	var skin := _mat(r.skin, 0.6)
	var shorts := _mat(r.shorts, 0.85)
	var trim := _mat(r.trim, 0.7)
	var glove := _mat(r.glove, 0.45)
	var hair := _mat(r.hair, 0.9)
	f["skin"] = skin
	var cap := CapsuleMesh.new()
	cap.radius = 0.5
	cap.height = 1.0
	cap.radial_segments = 12
	cap.rings = 4
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	sph.radial_segments = 16
	sph.rings = 8
	var box := BoxMesh.new()
	for k: String in ["na_u", "na_f", "fa_u", "fa_f", "nl_t", "nl_s", "fl_t", "fl_s"]:
		f[k] = _part(cap, skin)
	for k: String in ["na_g", "fa_g"]:
		f[k] = _part(sph, glove)
	for k: String in ["nl_ft", "fl_ft"]:
		f[k] = _part(box, skin)
	for k: String in ["nl_sh", "fl_sh"]:
		f[k] = _part(cap, shorts)
	f["torso"] = _part(cap, skin)
	f["chest"] = _part(sph, skin)
	f["hips"] = _part(sph, shorts)
	f["band"] = _part(CylinderMesh.new(), trim)
	f["neck"] = _part(cap, skin)
	f["head"] = _part(sph, skin)
	f["hair"] = _part(sph, hair)
	(f["hair"] as MeshInstance3D).visible = not r.bald
	f["beard"] = _part(sph, _mat(r.beard, 0.9))
	(f["beard"] as MeshInstance3D).visible = r.has_beard
	f["nose"] = _part(box, skin)
	if r.fem:
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


## Coloca um membro (cápsula de altura 1) entre dois pontos, com grossura `w`.
static func _seg(mi: MeshInstance3D, a: Vector3, b: Vector3, w: float) -> void:
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
	mi.transform = Transform3D(Basis(x * w, y * (l + w * 0.8), z * w), (a + b) * 0.5)


static func _blob(mi: MeshInstance3D, c: Vector3, s: Vector3, up: Vector3 = Vector3.UP) -> void:
	var y := up.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	mi.transform = Transform3D(Basis(x * s.x, y * s.y, z * s.z), c)


func _pose_fighter(f: Dictionary) -> void:
	var r: Rig2D = f["rig"]
	var j := r.joints(0.0, 0.0, 1.0)
	var Uh: float = j["U"]
	var skin: StandardMaterial3D = f["skin"]
	skin.albedo_color = r.skin.lerp(Color(0.8, 0.22, 0.18), r.flash * 0.35)
	var sw := 0.62 * r.chest_k * Uh
	var hw := 0.36 * Uh
	var aw := 0.62 * r.arm_k * Uh
	var lw := 0.85 * r.leg_k * Uh
	var hip := _v(j["hip"], 0.0)
	var neck := _v(j["neck"], 0.0)
	var sh := _v(j["sh"], 0.0)
	var up := (neck - hip).normalized()
	for side: String in ["na", "fa"]:
		var z := sw if side == "na" else -sw
		var s := sh + Vector3(0, 0, z)
		var el := _v(j[side + "_el"], z * 1.05)
		var wr := _v(j[side + "_wr"], z * 0.8)
		_seg(f[side + "_u"], s, el, aw)
		_seg(f[side + "_f"], el, wr, aw * 0.82)
		var gd := (wr - el).normalized()
		_blob(f[side + "_g"], wr + gd * Uh * 0.18, Vector3.ONE * Uh * 0.72, gd)
	for side: String in ["nl", "fl"]:
		var z := hw if side == "nl" else -hw
		var h := hip + Vector3(0, 0, z)
		var kn := _v(j[side + "_kn"], z)
		var an := _v(j[side + "_an"], z)
		var toe := _v(j[side + "_toe"], z)
		_seg(f[side + "_t"], h, kn, lw)
		_seg(f[side + "_s"], kn, an, lw * 0.62)
		_seg(f[side + "_ft"], an, toe, lw * 0.42)
		_seg(f[side + "_sh"], h - up * Uh * 0.1, h.lerp(kn, 0.5), lw * 1.18)
	# Tronco: cintura até o peito, e o peito mais largo.
	var depth := 0.95 * Uh * r.chest_k * (1.0 + 0.3 * r.belly)
	var chest_c := neck - up * Uh * 0.75
	var tx := up.cross(Vector3.BACK).normalized()
	var tz := tx.cross(up).normalized()
	var tl := hip.distance_to(neck)
	(f["torso"] as MeshInstance3D).transform = Transform3D(Basis(tx * depth, up * (tl + 0.2), tz * (sw * 1.6)), hip.lerp(neck, 0.47))
	(f["chest"] as MeshInstance3D).transform = Transform3D(Basis(tx * depth * 1.05, up * Uh * 1.35, tz * sw * 2.25), chest_c + up * Uh * 0.1)
	(f["hips"] as MeshInstance3D).transform = Transform3D(Basis(tx * depth * 1.0, up * Uh * 0.95, tz * hw * 3.0), hip + up * Uh * 0.15)
	(f["band"] as MeshInstance3D).transform = Transform3D(Basis(tx * depth * 1.02, up * Uh * 0.1, tz * hw * 3.05), hip + up * Uh * 0.55)
	if f.has("top"):
		(f["top"] as MeshInstance3D).transform = Transform3D(Basis(tx * depth * 1.08, up * Uh * 0.8, tz * sw * 2.3), chest_c + up * Uh * 0.05)
	# Pescoço e cabeça (nariz para onde ele olha).
	var head := _v(j["head"], 0.0)
	_seg(f["neck"], neck - up * Uh * 0.1, head, Uh * 0.48 * r.chest_k)
	var hu := (head - neck).normalized()
	var fw := Vector3(-hu.y, hu.x, 0) * r.dir
	if fw.x * r.dir < 0.0:
		fw = -fw
	var hr := Uh * 1.0
	_blob(f["head"], head, Vector3(hr * 1.0, hr * 1.12, hr * 0.92), hu)
	_blob(f["hair"], head + hu * Uh * 0.12 - fw * Uh * 0.06, Vector3(hr * 1.04, hr * 1.02, hr * 0.97), hu)
	_blob(f["beard"], head - hu * Uh * 0.22 + fw * Uh * 0.12, Vector3(hr * 0.85, hr * 0.7, hr * 0.85), hu)
	_seg(f["nose"], head + fw * Uh * 0.42 + hu * Uh * 0.02, head + fw * Uh * 0.56 - hu * Uh * 0.08, Uh * 0.14)


# --- Quadro --------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if brain == null or _figs.is_empty():
		return
	_t += delta
	for f: Dictionary in _figs:
		_pose_fighter(f)
	# Câmera de TV: por fora da grade, alta, acompanhando a dupla e girando devagar; chega mais
	# perto no chão e nos momentos grandes.
	var mid := ((brain.rigs[0] as Rig2D).px + (brain.rigs[1] as Rig2D).px) * 0.5
	var ground := String(brain.st.get("pos", "solto")) == "chao"
	var big := brain._caption_t > 0.0 and brain._caption_t < 10.0
	var dist := 14.0
	var look_y := 3.6
	var lift := 3.2
	if ground:
		dist = 13.0
		look_y = 1.4
		lift = 4.6
	if big:
		dist -= 2.5
	if brain._ended:
		dist = 13.0
		look_y = 3.0
		lift = 3.0
	var ang := 0.28 * sin(_t * 0.09) + 0.12
	var tgt := Vector3(mid + sin(ang) * dist, look_y + lift, cos(ang) * dist)
	var k := 1.0 - exp(-2.0 * delta)
	_cam_pos = _cam_pos.lerp(tgt, k)
	_cam_look = _cam_look.lerp(Vector3(mid, look_y, 0), k)
	var shake := Vector3(sin(_t * 70.0), cos(_t * 53.0), 0) * brain._shake * 0.25
	_cam.look_at_from_position(_cam_pos + shake, _cam_look + shake * 0.5)
	# Brilho dos golpes que entram.
	var fxl: Array = brain._fx
	for i in _fx.size():
		var m: MeshInstance3D = _fx[i]
		if i < fxl.size() and String((fxl[i] as Dictionary)["kind"]) == "hit":
			var e: Dictionary = fxl[i]
			var t := float(e["t"])
			m.visible = true
			m.position = Vector3(float(e["x"]), float(e["y"]), 0.6)
			m.scale = Vector3.ONE * (0.4 + float(e["pw"]) * 0.5) * (0.6 + t * 4.0)
			(m.material_override as StandardMaterial3D).albedo_color = Color(1, 0.95, 0.7, clampf(0.8 - t * 1.8, 0.0, 0.8))
		else:
			m.visible = false
	_cap.text = brain._caption if brain._caption_t > 0.0 else ""
