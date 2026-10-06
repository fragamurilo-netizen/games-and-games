class_name InjuryModel
extends RefCounted
## Lesões realistas: o motor diz que houve lesão e quão forte foi o lance (semanas da tabela
## geral, InjuryTable.roll_weeks); aqui ela vira uma lesão de verdade, com tipo e duração pelo
## jogador que se machucou:
##   - idade: depois dos 30, mais lesão muscular e recuperação mais lenta;
##   - cansaço: jogar com pouca condição física puxa lesão muscular (posterior, panturrilha, adutor);
##   - posição: goleiro quase não tem muscular; ponta, lateral e atacante sofrem na posterior da coxa;
##   - histórico: o mesmo músculo de novo em menos de 12 semanas volta mais vezes e demora mais;
##   - peso: sobrepeso pesa no joelho e no tornozelo;
##   - departamento médico do clube (no clube do usuário, a comissão; na IA, a estrutura).
## Volta de lesão longa: o jogador retorna sem ritmo (condição física baixa por algumas semanas).
## Player.inj_log = [[ano, turno, parte, semanas]] (as 6 últimas).

## Tipos: [parte, nome, semanas mín, máx, muscular]
const TYPES := {
	"posterior": [["Lesão na posterior da coxa (grau 1)", 2, 3], ["Lesão na posterior da coxa (grau 2)", 4, 7], ["Lesão na posterior da coxa (grau 3)", 8, 14]],
	"panturrilha": [["Lesão na panturrilha (grau 1)", 1, 3], ["Lesão na panturrilha (grau 2)", 4, 6]],
	"adutor": [["Distensão no adutor", 2, 4], ["Pubalgia", 4, 8]],
	"quadriceps": [["Lesão no quadríceps (grau 1)", 2, 3], ["Lesão no quadríceps (grau 2)", 4, 7]],
	"tornozelo": [["Entorse no tornozelo", 1, 3], ["Entorse grave no tornozelo", 4, 7], ["Fratura no tornozelo", 8, 14]],
	"joelho": [["Pancada no joelho", 1, 1], ["Lesão no ligamento colateral do joelho", 4, 8], ["Lesão no menisco", 6, 12], ["Ruptura do ligamento cruzado anterior", 26, 38]],
	"pe": [["Contusão no pé", 1, 2], ["Fratura no metatarso", 7, 12]],
	"tendao": [["Tendinite patelar", 2, 5], ["Ruptura do tendão de Aquiles", 26, 36]],
	"pancada": [["Pancada no tornozelo", 1, 1], ["Contusão na coxa", 1, 1], ["Concussão leve", 1, 1], ["Fratura no nariz", 1, 2], ["Corte no supercílio", 1, 1]],
	"ombro": [["Luxação no ombro", 3, 6], ["Fratura na clavícula", 6, 10]],
	"costas": [["Dores nas costas", 1, 2], ["Lesão na lombar", 2, 4]],
}
const MUSCLE := ["posterior", "panturrilha", "adutor", "quadriceps"]


## Transforma a lesão do jogo em lesão do jogador. Retorna {weeks, name, part}.
static func make(world: GameWorld, p: Player, engine_weeks: int, condition: float, training: bool = false) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, world.year, world.current_turn(), engine_weeks, "lesao"])
	var age := p.age(world.year)
	var gk := p.position == Pos.GK
	var tired := clampf((85.0 - condition) / 40.0, 0.0, 1.0)
	var over := maxf(0.0, float(BodyGrowth.overweight(p, world.year)))
	var recent := _recent_part(world, p)
	# Peso de cada parte do corpo para este jogador agora.
	var w := {
		"pancada": (0.8 if training else 3.0) if engine_weeks <= 1 else (0.2 if training else 0.6),
		"posterior": (0.4 if gk else 2.2) * (1.0 + tired * 1.5) * (1.0 + maxf(0.0, age - 29) * 0.12) * (1.4 if p.position in [Pos.RW, Pos.LW, Pos.ST, Pos.RB, Pos.LB] else 1.0),
		"panturrilha": (0.3 if gk else 1.0) * (1.0 + tired) * (1.0 + maxf(0.0, age - 30) * 0.15),
		"adutor": (0.4 if gk else 0.9) * (1.0 + tired * 0.6),
		"quadriceps": (0.3 if gk else 0.8) * (1.0 + tired * 0.6),
		"tornozelo": 1.6 * (1.0 + over * 0.08),
		"joelho": 1.3 * (1.0 + over * 0.1) * (1.6 if engine_weeks >= 13 else 1.0),
		"pe": 0.6,
		"tendao": 0.4 * (1.0 + maxf(0.0, age - 28) * 0.12) * (2.5 if engine_weeks >= 20 else 1.0),
		"ombro": (1.5 if gk else 0.4) * (0.5 if training else 1.0),
		"costas": 0.6 * (1.0 + maxf(0.0, age - 30) * 0.1),
	}
	if recent != "":
		w[recent] = float(w.get(recent, 0.5)) * 3.0 # recidiva: o mesmo lugar de novo
	var part := String(RngUtil.weighted_key(r, w))
	# Gravidade: a do lance do motor, puxada pelo tipo de lesão possível naquela parte.
	var opts: Array = TYPES[part]
	var pick: Array = opts[0]
	for o: Array in opts:
		if engine_weeks >= int(o[1]):
			pick = o
	var weeks := r.randi_range(int(pick[1]), int(pick[2]))
	if part == recent:
		weeks = int(ceil(weeks * 1.35)) # voltou a lesionar: demora mais
	if age >= 31:
		weeks = int(ceil(weeks * (1.0 + (age - 30) * 0.05)))
	weeks = int(ceil(weeks * medical_mult(world, p)))
	weeks = maxi(1, weeks)
	var log: Array = p.inj_log
	log.append([world.year, world.current_turn(), part, weeks])
	while log.size() > 6:
		log.pop_front()
	p.inj_log = log
	world.stat_add("inj_n")
	world.stat_add("inj_w", weeks)
	return {"weeks": weeks, "name": String(pick[0]), "part": part}


## Lugar da lesão mais recente se foi há menos de 12 semanas ("" se não houver).
static func _recent_part(world: GameWorld, p: Player) -> String:
	if p.inj_log.is_empty():
		return ""
	var last: Array = p.inj_log[p.inj_log.size() - 1]
	if int(last[0]) == world.year and world.current_turn() - int(last[1]) <= 12 and MUSCLE.has(String(last[2])):
		return String(last[2])
	return ""


## Departamento médico: no clube do usuário, a comissão; na IA, a estrutura do clube.
static func medical_mult(world: GameWorld, p: Player) -> float:
	if p.club_id < 0:
		return 1.1
	if world.is_user_club(p.club_id):
		return clampf(People.injury_mult(world), 0.8, 1.15)
	var c := world.club(p.club_id)
	return clampf(1.12 - c.facilities / 400.0, 0.85, 1.12)


## Volta de lesão: quem ficou parado muito tempo volta sem ritmo.
static func on_return(p: Player, weeks_out: int) -> void:
	if weeks_out >= 4:
		p.condition = minf(p.condition, clampf(100.0 - weeks_out * 2.0, 60.0, 90.0))


## Lesões de treino (todos os clubes, uma vez por semana). No futebol de verdade quase metade das
## lesões que tiram o jogador de campo acontece no treino: muscular, quase sempre curta. Pesam o
## cansaço acumulado, a idade, a propensão, o peso e o departamento médico; no clube do usuário,
## também o foco, a intensidade e a carga individual do treino.
const TRAIN_RATE := 0.0085 # por jogador e semana (≈ 10 a 12 por clube na temporada)


static func training_week(world: GameWorld) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.year, world.current_turn(), "treino_lesao"])
	for c: Club in world.clubs:
		if c.is_pool():
			continue
		var user := world.is_user_club(c.id)
		var club_m := TrainingManager.injury_mult(world, c.id) if user else 1.0
		for p: Player in world.squad(c):
			if p.is_injured():
				continue
			var age := p.age(world.year)
			var risk := TRAIN_RATE * club_m
			risk *= 1.0 + clampf((80.0 - p.condition) / 30.0, 0.0, 1.0) # cansado se machuca mais
			risk *= (1.0 + p.injury_prone / 10.0) * 0.5
			risk *= 1.0 + maxf(0.0, age - 29) * 0.06
			risk *= BodyGrowth.injury_factor(p) * p.trait_mult("injury_mult")
			if p.position == Pos.GK:
				risk *= 0.5
			if user:
				risk *= TrainingManager.player_injury_mult(world, p)
			if r.randf() >= risk:
				continue
			# Treino: lesões mais curtas que as de jogo (sem choque forte), muitas musculares.
			var eng := InjuryTable.roll_weeks(r)
			if eng >= 7 and r.randf() < 0.6:
				eng = r.randi_range(2, 4)
			var im := make(world, p, eng, p.condition, true)
			p.injury_weeks = int(im["weeks"])
			p.injury_name = String(im["name"])
			world.stat_add("inj_t")
			PlayerCareer.on_injury(world, p, p.injury_weeks, p.injury_name)
			PlayerDevelopment.injury_setback(world.rng, p, p.injury_weeks, age)
			NewsManager.on_injury(world, p)
			InboxManager.on_injury(world, p)
