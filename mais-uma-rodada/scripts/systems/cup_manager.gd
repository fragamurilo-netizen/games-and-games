class_name CupManager
extends RefCounted
## Copas continentais (Liga dos Campeões, Libertadores, CONCACAF, África, Ásia) e Mundial de Clubes:
## classificação pelas ligas, sorteio de grupos (evitando clubes do mesmo país), mata-mata em ida e
## volta com prorrogação e pênaltis, final única em campo neutro, premiação por fase e títulos.
## Também os estaduais brasileiros (kind = "state" no continental.json): grupos em turno único nas
## datas E1..E7, semifinal em jogo único na casa do melhor campanha e final em ida e volta.

const ROUND_NAMES := {"r16": "Oitavas de final", "qf": "Quartas de final", "sf": "Semifinal", "f": "Final"}
const KO_SLOTS := {"r16": ["C7", "C8"], "qf": ["C9", "C10"], "sf": ["C11", "C12"], "f": ["C13"]}
const CWC_SLOTS := {"qf": ["X1"], "sf": ["X2"], "f": ["X3"]}
const STAGE_IMPORTANCE := {"r16": 0.62, "qf": 0.72, "sf": 0.85, "f": 1.0}
const GROUP_LETTERS := "ABCDEFGH"
const CWC := "CWC"


static func cfg(id: String) -> Dictionary:
	return DatabaseManager.cup_cfg(id)


## Copas continentais com vagas por liga (todas menos o Mundial), na ordem dos dados.
static func continental_ids() -> Array:
	var out: Array = []
	for id in DatabaseManager.cups_cfg():
		if DatabaseManager.cup_cfg(id).has("alloc"):
			out.append(id)
	return out


## Estaduais (e regionais) brasileiros, na ordem dos dados.
static func state_ids() -> Array:
	var out: Array = []
	for id in DatabaseManager.cups_cfg():
		if is_state(id):
			out.append(id)
	return out


static func is_state(id: String) -> bool:
	return String(cfg(id).get("kind", "")) == "state"


static var _uf_cache: Dictionary = {}


## Estado (uf) de um clube brasileiro autoral, pelos dados (a chave do clube é estável).
static func uf_of(c: Club) -> String:
	if _uf_cache.is_empty():
		for d in DatabaseManager.club_data("BRA"):
			_uf_cache[String(d.get("key", ""))] = String(d.get("uf", ""))
	return String(_uf_cache.get(c.key, ""))


## Categoria de notícia de copa: "copa_campeao" ou, nos estaduais, "estadual_campeao".
static func news_cat(id: String, what: String) -> String:
	return ("estadual_" if is_state(id) else "copa_") + what


static func cup_of_nation(nation: String) -> String:
	var confed: String = DatabaseManager.nation(nation).get("confed", "")
	for id in continental_ids():
		if cfg(id).get("confed", "") == confed:
			return id
	return ""


## Vagas continentais de uma liga (só a primeira divisão classifica).
static func continental_spots(league: League) -> int:
	if league == null or league.tier != 1:
		return 0
	var id := cup_of_nation(league.nation)
	if id == "":
		return 0
	return int(cfg(id).get("alloc", {}).get(league.nation, 0))


static func cup_name(id: String) -> String:
	return cfg(id).get("name", id)


static func cup_short(id: String) -> String:
	return cfg(id).get("short", id)


## Fases do mata-mata de uma copa, pelo número de classificados.
static func ko_plan(id: String) -> Array:
	var c := cfg(id)
	if c.has("ko_plan"):
		return Array(c["ko_plan"])
	var groups := int(c.get("groups", 0))
	var n := groups * 2 if groups > 0 else int(c.get("teams", 8))
	if n >= 16:
		return ["r16", "qf", "sf", "f"]
	if n >= 8:
		return ["qf", "sf", "f"]
	if n >= 4:
		return ["sf", "f"]
	return ["f"]


static func _round_key(cup: Cup, r: int) -> String:
	var plan := ko_plan(cup.id)
	return plan[clampi(r, 0, plan.size() - 1)]


static func _round_slots(cup: Cup, r: int) -> Array:
	var key := _round_key(cup, r)
	if cfg(cup.id).has("ko_slots"):
		return Array(cfg(cup.id)["ko_slots"][key])
	return CWC_SLOTS[key] if cup.id == CWC else KO_SLOTS[key]


static func _legs(cup: Cup, r: int) -> int:
	return _round_slots(cup, r).size()


# ---------------------------------------------------------------------------
# Consultas usadas pelo motor e pela interface
# ---------------------------------------------------------------------------

static func stage_importance(world: GameWorld, f: Fixture) -> float:
	var cup: Cup = world.season.cups.get(f.comp, null) if world.season != null else null
	if cup == null:
		return 0.6
	var imp: float = STAGE_IMPORTANCE.get(_round_key(cup, f.round), 0.6) * float(cfg(cup.id).get("importance", 1.0))
	if f.leg == 1:
		imp += 0.05
	return clampf(imp, 0.0, 1.0)


## Jogo que decide o confronto (jogo único ou volta).
static func is_deciding_leg(world: GameWorld, f: Fixture) -> bool:
	var cup: Cup = world.season.cups.get(f.comp, null) if world.season != null else null
	if cup == null or f.stage != Fixture.STAGE_KO:
		return false
	return f.leg == _legs(cup, f.round) - 1


## Gols das partidas anteriores do confronto, do ponto de vista [mandante, visitante] deste jogo.
static func aggregate_before(world: GameWorld, f: Fixture) -> Array:
	if f.leg == 0:
		return [0, 0]
	var cup: Cup = world.season.cups.get(f.comp, null)
	if cup == null:
		return [0, 0]
	for g in cup.fixtures:
		if g.stage == Fixture.STAGE_KO and g.round == f.round and g.leg == 0 and g.home == f.away and g.away == f.home and g.played:
			return [g.ag, g.hg]
	return [0, 0]


## Texto curto de um confronto de mata-mata: "Agregado 3 x 2" ou "Pênaltis 4 x 3".
static func tie_summary(cup: Cup, t: Dictionary) -> String:
	var fx := cup.fixtures_of_tie(t)
	if fx.is_empty():
		return ""
	var a := int(t["a"])
	var ga := 0
	var gb := 0
	for f in fx:
		if not f.played:
			continue
		if f.home == a:
			ga += f.hg
			gb += f.ag
		else:
			ga += f.ag
			gb += f.hg
	var last: Fixture = fx[fx.size() - 1]
	if last.played and last.has_penalties():
		var pa := last.pen_h if last.home == a else last.pen_a
		var pb := last.pen_a if last.home == a else last.pen_h
		return "%d x %d (pên. %d x %d)" % [ga, gb, pa, pb]
	return "%d x %d" % [ga, gb]


## Artilharia de uma copa na temporada.
static func scorers(world: GameWorld, cup_id: String, count: int) -> Array:
	var out: Array = []
	for p: Player in world.players.values():
		var st: Variant = p.cup_stats.get(cup_id, null)
		if st != null and int(st[Player.C_GOALS]) > 0:
			out.append(p)
	out.sort_custom(func(a, b):
		var ga: int = a.cup_stats[cup_id][Player.C_GOALS]
		var gb: int = b.cup_stats[cup_id][Player.C_GOALS]
		if ga != gb:
			return ga > gb
		return a.cup_stats[cup_id][Player.C_MINUTES] < b.cup_stats[cup_id][Player.C_MINUTES])
	return out.slice(0, count)


# ---------------------------------------------------------------------------
# Classificação
# ---------------------------------------------------------------------------

## Classificados para as copas da próxima temporada pela tabela final das primeiras divisões.
## O campeão da copa garante vaga para defender o título.
static func compute_qualified(world: GameWorld) -> Dictionary:
	var out := {}
	for id in continental_ids():
		var alloc: Dictionary = cfg(id)["alloc"]
		var list: Array = []
		for nation in alloc:
			var lid := DatabaseManager.league_at(nation, 1)
			var league := world.league(lid)
			if league == null:
				continue
			list.append_array(CompetitionManager.sorted_ids(league).slice(0, int(alloc[nation])))
		var cup: Cup = world.season.cups.get(id, null)
		if cup != null and cup.champion >= 0 and not list.has(cup.champion):
			_insert_holder(world, list, cup.champion)
		out[id] = list
	return out


## Primeira temporada: não há tabela anterior — classificam os de maior reputação de cada país.
static func initial_qualified(world: GameWorld) -> Dictionary:
	var out := {}
	for id in continental_ids():
		var alloc: Dictionary = cfg(id)["alloc"]
		var list: Array = []
		for nation in alloc:
			var lid := DatabaseManager.league_at(nation, 1)
			var ids: Array = []
			for c in world.clubs_in_league(lid):
				ids.append(c.id)
			ids.sort_custom(func(a, b): return world.club(a).reputation > world.club(b).reputation or (world.club(a).reputation == world.club(b).reputation and a < b))
			list.append_array(ids.slice(0, int(alloc[nation])))
		out[id] = list
	return out


static func _insert_holder(world: GameWorld, list: Array, holder: int) -> void:
	var nation := world.club(holder).nation
	for i in range(list.size() - 1, -1, -1):
		if world.club(list[i]).nation == nation:
			list[i] = holder
			return
	if not list.is_empty():
		list[list.size() - 1] = holder


# ---------------------------------------------------------------------------
# Montagem da temporada
# ---------------------------------------------------------------------------

static func setup_season(world: GameWorld, s: SeasonState) -> void:
	var qualified: Dictionary = world.stats.get("qualified", {})
	if qualified.is_empty():
		qualified = initial_qualified(world)
	for id in continental_ids():
		var list: Array = []
		for cid in qualified.get(id, []):
			var c := world.club(int(cid))
			if c != null and not list.has(c.id):
				list.append(c.id)
		if list.size() < 2:
			continue
		var cup := Cup.new()
		cup.id = id
		cup.name = cup_name(id)
		cup.short_name = cup_short(id)
		cup.club_ids = list
		for k in ko_plan(id):
			cup.round_names.append(ROUND_NAMES[k])
		var groups := int(cfg(id).get("groups", 0))
		if groups > 0 and list.size() >= groups * 4:
			_draw_groups(world, s, cup, groups)
		else:
			_create_ko_round(world, s, cup, 0, _seeded_pairs(world, list))
		s.cups[id] = cup
	world.stats.erase("qualified")
	_setup_state_cups(world, s)


## Estaduais: todos os clubes brasileiros do(s) estado(s), divididos em grupos equilibrados por reputação.
static func _setup_state_cups(world: GameWorld, s: SeasonState) -> void:
	for id in state_ids():
		var c := cfg(id)
		var ufs: Array = c.get("ufs", [])
		var list: Array = []
		for club: Club in world.clubs:
			if club.nation == String(c.get("nation", "BRA")) and ufs.has(uf_of(club)):
				list.append(club.id)
		if list.size() < int(c.get("qualify", 4)):
			continue
		list.sort_custom(func(a, b): return world.club(a).reputation > world.club(b).reputation or (world.club(a).reputation == world.club(b).reputation and a < b))
		var cup := Cup.new()
		cup.id = id
		cup.name = cup_name(id)
		cup.short_name = cup_short(id)
		cup.club_ids = list
		for k in ko_plan(id):
			cup.round_names.append(ROUND_NAMES[k])
		var n_groups := ceili(float(list.size()) / float(int(c.get("group_max", 8))))
		for g in n_groups:
			cup.groups.append({"n": GROUP_LETTERS[g], "clubs": [], "table": {}})
		# Distribuição em serpentina: 1º no A, 2º no B, ..., e volta.
		for i in list.size():
			var lap := i / n_groups
			var gi := i % n_groups if lap % 2 == 0 else n_groups - 1 - i % n_groups
			cup.groups[gi]["clubs"].append(list[i])
		var slots: Array = c.get("group_slots", [])
		for g in cup.groups:
			for cid in g["clubs"]:
				g["table"][cid] = CompetitionManager.empty_row()
			var rounds := FixtureManager.round_robin(world.rng, g["clubs"], int(c.get("group_legs", 1)))
			for r in mini(rounds.size(), slots.size()):
				for pair in rounds[r]:
					var f := Fixture.new()
					f.home = pair[0]
					f.away = pair[1]
					f.comp = id
					f.stage = Fixture.STAGE_GROUP
					f.round = r
					f.slot = s.slot_of(String(slots[r]))
					cup.fixtures.append(f)
		s.cups[id] = cup


static func _coef(world: GameWorld, cid: int) -> float:
	var c := world.club(cid)
	return c.reputation + float(DatabaseManager.nation(c.nation).get("coef", 40)) * 0.1


static func _draw_groups(world: GameWorld, s: SeasonState, cup: Cup, n_groups: int) -> void:
	var ids: Array = cup.club_ids.duplicate()
	ids.sort_custom(func(a, b): return _coef(world, a) > _coef(world, b) or (_coef(world, a) == _coef(world, b) and a < b))
	ids = ids.slice(0, n_groups * 4)
	cup.club_ids = ids
	cup.groups.clear()
	for g in n_groups:
		cup.groups.append({"n": GROUP_LETTERS[g], "clubs": [], "table": {}})
	for pot in 4:
		var pot_ids: Array = ids.slice(pot * n_groups, (pot + 1) * n_groups)
		RngUtil.shuffle(world.rng, pot_ids)
		for g in n_groups:
			var nations := {}
			for cid in cup.groups[g]["clubs"]:
				nations[world.club(cid).nation] = true
			var pick := 0
			for i in pot_ids.size():
				if not nations.has(world.club(pot_ids[i]).nation):
					pick = i
					break
			cup.groups[g]["clubs"].append(pot_ids[pick])
			pot_ids.remove_at(pick)
	for g in cup.groups:
		for cid in g["clubs"]:
			g["table"][cid] = CompetitionManager.empty_row()
		var rounds := FixtureManager.round_robin(world.rng, g["clubs"], 2)
		for r in rounds.size():
			var slot := s.slot_of("C%d" % (r + 1))
			for pair in rounds[r]:
				var f := Fixture.new()
				f.home = pair[0]
				f.away = pair[1]
				f.comp = cup.id
				f.stage = Fixture.STAGE_GROUP
				f.round = r
				f.slot = slot
				cup.fixtures.append(f)


## Pares da primeira fase de uma copa sem grupos: cabeças de chave contra os demais, evitando o mesmo país.
static func _seeded_pairs(world: GameWorld, ids: Array) -> Array:
	var sorted: Array = ids.duplicate()
	sorted.sort_custom(func(a, b): return _coef(world, a) > _coef(world, b) or (_coef(world, a) == _coef(world, b) and a < b))
	var half := sorted.size() / 2
	var seeds: Array = sorted.slice(0, half)
	var rest: Array = sorted.slice(half, half * 2)
	RngUtil.shuffle(world.rng, rest)
	var pairs: Array = []
	for sd in seeds:
		var pick := 0
		for i in rest.size():
			if world.club(rest[i]).nation != world.club(sd).nation:
				pick = i
				break
		pairs.append([rest[pick], sd]) # o cabeça de chave decide em casa
		rest.remove_at(pick)
	return pairs


## Cria os confrontos e jogos da fase `r`. pairs: [[a, b]] — `a` manda o jogo de ida, `b` a volta.
static func _create_ko_round(world: GameWorld, s: SeasonState, cup: Cup, r: int, pairs: Array) -> void:
	var slots := _round_slots(cup, r)
	var key := _round_key(cup, r)
	for pair in pairs:
		var a: int = pair[0]
		var b: int = pair[1]
		cup.ties.append({"r": r, "a": a, "b": b, "w": -1})
		for leg in slots.size():
			var f := Fixture.new()
			f.home = a if leg == 0 else b
			f.away = b if leg == 0 else a
			f.comp = cup.id
			f.stage = Fixture.STAGE_KO
			f.round = r
			f.leg = leg
			f.slot = s.slot_of(slots[leg])
			f.neutral = slots.size() == 1 and bool(cfg(cup.id).get("neutral_single", true))
			cup.fixtures.append(f)
		# Premiação por alcançar a fase (a fase de grupos paga no primeiro jogo).
		var prize := int(cfg(cup.id).get("prize", {}).get(key, 0))
		if prize > 0:
			for cid in [a, b]:
				world.club(cid).add_ledger("premiacao", prize)


# ---------------------------------------------------------------------------
# Resultados e avanço
# ---------------------------------------------------------------------------

## Registra um jogo de copa: tabela do grupo e premiação por resultado.
static func apply_result(world: GameWorld, f: Fixture) -> void:
	var cup: Cup = world.season.cups.get(f.comp, null)
	if cup == null:
		return
	var prize: Dictionary = cfg(cup.id).get("prize", {})
	if f.stage == Fixture.STAGE_GROUP:
		var g := cup.group_of(f.home)
		if not g.is_empty():
			CompetitionManager.apply_to_table(g["table"], f)
		if f.round == 0:
			for cid in [f.home, f.away]:
				world.club(cid).add_ledger("premiacao", int(prize.get("group", 0)))
		if f.hg != f.ag:
			world.club(f.home if f.hg > f.ag else f.away).add_ledger("premiacao", int(prize.get("win", 0)))
		else:
			for cid in [f.home, f.away]:
				world.club(cid).add_ledger("premiacao", int(prize.get("draw", 0)))


## Depois de cada data: fecha grupos, decide confrontos, sorteia a próxima fase, coroa campeões
## e monta o Mundial. Retorna eventos [{t, cup, club, ...}] para notícias e relatório.
static func after_slot(world: GameWorld, slot: int) -> Array:
	var events: Array = []
	var s := world.season
	for id in s.cups.keys():
		var cup: Cup = s.cups[id]
		if cup.finished:
			continue
		# Fim da fase de grupos → mata-mata
		if not cup.groups.is_empty() and cup.ties.is_empty() and _all_played(cup, Fixture.STAGE_GROUP, -1) and is_state(id):
			var seeds := state_qualified(cup)
			for cid in cup.club_ids:
				if not seeds.has(cid):
					events.append({"t": "out", "cup": id, "club": cid, "stage": "Primeira fase"})
			for cid in seeds:
				events.append({"t": "advance", "cup": id, "club": cid, "stage": "Primeira fase", "first": cid == seeds[0]})
			# Semifinal: 1º x 4º e 2º x 3º, jogo único na casa da melhor campanha.
			_create_ko_round(world, s, cup, 0, [[seeds[0], seeds[3]], [seeds[1], seeds[2]]])
		elif not cup.groups.is_empty() and cup.ties.is_empty() and _all_played(cup, Fixture.STAGE_GROUP, -1):
			var winners: Array = []
			var runners: Array = []
			for g in cup.groups:
				var order := CompetitionManager.sort_table(g["clubs"], g["table"])
				winners.append(order[0])
				runners.append(order[1])
				for i in range(2, order.size()):
					events.append({"t": "out", "cup": id, "club": order[i], "stage": "Fase de grupos"})
				events.append({"t": "advance", "cup": id, "club": order[0], "stage": "Fase de grupos", "first": true})
				events.append({"t": "advance", "cup": id, "club": order[1], "stage": "Fase de grupos", "first": false})
			_create_ko_round(world, s, cup, 0, _knockout_draw(world, cup, winners, runners))
		# Confrontos decididos
		for t in cup.ties:
			if int(t["w"]) >= 0:
				continue
			var fx := cup.fixtures_of_tie(t)
			if fx.size() < _legs(cup, int(t["r"])):
				continue
			var done := true
			for f in fx:
				if not f.played:
					done = false
			if not done:
				continue
			t["w"] = _tie_winner(world, t, fx)
			var loser := int(t["a"]) if int(t["w"]) == int(t["b"]) else int(t["b"])
			var stage_name: String = cup.round_names[int(t["r"])]
			events.append({"t": "out", "cup": id, "club": loser, "stage": stage_name, "by": int(t["w"])})
			if int(t["r"]) < cup.round_names.size() - 1:
				events.append({"t": "advance", "cup": id, "club": int(t["w"]), "stage": stage_name, "by": loser})
		# Próxima fase ou campeão
		var last_r := -1
		for t in cup.ties:
			last_r = maxi(last_r, int(t["r"]))
		if last_r >= 0:
			var round_ties := cup.ties_of_round(last_r)
			var all_decided := true
			for t in round_ties:
				if int(t["w"]) < 0:
					all_decided = false
			if all_decided:
				if last_r >= cup.round_names.size() - 1:
					_crown(world, cup, round_ties[0])
					events.append({"t": "champion", "cup": id, "club": cup.champion, "runner_up": cup.runner_up})
				else:
					var winners: Array = []
					for t in round_ties:
						winners.append(int(t["w"]))
					_create_ko_round(world, s, cup, last_r + 1, _next_pairs(world, cup, winners))
	# Mundial: quando todas as copas continentais acabaram.
	if not s.cups.has(CWC) and s.slot_type(slot) == "C13":
		var all_done := true
		for id in s.cups:
			if not s.cups[id].finished and not is_state(id):
				all_done = false
		if all_done:
			var cwc := _setup_club_world_cup(world, s)
			if cwc != null:
				events.append({"t": "cwc", "cup": CWC, "clubs": cwc.club_ids.duplicate()})
	return events


static func _all_played(cup: Cup, stage: int, r: int) -> bool:
	for f in cup.fixtures:
		if f.stage == stage and (r < 0 or f.round == r) and not f.played:
			return false
	return true


## Sorteio das oitavas: 1º de um grupo contra 2º de outro, evitando o mesmo país; o 1º decide em casa.
static func _knockout_draw(world: GameWorld, cup: Cup, winners: Array, runners: Array) -> Array:
	var groups_of := {}
	for gi in cup.groups.size():
		for cid in cup.groups[gi]["clubs"]:
			groups_of[cid] = gi
	var pool: Array = runners.duplicate()
	RngUtil.shuffle(world.rng, pool)
	var pairs: Array = []
	for w in winners:
		var pick := -1
		for strict in [true, false]:
			for i in pool.size():
				var r: int = pool[i]
				if groups_of[r] == groups_of[w]:
					continue
				if strict and world.club(r).nation == world.club(w).nation:
					continue
				pick = i
				break
			if pick >= 0:
				break
		if pick < 0:
			pick = 0
		pairs.append([pool[pick], w])
		pool.remove_at(pick)
	return pairs


## Fases seguintes: sorteio livre (copas continentais) ou chaveamento fixo (Mundial).
static func _next_pairs(world: GameWorld, cup: Cup, winners: Array) -> Array:
	if is_state(cup.id):
		# Final em ida e volta: a melhor campanha da primeira fase decide em casa (jogo de volta).
		var order_s := CompetitionManager.sort_table(winners, _merged_table(cup))
		var out: Array = []
		for i in range(0, order_s.size() - 1, 2):
			out.append([order_s[i + 1], order_s[i]])
		return out
	var order: Array = winners.duplicate()
	if cup.id != CWC:
		RngUtil.shuffle(world.rng, order)
	var pairs: Array = []
	for i in range(0, order.size() - 1, 2):
		pairs.append([order[i], order[i + 1]])
	return pairs


## Classificados de um estadual, em ordem de campanha: líderes dos grupos e depois os melhores dos demais.
static func state_qualified(cup: Cup) -> Array:
	var table := _merged_table(cup)
	var leaders: Array = []
	var rest: Array = []
	for g in cup.groups:
		var order := CompetitionManager.sort_table(g["clubs"], g["table"])
		leaders.append(order[0])
		rest.append_array(order.slice(1))
	var n := int(cfg(cup.id).get("qualify", 4))
	var out := CompetitionManager.sort_table(leaders, table).slice(0, n)
	for cid in CompetitionManager.sort_table(rest, table):
		if out.size() >= n:
			break
		out.append(cid)
	return CompetitionManager.sort_table(out, table)


static func _merged_table(cup: Cup) -> Dictionary:
	var table := {}
	for g in cup.groups:
		table.merge(g["table"])
	return table


static func _tie_winner(world: GameWorld, t: Dictionary, fx: Array) -> int:
	var a := int(t["a"])
	var b := int(t["b"])
	var ga := 0
	var gb := 0
	for f in fx:
		if f.home == a:
			ga += f.hg
			gb += f.ag
		else:
			ga += f.ag
			gb += f.hg
	if ga != gb:
		return a if ga > gb else b
	var last: Fixture = fx[fx.size() - 1]
	if last.has_penalties():
		var home_won: bool = last.pen_h > last.pen_a
		return last.home if home_won else last.away
	return a if world.club(a).reputation >= world.club(b).reputation else b


static func _crown(world: GameWorld, cup: Cup, final_tie: Dictionary) -> void:
	cup.champion = int(final_tie["w"])
	cup.runner_up = int(final_tie["a"]) if cup.champion == int(final_tie["b"]) else int(final_tie["b"])
	cup.finished = true
	var champ := world.club(cup.champion)
	champ.add_title(("W:" if cup.id == CWC else ("S:" if is_state(cup.id) else "C:")) + cup.id)
	champ.add_ledger("premiacao", int(cfg(cup.id).get("prize", {}).get("champion", 0)))
	champ.reputation = clampf(champ.reputation + float(cfg(cup.id).get("rep_bonus", 4.0 if cup.id == CWC else 3.0)), 5.0, 99.0)
	champ.fan_mood = clampf(champ.fan_mood + float(cfg(cup.id).get("fan_bonus", 15.0)), 0.0, 100.0)
	for pid in champ.player_ids:
		var p := world.player(pid)
		if p != null and p.cup_stats.has(cup.id):
			p.titles += 1


## Mundial de Clubes: campeões e vices da Europa e América do Sul, campeões da CONCACAF, África e Ásia
## e o melhor semifinalista europeu. Jogo único em sede neutra; os campeões de Europa e América do Sul
## ficam em lados opostos da chave.
static func _setup_club_world_cup(world: GameWorld, s: SeasonState) -> Cup:
	var ids: Array = []
	var ucl: Cup = s.cups.get("UCL", null)
	var lib: Cup = s.cups.get("LIB", null)
	var top_a := -1
	var top_b := -1
	if ucl != null and ucl.champion >= 0:
		top_a = ucl.champion
		ids.append(ucl.champion)
		ids.append(ucl.runner_up)
	if lib != null and lib.champion >= 0:
		top_b = lib.champion
		ids.append(lib.champion)
		ids.append(lib.runner_up)
	for id in ["CCC", "CAF", "AFC"]:
		var c: Cup = s.cups.get(id, null)
		if c != null and c.champion >= 0:
			ids.append(c.champion)
	# Completa com semifinalistas (Europa, depois América do Sul) por reputação.
	for src in [ucl, lib]:
		if src == null:
			continue
		var sf: Array = []
		for t in src.ties:
			if src.round_names[int(t["r"])] == ROUND_NAMES["sf"]:
				sf.append(int(t["a"]) if int(t["w"]) == int(t["b"]) else int(t["b"]))
		sf.sort_custom(func(a, b): return world.club(a).reputation > world.club(b).reputation)
		for cid in sf:
			if ids.size() >= 8:
				break
			if not ids.has(cid):
				ids.append(cid)
	var filtered: Array = []
	for cid in ids:
		if cid >= 0 and not filtered.has(cid):
			filtered.append(cid)
	if filtered.size() < 8:
		return null
	filtered = filtered.slice(0, 8)
	var cup := Cup.new()
	cup.id = CWC
	cup.name = cup_name(CWC)
	cup.short_name = cup_short(CWC)
	cup.club_ids = filtered
	for k in ko_plan(CWC):
		cup.round_names.append(ROUND_NAMES[k])
	# Chave: campeão europeu na posição 0, sul-americano na 4; os demais sorteados.
	var others: Array = []
	for cid in filtered:
		if cid != top_a and cid != top_b:
			others.append(cid)
	RngUtil.shuffle(world.rng, others)
	var bracket: Array = []
	for i in 8:
		bracket.append(-1)
	if top_a >= 0:
		bracket[0] = top_a
	if top_b >= 0:
		bracket[4] = top_b
	for i in 8:
		if bracket[i] < 0 and not others.is_empty():
			bracket[i] = others.pop_front()
	var pairs: Array = []
	for i in range(0, 8, 2):
		pairs.append([bracket[i], bracket[i + 1]])
	_create_ko_round(world, s, cup, 0, pairs)
	s.cups[CWC] = cup
	return cup
