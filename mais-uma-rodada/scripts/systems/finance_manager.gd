class_name FinanceManager
extends RefCounted
## Economia: bilheteria, TV, patrocínio, premiação, salários, manutenção e juros.
## Tudo é lançado no "ledger" da temporada do clube para a tela de finanças.
##
## Escala: cada liga tem uma receita típica derivada da folha salarial do seu nível
## (rules.json → money.revenue_per_wage × salário do nível × escala salarial da liga).
## TV é igual para todos da liga; o patrocínio cresce com a reputação; bilheteria depende
## de torcida, estádio e ingresso. Assim um clube da Série D e um gigante inglês vivem em
## realidades diferentes, mas ambos conseguem pagar um elenco do próprio nível.

const CAT_NAMES := {
	"bilheteria": "Bilheteria", "tv": "Direitos de TV", "patrocinio": "Patrocínio", "premiacao": "Premiação",
	"vendas": "Venda de jogadores", "salarios": "Salários", "compras": "Compra de jogadores",
	"manutencao": "Manutenção", "juros": "Juros da dívida", "rescisoes": "Rescisões", "luvas": "Luvas",
	"investimentos": "Investimentos",
}
const INCOME_CATS: Array[String] = ["bilheteria", "tv", "patrocinio", "premiacao", "vendas"]
const EXPENSE_CATS: Array[String] = ["salarios", "compras", "manutencao", "juros", "rescisoes", "luvas", "investimentos"]
## Rodadas de fim de semana por temporada: salários, TV e patrocínio são pagos nelas.
const WEEKS := 38.0


static func money() -> Dictionary:
	return DatabaseManager.money()


static func wage_bill(world: GameWorld, club: Club) -> int:
	var total := 0
	for pid in club.player_ids:
		var p: Player = world.players.get(pid, null)
		if p != null:
			total += p.wage
	return total


# ---------------------------------------------------------------------------
# Escala da liga
# ---------------------------------------------------------------------------

## Nível típico (overall médio dos titulares) de um clube com reputação `rep` na liga.
static func level_of_rep(cfg: Dictionary, rep: float) -> float:
	var lr: Array = cfg.get("level", [55, 65])
	var rr: Array = cfg.get("rep", [40, 70])
	var t := clampf((rep - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), -0.3, 1.2)
	return float(lr[0]) + (float(lr[1]) - float(lr[0])) * t


static func league_mid_level(cfg: Dictionary) -> float:
	var lr: Array = cfg.get("level", [55, 65])
	return (float(lr[0]) + float(lr[1])) * 0.5


## Receita anual típica de um clube de nível `level` na liga.
static func revenue_target(cfg: Dictionary, level: float) -> float:
	return float(money()["revenue_per_wage"]) * Valuation.base_wage(level - Valuation.shift) * float(cfg.get("wage", 0.5))


## Receita típica de um clube médio da liga (referência para TV, prêmios e custos).
static func league_revenue(league_id: String) -> float:
	var cfg := DatabaseManager.league_cfg(league_id)
	return revenue_target(cfg, league_mid_level(cfg))


static func home_games(league_id: String) -> int:
	var cfg := DatabaseManager.league_cfg(league_id)
	return int((int(cfg.get("teams", 20)) - 1) * int(cfg.get("rr", 2)) / 2)


# ---------------------------------------------------------------------------
# Receitas e custos de um clube
# ---------------------------------------------------------------------------

static func tv_income(club: Club) -> int:
	return int(league_revenue(club.league_id) * float(money()["tv_share"]))


static func club_revenue_target(club: Club) -> float:
	var cfg := club.league_cfg()
	return revenue_target(cfg, level_of_rep(cfg, club.reputation)) * float(club.arch().get("revenue_mult", 1.0))


static func expected_prize(club: Club) -> int:
	var m := money()
	return int(league_revenue(club.league_id) * (float(m["prize_first"]) + float(m["prize_last"])) * 0.5)


static func expected_gate(club: Club) -> int:
	return expected_attendance(club, null, false) * ticket_price(club) * home_games(club.league_id)


## Patrocínio: completa a receita típica do nível do clube (cresce com a reputação).
static func sponsor_income(club: Club) -> int:
	var target := club_revenue_target(club)
	var rest := target - tv_income(club) - expected_prize(club) - expected_gate(club)
	return int(maxf(target * 0.08, rest))


static func maintenance_cost(club: Club) -> int:
	var m := money()
	var base := club_revenue_target(club) * (float(m["maintenance_share"]) + club.facilities * float(m["maintenance_per_facility"]))
	return int(base + club.capacity * ticket_price(club) * float(m["seat_upkeep"]))


static func ticket_price(club: Club) -> int:
	return maxi(1, int(round(float(club.league_cfg().get("ticket", 10)) * club.ticket_mult)))


static func expected_attendance(club: Club, opponent: Club, derby: bool, rng: RandomNumberGenerator = null) -> int:
	var mood_f := 0.55 + club.fan_mood / 200.0
	var opp_f := 0.9 + (opponent.reputation / 500.0 if opponent != null else 0.1)
	var derby_f := 1.25 if derby else 1.0
	var form_f := clampf(1.0 + club.streak_wins * 0.02 - club.streak_losses * 0.03, 0.85, 1.15)
	var noise := rng.randf_range(0.93, 1.07) if rng != null else 1.0
	var price_f := pow(1.0 / maxf(0.3, club.ticket_mult), 0.6)
	var att := club.fan_base * mood_f * opp_f * derby_f * form_f * noise * price_f
	return clampi(int(att), int(club.capacity * 0.05), club.capacity)


static func expected_revenue(club: Club) -> int:
	return tv_income(club) + sponsor_income(club) + expected_prize(club) + expected_gate(club)


## Lançamentos semanais (datas de liga) — salários, TV, patrocínio, manutenção e juros.
## TV, patrocínio e manutenção são fixados na montagem da temporada (set_budgets).
static func process_week(world: GameWorld, club: Club) -> void:
	var bill := wage_bill(world, club)
	club.add_ledger("salarios", -int(bill * 12.0 / WEEKS))
	club.add_ledger("tv", int(club.income_tv / WEEKS))
	club.add_ledger("patrocinio", int(club.income_sponsor / WEEKS))
	club.add_ledger("manutencao", -int(club.cost_upkeep / WEEKS))
	if club.balance < 0:
		club.add_ledger("juros", -int(-club.balance * float(money()["debt_interest"]) / WEEKS))


## Premiação por posição final (linear entre o 1º e o último).
static func prize_for(league_id: String, position: int, teams: int) -> int:
	var m := money()
	var first := float(m["prize_first"])
	var last := float(m["prize_last"])
	var t := float(position - 1) / maxf(1.0, teams - 1)
	return int(league_revenue(league_id) * (first + (last - first) * t))


static func promotion_bonus(new_league_id: String) -> int:
	return int(league_revenue(new_league_id) * float(money()["promotion_bonus"]))


## Orçamentos definidos pela diretoria no início da temporada (e as receitas fixas do ano).
static func set_budgets(world: GameWorld, club: Club) -> void:
	club.income_tv = tv_income(club)
	club.income_sponsor = sponsor_income(club)
	club.cost_upkeep = maintenance_cost(club)
	var arch := club.arch()
	var revenue := float(expected_revenue(club))
	var ratio := float(arch.get("wage_ratio", 0.62))
	var spend := float(arch.get("spend_rate", 0.35))
	if world.is_user_club(club.id):
		ratio = [0.95, 0.86, 0.8][world.difficulty]
		spend = [0.6, 0.45, 0.35][world.difficulty]
	var current := float(wage_bill(world, club))
	# Reservas viram poder de fogo salarial (dinheiro parado circula), dívida aperta o cinto.
	var reserve := minf(maxf(0.0, club.balance) * 0.12, revenue * 0.35)
	var budget := (revenue * ratio + reserve) / 12.0
	if club.balance >= 0:
		# Clube saudável pode manter a folha atual mesmo um pouco acima do ideal.
		budget = maxf(budget, minf(current, budget * 1.1))
	else:
		# Endividado: o teto cai e força cortes (vendas, não renovações).
		budget *= 0.92
	club.wage_budget = int(budget)
	# Teto por temporada: contratações limitadas a uma fração da receita anual, por mais rico que o clube seja.
	var cap_mult := 1.4
	if world.is_user_club(club.id):
		cap_mult = [2.0, 1.6, 1.3][world.difficulty]
	club.transfer_budget = int(clampf(club.balance * spend, 0.0, revenue * cap_mult))


## Parte de uma venda que a diretoria libera para novas contratações.
static func on_sale(world: GameWorld, club: Club, fee: int) -> void:
	var share := 0.8
	if world.is_user_club(club.id):
		share = [0.85, 0.7, 0.6][world.difficulty]
	if club.balance < 0:
		share *= 0.5
	club.transfer_budget += int(fee * share)


static func summary(world: GameWorld, club: Club) -> Dictionary:
	var income := 0
	var expense := 0
	for k in club.ledger:
		var v: int = club.ledger[k]
		if v >= 0:
			income += v
		else:
			expense += -v
	return {
		"balance": club.balance,
		"transfer_budget": club.transfer_budget,
		"wage_bill": wage_bill(world, club),
		"wage_budget": club.wage_budget,
		"income": income,
		"expense": expense,
		"expected_revenue": expected_revenue(club),
	}


## Situação financeira em palavras (para o usuário entender em segundos).
static func health_label(_world: GameWorld, club: Club) -> String:
	var rev := float(expected_revenue(club))
	var bal := float(club.balance)
	if bal < -rev * 0.5:
		return "Crise"
	if bal < 0:
		return "Endividado"
	if bal < rev * 0.2:
		return "Apertado"
	if bal < rev:
		return "Estável"
	return "Saudável"


## Custo para melhorar em 1 ponto a estrutura (CT) ou a base.
static func upgrade_cost(club: Club, current_level: int) -> int:
	var base := league_revenue(club.league_id) * float(money()["upgrade_share"])
	return maxi(1000, int(round(base * (1.0 + current_level / 40.0) / 1000.0)) * 1000)


## Investe `points` pontos em "facilities" ou "youth". Retorna o custo (0 se não houver dinheiro).
static func invest(club: Club, kind: String, points: int) -> int:
	var total := 0
	var level := club.facilities if kind == "facilities" else club.youth_level
	for i in points:
		if level + i >= 99:
			break
		total += upgrade_cost(club, level + i)
	if total <= 0 or total > club.balance:
		return 0
	club.add_ledger("investimentos", -total)
	if kind == "facilities":
		club.facilities = mini(99, club.facilities + points)
	else:
		club.youth_level = mini(99, club.youth_level + points)
	return total


## Fim de temporada: estrutura se deprecia; clubes da IA com caixa sobrando investem.
static func yearly_investments(world: GameWorld) -> void:
	for c: Club in world.clubs:
		if world.rng.randf() < 0.5:
			c.facilities = maxi(5, c.facilities - 1)
		if world.rng.randf() < 0.4:
			c.youth_level = maxi(5, c.youth_level - 1)
		if world.is_user_club(c.id):
			continue
		var excess := c.balance - int(expected_revenue(c) * 0.8)
		if excess <= 0:
			continue
		var budget := int(excess * 0.35)
		var spent := 0
		for _i in 6:
			var kind := "facilities" if c.facilities <= c.youth_level or world.rng.randf() < 0.5 else "youth"
			var cost := upgrade_cost(c, c.facilities if kind == "facilities" else c.youth_level)
			if spent + cost > budget:
				break
			spent += invest(c, kind, 1)
