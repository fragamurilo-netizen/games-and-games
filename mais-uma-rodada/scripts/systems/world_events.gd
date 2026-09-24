class_name WorldEvents
extends RefCounted
## Acontecimentos do mundo do futebol, fora do controle do usuário: clubes comprados por
## investidores (ou transformados em SAF), donos que vão embora, troca de presidente, clubes
## afundados em dívida que pedem recuperação judicial, estádios ampliados e novos contratos de TV.
##
## Donos atuais ficam em world.stats["owners"]: {"<club_id>": {y, who, arch (arquétipo anterior)}}.
## O histórico de compras fica em world.stats["takeovers"]: [{y, c, who}].

const INVESTORS := ["Grupo Atlas Capital", "Fundo Horizonte Sports", "Consórcio Al Waha", "Redwood Sports Group",
	"Nordic Football Holding", "Golden Pine Investments", "Grupo Sete Mares", "Pacific Crown Partners",
	"Fundo Soberano de Qamar", "Blue Harbor Capital", "Grupo Aurora", "Iron Bridge Sports", "Família Montenegro",
	"Sunrise Asia Holdings", "Lakeview Partners"]
## Chance semanal de o mundo sortear um candidato a cada tipo de acontecimento.
const P_TAKEOVER := 0.16
const P_EXIT := 0.03
const P_PRESIDENT := 0.25
const P_USER_PRESIDENT := 0.004
## Anos mínimos entre duas trocas de dono no mesmo clube.
const OWNER_COOLDOWN := 6


# ---------------------------------------------------------------------------
# Semana a semana
# ---------------------------------------------------------------------------

static func weekly(world: GameWorld) -> void:
	var rng := world.rng
	if rng.randf() < P_TAKEOVER:
		var c: Club = RngUtil.pick(rng, world.clubs)
		if _can_be_bought(world, c) and (c.balance < 0 or rng.randf() < 0.5):
			takeover(world, c, RngUtil.pick(rng, INVESTORS))
	if rng.randf() < P_EXIT:
		_investor_exit(world)
	if rng.randf() < P_PRESIDENT:
		var c: Club = RngUtil.pick(rng, world.clubs)
		if not world.is_user_club(c.id):
			new_president(world, c)
	if world.has_user() and rng.randf() < P_USER_PRESIDENT:
		new_president(world, world.user_club())


static func owner_of(world: GameWorld, club_id: int) -> Dictionary:
	return world.stats.get("owners", {}).get(str(club_id), {})


static func _can_be_bought(world: GameWorld, c: Club) -> bool:
	if world.is_user_club(c.id):
		return false # o clube do usuário passa por um dilema (EventManager "takeover")
	var own := owner_of(world, c.id)
	return own.is_empty() or world.year - int(own.get("y", 0)) >= OWNER_COOLDOWN


## Um investidor compra o clube: dívida quitada, dinheiro novo, estrutura e ambição.
## Retorna o aporte total.
static func takeover(world: GameWorld, c: Club, who: String) -> int:
	var rng := world.rng
	var revenue := float(FinanceManager.expected_revenue(c))
	var money := int(revenue * rng.randf_range(0.8, 2.0)) + maxi(0, -c.balance)
	c.add_ledger("aporte", money)
	var owners: Dictionary = world.stats.get("owners", {})
	var prev: Dictionary = owners.get(str(c.id), {})
	owners[str(c.id)] = {"y": world.year, "who": who, "arch": String(prev.get("arch", c.archetype))}
	world.stats["owners"] = owners
	var hist: Array = world.stats.get("takeovers", [])
	hist.append({"y": world.year, "c": c.id, "who": who})
	if hist.size() > 60:
		hist = hist.slice(hist.size() - 60)
	world.stats["takeovers"] = hist
	c.reputation = minf(99.0, c.reputation + 2.0)
	c.facilities = mini(99, c.facilities + rng.randi_range(4, 10))
	c.fan_mood = clampf(c.fan_mood + 8.0, 0.0, 100.0)
	if world.is_user_club(c.id):
		# O novo dono libera parte do dinheiro já e quer resultado rápido.
		c.transfer_budget += int(money * 0.4)
		c.board_confidence = clampf(c.board_confidence - 5.0, 0.0, 100.0)
	else:
		c.archetype = "rico_promovido"
		c.board_confidence = 55.0
		FinanceManager.set_budgets(world, c)
	world.stat_add("takeovers_total")
	var saf := c.nation == "BRA"
	var title := ("%s vira SAF" if saf else "%s tem novo dono") % c.short_name
	var body := "%s comprou o %s%s e promete %s em investimentos. A dívida foi quitada e a torcida sonha alto." % [
		who, c.name, " na transformação em SAF" if saf else "", Fmt.money(money)]
	if world.is_user_club(c.id):
		body += " O recado para o treinador: quer títulos logo."
		NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_HEADLINE, "clube")
	elif newsworthy(world, c):
		NewsManager.post_raw(world, title, body, c.id, -1, NewsEvent.IMP_HIGH, "clube")
	return money


## Donos que cansam: vão embora deixando dívida, e o clube volta ao perfil antigo.
static func _investor_exit(world: GameWorld) -> void:
	var owners: Dictionary = world.stats.get("owners", {})
	var cands: Array = []
	for k in owners:
		var o: Dictionary = owners[k]
		if world.year - int(o.get("y", 0)) >= 3 and not world.is_user_club(int(k)):
			cands.append(int(k))
	if cands.is_empty():
		return
	var c := world.club(RngUtil.pick(world.rng, cands))
	if c == null:
		return
	var o: Dictionary = owners[str(c.id)]
	owners.erase(str(c.id))
	world.stats["owners"] = owners
	var debt := int(FinanceManager.expected_revenue(c) * world.rng.randf_range(0.3, 0.7))
	c.add_ledger("saida_dono", -debt)
	c.archetype = String(o.get("arch", c.archetype))
	c.fan_mood = clampf(c.fan_mood - 12.0, 0.0, 100.0)
	c.board_confidence = 45.0
	FinanceManager.set_budgets(world, c)
	if newsworthy(world, c):
		NewsManager.post_raw(world, "%s abandona o %s" % [o.get("who", "Investidor"), c.short_name],
			"Depois de %d temporada(s), %s desistiu do projeto e deixou %s em dívidas. O clube terá de vender para fechar as contas." % [
				world.year - int(o.get("y", world.year)), o.get("who", "o investidor"), Fmt.money(debt)], c.id, -1, NewsEvent.IMP_HIGH, "clube")


## Eleição / troca de presidente: a paciência da diretoria recomeça do zero.
static func new_president(world: GameWorld, c: Club) -> void:
	var rng := world.rng
	var before := c.board_confidence
	c.board_confidence = clampf(lerpf(c.board_confidence, rng.randf_range(45.0, 65.0), 0.7), 0.0, 100.0)
	var who: String = RngUtil.pick(rng, ["um empresário do ramo imobiliário", "um ex-jogador ídolo do clube", "o antigo vice de futebol",
		"um advogado da oposição", "um banqueiro conselheiro", "um candidato da torcida organizada"])
	var style: String = RngUtil.pick(rng, ["promete austeridade", "promete reforços", "diz que confia no trabalho atual", "quer a base no time principal"])
	if world.is_user_club(c.id):
		var mood := "mais paciência" if c.board_confidence > before else "menos paciência"
		NewsManager.post_raw(world, "Novo presidente no %s" % c.short_name,
			"O clube elegeu %s, que %s. A diretoria nova chega com %s com o treinador (confiança %d)." % [who, style, mood, int(c.board_confidence)],
			c.id, -1, NewsEvent.IMP_HEADLINE, "clube")
	elif newsworthy(world, c) and c.tier == 1:
		NewsManager.post_raw(world, "Eleição no %s" % c.short_name, "O %s elegeu %s, que %s." % [c.name, who, style], c.id, -1, NewsEvent.IMP_LOW, "clube")


# ---------------------------------------------------------------------------
# Virada de ano
# ---------------------------------------------------------------------------

## Início da nova temporada (antes dos orçamentos): TV, obras, crises e ampliações.
static func season_start(world: GameWorld) -> void:
	_tv_deals(world)
	_finish_stadium_works(world)
	for c: Club in world.clubs:
		var revenue := float(FinanceManager.expected_revenue(c))
		var ratio := FinanceManager.debt_ratio(c, revenue)
		if ratio > 1.0 and world.rng.randf() < 0.45:
			_judicial_recovery(world, c, revenue)
		elif not world.is_user_club(c.id) and c.balance > revenue * 1.5 and c.fan_base > c.capacity and world.rng.randf() < 0.3:
			_expand_stadium_ai(world, c)


static func _tv_deals(world: GameWorld) -> void:
	var changes := FinanceManager.renegotiate_tv(world)
	if not world.has_user():
		return
	for ch in changes:
		var id := String(ch["league"])
		var cfg := DatabaseManager.league_cfg(id)
		var mine := String(cfg.get("nation", "")) == world.user_nation()
		if not mine and not (int(cfg.get("tier", 1)) == 1 and int(DatabaseManager.nation(String(cfg.get("nation", ""))).get("coef", 0)) >= SeasonManager.MAJOR_COEF):
			continue
		var delta := (float(ch["new"]) / maxf(0.01, float(ch["old"])) - 1.0) * 100.0
		if absf(delta) < 2.0:
			continue
		var up := delta > 0.0
		NewsManager.post_raw(world, "%s: novo contrato de TV" % cfg.get("name", id),
			"A liga fechou um novo acordo de transmissão por %d temporadas: as cotas %s %d%%." % [FinanceManager.TV_DEAL_YEARS, "sobem" if up else "caem", int(round(absf(delta)))],
			-1, -1, NewsEvent.IMP_HIGH if mine and id == world.user_league_id() else NewsEvent.IMP_NORMAL, "clube")


## Recuperação judicial: parte da dívida é renegociada, mas o clube perde prestígio e precisa vender.
static func _judicial_recovery(world: GameWorld, c: Club, revenue: float) -> void:
	var forgiven := int(-c.balance * 0.45)
	c.add_ledger("renegociacao", forgiven)
	c.reputation = maxf(5.0, c.reputation - 3.0)
	c.fan_mood = clampf(c.fan_mood - 10.0, 0.0, 100.0)
	var squad: Array = world.squad(c)
	squad.sort_custom(func(a, b): return a.wage > b.wage)
	var listed: Array = []
	if not world.is_user_club(c.id):
		for p: Player in squad.slice(0, 2):
			p.transfer_listed = true
			p.asking_price = int(TransferManager.asking_price(world, p) * 0.8)
			listed.append(p.display_name())
	world.stat_add("judicial_recoveries")
	var body := "Afundado em dívidas (%s, mais de um ano de receita), o %s entrou em recuperação judicial. %s da dívida foram renegociados, mas o clube terá de apertar o cinto." % [
		Fmt.money(-c.balance + forgiven), c.name, Fmt.money(forgiven)]
	if not listed.is_empty():
		body += " %s estão à venda." % " e ".join(listed)
	if world.is_user_club(c.id):
		body += " Sem verba para contratações até o caixa voltar ao azul."
		NewsManager.post_raw(world, "%s em recuperação judicial" % c.short_name, body, c.id, -1, NewsEvent.IMP_HEADLINE, "clube")
	elif newsworthy(world, c):
		NewsManager.post_raw(world, "%s em recuperação judicial" % c.short_name, body, c.id, -1, NewsEvent.IMP_HIGH, "clube")


## Custo de ampliar o estádio em `seats` lugares.
static func stadium_cost(c: Club, seats: int) -> int:
	return Valuation.round_value(seats * FinanceManager.ticket_price(c) * 120.0)


static func _expand_stadium_ai(world: GameWorld, c: Club) -> void:
	var seats := int(c.capacity * world.rng.randf_range(0.12, 0.3) / 100.0) * 100
	if seats < 500:
		return
	var cost := stadium_cost(c, seats)
	if cost > c.balance * 0.6:
		return
	c.add_ledger("investimentos", -cost)
	c.capacity += seats
	if newsworthy(world, c):
		NewsManager.post_raw(world, "%s amplia o %s" % [c.short_name, c.stadium],
			"O %s investiu %s e o estádio ganhou %d lugares: agora cabem %d torcedores." % [c.name, Fmt.money(cost), seats, c.capacity], c.id, -1, NewsEvent.IMP_LOW, "clube")


## Obras aprovadas pelo usuário ficam prontas na virada do ano.
static func _finish_stadium_works(world: GameWorld) -> void:
	var add := int(world.stats.get("stadium_work", 0))
	if add <= 0 or not world.has_user():
		return
	world.stats.erase("stadium_work")
	var c := world.user_club()
	c.capacity += add
	NewsManager.post_raw(world, "Estádio ampliado", "As obras terminaram: o %s ganhou %d lugares e agora recebe %d torcedores." % [c.stadium, add, c.capacity],
		c.id, -1, NewsEvent.IMP_HIGH, "clube")


# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

## O usuário ficaria sabendo? Clubes do país dele (até a 2ª divisão), rivais e gigantes das ligas grandes.
static func newsworthy(world: GameWorld, c: Club) -> bool:
	if not world.has_user():
		return false
	var u := world.user_club()
	if u.is_rival(c.id) or c.league_id == u.league_id:
		return true
	if c.nation == u.nation and c.tier <= 2:
		return true
	return c.tier == 1 and c.reputation >= 75.0 and int(DatabaseManager.nation(c.nation).get("coef", 0)) >= SeasonManager.MAJOR_COEF
