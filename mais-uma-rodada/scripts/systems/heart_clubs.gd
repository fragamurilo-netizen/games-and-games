class_name HeartClubs
extends RefCounted
## Time de coração dos jogadores: escondido por padrão.
##
## Uns 60% dos jogadores torcem para alguém, quase sempre um clube da cidade onde nasceram ou um
## grande do próprio país (quem tem mais torcida tem mais torcedores entre os jogadores também).
## O usuário só fica sabendo quando o jogador revela: numa entrevista, numa conversa, ao assinar
## com o clube do coração ou porque é um garoto da base que cresceu na arquibancada.
##
## Efeitos (discretos, como na vida real): topa ir para o clube do coração com mais facilidade
## e pedindo um pouco menos, reluta em sair dele e torce o nariz para o rival do coração.
##
## Player.heart: -2 ainda não sorteado, -1 não torce para ninguém, >= 0 id do clube.
## Player.heart_known: o usuário já sabe (com heart == -1: sabe que ele não torce para ninguém).

const HAS_CHANCE := 0.6
const HOMETOWN_CHANCE := 0.7


static func _rng(world: GameWorld, p: Player) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.world_seed, p.id, "heart"])
	return r


## Sorteia o time de coração de quem ainda não tem (mundo novo, garotos novos e saves antigos).
## Usa um gerador próprio: não mexe na sequência de sorteios do mundo.
static func ensure_all(world: GameWorld) -> void:
	var by_city := {}
	var by_nation := {}
	for c: Club in world.clubs:
		var ck := "%s|%s" % [c.nation, c.city]
		if not by_city.has(ck):
			by_city[ck] = []
		by_city[ck].append(c)
		if not by_nation.has(c.nation):
			by_nation[c.nation] = []
		by_nation[c.nation].append(c)
	for p: Player in world.players.values():
		if p.heart == -2:
			_assign(world, p, by_city, by_nation)
	for p: Player in world.academy.values():
		if p.heart == -2:
			_assign(world, p, by_city, by_nation)


## Sorteio de um jogador só (garotos novos), sem montar os índices do mundo todo.
static func assign_one(world: GameWorld, p: Player) -> void:
	var by_city := {}
	var by_nation := {}
	var ck := "%s|%s" % [p.nationality, p.hometown]
	for c: Club in world.clubs:
		if c.nation != p.nationality:
			continue
		if not by_nation.has(c.nation):
			by_nation[c.nation] = []
		by_nation[c.nation].append(c)
		if "%s|%s" % [c.nation, c.city] == ck:
			if not by_city.has(ck):
				by_city[ck] = []
			by_city[ck].append(c)
	_assign(world, p, by_city, by_nation)


static func _assign(world: GameWorld, p: Player, by_city: Dictionary, by_nation: Dictionary) -> void:
	var r := _rng(world, p)
	p.heart = -1
	if r.randf() >= HAS_CHANCE:
		return
	var local: Array = by_city.get("%s|%s" % [p.nationality, p.hometown], []) if p.hometown != "" else []
	var pool: Array = local if not local.is_empty() and r.randf() < HOMETOWN_CHANCE else by_nation.get(p.nationality, [])
	if pool.is_empty():
		return
	var w: Array = []
	for c: Club in pool:
		w.append(pow(maxf(1.0, float(c.fan_base)), 1.15) * (1.0 if c.tier <= 2 else 0.4))
	p.heart = pool[RngUtil.weighted_index(r, w)].id


## Garoto novo da base: quem é da cidade do clube costuma torcer para ele, e muitos fazem
## questão de contar (sócio-torcedor desde pequeno).
static func assign_academy_kid(world: GameWorld, p: Player, club: Club) -> void:
	var r := _rng(world, p)
	if p.hometown == club.city and p.nationality == club.nation and r.randf() < 0.65:
		p.heart = club.id
		p.heart_known = r.randf() < 0.5
	else:
		assign_one(world, p)


static func club_of(world: GameWorld, p: Player) -> Club:
	return world.club(p.heart) if p.heart >= 0 else null


static func is_fan(p: Player, club_id: int) -> bool:
	return club_id >= 0 and p.heart == club_id


## Texto para o perfil ("" = ainda não se sabe).
static func known_text(world: GameWorld, p: Player) -> String:
	if not p.heart_known:
		return ""
	var c := club_of(world, p)
	return c.name if c != null else "Não torce para nenhum clube"


## Revela o time de coração. Com notícia quando interessa ao usuário.
static func reveal(world: GameWorld, p: Player, how: String, news: bool = true) -> void:
	if p.heart_known or p.heart == -2:
		return
	p.heart_known = true
	var c := club_of(world, p)
	if c == null or not news:
		return
	var at_user := p.club_id >= 0 and world.is_user_club(p.club_id) or world.academy.has(p.id)
	var hint := at_user or c.id == world.user_club_id or p.overall >= 78
	if not hint:
		return
	var body := ""
	match how:
		"entrevista":
			body = "Em entrevista, %s contou que torce para o %s desde criança: \"Meu pai me levava ao estádio. Não tem como esconder.\"" % [p.display_name(), c.short_name]
		"assinatura":
			body = "%s realizou o sonho de criança: torcedor declarado do %s, agora veste a camisa do clube do coração." % [p.display_name(), c.short_name]
		"base":
			body = "Cria da arquibancada, %s é torcedor fanático do %s e diz que o sonho é ser ídolo do clube." % [p.display_name(), c.short_name]
		_:
			body = "%s revelou que é torcedor do %s." % [p.display_name(), c.short_name]
	NewsManager.post_raw(world, "%s: o coração é do %s" % [p.display_name(), c.short_name], body,
		world.user_club_id if at_user else c.id, p.id, NewsEvent.IMP_NORMAL, "jogador")


## Chance semanal de alguém soltar para quem torce (elenco e base do usuário, craques do mundo).
static func weekly(world: GameWorld) -> void:
	if not world.has_user():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, world.season.day if world.season != null else 0, "heart_w"])
	for p: Player in world.squad(world.user_club()):
		if not p.heart_known and p.heart >= 0 and rng.randf() < 0.006:
			reveal(world, p, "entrevista")
	for p: Player in world.academy.values():
		if not p.heart_known and p.heart >= 0 and rng.randf() < 0.004:
			reveal(world, p, "base")


## Ajuste na vontade de ir para `buyer` (somado em TransferManager.interest).
static func interest_delta(world: GameWorld, p: Player, buyer: Club) -> float:
	if p.heart < 0:
		return 0.0
	var d := 0.0
	if buyer.id == p.heart:
		d += 0.22
	if p.club_id == p.heart and buyer.id != p.heart:
		d -= 0.18
	var heart := world.club(p.heart)
	if heart != null and heart.id != buyer.id and (heart.is_rival(buyer.id) or buyer.is_rival(heart.id)):
		d -= 0.1
	return d


## Desconto salarial para jogar no clube do coração.
static func wage_mult(p: Player, buyer: Club) -> float:
	return 0.9 if p.heart >= 0 and buyer.id == p.heart else 1.0


## Conversa com o treinador: "Pra quem você torce?". Retorna a fala do jogador.
static func ask(world: GameWorld, p: Player) -> String:
	var c := club_of(world, p)
	var cur := world.club(p.club_id) if p.club_id >= 0 else null
	if c == null:
		p.heart_known = true
		return "Sinceramente? Não torço para ninguém. Virei profissional cedo e o futebol virou trabalho."
	if cur != null and c.id != cur.id and (c.is_rival(cur.id) or cur.is_rival(c.id)):
		return "Professor, prefiro não falar disso aqui dentro... Vamos deixar quieto."
	p.heart_known = true
	if cur != null and c.id == cur.id:
		return "Tá brincando? Eu sou %s desde que nasci! Jogar aqui é o sonho da minha família." % c.short_name
	return "Desde moleque eu torço para o %s. Mas aqui eu dou tudo pela camisa, pode ter certeza." % c.short_name
