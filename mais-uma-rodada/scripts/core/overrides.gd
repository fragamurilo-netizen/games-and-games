class_name Overrides
extends RefCounted
## Personalizações do editor que valem para todas as carreiras (user://custom/overrides.json):
## nomes, cores, escudos, estádios e uniformes de clubes (pela chave estável do clube), nomes, logos,
## cores e placar das competições e jogadores editados ou criados no Editor geral (PlayerMods).
## Tudo isso pode virar um mod (Mods.export_folder / export_bundle).
##
## clubs[chave]: {name, short, abbr, nick, city, official, stadium, cap, venue: {kind, photo, ...},
##   c1, c2, crest, kits: {h, a, t, g}, sponsors}
## leagues[id] / cups[id]: {name, short, logo, colors: [2], scoreboard: {colors: [3], layout}}

const PATH := "user://custom/overrides.json"
const CLUB_FIELDS: Array[String] = ["name", "short", "abbr", "nick", "city", "official", "stadium", "cap", "venue", "c1", "c2", "crest", "kits"]

static var _data: Dictionary = {}
static var _loaded := false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		_data = {"clubs": {}, "leagues": {}, "cups": {}, "players": []}
		if FileAccess.file_exists(PATH):
			var f := FileAccess.open(PATH, FileAccess.READ)
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in ["clubs", "leagues", "cups"]:
					_data[k] = parsed.get(k, {})
				_data["players"] = Array(parsed.get("players", []))
	return _data


static func save() -> void:
	DirAccess.make_dir_recursive_absolute("user://custom")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data(), "\t"))


# ---------------------------------------------------------------------------
# Clubes
# ---------------------------------------------------------------------------

static func club(key: String) -> Dictionary:
	return data()["clubs"].get(key, {})


## Guarda o visual/nome atual de um clube como padrão das próximas carreiras.
static func store_club(c: Club) -> void:
	var e := {"name": c.name, "short": c.short_name, "abbr": c.abbr, "nick": c.nickname, "city": c.city,
		"stadium": c.stadium, "cap": c.capacity, "c1": c.color1, "c2": c.color2, "crest": c.crest.duplicate(true),
		"kits": kits_of(c)}
	if c.official != "":
		e["official"] = c.official
	if not c.venue.is_empty():
		e["venue"] = c.venue.duplicate(true)
	data()["clubs"][c.key] = e
	save()


## Os quatro uniformes do clube, sem os logos de patrocinadores (que são contratos, não desenho).
static func kits_of(c: Club) -> Dictionary:
	var out := {}
	for f in [["h", c.kit_home], ["a", c.kit_away], ["t", c.third_kit()], ["g", c.gk_kit()]]:
		var k: Dictionary = (f[1] as Dictionary).duplicate(true)
		for key in KitDesign._sponsor_keys(k):
			k.erase(key)
		out[f[0]] = k
	return out


static func clear_club(key: String) -> void:
	data()["clubs"].erase(key)
	save()


static func apply_club(c: Club) -> void:
	var o := club(c.key)
	if o.is_empty():
		return
	c.name = String(o.get("name", c.name))
	c.short_name = String(o.get("short", c.short_name))
	c.abbr = String(o.get("abbr", c.abbr))
	c.nickname = String(o.get("nick", c.nickname))
	c.city = String(o.get("city", c.city))
	c.stadium = String(o.get("stadium", c.stadium))
	c.official = String(o.get("official", c.official))
	if o.has("cap"):
		c.capacity = maxi(500, int(o["cap"]))
	if o.get("venue", null) is Dictionary:
		c.venue = o["venue"].duplicate(true)
	if o.has("c1"):
		# Uniformes do editor (DatabaseManager.club_kits) já vêm certos: as cores não mexem neles.
		set_colors(c, String(o["c1"]), String(o.get("c2", c.color2)), not o.has("kits"))
	if o.get("crest", {}) is Dictionary and not o.get("crest", {}).is_empty():
		c.crest = o["crest"].duplicate(true)


## Troca as cores do clube mantendo escudo e uniformes coerentes.
static func set_colors(c: Club, c1: String, c2: String, kits: bool = true) -> void:
	c.color1 = c1
	c.color2 = c2
	c.crest["c1"] = c1
	c.crest["c2"] = c2
	if kits:
		c.kit_home["c1"] = c1
		c.kit_home["c2"] = c2


# ---------------------------------------------------------------------------
# Competições (ligas e copas): o banco de dados é corrigido em memória
# ---------------------------------------------------------------------------

static func comp(kind: String, id: String) -> Dictionary:
	return data()[kind].get(id, {})


static func store_comp(kind: String, id: String, name: String, short: String, logo: String, colors: Array = []) -> void:
	var e: Dictionary = comp(kind, id).duplicate(true)
	e["name"] = name
	e["short"] = short
	e["logo"] = logo
	if colors.size() == 2:
		e["colors"] = colors.duplicate()
	data()[kind][id] = e
	save()
	apply_db()


## Placar da TV de uma competição: {colors: [fundo, fundo 2, destaque], layout} ({} = padrão).
static func store_scoreboard(kind: String, id: String, sb: Dictionary) -> void:
	var e: Dictionary = comp(kind, id).duplicate(true)
	if sb.is_empty():
		e.erase("scoreboard")
		var cfg := _cfg(kind, id)
		cfg.erase("scoreboard")
		if cfg.get("_orig", {}).has("scoreboard"):
			cfg["scoreboard"] = cfg["_orig"]["scoreboard"]
	else:
		e["scoreboard"] = sb.duplicate(true)
	data()[kind][id] = e
	save()
	apply_db()


static func clear_comp(kind: String, id: String) -> void:
	data()[kind].erase(id)
	save()
	_revert(_cfg(kind, id))


## Aplica nomes, logos e cores personalizados às configurações carregadas.
static func apply_db() -> void:
	for id in data()["leagues"]:
		if DatabaseManager.has_league(id):
			var cfg := DatabaseManager.league_cfg(id)
			var o: Dictionary = data()["leagues"][id]
			_apply_comp(cfg, o, id)
	for id in data()["cups"]:
		var cfg := DatabaseManager.cup_cfg(id)
		if cfg.is_empty():
			continue
		_apply_comp(cfg, data()["cups"][id], id)


const _COMP_KEYS := ["name", "short", "logo", "colors", "scoreboard"]


static func _cfg(kind: String, id: String) -> Dictionary:
	if kind == "leagues":
		return DatabaseManager.league_cfg(id) if DatabaseManager.has_league(id) else {}
	return DatabaseManager.cup_cfg(id)


## Volta uma competição aos valores dos dados (guardados antes da primeira personalização).
static func _revert(cfg: Dictionary) -> void:
	if not cfg.has("_orig"):
		return
	var orig: Dictionary = cfg["_orig"]
	for k in _COMP_KEYS:
		cfg.erase(k)
		if orig.has(k):
			cfg[k] = orig[k]
	cfg.erase("_orig")


static func _apply_comp(cfg: Dictionary, o: Dictionary, id: String) -> void:
	if not cfg.has("_orig"):
		var orig := {}
		for k in _COMP_KEYS:
			if cfg.has(k):
				orig[k] = cfg[k].duplicate(true) if cfg[k] is Dictionary or cfg[k] is Array else cfg[k]
		cfg["_orig"] = orig
	cfg["name"] = String(o.get("name", cfg.get("name", id)))
	cfg["short"] = String(o.get("short", cfg.get("short", id)))
	cfg["logo"] = String(o.get("logo", cfg.get("logo", "")))
	_apply_colors(cfg, o)
	if o.get("scoreboard", null) is Dictionary:
		cfg["scoreboard"] = o["scoreboard"].duplicate(true)


static func _apply_colors(cfg: Dictionary, o: Dictionary) -> void:
	var cols: Variant = o.get("colors", [])
	if cols is Array and cols.size() == 2:
		cfg["colors"] = [String(cols[0]), String(cols[1])]


static func logo_of(id: String) -> Texture2D:
	var cfg: Dictionary = DatabaseManager.league_cfg(id) if DatabaseManager.has_league(id) else DatabaseManager.cup_cfg(id)
	return CustomAssets.texture(String(cfg.get("logo", "")))
