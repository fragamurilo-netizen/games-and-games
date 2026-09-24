class_name NameGenerator
extends RefCounted
## Gera nomes coerentes por cultura, apelidos (diminutivos, regionais e descritivos)
## e o "nome de camisa" (known_as). Evita nomes completos repetidos no mundo.

const MAX_TRIES := 12

static var _nat_codes: Array = []
static var _nat_weights: Array = []
static var _nat_by_code: Dictionary = {}


static func _prepare() -> void:
	if not _nat_codes.is_empty():
		return
	for n in DatabaseManager.names()["nationalities"]:
		_nat_by_code[n["code"]] = n
		if float(n["weight"]) > 0.0:
			_nat_codes.append(n["code"])
			_nat_weights.append(float(n["weight"]))


static func nationality_name(code: String) -> String:
	_prepare()
	return _nat_by_code.get(code, {}).get("name", code)


static func culture_of(code: String) -> String:
	_prepare()
	return _nat_by_code.get(code, {}).get("culture", "luso")


## Sorteia a nacionalidade conforme a divisão (mais estrangeiros no topo).
static func pick_nationality(rng: RandomNumberGenerator, division: int) -> String:
	_prepare()
	var shares: Array = DatabaseManager.names()["foreign_share_by_division"]
	var share: float = shares[clampi(division, 0, shares.size() - 1)]
	if rng.randf() >= share:
		return "VAL"
	var i := RngUtil.weighted_index(rng, _nat_weights)
	return _nat_codes[i]


## ctx: {pos, height, foot, attrs (PackedByteArray), region}
## used: Dictionary de nomes completos já usados (é atualizado).
static func generate(rng: RandomNumberGenerator, nationality: String, ctx: Dictionary, used: Dictionary) -> Dictionary:
	var culture_id := culture_of(nationality)
	var cultures: Dictionary = DatabaseManager.names()["cultures"]
	var c: Dictionary = cultures.get(culture_id, cultures["luso"])
	var first := ""
	var last := ""
	var full := ""
	for _i in MAX_TRIES:
		first = _pick_first(rng, c)
		last = RngUtil.pick(rng, c["last"])
		if c.has("suffixes") and rng.randf() < float(c.get("suffix_chance", 0.0)):
			last += " " + RngUtil.pick(rng, c["suffixes"])
		elif rng.randf() < 0.25 and culture_id == "luso":
			# Sobrenome duplo é comum: "Pereira Lima"
			var extra: String = RngUtil.pick(rng, c["last"])
			if extra != last:
				last = extra + " " + last if rng.randf() < 0.5 else last
		full = first + " " + last
		if not used.has(full):
			break
	used[full] = true
	var nickname := ""
	var known_by: Dictionary = c.get("known_by", {"last": 1.0})
	var mode: String = RngUtil.weighted_key(rng, known_by)
	if mode == "nickname":
		nickname = _make_nickname(rng, c, first, last, ctx)
		if nickname == "":
			mode = "last"
	var known := ""
	match mode:
		"nickname":
			known = nickname
		"first":
			known = first
		"full":
			known = first.get_slice(" ", 0) + " " + _main_surname(last)
		_:
			known = _main_surname(last)
	return {"first": first, "last": last, "nickname": nickname, "known_as": known}


static func _pick_first(rng: RandomNumberGenerator, c: Dictionary) -> String:
	if c.has("compound") and rng.randf() < float(c.get("compound_chance", 0.0)):
		return RngUtil.pick(rng, c["compound"])
	return RngUtil.pick(rng, c["first"])


static func _is_suffix(last: String) -> bool:
	return last.ends_with(" Júnior") or last.ends_with(" Filho") or last.ends_with(" Neto")


## "Pereira Lima" -> "Lima"; "Silva Júnior" -> "Silva".
static func _main_surname(last: String) -> String:
	var parts := last.split(" ")
	if parts.size() == 1:
		return last
	if _is_suffix(last):
		return parts[parts.size() - 2]
	return parts[parts.size() - 1]


static func _make_nickname(rng: RandomNumberGenerator, c: Dictionary, first: String, last: String, ctx: Dictionary) -> String:
	var options: Array = []
	var first_base := first.get_slice(" ", 0)
	# Diminutivo do primeiro nome
	var dims: Dictionary = c.get("diminutives", {})
	if dims.has(first_base) and rng.randf() < 0.5:
		return RngUtil.pick(rng, dims[first_base])
	# Júnior -> Juninho
	if last.ends_with("Júnior") and rng.randf() < 0.6:
		return "Juninho"
	# Regional (conforme a cidade natal)
	var regional: Dictionary = c.get("regional", {})
	var region: String = ctx.get("region", "")
	if region != "" and regional.has(region) and rng.randf() < 0.3:
		return RngUtil.pick(rng, regional[region])
	# Descritivo: depende de físico e atributos
	var desc: Dictionary = c.get("descriptive", {})
	if desc.is_empty():
		return ""
	var pos: int = ctx.get("pos", Pos.CM)
	var h: int = ctx.get("height", 178)
	var a: PackedByteArray = ctx.get("attrs", PackedByteArray())
	if a.size() == Attr.COUNT:
		if pos == Pos.GK and desc.has("keeper"):
			options.append("keeper")
		if h >= 192 and desc.has("tall"):
			options.append("tall")
		if h <= 168 and desc.has("short"):
			options.append("short")
		if ctx.get("foot", 0) == Player.FOOT_LEFT and pos != Pos.GK and desc.has("left"):
			options.append("left")
		if a[Attr.VEL] >= 78 and desc.has("fast"):
			options.append("fast")
		if pos == Pos.CB and a[Attr.MAR] >= 65 and desc.has("defender"):
			options.append("defender")
		if pos == Pos.DM and a[Attr.MAR] >= 62 and desc.has("destroyer"):
			options.append("destroyer")
		if (pos == Pos.CM or pos == Pos.AM) and a[Attr.VIS] >= 66 and desc.has("playmaker"):
			options.append("playmaker")
		if pos == Pos.ST and a[Attr.FOR] >= 70 and desc.has("strong"):
			options.append("strong")
		if a[Attr.TEC] >= 76 and desc.has("skill"):
			options.append("skill")
	if not options.is_empty() and rng.randf() < 0.75:
		var key: String = RngUtil.pick(rng, options)
		return RngUtil.pick(rng, desc[key])
	if desc.has("generic"):
		return RngUtil.pick(rng, desc["generic"])
	return ""
