class_name TransferBrain
extends RefCounted
## Como um clube da IA decide quem contratar, sem sorteio de candidatos:
##
## 1. Diagnóstico do elenco (diagnose): carência de posição, titular fraco para o nível do clube,
##    titular envelhecendo (precisa de sucessor), contrato acabando, lesão longa, vaga da formação
##    sem especialista (ponta no 4-3-3, ala no 3-5-2), banco curto, e reposição de quem foi vendido.
## 2. Pressão (pressure): torcida irritada, ferida recente (final perdida, rival campeão), presidente
##    vaidoso ou populista, ano de eleição, dono novo querendo gastar, briga contra o rebaixamento ou
##    pelo título na janela do meio, rival que acabou de contratar forte, e o aperto financeiro.
## 3. Perfil do clube (profile): o DNA de contratação (formação, estrelas, moneyball, veteranos),
##    idades, peso do potencial, gosto por jogadores do país e da mesma língua, teto salarial
##    (ninguém ganha muito acima do mais bem pago, a não ser o nome de peso), revenda.
## 4. Plano da janela (plan_window): as carências viram uma lista de prioridades com teto de preço e
##    salário; cada fim de semana o clube vai atrás da prioridade da vez.
## 5. Alvos (targets): só quem os olheiros conhecem (ClubScoutNet) ou quem os empresários oferecem
##    (sem clube, listado, insatisfeito) nas ligas que o clube acompanha. Cada alvo recebe nota pelo
##    que o clube enxerga (com o erro da observação), encaixe, idade, preço, salário, língua,
##    compatriotas, vontade do jogador e pressão. Quem já recusou não volta na mesma janela.

const MAX_NEEDS_MAIN := 6
const MAX_NEEDS_MID := 3
const AGENT_KNOW := 45.0 # empresário apresenta o jogador: o clube conhece o básico


# ---------------------------------------------------------------------------
# 1. Diagnóstico
# ---------------------------------------------------------------------------

## Carências do elenco: [{fam, pos, why, prio, min, ages, young}], da mais urgente para a menos.
static func diagnose(world: GameWorld, c: Club, summer: bool) -> Array:
	var lvl := PlayerGenerator.club_level(c)
	var out: Array = []
	var fam_taken := {}
	# a) carência de família (menos jogadores do que o mínimo)
	for n in TransferManager.squad_needs(world, c):
		var fam := int(n["fam"])
		if int(n["count"]) < int(TransferManager.FAMILIES[fam][1]):
			out.append({"fam": fam, "pos": -1, "why": "carencia", "prio": 3.0 + float(n["urgency"]) * 0.2, "min": lvl - 7.0, "ages": [20, 31]})
			fam_taken[fam] = true
	# b) o time titular, vaga por vaga
	var fname := c.sheet.formation if c.sheet != null else "4-4-2"
	var slots: Array = DatabaseManager.formation(fname)["slots"]
	var xi: Array = ClubAI.best_eleven(world, c, fname)
	for i in mini(slots.size(), xi.size()):
		var pos: int = slots[i]["pos"]
		var fam := TransferManager._family_of(pos)
		var pid := int(xi[i])
		var p: Player = world.player(pid) if pid >= 0 else null
		if p == null:
			out.append({"fam": fam, "pos": pos, "why": "carencia", "prio": 3.0, "min": lvl - 6.0, "ages": [20, 31]})
			continue
		var r := p.rating_at(pos)
		var age := p.age(world.year)
		if r < lvl - 3.0 and not fam_taken.has(fam):
			out.append({"fam": fam, "pos": pos, "why": "titular_fraco", "prio": 2.0 + (lvl - r) / 5.0, "min": r + 3.0, "ages": [21, 30]})
			fam_taken[fam] = true
		elif r < p.ovr_f - 5.0 and not fam_taken.has(fam):
			# A vaga existe na formação, mas quem joga ali não é da posição (ponta improvisado, ala que é zagueiro).
			out.append({"fam": fam, "pos": pos, "why": "sistema", "prio": 1.6, "min": lvl - 3.0, "ages": [20, 29]})
			fam_taken[fam] = true
		elif summer and age >= (34 if pos == Pos.GK else 32) and not fam_taken.has(fam):
			out.append({"fam": fam, "pos": pos, "why": "sucessor", "prio": 1.3, "min": lvl - 5.0, "ages": [19, 26], "young": true})
			fam_taken[fam] = true
		elif p.injury_weeks >= 8 and not fam_taken.has(fam):
			out.append({"fam": fam, "pos": pos, "why": "lesao", "prio": 2.2, "min": lvl - 4.0, "ages": [21, 32]})
			fam_taken[fam] = true
		elif summer and p.contract_years_left(world.year) <= 0 and p.squad_status <= Player.STATUS_STARTER and not fam_taken.has(fam):
			out.append({"fam": fam, "pos": pos, "why": "contrato", "prio": 1.1, "min": lvl - 3.0, "ages": [20, 30]})
			fam_taken[fam] = true
	# c) banco curto: menos de dois jogadores de rotação perto do nível na família
	if summer:
		var depth := {}
		for p: Player in world.squad(c):
			if p.ovr_f >= lvl - 7.0 and p.injury_weeks < 6:
				var f := TransferManager._family_of(p.position)
				depth[f] = int(depth.get(f, 0)) + 1
		for fam in TransferManager.FAMILIES.size():
			if fam_taken.has(fam):
				continue
			var need_n := int(TransferManager.FAMILIES[fam][1]) + 1
			if int(depth.get(fam, 0)) < need_n:
				out.append({"fam": fam, "pos": -1, "why": "elenco", "prio": 0.8, "min": lvl - 7.0, "ages": [19, 31]})
	# d) garimpo: clube europeu de porte com olheiros na América do Sul guarda uma vaga para joia
	if summer and MarketAI.hunts_jewels(c):
		out.append({"fam": -1, "pos": -1, "why": "joia", "prio": 0.9, "min": lvl - 14.0, "ages": [16, 20], "young": true})
	out.sort_custom(func(a, b): return float(a["prio"]) > float(b["prio"]))
	return out.slice(0, MAX_NEEDS_MAIN if summer else MAX_NEEDS_MID)


# ---------------------------------------------------------------------------
# 2. Pressão
# ---------------------------------------------------------------------------

## {amb: -0.5..1 (quanto o clube se estica), marquee: quer um nome de peso, why: [motivos]}
static func pressure(world: GameWorld, c: Club) -> Dictionary:
	var amb := 0.0
	var why: Array = []
	var marquee := false
	if c.fan_mood < 40.0:
		amb += 0.2
		why.append("torcida cobra reforços")
	if Aftermath.mood_target(world, c) < 52.0:
		amb += 0.15
		why.append("ferida recente")
	var pst := String(People.president(world, c.id).get("st", ""))
	if pst == "vaidoso" and MarketAI.power(c) >= 0.6:
		marquee = true
		amb += 0.1
		why.append("presidente quer um nome de peso")
	elif pst == "populista" and c.fan_mood < 50.0:
		amb += 0.15
		why.append("presidente de olho na arquibancada")
	elif pst == "empresario":
		amb -= 0.1
	if int(People.president(world, c.id).get("term", 0)) == world.year:
		amb += 0.15
		why.append("ano de eleição no clube")
	var own := WorldEvents.owner_of(world, c.id)
	if not own.is_empty() and world.year - int(own.get("y", 0)) <= 1:
		amb += 0.35
		marquee = true
		why.append("dono novo quer mostrar serviço")
	var league := world.league_of(c.id)
	if league != null and world.current_turn() > 6 and int(league.table.get(c.id, {}).get("pl", 0)) > 0:
		var pos := CompetitionManager.position_of(league, c.id)
		var n := league.club_ids.size()
		if pos >= n - 3:
			amb += 0.3
			why.append("briga contra o rebaixamento")
		elif pos <= 3:
			amb += 0.15
			why.append("briga pelo título")
	if _rival_splashed(world, c):
		amb += 0.15
		why.append("o rival contratou forte")
	if FinanceManager.in_trouble(c):
		amb -= 0.5
		marquee = false
		why.append("aperto financeiro")
	return {"amb": clampf(amb, -0.5, 1.0), "marquee": marquee, "why": why}


## Rival comprou caro nesta temporada?
static func _rival_splashed(world: GameWorld, c: Club) -> bool:
	for t: Transfer in world.transfer_log:
		if t.year != world.year or t.fee <= 0:
			continue
		var to := world.club(t.to_id)
		if to != null and (c.is_rival(to.id) or to.is_rival(c.id)) and t.fee >= to.transfer_budget * 0.3 + 1:
			return true
	return false


# ---------------------------------------------------------------------------
# 3. Perfil
# ---------------------------------------------------------------------------

static func profile(world: GameWorld, c: Club) -> Dictionary:
	var arch := c.arch()
	var rec := ClubDNA.rec(c)
	var pot_w := float(arch.get("potential_weight", 0.4))
	if rec == "formacao":
		pot_w = maxf(pot_w, 0.75)
	var top_wage := 0
	for p: Player in world.squad(c):
		top_wage = maxi(top_wage, p.wage)
	return {"rec": rec, "ages": ClubDNA.ages(c), "pot_w": pot_w, "top_wage": top_wage,
		"lang": String(DatabaseManager.nation(c.nation).get("lang", "")), "mism": float(arch.get("mismanagement", 0.0)) >= 0.5}


# ---------------------------------------------------------------------------
# 4. Plano da janela
# ---------------------------------------------------------------------------

static func plan_window(world: GameWorld, st: Dictionary, c: Club, summer: bool) -> void:
	if not st.has("plans"):
		st["plans"] = {}
	ClubScoutNet.ensure_known(world, c)
	var needs := diagnose(world, c, summer)
	var pr := pressure(world, c)
	# Dinheiro curto corta a lista; dinheiro sobrando e pressão alongam.
	var keep := needs.size()
	if c.transfer_budget <= 0 and FinanceManager.in_trouble(c):
		keep = mini(keep, 1)
	elif float(pr["amb"]) >= 0.4 and summer:
		keep = mini(needs.size(), keep + 1)
	needs = needs.slice(0, keep)
	st["plans"][str(c.id)] = {"needs": needs, "pr": pr, "tried": {}}
	st["left"][str(c.id)] = needs.size()


## Prioridade da vez (a primeira ainda aberta), ou {}.
static func next_need(st: Dictionary, c: Club) -> Dictionary:
	var plan: Dictionary = st.get("plans", {}).get(str(c.id), {})
	for n: Dictionary in plan.get("needs", []):
		if not n.get("done", false) and int(n.get("fails", 0)) < 3:
			return n
	return {}


static func plan_of(st: Dictionary, c: Club) -> Dictionary:
	return st.get("plans", {}).get(str(c.id), {})


## Vendeu um titular no meio da janela: a reposição entra no topo da lista.
static func on_sold(world: GameWorld, seller: Club, p: Player) -> void:
	if seller == null or world.is_user_club(seller.id) or not world.transfer_window_open():
		return
	var st: Dictionary = world.stats.get("mkt", {})
	if not st.has("plans"):
		return
	var plan: Dictionary = st["plans"].get(str(seller.id), {})
	if plan.is_empty():
		return
	var needs: Array = plan["needs"]
	needs.push_front({"fam": TransferManager._family_of(p.position), "pos": p.position, "why": "reposicao", "prio": 3.5,
		"min": p.ovr_f - 3.0, "ages": [20, 30]})
	st["left"][str(seller.id)] = int(st["left"].get(str(seller.id), 0)) + 1


# ---------------------------------------------------------------------------
# 5. Alvos
# ---------------------------------------------------------------------------

## Candidatos para a carência, do melhor para o pior (no máximo 8).
static func targets(world: GameWorld, c: Club, need: Dictionary, index: Dictionary, free_only: bool, st: Dictionary) -> Array:
	var plan := plan_of(st, c)
	var pr: Dictionary = plan.get("pr", {"amb": 0.0, "marquee": false})
	var tried: Dictionary = plan.get("tried", {})
	var prof := profile(world, c)
	var pool := {}
	if not free_only:
		var sl := ClubScoutNet.shortlist(world, c, 30.0)
		for pid in sl:
			pool[pid] = sl[pid]
	for p: Player in _agents_pool(world, c, need, index):
		if not pool.has(p.id):
			pool[p.id] = AGENT_KNOW
	var budget := float(c.transfer_budget) * (1.0 + float(pr["amb"]) * 0.25)
	var wage_room := float(c.wage_budget - FinanceManager.wage_bill(world, c))
	var lvl := PlayerGenerator.club_level(c)
	var scored: Array = []
	for pid in pool:
		var p: Player = world.players.get(pid)
		if p == null or p.club_id == c.id or p.retiring or p.injury_weeks > 4 or not p.loan.is_empty() or tried.has(pid):
			continue
		if p.club_id >= 0 and (free_only or world.is_user_club(p.club_id) or p.joined_year == world.year):
			continue
		var fam := int(need.get("fam", -1))
		if fam >= 0 and TransferManager._family_of(p.position) != fam:
			continue
		if not ClubPolicy.ai_wants(world, c, p):
			continue
		var age := p.age(world.year)
		var ages: Array = need.get("ages", [18, 32])
		if need.get("young", false) and age > int(ages[1]):
			continue
		if TransferRules.minor_blocked(world, p, c) and not need.get("young", false):
			continue
		if TransferRules.permit_block(world, p, c) != "":
			continue # sem permissão de trabalho (Reino Unido)
		var ow := MarketAI.origin_weight(c, p)
		if ow < 0.25:
			continue # o clube não contrata desse lugar (sul-americano raramente traz europeu)
		var kn := float(pool[pid])
		var est := ClubScoutNet.estimate(world, c, p, kn)
		if int(need.get("pos", -1)) >= 0:
			est -= maxf(0.0, p.ovr_f - p.rating_at(int(need["pos"]))) # fora de posição rende menos
		var pot := float(p.potential) + p.scout_noise * (1.0 - kn / 100.0)
		var eff := est + maxf(0.0, pot - est) * float(prof["pot_w"]) * (0.6 if age <= 23 else 0.0)
		if eff < float(need["min"]):
			continue
		# Preço e salário que o clube consegue bancar.
		var price := 0.0
		var seller: Club = null
		if p.club_id >= 0:
			seller = world.club(p.club_id)
			price = float(p.value) * MarketAI._seller_mult(world, seller, p, c, false, index["memo"])
			if price > budget and not MarketAI._loanable(world, p, c):
				continue
			if MarketAI.power(seller) > MarketAI.power(c) * 1.5 and p.squad_status <= Player.STATUS_STARTER and age < 30:
				continue # titular de clube muito mais rico não sai para um menor
		var wage := float(Valuation.wage_demand(p, c, world.year)) * float(MarketAI.profile(c.nation).get("wage_boost", 1.0))
		if wage > maxf(wage_room, 0.0) * 1.1 and need["why"] != "carencia":
			continue
		if wage > float(prof["top_wage"]) * 1.3 and not bool(pr["marquee"]) and int(prof["top_wage"]) > 0:
			continue # estrutura salarial: ninguém chega ganhando muito acima do mais bem pago
		# Nota rápida (barata): nível, idade, preço, origem, situação de contrato.
		var s := eff - float(need["min"])
		if age < int(ages[0]) or age > int(ages[1]):
			s -= 2.5 + absf(age - clampi(age, int(ages[0]), int(ages[1]))) * 1.2
		s -= price / maxf(50000.0, budget + 1.0) * 2.5
		s -= (1.0 - ow) * 3.0
		if p.nationality == c.nation:
			s += 1.0
		elif String(DatabaseManager.nation(p.nationality).get("lang", "?")) == String(prof["lang"]):
			s += 0.8 # mesma língua: adapta rápido
		if kn < 50.0 and prof["rec"] != "moneyball":
			s -= 0.8 # pouco visto: risco
		if prof["rec"] == "moneyball":
			s += (est - p.ovr_f + 3.0) * 0.2 - price / maxf(1.0, float(p.value)) * 0.5
		if p.transfer_listed or p.club_id < 0:
			s += 1.0
		elif p.contract_years_left(world.year) <= 1:
			s += 0.8
		if seller != null and (seller.is_rival(c.id) or c.is_rival(seller.id)):
			s -= 4.0
		scored.append([s, p])
	scored.sort_custom(func(a, b): return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and a[1].id < b[1].id))
	# Avaliação completa (cara) só para os 16 melhores da nota rápida: vontade do jogador, ambiente
	# no elenco, homens de confiança do técnico, fama e o DNA do clube.
	var coach := Relations.coach_id_of(world, c.id)
	var full: Array = []
	for e in scored.slice(0, 16):
		var p: Player = e[1]
		var s2 := float(e[0])
		if _compatriots(world, c, p) >= 2:
			s2 += 0.6
		if bool(pr["marquee"]):
			s2 += clampf(Reputation.player_rep(world, p) - 60.0, 0.0, 30.0) * 0.08
		s2 += ClubDNA.candidate_bonus(world, c, p, p.ovr_f, lvl, float(p.value), maxf(1.0, budget), 0)
		s2 += (MarketAI.player_interest(world, p, c) - 0.5) * 2.0
		s2 += Relations.trust_bonus(p, coach)
		s2 += minf(1.0, Relations.friends_in(world, p, c).size() * 0.4) - Relations.enemies_in(world, p, c).size() * 1.0
		if bool(prof["mism"]):
			s2 = s2 * 0.5 + Reputation.player_rep(world, p) * 0.05 # diretoria bagunçada vai pelo nome
		full.append([s2, p])
	full.sort_custom(func(a, b): return float(a[0]) > float(b[0]) or (float(a[0]) == float(b[0]) and a[1].id < b[1].id))
	var out: Array = []
	for e in full.slice(0, 8):
		out.append(e[1])
	return out


## O que os empresários oferecem ao clube: sem clube, listados e insatisfeitos das ligas que ele
## acompanha (e do próprio país), na família procurada.
static func _agents_pool(world: GameWorld, c: Club, need: Dictionary, index: Dictionary) -> Array:
	var fam := int(need.get("fam", -1))
	var nats := {c.nation: true}
	for lid in ClubScoutNet.covered(world, c):
		nats[String(DatabaseManager.league_cfg(lid).get("nation", ""))] = true
	var lvl := float(need.get("min", 50.0))
	var out: Array = []
	for nat in nats:
		var arr: Array = index.get("avail", {}).get(nat, [])
		if arr.is_empty():
			continue
		var fams: Array = [fam] if fam >= 0 else range(arr.size())
		for f in fams:
			for p: Player in arr[f]:
				if p.ovr_f < lvl - 4.0 or p.ovr_f > lvl + 16.0:
					continue
				out.append(p)
				if out.size() >= 40:
					return out
	return out


static func _compatriots(world: GameWorld, c: Club, p: Player) -> int:
	var n := 0
	for q: Player in world.squad(c):
		if q.nationality == p.nationality:
			n += 1
	return n


## Registra o resultado de uma tentativa: carência resolvida ou alvo riscado.
static func record(st: Dictionary, c: Club, need: Dictionary, p: Player, ok: bool) -> void:
	var plan := plan_of(st, c)
	if plan.is_empty():
		return
	if ok:
		need["done"] = true
	else:
		plan["tried"][p.id] = true
		need["fails"] = int(need.get("fails", 0)) + 1
