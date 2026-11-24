class_name Achievements
extends RefCounted
## Conquistas da carreira: marcas que ficam para sempre no save, com nível (bronze, prata, ouro),
## pontos e um título de gestor que sobe com eles. Cada conquista olha uma medida do mundo: um
## contador da carreira (`GameWorld.life`, alimentado por `Season.bump`) ou o estado de agora
## (reputação, caixa, equipe). `check` roda depois de cada luta do jogador, de cada noite
## fechada e toda semana; quem acabou de sair vai para a caixa de entrada e para a fila de
## comemoração da interface (`GameWorld.pops`).

const TIER_NAMES := ["", "Bronze", "Prata", "Ouro"]
const TIER_POINTS := [0, 10, 25, 50]
const CATS := [["lutas", "Lutas"], ["cinturoes", "Cinturões"], ["noites", "Noites"], ["casa", "A casa"], ["temporada", "Temporada"]]
## Título do gestor pelos pontos somados.
const RANKS := [[0, "Novato"], [40, "Promessa"], [120, "Profissional"], [250, "Respeitado"], [500, "Estrela"], [800, "Lenda"]]

## [chave, papel ("e" empresário, "p" presidente, "" os dois), categoria, nível, título, texto,
## medida, alvo, escondida]
const DEFS := [
	# Empresário: lutas
	["e_luta1", "e", "lutas", 1, "Estreia", "Faça a primeira luta da academia.", "life:fights", 1.0, false],
	["e_vit1", "e", "lutas", 1, "Primeira vitória", "Vença uma luta com um lutador da academia.", "life:wins", 1.0, false],
	["e_vit10", "e", "lutas", 1, "Dez vitórias", "Some 10 vitórias da academia.", "life:wins", 10.0, false],
	["e_vit50", "e", "lutas", 2, "Cinquenta vitórias", "Some 50 vitórias da academia.", "life:wins", 50.0, false],
	["e_vit150", "e", "lutas", 3, "Cento e cinquenta vitórias", "Some 150 vitórias da academia.", "life:wins", 150.0, false],
	["e_ko5", "e", "lutas", 1, "Mão pesada", "Vença 5 lutas por nocaute.", "life:ko", 5.0, false],
	["e_ko25", "e", "lutas", 2, "Demolidores", "Vença 25 lutas por nocaute.", "life:ko", 25.0, false],
	["e_sub5", "e", "lutas", 1, "Arte suave", "Vença 5 lutas por finalização.", "life:sub", 5.0, false],
	["e_sub25", "e", "lutas", 2, "Escola de finalizadores", "Vença 25 lutas por finalização.", "life:sub", 25.0, false],
	["e_r1", "e", "lutas", 1, "Relâmpago", "Vença uma luta no primeiro round.", "life:r1", 1.0, false],
	["e_r1_10", "e", "lutas", 2, "Noite curta", "Vença 10 lutas no primeiro round.", "life:r1", 10.0, false],
	["e_zebra", "e", "lutas", 1, "Zebra", "Vença alguém do top 30 que esteja dez posições ou mais acima.", "life:upsets", 1.0, false],
	["e_zebra5", "e", "lutas", 2, "Caçadores de favoritos", "Vença 5 lutas como zebra.", "life:upsets", 5.0, false],
	["e_seq5", "e", "lutas", 2, "Embalado", "Um lutador da academia com 5 vitórias seguidas.", "life:streak", 5.0, false],
	["e_seq10", "e", "lutas", 3, "Imparável", "Um lutador da academia com 10 vitórias seguidas.", "life:streak", 10.0, false],
	["e_main", "e", "lutas", 2, "Luta principal", "Um lutador da academia na luta principal de uma noite.", "life:main", 1.0, false],
	["e_elite", "e", "lutas", 1, "Na elite", "Um lutador da academia numa noite da Liga Global.", "life:t2_fights", 1.0, false],
	["e_elite10", "e", "lutas", 2, "Casa na elite", "Some 10 vitórias na Liga Global.", "life:t2_wins", 10.0, false],
	# Empresário: cinturões
	["e_disputa", "e", "cinturoes", 2, "Chance de ouro", "Leve um lutador a uma disputa de cinturão.", "life:title_fights", 1.0, false],
	["e_cinturao", "e", "cinturoes", 3, "Campeão do mundo", "Conquiste um cinturão.", "life:belts", 1.0, false],
	["e_cinturao3", "e", "cinturoes", 3, "Fábrica de campeões", "Conquiste 3 cinturões.", "life:belts", 3.0, false],
	["e_defesa", "e", "cinturoes", 2, "E ainda campeão", "Defenda um cinturão.", "life:defs", 1.0, false],
	["e_defesa5", "e", "cinturoes", 3, "Dinastia", "Some 5 defesas de cinturão.", "life:defs", 5.0, false],
	["e_dois", "e", "cinturoes", 3, "Dois tronos", "Tenha dois campeões na academia ao mesmo tempo.", "champs", 2.0, false],
	# Empresário: a casa
	["e_equipe3", "e", "casa", 1, "Equipe montada", "Tenha 3 lutadores na equipe.", "roster", 3.0, false],
	["e_equipe8", "e", "casa", 2, "Academia cheia", "Tenha 8 lutadores na equipe.", "roster", 8.0, false],
	["e_staff3", "e", "casa", 1, "Comissão técnica", "Tenha 3 profissionais no staff.", "staff", 3.0, false],
	["e_staff6", "e", "casa", 2, "Estrutura de ponta", "Tenha 6 profissionais no staff.", "staff", 6.0, false],
	["e_contrato5", "e", "casa", 1, "Olho clínico", "Contrate 5 lutadores.", "life:signed", 5.0, false],
	["e_rep40", "e", "casa", 1, "Respeitada", "Chegue a 40 de reputação.", "rep", 40.0, false],
	["e_rep60", "e", "casa", 2, "Uma das grandes", "Chegue a 60 de reputação.", "rep", 60.0, false],
	["e_rep80", "e", "casa", 3, "Referência mundial", "Chegue a 80 de reputação.", "rep", 80.0, false],
	["e_bolsa100", "e", "casa", 1, "Primeiros cem mil", "Some US$ 100 mil em bolsas para a academia.", "life:purse", 100000.0, false],
	["e_bolsa1m", "e", "casa", 2, "Um milhão em bolsas", "Some US$ 1 milhão em bolsas para a academia.", "life:purse", 1000000.0, false],
	["e_cash500", "e", "casa", 2, "Caixa forte", "Tenha US$ 500 mil em caixa.", "cash", 500000.0, false],
	["e_cash2m", "e", "casa", 3, "Império", "Tenha US$ 2 milhões em caixa.", "cash", 2000000.0, false],
	["e_vermelho", "e", "casa", 1, "No vermelho", "Deixe o caixa da academia abaixo de zero.", "debt", 1.0, true],
	["e_apoio", "e", "temporada", 2, "Orgulho da cidade", "Leve o apoio da cidade a 75, a faixa mais alta.", "sup", 75.0, false],
	# Presidente: noites
	["p_noite1", "p", "noites", 1, "Primeira noite", "Feche a primeira noite da liga.", "life:nights", 1.0, false],
	["p_noite26", "p", "noites", 2, "Um ano de noites", "Feche 26 noites.", "life:nights", 26.0, false],
	["p_noite100", "p", "noites", 3, "Cem noites", "Feche 100 noites.", "life:nights", 100.0, false],
	["p_lotada1", "p", "noites", 1, "Casa cheia", "Lote uma arena.", "life:sold", 1.0, false],
	["p_lotada25", "p", "noites", 2, "Ingressos esgotados", "Lote 50 noites.", "life:sold", 50.0, false],
	["p_arena18", "p", "noites", 2, "Arena grande", "Leve 18 mil pessoas a uma noite.", "life:crowd_best", 18000.0, false],
	["p_arena30", "p", "noites", 3, "Estádio", "Leve 30 mil pessoas a uma noite.", "life:crowd_best", 30000.0, false],
	["p_quente", "p", "noites", 1, "Noite quente", "Faça uma noite com hype de 70.", "life:hype_best", 70.0, false],
	["p_fogo", "p", "noites", 2, "Pegando fogo", "Faça 10 noites com hype de 85 ou mais.", "life:fire", 10.0, false],
	["p_historica", "p", "noites", 3, "Liga em chamas", "Faça 60 noites com hype de 85 ou mais.", "life:fire", 60.0, false],
	["p_ppv250", "p", "noites", 1, "Evento que vende", "Venda 250 mil compras de pay-per-view numa noite.", "life:ppv_best", 250000.0, false],
	["p_ppv500", "p", "noites", 2, "Meio milhão de compras", "Venda 500 mil compras de pay-per-view numa noite.", "life:ppv_best", 500000.0, false],
	["p_ppv1m", "p", "noites", 3, "Um milhão de compras", "Venda 1 milhão de compras de pay-per-view numa noite.", "life:ppv_best", 1000000.0, false],
	["p_publico", "p", "noites", 2, "Meio milhão nas arenas", "Some 500 mil pessoas de público.", "life:crowd", 500000.0, false],
	["p_publico2", "p", "noites", 3, "Dois milhões nas arenas", "Some 2 milhões de pessoas de público.", "life:crowd", 2000000.0, false],
	["p_fin100", "p", "noites", 2, "Liga dos nocautes", "Some 500 lutas da liga terminadas antes do fim.", "life:fin", 500.0, false],
	["p_card5", "p", "noites", 1, "Card completo", "Feche 5 noites com todas as vagas do card preenchidas.", "life:full", 5.0, false],
	["p_card50", "p", "noites", 2, "Cinquenta cards completos", "Feche 50 noites com o card completo.", "life:full", 50.0, false],
	# Presidente: cinturões
	["p_cint1", "p", "cinturoes", 1, "Vale o cinturão", "Promova uma disputa de cinturão.", "life:title_bouts", 1.0, false],
	["p_cint25", "p", "cinturoes", 2, "Vinte e cinco disputas", "Promova 25 disputas de cinturão.", "life:title_bouts", 25.0, false],
	["p_cint100", "p", "cinturoes", 3, "Cem disputas de cinturão", "Promova 100 disputas de cinturão.", "life:title_bouts", 100.0, false],
	["p_novo10", "p", "cinturoes", 2, "Troca de guarda", "Veja 25 campeões novos coroados na liga.", "life:new_champs", 25.0, false],
	["p_marcar10", "p", "cinturoes", 1, "Matchmaker", "Marque 10 lutas com a própria mão.", "life:booked", 10.0, false],
	["p_marcar100", "p", "cinturoes", 2, "Mão na massa", "Marque 100 lutas com a própria mão.", "life:booked", 100.0, false],
	["p_marcar300", "p", "cinturoes", 3, "Dono do card", "Marque 300 lutas com a própria mão.", "life:booked", 300.0, false],
	["p_estrelas", "p", "cinturoes", 2, "Fábrica de estrelas", "Tenha 20 lutadores da liga com fama de 95.", "stars95", 20.0, false],
	# Presidente: a casa
	["p_rep65", "p", "casa", 1, "Liga respeitada", "Chegue a 65 de prestígio.", "rep", 65.0, false],
	["p_rep80", "p", "casa", 2, "Liga de ponta", "Chegue a 80 de prestígio.", "rep", 80.0, false],
	["p_rep92", "p", "casa", 3, "A maior do mundo", "Chegue a 92 de prestígio.", "rep", 92.0, false],
	["p_tv", "p", "casa", 1, "No ar", "Assine um contrato de TV.", "life:tv", 1.0, false],
	["p_cash30", "p", "casa", 1, "Cofre cheio", "Tenha US$ 50 milhões em caixa.", "cash", 50000000.0, false],
	["p_cash100", "p", "casa", 2, "Cem milhões", "Tenha US$ 100 milhões em caixa.", "cash", 100000000.0, false],
	["p_cash500", "p", "casa", 3, "Meio bilhão", "Tenha US$ 500 milhões em caixa.", "cash", 500000000.0, false],
	["p_apoio", "p", "temporada", 2, "Carta branca", "Leve a confiança dos sócios a 75, a faixa mais alta.", "sup", 75.0, false],
	["p_interv", "p", "temporada", 1, "Na marca do pênalti", "Sofra uma intervenção dos sócios.", "life:interv", 1.0, true],
	["p_mandato", "p", "temporada", 2, "Segundo mandato", "Comece um mandato novo depois de perder o primeiro.", "life:terms", 2.0, true],
	# Os dois papéis: temporada
	["x_tut", "", "temporada", 1, "Primeiros passos", "Conclua o tutorial guiado.", "life:tut", 1.0, false],
	["x_meta1", "", "temporada", 1, "Meta batida", "Cumpra uma meta da temporada.", "life:goals_met", 1.0, false],
	["x_meta10", "", "temporada", 2, "Dez metas", "Cumpra 10 metas da temporada.", "life:goals_met", 10.0, false],
	["x_meta30", "", "temporada", 3, "Trinta metas", "Cumpra 30 metas da temporada.", "life:goals_met", 30.0, false],
	["x_ouro", "", "temporada", 3, "Ano de ouro", "Cumpra as três metas de um mesmo ano.", "life:gold", 1.0, false],
	["x_ano1", "", "temporada", 1, "Um ano de casa", "Complete uma temporada.", "life:years", 1.0, false],
	["x_ano5", "", "temporada", 2, "Cinco temporadas", "Complete 5 temporadas.", "life:years", 5.0, false],
	["x_ano10", "", "temporada", 3, "Dez temporadas", "Complete 10 temporadas.", "life:years", 10.0, false],
]


## As conquistas do papel do jogador.
static func list(w: GameWorld) -> Array:
	var role := "p" if w.is_president() else "e"
	var out: Array = []
	for d: Array in DEFS:
		if String(d[1]) == "" or String(d[1]) == role:
			out.append(d)
	return out


static func by_key(key: String) -> Array:
	for d: Array in DEFS:
		if String(d[0]) == key:
			return d
	return []


static func has(w: GameWorld, key: String) -> bool:
	return w.feats.has(key)


## Valor de agora de uma medida.
static func measure(w: GameWorld, m: String) -> float:
	var t := w.user_team()
	if m.begins_with("life:"):
		return Season.life(w, m.substr(5))
	match m:
		"rep":
			return t.reputation if t != null else 0.0
		"cash":
			return t.balance if t != null else 0.0
		"debt":
			return 1.0 if t != null and t.balance < 0.0 else 0.0
		"roster":
			return float(w.user_fighters().size())
		"staff":
			return float(t.staff.size()) if t != null else 0.0
		"champs":
			var n := 0
			for f: Fighter in w.user_fighters():
				if w.rank_of(f) == 0:
					n += 1
			return float(n)
		"sup":
			return Season.value_of(w)
		"stars95":
			return float(Season.stars(w, 95.0))
	return 0.0


## {done, week, val, n, frac}
static func progress(w: GameWorld, d: Array) -> Dictionary:
	var key := String(d[0])
	var n := float(d[7])
	if w.feats.has(key):
		return {"done": true, "week": int(w.feats[key]), "val": n, "n": n, "frac": 1.0}
	var v := measure(w, String(d[6]))
	return {"done": false, "week": -1, "val": v, "n": n, "frac": clampf(v / maxf(0.001, n), 0.0, 1.0)}


## Confere tudo e marca o que saiu. `silent`: sem notícia nem comemoração (save antigo que já
## chega com reputação, caixa e equipe). Devolve quantas saíram agora.
static func check(w: GameWorld, silent: bool = false) -> int:
	if w.user_team() == null:
		return 0
	var n := 0
	for d: Array in list(w):
		var key := String(d[0])
		if w.feats.has(key):
			continue
		if measure(w, String(d[6])) >= float(d[7]):
			w.feats[key] = w.week
			n += 1
			if not silent:
				w.add_news("conquista", "Conquista: %s (%s). %s" % [String(d[4]), String(TIER_NAMES[int(d[3])]).to_lower(), String(d[5])], [], int(d[3]) >= 2)
				Season.pop(w, "feat", String(d[4]), "%s · %d pontos" % [String(TIER_NAMES[int(d[3])]), int(TIER_POINTS[int(d[3])])])
	return n


static func points(w: GameWorld) -> int:
	var p := 0
	for d: Array in list(w):
		if w.feats.has(String(d[0])):
			p += int(TIER_POINTS[int(d[3])])
	return p


static func total_points(w: GameWorld) -> int:
	var p := 0
	for d: Array in list(w):
		p += int(TIER_POINTS[int(d[3])])
	return p


static func count(w: GameWorld) -> int:
	var n := 0
	for d: Array in list(w):
		if w.feats.has(String(d[0])):
			n += 1
	return n


## Título do gestor: {name, at (pontos do título), next (pontos do próximo, -1 no topo), next_name}.
static func rank(w: GameWorld) -> Dictionary:
	var p := points(w)
	var cur: Array = RANKS[0]
	var nxt: Array = []
	for r: Array in RANKS:
		if p >= int(r[0]):
			cur = r
		elif nxt.is_empty():
			nxt = r
	return {"name": String(cur[1]), "at": int(cur[0]), "next": int(nxt[0]) if not nxt.is_empty() else -1, "next_name": String(nxt[1]) if not nxt.is_empty() else ""}


## As que estão mais perto de sair (não escondidas), para o painel: [[def, progresso], ...].
static func next_up(w: GameWorld, limit: int = 3) -> Array:
	var out: Array = []
	for d: Array in list(w):
		if w.feats.has(String(d[0])) or bool(d[8]):
			continue
		out.append([d, progress(w, d)])
	out.sort_custom(func(a: Array, b: Array) -> bool:
		var fa := float((a[1] as Dictionary)["frac"])
		var fb := float((b[1] as Dictionary)["frac"])
		if not is_equal_approx(fa, fb):
			return fa > fb
		return int((a[0] as Array)[3]) < int((b[0] as Array)[3]))
	return out.slice(0, limit)


## As últimas que saíram: [def, ...], da mais nova para a mais velha.
static func recent(w: GameWorld, limit: int = 3) -> Array:
	var got: Array = []
	for d: Array in list(w):
		if w.feats.has(String(d[0])):
			got.append(d)
	got.sort_custom(func(a: Array, b: Array) -> bool: return int(w.feats[String(a[0])]) > int(w.feats[String(b[0])]))
	return got.slice(0, limit)


static func value_text(d: Array, v: float) -> String:
	var m := String(d[6])
	if m in ["cash", "life:purse"]:
		return Fmt.money(v)
	if float(d[7]) >= 10000.0:
		return Fmt.thousands(int(v))
	return str(int(floor(v + 0.001)))
