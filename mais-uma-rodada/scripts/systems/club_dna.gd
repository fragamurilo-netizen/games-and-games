class_name ClubDNA
extends RefCounted
## DNA dos clubes (data/gameplay/club_dna.json): o que o clube é, e não só o que falta no elenco.
## A IA não pensa "preciso de um meia 78"; pensa como o clube pensa:
##   rec  filosofia de elenco: formação / compra estrelas / moneyball / veteranos / equilíbrio
##   mkt  alcance do mercado: doméstico / regional / continental / global
##   tac  tática institucional: posse / transição / defesa / intensidade (a escola que sobrevive aos técnicos)
##   pat  paciência com o técnico · fin apetite financeiro · yth uso da base · sell venda de jovens
##   pre  prestígio · amb ambição  (0..100)
##   era  momento do clube: estável, em ascensão, potência, fábrica de talentos, novo rico, em crise,
##        perdendo relevância
##
## O DNA nasce do perfil do clube (arquétipo, filosofia de jogo, política de contratação, tamanho) sem
## usar o RNG do mundo, e muda com o que acontece: donos ricos que chegam e vão embora, presidentes,
## dívida, títulos, subidas e quedas, jovens vendidos, técnicos demitidos. Cada virada fica na linha do
## tempo do clube (dna.log), então depois de 20 temporadas cada clube tem uma história própria.
##
## Guardado em Club.dna: {rec, mkt, tac, pat, fin, yth, sell, pre, amb, era, since, log: [{y, t}],
## h: [{y, lv, rep, ys, yf, kids, t, cc, neg}], tt (títulos já contados), cc (trocas de técnico no ano),
## tacx (temporadas com técnico de outra escola dando certo)}.

const PATH := "res://data/gameplay/club_dna.json"
const PARAMS: Array[String] = ["pat", "fin", "yth", "sell", "pre", "amb"]
const MKT_ORDER: Array[String] = ["domestico", "regional", "continental", "global"]
const LOG_MAX := 24
const HIST_MAX := 8
## Idade até a qual o jogador conta como "jovem" nas vendas e na base.
const YOUNG_SALE_AGE := 23
const YOUNG_PLAY_AGE := 21

static var _data: Dictionary = {}
static var _confed: Dictionary = {}


static func db() -> Dictionary:
	if _data.is_empty():
		var d: Variant = DatabaseManager.read_json(PATH)
		_data = d if d is Dictionary else {"rec": {}, "mkt": {}, "tac": {}, "eras": {}, "params": {}, "archetype": {}}
	return _data


# ---------------------------------------------------------------------------
# Leitura
# ---------------------------------------------------------------------------

## DNA do clube (gerado e guardado na primeira consulta; saves antigos ganham um na hora).
static func of(club: Club) -> Dictionary:
	if club.dna.is_empty() or not club.dna.has("rec"):
		club.dna = _initial(club)
	return club.dna


static func rec(club: Club) -> String:
	return String(of(club)["rec"])


static func mkt(club: Club) -> String:
	return String(of(club)["mkt"])


static func tac(club: Club) -> String:
	return String(of(club)["tac"])


static func era(club: Club) -> String:
	return String(of(club).get("era", "estavel"))


static func val(club: Club, key: String) -> float:
	return float(of(club).get(key, 50.0))


static func info(kind: String, id: String) -> Dictionary:
	return db().get(kind, {}).get(id, {})


static func name_of(kind: String, id: String) -> String:
	return String(info(kind, id).get("name", id))


static func log_of(club: Club) -> Array:
	return of(club).get("log", [])


## Escola (tática institucional) a que uma filosofia de jogo pertence ("" = nenhuma, ex.: pragmático).
static func tac_of_philosophy(ph: String) -> String:
	var tacs: Dictionary = db().get("tac", {})
	for t in tacs:
		if Array(tacs[t].get("ph", [])).has(ph):
			return String(t)
	return ""


# ---------------------------------------------------------------------------
# Nascimento
# ---------------------------------------------------------------------------

static func _initial(club: Club) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash((club.key if club.key != "" else "id%d" % club.id) + "|dna")
	var arch := club.arch()
	var ad: Dictionary = db().get("archetype", {}).get(club.archetype, {})
	var pol := ClubPolicy.of(club)
	# Filosofia de elenco: arquétipo + política real de contratação.
	var rw: Dictionary = Dictionary(ad.get("rec", {"equilibrio": 1})).duplicate()
	if pol.has("buy_age_max"):
		rw["formacao"] = float(rw.get("formacao", 0.0)) + 3.0
		rw["moneyball"] = float(rw.get("moneyball", 0.0)) + 3.0
	if int(pol.get("youth", 0)) >= 12:
		rw["formacao"] = float(rw.get("formacao", 0.0)) + 4.0
	if pol.has("buy_age_min"):
		rw = {"estrelas": 3.0, "veteranos": 3.0}
	var r_id := String(RngUtil.weighted_key(rng, rw))
	# Alcance do mercado: quem tem dinheiro olha o mundo; o pequeno olha a própria cidade.
	var pw := MarketAI.power(club)
	var mw: Dictionary
	if pw >= 1.1:
		mw = {"global": 4.0, "continental": 2.0, "regional": 0.5, "domestico": 0.2}
	elif pw >= 0.7:
		mw = {"continental": 3.0, "global": 1.5, "regional": 2.0, "domestico": 0.5}
	elif club.tier >= 3 or club.reputation < 35.0:
		mw = {"domestico": 4.0, "regional": 2.0, "continental": 0.3}
	else:
		mw = {"regional": 3.0, "domestico": 2.0, "continental": 1.5, "global": 0.3}
	var m_id := String(RngUtil.weighted_key(rng, mw))
	if pol.has("only"):
		m_id = "domestico"
	elif pol.has("buy_age_min"):
		m_id = "global"
	# Escola: vem da filosofia de jogo atual; as neutras (pragmático, pelas pontas) sorteiam.
	var t_id := tac_of_philosophy(ClubPhilosophy.id_of(club))
	if t_id == "":
		t_id = String(RngUtil.weighted_key(rng, {"posse": 1.0, "transicao": 1.2, "defesa": 0.8, "intensidade": 1.0}))
	var trigger := float(People.TRIGGER_HAPPY.get(club.nation, 1.0))
	var d := {"rec": r_id, "mkt": m_id, "tac": t_id}
	d["pat"] = float(arch.get("board_patience", 50)) - (trigger - 1.0) * 30.0 + rng.randf_range(-10.0, 10.0)
	d["fin"] = 25.0 + float(arch.get("spend_rate", 0.35)) * 70.0 + float(arch.get("mismanagement", 0.0)) * 60.0 \
		+ (10.0 if r_id == "estrelas" else 0.0) + rng.randf_range(-8.0, 8.0)
	d["yth"] = float(arch.get("young_share", 0.2)) * 110.0 + (club.youth_level - 50) * 0.3 + float(pol.get("homegrown", 0.0)) * 50.0 \
		+ (12.0 if r_id == "formacao" else 0.0) - (10.0 if r_id == "estrelas" or r_id == "veteranos" else 0.0) + rng.randf_range(-8.0, 8.0)
	d["sell"] = 50.0 + (1.0 - float(arch.get("sell_mult", 1.0))) * 120.0 + (float(arch.get("potential_weight", 0.4)) - 0.4) * 50.0 \
		+ (10.0 if pw < 0.5 else 0.0) + (8.0 if r_id == "moneyball" else 0.0) + rng.randf_range(-8.0, 8.0)
	var honours := club.titles_of_kind("L:") + club.titles_of_kind("C:") * 3 + club.titles_of_kind("W:") * 4
	d["pre"] = club.reputation * 0.85 + minf(15.0, honours * 0.6)
	d["amb"] = 35.0 + (club.reputation - 50.0) * 0.45 + float(ad.get("amb", 0.0)) + rng.randf_range(-10.0, 10.0)
	for k in PARAMS:
		d[k] = snappedf(clampf(float(d[k]), 5.0, 95.0), 0.1)
	d["era"] = String(ad.get("era", "estavel"))
	d["since"] = DatabaseManager.start_year()
	d["log"] = []
	d["h"] = []
	d["tt"] = _titles_total(club)
	d["cc"] = 0
	d["tacx"] = 0
	return d


static func _titles_total(club: Club) -> int:
	var n := 0
	for k in club.titles:
		n += int(club.titles[k])
	return n


# ---------------------------------------------------------------------------
# Efeitos: mercado
# ---------------------------------------------------------------------------

## Faixa de idade que o clube procura no mercado.
static func ages(club: Club) -> Array:
	return info("rec", rec(club)).get("ages", [20, 30])


## Chance de procurar no próprio país (mistura o DNA com o hábito do país).
static func home_share(club: Club, country_domestic: float) -> float:
	var own := float(info("mkt", mkt(club)).get("home", 0.6))
	return clampf(own * 0.65 + country_domestic * 0.35, 0.15, 0.95)


## País onde procurar fora de casa, conforme o alcance do mercado ("" = mercado mundial por nível).
static func away_nation(rng: RandomNumberGenerator, club: Club, sources: Array) -> String:
	match mkt(club):
		"domestico":
			if not sources.is_empty() and rng.randf() < 0.3:
				return String(sources[rng.randi_range(0, sources.size() - 1)])
			return _same_confed(rng, club.nation)
		"regional":
			if not sources.is_empty() and rng.randf() < 0.7:
				return String(sources[rng.randi_range(0, sources.size() - 1)])
			var imp: Dictionary = DatabaseManager.nation(club.nation).get("imports", {})
			if not imp.is_empty():
				return String(RngUtil.weighted_key(rng, imp))
			return _same_confed(rng, club.nation)
		"continental":
			if rng.randf() < 0.8:
				return _same_confed(rng, club.nation)
			return ""
	# Global: rotas de garimpo do país ou o mundo inteiro.
	if not sources.is_empty() and rng.randf() < 0.5:
		return String(sources[rng.randi_range(0, sources.size() - 1)])
	return ""


static func _same_confed(rng: RandomNumberGenerator, nation: String) -> String:
	var conf := String(DatabaseManager.nation(nation).get("confed", ""))
	if conf == "":
		return ""
	if _confed.is_empty():
		var all := DatabaseManager.nations()
		var codes: Array = all.keys()
		codes.sort()
		for code in codes:
			var cf := String(all[code].get("confed", ""))
			if not _confed.has(cf):
				_confed[cf] = []
			_confed[cf].append(code)
	var arr: Array = _confed.get(conf, [])
	if arr.size() <= 1:
		return ""
	var pick := String(arr[rng.randi_range(0, arr.size() - 1)])
	return pick if pick != nation else ""


## Ajuste da nota de um candidato pelo DNA (somado ao placar do mercado da IA).
## surplus = quantos jogadores o clube já tem na família de posições além do mínimo.
static func candidate_bonus(world: GameWorld, club: Club, p: Player, rating: float, level: float, price: float, budget: float, surplus: int) -> float:
	var age := p.age(world.year)
	var s := 0.0
	match rec(club):
		"formacao":
			if age <= 22 and p.potential >= level:
				s += 2.0 + (float(p.potential) - level) * 0.12
			if age >= 29:
				s -= 2.0
		"estrelas":
			if rating >= level + 4.0:
				s += 3.0
			s += price / maxf(50000.0, budget + 1.0) * 1.2 # devolve parte da aversão a preço
		"moneyball":
			# Rende quanto custa? Prefere quem está barato para o que joga.
			var fair := float(Valuation.market_value_of_rating(rating)) * Valuation.age_factor(age)
			if p.stats[Player.S_APPS] >= 8:
				fair *= clampf(1.0 + (p.avg_rating() - 6.8) * 0.2, 0.8, 1.3) # rendimento em campo, não fama
			if price > 0.0:
				s += clampf((fair / maxf(1.0, price) - 1.0) * 3.0, -2.0, 3.0)
			s -= price / maxf(50000.0, budget + 1.0) * 1.5
			if p.contract_years_left(world.year) <= 1:
				s += 1.5
			if age >= 30:
				s -= 2.5 # não paga por quem só vai desvalorizar
		"veteranos":
			if age >= 28:
				s += 2.0
			if age <= 21:
				s -= 2.0
	# Não acumula jogador onde já sobra gente: o mal dos clubes de IA que enchem uma posição.
	if surplus > 0 and rating < level + 2.0:
		s -= 2.5 * surplus
	return s


## Multiplicador do teto de lance pelo apetite financeiro e pela filosofia.
static func bid_mult(club: Club, p: Player, level: float) -> float:
	var m := lerpf(0.88, 1.15, val(club, "fin") / 100.0)
	match rec(club):
		"moneyball":
			m *= 0.9
		"estrelas":
			if p.ovr_f >= level + 3.0:
				m *= 1.1
	return m


## Multiplicador do mínimo que o clube aceita ao vender (jovens: facilidade de venda do DNA).
static func sell_mult(world: GameWorld, seller: Club, p: Player) -> float:
	var m := 1.0
	if p.age(world.year) <= YOUNG_SALE_AGE:
		m *= lerpf(1.35, 0.82, val(seller, "sell") / 100.0)
	if rec(seller) == "moneyball" and p.squad_status <= Player.STATUS_STARTER:
		m *= 0.92 # vende no pico, inclusive titular
	if val(seller, "amb") >= 75.0 and p.squad_status <= Player.STATUS_STARTER:
		m *= 1.1 # ambicioso não se desfaz de quem joga
	return m


## Reforços por janela de verão (ajuste somado ao plano da IA).
static func window_delta(club: Club) -> int:
	var fin := val(club, "fin")
	return (1 if fin >= 70.0 else 0) - (1 if fin <= 30.0 else 0)


## A base tem um garoto pronto para essa posição? Clube que usa a base não compra por cima dele.
static func kid_blocks(world: GameWorld, club: Club, fam: int, level: float) -> bool:
	var yth := val(club, "yth")
	if yth < 45.0:
		return false
	for p: Player in world.squad(club):
		if p.age(world.year) > YOUNG_PLAY_AGE or TransferManager._family_of(p.position) != fam or not p.loan.is_empty():
			continue
		if p.potential >= level + 2.0 and p.ovr_f >= level - 7.0:
			return world.rng.randf() < yth / 100.0
	return false


# ---------------------------------------------------------------------------
# Efeitos: base, orçamento e técnico
# ---------------------------------------------------------------------------

## Bônus na escolha do time titular (clubes da IA): quem usa a base dá minutos aos garotos.
static func selection_bonus(club: Club, p: Player, year: int) -> float:
	var age := p.age(year)
	if age > YOUNG_PLAY_AGE:
		return 0.0
	var yth := val(club, "yth")
	return maxf(0.0, (yth - 35.0) / 65.0) * (2.2 if age <= 19 else 1.5)


## Garotos extras promovidos por ano (clubes da IA).
static func intake_extra(club: Club) -> int:
	var yth := val(club, "yth")
	return 1 if yth >= 70.0 else (-1 if yth <= 20.0 else 0)


## Fator sobre a fatia do caixa liberada para contratações.
static func spend_mult(club: Club) -> float:
	return lerpf(0.7, 1.35, val(club, "fin") / 100.0)


## Paciência da diretoria (0..100), na mesma escala do board_patience dos arquétipos.
static func patience(club: Club) -> float:
	return val(club, "pat")


## Filosofia de jogo que o técnico novo traz: a escola do clube costuma prevalecer.
static func new_coach_philosophy(club: Club, rng: RandomNumberGenerator, coach_style: String) -> String:
	var fam: Array = info("tac", tac(club)).get("ph", [])
	var keep := 0.55 + val(club, "pre") / 400.0 # clube grande impõe a escola
	if not fam.is_empty() and rng.randf() < keep:
		return String(fam[rng.randi_range(0, fam.size() - 1)])
	var ids: Array = ClubPhilosophy.ids()
	ids.sort()
	if coach_style == "pragmatico" or coach_style == "estrategista":
		return "pragmatico"
	return String(ids[rng.randi_range(0, ids.size() - 1)])


# ---------------------------------------------------------------------------
# Mudanças: acontecimentos do mundo
# ---------------------------------------------------------------------------

static func _add(d: Dictionary, key: String, delta: float) -> void:
	d[key] = snappedf(clampf(float(d.get(key, 50.0)) + delta, 3.0, 97.0), 0.1)


static func add_log(world: GameWorld, club: Club, text: String) -> void:
	var d := of(club)
	var lg: Array = d.get("log", [])
	lg.append({"y": world.year, "t": text})
	if lg.size() > LOG_MAX:
		lg = lg.slice(lg.size() - LOG_MAX)
	d["log"] = lg


static func _set_era(world: GameWorld, club: Club, e: String, text: String) -> void:
	var d := of(club)
	d["era"] = e
	d["since"] = world.year
	add_log(world, club, text)


static func _step_mkt(club: Club, steps: int) -> void:
	var d := of(club)
	var i := MKT_ORDER.find(String(d["mkt"]))
	d["mkt"] = MKT_ORDER[clampi(i + steps, 0, MKT_ORDER.size() - 1)]


## Investidor compra o clube: dinheiro, pressa, estrelas e olheiros pelo mundo.
static func on_takeover(world: GameWorld, club: Club, who: String) -> void:
	var d := of(club)
	d["fin"] = maxf(float(d["fin"]), 85.0)
	d["amb"] = maxf(float(d["amb"]), 80.0)
	d["pat"] = minf(float(d["pat"]), 35.0)
	var old := rec(club)
	if not world.is_user_club(club.id):
		d["rec"] = "estrelas"
	_step_mkt(club, 2)
	var txt := "Comprado por %s: dinheiro novo, pressa e mercado %s." % [who, name_of("mkt", mkt(club)).to_lower()]
	if old != rec(club):
		txt += " A filosofia muda de %s para %s." % [name_of("rec", old).to_lower(), name_of("rec", rec(club)).to_lower()]
	_set_era(world, club, "novo_rico", txt)


## O dono vai embora: fim da farra, venda de jovens e aposta na base ou nos números.
static func on_owner_exit(world: GameWorld, club: Club, who: String) -> void:
	var d := of(club)
	d["fin"] = minf(float(d["fin"]), 25.0)
	_add(d, "amb", -15.0)
	_add(d, "sell", 15.0)
	_add(d, "yth", 8.0)
	if not world.is_user_club(club.id):
		d["rec"] = "formacao" if float(d["yth"]) >= 45.0 else "moneyball"
	_step_mkt(club, -1)
	_set_era(world, club, "crise", "%s vai embora e deixa dívida. O clube passa a viver de %s." % [who, name_of("rec", rec(club)).to_lower()])


## Presidente novo: a promessa de campanha vira DNA.
static func on_president(world: GameWorld, club: Club, promise: String) -> void:
	var d := of(club)
	var txt := ""
	match promise:
		"promete austeridade":
			_add(d, "fin", -10.0)
			_add(d, "sell", 5.0)
			txt = "Novo presidente promete austeridade: menos gastos, mais vendas."
		"promete reforços":
			_add(d, "fin", 10.0)
			_add(d, "amb", 5.0)
			txt = "Novo presidente promete reforços: o cofre abre."
		"diz que confia no trabalho atual":
			_add(d, "pat", 10.0)
			txt = "Novo presidente aposta em continuidade: mais paciência com o técnico."
		"quer a base no time principal":
			_add(d, "yth", 12.0)
			_add(d, "sell", -5.0)
			txt = "Novo presidente quer a base no time principal."
	if txt != "":
		add_log(world, club, txt)


## Recuperação judicial: o DNA aperta o cinto.
static func on_crisis(world: GameWorld, club: Club) -> void:
	var d := of(club)
	_add(d, "fin", -12.0)
	_add(d, "sell", 10.0)
	_add(d, "yth", 6.0)
	if era(club) != "crise":
		_set_era(world, club, "crise", "Recuperação judicial: o clube passa a vender e a apostar na base.")


## Troca de técnico (conta para a paciência da diretoria ao longo dos anos).
static func on_coach_change(club: Club) -> void:
	var d := of(club)
	d["cc"] = int(d.get("cc", 0)) + 1


# ---------------------------------------------------------------------------
# Mudanças: balanço de cada temporada
# ---------------------------------------------------------------------------

## Patamar do clube no país: 1ª divisão vale mais que 2ª, e a posição conta dentro dela.
static func standing(tier: int, pos: int, teams: int) -> float:
	return float(6 - clampi(tier, 1, 5)) + (1.0 - float(pos - 1) / maxf(1.0, teams - 1))


## Fim de temporada (antes da troca de divisões): registra o ano e deixa o DNA reagir ao que aconteceu.
## moves: club_id -> liga da temporada seguinte (acessos e quedas).
static func season_end(world: GameWorld, moves: Dictionary) -> void:
	var young_sales := {}
	for t: Transfer in world.transfer_log:
		if t.year != world.year or t.kind != Transfer.KIND_BUY or t.from_id < 0 or t.age > YOUNG_SALE_AGE or t.fee <= 0:
			continue
		var row: Array = young_sales.get(t.from_id, [0, 0])
		young_sales[t.from_id] = [int(row[0]) + 1, int(row[1]) + t.fee]
	for c: Club in world.clubs:
		_season_club(world, c, moves, young_sales.get(c.id, [0, 0]))


static func _season_club(world: GameWorld, c: Club, moves: Dictionary, sales: Array) -> void:
	var d := of(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(world.world_seed, world.year * 131 + 17, c.id)
	var pos := 0
	var teams := 0
	if world.season != null and world.season.leagues.has(c.league_id):
		var league: League = world.season.leagues[c.league_id]
		teams = league.table.size()
		pos = CompetitionManager.position_of(league, c.id)
	var lv := standing(c.tier, pos, teams) if pos > 0 else (float(d["h"].back()["lv"]) if not d["h"].is_empty() else standing(c.tier, 10, 20))
	var promoted := false
	var relegated := false
	if moves.has(c.id):
		var nt := int(DatabaseManager.league_cfg(String(moves[c.id])).get("tier", c.tier))
		promoted = nt < c.tier
		relegated = nt > c.tier
	var total := _titles_total(c)
	var new_titles := maxi(0, total - int(d.get("tt", total)))
	d["tt"] = total
	var kids := 0
	for p: Player in world.squad(c):
		if p.age(world.year) <= YOUNG_PLAY_AGE and p.stats.size() > Player.S_APPS and p.stats[Player.S_APPS] >= 15:
			kids += 1
	var cc := int(d.get("cc", 0))
	d["cc"] = 0
	var revenue := float(FinanceManager.expected_revenue(c))
	# Dívida "normal" (até meio ano de receita, como quase todo clube) não pesa no DNA.
	var debt := maxf(0.0, FinanceManager.debt_ratio(c, revenue) - 0.5)
	var h: Array = d.get("h", [])
	h.append({"y": world.year, "lv": snappedf(lv, 0.01), "rep": snappedf(c.reputation, 0.1), "ys": int(sales[0]), "yf": int(sales[1]),
		"kids": kids, "t": new_titles, "cc": cc, "neg": debt > 0.0})
	if h.size() > HIST_MAX:
		h = h.slice(h.size() - HIST_MAX)
	d["h"] = h
	# Deriva lenta dos números: o clube vira aquilo que faz.
	var pre_target := clampf(c.reputation * 0.9 + new_titles * 4.0, 3.0, 97.0)
	_add(d, "pre", (pre_target - float(d["pre"])) * 0.12)
	var amb_target := 35.0 + (c.reputation - 50.0) * 0.45 + float(db().get("archetype", {}).get(c.archetype, {}).get("amb", 0.0))
	var amb_d := (amb_target - float(d["amb"])) * 0.1 + rng.randf_range(-1.5, 1.5) + new_titles * 2.0
	if promoted:
		amb_d += 4.0
	if relegated:
		amb_d -= 3.0
	_add(d, "amb", amb_d)
	_add(d, "yth", clampf((kids - 2) * 1.2, -2.0, 4.0))
	_add(d, "sell", clampf(float(sales[0]) * 2.5 - 1.5, -2.0, 6.0) + (2.0 if debt > 0.3 else 0.0))
	if debt > 0.0:
		_add(d, "fin", -(3.0 + minf(6.0, debt * 6.0)))
	elif c.balance > revenue:
		_add(d, "fin", 2.0)
	if cc >= 2:
		_add(d, "pat", -4.0) # cultura de demissão
	elif cc == 0:
		_add(d, "pat", 1.5)
	_school_drift(world, c, d, lv, new_titles)
	_update_era(world, c, d, rng, debt, revenue, promoted)


## Técnico de outra escola que dá certo por três temporadas muda a escola do clube.
static func _school_drift(world: GameWorld, c: Club, d: Dictionary, lv: float, new_titles: int) -> void:
	var cur := tac_of_philosophy(ClubPhilosophy.id_of(c))
	if cur == "" or cur == String(d["tac"]):
		d["tacx"] = 0
		return
	var h: Array = d["h"]
	var better := new_titles > 0 or (h.size() >= 2 and lv > float(h[h.size() - 2]["lv"]) + 0.05)
	d["tacx"] = int(d.get("tacx", 0)) + 1 if better else 0
	if int(d["tacx"]) >= 3:
		var old := String(d["tac"])
		d["tac"] = cur
		d["tacx"] = 0
		add_log(world, c, "A escola mudou: depois de anos de sucesso, o clube troca %s por %s." % [name_of("tac", old).to_lower(), name_of("tac", cur).to_lower()])


static func _update_era(world: GameWorld, c: Club, d: Dictionary, rng: RandomNumberGenerator, debt: float, revenue: float, promoted: bool) -> void:
	var cur := String(d.get("era", "estavel"))
	var yrs := world.year - int(d.get("since", world.year))
	if cur == "novo_rico" and yrs < 3 and debt < 0.6:
		return
	var h: Array = d["h"]
	var n := h.size()
	var ys3 := 0
	var yf3 := 0
	var t3 := 0
	for i in range(maxi(0, n - 3), n):
		ys3 += int(h[i]["ys"])
		yf3 += int(h[i]["yf"])
		t3 += int(h[i]["t"])
	var lv_now := float(h[n - 1]["lv"])
	var lv_old := float(h[maxi(0, n - 4)]["lv"])
	var rep_old := float(h[maxi(0, n - 4)]["rep"])
	var e := "estavel"
	if debt > 0.6:
		e = "crise"
	elif ys3 >= 4 and float(yf3) >= revenue * 0.35:
		e = "fabrica"
	elif float(d["pre"]) >= 75.0 and t3 >= 2:
		e = "potencia"
	elif n >= 3 and (lv_now - lv_old >= 0.9 or c.reputation - rep_old >= 6.0):
		e = "crescendo"
	elif n >= 3 and (lv_now - lv_old <= -0.9 or c.reputation - rep_old <= -6.0):
		e = "decadencia"
	# Uma era fica pelo menos duas temporadas, a não ser que o motivo seja forte (dívida ou salto).
	if e == cur or (yrs < 2 and e != "crise" and not promoted):
		return
	if e == "estavel" and cur != "novo_rico" and yrs < 4:
		return
	var txt := ""
	match e:
		"crise":
			_add(d, "fin", -12.0)
			_add(d, "sell", 8.0)
			_add(d, "yth", 6.0)
			if String(d["rec"]) == "estrelas" and not world.is_user_club(c.id):
				d["rec"] = "moneyball" if rng.randf() < 0.5 else "formacao"
			txt = "Dívida de %s: o clube entra em crise e passa a %s." % [Fmt.money(-c.balance), name_of("rec", String(d["rec"])).to_lower()]
		"fabrica":
			_add(d, "sell", 6.0)
			_add(d, "yth", 5.0)
			if String(d["rec"]) != "formacao" and String(d["rec"]) != "moneyball" and not world.is_user_club(c.id) and rng.randf() < 0.6:
				d["rec"] = "formacao"
			txt = "Virou fábrica de talentos: %d jovens vendidos em três temporadas, %s arrecadados." % [ys3, Fmt.money(yf3)]
		"potencia":
			_add(d, "amb", 6.0)
			_step_mkt(c, 1)
			txt = "Potência: %d títulos em três temporadas. O mercado agora é %s." % [t3, name_of("mkt", String(d["mkt"])).to_lower()]
		"crescendo":
			_add(d, "amb", 6.0)
			if rng.randf() < 0.5:
				_step_mkt(c, 1)
			txt = "Em ascensão: o clube subiu de patamar nas últimas temporadas."
		"decadencia":
			_add(d, "amb", -6.0)
			if String(d["mkt"]) == "global" and rng.randf() < 0.5:
				_step_mkt(c, -1)
			txt = "Perdendo relevância: o nome ainda pesa, mas os resultados sumiram."
		_:
			txt = "Fase estável depois de %s." % name_of("eras", cur).to_lower()
	_set_era(world, c, e, txt)
	if e != "estavel" and WorldEvents.newsworthy(world, c) and not world.is_user_club(c.id):
		var titles := {"crise": "%s em crise", "fabrica": "%s vira fábrica de talentos", "potencia": "%s vira potência",
			"crescendo": "%s em ascensão", "decadencia": "%s perde relevância"}
		NewsManager.post_raw(world, String(titles[e]) % c.short_name, txt, c.id, -1, NewsEvent.IMP_NORMAL, "clube")
	elif world.is_user_club(c.id) and e != "estavel":
		NewsManager.post_raw(world, "Nova fase no %s" % c.short_name, txt, c.id, -1, NewsEvent.IMP_HIGH, "clube")
