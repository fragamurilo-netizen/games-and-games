class_name PreHistory
extends RefCounted
## Passado das competições antes do primeiro ano do jogo. No mundo padrão, usa os campeões
## reais (data/world/history.json) e os títulos de todos os tempos de cada clube; as ligas sem
## lista real ganham um passado gerado pela reputação dos clubes, com "eras" de domínio.
## No mundo aleatório, tudo é gerado. As temporadas entram em `world.history` com "pre": true.

## Temporadas geradas para as ligas sem dados reais.
const GEN_SEASONS := 20


static func build(world: GameWorld) -> void:
	var data: Dictionary = DatabaseManager.get_data("history")
	var real := world.world_type == "padrao" and not data.is_empty()
	# RNG próprio: o passado não mexe no resto da geração do mundo.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(world.world_seed * 31 + 7)
	var years: Dictionary = data.get("years", {}) if real else {}
	var real_only: Array = data.get("real_only", []) if real else []
	var alltime: Dictionary = data.get("alltime", {}) if real else {}
	var start := world.year
	var first := start - 1 - GEN_SEASONS
	var seasons := {} # ano -> {"leagues": {}, "cups": {}}
	var counts := {} # club_id -> {comp: n}
	# Ligas
	for lid in DatabaseManager.league_ids():
		var key := "L:" + lid
		var champs := {}
		if years.has(key):
			champs = _real(world, years[key])
		elif not real_only.has(key):
			champs = _generated(world, rng, _league_clubs(world, lid), first, start - 2)
		for y in champs:
			_season(seasons, int(y))["leagues"][lid] = {"champion": champs[y], "promoted": [], "relegated": [], "pre": true}
			_count(counts, int(champs[y]), key)
	# Copas continentais e Mundial
	for cid in CupManager.continental_ids() + [CupManager.CWC]:
		var key: String = CupManager.title_key(String(cid))
		var champs := {}
		if years.has(key):
			champs = _real(world, years[key])
		elif not real_only.has(key) and cid != CupManager.CWC:
			champs = _generated(world, rng, _confed_clubs(world, String(CupManager.cfg(cid).get("confed", ""))), first, start - 2)
		for y in champs:
			_season(seasons, int(y))["cups"][cid] = {"champion": champs[y], "runner_up": -1, "scorer": {}, "pre": true}
			_count(counts, int(champs[y]), key)
	# Copas nacionais e da liga (mata-mata: mais surpresas que nas ligas) e supercopas reais
	for cid in CupManager.domestic_ids() + CupManager.super_ids():
		var key: String = CupManager.title_key(String(cid))
		var champs := {}
		if years.has(key):
			champs = _real(world, years[key])
		elif not real_only.has(key) and CupManager.is_domestic(String(cid)):
			champs = _generated(world, rng, _nation_clubs(world, String(CupManager.cfg(cid).get("nation", ""))), first, start - 2, 9.0)
		for y in champs:
			_season(seasons, int(y))["cups"][cid] = {"champion": champs[y], "runner_up": -1, "scorer": {}, "pre": true}
			_count(counts, int(champs[y]), key)
	# Títulos no clube: o maior entre a contagem de todos os tempos e a lista de anos.
	for cid in counts:
		var c := world.club(int(cid))
		for k in counts[cid]:
			c.titles[k] = int(counts[cid][k])
	for comp in alltime:
		for ck in alltime[comp]:
			var c := world.club_by_key(String(ck))
			if c != null:
				c.titles[comp] = maxi(c.title_count(comp), int(alltime[comp][ck]))
	# Temporadas no histórico, em ordem, antes das que o save vai criar
	var ys: Array = seasons.keys()
	ys.sort()
	var pre: Array = []
	for y in ys:
		if int(y) >= start:
			continue
		var s: Dictionary = seasons[y]
		pre.append({"y": int(y), "leagues": s["leagues"], "cups": s["cups"], "user": {}, "ballon": {}, "pre": true})
	world.history = pre + world.history


static func _season(seasons: Dictionary, y: int) -> Dictionary:
	if not seasons.has(y):
		seasons[y] = {"leagues": {}, "cups": {}}
	return seasons[y]


static func _count(counts: Dictionary, cid: int, key: String) -> void:
	if not counts.has(cid):
		counts[cid] = {}
	counts[cid][key] = int(counts[cid].get(key, 0)) + 1


## {"2019": "ENG_MSR"} -> {2019: club_id} (clubes que não existem no mundo ficam de fora).
static func _real(world: GameWorld, list: Dictionary) -> Dictionary:
	var out := {}
	for y in list:
		var c := world.club_by_key(String(list[y]))
		if c != null:
			out[int(y)] = c.id
	return out


static func _league_clubs(world: GameWorld, lid: String) -> Array:
	var out: Array = []
	for c: Club in world.clubs:
		if c.league_id == lid:
			out.append(c)
	return out


static func _nation_clubs(world: GameWorld, nation: String) -> Array:
	var out: Array = []
	for c: Club in world.clubs:
		if c.nation == nation:
			out.append(c)
	return out


static func _confed_clubs(world: GameWorld, confed: String) -> Array:
	var out: Array = []
	for c: Club in world.clubs:
		if c.tier == 1 and String(DatabaseManager.nation(c.nation).get("confed", "")) == confed:
			out.append(c)
	return out


## Campeões sorteados pela reputação, com eras de 5 anos em que alguns clubes dominam.
static func _generated(world: GameWorld, rng: RandomNumberGenerator, clubs: Array, from_y: int, to_y: int, spread: float = 6.0) -> Dictionary:
	var out := {}
	if clubs.is_empty():
		return out
	var top := 0.0
	for c: Club in clubs:
		top = maxf(top, c.reputation)
	var era := {}
	for y in range(from_y, to_y + 1):
		if (y - from_y) % 5 == 0:
			for c: Club in clubs:
				era[c.id] = rng.randfn(0.0, 0.45)
		var weights: Array = []
		for c: Club in clubs:
			weights.append(exp((c.reputation - top) / spread + float(era[c.id])))
		var i := RngUtil.weighted_index(rng, weights)
		if i >= 0:
			out[y] = (clubs[i] as Club).id
	return out
