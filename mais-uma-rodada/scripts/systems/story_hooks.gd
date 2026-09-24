class_name StoryHooks
extends RefCounted
## "Só mais uma rodada": ganchos que mostram o que está em jogo no próximo compromisso.
## Cada gancho: {text, kind (derby|table|streak|player|market|contract|season), priority}.


static func for_next_match(world: GameWorld) -> Array:
	var out: Array = []
	if not world.has_user() or world.season == null or world.season.finished:
		return out
	var user := world.user_club()
	var f := FixtureManager.next_fixture_for(world, user.id)
	if f == null:
		return out
	var opp := world.club(f.opponent_of(user.id))
	var league := world.league_of(user.id)
	var ids := CompetitionManager.sorted_ids(league)
	var my_pos := ids.find(user.id) + 1
	var opp_pos := ids.find(opp.id) + 1
	var cfg := DatabaseManager.division_config(user.division)
	var teams := ids.size()
	var remaining := CompetitionManager.remaining_rounds(league, user.id)
	var played: int = league.table[user.id]["pl"]
	# Clássico
	if MatchEngine.is_derby(world, user.id, opp.id):
		out.append({"text": "CLÁSSICO contra o %s" % opp.short_name, "kind": "derby", "priority": 100})
	# Tabela
	if played >= 3:
		if opp_pos == 1 and my_pos == 2 or my_pos == 1 and opp_pos == 2:
			out.append({"text": "Líder contra vice: vale a ponta da tabela", "kind": "table", "priority": 95})
		elif opp_pos == 1:
			out.append({"text": "Pedreira: o %s lidera a divisão" % opp.short_name, "kind": "table", "priority": 70})
		elif my_pos == 1:
			out.append({"text": "Defenda a liderança contra o %sº colocado" % opp_pos, "kind": "table", "priority": 60})
		var releg := int(cfg["relegated"])
		if releg > 0 and my_pos > teams - releg - 3 and opp_pos > teams - releg - 3:
			out.append({"text": "Confronto direto contra o rebaixamento", "kind": "table", "priority": 90})
		var promo := int(cfg["promoted"])
		if promo > 0 and my_pos <= promo + 3 and opp_pos <= promo + 3:
			out.append({"text": "Confronto direto pelo acesso", "kind": "table", "priority": 90})
	# Reta final
	if remaining > 0 and remaining <= 5:
		out.append(_season_math(world, league, ids, user, remaining))
	# Sequências
	if user.streak_wins >= 3:
		out.append({"text": "Embalado: %d vitórias seguidas" % user.streak_wins, "kind": "streak", "priority": 55})
	elif user.streak_winless >= 4:
		out.append({"text": "Pressão: %d jogos sem vencer" % user.streak_winless, "kind": "streak", "priority": 75})
	if opp.streak_wins >= 4:
		out.append({"text": "O %s venceu os últimos %d jogos" % [opp.short_name, opp.streak_wins], "kind": "streak", "priority": 50})
	# Jogadores
	for p in world.squad(user):
		if p.injury_weeks == 1:
			out.append({"text": "%s volta de lesão" % p.display_name(), "kind": "player", "priority": 45})
		var g: int = p.stats[Player.S_GOALS]
		if g in [9, 14, 19, 24, 29]:
			out.append({"text": "%s pode chegar a %d gols na temporada" % [p.display_name(), g + 1], "kind": "player", "priority": 40})
		if p.retiring:
			out.append({"text": "Últimos jogos de %s antes da aposentadoria" % p.display_name(), "kind": "player", "priority": 35})
	var threat := _top_scorer_of(world, opp)
	if threat != null and threat.stats[Player.S_GOALS] >= 5:
		out.append({"text": "Cuidado com %s: %d gols pelo %s" % [threat.display_name(), threat.stats[Player.S_GOALS], opp.short_name], "kind": "player", "priority": 38})
	# Mercado e contratos
	if world.transfer_window_open():
		var end := world.window_end_day()
		if end == world.season.day:
			out.append({"text": "Último dia da janela de transferências", "kind": "market", "priority": 65})
	else:
		var nxt := world.next_window_day()
		if nxt > 0 and nxt - world.season.day <= 2:
			out.append({"text": "A janela de transferências abre em %d rodada(s)" % (nxt - world.season.day), "kind": "market", "priority": 45})
	var expiring := 0
	for p in world.squad(user):
		if p.contract_end <= world.year:
			expiring += 1
	if expiring > 0 and world.season.day >= 20:
		out.append({"text": "%d contrato(s) terminam no fim da temporada" % expiring, "kind": "contract", "priority": 30 + world.season.day})
	var offers := TransferManager.pending_offers(world).size()
	if offers > 0:
		out.append({"text": "%d proposta(s) aguardando resposta" % offers, "kind": "market", "priority": 80})
	out.sort_custom(func(a, b): return a["priority"] > b["priority"])
	return out.slice(0, 4)


static func _top_scorer_of(world: GameWorld, c: Club) -> Player:
	var best: Player = null
	for p in world.squad(c):
		if best == null or p.stats[Player.S_GOALS] > best.stats[Player.S_GOALS]:
			best = p
	return best


static func _season_math(world: GameWorld, league: League, ids: Array, user: Club, remaining: int) -> Dictionary:
	var cfg := DatabaseManager.division_config(league.division)
	var my_pts: int = league.table[user.id]["pts"]
	var max_gain := remaining * 3
	var pos := ids.find(user.id) + 1
	if league.division == 0 or int(cfg["promoted"]) == 0:
		if pos == 1:
			var second: int = league.table[ids[1]]["pts"]
			if my_pts - second > (remaining - 1) * 3 and my_pts - second <= max_gain:
				return {"text": "Uma vitória pode garantir o TÍTULO!", "kind": "season", "priority": 99}
			return {"text": "Faltam %d rodadas: título em jogo" % remaining, "kind": "season", "priority": 85}
	if int(cfg["promoted"]) > 0:
		var cut := int(cfg["promoted"])
		var first_out: int = league.table[ids[cut]]["pts"]
		if pos <= cut and my_pts - first_out > (remaining - 1) * 3:
			return {"text": "Uma vitória pode garantir o ACESSO!", "kind": "season", "priority": 99}
		if pos <= cut + 3:
			return {"text": "Faltam %d rodadas: acesso em jogo" % remaining, "kind": "season", "priority": 85}
	if int(cfg["relegated"]) > 0:
		var safe_pos := ids.size() - int(cfg["relegated"])
		if pos > safe_pos - 3:
			return {"text": "Faltam %d rodadas: luta contra a queda" % remaining, "kind": "season", "priority": 88}
	return {"text": "Faltam %d rodadas para o fim da temporada" % remaining, "kind": "season", "priority": 20}
