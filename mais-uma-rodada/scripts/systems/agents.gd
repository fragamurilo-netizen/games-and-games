class_name Agents
extends RefCounted
## Empresários: gente de verdade no meio das negociações. Cada país com futebol tem os seus
## (de poucos a uma dúzia, conforme o tamanho), e há os superagentes, com carteira no mundo inteiro
## e os craques. Cada um tem reputação, estilo (parceiro, agressivo, discreto) e relação com os
## clubes: com quem ele se dá bem, o negócio anda; com quem brigou, trava.
##
## O jogador ganha empresário na primeira vez que alguém pergunta (sorteio fixo pelo id: o mesmo
## jogador tem sempre o mesmo empresário até trocar), então saves antigos funcionam sem migração.
##
## world.stats["ag"] = {"next": n, "list": {id: {id, n, nat, rep, st, intl (superagente), cl {clube: rel}}},
##                      "of": {pid: id do empresário (0 = sem empresário)}}

const STYLES := {
	"parceiro": {"name": "Parceiro", "pct": 0.0, "push": 0.6, "hint": "Fecha negócio bom para os dois lados e preza a relação com os clubes."},
	"agressivo": {"name": "Agressivo", "pct": 0.012, "push": 1.6, "hint": "Leva o cliente a quem paga mais, cobra caro e pressiona por renovação."},
	"discreto": {"name": "Discreto", "pct": -0.008, "push": 0.8, "hint": "Trabalha em silêncio, comissão menor, poucos clientes de peso."},
}
const SUPER := 18 # superagentes no mundo
const SUPER_NATS: Array[String] = ["POR", "ESP", "ITA", "ENG", "BRA", "ARG", "FRA", "GER", "NED", "SRB", "NGA", "URU"]


static func data(world: GameWorld) -> Dictionary:
	if not world.stats.has("ag"):
		world.stats["ag"] = {"next": 1, "list": {}, "of": {}}
		_seed(world)
	return world.stats["ag"]


static func get_agent(world: GameWorld, id: int) -> Dictionary:
	if id <= 0:
		return {}
	return Dictionary(data(world)["list"]).get(str(id), {})


static func _seed(world: GameWorld) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.world_seed, "empresarios"])
	var by_nat := {}
	for c: Club in world.clubs:
		if c != null and c.nation != "":
			by_nat[c.nation] = int(by_nat.get(c.nation, 0)) + 1
	for n in by_nat:
		var k := clampi(int(by_nat[n]) / 3, 2, 12)
		for _i in k:
			_new(world, r, String(n), false)
	for i in SUPER:
		_new(world, r, SUPER_NATS[i % SUPER_NATS.size()], true)


static func _new(world: GameWorld, r: RandomNumberGenerator, nat: String, intl: bool) -> Dictionary:
	var d: Dictionary = world.stats["ag"]
	var id := int(d["next"])
	d["next"] = id + 1
	var st := String(RngUtil.weighted_key(r, {"parceiro": 1.0, "agressivo": 0.8 if not intl else 1.2, "discreto": 0.7}))
	var rep := clampf(RngUtil.gauss(r, 82.0 if intl else 45.0, 8.0 if intl else 14.0), 10.0, 99.0)
	var a := {"id": id, "n": People._person_name(r, nat), "nat": nat, "rep": snappedf(rep, 0.1), "st": st, "intl": intl, "cl": {}}
	d["list"][str(id)] = a
	return a


## Empresário do jogador (0 = sem empresário). Sorteio fixo pelo id, guardado na primeira vez.
static func agent_id(world: GameWorld, p: Player) -> int:
	var d := data(world)
	var of: Dictionary = d["of"]
	var key := str(p.id)
	if of.has(key):
		return int(of[key])
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.world_seed, p.id, "agente"])
	var id := 0
	var top := p.overall >= 80 or p.potential >= 86
	if p.overall < 45 and p.potential < 60 and r.randf() < 0.5:
		id = 0 # garoto ou jogador de divisão de baixo, sem ninguém
	else:
		var pool := {}
		for aid in d["list"]:
			var a: Dictionary = d["list"][aid]
			var wgt := 0.0
			if bool(a["intl"]):
				wgt = (6.0 if top else (0.4 if p.overall >= 70 else 0.0))
			elif String(a["nat"]) == p.nationality:
				wgt = 1.0 + float(a["rep"]) / 40.0 * (1.5 if p.overall >= 70 else 0.6)
			if wgt > 0.0:
				pool[aid] = wgt
		if not pool.is_empty():
			id = int(RngUtil.weighted_key(r, pool))
	of[key] = id
	return id


static func agent_of(world: GameWorld, p: Player) -> Dictionary:
	return get_agent(world, agent_id(world, p))


## Comissão a mais ou a menos pelo empresário (somada ao DealTerms.agent_pct).
static func pct_bonus(world: GameWorld, p: Player) -> float:
	var a := agent_of(world, p)
	if a.is_empty():
		return -0.01
	var b := float(STYLES.get(String(a["st"]), STYLES["parceiro"])["pct"])
	if bool(a["intl"]):
		b += 0.015
	return b


## Relação do empresário com um clube (-100 a 100).
static func relation(world: GameWorld, agent: Dictionary, club_id: int) -> float:
	if agent.is_empty():
		return 0.0
	return float(Dictionary(agent["cl"]).get(str(club_id), 0.0))


static func add_relation(world: GameWorld, agent: Dictionary, club_id: int, v: float) -> void:
	if agent.is_empty():
		return
	var cl: Dictionary = agent["cl"]
	cl[str(club_id)] = clampf(float(cl.get(str(club_id), 0.0)) + v, -100.0, 100.0)


## Chance de o empresário travar uma negociação com o clube (relação ruim).
static func block_chance(world: GameWorld, p: Player, club_id: int) -> float:
	var a := agent_of(world, p)
	var rel := relation(world, a, club_id)
	if rel >= -20.0:
		return 0.0
	return clampf((-rel - 20.0) / 120.0, 0.0, 0.6)


## Clientes de um empresário (melhores primeiro).
static func clients(world: GameWorld, aid: int, limit: int = 0) -> Array:
	var a := get_agent(world, aid)
	if a.is_empty():
		return []
	var out: Array = []
	for p: Player in world.players.values():
		if not bool(a["intl"]) and p.nationality != String(a["nat"]):
			continue
		if bool(a["intl"]) and p.overall < 70 and p.potential < 82:
			continue
		if agent_id(world, p) == aid:
			out.append(p)
	out.sort_custom(func(x: Player, y: Player): return x.ovr_f > y.ovr_f if x.ovr_f != y.ovr_f else x.id < y.id)
	return out.slice(0, limit) if limit > 0 else out


## Depois de um negócio fechado com o clube: relação melhora (e piora quando a comissão foi cortada).
static func on_deal(world: GameWorld, p: Player, club_id: int, cut: float) -> void:
	var a := agent_of(world, p)
	if a.is_empty():
		return
	add_relation(world, a, club_id, 8.0 if cut >= 1.0 else (-6.0 if cut >= 0.75 else -18.0))
