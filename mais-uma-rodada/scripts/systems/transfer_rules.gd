class_name TransferRules
extends RefCounted
## Regras do regulamento de transferências que mudam o mercado de verdade:
##   - Menores de 18 (artigo 19 da FIFA): ninguém se muda de país antes dos 18, salvo dentro da
##     União Europeia a partir dos 16. O clube estrangeiro pode fechar a compra antes, como acontece
##     com as joias sul-americanas: paga agora e o garoto continua no clube de origem, emprestado,
##     até a temporada em que faz 18 (Player.loan["fut"]).
##   - Mecanismo de solidariedade: 5% de toda transferência internacional vão para os clubes que
##     registraram o jogador dos 12 aos 23 anos (0,25% por ano dos 12 aos 15 e 0,5% por ano dos 16
##     aos 23), descontados do que o vendedor recebe. É a receita que mantém a base de muito clube
##     sul-americano.

const SOLIDARITY := 0.05
const MINOR_AGE := 18
## Mudança dentro da UE/EEE (com a Suíça) é permitida a partir dos 16.
const EU_MIN_AGE := 16
const EU := ["ESP", "GER", "ITA", "FRA", "POR", "NED", "BEL", "AUT", "SUI", "CRO", "CZE", "DEN", "GRE", "IRL", "NOR",
	"SWE", "ISL", "FIN", "POL", "SVK", "SVN", "HUN", "ROU", "BUL", "EST", "LVA", "LTU", "LUX", "CYP", "MLT", "LIE"]


# ---------------------------------------------------------------------------
# Menores de 18
# ---------------------------------------------------------------------------

## A ida para `buyer` agora esbarra na regra dos menores?
## Permissão de trabalho no Reino Unido (pós-Brexit, sistema de pontos GBE): quem não tem passaporte
## britânico ou irlandês precisa somar pontos — seleção forte com jogos, liga e minutos do clube atual,
## nível, e a exceção para promessas sub-21. Vale para europeus também. "" = pode jogar lá.
const UK_CLUBS := ["ENG", "SCO"]
const UK_FREE := ["ENG", "SCO", "WAL", "NIR", "IRL"]
const GBE_PASS := 15


static func permit_block(world: GameWorld, p: Player, buyer: Club) -> String:
	if not UK_CLUBS.has(buyer.nation):
		return ""
	for n in NationalityManager.passports(p):
		if UK_FREE.has(n):
			return ""
	if gbe_points(world, p) >= GBE_PASS:
		return ""
	return "Sem permissão de trabalho no Reino Unido: faltam pontos (seleção, nível da liga e minutos)."


static func gbe_points(world: GameWorld, p: Player) -> int:
	var pts := 0
	var team := NationalityManager.team(p)
	var rec: Dictionary = p.origin.get("records", {}).get(team, {})
	var apps := int(rec.get("apps", 0))
	var tc := LeagueReputation.coef(team)
	if apps >= 10:
		pts += 15 if tc >= 70.0 else (10 if tc >= 50.0 else 5)
	elif apps >= 3:
		pts += 6 if tc >= 60.0 else 3
	var cur := world.club(p.club_id)
	if cur != null:
		var lc := LeagueReputation.coef(cur.nation) * (1.0 if cur.tier == 1 else 0.5)
		pts += 8 if lc >= 85.0 else (6 if lc >= 70.0 else (4 if lc >= 55.0 else (2 if lc >= 40.0 else 0)))
		pts += 6 if p.squad_status <= Player.STATUS_STARTER else (3 if p.squad_status == Player.STATUS_ROTATION else 0)
	if p.overall >= 76:
		pts += 6
	if p.age(world.year) <= 21 and p.potential >= 80:
		pts += 6 # exceção para promessas de elite
	return pts


static func minor_blocked(world: GameWorld, p: Player, buyer: Club) -> bool:
	if p == null or buyer == null:
		return false
	var age := p.age(world.year)
	if age >= MINOR_AGE:
		return false
	var from_nat := p.nationality
	if p.club_id >= 0 and world.club(p.club_id) != null:
		from_nat = world.club(p.club_id).nation
	if from_nat == buyer.nation:
		return false
	return not (age >= EU_MIN_AGE and EU.has(from_nat) and EU.has(buyer.nation))


## Última temporada que o garoto passa no clube de origem (ele se apresenta na seguinte, já com 18).
static func stay_until(p: Player) -> int:
	return p.birth_year + MINOR_AGE - 1


## Depois de comprado, o garoto volta emprestado ao clube de origem até poder se mudar.
static func hold_until_18(world: GameWorld, p: Player, buyer: Club, seller: Club) -> void:
	if seller == null or buyer == null or p.club_id != buyer.id:
		return
	var until := maxi(world.year, stay_until(p))
	TransferManager._move_loan(world, p, buyer, seller)
	p.loan["until"] = until
	p.loan["fut"] = true
	p.contract_end = maxi(p.contract_end, until + 3)
	TransferManager._set_status_on_arrival(world, p, seller)
	world.stat_add("minor_deals")


## Frase da venda antecipada (mensagens, notícias e perfil).
static func hold_note(world: GameWorld, p: Player, buyer: Club, seller: Club) -> String:
	return "Pela regra da FIFA ele só pode se mudar de país aos 18: fica no %s até o fim de %d e se apresenta ao %s em %d." % [
		seller.short_name, maxi(world.year, stay_until(p)), buyer.short_name, maxi(world.year, stay_until(p)) + 1]


static func is_held(p: Player) -> bool:
	return bool(p.loan.get("fut", false))


## Notícia de uma venda antecipada entre clubes da IA (só quando interessa ao usuário).
static func news_hold(world: GameWorld, p: Player, buyer: Club, seller: Club, fee: int) -> void:
	var near := world.has_user() and (seller.nation == world.user_nation() or buyer.nation == world.user_nation())
	if not near and fee < 15_000_000:
		return
	NewsManager.post_raw(world, "%s vende %s ao %s" % [seller.short_name, p.display_name(), buyer.short_name],
		"O %s acertou a venda de %s, de %d anos, ao %s por %s. %s" % [seller.short_name, p.display_name(), p.age(world.year), buyer.short_name, Fmt.money(fee), hold_note(world, p, buyer, seller)],
		buyer.id, p.id, NewsEvent.IMP_HIGH if fee >= 10_000_000 else NewsEvent.IMP_NORMAL, "transferencia")


# ---------------------------------------------------------------------------
# Mecanismo de solidariedade
# ---------------------------------------------------------------------------

## Distribui a solidariedade de uma venda internacional. Retorna quanto sai do valor do vendedor.
## Chamar antes de fechar a passagem do jogador pelo clube vendedor.
static func pay_solidarity(world: GameWorld, p: Player, seller: Club, buyer: Club, fee: int) -> int:
	if fee <= 0 or seller == null or buyer == null or seller.nation == buyer.nation:
		return 0
	var shares := formative_shares(world, p)
	var total := 0
	for cid in shares:
		var c := world.club(int(cid))
		if c == null or c.id == seller.id:
			continue
		var v := int(fee * float(shares[cid]))
		if v <= 0:
			continue
		c.add_ledger("solidariedade", v)
		c.transfer_budget += int(v * 0.5)
		total += v
		world.stat_add("solidarity", v)
		if world.is_user_club(c.id) and v >= 20_000:
			NewsManager.post_raw(world, "Solidariedade pela venda de %s" % p.display_name(),
				"O %s recebeu %s do mecanismo de solidariedade da FIFA pela transferência de %s do %s para o %s. É a parte do clube por ter formado o jogador." % [c.short_name, Fmt.money(v), p.display_name(), seller.short_name, buyer.short_name],
				c.id, p.id, NewsEvent.IMP_HIGH, "transferencia")
	return total


## Clube de registro em cada ano dos 12 aos 23: {club_id: fração do valor}. Antes da primeira
## passagem conhecida vale o clube onde ele começou (a base).
static func formative_shares(world: GameWorld, p: Player) -> Dictionary:
	var out := {}
	var spells: Array = p.spells
	if spells.is_empty():
		return out
	for age in range(12, 24):
		var y := p.birth_year + age
		if y >= world.year:
			break
		var cid := -1
		for s: Dictionary in spells:
			if String(s.get("k", "")) == "e":
				continue # empréstimo: o registro é do dono
			var a := int(s.get("from", 0))
			var b := int(s.get("to", 0))
			if y >= a and (b == 0 or y < b or (y == b and a == b)):
				cid = int(s.get("c", -1))
		if cid < 0 and y < int(spells[0].get("from", 0)):
			cid = int(spells[0].get("c", -1))
		if cid < 0:
			continue
		var frac := SOLIDARITY * (0.05 if age <= 15 else 0.1)
		out[cid] = float(out.get(cid, 0.0)) + frac
	return out
