class_name DropIns
extends RefCounted
## Imagens soltas nas pastas dos pacotes: o jogo acha o dono pelo nome do arquivo.
##
##   user://mods/<pacote>/crests/    escudos de clubes      (ou escudos/)
##   user://mods/<pacote>/logos/     logos de ligas e copas
##   user://mods/<pacote>/cutouts/   fotos de jogadores     (ou fotos/, faces/)
##   user://mods/<pacote>/kits/      camisas (<clube>.png = titular; _away, _third, _gk)
##                                   e uniformes em JSON (<clube>.json = {h, a, t, g})
##   user://mods/<pacote>/stadiums/  fotos de estádios      (ou estadios/)
##
## O nome do arquivo vale pela forma simplificada (sem acento, maiúsculas, espaços ou símbolos):
## "São Paulo.png", "sao-paulo.webp" e "SAO_PAULO.jpg" são o mesmo. Aceita a chave/id
## (BRA_RNC, BRA1, id do jogador), o nome, o nome curto, a sigla e o nome oficial.
## Os dados só guardam uma referência "@<pasta>/<nome>": sem o arquivo, volta o desenho do jogo.

const KINDS: Array[String] = ["crests", "logos", "cutouts", "kits", "stadiums"]
const FOLDERS := {
	"crests": ["crests", "escudos"],
	"logos": ["logos"],
	"cutouts": ["cutouts", "fotos", "faces", "players", "jogadores"],
	"kits": ["kits", "uniformes"],
	"stadiums": ["stadiums", "estadios"],
}
const KIND_NAMES := {"crests": "Escudos", "logos": "Logos", "cutouts": "Fotos", "kits": "Uniformes", "stadiums": "Estádios"}
const KIT_SLOTS := {
	"home": "h", "h": "h", "titular": "h", "casa": "h",
	"away": "a", "a": "a", "reserva": "a", "fora": "a",
	"third": "t", "t": "t", "terceiro": "t",
	"gk": "g", "g": "g", "goleiro": "g", "keeper": "g",
}
## Maior lado das imagens carregadas (as fotos grandes são reduzidas na memória).
const MAX_SIDE := 512
const MAX_WIDE := 1280

## Letras com acento e a letra simples que as substitui (mesma posição); as que viram duas letras
## vêm em _ACCENTS_MULTI ("ß=ss,...").
const _ACCENTS_FROM := "áàâãäåāąăéèêëēęěėíìîïīıįóòôõöøōőúùûüūůűųçćčñńňłśšşșźżžğřťțďđýÿð"
const _ACCENTS_TO := "aaaaaaaaaeeeeeeeeiiiiiiioooooooouuuuuuuucccnnnlsssszzzgrttddyyd"
const _ACCENTS_MULTI := "ß=ss,æ=ae,œ=oe,þ=th"

## tipo -> {nome simplificado (kits: "nome|slot"): caminho} dos pacotes ligados (o último ganha).
static var _idx: Dictionary = {}
## pacote -> [{kind, file, key, slot}] (para o relatório do Editor).
static var _files: Dictionary = {}
## pacote -> {nome simplificado: uniformes em JSON}
static var _kit_json: Dictionary = {}
static var _scanned := false
static var _re: RegEx = null
static var _report_cache: Dictionary = {}
static var _accents: Dictionary = {}


# ---------------------------------------------------------------------------
# Varredura
# ---------------------------------------------------------------------------

## Relê as pastas dos pacotes (início do jogo, "Recarregar", pacote ligado/desligado).
static func rescan() -> void:
	_scanned = false
	_report_cache.clear()
	CustomAssets.clear_cache()
	ensure()


static func ensure() -> void:
	if _scanned:
		return
	_scanned = true
	if _accents.is_empty():
		_build_accents()
	if _re == null:
		_re = RegEx.create_from_string("[^a-z0-9]")
	var idx := {}
	for k in KINDS:
		idx[k] = {}
	var files := {}
	var kj := {}
	var active := Mods.active_ids()
	for id in Mods.installed_ids():
		var list: Array = []
		var root := "%s/%s" % [Mods.DIR, id]
		var d := DirAccess.open(root)
		if d != null:
			for folder in d.get_directories():
				var kind := kind_of_folder(folder)
				if kind != "":
					_scan_dir(root + "/" + folder, folder, kind, list)
		files[id] = list
	# Ordem de aplicação: o pacote de baixo na lista ganha.
	for id in active:
		for e: Dictionary in files.get(id, []):
			if e["kind"] == "kits" and String(e["file"]).get_extension().to_lower() == "json":
				var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("%s/%s/%s" % [Mods.DIR, id, e["file"]]))
				if data is Dictionary:
					if not kj.has(id):
						kj[id] = {}
					kj[id][e["key"]] = data
				continue
			var k := String(e["key"]) + ("|" + String(e["slot"]) if e["kind"] == "kits" else "")
			idx[e["kind"]][k] = "%s/%s/%s" % [Mods.DIR, id, e["file"]]
	_idx = idx
	_files = files
	_kit_json = kj


static func _scan_dir(path: String, rel: String, kind: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		var is_json := kind == "kits" and ext == "json"
		if not CustomAssets.EXTENSIONS.has(ext) and not is_json:
			continue
		var stem := f.get_basename()
		var slot := ""
		if kind == "kits":
			var parts := split_slot(stem)
			stem = parts[0]
			slot = parts[1]
		var key := slug(stem)
		if key == "":
			continue
		out.append({"kind": kind, "file": rel + "/" + f, "key": key, "slot": slot})
	for sub in d.get_directories():
		_scan_dir(path + "/" + sub, rel + "/" + sub, kind, out)


## Tipo de uma pasta de imagens soltas pelo nome ("Escudos" -> "crests"); "" se não for uma.
static func kind_of_folder(name: String) -> String:
	var low := name.to_lower()
	for kind in KINDS:
		if FOLDERS[kind].has(low):
			return kind
	return ""


## "flamengo_away" -> ["flamengo", "a"]; sem sufixo conhecido é o titular.
static func split_slot(stem: String) -> Array:
	var low := stem.to_lower()
	for sep in ["_", "-", " ", "."]:
		var i := low.rfind(sep)
		if i > 0 and KIT_SLOTS.has(low.substr(i + 1)):
			return [stem.substr(0, i), KIT_SLOTS[low.substr(i + 1)]]
	return [stem, "h"]


## Forma simplificada de um nome: minúsculas, sem acento, só letras e números.
static func slug(s: String) -> String:
	var low := s.strip_edges().to_lower()
	if low.to_utf8_buffer().size() != low.length():
		if _accents.is_empty():
			_build_accents()
		var out := ""
		for ch in low:
			out += String(_accents.get(ch, ch))
		low = out
	if _re == null:
		_re = RegEx.create_from_string("[^a-z0-9]")
	return _re.sub(low, "", true)


static func _build_accents() -> void:
	var m := {}
	for i in _ACCENTS_FROM.length():
		m[_ACCENTS_FROM[i]] = _ACCENTS_TO[i]
	for pair in _ACCENTS_MULTI.split(","):
		m[pair.get_slice("=", 0)] = pair.get_slice("=", 1)
	_accents = m


static func has_any(kind: String) -> bool:
	ensure()
	return not Dictionary(_idx.get(kind, {})).is_empty()


# ---------------------------------------------------------------------------
# Referências ("@pasta/nome") e caminhos
# ---------------------------------------------------------------------------

## Primeira referência encontrada entre os nomes candidatos ("" se nenhum arquivo casar).
static func ref(kind: String, names: Array, slot: String = "") -> String:
	ensure()
	var m: Dictionary = _idx.get(kind, {})
	if m.is_empty():
		return ""
	for n in names:
		var k := slug(String(n))
		if k == "":
			continue
		if slot != "":
			k += "|" + slot
		if m.has(k):
			return "@%s/%s" % [kind, k]
	return ""


## Caminho real de uma referência "@pasta/nome" ("" se o arquivo sumiu).
static func path_of_ref(r: String) -> String:
	ensure()
	var kind := r.substr(1).get_slice("/", 0)
	var key := r.substr(kind.length() + 2)
	var p := String(Dictionary(_idx.get(kind, {})).get(key, ""))
	return p if p != "" and FileAccess.file_exists(p) else ""


static func club_names(c: Club) -> Array:
	return [c.key, c.name, c.short_name, c.official, c.abbr]


static func player_names(p: Player) -> Array:
	var out: Array = [str(p.id), p.first_name + " " + p.last_name]
	if p.known_as != "":
		out.append(p.known_as)
	if p.nickname != "":
		out.append(p.nickname)
	return out


static func comp_names(id: String) -> Array:
	var cfg: Dictionary = DatabaseManager.league_cfg(id) if DatabaseManager.has_league(id) else DatabaseManager.cup_cfg(id)
	return [id, String(cfg.get("name", "")), String(cfg.get("short", ""))]


## Foto (recorte) de um jogador, se houver arquivo com o nome dele.
static func player_ref(p: Player) -> String:
	if p == null or not has_any("cutouts"):
		return ""
	return ref("cutouts", player_names(p))


static func comp_ref(id: String) -> String:
	if not has_any("logos"):
		return ""
	return ref("logos", comp_names(id))


static func stadium_ref(c: Club) -> String:
	if c == null or not has_any("stadiums"):
		return ""
	return ref("stadiums", club_names(c) + [c.stadium])


## Foto do estádio: a do editor/dados ou a solta na pasta stadiums/.
static func venue_photo(c: Club) -> Texture2D:
	if c == null:
		return null
	var t := CustomAssets.texture(String(c.venue.get("photo", "")))
	return t if t != null else CustomAssets.texture(stadium_ref(c))


# ---------------------------------------------------------------------------
# Mundo: escudos e camisas em imagem
# ---------------------------------------------------------------------------

## Marca escudos e camisas dos clubes com as imagens soltas (sem imagem própria dos dados ou do
## editor). Rodado ao criar/abrir uma carreira e no "Recarregar". Nada é apagado: sem o arquivo,
## a referência não acha nada e o desenho do jogo volta.
static func apply_world(w: GameWorld) -> void:
	if w == null:
		return
	ensure()
	var crests := has_any("crests")
	var kits := has_any("kits")
	for c: Club in w.clubs:
		if c == null:
			continue
		var names := club_names(c)
		var cur := String(c.crest.get("img", ""))
		if cur == "" or cur.begins_with("@"):
			var r := ref("crests", names) if crests else ""
			if r != "":
				c.crest["img"] = r
			elif cur != "":
				c.crest.erase("img")
		for pair in [["h", c.kit_home], ["a", c.kit_away], ["t", c.kit_third], ["g", c.kit_gk]]:
			var k: Dictionary = pair[1]
			if k.is_empty(): # terceiro/goleiro ainda não gerados
				continue
			var kr := ref("kits", names, String(pair[0])) if kits else ""
			if kr != "":
				k["img"] = kr
			elif String(k.get("img", "")).begins_with("@"):
				k.erase("img")


## Uniformes em JSON soltos em kits/ ({h, a, t, g}) de um pacote para um clube dos dados.
static func kit_json_for(pack_id: String, club: Dictionary) -> Dictionary:
	ensure()
	var m: Dictionary = _kit_json.get(pack_id, {})
	if m.is_empty():
		return {}
	for n in [club.get("key", ""), club.get("name", ""), club.get("short", ""), club.get("official", "")]:
		var k := slug(String(n))
		if k != "" and m.has(k):
			return m[k]
	return {}


# ---------------------------------------------------------------------------
# Relatório (Editor → Mods)
# ---------------------------------------------------------------------------

## Arquivos de um pacote e com quem casaram:
## {kind: {"ok": [[arquivo, dono]], "miss": [arquivo]}}; fotos de jogadores sem mundo para
## conferir ficam em "ok" com dono "?".
static func report(pack_id: String, world: GameWorld) -> Dictionary:
	ensure()
	var cache_key := "%s|%d" % [pack_id, world.get_instance_id() if world != null else 0]
	if _report_cache.has(cache_key):
		return _report_cache[cache_key]
	var names := _universe(world)
	var out := {}
	for e: Dictionary in _files.get(pack_id, []):
		var kind := String(e["kind"])
		if not out.has(kind):
			out[kind] = {"ok": [], "miss": []}
		var pool: Variant = names.get("clubs" if kind in ["crests", "kits", "stadiums"] else ("comps" if kind == "logos" else "players"), null)
		if pool == null:
			out[kind]["ok"].append([e["file"], "?"])
			continue
		var owner := String(pool.get(e["key"], ""))
		if owner == "" and kind == "stadiums":
			owner = String(names["stadiums"].get(e["key"], ""))
		if owner != "":
			out[kind]["ok"].append([e["file"], owner])
		else:
			out[kind]["miss"].append(e["file"])
	_report_cache[cache_key] = out
	return out


## Nomes conhecidos: {clubs: {nome: rótulo}, comps: {...}, players: {...} ou null, stadiums: {...}}.
static func _universe(world: GameWorld) -> Dictionary:
	var clubs := {}
	var stadiums := {}
	if world != null:
		for c: Club in world.clubs:
			if c == null:
				continue
			for n in club_names(c):
				var k := slug(String(n))
				if k != "" and not clubs.has(k):
					clubs[k] = c.name
			stadiums[slug(c.stadium)] = c.name
	else:
		for nation in DatabaseManager.league_nations():
			for d in DatabaseManager.club_data(nation):
				var o := Overrides.club(String(d.get("key", "")))
				var label := String(o.get("name", d.get("name", "")))
				for n in [d.get("key", ""), label, o.get("short", d.get("short", "")), d.get("official", ""), o.get("abbr", d.get("abbr", ""))]:
					var k := slug(String(n))
					if k != "" and not clubs.has(k):
						clubs[k] = label
				stadiums[slug(String(o.get("stadium", d.get("stadium", ""))))] = label
	stadiums.erase("")
	var comps := {}
	var ids: Array = Array(DatabaseManager.league_ids()) + DatabaseManager.cups_cfg().keys()
	for id in ids:
		var cn := comp_names(String(id))
		for n in cn:
			var k := slug(String(n))
			if k != "" and not comps.has(k):
				comps[k] = String(cn[1]) if String(cn[1]) != "" else String(id)
	var players: Variant = null
	if world != null and has_any("cutouts"):
		# Só os nomes que têm arquivo: evita simplificar os milhares de nomes à toa.
		var wanted := {}
		for id in _files:
			for e: Dictionary in _files[id]:
				if e["kind"] == "cutouts":
					wanted[e["key"]] = true
		players = {}
		for p: Player in world.players.values():
			for n in player_names(p):
				var k := slug(String(n))
				if wanted.has(k) and not players.has(k):
					players[k] = p.first_name + " " + p.last_name
	return {"clubs": clubs, "comps": comps, "players": players, "stadiums": stadiums}


## Arquivos soltos de um pacote, por tipo (sem conferir com quem casam).
static func counts(pack_id: String) -> Dictionary:
	ensure()
	var out := {}
	for e: Dictionary in _files.get(pack_id, []):
		out[e["kind"]] = int(out.get(e["kind"], 0)) + 1
	return out
