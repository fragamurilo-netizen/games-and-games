class_name BoardObjectives
extends RefCounted
## Metas da diretoria além da tabela, como nos clubes de verdade: campanha nas copas (do tamanho
## do clube), finanças (folha dentro do orçamento, não fechar no vermelho) e, nos clubes que vivem
## da base, minutos para as crias. Cada meta tem situação ao vivo e pesa no balanço da temporada.
## Estado em world.stats["bobj"] = {"y": ano, "list": [{k, t, w, ...}]}; recriado a cada temporada.
## Também guarda o que mexeu na confiança ao longo do ano (world.stats["bconf"]) para a tela.

const KEY := "bobj"
const CONF_KEY := "bconf"
const STATE_NAMES := {"ok": "Em dia", "risk": "Em risco", "done": "Cumprida", "fail": "Não cumprida", "open": "Em disputa"}


static func list(world: GameWorld) -> Array:
	if not world.has_user():
		return []
	var d: Dictionary = world.stats.get(KEY, {})
	if int(d.get("y", -1)) != world.year:
		d = {"y": world.year, "list": _build(world)}
		world.stats[KEY] = d
		world.stats[CONF_KEY] = {}
	return d["list"]


static func _build(world: GameWorld) -> Array:
	var club := world.user_club()
	var out: Array = []
	var goal := SeasonManager.goal_of(world, club.id)
	out.append({"k": "league", "t": String(goal[0]), "w": 3})
	# Copas: a meta depende de quão forte o clube é entre os participantes
	if world.season != null:
		var mine := ClubAI._compute_strength(world, club)
		for cid in world.season.cups:
			var cup: Cup = world.season.cups[cid]
			if not cup.has_club(club.id) or cup.round_names.is_empty() or CupManager.is_state(String(cid)):
				continue
			var better := 0
			for other in cup.club_ids:
				if int(other) != club.id and ClubAI._compute_strength(world, world.club(int(other))) > mine:
					better += 1
			var pct := float(better) / maxf(1.0, cup.club_ids.size() - 1)
			var n := cup.round_names.size()
			var back := 1 if pct <= 0.06 else (2 if pct <= 0.15 else (3 if pct <= 0.35 else (4 if pct <= 0.6 else 0)))
			var target := n - back if back > 0 else -1 # -1 = passar da primeira fase
			var stage := String(cup.round_names[clampi(target, 0, n - 1)]) if target >= 0 else ""
			var text := ("Chegar à fase: %s na %s" % [stage.to_lower(), cup.short_name]) if target >= 0 else "Passar da primeira fase na %s" % cup.short_name
			if back == 1:
				text = "Chegar à final da %s" % cup.short_name
			out.append({"k": "cup", "cup": String(cid), "r": target, "t": text, "w": 2 if CupManager.continental_ids().has(cid) else 1})
	out.append({"k": "wages", "t": "Folha salarial dentro do orçamento", "w": 1})
	out.append({"k": "balance", "t": "Não fechar o ano no vermelho" if club.balance >= 0 else "Reduzir o rombo no caixa", "b0": club.balance, "w": 1})
	if ClubDNA.val(club, "yth") >= 65.0:
		out.append({"k": "youth", "t": "Dar minutos às crias da casa (%d jogos de titular)" % _youth_target(world), "n": _youth_target(world), "w": 1})
	return out


static func _youth_target(world: GameWorld) -> int:
	var league := world.league_of(world.user_club_id)
	var rounds := league.rounds.size() if league != null else 38
	return int(round(rounds * 1.2))


## Jogos de titular (na temporada) de quem saiu da base do clube e tem até 23 anos.
static func _youth_starts(world: GameWorld) -> int:
	var club := world.user_club()
	var n := 0
	for p: Player in world.squad(club):
		if p.age(world.year) <= 23 and Graduates.origin_of(p.spells, p.birth_year) == club.id:
			n += p.stat(Player.S_STARTS)
	return n


## Situação de uma meta: [estado ("ok"|"risk"|"done"|"fail"|"open"), detalhe].
static func status(world: GameWorld, o: Dictionary) -> Array:
	var club := world.user_club()
	var finished := world.season == null or world.season.finished
	match String(o["k"]):
		"league":
			var league := world.league_of(club.id)
			if league == null:
				return ["open", ""]
			var pos := CompetitionManager.position_of(league, club.id)
			var need := int(SeasonManager.goal_of(world, club.id)[1])
			var played := int(league.table[club.id]["pl"])
			var st := "ok" if pos <= need else "risk"
			if played >= league.rounds.size() and league.rounds.size() > 0:
				st = "done" if pos <= need else "fail"
			return [st, "%dº lugar (meta: até %dº)" % [pos, need]]
		"cup":
			var cup: Cup = world.season.cups.get(String(o["cup"]), null) if world.season != null else null
			if cup == null:
				return ["fail", ""]
			var best := -1
			var latest := -1
			for t in cup.ties:
				latest = maxi(latest, int(t["r"]))
				if int(t["a"]) == club.id or int(t["b"]) == club.id:
					best = maxi(best, int(t["r"]))
			var target := int(o["r"])
			if cup.champion == club.id:
				return ["done", "Campeão"]
			var reached := best >= target if target >= 0 else best >= 0 and best > _first_round(cup)
			if reached:
				return ["done", "Chegou: %s" % String(cup.round_names[best])]
			var out_now := latest > best and latest >= 0 and (best >= 0 or not cup.groups.is_empty() or latest > 0)
			if out_now or cup.champion >= 0:
				return ["fail", "Eliminado" + ((" (%s)" % String(cup.round_names[best]).to_lower()) if best >= 0 else "")]
			return ["open", "Ainda na disputa"]
		"wages":
			var bill := FinanceManager.wage_bill(world, club)
			var ok := bill <= int(club.wage_budget * 1.02)
			return ["done" if finished and ok else ("fail" if finished else ("ok" if ok else "risk")), "%s de %s" % [Fmt.money_month(bill), Fmt.money_month(club.wage_budget)]]
		"balance":
			var b0 := int(o.get("b0", 0))
			var good := club.balance >= 0 if b0 >= 0 else club.balance > b0
			return ["done" if finished and good else ("fail" if finished else ("ok" if good else "risk")), "Caixa: %s" % Fmt.money(club.balance)]
		"youth":
			var n := _youth_starts(world)
			var need2 := int(o.get("n", 30))
			var progress := float(world.season.day) / maxf(1.0, world.season.calendar.size()) if world.season != null else 1.0
			if n >= need2:
				return ["done", "%d de %d jogos" % [n, need2]]
			if finished:
				return ["fail", "%d de %d jogos" % [n, need2]]
			return ["ok" if n >= need2 * progress * 0.85 else "risk", "%d de %d jogos" % [n, need2]]
	return ["open", ""]


static func _first_round(cup: Cup) -> int:
	var lo := 99
	for t in cup.ties:
		lo = mini(lo, int(t["r"]))
	return lo if lo < 99 else 0


## Balanço das metas além da liga (a liga já tem peso próprio em BoardManager.season_review).
static func season_delta(world: GameWorld) -> float:
	var d := 0.0
	for o: Dictionary in list(world):
		if String(o["k"]) == "league":
			continue
		var st := String(status(world, o)[0])
		var w := float(o.get("w", 1))
		if st == "done" or st == "ok":
			d += 2.5 * w
		elif st == "fail" or st == "risk":
			d -= 3.0 * w
	return clampf(d, -18.0, 14.0)


## Registra o que mexeu na confiança (para mostrar "o que pesa na avaliação").
static func track(world: GameWorld, part: String, v: float) -> void:
	var t: Dictionary = world.stats.get(CONF_KEY, {})
	t[part] = float(t.get(part, 0.0)) + v
	world.stats[CONF_KEY] = t


static func breakdown(world: GameWorld) -> Dictionary:
	return world.stats.get(CONF_KEY, {})
