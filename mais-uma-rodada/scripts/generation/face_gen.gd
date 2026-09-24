class_name FaceGen
extends RefCounted
## Traços do rosto de uma pessoa (jogador, técnico, dirigente), derivados da semente do rosto,
## da etnia e da idade — o mesmo jogador tem sempre o mesmo rosto e envelhece com ele.
## A "genética" (barba, calvície, cabelos brancos, textura do cabelo) é fixa pela semente;
## o que ela produz depende da idade: a barba só nasce depois da puberdade e engrossa com os
## anos, as entradas avançam, o cabelo fica grisalho. O visual (penteado e barba) muda de tempos
## em tempos, mas sempre dentro do que aquela pessoa consegue ter.
## O editor pode fixar qualquer traço pelo dicionário `look` ({hs, hc, bd, sk, ey}).

# ---------------------------------------------------------------------------
# Etnias (mesma ordem de nations.json → "ethnicities")
# ---------------------------------------------------------------------------
const E_NOR := 0
const E_EUR := 1
const E_MED := 2
const E_ARB := 3
const E_LAT := 4
const E_AND := 5
const E_MIX := 6
const E_AFR := 7
const E_EAS := 8
const E_SAS := 9
const E_HAE := 10
const E_PAC := 11
const E_SEA := 12
const ETH_COUNT := 13

# ---------------------------------------------------------------------------
# Penteados (os índices antigos continuam valendo nos saves)
# ---------------------------------------------------------------------------
const HAIR_STYLES: Array[String] = [
	"Raspado", "Curto", "Repartido", "Topete", "Degradê", "Cacheado", "Black power", "Dreads",
	"Longo", "Coque", "Moicano", "Careca", "Penteado para trás", "Tranças nagô", "Arrepiado", "Franja",
	"Undercut", "Militar", "Pompadour", "Ondulado médio", "Repartido ao meio", "Mullet", "Rabo de cavalo", "Twists",
	"High top", "Waves", "Crop texturizado", "Surfista", "Tigela", "Box braids", "Afro curto", "Samurai",
	"Cacheado longo", "Degradê com risco", "Ondulado para trás", "Locs curtos",
]
const H_BUZZ := 0
const H_SHORT := 1
const H_PART := 2
const H_QUIFF := 3
const H_FADE := 4
const H_CURLY := 5
const H_AFRO := 6
const H_DREADS := 7
const H_LONG := 8
const H_BUN := 9
const H_MOHAWK := 10
const H_BALD := 11
const H_SLICK := 12
const H_CORNROWS := 13
const H_SPIKY := 14
const H_FRINGE := 15
const H_UNDERCUT := 16
const H_CREW := 17
const H_POMPADOUR := 18
const H_WAVY := 19
const H_MIDPART := 20
const H_MULLET := 21
const H_PONYTAIL := 22
const H_TWISTS := 23
const H_HIGHTOP := 24
const H_WAVES := 25
const H_CROP := 26
const H_SURFER := 27
const H_BOWL := 28
const H_BRAIDS := 29
const H_SHORT_AFRO := 30
const H_TOPKNOT := 31
const H_LONG_CURLY := 32
const H_FADE_PART := 33
const H_WAVY_BACK := 34
const H_SHORT_LOCS := 35

## Textura natural do cabelo.
const T_STRAIGHT := 0
const T_WAVY := 1
const T_CURLY := 2
const T_COILY := 3

## Popularidade de cada penteado por textura [liso, ondulado, cacheado, crespo].
const STYLE_TEX_W: Array = [
	[1.0, 1.0, 1.2, 2.6], # raspado
	[3.0, 3.0, 1.2, 0.3], # curto
	[2.4, 2.0, 0.4, 0.0], # repartido
	[1.4, 1.4, 0.4, 0.0], # topete
	[2.0, 2.0, 1.6, 3.2], # degradê
	[0.0, 0.3, 3.0, 0.4], # cacheado
	[0.0, 0.0, 0.2, 1.1], # black power
	[0.0, 0.0, 0.2, 1.4], # dreads
	[0.6, 0.8, 0.4, 0.0], # longo
	[0.4, 0.5, 0.5, 0.2], # coque
	[0.2, 0.2, 0.3, 0.5], # moicano
	[0.3, 0.3, 0.4, 1.0], # careca
	[1.2, 1.2, 0.3, 0.0], # para trás
	[0.0, 0.0, 0.0, 1.2], # nagô
	[1.2, 0.5, 0.0, 0.0], # arrepiado
	[1.2, 0.5, 0.1, 0.0], # franja
	[1.3, 1.1, 0.3, 0.0], # undercut
	[2.0, 2.0, 1.0, 0.6], # militar
	[0.6, 0.6, 0.1, 0.0], # pompadour
	[0.0, 2.0, 0.6, 0.0], # ondulado médio
	[1.0, 1.0, 0.2, 0.0], # repartido ao meio
	[0.3, 0.5, 0.4, 0.0], # mullet
	[0.3, 0.4, 0.3, 0.1], # rabo de cavalo
	[0.0, 0.0, 0.2, 1.4], # twists
	[0.0, 0.0, 0.0, 0.5], # high top
	[0.0, 0.0, 0.0, 1.5], # waves
	[2.0, 1.5, 0.4, 0.0], # crop
	[0.4, 1.0, 0.5, 0.0], # surfista
	[0.5, 0.1, 0.0, 0.0], # tigela
	[0.0, 0.0, 0.0, 0.6], # box braids
	[0.0, 0.0, 0.5, 2.4], # afro curto
	[0.4, 0.4, 0.2, 0.0], # samurai
	[0.0, 0.2, 1.2, 0.2], # cacheado longo
	[0.5, 0.5, 0.6, 1.6], # degradê com risco
	[0.4, 1.2, 0.4, 0.0], # ondulado para trás
	[0.0, 0.0, 0.1, 1.4], # locs curtos
]
## Penteados que exigem cabelo (somem com calvície avançada).
const NEEDS_HAIR: Array[int] = [H_QUIFF, H_CURLY, H_AFRO, H_LONG, H_BUN, H_FRINGE, H_POMPADOUR, H_WAVY,
	H_MIDPART, H_MULLET, H_PONYTAIL, H_HIGHTOP, H_SURFER, H_BOWL, H_BRAIDS, H_TOPKNOT, H_LONG_CURLY, H_TWISTS]

# ---------------------------------------------------------------------------
# Barbas
# ---------------------------------------------------------------------------
const BEARDS: Array[String] = [
	"Sem barba", "Por fazer", "Curta", "Cheia", "Cavanhaque", "Bigode", "Contorno", "Bigode e cavanhaque",
	"Rala", "Longa", "Três dias", "Ferradura", "Mosca", "Costeletas", "Âncora", "Barba sem bigode",
	"Bigode fino", "Desenhada", "Balbo", "Cavanhaque longo", "Buço",
]
const B_NONE := 0
const B_STUBBLE := 1
const B_SHORT := 2
const B_FULL := 3
const B_GOATEE := 4
const B_MUSTACHE := 5
const B_CHINSTRAP := 6
const B_VANDYKE := 7
const B_PATCHY := 8
const B_LONG := 9
const B_HEAVY_STUBBLE := 10
const B_HORSESHOE := 11
const B_SOUL := 12
const B_MUTTON := 13
const B_ANCHOR := 14
const B_CURTAIN := 15
const B_PENCIL := 16
const B_BOXED := 17
const B_BALBO := 18
const B_LONG_GOATEE := 19
const B_WISPY := 20

## Partes de cada barba: ch = bochechas (0 = não, senão a altura da linha: 0.1 alta … 0.5 baixa),
## sd = costeletas, jw = contorno da mandíbula, cn = queixo, mu = bigode (1 normal, 2 fino, 3 ferradura),
## so = mosca, nk = pescoço, ln = comprimento além do rosto, op = opacidade, sh = contorno marcado,
## pt = falhas, tx = textura (0 pontos, 1 fios).
const BEARD_PARTS: Array = [
	{},
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.5, "ln": 0.0, "op": 0.3, "sh": 0.0, "pt": 0.15, "tx": 0},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.05, "op": 0.86, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.8, "ln": 0.2, "op": 0.95, "sh": 0.1, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.4, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.5, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.3, "sd": 0.8, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.3, "ln": 0.03, "op": 0.62, "sh": 0.0, "pt": 0.75, "tx": 1},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 1.0, "ln": 0.55, "op": 0.96, "sh": 0.0, "pt": 0.0, "tx": 1},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.6, "ln": 0.0, "op": 0.52, "sh": 0.15, "pt": 0.08, "tx": 0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 3, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.4, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.88, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.28, "sd": 1.0, "jw": 0.8, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.35, "cn": 0.9, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1},
	{"ch": 0.45, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 0, "so": 0.0, "nk": 0.3, "ln": 0.14, "op": 0.93, "sh": 0.2, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 2, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.8, "pt": 0.0, "tx": 1},
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.95, "sh": 1.0, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.3, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.35, "op": 0.92, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.35, "mu": 1, "so": 0.3, "nk": 0.0, "ln": 0.0, "op": 0.34, "sh": 0.0, "pt": 0.5, "tx": 1},
]
## Capacidade de barba mínima para cada estilo (genética × maturidade).
const BEARD_MIN_CAP: Array[float] = [0.0, 0.22, 0.55, 0.72, 0.42, 0.5, 0.55, 0.5, 0.25, 0.82, 0.32, 0.6, 0.3, 0.65, 0.55, 0.62, 0.45, 0.62, 0.55, 0.66, 0.06]
## Popularidade dos estilos entre quem pode tê-los.
const BEARD_POP: Array[float] = [5.0, 3.2, 2.4, 1.3, 0.8, 0.35, 0.45, 0.7, 1.0, 0.25, 2.4, 0.12, 0.25, 0.12, 0.3, 0.2, 0.12, 1.2, 0.3, 0.15, 0.8]

# ---------------------------------------------------------------------------
# Cores
# ---------------------------------------------------------------------------
const HAIR_COLOR_NAMES: Array[String] = [
	"Preto", "Castanho-escuro", "Castanho", "Castanho-claro", "Loiro-escuro", "Loiro", "Ruivo", "Platinado",
	"Acaju", "Loiro-acinzentado", "Preto-azulado", "Pontas descoloridas",
]
const HC_PLATINUM := 7
const HC_TIPS := 11
const HAIR_COLORS: Array[Color] = [
	Color("#161211"), Color("#2E1F16"), Color("#4B3122"), Color("#765033"),
	Color("#A1804F"), Color("#D2B57A"), Color("#93401D"), Color("#E6E0D2"),
	Color("#5B2B1E"), Color("#9A8A6E"), Color("#0D0E15"), Color("#1A1411"),
]
const SKIN_COLORS: Array[Color] = [
	Color("#FBE3D4"), Color("#F3CFB5"), Color("#E9BE9C"), Color("#DBA983"), Color("#C79369"),
	Color("#AF7A51"), Color("#936240"), Color("#774C30"), Color("#5B3923"), Color("#40281A"),
]
const EYE_NAMES: Array[String] = ["Castanho-escuro", "Castanho", "Mel", "Verde", "Azul", "Cinza"]
const EYE_COLORS: Array[Color] = [Color("#2E1C12"), Color("#58381F"), Color("#8A6A36"), Color("#57804D"), Color("#4A7DB4"), Color("#7C8B97")]

# ---------------------------------------------------------------------------
# Fenótipo por etnia
# nor, eur, med, arb, lat, and, mix, afr, eas, sas, hae, pac, sea
# ---------------------------------------------------------------------------
## Faixa de tom de pele (índices contínuos em SKIN_COLORS).
const ETH_SKIN_RANGE: Array = [[0.0, 2.0], [0.4, 3.0], [1.4, 4.0], [2.0, 5.0], [2.0, 6.0], [3.4, 6.4], [3.2, 8.0], [5.8, 9.0], [0.9, 3.3], [3.4, 7.4], [5.4, 8.6], [3.6, 6.4], [2.6, 5.6]]
## Subtom: [rosado, neutro, oliva, dourado].
const ETH_UNDERTONE: Array = [
	[5, 3, 0.3, 0.5], [3, 4, 1, 1], [0.5, 3, 4, 1.5], [0.3, 3, 3, 2], [0.5, 3, 2, 3], [0.2, 2, 1, 4], [0.5, 4, 1, 3],
	[0.5, 5, 0.5, 2], [0.3, 2, 1, 5], [0.2, 3, 2, 3], [0.3, 5, 1, 2], [0.3, 3, 1, 4], [0.2, 2, 2, 5],
]
## Pesos das cores de cabelo (0..11).
const ETH_HAIR_COLOR: Array = [
	[0.3, 1.5, 1.6, 1.3, 1.3, 1.3, 0.4, 0.03, 0.2, 0.9, 0.0, 0.0],
	[0.8, 2.2, 1.7, 0.8, 0.5, 0.3, 0.12, 0.03, 0.25, 0.3, 0.0, 0.01],
	[2.0, 2.2, 1.0, 0.3, 0.1, 0.05, 0.05, 0.03, 0.15, 0.03, 0.1, 0.02],
	[3.0, 1.6, 0.4, 0.1, 0.0, 0.0, 0.03, 0.03, 0.1, 0.0, 0.3, 0.02],
	[2.5, 2.0, 0.6, 0.2, 0.08, 0.04, 0.03, 0.06, 0.12, 0.0, 0.2, 0.08],
	[4.0, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.03, 0.0, 0.0, 0.8, 0.02],
	[3.0, 1.5, 0.4, 0.1, 0.05, 0.0, 0.02, 0.08, 0.05, 0.0, 0.3, 0.2],
	[5.0, 0.8, 0.1, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.3, 0.25],
	[3.0, 1.4, 0.3, 0.05, 0.0, 0.0, 0.0, 0.06, 0.1, 0.0, 1.8, 0.05],
	[3.5, 1.4, 0.2, 0.0, 0.0, 0.0, 0.0, 0.02, 0.1, 0.0, 1.0, 0.02],
	[4.5, 1.2, 0.1, 0.0, 0.0, 0.0, 0.0, 0.05, 0.0, 0.0, 0.3, 0.1],
	[3.5, 1.5, 0.3, 0.05, 0.02, 0.0, 0.02, 0.04, 0.05, 0.0, 0.4, 0.1],
	[3.5, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.0, 1.2, 0.05],
]
const ETH_EYES: Array = [
	[0.5, 1.0, 0.8, 1.0, 2.2, 1.0],
	[1.5, 2.0, 1.0, 0.8, 1.0, 0.5],
	[2.0, 2.0, 0.9, 0.4, 0.3, 0.1],
	[3.0, 2.0, 0.6, 0.25, 0.05, 0.02],
	[3.0, 2.0, 0.5, 0.15, 0.1, 0.02],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[4.0, 2.0, 0.4, 0.12, 0.05, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[4.0, 1.6, 0.4, 0.08, 0.0, 0.0],
	[5.0, 1.0, 0.1, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
]
## Textura do cabelo: [liso, ondulado, cacheado, crespo].
const ETH_TEXTURE: Array = [
	[5, 3, 0.8, 0], [5, 4, 1.4, 0], [3, 4, 2.4, 0.1], [2.5, 4, 3, 0.3], [3, 3.5, 2.5, 0.8], [7, 1.5, 0.3, 0],
	[0.8, 2, 3.5, 3], [0, 0, 0.4, 8], [9, 1, 0.2, 0], [4, 4, 2, 0.2], [0, 0.4, 3, 6], [1, 3, 4, 1.5], [7, 2, 0.8, 0],
]
## Médias por etnia: largura do nariz, altura do dorso do nariz, lábios, abertura dos olhos,
## largura do rosto, maçãs do rosto, arco superciliar.
const ETH_NOSE_W: Array[float] = [0.15, 0.155, 0.16, 0.165, 0.17, 0.18, 0.19, 0.225, 0.17, 0.175, 0.18, 0.21, 0.19]
const ETH_BRIDGE: Array[float] = [0.95, 0.9, 0.95, 1.05, 0.75, 0.85, 0.6, 0.4, 0.35, 0.8, 0.75, 0.5, 0.4]
const ETH_LIPS: Array[float] = [0.9, 1.0, 1.05, 1.05, 1.1, 1.0, 1.25, 1.4, 1.0, 1.1, 1.2, 1.3, 1.15]
const ETH_EYE_OPEN: Array[float] = [1.0, 1.0, 1.0, 1.0, 1.0, 0.9, 1.0, 1.0, 0.7, 1.0, 1.0, 0.9, 0.82]
const ETH_FACE_W: Array[float] = [1.0, 1.0, 0.99, 0.98, 1.01, 1.04, 1.0, 1.0, 1.05, 0.98, 0.95, 1.07, 1.03]
const ETH_CHEEK: Array[float] = [0.9, 0.95, 1.0, 1.0, 1.05, 1.2, 1.05, 1.05, 1.2, 1.0, 1.1, 1.15, 1.15]
const ETH_RIDGE: Array[float] = [1.0, 0.95, 0.95, 1.05, 0.85, 0.8, 0.8, 0.8, 0.35, 0.9, 0.8, 0.9, 0.5]
const ETH_MONOLID: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.02, 0.15, 0.03, 0.0, 0.72, 0.0, 0.0, 0.05, 0.35]
const ETH_AQUILINE: Array[float] = [0.1, 0.12, 0.2, 0.35, 0.08, 0.3, 0.05, 0.02, 0.0, 0.15, 0.18, 0.02, 0.0]
## Genética de barba (média) e de calvície (média).
const ETH_BEARD_GENE: Array[float] = [0.75, 0.8, 0.9, 0.95, 0.7, 0.35, 0.62, 0.55, 0.28, 0.88, 0.45, 0.55, 0.28]
const ETH_BALD_GENE: Array[float] = [0.45, 0.45, 0.45, 0.42, 0.35, 0.25, 0.35, 0.32, 0.25, 0.38, 0.3, 0.3, 0.25]


static func style_group(eth: int) -> int:
	if eth == E_AFR or eth == E_HAE:
		return 1
	if eth == E_EAS or eth == E_SEA:
		return 2
	return 0


## Todos os traços de um rosto. `age` muda barba, cabelos brancos, entradas e rugas.
static func features(seed_value: int, eth: int, age: int, look: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var e := clampi(eth, 0, ETH_COUNT - 1)
	var f := {}
	f["eth"] = e
	f["age"] = age
	var youth := clampf((21.0 - age) / 6.0, 0.0, 1.0) # traços mais suaves no adolescente
	var aging := clampf((age - 28.0) / 20.0, 0.0, 1.0)

	# --- Pele -----------------------------------------------------------------
	var rg: Array = ETH_SKIN_RANGE[e]
	var sk := lerpf(float(rg[0]), float(rg[1]), (rng.randf() + rng.randf()) * 0.5)
	if look.has("sk"):
		sk = float(look["sk"])
	f["skin_i"] = sk
	var under := RngUtil.weighted_index(rng, ETH_UNDERTONE[e])
	f["undertone"] = under
	var skin := skin_at(sk)
	var tint: Color = [Color("#F2B8B0"), skin, Color("#B9A566"), Color("#E8B472")][under]
	skin = skin.lerp(tint, 0.1 if under != 1 else 0.0)
	f["skin"] = skin
	f["rosy"] = rng.randf_range(0.2, 1.0) * (1.0 - clampf(sk / 9.0, 0.0, 0.8)) * (1.3 if under == 0 else 1.0)
	f["blotch_seed"] = rng.randi()

	# --- Formato da cabeça ------------------------------------------------------
	var fwm: float = ETH_FACE_W[e]
	f["fw"] = rng.randf_range(0.2, 0.228) * fwm
	f["fh"] = rng.randf_range(0.28, 0.305)
	f["cheek_w"] = rng.randf_range(0.97, 1.03) # largura nas maçãs (relativa)
	f["jaw"] = rng.randf_range(0.68, 0.9) - youth * 0.04 # largura da mandíbula
	f["jaw_v"] = rng.randf_range(0.45, 0.66) # altura do ângulo da mandíbula
	f["chin_sq"] = rng.randf_range(1.25, 2.0) + (0.35 if rng.randf() < 0.25 else 0.0) # queixo quadrado ↔ fino
	f["chin_cleft"] = rng.randf() < 0.12
	f["forehead"] = rng.randf_range(0.9, 0.98)
	f["fat"] = clampf(rng.randf_range(0.0, 0.6) + youth * 0.2 + aging * 0.15, 0.0, 1.0)
	f["cheekbone"] = rng.randf_range(0.6, 1.2) * float(ETH_CHEEK[e])
	f["ridge"] = rng.randf_range(0.6, 1.2) * float(ETH_RIDGE[e]) * (1.0 - youth * 0.4)
	f["ear"] = rng.randf_range(0.88, 1.12) + aging * 0.06
	f["ear_out"] = rng.randf_range(0.0, 1.0) * (1.0 if rng.randf() < 0.35 else 0.4)
	f["asym"] = rng.randf_range(-1.0, 1.0)

	# --- Olhos ------------------------------------------------------------------
	var eye_i := RngUtil.weighted_index(rng, ETH_EYES[e])
	if look.has("ey"):
		eye_i = clampi(int(look["ey"]), 0, EYE_COLORS.size() - 1)
	f["eye_i"] = eye_i
	f["eye"] = EYE_COLORS[eye_i].lerp(Color.from_hsv(rng.randf(), 0.4, 0.4), rng.randf_range(0.0, 0.15))
	var eye_open: float = ETH_EYE_OPEN[e]
	f["eye_w"] = rng.randf_range(0.21, 0.255)
	f["eye_h"] = rng.randf_range(0.095, 0.125) * eye_open * (1.0 - aging * 0.1)
	f["eye_dx"] = rng.randf_range(0.4, 0.47)
	f["eye_y"] = rng.randf_range(-0.06, 0.02)
	f["eye_tilt"] = rng.randf_range(-0.015, 0.035) + (0.03 if e == E_EAS or e == E_SEA else 0.0)
	f["monolid"] = rng.randf() < float(ETH_MONOLID[e])
	f["hooded"] = rng.randf() < 0.25 + aging * 0.3
	f["deep"] = rng.randf_range(0.5, 1.2) * float(ETH_RIDGE[e]) + 0.2
	f["gaze"] = rng.randf_range(-0.15, 0.15)
	f["lashes"] = rng.randf_range(0.5, 1.0)

	# --- Sobrancelhas -----------------------------------------------------------
	f["brow_t"] = rng.randf_range(0.05, 0.085) * (0.8 if e == E_EAS or e == E_SEA else 1.0)
	f["brow_arch"] = rng.randf_range(0.0, 0.06)
	f["brow_tilt"] = rng.randf_range(-0.03, 0.04)
	f["brow_len"] = rng.randf_range(0.4, 0.5)
	f["brow_gap"] = rng.randf_range(0.17, 0.23)
	f["brow_dens"] = rng.randf_range(0.55, 1.0)
	f["unibrow"] = rng.randf() < 0.04 and e in [E_ARB, E_MED, E_SAS]

	# --- Nariz ------------------------------------------------------------------
	f["nose_w"] = rng.randf_range(0.85, 1.2) * float(ETH_NOSE_W[e]) + aging * 0.01
	f["nose_len"] = rng.randf_range(0.26, 0.35)
	f["bridge"] = clampf(rng.randf_range(0.7, 1.25) * float(ETH_BRIDGE[e]), 0.2, 1.4)
	f["bridge_w"] = rng.randf_range(0.055, 0.085) * (1.3 if float(ETH_BRIDGE[e]) < 0.6 else 1.0)
	f["aquiline"] = rng.randf() < float(ETH_AQUILINE[e])
	f["nose_tip"] = rng.randf_range(0.8, 1.25)

	# --- Boca -------------------------------------------------------------------
	var lips: float = ETH_LIPS[e]
	f["mouth_w"] = rng.randf_range(0.27, 0.36) * (1.0 + (lips - 1.0) * 0.3)
	f["mouth_y"] = rng.randf_range(0.55, 0.61)
	f["lip_u"] = rng.randf_range(0.032, 0.05) * lips * (1.0 - aging * 0.2)
	f["lip_l"] = rng.randf_range(0.05, 0.075) * lips * (1.0 - aging * 0.15)
	f["bow"] = rng.randf_range(0.2, 1.0)
	f["smile"] = rng.randf_range(-0.35, 0.8)

	# --- Cabelo -----------------------------------------------------------------
	var hc_i := RngUtil.weighted_index(rng, ETH_HAIR_COLOR[e])
	if hc_i == HC_TIPS and age > 30:
		hc_i = 0
	if look.has("hc"):
		hc_i = clampi(int(look["hc"]), 0, HAIR_COLORS.size() - 1)
	f["hair_i"] = hc_i
	var tex := RngUtil.weighted_index(rng, ETH_TEXTURE[e])
	f["texture"] = tex
	# Genética de calvície e de cabelos brancos
	var bald_gene := clampf(float(ETH_BALD_GENE[e]) + rng.randf_range(-0.35, 0.45), 0.0, 1.0)
	var rec := clampf((age - 21.0) / 22.0 * bald_gene * 1.5, 0.0, 1.0)
	f["recession"] = rec
	var crown := clampf(maxf(0.0, age - 29.0) / 14.0 * maxf(0.0, bald_gene - 0.55) * 2.6, 0.0, 1.0)
	var gray_start := rng.randf_range(27.0, 45.0)
	var gray := clampf((age - gray_start) / 16.0, 0.0, 0.9)
	f["gray"] = gray
	# Penteado: o "de sempre" e o da fase (muda a cada ~4 anos)
	var sw := _style_weights(e, tex, age)
	var base_style := RngUtil.weighted_index(rng, sw)
	var phase_rng := RandomNumberGenerator.new()
	var phase_off := rng.randi_range(0, 3)
	phase_rng.seed = hash([seed_value, int(floor((age + phase_off) / 4.0))])
	var style := base_style
	if phase_rng.randf() < 0.45:
		style = RngUtil.weighted_index(phase_rng, sw)
	# Calvície avançada: raspa, passa a máquina ou assume a careca
	if (crown > 0.35 or rec > 0.7) and style in NEEDS_HAIR:
		var r := phase_rng.randf()
		style = H_BALD if r < 0.3 else (H_BUZZ if r < 0.65 else H_SHORT)
	if look.has("hs"):
		style = clampi(int(look["hs"]), 0, HAIR_STYLES.size() - 1)
		crown = minf(crown, 0.3)
	if hc_i == HC_PLATINUM and not look.has("hc") and style in [H_LONG, H_SURFER, H_LONG_CURLY, H_MIDPART, H_PONYTAIL, H_BUN]:
		hc_i = 5 if e <= E_EUR else 1
		f["hair_i"] = hc_i
	f["style"] = style
	f["crown"] = crown if style != H_BALD else 0.0
	f["balding"] = crown > 0.25 and style != H_BALD
	f["vol"] = rng.randf_range(0.0, 1.0)
	f["part_side"] = -1.0 if rng.randf() < 0.62 else 1.0
	f["hairline"] = rng.randf_range(-0.6, -0.5) - youth * 0.02
	f["widow"] = rng.randf() < 0.18
	f["lineup"] = tex == T_COILY and rng.randf() < 0.6
	var hair := HAIR_COLORS[hc_i if hc_i != HC_TIPS else 0]
	hair = hair.lerp(Color.from_hsv(rng.randf_range(0.02, 0.1), 0.5, hair.v), rng.randf_range(0.0, 0.12))
	if hc_i != HC_PLATINUM:
		hair = hair.lerp(Color("#C8C5C0"), gray * 0.72)
	f["hair"] = hair
	f["tips"] = hc_i == HC_TIPS
	f["hair_seed"] = rng.randi()

	# --- Barba ------------------------------------------------------------------
	# Genética × maturidade: começa a nascer entre 15 e 21 anos e engrossa por ~7 anos.
	var gene := clampf(float(ETH_BEARD_GENE[e]) + rng.randf_range(-0.3, 0.25), 0.05, 1.0)
	var onset := rng.randf_range(15.5, 21.0)
	var maturity := clampf((age - onset) / 7.0, 0.0, 1.0)
	var cap := gene * maturity
	f["beard_cap"] = cap
	var pref := rng.randf() # < 0.3 gosta de rosto limpo, > 0.75 gosta de barba
	var bw: Array[float] = []
	for i in BEARDS.size():
		var w: float = BEARD_POP[i] if cap >= BEARD_MIN_CAP[i] else 0.0
		if i == B_NONE:
			w *= 1.8 if pref < 0.3 else (0.4 if pref > 0.75 else 1.0)
			w += (1.0 - cap) * 4.0
		elif i in [B_FULL, B_LONG, B_SHORT, B_BOXED, B_HEAVY_STUBBLE]:
			w *= 2.0 if pref > 0.75 else (0.4 if pref < 0.3 else 1.0)
		if i == B_PATCHY:
			w *= 3.0 if cap < 0.6 else 0.3
		if i == B_WISPY:
			w *= 3.0 if cap < 0.35 else 0.1
		if (e == E_EAS or e == E_SEA) and i in [B_FULL, B_LONG, B_MUTTON]:
			w *= 0.3
		if (e == E_ARB or e == E_SAS) and i in [B_FULL, B_SHORT, B_BOXED, B_CURTAIN]:
			w *= 1.8
		if age >= 33 and i in [B_FULL, B_SHORT, B_HEAVY_STUBBLE]:
			w *= 1.4
		bw.append(w)
	var beard := RngUtil.weighted_index(phase_rng, bw)
	if beard < 0:
		beard = B_NONE
	if look.has("bd"):
		beard = clampi(int(look["bd"]), 0, BEARDS.size() - 1)
	f["beard"] = beard
	# Barba rala de verdade quando a genética é fraca
	f["beard_patch"] = clampf(0.75 - cap, 0.0, 0.7)
	f["beard_seed"] = rng.randi()
	# Sombra da barba feita (quem tem barba forte e cabelo escuro)
	var dark_hair := 1.0 - clampf(HAIR_COLORS[hc_i if hc_i != HC_TIPS else 0].v * 1.6, 0.0, 0.8)
	f["shadow"] = cap * dark_hair * rng.randf_range(0.25, 0.7) if beard == B_NONE else cap * dark_hair * 0.35
	var beard_col := HAIR_COLORS[hc_i if hc_i < HC_PLATINUM or hc_i == 8 or hc_i == 9 or hc_i == 10 else (0 if hc_i == HC_TIPS else 1)].darkened(0.06)
	if hc_i == 6 or (hc_i >= 4 and rng.randf() < 0.3):
		beard_col = beard_col.lerp(HAIR_COLORS[6], 0.35) # barba puxando ao ruivo
	f["beard_col"] = beard_col.lerp(Color("#D2CFCA"), clampf(gray * 1.15, 0.0, 0.92))

	# --- Marcas do tempo e detalhes --------------------------------------------
	f["wrinkles"] = clampf((age - 29) / 14.0, 0.0, 1.0)
	f["aging"] = aging
	f["youth"] = youth
	f["freckles"] = (e == E_NOR or e == E_EUR) and sk < 1.8 and rng.randf() < (0.35 if hc_i == 6 else 0.18)
	f["mole"] = rng.randf() < 0.14
	f["mole_pos"] = Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, 0.7))
	f["scar"] = rng.randf() < 0.05
	f["scar_pos"] = Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.3))
	f["earring"] = rng.randf() < 0.08
	f["headband"] = (style in [H_LONG, H_DREADS, H_CURLY, H_AFRO, H_SURFER, H_LONG_CURLY, H_BRAIDS]) and rng.randf() < 0.2
	f["collar"] = rng.randi_range(0, 2)
	f["texture_seed"] = rng.randi()
	return f


## Pesos dos penteados para uma pessoa (etnia + textura + idade).
static func _style_weights(e: int, tex: int, age: int) -> Array:
	var sw: Array = []
	for i in HAIR_STYLES.size():
		var w: float = float((STYLE_TEX_W[i] as Array)[tex])
		sw.append(w)
	if e == E_EAS or e == E_SEA:
		for i in [H_FRINGE, H_SPIKY, H_MIDPART, H_BOWL, H_CROP]:
			sw[i] = float(sw[i]) * 2.0
	if e == E_PAC:
		for i in [H_LONG_CURLY, H_BUN, H_TOPKNOT, H_CURLY]:
			sw[i] = float(sw[i]) * 2.0
	if e == E_ARB or e == E_MED or e == E_SAS:
		for i in [H_SLICK, H_FADE, H_UNDERCUT, H_WAVY_BACK]:
			sw[i] = float(sw[i]) * 1.5
	if age >= 32:
		for i in [H_MOHAWK, H_HIGHTOP, H_BRAIDS, H_TWISTS, H_SPIKY, H_BOWL, H_TOPKNOT, H_MULLET]:
			sw[i] = float(sw[i]) * 0.35
		for i in [H_SHORT, H_PART, H_CREW, H_BUZZ, H_BALD]:
			sw[i] = float(sw[i]) * 1.5
	if age < 24:
		for i in [H_FADE, H_CROP, H_FADE_PART, H_UNDERCUT, H_TWISTS, H_MULLET]:
			sw[i] = float(sw[i]) * 1.4
		sw[H_BALD] = float(sw[H_BALD]) * 0.3
	return sw


static func skin_at(v: float) -> Color:
	var i := clampi(int(floor(v)), 0, SKIN_COLORS.size() - 1)
	var j := mini(i + 1, SKIN_COLORS.size() - 1)
	return SKIN_COLORS[i].lerp(SKIN_COLORS[j], clampf(v - i, 0.0, 1.0))
