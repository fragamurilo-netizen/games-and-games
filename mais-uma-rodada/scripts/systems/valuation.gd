class_name Valuation
extends RefCounted
## Valor de mercado e salários. Escala do dinheiro do jogo:
## overall 50 ≈ $ 45 mil · 60 ≈ $ 165 mil · 70 ≈ $ 610 mil · 80 ≈ $ 2,3 mi · 90 ≈ $ 8 mi.

const VALUE_BASE := 12000.0
const VALUE_GROWTH := 1.14
const WAGE_BASE := 1100.0
const WAGE_GROWTH := 1.115
const MIN_VALUE := 5000
const MARKET_TOP := 600

## Deslocamento da escala econômica: quanto o nível do mundo subiu/desceu desde a criação.
## Mantém valores e salários ancorados ao talento relativo (evita espirais de inflação).
static var shift: float = 0.0


## Overall "percebido" pelo mercado: jovens valem pelo que podem virar (com ruído de avaliação).
static func perceived_rating(p: Player, year: int) -> float:
	var age := p.age(year)
	var eff := p.ovr_f
	if age <= 23:
		var pot := float(p.potential) + p.scout_noise * 0.5
		var w := clampf((24 - age) * 0.09, 0.0, 0.55)
		eff = maxf(eff, eff + (pot - eff) * w)
	return eff - shift


## Nível de referência do mercado: média dos MARKET_TOP melhores jogadores em clubes.
static func market_reference(world: GameWorld) -> float:
	var arr: Array = []
	for p: Player in world.players.values():
		if p.club_id >= 0:
			arr.append(p.ovr_f)
	arr.sort()
	arr.reverse()
	var n := mini(MARKET_TOP, arr.size())
	var s := 0.0
	for i in n:
		s += arr[i]
	return s / maxf(1.0, n)


## Atualiza o deslocamento a partir do mundo (chamar na criação, ao carregar e a cada temporada).
static func refresh_shift(world: GameWorld) -> void:
	var ref := market_reference(world)
	if not world.stats.has("mref0"):
		world.stats["mref0"] = ref
	world.stats["mref"] = ref
	shift = ref - float(world.stats["mref0"])


static func age_factor(age: int) -> float:
	if age <= 19:
		return 1.2
	if age <= 21:
		return 1.25
	if age <= 24:
		return 1.18
	if age <= 27:
		return 1.05
	if age <= 29:
		return 0.9
	match age:
		30:
			return 0.75
		31:
			return 0.6
		32:
			return 0.48
		33:
			return 0.38
		34:
			return 0.28
	return 0.2


static func contract_factor(years_left: int) -> float:
	if years_left <= 0:
		return 0.55
	if years_left == 1:
		return 0.85
	return 1.0


static func position_factor(pos: int) -> float:
	match pos:
		Pos.GK:
			return 0.8
		Pos.ST:
			return 1.1
		Pos.AM, Pos.RW, Pos.LW:
			return 1.05
	return 1.0


static func market_value(p: Player, year: int) -> int:
	var eff := perceived_rating(p, year)
	var v := VALUE_BASE * pow(VALUE_GROWTH, eff - 40.0)
	v *= age_factor(p.age(year))
	v *= contract_factor(p.contract_years_left(year))
	v *= position_factor(p.position)
	# Forma recente pesa um pouco (quem está voando fica mais caro).
	v *= clampf(1.0 + (p.form() - 6.5) * 0.08, 0.85, 1.2)
	return round_value(v)


static func update_value(p: Player, year: int) -> void:
	p.value = market_value(p, year)


static func base_wage(rating: float) -> float:
	return WAGE_BASE * pow(WAGE_GROWTH, rating - 40.0)


## Salário mensal que o jogador pede para assinar/renovar com um clube.
static func wage_demand(p: Player, club: Club, year: int) -> int:
	var age := p.age(year)
	var r := (p.ovr_f - shift) * 0.6 + perceived_rating(p, year) * 0.4
	var w := base_wage(r)
	if club != null:
		w *= 0.8 + club.reputation / 250.0
	w *= p.trait_mult("greed")
	if age >= 34:
		w *= 0.8
	elif age <= 19:
		w *= 0.75
	return round_wage(w)


## Salário "justo" usado na geração inicial (com leve ruído do contrato antigo).
static func initial_wage(p: Player, club: Club, year: int, rng: RandomNumberGenerator) -> int:
	var w := float(wage_demand(p, club, year)) * rng.randf_range(0.8, 1.15)
	return round_wage(w)


static func round_value(v: float) -> int:
	if v >= 1_000_000.0:
		return int(round(v / 50_000.0)) * 50_000
	if v >= 100_000.0:
		return int(round(v / 5_000.0)) * 5_000
	return maxi(MIN_VALUE, int(round(v / 1_000.0)) * 1_000)


static func round_wage(w: float) -> int:
	if w >= 1000.0:
		return int(round(w / 100.0)) * 100
	return maxi(300, int(round(w / 50.0)) * 50)
