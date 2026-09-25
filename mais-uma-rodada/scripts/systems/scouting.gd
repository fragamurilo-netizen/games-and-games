class_name Scouting
extends RefCounted
## Olheiros no mercado: o treinador manda o olheiro-chefe observar um perfil (origem, setor,
## idade) e recebe relatórios com avaliação bem mais precisa desses jogadores.
## Estado em world.stats["scouting"]: {"ids": {pid(str): turno}, "last": turno, "yr": ano}.

const ORIGINS := [["all", "Todos"], ["nat", "Nacionais"], ["for", "Estrangeiros"]]
const MAX_REPORTS := 40


static func state(world: GameWorld) -> Dictionary:
	if not world.stats.has("scouting"):
		world.stats["scouting"] = {"ids": {}, "last": -1, "yr": world.year}
	var s: Dictionary = world.stats["scouting"]
	# Turno reinicia na virada da temporada.
	if int(s.get("yr", world.year)) != world.year:
		s["yr"] = world.year
		s["last"] = -1
	return s


## "Nacional" é relativo ao país do clube do usuário.
static func origin_ok(p: Player, club: Club, origin: String) -> bool:
	match origin:
		"nat":
			return p.nationality == club.nation
		"for":
			return p.nationality != club.nation
	return true


static func is_scouted(world: GameWorld, p: Player) -> bool:
	return world.stats.has("scouting") and world.stats["scouting"]["ids"].has(str(p.id))


## Quantos jogadores o olheiro consegue acompanhar por missão (3 a ~9).
static func capacity(world: GameWorld) -> int:
	return 3 + int(round(People.staff_level(world, "olheiro") * 5.0))


static func can_send(world: GameWorld) -> bool:
	return int(state(world)["last"]) != world.current_turn()


## Envia o olheiro: escolhe os melhores nomes do perfil que o clube poderia pagar e deixa
## a avaliação deles quase exata. Devolve os jogadores observados.
static func send_mission(world: GameWorld, origin: String, group: int, max_age: int) -> Array:
	var s := state(world)
	var club := world.user_club()
	var ids: Dictionary = s["ids"]
	var reach := maxi(club.transfer_budget * 3 / 2, 1)
	var cands: Array = []
	for p: Player in world.players.values():
		if p.club_id == club.id or p.retiring or ids.has(str(p.id)):
			continue
		if group >= 0 and Pos.group(p.position) != group:
			continue
		if p.age(world.year) > max_age or not origin_ok(p, club, origin):
			continue
		if p.club_id >= 0 and TransferManager.asking_price(world, p) > reach:
			continue
		# Nível estimado + margem de crescimento para os jovens.
		var score := float(PlayerRowView.estimate(world, p, p.overall))
		if p.age(world.year) <= 23:
			score += maxf(0.0, p.potential_estimate(0.3) - p.overall) * 0.4
		elif p.age(world.year) > 30:
			score -= (p.age(world.year) - 30) * 1.5
		cands.append([p, score])
	cands.sort_custom(func(a, b): return a[1] > b[1])
	var out: Array = []
	for c in cands.slice(0, capacity(world)):
		var p: Player = c[0]
		p.scout_noise = int(p.scout_noise * 0.25)
		ids[str(p.id)] = world.current_turn()
		out.append(p)
	s["last"] = world.current_turn()
	_trim(world)
	return out


## Relatórios válidos (remove quem sumiu, aposentou ou já está no seu elenco).
static func reports(world: GameWorld) -> Array:
	_trim(world)
	var out: Array = []
	for k in state(world)["ids"]:
		var p := world.player(int(k))
		if p != null:
			out.append(p)
	return out


static func forget(world: GameWorld, p: Player) -> void:
	state(world)["ids"].erase(str(p.id))


static func _trim(world: GameWorld) -> void:
	var ids: Dictionary = state(world)["ids"]
	var club := world.user_club()
	for k in ids.keys():
		var p := world.player(int(k))
		if p == null or p.club_id == club.id:
			ids.erase(k)
	if ids.size() > MAX_REPORTS:
		var ks: Array = ids.keys()
		ks.sort_custom(func(a, b): return int(ids[a]) < int(ids[b]))
		for k in ks.slice(0, ids.size() - MAX_REPORTS):
			ids.erase(k)
