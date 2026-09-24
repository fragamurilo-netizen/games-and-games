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


static func _in_user_league(world: GameWorld, club_id: int) -> bool:
	if not world.has_user():
		return false
	var c := world.club(club_id)
	return c != null and c.league_id == world.user_league_id()


static func _pname(p: Player) -> String:
	return p.display_name()


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Gera manchetes a partir dos jogos da data. results: Array de entradas {f: Fixture, res: resultado comum}.
static func after_matchday(world: GameWorld, results: Array) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	var lid := user.league_id
	var league: League = world.league(lid)
	if league == null:
		return
	var ids := CompetitionManager.sorted_ids(league)
	var posted := 0
	var league_day := false
	for r in results:
		var f: Fixture = r["f"]
		var res: Dictionary = r["res"]
		if f.comp == lid:
			league_day = true
		if (f.comp != lid and not f.involves(user.id)) or posted >= 3:
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
		if diff != 0 and f.comp == lid:
			var pw := ids.find(winner.id) + 1
			var pl := ids.find(loser.id) + 1
			if pw - pl >= 10 and pl <= 4:
				data["pos_w"] = pw
				data["pos_l"] = pl
				post(world, "zebra", data, winner.id, -1, imp)
				posted += 1
		# Hat-trick e primeiro gol (do usuário ou da liga)
		for side in 2:
			var club := world.club(f.home if side == 0 else f.away)
			var mine: int = f.hg if side == 0 else f.ag
			var theirs: int = f.ag if side == 0 else f.hg
			for ln in res["lines"][side]:
				var p: Player = ln[QuickMatch.L_P]
				var g: int = ln[QuickMatch.L_G]
				if g >= 3:
					var opp := world.club(f.opponent_of(club.id))
					post(world, "hattrick", {"player": _pname(p), "club": club.short_name, "shirt": p.shirt,
						"score": "%d x %d" % [mine, theirs], "opponent": opp.short_name}, club.id, p.id, imp)
				if g >= 1 and p.career_goals == g and p.age(world.year) <= 21 and club.id == user.id:
					post(world, "primeiro_gol", {"player": _pname(p), "age": p.age(world.year), "club": club.short_name}, club.id, p.id, NewsEvent.IMP_HIGH)
	if not league_day:
		return
	# Líder novo
	var leader: int = ids[0]
	var last_leader: int = int(world.stats.get("leader_" + lid, -1))
	if leader != last_leader and league.rounds_played() >= 3:
		var row: Dictionary = league.table[leader]
		post(world, "lider", {"club": world.club(leader).short_name, "division": league.name, "pts": row["pts"], "rounds": row["pl"]}, leader, -1,
			NewsEvent.IMP_HIGH if leader == user.id else NewsEvent.IMP_NORMAL)
	world.stats["leader_" + lid] = leader
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
	if league.rounds_played() % 5 == 4:
		var top := CompetitionManager.player_ranking(world, lid, Player.S_GOALS, 1)
		if not top.is_empty():
			var p: Player = top[0]
			post(world, "artilheiro", {"player": _pname(p), "n": p.stats[Player.S_GOALS], "club": world.club(p.club_id).short_name, "division": league.name}, p.club_id, p.id)


## Copas: classificação, eliminação e títulos do usuário; campeões continentais e mundial para todos.
static func on_cup_events(world: GameWorld, events: Array) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	for ev in events:
		var cup_name := CupManager.cup_name(String(ev["cup"]))
		match String(ev["t"]):
			"champion":
				var c := world.club(int(ev["club"]))
				var ru := world.club(int(ev.get("runner_up", -1)))
				var cat := "mundial_campeao" if ev["cup"] == CupManager.CWC else "copa_campeao"
				post(world, cat, {"club": c.short_name, "cup": cup_name, "runner_up": ru.short_name if ru != null else "", "year": world.year},
					c.id, -1, NewsEvent.IMP_HEADLINE if world.is_user_club(c.id) else NewsEvent.IMP_HIGH)
			"advance":
				if world.is_user_club(int(ev["club"])):
					var by := world.club(int(ev.get("by", -1)))
					post(world, "copa_avanca", {"club": user.short_name, "cup": cup_name, "stage": String(ev["stage"]).to_lower(),
						"opponent": by.short_name if by != null else ""}, user.id, -1, NewsEvent.IMP_HIGH)
			"out":
				if world.is_user_club(int(ev["club"])):
					var by := world.club(int(ev.get("by", -1)))
					post(world, "copa_eliminado", {"club": user.short_name, "cup": cup_name, "stage": String(ev["stage"]).to_lower(),
						"opponent": by.short_name if by != null else "os adversários"}, user.id, -1, NewsEvent.IMP_HIGH)
			"cwc":
				if ev["clubs"].has(user.id):
					post(world, "mundial_classificado", {"club": user.short_name}, user.id, -1, NewsEvent.IMP_HEADLINE)


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
	var in_div := (to != null and to.league_id == user.league_id) or (from != null and from.league_id == user.league_id)
	var big := t.fee >= 40_000_000
	if not involves_user and not (in_div and (t.fee >= Valuation.market_value_of_rating(PlayerGenerator.league_level(user)) or p.overall >= PlayerGenerator.league_level(user))) and not big:
		return
	var data := {"player": _pname(p), "to": to.short_name if to != null else "", "from": from.short_name if from != null else "",
		"fee": Fmt.money(t.fee), "age": t.age, "pos": Pos.name_of(p.position).to_lower()}
	var imp := NewsEvent.IMP_HIGH if involves_user else NewsEvent.IMP_NORMAL
	if world.is_user_club(t.from_id) and t.kind == Transfer.KIND_BUY:
		post(world, "venda_usuario", data, t.to_id, p.id, imp)
	elif from != null and to != null and (from.is_rival(t.to_id) or to.is_rival(t.from_id)) and t.kind == Transfer.KIND_BUY:
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
	post(world, "proposta_recebida", {"buyer": b.short_name, "fee": Fmt.money(o.fee), "player": _pname(p), "expires": o.expires_day - world.current_turn() + 1},
		b.id, p.id, NewsEvent.IMP_HIGH)


static func on_injury(world: GameWorld, p: Player) -> void:
	if not world.has_user() or p.injury_weeks < 4:
		return
	var c := world.club(p.club_id)
	if c == null:
		return
	if not world.is_user_club(c.id) and not (c.league_id == world.user_league_id() and p.overall >= PlayerGenerator.league_level(c) + 2.0):
		return
	post(world, "lesao_grave", {"player": _pname(p), "club": c.short_name, "weeks": p.injury_weeks, "injury": p.injury_name},
		c.id, p.id, NewsEvent.IMP_HIGH if world.is_user_club(c.id) else NewsEvent.IMP_NORMAL)


static func on_retirement_announced(world: GameWorld, p: Player) -> void:
	if not world.has_user():
		return
	var c := world.club(p.club_id)
	var notable := p.career_apps >= 250 or (c != null and world.is_user_club(c.id)) or (c != null and c.league_id == world.user_league_id() and p.overall >= PlayerGenerator.league_level(c))
	if not notable:
		return
	post(world, "aposentadoria_anuncio", {"player": _pname(p), "age": p.age(world.year), "apps": p.career_apps, "goals": p.career_goals},
		p.club_id, p.id, NewsEvent.IMP_HIGH if c != null and world.is_user_club(c.id) else NewsEvent.IMP_NORMAL)


static func on_explosion(world: GameWorld, p: Player) -> void:
	if not world.has_user() or p.club_id < 0:
		return
	var c := world.club(p.club_id)
	if not world.is_user_club(c.id) and c.league_id != world.user_league_id():
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
