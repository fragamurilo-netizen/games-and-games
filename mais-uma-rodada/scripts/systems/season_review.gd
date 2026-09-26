class_name SeasonReview
extends RefCounted
## Balanço da temporada do clube do usuário: nota do ano, campanha em números, destaques do
## elenco, evolução do clube e conquistas de carreira desbloqueadas. É montado dentro de
## SeasonManager.end_season, antes de as estatísticas da temporada serem zeradas.

## Conquistas de carreira do treinador (desbloqueadas uma única vez, guardadas em world.stats["ach"]).
const ACHIEVEMENTS := {
	"primeira": {"name": "Primeira de muitas", "desc": "Completar a primeira temporada", "icon": "whistle"},
	"meta": {"name": "Palavra cumprida", "desc": "Cumprir a meta da diretoria", "icon": "check"},
	"meta3": {"name": "Homem de confiança", "desc": "Cumprir a meta 3 temporadas seguidas", "icon": "shield"},
	"titulo": {"name": "Levantou a taça", "desc": "Conquistar o primeiro título", "icon": "trophy"},
	"titulos5": {"name": "Colecionador", "desc": "Chegar a 5 títulos na carreira", "icon": "trophy"},
	"acesso": {"name": "Subiu!", "desc": "Conquistar um acesso", "icon": "up"},
	"invicto_casa": {"name": "Alçapão", "desc": "Terminar a liga invicto em casa", "icon": "home"},
	"ataque": {"name": "Rolo compressor", "desc": "Marcar 2 gols por jogo na liga", "icon": "ball"},
	"defesa": {"name": "Muralha", "desc": "Sofrer menos de 1 gol por jogo na liga", "icon": "shield"},
	"artilheiro": {"name": "Tem goleador", "desc": "Ter o artilheiro da liga no elenco", "icon": "star"},
	"jogos100": {"name": "Cem jogos", "desc": "Chegar a 100 jogos como treinador", "icon": "clock"},
	"jogos250": {"name": "Veterano da casamata", "desc": "Chegar a 250 jogos como treinador", "icon": "clock"},
	"temporadas5": {"name": "Longevidade", "desc": "Completar 5 temporadas", "icon": "star"},
	"cria": {"name": "Cria da casa", "desc": "Um jogador de 21 anos ou menos com 20+ jogos", "icon": "up"},
}
const ACH_ORDER: Array[String] = ["primeira", "meta", "meta3", "titulo", "titulos5", "acesso", "invicto_casa", "ataque",
	"defesa", "artilheiro", "jogos100", "jogos250", "temporadas5", "cria"]

const GRADES: Array = [
	[92, "A+", "Temporada histórica"],
	[80, "A", "Temporada excelente"],
	[66, "B", "Boa temporada"],
	[50, "C", "Temporada regular"],
	[34, "D", "Temporada abaixo do esperado"],
	[0, "E", "Temporada para esquecer"],
]


static func grade_color(letter: String) -> Color:
	match letter:
		"A+", "A":
			return UIColors.ACCENT
		"B":
			return UIColors.GREEN
		"C":
			return UIColors.BLUE
		"D":
			return UIColors.ORANGE
	return UIColors.RED


## Monta o balanço. `user` é o summary["user"] já preenchido; `rep0`/`fans0` são reputação e
## torcida no início da virada (antes do ajuste anual); `league_scorer` é o artilheiro da liga.
static func build(world: GameWorld, user: Dictionary, league: League, rep0: float, fans0: int, league_scorer: Dictionary) -> Dictionary:
	var club := world.user_club()
	var row: Dictionary = league.table.get(club.id, {})
	var pl := int(row.get("pl", 0))
	var rec := {"pl": pl, "w": int(row.get("w", 0)), "d": int(row.get("d", 0)), "l": int(row.get("l", 0)),
		"gf": int(row.get("gf", 0)), "ga": int(row.get("ga", 0)), "pts": int(row.get("pts", 0))}
	rec["aprov"] = int(round(100.0 * rec["pts"] / maxf(1.0, pl * 3.0)))
	var home := _home_record(world, league, club.id)
	rec["home_l"] = home[2]
	rec["home_w"] = home[0]
	var fin := FinanceManager.summary(world, club)
	var score := _score(user, league, rec)
	var grade: Array = GRADES[GRADES.size() - 1]
	for g in GRADES:
		if score >= int(g[0]):
			grade = g
			break
	var stars := _stars(world, club)
	var out := {
		"score": score, "grade": grade[1], "grade_label": grade[2], "record": rec,
		"income": int(fin["income"]), "expense": int(fin["expense"]), "balance": int(fin["balance"]),
		"prize": FinanceManager.prize_for(league.id, int(user.get("pos", 1)), league.club_ids.size()),
		"rep0": snappedf(rep0, 0.1), "rep1": snappedf(club.reputation, 0.1), "fans0": fans0, "fans1": club.fan_base,
		"stars": stars, "best_pos": _best_finish(club, league.id), "headline": _headline(world, user, rec, grade),
	}
	out["achievements"] = _unlock(world, user, rec, league, stars, league_scorer)
	return out


## Nota de 0 a 100: meta da diretoria, posição relativa, copas, acesso/queda e aproveitamento.
static func _score(user: Dictionary, league: League, rec: Dictionary) -> int:
	var teams := maxi(2, league.club_ids.size())
	var pos := int(user.get("pos", teams))
	var s := 30.0 * float(teams - pos) / float(teams - 1)
	s += 30.0 if bool(user.get("goal_met", false)) else 8.0
	s += float(rec["aprov"]) * 0.2
	if bool(user.get("champion", false)):
		s += 18.0
	if bool(user.get("promoted", false)):
		s += 14.0
	if bool(user.get("relegated", false)):
		s -= 25.0
	for cu in user.get("cups", []):
		if bool(cu.get("champion", false)):
			s += 16.0
		elif String(cu.get("stage", "")) in ["Final", "Semifinal"]:
			s += 5.0
	return clampi(int(round(s)), 0, 100)


static func _home_record(world: GameWorld, league: League, club_id: int) -> Array:
	var w := 0
	var d := 0
	var l := 0
	for r in league.rounds:
		for f: Fixture in r:
			if not f.played or f.home != club_id:
				continue
			var res := f.result_for(club_id)
			if res == "V":
				w += 1
			elif res == "E":
				d += 1
			else:
				l += 1
	return [w, d, l]


## Destaques do elenco na temporada (liga + copas).
static func _stars(world: GameWorld, club: Club) -> Dictionary:
	var best := {}
	var vals := {"scorer": -1.0, "assists": -1.0, "rating": -1.0, "apps": -1.0, "young": -1.0}
	for p: Player in world.squad(club):
		var tot := p.season_totals()
		var apps := int(tot[0])
		if apps <= 0:
			continue
		var goals := int(tot[1])
		var assists := int(tot[2])
		var avg := p.avg_rating()
		var cand := {
			"scorer": [float(goals) + apps * 0.001, "%d gols" % goals],
			"assists": [float(assists) + apps * 0.001, "%d assistências" % assists],
			"rating": [avg if p.stats[Player.S_APPS] >= 8 else -1.0, "nota %s" % Fmt.rating(avg)],
			"apps": [float(apps), "%d jogos" % apps],
			"young": [avg + apps * 0.01 if p.age(world.year) <= 21 and apps >= 5 else -1.0, "%d anos · %d jogos" % [p.age(world.year), apps]],
		}
		for k in cand:
			var v: float = cand[k][0]
			if v > float(vals[k]) and (k != "scorer" or goals > 0) and (k != "assists" or assists > 0):
				vals[k] = v
				best[k] = {"id": p.id, "name": p.display_name(), "pos": p.position, "text": cand[k][1], "apps": apps}
	return best


static func _best_finish(club: Club, league_id: String) -> bool:
	var cur := 999
	var best := 999
	for h in club.history:
		if String(h.get("l", "")) != league_id:
			continue
		best = mini(best, int(h["p"]))
		cur = int(h["p"])
	return cur <= best and club.history.size() > 1


static func _headline(world: GameWorld, user: Dictionary, rec: Dictionary, grade: Array) -> String:
	var club := world.user_club()
	for cu in user.get("cups", []):
		if bool(cu.get("champion", false)):
			return "O %s entra para a história com o título da %s." % [club.short_name, cu["name"]]
	if bool(user.get("champion", false)):
		return "Campeão da %s com %d pontos. A cidade vai parar." % [user.get("league_name", ""), int(rec["pts"])]
	if bool(user.get("promoted", false)):
		return "Missão cumprida: o %s sobe de divisão." % club.short_name
	if bool(user.get("relegated", false)):
		return "Ano amargo: o %s cai e terá de se reconstruir." % club.short_name
	if bool(user.get("goal_met", false)):
		return "Meta cumprida: %dº lugar, %d vitórias e %d%% de aproveitamento." % [int(user.get("pos", 0)), int(rec["w"]), int(rec["aprov"])]
	return "%s. A diretoria espera mais na próxima temporada." % String(grade[2])


## Verifica as conquistas e devolve só as desbloqueadas agora.
static func _unlock(world: GameWorld, user: Dictionary, rec: Dictionary, league: League, stars: Dictionary, league_scorer: Dictionary) -> Array:
	var have: Array = world.stats.get("ach", [])
	var ms := world.manager_stats
	var streak := int(world.stats.get("goal_streak", 0))
	streak = streak + 1 if bool(user.get("goal_met", false)) else 0
	world.stats["goal_streak"] = streak
	var pl := maxi(1, int(rec["pl"]))
	var any_cup := false
	for cu in user.get("cups", []):
		any_cup = any_cup or bool(cu.get("champion", false))
	var young := false
	for p: Player in world.squad(world.user_club()):
		if p.age(world.year) <= 21 and int(p.season_totals()[0]) >= 20:
			young = true
	var cond := {
		"primeira": int(ms.get("seasons", 0)) >= 1,
		"meta": bool(user.get("goal_met", false)),
		"meta3": streak >= 3,
		"titulo": bool(user.get("champion", false)) or any_cup,
		"titulos5": int(ms.get("titles", 0)) >= 5,
		"acesso": bool(user.get("promoted", false)),
		"invicto_casa": int(rec["home_l"]) == 0 and int(rec["pl"]) >= 10,
		"ataque": float(rec["gf"]) / pl >= 2.0 and int(rec["pl"]) >= 10,
		"defesa": float(rec["ga"]) / pl < 1.0 and int(rec["pl"]) >= 10,
		"artilheiro": not league_scorer.is_empty() and world.player(int(league_scorer.get("id", -1))) != null and world.is_user_club(world.player(int(league_scorer["id"])).club_id),
		"jogos100": int(ms.get("games", 0)) >= 100,
		"jogos250": int(ms.get("games", 0)) >= 250,
		"temporadas5": int(ms.get("seasons", 0)) >= 5,
		"cria": young,
	}
	var new: Array = []
	for k in ACH_ORDER:
		if bool(cond[k]) and not have.has(k):
			have.append(k)
			new.append(k)
	world.stats["ach"] = have
	return new
