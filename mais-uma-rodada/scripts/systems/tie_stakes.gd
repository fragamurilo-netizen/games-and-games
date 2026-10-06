class_name TieStakes
extends RefCounted
## O que estava em jogo num mata-mata: o jogo que decide o confronto (jogo único ou volta)
## vale pelo agregado e pela taça, não pelo placar do dia. Vencer a volta e perder o título no
## agregado é derrota para a torcida, a imprensa e a diretoria; perder a volta e levantar a taça é festa.


## {} quando o jogo não decide nada. Senão:
## {w, l (ids), agg: [gols do vencedor, gols do perdedor], pens: bool, two: bool (ida e volta),
##  final: bool, title: bool (vale taça), access: bool (acesso/repescagem), name (competição),
##  stage (nome da fase), weight (0..1, o tamanho do golpe), derby: bool}
static func of(world: GameWorld, f: Fixture) -> Dictionary:
	if f == null or not f.played or f.stage != Fixture.STAGE_KO or world.season == null:
		return {}
	var agg: Array = [0, 0]
	var out := {}
	var cup: Cup = world.season.cups.get(f.comp, null)
	var league := world.league(f.comp)
	if cup != null:
		if not CupManager.is_deciding_leg(world, f):
			return {}
		agg = CupManager.aggregate_before(world, f)
		var last := cup.round_names.size() - 1
		out["final"] = CupManager._round_key(cup, f.round) == "f"
		out["title"] = out["final"]
		out["access"] = false
		out["name"] = CupManager.cup_name(cup.id)
		out["stage"] = String(cup.round_names[clampi(f.round, 0, last)]) if last >= 0 else ""
	elif league != null:
		if not LeagueFormat.is_deciding_leg(world, f):
			return {}
		agg = LeagueFormat.aggregate_before(world, f)
		var ko: Array = LeagueFormat.cfg(league).get("ko", ["f"])
		var bar := f.round == LeagueFormat.BAR_R
		var fin := not bar and String(ko[clampi(f.round, 0, ko.size() - 1)]) == "f"
		var kind := LeagueFormat.kind(league)
		out["final"] = fin
		out["title"] = fin and kind == "playoff"
		out["access"] = bar or (fin and kind == "promo")
		out["name"] = league.name
		out["stage"] = "Repescagem" if bar else String(LeagueFormat.KO_NAMES.get(ko[clampi(f.round, 0, ko.size() - 1)], "Playoff"))
	else:
		return {}
	var th := int(agg[0]) + f.hg
	var ta := int(agg[1]) + f.ag
	var home_wins: bool
	if th != ta:
		home_wins = th > ta
	elif f.has_penalties():
		home_wins = f.pen_h > f.pen_a
	else:
		var hc := world.club(f.home)
		var ac := world.club(f.away)
		home_wins = hc != null and ac != null and hc.reputation >= ac.reputation
	out["w"] = f.home if home_wins else f.away
	out["l"] = f.away if home_wins else f.home
	out["agg"] = [th, ta] if home_wins else [ta, th]
	out["pens"] = th == ta and f.has_penalties()
	out["two"] = f.leg == 1
	out["derby"] = MatchEngine.is_derby(world, f.home, f.away)
	var wgt := 0.3
	if bool(out["title"]):
		wgt = 1.0
	elif bool(out["access"]):
		wgt = 0.85
	elif String(out["stage"]).begins_with("Semi"):
		wgt = 0.55
	if cup != null and CupManager.is_super(cup.id):
		wgt *= 0.6 # supercopa: taça, mas de um jogo só
	out["weight"] = wgt
	return out


## Resultado que vale para o clima depois do jogo: quem passa (ou levanta a taça) venceu;
## quem cai perdeu, seja qual for o placar do dia. Fora de mata-mata decisivo, o placar normal.
static func effective_result(world: GameWorld, f: Fixture, club_id: int) -> String:
	var st := of(world, f)
	if st.is_empty():
		return f.result_for(club_id)
	return "V" if int(st["w"]) == club_id else "D"


## "no agregado (3 x 2)", "nos pênaltis" ou "" (jogo único decidido no tempo normal).
static func how(st: Dictionary) -> String:
	if bool(st.get("pens", false)):
		return "nos pênaltis"
	if bool(st.get("two", false)):
		return "no agregado (%d x %d)" % [int(st["agg"][0]), int(st["agg"][1])]
	return ""


## "da Copa do Brasil", "do Campeonato Gaúcho": artigo certo antes do nome da competição.
static func of_comp(name: String) -> String:
	for w in ["Copa", "Liga", "Recopa", "Supercopa", "Taça", "Libertadores", "Sul-Americana", "Série", "Premier", "Bundesliga", "Eredivisie", "Champions", "Europa", "Conference", "Ligue", "Primeira", "Superliga", "Super Liga"]:
		if name.begins_with(w):
			return "da " + name
	return "do " + name
