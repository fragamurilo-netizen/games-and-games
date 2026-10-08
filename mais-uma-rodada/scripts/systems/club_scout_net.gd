class_name ClubScoutNet
extends RefCounted
## Departamento de observação dos clubes da IA. Cada clube tem olheiros conforme o dinheiro, a
## reputação e o alcance de mercado do DNA (doméstico, regional, continental, global), e cada um
## cobre um conjunto de ligas: a própria, a divisão de baixo, as rotas de garimpo do país, o
## continente ou o mundo. Todo fim de semana os olheiros assistem a jogos dessas ligas (um rodízio
## pelas partidas da data, não sorteio) e anotam quem pode servir: o conhecimento sobe a cada jogo
## visto e a avaliação fica mais precisa (erro fixo por clube e jogador, que encolhe com o
## conhecimento). É dessa lista — e do que os empresários oferecem — que sai o reforço (TransferBrain).
##
## Estado: world.stats["csn"][str(club_id)] = {"k": {pid: conhecimento 0..100}, "t": {pid: turno visto}}

const MAX_KNOWN := 80 # jogadores acompanhados por clube (os menos úteis saem da lista)
const MAX_TIER := 2 # da 3ª divisão para baixo não há departamento: só o que os empresários oferecem
const KNOW_PER_GAME := 14.0
const STALE_TURNS := 60 # sem ver o jogador por tanto tempo, o conhecimento cai pela metade


static func data(world: GameWorld) -> Dictionary:
	if not world.stats.has("csn"):
		world.stats["csn"] = {}
	return world.stats["csn"]


static func of(world: GameWorld, club_id: int) -> Dictionary:
	var d := data(world)
	var key := str(club_id)
	if not d.has(key):
		d[key] = {"k": {}, "t": {}}
	return d[key]


## Apaga o que o departamento do clube acompanha (o próximo `ensure_known` monta a lista de novo).
static func forget(world: GameWorld, c: Club) -> void:
	var mem := of(world, c.id)
	(mem["k"] as Dictionary).clear()
	(mem["t"] as Dictionary).clear()


## Quantos olheiros o clube tem.
static func scouts(c: Club) -> int:
	var base: int = int({"domestico": 1, "regional": 2, "continental": 3, "global": 5}.get(ClubDNA.mkt(c), 2))
	base += int(MarketAI.power(c) * 2.5)
	base -= maxi(0, c.tier - 1)
	return clampi(base, 1, 10)


## Qualidade da avaliação (0,5..1,1): reputação e estrutura.
static func quality(c: Club) -> float:
	return clampf(0.45 + c.reputation / 200.0 + c.facilities / 500.0, 0.5, 1.1)


## Ligas que o departamento cobre (montado na primeira consulta da temporada e guardado no mundo:
## a reputação muda durante o ano, e o save carregado tem de cobrir as mesmas ligas do original).
static func covered(world: GameWorld, c: Club) -> Array:
	var cc: Dictionary = world.stats.get("csn_cov", {})
	if int(cc.get("y", -1)) != world.year:
		cc = {"y": world.year, "c": {}}
		world.stats["csn_cov"] = cc
	var cache: Dictionary = cc["c"]
	var key := str(c.id)
	if cache.has(key):
		return cache[key]
	var out: Array = [c.league_id]
	var nat := c.nation
	# A divisão de baixo do próprio país (achados baratos) e a de cima (quem caiu e quer voltar).
	for lid in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(lid)
		if String(cfg.get("nation", "")) == nat and absi(int(cfg.get("tier", 1)) - c.tier) == 1:
			out.append(lid)
	var prof := MarketAI.profile(nat)
	var srcs: Array = prof.get("sources", [])
	var mkt := ClubDNA.mkt(c)
	var n_src: int = int({"domestico": 1, "regional": 3, "continental": 5, "global": 8}.get(mkt, 3))
	for i in mini(n_src, srcs.size()):
		var top := Reputation.top_league_of(String(srcs[i]))
		if top != "" and not out.has(top):
			out.append(top)
	if mkt in ["continental", "global"]:
		var conf := String(DatabaseManager.nation(nat).get("confed", ""))
		var same: Array = []
		for lid in DatabaseManager.league_ids():
			var cfg := DatabaseManager.league_cfg(lid)
			var ln := String(cfg.get("nation", ""))
			if int(cfg.get("tier", 1)) == 1 and String(DatabaseManager.nation(ln).get("confed", "")) == conf and not out.has(lid):
				same.append([LeagueReputation.coef(ln), lid])
		same.sort_custom(func(a, b): return a[0] > b[0])
		for e in same.slice(0, 4 if mkt == "continental" else 3):
			out.append(e[1])
	if mkt == "global" or MarketAI.hunts_jewels(c):
		var world_top: Array = []
		for lid in DatabaseManager.league_ids():
			var cfg := DatabaseManager.league_cfg(lid)
			if int(cfg.get("tier", 1)) == 1 and not out.has(lid):
				world_top.append([LeagueReputation.coef(String(cfg.get("nation", ""))), lid])
		world_top.sort_custom(func(a, b): return a[0] > b[0])
		for e in world_top.slice(0, 6):
			out.append(e[1])
		if MarketAI.hunts_jewels(c):
			for n in ["BRA", "ARG", "URU", "COL"]:
				var top2 := Reputation.top_league_of(n)
				if top2 != "" and not out.has(top2):
					out.append(top2)
	cache[key] = out
	return out


## Fim de semana: os olheiros de cada clube assistem a jogos das ligas que cobrem.
static func weekly(world: GameWorld, entries: Array) -> void:
	var by_league := {}
	for e in entries:
		var f: Fixture = e["f"]
		if not f.played or not (e.get("res", {}) as Dictionary).has("lines"):
			continue
		if not by_league.has(f.comp):
			by_league[f.comp] = []
		by_league[f.comp].append(e)
	if by_league.is_empty():
		return
	var turn := world.current_turn()
	# Nível de quem jogou nesta data, calculado uma vez só (o mesmo jogo é visto por vários clubes).
	var est := {}
	for lid in by_league:
		for e in by_league[lid]:
			for side in 2:
				for ln in e["res"]["lines"][side]:
					var pl: Player = ln[QuickMatch.L_P]
					est[pl.id] = Valuation.perceived_rating(pl, world.year) + Valuation.shift
	for c: Club in world.clubs:
		if c.tier > MAX_TIER or world.is_user_club(c.id) or c.is_pool():
			continue
		# Cada departamento faz o relatório da quinzena: metade dos clubes por semana, com o dobro de jogos vistos.
		if (turn + c.id) % 2 != 0:
			continue
		var cov := covered(world, c)
		var n := scouts(c)
		var q := quality(c)
		var lvl := PlayerGenerator.club_level(c)
		var mem := of(world, c.id)
		for i in n:
			# Rodízio: cada olheiro pega uma liga e um jogo diferentes a cada semana.
			var lid := String(cov[(turn * 7 + i * 13 + c.id) % cov.size()])
			var games: Array = by_league.get(lid, [])
			if games.is_empty():
				continue
			var e: Dictionary = games[(turn + i * 5 + c.id) % games.size()]
			for side in 2:
				for ln in e["res"]["lines"][side]:
					var p: Player = ln[QuickMatch.L_P]
					var r: float = est.get(p.id, 0.0)
					if p.club_id == c.id or r < lvl - 9.0 or r > lvl + 14.0:
						continue
					_observe(mem, p, KNOW_PER_GAME * q * 2.0, turn)
		# A lista é enxugada a cada quatro semanas (cada clube na sua semana).
		if (turn + c.id) % 4 == 0 or (mem["k"] as Dictionary).size() > MAX_KNOWN + 40:
			_prune(world, mem, lvl, turn)


## Vale anotar? Nível perto do que o clube usa, ou garoto com teto para isso.
static func _worth(world: GameWorld, p: Player, lvl: float) -> bool:
	var est := Valuation.perceived_rating(p, world.year) + Valuation.shift
	return est >= lvl - 9.0 and est <= lvl + 14.0


static func _observe(mem: Dictionary, p: Player, gain: float, turn: int) -> void:
	var k: Dictionary = mem["k"]
	k[p.id] = minf(100.0, float(k.get(p.id, 0.0)) + gain)
	mem["t"][p.id] = turn


## Mantém só os mais úteis; quem não é visto há muito tempo vai sendo esquecido.
static func _prune(world: GameWorld, mem: Dictionary, lvl: float, turn: int) -> void:
	var k: Dictionary = mem["k"]
	var t: Dictionary = mem["t"]
	for pid in k.keys():
		var p: Player = world.players.get(pid)
		if p == null or p.retiring:
			k.erase(pid)
			t.erase(pid)
		elif turn - int(t.get(pid, turn)) > STALE_TURNS:
			k[pid] = float(k[pid]) * 0.5
			t[pid] = turn
	if k.size() <= MAX_KNOWN:
		return
	var ids := k.keys()
	ids.sort_custom(func(a, b): return float(k[a]) + world.players[a].ovr_f * 0.3 > float(k[b]) + world.players[b].ovr_f * 0.3)
	for pid in ids.slice(MAX_KNOWN):
		k.erase(pid)
		t.erase(pid)


## Conhecimento do clube sobre o jogador (0..100). Empresários garantem um mínimo para quem está
## à venda ou sem clube no raio de ação do clube.
static func know(world: GameWorld, c: Club, p: Player) -> float:
	var k := float(of(world, c.id)["k"].get(p.id, 0.0))
	if p.club_id == c.id:
		return 100.0
	return k


## Overall que o clube enxerga: o real com um erro fixo por clube e jogador, que encolhe quando o
## clube conhece bem o jogador.
static func estimate(world: GameWorld, c: Club, p: Player, kn: float = -1.0) -> float:
	if kn < 0.0:
		kn = know(world, c, p)
	var h := hash([c.id, p.id, "olho"])
	var err := float(h % 1300) / 100.0 - 6.5 # ±6,5 pontos para quem só ouviu falar
	return Valuation.perceived_rating(p, world.year) + Valuation.shift + err * (1.0 - clampf(kn, 0.0, 100.0) / 100.0)


## Jogadores que o clube conhece bem o bastante para fazer proposta (pid → conhecimento).
static func shortlist(world: GameWorld, c: Club, min_know: float = 30.0) -> Dictionary:
	var out := {}
	var k: Dictionary = of(world, c.id)["k"]
	for pid in k:
		if float(k[pid]) >= min_know:
			out[pid] = float(k[pid])
	return out


## Jogadores de cada liga ordenados pelo nível que o mercado enxerga (cache por data).
static var _league_pool: Dictionary = {}
static var _pool_key := -1


static func _pool(world: GameWorld, lid: String) -> Array:
	var key := hash([world.get_instance_id(), world.year, world.current_turn()])
	if _pool_key != key:
		_league_pool.clear()
		_pool_key = key
		for c: Club in world.clubs:
			if not _league_pool.has(c.league_id):
				_league_pool[c.league_id] = []
			for p: Player in world.squad(c):
				_league_pool[c.league_id].append([Valuation.perceived_rating(p, world.year) + Valuation.shift, p])
		for k in _league_pool:
			_league_pool[k].sort_custom(func(a, b): return a[0] < b[0])
	return _league_pool.get(lid, [])


## Primeiro índice da lista (ordenada pelo nível) com nível >= v.
static func _lower_bound(arr: Array, v: float) -> int:
	var lo := 0
	var hi := arr.size()
	while lo < hi:
		var mid := (lo + hi) >> 1
		if float(arr[mid][0]) < v:
			lo = mid + 1
		else:
			hi = mid
	return lo


## Primeira janela (ou save antigo): o departamento já acompanhava gente das ligas que cobre nas
## temporadas anteriores. Sem sorteio: entra quem está no nível do clube, os mais próximos do que
## ele procura primeiro; o próprio país é mais conhecido que o exterior.
static func ensure_known(world: GameWorld, c: Club) -> void:
	if c.tier > MAX_TIER or world.is_user_club(c.id):
		return
	var mem := of(world, c.id)
	if not (mem["k"] as Dictionary).is_empty():
		return
	var lvl := PlayerGenerator.club_level(c)
	var cov := covered(world, c)
	var q := quality(c)
	var per := maxi(6, MAX_KNOWN / maxi(1, cov.size()))
	var turn := world.current_turn()
	for lid in cov:
		var arr := _pool(world, String(lid))
		if arr.is_empty():
			continue
		var home := String(DatabaseManager.league_cfg(String(lid)).get("nation", "")) == c.nation
		var kv := (55.0 if home else 38.0) * q
		# A lista da liga já vem ordenada pelo nível: parte do nível procurado (lvl + 3) e vai
		# abrindo para os dois lados, sempre pegando o mais próximo, até `per` jogadores dentro da
		# faixa (lvl - 9 a lvl + 14). Mesmo resultado de ordenar a faixa inteira, sem ordenar nada.
		var target := lvl + 3.0
		var hi := _lower_bound(arr, target)
		var lo := hi - 1
		var taken := 0
		while taken < per and (lo >= 0 or hi < arr.size()):
			var use_hi := lo < 0 or (hi < arr.size() and float(arr[hi][0]) - target < target - float(arr[lo][0]))
			var e: Array = arr[hi] if use_hi else arr[lo]
			var est: float = e[0]
			if use_hi:
				hi += 1
				if est > lvl + 14.0:
					hi = arr.size() # passou da faixa por cima
					continue
			else:
				lo -= 1
				if est < lvl - 9.0:
					lo = -1 # passou da faixa por baixo
					continue
			var p: Player = e[1]
			if p.club_id == c.id:
				continue
			mem["k"][p.id] = kv
			mem["t"][p.id] = turn
			taken += 1
