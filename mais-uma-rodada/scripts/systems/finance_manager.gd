class_name FinanceManager
extends RefCounted
## Economia: bilheteria, TV, patrocínio, premiação, salários, manutenção e juros.
## Tudo é lançado no "ledger" da temporada do clube para a tela de finanças.
##
## Escala: cada liga tem uma receita típica derivada da folha salarial do seu nível
## (rules.json → money.revenue_per_wage × salário do nível × escala salarial da liga).
## TV é dividida como nas ligas de verdade: metade igual para todos, um quarto por mérito
## (posição na liga anterior) e um quarto por audiência (tamanho do clube), e o contrato de cada
## liga é renegociado a cada poucos anos. O patrocínio cresce com a reputação; bilheteria e loja
## dependem de torcida, estádio, ingresso e da fase do time. Assim um clube da Série D e um gigante inglês vivem em
## realidades diferentes, mas ambos conseguem pagar um elenco do próprio nível. Ligas com mais
## força comercial do que o nível dos jogadores sugere (Brasil, MLS, México) têm um multiplicador
## de receita próprio ("rev" em leagues.json).
##
## Dívida: o caixa (balance) é o dia a dia; a dívida de longo prazo (Club.debt) paga juros e
## amortização toda semana. Caixa no vermelho paga juros de cheque especial e, na virada do ano,
## vira empréstimo bancário até o limite que os bancos aceitam (debt_limit anos de receita).

const CAT_NAMES := {
	"bilheteria": "Bilheteria", "tv": "Direitos de TV", "loja": "Loja e produtos", "patrocinio": "Patrocínio", "premiacao": "Premiação",
	"vendas": "Venda de jogadores", "salarios": "Salários", "compras": "Compra de jogadores",
	"manutencao": "Custos operacionais", "juros": "Juros da dívida", "rescisoes": "Rescisões", "luvas": "Luvas",
	"investimentos": "Investimentos", "bonus_patrocinio": "Bônus de patrocínio", "aporte": "Aporte do novo dono",
	"renegociacao": "Dívida renegociada", "saida_dono": "Dívida deixada pelo dono", "impostos": "Impostos",
	"emprestimo": "Empréstimo bancário", "amortizacao": "Amortização da dívida",
}
const INCOME_CATS: Array[String] = ["bilheteria", "tv", "patrocinio", "bonus_patrocinio", "loja", "premiacao", "vendas", "aporte", "renegociacao", "emprestimo"]
const EXPENSE_CATS: Array[String] = ["salarios", "compras", "manutencao", "juros", "amortizacao", "rescisoes", "luvas", "investimentos", "saida_dono", "impostos"]
## Movimentos de dívida e de dono não são lucro nem prejuízo: ficam fora do imposto.
const NOT_TAXED: Array[String] = ["emprestimo", "amortizacao", "aporte", "renegociacao", "saida_dono"]
## Rodadas de fim de semana por temporada: salários, TV e patrocínio são pagos nelas.
const WEEKS := 38.0
## Divisão da TV: parte igual, parte por mérito, parte por audiência.
const TV_EQUAL := 0.5
const TV_MERIT := 0.25
const TV_AUDIENCE := 0.25
## Contratos de TV das ligas: duração e limites do multiplicador.
const TV_DEAL_YEARS := 3
const TV_DEAL_RANGE := [0.75, 1.5]
## Imposto sobre o lucro da temporada (cobrado no início da seguinte).
const PROFIT_TAX := 0.2


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
	var t := clampf((rep - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), -0.3, 1.04)
	if t < 0.0:
		t *= 0.4 # abaixo da faixa cai devagar: nem o lanterna de uma liga forte vira time de divisão inferior
	return float(lr[0]) + (float(lr[1]) - float(lr[0])) * t


static func league_mid_level(cfg: Dictionary) -> float:
	var lr: Array = cfg.get("level", [55, 65])
	return (float(lr[0]) + float(lr[1])) * 0.5


## Receita anual típica de um clube de nível `level` na liga.
static func revenue_target(cfg: Dictionary, level: float) -> float:
	return float(money()["revenue_per_wage"]) * Valuation.base_wage(level - Valuation.shift) * float(cfg.get("wage", 0.5)) * float(cfg.get("rev", 1.0))


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

## Cota de TV do clube (sem o multiplicador do contrato da liga, aplicado em set_budgets).
static func tv_income(club: Club) -> int:
	return int(tv_pool(club.league_id) * tv_factor(club))


## Cota média de TV de um clube da liga.
static func tv_pool(league_id: String) -> float:
	return league_revenue(league_id) * float(money()["tv_share"])


## Peso do clube na divisão da TV (média ≈ 1 na liga).
static func tv_factor(club: Club) -> float:
	var cfg := club.league_cfg()
	var rr: Array = cfg.get("rep", [40, 70])
	var aud := 0.4 + 1.2 * clampf((club.reputation - float(rr[0])) / maxf(1.0, float(rr[1]) - float(rr[0])), 0.0, 1.0)
	var merit := 1.0
	if not club.history.is_empty():
		var h: Dictionary = club.history[club.history.size() - 1]
		var teams := int(cfg.get("teams", 20))
		if String(h.get("l", "")) == club.league_id:
			merit = 0.4 + 1.2 * float(teams - int(h.get("p", teams / 2))) / maxf(1.0, teams - 1)
		elif int(DatabaseManager.league_cfg(String(h.get("l", ""))).get("tier", club.tier)) > club.tier:
			merit = 0.4 # recém-promovido
		else:
			merit = 1.2 # recém-rebaixado ainda recebe parte da cota da divisão de cima
	return TV_EQUAL + TV_MERIT * merit + TV_AUDIENCE * aud


## Multiplicador do contrato de TV vigente da liga.
static func tv_deal(world: GameWorld, league_id: String) -> float:
	return float(world.stats.get("tv_deals", {}).get(league_id, 1.0))


## Loja, camisas e produtos: vendas anuais típicas (torcida, preço do ingresso e alcance do clube).
static func merch_income(club: Club) -> int:
	var reach := 1.0 + maxf(0.0, club.reputation - 60.0) / 25.0
	return int(club.fan_base * ticket_price(club) * 0.9 * reach)


## Quanto a fase do time mexe nas vendas da loja nesta semana (1 = normal).
static func merch_mood(club: Club) -> float:
	var form_f := clampf(1.0 + club.streak_wins * 0.03 - club.streak_losses * 0.03, 0.85, 1.2)
	return (0.7 + club.fan_mood / 200.0) * form_f


static func club_revenue_target(club: Club) -> float:
	var cfg := club.league_cfg()
	return revenue_target(cfg, level_of_rep(cfg, club.reputation)) * float(club.arch().get("revenue_mult", 1.0))


static func expected_prize(club: Club) -> int:
	var m := money()
	return int(league_revenue(club.league_id) * (float(m["prize_first"]) + float(m["prize_last"])) * 0.5)


static func expected_gate(club: Club) -> int:
	return expected_attendance(club, null, false) * ticket_price(club) * home_games(club.league_id)


## Patrocínio: completa a receita típica do nível do clube (cresce com a reputação) e segue o
## momento comercial do clube (campanhas, títulos, rebaixamento).
static func sponsor_income(club: Club) -> int:
	var target := club_revenue_target(club)
	var rest := target - tv_income(club) - expected_prize(club) - expected_gate(club) - merch_income(club)
	return int(maxf(target * 0.08, rest) * club.commercial)


static func maintenance_cost(club: Club) -> int:
	var m := money()
	var base := club_revenue_target(club) * (float(m["maintenance_share"]) + club.facilities * float(m["maintenance_per_facility"]))
	return int(base + club.capacity * ticket_price(club) * float(m["seat_upkeep"]))


static func ticket_price(club: Club) -> int:
	return maxi(1, int(round(float(club.league_cfg().get("ticket", 10)) * club.ticket_mult)))


## heat_f: rivalidade do confronto (Rivalry.attendance_factor): rixas enchem mais, clássicos quentes esgotam.
static func expected_attendance(club: Club, opponent: Club, derby: bool, rng: RandomNumberGenerator = null, heat_f: float = 1.0) -> int:
	var mood_f := 0.55 + club.fan_mood / 200.0
	var opp_f := 0.9 + (opponent.reputation / 500.0 if opponent != null else 0.1)
	var derby_f := 1.25 if derby else 1.0
	var form_f := clampf(1.0 + club.streak_wins * 0.02 - club.streak_losses * 0.03, 0.85, 1.15)
	var noise := rng.randf_range(0.93, 1.07) if rng != null else 1.0
	var price_f := pow(1.0 / maxf(0.3, club.ticket_mult), 0.6)
	var att := club.fan_base * mood_f * opp_f * derby_f * heat_f * form_f * noise * price_f
	return clampi(int(att), int(club.capacity * 0.05), club.capacity)


static func expected_revenue(club: Club) -> int:
	return tv_income(club) + sponsor_income(club) + expected_prize(club) + expected_gate(club) + merch_income(club)


## Lançamentos semanais (datas de liga) — salários, TV, patrocínio, manutenção e juros.
## TV, patrocínio e manutenção são fixados na montagem da temporada (set_budgets).
static func process_week(world: GameWorld, club: Club) -> void:
	var bill := wage_bill(world, club)
	club.add_ledger("salarios", -int(bill * 12.0 / WEEKS))
	club.add_ledger("tv", int(club.income_tv / WEEKS))
	club.add_ledger("patrocinio", int(club.income_sponsor / WEEKS))
	club.add_ledger("loja", int(merch_income(club) / WEEKS * merch_mood(club)))
	club.add_ledger("manutencao", -int(club.cost_upkeep / WEEKS))
	var m := money()
	if club.debt > 0:
		# Juros e amortização do empréstimo de longo prazo (a parcela encolhe junto com a dívida)
		club.add_ledger("juros", -int(club.debt * float(m["loan_interest"]) / WEEKS))
		var amort := mini(club.debt, maxi(1, int(club.debt / float(m["loan_years"]) / WEEKS)))
		club.add_ledger("amortizacao", -amort)
		club.debt -= amort
	if club.balance < 0:
		# Cheque especial: caixa no vermelho custa bem mais caro que a dívida negociada
		club.add_ledger("juros", -int(-club.balance * float(m["debt_interest"]) / WEEKS))


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
## Verba pertence à diretoria, não ao treinador. Caixa do clube continua no balanço.
## A sobra de verba NÃO é somada à autorização do ano seguinte.
static func board_limits(world: GameWorld, club: Club) -> Dictionary:
	var revenue := maxf(0.0, float(expected_revenue(club) + club.income_tv - tv_income(club)))
	var payroll := float(wage_bill(world, club))
	var service := debt_service(club)
	var obligations := float(TransferManager.pending_installments(world, club.id))
	var operating := maxf(0.0, revenue - club.cost_upkeep - service)
	var ratio := clampf(float(club.arch().get("wage_ratio", 0.62)), 0.42, 0.68)
	var monthly := maxf(0.0, operating * ratio / 12.0)
	# Contratos vigentes não desaparecem quando a diretoria aperta o teto.
	var wage_ceiling := maxi(0, int(monthly))
	var reserve := payroll * 3.0 + float(club.cost_upkeep + service) * 0.25
	var spendable := maxf(0.0, float(club.balance) - reserve - obligations)
	var surplus := maxf(0.0, operating - payroll * 12.0 - obligations)
	var spend := clampf(float(club.arch().get("spend_rate", 0.35)) * ClubDNA.spend_mult(club), 0.15, 0.60)
	var cap := revenue * clampf(spend, 0.15, 0.45)
	var allowance := (spendable * spend + surplus * 0.20) / (1.0 + debt_ratio(club, revenue))
	allowance = minf(allowance, maxf(0.0, float(club.balance)))
	return {"transfer": int(clampf(allowance, 0.0, cap)), "wages": wage_ceiling,
		"cap": int(cap), "reserve": int(reserve), "obligations": int(obligations)}


static func set_budgets(world: GameWorld, club: Club) -> void:
	club.income_tv = int(tv_income(club) * tv_deal(world, club.league_id))
	club.income_sponsor = sponsor_income(club)
	club.cost_upkeep = maintenance_cost(club)
	var limits := board_limits(world, club)
	var budgets: Dictionary = world.stats.get("board_budgets_v1", {})
	var key := str(club.id)
	var old: Dictionary = budgets.get(key, {})
	if int(old.get("year", -1)) == world.year:
		# Mudar de emprego/reabrir a tela não repõe verba já comprometida.
		club.transfer_budget = mini(club.transfer_budget, maxi(0, int(limits["cap"]) - int(old.get("spent", 0))))
		return
	club.wage_budget = int(limits["wages"])
	club.transfer_budget = int(limits["transfer"])
	budgets[key] = {"year": world.year, "initial": club.transfer_budget, "authorized": club.transfer_budget, "spent": 0, "reviewed": false, "sale_share": sale_share(club)}
	world.stats["board_budgets_v1"] = budgets


## Migração limitada à política de orçamento: mantém caixa, jogadores e histórico intactos.
static func ensure_budget_policy(world: GameWorld) -> void:
	for club: Club in world.clubs:
		var rows: Dictionary=world.stats.get("board_budgets_v1",{})
		if int(rows.get(str(club.id),{}).get("year",-1))==world.year:
			continue
		var previous:=club.transfer_budget
		var spent:=maxi(0,-int(club.ledger.get("compras",0)))+maxi(0,-int(club.ledger.get("luvas",0)))
		set_budgets(world,club)
		var row: Dictionary=world.stats["board_budgets_v1"][str(club.id)]
		row["spent"]=spent
		club.transfer_budget=mini(previous,mini(club.transfer_budget,maxi(0,int(board_limits(world,club)["cap"])-spent)))
		row["authorized"]=spent+club.transfer_budget


static func commit_budget(world: GameWorld, club: Club, cost: int) -> void:
	cost = maxi(0, cost)
	club.transfer_budget = maxi(0, club.transfer_budget - cost)
	var budgets: Dictionary = world.stats.get("board_budgets_v1", {})
	var row: Dictionary = budgets.get(str(club.id), {})
	if int(row.get("year", -1)) == world.year:
		row["spent"] = int(row.get("spent", 0)) + cost


## All optional board grants use the same cash/commitment/annual-limit rule.
static func authorize_extra(world: GameWorld, club: Club, requested: int, reason: String) -> int:
	var budgets: Dictionary=world.stats.get("board_budgets_v1",{})
	var row: Dictionary=budgets.get(str(club.id),{})
	if int(row.get("year",-1))!=world.year:
		set_budgets(world,club)
		row=world.stats["board_budgets_v1"][str(club.id)]
	var grants: Dictionary=row.get("grants",{})
	if grants.has(reason):return 0
	var limits:=board_limits(world,club)
	var room:=maxi(0,int(limits["cap"])-int(row.get("spent",0))-club.transfer_budget)
	var free:=maxi(0,club.balance-int(limits["reserve"])-int(limits["obligations"])-club.transfer_budget)
	var amount:=mini(maxi(0,requested),mini(room,free))
	if amount<=0:return 0
	club.transfer_budget+=amount
	row["authorized"]=int(row.get("spent",0))+club.transfer_budget
	grants[reason]=amount
	row["grants"]=grants
	return amount

static func authorize_wages(world: GameWorld, club: Club, requested: int) -> int:
	var old:=club.wage_budget
	club.wage_budget=maxi(old,mini(requested,int(board_limits(world,club)["wages"])))
	return club.wage_budget-old


static func sale_share(club: Club) -> float:
	# Uma política comum a todos os clubes. Dívida e caixa, não a dificuldade, decidem a retenção.
	var debt := debt_ratio(club)
	var share := clampf(0.65 - debt * 0.20, 0.20, 0.65)
	return share * 0.5 if club.balance < 0 else share


## Salários de mercado: numa liga rica até o clube pequeno paga bem (a TV da Premier League
## banca salários altos para jogadores medianos). Quem gasta com a folha bem menos do que a
## receita permite renegocia os contratos para cima, aos poucos: a folha caminha para ~50% da
## receita, como nos clubes reais, em vez de o caixa virar uma montanha parada.
const WAGE_SHARE_MIN := 0.42
const WAGE_SHARE_TARGET := 0.52


static func market_wages(world: GameWorld, club: Club, first: bool = false) -> void:
	if world.is_user_club(club.id) and not first:
		return
	var revenue := float(expected_revenue(club) + club.income_tv - tv_income(club))
	var bill := float(wage_bill(world, club)) * 12.0
	if revenue <= 0.0 or bill <= 0.0 or bill >= revenue * WAGE_SHARE_MIN:
		return
	# Na geração o salto é maior (os contratos já nascem no patamar da liga); depois, 40% do caminho por ano.
	var gap := revenue * WAGE_SHARE_TARGET / bill
	var k := clampf(1.0 + (gap - 1.0) * (0.85 if first else 0.55), 1.0, 3.0 if first else 1.7)
	for pid in club.player_ids:
		var p: Player = world.players.get(pid, null)
		if p == null or not p.loan.is_empty():
			continue
		p.wage = Valuation.round_wage(p.wage * k)


## Dívida total (empréstimos + caixa no vermelho) em anos de receita (0 = sem dívida).
static func debt_ratio(club: Club, revenue: float = -1.0) -> float:
	var total := club.debt + maxi(0, -club.balance)
	if total <= 0:
		return 0.0
	if revenue < 0.0:
		revenue = float(expected_revenue(club))
	return total / maxf(1.0, revenue)


## Juros + amortização da dívida de longo prazo previstos para o ano.
static func debt_service(club: Club) -> float:
	var m := money()
	return club.debt * (float(m["loan_interest"]) + 1.0 / float(m["loan_years"]))


## Aperto financeiro de verdade: caixa no vermelho ou dívida acima de um ano de receita.
static func in_trouble(club: Club) -> bool:
	return club.balance < 0 or debt_ratio(club) > 1.0


## Virada do ano: o rombo do caixa vira empréstimo bancário, até o limite que os bancos aceitam.
## Retorna o valor emprestado.
static func refinance(world: GameWorld, club: Club) -> int:
	if club.balance >= 0:
		return 0
	var rev := float(expected_revenue(club))
	var room := int(rev * float(money()["debt_limit"])) - club.debt
	var loan := mini(-club.balance, maxi(0, room))
	if loan <= 0:
		return 0
	club.debt += loan
	club.add_ledger("emprestimo", loan)
	if world.is_user_club(club.id):
		NewsManager.post_raw(world, "Banco cobre o rombo do %s" % club.short_name,
			"O caixa fechou o ano no vermelho e a diretoria transformou %s em empréstimo de longo prazo. A dívida total vai a %s e a parcela entra na conta de cada mês." % [
				Fmt.money(loan), Fmt.money(club.debt)], club.id, -1, NewsEvent.IMP_HIGH, "clube")
	return loan


## Revisão de meio de temporada (abertura da janela de inverno): a diretoria ajusta a verba
## ao que entrou e saiu até aqui — premiações e vendas liberam dinheiro, prejuízo aperta.
static func mid_season_review(world: GameWorld, club: Club) -> void:
	var budgets: Dictionary = world.stats.get("board_budgets_v1", {})
	var row: Dictionary = budgets.get(str(club.id), {})
	if row.is_empty() or int(row.get("year", -1)) != world.year:
		set_budgets(world, club)
		budgets = world.stats.get("board_budgets_v1", {})
		row = budgets.get(str(club.id), {})
	if bool(row.get("reviewed", false)):
		return
	row["reviewed"] = true
	var limits := board_limits(world, club)
	var old := club.transfer_budget
	var cap_room := maxi(0, int(limits["cap"]) - int(row.get("spent", 0)))
	var extra := int(maxf(0.0, float(projected_balance(world, club)) - float(limits["reserve"]) - float(limits["obligations"])) * 0.10)
	club.transfer_budget = mini(old + extra, mini(cap_room, maxi(0, club.balance - int(limits["reserve"]) - int(limits["obligations"]))))
	row["authorized"] = int(row.get("spent", 0)) + club.transfer_budget
	if club.balance < 0:
		club.wage_budget = mini(club.wage_budget, int(limits["wages"]))
	if world.is_user_club(club.id):
		NewsManager.post_raw(world, "Diretoria revisa a verba", "Autorização para contratações: %s. A diretoria preservou reservas e compromissos futuros; o caixa não é uma carteira do treinador." % Fmt.money(club.transfer_budget), club.id, -1, NewsEvent.IMP_NORMAL, "clube")


## Projeção do caixa no fim da temporada: saldo atual + o que ainda falta entrar e sair.
static func projected_balance(world: GameWorld, club: Club) -> int:
	var s := world.season
	if s == null:
		return club.balance
	var left := 0
	for i in range(s.day, s.calendar.size()):
		if s.is_weekend(i):
			left += 1
	var weekly := (club.income_tv + club.income_sponsor + merch_income(club) - club.cost_upkeep - debt_service(club)) / WEEKS - wage_bill(world, club) * 12.0 / WEEKS
	var gate_left := expected_gate(club) * left / WEEKS
	return int(club.balance + weekly * left + gate_left)


## Renegociação dos contratos de TV das ligas (fim de temporada). Retorna [{league, old, new}] das que mudaram.
static func renegotiate_tv(world: GameWorld) -> Array:
	var deals: Dictionary = world.stats.get("tv_deals", {})
	var out: Array = []
	for id in DatabaseManager.league_ids():
		# Cada liga tem seu próprio ciclo (defasado pelo nome), para não mudar tudo no mesmo ano.
		if (world.year + absi(String(id).hash())) % TV_DEAL_YEARS != 0:
			continue
		var old := float(deals.get(id, 1.0))
		var nw := clampf(old * world.rng.randf_range(0.9, 1.2), float(TV_DEAL_RANGE[0]), float(TV_DEAL_RANGE[1]))
		# Contratos longe do normal tendem a voltar (o mercado se ajusta).
		nw = snappedf(lerpf(nw, 1.0, 0.15), 0.01)
		deals[id] = nw
		out.append({"league": id, "old": old, "new": nw})
	world.stats["tv_deals"] = deals
	return out


## Parte de uma venda que a diretoria libera para novas contratações.
static func on_sale(world: GameWorld, club: Club, fee: int) -> void:
	if fee <= 0:
		return
	var share := sale_share(club)
	var budgets: Dictionary = world.stats.get("board_budgets_v1", {})
	var row: Dictionary = budgets.get(str(club.id), {})
	var spent := int(row.get("spent", 0)) if int(row.get("year", -1)) == world.year else 0
	var cap := int(float(expected_revenue(club)) * 0.45)
	club.transfer_budget = mini(club.transfer_budget + int(fee * share), maxi(0, cap - spent))
	if not row.is_empty():
		row["authorized"] = spent + club.transfer_budget
		row["sale_share"] = share


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
		"debt": club.debt,
		"transfer_budget": club.transfer_budget,
		"wage_bill": wage_bill(world, club),
		"wage_budget": club.wage_budget,
		"income": income,
		"expense": expense,
		"expected_revenue": expected_revenue(club),
	}


## Situação financeira em palavras (para o usuário entender em segundos): caixa e dívida juntos.
static func health_label(_world: GameWorld, club: Club) -> String:
	var rev := float(expected_revenue(club))
	var bal := float(club.balance)
	var dr := debt_ratio(club, rev)
	if bal < -rev * 0.3 or dr > 1.5:
		return "Crise"
	if bal < 0 or dr > 0.7:
		return "Endividado"
	if bal < rev * 0.2 or dr > 0.4:
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



## Lucro de cada clube na temporada que termina → imposto a pagar: {club_id: valor}.
static func season_taxes(world: GameWorld) -> Dictionary:
	var out := {}
	for c: Club in world.clubs:
		var net := 0
		for k in c.ledger:
			if not NOT_TAXED.has(String(k)):
				net += int(c.ledger[k])
		if net > 0:
			out[c.id] = int(net * PROFIT_TAX)
	return out