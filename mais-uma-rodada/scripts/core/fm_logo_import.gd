class_name FmLogoImport
extends RefCounted
## Escudos e logos reais a partir da pasta graphics/logos do Football Manager (ou de qualquer pacote
## de logos), num pacote de imagens soltas do jogo (user://mods/fm-logos, ver DropIns).
##
## Os pacotes do FM nomeiam cada imagem pelo número único (UID) do clube ou da competição no banco
## do FM ("clubs/normal/662.png"), e o config.xml de cada pasta diz o que é cada número
## (graphics/pictures/club/<uid>/logo, .../comp/<uid>/logo). O número não diz o nome, então a
## ligação com os clubes do jogo vem, nesta ordem:
##   1. de user://fm_ids.json (associações feitas no jogo: Opções › Visual › Associar);
##   2. de listas "número;nome" (.csv ou .txt) dentro da pasta importada (exportadas de ferramentas
##      do FM ou feitas à mão);
##   3. de data/world/fm_ids.json ({"clubs": {uid: chave}, "comps": {uid: id}}), que um mod pode
##      preencher.
## Arquivos com o nome do clube ou da competição ("Liverpool.png") entram direto, como em DropIns.
## O jogo não traz nenhum escudo real: as imagens são as do próprio jogador, na máquina dele.

const PACK_ID := "fm-logos"
const PACK_DIR := "user://mods/fm-logos"
const USER_MAP := "user://fm_ids.json"
const SOURCE := "user://mods/fm-logos/source.json"
const YEARS: Array[String] = ["2026", "2025", "2024", "2023", "2022", "2021"]
## Pastas de tamanho, da preferida para a pior.
const SIZE_RANK := {"normal": 0, "large": 0, "": 1, "medium": 1, "small": 2, "tiny": 3, "icon": 3}


## Pastas prováveis de logos do FM nesta máquina (só as que existem).
static func default_dirs() -> Array:
	var homes: Array = []
	var up := OS.get_environment("USERPROFILE")
	if up != "":
		for docs in ["Documents", "Documentos", "OneDrive/Documents", "OneDrive/Documentos"]:
			homes.append(up.path_join(docs).path_join("Sports Interactive"))
	var home := OS.get_environment("HOME")
	if home != "":
		homes.append(home.path_join("Library/Application Support/Sports Interactive"))
		homes.append(home.path_join(".local/share/Sports Interactive"))
		homes.append(home.path_join("Documents/Sports Interactive"))
	var docs_dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs_dir != "":
		homes.append(docs_dir.path_join("Sports Interactive"))
	var out: Array = []
	for h in homes:
		for y in YEARS:
			var p := String(h).path_join("Football Manager %s" % y).path_join("graphics/logos")
			if DirAccess.dir_exists_absolute(p) and not out.has(p):
				out.append(p)
	# No celular: pasta copiada para Download/ ou Documents/
	for base in ["/storage/emulated/0/Download", "/storage/emulated/0/Documents"]:
		for name in ["logos", "fm-logos", "graphics/logos"]:
			var p2: String = String(base).path_join(name)
			if DirAccess.dir_exists_absolute(p2) and not out.has(p2):
				out.append(p2)
	return out


# ---------------------------------------------------------------------------
# Leitura da pasta
# ---------------------------------------------------------------------------

## Varre a pasta: {"clubs": {uid: caminho}, "comps": {uid: caminho}, "named": {nome simplificado:
## caminho}, "maps": [caminhos de listas], "total": n}. Fica com a maior versão de cada número.
static func scan(dir: String) -> Dictionary:
	var out := {"clubs": {}, "comps": {}, "named": {}, "maps": [], "total": 0}
	var kinds := {} # caminho sem extensão -> "club" | "comp" | "nation" (do config.xml)
	var files: Array = []
	_walk(dir, files, kinds, out["maps"], 0)
	var rank := {}
	for f: String in files:
		var stem := f.get_file().get_basename()
		var folder := f.get_base_dir().get_file().to_lower()
		var kind := String(kinds.get(f.get_basename(), ""))
		if kind == "":
			var low := f.to_lower()
			if low.contains("/nation") or low.contains("/flags"):
				kind = "nation"
			elif low.contains("/comp") or low.contains("/leagues") or low.contains("/competitions"):
				kind = "comp"
			elif stem.is_valid_int():
				kind = "club"
		if kind == "nation":
			continue
		out["total"] = int(out["total"]) + 1
		var r := int(SIZE_RANK.get(folder, 1))
		if stem.is_valid_int():
			var bucket: Dictionary = out["comps" if kind == "comp" else "clubs"]
			var key := "%s:%s" % [kind, stem]
			if not bucket.has(stem) or r < int(rank.get(key, 9)):
				bucket[stem] = f
				rank[key] = r
		else:
			var sk := DropIns.slug(stem)
			if sk != "" and (not out["named"].has(sk) or r < int(rank.get("n:" + sk, 9))):
				out["named"][sk] = f
				rank["n:" + sk] = r
	return out


static func _walk(path: String, files: Array, kinds: Dictionary, maps: Array, depth: int) -> void:
	if depth > 8:
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var full := path.path_join(f)
		var ext := f.get_extension().to_lower()
		if CustomAssets.EXTENSIONS.has(ext):
			files.append(full)
		elif f.to_lower() == "config.xml":
			_read_config(full, kinds)
		elif ext in ["csv", "txt"]:
			maps.append(full)
	for sub in d.get_directories():
		_walk(path.path_join(sub), files, kinds, maps, depth + 1)


## <record from="662" to="graphics/pictures/club/662/logo"/> → kinds[pasta/662] = "club".
static func _read_config(path: String, kinds: Dictionary) -> void:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		return
	var re := RegEx.create_from_string("from=\"([^\"]+)\"\\s+to=\"graphics/pictures/([a-z_]+)/(\\d+)/")
	var base := path.get_base_dir()
	for m in re.search_all(text):
		var what := m.get_string(2)
		var kind := "club" if what in ["club", "team"] else ("comp" if what.begins_with("comp") else ("nation" if what == "nation" else ""))
		if kind != "":
			kinds[base.path_join(m.get_string(1)).get_basename()] = kind


# ---------------------------------------------------------------------------
# Números do FM → clubes e competições do jogo
# ---------------------------------------------------------------------------

## {"clubs": {uid: chave do clube}, "comps": {uid: id da competição}} juntando as três fontes.
static func mapping(w: GameWorld, scan_result: Dictionary) -> Dictionary:
	var out := {"clubs": {}, "comps": {}}
	var raw: Variant = DatabaseManager.get_data("fm_ids")
	var data: Dictionary = raw if raw is Dictionary else {}
	for k in ["clubs", "comps"]:
		var src: Variant = data.get(k, {})
		if src is Dictionary:
			out[k].merge(src, true)
	# Listas "número;nome" da pasta
	var names := _name_index(w)
	for mp: String in scan_result.get("maps", []):
		_read_map(mp, names, out)
	var user := user_map()
	for k in ["clubs", "comps"]:
		out[k].merge(user.get(k, {}), true)
	return out


static func user_map() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(USER_MAP)) if FileAccess.file_exists(USER_MAP) else null
	if v is Dictionary:
		var d: Dictionary = v
		if not d.has("clubs"):
			d["clubs"] = {}
		if not d.has("comps"):
			d["comps"] = {}
		return d
	return {"clubs": {}, "comps": {}}


static func _save_user_map(d: Dictionary) -> void:
	var f := FileAccess.open(USER_MAP, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))


## nome simplificado → ["club", chave] ou ["comp", id], de todos os nomes conhecidos.
static func _name_index(w: GameWorld) -> Dictionary:
	var idx := {}
	if w != null:
		for c: Club in w.clubs:
			if c == null:
				continue
			for n in DropIns.club_names(c):
				var k := DropIns.slug(String(n))
				if k != "" and not idx.has(k):
					idx[k] = ["club", c.key]
	var ids: Array = Array(DatabaseManager.league_ids()) + DatabaseManager.cups_cfg().keys()
	for id in ids:
		for n in DropIns.comp_names(String(id)):
			var k := DropIns.slug(String(n))
			if k != "" and not idx.has(k):
				idx[k] = ["comp", String(id)]
	return idx


## Lista com um número e um nome por linha (separador ; , tab ou |; a ordem tanto faz).
static func _read_map(path: String, names: Dictionary, out: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		var parts: PackedStringArray = []
		for sep in [";", "\t", "|", ","]:
			if line.contains(sep):
				parts = line.split(sep, false)
				break
		if parts.size() < 2:
			continue
		var uid := ""
		var name := ""
		for p in parts:
			var t := p.strip_edges().trim_prefix("\"").trim_suffix("\"")
			if uid == "" and t.is_valid_int():
				uid = t
			elif name == "" and not t.is_valid_int():
				name = t
		if uid == "" or name == "":
			continue
		var hit: Variant = names.get(DropIns.slug(name), null)
		if hit is Array:
			out["clubs" if hit[0] == "club" else "comps"][uid] = hit[1]


# ---------------------------------------------------------------------------
# Importação
# ---------------------------------------------------------------------------

## Copia para o pacote fm-logos o que deu para ligar e liga o pacote. Devolve
## {"clubs": n, "comps": n, "numbers": n (números sem dono), "total": n, "dir": pasta}.
static func run(w: GameWorld, dir: String) -> Dictionary:
	var sr := scan(dir)
	var map := mapping(w, sr)
	DirAccess.make_dir_recursive_absolute(PACK_DIR.path_join("crests"))
	DirAccess.make_dir_recursive_absolute(PACK_DIR.path_join("logos"))
	var n_clubs := 0
	var n_comps := 0
	var used := {}
	for uid in sr["clubs"]:
		if map["clubs"].has(uid):
			if _copy(String(sr["clubs"][uid]), "crests", String(map["clubs"][uid])):
				n_clubs += 1
				used[uid] = true
	for uid in sr["comps"]:
		if map["comps"].has(uid):
			if _copy(String(sr["comps"][uid]), "logos", String(map["comps"][uid])):
				n_comps += 1
	var names := _name_index(w)
	for sk in sr["named"]:
		var hit: Variant = names.get(sk, null)
		if hit is Array:
			if _copy(String(sr["named"][sk]), "crests" if hit[0] == "club" else "logos", String(hit[1])):
				if hit[0] == "club":
					n_clubs += 1
				else:
					n_comps += 1
	# Guarda onde estão os números, para associar depois clube a clube.
	var f := FileAccess.open(SOURCE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"dir": dir, "clubs": sr["clubs"], "comps": sr["comps"]}))
	_write_manifest()
	Mods.set_enabled(PACK_ID, true)
	refresh_world(w)
	return {"clubs": n_clubs, "comps": n_comps, "numbers": Dictionary(sr["clubs"]).size() - used.size(), "total": int(sr["total"]), "dir": dir}


static func _copy(src: String, kind: String, key: String) -> bool:
	if key == "":
		return false
	var dst := PACK_DIR.path_join(kind).path_join(key + "." + src.get_extension().to_lower())
	# Outra extensão do mesmo dono sairia duplicada: apaga antes.
	for ext in CustomAssets.EXTENSIONS:
		var old := PACK_DIR.path_join(kind).path_join(key + "." + String(ext))
		if old != dst and FileAccess.file_exists(old):
			DirAccess.remove_absolute(old)
	return DirAccess.copy_absolute(src, dst) == OK


static func _write_manifest() -> void:
	var path := PACK_DIR.path_join("mod.json")
	if FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": "Logos do Football Manager", "author": "importado no jogo",
			"description": "Escudos e logos copiados da pasta graphics/logos do Football Manager desta máquina.", "priority": 50}, "\t"))


## Números importados ainda disponíveis (para a tela de associar): {"clubs": {uid: caminho}, ...}.
static func source() -> Dictionary:
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE)) if FileAccess.file_exists(SOURCE) else null
	return v if v is Dictionary else {}


## Imagem de um número do FM na pasta importada (null se não houver ou a pasta sumiu).
static func preview(uid: String, kind: String = "clubs") -> Texture2D:
	var path := String(Dictionary(source().get(kind, {})).get(uid, ""))
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


## Liga um número do FM a um clube (ou competição) do jogo: copia a imagem e lembra a escolha.
static func assign(w: GameWorld, uid: String, key: String, comp: bool = false) -> bool:
	var kind := "comps" if comp else "clubs"
	var path := String(Dictionary(source().get(kind, {})).get(uid, ""))
	if path == "" or not FileAccess.file_exists(path):
		return false
	DirAccess.make_dir_recursive_absolute(PACK_DIR.path_join("logos" if comp else "crests"))
	if not _copy(path, "logos" if comp else "crests", key):
		return false
	var um := user_map()
	um[kind][uid] = key
	_save_user_map(um)
	_write_manifest()
	Mods.set_enabled(PACK_ID, true)
	refresh_world(w)
	return true


## Relê os pacotes e reaplica escudos e uniformes em imagem no mundo aberto.
static func refresh_world(w: GameWorld) -> void:
	DropIns.rescan()
	if w != null:
		DropIns.apply_world(w)
