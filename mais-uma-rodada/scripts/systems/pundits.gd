class_name Pundits
extends RefCounted
## Comentaristas de TV nos jogos grandes (clássico, decisão, jogo de copa ou topo da tabela):
##   prévia no estúdio antes do apito e mesa-redonda depois do jogo. Tudo sai dos dados de verdade:
##   fase dos times (últimos resultados), tabela, retrospecto do confronto, craques, estilo e,
##   depois, xG, posse, finalizações, cartões, quem decidiu e a nota dos jogadores.
## Cada comentarista tem um assunto (clima e enredo, números, arbitragem e expectativa), mas a
## tela mostra só o nome: ninguém é apresentado como "o polêmico".

const STYLES: Array[String] = ["ex-jogador", "analista", "polêmico"]


static func is_big(sim: MatchSimulation) -> bool:
	return sim.derby or sim.importance >= 0.7 or sim.knockout


## Os três do estúdio (nomes do país da competição, fixos por mundo). O jeito de cada um ("style")
## só escolhe o tipo de fala; na tela aparece como apresentador/comentarista, sem rótulo.
static func panel(w: GameWorld, nation: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.world_seed, nation, "estudio"])
	var out: Array = []
	var roles := ["Comentarista", "Comentarista", "Comentarista"]
	for i in STYLES.size():
		var o := NameGenerator.pick_origin(rng, nation if nation != "" else "BRA")
		var n := NameGenerator.generate(rng, String(o["c"]), {}, {})
		out.append({"name": "%s %s" % [n["first"], n["last"]], "style": STYLES[i], "role": roles[i]})
	return out


static func _pick(rng: RandomNumberGenerator, arr: Array) -> String:
	return String(arr[rng.randi_range(0, arr.size() - 1)])


static func _form(c: Club) -> String:
	return c.results.right(5)


static func _form_word(c: Club) -> String:
	var f := _form(c)
	var w := f.count("V")
	var l := f.count("D")
	if f.length() < 3:
		return "ainda procurando ritmo"
	if w >= 4:
		return "voando (%s nos últimos jogos)" % f
	if l >= 3:
		return "em crise (%s nos últimos jogos)" % f
	if w >= 3:
		return "em boa fase"
	if f.count("E") >= 3:
		return "empatando demais"
	return "oscilando"


## Posição na tabela da liga ("" se não houver).
static func _table_note(w: GameWorld, c: Club) -> String:
	var lg := w.league_of(c.id)
	if lg == null or not lg.table.has(c.id) or int(lg.table[c.id]["pl"]) < 4:
		return ""
	var pos := CompetitionManager.position_of(lg, c.id)
	var n := lg.club_ids.size()
	if pos == 1:
		return "líder da %s" % w.league_short(lg.id)
	if pos <= 4:
		return "%dº colocado, brigando lá em cima" % pos
	if pos > n - 4:
		return "%dº, perto da zona de rebaixamento" % pos
	return "%dº na tabela" % pos


## Prévia: [[comentarista, fala]].
static func preview(w: GameWorld, sim: MatchSimulation, nation: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.world_seed, sim.teams[0].club.id, sim.teams[1].club.id, w.year, sim.importance])
	var p := panel(w, nation)
	var home: Club = sim.teams[0].club
	var away: Club = sim.teams[1].club
	var out: Array = []
	# Clima, fase e vestiário
	var line := ""
	if sim.derby:
		line = _pick(rng, ["Clássico é outro campeonato. Não importa a fase: quem errar menos, leva.",
			"Nesse jogo a torcida entra em campo junto. Quem tremer, perde.",
			"No túnel ninguém fala nada, é só olhar. Clássico se decide na cabeça.",
			"Tabela não entra em campo hoje. O %s e o %s jogam pela cidade." % [home.short_name, away.short_name],
			"Clássico tem memória: quem perdeu o último vai entrar mordido."])
	elif sim.knockout:
		line = _pick(rng, ["Mata-mata não perdoa: um erro e acabou a temporada nessa competição.",
			"Jogo de mata-mata é paciência. Quem se desesperar primeiro, dança.",
			"Aqui vale mais a cabeça do que as pernas. Experiência pesa."])
	elif _form(home).length() < 3 and _form(away).length() < 3:
		line = "Começo de temporada: os dois ainda estão se conhecendo. Quem encaixar primeiro sai na frente."
	else:
		line = "O %s chega %s; o %s, %s." % [home.short_name, _form_word(home), away.short_name, _form_word(away)]
		var tn := _table_note(w, home)
		if tn != "":
			line += " O dono da casa é %s." % tn
	out.append([p[0], line])
	# Retrospecto, craques e estilo
	var h := FootballMemory.head_to_head(w, home.id, away.id)
	var a_line := ""
	if int(h["games"]) >= 3:
		a_line = "No retrospecto, o %s tem %d vitórias, %d empates e %d derrotas contra o %s. " % [home.short_name, int(h["wins"]), int(h["draws"]), int(h["losses"]), away.short_name]
	var sh := _star(sim.teams[0])
	var sa := _star(sim.teams[1])
	if sh != null and sa != null:
		a_line += _pick(rng, ["De olho em %s e %s: quem tiver a bola nos pés deles dita o jogo." % [sh.display_name(), sa.display_name()],
			"%s tem %d gols na temporada; do outro lado, %s tem %d. Duelo à parte." % [sh.display_name(), sh.stats[Player.S_GOALS], sa.display_name(), sa.stats[Player.S_GOALS]],
			"Se %s tiver espaço entre as linhas, o %s sofre. E vice-versa com %s." % [sh.display_name(), away.short_name, sa.display_name()]])
	out.append([p[1], a_line.strip_edges()])
	# Aposta e expectativa
	var fav := 0 if ClubAI.team_strength(w, home) + 2.0 >= ClubAI.team_strength(w, away) else 1
	var c_fav: Club = sim.teams[fav].club
	var c_und: Club = sim.teams[1 - fav].club
	out.append([p[2], _pick(rng, ["O favorito é o %s, e favorito tem obrigação de propor o jogo." % c_fav.short_name,
		"Cuidado com o %s: time que chega sem pressão costuma surpreender." % c_und.short_name,
		"Meu palpite? %s por um gol. Jogo truncado, decidido na bola parada." % c_fav.short_name,
		"Se o %s fizer o primeiro, o jogo muda de figura. Aí o %s vai ter que se abrir." % [c_und.short_name, c_fav.short_name],
		"Vejo empate no primeiro tempo e o jogo se resolvendo nas substituições.",
		"O %s tem mais elenco. Se o jogo for até o fim equilibrado, o banco decide." % c_fav.short_name])])
	return out


## Mesa-redonda depois do jogo: [[comentarista, fala]].
static func review(w: GameWorld, sim: MatchSimulation, nation: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.world_seed, sim.teams[0].club.id, sim.score[0], sim.score[1], w.year])
	var p := panel(w, nation)
	var h: MatchTeam = sim.teams[0]
	var a: MatchTeam = sim.teams[1]
	var hg := sim.score[0]
	var ag := sim.score[1]
	var win := 0 if hg > ag else (1 if ag > hg else -1)
	# Enredo do jogo a partir dos gols
	var run := [0, 0]
	var trailed := [false, false]
	var last_goal_min := 0
	var last_goal_side := -1
	var scorers := {}
	for ev in sim.events:
		var t: int = ev["t"]
		if t == MatchSimulation.EV_GOAL or t == MatchSimulation.EV_OWN_GOAL:
			var sd := int(ev["s"])
			run[sd] += 1
			if run[0] < run[1]:
				trailed[0] = true
			if run[1] < run[0]:
				trailed[1] = true
			last_goal_min = int(ev["m"])
			last_goal_side = sd
			if t == MatchSimulation.EV_GOAL:
				scorers[int(ev["p"])] = int(scorers.get(int(ev["p"]), 0)) + 1
	var out: Array = []
	# Quem decidiu e o enredo
	var motm := sim.man_of_the_match()
	var l1 := ""
	if win >= 0 and trailed[win]:
		l1 = _pick(rng, ["Virada de quem não desistiu. O %s estava perdendo e buscou." % sim.teams[win].club.short_name,
			"Que virada do %s! Time que acredita até o fim ganha jogo assim." % sim.teams[win].club.short_name])
	elif win >= 0 and last_goal_side == win and last_goal_min >= 85 and absi(hg - ag) == 1:
		l1 = _pick(rng, ["Gol no fim, aos %d, e três pontos. Isso é time com fome." % last_goal_min,
			"Decidiu aos %d minutos. Esse tipo de vitória vale mais que três pontos." % last_goal_min])
	elif win >= 0 and absi(hg - ag) >= 3:
		l1 = _pick(rng, ["Atropelo. O %s foi superior do começo ao fim." % sim.teams[win].club.short_name,
			"Placar elástico, e poderia ser mais. O %s sobrou em campo." % sim.teams[win].club.short_name])
	elif win < 0:
		l1 = _pick(rng, ["Empate com cara de jogo pegado. Ninguém quis perder.",
			"Um ponto para cada, e os dois saem achando que podiam mais.",
			"Jogo de xadrez: os dois se anularam e o empate foi justo."])
	else:
		l1 = _pick(rng, ["O %s quis mais e mereceu." % sim.teams[win].club.short_name,
			"Vitória de time organizado. O %s sabia o que fazer com e sem a bola." % sim.teams[win].club.short_name,
			"O %s foi mais eficiente nas duas áreas, e jogo grande é isso." % sim.teams[win].club.short_name])
	for pid in scorers:
		if int(scorers[pid]) >= 3:
			var pl := w.player(int(pid))
			if pl != null:
				l1 += " E que noite de %s: %d gols!" % [pl.display_name(), int(scorers[pid])]
	if motm != null:
		l1 += " Melhor em campo: %s, nota %.1f." % [motm.p.display_name(), motm.final_rating]
	out.append([p[0], l1])
	# Números
	var ph := int(round(sim.possession_pct(0) * 100.0))
	var l2 := ("Posse %d%% a %d%%, finalizações %d a %d, xG %.1f a %.1f. " % [ph, 100 - ph, h.shots, a.shots, h.xg, a.xg]).replace(".", ",").trim_suffix(", ") + ". "
	var xg_w := 0 if h.xg > a.xg + 0.4 else (1 if a.xg > h.xg + 0.4 else -1)
	if win >= 0 and xg_w >= 0 and xg_w != win:
		l2 += _pick(rng, ["O resultado não conta a história: quem criou mais foi o %s." % sim.teams[xg_w].club.short_name,
			"O %s produziu mais e saiu sem nada. Futebol às vezes é injusto." % sim.teams[xg_w].club.short_name])
	elif win >= 0 and xg_w == win:
		l2 += _pick(rng, ["Vitória justa, os números confirmam.", "Os números batem com o placar: domínio claro."])
	elif win < 0 and xg_w >= 0:
		l2 += "O %s mereceu mais, mas faltou pontaria." % sim.teams[xg_w].club.short_name
	elif ph >= 62 or ph <= 38:
		var pos_side := 0 if ph >= 62 else 1
		l2 += "Um time com a bola, o outro esperando. O %s controlou a posse." % sim.teams[pos_side].club.short_name
	else:
		l2 += "Jogo equilibrado de verdade."
	out.append([p[1], l2])
	# Arbitragem, disciplina, o que vem pela frente
	var cards := h.yellows + a.yellows
	var reds := h.reds + a.reds
	var l3 := ""
	if reds > 0:
		l3 = _pick(rng, ["A expulsão mudou o jogo. Com um a menos, fica difícil sustentar.",
			"O vermelho pesou. Dali em diante, foi outro jogo."])
	elif cards >= 7:
		l3 = "%d cartões: jogo muito faltoso, a arbitragem teve trabalho." % cards
	elif win >= 0:
		var lt: MatchTeam = sim.teams[1 - win]
		var wt: MatchTeam = sim.teams[win]
		var tn := _table_note(w, wt.club)
		l3 = _pick(rng, ["O %s precisa rever muita coisa. Faltou intensidade." % lt.club.short_name,
			"O técnico do %s tentou mexer, mas as trocas não mudaram o jogo." % lt.club.short_name,
			"Para o %s fica a lição: sem o meio-campo, não se cria nada." % lt.club.short_name,
			("O %s segue %s. Moral lá em cima." % [wt.club.short_name, tn]) if tn != "" else "Três pontos que dão moral para a sequência."])
	else:
		l3 = _pick(rng, ["Empate que não ajuda nenhum dos dois na tabela.", "Nenhum dos dois arriscou. Faltou coragem nas substituições.",
			"Os goleiros foram bem. Quando é assim, o empate é justo."])
	out.append([p[2], l3])
	return out


static func _star(t: MatchTeam) -> Player:
	var best: Player = null
	for mp in t.slots:
		if mp != null and (best == null or mp.p.overall + (3 if mp.w_att >= 0.5 else 0) > best.overall):
			best = mp.p
	return best


## Cartão com as falas (para a abertura e para o fim de jogo).
static func card(title: String, lines: Array) -> Control:
	var v := UIKit.card("Card", 8)
	v.add_child(UIKit.section(title))
	for l in lines:
		var who: Dictionary = l[0]
		var row := UIKit.vbox(2)
		row.add_child(UIKit.colored(String(who["name"]), Color("#8FD9C5"), "Caps"))
		row.add_child(UIKit.label("“%s”" % String(l[1]), "", true))
		v.add_child(row)
	return UIKit.card_panel(v)
