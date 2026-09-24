class_name Attr
extends RefCounted
## Índices e nomes dos 15 atributos (escala 1–100).

const FIN := 0  # finalização
const PAS := 1  # passe
const TEC := 2  # técnica
const VEL := 3  # velocidade
const FOR := 4  # força
const MAR := 5  # marcação
const POS := 6  # posicionamento
const VIS := 7  # visão
const CRU := 8  # cruzamento
const CAB := 9  # cabeceio
const RES := 10 # resistência
const GOL := 11 # goleiro
const DIS := 12 # disciplina
const INT := 13 # inteligência
const DEC := 14 # decisão
const COUNT := 15

const NAMES: Array[String] = [
	"Finalização", "Passe", "Técnica", "Velocidade", "Força", "Marcação", "Posicionamento",
	"Visão", "Cruzamento", "Cabeceio", "Resistência", "Goleiro", "Disciplina", "Inteligência", "Decisão"
]
const SHORT: Array[String] = ["FIN", "PAS", "TEC", "VEL", "FOR", "MAR", "POS", "VIS", "CRU", "CAB", "RES", "GOL", "DIS", "INT", "DEC"]

## Agrupamento para a tela de perfil.
const UI_GROUPS: Array = [
	["Ataque", [FIN, CAB, CRU]],
	["Técnica", [PAS, TEC, VIS]],
	["Físico", [VEL, FOR, RES]],
	["Defesa", [MAR, POS]],
	["Mental", [DEC, INT, DIS]],
]

## Atributos que caem primeiro com a idade (físicos) e os que ainda crescem com experiência.
const PHYSICAL: Array[int] = [VEL, RES, FOR]
const TECHNICAL: Array[int] = [FIN, PAS, TEC, CRU, CAB, MAR, GOL]
const MENTAL: Array[int] = [POS, VIS, INT, DEC, DIS]


static func name_of(a: int) -> String:
	return I18n.t(NAMES[a])
