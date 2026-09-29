class_name Achievements
extends RefCounted
## Conquistas do treinador: catálogo com categorias e níveis (bronze, prata, ouro, platina),
## verificadas durante o jogo (depois de cada data, nas contratações e vendas, nas copas, nas
## datas FIFA e no fim da temporada). Desbloqueadas uma única vez e guardadas no save em
## world.stats["ach"] (lista de ids) e world.stats["ach_when"] ({id: [ano, rodada]}).
## As recém-desbloqueadas vão para world.pending_achievements e aparecem num aviso no alto da tela.

const TIERS := {
	"bronze": {"name": "Bronze", "color": "#C9824A", "pts": 10},
	"prata": {"name": "Prata", "color": "#B9C3CF", "pts": 25},
	"ouro": {"name": "Ouro", "color": "#FFC940", "pts": 50},
	"platina": {"name": "Platina", "color": "#7FE3F0", "pts": 100},
}
const CATEGORIES: Array = [["carreira", "Carreira"], ["partidas", "Partidas"], ["temporada", "Temporada"],
	["titulos", "Títulos"], ["mercado", "Mercado"], ["elenco", "Elenco"]]

## id -> {name, desc, icon, tier, cat, goal (opcional: meta de um contador), stat (de onde vem o contador)}
const CATALOG := {
	# Carreira
	"primeira": {"name": "Primeira de muitas", "desc": "Completar a primeira temporada", "icon": "whistle", "tier": "bronze", "cat": "carreira"},
	"temporadas5": {"name": "Longevidade", "desc": "Completar 5 temporadas", "icon": "star", "tier": "prata", "cat": "carreira", "goal": 5, "stat": "seasons"},
	"temporadas10": {"name": "Lenda do banco", "desc": "Completar 10 temporadas", "icon": "star", "tier": "ouro", "cat": "carreira", "goal": 10, "stat": "seasons"},
	"jogos100": {"name": "Cem jogos", "desc": "Chegar a 100 jogos como treinador", "icon": "clock", "tier": "bronze", "cat": "carreira", "goal": 100, "stat": "games"},
	"jogos250": {"name": "Veterano da casamata", "desc": "Chegar a 250 jogos como treinador", "icon": "clock", "tier": "prata", "cat": "carreira", "goal": 250, "stat": "games"},
	"jogos500": {"name": "Meio milhar", "desc": "Chegar a 500 jogos como treinador", "icon": "clock", "tier": "ouro", "cat": "carreira", "goal": 500, "stat": "games"},
	"vitorias50": {"name": "Cinquentão", "desc": "Vencer 50 jogos", "icon": "check", "tier": "bronze", "cat": "carreira", "goal": 50, "stat": "wins"},
	"vitorias150": {"name": "Ganhador em série", "desc": "Vencer 150 jogos", "icon": "check", "tier": "prata", "cat": "carreira", "goal": 150, "stat": "wins"},
	"vitorias300": {"name": "Máquina de vencer", "desc": "Vencer 300 jogos", "icon": "check", "tier": "platina", "cat": "carreira", "goal": 300, "stat": "wins"},
	"meta": {"name": "Palavra cumprida", "desc": "Cumprir a meta da diretoria", "icon": "check", "tier": "bronze", "cat": "carreira"},
	"meta3": {"name": "Homem de confiança", "desc": "Cumprir a meta 3 temporadas seguidas", "icon": "shield", "tier": "prata", "cat": "carreira"},
	# Partidas
	"vitoria1": {"name": "Primeira vitória", "desc": "Vencer o primeiro jogo no comando", "icon": "ball", "tier": "bronze", "cat": "partidas"},
	"goleada": {"name": "Chocolate", "desc": "Vencer por 5 ou mais gols de diferença", "icon": "ball", "tier": "bronze", "cat": "partidas"},
	"classico": {"name": "Dono da cidade", "desc": "Vencer um clássico", "icon": "bolt", "tier": "bronze", "cat": "partidas"},
	"zebra": {"name": "Davi contra Golias", "desc": "Vencer um clube muito mais forte que o seu", "icon": "bolt", "tier": "prata", "cat": "partidas"},
	"sequencia5": {"name": "Embalado", "desc": "Vencer 5 jogos seguidos", "icon": "up", "tier": "prata", "cat": "partidas", "goal": 5, "stat": "streak"},
	"sequencia10": {"name": "Imparável", "desc": "Vencer 10 jogos seguidos", "icon": "up", "tier": "ouro", "cat": "partidas", "goal": 10, "stat": "streak"},
	"invicto15": {"name": "Invencível", "desc": "Ficar 15 jogos sem perder", "icon": "shield", "tier": "ouro", "cat": "partidas", "goal": 15, "stat": "unbeaten"},
	"gols100": {"name": "Cem gols", "desc": "Seu time marcar 100 gols sob seu comando", "icon": "ball", "tier": "bronze", "cat": "partidas", "goal": 100, "stat": "gf"},
	"gols500": {"name": "Fábrica de gols", "desc": "Seu time marcar 500 gols sob seu comando", "icon": "ball", "tier": "ouro", "cat": "partidas", "goal": 500, "stat": "gf"},
	# Temporada
	"invicto_casa": {"name": "Alçapão", "desc": "Terminar a liga invicto em casa", "icon": "home", "tier": "prata", "cat": "temporada"},
	"ataque": {"name": "Rolo compressor", "desc": "Marcar 2 gols por jogo na liga", "icon": "ball", "tier": "prata", "cat": "temporada"},
	"defesa": {"name": "Muralha", "desc": "Sofrer menos de 1 gol por jogo na liga", "icon": "shield", "tier": "prata", "cat": "temporada"},
	"artilheiro": {"name": "Tem goleador", "desc": "Ter o artilheiro da liga no elenco", "icon": "star", "tier": "bronze", "cat": "temporada"},
	# Títulos
	"titulo": {"name": "Levantou a taça", "desc": "Conquistar o primeiro título", "icon": "trophy", "tier": "bronze", "cat": "titulos"},
	"acesso": {"name": "Subiu!", "desc": "Conquistar um acesso", "icon": "up", "tier": "bronze", "cat": "titulos"},
	"copa": {"name": "Copa na mão", "desc": "Ganhar uma copa nacional", "icon": "trophy", "tier": "prata", "cat": "titulos"},
	"liga": {"name": "Campeão da elite", "desc": "Ganhar a primeira divisão do país", "icon": "trophy", "tier": "ouro", "cat": "titulos"},
	"continental": {"name": "Rei do continente", "desc": "Ganhar uma copa continental", "icon": "trophy", "tier": "ouro", "cat": "titulos"},
	"mundial": {"name": "Campeão do mundo", "desc": "Ganhar o Mundial de Clubes", "icon": "trophy", "tier": "platina", "cat": "titulos"},
	"titulos5": {"name": "Colecionador", "desc": "Chegar a 5 títulos na carreira", "icon": "trophy", "tier": "prata", "cat": "titulos", "goal": 5, "stat": "titles"},
	"titulos10": {"name": "Galeria cheia", "desc": "Chegar a 10 títulos na carreira", "icon": "trophy", "tier": "platina", "cat": "titulos", "goal": 10, "stat": "titles"},
	# Mercado
	"reforco": {"name": "Primeiro reforço", "desc": "Fazer a primeira contratação", "icon": "swap", "tier": "bronze", "cat": "mercado"},
	"bomba": {"name": "Contratação bombástica", "desc": "Fechar uma contratação de peso (apresentação especial)", "icon": "star", "tier": "prata", "cat": "mercado"},
	"craque": {"name": "Chegou um craque", "desc": "Contratar um jogador de elite", "icon": "star", "tier": "ouro", "cat": "mercado"},
	"joia": {"name": "Garimpeiro", "desc": "Contratar uma grande promessa de até 19 anos", "icon": "search", "tier": "prata", "cat": "mercado"},
	"venda": {"name": "Negócio da China", "desc": "Vender um jogador por 30 milhões ou mais", "icon": "money", "tier": "prata", "cat": "mercado"},
	"venda_recorde": {"name": "Venda do século", "desc": "Vender um jogador por 80 milhões ou mais", "icon": "money", "tier": "ouro", "cat": "mercado"},
	# Elenco
	"cria": {"name": "Cria da casa", "desc": "Um jogador de 21 anos ou menos com 20+ jogos", "icon": "up", "tier": "bronze", "cat": "elenco"},
	"vitrine": {"name": "Vitrine", "desc": "Ter 5 jogadores convocados na mesma data FIFA", "icon": "shield", "tier": "prata", "cat": "elenco"},
}


static func unlocked(world: GameWorld) -> Array:
	return world.stats.get("ach", [])


static func has(world: GameWorld, id: String) -> bool:
	return unlocked(world).has(id)


static func points(world: GameWorld) -> int:
	var total := 0
	for id in unlocked(world):
		if CATALOG.has(id):
			total += int(TIERS[CATALOG[id]["tier"]]["pts"])
	return total


static func max_points() -> int:
	var total := 0
	for id in CATALOG:
		total += int(TIERS[CATALOG[id]["tier"]]["pts"])
	return total


static func tier_color(id: String) -> Color:
	var a: Dictionary = CATALOG.get(id, {})
	return Color(String(TIERS.get(String(a.get("tier", "bronze")), TIERS["bronze"])["color"]))


## Contador atual de uma conquista com meta (para a barra de progresso).
static func progress(world: GameWorld, id: String) -> int:
	var a: Dictionary = CATALOG.get(id, {})
	var ms := world.manager_stats
	match String(a.get("stat", "")):
		"seasons":
			return int(ms.get("seasons", 0))
		"games":
			return int(ms.get("games", 0))
		"wins":
			return int(ms.get("w", 0))
		"titles":
			return int(ms.get("titles", 0))
		"gf":
			return int(world.stats.get("ach_gf", 0))
		"streak":
			return int(world.stats.get("ach_best_streak", 0))
		"unbeaten":
			return int(world.stats.get("ach_best_unbeaten", 0))
	return 0


## Desbloqueia (uma vez). Devolve true se foi agora.
static func unlock(world: GameWorld, id: String) -> bool:
	if not CATALOG.has(id) or not world.has_user():
		return false
	var have: Array = world.stats.get("ach", [])
	if have.has(id):
		return false
	have.append(id)
	world.stats["ach"] = have
	var when: Dictionary = world.stats.get("ach_when", {})
	when[id] = [world.year, world.current_day()]
	world.stats["ach_when"] = when
	world.pending_achievements.append(id)
	# Carregado na hora (sem referência estática) para os testes sem autoloads de UI compilarem
	if DisplayServer.get_name() != "headless":
		load("res://scripts/ui/components/achievement_banner.gd").notify(world)
	return true


## Conquistas de contador (jogos, vitórias, títulos, gols, sequências). Também serve para saves
## antigos: roda ao abrir o hub.
static func check_counters(world: GameWorld) -> void:
	if not world.has_user():
		return
	for id in CATALOG:
		var a: Dictionary = CATALOG[id]
		if a.has("goal") and progress(world, id) >= int(a["goal"]):
			unlock(world, id)


## Depois de cada data: resultado do time do usuário.
static func after_matchday(world: GameWorld, results: Array) -> void:
	if not world.has_user():
		return
	var user := world.user_club()
	for r in results:
		var f: Fixture = r["f"]
		if not f.involves(user.id):
			continue
		var mine := f.hg if f.home == user.id else f.ag
		var theirs := f.ag if f.home == user.id else f.hg
		world.stats["ach_gf"] = int(world.stats.get("ach_gf", 0)) + mine
		var st := int(world.stats.get("ach_streak", 0))
		var unb := int(world.stats.get("ach_unbeaten", 0))
		if mine > theirs:
			st += 1
			unb += 1
			unlock(world, "vitoria1")
			if mine - theirs >= 5:
				unlock(world, "goleada")
			if MatchEngine.is_derby(world, f.home, f.away):
				unlock(world, "classico")
			var opp := world.club(f.opponent_of(user.id))
			if opp != null and opp.reputation >= user.reputation + 12.0:
				unlock(world, "zebra")
		elif mine == theirs:
			st = 0
			unb += 1
		else:
			st = 0
			unb = 0
		world.stats["ach_streak"] = st
		world.stats["ach_unbeaten"] = unb
		world.stats["ach_best_streak"] = maxi(st, int(world.stats.get("ach_best_streak", 0)))
		world.stats["ach_best_unbeaten"] = maxi(unb, int(world.stats.get("ach_best_unbeaten", 0)))
	check_counters(world)


## Contratações e vendas do usuário.
static func on_transfer(world: GameWorld, p: Player, buyer: Club, seller: Club, fee: int, major: bool) -> void:
	if not world.has_user():
		return
	if buyer != null and world.is_user_club(buyer.id):
		unlock(world, "reforco")
		if major:
			unlock(world, "bomba")
		if p.overall >= 85:
			unlock(world, "craque")
		if p.age(world.year) <= 19 and p.potential >= 80:
			unlock(world, "joia")
	if seller != null and world.is_user_club(seller.id):
		if fee >= 30_000_000:
			unlock(world, "venda")
		if fee >= 80_000_000:
			unlock(world, "venda_recorde")


## Título de copa do usuário.
static func on_cup_title(world: GameWorld, cup_id: String) -> void:
	unlock(world, "titulo")
	if cup_id == CupManager.CWC:
		unlock(world, "mundial")
	elif CupManager.is_international(cup_id):
		unlock(world, "continental")
	elif CupManager.is_domestic(cup_id):
		unlock(world, "copa")
