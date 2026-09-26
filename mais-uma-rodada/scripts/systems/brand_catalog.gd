class_name BrandCatalog
extends RefCounted
## Fonte única das marcas fictícias do mundo (data/world/brands.json): patrocinadores de clube,
## fornecedoras de material esportivo e anunciantes das placas e alambrados.
## Cada país tem as suas marcas, com o peso dos setores que aparecem no peito como no país real
## (apostas no Brasil, seguradoras e energia na Alemanha, aéreas no Golfo...) e as proibições
## locais (sem apostas na Espanha e na Itália, sem cerveja na Turquia e no mundo árabe, sem casa de
## apostas no peito da Premier League). Clubes pequenos ainda ganham marcas de bairro com o nome
## da cidade ("Supermercados Campinas", "Stadtwerke Bochum").
## Uma marca é um Dictionary {n, s (setor), tier (1 local, 2 nacional, 3 grande), c, t, m (símbolo)}.
## Outras telas (sala de imprensa, redes sociais) devem pedir marcas daqui:
##   for_club(world, club)     — patrocinadores e fornecedora que o clube tem hoje
##   brands_for(nation, ...)   — marcas que fazem sentido no país
##   competition_partners(...) — parceiras oficiais de uma liga ou copa
##   find(nome)                — ficha completa de uma marca pelo nome (símbolo, setor, cores)

const TIER_GLOBAL := 3

static var _index: Dictionary = {}


static func _data() -> Dictionary:
	return DatabaseManager.brand_data()


static func sector_name(s: String) -> String:
	return String(_data().get("sectors", {}).get(s, s))


static func nation_cfg(code: String) -> Dictionary:
	return _data().get("nations", {}).get(code, {})


static func confed_of(code: String) -> String:
	return String(DatabaseManager.nation(code).get("confed", ""))


## Nível comercial do clube, pela reputação: 3 atrai as maiores marcas, 1 só as locais.
static func club_tier(c: Club) -> int:
	if c.reputation >= 72.0:
		return 3
	if c.reputation >= 50.0:
		return 2
	return 1


## A marca pode aparecer nesse país? slot "master" na 1ª divisão respeita as regras do peito.
static func allowed(nation: String, sector: String, slot: String = "", league_tier: int = 1) -> bool:
	var ban := String(nation_cfg(nation).get("ban", {}).get(sector, ""))
	if ban == "all":
		return false
	if ban == "master1" and slot == "master" and league_tier <= 1:
		return false
	return true


## Ficha de uma marca pelo nome (patrocinadora, multinacional ou fornecedora). {} se não existir.
static func find(name: String) -> Dictionary:
	if _index.is_empty():
		var d := _data()
		for code in d.get("nations", {}):
			for b: Dictionary in d["nations"][code].get("brands", []):
				var e := b.duplicate()
				e["o"] = code
				_index[String(b["n"])] = e
		for b: Dictionary in d.get("global", []):
			_index[String(b["n"])] = b
		for b: Dictionary in d.get("suppliers", []):
			var e2 := b.duplicate()
			e2["s"] = "material"
			_index[String(b["n"])] = e2
	return _index.get(name, {})


## Marcas de bairro com o nome da cidade do clube (tier 1).
static func local_brands(nation: String, city: String) -> Array:
	var out: Array = []
	if city == "":
		return out
	var d := _data()
	for tpl in nation_cfg(nation).get("local", []):
		var parts := String(tpl).split("|")
		var n := parts[0].replace("{c}", city)
		if n.length() > 24:
			continue
		var s := parts[1] if parts.size() > 1 else "varejo"
		var h := absi(hash(n))
		var pal: Array = d.get("palettes", {}).get(s, [["#1B1B1B", "#FFFFFF"]])
		var col: Array = pal[h % pal.size()]
		var marks: Array = d.get("marks", {}).get(s, ["anel"])
		out.append({"n": n, "s": s, "tier": 1, "c": col[0], "t": col[1], "m": marks[(h / 7) % marks.size()], "o": nation})
	return out


## Marcas que fazem sentido para um clube do país `nation` com nível comercial `tier`.
## Inclui multinacionais que anunciam na confederação (clubes grandes) e, para os menores, as
## marcas de bairro da cidade. `slot` e `league_tier` aplicam as regras do peito.
static func brands_for(nation: String, tier: int, slot: String = "", league_tier: int = 1, city: String = "") -> Array:
	var out: Array = []
	var cfg := nation_cfg(nation)
	var confed := confed_of(nation)
	var own: Array = cfg.get("brands", [])
	for b: Dictionary in own:
		if absi(int(b.get("tier", 1)) - tier) <= 1 and allowed(nation, String(b.get("s", "")), slot, league_tier):
			out.append(b)
	if tier >= 2 or own.is_empty():
		for b: Dictionary in _data().get("global", []):
			var r: Array = b.get("r", [])
			if (r.has(confed) or own.is_empty()) and allowed(nation, String(b.get("s", "")), slot, league_tier):
				if tier >= TIER_GLOBAL or own.is_empty() or absi(hash(String(b["n"]) + nation)) % 3 == 0:
					out.append(b)
	if tier <= 1:
		for b in local_brands(nation, city):
			if allowed(nation, String(b["s"]), slot, league_tier):
				out.append(b)
	return out


## Peso de uma marca para o peito da camisa: o setor forte no país pesa mais.
static func master_weight(nation: String, b: Dictionary) -> float:
	var mix: Dictionary = nation_cfg(nation).get("mix", {})
	return 1.0 + float(mix.get(String(b.get("s", "")), 0.0)) * 1.5


## Fornecedoras que vendem no país, com peso. Os grandes vestem os gigantes globais; os menores,
## marcas continentais e nacionais.
static func suppliers_for(nation: String, tier: int) -> Array:
	var confed := confed_of(nation)
	var out: Array = []
	for b: Dictionary in _data().get("suppliers", []):
		var r: Array = b.get("r", [])
		var local := r.has(nation)
		if not (r.has("all") or r.has(confed) or local):
			continue
		var bt := int(b.get("tier", 1))
		if absi(bt - tier) > 1 and not (local and tier >= 2 and bt >= 1):
			continue
		var w := 1.0
		if bt == tier:
			w += 1.5
		if local:
			w += 1.5 if tier <= 2 else 0.3
		if String(b.get("o", "")) == nation:
			w += 0.8
		if tier >= 3 and bt >= 3:
			w += 3.0
		var e := b.duplicate()
		e["w"] = w
		out.append(e)
	return out


## Sorteio ponderado de uma lista de marcas com "w" (ou pesos em `weights`).
static func pick(rng: RandomNumberGenerator, list: Array, weights: Array = []) -> Dictionary:
	if list.is_empty():
		return {}
	var ws: Array = weights
	if ws.is_empty():
		for b: Dictionary in list:
			ws.append(float(b.get("w", 1.0)))
	var i := RngUtil.weighted_index(rng, ws)
	return list[i] if i >= 0 else list[0]


## Patrocinadores e fornecedora que o clube exibe hoje: [{slot, n, s, c, t, m, logo}].
static func for_club(_world: GameWorld, c: Club) -> Array:
	var out: Array = []
	for s in SponsorManager.SLOTS:
		var ct: Dictionary = c.sponsors.get(s[0], {})
		if ct.is_empty():
			continue
		var e := find(String(ct.get("n", "")))
		var row := {"slot": s[0], "n": ct["n"], "c": ct.get("c", "#1B1B1B"), "t": ct.get("t", "#FFFFFF"),
			"s": ct.get("s", e.get("s", "")), "m": ct.get("m", e.get("m", "")), "logo": ct.get("logo", e.get("logo", ""))}
		out.append(row)
	return out


## Parceiras oficiais de uma competição: ligas pegam grandes marcas do país (a primeira dá nome
## ao campeonato na TV); copas continentais pegam multinacionais da confederação.
static func competition_partners(comp_id: String, nation: String, continental: bool, count: int = 3) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([comp_id, "parceiras"])
	var pool: Array = []
	if continental:
		var confed := String(DatabaseManager.cup_cfg(comp_id).get("confed", confed_of(nation)))
		for b: Dictionary in _data().get("global", []):
			var reach: Array = b.get("r", [])
			if (reach.has(confed) or confed == "" or confed == "FIFA") and String(b.get("s", "")) != "aposta":
				pool.append(b)
	else:
		for b: Dictionary in nation_cfg(nation).get("brands", []):
			if int(b.get("tier", 1)) >= 3 and allowed(nation, String(b.get("s", ""))):
				pool.append(b)
		if pool.size() < count:
			pool.append_array(brands_for(nation, 3))
	RngUtil.shuffle(r, pool)
	var out: Array = []
	var seen := {}
	for b: Dictionary in pool:
		if seen.has(b["n"]):
			continue
		seen[b["n"]] = true
		out.append(b)
		if out.size() >= count:
			break
	return out
