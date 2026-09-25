class_name InboxManager
extends RefCounted
## Caixa de entrada do treinador: mensagens pessoais de quem trabalha com ele (presidente,
## comissão técnica, departamento médico, olheiros, jogadores, empresários, outros clubes e imprensa).
##
## As notícias (NewsManager) contam o que aconteceu no mundo; a caixa de entrada fala com o
## treinador: relatórios, avisos e pedidos, muitos com um atalho para resolver na hora.
##
## Cada mensagem é um dicionário salvo em world.inbox:
##   {id, y (ano), d (data), f (remetente), n (nome), s (assunto), b (texto), a (ação), r (lida), p (jogador), c (clube)}
## A ação é {"k": tipo, ...}: "event" (id), "talk" (kind, t), "offers", "job", "player" (id), "club" (id),
## ou "screen" (s, args). Nada aqui usa world.rng: a caixa de entrada não muda a simulação.

const MAX := 120

## Remetentes: nome do cargo, ícone e grupo do filtro.
const FROM := {
	"presidente": {"role": "Presidente", "icon": "shield", "group": "diretoria"},
	"diretoria": {"role": "Diretoria", "icon": "shield", "group": "diretoria"},
	"futebol": {"role": "Departamento de futebol", "icon": "swap", "group": "mercado"},
	"auxiliar": {"role": "Auxiliar técnico", "icon": "tactics", "group": "comissao"},
	"preparador": {"role": "Preparador físico", "icon": "bolt", "group": "comissao"},
	"medico": {"role": "Departamento médico", "icon": "cross", "group": "comissao"},
	"olheiro": {"role": "Olheiro-chefe", "icon": "search", "group": "comissao"},
	"base": {"role": "Coordenador da base", "icon": "up", "group": "comissao"},
	"jogador": {"role": "Elenco", "icon": "shirt", "group": "elenco"},
	"empresario": {"role": "Empresário", "icon": "search", "group": "mercado"},
	"clube": {"role": "Outro clube", "icon": "swap", "group": "mercado"},
	"imprensa": {"role": "Imprensa", "icon": "news", "group": "outros"},
	"torcida": {"role": "Torcida organizada", "icon": "heart", "group": "outros"},
}

## Quem manda a mensagem de cada decisão da carreira (EventManager).
const EVENT_FROM := {
	"raise": "jogador", "minutes": "jogador", "discipline": "auxiliar", "dressing": "auxiliar",
	"sponsor": "diretoria", "invest": "presidente", "tickets": "diretoria", "takeover": "presidente", "stadium": "presidente",
	"press": "imprensa", "fans": "torcida", "rival_bid": "clube", "youth_bid": "clube", "medical": "medico",
	"friendly": "futebol", "agent": "empresario", "prodigy": "base",
}

const SCOUT_EVERY := 6 # jogos entre dois relatórios do olheiro
const BOARD_EVERY := 8 # jogos entre duas cartas da diretoria


# ---------------------------------------------------------------------------
# Acesso
# ---------------------------------------------------------------------------

static func send(world: GameWorld, from: String, subject: String, body: String, action: Dictionary = {}, player_id: int = -1, club_id: int = -1, sender_name: String = "") -> Dictionary:
	var id := int(world.stats.get("inbox_next", 1))
	world.stats["inbox_next"] = id + 1
	var m := {"id": id, "y": world.year, "d": world.current_day(), "f": from, "n": sender_name if sender_name != "" else _sender_name(world, from),
		"s": subject, "b": body, "a": action, "r": false, "p": player_id, "c": club_id}
	world.inbox.append(m)
	if world.inbox.size() > MAX:
		world.inbox = world.inbox.slice(world.inbox.size() - MAX)
	return m


static func unread_count(world: GameWorld) -> int:
	var n := 0
	for m in world.inbox:
		if not bool(m.get("r", false)):
			n += 1
	return n


static func find(world: GameWorld, id: int) -> Dictionary:
	for m in world.inbox:
		if int(m["id"]) == id:
			return m
	return {}


static func mark_read(m: Dictionary) -> void:
	m["r"] = true


static func mark_all_read(world: GameWorld) -> void:
	for m in world.inbox:
		m["r"] = true


static func delete(world: GameWorld, id: int) -> void:
	world.inbox = world.inbox.filter(func(m): return int(m["id"]) != id)


## Apaga as mensagens lidas que não esperam mais resposta. Retorna quantas saíram.
static func delete_read(world: GameWorld) -> int:
	var before := world.inbox.size()
	world.inbox = world.inbox.filter(func(m): return not bool(m.get("r", false)) or action_open(world, m))
	return before - world.inbox.size()


static func group_of(m: Dictionary) -> String:
	return String(FROM.get(String(m.get("f", "")), {}).get("group", "outros"))


static func icon_of(m: Dictionary) -> String:
	return String(FROM.get(String(m.get("f", "")), {}).get("icon", "info"))


static func role_of(m: Dictionary) -> String:
	return String(FROM.get(String(m.get("f", "")), {}).get("role", ""))


## A mensagem pede uma resposta que ainda está em aberto (decisão, conversa, proposta).
static func action_open(world: GameWorld, m: Dictionary) -> bool:
	var a: Dictionary = m.get("a", {})
	match String(a.get("k", "")):
		"event":
			return not EventManager.find(world, int(a["id"])).is_empty()
		"talk":
			for q in People.requests(world):
				if String(q["k"]) == String(a["kind"]) and int(q.get("t", -1)) == int(a.get("t", -1)):
					return true
			return false
		"offers":
			return not TransferManager.pending_offers(world).is_empty()
		"job":
			return not People.job_offer(world).is_empty()
	return false


## A mensagem pede resposta (mesmo que já respondida).
static func is_request(m: Dictionary) -> bool:
	return String(m.get("a", {}).get("k", "")) in ["event", "talk", "offers", "job"]


static func _sender_name(world: GameWorld, from: String) -> String:
	if not world.has_user():
		return role_of({"f": from})
	match from:
		"presidente":
			return String(People.president(world, world.user_club_id).get("n", "Presidente"))
		"auxiliar", "preparador", "medico", "olheiro", "base":
			var s: Dictionary = People.staff(world).get(from, {})
			if not s.is_empty():
				return String(s.get("n", ""))
		"torcida":
			return String(People.data(world).get("fans", {}).get("group", "Torcida"))
	return role_of({"f": from})


## Variação de texto sem sorteio (o id da mensagem escolhe a frase).
static func _pick(world: GameWorld, options: Array) -> String:
	return String(options[int(world.stats.get("inbox_next", 1)) % options.size()])


static func _nota(r: float) -> String:
	var t := "%.1f" % r
	return t.replace(".", ",") if I18n.lang != "en" else t


# ---------------------------------------------------------------------------
# Início de trabalho e de temporada
# ---------------------------------------------------------------------------

## Boas-vindas ao assumir um clube (carreira nova ou troca de clube).
static func on_new_job(world: GameWorld) -> void:
	if not world.has_user():
		return
	var c := world.user_club()
	var goal := SeasonManager.goal_of(world, c.id)
	var pst := People.pres_style(world, c.id)
	send(world, "presidente", "Bem-vindo ao %s" % c.short_name,
		"%s, seja bem-vindo. A meta da diretoria para esta temporada é: %s.\n\nVocê tem %s para contratações e uma folha de até %s. %s\n\nConto com você." % [
			world.manager_name, String(goal[0]).to_lower(), Fmt.money(c.transfer_budget), Fmt.money_month(c.wage_budget),
			_pres_line(String(People.president(world, c.id).get("st", "paciente")), pst)],
		{"k": "screen", "s": "relations", "args": {"tab": "board"}}, -1, c.id)
	_squad_intro(world)
	if SponsorManager.is_preseason(world):
		send(world, "futebol", "Pré-temporada: uniforme da temporada",
			"Antes da estreia precisamos definir o uniforme da temporada. Os patrocínios ficam com a diretoria. Os amistosos da pré-temporada também estão abertos para marcar.",
			{"k": "screen", "s": "kit"})


static func _pres_line(st: String, pst: Dictionary) -> String:
	match st:
		"exigente":
			return "Não vou esconder: aqui meta é meta."
		"paciente":
			return "Acredito em projeto. Você terá tempo para trabalhar."
		"populista":
			return "A arquibancada é o nosso termômetro. Mantenha a torcida do nosso lado."
		"empresario":
			return "Cuide também das contas: prejuízo não é opção."
		"vaidoso":
			return "Quero ver esse clube nas manchetes. Clássicos e títulos contam muito."
	return String(pst.get("desc", ""))


## Primeira leitura do auxiliar sobre o elenco que você herdou.
static func _squad_intro(world: GameWorld) -> void:
	var c := world.user_club()
	var squad := world.squad(c)
	if squad.is_empty():
		return
	var best: Player = null
	var young: Player = null
	var old := 0
	for p: Player in squad:
		if best == null or p.overall > best.overall:
			best = p
		if p.age(world.year) <= 21 and (young == null or p.potential_estimate(0.8) > young.potential_estimate(0.8)):
			young = p
		if p.age(world.year) >= 32:
			old += 1
	var lines: Array = ["Dei uma primeira olhada no grupo que você recebeu."]
	lines.append("O melhor jogador é %s (%s, %d)." % [best.display_name(), Pos.name_of(best.position).to_lower(), best.overall])
	if young != null:
		lines.append("Fique de olho em %s, %d anos: tem margem para crescer." % [young.display_name(), young.age(world.year)])
	if old >= 5:
		lines.append("Temos %d jogadores com 32 anos ou mais. Vale pensar em renovar o elenco." % old)
	lines.append("Estou à disposição para ajustar a tática e o treino.")
	send(world, "auxiliar", "Primeiras impressões do elenco", "\n\n".join(lines), {"k": "screen", "s": "squad"}, best.id)


## Carta da diretoria na virada de ano, com a meta nova.
static func on_new_season(world: GameWorld) -> void:
	if not world.has_user():
		return
	var c := world.user_club()
	var goal := SeasonManager.goal_of(world, c.id)
	send(world, "presidente", "Temporada %d: a meta da diretoria" % world.year,
		"%s, começa uma nova temporada. O que esperamos: %s.\n\nOrçamento para contratações: %s. Folha salarial máxima: %s.\n\nConfiança da diretoria no seu trabalho: %s." % [
			world.manager_name, String(goal[0]).to_lower(), Fmt.money(c.transfer_budget), Fmt.money_month(c.wage_budget),
			BoardManager.label(c.board_confidence).to_lower()],
		{"k": "screen", "s": "relations", "args": {"tab": "board"}}, -1, c.id)
	if SponsorManager.is_preseason(world):
		send(world, "futebol", "Pré-temporada: uniforme da temporada",
			"Nova temporada, uniforme novo. Precisamos fechar o modelo antes da estreia.",
			{"k": "screen", "s": "kit"})


# ---------------------------------------------------------------------------
# Depois de cada jogo do usuário
# ---------------------------------------------------------------------------

## Chamado no fim da data em que o usuário jogou (report de SeasonManager.finish_matchday).
static func after_user_turn(world: GameWorld, report: Dictionary, entry: Dictionary) -> void:
	if not world.has_user() or entry.is_empty():
		return
	for ev in report.get("events", []):
		on_event(world, ev)
	for q in report.get("talks", []):
		on_talk_request(world, q)
	_match_report(world, entry)
	var turn := world.current_turn()
	var club := world.user_club()
	if turn > 0 and turn % SCOUT_EVERY == 0:
		scout_report(world)
	if turn > 0 and turn % BOARD_EVERY == 0:
		_board_letter(world, club)
	_contracts_notice(world, club)
	_fitness_notice(world, club)


## Relatório do auxiliar: destaque, quem foi mal e o próximo adversário.
static func _match_report(world: GameWorld, entry: Dictionary) -> void:
	var club := world.user_club()
	var f: Fixture = entry["f"]
	var res: Dictionary = entry.get("res", {})
	var side := 0 if f.home == club.id else 1
	var opp := world.club(f.opponent_of(club.id))
	var mine: int = f.hg if side == 0 else f.ag
	var theirs: int = f.ag if side == 0 else f.hg
	var result := f.result_for(club.id)
	var lines: Array = []
	var head := {"V": ["Boa vitória.", "Três pontos merecidos.", "Vitória importante."],
		"E": ["Empate.", "Um ponto só.", "Ficou no empate."],
		"D": ["Derrota dura.", "Não foi o nosso dia.", "Tropeço."]}
	lines.append("%s %s %d x %d %s." % [_pick(world, head.get(result, ["Fim de jogo."])), club.short_name, mine, theirs, opp.short_name if opp != null else ""])
	var best: Player = null
	var best_r := 0.0
	var worst: Player = null
	var worst_r := 99.0
	if res.has("lines"):
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			var rt: float = ln[QuickMatch.L_R]
			if int(ln[QuickMatch.L_MINS]) < 30:
				continue
			if rt > best_r:
				best_r = rt
				best = p
			if rt < worst_r:
				worst_r = rt
				worst = p
	if best != null:
		lines[0] += " Destaque: %s (nota %s)." % [best.display_name(), _nota(best_r)]
	if worst != null and worst != best and worst_r < 6.0:
		lines.append("%s ficou abaixo (nota %s). Pode ser hora de uma conversa ou de um descanso." % [worst.display_name(), _nota(worst_r)])
	var nf := FixtureManager.next_fixture_for(world, club.id)
	if nf != null:
		var nopp := world.club(nf.opponent_of(club.id))
		if nopp != null:
			var where := "em casa" if nf.home == club.id else "fora"
			var form := nopp.recent_form(5)
			var txt := "Próximo jogo: %s, %s, %s (%s)." % [nopp.short_name, where, CompText.fixture_title(world, nf), world.season.date_label(nf.slot, false)]
			var nl := world.league_of(nopp.id)
			if nl != null and nf.comp == nl.id and int(nl.table[nopp.id]["pl"]) > 0:
				txt += " Eles estão em %dº." % CompetitionManager.position_of(nl, nopp.id)
			if form != "":
				txt += " Últimos jogos: %s." % " ".join(Array(form.split("")))
			if MatchEngine.is_derby(world, nf.home, nf.away):
				txt += " É clássico: a torcida vai cobrar."
			lines.append(txt)
	send(world, "auxiliar", "Relatório: %s %d x %d %s" % [club.short_name, mine, theirs, opp.short_name if opp != null else ""],
		"\n\n".join(lines), {"k": "screen", "s": "prematch", "args": {"edit": true}} if nf != null else {}, best.id if best != null else -1)


## Preparador físico avisa quando muitos titulares estão cansados.
static func _fitness_notice(world: GameWorld, club: Club) -> void:
	var tired: Array = []
	for p: Player in world.squad(club):
		if p.squad_status <= Player.STATUS_STARTER and p.is_available() and p.condition < 72.0:
			tired.append("%s (%d%%)" % [p.display_name(), int(p.condition)])
	if tired.size() < 3:
		return
	var turn := world.current_turn()
	if turn - int(world.stats.get("inbox_fit", -99)) < 4:
		return
	world.stats["inbox_fit"] = turn
	send(world, "preparador", "Titulares no limite físico",
		"Vários titulares chegam desgastados ao próximo jogo: %s.\n\nSugiro rodar o time ou aliviar a intensidade do treino." % ", ".join(tired.slice(0, 5)),
		{"k": "screen", "s": "training"})


## Contratos que terminam no fim da temporada (uma vez por temporada, a partir do meio do ano).
static func _contracts_notice(world: GameWorld, club: Club) -> void:
	if world.season == null or world.season.day < 14 or int(world.stats.get("inbox_contracts", 0)) == world.year:
		return
	var names: Array = []
	for p: Player in world.squad(club):
		if p.contract_end <= world.year:
			names.append(p.display_name())
	if names.is_empty():
		return
	world.stats["inbox_contracts"] = world.year
	send(world, "futebol", "%d contrato(s) terminam em %d" % [names.size(), world.year],
		"Estes jogadores ficam livres no fim da temporada: %s.\n\nQuem você quiser manter precisa renovar antes disso; os outros podem sair de graça." % ", ".join(names.slice(0, 8)) + (" e mais %d" % (names.size() - 8) if names.size() > 8 else ""),
		{"k": "screen", "s": "squad", "args": {"sort": "contract"}})


## Carta periódica do presidente: confiança e posição em relação à meta.
static func _board_letter(world: GameWorld, club: Club) -> void:
	var league := world.league_of(club.id)
	if league == null or int(league.table[club.id]["pl"]) == 0:
		return
	var goal := SeasonManager.goal_of(world, club.id)
	var pos := CompetitionManager.position_of(league, club.id)
	var target := int(goal[1])
	var conf := club.board_confidence
	var txt := ""
	if pos <= target and conf >= 60.0:
		txt = "Estamos satisfeitos. O time está em %dº, dentro da meta (%s). Continue assim." % [pos, String(goal[0]).to_lower()]
	elif pos <= target:
		txt = "O time está em %dº, dentro da meta (%s), mas a diretoria quer ver mais consistência." % [pos, String(goal[0]).to_lower()]
	elif pos - target <= 3:
		txt = "Estamos em %dº, um pouco abaixo da meta (%s). Ainda há tempo, mas precisamos reagir." % [pos, String(goal[0]).to_lower()]
	else:
		txt = "Estamos em %dº e a meta é %s. A situação preocupa a diretoria." % [pos, String(goal[0]).to_lower()]
	send(world, "presidente", "Avaliação da diretoria",
		"%s\n\nConfiança no seu trabalho: %s." % [txt, BoardManager.label(conf).to_lower()],
		{"k": "screen", "s": "relations", "args": {"tab": "board"}}, -1, club.id)


## Recomendações do olheiro: jogadores que caberiam no orçamento e melhorariam o elenco.
static func scout_report(world: GameWorld) -> void:
	var club := world.user_club()
	var squad := world.squad(club)
	if squad.is_empty():
		return
	var ovrs: Array = []
	for p: Player in squad:
		ovrs.append(p.overall)
	ovrs.sort()
	ovrs.reverse()
	var bar_ovr: int = ovrs[mini(10, ovrs.size() - 1)] + 1
	var budget := club.transfer_budget
	var picks: Array = []
	for p: Player in world.players.values():
		if p.club_id == club.id or p.overall < bar_ovr or p.age(world.year) > 29 or p.is_injured():
			continue
		if p.club_id >= 0:
			var c := world.club(p.club_id)
			if c == null or c.nation != club.nation and p.value > budget * 0.6:
				continue
		if p.value > budget:
			continue
		picks.append(p)
	if picks.is_empty():
		return
	picks.sort_custom(func(a: Player, b: Player): return a.overall * 1_000_000 - a.value / 100 > b.overall * 1_000_000 - b.value / 100)
	var lines: Array = []
	for p: Player in picks.slice(0, 3):
		var where := world.club(p.club_id).short_name if p.club_id >= 0 else "sem clube"
		lines.append("• %s, %d anos, %s (%s) · %d · valor %s" % [p.display_name(), p.age(world.year), Pos.name_of(p.position).to_lower(), where, p.overall, Fmt.money(p.value)])
	var top: Player = picks[0]
	send(world, "olheiro", "Jogadores que cabem no orçamento",
		"Com %s para gastar, estes nomes melhorariam o nosso time:\n\n%s\n\nToque para ver o primeiro da lista." % [Fmt.money(budget), "\n".join(lines)],
		{"k": "player", "id": top.id}, top.id)


# ---------------------------------------------------------------------------
# Ganchos dos outros sistemas
# ---------------------------------------------------------------------------

## Nova decisão da carreira: vira mensagem com atalho para responder.
static func on_event(world: GameWorld, ev: Dictionary) -> void:
	var d := EventManager.describe(world, ev)
	var from := String(EVENT_FROM.get(String(ev["k"]), "diretoria"))
	var p := world.player(int(ev.get("p", -1)))
	var name := ""
	if from == "jogador" and p != null:
		name = p.display_name()
	var left := maxi(1, int(ev["exp"]) - world.current_turn())
	send(world, from, String(d["title"]), "%s\n\nResponda em até %d jogo(s)." % [String(d["body"]), left],
		{"k": "event", "id": int(ev["id"])}, p.id if p != null else -1, -1, name)


## Pedido de conversa (jogador, presidente ou coletiva).
static func on_talk_request(world: GameWorld, q: Dictionary) -> void:
	var kind := String(q["k"])
	var target := int(q.get("t", -1))
	var act := {"k": "talk", "kind": kind, "t": target}
	match kind:
		"player":
			var p := world.player(target)
			if p == null:
				return
			send(world, "jogador", "Podemos conversar, professor?",
				"%s anda insatisfeito e pediu um tempo com você antes do próximo jogo." % p.display_name(), act, p.id, -1, p.display_name())
		"board":
			send(world, "presidente", "Reunião na sala da diretoria",
				"Precisamos conversar sobre o momento do time. Venha à minha sala assim que puder.", act)
		"press":
			send(world, "imprensa", "Coletiva antes do próximo jogo",
				"A imprensa está esperando você na sala de entrevistas. As respostas mexem com o vestiário e com a torcida.", act)


static func on_offer_received(world: GameWorld, o: TransferOffer) -> void:
	if not world.has_user():
		return
	var p := world.player(o.player_id)
	var b := world.club(o.buyer_id)
	if p == null or b == null:
		return
	send(world, "clube", "Proposta por %s" % p.display_name(),
		"O %s oferece %s por %s (%d anos, %d).\n\nA proposta vale por %d jogo(s)." % [b.name, Fmt.money(o.fee), p.display_name(), p.age(world.year), p.overall,
			maxi(1, o.expires_day - world.current_turn() + 1)],
		{"k": "offers"}, p.id, b.id, b.short_name)


static func on_injury(world: GameWorld, p: Player) -> void:
	if not world.has_user() or not world.is_user_club(p.club_id) or p.injury_weeks <= 0:
		return
	var sev := "Nada grave" if p.injury_weeks <= 1 else ("Vai desfalcar por algumas semanas" if p.injury_weeks <= 4 else "Lesão séria")
	send(world, "medico", "%s: %s" % [p.display_name(), p.injury_name if p.injury_name != "" else "lesão"],
		"%s. %s deve ficar fora por %d semana(s).\n\nJá começamos o tratamento." % [sev, p.display_name(), p.injury_weeks],
		{"k": "player", "id": p.id}, p.id)


static func on_window(world: GameWorld, opening: bool) -> void:
	if not world.has_user():
		return
	var c := world.user_club()
	if opening:
		send(world, "futebol", "Janela de transferências aberta",
			"A janela abriu e vai até %s. Orçamento disponível: %s. Folha: %s de %s." % [
				world.season.date_label(world.window_end_day(), false), Fmt.money(c.transfer_budget),
				Fmt.money_month(FinanceManager.wage_bill(world, c)), Fmt.money_month(c.wage_budget)],
			{"k": "screen", "s": "market"})
	else:
		send(world, "futebol", "Janela de transferências fechada",
			"A janela fechou. Agora só jogadores sem clube podem ser contratados.", {"k": "screen", "s": "market"})


## Sondagem de outro clube para o treinador.
static func on_job_offer(world: GameWorld, c: Club) -> void:
	send(world, "clube", "Convite do %s" % c.short_name,
		"O presidente do %s quer saber se você toparia assumir o time. A proposta vale por poucos jogos." % c.name,
		{"k": "job"}, -1, c.id, c.short_name)


static func on_ultimatum(world: GameWorld, club: Club) -> void:
	var goal := SeasonManager.goal_of(world, club.id)
	send(world, "presidente", "Ultimato",
		"A diretoria perdeu a paciência. A meta era %s e não estamos perto disso.\n\nSem reação imediata, o seu cargo está em risco." % String(goal[0]).to_lower(),
		{"k": "screen", "s": "relations", "args": {"tab": "board"}}, -1, club.id)

