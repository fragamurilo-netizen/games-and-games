class_name Pos
extends RefCounted
## Posições, grupos, pesos de overall e familiaridade entre posições.

const GK := 0
const RB := 1
const CB := 2
const LB := 3
const DM := 4
const CM := 5
const AM := 6
const RM := 7
const LM := 8
const RW := 9
const LW := 10
const ST := 11
const COUNT := 12

const G_GK := 0
const G_DEF := 1
const G_MID := 2
const G_ATT := 3

const CODES: Array[String] = ["GOL", "LD", "ZAG", "LE", "VOL", "MC", "MEI", "MD", "ME", "PD", "PE", "ATA"]
const CODES_I18N: Dictionary = {
	"en": ["GK", "RB", "CB", "LB", "DM", "CM", "AM", "RM", "LM", "RW", "LW", "ST"],
	"es": ["POR", "LD", "DFC", "LI", "MCD", "MC", "MCO", "MD", "MI", "ED", "EI", "DC"],
}
const NAMES: Array[String] = [
	"Goleiro", "Lateral-direito", "Zagueiro", "Lateral-esquerdo", "Volante", "Meio-campista",
	"Meia-armador", "Meia-direita", "Meia-esquerda", "Ponta-direita", "Ponta-esquerda", "Centroavante"
]
const GROUP: Array[int] = [G_GK, G_DEF, G_DEF, G_DEF, G_MID, G_MID, G_MID, G_MID, G_MID, G_ATT, G_ATT, G_ATT]
const GROUP_CODES: Array[String] = ["GOL", "DEF", "MEI", "ATA"]
const GROUP_NAMES: Array[String] = ["Goleiros", "Defensores", "Meio-campistas", "Atacantes"]

## Ordem de exibição do elenco (goleiro → atacante).
const DISPLAY_ORDER: Array[int] = [GK, RB, CB, LB, DM, CM, RM, LM, AM, RW, LW, ST]

## Pesos de cada atributo no overall por posição (cada linha soma 1.0).
## Índices seguem Attr: FIN PAS TEC VEL FOR MAR POS VIS CRU CAB RES GOL DIS INT DEC
const WEIGHTS: Array = [
	[0.00, 0.05, 0.00, 0.05, 0.05, 0.00, 0.12, 0.00, 0.00, 0.00, 0.00, 0.55, 0.00, 0.08, 0.10], # GK
	[0.00, 0.09, 0.08, 0.17, 0.06, 0.17, 0.12, 0.00, 0.13, 0.00, 0.12, 0.00, 0.00, 0.00, 0.06], # RB
	[0.00, 0.05, 0.00, 0.07, 0.14, 0.26, 0.20, 0.00, 0.00, 0.15, 0.00, 0.00, 0.00, 0.05, 0.08], # CB
	[0.00, 0.09, 0.08, 0.17, 0.06, 0.17, 0.12, 0.00, 0.13, 0.00, 0.12, 0.00, 0.00, 0.00, 0.06], # LB
	[0.00, 0.15, 0.00, 0.00, 0.10, 0.21, 0.18, 0.07, 0.00, 0.00, 0.10, 0.00, 0.00, 0.09, 0.10], # DM
	[0.00, 0.22, 0.13, 0.00, 0.00, 0.09, 0.08, 0.14, 0.00, 0.00, 0.12, 0.00, 0.00, 0.10, 0.12], # CM
	[0.13, 0.18, 0.20, 0.08, 0.00, 0.00, 0.00, 0.19, 0.00, 0.00, 0.00, 0.00, 0.00, 0.10, 0.12], # AM
	[0.00, 0.14, 0.15, 0.17, 0.00, 0.07, 0.00, 0.07, 0.18, 0.00, 0.14, 0.00, 0.00, 0.00, 0.08], # RM
	[0.00, 0.14, 0.15, 0.17, 0.00, 0.07, 0.00, 0.07, 0.18, 0.00, 0.14, 0.00, 0.00, 0.00, 0.08], # LM
	[0.15, 0.07, 0.20, 0.22, 0.00, 0.00, 0.00, 0.09, 0.12, 0.00, 0.00, 0.00, 0.00, 0.05, 0.10], # RW
	[0.15, 0.07, 0.20, 0.22, 0.00, 0.00, 0.00, 0.09, 0.12, 0.00, 0.00, 0.00, 0.00, 0.05, 0.10], # LW
	[0.30, 0.00, 0.10, 0.12, 0.08, 0.00, 0.15, 0.00, 0.00, 0.12, 0.00, 0.00, 0.00, 0.05, 0.08], # ST
]

## Posições "vizinhas" e o quanto o jogador rende nelas (sem ser secundária declarada).
const RELATED: Dictionary = {
	GK: {},
	RB: {LB: 0.90, RM: 0.88, CB: 0.85, RW: 0.80},
	CB: {DM: 0.86, RB: 0.84, LB: 0.84},
	LB: {RB: 0.90, LM: 0.88, CB: 0.85, LW: 0.80},
	DM: {CM: 0.92, CB: 0.85},
	CM: {DM: 0.92, AM: 0.90, RM: 0.85, LM: 0.85},
	AM: {CM: 0.90, RW: 0.86, LW: 0.86, ST: 0.85},
	RM: {RW: 0.92, LM: 0.88, RB: 0.85, CM: 0.85},
	LM: {LW: 0.92, RM: 0.88, LB: 0.85, CM: 0.85},
	RW: {RM: 0.92, LW: 0.90, AM: 0.86, ST: 0.85},
	LW: {LM: 0.92, RW: 0.90, AM: 0.86, ST: 0.85},
	ST: {AM: 0.85, RW: 0.85, LW: 0.85},
}

const FAMILIARITY_SECONDARY := 0.96
const FAMILIARITY_UNRELATED := 0.70
const FAMILIARITY_GK_SWAP := 0.25


static func code(p: int) -> String:
	if p < 0 or p >= COUNT:
		return "?"
	return CODES_I18N[I18n.lang][p] if CODES_I18N.has(I18n.lang) else CODES[p]


static func name_of(p: int) -> String:
	return I18n.t(NAMES[p]) if p >= 0 and p < COUNT else "?"


static func group(p: int) -> int:
	return GROUP[p]


static func is_wide(p: int) -> bool:
	return p == RB or p == LB or p == RM or p == LM or p == RW or p == LW


static func is_right(p: int) -> bool:
	return p == RB or p == RM or p == RW


static func is_left(p: int) -> bool:
	return p == LB or p == LM or p == LW


## Quanto um jogador cuja posição principal é `main` (e secundárias `secondary`) rende em `target`.
static func familiarity(main: int, secondary: Array, target: int) -> float:
	if main == target:
		return 1.0
	if (main == GK) != (target == GK):
		return FAMILIARITY_GK_SWAP
	if secondary.has(target):
		return FAMILIARITY_SECONDARY
	var rel: Dictionary = RELATED[main]
	if rel.has(target):
		return rel[target]
	return FAMILIARITY_UNRELATED


## Cor de destaque por grupo (usada em badges de posição).
static func group_color(p: int) -> Color:
	match GROUP[p]:
		G_GK:
			return Color("#F2B134")
		G_DEF:
			return Color("#4EA8DE")
		G_MID:
			return Color("#3DBE7A")
		_:
			return Color("#E5484D")
