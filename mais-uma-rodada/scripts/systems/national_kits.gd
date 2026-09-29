class_name NationalKits
extends RefCounted
## Uniformes das seleções, desenhados pelo mesmo KitView dos clubes: titular e reserva pelas cores
## tradicionais (data/world/national_kits.json) ou, para quem não está na lista, pelas cores da
## bandeira; goleiro gerado como nos clubes. O técnico da seleção pode redesenhá-los no editor de
## uniformes (KitScreen com "nation"): a versão dele fica em world.stats["intl"]["kits"][nação].

const KEY := "kits"
const WHITE := "#FFFFFF"
const NAVY := "#0B1F4B"

static var _cache := {}


## {"home", "away", "gk"} de uma seleção (os editados pelo usuário, se houver).
static func kits(world: GameWorld, code: String) -> Dictionary:
	var own: Dictionary = NationalTeamManager.data(world).get(KEY, {}).get(code, {})
	if not own.is_empty():
		return {"home": own.get("h", {}), "away": own.get("a", {}), "gk": own.get("g", {})}
	var d := defaults(code)
	return {"home": d["h"], "away": d["a"], "gk": d["g"]}


static func home(world: GameWorld, code: String) -> Dictionary:
	return kits(world, code)["home"]


## Padrão da seleção (sem edição do usuário): {h, a, g}.
static func defaults(code: String) -> Dictionary:
	if not _cache.has(code):
		_cache[code] = _build_defaults(code)
	return (_cache[code] as Dictionary).duplicate(true)


static func _build_defaults(code: String) -> Dictionary:
	var cur: Dictionary = DatabaseManager.get_data("national_kits").get("kits", {}).get(code, {})
	var h: Dictionary
	var a: Dictionary
	if not cur.is_empty():
		h = (cur["h"] as Dictionary).duplicate(true)
		a = (cur["a"] as Dictionary).duplicate(true)
	else:
		var gen := _from_flag(code)
		h = gen[0]
		a = gen[1]
	var proxy := _bare_club(code, h, a)
	return {"h": h, "a": a, "g": ClubGenerator.make_gk_kit(proxy)}


## Titular na cor mais forte da bandeira; reserva branca (ou escura, se o titular já é claro).
static func _from_flag(code: String) -> Array:
	var cols: Array = DatabaseManager.nation(code).get("flag", {}).get("c", [WHITE, NAVY])
	var main := String(cols[0])
	for c in cols:
		if Color(String(c)).get_luminance() < 0.85:
			main = String(c)
			break
	var second := WHITE
	for c in cols:
		if String(c) != main:
			second = String(c)
			break
	if KitDesign.delta_e(Color(main), Color(second)) < 25.0:
		second = WHITE if Color(main).get_luminance() < 0.6 else NAVY
	var h := {"pattern": "plain", "c1": main, "c2": second, "c3": second, "shorts": second if Color(second).get_luminance() > 0.7 else main,
		"socks": main, "collar": "round", "sleeve": "cuff"}
	var light := Color(main).get_luminance() > 0.7
	var ac := NAVY if light else WHITE
	var a := {"pattern": "plain", "c1": ac, "c2": main, "c3": main, "shorts": ac, "socks": ac, "collar": "round", "sleeve": "cuff"}
	return [h, a]


static func _bare_club(code: String, h: Dictionary, a: Dictionary) -> Club:
	var c := Club.new()
	c.id = -1
	c.key = "SEL_" + code
	c.nation = code
	c.name = DatabaseManager.nation_name(code)
	c.short_name = c.name
	c.color1 = String(h.get("c1", WHITE))
	c.color2 = String(h.get("c2", NAVY))
	c.kit_home = h
	c.kit_away = a
	return c


## Clube "de mentira" da seleção para o editor de uniformes: os dicionários são os guardados no
## save (a edição fica gravada direto). Cria a cópia editável na primeira vez.
static func proxy_club(world: GameWorld, code: String) -> Club:
	var d := NationalTeamManager.data(world)
	if not d.has(KEY):
		d[KEY] = {}
	var all: Dictionary = d[KEY]
	if not all.has(code):
		var base := defaults(code)
		all[code] = {"h": base["h"], "a": base["a"], "g": base["g"]}
	var own: Dictionary = all[code]
	var c := _bare_club(code, own["h"], own["a"])
	c.kit_gk = own["g"]
	return c


## Volta ao uniforme tradicional.
static func reset(world: GameWorld, code: String) -> void:
	var all: Dictionary = NationalTeamManager.data(world).get(KEY, {})
	all.erase(code)
