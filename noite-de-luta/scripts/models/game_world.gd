class_name GameWorld
extends RefCounted
## Estado inteiro de uma carreira: lutadores, equipes, eventos, lutas, propostas, notícias e o
## relógio (uma semana por vez, de segunda a segunda; as lutas são no sábado).

const SAVE_VERSION := 1
## Segunda-feira da semana 0.
const START := {"year": 2027, "month": 1, "day": 4}

var seed: int = 0
var week: int = 0
var rng := RandomNumberGenerator.new()
var next_id: int = 1
var fighters: Dictionary = {} # id -> Fighter
var teams: Dictionary = {} # id -> Team
var events: Dictionary = {} # id -> FightEvent
var bouts: Dictionary = {} # id -> Bout
## Propostas e desafios em aberto para os lutadores do jogador:
## {id, fighter, opp, event, week, rounds, title, show, win, expires, kind ("proposta"/"desafio")}
var offers: Array = []
## Notícias: {week, kind, text, fighters [ids], important}
var news: Array = []
## Campeão de cada categoria (id do lutador ou -1 = vago).
var champions: Dictionary = {}
## Ranking de cada categoria: ids do melhor para o pior (refeito toda semana).
var rankings: Dictionary = {}
var user_team_id: int = -1
## Candidatos a staff no mercado: [{id, name, role, quality, age, wage, nation}]
var staff_market: Array = []
## Lutas da semana já resolvidas com o jogador (a semana só fecha depois delas).
var played_this_week: Array = []
## Numeração dos eventos por nome ("LGC" → 41) e semanas do calendário já montadas.
var event_counters: Dictionary = {}
var calendar_weeks: Array = []
## Desafios recusados: "meu_id:alvo_id" → semana em que pode tentar de novo.
var challenge_block: Dictionary = {}
## Contratações recusadas: id do lutador → semana em que ele volta a ouvir propostas.
var sign_block: Dictionary = {}
## Papel do jogador: "empresario" (dono de uma academia, como no LEATHER) ou "presidente" (manda
## na Liga Global: marca as noites, monta os cards, paga as bolsas). Nos dois o jogo é o mesmo
## mundo andando sozinho; o papel é o jeito de participar dele.
var role: String = "empresario"
## Lutadores que o jogador acompanha (como fã): aparecem no Início com a próxima luta e o último
## resultado, em qualquer papel.
var followed: Array = []
## História de cada cinturão: divisão → [{week, id, name, how, event}] (quem ganhou e quando).
var title_history: Dictionary = {}
## Presidente: o matchmaker da organização completa sozinho as vagas que sobrarem nos cards
## duas semanas antes da noite (o jogador cuida das lutas grandes).
var delegate_cards: bool = true
## Presidente: a organização pede este bloqueio quando uma academia recusa uma luta
## ("id_a:id_b" → semana em que dá para tentar de novo).
var bout_block: Dictionary = {}


func new_id() -> int:
	next_id += 1
	return next_id


func fighter(id: int) -> Fighter:
	return fighters.get(id, null)


func team(id: int) -> Team:
	return teams.get(id, null)


func bout(id: int) -> Bout:
	return bouts.get(id, null)


func event(id: int) -> FightEvent:
	return events.get(id, null)


func user_team() -> Team:
	return teams.get(user_team_id, null)


func is_president() -> bool:
	return role == "presidente"


## Nome da Liga Global: no papel de presidente é a organização do jogador.
func league_name() -> String:
	var t := user_team()
	if is_president() and t != null:
		return t.name
	return Rankings.tier_name(2)


func league_short() -> String:
	var t := user_team()
	if is_president() and t != null:
		return t.short
	return String(((DataDB.mma()["promotions"] as Dictionary)["2"] as Dictionary)["short"])


func is_followed(f: Fighter) -> bool:
	return f != null and followed.has(f.id)


func toggle_follow(f: Fighter) -> void:
	if followed.has(f.id):
		followed.erase(f.id)
	else:
		followed.append(f.id)


func is_user_fighter(f: Fighter) -> bool:
	return f != null and f.team_id == user_team_id and user_team_id >= 0


func user_fighters() -> Array:
	var out: Array = []
	for f: Fighter in fighters.values():
		if f.team_id == user_team_id and not f.retired:
			out.append(f)
	out.sort_custom(func(x: Fighter, y: Fighter) -> bool: return x.level() > y.level())
	return out


func team_fighters(team_id: int) -> Array:
	var out: Array = []
	for f: Fighter in fighters.values():
		if f.team_id == team_id and not f.retired:
			out.append(f)
	return out


func in_division(div: String) -> Array:
	var out: Array = []
	for f: Fighter in fighters.values():
		if f.division == div and not f.retired:
			out.append(f)
	return out


## Posição no ranking (1 = primeiro contendor; o campeão fica fora da lista e é 0). -1 = fora.
func rank_of(f: Fighter) -> int:
	if f == null:
		return -1
	if int(champions.get(f.division, -1)) == f.id:
		return 0
	var lst: Array = rankings.get(f.division, [])
	var i := lst.find(f.id)
	return i + 1 if i >= 0 else -1


func rank_text(f: Fighter) -> String:
	var r := rank_of(f)
	if r == 0:
		return "Campeão"
	if r < 0:
		return "Sem ranking"
	return "#%d" % r


# --- Datas -------------------------------------------------------------------------------

static func _unix_of(w: int, day_offset: int) -> int:
	var base := Time.get_unix_time_from_datetime_dict({"year": START.year, "month": START.month, "day": START.day, "hour": 12, "minute": 0, "second": 0})
	return int(base) + (w * 7 + day_offset) * 86400


static func date_of(w: int, day_offset: int = 0) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(_unix_of(w, day_offset))


func year() -> int:
	return int(date_of(week)["year"])


func month() -> int:
	return int(date_of(week)["month"])


## "sáb, 9 jan 2027" (o sábado da semana `w`, dia das lutas).
static func fight_date_text(w: int, with_year: bool = true) -> String:
	var d := date_of(w, 5)
	var t := "sáb, %d %s" % [int(d["day"]), Fmt.MONTHS[int(d["month"]) - 1]]
	return t + (" %d" % int(d["year"]) if with_year else "")


static func week_text(w: int) -> String:
	var d := date_of(w)
	return "%d de %s de %d" % [int(d["day"]), Fmt.MONTHS_FULL[int(d["month"]) - 1], int(d["year"])]


## "em 3 semanas", "nesta semana", "há 2 semanas".
func weeks_from_now(w: int) -> String:
	var n := w - week
	if n == 0:
		return "nesta semana"
	if n == 1:
		return "na próxima semana"
	if n > 1:
		return "em %d semanas" % n
	if n == -1:
		return "semana passada"
	return "há %d semanas" % -n


func age_of(f: Fighter) -> int:
	return f.age(year(), month())


func add_news(kind: String, text: String, ids: Array = [], important: bool = false) -> void:
	news.append({"week": week, "kind": kind, "text": text, "fighters": ids, "important": important})
	if news.size() > 300:
		news = news.slice(news.size() - 300)


# --- Save --------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var fs: Array = []
	for f: Fighter in fighters.values():
		fs.append(f.to_dict())
	var ts: Array = []
	for t: Team in teams.values():
		ts.append(t.to_dict())
	var es: Array = []
	for e: FightEvent in events.values():
		es.append(e.to_dict())
	var bs: Array = []
	for b: Bout in bouts.values():
		bs.append(b.to_dict())
	return {"v": SAVE_VERSION, "seed": seed, "week": week, "rng": str(rng.state), "rng_seed": str(rng.seed), "next_id": next_id,
		"fighters": fs, "teams": ts, "events": es, "bouts": bs, "offers": offers, "news": news,
		"champions": champions, "rankings": rankings, "user_team": user_team_id, "staff_market": staff_market,
		"played": played_this_week, "ev_count": event_counters, "cal": calendar_weeks, "ch_block": challenge_block,
		"sign_block": sign_block, "role": role, "followed": followed, "titles": title_history,
		"delegate": delegate_cards, "bout_block": bout_block}


static func from_dict(d: Dictionary) -> GameWorld:
	var w := GameWorld.new()
	w.seed = int(d.get("seed", 0))
	w.week = int(d.get("week", 0))
	w.rng.seed = int(String(d.get("rng_seed", "0")))
	w.rng.state = int(String(d.get("rng", "0")))
	w.next_id = int(d.get("next_id", 1))
	for fd: Dictionary in d.get("fighters", []):
		var f := Fighter.from_dict(fd)
		w.fighters[f.id] = f
	for td: Dictionary in d.get("teams", []):
		var t := Team.from_dict(td)
		w.teams[t.id] = t
	for ed: Dictionary in d.get("events", []):
		var e := FightEvent.from_dict(ed)
		w.events[e.id] = e
	for bd: Dictionary in d.get("bouts", []):
		var b := Bout.from_dict(bd)
		w.bouts[b.id] = b
	w.offers = d.get("offers", [])
	w.news = d.get("news", [])
	for k in (d.get("champions", {}) as Dictionary):
		w.champions[String(k)] = int(d["champions"][k])
	for k in (d.get("rankings", {}) as Dictionary):
		w.rankings[String(k)] = (d["rankings"][k] as Array).map(func(v): return int(v))
	w.user_team_id = int(d.get("user_team", -1))
	w.staff_market = d.get("staff_market", [])
	w.played_this_week = (d.get("played", []) as Array).map(func(v): return int(v))
	w.event_counters = d.get("ev_count", {})
	w.calendar_weeks = (d.get("cal", []) as Array).map(func(v): return int(v))
	w.challenge_block = d.get("ch_block", {})
	for k in (d.get("sign_block", {}) as Dictionary):
		w.sign_block[int(k)] = int(d["sign_block"][k])
	w.role = String(d.get("role", "empresario"))
	w.followed = (d.get("followed", []) as Array).map(func(v): return int(v))
	w.title_history = d.get("titles", {})
	w.delegate_cards = bool(d.get("delegate", true))
	w.bout_block = d.get("bout_block", {})
	return w
