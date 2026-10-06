class_name PlayerPercentiles
extends RefCounted
## Relatório de percentis, como nos sites de estatística: cada número por 90 minutos do jogador
## comparado com os da mesma função na mesma liga (quem jogou ao menos 270 minutos na liga).
## Percentil 90 = melhor que 90% deles. Números em que menos é melhor (faltas, gols sofridos)
## são invertidos.

const MIN_MINUTES := 270

## Métricas por setor: [id, nome, menos_é_melhor]
const METRICS := {
	Pos.G_ATT: [["g90", "Gols", false], ["xg90", "xG", false], ["sh90", "Finalizações", false], ["acc", "No alvo (%)", false],
		["a90", "Assistências", false], ["kp90", "Passes decisivos", false], ["dr90", "Dribles", false], ["rt", "Nota média", false]],
	Pos.G_MID: [["a90", "Assistências", false], ["kp90", "Passes decisivos", false], ["pp", "Passes certos (%)", false],
		["dr90", "Dribles", false], ["tk90", "Desarmes", false], ["in90", "Interceptações", false], ["g90", "Gols", false], ["rt", "Nota média", false]],
	Pos.G_DEF: [["tk90", "Desarmes", false], ["in90", "Interceptações", false], ["ae90", "Bolas aéreas", false],
		["pp", "Passes certos (%)", false], ["fo90", "Faltas", true], ["kp90", "Passes decisivos", false], ["rt", "Nota média", false]],
	Pos.G_GK: [["sv90", "Defesas", false], ["svp", "Chutes defendidos (%)", false], ["ga90", "Gols sofridos", true],
		["cs", "Sem sofrer gol (%)", false], ["rt", "Nota média", false]],
}


static func _value(p: Player, k: String) -> float:
	var apps := maxi(1, p.stats[Player.S_APPS])
	match k:
		"g90":
			return p.per90(Player.S_GOALS)
		"xg90":
			return p.per90(Player.S_XG) / 100.0
		"sh90":
			return p.per90(Player.S_SHOTS)
		"acc":
			return 100.0 * p.stats[Player.S_SHOTS_ON] / p.stats[Player.S_SHOTS] if p.stats[Player.S_SHOTS] > 0 else 0.0
		"a90":
			return p.per90(Player.S_ASSISTS)
		"kp90":
			return p.per90(Player.S_KEY_PASSES)
		"dr90":
			return p.per90(Player.S_DRIBBLES)
		"tk90":
			return p.per90(Player.S_TACKLES)
		"in90":
			return p.per90(Player.S_INTERCEPTIONS)
		"ae90":
			return p.per90(Player.S_AERIAL)
		"fo90":
			return p.per90(Player.S_FOULS)
		"pp":
			return float(p.stats[Player.S_PASS_PCT]) / apps
		"sv90":
			return p.per90(Player.S_SAVES)
		"svp":
			return p.save_pct()
		"ga90":
			return p.per90(Player.S_CONCEDED)
		"cs":
			return 100.0 * p.stats[Player.S_CLEAN] / apps
		"rt":
			return p.avg_rating()
	return 0.0


## Quem entra na comparação: mesmo setor, mesma liga, minutos suficientes.
static func pool(w: GameWorld, p: Player) -> Array:
	var club := w.club(p.club_id)
	if club == null:
		return []
	var grp := Pos.group(p.position)
	var out: Array = []
	for c: Club in w.clubs_in_league(club.league_id):
		for q: Player in w.squad(c):
			if Pos.group(q.position) == grp and q.stats[Player.S_MINUTES] >= MIN_MINUTES:
				out.append(q)
	return out


## [{name, value, pct (0..100), lower}] ou [] se o jogador ainda não tem minutos.
static func report(w: GameWorld, p: Player) -> Array:
	if p.stats[Player.S_MINUTES] < MIN_MINUTES:
		return []
	var peers := pool(w, p)
	if peers.size() < 8:
		return []
	var out: Array = []
	for m in METRICS.get(Pos.group(p.position), []):
		var k := String(m[0])
		var lower := bool(m[2])
		var mine := _value(p, k)
		var below := 0
		var equal := 0
		for q: Player in peers:
			var v := _value(q, k)
			if is_equal_approx(v, mine):
				equal += 1
			elif (v < mine) != lower:
				below += 1
		var pct := 100.0 * (below + 0.5 * equal) / float(peers.size())
		out.append({"name": String(m[1]), "value": mine, "pct": pct, "lower": lower, "k": k})
	return out


static func fmt_value(k: String, v: float) -> String:
	if k in ["acc", "pp", "svp", "cs"]:
		return "%d%%" % int(round(v))
	if k == "rt":
		return Fmt.rating(v)
	return Fmt.dec(v, 2)


## Cor do percentil na escala das notas (sem verde néon): elite, bom, regular, fraco, ruim.
static func color(pct: float) -> Color:
	if pct >= 80.0:
		return Fmt.rating_color(85)
	if pct >= 60.0:
		return Fmt.rating_color(75)
	if pct >= 40.0:
		return Fmt.rating_color(65)
	if pct >= 20.0:
		return Fmt.rating_color(55)
	return Fmt.rating_color(40)
