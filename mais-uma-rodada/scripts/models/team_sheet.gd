class_name TeamSheet
extends RefCounted
## Escalação + tática de um jogo: formação, 11 titulares (na ordem das vagas), banco,
## capitão, batedores e instruções.

const MENT_RETRANCA := 0
const MENT_DEFENSIVA := 1
const MENT_EQUILIBRADA := 2
const MENT_OFENSIVA := 3
const MENT_TUDO := 4

const STYLE_POSSE := 0
const STYLE_DIRETO := 1
const STYLE_CONTRA := 2
const STYLE_PRESSAO := 3
const STYLE_LADOS := 4
const STYLE_LONGA := 5

var formation: String = "4-4-2"
var starters: Array = [] # 11 ids, índice = vaga da formação
var bench: Array = []
var captain: int = -1
var penalty_taker: int = -1
var freekick_taker: int = -1
var corner_taker: int = -1
var mentality: int = MENT_EQUILIBRADA
var style: int = STYLE_POSSE
var intensity: int = 1
var line: int = 1
var pressing: int = 1
var auto_subs: bool = true
## Plano de jogo automático (-1 = não mexer): mentalidade se estiver perdendo / vencendo
## a partir de plan_minute. Empatando, volta para a mentalidade escolhida no pré-jogo.
var plan_losing: int = -1
var plan_winning: int = -1
var plan_minute: int = 70


func duplicate_sheet() -> TeamSheet:
	return TeamSheet.from_dict(to_dict())


func slot_of(player_id: int) -> int:
	return starters.find(player_id)


func contains(player_id: int) -> bool:
	return starters.has(player_id) or bench.has(player_id)


func to_dict() -> Dictionary:
	return {
		"f": formation, "s": starters.duplicate(), "b": bench.duplicate(),
		"cap": captain, "pen": penalty_taker, "fk": freekick_taker, "ck": corner_taker,
		"m": mentality, "st": style, "i": intensity, "l": line, "p": pressing, "as": auto_subs,
		"pl": plan_losing, "pw": plan_winning, "pm": plan_minute,
	}


static func from_dict(d: Dictionary) -> TeamSheet:
	var t := TeamSheet.new()
	t.formation = d.get("f", "4-4-2")
	t.starters = Array(d.get("s", [])).duplicate()
	t.bench = Array(d.get("b", [])).duplicate()
	t.captain = int(d.get("cap", -1))
	t.penalty_taker = int(d.get("pen", -1))
	t.freekick_taker = int(d.get("fk", -1))
	t.corner_taker = int(d.get("ck", -1))
	t.mentality = int(d.get("m", MENT_EQUILIBRADA))
	t.style = int(d.get("st", STYLE_POSSE))
	t.intensity = int(d.get("i", 1))
	t.line = int(d.get("l", 1))
	t.pressing = int(d.get("p", 1))
	t.auto_subs = bool(d.get("as", true))
	t.plan_losing = int(d.get("pl", -1))
	t.plan_winning = int(d.get("pw", -1))
	t.plan_minute = int(d.get("pm", 70))
	return t
