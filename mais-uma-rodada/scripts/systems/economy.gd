class_name Economy
extends RefCounted
## Economia 2026 (data/world/economy.json): receitas e dívidas reais dos clubes de referência
## e o câmbio. As contas do jogo são em euros; a receita de um clube de país com moeda própria
## segue o câmbio dela (real mais fraco = Flamengo com menos euros para gastar). O câmbio anda
## a cada virada de temporada, com volta parcial ao patamar de partida (câmbio real, sem inflação).
##
## Estado: world.stats["fx"] = {moeda: unidades por euro}; Club.rev_k = força comercial do clube
## além do que a reputação explica (âncora real).

const PATH := "res://data/world/economy.json"
const VERSION := 1

static var _cfg: Dictionary = {}
## moeda → câmbio de partida ÷ câmbio atual (1 = como em out/2026; < 1 = moeda local mais fraca)
static var _mult: Dictionary = {}
## moeda → unidades por euro hoje (exibição em R$ e US$)
static var _rate: Dictionary = {}


static func cfg() -> Dictionary:
	if _cfg.is_empty():
		var d: Variant = DatabaseManager.read_json(PATH)
		_cfg = d if d is Dictionary else {"fx": {}, "currency": {}, "clubs": {}}
	return _cfg


static func currency_of(nation: String) -> String:
	return String(cfg()["currency"].get(nation, "EUR"))


## Quanto o câmbio de hoje mexe na receita em euros de um clube do país (1 = como no começo).
static func fx_factor(nation: String) -> float:
	return float(_mult.get(currency_of(nation), 1.0))


static func base_rate(code: String) -> float:
	return float(cfg()["fx"].get(code, {}).get("rate", 1.0))


## Unidades da moeda por 1 euro hoje.
static func rate(code: String) -> float:
	return float(_rate.get(code, base_rate(code)))


## Liga o câmbio salvo no mundo (criação, carregamento) e dá as âncoras aos saves antigos.
static func ensure(world: GameWorld) -> void:
	var fx: Dictionary = world.stats.get("fx", {})
	for code in cfg()["fx"]:
		if not fx.has(code):
			fx[code] = base_rate(code)
	world.stats["fx"] = fx
	_apply_rates(fx)
	if int(world.stats.get("eco_v", 0)) < VERSION:
		world.stats["eco_v"] = VERSION
		# Save de antes da Economia 2026: só a força comercial (as dívidas da carreira ficam como estão).
		for c: Club in world.clubs:
			if is_equal_approx(c.rev_k, 1.0):
				anchor_revenue(c)


static func _apply_rates(fx: Dictionary) -> void:
	_mult.clear()
	_rate.clear()
	for code in fx:
		_rate[code] = float(fx[code])
		_mult[code] = base_rate(code) / maxf(0.0001, float(fx[code]))


## Âncora real do clube: [receita € mi, dívida € mi] ou [] se não houver.
static func real_of(c: Club) -> Array:
	return cfg()["clubs"].get(c.key, [])


## Força comercial para a receita do clube bater com a real (só os clubes de referência).
static func anchor_revenue(c: Club) -> void:
	var real := real_of(c)
	if real.is_empty():
		return
	var want := float(real[0]) * 1_000_000.0 * fx_factor(c.nation)
	for _i in 3:
		var now := float(FinanceManager.expected_revenue(c))
		var t := FinanceManager.club_revenue_target(c) / maxf(0.01, c.rev_k)
		var step := (want - now) / maxf(1.0, t * c.commercial)
		c.rev_k = clampf(c.rev_k + step, 0.3, 6.0)


## Dívida real (em €) do clube de referência, ou -1.
static func real_debt(c: Club) -> int:
	var real := real_of(c)
	if real.is_empty() or float(real[1]) < 0.0:
		return -1
	return int(round(float(real[1]) * 1_000_000.0 * fx_factor(c.nation) / 10000.0)) * 10000


## Virada de temporada: o câmbio anda. Retorna as manchetes das moedas que mais mexeram.
static func season_fx(world: GameWorld) -> Array:
	var fx: Dictionary = world.stats.get("fx", {})
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, world.year, 7311)
	var out: Array = []
	for code in cfg()["fx"]:
		var c: Dictionary = cfg()["fx"][code]
		var base := float(c["rate"])
		var old := float(fx.get(code, base))
		# Passeio aleatório em log com volta ao patamar de partida.
		var lg := log(old / base) * (1.0 - float(c.get("pull", 0.35))) + RngUtil.gauss(r, 0.0, float(c.get("vol", 0.06)))
		var nw := base * exp(clampf(lg, -0.45, 0.45))
		fx[code] = snappedf(nw, 0.0001 if nw < 10.0 else 0.01)
		var ch := nw / old - 1.0
		if absf(ch) >= 0.08:
			out.append({"code": code, "old": old, "new": nw, "ch": ch})
	world.stats["fx"] = fx
	_apply_rates(fx)
	for e: Dictionary in out:
		_fx_news(world, e)
	return out


static func _fx_news(world: GameWorld, e: Dictionary) -> void:
	var code := String(e["code"])
	var name := String(cfg()["fx"][code].get("name", code))
	var weaker := float(e["ch"]) > 0.0 # mais unidades por euro = moeda local mais fraca
	var nations: Array = []
	for n in cfg()["currency"]:
		if String(cfg()["currency"][n]) == code:
			nations.append(n)
	var who: String = String(DatabaseManager.nation(String(nations[0])).get("adj", "")) if not nations.is_empty() else ""
	var pct := int(round(absf(float(e["ch"])) * 100.0))
	var title := ("O %s perde %d%% para o euro" if weaker else "O %s ganha %d%% sobre o euro") % [name, pct]
	var body := ("Com o câmbio a %s, os clubes %ss perdem poder de compra lá fora e a venda para o exterior fica mais atraente." if weaker else
		"Com o câmbio a %s, os clubes %ss ganham fôlego para segurar os seus jogadores e buscar reforços no exterior.") % [_rate_text(code, float(e["new"])), String(who)]
	if world.has_user() and currency_of(world.user_club().nation) == code:
		NewsManager.post_raw(world, title, body, world.user_club_id, -1, NewsEvent.IMP_HIGH, "clube")
	else:
		NewsManager.post_raw(world, title, body, -1, -1, NewsEvent.IMP_NORMAL, "mundo")


static func _rate_text(code: String, v: float) -> String:
	match code:
		"BRL":
			return "R$ %s" % String.num(v, 2).replace(".", ",")
		"USD":
			return "US$ %s" % String.num(v, 2).replace(".", ",")
	return "%s %s" % [String.num(v, 2 if v < 100.0 else 0).replace(".", ","), code]
