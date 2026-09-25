class_name PressRoom
extends RefCounted
## Imprensa com memória, como na vida real:
##   - Palpites da pré-temporada: cada setorista crava a posição do seu time e o campeão; no fim,
##     o jornal cobra (e se cobra) pelo acerto.
##   - Termômetro do cargo: resultados contra o esperado, diretoria, torcida e clima com a imprensa.
##   - Bolsa de apostas: quem cai primeiro entre os técnicos da sua liga.
##   - Rumores de mercado com fonte. Veículo sério costuma acertar, o sensacionalista inventa; cada
##     um tem um placar de acertos que o jogo vai montando com as transferências de verdade.
##   - Coletiva depois de jogos marcantes, frases que voltam para cobrar e jogadores que falam.
## Estado em People.data(world)["press"]: pred (palpites), quotes (frases guardadas), rum (rumores),
## acc (acertos por jornalista), match (último jogo, para a coletiva), hot, rt e odds_t (controle).

## Chance de o rumor ter fundamento, pelo perfil do jornalista (e placar inicial de acertos).
const RELIABILITY := {"analitico": 0.8, "amigavel": 0.62, "critico": 0.6, "bairrista": 0.45, "sensacionalista": 0.3}
## Viés do palpite (posições): o bairrista é otimista, o crítico pessimista.
const PRED_BIAS := {"analitico": 0.0, "amigavel": -1.0, "critico": 1.5, "bairrista": -2.0, "sensacionalista": 0.0}
const PRED_SD := {"analitico": 1.2, "amigavel": 2.0, "critico": 2.0, "bairrista": 2.0, "sensacionalista": 3.5}
const HEADLINE := {
	"sensacionalista": "%s solta o verbo: %s", "critico": "%s na defensiva: %s", "amigavel": "%s confiante: %s",
	"analitico": "%s: %s", "bairrista": "%s mexe com a torcida: %s",
}
const MAX_RUMORS := 16
const HOT := 70.0


static func _st(world: GameWorld) -> Dictionary:
	var pr: Dictionary = People.data(world)["press"]
	for k in ["quotes", "rum"]:
		if not pr.has(k):
			pr[k] = []
	if not pr.has("acc"):
		pr["acc"] = {}
	return pr


static func _tone(j: Dictionary) -> String:
	return String(j.get("t", "analitico"))


static func journalist_by_tone(world: GameWorld, tone: String, r: RandomNumberGenerator) -> Dictionary:
	var js := People.journalists(world)
	for j: Dictionary in js:
		if _tone(j) == tone:
			return j
	return RngUtil.pick(r, js) if not js.is_empty() else {}


# ---------------------------------------------------------------------------
# Palpites da pré-temporada
# ---------------------------------------------------------------------------

## Monta os palpites do ano (uma vez por temporada e liga). `announce`: publica a notícia.
static func ensure_predictions(world: GameWorld, announce: bool = true) -> Dictionary:
	if not world.has_user():
		return {}
	var pr := _st(world)
	var lid := world.user_league_id()
	var pred: Dictionary = pr.get("pred", {})
	if int(pred.get("y", 0)) == world.year and String(pred.get("l", "")) == lid:
		return pred
	var league: League = world.season.leagues.get(lid, null)
	var js := People.journalists(world)
	if league == null or js.is_empty():
		return {}
	var r := People.rng(world, 41)
	var user := world.user_club()
	var teams := league.club_ids.size()
	var exp := SeasonManager.expected_rank(world, user.id, teams)
	var favs: Array = league.club_ids.duplicate()
	favs.sort_custom(func(a, b):
		var ea := SeasonManager.expected_rank(world, int(a), teams)
		var eb := SeasonManager.expected_rank(world, int(b), teams)
		return ea < eb if ea != eb else int(a) < int(b))
	var list: Array = []
	for j: Dictionary in js:
		var t := _tone(j)
		var pos := clampi(int(round(exp + float(PRED_BIAS.get(t, 0.0)) + RngUtil.gauss(r, 0.0, float(PRED_SD.get(t, 2.0))))), 1, teams)
		var ci := 0
		var roll := r.randf()
		if roll < (0.35 if t == "sensacionalista" else 0.15):
			ci = mini(2, favs.size() - 1)
		elif roll < (0.6 if t == "sensacionalista" else 0.4):
			ci = mini(1, favs.size() - 1)
		var champ: int = int(favs[ci])
		if t == "bairrista" and pos <= 3 and r.randf() < 0.5:
			champ = user.id
			pos = 1
		list.append({"j": int(j["id"]), "pos": pos, "champ": champ})
	pred = {"y": world.year, "l": lid, "list": list, "exp": exp}
	pr["pred"] = pred
	if announce and league.rounds_played() <= 2:
		var cons := consensus(world)
		var champs := {}
		for e: Dictionary in list:
			champs[int(e["champ"])] = int(champs.get(int(e["champ"]), 0)) + 1
		var fav := -1
		for cid in champs:
			if fav < 0 or int(champs[cid]) > int(champs[fav]) or (int(champs[cid]) == int(champs[fav]) and int(cid) < fav):
				fav = int(cid)
		var hi: Dictionary = list[0]
		var lo: Dictionary = list[0]
		for e: Dictionary in list:
			if int(e["pos"]) < int(hi["pos"]):
				hi = e
			if int(e["pos"]) > int(lo["pos"]):
				lo = e
		var jh := People.journalist(world, int(hi["j"]))
		var jl := People.journalist(world, int(lo["j"]))
		NewsManager.post_raw(world, "Palpites: a imprensa vê o %s em %dº" % [user.short_name, cons],
			"%d setoristas cravaram a campanha. O mais otimista é %s (%s), que aposta no %dº lugar; %s (%s) vê o time em %dº. Favorito ao título: %s." % [
				list.size(), String(jh.get("n", "")), String(jh.get("o", "")), int(hi["pos"]), String(jl.get("n", "")), String(jl.get("o", "")), int(lo["pos"]),
				world.club(fav).short_name if world.club(fav) != null else "?"], user.id, -1, NewsEvent.IMP_NORMAL, "imprensa")
	return pred


## Posição que a imprensa espera (mediana dos palpites; sem palpites, o ranking de força).
static func consensus(world: GameWorld) -> int:
	var pred: Dictionary = _st(world).get("pred", {})
	var list: Array = pred.get("list", [])
	if list.is_empty() or int(pred.get("y", 0)) != world.year:
		var l := world.league_of(world.user_club_id)
		return SeasonManager.expected_rank(world, world.user_club_id, l.club_ids.size() if l != null else 20)
	var ps: Array = list.map(func(e): return int(e["pos"]))
	ps.sort()
	return int(ps[ps.size() / 2])


# ---------------------------------------------------------------------------
# Termômetro do cargo
# ---------------------------------------------------------------------------

## 0 (tranquilo) .. 100 (fervendo).
static func heat(world: GameWorld) -> float:
	if not world.has_user():
		return 0.0
	var c := world.user_club()
	var v := (100.0 - c.board_confidence) * 0.45
	var l := world.league_of(c.id)
	if l != null and l.rounds_played() >= 3:
		v += (CompetitionManager.position_of(l, c.id) - consensus(world)) * 3.0
	v += c.streak_losses * 5.0 + c.streak_winless * 1.5 - c.streak_wins * 3.0
	v += (50.0 - People.press_mood(world)) * 0.2 + (50.0 - People.fan_support(world)) * 0.2
	return clampf(v + 10.0, 0.0, 100.0)


static func heat_label(v: float) -> String:
	if v >= HOT:
		return "Fervendo"
	if v >= 50.0:
		return "Esquentando"
	if v >= 30.0:
		return "Morno"
	return "Tranquilo"


## Cotação (odd decimal) de um técnico cair: quanto menor, mais perto da demissão.
static func sack_odds(job: float) -> float:
	return snappedf(clampf(1.3 + job * job / 260.0, 1.3, 51.0), 0.1)


## Bolsa de apostas da liga do usuário: [[nome, clube (id), odd]] do mais ameaçado ao menos (inclui você).
static func sack_race(world: GameWorld, n: int = 4) -> Array:
	if not world.has_user():
		return []
	var l := world.league_of(world.user_club_id)
	if l == null:
		return []
	var arr: Array = []
	for cid in l.club_ids:
		if world.is_user_club(cid):
			arr.append([world.manager_name, cid, sack_odds(100.0 - heat(world))])
			continue
		var co := People.coach_of(world, cid)
		if co.is_empty():
			continue
		arr.append([String(co["n"]), cid, sack_odds(float(co.get("job", 60.0)))])
	arr.sort_custom(func(a, b): return float(a[2]) < float(b[2]) if a[2] != b[2] else int(a[1]) < int(b[1]))
	return arr.slice(0, n)


# ---------------------------------------------------------------------------
# Rumores
# ---------------------------------------------------------------------------

## Placar de acertos do veículo (0..1), com o perfil do jornalista como ponto de partida.
static func accuracy(world: GameWorld, j: Dictionary) -> float:
	var a: Array = _st(world)["acc"].get(str(j.get("id", -1)), [0, 0])
	var prior := float(RELIABILITY.get(_tone(j), 0.5))
	return (int(a[0]) + prior * 4.0) / (int(a[0]) + int(a[1]) + 4.0)


static func _open_rumors(world: GameWorld) -> Array:
	return Array(_st(world)["rum"]).filter(func(x): return String(x["st"]) == "open")


## Tenta publicar um rumor. Com fundamento: comprador que pode pagar e jogador que toparia.
## Sem fundamento: o nome grande no clube grande, dinheiro que ninguém tem.
static func make_rumor(world: GameWorld, r: RandomNumberGenerator) -> Dictionary:
	var js := People.journalists(world)
	if js.is_empty():
		return {}
	var j: Dictionary = RngUtil.pick(r, js)
	var solid := r.randf() < float(RELIABILITY.get(_tone(j), 0.5))
	var user := world.user_club()
	var about_user := r.randf() < 0.35
	var best: Array = []
	for tries in 60:
		var p: Player = world.players.get(r.randi_range(1, maxi(1, world.next_player_id - 1)), null)
		if p == null or p.club_id < 0 or p.retiring:
			continue
		var cur := world.club(p.club_id)
		if about_user != (p.club_id == user.id):
			continue
		if not about_user and cur.nation != user.nation and p.overall < 80:
			continue
		# Comprador: um clube do país do usuário ou uma potência que se interessaria.
		var buyer: Club = world.clubs[r.randi_range(0, world.clubs.size() - 1)]
		if buyer.id == cur.id or world.is_user_club(buyer.id):
			continue
		if not about_user and buyer.nation != user.nation and buyer.reputation < 75.0:
			continue
		var lvl := PlayerGenerator.league_level(buyer)
		var fit := p.overall >= lvl - 3 and p.overall <= lvl + 8
		var money := p.value <= buyer.transfer_budget * 1.4
		var want := TransferManager.interest(world, p, buyer)
		var score := (1.0 if fit else 0.0) + (1.0 if money else 0.0) + want
		if not solid:
			# Sensacionalismo: quanto maior o nome e o clube, melhor a manchete.
			score = p.overall / 20.0 + buyer.reputation / 25.0 + r.randf()
		elif not (fit and money and want >= 0.5):
			continue
		if best.is_empty() or score > float(best[2]):
			best = [p, buyer, score]
	if best.is_empty():
		return {}
	var bp: Player = best[0]
	var bb: Club = best[1]
	var pr := _st(world)
	for x: Dictionary in pr["rum"]:
		if int(x["p"]) == bp.id and String(x["st"]) == "open":
			return {}
	var from := world.club(bp.club_id)
	var ru := {"id": People._next_id(world), "y": world.year, "t": world.current_turn(), "j": int(j["id"]), "p": bp.id, "to": bb.id, "from": from.id,
		"n": bp.display_name(), "tn": bb.short_name, "fn": from.short_name, "st": "open"}
	pr["rum"].append(ru)
	if Array(pr["rum"]).size() > MAX_RUMORS * 2:
		pr["rum"] = Array(pr["rum"]).slice(Array(pr["rum"]).size() - MAX_RUMORS * 2)
	var verb: String = RngUtil.pick(r, ["está de olho em", "monitora", "prepara proposta por", "sonda"])
	var title := "%s %s %s" % [bb.short_name, verb, bp.display_name()]
	var body := "Segundo %s, do %s, o %s %s %s, do %s. Valor de mercado: %s." % [String(j["n"]), String(j["o"]), bb.short_name, verb,
		bp.display_name(), from.short_name, Fmt.money(bp.value)]
	if _tone(j) == "sensacionalista":
		title = "Exclusivo: " + title
		body += " Fontes garantem que o negócio está encaminhado."
	elif _tone(j) == "analitico":
		body += " A informação é tratada como sondagem."
	NewsManager.post_raw(world, title, body, bb.id, bp.id, NewsEvent.IMP_HIGH if about_user else NewsEvent.IMP_NORMAL, "rumor")
	# Jogador do usuário na mira de um clube maior fica balançado (os ambiciosos mais).
	if about_user and bb.reputation > user.reputation:
		var d := -1.0 - maxf(0.0, bp.trait_sum("ambition")) / 20.0
		People.add_trust(world, bp, d)
	return ru


## Transferência concluída: confere os rumores sobre o jogador.
static func on_transfer(world: GameWorld, t: Transfer) -> void:
	if not world.has_user() or not People.data(world).has("press"):
		return
	var pr := _st(world)
	for x: Dictionary in pr["rum"]:
		if int(x["p"]) != t.player_id or String(x["st"]) != "open":
			continue
		var hit := int(x["to"]) == t.to_id
		_settle(world, x, hit)
		if hit:
			var j := People.journalist(world, int(x["j"]))
			NewsManager.post_raw(world, "%s tinha antecipado: %s no %s" % [String(j.get("o", "A imprensa")), String(x["n"]), String(x["tn"])],
				"%s publicou o interesse do %s na rodada %d. O acerto conta pontos para o veículo." % [String(j.get("n", "")), String(x["tn"]), int(x["t"])],
				int(x["to"]), t.player_id, NewsEvent.IMP_LOW, "imprensa")


static func _settle(world: GameWorld, x: Dictionary, hit: bool) -> void:
	x["st"] = "hit" if hit else "miss"
	var acc: Dictionary = _st(world)["acc"]
	var k := str(int(x["j"]))
	var a: Array = acc.get(k, [0, 0])
	acc[k] = [int(a[0]) + (1 if hit else 0), int(a[1]) + (0 if hit else 1)]


## Janela fechou: rumor que não virou negócio vira erro (os feitos na última semana esperam a próxima).
static func on_window_close(world: GameWorld) -> void:
	if not world.has_user() or not People.data(world).has("press"):
		return
	for x: Dictionary in _open_rumors(world):
		if world.current_turn() - int(x["t"]) >= 2 or int(x["y"]) < world.year:
			_settle(world, x, false)


# ---------------------------------------------------------------------------
# Rodada e jogo do usuário
# ---------------------------------------------------------------------------

## Depois de cada data do calendário.
static func after_matchday(world: GameWorld) -> void:
	if not world.has_user() or People.journalists(world).is_empty():
		return
	ensure_predictions(world)
	var pr := _st(world)
	var turn := world.current_turn()
	if int(pr.get("rt", -1)) == turn:
		return # uma leva de notícias por jogo do usuário (datas de copa de outros não contam)
	pr["rt"] = turn
	var r := People.rng(world, 43)
	var open := _open_rumors(world).size()
	if open < MAX_RUMORS and r.randf() < (0.6 if world.transfer_window_open() else 0.25):
		make_rumor(world, r)
	# Termômetro: vira notícia quando ferve (e só de novo depois de esfriar).
	var h := heat(world)
	var was_hot := bool(pr.get("hot", false))
	if h >= HOT and not was_hot:
		var j := journalist_by_tone(world, "sensacionalista", r)
		NewsManager.post_raw(world, "Termômetro: cargo de %s ferve no %s" % [world.manager_name, world.user_club().short_name],
			"A imprensa esperava o time em %dº. %s, do %s, diz que a paciência da diretoria está no fim." % [consensus(world), String(j.get("n", "")), String(j.get("o", ""))],
			world.user_club_id, -1, NewsEvent.IMP_HIGH, "imprensa")
		pr["hot"] = true
	elif h < 50.0 and was_hot:
		pr["hot"] = false
	# Bolsa de apostas a cada 6 jogos.
	var l := world.league_of(world.user_club_id)
	if l != null and l.rounds_played() >= 4 and turn - int(pr.get("odds_t", -99)) >= 6:
		pr["odds_t"] = turn
		var race := sack_race(world, 3)
		if not race.is_empty():
			var parts: Array = race.map(func(x): return "%s (%s) %.1f" % [x[0], world.club(int(x[1])).short_name, float(x[2])])
			NewsManager.post_raw(world, "Bolsa de apostas: %s é o favorito a cair na %s" % [String(race[0][0]), l.name],
				"As casas de apostas cotam quem deixa o cargo primeiro: %s." % ", ".join(parts), int(race[0][1]), -1,
				NewsEvent.IMP_HIGH if world.is_user_club(int(race[0][1])) else NewsEvent.IMP_LOW, "imprensa")


## Depois do jogo do usuário: guarda o contexto para a coletiva, pede coletiva nos jogos
## marcantes e às vezes um jogador fala. Retorna os pedidos novos (mesmo formato de People).
static func after_user_game(world: GameWorld, entry: Dictionary, result: String) -> Array:
	if not world.has_user() or entry.is_empty() or People.journalists(world).is_empty():
		return []
	var pr := _st(world)
	var club := world.user_club()
	var f: Fixture = entry["f"]
	var res: Dictionary = entry.get("res", {})
	var side := 0 if f.home == club.id else 1
	var gd := (f.hg - f.ag) * (1 if side == 0 else -1)
	var hero := -1
	var hero_r := 0.0
	var red := -1
	if res.has("lines"):
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			if float(ln[QuickMatch.L_R]) > hero_r:
				hero_r = float(ln[QuickMatch.L_R])
				hero = p.id
			if bool(ln[QuickMatch.L_RED]) and red < 0:
				red = p.id
	var opp := world.club(f.opponent_of(club.id))
	var last := {"t": world.current_turn(), "res": result, "gd": gd, "score": "%d x %d" % [f.hg, f.ag], "opp": opp.id,
		"derby": MatchEngine.is_derby(world, f.home, f.away), "hero": hero, "hr": snappedf(hero_r, 0.1), "red": red, "asked": false}
	pr["match"] = last
	var r := People.rng(world, 44)
	_player_speaks(world, r, hero, hero_r, result)
	var notable := absi(gd) >= 3 or bool(last["derby"]) or red >= 0 or (result == "D" and club.streak_losses >= 3)
	var added: Array = []
	if notable:
		var reqs: Array = People.data(world).get("reqs", [])
		var has := false
		for q in reqs:
			if String(q["k"]) == "press":
				has = true
		if not has:
			var q := {"k": "press", "t": -1, "until": world.current_turn(), "post": true}
			reqs.append(q)
			People.data(world)["reqs"] = reqs
			added.append(q)
	return added


## Entrevistas: o insatisfeito reclama em público; o herói da partida elogia o treinador.
static func _player_speaks(world: GameWorld, r: RandomNumberGenerator, hero: int, hero_r: float, result: String) -> void:
	var club := world.user_club()
	var js := People.journalists(world)
	var j: Dictionary = RngUtil.pick(r, js)
	var upset: Player = null
	for p: Player in world.squad(club):
		if People.trust_of(world, p) < 25.0 and p.overall >= 58 and (upset == null or p.overall > upset.overall):
			upset = p
	if upset != null and r.randf() < 0.12:
		var line: String = RngUtil.pick(r, ["Quero jogar. Não vim para ficar no banco.", "Ninguém me explicou por que eu saí do time.",
			"Se não tiver espaço, vou pensar no meu futuro."])
		NewsManager.post_raw(world, "%s desabafa: \"%s\"" % [upset.display_name(), line],
			"Em entrevista a %s, do %s, o jogador cobrou mais oportunidades. O vestiário acompanhou a repercussão." % [String(j["n"]), String(j["o"])],
			club.id, upset.id, NewsEvent.IMP_HIGH, "imprensa")
		club.cohesion = maxf(30.0, club.cohesion - 1.0)
		People.add_trust(world, upset, -2.0)
		return
	var hp := world.player(hero)
	if hp != null and result == "V" and hero_r >= 8.3 and r.randf() < 0.3:
		NewsManager.post_raw(world, "%s: \"O professor acreditou em mim\"" % hp.display_name(),
			"Melhor em campo (nota %.1f), o jogador dividiu o mérito com %s ao falar com %s, do %s." % [hero_r, world.manager_name, String(j["n"]), String(j["o"])],
			club.id, hp.id, NewsEvent.IMP_NORMAL, "imprensa")
		People.add_trust(world, hp, 2.0)
		People.add_support(world, 1.0)


# ---------------------------------------------------------------------------
# Coletiva: perguntas com memória
# ---------------------------------------------------------------------------

## Frase que a imprensa guarda para cobrar depois ("title", "blame", "reinforce").
static func add_quote(world: GameWorld, kind: String, text: String, jid: int) -> void:
	var pr := _st(world)
	var l := world.league_of(world.user_club_id)
	pr["quotes"].append({"y": world.year, "t": world.current_turn(), "k": kind, "txt": text, "j": jid,
		"pos": CompetitionManager.position_of(l, world.user_club_id) if l != null else 0, "done": false})
	if Array(pr["quotes"]).size() > 20:
		pr["quotes"] = Array(pr["quotes"]).slice(Array(pr["quotes"]).size() - 20)


## Perguntas que vêm antes das de sempre: o jogo que acabou e frases antigas que voltam.
## pick_j(tom) -> id do jornalista. Cada pergunta: {j, q, o: [{t, fx}]}.
static func questions(world: GameWorld, pick_j: Callable) -> Array:
	var qs: Array = []
	var pr := _st(world)
	var club := world.user_club()
	var last: Dictionary = pr.get("match", {})
	if not last.is_empty() and int(last["t"]) == world.current_turn() and not bool(last.get("asked", false)):
		last["asked"] = true
		var opp := world.club(int(last["opp"]))
		var on := opp.short_name if opp != null else "adversário"
		var gd := int(last["gd"])
		var res := String(last["res"])
		var oc := People.coach_of(world, int(last["opp"]))
		if bool(last["derby"]) and res != "E":
			if res == "V":
				qs.append({"j": pick_j.call("bairrista"), "q": "Vitória no clássico contra o %s. Tem recado para o rival?" % on, "o": [
					{"t": "\"A cidade tem dono.\"", "fx": {"sup": 4.0, "crel:%d" % int(oc.get("id", -1)): -6.0, "head": true, "jrel": 3.0}},
					{"t": "\"Respeito o %s. Hoje fomos melhores.\"" % on, "fx": {"board": 2.0, "crel:%d" % int(oc.get("id", -1)): 3.0}}]})
			else:
				qs.append({"j": pick_j.call("bairrista"), "q": "Perder o clássico dói. O que você diz ao torcedor?", "o": [
					{"t": "\"Peço desculpas. Não estivemos à altura.\"", "fx": {"sup": 2.0, "team": -1.0, "head": true}},
					{"t": "\"Clássico é outro campeonato. Vida que segue.\"", "fx": {"sup": -3.0, "jrel": -1.0}}]})
		elif gd <= -3:
			var o2 := {"team": -4.0, "board": 1.0, "head": true, "quote": "blame"}
			qs.append({"j": pick_j.call("critico"), "q": "%s contra o %s. Alguém vai ser cobrado?" % [String(last["score"]), on], "o": [
				{"t": "\"Eu assumo. A culpa é do treinador.\"", "fx": {"sup": 2.0, "team": 2.0, "board": -1.0}},
				{"t": "\"Tem jogador que precisa se olhar no espelho.\"", "fx": o2},
				{"t": "\"Um dia ruim. Não vou jogar tudo fora.\"", "fx": {"sup": -2.0, "jrel": -2.0}}]})
		elif gd >= 3:
			qs.append({"j": pick_j.call("amigavel"), "q": "%s no %s. Foi a melhor atuação do time com você?" % [String(last["score"]), on], "o": [
				{"t": "\"Foi o jogo mais completo que fizemos.\"", "fx": {"team": 2.0, "mood": 2.0}},
				{"t": "\"Nosso lugar é lá em cima.\"", "fx": {"sup": 3.0, "head": true, "quote": "title", "jrel": 2.0}},
				{"t": "\"Ainda dá para melhorar muito.\"", "fx": {"board": 2.0, "team": 1.0}}]})
		var rp := world.player(int(last.get("red", -1)))
		if rp != null:
			qs.append({"j": pick_j.call("sensacionalista"), "q": "A expulsão de %s mudou o jogo. Ele vai ser multado?" % rp.display_name(), "o": [
				{"t": "\"Vai. Deixou o time na mão.\"", "fx": {"trust:%d" % rp.id: -8.0, "board": 2.0, "head": true}},
				{"t": "\"Isso a gente resolve internamente.\"", "fx": {"trust:%d" % rp.id: 2.0, "jrel": -1.0}},
				{"t": "\"A arbitragem errou feio.\"", "fx": {"trust:%d" % rp.id: 4.0, "sup": 2.0, "board": -1.0, "head": true, "jrel": 2.0}}]})
		var hp := world.player(int(last.get("hero", -1)))
		if hp != null and hp.club_id == club.id and float(last.get("hr", 0.0)) >= 8.0 and qs.size() < 2:
			qs.append({"j": pick_j.call("analitico"), "q": "%s foi o melhor em campo (nota %.1f). É o jogador mais importante do elenco?" % [hp.display_name(), float(last["hr"])], "o": [
				{"t": "\"É o nosso craque.\"", "fx": {"trust:%d" % hp.id: 5.0, "team": -1.0, "head": true}},
				{"t": "\"Ninguém é maior que o grupo.\"", "fx": {"team": 2.0, "trust:%d" % hp.id: -1.0}}]})
	# Frases que voltam para cobrar
	var l := world.league_of(club.id)
	var pos := CompetitionManager.position_of(l, club.id) if l != null else 0
	for q: Dictionary in pr["quotes"]:
		if bool(q.get("done", false)) or int(q["y"]) != world.year or world.current_turn() - int(q["t"]) < 4:
			continue
		match String(q["k"]):
			"title":
				if pos > 4:
					q["done"] = true
					qs.append({"j": pick_j.call("critico"), "q": "Há %d jogos você disse que o time era candidato. Hoje é o %dº. Exagerou?" % [world.current_turn() - int(q["t"]), pos], "o": [
						{"t": "\"Mantenho. Vamos brigar até o fim.\"", "fx": {"sup": 1.0, "board": -1.0, "jrel": -1.0, "head": true}},
						{"t": "\"Fui otimista demais. Assumo.\"", "fx": {"jrel": 3.0, "sup": -2.0, "team": -1.0}},
						{"t": "\"O campeonato é longo.\"", "fx": {"jrel": -2.0}}]})
			"reinforce":
				if not world.transfer_window_open():
					q["done"] = true
					qs.append({"j": pick_j.call("sensacionalista"), "q": "Você pediu reforços com urgência e a janela fechou. A diretoria te deixou na mão?", "o": [
						{"t": "\"Fizemos o possível dentro da realidade do clube.\"", "fx": {"pres": 3.0, "board": 2.0}},
						{"t": "\"Pedi e não veio. Os números estão aí.\"", "fx": {"pres": -6.0, "sup": 2.0, "head": true, "jrel": 3.0}}]})
			"blame":
				if l != null and club.streak_wins >= 2:
					q["done"] = true
					qs.append({"j": pick_j.call("analitico"), "q": "Depois da cobrança pública, o time emendou vitórias. Foi estratégia?", "o": [
						{"t": "\"O grupo reagiu como eu esperava.\"", "fx": {"team": 2.0, "board": 1.0}},
						{"t": "\"Mérito todo deles.\"", "fx": {"team": 3.0, "jrel": 1.0}}]})
		if qs.size() >= 2:
			break
	return qs


## Manchete da coletiva conforme o veículo de quem fez a pergunta principal.
static func spin(world: GameWorld, jid: int, quote: String) -> String:
	var j := People.journalist(world, jid)
	var fmt := String(HEADLINE.get(_tone(j), "%s: %s"))
	return fmt % [world.manager_name, quote]


# ---------------------------------------------------------------------------
# Fim de temporada
# ---------------------------------------------------------------------------

## Quem acertou o palpite; rumores em aberto viram erro.
static func on_season_end(world: GameWorld, summary: Dictionary) -> void:
	if not world.has_user() or not People.data(world).has("press"):
		return
	var pr := _st(world)
	for x: Dictionary in _open_rumors(world):
		_settle(world, x, false)
	var pred: Dictionary = pr.get("pred", {})
	var u: Dictionary = summary.get("user", {})
	if int(pred.get("y", 0)) != world.year or u.is_empty() or String(pred.get("l", "")) != String(u.get("league", "")):
		return
	var pos := int(u["pos"])
	var best: Dictionary = {}
	for e: Dictionary in pred["list"]:
		if best.is_empty() or absi(int(e["pos"]) - pos) < absi(int(best["pos"]) - pos):
			best = e
	var cons := consensus(world)
	var j := People.journalist(world, int(best.get("j", -1)))
	var verdict := "acima do que a imprensa esperava" if pos < cons else ("abaixo do que a imprensa esperava" if pos > cons else "exatamente onde a imprensa previu")
	NewsManager.post_raw(world, "%s termina %s" % [world.user_club().short_name, verdict],
		"A aposta média era o %dº lugar e o time acabou em %dº. Quem chegou mais perto foi %s (%s), que cravou %dº." % [cons, pos,
			String(j.get("n", "")), String(j.get("o", "")), int(best.get("pos", 0))], world.user_club_id, -1, NewsEvent.IMP_NORMAL, "imprensa")
	pr["quotes"] = []
