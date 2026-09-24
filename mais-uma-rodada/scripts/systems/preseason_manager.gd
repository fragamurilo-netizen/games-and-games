class_name PreseasonManager
extends RefCounted
## Pré-temporada do clube do usuário: vale do início da carreira (ou da virada de ano) até o
## primeiro jogo oficial. O treinador revisa o elenco setor a setor (comparado com a liga),
## escolhe o tipo de intertemporada (efeitos reais em físico, entrosamento, finanças e base)
## e disputa três amistosos. Estado em world.stats["pre"] (vai junto no save).

const CAMPS := {
	"fisica": {"name": "Intertemporada física", "icon": "heart",
		"desc": "Semanas de academia e campo pesado.",
		"pros": "Físico em dia (velocidade, força, resistência) e elenco 100% descansado.", "cons": "Moral do grupo cai um pouco com a carga."},
	"tatica": {"name": "Treinos táticos fechados", "icon": "tactics",
		"desc": "Campo fechado, vídeo e repetição de movimentos.",
		"pros": "Entrosamento +15 e evolução de posicionamento e leitura de jogo.", "cons": "Sem receita extra e pouca evolução física."},
	"excursao": {"name": "Excursão internacional", "icon": "money",
		"desc": "Amistosos contra times estrangeiros de nome.",
		"pros": "Receita extra, torcida maior e moral em alta.", "cons": "Viagens cansam: o elenco começa a temporada menos descansado."},
	"base": {"name": "Integrar a garotada", "icon": "up",
		"desc": "Os jovens treinam e viajam com o time principal.",
		"pros": "Jogadores de até 21 anos evoluem mais e ganham confiança.", "cons": "Os titulares evoluem menos e o entrosamento sobe pouco."},
}
const CAMP_ORDER: Array[String] = ["fisica", "tatica", "excursao", "base"]

## Vagas de titular e elenco ideal por setor (GOL, DEF, MEI, ATA).
const STARTERS: Array[int] = [1, 4, 4, 2]
const IDEAL: Array[int] = [3, 8, 8, 5]


## Abre a pré-temporada do ano corrente (chamado ao criar a carreira e na virada de temporada).
static func open(world: GameWorld) -> void:
	if not world.has_user() or world.season == null:
		return
	world.stats["pre"] = {"y": world.year, "camp": "", "done": false, "seen_plan": false,
		"opponents": _pick_opponents(world, ""), "friendlies": []}


static func state(world: GameWorld) -> Dictionary:
	if world == null:
		return {}
	var pre: Dictionary = world.stats.get("pre", {})
	if pre.is_empty() or int(pre.get("y", -1)) != world.year:
		return {}
	return pre


## A pré-temporada vale até o primeiro jogo oficial do usuário (ou até ele encerrá-la).
static func is_active(world: GameWorld) -> bool:
	if world == null or not world.has_user() or world.season == null or world.season.finished:
		return false
	var pre := state(world)
	return not pre.is_empty() and not bool(pre.get("done", false)) and world.season.turn == 0


static func finish(world: GameWorld) -> void:
	var pre := state(world)
	if not pre.is_empty():
		pre["done"] = true


static func mark_plan_seen(world: GameWorld) -> void:
	var pre := state(world)
	if not pre.is_empty():
		pre["seen_plan"] = true


## Passos concluídos (para o cartão do hub): [planejamento, intertemporada, amistosos].
static func steps(world: GameWorld) -> Array:
	var pre := state(world)
	return [bool(pre.get("seen_plan", false)), String(pre.get("camp", "")) != "", not (pre.get("friendlies", []) as Array).is_empty()]


# ---------------------------------------------------------------------------
# Intertemporada
# ---------------------------------------------------------------------------

## Aplica a intertemporada escolhida (uma vez por ano). Retorna frases com o que mudou.
static func choose_camp(world: GameWorld, camp: String) -> Array:
	var pre := state(world)
	if pre.is_empty() or String(pre.get("camp", "")) != "" or not CAMPS.has(camp):
		return []
	pre["camp"] = camp
	var club := world.user_club()
	var squad := world.squad(club)
	var notes: Array = []
	match camp:
		"fisica":
			for p: Player in squad:
				p.condition = 100.0
				p.morale = clampf(p.morale - 3.0, 0.0, 100.0)
				PlayerDevelopment.apply_growth(world, p, 0.45 if p.age(world.year) <= 29 else 0.2, [[Attr.VEL, 3.0], [Attr.FOR, 3.0], [Attr.RES, 3.0]])
			club.cohesion = minf(100.0, club.cohesion + 4.0)
			notes.append("Elenco 100% fisicamente e mais forte na parte física.")
			notes.append("Moral do grupo -3 pela carga de treinos.")
		"tatica":
			club.cohesion = minf(100.0, club.cohesion + 15.0)
			for p: Player in squad:
				PlayerDevelopment.apply_growth(world, p, 0.3, [[Attr.POS, 3.0], [Attr.INT, 3.0], [Attr.DEC, 3.0]])
			notes.append("Entrosamento +15: o time já começa sabendo o que fazer.")
		"excursao":
			var fee := int(FinanceManager.expected_revenue(club) * 0.05)
			club.add_ledger("amistosos", fee)
			club.fan_base = int(club.fan_base * 1.04)
			club.fan_mood = clampf(club.fan_mood + 5.0, 0.0, 100.0)
			club.cohesion = minf(100.0, club.cohesion + 5.0)
			for p: Player in squad:
				p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
				p.condition = minf(p.condition, 88.0)
			pre["opponents"] = _pick_opponents(world, "excursao")
			notes.append("Receita da excursão: %s." % Fmt.money(fee))
			notes.append("Torcida +4% e moral do grupo em alta; o elenco chega cansado da viagem.")
		"base":
			var n := 0
			for p: Player in squad:
				if p.age(world.year) <= 21:
					PlayerDevelopment.apply_growth(world, p, 1.1, [])
					p.morale = clampf(p.morale + 6.0, 0.0, 100.0)
					n += 1
				else:
					PlayerDevelopment.apply_growth(world, p, 0.1, [])
			club.cohesion = minf(100.0, club.cohesion + 3.0)
			notes.append("%s evoluíram treinando com o time principal." % Fmt.plural(n, "jovem", "jovens"))
	for p: Player in squad:
		Valuation.update_value(p, world.year)
	pre["notes"] = notes
	return notes


# ---------------------------------------------------------------------------
# Amistosos
# ---------------------------------------------------------------------------

## Três adversários: um mais fraco, um do mesmo nível e um mais forte (estrangeiros na excursão).
static func _pick_opponents(world: GameWorld, camp: String) -> Array:
	var user := world.user_club()
	var rep := user.reputation
	var pool: Array = []
	for c: Club in world.clubs:
		if c.id == user.id or c.league_id == user.league_id:
			continue
		if camp == "excursao" and c.nation == user.nation:
			continue
		if camp != "excursao" and c.nation != user.nation and pool.size() > 0 and world.rng.randf() < 0.7:
			continue
		pool.append(c)
	var out: Array = []
	for target in [rep - 14.0, rep + 1.0, rep + 12.0]:
		var best: Club = null
		var best_d := 1e9
		for c: Club in pool:
			if out.has(c.id):
				continue
			var d := absf(c.reputation - target) + world.rng.randf() * 4.0
			if d < best_d:
				best_d = d
				best = c
		if best != null:
			out.append(best.id)
	return out


## Joga os amistosos (motor rápido, sem valer para estatísticas). Retorna os resultados.
static func play_friendlies(world: GameWorld) -> Array:
	var pre := state(world)
	if pre.is_empty() or not (pre.get("friendlies", []) as Array).is_empty():
		return []
	var user := world.user_club()
	var mine := ClubAI.auto_sheet(world, user, user.sheet.formation if user.sheet != null else "")
	var results: Array = []
	var won := 0
	var gate := 0
	for i in (pre.get("opponents", []) as Array).size():
		var opp := world.club(int(pre["opponents"][i]))
		if opp == null:
			continue
		var home := i != 1 # o do meio é fora de casa
		var theirs := ClubAI.auto_sheet(world, opp, "")
		var hc := user if home else opp
		var ac := opp if home else user
		var ctx := {"attendance": int(hc.capacity * 0.45), "importance": 0.1}
		var res := QuickMatch.play(world, hc, ac, mine if home else theirs, theirs if home else mine, ctx, world.rng.randi())
		var gf := int(res["hg"]) if home else int(res["ag"])
		var ga := int(res["ag"]) if home else int(res["hg"])
		var scorers: Array = []
		for g in res["goals"]:
			var side := int(g[1])
			if (side == 0) == home:
				var p: Player = world.player(int(g[2]))
				if p != null and p.club_id == user.id and not scorers.has(p.display_name()):
					scorers.append(p.display_name())
		var r := "V" if gf > ga else ("E" if gf == ga else "D")
		if r == "V":
			won += 1
		if home:
			gate += int(res["att"]) * FinanceManager.ticket_price(user) / 2
		results.append({"opp": opp.id, "home": home, "gf": gf, "ga": ga, "r": r, "scorers": scorers})
	pre["friendlies"] = results
	# Efeitos: ritmo de jogo (entrosamento), confiança e uma bilheteria modesta.
	user.cohesion = minf(100.0, user.cohesion + 2.0 * results.size())
	var mood := 2.0 * won - (results.size() - won) * 0.7
	for p: Player in world.squad(user):
		p.morale = clampf(p.morale + mood, 0.0, 100.0)
	if gate > 0:
		user.add_ledger("amistosos", gate)
	pre["gate"] = gate
	return results


# ---------------------------------------------------------------------------
# Planejamento de elenco
# ---------------------------------------------------------------------------

## Média dos titulares de um setor (os N melhores do elenco naquele setor).
static func _group_quality(players: Array, group: int) -> float:
	var ovrs: Array = []
	for p: Player in players:
		if Pos.GROUP[p.position] == group:
			ovrs.append(p.ovr_f)
	ovrs.sort()
	ovrs.reverse()
	var n := mini(STARTERS[group], ovrs.size())
	if n == 0:
		return 0.0
	var s := 0.0
	for i in n:
		s += float(ovrs[i])
	# Setor incompleto: as vagas que faltam contam como buracos.
	return s / float(STARTERS[group]) if ovrs.size() >= STARTERS[group] else s / float(STARTERS[group]) * 0.9


## Análise por setor: quantidade, qualidade dos titulares contra a média da liga, idade e veredito.
static func squad_plan(world: GameWorld) -> Array:
	var user := world.user_club()
	var league := world.league_of(user.id)
	var avg: Array = [0.0, 0.0, 0.0, 0.0]
	var n := 0
	for cid in league.club_ids:
		if int(cid) == user.id:
			continue
		var sq := world.squad(world.club(int(cid)))
		for g in 4:
			avg[g] += _group_quality(sq, g)
		n += 1
	var mine := world.squad(user)
	var out: Array = []
	for g in 4:
		var count := 0
		var age_sum := 0
		var old := 0
		for p: Player in mine:
			if Pos.GROUP[p.position] == g:
				count += 1
				age_sum += p.age(world.year)
				if p.age(world.year) >= 32:
					old += 1
		var q := _group_quality(mine, g)
		var la: float = avg[g] / maxf(1.0, n)
		var diff := q - la
		var verdict := "No nível da liga"
		var tone := 0
		if diff >= 3.0:
			verdict = "Ponto forte"
			tone = 1
		elif diff <= -3.0:
			verdict = "Precisa de reforço"
			tone = -1
		var depth := ""
		if count < IDEAL[g] - 1:
			depth = "Poucas opções (%d de %d ideais)" % [count, IDEAL[g]]
		elif count > IDEAL[g] + 3:
			depth = "Excesso de jogadores (%d)" % count
		out.append({"group": g, "count": count, "ideal": IDEAL[g], "quality": q, "league": la, "diff": diff,
			"verdict": verdict, "tone": tone, "depth": depth, "age": float(age_sum) / maxf(1.0, count), "old": old})
	return out


## Pendências e sugestões para o elenco: contratos no fim, veteranos em queda, sobras e promessas.
static func squad_notes(world: GameWorld) -> Dictionary:
	var user := world.user_club()
	var squad := world.squad(user)
	var expiring: Array = []
	var veterans: Array = []
	var surplus: Array = []
	var prospects: Array = []
	var plan := squad_plan(world)
	for p: Player in squad:
		var age := p.age(world.year)
		if p.contract_end <= world.year:
			expiring.append(p)
		var g := Pos.GROUP[p.position]
		if age >= 32 and p.ovr_f < float(plan[g]["quality"]) - 3.0:
			veterans.append(p)
		elif p.squad_status == Player.STATUS_BACKUP and int(plan[g]["count"]) > int(plan[g]["ideal"]) and age >= 24:
			surplus.append(p)
		if age <= 21 and p.potential_estimate(0.8) >= p.overall + 8:
			prospects.append(p)
	var by_ovr := func(a: Player, b: Player): return a.ovr_f > b.ovr_f
	expiring.sort_custom(by_ovr)
	veterans.sort_custom(by_ovr)
	surplus.sort_custom(func(a: Player, b: Player): return a.ovr_f < b.ovr_f)
	prospects.sort_custom(func(a: Player, b: Player): return a.potential_estimate(0.8) > b.potential_estimate(0.8))
	return {"expiring": expiring, "veterans": veterans, "surplus": surplus.slice(0, 5), "prospects": prospects.slice(0, 5)}
