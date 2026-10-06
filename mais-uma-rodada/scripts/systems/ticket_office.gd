class_name TicketOffice
extends RefCounted
## Bilheteria: a política de preço do ingresso (Club.ticket_mult sobre o ingresso médio da liga).
## O usuário escolhe o patamar vendo antes o público e a renda esperados; a torcida sente o preço
## (caro irrita aos poucos, barato agrada); os clubes da IA reajustam a cada temporada pelo que o
## estádio mostrou: lotado sobe, vazio desce, caixa apertado sobe, presidente populista segura.

const LEVELS := [[0.7, "Popular"], [0.85, "Abaixo da média"], [1.0, "Média da liga"], [1.2, "Acima da média"], [1.45, "Premium"], [1.8, "Elite"]]


static func level_of(club: Club) -> int:
	var best := 0
	for i in LEVELS.size():
		if absf(float(LEVELS[i][0]) - club.ticket_mult) < absf(float(LEVELS[best][0]) - club.ticket_mult):
			best = i
	return best


static func level_name(club: Club) -> String:
	return String(LEVELS[level_of(club)][1])


static func set_level(club: Club, i: int) -> void:
	club.ticket_mult = float(LEVELS[clampi(i, 0, LEVELS.size() - 1)][0])


## Público médio, ocupação e renda da temporada com o preço `mult` (sem mudar o clube).
static func preview(world: GameWorld, club: Club, mult: float) -> Dictionary:
	var keep := club.ticket_mult
	club.ticket_mult = mult
	var att := FinanceManager.expected_attendance(club, null, false)
	var gate := FinanceManager.expected_gate(club)
	var price := FinanceManager.ticket_price(club)
	club.ticket_mult = keep
	return {"att": att, "occ": float(att) / maxf(1.0, club.capacity), "gate": gate, "price": price}


## Semana: a torcida sente o preço (caro irrita, barato agrada), devagar.
static func weekly_mood(club: Club) -> void:
	club.fan_mood = clampf(club.fan_mood + (1.0 - club.ticket_mult) * 0.12, 0.0, 100.0)


## Virada da temporada: a IA reajusta o preço pelo que o estádio mostrou.
static func season_review_ai(world: GameWorld) -> void:
	for c: Club in world.clubs:
		if world.is_user_club(c.id) or c.capacity <= 0:
			continue
		var occ := float(FinanceManager.expected_attendance(c, null, false)) / float(c.capacity)
		var m := c.ticket_mult
		if occ >= 0.95:
			m *= 1.08 # estádio lotado: o ingresso sobe
		elif occ <= 0.6:
			m *= 0.92 # arquibancada vazia: promoção
		if FinanceManager.in_trouble(c):
			m *= 1.05
		if String(People.president(world, c.id).get("st", "")) == "populista":
			m = minf(m, 1.0)
		c.ticket_mult = clampf(m, 0.6, 2.0)
