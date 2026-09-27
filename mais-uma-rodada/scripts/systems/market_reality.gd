class_name MarketReality
extends RefCounted
## Calibração econômica baseada em valores totais de elenco do mercado real.
## Os jogadores do jogo continuam fictícios: o objetivo é fazer a SOMA do elenco e a capacidade
## de investimento do clube viverem na ordem de grandeza correta, sem copiar atletas reais.
##
## Base monetária interna: EUR. A moeda escolhida pelo usuário é só de exibição (Fmt).

const VERSION := 3

## Valores totais de elenco usados como âncoras (Transfermarkt, temporada 2026/27 ou 2026).
## Clubes sem âncora recebem a média do fator das âncoras da própria liga.
const SQUAD_ANCHORS_EUR := {
	"ESP_MBL": 1_220_000_000, # Real Madrid
	"ESP_BLG": 1_190_000_000, # Barcelona
	"ENG_MSK": 1_430_000_000, # Manchester City
	"ENG_NLR": 1_310_000_000, # Arsenal
	"GER_MUR": 1_010_000_000, # Bayern
	"FRA_PCF": 1_360_000_000, # PSG
	"ITA_MNZ": 683_800_000,   # Inter
	"BRA_RNC": 217_950_000,   # Flamengo
	"BRA_VPA": 229_480_000,   # Palmeiras
	"BRA_TIM": 150_300_000,   # Corinthians
	"BRA_GLO": 126_950_000,   # Botafogo
	"BRA_MOR": 81_000_000,    # São Paulo
	"KSA_AZR": 193_300_000,   # Al Hilal
}


static func squad_value(world: GameWorld, club: Club) -> int:
	var total := 0
	for pid in club.player_ids:
		var p := world.player(int(pid))
		if p != null:
			total += maxi(0, p.value)
	return total


static func _rescale_club(world: GameWorld, club: Club, factor: float) -> void:
	factor = clampf(factor, 0.45, 2.50)
	for pid in club.player_ids:
		var p := world.player(int(pid))
		if p != null and p.value > 0:
			p.value = Valuation.round_value(float(p.value) * factor)


## Uma vez por mundo/save: ajusta os valores dos elencos para a ordem de grandeza real.
## As âncoras batem o Transfermarkt; os demais clubes da mesma liga herdam o fator médio,
## preservando a hierarquia gerada por reputação/overall.
static func ensure_world(world: GameWorld) -> bool:
	if int(world.stats.get("market_reality", 0)) >= VERSION:
		return false
	# Versão 3: o peso de cada liga entra no próprio cálculo do valor (Valuation.LEAGUE_VALUE) e
	# não se perde quando o valor é recalculado; basta recalcular todo mundo uma vez.
	Valuation.set_club_factors(world)
	for p: Player in world.players.values():
		Valuation.update_value(p, world.year)
	world.stats["market_reality"] = VERSION
	return true
	var league_factors: Dictionary = {}
	var explicit_factors: Dictionary = {}
	for key in SQUAD_ANCHORS_EUR:
		var c := world.club_by_key(String(key))
		if c == null:
			continue
		var current := squad_value(world, c)
		if current <= 0:
			continue
		var factor := clampf(float(SQUAD_ANCHORS_EUR[key]) / float(current), 0.45, 2.50)
		explicit_factors[c.id] = factor
		if not league_factors.has(c.league_id):
			league_factors[c.league_id] = []
		league_factors[c.league_id].append(factor)

	var league_avg := {}
	for lid in league_factors:
		var arr: Array = league_factors[lid]
		var log_sum := 0.0
		for factor in arr:
			log_sum += log(maxf(0.01, float(factor)))
		# Média geométrica: uma âncora extrema não arrasta toda a liga.
		league_avg[lid] = clampf(exp(log_sum / maxf(1.0, arr.size())), 0.65, 1.55)

	for c: Club in world.clubs:
		var factor := 1.0
		if explicit_factors.has(c.id):
			factor = float(explicit_factors[c.id])
		elif league_avg.has(c.league_id):
			factor = float(league_avg[c.league_id])
		_rescale_club(world, c, factor)

	# Segunda passada deixa as âncoras próximas do total publicado apesar dos arredondamentos.
	for key in SQUAD_ANCHORS_EUR:
		var c := world.club_by_key(String(key))
		if c == null:
			continue
		var now := squad_value(world, c)
		if now > 0:
			_rescale_club(world, c, float(SQUAD_ANCHORS_EUR[key]) / float(now))

	world.stats["market_reality"] = VERSION
	return true


## Referência de verba de transferências por temporada.
## Transfermarkt ancora o VALOR DO ELENCO; a verba é uma simulação derivada de tamanho econômico,
## perfil da diretoria, caixa e dívida (não é apresentada como dado do Transfermarkt).
static func budget_reference(world: GameWorld, club: Club, revenue: float = -1.0) -> int:
	if revenue < 0.0:
		revenue = float(FinanceManager.expected_revenue(club))
	var squad := float(squad_value(world, club))
	if squad <= 0.0:
		return 0

	var ratio := 0.09 + clampf((club.reputation - 55.0) / 400.0, 0.0, 0.10)
	var arch := club.archetype
	if arch == "rico_promovido":
		ratio += 0.08
	elif arch == "gigante_endividado":
		ratio -= 0.035
	elif arch == "cidade_pequena" or arch == "azarao":
		ratio -= 0.02
	if club.nation in ["KSA", "QAT", "UAE"]:
		ratio += 0.08
	if club.tier >= 2:
		ratio *= 0.72

	var dr := FinanceManager.debt_ratio(club, revenue)
	var health := 1.0
	if club.balance < 0:
		health *= 0.55
	if dr > 0.7:
		health *= clampf(1.15 - dr * 0.35, 0.35, 0.9)
	var cash_power := maxf(0.0, float(club.balance)) * 0.55 + revenue * 0.16
	if arch == "rico_promovido" or club.nation in ["KSA", "QAT", "UAE"]:
		cash_power += revenue * 0.20

	var market_budget := squad * clampf(ratio, 0.045, 0.30) * health
	# O teto evita que um elenco caro, mas clube quebrado, produza dinheiro do nada.
	return int(clampf(market_budget, 0.0, maxf(revenue * 0.15, cash_power)))


## Migração de save antigo: não zera o que o usuário já gastou; aproxima suavemente a verba.
static func migrate_budget(world: GameWorld, club: Club) -> void:
	var ref := budget_reference(world, club)
	if ref <= 0:
		return
	club.transfer_budget = maxi(0, int(lerpf(float(club.transfer_budget), float(ref), 0.35)))
