class_name Mods
extends RefCounted
## Mods: conteúdo de fora do jogo que muda o banco de dados sem mexer no código.
##
## Cada mod é uma pasta em user://mods/<id>/ com:
##   mod.json                         {"name", "author", "version", "description"}
##   data/<caminho>.json              substitui o arquivo inteiro de res://data/<caminho>.json
##   data/<caminho>.patch.json        corrige o arquivo original (mesclagem profunda, ver merge())
##   players.json                     jogadores extras ou editados (ver PlayerMods)
##   img/*.png                        imagens (vão para a pasta de imagens do editor, user://custom/img)
## Um mod também pode vir num arquivo único (.json) com {"mod": {...}, "files": {"data/...": {...}},
## "players": [...], "images": {"arquivo.png": "<base64>"}} — é o formato de "Exportar como mod".
## Os mods ligados valem na ordem da lista (o último ganha) e entram quando os dados são carregados.
## Documentação completa: docs/MODS.md.

const DIR := "user://mods"
const ENABLED_PATH := "user://mods/enabled.json"
const FORMAT := 1

static var _enabled: Array = []
static var _enabled_loaded := false


# ---------------------------------------------------------------------------
# Lista e ativação
# ---------------------------------------------------------------------------

## Mods instalados: [{id, name, author, version, description, enabled}], na ordem de aplicação.
static func list() -> Array:
	var out: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	var ids: Array = []
	for sub in d.get_directories():
		if FileAccess.file_exists("%s/%s/mod.json" % [DIR, sub]):
			ids.append(sub)
	var order := enabled_ids()
	ids.sort_custom(func(a, b):
		var ia := order.find(a)
		var ib := order.find(b)
		if ia != ib:
			return (ia if ia >= 0 else 9999) < (ib if ib >= 0 else 9999)
		return String(a) < String(b))
	for id in ids:
		var meta: Variant = _read("%s/%s/mod.json" % [DIR, id])
		var m: Dictionary = meta if meta is Dictionary else {}
		out.append({"id": id, "name": String(m.get("name", id)), "author": String(m.get("author", "")),
			"version": String(m.get("version", "")), "description": String(m.get("description", "")),
			"enabled": order.has(id)})
	return out


static func enabled_ids() -> Array:
	if not _enabled_loaded:
		_enabled_loaded = true
		var e: Variant = _read(ENABLED_PATH)
		_enabled = Array(e) if e is Array else []
		# Mods apagados à mão somem da lista
		_enabled = _enabled.filter(func(id): return FileAccess.file_exists("%s/%s/mod.json" % [DIR, id]))
	return _enabled


## Mods que valem de fato: os ligados, se a Carreira Completa estiver liberada. O Store atualiza
## `allowed`; é uma variável simples porque a leitura dos dados também roda em threads.
static var allowed := true


static func active_ids() -> Array:
	return enabled_ids() if allowed else []


static func set_enabled(id: String, on: bool) -> void:
	var e := enabled_ids()
	e.erase(id)
	if on:
		e.append(id)
	_save_enabled()


## Move um mod ligado para cima (-1) ou para baixo (+1) na ordem de aplicação.
static func move(id: String, delta: int) -> void:
	var e := enabled_ids()
	var i := e.find(id)
	if i < 0:
		return
	var j := clampi(i + delta, 0, e.size() - 1)
	e.remove_at(i)
	e.insert(j, id)
	_save_enabled()


static func any_enabled() -> bool:
	return not enabled_ids().is_empty()


static func _save_enabled() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(ENABLED_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_enabled))


static func remove(id: String) -> void:
	set_enabled(id, false)
	_remove_dir("%s/%s" % [DIR, id])


static func _remove_dir(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_remove_dir(path + "/" + sub)
	DirAccess.remove_absolute(path)


# ---------------------------------------------------------------------------
# Aplicação nos dados
# ---------------------------------------------------------------------------

## Chamado pelo DatabaseManager para cada arquivo de res://data: devolve os dados com os mods ligados.
static func apply_to(res_path: String, data: Variant) -> Variant:
	if not res_path.begins_with("res://") or active_ids().is_empty():
		return data
	var rel := res_path.substr(6) # "data/world/clubs/BRA.json"
	for id in active_ids():
		var full := "%s/%s/%s" % [DIR, id, rel]
		if FileAccess.file_exists(full):
			var rep: Variant = _read(full)
			if rep != null:
				data = rep
		var patch := full.trim_suffix(".json") + ".patch.json"
		if FileAccess.file_exists(patch):
			var p: Variant = _read(patch)
			if p != null:
				data = merge(data, p)
	return data


## Mesclagem profunda de um patch sobre os dados:
## - dicionário sobre dicionário: chave a chave (recursivo); "_remove": [chaves] apaga chaves.
## - lista de objetos: {"_by": "key", "items": [...], "remove": [valores]} mescla cada item com o de mesmo
##   campo `_by` (ou acrescenta se não existir) e apaga os listados em "remove".
## - qualquer outro valor substitui.
static func merge(base: Variant, patch: Variant) -> Variant:
	if patch is Dictionary and patch.has("_by") and base is Array:
		return _merge_list(base, patch)
	if not (base is Dictionary and patch is Dictionary):
		return _copy(patch)
	var out: Dictionary = base
	for k in patch:
		if k == "_remove":
			for r in patch[k]:
				out.erase(r)
			continue
		if out.has(k):
			out[k] = merge(out[k], patch[k])
		else:
			out[k] = _copy(patch[k])
	return out


static func _merge_list(base: Array, patch: Dictionary) -> Array:
	var field := String(patch["_by"])
	var out: Array = base
	var removed: Array = Array(patch.get("remove", []))
	if not removed.is_empty():
		out = out.filter(func(e): return not (e is Dictionary and removed.has(e.get(field))))
	for item in patch.get("items", []):
		if not (item is Dictionary):
			continue
		var found := false
		for i in out.size():
			if out[i] is Dictionary and out[i].get(field) == item.get(field):
				out[i] = merge(out[i], item)
				found = true
				break
		if not found:
			out.append(_copy(item))
	return out


static func _copy(v: Variant) -> Variant:
	if v is Dictionary or v is Array:
		return v.duplicate(true)
	return v


## Jogadores de todos os mods ligados (players.json de cada um, na ordem).
static func players() -> Array:
	var out: Array = []
	for id in active_ids():
		var p: Variant = _read("%s/%s/players.json" % [DIR, id])
		if p is Array:
			out.append_array(p)
		elif p is Dictionary:
			out.append_array(Array(p.get("players", [])))
	return out


# ---------------------------------------------------------------------------
# Instalar e exportar
# ---------------------------------------------------------------------------

## Instala um mod a partir de um .zip (com mod.json na raiz ou numa pasta) ou de um .json único.
## Retorna {ok, id, msg}.
static func install(src_path: String) -> Dictionary:
	var ext := src_path.get_extension().to_lower()
	if ext == "zip":
		return _install_zip(src_path)
	if ext == "json":
		var data: Variant = _read(src_path)
		if not (data is Dictionary):
			return {"ok": false, "msg": "O arquivo não é um mod válido (JSON ilegível)."}
		return install_bundle(data)
	return {"ok": false, "msg": "Use um arquivo .zip ou .json de mod."}


static func install_bundle(data: Dictionary) -> Dictionary:
	var meta: Dictionary = data.get("mod", {})
	if meta.is_empty() and not data.has("files") and not data.has("players"):
		return {"ok": false, "msg": "Esse JSON não tem o formato de mod (faltam 'mod', 'files' ou 'players')."}
	var id := _new_id(String(meta.get("name", "mod")))
	var root := "%s/%s" % [DIR, id]
	DirAccess.make_dir_recursive_absolute(root)
	_write(root + "/mod.json", meta if not meta.is_empty() else {"name": id})
	var files: Dictionary = data.get("files", {})
	for rel in files:
		var r := String(rel).simplify_path()
		if r.begins_with("..") or r.begins_with("/") or not r.begins_with("data/"):
			continue # só arquivos de dados, sempre dentro da pasta do mod
		DirAccess.make_dir_recursive_absolute((root + "/" + r).get_base_dir())
		_write(root + "/" + r, files[rel])
	if data.has("players"):
		_write(root + "/players.json", data["players"])
	var imgs: Dictionary = data.get("images", {})
	for name in imgs:
		_store_image(String(name), Marshalls.base64_to_raw(String(imgs[name])))
	set_enabled(id, true)
	return {"ok": true, "id": id, "msg": "Mod \"%s\" instalado e ligado." % String(meta.get("name", id))}


static func _install_zip(src_path: String) -> Dictionary:
	var zr := ZIPReader.new()
	if zr.open(src_path) != OK:
		return {"ok": false, "msg": "Não foi possível abrir o .zip."}
	var files := zr.get_files()
	var prefix := ""
	for f in files:
		if f.get_file() == "mod.json" and (prefix == "" or f.length() < prefix.length() + 8):
			prefix = f.get_base_dir()
	if not files.has(prefix.path_join("mod.json") if prefix != "" else "mod.json"):
		zr.close()
		return {"ok": false, "msg": "O .zip não tem um mod.json."}
	var meta: Variant = JSON.parse_string(zr.read_file(prefix.path_join("mod.json") if prefix != "" else "mod.json").get_string_from_utf8())
	var id := _new_id(String(meta.get("name", "mod")) if meta is Dictionary else "mod")
	var root := "%s/%s" % [DIR, id]
	for f in files:
		if f.ends_with("/") or (prefix != "" and not f.begins_with(prefix + "/")):
			continue
		var rel := f.substr(prefix.length() + 1) if prefix != "" else f
		rel = rel.simplify_path()
		if rel.begins_with("..") or rel.begins_with("/"):
			continue
		if rel.begins_with("img/"):
			_store_image(rel.get_file(), zr.read_file(f))
			continue
		var ok_path := rel == "mod.json" or rel == "players.json" or rel.begins_with("data/")
		if not ok_path:
			continue
		DirAccess.make_dir_recursive_absolute((root + "/" + rel).get_base_dir())
		var out := FileAccess.open(root + "/" + rel, FileAccess.WRITE)
		if out != null:
			out.store_buffer(zr.read_file(f))
	zr.close()
	set_enabled(id, true)
	return {"ok": true, "id": id, "msg": "Mod \"%s\" instalado e ligado." % (String(meta.get("name", id)) if meta is Dictionary else id)}


## Suas personalizações do editor (clubes, competições, jogadores e imagens) num único arquivo de mod,
## já no formato de patches dos dados (quem instalar não precisa do seu overrides.json).
static func export_bundle(name: String, author: String) -> Dictionary:
	var ov := Overrides.data()
	var files := {}
	# Clubes: um patch por país
	var by_nation := {}
	for key in ov.get("clubs", {}):
		var o: Dictionary = ov["clubs"][key]
		var nation := _nation_of_club(String(key))
		if nation == "":
			continue
		var item := {"key": key}
		for f in ["name", "short", "abbr", "nick", "city", "stadium", "crest"]:
			if o.has(f):
				item[f] = o[f]
		if o.has("c1"):
			item["colors"] = [o["c1"], o.get("c2", o["c1"])]
		if not by_nation.has(nation):
			by_nation[nation] = []
		by_nation[nation].append(item)
	for nation in by_nation:
		files["data/world/clubs/%s.patch.json" % nation] = {"clubs": {"_by": "key", "items": by_nation[nation]}}
	# Competições: ligas (lista por id) e copas (continentais ou do país)
	var leagues: Array = []
	for id in ov.get("leagues", {}):
		var item := {"id": id}
		item.merge(ov["leagues"][id])
		leagues.append(item)
	if not leagues.is_empty():
		files["data/world/leagues.patch.json"] = {"leagues": {"_by": "id", "items": leagues}}
	var cont := {}
	var dom := {}
	for id in ov.get("cups", {}):
		if DatabaseManager.get_data("domestic").get("cups", {}).has(id):
			dom[id] = ov["cups"][id]
		else:
			cont[id] = ov["cups"][id]
	if not cont.is_empty():
		files["data/world/continental.patch.json"] = {"cups": cont}
	if not dom.is_empty():
		files["data/world/domestic.patch.json"] = {"cups": dom}
	var images := {}
	for f in _used_images(ov) + _used_images(PlayerMods.stored()):
		var path := "%s/%s" % [CustomAssets.DIR, f]
		if FileAccess.file_exists(path):
			images[f] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	return {"format": FORMAT, "mod": {"name": name, "author": author, "version": "1.0",
		"description": "Personalizações exportadas do editor do Mais Uma Rodada."},
		"files": files, "players": PlayerMods.stored(), "images": images}


static func _nation_of_club(key: String) -> String:
	for n in DatabaseManager.league_nations():
		for d in DatabaseManager.club_data(n):
			if String(d.get("key", "")) == key:
				return n
	return ""


## Imagens de mods vão para a mesma pasta das imagens do editor (os dados guardam só o nome).
static func _store_image(fname: String, bytes: PackedByteArray) -> void:
	fname = fname.get_file()
	if fname.get_extension().to_lower() != "png" or bytes.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(CustomAssets.DIR)
	var f := FileAccess.open("%s/%s" % [CustomAssets.DIR, fname], FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)


static func _used_images(v: Variant) -> Array:
	var out: Array = []
	if v is Dictionary:
		for k in v:
			if v[k] is String and String(v[k]).ends_with(".png"):
				out.append(String(v[k]))
			else:
				out.append_array(_used_images(v[k]))
	elif v is Array:
		for e in v:
			out.append_array(_used_images(e))
	return out


static func _new_id(name: String) -> String:
	var base := name.to_lower().validate_filename().replace(" ", "_").left(32)
	if base == "" or base == "enabled.json":
		base = "mod"
	var id := base
	var n := 2
	while DirAccess.dir_exists_absolute("%s/%s" % [DIR, id]):
		id = "%s_%d" % [base, n]
		n += 1
	return id


static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


static func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
