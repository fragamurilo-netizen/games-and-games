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

## Parâmetros de cada penteado: tp/sd = volume no alto/nas laterais, hl = franja (desce a linha do
## cabelo), sb = até onde descem as laterais, fd = degradê (1 leve, 2 alto, 3 lateral raspada),
## tx = textura forçada, sp = silhueta (1 reto no alto, 2 espetado, 3 cacheado, 4 crista),
## bk = parte de trás, fr = peça da frente, fl = direção dos fios (0 para trás, 1 de lado, 2 para
## baixo, 3 repartido ao meio), op = opacidade, gl = brilho extra, lk = comprimento das mechas.
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
	{"tp": 0.08, "sd": 0.03, "fd": 1, "fl": 1, "fr": "part", "gl": 0.15}, # social clássico
	{"tp": 0.09, "sd": 0.03, "hl": 0.12, "fd": 1, "fr": "crop", "fl": 2}, # crop francês
	{"tp": 0.13, "sd": 0.0, "fd": 3, "gl": 0.4}, # undercut para trás
	{"tp": 0.15, "sd": 0.0, "fd": 4, "sp": 5, "fl": 1}, # texturizado com degradê
	{"tp": 0.34, "sd": 0.1, "fd": 1, "sp": 3, "tx": "coil", "fr": "shaved_part"}, # afro com risco
	{"tp": 0.16, "sd": 0.0, "fd": 2, "tx": "locs", "fr": "locs_top"}, # dreads curtos com degradê
	{"tp": 0.24, "sd": 0.12, "tx": "coil", "fr": "twists", "sb": 0.1}, # twists longos
	{"tp": 0.1, "sd": 0.03, "fd": 2, "fr": "part", "fl": 1, "gl": 0.35}, # penteado de lado
	{"tp": 0.16, "sd": 0.1, "sb": 0.1, "sp": 5, "fl": 2, "hl": 0.12, "fr": "fringe"}, # médio bagunçado
	{"tp": 0.12, "sd": 0.07, "sb": 0.08, "fl": 3, "fr": "locks", "lk": 0.22, "fd": 1}, # cortina
	{"tp": 0.44, "sd": 0.1, "fd": 1, "sp": 3, "tx": "coil"}, # afro alto com degradê
	{"tp": 0.4, "sd": 0.02, "fd": 2, "sp": 1, "tx": "coil"}, # flat top
	{"tp": 0.14, "sd": 0.03, "hl": 0.18, "fd": 3, "fr": "fringe", "fl": 2}, # corte coreano
	{"tp": 0.0, "sd": 0.0, "fd": 3, "sp": 4, "tx": "coil"}, # frohawk
	{"tp": 0.03, "sd": 0.0, "fd": 2, "bk": "pony", "gl": 0.25}, # rabo com degradê
	{"tp": 0.12, "sd": 0.05, "fd": 1, "tx": "wavy", "fl": 1}, # ondulado curto
]

const LIGHT := Vector3(-0.45, -0.52, 0.72)
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
var _hair_style: Dictionary = {}
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


func _invalidate() -> void:
	queue_redraw()


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	var c := o + Vector2(s * 0.5, s * 0.5)
	if photo != null:
		_draw_photo(c, s)
		return
	if _dirty or _f.is_empty():
		_f = FaceGen.features(face_seed, eth, age, look)
		_dirty = false
	_prepare_decals(s)
	# Três camadas com cache próprio: fundo + cabelo de trás, corpo + roupa, rosto + cabelo.
	# Trocar o uniforme ou a estampa ficar pronta só redesenha a camada do corpo.
	var face_key := hash([face_seed, eth, age, look, size, bg_color])
	var k_back := hash(["back", face_key])
	var k_body := hash(["body", face_key, shirt_color, trim_color, suit, kit_collar, kit_pattern, kit, crest,
		_crest_tex != null, _sponsor_tex != null])
	var k_front := hash(["front", face_key])
	var ready := false
	for pair: Array in [[k_back, 0], [k_body, 1], [k_front, 2]]:
		var key: int = pair[0]
		if _cmd_cache.has(key):
			_replay(_cmd_cache[key])
			continue
		if not ready:
			_setup(c, s)
			ready = true
		_rec = []
		_recording = true
		match int(pair[1]):
			0:
				_layer_back()
			1:
				_body()
			2:
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
	_rim(_radial(_hc, head, _rings(11), _skin_px), head.size())
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
	# Borda
	_r_arc(_c, _R - 1.0, 0.0, TAU, 64, Color(bg_color.lightened(0.25), 0.6), maxf(1.0, _s * 0.012), true)


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
		var t2 := DecalCache.text_texture(String((sp as Dictionary)["n"]).to_upper(), self)
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
	_beard_p = FaceGen.BEARD_PARTS[int(f["beard"])]
	_shadow_p = FaceGen.BEARD_PARTS[FaceGen.B_STUBBLE]
	_hair_style = STYLE_P[int(f["style"])]
	_half = (_light + Vector3(0, 0, 1)).normalized()
	_shadow_col = Color(0.2, 0.22, 0.28).lerp(_skin.darkened(0.5), 0.5)
	var ag: float = f["aging"]
	var shadow: float = f["shadow"] if int(f["beard"]) != FaceGen.B_STUBBLE else 0.0
	_k = PackedFloat32Array([
		float(f["deep"]), float(f["ridge"]), 1.0 if bool(f["aquiline"]) else 0.0, float(f["bridge"]),
		float(f["nose_tip"]), 0.025 + 0.09 * ag + 0.04 * maxf(0.0, float(f["smile"])), float(f["cheekbone"]),
		0.07 * float(f["cheekbone"]) * (1.0 - float(f["fat"])), float(f["lip_l"]), 1.0 if bool(f["chin_cleft"]) else 0.0,
		ag, float(f["rosy"]), shadow, 0.05 + clampf(float(f["skin_i"]) / 9.0, 0.0, 1.0) * 0.1,
		float(f.get("dark_circles", 0.0))])
	_ND = float(f.get("nose_dx", 0.0))
	_blotches.clear()
	var br := RandomNumberGenerator.new()
	br.seed = int(f["blotch_seed"])
	for i in 5:
		_blotches.append([br.randf_range(-0.8, 0.8), br.randf_range(-0.8, 0.9), br.randf_range(0.15, 0.35), br.randf_range(-0.035, 0.03)])


func _contour_k() -> int:
	return clampi(int(24 * _det), 10, 30)


func _rings(n: int) -> int:
	return maxi(3, int(round(n * clampf(_det, 0.4, 1.2))))


func _draw_photo(c: Vector2, s: float) -> void:
	var pts := _ellipse(c, s * 0.5, s * 0.5, 48)
	var ts := photo.get_size()
	var side := minf(ts.x, ts.y)
	var uvs := PackedVector2Array()
	for p in pts:
		var rel := (p - c) / s # -0.5..0.5
		var px := ts * 0.5 + rel * side
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
func _strip(inner: PackedVector2Array, outer: PackedVector2Array, layers: int, shader: Callable) -> void:
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
	_emit([idx, pts, cols])


func _emit(m: Array) -> void:
	var idx: PackedInt32Array = m[0]
	if idx.is_empty():
		return
	_r_tri(idx, m[1], m[2])


## Mantém os pontos dentro do círculo do retrato (recorte barato das malhas).
func _cl(p: Vector2) -> Vector2:
	var d := p - _c
	var r := _R - 0.5
	if d.length_squared() > r * r:
		return _c + d.normalized() * r
	return p


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
	w *= 1.0 + float(f["fat"]) * 0.07 * _g(v - 0.55, 0.25)
	return w


## Expoente do crânio visto de frente: um pouco "quadrado" (superelipse), largo nas têmporas e
## arredondado no alto — uma elipse pura deixa a cabeça careca em forma de cone.
const SKULL_N := 2.35


## Meia largura do crânio (em fw) na altura `up` (0 = meio da cabeça, 1 = topo): a testa só
## estreita perto do alto, como num crânio real.
func _skull_rx(up: float) -> float:
	return lerpf(float(_f["cheek_w"]), float(_f["forehead"]), pow(clampf(up, 0.0, 1.0), 1.6))


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
		right.append(Vector2(_hw(v), v))
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
		return maxf(absf(u) / hw, v)
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
	# Luz "enrolada": a pele espalha a luz por dentro, então a passagem para a sombra é gradual
	var diff := clampf((nx * _light.x + ny * _light.y + nz * _light.z + 0.18) / 1.18, 0.0, 1.0)
	var lum := 0.47 + 0.6 * diff
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
			hump = 0.05 * exp(-b * b)
		lum += (0.1 * k[3] + hump) * ridge_hl
		a = (un - BW * 1.7) / (BW * 0.9)
		lum -= 0.2 * k[3] * exp(-a * a) * wv
		a = (un + BW * 1.9) / (BW * 0.9)
		lum -= 0.05 * k[3] * exp(-a * a) * wv
	if v > N - 0.25 and v < N + 0.12:
		a = (un + 0.02) / (NW * 0.45 * k[4])
		b = (v - (N - 0.07)) / 0.05
		lum += 0.09 * exp(-a * a - b * b)
		b = (v - (N - 0.035)) / 0.055
		bb = b * b
		a = (un - NW * 0.85) / (NW * 0.3)
		a2 = (un + NW * 0.85) / (NW * 0.3)
		lum -= 0.14 * (exp(-a * a - bb) + exp(-a2 * a2 - bb) * 0.6)
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
		lum -= 0.11 * exp(-a * a - b * b)
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
	# Manchas de tom (pele não é uniforme)
	for bl: Array in _blotches:
		a = (u - float(bl[0])) / float(bl[2])
		b = (v - float(bl[1])) / float(bl[2])
		lum += float(bl[3]) * exp(-a * a - b * b)
	var col := _shade(_skin, lum)
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
		var line := lerpf(N + 0.02, 0.2, smoothstep(MW * 0.8, MW * 1.5, au)) - 0.16 * smoothstep(0.55, 1.0, au)
		var dens := smoothstep(line - 0.08, line + 0.08, v)
		a = u / MW
		b = (v - M) / (k[8] * 2.2 + 0.03)
		dens *= smoothstep(0.8, 1.1, sqrt(a * a + b * b))
		col = col.lerp(_shadow_col, dens * k[12] * 0.32)
	# Brilho especular (mais visível em pele escura)
	var hx := _half.x
	var hy := _half.y
	var hz := _half.z
	var spec := pow(maxf(0.0, nx * hx + ny * hy + nz * hz), 26.0)
	a = (u + 0.5) / 0.2
	b = (v - 0.08) / 0.1
	spec *= k[13] * (0.6 + 0.8 * (fore * 0.9 + ridge_hl + exp(-a * a - b * b)))
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
	if wr <= 0.0:
		return
	var lw := maxf(0.7, _s * 0.005)
	var dark := Color(_skin.darkened(0.45), 0.12 + wr * 0.2)
	var light := Color(_skin.lightened(0.25), 0.06 + wr * 0.08)
	var lines := 1 + int(wr * 2.5)
	for k in lines:
		var y := -0.66 - k * 0.075 + _E
		var pts := PackedVector2Array()
		for i in 11:
			var t := float(i) / 10.0
			var u := lerpf(-0.5, 0.5, t)
			pts.append(_px(u, y - 0.03 * sin(PI * t) + 0.01 * sin(t * 13.0 + k)))
		_r_polyline(pts, dark, lw, true)
		var hl := PackedVector2Array()
		for p in pts:
			hl.append(p + Vector2(0, lw * 1.2))
		_r_polyline(hl, light, lw, true)
	if wr > 0.4:
		# Pés de galinha
		for sx: float in [-1.0, 1.0]:
			var ox := sx * (_X + float(f["eye_w"]) + 0.05)
			for k in 3:
				var a := _px(ox, _E + (k - 1) * 0.035)
				var b := _px(ox + sx * 0.1, _E + (k - 1) * 0.07)
				_r_line(a, b, Color(dark, dark.a * 0.8), lw * 0.8, true)
	if wr > 0.25:
		for sx: float in [-1.0, 1.0]:
			var pts := PackedVector2Array([_px(sx * _NW * 1.25, _N - 0.03), _px(sx * (_NW * 1.4 + _MW * 0.25), _N + 0.1), _px(sx * _MW * 1.12, _M + 0.05)])
			_r_polyline(pts, Color(dark, dark.a * (0.8 if sx > 0 else 0.5)), lw, true)
	if wr > 0.75:
		for sx: float in [-1.0, 1.0]:
			_r_line(_px(sx * _MW * 1.05, _M + 0.06), _px(sx * _MW * 1.2, _M + 0.2), Color(dark, dark.a * 0.6), lw, true)


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
	_chin_y = _hc.y + _fh
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


func _kit_band_pts(pattern: String) -> Array:
	# Faixas do uniforme (coordenadas do KitView) vestidas no tronco do retrato
	var out: Array = []
	for band: PackedVector2Array in KitView.pattern_bands(pattern):
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
	match ck:
		"v":
			collar = 0
		"round":
			collar = 1
		"wide":
			collar = 4
		"henley":
			collar = 1
			henley = true
		"polo":
			collar = 2
		"mandarin":
			collar = 3
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
	if pattern != "" and pattern != "plain":
		panels.append_array(_kit_band_pts(pattern))
	# Mangas de outra cor: raglan (costura do pescoço à axila) ou manga contrastante no ombro
	if sleeve == "contrast" or sleeve == "raglan":
		for sx: float in [-1.0, 1.0]:
			var sp := PackedVector2Array()
			if sleeve == "raglan":
				sp = PackedVector2Array([Vector2(_nwt * 1.2, _ynb - s * 0.03), Vector2(_sw * 1.3, _ynb - s * 0.05), Vector2(_sw * 1.3, _c.y + s * 0.6 - _hc.y), Vector2(_sw * 0.86, _c.y + s * 0.6 - _hc.y)])
			else:
				sp = PackedVector2Array([Vector2(_sw * 0.8, _ysp - s * 0.06), Vector2(_sw * 1.3, _ysp - s * 0.06), Vector2(_sw * 1.3, _c.y + s * 0.6 - _hc.y), Vector2(_sw * 0.9, _c.y + s * 0.6 - _hc.y)])
			var poly := PackedVector2Array()
			var n := sp.size()
			for i in n:
				for k in 6:
					var q := sp[i].lerp(sp[(i + 1) % n], k / 6.0)
					poly.append(Vector2(_hc.x + sx * q.x, _hc.y + q.y))
			panels.append(poly)
	for band: PackedVector2Array in panels:
		for piece in Geometry2D.intersect_polygons(band, shirt):
			var cols := PackedColorArray()
			for i in piece.size():
				piece[i] = _cl(piece[i])
				cols.append(_shade(c2, _cloth_lum(piece[i], neck_low)))
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
		else:
			_r_line(_cl(a), _cl(b), Color(0, 0, 0, 0.1), maxf(0.6, s * 0.004), true)
	# Escudo, fornecedor e patrocinador no peito
	_chest_marks(body_col, c2, trim, neck_low)
	# Gola
	var lw := s * 0.02
	match collar:
		0, 1, 4:
			_band(line, lw * (1.1 if collar == 0 else (1.35 if collar == 4 else 1.0)), trim)
			if henley:
				_placket(line[line.size() / 2], trim, body_col, 3)
		3:
			_band(line, s * 0.035, trim, true)
			var bx := _hc.x
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
		if (ec - _c).length() < _R - r * 1.5:
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
		if (sc - _c).length() < _R - s * 0.04:
			var ink := _shade(_ink_on(sup, body_col), _cloth_lum(sc, neck_low))
			_supplier_logo(sc, s * 0.022, String(sup.get("logo", "")), String(sup.get("n", "")), ink)
	# Patrocinador master no peito (o que couber no retrato)
	var sp: Dictionary = kit.get("sp", {}) if kit.get("sp") is Dictionary else {}
	var name := String(sp.get("n", "")).to_upper()
	if name == "" or s < 90.0:
		return
	var ink_sp := _ink_on(sp, body_col)
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
	if fs >= 6 and pos.y < _c.y + _R * 0.95:
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
			if (p - _c).length() > _R - 1.0:
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
		if (bp - _c).length() < _R - 2.0:
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
		if (bp - _c).length() < _R - 2.0:
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
	for sx: float in [-1.0, 1.0]:
		var ec := _px(sx * (float(f["cheek_w"]) * 0.97 + out * 0.07), 0.04)
		var ew := _fw * (0.15 + out * 0.04) * er
		var eh := _fh * 0.2 * er
		var pts := PackedVector2Array()
		var en := 12 if _s < 90.0 else 20
		for i in en:
			var a := TAU * i / en
			var y := sin(a)
			var x := cos(a) * (0.8 if y > 0.2 else 1.0) * lerpf(1.0, 0.7, clampf(y, 0.0, 1.0))
			pts.append(ec + Vector2(x * ew, y * eh))
		var lit := -sx
		var em := _radial(ec, pts, _rings(3), func(p: Vector2, t: float, _i: int) -> Color:
			var d := (p - ec) / Vector2(ew, eh)
			var lum := 0.8 + 0.1 * lit
			lum -= 0.22 * _g2(d.x + sx * 0.15, d.y + 0.05, 0.4, 0.45)
			lum += 0.1 * smoothstep(0.6, 0.95, t) * (1.0 if d.y < 0.3 else 0.3)
			var c := _shade(_skin, lum)
			return c.lerp(Color(0.85, 0.35, 0.3), 0.08 + 0.05 * float(f["rosy"])))
		_rim(em, pts.size())
		var lw := maxf(0.8, _s * 0.006)
		var a0 := -PI * 0.5 if sx > 0 else PI * 0.5
		_r_arc(ec + Vector2(sx * ew * 0.1, -eh * 0.05), ew * 0.55, a0, a0 + PI, 10, Color(_skin.darkened(0.35), 0.55), lw, true)
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
	var lw := maxf(0.9, _s * 0.009)
	var mono: bool = f["monolid"]
	var hooded: bool = f["hooded"]
	var asym: float = f["asym"]
	for sx: float in [-1.0, 1.0]:
		var cx := _hc.x + sx * _X * _fw
		var cy := _hc.y + _E * _fh + sx * asym * _fh * 0.012
		var inner := Vector2(cx - sx * ew, cy + tilt * 0.35 + (eh * 0.12 if mono else 0.0))
		var outer := Vector2(cx + sx * ew, cy - tilt)
		var upper := PackedVector2Array()
		var lower := PackedVector2Array()
		for i in 15:
			var t := float(i) / 14.0
			var base := inner.lerp(outer, t)
			var peak := pow(t, 0.78) if not mono else pow(t, 1.0)
			upper.append(base + Vector2(0, -sin(PI * peak) * eh * (0.85 if mono else 1.0)))
			lower.append(base + Vector2(0, sin(PI * pow(t, 1.15)) * eh * 0.52))
		var sclera := PackedVector2Array(upper)
		for i in range(lower.size() - 2, 0, -1):
			sclera.append(lower[i])
		var ecen := Vector2(cx, cy)
		var sc_base := Color("#E4DED4").lerp(_skin, 0.12)
		_radial(ecen, sclera, 2 if _s < 90.0 else 3, func(p: Vector2, t: float, _i: int) -> Color:
			var lum := 1.0 - 0.32 * t * t - (0.28 if p.y < cy else 0.0) * t
			return _shade(sc_base, lum))
		# Íris com anel escuro, centro claro e sombra da pálpebra
		var iris_col := eye_b if het == 1 and sx == het_side else iris_main
		var sector := het == 2 and sx == het_side
		var ic := Vector2(cx + float(f["gaze"]) * ew * 0.3, cy + eh * 0.12)
		var ir := minf(eh * 1.3, ew * 0.47)
		for piece in Geometry2D.intersect_polygons(_ellipse(ic, ir, ir, 12 if _s < 90.0 else 20), sclera):
			if not Geometry2D.is_point_in_polygon(ic, piece):
				_fill(piece, iris_col.darkened(0.3))
				continue
			_radial(ic, piece, 2 if _s < 90.0 else 4, func(p: Vector2, _t: float, _i: int) -> Color:
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
		_r_circle(ic + Vector2(-ir * 0.34, -ir * 0.36), maxf(0.7, ir * 0.2), Color(1, 1, 1, 0.9))
		_r_circle(ic + Vector2(ir * 0.3, ir * 0.25), maxf(0.4, ir * 0.09), Color(1, 1, 1, 0.35))
		# Carúncula
		_r_circle(inner + Vector2(sx * ew * 0.1, eh * 0.05), maxf(0.6, eh * 0.18), Color(0.85, 0.5, 0.5, 0.55))
		# Linha dos cílios (mais grossa por fora) e cílios
		var lash := Color("#2B1D15").lerp(_skin.darkened(0.7), 0.25)
		_r_polyline(upper, Color(lash, 0.62), lw * 0.9, true)
		_r_polyline(upper.slice(7), Color(lash, 0.5), lw * 1.25, true)
		var ln := float(f["lashes"]) * 0.7
		for k in (3 if _s > 110.0 else 0):
			var t := 0.62 + k * 0.08
			var i := int(t * 14.0)
			var p0: Vector2 = upper[mini(i, 14)]
			_r_line(p0, p0 + Vector2(sx * 0.6, -1.0).normalized() * eh * 0.45 * ln, Color(lash, 0.75), lw * 0.7, true)
		_r_line(outer, outer + Vector2(sx * ew * 0.08, -eh * 0.12), Color(lash, 0.4), lw * 0.9, true)
		_r_polyline(lower, Color(lash, 0.22), lw * 0.7, true)
		var wl := PackedVector2Array()
		for p in lower.slice(2, 13):
			wl.append(p + Vector2(0, lw * 0.6))
		_r_polyline(wl, Color(_skin.lightened(0.25), 0.25), lw * 0.6, true)
		# Dobra da pálpebra
		if not mono:
			var crease := PackedVector2Array()
			var off := eh * (0.38 if hooded else 0.62)
			for p in upper.slice(2, 13):
				crease.append(p + Vector2(0, -off))
			_r_polyline(crease, Color(_skin.darkened(0.4), 0.38), lw * 0.8, true)
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
	var wline := maxf(0.6, _s * 0.0034)
	var asym: float = f["asym"]
	var slit: int = int(f.get("brow_slit", 0))
	var slit_n := slit % 10
	var slit_side := slit / 10
	for sx: float in [-1.0, 1.0]:
		var cx := _hc.x + sx * _X * _fw
		var by := _hc.y + (_E - float(f["brow_gap"])) * _fh - sx * asym * _fh * 0.018
		var x0 := cx - sx * ew * 1.05
		var path := PackedVector2Array()
		var thick := PackedFloat32Array()
		for i in 12:
			var t := float(i) / 11.0
			var x := x0 + sx * blen * t
			var y := by - arch * sin(PI * minf(t / 0.7, 1.0) * 0.5) * (1.0 if t < 0.7 else 1.0 - (t - 0.7) * 1.8) - tilt * t
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
			for j in steps + 1:
				var t := lerpf(ta, tb, float(j) / steps)
				var fi := t * 11.0
				var i0 := mini(int(fi), 10)
				var lt := fi - i0
				var p := path[i0].lerp(path[i0 + 1], lt)
				var tk := lerpf(thick[i0], thick[i0 + 1], lt)
				# O risco corta na diagonal (o pelo de cima inclina para fora)
				top.append(p + Vector2(0, -tk * 0.5))
				bot.append(p + Vector2(0, tk * 0.5))
			bot.reverse()
			var poly := PackedVector2Array(top)
			poly.append_array(bot)
			_fill(poly, Color(col, base_a * dens + 0.1))
		var n := int(75 * dens * clampf(_det, 0.4, 1.6))
		for k in n:
			var t := pow(rng.randf(), 0.85)
			var in_gap := false
			for g: Vector2 in gaps:
				if t > g.x - 0.012 and t < g.y + 0.012:
					in_gap = true
			if in_gap:
				continue
			var i := mini(int(t * 11.0), 10)
			var lt := t * 11.0 - i
			var p := path[i].lerp(path[i + 1], lt)
			var tk := lerpf(thick[i], thick[i + 1], lt)
			p.y += rng.randf_range(-0.45, 0.45) * tk
			var dir: Vector2
			if t < 0.18:
				dir = Vector2(-sx * 0.2, -1.0)
			else:
				var a := lerpf(-0.9, 0.3, clampf((t - 0.18) / 0.8, 0.0, 1.0))
				dir = Vector2(sx * cos(a), sin(a))
			var ln := tk * rng.randf_range(0.6, 1.05) + _s * 0.002
			_r_line(p, p + dir.normalized() * ln, Color(col.darkened(rng.randf_range(0.0, 0.2)), rng.randf_range(0.35, 0.7)), wline, true)
	if bool(f["unibrow"]):
		for k in int(10 * clampf(_det, 0.5, 1.5)):
			var p := _px(rng.randf_range(-0.15, 0.15), _E - float(f["brow_gap"]) + rng.randf_range(-0.02, 0.02))
			_r_line(p, p + Vector2(0, -_s * 0.008), Color(col, 0.4), wline, true)


func _nose() -> void:
	var f := _f
	var lw := maxf(0.8, _s * 0.007)
	var dark := _skin.darkened(0.62)
	for sx: float in [-1.0, 1.0]:
		var nc := _pxn(sx * _NW * 0.45, _N + 0.004)
		var rx := _NW * _fw * 0.2
		var ry := _fh * 0.02
		_fill(_ellipse(nc, rx * 1.6, ry * 1.6, 12), Color(dark, 0.14))
		_fill(_ellipse(nc + Vector2(sx * rx * 0.1, 0), rx, ry, 12), Color(dark, 0.5))
		# Asa do nariz
		var wc := _pxn(sx * _NW * 0.82, _N - 0.03)
		var a0 := PI * 0.5 - sx * 0.6
		_r_arc(wc, _NW * _fw * 0.28, a0 - sx * PI * 0.9, a0 + sx * 0.2, 10, Color(_skin.darkened(0.4), 0.14 if sx < 0 else 0.24), lw, true)
	var side := PackedVector2Array([_pxn(_BW * 1.1, _E + 0.1), _pxn(_BW * 1.3, (_E + _N) * 0.5), _pxn(_NW * 0.75, _N - 0.07)])
	_r_polyline(side, Color(_skin.darkened(0.45), 0.14), lw * 1.2, true)
	var tip := PackedVector2Array()
	for i in 9:
		var t := float(i) / 8.0
		tip.append(_pxn(lerpf(-_NW * 0.35, _NW * 0.35, t), _N + 0.018 + sin(PI * t) * 0.012))
	_r_polyline(tip, Color(_skin.darkened(0.4), 0.25), lw, true)


func _mouth() -> void:
	var f := _f
	var smile: float = f["smile"]
	var mw := _MW * _fw
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
	var corner_y := mouth_y - smile * _fh * 0.03
	var bow: float = f["bow"]
	var line := PackedVector2Array()
	var up := PackedVector2Array()
	var lo := PackedVector2Array()
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw, mw, t)
		var yb := lerpf(corner_y, mouth_y + smile * _fh * 0.008, sin(PI * t))
		line.append(Vector2(x, yb))
		var cupid := ul * 0.3 * bow * _g(t - 0.5, 0.06)
		up.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) - sin(PI * t) * ul + cupid))
	for i in 15:
		var t := float(i) / 14.0
		var x := _hc.x + lerpf(-mw * 0.9, mw * 0.9, t)
		lo.append(Vector2(x, lerpf(corner_y, mouth_y, sin(PI * t)) + sin(PI * t) * ll))
	# Lábio superior (cor por vértice: mais escuro junto à linha da boca)
	var upper := PackedVector2Array(up)
	var ucol := PackedColorArray()
	for i in up.size():
		ucol.append(lip_up.lightened(0.05))
	for i in range(line.size() - 1, -1, -1):
		upper.append(line[i])
		ucol.append(lip_up.darkened(0.15))
	_poly_colors(upper, ucol)
	# Lábio inferior (claro no meio, com brilho)
	var lower := PackedVector2Array(line)
	var lcol := PackedColorArray()
	for i in line.size():
		lcol.append(lip_lo.darkened(0.12))
	var lo_r := lo.duplicate()
	lo_r.reverse()
	for i in lo_r.size():
		var t := float(i) / 14.0
		lcol.append(lip_lo.lightened(0.05 * sin(PI * t)).darkened(0.08 * (1.0 - sin(PI * t))))
	lower.append_array(lo_r)
	_poly_colors(lower, lcol)
	_fill(_ellipse(Vector2(_hc.x - mw * 0.14, mouth_y + ll * 0.48), mw * 0.22, ll * 0.14, 12), Color(1, 1, 1, 0.07 + darkness * 0.03))
	# Contornos suaves
	var lw := maxf(0.8, _s * 0.007)
	var ol := PackedVector2Array(up)
	_r_polyline(ol, Color(lip_up.darkened(0.1), 0.35), lw * 0.8, true)
	var olo := PackedVector2Array(lo)
	_r_polyline(olo, Color(lip_lo, 0.35), lw * 0.8, true)
	var lc := PackedColorArray()
	for i in line.size():
		var t := float(i) / 14.0
		lc.append(Color("#3A1C1B", 0.3 + 0.35 * sin(PI * t)))
	_r_polyline_colors(line, lc, lw, true)
	for sx: float in [-1.0, 1.0]:
		_r_circle(Vector2(_hc.x + sx * mw, corner_y), lw * 0.6, Color(0.1, 0.05, 0.05, 0.14))


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
	var soft := lerpf(0.09, 0.025, sharp)
	var ln: float = P["ln"]
	var lip_u: float = f["lip_u"] * 2.0
	var lip_l: float = f["lip_l"] * 2.0
	var d := 0.0
	# Bochechas
	var ch: float = P["ch"]
	var cn: float = P["cn"]
	if ch > 0.0:
		var line := lerpf(_N + 0.02, -0.02 + ch * 0.75, smoothstep(_MW * 0.8, _MW * 1.5, au)) - 0.16 * smoothstep(0.55, 1.0, au)
		var dc := smoothstep(line - soft, line + soft, v)
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
		var rx := _MW * (0.45 + cn * 0.6) * (1.0 + float(P.get("rd", 0.0)) * 0.45)
		var ke := 2.0 + 2.5 * float(P.get("sq", 0.0)) * float(v > cy)
		var e := pow(pow(absf(u / rx), ke) + pow(absf((v - cy) / ry), ke), 1.0 / ke)
		d = maxf(d, 1.0 - smoothstep(1.0 - soft * 3.0, 1.0 + soft, e))
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
		var wx := _MW * (0.95 if mu == 2 else (1.16 if mu == 4 else (1.22 if mu == 5 else (1.3 if mu == 8 else (1.0 if mu == 7 else 1.08)))))
		var yr := smoothstep(top_y - soft, top_y + soft, v) * (1.0 - smoothstep(bot_y - soft * 0.5, bot_y + soft * 0.5, v + au * 0.1))
		var xr := 1.0 - smoothstep(wx - soft, wx + soft, au)
		var dm := yr * xr
		if mu == 2 or mu == 5:
			dm *= smoothstep(0.02, 0.06, au)
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
			var hang := (1.0 - smoothstep(0.018, 0.018 + soft, absf(au - _MW * 1.07 - (v - _M) * 0.06))) * smoothstep(_M - 0.05, _M - 0.01, v) * (1.0 - smoothstep(1.25, 1.33, v))
			dm = maxf(dm, hang)
		if mu == 8:
			# Morsa: bigode cheio que cobre o lábio de cima, com a borda de baixo arredondada
			var edge8 := bot_y + 0.04 * (1.0 - pow(clampf(au / wx, 0.0, 1.0), 2.0))
			dm = maxf(dm, (1.0 - smoothstep(wx - soft, wx + soft, au)) * smoothstep(top_y - soft, top_y + soft, v) * (1.0 - smoothstep(edge8 - soft * 0.5, edge8 + soft * 0.5, v)))
		d = maxf(d, dm)
	# Cavanhaque fechado: ligação dos cantos da boca ao queixo
	if float(P.get("ci", 0.0)) > 0.0:
		var ring := (1.0 - smoothstep(0.05, 0.05 + soft, absf(au - _MW * 1.04))) * smoothstep(_M - 0.06, _M - 0.02, v) * (1.0 - smoothstep(_M + lip_l + 0.1, _M + lip_l + 0.16, v))
		d = maxf(d, ring)
	# Mosca
	var so: float = P["so"]
	if so > 0.0:
		var sy := _M + lip_l + 0.06
		d = maxf(d, so * (1.0 - smoothstep(0.7, 1.1, sqrt(pow(u / 0.07, 2.0) + pow((v - sy) / 0.05, 2.0)))))
	# Pescoço: só onde há pescoço embaixo (ele é mais estreito que a mandíbula)
	var nk: float = P["nk"]
	var neck_half := _neck_half()
	var over_neck := smoothstep(0.62, 0.9, v) * (1.0 - smoothstep(neck_half * 0.8, neck_half * 1.02, au))
	if nk > 0.0 and v > 0.6:
		d = maxf(d, nk * over_neck * smoothstep(0.98, 1.04, th) * (1.0 - smoothstep(1.1 + ln, 1.3 + ln, v)))
	# Fora do rosto: a barba tem espessura própria e some aos poucos a partir do contorno. Nas
	# laterais da mandíbula (fundo atrás) quase não passa da pele; embaixo do queixo, sobre o
	# pescoço, a barba comprida desce
	if th > 1.0:
		var reach := lerpf(0.012 + ln * 0.55, (0.03 + ln * 0.9) / 0.6, over_neck)
		d *= 1.0 - smoothstep(reach * 0.2, reach, th - 1.0)
	# Risco raspado na bochecha
	if float(P.get("cut", 0.0)) > 0.0:
		var cd := _seg_dist(Vector2(au, v), Vector2(0.78, 0.05), Vector2(0.52, 0.42))
		d *= smoothstep(0.012, 0.028, cd)
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
	var col: Color = f["beard_col"]
	var gray := clampf(float(f["gray"]) * 1.6, 0.0, 0.8)
	var short := int(P["tx"]) == 0
	# Barba rala: a malha é só uma sombra leve e contínua; quem desenha as falhas são os fios
	var patchy := minf(1.0, _beard_patchiness(P) * 1.6)
	var head := _head_contour(_contour_k())
	var grown := PackedVector2Array()
	for p in head:
		var q := _uv(p)
		# Folga além de onde a densidade zera: a borda da barba é o degradê, nunca o fim da malha
		var ext := 0.035 * smoothstep(-0.45, -0.2, q.y)
		if q.y > 0.0:
			ext += (0.05 + ln * 1.05 * pow(q.y, 1.5)) * smoothstep(0.0, 0.4, q.y)
			ext *= 1.0 + float(P.get("sq", 0.0)) * (0.9 * smoothstep(0.15, 0.55, absf(q.x)) - 0.25 * (1.0 - smoothstep(0.0, 0.2, absf(q.x))))
			ext *= 1.0 - float(P.get("pp", 0.0)) * 0.65 * smoothstep(0.05, 0.45, absf(q.x))
			ext *= 1.0 + float(P.get("wild", 0.0)) * (0.18 * sin(q.x * 23.0 + 1.3) + 0.12 * sin(q.x * 41.0))
		var dir := (p - _hc).normalized()
		grown.append(p + Vector2(dir.x * _fw, dir.y * _fh) * ext + Vector2(0, _fh * ext * 0.6 * float(q.y > 0.5)))
	_beard_data = _radial(_hc, grown, _rings(13), func(p: Vector2, t: float, _i: int) -> Color:
		var q := _uv(p)
		var dens := _beard_dens(q.x, q.y, P, false) * (1.0 - smoothstep(0.9, 1.0, t))
		if dens <= 0.0:
			return Color(col, 0.0)
		dens *= 1.0 - 0.5 * patchy * smoothstep(0.15, 0.45, absf(q.x))
		var lum := 0.95 - 0.22 * clampf(q.x, -1.0, 1.0) - 0.2 * smoothstep(0.6, 1.3, q.y) + 0.12 * _g2(q.x + 0.3, q.y - 0.5, 0.3, 0.2)
		lum += 0.05 * sin(q.x * 23.0 + q.y * 7.0) * sin(q.y * 19.0 - q.x * 5.0)
		var c := col.lerp(Color.BLACK, (1.0 - lum) * 0.6) if lum < 1.0 else col.lerp(col.lightened(0.3), lum - 1.0)
		# Pontas mais claras e mais quentes no queixo e nas bochechas
		c = c.lerp(col.lightened(0.18).lerp(Color("#8A5A3A"), 0.15), 0.25 * smoothstep(0.7, 1.2, q.y) + 0.1 * smoothstep(0.4, 0.8, absf(q.x)))
		# Os primeiros fios brancos aparecem nos cantos do queixo
		c = c.lerp(Color("#D9D6D0"), gray * _g2(absf(q.x) - 0.3, q.y - 0.95, 0.16, 0.22))
		if short:
			# Barba por fazer vista de longe é uma sombra fria na pele, não uma mancha marrom
			c = c.lerp(_shadow_col, 0.4)
		return Color(c, dens * op))


func _beard_hairs(rng: RandomNumberGenerator) -> void:
	if _beard_data.size() < 3:
		return
	if float(_beard_p.get("wild", 0.0)) > 0.0:
		var wc: Color = _f["beard_col"]
		for i in int(40 * clampf(_det, 0.4, 1.6)):
			var a := rng.randf_range(0.15, PI - 0.15)
			var r := rng.randf_range(0.85, 1.35)
			var p := _px(cos(a) * float(_f["cheek_w"]) * r * 0.9, 0.55 + sin(a) * (0.55 + float(_beard_p["ln"])) * r)
			var dir := Vector2(cos(a), sin(a) * 1.2).normalized()
			_r_line(_cl(p), _cl(p + dir * _s * rng.randf_range(0.015, 0.035)), Color(wc.lightened(rng.randf_range(0.0, 0.2)), 0.35), maxf(0.6, _s * 0.003), true)
	var f := _f
	var P := _beard_p
	var col: Color = f["beard_col"]
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
	var w := maxf(0.6, _s * 0.0036)
	var jit := _fw * 0.05
	for k in n:
		var i := cand[rng.randi() % cand.size()]
		var dens := cols[i].a / maxf(op, 0.01)
		if rng.randf() > dens:
			continue
		var p := pts[i] + Vector2(rng.randf_range(-jit, jit), rng.randf_range(-jit, jit))
		if (p - _c).length() > _R - 1.0:
			continue
		# A raiz precisa estar dentro da barba (o sorteio perto do vértice pode cair fora dela); as
		# falhas da barba rala também são desenhadas aqui, na posição exata de cada fio
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
		_r_polyline(PackedVector2Array([p, mid, tip]), Color(c, a), w * 0.85, true)


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
	var lum := 0.66 + 0.36 * dn.dot(Vector2(-0.55, -0.83))
	lum *= 0.78 + 0.22 * smoothstep(0.0, 0.45, w)
	lum *= 1.0 - 0.12 * smoothstep(0.85, 1.0, w)
	var c := hair.lerp(Color.BLACK, clampf((1.0 - lum) * 0.75, 0.0, 0.9))
	var tex: int = int(f["texture"])
	var gl: float = float([0.5, 0.36, 0.2, 0.1][tex]) + gloss
	var ang := atan2(q.y, q.x)
	var sheen := _g(ang + PI * 0.62, 0.5) * _g(w - 0.6, 0.3)
	sheen *= 0.78 + 0.22 * sin(t * 97.0 + float(int(f["hair_seed"]) % 100)) * sin(t * 41.0 + 1.3)
	c = c.lerp(hair.lightened(0.55).lerp(Color(0.8, 0.8, 0.85), 0.15 if hair.v < 0.2 else 0.0), clampf(sheen * gl, 0.0, 0.7))
	if bool(f["tips"]):
		c = c.lerp(Color("#E2C98C"), smoothstep(0.35, 0.95, w) * 0.85)
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
			a *= lerpf(0.16, 1.0, smoothstep(0.62, 0.7, h))
		4: # burst: raspado em volta da orelha, cheio no alto e na nuca
			a *= lerpf(0.1, 1.0, maxf(smoothstep(0.3, 0.55, h), 1.0 - smoothstep(0.55, 0.8, absf(q.x))))
	if int(_hs("sp", 0)) == 4:
		a *= lerpf(0.14, 1.0, 1.0 - smoothstep(0.22, 0.3, absf(q.x)))
	var crown: float = f["crown"]
	if crown > 0.0:
		a *= 1.0 - minf(1.0, crown * 1.3) * _g(q.x, 0.7) * smoothstep(0.35, 0.8, h) * smoothstep(0.05, 0.4, w)
	var sharp: bool = bool(f["lineup"]) or _hs("tx", "") in ["braid", "braid_zig", "waves"]
	# Linha do cabelo: o cabelo nasce ralo e vai enchendo (sem a "tarja" de borda dura na testa)
	a *= lerpf(0.9 if sharp else 0.0, 1.0, smoothstep(0.0, 0.08 if sharp else 0.3, w))
	# Pontas das laterais (costeletas): afinam até sumir em vez de terminar num corte reto
	var sb := float(_hs("sb", 0.0))
	a *= 1.0 - smoothstep(sb - 0.16, sb + 0.01, q.y) * (0.6 if sharp else 1.0)
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
			if not bool(f["lineup"]):
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
		_cap_in.append(_px(inner[i].x, inner[i].y))
		_cap_out.append(_px(outer[i].x, outer[i].y))


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
	_strip(_cap_in, _cap_out, _rings(7), func(p: Vector2, t: float, w: float) -> Color:
		var c := _hair_col(p, w, t, gloss)
		return Color(c, _cap_alpha(p, w)))
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
	var tex := String(_hs("tx", ["str", "wavy", "curl", "coil"][int(f["texture"])]))
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
			for i in 11:
				var t := 0.12 + 0.76 * i / 10.0
				var base := _cap_pt(t, 0.8)
				var tip := _cap_pt(t + rng.randf_range(-0.02, 0.02), 1.0)
				tip += (tip - _hc).normalized() * _fw * rng.randf_range(0.12, 0.22)
				_tuft(base, tip, _fw * 0.09, rng.randf_range(-0.2, 0.2), _hair_col(tip, 0.95, t, 0.15))
		4:
			var hl0: float = float(f["hairline"])
			var faux := int(_hs("fd", 0)) != 3
			var h := (0.16 + float(f["vol"]) * 0.12) * (0.55 if faux else 1.0)
			var cw := 1.7 if faux else 1.0
			var shape := [Vector2(-0.2 * cw, hl0 + 0.02), Vector2(-0.25 * cw, -0.75), Vector2(-0.22 * cw, -1.05 - h * 0.6), Vector2(-0.1, -1.05 - h), Vector2(0.1, -1.05 - h), Vector2(0.22 * cw, -1.05 - h * 0.6), Vector2(0.25 * cw, -0.75), Vector2(0.2 * cw, hl0 + 0.02)]
			if faux:
				# Faux hawk: volume arredondado que sobe até uma ponta no meio
				shape = [Vector2(-0.34, hl0 + 0.02), Vector2(-0.42, -0.75), Vector2(-0.36, -1.0 - h * 0.5), Vector2(-0.18, -1.04 - h * 0.95),
					Vector2(0.02, -1.05 - h * 1.35), Vector2(0.2, -1.04 - h * 0.9), Vector2(0.36, -1.0 - h * 0.45), Vector2(0.42, -0.75), Vector2(0.34, hl0 + 0.02)]
			var crest := PackedVector2Array()
			var ccol := PackedColorArray()
			for i in shape.size():
				var q: Vector2 = shape[i]
				crest.append(_cl(_px(q.x, q.y)))
				var cc := _hair_col(crest[i], 0.3 + 0.6 * clampf(-(q.y + 0.6) / 0.8, 0.0, 1.0), float(i) / 7.0, 0.2).darkened(0.12 if q.x > 0.0 else 0.0)
				# A base da crista nasce do degradê (meio transparente), não cola na testa como um chapéu
				ccol.append(Color(cc, 0.45 if i == 0 or i == shape.size() - 1 else 1.0))
			if faux:
				for i in 7:
					var ux := lerpf(-0.3, 0.3, i / 6.0)
					var base := _px(ux, -1.0 - h * 0.6)
					var tip := _px(ux * 1.2 + 0.03, -1.05 - h * (1.3 - absf(ux) * 1.2) - 0.05)
					var side := Vector2(_fw * 0.07, 0)
					var tc := _hair_col(tip, 0.95, float(i) / 6.0, 0.15)
					_r_polygon(PackedVector2Array([_cl(base - side), _cl(tip), _cl(base + side)]), PackedColorArray([tc.darkened(0.2), tc.lightened(0.1), tc.darkened(0.1)]))
			_poly_colors(crest, ccol)
			if String(_hs("ck", "")) == "locs":
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
	if _s < 80.0 or bool(_f["lineup"]) or tex in ["braid", "braid_zig", "waves", "dots", "locs"]:
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
			# Crespos: pontinhos e voltinhas curtas em vez de fios lisos
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
	_feather(pts, cols)
	var w := maxf(0.7, _s * 0.003)
	_r_polyline(left.slice(0, n - 1), Color(col.darkened(0.3), 0.2), w, true)
	_r_polyline(right.slice(0, n - 1), Color(col.darkened(0.3), 0.2), w, true)
	_r_polyline(mid.slice(1, n - 1), Color(col.lightened(0.3), 0.25), w, true)


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
		lower.append(p + Vector2(0.0, _fh * (0.05 + 0.03 * float(_hs("hl", 0.0)) / 0.3)))
	_strip(_cap_in, lower, 2, func(p: Vector2, t: float, w: float) -> Color:
		var i := clampi(int(round(t * (n - 1))), 0, n - 1)
		return Color(_shadow_col.darkened(0.3), a[i] * (1.0 - w) * (1.0 - w)))


## Textura do cabelo sobre a calota.
func _cap_texture(rng: RandomNumberGenerator, tex: String, hair: Color) -> void:
	var f := _f
	var w := maxf(0.6, _s * 0.0036)
	var k := clampf(_det * _det, 0.1, 2.0)
	var flow := int(_hs("fl", 0))
	var part := 0.5 + float(f["part_side"]) * 0.19
	match tex:
		"str", "wavy":
			var n := int(200 * k)
			w = maxf(0.6, _s * 0.0026)
			var hl_on: bool = bool(f.get("highlights", false))
			var hl_col := Color("#D8B46A").lerp(hair, 0.15)
			var wave_ph := float(int(f["hair_seed"]) % 17)
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
						# Ondas em fase com as vizinhas: o cabelo ondula em mechas, não fio a fio
						tt += 0.011 * sin(ww * 10.0 + t0 * 5.0 + wave_ph)
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
					c = hl_col.lerp(Color.WHITE, rng.randf_range(0.0, 0.2))
				elif roll < 0.45:
					c = _hair_col(pts[3], 0.6, t0, 0.3).lerp(hair.lightened(0.5), 0.15)
				elif roll < 0.55:
					c = hair.lightened(0.6).lerp(Color(0.9, 0.9, 0.95), 0.2)
				else:
					c = hair.darkened(rng.randf_range(0.2, 0.45))
				var a := rng.randf_range(0.14, 0.32) if not streak else rng.randf_range(0.45, 0.7)
				if roll >= 0.45 and roll < 0.55 and not streak:
					a *= 0.6
				_r_polyline(pts, Color(c, a), w * (1.3 if streak else 1.0), true)
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
			for i in int((75 if not big else 60) * k):
				var p := _cap_pt(rng.randf(), rng.randf_range(0.12, 0.97))
				if _cap_alpha(p, 0.5) < 0.5:
					continue
				var r := _fw * rng.randf_range(0.04, 0.08) * (1.35 if big else 1.0)
				var a0 := rng.randf() * TAU
				var lit := hair.lightened(0.3)
				if hl_on and rng.randf() < 0.3:
					lit = Color("#D8B46A")
				_r_arc(_cl(p + Vector2(r * 0.25, r * 0.45)), r, a0 + PI, a0 + PI * 2.1, 8, Color(hair.darkened(0.45), 0.5), w * 1.3, true)
				_r_arc(_cl(p), r, a0, a0 + PI * 1.3, 8, Color(lit, 0.55), w * 1.2, true)
				if rng.randf() < 0.5:
					_r_arc(_cl(p), r * 0.55, a0 + 0.8, a0 + PI * 1.5, 6, Color(lit.lightened(0.1), 0.35), w, true)
			_outline_bumps(rng, hair, 0.075 if not big else 0.095, 26)
		"coil":
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
			for r in 9:
				var rad := _fh * (0.45 + r * 0.1)
				var run := PackedVector2Array()
				for j in 25:
					var a := lerpf(PI * 0.2, PI * 0.8, float(j) / 24.0)
					var wp := crown + Vector2(cos(a), sin(a)) * rad
					var q := _uv(wp)
					if q.y < _hairline_v(q.x) - 0.03 and _th(q.x, q.y) < 1.0:
						run.append(_cl(wp))
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


func _blob(center: Vector2, rx: float, ry: float, gloss: float, lumpy: float, seed: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var k := 1.0 + lumpy * (0.06 * sin(a * 9.0 + seed) + 0.04 * sin(a * 14.0 + seed * 2.0))
		pts.append(_cl(center + Vector2(cos(a) * rx, sin(a) * ry) * k))
	_blob_c = center
	_blob_r = maxf(rx, ry)
	_rim(_radial(center, pts, _rings(6), func(p: Vector2, t: float, _i: int) -> Color:
		return _hair_col(p, clampf(0.35 + t * 0.55, 0.0, 1.0), float(_i) / 36.0, gloss)), pts.size())
	return pts


func _front_piece(rng: RandomNumberGenerator, kind: String, hair: Color, gloss: float) -> void:
	var f := _f
	var hl: float = float(f["hairline"]) + float(_hs("hl", 0.0))
	var w := maxf(0.6, _s * 0.0036)
	match kind:
		"quiff", "pomp":
			# Volume que nasce na linha do cabelo e sobe para trás, puxado para o lado do risco
			var big := kind == "pomp"
			var sx := float(f["part_side"])
			var hh := 0.4 if big else 0.3
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
				var peak := _g(u + sx * 0.12, 0.42)
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
			var crop := kind == "crop"
			# Mechas finas e sobrepostas que afinam e ficam transparentes na ponta (dente de serra
			# de triângulos opacos parecia papel recortado)
			var locks := 17 if not crop else 21
			var top_y := hl - (0.3 if not crop else 0.18)
			for pass_i in 2:
				for i in locks:
					var t := (float(i) + 0.5 * pass_i) / (locks - 1)
					if t > 1.0:
						continue
					var u := lerpf(-0.78, 0.78, t) + rng.randf_range(-0.015, 0.015)
					var lw := 0.07 + rng.randf_range(0.0, 0.035)
					var tip_y := hl + rng.randf_range(-0.035, 0.04) + (0.0 if crop else 0.03 * sin(PI * t)) - 0.03 * pass_i
					var skew := rng.randf_range(-0.04, 0.04) + float(f["part_side"]) * 0.03
					var mid_y := lerpf(top_y, tip_y, 0.55)
					var tc := _hair_col(_px(u, top_y), 0.8, t, gloss).darkened(0.1 * (1 - pass_i))
					var poly := PackedVector2Array([_px(u - lw, top_y), _px(u - lw * 0.55 + skew * 0.5, mid_y), _px(u + skew, tip_y + 0.02),
						_px(u + lw * 0.55 + skew * 0.5, mid_y), _px(u + lw, top_y)])
					var cols := PackedColorArray([tc, Color(tc.darkened(0.1), 0.9), Color(tc.darkened(0.25), 0.15), Color(tc.darkened(0.05), 0.9), tc])
					_poly_colors(poly, cols)
					_r_line(_px(u, top_y), _px(u + skew * 0.7, lerpf(top_y, tip_y, 0.8)), Color(hair.lightened(0.22), 0.22), w * 0.8, true)
			# Sombra da franja na testa
			var sh := PackedVector2Array()
			for i in 12:
				var t := float(i) / 11.0
				sh.append(_px(lerpf(-0.7, 0.7, t), hl + 0.05 + 0.03 * sin(PI * t)))
			_r_polyline(sh, Color(0, 0, 0, 0.1), _fh * 0.05, true)
		"locks", "braid_locks":
			var ln := float(_hs("lk", 1.0))
			var braid := kind == "braid_locks"
			for sx: float in [-1.0, 1.0]:
				var inner := PackedVector2Array()
				var outer := PackedVector2Array()
				for i in 10:
					var t := float(i) / 9.0
					var v := lerpf(-0.55, -0.1 + ln, t)
					var hw := _hw(clampf(v, 0.0, 1.0)) if v > 0.0 else float(f["cheek_w"]) * sqrt(maxf(0.0, 1.0 - pow(v / 1.02, 2.0)))
					var ix := hw * lerpf(0.8, 0.95, smoothstep(0.0, 0.35, t))
					if v > 0.75:
						ix = maxf(ix, 0.62 + (v - 0.75) * 0.35)
					var thick := lerpf(0.3, 0.06, pow(t, 1.4)) * (0.8 if braid else 1.0)
					inner.append(_px(sx * ix, v))
					outer.append(_px(sx * (ix + thick + 0.06 * sin(PI * t)), v + 0.03 * t))
				_strip(inner, outer, 3, func(p: Vector2, t: float, ww: float) -> Color:
					var c := _hair_col(p, 0.55 + ww * 0.3, t, gloss)
					# Borda de fora suave (a mecha contra o fundo não fica serrilhada)
					return Color(c.darkened(0.08 * t), (1.0 - smoothstep(0.92, 1.0, t) * 0.6) * (1.0 - 0.55 * smoothstep(0.66, 1.0, ww))))
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
						_r_polyline(pts, Color(hair.lightened(0.25) if light else hair.darkened(0.35), 0.35), w, true)
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
		"side_fringe":
			var sx := float(f["part_side"])
			# Com a lateral raspada a franja não passa da têmpora (senão fica "solta" sobre a pele)
			var far := 0.72 if int(_hs("fd", 0)) == 3 else 0.9
			var lower := PackedVector2Array()
			var upper := PackedVector2Array()
			for i in 12:
				var t := float(i) / 11.0
				var u := sx * lerpf(0.55, -far, t)
				var vl := hl - 0.14 + 0.24 * t + 0.05 * sin(PI * t)
				lower.append(_px(u, vl))
				# O lado de cima sempre sobe até dentro da calota: a franja nasce do cabelo
				upper.append(_px(u * 0.98, minf(vl - lerpf(0.34, 0.14, t), _hairline_v(u) - 0.04)))
			_strip(lower, upper, 3, func(p: Vector2, t: float, ww: float) -> Color:
				return Color(_hair_col(p, 0.5 + ww * 0.45, t, gloss), smoothstep(0.0, 0.3, ww) * (1.0 - 0.8 * smoothstep(0.75, 1.0, t))))
			for j in int(14 * clampf(_det, 0.3, 1.6)):
				var ww := rng.randf_range(0.15, 0.9)
				var pts := PackedVector2Array()
				for k in 11:
					pts.append(_cl(lower[k].lerp(upper[k], ww)))
				_r_polyline(pts, Color(hair.lightened(0.18) if j % 2 == 0 else hair.darkened(0.22), 0.25), w, true)
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
			# Franja longa jogada de lado: sai do risco, atravessa a testa e termina sobre a
			# sobrancelha do outro lado, afinando nas pontas
			var sx := float(f["part_side"])
			var lower := PackedVector2Array()
			var upper := PackedVector2Array()
			var far := 0.76 if int(_hs("fd", 0)) == 3 else 0.92
			for i in 14:
				var t := float(i) / 13.0
				var u := sx * lerpf(0.5, -far, t)
				var vl := hl - 0.16 + 0.3 * pow(t, 1.15) + 0.03 * sin(PI * t)
				lower.append(_px(u, vl))
				# Presa à linha do cabelo em todo o comprimento (antes a borda de cima ficava na testa)
				upper.append(_px(u * 0.97, minf(vl - lerpf(0.3, 0.1, t), _hairline_v(u) - 0.04)))
			_strip(lower, upper, 3, func(p: Vector2, t: float, ww: float) -> Color:
				var c := _hair_col(p, 0.62 + ww * 0.35, t, gloss + 0.15)
				return Color(c, smoothstep(0.0, 0.28, ww) * (1.0 - smoothstep(0.78, 1.0, t) * 0.8)))
			for j in int(26 * clampf(_det, 0.3, 1.6)):
				var ww := rng.randf_range(0.12, 0.95)
				var pts := PackedVector2Array()
				var end := 13 - rng.randi_range(0, 3)
				for k in end:
					pts.append(_cl(lower[k].lerp(upper[k], ww)))
				var c := hair.lightened(0.2) if j % 3 == 0 else hair.darkened(0.2)
				_r_polyline(pts, Color(c, 0.26), w, true)
			var sh := PackedVector2Array()
			for k in 12:
				sh.append(lower[k] + Vector2(0, _fh * 0.025))
			_r_polyline(sh, Color(0, 0, 0, 0.1), _fh * 0.04, true)
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
			_rim(_radial(_hc + Vector2(0, _fh * 0.4), clean, _rings(6), func(p: Vector2, t: float, i: int) -> Color:
				var c := _hair_col(p, 0.6, float(i) / 60.0, gloss).darkened(0.25)
				return c.darkened(0.15 * t)), clean.size())
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
			var r := 1.5 + float(f["vol"]) * 0.2
			var cen := _px(0.0, -0.32)
			var pts := _blob(cen, _fw * r, _fw * r * 0.95, 0.0, 1.0, float(int(f["hair_seed"]) % 100))
			for i in int(300 * clampf(_det, 0.4, 1.6)):
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * _fw * r
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * rr
				_r_circle(_cl(p), maxf(0.5, _s * rng.randf_range(0.003, 0.006)), Color(hair.lightened(0.2) if rng.randf() < 0.4 else hair.darkened(0.35), rng.randf_range(0.3, 0.6)))
			for i in 48:
				var a := TAU * i / 48.0
				var p := cen + Vector2(cos(a), sin(a) * 0.95) * _fw * r * 0.98
				_r_circle(_cl(p), _fw * r * 0.07, _hair_col(p, 0.9, float(i) / 48.0, 0.0))
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
		"puff":
			# Afro puff: bola de cabelo crespo no alto, atrás
			var cen := _px(0.0, -1.18)
			var r := 0.62 + float(f["vol"]) * 0.1
			_blob(cen, _fw * r, _fw * r * 0.82, 0.0, 1.0, float(int(f["hair_seed"]) % 100))
			for i in int(220 * clampf(_det, 0.4, 1.6)):
				var a := rng.randf() * TAU
				var rr := sqrt(rng.randf()) * _fw * r
				var p := cen + Vector2(cos(a), sin(a) * 0.82) * rr
				_r_circle(_cl(p), maxf(0.5, _s * rng.randf_range(0.003, 0.0055)), Color(hair.lightened(0.2) if rng.randf() < 0.4 else hair.darkened(0.35), rng.randf_range(0.3, 0.6)))
			for i in 36:
				var a := TAU * i / 36.0
				var p := cen + Vector2(cos(a), sin(a) * 0.82) * _fw * r * 0.97
				_r_circle(_cl(p), _fw * r * 0.08, _hair_col(p, 0.9, float(i) / 36.0, 0.0))
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
