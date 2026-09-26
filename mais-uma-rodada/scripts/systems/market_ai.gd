class_name MarketAI
extends RefCounted
## IA do mercado entre clubes, inspirada no futebol real:
## - cada clube planeja a janela: quantos reforços busca e quem sobra no elenco;
## - o dinheiro manda: ligas ricas pagam ágio e tiram talentos das exportadoras
##   (América do Sul → Portugal/Holanda → grandes ligas); veteranos vão para Arábia, EUA,
##   Turquia ou voltam para casa (perfis em data/gameplay/market.json);
## - negociação de verdade entre clubes: proposta, contraproposta e recusa; clube grande não
##   vende titular para clube menor, pequeno não segura jogador que quer sair; multa rescisória
##   paga à vista;
## - disputa entre interessados (leilão, "chapéu"), trocas com dinheiro, % de revenda para o formador,
##   novelas que duram vários fins de semana e empréstimo com opção de compra;
## - quem vende um titular sai atrás de reposição (efeito dominó);
## - grandes emprestam jovens para ganhar minutos;
## - último fim de semana da janela: correria, ágio de pânico e vendedores mais duros.

const CFG_PATH := "res://data/gameplay/market.json"
const CANDIDATES := 40
const STATUS_ASK: Array[float] = [1.6, 1.25, 1.0, 0.85, 1.3] # estrela, titular, rotação, reserva, promessa
const OFFSEASON_ROUNDS := 2 # rodadas de mercado nas férias (antes do primeiro jogo)
const MAX_RUMORS_PER_TURN := 1
const MAX_TALKS := 40 # negociações em andamento de uma semana para outra
const MAX_PUSH := 2 # quantas vezes o comprador volta à mesa depois da primeira recusa

static var _cfg: Dictionary = {}


# ---------------------------------------------------------------------------
# Perfis de país e poder econômico
# ---------------------------------------------------------------------------

static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var data: Variant = DatabaseManager.read_json(CFG_PATH)
		_cfg = data if data is Dictionary else {"default": {}, "nations": {}}
	return _cfg


## Perfil de mercado do país (valores ausentes vêm do padrão).
static func profile(nation: String) -> Dictionary:
	var c := cfg()
	var out: Dictionary = (c.get("default", {}) as Dictionary).duplicate()
	var n: Dictionary = c.get("nations", {}).get(nation, {})
	for k in n:
		out[k] = n[k]
	return out


## Poder de compra do clube: escala salarial da liga × tamanho do clube.
## Referências: gigante inglês ≈ 1,8 · grande espanhol ≈ 1,3 · grande brasileiro ≈ 0,6 · argentino ≈ 0,4.
static func power(c: Club) -> float:
	return float(c.league_cfg().get("wage", 0.5)) * (0.7 + c.reputation / 100.0 * 0.6)


## Quanto o clube aceita pagar acima do valor de mercado (a "taxa da Premier League").
static func premium(c: Club) -> float:
	var pr: Variant = profile(c.nation).get("premium")
	if pr != null:
		return float(pr)
	return clampf(0.8 + float(c.league_cfg().get("wage", 0.5)) * 0.3, 0.82, 1.2)


# ---------------------------------------------------------------------------
# Entrada: um fim de semana de mercado
# ---------------------------------------------------------------------------

## Mercado da IA num fim de semana (janela aberta ou não). Retorna as Transfer feitas.
static func matchday(world: GameWorld) -> Array:
	var window := world.transfer_window_open()
	var index := TransferManager._build_index(world)
	var done: Array = []
	var st := _state(world, window)
	st["rumors"] = 0
	var deadline := window and _is_deadline(world)
	var summer := window and world.current_day() < 10
	if window:
		done.append_array(_resume_talks(world, st, deadline))
	var order := _ai_clubs(world)
	for c: Club in order:
		var rules := DatabaseManager.squad_rules()
		if c.player_ids.size() > int(rules["max_players"]) - 1:
			TransferManager._ai_release_weakest(world, c)
			continue
		var key := str(c.id)
		var left := int(st["left"].get(key, 0))
		var urgent := _has_urgent_need(world, c)
		var act := 0.0
		if not window:
			act = 0.1 if urgent else 0.0
		elif left > 0 or urgent:
			act = (0.5 if summer else 0.3) + minf(0.25, power(c) * 0.1)
			if deadline:
				act = minf(0.95, act + 0.3)
		if act <= 0.0 or world.rng.randf() >= act:
			continue
		var tries := 2 if summer and left >= 2 else 1
		for _k in tries:
			var t := _try_signing(world, c, index, st, deadline, not window)
			if t == null:
				continue
			done.append(t)
			if t.to_id == c.id:
				left -= 1
		st["left"][key] = left
	return done


## Mercado das férias: a maior parte dos negócios de meio de ano acontece antes da bola rolar.
## Só IA↔IA (as propostas pelo elenco do usuário chegam durante a janela, onde ele pode responder).
static func offseason(world: GameWorld) -> int:
	if not world.transfer_window_open():
		return 0
	var n := 0
	for _r in OFFSEASON_ROUNDS:
		n += matchday(world).size()
	return n


static func _ai_clubs(world: GameWorld) -> Array:
	var order: Array = []
	for c in world.clubs:
		if not world.is_user_club(c.id):
			order.append(c)
	RngUtil.shuffle(world.rng, order)
	return order


## Última data de liga antes de a janela fechar ("deadline day").
static func _is_deadline(world: GameWorld) -> bool:
	var end := world.window_end_day()
	for i in range(world.current_day() + 1, end + 1):
		if world.season.is_weekend(i):
			return false
	return true


# ---------------------------------------------------------------------------
# Planejamento da janela
# ---------------------------------------------------------------------------

## Estado do mercado da janela atual (plano de cada clube). Refeito quando uma janela nova abre.
static func _state(world: GameWorld, window: bool) -> Dictionary:
	var st: Dictionary = world.stats.get("mkt", {})
	if not window:
		if st.is_empty():
			st = {"w": -1, "left": {}}
			world.stats["mkt"] = st
		return st
	var wid := world.year * 100 + (0 if world.current_day() < 10 else 1)
	if int(st.get("w", -1)) != wid:
		st = {"w": wid, "left": {}, "talks": []}
		world.stats["mkt"] = st
		_plan_window(world, st, world.current_day() < 10)
	return st


static func _plan_window(world: GameWorld, st: Dictionary, summer: bool) -> void:
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		var needs := TransferManager.squad_needs(world, c)
		var pw := power(c)
		var n := 0
		if summer:
			# Grandes e ricos trazem 3 a 6 reforços; pequenos, 1 a 3. Carências somam.
			n = 1 + int(round(minf(3.0, pw * 1.6))) + mini(2, needs.size())
			if c.transfer_budget <= 0 and needs.is_empty():
				n = 1
			n += world.rng.randi_range(-1, 1) + ClubDNA.window_delta(c)
		else:
			# Janela de inverno é de remendos: só quem tem carência ou dinheiro sobrando.
			n = mini(2, needs.size()) if not needs.is_empty() else (1 if world.rng.randf() < 0.3 else 0)
		st["left"][str(c.id)] = clampi(n, 0, 7)
		_plan_sales(world, c, summer)
		if summer or world.rng.randf() < 0.35:
			_plan_loans(world, c)


## Anuncia quem sobra: excesso na posição, insatisfeitos sem espaço e veteranos caros demais.
static func _plan_sales(world: GameWorld, c: Club, summer: bool) -> void:
	var squad := world.squad(c)
	var level := PlayerGenerator.club_level(c)
	var ages: Array = c.arch().get("target_age", [20, 30])
	var fam_n: Dictionary = {}
	for p: Player in squad:
		var f := TransferManager._family_of(p.position)
		fam_n[f] = int(fam_n.get(f, 0)) + 1
		if summer and p.loan.is_empty():
			p.transfer_listed = false
	var listed := 0
	squad.sort_custom(func(a, b): return a.ovr_f < b.ovr_f)
	for p: Player in squad:
		if listed >= 3 or not p.loan.is_empty() or p.transfer_listed:
			continue
		var f := TransferManager._family_of(p.position)
		var surplus := int(fam_n.get(f, 0)) > int(TransferManager.FAMILIES[f][1]) + 2
		var age := p.age(world.year)
		var why := false
		if surplus and p.ovr_f < level - 4.0 and age >= 22:
			why = true # sobra na posição e não joga
		elif p.morale < 35.0 and p.squad_status >= Player.STATUS_ROTATION:
			why = true # insatisfeito, quer sair
		elif age > int(ages[1]) + 1 and p.squad_status >= Player.STATUS_ROTATION and p.wage > Valuation.base_wage(p.ovr_f - Valuation.shift) * 1.2:
			why = true # veterano caro para o que joga
		if why and int(fam_n.get(f, 0)) > int(TransferManager.FAMILIES[f][1]):
			p.transfer_listed = true
			fam_n[f] = int(fam_n[f]) - 1
			listed += 1
	if FinanceManager.in_trouble(c) and world.rng.randf() < 0.6:
		TransferManager._ai_list_for_sale(world, c)


## Clubes fortes emprestam promessas sem espaço para times onde elas vão jogar.
static func _plan_loans(world: GameWorld, owner: Club) -> void:
	var level := PlayerGenerator.club_level(owner)
	if level < 64.0:
		return
	var rules := DatabaseManager.squad_rules()
	var sent := 0
	for p: Player in world.squad(owner):
		if sent >= 2 or owner.player_ids.size() <= int(rules["min_players"]) + 4:
			return
		if not p.loan.is_empty() or p.transfer_listed or p.age(world.year) > 21:
			continue
		if p.potential < p.overall + 5 or p.ovr_f >= level - 3.0 or p.squad_status <= Player.STATUS_ROTATION:
			continue
		if TransferManager._family_count(world, owner, p.position) <= TransferManager._family_min(p.position) + 1:
			continue
		if world.rng.randf() > 0.45:
			continue
		var to := _loan_destination(world, owner, p)
		if to == null:
			continue
		TransferManager._move_loan(world, p, owner, to)
		TransferManager._set_status_on_arrival(world, p, to)
		world.stat_add("loans")
		sent += 1


static func _loan_destination(world: GameWorld, owner: Club, p: Player) -> Club:
	var best: Club = null
	var best_v := -1e9
	var max_players := int(DatabaseManager.squad_rules()["max_players"])
	for _k in 30:
		var c: Club = world.clubs[world.rng.randi_range(0, world.clubs.size() - 1)]
		if c.id == owner.id or world.is_user_club(c.id) or c.player_ids.size() >= max_players - 2 or c.is_rival(owner.id):
			continue
		if not ClubPolicy.eligible(world, c, p):
			continue
		var lvl := PlayerGenerator.club_level(c)
		if p.ovr_f < lvl - 3.0 or p.ovr_f > lvl + 6.0:
			continue
		var v := -absf(p.ovr_f - lvl - 1.0) + world.rng.randf_range(0.0, 3.0)
		if c.nation == owner.nation:
			v += 3.0 # empréstimo dentro do país é o mais comum
		elif power(c) < power(owner):
			v += 1.0 # clube-satélite numa liga menor
		if v > best_v:
			best_v = v
			best = c
	return best


# ---------------------------------------------------------------------------
# Uma tentativa de contratação
# ---------------------------------------------------------------------------

static func _has_urgent_need(world: GameWorld, c: Club) -> bool:
	var needs := TransferManager.squad_needs(world, c)
	return not needs.is_empty() and int(needs[0]["count"]) < int(TransferManager.FAMILIES[int(needs[0]["fam"])][1])


## O que o clube vai buscar: {fam, pos, min_rating, urgency}.
static func _pick_need(world: GameWorld, c: Club, free_only: bool) -> Dictionary:
	var level := PlayerGenerator.club_level(c)
	var needs := TransferManager.squad_needs(world, c)
	if not needs.is_empty() and int(needs[0]["count"]) < int(TransferManager.FAMILIES[int(needs[0]["fam"])][1]):
		return {"fam": int(needs[0]["fam"]), "pos": -1, "min_rating": level - 8.0, "urgency": float(needs[0]["urgency"])}
	if free_only:
		return {}
	var rules := DatabaseManager.squad_rules()
	if c.player_ids.size() >= int(rules["max_players"]) - 2:
		return {}
	var arch := c.arch()
	# DNA: clubes de formação (e os que usam muito a base) apostam em promessas; os de estrelas
	# miram alto; os outros reforçam o titular mais fraco.
	var rec := ClubDNA.rec(c)
	var young_p := 0.4 if float(arch.get("potential_weight", 0.4)) >= 0.6 else 0.0
	if rec == "formacao":
		young_p = maxf(young_p, 0.5)
	elif rec == "estrelas" or rec == "veteranos":
		young_p *= 0.3
	if young_p > 0.0 and world.rng.randf() < young_p:
		var fam := world.rng.randi_range(0, TransferManager.FAMILIES.size() - 1)
		return {"fam": fam, "pos": -1, "min_rating": level - 4.0, "urgency": 0.5, "young": true}
	var weak := TransferManager._weakest_starter(world, c)
	if not weak.is_empty() and float(weak["rating"]) < level + 5.0 and world.rng.randf() < 0.75:
		var wfam := TransferManager._family_of(int(weak["pos"]))
		# Garoto da base pronto para a vaga: o clube que usa a base não compra por cima dele.
		if ClubDNA.kid_blocks(world, c, wfam, level):
			return {}
		var bar := float(weak["rating"]) + (4.0 if rec == "estrelas" else 2.0)
		return {"fam": wfam, "pos": int(weak["pos"]), "min_rating": bar, "urgency": 1.0}
	if not needs.is_empty():
		return {"fam": int(needs[0]["fam"]), "pos": -1, "min_rating": float(needs[0]["best"]) + 1.0, "urgency": float(needs[0]["urgency"])}
	return {}


static func _try_signing(world: GameWorld, c: Club, index: Dictionary, st: Dictionary, deadline: bool, free_only: bool) -> Transfer:
	var need := _pick_need(world, c, free_only)
	var mismanaged := world.rng.randf() < float(c.arch().get("mismanagement", 0.0)) * 0.2
	if need.is_empty():
		return null
	var fam: int = need["fam"]
	var min_rating: float = need["min_rating"]
	var target_pos: int = need["pos"]
	var urgency: float = need["urgency"]
	var budget := c.transfer_budget
	var wage_room := c.wage_budget - FinanceManager.wage_bill(world, c)
	if wage_room <= 0 and urgency < 3.0 and not mismanaged:
		return null
	var prof := profile(c.nation)
	var arch := c.arch()
	var ages: Array = arch.get("target_age", [20, 30])
	var pages: Variant = prof.get("age")
	var ra := world.rng.randf()
	if ra < 0.6:
		ages = ClubDNA.ages(c) # a filosofia de elenco manda
	elif pages is Array and ra < 0.85:
		ages = pages
	if need.get("young", false):
		ages = [17, 22]
	var pot_w := float(arch.get("potential_weight", 0.4))
	if ClubDNA.rec(c) == "formacao":
		pot_w = maxf(pot_w, 0.75)
	var sources: Array = prof.get("sources", [])
	var my_power := power(c)
	var level := PlayerGenerator.club_level(c)
	var fam_surplus := TransferManager._family_count(world, c, int(TransferManager.FAMILIES[fam][0][0])) - int(TransferManager.FAMILIES[fam][1]) - 1
	var best: Player = null
	var best_score := -1e9
	for _k in CANDIDATES:
		var p := _draw(world, index, c, fam, min_rating, prof)
		if p == null or p.club_id == c.id or p.retiring or p.injury_weeks > 4:
			continue
		if not ClubPolicy.ai_wants(world, c, p):
			continue # filosofia do clube (Athletic só bascos, Red Bull só jovens...)
		if p.club_id >= 0:
			if free_only or world.is_user_club(p.club_id) or p.joined_year == world.year:
				continue # recém-contratado não é revendido na mesma temporada
		var age := p.age(world.year)
		var rating := p.rating_at(target_pos) if target_pos >= 0 else p.ovr_f
		var eff := rating + (float(p.potential) - rating) * pot_w * (0.6 if age <= 23 else 0.0)
		eff += ClubPolicy.preference_bonus(world, c, p)
		if eff < min_rating and not mismanaged:
			continue
		var price := 0.0
		var seller: Club = null
		if p.club_id >= 0:
			seller = world.club(p.club_id)
			price = float(p.value) * _seller_mult(world, seller, p, c, false)
			if price > budget * (1.3 if mismanaged else 1.0) and not _loanable(world, p, c):
				continue
			# Titular de clube muito mais rico não sai para um clube pequeno.
			if power(seller) > my_power * 1.5 and p.squad_status <= Player.STATUS_STARTER and age < 30:
				continue
		var wage := float(Valuation.wage_demand(p, c, world.year)) * float(prof.get("wage_boost", 1.0))
		if wage > maxf(float(wage_room), 0.0) * (1.5 if mismanaged else 1.1) and not (urgency >= 3.0 and wage <= c.wage_budget * 0.08):
			continue
		var score := eff - min_rating
		if age < int(ages[0]) - 1 or age > int(ages[1]) + 1:
			score -= 3.0 + absf(age - clampi(age, int(ages[0]), int(ages[1]))) * 1.5
		score -= price / maxf(50000.0, float(budget) + 1.0) * 2.5
		if p.transfer_listed:
			score += 1.5
		if p.club_id < 0:
			score += 1.0 # de graça
		elif p.contract_years_left(world.year) <= 1:
			score += 1.0 # fim de contrato: sai barato
		if seller != null and sources.has(seller.nation):
			score += 1.5 # rota conhecida de garimpo
		if p.nationality == c.nation and age >= 29:
			score += 1.5 # repatriação
		if seller != null and (seller.is_rival(c.id) or c.is_rival(seller.id)):
			score -= 4.0
		score += ClubDNA.candidate_bonus(world, c, p, rating, level, price, float(budget), maxi(0, fam_surplus))
		if mismanaged:
			score = world.rng.randf_range(-5.0, 5.0) + (rating - min_rating) * 0.3
		if score > best_score:
			best_score = score
			best = p
	if best == null:
		return null
	var wage2 := Valuation.round_wage(TransferManager.wage_ask(world, best, c) * float(prof.get("wage_boost", 1.0)))
	var years := TransferManager.preferred_years(world, best)
	if best.club_id < 0:
		if world.rng.randf() > player_interest(world, best, c):
			return null
		return TransferManager.complete_transfer(world, best, c, 0, wage2, years)
	return _close_deal(world, st, c, best, urgency, deadline, mismanaged, 0)


## Fecha (ou não) a contratação: disputa com outros interessados, negociação, troca, % de revenda,
## novela para a semana seguinte ou empréstimo com opção de compra.
static func _close_deal(world: GameWorld, st: Dictionary, c: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool, push: int) -> Transfer:
	var seller := world.club(p.club_id)
	var buyer := c
	var deal := negotiate(world, c, p, urgency, deadline, mismanaged, push)
	if not deal.has("fee"):
		var gap := float(deal.get("gap", 0.0))
		if gap >= 0.8 and push < MAX_PUSH and _open_talk(world, st, c, p, urgency, push + 1):
			return null
		if _loan_with_option(world, c, p):
			return null
		_rumor_failed(world, st, c, p, seller)
		return null
	# Jogador cobiçado: outros clubes entram na disputa (multa paga não tem leilão).
	if not deal.get("clause", false):
		var top := max_bid(world, c, p, urgency, deadline, mismanaged, push)
		var auc := _auction(world, c, p, int(deal["fee"]), top, deadline)
		if not auc.is_empty():
			buyer = auc["club"]
			deal["fee"] = auc["fee"]
			if buyer != c:
				_news_hijack(world, buyer, c, p, int(deal["fee"]))
	if world.rng.randf() > player_interest(world, p, buyer):
		return null # clubes se acertaram, mas o jogador não quis
	var was_key := p.squad_status <= Player.STATUS_STARTER
	var fee: int = deal["fee"]
	var years := TransferManager.preferred_years(world, p)
	var wage := Valuation.round_wage(TransferManager.wage_ask(world, p, buyer) * float(profile(buyer.nation).get("wage_boost", 1.0)))
	if deal.get("clause", false):
		_news_clause(world, buyer, p, seller, fee)
	# Troca: parte do pagamento vai em jogador que o vendedor precisa.
	var piece: Player = null
	if world.rng.randf() < 0.45:
		piece = _swap_piece(world, buyer, seller, p, fee)
	var t := TransferManager.complete_transfer(world, p, buyer, fee, wage, years)
	var so := float(deal.get("sell_on", 0.0))
	if so > 0.0:
		p.clauses = {"so": seller.id, "pct": so}
	if piece != null:
		var credit := Valuation.round_value(piece.value * 0.9)
		TransferManager.complete_transfer(world, piece, seller, credit, Valuation.wage_demand(piece, seller, world.year), TransferManager.preferred_years(world, piece))
		world.stat_add("swaps")
		_news_swap(world, buyer, seller, p, piece, fee - credit)
	if buyer != c:
		var bk := str(buyer.id)
		st["left"][bk] = int(st["left"].get(bk, 0)) - 1
	# Efeito dominó: quem perdeu um titular vai atrás de reposição.
	if was_key and not world.is_user_club(seller.id):
		var k := str(seller.id)
		st["left"][k] = int(st["left"].get(k, 0)) + 1
	_news_record(world, t)
	return t


## Leilão: outros clubes com dinheiro e interesse entram na disputa. Quem paga mais leva.
## Retorna {club, fee} com o vencedor e o preço final, ou {} se ninguém mais apareceu.
static func _auction(world: GameWorld, buyer: Club, p: Player, fee: int, buyer_top: float, deadline: bool) -> Dictionary:
	if p.squad_status > Player.STATUS_STARTER and p.potential < p.overall + 6:
		return {}
	var seller := world.club(p.club_id)
	var r := Valuation.perceived_rating(p, world.year) + Valuation.shift
	var max_players := int(DatabaseManager.squad_rules()["max_players"])
	var rival: Club = null
	var rival_top := 0.0
	for _k in 12:
		var c: Club = world.clubs[world.rng.randi_range(0, world.clubs.size() - 1)]
		if c.id == buyer.id or c.id == seller.id or world.is_user_club(c.id) or c.transfer_budget <= fee or c.player_ids.size() >= max_players - 1:
			continue
		if not ClubPolicy.ai_wants(world, c, p):
			continue
		var lvl := PlayerGenerator.club_level(c)
		if r < lvl - 3.0 or r > lvl + 8.0 or world.rng.randf() > 0.12:
			continue
		var top := max_bid(world, c, p, 1.0, deadline) * world.rng.randf_range(0.85, 1.0)
		if top > rival_top:
			rival_top = top
			rival = c
	if rival == null or rival_top <= fee:
		return {}
	world.stat_add("auctions")
	if buyer_top >= rival_top * 1.03:
		return {"club": buyer, "fee": Valuation.round_value(minf(buyer_top, rival_top * 1.03))}
	return {"club": rival, "fee": Valuation.round_value(minf(rival_top, maxf(float(fee), buyer_top) * 1.03))}


## Jogador do comprador que entra no negócio: sobra no elenco dele e tapa uma carência do vendedor.
static func _swap_piece(world: GameWorld, buyer: Club, seller: Club, target: Player, fee: int) -> Player:
	if world.is_user_club(seller.id) or world.is_user_club(buyer.id):
		return null
	var needs := TransferManager.squad_needs(world, seller)
	if needs.is_empty():
		return null
	var fams := {}
	for n in needs:
		fams[int(n["fam"])] = true
	var lvl := PlayerGenerator.club_level(seller)
	for q: Player in world.squad(buyer):
		if q == target or not q.loan.is_empty() or q.joined_year == world.year or q.injury_weeks > 0 or q.retiring:
			continue
		if not ClubPolicy.eligible(world, seller, q):
			continue
		if not q.transfer_listed and q.squad_status < Player.STATUS_BACKUP:
			continue
		var f := TransferManager._family_of(q.position)
		if not fams.has(f) or q.ovr_f < lvl - 7.0 or q.value * 0.9 > fee * 0.8:
			continue
		if TransferManager._family_count(world, buyer, q.position) <= TransferManager._family_min(q.position) + 1:
			continue
		if world.rng.randf() > player_interest(world, q, seller):
			continue
		return q
	return null


## Novela: a proposta ficou perto do pedido; o comprador volta na semana seguinte com mais dinheiro.
static func _open_talk(world: GameWorld, st: Dictionary, c: Club, p: Player, urgency: float, push: int) -> bool:
	var talks: Array = st.get("talks", [])
	if talks.size() >= MAX_TALKS or not _is_open_window_ahead(world):
		return false
	talks.append({"b": c.id, "p": p.id, "s": p.club_id, "n": push, "u": urgency})
	st["talks"] = talks
	if push == 1 and _notable(world, c, world.club(p.club_id), p.value) and int(st.get("rumors", 0)) < MAX_RUMORS_PER_TURN:
		st["rumors"] = int(st.get("rumors", 0)) + 1
		var seller := world.club(p.club_id)
		NewsManager.post_raw(world, "Novela: %s insiste em %s" % [c.short_name, p.display_name()],
			"O %s não chegou ao valor pedido pelo %s, mas as conversas continuam. A expectativa é de uma proposta melhor nos próximos dias." % [c.short_name, seller.short_name],
			c.id, p.id, NewsEvent.IMP_LOW, "transferencia")
	return true


## Ainda haverá outra data de mercado nesta janela (para a novela continuar)?
static func _is_open_window_ahead(world: GameWorld) -> bool:
	if world.season == null or world.transfer_window_open() == false:
		return false
	return not _is_deadline(world)


## Retoma as negociações em andamento: o comprador volta com proposta maior; a pressão pesa no vendedor.
static func _resume_talks(world: GameWorld, st: Dictionary, deadline: bool) -> Array:
	var talks: Array = st.get("talks", [])
	st["talks"] = []
	var done: Array = []
	for tk in talks:
		var c := world.club(int(tk["b"]))
		var p := world.player(int(tk["p"]))
		if c == null or p == null or p.club_id != int(tk["s"]) or p.club_id < 0 or world.is_user_club(p.club_id) or not p.loan.is_empty():
			continue
		if c.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]) - 1:
			continue
		# Quem quer sair se faz notar: treina mal, dá entrevista... e o vendedor cede um pouco.
		if player_interest(world, p, c) >= 0.6:
			p.morale = clampf(p.morale - 3.0, 0.0, 100.0)
		world.stat_add("talks")
		var t := _close_deal(world, st, c, p, float(tk["u"]), deadline, false, int(tk["n"]))
		if t != null:
			done.append(t)
			if t.to_id == c.id:
				var k := str(c.id)
				st["left"][k] = int(st["left"].get(k, 0)) - 1
	return done


## Pode vir emprestado com opção de compra (não é peça-chave do dono)?
static func _loanable(world: GameWorld, p: Player, c: Club) -> bool:
	if p.club_id < 0 or not p.loan.is_empty() or p.squad_status <= Player.STATUS_STARTER or p.age(world.year) < 20:
		return false
	return TransferManager.loan_fee(p) <= c.transfer_budget and not world.is_user_club(p.club_id)


## Sem dinheiro para a compra agora: empréstimo até o fim da temporada com opção de compra.
static func _loan_with_option(world: GameWorld, c: Club, p: Player) -> bool:
	if not _loanable(world, p, c) or world.rng.randf() > 0.6:
		return false
	var owner := world.club(p.club_id)
	if owner.is_rival(c.id) or c.is_rival(owner.id) or c.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]) - 1:
		return false
	if TransferManager._family_count(world, owner, p.position) <= TransferManager._family_min(p.position) + 1:
		return false
	if world.rng.randf() > player_interest(world, p, c):
		return false
	var fee := TransferManager.loan_fee(p)
	c.add_ledger("compras", -fee)
	c.transfer_budget = maxi(0, c.transfer_budget - fee)
	owner.add_ledger("vendas", fee)
	TransferManager._move_loan(world, p, owner, c)
	p.loan["opt"] = Valuation.round_value(p.value * float(owner.arch().get("sell_mult", 1.0)) * world.rng.randf_range(0.9, 1.1))
	TransferManager._set_status_on_arrival(world, p, c)
	world.stat_add("loans")
	world.stat_add("loans_opt")
	return true


## Fim de temporada: quem veio com opção de compra e se firmou é comprado em definitivo.
static func exercise_loan_options(world: GameWorld) -> void:
	for p: Player in world.players.values():
		if not p.loan.has("opt") or int(p.loan.get("until", 0)) > world.year:
			continue
		var owner := world.club(int(p.loan["from"]))
		var borrower := world.club(p.club_id)
		if owner == null or borrower == null or world.is_user_club(owner.id) or world.is_user_club(borrower.id):
			continue
		var opt := int(p.loan["opt"])
		var level := PlayerGenerator.club_level(borrower)
		var worth := p.squad_status <= Player.STATUS_ROTATION or p.ovr_f >= level - 1.0
		if not worth or maxi(borrower.transfer_budget, borrower.balance / 3) < opt or p.age(world.year) >= 33 or world.rng.randf() > 0.8:
			continue
		borrower.player_ids.erase(p.id)
		owner.player_ids.append(p.id)
		p.club_id = owner.id
		p.loan = {}
		TransferManager.complete_transfer(world, p, borrower, opt, Valuation.wage_demand(p, borrower, world.year), TransferManager.preferred_years(world, p))
		world.stat_add("options_exercised")


## Sorteia um candidato: próprio país, rotas de garimpo do país ou o mercado mundial por nível.
static func _draw(world: GameWorld, index: Dictionary, c: Club, fam: int, min_rating: float, prof: Dictionary) -> Player:
	var r := world.rng.randf()
	var dom := ClubDNA.home_share(c, float(prof.get("domestic", 0.6))) # alcance do mercado (DNA)
	var nat := ""
	var only := String(ClubPolicy.of(c).get("only", ""))
	if only != "":
		nat = ClubPolicy.rule_nation(only) # só procura onde a regra deixa
	elif r < dom:
		nat = c.nation
	else:
		nat = ClubDNA.away_nation(world.rng, c, prof.get("sources", []))
	if nat != "":
		var arr: Array = index["nat"].get(nat, [])
		if not arr.is_empty() and not arr[fam].is_empty():
			return arr[fam][world.rng.randi_range(0, arr[fam].size() - 1)]
	var bands: Dictionary = index["band"][fam]
	var b0 := int(min_rating / TransferManager.BAND)
	for _t in 3:
		var b := b0 + world.rng.randi_range(0, 2)
		if bands.has(b) and not bands[b].is_empty():
			var arr2: Array = bands[b]
			return arr2[world.rng.randi_range(0, arr2.size() - 1)]
	return null


## Vontade do jogador de ir (0..1): a base do jogo + dinheiro do Golfo/EUA para veteranos + voltar para casa.
static func player_interest(world: GameWorld, p: Player, buyer: Club) -> float:
	var v := TransferManager.interest(world, p, buyer)
	var age := p.age(world.year)
	var prof := profile(buyer.nation)
	if age >= 29:
		v += float(prof.get("vet_pull", 0.0))
		if buyer.nation == p.nationality:
			v += 0.12 # fim de carreira em casa
	# Jovem de liga exportadora sonha com a liga rica.
	if age <= 24 and p.club_id >= 0 and power(buyer) > power(world.club(p.club_id)) * 1.6:
		v += 0.12
	return clampf(v, 0.05, 0.95)


# ---------------------------------------------------------------------------
# Negociação clube × clube
# ---------------------------------------------------------------------------

## Multiplicador (sobre o valor de mercado) do mínimo que o vendedor aceita.
static func _seller_mult(world: GameWorld, seller: Club, p: Player, buyer: Club, deadline: bool) -> float:
	var m := float(seller.arch().get("sell_mult", 1.0)) * STATUS_ASK[clampi(p.squad_status, 0, 4)]
	if not world.is_user_club(seller.id):
		m *= ClubDNA.sell_mult(world, seller, p) # venda de jovens, moneyball, ambição
	var years := p.contract_years_left(world.year)
	if years <= 0:
		m *= 0.6 # ou vende agora, ou perde de graça
	elif years == 1:
		m *= 0.8
	elif years >= 4:
		m *= 1.08
	if p.transfer_listed:
		m *= 0.85
	if FinanceManager.in_trouble(seller):
		m *= 0.8
	if TransferManager._family_count(world, seller, p.position) <= TransferManager._family_min(p.position):
		m *= 1.6 # sem reposição na posição
	if seller.is_rival(buyer.id) or buyer.is_rival(seller.id):
		m *= 1.5
	if deadline and p.squad_status <= Player.STATUS_STARTER:
		m *= 1.2 # sem tempo para repor
	var gap := power(buyer) / maxf(0.05, power(seller))
	if gap >= 1.6:
		m *= 0.92 # clube menor não segura quem recebe proposta de um gigante
	elif gap <= 0.7 and p.squad_status <= Player.STATUS_STARTER:
		m *= 1.35 # clube maior não precisa vender
	if p.squad_status == Player.STATUS_STAR and gap < 1.2:
		m *= 1.4 # inegociável, salvo loucura
	return m


## Teto que o comprador paga.
static func max_bid(world: GameWorld, buyer: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool = false, push: int = 0) -> float:
	var m := premium(buyer) * (1.0 + clampf(urgency, 0.0, 6.0) * 0.03) * (1.0 + 0.07 * push)
	var level := PlayerGenerator.club_level(buyer)
	if p.squad_status == Player.STATUS_STAR or p.ovr_f >= level + 4.0:
		m *= 1.0 + float(buyer.arch().get("star_pref", 0.5)) * 0.25
	if p.age(world.year) <= 23 and p.potential >= p.overall + 6:
		m *= 1.1 # ágio pela promessa
	if deadline:
		m *= 1.1
	if mismanaged:
		m *= 1.25
	if not world.is_user_club(buyer.id):
		m *= ClubDNA.bid_mult(buyer, p, level)
	return minf(float(p.value) * m * 1.15, float(buyer.transfer_budget) * (1.3 if mismanaged else 1.0))


## Proposta, contraproposta e desfecho. Retorna {fee, clause?, sell_on?} quando fecha, ou {gap} quando
## trava (gap = quanto o teto do comprador cobre do pedido; perto de 1 = vale insistir).
## push: quantas vezes o comprador já voltou à mesa (cada volta ele sobe o teto e o vendedor cede um pouco).
static func negotiate(world: GameWorld, buyer: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool = false, push: int = 0) -> Dictionary:
	var seller := world.club(p.club_id)
	var reserve := float(p.value) * _seller_mult(world, seller, p, buyer, deadline) * world.rng.randf_range(0.95, 1.08)
	reserve *= 1.0 - 0.05 * push
	var top := max_bid(world, buyer, p, urgency, deadline, mismanaged, push)
	var clause := _clause_of(seller, p)
	if top <= 0.0:
		return {"gap": 0.0}
	# Formador/vendedor que solta uma promessa para clube mais rico guarda % da revenda e cobra menos à vista.
	var sell_on := 0.0
	if p.age(world.year) <= 23 and (float(seller.arch().get("potential_weight", 0.4)) >= 0.6 or power(buyer) >= power(seller) * 1.6):
		sell_on = [0.1, 0.15, 0.2][world.rng.randi_range(0, 2)]
		reserve *= 1.0 - sell_on * 0.5
	var bid := minf(top, float(p.value) * premium(buyer) * world.rng.randf_range(0.72, 0.95) * (1.0 + 0.05 * push))
	for _round in 3:
		if bid >= reserve:
			return _deal(bid, sell_on)
		var counter := maxf(reserve * world.rng.randf_range(1.0, 1.1), bid * 1.05)
		if counter <= top:
			if world.rng.randf() < 0.55:
				return _deal(counter, sell_on)
			bid = (bid + counter) * 0.5 # "racha a diferença"
			if bid >= reserve * 0.97 and world.rng.randf() < 0.6:
				return _deal(bid, sell_on)
		else:
			bid = minf(top, (bid + counter) * 0.5)
	# Vendedor não cedeu: se a multa couber no bolso e o jogador quiser, deposita e leva.
	if clause > 0 and float(clause) <= float(buyer.transfer_budget) and float(clause) <= top * 1.25 and power(buyer) >= power(seller):
		return {"fee": clause, "clause": true}
	return {"gap": top / maxf(1.0, reserve)}


static func _deal(fee: float, sell_on: float) -> Dictionary:
	var d := {"fee": Valuation.round_value(fee)}
	if sell_on > 0.0:
		d["sell_on"] = sell_on
	return d


## Multa rescisória: a do contrato ou, em países que usam (Espanha, Portugal), a implícita dos titulares.
static func _clause_of(seller: Club, p: Player) -> int:
	if p.release_clause > 0:
		return p.release_clause
	var mult := float(profile(seller.nation).get("clause", 0.0))
	if mult <= 0.0 or p.squad_status > Player.STATUS_STARTER:
		return 0
	return Valuation.round_value(p.value * mult)


# ---------------------------------------------------------------------------
# Propostas pelos jogadores do usuário
# ---------------------------------------------------------------------------

## Clube que faria proposta pelo jogador: precisa da posição, tem dinheiro e o jogador toparia.
static func find_buyer_for(world: GameWorld, p: Player) -> Club:
	var best: Club = null
	var best_v := -1e9
	var owner := world.club(p.club_id)
	# Olheiros avaliam jovens pelo que podem virar.
	var r := Valuation.perceived_rating(p, world.year) + Valuation.shift
	for _k in 40:
		var c: Club = world.clubs[world.rng.randi_range(0, world.clubs.size() - 1)]
		if world.is_user_club(c.id) or c.transfer_budget < p.value * 0.75:
			continue
		if not ClubPolicy.ai_wants(world, c, p):
			continue
		var level := PlayerGenerator.club_level(c)
		if r < level - 3.0 or r > level + 12.0:
			continue
		var v := c.reputation * 0.3 - absf(r - level - 2.0) * 1.5 + world.rng.randf_range(0.0, 8.0)
		v += 6.0 * clampf(power(c) / maxf(0.05, power(owner)) - 1.0, -1.0, 2.0) # quem tem mais dinheiro vem buscar
		var fam := TransferManager._family_of(p.position)
		for n in TransferManager.squad_needs(world, c):
			if int(n["fam"]) == fam:
				v += 4.0
				break
		if owner.is_rival(c.id) or c.is_rival(owner.id):
			v -= 12.0
		if v > best_v:
			best_v = v
			best = c
	if best == null or player_interest(world, p, best) < 0.3:
		return null
	return best


## Chance extra de um jogador do usuário atrair propostas: promessas e clubes de ligas
## exportadoras (vitrine) chamam muito mais atenção; no último fim de semana, mais ainda.
static func extra_offer_chance(world: GameWorld, p: Player) -> float:
	var add := 0.0
	if p.age(world.year) <= 23 and p.potential >= p.overall + 5 and p.ovr_f >= PlayerGenerator.club_level(world.club(p.club_id)) - 6.0:
		add += 0.03
	if p.squad_status <= Player.STATUS_STARTER:
		add += 0.01
	if power(world.club(p.club_id)) < 0.7:
		add += 0.02
	if _is_deadline(world):
		add *= 1.5
	return add


## Proposta inicial e teto do comprador por um jogador do usuário: [fee, max_fee].
static func bids_for_user_player(world: GameWorld, buyer: Club, p: Player) -> Array:
	var deadline := _is_deadline(world)
	var top := max_bid(world, buyer, p, 1.0, deadline)
	var years := p.contract_years_left(world.year)
	if years <= 0:
		top *= 0.6
	elif years == 1:
		top *= 0.8
	var open := top * world.rng.randf_range(0.72, 0.9)
	if p.transfer_listed and p.asking_price > 0:
		open = minf(top, maxf(open, p.asking_price * world.rng.randf_range(0.8, 1.0)))
	return [Valuation.round_value(open), Valuation.round_value(maxf(open, top))]


# ---------------------------------------------------------------------------
# Notícias do mercado
# ---------------------------------------------------------------------------

static func _notable(world: GameWorld, a: Club, b: Club, fee: float) -> bool:
	if not world.has_user():
		return false
	var user := world.user_club()
	var in_div := (a != null and a.league_id == user.league_id) or (b != null and b.league_id == user.league_id)
	return fee >= 40_000_000 or (in_div and fee >= Valuation.market_value_of_rating(PlayerGenerator.league_level(user)))


static func _rumor_failed(world: GameWorld, st: Dictionary, buyer: Club, p: Player, seller: Club) -> void:
	if int(st.get("rumors", 0)) >= MAX_RUMORS_PER_TURN or not _notable(world, buyer, seller, p.value):
		return
	st["rumors"] = int(st.get("rumors", 0)) + 1
	NewsManager.post_raw(world, "%s tenta %s, mas %s não libera" % [buyer.short_name, p.display_name(), seller.short_name],
		"O %s fez proposta por %s, mas o %s recusou e a negociação travou. O mercado segue de olho." % [buyer.short_name, p.display_name(), seller.short_name],
		buyer.id, p.id, NewsEvent.IMP_LOW, "transferencia")


static func _news_clause(world: GameWorld, buyer: Club, p: Player, seller: Club, fee: int) -> void:
	if not _notable(world, buyer, seller, fee):
		return
	NewsManager.post_raw(world, "%s paga a multa e leva %s" % [buyer.short_name, p.display_name()],
		"Sem acordo com o %s, o %s depositou os %s da multa rescisória de %s." % [seller.short_name, buyer.short_name, Fmt.money(fee), p.display_name()],
		buyer.id, p.id, NewsEvent.IMP_HIGH, "transferencia")


static func _news_record(world: GameWorld, t: Transfer) -> void:
	if not world.stats.has("record_fee"):
		# Referência inicial: o recorde "histórico" do mundo, acima do craque mais caro de hoje.
		world.stats["record_fee"] = Valuation.round_value(Valuation.market_value_of_rating(90.0) * 1.6)
	var rec := int(world.stats["record_fee"])
	if t.fee <= rec:
		return
	world.stats["record_fee"] = t.fee
	if not world.has_user():
		return
	var to := world.club(t.to_id)
	var from := world.club(t.from_id)
	NewsManager.post_raw(world, "Recorde mundial: %s vai para o %s por %s" % [t.player_name, to.short_name, Fmt.money(t.fee)],
		"É a transferência mais cara da história. O %s pagou %s ao %s por %s, de %d anos." % [to.short_name, Fmt.money(t.fee), from.short_name if from != null else "", t.player_name, t.age],
		t.to_id, t.player_id, NewsEvent.IMP_HEADLINE, "transferencia")


static func _news_hijack(world: GameWorld, winner: Club, loser: Club, p: Player, fee: int) -> void:
	if not _notable(world, winner, loser, fee):
		return
	NewsManager.post_raw(world, "Chapéu! %s fura o %s e fica com %s" % [winner.short_name, loser.short_name, p.display_name()],
		"O %s parecia perto de fechar, mas o %s entrou na disputa, cobriu a oferta e levou %s por %s." % [loser.short_name, winner.short_name, p.display_name(), Fmt.money(fee)],
		winner.id, p.id, NewsEvent.IMP_NORMAL, "transferencia")


static func _news_swap(world: GameWorld, buyer: Club, seller: Club, p: Player, piece: Player, cash: int) -> void:
	if not _notable(world, buyer, seller, p.value):
		return
	NewsManager.post_raw(world, "Troca: %s vai para o %s e %s faz o caminho inverso" % [p.display_name(), buyer.short_name, piece.display_name()],
		"O %s fechou a contratação de %s colocando %s no negócio, mais %s em dinheiro." % [buyer.short_name, p.display_name(), piece.display_name(), Fmt.money(maxi(0, cash))],
		buyer.id, p.id, NewsEvent.IMP_NORMAL, "transferencia")
