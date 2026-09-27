class_name Face3DKit
extends RefCounted
## Kit de rostos 3D (dados CC0 do MakeHuman, gerados por tools/face3d/build_face3d.py).
## body.bin traz o busto e os alvos (morphs) esparsos; cada proxy (cabelo, barba, sobrancelha,
## olhos, camisa) é preso aos vértices do busto por pesos, então acompanha qualquer formato de rosto.
## Tudo é montado na CPU uma vez por retrato (o resultado vira textura em cache no Face3DStudio).

const DIR := "res://assets/face3d/"
## Centro aproximado do crânio (metros) na pose base.
const SKULL_C := Vector3(0.0, 0.83, 0.03)

static var _files := {}
static var _info := {}


static func available() -> bool:
	return FileAccess.file_exists(DIR + "body.bin")


static func info() -> Dictionary:
	if _info.is_empty():
		var f := FileAccess.open(DIR + "face3d.json", FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_info = d
	return _info


## Lê um .bin: {"meta": {...}, "<bloco>": PackedFloat32Array | PackedInt32Array}.
static func load_bin(key: String) -> Dictionary:
	if _files.has(key):
		return _files[key]
	var out := {}
	var f := FileAccess.open(DIR + key + ".bin", FileAccess.READ)
	if f == null:
		_files[key] = out
		return out
	var magic := f.get_buffer(4).get_string_from_ascii()
	if magic != "F3D1":
		_files[key] = out
		return out
	var n := f.get_32()
	var meta: Dictionary = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	out["meta"] = meta
	for b in meta["blocks"]:
		var cnt := int(b[2])
		var buf := f.get_buffer(cnt * 4)
		out[String(b[0])] = buf.to_float32_array() if String(b[1]) == "f32" else buf.to_int32_array()
	_files[key] = out
	return out


## Posições do busto (todas as referências) com os alvos aplicados. weights: {nome: peso}.
static func body_positions(weights: Dictionary) -> PackedVector3Array:
	var b := load_bin("body")
	var p: PackedFloat32Array = b["pos"]
	var pos: PackedFloat32Array = p.duplicate()
	for name in weights:
		var wv: float = weights[name]
		if absf(wv) < 0.001 or not b.has("s:%s:i" % name):
			continue
		var ii: PackedInt32Array = b["s:%s:i" % name]
		var dd: PackedFloat32Array = b["s:%s:d" % name]
		for k in ii.size():
			var j := ii[k] * 3
			pos[j] += dd[k * 3] * wv
			pos[j + 1] += dd[k * 3 + 1] * wv
			pos[j + 2] += dd[k * 3 + 2] * wv
	var out := PackedVector3Array()
	out.resize(pos.size() / 3)
	for i in out.size():
		out[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
	return out


## Malha do busto (pele) com normais suaves calculadas nos vértices originais (sem costura no UV).
## CUSTOM0 = posição na pose base (decímetros): os shaders pintam pele, barba e cabelo por ela.
static func body_mesh(bp: PackedVector3Array) -> ArrayMesh:
	var b := load_bin("body")
	return _build(bp, b["orig"], b["uv"], b["idx"], PackedFloat32Array(), b["pos"])


## Malha de um proxy (cabelo, barba, sobrancelha...) encaixada no busto já deformado.
## `scale` aumenta/diminui o volume em torno do centro do crânio (black power maior, cachos curtos...).
static func proxy_mesh(key: String, bp: PackedVector3Array, scale := 1.0) -> ArrayMesh:
	var d := load_bin(key)
	if d.is_empty():
		return null
	var ref: PackedInt32Array = d["ref"]
	var w: PackedFloat32Array = d["w"]
	var off: PackedFloat32Array = d["off"]
	var n := w.size() / 3
	var local := PackedVector3Array()
	local.resize(n)
	for i in n:
		var a := i * 3
		local[i] = bp[ref[a]] * w[a] + bp[ref[a + 1]] * w[a + 1] + bp[ref[a + 2]] * w[a + 2] + Vector3(off[a], off[a + 1], off[a + 2])
	if scale != 1.0:
		var c := SKULL_C
		for i in n:
			local[i] = c + (local[i] - c) * Vector3(scale, lerpf(1.0, scale, 0.8), scale)
	return _build(local, d["vloc"], d["uv"], d["idx"], d.get("dist", PackedFloat32Array()))


## `extra` (opcional, por vértice original) vai no UV2.x: a camisa usa como distância até a gola.
static func _build(pos: PackedVector3Array, vmap: PackedInt32Array, uv: PackedFloat32Array, idx: PackedInt32Array, extra := PackedFloat32Array(), base := PackedFloat32Array()) -> ArrayMesh:
	# Normais por vértice original (soma das normais das faces)
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	var t := 0
	while t < idx.size():
		var ia := vmap[idx[t]]
		var ib := vmap[idx[t + 1]]
		var ic := vmap[idx[t + 2]]
		var fn := (pos[ib] - pos[ia]).cross(pos[ic] - pos[ia])
		nrm[ia] += fn
		nrm[ib] += fn
		nrm[ic] += fn
		t += 3
	var nv := vmap.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(nv)
	norms.resize(nv)
	uvs.resize(nv)
	for i in nv:
		var o := vmap[i]
		verts[i] = pos[o]
		norms[i] = nrm[o].normalized()
		uvs[i] = Vector2(uv[i * 2], uv[i * 2 + 1])
	# O MakeHuman usa ordem anti-horária; o Godot considera frente a horária
	var tri := PackedInt32Array()
	tri.resize(idx.size())
	t = 0
	while t < idx.size():
		tri[t] = idx[t]
		tri[t + 1] = idx[t + 2]
		tri[t + 2] = idx[t + 1]
		t += 3
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = tri
	if not extra.is_empty():
		var uv2 := PackedVector2Array()
		uv2.resize(nv)
		for i in nv:
			uv2[i] = Vector2(extra[vmap[i]], 0.0)
		arr[Mesh.ARRAY_TEX_UV2] = uv2
	var flags := 0
	if not base.is_empty():
		var c0 := PackedFloat32Array()
		c0.resize(nv * 3)
		for i in nv:
			var o := vmap[i] * 3
			c0[i * 3] = base[o] * 10.0
			c0[i * 3 + 1] = base[o + 1] * 10.0
			c0[i * 3 + 2] = base[o + 2] * 10.0
		arr[Mesh.ARRAY_CUSTOM0] = c0
		flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, flags)
	return m


static func texture(name: String) -> Texture2D:
	var path := DIR + "tex/" + name
	if ResourceLoader.exists(path):
		return load(path)
	return null
