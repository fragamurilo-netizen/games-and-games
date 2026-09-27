class_name Shortlist
extends RefCounted
## Lista de observação do mercado: jogadores que o treinador quer acompanhar.
## Guarda como estavam quando entraram (clube, preço, se estavam à venda) para mostrar
## o que mudou desde então.
## Estado em world.stats["shortlist"]: {pid(str): {"t": turno, "yr": ano, "c": clube, "ask": preço, "ls": à venda}}.

const MAX_ENTRIES := 30


static func state(world: GameWorld) -> Dictionary:
	if not world.stats.has("shortlist"):
		world.stats["shortlist"] = {}
	return world.stats["shortlist"]


static func has(world: GameWorld, p: Player) -> bool:
	return world.stats.has("shortlist") and world.stats["shortlist"].has(str(p.id))


## Adiciona ou tira da lista. Devolve true se o jogador ficou na lista.
static func toggle(world: GameWorld, p: Player) -> bool:
	var s := state(world)
	var k := str(p.id)
	if s.has(k):
		s.erase(k)
		return false
	if s.size() >= MAX_ENTRIES:
		return false
	s[k] = {"t": world.current_turn(), "yr": world.year, "c": p.club_id,
		"ask": TransferManager.asking_price(world, p), "ls": p.transfer_listed}
	return true


static func is_full(world: GameWorld) -> bool:
	return state(world).size() >= MAX_ENTRIES


## Jogadores da lista (remove quem sumiu, aposentou ou já chegou ao seu clube).
static func players(world: GameWorld) -> Array:
	var s := state(world)
	var club := world.user_club()
	var out: Array = []
	for k in s.keys():
		var p := world.player(int(k))
		if p == null or (club != null and p.club_id == club.id):
			s.erase(k)
			continue
		out.append(p)
	return out


## O que mudou desde que o jogador entrou na lista: [[texto, cor]].
static func changes(world: GameWorld, p: Player) -> Array:
	var e: Dictionary = state(world).get(str(p.id), {})
	var out: Array = []
	if e.is_empty():
		return out
	var was := int(e.get("c", -1))
	if p.club_id != was:
		if p.club_id < 0:
			out.append(["Ficou livre", UIColors.GREEN])
		else:
			out.append(["Foi para o %s" % world.club(p.club_id).short_name, UIColors.ORANGE])
	if p.transfer_listed and not bool(e.get("ls", false)):
		out.append(["Colocado à venda", UIColors.GREEN])
	if p.club_id >= 0 and p.club_id == was:
		var before := int(e.get("ask", 0))
		var now := TransferManager.asking_price(world, p)
		if before > 0 and now <= int(before * 0.9):
			out.append(["Preço caiu %d%%" % int(round((1.0 - float(now) / before) * 100.0)), UIColors.GREEN])
		elif before > 0 and now >= int(before * 1.1):
			out.append(["Preço subiu %d%%" % int(round((float(now) / before - 1.0) * 100.0)), UIColors.RED])
	if p.club_id >= 0 and p.contract_years_left(world.year) <= 0:
		out.append(["Contrato acaba em %d" % p.contract_end, UIColors.ACCENT])
	if p.injury_weeks > 0:
		out.append(["Lesionado (%d sem.)" % p.injury_weeks, UIColors.RED])
	return out


## Quantos jogadores da lista têm novidade (para o contador da aba).
static func news_count(world: GameWorld) -> int:
	var n := 0
	for p: Player in players(world):
		if not changes(world, p).is_empty():
			n += 1
	return n


## Chance de o jogador topar vir para o clube do usuário, em palavras: [texto, cor].
static func interest_label(world: GameWorld, p: Player) -> Array:
	var club := world.user_club()
	if club == null:
		return ["", UIColors.MUTED]
	var v := MarketAI.player_interest(world, p, club)
	if v >= 0.6:
		return ["Topa vir", UIColors.GREEN]
	if v >= 0.35:
		return ["Pode topar", UIColors.ACCENT]
	return ["Resiste a vir", UIColors.RED]
