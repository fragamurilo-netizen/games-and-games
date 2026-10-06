class_name LeagueStats
extends RefCounted
## RodadaScore: os números de equipe e de jogador de uma liga, no estilo dos sites de
## estatística. O que é de jogador vem das estatísticas da liga de cada um (Player.stats);
## o que é só do jogo (posse, finalizações sofridas, xG contra) é somado a cada partida de
## liga na linha da classificação do clube, em `row["ts"]`.

const BRAND := "RodadaScore"

# Índices de row["ts"]
const T_N := 0 # jogos contados
const T_POSS := 1 # soma da posse (%)
const T_SH := 2
const T_SO := 3
const T_XG := 4 # × 100
const T_SHA := 5 # finalizações sofridas
const T_SOA := 6
const T_XGA := 7 # × 100
const T_PP := 8 # soma da % de passes certos do time por jogo
const T_TK := 9
const T_IT := 10
const T_DR := 11
const T_AD := 12
const T_FC := 13
const T_KP := 14
const T_CS := 15 # jogos sem sofrer gol
const T_RT := 16 # soma da nota média do time × 10
const T_COUNT := 17


## Chamado em cada jogo de liga, com as estatísticas por jogador da partida (MatchStats).
static func record(league: League, f: Fixture, res: Dictionary, detail: Dictionary) -> void:
	if league == null or not league.table.has(f.home) or not league.table.has(f.away):
		return
	var sums: Array = [[], []]
	for side in 2:
		var s: Array = []
		s.resize(MatchStats.N)
		s.fill(0)
		var pp_sum := 0.0
		var pp_n := 0
		var r_sum := 0.0
		var r_n := 0
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			var d: Array = detail.get(p.id, [])
			if d.size() == MatchStats.N:
				for k in MatchStats.N:
					s[k] += int(d[k])
				if int(ln[QuickMatch.L_MINS]) >= 30:
					pp_sum += float(d[MatchStats.PP])
					pp_n += 1
			if int(ln[QuickMatch.L_MINS]) >= 30:
				r_sum += float(ln[QuickMatch.L_R])
				r_n += 1
		s[MatchStats.PP] = int(round(pp_sum / pp_n)) if pp_n > 0 else 0
		s.append(int(round(r_sum / r_n * 10.0)) if r_n > 0 else 0)
		sums[side] = s
	var poss := float(res.get("poss", 0.5))
	var goals := [f.hg, f.ag]
	for side in 2:
		var cid := f.home if side == 0 else f.away
		var row: Dictionary = league.table[cid]
		var ts: Array = row.get("ts", [])
		if ts.size() != T_COUNT:
			ts = []
			ts.resize(T_COUNT)
			ts.fill(0)
		var me: Array = sums[side]
		var op: Array = sums[1 - side]
		ts[T_N] = int(ts[T_N]) + 1
		ts[T_POSS] = int(ts[T_POSS]) + int(round((poss if side == 0 else 1.0 - poss) * 100.0))
		ts[T_SH] = int(ts[T_SH]) + int(me[MatchStats.SH])
		ts[T_SO] = int(ts[T_SO]) + int(me[MatchStats.SO])
		ts[T_XG] = int(ts[T_XG]) + int(me[MatchStats.XG])
		ts[T_SHA] = int(ts[T_SHA]) + int(op[MatchStats.SH])
		ts[T_SOA] = int(ts[T_SOA]) + int(op[MatchStats.SO])
		ts[T_XGA] = int(ts[T_XGA]) + int(op[MatchStats.XG])
		ts[T_PP] = int(ts[T_PP]) + int(me[MatchStats.PP])
		ts[T_TK] = int(ts[T_TK]) + int(me[MatchStats.TK])
		ts[T_IT] = int(ts[T_IT]) + int(me[MatchStats.IT])
		ts[T_DR] = int(ts[T_DR]) + int(me[MatchStats.DR])
		ts[T_AD] = int(ts[T_AD]) + int(me[MatchStats.AD])
		ts[T_FC] = int(ts[T_FC]) + int(me[MatchStats.FC])
		ts[T_KP] = int(ts[T_KP]) + int(me[MatchStats.KP])
		if int(goals[1 - side]) == 0:
			ts[T_CS] = int(ts[T_CS]) + 1
		ts[T_RT] = int(ts[T_RT]) + int(me[MatchStats.N])
		row["ts"] = ts


## Nota RodadaScore do jogador na liga: média das notas de jogo (0 sem jogos).
static func player_rating(p: Player) -> float:
	var apps := p.stats[Player.S_APPS]
	return float(p.stats[Player.S_RATING_SUM]) / 10.0 / apps if apps > 0 else 0.0


## Jogadores com pelo menos um jogo pela liga, dos clubes que estão nela.
static func players(world: GameWorld, league: League, min_apps: int = 1) -> Array:
	var out: Array = []
	for cid in league.club_ids:
		var c := world.club(int(cid))
		if c == null:
			continue
		for pid in c.player_ids:
			var p: Player = world.players.get(pid, null)
			if p != null and p.stats[Player.S_APPS] >= min_apps:
				out.append(p)
	return out


## Números de um clube na liga, por jogo quando faz sentido. -1 = sem dado (posse e o que
## é do adversário só existem a partir dos jogos registrados).
static func team(world: GameWorld, league: League, cid: int) -> Dictionary:
	var row: Dictionary = league.table.get(cid, {})
	var pl := int(row.get("pl", 0))
	var ts: Array = row.get("ts", [])
	var n := int(ts[T_N]) if ts.size() == T_COUNT else 0
	var out := {"id": cid, "pl": pl, "gf": int(row.get("gf", 0)), "ga": int(row.get("ga", 0)), "pts": int(row.get("pts", 0)),
		"yc": int(row.get("yc", 0)), "rc": int(row.get("rc", 0)), "n": n}
	var g := maxf(1.0, float(pl))
	out["gfpg"] = out["gf"] / g
	out["gapg"] = out["ga"] / g
	if n > 0 and n >= pl:
		var nn := float(n)
		out["sh"] = ts[T_SH] / nn
		out["so"] = ts[T_SO] / nn
		out["xg"] = ts[T_XG] / 100.0
		out["kp"] = ts[T_KP] / nn
		out["dr"] = ts[T_DR] / nn
		out["tk"] = ts[T_TK] / nn
		out["it"] = ts[T_IT] / nn
		out["ad"] = ts[T_AD] / nn
		out["fc"] = ts[T_FC] / nn
		out["pp"] = ts[T_PP] / nn
		out["rt"] = ts[T_RT] / nn / 10.0
	else:
		# Save antigo ou temporada já em andamento: o que dá para somar vem dos jogadores.
		var tot: Array = []
		tot.resize(Player.S_COUNT)
		tot.fill(0)
		var apps := 0
		var rsum := 0
		var c := world.club(cid)
		if c != null:
			for pid in c.player_ids:
				var p: Player = world.players.get(pid, null)
				if p == null:
					continue
				for k in Player.S_COUNT:
					tot[k] += p.stats[k]
				apps += p.stats[Player.S_APPS]
				rsum += p.stats[Player.S_RATING_SUM]
		out["sh"] = tot[Player.S_SHOTS] / g
		out["so"] = tot[Player.S_SHOTS_ON] / g
		out["xg"] = tot[Player.S_XG] / 100.0
		out["kp"] = tot[Player.S_KEY_PASSES] / g
		out["dr"] = tot[Player.S_DRIBBLES] / g
		out["tk"] = tot[Player.S_TACKLES] / g
		out["it"] = tot[Player.S_INTERCEPTIONS] / g
		out["ad"] = tot[Player.S_AERIAL] / g
		out["fc"] = tot[Player.S_FOULS] / g
		out["pp"] = float(tot[Player.S_PASS_PCT]) / apps if apps > 0 else 0.0
		out["rt"] = rsum / 10.0 / apps if apps > 0 else 0.0
	if n > 0:
		var nn2 := float(n)
		out["poss"] = ts[T_POSS] / nn2
		out["sha"] = ts[T_SHA] / nn2
		out["soa"] = ts[T_SOA] / nn2
		out["xga"] = ts[T_XGA] / 100.0
		out["cs"] = int(ts[T_CS])
	else:
		out["poss"] = -1.0
		out["sha"] = -1.0
		out["soa"] = -1.0
		out["xga"] = -1.0
		out["cs"] = -1
	return out


static func teams(world: GameWorld, league: League) -> Array:
	var out: Array = []
	for cid in league.club_ids:
		out.append(team(world, league, int(cid)))
	return out


## Pontos fortes, fracos e o estilo do time, pela posição dele em cada quesito na liga.
## [[nome, posição], ...] para fortes e fracos; estilo em frases curtas.
const TRAITS := [
	["Finalização", "sh", true], ["Pontaria", "so", true], ["Criação de chances", "kp", true],
	["Drible", "dr", true], ["Posse de bola", "poss", true], ["Passe", "pp", true],
	["Desarme", "tk", true], ["Interceptação", "it", true], ["Jogo aéreo", "ad", true],
	["Defesa", "gapg", false], ["Proteção da área", "sha", false], ["Disciplina", "fc", false],
]


static func profile(rows: Array, cid: int) -> Dictionary:
	var me: Dictionary = {}
	for r: Dictionary in rows:
		if int(r["id"]) == cid:
			me = r
	if me.is_empty() or int(me["pl"]) == 0:
		return {"strong": [], "weak": [], "style": []}
	var n := rows.size()
	var ranked: Array = []
	for t: Array in TRAITS:
		var key := String(t[1])
		var v := float(me.get(key, -1.0))
		if v < 0.0:
			continue
		var rank := 1
		for r: Dictionary in rows:
			var o := float(r.get(key, -1.0))
			if int(r["id"]) != cid and o >= 0.0 and ((o > v) if bool(t[2]) else (o < v)):
				rank += 1
		ranked.append([String(t[0]), rank])
	ranked.sort_custom(func(a, b): return a[1] < b[1])
	var cut := maxi(2, n / 4)
	var strong: Array = ranked.filter(func(x): return int(x[1]) <= cut).slice(0, 3)
	var weak: Array = ranked.filter(func(x): return int(x[1]) > n - cut)
	weak.reverse()
	weak = weak.slice(0, 3)
	var style: Array = []
	var poss := float(me.get("poss", -1.0))
	if poss >= 55.0:
		style.append("Gosta de ficar com a bola")
	elif poss >= 0.0 and poss <= 45.0:
		style.append("Cede a bola e sai em velocidade")
	if float(me["sh"]) > 0.0 and float(me["so"]) / float(me["sh"]) < 0.3:
		style.append("Chuta muito de longe")
	if float(me["ad"]) >= _avg(rows, "ad") * 1.12:
		style.append("Procura o jogo aéreo")
	if float(me["tk"]) >= _avg(rows, "tk") * 1.1:
		style.append("Marca forte no campo todo")
	if float(me["fc"]) >= _avg(rows, "fc") * 1.15:
		style.append("Faz muitas faltas")
	return {"strong": strong, "weak": weak, "style": style.slice(0, 3)}


static func _avg(rows: Array, key: String) -> float:
	var s := 0.0
	var k := 0
	for r: Dictionary in rows:
		var v := float(r.get(key, -1.0))
		if v >= 0.0 and int(r["pl"]) > 0:
			s += v
			k += 1
	return s / k if k > 0 else 0.0


## Seleção da temporada pela nota RodadaScore: 4-3-3 com quem jogou ao menos metade
## dos jogos possíveis do clube.
static func best_xi(world: GameWorld, league: League) -> Array:
	var slots := [[Pos.GK], [Pos.RB], [Pos.CB], [Pos.CB], [Pos.LB], [Pos.DM, Pos.CM], [Pos.CM, Pos.AM], [Pos.CM, Pos.AM, Pos.DM],
		[Pos.RW, Pos.RM], [Pos.ST], [Pos.LW, Pos.LM]]
	var pool: Array = []
	for p: Player in players(world, league):
		var pl := int(league.table.get(p.club_id, {}).get("pl", 0))
		if p.stats[Player.S_APPS] >= maxi(1, pl / 2):
			pool.append(p)
	pool.sort_custom(func(a: Player, b: Player): return player_rating(a) > player_rating(b))
	var used := {}
	var out: Array = []
	for s: Array in slots:
		var pick: Player = null
		for p: Player in pool:
			if not used.has(p.id) and p.position in s:
				pick = p
				break
		if pick != null:
			used[pick.id] = true
			out.append(pick)
	return out
