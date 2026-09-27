class_name Pundits
extends RefCounted
## Comentaristas de TV nos jogos grandes (clássico, decisão, jogo de copa ou topo da tabela):
##   prévia no estúdio antes do apito e mesa-redonda depois do jogo. Tudo sai dos dados de verdade:
##   fase dos times (últimos resultados), tabela, retrospecto do confronto, craques, estilo e,
##   depois, xG, posse, finalizações, cartões, quem decidiu e a nota dos jogadores.
## Cada comentarista tem um jeito: o ex-jogador (fala de raça e vestiário), o analista (números e
## tática) e o polêmico (arbitragem, cobrança, frase de efeito).

const STYLES: Array[String] = ["ex-jogador", "analista", "polêmico"]


static func is_big(sim: MatchSimulation) -> bool:
	return sim.derby or sim.importance >= 0.7 or sim.knockout


## Os três do estúdio (nomes do país da competição, fixos por mundo).
static func panel(w: GameWorld, nation: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.world_seed, nation, "estudio"])
	var out: Array = []
	for st in STYLES:
		var o := NameGenerator.pick_origin(rng, nation if nation != "" else "BRA")
		var n := NameGenerator.generate(rng, String(o["c"]), {}, {})
		out.append({"name": "%s %s" % [n["first"], n["last"]], "style": st})
	return out


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
	return "oscilando"


## Prévia: [[comentarista, fala]].
static func preview(w: GameWorld, sim: MatchSimulation, nation: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([w.world_seed, sim.teams[0].club.id, sim.teams[1].club.id, w.year, sim.importance])
	var p := panel(w, nation)
	var home: Club = sim.teams[0].club
	var away: Club = sim.teams[1].club
	var out: Array = []
	# Ex-jogador: clima, fase e vestiário
	var line := ""
	if sim.derby:
		line = ["Clássico é outro campeonato. Não importa a fase: quem errar menos, leva.", "Nesse jogo a torcida entra em campo junto. Quem tremer, perde.", "Já joguei muito clássico: no túnel ninguém fala nada, é só olhar."][rng.randi_range(0, 2)]
	elif _form(home).length() < 3 and _form(away).length() < 3:
		line = "Começo de temporada: os dois ainda estão se conhecendo. Quem encaixar primeiro sai na frente."
	else:
		line = "O %s chega %s; o %s, %s. Jogo grande se ganha no detalhe." % [home.short_name, _form_word(home), away.short_name, _form_word(away)]
	out.append([p[0], line])
	# Analista: retrospecto, craques e estilo
	var h := FootballMemory.head_to_head(w, home.id, away.id)
	var a_line := ""
	if int(h["games"]) >= 3:
		a_line = "No retrospecto, o %s tem %d vitórias, %d empates e %d derrotas contra o %s. " % [home.short_name, int(h["wins"]), int(h["draws"]), int(h["losses"]), away.short_name]
	var sh := _star(sim.teams[0])
	var sa := _star(sim.teams[1])
	if sh != null and sa != null:
		a_line += "Os nomes são %s e %s: quem tiver a bola nos pés deles, dita o jogo." % [sh.display_name(), sa.display_name()]
	out.append([p[1], a_line])
	# Polêmico: cobrança e aposta
	var fav := 0 if ClubAI.team_strength(w, home) + 2.0 >= ClubAI.team_strength(w, away) else 1
	var c_fav: Club = sim.teams[fav].club
	var c_und: Club = sim.teams[1 - fav].club
	var pol := ["Se o %s não ganhar hoje, tem que ter cobrança. Não tem desculpa." % c_fav.short_name,
		"Vou dizer: o %s vai surpreender. Favorito demais costuma tropeçar." % c_und.short_name,
		"O árbitro vai ter trabalho. Espero que não apareça mais que os jogadores.",
		"Meu palpite? %s por um gol. E ninguém vai lembrar da tática, só do resultado." % c_fav.short_name]
	out.append([p[2], pol[rng.randi_range(0, pol.size() - 1)]])
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
	var out: Array = []
	# Ex-jogador: raça e quem decidiu
	var motm := sim.man_of_the_match()
	var l1 := ""
	if win < 0:
		l1 = "Empate com cara de jogo pegado. Ninguém quis perder e isso também conta."
	else:
		var wt: MatchTeam = sim.teams[win]
		l1 = "O %s quis mais. Deu para ver no olho dos jogadores." % wt.club.short_name
	if motm != null:
		l1 += " E %s foi o melhor em campo, nota %.1f." % [motm.p.display_name(), motm.final_rating]
	out.append([p[0], l1])
	# Analista: números
	var ph := int(round(sim.possession_pct(0) * 100.0))
	var l2 := ("Posse %d%% a %d%%, finalizações %d a %d, xG %.1f a %.1f. " % [ph, 100 - ph, h.shots, a.shots, h.xg, a.xg]).replace(".", ",").trim_suffix(", ") + ". "
	var xg_w := 0 if h.xg > a.xg + 0.4 else (1 if a.xg > h.xg + 0.4 else -1)
	if win >= 0 and xg_w >= 0 and xg_w != win:
		l2 += "O resultado mentiu: quem criou mais foi o %s." % sim.teams[xg_w].club.short_name
	elif win >= 0 and xg_w == win:
		l2 += "Vitória justa, os números confirmam."
	elif win < 0 and xg_w >= 0:
		l2 += "O %s mereceu mais, mas faltou pontaria." % sim.teams[xg_w].club.short_name
	else:
		l2 += "Jogo equilibrado de verdade."
	out.append([p[1], l2])
	# Polêmico: arbitragem, cartões, cobrança
	var cards := h.yellows + a.yellows
	var reds := h.reds + a.reds
	var l3 := ""
	if reds > 0:
		l3 = "A expulsão mudou o jogo. Foi justa? Para mim, o árbitro exagerou."
	elif cards >= 7:
		l3 = "%d cartões: o juiz perdeu o controle cedo." % cards
	elif win >= 0:
		var lt: MatchTeam = sim.teams[1 - win]
		l3 = ["O %s precisa se olhar no espelho. Com esse futebol, não vai longe." % lt.club.short_name,
			"Tem gente no %s que não pode vestir essa camisa num jogo desses." % lt.club.short_name,
			"Cadê o plano B do técnico do %s? Ficou assistindo." % lt.club.short_name][rng.randi_range(0, 2)]
	else:
		l3 = "Empate bom para quem? Para ninguém. Os dois saem devendo."
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
		row.add_child(UIKit.colored("%s · %s" % [String(who["name"]), String(who["style"])], Color("#8FD9C5"), "Caps"))
		row.add_child(UIKit.label("“%s”" % String(l[1]), "", true))
		v.add_child(row)
	return UIKit.card_panel(v)
