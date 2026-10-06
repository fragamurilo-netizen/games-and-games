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
const STATUS_ASK: Array[float] = [1.6, 1.25, 1.0, 0.85, 1.3] # estrela, titular, rotação, reserva, promessa
const OFFSEASON_ROUNDS := 2 # rodadas de mercado nas férias (antes do primeiro jogo)
const MAX_RUMORS_PER_TURN := 1
const MAX_TALKS := 40 # negociações em andamento de uma semana para outra
const MAX_PUSH := 2 # quantas vezes o comprador volta à mesa depois da primeira recusa
const SOUTH_AMERICA := ["BRA", "ARG", "URU", "COL", "CHI", "ECU", "PER", "PAR", "BOL", "VEN"]
const JEWEL_POT := 74.0 # potencial que faz um garoto de 16-17 anos ser vendido antes dos 18
const JEWEL_PRESELL := 0.35 # chance por janela de uma dessas joias ser vendida (sobe com o potencial)

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


## Chance (0..1) de o clube aceitar um jogador por causa da nacionalidade dele, como no mercado
## real: na América do Sul quase todo estrangeiro é sul-americano (Transfermarkt: europeus são 1 a 2%
## dos elencos do Brasileirão e do Argentino). Do próprio país ou da mesma confederação = 1; de quem
## está na lista de importações do país (nations.json › imports), a força dela × outside_imports;
## do resto, outside. País sem outside em market.json não filtra.
static func origin_weight(buyer: Club, p: Player) -> float:
	var prof := profile(buyer.nation)
	var outside: Variant = prof.get("outside")
	if outside == null or p.nationality == buyer.nation:
		return 1.0
	var my_conf := String(DatabaseManager.nation(buyer.nation).get("confed", ""))
	if my_conf != "" and String(DatabaseManager.nation(p.nationality).get("confed", "")) == my_conf:
		return 1.0
	var w := float(outside)
	var imp: Dictionary = DatabaseManager.nation(buyer.nation).get("imports", {})
	if imp.has(p.nationality):
		var top := 1.0
		for k in imp:
			top = maxf(top, float(imp[k]))
		w = maxf(w, float(imp[p.nationality]) / top * float(prof.get("outside_imports", 0.5)))
	return w


# ---------------------------------------------------------------------------
# Coerência: quem pode querer quem, e quanto vale uma aposta
# ---------------------------------------------------------------------------

## O jogador serve para o clube? O nível que o mercado enxerga (jovens pelo que podem virar) tem de
## estar perto do nível do elenco: gigante não vai atrás de reserva de quarta divisão.
static func fits_level(world: GameWorld, c: Club, p: Player, below: float = 4.0, above: float = 14.0) -> bool:
	var r := Valuation.perceived_rating(p, world.year) + Valuation.shift
	var lvl := PlayerGenerator.club_level(c)
	return r >= lvl - below and r <= lvl + above


## Clube realista para sondar o jogador (eventos e rumores): reputação mínima, nível compatível e
## filosofia que aceita o jogador. Sorteia entre os de nível mais próximo. null se ninguém faria sentido.
static func realistic_suitor(world: GameWorld, p: Player, min_rep: float, rng: RandomNumberGenerator, below: float = 4.0, filter: Callable = Callable()) -> Club:
	var r := Valuation.perceived_rating(p, world.year) + Valuation.shift
	var cands: Array = []
	for c: Club in world.clubs:
		if c.id == p.club_id or world.is_user_club(c.id) or c.reputation < min_rep:
			continue
		if not fits_level(world, c, p, below) or not ClubPolicy.ai_wants(world, c, p):
			continue
		if origin_weight(c, p) < 0.15:
			continue # rumor tem de fazer sentido: clube argentino não sonda zagueiro sueco
		if filter.is_valid() and not filter.call(c):
			continue
		cands.append(c)
	if cands.is_empty():
		return null
	cands.sort_custom(func(a: Club, b: Club):
		var da := absf(r - PlayerGenerator.club_level(a) - 2.0)
		var db := absf(r - PlayerGenerator.club_level(b) - 2.0)
		return da < db if da != db else a.id < b.id)
	return cands[rng.randi_range(0, mini(cands.size(), 6) - 1)]


## Quanto um clube paga por um garoto que nem estreou no profissional: aposta no potencial, com
## desconto por não ter jogado nada. Nem a maior joia custa mais que um titular pronto dez pontos
## abaixo do potencial dela, nem mais que 20% da verba do comprador.
static func academy_fee(world: GameWorld, p: Player, buyer: Club, rng: RandomNumberGenerator) -> int:
	var pot := float(p.potential) + p.scout_noise * 0.5
	var eff := p.ovr_f + maxf(0.0, pot - p.ovr_f) * 0.4
	var v := Valuation.VALUE_BASE * pow(Valuation.VALUE_GROWTH, eff - Valuation.shift - 40.0) * Valuation.age_factor(p.age(world.year))
	v *= rng.randf_range(0.9, 1.35) * (0.85 + buyer.reputation / 400.0)
	var cap := minf(float(Valuation.market_value_of_rating(pot - 10.0)), float(buyer.transfer_budget) * 0.2)
	return Valuation.round_value(clampf(v, 50_000.0, maxf(50_000.0, cap)))


# ---------------------------------------------------------------------------
# Entrada: um fim de semana de mercado
# ---------------------------------------------------------------------------

## Mercado da IA num fim de semana (janela aberta ou não). Retorna as Transfer feitas.
static func matchday(world: GameWorld) -> Array:
	var window := world.transfer_window_open()
	var index := TransferManager._build_index(world)
	index["memo"] = new_memo()
	var done: Array = []
	var st := _state(world, window)
	st["rumors"] = 0
	var deadline := window and _is_deadline(world)
	var wi := window_index(world)
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
		var summer := window and is_main_window(world, c, wi)
		# O clube trabalha enquanto tem prioridade aberta no plano; fora da janela, só livres para
		# tapar carência. Clube grande tem mais gente no departamento e resolve mais coisas por semana.
		if window:
			if TransferBrain.next_need(st, c).is_empty():
				continue
		elif not urgent:
			continue
		var tries := 1
		if summer and left >= 2:
			tries = 2 + (1 if power(c) >= 1.0 else 0)
		if deadline:
			tries += 1
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
	var wi := window_index(world)
	var wid := world.year * 100 + wi
	if int(st.get("w", -1)) != wid:
		st = {"w": wid, "left": {}, "talks": []}
		world.stats["mkt"] = st
		_plan_window(world, st, wi)
	return st


## Qual janela está aberta: 0 = a primeira da temporada, 1 = a do meio (-1 = fechada).
static func window_index(world: GameWorld) -> int:
	if world.season == null:
		return -1
	var ws := world.season.window_ranges()
	for i in ws.size():
		if world.current_day() >= int(ws[i][0]) and world.current_day() <= int(ws[i][1]):
			return i
	return -1


## A janela aberta é a grande do clube? Cada clube monta o elenco na pré-temporada da própria liga:
## na América do Sul (ano civil) é a de janeiro, na Europa a de julho e agosto, seja qual for o
## calendário da carreira. Na outra janela o clube só faz remendos e repõe quem vendeu.
static func is_main_window(world: GameWorld, c: Club, wi: int) -> bool:
	if wi < 0:
		return false
	var own := String(c.league_cfg().get("calendar", ""))
	return (wi == 0) == (own == SeasonManager.calendar_kind(world))


static func _plan_window(world: GameWorld, st: Dictionary, wi: int) -> void:
	_presell_jewels(world)
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		var summer := is_main_window(world, c, wi)
		# Diagnóstico do elenco, pressão e perfil viram a lista de prioridades da janela.
		TransferBrain.plan_window(world, st, c, summer)
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
		if not ClubPolicy.eligible(world, c, p) or TransferRules.minor_blocked(world, p, c):
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


static func _try_signing(world: GameWorld, c: Club, index: Dictionary, st: Dictionary, deadline: bool, free_only: bool) -> Transfer:
	if ClubEvents.banned(world, c):
		return null # transfer ban: não pode inscrever reforços
	var need := TransferBrain.next_need(st, c)
	if need.is_empty() and free_only:
		# Fora da janela: só sem clube, e só para tapar uma carência de verdade.
		for n: Dictionary in TransferBrain.diagnose(world, c, false):
			if String(n["why"]) == "carencia":
				need = n
				break
	if need.is_empty():
		return null
	var mismanaged := float(c.arch().get("mismanagement", 0.0)) >= 0.5
	var urgency := clampf(float(need.get("prio", 1.0)), 0.5, 4.0)
	var cands := TransferBrain.targets(world, c, need, index, free_only, st)
	if cands.is_empty():
		need["fails"] = int(need.get("fails", 0)) + 1
		return null
	var best: Player = cands[0]
	var prof := profile(c.nation)
	if best.club_id < 0:
		if player_interest(world, best, c) < decision_bar(best):
			TransferBrain.record(st, c, need, best, false)
			return null
		var wage2 := Valuation.round_wage(TransferManager.wage_ask(world, best, c) * float(prof.get("wage_boost", 1.0)))
		var tf := TransferManager.complete_transfer(world, best, c, 0, wage2, TransferManager.preferred_years(world, best))
		TransferBrain.record(st, c, need, best, true)
		return tf
	var t := _close_deal(world, st, c, best, urgency, deadline, mismanaged, 0)
	TransferBrain.record(st, c, need, best, best.club_id == c.id)
	return t


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
	if player_interest(world, p, buyer) < decision_bar(p):
		return null # clubes se acertaram, mas o jogador não quis (exigência dele, não sorteio)
	var was_key := p.squad_status <= Player.STATUS_STARTER
	var fee: int = deal["fee"]
	var years := TransferManager.preferred_years(world, p)
	var wage := Valuation.round_wage(TransferManager.wage_ask(world, p, buyer) * float(profile(buyer.nation).get("wage_boost", 1.0)))
	if deal.get("clause", false):
		_news_clause(world, buyer, p, seller, fee)
	var minor := TransferRules.minor_blocked(world, p, buyer)
	# Troca: parte do pagamento vai em jogador que o vendedor precisa.
	var piece: Player = null
	if not minor and world.rng.randf() < 0.45:
		piece = _swap_piece(world, buyer, seller, p, fee)
	var t := TransferManager.complete_transfer(world, p, buyer, fee, wage, years)
	if minor:
		TransferRules.hold_until_18(world, p, buyer, seller)
		TransferRules.news_hold(world, p, buyer, seller, fee)
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
	# Efeito dominó: quem perdeu um titular põe a reposição no topo da lista.
	if was_key and not minor and not world.is_user_club(seller.id):
		TransferBrain.on_sold(world, seller, p)
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


static func _presell_jewels(world: GameWorld) -> void:
	var hunters: Array = []
	for c: Club in world.clubs:
		if not world.is_user_club(c.id) and hunts_jewels(c) and not ClubEvents.banned(world, c):
			hunters.append(c)
	if hunters.is_empty():
		return
	for p: Player in world.players.values():
		if p.club_id < 0 or not p.loan.is_empty() or p.age(world.year) < 16 or p.age(world.year) > 17:
			continue
		var seller := world.club(p.club_id)
		if world.is_user_club(seller.id) or not SOUTH_AMERICA.has(seller.nation):
			continue
		var pot := float(p.potential) + p.scout_noise * 0.5
		if pot < JEWEL_POT or world.rng.randf() > JEWEL_PRESELL * (1.0 + (pot - JEWEL_POT) / 10.0):
			continue
		# Os mais ricos escolhem primeiro; o garoto prefere quem tem nome.
		var best: Club = null
		var best_v := -1e9
		for _k in 8:
			var c: Club = hunters[world.rng.randi_range(0, hunters.size() - 1)]
			if not ClubPolicy.ai_wants(world, c, p):
				continue
			var v := c.reputation + power(c) * 10.0 + world.rng.randf_range(0.0, 8.0)
			if v > best_v:
				best_v = v
				best = c
		if best == null:
			continue
		world.stat_add("jewel_tries")
		# O clube sul-americano vende pelo pedido: o dinheiro fecha o ano e o garoto não ficaria mesmo.
		var fee := Valuation.round_value(TransferManager.asking_price(world, p) * world.rng.randf_range(1.0, 1.25))
		if fee > best.transfer_budget or world.rng.randf() > maxf(0.5, player_interest(world, p, best)):
			continue
		TransferManager.complete_transfer(world, p, best, fee, Valuation.wage_demand(p, best, world.year), 5)
		TransferRules.hold_until_18(world, p, best, seller)
		TransferRules.news_hold(world, p, best, seller, fee)


## Clube europeu com dinheiro e olheiros na América do Sul.
static func hunts_jewels(c: Club) -> bool:
	if SOUTH_AMERICA.has(c.nation) or c.reputation < 64.0:
		return false
	var ages: Variant = profile(c.nation).get("age")
	if ages is Array and int(ages[0]) >= 23:
		return false # Golfo, Turquia, China: compram pronto, não apostam em garoto
	for n in profile(c.nation).get("sources", []):
		if SOUTH_AMERICA.has(n):
			return true
	return false


static func decision_bar(p: Player) -> float:
	return 0.32 + float(hash([p.id, p.face_seed, "exige"]) % 100) / 100.0 * 0.3


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
	v += Aftermath.exit_pull(world, p, buyer) # quem caiu quer sair; o campeão atrai
	return clampf(v, 0.05, 0.95)


# ---------------------------------------------------------------------------
# Negociação clube × clube
# ---------------------------------------------------------------------------

## Multiplicador (sobre o valor de mercado) do mínimo que o vendedor aceita.
## `memo` (opcional, de uma rodada de mercado): guarda o que é do clube vendedor (aperto financeiro,
## elenco por família) enquanto o caixa e o elenco dele não mudam; o resultado é o mesmo.
static func _seller_mult(world: GameWorld, seller: Club, p: Player, buyer: Club, deadline: bool, memo: Dictionary = {}) -> float:
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
	m *= Aftermath.sell_mult(world, seller, p) # recém-rebaixado não segura quem está acima do nível
	if _memo_trouble(seller, memo):
		m *= 0.8
	if _memo_family_count(world, seller, p.position, memo) <= TransferManager._family_min(p.position):
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


static func _memo_trouble(c: Club, memo: Dictionary) -> bool:
	if memo.is_empty() and not memo.has("on"):
		return FinanceManager.in_trouble(c)
	var key := [c.id, c.balance, c.debt]
	var t: Dictionary = memo["trouble"]
	if not t.has(key):
		t[key] = FinanceManager.in_trouble(c)
	return t[key]


static func _memo_family_count(world: GameWorld, c: Club, pos: int, memo: Dictionary) -> int:
	if memo.is_empty() and not memo.has("on"):
		return TransferManager._family_count(world, c, pos)
	var fams: Dictionary = memo["fam"]
	var h := c.player_ids.hash()
	var e: Array = fams.get(c.id, [])
	if e.is_empty() or int(e[0]) != h:
		var counts := PackedInt32Array()
		counts.resize(TransferManager.FAMILIES.size())
		for pid in c.player_ids:
			var q: Player = world.players.get(pid, null)
			if q != null and q.injury_weeks < 6:
				counts[TransferManager._family_of(q.position)] += 1
		e = [h, counts]
		fams[c.id] = e
	return (e[1] as PackedInt32Array)[TransferManager._family_of(pos)]


## Memória de uma rodada de mercado (lesões não mudam no meio dela; caixa e elenco entram na chave).
static func new_memo() -> Dictionary:
	return {"on": true, "trouble": {}, "fam": {}}


## Teto que o comprador paga.
static func max_bid(world: GameWorld, buyer: Club, p: Player, urgency: float, deadline: bool, mismanaged: bool = false, push: int = 0) -> float:
	var m := premium(buyer) * (1.0 + clampf(urgency, 0.0, 6.0) * 0.03) * (1.0 + 0.07 * push)
	var level := PlayerGenerator.club_level(buyer)
	if p.squad_status == Player.STATUS_STAR or p.ovr_f >= level + 4.0:
		m *= 1.0 + float(buyer.arch().get("star_pref", 0.5)) * 0.25
	var age := p.age(world.year)
	if age <= 23 and p.potential >= p.overall + 6:
		if p.ovr_f >= level - 6.0:
			m *= 1.1 # ágio pela promessa que já joga
		else:
			# Ainda não está pronto para este time: paga-se a aposta, não o craque que ele pode virar.
			m *= 0.8 if p.career_apps >= 30 else 0.65
	if deadline:
		m *= 1.1
	if mismanaged:
		m *= 1.25
	if not world.is_user_club(buyer.id):
		m *= ClubDNA.bid_mult(buyer, p, level)
	# Ninguém paga ágio por jogador passado dos 30: o valor de revenda é zero.
	if age >= 30:
		m *= 0.88 if age == 30 else (0.78 if age <= 32 else 0.68)
	# Os ágios não se empilham sem fim: nem no leilão mais doido alguém paga muito mais que ~1,6× o valor.
	m = minf(m, 1.4)
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
		var ow := origin_weight(c, p)
		if ow < 1.0 and world.rng.randf() >= ow:
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
