class_name YouthManager
extends RefCounted
## Categorias de base do clube do usuário: sub-15, sub-17 e sub-20, com as ligas sub-17 e sub-20.
##
## A base do usuário tem jogadores de verdade (world.academy: id → Player, fora de world.players):
## eles treinam, jogam, evoluem e podem subir ao elenco, ser vendidos ou dispensados.
##   - Cada jogo escala um time de verdade (um goleiro, quatro defensores, três meias e três atacantes)
##     com rodízio: quem joga ganha minutos, gols, assistências e notas, e evolui mais.
##   - O potencial aparece como uma faixa que fica mais estreita com o tempo de casa e o coordenador.
##   - No fim do ano alguns dão o estirão (ganham potencial) e outros estagnam.
##   - A captação escolhe onde procurar (região, país ou exterior) e qual setor priorizar, e uma
##     peneira por temporada traz candidatos para aprovar ou não.
##   - Clubes maiores fazem propostas pelos garotos (EventManager, evento "youth_bid").
##   - Os revelados pela base ficam registrados, com o que renderam em vendas.
## Os outros clubes entram nas ligas com uma força derivada do nível da base e três destaques com
## nome (para a artilharia). A cada virada de ano chegam novos garotos.
##
## Estado extra em world.youth: {region, focus, trial (ano da última peneira), cands (candidatos da
## peneira), u17 (liga sub-17), grads (revelados), cost (gasto da captação no ano)}.

const MIN_AGE := 14
const MAX_AGE := 19 # quem passa disso precisa subir ou sair
const TARGET_SIZE := 20
const MAX_SIZE := 30

const CAT_U15 := "sub15"
const CAT_U17 := "sub17"
const CAT_U20 := "sub20"
const CATEGORIES: Array = [[CAT_U20, "Sub-20", "18 e 19 anos"], [CAT_U17, "Sub-17", "16 e 17 anos"], [CAT_U15, "Sub-15", "14 e 15 anos"]]

## Onde a captação procura garotos. cost: multiplicador do custo anual da rede de observadores.
const REGIONS := {
	"local": {"name": "Região do clube", "desc": "Mais garotos da cidade, identificação com a torcida e custo zero. Nível médio um pouco menor.",
		"cost": 0.0, "extra": 1, "target": -1.5, "import": 0.0, "gem": 0.85, "home": 0.9},
	"nacional": {"name": "Todo o país", "desc": "Observadores espalhados pelo país. Equilíbrio entre custo e qualidade.",
		"cost": 1.0, "extra": 0, "target": 0.0, "import": 0.03, "gem": 1.0, "home": 0.45},
	"internacional": {"name": "Internacional", "desc": "Rede no exterior: mais joias raras, garotos melhores e custo alto. Pela regra da FIFA, estrangeiros só a partir dos 18 anos (16 entre países europeus).",
		"cost": 3.0, "extra": 0, "target": 1.5, "import": 0.3, "gem": 1.5, "home": 0.3},
}
const REGION_ORDER: Array[String] = ["local", "nacional", "internacional"]

## Setor priorizado na captação (grupo de posições, -1 = equilibrado).
const FOCUS := {
	"equilibrado": {"name": "Equilibrado", "g": -1},
	"gol": {"name": "Goleiros", "g": Pos.G_GK},
	"defesa": {"name": "Defensores", "g": Pos.G_DEF},
	"meio": {"name": "Meio-campistas", "g": Pos.G_MID},
	"ataque": {"name": "Atacantes", "g": Pos.G_ATT},
}
const FOCUS_ORDER: Array[String] = ["equilibrado", "gol", "defesa", "meio", "ataque"]

const POS_WEIGHTS: Array = [1.0, 1.0, 1.6, 1.0, 1.0, 1.4, 1.0, 0.6, 0.6, 0.9, 0.9, 1.6]

## Time dos jogos da base (4-3-3), na ordem em que as vagas são preenchidas.
const XI_SHAPE: Array = [Pos.GK, Pos.ST, Pos.CB, Pos.CB, Pos.CM, Pos.RB, Pos.LB, Pos.DM, Pos.CM, Pos.RW, Pos.LW]


# ---------------------------------------------------------------------------
# Estado e categorias
# ---------------------------------------------------------------------------

static func state(world: GameWorld) -> Dictionary:
	var s := world.youth
	if not s.has("region"):
		s["region"] = "nacional"
	if not s.has("focus"):
		s["focus"] = "equilibrado"
	if not s.has("grads"):
		s["grads"] = []
	if not s.has("cands"):
		s["cands"] = []
	return s


static func category(p: Player, year: int) -> String:
	var a := p.age(year)
	if a >= 18:
		return CAT_U20
	if a >= 16:
		return CAT_U17
	return CAT_U15


static func category_name(cat: String) -> String:
	for c in CATEGORIES:
		if c[0] == cat:
			return c[1]
	return cat


static func academy(world: GameWorld) -> Array:
	var out: Array = world.academy.values()
	out.sort_custom(func(a: Player, b: Player): return a.overall > b.overall if a.overall != b.overall else a.id < b.id)
	return out


static func in_category(world: GameWorld, cat: String) -> Array:
	return academy(world).filter(func(p: Player): return category(p, world.year) == cat)


## Anos completos na base (quem chegou nesta temporada tem 0).
static func years_in(world: GameWorld, p: Player) -> int:
	return maxi(0, world.year - p.joined_year)


# ---------------------------------------------------------------------------
# Potencial: faixa que estreita com o tempo
# ---------------------------------------------------------------------------

## Quanto o clube já conhece o garoto (0.3..0.92): coordenador da base, anos de casa e jogos.
static func precision(world: GameWorld, p: Player) -> float:
	var pr := 0.3 + People.staff_level(world, "base") * 0.3 + years_in(world, p) * 0.12
	if p.stats[Player.S_APPS] >= 10:
		pr += 0.08
	return clampf(pr, 0.3, 0.92)


## Faixa estimada de potencial [mínimo, máximo]. O potencial real sempre está dentro dela.
static func potential_range(world: GameWorld, p: Player) -> Array:
	var pr := precision(world, p)
	var mid := p.potential_estimate(pr)
	var half := int(round((1.0 - pr) * 9.0)) + 1
	return [clampi(mid - half, p.overall, 94), clampi(mid + half, p.overall, 94)]


static func potential_text(world: GameWorld, p: Player) -> String:
	var r := potential_range(world, p)
	if int(r[0]) == int(r[1]):
		return "Pot. %d" % int(r[0])
	return "Pot. %d–%d" % [int(r[0]), int(r[1])]


static func potential_label_of(world: GameWorld, p: Player) -> String:
	var r := potential_range(world, p)
	return Player.potential_label(int(round((int(r[0]) + int(r[1])) / 2.0)))


# ---------------------------------------------------------------------------
# Elenco da base e captação
# ---------------------------------------------------------------------------

## Garante que o clube do usuário tenha base (nova carreira ou troca de clube).
static func ensure_academy(world: GameWorld) -> void:
	if not world.has_user():
		return
	state(world)
	var club := world.user_club()
	for p: Player in world.academy.values():
		if p.club_id != club.id:
			world.academy.erase(p.id) # base do clube antigo fica por lá
	if world.academy.size() >= 8:
		return
	var used := WorldGenerator.used_names_of(world)
	while world.academy.size() < TARGET_SIZE:
		var kid := _new_kid(world, club, world.rng.randi_range(MIN_AGE, 18), used)
		kid.joined_year = world.year - world.rng.randi_range(0, maxi(0, kid.age(world.year) - MIN_AGE))


## Idade mínima para uma transferência internacional de menor (FIFA, art. 19):
## 18 anos, ou 16 quando os dois países são europeus.
static func min_foreign_age(from_nation: String, to_nation: String) -> int:
	if from_nation == to_nation:
		return 0
	var eu := String(DatabaseManager.nation(from_nation).get("confed", "")) == "UEFA" and String(DatabaseManager.nation(to_nation).get("confed", "")) == "UEFA"
	return 16 if eu else 18


static func region_cfg(world: GameWorld) -> Dictionary:
	return REGIONS.get(String(state(world)["region"]), REGIONS["nacional"])


static func set_region(world: GameWorld, region: String) -> void:
	if REGIONS.has(region):
		state(world)["region"] = region


static func set_focus(world: GameWorld, focus: String) -> void:
	if FOCUS.has(focus):
		state(world)["focus"] = focus


## Custo anual da rede de observadores (cobrado na virada do ano).
static func scouting_cost(world: GameWorld, region: String = "") -> int:
	if region == "":
		region = String(state(world)["region"])
	var f := float(REGIONS.get(region, REGIONS["nacional"])["cost"])
	if f <= 0.0:
		return 0
	return Valuation.round_wage(maxf(20000.0, FinanceManager.expected_revenue(world.user_club()) * 0.003) * f)


static func _pos_weights(world: GameWorld) -> Array:
	var g := int(FOCUS.get(String(state(world)["focus"]), FOCUS["equilibrado"])["g"])
	var w: Array = POS_WEIGHTS.duplicate()
	if g >= 0:
		for i in w.size():
			if Pos.group(i) == g:
				w[i] = float(w[i]) * (4.0 if g == Pos.G_GK else 2.5)
	return w


## Cria um garoto para a base do usuário. `quality` desloca o nível (peneira < captação normal).
static func _new_kid(world: GameWorld, club: Club, age: int, used: Dictionary, quality: float = 0.0, spread: float = 4.5, gem_mult: float = 1.0) -> Player:
	var rng := world.rng
	var reg := region_cfg(world)
	var pos: int = RngUtil.weighted_index(rng, _pos_weights(world))
	var level := PlayerGenerator.league_level(club)
	var drift := clampf(float(world.stats.get("talent_drift", 0.0)), -8.0, 8.0)
	var nation_bonus := float(DatabaseManager.nation(club.nation).get("youth", 0.0))
	var target := level - 22.0 + club.youth_level * 0.07 + rng.randfn(0.0, spread) + (age - 15) * 2.2 - drift + nation_bonus * 0.4 + float(reg["target"]) + quality
	target = clampf(target, 18.0, 68.0)
	var imp := float(reg["import"])
	var nat := club.nation
	if age >= 16 and rng.randf() < imp:
		nat = PlayerGenerator.pick_import(rng, club.nation)
		if age < min_foreign_age(nat, club.nation):
			nat = club.nation
	var p := PlayerGenerator.create(world, rng, pos, target, age, nat, club.city, used)
	ClubPolicy.apply_rule(world, rng, club, p, ClubPolicy.generation_rule(rng, club), used)
	p.potential = PlayerGenerator.youth_potential(rng, p.overall, club.youth_level, drift, nation_bonus)
	var gm := float(reg["gem"]) * gem_mult
	if gm > 1.0 and rng.randf() < (gm - 1.0) * 0.012:
		p.potential = clampi(p.potential + rng.randi_range(6, 12), p.overall + 2, 94)
	elif gm < 1.0 and rng.randf() < (1.0 - gm) * 0.5:
		p.potential = maxi(p.overall + 2, p.potential - rng.randi_range(1, 3))
	p.club_id = club.id
	p.squad_status = Player.STATUS_PROSPECT
	p.wage = 0
	p.contract_end = world.year
	p.joined_year = world.year
	if p.nationality == club.nation and rng.randf() < float(reg["home"]) and not ClubPolicy.of(club).has("only"):
		p.hometown = club.city
	Valuation.update_value(p, world.year)
	world.academy[p.id] = p
	return p


## Quantos garotos chegam na virada do ano.
static func intake_count(world: GameWorld, club: Club) -> int:
	return 4 + (1 if club.youth_level >= 55 else 0) + (1 if club.youth_level >= 80 else 0) + int(region_cfg(world)["extra"])


# ---------------------------------------------------------------------------
# Peneira (uma por temporada)
# ---------------------------------------------------------------------------

static func trial_cost(world: GameWorld) -> int:
	return Valuation.round_wage(maxf(10000.0, FinanceManager.expected_revenue(world.user_club()) * 0.0008))


static func can_trial(world: GameWorld) -> bool:
	return world.has_user() and int(state(world).get("trial", 0)) != world.year


## Faz a peneira: paga o custo e gera candidatos (ficam em world.youth.cands até a decisão).
static func run_trial(world: GameWorld) -> Array:
	if not can_trial(world):
		return []
	var s := state(world)
	var club := world.user_club()
	club.add_ledger("investimentos", -trial_cost(world))
	s["trial"] = world.year
	var used := WorldGenerator.used_names_of(world)
	var n := 4 + world.rng.randi_range(0, 2)
	var cands: Array = []
	for _i in n:
		var kid := _new_kid(world, club, world.rng.randi_range(MIN_AGE, 17), used, -3.0, 6.5, 1.3)
		world.academy.erase(kid.id) # só entra se for aprovado
		kid.hometown = club.city if world.rng.randf() < 0.7 else kid.hometown
		cands.append(kid.to_dict())
	s["cands"] = cands
	world.stat_add("youth_trials")
	return candidates(world)


static func candidates(world: GameWorld) -> Array:
	var out: Array = []
	for d in state(world)["cands"]:
		out.append(Player.from_dict(d))
	return out


static func accept_candidate(world: GameWorld, pid: int) -> String:
	var s := state(world)
	if world.academy.size() >= MAX_SIZE:
		return "A base está cheia (%d garotos)." % MAX_SIZE
	var cands: Array = s["cands"]
	for i in cands.size():
		if int(cands[i]["id"]) == pid:
			var p := Player.from_dict(cands[i])
			p.joined_year = world.year
			world.academy[p.id] = p
			cands.remove_at(i)
			return "%s foi aprovado na peneira!" % p.display_name()
	return "Candidato não encontrado."


static func dismiss_candidates(world: GameWorld) -> void:
	state(world)["cands"] = []


# ---------------------------------------------------------------------------
# Subir, vender, dispensar e os revelados
# ---------------------------------------------------------------------------

## Melhor garoto pronto para subir (evento "joia da base").
static func best_prospect(world: GameWorld, club: Club) -> Player:
	var best: Player = null
	for p: Player in world.academy.values():
		if p.age(world.year) < 17:
			continue
		if best == null or p.potential_estimate(0.6) > best.potential_estimate(0.6):
			best = p
	if best == null:
		return null
	# Só vale o alerta se ele já estiver perto do nível do elenco
	var weakest := 99
	for q: Player in world.squad(club):
		weakest = mini(weakest, q.overall)
	return best if best.overall >= weakest - 8 or best.potential_estimate(0.6) >= 72 else null


## Sobe um garoto para o elenco profissional. Retorna a mensagem para a interface.
static func promote(world: GameWorld, p: Player) -> String:
	var club := world.user_club()
	if not world.academy.has(p.id):
		return "Ele não está mais na base."
	if club.player_ids.size() >= int(DatabaseManager.squad_rules()["max_players"]):
		return "Elenco cheio: libere uma vaga antes de subir %s." % p.display_name()
	world.academy.erase(p.id)
	var years_home := years_in(world, p)
	p.reset_season_stats()
	p.club_id = -1
	PlayerGenerator.sign_to_club(world, world.rng, p, club, false)
	p.squad_status = Player.STATUS_PROSPECT
	p.contract_end = world.year + 3
	p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(club.league_cfg().get("wage", 0.5)))
	p.morale = minf(100.0, p.morale + 12.0)
	Valuation.update_value(p, world.year)
	world.stat_add("youth_promoted")
	_add_grad(world, p, club.id, 0, years_home)
	NewsManager.post_raw(world, "%s sobe para o profissional" % p.display_name(),
		"Aos %d anos, %s (%s) deixa a base do %s e passa a treinar com o elenco principal." % [p.age(world.year), p.display_name(), Pos.name_of(p.position).to_lower(), club.short_name],
		club.id, p.id, NewsEvent.IMP_HIGH, "base")
	return "%s subiu para o elenco principal!" % p.display_name()


## Vende um garoto da base para outro clube (proposta aceita). Fica com % de uma revenda futura.
static func sell(world: GameWorld, p: Player, buyer: Club, fee: int, sell_on: float = 0.2) -> String:
	var club := world.user_club()
	if not world.academy.has(p.id) or buyer == null:
		return "Negócio desfeito."
	var years_home := years_in(world, p)
	world.academy.erase(p.id)
	p.reset_season_stats()
	p.club_id = -1
	PlayerGenerator.sign_to_club(world, world.rng, p, buyer, false)
	p.squad_status = Player.STATUS_PROSPECT
	p.contract_end = world.year + 3
	p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(buyer.league_cfg().get("wage", 0.5)))
	if sell_on > 0.0:
		p.clauses = {"so": club.id, "pct": sell_on}
	club.add_ledger("vendas", fee)
	buyer.add_ledger("compras", -fee)
	world.stat_add("youth_sold")
	_add_grad(world, p, club.id, fee, years_home)
	NewsManager.post_raw(world, "%s vende %s ao %s" % [club.short_name, p.display_name(), buyer.short_name],
		"Revelado na base do %s, %s (%d anos) foi vendido ao %s por %s. O clube fica com %d%% de uma venda futura." % [club.short_name, p.display_name(), p.age(world.year), buyer.name, Fmt.money(fee), int(round(sell_on * 100.0))],
		club.id, p.id, NewsEvent.IMP_HIGH, "base")
	return "%s vendido ao %s por %s." % [p.display_name(), buyer.short_name, Fmt.money(fee)]


static func release(world: GameWorld, p: Player) -> void:
	world.academy.erase(p.id)


static func _add_grad(world: GameWorld, p: Player, club_id: int, fee: int, years_home: int) -> void:
	var grads: Array = state(world)["grads"]
	grads.append({"id": p.id, "n": p.display_name(), "pos": p.position, "y": world.year, "c": club_id, "fee": fee,
		"yrs": years_home, "o": p.overall, "age": p.age(world.year)})
	if grads.size() > 80:
		grads.remove_at(0)


## Revelados pela base do clube atual, do mais recente ao mais antigo.
## Cada item: o registro salvo + "p" (Player ou null se aposentado).
static func graduates(world: GameWorld) -> Array:
	var out: Array = []
	for g in state(world)["grads"]:
		if int(g.get("c", -1)) != world.user_club_id:
			continue
		var e: Dictionary = g.duplicate()
		e["p"] = world.players.get(int(g["id"]), null)
		out.append(e)
	out.reverse()
	return out


static func sales_total(world: GameWorld) -> int:
	var t := 0
	for g in graduates(world):
		t += int(g.get("fee", 0))
	return t


## Garoto que chama a atenção de clubes maiores (evento de proposta).
static func bid_target(world: GameWorld) -> Player:
	var best: Player = null
	for p: Player in world.academy.values():
		if p.age(world.year) < 15 or p.potential < 68:
			continue
		if int(Dictionary(world.stats.get("yb_skip", {})).get(str(p.id), 0)) == world.year:
			continue # no máximo uma proposta por garoto em cada temporada
		if best == null or p.potential > best.potential:
			best = p
	return best


## Clube interessado num garoto: bem maior que o do usuário. De fora do país só se a idade
## permitir a transferência internacional. Retorna null se ninguém se encaixar.
static func bid_buyer(world: GameWorld, p: Player) -> Club:
	var club := world.user_club()
	var age := p.age(world.year)
	var cands: Array = []
	for c: Club in world.clubs:
		if c.id == club.id or c.tier != 1 or c.reputation < club.reputation + 10.0:
			continue
		if age < min_foreign_age(club.nation, c.nation):
			continue
		cands.append(c)
	if cands.is_empty():
		return null
	cands.sort_custom(func(a: Club, b: Club): return a.reputation > b.reputation if a.reputation != b.reputation else a.id < b.id)
	return cands[world.rng.randi_range(0, mini(cands.size(), 25) - 1)]


## Valor de uma proposta por um garoto da base (potencial pesa mais que o nível atual).
static func bid_fee(world: GameWorld, p: Player, buyer: Club) -> int:
	var base := maxf(float(p.value), Valuation.base_wage(float(p.potential)) * 30.0)
	var pot_f := 1.0 + maxf(0.0, p.potential - 70.0) * 0.08
	return Valuation.round_value(base * pot_f * world.rng.randf_range(1.1, 1.8) * (0.8 + buyer.reputation / 250.0))


# ---------------------------------------------------------------------------
# Evolução semanal e virada de ano
# ---------------------------------------------------------------------------

## Jogos já disputados pelo time de uma categoria nesta temporada.
static func team_games(world: GameWorld, cat: String) -> int:
	var yl := league(world, "u20" if cat == CAT_U20 else "u17")
	if yl.is_empty() or not yl["table"].has(world.user_club_id):
		return 0
	return int(yl["table"][world.user_club_id]["pl"])


## Fator de minutos: quem joga evolui mais; o sub-15 disputa torneios internos (fator neutro).
static func play_factor(world: GameWorld, p: Player) -> float:
	var cat := category(p, world.year)
	if cat == CAT_U15:
		return 1.0 + minf(0.1, p.stats[Player.S_APPS] * 0.02)
	var games := team_games(world, cat)
	if games < 3:
		return 1.0
	var ratio := clampf(float(p.stats[Player.S_APPS]) / float(games), 0.0, 1.0)
	return 0.78 + 0.42 * ratio


## Treino semanal da base: evolui conforme idade, potencial, nível da base, curva e minutos.
static func weekly(world: GameWorld) -> void:
	if world.academy.is_empty():
		return
	var club := world.user_club()
	var focus := TrainingManager.youth_mult(world)
	for p: Player in world.academy.values():
		var gap := float(p.potential) - p.ovr_f
		if gap <= 0.0:
			continue
		var age := p.age(world.year)
		var age_f := 1.15 if age <= 17 else 1.0
		if age <= 17 and p.dev_curve == Player.CURVE_PRECOCE:
			age_f *= 1.2
		elif age <= 17 and p.dev_curve == Player.CURVE_TARDIO:
			age_f *= 0.8
		var budget := gap * 0.005 * age_f * (0.75 + club.youth_level / 250.0) * play_factor(world, p) * focus * p.trait_mult("dev_mult") + p.dev_acc
		PlayerDevelopment.apply_growth(world, p, maxf(0.0, budget))
		p.morale = clampf(p.morale + (65.0 - p.morale) * 0.1, 0.0, 100.0)


## Balanço do ano de cada garoto: estirão (ganha potencial) ou estagnação (perde).
## Retorna [{p, up (bool), d (pontos), why}].
static func yearly_review(world: GameWorld) -> Array:
	var out: Array = []
	var rng := world.rng
	var coord := People.staff_level(world, "base")
	for p: Player in world.academy.values():
		var age := p.age(world.year)
		var cat := category(p, world.year)
		var apps := p.stats[Player.S_APPS]
		var games := team_games(world, cat)
		var avg := p.avg_rating()
		var up := 0.08 + coord * 0.08
		var down := 0.05
		if p.dev_curve == Player.CURVE_TARDIO:
			up += 0.22
		if apps >= 8 and avg >= 7.0:
			up += 0.12
		if cat != CAT_U15 and games >= 8 and apps < games * 0.2:
			down += 0.12
		for t in ["profissional", "esforcado", "perfeccionista"]:
			if p.has_trait(t):
				up += 0.06
		for t in ["festeiro", "acomodado"]:
			if p.has_trait(t):
				down += 0.1
		if p.morale < 40.0:
			down += 0.05
		var r := rng.randf()
		if r < up:
			var d := rng.randi_range(3, 7) if p.dev_curve == Player.CURVE_TARDIO else rng.randi_range(2, 5)
			p.potential = mini(94, p.potential + d)
			var why := "Deu o estirão: ganhou corpo e velocidade." if age <= 17 else "Temporada de afirmação: o teto dele subiu."
			if age <= 17:
				PlayerDevelopment.apply_growth(world, p, 1.5, [[Attr.VEL, 3.0], [Attr.FOR, 3.0], [Attr.RES, 3.0]])
			elif apps >= 8 and avg >= 7.0:
				why = "Brilhou nos jogos da base (nota %.1f): o teto dele subiu." % avg
			out.append({"p": p, "up": true, "d": d, "why": why})
		elif r < up + down:
			var d2 := rng.randi_range(2, 5)
			var floor_pot := p.overall + 1
			d2 = mini(d2, maxi(0, p.potential - floor_pot))
			if d2 <= 0:
				continue
			p.potential -= d2
			var why2 := "Jogou pouco e parou de evoluir."
			if p.has_trait("festeiro") or p.has_trait("acomodado"):
				why2 = "Falta de dedicação: a evolução travou."
			elif p.morale < 40.0:
				why2 = "Desanimado, rendeu abaixo nos treinos."
			out.append({"p": p, "up": false, "d": d2, "why": why2})
	return out


## Fim de temporada: balanço, todos envelhecem um ano; quem passou da idade sai; chegam novos garotos.
## Retorna {"left": [nomes], "new": [Player], "changes": [{id, name, up, d, why}], "cost": custo da captação}.
static func season_turnover(world: GameWorld) -> Dictionary:
	var out := {"left": [], "new": [], "changes": [], "cost": 0}
	if not world.has_user():
		return out
	var club := world.user_club()
	# O balanço usa os números da temporada que terminou (ano anterior ao atual).
	world.year -= 1
	for ch in yearly_review(world):
		var cp: Player = ch["p"]
		out["changes"].append({"id": cp.id, "name": cp.display_name(), "up": ch["up"], "d": ch["d"], "why": ch["why"]})
	world.year += 1
	for p: Player in world.academy.values().duplicate():
		p.reset_season_stats()
		if p.age(world.year) > MAX_AGE:
			world.academy.erase(p.id)
			p.club_id = -1
			p.contract_end = world.year
			world.add_player(p) # vira agente livre: outro clube pode apostar nele
			out["left"].append(p.display_name())
	dismiss_candidates(world)
	var cost := scouting_cost(world)
	if cost > 0:
		club.add_ledger("investimentos", -cost)
	out["cost"] = cost
	state(world)["cost"] = cost
	var used := WorldGenerator.used_names_of(world)
	var n := intake_count(world, club) + (1 if world.rng.randf() < 0.4 else 0)
	for _i in n:
		if world.academy.size() >= MAX_SIZE:
			break
		out["new"].append(_new_kid(world, club, world.rng.randi_range(MIN_AGE, 16), used))
	if String(state(world)["region"]) == "local":
		club.fan_mood = clampf(club.fan_mood + 1.0, 0.0, 100.0)
	return out


# ---------------------------------------------------------------------------
# Ligas sub-17 e sub-20
# ---------------------------------------------------------------------------

static func league(world: GameWorld, key: String = "u20") -> Dictionary:
	if key == "u20":
		return world.youth_league
	return world.youth.get("u17", {})


static func has_league(world: GameWorld, key: String = "u20") -> bool:
	return not league(world, key).is_empty()


## Monta as ligas sub-20 e sub-17 da liga do usuário para a temporada que começa.
static func build_league(world: GameWorld) -> void:
	world.youth_league = {}
	world.youth.erase("u17")
	if not world.has_user():
		return
	state(world)
	world.youth_league = _build(world, "u20")
	var u17 := _build(world, "u17")
	if not u17.is_empty():
		world.youth["u17"] = u17


static func _build(world: GameWorld, key: String) -> Dictionary:
	var club := world.user_club()
	var ids: Array = []
	for c: Club in world.clubs_in_league(club.league_id):
		ids.append(c.id)
	if ids.size() < 4:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, "sub20" if key == "u20" else "sub17"])
	var pairs := FixtureManager.round_robin(rng, ids, 1)
	var weekend: Array = []
	for i in world.season.calendar.size():
		if world.season.is_weekend(i):
			weekend.append(i)
	var slots := FixtureManager.spread_rounds(pairs.size(), weekend)
	var rounds: Array = []
	for r in pairs.size():
		var games: Array = []
		for pr in pairs[r]:
			games.append([int(pr[0]), int(pr[1]), -1, -1])
		rounds.append(games)
	var table := {}
	var strength := {}
	var stars := {}
	var used := {}
	var offset := 16.5 if key == "u20" else 22.0
	for cid in ids:
		table[cid] = CompetitionManager.empty_row()
		var c := world.club(cid)
		# Mesma escala dos garotos de verdade: 11 melhores de uma base média daquele clube
		strength[cid] = PlayerGenerator.league_level(c) - offset + c.youth_level * 0.07 + rng.randfn(0.0, 2.5)
		if cid != club.id:
			var names: Array = []
			for k in 3:
				var origin := NameGenerator.pick_origin(rng, c.nation)
				var nm := NameGenerator.generate(rng, origin["c"], {"pos": Pos.ST, "height": 178, "foot": 0, "attrs": PackedByteArray(), "region": ""}, used)
				names.append(String(nm["known_as"]) if String(nm["known_as"]) != "" else String(nm["last"]))
			stars[cid] = names
	var cfg := DatabaseManager.league_cfg(club.league_id)
	return {
		"key": key, "league": club.league_id, "year": world.year,
		"name": "%s %s" % [cfg.get("short", club.league_id), "Sub-20" if key == "u20" else "Sub-17"],
		"clubs": ids, "rounds": rounds, "slots": slots, "table": table, "str": strength, "stars": stars,
		"scorers": {}, "champion": -1,
	}


## Escalação do jogo: 4-3-3 com rodízio (a nota de cada um na posição + um pouco de sorte e de
## preferência por quem jogou menos). A categoria de cima pode chamar garotos mais novos, e as
## vagas que ninguém da lista merece ficam com os garotos sem destaque do elenco (nível médio da
## base). Retorna {"xi": [[Player, pos]], "bench": [Player], "str": força}.
static func pick_team(world: GameWorld, key: String, exclude: Dictionary = {}, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = world.rng
	var pool: Array = []
	var extra: Array = []
	for p: Player in world.academy.values():
		if exclude.has(p.id) or not p.is_available():
			continue
		var a := p.age(world.year)
		if key == "u20":
			if a >= 18:
				pool.append(p)
			elif a >= 16:
				extra.append(p)
		elif a >= 16 and a <= 17:
			pool.append(p)
		elif a <= 15:
			extra.append(p)
	pool.sort_custom(func(x: Player, y: Player): return x.id < y.id)
	extra.sort_custom(func(x: Player, y: Player): return x.id < y.id)
	var filler := filler_level(world, key)
	var xi: Array = []
	var taken := {}
	var total := 0.0
	for slot in XI_SHAPE:
		var best: Player = null
		var best_s := filler + rng.randfn(0.0, 1.0)
		for si in 2:
			var src: Array = pool if si == 0 else extra
			for p: Player in src:
				if taken.has(p.id):
					continue
				var s: float = p.rating_at(slot) + rng.randfn(0.0, 1.6) - p.stats[Player.S_STARTS] * 0.04
				if si == 1:
					s -= 2.5 # sobe de categoria quem se destaca
				if s > best_s:
					best_s = s
					best = p
		if best == null:
			total += filler
			continue
		taken[best.id] = true
		xi.append([best, slot])
		total += best.rating_at(slot)
	var bench: Array = []
	for p: Player in pool + extra:
		if not taken.has(p.id) and bench.size() < 3 and p.best_position() != Pos.GK:
			bench.append(p)
	return {"xi": xi, "bench": bench, "str": total / float(XI_SHAPE.size())}


## Nível dos garotos sem destaque que completam o time (a mesma escala dos adversários).
static func filler_level(world: GameWorld, key: String) -> float:
	var club := world.user_club()
	var offset := 20.0 if key == "u20" else 25.0
	return PlayerGenerator.league_level(club) - offset + club.youth_level * 0.07


## Força do time sub-20 do usuário (escalação padrão, sem sorte).
static func user_strength(world: GameWorld, key: String = "u20") -> float:
	var r := RandomNumberGenerator.new()
	r.seed = 1
	var t := pick_team(world, key, {}, r)
	# Sem o fator sorte a média sai um pouco maior; compensa para ficar na escala do jogo
	return float(t["str"]) - 0.5


## Joga as rodadas do sub-20 e do sub-17 marcadas para esta data (o sub-20 escala primeiro).
static func play_slot(world: GameWorld, slot: int) -> Array:
	var played: Array = []
	var used := {}
	for key in ["u20", "u17"]:
		var yl := league(world, key)
		if yl.is_empty():
			continue
		var slots: Array = yl["slots"]
		for r in slots.size():
			if int(slots[r]) != slot:
				continue
			for g in yl["rounds"][r]:
				if int(g[2]) >= 0:
					continue
				var h := int(g[0])
				var a := int(g[1])
				var team := {}
				var sh: float
				var sa: float
				if world.is_user_club(h) or world.is_user_club(a):
					team = pick_team(world, key, used)
					for e in team["xi"]:
						used[e[0].id] = true
					for bp: Player in team["bench"]:
						used[bp.id] = true
				sh = float(team["str"]) if world.is_user_club(h) else _strength(world, yl, h)
				sa = float(team["str"]) if world.is_user_club(a) else _strength(world, yl, a)
				var lh := 1.45 * exp((sh - sa) / 11.0) * 1.08
				var la := 1.25 * exp((sa - sh) / 11.0)
				g[2] = _poisson(world.rng, clampf(lh, 0.2, 5.0))
				g[3] = _poisson(world.rng, clampf(la, 0.2, 5.0))
				var f := Fixture.new()
				f.home = h
				f.away = a
				f.hg = int(g[2])
				f.ag = int(g[3])
				CompetitionManager.apply_to_table(yl["table"], f)
				if world.is_user_club(h):
					g.append(_credit_user(world, yl, team, int(g[2]), int(g[3])))
					_credit_goals(world, yl, a, int(g[3]))
				elif world.is_user_club(a):
					_credit_goals(world, yl, h, int(g[2]))
					g.append(_credit_user(world, yl, team, int(g[3]), int(g[2])))
				else:
					_credit_goals(world, yl, h, int(g[2]))
					_credit_goals(world, yl, a, int(g[3]))
				if world.is_user_club(h) or world.is_user_club(a):
					played.append(g)
	return played


static func _strength(world: GameWorld, yl: Dictionary, cid: int) -> float:
	# Os garotos dos outros clubes também evoluem ao longo do ano
	var progress := float(world.season.day) / maxf(1.0, float(world.season.calendar.size()))
	return float(yl["str"].get(cid, 45.0)) + progress * 2.0


## Minutos, gols, assistências e notas do time do usuário. Retorna o resumo do jogo:
## {"g": [nomes dos autores], "best": nome do melhor em campo}.
static func _credit_user(world: GameWorld, yl: Dictionary, team: Dictionary, mine: int, theirs: int) -> Dictionary:
	var rng := world.rng
	var xi: Array = team["xi"]
	var summary := {"g": [], "best": ""}
	if xi.is_empty():
		return summary
	var goals := {}
	var assists := {}
	var wg: Array = []
	var wa: Array = []
	for e in xi:
		var p: Player = e[0]
		var grp := Pos.group(int(e[1]))
		wg.append(float(p.attrs[Attr.FIN] + p.attrs[Attr.POS]) * [0.0, 0.25, 1.2, 3.0][grp])
		wa.append(float(p.attrs[Attr.PAS] + p.attrs[Attr.VIS] + p.attrs[Attr.CRU]) * [0.02, 0.5, 1.6, 1.4][grp])
	var sc: Dictionary = yl["scorers"]
	var cid := world.user_club_id
	for _i in mine:
		var k := RngUtil.weighted_index(rng, wg)
		var p: Player = xi[k][0]
		goals[p.id] = int(goals.get(p.id, 0)) + 1
		summary["g"].append(p.short_name())
		var key := "p%d" % p.id
		if not sc.has(key):
			sc[key] = {"n": p.display_name(), "c": cid, "g": 0, "pid": p.id}
		sc[key]["g"] = int(sc[key]["g"]) + 1
		if rng.randf() < 0.7:
			var wa2: Array = wa.duplicate()
			wa2[k] = 0.0
			var ka := RngUtil.weighted_index(rng, wa2)
			if ka >= 0:
				var ap: Player = xi[ka][0]
				assists[ap.id] = int(assists.get(ap.id, 0)) + 1
	var res := 0.35 if mine > theirs else (-0.35 if mine < theirs else 0.0)
	var subs_out := {}
	var bench: Array = team["bench"]
	if xi.size() > 1:
		for i in bench.size():
			subs_out[rng.randi_range(1, xi.size() - 1)] = true
	var best: Player = null
	var best_r := 0.0
	for i in xi.size():
		var p: Player = xi[i][0]
		var grp := Pos.group(int(xi[i][1]))
		var rt := 6.3 + res + int(goals.get(p.id, 0)) * 0.9 + int(assists.get(p.id, 0)) * 0.5 + rng.randfn(0.0, 0.5)
		if theirs == 0 and grp <= Pos.G_DEF:
			rt += 0.6 if grp == Pos.G_GK else 0.3
			if grp == Pos.G_GK:
				p.stats[Player.S_CLEAN] += 1
		elif grp <= Pos.G_DEF:
			rt -= theirs * 0.15
		rt = clampf(rt, 4.0, 10.0)
		p.stats[Player.S_APPS] += 1
		p.stats[Player.S_STARTS] += 1
		p.stats[Player.S_MINUTES] += 70 if subs_out.has(i) else 90
		p.stats[Player.S_GOALS] += int(goals.get(p.id, 0))
		p.stats[Player.S_ASSISTS] += int(assists.get(p.id, 0))
		p.stats[Player.S_RATING_SUM] += int(round(rt * 10.0))
		p.push_rating(rt)
		if rt > best_r:
			best_r = rt
			best = p
	for bp: Player in bench:
		var rb := clampf(6.2 + res * 0.5 + rng.randfn(0.0, 0.4), 5.0, 8.5)
		bp.stats[Player.S_APPS] += 1
		bp.stats[Player.S_MINUTES] += 20
		bp.stats[Player.S_RATING_SUM] += int(round(rb * 10.0))
		bp.push_rating(rb)
	if best != null:
		best.stats[Player.S_MOTM] += 1
		summary["best"] = best.short_name()
	return summary


static func _credit_goals(world: GameWorld, yl: Dictionary, cid: int, goals: int) -> void:
	var sc: Dictionary = yl["scorers"]
	var names: Array = yl["stars"].get(cid, [])
	for _i in goals:
		var k := RngUtil.weighted_index(world.rng, [0.4, 0.25, 0.15, 0.2])
		if k >= names.size():
			continue # gol de outro garoto
		var key := "c%d_%d" % [cid, k]
		if not sc.has(key):
			sc[key] = {"n": names[k], "c": cid, "g": 0}
		sc[key]["g"] = int(sc[key]["g"]) + 1


static func _poisson(rng: RandomNumberGenerator, lambda: float) -> int:
	var l := exp(-lambda)
	var k := 0
	var p := 1.0
	while true:
		p *= rng.randf()
		if p <= l or k > 9:
			break
		k += 1
	return k


static func sorted_table(world: GameWorld, key: String = "u20") -> Array:
	var yl := league(world, key)
	if yl.is_empty():
		return []
	return CompetitionManager.sort_table(yl["clubs"], yl["table"])


static func top_scorers(world: GameWorld, n: int, key: String = "u20") -> Array:
	var yl := league(world, key)
	if yl.is_empty():
		return []
	var arr: Array = yl["scorers"].values()
	arr.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["g"]) > int(b["g"]))
	return arr.slice(0, n)


## Fecha as ligas da base: campeão, título e notícia. Retorna o resumo do sub-20 ({} se não houve
## liga), com o do sub-17 em "u17".
static func finish_league(world: GameWorld) -> Dictionary:
	var out := _finish(world, "u20")
	var u17 := _finish(world, "u17")
	if not u17.is_empty():
		if out.is_empty():
			out = {"u17": u17}
		else:
			out["u17"] = u17
	return out


static func _finish(world: GameWorld, key: String) -> Dictionary:
	var yl := league(world, key)
	if yl.is_empty():
		return {}
	var order := sorted_table(world, key)
	if order.is_empty():
		return {}
	var champ := world.club(int(order[0]))
	yl["champion"] = champ.id
	champ.add_title(("Y:" if key == "u20" else "Z:") + String(yl["league"]))
	var sc := top_scorers(world, 1, key)
	var out := {"name": yl["name"], "champion": champ.id, "scorer": sc[0] if not sc.is_empty() else {}, "user_pos": order.find(world.user_club_id) + 1}
	if world.is_user_club(champ.id):
		NewsManager.post_raw(world, "Campeões do %s!" % yl["name"], "A garotada do %s conquistou o %s. O futuro do clube está em boas mãos." % [champ.short_name, yl["name"]], champ.id, -1, NewsEvent.IMP_HIGH, "base")
	return out
