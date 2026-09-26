class_name Physique
extends RefCounted
## O corpo e o pé do jogador dentro da partida (os dois motores usam as mesmas contas):
##  - altura e peso decidem bola aérea (cabeceio, escanteio, goleiro saindo do gol);
##  - peso e altura dão força no corpo a corpo (proteger a bola, marcar o centroavante);
##  - peso demais para a altura custa velocidade e fôlego;
##  - goleiro alto alcança mais; baixo sofre nas bolas altas;
##  - o pé bom no lado certo cruza melhor; o "invertido" (destro na esquerda) corta para dentro,
##    finaliza e chuta de fora melhor, mas cruza pior. Ambidestro ganha um pouco nos dois.

const SIDE_NATURAL := 1
const SIDE_INVERTED := -1
const SIDE_NEUTRAL := 0

## Índice de massa corporal médio por posição (atleta de futebol).
const BMI_MEAN: Array[float] = [23.8, 22.8, 23.8, 22.8, 23.2, 22.8, 22.5, 22.4, 22.4, 22.3, 22.3, 23.5]


## Peso coerente com altura, posição e idade (kg).
static func weight_for(rng: RandomNumberGenerator, height_cm: int, pos: int, age: int) -> int:
	var bmi := RngUtil.gauss(rng, BMI_MEAN[pos] + clampf((age - 27) * 0.07, -0.4, 0.6), 1.0, 20.0, 27.5)
	var m := height_cm / 100.0
	return clampi(int(round(bmi * m * m)), 55, 105)


## Peso padrão (saves antigos, sem sorteio): o médio da posição.
static func default_weight(height_cm: int, pos: int) -> int:
	var m := height_cm / 100.0
	return int(round(BMI_MEAN[pos] * m * m))


static func bmi(p: Player) -> float:
	var m := p.height / 100.0
	return p.weight / maxf(0.01, m * m)


## Bônus na bola aérea (pontos de atributo).
static func aerial(p: Player) -> float:
	return clampf((p.height - 181.0) * 0.55 + (p.weight - 77.0) * 0.12, -12.0, 12.0)


## Bônus de força no corpo a corpo.
static func strength(p: Player) -> float:
	return clampf((p.weight - 77.0) * 0.25 + (p.height - 181.0) * 0.1, -6.0, 6.0)


## Perda de velocidade por estar pesado para a altura.
static func pace_penalty(p: Player) -> float:
	return clampf((bmi(p) - 24.3) * 1.6, 0.0, 8.0)


## Alcance do goleiro.
static func gk_reach(p: Player) -> float:
	return clampf((p.height - 188.0) * 0.35, -6.0, 4.0)


## O pé do jogador combina com o lado da vaga?
static func side_fit(p: Player, pos: int) -> int:
	if p.foot == Player.FOOT_BOTH:
		return SIDE_NEUTRAL
	var left_side := pos in [Pos.LB, Pos.LM, Pos.LW]
	var right_side := pos in [Pos.RB, Pos.RM, Pos.RW]
	if not left_side and not right_side:
		return SIDE_NEUTRAL
	var lefty := p.foot == Player.FOOT_LEFT
	return SIDE_NATURAL if lefty == left_side else SIDE_INVERTED


## Ajustes do pé para a vaga: [cruzamento, finalização, chute de longe, drible+velocidade].
static func side_mods(p: Player, pos: int) -> Array:
	var wide := pos in [Pos.LB, Pos.LM, Pos.LW, Pos.RB, Pos.RM, Pos.RW]
	if p.foot == Player.FOOT_BOTH:
		return [2.0, 1.5, 1.5, 1.0] if wide else [0.0, 1.5, 1.5, 0.0]
	match side_fit(p, pos):
		SIDE_NATURAL:
			return [4.0, 0.0, 0.0, 0.0]
		SIDE_INVERTED:
			# Lateral invertido sofre mais (vive de cruzar); ponta invertido ganha o corte para dentro
			if pos in [Pos.LB, Pos.RB]:
				return [-7.0, 0.0, 1.0, 0.0]
			return [-5.0, 2.5, 3.0, 4.0]
	return [0.0, 0.0, 0.0, 0.0]


## Texto curto para a interface ("Ponta invertido: corta para dentro").
static func side_note(p: Player, pos: int) -> String:
	if p.foot == Player.FOOT_BOTH:
		return "Ambidestro: bom pelos dois lados"
	match side_fit(p, pos):
		SIDE_NATURAL:
			return "Pé bom do lado certo: cruza melhor"
		SIDE_INVERTED:
			if pos in [Pos.LB, Pos.RB]:
				return "Pé invertido: cruza pior"
			return "Invertido: corta para dentro e finaliza"
	return ""
