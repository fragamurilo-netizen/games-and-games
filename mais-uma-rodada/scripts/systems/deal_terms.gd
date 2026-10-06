class_name DealTerms
extends RefCounted
## Condições que deixam as negociações mais parecidas com as de verdade (complementa TransferManager):
##   - Empresário: pede comissão (um % da transferência, ou alguns salários num jogador livre ou numa
##     renovação). Cortar a comissão deixa o salário pedido mais alto e, cortada demais, trava o acordo.
##   - Bônus no contrato: por jogo e por gol. O jogador troca parte do salário fixo por eles.
##   - Promessa de papel no elenco (estrela, titular, rodízio): baixa o pedido; descumprida, vira crise.
##   - Bônus por metas ao clube vendedor (add-on): pago quando o jogador completa N jogos pelo clube.
##   - Empréstimo com opção ou obrigação de compra e divisão do salário.
##   - Nas vendas do usuário: propostas parceladas ou com bônus, pedido de % de revenda e de
##     cláusula de recompra; parcelas a receber nas temporadas seguintes.
##   - Clube vendedor com paciência (propostas ridículas encerram a conversa) e o relógio da janela
##     (na reta final, quem precisa vender cede e quem perde titular endurece).
## Estado: Player.clauses {gb, ab (bônus), pr, pry (promessa), bb, bbv, bby (recompra), so, pct},
## Player.loan {opt, obl, ws}, world.stats["addons"] (bônus por metas pendentes) e
## world.stats["recv"] (parcelas a receber). Tudo com padrão vazio: saves antigos seguem iguais.

const ADDON_APPS := 25 # jogos pelo clube para o bônus por metas sair
const ADDON_YEARS := 3
const OBLIGATION_APPS := 10 # a obrigação de compra do empréstimo dispara com 10 jogos
const AGENT_CUTS: Array = [[1.0, "Cheia"], [0.75, "-25%"], [0.5, "-50%"]]
const ROLE_OPTIONS: Array = [[-1, "Nenhuma"], [Player.STATUS_STAR, "Estrela"], [Player.STATUS_STARTER, "Titular"], [Player.STATUS_ROTATION, "Rodízio"]]
const BUYBACK_YEARS := 2


# ---------------------------------------------------------------------------
# Empresário
# ---------------------------------------------------------------------------

## Comissão pedida numa transferência (fração do valor): 3% a 10%, mais alta nos jogadores disputados.
static func agent_pct(world: GameWorld, p: Player) -> float:
	var pct := 0.05
	if p.squad_status == Player.STATUS_STAR:
		pct += 0.02
	if p.age(world.year) <= 21 and p.potential >= p.overall + 8:
		pct += 0.02 # empresário de joia cobra caro
	if p.value >= 40_000_000:
		pct -= 0.01
	pct += (float(absi(hash([p.id, "agent"])) % 5) - 2.0) * 0.005
	return clampf(pct, 0.03, 0.10)


## Comissão de contrato sem transferência (livre, pré-contrato, renovação): alguns salários.
static func agent_lump(world: GameWorld, p: Player, mode: String, wage: int) -> int:
	var months := 1.5 if mode == "renew" else 3.0
	if p.squad_status == Player.STATUS_STAR:
		months += 1.0
	return Valuation.round_value(wage * months)


## Custo da comissão com o corte proposto.
static func agent_cost(world: GameWorld, p: Player, fee: int, mode: String, wage: int, deal: Dictionary) -> int:
	var frac := float(deal.get("agent", 1.0))
	if fee > 0:
		return int(fee * float(deal.get("agent_pct", agent_pct(world, p))) * frac)
	return int(agent_lump(world, p, mode, wage) * frac)


## Empresário que se sente passado para trás trava o acordo. "" = segue a conversa.
static func agent_block(world: GameWorld, p: Player, deal: Dictionary) -> String:
	var frac := float(deal.get("agent", 1.0))
	if frac >= 0.75:
		return ""
	if absi(hash([p.id, world.year, "agent_cut"])) % 100 < 55:
		return "O empresário de %s não aceita cortar a comissão pela metade e encerrou a conversa. Tente com a comissão cheia ou -25%%." % p.display_name()
	return ""


# ---------------------------------------------------------------------------
# Bônus por jogo e por gol
# ---------------------------------------------------------------------------

## Valores das opções [nenhum, moderado, alto] para o salário `wage`.
static func bonus_options(kind: String, wage: int) -> Array:
	var m: Array = [0.0, 0.04, 0.08] if kind == "ab" else [0.0, 0.08, 0.16]
	var out: Array = []
	for x in m:
		out.append(Valuation.round_wage(wage * float(x)) if x > 0.0 else 0)
	return out


## Jogos por temporada que o jogador espera fazer (pelo papel no elenco).
static func expected_apps(p: Player, role: int) -> float:
	var r := role if role >= 0 else p.squad_status
	return [40.0, 34.0, 24.0, 12.0, 14.0][clampi(r, 0, 4)]


## Gols por jogo que ele espera marcar (posição e histórico).
static func expected_gpg(p: Player) -> float:
	var base: float = [0.0, 0.04, 0.12, 0.45][Pos.group(p.position)]
	if p.career_apps >= 30:
		base = base * 0.5 + float(p.career_goals) / float(p.career_apps) * 0.5
	return base


## Quanto os bônus valem por mês para o jogador (ele desconta a incerteza).
static func bonus_monthly_value(p: Player, deal: Dictionary) -> float:
	var role := int(deal.get("role", -1))
	var apps := expected_apps(p, role)
	var v := float(deal.get("ab", 0)) * apps + float(deal.get("gb", 0)) * apps * expected_gpg(p)
	return v * 0.75 / 12.0


# ---------------------------------------------------------------------------
# Promessa de papel no elenco
# ---------------------------------------------------------------------------

static func role_name(role: int) -> String:
	for r in ROLE_OPTIONS:
		if int(r[0]) == role:
			return String(r[1])
	return ""


## O jogador acredita na promessa? (quantos melhores que ele há na posição)
static func promise_credible(world: GameWorld, p: Player, club: Club, role: int) -> bool:
	if role < 0:
		return true
	var better := 0
	for q: Player in world.squad(club):
		if q.id != p.id and Pos.group(q.position) == Pos.group(p.position) and q.ovr_f > p.ovr_f + 1.0:
			better += 1
	var slots: int = [2, 5, 5, 4][Pos.group(p.position)] if role == Player.STATUS_ROTATION else [1, 4, 4, 2][Pos.group(p.position)]
	if role == Player.STATUS_STAR:
		return better == 0 and p.ovr_f >= PlayerGenerator.club_level(club) + 2.0
	return better < slots


## Desconto no salário pedido pela promessa (0 se ele não acredita).
static func promise_discount(world: GameWorld, p: Player, club: Club, role: int) -> float:
	if role < 0 or not promise_credible(world, p, club, role):
		return 0.0
	match role:
		Player.STATUS_STAR:
			return 0.12
		Player.STATUS_STARTER:
			return 0.07
		Player.STATUS_ROTATION:
			return 0.02
	return 0.0


## Pedido salarial depois de bônus, promessa e corte na comissão do empresário.
static func adjust_demand(world: GameWorld, p: Player, club: Club, demand: int, deal: Dictionary) -> int:
	var d := float(demand)
	d -= bonus_monthly_value(p, deal)
	d *= 1.0 - promise_discount(world, p, club, int(deal.get("role", -1)))
	var frac := float(deal.get("agent", 1.0))
	if frac < 1.0:
		d *= 1.0 + (1.0 - frac) * 0.3 # o empresário empurra o salário para compensar
	return Valuation.round_wage(maxf(d, demand * 0.5))


# ---------------------------------------------------------------------------
# Fechamento: grava bônus, promessa e bônus por metas; cobra a comissão
# ---------------------------------------------------------------------------

static func on_signed(world: GameWorld, p: Player, club: Club, seller_id: int, fee: int, deal: Dictionary, mode: String) -> void:
	if deal.is_empty():
		return
	var cl: Dictionary = p.clauses
	for k in ["gb", "ab", "pr", "pry"]:
		cl.erase(k)
	if int(deal.get("gb", 0)) > 0:
		cl["gb"] = int(deal["gb"])
	if int(deal.get("ab", 0)) > 0:
		cl["ab"] = int(deal["ab"])
	var role := int(deal.get("role", -1))
	if role >= 0:
		cl["pr"] = role
		cl["pry"] = world.year if TransferManager.season_progress(world) < 0.5 else world.year + 1
		p.squad_status = role
	p.clauses = cl
	if deal.has("agent_pct") or deal.has("agent"):
		var cost := agent_cost(world, p, fee, mode, p.wage, deal)
		if cost > 0:
			club.add_ledger("compras" if fee > 0 else "luvas", -cost)
	var addon := addon_amount(fee, deal)
	if addon > 0 and seller_id >= 0:
		register_addon(world, p, club.id, seller_id, addon)


static func addon_amount(fee: int, deal: Dictionary) -> int:
	return Valuation.round_value(fee * clampf(float(deal.get("addon", 0.0)), 0.0, 0.4)) if float(deal.get("addon", 0.0)) > 0.0 else 0


static func register_addon(world: GameWorld, p: Player, payer: int, receiver: int, amount: int) -> void:
	var arr: Array = world.stats.get("addons", [])
	arr.append({"pid": p.id, "pay": payer, "rec": receiver, "v": amount, "n": ADDON_APPS, "base": p.career_apps,
		"until": world.year + ADDON_YEARS, "pn": p.display_name()})
	world.stats["addons"] = arr


## Bônus por metas pendentes que envolvem o clube do usuário: [{pn, v, left (jogos), until, pay (bool: o usuário paga)}].
static func user_addons(world: GameWorld) -> Array:
	var out: Array = []
	for e in world.stats.get("addons", []):
		var pays := world.is_user_club(int(e["pay"]))
		if not pays and not world.is_user_club(int(e["rec"])):
			continue
		var p := world.player(int(e["pid"]))
		var done := (p.career_apps - int(e["base"])) if p != null else 0
		out.append({"pn": e["pn"], "v": int(e["v"]), "left": maxi(0, int(e["n"]) - done), "until": int(e["until"]), "pay": pays})
	return out


# ---------------------------------------------------------------------------
# Relógio da janela e humor do vendedor
# ---------------------------------------------------------------------------

## 0 no começo da janela, 1 no último dia: pressão do fechamento.
static func deadline_factor(world: GameWorld) -> float:
	if world.season == null or not world.transfer_window_open():
		return 0.0
	var end := world.window_end_day()
	var start := end
	for wr in world.season.window_ranges():
		if world.season.day >= int(wr[0]) and world.season.day <= int(wr[1]):
			start = int(wr[0])
	var span := maxf(1.0, float(end - start))
	var t := float(world.season.day - start) / span
	return clampf((t - 0.6) / 0.4, 0.0, 1.0) # só pesa no último terço


## Multiplicador do preço pedido na reta final: quem quer vender cede; titular fica mais caro.
static func deadline_mult(world: GameWorld, seller: Club, p: Player) -> float:
	var df := deadline_factor(world)
	if df <= 0.0:
		return 1.0
	if p.transfer_listed or p.squad_status >= Player.STATUS_BACKUP or FinanceManager.in_trouble(seller) or p.contract_years_left(world.year) <= 0:
		return 1.0 - 0.12 * df
	if p.squad_status <= Player.STATUS_STARTER:
		return 1.0 + 0.15 * df # sem tempo de repor
	return 1.0


static func deadline_hint(world: GameWorld, seller: Club, p: Player) -> String:
	var df := deadline_factor(world)
	if df <= 0.0:
		return ""
	var m := deadline_mult(world, seller, p)
	if m < 1.0:
		return "Reta final da janela: o %s quer resolver a venda e aceita menos." % seller.short_name
	if m > 1.0:
		return "Reta final da janela: sem tempo para repor, o %s só libera titular por mais." % seller.short_name
	return "Reta final da janela: as conversas andam mais rápido."


# ---------------------------------------------------------------------------
# Empréstimos com opção/obrigação de compra e divisão do salário
# ---------------------------------------------------------------------------

## Preço de compra combinado para a opção/obrigação (o que o dono pediria hoje).
static func loan_option_price(world: GameWorld, p: Player) -> int:
	return Valuation.round_value(TransferManager.asking_price(world, p) * 1.05)


## Taxa do empréstimo com essas condições: obrigação barateia, dono pagando salário encarece.
static func loan_fee_with(world: GameWorld, p: Player, terms: Dictionary) -> int:
	var f := float(TransferManager.loan_fee(p))
	match String(terms.get("kind", "")):
		"opt":
			f *= 0.8
		"obl":
			f *= 0.45
	f *= 1.0 + (1.0 - float(terms.get("ws", 1.0))) * 0.6
	return Valuation.round_value(f)


## O dono topa? "" se sim; senão o motivo. (A parte da janela, elenco e rival fica em loan_in_terms.)
static func loan_owner_block(world: GameWorld, p: Player, terms: Dictionary) -> String:
	var owner := world.club(p.club_id)
	var kind := String(terms.get("kind", ""))
	var ws := float(terms.get("ws", 1.0))
	var starter := p.squad_status <= Player.STATUS_STARTER and p.age(world.year) > 21
	if p.squad_status == Player.STATUS_STAR:
		return "%s não empresta a estrela do time." % owner.short_name
	if starter and kind != "obl":
		return "%s só libera um titular por empréstimo com obrigação de compra." % owner.short_name
	if ws < 1.0 and p.squad_status <= Player.STATUS_ROTATION and kind == "":
		return "%s não vai pagar parte do salário de quem ele usa." % owner.short_name
	if ws <= 0.5 and not (p.transfer_listed or p.squad_status >= Player.STATUS_BACKUP):
		return "%s aceita dividir o salário só de quem está sobrando no elenco." % owner.short_name
	return ""


## Salário que o dono ainda paga no resto da temporada (divisão combinada).
static func owner_wage_share(world: GameWorld, p: Player, ws: float) -> int:
	return int(p.wage * (1.0 - ws) * 12.0 * maxf(0.0, 1.0 - TransferManager.season_progress(world)))


## Usuário exerce a opção de compra de quem está com ele emprestado.
static func exercise_option(world: GameWorld, p: Player) -> Dictionary:
	var user := world.user_club()
	if p.club_id != user.id or p.loan.is_empty() or not p.loan.has("opt") or world.is_user_club(int(p.loan.get("from", -1))):
		return {"ok": false, "msg": "Não há opção de compra para exercer."}
	var price := int(p.loan["opt"])
	if price > user.transfer_budget:
		return {"ok": false, "msg": "A opção custa %s e o orçamento é %s." % [Fmt.money(price), Fmt.money(user.transfer_budget)]}
	var owner := world.club(int(p.loan["from"]))
	_buy_from_loan(world, p, owner, user, price)
	return {"ok": true, "msg": "%s é seu em definitivo por %s." % [p.display_name(), Fmt.money(price)]}


static func _buy_from_loan(world: GameWorld, p: Player, owner: Club, borrower: Club, price: int) -> void:
	borrower.player_ids.erase(p.id)
	p.loan = {}
	if owner == null:
		p.club_id = -1
		NationalityManager.sync_residence(world, p, true)
		TransferManager.complete_transfer(world, p, borrower, 0, maxi(p.wage, Valuation.wage_demand(p, borrower, world.year)), TransferManager.preferred_years(world, p))
		return
	owner.player_ids.append(p.id)
	p.club_id = owner.id
	NationalityManager.sync_residence(world, p, true)
	var wage := maxi(p.wage, Valuation.wage_demand(p, borrower, world.year)) if not world.is_user_club(borrower.id) else p.wage
	TransferManager.complete_transfer(world, p, borrower, price, wage, TransferManager.preferred_years(world, p))


static func season_apps(p: Player) -> int:
	var n := p.stats[Player.S_APPS]
	for k in p.cup_stats:
		n += int(p.cup_stats[k][Player.C_APPS])
	return n


static func season_goals(p: Player) -> int:
	var n := p.stats[Player.S_GOALS]
	for k in p.cup_stats:
		n += int(p.cup_stats[k][Player.C_GOALS])
	return n


# ---------------------------------------------------------------------------
# Vendas do usuário: estrutura das propostas, revenda e recompra
# ---------------------------------------------------------------------------

## A IA às vezes propõe parcelado (pagando um pouco mais no total) ou com bônus por metas.
static func shape_offer(world: GameWorld, o: TransferOffer, buyer: Club) -> void:
	var rng := world.rng
	if rng.randf() < (0.45 if FinanceManager.in_trouble(buyer) or buyer.transfer_budget < o.fee * 1.3 else 0.2):
		o.inst = 3 if rng.randf() < 0.4 else 2
		o.fee = Valuation.round_value(o.fee * (1.0 + 0.04 * (o.inst - 1)))
		o.max_fee = maxi(o.max_fee, o.fee)
	if rng.randf() < 0.25:
		o.addon = Valuation.round_value(o.fee * rng.randf_range(0.08, 0.2))


## Usuário pede % de revenda ("so") ou cláusula de recompra ("bb"). Conta como rodada de negociação.
static func request_clause(world: GameWorld, o: TransferOffer, kind: String) -> String:
	var p := world.player(o.player_id)
	var buyer := world.club(o.buyer_id)
	if p == null or buyer == null or not o.is_pending():
		return "Essa proposta não está mais disponível."
	if o.rounds >= TransferManager.MAX_COUNTERS:
		o.status = TransferOffer.WITHDRAWN
		return "%s cansou de negociar e desistiu." % buyer.short_name
	o.rounds += 1
	var age := p.age(world.year)
	match kind:
		"so":
			if o.so > 0.0:
				return "A revenda já está no acordo."
			if age >= 29:
				return "%s recusou: revenda não faz sentido para um jogador de %d anos." % [buyer.short_name, age]
			o.so = 0.15
			o.fee = Valuation.round_value(o.fee * 0.95)
			return "%s aceita 15%% de uma venda futura, mas baixa a oferta para %s." % [buyer.short_name, Fmt.money(o.fee)]
		"bb":
			if o.bb > 0:
				return "A recompra já está no acordo."
			if age > 23:
				return "%s recusou: recompra só se discute por jogador jovem." % buyer.short_name
			if p.potential >= 84 or buyer.reputation >= world.user_club().reputation + 15.0:
				return "%s não aceita recompra: quer o jogador para ficar." % buyer.short_name
			o.bb = Valuation.round_value(maxf(o.fee * 2.0, p.value * 2.2))
			o.fee = Valuation.round_value(o.fee * 0.92)
			return "%s aceita a recompra por %s (até %d), com a oferta em %s." % [buyer.short_name, Fmt.money(o.bb), world.year + BUYBACK_YEARS, Fmt.money(o.fee)]
	return ""


## Venda aceita: parcelas a receber, bônus por metas, revenda e recompra.
static func on_offer_accepted(world: GameWorld, o: TransferOffer, p: Player, buyer: Club) -> void:
	var user := world.club(o.seller_id)
	if o.inst > 1 and o.fee > 0:
		var later := o.fee - int(ceil(float(o.fee) / o.inst))
		user.add_ledger("vendas", -later)
		buyer.add_ledger("compras", later)
		var recv: Array = world.stats.get("recv", [])
		var part := int(later / (o.inst - 1))
		for k in o.inst - 1:
			recv.append({"y": world.year + 1 + k, "v": part, "p": p.display_name(), "cn": buyer.short_name})
		world.stats["recv"] = recv
	if o.addon > 0:
		register_addon(world, p, buyer.id, user.id, o.addon)
	var cl: Dictionary = p.clauses
	if o.so > 0.0:
		cl["so"] = user.id
		cl["pct"] = o.so
	if o.bb > 0:
		cl["bb"] = user.id
		cl["bbv"] = o.bb
		cl["bby"] = world.year + BUYBACK_YEARS
	p.clauses = cl


## Parcelas de vendas a receber (virada do ano, junto com as parcelas a pagar).
static func collect_receivables(world: GameWorld) -> int:
	var recv: Array = world.stats.get("recv", [])
	if recv.is_empty() or not world.has_user():
		return 0
	var total := 0
	var keep: Array = []
	for e in recv:
		if int(e["y"]) <= world.year:
			total += int(e["v"])
		else:
			keep.append(e)
	world.stats["recv"] = keep
	if total > 0:
		world.user_club().add_ledger("vendas", total)
		NewsManager.post_raw(world, "Parcelas de vendas recebidas", "O clube recebeu %s em parcelas de vendas antigas." % Fmt.money(total), world.user_club_id, -1, NewsEvent.IMP_NORMAL)
	return total


static func pending_receivables(world: GameWorld) -> int:
	var t := 0
	for e in world.stats.get("recv", []):
		t += int(e["v"])
	return t


## Recompra disponível para o usuário: {price, until} ou {}.
static func buyback_of(world: GameWorld, p: Player) -> Dictionary:
	if not world.has_user() or int(p.clauses.get("bb", -1)) != world.user_club_id or p.club_id < 0 or world.is_user_club(p.club_id):
		return {}
	if int(p.clauses.get("bby", 0)) < world.year:
		return {}
	return {"price": int(p.clauses.get("bbv", 0)), "until": int(p.clauses.get("bby", 0))}


# ---------------------------------------------------------------------------
# Fim de temporada (chamado por TransferManager.return_loans, antes dos emprestados voltarem)
# ---------------------------------------------------------------------------

static func season_end(world: GameWorld) -> void:
	if not world.has_user():
		return
	_pay_bonuses(world)
	_check_promises(world)
	_settle_addons(world)
	_settle_loans(world)


static func _pay_bonuses(world: GameWorld) -> void:
	var user := world.user_club()
	var total := 0
	var top := ""
	var top_v := 0
	for p: Player in world.squad(user):
		var ab := int(p.clauses.get("ab", 0))
		var gb := int(p.clauses.get("gb", 0))
		if ab <= 0 and gb <= 0:
			continue
		var v := ab * season_apps(p) + gb * season_goals(p)
		total += v
		if v > top_v:
			top_v = v
			top = p.display_name()
	if total > 0:
		user.add_ledger("salarios", -total)
		NewsManager.post_raw(world, "Bônus de desempenho pagos", "O %s pagou %s em bônus por jogos e gols previstos nos contratos. O maior foi de %s (%s)." % [user.short_name, Fmt.money(total), top, Fmt.money(top_v)],
			user.id, -1, NewsEvent.IMP_LOW, "clube")


static func _check_promises(world: GameWorld) -> void:
	var user := world.user_club()
	var lg := world.league_of(user.id)
	var games := lg.rounds_played() if lg != null else 0
	if games < 8:
		return
	for p: Player in world.squad(user):
		if not p.clauses.has("pr") or int(p.clauses.get("pry", 0)) > world.year:
			continue
		var role := int(p.clauses["pr"])
		var need: float = {Player.STATUS_STAR: 0.65, Player.STATUS_STARTER: 0.5, Player.STATUS_ROTATION: 0.25}.get(role, 0.3)
		var starts := p.stats[Player.S_STARTS]
		var cl := p.clauses
		cl.erase("pr")
		cl.erase("pry")
		p.clauses = cl
		var injured_long := p.injury_weeks >= 8
		if float(starts) >= need * games or injured_long:
			p.morale = clampf(p.morale + 6.0, 0.0, 100.0)
			People.add_trust(world, p, 6.0)
			continue
		p.morale = clampf(p.morale - 20.0, 0.0, 100.0)
		p.unhappy_weeks += 6
		People.add_trust(world, p, -15.0)
		InboxManager.send(world, "jogador", "%s cobra a promessa" % p.display_name(),
			"Você me prometeu ser %s e comecei só %d de %d jogos. Não foi isso que combinamos. Quero ouvir o que o clube pensa do meu futuro." % [role_name(role).to_lower(), starts, games],
			{}, p.id, user.id, p.display_name())
		NewsManager.post_raw(world, "%s insatisfeito com o papel no %s" % [p.display_name(), user.short_name],
			"Contratado com a promessa de ser %s, %s foi titular em só %d de %d jogos e deixou clara a irritação." % [role_name(role).to_lower(), p.display_name(), starts, games],
			user.id, p.id, NewsEvent.IMP_NORMAL, "clube")


static func _settle_addons(world: GameWorld) -> void:
	var arr: Array = world.stats.get("addons", [])
	if arr.is_empty():
		return
	var keep: Array = []
	for e in arr:
		var p := world.player(int(e["pid"]))
		var payer := world.club(int(e["pay"]))
		var rec := world.club(int(e["rec"]))
		if p == null or payer == null or rec == null:
			continue
		if p.club_id != payer.id and not (not p.loan.is_empty() and int(p.loan.get("from", -1)) == payer.id):
			continue # saiu antes de completar a meta: o bônus caduca
		if p.career_apps - int(e["base"]) >= int(e["n"]):
			var v := int(e["v"])
			payer.add_ledger("compras", -v)
			rec.add_ledger("vendas", v)
			if world.is_user_club(payer.id) or world.is_user_club(rec.id):
				NewsManager.post_raw(world, "Bônus por metas de %s" % p.display_name(),
					"%s completou %d jogos pelo %s e o bônus de %s previsto na transferência foi pago ao %s." % [p.display_name(), int(e["n"]), payer.short_name, Fmt.money(v), rec.short_name],
					rec.id if world.is_user_club(rec.id) else payer.id, p.id, NewsEvent.IMP_NORMAL, "transferencia")
			continue
		if world.year >= int(e["until"]):
			continue
		keep.append(e)
	world.stats["addons"] = keep


## Empréstimos que acabam agora com opção/obrigação envolvendo o usuário.
static func _settle_loans(world: GameWorld) -> void:
	for p: Player in world.players.values().duplicate():
		if p.loan.is_empty() or int(p.loan.get("until", 0)) > world.year or not p.loan.has("opt"):
			continue
		var owner := world.club(int(p.loan["from"]))
		var borrower := world.club(p.club_id)
		if owner == null or borrower == null:
			continue
		var user_borrows := world.is_user_club(borrower.id)
		var user_owns := world.is_user_club(owner.id)
		if not user_borrows and not user_owns:
			continue
		var price := int(p.loan["opt"])
		var apps := season_apps(p)
		if bool(p.loan.get("obl", false)):
			if apps >= OBLIGATION_APPS:
				_buy_from_loan(world, p, owner, borrower, price)
				NewsManager.post_raw(world, "%s fica no %s em definitivo" % [p.display_name(), borrower.short_name],
					"Com %d jogos, disparou a obrigação de compra do empréstimo: o %s paga %s ao %s." % [apps, borrower.short_name, Fmt.money(price), owner.short_name],
					borrower.id if user_borrows else owner.id, p.id, NewsEvent.IMP_HIGH, "transferencia")
			continue
		if user_owns:
			# Clube da IA decide a opção: fica com quem se firmou e cabe no bolso.
			var level := PlayerGenerator.club_level(borrower)
			var worth := p.squad_status <= Player.STATUS_ROTATION or p.ovr_f >= level - 1.0 or apps >= 20
			if worth and maxi(borrower.transfer_budget, borrower.balance / 3) >= price and p.age(world.year) < 33:
				_buy_from_loan(world, p, owner, borrower, price)
				NewsManager.post_raw(world, "%s exerce a opção por %s" % [borrower.short_name, p.display_name()],
					"O %s gostou do que viu e pagou %s ao %s para ficar com %s." % [borrower.short_name, Fmt.money(price), owner.short_name, p.display_name()],
					owner.id, p.id, NewsEvent.IMP_HIGH, "transferencia")
		elif user_borrows:
			InboxManager.send(world, "diretoria", "Opção de %s não exercida" % p.display_name(),
				"O empréstimo acabou e a opção de compra (%s) não foi usada: %s volta ao %s." % [Fmt.money(price), p.display_name(), owner.short_name], {}, p.id, owner.id)
