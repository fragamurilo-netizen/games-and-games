class_name CompText
extends RefCounted
## Textos de competição reutilizados pelas telas (título do jogo, nome curto, fase da copa).


## "Rodada 5 de 38 · Brasil A", "Libertadores · Grupo C · 2ª rodada" ou "Campeões · Semifinal (volta)".
static func fixture_title(w: GameWorld, f: Fixture) -> String:
	if f.is_league():
		var league := w.league(f.comp)
		return "Rodada %d de %d · %s" % [f.round + 1, league.rounds.size() if league != null else 0, w.league_short(f.comp)]
	var cup: Cup = w.season.cups.get(f.comp, null) if w.season != null else null
	if cup == null:
		return CupManager.cup_short(f.comp)
	if f.stage == Fixture.STAGE_GROUP:
		return "%s · Grupo %s · %dª rodada" % [cup.short_name, cup.group_of(f.home).get("n", "?"), f.round + 1]
	var stage: String = cup.round_names[f.round] if f.round < cup.round_names.size() else ""
	if f.neutral:
		return "%s · %s" % [cup.short_name, stage]
	return "%s · %s (%s)" % [cup.short_name, stage, "ida" if f.leg == 0 else "volta"]


## Nome curto de uma competição (liga ou copa).
static func comp_short(w: GameWorld, comp: String) -> String:
	if DatabaseManager.has_league(comp):
		return w.league_short(comp)
	return CupManager.cup_short(comp)


## Jogos da mesma competição e fase disputados na mesma data do jogo `f` (o "resto da rodada").
static func sibling_fixtures(w: GameWorld, f: Fixture) -> Array:
	var out: Array = []
	if f.is_league():
		var league := w.league(f.comp)
		if league != null:
			return league.fixtures_of_round(f.round)
		return out
	var cup: Cup = w.season.cups.get(f.comp, null)
	if cup == null:
		return out
	for g in cup.fixtures:
		if g.slot == f.slot and g.stage == f.stage:
			out.append(g)
	return out


## Texto de um evento de copa do relatório para o usuário (ou "" se não for sobre ele).
static func cup_event_text(w: GameWorld, ev: Dictionary) -> String:
	var cup_name := CupManager.cup_name(String(ev.get("cup", "")))
	var club := int(ev.get("club", -1))
	match String(ev.get("t", "")):
		"champion":
			if w.is_user_club(club):
				return "CAMPEÃO da %s!" % cup_name
			return "%s é o campeão da %s." % [w.club(club).short_name, cup_name]
		"advance":
			if w.is_user_club(club):
				return "Classificado! Seu time passou da %s na %s." % [String(ev.get("stage", "")).to_lower(), cup_name]
		"out":
			if w.is_user_club(club):
				return "Eliminado na %s da %s." % [String(ev.get("stage", "")).to_lower(), cup_name]
		"cwc":
			if ev.get("clubs", []).has(w.user_club_id):
				return "Seu time está no Mundial de Clubes!"
	return ""
