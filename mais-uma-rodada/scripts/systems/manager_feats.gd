class_name ManagerFeats
extends RefCounted
## Feitos do treinador do usuário: o que acontece em campo vira prestígio, reputação, confiança da
## diretoria, apoio da torcida e moral do elenco — e o jogo mostra na hora quanto cada coisa rendeu.
##
## Cada jogo rende prestígio (vitória, empate) e pode render feitos (zebra, virada, clássico,
## derrubar o líder, gol no fim, mata-mata...). Sequências (invencibilidade, vitórias seguidas,
## jogos sem sofrer gol) contam pela carreira no clube e premiam nas marcas redondas. Jogos que
## valem mais (clássico, mata-mata, final, reta final) multiplicam tudo.
## O prestígio acumulado sobe o nível do treinador; cada nível novo é festejado pela diretoria e
## pela torcida.
##
## Tudo em world.manager["ft"]:
##   xp    prestígio acumulado
##   n     {feito: vezes}
##   log   últimos feitos [{y, t, id, xp}]
##   st    sequências em andamento {c (clube), u, w, cs, wc (vitórias no clube)}
##   best  melhores sequências da carreira {u, w, cs}
##   ms    marcos já alcançados {chave: ano}

const LOG_MAX := 40

## name, xp, rep (reputação do treinador), board, fans, mor (moral do elenco)
const FEATS := {
	"zebra": {"name": "Zebra!", "xp": 40, "rep": 0.8, "board": 3.0, "fans": 4.0, "mor": 3.0},
	"zebra_e": {"name": "Empate com gosto de vitória", "xp": 15, "rep": 0.3, "board": 1.0, "fans": 1.5, "mor": 1.0},
	"virada": {"name": "Virada", "xp": 25, "rep": 0.3, "board": 1.0, "fans": 3.0, "mor": 3.0},
	"goleada": {"name": "Goleada", "xp": 20, "rep": 0.3, "board": 1.0, "fans": 2.5, "mor": 2.0},
	"classico": {"name": "Clássico é nosso", "xp": 30, "rep": 0.6, "board": 3.0, "fans": 5.0, "mor": 2.0},
	"lider": {"name": "Derrubou o líder", "xp": 30, "rep": 0.8, "board": 2.0, "fans": 3.0, "mor": 2.0},
	"apagar": {"name": "No apagar das luzes", "xp": 20, "rep": 0.2, "board": 0.5, "fans": 3.0, "mor": 2.0},
	"mata": {"name": "Classificado no mata-mata", "xp": 30, "rep": 0.6, "board": 2.0, "fans": 3.0, "mor": 2.0},
	"final": {"name": "Final vencida", "xp": 120, "rep": 1.5, "board": 6.0, "fans": 8.0, "mor": 5.0},
	"freguesia": {"name": "Fim da freguesia", "xp": 30, "rep": 0.5, "board": 1.0, "fans": 2.0, "mor": 1.0},
	"estreia": {"name": "Primeira vitória no clube", "xp": 15, "rep": 0.2, "board": 2.0, "fans": 2.0, "mor": 1.0},
	"invicto": {"name": "Invencibilidade", "xp": 0, "rep": 0.0, "board": 0.0, "fans": 0.0, "mor": 0.0},
	"vitorias": {"name": "Vitórias seguidas", "xp": 0, "rep": 0.0, "board": 0.0, "fans": 0.0, "mor": 0.0},
	"muralha": {"name": "Muralha", "xp": 0, "rep": 0.0, "board": 0.0, "fans": 0.0, "mor": 0.0},
	"recorde": {"name": "Recorde pessoal", "xp": 25, "rep": 0.3, "board": 1.0, "fans": 1.0, "mor": 1.0},
	"marco": {"name": "Marco da carreira", "xp": 0, "rep": 0.0, "board": 0.0, "fans": 0.0, "mor": 0.0},
}
const UNBEATEN_AT: Array[int] = [5, 10, 15, 20, 30, 40]
const WINS_AT: Array[int] = [3, 5, 7, 10, 15]
const CLEAN_AT: Array[int] = [3, 5, 8]
const GAMES_AT: Array[int] = [50, 100, 150, 200, 300, 400, 500, 750, 1000]
const WINS_TOTAL_AT: Array[int] = [25, 50, 100, 150, 200, 300, 400, 500]
const LEVEL_NAMES := [[1, "Estreante"], [5, "Promissor"], [10, "Respeitado"], [15, "Consagrado"], [22, "Referência"], [30, "Lenda"]]


static func data(world: GameWorld) -> Dictionary:
	if not world.manager.has("ft"):
		world.manager["ft"] = {"xp": 0, "n": {}, "log": [], "st": {"c": -1, "u": 0, "w": 0, "cs": 0, "wc": 0}, "best": {"u": 0, "w": 0, "cs": 0}, "ms": {}}
	return world.manager["ft"]


# ---------------------------------------------------------------------------
# Nível
# ---------------------------------------------------------------------------

## Prestígio para ir do nível `lv` ao seguinte.
static func need(lv: int) -> int:
	return 80 + 40 * lv


## [nível, prestígio dentro do nível, prestígio para o próximo]
static func level_of(xp: int) -> Array:
	var lv := 1
	var rest := xp
	while rest >= need(lv):
		rest -= need(lv)
		lv += 1
	return [lv, rest, need(lv)]


static func level_name(lv: int) -> String:
	var out := ""
	for e in LEVEL_NAMES:
		if lv >= int(e[0]):
			out = String(e[1])
	return out


static func level(world: GameWorld) -> Array:
	return level_of(int(data(world)["xp"]))


# ---------------------------------------------------------------------------
# Depois de cada jogo do usuário
# ---------------------------------------------------------------------------

## Retorna {feats: [{id, name, text, xp, rew}], xp, weight, why, lv0, lv1, up, streak}
static func on_user_match(world: GameWorld, entry: Dictionary, result: String) -> Dictionary:
	if not world.has_user() or entry.is_empty():
		return {}
	var d := data(world)
	var club := world.user_club()
	var f: Fixture = entry["f"]
	var side := 0 if f.home == club.id else 1
	var mine := f.hg if side == 0 else f.ag
	var theirs := f.ag if side == 0 else f.hg
	var opp := world.club(f.opponent_of(club.id))
	var st: Dictionary = d["st"]
	var fresh := int(st.get("c", -1)) != club.id
	if fresh:
		st.merge({"c": club.id, "u": 0, "w": 0, "cs": 0, "wc": 0}, true)
	var out: Array = []
	var gain := 10 if result == "V" else (3 if result == "E" else 0)
	# Peso do jogo
	var weight := 1.0
	var why: Array = []
	var derby := MatchEngine.is_derby(world, f.home, f.away)
	var kind := FootballMemory._kind_of(world, f)
	var tie_w := FootballMemory._tie_winner(world, f) if kind == FootballMemory.K_KO or kind == FootballMemory.K_FINAL else -1
	if derby:
		weight += 0.5
		why.append("clássico")
	if kind == FootballMemory.K_FINAL:
		weight += 1.0
		why.append("final")
	elif kind == FootballMemory.K_KO:
		weight += 0.3
		why.append("mata-mata")
	var league := world.league_of(club.id)
	if f.is_league() and league != null:
		var left := CompetitionManager.remaining_rounds(league, club.id)
		var pos := CompetitionManager.position_of(league, club.id)
		var cfg := league.cfg()
		var teams := league.club_ids.size()
		var tight := pos <= maxi(2, int(cfg.get("up", 0)) + 1) or (int(cfg.get("down", 0)) > 0 and pos >= teams - int(cfg.get("down", 0)) - 1)
		if left <= 5 and tight:
			weight += 0.4
			why.append("reta final")
	# Feitos do jogo
	var ogap := opp.reputation - club.reputation
	if result == "V" and ogap >= 10.0:
		out.append(_feat("zebra", "Vitória sobre o %s, bem mais forte no papel." % opp.short_name))
	elif result == "E" and ogap >= 14.0:
		out.append(_feat("zebra_e", "Empate com o %s, muito mais forte no papel." % opp.short_name))
	if result == "V" and _was_behind(f, side):
		out.append(_feat("virada", "Saiu atrás e virou contra o %s." % opp.short_name))
	if result == "V" and mine - theirs >= 4:
		out.append(_feat("goleada", "%d a %d no %s." % [mine, theirs, opp.short_name]))
	if result == "V" and derby:
		out.append(_feat("classico", "Vitória no clássico contra o %s." % opp.short_name))
	if result == "V" and f.is_league() and league != null and CompetitionManager.position_of(league, opp.id) == 1 and league.rounds_played() >= 5:
		out.append(_feat("lider", "Venceu o %s, líder da divisão." % opp.short_name))
	if result == "V" and mine - theirs == 1 and _late_winner(f, side):
		out.append(_feat("apagar", "Gol da vitória nos minutos finais."))
	if tie_w == club.id:
		if kind == FootballMemory.K_FINAL:
			out.append(_feat("final", "Campeão contra o %s!" % opp.short_name))
		else:
			out.append(_feat("mata", "Passou pelo %s." % opp.short_name))
	var oc := People.coach_of(world, opp.id)
	if result == "V" and not oc.is_empty():
		var vs := CoachStories.vs_user(oc)
		if int(vs[0]) == 0 and int(vs[2]) >= 3:
			out.append(_feat("freguesia", "Primeira vitória sobre %s depois de %d derrotas." % [String(oc["n"]), int(vs[2])]))
	if result == "V":
		st["wc"] = int(st.get("wc", 0)) + 1
		if int(st["wc"]) == 1 and int(world.manager_stats.get("games", 0)) > 1:
			out.append(_feat("estreia", "Primeira vitória no comando do %s." % club.short_name))
	# Peso aplicado aos feitos do jogo
	for ft: Dictionary in out:
		ft["xp"] = int(round(float(ft["xp"]) * weight))
		for k in ["rep", "board", "fans", "mor"]:
			ft[k] = float(ft[k]) * weight
	gain = int(round(gain * weight))
	# Sequências
	st["u"] = int(st["u"]) + 1 if result != "D" else 0
	st["w"] = int(st["w"]) + 1 if result == "V" else 0
	st["cs"] = int(st["cs"]) + 1 if theirs == 0 else 0
	if UNBEATEN_AT.has(int(st["u"])):
		var n := int(st["u"])
		var ft2 := _streak_feat("invicto", "%d jogos sem perder." % n, n * 4, n * 0.06, n * 0.4, n * 0.3, 2.0)
		if n >= 10:
			var bonus := Valuation.round_value(maxf(50000.0, club.wage_budget * (n / 10.0) * 0.5))
			BoardBudget.grant(world,club,bonus,"Premiação autorizada","manager_feats:"+str(world.current_turn()))
			ft2["cash"] = bonus
		out.append(ft2)
	if WINS_AT.has(int(st["w"])):
		var n2 := int(st["w"])
		out.append(_streak_feat("vitorias", "%d vitórias seguidas." % n2, n2 * 6, n2 * 0.1, n2 * 0.5, n2 * 0.5, 2.0))
	if CLEAN_AT.has(int(st["cs"])):
		var n3 := int(st["cs"])
		out.append(_streak_feat("muralha", "%d jogos seguidos sem sofrer gol." % n3, n3 * 6, n3 * 0.05, n3 * 0.3, n3 * 0.3, 1.5))
	var best: Dictionary = d["best"]
	for k2 in ["u", "w"]:
		if int(st[k2]) > int(best.get(k2, 0)):
			if int(st[k2]) == int(best.get(k2, 0)) + 1 and int(best.get(k2, 0)) >= 5:
				out.append(_feat("recorde", ("Nova maior invencibilidade da carreira: %d jogos." if k2 == "u" else "Nova maior sequência de vitórias da carreira: %d.") % int(st[k2])))
			best[k2] = int(st[k2])
	best["cs"] = maxi(int(best.get("cs", 0)), int(st["cs"]))
	# Marcos da carreira
	var ms: Dictionary = d["ms"]
	var games := int(world.manager_stats.get("games", 0))
	var wins := int(world.manager_stats.get("w", 0))
	if GAMES_AT.has(games) and not ms.has("g%d" % games):
		ms["g%d" % games] = world.year
		out.append(_streak_feat("marco", "%d jogos como treinador." % games, games / 5, 0.5, 2.0, 1.0, 0.0))
	if result == "V" and WINS_TOTAL_AT.has(wins) and not ms.has("w%d" % wins):
		ms["w%d" % wins] = world.year
		out.append(_streak_feat("marco", "%dª vitória da carreira." % wins, wins / 3, 0.5, 2.0, 1.5, 0.0))
	# Recompensas
	var lv0 := int(level(world)[0])
	var total := gain
	for ft: Dictionary in out:
		total += int(ft["xp"])
		_apply(world, club, ft)
		d["n"][String(ft["id"])] = int(d["n"].get(String(ft["id"]), 0)) + 1
		_log(world, ft)
	d["xp"] = int(d["xp"]) + total
	var lv1 := int(level(world)[0])
	if lv1 > lv0:
		_level_up(world, club, lv0, lv1)
	return {"feats": out, "xp": total, "base": gain, "weight": weight, "why": ", ".join(why), "lv0": lv0, "lv1": lv1, "up": lv1 > lv0,
		"streak": _streak_line(world)}


static func _feat(id: String, text: String) -> Dictionary:
	var fd: Dictionary = FEATS[id]
	return {"id": id, "name": String(fd["name"]), "text": text, "xp": int(fd["xp"]), "rep": float(fd["rep"]), "board": float(fd["board"]),
		"fans": float(fd["fans"]), "mor": float(fd["mor"])}


static func _streak_feat(id: String, text: String, xp: int, rep: float, board: float, fans: float, mor: float) -> Dictionary:
	return {"id": id, "name": String(FEATS[id]["name"]), "text": text, "xp": xp, "rep": rep, "board": board, "fans": fans, "mor": mor}


static func _gkey(g: Array) -> int:
	return (int(g[4]) if g.size() > 4 else (1 if int(g[0]) <= 45 else 2)) * 1000 + int(g[0])


static func _was_behind(f: Fixture, side: int) -> bool:
	var goals: Array = f.goals.duplicate()
	goals.sort_custom(func(a, b): return _gkey(a) < _gkey(b))
	var m := 0
	var t := 0
	for g in goals:
		if int(g[1]) == side:
			m += 1
		else:
			t += 1
		if t > m:
			return true
	return false


## O gol da vitória (o último do jogo, com o placar empatado antes) saiu a partir dos 88 minutos.
static func _late_winner(f: Fixture, side: int) -> bool:
	if f.extra_time or f.goals.is_empty():
		return false
	var last: Array = f.goals[0]
	for g in f.goals:
		if _gkey(g) >= _gkey(last):
			last = g
	return int(last[1]) == side and int(last[0]) >= 88


static func _apply(world: GameWorld, club: Club, ft: Dictionary) -> void:
	var pp := People.data(world)
	var rep := float(ft.get("rep", 0.0))
	if rep != 0.0:
		pp["mrep"] = clampf(People.manager_rep(world) + rep, 5.0, 99.0)
	var board := float(ft.get("board", 0.0))
	if board != 0.0:
		club.board_confidence = clampf(club.board_confidence + board, 0.0, 100.0)
	var fans := float(ft.get("fans", 0.0))
	if fans != 0.0:
		People.add_support(world, fans)
	var mor := float(ft.get("mor", 0.0))
	if mor != 0.0:
		for p: Player in world.squad(club):
			p.morale = clampf(p.morale + mor, 0.0, 100.0)
	var parts: Array = []
	if rep >= 0.05:
		parts.append("+%s reputação" % String.num(rep, 1))
	if board >= 0.5:
		parts.append("+%d diretoria" % int(round(board)))
	if fans >= 0.5:
		parts.append("+%d torcida" % int(round(fans)))
	if mor >= 0.5:
		parts.append("+%d moral" % int(round(mor)))
	if int(ft.get("cash", 0)) > 0:
		parts.append("+%s para reforços" % Fmt.money(int(ft["cash"])))
	ft["rew"] = " · ".join(parts)


static func _log(world: GameWorld, ft: Dictionary) -> void:
	var lg: Array = data(world)["log"]
	lg.append({"y": world.year, "t": "%s: %s" % [String(ft["name"]), String(ft["text"])], "id": String(ft["id"]), "xp": int(ft["xp"])})
	while lg.size() > LOG_MAX:
		lg.pop_front()


static func _level_up(world: GameWorld, club: Club, lv0: int, lv1: int) -> void:
	club.board_confidence = clampf(club.board_confidence + 3.0, 0.0, 100.0)
	People.add_support(world, 3.0)
	var pp := People.data(world)
	pp["mrep"] = clampf(People.manager_rep(world) + 0.5 * (lv1 - lv0), 5.0, 99.0)
	var n0 := level_name(lv0)
	var n1 := level_name(lv1)
	if n0 != n1:
		NewsManager.post_raw(world, "%s agora é um treinador %s" % [world.manager_name, n1.to_lower()],
			"Os resultados colocaram %s em outro patamar: nível %d de prestígio. Diretoria e torcida sentem a diferença." % [world.manager_name, lv1],
			club.id, -1, NewsEvent.IMP_HIGH, "tecnicos")


static func _streak_line(world: GameWorld) -> String:
	var st: Dictionary = data(world)["st"]
	var u := int(st.get("u", 0))
	var w := int(st.get("w", 0))
	if w >= 2:
		var nxt := _next_mark(WINS_AT, w)
		return "%d vitórias seguidas" % w + (" · mais %d para %d" % [nxt - w, nxt] if nxt > 0 else "")
	if u >= 3:
		var nxt2 := _next_mark(UNBEATEN_AT, u)
		return "Invicto há %d jogos" % u + (" · mais %d para %d" % [nxt2 - u, nxt2] if nxt2 > 0 else "")
	return ""


static func _next_mark(marks: Array[int], v: int) -> int:
	for m in marks:
		if m > v:
			return m
	return 0


# ---------------------------------------------------------------------------
# Próximo jogo e fim de temporada
# ---------------------------------------------------------------------------

## Ganchos para o próximo jogo (formato de StoryHooks).
static func next_hooks(world: GameWorld, opp: Club) -> Array:
	var out: Array = []
	var d := data(world)
	var st: Dictionary = d["st"]
	if int(st.get("c", -1)) == world.user_club_id:
		var u := int(st.get("u", 0))
		var w := int(st.get("w", 0))
		var nu := _next_mark(UNBEATEN_AT, u)
		var nw := _next_mark(WINS_AT, w)
		if w >= 2 and nw == w + 1:
			out.append({"text": "Vença e chegue a %d vitórias seguidas" % nw, "kind": "streak", "priority": 72})
		elif u >= 4 and nu == u + 1:
			out.append({"text": "Não perca e complete %d jogos de invencibilidade" % nu, "kind": "streak", "priority": 70})
		var best_u := int(d["best"].get("u", 0))
		if u >= 5 and u == best_u:
			out.append({"text": "Mais um jogo sem perder e você bate seu recorde (%d)" % best_u, "kind": "streak", "priority": 74})
	var games := int(world.manager_stats.get("games", 0))
	var ng := _next_mark(GAMES_AT, games)
	if ng == games + 1:
		out.append({"text": "Seu %dº jogo como treinador" % ng, "kind": "season", "priority": 66})
	var oc := People.coach_of(world, opp.id)
	if not oc.is_empty():
		var vs := CoachStories.vs_user(oc)
		var nm := String(oc["n"])
		if int(vs[2]) >= 3 and int(vs[0]) == 0:
			out.append({"text": "%s nunca perdeu para você (%dV %dE dele)" % [nm, int(vs[2]), int(vs[1])], "kind": "derby", "priority": 78})
		elif int(vs[0]) >= 3 and int(vs[2]) == 0:
			out.append({"text": "Freguês: %s nunca venceu você (%d derrotas)" % [nm, int(vs[0])], "kind": "derby", "priority": 58})
		else:
			var nick := CoachStories.nickname(world, oc)
			var arc := CoachStories.arc_text(oc)
			if arc != "":
				out.append({"text": "No banco rival, %s: %s" % [nm, arc.to_lower()], "kind": "derby", "priority": 52})
			elif nick != "":
				out.append({"text": "No banco rival, %s, \"%s\"" % [nm, nick], "kind": "derby", "priority": 48})
	return out


## Fim da temporada: campanha vira prestígio. Retorna {xp, lv0, lv1, lines}.
static func on_season_end(world: GameWorld, u: Dictionary) -> Dictionary:
	var d := data(world)
	var lines: Array = []
	var xp := 0
	if bool(u.get("champion", false)):
		xp += 300
		lines.append("Título da liga +300")
	elif bool(u.get("promoted", false)):
		xp += 200
		lines.append("Acesso +200")
	elif bool(u.get("goal_met", false)):
		xp += 100
		lines.append("Meta cumprida +100")
	for cu in u.get("cups", []):
		if bool(cu.get("champion", false)):
			xp += 150
			lines.append("%s +150" % String(cu.get("name", "Copa")))
	if xp == 0:
		return {}
	var lv0 := int(level(world)[0])
	d["xp"] = int(d["xp"]) + xp
	var lv1 := int(level(world)[0])
	if lv1 > lv0 and world.has_user():
		_level_up(world, world.user_club(), lv0, lv1)
	return {"xp": xp, "lv0": lv0, "lv1": lv1, "lines": lines}
