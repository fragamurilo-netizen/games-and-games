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
## Ordem dos batedores na disputa de pênaltis (ids). Vazia = automática pela habilidade.
var shootout_order: Array = []
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
## Instruções individuais: {player_id: chave de INSTRUCTIONS}.
var instr: Dictionary = {}
## Largura do time: 0 fechado, 1 normal, 2 aberto.
var width: int = 1

## Instruções individuais: ajustes nos pesos de defesa/meio/ataque da vaga, nas faltas e nos chutes.
## "gap": espaço que o jogador deixa (ou fecha) no próprio corredor quando o time perde a bola.
const INSTRUCTIONS := {
	"avancar": {"name": "Apoiar o ataque", "desc": "Sobe mais, aparece na área. Deixa espaço atrás.", "def": -0.12, "mid": 0.0, "att": 0.15, "foul": 1.0, "shoot": 1.1, "gap": 0.45},
	"segurar": {"name": "Segurar a posição", "desc": "Não sai da função defensiva. Ataca menos.", "def": 0.12, "mid": 0.0, "att": -0.12, "foul": 1.0, "shoot": 0.85, "gap": -0.12},
	"chutar": {"name": "Arriscar de longe", "desc": "Finaliza de fora da área sempre que puder.", "def": 0.0, "mid": -0.03, "att": 0.06, "foul": 1.0, "shoot": 1.35},
	"marcar": {"name": "Marcação forte", "desc": "Cola no adversário e não deixa jogar. Faz mais faltas.", "def": 0.08, "mid": 0.0, "att": -0.04, "foul": 1.35, "shoot": 1.0},
	"prender": {"name": "Prender a bola", "desc": "Segura a posse e cadencia o jogo.", "def": 0.0, "mid": 0.12, "att": -0.05, "foul": 1.0, "shoot": 0.9},
}
const INSTRUCTION_ORDER: Array[String] = ["avancar", "segurar", "chutar", "marcar", "prender"]
const WIDTH_NAMES: Array[String] = ["Fechado", "Normal", "Aberto"]


func instruction_of(pid: int) -> Dictionary:
	return INSTRUCTIONS.get(String(instr.get(pid, "")), {})


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
		"so": shootout_order.duplicate(), "pl": plan_losing, "pw": plan_winning, "pm": plan_minute, "ins": instr.duplicate(), "wd": width,
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
	for pid in d.get("so", []):
		t.shootout_order.append(int(pid))
	t.mentality = int(d.get("m", MENT_EQUILIBRADA))
	t.style = int(d.get("st", STYLE_POSSE))
	t.intensity = int(d.get("i", 1))
	t.line = int(d.get("l", 1))
	t.pressing = int(d.get("p", 1))
	t.auto_subs = bool(d.get("as", true))
	t.plan_losing = int(d.get("pl", -1))
	t.plan_winning = int(d.get("pw", -1))
	t.plan_minute = int(d.get("pm", 70))
	var ins: Dictionary = d.get("ins", {})
	for k in ins:
		t.instr[int(k)] = String(ins[k])
	t.width = int(d.get("wd", 1))
	return t
