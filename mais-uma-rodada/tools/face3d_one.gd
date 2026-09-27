extends SceneTree
## Um rosto 3D grande do estúdio, para depurar: --seed --eth --age --look=hs:6 --hide=lashes,brows --out
## xvfb-run godot --path . --resolution 600x600 --script res://tools/face3d_one.gd -- --seed=5 --out=/tmp/o.png

var _st: Face3DStudio
var _spec := {"seed": 5, "eth": 1, "age": 26, "look": {}}
var _hide: Array = []
var _out := "/tmp/face3d_one.png"
var _frames := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			_spec["seed"] = int(a.substr(7))
		elif a.begins_with("--eth="):
			_spec["eth"] = int(a.substr(6))
		elif a.begins_with("--age="):
			_spec["age"] = int(a.substr(6))
		elif a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--plain":
			Face3DLook.debug_plain = true
		elif a.begins_with("--hide="):
			_hide = Array(a.substr(7).split(","))
		elif a.begins_with("--look="):
			var lk := {}
			for kv in a.substr(7).split(","):
				var p := kv.split(":")
				lk[p[0]] = int(p[1])
			_spec["look"] = lk
	_spec["kit"] = {"pattern": "stripes_v", "c1": "#B3122E", "c2": "#111111", "collar": "round"}
	_st = Face3DStudio.new()
	root.add_child(_st)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		var t0 := Time.get_ticks_msec()
		_st.setup(_spec)
		print("setup ms ", Time.get_ticks_msec() - t0)
		if OS.get_environment("EYESTD") != "":
			var sm := StandardMaterial3D.new()
			sm.albedo_texture = Face3DKit.texture("eye_brown.png")
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
			if OS.get_environment("EYESTD") == "2":
				sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			if OS.get_environment("EYESTD") == "3":
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				sm.alpha_scissor_threshold = 0.4
			if OS.get_environment("EYESTD") == "4":
				sm.albedo_texture = Face3DKit.texture("eyes.png")
			(_st._mi["eyes"] as MeshInstance3D).material_override = sm
		for k in _hide:
			if _st._mi.has(k):
				(_st._mi[k] as MeshInstance3D).visible = false
			if k == "shells":
				for m in _st._scalp + _st._beard:
					m.visible = false
		_st._kit_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _frames == 3:
		_st._vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if _frames == 6:
		var img := _st._vp.get_texture().get_image()
		var bg := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		bg.fill(Color("#3A3F48"))
		img.convert(Image.FORMAT_RGBA8)
		bg.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		bg.save_png(_out)
		_st._kit_vp.get_texture().get_image().save_png(_out.replace(".png", "_kit.png"))
		print("salvo ", _out)
		return true
	return false
