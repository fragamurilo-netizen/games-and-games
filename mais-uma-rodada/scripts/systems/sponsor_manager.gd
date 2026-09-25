class_name SponsorManager
extends RefCounted
## Patrocínios do clube do usuário: master (peito), material esportivo e espaços menores.
## Como na vida real, quem negocia é a diretoria: na pré-temporada ela recebe as propostas para
## os espaços livres e fecha sozinha. O treinador influencia pelo que o time faz em campo — o
## "momento comercial" do clube (Club.commercial) sobe com campanhas acima do esperado e títulos e
## cai com fracassos e rebaixamento, e é ele que define o valor das próximas propostas.
## Todo contrato tem cláusulas de desempenho: bônus por título e por vaga continental, e corte
## no valor em caso de rebaixamento. Também controla a janela da pré-temporada (uniforme).

## [chave, nome, fatia da receita de patrocínio típica do clube]
const SLOTS: Array = [
	["master", "Master (peito)", 0.45],
	["fornecedor", "Material esportivo", 0.1],
	["manga", "Manga", 0.1],
	["costas", "Costas", 0.08],
	["calcao", "Calção", 0.07],
]
## Chave do logo de cada espaço no dicionário do uniforme (KitView).
const KIT_KEYS := {"master": "sp", "fornecedor": "sup", "manga": "sp_m", "costas": "sp_c", "calcao": "sp_s"}
## Placas, licenciamento e patrocínios menores: entram sempre, sem contrato.
const BASE_SHARE := 0.2
## Cláusulas padrão (fração do valor anual): título, vaga continental e corte por rebaixamento.
const TITLE_BONUS := 0.12
const CONT_BONUS := 0.06
const RELEGATION_CUT := 0.3
const COMMERCIAL_MIN := 0.72
const COMMERCIAL_MAX := 1.35


static func slot_name(slot: String) -> String:
	for s in SLOTS:
		if s[0] == slot:
			return String(s[1])
	return slot


static func _share(slot: String) -> float:
	for s in SLOTS:
		if s[0] == slot:
			return float(s[2])
	return 0.0


## A pré-temporada (uniforme e patrocínios liberados) vai até o primeiro jogo do usuário.
static func is_preseason(world: GameWorld) -> bool:
	return world.has_user() and int(world.stats.get("sponsor_pre", -1)) == world.year


## Abre a pré-temporada: encerra contratos vencidos e a diretoria fecha os espaços livres.
static func open_preseason(world: GameWorld) -> void:
	if not world.has_user():
		return
	var club := world.user_club()
	for slot in club.sponsors.keys():
		if int(club.sponsors[slot].get("y", 0)) < world.year:
			club.sponsors.erase(slot)
		else:
			club.sponsors[slot]["e"] = 0 # bônus da temporada recomeçam
	world.stats["sponsor_pre"] = world.year
	world.stats.erase("sp_offers")
	board_signs(world, club)
	apply_to_kits(club)
	apply_income(world, club)


## Fecha a janela da pré-temporada (primeiro jogo). Os contratos já foram fechados pela diretoria.
static func close_preseason(world: GameWorld) -> Array:
	if not is_preseason(world):
		return []
	world.stats["sponsor_pre"] = -1
	world.stats.erase("sp_offers")
	return []


## Saves antigos podiam ter propostas abertas para o treinador escolher; agora a diretoria decide.
static func offers_for(_world: GameWorld, _slot: String) -> Array:
	return []


## A diretoria recebe três propostas por espaço livre (marcas de nível parecido com o do clube) e
## escolhe pelo momento: em alta, trava o valor por mais anos; em baixa, fecha por um ano só,
## esperando recuperar o preço. Retorna os contratos fechados.
static func board_signs(world: GameWorld, club: Club) -> Array:
	var signed: Array = []
	var offers := _make_offers(world, club)
	for s in SLOTS:
		var slot: String = s[0]
		if club.sponsors.has(slot) or not offers.has(slot):
			continue
		var list: Array = offers[slot]
		if list.is_empty():
			continue
		var best: Dictionary = list[0]
		for o: Dictionary in list:
			if _board_score(club, o) > _board_score(club, best):
				best = o
		_sign(world, club, slot, best)
		signed.append(best)
	if not signed.is_empty():
		var parts: Array = []
		var total := 0
		for o: Dictionary in signed:
			parts.append("%s (%s, %s)" % [String(o["n"]), slot_name(String(o["slot"])).to_lower(), Fmt.plural(int(o["yrs"]), "ano", "anos")])
			total += int(o["v"])
		NewsManager.post_raw(world, "Diretoria fecha patrocínios", "O %s acertou %s por ano: %s." % [club.short_name, Fmt.money(total), ", ".join(parts)],
			club.id, -1, NewsEvent.IMP_HIGH)
	return signed


## Valor que a diretoria enxerga numa proposta: o que rende no contrato, com o risco do momento.
static func _board_score(club: Club, o: Dictionary) -> float:
	var yrs := int(o.get("yrs", 1))
	var m := club.commercial
	# Em alta: anos extras valem (o preço de hoje é bom). Em baixa: anos extras custam (preço deprimido).
	var lock := (m - 1.0) * 0.8 * (yrs - 1)
	return float(o["v"]) * (1.0 + lock)


static func _sign(world: GameWorld, club: Club, slot: String, o: Dictionary) -> void:
	var c := o.duplicate()
	c.erase("slot")
	c["y"] = world.year + int(o.get("yrs", 1)) - 1
	c["y0"] = world.year
	club.sponsors[slot] = c


## Receita fixa anual de patrocínio: base + contratos ativos.
static func apply_income(world: GameWorld, club: Club) -> void:
	var total := int(FinanceManager.sponsor_income(club) * BASE_SHARE)
	for slot in club.sponsors:
		total += int(club.sponsors[slot].get("v", 0))
	club.income_sponsor = total


## Logos dos patrocinadores nos uniformes (titular e reserva): peito, fornecedor, manga, costas e calção.
static func apply_to_kits(club: Club) -> void:
	for slot in KIT_KEYS:
		var key: String = KIT_KEYS[slot]
		var m: Dictionary = club.sponsors.get(slot, {})
		for k: Dictionary in [club.kit_home, club.kit_away]:
			if m.is_empty():
				k.erase(key)
			else:
				k[key] = {"n": m["n"], "c": m["c"], "t": m["t"], "logo": m.get("logo", "")}


## Bônus por vitória (contratos "por vitória").
static func on_win(world: GameWorld, club: Club) -> void:
	var bonus := 0
	for slot in club.sponsors:
		var b := int(club.sponsors[slot].get("b", 0))
		if b > 0:
			club.sponsors[slot]["e"] = int(club.sponsors[slot].get("e", 0)) + b
			bonus += b
	if bonus > 0:
		club.add_ledger("bonus_patrocinio", bonus)


## Receita de patrocínio por fonte, para as finanças: [{name, slot, v (por ano), e (bônus ganhos), y}].
## A primeira linha é a base (placas e licenciamento), sem contrato.
static func breakdown(club: Club) -> Array:
	var out: Array = [{"name": "Placas e licenciamento", "slot": "", "v": int(FinanceManager.sponsor_income(club) * BASE_SHARE), "e": 0, "y": 0}]
	for s in SLOTS:
		var c: Dictionary = club.sponsors.get(s[0], {})
		if not c.is_empty():
			out.append({"name": String(c["n"]), "slot": String(s[1]), "v": int(c.get("v", 0)), "e": int(c.get("e", 0)), "y": int(c.get("y", 0))})
	return out


static func _make_offers(world: GameWorld, club: Club) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [world.world_seed, world.year, club.id])
	# O mercado paga pelo momento do clube (já embutido na receita típica de patrocínio).
	var target := float(FinanceManager.sponsor_income(club))
	var tier := 1
	if club.reputation >= 72.0:
		tier = 3
	elif club.reputation >= 50.0:
		tier = 2
	var suppliers: Array = []
	for b in DatabaseManager.kit_suppliers():
		if absi(int(b.get("tier", 1)) - tier) <= 1:
			suppliers.append(b)
	RngUtil.shuffle(rng, suppliers)
	var brands: Array = []
	var used := {}
	for s in club.sponsors.values():
		used[String(s.get("n", ""))] = true
	for b in DatabaseManager.sponsor_brands():
		if absi(int(b.get("tier", 1)) - tier) <= 1 and not used.has(String(b["n"])):
			brands.append(b)
	RngUtil.shuffle(rng, brands)
	var out := {}
	var bi := 0
	for s in SLOTS:
		var slot: String = s[0]
		if club.sponsors.has(slot):
			continue
		var base := target * float(s[2])
		var list: Array = []
		var pool: Array = suppliers if slot == "fornecedor" else brands
		var si := 0
		for yrs in [1, 2, 3]:
			if pool.is_empty():
				break
			var b: Dictionary
			if slot == "fornecedor":
				b = pool[si % pool.size()]
				si += 1
			else:
				b = pool[bi % pool.size()]
				bi += 1
			# Marcas maiores pagam um pouco mais; contratos longos pagam um pouco menos por ano.
			var v: float = base * rng.randf_range(0.92, 1.08) * (1.0 + (int(b.get("tier", 1)) - tier) * 0.08) * (1.0 - (yrs - 1) * 0.03)
			list.append({"n": b["n"], "c": b["c"], "t": b["t"], "logo": b.get("logo", ""), "slot": slot, "yrs": yrs,
				"v": Valuation.round_value(v), "b": 0, "tb": TITLE_BONUS, "qb": CONT_BONUS, "rc": RELEGATION_CUT})
		out[slot] = list
	return out


## Fim de temporada: atualiza o momento comercial de todos os clubes e aplica as cláusulas dos
## contratos do usuário (bônus por título e vaga continental, corte por rebaixamento).
## Chamado por SeasonManager.end_season depois das ligas e copas, antes da virada.
static func season_close(world: GameWorld, moves: Dictionary) -> Array:
	var s := world.season
	var cups_won := {}
	for cid in s.cups:
		var cup: Cup = s.cups[cid]
		if cup.champion >= 0:
			cups_won[cup.champion] = int(cups_won.get(cup.champion, 0)) + 1
	var continental := {}
	for cid in CupManager.continental_ids():
		var cup: Cup = s.cups.get(cid, null)
		if cup != null:
			for c in cup.club_ids:
				continental[int(c)] = true
	var qualified := {}
	var q: Dictionary = world.stats.get("qualified", {})
	for cid in q:
		for c in q[cid]:
			qualified[int(c)] = true
	var notes: Array = []
	for lid in s.league_order:
		var league: League = s.leagues[lid]
		var ids := CompetitionManager.sorted_ids(league)
		var teams := ids.size()
		for i in teams:
			var c := world.club(ids[i])
			var exp := SeasonManager.expected_rank(world, c.id, teams)
			var champion := LeagueFormat.champion(league, ids) == c.id
			var up: bool = moves.has(c.id) and DatabaseManager.league_cfg(moves[c.id]).get("tier", 1) < league.tier
			var down: bool = moves.has(c.id) and DatabaseManager.league_cfg(moves[c.id]).get("tier", 1) > league.tier
			var t := 1.0 + clampf(float(exp - (i + 1)) / maxf(1.0, teams), -0.5, 0.5) * 0.4
			if champion:
				t += 0.12
			t += minf(0.15, int(cups_won.get(c.id, 0)) * 0.06)
			if continental.has(c.id):
				t += 0.04
			if up:
				t += 0.08
			if down:
				t -= 0.15
			c.commercial = clampf(c.commercial * 0.45 + clampf(t, COMMERCIAL_MIN, COMMERCIAL_MAX) * 0.55, COMMERCIAL_MIN, COMMERCIAL_MAX)
			if world.is_user_club(c.id):
				notes = _clauses(world, c, (1 if champion else 0) + int(cups_won.get(c.id, 0)), qualified.has(c.id), down)
	return notes


static func _clauses(world: GameWorld, club: Club, titles: int, qualified: bool, relegated: bool) -> Array:
	var notes: Array = []
	var bonus := 0
	for slot in club.sponsors:
		var ct: Dictionary = club.sponsors[slot]
		var v := int(ct.get("v", 0))
		bonus += int(v * float(ct.get("tb", 0.0)) * titles)
		if qualified:
			bonus += int(v * float(ct.get("qb", 0.0)))
		if relegated and int(ct.get("y", 0)) > world.year:
			ct["v"] = Valuation.round_value(v * (1.0 - float(ct.get("rc", 0.0))))
	if bonus > 0:
		club.add_ledger("bonus_patrocinio", bonus)
		notes.append("Cláusulas de desempenho dos patrocinadores: +%s." % Fmt.money(bonus))
	if relegated and not club.sponsors.is_empty():
		notes.append("Rebaixamento: os contratos em vigor caem %d%% no ano que vem." % int(RELEGATION_CUT * 100))
	return notes


## Como os patrocinadores veem o clube agora, para a tela de patrocínios.
static func market_label(club: Club) -> Array:
	var m := club.commercial
	if m >= 1.18:
		return ["Em alta", UIColors.GREEN]
	if m >= 1.05:
		return ["Valorizado", UIColors.GREEN]
	if m > 0.95:
		return ["Estável", UIColors.MUTED]
	if m > 0.84:
		return ["Em baixa", UIColors.ORANGE]
	return ["Desvalorizado", UIColors.RED]
