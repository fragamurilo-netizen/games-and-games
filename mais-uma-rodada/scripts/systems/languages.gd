class_name Languages
extends RefCounted
## Idiomas de verdade (data/world/languages.json): cada país fala uma ou mais línguas; cada
## jogador nasce falando a da sua terra (nos países bilíngues, uma delas, com noção da outra) e
## um tanto de inglês conforme o país; e aprende a língua do clube com o tempo — mais rápido se é
## jovem, se adapta fácil ou se a língua é parecida (português e espanhol se entendem).
##
## Efeitos: o vestiário (quem não se comunica fica isolado e as panelinhas se formam pela língua),
## o entrosamento do time titular, a disposição de ir para um país e o técnico estrangeiro (que
## também aprende). Tudo em texto: nativo, fluente, bom, básico — nunca número.
##
## Estado: Player.langs {código: fluência 0..100} (salvo como "lng"); o do técnico fica em
## world.manager["lng"].

const NATIVE := 100.0
## Cidades onde a língua do clube não é a principal do país.
const CITY_LANG := {"Genève": "fr", "Lausanne": "fr", "Sion": "fr", "Yverdon-les-Bains": "fr", "Lugano": "it",
	"Charleroi": "fr", "Liège": "fr", "Bruxelles": "fr", "Montréal": "fr"}

static var _d: Dictionary = {}
static var _near: Dictionary = {}


static func _data() -> Dictionary:
	if _d.is_empty():
		var v: Variant = DatabaseManager.read_modded("res://data/world/languages.json")
		_d = v if v is Dictionary else {"names": {}, "nations": {}, "near": []}
		_near.clear()
		for e in _d.get("near", []):
			for ab in [[String(e[0]), String(e[1])], [String(e[1]), String(e[0])]]:
				if not _near.has(ab[0]):
					_near[ab[0]] = {}
				_near[ab[0]][ab[1]] = float(e[2])
	return _d


static func name_of(code: String) -> String:
	return String(_data()["names"].get(code, code))


## Línguas faladas no país: [[código, parcela]].
static func of_nation(nation: String) -> Array:
	return _data()["nations"].get(nation, {}).get("l", [["en", 1.0]])


## Língua principal do país.
static func primary(nation: String) -> String:
	return String(of_nation(nation)[0][0])


## Nível de inglês comum entre os jogadores do país (0..1; 1 para quem é nativo).
static func english_level(nation: String) -> float:
	var n: Dictionary = _data()["nations"].get(nation, {})
	for l in n.get("l", []):
		if String(l[0]) == "en":
			return 1.0
	return float(n.get("en", 0.3))


## Quanto quem fala `a` entende de `b` (0..1).
static func similarity(a: String, b: String) -> float:
	if a == b:
		return 1.0
	_data()
	var row: Variant = _near.get(a) # língua → língua → parecença (sem montar texto a cada consulta)
	return float(row.get(b, 0.0)) if row != null else 0.0


## Língua do vestiário do clube.
static func club_lang(c: Club) -> String:
	if CITY_LANG.has(c.city):
		return String(CITY_LANG[c.city])
	return primary(c.nation)


# ---------------------------------------------------------------------------
# O que cada um fala
# ---------------------------------------------------------------------------

## Línguas do jogador (criadas na primeira consulta, sem mexer no RNG do mundo).
static func of(p: Player) -> Dictionary:
	if not p.langs.is_empty():
		return p.langs
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, "idiomas"])
	var out := {}
	var born := NationalityManager.birth_country(p)
	for nat in ([born, p.nationality] if born != p.nationality else [p.nationality]):
		var ls := of_nation(nat)
		# Nos países com mais de uma língua, a pessoa é nativa numa e tem noção das outras.
		var w := {}
		for l in ls:
			w[String(l[0])] = float(l[1])
		var mine := String(RngUtil.weighted_key(r, w))
		out[mine] = NATIVE
		for l in ls:
			var code := String(l[0])
			if code != mine and float(l[1]) >= 0.15:
				out[code] = maxf(float(out.get(code, 0.0)), r.randf_range(30.0, 75.0))
	if not out.has("en"):
		var en := english_level(born) * r.randf_range(0.35, 1.25) * 100.0
		if en >= 15.0:
			out["en"] = minf(90.0, en)
	p.langs = out
	return out


## Mundo novo ou save antigo: todos ganham as línguas da terra e as dos países onde já jogaram
## (cada ano numa passagem ensina boa parte da língua de lá).
static func init_world(world: GameWorld) -> void:
	for p: Player in world.players.values():
		var ls := of(p)
		for s in p.spells:
			var c := world.club(int(s.get("c", -1)))
			if c == null:
				continue
			var to := int(s.get("to", 0))
			var yrs := maxi(1, (to if to > 0 else world.year) - int(s.get("from", world.year)))
			var code := club_lang(c)
			ls[code] = maxf(float(ls.get(code, 0.0)), minf(95.0, yrs * 32.0))
		var cur := world.club(p.club_id)
		if cur != null:
			var code2 := club_lang(cur)
			ls[code2] = maxf(float(ls.get(code2, 0.0)), minf(95.0, maxi(0, world.year - p.joined_year) * 32.0))
	world.stats["lng_v"] = 1


## Fluência numa língua contando as parecidas (o brasileiro entende espanhol de cara).
static func level(p: Player, code: String) -> float:
	var best := 0.0
	var ls := of(p)
	for k in ls:
		best = maxf(best, float(ls[k]) * similarity(String(k), code))
	return best


## Comunicação do jogador no clube (0..1): a língua do vestiário ou, onde o inglês corre solto, o inglês.
static func comm(p: Player, c: Club) -> float:
	return _comm(p, club_lang(c), english_level(c.nation))


## `comm` com a língua do clube e o inglês do país já lidos (o vestiário inteiro de uma vez).
static func _comm(p: Player, code: String, en_lvl: float) -> float:
	var main := level(p, code) / 100.0
	var en := level(p, "en") / 100.0 * en_lvl
	return clampf(maxf(main, en * 0.9), 0.0, 1.0)


static func label(fl: float) -> String:
	if fl >= NATIVE:
		return "nativo"
	if fl >= 80.0:
		return "fluente"
	if fl >= 55.0:
		return "bom"
	if fl >= 25.0:
		return "básico"
	return ""


## "Português (nativo) · Espanhol (fluente) · Inglês (básico)".
static func text(p: Player) -> String:
	return _text_of(of(p))


static func _text_of(ls: Dictionary) -> String:
	var keys := ls.keys()
	keys.sort_custom(func(a, b): return float(ls[a]) > float(ls[b]))
	var parts: PackedStringArray = []
	for k in keys:
		var lb := label(float(ls[k]))
		if lb != "":
			parts.append("%s (%s)" % [I18n.t(name_of(String(k))), I18n.t(lb)])
	return " · ".join(parts)


# ---------------------------------------------------------------------------
# Aprendizado (uma vez por mês)
# ---------------------------------------------------------------------------

static func monthly(world: GameWorld) -> void:
	for c: Club in world.clubs:
		if c.is_pool():
			continue
		var code := club_lang(c)
		var squad: Array = world.squad(c)
		var native_mates := {}
		for p: Player in squad:
			var pl := primary(p.nationality)
			native_mates[pl] = int(native_mates.get(pl, 0)) + 1
		for p: Player in squad:
			var cur := float(of(p).get(code, 0.0))
			if cur >= 95.0:
				continue
			var age := p.age(world.year)
			var gain := 6.0 * clampf(1.45 - (age - 18) * 0.035, 0.55, 1.45) * (0.5 + p.hid("ada") / 20.0)
			gain *= 1.0 + level(p, code) / 200.0 # quem já entende algo aprende mais rápido
			if int(native_mates.get(primary(p.nationality), 0)) >= 3:
				gain *= 0.75 # com muitos compatriotas, a língua nova demora
			p.langs[code] = minf(95.0, cur + gain)
	_coach_month(world)


# ---------------------------------------------------------------------------
# Técnico
# ---------------------------------------------------------------------------

static func coach(world: GameWorld) -> Dictionary:
	var m := ManagerProfile.data(world)
	if not m.has("lng") or (m["lng"] as Dictionary).is_empty():
		var nat := String(m.get("nat", "BRA"))
		var out := {primary(nat): NATIVE}
		if not out.has("en"):
			out["en"] = clampf(english_level(nat) * 100.0, 20.0, 85.0)
		m["lng"] = out
	return m["lng"]


static func coach_text(world: GameWorld) -> String:
	return _text_of(coach(world))


## Comunicação do técnico com o vestiário do clube (0..1).
static func coach_comm(world: GameWorld, c: Club) -> float:
	var ls := coach(world)
	var code := club_lang(c)
	var best := 0.0
	for k in ls:
		best = maxf(best, float(ls[k]) * similarity(String(k), code))
		if String(k) == "en":
			best = maxf(best, float(ls[k]) * english_level(c.nation) * 0.9)
	return clampf(best / 100.0, 0.0, 1.0)


static func _coach_month(world: GameWorld) -> void:
	if not world.has_user():
		return
	var ls := coach(world)
	var code := club_lang(world.user_club())
	var cur := float(ls.get(code, 0.0))
	if cur < 95.0:
		ls[code] = minf(95.0, cur + 5.0 + cur / 40.0)


# ---------------------------------------------------------------------------
# Efeitos
# ---------------------------------------------------------------------------

## Entrosamento da semana: titulares que não se entendem atrapalham (negativo) — os 14 mais usados.
static func cohesion_push(world: GameWorld, c: Club) -> float:
	var squad: Array = world.squad(c)
	if squad.is_empty():
		return 0.0
	# Os 14 que mais jogam (empate: o melhor). Ordenação nativa de [jogos, overall, índice]: a
	# comparação por função custava mais que o resto da semana do clube.
	var keys: Array = []
	for i in squad.size():
		var q: Player = squad[i]
		keys.append([q.stats[Player.S_APPS], q.ovr_f, -i])
	keys.sort()
	var tot := 0.0
	var n := mini(14, keys.size())
	var code := club_lang(c)
	var en_lvl := english_level(c.nation)
	for k in n:
		tot += _comm(squad[-int(keys[keys.size() - 1 - k][2])], code, en_lvl)
	var avg := tot / float(n)
	return minf(0.0, (avg - 0.8) * 0.6)


## Facilidade de ir para um clube (para o interesse em transferências): -0,05..+0,08.
static func ease(p: Player, buyer: Club, age: int) -> float:
	var cm := comm(p, buyer)
	if cm >= 0.8:
		return 0.06 + (0.02 if primary(p.nationality) == club_lang(buyer) else 0.0)
	if cm >= 0.5:
		return 0.02
	return -0.04 if age >= 29 else -0.01
