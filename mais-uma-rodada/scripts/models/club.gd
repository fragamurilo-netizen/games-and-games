class_name Club
extends RefCounted
## Clube: identidade, torcida, estádio, finanças, estrutura, visual, elenco e memória.

var id: int = 0
## Identificador estável entre mundos e versões (ex.: "BRA_RNC"); procedurais: "POR_P03".
var key: String = ""
var name: String = ""
var short_name: String = ""
var abbr: String = ""
var nickname: String = ""
var city: String = ""
var region: String = ""
var founded: int = 1920
var nation: String = ""
var league_id: String = ""
var tier: int = 1 # divisão dentro da nação (1 = primeira)

var reputation: float = 50.0 # 1..100 (escala mundial)
var fan_base: int = 10000 # torcedores "de estádio" potenciais
var fan_mood: float = 60.0 # 0..100
var board_confidence: float = 60.0 # 0..100
var rivals: Array = [] # ids de clubes rivais (o primeiro é o maior)

var stadium: String = ""
var capacity: int = 10000

var balance: int = 0
var transfer_budget: int = 0
var wage_budget: int = 0 # folha mensal máxima
var ledger: Dictionary = {} # receitas/despesas da temporada por categoria
## Receitas e custos fixos da temporada (definidos com os orçamentos, pagos a cada semana).
var income_tv: int = 0
var income_sponsor: int = 0
var cost_upkeep: int = 0
## Multiplicador do preço do ingresso escolhido pelo clube (1 = preço da liga).
var ticket_mult: float = 1.0
## Treino (só o usuário mexe): {focus, int (0 leve, 1 normal, 2 intensa)}.
var training: Dictionary = {}

var youth_level: int = 50 # 1..100
var facilities: int = 50 # 1..100
var archetype: String = "tradicional_equilibrado"

var color1: String = "#FFFFFF"
var color2: String = "#000000"
var kit_home: Dictionary = {}
var kit_away: Dictionary = {}
var crest: Dictionary = {}

var player_ids: Array = []
var sheet: TeamSheet = null
var cohesion: float = 60.0 # entrosamento 0..100
var last_lineup: Array = []

## Memória: [{y, l (liga), p (posição), pts, w, dr, l, gf, ga}]
var history: Array = []
## Títulos por chave: "L:BRA1" campeão da liga, "P:BRA2" acesso conquistado, "C:UCL" continental, "W:CWC" mundial.
var titles: Dictionary = {}
## Ranking mundial: pontos das últimas temporadas (mais recente no fim) e posição ao fim da anterior.
var rank_hist: Array = []
var rank_prev: int = 0
## Sequências da temporada atual
var streak_unbeaten: int = 0
var streak_wins: int = 0
var streak_winless: int = 0
var streak_losses: int = 0
var results: String = "" # "VEDDV..." resultados recentes (mais recente no fim)

# Controle da IA: quando a formação foi escolhida (salvo para o jogo seguir idêntico após carregar)
var ai_formation_key: int = -1


func arch() -> Dictionary:
	return DatabaseManager.archetype(archetype)


func league_cfg() -> Dictionary:
	return DatabaseManager.league_cfg(league_id)


func primary_color() -> Color:
	return Color(color1)


func secondary_color() -> Color:
	return Color(color2)


func is_rival(other_id: int) -> bool:
	return other_id >= 0 and rivals.has(other_id)


func main_rival() -> int:
	return int(rivals[0]) if not rivals.is_empty() else -1


func squad_size() -> int:
	return player_ids.size()


func add_ledger(category: String, amount: int) -> void:
	ledger[category] = int(ledger.get(category, 0)) + amount
	balance += amount


func recent_form(n: int = 5) -> String:
	return results.substr(max(0, results.length() - n))


func push_result(r: String) -> void:
	results += r
	if results.length() > 10:
		results = results.substr(results.length() - 10)
	match r:
		"V":
			streak_wins += 1
			streak_unbeaten += 1
			streak_winless = 0
			streak_losses = 0
		"E":
			streak_wins = 0
			streak_unbeaten += 1
			streak_winless += 1
			streak_losses = 0
		"D":
			streak_wins = 0
			streak_unbeaten = 0
			streak_winless += 1
			streak_losses += 1


func reset_season_state() -> void:
	ledger = {}
	streak_unbeaten = 0
	streak_wins = 0
	streak_winless = 0
	streak_losses = 0
	results = ""


func title_count(key_: String) -> int:
	return int(titles.get(key_, 0))


func add_title(key_: String) -> void:
	titles[key_] = title_count(key_) + 1


## Total de títulos de um tipo ("L:" ligas, "C:" continentais, "W:" mundiais).
func titles_of_kind(prefix: String) -> int:
	var n := 0
	for k in titles:
		if String(k).begins_with(prefix):
			n += int(titles[k])
	return n


func to_dict() -> Dictionary:
	return {
		"id": id, "key": key, "name": name, "short": short_name, "abbr": abbr, "nick": nickname,
		"city": city, "region": region, "founded": founded, "nat": nation, "lg": league_id, "tier": tier,
		"rep": reputation, "fans": fan_base, "mood": fan_mood, "board": board_confidence,
		"rivals": rivals, "stadium": stadium, "cap": capacity,
		"bal": balance, "tb": transfer_budget, "wb": wage_budget, "ledger": ledger,
		"itv": income_tv, "isp": income_sponsor, "cup": cost_upkeep, "tm": ticket_mult, "trn": training,
		"youth": youth_level, "fac": facilities, "arch": archetype,
		"c1": color1, "c2": color2, "kh": kit_home, "ka": kit_away, "crest": crest,
		"players": player_ids,
		"sheet": sheet.to_dict() if sheet != null else {},
		"coh": cohesion, "ll": last_lineup, "afk": ai_formation_key,
		"hist": history, "titles": titles,
		"su": streak_unbeaten, "sw": streak_wins, "swl": streak_winless, "sl": streak_losses, "res": results,
		"rk": rank_hist, "rkp": rank_prev,
	}


static func from_dict(d: Dictionary) -> Club:
	var c := Club.new()
	c.id = int(d.get("id", 0))
	c.key = d.get("key", "")
	c.name = d.get("name", "")
	c.short_name = d.get("short", c.name)
	c.abbr = d.get("abbr", c.name.substr(0, 3).to_upper())
	c.nickname = d.get("nick", "")
	c.city = d.get("city", "")
	c.region = d.get("region", "")
	c.founded = int(d.get("founded", 1920))
	c.nation = d.get("nat", "")
	c.league_id = d.get("lg", "")
	c.tier = int(d.get("tier", 1))
	c.reputation = float(d.get("rep", 50.0))
	c.fan_base = int(d.get("fans", 10000))
	c.fan_mood = float(d.get("mood", 60.0))
	c.board_confidence = float(d.get("board", 60.0))
	c.rivals = Array(d.get("rivals", []))
	c.stadium = d.get("stadium", "")
	c.capacity = int(d.get("cap", 10000))
	c.balance = int(d.get("bal", 0))
	c.transfer_budget = int(d.get("tb", 0))
	c.wage_budget = int(d.get("wb", 0))
	c.ledger = d.get("ledger", {})
	c.income_tv = int(d.get("itv", 0))
	c.income_sponsor = int(d.get("isp", 0))
	c.cost_upkeep = int(d.get("cup", 0))
	c.ticket_mult = float(d.get("tm", 1.0))
	c.training = d.get("trn", {})
	c.youth_level = int(d.get("youth", 50))
	c.facilities = int(d.get("fac", 50))
	c.archetype = d.get("arch", "tradicional_equilibrado")
	c.color1 = d.get("c1", "#FFFFFF")
	c.color2 = d.get("c2", "#000000")
	c.kit_home = d.get("kh", {})
	c.kit_away = d.get("ka", {})
	c.crest = d.get("crest", {})
	c.ai_formation_key = int(d.get("afk", -1))
	c.player_ids = Array(d.get("players", []))
	var sd: Dictionary = d.get("sheet", {})
	c.sheet = TeamSheet.from_dict(sd) if not sd.is_empty() else null
	c.cohesion = float(d.get("coh", 60.0))
	c.last_lineup = Array(d.get("ll", []))
	c.history = Array(d.get("hist", []))
	c.titles = d.get("titles", {})
	c.streak_unbeaten = int(d.get("su", 0))
	c.streak_wins = int(d.get("sw", 0))
	c.streak_winless = int(d.get("swl", 0))
	c.streak_losses = int(d.get("sl", 0))
	c.results = d.get("res", "")
	c.rank_hist = Array(d.get("rk", []))
	c.rank_prev = int(d.get("rkp", 0))
	return c
