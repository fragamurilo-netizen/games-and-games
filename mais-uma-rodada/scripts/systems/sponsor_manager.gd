class_name SponsorManager
extends RefCounted
## Patrocínios do clube do usuário: master (peito) e espaços menores (manga, costas, calção).
## Na pré-temporada cada espaço livre recebe três propostas; o usuário escolhe. O que ficar
## vazio até o primeiro jogo, a diretoria fecha com a proposta mais segura.
## Também controla a janela da pré-temporada, quando o uniforme pode ser redesenhado.

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
const KINDS: Array = ["fixo", "vitoria", "longo"]
const KIND_NAMES := {"fixo": "Valor fixo", "vitoria": "Por vitória", "longo": "Longo prazo"}


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
	return world.has_user() and int(world.stats.get("pre", -1)) == world.year


## Abre a pré-temporada: encerra contratos vencidos e gera propostas para os espaços livres.
static func open_preseason(world: GameWorld) -> void:
	if not world.has_user():
		return
	var club := world.user_club()
	for slot in club.sponsors.keys():
		if int(club.sponsors[slot].get("y", 0)) < world.year:
			club.sponsors.erase(slot)
	apply_to_kits(club)
	world.stats["pre"] = world.year
	world.stats["sp_offers"] = _make_offers(world, club)
	apply_income(world, club)


## Fecha a pré-temporada (primeiro jogo): espaços vazios ficam com a proposta de valor fixo.
static func close_preseason(world: GameWorld) -> Array:
	var signed: Array = []
	if not is_preseason(world):
		return signed
	var club := world.user_club()
	var offers: Dictionary = world.stats.get("sp_offers", {})
	for s in SLOTS:
		var slot: String = s[0]
		if club.sponsors.has(slot):
			continue
		var list: Array = offers.get(slot, [])
		if list.is_empty():
			continue
		_sign(world, club, slot, list[0])
		signed.append("%s (%s)" % [String(list[0]["n"]), slot_name(slot).to_lower()])
	world.stats["pre"] = -1
	world.stats.erase("sp_offers")
	if not signed.is_empty():
		NewsManager.post_raw(world, "Diretoria fecha patrocínios", "Sem escolha do treinador, a diretoria acertou com: %s." % ", ".join(signed), club.id, -1, NewsEvent.IMP_NORMAL)
	return signed


static func offers_for(world: GameWorld, slot: String) -> Array:
	return world.stats.get("sp_offers", {}).get(slot, [])


## Usuário assina uma das propostas de um espaço.
static func sign(world: GameWorld, slot: String, index: int) -> Dictionary:
	if not is_preseason(world):
		return {"ok": false, "msg": "Patrocínios só são fechados na pré-temporada."}
	var club := world.user_club()
	if club.sponsors.has(slot):
		return {"ok": false, "msg": "Esse espaço já tem contrato."}
	var list := offers_for(world, slot)
	if index < 0 or index >= list.size():
		return {"ok": false, "msg": "Proposta indisponível."}
	var o: Dictionary = list[index]
	_sign(world, club, slot, o)
	if slot == "fornecedor":
		return {"ok": true, "msg": "%s vai fornecer o material esportivo do %s!" % [String(o["n"]), club.short_name]}
	var where := {"master": "master", "manga": "da manga", "costas": "das costas", "calcao": "do calção"}
	return {"ok": true, "msg": "%s é o novo patrocinador %s do %s!" % [String(o["n"]), String(where.get(slot, slot)), club.short_name]}


static func _sign(world: GameWorld, club: Club, slot: String, o: Dictionary) -> void:
	var c := o.duplicate()
	c["y"] = world.year + int(o.get("yrs", 1)) - 1
	club.sponsors[slot] = c
	apply_income(world, club)
	apply_to_kits(club)
	NewsManager.post_raw(world, "%s fecha com %s" % [club.short_name, String(o["n"])],
		"Acordo de patrocínio (%s) por %s/ano%s, até %d." % [slot_name(slot).to_lower(), Fmt.money(int(o["v"])),
		(" + %s por vitória" % Fmt.money(int(o["b"]))) if int(o.get("b", 0)) > 0 else "", int(c["y"])],
		club.id, -1, NewsEvent.IMP_HIGH if slot == "master" else NewsEvent.IMP_NORMAL)


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
				k[key] = {"n": m["n"], "c": m["c"], "t": m["t"]}


## Bônus por vitória (contratos "por vitória").
static func on_win(world: GameWorld, club: Club) -> void:
	var bonus := 0
	for slot in club.sponsors:
		bonus += int(club.sponsors[slot].get("b", 0))
	if bonus > 0:
		club.add_ledger("patrocinio", bonus)


static func _make_offers(world: GameWorld, club: Club) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%d" % [world.world_seed, world.year, club.id])
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
	var games := maxi(10, FinanceManager.home_games(club.league_id) * 2)
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
		for kind in KINDS:
			if pool.is_empty():
				break
			var b: Dictionary
			if slot == "fornecedor":
				b = pool[si % pool.size()]
				si += 1
			else:
				b = pool[bi % pool.size()]
				bi += 1
			# Marcas maiores pagam um pouco mais.
			var v := base * rng.randf_range(0.9, 1.08) * (1.0 + (int(b.get("tier", 1)) - tier) * 0.08)
			var o := {"n": b["n"], "c": b["c"], "t": b["t"], "kind": kind, "yrs": 1, "v": 0, "b": 0}
			match kind:
				"fixo":
					o["v"] = Valuation.round_value(v)
				"vitoria":
					# Fixo menor + bônus: empata com o fixo ganhando ~45% dos jogos, rende mais acima disso.
					o["v"] = Valuation.round_value(v * 0.55)
					o["b"] = Valuation.round_wage(v * 0.5 / (games * 0.45))
				"longo":
					o["v"] = Valuation.round_value(v * 0.94)
					o["yrs"] = 3
			list.append(o)
		out[slot] = list
	return out
