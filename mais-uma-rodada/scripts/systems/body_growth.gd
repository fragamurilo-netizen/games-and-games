class_name BodyGrowth
extends RefCounted
## O corpo muda com a idade: o garoto da base ainda cresce (até ~19-21 anos, às vezes com um
## estirão tardio) e ganha massa muscular até o peso de atleta da posição. Alguns jogadores têm
## tendência a engordar: voltam das férias acima do peso, engordam parados por lesão e, depois dos
## 29, perdem a forma mais fácil. Peso acima do ideal já custa velocidade e fôlego no motor
## (Physique.pace_penalty) e aqui também aumenta o risco de lesão. O preparador físico (e a
## seriedade do jogador) ajuda a perder o excesso ao longo da temporada.
##
## Player.adult_h = altura final (cm); 0 = ainda não definida (saves antigos: definida na virada).
## A tendência a engordar é fixa por jogador (sorteio pela semente do rosto, sem campo no save).

## Quanto ainda falta crescer, em média, por idade (cm).
const GROW_LEFT := {14: 9.0, 15: 6.5, 16: 4.0, 17: 2.3, 18: 1.2, 19: 0.6, 20: 0.2}
## Fração do que falta que o garoto cresce no ano.
const GROW_RATE := {14: 0.35, 15: 0.4, 16: 0.45, 17: 0.5, 18: 0.6, 19: 0.75, 20: 1.0}
## Garoto mais magro que o adulto: ajuste do IMC por idade.
const YOUTH_BMI := {14: -2.6, 15: -2.3, 16: -2.0, 17: -1.5, 18: -1.0, 19: -0.6, 20: -0.3}
const OVER_INJURY := 0.1 # +10% de risco de lesão por kg acima de 1,5 kg de sobrepeso
const NOTE_KG := 3 # a partir daqui o preparador avisa


static func _r(p: Player, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.face_seed, p.id, salt])
	return r


## Tendência a engordar (0..1): a maioria tem pouca, ~1 em 8 tem muita. Seriedade pesa.
static func prone(p: Player) -> float:
	var u := _r(p, "peso").randf()
	var base := 0.75 if u < 0.12 else (0.3 if u < 0.32 else 0.08)
	return clampf(base * (1.0 + (10 - p.hid("pro")) * 0.05) * (1.4 if p.has_trait("festeiro") else 1.0), 0.0, 1.0)


## Peso ideal de atleta para a altura, a posição e a idade (kg).
static func ideal_weight(p: Player, year: int) -> int:
	var age := p.age(year)
	var bmi := Physique.BMI_MEAN[clampi(p.position, 0, Physique.BMI_MEAN.size() - 1)] + float(YOUTH_BMI.get(clampi(age, 14, 21), 0.0))
	if age >= 31:
		bmi += 0.3
	var m := p.height / 100.0
	return int(round(bmi * m * m))


static func overweight(p: Player, year: int) -> int:
	return p.weight - ideal_weight(p, year)


## Peso como texto para a ficha: "78 kg" ou "84 kg (acima do peso)".
static func weight_text(p: Player, year: int) -> String:
	var ov := overweight(p, year)
	if ov >= NOTE_KG:
		return "%d kg (acima do peso)" % p.weight
	return "%d kg" % p.weight


## Risco extra de lesão pelo sobrepeso (multiplicador).
static func injury_factor(p: Player) -> float:
	var ov := float(p.weight - Physique.default_weight(p.height, p.position)) - 1.5
	return 1.0 + maxf(0.0, ov) * OVER_INJURY


## Garoto recém-criado: a altura sorteada vira a final e ele começa menor e mais magro.
static func setup_young(p: Player, year: int) -> void:
	var age := p.age(year)
	if age > 20:
		p.adult_h = p.height
		return
	var r := _r(p, "cresce")
	var left := float(GROW_LEFT.get(clampi(age, 14, 20), 0.0))
	# Estirão tardio: um em dez ainda vai crescer bem mais do que parece.
	if r.randf() < 0.1 and age <= 17:
		left += r.randf_range(3.0, 7.0)
	var rest := int(round(maxf(0.0, r.randfn(left, left * 0.35))))
	p.adult_h = p.height
	p.height = maxi(150, p.height - rest)
	p.weight = ideal_weight(p, year) + r.randi_range(-2, 1)


## Virada do ano: cresce, ganha massa e, quem tem tendência, volta das férias acima do peso.
## Retorna os jogadores do usuário que voltaram pesados (para o aviso do preparador).
static func yearly(world: GameWorld) -> Array:
	var heavy: Array = []
	var year := world.year
	for p: Player in world.players.values():
		var age := p.age(year)
		var r := _r(p, "ano%d" % year)
		if p.adult_h <= 0:
			p.adult_h = p.height + (int(round(r.randf() * float(GROW_LEFT.get(age, 0.0)))) if age <= 20 else 0)
		if p.height < p.adult_h:
			var g := maxi(1, int(ceil((p.adult_h - p.height) * float(GROW_RATE.get(clampi(age, 14, 20), 1.0)))))
			p.height = mini(p.adult_h, p.height + g)
		var ideal := ideal_weight(p, year)
		if age <= 22:
			# Ganha massa muscular rumo ao peso de atleta.
			p.weight += int(round((ideal - p.weight) * 0.6))
		var pr := prone(p)
		var gain := 0
		if r.randf() < pr * 0.7:
			gain = r.randi_range(1, 3) + (r.randi_range(1, 3) if pr >= 0.6 else 0)
		if age >= 29 and r.randf() < 0.35 + pr * 0.4:
			gain += 1
		if gain > 0:
			p.weight = mini(p.weight + gain, 118)
			if p.club_id >= 0 and world.is_user_club(p.club_id) and overweight(p, year) >= NOTE_KG:
				heavy.append(p)
	if world.has_user() and not heavy.is_empty():
		var names: Array = []
		for p: Player in heavy.slice(0, 4):
			names.append("%s (+%d kg)" % [p.display_name(), overweight(p, year)])
		InboxManager.send(world, "preparador", "Voltaram acima do peso",
			"Na reapresentação, %s chegaram acima do peso. Com o excesso eles perdem velocidade e se machucam mais. Vamos trabalhar isso nas próximas semanas." % ", ".join(names),
			{"k": "screen", "s": "squad"}, int(heavy[0].id), world.user_club_id)
	return heavy


## Semana: o preparador físico tira o excesso aos poucos; quem está parado por lesão engorda.
static func weekly(world: GameWorld) -> void:
	var year := world.year
	var parity := int(world.stats.get("tick_parity", 0)) # o mesmo meio-elenco do PlayerDevelopment
	for p: Player in world.players.values():
		if p.id % 2 == parity or p.club_id < 0:
			continue
		var ov := overweight(p, year)
		var r := _r(p, "sem%d_%d" % [year, world.current_turn()])
		if p.injury_weeks >= 2 and r.randf() < prone(p) * 0.25:
			p.weight += 1
			continue
		if ov <= 0:
			continue
		var prep := People.staff_level(world, "preparador") if world.is_user_club(p.club_id) else 0.6
		var lose := (0.18 + prep * 0.12) * (1.0 + (p.hid("pro") - 10) * 0.05) * 2.0
		if r.randf() < clampf(lose, 0.05, 0.8):
			p.weight -= 1
