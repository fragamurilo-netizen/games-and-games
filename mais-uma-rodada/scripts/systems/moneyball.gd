class_name Moneyball
extends RefCounted
## Análise de elenco e busca por números ("moneyball"): o que falta no seu time comparado à liga,
## e quem no mundo entrega mais por euro (gols, assistências, passes decisivos, desarmes, dribles,
## defesas por 90 minutos), não só pelo overall.

## Vagas do time titular: [rótulo, posições que servem, quantos titulares].
const SLOTS := [
	["Goleiro", [Pos.GK], 1],
	["Zagueiro", [Pos.CB], 2],
	["Lateral direito", [Pos.RB], 1],
	["Lateral esquerdo", [Pos.LB], 1],
	["Volante", [Pos.DM, Pos.CM], 1],
	["Meio-campista", [Pos.CM, Pos.AM], 2],
	["Ponta", [Pos.RW, Pos.LW, Pos.RM, Pos.LM], 2],
	["Centroavante", [Pos.ST], 1],
]

## Perfis de busca: [chave, nome, descrição].
const PROFILES := [
	["geral", "Custo-benefício", "Melhor nota média pelo menor preço."],
	["gols", "Finalizador", "Gols e xG por 90 minutos."],
	["assist", "Garçom", "Assistências por 90 minutos."],
	["criacao", "Criador", "Passes decisivos por 90 minutos."],
	["desarme", "Ladrão de bola", "Desarmes e interceptações por 90 minutos."],
	["drible", "Driblador", "Dribles certos por 90 minutos."],
	["defesas", "Goleiro de defesas", "Defesas por 90 minutos e jogos sem sofrer gol."],
	["jovem", "Jovem promessa", "Até 21 anos, potencial estimado alto e barato."],
]

const MIN_MINUTES := 360


static func _fits(p: Player, positions: Array) -> int:
	if p.position in positions:
		return 0
	for s in p.secondary:
		if int(s) in positions:
			return 3
	return -1


## Nível do n-ésimo melhor jogador do clube na vaga (overall, com desconto para posição secundária).
static func slot_levels(world: GameWorld, club: Club, positions: Array) -> Array:
	var lv: Array = []
	for p: Player in world.squad(club):
		if p.injury_weeks > 8:
			continue
		var pen := _fits(p, positions)
		if pen >= 0:
			lv.append(p.overall - pen)
	lv.sort()
	lv.reverse()
	return lv


## Carências do elenco: [{slot, label, mine, league, depth, age, gap, reasons, priority}], da maior para a menor.
static func needs(world: GameWorld, club: Club) -> Array:
	var out: Array = []
	var league := world.league_of(club.id)
	for sl: Array in SLOTS:
		var positions: Array = sl[1]
		var n: int = sl[2]
		var mine := slot_levels(world, club, positions)
		var level := float(mine[n - 1]) if mine.size() >= n else 40.0
		var sum := 0.0
		var cnt := 0
		if league != null:
			for id in league.club_ids:
				if int(id) == club.id:
					continue
				var lv := slot_levels(world, world.club(int(id)), positions)
				if lv.size() >= n:
					sum += float(lv[n - 1])
					cnt += 1
		var avg := sum / cnt if cnt > 0 else level
		# Idade do titular mais velho da vaga
		var old := 0
		var best: Array = world.squad(club).filter(func(p: Player) -> bool: return _fits(p, positions) >= 0)
		best.sort_custom(func(a: Player, b: Player): return a.overall > b.overall)
		for i in mini(n, best.size()):
			old = maxi(old, (best[i] as Player).age(world.year))
		var reasons: Array = []
		var prio := 0.0
		var gap := avg - level
		if gap > 1.0:
			reasons.append("titular %d, média da liga %d" % [int(level), int(round(avg))])
			prio += gap
		if mine.size() < n + 1:
			reasons.append("só %d jogador(es) para a vaga" % mine.size())
			prio += 4.0 * (n + 1 - mine.size())
		elif mine.size() > n and float(mine[n]) < level - 8.0:
			reasons.append("reserva muito abaixo do titular (%d)" % int(mine[n]))
			prio += 2.0
		if old >= 32:
			reasons.append("titular com %d anos" % old)
			prio += 2.0 + (old - 32)
		out.append({"label": sl[0], "positions": positions, "mine": level, "league": avg, "depth": mine.size(),
			"gap": gap, "reasons": reasons, "priority": prio})
	out.sort_custom(func(a, b): return float(a["priority"]) > float(b["priority"]))
	return out


## Número principal do perfil para um jogador e o texto que o explica. Sem minutos suficientes
## na temporada, usa a temporada anterior (jogos, gols, assistências, nota).
static func metric(world: GameWorld, p: Player, profile: String) -> Array:
	var mins := float(p.stats[Player.S_MINUTES])
	var per := 90.0 / maxf(1.0, mins)
	var enough := mins >= MIN_MINUTES
	var last: Dictionary = {}
	if not enough:
		var h: Array = p.history
		for i in range(h.size() - 1, -1, -1):
			if int((h[i] as Dictionary).get("a", 0)) >= 5:
				last = h[i]
				break
	match profile:
		"gols":
			if enough:
				var v := p.stats[Player.S_GOALS] * per + 0.3 * p.stats[Player.S_XG] / 100.0 * per
				return [v, "%.2f gols/90 · %d gols" % [p.stats[Player.S_GOALS] * per, p.stats[Player.S_GOALS]]]
			if not last.is_empty():
				var g := float(last.get("g", 0)) / maxf(1.0, float(last.get("a", 1)))
				return [g, "%d gols em %d jogos (%d)" % [int(last.get("g", 0)), int(last.get("a", 0)), int(last.get("y", 0))]]
		"assist":
			if enough:
				return [p.stats[Player.S_ASSISTS] * per + 0.1 * p.stats[Player.S_KEY_PASSES] * per, "%.2f assist./90 · %d assist." % [p.stats[Player.S_ASSISTS] * per, p.stats[Player.S_ASSISTS]]]
			if not last.is_empty():
				var a := float(last.get("as", 0)) / maxf(1.0, float(last.get("a", 1)))
				return [a, "%d assist. em %d jogos (%d)" % [int(last.get("as", 0)), int(last.get("a", 0)), int(last.get("y", 0))]]
		"criacao":
			if enough:
				return [p.stats[Player.S_KEY_PASSES] * per + 2.0 * p.stats[Player.S_ASSISTS] * per, "%.1f passes decisivos/90" % (p.stats[Player.S_KEY_PASSES] * per)]
		"desarme":
			if enough:
				var d := (p.stats[Player.S_TACKLES] + p.stats[Player.S_INTERCEPTIONS]) * per
				return [d, "%.1f desarmes+intercept./90" % d]
		"drible":
			if enough:
				return [p.stats[Player.S_DRIBBLES] * per, "%.1f dribles/90" % (p.stats[Player.S_DRIBBLES] * per)]
		"defesas":
			if enough:
				var apps := maxf(1.0, p.stats[Player.S_APPS])
				var v := p.stats[Player.S_SAVES] * per + 3.0 * p.stats[Player.S_CLEAN] / apps
				return [v, "%.1f defesas/90 · %d sem sofrer gol" % [p.stats[Player.S_SAVES] * per, p.stats[Player.S_CLEAN]]]
		"jovem":
			var pot := PlayerAssessment.stars(world,p,-1,true)
			return [float(pot) + (21 - p.age(world.year)) * 0.5, "projeção " + PlayerAssessment.summary(world,p,true)]
	# geral (e fallback dos perfis que só existem com minutos): nota média
	if enough:
		return [p.avg_rating(), "nota %.2f em %d jogos" % [p.avg_rating(), p.stats[Player.S_APPS]]]
	if not last.is_empty():
		return [float(last.get("r", 6.5)), "nota %.2f em %d jogos (%d)" % [float(last.get("r", 0.0)), int(last.get("a", 0)), int(last.get("y", 0))]]
	return [5.5 + (PlayerAssessment.score(world,p) - 60) * 0.04, "sem jogos recentes"]


## Pré-seleção barata: números da temporada (se houver) e overall, contra o preço.
static func _pre_score(world: GameWorld, p: Player, profile: String, price: int) -> float:
	var mins := float(p.stats[Player.S_MINUTES])
	var per := 90.0 / maxf(1.0, mins)
	var s := PlayerAssessment.score(world,p)
	if mins >= MIN_MINUTES:
		match profile:
			"gols":
				s += 20.0 * p.stats[Player.S_GOALS] * per
			"assist":
				s += 25.0 * p.stats[Player.S_ASSISTS] * per
			"criacao":
				s += 4.0 * p.stats[Player.S_KEY_PASSES] * per
			"desarme":
				s += 2.0 * (p.stats[Player.S_TACKLES] + p.stats[Player.S_INTERCEPTIONS]) * per
			"drible":
				s += 3.0 * p.stats[Player.S_DRIBBLES] * per
			"defesas":
				s += 2.0 * p.stats[Player.S_SAVES] * per
			_:
				s += 6.0 * (p.avg_rating() - 6.5)
	elif profile == "jovem":
		s += maxf(0.0,26-p.age(world.year))*0.5
	return s - 2.5 * log(maxf(1.0, price) / 100000.0 + 1.0)


## Busca no mundo: [{p, perf, text, cb (custo-benefício 0..100)}], melhores primeiro.
## positions vazio = todas; max_fee <= 0 = sem limite de preço.
static func search(world: GameWorld, club: Club, profile: String, positions: Array, max_age: int, max_fee: int, min_ovr: int, limit := 30) -> Array:
	var pool: Array = []
	for p: Player in world.players.values():
		if p.club_id == club.id or p.retiring or world.academy.has(p.id):
			continue
		if not positions.is_empty() and _fits(p, positions) < 0:
			continue
		if profile == "defesas" and p.position != Pos.GK:
			continue
		var age := p.age(world.year)
		if age > max_age or (profile == "jovem" and age > 21):
			continue
		if PlayerAssessment.score(world,p) < min_ovr:
			continue
		var price := maxi(p.value, p.asking_price) if p.club_id >= 0 else 0
		if max_fee > 0 and price > max_fee:
			continue
		# Custo real: taxa + dois anos de salário (livre não sai de graça)
		var wage := p.wage if p.club_id >= 0 and p.wage > 0 else Valuation.wage_demand(p, club, world.year)
		var cost := price + wage * 24
		pool.append({"p": p, "price": price, "wage": wage, "cost": cost, "pre": _pre_score(world,p, profile, cost)})
	if pool.is_empty():
		return []
	# Só os mais promissores passam pela conta completa (a carreira compactada de cada jogador só
	# é aberta para esses poucos).
	pool.sort_custom(func(a, b): return float(a["pre"]) > float(b["pre"]))
	pool = pool.slice(0, 260)
	for e: Dictionary in pool:
		var m := metric(world, e["p"], profile)
		e["perf"] = float(m[0])
		e["text"] = String(m[1])
	# Percentis de desempenho e de preço dentro do grupo buscado
	var by_perf := pool.duplicate()
	by_perf.sort_custom(func(a, b): return float(a["perf"]) < float(b["perf"]))
	var by_price := pool.duplicate()
	by_price.sort_custom(func(a, b): return int(a["cost"]) < int(b["cost"]))
	var n := float(maxi(1, pool.size() - 1))
	for i in by_perf.size():
		by_perf[i]["pp"] = i / n * 100.0
	for i in by_price.size():
		by_price[i]["vp"] = i / n * 100.0
	for e: Dictionary in pool:
		e["cb"] = clampf(float(e["pp"]) * 0.6 + (100.0 - float(e["vp"])) * 0.4, 0.0, 100.0)
	pool.sort_custom(func(a, b): return float(a["cb"]) + float(a["pp"]) * 0.2 > float(b["cb"]) + float(b["pp"]) * 0.2)
	return pool.slice(0, limit)
