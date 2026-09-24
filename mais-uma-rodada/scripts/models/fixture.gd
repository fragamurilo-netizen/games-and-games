class_name Fixture
extends RefCounted
## Um jogo do calendário (liga ou copa) e seu resultado resumido.

const GOAL_NORMAL := 0
const GOAL_PENALTY := 1
const GOAL_OWN := 2

var home: int = -1
var away: int = -1
var round: int = 0
var competition: String = "L" # "L" liga, "C" copa
var division: int = 0
var played: bool = false
var hg: int = 0
var ag: int = 0
var goals: Array = [] # [[minuto, lado(0/1), player_id, tipo]]
var attendance: int = 0
var motm: int = -1


func involves(club_id: int) -> bool:
	return home == club_id or away == club_id


func opponent_of(club_id: int) -> int:
	return away if home == club_id else home


func is_home(club_id: int) -> bool:
	return home == club_id


## Resultado do ponto de vista de um clube: "V", "E" ou "D" ("" se não jogado).
func result_for(club_id: int) -> String:
	if not played:
		return ""
	var mine := hg if home == club_id else ag
	var theirs := ag if home == club_id else hg
	if mine > theirs:
		return "V"
	if mine < theirs:
		return "D"
	return "E"


func score_text() -> String:
	return "%d x %d" % [hg, ag] if played else "x"


func to_dict() -> Dictionary:
	return {
		"h": home, "a": away, "r": round, "c": competition, "dv": division, "pl": played,
		"hg": hg, "ag": ag, "g": goals, "att": attendance, "motm": motm,
	}


static func from_dict(d: Dictionary) -> Fixture:
	var f := Fixture.new()
	f.home = int(d.get("h", -1))
	f.away = int(d.get("a", -1))
	f.round = int(d.get("r", 0))
	f.competition = d.get("c", "L")
	f.division = int(d.get("dv", 0))
	f.played = bool(d.get("pl", false))
	f.hg = int(d.get("hg", 0))
	f.ag = int(d.get("ag", 0))
	f.goals = Array(d.get("g", []))
	f.attendance = int(d.get("att", 0))
	f.motm = int(d.get("motm", -1))
	return f
