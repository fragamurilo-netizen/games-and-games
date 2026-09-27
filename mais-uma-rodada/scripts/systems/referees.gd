class_name Referees
extends RefCounted
## Arbitragem: cada país tem um quadro de árbitros com perfil próprio (rigor nos cartões, facilidade
## para marcar pênalti, quanto deixa o jogo correr) e nível (os melhores apitam os jogos grandes).
## O árbitro de cada jogo entra no contexto da partida e mexe de verdade no motor (cartões, faltas,
## pênaltis). Copas continentais usam árbitros de outro país da confederação.
## Estado em world.stats["refs"]: {nação: [{id, n, nat, age, st, pn, adv, lv, g, y, r, p}]}; os números
## (g jogos, y amarelos, r vermelhos, p pênaltis) são da temporada e zeram na virada.

const PER_NATION := 14
const KEY := "refs"


static func data(world: GameWorld) -> Dictionary:
	if not world.stats.has(KEY):
		world.stats[KEY] = {}
	return world.stats[KEY]


## Quadro de árbitros de uma nação (gerado na primeira vez, sempre igual para o mesmo mundo).
static func pool(world: GameWorld, nation: String) -> Array:
	var d := data(world)
	if d.has(nation):
		return d[nation]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "refs", nation])
	var used := {}
	var out: Array = []
	for i in PER_NATION:
		var origin := NameGenerator.pick_origin(rng, nation)
		var nm := NameGenerator.generate(rng, String(origin["c"]), {"pos": Pos.CM, "height": 180, "foot": 0, "attrs": PackedByteArray(), "region": ""}, used)
		var full := ("%s %s" % [nm["first"], nm["last"]]).strip_edges()
		# Nível: poucos de elite (1), a maioria intermediária (2), alguns iniciantes (3).
		var lv := 1 if i < 3 else (2 if i < 10 else 3)
		out.append({"id": i, "n": full, "nat": nation, "age": rng.randi_range(31, 46) + (3 if lv == 1 else 0),
			"st": snappedf(clampf(rng.randfn(1.0, 0.13), 0.72, 1.35), 0.01),
			"pn": snappedf(clampf(rng.randfn(1.0, 0.18), 0.6, 1.5), 0.01),
			"adv": snappedf(clampf(rng.randfn(1.0, 0.08), 0.82, 1.18), 0.01),
			"lv": lv, "g": 0, "y": 0, "r": 0, "p": 0})
	d[nation] = out
	return out


static func get_ref(world: GameWorld, nation: String, id: int) -> Dictionary:
	var list := pool(world, nation)
	if id >= 0 and id < list.size():
		return list[id]
	return {}


## Escala o árbitro de um jogo: [nação, id]. Jogo grande pede árbitro de elite. Determinístico
## pelo jogo (não gasta o sorteio do mundo).
static func assign(world: GameWorld, f: Fixture, importance: float) -> Array:
	var home := world.club(f.home)
	var nation := home.nation if home != null else "BRA"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, f.home, f.away, f.round, f.comp])
	var league_cup := f.is_league() or world.league(f.comp) != null or CupManager.is_domestic(f.comp) or CupManager.is_state(f.comp)
	if not league_cup:
		# Copa continental ou Mundial: árbitro de um terceiro país da mesma confederação.
		var away := world.club(f.away)
		var confed := String(DatabaseManager.nation(nation).get("confed", ""))
		var options: Array = []
		for n in DatabaseManager.league_nations():
			if n == nation or (away != null and n == away.nation):
				continue
			if confed == "" or String(DatabaseManager.nation(n).get("confed", "")) == confed:
				options.append(n)
		if not options.is_empty():
			nation = String(options[rng.randi_range(0, options.size() - 1)])
	var list := pool(world, nation)
	var weights: Array = []
	for r: Dictionary in list:
		var lv := int(r["lv"])
		var w := 1.0
		if importance >= 0.7:
			w = [0.0, 4.0, 1.0, 0.1][lv]
		elif importance >= 0.45:
			w = [0.0, 1.6, 1.5, 0.5][lv]
		else:
			w = [0.0, 0.6, 1.3, 1.4][lv]
		weights.append(w)
	var idx := maxi(0, RngUtil.weighted_index(rng, weights))
	return [nation, idx]


## Multiplicadores do árbitro no motor: {"cards", "pens", "fouls"}.
static func factors(world: GameWorld, ref: Array) -> Dictionary:
	if ref.size() < 2:
		return {"cards": 1.0, "pens": 1.0, "fouls": 1.0}
	var r := get_ref(world, String(ref[0]), int(ref[1]))
	if r.is_empty():
		return {"cards": 1.0, "pens": 1.0, "fouls": 1.0}
	return {"cards": float(r["st"]), "pens": float(r["pn"]), "fouls": float(r["adv"])}


## Depois do jogo: soma cartões e pênaltis na conta do árbitro.
static func record(world: GameWorld, res: Dictionary) -> void:
	var ref: Array = res.get("ref", [])
	if ref.size() < 2:
		return
	var r := get_ref(world, String(ref[0]), int(ref[1]))
	if r.is_empty():
		return
	var yc: Array = res.get("yc", [0, 0])
	var rc: Array = res.get("rc", [0, 0])
	r["g"] = int(r["g"]) + 1
	r["y"] = int(r["y"]) + int(yc[0]) + int(yc[1])
	r["r"] = int(r["r"]) + int(rc[0]) + int(rc[1])
	for g in res.get("goals", []):
		if int(g[3]) == 1: # gol de pênalti
			r["p"] = int(r["p"]) + 1


## Virada de temporada: zera os números e envelhece o quadro (quem passa dos 47 se aposenta).
static func season_close(world: GameWorld) -> void:
	var d := data(world)
	for nation in d:
		for r: Dictionary in d[nation]:
			r["g"] = 0
			r["y"] = 0
			r["r"] = 0
			r["p"] = 0
			r["age"] = int(r["age"]) + 1
			if int(r["age"]) > 47:
				r["age"] = 32
				r["lv"] = 3


## Rótulo do estilo para a UI.
static func style_label(r: Dictionary) -> String:
	var st := float(r.get("st", 1.0))
	var pn := float(r.get("pn", 1.0))
	var parts: Array = []
	if st >= 1.15:
		parts.append("rigoroso")
	elif st <= 0.87:
		parts.append("deixa jogar")
	else:
		parts.append("equilibrado")
	if pn >= 1.2:
		parts.append("marca pênaltis com facilidade")
	elif pn <= 0.8:
		parts.append("difícil de dar pênalti")
	return ", ".join(parts)


static func level_label(r: Dictionary) -> String:
	return ["", "Elite", "Nacional", "Em formação"][clampi(int(r.get("lv", 2)), 1, 3)]


## Linha de apresentação: "Nome (BRA) · rigoroso · 4,8 cartões/jogo".
static func summary(world: GameWorld, ref: Array) -> String:
	if ref.size() < 2:
		return ""
	var r := get_ref(world, String(ref[0]), int(ref[1]))
	if r.is_empty():
		return ""
	var s := "%s · %s" % [String(r["n"]), style_label(r)]
	if int(r["g"]) >= 3:
		s += " · %s cartões/jogo" % TacticalXRay.dec(float(int(r["y"]) + int(r["r"])) / int(r["g"]), 1)
	return s
