class_name LicensePack
extends RefCounted
## Pacote de licenciamento num arquivo só: exporta o mundo atual (nomes, cores, estádios,
## uniformes, jogadores e imagens) e gera o modelo de planilha para preencher os nomes reais.
## O formato está em Mods (pack.json, names.csv) e DropIns (pastas de imagens); docs/MODS.md.

const EXPORT_DIR := "user://exports"
const SLOT_NAMES := {"h": "home", "a": "away", "t": "third", "g": "gk"}


# ---------------------------------------------------------------------------
# Exportar
# ---------------------------------------------------------------------------

## Tudo o que difere dos dados originais do jogo (com mods, pacotes e editor), mais as imagens
## em uso, numa pasta user://exports/<id>/ e num .zip ao lado. Retorna {folder, zip, counts}.
static func export_pack(name: String, author: String) -> Dictionary:
	var id := _free_name(name.to_lower().validate_filename().replace(" ", "_").left(32))
	var root := "%s/%s" % [EXPORT_DIR, id]
	DirAccess.make_dir_recursive_absolute(root)
	var pack := {"name": name, "author": author, "version": "1.0", "format": 1, "priority": 10,
		"clubs": {}, "leagues": {}, "cups": {}, "players": []}
	var counts := {"clubs": 0, "comps": 0, "players": 0, "images": 0}
	# Clubes: o que mudou em relação aos dados originais
	for nation in DatabaseManager.league_nations():
		var base := _base_clubs(nation)
		for cd: Dictionary in DatabaseManager.club_data(nation):
			var key := String(cd.get("key", ""))
			var eff := _club_effective(cd)
			var orig: Dictionary = base.get(key, {})
			var diff := {}
			for f in eff:
				if not orig.has(f) or not _same(orig[f], eff[f]):
					diff[f] = eff[f]
			if not diff.is_empty():
				pack["clubs"][key] = diff
			counts["images"] += _export_club_images(root, key, cd)
	counts["clubs"] = pack["clubs"].size()
	# Competições
	var base_leagues := {}
	var bl: Variant = DatabaseManager.read_json("res://data/world/leagues.json")
	if bl is Dictionary:
		for l in bl.get("leagues", []):
			base_leagues[String(l.get("id", ""))] = l
	var base_cups := {}
	for f in ["res://data/world/continental.json", "res://data/world/domestic.json"]:
		var bc: Variant = DatabaseManager.read_json(f)
		if bc is Dictionary and bc.get("cups", null) is Dictionary:
			base_cups.merge(bc["cups"])
	for lid in DatabaseManager.league_ids():
		var d := _comp_diff(DatabaseManager.league_cfg(lid), base_leagues.get(lid, {}))
		if not d.is_empty():
			pack["leagues"][lid] = d
		counts["images"] += _export_logo(root, lid)
	for cid in DatabaseManager.cups_cfg():
		var d := _comp_diff(DatabaseManager.cup_cfg(cid), base_cups.get(cid, {}))
		if not d.is_empty():
			pack["cups"][cid] = d
		counts["images"] += _export_logo(root, String(cid))
	counts["comps"] = pack["leagues"].size() + pack["cups"].size()
	# Jogadores: os dos pacotes ligados e os do Editor geral (foto vira arquivo em cutouts/)
	for e in Mods.players() + PlayerMods.stored():
		if not (e is Dictionary):
			continue
		var entry: Dictionary = e.duplicate(true)
		var look: Variant = entry.get("look", null)
		if look is Dictionary and String(look.get("photo", "")) != "":
			var who := String(entry.get("known", ""))
			if who == "":
				who = (String(entry.get("first", "")) + " " + String(entry.get("last", ""))).strip_edges()
			if who == "":
				who = String(entry.get("match", ""))
			if _copy_image(String(look["photo"]), root, "cutouts", who):
				counts["images"] += 1
			look.erase("photo")
		pack["players"].append(entry)
	counts["players"] = pack["players"].size()
	# Fotos soltas dos pacotes ligados vão como estão
	for pid in Mods.active_ids():
		for e: Dictionary in DropIns._files.get(pid, []):
			if e["kind"] == "cutouts":
				var dst := root + "/cutouts/" + String(e["file"]).get_file()
				if not FileAccess.file_exists(dst):
					DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
					DirAccess.copy_absolute("%s/%s/%s" % [Mods.DIR, pid, e["file"]], dst)
					counts["images"] += 1
	_write_json(root + "/pack.json", pack)
	var zip_path := "%s/%s.zip" % [EXPORT_DIR, id]
	_zip(root, zip_path, id)
	return {"folder": ProjectSettings.globalize_path(root), "zip": ProjectSettings.globalize_path(zip_path),
		"zip_local": zip_path, "counts": counts}


## Campos exportáveis de um clube como ele está (dados + mods + editor).
static func _club_effective(cd: Dictionary) -> Dictionary:
	var key := String(cd.get("key", ""))
	var o := Overrides.club(key)
	var out := {}
	for pair in [["name", "name"], ["short", "short"], ["abbr", "abbr"], ["nick", "nick"], ["city", "city"], ["official", "official"]]:
		var v := String(o.get(pair[1], cd.get(pair[0], "")))
		if v != "":
			out[pair[0]] = v
	if o.has("c1"):
		out["colors"] = [String(o["c1"]), String(o.get("c2", o["c1"]))]
	elif cd.get("colors", null) is Array:
		out["colors"] = Array(cd["colors"]).duplicate()
	var st := String(o.get("stadium", cd.get("stadium", "")))
	if st != "":
		out["stadium"] = st
	var cap := int(o.get("cap", cd.get("capacity", 0)))
	if cap > 0:
		out["capacity"] = cap
	var kits: Variant = o.get("kits", cd.get("kits", null))
	if kits is Dictionary and not kits.is_empty():
		var k: Dictionary = kits.duplicate(true)
		for slot in k:
			if k[slot] is Dictionary:
				k[slot].erase("img")
		out["kits"] = k
	return out


static func _base_clubs(nation: String) -> Dictionary:
	var out := {}
	var path := DatabaseManager.CLUBS_DIR + nation + ".json"
	if not FileAccess.file_exists(path):
		return out
	var d: Variant = DatabaseManager.read_json(path)
	if d is Dictionary:
		for cd in d.get("clubs", []):
			if cd is Dictionary:
				var n: Dictionary = LicensedData.normalize_club(cd.duplicate(true))
				out[String(n.get("key", ""))] = n
	return out


## Igualdade que não liga para 45000 x 45000.0 (o JSON lê números como float).
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	if a is Array and b is Array:
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _same(a[i], b[i]):
				return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


static func _comp_diff(cfg: Dictionary, base: Dictionary) -> Dictionary:
	var out := {}
	for f in ["name", "short", "colors"]:
		if cfg.has(f) and not _same(cfg[f], base.get(f, null)):
			out[f] = cfg[f].duplicate() if cfg[f] is Array else cfg[f]
	return out


static func _export_club_images(root: String, key: String, cd: Dictionary) -> int:
	var n := 0
	var o := Overrides.club(key)
	var names := [key, o.get("name", cd.get("name", "")), o.get("short", cd.get("short", "")), cd.get("official", ""), o.get("abbr", cd.get("abbr", ""))]
	var crest := String(Dictionary(o.get("crest", {})).get("img", Dictionary(cd.get("crest", {})).get("img", "")))
	if crest == "" or CustomAssets.path_of(crest) == "":
		crest = DropIns.ref("crests", names)
	if _copy_image(crest, root, "crests", key):
		n += 1
	var venue: Dictionary = o.get("venue", cd.get("venue", {})) if (o.get("venue", cd.get("venue", {})) is Dictionary) else {}
	var photo := String(venue.get("photo", ""))
	if photo == "" or CustomAssets.path_of(photo) == "":
		photo = DropIns.ref("stadiums", names + [o.get("stadium", cd.get("stadium", ""))])
	if _copy_image(photo, root, "stadiums", key):
		n += 1
	if DropIns.has_any("kits"):
		for slot in SLOT_NAMES:
			if _copy_image(DropIns.ref("kits", names, slot), root, "kits", key + "_" + String(SLOT_NAMES[slot])):
				n += 1
	return n


static func _export_logo(root: String, id: String) -> int:
	var cfg: Dictionary = DatabaseManager.league_cfg(id) if DatabaseManager.has_league(id) else DatabaseManager.cup_cfg(id)
	var logo := String(cfg.get("logo", ""))
	if logo == "" or CustomAssets.path_of(logo) == "":
		logo = DropIns.comp_ref(id)
	return 1 if _copy_image(logo, root, "logos", id) else 0


## Copia uma imagem em uso para <pasta>/<nome>.<ext> do pacote.
static func _copy_image(ref: String, root: String, folder: String, stem: String) -> bool:
	if ref == "" or stem.strip_edges() == "":
		return false
	var src := CustomAssets.path_of(ref)
	if src == "" or not FileAccess.file_exists(src):
		return false
	var dst := "%s/%s/%s.%s" % [root, folder, stem.validate_filename(), src.get_extension().to_lower()]
	DirAccess.make_dir_recursive_absolute(dst.get_base_dir())
	return DirAccess.copy_absolute(src, dst) == OK


# ---------------------------------------------------------------------------
# Modelo para preencher
# ---------------------------------------------------------------------------

## Cria um pacote vazio em user://mods/<id>/ com names.csv (todos os clubes, competições e, com
## um mundo, os jogadores: id, nome atual e colunas em branco) e as pastas de imagens.
## Já entra ligado: célula vazia não muda nada. Retorna {id, folder, csv}.
static func make_template(world: GameWorld) -> Dictionary:
	var id := Mods._new_id("modelo_licenciamento")
	var root := "%s/%s" % [Mods.DIR, id]
	DirAccess.make_dir_recursive_absolute(root)
	for kind in DropIns.KINDS:
		DirAccess.make_dir_recursive_absolute(root + "/" + kind)
	_write_json(root + "/pack.json", {"name": "Modelo de licenciamento", "author": "", "version": "1.0", "priority": 100})
	var f := FileAccess.open(root + "/names.csv", FileAccess.WRITE)
	if f == null:
		return {}
	f.store_string("﻿") # BOM: o Excel abre com acentos certos
	f.store_csv_line(PackedStringArray(Mods.CSV_COLUMNS))
	var blank := PackedStringArray()
	blank.resize(Mods.CSV_COLUMNS.size() - 3)
	var rows := 0
	for lid in DatabaseManager.league_ids():
		f.store_csv_line(PackedStringArray(["liga", lid, String(DatabaseManager.league_cfg(lid).get("name", lid))]) + blank)
		rows += 1
	for cid in DatabaseManager.cups_cfg():
		f.store_csv_line(PackedStringArray(["copa", cid, String(DatabaseManager.cup_cfg(cid).get("name", cid))]) + blank)
		rows += 1
	for nation in DatabaseManager.league_nations():
		for cd: Dictionary in DatabaseManager.club_data(nation):
			var key := String(cd.get("key", ""))
			f.store_csv_line(PackedStringArray(["clube", key, String(Overrides.club(key).get("name", cd.get("name", key)))]) + blank)
			rows += 1
	if world != null:
		var marks: Dictionary = world.stats.get("pmods", {})
		for c: Club in world.clubs:
			if c == null or DatabaseManager.club_entry(c.key).is_empty():
				continue
			for pid in c.player_ids:
				var p := world.player(int(pid))
				if p == null:
					continue
				var orig := p.first_name + " " + p.last_name
				var mk := String(marks.get(str(p.id), ""))
				if mk.begins_with(c.key + "/") and mk.length() > c.key.length() + 1:
					orig = mk.substr(c.key.length() + 1)
				f.store_csv_line(PackedStringArray(["jogador", c.key + "/" + orig, p.first_name + " " + p.last_name]) + blank)
				rows += 1
	f.close()
	Mods.set_enabled(id, true)
	return {"id": id, "folder": ProjectSettings.globalize_path(root), "csv": ProjectSettings.globalize_path(root + "/names.csv"), "rows": rows}


# ---------------------------------------------------------------------------
# Arquivos
# ---------------------------------------------------------------------------

static func _free_name(base: String) -> String:
	if base == "":
		base = "pacote"
	var id := base
	var n := 2
	while DirAccess.dir_exists_absolute("%s/%s" % [EXPORT_DIR, id]) or FileAccess.file_exists("%s/%s.zip" % [EXPORT_DIR, id]):
		id = "%s_%d" % [base, n]
		n += 1
	return id


static func _write_json(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


static func _zip(root: String, zip_path: String, top: String) -> void:
	var zp := ZIPPacker.new()
	if zp.open(zip_path) != OK:
		return
	for rel in Mods._files_under(root, ""):
		var r := String(rel).trim_prefix("/")
		zp.start_file(top + "/" + r)
		zp.write_file(FileAccess.get_file_as_bytes(root + "/" + r))
		zp.close_file()
	zp.close()
