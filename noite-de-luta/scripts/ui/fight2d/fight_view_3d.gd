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
	env.ambient_light_color = Color(0.5, 0.54, 0.66)
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.8
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.07
	env.adjustment_saturation = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	# Luz de recorte: vem de trás e do alto, fria, e solta os lutadores do fundo escuro.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-32, 200, 0)
	rim.light_energy = 0.34
	rim.light_color = Color(0.72, 0.82, 1.0)
	rim.shadow_enabled = false
	_vp.add_child(rim)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 0.5
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	_vp.add_child(sun)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 14, 10)
	fill.omni_range = 40.0
	fill.light_energy = 0.2
	_vp.add_child(fill)
	# Lona: octógono claro com o anel e a marca no centro.
	var fl := CylinderMesh.new()
	fl.top_radius = R_OCT
	fl.bottom_radius = R_OCT
	fl.height = 0.4
	fl.radial_segments = 8
	_add(fl, _mat(Color("#62666E"), 0.92), Vector3(0, -0.2, 0), deg_to_rad(22.5))
	var apron := CylinderMesh.new()
	apron.top_radius = R_OCT + 3.0
	apron.bottom_radius = R_OCT + 3.0
	apron.height = 0.4
	apron.radial_segments = 8
	_add(apron, _mat(Color("#16181D")), Vector3(0, -0.45, 0), deg_to_rad(22.5))
	# Pintura da lona em camadas finas: faixa na cor da liga junto à grade, a lona por dentro, o
	# anel e o disco do centro com a marca.
	var canvas := Color("#62666E")
	for lay: Array in [[R_OCT - 0.12, 8, _org.darkened(0.5), 0.01], [R_OCT - 1.7, 8, canvas, 0.02], [6.2, 48, _org.darkened(0.42), 0.03], [5.3, 48, Color(_org, 1.0).darkened(0.3).lerp(canvas, 0.72), 0.04]]:
		var lc := CylinderMesh.new()
		lc.top_radius = float(lay[0])
		lc.bottom_radius = float(lay[0])
		lc.height = 0.01
		lc.radial_segments = int(lay[1])
		var lmi := _add(lc, _mat(lay[2], 0.92), Vector3(0, float(lay[3]) - 0.005, 0), deg_to_rad(22.5) if int(lay[1]) == 8 else 0.0)
		lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
		# Rodapé acolchoado com a faixa da liga.
		var base := BoxMesh.new()
		base.size = Vector3(side, 0.55, 0.4)
		var bm0 := _add(base, _mat(Color("#101116")), Vector3(sin(a) * (apothem + 0.05), 0.27, cos(a) * (apothem + 0.05)), a)
		var stripe := BoxMesh.new()
		stripe.size = Vector3(side, 0.09, 0.42)
		var sm0 := _add(stripe, _mat(_org.darkened(0.1)), Vector3(sin(a) * (apothem + 0.05), 0.5, cos(a) * (apothem + 0.05)), a)
		_fence.append([[p, pm, bm0, sm0], Vector3(sin(a) * apothem, 0, cos(a) * apothem)])
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
	# Arquibancada: um anel inclinado em volta do octógono, com a torcida sentada (corpo e cabeça).
	var bowl := CylinderMesh.new()
	bowl.top_radius = R_OCT + 18.0
	bowl.bottom_radius = R_OCT + 5.2
	bowl.height = 6.6
	bowl.radial_segments = 32
	bowl.cap_top = false
	bowl.cap_bottom = false
	var bowl_m := _mat(Color("#0C0D11"), 1.0)
	bowl_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_add(bowl, bowl_m, Vector3(0, 2.7, 0)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var spots: Array = []
	for row in 7:
		var r := R_OCT + 6.0 + float(row) * 1.6
		var cnt := int(TAU * r / 1.15)
		for i in cnt:
			var a := TAU * float(i) / float(cnt) + rng.randf() * 0.02
			spots.append([Vector3(sin(a) * r, 0.2 + float(row) * 0.9 + rng.randf() * 0.25, cos(a) * r), a])
	var n := spots.size()
	var person := BoxMesh.new()
	person.size = Vector3(0.95, 1.25, 0.6)
	var head_m := SphereMesh.new()
	head_m.radius = 0.3
	head_m.height = 0.64
	head_m.radial_segments = 8
	head_m.rings = 4
	var skins := [Color("#C99E7C"), Color("#8E6243"), Color("#E0B896"), Color("#5E3D28"), Color("#B5825C")]
	var shirts := [Color("#3A3F4C"), Color("#2B2E38"), Color("#6A2A32"), Color("#27384F"), Color("#8A8D96"), Color("#3E4A3A"), Color("#B5B2AA"), Color("#4A3A52")]
	for part in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = person if part == 0 else head_m
		mm.instance_count = n
		for i in n:
			var s: Array = spots[i]
			var pos: Vector3 = s[0]
			if part == 1:
				pos += Vector3(0, 0.95, 0)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(s[1])), pos))
			var lum := rng.randf_range(0.3, 0.62)
			var c: Color = (shirts[rng.randi() % shirts.size()] if part == 0 else skins[rng.randi() % skins.size()])
			mm.set_instance_color(i, Color(c.r * lum, c.g * lum, c.b * lum))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var cm := StandardMaterial3D.new()
		cm.vertex_color_use_as_albedo = true
		cm.roughness = 1.0
		mmi.material_override = cm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_vp.add_child(mmi)
	# Telões em cima da arquibancada, com o nome do evento e as cores dos dois corners.
	var screen_m := StandardMaterial3D.new()
	screen_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen_m.albedo_color = Color(0.05, 0.07, 0.12).lerp(_org, 0.12)
	for sa: float in [PI, PI - 1.05, PI + 1.05]:
		var sr := R_OCT + 18.5
		var sq := QuadMesh.new()
		sq.size = Vector2(11.0, 4.6)
		var sp0 := Vector3(sin(sa) * sr, 10.2, cos(sa) * sr)
		var smi := _add(sq, screen_m, sp0, sa + PI)
		smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var frame := BoxMesh.new()
		frame.size = Vector3(11.5, 5.1, 0.3)
		_add(frame, _mat(Color("#0A0B0E")), sp0 * 1.01, sa + PI).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var inward := -Vector3(sin(sa), 0, cos(sa))
		for cs in 2:
			var bar := QuadMesh.new()
			bar.size = Vector2(5.2, 0.35)
			var bmat := StandardMaterial3D.new()
			bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bmat.albedo_color = (UIColors.CORNER_RED if cs == 0 else UIColors.CORNER_BLUE)
			var right := Vector3.UP.cross(inward).normalized()
			_add(bar, bmat, sp0 + inward * 0.05 + Vector3(0, -1.75, 0) + right * (-2.7 if cs == 0 else 2.7), sa + PI).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sl := Label3D.new()
		sl.text = (_logo if _logo != "" else "Noite de Luta").to_upper()
		sl.font_size = 110
		sl.pixel_size = 0.016
		sl.outline_size = 0
		sl.modulate = Color(0.96, 0.95, 0.92)
		sl.width = 620.0
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.position = sp0 + inward * 0.08 + Vector3(0, 0.35, 0)
		sl.rotation.y = sa + PI
		_vp.add_child(sl)
	# Nome do evento pintado na lona.
	if _logo != "":
		_canvas_label = Label3D.new()
		_canvas_label.text = _logo.to_upper()
		_canvas_label.font_size = 160
		_canvas_label.pixel_size = 0.012
		_canvas_label.outline_size = 0
		_canvas_label.modulate = Color(1, 1, 1, 0.55)
		_canvas_label.rotation_degrees = Vector3(-90, 0, 0)
		_canvas_label.position = Vector3(0, 0.062, 0)
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
	beam.albedo_color = Color(1.0, 0.95, 0.85, 0.016)
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
		sp.light_energy = 0.42
		sp.light_color = Color(1.0, 0.96, 0.9)
		_vp.add_child(sp)
		sp.look_at_from_position(sp.position, Vector3(0, 0, 0))
	_cam = Camera3D.new()
	_cam.fov = 38.0
	_cam.near = 0.3
	_cam.far = 400.0
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


## Monta o boneco: o corpo é uma malha contínua com esqueleto (Body3D: tronco, braços, pernas,
## pés, calção e cabeça); por cima vão as peças soltas: luvas com polegar e punho do corner,
## orelhas, olhos, sobrancelhas, nariz, boca, cabelo, barba, corte e inchaço.
func _build_fighter(r: Rig2D) -> Dictionary:
	var f := {"rig": r}
	var is_ref := r.outfit == "ref"
	f["body"] = Body3D.build(r, _vp)
	var skin := _mat(Body3D.skin_tone(r.skin), 0.55)
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
	var sph := _sphere()
	var box := BoxMesh.new()
	if not is_ref:
		for sd: String in ["na", "fa"]:
			f[sd + "_g"] = _part(sph, glove)
			f[sd + "_th"] = _part(sph, glove)
			f[sd + "_fing"] = _part(sph, skin)
			f[sd + "_band"] = _part(_taper(1.0), band)
	else:
		f["badge"] = _part(box, _mat(Color("#E8E6E0"), 0.6))
	f["lips"] = _part(sph, _mat(Body3D.skin_tone(r.skin).darkened(0.3).lerp(Color(0.55, 0.25, 0.25), 0.3), 0.5))
	f["white_n"] = _part(sph, _mat(Color(0.92, 0.9, 0.86), 0.3))
	f["white_f"] = _part(sph, _mat(Color(0.92, 0.9, 0.86), 0.3))
	f["nosebleed"] = _part(_taper(0.5), blood)
	f["ear_n"] = _part(sph, skin)
	f["ear_f"] = _part(sph, skin)
	f["eye_n"] = _part(sph, dark)
	f["eye_f"] = _part(sph, dark)
	f["brow_n"] = _part(box, hair)
	f["brow_f"] = _part(box, hair)
	f["nose"] = _part(sph, skin)
	# Cabelo pelo volume do penteado (HairShape): calota, parte que cai na nuca, coque/rabo.
	var hs: Dictionary = r.hair_shape
	var bun := int(hs.get("bun", 0))
	f["hair"] = _part(sph, hair)
	(f["hair"] as MeshInstance3D).visible = not r.bald
	f["hair_back"] = _part(sph, _mat(r.hair.darkened(0.12), 0.95))
	(f["hair_back"] as MeshInstance3D).visible = not r.bald and (float(hs.get("back", 0.0)) >= 0.2 or bun == HairShape.BUN_TAIL)
	f["bun"] = _part(sph, hair)
	(f["bun"] as MeshInstance3D).visible = not r.bald and bun in [HairShape.BUN_TOP, HairShape.BUN_LOW, HairShape.BUN_PUFFS]
	f["bun2"] = _part(sph, hair)
	(f["bun2"] as MeshInstance3D).visible = not r.bald and bun == HairShape.BUN_PUFFS
	# Barba pelo tipo: sombra por fazer, bigode, cavanhaque, curta, média e longa.
	var bmat := _mat(r.beard, 0.95)
	f["beard"] = _part(sph, bmat)
	(f["beard"] as MeshInstance3D).visible = r.beard_kind >= HairShape.BD_GOATEE
	f["stache"] = _part(sph, bmat)
	(f["stache"] as MeshInstance3D).visible = r.beard_kind >= HairShape.BD_MUSTACHE
	var stub := _mat(Color(r.beard, 0.32), 0.95)
	stub.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	f["stubble"] = _part(sph, stub)
	(f["stubble"] as MeshInstance3D).visible = r.beard_kind == HairShape.BD_STUBBLE
	f["cut"] = _part(sph, blood)
	f["drip"] = _part(_taper(0.4), blood)
	f["chest_blood"] = _part(_taper(0.5), blood)
	f["bruise"] = _part(sph, bruise)
	f["phase"] = randf() * TAU
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
	var body: Body3D = f["body"]
	var j := r.joints(0.0, 0.0, 1.0)
	var Uh: float = j["U"]
	var is_ref := r.outfit == "ref"
	var tint := Color.WHITE.lerp(Color(1.0, 0.5, 0.45), r.flash * 0.45)
	body.mat.albedo_color = tint
	var skin: StandardMaterial3D = f["skin"]
	skin.albedo_color = Body3D.skin_tone(r.skin) * tint
	var zz := zoff + float(r.pose.get("zz", 0.0))
	var lz := 1.0 + float(r.pose.get("lz", 0.0))
	var az := 1.0 + float(r.pose.get("az", 0.0))
	var sw := body.sw
	var hw := body.hw * lz
	var hip := _v(j["hip"], zz)
	var neck := _v(j["neck"], zz)
	var sh := _v(j["sh"], zz)
	var tf := _frame(neck - hip, r.dir)
	var fw: Vector3 = tf[0]
	var up: Vector3 = tf[1]
	var side: Vector3 = Vector3.BACK
	# Tronco: o peito gira mais que o quadril (direto, gancho, chute), a cintura torce no meio.
	var tw := deg_to_rad(float(r.pose.get("tw", 0.0)))
	var rear := r.rear()
	var base := Basis(fw, up, fw.cross(up).normalized())
	var phi := r.dir * (1.0 if rear == "n" else -1.0) * tw
	var bc := Basis(up, phi) * base
	var bp := Basis(up, phi * 0.6) * base
	var breath := 1.0 + 0.014 * sin(_t * 2.6 + float(f["phase"]))
	body.pose_block(Body3D.B_PELVIS, hip, bp)
	body.pose_block(Body3D.B_CHEST, neck, bc, Vector3(breath, 1.0, breath))
	var arm_len := (Rig2D.L_UARM + Rig2D.L_FARM) * Uh
	for s in 2:
		var zl := 1.0 if s == 0 else -1.0
		var near := r.dir * zl > 0.0
		var sd := "na" if near else "fa"
		# Braço: o ombro acompanha o giro do peito; o soco esticado fecha no centro.
		var sg := 1.0 if sd.begins_with(rear) else -1.0
		var fo := fw * sin(tw) * sw * sg
		var z := (sw if near else -sw) * az * cos(tw)
		var s0 := sh + bc * Vector3(0, 0, zl * sw)
		var reach := clampf(((j[sd + "_wr"] as Vector2).distance_to(j["sh"]) / arm_len - 0.6) / 0.35, 0.0, 1.0)
		var el := _v(j[sd + "_el"], zz + z * 1.08) + fo
		var wr := _v(j[sd + "_wr"], zz + z * 0.85 * (1.0 - 0.85 * reach)) + fo
		var bend := (s0 + wr) * 0.5 - el
		var hint := bend * 4.0 + fw * 0.2 + up * 0.1
		var flex := clampf(1.0 - s0.distance_to(wr) / arm_len, 0.0, 1.0)
		body.pose_limb(Body3D.side_bone(s, Body3D.P_UARM), s0, el, hint, 1.0 + 0.07 * flex)
		body.pose_limb(Body3D.side_bone(s, Body3D.P_FARM), el, wr, hint)
		if not is_ref:
			# Luva de MMA: almofada nos nós dos dedos, dedos dobrados por baixo, polegar e punho.
			var gd := (wr - el).normalized()
			var gf := _frame(gd, r.dir)
			_ell(f[sd + "_g"], wr + gd * Uh * 0.2 + (gf[0] as Vector3) * Uh * 0.05, gf[0], gd, side, Vector3(Uh * 0.48, Uh * 0.56, Uh * 0.52))
			_ell(f[sd + "_fing"], wr + gd * Uh * 0.27 - (gf[0] as Vector3) * Uh * 0.14, gf[0], gd, side, Vector3(Uh * 0.26, Uh * 0.32, Uh * 0.44))
			_ell(f[sd + "_th"], wr + gd * Uh * 0.1 + (gf[0] as Vector3) * Uh * 0.2, gf[0], gd, side, Vector3(Uh * 0.2, Uh * 0.32, Uh * 0.2))
			_seg(f[sd + "_band"], wr - gd * Uh * 0.14, wr + gd * Uh * 0.02, Uh * 0.36)
		# Perna: o quadril gira menos; a perna que sobe (chute, joelhada) fecha para o centro.
		var ld := "nl" if near else "fl"
		var lsg := 1.0 if ld.begins_with(rear) else -1.0
		var lfo := fw * sin(tw * 0.6) * hw * lsg
		var lzv := (hw if near else -hw) * cos(tw * 0.6)
		var h0 := hip + bp * Vector3(0, 0, zl * body.hw * minf(lz, 1.25))
		var rise := clampf(((j[ld + "_an"] as Vector2).y * -1.0 - (-(j["hip"] as Vector2).y - 3.2 * Uh)) / (2.6 * Uh), 0.0, 1.0)
		var kn := _v(j[ld + "_kn"], zz + lzv * 1.05 * (1.0 - 0.5 * rise)) + lfo
		var an := _v(j[ld + "_an"], zz + lzv * (1.0 - 0.8 * rise)) + lfo
		var toe := _v(j[ld + "_toe"], zz + lzv * (1.0 - 0.8 * rise) + signf(lzv) * 0.12 * Uh * (1.0 - rise)) + lfo
		var lhint := (kn - (h0 + an) * 0.5) * 4.0 + fw * 0.2
		body.pose_limb(Body3D.side_bone(s, Body3D.P_THIGH), h0, kn, lhint)
		body.pose_limb(Body3D.side_bone(s, Body3D.P_SHIN), kn, an, lhint)
		body.pose_limb(Body3D.side_bone(s, Body3D.P_FOOT), an, toe, kn - an)
	var depth := 0.92 * Uh * (0.88 + 0.12 * r.chest_k)
	var chest_c := neck - up * Uh * 0.6
	if is_ref:
		_ell(f["badge"], chest_c + up * Uh * 0.1 + fw * depth * 0.5 + side * sw * 0.5, fw, up, side, Vector3(0.05, Uh * 0.28, Uh * 0.36))
	# Cabeça
	var head := _v(j["head"], zz)
	var hfr := _frame(head - neck, r.dir)
	var hf: Vector3 = hfr[0]
	var hu: Vector3 = hfr[1]
	var hr := Uh
	body.pose_block(Body3D.B_HEAD, head, Basis(hf, hu, hf.cross(hu).normalized()))
	_ell(f["ear_n"], head + side * hr * 0.44 - hf * hr * 0.05 - hu * hr * 0.04, hf, hu, side, Vector3(hr * 0.16, hr * 0.26, hr * 0.1))
	_ell(f["ear_f"], head - side * hr * 0.44 - hf * hr * 0.05 - hu * hr * 0.04, hf, hu, side, Vector3(hr * 0.16, hr * 0.26, hr * 0.1))
	for ek: String in ["n", "f"]:
		var zs := 1.0 if ek == "n" else -1.0
		var ep := head + hf * hr * 0.4 + hu * hr * 0.08 + side * zs * hr * 0.17
		_ell(f["eye_" + ek], ep + hf * hr * 0.02, hf, hu, side, Vector3(hr * 0.06, hr * (0.02 if r.ko else 0.07), hr * 0.07))
		_ell(f["brow_" + ek], ep + hu * hr * 0.1 + hf * hr * 0.035, hf, hu, side, Vector3(hr * 0.06, hr * 0.045, hr * 0.2))
		var wm: MeshInstance3D = f["white_" + ek]
		_ell(wm, ep - hf * hr * 0.005, hf, hu, side, Vector3(hr * 0.06, hr * (0.02 if r.ko else 0.085), hr * 0.15))
	_ell(f["lips"], head - hu * hr * 0.3 + hf * hr * 0.41, hf, hu, side, Vector3(hr * 0.09, hr * 0.07, hr * 0.24))
	var nb: MeshInstance3D = f["nosebleed"]
	nb.visible = r.bruise > 0.6 and not is_ref
	if nb.visible:
		_seg(nb, head + hf * hr * 0.48 - hu * hr * 0.17, head + hf * hr * 0.45 - hu * hr * (0.35 + 0.3 * r.bruise), hr * 0.1)
	if f.has("glove_m"):
		(f["glove_m"] as StandardMaterial3D).albedo_color = r.glove.lerp(Color(0.42, 0.03, 0.03), clampf(r.glove_blood, 0.0, 0.8) * 0.6)
	_ell(f["nose"], head + hf * hr * 0.47 - hu * hr * 0.07, hf, hu, side, Vector3(hr * 0.2, hr * 0.26, hr * 0.14))
	# Cabelo: a calota cresce no alto e nos lados conforme o penteado; laterais raspadas deixam
	# só o alto, o moicano vira uma crista e o cabelo comprido cai na nuca com a gravidade.
	var hs: Dictionary = r.hair_shape
	if not r.bald and not hs.is_empty():
		var top := float(hs["top"])
		var sdk := float(hs["side"])
		var back := float(hs["back"])
		if bool(hs["ridge"]):
			_ell(f["hair"], head + hu * hr * (0.14 + top * 0.5) - hf * hr * 0.08, hf, hu, side, Vector3(hr * 1.0, hr * (0.95 + top * 1.3), hr * 0.22))
		else:
			_ell(f["hair"], head + hu * hr * (0.1 + (top - 0.03) * 0.55) - hf * hr * (0.06 + (sdk - 0.026) * 0.7), hf, hu, side,
				Vector3(hr * (0.97 + (sdk - 0.026) * 1.35), hr * (0.95 + (top - 0.03) * 0.9), hr * (0.91 + (sdk - 0.026) * 1.35)))
		var gu := (hu * 0.45 + Vector3.UP * 0.55).normalized()
		var gf := (hf - gu * hf.dot(gu)).normalized()
		var bun := int(hs["bun"])
		if bun == HairShape.BUN_TAIL:
			_ell(f["hair_back"], head - hf * hr * 0.6 - gu * hr * 0.22 + hu * hr * 0.15, gf, gu, side, Vector3(hr * 0.24, hr * 0.85, hr * 0.24))
		elif back >= 0.2:
			_ell(f["hair_back"], head - hf * hr * (0.3 + sdk * 0.5) - gu * hr * (0.22 + back * 0.32), gf, gu, side, Vector3(hr * (0.6 + sdk), hr * (0.7 + back * 0.78), hr * (0.84 + sdk * 1.2)))
		var puff := bool(hs["curly"])
		if bun == HairShape.BUN_TOP:
			_ell(f["bun"], head + hu * hr * (0.6 if not puff else 0.66) - hf * hr * 0.2, hf, hu, side, Vector3.ONE * hr * (0.34 if not puff else 0.62))
		elif bun == HairShape.BUN_LOW:
			_ell(f["bun"], head - hf * hr * 0.52 - hu * hr * 0.14, hf, hu, side, Vector3.ONE * hr * 0.33)
		elif bun == HairShape.BUN_PUFFS:
			var sv := hf.cross(hu).normalized()
			_ell(f["bun"], head + hu * hr * 0.5 + sv * hr * 0.34 - hf * hr * 0.05, hf, hu, side, Vector3.ONE * hr * 0.46)
			_ell(f["bun2"], head + hu * hr * 0.5 - sv * hr * 0.34 - hf * hr * 0.05, hf, hu, side, Vector3.ONE * hr * 0.46)
	match r.beard_kind:
		HairShape.BD_GOATEE:
			_ell(f["beard"], head - hu * hr * 0.44 + hf * hr * 0.3, hf, hu, side, Vector3(hr * 0.34, hr * 0.36, hr * 0.38))
		HairShape.BD_SHORT:
			_ell(f["beard"], head - hu * hr * 0.31 + hf * hr * 0.13, hf, hu, side, Vector3(hr * 0.72, hr * 0.5, hr * 0.76))
		HairShape.BD_MEDIUM:
			_ell(f["beard"], head - hu * hr * 0.35 + hf * hr * 0.13, hf, hu, side, Vector3(hr * 0.75, hr * 0.62, hr * 0.79))
		HairShape.BD_LONG:
			_ell(f["beard"], head - hu * hr * 0.5 + hf * hr * 0.16, hf, hu, side, Vector3(hr * 0.72, hr * 0.98, hr * 0.74))
		HairShape.BD_STUBBLE:
			_ell(f["stubble"], head - hu * hr * 0.3 + hf * hr * 0.12, hf, hu, side, Vector3(hr * 0.73, hr * 0.5, hr * 0.775))
	if r.beard_kind >= HairShape.BD_MUSTACHE:
		_ell(f["stache"], head - hu * hr * 0.215 + hf * hr * 0.425, hf, hu, side, Vector3(hr * 0.1, hr * 0.075, hr * 0.3))
	# Corte, sangue escorrendo e olho inchado.
	var cut := r.cut
	var cm: MeshInstance3D = f["cut"]
	cm.visible = cut > 0.2
	(f["drip"] as MeshInstance3D).visible = cut > 0.35
	(f["chest_blood"] as MeshInstance3D).visible = cut > 0.8
	if cut > 0.2:
		var cp := head + hf * hr * 0.4 + hu * hr * 0.28 + side * hr * 0.12
		_ell(cm, cp, hf, hu, side, Vector3(hr * 0.12, hr * 0.12, hr * (0.12 + 0.15 * cut)))
		_seg(f["drip"], cp, head + hf * hr * 0.45 - hu * hr * (0.2 + 0.4 * minf(cut, 1.0)) + side * hr * 0.15, hr * 0.09 * (1.0 + cut))
		_seg(f["chest_blood"], neck + fw * depth * 0.32 - up * Uh * 0.2, chest_c + fw * depth * 0.55 - up * Uh * 0.5, Uh * 0.15)
	var bm: MeshInstance3D = f["bruise"]
	bm.visible = r.bruise > 0.25
	if bm.visible:
		(f["bruise_m"] as StandardMaterial3D).albedo_color = Color(0.38, 0.12, 0.2, clampf((r.bruise - 0.25) * 0.8, 0.0, 0.6))
		_ell(bm, head + hf * hr * 0.38 + hu * hr * 0.05 + side * hr * 0.17, hf, hu, side, Vector3(hr * 0.12, hr * 0.22, hr * 0.26) * (1.0 + 0.4 * r.bruise))


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
			sm.position = Vector3(float(stn["x"]), 0.047 + float(i) * 0.0006, lerpf(1.6, -2.4, float(stn["z"])))
			sm.scale = Vector3(w, 1.0, w * 0.8)
	_cap.text = brain._caption if brain._caption_t > 0.0 else ""
	_rep.visible = brain.in_replay()
	_rep.text = "● REPLAY" if brain.replay_take() <= 0 else "● REPLAY · CÂMERA LENTA"
