class_name EventPack
extends RefCounted
## Segundo lote de dilemas da carreira (lesões, contratos, diretoria, torcida, rivais, imprensa e
## empresários). Segue o mesmo formato do EventManager: build monta o evento quando faz sentido,
## describe gera texto e opções, resolve aplica as consequências. Os tipos ficam em EventManager.KINDS.
##
## Consequências que chegam depois (recaída, meta de pontos, bicho por vitória, provocação do rival)
## ficam em world.stats["ev2"] e são conferidas a cada jogo em after_turn.

const KINDS := ["rush_back", "renewal_standoff", "tapping_up", "rival_jab", "board_cut", "board_meeting",
	"fans_ct", "idol_farewell", "loan_request", "agent_fee", "documentary", "sack_rumor", "fatigue",
	"win_bonus", "own_doctor"]


static func handles(k: String) -> bool:
	return KINDS.has(k)


static func _state(world: GameWorld) -> Dictionary:
	if not world.stats.has("ev2") or typeof(world.stats["ev2"]) != TYPE_DICTIONARY:
		world.stats["ev2"] = {}
	return world.stats["ev2"]


static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _clamp_board(club: Club, d: float) -> void:
	club.board_confidence = clampf(club.board_confidence + d, 0.0, 100.0)


static func _clamp_fans(club: Club, d: float) -> void:
	club.fan_mood = clampf(club.fan_mood + d, 0.0, 100.0)


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

static func build(world: GameWorld, k: String, ev: Dictionary) -> Dictionary:
	var club := world.user_club()
	var rng := world.rng
	var squad: Array = world.squad(club)
	var turn := world.current_turn()
	match k:
		"rush_back":
			var best: Player = null
			for p: Player in squad:
				if p.squad_status <= Player.STATUS_STARTER and p.injury_weeks >= 2 and p.injury_weeks <= 6 and not p.injury_name.contains("Folga"):
					if best == null or p.overall > best.overall:
						best = p
			if best == null:
				return {}
			ev["p"] = best.id
			ev["d"] = {"weeks": best.injury_weeks, "cost": Valuation.round_wage(maxf(15000.0, FinanceManager.expected_revenue(club) * 0.004))}
		"renewal_standoff":
			var pick: Player = null
			for p: Player in squad:
				if p.squad_status > Player.STATUS_STARTER or p.contract_years_left(world.year) > 0 or p.age(world.year) > 31 or p.loan.size() > 0:
					continue
				if pick == null or p.overall > pick.overall:
					pick = p
			if pick == null or turn < 3:
				return {}
			var wage := Valuation.round_wage(maxf(float(pick.wage) * 1.1, float(Valuation.wage_demand(pick, club, world.year))))
			ev["p"] = pick.id
			ev["d"] = {"wage": wage, "bonus": Valuation.round_value(wage * rng.randf_range(4.0, 8.0)), "years": clampi(TransferManager.preferred_years(world, pick), 2, 4)}
		"tapping_up":
			var star: Player = null
			for p: Player in squad:
				if p.transfer_listed or p.age(world.year) > 30 or p.squad_status > Player.STATUS_STARTER:
					continue
				if star == null or p.value > star.value:
					star = p
			if star == null:
				return {}
			var suitor: Club = null
			for rid in club.rivals:
				var rc := world.club(int(rid))
				if rc != null and rc.tier == club.tier and rc.reputation >= club.reputation - 15.0:
					suitor = rc
					break
			if suitor == null:
				suitor = MarketAI.realistic_suitor(world, star, club.reputation + 6.0, rng, 4.0,
					func(c: Club): return c.tier == 1 and c.nation == club.nation and c.id != club.id)
			if suitor == null:
				return {}
			ev["p"] = star.id
			ev["d"] = {"club": suitor.id, "rival": club.rivals.find(suitor.id)}
		"rival_jab":
			if turn < 3 or _state(world).has("jab"):
				return {}
			var f := FixtureManager.next_fixture_for(world, club.id)
			if f == null or not MatchEngine.is_derby(world, f.home, f.away):
				return {}
			var opp := world.club(f.opponent_of(club.id))
			if opp == null:
				return {}
			ev["d"] = {"opp": opp.id, "what": rng.randi_range(0, 2), "coach": People.coach_name(world, opp.id)}
		"board_cut":
			if club.balance >= 0 and club.debt < FinanceManager.expected_revenue(club) * 0.6:
				return {}
			var heavy: Player = null
			for p: Player in squad:
				if p.age(world.year) < 27 or p.loan.size() > 0 or p.transfer_listed:
					continue
				if heavy == null or p.wage > heavy.wage:
					heavy = p
			if heavy == null:
				return {}
			ev["p"] = heavy.id
		"board_meeting":
			if turn < 6 or club.board_confidence >= 38.0 or club.board_confidence < 12.0 or _state(world).has("pts"):
				return {}
			ev["d"] = {"need": 6 if club.reputation >= 60.0 else 5}
		"fans_ct":
			if club.streak_losses < 3 and not (club.streak_winless >= 5 and club.fan_mood < 40.0):
				return {}
			ev["d"] = {"group": String((People.data(world).get("fans", {}) as Dictionary).get("group", "a torcida organizada"))}
		"idol_farewell":
			var idol: Player = null
			for p: Player in squad:
				var a := p.age(world.year)
				if a < 33 or world.year - p.joined_year < 5:
					continue
				if not (p.retiring or p.contract_years_left(world.year) == 0):
					continue
				if idol == null or world.year - p.joined_year > world.year - idol.joined_year:
					idol = p
			if idol == null or TransferManager.season_progress(world) < 0.45:
				return {}
			ev["p"] = idol.id
			ev["d"] = {"years": world.year - idol.joined_year}
		"loan_request":
			if not world.transfer_window_open():
				return {}
			var pool: Array = []
			for p: Player in squad:
				if p.age(world.year) <= 22 and p.loan.is_empty() and p.squad_status >= Player.STATUS_ROTATION and p.potential >= p.overall + 6 and p.stat(Player.S_STARTS) <= maxi(1, turn / 6):
					pool.append(p)
			if pool.is_empty():
				return {}
			ev["p"] = (RngUtil.pick(rng, pool) as Player).id
		"agent_fee":
			var pool2: Array = []
			for p: Player in squad:
				if world.year - p.joined_year <= 1 and p.joined_year > 0 and p.overall >= 55 and p.loan.is_empty():
					pool2.append(p)
			if pool2.is_empty():
				return {}
			var ap: Player = RngUtil.pick(rng, pool2)
			ev["p"] = ap.id
			ev["d"] = {"fee": Valuation.round_value(maxf(30000.0, ap.value * rng.randf_range(0.03, 0.06)))}
		"documentary":
			if club.reputation < 55.0 or world.stats.has("doc_year") and int(world.stats["doc_year"]) == world.year:
				return {}
			ev["d"] = {"money": Valuation.round_value(FinanceManager.expected_revenue(club) * rng.randf_range(0.012, 0.025)),
				"who": RngUtil.pick(rng, ["uma plataforma de streaming", "um canal fechado de esportes", "uma produtora independente"])}
		"sack_rumor":
			if turn < 5 or club.board_confidence >= 45.0 or club.streak_winless < 3:
				return {}
			var names: Array = []
			for c2: Club in world.clubs:
				if c2.nation == club.nation and c2.id != club.id:
					names.append(People.coach_name(world, c2.id))
				if names.size() >= 30:
					break
			var cand := String(RngUtil.pick(rng, names)) if not names.is_empty() else ""
			if cand == "":
				return {}
			ev["d"] = {"cand": cand}
		"fatigue":
			var tired: Array = []
			for p: Player in squad:
				if p.squad_status <= Player.STATUS_STARTER and not p.is_injured() and p.condition < 78.0:
					tired.append(p.id)
			if tired.size() < 3:
				return {}
			ev["d"] = {"ids": tired.slice(0, 5)}
		"win_bonus":
			if turn < 4 or _state(world).has("bonus"):
				return {}
			var leaders: Array = []
			for p: Player in squad:
				if p.age(world.year) >= 28 and p.squad_status <= Player.STATUS_STARTER:
					leaders.append(p)
			if leaders.is_empty():
				return {}
			var bill := 0
			for p: Player in squad:
				bill += p.wage
			ev["p"] = (RngUtil.pick(rng, leaders) as Player).id
			ev["d"] = {"per_win": Valuation.round_wage(maxf(20000.0, bill * rng.randf_range(0.06, 0.1)))}
		"own_doctor":
			var pool3: Array = []
			for p: Player in squad:
				if p.injury_weeks >= 3 and p.nationality != club.nation and not p.injury_name.contains("Folga"):
					pool3.append(p)
			if pool3.is_empty():
				return {}
			var dp: Player = RngUtil.pick(rng, pool3)
			ev["p"] = dp.id
			ev["d"] = {"weeks": dp.injury_weeks}
	return ev


# ---------------------------------------------------------------------------
# Texto
# ---------------------------------------------------------------------------

static func describe(world: GameWorld, ev: Dictionary) -> Dictionary:
	var club := world.user_club()
	var p: Player = world.player(int(ev.get("p", -1)))
	var d: Dictionary = ev.get("d", {})
	var pn := p.display_name() if p != null else "O jogador"
	match String(ev["k"]):
		"rush_back":
			var wk := int(d.get("weeks", 2))
			return {"title": "Antecipar a volta de %s?" % pn, "def": 1,
				"body": "%s tem previsão de %s fora. O médico diz que, com infiltração e carga controlada, ele pode jogar antes, mas não garante que a lesão não volte." % [pn, Fmt.n_of(wk, "%d semana", "%d semanas")],
				"options": [
					{"t": "Antecipar a volta", "hint": "Volta em 1 semana · risco de recaída"},
					{"t": "Respeitar o prazo", "hint": "Sem risco"},
					{"t": "Mandar para uma clínica especializada", "hint": "Custo de %s · volta 1 semana antes" % Fmt.money(int(d.get("cost", 0)))}]}
		"renewal_standoff":
			return {"title": "Renovação de %s travada" % pn, "def": 2,
				"body": "O contrato de %s termina no fim da temporada. O empresário aceita renovar por %d anos a %s/mês, mas exige %s de luvas na assinatura." % [pn, int(d.get("years", 3)), Fmt.money(int(d.get("wage", 0))), Fmt.money(int(d.get("bonus", 0)))],
				"options": [
					{"t": "Pagar as luvas e renovar", "hint": "%s agora · contrato até %d" % [Fmt.money(int(d.get("bonus", 0))), world.year + int(d.get("years", 3))]},
					{"t": "Oferecer só o salário", "hint": "Ele pode recusar"},
					{"t": "Deixar o contrato correr", "hint": "Pode sair de graça no fim da temporada"}]}
		"tapping_up":
			var sc := world.club(int(d.get("club", -1)))
			var sn := sc.short_name if sc != null else "outro clube"
			var ri := int(d.get("rival", -1))
			var riv := (" O %s é o maior rival do clube." % sn) if ri == 0 else ((" O %s é um dos rivais do clube." % sn) if ri > 0 else "")
			return {"title": "%s assedia %s" % [sn, pn], "def": 2,
				"body": "O presidente do %s disse em entrevista que sonha com %s e que o jogador \"já sabe que as portas estão abertas\".%s" % [sn, pn, riv],
				"options": [
					{"t": "Denunciar o aliciamento à federação", "hint": "Diretoria aprova · ele fica no meio da briga"},
					{"t": "Dizer em público que ele não sai", "hint": "Torcida aprova"},
					{"t": "Não comentar", "hint": "Nada muda agora"}]}
		"rival_jab":
			var oc := world.club(int(d.get("opp", -1)))
			var on := oc.short_name if oc != null else "rival"
			var jab: String = ["disse que o %s só ganha no grito" % club.short_name, "afirmou que o seu time joga por uma bola e reza", "comentou que vai ganhar no estádio de vocês, como da última vez"][int(d.get("what", 0)) % 3]
			return {"title": "Provocação antes do clássico", "def": 1,
				"body": "Na véspera do jogo contra o %s, o técnico %s %s. Os repórteres querem a sua resposta." % [on, String(d.get("coach", "deles")), jab],
				"options": [
					{"t": "Responder à altura", "hint": "Grupo e torcida inflamados · se perder, a cobrança dobra"},
					{"t": "Não entrar na provocação", "hint": "Diretoria aprova"},
					{"t": "Elogiar o trabalho dele", "hint": "Clima mais calmo · parte da torcida não gosta"}]}
		"board_cut":
			return {"title": "Diretoria pede corte na folha", "def": 1,
				"body": "Com o caixa no vermelho (%s), a diretoria quer reduzir a folha salarial ainda nesta temporada. A sugestão é negociar %s, um dos maiores salários do elenco (%s/mês)." % [Fmt.money(club.balance), pn, Fmt.money(p.wage if p != null else 0)],
				"options": [
					{"t": "Colocar %s à venda" % pn, "hint": "Diretoria satisfeita · ele entra na lista"},
					{"t": "Aceitar cortar a verba de contratações", "hint": "Verba de contratações cai 50%"},
					{"t": "Recusar o corte", "hint": "Relação com a diretoria piora"}]}
		"board_meeting":
			var need := int(d.get("need", 5))
			return {"title": "Reunião com a diretoria", "def": 2,
				"body": "O presidente chamou o treinador para uma reunião depois da última rodada. A confiança no trabalho está baixa e ele quer saber o que muda daqui para a frente.",
				"options": [
					{"t": "Prometer %s nos próximos 3 jogos" % Fmt.n_of(need, "%d ponto", "%d pontos"), "hint": "Se cumprir, a confiança sobe · se falhar, cai bastante"},
					{"t": "Pedir reforços", "hint": "Mais verba se houver caixa · diretoria fica desconfiada"},
					{"t": "Pedir tempo", "hint": "Confiança cai um pouco"}]}
		"fans_ct":
			return {"title": "Protesto no CT", "def": 0,
				"body": "Depois da sequência ruim, %s foi ao centro de treinamento e pede para falar com o elenco e com o treinador." % String(d.get("group", "a torcida organizada")),
				"options": [
					{"t": "Receber uma comissão", "hint": "Torcida mais calma · elenco sente a pressão"},
					{"t": "Deixar os jogadores conversarem", "hint": "Pode aproximar ou terminar em confusão"},
					{"t": "Fechar o CT e reforçar a segurança", "hint": "Elenco protegido · torcida revoltada"}]}
		"idol_farewell":
			return {"title": "Despedida de %s" % pn, "def": 1,
				"body": "Depois de %d temporadas no clube, %s deve se despedir no fim do ano. A torcida pede uma homenagem e o jogador gostaria de começar mais um jogo como titular." % [int(d.get("years", 5)), pn],
				"options": [
					{"t": "Escalar como titular numa partida", "hint": "Precisa começar 1 dos próximos 3 jogos"},
					{"t": "Homenagem antes do jogo", "hint": "Torcida aprova"},
					{"t": "Deixar para o fim da temporada", "hint": "Ele e a torcida se decepcionam"}]}
		"loan_request":
			var starts := p.stat(Player.S_STARTS) if p != null else 0
			var how := "Sem nenhum jogo como titular nesta temporada" if starts == 0 else "Com %s nesta temporada" % Fmt.n_of(starts, "%d jogo como titular", "%d jogos como titular")
			return {"title": "%s pede para ser emprestado" % pn, "def": 2,
				"body": "%s, %s (%d anos) acha que precisa jogar para evoluir e pediu para ser emprestado até o fim do ano." % [how, pn, p.age(world.year) if p != null else 0],
				"options": [
					{"t": "Emprestar", "hint": "Joga em outro clube até o fim da temporada"},
					{"t": "Prometer chances", "hint": "Precisa começar 1 dos próximos 4 jogos"},
					{"t": "Manter no elenco", "hint": "Ele fica frustrado"}]}
		"agent_fee":
			return {"title": "Empresário cobra comissão", "def": 1,
				"body": "O empresário que intermediou a chegada de %s diz que o clube não pagou toda a comissão combinada e cobra %s. O departamento jurídico acha que o contrato é ambíguo." % [pn, Fmt.money(int(d.get("fee", 0)))],
				"options": [
					{"t": "Pagar", "hint": "%s agora" % Fmt.money(int(d.get("fee", 0)))},
					{"t": "Contestar na justiça", "hint": "Pode não pagar nada ou pagar o dobro"},
					{"t": "Propor metade", "hint": "%s · o jogador fica constrangido" % Fmt.money(int(d.get("fee", 0)) / 2)}]}
		"documentary":
			return {"title": "Série sobre o clube", "def": 2,
				"body": "%s quer gravar a temporada do %s nos bastidores, com câmeras no vestiário e nos treinos. Oferece %s." % [_cap(String(d.get("who", "uma produtora"))), club.short_name, Fmt.money(int(d.get("money", 0)))],
				"options": [
					{"t": "Liberar acesso total", "hint": "%s · elenco fica exposto" % Fmt.money(int(d.get("money", 0)))},
					{"t": "Liberar sem o vestiário", "hint": "%s" % Fmt.money(int(d.get("money", 0)) / 2)},
					{"t": "Recusar", "hint": "Nada muda"}]}
		"sack_rumor":
			return {"title": "Imprensa fala em demissão", "def": 2,
				"body": "Um jornal publicou que a diretoria já sondou %s para o seu lugar caso o time não reaja. A notícia caiu no vestiário antes do treino." % String(d.get("cand", "outro técnico")),
				"options": [
					{"t": "Cobrar a diretoria em público", "hint": "Torcida e elenco do seu lado · presidente irritado"},
					{"t": "Pedir uma posição à diretoria em particular", "hint": "Relação com o presidente melhora"},
					{"t": "Ignorar e focar no jogo", "hint": "Nada muda agora"}]}
		"fatigue":
			var n := (d.get("ids", []) as Array).size()
			return {"title": "Alerta da preparação física", "def": 0,
				"body": "O preparador físico avisa que %s estão no limite do desgaste e pede uma semana de treinos regenerativos." % Fmt.n_of(n, "%d titular", "%d titulares"),
				"options": [
					{"t": "Semana regenerativa", "hint": "Condição física sobe · menos treino tático"},
					{"t": "Manter a carga", "hint": "Risco de lesão muscular"}]}
		"win_bonus":
			return {"title": "Elenco pede bicho por vitória", "def": 1,
				"body": "%s falou em nome do grupo: os jogadores querem uma premiação por vitória nos próximos 3 jogos. O valor pedido é %s por vitória, dividido entre o elenco." % [pn, Fmt.money(int(d.get("per_win", 0)))],
				"options": [
					{"t": "Pagar o bicho", "hint": "%s por vitória · elenco motivado" % Fmt.money(int(d.get("per_win", 0)))},
					{"t": "Recusar", "hint": "Elenco contrariado"},
					{"t": "Pagar só se vencer os 3", "hint": "%s no fim · motivação menor" % Fmt.money(int(d.get("per_win", 0)) * 3)}]}
		"own_doctor":
			return {"title": "%s quer tratar fora" % pn, "def": 1,
				"body": "%s pediu para fazer a recuperação com o médico particular, no país dele, em vez de ficar com o departamento médico do clube. A previsão atual é de %s." % [pn, Fmt.n_of(int(d.get("weeks", 3)), "%d semana", "%d semanas")],
				"options": [
					{"t": "Liberar", "hint": "Ele fica satisfeito · o clube perde o controle da recuperação"},
					{"t": "Manter no clube", "hint": "Ele fica contrariado"}]}
	return {"title": "Evento", "body": "", "options": [{"t": "OK", "hint": ""}], "def": 0}


# ---------------------------------------------------------------------------
# Consequências
# ---------------------------------------------------------------------------

static func resolve(world: GameWorld, ev: Dictionary, opt: int) -> String:
	var club := world.user_club()
	var p: Player = world.player(int(ev.get("p", -1)))
	var d: Dictionary = ev.get("d", {})
	var rng := world.rng
	var turn := world.current_turn()
	var st := _state(world)
	var k := String(ev["k"])
	var needs_player := ["rush_back", "renewal_standoff", "tapping_up", "board_cut", "idol_farewell", "loan_request", "agent_fee", "own_doctor"]
	if needs_player.has(k) and (p == null or p.club_id != club.id):
		return "Ele já não está no clube."
	var pn := p.display_name() if p != null else ""
	match k:
		"rush_back":
			match opt:
				0:
					p.injury_weeks = mini(p.injury_weeks, 1)
					EventManager._morale(p, 4.0)
					# Recaída: mais provável em quem se machuca fácil e em lesão longa.
					var risk := 0.22 + p.injury_prone * 0.015 + int(d.get("weeks", 2)) * 0.03
					if rng.randf() < risk:
						var rl: Array = st.get("relapse", [])
						rl.append({"p": p.id, "at": turn + rng.randi_range(2, 4), "w": int(d.get("weeks", 2)) + rng.randi_range(1, 3)})
						st["relapse"] = rl
					return "%s vai treinar com o grupo e pode jogar na próxima semana." % pn
				1:
					return "%s segue o tratamento normal." % pn
				_:
					club.add_ledger("investimentos", -int(d.get("cost", 0)))
					p.injury_weeks = maxi(1, p.injury_weeks - 1)
					return "%s foi para a clínica. Previsão: %s." % [pn, Fmt.n_of(p.injury_weeks, "%d semana", "%d semanas")]
		"renewal_standoff":
			var wage := int(d.get("wage", p.wage))
			var years := int(d.get("years", 3))
			match opt:
				0:
					club.add_ledger("luvas", -int(d.get("bonus", 0)))
					TransferManager.apply_renewal(world, p, wage, years)
					return "%s renovou até %d." % [pn, p.contract_end]
				1:
					var yes := p.morale >= 55.0 and p.trait_sum("greed") < 1.1 and rng.randf() < 0.55
					if yes:
						TransferManager.apply_renewal(world, p, wage, years)
						return "%s aceitou renovar sem luvas, até %d." % [pn, p.contract_end]
					EventManager._morale(p, -8.0)
					return "O empresário recusou. A renovação de %s esfriou." % pn
				_:
					EventManager._morale(p, -5.0)
					p.unhappy_weeks += 2
					return "O contrato de %s segue correndo." % pn
		"tapping_up":
			var sc := world.club(int(d.get("club", -1)))
			match opt:
				0:
					_clamp_board(club, 3.0)
					EventManager._morale(p, -3.0)
					if sc != null and rng.randf() < 0.5:
						sc.add_ledger("outros", -Valuation.round_value(maxf(20000.0, FinanceManager.expected_revenue(sc) * 0.002)))
						return "A federação multou o %s por aliciamento." % sc.short_name
					return "A federação arquivou a denúncia. A diretoria gostou da firmeza."
				1:
					_clamp_fans(club, 4.0)
					if p.trait_sum("ambition") > 10.0:
						EventManager._morale(p, -5.0)
						return "A torcida aplaudiu. %s preferia ter sido consultado." % pn
					EventManager._morale(p, 4.0)
					return "A torcida aplaudiu e %s agradeceu o apoio." % pn
				_:
					if p.trait_sum("ambition") > 10.0:
						EventManager._morale(p, -4.0)
						p.unhappy_weeks += 2
						return "O silêncio deixou %s pensativo." % pn
					return "O assunto morreu em poucos dias."
		"rival_jab":
			match opt:
				0:
					EventManager._team_morale(world, club, 4.0)
					_clamp_fans(club, 3.0)
					st["jab"] = turn
					return "A resposta virou manchete. Agora o clássico vale mais."
				1:
					_clamp_board(club, 2.0)
					return "Você não entrou na provocação."
				_:
					EventManager._team_morale(world, club, -1.0)
					_clamp_fans(club, -2.0)
					_clamp_board(club, 1.0)
					return "O elogio esfriou o clima. Parte da torcida não gostou."
		"board_cut":
			match opt:
				0:
					p.transfer_listed = true
					p.asking_price = int(TransferManager.asking_price(world, p) * 0.9)
					EventManager._morale(p, -6.0)
					_clamp_board(club, 6.0)
					People.add_pres_rel(world, 4.0)
					return "%s está à venda por %s." % [pn, Fmt.money(p.asking_price)]
				1:
					club.transfer_budget = int(club.transfer_budget * 0.5)
					_clamp_board(club, 3.0)
					return "Verba de contratações reduzida para %s." % Fmt.money(club.transfer_budget)
				_:
					_clamp_board(club, -7.0)
					People.add_pres_rel(world, -6.0)
					return "Você recusou. O presidente não gostou."
		"board_meeting":
			match opt:
				0:
					st["pts"] = {"until": turn + 3, "need": int(d.get("need", 5)), "acc": 0, "n": 0}
					_clamp_board(club, 2.0)
					return "Meta combinada: %s nos próximos 3 jogos." % Fmt.n_of(int(d.get("need", 5)), "%d ponto", "%d pontos")
				1:
					if club.balance > 0:
						var extra := Valuation.round_value(club.balance * 0.15)
						club.transfer_budget += extra
						_clamp_board(club, -4.0)
						return "A diretoria liberou mais %s para contratações, a contragosto." % Fmt.money(extra)
					_clamp_board(club, -6.0)
					return "Não há dinheiro. O pedido pegou mal."
				_:
					_clamp_board(club, -2.0)
					return "A diretoria vai esperar, mas acompanha cada resultado."
		"fans_ct":
			match opt:
				0:
					_clamp_fans(club, 6.0)
					EventManager._team_morale(world, club, -2.0)
					return "A conversa acalmou a torcida. O elenco sentiu a cobrança."
				1:
					if rng.randf() < 0.7:
						_clamp_fans(club, 5.0)
						EventManager._team_morale(world, club, 2.0)
						return "Os jogadores ouviram a torcida e o clima melhorou."
					var sq: Array = world.squad(club)
					if not sq.is_empty():
						var vic: Player = RngUtil.pick(rng, sq)
						EventManager._morale(vic, -12.0)
						_clamp_fans(club, -3.0)
						NewsManager.post_raw(world, "Confusão no CT", "A conversa com a torcida terminou em bate-boca e %s foi o mais cobrado." % vic.display_name(), club.id, vic.id, NewsEvent.IMP_HIGH)
						return "A conversa terminou em bate-boca. %s foi o mais cobrado." % vic.display_name()
					return "A conversa terminou em bate-boca."
				_:
					_clamp_fans(club, -6.0)
					EventManager._team_morale(world, club, 2.0)
					club.add_ledger("outros", -Valuation.round_wage(maxf(5000.0, FinanceManager.expected_revenue(club) * 0.0005)))
					return "O CT foi fechado. A torcida protestou do lado de fora."
		"idol_farewell":
			match opt:
				0:
					EventManager._morale(p, 10.0)
					_clamp_fans(club, 3.0)
					world.promises.append({"k": "minutes", "p": p.id, "until": turn + 3, "need": 1, "s0": p.stat(Player.S_STARTS) + EventManager._cup_starts(p)})
					return "%s será titular em um dos próximos 3 jogos." % pn
				1:
					EventManager._morale(p, 6.0)
					_clamp_fans(club, 5.0)
					club.add_ledger("outros", -Valuation.round_wage(maxf(5000.0, FinanceManager.expected_revenue(club) * 0.0005)))
					return "%s será homenageado antes do próximo jogo em casa." % pn
				_:
					EventManager._morale(p, -8.0)
					_clamp_fans(club, -4.0)
					return "A homenagem ficou para depois. A torcida reclamou."
		"loan_request":
			match opt:
				0:
					var r := TransferManager.loan_out(world, p)
					if bool(r.get("ok", false)):
						EventManager._morale(p, 8.0)
					else:
						EventManager._morale(p, -3.0)
					return String(r.get("msg", ""))
				1:
					EventManager._morale(p, 6.0)
					world.promises.append({"k": "minutes", "p": p.id, "until": turn + 4, "need": 1, "s0": p.stat(Player.S_STARTS) + EventManager._cup_starts(p)})
					return "Promessa feita: %s precisa começar 1 dos próximos 4 jogos." % pn
				_:
					EventManager._morale(p, -9.0)
					p.unhappy_weeks += 2
					return "%s fica no elenco, contrariado." % pn
		"agent_fee":
			var fee := int(d.get("fee", 0))
			match opt:
				0:
					club.add_ledger("outros", -fee)
					return "Comissão paga: %s." % Fmt.money(fee)
				1:
					if rng.randf() < 0.5:
						EventManager._morale(p, -3.0)
						return "A justiça deu razão ao clube. Nada a pagar."
					club.add_ledger("outros", -fee * 2)
					EventManager._morale(p, -6.0)
					return "O clube perdeu a ação e pagou %s com multa e custas." % Fmt.money(fee * 2)
				_:
					club.add_ledger("outros", -fee / 2)
					EventManager._morale(p, -4.0)
					return "O empresário aceitou %s." % Fmt.money(fee / 2)
		"documentary":
			var money := int(d.get("money", 0))
			match opt:
				0:
					world.stats["doc_year"] = world.year
					club.add_ledger("patrocinio", money)
					_clamp_fans(club, 3.0)
					club.cohesion = maxf(20.0, club.cohesion - 3.0)
					EventManager._team_morale(world, club, -2.0)
					return "Contrato assinado: %s. As câmeras chegam na semana que vem." % Fmt.money(money)
				1:
					world.stats["doc_year"] = world.year
					club.add_ledger("patrocinio", money / 2)
					_clamp_fans(club, 1.0)
					return "Contrato assinado: %s, sem acesso ao vestiário." % Fmt.money(money / 2)
				_:
					return "Proposta recusada."
		"sack_rumor":
			match opt:
				0:
					_clamp_fans(club, 3.0)
					EventManager._team_morale(world, club, 3.0)
					_clamp_board(club, -5.0)
					People.add_pres_rel(world, -6.0)
					return "A cobrança pública uniu o vestiário. O presidente não gostou."
				1:
					People.add_pres_rel(world, 4.0)
					_clamp_board(club, 2.0)
					return "O presidente garantiu que você segue no cargo."
				_:
					EventManager._team_morale(world, club, -2.0)
					return "Você ignorou. O vestiário seguiu falando no assunto."
		"fatigue":
			var ids: Array = d.get("ids", [])
			match opt:
				0:
					for pid in ids:
						var q: Player = world.player(int(pid))
						if q != null and q.club_id == club.id:
							q.condition = minf(100.0, q.condition + 12.0)
					club.cohesion = maxf(20.0, club.cohesion - 1.5)
					return "Semana regenerativa. O grupo recuperou o fôlego."
				_:
					var hurt: Array = []
					for pid in ids:
						var q: Player = world.player(int(pid))
						if q == null or q.club_id != club.id or q.is_injured():
							continue
						if rng.randf() < 0.12 + q.injury_prone * 0.008:
							q.injury_weeks = rng.randi_range(1, 3)
							q.injury_name = RngUtil.pick(rng, ["Lesão na coxa", "Estiramento na panturrilha", "Desgaste muscular"])
							NewsManager.on_injury(world, q)
							InboxManager.on_injury(world, q)
							hurt.append(q.display_name())
					club.cohesion = minf(100.0, club.cohesion + 1.0)
					if hurt.is_empty():
						return "Carga mantida. Ninguém se machucou."
					return "Carga mantida. Lesionado: %s." % ", ".join(hurt) if hurt.size() == 1 else "Carga mantida. Lesionados: %s." % ", ".join(hurt)
		"win_bonus":
			var per := int(d.get("per_win", 0))
			match opt:
				0:
					st["bonus"] = {"until": turn + 3, "per": per, "all": false, "wins": 0}
					EventManager._team_morale(world, club, 5.0)
					return "Bicho combinado: %s por vitória nos próximos 3 jogos." % Fmt.money(per)
				1:
					EventManager._team_morale(world, club, -4.0)
					if p != null:
						People.add_trust(world, p, -4.0)
					return "Pedido recusado. O grupo não gostou."
				_:
					st["bonus"] = {"until": turn + 3, "per": per, "all": true, "wins": 0}
					EventManager._team_morale(world, club, 2.0)
					return "Prêmio de %s se o time vencer os 3 jogos." % Fmt.money(per * 3)
		"own_doctor":
			if opt == 0:
				EventManager._morale(p, 8.0)
				var delta := rng.randi_range(-1, 2)
				p.injury_weeks = maxi(1, p.injury_weeks + delta)
				if delta > 0:
					return "%s viajou para tratar fora. A recuperação deve levar mais tempo que o previsto." % pn
				return "%s viajou para tratar com o médico particular." % pn
			EventManager._morale(p, -7.0)
			return "%s fica no clube, contrariado." % pn
	return ""


# ---------------------------------------------------------------------------
# Acompanhamento a cada jogo do usuário
# ---------------------------------------------------------------------------

static func after_turn(world: GameWorld, turn: int, result: String) -> void:
	if not world.stats.has("ev2"):
		return
	var st := _state(world)
	var club := world.user_club()
	if st.has("relapse"):
		var keep: Array = []
		for r in st["relapse"]:
			if turn < int(r["at"]):
				keep.append(r)
				continue
			var q: Player = world.player(int(r["p"]))
			if q == null or q.club_id != club.id or q.is_injured():
				continue
			q.injury_weeks = int(r["w"])
			q.injury_name = "Recaída da lesão"
			NewsManager.post_raw(world, "Recaída de %s" % q.display_name(), "%s sentiu a mesma lesão e volta a desfalcar o time por %s." % [q.display_name(), Fmt.n_of(q.injury_weeks, "%d semana", "%d semanas")], club.id, q.id, NewsEvent.IMP_HIGH)
			InboxManager.on_injury(world, q)
		if keep.is_empty():
			st.erase("relapse")
		else:
			st["relapse"] = keep
	if st.has("pts"):
		var pt: Dictionary = st["pts"]
		pt["acc"] = int(pt["acc"]) + (3 if result == "V" else (1 if result == "E" else 0))
		pt["n"] = int(pt["n"]) + 1
		if int(pt["acc"]) >= int(pt["need"]):
			st.erase("pts")
			_clamp_board(club, 8.0)
			People.add_pres_rel(world, 4.0)
			NewsManager.post_raw(world, "Meta cumprida", "O time somou %s e a diretoria renovou a confiança no trabalho." % Fmt.n_of(int(pt["acc"]), "%d ponto", "%d pontos"), club.id, -1, NewsEvent.IMP_HIGH)
		elif turn >= int(pt["until"]) or int(pt["n"]) >= 3:
			st.erase("pts")
			_clamp_board(club, -10.0)
			People.add_pres_rel(world, -6.0)
			NewsManager.post_raw(world, "Meta não cumprida", "O time somou só %s dos %d prometidos. A diretoria cobra o treinador." % [Fmt.n_of(int(pt["acc"]), "%d ponto", "%d pontos"), int(pt["need"])], club.id, -1, NewsEvent.IMP_HIGH)
	if st.has("bonus"):
		var b: Dictionary = st["bonus"]
		if result == "V":
			b["wins"] = int(b["wins"]) + 1
			if not bool(b["all"]):
				club.add_ledger("salarios", -int(b["per"]))
		var done := turn >= int(b["until"])
		if bool(b["all"]) and result != "V":
			done = true
		if done:
			st.erase("bonus")
			if bool(b["all"]) and int(b["wins"]) >= 3:
				club.add_ledger("salarios", -int(b["per"]) * 3)
				NewsManager.post_raw(world, "Prêmio pago", "O elenco venceu os 3 jogos e recebeu %s." % Fmt.money(int(b["per"]) * 3), club.id, -1, NewsEvent.IMP_NORMAL)
	if st.has("jab"):
		var jt := int(st["jab"])
		if turn > jt:
			st.erase("jab")
			if result == "D":
				_clamp_fans(club, -6.0)
				_clamp_board(club, -3.0)
				NewsManager.post_raw(world, "A resposta voltou contra", "O treinador do %s comprou a briga antes do clássico e perdeu. A torcida cobrou." % club.short_name, club.id, -1, NewsEvent.IMP_NORMAL)
			elif result == "V":
				_clamp_fans(club, 4.0)
	if st.is_empty():
		world.stats.erase("ev2")
