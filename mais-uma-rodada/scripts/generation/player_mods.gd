class_name PlayerMods
extends RefCounted
## Jogadores personalizados que entram na geração do mundo: as edições feitas no Editor geral
## (padrão das novas carreiras, guardadas em Overrides) e os jogadores de mods (players.json).
##
## Cada entrada é um dicionário:
##   club    chave do clube ("BRA_FLA"...); vazio = sem clube
##   match   nome original do jogador gerado ("Nome Sobrenome") para editar; sem match = jogador novo
##   uid     identificador de um jogador novo criado no editor (para editar de novo depois)
##   remove  true tira o jogador do mundo (para trocar um fictício por um real)
##   first, last, known, nick, nat, pos ("ATA" ou "ST"), sec (["PD", "MEI"]), birth ou age,
##   height, weight, foot ("R", "L", "B"), shirt, ovr (overall alvo), pot, attrs ({"FIN": 88, ...}),
##   traits (["lider"]), look ({hs, hc, bd, sk, ey, photo})
## Usa um RNG próprio: o sorteio do mundo continua igual com ou sem personalizações.

const FOOT_CODES := {"R": Player.FOOT_RIGHT, "L": Player.FOOT_LEFT, "B": Player.FOOT_BOTH, "D": Player.FOOT_RIGHT, "E": Player.FOOT_LEFT, "A": Player.FOOT_BOTH}


## Entradas salvas pelo Editor geral.
static func stored() -> Array:
	return Array(Overrides.data().get("players", []))


## Salva (ou substitui) a entrada de um jogador como padrão das novas carreiras.
static func store(entry: Dictionary) -> void:
	var list := stored()
	var k := entry_key(entry)
	list = list.filter(func(e): return entry_key(e) != k)
	list.append(entry)
	Overrides.data()["players"] = list
	Overrides.save()


static func unstore(key: String) -> void:
	Overrides.data()["players"] = stored().filter(func(e): return entry_key(e) != key)
	Overrides.save()


static func entry_key(e: Dictionary) -> String:
	if e.has("uid"):
		return "uid:" + String(e["uid"])
	return "%s/%s" % [String(e.get("club", "")), String(e.get("match", ""))]


## Chave da personalização de um jogador do mundo (se ele veio de uma), ou "".
static func key_of(world: GameWorld, p: Player) -> String:
	return String(world.stats.get("pmods", {}).get(str(p.id), ""))


static func apply(world: GameWorld) -> void:
	var entries: Array = Mods.players() + stored()
	if entries.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed * 17 + 3)
	var used := WorldGenerator.used_names_of(world)
	var touched := {}
	var marks := {}
	for e in entries:
		if not (e is Dictionary):
			continue
		var cid := _apply_one(world, rng, e, used, marks)
		if cid >= 0:
			touched[cid] = true
	for cid in touched:
		var c := world.club(int(cid))
		PlayerGenerator.assign_statuses(world, c)
		PlayerGenerator.assign_shirt_numbers(world, c)
	world.stats["pmods"] = marks


## Aplica uma entrada; devolve o id do clube mexido (ou -1).
static func _apply_one(world: GameWorld, rng: RandomNumberGenerator, e: Dictionary, used: Dictionary, marks: Dictionary) -> int:
	var club: Club = world.club_by_key(String(e.get("club", ""))) if String(e.get("club", "")) != "" else null
	if String(e.get("club", "")) != "" and club == null:
		return -1 # clube que não existe neste mundo
	var p: Player = null
	var match := String(e.get("match", ""))
	if match != "":
		p = find(world, club, match)
		if p == null:
			return -1
		if bool(e.get("remove", false)):
			_remove(world, p)
			return club.id if club != null else -1
	else:
		var pos := pos_from(e.get("pos", "MC"))
		var age := int(e.get("age", world.year - int(e.get("birth", world.year - 25))))
		var nat := String(e.get("nat", club.nation if club != null else "BRA"))
		if not DatabaseManager.has_nation(nat):
			nat = club.nation if club != null else "BRA"
		p = PlayerGenerator.create(world, rng, pos, float(e.get("ovr", 70)), clampi(age, 15, 45), nat, club.city if club != null else "", used)
		if club != null:
			PlayerGenerator.sign_to_club(world, rng, p, club, true)
		else:
			p.club_id = -1
			p.contract_end = world.year
			world.add_player(p)
	fill(world, p, e)
	marks[str(p.id)] = entry_key(e)
	return club.id if club != null else -1


## Jogador de um clube (ou sem clube) pelo nome completo ou pelo nome de exibição.
static func find(world: GameWorld, club: Club, name: String) -> Player:
	var q := name.strip_edges().to_lower()
	var ids: Array = club.player_ids if club != null else world.players.keys()
	for pid in ids:
		var p := world.player(int(pid))
		if p == null or (club == null and p.club_id >= 0):
			continue
		if (p.first_name + " " + p.last_name).to_lower() == q or p.display_name().to_lower() == q:
			return p
	return null


static func _remove(world: GameWorld, p: Player) -> void:
	var c := world.club(p.club_id)
	if c != null:
		c.player_ids.erase(p.id)
	world.players.erase(p.id)
	world._free_agents_dirty = true


## Posição por código em português ("ATA") ou inglês ("ST"), ou índice.
static func pos_from(v: Variant) -> int:
	if v is int or v is float:
		return clampi(int(v), 0, Pos.COUNT - 1)
	var code := String(v).to_upper()
	var i := Pos.CODES.find(code)
	if i >= 0:
		return i
	return int(DatabaseManager.POS_BY_CODE.get(code, Pos.CM))


## Copia os campos da entrada para o jogador (só os que existem nela).
static func fill(world: GameWorld, p: Player, e: Dictionary) -> void:
	if e.has("first"):
		p.first_name = String(e["first"])
	if e.has("last"):
		p.last_name = String(e["last"])
	if e.has("known"):
		p.known_as = String(e["known"])
	if e.has("nick"):
		p.nickname = String(e["nick"])
	if e.has("nat") and DatabaseManager.has_nation(String(e["nat"])):
		p.nationality = String(e["nat"])
	if e.has("pos"):
		p.position = pos_from(e["pos"])
	if e.has("sec"):
		p.secondary = []
		for s in e["sec"]:
			var sp := pos_from(s)
			if sp != p.position and not p.secondary.has(sp):
				p.secondary.append(sp)
	if e.has("birth"):
		p.birth_year = int(e["birth"])
	elif e.has("age"):
		p.birth_year = world.year - int(e["age"])
	if e.has("height"):
		p.height = clampi(int(e["height"]), 150, 210)
	if e.has("weight"):
		p.weight = clampi(int(e["weight"]), 50, 110)
	if e.has("foot"):
		p.foot = int(FOOT_CODES.get(String(e["foot"]).to_upper(), p.foot)) if e["foot"] is String else clampi(int(e["foot"]), 0, 2)
	if e.has("shirt"):
		p.shirt = clampi(int(e["shirt"]), 1, 99)
	if e.has("traits"):
		p.set_traits(Array(e["traits"]).filter(func(t): return DatabaseManager.trait_ids().has(String(t))).slice(0, 2))
	if e.has("look") and e["look"] is Dictionary:
		p.look = e["look"].duplicate(true)
	if e.has("face"):
		p.face_seed = int(e["face"])
	if e.has("attrs"):
		var a: Variant = e["attrs"]
		if a is Array:
			for i in mini(a.size(), Attr.COUNT):
				p.set_attr(i, int(a[i]))
		elif a is Dictionary:
			for k in a:
				var i := Attr.SHORT.find(String(k).to_upper())
				if i >= 0:
					p.set_attr(i, int(a[k]))
		p.recompute_overall()
	elif e.has("ovr"):
		scale_to(p, int(e["ovr"]))
	p.recompute_overall()
	if e.has("pot"):
		p.potential = clampi(int(e["pot"]), p.overall, 99)
	p.potential = maxi(p.potential, p.overall)
	Valuation.update_value(p, world.year)


## Sobe ou desce todos os atributos até o overall chegar ao alvo (mantém o perfil do jogador).
static func scale_to(p: Player, target: int) -> void:
	target = clampi(target, 30, 99)
	for _i in 60:
		p.recompute_overall()
		var diff := target - p.overall
		if diff == 0:
			return
		var step := signi(diff) * maxi(1, absi(diff) / 2)
		for i in Attr.COUNT:
			if i == Attr.GOL and p.position != Pos.GK:
				continue
			p.set_attr(i, clampi(p.attrs[i] + step, 1, 99))


## Entrada completa com o estado atual do jogador (para salvar como padrão).
static func snapshot(world: GameWorld, p: Player, club: Club, match: String, uid: String) -> Dictionary:
	var attrs := {}
	for i in Attr.COUNT:
		attrs[Attr.SHORT[i]] = p.attrs[i]
	var sec: Array = []
	for s in p.secondary:
		sec.append(Pos.CODES[int(s)])
	var e := {"club": club.key if club != null else "", "first": p.first_name, "last": p.last_name, "known": p.known_as,
		"nat": p.nationality, "pos": Pos.CODES[p.position], "sec": sec, "birth": p.birth_year, "height": p.height,
		"weight": p.weight, "foot": ["R", "L", "B"][p.foot], "shirt": p.shirt, "attrs": attrs, "pot": p.potential,
		"traits": p.traits.duplicate(), "look": p.look.duplicate(true), "face": p.face_seed}
	if uid != "":
		e["uid"] = uid
	else:
		e["match"] = match
	return e
