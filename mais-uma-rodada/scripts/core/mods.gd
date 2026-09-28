class_name Mods
extends RefCounted
## Mods: conteúdo de fora do jogo que muda o banco de dados sem mexer no código.
##
## Cada mod é uma pasta em user://mods/<id>/ com:
##   mod.json                         {"name", "author", "version", "description", "priority", "enabled"}
##   data/<caminho>.json              substitui o arquivo inteiro de res://data/<caminho>.json
##                                    (ou cria um arquivo novo, ex.: clubes de um país que não existia)
##   data/<caminho>.patch.json        corrige o arquivo original (mesclagem profunda, ver merge())
##   players.json                     jogadores extras ou editados (ver PlayerMods)
##   img/**                           imagens (escudos, uniformes, estádios, logos, fotos): os dados
##                                    citam o caminho a partir de img/ ("escudos/meu_clube.png")
## Um mod também pode vir num arquivo único (.json) com {"mod": {...}, "files": {"data/...": {...}},
## "players": [...], "images": {"arquivo.png": "<base64>"}} — é o formato de "Exportar como mod".
## Os mods ligados valem na ordem da lista (o último ganha) e entram quando os dados são carregados.
## Um mod novo (pasta copiada à mão) entra ligado, na posição do seu "priority" (maior = aplicado
## depois, ganha dos outros), a não ser que o mod.json diga "enabled": false.
## Documentação completa: docs/MODS.md.

const DIR := "user://mods"
const ENABLED_PATH := "user://mods/enabled.json"
const FORMAT := 2

static var _enabled: Array = []
## Mods que o jogador desligou (os que não estão aqui nem na ordem são novos).
static var _off: Array = []
static var _enabled_loaded := false


# ---------------------------------------------------------------------------
# Lista e ativação
# ---------------------------------------------------------------------------

## Mods instalados: [{id, name, author, version, description, priority, enabled, problems}],
## na ordem de aplicação (desligados no fim).
static func list() -> Array:
	var out: Array = []
	var order := enabled_ids()
	var ids := _installed()
	ids.sort_custom(func(a, b):
		var ia := order.find(a)
		var ib := order.find(b)
		if ia != ib:
			return (ia if ia >= 0 else 9999) < (ib if ib >= 0 else 9999)
		return String(a) < String(b))
	for id in ids:
		var m := manifest(id)
		out.append({"id": id, "name": String(m.get("name", id)), "author": String(m.get("author", "")),
			"version": String(m.get("version", "")), "description": String(m.get("description", "")),
			"priority": int(m.get("priority", 0)), "enabled": order.has(id)})
	return out


## mod.json de um mod instalado ({} se ilegível).
static func manifest(id: String) -> Dictionary:
	var meta: Variant = _read("%s/%s/mod.json" % [DIR, id])
	return meta if meta is Dictionary else {}


static func _installed() -> Array:
	var ids: Array = []
	var d := DirAccess.open(DIR)
	if d == null:
		return ids
	for sub in d.get_directories():
		if FileAccess.file_exists("%s/%s/mod.json" % [DIR, sub]):
			ids.append(sub)
	return ids


static func enabled_ids() -> Array:
	if not _enabled_loaded:
		_enabled_loaded = true
		var e: Variant = _read(ENABLED_PATH)
		# Formato antigo: só a lista dos ligados.
		_enabled = Array(e) if e is Array else (Array(e.get("order", [])) if e is Dictionary else [])
		_off = Array(e.get("off", [])) if e is Dictionary else []
		# Mods apagados à mão somem da lista
		_enabled = _enabled.filter(func(id): return FileAccess.file_exists("%s/%s/mod.json" % [DIR, id]))
		_discover()
	return _enabled


## Pastas novas (copiadas à mão): entram ligadas na posição do "priority", salvo "enabled": false.
static func _discover() -> void:
	var fresh: Array = []
	for id in _installed():
		if _enabled.has(id) or _off.has(id):
			continue
		if manifest(id).get("enabled", true) == false:
			_off.append(id)
		else:
			fresh.append(id)
	if fresh.is_empty():
		return
	fresh.sort()
	for id in fresh:
		var pr := int(manifest(id).get("priority", 0))
		var at := _enabled.size()
		for i in _enabled.size():
			if int(manifest(String(_enabled[i])).get("priority", 0)) > pr:
				at = i
				break
		_enabled.insert(at, id)
	_save_enabled()


## Mods que valem de fato: os ligados, se a Carreira Completa estiver liberada. O Store atualiza
## `allowed`; é uma variável simples porque a leitura dos dados também roda em threads.
static var allowed := true


static func active_ids() -> Array:
	return enabled_ids() if allowed else []


static func set_enabled(id: String, on: bool) -> void:
	var e := enabled_ids()
	e.erase(id)
	_off.erase(id)
	if on:
		e.append(id)
	else:
		_off.append(id)
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


## Relê a pasta de mods (depois de copiar um mod à mão ou instalar um).
static func rescan() -> void:
	_enabled_loaded = false
	enabled_ids()


static func _save_enabled() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(ENABLED_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"order": _enabled, "off": _off}))


static func remove(id: String) -> void:
	enabled_ids().erase(id)
	_off.erase(id)
	_save_enabled()
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


## Arquivos do mod com problema: JSON ilegível ou caminho que não existe no jogo.
## [{file, msg}] — mostrado no Editor para quem está criando o mod.
static func problems(id: String) -> Array:
	var out: Array = []
	var root := "%s/%s" % [DIR, id]
	if manifest(id).is_empty():
		out.append({"file": "mod.json", "msg": "mod.json ilegível"})
	for rel in _files_under(root + "/data", "data"):
		if not rel.ends_with(".json"):
			continue
		if JSON.parse_string(FileAccess.get_file_as_string(root + "/" + rel)) == null:
			out.append({"file": rel, "msg": "JSON inválido"})
			continue
		var orig: String = "res://" + rel.trim_suffix(".patch.json") + (".json" if rel.ends_with(".patch.json") else "")
		if rel.ends_with(".patch.json") and not FileAccess.file_exists(orig) and not rel.begins_with("data/world/"):
			out.append({"file": rel, "msg": "não existe %s no jogo para corrigir" % orig.substr(6)})
	if FileAccess.file_exists(root + "/players.json") and _read(root + "/players.json") == null:
		out.append({"file": "players.json", "msg": "JSON inválido"})
	return out


static func _files_under(path: String, rel: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(path)
	if d == null:
		return out
	for f in d.get_files():
		out.append(rel + "/" + f)
	for sub in d.get_directories():
		out.append_array(_files_under(path + "/" + sub, rel + "/" + sub))
	return out


## Caminho de uma imagem de mod ("escudos/x.png" → user://mods/<id>/img/escudos/x.png), do último
## mod ligado que a tiver; "" se nenhum tiver.
static func image_path(file: String) -> String:
	var ids := active_ids()
	for i in range(ids.size() - 1, -1, -1):
		var p := "%s/%s/img/%s" % [DIR, ids[i], file]
		if FileAccess.file_exists(p):
			return p
	return ""


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
	if patch is Dictionary and patch.has("_by") and (base is Array or base == null):
		return _merge_list(base if base is Array else [], patch)
	if base == null and patch is Dictionary:
		base = {}
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
			out[k] = merge(null, patch[k]) if patch[k] is Dictionary else _copy(patch[k])
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
	write_folder(root, meta if not meta.is_empty() else {"name": id}, data.get("files", {}), data.get("players", null), {})
	var imgs: Dictionary = data.get("images", {})
	for name in imgs:
		_store_image(root, String(name), Marshalls.base64_to_raw(String(imgs[name])))
	set_enabled(id, true)
	return {"ok": true, "id": id, "msg": "Mod \"%s\" instalado e ligado." % String(meta.get("name", id))}


## Grava um mod em pasta: mod.json, arquivos de dados (só dentro de data/), players.json e imagens
## ({caminho em img/: caminho de origem}).
static func write_folder(root: String, meta: Dictionary, files: Dictionary, players: Variant, images: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(root)
	_write(root + "/mod.json", meta)
	for rel in files:
		var r := String(rel).simplify_path()
		if r.begins_with("..") or r.begins_with("/") or not r.begins_with("data/"):
			continue # só arquivos de dados, sempre dentro da pasta do mod
		DirAccess.make_dir_recursive_absolute((root + "/" + r).get_base_dir())
		_write(root + "/" + r, files[rel])
	if players is Array and not players.is_empty():
		_write(root + "/players.json", players)
	for rel in images:
		var src := String(images[rel])
		if FileAccess.file_exists(src):
			_store_image(root, String(rel), FileAccess.get_file_as_bytes(src))


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
			_store_image(root, rel.substr(4), zr.read_file(f))
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


## Suas personalizações do editor (clubes, estádios, uniformes, competições, placares, jogadores e
## imagens) no formato de patches dos dados (quem instalar não precisa do seu overrides.json).
## {mod, files: {caminho: dados}, players, image_files: {nome: caminho local}}
static func export_content(name: String, author: String) -> Dictionary:
	var ov := Overrides.data()
	var files := {}
	# Clubes: um patch por país (e os uniformes no arquivo de uniformes do país)
	var by_nation := {}
	var kits_by_nation := {}
	for key in ov.get("clubs", {}):
		var o: Dictionary = ov["clubs"][key]
		var nation := _nation_of_club(String(key))
		if nation == "":
			continue # clube gerado na hora: não existe nos dados para corrigir
		var item := {"key": key}
		for f in ["name", "short", "abbr", "nick", "city", "official", "crest", "sponsors"]:
			if o.has(f):
				item[f] = o[f]
		if o.has("c1"):
			item["colors"] = [o["c1"], o.get("c2", o["c1"])]
		if o.has("stadium") or o.has("cap") or o.has("venue"):
			var st: Dictionary = Dictionary(o.get("venue", {})).duplicate(true)
			if o.has("stadium"):
				st["name"] = o["stadium"]
			if o.has("cap"):
				st["capacity"] = int(o["cap"])
			item["stadium"] = st
		if o.get("kits", null) is Dictionary and not o["kits"].is_empty():
			if not kits_by_nation.has(nation):
				kits_by_nation[nation] = {}
			kits_by_nation[nation][key] = o["kits"]
		if item.size() <= 1:
			continue
		if not by_nation.has(nation):
			by_nation[nation] = []
		by_nation[nation].append(item)
	for nation in by_nation:
		files["data/world/clubs/%s.patch.json" % nation] = {"clubs": {"_by": "key", "items": by_nation[nation]}}
	for nation in kits_by_nation:
		files["data/world/kits/%s.patch.json" % nation] = {"kits": kits_by_nation[nation]}
	# Competições: ligas (lista por id) e copas (continentais ou do país), com placar e logo
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
		var path := CustomAssets.path_of(f)
		if path != "":
			images[f] = path
	var meta := {"name": name, "author": author, "version": "1.0", "format": FORMAT, "priority": 0, "enabled": true,
		"description": "Personalizações exportadas do editor do Mais Uma Rodada."}
	return {"mod": meta, "files": files, "players": PlayerMods.stored(), "image_files": images}


## Exportação em arquivo único (.json com as imagens em base64).
static func export_bundle(name: String, author: String) -> Dictionary:
	var c := export_content(name, author)
	var images := {}
	for f in c["image_files"]:
		images[f] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(String(c["image_files"][f])))
	return {"format": FORMAT, "mod": c["mod"], "files": c["files"], "players": c["players"], "images": images}


## Exportação em pasta de mod, pronta para editar à mão: user://mods/<id>/ (fica desligada, porque
## as mesmas personalizações já valem pelo editor) e um .zip ao lado para compartilhar.
## Retorna {id, folder, zip}.
static func export_folder(name: String, author: String) -> Dictionary:
	var c := export_content(name, author)
	var id := _new_id(name)
	var root := "%s/%s" % [DIR, id]
	var meta: Dictionary = c["mod"]
	meta["enabled"] = false
	write_folder(root, meta, c["files"], c["players"], c["image_files"])
	enabled_ids()
	_off.append(id)
	_save_enabled()
	DirAccess.make_dir_recursive_absolute("user://exports")
	var zip_path := "user://exports/%s.zip" % id
	_zip_folder(root, zip_path, id)
	return {"id": id, "folder": ProjectSettings.globalize_path(root), "zip": ProjectSettings.globalize_path(zip_path)}


static func _zip_folder(root: String, zip_path: String, top: String) -> void:
	var zp := ZIPPacker.new()
	if zp.open(zip_path) != OK:
		return
	var all: Array = ["mod.json"]
	if FileAccess.file_exists(root + "/players.json"):
		all.append("players.json")
	all.append_array(_files_under(root + "/data", "data"))
	all.append_array(_files_under(root + "/img", "img"))
	for rel in all:
		zp.start_file(top + "/" + String(rel))
		zp.write_file(FileAccess.get_file_as_bytes(root + "/" + String(rel)))
		zp.close_file()
	zp.close()


static func _nation_of_club(key: String) -> String:
	if DatabaseManager.club_entry(key).is_empty():
		return ""
	for n in DatabaseManager.league_nations():
		for d in DatabaseManager.club_data(n):
			if String(d.get("key", "")) == key:
				return n
	return ""


## Imagens de mods ficam na pasta img/ do próprio mod (os dados guardam o caminho a partir de img/).
static func _store_image(root: String, rel: String, bytes: PackedByteArray) -> void:
	rel = rel.simplify_path()
	if rel.begins_with("..") or rel.begins_with("/") or bytes.is_empty():
		return
	if not CustomAssets.EXTENSIONS.has(rel.get_extension().to_lower()):
		return
	var path := root + "/img/" + rel
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)


static func _used_images(v: Variant) -> Array:
	var out: Array = []
	if v is Dictionary:
		for k in v:
			if v[k] is String and CustomAssets.EXTENSIONS.has(String(v[k]).get_extension().to_lower()):
				out.append(String(v[k]))
			else:
				out.append_array(_used_images(v[k]))
	elif v is Array:
		for e in v:
			out.append_array(_used_images(e))
	return out


static func _new_id(name: String) -> String:
	var base := name.to_lower().validate_filename().replace(" ", "_").left(32)
	if base == "" or base == "enabled.json" or base == "enabled":
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
