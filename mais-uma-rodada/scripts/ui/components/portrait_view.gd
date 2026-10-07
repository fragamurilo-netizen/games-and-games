@tool
class_name PortraitView
extends Control
## Retrato 2D procedural com sombreamento suave. Cada parte grande (fundo, pele, orelhas, pescoço,
## camisa, cabelo, barba, olhos) é uma malha com cor por vértice calculada por uma função de luz:
## luz principal vindo de cima à esquerda, sombras quentes, brilho especular, órbitas, dorso do
## nariz, maçãs, sombra sob o lábio e o queixo. Cabelo, sobrancelhas e barba ganham fios por cima.
## Os traços vêm de FaceGen (semente + etnia + idade); uma foto importada no editor substitui tudo.
## O retrato pronto (malhas e traços) fica num cache global de comandos de desenho.

@export var face_seed: int = 12345:
	set(v):
		face_seed = v
		_dirty = true
		_invalidate()
@export var eth: int = 1:
	set(v):
		eth = v
		_dirty = true
		_invalidate()
@export var age: int = 25:
	set(v):
		age = v
		_dirty = true
		_invalidate()
@export var shirt_color: Color = Color("#1B3A8C"):
	set(v):
		shirt_color = v
		_invalidate()
@export var trim_color: Color = Color("#FFFFFF"):
	set(v):
		trim_color = v
		_invalidate()
@export var bg_color: Color = Color("#1C1D21"):
	set(v):
		bg_color = v
		_invalidate()
## Roupa de treinador/dirigente (terno) em vez da camisa do clube.
@export var suit: bool = false:
	set(v):
		suit = v
		_invalidate()
## Gola e padrão do uniforme do clube ("round", "v", "polo"; padrões do KitView). Vazio = sorteado.
@export var kit_collar: String = "":
	set(v):
		kit_collar = v
		_invalidate()
@export var kit_pattern: String = "":
	set(v):
		kit_pattern = v
		_invalidate()
## Uniforme do clube, no mesmo formato do KitView (pattern, c1, c2, c3, collar, sleeve, sp, sup).
## Tem prioridade sobre shirt_color/trim_color/kit_collar/kit_pattern.
var kit: Dictionary = {}:
	set(v):
		kit = v
		_invalidate()

## Escudo do clube (dicionário do CrestView), impresso no peito da camisa.
var crest: Dictionary = {}:
	set(v):
		crest = v
		_invalidate()

var look: Dictionary = {}:
	set(v):
		look = v
		_dirty = true
		_invalidate()
var photo: Texture2D = null:
	set(v):
		photo = v
		queue_redraw()
## Recorte para fotos (apresentação, notícias): sem o fundo redondo nem a borda, só o jogador.
var cutout: bool = false:
	set(v):
		cutout = v
		queue_redraw()

## Enquadramento: clássico (busto dentro do círculo com a cor do clube) ou recorte como os cutouts
## do Football Manager (cabeça grande no quadro, fundo transparente, ombros cortados embaixo).
const FRAME_CLASSIC := 0
const FRAME_FM := 1
## Padrão dos retratos (Opções › Retratos). As fotos de apresentação (cutout) usam sempre o busto.
static var default_framing := FRAME_FM
## -1 = segue o padrão.
var framing: int = -1:
	set(v):
		framing = v
		queue_redraw()
## Teste da luz de estúdio por malha sobre o retrato inteiro (FaceShade): 0 desligada, 1 ligada.
## -1 = segue o padrão.
static var mesh_light_default := 0
var mesh_light: int = -1:
	set(v):
		mesh_light = v
		queue_redraw()
## No recorte FM a cabeça é desenhada como num busto deste tamanho relativo, com os olhos a 47%
## da altura do quadro (medidas tiradas de cutouts de 250 px).
const FM_ZOOM := 1.42
const FM_EYE_Y := 0.47

## Parâmetros de cada penteado: tp/sd = volume no alto/nas laterais, hl = franja (desce a linha do
## cabelo), sb = até onde descem as laterais, fd = degradê (1 leve, 2 alto, 3 lateral raspada),
## tx = textura forçada, sp = silhueta (1 reto no alto, 2 espetado, 3 cacheado, 4 crista),
## lu = contorno marcado (line-up), bk = parte de trás, fr = peça da frente, fl = direção dos fios (0 para trás, 1 de lado, 2 para
## baixo, 3 repartido ao meio), op = opacidade, gl = brilho extra, lk = comprimento das mechas,
## dz = parte tingida (1 só o alto, 2 listra no meio) na cor dc, hh = altura da crista do moicano,
## sa = quanto sobra nas laterais raspadas (fd 3 e crista), mk = crista estreita de moicano mesmo sem fd 3.
const STYLE_P: Array = [
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.6}, # raspado
	{"tp": 0.09, "sd": 0.05, "fd": 1, "fl": 1}, # curto
	{"tp": 0.13, "sd": 0.06, "fl": 1, "fr": "part"}, # repartido
	{"tp": 0.1, "sd": 0.04, "fd": 1, "fr": "quiff"}, # topete
	{"tp": 0.1, "sd": 0.0, "fd": 2}, # degradê
	{"tp": 0.24, "sd": 0.16, "sp": 3, "tx": "curl", "sb": 0.05}, # cacheado
	{"tp": 0.5, "sd": 0.42, "sp": 3, "tx": "coil", "bk": "afro"}, # black power
	{"tp": 0.12, "sd": 0.1, "tx": "locs", "bk": "dreads", "sb": 0.1}, # dreads
	{"tp": 0.1, "sd": 0.1, "sb": 0.25, "bk": "long", "fr": "locks", "lk": 1.3, "fl": 1}, # longo
	{"tp": 0.05, "sd": 0.03, "bk": "bun", "gl": 0.15}, # coque
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4}, # moicano
	{}, # careca
	{"tp": 0.1, "sd": 0.04, "fd": 1, "gl": 0.3}, # para trás
	{"tp": 0.03, "sd": 0.02, "tx": "braid", "op": 0.75}, # nagô
	{"tp": 0.14, "sd": 0.05, "sp": 2, "fd": 1}, # arrepiado
	{"tp": 0.12, "sd": 0.08, "hl": 0.27, "fr": "fringe", "fl": 2, "sb": 0.05}, # franja
	{"tp": 0.15, "sd": 0.0, "fd": 3, "fl": 1, "gl": 0.15}, # undercut
	{"tp": 0.05, "sd": 0.02, "fd": 1, "op": 0.85}, # militar
	{"tp": 0.12, "sd": 0.0, "fd": 2, "fr": "pomp", "gl": 0.3}, # pompadour
	{"tp": 0.17, "sd": 0.15, "sb": 0.2, "tx": "wavy", "fr": "locks", "lk": 0.45, "fl": 1}, # ondulado médio
	{"tp": 0.12, "sd": 0.1, "sb": 0.22, "fl": 3, "fr": "locks", "lk": 0.4}, # repartido ao meio
	{"tp": 0.1, "sd": 0.05, "fd": 1, "bk": "mullet"}, # mullet
	{"tp": 0.03, "sd": 0.02, "bk": "pony", "gl": 0.25}, # rabo de cavalo
	{"tp": 0.2, "sd": 0.0, "fd": 2, "tx": "coil", "fr": "twists"}, # twists
	{"tp": 0.55, "sd": 0.02, "fd": 2, "sp": 1, "tx": "coil"}, # high top
	{"tp": 0.03, "sd": 0.02, "tx": "waves", "op": 0.9}, # waves
	{"tp": 0.08, "sd": 0.0, "hl": 0.14, "fd": 2, "fr": "crop", "fl": 2}, # crop
	{"tp": 0.14, "sd": 0.14, "sb": 0.3, "tx": "wavy", "bk": "long_short", "fr": "locks", "lk": 0.8, "fl": 1}, # surfista
	{"tp": 0.12, "sd": 0.11, "hl": 0.3, "fr": "fringe", "fl": 2, "sb": 0.08}, # tigela
	{"tp": 0.05, "sd": 0.03, "tx": "braid", "bk": "braids", "fr": "braid_locks", "lk": 1.3}, # box braids
	{"tp": 0.2, "sd": 0.15, "sp": 3, "tx": "coil"}, # afro curto
	{"tp": 0.03, "sd": 0.0, "fd": 3, "bk": "knot", "gl": 0.2}, # samurai
	{"tp": 0.3, "sd": 0.3, "sp": 3, "tx": "curl", "sb": 0.3, "bk": "curly_long"}, # cacheado longo
	{"tp": 0.08, "sd": 0.0, "fd": 2, "fr": "shaved_part"}, # degradê com risco
	{"tp": 0.14, "sd": 0.06, "tx": "wavy", "gl": 0.2}, # ondulado para trás
	{"tp": 0.2, "sd": 0.05, "fd": 1, "tx": "coil", "fr": "locs_top"}, # locs curtos
	{"tp": 0.16, "sd": 0.0, "fd": 4}, # burst fade
	{"tp": 0.36, "sd": 0.0, "fd": 2, "sp": 3, "tx": "coil"}, # afro com degradê
	{"tp": 0.16, "sd": 0.12, "sb": 0.18, "gl": 0.25, "tx": "wavy", "fr": "locks", "lk": 0.32}, # flow para trás
	{"tp": 0.16, "sd": 0.03, "fd": 1, "sp": 5, "fl": 1}, # topete bagunçado
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.62, "fr": "design"}, # máquina com desenho
	{"tp": 0.04, "sd": 0.0, "fd": 2, "tx": "braid", "op": 0.8}, # nagô com degradê
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "tx": "curl"}, # moicano cacheado
	{"tp": 0.14, "sd": 0.1, "hl": 0.2, "fd": 1, "fr": "fringe", "fl": 2, "sb": 0.05}, # liso médio
	{"tp": 0.14, "sd": 0.05, "hl": 0.1, "fd": 2, "fr": "side_fringe", "fl": 1}, # franja lateral
	{"tp": 0.2, "sd": 0.1, "tx": "locs", "fr": "locs_top", "sb": 0.05}, # freeform
	{"tp": 0.07, "sd": 0.02, "fd": 1, "fl": 1, "fr": "part", "op": 0.95}, # degradê social
	{"tp": 0.26, "sd": 0.0, "fd": 2, "sp": 3, "tx": "curl"}, # cacheado com degradê
	{"tp": 0.22, "sd": 0.06, "fd": 1, "sp": 3, "tx": "curl", "sb": 0.02}, # taper cacheado
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "dots", "op": 0.72}, # buzz com degradê
	{"tp": 0.05, "sd": 0.0, "fd": 3, "bk": "bun", "gl": 0.2}, # coque com undercut
	{"tp": 0.1, "sd": 0.1, "sb": 0.28, "bk": "long", "fr": "locks", "lk": 1.1, "fl": 1, "gl": 0.1, "fr2": "top_knot"}, # meio preso
	{"tp": 0.12, "sd": 0.0, "fd": 4, "bk": "mullet", "sp": 5, "fl": 1}, # mullet com degradê
	{"tp": 0.08, "sd": 0.0, "hl": 0.2, "fd": 2, "fr": "edgar", "fl": 2}, # corte Edgar
	{"tp": 0.06, "sd": 0.0, "fd": 2, "sp": 4, "gl": 0.15}, # faux hawk
	{"tp": 0.03, "sd": 0.0, "tx": "dots", "op": 0.8, "fd": 1}, # nevou
	{"tp": 0.14, "sd": 0.0, "fd": 2, "tx": "locs", "bk": "dreads"}, # dreads com degradê
	{"tp": 0.24, "sd": 0.05, "hl": 0.12, "fd": 2, "sp": 3, "tx": "curl", "fr": "curl_fringe"}, # franja cacheada
	{"tp": 0.12, "sd": 0.0, "fd": 2, "gl": 0.35}, # para trás com degradê
	{"tp": 0.04, "sd": 0.02, "tx": "braid", "bk": "bun", "op": 0.8}, # tranças com coque
	{"tp": 0.1, "sd": 0.0, "fd": 2, "fr": "quiff", "fr2": "shaved_part"}, # topete com risco
	{"tp": 0.1, "sd": 0.06, "sb": 0.2, "bk": "long", "gl": 0.35}, # longo para trás
	{"tp": 0.16, "sd": 0.1, "hl": 0.2, "tx": "wavy", "fr": "fringe", "fl": 2, "sb": 0.08}, # ondulado com franja
	{"tp": 0.12, "sd": 0.03, "sp": 2, "fd": 2, "gl": 0.45}, # espetado com gel
	{"tp": 0.32, "sd": 0.24, "sp": 3, "tx": "curl", "sb": 0.15}, # cachos médios
	{"tp": 0.02, "sd": 0.0, "fd": 3, "tx": "braid", "op": 0.85}, # moicano trançado
	{"tp": 0.14, "sd": 0.0, "fd": 3, "fr": "side_fringe", "fl": 1}, # sidecut
	{"tp": 0.1, "sd": 0.02, "tx": "locs", "bk": "dread_bun", "fd": 1}, # dreads presos
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "tx": "locs", "ck": "locs"}, # moicano de dreads
	{"tp": 0.2, "sd": 0.03, "fd": 2, "sp": 5, "fl": 0, "gl": 0.2}, # blowout
	{"tp": 0.1, "sd": 0.02, "hl": 0.16, "fd": 2, "fr": "crop", "sp": 5, "fl": 2}, # franja texturizada
	{"tp": 0.3, "sd": 0.24, "sp": 3, "tx": "curl", "sb": 0.1, "bc": 1}, # twist out
	{"tp": 0.04, "sd": 0.0, "fd": 2, "tx": "coil", "bk": "puff"}, # afro puff
	{"tp": 0.03, "sd": 0.02, "tx": "braid_zig", "op": 0.75}, # nagô em zigue-zague
	{"tp": 0.05, "sd": 0.0, "fd": 2, "tx": "braid", "bk": "braids", "fr": "braid_locks", "lk": 1.2}, # tranças longas com degradê
	{"tp": 0.12, "sd": 0.0, "fd": 2, "fr": "pomp", "fr2": "shaved_part", "gl": 0.35}, # pompadour com risco
	{"tp": 0.14, "sd": 0.14, "sb": 0.3, "tx": "wavy", "bk": "long", "fr": "locks", "lk": 1.5, "fl": 3}, # longo ondulado
	{"tp": 0.12, "sd": 0.03, "sp": 2, "fd": 2, "gl": 0.3}, # espetado descolorido
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.65, "fr": "shaved_part"}, # máquina com risco
	{"tp": 0.14, "sd": 0.05, "fd": 2, "tx": "coil", "fr": "sponge"}, # esponja
	{"tp": 0.04, "sd": 0.02, "bk": "bun_low", "gl": 0.3, "fl": 0}, # coque baixo
	{"tp": 0.12, "sd": 0.02, "fd": 2, "fr": "quiff", "sp": 5, "fl": 1}, # topete desfiado
	{"tp": 0.14, "sd": 0.06, "hl": 0.14, "fd": 3, "fr": "side_fringe_long", "fl": 1}, # franja longa de lado
	{"tp": 0.13, "sd": 0.1, "sb": 0.12, "fl": 3, "fr": "curtain", "tx": "wavy"}, # franja cortina
	{"tp": 0.04, "sd": 0.01, "tx": "dots", "op": 0.82, "fd": 1}, # máquina 2
	{"tp": 0.1, "sd": 0.0, "fd": 5, "fl": 1}, # degradê navalhado
	{"tp": 0.14, "sd": 0.0, "fd": 3, "fr": "pomp", "gl": 0.35, "ph": 1.35}, # topete alto
	{"tp": 0.2, "sd": 0.0, "fd": 2, "sp": 3, "tx": "curl", "fr": "quiff"}, # topete cacheado
	{"tp": 0.07, "sd": 0.02, "hl": 0.09, "fd": 1, "fr": "crop", "fl": 2, "fc": 0.7}, # social com franjinha
	{"tp": 0.08, "sd": 0.02, "fd": 1, "fl": 1, "fr": "part", "gl": 0.2}, # ivy league
	{"tp": 0.1, "sd": 0.04, "fd": 1, "gl": 0.6, "fl": 0}, # molhado para trás
	{"tp": 0.28, "sd": 0.0, "fd": 4, "sp": 3, "tx": "curl"}, # burst cacheado
	{"tp": 0.5, "sd": 0.42, "sp": 3, "tx": "coil", "bk": "afro", "ar": 1.22}, # black power alto
	{"tp": 0.34, "sd": 0.0, "fd": 2, "sp": 3, "tx": "coil", "fr": "shaved_part"}, # afro com risco
	{"tp": 0.2, "sd": 0.08, "tx": "coil", "fr": "twists", "bk": "braids", "sb": 0.05}, # twists longos
	{"tp": 0.1, "sd": 0.04, "tx": "locs", "bk": "pony", "fl": 0}, # dreads em rabo
	{"tp": 0.03, "sd": 0.02, "tx": "braid", "op": 0.78, "bk": "pony"}, # nagô com rabo
	{"tp": 0.04, "sd": 0.0, "fd": 2, "bk": "knot", "gl": 0.25}, # coque alto com degradê
	{"tp": 0.1, "sd": 0.1, "sb": 0.3, "hl": 0.22, "bk": "long", "fr": "fringe", "fr2": "locks", "lk": 1.3, "fl": 2}, # longo com franja
	{"tp": 0.12, "sd": 0.12, "sb": 0.3, "bk": "long_short", "fr": "locks", "lk": 0.65, "fl": 3, "gl": 0.2}, # chanel
	{"tp": 0.2, "sd": 0.08, "sp": 3, "tx": "curl", "bk": "mullet", "fd": 1}, # mullet cacheado
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "ck": "spikes"}, # moicano espetado
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.75, "fr": "design", "fd": 1}, # descolorido com desenho
	{"tp": 0.18, "sd": 0.1, "sb": 0.08, "tx": "wavy", "sp": 5, "fl": 1}, # ondulado bagunçado
	{"tp": 0.19, "sd": 0.08, "fl": 1, "fr": "part", "gl": 0.15}, # repartido volumoso
	{"tp": 0.07, "sd": 0.02, "hl": 0.12, "fd": 1, "fr": "crop", "fl": 2, "fc": 0.55}, # corte césar
	{"tp": 0.1, "sd": 0.0, "fd": 4, "fr": "quiff"}, # topete com burst
	{"tp": 0.12, "sd": 0.0, "fd": 3, "bk": "bun_low", "gl": 0.3, "fl": 0}, # undercut com coque baixo
	{"tp": 0.3, "sd": 0.3, "sp": 3, "tx": "curl", "sb": 0.3, "bk": "curly_long", "hl": 0.12, "fr": "curl_fringe"}, # cacheado longo com franja
	{"tp": 0.18, "sd": 0.0, "fd": 2, "tx": "locs", "fr": "locs_top"}, # freeform com degradê
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "waves", "op": 0.9}, # waves com degradê
	{"tp": 0.24, "sd": 0.02, "fd": 2, "sp": 3, "tx": "curl"}, # cachos com luzes
	{"tp": 0.04, "sd": 0.0, "fd": 1, "tx": "coil", "bk": "puffs2", "fl": 3}, # dois puffs
	{"tp": 0.11, "sd": 0.04, "fd": 1, "sp": 5, "fl": 1}, # curto texturizado
	{"tp": 0.1, "sd": 0.0, "fd": 2, "fr": "quiff", "ph": 0.8}, # degradê com topete baixo
	{"tp": 0.07, "sd": 0.03, "fd": 1, "fl": 1, "op": 0.95}, # social curto
	{"tp": 0.1, "sd": 0.03, "fd": 2, "fl": 1, "fr": "part"}, # repartido baixo
	{"tp": 0.09, "sd": 0.05, "hl": 0.12, "fd": 1, "fr": "crop", "fl": 2, "fc": 0.8}, # franja curta reta
	{"tp": 0.18, "sd": 0.04, "fd": 1, "fr": "quiff", "ph": 1.15, "gl": 0.2}, # topete com volume
	{"tp": 0.18, "sd": 0.1, "sp": 3, "tx": "curl", "sb": 0.03}, # cacheado curto
	{"tp": 0.22, "sd": 0.0, "fd": 5, "sp": 3, "tx": "curl"}, # cachos com degradê navalhado
	{"tp": 0.1, "sd": 0.06, "sp": 3, "tx": "coil", "fd": 1}, # crespo curto
	{"tp": 0.12, "sd": 0.0, "fd": 5, "tx": "coil", "sp": 3}, # crespo com degradê alto
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "waves", "op": 0.9, "fr": "shaved_part"}, # waves com risco
	{"tp": 0.14, "sd": 0.03, "fd": 2, "tx": "coil", "fr": "twists"}, # twists curtos
	{"tp": 0.14, "sd": 0.1, "tx": "locs", "bk": "dreads", "sb": 0.12, "fd": 1}, # locs médios
	{"tp": 0.13, "sd": 0.07, "tx": "wavy", "fd": 1, "fl": 1}, # ondulado curto
	{"tp": 0.15, "sd": 0.08, "tx": "wavy", "fl": 1, "fr": "part"}, # ondulado repartido
	{"tp": 0.15, "sd": 0.08, "sb": 0.12, "fl": 1, "fr": "side_fringe"}, # liso médio de lado
	{"tp": 0.08, "sd": 0.03, "fd": 1, "gl": 0.25, "fl": 0}, # para trás curto
	{"tp": 0.08, "sd": 0.02, "fd": 1, "fl": 1}, # degradê baixo
	{"tp": 0.09, "sd": 0.0, "fd": 2, "fl": 1}, # degradê médio
	{"tp": 0.05, "sd": 0.02, "tx": "dots", "op": 0.9, "fd": 1}, # máquina 3
	{"tp": 0.015, "sd": 0.0, "tx": "dots", "op": 0.45}, # raspado rente
	{"tp": 0.13, "sd": 0.02, "fd": 2, "sp": 5, "fl": 0}, # topete bagunçado curto
	{"tp": 0.11, "sd": 0.05, "hl": 0.18, "fd": 1, "fr": "fringe", "fl": 2, "sp": 5}, # franja desfiada
	{"tp": 0.17, "sd": 0.12, "sb": 0.14, "sp": 5, "fl": 1, "fr": "locks", "lk": 0.35}, # médio desarrumado
	{"tp": 0.36, "sd": 0.3, "sp": 3, "tx": "curl", "sb": 0.12}, # cacheado volumoso
	{"tp": 0.34, "sd": 0.28, "sp": 3, "tx": "coil"}, # afro médio
	{"tp": 0.3, "sd": 0.1, "fd": 1, "sp": 3, "tx": "coil"}, # afro com degradê baixo
	{"tp": 0.035, "sd": 0.0, "fd": 1, "tx": "braid", "op": 0.8}, # nagô reto com degradê
	{"tp": 0.05, "sd": 0.0, "fd": 2, "bk": "bun_low", "gl": 0.25, "fl": 0}, # coque baixo com degradê
	{"tp": 0.1, "sd": 0.1, "sb": 0.28, "bk": "long", "fr": "locks", "lk": 1.2, "fl": 3}, # longo solto repartido
	{"tp": 0.15, "sd": 0.1, "sb": 0.14, "tx": "wavy", "gl": 0.2, "fr": "locks", "lk": 0.25, "fl": 0}, # médio ondulado para trás
	{"tp": 0.16, "sd": 0.03, "fd": 2, "tx": "wavy", "fr": "quiff"}, # topete ondulado
	{"tp": 0.16, "sd": 0.0, "hl": 0.12, "fd": 2, "sp": 3, "tx": "curl", "fr": "curl_fringe"}, # crop cacheado
	{"tp": 0.08, "sd": 0.02, "fd": 1, "fl": 1, "fr": "part", "fr2": "shaved_part"}, # social com risco
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "dots", "op": 0.75, "fr": "shaved_part"}, # buzz com risco lateral
	{"tp": 0.1, "sd": 0.03, "hl": 0.08, "fd": 2, "fr": "side_fringe", "fl": 1}, # curto com franja lateral
	{"tp": 0.1, "sd": 0.03, "sp": 2, "fd": 1, "gl": 0.2}, # espetado curto
	{"tp": 0.14, "sd": 0.1, "sb": 0.16, "fl": 3, "fr": "curtain"}, # médio com franja cortina
	{"tp": 0.26, "sd": 0.2, "sp": 3, "tx": "curl", "sb": 0.18, "bc": 1}, # cachos soltos médios
	{"tp": 0.12, "sd": 0.0, "fd": 5, "tx": "coil", "fr": "sponge"}, # esponja com degradê
	{"tp": 0.17, "sd": 0.0, "fd": 5, "fr": "quiff", "ph": 1.1, "gl": 0.3, "fl": 0, "lu": 1}, # topete penteado navalhado
	{"tp": 0.12, "sd": 0.07, "fl": 1, "sb": 0.06}, # social natural
	{"tp": 0.07, "sd": 0.0, "fd": 2, "tx": "coil", "lu": 1}, # crespo baixo com degradê
	{"tp": 0.035, "sd": 0.0, "fd": 5, "tx": "dots", "op": 0.95, "lu": 1}, # buzz navalhado
	{"tp": 0.07, "sd": 0.02, "fd": 1, "gl": 0.35, "fl": 0, "sb": 0.05}, # liso para trás rente
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "gl": 0.1}, # moicano desfiado
	{"tp": 0.26, "sd": 0.0, "fd": 5, "tx": "locs", "fr": "locs_top", "sp": 3, "lu": 1}, # twists caídos com degradê
	{"tp": 0.14, "sd": 0.02, "hl": 0.14, "fd": 2, "fr": "fringe", "fl": 2, "sp": 5}, # franja bagunçada com degradê
	{"tp": 0.1, "sd": 0.0, "hl": 0.14, "fd": 5, "fr": "crop", "fl": 2, "fc": 0.9}, # french crop navalhado
	{"tp": 0.2, "sd": 0.0, "hl": 0.2, "fd": 5, "sp": 3, "tx": "curl"}, # franja cacheada navalhada
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.7, "lu": 1}, # máquina 1 com contorno
	{"tp": 0.15, "sd": 0.0, "hl": 0.04, "fd": 2, "sp": 5, "fl": 1}, # texturizado de lado com degradê
	{"tp": 0.56, "sd": 0.5, "sp": 3, "tx": "coil", "bk": "afro", "lu": 1}, # black power redondo
	{"tp": 0.4, "sd": 0.0, "fd": 5, "sp": 3, "tx": "coil", "lu": 1}, # afro alto navalhado
	{"tp": 0.5, "sd": 0.0, "fd": 5, "sp": 1, "tx": "coil", "lu": 1}, # high top navalhado
	{"tp": 0.22, "sd": 0.12, "tx": "coil", "fr": "twists", "sb": 0.1}, # twists médios
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "braid_zig", "op": 0.8}, # nagô em zigue-zague com degradê
	{"tp": 0.2, "sd": 0.0, "fd": 2, "tx": "coil", "fr": "sponge", "lu": 1}, # esponja alta
	{"tp": 0.16, "sd": 0.02, "fd": 5, "tx": "locs", "bk": "dreads", "sb": 0.08}, # locs com degradê navalhado
	{"tp": 0.05, "sd": 0.0, "fd": 5, "tx": "coil", "bk": "puff", "lu": 1}, # afro puff com degradê
	{"tp": 0.025, "sd": 0.0, "fd": 1, "tx": "waves", "op": 0.9}, # waves 360
	{"tp": 0.24, "sd": 0.14, "sp": 3, "tx": "coil", "fr": "shaved_part", "lu": 1}, # crespo médio com risco
	{"tp": 0.3, "sd": 0.0, "fd": 3, "sp": 4, "tx": "coil", "lu": 1}, # frohawk
	{"tp": 0.28, "sd": 0.0, "fd": 2, "sp": 3, "tx": "curl", "lu": 1}, # cachos definidos com degradê
	{"tp": 0.26, "sd": 0.2, "sp": 3, "tx": "coil", "sb": 0.06}, # crespo médio natural
	{"tp": 0.34, "sd": 0.0, "fd": 4, "sp": 3, "tx": "curl", "lu": 1}, # high top cacheado com pontas descoloridas
	{"tp": 0.08, "sd": 0.03, "sb": 0.18, "bk": "long", "gl": 0.65, "fl": 0}, # longo liso molhado para trás
	{"tp": 0.1, "sd": 0.07, "hl": 0.16, "fd": 0, "fr": "crop", "fl": 1, "fc": 1.0, "lu": 1}, # franja reta curta
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "ck": "spikes"}, # moicano com pontas descoloridas
	{"tp": 0.02, "sd": 0.0, "tx": "dots", "op": 0.5, "fr": "halfmoon"}, # meia-lua na franja
	{"tp": 0.14, "sd": 0.0, "fd": 2, "fr": "quiff", "ph": 1.1, "gl": 0.2, "dz": 1}, # topete descolorido com laterais escuras
	{"tp": 0.24, "sd": 0.0, "fd": 2, "sp": 3, "tx": "curl", "dz": 1}, # cachinhos descoloridos no alto
	{"tp": 0.2, "sd": 0.0, "fd": 5, "sp": 3, "tx": "coil", "dz": 1, "lu": 1}, # crespo descolorido no alto
	{"tp": 0.03, "sd": 0.0, "fd": 1, "tx": "braid", "op": 0.82}, # tranças nagô descoloridas
	{"tp": 0.2, "sd": 0.04, "fd": 2, "tx": "coil", "fr": "twists"}, # twists com pontas descoloridas
	{"tp": 0.22, "sd": 0.06, "fd": 1, "tx": "coil", "fr": "twists"}, # twists tingidos de vermelho
	{"tp": 0.16, "sd": 0.0, "fd": 5, "fr": "quiff", "ph": 1.3, "sp": 2, "gl": 0.3, "lu": 1}, # topete alto arrepiado com degradê
	{"tp": 0.13, "sd": 0.03, "sp": 2, "fd": 1, "gl": 0.2}, # espetado com luzes
	{"tp": 0.04, "sd": 0.0, "fd": 3, "sp": 4, "tx": "coil", "hh": 0.8}, # moicano descolorido
	{"tp": 0.03, "sd": 0.0, "fd": 1, "sp": 4, "mk": 1, "fr": "design_both", "tx": "dots", "op": 0.9, "sa": 0.85}, # moicano com desenhos laterais
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "hh": 1.9, "gl": 0.35}, # crista alta
	{"tp": 0.5, "sd": 0.45, "sp": 3, "tx": "curl", "bk": "afro_curl", "ar": 1.3, "fr": "curl_fringe", "hl": 0.06, "bc": 1}, # afro gigante loiro
	{"tp": 0.55, "sd": 0.5, "sp": 3, "tx": "coil", "bk": "afro", "ar": 1.45}, # black power gigante
	{"tp": 0.42, "sd": 0.4, "sp": 3, "tx": "curl", "bk": "afro_curl", "ar": 1.02, "bc": 1, "hl": 0.1}, # cachos armados gigantes
	{"tp": 0.16, "sd": 0.14, "tx": "locs", "bk": "dreads", "fr": "braid_locks", "lk": 1.1, "sb": 0.2}, # dreads longos volumosos
	{"tp": 0.12, "sd": 0.1, "tx": "locs", "bk": "dreads", "sb": 0.1, "fr": "band"}, # dreads com faixa
	{"tp": 0.1, "sd": 0.1, "sb": 0.25, "bk": "long", "fr": "locks", "lk": 1.2, "fl": 3, "fr2": "band"}, # longo com faixa
	{"tp": 0.26, "sd": 0.26, "sp": 3, "tx": "curl", "sb": 0.3, "bk": "curly_long", "fr": "band"}, # cacheado longo com faixa
	{"tp": 0.06, "sd": 0.04, "bk": "pony", "gl": 0.2, "fr": "locks", "lk": 0.3, "fl": 3, "sb": 0.1}, # preso para trás com mechas soltas
	{"tp": 0.08, "sd": 0.04, "fd": 1, "fl": 1, "bk": "rattail"}, # rabinho trançado na nuca
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "ck": "spikes"}, # moicano tingido de azul
	{"tp": 0.1, "sd": 0.03, "fd": 1, "sp": 5, "fl": 1, "dz": 2, "dc": "#B8222C"}, # listra tingida de vermelho no meio
	{"tp": 0.14, "sd": 0.0, "fd": 3, "gl": 0.5, "fl": 0, "fr": "shaved_part"}, # undercut para trás com risco
	{"tp": 0.14, "sd": 0.0, "fd": 5, "tx": "coil", "fr": "sponge", "lu": 1}, # esponja descolorida
	{"tp": 0.05, "sd": 0.02, "fd": 1, "tx": "braid", "op": 0.8, "fr": "bunches"}, # tufinhos trançados tingidos de verde
	{"tp": 0.36, "sd": 0.28, "sp": 3, "tx": "coil", "sb": 0.42}, # black power com costeletas longas
	{"tp": 0.16, "sd": 0.06, "gl": 0.55, "fl": 0, "bk": "mullet", "sb": 0.1}, # para trás volumoso até a nuca
	{"tp": 0.12, "sd": 0.05, "sb": 0.05, "tx": "wavy", "bk": "long", "fl": 1, "fr": "part", "gl": 0.15}, # longo ondulado atrás das orelhas
	{"tp": 0.14, "sd": 0.0, "fd": 2, "tx": "wavy", "fl": 1}, # ondulado com degradê
	{"tp": 0.26, "sd": 0.16, "sp": 3, "tx": "curl", "sb": 0.06, "hl": 0.12, "fr": "curl_fringe"}, # cacheado médio com franja
	{"tp": 0.1, "sd": 0.0, "fd": 5, "fl": 1, "fr": "part", "lu": 1, "gl": 0.15}, # repartido navalhado
	{"tp": 0.16, "sd": 0.03, "fd": 1, "tx": "coil", "fr": "twists"}, # twists curtos com degradê baixo
	{"tp": 0.15, "sd": 0.08, "sb": 0.1, "fl": 1, "fr": "side_fringe", "gl": 0.2}, # médio penteado de lado
	{"tp": 0.3, "sd": 0.04, "fd": 1, "sp": 3, "tx": "curl"}, # cacheado com laterais curtas
	{"tp": 0.08, "sd": 0.02, "fd": 1, "fl": 1, "fr": "part", "gl": 0.5}, # social com gel
	{"tp": 0.11, "sd": 0.06, "sb": 0.06, "fl": 3, "fr": "curtain"}, # curto repartido ao meio
	{"tp": 0.22, "sd": 0.06, "fd": 1, "sp": 3, "tx": "coil", "lu": 1}, # crespo médio com degradê baixo
	{"tp": 0.12, "sd": 0.04, "fd": 1, "fr": "quiff", "ph": 0.75}, # topete curto natural
	{"tp": 0.03, "sd": 0.0, "fd": 3, "bk": "knot", "tx": "curl", "gl": 0.1}, # coque samurai cacheado
	{"tp": 0.03, "sd": 0.0, "fd": 2, "tx": "braid", "op": 0.8, "fr": "shaved_part"}, # nagô com risco lateral
	{"tp": 0.08, "sd": 0.04, "tx": "wavy", "bk": "bun_low", "fl": 0, "gl": 0.15}, # ondulado preso em coque baixo
	{"tp": 0.16, "sd": 0.0, "fd": 2, "fl": 0, "gl": 0.25, "sp": 5}, # para trás desarrumado com degradê
]

const LIGHT := Vector3(-0.4, -0.5, 0.77)
const HEAD_SCALE := 0.88
## Rosto um pouco mais estreito que o gerado: a proporção largura/altura fica mais perto da de
## uma cabeça real e o retrato perde o ar "inchado".
const HEAD_W := 0.93

var _f: Dictionary = {}
var _dirty := true
# Geometria do retrato atual (em pixels)
var _s := 0.0
var _c := Vector2.ZERO
var _hc := Vector2.ZERO
var _fw := 0.0
var _fh := 0.0
var _R := 0.0
var _fm := false
var _ml := 0
var _mlon := false
var _ml_masks: Array = []
## Silhuetas do cabelo de trás (para a luz por malha), guardadas junto do cache da camada de trás.
var _hair_sil: Array = []
static var _sil_cache: Dictionary = {}
var _rect := Rect2()
var _det := 1.0
var _light := Vector3.ZERO
# Traços em coordenadas normalizadas do rosto (u = x/fw, v = y/fh a partir do centro da cabeça)
var _E := 0.0
var _X := 0.0
var _N := 0.0
var _M := 0.0
var _NW := 0.0
var _BW := 0.0
var _MW := 0.0
var _ND := 0.0
var _skin := Color.WHITE
## Ombro da luz na pele: acima de _lum_knee a luminância se aproxima de _lum_top sem passar.
var _lum_knee := 9.0
var _lum_top := 10.0
var _beard_p: Dictionary = {}
var _shadow_p: Dictionary = {}
var _blotches: Array = []
var _k := PackedFloat32Array()
var _half := Vector3.ZERO
var _shadow_col := Color.BLACK
var _beard_data: Array = []
# Gravação dos comandos de desenho: o retrato pronto fica num cache global e é só reproduzido
# quando a tela o recria (listas de elenco, mercado, etc.).
var _rec: Array = []
var _recording := false
static var _cmd_cache: Dictionary = {}
static var _cmd_cache_order: Array = []
const CMD_CACHE_MAX := 720
# Contexto da malha que está sendo gerada
var _mesh_c := Vector2.ZERO
var _mesh_b := PackedVector2Array()
var _blob_c := Vector2.ZERO
var _blob_r := 1.0
var _blob_m: Array = [] # malha do último _blob (para a textura de fios)
var _hair_style: Dictionary = {}
## Cor da barba já com a tinta do estilo (descolorida), sem mexer na sobrancelha.
var _bcol := Color.BLACK
var _cap_in := PackedVector2Array()
var _cap_out := PackedVector2Array()
# Estampas prontas para imprimir no peito (texturas do DecalCache)
var _crest_tex: Texture2D = null
var _sponsor_tex: Texture2D = null


func set_player(p: Player, club: Club, year: int) -> void:
	face_seed = p.face_seed
	eth = p.eth
	age = p.age(year)
	look = p.look
	photo = CustomAssets.texture(String(p.look.get("photo", "")))
	if photo == null:
		photo = CustomAssets.texture(DropIns.player_ref(p)) # recorte solto em cutouts/ de um pacote
	if club != null:
		shirt_color = club.primary_color()
		trim_color = club.secondary_color()
		bg_color = club.primary_color().darkened(0.6)
		kit = club.kit_for(p)
		if p.position == Pos.GK:
			shirt_color = Color(String(kit.get("c1", "#111111")))
			trim_color = Color(String(kit.get("c2", "#FFFFFF")))
		crest = club.crest
	queue_redraw()


func set_person(seed_value: int, eth_: int, age_: int, club: Club) -> void:
	face_seed = seed_value
	eth = eth_
	age = age_
	suit = true
	if club != null:
		trim_color = club.primary_color()
		bg_color = club.primary_color().darkened(0.6)


func _init() -> void:
	# O recorte FM passa das bordas do quadro (ombros, cabelo alto): o próprio Control corta.
	clip_contents = true


func _invalidate() -> void:
	queue_redraw()


## Recorte no estilo FM? As fotos de apresentação (cutout) precisam do busto inteiro.
func is_fm() -> bool:
	if cutout:
		return false
	return (default_framing if framing < 0 else framing) == FRAME_FM


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c := o + Vector2(s * 0.5, s * 0.5)
	_fm = is_fm()
	_ml = mesh_light if mesh_light >= 0 else mesh_light_default
	_rect = Rect2(o, Vector2(s, s))
	if photo != null:
		_draw_photo(c, s)
		return
	if _dirty or _f.is_empty():
		_f = FaceGen.features(face_seed, eth, age, look)
		_dirty = false
	_prepare_decals(s)
	# Três camadas com cache próprio: fundo + cabelo de trás, corpo + roupa, rosto + cabelo.
	# Trocar o uniforme ou a estampa ficar pronta só redesenha a camada do corpo.
	var face_key := hash([face_seed, eth, age, look, size, bg_color, cutout, _fm])
	var k_back := hash(["back", face_key])
	var k_body := hash(["body", face_key, shirt_color, trim_color, suit, kit_collar, kit_pattern, kit, crest,
		_crest_tex != null, _sponsor_tex != null])
	var k_front := hash(["front", face_key, _ml])
	var ready := false
	for pair: Array in [[k_back, 0], [k_body, 1], [k_front, 2]]:
		var key: int = pair[0]
		if _cmd_cache.has(key):
			_replay(_cmd_cache[key])
			continue
		if not ready:
			if _fm:
				# Busto maior que o quadro, com os olhos na altura dos cutouts do FM; o que passa
				# das bordas é cortado (ombros embaixo, cabelo muito alto em cima).
				var sv := s * FM_ZOOM
				_setup(Vector2(c.x, o.y + s * FM_EYE_Y + sv * 0.105), sv)
			else:
				_setup(c, s)
			ready = true
		_rec = []
		_recording = true
		match int(pair[1]):
			0:
				_hair_sil = []
				_layer_back()
				if _sil_cache.size() > CMD_CACHE_MAX:
					_sil_cache.clear()
				_sil_cache[k_back] = _hair_sil
			1:
				_body()
			2:
				_hair_sil = _sil_cache.get(k_back, [])
				_layer_front()
		_recording = false
		_cmd_cache[key] = _rec
		_cmd_cache_order.append(key)
		if _cmd_cache_order.size() > CMD_CACHE_MAX:
			_cmd_cache.erase(_cmd_cache_order.pop_front())
		_rec = []


func _layer_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_f["texture_seed"])
	if not cutout and not _fm:
		_background()
		_backdrop_depth()
	_back_hair(rng)


func _layer_front() -> void:
	var f := _f
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f["texture_seed"]) + 7
	var style: int = f["style"]
	var hair: Color = f["hair"]
	_ears()
	# Rosto
	var head := _head_contour(_contour_k())
	# De perto, o dorso do nariz e os sulcos precisam de amostras menores que a íris.
	# A malha continua radial e entra no mesmo cache; miniaturas mantêm o custo anterior.
	_mlon = _ml > 0 and _s >= 50.0
	_ml_masks = []
	var face := _radial(_hc, head, _rings(20 if _s >= 140.0 else 11), _skin_px)
	_rim(face, head.size())
	if _s >= DETAIL_MIN:
		# Pele: manchas, granulado e poros (mais marcados com a idade, menos na pele lisa)
		var ka := 0.08 + 0.1 * float(f["aging"]) - 0.03 * float(f.get("skin_clear", 0.0))
		_detail(face, _planar_uvs(face[1], "skin_pores", DETAIL_DENS, _detail_off(2)), "skin_pores", clampf(ka, 0.04, 0.2))
	_age_lines()
	_marks(rng)
	# Barba (malha com densidade suave), depois os traços por cima
	if int(f["beard"]) != FaceGen.B_NONE:
		_beard_mesh()
	_eyes()
	_brows(rng)
	_nose()
	_mouth()
	if int(f["beard"]) != FaceGen.B_NONE:
		_beard_hairs(rng)
	# Cabelo da frente
	if style != FaceGen.H_BALD:
		_front_hair(rng, hair)
	else:
		_scalp_shine()
	_accessories()
	if _mlon:
		# Luz de estúdio do boneco inteiro por cima de tudo: rosto, cabelo, barba, pescoço e camisa
		_body_setup()
		FaceShade.paint(self, _ml_masks, _beard_data if int(f["beard"]) != FaceGen.B_NONE else [], _hair_sil)
	_light_pass()
	_mlon = false
	if cutout or _fm:
		return
	# Borda
	_r_arc(_c, _R - 1.0, 0.0, TAU, 64, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, _s * 0.012), true)


## Luz de estúdio sobre o recorte inteiro (rosto, cabelo, pescoço e camisa juntos): luz principal
## quente do alto à esquerda, lado direito e parte de baixo caindo para a sombra, e uma luz de
## contorno fria marcando a borda direita da cabeça e dos ombros, como numa foto de ficha.
func _light_pass() -> void:
	if _s < 50.0:
		return
	var key := _hc + Vector2(-_fw * 0.9, -_fh * 0.9)
	var light := func(p: Vector2, _t: float, _i: int) -> Color:
		var d := (p - key) / (_s * 0.9)
		var fall := clampf(d.length(), 0.0, 1.3)
		var warm := Color(1.0, 0.92, 0.8, 0.1 * (1.0 - smoothstep(0.0, 0.65, fall)))
		var shade := 0.12 * smoothstep(0.55, 1.35, fall)
		if shade > warm.a:
			return Color(0.04, 0.06, 0.12, shade)
		return warm
	var head := _head_contour(_contour_k())
	if cutout or _fm:
		# Sem fundo: a luz vai só sobre o rosto (no círculo inteiro ela tingia o fundo transparente),
		# sumindo antes do contorno da cabeça: com a borda dura, o black power e o cabelo comprido
		# ficavam com um "capacete" mais claro no formato do crânio
		_radial(_hc, head, 4 if _s < 90.0 else 6, func(p: Vector2, t: float, i: int) -> Color:
			var c: Color = light.call(p, t, i)
			return Color(c, c.a * (1.0 - smoothstep(0.5, 0.95, t))))
	else:
		var circle := _ellipse(_c, _R, _R, 24 if _s < 90.0 else 36)
		_radial(_c, circle, 4 if _s < 90.0 else 6, light)
	# Luz de contorno (recorte) só nos ombros: no rosto ela sobrava como um risco na mandíbula
	var lw := maxf(0.8, _s * 0.007)
	_body_setup()
	if not suit and not _mlon:
		var side := _torso_side(0.06, false)
		var sc := PackedColorArray()
		var sp := PackedVector2Array()
		for i in side.size():
			var p := side[i]
			if p.y < _ysp - _s * 0.03 or p.x < _hc.x + _nwt:
				continue
			sp.append(_cl(p + Vector2(-lw * 0.7, lw * 0.3)))
			sc.append(Color(0.8, 0.88, 1.0, 0.22 * (1.0 - smoothstep(_ysp, _ysp + _s * 0.18, p.y))))
		if sp.size() > 2:
			_r_polyline_colors(sp, sc, lw * 1.2, true)


## Pede ao DecalCache o escudo e o patrocínio em textura; só usa quando já foram desenhados.
func _prepare_decals(s: float) -> void:
	_crest_tex = null
	_sponsor_tex = null
	if suit or s < 70.0 or DisplayServer.get_name() == "headless":
		return
	if not crest.is_empty():
		var t := DecalCache.crest_texture(crest, self)
		if t != null and DecalCache.is_ready(t):
			_crest_tex = t
	var sp: Variant = kit.get("sp", {})
	if sp is Dictionary and String((sp as Dictionary).get("n", "")) != "" and s >= 90.0:
		var t2 := DecalCache.brand_texture(sp as Dictionary, self)
		if t2 != null and DecalCache.is_ready(t2):
			_sponsor_tex = t2


func _setup(c: Vector2, s: float) -> void:
	var f := _f
	_s = s
	_c = c
	_R = s * 0.5
	# Cabeça um pouco menor e mais alta, para caber pescoço e ombros como numa foto de ficha
	_fw = float(f["fw"]) * s * HEAD_SCALE * HEAD_W
	_fh = float(f["fh"]) * s * HEAD_SCALE
	_hc = c + Vector2(0, -s * 0.1)
	_det = clampf(s / 140.0, 0.3, 2.0)
	_light = LIGHT.normalized()
	_E = float(f["eye_y"])
	_X = float(f["eye_dx"])
	_N = float(f["nose_len"])
	_M = float(f["mouth_y"])
	_NW = float(f["nose_w"]) * 1.1
	_BW = float(f["bridge_w"])
	_MW = float(f["mouth_w"]) * 1.15
	_skin = f["skin"]
	# Luminância em que o canal mais claro da pele chega a 0,97 (com as curvas de _shade)
	var lum_max := minf(pow(0.97 / maxf(_skin.r, 0.01), 1.0 / 0.82), minf(0.97 / maxf(_skin.g, 0.01), pow(0.97 / maxf(_skin.b, 0.01), 1.0 / 1.12)))
	_lum_top = maxf(lum_max, 1.05)
	_lum_knee = maxf(0.92, _lum_top - 0.2)
	# Índice fora da tabela (save antigo, catálogo novo) cai no último item em vez de travar o
	# _setup no meio: com o _setup interrompido a pele do rosto saía toda preta.
	_beard_p = FaceGen.BEARD_PARTS[clampi(int(f["beard"]), 0, FaceGen.BEARD_PARTS.size() - 1)]
	_shadow_p = FaceGen.BEARD_PARTS[FaceGen.B_STUBBLE]
	_hair_style = STYLE_P[clampi(int(f["style"]), 0, STYLE_P.size() - 1)]
	_bcol = (f["beard_col"] as Color).lerp(Color("#E4D6AE"), float(_beard_p.get("bl", 0.0)))
	_half = (_light + Vector3(0, 0, 1)).normalized()
	_shadow_col = Color(0.2, 0.22, 0.28).lerp(_skin.darkened(0.5), 0.5)
	var ag: float = f["aging"]
	var shadow: float = f["shadow"] if int(f["beard"]) != FaceGen.B_STUBBLE else 0.0
	_k = PackedFloat32Array([
		float(f["deep"]), float(f["ridge"]), 1.0 if bool(f["aquiline"]) else 0.0, float(f["bridge"]),
		float(f["nose_tip"]), 0.025 + 0.09 * ag + 0.04 * maxf(0.0, float(f["smile"])), float(f["cheekbone"]),
		0.07 * float(f["cheekbone"]) * (1.0 - float(f["fat"])) + 0.06 * float(f.get("thin", 0.0)), float(f["lip_l"]), 1.0 if bool(f["chin_cleft"]) else 0.0,
		ag, float(f["rosy"]), shadow, 0.05 + clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0) * 0.1,
		float(f.get("dark_circles", 0.0)), float(f.get("thin", 0.0)), float(f.get("jowl", 0.0)),
		float(f.get("eyebags", 0.0)), float(f.get("temple", 0.0)), clampf(float(f["smile"]) - 0.5, 0.0, 1.0) + float(f.get("squint", 0.0)) * 0.3,
		float(f.get("heavy", 0.0)), float(f.get("skin_clear", 0.0)),
		float(f.get("nose_bulb", 0.0)), float(f.get("nose_pinch", 0.0)), float(f.get("nose_flare", 0.0)),
		float(f.get("bridge_low", 0.0)), float(f.get("nose_bump", 0.0)), float(f.get("philtrum", 0.0)),
		float(f.get("under_line", 0.0)), float(f.get("pout", 0.0))])
	_ND = float(f.get("nose_dx", 0.0)) + float(f.get("nose_dx_t", 0.0))
	_blotches.clear()
	var br := RandomNumberGenerator.new()
	br.seed = int(f["blotch_seed"])
	for i in 5:
		_blotches.append([br.randf_range(-0.8, 0.8), br.randf_range(-0.8, 0.9), br.randf_range(0.15, 0.35), br.randf_range(-0.035, 0.03)])


func _contour_k() -> int:
	return clampi(int(24 * _det), 10, 30)


func _rings(n: int) -> int:
	return maxi(3, int(round(n * clampf(_det, 0.4, 1.2))))


static var _alpha_cache: Dictionary = {}


## Foto com fundo transparente (recorte de verdade)? Conferido uma vez por textura.
static func _has_alpha(t: Texture2D) -> bool:
	var id := t.get_instance_id()
	if not _alpha_cache.has(id):
		var img := t.get_image()
		_alpha_cache[id] = img != null and img.detect_alpha() != Image.ALPHA_NONE
	return _alpha_cache[id]


func _draw_photo(c: Vector2, s: float) -> void:
	var ts := photo.get_size()
	if _fm:
		# Recorte FM: a foto no quadro, sem círculo (PNG transparente inteiro; foto comum cortada
		# em quadrado a partir do alto)
		if _has_alpha(photo):
			var kf := minf(size.x / ts.x, size.y / ts.y)
			var szf := ts * kf
			draw_texture_rect(photo, Rect2(Vector2((size.x - szf.x) * 0.5, size.y - szf.y), szf), false)
		else:
			var sd := minf(ts.x, ts.y)
			draw_texture_rect_region(photo, Rect2(_rect.position, _rect.size), Rect2(Vector2((ts.x - sd) * 0.5, 0.0), Vector2(sd, sd)))
		return
	if cutout and _has_alpha(photo):
		# Recorte (apresentação, notícias): a imagem inteira, apoiada embaixo, sem o círculo.
		var k := minf(size.x / ts.x, size.y / ts.y)
		var sz := ts * k
		draw_texture_rect(photo, Rect2(Vector2((size.x - sz.x) * 0.5, size.y - sz.y), sz), false)
		return
	var pts := _ellipse(c, s * 0.5, s * 0.5, 48)
	# Fundo do círculo: recortes em PNG transparente ficam sobre a cor do clube.
	draw_colored_polygon(pts, bg_color)
	# Quadrado do tamanho do lado menor, centrado na largura e apoiado no alto (rosto em cima).
	var side := minf(ts.x, ts.y)
	var top := Vector2((ts.x - side) * 0.5, 0.0)
	var uvs := PackedVector2Array()
	for p in pts:
		var rel := (p - c) / s + Vector2(0.5, 0.5) # 0..1
		var px := top + rel * side
		uvs.append(Vector2(px.x / ts.x, px.y / ts.y))
	_fill(pts, Color.WHITE, uvs, photo)
	_r_arc(c, s * 0.5 - 1.0, 0.0, TAU, 48, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, s * 0.012), true)


# ---------------------------------------------------------------------------
# Malhas com cor por vértice
# ---------------------------------------------------------------------------

## Malha radial de `center` até o contorno `boundary` (precisa ser "estrelado" a partir do centro).
## `shader(p, t, i)` recebe o ponto, a fração do raio (0 centro … 1 borda) e o índice no contorno.
func _radial(center: Vector2, boundary: PackedVector2Array, rings: int, shader: Callable) -> Array:
	var n := boundary.size()
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	if n < 3:
		return [idx, pts, cols]
	_mesh_c = center
	_mesh_b = boundary
	pts.append(_cl(center))
	cols.append(shader.call(center, 0.0, 0))
	for r in range(1, rings + 1):
		var t := float(r) / rings
		for i in n:
			var p := center + (boundary[i] - center) * t
			pts.append(_cl(p))
			cols.append(shader.call(p, t, i))
	for i in n:
		idx.append_array([0, 1 + i, 1 + (i + 1) % n])
	for r in range(1, rings):
		var b0 := 1 + (r - 1) * n
		var b1 := 1 + r * n
		for i in n:
			var j := (i + 1) % n
			idx.append_array([b0 + i, b1 + i, b1 + j, b0 + i, b1 + j, b0 + j])
	var m := [idx, pts, cols]
	_emit(m)
	return m


## Faixa entre duas linhas com o mesmo número de pontos; `shader(p, t, w)` recebe a posição ao
## longo da faixa (t) e a fração entre a linha de dentro (w = 0) e a de fora (w = 1).
func _strip(inner: PackedVector2Array, outer: PackedVector2Array, layers: int, shader: Callable, emit: bool = true) -> Array:
	var n := mini(inner.size(), outer.size())
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for l in layers + 1:
		var w := float(l) / layers
		for i in n:
			var p := inner[i].lerp(outer[i], w)
			pts.append(_cl(p))
			cols.append(shader.call(p, float(i) / maxf(1.0, n - 1.0), w))
	for l in layers:
		var b0 := l * n
		var b1 := (l + 1) * n
		for i in n - 1:
			idx.append_array([b0 + i, b1 + i, b1 + i + 1, b0 + i, b1 + i + 1, b0 + i + 1])
	var m := [idx, pts, cols]
	if emit:
		_emit(m)
	return m


func _emit(m: Array) -> void:
	var idx: PackedInt32Array = m[0]
	if idx.is_empty():
		return
	_r_tri(idx, m[1], m[2])


# ---------------------------------------------------------------------------
# Texturas de detalhe (fios, pelos, pele, íris)
# ---------------------------------------------------------------------------

## Abaixo deste tamanho (lado virtual do retrato) as texturas não aparecem: viram a cor média.
const DETAIL_MIN := 64.0
## Escala das texturas: texels por meia largura de rosto (_fw).
const DETAIL_DENS := 256.0
const BEARD_DENS := 320.0

## Texturas de assets/portrait (tools/portrait_textures/gen.py): cinza = tom (média 0,5), alfa =
## cobertura. Repetem sem costura e têm mipmaps: nítidas de perto, sem chuvisco no retrato
## pequeno. Carregadas uma vez.
static var _detail_cache: Dictionary = {}


static func _detail_tex(name: String) -> CanvasTexture:
	if not _detail_cache.has(name):
		var path := "res://assets/portrait/%s.png" % name
		var ct: CanvasTexture = null
		if ResourceLoader.exists(path):
			ct = CanvasTexture.new()
			ct.diffuse_texture = load(path)
			ct.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			ct.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_detail_cache[name] = ct
	return _detail_cache[name]


## Repete a malha `m` ([idx, pts, cols]) com a textura `name` por cima. A cor de cada vértice
## (já iluminada) vai em dobro porque a textura tem tom médio 0,5: na média a peça fica com a cor
## de antes, e os fios clareiam e escurecem em volta dela. A opacidade é a do vértice vezes
## `alpha`; com `alphas`, é a de `alphas` (uma por vértice) vezes `alpha`.
func _detail(m: Array, uvs: PackedVector2Array, name: String, alpha: float = 1.0, alphas: PackedFloat32Array = PackedFloat32Array()) -> void:
	var idx: PackedInt32Array = m[0]
	if idx.is_empty() or _s < DETAIL_MIN:
		return
	var tex := _detail_tex(name)
	if tex == null:
		return
	var cols: PackedColorArray = m[2]
	var tc := PackedColorArray()
	tc.resize(cols.size())
	var own := alphas.size() == cols.size()
	for i in cols.size():
		var c := cols[i]
		tc[i] = Color(c.r * 2.0, c.g * 2.0, c.b * 2.0, (alphas[i] if own else c.a) * alpha)
	_r_tex_tri(idx, m[1], tc, uvs, tex)


## UVs planas (no plano do rosto, mesma escala nos dois eixos) para os pontos `pts`.
func _planar_uvs(pts: PackedVector2Array, name: String, dens: float, off: Vector2) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	var tex := _detail_tex(name)
	if tex == null:
		return uvs
	var ts := tex.diffuse_texture.get_size()
	var k := Vector2(dens / (_fw * ts.x), dens / (_fw * ts.y))
	uvs.resize(pts.size())
	for i in pts.size():
		uvs[i] = off + (pts[i] - _hc) * k
	return uvs


## Desloca a textura de cada rosto (os fios não caem no mesmo lugar em todo mundo).
func _detail_off(salt: int) -> Vector2:
	var h := hash([int(_f["hair_seed"]), salt])
	return Vector2(float(h % 1000) / 1000.0, float((h / 1000) % 1000) / 1000.0)


## UVs de uma faixa (`_strip`) para a textura `name`: u segue o comprimento da faixa e v a
## espessura, na mesma escala do começo ao fim (os fios não esticam onde a faixa afina). Na ordem
## dos vértices de `_strip` (camada a camada).
func _strip_uvs(inner: PackedVector2Array, outer: PackedVector2Array, layers: int, name: String, salt: int) -> PackedVector2Array:
	var uvs := PackedVector2Array()
	var tex := _detail_tex(name)
	var n := mini(inner.size(), outer.size())
	if tex == null or n < 2:
		return uvs
	var ts := tex.diffuse_texture.get_size()
	var acc := PackedFloat32Array()
	acc.resize(n)
	acc[0] = 0.0
	for i in range(1, n):
		var a := (inner[i - 1] + outer[i - 1]) * 0.5
		var b := (inner[i] + outer[i]) * 0.5
		acc[i] = acc[i - 1] + a.distance_to(b) / _fw
	var off := _detail_off(salt)
	for l in layers + 1:
		var w := float(l) / layers
		for i in n:
			var th := inner[i].distance_to(outer[i]) / _fw
			uvs.append(off + Vector2(acc[i] * DETAIL_DENS / ts.x, w * th * DETAIL_DENS / ts.y))
	return uvs


## Borda crespa: uma faixa de `inner` a `outer` feita só de fios soltos (textura rala), que
## somem aos poucos para fora. A silhueta de cachos e crespos termina em fios, não em bolinhas.
func _fuzz(inner: PackedVector2Array, outer: PackedVector2Array, color_at: Callable) -> void:
	if _s < DETAIL_MIN:
		return
	var m := _strip(inner, outer, 3, func(p: Vector2, _t: float, w: float) -> Color:
		var c: Color = color_at.call(p)
		return Color(c, c.a * (1.0 - w * w)), false)
	_detail(m, _strip_uvs(inner, outer, 3, "hair_fuzz", 7), "hair_fuzz")


## Borda crespa em volta de um contorno fechado (bola de cabelo).
func _fuzz_ring(center: Vector2, outline: PackedVector2Array, inset: float, outset: float, color_at: Callable) -> void:
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in outline.size() + 1:
		var p := outline[i % outline.size()]
		inner.append(_cl(center + (p - center) * (1.0 - inset)))
		outer.append(_cl(center + (p - center) * (1.0 + outset)))
	_fuzz(inner, outer, color_at)


## Mantém os pontos dentro do círculo do retrato (recorte barato das malhas).
func _cl(p: Vector2) -> Vector2:
	if _fm:
		return p # o Control corta (clip_contents); prender na borda criava faixas no rodapé
	var d := p - _c
	var r := _R - 0.5
	if d.length_squared() > r * r:
		return _c + d.normalized() * r
	return p


## Ponto dentro do retrato (círculo ou quadro do recorte FM), com folga `margin`.
func _inside(p: Vector2, margin: float = 1.0) -> bool:
	if _fm:
		return _rect.grow(-margin).has_point(p)
	return (p - _c).length() < _R - margin


## Contorno do retrato como polígono, para recortar malhas.
func _clip_poly() -> PackedVector2Array:
	if _fm:
		var r := _rect
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var disc := PackedVector2Array()
	for i in 64:
		disc.append(_c + Vector2.from_angle(TAU * i / 64.0) * _R * 0.995)
	return disc


func _aa_outline(poly: PackedVector2Array, col: Color, alpha: float) -> void:
	var pts := PackedVector2Array(poly)
	pts.append(poly[0])
	for i in pts.size():
		pts[i] = _cl(pts[i])
	_r_polyline(pts, Color(col, alpha * 0.55), maxf(0.8, _s * 0.006), true)


## Borda suave numa silhueta aberta: o GLES3 não faz MSAA em 2D, então as bordas das malhas
## contra o fundo ganham uma linha antisserrilhada na própria cor de cada ponto.
func _aa_edge(pts: PackedVector2Array, color_at: Callable, alpha: float = 1.0) -> void:
	if pts.size() < 2:
		return
	var line := PackedVector2Array()
	var cols := PackedColorArray()
	for p in pts:
		var q := _cl(p)
		line.append(q)
		var c: Color = color_at.call(q)
		cols.append(Color(c, c.a * alpha))
	_r_polyline_colors(line, cols, maxf(1.0, _s * 0.005), true)


static func _g(x: float, sd: float) -> float:
	return exp(-(x * x) / (sd * sd))


static func _g2(x: float, y: float, sx: float, sy: float) -> float:
	return exp(-(x * x) / (sx * sx) - (y * y) / (sy * sy))


func _uv(p: Vector2) -> Vector2:
	return Vector2((p.x - _hc.x) / _fw, (p.y - _hc.y) / _fh)


func _px(u: float, v: float) -> Vector2:
	return _hc + Vector2(u * _fw, v * _fh)


## Ponto do nariz (acompanha o desvio de um nariz torto).
func _pxn(u: float, v: float) -> Vector2:
	return _px(u + _ND * smoothstep(_E - 0.05, _N, v), v)


## Aplica luminância com sombras mais quentes (o vermelho some por último).
static func _shade(base: Color, lum: float) -> Color:
	var l := maxf(lum, 0.0)
	return Color(minf(base.r * pow(l, 0.82), 1.0), minf(base.g * l, 1.0), minf(base.b * pow(l, 1.12), 1.0), base.a)


# ---------------------------------------------------------------------------
# Formato da cabeça
# ---------------------------------------------------------------------------

## Meia largura do rosto (em fw) na altura v (0 = centro da cabeça, 1 = queixo).
func _hw(v: float) -> float:
	var f := _f
	var cw: float = f["cheek_w"]
	var jaw: float = f["jaw"]
	var jv: float = f["jaw_v"]
	var sq: float = f["chin_sq"]
	jaw *= 0.95
	var w: float
	if v <= jv:
		# Começa a afinar já abaixo das maçãs, sem a lateral reta de "caixa"
		w = lerpf(cw, jaw, smoothstep(-0.2, jv, v))
	else:
		# Da mandíbula ao queixo em linha quase reta, com a ponta arredondada: o queixo tem
		# largura própria (mais largo no queixo quadrado) em vez de um "U" cheio
		var q := clampf((v - jv) / (1.0 - jv), 0.0, 1.0)
		var chin := jaw * lerpf(0.42, 0.58, clampf((sq - 1.25) / 1.6, 0.0, 1.0))
		var e := 3.0 + sq
		w = lerpf(jaw, chin, pow(q, 1.1)) * pow(maxf(0.0, 1.0 - pow(q, e)), 1.0 / e)
	w += 0.03 * float(f["cheekbone"]) * _g(v - 0.08, 0.16)
	w *= 1.0 + float(f["fat"]) * 0.11 * _g(v - 0.5, 0.3)
	# Gordo: bochecha e mandíbula cheias; fino: afunda logo abaixo das maçãs
	w *= 1.0 + float(f.get("heavy", 0.0)) * 0.15 * _g(v - 0.72, 0.2)
	w *= 1.0 - float(f.get("thin", 0.0)) * 0.12 * _g(v - 0.42, 0.14)
	# Buldogue: a pele desce e alarga a linha da mandíbula perto do queixo
	w *= 1.0 + float(f.get("jowl", 0.0)) * 0.1 * _g(v - 0.8, 0.1)
	w *= lerpf(1.0, float(f.get("chin_width", 1.0)), smoothstep(0.65, 0.95, v))
	return w


## Queixo mais comprido (proeminente) ou mais curto (recuado): desloca só a ponta do rosto.
func _chin_v(v: float) -> float:
	return v + float(_f.get("chin_len", 0.0)) * smoothstep(0.7, 1.0, v)


## Expoente do crânio visto de frente: um pouco "quadrado" (superelipse), largo nas têmporas e
## arredondado no alto — uma elipse pura deixa a cabeça careca em forma de cone.
const SKULL_N := 2.35


## Meia largura do crânio (em fw) na altura `up` (0 = meio da cabeça, 1 = topo): a testa só
## estreita perto do alto, como num crânio real.
func _skull_rx(up: float) -> float:
	var width := lerpf(float(_f["cheek_w"]), float(_f["forehead"]), pow(clampf(up, 0.0, 1.0), 1.6))
	return width * lerpf(1.0, float(_f.get("temple_width", 1.0)), _g(up - 0.48, 0.28))


## Ponto do alto da cabeça no ângulo `a` (de -PI a 0), em unidades do rosto.
func _skull_pt(a: float, grow_x: float = 0.0, grow_y: float = 0.0) -> Vector2:
	var e := 2.0 / SKULL_N
	var cx := signf(cos(a)) * pow(absf(cos(a)), e)
	var sy := signf(sin(a)) * pow(absf(sin(a)), e)
	return Vector2(cx * (_skull_rx(-sy) + grow_x), sy * (1.02 + grow_y))


## Contorno da cabeça (sentido horário a partir do alto).
func _head_contour(k: int) -> PackedVector2Array:
	var right := PackedVector2Array()
	for i in k:
		var a := -PI * 0.5 + PI * 0.5 * float(i) / k
		right.append(_skull_pt(a))
	for i in k + 1:
		var q := float(i) / k
		var v := sin(q * PI * 0.5)
		right.append(Vector2(_hw(v), _chin_v(v)))
	var pts := PackedVector2Array()
	for p in right:
		pts.append(_px(p.x, p.y))
	for i in range(right.size() - 2, 0, -1):
		pts.append(_px(-right[i].x, right[i].y))
	return pts


## "Distância" normalizada até o contorno do rosto: < 1 dentro, 1 na borda, > 1 fora.
func _th(u: float, v: float) -> float:
	if v >= 0.0:
		# Perto do queixo a largura tende a zero; um piso evita uma "agulha" de barba no pescoço
		var hw := maxf(_hw(minf(v, 1.0)), maxf(0.001, 0.32 * smoothstep(0.8, 1.0, v)))
		return maxf(absf(u) / hw, v / (1.0 + float(_f.get("chin_len", 0.0)) * smoothstep(0.7, 1.0, v)))
	var rx := _skull_rx(-v / 1.02)
	return pow(pow(absf(u / rx), SKULL_N) + pow(absf(v / 1.02), SKULL_N), 1.0 / SKULL_N)


# ---------------------------------------------------------------------------
# Pele
# ---------------------------------------------------------------------------

func _skin_px(p: Vector2, t: float, i: int) -> Color:
	var u := (p.x - _hc.x) / _fw
	var v := (p.y - _hc.y) / _fh
	var au := absf(u)
	# Normal de uma "cúpula" com o formato do rosto
	var dx := 0.0
	var dy := 0.0
	if t > 0.0 and i < _mesh_b.size():
		var d := (_mesh_b[i] - _mesh_c).normalized()
		dx = d.x
		dy = d.y
	var tilt := pow(t, 1.8)
	var nx := dx * tilt
	var ny := dy * tilt
	var nz := sqrt(maxf(0.0, 1.0 - tilt * tilt))
	# O nariz participa da luz da pele. Antes só havia manchas pintadas sobre a
	# cúpula da cabeça, deixando o dorso plano mesmo quando a ponte era alta.
	var nu := u - _ND * smoothstep(_E - 0.05, _N, v)
	var bridge_mask := smoothstep(_E - 0.06, _E + 0.1, v) * (1.0 - smoothstep(_N - 0.1, _N + 0.02, v))
	var bridge_x := nu / (_BW * 1.45)
	var tip_x := nu / (_NW * 0.65 * float(_f.get("nose_tip_width", 1.0)))
	var tip_y := (v - (_N - 0.055)) / 0.07
	var tip_shape := exp(-tip_x * tip_x - tip_y * tip_y)
	var tip_projection := float(_f.get("nose_tip_projection", 1.0))
	nx += 0.9 * _k[3] * bridge_x * exp(-bridge_x * bridge_x) * bridge_mask + 0.55 * tip_x * tip_shape * tip_projection
	ny += 0.45 * tip_y * tip_shape * tip_projection
	nx -= float(_f.get("nose_tip_split", 0.0)) * 0.18 * tip_x * exp(-tip_x * tip_x * 8.0 - tip_y * tip_y)
	# Órbitas côncavas, maçãs convexas e volume do queixo sob a mesma luz.
	# A simetria usa as medidas de cada pessoa, sem trocar o formato salvo.
	var orbit_x := (au - _X) / 0.25
	var orbit_y := (v - (_E + 0.015)) / 0.12
	var orbit := exp(-orbit_x * orbit_x - orbit_y * orbit_y) * _k[0]
	nx -= signf(u) * 0.22 * orbit_x * orbit
	ny -= 0.3 * orbit_y * orbit
	var cheek_x := (au - 0.5) / 0.32
	var cheek_y := (v - 0.16) / 0.25
	var cheek := exp(-cheek_x * cheek_x - cheek_y * cheek_y) * _k[6]
	nx += signf(u) * 0.3 * cheek_x * cheek
	ny += 0.32 * cheek_y * cheek
	var chin_x := u / 0.3
	var chin_y := (v - 0.82) / 0.16
	var chin := exp(-chin_x * chin_x - chin_y * chin_y)
	nx += 0.16 * chin_x * chin
	ny += 0.22 * chin_y * chin
	var normal := Vector3(nx, ny, nz).normalized()
	nx = normal.x
	ny = normal.y
	nz = normal.z
	# Luz "enrolada": a pele espalha a luz por dentro, então a passagem para a sombra é gradual
	var diff := clampf((nx * _light.x + ny * _light.y + nz * _light.z + 0.3) / 1.3, 0.0, 1.0)
	# Luz principal suave e um rebatedor na frente: a sombra fica macia, sem "meia cara escura"
	var lum := 0.56 + 0.5 * diff
	# Oclusão onde a cabeça vira para longe da câmera e luz de rebote no lado da sombra, que separa
	# o rosto do fundo como numa foto
	lum -= 0.06 * smoothstep(0.78, 1.0, t)
	lum += 0.07 * smoothstep(0.86, 1.0, t) * maxf(0.0, dx) * (1.0 - smoothstep(0.3, 0.9, -dy))
	var E := _E
	var X := _X
	var N := _N
	var M := _M
	var BW := _BW
	var NW := _NW
	var MW := _MW
	var k := _k
	var a := 0.0
	var b := 0.0
	# Órbitas e arco superciliar
	var ey := v - E + 0.01
	a = (u - X) / 0.27
	b = (u + X) / 0.27
	var ey2 := ey * ey / 0.0121
	lum -= 0.13 * k[0] * (exp(-a * a - ey2) + exp(-b * b - ey2))
	a = (au - 0.2) / 0.08
	b = (v - E) / 0.08
	lum -= 0.05 * exp(-a * a - b * b)
	b = (v - E + 0.19) / 0.05
	var bb := b * b
	a = (u + X * 0.95) / 0.26
	var a2 := (u - X * 0.95) / 0.26
	lum += 0.07 * k[1] * (exp(-a * a - bb) * 1.2 + exp(-a2 * a2 - bb) * 0.6)
	# Testa e têmporas
	a = (u + 0.2) / 0.38
	b = (v + 0.55) / 0.2
	var fore := exp(-a * a - b * b)
	lum += 0.07 * fore
	a = (au - 0.92) / 0.14
	b = (v + 0.28) / 0.22
	lum -= 0.05 * exp(-a * a - b * b)
	# Nariz: dorso claro, lateral direita na sombra, ponta, asas e sombra embaixo
	var un := u - _ND * smoothstep(E - 0.05, N, v)
	var wv := smoothstep(E - 0.06, E + 0.1, v) * (1.0 - smoothstep(N - 0.1, N - 0.01, v))
	var ridge_hl := 0.0
	if wv > 0.0:
		a = (un + 0.03) / BW
		ridge_hl = exp(-a * a) * wv
		var hump := 0.0
		if k[2] > 0.0:
			b = (v - (E + N) * 0.5) / 0.06
			hump = (0.05 + 0.07 * k[26]) * exp(-b * b)
		# Ponte baixa: o dorso só ganha luz da metade do nariz para baixo
		var low := 1.0 - k[25] * (1.0 - smoothstep(E + 0.04, E + 0.22, v))
		lum += (0.06 * k[3] * low + hump) * ridge_hl
		if k[26] > 0.0:
			# Calombo: sombra logo abaixo do ressalto
			a = (un - BW * 0.4) / (BW * 1.4)
			b = (v - ((E + N) * 0.5 + 0.075)) / 0.035
			lum -= 0.06 * k[26] * exp(-a * a - b * b) * wv
		a = (un - BW * 1.7) / (BW * 0.9)
		lum -= 0.12 * k[3] * exp(-a * a) * wv
		a = (un + BW * 1.9) / (BW * 0.9)
		lum -= 0.05 * k[3] * exp(-a * a) * wv
	if v > N - 0.25 and v < N + 0.12:
		a = (un + 0.02) / (NW * 0.45 * k[4] * (1.0 - 0.35 * k[23]))
		b = (v - (N - 0.07)) / 0.05
		lum += 0.09 * exp(-a * a - b * b)
		if k[22] > 0.0:
			# Ponta bulbosa: bola de luz maior e sombra em volta, embaixo à direita
			a = (un + 0.02) / (NW * 0.62)
			b = (v - (N - 0.06)) / 0.075
			lum += 0.06 * k[22] * exp(-a * a - b * b)
			lum -= 0.07 * k[22] * _g2(un - NW * 0.32, v - (N + 0.004), NW * 0.36, 0.026)
		b = (v - (N - 0.035)) / 0.055
		bb = b * b
		var wing := NW * (0.85 + 0.18 * k[24])
		a = (un - wing) / (NW * 0.3)
		a2 = (un + wing) / (NW * 0.3)
		lum -= 0.14 * (1.0 + 0.6 * k[23]) * (exp(-a * a - bb) + exp(-a2 * a2 - bb) * 0.6)
		a = (un - 0.02) / (NW * 0.8)
		b = (v - (N + 0.035)) / 0.034
		lum -= 0.28 * exp(-a * a - b * b)
	# Sulco nasolabial (mais marcado com a idade e o sorriso)
	if v > N - 0.1 and v < M + 0.15:
		var nl_d := _seg_dist(Vector2(au, v), Vector2(NW * 1.25, N - 0.02), Vector2(MW * 1.12, M + 0.04)) / 0.045
		lum -= k[5] * (1.0 if u > 0.0 else 0.55) * exp(-nl_d * nl_d)
	# Maçãs do rosto e bochechas
	b = (v - 0.1) / 0.1
	a = (u + 0.5) / 0.25
	a2 = (u - 0.5) / 0.25
	lum += k[6] * (0.07 * exp(-a * a - b * b) + 0.03 * exp(-a2 * a2 - b * b))
	a = (au - 0.64) / 0.17
	b = (v - 0.4) / 0.13
	lum -= k[7] * exp(-a * a - b * b)
	# Boca e queixo
	if v > M - 0.15:
		a = u / (MW * 0.55)
		b = (v - (M + k[8] * 2.0 + 0.06)) / 0.035
		lum -= 0.11 * (1.0 + 0.7 * k[29]) * exp(-a * a - b * b)
		a = (au - MW * 1.05) / 0.05
		b = (v - M) / 0.04
		lum -= 0.08 * exp(-a * a - b * b)
		a = (u + 0.06) / 0.2
		b = (v - 0.86) / 0.07
		lum += 0.07 * exp(-a * a - b * b)
		if k[9] > 0.0:
			a = u / 0.025
			b = (v - 0.9) / 0.06
			lum -= 0.08 * exp(-a * a - b * b)
	a = (u + 0.04) / 0.04
	b = (v - (N + M) * 0.5) / 0.05
	lum += 0.03 * exp(-a * a - b * b)
	if k[27] > 0.0 and v > N and v < M:
		# Filtro marcado: duas colunas claras e o sulco no meio, entre o nariz e o lábio
		var wv2 := _g(v - (N + M) * 0.5, 0.045)
		lum += 0.05 * k[27] * (_g(u - 0.055, 0.02) + _g(u + 0.055, 0.02) * 0.6) * wv2
		lum -= 0.04 * k[27] * _g(u + 0.005, 0.022) * wv2
	if k[28] > 0.0:
		# Olheira funda: o sulco sob a pálpebra e a luz no alto da maçã logo abaixo
		lum -= 0.08 * k[28] * _g2(au - X * 0.78, v - (E + 0.16), 0.13, 0.02)
		lum += 0.035 * k[28] * _g2(au - X * 0.85, v - (E + 0.22), 0.14, 0.03)
	# Olheiras e flacidez com a idade
	if k[10] > 0.0:
		a = (au - X) / 0.18
		b = (v - (E + 0.13)) / 0.035
		lum -= 0.07 * k[10] * exp(-a * a - b * b)
		a = (au - MW * 1.3) / 0.12
		b = (v - 0.8) / 0.1
		lum -= 0.05 * k[10] * exp(-a * a - b * b)
	if k[14] > 0.05:
		a = (au - X * 0.9) / 0.2
		b = (v - (E + 0.11)) / 0.045
		lum -= 0.09 * k[14] * exp(-a * a - b * b)
	# Rosto fino: maçãs saltadas e bochecha funda
	if k[15] > 0.01:
		lum -= 0.12 * k[15] * _g2(au - 0.6, v - 0.43, 0.13, 0.13)
		lum += 0.07 * k[15] * _g2(au - 0.58, v - 0.12, 0.16, 0.06)
		lum -= 0.05 * k[15] * _g2(au - 0.88, v + 0.28, 0.1, 0.14)
	# Idade: papada lateral, bolsas sob os olhos e têmporas fundas
	if k[16] > 0.01:
		lum -= 0.1 * k[16] * _g2(au - MW * 1.55, v - 0.84, 0.09, 0.07)
		lum += 0.03 * k[16] * _g2(au - MW * 1.8, v - 0.72, 0.1, 0.06)
	if k[17] > 0.01:
		lum -= 0.07 * k[17] * _g2(au - X, v - (E + 0.17), 0.12, 0.022)
		lum += 0.04 * k[17] * _g2(au - X, v - (E + 0.12), 0.12, 0.03)
	if k[18] > 0.01:
		lum -= 0.06 * k[18] * _g2(au - 0.86, v + 0.3, 0.1, 0.15)
	# Sorriso: as maçãs sobem e ganham luz
	if k[19] > 0.01:
		lum += 0.06 * k[19] * _g2(au - 0.45, v - 0.2, 0.14, 0.08)
		lum -= 0.03 * k[19] * _g2(au - 0.45, v - 0.32, 0.14, 0.04)
	# Gordo: bochechas cheias e dobra do queixo duplo
	if k[20] > 0.01:
		lum += 0.05 * k[20] * _g2(au - 0.55, v - 0.45, 0.2, 0.15)
		lum -= 0.1 * k[20] * _g2(u, v - 1.0, 0.36, 0.04)
		lum -= 0.05 * k[20] * _g2(au - 0.8, v - 0.75, 0.12, 0.15)
	# Manchas de tom (pele não é uniforme); pele bonita é mais uniforme
	for bl: Array in _blotches:
		a = (u - float(bl[0])) / float(bl[2])
		b = (v - float(bl[1])) / float(bl[2])
		lum += float(bl[3]) * exp(-a * a - b * b) * (1.0 - k[21] * 0.7)
	# Pele muito clara não estoura no branco: a luz forte entra num "ombro" suave, como numa foto
	if lum > _lum_knee:
		var room := _lum_top - _lum_knee
		lum = _lum_knee + room * (1.0 - exp(-(lum - _lum_knee) / room))
	var col := _shade(_skin, lum)
	# Pele translúcida: na passagem da luz para a sombra o tom esquenta um pouco (sangue sob a pele)
	var term := 4.0 * diff * (1.0 - diff)
	col = col.lerp(Color(0.78, 0.36, 0.28), 0.07 * term)
	# Rubor nas bochechas, nariz e queixo
	a = (au - 0.52) / 0.22
	b = (v - 0.25) / 0.13
	var blush := 0.55 * exp(-a * a - b * b)
	a = u / NW
	b = (v - (N - 0.05)) / 0.06
	blush += 0.35 * exp(-a * a - b * b)
	a = u / 0.2
	b = (v - 0.9) / 0.08
	blush += 0.2 * exp(-a * a - b * b)
	col = col.lerp(Color(0.85, 0.32, 0.3), clampf(blush * k[11] * 0.18, 0.0, 0.3))
	# Sombra da barba feita (zona da barba, bem suave)
	if k[12] > 0.02 and v > N - 0.05:
		# A linha desce na frente da bochecha e sobe para a costeleta; a passagem é larga (a faixa
		# estreita marcava um degrau na altura do nariz, com a testa parecendo mais branca)
		var line := lerpf(N + 0.02, (N + M) * 0.5 + 0.04, smoothstep(MW * 0.8, MW * 1.5, au)) - 0.3 * smoothstep(0.6, 1.0, au)
		var dens := smoothstep(line - 0.12, line + 0.14, v)
		a = u / MW
		b = (v - M) / (k[8] * 2.2 + 0.03)
		dens *= smoothstep(0.8, 1.1, sqrt(a * a + b * b))
		col = col.lerp(_shadow_col, dens * k[12] * 0.24)
	# Brilho especular (mais visível em pele escura)
	var hx := _half.x
	var hy := _half.y
	var hz := _half.z
	var spec := pow(maxf(0.0, nx * hx + ny * hy + nz * hz), 26.0)
	a = (u + 0.5) / 0.2
	b = (v - 0.08) / 0.1
	spec *= k[13] * (0.6 + 0.8 * (fore * 0.9 + ridge_hl + exp(-a * a - b * b))) * (0.5 if _mlon else 1.0)
	return Color(minf(col.r + spec, 1.0), minf(col.g + spec * 0.97, 1.0), minf(col.b + spec * 0.93, 1.0))


static func _hash2(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## Ruído suave (0..1) para manchas e falhas com aparência natural.
static func _vnoise(x: float, y: float) -> float:
	var ix := floori(x)
	var iy := floori(y)
	var fx := x - ix
	var fy := y - iy
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a := lerpf(_hash2(ix, iy), _hash2(ix + 1, iy), fx)
	var b := lerpf(_hash2(ix, iy + 1), _hash2(ix + 1, iy + 1), fx)
	return lerpf(a, b, fy)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _age_lines() -> void:
	var f := _f
	var wr: float = f["wrinkles"]
	_age_spots()
	if wr <= 0.0:
		return
	var lw := maxf(0.7, _s * 0.005)
	var dark := Color(_skin.darkened(0.5), 0.16 + minf(wr, 1.4) * 0.3)
	var light := Color(_skin.lightened(0.25), 0.06 + minf(wr, 1.2) * 0.1)
	var lr := RandomNumberGenerator.new()
	lr.seed = int(f["blotch_seed"]) + 3
	# Testa: linhas horizontais que não atravessam a testa inteira e se quebram no meio
	var lines := 1 + int(wr * 3.0)
	var raise: float = float(f.get("brow_raise", 0.0))
	for k in lines:
		var y := -0.64 - k * 0.07 + _E
		var span := lerpf(0.34, 0.5, lr.randf()) * (1.0 - k * 0.08)
		var a0 := lr.randf_range(-0.08, 0.05)
		for part in 2:
			var pts := PackedVector2Array()
			var u0 := a0 - span if part == 0 else a0 + lr.randf_range(0.02, 0.08)
			var u1 := a0 - lr.randf_range(0.02, 0.08) if part == 0 else a0 + span
			for i in 8:
				var t := float(i) / 7.0
				var u := lerpf(u0, u1, t)
				pts.append(_px(u, y - 0.03 * cos(u * 2.2) + 0.008 * sin(t * 9.0 + k) - raise * 0.01))
			var al := (0.6 + raise * 0.4) * (1.0 - k * 0.12)
			_r_polyline(pts, Color(dark, dark.a * al), lw, true)
			var hl := PackedVector2Array()
			for p in pts:
				hl.append(p + Vector2(0, lw * 1.2))
			_r_polyline(hl, Color(light, light.a * al), lw, true)
	# Linhas entre as sobrancelhas (quem franze a testa)
	var knit: float = maxf(float(f.get("brow_in", 0.0)), 0.0) + wr * 0.4
	if knit > 0.3:
		for sx: float in [-1.0, 1.0]:
			_r_line(_px(sx * 0.05, _E - float(f["brow_gap"]) + 0.02), _px(sx * 0.07, _E - float(f["brow_gap"]) - 0.1), Color(dark, dark.a * minf(1.0, knit) * 0.8), lw * 0.9, true)
	if wr > 0.3:
		# Pés de galinha: leque de rugas curvas no canto de fora dos olhos
		for sx: float in [-1.0, 1.0]:
			var ox := sx * (_X + float(f["eye_w"]) + 0.04)
			for k in 2 + int(wr * 2.0):
				var ang := lerpf(-0.5, 0.55, float(k) / (1.0 + int(wr * 2.0)))
				var a := _px(ox, _E + ang * 0.05)
				var dir := Vector2(sx * cos(ang), sin(ang) * 0.9)
				var mid := a + Vector2(dir.x * _fw, dir.y * _fh) * 0.06
				var b := a + Vector2(dir.x * _fw, dir.y * _fh) * (0.1 + wr * 0.03) + Vector2(0, _fh * 0.01)
				_r_polyline(PackedVector2Array([a, mid, b]), Color(dark, dark.a * 0.7), lw * 0.8, true)
	if wr > 0.2:
		# Sulco nasolabial e linha de marionete
		for sx: float in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 7:
				var t := float(i) / 6.0
				var u := sx * lerpf(_NW * 1.25, _MW * 1.12, t) + sx * 0.04 * sin(PI * t)
				pts.append(_px(u, lerpf(_N - 0.03, _M + 0.05, t)))
			_r_polyline(pts, Color(dark, dark.a * (0.85 if sx > 0 else 0.55)), lw * 1.2, true)
	if wr > 0.6:
		for sx: float in [-1.0, 1.0]:
			_r_polyline(PackedVector2Array([_px(sx * _MW * 1.05, _M + 0.05), _px(sx * _MW * 1.12, _M + 0.14), _px(sx * _MW * 1.18, _M + 0.24)]), Color(dark, dark.a * 0.55), lw, true)
		# Rugas finas sob os olhos
		for sx: float in [-1.0, 1.0]:
			var pts := PackedVector2Array()
			for i in 6:
				var t := float(i) / 5.0
				pts.append(_px(sx * (_X - 0.1 + t * 0.2), _E + 0.12 + 0.02 * sin(PI * t)))
			_r_polyline(pts, Color(dark, dark.a * 0.45), lw * 0.7, true)
	if wr > 0.85:
		# Lábio de cima com rugas verticais (código de barras)
		for i in 5:
			var u := lerpf(-_MW * 0.6, _MW * 0.6, i / 4.0)
			_r_line(_px(u, _M - float(f["lip_u"]) * 2.0 - 0.02), _px(u * 1.05, _M - float(f["lip_u"]) * 2.0 - 0.055), Color(dark, dark.a * 0.35), lw * 0.6, true)


## Manchas de sol e da idade na testa, têmporas e maçãs.
func _age_spots() -> void:
	var sp: float = float(_f.get("age_spots", 0.0))
	if sp <= 0.05 or _s < 70.0:
		return
	var r := RandomNumberGenerator.new()
	r.seed = int(_f.get("spot_seed", 1))
	for i in int(14 * sp):
		var u := r.randf_range(-0.8, 0.8)
		var v := r.randf_range(-0.75, 0.3)
		if absf(u) < 0.5 and v > -0.2:
			u = signf(u) * r.randf_range(0.5, 0.8)
		var rr := _fw * r.randf_range(0.02, 0.05)
		_fill(_ellipse(_px(u, v), rr, rr * r.randf_range(0.7, 1.0), 10), Color(_skin.darkened(0.25).lerp(Color("#7A4A2A"), 0.3), r.randf_range(0.12, 0.28) * sp))


func _marks(rng: RandomNumberGenerator) -> void:
	var f := _f
	if bool(f["freckles"]):
		var n := int(40 * clampf(_det, 0.5, 1.5))
		for i in n:
			var sx := -1.0 if i % 2 == 0 else 1.0
			var u := sx * rng.randf_range(0.0, 0.62)
			var v := rng.randf_range(-0.05, 0.3) - (0.12 if absf(u) < 0.2 else 0.0)
			_r_circle(_px(u, v), maxf(0.5, _s * rng.randf_range(0.0025, 0.0045)), Color(_skin.darkened(0.3).lerp(Color("#8A4A2A"), 0.3), rng.randf_range(0.25, 0.55)))
	# Marcas de acne e poros abertos
	var bl: float = float(f.get("blemish", 0.0))
	if bl > 0.05:
		for i in int(30 * bl * clampf(_det, 0.4, 1.5)):
			var u := rng.randf_range(-0.75, 0.75)
			var v := rng.randf_range(-0.6, 0.75)
			if absf(u) < 0.45 and v > -0.1 and v < 0.25:
				u = signf(u) * rng.randf_range(0.45, 0.75)
			var p := _px(u, v)
			var r := maxf(0.5, _s * rng.randf_range(0.003, 0.006))
			if rng.randf() < 0.5:
				_r_circle(p, r, Color(0.7, 0.25, 0.2, rng.randf_range(0.12, 0.25)))
			else:
				_r_circle(p, r, Color(_skin.darkened(0.25), 0.25))
				_r_circle(p + Vector2(-r * 0.3, -r * 0.3), r * 0.5, Color(_skin.lightened(0.2), 0.2))
	# Papada
	var fat: float = f["fat"]
	if fat > 0.62:
		var amt := (fat - 0.62) / 0.38
		var pts := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			pts.append(_px(lerpf(-0.5, 0.5, t), 1.02 + 0.07 * sin(PI * t)))
		_r_polyline(pts, Color(_skin.darkened(0.4), 0.3 * amt), maxf(0.8, _s * 0.007), true)
	if bool(f["mole"]):
		var mp: Vector2 = f["mole_pos"]
		_r_circle(_px(mp.x, mp.y), maxf(0.7, _s * 0.005), _skin.darkened(0.5))
	if bool(f["scar"]):
		var sp: Vector2 = f["scar_pos"]
		var a := _px(sp.x, sp.y)
		var b := a + Vector2(_fw * 0.12, _fh * 0.07)
		_r_line(a, b, Color(_skin.lightened(0.2), 0.6), maxf(0.8, _s * 0.006), true)
		_r_line(a + Vector2(0, 1), b + Vector2(0, 1), Color(_skin.darkened(0.3), 0.3), maxf(0.6, _s * 0.004), true)


# ---------------------------------------------------------------------------
# Fundo, corpo, orelhas
# ---------------------------------------------------------------------------

func _background() -> void:
	var circle := _ellipse(_c, _R, _R, 24 if _s < 90.0 else 40)
	_radial(_c, circle, 3 if _s < 90.0 else 5, func(p: Vector2, t: float, _i: int) -> Color:
		var d := (p - _c) / _R
		var lum := 1.12 - 0.3 * t * t + 0.1 * (-d.x * 0.5 - d.y * 0.8)
		return Color(minf(bg_color.r * lum, 1.0), minf(bg_color.g * lum, 1.0), minf(bg_color.b * lum, 1.0)))


## Profundidade atrás do jogador: um halo claro do lado da luz e a sombra que cabeça e ombros
## projetam no fundo, para o busto "descolar" do fundo como num recorte de foto.
func _backdrop_depth() -> void:
	if _s < 60.0:
		return
	var glow := _hc + Vector2(-_fw * 0.35, -_fh * 0.25)
	var halo := _ellipse(glow, _fw * 2.1, _fh * 1.9, 32)
	_radial(glow, halo, 4, func(_p: Vector2, t: float, _i: int) -> Color:
		return Color(1, 1, 1, 0.07 * (1.0 - smoothstep(0.0, 1.0, t))))
	var sc := _hc + Vector2(_fw * 0.22, _fh * 0.4)
	var shade := _ellipse(sc, _fw * 1.45, _fh * 1.35, 32)
	_radial(sc, shade, 4, func(_p: Vector2, t: float, _i: int) -> Color:
		return Color(0, 0, 0, 0.2 * (1.0 - smoothstep(0.35, 1.0, t))))
	var bc := Vector2(_hc.x + _s * 0.03, _c.y + _s * 0.4)
	var body := _ellipse(bc, _s * 0.52, _s * 0.22, 32)
	_radial(bc, body, 4, func(_p: Vector2, t: float, _i: int) -> Color:
		return Color(0, 0, 0, 0.22 * (1.0 - smoothstep(0.3, 1.0, t))))


## Geometria do tronco: pescoço que se abre no trapézio, ombros arredondados e golas que
## abraçam o pescoço. Tudo em pixels, calculado a partir do tamanho do rosto.
var _nwt := 0.0 # meia largura do pescoço
var _ynb := 0.0 # base do pescoço (onde o trapézio começa)
var _ynotch := 0.0 # fúrcula (entre as clavículas)
var _sw := 0.0 # meia largura dos ombros
var _ysp := 0.0 # altura do ombro
var _chin_y := 0.0


func _body_setup() -> void:
	var f := _f
	var s := _s
	var build: float = f.get("build", 0.5)
	_chin_y = _hc.y + _fh * (1.0 + float(f.get("chin_len", 0.0)))
	_nwt = _fw * float(f.get("neck_w", 0.68)) * (1.0 + 0.1 * float(f["fat"]))
	# Pescoço de atleta: nunca um "palito" embaixo de um rosto fino, mas também nunca mais largo que
	# a mandíbula (aí vira uma "coluna")
	_nwt = minf(maxf(_nwt, _fw * 0.6), _fw * float(f["jaw"]) * 0.95 * 0.92)
	_ynb = _chin_y + s * (0.058 + 0.01 * build)
	_ynotch = _chin_y + s * (0.1 + 0.01 * build)
	_sw = s * (0.41 + 0.07 * build)
	_ysp = _ynb + s * (0.085 - 0.02 * build)


static func _bez(a: Vector2, c: Vector2, b: Vector2, n: int, from_t: float = 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := lerpf(from_t, 1.0, float(i) / n)
		out.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return out


## Lado direito do tronco, de dentro (pescoço ou gola) para fora (braço). `t0` corta o começo
## do trapézio (a gola cobre essa parte); com `neck` inclui a lateral do pescoço.
func _torso_side(t0: float, neck: bool) -> PackedVector2Array:
	var s := _s
	var x0 := _hc.x
	var n := 4 if _s < 90.0 else 8
	var out := PackedVector2Array()
	var r1 := Vector2(x0 + _nwt * 1.03, _ynb - s * 0.022)
	if neck:
		for i in 4:
			var q := float(i) / 3.0
			out.append(Vector2(x0 + _nwt * lerpf(0.96, 1.0, q), lerpf(_hc.y + _fh * 0.35, r1.y - s * 0.012, q)))
	var r2 := Vector2(x0 + _sw * 0.72, _ysp - s * 0.006)
	out.append_array(_bez(r1, Vector2(x0 + _nwt * 1.1 + s * 0.025, _ynb + s * 0.004), r2, n, t0))
	var sh := _bez(r2, Vector2(x0 + _sw * 0.99, _ysp), Vector2(x0 + _sw * 1.05, _ysp + s * 0.085), n)
	sh.remove_at(0)
	out.append_array(sh)
	out.append(Vector2(x0 + _sw * 1.08, _c.y + s * 0.56))
	return out


static func _mirror(pts: PackedVector2Array, cx: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(2.0 * cx - pts[i].x, pts[i].y))
	return out


## Linha de cima de uma peça: lado esquerdo (de fora para dentro) + meio + lado direito.
func _torso_top(t0: float, neck: bool, middle: PackedVector2Array) -> PackedVector2Array:
	var right := _torso_side(t0, neck)
	var top := _mirror(right, _hc.x)
	top.append_array(middle)
	top.append_array(right)
	return top


## Malha entre uma linha de cima e o fundo do retrato (pontos intermediários para a luz).
func _drape(top: PackedVector2Array, layers: int, shader: Callable) -> void:
	var bottom := PackedVector2Array()
	var yb := _c.y + _s * 0.56
	for p in top:
		bottom.append(Vector2(p.x, maxf(yb, p.y)))
	_strip(top, bottom, layers, shader)


## Decote: arco (gola redonda), V (fundo `depth`) ou V curto da polo, de N_E para N_D.
func _neckline(kind: int) -> PackedVector2Array:
	var s := _s
	var x0 := _hc.x
	var n := 8 if _s < 90.0 else 16
	var out := PackedVector2Array()
	var y0 := _ynb - s * 0.022
	var rx := _nwt * 1.03
	match kind:
		0, 2: # V (camisa) e V curto (polo)
			var bot := Vector2(x0, _ynotch + s * (0.075 if kind == 0 else 0.03))
			var half := n / 2
			for i in half + 1:
				var q := float(i) / half
				out.append(Vector2(x0 - rx * (1.0 - q), lerpf(y0, bot.y, pow(q, 1.25))) + Vector2(0, -s * 0.012 * sin(q * PI)))
			for i in range(1, half + 1):
				var q := 1.0 - float(i) / half
				out.append(Vector2(x0 + rx * (1.0 - q), lerpf(y0, bot.y, pow(q, 1.25))) + Vector2(0, -s * 0.012 * sin(q * PI)))
		3: # gola alta: acompanha o pescoço mais em cima
			for i in n + 1:
				var a := PI - PI * float(i) / n
				out.append(Vector2(x0 + rx * cos(a), y0 - s * 0.03 + (_ynotch - y0 - s * 0.02) * sin(a)))
		4: # careca larga
			for i in n + 1:
				var a := PI - PI * float(i) / n
				out.append(Vector2(x0 + rx * 1.12 * cos(a), y0 + (_ynotch - y0 + s * 0.02) * sin(a)))
		_: # redonda
			for i in n + 1:
				var a := PI - PI * float(i) / n
				out.append(Vector2(x0 + rx * cos(a), y0 + (_ynotch - y0 + s * 0.004) * sin(a)))
	return out


## Faixa (ribana) ao longo de uma linha, para fora (para baixo) com espessura `th`.
func _band(line: PackedVector2Array, th: float, col: Color, up: bool = false) -> void:
	var outer := PackedVector2Array()
	for i in line.size():
		var a := line[maxi(0, i - 1)]
		var b := line[mini(line.size() - 1, i + 1)]
		var nrm := Vector2(-(b - a).y, (b - a).x).normalized()
		if (nrm.y < 0.0) != up:
			nrm = -nrm
		outer.append(line[i] + nrm * th)
	var x0 := _hc.x
	var sw := _sw
	_strip(line, outer, 2, func(p: Vector2, _t: float, w: float) -> Color:
		var lum := 1.0 - 0.22 * (p.x - x0) / sw - 0.2 * (1.0 - w if not up else w) + 0.08 * sin(w * PI)
		return _shade(col, lum))
	if _s >= 100.0:
		var step := maxi(2, int(line.size() / 10.0))
		for i in range(0, line.size(), step):
			_r_line(_cl(line[i].lerp(outer[i], 0.15)), _cl(line[i].lerp(outer[i], 0.9)), Color(0, 0, 0, 0.08), maxf(0.5, _s * 0.003), true)


func _skin_torso_col(p: Vector2) -> Color:
	var f := _f
	var s := _s
	var x := p.x - _hc.x
	var y := p.y
	var fat: float = f["fat"]
	var lum: float
	if y < _ynb:
		var dx := x / _nwt
		lum = 0.84 - 0.1 * dx - 0.2 * smoothstep(0.55, 1.05, absf(dx))
	else:
		var dx := x / _sw
		lum = 0.84 - 0.16 * dx - 0.12 * smoothstep(0.3, 1.0, absf(dx))
	# Sombra do queixo e da mandíbula sobre o pescoço
	var nx := clampf(x / (_fw * 0.9), -1.0, 1.0)
	var sh_y := _chin_y + s * (0.018 + 0.015 * fat) - s * 0.03 * nx * nx
	lum -= 0.24 * (1.0 - smoothstep(sh_y - s * 0.025, sh_y + s * 0.018, y))
	lum -= 0.06 * (1.0 - smoothstep(_chin_y, _ynb, y)) * smoothstep(0.3, 1.0, absf(x) / _nwt)
	# Trapézio
	lum += 0.05 * _g2((absf(x) - _nwt * 1.5) / (s * 0.05), (y - _ynb - s * 0.02) / (s * 0.02), 1.0, 1.0)
	# Esternocleidomastoide
	var ms := 0.07 * (1.0 - fat * 0.7)
	for sx: float in [-1.0, 1.0]:
		var a := Vector2(_hc.x + sx * _nwt * 0.92, _chin_y - s * 0.03)
		var b := Vector2(_hc.x + sx * _nwt * 0.16, _ynotch - s * 0.004)
		var d := _seg_dist(p, a, b)
		var inner := signf((b - a).cross(p - a)) * sx
		lum += ms * _g(d, s * 0.012) * (1.0 if sx < 0 else 0.5)
		lum -= ms * 0.8 * _g(d - s * 0.018, s * 0.01) * (1.0 if inner < 0 else 0.0)
	# Pomo de adão
	if age >= 17:
		var ay := _chin_y + s * 0.055
		lum += 0.06 * _g2(x / (s * 0.012), (y - ay) / (s * 0.016), 1.0, 1.0) * (1.0 - fat)
		lum -= 0.05 * _g2(x / (s * 0.014), (y - ay - s * 0.02) / (s * 0.01), 1.0, 1.0)
	# Fúrcula e clavículas
	lum -= 0.13 * _g2(x / (s * 0.022), (y - _ynotch) / (s * 0.014), 1.0, 1.0)
	var ax := absf(x)
	if ax > s * 0.015 and ax < _sw * 0.8:
		var cy := _ynotch - s * 0.004 + (ax - s * 0.015) * 0.12 - s * 0.012 * sin(clampf(ax / (_sw * 0.8), 0.0, 1.0) * PI)
		var dd := y - cy
		var fade := smoothstep(_sw * 0.8, _sw * 0.55, ax)
		lum += (0.07 * _g(dd, s * 0.008) - 0.08 * _g(dd - s * 0.017, s * 0.01)) * fade * (1.0 - fat * 0.6)
	var c := _shade(_skin, lum * 0.97)
	return c.lerp(Color(0.8, 0.35, 0.3), 0.03 + 0.03 * float(f["rosy"]))


## Bordas suaves do pescoço e do colo contra o fundo.
func _skin_edges() -> void:
	var side := _torso_side(0.0, true)
	for pts: PackedVector2Array in [side, _mirror(side, _hc.x)]:
		_aa_edge(pts, _skin_torso_col)


## Bordas suaves dos ombros da roupa contra o fundo.
func _cloth_edges(t0: float, color_at: Callable) -> void:
	var side := _torso_side(t0, false)
	for pts: PackedVector2Array in [side, _mirror(side, _hc.x)]:
		_aa_edge(pts, color_at)


func _cloth_lum(p: Vector2, neck_low: float) -> float:
	var s := _s
	var X := (p.x - _hc.x) / _sw
	var Y := (p.y - _ysp) / (s * 0.2)
	var lum := 1.0 - 0.2 * X - 0.1 * Y
	lum -= 0.28 * smoothstep(0.78, 1.04, absf(X)) * smoothstep(-0.4, 0.3, Y)
	lum += 0.07 * _g2(absf(X) - 0.72, Y + 0.25, 0.18, 0.2) * (1.0 if X < 0 else 0.4)
	# Sombra embaixo da gola e do queixo
	lum -= 0.16 * _g2((p.x - _hc.x) / (_nwt * 1.5), (p.y - neck_low - s * 0.012) / (s * 0.035), 1.0, 1.0)
	# Dobras do tecido perto das axilas
	lum += 0.035 * sin(X * 11.0 + Y * 6.0) * smoothstep(0.4, 0.85, absf(X)) * smoothstep(0.0, 0.6, Y)
	lum -= 0.04 * _g(X, 0.04) * smoothstep(0.1, 0.5, Y) * 0.5
	return lum * 0.97


## Leva um ponto "plano" do tecido (x = distância pelo peito a partir do meio) para a tela,
## vestido num tronco cilíndrico: o que está no meio fica igual, o que vai para os lados encolhe
## e sobe um pouco — listras verticais afinam nas laterais e faixas horizontais fazem curva.
func _wrap(flat: Vector2) -> Vector2:
	var r := _sw * 0.92
	var a := clampf((flat.x - _hc.x) / r, -1.52, 1.52)
	return Vector2(_hc.x + r * sin(a), flat.y - _s * 0.028 * (1.0 - cos(a)))


## Coordenadas do KitView (0.25..0.75 = frente da camisa) para o plano do tecido no retrato.
func _kit_flat(q: Vector2) -> Vector2:
	return Vector2(_hc.x + (q.x - 0.5) / 0.25 * _sw * 1.12, _ynotch + (q.y - 0.12) * _s * 0.75)


## Parte da camisa do KitView que aparece no retrato (peito e ombros). As faixas são recortadas
## nela antes de vestir o tronco: pontos muito fora dela se amontoariam na curva das laterais e
## a faixa (diagonais, aspas) sumiria.
const KIT_WINDOW := [Vector2(0.2, 0.0), Vector2(0.8, 0.0), Vector2(0.8, 0.75), Vector2(0.2, 0.75)]


func _kit_band_pts(pattern: String, third: bool = false) -> Array:
	# Faixas do uniforme (coordenadas do KitView) vestidas no tronco do retrato
	var out: Array = []
	var bands: Array = KitView.pattern_bands3(pattern) if third else KitView.pattern_bands(pattern)
	for raw: PackedVector2Array in bands:
		for band in Geometry2D.intersect_polygons(raw, PackedVector2Array(KIT_WINDOW)):
			if band.size() < 3:
				continue
			var pts := PackedVector2Array()
			var n := band.size()
			for i in n:
				var a := band[i]
				var b := band[(i + 1) % n]
				for k in 12:
					pts.append(_wrap(_kit_flat(a.lerp(b, k / 12.0))))
			out.append(pts)
	return out


## Cor do uniforme (c1 principal, c2 secundária, c3 detalhes), com as cores do retrato como reserva.
func _kit_col(key: String, fallback: Color) -> Color:
	var v: Variant = kit.get(key, "")
	if v is Color:
		return v
	if String(v) != "":
		return Color(String(v))
	return fallback


func _body() -> void:
	var f := _f
	var s := _s
	_body_setup()
	var layers := 4 if s < 90.0 else 7
	# Gola: a do uniforme do clube (mesmas chaves do KitView) ou a sorteada
	var collar := int(f["collar"])
	var henley := false
	var ck := String(kit.get("collar", kit_collar))
	var ringer := false
	var zip := false
	match ck:
		"v", "crossover":
			collar = 0
		"round":
			collar = 1
		"ringer":
			collar = 1
			ringer = true
		"wide":
			collar = 4
		"henley", "laced":
			collar = 1
			henley = true
		"polo", "retro":
			collar = 2
		"mandarin":
			collar = 3
		"zip":
			collar = 3
			zip = true
	if suit:
		_suit_body(layers)
		return
	var line := _neckline(collar)
	var neck_low := line[line.size() / 2].y
	var body_col := _kit_col("c1", shirt_color)
	var c2 := _kit_col("c2", trim_color)
	var trim := _kit_col("c3", c2)
	if trim.is_equal_approx(body_col):
		trim = body_col.darkened(0.35)
	var pattern := String(kit.get("pattern", kit_pattern))
	var sleeve := String(kit.get("sleeve", ""))
	var kit_trim := String(kit.get("trim", "none"))
	# Estampa tom sobre tom: tons da própria cor principal, como no KitView
	var pat_col := c2
	var pat_col3 := trim
	if bool(kit.get("tonal", false)):
		pat_col = KitView.tone_of(body_col)
		pat_col3 = pat_col.lerp(body_col, 0.5)
	# Parte de dentro da gola, atrás do pescoço
	if collar == 2 or collar == 3:
		var back := PackedVector2Array()
		var rx := _nwt * 1.08
		var hgt := s * (0.055 if collar == 2 else 0.04)
		for i in 13:
			var a := PI + PI * i / 12.0
			back.append(Vector2(_hc.x + rx * cos(a), _ynb - s * 0.02 + hgt * sin(a)))
		back.append(Vector2(_hc.x + rx, _ynb + s * 0.01))
		back.append(Vector2(_hc.x - rx, _ynb + s * 0.01))
		_fill(back, (trim if collar == 2 else body_col).darkened(0.45))
	else:
		var back := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			back.append(Vector2(_hc.x + _nwt * 1.06 * cos(a), _ynb - s * 0.024 + s * 0.02 * sin(a)))
		_r_polyline(back, trim.darkened(0.4), maxf(1.0, s * 0.02), true)
	# Pescoço e colo
	_drape(_torso_top(0.0, true, PackedVector2Array()), layers, func(p: Vector2, _t: float, _w: float) -> Color:
		return _skin_torso_col(p))
	_skin_edges()
	_neck_tattoo()
	# Camisa
	var t0 := 0.06
	_drape(_torso_top(t0, false, line), layers, func(p: Vector2, _t: float, _w: float) -> Color:
		return _shade(body_col, _cloth_lum(p, neck_low)))
	_cloth_edges(t0, func(p: Vector2) -> Color:
		return _shade(body_col, _cloth_lum(p, neck_low)))
	var shirt := _torso_top(t0, false, line)
	shirt.append(Vector2(_hc.x + _sw * 1.1, _c.y + s * 0.6))
	shirt.append(Vector2(_hc.x - _sw * 1.1, _c.y + s * 0.6))
	var panels: Array = []
	var panels3: Array = []
	if pattern != "" and pattern != "plain":
		panels.append_array(_kit_band_pts(pattern))
		panels3.append_array(_kit_band_pts(pattern, true))
	var sleeve_panels: Array = []
	# Mangas de outra cor: raglan (costura do pescoço à axila) ou manga contrastante no ombro
	if sleeve == "contrast" or sleeve == "raglan":
		for sx: float in [-1.0, 1.0]:
			var sp := PackedVector2Array()
			# x relativo ao centro, y absoluto
			if sleeve == "raglan":
				sp = PackedVector2Array([Vector2(_nwt * 1.2, _ynb - s * 0.03), Vector2(_sw * 1.3, _ynb - s * 0.05), Vector2(_sw * 1.3, _c.y + s * 0.6), Vector2(_sw * 0.86, _c.y + s * 0.6)])
			else:
				sp = PackedVector2Array([Vector2(_sw * 0.8, _ysp - s * 0.06), Vector2(_sw * 1.3, _ysp - s * 0.06), Vector2(_sw * 1.3, _c.y + s * 0.6), Vector2(_sw * 0.9, _c.y + s * 0.6)])
			var poly := PackedVector2Array()
			var n := sp.size()
			for i in n:
				for k in 6:
					var q := sp[i].lerp(sp[(i + 1) % n], k / 6.0)
					poly.append(Vector2(_hc.x + sx * q.x, q.y))
			sleeve_panels.append(poly)
	# Recorte pelo círculo do retrato como polígono (prender ponto a ponto na borda cruzava o
	# contorno das faixas largas, e a faixa não era desenhada).
	var disc := _clip_poly()
	for layer in [[panels, pat_col], [panels3, pat_col3], [sleeve_panels, c2]]:
		var col: Color = layer[1]
		for band: PackedVector2Array in layer[0]:
			for part in Geometry2D.intersect_polygons(band, shirt):
				for piece in Geometry2D.intersect_polygons(part, disc):
					var cols := PackedColorArray()
					for i in piece.size():
						cols.append(_shade(col, _cloth_lum(piece[i], neck_low)))
					if not Geometry2D.triangulate_polygon(piece).is_empty():
						_r_polygon(piece, cols)
	# Costura do ombro (ou as três listras da manga)
	for sx: float in [-1.0, 1.0]:
		var a := Vector2(_hc.x + sx * _nwt * 1.25, _ynb - s * 0.004)
		var b := Vector2(_hc.x + sx * _sw * 0.92, _ysp + s * 0.012)
		if sleeve == "stripes":
			for k in 3:
				var d := Vector2(0, s * 0.012 * (k - 1))
				_r_line(_cl(a.lerp(b, 0.35) + d), _cl(b + Vector2(sx * _sw * 0.12, s * 0.02) + d), trim, maxf(0.8, s * 0.007), true)
		elif sleeve == "shoulder_stripe" or kit_trim in ["shoulders", "both"]:
			# Friso ou vivo no ombro, na cor dos detalhes
			var w := s * (0.016 if sleeve == "shoulder_stripe" else 0.009)
			_r_line(_cl(a), _cl(b + Vector2(sx * _sw * 0.1, s * 0.015)), _shade(trim, _cloth_lum(a.lerp(b, 0.5), neck_low)), maxf(1.0, w), true)
		else:
			_r_line(_cl(a), _cl(b), Color(0, 0, 0, 0.1), maxf(0.6, s * 0.004), true)
	# Escudo, fornecedor e patrocinador no peito
	_chest_marks(body_col, c2, trim, neck_low)
	# Gola
	var lw := s * 0.02
	match collar:
		0, 1, 4:
			_band(line, lw * (1.1 if collar == 0 else (1.35 if collar == 4 else 1.0)), trim)
			if ringer:
				# Friso duplo: segunda linha fina logo abaixo da gola
				var low := PackedVector2Array()
				for p in line:
					low.append(p + Vector2(0, lw * 1.6))
				_band(low, lw * 0.45, trim)
			if henley:
				_placket(line[line.size() / 2], trim, body_col, 3)
		3:
			_band(line, s * 0.035, trim, true)
			var bx := _hc.x
			if zip:
				_r_line(_cl(Vector2(bx, neck_low - s * 0.03)), _cl(Vector2(bx, neck_low + s * 0.07)), trim.darkened(0.25), maxf(1.0, s * 0.008), true)
			_r_circle(Vector2(bx, neck_low - s * 0.012), maxf(0.8, s * 0.007), trim.darkened(0.35))
		2:
			_polo_collar(line, trim, body_col)


## Escudo do clube (lado do coração), marca de material e patrocinador master (se houver),
## impressos no tecido: seguem a curvatura do peito e recebem a mesma luz e as mesmas dobras.
func _chest_marks(body_col: Color, c2: Color, trim: Color, neck_low: float) -> void:
	var s := _s
	if s < 70.0:
		return
	var y := _ynotch + s * 0.085
	# Escudo
	var cflat := Vector2(_hc.x + _sw * 0.36, y)
	var cs := s * 0.078
	if _crest_tex != null:
		_decal(_crest_tex, cflat, Vector2(cs, cs), Color(0.97, 0.97, 0.97), neck_low)
	else:
		var ec := _wrap(cflat)
		var r := s * 0.028
		if _inside(ec, r * 1.5):
			var edge := c2 if absf(c2.get_luminance() - body_col.get_luminance()) > 0.2 else trim
			var lum := _cloth_lum(ec, neck_low)
			var shield := PackedVector2Array([ec + Vector2(-r, -r), ec + Vector2(r, -r), ec + Vector2(r, r * 0.25), ec + Vector2(0, r * 1.25), ec + Vector2(-r, r * 0.25)])
			_fill(shield, _shade(edge, lum))
			var inner := PackedVector2Array()
			for p in shield:
				inner.append(ec + (p - ec) * 0.72)
			_fill(inner, _shade(body_col.lerp(edge, 0.35), lum))
			_r_line(ec + Vector2(-r * 0.5, -r * 0.2), ec + Vector2(r * 0.5, -r * 0.2), Color(_shade(edge, lum), 0.9), maxf(0.6, s * 0.004), true)
	# Fornecedor: logo pequeno do outro lado
	var sup: Dictionary = kit.get("sup", {}) if kit.get("sup") is Dictionary else {}
	if not sup.is_empty():
		var sc := _wrap(Vector2(_hc.x - _sw * 0.36, y - s * 0.004))
		if _inside(sc, s * 0.04):
			var ink := _shade(Color(String(kit["supc"])) if String(kit.get("supc", "")) != "" else _ink_on(sup, body_col), _cloth_lum(sc, neck_low))
			_supplier_logo(sc, s * 0.022, String(sup.get("logo", "")), String(sup.get("n", "")), ink)
	# Patrocinador master no peito (o que couber no retrato)
	var sp: Dictionary = kit.get("sp", {}) if kit.get("sp") is Dictionary else {}
	var name := String(sp.get("n", "")).to_upper()
	if name == "" or s < 90.0:
		return
	var ink_sp := Color(String(kit["spc"])) if String(kit.get("spc", "")) != "" else _ink_on(sp, body_col)
	var sy := _ynotch + s * 0.19
	if _sponsor_tex != null:
		var aspect := DecalCache.aspect(_sponsor_tex)
		var h := s * 0.058
		var w := minf(_sw * 1.05, h * aspect)
		h = w / maxf(aspect, 0.1)
		_decal(_sponsor_tex, Vector2(_hc.x, sy), Vector2(w, h), ink_sp, neck_low)
		return
	var font := get_theme_font(&"font", &"Big")
	if font == null:
		font = ThemeDB.fallback_font
	var fs := int(s * 0.05)
	var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var maxw := _sw * 1.0
	if tw > maxw:
		fs = int(fs * maxw / tw)
		tw = font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pos := Vector2(_hc.x - tw * 0.5, _ynotch + s * 0.2)
	if fs >= 6 and _inside(Vector2(_hc.x, pos.y), 0.0) and pos.y < _c.y + _R * 0.95:
		var lum := _cloth_lum(Vector2(_hc.x, sy), neck_low)
		_r_string(font, pos, name, fs, Color(_shade(ink_sp, lum), 0.92))


## Estampa (textura) impressa no tecido: malha que acompanha o peito, com a luz do tecido por vértice.
func _decal(tex: Texture2D, center: Vector2, sz: Vector2, tint: Color, neck_low: float) -> void:
	var nx := 8
	var ny := 3
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in ny + 1:
		for i in nx + 1:
			var uv := Vector2(float(i) / nx, float(j) / ny)
			var p := _wrap(center + (uv - Vector2(0.5, 0.5)) * sz)
			if not _inside(p):
				p = _cl(p)
			pts.append(p)
			uvs.append(uv)
			var lum := _cloth_lum(p, neck_low) * 1.02
			cols.append(Color(minf(tint.r * lum, 1.0), minf(tint.g * lum, 1.0), minf(tint.b * lum, 1.0), tint.a))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 2, a, a + nx + 2, a + nx + 1])
	_r_tex_tri(idx, pts, cols, uvs, tex)


## Logos genéricos de material esportivo (as mesmas formas do KitView), já sombreados.
func _supplier_logo(c: Vector2, u: float, logo: String, name: String, col: Color) -> void:
	var P := func(x: float, y: float) -> Vector2: return _cl(c + Vector2(x, y) * u)
	match logo:
		"curva":
			_fill(PackedVector2Array([P.call(-1.0, 0.1), P.call(-0.6, 0.6), P.call(0.2, 0.4), P.call(1.1, -0.5), P.call(0.1, 0.1), P.call(-0.55, 0.3)]), col)
		"barras":
			for i in 3:
				var x := -0.8 + i * 0.6
				var hh := 0.5 + i * 0.35
				_fill(PackedVector2Array([P.call(x, 0.6), P.call(x + 0.35, 0.6), P.call(x + 0.35 + hh * 0.5, 0.6 - hh), P.call(x + hh * 0.5, 0.6 - hh)]), col)
		"triangulo":
			for i in 3:
				var yy := 0.6 - i * 0.45
				var hw := 1.0 - i * 0.33
				_fill(PackedVector2Array([P.call(-hw, yy), P.call(hw, yy), P.call(hw * 0.8, yy - 0.3), P.call(-hw * 0.8, yy - 0.3)]), col)
		"raio":
			_fill(PackedVector2Array([P.call(0.3, -0.9), P.call(-0.6, 0.15), P.call(-0.05, 0.15), P.call(-0.3, 0.9), P.call(0.6, -0.2), P.call(0.05, -0.2)]), col)
		"asas":
			_fill(PackedVector2Array([P.call(-1.0, -0.5), P.call(0.0, 0.1), P.call(1.0, -0.5), P.call(0.0, 0.6)]), col)
		"diamante":
			_r_polyline(PackedVector2Array([P.call(0, -0.8), P.call(0.7, 0), P.call(0, 0.8), P.call(-0.7, 0), P.call(0, -0.8)]), col, maxf(0.8, u * 0.25), true)
		"trevo":
			for a in [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]:
				_r_circle(c + Vector2(cos(a), sin(a)) * u * 0.42, u * 0.38, col)
		"estrela":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 0.9 if i % 2 == 0 else 0.38
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(_cl(c + Vector2(cos(a), sin(a)) * u * rr))
			_fill(pts, col)
		"chevron":
			for i in 2:
				var yy := -0.3 + i * 0.55
				_r_polyline(PackedVector2Array([P.call(-0.8, yy), P.call(0, yy + 0.45), P.call(0.8, yy)]), col, maxf(0.8, u * 0.28), true)
		_:
			_r_arc(c, u * 0.75, PI * 0.15, PI * 1.15, 10, col, maxf(0.8, _s * 0.006), true)
			_r_circle(c + Vector2(u * 0.25, -u * 0.1), maxf(0.6, u * 0.22), col)


## Tatuagem na lateral do pescoço (escrita, tribal, estrela ou asas).
func _neck_tattoo() -> void:
	var f := _f
	var kind := int(f.get("tattoo", 0))
	if kind <= 0 or _s < 60.0:
		return
	var sx := float(f.get("tattoo_side", 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(f.get("tattoo_seed", 1))
	var dark := clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0)
	var ink := Color(0.1, 0.12, 0.17, lerpf(0.6, 0.42, dark))
	var lw := maxf(0.7, _s * 0.0045)
	var cx := _hc.x + sx * _nwt * 0.52
	var top := _chin_y + _s * 0.035
	var bot := _ynb - _s * 0.004
	var mid := (top + bot) * 0.5
	match kind:
		1: # escrita: linhas cursivas inclinadas
			for k in 3:
				var yy := lerpf(top, bot, 0.2 + k * 0.27)
				var pts := PackedVector2Array()
				var ln := rng.randf_range(0.55, 0.8)
				for i in 14:
					var t := float(i) / 13.0
					pts.append(Vector2(cx - sx * _nwt * 0.3 + sx * _nwt * ln * t, yy + _s * 0.0055 * sin(t * 22.0 + k * 2.0 + rng.randf() * 0.5) - t * _s * 0.012))
				_r_polyline(pts, ink, lw, true)
		2: # tribal: pontas curvas
			for k in 4:
				var a := Vector2(cx - sx * _nwt * 0.25, lerpf(top, bot, 0.1 + k * 0.22))
				var b := a + Vector2(sx * _nwt * 0.55, -_s * 0.02)
				var c := a + Vector2(sx * _nwt * 0.25, _s * 0.015)
				var pts := PackedVector2Array([a, a.lerp(c, 0.5) + Vector2(0, -_s * 0.006), b, c, a])
				_fill(pts, ink)
		3: # estrela
			var r := _s * 0.024
			var pts := PackedVector2Array()
			for i in 11:
				var rr := r if i % 2 == 0 else r * 0.42
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(Vector2(cx, mid) + Vector2(cos(a), sin(a)) * rr)
			_r_polyline(pts, ink, lw * 1.1, true)
		4: # asas
			for k in 4:
				var base := Vector2(cx - sx * _nwt * 0.2, mid + _s * 0.012)
				var tip := base + Vector2(sx * _nwt * (0.35 + k * 0.1), -_s * (0.035 - k * 0.006))
				_r_polyline(PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(0, -_s * 0.01), tip]), ink, lw, true)
		5: # rosa: espiral de pétalas e duas folhas
			var cen := Vector2(cx, mid)
			var pts5 := PackedVector2Array()
			for i in 26:
				var t := float(i) / 25.0
				var a := t * TAU * 2.2
				pts5.append(cen + Vector2(cos(a), sin(a)) * _s * (0.004 + 0.02 * t))
			_r_polyline(pts5, ink, lw, true)
			for sgn: float in [-1.0, 1.0]:
				var lf := cen + Vector2(sgn * _s * 0.02, _s * 0.022)
				_fill(PackedVector2Array([cen + Vector2(0, _s * 0.018), lf + Vector2(0, -_s * 0.006), lf, lf + Vector2(-sgn * _s * 0.008, _s * 0.004)]), ink)
		6: # cruz
			var c6 := Vector2(cx, mid)
			_r_line(c6 + Vector2(0, -_s * 0.03), c6 + Vector2(0, _s * 0.03), ink, lw * 1.6, true)
			_r_line(c6 + Vector2(-_s * 0.016, -_s * 0.012), c6 + Vector2(_s * 0.016, -_s * 0.012), ink, lw * 1.6, true)
		7: # coroa
			var b7 := Vector2(cx - _s * 0.024, mid + _s * 0.012)
			var w7 := _s * 0.048
			_r_polyline(PackedVector2Array([b7, b7 + Vector2(0, -_s * 0.024), b7 + Vector2(w7 * 0.25, -_s * 0.012), b7 + Vector2(w7 * 0.5, -_s * 0.03),
				b7 + Vector2(w7 * 0.75, -_s * 0.012), b7 + Vector2(w7, -_s * 0.024), b7 + Vector2(w7, 0), b7]), ink, lw, true)
		8: # números romanos (uma data)
			var y8 := mid
			var x8 := cx - sx * _nwt * 0.3
			for i in 9:
				var tall := rng.randf() < 0.7
				var px := x8 + sx * i * _s * 0.007
				if tall:
					_r_line(Vector2(px, y8 - _s * 0.009), Vector2(px, y8 + _s * 0.009), ink, lw, true)
				else:
					_r_line(Vector2(px - _s * 0.004, y8 - _s * 0.009), Vector2(px + _s * 0.004, y8 + _s * 0.009), ink, lw, true)
		9: # terço: contas descendo pelo pescoço e a cruz
			for i in 9:
				var t9 := float(i) / 8.0
				var p9 := Vector2(cx - sx * _nwt * 0.15 * sin(t9 * PI), lerpf(top, bot - _s * 0.012, t9))
				_r_circle(p9, maxf(0.7, _s * 0.0032), ink)
			var cb := Vector2(cx, bot - _s * 0.004)
			_r_line(cb + Vector2(0, -_s * 0.01), cb + Vector2(0, _s * 0.006), ink, lw, true)
			_r_line(cb + Vector2(-_s * 0.005, -_s * 0.004), cb + Vector2(_s * 0.005, -_s * 0.004), ink, lw, true)
		10: # ramo de folhas subindo pelo pescoço
			var stem := PackedVector2Array()
			for i in 12:
				var t10 := float(i) / 11.0
				stem.append(Vector2(cx + sx * _nwt * 0.12 * sin(t10 * 3.0), lerpf(bot, top, t10)))
			_r_polyline(stem, ink, lw, true)
			for i in 5:
				var q := stem[2 + i * 2]
				var sgn2 := 1.0 if i % 2 == 0 else -1.0
				_fill(PackedVector2Array([q, q + Vector2(sgn2 * _s * 0.014, -_s * 0.006), q + Vector2(sgn2 * _s * 0.018, -_s * 0.014), q + Vector2(sgn2 * _s * 0.004, -_s * 0.008)]), ink)
		11: # manga no ombro: padrão denso aparecendo na borda da camisa
			var sh := Vector2(_hc.x + sx * _nwt * 1.9, bot + _s * 0.01)
			for k in 7:
				var a0 := -PI * 0.5 + sx * (0.2 + k * 0.18)
				var r0 := _s * (0.018 + (k % 3) * 0.008)
				_r_polyline(PackedVector2Array([sh + Vector2(cos(a0), sin(a0)) * r0 * 0.4, sh + Vector2(cos(a0 + 0.3), sin(a0 + 0.3)) * r0, sh + Vector2(cos(a0 + 0.6), sin(a0 + 0.6)) * r0 * 0.6]), ink, lw, true)
		12: # nome do filho em letra cursiva grande, na lateral do pescoço
			var pts12 := PackedVector2Array()
			var x0 := cx - sx * _nwt * 0.35
			for i in 22:
				var t12 := float(i) / 21.0
				pts12.append(Vector2(x0 + sx * _nwt * 0.8 * t12, mid + _s * 0.01 * sin(t12 * 26.0) - t12 * _s * 0.018))
			_r_polyline(pts12, ink, lw * 1.2, true)


static func _ink_on(sp: Dictionary, bg: Color) -> Color:
	for key in ["t", "c"]:
		var c := Color(String(sp.get(key, "#FFFFFF")))
		if absf(c.get_luminance() - bg.get_luminance()) > 0.35:
			return c
	return Color.WHITE if bg.get_luminance() < 0.55 else Color("#15171B")


func _placket(bot: Vector2, trim: Color, body_col: Color, buttons: int) -> void:
	var s := _s
	var pw := s * 0.016
	var plk := PackedVector2Array([bot + Vector2(-pw, -s * 0.004), bot + Vector2(pw, -s * 0.004), bot + Vector2(pw, s * 0.08), bot + Vector2(-pw, s * 0.08)])
	var pc := PackedColorArray()
	for i in plk.size():
		pc.append(_shade(trim, _cloth_lum(plk[i], bot.y)))
		plk[i] = _cl(plk[i])
	_r_polygon(plk, pc)
	for k in buttons:
		var bp := bot + Vector2(0, s * (0.015 + 0.025 * k))
		if _inside(bp, 2.0):
			_r_circle(bp, maxf(0.6, s * 0.005), body_col.lightened(0.25))


func _polo_collar(line: PackedVector2Array, trim: Color, body_col: Color) -> void:
	var s := _s
	var x0 := _hc.x
	var bot := line[line.size() / 2]
	# Carcela com botões
	var pw := s * 0.018
	var plk := PackedVector2Array([bot + Vector2(-pw, -s * 0.004), bot + Vector2(pw, -s * 0.004), bot + Vector2(pw, s * 0.1), bot + Vector2(-pw, s * 0.1)])
	var pc := PackedColorArray()
	for i in plk.size():
		pc.append(_shade(body_col, _cloth_lum(plk[i], bot.y) + 0.04))
		plk[i] = _cl(plk[i])
	_r_polygon(plk, pc)
	_r_line(_cl(bot + Vector2(pw, 0)), _cl(bot + Vector2(pw, s * 0.1)), Color(0, 0, 0, 0.18), maxf(0.6, s * 0.004), true)
	for k in 2:
		var bp := bot + Vector2(0, s * (0.03 + 0.045 * k))
		if _inside(bp, 2.0):
			_r_circle(bp, maxf(0.7, s * 0.006), trim.lightened(0.3))
	# Abas da gola dobradas sobre os ombros
	for sx: float in [-1.0, 1.0]:
		var a := Vector2(x0 + sx * _nwt * 0.97, _ynb - s * 0.05)
		var b := Vector2(x0 + sx * s * 0.004, bot.y + s * 0.004)
		var c := Vector2(x0 + sx * _nwt * 0.7, bot.y + s * 0.045)
		var d := Vector2(x0 + sx * _nwt * 1.5, _ynb + s * 0.012)
		var flap := PackedVector2Array([a, b.lerp(a, 0.02), b, c, d])
		var shadow := PackedVector2Array()
		for p in flap:
			shadow.append(_cl(p + Vector2(s * 0.004, s * 0.008)))
		_fill(shadow, Color(0, 0, 0, 0.22))
		var cols := PackedColorArray()
		for i in flap.size():
			flap[i] = _cl(flap[i])
			var lum := 1.02 - 0.2 * (flap[i].x - x0) / _sw - (0.12 if i == 0 else 0.0) + (0.05 if i == 3 else 0.0)
			cols.append(_shade(trim, lum))
		_r_polygon(flap, cols)
		var edge := PackedVector2Array([flap[2], flap[3], flap[4]])
		_r_polyline(edge, Color(trim.darkened(0.45), 0.7), maxf(0.6, s * 0.005), true)


func _suit_body(layers: int) -> void:
	var s := _s
	var x0 := _hc.x
	var jacket := Color("#262A31")
	var shirt := Color("#E4E8EE")
	# Pescoço e colo
	_drape(_torso_top(0.0, true, PackedVector2Array()), layers, func(p: Vector2, _t: float, _w: float) -> Color:
		return _skin_torso_col(p))
	_skin_edges()
	# Camisa social (gola alta em volta do pescoço)
	var line := _neckline(3)
	var neck_low := line[line.size() / 2].y
	_drape(_torso_top(0.04, false, line), layers, func(p: Vector2, _t: float, _w: float) -> Color:
		return _shade(shirt, _cloth_lum(p, neck_low) + 0.06))
	# Gravata: nó e lâmina
	var ky := neck_low - s * 0.004
	var knot := PackedVector2Array([Vector2(x0 - s * 0.024, ky - s * 0.012), Vector2(x0 + s * 0.024, ky - s * 0.012), Vector2(x0 + s * 0.014, ky + s * 0.028), Vector2(x0 - s * 0.014, ky + s * 0.028)])
	var blade := PackedVector2Array([Vector2(x0 - s * 0.016, ky + s * 0.024), Vector2(x0 + s * 0.016, ky + s * 0.024), Vector2(x0 + s * 0.034, _c.y + s * 0.44), Vector2(x0, _c.y + s * 0.47), Vector2(x0 - s * 0.034, _c.y + s * 0.44)])
	var tie := trim_color.darkened(0.1)
	for k in 2:
		var poly: PackedVector2Array = blade if k == 0 else knot
		var cols := PackedColorArray()
		for i in poly.size():
			poly[i] = _cl(poly[i])
			cols.append(_shade(tie, 1.05 - 0.09 * (poly[i].x - x0) / (s * 0.03) - (0.15 if k == 0 and i < 2 else 0.0)))
		_r_polygon(poly, cols)
	_r_line(_cl(Vector2(x0 - s * 0.006, ky + s * 0.04)), _cl(Vector2(x0 + s * 0.004, _c.y + s * 0.42)), Color(1, 1, 1, 0.12), maxf(0.8, s * 0.006), true)
	# Pontas da gola da camisa
	for sx: float in [-1.0, 1.0]:
		var pt := PackedVector2Array([Vector2(x0 + sx * _nwt * 1.0, _ynb - s * 0.05), Vector2(x0 + sx * s * 0.022, ky + s * 0.008), Vector2(x0 + sx * _nwt * 0.55, ky + s * 0.05), Vector2(x0 + sx * _nwt * 1.28, _ynb + s * 0.0)])
		var sh := PackedVector2Array()
		for p in pt:
			sh.append(_cl(p + Vector2(s * 0.003, s * 0.007)))
		_fill(sh, Color(0, 0, 0, 0.18))
		var cols := PackedColorArray()
		for i in pt.size():
			pt[i] = _cl(pt[i])
			cols.append(_shade(shirt, 1.0 - 0.18 * (pt[i].x - x0) / _sw - (0.1 if i == 0 else 0.0)))
		_r_polygon(pt, cols)
		_r_polyline(PackedVector2Array([pt[1], pt[2], pt[3]]), Color(0.55, 0.58, 0.64, 0.6), maxf(0.6, s * 0.004), true)
	# Paletó: duas metades que deixam o V da camisa e da gravata
	var yb := _c.y + s * 0.56
	for sx: float in [-1.0, 1.0]:
		var side := _torso_side(0.3, false)
		var top := PackedVector2Array()
		var nv := 6
		var start := Vector2(x0 + _nwt * 1.12, _ynb + s * 0.002)
		for i in nv + 1:
			var q := float(i) / nv
			top.append(Vector2(lerpf(x0 + s * 0.05, start.x, pow(q, 0.8)), lerpf(yb - s * 0.08, start.y, q)))
		top.reverse()
		var half := PackedVector2Array()
		for i in range(top.size() - 1, -1, -1):
			half.append(top[i])
		half.append_array(side)
		if sx < 0:
			half = _mirror(half, x0)
		_drape(half, layers, func(p: Vector2, _t: float, _w: float) -> Color:
			return _shade(jacket, _cloth_lum(p, neck_low) + 0.05))
		_aa_edge(side if sx > 0 else _mirror(side, x0), func(p: Vector2) -> Color:
			return _shade(jacket, _cloth_lum(p, neck_low) + 0.05))
		# Lapela
		var lap := PackedVector2Array([
			Vector2(x0 + sx * _nwt * 1.12, _ynb + s * 0.002), Vector2(x0 + sx * s * 0.05, yb - s * 0.08),
			Vector2(x0 + sx * s * 0.1, yb - s * 0.12), Vector2(x0 + sx * _sw * 0.42, _ynb + s * 0.075),
			Vector2(x0 + sx * _sw * 0.36, _ynb + s * 0.055), Vector2(x0 + sx * _nwt * 1.55, _ynb + s * 0.012)])
		var cols := PackedColorArray()
		for i in lap.size():
			lap[i] = _cl(lap[i])
			cols.append(_shade(jacket, 1.1 - 0.25 * (lap[i].x - x0) / _sw))
		_r_polygon(lap, cols)
		_r_polyline(PackedVector2Array([lap[0], lap[1]]), Color(0, 0, 0, 0.35), maxf(0.7, s * 0.005), true)
		_r_polyline(PackedVector2Array([lap[2], lap[3], lap[4]]), Color(0, 0, 0, 0.3), maxf(0.6, s * 0.004), true)


func _ears() -> void:
	var f := _f
	var er: float = f["ear"]
	var out: float = f["ear_out"]
	var lobe: float = float(f.get("lobe", 1.0))
	var pointy: float = float(f.get("ear_top", 0.0))
	var cauli: float = float(f.get("cauli", 0.0))
	var asym: float = float(f["asym"])
	for sx: float in [-1.0, 1.0]:
		var ek := er * (1.0 + sx * asym * 0.03)
		var ec := _px(sx * (float(f["cheek_w"]) * 0.97 + out * 0.07), 0.04)
		var ew := _fw * (0.15 + out * 0.04) * ek * float(f.get("ear_width", 1.0))
		var eh := _fh * 0.2 * ek * float(f.get("ear_height", 1.0))
		var rotation := float(f.get("ear_rotate", 0.0)) * sx
		var ep := func(x: float, y: float) -> Vector2:
			return ec + Vector2(x * ew * sx, y * eh).rotated(rotation)
		var pts := PackedVector2Array()
		var en := 12 if _s < 90.0 else 20
		for i in en:
			var a := TAU * i / en
			var y := sin(a)
			# Lóbulo solto (arredondado) ou preso (afina e cola no rosto)
			var bottom := lerpf(0.45, 0.7, lobe)
			var x := cos(a) * (0.8 if y > 0.2 else 1.0) * lerpf(1.0, bottom, clampf(y, 0.0, 1.0))
			x *= lerpf(1.0, float(f.get("ear_lobe_width", 1.0)), smoothstep(0.25, 0.9, y))
			x *= 1.0 + float(f.get("ear_top_full", 0.0)) * _g(y + 0.65, 0.35)
			if y > 0.4 and lobe < 0.5:
				y = lerpf(y, 0.4 + (y - 0.4) * 0.6, 1.0 - lobe)
			# Ponta no alto da orelha
			if pointy > 0.0 and y < -0.5 and cos(a) * sx > -0.2:
				y -= pointy * 0.2 * smoothstep(-0.5, -1.0, y)
			var bump := 1.0 + cauli * (0.08 * sin(a * 5.0 + 1.0) + 0.05 * sin(a * 9.0))
			pts.append(ec + Vector2(x * ew * bump, y * eh * bump).rotated(rotation))
		var lit := -sx
		var em := _radial(ec, pts, _rings(5 if _s >= 140.0 else 3), func(p: Vector2, t: float, _i: int) -> Color:
			var d := (p - ec).rotated(-rotation) / Vector2(ew, eh)
			var lum := 0.8 + 0.1 * lit
			lum -= 0.22 * _g2(d.x + sx * 0.15, d.y + 0.05, 0.4, 0.45)
			lum += 0.1 * smoothstep(0.6, 0.95, t) * (1.0 if d.y < 0.3 else 0.3)
			# Orelha de lutador: cartilagem inchada, com caroços e sombras
			lum += cauli * 0.1 * sin(d.x * 9.0 + d.y * 7.0) * (1.0 - t)
			var c := _shade(_skin, lum)
			return c.lerp(Color(0.85, 0.35, 0.3), 0.08 + 0.05 * float(f["rosy"])))
		_rim(em, pts.size())
		var lw := maxf(0.55, _s * 0.0025)
		if _s >= 140.0:
			# Concha, hélice, anti-hélice em Y e trago têm profundidades próprias.
			var concha := float(f.get("ear_concha", 1.0))
			_soft_spot(ep.call(-0.05, 0.12), ew * 0.45, eh * 0.42, Color(_skin.darkened(0.5), 0.28 * concha))
			_soft_spot(ep.call(-0.3, 0.19), ew * 0.2, eh * 0.19, Color(_skin.darkened(0.65), 0.32 * concha))
			var helix := PackedVector2Array()
			var helix_colors := PackedColorArray()
			for i in 17:
				var t := float(i) / 16.0
				var a := lerpf(-PI * 0.8, PI * 0.65, t)
				helix.append(ep.call(cos(a) * 0.73, sin(a) * 0.79))
				helix_colors.append(Color(_skin.darkened(0.3), sin(PI * t) * 0.38))
			_r_polyline_colors(helix, helix_colors, lw * float(f.get("ear_helix", 1.0)), true)
			var stem := PackedVector2Array([ep.call(0.15, 0.55), ep.call(0.35, 0.22), ep.call(0.26, -0.12), ep.call(0.02, -0.48)])
			var fork := PackedVector2Array([ep.call(0.26, -0.12), ep.call(0.42, -0.36), ep.call(0.38, -0.58)])
			var anti := float(f.get("ear_antihelix", 1.0))
			_r_polyline(stem, Color(_skin.darkened(0.35), 0.26 * anti), lw * 1.1, true)
			_r_polyline(fork, Color(_skin.darkened(0.3), 0.22 * anti), lw, true)
			for i in stem.size():
				stem[i] += Vector2(-lw * 0.7, 0)
			_r_polyline(stem, Color(_skin.lightened(0.15), 0.3), lw * 0.75, true)
			_soft_spot(ep.call(-0.4, 0.24), ew * 0.23 * float(f.get("ear_tragus", 1.0)), eh * 0.2, Color(_skin.lightened(0.12), 0.45))
		else:
			var a0 := -PI * 0.5 if sx > 0 else PI * 0.5
			_r_arc(ec + Vector2(sx * ew * 0.1, -eh * 0.05), ew * 0.55, a0, a0 + PI, 10, Color(_skin.darkened(0.35), 0.45), lw, true)
		if bool(f["earring"]) and sx < 0:
			var er_col := Color("#F2D16B") if int(f["texture_seed"]) % 2 == 0 else Color("#E6E9EE")
			_r_circle(ec + Vector2(0, eh * 0.78), maxf(1.2, _s * 0.012), er_col)
			_r_circle(ec + Vector2(-_s * 0.004, eh * 0.75), maxf(0.5, _s * 0.004), Color(1, 1, 1, 0.8))


# ---------------------------------------------------------------------------
# Olhos, sobrancelhas, nariz, boca
# ---------------------------------------------------------------------------

func _eyes() -> void:
	var f := _f
	var ew := _fw * float(f["eye_w"])
	var eh := _fw * float(f["eye_h"])
	var tilt := _fw * float(f["eye_tilt"])
	var iris_main: Color = f["eye"]
	var ring: float = f.get("eye_ring", 0.0)
	var ring_col: Color = f.get("eye_in", Color("#8A5A26"))
	var limbal: float = f.get("limbal", 0.7)
	var het: int = f.get("hetero", 0)
	var het_side: float = f.get("hetero_side", 1.0)
	var het_ang: float = f.get("hetero_ang", 0.0)
	var eye_b: Color = f.get("eye_b", iris_main)
	var lw := maxf(0.65, _s * 0.0055)
	var mono: bool = f["monolid"]
	var hooded: bool = f["hooded"]
	var asym: float = f["asym"]
	var lid: float = clampf(float(f.get("lid", 0.0)), 0.0, 0.7)
	var squint: float = float(f.get("squint", 0.0))
	var bulge: float = float(f.get("bulge", 0.0))
	var uneven: float = float(f.get("eye_uneven", 0.0))
	var crease2: float = float(f.get("crease2", 0.0))
	var epi: float = float(f.get("epicanthic", 0.0))
	var under: float = float(f.get("under_line", 0.0))
	var scleral: float = float(f.get("scleral", 0.0))
	var lash_k: float = float(f.get("lash_heavy", 0.0))
	var hood_o: float = float(f.get("hood_outer", 0.0))
	var eh0 := eh
	for sx: float in [-1.0, 1.0]:
		# Olhos desiguais (feios): um menor e um pouco mais baixo
		eh = eh0 * (1.0 - (uneven * 0.2 if sx > 0.0 else 0.0))
		var cx := _hc.x + sx * _X * _fw
		var cy := _hc.y + _E * _fh + sx * asym * _fh * 0.012 + (uneven * _fh * 0.018 if sx > 0.0 else 0.0)
		# Pálpebra de cima baixa (encapuzado, cansado, semicerrado) e de baixo subindo no sorriso
		var up_k := (1.0 - lid * 0.55) * (1.0 - squint * 0.25)
		var lo_k := (1.0 + bulge * 0.4 + scleral * 0.3) * (1.0 - squint * 0.5)
		var inner := Vector2(cx - sx * ew, cy + tilt * 0.35 + (eh * 0.12 if mono else 0.0))
		var outer := Vector2(cx + sx * ew, cy - tilt)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 15:
			var t := float(i) / 14.0
			var base := inner.lerp(outer, t)
			var peak := pow(t, float(f.get("eye_upper", 0.78)) if not mono else lerpf(1.0, float(f.get("eye_upper", 1.0)), 0.5))
			# Canto de fora encoberto: a pele da pálpebra desce sobre o terço de fora do olho
			var hood := 1.0 - 0.35 * hood_o * smoothstep(0.5, 0.95, t)
			var canthal := 1.0 - float(f.get("eye_canthal", 0.0)) * exp(-pow((t - 0.12) / 0.12, 2.0))
			upper.append(base + Vector2(0, -sin(PI * peak) * eh * (0.85 if mono else 1.0) * up_k * hood * canthal))
			lower.append(base + Vector2(0, sin(PI * pow(t, float(f.get("eye_lower", 1.15)))) * eh * float(f.get("eye_lower_depth", 0.52)) * lo_k * canthal))
		var sclera := PackedVector2Array(upper)
		for i in range(lower.size() - 2, 0, -1):
			sclera.append(lower[i])
		if _mlon:
			_ml_masks.append(sclera)
		var ecen := Vector2(cx, cy)
		# Pele com espessura em volta do globo ocular, com bordas transparentes.
		# A pálpebra se integra à pele já iluminada, em vez de virar outro contorno.
		if _s >= 140.0:
			var lid_outer := PackedVector2Array()
			for i in upper.size():
				lid_outer.append(upper[i] + Vector2(0, -eh * 0.85 * sin(PI * float(i) / 14.0)))
			_strip(upper, lid_outer, 3, func(_p: Vector2, t: float, w: float) -> Color:
				return Color(_skin.darkened(0.22 * (1.0 - w)), sin(PI * t) * sin(PI * w) * 0.42))
			lid_outer = PackedVector2Array()
			for i in lower.size():
				lid_outer.append(lower[i] + Vector2(0, eh * 0.6 * sin(PI * float(i) / 14.0)))
			_strip(lower, lid_outer, 3, func(_p: Vector2, t: float, w: float) -> Color:
				return Color(_skin.lightened(0.1), sin(PI * t) * sin(PI * w) * 0.28))
		var sc_base := Color("#D9D2C8").lerp(_skin, 0.16)
		_radial(ecen, sclera, 2 if _s < 90.0 else 3, func(p: Vector2, t: float, _i: int) -> Color:
			var lum := 1.0 - 0.32 * t * t - (0.28 if p.y < cy else 0.0) * t
			return _shade(sc_base, lum))
		# Íris com anel escuro, centro claro e sombra da pálpebra
		var iris_col := eye_b if het == 1 and sx == het_side else iris_main
		var sector := het == 2 and sx == het_side
		var ic := Vector2(cx + float(f["gaze"]) * ew * 0.3, cy + eh * 0.12 - bulge * eh * 0.08 - scleral * eh * 0.1)
		var ir := minf(eh * 1.3, ew * 0.47) * float(f.get("iris_scale", 1.0))
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, ir, ir, 12 if _s < 90.0 else 20), sclera):
			if not Geometry2D.is_point_in_polygon(ic, piece):
				_fill(piece, iris_col.darkened(0.3))
				continue
			var im := _radial(ic, piece, 2 if _s < 90.0 else 4, func(p: Vector2, _t: float, _i: int) -> Color:
				var d := p - ic
				var r := d.length() / ir
				var ang := atan2(d.y, d.x)
				var lum := 1.0 + 0.28 * (1.0 - smoothstep(0.3, 0.7, r)) - (0.25 + 0.4 * limbal) * smoothstep(0.72, 1.0, r)
				lum -= 0.4 * (1.0 - smoothstep(-ir * 0.9, -ir * 0.1, d.y))
				lum += (0.08 * sin(ang * 17.0 + sx * 3.0) + 0.05 * sin(ang * 31.0 + 1.7)) * (1.0 - r)
				var base := iris_col
				if sector:
					base = base.lerp(eye_b, (1.0 - smoothstep(0.35, 0.65, absf(angle_difference(ang, het_ang)))) * smoothstep(0.3, 0.45, r))
				# Anel central (heterocromia central, comum em olhos claros)
				base = base.lerp(ring_col, ring * (1.0 - smoothstep(0.4, 0.62, r)))
				return _shade(base, lum))
			if _s >= DETAIL_MIN * 1.5:
				# Fibras, colarete e criptas da íris
				var ipts: PackedVector2Array = im[1]
				var iuv := PackedVector2Array()
				for q in ipts:
					iuv.append((q - ic) / (ir * 2.0) + Vector2(0.5, 0.5))
				_detail(im, iuv, "iris", 0.85)
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, ir * 0.4, ir * 0.4, 14), sclera):
			_fill(piece, Color("#070505"))
		# Anel límbico: a borda da íris escurece e fica suave (só onde a íris aparece)
		if _s >= 90.0:
			var run := PackedVector2Array()
			var ring_c := Color(iris_col.darkened(0.55), 0.35 + 0.35 * limbal)
			for j in 29:
				var a := TAU * j / 28.0
				var rp := ic + Vector2(cos(a), sin(a)) * ir * 0.97
				if Geometry2D.is_point_in_polygon(rp, sclera):
					run.append(rp)
				elif run.size() > 1:
					_r_polyline(run, ring_c, maxf(0.7, ir * 0.12), true)
					run = PackedVector2Array()
				else:
					run = PackedVector2Array()
			if run.size() > 1:
				_r_polyline(run, ring_c, maxf(0.7, ir * 0.12), true)
		# Reflexo da luz do estúdio, recortado pela pálpebra. O ponto branco grande e
		# redondo dava aparência de boneco, sobretudo nos olhos semicerrados.
		var glint_center := ic + Vector2(-ir * 0.28, -ir * 0.32)
		if _s >= 140.0:
			var glint := _ellipse(glint_center, maxf(0.35, ir * 0.12), maxf(0.25, ir * 0.08), 8)
			for piece in Geometry2D.intersect_polygons(glint, sclera):
				_fill(piece, Color(1, 0.98, 0.94, 0.7))
		elif Geometry2D.is_point_in_polygon(glint_center, sclera):
			_r_circle(glint_center, maxf(0.25, ir * 0.1), Color(1, 0.98, 0.94, 0.65))
		# Carúncula (a prega do canto interno cobre)
		_r_circle(inner + Vector2(sx * ew * 0.1, eh * 0.05), maxf(0.6, eh * 0.18), Color(0.85, 0.5, 0.5, 0.55 * (1.0 - 0.8 * epi)))
		# Linha dos cílios (mais grossa por fora) e cílios
		var lash := Color("#2B1D15").lerp(_skin.darkened(0.7), 0.25)
		_r_polyline(upper, Color(lash, minf(1.0, 0.62 + 0.25 * lash_k)), lw * (0.9 + 0.6 * lash_k), true)
		_r_polyline(upper.slice(7), Color(lash, 0.5 + 0.25 * lash_k), lw * (1.25 + 0.7 * lash_k), true)
		var ln := float(f["lashes"]) * (0.7 + 0.35 * lash_k)
		for k in ((5 if lash_k > 0.0 else 3) if _s > (90.0 if lash_k > 0.0 else 110.0) else 0):
			var t := 0.62 + k * 0.08
			var i := int(t * 14.0)
			var p0: Vector2 = upper[mini(i, 14)]
			_r_line(p0, p0 + Vector2(sx * 0.6, -1.0).normalized() * eh * 0.45 * ln, Color(lash, 0.75), lw * 0.7, true)
		_r_line(outer, outer + Vector2(sx * ew * 0.08, -eh * 0.12), Color(lash, 0.4), lw * 0.9, true)
		_r_polyline(lower, Color(lash, 0.22 + 0.12 * lash_k), lw * 0.7, true)
		if epi > 0.0:
			# Prega no canto interno: a pele da pálpebra de cima desce e cobre o canto
			var fold := PackedVector2Array([upper[4] + Vector2(0, -eh * 0.22), inner + Vector2(-sx * ew * 0.02, -eh * 0.16), inner + Vector2(sx * ew * 0.03, eh * 0.12)])
			_r_polyline(fold, Color(_skin.darkened(0.35), 0.32 * epi), lw * 0.8, true)
		if under > 0.0:
			# Sulco da olheira, embaixo da pálpebra de baixo
			var ul := PackedVector2Array()
			for p in lower.slice(1, 12):
				ul.append(p + Vector2(sx * ew * 0.04, eh * 0.55))
			_r_polyline(ul, Color(_skin.darkened(0.38), 0.2 * under), lw * 0.8, true)
		if hood_o > 0.0:
			# Dobra da pele que cai sobre o canto de fora
			var hd := PackedVector2Array()
			for p in upper.slice(6, 15):
				hd.append(p + Vector2(sx * ew * 0.03, -eh * 0.16))
			_r_polyline(hd, Color(_skin.darkened(0.35), 0.3 * hood_o), lw, true)
		var wl := PackedVector2Array()
		for p in lower.slice(2, 13):
			wl.append(p + Vector2(0, lw * 0.6))
		_r_polyline(wl, Color(_skin.lightened(0.25), 0.25), lw * 0.6, true)
		# Dobra da pálpebra
		# Sombra da pálpebra pesada sobre a íris
		if lid > 0.15:
			var ls := PackedVector2Array()
			for p in upper.slice(2, 13):
				ls.append(p + Vector2(0, lw * 0.9))
			_r_polyline(ls, Color(0, 0, 0, 0.18 * lid), lw * 1.6, true)
		if squint > 0.2:
			var sq := PackedVector2Array()
			for p in lower.slice(3, 12):
				sq.append(p + Vector2(0, eh * 0.28))
			_r_polyline(sq, Color(_skin.darkened(0.35), 0.25 * squint), lw * 0.8, true)
		if not mono:
			var crease := PackedVector2Array()
			var off := eh * ((0.38 if hooded else 0.62) + 0.18 * crease2) * (1.0 - lid * 0.4)
			for p in upper.slice(2, 13):
				crease.append(p + Vector2(0, -off))
			var cc := Color(_skin.darkened(0.4), 0.38 + 0.22 * crease2)
			if _s >= 140.0:
				# De perto a dobra é uma sombra macia que some nas pontas, com um vinco fino no meio
				_fade_line(crease, Color(cc, cc.a * 0.3), lw * 2.4)
				_fade_line(crease, cc, lw * (0.55 + 0.2 * crease2))
			else:
				_r_polyline(crease, cc, lw * (0.8 + 0.2 * crease2), true)
			if crease2 > 0.3:
				# Pálpebra dupla marcada: uma segunda dobra, fraca, acima da primeira
				var c2 := PackedVector2Array()
				for p in crease.slice(1, 10):
					c2.append(p + Vector2(0, -eh * 0.2))
				_r_polyline(c2, Color(_skin.darkened(0.3), 0.14 * crease2), lw * 0.7, true)
			var hl := PackedVector2Array()
			for p in crease.slice(2, 9):
				hl.append(p + Vector2(0, -lw * 1.2))
			_r_polyline(hl, Color(_skin.lightened(0.3), 0.12), lw, true)
		else:
			var fold := PackedVector2Array()
			for p in upper.slice(0, 7):
				fold.append(p + Vector2(0, -eh * 0.12))
			_r_polyline(fold, Color(_skin.darkened(0.3), 0.3), lw * 0.8, true)


func _brows(rng: RandomNumberGenerator) -> void:
	var f := _f
	var col: Color = (f["beard_col"] as Color).darkened(0.12)
	if int(f["hair_i"]) in [4, 5, 9, FaceGen.HC_HONEY]: # loiros naturais: sobrancelha no tom do cabelo; tinta não muda a sobrancelha
		col = (f["hair"] as Color).darkened(0.35)
	col = col.lerp(_skin, 0.12)
	var ew := _fw * float(f["eye_w"])
	var th := _fw * float(f["brow_t"])
	var arch := _fw * float(f["brow_arch"])
	var tilt := _fw * float(f["brow_tilt"])
	var blen := ew * 2.3 * (float(f["brow_len"]) / 0.45)
	var dens: float = f["brow_dens"]
	# De perto os pelos ficam finos e em maior número (sorteio próprio para os extras)
	var fine := _s >= 140.0
	var wline := maxf(0.55, _s * 0.0022) if fine else maxf(0.6, _s * 0.0034)
	var xr := RandomNumberGenerator.new()
	xr.seed = int(f["texture_seed"]) + 53
	var asym: float = f["asym"]
	var peak: float = float(f.get("brow_peak", 0.0))
	var messy: float = float(f.get("brow_messy", 0.0))
	var raise: float = float(f.get("brow_raise", 0.0))
	var knit: float = float(f.get("brow_in", 0.0))
	var uneven: float = float(f.get("brow_uneven", 0.0))
	var slit: int = int(f.get("brow_slit", 0))
	var slit_n := slit % 10
	var slit_side := slit / 10
	for sx: float in [-1.0, 1.0]:
		var cx := _hc.x + sx * _X * _fw
		var by := _hc.y + (_E - float(f["brow_gap"])) * _fh - sx * asym * _fh * 0.018
		# Expressão: sobrancelhas sobem (surpresa), descem e se juntam (bravo), uma sobe (desconfiado)
		by -= raise * _fh * 0.07 + (_fh * 0.06 if uneven != 0.0 and signf(uneven) == sx else 0.0)
		var x0 := cx - sx * ew * 1.05
		var path := PackedVector2Array()
		var thick := PackedFloat32Array()
		for i in 12:
			var t := float(i) / 11.0
			var x := x0 + sx * blen * t
			var y := by - arch * sin(PI * minf(t / 0.7, 1.0) * 0.5) * (1.0 if t < 0.7 else 1.0 - (t - 0.7) * 1.8) - tilt * t
			if peak > 0.0:
				# Angulosa: sobe reto até o pico e cai reto
				y = by - arch * (t / 0.62 if t < 0.62 else 1.0 - (t - 0.62) * 2.2) - tilt * t
			y += knit * _fh * 0.065 * pow(1.0 - t, 1.3) - knit * _fh * 0.015 * t
			path.append(Vector2(x, y))
			thick.append(th * lerpf(1.15, 0.35, pow(t, 1.4)))
		# Riscos (falhas raspadas): intervalos em t sem pelos
		var gaps: Array = []
		var here := slit_n > 0 and (slit_side == 3 or (slit_side == 1 and sx < 0.0) or (slit_side == 2 and sx > 0.0))
		if here:
			for k in slit_n:
				var tk := 0.66 + (float(k) - (slit_n - 1) * 0.5) * 0.11
				gaps.append(Vector2(tk - 0.035, tk + 0.035))
		var cuts: Array = [0.0]
		for g: Vector2 in gaps:
			cuts.append(g.x)
			cuts.append(g.y)
		cuts.append(1.0)
		var base_a := 0.42 + (0.3 if _s < 90.0 else 0.0)
		for c in range(0, cuts.size(), 2):
			var ta: float = cuts[c]
			var tb: float = cuts[c + 1]
			if tb - ta < 0.02:
				continue
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			var steps := maxi(2, int((tb - ta) * 14.0) + 1)
			# De perto o miolo da sobrancelha tem borda macia (a faixa chapada virava um bloco)
			var spread := 0.62 if fine else 0.5
			for j in steps + 1:
				var t := lerpf(ta, tb, float(j) / steps)
				var fi := t * 11.0
				var i0 := mini(int(fi), 10)
				var lt := fi - i0
				var p := path[i0].lerp(path[i0 + 1], lt)
				var tk := lerpf(thick[i0], thick[i0 + 1], lt)
				# O risco corta na diagonal (o pelo de cima inclina para fora)
				top.append(p + Vector2(0, -tk * spread))
				bot.append(p + Vector2(0, tk * spread))
			if fine:
				var ba := base_a * dens + 0.1
				_strip(top, bot, 4, func(_p: Vector2, u: float, w: float) -> Color:
					var t := lerpf(ta, tb, u)
					var across := 1.0 - pow(absf(w * 2.0 - 1.0), 2.5)
					var along := lerpf(0.55, 1.0, smoothstep(0.0, 0.2, t)) * (1.0 - 0.35 * smoothstep(0.75, 1.0, t))
					return Color(col, ba * across * along))
				continue
			bot.reverse()
			var poly := PackedVector2Array(top)
			poly.append_array(bot)
			_fill(poly, Color(col, base_a * dens + 0.1))
		var hair_at := func(r: RandomNumberGenerator) -> void:
			var t := pow(r.randf(), 0.85)
			for g: Vector2 in gaps:
				if t > g.x - 0.012 and t < g.y + 0.012:
					return
			var i := mini(int(t * 11.0), 10)
			var lt := t * 11.0 - i
			var p: Vector2 = path[i].lerp(path[i + 1], lt)
			var tk := lerpf(thick[i], thick[i + 1], lt)
			p.y += r.randf_range(-0.45, 0.45) * tk
			var dir: Vector2
			var head := t < 0.18
			if head:
				# Cabeça da sobrancelha: pelos curtos que nascem embaixo e abrem em leque para cima
				p.y += tk * 0.2
				dir = Vector2(sx * lerpf(0.12, 0.5, t / 0.18), -1.0)
			else:
				var a := lerpf(-0.9, 0.3, clampf((t - 0.18) / 0.8, 0.0, 1.0))
				dir = Vector2(sx * cos(a), sin(a))
			# Desvio próprio de cada pelo (sorteio à parte, para não mudar o resto do rosto)
			dir = dir.rotated(xr.randf_range(-0.16, 0.16))
			var ln := (tk * r.randf_range(0.6, 1.05) + _s * 0.002) * (0.72 if head else 1.0)
			if messy > 0.0 and r.randf() < 0.25:
				# Desgrenhada: pelos longos apontando para todo lado
				dir = dir.rotated(r.randf_range(-1.2, 1.2))
				ln *= r.randf_range(1.3, 2.0)
			_r_line(p, p + dir.normalized() * ln, Color(col.darkened(r.randf_range(0.0, 0.2)), r.randf_range(0.35, 0.7)), wline, true)
		var n := int(75 * dens * clampf(_det, 0.4, 1.6))
		for k in n:
			hair_at.call(rng)
		if fine:
			for k in int(n * 0.9):
				hair_at.call(xr)
	if bool(f["unibrow"]):
		for k in int(10 * clampf(_det, 0.5, 1.5)):
			var p := _px(rng.randf_range(-0.15, 0.15), _E - float(f["brow_gap"]) + rng.randf_range(-0.02, 0.02))
			# Pelos do meio abrem para os lados, cada um num ângulo
			var d := Vector2((p.x - _hc.x) / maxf(1.0, _fw * 0.15) * 0.35, -1.0).rotated(xr.randf_range(-0.25, 0.25))
			_r_line(p, p + d.normalized() * _s * 0.008 * xr.randf_range(0.6, 1.0), Color(col, 0.4), wline, true)


func _nose() -> void:
	var f := _f
	var lw := maxf(0.55, _s * 0.0035)
	var dark := _skin.darkened(0.62)
	var nostril: float = float(f.get("nostril", 1.0))
	var nup: float = float(f.get("nose_up", 0.0))
	var hook: float = float(f.get("nose_hook", 0.0))
	var septum: float = maxf(float(f.get("nose_septum", 0.0)), float(f.get("nose_columella", 0.0)))
	var flare: float = float(f.get("nose_flare", 0.0))
	var pinch: float = float(f.get("nose_pinch", 0.0))
	var bulb: float = float(f.get("nose_bulb", 0.0))
	var bump: float = float(f.get("nose_bump", 0.0))
	if hook > 0.0:
		# Ponta caída: a ponta desce sobre as narinas e faz sombra
		_fill(_ellipse(_pxn(0.0, _N + 0.012), _NW * _fw * 0.42, _fh * 0.03 * hook, 12), Color(_skin.darkened(0.15), 0.6))
	for sx: float in [-1.0, 1.0]:
		# Narinas à mostra: mais altas que largas, mais perto do meio e mais escuras
		var nc := _pxn(sx * _NW * (0.45 - 0.07 * septum + 0.08 * flare), _N + 0.004 - nup * 0.012 + hook * 0.012 + septum * 0.004 + float(f.get("alar_height", 0.0)))
		var rx := _NW * _fw * 0.2 * nostril * (1.0 + 0.08 * septum) * (1.0 + sx * float(f.get("nose_asym", 0.0)))
		var ry := _fh * 0.02 * (1.0 + nup * 0.6) * (1.0 - hook * 0.4) * (1.0 + 0.4 * septum)
		if _s >= 140.0:
			# De perto: sombra macia em volta e o furo mais escuro no fundo
			_soft_spot(nc, rx * 2.0, ry * 2.0, Color(dark, 0.22))
			var opening := _ellipse(nc + Vector2(sx * rx * 0.1, 0), rx, ry, 16)
			for i in opening.size():
				opening[i] = nc + (opening[i] - nc).rotated(sx * float(f.get("nostril_angle", 0.0)))
			_fill(opening, Color(dark, 0.38 + 0.1 * septum))
			_soft_spot(nc + Vector2(sx * rx * 0.15, ry * 0.15), rx * 0.75, ry * 0.7, Color(dark.darkened(0.3), 0.35 + 0.1 * septum))
		else:
			_fill(_ellipse(nc, rx * 1.6, ry * 1.6, 12), Color(dark, 0.14))
			_fill(_ellipse(nc + Vector2(sx * rx * 0.1, 0), rx, ry, 12), Color(dark, 0.5 + 0.1 * septum))
		# Asa do nariz (aberta, ou presa num sulco fundo na ponta afilada)
		var wc := _pxn(sx * _NW * (0.82 + 0.16 * flare), _N - 0.03)
		var a0 := PI * 0.5 - sx * 0.6
		var wa := (0.14 if sx < 0 else 0.24) * (1.0 + 0.8 * pinch + 0.3 * flare)
		_r_arc(wc, _NW * _fw * 0.28 * (1.0 + 0.25 * flare - 0.2 * pinch) * float(f.get("alar_round", 1.0)), a0 - sx * PI * 0.9, a0 + sx * 0.2, 10, Color(_skin.darkened(0.4), minf(wa, 0.5)), lw, true)
	if septum > 0.0:
		# Columela: a pele clara entre as narinas
		_fill(_ellipse(_pxn(0.0, _N + 0.008), _NW * _fw * 0.09, _fh * 0.022, 10), Color(_skin.lightened(0.06), 0.35 * septum))
	var side := PackedVector2Array([_pxn(_BW * 1.1, _E + 0.1), _pxn(_BW * 1.3, (_E + _N) * 0.5), _pxn(_NW * 0.75, _N - 0.07)])
	if bump > 0.0:
		# Calombo no dorso: a linha do lado da sombra se abre num morro suave no meio
		side = PackedVector2Array()
		for i in 9:
			var t := float(i) / 8.0
			var u := lerpf(_BW * 1.1, _NW * 0.75, t * t) + _BW * 0.2 * sin(PI * t)
			u += _BW * 0.45 * bump * exp(-pow((t - 0.42) / 0.13, 2.0))
			side.append(_pxn(u, lerpf(_E + 0.1, _N - 0.07, t)))
	_r_polyline(side, Color(_skin.darkened(0.45), 0.14 + 0.06 * bump), lw * 1.2, true)
	var tip := PackedVector2Array()
	var tw := _NW * 0.35 * (1.0 - 0.3 * pinch + 0.25 * bulb) * float(f.get("nose_tip_width", 1.0))
	for i in 9:
		var t := float(i) / 8.0
		tip.append(_pxn(lerpf(-tw, tw, t), _N + 0.018 + sin(PI * t) * (0.012 + 0.01 * bulb)))
	_r_polyline(tip, Color(_skin.darkened(0.4), 0.25), lw, true)
	if bulb > 0.0:
		# Contorno da ponta redonda, do lado da sombra
		_r_arc(_pxn(0.02, _N - 0.05), _NW * _fw * 0.4, -0.2, PI * 0.55, 10, Color(_skin.darkened(0.4), 0.16 * bulb), lw, true)


func _mouth() -> void:
	var f := _f
	var smile: float = f["smile"]
	var mw := _MW * _fw * (1.0 + maxf(0.0, smile - 0.6) * 0.18)
	var mouth_y := _hc.y + _M * _fh
	var ul := _fh * float(f["lip_u"]) * 2.0
	var ll := _fh * float(f["lip_l"]) * 2.0
	var darkness := clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0)
	# O lábio parte da pele já sombreada em volta da boca (a pele "crua" é mais clara que a região
	# da boca e deixava o lábio parecendo aceso) e puxa o tom para o vermelho sem mudar o brilho
	var sk := _shade(_skin, 0.86)
	var red := Color("#A8585A")
	var rr := sk.get_luminance() / maxf(0.05, red.get_luminance())
	var lip := sk.lerp(Color(minf(1.0, red.r * rr), minf(1.0, red.g * rr), minf(1.0, red.b * rr)), 0.38 - darkness * 0.12).darkened(0.06 + darkness * 0.06)
	var lip_up := lip.darkened(0.1 + darkness * 0.14)
	# Em pele escura o lábio de baixo puxa para o rosado, mas no mesmo brilho do lábio (clarear
	# demais parece boca aberta)
	var rose := Color("#9A5A5E")
	var rk := lip.get_luminance() / maxf(0.05, rose.get_luminance())
	var lip_lo := lip.lerp(Color(minf(1.0, rose.r * rk), minf(1.0, rose.g * rk), minf(1.0, rose.b * rk)), darkness * 0.3)
	var corner_y := mouth_y - smile * _fh * 0.03 + float(f.get("corner", 0.0)) * _fh * 0.022
	var bow: float = f["bow"]
	# Canto de um lado mais alto (sorriso de canto) ou boca torta
	var smirk: float = float(f.get("smirk", 0.0)) + float(f.get("mouth_tilt", 0.0)) * 0.5
	var teeth: float = float(f.get("teeth", 0.0))
	var mopen: float = float(f.get("mouth_open", 0.0))
	var asym: float = float(f.get("lip_asym", 0.0))
	var pout: float = float(f.get("pout", 0.0))
	var gap := _fh * (teeth * 0.05 + mopen * 0.09)
	var line := PackedVector2Array()
	var bot := PackedVector2Array()
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw, mw, t)
		var cy := corner_y - smirk * _fh * 0.03 * (t - 0.5) * 2.0 * absf(t - 0.5) * 2.0 * signf(t - 0.5)
		var yb := lerpf(cy, mouth_y + smile * _fh * 0.008, sin(PI * t)) + _fh * 0.008 * float(f.get("lip_tubercle", 0.0)) * _g(t - 0.5, 0.1)
		line.append(Vector2(x, yb))
		bot.append(Vector2(x, yb + gap * pow(sin(PI * t), 0.8)))
		var center_shift := float(f.get("lip_center_shift", 0.0))
		var cupid := ul * 0.3 * bow * _g(t - 0.5 - center_shift, 0.06)
		var lobes := 1.0 + float(f.get("lip_lobes", 0.0)) * 0.25 * (_g(t - 0.35 - center_shift, 0.11) + _g(t - 0.65 - center_shift, 0.11))
		# Assimétrica: um lado do lábio de cima mais cheio que o outro
		var ua := 1.0 + asym * 0.3 * (t - 0.5) * 2.0
		up.append(Vector2(x, lerpf(cy, mouth_y, sin(PI * t)) - pow(sin(PI * t), float(f.get("lip_upper_curve", 1.0))) * ul * ua * lobes + cupid))
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw * 0.9, mw * 0.9, t)
		var tt := lerpf(0.05, 0.95, t)
		var cy := corner_y - smirk * _fh * 0.03 * (tt - 0.5) * 2.0 * absf(tt - 0.5) * 2.0 * signf(tt - 0.5)
		var la := 1.0 - asym * 0.22 * (t - 0.5) * 2.0
		var lower_volume := pow(sin(PI * t), float(f.get("lip_lower_curve", 1.0))) - float(f.get("lip_lower_groove", 0.0)) * 0.15 * _g(t - 0.5, 0.12)
		lo.append(Vector2(x, lerpf(cy, mouth_y, sin(PI * t)) + lower_volume * ll * la + gap * pow(sin(PI * t), 0.8)))
	if gap > 0.5:
		# Boca aberta: interior escuro e a fileira de dentes de cima
		var inside := PackedVector2Array(line)
		var rb := bot.duplicate()
		rb.reverse()
		inside.append_array(rb)
		if not Geometry2D.triangulate_polygon(inside).is_empty():
			_fill(inside, Color("#3A1414"))
			var th := gap * (0.75 if teeth > 0.0 else 0.35)
			var tb := PackedVector2Array()
			for i in range(2, 13):
				var t := float(i) / 14.0
				tb.append(line[i] + Vector2(0, th * pow(sin(PI * t), 0.6)))
			var tpoly := PackedVector2Array(line.slice(2, 13))
			var rtb := tb.duplicate()
			rtb.reverse()
			tpoly.append_array(rtb)
			var tcols := PackedColorArray()
			for i in tpoly.size():
				var q := absf(float(i % 11) / 10.0 - 0.5) * 2.0
				tcols.append(Color("#EDE6DA").darkened(0.08 + 0.3 * q * q))
			if not Geometry2D.triangulate_polygon(tpoly).is_empty():
				_r_polygon(tpoly, tcols)
				for i in range(4, 11, 2):
					_r_line(line[i], tb[i - 2], Color(0.55, 0.45, 0.4, 0.25), maxf(0.5, _s * 0.002), true)
	if _mlon:
		var lu := PackedVector2Array(up)
		var rl := line.duplicate()
		rl.reverse()
		lu.append_array(rl)
		var lb := PackedVector2Array(bot)
		var rlo := lo.duplicate()
		rlo.reverse()
		lb.append_array(rlo)
		_ml_masks.append(lu)
		_ml_masks.append(lb)
	# Faixas seguem a anatomia em vez de triangular um polígono inteiro: os
	# triângulos grandes cruzavam o lábio e formavam placas planas de cor.
	_strip(up, line, 3 if _s >= 140.0 else 1, func(_p: Vector2, t: float, w: float) -> Color:
		var volume := sin(PI * w) * sin(PI * t)
		return lip_up.lightened(0.06 * volume).darkened(0.18 * w))
	_strip(bot, lo, 4 if _s >= 140.0 else 1, func(_p: Vector2, t: float, w: float) -> Color:
		var volume := sin(PI * w) * sin(PI * t)
		var base := lip_lo.lightened(0.12 * volume).darkened(0.15 * (1.0 - w))
		return base.lerp(sk, 0.22 * smoothstep(0.65, 1.0, w)))
	# Brilho do lábio de baixo: mancha macia (a elipse chapada parecia dente de perto)
	var gloss := Color(1, 1, 1, 0.07 + darkness * 0.03 + 0.07 * pout)
	var gc := Vector2(_hc.x - mw * 0.14, mouth_y + ll * 0.48 + gap)
	if _s >= 90.0:
		_soft_spot(gc, mw * (0.3 + 0.1 * pout), ll * (0.24 + 0.07 * pout), Color(gloss, gloss.a * 1.5))
	else:
		_fill(_ellipse(gc, mw * (0.22 + 0.08 * pout), ll * (0.14 + 0.05 * pout), 12), gloss)
	var lw := maxf(0.8, _s * 0.007)
	if _s >= 140.0:
		# Vincos verticais dos lábios (só de perto)
		var lr := RandomNumberGenerator.new()
		lr.seed = int(f["texture_seed"]) + 77
		var vc := Color(lip_lo.darkened(0.3), 0.13)
		for i in 12:
			var t := 0.18 + 0.64 * (float(i) + lr.randf_range(-0.3, 0.3)) / 11.0
			var j := clampi(int(round(t * 14.0)), 1, 13)
			var a := bot[j].lerp(lo[j], 0.15)
			var b := bot[j].lerp(lo[j], lr.randf_range(0.5, 0.85))
			_r_line(a, b + Vector2(lr.randf_range(-1.0, 1.0) * lw * 0.3, 0), vc, maxf(0.5, lw * 0.22), true)
		for i in 7:
			var t := 0.25 + 0.5 * (float(i) + lr.randf_range(-0.3, 0.3)) / 6.0
			var j := clampi(int(round(t * 14.0)), 1, 13)
			_r_line(line[j].lerp(up[j], 0.1), line[j].lerp(up[j], lr.randf_range(0.45, 0.75)), Color(lip_up.darkened(0.3), 0.1), maxf(0.5, lw * 0.22), true)
	# Contornos suaves
	var lip_line: float = float(f.get("lip_line", 0.0))
	var ol := PackedVector2Array(up)
	_r_polyline(ol, Color(lip_up.darkened(0.1), 0.35 + 0.2 * lip_line), lw * 0.8, true)
	if lip_line > 0.0:
		# Contorno definido: a borda clara da pele logo acima do lábio de cima
		var roll := PackedVector2Array()
		for i in range(1, 14):
			roll.append(up[i] + Vector2(0, -lw * 0.75))
		_r_polyline(roll, Color(_skin.lightened(0.2), 0.28 * lip_line), lw * 0.7, true)
	var olo := PackedVector2Array(lo)
	_r_polyline(olo, Color(lip_lo, 0.35), lw * 0.8, true)
	var lc := PackedColorArray()
	for i in line.size():
		var t := float(i) / 14.0
		lc.append(Color("#3A1C1B", 0.3 + 0.35 * sin(PI * t)))
	if gap <= 0.5:
		_r_polyline_colors(line, lc, lw, true)
	var cl: float = float(f.get("corner_lines", 0.0))
	for sx: float in [-1.0, 1.0]:
		var cp0 := line[0 if sx < 0.0 else 14]
		_r_circle(cp0, lw * 0.6, Color(0.1, 0.05, 0.05, 0.14))
		if cl > 0.0:
			# Cantos marcados: o vinco desce do canto da boca
			var cv := PackedVector2Array([cp0 + Vector2(sx * mw * 0.02, 0), cp0 + Vector2(sx * mw * 0.08, _fh * 0.035), cp0 + Vector2(sx * mw * 0.1, _fh * 0.075)])
			_fade_line(cv, Color(_skin.darkened(0.4), 0.32 * cl), lw * 0.9)
	# Covinhas/sulcos de sorriso nos cantos
	if smile > 0.7:
		for sx: float in [-1.0, 1.0]:
			var cp := line[0 if sx < 0.0 else 14]
			_r_arc(cp + Vector2(sx * mw * 0.12, -_fh * 0.01), _fh * 0.035, PI * 0.5 - sx * 1.2, PI * 0.5 + sx * 0.2, 6, Color(_skin.darkened(0.35), 0.22 * (smile - 0.6)), lw * 0.8, true)


## Linha que some nas duas pontas (dobras e vincos da pele).
func _fade_line(pts: PackedVector2Array, col: Color, w: float) -> void:
	var cols := PackedColorArray()
	var n := pts.size()
	for i in n:
		var t := float(i) / maxf(1.0, n - 1.0)
		cols.append(Color(col, col.a * pow(sin(PI * lerpf(0.06, 0.94, t)), 0.7)))
	_r_polyline_colors(pts, cols, w, true)


## Mancha suave (brilho ou sombra): a cor no centro some até a borda da elipse.
func _soft_spot(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var a := col.a
	_radial(c, _ellipse(c, rx, ry, 18), 3, func(_p: Vector2, t: float, _i: int) -> Color:
		var k := 1.0 - t * t
		return Color(col, a * k * k))


func _poly_colors(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		_r_polygon(pts, cols)
		_feather(pts, cols)
	else:
		_fill(pts, cols[0])


# ---------------------------------------------------------------------------
# Barba
# ---------------------------------------------------------------------------

## Densidade (0..1) de pelos da barba `P` no ponto (u, v) do rosto. Sem `patches`, ignora as falhas
## (a malha usa a versão contínua; as falhas ficam nos fios, que têm resolução para desenhá-las).
func _beard_dens(u: float, v: float, P: Dictionary, patches: bool = true) -> float:
	if P.is_empty():
		return 0.0
	var f := _f
	var au := absf(u)
	var th := _th(u, v)
	var sharp: float = P["sh"]
	var soft := lerpf(0.09, 0.035, sharp)
	var ln: float = P["ln"]
	var lip_u: float = f["lip_u"] * 2.0
	var lip_l: float = f["lip_l"] * 2.0
	var d := 0.0
	var d_chin := 0.0
	# Bochechas
	var ch: float = P["ch"]
	var cn: float = P["cn"]
	if ch > 0.0:
		var line := lerpf(_N + 0.02, -0.02 + ch * 0.75, smoothstep(_MW * 0.8, _MW * 1.5, au)) - 0.16 * smoothstep(0.55, 1.0, au)
		var soft_c := soft
		if float(P.get("cl", 0.0)) > 0.0:
			# Linha da bochecha natural: desce em diagonal do canto do nariz até a costeleta, sem o
			# degrau reto ao lado do bigode, e a borda de cima se desfaz aos poucos
			var t := smoothstep(_MW * 0.9, _MW * 2.6, au)
			line = lerpf(_M - 0.03, -0.02 + ch * 0.75, sqrt(t)) - 0.16 * smoothstep(0.55, 1.0, au)
			soft_c = soft * 1.6
		var dc := smoothstep(line - soft_c, line + soft_c, v)
		if cn <= 0.0:
			dc *= smoothstep(_MW * 1.15, _MW * 1.5, au)
		d = maxf(d, dc)
	# Costeletas
	var sd: float = P["sd"]
	if sd > 0.0:
		var sd_end := 0.62 if float(P.get("sdl", 0.0)) > 0.0 else 0.45
		d = maxf(d, sd * smoothstep(0.78, 0.9, th) * smoothstep(-0.34, -0.2, v) * (1.0 - smoothstep(sd_end - 0.15, sd_end, v) * (1.0 if ch <= 0.0 and float(P["jw"]) <= 0.0 else 0.0)))
	# Contorno da mandíbula
	var jw: float = P["jw"]
	if jw > 0.0:
		var band := smoothstep(0.82 - soft, 0.86, th) * smoothstep(-0.1, 0.1, v)
		if float(P.get("thin", 0.0)) > 0.0:
			band = smoothstep(0.9, 0.93, th) * smoothstep(-0.05, 0.12, v)
		if jw < 0.8:
			band *= 1.0 - smoothstep(jw * 1.3, jw * 1.3 + 0.12, au)
		d = maxf(d, band)
	# Queixo
	if cn > 0.0:
		var top := _M + lip_l + 0.05
		var bottom := 1.02 + ln * 0.9
		var cy := (top + bottom) * 0.5
		var ry := (bottom - top) * 0.5 + 0.02
		var rx := _MW * (0.45 + cn * 0.6) * (1.0 + float(P.get("rd", 0.0)) * 0.45) * float(P.get("cnw", 1.0))
		# Cavanhaque triangular: afina em direção à ponta
		rx *= lerpf(1.0, 0.35, clampf((v - cy) / ry, 0.0, 1.0) * float(P.get("tri", 0.0)))
		var ke := 2.0 + 2.5 * float(P.get("sq", 0.0)) * float(v > cy)
		var e := pow(pow(absf(u / rx), ke) + pow(absf((v - cy) / ry), ke), 1.0 / ke)
		d_chin = 1.0 - smoothstep(1.0 - soft * 3.0, 1.0 + soft, e)
		d = maxf(d, d_chin)
	# Bigode
	var mu: int = int(P["mu"])
	if mu > 0:
		var top_y := _N + 0.045
		var bot_y := _M - lip_u * 0.55
		if mu == 2 or mu == 5:
			top_y = _M - lip_u - (0.045 if mu == 2 else 0.055)
			bot_y = _M - lip_u * (0.6 if mu == 2 else 0.45)
		elif mu == 4:
			top_y = _N + 0.025
			bot_y = _M - lip_u * 0.15
		if mu == 6:
			top_y = _N + 0.05
			bot_y = _M - lip_u * 0.45
		elif mu == 7:
			top_y = _M - lip_u - 0.04
			bot_y = _M - lip_u * 0.55
		elif mu == 8:
			top_y = _N + 0.02
			bot_y = _M + lip_l * 0.25
		var wx := _MW * (0.95 if mu == 2 else (1.16 if mu == 4 else (1.22 if mu == 5 else (1.3 if mu == 8 else (1.0 if mu == 7 else 1.08))))) * float(P.get("mw", 1.0))
		top_y -= (bot_y - top_y) * (float(P.get("mh", 1.0)) - 1.0)
		if mu in [1, 4, 6]:
			# O filtro abre uma separação suave no meio do bigode cheio.
			top_y += 0.025 * _g(au, 0.065)
		var yr := smoothstep(top_y - soft, top_y + soft, v) * (1.0 - smoothstep(bot_y - soft * 0.5, bot_y + soft * 0.5, v + au * 0.1))
		var xr := 1.0 - smoothstep(wx - soft, wx + soft, au)
		var dm := yr * xr
		if mu == 2 or mu == 5:
			dm *= lerpf(0.55, 1.0, smoothstep(0.0, 0.035, au))
		# Pontas do bigode descendo nos cantos
		dm = maxf(dm, (1.0 - smoothstep(0.05, 0.05 + soft, absf(au - _MW * 1.02))) * smoothstep(_N + 0.06, _N + 0.1, v) * (1.0 - smoothstep(_M + 0.02, _M + 0.06, v)) * (0.0 if mu == 2 or mu == 5 else 1.0))
		if mu == 5:
			# Bigode inglês: pontas finas que sobem para os lados
			var k := clampf((au - _MW * 1.1) / (_MW * 0.45), 0.0, 1.0)
			var vc := bot_y - 0.02 - k * k * 0.12
			var tip := (1.0 - smoothstep(0.014, 0.014 + soft, absf(v - vc))) * smoothstep(_MW * 1.05, _MW * 1.15, au) * (1.0 - smoothstep(_MW * 1.5, _MW * 1.6, au))
			dm = maxf(dm, tip * (1.0 - k * 0.3))
		if mu == 3:
			var bar := (1.0 - smoothstep(0.07, 0.07 + soft, absf(au - _MW * 1.12))) * smoothstep(_N + 0.06, _N + 0.1, v) * (1.0 - smoothstep(0.93, 1.0, th))
			dm = maxf(dm, bar)
		if mu == 6:
			# Guidão: pontas grossas que viram para cima
			var k6 := clampf((au - _MW) / (_MW * 0.75), 0.0, 1.0)
			var vc6 := bot_y - 0.01 - k6 * k6 * 0.22
			var th6 := 0.034 * (1.0 - k6 * 0.5)
			dm = maxf(dm, (1.0 - smoothstep(th6, th6 + soft * 0.6, absf(v - vc6))) * smoothstep(_MW * 0.9, _MW * 1.0, au) * (1.0 - smoothstep(_MW * 1.72, _MW * 1.8, au)))
		if mu == 7:
			# Fu Manchu: fios finos e compridos descendo dos cantos da boca
			var hw7 := lerpf(0.026, 0.01, clampf((v - _M) / 0.6, 0.0, 1.0))
			var hang := (1.0 - smoothstep(hw7, hw7 + soft, absf(au - _MW * 1.07 - (v - _M) * 0.08))) * smoothstep(_M - 0.05, _M - 0.01, v) * (1.0 - smoothstep(1.25, 1.33, v))
			dm = maxf(dm, hang)
		if mu == 8:
			# Morsa: bigode cheio que cobre o lábio de cima, com a borda de baixo arredondada
			var k8 := clampf(au / wx, 0.0, 1.0)
			var edge8 := bot_y + 0.04 * (1.0 - k8 * k8)
			var top8 := top_y + 0.05 * k8 * k8
			dm = (1.0 - smoothstep(wx * 0.88, wx + soft, au)) * smoothstep(top8 - soft, top8 + soft, v) * (1.0 - smoothstep(edge8 - soft * 0.5, edge8 + soft * 0.5, v))
		d = maxf(d, dm)
	# Cavanhaque fechado: ligação dos cantos da boca ao queixo
	if float(P.get("ci", 0.0)) > 0.0:
		var ring := (1.0 - smoothstep(0.05, 0.05 + soft, absf(au - _MW * 1.04))) * smoothstep(_M - 0.06, _M - 0.02, v) * (1.0 - smoothstep(_M + lip_l + 0.1, _M + lip_l + 0.16, v))
		d = maxf(d, ring)
	# Mosca
	var so: float = P["so"]
	if so > 0.0:
		var sl := float(P.get("sl", 1.0))
		var sy := _M + lip_l + 0.06 + 0.05 * (sl - 1.0)
		d = maxf(d, so * (1.0 - smoothstep(0.7, 1.1, sqrt(pow(u / (0.07 - 0.015 * (sl - 1.0) * float(v > sy)), 2.0) + pow((v - sy) / (0.05 * sl), 2.0)))))
	# Pescoço
	var nk: float = P["nk"]
	# "hw": barba cheia que desce larga (da largura da mandíbula), em vez de uma faixa da largura do pescoço
	var neck_half := _neck_half() * (1.0 + float(P.get("hw", 0.0)))
	var over_neck := smoothstep(0.62, 0.9, v) * (1.0 - smoothstep(neck_half * 0.8, neck_half * 1.02, au))
	if nk > 0.0 and v > 0.6:
		d = maxf(d, nk * over_neck * smoothstep(0.98, 1.04, th) * (1.0 - smoothstep(1.1 + ln, 1.3 + ln, v)))
	# Fora do rosto: a barba tem espessura própria e some aos poucos a partir do contorno. Nas
	# laterais da mandíbula (fundo atrás) quase não passa da pele; embaixo do queixo, sobre o
	# pescoço, a barba comprida desce
	if th > 1.0:
		var reach := lerpf(0.012 + ln * 0.55, (0.03 + ln * 0.9) / 0.6, over_neck)
		if float(P.get("cl", 0.0)) > 0.0:
			# Embaixo do queixo a barba desce em toda a largura do queixo (não numa faixa da largura
			# do pescoço) e, se for curta, só arredonda o contorno
			reach = lerpf(0.012 + ln * 0.55, 0.015 + ln * 1.3, smoothstep(0.62, 0.9, v))
			# Abaixo da ponta do queixo vale só o formato do queixo (arredondado), nunca um bloco reto
			if v > 0.9 and ln >= 0.12 and cn > 0.0:
				# Barba comprida: embaixo do queixo continua da largura da mandíbula e só afina
				# perto da ponta (formato de U/V), em vez de pendurar uma faixa estreita
				var bot := 1.02 + ln * 0.9
				var k := clampf((v - 0.96) / maxf(bot - 0.96, 0.02), 0.0, 1.0)
				var w0 := _hw(0.72) * 0.95
				var wv := lerpf(w0, w0 * lerpf(0.82, 0.45, float(P.get("pp", 0.0))), pow(k, 3.0))
				var hang := (1.0 - smoothstep(wv - soft * 2.0, wv + soft, au)) * (1.0 - smoothstep(bot - soft * 2.0, bot + soft, v))
				var d_cut := d * (1.0 - smoothstep(reach * 0.2, reach, th - 1.0))
				d = lerpf(d_cut, maxf(hang, d_cut), smoothstep(0.9, 0.98, v))
				reach = 99.0 # já recortado acima
			elif v > 0.96:
				d = minf(d, lerpf(d, d_chin, smoothstep(0.96, 1.02, v)))
		d *= 1.0 - smoothstep(reach * 0.2, reach, th - 1.0)
	# Risco raspado na bochecha
	if float(P.get("cut", 0.0)) > 0.0:
		var cd := _seg_dist(Vector2(au, v), Vector2(0.78, 0.05), Vector2(0.52, 0.42))
		d *= smoothstep(0.012, 0.028, cd)
		if float(P["cut"]) >= 2.0:
			# Dois riscos paralelos
			d *= smoothstep(0.012, 0.028, _seg_dist(Vector2(au, v), Vector2(0.88, 0.16), Vector2(0.64, 0.5)))
	# Risco raspado no meio do cavanhaque
	if float(P.get("gap", 0.0)) > 0.0:
		d *= lerpf(1.0, smoothstep(0.012, 0.026, au), smoothstep(_M + lip_l * 0.6, _M + lip_l + 0.05, v))
	# Barba bifurcada: abre no meio, abaixo do queixo
	var fk := float(P.get("fk", 0.0))
	if fk > 0.0:
		d *= 1.0 - fk * _g(u, 0.06) * smoothstep(1.02, 1.12, v)
	# Barba degradê: afina em direção às costeletas
	var fdb: float = float(P.get("fd", 0.0))
	if fdb > 0.0:
		d *= lerpf(1.0, 0.2, fdb * (1.0 - smoothstep(0.05, 0.4, v)) * smoothstep(0.55, 0.85, au))
	# Nunca sobre os lábios (o bigode morsa cobre o lábio de cima de propósito)
	var lip_c := _M + (lip_l - lip_u) * 0.5
	var le := sqrt(pow(u / (_MW * 1.0), 2.0) + pow((v - lip_c) / ((lip_u + lip_l) * 0.62), 2.0))
	var over_lip := 0.0
	if mu == 8:
		over_lip = (1.0 - smoothstep(_MW * 1.3 - soft, _MW * 1.3 + soft, au)) * smoothstep(_N + 0.02 - soft, _N + 0.02 + soft, v) * (1.0 - smoothstep(_M + lip_l * 0.25 + 0.02, _M + lip_l * 0.25 + 0.05, v))
	d *= smoothstep(0.85, 1.05, le)
	d = maxf(d, over_lip)
	# Nunca acima da linha das maçãs
	d *= smoothstep(_E + 0.08, _E + 0.2, v) if au < 0.8 else 1.0
	# Falhas
	var pt := _beard_patchiness(P)
	if pt > 0.01 and patches:
		var sd2 := float(int(f["beard_seed"]) % 1000)
		var nz := _vnoise(u * 6.5 + sd2 * 0.37, v * 6.5 - sd2 * 0.21) * 0.62 + _vnoise(u * 15.0 - sd2, v * 13.0 + sd2 * 0.5) * 0.38
		var on_cheek := smoothstep(0.15, 0.45, au) * (1.0 - smoothstep(0.8, 1.0, v))
		d *= lerpf(1.0, smoothstep(pt - 0.12, pt + 0.1, nz), on_cheek * minf(1.0, pt * 1.6))
	return clampf(d, 0.0, 1.0)


## Meia largura do pescoço em unidades do rosto (mesma conta do corpo, sem depender dele).
func _neck_half() -> float:
	var f := _f
	var nw := float(f.get("neck_w", 0.68)) * (1.0 + 0.1 * float(f["fat"]))
	return minf(maxf(nw, 0.6), float(f["jaw"]) * 0.95 * 0.92)


func _beard_patchiness(P: Dictionary) -> float:
	return maxf(float(P["pt"]), float(_f["beard_patch"]) if P != _shadow_p else 0.0)


func _beard_mesh() -> void:
	var f := _f
	var P := _beard_p
	var ln: float = P["ln"]
	var op: float = P["op"]
	var col: Color = _bcol
	var gray := clampf(float(f["gray"]) * 1.6, 0.0, 0.8)
	var short := int(P["tx"]) == 0
	# Barba rala: a malha é só uma sombra leve e contínua; quem desenha as falhas são os fios.
	var patchy := minf(1.0, _beard_patchiness(P) * 1.6)
	var head := _head_contour(_contour_k())
	var grown := PackedVector2Array()
	for p in head:
		var q := _uv(p)
		# Folga mínima além da linha de densidade para a borda sempre terminar em degradê.
		var ext := 0.035 * smoothstep(-0.45, -0.2, q.y)
		if q.y > 0.0:
			ext += (0.05 + ln * 1.05 * pow(q.y, 1.5)) * smoothstep(0.0, 0.4, q.y)
			ext *= 1.0 + float(P.get("sq", 0.0)) * (0.9 * smoothstep(0.15, 0.55, absf(q.x)) - 0.25 * (1.0 - smoothstep(0.0, 0.2, absf(q.x))))
			ext *= 1.0 - float(P.get("pp", 0.0)) * 0.65 * smoothstep(0.05, 0.45, absf(q.x))
			ext *= 1.0 + float(P.get("wild", 0.0)) * (0.18 * sin(q.x * 23.0 + 1.3) + 0.12 * sin(q.x * 41.0))
		# Bifurcada: duas pontas, com o meio mais curto.
		ext *= 1.0 - float(P.get("fk", 0.0)) * (0.55 * _g(q.x, 0.1) - 0.2 * _g(absf(q.x) - 0.22, 0.1))
		var dir := (p - _hc).normalized()
		var gp := p + Vector2(dir.x * _fw, dir.y * _fh) * ext + Vector2(0, _fh * ext * 0.6 * float(q.y > 0.5))
		if float(P.get("cl", 0.0)) > 0.0 and ln >= 0.12:
			# Barba comprida e cheia: a área desenhável desce reta a partir da mandíbula
			gp.y += _fh * (ln * 0.95 + 0.04) * smoothstep(0.5, 0.85, q.y) * (1.0 - smoothstep(0.85, 1.0, q.y) * 0.5)
		grown.append(gp)
	# Grade fina na metade de baixo do rosto (a malha radial era grossa demais perto da boca e
	# picotava bigodes finos e contornos em pontinhos). O contorno "crescido" dá a forma de fora.
	var bound := _angle_radius_table(_hc, grown, 128)
	var vmax := -0.4
	for p in grown:
		vmax = maxf(vmax, _uv(p).y)
	var shade := func(p: Vector2) -> Color:
		var edge := _inside_star(_hc, bound, p)
		if edge <= 0.0:
			return Color(col, 0.0)
		var px: Color = _beard_px(p, P, col, gray, short, patchy, op)
		return Color(px, px.a * edge)
	_beard_data = _grid(-1.4, 1.4, -0.42, vmax + 0.04, int(54 * clampf(_det, 0.35, 1.3)), int(60 * clampf(_det, 0.35, 1.3)), shade)
	if _s >= DETAIL_MIN:
		_beard_detail(P, op)


## Pelos de verdade sobre a malha da barba: uma camada rala na barba toda (as bordas e as falhas
## terminam em fios soltos, não num degradê) e outra densa no miolo.
func _beard_detail(P: Dictionary, op: float) -> void:
	var m := _beard_data
	var cols: PackedColorArray = m[2]
	var kind := "short"
	if int(P["tx"]) == 0:
		kind = "stubble"
	elif float(P.get("cr", 0.0)) > 0.0:
		kind = "curly"
	elif float(P["ln"]) >= 0.12:
		kind = "long"
	var sparse := PackedFloat32Array()
	var dense := PackedFloat32Array()
	sparse.resize(cols.size())
	dense.resize(cols.size())
	for i in cols.size():
		var d := cols[i].a / maxf(op, 0.05)
		sparse[i] = smoothstep(0.02, 0.3, d)
		dense[i] = smoothstep(0.3, 0.8, d)
	if kind == "stubble":
		_detail(m, _planar_uvs(m[1], "beard_stubble", BEARD_DENS, _detail_off(3)), "beard_stubble", 0.55 + op, sparse)
		return
	var a := "beard_%s_a" % kind
	var b := "beard_%s_b" % kind
	var density := BEARD_DENS * (1.45 if kind == "curly" else 1.15)
	_detail(m, _planar_uvs(m[1], a, density, _detail_off(3)), a, 1.0, sparse)
	_detail(m, _planar_uvs(m[1], b, density, _detail_off(4)), b, op, dense)


## Cor da barba num ponto da malha (densidade no alfa).
func _beard_px(p: Vector2, P: Dictionary, col: Color, gray: float, short: bool, patchy: float, op: float) -> Color:
	var q := _uv(p)
	var dens := _beard_dens(q.x, q.y, P, false)
	# Estilo por cima (por fazer com cavanhaque): a outra barba entra cheia sobre a sombra
	var d2 := 0.0
	if P.has("ov"):
		var P2: Dictionary = FaceGen.BEARD_PARTS[int(P["ov"])]
		d2 = _beard_dens(q.x, q.y, P2, false) * float(P2["op"])
	if dens <= 0.0 and d2 <= 0.0:
		return Color(col, 0.0)
	dens *= 1.0 - 0.5 * patchy * smoothstep(0.15, 0.45, absf(q.x))
	var lum := 0.95 - 0.22 * clampf(q.x, -1.0, 1.0) - 0.2 * smoothstep(0.6, 1.3, q.y) + 0.12 * _g2(q.x + 0.3, q.y - 0.5, 0.3, 0.2)
	lum += 0.05 * sin(q.x * 23.0 + q.y * 7.0) * sin(q.y * 19.0 - q.x * 5.0)
	var c := col.lerp(Color.BLACK, (1.0 - lum) * 0.6) if lum < 1.0 else col.lerp(col.lightened(0.3), lum - 1.0)
	# Pontas mais claras e mais quentes no queixo e nas bochechas
	c = c.lerp(col.lightened(0.18).lerp(Color("#8A5A3A"), 0.15), 0.25 * smoothstep(0.7, 1.2, q.y) + 0.1 * smoothstep(0.4, 0.8, absf(q.x)))
	# Os primeiros fios brancos aparecem nos cantos do queixo
	c = c.lerp(Color("#D9D6D0"), gray * _g2(absf(q.x) - 0.3, q.y - 0.95, 0.16, 0.22))
	var k2 := clampf(d2 / maxf(dens * op + d2, 0.001), 0.0, 1.0) if d2 > 0.0 else 0.0
	if short:
		# Barba por fazer vista de longe é uma sombra fria na pele, não uma mancha marrom
		c = c.lerp(_shadow_col, 0.4 * (1.0 - k2))
	# A massa dá profundidade, os pelos dão a cobertura. Uma base opaca transformava
	# bigode, barba branca e barba curta em peças coladas sobre a pele.
	return Color(c, maxf(dens * op, d2) * (0.62 if short else 0.78))


## Tabela raio-por-ângulo de um contorno "estrelado" a partir de `center`.
func _angle_radius_table(center: Vector2, contour: PackedVector2Array, bins: int) -> PackedFloat32Array:
	var tab := PackedFloat32Array()
	tab.resize(bins)
	tab.fill(0.0)
	var n := contour.size()
	for i in n:
		var a := contour[i] - center
		var b := contour[(i + 1) % n] - center
		for k in 9:
			var d := a.lerp(b, k / 8.0)
			var bi := int(floor(fposmod(d.angle(), TAU) / TAU * bins)) % bins
			tab[bi] = maxf(tab[bi], d.length())
	# Preenche buracos com o vizinho
	for pass_i in 2:
		for i in bins:
			if tab[i] <= 0.0:
				tab[i] = maxf(tab[(i + bins - 1) % bins], tab[(i + 1) % bins])
	return tab


## 1 bem dentro do contorno, 0 fora, com uma borda macia.
func _inside_star(center: Vector2, tab: PackedFloat32Array, p: Vector2) -> float:
	var d := p - center
	var bins := tab.size()
	var x := fposmod(d.angle(), TAU) / TAU * bins
	var i := int(floor(x)) % bins
	var r := lerpf(tab[i], tab[(i + 1) % bins], x - floor(x))
	if r <= 0.0:
		return 0.0
	return 1.0 - smoothstep(0.93, 1.0, d.length() / r)


## Grade retangular (em coordenadas do rosto) com cor por vértice; só emite as células com algo visível.
func _grid(u0: float, u1: float, v0: float, v1: float, nu: int, nv: int, shader: Callable) -> Array:
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for j in nv + 1:
		for i in nu + 1:
			var p := _px(lerpf(u0, u1, float(i) / nu), lerpf(v0, v1, float(j) / nv))
			pts.append(_cl(p))
			cols.append(shader.call(p))
	var row := nu + 1
	for j in nv:
		for i in nu:
			var a := j * row + i
			if cols[a].a + cols[a + 1].a + cols[a + row].a + cols[a + row + 1].a < 0.004:
				continue
			idx.append_array([a, a + row, a + row + 1, a, a + row + 1, a + 1])
	var m := [idx, pts, cols]
	_emit(m)
	return m


func _beard_hairs(rng: RandomNumberGenerator) -> void:
	if _beard_data.size() < 3:
		return
	if float(_beard_p.get("wild", 0.0)) > 0.0:
		var wc: Color = _bcol
		for i in int(40 * clampf(_det, 0.4, 1.6)):
			var a := rng.randf_range(0.15, PI - 0.15)
			var r := rng.randf_range(0.85, 1.35)
			var p := _px(cos(a) * float(_f["cheek_w"]) * r * 0.9, 0.55 + sin(a) * (0.55 + float(_beard_p["ln"])) * r)
			# Fio rebelde só na borda da barba (não solto sobre a camisa)
			var qw := _uv(p)
			if _beard_dens(qw.x, qw.y, _beard_p, false) < 0.25:
				continue
			var dir := Vector2(cos(a), sin(a) * 1.2).normalized()
			_r_line(_cl(p), _cl(p + dir * _s * rng.randf_range(0.015, 0.035)), Color(wc.lightened(rng.randf_range(0.0, 0.2)), 0.35), maxf(0.6, _s * 0.003), true)
	_beard_strands(rng, _beard_p)
	if _beard_p.has("ov"):
		_beard_strands(rng, FaceGen.BEARD_PARTS[int(_beard_p["ov"])])
	if float(_beard_p.get("brd", 0.0)) > 0.0:
		_beard_braid(float(_beard_p["brd"]))


## Fios da barba `P` sobre a malha já montada.
func _beard_strands(rng: RandomNumberGenerator, P: Dictionary) -> void:
	var f := _f
	var col: Color = _bcol
	var ln: float = P["ln"]
	var op: float = P["op"]
	var tx: int = int(P["tx"])
	# Os fios nascem nos vértices da malha da barba (a densidade já está no alfa)
	var pts: PackedVector2Array = _beard_data[1]
	var cols: PackedColorArray = _beard_data[2]
	var cand := PackedInt32Array()
	for i in cols.size():
		if cols[i].a > 0.12 * op:
			cand.append(i)
	if cand.is_empty():
		return
	var patchy := minf(1.0, _beard_patchiness(P) * 1.6)
	var n := int((420 if tx == 0 else 300 + ln * 300.0) * clampf(_det, 0.35, 1.8) * (0.6 + op * 0.6) * (1.0 + patchy * 0.4))
	var w := maxf(0.4, _s * 0.0024)
	# Estilos de contorno marcado espalham menos: o fio não "vaza" para fora do desenho
	var jit := _fw * lerpf(0.045, 0.014, float(P["sh"]))
	for k in n:
		var i := cand[rng.randi() % cand.size()]
		var dens := cols[i].a / maxf(op, 0.01)
		if rng.randf() > dens:
			continue
		var p := pts[i] + Vector2(rng.randf_range(-jit, jit), rng.randf_range(-jit, jit))
		if not _inside(p):
			continue
		# Cada fio confere a densidade no ponto exato onde nasce (e as falhas, se houver)
		var qp := _uv(p)
		var dp := _beard_dens(qp.x, qp.y, P, patchy > 0.01)
		if rng.randf() > dp:
			continue
		if tx == 0:
			# Pelos curtos: tracinhos finos e claros, não pontos grossos
			var dd := Vector2(rng.randf_range(-0.3, 0.3), 1.0).normalized() * _s * rng.randf_range(0.003, 0.006)
			_r_line(p, p + dd, Color(col.darkened(0.1), rng.randf_range(0.18, 0.38) * (0.5 + op)), maxf(0.5, _s * 0.0022), true)
			continue
		var u := qp.x
		var v := qp.y
		# Os pelos descem pelas bochechas e, perto da borda, acompanham a mandíbula até o queixo
		# (fio reto para baixo na lateral "sai" do rosto e deixa a barba com borda de recorte)
		var vv := clampf(v, 0.0, 0.98)
		var slope := (_hw(vv + 0.02) - _hw(vv - 0.02)) / 0.04 * _fw / _fh
		var edge := smoothstep(0.35, 0.95, absf(u) / maxf(0.05, _hw(vv)))
		var dir := Vector2(signf(u) * slope * edge + u * 0.12 * (1.0 - edge), 1.0).normalized()
		if absf(v - (_N + _M) * 0.5) < 0.08 and absf(u) < _MW * 1.1:
			dir = Vector2(u * 1.4, 1.0).normalized()
		var length := _s * (0.007 + ln * 0.028) * rng.randf_range(0.6, 1.2) * (1.0 if dens > 0.6 else 0.6)
		var bend := dir.orthogonal() * length * rng.randf_range(-0.25, 0.25)
		var tip := p + dir * length + bend * 0.4
		var qt := _uv(tip)
		var dt := _beard_dens(qt.x, qt.y, P, false)
		if dt < 0.2:
			# A ponta sairia da barba: fio curto e fraco, que só suaviza a borda
			length *= 0.4
			bend *= 0.4
			tip = p + dir * length + bend * 0.4
		var light := rng.randf() < 0.4
		var c := col.lightened(rng.randf_range(0.05, 0.2)) if light else col.darkened(rng.randf_range(0.05, 0.25))
		var mid := p + dir * length * 0.5 + bend
		var a := rng.randf_range(0.22, 0.5) * op * (0.45 + 0.55 * minf(dp, maxf(dt, 0.2)))
		if float(P.get("cr", 0.0)) > 0.0:
			# Barba crespa/cacheada: voltinhas curtas em vez de fios retos
			var r := _s * rng.randf_range(0.004, 0.007) * (1.0 + ln * 1.2)
			var a0 := rng.randf() * TAU
			_r_arc(p + dir * r, r, a0, a0 + PI * 1.15, 6, Color(c, minf(1.0, a * 1.2)), w, true)
			continue
		_r_polyline(PackedVector2Array([p, mid, tip]), Color(c, a), w * 0.85, true)


## Trança pendurada no queixo (cavanhaque ou barba longa trançada).
func _beard_braid(extra: float) -> void:
	var ln: float = float(_beard_p["ln"])
	var col := _bcol
	var top := _px(0.0, 1.0 + ln * 0.55)
	var bot := _px(0.03, 1.08 + ln * 0.9 + extra)
	var n := 5 + int(extra * 10.0)
	var seg := (bot - top) / float(n)
	var hw := _fw * 0.075
	var w := maxf(0.7, _s * 0.004)
	for k in n:
		var c := top + seg * (float(k) + 0.5)
		var side := 1.0 if k % 2 == 0 else -1.0
		var sz := hw * lerpf(1.0, 0.7, float(k) / n)
		var e := _ellipse(_cl(c + Vector2(side * sz * 0.3, 0.0)), sz, seg.length() * 0.62, 10)
		_fill(e, col.darkened(0.12 + 0.1 * float(k % 2)))
		_r_line(_cl(c + Vector2(-side * sz * 0.5, -seg.y * 0.35)), _cl(c + Vector2(side * sz * 0.7, seg.y * 0.3)), Color(col.lightened(0.25), 0.5), w, true)
		_r_line(_cl(c + Vector2(-side * sz * 0.8, seg.y * 0.1)), _cl(c + Vector2(side * sz * 0.2, seg.y * 0.5)), Color(col.darkened(0.45), 0.45), w, true)
	# Elástico e a pontinha solta
	_r_line(_cl(bot + Vector2(-hw * 0.6, -seg.y * 0.1)), _cl(bot + Vector2(hw * 0.6, -seg.y * 0.1)), Color("#2A2A30"), maxf(1.0, _s * 0.009), true)
	for i in 5:
		var x := lerpf(-0.5, 0.5, i / 4.0) * hw
		_r_line(_cl(bot + Vector2(x * 0.6, 0)), _cl(bot + Vector2(x, _fh * 0.06)), Color(col.darkened(0.1), 0.7), w * 1.2, true)


# ---------------------------------------------------------------------------
# Cabelo
# ---------------------------------------------------------------------------

func _hs(key: String, def: Variant) -> Variant:
	return _hair_style.get(key, def)


## Cor do cabelo em um ponto: luz de cima à esquerda, raiz mais escura, faixa de brilho.
func _hair_col(p: Vector2, w: float, t: float, gloss: float) -> Color:
	var f := _f
	var hair: Color = f["hair"]
	var q := _uv(p)
	var dn := Vector2(q.x, q.y * 0.9).normalized() if q.length() > 0.001 else Vector2(0, -1)
	var lum := 0.7 + 0.32 * dn.dot(Vector2(-0.55, -0.83))
	lum *= 0.78 + 0.22 * smoothstep(0.0, 0.45, w)
	lum *= 1.0 - 0.12 * smoothstep(0.85, 1.0, w)
	var c := hair.lerp(Color.BLACK, clampf((1.0 - lum) * 0.75, 0.0, 0.9))
	var tex: int = int(f["texture"])
	var gl: float = float([0.5, 0.36, 0.2, 0.1][tex]) + gloss
	var ang := atan2(q.y, q.x)
	var sheen := _g(ang + PI * 0.62, 0.5) * _g(w - 0.6, 0.3)
	sheen *= 0.78 + 0.22 * sin(t * 97.0 + float(int(f["hair_seed"]) % 100)) * sin(t * 41.0 + 1.3)
	c = c.lerp(hair.lightened(0.32), clampf(sheen * gl * 0.7, 0.0, 0.5))
	if bool(f["tips"]):
		c = c.lerp(Color("#E2C98C"), smoothstep(0.35, 0.95, w) * 0.85)
	var dz := int(_hs("dz", 0))
	if dz > 0:
		# Parte tingida: 1 = só o alto (laterais escuras), 2 = uma listra no meio da cabeça
		var hq := -q.y
		var k := smoothstep(0.5, 0.64, hq) if dz == 1 else (1.0 - smoothstep(0.13, 0.19, absf(q.x))) * smoothstep(0.3, 0.45, hq)
		if k > 0.0:
			var dcol := Color(String(_hs("dc", "#E4D6AE")))
			var dy := dcol.lerp(Color.BLACK, clampf((1.0 - lum) * 0.6, 0.0, 0.8)).lerp(dcol.lightened(0.35), clampf(sheen * 0.6, 0.0, 0.5))
			c = c.lerp(dy, k * 0.95)
	return c


## Opacidade do cabelo da calota (degradê, linha do cabelo suave, coroa rala).
func _cap_alpha(p: Vector2, w: float) -> float:
	var f := _f
	var q := _uv(p)
	var h := -q.y
	var a: float = float(_hs("op", 1.0))
	match int(_hs("fd", 0)):
		1:
			a *= lerpf(0.5, 1.0, smoothstep(-0.05, 0.3, h))
		2:
			a *= lerpf(0.1, 1.0, smoothstep(0.35, 0.72, h))
		3:
			a *= lerpf(float(_hs("sa", 0.16)), 1.0, smoothstep(0.62, 0.7, h))
		4: # burst: raspado em volta da orelha, cheio no alto e na nuca
			a *= lerpf(0.1, 1.0, maxf(smoothstep(0.3, 0.55, h), 1.0 - smoothstep(0.55, 0.8, absf(q.x))))
		5: # navalhado: pele lisa nas laterais e transição curta
			a *= lerpf(0.02, 1.0, smoothstep(0.52, 0.64, h))
	if int(_hs("sp", 0)) == 4:
		a *= lerpf(float(_hs("sa", 0.14)), 1.0, 1.0 - smoothstep(0.22, 0.3, absf(q.x)))
	var crown: float = f["crown"]
	if crown > 0.0:
		a *= 1.0 - minf(1.0, crown * 1.3) * _g(q.x, 0.7) * smoothstep(0.35, 0.8, h) * smoothstep(0.05, 0.4, w)
	var sharp: bool = bool(f["lineup"]) or int(_hs("lu", 0)) == 1 or _hs("tx", "") in ["braid", "braid_zig", "waves"]
	# Linha do cabelo: o cabelo nasce ralo e vai enchendo (sem a "tarja" de borda dura na testa).
	# A faixa rala tem largura parecida em qualquer volume: num black power (calota grossa) 30% da
	# calota virava um véu translúcido enorme sobre a testa.
	var ramp := 0.3 * clampf(0.14 / (maxf(float(_hs("tp", 0.1)), float(_hs("sd", 0.0))) + 0.05), 0.3, 1.0)
	a *= lerpf(0.9 if sharp else 0.0, 1.0, smoothstep(0.0, 0.08 if sharp else ramp, w))
	# Costeletas afinam até sumir. Em line-up/tranças/waves a ponta fica um pouco mais marcada.
	var sb: float = float(_hs("sb", 0.0))
	if absf(q.x) > 0.5:
		a *= 1.0 - 0.85 * smoothstep(sb - 0.16, sb + 0.02, q.y)
	return a


## Monta a calota: linha de fora (silhueta) e de dentro (linha do cabelo), da esquerda para a direita.
func _build_cap() -> void:
	var f := _f
	var vol: float = f["vol"]
	var thin: bool = _hs("tx", "") in ["dots", "braid", "braid_zig", "waves"] or int(_hs("fd", 0)) == 3
	var tp: float = (float(_hs("tp", 0.08)) + (0.0 if thin else 0.07)) * (0.85 + vol * 0.3)
	var sd: float = (float(_hs("sd", 0.04)) + (0.0 if thin else 0.035)) * (0.85 + vol * 0.3)
	var sb: float = float(_hs("sb", 0.0))
	var sp: int = int(_hs("sp", 0))
	var cw: float = f["cheek_w"]
	var fore: float = f["forehead"]
	var seed := float(int(f["hair_seed"]) % 1000)
	var n := clampi(int(40 * _det), 18, 48)
	var outer := PackedVector2Array()
	var d0 := asin(clampf(sb, 0.0, 0.9))
	for i in n:
		var a := PI - d0 + (PI + 2.0 * d0) * float(i) / (n - 1)
		var up := maxf(0.0, -sin(a))
		# O volume de cima cobre toda a coroa (não só o ponto mais alto, que vira um "cone")
		var ext := lerpf(sd, tp, smoothstep(0.05, 0.8, up))
		if sp == 3:
			ext += 0.035 * sin(a * 11.0 + seed) + 0.025 * sin(a * 17.0 + seed * 1.7)
		var q: Vector2
		if sin(a) < 0.0:
			# Alto da cabeça: mesma superelipse do crânio, crescida pelo volume do cabelo
			q = _skull_pt(a, 0.035 + ext * 0.9, 0.01 + ext)
		else:
			q = Vector2(cos(a) * (cw * 1.035 + ext * 0.9), sin(a) * (1.03 + ext))
		if sp == 1:
			if sin(a) < 0.0:
				q.y = -pow(up, 0.22) * (1.03 + tp)
			q.x = cos(a) * (lerpf(cw, fore, up) * 1.035 + 0.04)
		outer.append(q)
	# Linha do cabelo
	var rec: float = f["recession"]
	var hl: float = float(f["hairline"]) + float(_hs("hl", 0.0))
	var fringe := float(_hs("hl", 0.0)) > 0.1
	var inner_raw := PackedVector2Array()
	# A base das laterais encosta na silhueta: a costeleta afina em vez de acabar num degrau
	inner_raw.append(Vector2(-cw * 0.96, sb))
	inner_raw.append(Vector2(-cw * 0.89, -0.12))
	inner_raw.append(Vector2(-0.8, hl * 0.62 - rec * 0.25))
	for i in 13:
		var t := float(i) / 12.0
		var u := lerpf(-0.66, 0.66, t)
		var y := hl - 0.045 * sin(PI * t)
		if not fringe:
			y -= rec * 0.12 + rec * 0.3 * smoothstep(0.15, 0.66, absf(u))
			if bool(f["widow"]):
				y += 0.05 * _g(u, 0.09)
			if not bool(f["lineup"]) and int(_hs("lu", 0)) != 1:
				y += 0.012 * sin(t * 23.0 + seed) + 0.008 * sin(t * 41.0 + seed * 0.7)
		if int(_hs("fl", 0)) == 3:
			# Repartido ao meio: o cabelo cai para os lados e deixa um "V" de testa no centro
			y = hl + 0.2 - 0.1 * absf(u) / 0.66 - 0.2 * _g(u, 0.16) + 0.08 * smoothstep(0.3, 0.66, absf(u))
		inner_raw.append(Vector2(u, y))
	inner_raw.append(Vector2(0.8, hl * 0.62 - rec * 0.25))
	inner_raw.append(Vector2(cw * 0.89, -0.12))
	inner_raw.append(Vector2(cw * 0.96, sb))
	var inner := _resample(inner_raw, n)
	_cap_in = PackedVector2Array()
	_cap_out = PackedVector2Array()
	for i in n:
		# As pontas da calota (costeletas) afinam até quase nada: sem o "bloco" reto ao lado dos olhos
		var e := minf(float(i), float(n - 1 - i)) / float(n - 1)
		var o := inner[i].lerp(outer[i], lerpf(0.12, 1.0, smoothstep(0.0, 0.2, e)))
		_cap_in.append(_px(inner[i].x, inner[i].y))
		_cap_out.append(_px(o.x, o.y))


static func _resample(pts: PackedVector2Array, n: int) -> PackedVector2Array:
	var lens := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		lens.append(lens[i - 1] + pts[i].distance_to(pts[i - 1]))
	var total := lens[lens.size() - 1]
	var out := PackedVector2Array()
	var j := 0
	for k in n:
		var target := total * float(k) / (n - 1)
		while j < pts.size() - 2 and lens[j + 1] < target:
			j += 1
		var seg := maxf(lens[j + 1] - lens[j], 1e-6)
		out.append(pts[j].lerp(pts[j + 1], clampf((target - lens[j]) / seg, 0.0, 1.0)))
	return out


## Suaviza um polígono fechado cortando os cantos (Chaikin).
static func _chaikin(pts: PackedVector2Array, iters: int) -> PackedVector2Array:
	var cur := pts
	for it in iters:
		var nxt := PackedVector2Array()
		var n := cur.size()
		for i in n:
			var a := cur[i]
			var b := cur[(i + 1) % n]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		cur = nxt
	return cur


func _cap_pt(t: float, w: float) -> Vector2:
	var n := _cap_in.size()
	var x := clampf(t, 0.0, 1.0) * (n - 1)
	var i := mini(int(x), n - 2)
	var lt := x - i
	var a := _cap_in[i].lerp(_cap_in[i + 1], lt)
	var b := _cap_out[i].lerp(_cap_out[i + 1], lt)
	return a.lerp(b, w)


func _front_hair(rng: RandomNumberGenerator, hair: Color) -> void:
	var f := _f
	_build_cap()
	var gloss: float = float(_hs("gl", 0.0))
	_hair_shadow()
	var cap_layers := _rings(7)
	var cap := _strip(_cap_in, _cap_out, cap_layers, func(p: Vector2, t: float, w: float) -> Color:
		var c := _hair_col(p, w, t, gloss)
		return Color(c, _cap_alpha(p, w)))
	var tex := String(_hs("tx", ["str", "wavy", "curl", "coil"][int(f["texture"])]))
	if _s >= DETAIL_MIN:
		var tname := String({"str": "hair_str", "wavy": "hair_wavy", "curl": "hair_curl", "dots": "hair_buzz"}.get(tex, "hair_coil"))
		var strength := float({"braid": 0.5, "braid_zig": 0.5, "waves": 0.6, "locs": 0.6}.get(tex, 1.0))
		_detail(cap, _strip_uvs(_cap_in, _cap_out, cap_layers, tname, 1), tname, strength)
	var nc := _cap_out.size()
	_aa_edge(_cap_out, func(p: Vector2) -> Color:
		var i := 0
		var best := INF
		for k in nc:
			var d := _cap_out[k].distance_squared_to(p)
			if d < best:
				best = d
				i = k
		var t := float(i) / maxf(1.0, nc - 1.0)
		return Color(_hair_col(p, 1.0, t, gloss), _cap_alpha(p, 1.0)))
	_cap_texture(rng, tex, hair)
	var wr := RandomNumberGenerator.new()
	wr.seed = int(f["texture_seed"]) + 31 # gerador próprio: não mexe nos sorteios das outras peças
	_hairline_wisps(wr, tex, hair)
	_front_piece(rng, String(_hs("fr", "")), hair, gloss)
	_front_piece(rng, String(_hs("fr2", "")), hair, gloss)
	# Silhueta espetada / crista
	match int(_hs("sp", 0)):
		5:
			# Bagunçado: muitas mechas pequenas quebrando a silhueta (poucas e grandes viram chifres)
			for i in 26:
				var t := 0.1 + 0.8 * i / 25.0 + rng.randf_range(-0.012, 0.012)
				var base := _cap_pt(t, 0.8)
				var tip := _cap_pt(t + rng.randf_range(-0.03, 0.03), 1.0)
				tip += (tip - _hc).normalized().rotated(rng.randf_range(-0.45, 0.45)) * _fw * rng.randf_range(0.03, 0.085)
				var tc := _hair_col(tip, 0.9, t, 0.1)
				_tuft(base, tip, _fw * rng.randf_range(0.04, 0.065), rng.randf_range(-0.3, 0.3), tc)
		2:
			# Espetado: pontas curtas no alto, puxadas para cima (não raios saindo da cabeça toda)
			for row in 2:
				var cnt := 15 - row * 4
				for i in cnt:
					var t := 0.2 + 0.6 * (float(i) + 0.5 * row) / float(cnt)
					var base := _cap_pt(t, 0.72 - row * 0.12)
					var edge := _cap_pt(t, 1.0)
					var outd := (edge - _hc).normalized().lerp(Vector2(0, -1), 0.45).normalized()
					var tip := edge + outd.rotated(rng.randf_range(-0.25, 0.25)) * _fw * rng.randf_range(0.05, 0.11) * (1.0 - row * 0.4)
					var tc := _hair_col(edge, 0.9, t, 0.1).lightened(0.04 * row)
					_tuft(base, tip, _fw * rng.randf_range(0.06, 0.08), rng.randf_range(-0.25, 0.25), tc)
		4:
			var hl0: float = float(f["hairline"])
			var faux := int(_hs("fd", 0)) != 3 and int(_hs("mk", 0)) == 0
			var h := (0.16 + float(f["vol"]) * 0.12) * (0.55 if faux else 1.0) * float(_hs("hh", 1.0))
			var cw := 1.7 if faux else 1.0
			var shape := [Vector2(-0.2 * cw, hl0 + 0.02), Vector2(-0.25 * cw, -0.75), Vector2(-0.22 * cw, -1.05 - h * 0.6), Vector2(-0.1, -1.05 - h), Vector2(0.1, -1.05 - h), Vector2(0.22 * cw, -1.05 - h * 0.6), Vector2(0.25 * cw, -0.75), Vector2(0.2 * cw, hl0 + 0.02)]
			if faux:
				# Faux hawk: volume arredondado que sobe até uma ponta no meio
				shape = [Vector2(-0.34, hl0 + 0.02), Vector2(-0.42, -0.75), Vector2(-0.36, -1.0 - h * 0.5), Vector2(-0.18, -1.04 - h * 0.95),
					Vector2(0.02, -1.05 - h * 1.35), Vector2(0.2, -1.04 - h * 0.9), Vector2(0.36, -1.0 - h * 0.45), Vector2(0.42, -0.75), Vector2(0.34, hl0 + 0.02)]
			# Contorno arredondado (cantos suavizados) e sombreado como volume, não um tijolo chapado
			var rough := PackedVector2Array()
			for q: Vector2 in shape:
				rough.append(q)
			rough = _chaikin(rough, 3)
			var crest := PackedVector2Array()
			for q in rough:
				crest.append(_cl(_px(q.x, q.y)))
			var ccen := _px(0.0, -0.95 - h * 0.35)
			_radial(ccen, crest, _rings(5), func(p: Vector2, t: float, _i: int) -> Color:
				var q := _uv(p)
				var up := clampf(-(q.y + 0.6) / (0.5 + h), 0.0, 1.0)
				var c := _hair_col(p, 0.35 + 0.6 * up, float(_i) / 40.0, 0.2).darkened(0.1 * smoothstep(0.0, 0.3, q.x))
				return Color(c, 1.0 - smoothstep(0.85, 1.0, t) * 0.35 * float(q.y > hl0 - 0.1)))
			if faux:
				for i in 7:
					var ux := lerpf(-0.3, 0.3, i / 6.0)
					var base := _px(ux, -1.0 - h * 0.6)
					var tip := _px(ux * 0.8 + 0.02, -1.05 - h * (1.35 - absf(ux) * 1.3) - 0.03)
					var tc := _hair_col(tip, 0.95, float(i) / 6.0, 0.15)
					_tuft(base, tip, _fw * 0.07, rng.randf_range(-0.2, 0.2), tc)
			if String(_hs("ck", "")) == "spikes":
				# Crista espetada: pontas finas saindo do alto do moicano
				for i in 9:
					var ux := lerpf(-0.13, 0.13, i / 8.0)
					var vy := -1.05 - h * (0.95 - absf(ux) * 1.5)
					var base := _px(ux * 0.9, vy + 0.12)
					var tip := _px(ux * 1.6 + rng.randf_range(-0.03, 0.03), vy - rng.randf_range(0.12, 0.2))
					_tuft(base, tip, _fw * 0.06, rng.randf_range(-0.2, 0.2), _hair_col(tip, 0.95, float(i) / 8.0, 0.2))
			elif String(_hs("ck", "")) == "locs":
				for i in 7:
					var ux := lerpf(-0.14, 0.14, i / 6.0)
					var pts := PackedVector2Array()
					for j in 6:
						var q := float(j) / 5.0
						pts.append(_cl(_px(ux * (1.0 + q * 0.6) + 0.05 * sin(q * 3.0 + i), lerpf(hl0 + 0.02, -1.05 - h * 0.9, pow(q, 0.8)))))
					var lc := hair.darkened(rng.randf_range(0.1, 0.3))
					_r_polyline(pts, lc, _fw * 0.075, true)
					_r_polyline(pts, Color(hair.lightened(0.2), 0.35), _fw * 0.022, true)
					_r_circle(pts[5], _fw * 0.037, lc)
			else:
				_strands_in_poly(rng, crest, hair, Vector2(0, -1), 24)
	if bool(f["balding"]) or float(f["recession"]) > 0.5:
		_scalp_shine()


## Altura (v) da linha do cabelo na coluna `u` do rosto, lida da calota já montada.
func _hairline_v(u: float) -> float:
	var best := INF
	var v := float(_f["hairline"])
	for p in _cap_in:
		var q := _uv(p)
		if q.y > -0.15:
			continue # laterais
		var d := absf(q.x - u)
		if d < best:
			best = d
			v = q.y
	return v


## Fios finos e curtos que atravessam a linha do cabelo (testa e têmporas): ligam o cabelo à pele
## como numa foto, em vez de uma borda recortada. Cortes marcados (lineup, tranças) ficam limpos.
func _hairline_wisps(rng: RandomNumberGenerator, tex: String, hair: Color) -> void:
	if _s < 80.0 or bool(_f["lineup"]) or int(_hs("lu", 0)) == 1 or tex in ["braid", "braid_zig", "waves", "dots", "locs"]:
		return
	var w := maxf(0.5, _s * 0.0026)
	var n := int(70 * clampf(_det, 0.5, 1.6))
	var kinky := tex == "coil" or tex == "curl"
	for i in n:
		var t := rng.randf_range(0.04, 0.96)
		var root := _cap_pt(t, rng.randf_range(0.14, 0.3))
		if _cap_alpha(root, 0.35) < 0.5:
			continue # lateral raspada
		var tip := _cap_pt(t + rng.randf_range(-0.01, 0.01), rng.randf_range(-0.07, 0.02))
		var c := hair.darkened(rng.randf_range(0.0, 0.25)).lerp(_skin, rng.randf_range(0.05, 0.25))
		var a := rng.randf_range(0.18, 0.4)
		if kinky:
			# Crespos: pontinhos e voltinhas curtas em vez de fios lisos (com a textura de fios,
			# ela mesma faz a linha do cabelo)
			if _s >= DETAIL_MIN:
				continue
			_r_circle(_cl(root.lerp(tip, rng.randf_range(0.3, 0.9))), maxf(0.4, _s * rng.randf_range(0.0018, 0.003)), Color(c, a))
			continue
		var bend := (tip - root).orthogonal() * rng.randf_range(-0.2, 0.2)
		_r_polyline(PackedVector2Array([_cl(root), _cl(root.lerp(tip, 0.5) + bend), _cl(tip)]), Color(c, a), w, true)


## Mecha espetada: base larga que afina até a ponta numa curva leve (não um triângulo reto),
## com o lado da luz mais claro, um fio de brilho no meio e bordas suaves.
func _tuft(base: Vector2, tip: Vector2, half_w: float, bend: float, col: Color) -> void:
	var axis := tip - base
	var nrm := axis.orthogonal().normalized()
	var n := 6
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var mid := PackedVector2Array()
	for i in n + 1:
		var q := float(i) / n
		var c := base + axis * q + nrm * axis.length() * bend * sin(PI * q) * 0.5
		var hw := half_w * pow(1.0 - q, 0.8)
		left.append(_cl(c - nrm * hw))
		right.append(_cl(c + nrm * hw))
		mid.append(_cl(c))
	var lit := 1.0 if nrm.dot(Vector2(_light.x, _light.y)) < 0.0 else -1.0
	var pts := PackedVector2Array(left)
	var cols := PackedColorArray()
	# A ponta afina também na opacidade: mecha de verdade termina em fios, não numa quina
	for i in left.size():
		var q := float(i) / n
		cols.append(Color(col.darkened(0.2 if lit > 0.0 else 0.04).lerp(col, q * 0.5), 1.0 - 0.7 * q * q))
	for i in range(right.size() - 2, -1, -1):
		var q := float(i) / n
		pts.append(right[i])
		cols.append(Color(col.darkened(0.04 if lit > 0.0 else 0.2).lerp(col, q * 0.5), 1.0 - 0.7 * q * q))
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return
	_r_polygon(pts, cols)
	var w := maxf(0.8, _s * 0.004)
	_r_polyline(left, Color(col.darkened(0.3), 0.45), w, true)
	_r_polyline(right, Color(col.darkened(0.3), 0.45), w, true)
	_r_polyline(mid.slice(1, n), Color(col.lightened(0.3), 0.35), w, true)


## Sombra suave que o cabelo projeta na testa e nas têmporas (integra a calota ao rosto).
func _hair_shadow() -> void:
	var n := _cap_in.size()
	if n < 3:
		return
	var thin: bool = _hs("tx", "") == "dots"
	var strength := (0.07 if thin else 0.17) * float(_hs("op", 1.0))
	var lower := PackedVector2Array()
	var a := PackedFloat32Array()
	for i in n:
		var p := _cap_in[i]
		var q := _uv(p)
		# Mais forte no meio da testa; nas laterais, onde a linha desce, some aos poucos
		var k := strength * (1.0 - smoothstep(0.25, 0.9, q.y + 0.6)) * _cap_alpha(p, 0.15)
		a.append(k)
		# De perto a sombra desce mais pela testa (o cabelo tapa a luz de cima)
		lower.append(p + Vector2(0.0, _fh * ((0.05 if _s < 140.0 else 0.09) + 0.03 * float(_hs("hl", 0.0)) / 0.3)))
	_strip(_cap_in, lower, 3, func(p: Vector2, t: float, w: float) -> Color:
		var i := clampi(int(round(t * (n - 1))), 0, n - 1)
		return Color(_shadow_col.darkened(0.3), a[i] * pow(1.0 - w, 1.7)))
	# A pele embaixo dos fios ralos da linha do cabelo fica na sombra do próprio cabelo (sem isso a
	# testa clara aparecia através dos fios como um brilho)
	var up := PackedVector2Array()
	for i in n:
		up.append(_cap_in[i].lerp(_cap_out[i], 0.32))
	_strip(up, _cap_in, 2, func(_p: Vector2, t: float, w: float) -> Color:
		var i := clampi(int(round(t * (n - 1))), 0, n - 1)
		return Color(_shadow_col.darkened(0.3), a[i] * lerpf(2.2, 1.0, w)))


## Textura do cabelo sobre a calota. Com a textura de fios (retrato grande), os cachos, as
## bolinhas e o contorno em contas dão lugar a ela e a uma borda de fios soltos.
func _cap_texture(rng: RandomNumberGenerator, tex: String, hair: Color) -> void:
	var f := _f
	var w := maxf(0.6, _s * 0.0036)
	var k := clampf(_det * _det, 0.1, 2.0)
	var textured := _s >= DETAIL_MIN
	var flow := int(_hs("fl", 0))
	var part := 0.5 + float(f["part_side"]) * 0.19
	if _s >= 140.0 and tex in ["str", "wavy"]:
		_cap_flyaways(hair)
	match tex:
		"str", "wavy":
			var n := int(200 * k)
			w = maxf(0.4, _s * 0.0018)
			var hl_on: bool = bool(f.get("highlights", false))
			var hl_col := Color("#D8B46A").lerp(hair, 0.35)
			var streaks: Array = []
			if hl_on:
				for i in 5:
					streaks.append(rng.randf())
			for i in n:
				var t0 := rng.randf()
				var streak := false
				if hl_on and rng.randf() < 0.45:
					t0 = clampf(float(streaks[rng.randi() % streaks.size()]) + rng.randf_range(-0.035, 0.035), 0.0, 1.0)
					streak = true
				var w0 := rng.randf_range(0.0, 0.25)
				var w1 := rng.randf_range(0.65, 1.0)
				var pts := PackedVector2Array()
				var ok := true
				for j in 7:
					var ww := lerpf(w0, w1, float(j) / 6.0)
					var tt := t0
					if flow == 1:
						tt += (t0 - part) * 0.08 * ww
					elif flow == 3:
						tt += (t0 - 0.5) * 0.12 * ww
					if tex == "wavy":
						tt += 0.006 * sin(ww * 7.0 + t0 * 23.0)
					var p := _cap_pt(tt, ww)
					# Só pula a área raspada (degradê); a borda rala da linha do cabelo recebe fios
					if _cap_alpha(p, maxf(ww, 0.3)) < 0.5:
						ok = false
						break
					pts.append(_cl(p))
				if not ok:
					continue
				var roll := rng.randf()
				var c: Color
				if streak:
					c = hl_col.lerp(hair, rng.randf_range(0.0, 0.3))
				elif roll < 0.45:
					c = _hair_col(pts[3], 0.6, t0, 0.3).lerp(hair.lightened(0.28), 0.12)
				elif roll < 0.55:
					c = hair.lightened(0.36)
				else:
					c = hair.darkened(rng.randf_range(0.2, 0.45))
				var a := rng.randf_range(0.2, 0.45) if not streak else rng.randf_range(0.25, 0.42)
				if roll >= 0.45 and roll < 0.55 and not streak:
					a *= 0.6
				# Os fios se perdem na raiz e na ponta, em vez de riscar a calota
				# inteira com linhas claras de espessura constante.
				if _s >= 140.0:
					var strand_colors := PackedColorArray()
					for j in pts.size():
						var t := float(j) / (pts.size() - 1.0)
						strand_colors.append(Color(c, a * smoothstep(0.0, 0.2, t) * (1.0 - smoothstep(0.72, 1.0, t))))
					_r_polyline_colors(pts, strand_colors, w, true)
				else:
					_r_polyline(pts, Color(c, a), w, true)
			if int(f["hair_i"]) not in FaceGen.DYED and float(f["gray"]) > 0.15:
				for i in int(55 * k * float(f["gray"])):
					var t0 := rng.randf()
					var a := _cap_pt(t0, rng.randf_range(0.1, 0.4))
					var b := _cap_pt(t0 + rng.randf_range(-0.01, 0.01), rng.randf_range(0.6, 0.95))
					if _cap_alpha(a, 0.3) < 0.5 or _cap_alpha(b, 0.8) < 0.5:
						continue
					_r_line(_cl(a), _cl(b), Color(0.86, 0.86, 0.84, 0.4), w, true)
		"curl":
			var big := int(_hs("bc", 0)) == 1
			var hl_on: bool = bool(f.get("highlights", false))
			if textured:
				_cap_fuzz(0.09 if not big else 0.12)
				return
			for i in int((75 if not big else 60) * k):
				var p := _cap_pt(rng.randf(), rng.randf_range(0.12, 0.97))
				if _cap_alpha(p, 0.5) < 0.5:
					continue
				var r := _fw * rng.randf_range(0.035, 0.06) * (1.3 if big else 1.0)
				var a0 := rng.randf() * TAU
				# Cada cacho é um tufo cheio: sombra embaixo, corpo na cor do cabelo e um reflexo em
				# meia-lua do lado da luz (argolas soltas pareciam rabiscos)
				var bc := _hair_col(p, 0.7, 0.5, 0.0)
				var lit := bc.lightened(0.22)
				if hl_on and rng.randf() < 0.3:
					lit = Color("#D8B46A").lerp(bc, 0.3)
				_fill(_ellipse(_cl(p + Vector2(r * 0.15, r * 0.3)), r, r * 0.85, 10), Color(hair.darkened(0.5), 0.22))
				_fill(_ellipse(_cl(p), r * 0.92, r * 0.8, 10), Color(bc.darkened(0.06), 0.9))
				_r_arc(_cl(p), r * 0.6, PI * 1.05 + a0 * 0.2, PI * 1.75 + a0 * 0.2, 6, Color(lit, 0.38), w * 1.1, true)
				if rng.randf() < 0.4:
					_r_arc(_cl(p), r * 0.3, a0, a0 + PI, 5, Color(hair.darkened(0.35), 0.4), w, true)
			_outline_bumps(rng, hair, 0.075 if not big else 0.095, 26)
		"coil":
			if textured:
				_cap_fuzz(0.05)
				return
			for i in int(420 * k):
				var ww := rng.randf_range(0.05, 1.0)
				var tt := rng.randf()
				var p := _cap_pt(tt, ww)
				if _cap_alpha(p, ww) < 0.3:
					continue
				var base := _hair_col(p, ww, tt, 0.0)
				var light := rng.randf() < 0.45
				var c := base.lerp(hair.lightened(0.35), 0.35) if light else base.darkened(0.3)
				if bool(f.get("highlights", false)) and rng.randf() < 0.18:
					c = Color("#C9A25E")
				_r_circle(_cl(p), maxf(0.45, _s * rng.randf_range(0.0022, 0.0042)), Color(c, rng.randf_range(0.25, 0.5)))
			_outline_bumps(rng, hair, 0.028, 56)
		"dots":
			if textured:
				return
			for i in int(170 * k):
				var ww := rng.randf_range(0.0, 1.0)
				var p := _cap_pt(rng.randf(), ww)
				_r_circle(_cl(p), maxf(0.4, _s * 0.0028), Color(hair.darkened(0.2), rng.randf_range(0.25, 0.5)))
		"braid", "braid_zig":
			var rows := 8
			var zig := tex == "braid_zig"
			for r in rows:
				var t0 := lerpf(0.14, 0.86, float(r) / (rows - 1))
				var pts := PackedVector2Array()
				for j in 12:
					var tt := t0 + (t0 - 0.5) * 0.05 * j / 11.0
					if zig:
						tt += 0.028 * (1.0 if j % 4 < 2 else -1.0) * (1.0 if j % 2 == 0 else 0.5)
					pts.append(_cl(_cap_pt(tt, lerpf(0.0, 0.98, float(j) / 11.0))))
				# Risca do couro entre esta fileira e a próxima
				if r < rows - 1:
					var gap := PackedVector2Array()
					var tn := lerpf(0.14, 0.86, float(r + 1) / (rows - 1))
					for j in 12:
						var tm := (t0 + tn) * 0.5
						var tt2 := tm + (tm - 0.5) * 0.05 * j / 11.0
						if zig:
							tt2 += 0.028 * (1.0 if j % 4 < 2 else -1.0) * (1.0 if j % 2 == 0 else 0.5)
						gap.append(_cl(_cap_pt(tt2, lerpf(0.0, 0.98, float(j) / 11.0))))
					_r_polyline(gap, Color(_skin.darkened(0.12), 0.8), maxf(0.6, _fw * 0.022), true)
				_r_polyline(pts, Color(hair.darkened(0.1), 0.95), _fw * 0.09, true)
				for j in 11:
					var a := pts[j]
					var b := pts[j + 1]
					var side := (b - a).orthogonal().normalized() * _fw * 0.035
					_r_line(a - side, b + side, Color(hair.lightened(0.25), 0.55), w * 1.3, true)
					_r_line(a + side * 0.6, b - side * 0.6, Color(hair.darkened(0.45), 0.35), w, true)
		"waves":
			# Arcos concêntricos a partir da coroa, só onde há cabelo (antes cruzavam a testa)
			var crown := _px(0.0, -1.35)
			# Ondas só dentro da calota (antes os arcos passavam da cabeça para o fundo)
			var cap_poly := PackedVector2Array(_cap_out)
			for i in range(_cap_in.size() - 1, -1, -1):
				cap_poly.append(_cap_in[i])
			for r in 9:
				var rad := _fh * (0.45 + r * 0.1)
				var run := PackedVector2Array()
				for i in 25:
					var a := lerpf(PI * 0.15, PI * 0.85, i / 24.0)
					var p := crown + Vector2(cos(a), sin(a)) * rad
					if Geometry2D.is_point_in_polygon(p, cap_poly) and _cap_alpha(p, 0.6) > 0.5:
						run.append(_cl(p))
					else:
						if run.size() > 1:
							_r_polyline(run, Color(hair.lightened(0.3), 0.3), w * 1.4, true)
						run = PackedVector2Array()
				if run.size() > 1:
					_r_polyline(run, Color(hair.lightened(0.3), 0.3), w * 1.4, true)
			for i in int(120 * k):
				var ww := rng.randf_range(0.0, 1.0)
				var p := _cap_pt(rng.randf(), ww)
				_r_circle(_cl(p), maxf(0.4, _s * 0.0028), Color(hair.darkened(0.3), 0.35))
		"locs":
			for i in 13:
				var t0 := 0.07 + 0.86 * i / 12.0
				var pts := PackedVector2Array()
				for j in 7:
					pts.append(_cl(_cap_pt(t0 + 0.01 * sin(j * 1.7 + i), 0.08 + 0.9 * j / 6.0)))
				var lc := hair.darkened(rng.randf_range(0.15, 0.35))
				_r_polyline(pts, Color(lc, 0.75), _fw * 0.085, true)
				_r_polyline(pts, Color(hair.lightened(0.22), 0.3), _fw * 0.025, true)
				# Gomos das dreads
				for j in 6:
					var a := pts[j]
					var b := pts[j + 1]
					var side := (b - a).orthogonal().normalized() * _fw * 0.04
					var m := a.lerp(b, 0.5)
					_r_line(m - side, m + side, Color(lc.darkened(0.35), 0.45), w, true)


## Poucos fios finos quebram a borda perfeita dos cabelos lisos. O sorteio é
## separado: acrescentar esse acabamento não muda os fios nem a identidade.
func _cap_flyaways(hair: Color) -> void:
	if _cap_out.size() < 3:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_f["hair_seed"]) + 191
	for i in 18:
		var j := rng.randi_range(1, _cap_out.size() - 2)
		var p := _cap_out[j]
		if _uv(p).y > -0.6 or _cap_alpha(p, 0.95) < 0.7:
			continue
		var outward := (p - _hc).normalized()
		var along := (_cap_out[j + 1] - _cap_out[j - 1]).normalized()
		var length := _fw * rng.randf_range(0.025, 0.055)
		var strand := PackedVector2Array([_cl(p - outward * length * 0.5), _cl(p + outward * length * 0.45), _cl(p + outward * length + along * length * 0.75)])
		var ink := hair.lightened(0.12)
		_r_polyline_colors(strand, PackedColorArray([Color(ink, 0.2), Color(ink, 0.35), Color(ink, 0)]), maxf(0.35, _s * 0.0014), true)


## Borda de fios soltos por fora da silhueta da calota (cachos e crespos), afinando nas costeletas.
func _cap_fuzz(out: float) -> void:
	var n := _cap_out.size()
	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	for i in n:
		var p := _cap_out[i]
		var d := (p - _hc).normalized()
		var e := smoothstep(0.0, 0.15, minf(float(i), float(n - 1 - i)) / float(n - 1))
		inner.append(_cl(p - d * _fw * 0.04 * e))
		outer.append(_cl(p + d * _fw * out * e))
	var nc := n
	_fuzz(inner, outer, func(p: Vector2) -> Color:
		var best := INF
		var i := 0
		for j in nc:
			var dd := _cap_out[j].distance_squared_to(p)
			if dd < best:
				best = dd
				i = j
		var t := float(i) / maxf(1.0, nc - 1.0)
		return Color(_hair_col(p, 0.95, t, 0.0), _cap_alpha(_cap_out[i], 1.0)))


## Bolinhas na silhueta (cachos e crespos).
func _outline_bumps(rng: RandomNumberGenerator, hair: Color, r: float, n: int) -> void:
	for i in n:
		var t := float(i) / (n - 1)
		var p := _cap_pt(t, 0.97)
		if _cap_alpha(p, 0.9) < 0.5:
			continue
		var rr := _fw * r * rng.randf_range(0.7, 1.2)
		_r_circle(_cl(p), rr, _hair_col(p, 0.9, t, 0.0))


func _strands_in_poly(rng: RandomNumberGenerator, poly: PackedVector2Array, hair: Color, dir: Vector2, n: int) -> void:
	var r := _bounds(poly)
	var w := maxf(0.6, _s * 0.0036)
	var drawn := 0
	var tries := 0
	var cnt := int(n * clampf(_det, 0.4, 1.6))
	while drawn < cnt and tries < cnt * 5:
		tries += 1
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		var q := p + (dir.normalized() + Vector2(rng.randf_range(-0.2, 0.2), 0)) * _fh * rng.randf_range(0.08, 0.16)
		if not Geometry2D.is_point_in_polygon(q, poly):
			continue
		var light := rng.randf() < 0.5
		_r_line(p, q, Color(hair.lightened(0.25) if light else hair.darkened(0.3), 0.4), w, true)
		drawn += 1


## Bola de cabelo (afro, coque, puff). `soft`: com a textura de fios, a borda some aos poucos
## para a franja de fios soltos (_fuzz_ring) fazer a silhueta.
func _blob(center: Vector2, rx: float, ry: float, gloss: float, lumpy: float, seed: float, soft: bool = false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var fade := soft and _s >= DETAIL_MIN
	var nb := 72 if fade and _s >= 140.0 else 36
	for i in nb:
		var a := TAU * i / nb
		var k := 1.0 + lumpy * (0.06 * sin(a * 9.0 + seed) + 0.04 * sin(a * 14.0 + seed * 2.0))
		pts.append(_cl(center + Vector2(cos(a) * rx, sin(a) * ry) * k))
	_blob_c = center
	_blob_r = maxf(rx, ry)
	_blob_m = _radial(center, pts, _rings(6), func(p: Vector2, t: float, _i: int) -> Color:
		var c := _hair_col(p, clampf(0.35 + t * 0.55, 0.0, 1.0), float(_i) / nb, gloss)
		return Color(c, 1.0 - 0.65 * smoothstep(0.84, 1.0, t)) if fade else c)
	if not fade:
		_rim(_blob_m, pts.size())
	return pts


## Textura de fios planos sobre a última bola de cabelo (_blob).
func _blob_detail(name: String, alpha: float = 1.0) -> void:
	if _s >= DETAIL_MIN and _blob_m.size() == 3:
		_detail(_blob_m, _planar_uvs(_blob_m[1], name, DETAIL_DENS, _detail_off(5)), name, alpha)


func _front_piece(rng: RandomNumberGenerator, kind: String, hair: Color, gloss: float) -> void:
	var f := _f
	var hl: float = float(f["hairline"]) + float(_hs("hl", 0.0))
	var w := maxf(0.6, _s * 0.0036)
	match kind:
		"quiff", "pomp":
			# Volume que nasce na linha do cabelo e sobe para trás, puxado para o lado do risco
			var big := kind == "pomp"
			var sx := float(f["part_side"])
			var hh := (0.4 if big else 0.3) * float(_hs("ph", 1.0))
			var hl0 := float(f["hairline"])
			var pts := PackedVector2Array()
			# A base acompanha a linha do cabelo (um pouco para dentro dela), não uma régua na testa
			for i in 15:
				var t := float(i) / 14.0
				var u := lerpf(-0.64, 0.64, t)
				pts.append(_px(u, _hairline_v(u) - 0.035))
			for i in 17:
				var t := float(i) / 16.0
				var u := lerpf(0.66, -0.66, t)
				var peak := _g(u + sx * 0.12, 0.42 * float(_hs("ph", 1.0)))
				pts.append(_px(u * (1.0 + 0.04 * sin(PI * t)), hl0 - 0.06 - hh * peak - 0.12 * sin(PI * t)))
			var clean := PackedVector2Array()
			for p in pts:
				clean.append(_cl(p))
			var cen := _px(-sx * 0.1, hl0 - 0.12 - hh * 0.4)
			_radial(cen, clean, _rings(5), func(p: Vector2, t: float, _i: int) -> Color:
				var q := _uv(p)
				var up := clampf((hl0 - q.y) / (hh + 0.2), 0.0, 1.0)
				var c := _hair_col(p, 0.35 + up * 0.6, float(_i) / 32.0, gloss + 0.25)
				return Color(c, 1.0 - smoothstep(0.7, 1.0, t) * (1.0 if _i < 15 else 0.0)))
			_strands_in_poly(rng, clean, hair, Vector2(-sx * 0.25, -1.0), 30 if big else 22)
		"fringe", "crop":
			# Mechas que caem sobre a testa: duas fileiras de tufos curvos que se sobrepõem (a de trás
			# mais escura), pontas desencontradas e sombra suave embaixo (não um serrote de triângulos)
			var crop := kind == "crop"
			var top_y := hl - (0.3 if not crop else 0.2) * float(_hs("fc", 1.0))
			var sx := float(f["part_side"])
			var sh := PackedVector2Array()
			for i in 12:
				var t := float(i) / 11.0
				sh.append(_px(lerpf(-0.68, 0.68, t), hl + 0.04 + 0.03 * sin(PI * t)))
			_r_polyline(sh, Color(0, 0, 0, 0.09), _fh * 0.06, true)
			for row in 2:
				var tuft_count := (9 if not crop else 11) - row
				for i in tuft_count:
					var t := (float(i) + 0.5 * row) / float(tuft_count - 1 + row)
					var u := lerpf(-0.72, 0.72, t) + rng.randf_range(-0.02, 0.02)
					var edge := pow(absf(u) / 0.72, 2.0)
					var tip_y := hl + rng.randf_range(-0.035, 0.03) - edge * 0.07 - row * 0.03 + (0.0 if crop else 0.025 * sin(PI * t))
					var base := _px(u * 0.92, top_y - row * 0.04)
					var tip := _px(u + sx * 0.04 + rng.randf_range(-0.04, 0.04), tip_y)
					var tc := _hair_col(base.lerp(tip, 0.4), 0.8, t, gloss).darkened(0.12 * (1 - row))
					_tuft(base, tip, _fw * rng.randf_range(0.075, 0.1) * (0.85 if crop else 1.0), rng.randf_range(-0.2, 0.2) + sx * 0.08, tc)
		"locks", "braid_locks":
			var ln := float(_hs("lk", 1.0))
			var braid := kind == "braid_locks"
			for sx: float in [-1.0, 1.0]:
				var inner := PackedVector2Array()
				var outer := PackedVector2Array()
				for i in 10:
					var t := float(i) / 9.0
					var v := lerpf(-0.68, -0.1 + ln, t)
					var hw := _hw(clampf(v, 0.0, 1.0)) if v > 0.0 else float(f["cheek_w"]) * sqrt(maxf(0.0, 1.0 - pow(v / 1.02, 2.0)))
					var ix := hw * lerpf(0.8, 0.95, smoothstep(0.0, 0.35, t))
					if v > 0.75:
						ix = maxf(ix, 0.62 + (v - 0.75) * 0.35)
					var thick := lerpf(0.3, 0.06, pow(t, 1.4)) * (0.8 if braid else 1.0)
					inner.append(_px(sx * ix, v))
					outer.append(_px(sx * (ix + thick + 0.06 * sin(PI * t)), v + 0.03 * t))
				_strip(inner, outer, 4, func(p: Vector2, t: float, ww: float) -> Color:
					var c := _hair_col(p, 0.55 + ww * 0.3, t, gloss)
					# Borda do lado do rosto e pontas desfiadas: nada de painel recortado
					var a := smoothstep(0.0, 0.3, ww) * (1.0 - smoothstep(0.8, 1.0, t) * 0.75) * smoothstep(0.0, 0.1, t)
					return Color(c.darkened(0.08 * t), a))
				var n := int(18 * clampf(_det, 0.4, 1.6))
				for j in n:
					var ww := rng.randf()
					var pts := PackedVector2Array()
					for k in 8:
						var t := float(k) / 7.0
						var i0 := mini(int(t * 8.0), 8)
						var lt := t * 8.0 - i0
						var a := inner[i0].lerp(inner[i0 + 1], lt)
						var b := outer[i0].lerp(outer[i0 + 1], lt)
						var p := a.lerp(b, ww)
						if _hs("tx", "") == "wavy":
							p.x += sin(t * 9.0 + j) * _fw * 0.02
						pts.append(_cl(p))
					var light := rng.randf() < 0.5
					if braid:
						_r_polyline(pts, Color(hair.darkened(0.3), 0.5), _fw * 0.05, true)
						for k in 7:
							_r_line(pts[k], pts[k + 1], Color(hair.lightened(0.25), 0.4), w, true)
					else:
						_r_polyline(pts, Color(hair.lightened(0.25) if light else hair.darkened(0.35), 0.18 if light else 0.3), w, true)
		"part":
			var px := float(f["part_side"]) * 0.36
			_r_line(_px(px, hl - 0.03), _px(px * 0.75, -1.0), Color(hair.lightened(0.3).lerp(_skin, 0.4), 0.55), maxf(0.8, _s * 0.006), true)
		"design":
			var sx := float(f["part_side"])
			var lw := maxf(0.8, _s * 0.006)
			# Dois riscos ondulados na lateral, presos à calota (nunca fora do cabelo)
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var t := float(i) / 8.0
					var tc := 0.14 + 0.14 * t
					pts.append(_cl(_cap_pt(tc if sx < 0.0 else 1.0 - tc, 0.3 + k * 0.24 + 0.1 * sin(PI * t * 2.0))))
				_r_polyline(pts, Color(_skin.lightened(0.05), 0.85), lw, true)
		"curtain":
			# Franja cortina: risco no meio e as duas metades abrindo para os lados
			for cs: float in [-1.0, 1.0]:
				_swoop(rng, hair, gloss, hl, false, cs)
		"side_fringe":
			_swoop(rng, hair, gloss, hl, false)
		"curtain":
			# Franja cortina: risco no meio e as duas metades abrindo para os lados
			for sx: float in [-1.0, 1.0]:
				_swoop(rng, hair, gloss, hl, false, sx)
		"edgar":
			# Franja reta e cortada rente, bem marcada na testa
			var lower := PackedVector2Array()
			var upper := PackedVector2Array()
			for i in 14:
				var t := float(i) / 13.0
				var u := lerpf(-0.74, 0.74, t)
				var vl := hl + 0.01 - 0.06 * pow(absf(u) / 0.74, 3.0) + 0.008 * sin(t * 40.0)
				lower.append(_px(u, vl))
				upper.append(_px(u * 1.02, vl - 0.24))
			_strip(lower, upper, 3, func(p: Vector2, t: float, ww: float) -> Color:
				var ec := _hair_col(p, 0.5 + ww * 0.45, t, gloss + 0.1)
				return Color(ec.darkened(0.06 * (1.0 - ww)), (0.55 + 0.45 * smoothstep(0.0, 0.25, ww)) * (1.0 - smoothstep(0.7, 1.0, ww) * 0.5 - smoothstep(0.85, 1.0, absf(t - 0.5) * 2.0) * 0.6)))
			for j in int(26 * clampf(_det, 0.3, 1.6)):
				var t := rng.randf()
				var i0 := mini(int(t * 13.0), 12)
				var a := lower[i0].lerp(lower[i0 + 1], t * 13.0 - i0)
				var b := upper[i0].lerp(upper[i0 + 1], t * 13.0 - i0)
				_r_line(_cl(a.lerp(b, rng.randf_range(0.0, 0.1))), _cl(a.lerp(b, rng.randf_range(0.6, 1.0))), Color(hair.lightened(0.2) if j % 2 == 0 else hair.darkened(0.35), 0.35), w, true)
			_r_polyline(lower, Color(hair.darkened(0.3), 0.18), w, true)
			var sheen := PackedVector2Array()
			for i in range(2, 12):
				sheen.append(lower[i].lerp(upper[i], 0.62))
			_r_polyline(sheen, Color(hair.lightened(0.45), 0.18), _fh * 0.03, true)
		"curl_fringe":
			# Cachos caindo na testa
			# duas fileiras que se sobrepõem, a de trás mais escura
			for row in 2:
				var cn := 8 - row
				for i in cn:
					var t := (float(i) + 0.5 * row) / 7.5
					var u := lerpf(-0.6, 0.6, t) + rng.randf_range(-0.03, 0.03)
					var v := hl - 0.1 + row * 0.08 + rng.randf_range(-0.015, 0.03) - 0.06 * pow(absf(u) / 0.6, 2.0)
					var cp := _px(u, v)
					var r := _fw * rng.randf_range(0.09, 0.12) * (1.0 - row * 0.1)
					var cc := _hair_col(cp, 0.75 - row * 0.1, t, gloss)
					_fill(_ellipse(cp + Vector2(r * 0.1, r * 0.3), r, r * 0.8, 10), Color(0, 0, 0, 0.1))
					_fill(_ellipse(cp, r, r * 0.9, 12), cc.darkened(0.1 + 0.08 * row))
					var a0 := rng.randf_range(0.0, TAU)
					_r_arc(cp, r * 0.55, a0, a0 + PI * 1.4, 8, Color(cc.lightened(0.3), 0.6), maxf(0.6, _s * 0.004), true)
					_r_arc(cp + Vector2(r * 0.1, 0), r * 0.85, PI * 0.15, PI * 0.85, 6, Color(cc.darkened(0.35), 0.35), maxf(0.6, _s * 0.004), true)
		"top_knot":
			var bc := _px(0.05, -1.24 - float(_hs("tp", 0.1)) * 0.5)
			var br := _fw * 0.24
			var bp := _blob(bc, br, br * 0.85, 0.2, 0.2, 7.0)
			_strands_in_poly(rng, bp, hair, Vector2(0.4, -1), 8)
			_r_line(bc + Vector2(-br * 0.8, br * 0.75), bc + Vector2(br * 0.8, br * 0.8), Color(hair.darkened(0.5), 0.6), maxf(0.8, _s * 0.006), true)
		"shaved_part":
			# Termina antes da borda do crânio, senão o risco "sai" do cabelo em cortes baixos
			var px := float(f["part_side"]) * 0.52
			var ux := px * 0.85
			var top := -0.86 * sqrt(maxf(0.0, 1.0 - pow(ux / float(f["forehead"]), 2.0)))
			_r_line(_px(px, hl - 0.02), _px(ux, maxf(top, hl - 0.3)), Color(_skin.lightened(0.05), 0.85), maxf(0.8, _s * 0.007), true)
		"sponge":
			# Esponja: nozinhos crespos pequenos cobrindo o alto
			var n := int(46 * clampf(_det, 0.5, 1.5))
			for i in n:
				var t := rng.randf_range(0.1, 0.9)
				var ww := rng.randf_range(0.4, 0.98)
				var p := _cap_pt(t, ww)
				if _cap_alpha(p, ww) < 0.55:
					continue
				var r := _fw * rng.randf_range(0.035, 0.055)
				var bc := _hair_col(p, ww, t, 0.0)
				_r_circle(_cl(p + Vector2(r * 0.15, r * 0.25)), r, Color(hair.darkened(0.45), 0.7))
				_r_circle(_cl(p), r * 0.9, bc.darkened(0.08))
				_r_arc(_cl(p), r * 0.55, PI * 1.05, PI * 1.85, 6, Color(bc.lightened(0.28), 0.6), maxf(0.6, _s * 0.0035), true)
		"side_fringe_long":
			_swoop(rng, hair, gloss, hl, true)
		"design_both":
			# Desenhos raspados nas duas laterais: três riscos em zigue-zague de cada lado
			var lw := maxf(1.0, _s * 0.008)
			for side: float in [-1.0, 1.0]:
				for k in 3:
					var pts := PackedVector2Array()
					for i in 9:
						var t := float(i) / 8.0
						var tc := 0.1 + 0.2 * t
						var ww := 0.28 + k * 0.2 + 0.07 * (1.0 if i % 2 == 0 else -1.0) * float(k != 1) + 0.05 * sin(PI * t * 2.0) * float(k == 1)
						pts.append(_cl(_cap_pt(tc if side < 0.0 else 1.0 - tc, ww)))
					_r_polyline(pts, Color(_skin.lightened(0.08), 0.9), lw, true)
		"halfmoon":
			# Tufo em meia-lua na frente, com o resto da cabeça raspado
			var hl0 := float(f["hairline"])
			var pts := PackedVector2Array()
			for i in 9:
				var u := lerpf(-0.3, 0.3, float(i) / 8.0)
				pts.append(_cl(_px(u, hl0 + 0.03 + 0.02 * sin(PI * float(i) / 8.0))))
			for i in 15:
				var a := float(i) / 14.0 * PI
				pts.append(_cl(_px(0.31 * cos(a), hl0 - 0.03 - 0.36 * pow(sin(a), 0.8))))
			var cen := _px(0.0, hl0 - 0.12)
			_rim(_radial(cen, pts, _rings(4), func(p: Vector2, t: float, _i: int) -> Color:
				var q := _uv(p)
				var up := clampf((hl0 - q.y) / 0.36, 0.0, 1.0)
				return Color(_hair_col(p, 0.3 + up * 0.55, float(_i) / 24.0, gloss + 0.1), 1.0 - smoothstep(0.8, 1.0, t) * 0.5)), pts.size(), 0.6)
			_strands_in_poly(rng, pts, hair, Vector2(0.0, -1.0), 26)
		"band":
			# Faixa de cabelo (elástico) atravessando o alto da cabeça, um pouco atrás da linha do cabelo
			var bcols := [Color("#EDEDED"), Color("#1B1B20"), Color("#B8202A"), Color("#2449A8")]
			var bc: Color = bcols[int(f["hair_seed"]) % bcols.size()]
			var lo := PackedVector2Array()
			var hi := PackedVector2Array()
			for i in 21:
				var t := lerpf(0.06, 0.94, float(i) / 20.0)
				lo.append(_cap_pt(t, 0.26))
				hi.append(_cap_pt(t, 0.46))
			_strip(lo, hi, 3, func(p: Vector2, t: float, ww: float) -> Color:
				var q := _uv(p)
				var lum := 0.8 + 0.25 * Vector2(q.x, q.y).normalized().dot(Vector2(-0.55, -0.83)) - 0.15 * absf(ww - 0.5)
				return Color(bc.lerp(Color.BLACK, clampf(1.0 - lum, 0.0, 0.6)) if lum < 1.0 else bc.lightened(lum - 1.0), 0.97 * smoothstep(0.0, 0.04, t) * (1.0 - smoothstep(0.96, 1.0, t))))
			_r_polyline(lo, Color(bc.darkened(0.45), 0.5), w, true)
			_r_polyline(hi, Color(bc.darkened(0.3), 0.4), w, true)
		"bunches":
			# Tufinhos trançados espetados, presos com elástico na base
			var hn := 6
			for i in hn:
				var t := lerpf(0.16, 0.84, float(i) / (hn - 1)) + rng.randf_range(-0.015, 0.015)
				var base := _cap_pt(t, 0.8)
				var out := (_cap_pt(t, 1.0) - _px(0.0, -0.2)).normalized()
				var ln := _fw * rng.randf_range(0.2, 0.28)
				var tip := base + out * ln
				var th := _fw * 0.09
				var bc := _hair_col(base, 0.8, t, 0.1)
				var segs := 4
				for k in segs:
					var a := base.lerp(tip, float(k) / segs)
					var b := base.lerp(tip, float(k + 1) / segs)
					var m := a.lerp(b, 0.5)
					var sz := th * lerpf(1.0, 0.6, float(k) / segs)
					_fill(_ellipse(_cl(m), sz, (b - a).length() * 0.6, 8), bc.darkened(0.1 + 0.1 * float(k % 2)))
					var side := (b - a).orthogonal().normalized() * sz * 0.7
					_r_line(_cl(a - side), _cl(b + side * 0.3), Color(bc.lightened(0.3), 0.5), w, true)
				_r_circle(_cl(tip + out * th * 0.3), th * 0.45, bc.darkened(0.15))
				_r_line(_cl(base - out.orthogonal() * th * 0.9), _cl(base + out.orthogonal() * th * 0.9), Color("#1A1A1E"), maxf(1.0, _s * 0.008), true)
		"twists", "locs_top":
			# Mechas curtas torcidas, caindo a partir do alto da cabeça
			var n := int(22 * clampf(_det, 0.5, 1.4))
			var th := _fw * (0.12 if kind == "twists" else 0.1)
			for i in n:
				var t := rng.randf_range(0.08, 0.92)
				var ww := rng.randf_range(0.45, 0.95)
				var base := _cap_pt(t, ww)
				var out := (base - _px(0.0, -0.3)).normalized()
				var tip := base + (out * 0.6 + Vector2(0, 0.5)).normalized() * _fw * rng.randf_range(0.1, 0.2)
				var bc := _hair_col(base, ww, t, 0.05)
				_r_line(_cl(base), _cl(tip), bc.darkened(0.15), th, true)
				_r_circle(_cl(tip), th * 0.5, bc.darkened(0.15))
				for k in 3:
					var a := base.lerp(tip, float(k) / 3.0)
					var b2 := base.lerp(tip, float(k + 1) / 3.0)
					var side := (b2 - a).orthogonal().normalized() * th * 0.35
					_r_line(_cl(a - side), _cl(b2 + side), Color(bc.lightened(0.18), 0.35), w * 1.1, true)


## Franja jogada de lado: nasce no risco (dentro do cabelo), cruza a testa numa curva e afina até a
## ponta; a longa desce até a sobrancelha do outro lado.
func _swoop(rng: RandomNumberGenerator, hair: Color, gloss: float, hl: float, long: bool, curtain: float = 0.0) -> void:
	var sx := float(_f["part_side"])
	var w := maxf(0.6, _s * 0.0036)
	var p0 := Vector2(sx * 0.5, hl - 0.3)
	var p1 := Vector2(-sx * 0.1, hl - (0.16 if long else 0.15))
	var p2 := Vector2(-sx * (0.84 if long else 0.78), hl + (0.2 if long else 0.06))
	if curtain != 0.0:
		p0 = Vector2(curtain * 0.03, hl - 0.3)
		p1 = Vector2(curtain * 0.3, hl - 0.1)
		p2 = Vector2(curtain * 0.86, hl + 0.14)
	var n := 16
	var lower := PackedVector2Array()
	var upper := PackedVector2Array()
	for i in n:
		var t := float(i) / (n - 1)
		var c := p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)
		var d := (p1 - p0).lerp(p2 - p1, t).normalized()
		var nrm := Vector2(-d.y, d.x)
		if nrm.y < 0.0:
			nrm = -nrm
		var th := lerpf(0.2 if long else 0.17, 0.02, pow(t, 1.6))
		lower.append(_px(c.x + nrm.x * th * 0.6, c.y + nrm.y * th * 0.6))
		upper.append(_px(c.x - nrm.x * th * 1.6, c.y - nrm.y * th * 1.6))
	# Sombra na testa, logo abaixo da mecha
	var sh := PackedVector2Array()
	for k in range(3, n - 2):
		sh.append(_cl(lower[k] + Vector2(0, _fh * 0.03)))
	_r_polyline(sh, Color(0, 0, 0, 0.1), _fh * 0.045, true)
	_strip(lower, upper, 4, func(p: Vector2, t: float, ww: float) -> Color:
		var c := _hair_col(p, 0.85 + ww * 0.15, t, gloss + 0.3).lightened(0.06)
		return Color(c.darkened(0.08 * (1.0 - ww)), smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.88, 1.0, t) * 0.5)))
	for j in int(24 * clampf(_det, 0.3, 1.6)):
		var ww := rng.randf_range(0.08, 0.92)
		var pts := PackedVector2Array()
		var end := n - rng.randi_range(0, 4)
		for k in range(rng.randi_range(1, 4), end):
			pts.append(_cl(lower[k].lerp(upper[k], ww)))
		if pts.size() < 2:
			continue
		var c := hair.lightened(0.3) if j % 3 == 0 else hair.darkened(0.3)
		_r_polyline(pts, Color(c, 0.22 if j % 3 == 0 else 0.3), w, true)


## Bola de cabelo crespo (afro puff).
func _puff(rng: RandomNumberGenerator, hair: Color, cen: Vector2, r: float) -> void:
	var pts := _blob(cen, _fw * r, _fw * r * 0.82, 0.0, 1.0, float(int(_f["hair_seed"]) % 100), true)
	if _s >= DETAIL_MIN:
		_blob_detail("hair_afro")
		_fuzz_ring(cen, pts, 0.05, 0.09, func(p: Vector2) -> Color: return _hair_col(p, 0.9, 0.5, 0.0))
		return
	for i in int(220 * clampf(_det, 0.4, 1.6)):
		var a := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * _fw * r
		var p := cen + Vector2(cos(a), sin(a) * 0.82) * rr
		_r_circle(_cl(p), maxf(0.5, _s * rng.randf_range(0.003, 0.0055)), Color(hair.lightened(0.2) if rng.randf() < 0.4 else hair.darkened(0.35), rng.randf_range(0.3, 0.6)))
	for i in 36:
		var a := TAU * i / 36.0
		var p := cen + Vector2(cos(a), sin(a) * 0.82) * _fw * r * 0.97
		_r_circle(_cl(p), _fw * r * 0.08, _hair_col(p, 0.9, float(i) / 36.0, 0.0))


func _back_hair(rng: RandomNumberGenerator) -> void:
	var f := _f
	if int(f["style"]) == FaceGen.H_BALD:
		return
	var hair: Color = f["hair"]
	var gloss: float = float(_hs("gl", 0.0))
	var back_dark := hair.darkened(0.25)
	match String(_hs("bk", "")):
		"long", "long_short", "curly_long", "mullet":
			var kind := String(_hs("bk", ""))
			var bottom := 1.3 if kind == "long" else (0.85 if kind == "long_short" else (1.35 if kind == "curly_long" else 1.1))
			var width := 1.28 if kind != "curly_long" else 1.55
			if kind == "mullet":
				# Mullet: de frente só aparece atrás do pescoço e abaixo das orelhas, não em volta
				# do rosto inteiro como um capuz
				width = 0.98
			var pts := PackedVector2Array()
			for i in 30:
				var a := PI + PI * i / 29.0
				pts.append(_px(cos(a) * width, sin(a) * 1.12 - 0.3))
			var lumpy := 1.0 if kind == "curly_long" else 0.0
			var xb := width * (0.76 if kind == "mullet" else 0.78)
			for i in 12:
				var t := float(i + 1) / 12.0
				var v := lerpf(-0.3, bottom, t)
				var wd := width * (1.0 + 0.07 * sin(PI * t)) - (width - xb) * t * t + lumpy * 0.06 * sin(t * 12.0)
				pts.append(_px(wd, v))
			for i in 9:
				var t := float(i + 1) / 10.0
				pts.append(_px(lerpf(xb, -xb, t), bottom + 0.07 * sin(PI * t) + rng.randf_range(-0.03, 0.03)))
			for i in 12:
				var t := 1.0 - float(i) / 12.0
				var v := lerpf(-0.3, bottom, t)
				var wd := width * (1.0 + 0.07 * sin(PI * t)) - (width - xb) * t * t + lumpy * 0.06 * sin(t * 12.0 + 1.0)
				pts.append(_px(-wd, v))
			var clean := PackedVector2Array()
			for p in pts:
				clean.append(_cl(p))
			_hair_sil.append(clean)
			var lm := _radial(_hc + Vector2(0, _fh * 0.4), clean, _rings(6), func(p: Vector2, t: float, i: int) -> Color:
				var c := _hair_col(p, 0.6, float(i) / 60.0, gloss).darkened(0.25)
				return c.darkened(0.15 * t))
			_rim(lm, clean.size())
			if _s >= DETAIL_MIN:
				var ln_tex := "hair_ringlets" if kind == "curly_long" else "hair_long"
				_detail(lm, _planar_uvs(lm[1], ln_tex, DETAIL_DENS, _detail_off(6)), ln_tex)
			if kind == "curly_long":
				for i in int(70 * clampf(_det, 0.4, 1.6)):
					var p := _px(rng.randf_range(-width, width), rng.randf_range(-0.2, bottom))
					var r := _fw * rng.randf_range(0.05, 0.08)
					var a0 := rng.randf() * TAU
					_r_arc(_cl(p), r, a0, a0 + PI * 1.3, 8, Color(hair.lightened(0.2), 0.45), maxf(0.7, _s * 0.004), true)
			else:
				for i in int(50 * clampf(_det, 0.4, 1.6)):
					var x := rng.randf_range(-width, width)
					var a := _px(x, rng.randf_range(-0.1, 0.4))
					var b := _px(x * 1.05 + rng.randf_range(-0.05, 0.05), bottom - rng.randf_range(0.0, 0.2))
					_r_line(_cl(a), _cl(b), Color(hair.lightened(0.15) if rng.randf() < 0.5 else back_dark.darkened(0.2), 0.3), maxf(0.6, _s * 0.0035), true)
		"afro":
			var r := (1.5 + float(f["vol"]) * 0.2) * float(_hs("ar", 1.0))
			var cen := _px(0.0, -0.32)
			var pts := _blob(cen, _fw * r, _fw * r * 0.95, 0.0, 1.0, float(int(f["hair_seed"]) % 100), true)
			_hair_sil.append(pts)
			if _s >= DETAIL_MIN:
				_blob_detail("hair_afro")
				_fuzz_ring(cen, pts, 0.04, 0.07, func(p: Vector2) -> Color: return _hair_col(p, 0.9, 0.5, 0.0))
				return
			for i in int(300 * clampf(_det, 0.4, 1.6)):
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * _fw * r
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * rr
				_r_circle(_cl(p), maxf(0.5, _s * rng.randf_range(0.003, 0.006)), Color(hair.lightened(0.2) if rng.randf() < 0.4 else hair.darkened(0.35), rng.randf_range(0.3, 0.6)))
			for i in 48:
				var a := TAU * i / 48.0
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * _fw * r * 0.98
				_r_circle(_cl(p), _fw * r * 0.07, _hair_col(p, 0.9, float(i) / 48.0, 0.0))
		"afro_curl":
			# Cabeleira cacheada gigante: bola de cachos grandes que desce até a altura do queixo
			var r := (1.4 + float(f["vol"]) * 0.15) * float(_hs("ar", 1.0))
			var cen := _px(0.0, -0.2)
			var ry := r * 1.0
			var cpts := _blob(cen, _fw * r, _fw * ry, 0.0, 0.5, float(int(f["hair_seed"]) % 100), true)
			_hair_sil.append(cpts)
			_blob_detail("hair_ringlets")
			if _s >= DETAIL_MIN:
				_fuzz_ring(cen, cpts, 0.04, 0.08, func(p: Vector2) -> Color: return _hair_col(p, 0.9, 0.5, 0.0).darkened(0.1))
			for i in int(160 * clampf(_det, 0.4, 1.6)):
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * 0.97
				var p := cen + Vector2(cos(a) * _fw * r, sin(a) * _fw * ry) * rr
				var cr := _fw * rng.randf_range(0.07, 0.11)
				var bc := _hair_col(p, 0.35 + 0.6 * rr, float(i) / 160.0, 0.0).darkened(0.18)
				_fill(_ellipse(_cl(p + Vector2(cr * 0.15, cr * 0.3)), cr, cr * 0.85, 10), Color(hair.darkened(0.55), 0.25))
				_fill(_ellipse(_cl(p), cr * 0.92, cr * 0.8, 10), Color(bc, 0.92))
				var a0 := rng.randf() * TAU
				_r_arc(_cl(p), cr * 0.58, PI * 1.05 + a0 * 0.2, PI * 1.8 + a0 * 0.2, 6, Color(bc.lightened(0.28), 0.45), maxf(0.7, _s * 0.004), true)
				if rng.randf() < 0.5:
					_r_arc(_cl(p), cr * 0.3, a0, a0 + PI, 5, Color(hair.darkened(0.4), 0.4), maxf(0.6, _s * 0.0035), true)
			for i in 44:
				var a := TAU * i / 44.0
				var p := cen + Vector2(cos(a) * _fw * r, sin(a) * _fw * ry) * 0.97
				var cr := _fw * rng.randf_range(0.08, 0.12)
				var bc := _hair_col(p, 0.9, float(i) / 44.0, 0.0).darkened(0.2)
				_fill(_ellipse(_cl(p), cr, cr * 0.85, 10), bc)
				_r_arc(_cl(p), cr * 0.55, PI * 1.1, PI * 1.8, 6, Color(bc.lightened(0.25), 0.45), maxf(0.7, _s * 0.004), true)
		"rattail":
			# Rabinho trançado fino que desce da nuca por cima do ombro
			var pts := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				pts.append(_px(0.62 + 0.3 * t + 0.04 * sin(t * PI), 0.35 + 0.85 * t))
			var th := _fw * 0.07
			var w := maxf(0.7, _s * 0.004)
			for k in 8:
				var a := pts[k]
				var b := pts[k + 1]
				var m := a.lerp(b, 0.5)
				var sz := th * lerpf(1.0, 0.65, float(k) / 8.0)
				var bc := _hair_col(m, 0.6, float(k) / 8.0, gloss).darkened(0.15 + 0.1 * float(k % 2))
				_fill(_ellipse(_cl(m), sz, (b - a).length() * 0.62, 8), bc)
				var side := (b - a).orthogonal().normalized() * sz * 0.7 * (1.0 if k % 2 == 0 else -1.0)
				_r_line(_cl(a - side), _cl(b + side * 0.3), Color(bc.lightened(0.3), 0.5), w, true)
			var end := pts[8]
			_r_line(_cl(end + Vector2(-th * 0.6, 0)), _cl(end + Vector2(th * 0.6, 0)), Color("#1A1A1E"), maxf(1.0, _s * 0.008), true)
			for i in 4:
				var x := lerpf(-0.5, 0.5, i / 3.0) * th
				_r_line(_cl(end), _cl(end + Vector2(x, _fh * 0.07)), Color(hair.darkened(0.1), 0.7), w, true)
		"dreads", "braids":
			var braids := String(_hs("bk", "")) == "braids"
			var n := 18 if braids else 15
			for i in n:
				var t := float(i) / (n - 1)
				var x := lerpf(-1.15, 1.15, t)
				var top := _px(x * 0.8, -0.6)
				var bottom := _px(x * 1.12 + rng.randf_range(-0.05, 0.05), rng.randf_range(0.8, 1.3))
				var th := _fw * (0.1 if braids else 0.16)
				var c := back_dark.darkened(rng.randf_range(0.0, 0.2))
				_r_line(_cl(top), _cl(bottom), c, th, true)
				_r_circle(_cl(bottom), th * 0.5, c)
				_r_line(_cl(top + Vector2(-th * 0.2, 0)), _cl(bottom + Vector2(-th * 0.2, 0)), Color(hair.lightened(0.15), 0.3), th * 0.25, true)
		"dread_bun":
			# Dreads presas num coque grande no alto
			var bc := _px(0.02, -1.2)
			var br := _fw * 0.46
			var bp := _blob(bc, br, br * 0.78, 0.1, 0.5, 9.0)
			for i in 10:
				var a0 := rng.randf() * TAU
				var rr := br * rng.randf_range(0.3, 0.85)
				var pts := PackedVector2Array()
				for j in 7:
					var a := a0 + j * 0.35
					pts.append(_cl(bc + Vector2(cos(a) * rr, sin(a) * rr * 0.75)))
				_r_polyline(pts, Color(hair.darkened(rng.randf_range(0.1, 0.35)), 0.8), _fw * 0.07, true)
				_r_polyline(pts, Color(hair.lightened(0.2), 0.3), _fw * 0.02, true)
			# pontas soltas caindo atrás
			for i in 6:
				var x := lerpf(-0.5, 0.5, i / 5.0)
				_r_line(_cl(_px(x, -1.05)), _cl(_px(x * 1.5, -0.55 + rng.randf_range(0.0, 0.2))), back_dark, _fw * 0.075, true)
		"puff", "puffs2":
			# Afro puff: bola de cabelo crespo no alto, atrás (ou duas, uma de cada lado)
			var two := String(_hs("bk", "")) == "puffs2"
			for side: float in ([-1.0, 1.0] if two else [0.0]):
				_puff(rng, hair, _px(side * 0.78, -1.02 if two else -1.18), (0.44 if two else 0.62) + float(f["vol"]) * 0.08)
		"bun_low":
			# Coque baixo na nuca: aparece um pouco ao lado do pescoço
			var bc := _px(0.62, 0.72)
			var br := _fw * 0.3
			var bp := _blob(bc, br, br * 0.85, 0.2, 0.2, 4.0)
			_strands_in_poly(rng, bp, hair, Vector2(-0.5, -1), 8)
		"bun", "knot":
			var knot := String(_hs("bk", "")) == "knot"
			var bc := _px(0.0, -1.12 if not knot else -1.18)
			var br := _fw * (0.34 if not knot else 0.26)
			var bp := _blob(bc, br, br * 0.9, 0.2, 0.2, 5.0)
			_strands_in_poly(rng, bp, hair, Vector2(0.5, -1), 10)
		"pony":
			var pts := PackedVector2Array([_px(0.55, 0.2), _px(0.95, 0.15), _px(1.2, 0.8), _px(1.05, 1.35), _px(0.8, 1.3), _px(0.85, 0.7)])
			var cols := PackedColorArray()
			for p in pts:
				cols.append(_hair_col(p, 0.6, 0.5, gloss).darkened(0.2))
			for i in pts.size():
				pts[i] = _cl(pts[i])
			_poly_colors(pts, cols)
			_strands_in_poly(rng, pts, hair, Vector2(0.2, 1.0), 14)


func _scalp_shine() -> void:
	var p := _px(-0.25, -0.8)
	_fill(_ellipse(p, _fw * 0.32, _fh * 0.11, 18), Color(1, 1, 1, 0.08))
	_fill(_ellipse(p + Vector2(-_fw * 0.04, -_fh * 0.01), _fw * 0.15, _fh * 0.05, 14), Color(1, 1, 1, 0.08))


func _accessories() -> void:
	var f := _f
	if bool(f["headband"]):
		var hy := float(f["hairline"]) - 0.02
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 13:
			var t := float(i) / 12.0
			var u := lerpf(-1.08, 1.08, t)
			pts.append(_cl(_px(u, hy - 0.05 - 0.05 * sin(PI * t))))
			cols.append(trim_color.lightened(0.1 * (1.0 - t)))
		for i in range(12, -1, -1):
			var t := float(i) / 12.0
			var u := lerpf(-1.08, 1.08, t)
			pts.append(_cl(_px(u, hy + 0.07 - 0.05 * sin(PI * t))))
			cols.append(trim_color.darkened(0.15 + 0.15 * t))
		_poly_colors(pts, cols)


# ---------------------------------------------------------------------------
# Desenho gravado
# ---------------------------------------------------------------------------

func _r_line(a: Vector2, b: Vector2, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_line(a, b, col, w, aa)
	if _recording:
		_rec.append([0, a, b, col, w, aa])


func _r_polyline(pts: PackedVector2Array, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_polyline(pts, col, w, aa)
	if _recording:
		_rec.append([1, pts, col, w, aa])


func _r_polyline_colors(pts: PackedVector2Array, cols: PackedColorArray, w: float = -1.0, aa: bool = false) -> void:
	draw_polyline_colors(pts, cols, w, aa)
	if _recording:
		_rec.append([2, pts, cols, w, aa])


func _r_circle(p: Vector2, r: float, col: Color) -> void:
	draw_circle(p, r, col, true, -1.0, true)
	if _recording:
		_rec.append([3, p, r, col])


func _r_arc(c: Vector2, r: float, a0: float, a1: float, n: int, col: Color, w: float = -1.0, aa: bool = false) -> void:
	draw_arc(c, r, a0, a1, n, col, w, aa)
	if _recording:
		_rec.append([4, c, r, a0, a1, n, col, w, aa])


func _r_polygon(pts: PackedVector2Array, cols: PackedColorArray) -> void:
	draw_polygon(pts, cols)
	if _recording:
		_rec.append([5, pts, cols])


func _r_colored_polygon(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	draw_colored_polygon(pts, col, uvs, tex)
	if _recording:
		_rec.append([6, pts, col, uvs, tex])


func _r_string(font: Font, pos: Vector2, text: String, fs: int, col: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if _recording:
		_rec.append([8, font, pos, text, fs, col])


func _r_tri(idx: PackedInt32Array, pts: PackedVector2Array, cols: PackedColorArray) -> void:
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)
	if _recording:
		_rec.append([7, idx, pts, cols])


func _r_tex_tri(idx: PackedInt32Array, pts: PackedVector2Array, cols: PackedColorArray, uvs: PackedVector2Array, tex: Texture2D) -> void:
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), tex.get_rid())
	if _recording:
		_rec.append([9, idx, pts, cols, uvs, tex])


func _replay(cmds: Array) -> void:
	var ci := get_canvas_item()
	for c: Array in cmds:
		match int(c[0]):
			0:
				draw_line(c[1], c[2], c[3], c[4], c[5])
			1:
				draw_polyline(c[1], c[2], c[3], c[4])
			2:
				draw_polyline_colors(c[1], c[2], c[3], c[4])
			3:
				draw_circle(c[1], c[2], c[3], true, -1.0, true)
			4:
				draw_arc(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8])
			5:
				draw_polygon(c[1], c[2])
			6:
				draw_colored_polygon(c[1], c[2], c[3], c[4])
			7:
				RenderingServer.canvas_item_add_triangle_array(ci, c[1], c[2], c[3])
			8:
				draw_string(c[1], c[2], c[3], HORIZONTAL_ALIGNMENT_LEFT, -1, c[4], c[5])
			9:
				var tex: Texture2D = c[5]
				if tex != null:
					RenderingServer.canvas_item_add_triangle_array(ci, c[1], c[2], c[3], c[4], PackedInt32Array(), PackedFloat32Array(), tex.get_rid())


# ---------------------------------------------------------------------------
# Geometria auxiliar
# ---------------------------------------------------------------------------

## Preenche um polígono; se ele se cruzar (traços extremos), limpa o contorno antes.
func _fill(pts: PackedVector2Array, col: Color, uvs: PackedVector2Array = PackedVector2Array(), tex: Texture2D = null) -> void:
	if pts.size() < 3:
		return
	if not Geometry2D.triangulate_polygon(pts).is_empty():
		_r_colored_polygon(pts, col, uvs, tex)
		if tex == null:
			_feather(pts, PackedColorArray([col]))
		return
	for piece in Geometry2D.offset_polygon(pts, 0.05):
		if not Geometry2D.triangulate_polygon(piece).is_empty():
			_r_colored_polygon(piece, col)
			_feather(piece, PackedColorArray([col]))


## Franja de ~1 px que vai da cor da borda ao transparente em volta de um polígono preenchido: o
## GLES3 não faz MSAA em 2D, e sem isso toda borda de polígono fica serrilhada. `cols` tem uma cor
## por ponto ou uma só para todos.
func _feather(pts: PackedVector2Array, cols: PackedColorArray, w: float = 0.9) -> void:
	var n := pts.size()
	if n < 3 or cols.is_empty():
		return
	var area := 0.0
	for i in n:
		area += pts[i].cross(pts[(i + 1) % n])
	if absf(area) < 1.0:
		return
	var sgn := 1.0 if area > 0.0 else -1.0
	var verts := PackedVector2Array(pts)
	var vcols := PackedColorArray()
	vcols.resize(n * 2)
	for i in n:
		var a := pts[(i - 1 + n) % n]
		var b := pts[i]
		var c := pts[(i + 1) % n]
		var nm := (b - a).orthogonal().normalized() + (c - b).orthogonal().normalized()
		nm = nm.normalized() if nm.length_squared() > 1e-4 else (c - b).orthogonal().normalized()
		verts.append(b + nm * sgn * w)
		var col: Color = cols[i] if cols.size() == n else cols[0]
		vcols[i] = col
		vcols[n + i] = Color(col, 0.0)
	var idx := PackedInt32Array()
	for i in n:
		var j := (i + 1) % n
		idx.append_array([i, n + i, n + j, i, n + j, j])
	_r_tri(idx, verts, vcols)


## Borda de uma malha radial com as cores do próprio último anel: a silhueta fica suave e no tom
## da pele (sem o contorno escuro de desenho animado).
func _rim(m: Array, n: int, alpha: float = 1.0, w: float = -1.0) -> void:
	var pts: PackedVector2Array = m[1]
	var cols: PackedColorArray = m[2]
	if n < 3 or pts.size() < n + 1:
		return
	var start := pts.size() - n
	var line := pts.slice(start)
	line.append(pts[start])
	var lc := cols.slice(start)
	lc.append(cols[start])
	for i in lc.size():
		lc[i] = Color(lc[i], lc[i].a * alpha)
	_r_polyline_colors(line, lc, w if w > 0.0 else maxf(1.0, _s * 0.004), true)


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(1.0, poly.size())


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _ellipse(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
