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
## Instruções de equipe (índices das listas de mesmo nome em tactics.json; ver TacticsManager.DEEP).
var tempo: int = 1 # 0 cadenciado, 1 normal, 2 acelerado
var passing: int = 1 # 0 curto, 1 misto, 2 direto
var marking: int = 0 # 0 por zona, 1 individual
var transition: int = 1 # na perda da bola: 0 recompor, 1 normal, 2 contrapressão
var focus: int = 1 # 0 esquerda, 1 variado, 2 pelo meio, 3 direita
var time_waste: int = 0 # 0 não, 1 ganhar tempo quando vencer
var corners: int = 0 # 0 variado, 1 primeiro pau, 2 segundo pau, 3 curto

## Instruções individuais: ajustes nos pesos de defesa/meio/ataque da vaga, nas faltas e nos chutes.
## "gap": espaço que o jogador deixa (ou fecha) no próprio corredor quando o time perde a bola.
const INSTRUCTIONS := {
	"avancar": {"name": "Apoiar o ataque", "desc": "Sobe mais, aparece na área. Deixa espaço atrás.", "def": -0.12, "mid": 0.0, "att": 0.15, "foul": 1.0, "shoot": 1.1, "gap": 0.45},
	"segurar": {"name": "Segurar a posição", "desc": "Não sai da função defensiva. Ataca menos.", "def": 0.12, "mid": 0.0, "att": -0.12, "foul": 1.0, "shoot": 0.85, "gap": -0.12},
	"chutar": {"name": "Arriscar de longe", "desc": "Finaliza de fora da área sempre que puder.", "def": 0.0, "mid": -0.03, "att": 0.06, "foul": 1.0, "shoot": 1.35},
	"marcar": {"name": "Marcação forte", "desc": "Cola no adversário e não deixa jogar. Faz mais faltas.", "def": 0.08, "mid": 0.0, "att": -0.04, "foul": 1.35, "shoot": 1.0},
	"prender": {"name": "Prender a bola", "desc": "Segura a posse e cadencia o jogo.", "def": 0.0, "mid": 0.12, "att": -0.05, "foul": 1.0, "shoot": 0.9},
	# Efeitos extras (MatchPlayer.apply_side / MatchTeam): "types" = tipos de jogada do time,
	# "pick" = peso de escolha por modo, "fat" = cansaço, "wide" = largura, "offside" = impedimentos,
	# "mark" = persegue o jogador mais perigoso do rival.
	"frente": {"name": "Ficar na frente", "desc": "Não volta para marcar: espera o contra-ataque lá na frente. Cansa menos, mas o time defende com um a menos.",
		"def": -0.25, "mid": -0.05, "att": 0.08, "foul": 1.0, "shoot": 1.05, "gap": 0.6, "types": {"counter": 0.06}, "fat": 0.85},
	"abrir": {"name": "Jogar aberto", "desc": "Cola na linha lateral: estica a defesa rival e cruza mais. Aparece menos por dentro.",
		"def": 0.0, "mid": -0.05, "att": 0.02, "foul": 1.0, "shoot": 0.9, "wide": 0.35, "types": {"cross": 0.04}, "pick": {6: 1.25}},
	"infiltrar": {"name": "Atacar o espaço", "desc": "Corre nas costas da zaga o tempo todo: mais bolas em profundidade e mais impedimentos. Cansa mais.",
		"def": -0.04, "mid": -0.04, "att": 0.08, "foul": 1.0, "shoot": 1.1, "gap": 0.15, "types": {"through": 0.05}, "offside": 0.12, "pick": {4: 1.2}, "fat": 1.05},
	"recuar": {"name": "Recuar para armar", "desc": "Sai da área para buscar o jogo, como um falso 9: finaliza menos e cria mais.",
		"def": 0.02, "mid": 0.15, "att": -0.1, "foul": 1.0, "shoot": 0.8, "types": {"through": 0.04}, "pick": {5: 1.3}},
	"perseguir": {"name": "Marcar o craque", "desc": "Persegue o jogador mais perigoso do rival. Quanto melhor marcador, mais o craque some. Faz faltas e abre o setor.",
		"def": 0.02, "mid": -0.04, "att": -0.1, "foul": 1.25, "shoot": 0.9, "gap": 0.2, "mark": true, "fat": 1.05},
}
const INSTRUCTION_ORDER: Array[String] = ["avancar", "segurar", "chutar", "marcar", "prender", "frente", "abrir", "infiltrar", "recuar", "perseguir"]
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
		"tp": tempo, "pa": passing, "mk": marking, "tr": transition, "fo": focus, "tw": time_waste, "cr": corners,
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
	# Instruções de equipe (saves antigos: padrão neutro)
	t.tempo = int(d.get("tp", 1))
	t.passing = int(d.get("pa", 1))
	t.marking = int(d.get("mk", 0))
	t.transition = int(d.get("tr", 1))
	t.focus = int(d.get("fo", 1))
	t.time_waste = int(d.get("tw", 0))
	t.corners = int(d.get("cr", 0))
	return t


## Instruções de equipe na ordem de TacticsManager.DEEP.
func deep_values() -> Array:
	return [tempo, passing, marking, transition, focus, time_waste, corners]
