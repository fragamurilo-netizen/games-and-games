class_name YouthManager
extends RefCounted
## Categorias de base do clube do usuário e a liga sub-20 da temporada.
##
## A base do usuário tem jogadores de verdade (world.academy: id → Player, fora de world.players):
## eles treinam, jogam a liga sub-20, evoluem e podem subir ao elenco ou ser dispensados.
## Os outros clubes entram na liga sub-20 com uma força derivada do nível da base e três
## destaques com nome (para a artilharia). A cada virada de ano chegam novos garotos.

const MIN_AGE := 15
const MAX_AGE := 19 # quem passa disso precisa subir ou sair
const TARGET_SIZE := 14
const MAX_SIZE := 24


# ---------------------------------------------------------------------------
# Elenco da base
# ---------------------------------------------------------------------------

static func academy(world: GameWorld) -> Array:
	var out: Array = world.academy.values()
	out.sort_custom(func(a: Player, b: Player): return a.overall > b.overall if a.overall != b.overall else a.id < b.id)
	return out


## Garante que o clube do usuário tenha base (nova carreira ou troca de clube).
static func ensure_academy(world: GameWorld) -> void:
	if not world.has_user():
		return
	var club := world.user_club()
	for p: Player in world.academy.values():
		if p.club_id != club.id:
			world.academy.erase(p.id) # base do clube antigo fica por lá
	if world.academy.size() >= 8:
		return
	var used := WorldGenerator.used_names_of(world)
	while world.academy.size() < TARGET_SIZE:
		_new_kid(world, club, world.rng.randi_range(MIN_AGE, 18), used)


static func _new_kid(world: GameWorld, club: Club, age: int, used: Dictionary) -> Player:
	var rng := world.rng
	var pos: int = RngUtil.weighted_index(rng, [1.0, 1.0, 1.6, 1.0, 1.0, 1.4, 1.0, 0.6, 0.6, 0.9, 0.9, 1.6])
	var level := PlayerGenerator.league_level(club)
	var drift := clampf(float(world.stats.get("talent_drift", 0.0)), -8.0, 8.0)
	var nation_bonus := float(DatabaseManager.nation(club.nation).get("youth", 0.0))
	var target := level - 22.0 + club.youth_level * 0.07 + rng.randfn(0.0, 4.5) + (age - 15) * 2.2 - drift + nation_bonus * 0.4
	target = clampf(target, 20.0, 68.0)
	var nat := club.nation if rng.randf() < 0.95 else PlayerGenerator.pick_import(rng, club.nation)
	var p := PlayerGenerator.create(world, rng, pos, target, age, nat, club.city, used)
	ClubPolicy.apply_rule(world, rng, club, p, ClubPolicy.generation_rule(rng, club), used)
	p.potential = PlayerGenerator.youth_potential(rng, p.overall, club.youth_level, drift, nation_bonus)
	p.club_id = club.id
	p.squad_status = Player.STATUS_PROSPECT
	p.wage = 0
	p.contract_end = world.year
	p.joined_year = world.year
	if p.nationality == club.nation and rng.randf() < 0.6 and not ClubPolicy.of(club).has("only"):
		p.hometown = club.city
	Valuation.update_value(p, world.year)
	world.academy[p.id] = p
	return p


## Melhor garoto pronto para subir (evento "joia da base").
static func best_prospect(world: GameWorld, club: Club) -> Player:
	var best: Player = null
	for p: Player in world.academy.values():
		if p.age(world.year) < 17:
			continue
		if best == null or p.potential_estimate(0.6) > best.potential_estimate(0.6):
			best = p
	if best == null:
		return null
	# Só vale o alerta se ele já estiver perto do nível do elenco
	var weakest := 99
	for q: Player in world.squad(club):
		weakest = mini(weakest, q.overall)
	return best if best.overall >= weakest - 8 or best.potential_estimate(0.6) >= 72 else null


## Sobe um garoto para o elenco profissional. Retorna a mensagem para a interface.
static func promote(world: GameWorld, p: Player) -> String:
	var club := world.user_club()
	if not world.academy.has(p.id):
		return "Ele não está mais na base."
	if club.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return "Elenco cheio: libere uma vaga antes de subir %s." % p.display_name()
	world.academy.erase(p.id)
	p.reset_season_stats()
	p.club_id = -1
	PlayerGenerator.sign_to_club(world, world.rng, p, club, false)
	p.squad_status = Player.STATUS_PROSPECT
	p.contract_end = world.year + 3
	p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(club.league_cfg().get("wage", 0.5)))
	p.morale = minf(100.0, p.morale + 12.0)
	Valuation.update_value(p, world.year)
	world.stat_add("youth_promoted")
	NewsManager.post_raw(world, "%s sobe para o profissional" % p.display_name(),
		"Aos %d anos, %s (%s) deixa a base do %s e passa a treinar com o elenco principal." % [p.age(world.year), p.display_name(), Pos.name_of(p.position).to_lower(), club.short_name],
		club.id, p.id, NewsEvent.IMP_HIGH, "base")
	return "%s subiu para o elenco principal!" % p.display_name()


static func release(world: GameWorld, p: Player) -> void:
	world.academy.erase(p.id)


# ---------------------------------------------------------------------------
# Evolução semanal e virada de ano
# ---------------------------------------------------------------------------

## Treino semanal da base: evolui conforme idade, potencial, nível da base e minutos no sub-20.
static func weekly(world: GameWorld) -> void:
	if world.academy.is_empty():
		return
	var club := world.user_club()
	var focus := TrainingManager.youth_mult(world)
	for p: Player in world.academy.values():
		var gap := float(p.potential) - p.ovr_f
		if gap <= 0.0:
			continue
		var age := p.age(world.year)
		var age_f := 1.15 if age <= 17 else 1.0
		var play_f := 1.0 + minf(0.25, p.stats[Player.S_APPS] * 0.02)
		var budget := gap * 0.005 * age_f * (0.75 + club.youth_level / 250.0) * play_f * focus * p.trait_mult("dev_mult") + p.dev_acc
		PlayerDevelopment.apply_growth(world, p, maxf(0.0, budget))
		p.morale = clampf(p.morale + (65.0 - p.morale) * 0.1, 0.0, 100.0)


## Fim de temporada: todos envelhecem um ano; quem passou da idade sai; chegam novos garotos.
## Retorna {"left": [nomes], "new": [Player]}.
static func season_turnover(world: GameWorld) -> Dictionary:
	var out := {"left": [], "new": []}
	if not world.has_user():
		return out
	var club := world.user_club()
	for p: Player in world.academy.values().duplicate():
		p.reset_season_stats()
		if p.age(world.year) > MAX_AGE:
			world.academy.erase(p.id)
			p.club_id = -1
			p.contract_end = world.year
			world.add_player(p) # vira agente livre: outro clube pode apostar nele
			out["left"].append(p.display_name())
	var used := WorldGenerator.used_names_of(world)
	var n := 3 + (1 if club.youth_level >= 55 else 0) + (1 if club.youth_level >= 80 else 0) + (1 if world.rng.randf() < 0.4 else 0)
	for _i in n:
		if world.academy.size() >= MAX_SIZE:
			break
		out["new"].append(_new_kid(world, club, world.rng.randi_range(MIN_AGE, 16), used))
	return out


# ---------------------------------------------------------------------------
# Liga sub-20
# ---------------------------------------------------------------------------

## Monta a liga sub-20 da liga do usuário para a temporada que começa.
static func build_league(world: GameWorld) -> void:
	world.youth_league = {}
	if not world.has_user():
		return
	var club := world.user_club()
	var ids: Array = []
	for c: Club in world.clubs_in_league(club.league_id):
		ids.append(c.id)
	if ids.size() < 4:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, "sub20"])
	var pairs := FixtureManager.round_robin(rng, ids, 1)
	var weekend: Array = []
	for i in world.season.calendar.size():
		if world.season.is_weekend(i):
			weekend.append(i)
	var slots := FixtureManager.spread_rounds(pairs.size(), weekend)
	var rounds: Array = []
	for r in pairs.size():
		var games: Array = []
		for pr in pairs[r]:
			games.append([int(pr[0]), int(pr[1]), -1, -1])
		rounds.append(games)
	var table := {}
	var strength := {}
	var stars := {}
	var used := {}
	for cid in ids:
		table[cid] = CompetitionManager.empty_row()
		var c := world.club(cid)
		# Mesma escala dos garotos de verdade: 11 melhores de uma base média daquele clube
		strength[cid] = PlayerGenerator.league_level(c) - 16.5 + c.youth_level * 0.07 + rng.randfn(0.0, 2.5)
		if cid != club.id:
			var names: Array = []
			for k in 3:
				var origin := NameGenerator.pick_origin(rng, c.nation)
				var nm := NameGenerator.generate(rng, origin["c"], {"pos": Pos.ST, "height": 178, "foot": 0, "attrs": PackedByteArray(), "region": ""}, used)
				names.append(String(nm["known_as"]) if String(nm["known_as"]) != "" else String(nm["last"]))
			stars[cid] = names
	var cfg := DatabaseManager.league_cfg(club.league_id)
	world.youth_league = {
		"league": club.league_id, "year": world.year, "name": "%s Sub-20" % cfg.get("short", club.league_id),
		"clubs": ids, "rounds": rounds, "slots": slots, "table": table, "str": strength, "stars": stars,
		"scorers": {}, "champion": -1,
	}


static func has_league(world: GameWorld) -> bool:
	return not world.youth_league.is_empty()


## Força do time sub-20 do usuário: média dos 11 melhores da base.
static func user_strength(world: GameWorld) -> float:
	var list := academy(world)
	var s := 0.0
	for i in 11:
		s += float(list[i].overall) if i < list.size() else 35.0
	return s / 11.0


## Joga as rodadas do sub-20 marcadas para esta data.
static func play_slot(world: GameWorld, slot: int) -> Array:
	var played: Array = []
	var yl := world.youth_league
	if yl.is_empty():
		return played
	var slots: Array = yl["slots"]
	var rng := world.rng
	for r in slots.size():
		if int(slots[r]) != slot:
			continue
		for g in yl["rounds"][r]:
			if int(g[2]) >= 0:
				continue
			var h := int(g[0])
			var a := int(g[1])
			var sh := _strength(world, h)
			var sa := _strength(world, a)
			var lh := 1.45 * exp((sh - sa) / 11.0) * 1.08
			var la := 1.25 * exp((sa - sh) / 11.0)
			g[2] = _poisson(rng, clampf(lh, 0.2, 5.0))
			g[3] = _poisson(rng, clampf(la, 0.2, 5.0))
			var f := Fixture.new()
			f.home = h
			f.away = a
			f.hg = int(g[2])
			f.ag = int(g[3])
			CompetitionManager.apply_to_table(yl["table"], f)
			_credit_goals(world, h, int(g[2]))
			_credit_goals(world, a, int(g[3]))
			if world.is_user_club(h) or world.is_user_club(a):
				played.append(g)
	return played


static func _strength(world: GameWorld, cid: int) -> float:
	if world.is_user_club(cid):
		return user_strength(world)
	# Os garotos dos outros clubes também evoluem ao longo do ano
	var progress := float(world.season.day) / maxf(1.0, float(world.season.calendar.size()))
	return float(world.youth_league["str"].get(cid, 45.0)) + progress * 2.0


static func _credit_goals(world: GameWorld, cid: int, goals: int) -> void:
	var yl := world.youth_league
	var sc: Dictionary = yl["scorers"]
	var rng := world.rng
	if world.is_user_club(cid):
		var xi: Array = academy(world).slice(0, 11)
		if xi.is_empty():
			return
		var w: Array = []
		for p: Player in xi:
			p.stats[Player.S_APPS] += 1
			p.stats[Player.S_MINUTES] += 90
			w.append(float(p.attrs[Attr.FIN] + p.attrs[Attr.POS]) * (3.0 if Pos.group(p.position) == Pos.G_ATT else (1.2 if Pos.group(p.position) == Pos.G_MID else 0.25)))
		for _i in goals:
			var p: Player = xi[RngUtil.weighted_index(rng, w)]
			p.stats[Player.S_GOALS] += 1
			var key := "p%d" % p.id
			if not sc.has(key):
				sc[key] = {"n": p.display_name(), "c": cid, "g": 0, "pid": p.id}
			sc[key]["g"] = int(sc[key]["g"]) + 1
		return
	var names: Array = yl["stars"].get(cid, [])
	for _i in goals:
		var k := RngUtil.weighted_index(rng, [0.4, 0.25, 0.15, 0.2])
		if k >= names.size():
			continue # gol de outro garoto
		var key := "c%d_%d" % [cid, k]
		if not sc.has(key):
			sc[key] = {"n": names[k], "c": cid, "g": 0}
		sc[key]["g"] = int(sc[key]["g"]) + 1


static func _poisson(rng: RandomNumberGenerator, lambda: float) -> int:
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l or k > 9:
			break
		k += 1
	return k


static func sorted_table(world: GameWorld) -> Array:
	var yl := world.youth_league
	if yl.is_empty():
		return []
	return CompetitionManager.sort_table(yl["clubs"], yl["table"])


static func top_scorers(world: GameWorld, n: int) -> Array:
	var yl := world.youth_league
	if yl.is_empty():
		return []
	var arr: Array = yl["scorers"].values()
	arr.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["g"]) > int(b["g"]))
	return arr.slice(0, n)


## Fecha a liga sub-20: campeão, título e notícia. Retorna o resumo ({} se não houve liga).
static func finish_league(world: GameWorld) -> Dictionary:
	var yl := world.youth_league
	if yl.is_empty():
		return {}
	var order := sorted_table(world)
	if order.is_empty():
		return {}
	var champ := world.club(int(order[0]))
	yl["champion"] = champ.id
	champ.add_title("Y:" + String(yl["league"]))
	var sc := top_scorers(world, 1)
	var out := {"name": yl["name"], "champion": champ.id, "scorer": sc[0] if not sc.is_empty() else {}, "user_pos": order.find(world.user_club_id) + 1}
	if world.is_user_club(champ.id):
		NewsManager.post_raw(world, "Campeões do %s!" % yl["name"], "A garotada do %s conquistou o %s. O futuro do clube está em boas mãos." % [champ.short_name, yl["name"]], champ.id, -1, NewsEvent.IMP_HIGH, "base")
	return out
