class_name CoachStories
extends RefCounted
## Os técnicos da IA como personagens: temperamento, apelidos que a carreira justifica, momentos
## marcantes, arcos (revelação, volta por cima, despedida, volta para casa) e um mercado de fim de
## temporada em que quem fez um trabalho acima do esperado é chamado por clubes maiores.
##
## Tudo fica no próprio técnico (world.people coaches/free), sem módulo de dados à parte:
##   tm    temperamento (TEMPERS), sorteado pelo id na primeira vez que alguém pergunta
##   tl    momentos da carreira [{y, t, k}] (k = tipo, para o ícone), os mais recentes no fim
##   arc   arco em andamento {k, y}
##   aw    prêmios [[ano, chave, liga]] ("coach" = da temporada, "coach_world" = do ano)
##   vs    retrospecto contra o treinador do usuário [v, e, d] do ponto de vista do técnico
##   ms    marcos já anunciados {chave: ano}
##   prom  acessos; resc  clubes salvos do rebaixamento; sov  campanha da última temporada
##         (posições acima da meta)
##   hot   o cargo chegou a balançar (para "balançou, mas não caiu")
##   hire  contratado no meio do ano {y, pos, n} (para saber se salvou o clube)

const TL_MAX := 14
const MS_GAMES: Array[int] = [100, 250, 500, 750, 1000]
const MS_TITLES: Array[int] = [5, 10, 15, 20]

## Temperamento: como o técnico fala, reage e decide a carreira. `amb` pesa nas propostas.
const TEMPERS := {
	"provocador": {"name": "Falastrão", "desc": "Fala o que pensa e adora cutucar os rivais na entrevista.", "amb": 0.1, "w": 1.0},
	"diplomata": {"name": "Diplomata", "desc": "Elegante na vitória e na derrota. A imprensa gosta dele.", "amb": 0.0, "w": 1.2},
	"ambicioso": {"name": "Ambicioso", "desc": "Quer chegar ao topo e não recusa um clube maior.", "amb": 0.35, "w": 1.1},
	"fiel": {"name": "Fiel", "desc": "Cria raízes. Recusa propostas para terminar o que começou.", "amb": -0.4, "w": 0.9},
	"explosivo": {"name": "Pavio curto", "desc": "Briga com a arbitragem, com a diretoria e às vezes com o próprio elenco.", "amb": 0.05, "w": 0.8},
	"discreto": {"name": "Discreto", "desc": "Pouca entrevista, muito trabalho. Deixa os números falarem.", "amb": 0.0, "w": 1.3},
}


static func temper(world: GameWorld, co: Dictionary) -> String:
	if co.has("tm"):
		return String(co["tm"])
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, int(co.get("id", 0)), 60613)
	var keys: Array = TEMPERS.keys()
	var ws: Array = []
	for k in keys:
		ws.append(float(TEMPERS[k]["w"]))
	var t := String(keys[RngUtil.weighted_index(r, ws)])
	co["tm"] = t
	return t


static func temper_name(world: GameWorld, co: Dictionary) -> String:
	return String(TEMPERS[temper(world, co)]["name"])


static func temper_desc(world: GameWorld, co: Dictionary) -> String:
	return String(TEMPERS[temper(world, co)]["desc"])


static func moment(world: GameWorld, co: Dictionary, text: String, kind: String = "") -> void:
	if co.is_empty():
		return
	var tl: Array = co.get("tl", [])
	tl.append({"y": world.year, "t": text, "k": kind})
	if tl.size() > TL_MAX:
		tl = tl.slice(tl.size() - TL_MAX)
	co["tl"] = tl


static func moments(co: Dictionary) -> Array:
	return co.get("tl", [])


## Notícia só quando o usuário acompanharia: mesma liga, rival, primeira divisão do país dele ou
## técnico de nome.
static func _relevant(world: GameWorld, club: Club, co: Dictionary = {}) -> bool:
	if not world.has_user() or club == null:
		return false
	var u := world.user_club()
	return club.league_id == u.league_id or u.is_rival(club.id) or (club.nation == u.nation and club.tier == 1) or float(co.get("rep", 0.0)) >= 72.0


static func _news(world: GameWorld, club: Club, co: Dictionary, title: String, body: String, high: bool = false) -> void:
	if not _relevant(world, club, co):
		return
	var u := world.user_club()
	var imp := NewsEvent.IMP_HIGH if high and (club.league_id == u.league_id or u.is_rival(club.id)) else NewsEvent.IMP_NORMAL
	NewsManager.post_raw(world, title, body, club.id, -1, imp, "tecnicos")


# ---------------------------------------------------------------------------
# Apelidos e rótulos: só o que a carreira sustenta
# ---------------------------------------------------------------------------

## [{n: nome, d: por quê}] do mais forte para o mais fraco.
static func labels(world: GameWorld, co: Dictionary) -> Array:
	var out: Array = []
	var t := CoachCareer.totals(co)
	var cups := 0
	var best_len := 0
	var best_club := ""
	var best_titles := 0
	var nations := {}
	for sp: Dictionary in co.get("car", []):
		var k := String(sp.get("k", ""))
		if k == "aux" or k == "base":
			continue
		for key in sp.get("t", []):
			if not String(key).begins_with("L:"):
				cups += 1
		var to := int(sp["to"]) if int(sp["to"]) > 0 else world.year
		var ln := to - int(sp["from"])
		if ln > best_len or (ln == best_len and (sp["t"] as Array).size() > best_titles):
			best_len = ln
			best_club = String(sp.get("cn", ""))
			best_titles = (sp["t"] as Array).size()
		var cl := world.club(int(sp.get("c", -1)))
		if cl != null:
			nations[cl.nation] = true
	var world_aw := 0
	var league_aw := 0
	for a in co.get("aw", []):
		if String(a[1]) == "coach_world":
			world_aw += 1
		else:
			league_aw += 1
	var age := world.year - int(co.get("by", world.year - 50))
	if world_aw > 0:
		out.append({"n": "Melhor do mundo", "d": "Eleito treinador do ano %d vez(es)." % world_aw})
	if int(t["t"]) >= 8:
		out.append({"n": "Multicampeão", "d": "%d títulos na carreira." % int(t["t"])})
	if best_len >= 5 and best_titles >= 1:
		out.append({"n": "Ídolo do %s" % best_club, "d": "%d anos e %d título(s) no mesmo clube." % [best_len, best_titles]})
	elif int(co.get("idol", -1)) >= 0 and world.club(int(co["idol"])) != null:
		out.append({"n": "Cria do %s" % world.club(int(co["idol"])).short_name, "d": "Fez história lá como jogador."})
	if cups >= 3:
		out.append({"n": "Rei de copas", "d": "%d copas levantadas." % cups})
	if int(co.get("prom", 0)) >= 2:
		out.append({"n": "Rei do acesso", "d": "%d acessos." % int(co["prom"])})
	if int(co.get("resc", 0)) >= 2:
		out.append({"n": "Bombeiro", "d": "Salvou %d clubes do rebaixamento chegando no meio do ano." % int(co["resc"])})
	if league_aw >= 2:
		out.append({"n": "Premiado", "d": "Treinador da temporada %d vezes." % league_aw})
	if age <= 42 and float(co.get("rep", 0.0)) >= 66.0:
		out.append({"n": "Revelação", "d": "Aos %d anos, já é um dos nomes do mercado." % age})
	if nations.size() >= 3:
		out.append({"n": "Cidadão do mundo", "d": "Trabalhou em %d países." % nations.size()})
	if int(t["clubs"]) >= 9:
		out.append({"n": "Andarilho", "d": "%d clubes na carreira." % int(t["clubs"])})
	if int(t["dem"]) >= 7:
		out.append({"n": "Corda bamba", "d": "%d demissões." % int(t["dem"])})
	if int(t["g"]) >= 800:
		out.append({"n": "Veterano da casamata", "d": "%d jogos como técnico." % int(t["g"])})
	return out


static func nickname(world: GameWorld, co: Dictionary) -> String:
	var ls := labels(world, co)
	return String(ls[0]["n"]) if not ls.is_empty() else ""


static func arc_text(co: Dictionary) -> String:
	match String(co.get("arc", {}).get("k", "")):
		"revelacao":
			return "Revelação em busca do primeiro grande clube"
		"redencao":
			return "Em busca da volta por cima"
		"despedida":
			return "Última temporada antes de parar"
		"casa":
			return "De volta ao clube do coração"
	return ""


## Retrospecto do usuário contra o técnico [v, e, d] (do ponto de vista do usuário).
static func vs_user(co: Dictionary) -> Array:
	var v: Array = co.get("vs", [0, 0, 0])
	return [int(v[2]), int(v[1]), int(v[0])]


# ---------------------------------------------------------------------------
# Contratação: histórias que nascem quando alguém assume um clube
# ---------------------------------------------------------------------------

static func on_hired(world: GameWorld, club: Club, co: Dictionary, reason: String, from_club: Club) -> void:
	if co.is_empty() or club == null or world.is_user_club(club.id):
		return
	temper(world, co)
	var nm := String(co.get("n", ""))
	var car: Array = co.get("car", [])
	var prev: Array = car.slice(0, maxi(0, car.size() - 1)) # sem o trabalho que acabou de abrir
	var fired_here := false
	var titles_here := 0
	var biggest := 0.0
	var worked_nation := false
	for sp: Dictionary in prev:
		var k := String(sp.get("k", ""))
		if k == "aux" or k == "base":
			continue
		var cl := world.club(int(sp.get("c", -1)))
		if cl != null:
			biggest = maxf(biggest, cl.reputation)
			if cl.nation == club.nation:
				worked_nation = true
		if int(sp.get("c", -1)) == club.id:
			if String(sp.get("e", "")) == "dem" and int(sp.get("to", 0)) >= world.year - 8:
				fired_here = true
			titles_here += (sp["t"] as Array).size()
	var bond := FootballMemory.coach_bond(world, co, club.id)
	var arc_k := String(co.get("arc", {}).get("k", ""))
	if bond >= 40 or int(co.get("idol", -1)) == club.id:
		co["arc"] = {"k": "casa", "y": world.year}
		moment(world, co, "Voltou ao %s, onde fez %d jogos como jogador, agora como técnico." % [club.short_name, bond] if bond > 0 else "Voltou ao %s, o clube do coração." % club.short_name, "casa")
		_news(world, club, co, "%s volta para casa" % nm, "Ídolo do %s nos tempos de jogador, %s assume o time. A torcida lota as redes de boas-vindas." % [club.short_name, nm], true)
	elif titles_here > 0:
		moment(world, co, "Voltou ao %s, onde já tinha sido campeão." % club.short_name, "casa")
		_news(world, club, co, "O retorno do campeão: %s de volta ao %s" % [nm, club.short_name], "%s conquistou %d título(s) no clube e aceitou o desafio de repetir a história." % [nm, titles_here], true)
	elif fired_here:
		moment(world, co, "Voltou ao %s, o clube que um dia o demitiu." % club.short_name, "volta")
		_news(world, club, co, "%s volta ao %s, que o demitiu" % [nm, club.short_name], "Anos depois de sair pela porta dos fundos, %s ganha uma segunda chance no mesmo clube. \"Futebol dá voltas\", resumiu." % nm)
	if biggest > 0.0 and club.reputation >= biggest + 10.0:
		moment(world, co, "Assumiu o %s, o maior trabalho da carreira." % club.short_name, "sobe")
		if arc_k == "revelacao":
			co.erase("arc")
			moment(world, co, "Da revelação ao grande clube: o salto que todos esperavam.", "sobe")
			_news(world, club, co, "A revelação chegou lá: %s é do %s" % [nm, club.short_name], "Depois de fazer barulho %s, %s ganha a chance num clube do tamanho do %s." % ["no %s" % from_club.short_name if from_club != null else "com times menores", nm, club.short_name], true)
	if not worked_nation and club.nation != String(co.get("nat", "")) and not prev.is_empty():
		moment(world, co, "Primeira aventura no futebol de %s, no %s." % [DatabaseManager.nation_name(club.nation), club.short_name], "mundo")
	if world.season != null and not world.season.finished and world.season.day > 4:
		var league := world.league_of(club.id)
		if league != null:
			co["hire"] = {"y": world.year, "pos": CompetitionManager.position_of(league, club.id), "n": league.club_ids.size()}
	if reason == "ciclo" and from_club != null:
		moment(world, co, "Trocou o %s pelo %s depois de uma grande temporada." % [from_club.short_name, club.short_name], "sobe")


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Depois de cada data: marcos da carreira e técnicos que balançaram e se seguraram.
static func after_matchday(world: GameWorld, entries: Array) -> void:
	var coaches: Dictionary = People.data(world)["coaches"]
	for e in entries:
		var f: Fixture = e["f"]
		if not f.played:
			continue
		for cid in [f.home, f.away]:
			if world.is_user_club(cid):
				continue
			var co: Dictionary = coaches.get(cid, {})
			if co.is_empty() or bool(co.get("int", false)):
				continue
			var club := world.club(cid)
			var job := float(co.get("job", 60.0))
			if job < 25.0:
				co["hot"] = true
			elif bool(co.get("hot", false)) and job >= 55.0:
				co.erase("hot")
				moment(world, co, "Balançou no cargo do %s, mas virou o jogo e se segurou." % club.short_name, "volta")
				_news(world, club, co, "%s balançou, mas não caiu" % String(co["n"]),
					"Pressionado há poucas semanas, %s engatou uma boa sequência e hoje é bancado pela diretoria do %s." % [String(co["n"]), club.short_name])
			_milestones(world, club, co)


static func _milestones(world: GameWorld, club: Club, co: Dictionary) -> void:
	var ms: Dictionary = co.get("ms", {})
	var t := CoachCareer.totals(co)
	for n in MS_GAMES:
		var key := "g%d" % n
		if int(t["g"]) >= n and not ms.has(key):
			ms[key] = world.year
			co["ms"] = ms
			if int(t["g"]) - n > 3:
				continue # já tinha passado (save antigo): registra sem alarde
			moment(world, co, "Chegou a %d jogos como técnico." % n, "marco")
			if n >= 250:
				_news(world, club, co, "%s chega a %d jogos como técnico" % [String(co["n"]), n],
					"Na casamata do %s, %s alcançou a marca com %d vitórias e %d título(s) na carreira." % [club.short_name, String(co["n"]), int(t["w"]), int(t["t"])])
	for n in MS_TITLES:
		var key2 := "t%d" % n
		if int(t["t"]) >= n and not ms.has(key2):
			ms[key2] = world.year
			co["ms"] = ms


## Depois do jogo do usuário: retrospecto contra o técnico adversário e o que ele disse depois.
static func after_user_match(world: GameWorld, entry: Dictionary, result: String) -> void:
	if not world.has_user() or entry.is_empty():
		return
	var f: Fixture = entry["f"]
	var user := world.user_club()
	var opp := world.club(f.opponent_of(user.id))
	var co := People.coach_of(world, opp.id)
	if co.is_empty():
		return
	var vs: Array = co.get("vs", [0, 0, 0])
	var day := f.result_for(user.id) # o retrospecto conta o placar do jogo; o tom da fala segue o confronto
	var i := 2 if day == "V" else (1 if day == "E" else 0) # do ponto de vista do técnico: V do usuário = D dele
	vs[i] = int(vs[i]) + 1
	co["vs"] = vs
	var nm := String(co["n"])
	var me := world.manager_name
	var r := People.rng(world, 41)
	var tm := temper(world, co)
	var won := result == "D"
	var lost := result == "V"
	var title := ""
	var body := ""
	var rel := 0.0
	match tm:
		"provocador":
			if won and r.randf() < 0.65:
				title = "%s provoca: \"Hoje ficou claro quem manda\"" % nm
				body = "Depois de vencer o %s, o técnico do %s não economizou: \"%s gosta de falar, mas quem ganhou fomos nós\"." % [user.short_name, opp.short_name, me]
				rel = -4.0
			elif lost and r.randf() < 0.5:
				title = "%s reclama depois da derrota para o %s" % [nm, user.short_name]
				body = "\"Não vou falar da arbitragem para não ser punido\", disse %s, antes de passar dez minutos falando da arbitragem." % nm
				rel = -2.0
		"diplomata":
			if lost and r.randf() < 0.35:
				title = "%s elogia %s" % [nm, me]
				body = "\"Parabéns ao %s. Foram melhores e mereceram\", reconheceu o técnico do %s." % [user.short_name, opp.short_name]
				rel = 3.0
			elif won and r.randf() < 0.25:
				title = "%s: \"O %s vai brigar lá em cima\"" % [nm, user.short_name]
				body = "Mesmo vencendo, o técnico do %s rasgou elogios ao trabalho de %s." % [opp.short_name, me]
				rel = 2.0
		"explosivo":
			if lost and r.randf() < 0.4:
				title = "%s perde a cabeça contra o %s" % [nm, user.short_name]
				body = "Expulso da área técnica, %s ainda discutiu com o banco adversário na saída de campo." % nm
				rel = -3.0
	var us := vs_user(co)
	if title == "" and int(us[2]) >= 3 and int(us[0]) == 0 and won:
		title = "%s segue invicto contra %s" % [nm, me]
		body = "Em %d jogos, %s nunca perdeu para um time de %s (%dV %dE a favor dele)." % [int(us[0]) + int(us[1]) + int(us[2]), nm, me, int(us[2]), int(us[1])]
	elif title == "" and lost and int(us[0]) == 1 and int(us[2]) >= 3:
		title = "%s enfim vence %s" % [me, nm]
		body = "Depois de %d derrotas, o %s quebrou a escrita contra o técnico do %s." % [int(us[2]), user.short_name, opp.short_name]
	if rel != 0.0:
		People.add_coach_rel(world, int(co["id"]), rel)
	if title != "":
		NewsManager.post_raw(world, title, body, opp.id, -1, NewsEvent.IMP_NORMAL, "tecnicos")


# ---------------------------------------------------------------------------
# Temporada
# ---------------------------------------------------------------------------

## Antes do balanço dos técnicos (People.on_season_end): prêmios entram no currículo.
static func season_awards(world: GameWorld, hist_leagues: Dictionary, wcoach: Dictionary) -> void:
	for lid in hist_leagues:
		var a: Dictionary = hist_leagues[lid].get("coach", {})
		if a.is_empty() or bool(a.get("user", false)):
			continue
		var co := CoachCareer.find(world, int(a.get("co", -1)))
		if co.is_empty():
			continue
		var aw: Array = co.get("aw", [])
		aw.append([world.year, "coach", String(lid)])
		co["aw"] = aw
		co["rep"] = minf(99.0, float(co.get("rep", 40.0)) + 3.0)
		moment(world, co, "Eleito o treinador da temporada (%s) pelo %s." % [world.league_short(String(lid)), String(a.get("cn", ""))], "premio")
	if not wcoach.is_empty() and not bool(wcoach.get("user", false)):
		var wc := CoachCareer.find(world, int(wcoach.get("co", -1)))
		if not wc.is_empty():
			var aw2: Array = wc.get("aw", [])
			aw2.append([world.year, "coach_world", ""])
			wc["aw"] = aw2
			wc["rep"] = minf(99.0, float(wc.get("rep", 40.0)) + 5.0)
			moment(world, wc, "Eleito o treinador do ano pelo júri mundial.", "premio")


## Depois do balanço dos técnicos: campanhas, arcos, despedidas e o mercado de técnicos.
static func on_season_end(world: GameWorld, moves: Dictionary, hist_leagues: Dictionary, hist_cups: Dictionary) -> void:
	var pp := People.data(world)
	var r := People.rng(world, 71)
	var champs := {}
	for lid in hist_leagues:
		var cid := int(hist_leagues[lid].get("champion", -1))
		if cid >= 0:
			champs[cid] = "a %s" % world.league_short(String(lid))
	for cup in hist_cups:
		var cid2 := int(hist_cups[cup].get("champion", -1))
		if cid2 >= 0 and not champs.has(cid2):
			champs[cid2] = "a %s" % CupManager.cup_short(String(cup))
	var retire: Array = []
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		var co: Dictionary = pp["coaches"].get(c.id, {})
		if co.is_empty() or bool(co.get("int", false)):
			continue
		temper(world, co)
		co.erase("sov")
		var hire: Dictionary = co.get("hire", {})
		co.erase("hire")
		if c.history.is_empty() or int(c.history.back().get("y", 0)) != world.year:
			continue
		var h: Dictionary = c.history.back()
		var goal := SeasonManager.goal_of(world, c.id)
		var diff := int(goal[1]) - int(h["p"])
		co["sov"] = diff
		var nm := String(co["n"])
		var age := world.year - int(co.get("by", world.year - 50))
		var up := moves.has(c.id) and int(DatabaseManager.league_cfg(moves[c.id]).get("tier", 1)) < c.tier
		var down := moves.has(c.id) and int(DatabaseManager.league_cfg(moves[c.id]).get("tier", 1)) > c.tier
		if champs.has(c.id):
			moment(world, co, "Campeão com o %s (%s)." % [c.short_name, String(champs[c.id]).substr(2)], "titulo")
		if up:
			co["prom"] = int(co.get("prom", 0)) + 1
			moment(world, co, "Levou o %s ao acesso." % c.short_name, "sobe")
		if not hire.is_empty() and int(hire.get("y", 0)) == world.year and not down:
			var zone := int(hire.get("n", 20)) - int(DatabaseManager.league_cfg(c.league_id).get("down", 0))
			if int(DatabaseManager.league_cfg(c.league_id).get("down", 0)) > 0 and int(hire.get("pos", 0)) > zone:
				co["resc"] = int(co.get("resc", 0)) + 1
				moment(world, co, "Chegou com o %s na zona e livrou o time da queda." % c.short_name, "volta")
				_news(world, c, co, "%s, o bombeiro: %s está salvo" % [nm, c.short_name],
					"Quando %s chegou, o %s estava em %dº. Terminou em %dº e segue na divisão." % [nm, c.short_name, int(hire["pos"]), int(h["p"])], true)
		# Volta por cima: quem vinha de demissões e fez uma grande temporada.
		var arc_k := String(co.get("arc", {}).get("k", ""))
		if arc_k == "redencao" and (champs.has(c.id) or diff >= 3):
			co.erase("arc")
			moment(world, co, "A volta por cima: de demitido a destaque da temporada no %s." % c.short_name, "volta")
			_news(world, c, co, "A volta por cima de %s" % nm, "Depois de demissões seguidas, %s fez do %s uma das surpresas da temporada." % [nm, c.short_name], true)
		elif arc_k == "" and diff >= 5 and age <= 45 and not champs.has(c.id):
			co["arc"] = {"k": "revelacao", "y": world.year}
			moment(world, co, "Temporada de revelação: %d posições acima da meta com o %s." % [diff, c.short_name], "sobe")
			_news(world, c, co, "%s, a revelação da temporada" % nm, "Aos %d anos, %s levou o %s ao %dº lugar, bem acima do esperado. Clubes maiores já perguntam por ele." % [age, nm, c.short_name, int(h["p"])], true)
		elif arc_k == "casa" and int(co.get("arc", {}).get("y", world.year)) <= world.year - 3:
			co.erase("arc")
		# Despedida anunciada no ano passado: sai agora, com homenagem.
		if arc_k == "despedida" and int(co.get("arc", {}).get("y", world.year)) < world.year:
			retire.append(c)
		elif arc_k == "" and age >= 66 and r.randf() < 0.3:
			co["arc"] = {"k": "despedida", "y": world.year}
			moment(world, co, "Anunciou que a próxima temporada será a última da carreira.", "marco")
			_news(world, c, co, "%s anuncia a última temporada" % nm, "Aos %d anos, %s avisou que para depois do próximo campeonato. Cada jogo do %s vira uma despedida." % [age, nm, c.short_name])
	for c: Club in retire:
		var co2: Dictionary = pp["coaches"].get(c.id, {})
		var tt := CoachCareer.totals(co2)
		_news(world, c, co2, "O adeus de %s" % String(co2["n"]),
			"%s encerra a carreira no %s com %d jogos, %d vitórias e %d título(s). A torcida fez um mosaico com o rosto dele." % [String(co2["n"]), c.short_name, int(tt["g"]), int(tt["w"]), int(tt["t"])], true)
		ClubDNA.add_log(world, c, "%s se aposenta no comando do clube" % String(co2["n"]))
		People.replace_coach(world, c, "")
	# Quem foi demitido duas vezes seguidas começa a busca pela volta por cima.
	for co3: Dictionary in pp["free"]:
		if co3.has("arc"):
			continue
		var car: Array = co3.get("car", [])
		var dem := 0
		for i in range(car.size() - 1, maxi(-1, car.size() - 4), -1):
			if String(car[i].get("e", "")) == "dem":
				dem += 1
		if dem >= 2:
			co3["arc"] = {"k": "redencao", "y": world.year}
	_market(world, r)


## Mercado de técnicos: clubes maiores vão atrás de quem fez temporada acima da meta num clube
## menor. O ambicioso quase sempre aceita; o fiel costuma recusar (e isso também vira notícia).
static func _market(world: GameWorld, r: RandomNumberGenerator) -> void:
	var pp := People.data(world)
	var stars: Array = []
	for cid in pp["coaches"]:
		var co: Dictionary = pp["coaches"][cid]
		var c := world.club(int(cid))
		if c == null or world.is_user_club(c.id) or bool(co.get("int", false)) or int(co.get("since", 0)) >= world.year:
			continue
		var hot := int(co.get("sov", 0)) >= 3 or String(co.get("arc", {}).get("k", "")) == "revelacao"
		if hot:
			stars.append([co, c])
	stars.sort_custom(func(a, b): return int(a[0].get("sov", 0)) > int(b[0].get("sov", 0)))
	var limit := maxi(4, world.clubs.size() / 40)
	var touched := {}
	var done := 0
	for pair in stars:
		if done >= limit:
			break
		var co: Dictionary = pair[0]
		var here: Club = pair[1]
		if touched.has(here.id) or int(co.get("c", -1)) != here.id:
			continue
		var best: Club = null
		var best_s := -INF
		for t: Club in world.clubs:
			if touched.has(t.id) or world.is_user_club(t.id) or t.id == here.id or t.is_pool():
				continue
			if t.reputation < here.reputation + 6.0 or t.reputation > float(co.get("rep", 40.0)) + 20.0:
				continue
			if t.nation != here.nation and (float(co.get("rep", 40.0)) < 60.0 or r.randf() < 0.7):
				continue
			var cur: Dictionary = pp["coaches"].get(t.id, {})
			var shaky := cur.is_empty() or bool(cur.get("int", false)) or float(cur.get("job", 60.0)) < 58.0 or int(cur.get("sov", 0)) < 0 \
				or String(cur.get("arc", {}).get("k", "")) == "despedida"
			if not shaky:
				continue
			var s := -absf(t.reputation - (here.reputation + 12.0)) + r.randf() * 8.0 + (6.0 if t.nation == here.nation else 0.0)
			if s > best_s:
				best_s = s
				best = t
		if best == null:
			continue
		touched[best.id] = true
		touched[here.id] = true
		var amb := float(TEMPERS[temper(world, co)]["amb"])
		var yes := r.randf() < clampf(0.62 + amb + (best.reputation - here.reputation) / 60.0, 0.1, 0.97)
		var nm := String(co["n"])
		if not yes:
			co["job"] = clampf(float(co.get("job", 60.0)) + 12.0, 0.0, 100.0)
			moment(world, co, "Recusou o %s para seguir no %s." % [best.short_name, here.short_name], "fiel")
			_news(world, here, co, "%s diz não ao %s e fica no %s" % [nm, best.short_name, here.short_name],
				"\"Tenho um projeto aqui e vou até o fim\", disse %s, que recusou a proposta de um clube maior." % nm)
			continue
		done += 1
		People.replace_coach(world, best, "ciclo", "", co)
