class_name Overrides
extends RefCounted
## Personalizações do editor que valem para todas as carreiras (user://custom/overrides.json):
## nomes, cores e escudos de clubes (pela chave estável do clube), nomes/logos/cores das competições
## e jogadores editados ou criados no Editor geral (PlayerMods).

const PATH := "user://custom/overrides.json"
const CLUB_FIELDS: Array[String] = ["name", "short", "abbr", "nick", "city", "stadium", "c1", "c2", "crest"]

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
	data()["clubs"][c.key] = {"name": c.name, "short": c.short_name, "abbr": c.abbr, "nick": c.nickname, "city": c.city,
		"stadium": c.stadium, "c1": c.color1, "c2": c.color2, "crest": c.crest.duplicate(true)}
	save()


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
	if o.has("c1"):
		set_colors(c, String(o["c1"]), String(o.get("c2", c.color2)))
	if o.get("crest", {}) is Dictionary and not o.get("crest", {}).is_empty():
		c.crest = o["crest"].duplicate(true)


## Troca as cores do clube mantendo escudo e uniformes coerentes.
static func set_colors(c: Club, c1: String, c2: String) -> void:
	c.color1 = c1
	c.color2 = c2
	c.crest["c1"] = c1
	c.crest["c2"] = c2
	c.kit_home["c1"] = c1
	c.kit_home["c2"] = c2


# ---------------------------------------------------------------------------
# Competições (ligas e copas): o banco de dados é corrigido em memória
# ---------------------------------------------------------------------------

static func comp(kind: String, id: String) -> Dictionary:
	return data()[kind].get(id, {})


static func store_comp(kind: String, id: String, name: String, short: String, logo: String, colors: Array = []) -> void:
	var e := {"name": name, "short": short}
	if logo != "":
		e["logo"] = logo
	if colors.size() == 2:
		e["colors"] = colors.duplicate()
	data()[kind][id] = e
	save()
	apply_db()


static func clear_comp(kind: String, id: String) -> void:
	data()[kind].erase(id)
	save()


## Aplica nomes, logos e cores personalizados às configurações carregadas.
static func apply_db() -> void:
	for id in data()["leagues"]:
		if DatabaseManager.has_league(id):
			var cfg := DatabaseManager.league_cfg(id)
			var o: Dictionary = data()["leagues"][id]
			cfg["name"] = String(o.get("name", cfg.get("name", id)))
			cfg["short"] = String(o.get("short", cfg.get("short", id)))
			cfg["logo"] = String(o.get("logo", ""))
			_apply_colors(cfg, o)
	for id in data()["cups"]:
		var cfg := DatabaseManager.cup_cfg(id)
		if cfg.is_empty():
			continue
		var o: Dictionary = data()["cups"][id]
		cfg["name"] = String(o.get("name", cfg.get("name", id)))
		cfg["short"] = String(o.get("short", cfg.get("short", id)))
		cfg["logo"] = String(o.get("logo", ""))
		_apply_colors(cfg, o)


static func _apply_colors(cfg: Dictionary, o: Dictionary) -> void:
	var cols: Variant = o.get("colors", [])
	if cols is Array and cols.size() == 2:
		cfg["colors"] = [String(cols[0]), String(cols[1])]


static func logo_of(id: String) -> Texture2D:
	var cfg: Dictionary = DatabaseManager.league_cfg(id) if DatabaseManager.has_league(id) else DatabaseManager.cup_cfg(id)
	return CustomAssets.texture(String(cfg.get("logo", "")))
