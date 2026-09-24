class_name TransferManager
extends RefCounted
## Mercado: preço pedido, interesse do jogador, negociação do usuário, IA↔IA,
## propostas da IA pelos jogadores do usuário, agentes livres, renovações e rescisões.

const STATUS_ASK: Array[float] = [1.55, 1.25, 1.05, 0.9, 1.3] # estrela, titular, rotação, reserva, promessa
const MAX_BIDS_PER_DAY := 3
const OFFER_DAYS := 2

# Famílias de posição para carências de elenco: [posições, mínimo]
const FAMILIES: Array = [
	[[Pos.GK], 2],
	[[Pos.CB], 3],
	[[Pos.RB, Pos.LB], 2],
	[[Pos.DM, Pos.CM], 4],
	[[Pos.AM, Pos.RM, Pos.LM, Pos.RW, Pos.LW], 3],
	[[Pos.ST], 2],
]


# ---------------------------------------------------------------------------
# Preço e interesse
# ---------------------------------------------------------------------------

## Quanto o clube dono pede pelo jogador.
static func asking_price(world: GameWorld, p: Player) -> int:
	if p.club_id < 0:
		return 0
	var club := world.club(p.club_id)
	if world.is_user_club(club.id) and p.transfer_listed and p.asking_price > 0:
		return p.asking_price
	var mult := float(club.arch().get("sell_mult", 1.0)) * STATUS_ASK[clampi(p.squad_status, 0, 4)]
	if p.transfer_listed:
		mult *= 0.85
	var years := p.contract_years_left(world.year)
	if years <= 0:
		mult *= 0.7
	elif years == 1:
		mult *= 0.9
	if club.balance < 0:
		mult *= 0.85
	if not world.is_user_club(club.id) and world.has_user():
		mult *= [0.92, 1.0, 1.1][world.difficulty]
	return Valuation.round_value(p.value * mult)


## Probabilidade (0..1) de o jogador topar se mudar para `buyer` com salário justo.
static func interest(world: GameWorld, p: Player, buyer: Club) -> float:
	var cur := world.club(p.club_id) if p.club_id >= 0 else null
	var rep_diff := buyer.reputation - (cur.reputation if cur != null else buyer.reputation - 8.0)
	var amb := 1.0 + p.trait_sum("ambition") / 40.0
	var v := 0.55 + rep_diff * 0.012 * maxf(0.4, amb)
	if cur != null:
		v += (cur.division - buyer.division) * 0.1
		v -= p.trait_sum("loyalty") / 100.0
		if cur.id == buyer.rival_id or cur.rival_id == buyer.id:
			v -= 0.15 # ninguém gosta de trocar pelo rival
	if p.age(world.year) >= 31:
		v += 0.1
	# Minutos: teria espaço no novo time?
	var better := 0
	for q in world.squad(buyer):
		if q.position == p.position and q.ovr_f > p.ovr_f + 2.0:
			better += 1
	v += 0.1 if better == 0 else (-0.08 * better)
	if p.morale < 40.0 and cur != null:
		v += 0.15 # insatisfeito quer sair
	return clampf(v, 0.05, 0.95)


## Salário pedido para assinar com `buyer` (quanto menos interessado, mais caro).
static func wage_ask(world: GameWorld, p: Player, buyer: Club) -> int:
	var base := float(Valuation.wage_demand(p, buyer, world.year))
	var i := interest(world, p, buyer)
	base *= 1.0 + (0.5 - i) * 0.6
	if p.club_id >= 0:
		base = maxf(base, p.wage * 1.05)
	return Valuation.round_wage(base)


static func preferred_years(world: GameWorld, p: Player) -> int:
	var age := p.age(world.year)
	if age <= 23:
		return 4
	if age <= 28:
		return 3
	if age <= 31:
		return 2
	return 1


# ---------------------------------------------------------------------------
# Negociação do usuário
# ---------------------------------------------------------------------------

## Proposta do usuário ao clube dono. Retorna {result: "accepted"|"counter"|"rejected", fee, msg}.
static func user_bid(world: GameWorld, p: Player, fee: int) -> Dictionary:
	var user := world.user_club()
	if p.club_id < 0:
		return {"result": "accepted", "fee": 0, "msg": "Jogador livre: negocie direto com ele."}
	if p.club_id == user.id:
		return {"result": "rejected", "fee": 0, "msg": "Ele já é seu jogador."}
	if not world.transfer_window_open():
		return {"result": "rejected", "fee": 0, "msg": "A janela de transferências está fechada."}
	if fee > user.transfer_budget:
		return {"result": "rejected", "fee": 0, "msg": "A diretoria não libera esse valor. Orçamento: %s." % Fmt.money(user.transfer_budget)}
	var neg: Dictionary = world.stats.get("neg", {})
	var key := str(p.id)
	var n: Dictionary = neg.get(key, {"d": -1, "n": 0})
	if int(n["d"]) == world.current_day() and int(n["n"]) >= MAX_BIDS_PER_DAY:
		return {"result": "rejected", "fee": 0, "msg": "O clube encerrou as conversas por hoje. Tente na próxima rodada."}
	if int(n["d"]) != world.current_day():
		n = {"d": world.current_day(), "n": 0}
	n["n"] = int(n["n"]) + 1
	neg[key] = n
	world.stats["neg"] = neg
	var seller := world.club(p.club_id)
	var ask := asking_price(world, p)
	# Clube não vende titular absoluto para rival direto, exceto por muito dinheiro.
	if seller.is_rival(user.id) and p.squad_status <= Player.STATUS_STARTER:
		ask = int(ask * 1.4)
	# Elenco curto na posição: pede mais.
	if _family_count(world, seller, p.position) <= _family_min(p.position):
		ask = int(ask * 1.25)
	if fee >= ask:
		return {"result": "accepted", "fee": fee, "msg": "%s aceitou a proposta!" % seller.short_name}
	if fee >= ask * 0.8:
		var counter := Valuation.round_value((fee + ask) * 0.5 if fee >= ask * 0.92 else ask)
		counter = maxi(counter, fee + 1000)
		return {"result": "counter", "fee": counter, "msg": "%s pede %s." % [seller.short_name, Fmt.money(counter)]}
	return {"result": "rejected", "fee": 0, "msg": "Proposta recusada: muito abaixo do esperado (%s pediria algo perto de %s)." % [seller.short_name, Fmt.money(Valuation.round_value(ask * 1.05))]}


## Termos pessoais. Retorna {result: "accepted"|"counter"|"rejected", wage, msg}.
static func user_terms(world: GameWorld, p: Player, wage: int, years: int) -> Dictionary:
	var user := world.user_club()
	var i := interest(world, p, user)
	if i < 0.18:
		return {"result": "rejected", "wage": 0, "msg": "%s não tem interesse em jogar no %s." % [p.display_name(), user.short_name]}
	var demand := wage_ask(world, p, user)
	var pref := preferred_years(world, p)
	if absi(years - pref) >= 2:
		demand = Valuation.round_wage(demand * 1.1)
	if not _wage_fits(world, user, p, wage):
		return {"result": "rejected", "wage": demand, "msg": "Folha salarial estourada: a diretoria limita a %s/mês." % Fmt.money(user.wage_budget)}
	if wage >= demand:
		return {"result": "accepted", "wage": wage, "msg": "%s aceitou os termos!" % p.display_name()}
	if wage >= demand * 0.9 and world.rng.randf() < 0.5:
		return {"result": "accepted", "wage": wage, "msg": "%s aceitou, mesmo pedindo um pouco mais." % p.display_name()}
	return {"result": "counter", "wage": demand, "msg": "%s quer %s por %d ano(s)." % [p.display_name(), Fmt.money_month(demand), years]}


static func _wage_fits(world: GameWorld, club: Club, p: Player, wage: int) -> bool:
	var bill := FinanceManager.wage_bill(world, club)
	if p.club_id == club.id:
		bill -= p.wage
	return bill + wage <= int(club.wage_budget * 1.02)


## Executa a transferência (qualquer clube). fee pode ser 0 (livre).
static func complete_transfer(world: GameWorld, p: Player, buyer: Club, fee: int, wage: int, years: int) -> Transfer:
	var seller_id := p.club_id
	var seller := world.club(seller_id) if seller_id >= 0 else null
	if seller != null:
		seller.player_ids.erase(p.id)
		seller.add_ledger("vendas", fee)
		FinanceManager.on_sale(world, seller, fee)
		_close_spell(world, p)
	buyer.add_ledger("compras", -fee)
	buyer.transfer_budget = maxi(0, buyer.transfer_budget - fee)
	buyer.player_ids.append(p.id)
	buyer.cohesion = maxf(20.0, buyer.cohesion - 2.5)
	p.club_id = buyer.id
	p.wage = wage
	p.contract_end = world.year + clampi(years, 1, 5)
	p.joined_year = world.year
	p.transfer_listed = false
	p.asking_price = 0
	p.retiring = false
	p.morale = clampf(p.morale + 10.0, 0.0, 100.0)
	p.spells.append({"c": buyer.id, "cn": buyer.short_name, "from": world.year, "to": 0, "a": 0, "g": 0, "as": 0})
	_set_status_on_arrival(world, p, buyer)
	world.mark_free_agents_dirty()
	Valuation.update_value(p, world.year)
	var kind := Transfer.KIND_BUY if seller != null else Transfer.KIND_FREE
	var t := Transfer.make(world.year, world.current_day(), p, seller_id, buyer.id, fee, kind)
	world.transfer_log.append(t)
	world.stat_add("transfers")
	world.stat_add("transfer_fees", fee)
	# Propostas pendentes por esse jogador perdem o sentido.
	for o: TransferOffer in world.offers:
		if o.player_id == p.id and o.is_pending():
			o.status = TransferOffer.WITHDRAWN
	if world.is_user_club(buyer.id) and buyer.sheet != null:
		pass # a escalação é revalidada antes do próximo jogo
	NewsManager.on_transfer(world, t)
	return t


static func _close_spell(world: GameWorld, p: Player) -> void:
	if not p.spells.is_empty():
		var s: Dictionary = p.spells[p.spells.size() - 1]
		if int(s.get("to", 0)) == 0:
			s["to"] = world.year


static func _set_status_on_arrival(world: GameWorld, p: Player, club: Club) -> void:
	var better := 0
	for q in world.squad(club):
		if q != p and q.position == p.position and q.ovr_f > p.ovr_f:
			better += 1
	var age := p.age(world.year)
	if better == 0:
		p.squad_status = Player.STATUS_STARTER
	elif age <= 21 and p.potential >= p.overall + 6:
		p.squad_status = Player.STATUS_PROSPECT
	elif better == 1:
		p.squad_status = Player.STATUS_ROTATION
	else:
		p.squad_status = Player.STATUS_BACKUP


## Contratação de jogador livre (usuário). Retorna {ok, msg}.
static func user_sign_free(world: GameWorld, p: Player, wage: int, years: int) -> Dictionary:
	var user := world.user_club()
	if p.club_id >= 0:
		return {"ok": false, "msg": "Ele tem contrato com outro clube."}
	if user.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return {"ok": false, "msg": "Elenco cheio (máximo %d)." % int(DatabaseManager.squad_rules()["max_players"])}
	var r := user_terms(world, p, wage, years)
	if r["result"] != "accepted":
		return {"ok": false, "msg": r["msg"], "wage": r.get("wage", 0), "result": r["result"]}
	complete_transfer(world, p, user, 0, wage, years)
	return {"ok": true, "msg": "%s assinou com o %s!" % [p.display_name(), user.short_name]}


## Contratação com clube (depois de proposta aceita). Retorna {ok, msg}.
static func user_sign(world: GameWorld, p: Player, fee: int, wage: int, years: int) -> Dictionary:
	var user := world.user_club()
	if fee > user.transfer_budget:
		return {"ok": false, "msg": "Orçamento insuficiente."}
	if user.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return {"ok": false, "msg": "Elenco cheio (máximo %d)." % int(DatabaseManager.squad_rules()["max_players"])}
	var r := user_terms(world, p, wage, years)
	if r["result"] != "accepted":
		return {"ok": false, "msg": r["msg"], "wage": r.get("wage", 0), "result": r["result"]}
	complete_transfer(world, p, user, fee, wage, years)
	return {"ok": true, "msg": "%s é o novo reforço do %s!" % [p.display_name(), user.short_name]}


## Renovação de contrato. Retorna {result, wage, msg}.
static func renewal_terms(world: GameWorld, p: Player, wage: int, years: int) -> Dictionary:
	var club := world.club(p.club_id)
	var demand := float(Valuation.wage_demand(p, club, world.year))
	demand *= 1.0 + maxf(0.0, (55.0 - p.morale) / 100.0)
	if p.squad_status == Player.STATUS_STAR:
		demand *= 1.1
	demand = maxf(demand, p.wage * (0.9 if p.age(world.year) >= 32 else 1.0))
	var d := Valuation.round_wage(demand)
	# Ambicioso bom demais para o clube pode recusar.
	var ambition := p.trait_sum("ambition")
	var level := PlayerGenerator.club_level(club.division, club.reputation, club.arch())
	if ambition >= 25.0 and p.ovr_f >= level + 6.0 and p.age(world.year) <= 29:
		return {"result": "rejected", "wage": d, "msg": "%s quer jogar num clube maior e não pretende renovar." % p.display_name()}
	if p.morale < 25.0:
		return {"result": "rejected", "wage": d, "msg": "%s está insatisfeito e não quer conversar agora." % p.display_name()}
	if not _wage_fits(world, club, p, wage):
		return {"result": "rejected", "wage": d, "msg": "Esse salário estoura o limite da folha (%s/mês)." % Fmt.money(club.wage_budget)}
	if wage >= d:
		return {"result": "accepted", "wage": wage, "msg": "Renovado até %d!" % (world.year + years)}
	return {"result": "counter", "wage": d, "msg": "%s pede %s." % [p.display_name(), Fmt.money_month(d)]}


static func apply_renewal(world: GameWorld, p: Player, wage: int, years: int) -> void:
	p.wage = wage
	p.contract_end = world.year + clampi(years, 1, 5)
	p.morale = clampf(p.morale + 6.0, 0.0, 100.0)
	Valuation.update_value(p, world.year)


## Custo de rescisão: metade dos salários restantes do contrato.
static func release_cost(world: GameWorld, p: Player) -> int:
	var months := maxi(1, (p.contract_end - world.year) * 12 + 6)
	return int(p.wage * months * 0.5)


static func release(world: GameWorld, p: Player) -> int:
	var club := world.club(p.club_id)
	var cost := release_cost(world, p)
	club.add_ledger("rescisoes", -cost)
	club.player_ids.erase(p.id)
	_close_spell(world, p)
	var t := Transfer.make(world.year, world.current_day(), p, club.id, -1, 0, Transfer.KIND_RELEASE)
	world.transfer_log.append(t)
	p.club_id = -1
	p.wage = 0
	p.transfer_listed = false
	p.contract_end = world.year
	world.mark_free_agents_dirty()
	return cost


# ---------------------------------------------------------------------------
# Propostas recebidas pelo usuário
# ---------------------------------------------------------------------------

static func pending_offers(world: GameWorld) -> Array:
	var out: Array = []
	for o: TransferOffer in world.offers:
		if o.is_pending():
			out.append(o)
	return out


## Resposta do usuário: "accept", "reject" ou "counter" (pede mais). Retorna mensagem.
static func respond_offer(world: GameWorld, o: TransferOffer, action: String, counter_fee: int = 0) -> String:
	var p := world.player(o.player_id)
	var buyer := world.club(o.buyer_id)
	if p == null or buyer == null or not o.is_pending() or p.club_id != o.seller_id:
		o.status = TransferOffer.WITHDRAWN
		return "Essa proposta não está mais disponível."
	match action:
		"accept":
			if not world.transfer_window_open():
				return "A janela está fechada."
			o.status = TransferOffer.ACCEPTED
			var wage := Valuation.wage_demand(p, buyer, world.year)
			complete_transfer(world, p, buyer, o.fee, wage, preferred_years(world, p))
			return "%s foi vendido ao %s por %s." % [p.display_name(), buyer.short_name, Fmt.money(o.fee)]
		"reject":
			o.status = TransferOffer.REJECTED
			p.morale = clampf(p.morale - (6.0 if p.trait_sum("ambition") >= 25.0 else 1.0), 0.0, 100.0)
			return "Proposta recusada."
		"counter":
			if o.raised or counter_fee > o.max_fee:
				o.status = TransferOffer.WITHDRAWN
				return "%s desistiu da negociação." % buyer.short_name
			o.fee = counter_fee
			o.raised = true
			return "%s aceitou pagar %s. Confirme a venda!" % [buyer.short_name, Fmt.money(counter_fee)]
	return ""


# ---------------------------------------------------------------------------
# IA de mercado (a cada dia de jogo)
# ---------------------------------------------------------------------------

## Processa mercado da IA. Retorna Array de Transfer realizadas.
static func process_matchday(world: GameWorld) -> Array:
	var done: Array = []
	var window := world.transfer_window_open()
	var index := _build_index(world)
	var order: Array = []
	for c in world.clubs:
		if not world.is_user_club(c.id):
			order.append(c)
	RngUtil.shuffle(world.rng, order)
	for c: Club in order:
		var p_active := 0.55 if window else 0.08
		if world.rng.randf() >= p_active:
			continue
		var t := _ai_turn(world, c, index, window)
		if t != null:
			done.append(t)
	if window:
		_generate_offers_for_user(world)
	_expire_offers(world)
	return done


## Índice de jogadores por família de posição (reconstruído por dia de jogo).
static func _build_index(world: GameWorld) -> Array:
	var idx: Array = []
	for _f in FAMILIES:
		idx.append([])
	for p: Player in world.players.values():
		idx[_family_of(p.position)].append(p)
	return idx


static func _family_of(pos: int) -> int:
	for i in FAMILIES.size():
		if FAMILIES[i][0].has(pos):
			return i
	return 3


static func _family_min(pos: int) -> int:
	return int(FAMILIES[_family_of(pos)][1])


static func _family_count(world: GameWorld, club: Club, pos: int) -> int:
	var fam := _family_of(pos)
	var n := 0
	for p in world.squad(club):
		if _family_of(p.position) == fam and p.injury_weeks < 6:
			n += 1
	return n


## Carências do elenco: [{fam, urgency, best}] ordenado por urgência.
static func squad_needs(world: GameWorld, club: Club) -> Array:
	var level := PlayerGenerator.club_level(club.division, club.reputation, club.arch())
	var counts: Array = []
	var best: Array = []
	for _f in FAMILIES:
		counts.append(0)
		best.append(0.0)
	for p in world.squad(club):
		var f := _family_of(p.position)
		if p.injury_weeks < 6 and not p.retiring:
			counts[f] += 1
		best[f] = maxf(best[f], p.ovr_f)
	var out: Array = []
	for i in FAMILIES.size():
		var urgency := maxf(0.0, float(FAMILIES[i][1] - counts[i])) * 3.0 + maxf(0.0, level - best[i]) / 3.0
		if urgency > 0.5:
			out.append({"fam": i, "urgency": urgency, "best": best[i], "count": counts[i]})
	out.sort_custom(func(a, b): return a["urgency"] > b["urgency"])
	return out


static func _ai_turn(world: GameWorld, club: Club, index: Array, window: bool) -> Transfer:
	var rules := DatabaseManager.squad_rules()
	var size := club.player_ids.size()
	# Enxuga elenco inchado.
	if size > int(rules["max_players"]) - 1:
		_ai_release_weakest(world, club)
		return null
	var arch := club.arch()
	# Endividado: coloca alguém à venda para fazer caixa.
	if window and club.balance < 0 and world.rng.randf() < 0.35:
		_ai_list_for_sale(world, club)
	var mismanaged := world.rng.randf() < float(arch.get("mismanagement", 0.0)) * 0.25
	var level := PlayerGenerator.club_level(club.division, club.reputation, arch)
	var budget := club.transfer_budget
	var wage_room := club.wage_budget - FinanceManager.wage_bill(world, club)
	# Define o alvo: carência urgente > reforço da posição mais fraca do time titular.
	var needs := squad_needs(world, club)
	var fam := -1
	var target_pos := -1
	var min_rating := 0.0
	var urgent := false
	if not needs.is_empty() and int(needs[0]["count"]) < int(FAMILIES[int(needs[0]["fam"])][1]):
		fam = needs[0]["fam"]
		urgent = true
		min_rating = level - 9.0
	elif window and (budget > 0 or wage_room > 0) and size < int(rules["max_players"]) - 2:
		var weak := _weakest_starter(world, club)
		if not weak.is_empty() and float(weak["rating"]) < level + 4.0:
			target_pos = weak["pos"]
			fam = _family_of(target_pos)
			min_rating = float(weak["rating"]) + 2.5
	elif not needs.is_empty():
		fam = needs[0]["fam"]
		min_rating = float(needs[0]["best"]) + 1.0
	if mismanaged and fam < 0:
		fam = world.rng.randi_range(0, FAMILIES.size() - 1)
	if fam < 0:
		return null
	if wage_room <= 0 and not mismanaged and not urgent:
		return null
	var ages: Array = arch.get("target_age", [20, 30])
	var pot_w := float(arch.get("potential_weight", 0.4))
	var cands: Array = index[fam]
	var best: Player = null
	var best_score := -1e9
	var tries := mini(cands.size(), 90)
	for _k in tries:
		var p: Player = cands[world.rng.randi_range(0, cands.size() - 1)]
		if p.club_id == club.id or p.retiring or p.injury_weeks > 4:
			continue
		if p.club_id >= 0 and (not window or world.is_user_club(p.club_id)):
			continue
		var age := p.age(world.year)
		var rating := p.rating_at(target_pos) if target_pos >= 0 else p.ovr_f
		var eff := rating + (float(p.potential) - rating) * pot_w * (0.6 if age <= 23 else 0.0)
		if eff < min_rating and not mismanaged:
			continue
		var price := asking_price(world, p) if p.club_id >= 0 else 0
		if price > budget * (1.3 if mismanaged else 1.0):
			continue
		var wage := Valuation.wage_demand(p, club, world.year)
		var wage_delta := wage
		if wage_delta > maxi(wage_room, 0) * (1.5 if mismanaged else 1.0) and not (urgent and wage <= club.wage_budget * 0.08):
			continue
		var score := eff - min_rating
		if age < int(ages[0]) - 1 or age > int(ages[1]) + 1:
			score -= 3.0 + absf(age - clampi(age, int(ages[0]), int(ages[1]))) * 1.5
		score -= float(price) / maxf(50000.0, float(budget) + 1.0) * 2.5
		if p.transfer_listed:
			score += 1.5
		if mismanaged:
			score = world.rng.randf_range(-5.0, 5.0) + (rating - level) * 0.3
		if score > best_score:
			best_score = score
			best = p
	if best == null:
		return null
	var i := interest(world, best, club)
	if world.rng.randf() > i:
		return null
	var wage2 := wage_ask(world, best, club)
	if best.club_id < 0:
		return complete_transfer(world, best, club, 0, wage2, preferred_years(world, best))
	var ask := asking_price(world, best)
	var offer := Valuation.round_value(ask * world.rng.randf_range(0.9, 1.05) * (1.15 if mismanaged else 1.0))
	if offer < ask:
		offer = Valuation.round_value(ask) # sobe até o pedido
	if offer > budget * (1.3 if mismanaged else 1.0):
		return null
	var seller := world.club(best.club_id)
	# O vendedor não pode ficar sem ninguém na posição.
	if _family_count(world, seller, best.position) <= _family_min(best.position):
		return null
	return complete_transfer(world, best, club, offer, wage2, preferred_years(world, best))


## Vaga do time titular com o pior rendimento (alvo de reforço).
static func _weakest_starter(world: GameWorld, club: Club) -> Dictionary:
	var fname := club.sheet.formation if club.sheet != null else "4-4-2"
	var slots: Array = DatabaseManager.formation(fname)["slots"]
	var xi := ClubAI.best_eleven(world, club, fname)
	var worst := {}
	for i in slots.size():
		var pos: int = slots[i]["pos"]
		var r := 0.0
		if xi[i] >= 0:
			r = world.player(xi[i]).rating_at(pos)
		if worst.is_empty() or r < float(worst["rating"]):
			worst = {"pos": pos, "rating": r}
	return worst


## Clube endividado anuncia um jogador valioso (mas não insubstituível) à venda.
static func _ai_list_for_sale(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.value > b.value)
	for p in squad:
		if p.transfer_listed:
			return
		if _family_count(world, club, p.position) > _family_min(p.position):
			p.transfer_listed = true
			return


static func _ai_release_weakest(world: GameWorld, club: Club) -> void:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f + (8.0 if a.age(world.year) <= 21 else 0.0) < b.ovr_f + (8.0 if b.age(world.year) <= 21 else 0.0))
	for p in squad:
		if _family_count(world, club, p.position) > _family_min(p.position) + 1:
			release(world, p)
			return


## A IA faz propostas por jogadores do usuário (principalmente os listados e os em boa fase).
static func _generate_offers_for_user(world: GameWorld) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	var pending := 0
	for o: TransferOffer in world.offers:
		if o.is_pending():
			pending += 1
	if pending >= 4:
		return
	for p in world.squad(user):
		var chance := 0.012
		if p.transfer_listed:
			chance += 0.2
		if p.form() >= 7.2:
			chance += 0.04
		if p.squad_status == Player.STATUS_STAR:
			chance += 0.02
		if world.rng.randf() >= chance:
			continue
		var already := false
		for o: TransferOffer in world.offers:
			if o.player_id == p.id and o.is_pending():
				already = true
		if already:
			continue
		var buyer := _find_buyer(world, p)
		if buyer == null:
			continue
		var base := float(asking_price(world, p)) if p.transfer_listed else float(p.value)
		var fee := Valuation.round_value(base * world.rng.randf_range(0.8, 1.1))
		var o := TransferOffer.new()
		o.id = world.next_offer_id
		world.next_offer_id += 1
		o.player_id = p.id
		o.buyer_id = buyer.id
		o.seller_id = user.id
		o.fee = fee
		o.max_fee = Valuation.round_value(minf(buyer.transfer_budget, fee * world.rng.randf_range(1.05, 1.3)))
		o.created_day = world.current_day()
		o.expires_day = world.current_day() + OFFER_DAYS
		world.offers.append(o)
		NewsManager.on_offer_received(world, o)
		pending += 1
		if pending >= 4:
			return


static func _find_buyer(world: GameWorld, p: Player) -> Club:
	var best: Club = null
	var best_v := -1e9
	for _k in 12:
		var c: Club = world.clubs[world.rng.randi_range(0, world.clubs.size() - 1)]
		if world.is_user_club(c.id) or c.transfer_budget < p.value * 0.8:
			continue
		var level := PlayerGenerator.club_level(c.division, c.reputation, c.arch())
		if p.ovr_f < level - 4.0:
			continue
		var v := c.reputation - absf(p.ovr_f - level) * 2.0 + world.rng.randf_range(0.0, 10.0)
		if v > best_v:
			best_v = v
			best = c
	return best


static func _expire_offers(world: GameWorld) -> void:
	var keep: Array = []
	for o: TransferOffer in world.offers:
		if o.is_pending() and world.current_day() > o.expires_day:
			o.status = TransferOffer.EXPIRED
		if o.is_pending() or world.current_day() - o.expires_day <= 3:
			keep.append(o)
	world.offers = keep


# ---------------------------------------------------------------------------
# Fim de temporada: contratos e equilíbrio de elencos
# ---------------------------------------------------------------------------

## Contratos que vencem agora: IA renova quem vale a pena; o resto (e os do usuário não renovados) sai.
## Retorna jogadores que deixaram o clube do usuário.
static func process_expiring_contracts(world: GameWorld) -> Array:
	var left_user: Array = []
	for p: Player in world.players.values().duplicate():
		if p.club_id < 0 or p.contract_end > world.year:
			continue
		var club := world.club(p.club_id)
		if world.is_user_club(club.id):
			left_user.append(p)
			release_free(world, p)
			continue
		var level := PlayerGenerator.club_level(club.division, club.reputation, club.arch())
		var age := p.age(world.year)
		var useful := p.ovr_f >= level - 3.0 or p.squad_status <= Player.STATUS_STARTER
		var chance := 0.0
		if p.retiring:
			chance = 0.0
		elif age <= 22 and p.potential >= level - 2:
			chance = 0.9
		elif useful and age <= 31:
			chance = 0.85
		elif useful:
			chance = 0.55
		elif age <= 29:
			chance = 0.6 if club.player_ids.size() <= int(DatabaseManager.squad_rules()["ideal_players"]) else 0.35
		else:
			chance = 0.25
		var wage := Valuation.wage_demand(p, club, world.year)
		# A folha precisa caber no orçamento (clube endividado perde jogadores caros).
		var bill := FinanceManager.wage_bill(world, club) - p.wage + wage
		if bill > club.wage_budget * 1.05:
			chance *= 0.25
		if world.rng.randf() < chance:
			apply_renewal(world, p, wage, preferred_years(world, p))
		else:
			release_free(world, p)
	return left_user


## Saída sem custo (fim de contrato).
static func release_free(world: GameWorld, p: Player) -> void:
	var club := world.club(p.club_id)
	if club != null:
		club.player_ids.erase(p.id)
	_close_spell(world, p)
	p.club_id = -1
	p.wage = 0
	p.transfer_listed = false
	world.mark_free_agents_dirty()


## Garante elencos mínimos (IA contrata livres) e poda excessos. Chamado na virada de temporada.
static func balance_squads(world: GameWorld) -> void:
	var rules := DatabaseManager.squad_rules()
	var free := world.free_agents().duplicate()
	free.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		_ai_cut_wages(world, c)
		while c.player_ids.size() > int(rules["max_players"]):
			var before := c.player_ids.size()
			_ai_release_weakest(world, c)
			if c.player_ids.size() == before:
				break
		var guard := 0
		while guard < 12:
			guard += 1
			var needs := squad_needs(world, c)
			var short := c.player_ids.size() < int(rules["min_players"]) + 2
			var urgent: Dictionary = {}
			for n in needs:
				if int(n["count"]) < int(FAMILIES[int(n["fam"])][1]):
					urgent = n
					break
			if urgent.is_empty() and not short:
				break
			var fam: int = urgent["fam"] if not urgent.is_empty() else -1
			var pick: Player = null
			var level := PlayerGenerator.club_level(c.division, c.reputation, c.arch())
			for p: Player in free:
				if p.club_id >= 0:
					continue
				if fam >= 0 and _family_of(p.position) != fam:
					continue
				if p.ovr_f > level + 6.0:
					continue
				pick = p
				break
			if pick == null:
				var used := WorldGenerator.used_names_of(world)
				var pos: int = FAMILIES[fam][0][0] if fam >= 0 else Pos.CM
				pick = PlayerGenerator.create(world, world.rng, pos, level - 4.0, world.rng.randi_range(20, 30), NameGenerator.pick_nationality(world.rng, c.division), c.city, used)
				pick.club_id = -1
				world.add_player(pick)
			complete_transfer(world, pick, c, 0, Valuation.wage_demand(pick, c, world.year), world.rng.randi_range(1, 2))


## Folha acima do teto: coloca à venda quem custa muito para o que rende; em crise, libera.
static func _ai_cut_wages(world: GameWorld, c: Club) -> void:
	var bill := FinanceManager.wage_bill(world, c)
	if bill <= c.wage_budget * 1.05:
		return
	var squad := world.squad(c)
	# Pior custo-benefício primeiro: salário alto para o overall.
	squad.sort_custom(func(a, b): return a.wage / maxf(1.0, Valuation.base_wage(a.ovr_f - Valuation.shift)) > b.wage / maxf(1.0, Valuation.base_wage(b.ovr_f - Valuation.shift)))
	var listed := 0
	for p in squad:
		if listed >= 3:
			break
		if _family_count(world, c, p.position) > _family_min(p.position) and not p.transfer_listed:
			p.transfer_listed = true
			listed += 1
	if bill > c.wage_budget * 1.3 and c.player_ids.size() > int(DatabaseManager.squad_rules()["min_players"]) + 2:
		for p in squad:
			if _family_count(world, c, p.position) > _family_min(p.position) + 1 and p.contract_years_left(world.year) <= 1:
				release(world, p)
				break
