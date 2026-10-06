class_name Reputation
extends RefCounted
## Reputação (1..100) de competições, clubes e jogadores, e quanto vale cada título.
##
## Competições: ligas pela força do país e da divisão (a mesma do ranking de clubes) e pelo teto de
## reputação dos clubes; copas continentais pela confederação e pelo nível (Campeões > Liga Europa
## > Conferência); copas nacionais e supercopas pela liga principal do país.
## Um título vale (rep/100)³ × 100 pontos de prestígio: ganhar a Premier (≈86) pesa bem mais do que
## ganhar uma liga média (≈40) ou um estadual (≈11). O mesmo valor define quanto a vitória sobe a
## reputação do clube.
## Clubes: a reputação do próprio clube; o prestígio soma os títulos pelo peso de cada um.
## Jogadores: calculada na hora (overall, clube, títulos pesados e prêmios); não entra no save.

const LABELS := [[90.0, "Lendária"], [80.0, "Mundial"], [68.0, "Continental"], [55.0, "Nacional"], [40.0, "Regional"], [0.0, "Local"]]
const PLAYER_LABELS := [[86.0, "Estrela mundial"], [74.0, "Internacional"], [60.0, "Nacional"], [45.0, "Conhecido"], [0.0, "Desconhecido"]]

static var _comp_cache := {}


## A força das ligas mudou (LeagueReputation): as reputações de competição são recalculadas.
static func clear_cache() -> void:
	_comp_cache.clear()


static func label(v: float) -> String:
	for it: Array in LABELS:
		if v >= float(it[0]):
			return it[1]
	return "Local"


static func player_label(v: float) -> String:
	for it: Array in PLAYER_LABELS:
		if v >= float(it[0]):
			return it[1]
	return "Desconhecido"


static func color(v: float) -> Color:
	if v >= 80.0:
		return UIColors.ACCENT
	if v >= 68.0:
		return UIColors.GREEN
	if v >= 55.0:
		return UIColors.BLUE
	return UIColors.MUTED


## Reputação de uma liga nacional.
static func league_rep(league_id: String) -> float:
	var key := "L:" + league_id
	if _comp_cache.has(key):
		return _comp_cache[key]
	var cfg := DatabaseManager.league_cfg(league_id)
	var s := ClubRanking.league_strength(league_id)
	var rr: Array = cfg.get("rep", [40, 70])
	var v := clampf(0.6 * (30.0 + 65.0 * sqrt(s)) + 0.4 * float(rr[1]), 5.0, 99.0)
	_comp_cache[key] = v
	return v


## Liga principal de um país ("" se o país não tem liga).
static func top_league_of(nation: String) -> String:
	for id in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(id)
		if String(cfg.get("nation", "")) == nation and int(cfg.get("tier", 1)) == 1:
			return id
	return ""


## Reputação de uma copa (continental, Mundial, nacional, da liga, supercopa ou estadual).
static func cup_rep(cup_id: String) -> float:
	var key := "C:" + cup_id
	if _comp_cache.has(key):
		return _comp_cache[key]
	var cfg := CupManager.cfg(cup_id)
	var v := 40.0
	if cup_id == CupManager.CWC:
		v = 99.0
	elif CupManager.is_international(cup_id):
		var wgt := float(ClubRanking.CONFED_WEIGHT.get(String(cfg.get("confed", "")), 0.5))
		v = 45.0 + 54.0 * wgt - (int(cfg.get("level", 1)) - 1) * 10.0
	elif CupManager.is_state(cup_id):
		v = 38.0 + 10.0 * float(cfg.get("rep_bonus", 1.0))
	else:
		var top := top_league_of(String(cfg.get("nation", "")))
		var base := league_rep(top) if top != "" else 50.0
		match String(cfg.get("kind", "")):
			"national":
				v = base * 0.8
			"super":
				v = base * 0.55
			_:
				v = base * 0.7
	v = clampf(v, 5.0, 99.0)
	_comp_cache[key] = v
	return v


## Reputação da competição de um título ("L:ENG1", "C:UCL", "D:FAC"...).
static func title_rep(key: String) -> float:
	var id := key.substr(2)
	match key.substr(0, 2):
		"L:":
			return league_rep(id)
		"P:":
			return league_rep(id) * 0.55
		"Y:":
			return league_rep(id) * 0.4
		"Z:":
			return league_rep(id) * 0.33
		"W:", "C:", "D:", "S:", "U:":
			return cup_rep(id)
	return 30.0


## Pontos de prestígio que um título vale.
static func title_value(key: String) -> float:
	var r := title_rep(key) / 100.0
	return r * r * r * 100.0


## Quanto um título sobe a reputação do clube (a liga forte sobe mais).
static func title_rep_gain(key: String) -> float:
	return 0.4 + 3.6 * title_value(key) / 100.0


## Soma do prestígio de todos os títulos do clube.
static func club_prestige(club: Club) -> float:
	var s := 0.0
	for k in club.titles:
		s += title_value(String(k)) * int(club.titles[k])
	return s


## Títulos do clube do mais valioso para o menos: [{k, n, v}].
static func club_titles_by_value(club: Club) -> Array:
	var out: Array = []
	for k in club.titles:
		var n := int(club.titles[k])
		if n > 0:
			out.append({"k": String(k), "n": n, "v": title_value(String(k))})
	out.sort_custom(func(a, b): return float(a["v"]) > float(b["v"]))
	return out


## Posição do clube no ranking mundial de reputação (1 = maior).
static func club_world_rank(world: GameWorld, club: Club) -> int:
	var n := 1
	for c: Club in world.clubs:
		if c != null and c.id != club.id and c.reputation > club.reputation:
			n += 1
	return n


## Reputação de um jogador (1..100).
static func player_rep(world: GameWorld, p: Player) -> float:
	var ovr := clampf((p.overall - 45.0) / 47.0, 0.0, 1.0) * 100.0
	var c := world.club(p.club_id) if p.club_id >= 0 else null
	var club_rep := c.reputation if c != null else 30.0
	var honours := 0.0
	for t in p.trophies:
		honours += title_value(String(t.get("k", "")))
	var hon := 100.0 * (1.0 - exp(-honours / 220.0))
	var aw := minf(100.0, p.awards.size() * 14.0)
	return clampf(0.58 * ovr + 0.2 * club_rep + 0.14 * hon + 0.08 * aw, 1.0, 99.0)


## Nome curto de uma competição para listas.
static func comp_name(world: GameWorld, key: String) -> String:
	var id := key.substr(2)
	if key.begins_with("L:"):
		return String(DatabaseManager.league_cfg(id).get("name", world.league_short(id)))
	return CupManager.cup_name(id)
