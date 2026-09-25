class_name CompText
extends RefCounted
## Textos de competição reutilizados pelas telas (título do jogo, nome curto, fase da copa).


## "Rodada 5 de 38 · Série A", "Libertadores · Grupo C · 2ª rodada" ou "Campeões · Semifinal (volta)".
static func fixture_title(w: GameWorld, f: Fixture) -> String:
	if f.is_league():
		var league := w.league(f.comp)
		return "Rodada %d de %d · %s" % [f.round + 1, league.rounds.size() if league != null else 0, w.league_short(f.comp)]
	var pl := w.league(f.comp)
	if pl != null:
		return "%s · %s" % [pl.short_name, LeagueFormat.round_label(pl, f)]
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


## Logo desenhado de uma competição (formato do CrestView): o de identity.json, ou um selo gerado
## com as cores oficiais e as iniciais.
static func logo(comp: String) -> Dictionary:
	var logos: Dictionary = DatabaseManager.get_data("identity").get("logos", {})
	if logos.has(comp):
		return logos[comp]
	var cols := colors(comp)
	var name := ""
	if DatabaseManager.has_league(comp):
		name = String(DatabaseManager.league_cfg(comp).get("short", comp))
	else:
		name = String(DatabaseManager.cup_cfg(comp).get("short", comp))
	var ini := ""
	for part in name.replace(".", " ").split(" ", false):
		if ini.length() < 2 and part.length() > 0 and part[0] == part[0].to_upper():
			ini += part[0]
	if ini == "":
		ini = name.substr(0, 2).to_upper()
	var h := absi(hash(comp))
	var shapes := ["round", "shield", "round", "heater"]
	var cup := not DatabaseManager.has_league(comp)
	return {"shape": shapes[h % shapes.size()], "field": "plain", "c1": cols[0].to_html(false), "c2": cols[1].to_html(false),
		"symbol": "ball" if cup and h % 3 == 0 else ("star" if cup else "letter"), "initials": ini, "sc": cols[1].to_html(false),
		"border": "gold" if cup else "thin"}


## Cores [principal, destaque] de uma liga ou copa (já com as personalizações do editor).
static func colors(comp: String) -> Array[Color]:
	var cfg: Dictionary = DatabaseManager.league_cfg(comp) if DatabaseManager.has_league(comp) else DatabaseManager.cup_cfg(comp)
	var hex: Array = cfg.get("colors", [])
	if hex.size() < 2:
		return [UIColors.ACCENT, UIColors.ON_ACCENT]
	return [Color(String(hex[0])), Color(String(hex[1]))]


## Jogos da mesma competição e fase disputados na mesma data do jogo `f` (o "resto da rodada").
static func sibling_fixtures(w: GameWorld, f: Fixture) -> Array:
	var out: Array = []
	if f.is_league():
		var league := w.league(f.comp)
		if league != null:
			return league.fixtures_of_round(f.round)
		return out
	var pl := w.league(f.comp)
	if pl != null:
		for r in pl.rounds:
			if r.has(f):
				return r
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
	var da := "do" if CupManager.is_state(String(ev.get("cup", ""))) and not cup_name.begins_with("Copa") else "da"
	var club := int(ev.get("club", -1))
	match String(ev.get("t", "")):
		"champion":
			if w.is_user_club(club):
				return "CAMPEÃO %s %s!" % [da, cup_name]
			return "%s é o campeão %s %s." % [w.club(club).short_name, da, cup_name]
		"advance":
			if w.is_user_club(club):
				return "Classificado! Seu time passou da %s %s %s." % [String(ev.get("stage", "")).to_lower(), "no" if da == "do" else "na", cup_name]
		"out":
			if w.is_user_club(club):
				return "Eliminado na %s %s %s." % [String(ev.get("stage", "")).to_lower(), da, cup_name]
		"cwc":
			if ev.get("clubs", []).has(w.user_club_id):
				return "Seu time está no Mundial de Clubes!"
	return ""
