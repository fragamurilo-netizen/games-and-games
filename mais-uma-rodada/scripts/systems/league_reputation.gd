class_name LeagueReputation
extends RefCounted
## A força das ligas muda com o tempo, como o coeficiente da UEFA e da CONMEBOL: o que os clubes
## do país fazem nas copas continentais (acima ou abaixo do que a reputação deles prometia), a
## força dos grandes da liga e o dinheiro (receita, câmbio) mexem no coeficiente do país. Ele
## alimenta a reputação da liga (Reputation.league_rep), o ranking de clubes, o sorteio das copas e
## a renegociação da TV. Muda devagar: uma temporada boa sobe um pouco, uma década boa muda a liga.
##
## Estado: world.stats["lr"] = {"c": {país: coeficiente}, "c0": {país: de partida},
##   "perf": {país: desempenho continental acumulado}, "top0": {país: reputação média do top 6 no começo},
##   "rev0": {país: receita média da 1ª divisão no começo}, "hist": {país: [[ano, coef], ...]}}

const PERF_DECAY := 0.8 # desempenho continental: média móvel (≈ cinco temporadas)
const STAGE_POINTS := {"Campeão": 10.0, "Final": 7.0, "Semifinal": 5.0, "Semifinais": 5.0, "Quartas de final": 3.5, "Quartas": 3.5}
const MAX_SHIFT := 22.0 # o coeficiente anda no máximo isso para cima ou para baixo do de partida
const SPEED := 0.25 # fração do caminho até o alvo por temporada

## país → coeficiente atual (vazio = valores dos dados)
static var _coef: Dictionary = {}


static func coef(nation: String) -> float:
	if _coef.has(nation):
		return float(_coef[nation])
	return float(DatabaseManager.nation(nation).get("coef", 40))


static func data(world: GameWorld) -> Dictionary:
	if not world.stats.has("lr"):
		world.stats["lr"] = {"c": {}, "c0": {}, "perf": {}, "top0": {}, "rev0": {}, "hist": {}}
	return world.stats["lr"]


## Liga os coeficientes salvos (criação e carregamento). Primeira vez: guarda o ponto de partida.
static func ensure(world: GameWorld) -> void:
	var d := data(world)
	if (d["c0"] as Dictionary).is_empty():
		for lid in DatabaseManager.league_ids():
			var cfg := DatabaseManager.league_cfg(lid)
			if int(cfg.get("tier", 1)) != 1:
				continue
			var nat := String(cfg.get("nation", ""))
			var c0 := float(DatabaseManager.nation(nat).get("coef", 40))
			d["c0"][nat] = c0
			d["c"][nat] = c0
			d["top0"][nat] = _top_rep(world, lid)
			d["rev0"][nat] = _mean_revenue(world, lid)
	_apply(d)


static func _apply(d: Dictionary) -> void:
	_coef = (d["c"] as Dictionary).duplicate()
	Reputation.clear_cache()


static func _top_rep(world: GameWorld, lid: String) -> float:
	var reps: Array = []
	for c: Club in world.clubs_in_league(lid):
		reps.append(c.reputation)
	reps.sort()
	reps.reverse()
	var n := mini(6, reps.size())
	var s := 0.0
	for i in n:
		s += float(reps[i])
	return s / maxf(1.0, n)


static func _mean_revenue(world: GameWorld, lid: String) -> float:
	var cl: Array = world.clubs_in_league(lid)
	var s := 0.0
	for c: Club in cl:
		s += float(FinanceManager.expected_revenue(c))
	return s / maxf(1.0, cl.size())


## Fim de temporada (com as copas ainda montadas): atualiza os coeficientes. Retorna as ligas que
## mais mexeram [{nation, old, new}].
static func season_close(world: GameWorld) -> Array:
	var d := data(world)
	if world.season == null:
		return []
	# 1) Desempenho continental acima/abaixo do esperado, por país.
	var over := {}
	var count := {}
	for cid in CupManager.continental_ids():
		var cup: Cup = world.season.cups.get(cid)
		if cup == null or cup.club_ids.size() < 4:
			continue
		var ids: Array = cup.club_ids.duplicate()
		var pts: Array = []
		for id in ids:
			pts.append(_points(cup, int(id)))
		# Esperado: os mesmos pontos distribuídos pela ordem de reputação.
		var by_rep: Array = ids.duplicate()
		by_rep.sort_custom(func(a, b): return world.club(int(a)).reputation > world.club(int(b)).reputation)
		var sorted_pts: Array = pts.duplicate()
		sorted_pts.sort()
		sorted_pts.reverse()
		var expected := {}
		for i in by_rep.size():
			expected[int(by_rep[i])] = float(sorted_pts[i])
		for i in ids.size():
			var c := world.club(int(ids[i]))
			if c == null:
				continue
			over[c.nation] = float(over.get(c.nation, 0.0)) + float(pts[i]) - float(expected[int(ids[i])])
			count[c.nation] = int(count.get(c.nation, 0)) + 1
	var moves: Array = []
	for lid in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(lid)
		if int(cfg.get("tier", 1)) != 1:
			continue
		var nat := String(cfg.get("nation", ""))
		if not d["c0"].has(nat):
			continue
		var c0 := float(d["c0"][nat])
		var perf := float(d["perf"].get(nat, 0.0)) * PERF_DECAY
		if count.has(nat):
			perf += float(over[nat]) / float(count[nat])
		d["perf"][nat] = snappedf(perf, 0.01)
		# 2) Força dos grandes da liga e 3) dinheiro (receita média, já com o câmbio).
		var top := _top_rep(world, lid) - float(d["top0"].get(nat, 0.0))
		var rev0 := maxf(1.0, float(d["rev0"].get(nat, 1.0)))
		var money := log(maxf(0.05, _mean_revenue(world, lid) / rev0))
		# 4) A formação do país (gerações e investimento na base) também dá vitrine à liga.
		var target := clampf(c0 + perf * 1.6 + top * 0.6 + money * 8.0 + Generations.league_push(world, nat), c0 - MAX_SHIFT, c0 + MAX_SHIFT)
		var old := float(d["c"].get(nat, c0))
		var nw := snappedf(clampf(old + (target - old) * SPEED, 5.0, 100.0), 0.1)
		d["c"][nat] = nw
		var h: Array = d["hist"].get(nat, [])
		h.append([world.year, nw])
		if h.size() > 30:
			h.pop_front()
		d["hist"][nat] = h
		if absf(nw - old) >= 1.5:
			moves.append({"nation": nat, "league": lid, "old": old, "new": nw})
	_apply(d)
	for m: Dictionary in moves:
		_news(world, m)
	return moves


static func _points(cup: Cup, club_id: int) -> float:
	var st := SeasonManager._stage_reached(cup, club_id)
	if STAGE_POINTS.has(st):
		return float(STAGE_POINTS[st])
	if st.begins_with("Oitavas"):
		return 2.5
	if st.begins_with("Fase") or st.begins_with("Primeira"):
		return 1.0
	return 1.8 # rodadas intermediárias de mata-mata (playoffs, 16 avos)


static func _news(world: GameWorld, m: Dictionary) -> void:
	var up := float(m["new"]) > float(m["old"])
	var lname := world.league_name(String(m["league"]))
	var mine := world.has_user() and world.user_club().nation == String(m["nation"])
	if not mine and absf(float(m["new"]) - float(m["old"])) < 3.0:
		return
	NewsManager.post_raw(world, ("%s sobe no ranking de ligas" if up else "%s perde força no ranking de ligas") % lname,
		("Campanhas nas copas continentais, os grandes mais fortes e o dinheiro novo puxaram o coeficiente do país de %d para %d. A liga atrai mais jogadores e vale mais na TV." if up else
		"Campanhas fracas fora do país e clubes perdendo força derrubaram o coeficiente de %d para %d. Fica mais difícil segurar talentos e vender a liga na TV.") % [int(round(float(m["old"]))), int(round(float(m["new"])))],
		world.user_club_id if mine else -1, -1, NewsEvent.IMP_HIGH if mine else NewsEvent.IMP_NORMAL, "mundo")


## Quanto a liga está acima (> 1) ou abaixo do ponto de partida (renegociação da TV, atração).
static func trend_factor(nation: String, world: GameWorld) -> float:
	var d := data(world)
	var c0 := float(d["c0"].get(nation, coef(nation)))
	return clampf(1.0 + (coef(nation) - c0) / 60.0, 0.7, 1.35)
