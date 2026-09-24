class_name FinanceManager
extends RefCounted
## Economia simples: bilheteria, TV, patrocínio, premiação, salários, manutenção e juros.
## Tudo é lançado no "ledger" da temporada do clube para a tela de finanças.

const CAT_NAMES := {
	"bilheteria": "Bilheteria", "tv": "Direitos de TV", "patrocinio": "Patrocínio", "premiacao": "Premiação",
	"vendas": "Venda de jogadores", "salarios": "Salários", "compras": "Compra de jogadores",
	"manutencao": "Manutenção", "juros": "Juros da dívida", "rescisoes": "Rescisões", "luvas": "Luvas",
	"investimentos": "Investimentos",
}
const INCOME_CATS: Array[String] = ["bilheteria", "tv", "patrocinio", "premiacao", "vendas"]
const EXPENSE_CATS: Array[String] = ["salarios", "compras", "manutencao", "juros", "rescisoes", "luvas", "investimentos"]


static func cfg(div: int) -> Dictionary:
	return DatabaseManager.division_config(div)


static func league_days() -> int:
	return 38


static func wage_bill(world: GameWorld, club: Club) -> int:
	var total := 0
	for pid in club.player_ids:
		var p: Player = world.players.get(pid, null)
		if p != null:
			total += p.wage
	return total


static func tv_income(club: Club) -> int:
	return int(cfg(club.division)["tv_money"])


static func sponsor_income(club: Club) -> int:
	var f := float(DatabaseManager.competitions().get("sponsor_factor", 150))
	return int(f * club.reputation * club.reputation * float(club.arch().get("revenue_mult", 1.0)))


static func maintenance_cost(club: Club) -> int:
	var m: Dictionary = DatabaseManager.competitions()["maintenance"]
	var scale: float = m["division_scale"][club.division]
	return int(club.capacity * float(m["per_seat"]) + club.facilities * float(m["per_facility_point"]) * scale)


static func ticket_price(club: Club) -> int:
	return int(cfg(club.division)["ticket_price"])


static func expected_attendance(club: Club, opponent: Club, derby: bool, rng: RandomNumberGenerator = null) -> int:
	var mood_f := 0.55 + club.fan_mood / 200.0
	var opp_f := 0.9 + (opponent.reputation / 500.0 if opponent != null else 0.1)
	var derby_f := 1.25 if derby else 1.0
	var form_f := clampf(1.0 + club.streak_wins * 0.02 - club.streak_losses * 0.03, 0.85, 1.15)
	var noise := rng.randf_range(0.93, 1.07) if rng != null else 1.0
	var att := club.fan_base * mood_f * opp_f * derby_f * form_f * noise
	return clampi(int(att), int(club.capacity * 0.05), club.capacity)


static func expected_revenue(club: Club) -> int:
	var c := cfg(club.division)
	var att := expected_attendance(club, null, false)
	var gate := att * ticket_price(club) * 19
	var prize := (int(c["prize_first"]) + int(c["prize_last"])) / 2
	return gate + tv_income(club) + sponsor_income(club) + prize


## Lançamentos de um dia de jogo da liga (chamado para todos os clubes).
static func process_matchday(world: GameWorld, club: Club, gate: int) -> void:
	var days := float(league_days())
	var bill := wage_bill(world, club)
	club.add_ledger("salarios", -int(bill * 12.0 / days))
	club.add_ledger("tv", int(tv_income(club) / days))
	club.add_ledger("patrocinio", int(sponsor_income(club) / days))
	club.add_ledger("manutencao", -int(maintenance_cost(club) / days))
	if club.balance < 0:
		var rate := float(DatabaseManager.competitions().get("debt_interest", 0.08))
		club.add_ledger("juros", -int(-club.balance * rate / days))
	if gate > 0:
		club.add_ledger("bilheteria", gate)


## Premiação por posição final (linear entre o 1º e o último).
static func prize_for(div: int, position: int, teams: int) -> int:
	var c := cfg(div)
	var first := float(c["prize_first"])
	var last := float(c["prize_last"])
	var t := float(position - 1) / maxf(1.0, teams - 1)
	return int(first + (last - first) * t)


## Orçamentos definidos pela diretoria no início da temporada.
static func set_budgets(world: GameWorld, club: Club) -> void:
	var arch := club.arch()
	var revenue := float(expected_revenue(club))
	var ratio := float(arch.get("wage_ratio", 0.62))
	var spend := float(arch.get("spend_rate", 0.35))
	if world.is_user_club(club.id):
		ratio = [0.95, 0.86, 0.8][world.difficulty]
		spend = [0.6, 0.45, 0.35][world.difficulty]
	var current := float(wage_bill(world, club))
	# Reservas viram poder de fogo salarial (dinheiro parado circula), dívida aperta o cinto.
	var reserve := maxf(0.0, club.balance) * 0.12
	var budget := (revenue * ratio + reserve) / 12.0
	if club.balance >= 0:
		# Clube saudável pode manter a folha atual mesmo um pouco acima do ideal.
		budget = maxf(budget, minf(current, budget * 1.1))
	else:
		# Endividado: o teto cai e força cortes (vendas, não renovações).
		budget *= 0.92
	club.wage_budget = int(budget)
	club.transfer_budget = int(maxf(0.0, club.balance * spend))


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
static func health_label(world: GameWorld, club: Club) -> String:
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
	var scale: float = DatabaseManager.competitions()["maintenance"]["division_scale"][club.division]
	return int(round(60000.0 * scale * (1.0 + current_level / 40.0) / 1000.0)) * 1000


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
