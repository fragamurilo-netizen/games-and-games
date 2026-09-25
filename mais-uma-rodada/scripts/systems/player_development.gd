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
const DECLINE_W: Array = [0.07, 0.05, 0.07, 0.24, 0.1, 0.07, 0.05, 0.02, 0.06, 0.05, 0.2, 0.02, 0.0, 0.0, 0.03,
	0.08, 0.06, 0.04, 0.26, 0.05, 0.0] # DRI DES CHL ACE REF FRI: a aceleração é a primeira a ir embora


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
	var mentors := _mentor_bonus(world)
	for p: Player in world.players.values():
		if p.id % 2 != parity:
			continue
		# Moral volta aos poucos ao normal (duas semanas de efeito, como o resto do laço).
		p.morale += (62.0 - p.morale) * 0.1
		var cid := p.club_id
		if cid >= 0 and cid == world.user_club_id and p.morale < 62.0:
			p.morale += (62.0 - p.morale) * 0.1 * (ManagerProfile.morale_recovery(world) - 1.0)
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
				var train_f := TrainingManager.growth_mult(world, p) * (ManagerProfile.youth_mult(world) if age <= 21 else 1.0) if cid == world.user_club_id else 1.0
				# Quem joga bem cresce mais; quem vive de notas baixas trava.
				var perf_f := performance_factor(p) if mins > 0 else 1.0
				# Jovens ao lado de um mentor aprendem mais rápido.
				var mentor_f := 1.0 + float(mentors.get(cid, 0.0)) if age <= 22 and cid >= 0 and not p.has_trait("mentor") else 1.0
				# A cabeça conta: moral, confiança no treinador e o nível de quem treina ao lado.
				var mind_f := mind_factor(world, p)
				var env_f := environment_factor(world, p)
				p.dev_acc += g * play_f * growth_f * fac_f * train_f * perf_f * mentor_f * mind_f * env_f * p.trait_mult("dev_mult") * rng.randf_range(0.6, 1.4)
				if p.dev_acc >= 0.15:
					var before := p.overall
					apply_growth(world, p, p.dev_acc, TrainingManager.bias_for(world, p) if cid == world.user_club_id else [])
					if p.overall >= before + 2:
						notable.append(p)
			elif age >= 27 and rng.randf() < 0.04:
				# Experiência: veteranos ficam mais inteligentes mesmo sem crescer fisicamente.
				_experience(rng, p)
		else:
			# Cada corpo envelhece de um jeito (fixo por jogador) e a carga de jogos pesa depois dos 30.
			var body_f := aging_factor(p)
			var load_f := 1.0
			if age >= 30:
				var mins: int = minutes.get(p.id, 0)
				load_f = 1.08 if mins >= 80 else (0.95 if mins == 0 else 1.0)
			var expected := (5.0 + (age - dstart) * 4.0) * float(cv[2]) * p.trait_mult("decline_mult") * decline_f * body_f * load_f
			while expected > 0.0:
				if rng.randf() < minf(1.0, expected):
					apply_decline(rng, p)
				expected -= 1.0
			# A cabeça ainda aprende: veteranos ganham leitura de jogo enquanto o físico cai.
			if rng.randf() < 0.035 * p.trait_mult("dev_mult"):
				_wisdom(rng, p)
	return notable


## Multiplicador de crescimento pela forma recente (notas das últimas partidas).
static func performance_factor(p: Player) -> float:
	if p.recent_ratings.is_empty():
		return 1.0
	return clampf(1.0 + (p.form() - 6.6) * 0.22, 0.82, 1.22)


## Cabeça boa, treino bom: moral e (no clube do usuário) a confiança no treinador, o "carinho"
## que ele recebe. Vai de ~0,85 (desmotivado, sem confiança) a ~1,1 (feliz e bancado).
static func mind_factor(world: GameWorld, p: Player) -> float:
	var f := 1.0 + (p.morale - 62.0) / 400.0
	if p.club_id >= 0 and p.club_id == world.user_club_id and People.has_trust(world, p.id):
		f += (People.trust_of(world, p) - 50.0) / 500.0
	return clampf(f, 0.85, 1.1)


## Treinar com gente melhor faz crescer (garoto no gigante); ser o melhor do treino, menos.
static func environment_factor(world: GameWorld, p: Player) -> float:
	if p.club_id < 0:
		return 0.95
	var lvl := PlayerGenerator.club_level(world.clubs[p.club_id])
	return clampf(1.0 + (lvl - p.ovr_f) * 0.005, 0.95, 1.07)


## Ritmo de envelhecimento próprio do jogador (0,8 a 1,2), estável ao longo da carreira.
static func aging_factor(p: Player) -> float:
	return 1.0 + RngUtil.noise(p.id, 911, p.birth_year) * 0.2


## Bônus de desenvolvimento que os mentores de cada clube dão aos jovens: {club_id: bônus}.
static func _mentor_bonus(world: GameWorld) -> Dictionary:
	var out := {}
	for p: Player in world.players.values():
		if p.club_id >= 0 and p.injury_weeks <= 0 and p.has_trait("mentor"):
			out[p.club_id] = minf(0.16, float(out.get(p.club_id, 0.0)) + float(DatabaseManager.trait_data("mentor").get("mentor", 0.08)))
	return out


## Veterano em declínio ganha um ponto mental, sem teto do potencial.
static func _wisdom(rng: RandomNumberGenerator, p: Player) -> void:
	var mental: int = [Attr.INT, Attr.DEC, Attr.POS, Attr.VIS][rng.randi_range(0, 3)]
	if p.attrs[mental] < 95:
		p.set_attr(mental, p.attrs[mental] + 1)
		p.recompute_overall()


## Lesão grave cobra um preço físico, maior com a idade. Retorna os pontos perdidos.
static func injury_setback(rng: RandomNumberGenerator, p: Player, weeks: int, age: int) -> int:
	if weeks < 8:
		return 0
	var expected := (weeks - 6) * 0.18 * (1.0 + maxf(0.0, age - 27.0) * 0.12) * p.trait_mult("injury_loss_mult")
	var lost := 0
	while expected > 0.0:
		if rng.randf() < minf(1.0, expected):
			var i: int = Attr.PHYSICAL[rng.randi_range(0, Attr.PHYSICAL.size() - 1)]
			if p.attrs[i] > 20:
				p.attrs[i] -= 1
				lost += 1
		expected -= 1.0
	if lost > 0:
		p._pos_cache_dirty = true
		p.recompute_overall()
	return lost


## Quem mais evoluiu e quem mais caiu no elenco durante a temporada.
## Retorna {"up": [{id, name, from, to, age}], "down": [...]} (até 3 de cada).
static func squad_evolution(world: GameWorld, club_id: int) -> Dictionary:
	var c := world.club(club_id)
	var rows: Array = []
	if c != null:
		for pid in c.player_ids:
			var p := world.player(pid)
			if p == null or p.ovr_start < 0:
				continue
			var d := p.season_delta()
			if d != 0:
				rows.append({"id": p.id, "name": p.display_name(), "from": p.ovr_start, "to": p.overall, "age": p.age(world.year), "d": d})
	rows.sort_custom(func(a, b): return int(a["d"]) > int(b["d"]) if a["d"] != b["d"] else int(a["id"]) < int(b["id"]))
	var up: Array = rows.filter(func(r): return int(r["d"]) > 0).slice(0, 3)
	var down_all: Array = rows.filter(func(r): return int(r["d"]) < 0)
	down_all.reverse()
	return {"up": up, "down": down_all.slice(0, 3)}


# ---------------------------------------------------------------------------
# Personalidade viva
# ---------------------------------------------------------------------------

const MAX_TRAITS := 3


## Revisão anual de personalidade: a idade, os prêmios, a fase e o clube mudam as pessoas.
## No máximo uma mudança por jogador por ano. Retorna [{p, t, add, why}].
static func personality_review(world: GameWorld) -> Array:
	var rng := world.rng
	var out: Array = []
	var year := world.year
	var full := FinanceManager.WEEKS * 90.0
	var conflicts: Array = DatabaseManager.personalities().get("conflicts", [])
	for p: Player in world.players.values():
		var age := p.age(year)
		var share := p.minutes_season / full
		var avg := p.avg_rating()
		var won: Array = p.awards_in(year)
		var big_award := false
		for k in won:
			if AwardManager.award_weight(k) >= 3:
				big_award = true
		var ch := {}
		# Perdas: amadurecimento e confiança
		if p.has_trait("inseguro") and share >= 0.45 and avg >= 7.1 and rng.randf() < 0.35:
			ch = {"t": "inseguro", "add": false, "why": "Uma temporada de alto nível acabou com a insegurança."}
		elif p.has_trait("timido") and big_award and rng.randf() < 0.6:
			ch = {"t": "timido", "add": false, "why": "O prêmio deu a confiança que faltava."}
		elif p.has_trait("festeiro") and age >= 29 and rng.randf() < 0.18:
			ch = {"t": "festeiro", "add": false, "why": "Sossegou: agora cuida mais do corpo."}
		elif p.has_trait("temperamental") and age >= 31 and rng.randf() < 0.14:
			ch = {"t": "temperamental", "add": false, "why": "A idade trouxe calma dentro de campo."}
		elif p.has_trait("acomodado") and age <= 27 and share >= 0.6 and avg >= 7.0 and rng.randf() < 0.3:
			ch = {"t": "acomodado", "add": false, "why": "Voltou a ter fome de bola depois de um grande ano."}
		elif p.has_trait("rebelde") and age >= 30 and rng.randf() < 0.12:
			ch = {"t": "rebelde", "add": false, "why": "Aprendeu a conviver com o vestiário."}
		# Ganhos: experiência, idolatria, ego, liderança, rebeldia
		elif age >= 30 and p.career_apps >= 280 and rng.randf() < 0.22:
			ch = {"t": "cascudo", "add": true, "why": "Mais de %d jogos na carreira: já viu de tudo." % p.career_apps}
		elif p.club_id >= 0 and _club_years(p, year) >= 6 and _club_apps(p) >= 150 and rng.randf() < 0.3:
			ch = {"t": "idolo", "add": true, "why": "%d temporadas e %d jogos pelo clube: virou ídolo da torcida." % [_club_years(p, year), _club_apps(p)]}
		elif age >= 29 and p.career_apps >= 250 and p.consistency >= 12 and rng.randf() < 0.08:
			ch = {"t": "lider", "add": true, "why": "A experiência fez dele uma voz ativa no vestiário."}
		elif age >= 31 and p.career_apps >= 300 and rng.randf() < 0.07:
			ch = {"t": "mentor", "add": true, "why": "Passou a adotar os garotos do elenco."}
		elif age <= 24 and big_award and rng.randf() < 0.18:
			ch = {"t": "estrela", "add": true, "why": "O sucesso precoce subiu à cabeça."}
		elif p.unhappy_weeks >= 8 and rng.randf() < 0.25:
			ch = {"t": "rebelde", "add": true, "why": "Meses de insatisfação mudaram o humor dele."}
		elif age <= 21 and p.traits.size() < 2 and rng.randf() < 0.12:
			var ids := DatabaseManager.trait_ids()
			var t: String = ids[RngUtil.weighted_index(rng, DatabaseManager.trait_weights())]
			ch = {"t": t, "add": true, "why": "A personalidade está se formando."}
		if ch.is_empty():
			continue
		var t: String = ch["t"]
		if ch["add"]:
			if p.has_trait(t) or p.traits.size() >= MAX_TRAITS or DatabaseManager.trait_data(t).is_empty():
				continue
			var blocked := false
			for other in p.traits:
				if PlayerGenerator._conflicts(conflicts, String(other), t):
					blocked = true
			if blocked:
				continue
			var nt: Array = p.traits.duplicate()
			nt.append(t)
			p.set_traits(nt)
		else:
			var nt: Array = p.traits.duplicate()
			nt.erase(t)
			if nt.is_empty():
				continue # todo mundo tem ao menos um traço
			p.set_traits(nt)
		p.persona_log.append({"y": year, "t": t, "add": ch["add"], "why": ch["why"]})
		ch["p"] = p
		out.append(ch)
	return out


static func persona_headline(ch: Dictionary) -> String:
	var name := String(DatabaseManager.trait_data(String(ch["t"])).get("name", ch["t"]))
	return ("agora é %s" % name.to_lower()) if ch["add"] else ("deixou de ser %s" % name.to_lower())


static func _club_years(p: Player, year: int) -> int:
	return year - p.joined_year + 1 if p.joined_year > 0 else 0


static func _club_apps(p: Player) -> int:
	if p.spells.is_empty():
		return 0
	var s: Dictionary = p.spells[p.spells.size() - 1]
	return int(s.get("a", 0)) if int(s.get("c", -1)) == p.club_id else 0


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
		if age > 24:
			continue
		var share := p.minutes_season / full
		var avg := p.avg_rating()
		# O que aconteceu na temporada mexe no teto: jogar bem, ser bancado, prêmios, cabeça.
		var up := 0.0
		var down := 0.0
		if share >= 0.5 and avg >= 7.0:
			up += 0.45
		elif share >= 0.3 and avg >= 6.8:
			up += 0.2
		if p.minutes_season < 300 and age >= 19 and p.club_id >= 0:
			down += 0.45
		elif share < 0.15 and age >= 20 and p.club_id >= 0:
			down += 0.2
		var dm := p.trait_mult("dev_mult")
		if dm >= 1.05:
			up += 0.08
		elif dm <= 0.95:
			down += 0.12
		if p.morale < 35.0:
			down += 0.1
		if p.club_id >= 0 and p.club_id == world.user_club_id and People.has_trust(world, p.id):
			var tr := People.trust_of(world, p)
			if tr >= 70.0:
				up += 0.08
			elif tr <= 30.0:
				down += 0.08
		for k in p.awards_in(world.year):
			if AwardManager.award_weight(k) >= 2:
				up += 0.15
				break
		up *= boost_chance
		var roll := rng.randf()
		if roll < up:
			p.potential = mini(94, p.potential + rng.randi_range(1, 3))
		elif roll < up + down:
			p.potential = maxi(p.overall, p.potential - rng.randi_range(1, 3))
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
		n = maxi(1, n + ClubDNA.intake_extra(c)) # uso da base (DNA)
		var arr: Array = []
		for _i in n:
			arr.append(PlayerGenerator.create_youth(world, world.rng, c, used))
		out[c.id] = arr
	return out
