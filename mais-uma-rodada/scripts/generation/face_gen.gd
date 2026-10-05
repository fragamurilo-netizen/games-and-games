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
	"Cacheado longo", "Degradê com risco", "Ondulado para trás", "Locs curtos", "Burst fade", "Afro com degradê",
	"Flow para trás", "Topete bagunçado", "Máquina com desenho", "Nagô com degradê", "Moicano cacheado", "Liso médio",
	"Franja lateral", "Freeform", "Degradê social", "Cacheado com degradê", "Taper cacheado", "Buzz com degradê",
	"Coque com undercut", "Meio preso", "Mullet com degradê", "Corte Edgar", "Faux hawk", "Nevou (descolorido)",
	"Dreads com degradê", "Franja cacheada", "Para trás com degradê", "Tranças com coque", "Topete com risco",
	"Longo para trás", "Ondulado com franja", "Espetado com gel", "Cachos médios", "Moicano trançado", "Sidecut",
	"Dreads presos", "Moicano de dreads", "Blowout", "Franja texturizada", "Twist out", "Afro puff",
	"Nagô em zigue-zague", "Tranças longas com degradê", "Pompadour com risco", "Longo ondulado",
	"Espetado descolorido", "Máquina com risco", "Esponja", "Coque baixo", "Topete desfiado", "Franja longa de lado",
	"Franja cortina", "Máquina 2", "Degradê navalhado", "Topete alto", "Topete cacheado", "Social com franjinha", "Ivy League", "Molhado para trás", "Burst cacheado", "Black power alto", "Afro com risco", "Twists longos", "Dreads em rabo", "Nagô com rabo", "Coque alto com degradê", "Longo com franja", "Chanel", "Mullet cacheado", "Moicano espetado", "Descolorido com desenho", "Ondulado bagunçado", "Repartido volumoso", "Corte César", "Topete com burst", "Undercut com coque baixo", "Cacheado longo com franja", "Freeform com degradê", "Waves com degradê", "Cachos com luzes", "Dois puffs",
	# 113+
	"Curto texturizado", "Degradê com topete baixo", "Social curto", "Repartido baixo", "Franja curta reta", "Topete com volume", "Cacheado curto", "Cachos com degradê navalhado", "Crespo curto", "Crespo com degradê alto", "Waves com risco", "Twists curtos", "Locs médios", "Ondulado curto", "Ondulado repartido", "Liso médio de lado", "Para trás curto", "Degradê baixo", "Degradê médio", "Máquina 3", "Raspado rente", "Topete bagunçado curto", "Franja desfiada", "Médio desarrumado", "Cacheado volumoso", "Afro médio", "Afro com degradê baixo", "Nagô reto com degradê", "Coque baixo com degradê", "Longo solto repartido", "Médio ondulado para trás", "Topete ondulado", "Crop cacheado", "Social com risco", "Buzz com risco lateral", "Curto com franja lateral", "Espetado curto", "Médio com franja cortina", "Cachos soltos médios", "Esponja com degradê",
	"Topete penteado navalhado", "Social natural", "Crespo baixo com degradê", "Buzz navalhado", "Liso para trás rente", "Moicano desfiado", "Twists caídos com degradê", "Franja bagunçada com degradê", "French crop navalhado", "Franja cacheada navalhada", "Máquina 1 com contorno", "Texturizado de lado com degradê", "Black power redondo", "Afro alto navalhado", "High top navalhado", "Twists médios", "Nagô em zigue-zague com degradê", "Esponja alta", "Locs com degradê navalhado", "Afro puff com degradê", "Waves 360", "Crespo médio com risco", "Frohawk", "Cachos definidos com degradê", "Crespo médio natural",
	# 178+
	"High top cacheado com pontas descoloridas", "Longo liso molhado para trás", "Franja reta curta", "Moicano com pontas descoloridas",
	# 182+
	"Meia-lua na franja", "Topete descolorido com laterais escuras", "Cachinhos descoloridos no alto", "Crespo descolorido no alto", "Tranças nagô descoloridas", "Twists com pontas descoloridas", "Twists tingidos de vermelho", "Topete alto arrepiado com degradê", "Espetado com luzes", "Moicano descolorido", "Moicano com desenhos laterais", "Crista alta", "Afro gigante loiro", "Black power gigante", "Cachos armados gigantes", "Dreads longos volumosos", "Dreads com faixa", "Longo com faixa", "Cacheado longo com faixa", "Preso para trás com mechas soltas", "Rabinho trançado na nuca", "Moicano tingido de azul", "Listra tingida de vermelho no meio", "Undercut para trás com risco", "Esponja descolorida", "Tufinhos trançados tingidos de verde", "Black power com costeletas longas", "Para trás volumoso até a nuca", "Longo ondulado atrás das orelhas",
	# 211+ (entram por sorteio à parte, ver _newer_style)
	"Ondulado com degradê", "Cacheado médio com franja", "Repartido navalhado", "Twists curtos com degradê baixo",
	"Médio penteado de lado", "Cacheado com laterais curtas", "Social com gel", "Curto repartido ao meio",
	"Crespo médio com degradê baixo", "Topete curto natural", "Coque samurai cacheado", "Nagô com risco lateral",
	"Ondulado preso em coque baixo", "Para trás desarrumado com degradê",
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
const H_BURST := 36
const H_TAPER_AFRO := 37
const H_FLOW := 38
const H_MESSY := 39
const H_BUZZ_DESIGN := 40
const H_FADE_ROWS := 41
const H_CURLY_MOHAWK := 42
const H_TWO_BLOCK := 43
const H_SIDE_FRINGE := 44
const H_FREEFORM := 45
const H_TAPER := 46
const H_CURLY_FADE := 47
const H_CURLY_TAPER := 48
const H_BUZZ_FADE := 49
const H_BUN_UNDERCUT := 50
const H_HALF_UP := 51
const H_FADE_MULLET := 52
const H_EDGAR := 53
const H_FAUX_HAWK := 54
const H_BLEACHED := 55
const H_LOCS_FADE := 56
const H_CURLY_FRINGE := 57
const H_SLICK_FADE := 58
const H_BRAID_BUN := 59
const H_QUIFF_PART := 60
const H_LONG_BACK := 61
const H_WAVY_FRINGE := 62
const H_GEL_SPIKES := 63
const H_MED_CURLS := 64
const H_BRAID_HAWK := 65
const H_SIDECUT := 66
const H_DREAD_BUN := 67
const H_DREAD_HAWK := 68
const H_BLOWOUT := 69
const H_TEXT_FRINGE := 70
const H_TWIST_OUT := 71
const H_AFRO_PUFF := 72
const H_ZIGZAG_ROWS := 73
const H_LONG_BRAIDS_FADE := 74
const H_POMP_PART := 75
const H_LONG_WAVY := 76
const H_FROSTED := 77
const H_BUZZ_PART := 78
const H_SPONGE := 79
const H_LOW_BUN := 80
const H_TEXT_QUIFF := 81
const H_LONG_SIDE_FRINGE := 82
const H_CURTAIN := 83
const H_BUZZ_HIGH := 84
const H_SKIN_FADE := 85
const H_HIGH_QUIFF := 86
const H_CURLY_QUIFF := 87
const H_FRINGE_CREW := 88
const H_IVY := 89
const H_WET_BACK := 90
const H_CURLY_BURST := 91
const H_BIG_AFRO := 92
const H_AFRO_PART := 93
const H_LONG_TWISTS := 94
const H_DREAD_PONY := 95
const H_ROWS_PONY := 96
const H_TOPKNOT_FADE := 97
const H_LONG_FRINGE := 98
const H_BOB := 99
const H_CURLY_MULLET := 100
const H_SPIKY_HAWK := 101
const H_BLEACH_DESIGN := 102
const H_MESSY_WAVY := 103
const H_BIG_PART := 104
const H_CAESAR := 105
const H_QUIFF_BURST := 106
const H_UNDERCUT_LOWBUN := 107
const H_CURLY_LONG_FRINGE := 108
const H_FREEFORM_FADE := 109
const H_WAVES_FADE := 110
const H_FROSTED_CURLS := 111
const H_TWO_PUFFS := 112

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
	[1.0, 1.0, 1.6, 2.0], # burst fade
	[0.0, 0.0, 0.3, 1.8], # afro com degradê
	[0.6, 1.3, 0.4, 0.0], # flow para trás
	[1.4, 1.3, 0.5, 0.0], # topete bagunçado
	[0.3, 0.3, 0.4, 1.0], # máquina com desenho
	[0.0, 0.0, 0.0, 0.9], # nagô com degradê
	[0.0, 0.1, 1.1, 0.9], # moicano cacheado
	[1.0, 0.4, 0.0, 0.0], # liso médio
	[1.0, 0.5, 0.1, 0.0], # franja lateral
	[0.0, 0.0, 0.1, 0.9], # freeform
	[1.6, 1.6, 0.8, 0.8], # degradê social
	[0.0, 0.3, 2.4, 0.8], # cacheado com degradê
	[0.0, 0.4, 2.0, 0.6], # taper cacheado
	[1.2, 1.2, 1.2, 2.4], # buzz com degradê
	[0.5, 0.6, 0.5, 0.1], # coque com undercut
	[0.4, 0.6, 0.4, 0.0], # meio preso
	[0.6, 0.8, 0.8, 0.3], # mullet com degradê
	[1.0, 0.7, 0.4, 0.2], # corte Edgar
	[1.0, 0.8, 0.3, 0.1], # faux hawk
	[0.3, 0.3, 0.5, 1.0], # nevou
	[0.0, 0.0, 0.1, 1.0], # dreads com degradê
	[0.0, 0.3, 1.6, 0.3], # franja cacheada
	[1.0, 1.0, 0.2, 0.0], # para trás com degradê
	[0.0, 0.0, 0.1, 0.8], # tranças com coque
	[1.0, 1.0, 0.3, 0.1], # topete com risco
	[0.4, 0.5, 0.1, 0.0], # longo para trás
	[0.4, 1.4, 0.3, 0.0], # ondulado com franja
	[1.0, 0.6, 0.1, 0.0], # espetado com gel
	[0.0, 0.4, 2.0, 0.4], # cachos médios
	[0.0, 0.0, 0.0, 0.6], # moicano trançado
	[1.0, 0.8, 0.2, 0.0], # sidecut
	[0.0, 0.0, 0.1, 0.9], # dreads presos
	[0.0, 0.0, 0.0, 0.5], # moicano de dreads
	[1.2, 1.3, 0.4, 0.0], # blowout
	[1.6, 1.3, 0.3, 0.0], # franja texturizada
	[0.0, 0.2, 1.2, 1.6], # twist out
	[0.0, 0.0, 0.4, 0.9], # afro puff
	[0.0, 0.0, 0.0, 0.7], # nagô em zigue-zague
	[0.0, 0.0, 0.1, 0.8], # tranças longas com degradê
	[0.8, 0.8, 0.1, 0.0], # pompadour com risco
	[0.4, 0.9, 0.3, 0.0], # longo ondulado
	[0.8, 0.5, 0.3, 0.6], # espetado descolorido
	[0.6, 0.6, 0.6, 1.4], # máquina com risco
	[0.0, 0.0, 0.2, 1.8], # esponja
	[0.4, 0.6, 0.5, 0.2], # coque baixo
	[1.4, 1.3, 0.4, 0.0], # topete desfiado
	[0.8, 0.5, 0.1, 0.0], # franja longa de lado
	[1.0, 1.3, 0.3, 0.0], # franja cortina
	[1.4, 1.4, 1.0, 1.6], # máquina 2
	[1.4, 1.4, 1.2, 2.4], # degradê navalhado
	[0.8, 0.8, 0.2, 0.0], # topete alto
	[0.0, 0.3, 1.4, 0.3], # topete cacheado
	[1.4, 1.2, 0.4, 0.1], # social com franjinha
	[1.3, 1.3, 0.3, 0.0], # ivy league
	[0.8, 0.8, 0.2, 0.0], # molhado para trás
	[0.0, 0.2, 1.8, 1.2], # burst cacheado
	[0.0, 0.0, 0.1, 0.6], # black power alto
	[0.0, 0.0, 0.2, 1.3], # afro com risco
	[0.0, 0.0, 0.1, 0.8], # twists longos
	[0.0, 0.0, 0.1, 0.6], # dreads em rabo
	[0.0, 0.0, 0.0, 0.5], # nagô com rabo
	[0.4, 0.5, 0.4, 0.2], # coque alto com degradê
	[0.4, 0.4, 0.1, 0.0], # longo com franja
	[0.3, 0.4, 0.1, 0.0], # chanel
	[0.0, 0.2, 0.8, 0.2], # mullet cacheado
	[0.3, 0.3, 0.1, 0.1], # moicano espetado
	[0.2, 0.2, 0.3, 0.7], # descolorido com desenho
	[0.3, 1.4, 0.4, 0.0], # ondulado bagunçado
	[1.2, 1.2, 0.2, 0.0], # repartido volumoso
	[1.3, 1.1, 0.4, 0.1], # corte césar
	[0.9, 0.9, 0.4, 0.1], # topete com burst
	[0.4, 0.5, 0.4, 0.1], # undercut com coque baixo
	[0.0, 0.1, 0.9, 0.1], # cacheado longo com franja
	[0.0, 0.0, 0.1, 0.8], # freeform com degradê
	[0.0, 0.0, 0.0, 1.3], # waves com degradê
	[0.0, 0.2, 1.0, 0.8], # cachos com luzes
	[0.0, 0.0, 0.2, 0.5], # dois puffs
	[2.4, 2.2, 0.6, 0.1], # curto texturizado
	[1.8, 1.6, 0.4, 0.1], # degradê com topete baixo
	[2.6, 2.4, 0.8, 0.3], # social curto
	[2.0, 1.8, 0.4, 0.1], # repartido baixo
	[1.6, 1.2, 0.3, 0.0], # franja curta reta
	[1.2, 1.2, 0.4, 0.0], # topete com volume
	[0.0, 0.4, 2.6, 0.6], # cacheado curto
	[0.0, 0.3, 2.0, 0.8], # cachos com degradê navalhado
	[0.0, 0.0, 0.4, 2.6], # crespo curto
	[0.0, 0.0, 0.3, 2.4], # crespo com degradê alto
	[0.0, 0.0, 0.0, 0.8], # waves com risco
	[0.0, 0.0, 0.2, 1.2], # twists curtos
	[0.0, 0.0, 0.2, 1.0], # locs médios
	[0.4, 2.4, 0.6, 0.0], # ondulado curto
	[0.3, 1.8, 0.4, 0.0], # ondulado repartido
	[1.4, 0.8, 0.1, 0.0], # liso médio de lado
	[1.6, 1.4, 0.3, 0.0], # para trás curto
	[2.2, 2.0, 1.0, 1.2], # degradê baixo
	[2.0, 1.8, 1.0, 1.6], # degradê médio
	[1.4, 1.4, 1.0, 1.6], # máquina 3
	[0.6, 0.6, 0.6, 1.2], # raspado rente
	[1.4, 1.2, 0.3, 0.0], # topete bagunçado curto
	[1.2, 0.8, 0.1, 0.0], # franja desfiada
	[0.8, 1.2, 0.4, 0.0], # médio desarrumado
	[0.0, 0.1, 1.2, 0.6], # cacheado volumoso
	[0.0, 0.0, 0.2, 1.4], # afro médio
	[0.0, 0.0, 0.2, 1.6], # afro com degradê baixo
	[0.0, 0.0, 0.0, 0.8], # nagô reto com degradê
	[0.4, 0.5, 0.4, 0.1], # coque baixo com degradê
	[0.5, 0.6, 0.2, 0.0], # longo solto repartido
	[0.4, 1.2, 0.3, 0.0], # médio ondulado para trás
	[0.3, 1.4, 0.4, 0.0], # topete ondulado
	[0.0, 0.3, 1.6, 0.3], # crop cacheado
	[1.0, 1.0, 0.3, 0.3], # social com risco
	[0.6, 0.6, 0.6, 1.2], # buzz com risco lateral
	[1.6, 1.0, 0.2, 0.0], # curto com franja lateral
	[1.2, 0.8, 0.1, 0.0], # espetado curto
	[1.0, 1.0, 0.2, 0.0], # médio com franja cortina
	[0.0, 0.4, 1.4, 0.4], # cachos soltos médios
	[0.0, 0.0, 0.2, 1.4], # esponja com degradê
	[1.6, 1.4, 0.3, 0.0], # topete penteado navalhado
	[2.0, 1.8, 0.4, 0.0], # social natural
	[0.0, 0.0, 0.3, 2.6], # crespo baixo com degradê
	[0.8, 0.8, 0.8, 2.0], # buzz navalhado
	[1.2, 0.8, 0.1, 0.0], # liso para trás rente
	[0.3, 0.3, 0.1, 0.0], # moicano desfiado
	[0.0, 0.0, 0.2, 1.3], # twists caídos com degradê
	[1.6, 1.2, 0.2, 0.0], # franja bagunçada com degradê
	[1.8, 1.2, 0.2, 0.0], # french crop navalhado
	[0.0, 0.5, 1.8, 0.4], # franja cacheada navalhada
	[0.8, 0.8, 0.8, 1.8], # máquina 1 com contorno
	[1.6, 1.3, 0.3, 0.0], # texturizado de lado com degradê
	[0.0, 0.0, 0.1, 0.9], # black power redondo
	[0.0, 0.0, 0.1, 1.2], # afro alto navalhado
	[0.0, 0.0, 0.0, 0.4], # high top navalhado
	[0.0, 0.0, 0.2, 1.2], # twists médios
	[0.0, 0.0, 0.0, 0.6], # nagô em zigue-zague com degradê
	[0.0, 0.0, 0.2, 1.4], # esponja alta
	[0.0, 0.0, 0.1, 1.2], # locs com degradê navalhado
	[0.0, 0.0, 0.1, 0.5], # afro puff com degradê
	[0.0, 0.0, 0.0, 1.4], # waves 360
	[0.0, 0.0, 0.2, 1.2], # crespo médio com risco
	[0.0, 0.0, 0.1, 0.5], # frohawk
	[0.0, 0.2, 1.6, 0.8], # cachos definidos com degradê
	[0.0, 0.0, 0.3, 1.6], # crespo médio natural
	[0.0, 0.0, 0.6, 0.8], # high top cacheado com pontas descoloridas
	[0.5, 0.3, 0.0, 0.0], # longo liso molhado para trás
	[1.2, 0.5, 0.0, 0.0], # franja reta curta
	[0.2, 0.3, 0.5, 0.3], # moicano com pontas descoloridas
	[0.3, 0.3, 0.3, 0.3], # meia-lua na franja
	[0.6, 0.6, 0.2, 0.0], # topete descolorido com laterais escuras
	[0.0, 0.2, 0.8, 0.4], # cachinhos descoloridos no alto
	[0.0, 0.0, 0.2, 0.9], # crespo descolorido no alto
	[0.0, 0.0, 0.0, 0.5], # tranças nagô descoloridas
	[0.0, 0.0, 0.2, 0.9], # twists com pontas descoloridas
	[0.0, 0.0, 0.1, 0.5], # twists tingidos de vermelho
	[1.2, 1.1, 0.3, 0.0], # topete alto arrepiado com degradê
	[0.6, 0.4, 0.1, 0.0], # espetado com luzes
	[0.1, 0.1, 0.3, 0.5], # moicano descolorido
	[0.2, 0.2, 0.3, 0.5], # moicano com desenhos laterais
	[0.3, 0.3, 0.1, 0.0], # crista alta
	[0.0, 0.0, 0.4, 0.3], # afro gigante loiro
	[0.0, 0.0, 0.2, 0.4], # black power gigante
	[0.0, 0.1, 0.8, 0.3], # cachos armados gigantes
	[0.0, 0.0, 0.1, 0.7], # dreads longos volumosos
	[0.0, 0.0, 0.1, 0.5], # dreads com faixa
	[0.4, 0.5, 0.2, 0.0], # longo com faixa
	[0.0, 0.2, 0.7, 0.2], # cacheado longo com faixa
	[0.5, 0.6, 0.3, 0.0], # preso para trás com mechas soltas
	[0.3, 0.3, 0.1, 0.0], # rabinho trançado na nuca
	[0.1, 0.1, 0.2, 0.3], # moicano tingido de azul
	[0.3, 0.3, 0.1, 0.0], # listra tingida de vermelho no meio
	[1.0, 1.0, 0.2, 0.0], # undercut para trás com risco
	[0.0, 0.0, 0.1, 0.8], # esponja descolorida
	[0.0, 0.0, 0.0, 0.3], # tufinhos trançados tingidos de verde
	[0.0, 0.0, 0.2, 0.6], # black power com costeletas longas
	[0.8, 1.0, 0.2, 0.0], # para trás volumoso até a nuca
	[0.3, 0.8, 0.2, 0.0], # longo ondulado atrás das orelhas
	[0.3, 1.8, 0.4, 0.0], # ondulado com degradê
	[0.0, 0.3, 1.6, 0.3], # cacheado médio com franja
	[1.4, 1.2, 0.3, 0.0], # repartido navalhado
	[0.0, 0.0, 0.2, 1.2], # twists curtos com degradê baixo
	[1.0, 1.0, 0.2, 0.0], # médio penteado de lado
	[0.0, 0.3, 2.0, 0.6], # cacheado com laterais curtas
	[1.2, 1.0, 0.2, 0.0], # social com gel
	[1.0, 1.2, 0.2, 0.0], # curto repartido ao meio
	[0.0, 0.0, 0.4, 1.8], # crespo médio com degradê baixo
	[1.6, 1.4, 0.4, 0.0], # topete curto natural
	[0.0, 0.1, 0.4, 0.1], # coque samurai cacheado
	[0.0, 0.0, 0.0, 0.5], # nagô com risco lateral
	[0.2, 0.6, 0.3, 0.0], # ondulado preso em coque baixo
	[1.0, 1.0, 0.2, 0.0], # para trás desarrumado com degradê
]
## Penteados que exigem cabelo (somem com calvície avançada).
const NEEDS_HAIR: Array[int] = [H_QUIFF, H_CURLY, H_AFRO, H_LONG, H_BUN, H_FRINGE, H_POMPADOUR, H_WAVY,
	H_MIDPART, H_MULLET, H_PONYTAIL, H_HIGHTOP, H_SURFER, H_BOWL, H_BRAIDS, H_TOPKNOT, H_LONG_CURLY, H_TWISTS,
	H_TAPER_AFRO, H_FLOW, H_MESSY, H_CURLY_MOHAWK, H_TWO_BLOCK, H_SIDE_FRINGE, H_FREEFORM, H_CURLY_FADE,
	H_CURLY_TAPER, H_BUN_UNDERCUT, H_HALF_UP, H_FADE_MULLET, H_EDGAR, H_FAUX_HAWK, H_LOCS_FADE, H_CURLY_FRINGE,
	H_BRAID_BUN, H_QUIFF_PART, H_LONG_BACK, H_WAVY_FRINGE, H_GEL_SPIKES, H_MED_CURLS, H_SIDECUT,
	H_DREAD_BUN, H_DREAD_HAWK, H_BLOWOUT, H_TEXT_FRINGE, H_TWIST_OUT, H_AFRO_PUFF, H_LONG_BRAIDS_FADE, H_POMP_PART,
	H_LONG_WAVY, H_FROSTED, H_SPONGE, H_LOW_BUN, H_TEXT_QUIFF, H_LONG_SIDE_FRINGE, H_ZIGZAG_ROWS,
	H_CURTAIN, H_HIGH_QUIFF, H_CURLY_QUIFF, H_CURLY_BURST, H_BIG_AFRO, H_AFRO_PART, H_LONG_TWISTS, H_DREAD_PONY,
	H_ROWS_PONY, H_TOPKNOT_FADE, H_LONG_FRINGE, H_BOB, H_CURLY_MULLET, H_SPIKY_HAWK, H_MESSY_WAVY, H_BIG_PART,
	H_QUIFF_BURST, H_UNDERCUT_LOWBUN, H_CURLY_LONG_FRINGE, H_FREEFORM_FADE, H_FROSTED_CURLS, H_TWO_PUFFS,
	113, 114, 116, 117, 118, 119, 120, 124, 125, 126, 127, 128, 134, 135, 136, 137, 138, 139, 141, 142, 143, 144, 145, 146, 148, 150, 151, 152,
	153, 154, 157, 158, 159, 160, 161, 162, 164, 165, 166, 167, 168, 170, 171, 172, 174, 175, 176, 177, 178, 179, 180, 181,
	182, 183, 184, 185, 186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210,
	211, 212, 213, 214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224]

# ---------------------------------------------------------------------------
# Barbas
# ---------------------------------------------------------------------------
const BEARDS: Array[String] = [
	"Sem barba", "Por fazer", "Curta", "Cheia", "Cavanhaque", "Bigode", "Contorno", "Bigode e cavanhaque",
	"Rala", "Longa", "Três dias", "Ferradura", "Mosca", "Costeletas", "Âncora", "Barba sem bigode",
	"Bigode fino", "Desenhada", "Balbo", "Cavanhaque longo", "Buço", "Bigode grosso", "Imperial",
	"Cavanhaque fechado", "Garibaldi", "Barba degradê", "Barba média", "Cerrada", "Lenhador", "Bigode e mosca",
	"Barba quadrada", "Bigode inglês", "Barba com risco", "Bigode fino e cavanhaque", "Hollywood", "Contorno com mosca",
	"Cheia aparada", "Longa pontuda",
	"Bigode guidão", "Fu Manchu", "Bigode morsa", "Barba de uma semana", "Barba Verdi", "Lenhador longa",
	"Cavanhaque com costeletas", "Curta com bigode grosso", "Queixo e bigode fino", "Tufo no queixo",
	"Desenhada grossa", "Âncora longa",
	"Barba arredondada", "Curta marcada", "Penugem", "Bigode fino largo", "Bigode curto",
	"Bigode e queixo", "Cavanhaque largo", "Cavanhaque pontudo", "Sem bigode curta", "Queixo largo",
	"Quadrada longa", "Desgrenhada", "Morsa com barba curta", "Guidão e cavanhaque", "Guidão com barba",
	"Costeletas compridas", "Contorno fino com bigode", "Sombra no queixo", "Degradê comprida", "Média com risco",
	"Ferradura grossa", "Mosca comprida", "Bifurcada", "Longa com guidão", "Bigode fino e mosca",
	"Barba baixa", "Barba alta", "Cavanhaque triangular", "Semana com bigode grosso", "Longa rala",
	# 80+
	"Por fazer leve", "Barba de três dias", "Curta aparada alta", "Curta com contorno baixo", "Média arredondada", "Cheia curta", "Rala desigual", "Cavanhaque curto", "Cavanhaque e bigode fino", "Bigode e mosca curtos", "Contorno fino com cavanhaque", "Queixo e mandíbula", "Cheia com degradê curto", "Barba de dez dias", "Queixo sombreado", "Bigode cheio curto", "Média quadrada", "Longa aparada", "Costeletas e bigode", "Cavanhaque largo curto", "Por fazer marcada", "Curta rala nas bochechas", "Âncora curta", "Cheia densa",
	"Cavanhaque de ponta com bigode", "Círculo aparado", "Bigode fino e mosca", "Contorno fino", "Barba curta com degradê", "Cheia aparada baixa", "Cavanhaque longo pontudo", "Barba de duas semanas", "Bigode e barba no queixo", "Por fazer leve", "Bigode grosso com mosca", "Cheia volumosa", "Barba quadrada curta", "Cavanhaque ralo", "Costeletas longas", "Barba rala com bigode",
	"Cheia longa e volumosa",
	# 121+
	"Cheia cacheada volumosa", "Crespa curta", "Crespa longa", "Cavanhaque crespo", "Crespa com contorno navalhado", "Por fazer com cavanhaque", "Por fazer com bigode e cavanhaque", "Por fazer com bigode grosso", "Por fazer com mosca", "Cavanhaque descolorido", "Curta descolorida", "Bigode e cavanhaque descoloridos", "Barba com dois riscos", "Cavanhaque com risco no meio", "Cavanhaque trançado", "Longa com trança no queixo", "Pontuda desenhada", "Cheia média desalinhada", "Curta com queixo pontudo", "Crespa pontuda",
	# 141+ (entram por sorteio à parte, ver _newer_beard)
	"Curta sem costeletas", "Por fazer no queixo e bigode", "Média com pescoço aparado", "Cheia rala nas bochechas",
	"Cavanhaque com bigode ralo", "Contorno com queixo cheio", "Três dias com contorno", "Média pontuda curta",
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
const B_CHEVRON := 21
const B_IMPERIAL := 22
const B_CIRCLE := 23
const B_GARIBALDI := 24
const B_FADED := 25
const B_MEDIUM := 26
const B_DENSE_STUBBLE := 27
const B_LUMBERJACK := 28
const B_MUSTACHE_SOUL := 29
const B_SQUARE := 30
const B_ENGLISH := 31
const B_LINE_CUT := 32
const B_PENCIL_GOATEE := 33
const B_HOLLYWOOD := 34
const B_STRAP_SOUL := 35
const B_TRIMMED := 36
const B_POINTED := 37
const B_HANDLEBAR := 38
const B_FU_MANCHU := 39
const B_WALRUS := 40
const B_WEEK := 41
const B_VERDI := 42
const B_BANDHOLZ := 43
const B_GOATEE_SIDES := 44
const B_SHORT_THICK_MU := 45
const B_CHIN_PENCIL := 46
const B_CHIN_PUFF := 47
const B_THICK_LINED := 48
const B_LONG_ANCHOR := 49
const B_ROUNDED := 50
const B_SHORT_SHARP := 51
const B_PEACH := 52
const B_WIDE_PENCIL := 53
const B_SHORT_MU := 54
const B_MU_CHIN := 55
const B_WIDE_GOATEE := 56
const B_POINT_GOATEE := 57
const B_CHIN_CURTAIN_SHORT := 58
const B_WIDE_CHIN := 59
const B_LONG_BOX := 60
const B_SCRUFFY := 61
const B_WALRUS_SHORT := 62
const B_HANDLEBAR_GOATEE := 63
const B_HANDLEBAR_BEARD := 64
const B_LONG_SIDEBURNS := 65
const B_THIN_LINE_MU := 66
const B_CHIN_SHADOW := 67
const B_LONG_FADE := 68
const B_MEDIUM_CUT := 69
const B_THICK_HORSESHOE := 70
const B_LONG_SOUL := 71
const B_FORKED := 72
const B_LONG_HANDLEBAR := 73
const B_PENCIL_SOUL := 74
const B_LOW_LINE := 75
const B_HIGH_LINE := 76
const B_TRIANGLE := 77
const B_WEEK_THICK_MU := 78
const B_LONG_THIN := 79

## Partes de cada barba: ch = bochechas (0 = não, senão a altura da linha: 0.1 alta … 0.5 baixa),
## sd = costeletas, jw = contorno da mandíbula, cn = queixo, mu = bigode (1 normal, 2 fino, 3 ferradura),
## so = mosca, nk = pescoço, ln = comprimento além do rosto, op = opacidade, sh = contorno marcado,
## pt = falhas, tx = textura (0 pontos, 1 fios); cr = fios crespos, ov = outra barba por cima (cheia),
## bl = descolorida, cut 2 = dois riscos, gap = risco no meio do queixo, brd = trança no queixo.
const BEARD_PARTS: Array = [
	{},
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.5, "ln": 0.0, "op": 0.3, "sh": 0.0, "pt": 0.15, "tx": 0},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.86, "sh": 0.3, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.2, "op": 0.95, "sh": 0.1, "pt": 0.0, "tx": 1, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.4, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.5, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.3, "sd": 0.8, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.62, "sh": 0.0, "pt": 0.75, "tx": 1, "cl": 1.0},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.55, "op": 0.96, "sh": 0.0, "pt": 0.0, "tx": 1, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.52, "sh": 0.15, "pt": 0.08, "tx": 0, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 3, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.4, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.88, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.28, "sd": 1.0, "jw": 0.8, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.35, "cn": 0.9, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1},
	{"ch": 0.45, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 0, "so": 0.0, "nk": 0.25, "ln": 0.14, "op": 0.93, "sh": 0.2, "pt": 0.0, "tx": 1, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 2, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.8, "pt": 0.0, "tx": 1},
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.95, "sh": 1.0, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.3, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.35, "op": 0.92, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.35, "mu": 1, "so": 0.3, "nk": 0.0, "ln": 0.0, "op": 0.34, "sh": 0.0, "pt": 0.5, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 4, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.95, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.8, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.8, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.92, "sh": 0.5, "pt": 0.0, "tx": 1, "ci": 1.0},
	{"ch": 0.16, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.38, "op": 0.95, "sh": 0.0, "pt": 0.0, "tx": 1, "rd": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.93, "sh": 0.6, "pt": 0.0, "tx": 1, "fd": 1.0, "cl": 1.0},
	{"ch": 0.18, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.11, "op": 0.94, "sh": 0.2, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.24, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.015, "op": 0.72, "sh": 0.2, "pt": 0.04, "tx": 1, "cl": 1.0},
	{"ch": 0.1, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 4, "so": 1.0, "nk": 0.25, "ln": 0.48, "op": 0.97, "sh": 0.0, "pt": 0.0, "tx": 1, "rd": 1.3, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.13, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.18, "op": 0.96, "sh": 1.0, "pt": 0.0, "tx": 1, "rd": 0.7, "sq": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 5, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.6, "pt": 0.0, "tx": 1},
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.94, "sh": 0.9, "pt": 0.0, "tx": 1, "cut": 1.0, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.6, "mu": 2, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1},
	{"ch": 0.3, "sd": 0.0, "jw": 0.9, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.93, "sh": 0.5, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.4, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.8, "pt": 0.0, "tx": 1},
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.035, "op": 0.9, "sh": 0.9, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.16, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.42, "op": 0.95, "sh": 0.1, "pt": 0.0, "tx": 1, "pp": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 6, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.95, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 7, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.95, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 8, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.97, "sh": 0.3, "pt": 0.0, "tx": 1},
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.66, "sh": 0.15, "pt": 0.03, "tx": 0, "cl": 1.0},
	{"ch": 0.15, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 6, "so": 1.0, "nk": 0.25, "ln": 0.3, "op": 0.96, "sh": 0.2, "pt": 0.0, "tx": 1, "rd": 1.25, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.1, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 4, "so": 1.0, "nk": 0.25, "ln": 0.68, "op": 0.97, "sh": 0.0, "pt": 0.0, "tx": 1, "rd": 1.4, "wild": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.0, "sd": 1.0, "jw": 0.0, "cn": 0.75, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "sdl": 1.0},
	{"ch": 0.26, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 4, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.93, "sh": 0.4, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 1.0, "jw": 0.6, "cn": 0.45, "mu": 2, "so": 0.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.85, "pt": 0.0, "tx": 1, "thin": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.5, "mu": 0, "so": 0.5, "nk": 0.0, "ln": 0.06, "op": 0.8, "sh": 0.2, "pt": 0.2, "tx": 1},
	{"ch": 0.12, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.09, "op": 0.97, "sh": 1.0, "pt": 0.0, "tx": 1, "cut": 1.0, "sq": 0.6, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.35, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.22, "op": 0.94, "sh": 0.5, "pt": 0.0, "tx": 1, "pp": 1.0},
	{"ch": 0.18, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.2, "op": 0.95, "sh": 0.15, "pt": 0.0, "tx": 1, "rd": 1.2, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.92, "sh": 0.9, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 0.5, "jw": 0.6, "cn": 0.8, "mu": 1, "so": 0.6, "nk": 0.0, "ln": 0.0, "op": 0.38, "sh": 0.0, "pt": 0.45, "tx": 0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 2, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.92, "sh": 0.8, "pt": 0.0, "tx": 1, "mw": 1.25},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.8, "pt": 0.0, "tx": 1, "mw": 0.82, "mh": 0.8},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.55, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "cnw": 0.75},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 1.0, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.92, "sh": 0.6, "pt": 0.0, "tx": 1, "cnw": 1.3},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.6, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.24, "op": 0.92, "sh": 0.5, "pt": 0.0, "tx": 1, "tri": 1.0, "cnw": 0.8},
	{"ch": 0.4, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.04, "op": 0.92, "sh": 0.6, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.6, "cn": 1.0, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.92, "sh": 0.6, "pt": 0.0, "tx": 1, "cnw": 1.3},
	{"ch": 0.12, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 4, "so": 1.0, "nk": 0.25, "ln": 0.3, "op": 0.97, "sh": 0.8, "pt": 0.0, "tx": 1, "sq": 0.8, "rd": 0.8, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.46, "op": 0.95, "sh": 0.0, "pt": 0.05, "tx": 1, "rd": 1.2, "wild": 0.4, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 8, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.94, "sh": 0.3, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.6, "mu": 6, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.94, "sh": 0.5, "pt": 0.0, "tx": 1},
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 6, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.94, "sh": 0.4, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 1.0, "jw": 0.0, "cn": 0.0, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "sdl": 1.0},
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.45, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.9, "pt": 0.0, "tx": 1, "thin": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.6, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.3, "ln": 0.0, "op": 0.45, "sh": 0.0, "pt": 0.1, "tx": 0},
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.2, "op": 0.95, "sh": 0.4, "pt": 0.0, "tx": 1, "fd": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.18, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.12, "op": 0.95, "sh": 0.7, "pt": 0.0, "tx": 1, "cut": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 3, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.97, "sh": 0.4, "pt": 0.0, "tx": 1, "mw": 1.12, "mh": 1.3},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1, "sl": 2.2},
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.5, "op": 0.96, "sh": 0.1, "pt": 0.0, "tx": 1, "rd": 1.1, "fk": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.15, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 6, "so": 1.0, "nk": 0.25, "ln": 0.45, "op": 0.96, "sh": 0.1, "pt": 0.0, "tx": 1, "rd": 1.1, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 2, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1},
	{"ch": 0.45, "sd": 0.7, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.93, "sh": 0.5, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.06, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.94, "sh": 0.3, "pt": 0.0, "tx": 1, "cl": 1.0},
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.9, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.14, "op": 0.93, "sh": 0.6, "pt": 0.0, "tx": 1, "ci": 1.0, "tri": 0.8},
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 4, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.64, "sh": 0.15, "pt": 0.03, "tx": 0, "cl": 1.0},
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.42, "op": 0.72, "sh": 0.0, "pt": 0.3, "tx": 1, "pp": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 2.3},
	{"ch": 0.3, "sd": 0.8, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 0.8, "nk": 0.3, "ln": 0.0, "op": 0.22, "sh": 0.0, "pt": 0.2, "tx": 0}, # por fazer leve
	{"ch": 0.26, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.01, "op": 0.6, "sh": 0.1, "pt": 0.05, "tx": 0, "cl": 1.0}, # barba de três dias
	{"ch": 0.12, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1, "cl": 1.0}, # curta aparada alta
	{"ch": 0.34, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.8, "pt": 0.0, "tx": 1, "cl": 1.0}, # curta com contorno baixo
	{"ch": 0.17, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.14, "op": 0.95, "sh": 0.2, "pt": 0.0, "tx": 1, "rd": 1.1, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # média arredondada
	{"ch": 0.15, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.08, "op": 0.94, "sh": 0.3, "pt": 0.0, "tx": 1, "cl": 1.0}, # cheia curta
	{"ch": 0.3, "sd": 0.6, "jw": 0.9, "cn": 1.0, "mu": 1, "so": 0.8, "nk": 0.0, "ln": 0.02, "op": 0.5, "sh": 0.0, "pt": 0.55, "tx": 1, "cl": 1.0}, # rala desigual
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.6, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.85, "sh": 0.5, "pt": 0.0, "tx": 1}, # cavanhaque curto
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.65, "mu": 2, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.88, "sh": 0.6, "pt": 0.0, "tx": 1}, # cavanhaque e bigode fino
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.7, "nk": 0.0, "ln": 0.0, "op": 0.85, "sh": 0.5, "pt": 0.0, "tx": 1}, # bigode e mosca curtos
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.9, "sh": 0.85, "pt": 0.0, "tx": 1, "thin": 1.0}, # contorno fino com cavanhaque
	{"ch": 0.0, "sd": 0.0, "jw": 0.8, "cn": 1.0, "mu": 0, "so": 1.0, "nk": 0.1, "ln": 0.04, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1}, # queixo e mandíbula
	{"ch": 0.18, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.93, "sh": 0.6, "pt": 0.0, "tx": 1, "fd": 1.0, "cl": 1.0}, # cheia com degradê curto
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.78, "sh": 0.15, "pt": 0.03, "tx": 1, "cl": 1.0}, # barba de dez dias
	{"ch": 0.0, "sd": 0.0, "jw": 0.4, "cn": 0.8, "mu": 1, "so": 0.8, "nk": 0.0, "ln": 0.0, "op": 0.35, "sh": 0.0, "pt": 0.2, "tx": 0}, # queixo sombreado
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.95, "sh": 0.5, "pt": 0.0, "tx": 1, "mw": 1.08, "mh": 1.15}, # bigode cheio curto
	{"ch": 0.15, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.16, "op": 0.95, "sh": 0.8, "pt": 0.0, "tx": 1, "sq": 0.9, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # média quadrada
	{"ch": 0.15, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.3, "op": 0.95, "sh": 0.4, "pt": 0.0, "tx": 1, "rd": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # longa aparada
	{"ch": 0.0, "sd": 1.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "sdl": 1.0}, # costeletas e bigode
	{"ch": 0.0, "sd": 0.0, "jw": 0.3, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "cnw": 1.2}, # cavanhaque largo curto
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.72, "sh": 0.3, "pt": 0.02, "tx": 0, "cl": 1.0}, # por fazer marcada
	{"ch": 0.4, "sd": 0.8, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.85, "sh": 0.2, "pt": 0.25, "tx": 1, "cl": 1.0}, # curta rala nas bochechas
	{"ch": 0.0, "sd": 0.0, "jw": 0.25, "cn": 0.85, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.9, "sh": 0.7, "pt": 0.0, "tx": 1}, # âncora curta
	{"ch": 0.1, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.22, "op": 0.98, "sh": 0.2, "pt": 0.0, "tx": 1, "rd": 1.15, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # cheia densa
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.8, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.08, "op": 0.95, "sh": 0.7, "pt": 0.0, "tx": 1, "cnw": 0.8, "mh": 0.8}, # cavanhaque de ponta com bigode
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.92, "sh": 0.8, "pt": 0.0, "tx": 1, "cnw": 0.9}, # círculo aparado
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 2, "so": 0.7, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1}, # bigode fino e mosca
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.6, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.02, "op": 0.88, "sh": 0.9, "pt": 0.0, "tx": 1, "thin": 1.0}, # contorno fino
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "fd": 1.0, "cl": 1.0}, # barba curta com degradê
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.93, "sh": 0.8, "pt": 0.0, "tx": 1, "cl": 1.0}, # cheia aparada baixa
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.8, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.25, "op": 0.92, "sh": 0.3, "pt": 0.0, "tx": 1, "cnw": 0.95, "tri": 0.6}, # cavanhaque longo pontudo
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.85, "sh": 0.2, "pt": 0.04, "tx": 1, "cl": 1.0}, # barba de duas semanas
	{"ch": 0.0, "sd": 0.0, "jw": 0.5, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1}, # bigode e barba no queixo
	{"ch": 0.3, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.0, "op": 0.22, "sh": 0.0, "pt": 0.2, "tx": 0}, # por fazer leve
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.95, "sh": 0.5, "pt": 0.0, "tx": 1, "mw": 1.1, "mh": 1.15}, # bigode grosso com mosca
	{"ch": 0.12, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.3, "op": 0.97, "sh": 0.2, "pt": 0.0, "tx": 1, "rd": 1.2, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # cheia volumosa
	{"ch": 0.18, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.1, "op": 0.95, "sh": 0.8, "pt": 0.0, "tx": 1, "sq": 0.8, "cl": 1.0}, # barba quadrada curta
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.55, "sh": 0.2, "pt": 0.4, "tx": 1}, # cavanhaque ralo
	{"ch": 0.0, "sd": 1.0, "jw": 0.0, "cn": 0.0, "mu": 0, "so": 0.0, "nk": 0.0, "ln": 0.0, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1, "sdl": 1.0}, # costeletas longas
	{"ch": 0.35, "sd": 0.7, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.02, "op": 0.6, "sh": 0.5, "pt": 0.45, "tx": 1, "cl": 1.0}, # barba rala com bigode
	{"ch": 0.1, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.32, "op": 0.98, "sh": 0.1, "pt": 0.0, "tx": 1, "rd": 1.35, "cnw": 1.9, "hw": 0.9, "cl": 1.0}, # cheia longa e volumosa
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.07, "op": 0.96, "sh": 0.1, "pt": 0.0, "tx": 1, "rd": 1.3, "cr": 1.0, "cnw": 1.6, "hw": 0.9, "cl": 1.0}, # cheia cacheada volumosa
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.94, "sh": 0.3, "pt": 0.0, "tx": 1, "cr": 1.0, "cl": 1.0}, # crespa curta
	{"ch": 0.12, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.16, "op": 0.97, "sh": 0.05, "pt": 0.0, "tx": 1, "rd": 1.25, "cr": 1.0, "cnw": 1.9, "hw": 0.9, "cl": 1.0}, # crespa longa
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.8, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.12, "op": 0.92, "sh": 0.4, "pt": 0.0, "tx": 1, "cr": 1.0}, # cavanhaque crespo
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.08, "op": 0.95, "sh": 1.0, "pt": 0.0, "tx": 1, "cr": 1.0, "cl": 1.0}, # crespa com contorno navalhado
	{"ch": 0.28, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.0, "op": 0.42, "sh": 0.0, "pt": 0.1, "tx": 0, "ov": 4}, # por fazer com cavanhaque
	{"ch": 0.28, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.0, "op": 0.42, "sh": 0.0, "pt": 0.1, "tx": 0, "ov": 7}, # por fazer com bigode e cavanhaque
	{"ch": 0.28, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.0, "op": 0.42, "sh": 0.0, "pt": 0.1, "tx": 0, "ov": 21}, # por fazer com bigode grosso
	{"ch": 0.28, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.4, "ln": 0.0, "op": 0.42, "sh": 0.0, "pt": 0.1, "tx": 0, "ov": 12}, # por fazer com mosca
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 0, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.92, "sh": 0.5, "pt": 0.0, "tx": 1, "bl": 1.0}, # cavanhaque descolorido
	{"ch": 0.25, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.88, "sh": 0.3, "pt": 0.0, "tx": 1, "bl": 1.0, "cl": 1.0}, # curta descolorida
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.9, "sh": 0.5, "pt": 0.0, "tx": 1, "bl": 1.0}, # bigode e cavanhaque descoloridos
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.06, "op": 0.95, "sh": 0.9, "pt": 0.0, "tx": 1, "cut": 2.0, "cl": 1.0}, # barba com dois riscos
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.8, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.05, "op": 0.93, "sh": 0.7, "pt": 0.0, "tx": 1, "ci": 1.0, "gap": 1.0}, # cavanhaque com risco no meio
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.75, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.12, "op": 0.93, "sh": 0.4, "pt": 0.0, "tx": 1, "cnw": 0.85, "brd": 0.25}, # cavanhaque trançado
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.35, "op": 0.95, "sh": 0.1, "pt": 0.0, "tx": 1, "pp": 1.0, "brd": 0.3, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # longa com trança no queixo
	{"ch": 0.14, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.28, "op": 0.96, "sh": 1.0, "pt": 0.0, "tx": 1, "pp": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # pontuda desenhada
	{"ch": 0.16, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.2, "op": 0.94, "sh": 0.0, "pt": 0.04, "tx": 1, "rd": 1.1, "wild": 0.7, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # cheia média desalinhada
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.18, "op": 0.93, "sh": 0.4, "pt": 0.0, "tx": 1, "fd": 1.0, "pp": 1.0, "cl": 1.0, "hw": 0.9, "cnw": 1.5}, # curta com queixo pontudo
	{"ch": 0.16, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.25, "ln": 0.12, "op": 0.95, "sh": 0.1, "pt": 0.0, "tx": 1, "pp": 1.0, "cr": 1.0, "cnw": 1.5, "hw": 0.6, "cl": 1.0}, # crespa pontuda
	{"ch": 0.28, "sd": 0.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.04, "op": 0.86, "sh": 0.3, "pt": 0.0, "tx": 1, "cl": 1.0}, # curta sem costeletas
	{"ch": 0.0, "sd": 0.0, "jw": 0.3, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.36, "sh": 0.0, "pt": 0.1, "tx": 0}, # por fazer no queixo e bigode
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.12, "op": 0.93, "sh": 0.6, "pt": 0.0, "tx": 1, "cl": 1.0}, # média com pescoço aparado
	{"ch": 0.36, "sd": 0.9, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.1, "ln": 0.09, "op": 0.8, "sh": 0.1, "pt": 0.35, "tx": 1, "cl": 1.0}, # cheia rala nas bochechas
	{"ch": 0.0, "sd": 0.0, "jw": 0.0, "cn": 0.7, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.03, "op": 0.62, "sh": 0.2, "pt": 0.4, "tx": 1}, # cavanhaque com bigode ralo
	{"ch": 0.0, "sd": 1.0, "jw": 1.0, "cn": 0.85, "mu": 0, "so": 0.6, "nk": 0.0, "ln": 0.04, "op": 0.9, "sh": 0.6, "pt": 0.0, "tx": 1}, # contorno com queixo cheio
	{"ch": 0.22, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.0, "op": 0.55, "sh": 0.7, "pt": 0.03, "tx": 0, "cl": 1.0}, # três dias com contorno
	{"ch": 0.2, "sd": 1.0, "jw": 1.0, "cn": 1.0, "mu": 1, "so": 1.0, "nk": 0.0, "ln": 0.16, "op": 0.94, "sh": 0.3, "pt": 0.0, "tx": 1, "pp": 0.6, "cl": 1.0, "hw": 0.9, "cnw": 1.3}, # média pontuda curta
]
## Barbas de fio crespo: combinam com cabelo cacheado/crespo.
const CURLY_BEARDS: Array[int] = [121, 122, 123, 124, 125, 140]
## Capacidade de barba mínima para cada estilo (genética × maturidade).
const BEARD_MIN_CAP: Array[float] = [0.0, 0.22, 0.55, 0.72, 0.42, 0.5, 0.55, 0.5, 0.25, 0.82, 0.32, 0.6, 0.3, 0.65, 0.55, 0.62, 0.45, 0.62, 0.55, 0.66, 0.06, 0.55, 0.5, 0.5, 0.8, 0.6, 0.65, 0.42,
	0.88, 0.5, 0.72, 0.55, 0.6, 0.5, 0.6, 0.55, 0.55, 0.8,
	0.6, 0.62, 0.66, 0.4, 0.8, 0.9, 0.58, 0.64, 0.5, 0.3, 0.72, 0.7,
	0.78, 0.6, 0.05, 0.5, 0.45, 0.5, 0.6, 0.62, 0.62, 0.58, 0.88, 0.85, 0.66, 0.6, 0.66, 0.5, 0.55, 0.3, 0.72, 0.64,
	0.6, 0.35, 0.9, 0.85, 0.48, 0.66, 0.7, 0.6, 0.45, 0.7,
	0.15, 0.4, 0.6, 0.55, 0.72, 0.7, 0.2, 0.35, 0.45, 0.45, 0.55, 0.5, 0.62, 0.5, 0.2, 0.5, 0.75, 0.8, 0.55, 0.5, 0.35, 0.45, 0.5, 0.85,
	0.5, 0.5, 0.4, 0.55, 0.6, 0.65, 0.6, 0.55, 0.5, 0.1, 0.55, 0.85, 0.7, 0.25, 0.45, 0.3, 0.9,
	0.8, 0.6, 0.85, 0.45, 0.62, 0.45, 0.5, 0.5, 0.3, 0.42, 0.55, 0.5, 0.6, 0.5, 0.55, 0.85, 0.8, 0.78, 0.65, 0.8,
	0.55, 0.3, 0.62, 0.45, 0.35, 0.55, 0.4, 0.66]
## Popularidade dos estilos entre quem pode tê-los.
const BEARD_POP: Array[float] = [5.0, 3.2, 2.4, 1.3, 0.8, 0.35, 0.45, 0.7, 1.0, 0.25, 2.4, 0.12, 0.25, 0.12, 0.3, 0.2, 0.12, 1.2, 0.3, 0.15, 0.8, 0.25, 0.2, 0.7, 0.25, 1.4, 1.6, 1.8,
	0.12, 0.25, 0.45, 0.08, 0.4, 0.3, 0.35, 0.15, 1.0, 0.1,
	0.12, 0.08, 0.1, 1.8, 0.3, 0.08, 0.3, 0.6, 0.35, 0.6, 0.9, 0.2,
	0.5, 1.2, 0.9, 0.12, 0.3, 0.5, 0.35, 0.25, 0.2, 0.3, 0.15, 0.15, 0.1, 0.1, 0.1, 0.15, 0.4, 0.8, 0.35, 0.3,
	0.08, 0.2, 0.06, 0.05, 0.2, 0.5, 0.6, 0.3, 0.5, 0.12,
	2.0, 2.0, 1.2, 1.2, 0.8, 1.0, 0.8, 0.6, 0.4, 0.3, 0.4, 0.3, 1.0, 1.2, 0.8, 0.2, 0.4, 0.25, 0.1, 0.35, 1.4, 0.7, 0.25, 0.5,
	0.9, 0.8, 0.5, 0.5, 1.2, 1.0, 0.2, 1.2, 0.5, 2.0, 0.2, 0.3, 0.6, 0.9, 0.1, 1.0, 0.25,
	0.6, 1.0, 0.25, 0.4, 0.6, 0.5, 0.5, 0.2, 0.3, 0.08, 0.08, 0.06, 0.1, 0.1, 0.05, 0.04, 0.3, 0.3, 0.6, 0.2,
	0.6, 0.5, 0.8, 0.5, 0.4, 0.3, 1.0, 0.4]

# ---------------------------------------------------------------------------
# Cores
# ---------------------------------------------------------------------------
const HAIR_COLOR_NAMES: Array[String] = [
	"Preto", "Castanho-escuro", "Castanho", "Castanho-claro", "Loiro-escuro", "Loiro", "Ruivo", "Platinado",
	"Acaju", "Loiro-acinzentado", "Preto-azulado", "Pontas descoloridas", "Loiro mel", "Tingido de vermelho",
]
const HC_PLATINUM := 7
const HC_TIPS := 11
const HC_HONEY := 12
const HC_RED_DYE := 13
## Penteados que já vêm com a cor (descoloridos e tingidos): índice do penteado → cor do cabelo.
const STYLE_DYE := {186: HC_PLATINUM, 188: HC_RED_DYE, 191: HC_PLATINUM, 194: HC_PLATINUM, 203: HC_PLATINUM,
	206: HC_PLATINUM, 207: HC_PLATINUM}
## Tintas fora da paleta (a sobrancelha e a barba seguem naturais, como nas outras tintas).
const STYLE_DYE_COLOR := {194: "#C99B4E", 203: "#2C5CC4", 207: "#3A8F4C"}
## Cores que são tinta (a sobrancelha e a barba continuam naturais).
const DYED: Array[int] = [HC_PLATINUM, HC_RED_DYE]
const HAIR_COLORS: Array[Color] = [
	Color("#161211"), Color("#2E1F16"), Color("#4B3122"), Color("#765033"),
	Color("#A1804F"), Color("#D2B57A"), Color("#93401D"), Color("#E6E0D2"),
	Color("#5B2B1E"), Color("#9A8A6E"), Color("#0D0E15"), Color("#1A1411"), Color("#B48748"), Color("#A3262A"),
]
## Tons de pele pelo índice contínuo: 0..9 são a escala original; abaixo de 0 (até -1) a pele
## clarinha de porcelana e acima de 9 (até 11) os tons mais retintos.
const SKIN_COLORS: Array[Color] = [
	Color("#FBE3D4"), Color("#F3CFB5"), Color("#E9BE9C"), Color("#DBA983"), Color("#C79369"),
	Color("#AF7A51"), Color("#936240"), Color("#774C30"), Color("#5B3923"), Color("#40281A"),
	Color("#33200F"), Color("#26180C"),
]
const SKIN_PORCELAIN := Color("#FFF1EA")
const SKIN_MIN := -1.0
const SKIN_MAX := 11.0
const FACE_SHAPES: Array[String] = ["Oval", "Redondo", "Quadrado", "Coração", "Losango", "Alongado", "Triangular", "Retangular",
	"Estreito", "Largo", "Queixo forte", "Queixo recuado",
	"Maçãs altas", "Mandíbula marcada", "Rosto curto", "Oval largo", "Oval estreito", "Pera"]
const EYE_SHAPES: Array[String] = ["Amendoado", "Grande", "Estreito", "Caído", "Puxado", "Fundo", "Afastados", "Próximos",
	"Encapuzado", "Saltado", "Pequenos", "Triste", "Felino", "Semicerrado",
	"Amendoado grande", "Redondo", "Levemente caído", "Estreito e puxado", "Pálpebra pesada", "Fundo e pequeno",
	"Abertos e afastados", "Amendoado fino"]
const EYE_SHAPE_W: Array[float] = [4.0, 1.2, 1.2, 0.8, 0.8, 0.8, 0.6, 0.6, 1.0, 0.5, 0.7, 0.5, 0.5, 0.6, 1.4, 0.9, 1.0, 0.8, 1.0, 0.7, 0.7, 1.2]
const NOSE_TYPES: Array[String] = ["Reto", "Arrebitado", "Batatudo", "Aquilino", "Largo", "Fino", "Achatado", "Grego",
	"Adunco", "Quebrado", "Pontudo", "Comprido", "Pequeno", "Narinas largas",
	"Dorso largo", "Ponta caída", "Largo e alto", "Curto e largo", "Romano", "Arrebitado largo", "Estreito e comprido",
	"Ponta redonda", "Asas altas", "Levemente torto"]
const MOUTH_TYPES: Array[String] = ["Comum", "Lábio de cima fino", "Lábios cheios", "Boca larga", "Boca pequena",
	"Lábio de baixo carnudo", "Cantos caídos", "Arco marcado", "Boca fina e reta", "Lábios grossos",
	"Lábio de cima cheio", "Média carnuda", "Coração", "Estreita e cheia", "Larga e fina", "Lábio de baixo fino",
	"Cantos para cima", "Arco suave"]
const BROW_TYPES: Array[String] = ["Comum", "Reta", "Arqueada", "Grossa", "Fina", "Caída", "Reta e grossa", "Rala",
	"Angulosa", "Baixa e pesada", "Alta", "Desgrenhada",
	"Curva suave", "Grossa arqueada", "Fina e reta", "Curta", "Longa", "Cheia e baixa", "Caída e grossa", "Pico suave",
	"Levantada", "Espessa e irregular"]
const EAR_TYPES: Array[String] = ["Comum", "Pequena e colada", "Grande", "De abano", "Lóbulo preso", "Pontuda", "Couve-flor",
	"Média colada", "Lóbulo grande", "Estreita e comprida", "Arredondada", "Levemente de abano"]
const CHIN_TYPES: Array[String] = ["Comum", "Partido", "Recuado", "Proeminente", "Pontudo", "Largo",
	"Partido largo", "Curto e redondo", "Quadrado marcado", "Pontudo e longo", "Recuado suave", "Proeminente e largo"]
const EXPRESSIONS: Array[String] = ["Neutro", "Sorriso leve", "Sorriso aberto", "Sério", "Bravo", "Confiante",
	"Surpreso", "Cansado", "Pensativo", "Desconfiado"]
## Grupo de traços por etnia: 0 europeu, 1 mediterrâneo/árabe, 2 latino/mestiço, 3 africano,
## 4 leste/sudeste asiático, 5 sul-asiático, 6 andino, 7 pacífico.
const ETH_GROUP: Array[int] = [0, 0, 1, 1, 2, 6, 2, 3, 4, 5, 3, 7, 4]
## Pesos dos tipos por grupo (mesma ordem de NOSE_TYPES, EYE_SHAPES, MOUTH_TYPES).
const GROUP_NOSE_W: Array = [
	[4, 1.4, 1.2, 1.0, 0.4, 1.6, 0.1, 1.0, 0.5, 0.5, 1.0, 1.0, 0.8, 0.1, 0.8, 0.6, 0.3, 0.6, 1.0, 0.5, 1.0, 0.8, 0.6, 0.5],
	[4, 0.6, 1.0, 2.2, 0.6, 0.8, 0.1, 1.2, 1.4, 0.5, 0.6, 1.4, 0.4, 0.2, 0.8, 0.8, 0.6, 0.5, 1.4, 0.3, 0.9, 0.7, 0.4, 0.5],
	[4, 1.0, 1.4, 0.8, 1.4, 0.7, 0.6, 0.5, 0.5, 0.5, 0.5, 0.6, 0.8, 0.8, 0.8, 0.7, 0.7, 1.0, 0.6, 0.7, 0.5, 1.0, 0.7, 0.5],
	[3, 0.6, 1.2, 0.1, 2.4, 0.3, 2.0, 0.1, 0.1, 0.5, 0.2, 0.2, 0.5, 2.4, 0.5, 0.3, 1.4, 1.4, 0.1, 1.0, 0.2, 1.0, 1.2, 0.4],
	[4, 1.0, 1.0, 0.1, 1.2, 0.5, 1.6, 0.2, 0.1, 0.3, 0.3, 0.2, 1.6, 0.8, 0.6, 0.3, 0.5, 1.2, 0.1, 0.9, 0.3, 0.9, 0.8, 0.4],
	[4, 0.6, 1.2, 1.4, 1.0, 0.8, 0.3, 0.8, 1.0, 0.4, 0.6, 1.2, 0.5, 0.6, 0.8, 0.8, 0.8, 0.7, 1.0, 0.5, 0.8, 0.8, 0.5, 0.5],
	[4, 0.5, 1.0, 2.0, 1.2, 0.4, 0.4, 0.4, 1.6, 0.4, 0.3, 1.2, 0.4, 0.6, 0.8, 0.9, 0.8, 0.8, 1.2, 0.4, 0.6, 0.8, 0.5, 0.5],
	[3, 0.6, 1.6, 0.2, 2.2, 0.2, 1.6, 0.1, 0.2, 0.5, 0.2, 0.3, 0.4, 1.6, 0.6, 0.4, 1.2, 1.2, 0.2, 0.9, 0.3, 1.0, 1.0, 0.4],
]
const GROUP_EYE_W: Array = [
	[4, 1.2, 1.2, 0.8, 0.5, 1.0, 0.6, 0.6, 1.2, 0.5, 0.7, 0.6, 0.4, 0.6, 1.4, 0.8, 1.0, 0.3, 1.0, 0.8, 0.7, 1.2],
	[4, 1.4, 0.8, 0.8, 0.6, 1.2, 0.6, 0.6, 1.2, 0.4, 0.5, 0.5, 0.8, 0.6, 1.6, 0.9, 1.0, 0.4, 1.0, 0.8, 0.6, 1.2],
	[4, 1.4, 1.0, 0.8, 0.8, 0.6, 0.6, 0.6, 0.8, 0.5, 0.6, 0.5, 0.6, 0.6, 1.6, 1.0, 1.0, 0.5, 0.9, 0.6, 0.7, 1.2],
	[4, 1.6, 0.8, 0.6, 0.6, 0.4, 0.8, 0.4, 0.6, 0.8, 0.5, 0.4, 0.5, 0.6, 1.6, 1.2, 0.9, 0.4, 0.8, 0.5, 0.8, 1.0],
	[2, 0.4, 2.0, 0.4, 2.4, 0.2, 0.8, 0.3, 1.4, 0.1, 1.2, 0.3, 1.2, 1.0, 0.6, 0.3, 0.6, 2.0, 1.2, 0.6, 0.3, 1.4],
	[4, 1.8, 0.6, 1.0, 0.6, 1.0, 0.5, 0.6, 1.2, 0.4, 0.4, 0.8, 0.6, 0.5, 1.8, 1.0, 1.0, 0.4, 1.0, 0.6, 0.6, 1.2],
	[3, 0.8, 1.4, 0.6, 1.4, 0.6, 0.6, 0.5, 1.2, 0.2, 0.8, 0.5, 0.8, 0.8, 1.2, 0.7, 0.9, 1.0, 1.0, 0.7, 0.5, 1.2],
	[3, 1.0, 1.4, 0.6, 1.2, 0.4, 0.6, 0.4, 1.0, 0.3, 0.8, 0.4, 0.6, 0.8, 1.2, 0.9, 0.9, 0.9, 1.0, 0.6, 0.6, 1.1],
]
const GROUP_MOUTH_W: Array = [
	[4, 1.6, 0.6, 0.8, 1.0, 0.8, 0.8, 0.8, 1.0, 0.2, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[4, 1.0, 1.0, 0.8, 0.8, 1.0, 0.8, 1.0, 0.6, 0.5, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[4, 0.8, 1.4, 1.0, 0.6, 1.2, 0.6, 0.8, 0.5, 0.8, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[3, 0.3, 2.0, 1.2, 0.3, 1.4, 0.5, 0.6, 0.2, 2.0, 1.2, 1.4, 0.6, 0.8, 0.3, 0.3, 0.6, 0.6],
	[4, 0.8, 0.8, 0.6, 1.4, 1.0, 0.8, 0.6, 0.8, 0.3, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[4, 0.8, 1.2, 1.0, 0.6, 1.2, 0.6, 1.0, 0.5, 0.6, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[4, 1.0, 1.0, 1.0, 0.8, 1.0, 1.0, 0.6, 0.8, 0.4, 0.8, 0.8, 0.6, 0.6, 0.8, 0.8, 0.6, 0.8],
	[3, 0.4, 1.8, 1.2, 0.4, 1.4, 0.5, 0.6, 0.3, 1.6, 1.2, 1.4, 0.6, 0.8, 0.3, 0.3, 0.6, 0.6],
]
const TATTOOS: Array[String] = ["Sem tatuagem", "Escrita", "Tribal", "Estrela", "Asas", "Rosa", "Cruz", "Coroa", "Números romanos", "Terço", "Ramo de folhas", "Manga no ombro", "Nome do filho"]
const FACE_SHAPE_W: Array[float] = [4.0, 1.8, 2.2, 1.4, 1.1, 1.6, 0.7, 1.4, 1.2, 1.0, 0.9, 0.8, 1.0, 1.1, 0.8, 1.4, 1.3, 0.5]
const EYE_NAMES: Array[String] = ["Castanho-escuro", "Castanho", "Mel", "Verde", "Azul", "Cinza", "Quase preto",
	"Âmbar", "Avelã", "Azul-claro", "Azul-acinzentado", "Verde-acinzentado"]
const EYE_COLORS: Array[Color] = [Color("#2E1C12"), Color("#58381F"), Color("#8A6A36"), Color("#57804D"), Color("#4A7DB4"),
	Color("#7C8B97"), Color("#1B120D"), Color("#9C6620"), Color("#6D6636"), Color("#7AA6CF"), Color("#5E7D93"), Color("#6E8672")]
## Olhos claros costumam ter um anel castanho/âmbar em volta da pupila.
const EYE_LIGHT: Array[int] = [2, 3, 4, 5, 8, 9, 10, 11]

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
	[0.3, 1.5, 1.6, 1.3, 1.3, 1.3, 0.4, 0.03, 0.2, 0.9, 0.0, 0.0, 0.25, 0.004],
	[0.8, 2.2, 1.7, 0.8, 0.5, 0.3, 0.12, 0.03, 0.25, 0.3, 0.0, 0.01, 0.3, 0.006],
	[2.0, 2.2, 1.0, 0.3, 0.1, 0.05, 0.05, 0.03, 0.15, 0.03, 0.1, 0.02, 0.15, 0.008],
	[3.0, 1.6, 0.4, 0.1, 0.0, 0.0, 0.03, 0.03, 0.1, 0.0, 0.3, 0.02, 0.05, 0.006],
	[2.5, 2.0, 0.6, 0.2, 0.08, 0.04, 0.03, 0.06, 0.12, 0.0, 0.2, 0.08, 0.2, 0.01],
	[4.0, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.03, 0.0, 0.0, 0.8, 0.02, 0.03, 0.003],
	[3.0, 1.5, 0.4, 0.1, 0.05, 0.0, 0.02, 0.08, 0.05, 0.0, 0.3, 0.2, 0.25, 0.012],
	[5.0, 0.8, 0.1, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.3, 0.25, 0.04, 0.012],
	[3.0, 1.4, 0.3, 0.05, 0.0, 0.0, 0.0, 0.06, 0.1, 0.0, 1.8, 0.05, 0.02, 0.012],
	[3.5, 1.4, 0.2, 0.0, 0.0, 0.0, 0.0, 0.02, 0.1, 0.0, 1.0, 0.02, 0.02, 0.004],
	[4.5, 1.2, 0.1, 0.0, 0.0, 0.0, 0.0, 0.05, 0.0, 0.0, 0.3, 0.1, 0.03, 0.01],
	[3.5, 1.5, 0.3, 0.05, 0.02, 0.0, 0.02, 0.04, 0.05, 0.0, 0.4, 0.1, 0.08, 0.008],
	[3.5, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.05, 0.05, 0.0, 1.2, 0.05, 0.03, 0.01],
]
## Pesos por etnia: [castanho-escuro, castanho, mel, verde, azul, cinza, quase preto, âmbar, avelã,
## azul-claro, azul-acinzentado, verde-acinzentado].
const ETH_EYES: Array = [
	[0.5, 1.0, 0.8, 1.0, 2.2, 1.0, 0.0, 0.1, 0.8, 1.6, 1.4, 0.8],
	[1.5, 2.0, 1.0, 0.8, 1.0, 0.5, 0.1, 0.2, 1.0, 0.5, 0.6, 0.5],
	[2.0, 2.0, 0.9, 0.4, 0.3, 0.1, 0.3, 0.3, 0.8, 0.1, 0.15, 0.2],
	[3.0, 2.0, 0.6, 0.25, 0.05, 0.02, 0.8, 0.3, 0.5, 0.02, 0.05, 0.1],
	[3.0, 2.0, 0.5, 0.15, 0.1, 0.02, 0.6, 0.3, 0.4, 0.03, 0.05, 0.05],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0, 1.5, 0.05, 0.02, 0.0, 0.0, 0.0],
	[4.0, 2.0, 0.4, 0.12, 0.05, 0.0, 1.0, 0.25, 0.3, 0.02, 0.03, 0.05],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0, 2.5, 0.05, 0.0, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0, 2.5, 0.02, 0.0, 0.0, 0.0, 0.0],
	[4.0, 1.6, 0.4, 0.08, 0.0, 0.0, 1.5, 0.2, 0.3, 0.0, 0.0, 0.05],
	[5.0, 1.0, 0.1, 0.0, 0.0, 0.0, 2.0, 0.05, 0.02, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0, 2.0, 0.05, 0.0, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0, 2.0, 0.05, 0.0, 0.0, 0.0, 0.0],
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
const ETH_BEARD_GENE: Array[float] = [0.75, 0.8, 0.9, 0.95, 0.7, 0.35, 0.62, 0.55, 0.16, 0.88, 0.45, 0.55, 0.18]
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
	# Extremos da escala (porcelana, retinto) num sorteio à parte: quem já existia não muda de tom
	var skx := RandomNumberGenerator.new()
	skx.seed = hash([seed_value, "pele"])
	var ext_roll := skx.randf()
	var ext_amt := skx.randf()
	if sk <= float(rg[0]) + 0.6 and float(rg[0]) <= 1.0 and ext_roll < 0.35:
		sk -= ext_amt * 1.0 # porcelana (nórdicos, europeus, leste asiático claro)
	elif sk >= 7.6 and ext_roll < 0.45:
		sk += ext_amt * (float(rg[1]) - 7.0) # retinto (África, Pacífico)
	elif ext_roll > 0.9:
		sk += (ext_amt - 0.5) * 0.8 # um pouco fora da faixa típica, para mais variedade
	sk = clampf(sk, SKIN_MIN, SKIN_MAX)
	if look.has("sk"):
		sk = clampf(float(look["sk"]), SKIN_MIN, SKIN_MAX)
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
	# Atletas: a maioria tem rosto de peso normal (nem chupado nem cheio)
	f["fat"] = clampf(rng.randf_range(0.05, 0.4) + youth * 0.1 + aging * 0.12, 0.0, 1.0)
	f["cheekbone"] = rng.randf_range(0.6, 1.2) * float(ETH_CHEEK[e])
	f["ridge"] = rng.randf_range(0.6, 1.2) * float(ETH_RIDGE[e]) * (1.0 - youth * 0.4)
	f["ear"] = rng.randf_range(0.88, 1.12) + aging * 0.06
	f["ear_out"] = rng.randf_range(0.0, 1.0) * (1.0 if rng.randf() < 0.35 else 0.4)
	# Beleza: harmonia, simetria e pele. Não depende da etnia; muda proporções mais adiante.
	var brng := RandomNumberGenerator.new()
	brng.seed = hash([seed_value, "beleza"])
	var beauty := clampf((brng.randf() + brng.randf() + brng.randf()) / 3.0 * 1.3 - 0.15, 0.0, 1.0)
	# Caudas: uma parte das pessoas é bonita de verdade e outra feia de verdade
	var tail := brng.randf()
	if tail < 0.09:
		beauty = brng.randf_range(0.86, 1.0)
	elif tail < 0.18:
		beauty = brng.randf_range(0.0, 0.14)
	if look.has("bt"):
		beauty = clampf(float(look["bt"]), 0.0, 1.0)
	var ugly := 1.0 - beauty
	f["beauty"] = beauty
	f["asym"] = rng.randf_range(-1.0, 1.0) * (0.3 + ugly * 1.5)

	# --- Olhos ------------------------------------------------------------------
	var eye_i := RngUtil.weighted_index(rng, ETH_EYES[e])
	if look.has("ey"):
		eye_i = clampi(int(look["ey"]), 0, EYE_COLORS.size() - 1)
	f["eye_i"] = eye_i
	rng.randf()
	rng.randf() # mantém a sequência do sorteio
	# Cor dos olhos: pequena variação em torno do tom, anel central e, raramente, heterocromia
	var erng := RandomNumberGenerator.new()
	erng.seed = hash([seed_value, "olhos"])
	var ec := EYE_COLORS[eye_i]
	f["eye"] = Color.from_hsv(fposmod(ec.h + erng.randf_range(-0.02, 0.02), 1.0), clampf(ec.s * erng.randf_range(0.85, 1.15), 0.0, 1.0), clampf(ec.v * erng.randf_range(0.88, 1.12), 0.0, 1.0))
	var ring := 0.0
	if eye_i in EYE_LIGHT and erng.randf() < (0.7 if eye_i in [3, 8, 11] else 0.3):
		ring = erng.randf_range(0.35, 0.9)
	f["eye_ring"] = ring
	f["eye_in"] = Color("#8A5A26").lerp(Color("#B98A3A"), erng.randf())
	f["limbal"] = clampf(erng.randf_range(0.4, 1.0) - maxf(0.0, age - 28.0) * 0.02, 0.1, 1.0)
	var het := erng.randf()
	f["hetero"] = 1 if het < 0.004 else (2 if het < 0.014 else 0)
	if look.has("het"):
		f["hetero"] = clampi(int(look["het"]), 0, 2)
	var other := EYE_COLORS[[1, 4, 3, 2][erng.randi_range(0, 3)]]
	if other.is_equal_approx(ec):
		other = EYE_COLORS[1 if eye_i != 1 else 4]
	f["eye_b"] = other
	f["hetero_side"] = -1.0 if erng.randf() < 0.5 else 1.0
	f["hetero_ang"] = erng.randf_range(0.0, TAU)
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

	# --- Variedade: formato dos olhos e proporções (sorteio próprio) -----------
	var vrng := RandomNumberGenerator.new()
	vrng.seed = hash([seed_value, "variedade"])
	var eye_shape := RngUtil.weighted_index(vrng, GROUP_EYE_W[ETH_GROUP[e]])
	if look.has("es"):
		eye_shape = clampi(int(look["es"]), 0, EYE_SHAPES.size() - 1)
	f["eye_shape"] = eye_shape
	match eye_shape:
		1:
			f["eye_h"] = float(f["eye_h"]) * 1.2
			f["eye_w"] = float(f["eye_w"]) * 1.05
		2:
			f["eye_h"] = float(f["eye_h"]) * 0.8
			f["eye_w"] = float(f["eye_w"]) * 1.03
		3:
			f["eye_tilt"] = float(f["eye_tilt"]) - 0.035
		4:
			f["eye_tilt"] = float(f["eye_tilt"]) + 0.035
		5:
			f["deep"] = float(f["deep"]) * 1.35
			f["hooded"] = bool(f["hooded"]) or vrng.randf() < 0.5
		6:
			f["eye_dx"] = float(f["eye_dx"]) + 0.035
		7:
			f["eye_dx"] = float(f["eye_dx"]) - 0.03
		8: # encapuzado: a pálpebra de cima desce sobre o olho
			f["hooded"] = true
			f["lid"] = vrng.randf_range(0.25, 0.45)
		9: # saltado: olho grande, aparece branco embaixo
			f["eye_h"] = float(f["eye_h"]) * 1.12
			f["bulge"] = vrng.randf_range(0.5, 1.0)
		10: # pequenos
			f["eye_h"] = float(f["eye_h"]) * 0.82
			f["eye_w"] = float(f["eye_w"]) * 0.88
		11: # triste: canto de fora bem caído
			f["eye_tilt"] = float(f["eye_tilt"]) - 0.06
			f["lid"] = vrng.randf_range(0.1, 0.25)
		12: # felino: alongado e puxado para cima
			f["eye_w"] = float(f["eye_w"]) * 1.08
			f["eye_h"] = float(f["eye_h"]) * 0.86
			f["eye_tilt"] = float(f["eye_tilt"]) + 0.05
		13: # semicerrado
			f["lid"] = vrng.randf_range(0.35, 0.55)
		14: # amendoado grande
			f["eye_h"] = float(f["eye_h"]) * 1.1
			f["eye_w"] = float(f["eye_w"]) * 1.06
			f["eye_tilt"] = float(f["eye_tilt"]) + 0.015
		15: # redondo
			f["eye_h"] = float(f["eye_h"]) * 1.17
			f["eye_w"] = float(f["eye_w"]) * 0.96
		16: # levemente caído
			f["eye_tilt"] = float(f["eye_tilt"]) - 0.025
			f["lid"] = vrng.randf_range(0.06, 0.14)
		17: # estreito e puxado
			f["eye_h"] = float(f["eye_h"]) * 0.82
			f["eye_tilt"] = float(f["eye_tilt"]) + 0.045
		18: # pálpebra pesada
			f["hooded"] = true
			f["lid"] = vrng.randf_range(0.18, 0.3)
			f["eye_h"] = float(f["eye_h"]) * 0.95
		19: # fundo e pequeno
			f["deep"] = float(f["deep"]) * 1.3
			f["eye_h"] = float(f["eye_h"]) * 0.88
			f["eye_w"] = float(f["eye_w"]) * 0.93
		20: # abertos e afastados
			f["eye_dx"] = float(f["eye_dx"]) + 0.025
			f["eye_h"] = float(f["eye_h"]) * 1.07
		21: # amendoado fino
			f["eye_w"] = float(f["eye_w"]) * 1.07
			f["eye_h"] = float(f["eye_h"]) * 0.88
			f["eye_tilt"] = float(f["eye_tilt"]) + 0.02
	f["fw"] = float(f["fw"]) * vrng.randf_range(0.95, 1.06)
	f["fh"] = float(f["fh"]) * vrng.randf_range(0.965, 1.045)
	f["nose_w"] = float(f["nose_w"]) * vrng.randf_range(0.88, 1.16)
	f["nose_len"] = float(f["nose_len"]) * vrng.randf_range(0.92, 1.1)
	f["mouth_w"] = float(f["mouth_w"]) * vrng.randf_range(0.9, 1.1)
	var lipk := vrng.randf_range(0.85, 1.2)
	f["lip_u"] = float(f["lip_u"]) * lipk
	f["lip_l"] = float(f["lip_l"]) * lipk * vrng.randf_range(0.95, 1.08)
	f["brow_t"] = float(f["brow_t"]) * vrng.randf_range(0.82, 1.28)
	f["ear"] = float(f["ear"]) * vrng.randf_range(0.92, 1.1)

	# --- Cabelo -----------------------------------------------------------------
	var hc_i := RngUtil.weighted_index(rng, ETH_HAIR_COLOR[e])
	if hc_i == HC_TIPS and age > 30:
		hc_i = 0
	if hc_i == HC_RED_DYE and age > 28:
		hc_i = 1
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
	# Os penteados antigos são sorteados como antes (o rosto de quem já existe não muda); os
	# acrescentados depois entram num sorteio à parte, na proporção do peso que têm.
	var sw_old := sw.slice(0, HS_V1)
	var base_style := RngUtil.weighted_index(rng, sw_old)
	var phase_rng := RandomNumberGenerator.new()
	var phase_off := rng.randi_range(0, 3)
	phase_rng.seed = hash([seed_value, int(floor((age + phase_off) / 4.0))])
	var style := base_style
	if phase_rng.randf() < 0.45:
		style = RngUtil.weighted_index(phase_rng, sw_old)
	style = _newer_pick(hash([seed_value, "hs2", int(floor((age + phase_off) / 4.0))]), sw, HS_V1, style)
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
	if style in [H_BLEACHED, H_BLEACH_DESIGN] and not look.has("hc"):
		hc_i = HC_PLATINUM
		f["hair_i"] = hc_i
	if STYLE_DYE.has(style) and not look.has("hc"):
		hc_i = int(STYLE_DYE[style])
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
	if not hc_i in DYED:
		hair = hair.lerp(Color("#C8C5C0"), gray * 0.72)
	if STYLE_DYE_COLOR.has(style) and not look.has("hc"):
		hair = Color(String(STYLE_DYE_COLOR[style]))
	f["hair"] = hair
	f["tips"] = hc_i == HC_TIPS
	f["hair_seed"] = rng.randi()
	# Riscos na sobrancelha, tatuagem no pescoço e luzes: sorteio próprio (não mexe no resto)
	var xrng := RandomNumberGenerator.new()
	xrng.seed = hash([seed_value, "estilo"])
	var slit_p := 0.07 * (1.8 if age < 25 else (1.0 if age < 31 else 0.3))
	if e in [E_AFR, E_MIX, E_LAT, E_HAE]:
		slit_p *= 1.6
	elif e in [E_EAS, E_SEA, E_NOR]:
		slit_p *= 0.5
	var slit := 0
	if xrng.randf() < slit_p:
		slit = 1 + RngUtil.weighted_index(xrng, [0.55, 0.35, 0.1]) + 10 * (1 + RngUtil.weighted_index(xrng, [0.45, 0.35, 0.2]))
	if look.has("sl"):
		slit = int(look["sl"])
	f["brow_slit"] = slit
	# Tatuagem visível no pescoço/ombro: comum no futebol de hoje (menos no leste asiático e no mundo árabe)
	var tat_p := 0.13 * (1.4 if age >= 21 and age <= 33 else 0.55)
	if e in [E_LAT, E_MIX, E_AFR, E_HAE, E_EUR, E_NOR, E_MED]:
		tat_p *= 1.3
	elif e in [E_EAS, E_SEA, E_ARB, E_SAS]:
		tat_p *= 0.45
	var tattoo := 1 + RngUtil.weighted_index(xrng, [0.16, 0.12, 0.1, 0.08, 0.1, 0.09, 0.07, 0.07, 0.06, 0.05, 0.06, 0.04]) if xrng.randf() < tat_p else 0
	if look.has("tt"):
		tattoo = clampi(int(look["tt"]), 0, TATTOOS.size() - 1)
	f["tattoo"] = tattoo
	f["tattoo_side"] = -1.0 if xrng.randf() < 0.5 else 1.0
	f["tattoo_seed"] = xrng.randi()
	var hl_p := 0.05 * (1.5 if age < 27 else 0.6) * (1.4 if e in [E_MIX, E_LAT, E_AFR] else 1.0)
	f["highlights"] = xrng.randf() < hl_p and hc_i in [0, 1, 2, 3, 10, HC_HONEY] and style not in [H_BALD, H_BUZZ, H_CORNROWS, H_WAVES]
	if style == H_FROSTED or style == H_FROSTED_CURLS or style == 178 or style == 181 or style == 187:
		f["tips"] = true
	if style == 190:
		f["highlights"] = true

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
		elif i in [B_FULL, B_LONG, B_SHORT, B_BOXED, B_HEAVY_STUBBLE, B_MEDIUM, B_FADED, B_DENSE_STUBBLE, B_GARIBALDI,
				B_LUMBERJACK, B_SQUARE, B_LINE_CUT, B_HOLLYWOOD, B_TRIMMED, B_POINTED, B_WEEK, B_VERDI, B_BANDHOLZ,
				B_SHORT_THICK_MU, B_THICK_LINED, B_LONG_ANCHOR, B_ROUNDED, B_SHORT_SHARP, B_LONG_BOX, B_SCRUFFY,
				B_LONG_FADE, B_MEDIUM_CUT, B_FORKED, B_LONG_HANDLEBAR, B_LOW_LINE, B_HIGH_LINE, B_WEEK_THICK_MU,
				81, 82, 83, 84, 85, 92, 93, 96, 97, 100, 101, 103]:
			w *= 2.0 if pref > 0.75 else (0.4 if pref < 0.3 else 1.0)
		if i == B_PATCHY:
			w *= 3.0 if cap < 0.6 else 0.3
		if i == B_WISPY or i == B_PEACH:
			w *= 3.0 if cap < 0.35 else 0.1
		if (e == E_EAS or e == E_SEA) and i in [B_FULL, B_LONG, B_MUTTON, B_VERDI, B_BANDHOLZ, B_WALRUS, B_SCRUFFY, B_FORKED, B_LONG_BOX]:
			w *= 0.3
		if i == B_CHIN_PUFF:
			w *= 2.0 if cap < 0.55 else 0.4
		if age >= 30 and i in [B_WALRUS, B_HANDLEBAR, B_VERDI, B_WALRUS_SHORT, B_HANDLEBAR_BEARD, B_FORKED]:
			w *= 1.6
		if (e == E_ARB or e == E_SAS) and i in [B_FULL, B_SHORT, B_BOXED, B_CURTAIN, B_MEDIUM, B_FADED, B_ROUNDED,
				B_SHORT_SHARP, B_MEDIUM_CUT]:
			w *= 1.8
		if age >= 33 and i in [B_FULL, B_SHORT, B_HEAVY_STUBBLE]:
			w *= 1.4
		w *= _beard_realism()[i]
		if i in CURLY_BEARDS:
			w *= 2.2 if tex >= T_CURLY else 0.08
		if (e == E_EAS or e == E_SEA) and i != B_NONE and i not in [B_WISPY, B_PEACH, B_STUBBLE]:
			w *= 0.4 # leste e sudeste asiático: barba rala e pouco comum no futebol
		bw.append(w)
	var beard := RngUtil.weighted_index(phase_rng, bw.slice(0, BD_V1))
	if beard < 0:
		beard = B_NONE
	beard = _newer_pick(hash([seed_value, "bd2", int(floor((age + phase_off) / 4.0))]), bw, BD_V1, beard)
	if look.has("bd"):
		beard = clampi(int(look["bd"]), 0, BEARDS.size() - 1)
	f["beard"] = beard
	# Barba rala de verdade quando a genética é fraca
	f["beard_patch"] = clampf(0.75 - cap, 0.0, 0.7) if not look.has("bd") else clampf(0.75 - cap, 0.0, 0.15)
	f["beard_seed"] = rng.randi()
	# Sombra da barba feita (quem tem barba forte e cabelo escuro)
	var dark_hair := 1.0 - clampf(HAIR_COLORS[hc_i if hc_i != HC_TIPS else 0].v * 1.6, 0.0, 0.8)
	f["shadow"] = cap * dark_hair * rng.randf_range(0.25, 0.7) if beard == B_NONE else cap * dark_hair * 0.35
	var natural := hc_i
	if hc_i in DYED:
		natural = 4 if e <= E_EUR and xrng.randf() < 0.3 else 1
	elif hc_i == HC_TIPS:
		natural = 0
	var beard_col := HAIR_COLORS[natural].darkened(0.06)
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
	f["headband"] = (style in [H_LONG, H_DREADS, H_CURLY, H_AFRO, H_SURFER, H_LONG_CURLY, H_BRAIDS, H_BIG_AFRO, H_LONG_FRINGE]) and rng.randf() < 0.2
	rng.randi_range(0, 2) # mantém a sequência do sorteio
	# Corpo: pescoço, ombros e gola vêm de um sorteio próprio
	var body_rng := RandomNumberGenerator.new()
	body_rng.seed = hash([seed_value, "corpo"])
	f["build"] = clampf(body_rng.randf_range(0.2, 0.9) + float(f["fat"]) * 0.15 - youth * 0.25, 0.0, 1.0)
	f["neck_w"] = body_rng.randf_range(0.6, 0.76) + float(f["build"]) * 0.06 - youth * 0.05
	f["collar"] = RngUtil.weighted_index(body_rng, [3.0, 4.0, 2.0, 1.0])
	f["texture_seed"] = rng.randi()
	var srng := RandomNumberGenerator.new()
	srng.seed = hash([seed_value, "formato"])
	_apply_shape(f, srng, look)
	_apply_beauty(f, beauty, brng)
	_apply_mass(f, seed_value, age, look)
	_apply_aging(f, seed_value, age)
	_apply_expression(f, seed_value, age, look)
	_proportion_floor(f)
	return f


## Cabeça humana tem proporção: os ajustes (magro, rosto estreito, alongado, etnia) somados
## deixavam alguns rostos finos demais. Largura mínima de ~73% da altura (rosto real fica
## entre ~0,75 e 0,9) e mandíbula e maçãs sem afinar além do plausível.
static func _proportion_floor(f: Dictionary) -> void:
	var fh := float(f["fh"])
	f["fw"] = clampf(float(f["fw"]), fh * 0.76, fh * 0.88)
	f["jaw"] = clampf(float(f["jaw"]), 0.72, 0.95)
	f["fat"] = clampf(float(f["fat"]), 0.0, 0.7)
	f["cheek_w"] = maxf(float(f["cheek_w"]), 0.97)


## Corpo: a maioria é atleta, mas há rostos muito finos (chupados, maçãs saltadas) e gordos
## (bochechas cheias, papada, pescoço largo). Com a idade (técnicos, dirigentes) engordar é comum.
static func _apply_mass(f: Dictionary, seed_value: int, age: int, look: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "massa"])
	var older := clampf((age - 28.0) / 24.0, 0.0, 1.0)
	# Rostos normais na grande maioria: magro ou cheio aparece pouco e sem exagero
	var p_thin := 0.04 - older * 0.02
	var p_heavy := 0.03 + older * 0.14
	var roll := r.randf()
	var thin := 0.0
	var heavy := 0.0
	if roll < p_thin:
		thin = r.randf_range(0.25, 0.5)
	elif roll < p_thin + p_heavy:
		heavy = r.randf_range(0.2, 0.55)
	elif r.randf() < 0.35:
		thin = r.randf_range(0.0, 0.18)
	var good := smoothstep(0.55, 1.0, float(f["beauty"]))
	heavy *= 1.0 - good * 0.5
	if look.has("ms"):
		var m := clampf(float(look["ms"]), -1.0, 1.0)
		thin = maxf(0.0, -m)
		heavy = maxf(0.0, m)
	f["thin"] = thin
	f["heavy"] = heavy
	f["fat"] = clampf(float(f["fat"]) * (1.0 - thin) + heavy * 0.85, 0.0, 1.0)
	f["fw"] = float(f["fw"]) * (1.0 - thin * 0.07) * (1.0 + heavy * 0.2)
	f["fh"] = float(f["fh"]) * (1.0 + heavy * 0.04) * (1.0 + thin * 0.02)
	f["cheekbone"] = float(f["cheekbone"]) * (1.0 + thin * 0.35) * (1.0 - heavy * 0.4)
	f["jaw"] = lerpf(float(f["jaw"]), 0.96, heavy * 0.6) - thin * 0.04
	f["chin_sq"] = lerpf(float(f["chin_sq"]), 1.3, heavy * 0.5)
	f["jaw_v"] = float(f["jaw_v"]) + heavy * 0.06
	f["eye_h"] = float(f["eye_h"]) * (1.0 - heavy * 0.12)
	f["neck_w"] = float(f["neck_w"]) + heavy * 0.14 - thin * 0.06
	f["build"] = clampf(float(f["build"]) + heavy * 0.3 - thin * 0.3, 0.0, 1.0)


## Envelhecimento: cada pessoa tem uma "genética de pele" (envelhece bem ou mal) e sol na conta.
## Rugas, bolsas sob os olhos, papada lateral (buldogue), têmporas fundas, manchas, nariz e orelhas
## maiores, lábios mais finos e pele menos viçosa.
static func _apply_aging(f: Dictionary, seed_value: int, age: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "velhice"])
	var gene := r.randf_range(0.7, 1.35)
	var sun := r.randf()
	f["age_gene"] = gene
	var onset := 27.0 + (1.35 - gene) * 8.0
	f["wrinkles"] = clampf((age - onset) / 13.0 * gene, 0.0, 1.5)
	f["jowl"] = clampf((age - 38.0) / 16.0 * gene, 0.0, 1.4)
	f["eyebags"] = clampf((age - 30.0) / 16.0 * gene, 0.0, 1.4)
	f["temple"] = clampf((age - 44.0) / 24.0, 0.0, 1.0) * (1.0 - float(f["fat"]) * 0.6)
	f["age_spots"] = clampf((age - 44.0) / 20.0, 0.0, 1.0) * (0.3 + sun * 0.7)
	f["spot_seed"] = r.randi()
	var old := clampf((age - 40.0) / 30.0, 0.0, 1.0)
	f["nose_len"] = float(f["nose_len"]) * (1.0 + old * 0.1)
	f["nose_w"] = float(f["nose_w"]) * (1.0 + old * 0.06)
	f["lip_u"] = float(f["lip_u"]) * (1.0 - old * 0.35)
	f["lip_l"] = float(f["lip_l"]) * (1.0 - old * 0.2)
	# Com a idade o rosto "desce": cantos da boca caem, queixo alonga, olhos ficam menores
	f["corner"] = float(f.get("corner", 0.0)) + old * gene * 0.5
	f["chin_len"] = float(f.get("chin_len", 0.0)) + old * 0.04
	f["eye_h"] = float(f["eye_h"]) * (1.0 - old * 0.12)
	f["brow_dens"] = clampf(float(f["brow_dens"]) + old * 0.15, 0.0, 1.0)
	if age > 52 and r.randf() < 0.45:
		f["brow_messy"] = 1.0
	if old > 0.0:
		var sk: Color = f["skin"]
		f["skin"] = Color.from_hsv(sk.h, sk.s * (1.0 - old * 0.14), sk.v * (1.0 - old * 0.03))
		f["hooded"] = bool(f["hooded"]) or r.randf() < old
		f["lid"] = maxf(float(f.get("lid", 0.0)), old * gene * 0.25)


## Expressão do retrato (de ficha): quase sempre neutra ou um sorriso, às vezes séria, brava,
## confiante… Muda de tempos em tempos, como uma foto nova a cada fase da carreira.
static func _apply_expression(f: Dictionary, seed_value: int, age: int, look: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "expressao", int(age / 3)])
	var ex := RngUtil.weighted_index(r, [4.0, 3.2, 1.0, 2.0, 0.5, 1.3, 0.2, 0.4, 0.6, 0.5])
	if look.has("ex"):
		ex = clampi(int(look["ex"]), 0, EXPRESSIONS.size() - 1)
	f["expr"] = ex
	var side := -1.0 if r.randf() < 0.5 else 1.0
	var sm: float = f["smile"]
	f["teeth"] = 0.0
	f["brow_raise"] = 0.0
	f["brow_in"] = 0.0
	f["smirk"] = 0.0
	f["squint"] = 0.0
	f["mouth_open"] = 0.0
	f["brow_uneven"] = 0.0
	match ex:
		0:
			f["smile"] = clampf(sm, -0.2, 0.35)
		1:
			f["smile"] = r.randf_range(0.8, 1.05)
			f["squint"] = 0.2
		2:
			f["smile"] = r.randf_range(1.25, 1.5)
			f["teeth"] = 1.0
			f["squint"] = 0.45
		3:
			f["smile"] = r.randf_range(-0.4, -0.15)
			f["brow_in"] = 0.35
		4:
			f["smile"] = -0.55
			f["brow_in"] = 1.0
			f["brow_raise"] = -0.5
			f["squint"] = 0.3
		5:
			f["smile"] = 0.35
			f["smirk"] = side * r.randf_range(0.6, 1.0)
			f["squint"] = 0.15
		6:
			f["smile"] = 0.0
			f["brow_raise"] = 1.0
			f["mouth_open"] = r.randf_range(0.4, 0.7)
			f["lid"] = 0.0
			f["bulge"] = maxf(float(f.get("bulge", 0.0)), 0.4)
		7:
			f["smile"] = -0.2
			f["lid"] = maxf(float(f.get("lid", 0.0)), 0.4)
			f["brow_in"] = -0.5
			f["dark_circles"] = maxf(float(f.get("dark_circles", 0.0)), 0.6)
		8:
			f["smile"] = 0.1
			f["smirk"] = side * 0.35
			f["brow_in"] = 0.3
			f["gaze"] = side * 0.5
		9:
			f["smile"] = -0.1
			f["squint"] = 0.5
			f["brow_uneven"] = side
			f["smirk"] = -side * 0.3


## Formato do rosto, do nariz, das sobrancelhas e dos lábios: tipos bem distintos por cima das
## medidas contínuas, para que dois jogadores da mesma etnia não pareçam irmãos.
static func _apply_shape(f: Dictionary, r: RandomNumberGenerator, look: Dictionary) -> void:
	var e: int = f["eth"]
	var g: int = ETH_GROUP[e]
	var shape := RngUtil.weighted_index(r, FACE_SHAPE_W)
	if look.has("fs"):
		shape = clampi(int(look["fs"]), 0, FACE_SHAPES.size() - 1)
	f["face_shape"] = shape
	match shape:
		1: # redondo
			f["cheek_w"] = float(f["cheek_w"]) * 1.03
			f["jaw"] = maxf(float(f["jaw"]), 0.84) + r.randf_range(0.02, 0.06)
			f["jaw_v"] = r.randf_range(0.46, 0.54)
			f["chin_sq"] = r.randf_range(1.25, 1.45)
			f["fh"] = float(f["fh"]) * 0.95
			f["fat"] = clampf(float(f["fat"]) + 0.12, 0.0, 1.0)
		2: # quadrado
			f["jaw"] = r.randf_range(0.9, 0.96)
			f["jaw_v"] = r.randf_range(0.6, 0.7)
			f["chin_sq"] = r.randf_range(2.4, 3.2)
			f["forehead"] = r.randf_range(0.96, 1.0)
		3: # coração
			f["forehead"] = r.randf_range(0.99, 1.02)
			f["jaw"] = r.randf_range(0.63, 0.7)
			f["chin_sq"] = r.randf_range(1.15, 1.35)
			f["cheekbone"] = float(f["cheekbone"]) * 1.1
		4: # losango
			f["forehead"] = r.randf_range(0.84, 0.88)
			f["cheek_w"] = float(f["cheek_w"]) * 1.04
			f["jaw"] = r.randf_range(0.67, 0.74)
			f["chin_sq"] = r.randf_range(1.3, 1.5)
			f["cheekbone"] = float(f["cheekbone"]) * 1.25
		5: # alongado
			f["fh"] = float(f["fh"]) * 1.07
			f["fw"] = float(f["fw"]) * 0.95
			f["jaw"] = r.randf_range(0.76, 0.84)
			f["chin_sq"] = r.randf_range(1.6, 2.0)
		6: # triangular
			f["forehead"] = r.randf_range(0.84, 0.88)
			f["jaw"] = r.randf_range(0.92, 0.98)
			f["jaw_v"] = r.randf_range(0.6, 0.66)
		7: # retangular
			f["fh"] = float(f["fh"]) * 1.06
			f["fw"] = float(f["fw"]) * 0.97
			f["jaw"] = r.randf_range(0.88, 0.94)
			f["chin_sq"] = r.randf_range(2.2, 2.8)
			f["forehead"] = r.randf_range(0.96, 0.99)
		8: # estreito
			f["fw"] = float(f["fw"]) * 0.95
			f["fh"] = float(f["fh"]) * 1.03
			f["jaw"] = r.randf_range(0.66, 0.76)
			f["cheek_w"] = float(f["cheek_w"]) * 0.97
		9: # largo
			f["fw"] = float(f["fw"]) * 1.09
			f["fh"] = float(f["fh"]) * 0.97
			f["jaw"] = r.randf_range(0.86, 0.95)
			f["chin_sq"] = r.randf_range(1.6, 2.3)
		10: # queixo forte
			f["chin_len"] = r.randf_range(0.04, 0.07)
			f["chin_sq"] = r.randf_range(2.2, 3.0)
			f["jaw"] = r.randf_range(0.82, 0.92)
		11: # queixo recuado
			f["chin_len"] = -r.randf_range(0.04, 0.07)
			f["chin_sq"] = r.randf_range(1.1, 1.35)
			f["jaw"] = r.randf_range(0.66, 0.74)
		12: # maçãs altas
			f["cheekbone"] = float(f["cheekbone"]) * 1.3
			f["jaw"] = r.randf_range(0.72, 0.8)
		13: # mandíbula marcada
			f["jaw"] = r.randf_range(0.88, 0.95)
			f["jaw_v"] = r.randf_range(0.62, 0.7)
			f["chin_sq"] = r.randf_range(1.9, 2.5)
			f["fat"] = clampf(float(f["fat"]) - 0.08, 0.0, 1.0)
		14: # rosto curto
			f["fh"] = float(f["fh"]) * 0.95
			f["jaw"] = r.randf_range(0.8, 0.88)
		15: # oval largo
			f["fw"] = float(f["fw"]) * 1.04
			f["jaw"] = r.randf_range(0.78, 0.85)
		16: # oval estreito
			f["fw"] = float(f["fw"]) * 0.97
			f["fh"] = float(f["fh"]) * 1.02
			f["jaw"] = r.randf_range(0.72, 0.8)
		17: # pera: testa estreita, mandíbula cheia
			f["forehead"] = r.randf_range(0.86, 0.9)
			f["jaw"] = r.randf_range(0.9, 0.96)
			f["fat"] = clampf(float(f["fat"]) + 0.06, 0.0, 1.0)
	var nose := RngUtil.weighted_index(r, GROUP_NOSE_W[g])
	if look.has("ns"):
		nose = clampi(int(look["ns"]), 0, NOSE_TYPES.size() - 1)
	f["nose_type"] = nose
	match nose:
		1: # arrebitado
			f["nose_len"] = float(f["nose_len"]) * 0.88
			f["nose_tip"] = float(f["nose_tip"]) * 0.9
		2: # batatudo
			f["nose_tip"] = float(f["nose_tip"]) * 1.4
			f["nose_w"] = float(f["nose_w"]) * 1.08
		3: # aquilino
			f["aquiline"] = true
			f["nose_len"] = float(f["nose_len"]) * 1.05
		4: # largo
			f["nose_w"] = float(f["nose_w"]) * 1.16
			f["bridge_w"] = float(f["bridge_w"]) * 1.2
		5: # fino
			f["nose_w"] = float(f["nose_w"]) * 0.87
			f["bridge_w"] = float(f["bridge_w"]) * 0.85
			f["bridge"] = float(f["bridge"]) * 1.1
		6: # achatado: dorso baixo e largo, asas abertas
			f["bridge"] = float(f["bridge"]) * 0.55
			f["nose_w"] = float(f["nose_w"]) * 1.14
			f["nose_len"] = float(f["nose_len"]) * 0.92
			f["nostril"] = 1.3
		7: # grego: dorso reto e longo, contínuo com a testa
			f["bridge"] = float(f["bridge"]) * 1.25
			f["nose_len"] = float(f["nose_len"]) * 1.06
			f["bridge_w"] = float(f["bridge_w"]) * 0.9
		8: # adunco: ponta caída e dorso em curva
			f["aquiline"] = true
			f["nose_len"] = float(f["nose_len"]) * 1.1
			f["nose_hook"] = r.randf_range(0.5, 1.0)
		9: # quebrado: torto e com calombo
			f["aquiline"] = true
			f["nose_dx_t"] = r.randf_range(0.04, 0.09) * (1.0 if r.randf() < 0.5 else -1.0)
			f["nose_w"] = float(f["nose_w"]) * 1.06
		10: # pontudo
			f["nose_tip"] = float(f["nose_tip"]) * 0.75
			f["nose_w"] = float(f["nose_w"]) * 0.92
			f["nose_up"] = 0.4
		11: # comprido
			f["nose_len"] = float(f["nose_len"]) * 1.16
		12: # pequeno
			f["nose_len"] = float(f["nose_len"]) * 0.86
			f["nose_w"] = float(f["nose_w"]) * 0.9
			f["nose_tip"] = float(f["nose_tip"]) * 0.9
		13: # narinas largas
			f["nose_w"] = float(f["nose_w"]) * 1.22
			f["nostril"] = 1.5
			f["nose_up"] = 0.3
		14: # dorso largo
			f["bridge_w"] = float(f["bridge_w"]) * 1.3
			f["bridge"] = float(f["bridge"]) * 1.05
			f["nose_w"] = float(f["nose_w"]) * 1.05
		15: # ponta caída
			f["nose_hook"] = r.randf_range(0.25, 0.45)
			f["nose_tip"] = float(f["nose_tip"]) * 1.1
			f["nose_len"] = float(f["nose_len"]) * 1.05
		16: # largo e alto
			f["nose_w"] = float(f["nose_w"]) * 1.15
			f["bridge"] = float(f["bridge"]) * 1.2
			f["nose_len"] = float(f["nose_len"]) * 1.05
		17: # curto e largo
			f["nose_len"] = float(f["nose_len"]) * 0.86
			f["nose_w"] = float(f["nose_w"]) * 1.12
			f["nostril"] = 1.2
		18: # romano: dorso alto com curva suave
			f["aquiline"] = true
			f["bridge"] = float(f["bridge"]) * 1.2
			f["nose_len"] = float(f["nose_len"]) * 1.07
		19: # arrebitado largo
			f["nose_up"] = 0.35
			f["nose_w"] = float(f["nose_w"]) * 1.1
			f["nose_len"] = float(f["nose_len"]) * 0.9
		20: # estreito e comprido
			f["nose_w"] = float(f["nose_w"]) * 0.87
			f["nose_len"] = float(f["nose_len"]) * 1.13
			f["bridge_w"] = float(f["bridge_w"]) * 0.86
		21: # ponta redonda
			f["nose_tip"] = float(f["nose_tip"]) * 1.25
			f["nose_w"] = float(f["nose_w"]) * 0.97
		22: # asas altas
			f["nostril"] = 1.25
			f["nose_up"] = 0.2
			f["nose_tip"] = float(f["nose_tip"]) * 0.9
		23: # levemente torto
			f["nose_dx_t"] = r.randf_range(0.02, 0.04) * (1.0 if r.randf() < 0.5 else -1.0)
	var brow := RngUtil.weighted_index(r, [3.0, 2.0, 1.5, 1.2, 0.8, 0.6, 0.9, 0.7, 0.7, 0.7, 0.5, 0.5,
		1.4, 0.9, 0.8, 0.7, 0.7, 0.8, 0.6, 0.8, 0.6, 0.5])
	if look.has("bw"):
		brow = clampi(int(look["bw"]), 0, BROW_TYPES.size() - 1)
	f["brow_type"] = brow
	match brow:
		1: # reta
			f["brow_arch"] = r.randf_range(0.0, 0.01)
			f["brow_tilt"] = r.randf_range(-0.01, 0.01)
		2: # arqueada
			f["brow_arch"] = r.randf_range(0.06, 0.085)
		3: # grossa
			f["brow_t"] = float(f["brow_t"]) * 1.3
			f["brow_dens"] = 1.0
		4: # fina
			f["brow_t"] = float(f["brow_t"]) * 0.75
		5: # caída
			f["brow_tilt"] = -0.04
		6: # reta e grossa
			f["brow_arch"] = r.randf_range(0.0, 0.012)
			f["brow_t"] = float(f["brow_t"]) * 1.35
			f["brow_dens"] = 1.0
		7: # rala
			f["brow_dens"] = r.randf_range(0.3, 0.45)
			f["brow_t"] = float(f["brow_t"]) * 0.85
		8: # angulosa: pico marcado
			f["brow_arch"] = r.randf_range(0.06, 0.09)
			f["brow_peak"] = 1.0
		9: # baixa e pesada
			f["brow_gap"] = float(f["brow_gap"]) - 0.035
			f["brow_t"] = float(f["brow_t"]) * 1.2
			f["deep"] = float(f["deep"]) * 1.2
		10: # alta
			f["brow_gap"] = float(f["brow_gap"]) + 0.04
			f["brow_arch"] = maxf(float(f["brow_arch"]), 0.04)
		11: # desgrenhada
			f["brow_t"] = float(f["brow_t"]) * 1.2
			f["brow_messy"] = 1.0
		12: # curva suave
			f["brow_arch"] = r.randf_range(0.03, 0.045)
		13: # grossa arqueada
			f["brow_t"] = float(f["brow_t"]) * 1.3
			f["brow_arch"] = r.randf_range(0.05, 0.07)
			f["brow_dens"] = 1.0
		14: # fina e reta
			f["brow_t"] = float(f["brow_t"]) * 0.75
			f["brow_arch"] = r.randf_range(0.0, 0.012)
		15: # curta
			f["brow_len"] = r.randf_range(0.36, 0.4)
		16: # longa
			f["brow_len"] = r.randf_range(0.5, 0.55)
		17: # cheia e baixa
			f["brow_gap"] = float(f["brow_gap"]) - 0.02
			f["brow_t"] = float(f["brow_t"]) * 1.15
			f["brow_dens"] = maxf(float(f["brow_dens"]), 0.9)
		18: # caída e grossa
			f["brow_tilt"] = -0.03
			f["brow_t"] = float(f["brow_t"]) * 1.25
		19: # pico suave
			f["brow_arch"] = r.randf_range(0.045, 0.06)
			f["brow_peak"] = 0.5
		20: # levantada
			f["brow_gap"] = float(f["brow_gap"]) + 0.025
			f["brow_tilt"] = float(f["brow_tilt"]) + 0.02
		21: # espessa e irregular
			f["brow_t"] = float(f["brow_t"]) * 1.15
			f["brow_messy"] = 0.5
	var mouth := RngUtil.weighted_index(r, GROUP_MOUTH_W[g])
	if look.has("mt"):
		mouth = clampi(int(look["mt"]), 0, MOUTH_TYPES.size() - 1)
	f["mouth_type"] = mouth
	match mouth:
		1: # lábio de cima fino
			f["lip_u"] = float(f["lip_u"]) * 0.75
		2: # lábios cheios
			f["lip_u"] = float(f["lip_u"]) * 1.15
			f["lip_l"] = float(f["lip_l"]) * 1.12
		3: # boca larga
			f["mouth_w"] = float(f["mouth_w"]) * 1.1
		4: # boca pequena
			f["mouth_w"] = float(f["mouth_w"]) * 0.86
		5: # lábio de baixo carnudo
			f["lip_l"] = float(f["lip_l"]) * 1.25
		6: # cantos caídos
			f["corner"] = r.randf_range(0.4, 0.8)
		7: # arco marcado
			f["bow"] = r.randf_range(1.3, 1.8)
			f["lip_u"] = float(f["lip_u"]) * 1.08
		8: # boca fina e reta
			f["lip_u"] = float(f["lip_u"]) * 0.7
			f["lip_l"] = float(f["lip_l"]) * 0.75
			f["bow"] = 0.1
		9: # lábios grossos
			f["lip_u"] = float(f["lip_u"]) * 1.25
			f["lip_l"] = float(f["lip_l"]) * 1.2
			f["mouth_w"] = float(f["mouth_w"]) * 1.04
		10: # lábio de cima cheio
			f["lip_u"] = float(f["lip_u"]) * 1.2
		11: # média carnuda
			f["lip_u"] = float(f["lip_u"]) * 1.1
			f["lip_l"] = float(f["lip_l"]) * 1.15
		12: # coração
			f["bow"] = r.randf_range(1.4, 1.9)
			f["mouth_w"] = float(f["mouth_w"]) * 0.93
			f["lip_u"] = float(f["lip_u"]) * 1.1
		13: # estreita e cheia
			f["mouth_w"] = float(f["mouth_w"]) * 0.88
			f["lip_u"] = float(f["lip_u"]) * 1.12
			f["lip_l"] = float(f["lip_l"]) * 1.15
		14: # larga e fina
			f["mouth_w"] = float(f["mouth_w"]) * 1.1
			f["lip_u"] = float(f["lip_u"]) * 0.8
			f["lip_l"] = float(f["lip_l"]) * 0.85
		15: # lábio de baixo fino
			f["lip_l"] = float(f["lip_l"]) * 0.78
		16: # cantos para cima
			f["corner"] = -r.randf_range(0.15, 0.3)
		17: # arco suave
			f["bow"] = r.randf_range(0.3, 0.5)
	# Orelhas
	var ear := RngUtil.weighted_index(r, [5.0, 1.2, 0.8, 0.9, 1.0, 0.4, 0.15, 1.5, 0.8, 0.7, 1.0, 0.8])
	if look.has("er"):
		ear = clampi(int(look["er"]), 0, EAR_TYPES.size() - 1)
	f["ear_type"] = ear
	match ear:
		1:
			f["ear"] = float(f["ear"]) * 0.86
			f["ear_out"] = 0.0
		2:
			f["ear"] = float(f["ear"]) * 1.15
		3:
			f["ear_out"] = r.randf_range(0.8, 1.2)
		4:
			f["lobe"] = 0.0
		5:
			f["ear_top"] = 1.0
		6:
			f["cauli"] = 1.0
		7: # média colada
			f["ear_out"] = minf(float(f["ear_out"]), 0.1)
		8: # lóbulo grande
			f["lobe"] = 1.35
		9: # estreita e comprida
			f["ear"] = float(f["ear"]) * 1.08
			f["ear_out"] = minf(float(f["ear_out"]), 0.3)
		10: # arredondada
			f["ear"] = float(f["ear"]) * 0.95
		11: # levemente de abano
			f["ear_out"] = r.randf_range(0.45, 0.7)
	# Queixo
	var chin := RngUtil.weighted_index(r, [5.0, 0.8, 0.7, 0.8, 0.6, 0.8, 0.5, 0.8, 0.7, 0.5, 0.8, 0.5])
	if look.has("cn"):
		chin = clampi(int(look["cn"]), 0, CHIN_TYPES.size() - 1)
	f["chin_type"] = chin
	match chin:
		1:
			f["chin_cleft"] = true
		2:
			f["chin_len"] = minf(float(f.get("chin_len", 0.0)), -0.04)
		3:
			f["chin_len"] = maxf(float(f.get("chin_len", 0.0)), 0.045)
		4:
			f["chin_sq"] = 1.1
		5:
			f["chin_sq"] = maxf(float(f["chin_sq"]), 2.6)
		6: # partido largo
			f["chin_cleft"] = true
			f["chin_sq"] = maxf(float(f["chin_sq"]), 2.3)
		7: # curto e redondo
			f["chin_len"] = minf(float(f.get("chin_len", 0.0)), -0.02)
			f["chin_sq"] = r.randf_range(1.2, 1.45)
		8: # quadrado marcado
			f["chin_sq"] = r.randf_range(2.8, 3.3)
			f["chin_len"] = maxf(float(f.get("chin_len", 0.0)), 0.015)
		9: # pontudo e longo
			f["chin_sq"] = 1.05
			f["chin_len"] = maxf(float(f.get("chin_len", 0.0)), 0.04)
		10: # recuado suave
			f["chin_len"] = minf(float(f.get("chin_len", 0.0)), -0.02)
		11: # proeminente e largo
			f["chin_len"] = maxf(float(f.get("chin_len", 0.0)), 0.035)
			f["chin_sq"] = maxf(float(f["chin_sq"]), 2.4)


## Pessoas bonitas: traços harmônicos, simétricos, mandíbula e maçãs marcadas, pele lisa.
## Pessoas feias: assimetria, nariz grande ou torto, olhos pequenos, orelhas de abano,
## queixo fraco ou papada, olheiras e marcas na pele.
static func _apply_beauty(f: Dictionary, beauty: float, r: RandomNumberGenerator) -> void:
	var ugly := 1.0 - beauty
	var bad := smoothstep(0.45, 1.0, ugly) # só os realmente feios ganham defeitos marcantes
	var good := smoothstep(0.55, 1.0, beauty)
	f["eye_h"] = float(f["eye_h"]) * lerpf(0.76, 1.0, smoothstep(0.0, 0.5, beauty)) * (1.0 + good * 0.1)
	f["eye_w"] = float(f["eye_w"]) * lerpf(0.88, 1.0, smoothstep(0.0, 0.5, beauty)) * (1.0 + good * 0.04)
	f["eye_dx"] = clampf(float(f["eye_dx"]) + bad * (0.05 if r.randf() < 0.5 else -0.05), 0.36, 0.52)
	f["nose_w"] = float(f["nose_w"]) * (1.0 + bad * 0.5) * (1.0 - good * 0.1)
	f["nose_len"] = float(f["nose_len"]) * (1.0 + bad * 0.15) * (1.0 - good * 0.04)
	f["nose_tip"] = float(f["nose_tip"]) * (1.0 + bad * 0.35)
	f["nose_dx"] = r.randf_range(0.04, 0.1) * bad * (1.0 if r.randf() < 0.5 else -1.0) if r.randf() < 0.6 else 0.0
	f["lip_u"] = float(f["lip_u"]) * (1.0 - bad * 0.35) * (1.0 + good * 0.15)
	f["lip_l"] = float(f["lip_l"]) * (1.0 - bad * 0.25) * (1.0 + good * 0.12)
	f["brow_gap"] = float(f["brow_gap"]) - bad * 0.04 + good * 0.01
	f["mouth_w"] = float(f["mouth_w"]) * lerpf(r.randf_range(0.85, 1.12), 1.0, beauty)
	f["cheekbone"] = float(f["cheekbone"]) * lerpf(0.7, 1.3, beauty)
	f["chin_sq"] = float(f["chin_sq"]) + good * 0.3
	f["jaw_v"] = float(f["jaw_v"]) - beauty * 0.04
	f["jaw"] = float(f["jaw"]) - bad * r.randf_range(0.0, 0.1) if r.randf() < 0.5 else float(f["jaw"])
	f["fat"] = clampf(float(f["fat"]) * (1.0 - good * 0.6) + bad * r.randf_range(0.05, 0.3), 0.0, 1.0)
	f["ear_out"] = clampf(float(f["ear_out"]) * (1.0 - good * 0.7) + bad * r.randf_range(0.3, 1.0), 0.0, 1.0)
	f["ear"] = float(f["ear"]) * lerpf(1.0, 1.12, bad)
	f["brow_dens"] = clampf(float(f["brow_dens"]) * lerpf(0.85, 1.1, beauty), 0.4, 1.0)
	if bad > 0.3 and r.randf() < 0.12:
		f["unibrow"] = true
	f["blemish"] = bad * r.randf_range(0.4, 1.0) if r.randf() < 0.75 else 0.0
	f["dark_circles"] = ugly * r.randf_range(0.2, 1.0) * (1.0 - good)
	f["rosy"] = float(f["rosy"]) * (1.0 + bad * 0.6)
	f["deep"] = float(f["deep"]) * lerpf(1.2, 1.0, beauty)
	# Os muito bonitos: simetria quase perfeita, olhos um pouco puxados para cima, nariz reto,
	# pele limpa. Os muito feios: olhos desiguais, boca torta, queixo fraco ou exagerado.
	f["asym"] = float(f["asym"]) * (1.0 - good * 0.85)
	f["eye_tilt"] = float(f["eye_tilt"]) + good * 0.012
	f["skin_clear"] = good
	if good > 0.3:
		f["nose_dx"] = 0.0
		f["brow_messy"] = 0.0
	f["eye_uneven"] = bad * r.randf_range(0.3, 1.0) if r.randf() < 0.7 else 0.0
	f["mouth_tilt"] = bad * r.randf_range(-1.0, 1.0)
	if bad > 0.3:
		f["chin_len"] = float(f.get("chin_len", 0.0)) + (bad * r.randf_range(-0.07, 0.07))
		f["cheekbone"] = float(f["cheekbone"]) * (1.0 - bad * 0.3)


## Pesos dos penteados para uma pessoa (etnia + textura + idade).
## Frequência real entre jogadores profissionais: cortes chamativos (moicano, descolorido, mullet,
## tigela, desenhos...) são raros (~3-4% no total) e cabelo longo/coque é minoria (~5%).
const FLASHY_STYLE_NAMES := ["Moicano", "Nevou (descolorido)", "Espetado descolorido", "Descolorido com desenho",
	"Moicano espetado", "Moicano trançado", "Moicano de dreads", "Moicano cacheado", "Mullet", "Mullet com degradê",
	"Mullet cacheado", "Tigela", "Samurai", "High top", "Black power alto", "Dois puffs", "Afro puff", "Espetado com gel",
	"Máquina com desenho", "Cachos com luzes", "Chanel", "Faux hawk", "Sidecut", "Nagô em zigue-zague", "Arrepiado",
	"Moicano desfiado", "Black power redondo", "High top navalhado", "Afro puff com degradê", "Frohawk", "Nagô em zigue-zague com degradê",
	"High top cacheado com pontas descoloridas", "Moicano com pontas descoloridas",
	"Meia-lua na franja", "Topete descolorido com laterais escuras", "Cachinhos descoloridos no alto", "Crespo descolorido no alto",
	"Tranças nagô descoloridas", "Twists tingidos de vermelho", "Espetado com luzes", "Moicano descolorido",
	"Moicano com desenhos laterais", "Crista alta", "Afro gigante loiro", "Black power gigante", "Cachos armados gigantes",
	"Rabinho trançado na nuca", "Moicano tingido de azul", "Listra tingida de vermelho no meio", "Esponja descolorida",
	"Tufinhos trançados tingidos de verde", "Black power com costeletas longas", "Dreads com faixa", "Cacheado longo com faixa",
	"Coque samurai cacheado", "Nagô com risco lateral"]
const LONG_STYLE_NAMES := ["Longo", "Coque", "Rabo de cavalo", "Surfista", "Cacheado longo", "Meio preso",
	"Longo para trás", "Longo ondulado", "Coque baixo", "Longo com franja", "Coque com undercut",
	"Undercut com coque baixo", "Coque alto com degradê", "Cacheado longo com franja", "Flow para trás",
	"Coque baixo com degradê", "Longo solto repartido", "Longo liso molhado para trás",
	"Dreads longos volumosos", "Longo com faixa", "Preso para trás com mechas soltas", "Longo ondulado atrás das orelhas",
	"Ondulado preso em coque baixo"]
static var _style_mult := PackedFloat32Array()
## Quantos penteados e barbas existiam antes do sorteio à parte (não mudar).
const HS_V1 := 211
const BD_V1 := 141


## Troca a escolha por um estilo acrescentado depois (índice >= first) com a chance que o peso
## deles representa no total. Usa um sorteio próprio para não mexer nos outros traços do rosto.
static func _newer_pick(seed_h: int, weights: Array, first: int, current: int) -> int:
	if weights.size() <= first:
		return current
	var total := 0.0
	var newer := 0.0
	for i in weights.size():
		total += float(weights[i])
		if i >= first:
			newer += float(weights[i])
	if newer <= 0.0 or total <= 0.0:
		return current
	var r := RandomNumberGenerator.new()
	r.seed = seed_h
	if r.randf() >= newer / total:
		return current
	var idx := RngUtil.weighted_index(r, weights.slice(first))
	return current if idx < 0 else first + idx


static func _style_realism() -> PackedFloat32Array:
	if _style_mult.size() == HAIR_STYLES.size():
		return _style_mult
	var m := PackedFloat32Array()
	m.resize(HAIR_STYLES.size())
	for i in HAIR_STYLES.size():
		var n: String = HAIR_STYLES[i]
		m[i] = 0.3 if n in FLASHY_STYLE_NAMES else (0.6 if n in LONG_STYLE_NAMES else 1.0)
	_style_mult = m
	return m


static func _style_weights(e: int, tex: int, age: int) -> Array:
	var sw: Array = []
	var real := _style_realism()
	for i in HAIR_STYLES.size():
		var w: float = float((STYLE_TEX_W[i] as Array)[tex]) * real[i]
		sw.append(w)
	if e == E_EAS or e == E_SEA:
		for i in [H_FRINGE, H_SPIKY, H_MIDPART, H_BOWL, H_CROP, H_TEXT_FRINGE, H_LONG_SIDE_FRINGE, H_CURTAIN, H_LONG_FRINGE, H_BOB]:
			sw[i] = float(sw[i]) * 2.0
	if e == E_PAC:
		for i in [H_LONG_CURLY, H_BUN, H_TOPKNOT, H_CURLY]:
			sw[i] = float(sw[i]) * 2.0
	if e == E_ARB or e == E_MED or e == E_SAS:
		for i in [H_SLICK, H_FADE, H_UNDERCUT, H_WAVY_BACK, H_WET_BACK, H_IVY]:
			sw[i] = float(sw[i]) * 1.5
	if age >= 32:
		for i in [H_MOHAWK, H_HIGHTOP, H_BRAIDS, H_TWISTS, H_SPIKY, H_BOWL, H_TOPKNOT, H_MULLET, H_EDGAR,
				H_BLEACHED, H_FADE_MULLET, H_FAUX_HAWK, H_CURLY_FRINGE, H_GEL_SPIKES, H_BRAID_HAWK, H_SIDECUT,
				H_DREAD_HAWK, H_FROSTED, H_AFRO_PUFF, H_SPONGE, H_ZIGZAG_ROWS, H_TEXT_FRINGE, H_SPIKY_HAWK, H_BIG_AFRO,
				H_LONG_TWISTS, H_BLEACH_DESIGN, H_TWO_PUFFS, H_CURLY_MULLET]:
			sw[i] = float(sw[i]) * 0.35
		for i in [H_SHORT, H_PART, H_CREW, H_BUZZ, H_BALD, H_IVY, H_CAESAR]:
			sw[i] = float(sw[i]) * 1.5
	if age < 24:
		for i in [H_FADE, H_CROP, H_FADE_PART, H_UNDERCUT, H_TWISTS, H_MULLET, H_EDGAR, H_CURLY_FADE, H_FADE_MULLET,
				H_CURLY_FRINGE, H_BLEACHED, H_TEXT_FRINGE, H_FROSTED, H_SPONGE, H_TEXT_QUIFF, H_BLOWOUT, H_TWIST_OUT,
				H_SKIN_FADE, H_CURTAIN, H_BLEACH_DESIGN, H_AFRO_PART, H_FREEFORM_FADE, H_WAVES_FADE, H_QUIFF_BURST]:
			sw[i] = float(sw[i]) * 1.4
		sw[H_BALD] = float(sw[H_BALD]) * 0.3
	return sw


## Barbas: no futebol real a maioria tem rosto limpo, barba por fazer ou barba curta/cheia bem
## aparada; bigodão, costeleta, barba longa e desenhos exóticos são raros (<5% somados).
static var _beard_mult := PackedFloat32Array()


static func _beard_realism() -> PackedFloat32Array:
	if _beard_mult.size() == BEARDS.size():
		return _beard_mult
	var m := PackedFloat32Array()
	m.resize(BEARDS.size())
	var plain := [B_NONE, B_WISPY, B_PEACH, B_STUBBLE, B_HEAVY_STUBBLE, B_DENSE_STUBBLE, B_WEEK, B_FADED, B_PATCHY]
	var beards := [B_SHORT, B_FULL, B_BOXED, B_MEDIUM, B_TRIMMED, B_SQUARE, B_ROUNDED, B_SHORT_SHARP, B_LINE_CUT]
	var classic := [B_GOATEE, B_MUSTACHE, B_VANDYKE, B_CHINSTRAP, B_SOUL, B_CIRCLE, B_BALBO, B_ANCHOR]
	plain.append_array([80, 81, 86, 93, 94, 100])
	plain.append_array([111, 113, 117, 119])
	beards.append_array([82, 83, 84, 85, 92, 96, 101, 103])
	beards.append_array([107, 108, 109, 115, 116])
	beards.append_array([120])
	beards.append_array([121, 122, 125, 138, 139])
	classic.append_array([124, 126, 127, 129])
	classic.append_array([87, 88, 89, 90, 99, 102])
	classic.append_array([104, 105, 106, 110, 112, 114, 118])
	plain.append_array([142, 147])
	beards.append_array([141, 143, 144, 148])
	classic.append_array([145, 146])
	for i in BEARDS.size():
		if i in plain:
			m[i] = 1.0
		elif i in beards:
			m[i] = 1.5
		elif i in classic:
			m[i] = 0.9
		else:
			m[i] = 0.18
	_beard_mult = m
	return m


static func skin_at(v: float) -> Color:
	if v < 0.0:
		return SKIN_PORCELAIN.lerp(SKIN_COLORS[0], clampf(v + 1.0, 0.0, 1.0))
	var i := clampi(int(floor(v)), 0, SKIN_COLORS.size() - 1)
	var j := mini(i + 1, SKIN_COLORS.size() - 1)
	return SKIN_COLORS[i].lerp(SKIN_COLORS[j], clampf(v - i, 0.0, 1.0))