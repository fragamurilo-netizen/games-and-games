class_name GameWorld
extends RefCounted
## Raiz de todo o estado de uma carreira. É exatamente isto que vai para o save.

const SAVE_VERSION := 2
const DIFF_EASY := 0
const DIFF_NORMAL := 1
const DIFF_HARD := 2
const DIFF_NAMES: Array[String] = ["Fácil", "Normal", "Difícil"]
const MAX_NEWS := 160

var version: int = SAVE_VERSION
var world_seed: int = 0
var world_type: String = "padrao" # "padrao" | "aleatorio"
var rng := RandomNumberGenerator.new()
var year: int = 2026
var season_number: int = 1
var clubs: Array = [] # Club, índice == id
var players: Dictionary = {} # id -> Player (em clubes e livres)
var next_player_id: int = 1
var next_offer_id: int = 1
var user_club_id: int = -1
var manager_name: String = "Treinador"
var difficulty: int = DIFF_NORMAL
var season: SeasonState = null
## Memória do mundo: campeões, acessos, artilheiros, etc. por temporada.
var history: Array = []
var news: Array = [] # NewsEvent (mais recente no fim)
var offers: Array = [] # TransferOffer envolvendo o usuário
var transfer_log: Array = [] # Transfer da temporada atual e anterior
var retired: Array = [] # registros compactos de aposentados notáveis
var manager_stats: Dictionary = {"games": 0, "w": 0, "d": 0, "l": 0, "titles": 0, "promotions": 0, "seasons": 0}
## Decisões pendentes do usuário (EventManager) e promessas feitas aos jogadores.
var events: Array = []
var promises: Array = []
## Categorias de base do usuário (id → Player; fora de `players`) e a liga sub-20 da temporada.
var academy: Dictionary = {}
var youth_league: Dictionary = {}
## Estatísticas agregadas usadas pelo relatório de balanceamento.
var stats: Dictionary = {}
## Técnicos, presidentes, comissão, torcida, imprensa e relações (People).
var people: Dictionary = {}

# Índices em memória (não salvos): reconstruídos sob demanda.
var _free_agents_cache: Array = []
var _free_agents_dirty: bool = true
var _club_by_key: Dictionary = {}
var _recovering: Dictionary = {} # jogadores com condição abaixo de 100 (recuperação entre datas)
var _recovering_built: bool = false
var _suspended: Dictionary = {} # jogadores cumprindo suspensão
var _suspended_built: bool = false


# ---------------------------------------------------------------------------
# Acesso
# ---------------------------------------------------------------------------

func club(id: int) -> Club:
	if id < 0 or id >= clubs.size():
		return null
	return clubs[id]


func player(id: int) -> Player:
	var p: Player = players.get(id, null)
	if p == null:
		p = academy.get(id, null)
	return p


func user_club() -> Club:
	return club(user_club_id)


func has_user() -> bool:
	return user_club_id >= 0


func is_user_club(id: int) -> bool:
	return id >= 0 and id == user_club_id


func squad(c: Club) -> Array:
	var out: Array = []
	for pid in c.player_ids:
		var p: Player = players.get(pid, null)
		if p != null:
			out.append(p)
	return out


func squad_of(club_id: int) -> Array:
	var c := club(club_id)
	return squad(c) if c != null else []


func free_agents() -> Array:
	if _free_agents_dirty:
		_free_agents_cache.clear()
		for p in players.values():
			if p.club_id < 0:
				_free_agents_cache.append(p)
		_free_agents_dirty = false
	return _free_agents_cache


func mark_free_agents_dirty() -> void:
	_free_agents_dirty = true


## Jogadores que ainda estão se recuperando fisicamente (índice em memória, refeito ao carregar).
func recovering() -> Dictionary:
	if not _recovering_built:
		_recovering.clear()
		for p: Player in players.values():
			if p.condition < 100.0:
				_recovering[p.id] = true
		_recovering_built = true
	return _recovering


func mark_tired(p: Player) -> void:
	if p.condition < 100.0:
		recovering()[p.id] = true


## Jogadores suspensos (índice em memória, refeito ao carregar).
func suspended() -> Dictionary:
	if not _suspended_built:
		_suspended.clear()
		for p: Player in players.values():
			if p.suspension > 0:
				_suspended[p.id] = true
		_suspended_built = true
	return _suspended


func mark_suspended(p: Player) -> void:
	if p.suspension > 0:
		suspended()[p.id] = true


## Índices em memória precisam ser refeitos (virada de temporada).
func reset_indexes() -> void:
	_recovering_built = false
	_suspended_built = false
	_free_agents_dirty = true


func club_by_key(key: String) -> Club:
	if _club_by_key.size() != clubs.size():
		_club_by_key.clear()
		for c in clubs:
			_club_by_key[c.key] = c
	return _club_by_key.get(key, null)


func league_of(club_id: int) -> League:
	var c := club(club_id)
	if c == null or season == null:
		return null
	return season.leagues.get(c.league_id, null)


func league(id: String) -> League:
	return season.leagues.get(id, null) if season != null else null


func league_name(id: String) -> String:
	return DatabaseManager.league_cfg(id).get("name", id)


func league_short(id: String) -> String:
	return DatabaseManager.league_cfg(id).get("short", id)


func user_league_id() -> String:
	var u := user_club()
	return u.league_id if u != null else ""


func user_nation() -> String:
	var u := user_club()
	return u.nation if u != null else ""


## Clubes de uma liga (pelo estado atual dos clubes, não pela temporada).
func clubs_in_league(id: String) -> Array:
	var out: Array = []
	for c in clubs:
		if c.league_id == id:
			out.append(c)
	return out


func clubs_of_nation(code: String) -> Array:
	var out: Array = []
	for c in clubs:
		if c.nation == code:
			out.append(c)
	return out


func new_player_id() -> int:
	var id := next_player_id
	next_player_id += 1
	return id


func add_player(p: Player) -> void:
	players[p.id] = p
	if p.club_id < 0:
		_free_agents_dirty = true


func remove_player(p: Player) -> void:
	if p.club_id >= 0:
		var c := club(p.club_id)
		if c != null:
			c.player_ids.erase(p.id)
	players.erase(p.id)
	_free_agents_dirty = true


func add_news(n: NewsEvent) -> void:
	news.append(n)
	if news.size() > MAX_NEWS:
		news = news.slice(news.size() - MAX_NEWS)


func unread_news_count() -> int:
	var n := 0
	for item in news:
		if not item.read:
			n += 1
	return n


func current_day() -> int:
	return season.day if season != null else 0


## Jogos do usuário já disputados na temporada (prazos de propostas e negociações).
func current_turn() -> int:
	return season.turn if season != null else 0


func transfer_window_open() -> bool:
	if season == null:
		return false
	return window_open_at(season.day)


func window_open_at(slot: int) -> bool:
	for w in DatabaseManager.calendar_cfg()["windows"]:
		if slot >= int(w[0]) and slot <= int(w[1]):
			return true
	return false


## Próxima data em que a janela abre (ou -1 se não abre mais nesta temporada).
func next_window_day() -> int:
	if season == null:
		return -1
	for w in DatabaseManager.calendar_cfg()["windows"]:
		if int(w[0]) > season.day:
			return int(w[0])
	return -1


## Última data da janela aberta atual (ou -1).
func window_end_day() -> int:
	if season == null:
		return -1
	for w in DatabaseManager.calendar_cfg()["windows"]:
		if season.day >= int(w[0]) and season.day <= int(w[1]):
			return int(w[1])
	return -1


func stat_add(key: String, amount: float = 1.0) -> void:
	stats[key] = float(stats.get(key, 0.0)) + amount


# ---------------------------------------------------------------------------
# Serialização
# ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var cl: Array = []
	for c in clubs:
		cl.append(c.to_dict())
	var pl: Array = []
	for p in players.values():
		pl.append(p.to_dict())
	var nw: Array = []
	for n in news:
		nw.append(n.to_dict())
	var of: Array = []
	for o in offers:
		of.append(o.to_dict())
	var tl: Array = []
	for t in transfer_log:
		tl.append(t.to_dict())
	return {
		"version": SAVE_VERSION,
		"seed": world_seed, "wtype": world_type, "rng_state": rng.state, "rng_seed": rng.seed,
		"year": year, "sn": season_number,
		"clubs": cl, "players": pl, "npid": next_player_id, "noid": next_offer_id,
		"user": user_club_id, "manager": manager_name, "diff": difficulty,
		"season": season.to_dict() if season != null else {},
		"history": history, "news": nw, "offers": of, "tlog": tl, "retired": retired,
		"mstats": manager_stats, "stats": stats, "events": events, "promises": promises,
		"academy": academy.values().map(func(p: Player): return p.to_dict()), "yl": youth_league,
		"people": people,
	}


static func from_dict(d: Dictionary) -> GameWorld:
	var w := GameWorld.new()
	w.version = int(d.get("version", SAVE_VERSION))
	w.world_seed = int(d.get("seed", 0))
	w.world_type = d.get("wtype", "padrao")
	w.rng.seed = int(d.get("rng_seed", w.world_seed))
	w.rng.state = int(d.get("rng_state", 0))
	w.year = int(d.get("year", 2026))
	w.season_number = int(d.get("sn", 1))
	for cd in d.get("clubs", []):
		w.clubs.append(Club.from_dict(cd))
	for pd in d.get("players", []):
		var p := Player.from_dict(pd)
		w.players[p.id] = p
	w.next_player_id = int(d.get("npid", 1))
	w.next_offer_id = int(d.get("noid", 1))
	w.user_club_id = int(d.get("user", -1))
	w.manager_name = d.get("manager", "Treinador")
	w.difficulty = int(d.get("diff", DIFF_NORMAL))
	var sd: Dictionary = d.get("season", {})
	w.season = SeasonState.from_dict(sd) if not sd.is_empty() else null
	w.history = Array(d.get("history", []))
	for nd in d.get("news", []):
		w.news.append(NewsEvent.from_dict(nd))
	for od in d.get("offers", []):
		w.offers.append(TransferOffer.from_dict(od))
	for td in d.get("tlog", []):
		w.transfer_log.append(Transfer.from_dict(td))
	w.retired = Array(d.get("retired", []))
	var ms: Dictionary = d.get("mstats", {})
	for k in ms:
		w.manager_stats[k] = ms[k]
	w.stats = d.get("stats", {})
	w.events = Array(d.get("events", []))
	w.promises = Array(d.get("promises", []))
	for pd in d.get("academy", []):
		var ap := Player.from_dict(pd)
		w.academy[ap.id] = ap
	w.youth_league = d.get("yl", {})
	w.people = d.get("people", {})
	w._free_agents_dirty = true
	w._club_by_key.clear()
	return w
