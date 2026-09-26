class_name Attr
extends RefCounted
## Índices e nomes dos 21 atributos (escala 1–100). Os 15 primeiros são os originais; os 6
## últimos (drible, desarme, chute de longe, aceleração, reflexos e frieza) chegaram depois e,
## nos saves antigos, são derivados dos demais (migrate).

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
const DRI := 15 # drible
const DES := 16 # desarme
const CHL := 17 # chute de longe
const ACE := 18 # aceleração
const REF := 19 # reflexos (goleiro)
const FRI := 20 # frieza (decidir sob pressão: cara a cara, pênalti, jogo grande)
const COUNT := 21
const OLD_COUNT := 15

const NAMES: Array[String] = [
	"Finalização", "Passe", "Técnica", "Velocidade", "Força", "Marcação", "Posicionamento",
	"Visão", "Cruzamento", "Cabeceio", "Resistência", "Goleiro", "Disciplina", "Inteligência", "Decisão",
	"Drible", "Desarme", "Chute de longe", "Aceleração", "Reflexos", "Frieza"
]
const SHORT: Array[String] = ["FIN", "PAS", "TEC", "VEL", "FOR", "MAR", "POS", "VIS", "CRU", "CAB", "RES", "GOL", "DIS", "INT", "DEC",
	"DRI", "DES", "CHL", "ACE", "REF", "FRI"]

## Agrupamento para a tela de perfil.
const UI_GROUPS: Array = [
	["Ataque", [FIN, CHL, CAB, CRU]],
	["Técnica", [PAS, TEC, DRI, VIS]],
	["Físico", [VEL, ACE, FOR, RES]],
	["Defesa", [MAR, DES, POS]],
	["Mental", [DEC, FRI, INT, DIS]],
	["Goleiro", [GOL, REF]],
]

## Atributos que caem primeiro com a idade (físicos) e os que ainda crescem com experiência.
const PHYSICAL: Array[int] = [VEL, RES, FOR, ACE]
const TECHNICAL: Array[int] = [FIN, PAS, TEC, CRU, CAB, MAR, GOL, DRI, DES, CHL, REF]
const MENTAL: Array[int] = [POS, VIS, INT, DEC, DIS, FRI]


## Atributos de um save antigo (15) → os 21 atuais: os novos saem dos parentes mais próximos,
## com um pequeno desvio estável por jogador para ninguém ficar "clonado".
static func migrate(old: PackedByteArray, pid: int, is_gk: bool) -> PackedByteArray:
	var a := old.duplicate()
	a.resize(COUNT)
	var n := func(k: int) -> float: return RngUtil.noise(pid, 700 + k) * 5.0
	var v := func(x: float) -> int: return clampi(int(round(x)), 1, 99)
	a[DRI] = v.call(old[TEC] * 0.6 + old[VEL] * 0.25 + old[DEC] * 0.15 + n.call(0))
	a[DES] = v.call(old[MAR] * 0.7 + old[FOR] * 0.15 + old[POS] * 0.15 + n.call(1))
	a[CHL] = v.call(old[FIN] * 0.55 + old[TEC] * 0.3 + old[FOR] * 0.15 + n.call(2))
	a[ACE] = v.call(old[VEL] * 0.9 + old[TEC] * 0.1 + n.call(3))
	a[REF] = v.call(old[GOL] * 0.85 + old[VEL] * 0.15 + n.call(4)) if is_gk else v.call(minf(25.0, old[GOL] + 3.0 + n.call(4)))
	a[FRI] = v.call(old[DEC] * 0.5 + old[INT] * 0.3 + old[FIN] * 0.2 + n.call(5))
	return a


static func name_of(a: int) -> String:
	return I18n.t(NAMES[a])
