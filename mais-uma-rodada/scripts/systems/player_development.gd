class_name PlayerDevelopment
extends RefCounted
## Evolução, envelhecimento, aposentadoria e geração da base.
## - Crescimento: orçamento em pontos de overall (limitado pelo potencial), aplicado semanalmente.
## - Declínio: pontos de atributo, físicos primeiro (ponta veloz cai rápido; zagueiro cerebral dura).
## - Potencial dinâmico: minutos e boas atuações fazem jovens crescerem; banco eterno atrofia.

## [fim do crescimento, início do declínio, ritmo do declínio] por curva
const CURVES: Array = [
	[23, 29, 1.1], # precoce
	[25, 31, 1.0], # normal
	[28, 32, 0.9], # tardio
	[25, 29, 1.4], # declínio precoce
	[26, 33, 0.7], # longevo
]

## Pesos para escolher qual atributo cai com a idade.
const DECLINE_W: Array = [0.07, 0.05, 0.07, 0.24, 0.1, 0.07, 0.05, 0.02, 0.06, 0.05, 0.2, 0.02, 0.0, 0.0, 0.03]


static func curve(p: Player) -> Array:
	var c: Array = CURVES[clampi(p.dev_curve, 0, CURVES.size() - 1)].duplicate()
	if p.position == Pos.GK:
		c[0] += 2
		c[1] += 3
	return c


## Crescimento esperado de overall em uma temporada (antes de minutos/estrutura/personalidade).
static func season_growth(p: Player, age: int) -> float:
	var gap := float(p.potential) - p.ovr_f
	if gap <= 0.0:
		return 0.0
	var c := curve(p)
	if age >= int(c[1]):
		return 0.0
	var t := float(c[0] - age)
	var rate := clampf(0.06 + t * 0.04, 0.02, 0.32)
	if p.dev_curve == Player.CURVE_TARDIO and t > 3.0:
		rate *= 0.8
	var minimum := 1.2 if t >= 4.0 else (0.6 if t >= 1.0 else 0.0)
	return minf(gap, maxf(gap * rate, minimum))


## Pontos de atributo perdidos por temporada pela idade.
static func decline_points(p: Player, age: int) -> float:
	var c := curve(p)
	if age < int(c[1]):
		return 0.0
	return (4.0 + (age - int(c[1])) * 3.2) * float(c[2]) * p.trait_mult("decline_mult")


static func facilities_factor(world: GameWorld, p: Player) -> float:
	if p.club_id < 0:
		return 0.7
	var c := world.club(p.club_id)
	return 0.85 + c.facilities / 100.0 * 0.3


## Evolução semanal de todos os jogadores. minutes: {player_id: minutos no jogo desta rodada}.
## Retorna jogadores que tiveram salto notável (para notícias).
static func weekly_tick(world: GameWorld, minutes: Dictionary) -> Array:
	var rng := world.rng
	var weeks := float(FinanceManager.league_days())
	var notable: Array = []
	for p: Player in world.players.values():
		var age := p.age(world.year)
		var g := season_growth(p, age)
		if g > 0.0:
			var mins: int = minutes.get(p.id, -1)
			var play_f := 1.25 if mins >= 60 else (1.05 if mins > 0 else (0.85 if p.club_id >= 0 else 0.7))
			var add := g / weeks * play_f * facilities_factor(world, p) * p.trait_mult("dev_mult") * rng.randf_range(0.6, 1.4)
			p.dev_acc += add
			if p.dev_acc >= 0.15:
				var before := p.overall
				apply_growth(world, p, p.dev_acc)
				if p.overall >= before + 2:
					notable.append(p)
		var dcl := decline_points(p, age)
		if dcl > 0.0:
			var expected := dcl / weeks
			while expected > 0.0:
				if rng.randf() < minf(1.0, expected):
					apply_decline(rng, p)
				expected -= 1.0
		elif age >= 27 and age <= 33 and rng.randf() < 0.02:
			# Experiência: veteranos ficam mais inteligentes mesmo sem crescer fisicamente.
			var mental: int = [Attr.INT, Attr.DEC, Attr.POS, Attr.VIS][rng.randi_range(0, 3)]
			if p.ovr_f < p.potential:
				p.set_attr(mental, p.attrs[mental] + 1)
				p.recompute_overall()
	return notable


## Converte um orçamento de overall em pontos de atributo (posição dita o que cresce).
static func apply_growth(world: GameWorld, p: Player, budget: float) -> void:
	var rng := world.rng
	var target := minf(p.ovr_f + budget, float(p.potential) + 0.4)
	var w: Array = Pos.WEIGHTS[p.position]
	var young := p.age(world.year) <= 21
	var weights: Array = []
	for i in Attr.COUNT:
		var v: float = w[i] + 0.03
		if i == Attr.DIS or (i == Attr.GOL and p.position != Pos.GK):
			v = 0.0
		elif young and (i == Attr.VEL or i == Attr.FOR or i == Attr.RES):
			v += 0.05
		if p.attrs[i] >= 99:
			v = 0.0
		weights.append(v)
	var guard := 0
	while p.ovr_f < target - 0.05 and guard < 60:
		var i := RngUtil.weighted_index(rng, weights)
		if i < 0:
			break
		p.attrs[i] = mini(99, p.attrs[i] + 1)
		p._pos_cache_dirty = true
		p.recompute_overall()
		guard += 1
	# Débito/crédito para a próxima semana (evita inflação por arredondamento)
	p.dev_acc = clampf(target - p.ovr_f, -1.0, 1.0)


static func apply_decline(rng: RandomNumberGenerator, p: Player) -> void:
	# Físicos caem primeiro, mas o que a posição exige também se perde com os anos.
	var pw: Array = Pos.WEIGHTS[p.position]
	var w: Array = []
	for k in Attr.COUNT:
		w.append(float(DECLINE_W[k]) * 0.55 + float(pw[k]) * 0.45)
	var i := RngUtil.weighted_index(rng, w)
	if i < 0:
		return
	p.attrs[i] = maxi(1, p.attrs[i] - 1)
	p._pos_cache_dirty = true
	p.recompute_overall()


## Ajustes de fim de temporada: potencial dinâmico, explosões e estagnações.
## Retorna {"explosions": [Player], "busts": [Player]}.
static func yearly_review(world: GameWorld) -> Dictionary:
	var rng := world.rng
	var out := {"explosions": [], "busts": []}
	var full := float(FinanceManager.league_days() * 90)
	for p: Player in world.players.values():
		var age := p.age(world.year)
		if age > 23:
			continue
		var share := p.minutes_season / full
		var avg := p.avg_rating()
		if share >= 0.5 and avg >= 7.0:
			p.potential = mini(95, p.potential + rng.randi_range(0, 2))
		elif p.minutes_season < 300 and age >= 19 and p.club_id >= 0:
			p.potential = maxi(p.overall, p.potential - rng.randi_range(0, 2))
		if rng.randf() < 0.025:
			p.potential = maxi(p.overall, p.potential - rng.randi_range(3, 6))
			out["busts"].append(p)
		elif age <= 21 and p.potential - p.overall >= 6 and rng.randf() < 0.02 + share * 0.02:
			var before := p.overall
			apply_growth(world, p, rng.randf_range(2.0, 5.0))
			if p.overall > before:
				out["explosions"].append(p)
	return out


# ---------------------------------------------------------------------------
# Aposentadoria
# ---------------------------------------------------------------------------

static func retirement_chance(world: GameWorld, p: Player) -> float:
	var age := p.age(world.year)
	if p.position == Pos.GK:
		age -= 2
	if p.dev_curve == Player.CURVE_LONGEVO:
		age -= 1
	var base := 0.0
	if age >= 39:
		base = 0.9
	elif age >= 38:
		base = 0.72
	elif age >= 37:
		base = 0.55
	elif age >= 36:
		base = 0.38
	elif age >= 35:
		base = 0.22
	elif age >= 34:
		base = 0.12
	elif age >= 33:
		base = 0.06
	elif age >= 32:
		base = 0.03
	if base <= 0.0:
		return 0.0
	if p.club_id < 0:
		base *= 1.8
	else:
		var c := world.club(p.club_id)
		var level := PlayerGenerator.club_level(c.division, c.reputation, c.arch())
		if p.ovr_f >= level + 2.0:
			base *= 0.6
	if p.injury_weeks > 10:
		base *= 1.5
	return clampf(base, 0.0, 0.97)


## Durante a temporada (≈ rodada 28): veteranos decidem se param no fim do ano.
static func announce_retirements(world: GameWorld) -> Array:
	var out: Array = []
	for p: Player in world.players.values():
		if p.retiring or p.age(world.year) < 32:
			continue
		if world.rng.randf() < retirement_chance(world, p):
			p.retiring = true
			out.append(p)
	return out


## Fim de temporada: quem anunciou se aposenta; livres veteranos também podem parar.
static func process_retirements(world: GameWorld) -> Array:
	var retired: Array = []
	for p: Player in world.players.values().duplicate():
		var go := p.retiring
		if not go and p.club_id < 0 and p.age(world.year) >= 31:
			go = world.rng.randf() < retirement_chance(world, p) * 1.2
		if not go and p.age(world.year) >= 41:
			go = true
		if go:
			retired.append(p)
			_archive_retired(world, p)
			world.remove_player(p)
	return retired


static func _archive_retired(world: GameWorld, p: Player) -> void:
	var notable := p.career_apps >= 150 or p.career_goals >= 50 or p.titles > 0
	for s in p.spells:
		if world.is_user_club(int(s.get("c", -1))) and int(s.get("a", 0)) >= 20:
			notable = true
	if not notable:
		return
	world.retired.append({
		"id": p.id, "name": p.first_name + " " + p.last_name, "ka": p.display_name(),
		"pos": p.position, "nat": p.nationality, "by": p.birth_year, "year": world.year,
		"apps": p.career_apps, "goals": p.career_goals, "assists": p.career_assists, "titles": p.titles,
		"spells": p.spells.duplicate(true), "ovr": p.overall,
	})
	if world.retired.size() > 600:
		world.retired = world.retired.slice(world.retired.size() - 600)


# ---------------------------------------------------------------------------
# Base
# ---------------------------------------------------------------------------

## Novos jovens em todos os clubes. Retorna {club_id: [Player]}.
static func youth_intake(world: GameWorld) -> Dictionary:
	var out := {}
	var used := WorldGenerator.used_names_of(world)
	for c: Club in world.clubs:
		var n := 1 + (1 if c.youth_level >= 55 else 0) + (1 if c.youth_level >= 85 else 0) + (1 if world.rng.randf() < 0.35 else 0)
		var arr: Array = []
		for _i in n:
			arr.append(PlayerGenerator.create_youth(world, world.rng, c, used))
		out[c.id] = arr
	return out
