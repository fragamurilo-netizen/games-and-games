class_name EventManager
extends RefCounted
## Eventos da carreira: dilemas com escolhas (aumento, minutos, patrocínio, imprensa, torcida,
## investimentos, indisciplina, sondagens, departamento médico, amistosos, vestiário, ingressos,
## empresários, joias da base, proposta de compra do clube, ampliação do estádio) e acontecimentos sem escolha (lesão no treino, homenagens...).
##
## Um evento pendente é um dicionário salvo em world.events:
##   {id, k (tipo), turn (criado), exp (expira no jogo), p (jogador), p2 (outro jogador), d (dados)}
## O texto e as opções são montados na hora (describe) a partir dos dados; resolver aplica as
## consequências e devolve uma frase para a interface. Ao expirar vale a opção padrão.

const MAX_PENDING := 4
const COOLDOWN := 6 # jogos entre dois eventos do mesmo tipo
const LIFETIME := 3 # jogos para decidir

const KINDS := {
	"raise": {"w": 1.2, "icon": "money", "color": "ORANGE"},
	"minutes": {"w": 1.0, "icon": "clock", "color": "ORANGE"},
	"sponsor": {"w": 0.0, "icon": "money", "color": "GREEN"}, # patrocínio é da diretoria (fica só para saves antigos)
	"press": {"w": 1.2, "icon": "news", "color": "BLUE"},
	"fans": {"w": 1.0, "icon": "heart", "color": "RED"},
	"invest": {"w": 0.6, "icon": "shield", "color": "GREEN"},
	"discipline": {"w": 0.8, "icon": "card", "color": "RED"},
	"rival_bid": {"w": 0.7, "icon": "swap", "color": "ORANGE"},
	"medical": {"w": 0.7, "icon": "cross", "color": "RED"},
	"friendly": {"w": 0.5, "icon": "ball", "color": "BLUE"},
	"dressing": {"w": 0.6, "icon": "shirt", "color": "ORANGE"},
	"tickets": {"w": 0.5, "icon": "money", "color": "BLUE"},
	"agent": {"w": 0.8, "icon": "search", "color": "BLUE"},
	"prodigy": {"w": 0.8, "icon": "star", "color": "GREEN"},
	"youth_bid": {"w": 0.5, "icon": "swap", "color": "ORANGE"},
	"takeover": {"w": 0.25, "icon": "money", "color": "GREEN"},
	"stadium": {"w": 0.4, "icon": "shield", "color": "BLUE"},
	"homesick": {"w": 0.6, "icon": "home", "color": "ORANGE"},
	"mercenary": {"w": 0.55, "icon": "money", "color": "ORANGE"},
	"want_leave": {"w": 0.5, "icon": "swap", "color": "RED"},
	"fight": {"w": 0.45, "icon": "card", "color": "RED"},
	"party": {"w": 0.5, "icon": "card", "color": "RED"},
	"betting": {"w": 0.18, "icon": "search", "color": "RED"},
	"baby": {"w": 0.35, "icon": "heart", "color": "GREEN"},
	"social": {"w": 0.55, "icon": "news", "color": "BLUE"},
	"extra": {"w": 0.45, "icon": "star", "color": "GREEN"},
	"rebel": {"w": 0.45, "icon": "card", "color": "RED"},
	"chairman": {"w": 0.3, "icon": "shield", "color": "ORANGE"},
	"captain_meeting": {"w": 0.65, "icon": "shirt", "color": "BLUE"},
	"training_star": {"w": 0.7, "icon": "star", "color": "GREEN"},
	"academy_path": {"w": 0.55, "icon": "star", "color": "GREEN"},
	"media_leak": {"w": 0.45, "icon": "news", "color": "RED"},
}
## Ligas que pagam acima do mercado (propostas "irrecusáveis").
const RICH_NATIONS := ["KSA", "QAT", "UAE"]


static func pending(world: GameWorld) -> Array:
	return world.events


static func find(world: GameWorld, id: int) -> Dictionary:
	for ev in world.events:
		if int(ev["id"]) == id:
			return ev
	return {}


# ---------------------------------------------------------------------------
# Disparo (depois de cada jogo do usuário)
# ---------------------------------------------------------------------------

static func after_user_turn(world: GameWorld, result: String) -> Array:
	var out: Array = []
	if not world.has_user():
		return out
	var turn := world.current_turn()
	_check_promises(world, turn, result)
	_expire(world, turn)
	_random_happenings(world)
	AmbientStorytelling.after_user_turn(world, result)
	if world.events.size() >= MAX_PENDING:
		return out
	var p_new := 0.36 if world.events.is_empty() else 0.18
	if world.rng.randf() >= p_new:
		return out
	var cands: Array = []
	var weights: Array = []
	var cd: Dictionary = world.stats.get("ev_cd", {})
	for k in KINDS:
		if turn - int(cd.get(k, -99)) < COOLDOWN:
			continue
		var ev := _build(world, k)
		if ev.is_empty():
			continue
		cands.append(ev)
		weights.append(float(KINDS[k]["w"]))
	if cands.is_empty():
		return out
	var ev: Dictionary = cands[RngUtil.weighted_index(world.rng, weights)]
	ev["id"] = int(world.stats.get("ev_next", 1))
	world.stats["ev_next"] = int(ev["id"]) + 1
	ev["turn"] = turn
	ev["exp"] = turn + LIFETIME
	cd[ev["k"]] = turn
	world.stats["ev_cd"] = cd
	world.events.append(ev)
	out.append(ev)
	return out


## Monta um evento de um tipo se ele fizer sentido agora ({} se não).
static func _build(world: GameWorld, k: String) -> Dictionary:
	var club := world.user_club()
	var rng := world.rng
	var squad: Array = world.squad(club)
	if squad.is_empty():
		return {}
	var turn := world.current_turn()
	var ev := {"k": k, "p": -1, "p2": -1, "d": {}}
	match k:
		"raise":
			var best: Player = null
			for p: Player in squad:
				if p.squad_status > Player.STATUS_STARTER or p.contract_years_left(world.year) < 1 or p.is_injured():
					continue
				var ask := TransferManager.wage_ask(world, p, club)
				if p.wage < ask * 0.8 and (best == null or p.overall > best.overall):
					best = p
			if best == null:
				return {}
			ev["p"] = best.id
			ev["d"] = {"wage": Valuation.round_wage(TransferManager.wage_ask(world, best, club) * 0.95)}
		"minutes":
			if turn < 6:
				return {}
			var ovrs: Array = []
			for p: Player in squad:
				ovrs.append(p.overall)
			ovrs.sort()
			var median: int = ovrs[ovrs.size() / 2]
			var pool: Array = []
			for p: Player in squad:
				if p.overall >= median and p.age(world.year) >= 20 and not p.is_injured() and p.stat(Player.S_STARTS) <= turn * 0.25 and not p.transfer_listed:
					pool.append(p)
			if pool.is_empty():
				return {}
			var pl: Player = RngUtil.pick(rng, pool)
			ev["p"] = pl.id
		"sponsor":
			var base := maxf(float(club.income_sponsor), FinanceManager.club_revenue_target(club) * 0.15)
			ev["d"] = {"lump": Valuation.round_wage(base * rng.randf_range(0.08, 0.14)), "bonus": Valuation.round_wage(base * rng.randf_range(0.2, 0.3)),
				"brand": RngUtil.pick(rng, ["Banco Atlântico", "Veloz Telecom", "Cervejaria Três Coroas", "Aurora Seguros", "PixPay", "Motores Leão", "Supermercados Boa Praça", "AeroSul", "Energia Viva", "Apostas Craque"])}
		"press":
			var f := FixtureManager.next_fixture_for(world, club.id)
			if f == null:
				return {}
			var opp := world.club(f.opponent_of(club.id))
			var why := ""
			if MatchEngine.is_derby(world, f.home, f.away):
				why = "derby"
			elif club.streak_losses >= 2:
				why = "crisis"
			elif club.streak_wins >= 3:
				why = "hot"
			else:
				return {}
			ev["d"] = {"opp": opp.short_name, "why": why}
		"fans":
			if club.streak_winless < 4 and club.fan_mood >= 35.0:
				return {}
		"invest":
			var cost := int(FinanceManager.expected_revenue(club) * 0.07)
			if club.balance < cost * 3 or club.board_confidence < 45.0:
				return {}
			ev["d"] = {"cost": cost}
		"discipline":
			var pool: Array = []
			for p: Player in squad:
				if HiddenPersona.troublemaker(p) or HiddenPersona.hot_head(p) or (p.age(world.year) <= 24 and rng.randf() < 0.1):
					pool.append(p)
					# Quem vive em polêmica aparece mais vezes na lista (e o profissional quase nunca).
					if p.hid("pol") >= 15:
						pool.append(p)
				elif p.hid("pro") <= 5 and rng.randf() < 0.4:
					pool.append(p)
			if pool.is_empty():
				return {}
			var pl: Player = RngUtil.pick(rng, pool)
			ev["p"] = pl.id
			ev["d"] = {"what": rng.randi_range(0, 3)}
		"rival_bid":
			var star: Player = null
			for p: Player in squad:
				if p.transfer_listed:
					continue
				if star == null or p.value > star.value:
					star = p
			if star == null or star.age(world.year) > 31:
				return {}
			# Só sonda quem tem nível para o elenco do interessado (ninguém liga da Europa por um reserva da Série D).
			var buyer := MarketAI.realistic_suitor(world, star, club.reputation + 8.0, rng, 4.0,
				func(c: Club): return c.tier == 1)
			if buyer == null:
				return {}
			ev["p"] = star.id
			ev["d"] = {"club": buyer.id}
		"medical":
			var hurt := 0
			for p: Player in squad:
				if p.injury_weeks >= 2:
					hurt += 1
			if hurt < 2:
				return {}
			ev["d"] = {"cost": int(FinanceManager.expected_revenue(club) * 0.012) + 1000}
		"friendly":
			ev["d"] = {"money": int(FinanceManager.expected_revenue(club) * rng.randf_range(0.015, 0.03)), "where": RngUtil.pick(rng, ["nos Estados Unidos", "no Japão", "nos Emirados", "na China", "na Arábia", "na Austrália", "no Catar"])}
		"dressing":
			var vets: Array = []
			var kids: Array = []
			for p: Player in squad:
				var a := p.age(world.year)
				if a >= 29 and p.squad_status <= Player.STATUS_ROTATION:
					vets.append(p)
				elif a <= 23:
					kids.append(p)
			if vets.is_empty() or kids.is_empty():
				return {}
			var v: Player = RngUtil.pick(rng, vets)
			var y: Player = RngUtil.pick(rng, kids)
			ev["p"] = v.id
			ev["p2"] = y.id
		"tickets":
			if world.season.day < 6:
				return {}
		"agent":
			var need_fams: Array = TransferManager.squad_needs(world, club).map(func(n): return int(n["fam"]))
			var best: Player = null
			for p: Player in world.free_agents():
				if p.age(world.year) > 32:
					continue
				var fits := need_fams.is_empty() or need_fams.has(TransferManager._family_of(p.position))
				if fits and (best == null or p.overall > best.overall):
					best = p
			if best == null or club.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
				return {}
			ev["p"] = best.id
			ev["d"] = {"wage": TransferManager.wage_ask(world, best, club), "years": TransferManager.preferred_years(world, best)}
		"youth_bid":
			var target: Player = YouthManager.bid_target(world)
			if target == null:
				return {}
			var bidder := YouthManager.bid_buyer(world, target)
			if bidder == null:
				return {}
			ev["p"] = target.id
			ev["d"] = {"club": bidder.id, "fee": YouthManager.bid_fee(world, target, bidder)}
		"prodigy":
			var kid: Player = YouthManager.best_prospect(world, club)
			if kid == null or Array(world.stats.get("ev_skip", [])).has(kid.id):
				return {}
			ev["p"] = kid.id
		"homesick":
			# Estrangeiro jovem ou recém-chegado, longe de casa e com a cabeça baixa
			var pool: Array = []
			for p: Player in squad:
				if p.nationality != club.nation and p.morale < 55.0 and (p.age(world.year) <= 24 or world.year - p.joined_year <= 1) and not p.is_injured():
					# Adaptabilidade oculta: quem se adapta fácil quase nunca sente saudade.
					if p.hid("ada") >= 15 and rng.randf() < 0.8:
						continue
					pool.append(p)
					if p.hid("ada") <= 6:
						pool.append(p)
			if pool.is_empty():
				return {}
			var hp: Player = RngUtil.pick(rng, pool)
			ev["p"] = hp.id
			ev["d"] = {"cost": Valuation.round_wage(maxf(20000.0, hp.wage * 1.5))}
		"mercenary":
			# Proposta milionária do Golfo para quem liga para dinheiro
			var best: Player = null
			for p: Player in squad:
				if p.transfer_listed or p.age(world.year) < 24 or p.age(world.year) > 33 or p.is_injured():
					continue
				if not (p.has_trait("mercenario") or p.has_trait("ambicioso") or p.trait_sum("greed") > 1.1):
					continue
				if best == null or p.overall > best.overall:
					best = p
			if best == null or best.overall < 62:
				return {}
			# Clube do Golfo que tenha o jogador no nível do elenco dele.
			var rich := MarketAI.realistic_suitor(world, best, 0.0, rng, 6.0,
				func(c: Club): return RICH_NATIONS.has(c.nation) and c.tier == 1)
			if rich == null:
				return {}
			ev["p"] = best.id
			ev["d"] = {"club": rich.id, "fee": Valuation.round_value(best.value * rng.randf_range(1.1, 1.4)),
				"their_wage": Valuation.round_wage(best.wage * rng.randf_range(2.5, 4.0)), "raise": Valuation.round_wage(best.wage * 1.35)}
		"want_leave":
			# Craque ambicioso com um clube maior de olho
			var star: Player = null
			for p: Player in squad:
				if p.transfer_listed or p.age(world.year) > 30 or p.squad_status > Player.STATUS_STARTER:
					continue
				if not (p.has_trait("ambicioso") or p.has_trait("estrela") or p.has_trait("competitivo")):
					continue
				if star == null or p.overall > star.overall:
					star = p
			if star == null:
				return {}
			# O sonho é um clube maior, mas ao alcance dele (um degrau acima, não o gigante europeu).
			var big := MarketAI.realistic_suitor(world, star, minf(club.reputation + 10.0, 92.0), rng, 6.0,
				func(c: Club): return c.tier == 1 and c.reputation > club.reputation)
			if big == null:
				return {}
			ev["p"] = star.id
			ev["d"] = {"club": big.id}
		"fight":
			# Briga no treino: pelo menos um esquentado
			var hot: Array = []
			for p: Player in squad:
				if HiddenPersona.hot_head(p) or p.has_trait("provocador") or p.hid("pol") >= 16:
					hot.append(p)
			if hot.is_empty() or squad.size() < 2:
				return {}
			var a1: Player = RngUtil.pick(rng, hot)
			var a2: Player = RngUtil.pick(rng, squad)
			for _t in 10:
				if a2.id != a1.id:
					break
				a2 = RngUtil.pick(rng, squad)
			if a2.id == a1.id:
				return {}
			ev["p"] = a1.id
			ev["p2"] = a2.id
			ev["d"] = {"fine": Valuation.round_wage(maxf(5000.0, a1.wage * 0.5))}
		"party":
			# Balada filmada: festeiros e quem acabou de perder têm mais chance
			var pool2: Array = []
			for q: Player in squad:
				if q.has_trait("festeiro") or q.has_trait("vaidoso") or (q.age(world.year) <= 25 and q.hid("pro") <= 8):
					pool2.append(q)
			if pool2.is_empty():
				return {}
			var pp: Player = RngUtil.pick(rng, pool2)
			ev["p"] = pp.id
			ev["d"] = {"fine": Valuation.round_wage(maxf(3000.0, pp.wage * 0.4)), "where": RngUtil.pick(rng, ["numa boate", "num aniversário de famoso", "num camarote de show", "numa festa em casa com dezenas de convidados"])}
		"betting":
			# Investigação de apostas (raro): quem tem pouca disciplina e muita polêmica
			var pool3: Array = []
			for q: Player in squad:
				if q.hid("pro") <= 7 or q.hid("pol") >= 14:
					pool3.append(q)
			if pool3.is_empty() or rng.randf() > 0.35:
				return {}
			ev["p"] = (RngUtil.pick(rng, pool3) as Player).id
		"baby":
			var pool4: Array = []
			for q: Player in squad:
				var a := q.age(world.year)
				if a >= 22 and a <= 35:
					pool4.append(q)
			if pool4.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, pool4) as Player).id
		"social":
			# Post polêmico: vaidosos, polêmicos e quem está fora do time
			var pool5: Array = []
			for q: Player in squad:
				if q.has_trait("vaidoso") or q.has_trait("polemico") or q.has_trait("provocador") or (q.squad_status <= Player.STATUS_STARTER and q.minutes_season < 180 and world.current_turn() > 6):
					pool5.append(q)
			if pool5.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, pool5) as Player).id
			ev["d"] = {"what": rng.randi_range(0, 2)}
		"extra":
			# Jovem dedicado pede treino extra com especialista
			var pool6: Array = []
			for q: Player in squad:
				if q.age(world.year) <= 23 and (q.has_trait("esforcado") or q.has_trait("perfeccionista") or q.hid("det") >= 15) and q.potential - q.overall >= 4:
					pool6.append(q)
			if pool6.is_empty():
				return {}
			var px: Player = RngUtil.pick(rng, pool6)
			ev["p"] = px.id
			ev["d"] = {"cost": Valuation.round_value(maxf(40000.0, float(FinanceManager.expected_revenue(club)) * 0.004))}
		"rebel":
			# O rebelde barrado que se recusa a treinar
			var pool7: Array = []
			for q: Player in squad:
				if (q.has_trait("rebelde") or q.has_trait("estrela") or HiddenPersona.hot_head(q)) and q.minutes_season < 360 and world.current_turn() > 4:
					pool7.append(q)
			if pool7.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, pool7) as Player).id
		"chairman":
			# Estrela bate de frente com o presidente (salário atrasado, renovação travada, venda forçada)
			var pool8: Array = []
			for q: Player in squad:
				if q.squad_status <= Player.STATUS_STARTER and (q.hid("pol") >= 11 or q.has_trait("estrela") or q.has_trait("lider") or club.balance < 0):
					pool8.append(q)
			if pool8.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, pool8) as Player).id
			ev["d"] = {"why": 0 if club.balance < 0 else rng.randi_range(1, 2)}
		"captain_meeting":
			if turn < 4:
				return {}
			var leaders: Array = []
			for q: Player in squad:
				if q.age(world.year) >= 27 and (q.has_trait("lider") or q.squad_status <= Player.STATUS_STARTER):
					leaders.append(q)
			if leaders.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, leaders) as Player).id
			ev["d"] = {"topic": rng.randi_range(0, 2)}
		"training_star":
			var hot: Array = []
			for q: Player in squad:
				if not q.is_injured() and q.form() >= 6.8 and q.morale >= 45.0:
					hot.append(q)
			if hot.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, hot) as Player).id
		"academy_path":
			var kid: Player = YouthManager.best_prospect(world, club)
			if kid == null or kid.age(world.year) > 20:
				return {}
			ev["p"] = kid.id
			ev["d"] = {"age": kid.age(world.year)}
		"media_leak":
			if turn < 5:
				return {}
			var nf := FixtureManager.next_fixture_for(world, club.id)
			if nf == null:
				return {}
			var no := world.club(nf.opponent_of(club.id))
			if no == null:
				return {}
			ev["d"] = {"opp": no.short_name, "what": rng.randi_range(0, 2)}
		"takeover":
			# Raro: investidores só aparecem de tempos em tempos e não logo depois de uma troca de dono.
			var own := WorldEvents.owner_of(world, club.id)
			if turn < 4 or rng.randf() > 0.25 or (not own.is_empty() and world.year - int(own.get("y", 0)) < WorldEvents.OWNER_COOLDOWN):
				return {}
			var revenue := float(FinanceManager.expected_revenue(club))
			ev["d"] = {"who": ClubEvents.investor_for(club, rng), "money": Valuation.round_value(revenue * rng.randf_range(0.8, 1.8) + maxi(0, -club.balance))}
		"stadium":
			if club.fan_base < club.capacity or world.stats.has("stadium_work"):
				return {}
			var seats := maxi(1000, int(club.capacity * 0.2 / 500.0) * 500)
			var cost := WorldEvents.stadium_cost(club, seats)
			if club.balance < cost * 1.2:
				return {}
			ev["d"] = {"seats": seats, "cost": cost}
	return ev


# ---------------------------------------------------------------------------
# Texto e opções
# ---------------------------------------------------------------------------

## {title, body, options: [{t, hint}], def}
static func describe(world: GameWorld, ev: Dictionary) -> Dictionary:
	var club := world.user_club()
	var p: Player = world.player(int(ev.get("p", -1)))
	var p2: Player = world.player(int(ev.get("p2", -1)))
	var d: Dictionary = ev.get("d", {})
	var pn := p.display_name() if p != null else "O jogador"
	match String(ev["k"]):
		"raise":
			return {"title": "%s quer aumento" % pn, "def": 2,
				"body": "%s, um dos pilares do time, acha que ganha pouco (%s/mês). O empresário pede %s por mês até o fim do contrato." % [pn, Fmt.money(p.wage if p != null else 0), Fmt.money(int(d.get("wage", 0)))],
				"options": [
					{"t": "Dar o aumento", "hint": "Salário vai a %s · moral lá em cima" % Fmt.money(int(d.get("wage", 0)))},
					{"t": "Prometer conversar na renovação", "hint": "Ganha tempo · moral sobe um pouco"},
					{"t": "Recusar", "hint": "Moral despenca · pode pedir para sair"}]}
		"minutes":
			return {"title": "%s quer jogar mais" % pn, "def": 2,
				"body": "%s bateu na sua porta: acha que merece mais chances e não quer passar a temporada no banco." % pn,
				"options": [
					{"t": "Prometer mais jogos", "hint": "Precisa ser titular 2 vezes nos próximos 5 jogos"},
					{"t": "Colocar na lista de transferências", "hint": "Ele vai atrás de outro clube"},
					{"t": "Pedir paciência", "hint": "Moral cai"}]}
		"sponsor":
			return {"title": "Proposta da %s" % d.get("brand", "patrocinadora"), "def": 2,
				"body": "A %s quer estampar a marca em ações do clube nesta temporada. Oferece dinheiro agora ou um bônus maior se a meta da diretoria for cumprida." % d.get("brand", ""),
				"options": [
					{"t": "Aceitar %s agora" % Fmt.money(int(d.get("lump", 0))), "hint": "Dinheiro garantido no caixa"},
					{"t": "Apostar no bônus de %s" % Fmt.money(int(d.get("bonus", 0))), "hint": "Só recebe se cumprir a meta no fim da temporada"},
					{"t": "Recusar", "hint": "Nada muda"}]}
		"press":
			var why := String(d.get("why", ""))
			var ctx := "Antes do clássico contra o %s" % d.get("opp", "") if why == "derby" else ("Depois da sequência de derrotas" if why == "crisis" else "Com o time embalado")
			return {"title": "Entrevista coletiva", "def": 1,
				"body": "%s, os repórteres querem saber: o que esperar do próximo jogo contra o %s?" % [ctx, d.get("opp", "")],
				"options": [
					{"t": "\"Vamos vencer, podem escrever.\"", "hint": "Moral e torcida sobem · se perder, a diretoria cobra"},
					{"t": "\"Respeito o adversário, jogo a jogo.\"", "hint": "Diretoria gosta da postura"},
					{"t": "\"O elenco precisa entregar mais.\"", "hint": "Diretoria aprova · elenco fica chateado"}]}
		"fans":
			return {"title": "Torcida na porta do CT", "def": 2,
				"body": "Um grupo de torcedores protesta contra a fase do %s e exige explicações." % club.short_name,
				"options": [
					{"t": "Receber uma comissão de torcedores", "hint": "Torcida acalma · diretoria acha arriscado"},
					{"t": "Prometer reação e reforços", "hint": "Torcida anima · a cobrança aumenta"},
					{"t": "Ignorar o protesto", "hint": "Torcida fica mais irritada"}]}
		"invest":
			var cost := int(d.get("cost", 0))
			return {"title": "Diretoria quer investir", "def": 2,
				"body": "Com o caixa positivo, a diretoria abre espaço para um investimento de %s. Onde aplicar?" % Fmt.money(cost),
				"options": [
					{"t": "Centro de treinamento", "hint": "Estrutura +6: recuperação e evolução melhores"},
					{"t": "Categorias de base", "hint": "Base +8: jovens melhores a cada ano"},
					{"t": "Guardar o dinheiro", "hint": "Caixa intacto"}]}
		"discipline":
			var what: String = ["foi flagrado em uma festa na véspera do treino", "chegou atrasado pela terceira vez na semana", "discutiu feio com o preparador físico", "postou críticas ao clube nas redes sociais"][int(d.get("what", 0)) % 4]
			return {"title": "Indisciplina: %s" % pn, "def": 2,
				"body": "%s %s. O elenco espera uma resposta do treinador." % [pn, what],
				"options": [
					{"t": "Multar", "hint": "Moral dele cai · elenco aprova"},
					{"t": "Afastar do próximo jogo", "hint": "Fica fora de uma partida"},
					{"t": "Deixar passar", "hint": "Ele agradece · o grupo não gosta"}]}
		"rival_bid":
			var buyer := world.club(int(d.get("club", -1)))
			return {"title": "%s sondado pelo %s" % [pn, buyer.short_name if buyer != null else "gigante"], "def": 0,
				"body": "O %s (%s) demonstrou interesse em %s. O jogador ficou balançado." % [buyer.name if buyer != null else "", DatabaseManager.nation_name(buyer.nation) if buyer != null else "", pn],
				"options": [
					{"t": "Inegociável", "hint": "Torcida vibra · ele pode ficar frustrado"},
					{"t": "Ouvir propostas", "hint": "Entra na lista de venda com preço alto"},
					{"t": "Conversar e valorizar o jogador", "hint": "Moral dele sobe"}]}
		"homesick":
			return {"title": "%s com saudade de casa" % pn, "def": 2,
				"body": "%s anda calado no vestiário. Longe da família, não se adaptou e o rendimento caiu. O staff sugere agir." % pn,
				"options": [
					{"t": "Trazer a família para cá", "hint": "Custa %s · moral e adaptação sobem" % Fmt.money(int(d.get("cost", 0)))},
					{"t": "Liberar uns dias em casa", "hint": "Fica fora do próximo jogo · volta renovado"},
					{"t": "Cobrar foco", "hint": "Nada muda no caixa · moral cai; os sensíveis podem pedir para sair"}]}
		"mercenary":
			var rich := world.club(int(d.get("club", -1)))
			return {"title": "Proposta milionária por %s" % pn, "def": 2,
				"body": "O %s (%s) oferece %s ao clube e um salário de %s/mês a %s, bem acima do que ele ganha aqui (%s). O jogador quer ouvir." % [
					rich.short_name if rich != null else "", DatabaseManager.nation_name(rich.nation) if rich != null else "", Fmt.money(int(d.get("fee", 0))),
					Fmt.money(int(d.get("their_wage", 0))), pn, Fmt.money(p.wage if p != null else 0)],
				"options": [
					{"t": "Vender", "hint": "Entra %s no caixa" % Fmt.money(int(d.get("fee", 0)))},
					{"t": "Segurar com aumento", "hint": "Salário vai a %s · ele fica, mas de olho" % Fmt.money(int(d.get("raise", 0)))},
					{"t": "Recusar", "hint": "Moral despenca e o rendimento pode cair"}]}
		"want_leave":
			var big := world.club(int(d.get("club", -1)))
			return {"title": "%s quer sair" % pn, "def": 2,
				"body": "%s avisou que sonha em jogar no %s e pediu para ser negociado. O vestiário acompanha como você vai lidar." % [pn, big.short_name if big != null else "exterior"],
				"options": [
					{"t": "Prometer um time para brigar por títulos", "hint": "Ele fica por ora · cobra resultado"},
					{"t": "Colocar à venda", "hint": "Entra na lista com preço de mercado"},
					{"t": "Segurar sem conversa", "hint": "Moral despenca · clima pesa no vestiário"}]}
		"fight":
			var n2 := p2.display_name() if p2 != null else "um companheiro"
			return {"title": "Briga no treino", "def": 2,
				"body": "%s e %s trocaram empurrões no treino de hoje e precisaram ser separados. O elenco espera uma resposta." % [pn, n2],
				"options": [
					{"t": "Multar os dois", "hint": "Multa de %s cada · os dois ficam chateados" % Fmt.money(int(d.get("fine", 0)))},
					{"t": "Afastar %s do próximo jogo" % pn, "hint": "Ele cumpre suspensão interna · o grupo aprova"},
					{"t": "Conversar e deixar passar", "hint": "Sem punição · entrosamento sofre"}]}
		"party":
			return {"title": "%s flagrado na balada" % pn, "def": 1,
				"body": "Um vídeo de %s %s, dois dias antes do jogo, viralizou. A torcida cobra e a imprensa quer saber o que o treinador vai fazer." % [pn, d.get("where", "numa festa")],
				"options": [
					{"t": "Multar e deixar no banco", "hint": "Multa de %s · ele fica fora de um jogo · grupo aprova" % Fmt.money(int(d.get("fine", 0)))},
					{"t": "Multar em particular", "hint": "Moral dele cai um pouco · torcida acha pouco"},
					{"t": "Defender o jogador", "hint": "Ele fica grato · torcida e diretoria reclamam"}]}
		"betting":
			return {"title": "%s investigado por apostas" % pn, "def": 1,
				"body": "A polícia e a justiça desportiva investigam apostas suspeitas ligadas a cartões de %s. Ainda não há acusação formal." % pn,
				"options": [
					{"t": "Afastar até a investigação acabar", "hint": "Fora por 3 jogos · protege o clube"},
					{"t": "Manter e apoiar publicamente", "hint": "Ele joga · se for punido, a suspensão é longa"},
					{"t": "Rescindir o contrato", "hint": "Sai sem custo · o elenco estranha a pressa"}]}
		"baby":
			return {"title": "Nasceu o filho de %s" % pn, "def": 0,
				"body": "%s pediu para acompanhar o nascimento do filho, justo na semana do próximo jogo." % pn,
				"options": [
					{"t": "Liberar", "hint": "Fica fora de um jogo · volta nas nuvens"},
					{"t": "Pedir que fique para o jogo", "hint": "Ele joga · a moral cai e o grupo não gosta"}]}
		"social":
			var what: String = ["uma indireta sobre ficar no banco", "um vídeo reclamando da tática", "curtidas em críticas ao treinador"][int(d.get("what", 0)) % 3]
			return {"title": "Polêmica nas redes: %s" % pn, "def": 1,
				"body": "%s postou %s. Os prints rodam os grupos de torcedores e a imprensa pergunta se há racha no elenco." % [pn, what],
				"options": [
					{"t": "Enquadrar em público", "hint": "Autoridade reforçada · ele fica chateado"},
					{"t": "Conversar em particular", "hint": "Clima acalma · parte da imprensa acha fraqueza"},
					{"t": "Ignorar", "hint": "Nada muda agora · outros podem se sentir à vontade"}]}
		"extra":
			return {"title": "%s quer treino extra" % pn, "def": 1,
				"body": "%s pediu para contratar um especialista e treinar depois do expediente. Custo: %s." % [pn, Fmt.money(int(d.get("cost", 0)))],
				"options": [
					{"t": "Bancar o especialista", "hint": "Evolui mais rápido · moral sobe"},
					{"t": "Agradecer e recusar", "hint": "Sem custo · ele fica um pouco frustrado"}]}
		"rebel":
			return {"title": "%s se recusa a treinar" % pn, "def": 0,
				"body": "Sem jogar, %s não apareceu no treino de hoje e mandou recado pelo empresário: quer ser titular ou sair." % pn,
				"options": [
					{"t": "Afastar do elenco por uma semana", "hint": "Fica fora de um jogo · o grupo apoia o treinador"},
					{"t": "Prometer minutos", "hint": "Ele volta · precisa começar 2 dos próximos 5 jogos"},
					{"t": "Colocar à venda", "hint": "Entra na lista de transferências"}]}
		"chairman":
			var why2: String = ["os salários atrasados", "a renovação que a diretoria travou", "a venda de um companheiro sem consultar o grupo"][int(d.get("why", 0)) % 3]
			return {"title": "%s bate de frente com o presidente" % pn, "def": 2,
				"body": "Em entrevista, %s criticou o presidente por %s. A diretoria ficou irritada e espera que o treinador se posicione." % [pn, why2],
				"options": [
					{"t": "Ficar do lado do jogador", "hint": "Elenco fecha com você · diretoria perde confiança"},
					{"t": "Ficar do lado da diretoria", "hint": "Presidente agradece · ele e parte do elenco se chateiam"},
					{"t": "Mediar uma reunião", "hint": "Clima melhora aos poucos · ninguém sai 100% satisfeito"}]}
		"medical":
			return {"title": "Departamento médico", "def": 1,
				"body": "O médico sugere um tratamento intensivo para acelerar a volta dos lesionados. Custo: %s." % Fmt.money(int(d.get("cost", 0))),
				"options": [
					{"t": "Pagar o tratamento", "hint": "Lesionados voltam 1 a 2 semanas antes"},
					{"t": "Seguir o tratamento normal", "hint": "Nada muda"}]}
		"friendly":
			return {"title": "Convite para amistoso", "def": 1,
				"body": "Um promotor oferece %s por um amistoso %s na próxima semana livre." % [Fmt.money(int(d.get("money", 0))), d.get("where", "")],
				"options": [
					{"t": "Aceitar", "hint": "Dinheiro no caixa · elenco mais cansado"},
					{"t": "Recusar", "hint": "Elenco descansa"}]}
		"dressing":
			var n2 := p2.display_name() if p2 != null else "o jovem"
			return {"title": "Briga no vestiário", "def": 2,
				"body": "%s, veterano do grupo, e %s bateram boca no treino. O clima pesou." % [pn, n2],
				"options": [
					{"t": "Apoiar %s" % pn, "hint": "Veterano fortalecido · jovem abalado"},
					{"t": "Apoiar %s" % n2, "hint": "Jovem fortalecido · veterano contrariado"},
					{"t": "Multar os dois", "hint": "Ambos chateados · grupo mais unido"}]}
		"tickets":
			return {"title": "Preço dos ingressos", "def": 2,
				"body": "O departamento comercial pergunta se é hora de mexer no preço dos ingressos (hoje %s)." % Fmt.money(FinanceManager.ticket_price(club)),
				"options": [
					{"t": "Aumentar 20%", "hint": "Mais receita por torcedor · torcida reclama"},
					{"t": "Reduzir 20%", "hint": "Estádio mais cheio · torcida feliz"},
					{"t": "Manter", "hint": "Nada muda"}]}
		"agent":
			return {"title": "Empresário oferece %s" % pn, "def": 1,
				"body": ("Um empresário oferece %s (%d anos, %s, sem clube). Ele assinaria por %s/mês por %d ano." if int(d.get("years", 1)) == 1 else "Um empresário oferece %s (%d anos, %s, sem clube). Ele assinaria por %s/mês por %d anos.") % [pn, p.age(world.year) if p != null else 0, Pos.NAMES[p.position] if p != null else "", Fmt.money(int(d.get("wage", 0))), int(d.get("years", 1))],
				"options": [
					{"t": "Contratar", "hint": "Chega sem custo de transferência"},
					{"t": "Dispensar", "hint": "Nada muda"}]}
		"youth_bid":
			var bidder := world.club(int(d.get("club", -1)))
			var bn := bidder.short_name if bidder != null else "gigante"
			var abroad := bidder != null and bidder.nation != club.nation
			return {"title": "%s quer %s, da base" % [bn, pn], "def": 2,
				"body": "O %s%s oferece %s por %s (%d anos, %s), que ainda nem estreou no profissional. O garoto e a família ficaram animados." % [
					bidder.name if bidder != null else "", (" (%s)" % DatabaseManager.nation_name(bidder.nation)) if abroad else "",
					Fmt.money(int(d.get("fee", 0))), pn, p.age(world.year) if p != null else 0, Pos.name_of(p.position).to_lower() if p != null else ""],
				"options": [
					{"t": "Vender", "hint": "%s no caixa · 20%% de uma venda futura" % Fmt.money(int(d.get("fee", 0)))},
					{"t": "Assinar o primeiro contrato profissional", "hint": "Sobe ao elenco com salário melhor · moral sobe"},
					{"t": "Recusar", "hint": "Fica na base · ele pode ficar frustrado"}]}
		"prodigy":
			return {"title": "Joia na base: %s" % pn, "def": 1,
				"body": "O coordenador da base diz que %s (%d anos) está pronto para treinar com os profissionais." % [pn, p.age(world.year) if p != null else 0],
				"options": [
					{"t": "Subir para o elenco", "hint": "Entra no time principal"},
					{"t": "Manter na base mais um tempo", "hint": "Segue evoluindo com a base"}]}
		"captain_meeting":
			var topic := int(d.get("topic", 0))
			var issue: String = ["o grupo sentiu a cobrança das últimas semanas", "alguns reservas estão ficando impacientes", "os mais jovens estão precisando de liderança"][topic % 3]
			return {"title": "O capitão pediu uma conversa", "def": 1,
				"body": "%s veio falar em nome do vestiário: %s. Ele quer saber como você pretende conduzir o grupo." % [pn, issue],
				"options": [
					{"t": "Abrir o jogo com o elenco", "hint": "Confiança do grupo sobe · você divide a responsabilidade"},
					{"t": "Pedir que o capitão acalme o vestiário", "hint": "Liderança dele ganha peso · efeito moderado"},
					{"t": "Dizer que cada um deve cuidar do próprio trabalho", "hint": "Autoridade sobe · moral do grupo pode cair"}]}
		"training_star":
			return {"title": "%s voando no treino" % pn, "def": 1,
				"body": "A comissão destacou %s como o melhor dos últimos treinos. Intensidade, confiança e execução chamaram atenção." % pn,
				"options": [
					{"t": "Prometer uma chance no time", "hint": "Precisa começar 1 dos próximos 3 jogos"},
					{"t": "Elogiar e manter a disputa aberta", "hint": "Moral sobe sem promessa"},
					{"t": "Manter a hierarquia", "hint": "Sem promessa · ele pode se frustrar"}]}
		"academy_path":
			return {"title": "Plano para %s" % pn, "def": 1,
				"body": "A base quer uma definição para %s, de %d anos. O garoto está evoluindo e pergunta qual é o próximo passo." % [pn, int(d.get("age", 0))],
				"options": [
					{"t": "Integrar aos treinos do profissional", "hint": "Moral e desenvolvimento sobem"},
					{"t": "Manter na base com plano individual", "hint": "Desenvolvimento sobe um pouco"},
					{"t": "Dizer que ainda não está pronto", "hint": "Sem mudança técnica · moral cai"}]}
		"media_leak":
			var leak: String = ["a provável escalação", "uma mudança tática treinada a portas fechadas", "a lista de jogadores poupados"][int(d.get("what", 0)) % 3]
			return {"title": "Vazamento antes do jogo", "def": 1,
				"body": "A imprensa publicou %s para o jogo contra o %s. A informação saiu de dentro do clube." % [leak, d.get("opp", "adversário")],
				"options": [
					{"t": "Mudar o plano de última hora", "hint": "Evita previsibilidade · grupo perde um pouco de confiança"},
					{"t": "Manter o plano e blindar o elenco", "hint": "Confiança do grupo sobe"},
					{"t": "Abrir investigação interna", "hint": "Diretoria aprova · ambiente fica tenso"}]}
		"takeover":
			var saf := club.nation == "BRA"
			return {"title": "Proposta de compra do clube", "def": 1,
				"body": "%s quer comprar o %s%s e promete %s em investimentos. Antes da votação no conselho, o presidente quer ouvir o treinador." % [
					d.get("who", "Um investidor"), club.short_name, " e transformá-lo em SAF" if saf else "", Fmt.money(int(d.get("money", 0)))],
				"options": [
					{"t": "Apoiar a venda", "hint": "Dinheiro novo e dívida quitada · o dono vai cobrar títulos"},
					{"t": "Ficar neutro", "hint": "O conselho decide sozinho (metade das vezes aprova)"},
					{"t": "Ser contra", "hint": "Venda barrada · a torcida gosta, a diretoria nem tanto"}]}
		"stadium":
			return {"title": "Ampliar o estádio?", "def": 1,
				"body": "O %s vive lotado e a diretoria estuda ampliar: +%d lugares por %s. As obras ficam prontas na próxima temporada." % [
					club.stadium, int(d.get("seats", 0)), Fmt.money(int(d.get("cost", 0)))],
				"options": [
					{"t": "Aprovar a ampliação", "hint": "Paga agora · mais público e bilheteria no ano que vem"},
					{"t": "Adiar", "hint": "Caixa intacto"}]}
	return {"title": "Evento", "body": "", "options": [{"t": "OK", "hint": ""}], "def": 0}


# ---------------------------------------------------------------------------
# Consequências
# ---------------------------------------------------------------------------

## Aplica a escolha `opt` e retira o evento. Retorna o texto do resultado.
static func resolve(world: GameWorld, ev: Dictionary, opt: int) -> String:
	world.events.erase(ev)
	var club := world.user_club()
	var p: Player = world.player(int(ev.get("p", -1)))
	var p2: Player = world.player(int(ev.get("p2", -1)))
	var d: Dictionary = ev.get("d", {})
	var turn := world.current_turn()
	var msg := ""
	match String(ev["k"]):
		"raise":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					p.wage = int(d.get("wage", p.wage))
					_morale(p, 18.0)
					msg = "%s ganhou o aumento e está motivado." % p.display_name()
				1:
					_morale(p, 4.0)
					msg = "%s aceitou esperar a renovação — por enquanto." % p.display_name()
				_:
					_morale(p, -18.0)
					p.unhappy_weeks += 3
					if world.rng.randf() < 0.3:
						p.transfer_listed = true
						p.asking_price = TransferManager.asking_price(world, p)
						msg = "%s ficou revoltado e pediu para ser negociado." % p.display_name()
					else:
						msg = "%s não gostou nada da resposta." % p.display_name()
		"minutes":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					_morale(p, 10.0)
					world.promises.append({"k": "minutes", "p": p.id, "until": turn + 5, "need": 2, "s0": p.stat(Player.S_STARTS) + _cup_starts(p)})
					msg = "Promessa feita: %s precisa começar 2 dos próximos 5 jogos." % p.display_name()
				1:
					p.transfer_listed = true
					p.asking_price = TransferManager.asking_price(world, p)
					_morale(p, -3.0)
					msg = "%s está na lista de transferências." % p.display_name()
				_:
					_morale(p, -10.0)
					msg = "%s vai esperar, mas não está feliz." % p.display_name()
		"sponsor":
			match opt:
				0:
					club.add_ledger("patrocinio", int(d.get("lump", 0)))
					msg = "Contrato assinado: %s no caixa." % Fmt.money(int(d.get("lump", 0)))
				1:
					world.stats["sponsor_bonus"] = int(d.get("bonus", 0))
					msg = "Acordo feito: %s se a meta for cumprida." % Fmt.money(int(d.get("bonus", 0)))
				_:
					msg = "Proposta recusada."
		"press":
			match opt:
				0:
					_team_morale(world, club, 5.0)
					club.fan_mood = clampf(club.fan_mood + 3.0, 0.0, 100.0)
					world.stats["press_bold"] = turn
					msg = "A frase virou manchete. Agora é vencer."
				1:
					club.board_confidence = clampf(club.board_confidence + 2.0, 0.0, 100.0)
					msg = "Postura elogiada pela diretoria."
				_:
					_team_morale(world, club, -4.0)
					club.board_confidence = clampf(club.board_confidence + 3.0, 0.0, 100.0)
					msg = "O recado foi dado. O vestiário sentiu."
		"fans":
			match opt:
				0:
					club.fan_mood = clampf(club.fan_mood + 10.0, 0.0, 100.0)
					club.board_confidence = clampf(club.board_confidence - 2.0, 0.0, 100.0)
					msg = "A conversa acalmou os ânimos da torcida."
				1:
					club.fan_mood = clampf(club.fan_mood + 6.0, 0.0, 100.0)
					club.board_confidence = clampf(club.board_confidence - 1.0, 0.0, 100.0)
					msg = "A torcida vai cobrar a promessa."
				_:
					club.fan_mood = clampf(club.fan_mood - 6.0, 0.0, 100.0)
					msg = "O protesto cresceu nas redes."
		"invest":
			var cost := int(d.get("cost", 0))
			match opt:
				0:
					club.add_ledger("investimentos", -cost)
					club.facilities = mini(100, club.facilities + 6)
					msg = "Obras no CT começam amanhã. Estrutura: %d." % club.facilities
				1:
					club.add_ledger("investimentos", -cost)
					club.youth_level = mini(100, club.youth_level + 8)
					msg = "A base ganhou reforço. Nível da base: %d." % club.youth_level
				_:
					msg = "Dinheiro guardado."
		"discipline":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					_morale(p, -8.0)
					_team_morale(world, club, 1.0)
					msg = "%s foi multado." % p.display_name()
				1:
					p.suspension = maxi(p.suspension, 1)
					world.mark_suspended(p)
					_morale(p, -5.0)
					msg = "%s está fora do próximo jogo." % p.display_name()
				_:
					_morale(p, 3.0)
					_team_morale(world, club, -2.0)
					msg = "Nada de punição. Parte do grupo torceu o nariz."
		"rival_bid":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					club.fan_mood = clampf(club.fan_mood + 4.0, 0.0, 100.0)
					_morale(p, -8.0 if p.trait_sum("ambition") > 10.0 else -2.0)
					msg = "%s é inegociável. A torcida aprovou." % p.display_name()
				1:
					p.transfer_listed = true
					p.asking_price = int(TransferManager.asking_price(world, p) * 1.2)
					msg = "%s está à venda por %s." % [p.display_name(), Fmt.money(p.asking_price)]
				_:
					_morale(p, 6.0)
					msg = "%s se sentiu valorizado." % p.display_name()
		"homesick":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					club.add_ledger("outros", -int(d.get("cost", 0)))
					_morale(p, 18.0)
					msg = "A família de %s chegou. Ele está bem mais animado." % p.display_name()
				1:
					p.injury_weeks = maxi(p.injury_weeks, 1)
					p.injury_name = "Folga para visitar a família"
					_morale(p, 12.0)
					msg = "%s vai passar uns dias em casa e volta na semana que vem." % p.display_name()
				_:
					var sens := p.has_trait("timido") or p.has_trait("inseguro")
					_morale(p, -12.0 if sens else -5.0)
					if sens and p.morale < 30.0:
						p.transfer_listed = true
						p.asking_price = TransferManager.asking_price(world, p)
						msg = "%s não aguentou a pressão e pediu para voltar ao país dele. Está à venda." % p.display_name()
					else:
						msg = "%s ouviu a cobrança em silêncio." % p.display_name()
		"mercenary":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			var rich := world.club(int(d.get("club", -1)))
			match opt:
				0:
					if rich == null:
						return "A proposta caiu."
					TransferManager.complete_transfer(world, p, rich, int(d.get("fee", 0)), int(d.get("their_wage", p.wage)), 3)
					msg = "%s foi vendido ao %s por %s." % [p.display_name(), rich.short_name, Fmt.money(int(d.get("fee", 0)))]
				1:
					p.wage = maxi(p.wage, int(d.get("raise", p.wage)))
					_morale(p, 6.0)
					msg = "%s aceitou ficar com o aumento. Salário: %s/mês." % [p.display_name(), Fmt.money(p.wage)]
				_:
					_morale(p, -20.0 if p.has_trait("mercenario") else -12.0)
					msg = "%s ficou muito contrariado com a recusa." % p.display_name()
		"want_leave":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			match opt:
				0:
					_morale(p, 4.0)
					msg = "%s aceitou esperar, mas vai cobrar resultado." % p.display_name()
				1:
					p.transfer_listed = true
					p.asking_price = TransferManager.asking_price(world, p)
					_morale(p, 8.0)
					msg = "%s está à venda por %s." % [p.display_name(), Fmt.money(p.asking_price)]
				_:
					_morale(p, -22.0)
					club.cohesion = maxf(20.0, club.cohesion - 3.0)
					msg = "%s ficou revoltado. O clima no vestiário pesou." % p.display_name()
		"fight":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			var fine := int(d.get("fine", 0))
			match opt:
				0:
					club.add_ledger("outros", fine * (2 if p2 != null else 1))
					_morale(p, -6.0)
					if p2 != null:
						_morale(p2, -6.0)
					club.cohesion = minf(100.0, club.cohesion + 1.0)
					msg = "Os dois foram multados. O recado foi dado."
				1:
					p.suspension = maxi(p.suspension, 1)
					_morale(p, -10.0)
					if p2 != null:
						_morale(p2, 3.0)
					club.cohesion = minf(100.0, club.cohesion + 2.0)
					msg = "%s está fora do próximo jogo. O grupo aprovou." % p.display_name()
				_:
					club.cohesion = maxf(20.0, club.cohesion - 4.0)
					if p2 != null:
						_morale(p2, -5.0)
					msg = "Ficou tudo por isso mesmo. Parte do elenco não gostou."
		"medical":
			if opt == 0:
				club.add_ledger("investimentos", -int(d.get("cost", 0)))
				var n := 0
				for q: Player in world.squad(club):
					if q.injury_weeks > 0:
						q.injury_weeks = maxi(0, q.injury_weeks - world.rng.randi_range(1, 2))
						if q.injury_weeks == 0:
							q.injury_name = ""
						n += 1
				msg = ("Tratamento intensivo para %d jogador." if n == 1 else "Tratamento intensivo para %d jogadores.") % n
			else:
				msg = "Tratamento normal mantido."
		"friendly":
			if opt == 0:
				club.add_ledger("bilheteria", int(d.get("money", 0)))
				for q: Player in world.squad(club):
					q.condition = maxf(55.0, q.condition - 7.0)
					world.mark_tired(q)
				msg = "Amistoso %s: %s no caixa." % [d.get("where", ""), Fmt.money(int(d.get("money", 0)))]
			else:
				msg = "Elenco descansando."
		"dressing":
			if p == null or p2 == null:
				return "A situação se resolveu sozinha."
			match opt:
				0:
					_morale(p, 5.0)
					_morale(p2, -10.0)
					_team_morale(world, club, 1.0)
					msg = "Você fechou com %s." % p.display_name()
				1:
					_morale(p2, 7.0)
					_morale(p, -10.0)
					msg = "Você fechou com %s." % p2.display_name()
				_:
					_morale(p, -5.0)
					_morale(p2, -5.0)
					_team_morale(world, club, 2.0)
					msg = "Os dois pagaram multa e o grupo se uniu."
		"tickets":
			match opt:
				0:
					club.ticket_mult = clampf(club.ticket_mult * 1.2, 0.5, 2.5)
					club.fan_mood = clampf(club.fan_mood - 6.0, 0.0, 100.0)
					msg = "Ingressos mais caros: %s." % Fmt.money(FinanceManager.ticket_price(club))
				1:
					club.ticket_mult = clampf(club.ticket_mult * 0.8, 0.5, 2.5)
					club.fan_mood = clampf(club.fan_mood + 6.0, 0.0, 100.0)
					msg = "Ingressos mais baratos: %s." % Fmt.money(FinanceManager.ticket_price(club))
				_:
					msg = "Preços mantidos."
		"agent":
			if opt == 0 and p != null and p.club_id < 0:
				var r := TransferManager.user_sign_free(world, p, int(d.get("wage", p.wage)), int(d.get("years", 1)))
				msg = String(r.get("msg", ""))
			else:
				msg = "Proposta dispensada."
		"youth_bid":
			if p == null or not world.academy.has(p.id):
				return "Ele já não está na base."
			var skip_b: Dictionary = world.stats.get("yb_skip", {})
			skip_b[str(p.id)] = world.year
			world.stats["yb_skip"] = skip_b
			match opt:
				0:
					msg = YouthManager.sell(world, p, world.club(int(d.get("club", -1))), int(d.get("fee", 0)))
				1:
					msg = YouthManager.promote(world, p)
					if not world.academy.has(p.id):
						p.wage = Valuation.round_wage(p.wage * 1.6)
						p.contract_end = world.year + 4
						_morale(p, 10.0)
				_:
					_morale(p, -16.0 if p.trait_sum("ambition") > 10.0 else -8.0)
					msg = "%s fica na base. O garoto sentiu o golpe." % p.display_name()
		"prodigy":
			if p != null and opt == 0:
				msg = YouthManager.promote(world, p)
			else:
				if p != null:
					p.dev_acc += 0.5
					var skip: Array = world.stats.get("ev_skip", [])
					skip.append(p.id)
					world.stats["ev_skip"] = skip
				msg = "Ele segue na base."
		"captain_meeting":
			if p == null or p.club_id != club.id:
				return "O capitão já não está no clube."
			match opt:
				0:
					_team_morale(world, club, 5.0)
					People.add_trust(world, p, 6.0)
					msg = "A conversa franca foi bem recebida pelo grupo."
				1:
					_team_morale(world, club, 2.0)
					People.add_trust(world, p, 4.0)
					msg = "%s assumiu a responsabilidade de conversar com o elenco." % p.display_name()
				_:
					_team_morale(world, club, -4.0)
					club.board_confidence = clampf(club.board_confidence + 1.0, 0.0, 100.0)
					msg = "O recado foi firme, mas parte do vestiário não gostou."
		"training_star":
			if p == null or p.club_id != club.id:
				return "O jogador já não está no clube."
			match opt:
				0:
					_morale(p, 9.0)
					world.promises.append({"k": "minutes", "p": p.id, "until": turn + 3, "need": 1, "s0": p.stat(Player.S_STARTS) + _cup_starts(p)})
					msg = "Promessa feita: %s terá uma chance nos próximos 3 jogos." % p.display_name()
				1:
					_morale(p, 6.0)
					People.add_trust(world, p, 3.0)
					msg = "%s saiu motivado da conversa." % p.display_name()
				_:
					_morale(p, -3.0)
					msg = "%s entendeu, mas esperava uma recompensa pelo treino." % p.display_name()
		"academy_path":
			if p == null:
				return "O jogador já não está disponível."
			match opt:
				0:
					p.dev_acc += 0.8
					_morale(p, 8.0)
					msg = "%s passa a treinar mais perto do elenco profissional." % p.display_name()
				1:
					p.dev_acc += 0.45
					_morale(p, 3.0)
					msg = "A base montou um plano individual para %s." % p.display_name()
				_:
					_morale(p, -5.0)
					msg = "%s ficou decepcionado, mas segue trabalhando na base." % p.display_name()
		"media_leak":
			match opt:
				0:
					_team_morale(world, club, -2.0)
					msg = "A comissão ajustou o plano. O adversário terá menos certezas, mas o grupo sentiu a mudança."
				1:
					_team_morale(world, club, 3.0)
					msg = "Você manteve a ideia e blindou o elenco publicamente."
				_:
					club.board_confidence = clampf(club.board_confidence + 2.0, 0.0, 100.0)
					_team_morale(world, club, -1.0)
					msg = "A diretoria abriu uma investigação interna sobre o vazamento."
		"takeover":
			var sold := opt == 0 or (opt == 1 and world.rng.randf() < 0.5)
			if sold:
				var paid := WorldEvents.takeover(world, club, String(d.get("who", "Investidor")))
				msg = "Venda aprovada: %s entram no clube e a verba para contratações subiu." % Fmt.money(paid)
			elif opt == 2:
				club.fan_mood = clampf(club.fan_mood + 5.0, 0.0, 100.0)
				club.board_confidence = clampf(club.board_confidence - 3.0, 0.0, 100.0)
				msg = "O conselho barrou a venda. A torcida aplaudiu sua posição."
			else:
				msg = "O conselho recusou a proposta."
		"party", "betting", "baby", "social", "extra", "rebel", "chairman":
			if p == null or p.club_id != club.id:
				return "Ele já não está no clube."
			msg = _resolve_player_event(world, club, p, String(ev["k"]), opt, d, turn)
		"stadium":
			var cost := int(d.get("cost", 0))
			if opt == 0 and club.balance >= cost:
				club.add_ledger("investimentos", -cost)
				world.stats["stadium_work"] = int(d.get("seats", 0))
				msg = "Obras aprovadas: +%d lugares na próxima temporada." % int(d.get("seats", 0))
			else:
				msg = "Ampliação adiada."
	return msg


static func _resolve_player_event(world: GameWorld, club: Club, p: Player, k: String, opt: int, d: Dictionary, turn: int) -> String:
	var pn := p.display_name()
	match k:
		"party":
			match opt:
				0:
					p.suspension = maxi(p.suspension, 1)
					world.mark_suspended(p)
					_morale(p, -8.0)
					_team_morale(world, club, 1.0)
					return "%s foi multado e fica fora do próximo jogo." % pn
				1:
					_morale(p, -3.0)
					club.fan_mood = clampf(club.fan_mood - 2.0, 0.0, 100.0)
					return "Multa discreta. A torcida esperava mais rigor."
				_:
					_morale(p, 6.0)
					club.fan_mood = clampf(club.fan_mood - 4.0, 0.0, 100.0)
					club.board_confidence = clampf(club.board_confidence - 3.0, 0.0, 100.0)
					return "Você defendeu %s. Ele agradeceu; a torcida e a diretoria, não." % pn
		"betting":
			var guilty := world.rng.randf() < (0.55 if p.hid("pro") <= 5 else 0.3)
			match opt:
				0:
					p.suspension = maxi(p.suspension, 3)
					world.mark_suspended(p)
					if guilty:
						p.suspension = maxi(p.suspension, 10)
						return "Afastado por precaução; a investigação confirmou a suspeita e %s pegou 10 jogos de suspensão." % pn
					return "%s ficou fora de 3 jogos e foi inocentado." % pn
				1:
					if guilty:
						p.suspension = maxi(p.suspension, 12)
						world.mark_suspended(p)
						club.board_confidence = clampf(club.board_confidence - 6.0, 0.0, 100.0)
						return "A justiça puniu %s com 12 jogos de suspensão. O apoio público pegou mal." % pn
					_morale(p, 8.0)
					return "Nada foi provado contra %s, que agradeceu o apoio." % pn
				_:
					TransferManager.release_free(world, p)
					_team_morale(world, club, -2.0)
					return "Contrato de %s rescindido." % pn
		"baby":
			if opt == 0:
				p.suspension = maxi(p.suspension, 1)
				world.mark_suspended(p)
				_morale(p, 12.0)
				_team_morale(world, club, 1.0)
				return "%s foi liberado e volta radiante." % pn
			_morale(p, -10.0)
			_team_morale(world, club, -1.5)
			return "%s ficou para o jogo, mas a cabeça está longe." % pn
		"social":
			match opt:
				0:
					_morale(p, -7.0)
					_team_morale(world, club, 1.0)
					return "Enquadrado em público. O recado foi dado ao grupo todo."
				1:
					_morale(p, 3.0)
					return "Conversa franca. %s apagou o post." % pn
				_:
					_team_morale(world, club, -1.5)
					return "Você ignorou. A polêmica esfriou, mas a hierarquia sofreu."
		"extra":
			if opt == 0:
				var cost := int(d.get("cost", 0))
				club.add_ledger("investimentos", -cost)
				PlayerDevelopment.apply_growth(world, p, world.rng.randf_range(0.6, 1.4))
				_morale(p, 6.0)
				return "%s treina com o especialista e já mostra evolução." % pn
			_morale(p, -3.0)
			return "%s entendeu, mas ficou frustrado." % pn
		"rebel":
			match opt:
				0:
					p.suspension = maxi(p.suspension, 1)
					world.mark_suspended(p)
					_morale(p, -10.0)
					_team_morale(world, club, 1.5)
					return "%s afastado por uma semana. O grupo apoiou." % pn
				1:
					_morale(p, 10.0)
					world.promises.append({"k": "minutes", "p": p.id, "until": turn + 5, "need": 2, "s0": p.stat(Player.S_STARTS) + _cup_starts(p)})
					return "%s voltou aos treinos com a promessa de jogar." % pn
				_:
					p.transfer_listed = true
					p.asking_price = TransferManager.asking_price(world, p)
					_morale(p, -4.0)
					return "%s está à venda." % pn
		"chairman":
			match opt:
				0:
					_team_morale(world, club, 3.0)
					_morale(p, 8.0)
					club.board_confidence = clampf(club.board_confidence - 8.0, 0.0, 100.0)
					return "Você ficou com o jogador. O vestiário fechou com você; o presidente não gostou."
				1:
					_morale(p, -12.0)
					_team_morale(world, club, -2.0)
					club.board_confidence = clampf(club.board_confidence + 5.0, 0.0, 100.0)
					return "Você apoiou a diretoria. %s ficou isolado." % pn
				_:
					_morale(p, 3.0)
					club.board_confidence = clampf(club.board_confidence + 1.0, 0.0, 100.0)
					return "Reunião feita. As partes baixaram o tom."
	return ""


static func _morale(p: Player, delta: float) -> void:
	p.morale = clampf(p.morale + delta, 0.0, 100.0)


static func _team_morale(world: GameWorld, club: Club, delta: float) -> void:
	for p: Player in world.squad(club):
		_morale(p, delta)


static func _cup_starts(p: Player) -> int:
	var n := 0
	for k in p.cup_stats:
		n += int(p.cup_stats[k][Player.C_APPS])
	return n


## Eventos que ninguém respondeu valem a opção padrão.
static func _expire(world: GameWorld, turn: int) -> void:
	for ev in world.events.duplicate():
		if int(ev["exp"]) <= turn:
			var desc := describe(world, ev)
			var msg := resolve(world, ev, int(desc.get("def", 0)))
			NewsManager.post_raw(world, "Sem resposta: %s" % desc["title"], msg, world.user_club_id, int(ev.get("p", -1)), NewsEvent.IMP_NORMAL)


## Promessas feitas aos jogadores: cumpridas ou quebradas.
static func _check_promises(world: GameWorld, turn: int, result: String) -> void:
	for pr in world.promises.duplicate():
		var p: Player = world.player(int(pr["p"]))
		if p == null or p.club_id != world.user_club_id:
			world.promises.erase(pr)
			continue
		var starts := p.stat(Player.S_STARTS) + _cup_starts(p) - int(pr["s0"])
		if starts >= int(pr["need"]):
			world.promises.erase(pr)
			_morale(p, 6.0)
			People.add_trust(world, p, 8.0)
			NewsManager.post_raw(world, "Promessa cumprida", "%s ganhou as chances prometidas e está satisfeito." % p.display_name(), world.user_club_id, p.id, NewsEvent.IMP_NORMAL)
		elif turn >= int(pr["until"]):
			world.promises.erase(pr)
			_morale(p, -22.0)
			People.add_trust(world, p, -18.0)
			p.unhappy_weeks += 4
			NewsManager.post_raw(world, "Promessa quebrada", "%s não recebeu as chances prometidas e perdeu a confiança no treinador." % p.display_name(), world.user_club_id, p.id, NewsEvent.IMP_HIGH)
	var bold := int(world.stats.get("press_bold", -1))
	if bold >= 0 and turn > bold:
		world.stats.erase("press_bold")
		var club := world.user_club()
		if result == "D":
			club.board_confidence = clampf(club.board_confidence - 4.0, 0.0, 100.0)
			club.fan_mood = clampf(club.fan_mood - 4.0, 0.0, 100.0)
			NewsManager.post_raw(world, "A promessa voltou para cobrar", "O treinador garantiu a vitória e o %s perdeu. A diretoria não gostou." % club.short_name, club.id, -1, NewsEvent.IMP_NORMAL)
		elif result == "V":
			club.fan_mood = clampf(club.fan_mood + 3.0, 0.0, 100.0)


## Acontecimentos sem escolha: deixam o mundo vivo.
static func _random_happenings(world: GameWorld) -> void:
	var club := world.user_club()
	var rng := world.rng
	if rng.randf() < 0.06:
		var squad: Array = world.squad(club)
		var fit: Array = []
		for p: Player in squad:
			if not p.is_injured():
				fit.append(p)
		if not fit.is_empty():
			var p: Player = RngUtil.pick(rng, fit)
			p.injury_weeks = rng.randi_range(1, 3)
			p.injury_name = RngUtil.pick(rng, ["Torção no tornozelo (treino)", "Dor muscular (treino)", "Pancada no joelho (treino)", "Contusão no pé (treino)"])
			NewsManager.on_injury(world, p)
			InboxManager.on_injury(world, p)
	elif rng.randf() < 0.035:
		# Virose ou gripe: um ou mais jogadores de molho por uma semana
		var squad2: Array = world.squad(club)
		var fit2: Array = []
		for p: Player in squad2:
			if not p.is_injured():
				fit2.append(p)
		if not fit2.is_empty():
			var ill: String = RngUtil.pick(rng, ["Virose", "Gripe forte", "Intoxicação alimentar", "Amigdalite"])
			var n_ill := 1 if ill == "Amigdalite" else rng.randi_range(1, 3)
			var names: Array = []
			for _i in n_ill:
				if fit2.is_empty():
					break
				var p: Player = fit2.pop_at(rng.randi_range(0, fit2.size() - 1))
				p.injury_weeks = 1
				p.injury_name = ill
				p.condition = maxf(40.0, p.condition - 20.0)
				names.append(p.display_name())
			NewsManager.post_raw(world, "%s no elenco" % ill, "%s %s fora do próximo jogo: %s." % [", ".join(names), "está" if names.size() == 1 else "estão", ill.to_lower()], club.id, -1, NewsEvent.IMP_NORMAL)
	elif rng.randf() < 0.04:
		var squad: Array = world.squad(club)
		if not squad.is_empty():
			var p: Player = RngUtil.pick(rng, squad)
			var what: String = RngUtil.pick(rng, ["visitou um hospital infantil e virou assunto nas redes", "bancou a reforma do campinho onde começou", "foi homenageado na cidade natal", "viralizou com um golaço no treino"])
			_morale(p, 5.0)
			club.fan_mood = clampf(club.fan_mood + 2.0, 0.0, 100.0)
			NewsManager.post_raw(world, "%s em alta" % p.display_name(), "%s %s." % [p.display_name(), what], club.id, p.id, NewsEvent.IMP_NORMAL)


## Fim de temporada: bônus de patrocínio condicionado à meta.
static func on_season_end(world: GameWorld, goal_met: bool) -> void:
	var bonus := int(world.stats.get("sponsor_bonus", 0))
	world.stats.erase("sponsor_bonus")
	world.promises.clear()
	if bonus > 0 and world.has_user():
		var club := world.user_club()
		if goal_met:
			club.add_ledger("patrocinio", bonus)
			NewsManager.post_raw(world, "Bônus do patrocinador", "Meta cumprida: o patrocinador pagou %s de bônus." % Fmt.money(bonus), club.id, -1, NewsEvent.IMP_HIGH)
		else:
			NewsManager.post_raw(world, "Sem bônus do patrocinador", "A meta não foi cumprida e o bônus de %s ficou pelo caminho." % Fmt.money(bonus), club.id, -1, NewsEvent.IMP_NORMAL)