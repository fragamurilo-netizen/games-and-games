class_name EventManager
extends RefCounted
## Eventos da carreira: dilemas com escolhas (aumento, minutos, patrocínio, imprensa, torcida,
## investimentos, indisciplina, sondagens, departamento médico, amistosos, vestiário, ingressos,
## empresários, joias da base) e acontecimentos sem escolha (lesão no treino, homenagens...).
##
## Um evento pendente é um dicionário salvo em world.events:
##   {id, k (tipo), turn (criado), exp (expira no jogo), p (jogador), p2 (outro jogador), d (dados)}
## O texto e as opções são montados na hora (describe) a partir dos dados; resolver aplica as
## consequências e devolve uma frase para a interface. Ao expirar vale a opção padrão.

const MAX_PENDING := 3
const COOLDOWN := 7 # jogos entre dois eventos do mesmo tipo
const LIFETIME := 3 # jogos para decidir

const KINDS := {
	"raise": {"w": 1.2, "icon": "money", "color": "ORANGE"},
	"minutes": {"w": 1.0, "icon": "clock", "color": "ORANGE"},
	"sponsor": {"w": 0.8, "icon": "money", "color": "GREEN"},
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
}


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
	if world.events.size() >= MAX_PENDING:
		return out
	var p_new := 0.3 if world.events.is_empty() else 0.14
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
				if p.has_trait("festeiro") or p.has_trait("rebelde") or p.has_trait("temperamental") or (p.age(world.year) <= 24 and rng.randf() < 0.1):
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
			var buyer: Club = null
			for tries in 30:
				var c: Club = RngUtil.pick(rng, world.clubs)
				if c.id != club.id and c.reputation >= club.reputation + 8.0 and c.tier == 1:
					buyer = c
					break
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
			if world.season.day < 4:
				return {}
		"agent":
			var need := TransferManager.squad_needs(world, club)
			var best: Player = null
			for p: Player in world.free_agents():
				if p.age(world.year) > 32:
					continue
				var fits := need.is_empty() or need.has(p.position)
				if fits and (best == null or p.overall > best.overall):
					best = p
			if best == null or club.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
				return {}
			ev["p"] = best.id
			ev["d"] = {"wage": TransferManager.wage_ask(world, best, club), "years": TransferManager.preferred_years(world, best)}
		"prodigy":
			var kid: Player = YouthManager.best_prospect(world, club)
			if kid == null or Array(world.stats.get("ev_skip", [])).has(kid.id):
				return {}
			ev["p"] = kid.id
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
				"body": "Um empresário oferece %s (%d anos, %s, sem clube). Ele assinaria por %s/mês por %d ano(s)." % [pn, p.age(world.year) if p != null else 0, Pos.NAMES[p.position] if p != null else "", Fmt.money(int(d.get("wage", 0))), int(d.get("years", 1))],
				"options": [
					{"t": "Contratar", "hint": "Chega sem custo de transferência"},
					{"t": "Dispensar", "hint": "Nada muda"}]}
		"prodigy":
			return {"title": "Joia na base: %s" % pn, "def": 1,
				"body": "O coordenador da base diz que %s (%d anos) está pronto para treinar com os profissionais." % [pn, p.age(world.year) if p != null else 0],
				"options": [
					{"t": "Subir para o elenco", "hint": "Entra no time principal"},
					{"t": "Manter na base mais um tempo", "hint": "Segue evoluindo com a base"}]}
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
				msg = "Tratamento intensivo para %d jogador(es)." % n
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
	return msg


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
			NewsManager.post_raw(world, "Promessa cumprida", "%s ganhou as chances prometidas e está satisfeito." % p.display_name(), world.user_club_id, p.id, NewsEvent.IMP_NORMAL)
		elif turn >= int(pr["until"]):
			world.promises.erase(pr)
			_morale(p, -22.0)
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
