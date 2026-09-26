class_name Fixture
extends RefCounted
## Um jogo do calendário (liga, copa ou amistoso) e seu resultado resumido.

const GOAL_NORMAL := 0
const GOAL_PENALTY := 1
const GOAL_OWN := 2

const STAGE_LEAGUE := 0 # pontos corridos
const STAGE_GROUP := 1 # fase de grupos de copa
const STAGE_KO := 2 # mata-mata

var home: int = -1
var away: int = -1
var round: int = 0 # rodada da liga ou fase/rodada da copa
var comp: String = "" # id da liga ("BRA1") ou da copa ("UCL")
var stage: int = STAGE_LEAGUE
var leg: int = 0 # 0 = jogo único/ida, 1 = volta
var slot: int = -1 # data do calendário
var neutral: bool = false
var played: bool = false
var hg: int = 0
var ag: int = 0
var goals: Array = [] # [[minuto, lado(0/1), player_id, tipo, tempo]]
var attendance: int = 0
var motm: int = -1
var extra_time: bool = false
var pen_h: int = -1 # disputa de pênaltis (-1 = não houve)
var pen_a: int = -1


func involves(club_id: int) -> bool:
	return home == club_id or away == club_id


func opponent_of(club_id: int) -> int:
	return away if home == club_id else home


func is_home(club_id: int) -> bool:
	return home == club_id


func is_league() -> bool:
	return stage == STAGE_LEAGUE


func has_penalties() -> bool:
	return pen_h >= 0 and pen_a >= 0


## Resultado do ponto de vista de um clube: "V", "E" ou "D" ("" se não jogado).
## Nos pênaltis, conta como empate (o avanço é decidido pela copa).
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
	if not played:
		return "x"
	var s := "%d x %d" % [hg, ag]
	if has_penalties():
		s += " (%d-%d pên.)" % [pen_h, pen_a]
	return s


func to_dict() -> Array:
	return [home, away, round, comp, stage, leg, slot, 1 if neutral else 0, 1 if played else 0, hg, ag, goals, attendance, motm,
		1 if extra_time else 0, pen_h, pen_a]


static func from_dict(d: Variant) -> Fixture:
	var f := Fixture.new()
	if d is Array and d.size() >= 17:
		f.home = int(d[0])
		f.away = int(d[1])
		f.round = int(d[2])
		f.comp = String(d[3])
		f.stage = int(d[4])
		f.leg = int(d[5])
		f.slot = int(d[6])
		f.neutral = int(d[7]) == 1
		f.played = int(d[8]) == 1
		f.hg = int(d[9])
		f.ag = int(d[10])
		f.goals = Array(d[11])
		f.attendance = int(d[12])
		f.motm = int(d[13])
		f.extra_time = int(d[14]) == 1
		f.pen_h = int(d[15])
		f.pen_a = int(d[16])
	return f
