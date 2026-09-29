class_name BoardRequests
extends RefCounted
## Estrutura, base e estádio são do clube: o treinador não gasta o dinheiro, ele pede ao presidente.
## O pedido passa pelo diretor de futebol (nome, negociação, rede de olheiros e relação com a
## diretoria, em world.stats["dof"]). A resposta depende da confiança da diretoria, do caixa contra
## o custo, da dívida e de quem leva o pedido; há intervalo entre pedidos do mesmo tipo.
## Resultado: aprovado inteiro, aprovado em parte (1 ponto, um terço do custo) ou negado com motivo.

const COOLDOWN := 8 # rodadas entre pedidos do mesmo tipo
const POINTS := 3


## Diretor de futebol do clube do usuário (criado na primeira vez).
static func director(world: GameWorld) -> Dictionary:
	var d: Dictionary = world.stats.get("dof", {})
	if not d.is_empty() and int(d.get("club", -1)) == world.user_club_id:
		return d
	var club := world.user_club()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.user_club_id, "dof"])
	var o := NameGenerator.pick_origin(rng, club.nation)
	var n := NameGenerator.generate(rng, String(o["c"]), {}, {})
	d = {"club": club.id, "name": "%s %s" % [n["first"], n["last"]], "age": rng.randi_range(38, 64),
		"neg": rng.randi_range(40, 85), "net": rng.randi_range(35, 85), "rel": rng.randi_range(40, 80), "since": world.year - rng.randi_range(0, 5)}
	world.stats["dof"] = d
	return d


static func chairman_name(world: GameWorld) -> String:
	var club := world.user_club()
	if club.affairs.has("pres_note"):
		return String(club.affairs["pres"]) # presidente real do clube (ex.: a dona da patrocinadora)
	return String(People.president(world, club.id).get("n", "o presidente"))


static func cost_of(world: GameWorld, kind: String, points: int = POINTS) -> int:
	var club := world.user_club()
	if kind == "stadium":
		return WorldEvents.stadium_cost(club, _stadium_seats(club))
	var level := club.facilities if kind == "facilities" else club.youth_level
	var total := 0
	for i in points:
		total += FinanceManager.upgrade_cost(club, level + i)
	return total


static func _stadium_seats(club: Club) -> int:
	return maxi(1000, int(club.capacity * 0.15 / 500.0) * 500)


## Rodadas até poder pedir de novo (0 = pode).
static func wait_turns(world: GameWorld, kind: String) -> int:
	var cd: Dictionary = world.stats.get("req_cd", {})
	return maxi(0, int(cd.get(kind, -99)) + COOLDOWN - world.current_turn())


## Chance de o presidente aprovar (0..1) e o principal motivo contra.
static func odds(world: GameWorld, kind: String) -> Array:
	var club := world.user_club()
	var d := director(world)
	var cost := cost_of(world, kind)
	var p := 0.3 + (club.board_confidence - 50.0) / 90.0 + (float(d["rel"]) - 50.0) / 220.0
	var why := ""
	if club.balance >= cost * 3:
		p += 0.3
	elif club.balance >= cost:
		p += 0.05
		why = "o caixa fica apertado"
	else:
		p -= 0.45
		why = "não há dinheiro em caixa"
	var rev := float(FinanceManager.expected_revenue(club))
	if FinanceManager.debt_ratio(club, rev) > 1.0:
		p -= 0.2
		why = "a dívida passa de um ano de receita"
	if club.board_confidence < 40.0 and why == "":
		why = "a diretoria anda desconfiada do trabalho"
	if kind == "stadium" and club.fan_base < club.capacity:
		p -= 0.35
		why = "o estádio nem lota hoje"
	return [clampf(p, 0.03, 0.95), why]


## Faz o pedido. Retorna {ok (bool), partial (bool), msg}.
static func request(world: GameWorld, kind: String) -> Dictionary:
	var club := world.user_club()
	var cd: Dictionary = world.stats.get("req_cd", {})
	cd[kind] = world.current_turn()
	world.stats["req_cd"] = cd
	var od := odds(world, kind)
	var chance: float = od[0]
	var why: String = od[1]
	var pres := chairman_name(world)
	var what: String = {"facilities": "a melhoria do CT", "youth": "o investimento na base", "stadium": "a ampliação do estádio"}[kind]
	var roll := world.rng.randf()
	if roll < chance:
		if kind == "stadium":
			var seats := _stadium_seats(club)
			club.add_ledger("investimentos", -cost_of(world, kind))
			world.stats["stadium_work"] = seats
			return {"ok": true, "partial": false, "msg": "%s aprovou %s: +%d lugares para a próxima temporada." % [pres, what, seats]}
		var paid := FinanceManager.invest(club, kind, POINTS)
		if paid > 0:
			return {"ok": true, "partial": false, "msg": "%s aprovou %s (+%d, %s)." % [pres, what, POINTS, Fmt.money(paid)]}
		why = "não há dinheiro em caixa"
	elif roll < chance + 0.2 and kind != "stadium":
		var paid2 := FinanceManager.invest(club, kind, 1)
		if paid2 > 0:
			return {"ok": true, "partial": true, "msg": "%s liberou só uma parte para %s (+1, %s)%s." % [pres, what, Fmt.money(paid2), (": " + why) if why != "" else ""]}
	club.board_confidence = clampf(club.board_confidence - 1.0, 0.0, 100.0)
	return {"ok": false, "partial": false, "msg": "%s negou %s%s. Dá para pedir de novo daqui a %d rodadas." % [pres, what, (" — " + why) if why != "" else "", COOLDOWN]}


## Sugestões do diretor: onde o elenco é mais fraco e 5 nomes que cabem no orçamento.
static func suggestions(world: GameWorld) -> Dictionary:
	var club := world.user_club()
	var d := director(world)
	var squad: Array = world.squad(club)
	var groups := [[], [], [], []]
	for p: Player in squad:
		groups[Pos.group(p.position)].append(PlayerAssessment.score(world,p))
	var worst := 1
	var worst_v := 999.0
	var need := [2, 4, 4, 3]
	for g in 4:
		var arr: Array = groups[g]
		arr.sort()
		arr.reverse()
		var top := arr.slice(0, need[g])
		var v := 0.0
		for x in top:
			v += float(x)
		v = v / maxf(1.0, float(need[g])) - (5.0 if top.size() < need[g] else 0.0)
		if v < worst_v:
			worst_v = v
			worst = g
	var budget := float(club.transfer_budget) * 1.15
	# A rede de olheiros define quantos o diretor conhece (e o quanto erra)
	var reach := 0.25 + float(d["net"]) / 130.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.current_turn(), "sug"])
	var cands: Array = []
	for p: Player in world.players.values():
		if p.club_id == club.id or Pos.group(p.position) != worst or p.age(world.year) > 31:
			continue
		if PlayerAssessment.score(world,p) < worst_v + 2.0 or float(p.value) > budget:
			continue
		if rng.randf() > reach:
			continue
		cands.append([p, PlayerAssessment.score(world,p) + maxf(0.0,26-p.age(world.year))*0.5 - float(p.value) / maxf(1.0, budget) * 4.0])
	cands.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var ids: Array = []
	for c in cands.slice(0, 5):
		ids.append((c[0] as Player).id)
	return {"group": worst, "level": worst_v, "ids": ids}
