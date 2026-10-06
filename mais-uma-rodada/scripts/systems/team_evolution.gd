class_name TeamEvolution
extends RefCounted
## Times melhoram e pioram com o tempo, como na vida real, além do que o elenco já muda
## (idade, evolução, mercado):
##   - Trabalho do técnico (`w`, 0..100): cresce jogo a jogo na direção do que o técnico
##     consegue construir (habilidade, estilo, tempo no cargo, estrutura). Trocar de técnico
##     derruba parte do trabalho — mas o time novo costuma dar um gás no começo.
##   - Fase (`mo`, -1..1): confiança pelos resultados em relação ao esperado. Sequência boa
##     embala, sequência ruim pesa; tudo volta aos poucos para o normal.
##   - Força no começo da temporada (`s0`) e histórico por temporada (`hist`), para o auxiliar
##     e a imprensa dizerem quem cresceu e quem caiu.
## O efeito no jogo é moderado (de -2,5% a +3% no rendimento): talento continua decidindo.

const CENTER := 58.0
const WORK_SPAN := 0.022
const MOMENTUM_SPAN := 0.013
const LEARN := 0.045


static func ensure(world: GameWorld, club: Club) -> Dictionary:
	if club.evo.is_empty():
		var tgt := _target(world, club)
		club.evo = {"w": snappedf(tgt - 6.0, 0.1), "mo": 0.0, "cs": _coach_key(world, club), "n": 0,
			"s0": snappedf(ClubAI.team_strength(world, club), 0.1), "hist": []}
	return club.evo


static func _coach_key(world: GameWorld, club: Club) -> int:
	if world.is_user_club(club.id):
		return -2
	return int(People.coach_of(world, club.id).get("id", -1))


## O teto do trabalho: o que o comando consegue construir.
static func _target(world: GameWorld, club: Club) -> float:
	var n := int(club.evo.get("n", 0))
	var tenure := minf(float(n) / 19.0, 4.0) * 2.0
	var fac := (float(club.facilities) - 50.0) * 0.08
	if world.is_user_club(club.id):
		# O time do usuário: o trabalho vem da comissão (auxiliar) e do tempo no cargo.
		return clampf(34.0 + People.staff_level(world, "auxiliar") * 38.0 + tenure + fac, 20.0, 92.0)
	var co := People.coach_of(world, club.id)
	var sk := float(co.get("sk", 50.0))
	var st_bonus := {"estrategista": 3.0, "linha_dura": 1.5, "pragmatico": 1.0, "motivador": 0.0, "formador": -1.0, "ofensivo": -0.5}
	if bool(co.get("int", false)):
		sk -= 12.0 # interino segura, não constrói
	return clampf(22.0 + sk * 0.6 + float(st_bonus.get(String(co.get("st", "")), 0.0)) + tenure + fac, 15.0, 95.0)


## Multiplicador de rendimento do time (entra no fator individual, sem amortecimento).
static func factor(world: GameWorld, club: Club) -> float:
	if club.evo.is_empty():
		return 1.0
	var w := float(club.evo.get("w", CENTER))
	var mo := float(club.evo.get("mo", 0.0))
	return clampf(1.0 + (w - CENTER) / 42.0 * WORK_SPAN + mo * MOMENTUM_SPAN, 0.975, 1.03)


## Depois de cada jogo (os dois lados). `result` = "V", "E" ou "D".
static func after_match(world: GameWorld, club: Club, opp: Club, result: String, home: bool) -> void:
	var e := ensure(world, club)
	# Troca de comando: parte do trabalho se perde, mas o time novo costuma responder.
	var ck := _coach_key(world, club)
	if ck != int(e.get("cs", ck)):
		e["w"] = snappedf(float(e["w"]) * 0.62 + 12.0, 0.1)
		e["mo"] = snappedf(maxf(float(e["mo"]), 0.0) * 0.5 + 0.35, 0.01)
		e["n"] = 0
		e["cs"] = ck
	e["n"] = int(e.get("n", 0)) + 1
	var tgt := _target(world, club)
	var w := float(e["w"])
	e["w"] = snappedf(w + (tgt - w) * LEARN, 0.1)
	# Fase: pontos contra o esperado pela diferença de força.
	var pts := 3.0 if result == "V" else (1.0 if result == "E" else 0.0)
	var exp_pts := 1.35
	if opp != null:
		var d := ClubAI.team_strength(world, club) - ClubAI.team_strength(world, opp) + (1.5 if home else -1.5)
		exp_pts = clampf(1.35 + d * 0.11, 0.35, 2.5)
	var mo := float(e["mo"]) * 0.88 + (pts - exp_pts) * 0.07
	e["mo"] = snappedf(clampf(mo, -1.0, 1.0), 0.01)


## Fim de temporada: guarda a força inicial e final, técnicos evoluem ou estagnam.
static func season_end(world: GameWorld) -> void:
	for c: Club in world.clubs:
		var e := ensure(world, c)
		var now := ClubAI._compute_strength(world, c)
		var hist: Array = e.get("hist", [])
		hist.append([world.year, snappedf(float(e.get("s0", now)), 0.1), snappedf(now, 0.1), snappedf(float(e["w"]), 0.1)])
		if hist.size() > 8:
			hist = hist.slice(hist.size() - 8)
		e["hist"] = hist
		e["mo"] = snappedf(float(e["mo"]) * 0.4, 0.01) # pré-temporada zera boa parte da fase
	# Técnicos: os jovens aprendem com o tempo, os mais velhos param no tempo (os resultados
	# da temporada já mexem na habilidade em People.on_season_end).
	var pp := People.data(world)
	for cid in pp["coaches"]:
		var co: Dictionary = pp["coaches"][cid]
		var age := world.year - int(co.get("by", world.year - 50))
		var r := RngUtil.hash_i(world.world_seed, int(co.get("id", 0)) * 131 + world.year, 99173)
		var noise := float(absi(r) % 1000) / 1000.0
		var d := 0.0
		if age < 45:
			d = 0.3 + noise * 1.0
		elif age > 62:
			d = -noise * 0.9
		co["sk"] = snappedf(clampf(float(co.get("sk", 50.0)) + d, 15.0, 97.0), 0.1)


## Começo de temporada: marca a força de partida de cada clube.
static func season_start(world: GameWorld) -> void:
	for c: Club in world.clubs:
		var e := ensure(world, c)
		e["s0"] = snappedf(ClubAI._compute_strength(world, c), 0.1)


## Variação de força desde o começo da temporada (pontos de overall do time titular).
static func strength_delta(world: GameWorld, club: Club) -> float:
	var e := ensure(world, club)
	return ClubAI.team_strength(world, club) - float(e.get("s0", ClubAI.team_strength(world, club)))


static func work_label(w: float) -> String:
	if w >= 75.0:
		return "Trabalho consolidado"
	if w >= 60.0:
		return "Trabalho em evolução"
	if w >= 45.0:
		return "Trabalho em construção"
	return "Time ainda sem padrão"


static func momentum_label(mo: float) -> String:
	if mo >= 0.45:
		return "Embalado"
	if mo >= 0.15:
		return "Confiante"
	if mo <= -0.45:
		return "Em crise"
	if mo <= -0.15:
		return "Pressionado"
	return "Fase normal"
