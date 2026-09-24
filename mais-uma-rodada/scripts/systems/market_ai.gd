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
## - quem vende um titular sai atrás de reposição (efeito dominó);
## - grandes emprestam jovens para ganhar minutos;
## - último fim de semana da janela: correria, ágio de pânico e vendedores mais duros.

const CFG_PATH := "res://data/gameplay/market.json"
const CANDIDATES := 40
const STATUS_ASK: Array[float] = [1.6, 1.25, 1.0, 0.85, 1.3] # estrela, titular, rotação, reserva, promessa
const OFFSEASON_ROUNDS := 2 # rodadas de mercado nas férias (antes do primeiro jogo)
const MAX_RUMORS_PER_TURN := 1

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
		st = {"w": wid, "left": {}}
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
			n += world.rng.randi_range(-1, 1)
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
	if c.balance < 0 and world.rng.randf() < 0.6:
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
	# Formadores e vendedores apostam em promessas; os outros reforçam o time titular.
	if float(arch.get("potential_weight", 0.4)) >= 0.6 and world.rng.randf() < 0.4:
		var fam := world.rng.randi_range(0, TransferManager.FAMILIES.size() - 1)
		return {"fam": fam, "pos": -1, "min_rating": level - 4.0, "urgency": 0.5, "young": true}
	var weak := TransferManager._weakest_starter(world, c)
	if not weak.is_empty() and float(weak["rating"]) < level + 5.0 and world.rng.randf() < 0.75:
		return {"fam": TransferManager._family_of(int(weak["pos"])), "pos": int(weak["pos"]), "min_rating": float(weak["rating"]) + 2.0, "urgency": 1.0}
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
	if pages is Array and world.rng.randf() < 0.7:
		ages = pages
	if need.get("young", false):
		ages = [17, 22]
	var pot_w := float(arch.get("potential_weight", 0.4))
	var sources: Array = prof.get("sources", [])
	var my_power := power(c)
	var best: Player = null
	var best_score := -1e9
	for _k in CANDIDATES:
		var p := _draw(world, index, c, fam, min_rating, prof)
		if p == null or p.club_id == c.id or p.retiring or p.injury_weeks > 4:
			continue
		if p.club_id >= 0:
			if free_only or world.is_user_club(p.club_id) or p.joined_year == world.year:
				continue # recém-contratado não é revendido na mesma temporada
		var age := p.age(world.year)
		var rating := p.rating_at(target_pos) if target_pos >= 0 else p.ovr_f
		var eff := rating + (float(p.potential) - rating) * pot_w * (0.6 if age <= 23 else 0.0)
		if eff < min_rating and not mismanaged:
			continue
		var price := 0.0
		var seller: Club = null
		if p.club_id >= 0:
			seller = world.club(p.club_id)
			price = float(p.value) * _seller_mult(world, seller, p, c, false)
			if price > budget * (1.3 if mismanaged else 1.0):
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
	var seller2 := world.club(best.club_id)
	var deal := negotiate(world, c, best, urgency, deadline, mismanaged)
	if deal.is_empty():
		_rumor_failed(world, st, c, best, seller2)
		return null
	if world.rng.randf() > player_interest(world, best, c):
		return null # clubes se acertaram, mas o jogador não quis
	var was_key := best.squad_status <= Player.STATUS_STARTER
	var fee: int = deal["fee"]
	if deal.get("clause", false):
		_news_clause(world, c, best, seller2, fee)
	var t := TransferManager.complete_transfer(world, best, c, fee, wage2, years)
	# Efeito dominó: quem perdeu um titular vai atrás de reposição.
	if was_key and not world.is_user_club(seller2.id):
		var k := str(seller2.id)
		st["left"][k] = int(st["left"].get(k, 0)) + 1
	_news_record(world, t)
	return t


## Sorteia um candidato: próprio país, rotas de garimpo do país ou o mercado mundial por nível.
static func _draw(world: GameWorld, index: Dictionary, c: Club, fam: int, min_rating: float, prof: Dictionary) -> Player:
	var r := world.rng.randf()
	var dom := float(prof.get("domestic", 0.6))
	var nat := ""
	if r < dom:
		nat = c.nation
	else:
		var sources: Array = prof.get("sources", [])
		if not sources.is_empty() and world.rng.randf() < 0.5:
			nat = sources[world.rng.randi_range(0, sources.size() - 1)]
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
	var years := p.contract_years_left(world.year)
	if years <= 0:
		m *= 0.6 # ou vende agora, ou perde de graça
	elif years == 1:
		m *= 0.8
	elif years >= 4:
		m *= 1.08
	if p.transfer_listed:
		m *= 0.85
	if seller.balance < 0:
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
static func max_bid(world: GameWorld, buyer: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool = false) -> float:
	var m := premium(buyer) * (1.0 + clampf(urgency, 0.0, 6.0) * 0.03)
	var level := PlayerGenerator.club_level(buyer)
	if p.squad_status == Player.STATUS_STAR or p.ovr_f >= level + 4.0:
		m *= 1.0 + float(buyer.arch().get("star_pref", 0.5)) * 0.25
	if p.age(world.year) <= 23 and p.potential >= p.overall + 6:
		m *= 1.1 # ágio pela promessa
	if deadline:
		m *= 1.1
	if mismanaged:
		m *= 1.25
	return minf(float(p.value) * m * 1.15, float(buyer.transfer_budget) * (1.3 if mismanaged else 1.0))


## Proposta, contraproposta e desfecho. Retorna {fee, clause} ou {} (negociação travou).
static func negotiate(world: GameWorld, buyer: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool = false) -> Dictionary:
	var seller := world.club(p.club_id)
	var reserve := float(p.value) * _seller_mult(world, seller, p, buyer, deadline) * world.rng.randf_range(0.95, 1.08)
	var top := max_bid(world, buyer, p, urgency, deadline, mismanaged)
	var clause := _clause_of(seller, p)
	if top <= 0.0:
		return {}
	var bid := minf(top, float(p.value) * premium(buyer) * world.rng.randf_range(0.72, 0.95))
	for _round in 3:
		if bid >= reserve:
			return {"fee": Valuation.round_value(bid)}
		var counter := maxf(reserve * world.rng.randf_range(1.0, 1.1), bid * 1.05)
		if counter <= top:
			if world.rng.randf() < 0.55:
				return {"fee": Valuation.round_value(counter)}
			bid = (bid + counter) * 0.5 # "racha a diferença"
			if bid >= reserve * 0.97 and world.rng.randf() < 0.6:
				return {"fee": Valuation.round_value(bid)}
		else:
			bid = minf(top, (bid + counter) * 0.5)
	# Vendedor não cedeu: se a multa couber no bolso e o jogador quiser, deposita e leva.
	if clause > 0 and float(clause) <= float(buyer.transfer_budget) and float(clause) <= top * 1.25 and power(buyer) >= power(seller):
		return {"fee": clause, "clause": true}
	return {}


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
