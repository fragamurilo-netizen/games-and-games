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

## Âncora de talento: o nível médio dos melhores jogadores do mundo não pode subir (ou cair)
## indefinidamente ao longo de décadas. O desvio em relação ao mundo recém-criado ajusta,
## de forma suave e igual para todos os clubes, a base, o crescimento e o declínio.
const TALENT_PER_CLUB := 16 # titulares e primeiros reservas de cada clube

## Pesos para escolher qual atributo cai com a idade.
const DECLINE_W: Array = [0.07, 0.05, 0.07, 0.24, 0.1, 0.07, 0.05, 0.02, 0.06, 0.05, 0.2, 0.02, 0.0, 0.0, 0.03]


## Overall médio dos melhores jogadores do mundo (TALENT_PER_CLUB por clube).
static func talent_index(world: GameWorld) -> float:
	var arr := PackedFloat32Array()
	for p: Player in world.players.values():
		arr.append(p.ovr_f)
	arr.sort()
	var n := mini(world.clubs.size() * TALENT_PER_CLUB, arr.size())
	var s := 0.0
	for i in n:
		s += arr[arr.size() - 1 - i]
	return s / maxf(1.0, float(n))


## Recalcula o desvio de talento (chamado no fim de cada temporada). Controle proporcional
## + integral: o termo acumulado corrige tendências lentas que o proporcional sozinho deixaria.
static func update_talent_drift(world: GameWorld) -> float:
	var idx := talent_index(world)
	if not world.stats.has("talent_ref"):
		world.stats["talent_ref"] = idx
	var raw := idx - float(world.stats["talent_ref"])
	var integ := clampf(float(world.stats.get("talent_integ", 0.0)) + raw * 0.25, -5.0, 5.0)
	world.stats["talent_integ"] = integ
	world.stats["talent_raw"] = raw
	world.stats["talent_drift"] = raw + integ
	return raw + integ


static func talent_drift(world: GameWorld) -> float:
	return float(world.stats.get("talent_drift", 0.0))


## Evolução semanal de todos os jogadores. minutes: {player_id: minutos no jogo desta rodada}.
## Retorna jogadores que tiveram salto notável (para notícias).
static func weekly_tick(world: GameWorld, minutes: Dictionary, clubs_played: Dictionary = {}) -> Array:
	var rng := world.rng
	# Metade dos jogadores por semana, com o dobro do efeito: mesmo total, metade do custo.
	var parity := int(world.stats.get("tick_parity", 0))
	world.stats["tick_parity"] = 1 - parity
	var weeks := FinanceManager.WEEKS * 0.5
	var notable: Array = []
	var drift := talent_drift(world)
	var growth_f := clampf(1.0 - drift * 0.06, 0.55, 1.3) / weeks
	var decline_f := clampf(1.0 + drift * 0.05, 0.75, 1.5) / weeks
	var year := world.year
	var clubs := world.clubs
	for p: Player in world.players.values():
		if p.id % 2 != parity:
			continue
		# Moral volta aos poucos ao normal (duas semanas de efeito, como o resto do laço).
		p.morale += (62.0 - p.morale) * 0.1
		var cid := p.club_id
		# Quem ficou fora do jogo da semana: estrelas e titulares reclamam do banco.
		if cid >= 0 and clubs_played.has(cid) and not minutes.has(p.id) and p.injury_weeks <= 0 and p.suspension <= 0:
			if p.squad_status <= Player.STATUS_STARTER:
				p.morale = maxf(0.0, p.morale - 5.0 * p.trait_mult("morale_volatility"))
			elif p.squad_status == Player.STATUS_PROSPECT and year - p.birth_year >= 19:
				p.morale = maxf(0.0, p.morale - 1.2)
		var age := year - p.birth_year
		var cv: Array = CURVES[p.dev_curve]
		var gk := p.position == Pos.GK
		var dstart: int = int(cv[1]) + (3 if gk else 0)
		if age < dstart:
			var gap := float(p.potential) - p.ovr_f
			if gap > 0.0:
				var t := float(int(cv[0]) + (2 if gk else 0) - age)
				var rate := clampf(0.06 + t * 0.04, 0.02, 0.32)
				if p.dev_curve == Player.CURVE_TARDIO and t > 3.0:
					rate *= 0.8
				var minimum := 1.2 if t >= 4.0 else (0.6 if t >= 1.0 else 0.0)
				var g := minf(gap, maxf(gap * rate, minimum))
				var mins: int = minutes.get(p.id, -1)
				var play_f := 1.25 if mins >= 60 else (1.05 if mins > 0 else (0.85 if cid >= 0 else 0.7))
				var fac_f: float = (0.85 + clubs[cid].facilities * 0.003) if cid >= 0 else 0.7
				var train_f := TrainingManager.growth_mult(world, p) if cid == world.user_club_id else 1.0
				p.dev_acc += g * play_f * growth_f * fac_f * train_f * p.trait_mult("dev_mult") * rng.randf_range(0.6, 1.4)
				if p.dev_acc >= 0.15:
					var before := p.overall
					apply_growth(world, p, p.dev_acc, TrainingManager.bias_for(world, p) if cid == world.user_club_id else [])
					if p.overall >= before + 2:
						notable.append(p)
			elif age >= 27 and rng.randf() < 0.04:
				# Experiência: veteranos ficam mais inteligentes mesmo sem crescer fisicamente.
				_experience(rng, p)
		else:
			var expected := (5.0 + (age - dstart) * 4.0) * float(cv[2]) * p.trait_mult("decline_mult") * decline_f
			while expected > 0.0:
				if rng.randf() < minf(1.0, expected):
					apply_decline(rng, p)
				expected -= 1.0
	return notable


static func _experience(rng: RandomNumberGenerator, p: Player) -> void:
	var mental: int = [Attr.INT, Attr.DEC, Attr.POS, Attr.VIS][rng.randi_range(0, 3)]
	if p.ovr_f < p.potential:
		p.set_attr(mental, p.attrs[mental] + 1)
		p.recompute_overall()


## Converte um orçamento de overall em pontos de atributo (posição dita o que cresce).
static var _growth_w: Array = [] # [posição][jovem 0/1] -> pesos (pré-calculados)


static func _growth_weights(pos: int, young: bool) -> Array:
	if _growth_w.is_empty():
		for ps in Pos.COUNT:
			var pair: Array = []
			for y in 2:
				var w: Array = Pos.WEIGHTS[ps]
				var weights: Array = []
				for i in Attr.COUNT:
					var v: float = w[i] + 0.03
					if i == Attr.DIS or (i == Attr.GOL and ps != Pos.GK):
						v = 0.0
					elif y == 1 and (i == Attr.VEL or i == Attr.FOR or i == Attr.RES):
						v += 0.05
					weights.append(v)
				pair.append(weights)
			_growth_w.append(pair)
	return _growth_w[pos][1 if young else 0]


## `bias`: [[atributo, multiplicador], ...] do treino (foco do time e individual).
static func apply_growth(world: GameWorld, p: Player, budget: float, bias: Array = []) -> void:
	var rng := world.rng
	var target := minf(p.ovr_f + budget, float(p.potential) + 0.4)
	var weights := _growth_weights(p.position, p.age(world.year) <= 21)
	if not bias.is_empty():
		weights = weights.duplicate()
		for b in bias:
			var i: int = b[0]
			weights[i] = maxf(float(weights[i]), 0.04) * float(b[1])
	var guard := 0
	while p.ovr_f < target - 0.05 and guard < 60:
		var i := RngUtil.weighted_index(rng, weights)
		if i < 0:
			break
		guard += 1
		if p.attrs[i] >= 99:
			continue
		p.attrs[i] = mini(99, p.attrs[i] + 1)
		p._pos_cache_dirty = true
		p.recompute_overall()
	# Débito/crédito para a próxima semana (evita inflação por arredondamento)
	p.dev_acc = clampf(target - p.ovr_f, -1.0, 1.0)


static var _decline_w: Array = [] # por posição (pré-calculado: o laço semanal não aloca)


static func apply_decline(rng: RandomNumberGenerator, p: Player) -> void:
	# Físicos caem primeiro, mas o que a posição exige também se perde com os anos.
	if _decline_w.is_empty():
		for pos in Pos.COUNT:
			var pw: Array = Pos.WEIGHTS[pos]
			var w: Array = []
			for k in Attr.COUNT:
				w.append(float(DECLINE_W[k]) * 0.55 + float(pw[k]) * 0.45)
			_decline_w.append(w)
	var i := RngUtil.weighted_index(rng, _decline_w[p.position])
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
	var full := FinanceManager.WEEKS * 90.0
	var boost_chance := clampf(1.0 - talent_drift(world) * 0.15, 0.2, 1.0)
	for p: Player in world.players.values():
		var age := p.age(world.year)
		if age > 23:
			continue
		var share := p.minutes_season / full
		var avg := p.avg_rating()
		if share >= 0.5 and avg >= 7.0 and rng.randf() < boost_chance:
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
		var level := PlayerGenerator.club_level(c)
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
		if c.id == world.user_club_id:
			continue # a base do usuário tem garotos de verdade (YouthManager)
		var n := 1 + (1 if c.youth_level >= 55 else 0) + (1 if c.youth_level >= 85 else 0) + (1 if world.rng.randf() < 0.35 else 0)
		var arr: Array = []
		for _i in n:
			arr.append(PlayerGenerator.create_youth(world, world.rng, c, used))
		out[c.id] = arr
	return out
