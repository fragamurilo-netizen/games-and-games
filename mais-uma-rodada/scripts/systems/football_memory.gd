class_name FootballMemory
extends RefCounted
## Football Memory: a enciclopédia de cada save. O simulador já sabe tudo o que aconteceu;
## aqui guardamos o que não dá para reconstruir depois (confrontos, preços, gols decisivos,
## braçadeiras, técnicos) e montamos, na hora de mostrar, a linha do tempo de cada atleta,
## os recordes dos clubes e os momentos do mundo.
##
## Tudo fica em `world.memory` (vai junto no save):
##   h2h  {"a:b" (a < b)}: [jogos, vit. a, empates, vit. b, gols a, gols b, 1º ano, último ano,
##                          mata-matas vencidos por a, por b, finais vencidas por a, por b]
##   last {"a:b"}: últimos encontros [[ano, comp, mandante, gols mand., gols visit., tipo, pên. mand., pên. visit.]]
##   tx   {"a:b"}: transferências entre os dois [de a para b, de b para a, último jogador, último ano]
##   pm   {pid}: momentos do jogador [[ano, tipo, clube, valor, extra]]
##   cap  {pid}: braçadeira [[clube, de, até]]
##   cr   {clube}: recordes {buy, sell, win, loss, att, coaches}
##   wr   recordes do mundo {fee, win}
##   fin  finais [[ano, comp, campeão, vice, gols campeão, gols vice, pên. c, pên. v, [artilheiros do campeão]]]
##   ups  zebras [[ano, comp, vencedor, perdedor, gols v, gols p, diferença de reputação]]
##   der  clássicos marcantes [[ano, comp, mandante, visitante, gm, gv, tipo]]
##   tit  títulos decididos [[ano, liga, campeão, adversário, gm, gv, pid do gol (-1), rodadas restantes]]
##   cl   {liga: ano} liga já decidida neste ano
##   top  {clube: pid} maior artilheiro da história do clube (para notar quando o recorde cai)
##   ex   {"coach:clube": ano} ídolo que virou técnico já enfrentou o ex-clube
##   lc   {pid: id do técnico} aposentados que viraram técnicos

const VERSION := 1
const LAST_N := 6
const PM_MAX := 40
const TOP_CLUB := 5
const TOP_WORLD := 12
const FIN_MAX := 600
const DER_MAX := 300
const UPS_PER_YEAR := 6
const TIT_MAX := 400
const COACHES_MAX := 16

# Tipos de encontro
const K_LEAGUE := 0
const K_CUP := 1
const K_KO := 2
const K_FINAL := 3

# Índices do registro h2h
const H_N := 0
const H_WA := 1
const H_D := 2
const H_WB := 3
const H_GA := 4
const H_GB := 5
const H_FIRST := 6
const H_LAST := 7
const H_KOA := 8
const H_KOB := 9
const H_FA := 10
const H_FB := 11

## Apps pelo clube a partir das quais o jogador é um ídolo de lá.
const IDOL_APPS := 120


static func data(world: GameWorld) -> Dictionary:
	var m: Dictionary = world.memory
	if int(m.get("v", 0)) < VERSION:
		for k in ["h2h", "last", "tx", "pm", "cap", "cr", "cl", "top", "ex", "lc"]:
			if not m.has(k):
				m[k] = {}
		for k in ["fin", "ups", "der", "tit"]:
			if not m.has(k):
				m[k] = []
		if not m.has("wr"):
			m["wr"] = {"fee": [], "win": []}
		m["v"] = VERSION
	return m


static func pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]


static func comp_name(world: GameWorld, comp: String) -> String:
	if DatabaseManager.has_league(comp):
		return world.league_short(comp)
	return CupManager.cup_short(comp)


static func _club_name(world: GameWorld, id: int) -> String:
	var c := world.club(id) if id >= 0 and id < world.clubs.size() else null
	return c.short_name if c != null else "?"


# ---------------------------------------------------------------------------
# Registro: partidas
# ---------------------------------------------------------------------------

## Chamado para cada jogo oficial (liga, playoffs e copas) já com o placar aplicado.
static func on_match(world: GameWorld, f: Fixture) -> void:
	if f.home < 0 or f.away < 0:
		return
	var m := data(world)
	var kind := _kind_of(world, f)
	var tie_w := _tie_winner(world, f) if kind >= K_KO else -1
	_h2h_add(world, m, f, kind, tie_w)
	_club_records(world, m, f)
	_world_records(world, m, f)
	_upset(world, m, f, kind)
	var home := world.club(f.home)
	if home.is_rival(f.away) or world.club(f.away).is_rival(f.home):
		if absi(f.hg - f.ag) >= 3 or kind >= K_KO:
			var der: Array = m["der"]
			der.append([world.year, f.comp, f.home, f.away, f.hg, f.ag, kind])
			if der.size() > DER_MAX:
				m["der"] = der.slice(der.size() - DER_MAX)
	if kind == K_FINAL and tie_w >= 0:
		_final(world, m, f, tie_w)
	_coach_returns(world, m, f)


static func _kind_of(world: GameWorld, f: Fixture) -> int:
	if f.stage == Fixture.STAGE_LEAGUE:
		return K_LEAGUE
	if f.stage != Fixture.STAGE_KO:
		return K_CUP
	var league := world.league(f.comp)
	if league != null:
		if not LeagueFormat.is_deciding_leg(world, f):
			return K_CUP
		if f.round == LeagueFormat.BAR_R:
			return K_KO
		var ko: Array = LeagueFormat.cfg(league).get("ko", ["f"])
		return K_FINAL if String(ko[clampi(f.round, 0, ko.size() - 1)]) == "f" else K_KO
	var cup: Cup = world.season.cups.get(f.comp, null) if world.season != null else null
	if cup == null or not CupManager.is_deciding_leg(world, f):
		return K_CUP
	return K_FINAL if CupManager._round_key(cup, f.round) == "f" else K_KO


## Quem passou no confronto decidido neste jogo (agregado e pênaltis), ou -1.
static func _tie_winner(world: GameWorld, f: Fixture) -> int:
	var agg: Array = LeagueFormat.aggregate_before(world, f) if world.league(f.comp) != null else CupManager.aggregate_before(world, f)
	var th := int(agg[0]) + f.hg
	var ta := int(agg[1]) + f.ag
	if f.has_penalties():
		return f.home if f.pen_h > f.pen_a else f.away
	if th != ta:
		return f.home if th > ta else f.away
	return -1


static func _h2h_add(world: GameWorld, m: Dictionary, f: Fixture, kind: int, tie_w: int) -> void:
	var key := pair_key(f.home, f.away)
	var a := mini(f.home, f.away)
	var ga := f.hg if f.home == a else f.ag
	var gb := f.ag if f.home == a else f.hg
	var h: Array = m["h2h"].get(key, [])
	if h.is_empty():
		h = [0, 0, 0, 0, 0, 0, world.year, world.year, 0, 0, 0, 0]
		m["h2h"][key] = h
	h[H_N] = int(h[H_N]) + 1
	if ga > gb:
		h[H_WA] = int(h[H_WA]) + 1
	elif gb > ga:
		h[H_WB] = int(h[H_WB]) + 1
	else:
		h[H_D] = int(h[H_D]) + 1
	h[H_GA] = int(h[H_GA]) + ga
	h[H_GB] = int(h[H_GB]) + gb
	h[H_LAST] = world.year
	if tie_w >= 0:
		var idx := (H_FA if tie_w == a else H_FB) if kind == K_FINAL else (H_KOA if tie_w == a else H_KOB)
		h[idx] = int(h[idx]) + 1
	var last: Array = m["last"].get(key, [])
	var e := [world.year, f.comp, f.home, f.hg, f.ag, kind]
	if f.has_penalties():
		e.append_array([f.pen_h, f.pen_a])
	last.append(e)
	if last.size() > LAST_N:
		last = last.slice(last.size() - LAST_N)
	m["last"][key] = last


static func _cr(m: Dictionary, club_id: int) -> Dictionary:
	var cr: Dictionary = m["cr"].get(club_id, {})
	if cr.is_empty():
		cr = {"buy": [], "sell": [], "win": [], "loss": [], "att": [], "coaches": []}
		m["cr"][club_id] = cr
	return cr


## Insere mantendo os `cap` maiores pelo critério `better(a, b)`.
static func _top_insert(arr: Array, e: Array, cap: int, better: Callable) -> void:
	var i := arr.size()
	while i > 0 and better.call(e, arr[i - 1]):
		i -= 1
	if i >= cap:
		return
	arr.insert(i, e)
	if arr.size() > cap:
		arr.resize(cap)


static func _by_margin(a: Array, b: Array) -> bool:
	var ma := int(a[0]) - int(a[1])
	var mb := int(b[0]) - int(b[1])
	return ma > mb or (ma == mb and int(a[0]) > int(b[0]))


static func _club_records(world: GameWorld, m: Dictionary, f: Fixture) -> void:
	for side in 2:
		var cid := f.home if side == 0 else f.away
		var gf := f.hg if side == 0 else f.ag
		var ga := f.ag if side == 0 else f.hg
		if gf == ga:
			continue
		var cr := _cr(m, cid)
		var opp := f.away if side == 0 else f.home
		if gf > ga and gf - ga >= 3:
			_top_insert(cr["win"], [gf, ga, opp, world.year, f.comp, side == 0], 3, _by_margin)
		elif ga > gf and ga - gf >= 3:
			_top_insert(cr["loss"], [ga, gf, opp, world.year, f.comp, side == 0], 3, _by_margin)
	if f.attendance > 0 and not f.neutral:
		var hr := _cr(m, f.home)
		var att: Array = hr["att"]
		if att.is_empty() or f.attendance > int(att[0]):
			hr["att"] = [f.attendance, f.away, world.year, f.comp]


static func _world_records(world: GameWorld, m: Dictionary, f: Fixture) -> void:
	if absi(f.hg - f.ag) < 5:
		return
	var w := f.home if f.hg > f.ag else f.away
	var l := f.away if w == f.home else f.home
	_top_insert(m["wr"]["win"], [maxi(f.hg, f.ag), mini(f.hg, f.ag), w, l, world.year, f.comp], TOP_WORLD, _by_margin)


## Zebra: o time de reputação bem menor vence um jogo de primeira divisão ou de copa.
static func _upset(world: GameWorld, m: Dictionary, f: Fixture, kind: int) -> void:
	if f.hg == f.ag and not f.has_penalties():
		return
	var w := f.home if (f.hg > f.ag or (f.hg == f.ag and f.pen_h > f.pen_a)) else f.away
	var l := f.away if w == f.home else f.home
	if kind == K_LEAGUE and world.club(w).tier != 1:
		return
	var gap := world.club(l).reputation - world.club(w).reputation
	if gap < 22.0:
		return
	m["ups"].append([world.year, f.comp, w, l, f.hg if w == f.home else f.ag, f.ag if w == f.home else f.hg, snappedf(gap, 0.1)])


static func _final(world: GameWorld, m: Dictionary, f: Fixture, champ: int) -> void:
	var runner := f.opponent_of(champ)
	var side := 0 if f.home == champ else 1
	var agg: Array = LeagueFormat.aggregate_before(world, f) if world.league(f.comp) != null else CupManager.aggregate_before(world, f)
	var gc := int(agg[side]) + (f.hg if side == 0 else f.ag)
	var gr := int(agg[1 - side]) + (f.ag if side == 0 else f.hg)
	var pc := -1
	var pr := -1
	if f.has_penalties():
		pc = f.pen_h if side == 0 else f.pen_a
		pr = f.pen_a if side == 0 else f.pen_h
	var scorers := {}
	for g in f.goals:
		if int(g[1]) == side and int(g[3]) != Fixture.GOAL_OWN:
			var pid := int(g[2])
			scorers[pid] = int(scorers.get(pid, 0)) + 1
	for pid in scorers:
		add_moment(world, pid, "fgoal", champ, int(scorers[pid]), f.comp)
	var fin: Array = m["fin"]
	fin.append([world.year, f.comp, champ, runner, gc, gr, pc, pr, scorers.keys()])
	if fin.size() > FIN_MAX:
		m["fin"] = fin.slice(fin.size() - FIN_MAX)


# ---------------------------------------------------------------------------
# Registro: fim de cada data (títulos decididos)
# ---------------------------------------------------------------------------

## Depois de todos os jogos da data: descobre ligas que acabaram de ser decididas e
## guarda o gol do título.
static func after_matchday(world: GameWorld, entries: Array) -> void:
	var m := data(world)
	var touched := {}
	for e in entries:
		var f: Fixture = e["f"]
		if f.is_league() and world.league(f.comp) != null:
			touched[f.comp] = true
	for lid in touched:
		if int(m["cl"].get(lid, 0)) == world.year:
			continue
		var league := world.league(lid)
		if LeagueFormat.kind(league) != "":
			continue
		var rem := {}
		for r in league.rounds:
			for f: Fixture in r:
				if f.stage == Fixture.STAGE_LEAGUE and not f.played:
					rem[f.home] = int(rem.get(f.home, 0)) + 1
					rem[f.away] = int(rem.get(f.away, 0)) + 1
		var ids := CompetitionManager.sorted_ids(league)
		if ids.size() < 2:
			continue
		var leader := int(ids[0])
		var lead_pts := int(league.table[leader]["pts"])
		var open := false
		for i in range(1, ids.size()):
			var cid := int(ids[i])
			if int(league.table[cid]["pts"]) + 3 * int(rem.get(cid, 0)) >= lead_pts:
				open = true
				break
		if open:
			continue
		m["cl"][lid] = world.year
		_title_decided(world, m, league, leader, entries, int(rem.get(leader, 0)))


static func _title_decided(world: GameWorld, m: Dictionary, league: League, champ: int, entries: Array, left: int) -> void:
	var fx: Fixture = null
	for e in entries:
		var f: Fixture = e["f"]
		if f.comp == league.id and f.involves(champ):
			fx = f
	var opp := -1
	var gc := 0
	var go := 0
	var hero := -1
	if fx != null:
		opp = fx.opponent_of(champ)
		var side := 0 if fx.home == champ else 1
		gc = fx.hg if side == 0 else fx.ag
		go = fx.ag if side == 0 else fx.hg
		if gc > go:
			# O gol da vitória: o que deixou o campeão na frente de vez.
			var n := 0
			var goals: Array = fx.goals.duplicate()
			goals.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
			for g in goals:
				if int(g[1]) == side:
					n += 1
					if n == go + 1 and int(g[3]) != Fixture.GOAL_OWN:
						hero = int(g[2])
	var tit: Array = m["tit"]
	tit.append([world.year, league.id, champ, opp, gc, go, hero, left])
	if tit.size() > TIT_MAX:
		m["tit"] = tit.slice(tit.size() - TIT_MAX)
	if hero >= 0:
		add_moment(world, hero, "tgoal", champ, 0, league.id)
	if world.has_user() and (league.id == world.user_league_id() or world.is_user_club(champ)):
		var c := world.club(champ)
		var hp := world.player(hero)
		var body := "O %s garantiu o título da %s%s." % [c.short_name, league.name, (" com %d rodada(s) de antecedência" % left) if left > 0 else ""]
		if hp != null:
			body += " O gol do título foi de %s, contra o %s." % [hp.display_name(), _club_name(world, opp)]
		NewsManager.post_raw(world, "%s é campeão da %s" % [c.short_name, league.short_name], body, champ, hero,
			NewsEvent.IMP_HEADLINE if world.is_user_club(champ) else NewsEvent.IMP_HIGH, "campeao")


# ---------------------------------------------------------------------------
# Registro: transferências, técnicos e fim de temporada
# ---------------------------------------------------------------------------

static func add_moment(world: GameWorld, pid: int, kind: String, club_id: int, value: int = 0, extra: Variant = "") -> void:
	if pid < 0:
		return
	var m := data(world)
	var arr: Array = m["pm"].get(pid, [])
	arr.append([world.year, kind, club_id, value, extra])
	if arr.size() > PM_MAX:
		arr = arr.slice(arr.size() - PM_MAX)
	m["pm"][pid] = arr


static func moments(world: GameWorld, pid: int) -> Array:
	return data(world)["pm"].get(pid, [])


## Transferência concluída (compra ou sem custo).
static func on_transfer(world: GameWorld, t: Transfer) -> void:
	var m := data(world)
	add_moment(world, t.player_id, "buy" if t.fee > 0 else "free", t.to_id, t.fee, t.from_id)
	if t.from_id < 0 or t.to_id < 0:
		return
	var key := pair_key(t.from_id, t.to_id)
	var tx: Array = m["tx"].get(key, [0, 0, -1, 0])
	tx[0 if t.from_id < t.to_id else 1] = int(tx[0 if t.from_id < t.to_id else 1]) + 1
	tx[2] = t.player_id
	tx[3] = world.year
	m["tx"][key] = tx
	if t.fee <= 0:
		return
	var by_fee := func(a: Array, b: Array): return int(a[0]) > int(b[0])
	_top_insert(_cr(m, t.to_id)["buy"], [t.fee, t.player_id, t.player_name, t.from_id, world.year, t.age], TOP_CLUB, by_fee)
	_top_insert(_cr(m, t.from_id)["sell"], [t.fee, t.player_id, t.player_name, t.to_id, world.year, t.age], TOP_CLUB, by_fee)
	_top_insert(m["wr"]["fee"], [t.fee, t.player_id, t.player_name, t.from_id, t.to_id, world.year, t.age], TOP_WORLD, by_fee)


## Técnico deixando o clube (demitido ou de saída): fica na galeria de técnicos do clube.
static func on_coach_left(world: GameWorld, club: Club, coach: Dictionary) -> void:
	if coach.is_empty():
		return
	var cr := _cr(data(world), club.id)
	var arr: Array = cr["coaches"]
	arr.append([String(coach.get("n", "")), int(coach.get("since", world.year)), world.year, int(coach.get("w", 0)), int(coach.get("d", 0)),
		int(coach.get("l", 0)), int(coach.get("id", -1)), int(coach.get("pid", -1))])
	if arr.size() > COACHES_MAX:
		cr["coaches"] = arr.slice(arr.size() - COACHES_MAX)


## Fim de temporada (depois das aposentadorias, antes da virada do ano).
static func on_season_end(world: GameWorld, retired: Array) -> void:
	var m := data(world)
	_captains(world, m)
	_scorer_records(world, m)
	_trim_upsets(world, m)
	for p: Player in retired:
		_maybe_coach(world, m, p)
	# Momentos de quem saiu do mundo sem virar lenda deixam de ocupar espaço.
	var keep := {}
	for r in world.retired:
		keep[int(r.get("id", -1))] = true
	for pid in m["pm"].keys():
		if not world.players.has(pid) and not keep.has(int(pid)):
			m["pm"].erase(pid)
	for pid in m["cap"].keys():
		if not world.players.has(pid) and not keep.has(int(pid)):
			m["cap"].erase(pid)


static func _captains(world: GameWorld, m: Dictionary) -> void:
	for c: Club in world.clubs:
		if c.sheet == null or c.sheet.captain < 0:
			continue
		var pid := c.sheet.captain
		var p := world.player(pid)
		if p == null or p.club_id != c.id:
			continue
		var arr: Array = m["cap"].get(pid, [])
		if not arr.is_empty() and int(arr[-1][0]) == c.id and int(arr[-1][2]) >= world.year - 1:
			arr[-1][2] = world.year
		else:
			arr.append([c.id, world.year, world.year])
		m["cap"][pid] = arr


static func captaincy(world: GameWorld, pid: int) -> Array:
	return data(world)["cap"].get(pid, [])


## Nota quando um jogador em atividade vira o maior artilheiro da história de um clube.
static func _scorer_records(world: GameWorld, m: Dictionary) -> void:
	var best := {} # clube -> [gols, pid]
	for p: Player in world.players.values():
		for s in p.spells:
			var cid := int(s.get("c", -1))
			var g := int(s.get("g", 0))
			if cid >= 0 and g >= 30 and g > int(best.get(cid, [0, -1])[0]):
				best[cid] = [g, p.id]
	for r in world.retired:
		for s in r.get("spells", []):
			var cid := int(s.get("c", -1))
			var g := int(s.get("g", 0))
			if cid >= 0 and g > int(best.get(cid, [0, -1])[0]):
				best[cid] = [g, -1 - int(r.get("id", 0))]
	for cid in best:
		var pid := int(best[cid][1])
		var prev := int(m["top"].get(cid, -2))
		if prev == pid:
			continue
		m["top"][cid] = pid
		if pid < 0 or prev == -2 and world.season_number <= 1:
			continue
		add_moment(world, pid, "crec", cid, int(best[cid][0]))
		if world.has_user() and world.is_user_club(cid):
			var p := world.player(pid)
			NewsManager.post_raw(world, "%s é o maior artilheiro da história do %s" % [p.display_name(), world.club(cid).short_name],
				"Com %d gols pelo clube, %s passou todos os nomes que já vestiram essa camisa." % [int(best[cid][0]), p.display_name()],
				cid, pid, NewsEvent.IMP_HIGH, "recorde")


static func _trim_upsets(world: GameWorld, m: Dictionary) -> void:
	var cur: Array = []
	var old: Array = []
	for u in m["ups"]:
		if int(u[0]) == world.year:
			cur.append(u)
		else:
			old.append(u)
	cur.sort_custom(func(a, b): return float(a[6]) > float(b[6]))
	m["ups"] = old + cur.slice(0, UPS_PER_YEAR)
	if m["ups"].size() > 240:
		m["ups"] = m["ups"].slice(m["ups"].size() - 240)


## Lendas que penduram as chuteiras podem voltar como técnico.
static func _maybe_coach(world: GameWorld, m: Dictionary, p: Player) -> void:
	var notable := p.career_apps >= 300 or p.titles >= 3 or p.career_goals >= 100
	if not notable or p.age(world.year) < 32:
		return
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, p.id * 131 + world.year, 777001)
	if r.randf() > 0.4:
		return
	var pp := People.data(world)
	var main := _main_club(p.spells)
	var nat := p.nationality
	var level := clampf(float(p.overall) - 10.0 + p.titles * 1.5, 25.0, 85.0)
	var coach := People._new_coach(world, r, nat, level, "")
	coach["n"] = p.display_name()
	coach["nat"] = nat
	coach["by"] = p.birth_year
	coach["pid"] = p.id
	coach["idol"] = main
	coach["since"] = world.year
	pp["free"].append(coach)
	m["lc"][p.id] = int(coach["id"])


## Clube onde o jogador mais jogou (o "clube do coração" da carreira), ou -1.
static func _main_club(spells: Array) -> int:
	var apps := {}
	for s in spells:
		var cid := int(s.get("c", -1))
		if cid >= 0 and not String(s.get("cn", "")).ends_with("(empr.)"):
			apps[cid] = int(apps.get(cid, 0)) + int(s.get("a", 0))
	var best := -1
	var best_a := 0
	for cid in apps:
		if int(apps[cid]) > best_a:
			best_a = int(apps[cid])
			best = int(cid)
	return best


## Jogos que um técnico ex-jogador fez pelo clube (0 se nunca jogou lá).
static func coach_bond(world: GameWorld, coach: Dictionary, club_id: int) -> int:
	var pid := int(coach.get("pid", -1))
	if pid < 0:
		return 0
	var r := retired_record(world, pid)
	var n := 0
	for s in r.get("spells", []):
		if int(s.get("c", -1)) == club_id:
			n += int(s.get("a", 0))
	return n


static func retired_record(world: GameWorld, pid: int) -> Dictionary:
	for i in range(world.retired.size() - 1, -1, -1):
		if int(world.retired[i].get("id", -1)) == pid:
			return world.retired[i]
	return {}


## Um ídolo que virou técnico enfrenta pela primeira vez o clube onde fez história.
static func _coach_returns(world: GameWorld, m: Dictionary, f: Fixture) -> void:
	for side in 2:
		var cid := f.home if side == 0 else f.away
		var opp := f.away if side == 0 else f.home
		var coach := People.coach_of(world, cid)
		if coach.is_empty() or int(coach.get("pid", -1)) < 0:
			continue
		var key := "%d:%d" % [int(coach.get("id", -1)), opp]
		if m["ex"].has(key):
			continue
		var apps := coach_bond(world, coach, opp)
		if apps < 40:
			continue
		m["ex"][key] = world.year
		var pid := int(coach["pid"])
		add_moment(world, pid, "face", opp, apps, cid)
		if world.has_user() and (world.is_user_club(opp) or world.is_user_club(cid) or world.club(cid).league_id == world.user_league_id()):
			var idol := apps >= IDOL_APPS
			NewsManager.post_raw(world, "%s enfrenta pela primeira vez o %s" % [String(coach["n"]), _club_name(world, opp)],
				"%s, agora técnico do %s, reencontrou o clube onde %s (%d jogos). Placar: %s %d x %d %s." % [String(coach["n"]), _club_name(world, cid),
				"se tornou ídolo" if idol else "jogou", apps, _club_name(world, f.home), f.hg, f.ag, _club_name(world, f.away)],
				opp, -1, NewsEvent.IMP_HIGH if world.is_user_club(opp) or world.is_user_club(cid) else NewsEvent.IMP_NORMAL, "tecnicos")


# ---------------------------------------------------------------------------
# Consultas (interface e outros sistemas, como a rivalidade entre clubes)
# ---------------------------------------------------------------------------

## Retrospecto entre dois clubes do ponto de vista de `a`:
## {games, wins, draws, losses, gf, ga, first, last, ko_won, ko_lost, finals_won, finals_lost,
##  transfers_to, transfers_from, recent: [{y, comp, home, hg, ag, kind, gf, ga, pens}]} (recent: mais novo no fim).
static func head_to_head(world: GameWorld, a: int, b: int) -> Dictionary:
	var m := data(world)
	var key := pair_key(a, b)
	var h: Array = m["h2h"].get(key, [])
	var low := a < b
	var out := {"games": 0, "wins": 0, "draws": 0, "losses": 0, "gf": 0, "ga": 0, "first": 0, "last": 0,
		"ko_won": 0, "ko_lost": 0, "finals_won": 0, "finals_lost": 0, "transfers_to": 0, "transfers_from": 0, "recent": []}
	if not h.is_empty():
		out["games"] = int(h[H_N])
		out["wins"] = int(h[H_WA] if low else h[H_WB])
		out["losses"] = int(h[H_WB] if low else h[H_WA])
		out["draws"] = int(h[H_D])
		out["gf"] = int(h[H_GA] if low else h[H_GB])
		out["ga"] = int(h[H_GB] if low else h[H_GA])
		out["first"] = int(h[H_FIRST])
		out["last"] = int(h[H_LAST])
		out["ko_won"] = int(h[H_KOA] if low else h[H_KOB])
		out["ko_lost"] = int(h[H_KOB] if low else h[H_KOA])
		out["finals_won"] = int(h[H_FA] if low else h[H_FB])
		out["finals_lost"] = int(h[H_FB] if low else h[H_FA])
	var tx: Array = m["tx"].get(key, [])
	if not tx.is_empty():
		out["transfers_to"] = int(tx[0] if low else tx[1]) # de a para b
		out["transfers_from"] = int(tx[1] if low else tx[0])
	for e in m["last"].get(key, []):
		var home := int(e[2])
		var hg := int(e[3])
		var ag := int(e[4])
		out["recent"].append({"y": int(e[0]), "comp": String(e[1]), "home": home, "hg": hg, "ag": ag, "kind": int(e[5]),
			"gf": hg if home == a else ag, "ga": ag if home == a else hg, "pens": [int(e[6]), int(e[7])] if e.size() >= 8 else []})
	return out


## Adversários mais enfrentados por um clube: [{id, games, wins, draws, losses, gf, ga}] (mais jogos primeiro).
static func opponents_of(world: GameWorld, club_id: int, limit: int = 10) -> Array:
	var out: Array = []
	for key: String in data(world)["h2h"]:
		var parts := key.split(":")
		var x := int(parts[0])
		var y := int(parts[1])
		if x != club_id and y != club_id:
			continue
		var opp := y if x == club_id else x
		var h := head_to_head(world, club_id, opp)
		h["id"] = opp
		h.erase("recent")
		out.append(h)
	out.sort_custom(func(p, q): return int(p["games"]) > int(q["games"]) if p["games"] != q["games"] else int(p["id"]) < int(q["id"]))
	return out.slice(0, limit)


## Texto curto: "12 jogos · 5V 3E 4D · 18 x 15".
static func h2h_line(h: Dictionary) -> String:
	return "%d jogo(s) · %dV %dE %dD · gols %d x %d" % [int(h["games"]), int(h["wins"]), int(h["draws"]), int(h["losses"]), int(h["gf"]), int(h["ga"])]


## Maiores artilheiros e jogadores com mais jogos pelo clube (em atividade e lendas aposentadas):
## [{n, g, a, pid (-1 aposentado), from, to}]
static func club_legends(world: GameWorld, club_id: int) -> Array:
	var totals := {}
	for p: Player in world.players.values():
		for s in p.spells:
			if int(s.get("c", -1)) == club_id:
				_acc(totals, "p%d" % p.id, p.display_name(), s, p.id)
	for r in world.retired:
		for s in r.get("spells", []):
			if int(s.get("c", -1)) == club_id:
				_acc(totals, "r%d" % int(r["id"]), String(r.get("ka", r.get("name", ""))), s, -1)
	return totals.values()


static func _acc(totals: Dictionary, key: String, name: String, s: Dictionary, pid: int) -> void:
	if not totals.has(key):
		totals[key] = {"n": name, "g": 0, "a": 0, "pid": pid, "from": int(s.get("from", 0)), "to": int(s.get("to", 0))}
	var e: Dictionary = totals[key]
	e["g"] = int(e["g"]) + int(s.get("g", 0))
	e["a"] = int(e["a"]) + int(s.get("a", 0))
	e["from"] = mini(int(e["from"]), int(s.get("from", 0))) if int(e["from"]) > 0 else int(s.get("from", 0))


## Posição do jogador entre os artilheiros históricos de um clube (1 = maior), 0 se fora do top 10.
static func scorer_rank(world: GameWorld, club_id: int, pid: int) -> int:
	var arr := club_legends(world, club_id)
	arr.sort_custom(func(x, y): return int(x["g"]) > int(y["g"]))
	for i in mini(10, arr.size()):
		if int(arr[i]["pid"]) == pid and int(arr[i]["g"]) > 0:
			return i + 1
	return 0


static func club_records(world: GameWorld, club_id: int) -> Dictionary:
	return _cr(data(world), club_id)


## Títulos conquistados por um clube entre dois anos (inclusive), pelo arquivo das temporadas.
static func titles_between(world: GameWorld, club_id: int, y0: int, y1: int) -> int:
	var n := 0
	for h in world.history:
		var y := int(h.get("y", 0))
		if h.get("pre", false) or y < y0 or y > y1:
			continue
		for lid in h.get("leagues", {}):
			if int(h["leagues"][lid].get("champion", -1)) == club_id:
				n += 1
		for cid in h.get("cups", {}):
			if int(h["cups"][cid].get("champion", -1)) == club_id:
				n += 1
	return n


# ---------------------------------------------------------------------------
# Linha do tempo do jogador
# ---------------------------------------------------------------------------

## Fatos de destaque e momentos da carreira em ordem: {facts: [String], events: [{y, t, k}]}.
static func timeline(world: GameWorld, p: Player) -> Dictionary:
	var facts: Array = []
	var ev: Array = []
	var pm := moments(world, p.id)
	# Estreia
	var first_y := 0
	var first_c := ""
	for h in p.history:
		if first_y == 0 or int(h.get("y", 0)) < first_y:
			first_y = int(h.get("y", 0))
			first_c = String(h.get("cn", ""))
	if first_y == 0 and not p.spells.is_empty() and p.career_apps > 0:
		first_y = int(p.spells[0].get("from", world.year))
		first_c = String(p.spells[0].get("cn", ""))
	if first_y > 0:
		ev.append({"y": first_y, "t": "Estreou aos %d pelo %s" % [first_y - p.birth_year, first_c], "k": "debut"})
	else:
		ev.append({"y": world.year, "t": "Ainda não estreou como profissional", "k": "debut"})
	# Chegadas a cada clube (com o preço, quando o jogo registrou)
	var buys := {}
	for e in pm:
		if String(e[1]) == "buy" or String(e[1]) == "free":
			buys["%d:%d" % [int(e[0]), int(e[2])]] = e
	for i in range(1, p.spells.size()):
		var s: Dictionary = p.spells[i]
		var y := int(s.get("from", 0))
		var cn := String(s.get("cn", ""))
		var age := y - p.birth_year
		if cn.ends_with("(empr.)"):
			ev.append({"y": y, "t": "Emprestado ao %s" % cn.trim_suffix(" (empr.)"), "k": "move"})
			continue
		if i > 0 and int(p.spells[i - 1].get("c", -1)) == int(s.get("c", -2)):
			continue # volta de empréstimo
		var b: Array = buys.get("%d:%d" % [y, int(s.get("c", -1))], [])
		var text := "Transferiu-se para o %s aos %d" % [cn, age]
		if not b.is_empty():
			text = ("Comprado pelo %s aos %d, por %s" % [cn, age, Fmt.money(int(b[3]))]) if String(b[1]) == "buy" else "Chegou ao %s sem custo, aos %d" % [cn, age]
		if world.has_user() and world.is_user_club(int(s.get("c", -1))):
			text = text.replace(" pelo %s" % cn, " pelo seu clube (%s)" % cn).replace(" para o %s" % cn, " para o seu clube (%s)" % cn)
		ev.append({"y": y, "t": text, "k": "move"})
	# Títulos
	for t in p.trophies:
		var k := String(t.get("k", ""))
		var name := NationalTeamManager.tournament_name(k.substr(2)) if k.begins_with("N:") else TrophyView.trophy_name(k, world)
		ev.append({"y": int(t.get("y", 0)), "t": "Campeão: %s" % name, "k": "title"})
	# Prêmios
	for a in p.awards:
		ev.append({"y": int(a.get("y", 0)), "t": "Prêmio: %s%s" % [AwardManager.award_name(String(a.get("k", ""))), _award_where(world, String(a.get("l", "")))], "k": "award"})
	# Momentos guardados
	for e in pm:
		var kind := String(e[1])
		var cn := _club_name(world, int(e[2]))
		match kind:
			"fgoal":
				ev.append({"y": int(e[0]), "t": "%s na final da %s pelo %s" % ["Gol" if int(e[3]) == 1 else "%d gols" % int(e[3]), comp_name(world, String(e[4])), cn], "k": "goal"})
			"tgoal":
				ev.append({"y": int(e[0]), "t": "Gol do título da %s de %d pelo %s" % [comp_name(world, String(e[4])), int(e[0]), cn], "k": "goal"})
			"crec":
				ev.append({"y": int(e[0]), "t": "Tornou-se o maior artilheiro da história do %s (%d gols)" % [cn, int(e[3])], "k": "record"})
			"face":
				ev.append({"y": int(e[0]), "t": "Como técnico do %s, enfrentou pela primeira vez o %s" % [_club_name(world, int(e[4])), cn], "k": "coach"})
	# Braçadeira
	for c in captaincy(world, p.id):
		var cn := _club_name(world, int(c[0]))
		var y0 := int(c[1])
		var y1 := int(c[2])
		var text := ("Capitão do %s em %d" % [cn, y0]) if y0 == y1 else ("Capitão do %s entre %d e %d" % [cn, y0, y1])
		ev.append({"y": y0, "t": text, "k": "captain"})
	if p.retiring:
		ev.append({"y": world.year, "t": "Aposentadoria anunciada para o fim da temporada", "k": "retire"})
	ev.sort_custom(func(a, b): return int(a["y"]) < int(b["y"]) if a["y"] != b["y"] else _order(a["k"]) < _order(b["k"]))
	# Fatos: idade, clubes, gols, títulos, recordes e maior rival
	var main := _main_club(p.spells)
	if main >= 0:
		var rank := scorer_rank(world, main, p.id)
		var mc := world.club(main)
		var g := 0
		for s in p.spells:
			if int(s.get("c", -1)) == main:
				g += int(s.get("g", 0))
		if rank == 1:
			facts.append("Maior artilheiro da história do %s: %d gols" % [mc.short_name, g])
		elif rank > 1:
			facts.append("%dº maior artilheiro da história do %s (%d gols)" % [rank, mc.short_name, g])
		var rv := mc.main_rival()
		if rv >= 0:
			facts.append("Maior rival: %s" % _club_name(world, rv))
	facts.push_front("%d jogos · %d gols · %d títulos na carreira" % [p.career_apps, p.career_goals, p.titles])
	return {"facts": facts, "events": ev}


static func _order(k: String) -> int:
	return ["debut", "move", "captain", "goal", "title", "award", "record", "coach", "retire"].find(k)


static func _award_where(world: GameWorld, l: String) -> String:
	if l == "":
		return ""
	if DatabaseManager.has_league(l):
		return " (%s)" % world.league_short(l)
	return " (%s)" % CupManager.cup_short(l) if CupManager.cfg(l).size() > 0 else ""
