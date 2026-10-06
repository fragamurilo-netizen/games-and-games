class_name JobMarket
extends RefCounted
## Mercado de técnicos do lado do usuário: pedir demissão, ver as vagas abertas (clubes com
## interino no comando) e os cargos por um fio, mandar candidatura, fazer a entrevista com o
## presidente e assinar. Clubes que precisam de técnico também procuram o usuário por conta
## própria (People.job_offer), como no mercado real.
##
## Estado em People.data(world)["jm"]:
##   apps  {club_id: {y, st ("ent" entrevista marcada, "prop" proposta, "nao" recusado), leak}}
##   watch {club_id: turno} — "deixei o nome à disposição" num cargo ameaçado
##   last  turno da última candidatura (empregado: uma a cada APP_CD rodadas)
##
## A entrevista é uma conversa do Talks (kind "interview", t = id do clube): quatro perguntas
## que o presidente escolhe pelo estilo dele, pelo DNA do clube e pelo momento do usuário.

const APP_CD := 3 # rodadas entre duas candidaturas enquanto empregado
const HOT_JOB := 30.0 # abaixo disso o técnico da IA está balançando
const LEAK_BASE := 0.25 # chance de a candidatura vazar para a imprensa
const APPROACH := 0.12 # chance por rodada de um clube com vaga procurar o usuário
const APPROACH_WATCH := 0.6 # ... se o usuário deixou o nome à disposição

const TAC_LINES := {
	"posse": "\"Com a bola: troca de passes e paciência até achar o espaço.\"",
	"intensidade": "\"Pressão alta e intensidade o jogo inteiro.\"",
	"transicao": "\"Vertical: roubar a bola e chegar rápido no gol.\"",
	"defesa": "\"Primeiro não tomar gol. Time organizado e compacto.\"",
}
const TAC_OPPOSITE := {"posse": "defesa", "defesa": "posse", "intensidade": "defesa", "transicao": "posse"}


static func data(world: GameWorld) -> Dictionary:
	var pp := People.data(world)
	if not pp.has("jm"):
		pp["jm"] = {"apps": {}, "watch": {}, "last": -99}
	var jm: Dictionary = pp["jm"]
	# Candidaturas valem só na temporada em que foram feitas.
	var apps: Dictionary = jm["apps"]
	for k in apps.keys():
		if int(apps[k].get("y", 0)) != world.year:
			apps.erase(k)
	return jm


static func unemployed(world: GameWorld) -> bool:
	return world.stats.has("fired")


# ---------------------------------------------------------------------------
# Vagas e cargos ameaçados
# ---------------------------------------------------------------------------

## Clubes sem técnico efetivo (interino no comando), melhores primeiro.
static func vacancies(world: GameWorld) -> Array:
	var pp := People.data(world)
	var out: Array = []
	for c: Club in world.clubs:
		if c.is_pool() or world.is_user_club(c.id) and not unemployed(world):
			continue
		if unemployed(world) and c.id == int(world.stats["fired"].get("from", -1)):
			continue
		var co: Dictionary = pp["coaches"].get(c.id, {})
		if co.is_empty() or bool(co.get("int", false)):
			out.append(c)
	out.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation if a.reputation != b.reputation else a.id < b.id)
	return out


## Técnicos da IA por um fio (pressão alta), de clubes que poderiam se interessar pelo usuário.
static func hot_seats(world: GameWorld) -> Array:
	var pp := People.data(world)
	var out: Array = []
	for cid in pp["coaches"]:
		var co: Dictionary = pp["coaches"][cid]
		var c := world.club(int(cid))
		if c == null or c.is_pool() or world.is_user_club(c.id) or bool(co.get("int", false)):
			continue
		if float(co.get("job", 60.0)) >= HOT_JOB or fit(world, c) < 0.15:
			continue
		out.append(c)
	out.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation if a.reputation != b.reputation else a.id < b.id)
	return out


## Quanto o clube se interessa pelo usuário (0..1): reputação dele perto do que o clube costuma
## contratar (≈ 90% da reputação do clube), perfil que combina, país conhecido, demissão recente.
static func fit(world: GameWorld, c: Club) -> float:
	var rep := People.manager_rep(world)
	var v := 0.55 - (c.reputation * 0.9 - rep) / 30.0
	v += CoachIdentity.job_score(CoachIdentity.job_context(world), c) / 40.0
	var home := world.user_club().nation if world.has_user() else c.nation
	v += 0.05 if c.nation == home else -0.02
	v += (Languages.coach_comm(world, c) - 0.6) * 0.15 # falar a língua do vestiário conta
	var f: Dictionary = world.stats.get("fired", {})
	if not f.is_empty() and not bool(f.get("res", false)):
		v -= 0.08 # recém-demitido assusta um pouco
	return clampf(v, 0.03, 0.95)


## Aviso de língua para a vaga ("" se o técnico se comunica bem lá).
static func language_note(world: GameWorld, c: Club) -> String:
	var cm := Languages.coach_comm(world, c)
	if cm >= 0.7:
		return ""
	var lg := I18n.t(Languages.name_of(Languages.club_lang(c)))
	if I18n.lang != "en":
		lg = lg.to_lower() # em inglês, nome de língua leva maiúscula
	if cm >= 0.4:
		return "Seu %s ainda é básico: a diretoria pergunta como vai falar com o grupo." % lg
	return "Você não fala %s: a diretoria vê isso com reserva." % lg


static func fit_label(v: float) -> String:
	if v >= 0.7:
		return "Favorito"
	if v >= 0.45:
		return "Bem cotado"
	if v >= 0.2:
		return "Corre por fora"
	return "Fora do perfil"


static func fit_color(v: float) -> Color:
	if v >= 0.7:
		return UIColors.GREEN
	if v >= 0.45:
		return UIColors.BLUE
	if v >= 0.2:
		return UIColors.ORANGE
	return UIColors.MUTED


static func app_of(world: GameWorld, club_id: int) -> Dictionary:
	return data(world)["apps"].get(club_id, {})


static func app_status_text(st: String) -> String:
	match st:
		"ent":
			return "Entrevista marcada"
		"prop":
			return "Proposta na mesa"
		"nao":
			return "Escolheu outro nome"
	return ""


## Motivo para não poder se candidatar agora ("" = pode).
static func can_apply(world: GameWorld, c: Club) -> String:
	var app := app_of(world, c.id)
	if not app.is_empty():
		return app_status_text(String(app.get("st", "")))
	if not unemployed(world):
		var wait := APP_CD - (world.current_turn() - int(data(world).get("last", -99)))
		if wait > 0:
			return "Espere %d rodada%s para outra candidatura" % [wait, "" if wait == 1 else "s"]
	return ""


# ---------------------------------------------------------------------------
# Candidatura
# ---------------------------------------------------------------------------

## Manda o currículo. Retorna {ok, text}: ok = entrevista marcada.
static func apply(world: GameWorld, club_id: int) -> Dictionary:
	var c := world.club(club_id)
	if c == null:
		return {"ok": false, "text": ""}
	var why := can_apply(world, c)
	if why != "":
		return {"ok": false, "text": why}
	var jm := data(world)
	var r := People.rng(world, 41)
	var employed := not unemployed(world)
	if employed:
		jm["last"] = world.current_turn()
	var app := {"y": world.year, "st": "nao"}
	jm["apps"][c.id] = app
	if employed:
		_maybe_leak(world, r, c, app)
	var f := fit(world, c)
	if r.randf() < clampf(f * 1.4, 0.05, 0.98):
		app["st"] = "ent"
		People.log_event(world, "Candidatura ao %s: entrevista marcada." % c.short_name)
		return {"ok": true, "text": "O %s chamou você para uma entrevista." % c.short_name}
	People.log_event(world, "Candidatura ao %s recusada." % c.short_name)
	return {"ok": false, "text": _no_thanks(c, f)}


static func _no_thanks(c: Club, f: float) -> String:
	if f < 0.2:
		return "O %s agradeceu, mas procura um nome de mais peso." % c.short_name
	return "O %s agradeceu e seguiu com outros nomes." % c.short_name


## Empregado mandando currículo: às vezes a imprensa descobre, e a diretoria e a torcida também.
static func _maybe_leak(world: GameWorld, r: RandomNumberGenerator, c: Club, app: Dictionary) -> void:
	var u := world.user_club()
	var chance := LEAK_BASE
	if c.league_id == u.league_id:
		chance += 0.15
	if u.is_rival(c.id) or c.is_rival(u.id):
		chance += 0.25
	if r.randf() >= chance:
		return
	app["leak"] = true
	var rival := u.is_rival(c.id) or c.is_rival(u.id)
	u.board_confidence = clampf(u.board_confidence - (9.0 if rival else 5.0), 0.0, 100.0)
	People.add_pres_rel(world, -10.0 if rival else -6.0)
	People.add_support(world, -12.0 if rival else -5.0)
	NewsManager.post_raw(world, "%s se oferece ao %s" % [world.manager_name, c.short_name],
		"O técnico do %s mandou o currículo para o %s, que está sem treinador efetivo. A notícia caiu mal na diretoria%s." % [
			u.short_name, c.short_name, " e revoltou a torcida, que não perdoa namoro com o rival" if rival else ""],
		u.id, -1, NewsEvent.IMP_HIGH, "tecnicos")
	InboxManager.send(world, "presidente", "Soube da sua conversa com o %s" % c.short_name,
		"%s, a imprensa já sabe que você se ofereceu ao %s. Enquanto estiver aqui, quero você inteiro com a gente." % [world.manager_name, c.short_name],
		{"k": "screen", "s": "relations", "args": {"tab": "board"}}, -1, u.id)


## Deixa o nome à disposição de um clube cujo técnico está balançando: se ele cair, o clube
## liga primeiro para o usuário (se o perfil servir). Também pode vazar.
static func watch(world: GameWorld, club_id: int) -> void:
	var c := world.club(club_id)
	if c == null:
		return
	var jm := data(world)
	jm["watch"][c.id] = world.current_turn()
	if not unemployed(world):
		var r := People.rng(world, 42)
		_maybe_leak(world, r, c, {})


static func watching(world: GameWorld, club_id: int) -> bool:
	return data(world)["watch"].has(club_id)


# ---------------------------------------------------------------------------
# Clubes que procuram o usuário
# ---------------------------------------------------------------------------

## Depois de cada jogo do usuário: um clube com vaga (de nível parecido ou maior) pode ligar.
static func tick(world: GameWorld, r: RandomNumberGenerator) -> void:
	if not world.has_user() or unemployed(world) or not People.job_offer(world).is_empty():
		return
	var u := world.user_club()
	var jm := data(world)
	for c: Club in vacancies(world):
		if c.reputation < u.reputation - 4.0 or c.reputation > People.manager_rep(world) + 24.0:
			continue
		var watched: bool = jm["watch"].has(c.id)
		var f := fit(world, c)
		if f < (0.3 if watched else 0.5):
			continue
		if r.randf() >= (APPROACH_WATCH if watched else APPROACH * f):
			continue
		approach(world, c)
		return


## O clube liga: proposta direta, válida por algumas rodadas (aceitar/recusar nos Bastidores).
static func approach(world: GameWorld, c: Club) -> void:
	var pp := People.data(world)
	pp["offer"] = {"c": c.id, "until": world.current_turn() + 3}
	InboxManager.on_job_offer(world, c)
	NewsManager.post_raw(world, "%s sonda %s" % [c.short_name, world.manager_name],
		"O %s procurou o staff de %s para saber se ele toparia assumir o clube. A resposta pode mudar a temporada." % [c.name, world.manager_name], c.id, -1, NewsEvent.IMP_HEADLINE, "tecnicos")


# ---------------------------------------------------------------------------
# Demissão e troca de clube
# ---------------------------------------------------------------------------

## O usuário entrega o cargo. Fica sem clube até aceitar uma proposta ou passar numa entrevista.
static func resign(world: GameWorld) -> void:
	if unemployed(world) or not world.has_user():
		return
	var club := world.user_club()
	var mid := world.season != null and not world.season.finished and world.current_turn() > 0
	var offers := BoardManager.job_offers(world, club)
	world.stats["fired"] = {"from": club.id, "offers": offers, "year": world.year, "mid": mid, "res": true}
	club.board_confidence = 50.0
	var pp := People.data(world)
	pp.erase("offer")
	if mid:
		pp["mrep"] = maxf(5.0, People.manager_rep(world) - 2.0) # largar no meio do caminho pesa um pouco
	NewsManager.post_raw(world, "%s pede demissão do %s" % [world.manager_name, club.short_name],
		("%s entregou o cargo no meio da temporada. O %s vai procurar outro treinador." if mid else "%s não segue no comando do %s na próxima temporada.") % [world.manager_name, club.short_name],
		club.id, -1, NewsEvent.IMP_HEADLINE, "tecnicos")
	People.log_event(world, "Pediu demissão do %s." % club.short_name)


## Assume o clube (proposta de entrevista, sondagem ou depois de demitido).
static func accept(world: GameWorld, club_id: int) -> void:
	var c := world.club(club_id)
	if c == null:
		return
	var jm := data(world)
	var pledge := bool(jm.get("pledge_next", false))
	jm.erase("pledge_next")
	jm["apps"].erase(club_id)
	jm["watch"].clear()
	if unemployed(world):
		BoardManager.take_job(world, club_id)
	else:
		var old := world.user_club()
		People.data(world).erase("offer")
		BoardManager.take_job(world, club_id)
		NewsManager.post_raw(world, "%s deixa o %s" % [world.manager_name, old.short_name],
			"%s acertou com o %s. A torcida do %s não gostou de ver o técnico sair assim." % [world.manager_name, c.short_name, old.short_name],
			old.id, -1, NewsEvent.IMP_HIGH, "tecnicos")
	if pledge:
		People.data(world)["pledge"] = world.year # prometeu na entrevista: a diretoria cobra no balanço


# ---------------------------------------------------------------------------
# Entrevista (Talks kind "interview")
# ---------------------------------------------------------------------------

static func interview_start(world: GameWorld, club_id: int) -> Dictionary:
	var c := world.club(club_id)
	var pr := People.president(world, club_id)
	var st := People.pres_style(world, club_id)
	var conv := {"k": "interview", "t": club_id, "who": "Presidente %s" % String(pr.get("n", "")),
		"sub": "%s · %s" % [c.short_name if c != null else "", String(st.get("name", ""))], "p": -1,
		"lines": [], "opts": [], "done": false, "fx": [], "stage": "q", "d": {"i": 0, "pts": 0.0}}
	if c == null:
		conv["done"] = true
		return conv
	var app := app_of(world, club_id)
	var invited := String(app.get("st", "")) == "ent"
	if not invited:
		conv["lines"].append(["npc", "Não temos nenhuma conversa marcada com você, %s." % world.manager_name])
		conv["done"] = true
		return conv
	var r := People.rng(world, 43)
	conv["d"]["qs"] = _questions(world, c, r)
	var hello: String = RngUtil.pick(r, ["Sente-se, %s. Obrigado por vir até aqui." % world.manager_name,
		"%s, seja bem-vindo. Vamos direto ao ponto." % world.manager_name,
		"Bom dia, %s. Tenho algumas perguntas antes de qualquer decisão." % world.manager_name])
	conv["lines"].append(["npc", String(hello)])
	conv["lines"].append(["info", "Entrevista no %s · %d perguntas" % [c.name, (conv["d"]["qs"] as Array).size()]])
	_ask(conv)
	return conv


static func _ask(conv: Dictionary) -> void:
	var qs: Array = conv["d"]["qs"]
	var i := int(conv["d"]["i"])
	var q: Dictionary = qs[i]
	conv["lines"].append(["npc", String(q["q"])])
	var opts: Array = []
	for k in (q["o"] as Array).size():
		opts.append({"id": str(k), "t": String(q["o"][k]["t"])})
	conv["opts"] = opts


static func interview_choose(world: GameWorld, conv: Dictionary, id: String) -> void:
	var qs: Array = conv["d"]["qs"]
	var i := int(conv["d"]["i"])
	var o: Dictionary = qs[i]["o"][clampi(int(id), 0, (qs[i]["o"] as Array).size() - 1)]
	var v := float(o.get("v", 0.0))
	conv["d"]["pts"] = float(conv["d"]["pts"]) + v
	if bool(o.get("pledge", false)):
		conv["d"]["pledge"] = true
	var r := People.rng(world, 44)
	conv["lines"].append(["npc", _reaction(r, v)])
	i += 1
	conv["d"]["i"] = i
	if i < qs.size():
		_ask(conv)
		return
	_verdict(world, conv, r)


static func _reaction(r: RandomNumberGenerator, v: float) -> String:
	if v >= 2.0:
		return String(RngUtil.pick(r, ["Era exatamente isso que eu queria ouvir.", "Gostei. Muito.", "Isso combina com o que a gente pensa aqui."]))
	if v >= 1.0:
		return String(RngUtil.pick(r, ["Faz sentido.", "Certo. Anotado.", "Boa resposta."]))
	if v > -1.0:
		return String(RngUtil.pick(r, ["Hum. Entendi.", "Certo.", "Vamos em frente."]))
	if v > -2.0:
		return String(RngUtil.pick(r, ["Não é bem o que eu esperava.", "Hum... aqui as coisas são diferentes.", "Vou ser sincero: não me convenceu."]))
	return String(RngUtil.pick(r, ["Isso não funciona no nosso clube.", "Aí você me preocupou.", "Discordo totalmente."]))


static func _verdict(world: GameWorld, conv: Dictionary, r: RandomNumberGenerator) -> void:
	var c := world.club(int(conv["t"]))
	var pts := float(conv["d"]["pts"])
	var chance := clampf(fit(world, c) * 0.7 + 0.15 + pts * 0.06, 0.02, 0.97)
	var app := app_of(world, c.id)
	conv["opts"] = []
	conv["done"] = true
	conv["fx"].append("Entrevista: %s" % ("muito boa" if pts >= 4.0 else ("boa" if pts >= 1.5 else ("morna" if pts > -1.5 else "ruim"))))
	if r.randf() < chance:
		app["st"] = "prop"
		conv["d"]["offer"] = true
		data(world)["pledge_next"] = bool(conv["d"].get("pledge", false))
		var goal := SeasonManager.goal_of(world, c.id)
		conv["lines"].append(["npc", String(RngUtil.pick(r, ["O cargo é seu, se quiser. A meta é: %s." % String(goal[0]).to_lower(),
			"Conversei com a diretoria. Queremos você. A meta é: %s." % String(goal[0]).to_lower()]))])
		conv["lines"].append(["info", "Proposta do %s. Ela fica de pé até o fim da temporada ou até o clube contratar outro." % c.short_name])
		People.log_event(world, "Proposta do %s depois da entrevista." % c.short_name)
	else:
		app["st"] = "nao"
		conv["lines"].append(["npc", String(RngUtil.pick(r, ["Obrigado pela conversa. Vamos seguir com outro nome.",
			"Foi bom te conhecer, mas o perfil que buscamos é outro.", "Agradeço. A diretoria decidiu por outro caminho."]))])
		People.log_event(world, "Entrevista no %s: não foi escolhido." % c.short_name)


## Proposta em aberto depois da entrevista (o clube segue com interino até alguém assinar).
static func offer_open(world: GameWorld, club_id: int) -> bool:
	if String(app_of(world, club_id).get("st", "")) != "prop":
		return false
	var co: Dictionary = People.data(world)["coaches"].get(club_id, {})
	return co.is_empty() or bool(co.get("int", false))


static func decline(world: GameWorld, club_id: int) -> void:
	var app := app_of(world, club_id)
	if not app.is_empty():
		app["st"] = "nao"
	data(world).erase("pledge_next")


## Perguntas da entrevista: projeto, estilo, momento do treinador e um tema do presidente.
static func _questions(world: GameWorld, c: Club, r: RandomNumberGenerator) -> Array:
	var st := String(People.president(world, c.id).get("st", "paciente"))
	var goal := SeasonManager.goal_of(world, c.id)
	var goal_pos := int(goal[1])
	var big := goal_pos <= 2
	var league := world.league_of(c.id)
	var pos := CompetitionManager.position_of(league, c.id) if league != null else 0
	var danger := league != null and pos > 0 and pos >= league.club_ids.size() - 3 and world.current_turn() > 4
	var trouble := FinanceManager.in_trouble(c)
	var qs: Array = []
	# 1. Projeto
	qs.append({"q": "O que você pretende fazer no %s?" % c.short_name, "o": [
		{"t": "\"Brigar por título desde o primeiro dia.\"", "pledge": true,
			"v": (2.0 if st in ["exigente", "vaidoso"] else 1.0) if big else (-2.0 if st in ["empresario", "paciente"] else -1.0)},
		{"t": "\"Montar um time forte para os próximos anos.\"",
			"v": {"paciente": 2.0, "empresario": 1.0, "exigente": -1.0}.get(st, 0.5) - (1.5 if danger else 0.0)},
		{"t": "\"Primeiro, cumprir a meta: %s.\"" % String(goal[0]).to_lower(), "v": 2.0 if danger else 1.0}]})
	# 2. Estilo de jogo
	var tac := ClubDNA.tac(c)
	var keys: Array = TAC_LINES.keys()
	var o2: Array = []
	for k in keys:
		var v := 0.0
		if k == tac:
			v = 2.0
		elif String(TAC_OPPOSITE.get(tac, "")) == k:
			v = -1.5
		if st == "populista" and k in ["posse", "intensidade"]:
			v += 1.0
		o2.append({"t": String(TAC_LINES[k]), "v": v})
	qs.append({"q": "Como joga um time seu?", "o": o2})
	# 3. Momento do treinador
	var f: Dictionary = world.stats.get("fired", {})
	var old := world.club(int(f.get("from", -1))) if not f.is_empty() else null
	var cur := world.user_club() if world.has_user() else null
	if old != null and bool(f.get("res", false)):
		qs.append({"q": "Você pediu para sair do %s. Por quê?" % old.short_name, "o": [
			{"t": "\"Senti que o meu ciclo lá tinha acabado.\"", "v": 1.0},
			{"t": "\"Faltava estrutura para crescer.\"", "v": 1.5 if c.reputation > old.reputation + 3.0 else -1.0},
			{"t": "\"Tive problemas com a diretoria.\"", "v": -3.0 if st == "exigente" else -2.0}]})
	elif old != null:
		qs.append({"q": "Por que não deu certo no %s?" % old.short_name, "o": [
			{"t": "\"Assumo a minha parte. Aprendi muito.\"", "v": 2.0 if st == "paciente" else 1.0},
			{"t": "\"Não me deram tempo para trabalhar.\"", "v": {"paciente": 1.0, "exigente": -2.0}.get(st, -0.5)},
			{"t": "\"O elenco não tinha nível.\"", "v": -1.0}]})
	elif cur != null and cur.id != c.id:
		var rival := cur.is_rival(c.id) or c.is_rival(cur.id)
		qs.append({"q": "Você comanda o nosso maior rival. Como fica isso?" if rival else "Você tem contrato com o %s. Por que sair agora?" % cur.short_name, "o": [
			{"t": "\"Quero um desafio maior.\"", "v": 2.0 if c.reputation > cur.reputation + 4.0 else -1.0},
			{"t": "\"Aqui terei mais condições de trabalho.\"", "v": 1.0},
			{"t": "\"Ainda não decidi nada. Vim ouvir.\"", "v": -2.0 if st == "vaidoso" else -1.0}]})
	else:
		qs.append(_squad_question(c, st, trouble))
	# 4. O tema do presidente
	if trouble or st == "empresario":
		qs.append({"q": "O caixa está apertado. Como você lida com isso?" if trouble else "Aqui a planilha manda. Como você lida com orçamento curto?", "o": [
			{"t": "\"Trabalho com o que tiver.\"", "v": 2.0},
			{"t": "\"Se for preciso, vendo um titular para equilibrar.\"", "v": 2.0 if st == "empresario" else (-1.0 if st == "populista" else 1.0)},
			{"t": "\"Sem investimento não há milagre.\"", "v": -2.0}]})
	elif st == "populista":
		qs.append({"q": "A torcida é o nosso termômetro. O que você diz a ela?", "o": [
			{"t": "\"Vamos jogar para frente, em casa e fora.\"", "v": 2.0},
			{"t": "\"Peço paciência: o trabalho leva tempo.\"", "v": -1.0},
			{"t": "\"Os resultados vão falar por mim.\"", "v": 0.5}]})
	elif st == "vaidoso":
		qs.append({"q": "Quero um nome forte no elenco. Você trabalharia com uma estrela?", "o": [
			{"t": "\"Claro. Craque resolve jogo.\"", "v": 2.0},
			{"t": "\"Se ajudar o time, sim.\"", "v": 1.0},
			{"t": "\"Prefiro um grupo sem estrelas.\"", "v": -2.0}]})
	else:
		var ambitious := goal_pos > 1
		qs.append({"q": "Qual meta você assumiria aqui?", "o": [
			{"t": "\"A da diretoria: %s.\"" % String(goal[0]).to_lower(), "v": 1.0},
			{"t": "\"Acima da meta: vou surpreender.\"", "pledge": true, "v": (2.0 if st == "exigente" else 0.0) if ambitious else 1.0},
			{"t": "\"Prefiro não prometer nada.\"", "v": -2.0 if st == "exigente" else 1.0}]})
	if qs.size() < 4:
		qs.insert(2, _squad_question(c, st, trouble))
	return qs


static func _squad_question(c: Club, st: String, trouble: bool) -> Dictionary:
	if ClubDNA.rec(c) == "formacao" or ClubDNA.val(c, "yth") >= 60.0 or c.youth_level >= 70:
		return {"q": "E os garotos da base?", "o": [
			{"t": "\"Vão ter espaço. A base é o futuro do clube.\"", "v": 2.0},
			{"t": "\"Quem estiver pronto joga, seja de onde for.\"", "v": 1.0},
			{"t": "\"Preciso de jogadores prontos agora.\"", "v": 1.0 if st == "vaidoso" else -1.5}]}
	return {"q": "Como você vê o elenco atual?", "o": [
		{"t": "\"Dá para brigar com esse grupo.\"", "v": 2.0 if st == "empresario" else 1.0},
		{"t": "\"Faltam peças. Vou precisar de reforços.\"", "v": -2.0 if trouble or st == "empresario" else (1.0 if st == "vaidoso" else 0.0)},
		{"t": "\"Vou recuperar quem anda esquecido.\"", "v": 1.5 if st == "paciente" else 1.0}]}
