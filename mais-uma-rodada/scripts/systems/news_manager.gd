class_name NewsManager
extends RefCounted
## Feed procedural: transforma o que aconteceu no save em manchetes.
## Foco no que importa para o usuário (seu clube e sua divisão) para não virar ruído.


static func _tpl(cat: String) -> Dictionary:
	return DatabaseManager.news_templates().get(cat, {"t": ["{title}"], "b": [""]})


static func _fill(text: String, data: Dictionary) -> String:
	var out := text
	for k in data:
		out = out.replace("{" + str(k) + "}", str(data[k]))
	return out


static func post(world: GameWorld, cat: String, data: Dictionary, club_id: int = -1, player_id: int = -1, imp: int = NewsEvent.IMP_NORMAL) -> NewsEvent:
	var t := _tpl(cat)
	var title := _fill(RngUtil.pick(world.rng, t["t"]), data)
	var body := _fill(RngUtil.pick(world.rng, t["b"]), data) if not t["b"].is_empty() else ""
	var n := NewsEvent.make(world.year, world.current_day(), cat, title, body, club_id, player_id, imp)
	world.add_news(n)
	return n


static func _involves_user_div(world: GameWorld, club_id: int) -> bool:
	if not world.has_user():
		return false
	var c := world.club(club_id)
	return c != null and c.division == world.user_club().division


static func _pname(p: Player) -> String:
	return p.display_name()


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Gera manchetes a partir dos jogos da rodada. results: Array de {f: Fixture, sim: MatchSimulation}.
static func after_matchday(world: GameWorld, results: Array) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	var div := user.division
	var league: League = world.season.leagues[div]
	var ids := CompetitionManager.sorted_ids(league)
	var posted := 0
	for r in results:
		var f: Fixture = r["f"]
		var sim: MatchSimulation = r["sim"]
		if f.division != div or posted >= 3:
			continue
		var home := world.club(f.home)
		var away := world.club(f.away)
		var diff := f.hg - f.ag
		var winner: Club = home if diff > 0 else away
		var loser: Club = away if diff > 0 else home
		var scorer := _top_scorer_name(world, f, winner.id)
		var data := {"winner": winner.short_name, "loser": loser.short_name, "home": home.short_name, "away": away.short_name,
			"score": "%d x %d" % [f.hg, f.ag] if diff >= 0 else "%d x %d" % [f.ag, f.hg], "scorer": scorer}
		var involves_user := f.involves(user.id)
		var imp := NewsEvent.IMP_HIGH if involves_user else NewsEvent.IMP_NORMAL
		if MatchEngine.is_derby(world, f.home, f.away):
			if diff == 0:
				data["score"] = "%d x %d" % [f.hg, f.ag]
				post(world, "classico_empate", data, home.id, -1, imp)
			else:
				post(world, "classico_vitoria", data, winner.id, -1, imp)
			posted += 1
			continue
		if absi(diff) >= 4:
			post(world, "goleada", data, winner.id, -1, imp)
			posted += 1
			continue
		if diff != 0:
			var pw := ids.find(winner.id) + 1
			var pl := ids.find(loser.id) + 1
			if pw - pl >= 10 and pl <= 4:
				data["pos_w"] = pw
				data["pos_l"] = pl
				post(world, "zebra", data, winner.id, -1, imp)
				posted += 1
		# Hat-trick e primeiro gol (do usuário ou da divisão)
		if sim != null:
			for t: MatchTeam in sim.teams:
				for mp: MatchPlayer in t.all:
					if mp.goals >= 3:
						var opp := world.club(f.opponent_of(t.club.id))
						post(world, "hattrick", {"player": _pname(mp.p), "club": t.club.short_name, "shirt": mp.p.shirt,
							"score": "%d x %d" % [sim.score[t.side], sim.score[1 - t.side]], "opponent": opp.short_name}, t.club.id, mp.p.id, imp)
					if mp.goals >= 1 and mp.p.career_goals == mp.goals and mp.p.age(world.year) <= 21 and t.club.id == user.id:
						post(world, "primeiro_gol", {"player": _pname(mp.p), "age": mp.p.age(world.year), "club": t.club.short_name}, t.club.id, mp.p.id, NewsEvent.IMP_HIGH)
	# Líder novo
	var leader: int = ids[0]
	var last_leader: int = int(world.stats.get("leader_%d" % div, -1))
	if leader != last_leader and world.season.day >= 3:
		var row: Dictionary = league.table[leader]
		post(world, "lider", {"club": world.club(leader).short_name, "division": world.division_name(div), "pts": row["pts"], "rounds": row["pl"]}, leader, -1,
			NewsEvent.IMP_HIGH if leader == user.id else NewsEvent.IMP_NORMAL)
	world.stats["leader_%d" % div] = leader
	# Sequências (uma notícia por tipo)
	var best_streak: Club = null
	var worst_streak: Club = null
	for cid in league.club_ids:
		var c := world.club(cid)
		if c.streak_wins >= 4 and (best_streak == null or c.streak_wins > best_streak.streak_wins):
			best_streak = c
		if c.streak_losses >= 4 and (worst_streak == null or c.streak_losses > worst_streak.streak_losses):
			worst_streak = c
	if best_streak != null and best_streak.streak_wins % 2 == 0:
		post(world, "sequencia_vitorias", {"club": best_streak.short_name, "n": best_streak.streak_wins}, best_streak.id)
	if worst_streak != null:
		post(world, "sequencia_derrotas", {"club": worst_streak.short_name, "n": worst_streak.streak_losses}, worst_streak.id, -1,
			NewsEvent.IMP_HIGH if worst_streak.id == user.id else NewsEvent.IMP_NORMAL)
	elif user.streak_winless >= 5 and user.streak_losses < 4:
		post(world, "sem_vencer", {"club": user.short_name, "n": user.streak_winless}, user.id, -1, NewsEvent.IMP_HIGH)
	# Artilharia a cada 5 rodadas
	if world.season.day % 5 == 4:
		var top := CompetitionManager.player_ranking(world, div, Player.S_GOALS, 1)
		if not top.is_empty():
			var p: Player = top[0]
			post(world, "artilheiro", {"player": _pname(p), "n": p.stats[Player.S_GOALS], "club": world.club(p.club_id).short_name, "division": world.division_name(div)}, p.club_id, p.id)


static func _top_scorer_name(world: GameWorld, f: Fixture, club_id: int) -> String:
	var counts := {}
	var side := 0 if f.home == club_id else 1
	for g in f.goals:
		if int(g[1]) == side and int(g[3]) != Fixture.GOAL_OWN:
			counts[int(g[2])] = int(counts.get(int(g[2]), 0)) + 1
	var best := -1
	var best_n := 0
	for pid in counts:
		if counts[pid] > best_n:
			best_n = counts[pid]
			best = pid
	var p := world.player(best)
	return p.display_name() if p != null else "o time"


# ---------------------------------------------------------------------------
# Eventos pontuais
# ---------------------------------------------------------------------------

static func on_transfer(world: GameWorld, t: Transfer) -> void:
	if not world.has_user():
		return
	var p := world.player(t.player_id)
	if p == null:
		return
	var to := world.club(t.to_id)
	var from := world.club(t.from_id) if t.from_id >= 0 else null
	var user := world.user_club()
	var involves_user := world.is_user_club(t.to_id) or world.is_user_club(t.from_id)
	var in_div := (to != null and to.division == user.division) or (from != null and from.division == user.division)
	var big := t.fee >= 1_500_000
	if not involves_user and not (in_div and (t.fee >= 150_000 or p.overall >= 60)) and not big:
		return
	var data := {"player": _pname(p), "to": to.short_name if to != null else "", "from": from.short_name if from != null else "",
		"fee": Fmt.money(t.fee), "age": t.age, "pos": Pos.name_of(p.position).to_lower()}
	var imp := NewsEvent.IMP_HIGH if involves_user else NewsEvent.IMP_NORMAL
	if world.is_user_club(t.from_id) and t.kind == Transfer.KIND_BUY:
		post(world, "venda_usuario", data, t.to_id, p.id, imp)
	elif from != null and (from.rival_id == t.to_id or to.rival_id == t.from_id) and t.kind == Transfer.KIND_BUY:
		post(world, "transferencia_rival", data, t.to_id, p.id, NewsEvent.IMP_HIGH)
	elif t.kind == Transfer.KIND_FREE:
		post(world, "transferencia_livre", data, t.to_id, p.id, imp)
	else:
		post(world, "transferencia", data, t.to_id, p.id, imp)


static func on_offer_received(world: GameWorld, o: TransferOffer) -> void:
	var p := world.player(o.player_id)
	var b := world.club(o.buyer_id)
	if p == null or b == null:
		return
	post(world, "proposta_recebida", {"buyer": b.short_name, "fee": Fmt.money(o.fee), "player": _pname(p), "expires": o.expires_day + 1},
		b.id, p.id, NewsEvent.IMP_HIGH)


static func on_injury(world: GameWorld, p: Player) -> void:
	if not world.has_user() or p.injury_weeks < 4:
		return
	var c := world.club(p.club_id)
	if c == null:
		return
	if not world.is_user_club(c.id) and not (c.division == world.user_club().division and p.overall >= 65):
		return
	post(world, "lesao_grave", {"player": _pname(p), "club": c.short_name, "weeks": p.injury_weeks, "injury": p.injury_name},
		c.id, p.id, NewsEvent.IMP_HIGH if world.is_user_club(c.id) else NewsEvent.IMP_NORMAL)


static func on_retirement_announced(world: GameWorld, p: Player) -> void:
	if not world.has_user():
		return
	var c := world.club(p.club_id)
	var notable := p.career_apps >= 250 or (c != null and world.is_user_club(c.id)) or (c != null and c.division == world.user_club().division and p.overall >= 62)
	if not notable:
		return
	post(world, "aposentadoria_anuncio", {"player": _pname(p), "age": p.age(world.year), "apps": p.career_apps, "goals": p.career_goals},
		p.club_id, p.id, NewsEvent.IMP_HIGH if c != null and world.is_user_club(c.id) else NewsEvent.IMP_NORMAL)


static func on_explosion(world: GameWorld, p: Player) -> void:
	if not world.has_user() or p.club_id < 0:
		return
	var c := world.club(p.club_id)
	if not world.is_user_club(c.id) and c.division != world.user_club().division:
		return
	post(world, "jovem_explode", {"player": _pname(p), "age": p.age(world.year), "club": c.short_name}, c.id, p.id,
		NewsEvent.IMP_HIGH if world.is_user_club(c.id) else NewsEvent.IMP_NORMAL)


static func on_goal_milestone(world: GameWorld, p: Player, n: int) -> void:
	var c := world.club(p.club_id)
	post(world, "marco_gols", {"player": _pname(p), "n": n, "club": c.short_name}, c.id, p.id, NewsEvent.IMP_HIGH)


static func on_window(world: GameWorld, opening: bool) -> void:
	if opening:
		post(world, "janela_abre", {"until": world.window_end_day() + 1}, -1, -1, NewsEvent.IMP_HIGH)
	else:
		post(world, "janela_fecha", {}, -1, -1, NewsEvent.IMP_NORMAL)
