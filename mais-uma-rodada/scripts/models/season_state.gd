class_name SeasonState
extends RefCounted
## Estado da temporada corrente: ligas, calendário de dias de jogo e progresso.

var year: int = 2026
var leagues: Array = [] # League por divisão (0 = primeira)
## Dias de jogo em ordem: {"t": "L", "r": rodada}. A Copa entra como {"t": "C", ...}.
var calendar: Array = []
var day: int = 0 # próximo dia de jogo a disputar
var finished: bool = false


func total_days() -> int:
	return calendar.size()


func current_entry() -> Dictionary:
	if day < 0 or day >= calendar.size():
		return {}
	return calendar[day]


## Número da próxima rodada da liga (1-based) ou 0 se acabou.
func next_league_round() -> int:
	var e := current_entry()
	if e.is_empty():
		return 0
	return int(e.get("r", 0)) + 1


func league(div: int) -> League:
	return leagues[div]


func to_dict() -> Dictionary:
	var ls: Array = []
	for l in leagues:
		ls.append(l.to_dict())
	return {"year": year, "leagues": ls, "cal": calendar, "day": day, "fin": finished}


static func from_dict(d: Dictionary) -> SeasonState:
	var s := SeasonState.new()
	s.year = int(d.get("year", 2026))
	for ld in d.get("leagues", []):
		s.leagues.append(League.from_dict(ld))
	s.calendar = Array(d.get("cal", []))
	s.day = int(d.get("day", 0))
	s.finished = bool(d.get("fin", false))
	return s
