@tool
class_name KitView
extends Control
## Uniforme procedural. Por padrão desenha só a camisa; com `full` desenha camisa, calção e meiões.
## Chaves do dicionário do uniforme (todas opcionais, com padrão sensato):
##   pattern, tonal (estampa tom sobre tom), c1 (principal), c2 (secundária), c3 (detalhes: gola,
##   punhos, vivos, terceira cor das tricolores), nc (cor dos números),
##   collar, sleeve, sleeve_len (short|long), trim (vivos),
##   shorts / shorts2 / shorts_style, socks / socks2 / socks_style,
##   sp = {n, c, t} (patrocinador master no peito), sp_m (manga), sp_c (costas), sp_s (calção),
##   spc / spmc / spcc / spsc / supc = cor escolhida para cada logo (master, manga, costas, calção,
##   fornecedor); vazio = a cor da própria marca que mais contrasta com o tecido,
##   sup = {n, c, t, logo} (fornecedor de material esportivo, logo pequeno no peito).
##   sp = {n, c, t, m} (patrocinador; m = símbolo de BrandMark desenhado ao lado do nome).
## O escudo do clube vai no peito (lado do coração) quando `crest` é dado.

@export var kit: Dictionary = {"pattern": "stripes_v", "c1": "#B3122E", "c2": "#F2C14E", "collar": "round", "sleeve": "same"}:
	set(v):
		kit = v
		queue_redraw()
@export var number: int = 0:
	set(v):
		number = v
		queue_redraw()
@export var full: bool = false:
	set(v):
		full = v
		queue_redraw()
## Vista de costas: patrocinador das costas, nome e número grande.
@export var back: bool = false:
	set(v):
		back = v
		queue_redraw()
@export var back_name: String = "":
	set(v):
		back_name = v
		queue_redraw()
## Escudo do clube (formato do CrestView), bordado no peito.
@export var crest: Dictionary = {}:
	set(v):
		crest = v
		queue_redraw()

## [chave, nome] — a ordem é a do editor.
const PATTERNS: Array = [
	["plain", "Lisa"], ["stripes_v", "Listras"], ["pinstripes", "Listras finas"], ["wide_stripes", "Listras largas"],
	["center_stripe", "Listra central"], ["center_stripe_edged", "Listra central com filetes"], ["twin_stripes", "Listras gêmeas"],
	["tricolor_v", "Tricolor vertical"], ["stripes_tri", "Listras tricolores"],
	["halves", "Metades"], ["quarters", "Quartos"],
	["stripes_h", "Faixas horizontais"], ["hoops_thin", "Faixas finas"], ["hoops_pin", "Riscas"], ["hoop_fade", "Faixas em degradê"],
	["faixa", "Faixa no peito"], ["faixa_duo", "Faixa bicolor no peito"], ["double_band", "Faixa dupla"], ["band_low", "Faixa baixa"], ["tricolor_h", "Tricolor horizontal"],
	["bottom_half", "Duas cores (h)"], ["yoke", "Ombros"], ["shoulder_band", "Faixa nos ombros"],
	["diagonal", "Faixa diagonal"], ["diagonal_rev", "Diagonal invertida"], ["sash_thin", "Diagonal fina"],
	["sash_double", "Diagonal dupla"], ["diagonal_split", "Diagonal dividida"], ["chevron", "Chevron"], ["v_big", "V largo"],
	["cross", "Cruz"], ["saltire", "Aspa"],
	["checkers", "Xadrez"], ["tartan", "Xadrez escocês"], ["harlequin", "Arlequim"], ["argyle", "Losangos"], ["pixels", "Grade"],
	["triangles", "Triângulos"], ["zigzag", "Zigue-zague"], ["waves", "Ondas"], ["dots", "Bolinhas"],
	["gradient", "Degradê"], ["fade_up", "Degradê de baixo"], ["halftone", "Pontilhado"], ["brush", "Pinceladas"],
	["sunburst", "Raios"], ["side_panels", "Laterais"], ["center_panel", "Painel central"], ["shatter", "Estilhaços"],
	["camo", "Camuflado"], ["topo", "Relevo"],
]
## Grupos do editor: [nome, primeira chave, última chave] na ordem de PATTERNS.
const PATTERN_GROUPS: Array = [
	["Clássicas", "plain", "quarters"], ["Faixas", "stripes_h", "shoulder_band"],
	["Diagonais e cruzes", "diagonal", "saltire"], ["Geométricas", "checkers", "dots"], ["Modernas", "gradient", "topo"],
]
const COLLARS: Array = [["round", "Redonda"], ["ringer", "Friso duplo"], ["wide", "Careca larga"], ["v", "Em V"],
	["crossover", "V transpassado"], ["henley", "Botões"], ["laced", "Cordão"], ["polo", "Polo"], ["retro", "Colarinho retrô"],
	["mandarin", "Padre"], ["zip", "Zíper"]]
const SLEEVES: Array = [["same", "Iguais"], ["contrast", "Contraste"], ["cuff", "Punho"], ["cuff_double", "Punho duplo"],
	["tipped", "Punho listrado"], ["stripes", "Três listras"], ["shoulder_stripe", "Friso no ombro"], ["raglan", "Raglan"],
	["pattern", "Estampa na manga"]]
const SLEEVE_LENGTHS: Array = [["short", "Curta"], ["long", "Longa"]]
const TRIMS: Array = [["none", "Sem vivos"], ["sides", "Laterais"], ["shoulders", "Ombros"], ["both", "Ombros e laterais"], ["hem", "Barra"]]
const SHORTS_STYLES: Array = [["plain", "Liso"], ["side_stripe", "Faixa lateral"], ["side_panel", "Painel lateral"], ["piping", "Vivo"],
	["hem", "Barra"], ["hem_double", "Barra dupla"], ["two_tone", "Duas cores"], ["stripes3", "Três listras"], ["vent", "Fenda"]]
const SOCKS_STYLES: Array = [["plain", "Liso"], ["hoops", "Listrado"], ["top_band", "Punho"], ["top_stripes", "Punho listrado"],
	["two_tone", "Duas cores"], ["stripes3", "Frisos"], ["hoops_thin", "Duas faixas"], ["band_mid", "Faixa central"],
	["chevron", "Chevron"], ["foot", "Pé contrastante"]]
## Estampas que atravessam as mangas (faixas horizontais e ombros).
const CARRY := ["stripes_h", "hoops_thin", "hoops_pin", "hoop_fade", "faixa", "faixa_duo", "double_band", "yoke", "shoulder_band", "tricolor_h"]
## Estampas pintadas com degradê (desenho próprio; pattern_bands dá só uma aproximação).
const GRADIENTS := ["gradient", "fade_up"]

## Corpo da camisa (coordenadas unitárias; 0.25..0.75 é a frente). Formato do tronco: trapézio
## descendo do pescoço para o ombro, peito largo na axila, cintura afinando e quadril de volta,
## barra levemente curva.
const BODY := [Vector2(0.378, 0.062), Vector2(0.5, 0.072), Vector2(0.622, 0.062), Vector2(0.7, 0.087), Vector2(0.738, 0.128),
	Vector2(0.754, 0.22), Vector2(0.758, 0.31), Vector2(0.752, 0.45), Vector2(0.74, 0.62), Vector2(0.743, 0.78), Vector2(0.75, 0.93),
	Vector2(0.632, 0.948), Vector2(0.5, 0.955), Vector2(0.368, 0.948), Vector2(0.25, 0.93), Vector2(0.257, 0.78), Vector2(0.26, 0.62),
	Vector2(0.248, 0.45), Vector2(0.242, 0.31), Vector2(0.246, 0.22), Vector2(0.262, 0.128), Vector2(0.3, 0.087)]
## Índices do contorno do corpo: ombro direito (gola..cava), lateral direita..barra..lateral esquerda, ombro esquerdo.
const BODY_SHOULDER_R := [2, 3, 4, 5]
const BODY_SIDES := [5, 19]
const BODY_SHOULDER_L := [0, 21, 20, 19]
## Manga direita (de quem olha); a esquerda é o espelho. Braço caído junto ao corpo, deltoide
## arredondado no ombro e a boca da manga na metade do braço.
const SLEEVE_SHORT := [Vector2(0.695, 0.085), Vector2(0.77, 0.1), Vector2(0.822, 0.138), Vector2(0.855, 0.205), Vector2(0.874, 0.3),
	Vector2(0.888, 0.43), Vector2(0.79, 0.452), Vector2(0.772, 0.36), Vector2(0.758, 0.28), Vector2(0.75, 0.2)]
const SLEEVE_LONG := [Vector2(0.695, 0.085), Vector2(0.77, 0.1), Vector2(0.82, 0.138), Vector2(0.853, 0.21), Vector2(0.874, 0.33),
	Vector2(0.888, 0.47), Vector2(0.9, 0.6), Vector2(0.912, 0.7), Vector2(0.862, 0.716), Vector2(0.84, 0.6), Vector2(0.82, 0.47),
	Vector2(0.79, 0.37), Vector2(0.765, 0.29), Vector2(0.75, 0.2)]
## Índices da boca da manga em cada formato.
const CUFF_SHORT := [5, 6]
const CUFF_LONG := [7, 8]
## Índice da ponta do ombro (alto do deltoide) nas duas mangas.
const SLEEVE_TOP := 2
## Proporção largura/altura do uniforme completo e altura da camisa nele.
const FULL_ASPECT := 0.55
const FULL_SHIRT := 0.5

static var _knit_texture: CanvasTexture

## Recortes já feitos (em coordenadas unitárias), por estampa e peça.
static var _clip_cache: Dictionary = {}

var _crest_view: CrestView


## Número de combinações de estilo (sem contar cores).
static func style_combinations() -> int:
	return PATTERNS.size() * 2 * COLLARS.size() * SLEEVES.size() * SLEEVE_LENGTHS.size() * TRIMS.size() * SHORTS_STYLES.size() * SOCKS_STYLES.size()


static func pattern_name(key: String) -> String:
	for p in PATTERNS:
		if p[0] == key:
			return p[1]
	return key


## Chaves de estampa de um grupo do editor.
static func group_patterns(group: int) -> Array:
	var g: Array = PATTERN_GROUPS[group]
	var out: Array = []
	var on := false
	for p in PATTERNS:
		if p[0] == g[1]:
			on = true
		if on:
			out.append(p)
		if p[0] == g[2]:
			break
	return out


func _draw() -> void:
	# Camisa em imagem (pasta kits/ de um pacote): no lugar da camisa desenhada, de frente.
	var img: Texture2D = CustomAssets.texture(String(kit.get("img", ""))) if kit.has("img") and not back else null
	if img != null:
		_place_crest(Rect2())
		var box := Rect2(Vector2.ZERO, size)
		if full:
			var fh := minf(size.y, size.x / FULL_ASPECT)
			var fr := Rect2((size.x - fh * FULL_ASPECT) * 0.5, (size.y - fh) * 0.5, fh * FULL_ASPECT, fh)
			_draw_legs(fr)
			var fs := fh * FULL_SHIRT
			box = Rect2(fr.position + Vector2((fr.size.x - fs) * 0.5, 0.0), Vector2(fs, fs))
		var ts := img.get_size()
		var k := minf(box.size.x / ts.x, box.size.y / ts.y)
		var sz := ts * k
		draw_texture_rect(img, Rect2(box.position + (box.size - sz) * 0.5, sz), false)
		return
	if full:
		var h := minf(size.y, size.x / FULL_ASPECT)
		var w := h * FULL_ASPECT
		if h <= 8.0:
			_place_crest(Rect2())
			return
		var r := Rect2((size.x - w) * 0.5, (size.y - h) * 0.5, w, h)
		_draw_legs(r)
		var s := h * FULL_SHIRT
		_draw_shirt(s, r.position + Vector2((w - s) * 0.5, 0.0))
	else:
		var s := minf(size.x, size.y)
		if s <= 2.0:
			_place_crest(Rect2())
			return
		_draw_shirt(s, Vector2((size.x - s) * 0.5, (size.y - s) * 0.5))


func _col(key: String, fallback: String) -> Color:
	return Color(String(kit.get(key, fallback)))


## Cor da estampa: a secundária, ou um tom da principal quando a estampa é tom sobre tom.
static func tone_of(c: Color) -> Color:
	return c.lightened(0.16) if c.get_luminance() < 0.45 else c.darkened(0.14)


func _pattern_cols() -> Array:
	var c1 := _col("c1", "#FFFFFF")
	var c2 := _col("c2", "#000000")
	var c3 := Color(String(kit.get("c3", kit.get("c2", "#000000"))))
	if bool(kit.get("tonal", false)):
		return [tone_of(c1), tone_of(c1).lerp(c1, 0.5)]
	return [c2, c3]


func _sleeve_poly(long: bool, left: bool) -> Array:
	var pts: Array = SLEEVE_LONG if long else SLEEVE_SHORT
	if not left:
		return pts
	var out: Array = []
	for p: Vector2 in pts:
		out.append(Vector2(1.0 - p.x, p.y))
	return out


func _draw_shirt(s: float, off: Vector2) -> void:
	var c1 := _col("c1", "#FFFFFF")
	var c2 := _col("c2", "#000000")
	var c3 := Color(String(kit.get("c3", kit.get("c2", "#000000"))))
	var pc: Array = _pattern_cols()
	var pat := String(kit.get("pattern", "plain"))
	var sleeve := String(kit.get("sleeve", "same"))
	var long := String(kit.get("sleeve_len", "short")) == "long"
	var sleeve_col := c2 if sleeve == "contrast" or sleeve == "raglan" else c1
	var carry := sleeve == "pattern" or (pat in CARRY and sleeve != "contrast" and sleeve != "raglan")
	# Listras verticais descem pela manga também (como nas camisas listradas de verdade)
	var stripes_sl := pat in STRIPES_V and not (sleeve in ["contrast", "raglan"]) and not bool(kit.get("tonal", false))
	if stripes_sl:
		carry = true
	var px := 1.0 / s # um pixel em unidades da camisa
	_place_crest(Rect2())
	# Tecido, estampa, frisos e gola em coordenadas da camisa (0..1)
	draw_set_transform(off, 0.0, Vector2(s, s))
	for left in [false, true]:
		_fill(PackedVector2Array(_sleeve_poly(long, left)), sleeve_col, px)
	_fill(PackedVector2Array(BODY), c1, px)
	if pat in GRADIENTS:
		_draw_gradient(pat, 1.0, Vector2.ZERO, c1, pc[0])
	else:
		for k in 2:
			for piece: PackedVector2Array in _warped(pat, k == 1):
				_fill(piece, pc[k], px)
	if stripes_sl:
		for k in 2:
			for piece: PackedVector2Array in _sleeve_stripes(pat, long, k == 1):
				_fill(piece, pc[k], px)
				_fill(_mirror_pv(piece), pc[k], px)
	elif carry:
		var part := "sl_long" if long else "sl_short"
		for k in 2:
			for piece: PackedVector2Array in _clipped(pat, part, k == 1):
				_fill(piece, pc[k], px)
	if sleeve == "raglan":
		_draw_raglan(c2, c3, px)
	_draw_trims(sleeve, long, c1, c2, c3, sleeve_col, px)
	if back:
		_draw_back_collar(c1, c3, px)
	else:
		_draw_collar(c1, c3, px, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Marcas, escudo e número: aplicados no tecido antes da luz, que passa por cima deles.
	var show_logos := s >= 56.0
	if back:
		var fg := _number_col(c1)
		if show_logos:
			var spc: Dictionary = kit.get("sp_c", {})
			if not spc.is_empty():
				_draw_patch(Rect2(off + Vector2(0.33, 0.12) * s, Vector2(0.34, 0.075) * s), spc, _area_colors(Rect2(0.33, 0.12, 0.34, 0.075), c1), false, "spcc")
			if back_name != "":
				_draw_text_centered(back_name.to_upper(), off + Vector2(0.5, 0.28) * s, s * 0.44, int(s * 0.072), fg, &"Caps", _num_edge(fg))
		if number > 0:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.58 if back_name != "" and show_logos else 0.53) * s, s * 0.46, int(s * (0.34 if show_logos else 0.44)), fg, &"Big", _num_edge(fg))
	else:
		if s >= 40.0:
			_draw_crest(s, off, c1, c2, c3)
		var sp: Dictionary = kit.get("sp", {})
		var has_master := not sp.is_empty() and show_logos
		if show_logos:
			if has_master:
				_draw_patch(Rect2(off + Vector2(0.285, 0.34) * s, Vector2(0.43, 0.12) * s), sp, _area_colors(Rect2(0.285, 0.34, 0.43, 0.12), c1), true, "spc")
			var sup: Dictionary = kit.get("sup", {})
			if not sup.is_empty():
				# Fornecedor no peito direito do jogador (esquerda de quem olha).
				_draw_supplier(off + Vector2(0.38, 0.2) * s, s * 0.035, sup, _bg_at(Vector2(0.38, 0.2), c1), true)
			var spm: Dictionary = kit.get("sp_m", {})
			if not spm.is_empty():
				_draw_patch(Rect2(off + Vector2(0.792, 0.175) * s, Vector2(0.062, 0.042) * s), spm, [sleeve_col] + ([pc[0]] if carry else []), false, "spmc")
		if number > 0:
			var fg := _number_col(c1)
			if has_master:
				_draw_text_centered(str(number), off + Vector2(0.5, 0.64) * s, s * 0.26, int(s * 0.17), fg, &"Big", _num_edge(fg))
			else:
				_draw_text_centered(str(number), off + Vector2(0.5, 0.5) * s, s * 0.4, int(s * 0.3), fg, &"Big", _num_edge(fg))
	# Luz, sombra e dobras por cima de tudo; depois a trama e o contorno.
	draw_set_transform(off, 0.0, Vector2(s, s))
	_shade_shirt(long, c1, pc, pat, sleeve_col, carry)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_fabric(s, off, long)
	draw_set_transform(off, 0.0, Vector2(s, s))
	_outline_shirt(long, c1, sleeve_col, px)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Peça chapada com a borda suavizada (o polígono do Godot não tem antialiasing).
func _fill(poly: PackedVector2Array, col: Color, px: float) -> void:
	if poly.size() < 3:
		return
	draw_colored_polygon(poly, col)
	var edge := PackedVector2Array(poly)
	edge.append(poly[0])
	draw_polyline(edge, col, px, true)


static func _mirror_pv(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = Vector2(1.0 - poly[i].x, poly[i].y)
	return out


## Estampas de listras verticais que se repetem (continuam pela manga).
const STRIPES_V := ["stripes_v", "pinstripes", "wide_stripes", "stripes_tri"]


## Listras na manga direita: as faixas do tronco repetidas no mesmo ritmo para fora e inclinadas
## junto com a manga (a listra desce pelo braço), recortadas pela manga.
static func _sleeve_stripes(pat: String, long: bool, third: bool) -> Array:
	var key := "ss|%s|%s|%s" % [pat, long, third]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var bands: Array = pattern_bands3(pat) if third else pattern_bands(pat)
	var xs: Array = []
	for b: PackedVector2Array in bands:
		xs.append(KitGeom.bounds(b).position.x)
	xs.sort()
	var period := 0.16
	if xs.size() >= 2:
		period = (float(xs[xs.size() - 1]) - float(xs[0])) / (xs.size() - 1)
	var a := Vector2(0.785, 0.13)
	var b2 := Vector2(0.887, 0.708) if long else Vector2(0.839, 0.441)
	var d := (b2 - a).normalized()
	var phi := -atan2(d.x, d.y)
	var sl := PackedVector2Array(SLEEVE_LONG if long else SLEEVE_SHORT)
	var out: Array = []
	for b: PackedVector2Array in bands:
		for k in range(0, 4):
			var moved := PackedVector2Array()
			for q in b:
				var p := q + Vector2(k * period, 0.0)
				moved.append(a + (p - a).rotated(phi))
			for piece in Geometry2D.intersect_polygons(moved, sl):
				if piece.size() >= 3:
					out.append(piece)
	_clip_cache[key] = out
	return out


## Estampa do tronco curvada pelo corpo (KitGeom.warp_torso) e recortada pela camisa.
static func _warped(pat: String, third: bool) -> Array:
	var key := "w|%s|%s" % [pat, third]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var out: Array = []
	if pat != "plain":
		var bands: Array = pattern_bands3(pat) if third else pattern_bands(pat)
		var body := PackedVector2Array(BODY)
		for band: PackedVector2Array in bands:
			for piece in Geometry2D.intersect_polygons(KitGeom.warp_poly(band, 0.02), body):
				if piece.size() >= 3:
					out.append(piece)
	_clip_cache[key] = out
	return out


## Caminhos dos frisos (lado direito de quem olha, coordenadas da camisa). O do ombro segue o
## contorno de fora, da gola por cima do ombro até a boca da manga.
const SHOULDER_PATH_S := [Vector2(0.575, 0.063), Vector2(0.622, 0.064), Vector2(0.7, 0.089), Vector2(0.77, 0.102),
	Vector2(0.822, 0.14), Vector2(0.855, 0.207), Vector2(0.874, 0.302), Vector2(0.889, 0.432)]
const SHOULDER_PATH_L := [Vector2(0.575, 0.063), Vector2(0.622, 0.064), Vector2(0.7, 0.089), Vector2(0.77, 0.102),
	Vector2(0.82, 0.14), Vector2(0.853, 0.212), Vector2(0.874, 0.332), Vector2(0.888, 0.472), Vector2(0.9, 0.602), Vector2(0.913, 0.702)]
const SHOULDER_SEAM := [Vector2(0.615, 0.064), Vector2(0.7, 0.087), Vector2(0.738, 0.128), Vector2(0.754, 0.22), Vector2(0.758, 0.31)]
const SIDE_SEAM := [Vector2(0.758, 0.32), Vector2(0.752, 0.45), Vector2(0.74, 0.62), Vector2(0.743, 0.78), Vector2(0.75, 0.93)]
const HEM_PATH := [Vector2(0.25, 0.93), Vector2(0.368, 0.948), Vector2(0.5, 0.955), Vector2(0.632, 0.948), Vector2(0.75, 0.93)]


## Faixas de um friso no lado direito: [[polígono, cor (0 detalhe, 1 secundária, 2 tom do tecido)]].
## Cada faixa é paralela ao contorno (mesma largura nas curvas) e recortada pela peça.
static func _trim_polys(kind: String, long: bool) -> Array:
	var key := "t|%s|%s" % [kind, long]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var sl := PackedVector2Array(SLEEVE_LONG if long else SLEEVE_SHORT)
	var body := PackedVector2Array(BODY)
	var cuff: Array = CUFF_LONG if long else CUFF_SHORT
	var cuff_path := KitGeom.extend(PackedVector2Array([sl[cuff[0]], sl[cuff[1]]]), 0.03, 0.03)
	var shoulder := KitGeom.extend(KitGeom.smooth(SHOULDER_PATH_L if long else SHOULDER_PATH_S, 6), 0.03, 0.05)
	var bands: Array = []
	match kind:
		"cuff_tone":
			bands = [[KitGeom.band(cuff_path, 0.0, 0.024), 2, [sl]]]
		"cuff":
			bands = [[KitGeom.band(cuff_path, 0.0, 0.035), 0, [sl]]]
		"cuff_double":
			bands = [[KitGeom.band(cuff_path, 0.0, 0.014), 0, [sl]], [KitGeom.band(cuff_path, 0.026, 0.04), 0, [sl]]]
		"tipped":
			bands = [[KitGeom.band(cuff_path, 0.0, 0.032), 0, [sl]], [KitGeom.band(cuff_path, 0.011, 0.021), 1, [sl]]]
		"stripes":
			for i in 3:
				bands.append([KitGeom.band(shoulder, 0.012 + i * 0.019, 0.023 + i * 0.019), 0, [sl, body]])
		"shoulder_stripe":
			bands = [[KitGeom.band(shoulder, 0.013, 0.035), 0, [sl, body]]]
		"pip_shoulder":
			bands = [[KitGeom.band(KitGeom.smooth(SHOULDER_SEAM, 6), -0.005, 0.006), 0, [sl, body]]]
		"pip_side":
			bands = [[KitGeom.band(KitGeom.smooth(SIDE_SEAM, 6), 0.005, 0.016), 0, [body]]]
		"hem":
			bands = [[KitGeom.band(KitGeom.extend(KitGeom.smooth(HEM_PATH, 6), 0.03, 0.03), -0.034, -0.016), 0, [body]]]
	var out: Array = []
	for b: Array in bands:
		for piece in KitGeom.clip_all([b[0]], b[2]):
			out.append([piece, b[1]])
	_clip_cache[key] = out
	return out


func _draw_trims(sleeve: String, long: bool, c1: Color, c2: Color, c3: Color, sleeve_col: Color, px: float) -> void:
	var kinds: Array = []
	if sleeve in ["cuff", "cuff_double", "tipped"]:
		kinds.append(sleeve)
	else:
		kinds.append("cuff_tone") # punho de ribana no tom do tecido
		if sleeve in ["stripes", "shoulder_stripe"]:
			kinds.append(sleeve)
	var trim := String(kit.get("trim", "none"))
	if trim == "sides" or trim == "both":
		kinds.append("pip_side")
	if trim == "shoulders" or trim == "both":
		kinds.append("pip_shoulder")
	var alt := c2 if c2 != c3 else c1
	var tone := sleeve_col.darkened(0.08) if sleeve_col.get_luminance() > 0.12 else sleeve_col.lightened(0.07)
	for kind: String in kinds:
		for it: Array in _trim_polys(kind, long):
			var col: Color = [c3, alt, tone][int(it[1])]
			_fill(it[0], col, px)
			_fill(_mirror_pv(it[0]), col, px)
	if trim == "hem":
		for it: Array in _trim_polys("hem", long):
			_fill(it[0], c3, px)


## Raglan: a cor da manga sobe até a gola, com a costura curva.
func _draw_raglan(c2: Color, c3: Color, px: float) -> void:
	var seam := KitGeom.smooth([Vector2(0.588, 0.064), Vector2(0.645, 0.115), Vector2(0.705, 0.19), Vector2(0.742, 0.255), Vector2(0.758, 0.318)], 6)
	var region := PackedVector2Array(seam)
	for q in [Vector2(0.8, 0.318), Vector2(0.8, 0.04), Vector2(0.588, 0.04)]:
		region.append(q)
	var body := PackedVector2Array(BODY)
	var line_col := c3 if c3 != c2 else c2.darkened(0.3)
	for m in [false, true]:
		for piece in Geometry2D.intersect_polygons(_mirror_pv(region) if m else region, body):
			_fill(piece, c2, px)
		draw_polyline(_mirror_pv(seam) if m else seam, line_col, px * 1.5, true)


func _neck_path(collar: String) -> Array:
	match collar:
		"v":
			return [Vector2(0.4, 0.064), Vector2(0.5, 0.19), Vector2(0.6, 0.064)]
		"crossover":
			return [Vector2(0.4, 0.064), Vector2(0.5, 0.18), Vector2(0.6, 0.064)]
		"laced":
			return [Vector2(0.41, 0.064), Vector2(0.45, 0.1), Vector2(0.5, 0.17), Vector2(0.55, 0.1), Vector2(0.59, 0.064)]
		"retro":
			return [Vector2(0.41, 0.064), Vector2(0.5, 0.2), Vector2(0.59, 0.064)]
		"wide":
			return [Vector2(0.365, 0.062), Vector2(0.42, 0.118), Vector2(0.5, 0.135), Vector2(0.58, 0.118), Vector2(0.635, 0.062)]
		"mandarin", "zip", "polo":
			return [Vector2(0.39, 0.064), Vector2(0.44, 0.092), Vector2(0.5, 0.1), Vector2(0.56, 0.092), Vector2(0.61, 0.064)]
	return [Vector2(0.395, 0.064), Vector2(0.44, 0.1), Vector2(0.5, 0.112), Vector2(0.56, 0.1), Vector2(0.605, 0.064)]


## Gola (coordenadas da camisa): o avesso das costas no decote, a ribana da nuca vista por dentro e
## a ribana da frente como uma faixa contínua que segue o decote, com as nervuras do tecido.
func _draw_collar(c1: Color, c3: Color, px: float, s: float) -> void:
	var collar: String = kit.get("collar", "round")
	var col := c3 if c3 != c1 else (c1.darkened(0.4) if c1.get_luminance() > 0.2 else c1.lightened(0.3))
	var pts := _neck_path(collar)
	var sharp := collar in ["v", "crossover", "retro"]
	var front := PackedVector2Array(pts) if sharp else KitGeom.smooth(pts, 8)
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var nape := KitGeom.smooth([b, Vector2(lerpf(b.x, 0.5, 0.45), 0.055), Vector2(0.5, 0.052), Vector2(lerpf(a.x, 0.5, 0.45), 0.055), a], 6)
	var w := 0.03 if collar == "wide" else 0.024
	# Avesso das costas, mais fundo embaixo do decote
	var opening := PackedVector2Array(front)
	for i in range(1, nape.size() - 1):
		opening.append(nape[i])
	var ymax := 0.06
	for q in front:
		ymax = maxf(ymax, q.y)
	var cols := PackedColorArray()
	for q in opening:
		cols.append(c1.darkened(0.36).lerp(c1.darkened(0.66), clampf((q.y - 0.05) / maxf(0.02, ymax - 0.05), 0.0, 1.0)))
	draw_polygon(opening, cols)
	# Ribana da nuca, vista por dentro (um tom abaixo)
	_fill(KitGeom.band(nape, -w * 0.75, 0.0), col.darkened(0.3), px)
	match collar:
		"mandarin", "zip":
			var stand := KitGeom.smooth([Vector2(0.39, 0.06), Vector2(0.44, 0.088), Vector2(0.5, 0.096), Vector2(0.56, 0.088), Vector2(0.61, 0.06)], 6)
			_fill(KitGeom.band(stand, -0.042, 0.004), col, px)
			draw_polyline(KitGeom.offset(stand, -0.004), col.darkened(0.2), px, true)
			if collar == "zip":
				draw_line(Vector2(0.5, 0.096), Vector2(0.5, 0.25), col.darkened(0.35), px * 2.2, true)
				draw_rect(Rect2(Vector2(0.491, 0.1), Vector2(0.018, 0.028)), Color("#C9CCD1"))
			else:
				draw_circle(Vector2(0.5, 0.09), 0.008, col.darkened(0.3))
			return
		"polo":
			_fill(KitGeom.band(front, -0.002, w * 0.7), col, px)
			draw_line(Vector2(0.5, 0.1), Vector2(0.5, 0.24), col.darkened(0.2), px * 2.0, true)
			for i in 2:
				draw_circle(Vector2(0.5, 0.18 + i * 0.04), 0.008, col.darkened(0.3))
			for m in [false, true]:
				var flap := PackedVector2Array(_mirror([Vector2(0.385, 0.056), Vector2(0.5, 0.1), Vector2(0.47, 0.165), Vector2(0.405, 0.125)], m))
				var sh := PackedVector2Array()
				for q in flap:
					sh.append(q + Vector2(0.0, 0.008))
				draw_colored_polygon(sh, Color(0, 0, 0, 0.18))
				_fill(flap, col, px)
				draw_polyline(PackedVector2Array(_mirror([Vector2(0.405, 0.125), Vector2(0.47, 0.165), Vector2(0.5, 0.1)], m)), col.darkened(0.3), px, true)
			return
	_fill(KitGeom.band(front, -0.002, w), col, px)
	if s >= 150.0:
		_rib_lines(front, w, col, px)
	match collar:
		"ringer":
			_fill(KitGeom.band(front, w * 0.38, w * 0.62), c1 if col != c1 else Color.WHITE, px)
		"crossover":
			# A aba da esquerda passa por cima da direita
			var flap := KitGeom.band(PackedVector2Array([Vector2(0.4, 0.064), Vector2(0.535, 0.205)]), -w * 0.5, w * 0.5)
			draw_colored_polygon(KitGeom.band(PackedVector2Array([Vector2(0.4, 0.07), Vector2(0.535, 0.212)]), -w * 0.5, w * 0.5), Color(0, 0, 0, 0.2))
			_fill(flap, col, px)
		"henley":
			draw_line(Vector2(0.5, 0.112), Vector2(0.5, 0.23), col, px * 2.2, true)
			for i in 3:
				draw_circle(Vector2(0.5, 0.14 + i * 0.035), 0.008, col.darkened(0.2))
		"laced":
			var lace := PackedVector2Array()
			for i in 5:
				var y := 0.08 + i * 0.018
				var hw := 0.035 * (1.0 - (y - 0.064) / 0.11)
				lace.append(Vector2(0.5 + (hw if i % 2 == 0 else -hw), y))
			draw_polyline(lace, col.lightened(0.2), px * 1.6, true)
		"retro":
			# Gola esporte dobrada: lapelas estreitas que se encontram no V, a dobra marcada e a
			# sombra delas no peito.
			for m in [false, true]:
				draw_colored_polygon(PackedVector2Array(_mirror([Vector2(0.395, 0.074), Vector2(0.5, 0.215), Vector2(0.462, 0.224), Vector2(0.4, 0.132), Vector2(0.385, 0.09)], m)), Color(0, 0, 0, 0.18))
				_fill(PackedVector2Array(_mirror([Vector2(0.378, 0.058), Vector2(0.41, 0.064), Vector2(0.5, 0.2), Vector2(0.462, 0.21), Vector2(0.395, 0.118), Vector2(0.38, 0.084)], m)), col, px)
				draw_polyline(PackedVector2Array(_mirror([Vector2(0.38, 0.084), Vector2(0.395, 0.118), Vector2(0.462, 0.21), Vector2(0.5, 0.2)], m)), col.darkened(0.3), px, true)
				draw_polyline(PackedVector2Array(_mirror([Vector2(0.41, 0.064), Vector2(0.5, 0.2)], m)), col.lightened(0.12), px * 0.8, true)


## Nervuras da ribana: tracinhos atravessando a faixa da gola.
func _rib_lines(path: PackedVector2Array, w: float, col: Color, px: float) -> void:
	var inner := KitGeom.offset(path, w * 0.12)
	var outer := KitGeom.offset(path, w * 0.88)
	var rib := Color(col.darkened(0.18), 0.55) if col.get_luminance() > 0.2 else Color(col.lightened(0.18), 0.4)
	var acc := 0.0
	for i in range(1, path.size()):
		acc += path[i].distance_to(path[i - 1])
		if acc >= 0.0065:
			acc = 0.0
			draw_line(inner[i], outer[i], rib, px * 0.8, true)


## Costas: a gola alta por trás.
func _draw_back_collar(c1: Color, c3: Color, px: float) -> void:
	var col := c3 if c3 != c1 else c1.darkened(0.4)
	var path := KitGeom.smooth([Vector2(0.385, 0.06), Vector2(0.44, 0.074), Vector2(0.5, 0.079), Vector2(0.56, 0.074), Vector2(0.615, 0.06)], 6)
	_fill(KitGeom.band(path, -0.004, 0.024), col, px)


## Dobras do tronco (lado direito; o esquerdo é o espelho): [caminho, largura, intensidade].
const TORSO_FOLDS := [
	# O braço puxa o tecido da axila para o peito
	[[Vector2(0.754, 0.322), Vector2(0.716, 0.352), Vector2(0.662, 0.372), Vector2(0.62, 0.378)], 0.02, 0.3],
	[[Vector2(0.758, 0.38), Vector2(0.728, 0.425), Vector2(0.692, 0.478)], 0.018, 0.2],
	# Cintura: o tecido junta dos lados
	[[Vector2(0.738, 0.585), Vector2(0.702, 0.616), Vector2(0.652, 0.64)], 0.02, 0.2],
	[[Vector2(0.742, 0.7), Vector2(0.708, 0.722), Vector2(0.662, 0.733)], 0.018, 0.15],
]
## Dobras do meio (sem espelho): barra e barriga.
const TORSO_FOLDS_C := [
	[[Vector2(0.34, 0.855), Vector2(0.347, 0.9), Vector2(0.355, 0.95)], 0.014, 0.14],
	[[Vector2(0.632, 0.865), Vector2(0.627, 0.905), Vector2(0.621, 0.95)], 0.012, 0.12],
	[[Vector2(0.425, 0.765), Vector2(0.5, 0.778), Vector2(0.58, 0.768)], 0.03, 0.07],
]
## Dobras da manga direita (curta e longa).
const SLEEVE_FOLDS_S := [
	[[Vector2(0.775, 0.27), Vector2(0.805, 0.3), Vector2(0.842, 0.318)], 0.014, 0.22],
	[[Vector2(0.78, 0.36), Vector2(0.812, 0.375), Vector2(0.85, 0.372)], 0.012, 0.15],
]
const SLEEVE_FOLDS_L := [
	[[Vector2(0.775, 0.27), Vector2(0.805, 0.3), Vector2(0.84, 0.31)], 0.014, 0.2],
	[[Vector2(0.83, 0.48), Vector2(0.86, 0.495), Vector2(0.888, 0.49)], 0.012, 0.18],
	[[Vector2(0.842, 0.56), Vector2(0.872, 0.57), Vector2(0.898, 0.565)], 0.01, 0.12],
]

static var _shade_prm: Dictionary = {}


## Meia largura do tronco por altura (0..1 em 101 passos) e as dobras, para a luz do tronco.
static func _torso_prm() -> Dictionary:
	if _shade_prm.has("torso"):
		return _shade_prm["torso"]
	var hw: Array = []
	var body := PackedVector2Array(BODY)
	var last := 0.2
	for i in 101:
		var y := i / 100.0
		var lo := INF
		var hi := -INF
		for k in body.size():
			var p := body[k]
			var q := body[(k + 1) % body.size()]
			if p.y != q.y and (p.y - y) * (q.y - y) <= 0.0:
				var x := lerpf(p.x, q.x, (y - p.y) / (q.y - p.y))
				lo = minf(lo, x)
				hi = maxf(hi, x)
		if hi > lo:
			last = (hi - lo) * 0.5
		hw.append(last)
	var prm := {"hw": hw, "folds": KitShade.folds(TORSO_FOLDS, true) + KitShade.folds(TORSO_FOLDS_C),
		"pits": [Vector2(0.758, 0.3), Vector2(0.242, 0.3)]}
	_shade_prm["torso"] = prm
	return prm


static func _mirror_defs(defs: Array) -> Array:
	var out: Array = []
	for f: Array in defs:
		var pts: Array = []
		for q: Vector2 in f[0]:
			pts.append(Vector2(1.0 - q.x, q.y))
		out.append([pts, f[1], -float(f[2])])
	return out


## Manga como cilindro do alto do ombro até a boca, com o lado do corpo na sombra.
static func _sleeve_prm(long: bool, left: bool) -> Dictionary:
	var key := "sl%s%s" % [long, left]
	if _shade_prm.has(key):
		return _shade_prm[key]
	var a := Vector2(0.785, 0.13)
	var b := Vector2(0.887, 0.708) if long else Vector2(0.839, 0.441)
	var defs: Array = SLEEVE_FOLDS_L if long else SLEEVE_FOLDS_S
	var prm := {"a": a, "b": b, "ha": 0.068, "hb": 0.026 if long else 0.05, "cap": 0.2, "cap0": 0.07, "inner": 1.0}
	if left:
		prm["a"] = Vector2(1.0 - a.x, a.y)
		prm["b"] = Vector2(1.0 - b.x, b.y)
		prm["inner"] = -1.0
		prm["folds"] = KitShade.folds(_mirror_defs(defs))
	else:
		prm["folds"] = KitShade.folds(defs)
	_shade_prm[key] = prm
	return prm


## A parte da manga que aparece (o corpo cobre a cava).
static func _sleeve_visible(long: bool, left: bool) -> Array:
	var key := "vis%s%s" % [long, left]
	if _shade_prm.has(key):
		return _shade_prm[key]
	var sl := PackedVector2Array(SLEEVE_LONG if long else SLEEVE_SHORT)
	if left:
		sl = _mirror_pv(sl)
	var best := sl
	var area := -1.0
	for piece in Geometry2D.clip_polygons(sl, PackedVector2Array(BODY)):
		var bb := KitGeom.bounds(piece)
		if bb.get_area() > area:
			area = bb.get_area()
			best = piece
	var out := Array(best)
	_shade_prm[key] = out
	return out


func _shade_shirt(long: bool, c1: Color, pc: Array, pat: String, sleeve_col: Color, carry: bool) -> void:
	var lum := c1.get_luminance()
	var patterned := pat != "plain" and not bool(kit.get("tonal", false))
	if patterned:
		lum = lerpf(lum, (pc[0] as Color).get_luminance(), 0.4)
	var slum := sleeve_col.get_luminance()
	if carry and patterned:
		slum = lerpf(slum, (pc[0] as Color).get_luminance(), 0.4)
	var cls := KitShade.lum_class(Color(lum, lum, lum))
	var scls := KitShade.lum_class(Color(slum, slum, slum))
	for left in [false, true]:
		var key := "sl|%s|%s" % ["l" if long else "s", "e" if left else "d"]
		KitShade.draw(self, KitShade.layers(key, _sleeve_visible(long, left), "sleeve", _sleeve_prm(long, left), scls, 0.014))
	KitShade.draw(self, KitShade.layers("torso", BODY, "torso", _torso_prm(), cls, 0.018))


## Cor do contorno da peça: o próprio tecido mais escuro (ou mais claro no tecido muito escuro).
static func _edge_col(c: Color) -> Color:
	if c.get_luminance() < 0.12:
		return Color(c.lightened(0.32), 0.7)
	return Color(c.darkened(0.58), 0.85)


func _outline_shirt(long: bool, c1: Color, sleeve_col: Color, px: float) -> void:
	var w := px * 1.3
	for left in [false, true]:
		var sl: Array = _sleeve_poly(long, left)
		var outer := PackedVector2Array()
		for i in range(1, sl.size() - 1):
			outer.append(sl[i])
		draw_polyline(outer, _edge_col(sleeve_col), w, true)
		# Costura da cava
		var seam := PackedVector2Array(_mirror(SHOULDER_SEAM.slice(1), left))
		draw_polyline(seam, Color(0, 0, 0, 0.16) if sleeve_col.get_luminance() > 0.15 else Color(1, 1, 1, 0.1), px, true)
	var pts := PackedVector2Array()
	for i in range(BODY_SIDES[0], BODY_SIDES[1] + 1):
		pts.append(BODY[i])
	draw_polyline(pts, _edge_col(c1), w, true)
	for idx: Array in [BODY_SHOULDER_R, BODY_SHOULDER_L]:
		var sh := PackedVector2Array()
		for i: int in idx:
			sh.append(BODY[i])
		draw_polyline(sh, Color(_edge_col(c1), 0.5), w, true)


## Cor por baixo de um ponto do peito (para o logo contrastar com a estampa).
func _bg_at(p: Vector2, c1: Color) -> Color:
	var pat := String(kit.get("pattern", "plain"))
	if pat == "plain" or bool(kit.get("tonal", false)) or pat in GRADIENTS:
		return c1
	for piece: PackedVector2Array in _warped(pat, false):
		if Geometry2D.is_point_in_polygon(p, piece):
			return _pattern_cols()[0]
	return c1


func _number_col(c1: Color) -> Color:
	if kit.has("nc") and String(kit["nc"]) != "":
		return Color(String(kit["nc"]))
	var pat := String(kit.get("pattern", "plain"))
	if pat == "plain" or bool(kit.get("tonal", false)):
		return UIColors.on_color(c1)
	# Camisa estampada: a cor que mais contrasta com as duas.
	var c2 := _pattern_cols()[0] as Color
	var avg := (c1.get_luminance() + c2.get_luminance()) * 0.5
	return Color.WHITE if avg < 0.55 else Color("#111111")


## Em camisa listrada/estampada o número ganha contorno, como nas camisas de verdade.
func _num_edge(fg: Color) -> Color:
	var pat := String(kit.get("pattern", "plain"))
	if pat == "plain" or bool(kit.get("tonal", false)):
		return Color(0, 0, 0, 0)
	return Color(0, 0, 0, 0.8) if fg.get_luminance() > 0.5 else Color(1, 1, 1, 0.9)


## Malha de poliéster fosco, compartilhada por todas as camisas. Some nas
## miniaturas e usa mipmaps para não cintilar quando a peça muda de tamanho.
static func _knit() -> CanvasTexture:
	if _knit_texture == null:
		var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var stitch := (x + (2 if y % 8 >= 4 else 0)) % 4
				var grain := float((x * 17 + y * 29) % 11) / 11.0
				var light := stitch == 1 or (stitch == 2 and y % 4 >= 2)
				image.set_pixel(x, y, Color(1, 1, 1, 0.035 + grain * 0.025) if light else Color(0, 0, 0, 0.025 + grain * 0.02))
		image.generate_mipmaps()
		_knit_texture = CanvasTexture.new()
		_knit_texture.diffuse_texture = ImageTexture.create_from_image(image)
		_knit_texture.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		_knit_texture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _knit_texture


func _draw_fabric(s: float, off: Vector2, long: bool) -> void:
	if s < 140.0:
		return
	var texture := _knit()
	for piece: Array in [BODY, _sleeve_poly(long, false), _sleeve_poly(long, true)]:
		var uv := PackedVector2Array()
		for p: Vector2 in piece:
			uv.append(p * 8.0)
		draw_polygon(_xf(piece, s, off), PackedColorArray([Color.WHITE]), uv, texture)
	# Costura de união das mangas, no mesmo tom do tecido.
	for side in [false, true]:
		var seam := _mirror([Vector2(0.7, 0.09), Vector2(0.738, 0.13), Vector2(0.753, 0.22), Vector2(0.757, 0.305)], side)
		draw_polyline(_xf(seam, s, off), Color(0, 0, 0, 0.12), maxf(0.5, s * 0.002), true)


## Degradê vertical do corpo (e das mangas), da cor principal para a da estampa.
func _draw_gradient(pat: String, s: float, off: Vector2, c1: Color, c2: Color) -> void:
	var y0 := 0.25 if pat == "gradient" else 0.55
	var y1 := 0.95
	for piece in _clipped("_hstrips", "body", false):
		var cols := PackedColorArray()
		for p: Vector2 in piece:
			cols.append(c1.lerp(c2, smoothstep(y0, y1, p.y)))
		draw_polygon(_xf(piece, s, off), cols)


func _mirror(pts: Array, do_it: bool) -> Array:
	if not do_it:
		return pts
	var out: Array = []
	for p: Vector2 in pts:
		out.append(Vector2(1.0 - p.x, p.y))
	return out


## Faixa ao longo da boca da manga: de `from` a `from + w` para dentro.
func _band(a: Vector2, b: Vector2, inward: Vector2, from: float, w: float, s: float, off: Vector2, col: Color) -> void:
	var p := [a + inward * from, b + inward * from, b + inward * (from + w), a + inward * (from + w)]
	draw_colored_polygon(_xf(p, s, off), col)


## Pedaços da estampa (ou das camadas de sombra) recortados pela peça, em coordenadas unitárias.
## `third`: as faixas da terceira cor (c3) das tricolores.
func _clipped(pat: String, part: String, third: bool) -> Array:
	var key := "%s|%s|%s" % [pat, part, third]
	if _clip_cache.has(key):
		return _clip_cache[key]
	var bands: Array
	match pat:
		"_shade":
			bands = []
			for i in 14:
				bands.append(_rect(0.24 + i * 0.037, 0.0, 0.037, 1.0))
		"_hstrips":
			bands = []
			for i in 16:
				bands.append(_rect(0.0, 0.04 + i * 0.058, 1.0, 0.058))
		"_shine":
			bands = []
			for iy in 5:
				for ix in 6:
					bands.append(_rect(0.26 + ix * 0.06, 0.07 + iy * 0.07, 0.06, 0.07))
		_:
			bands = pattern_bands3(pat) if third else pattern_bands(pat)
	var shapes: Array = []
	match part:
		"body":
			shapes = [PackedVector2Array(BODY)]
		"sl_short":
			shapes = [PackedVector2Array(SLEEVE_SHORT), _mirror_packed(SLEEVE_SHORT)]
		"sl_long":
			shapes = [PackedVector2Array(SLEEVE_LONG), _mirror_packed(SLEEVE_LONG)]
	var out: Array = []
	for shape: PackedVector2Array in shapes:
		var bb := _bounds(shape)
		for band: PackedVector2Array in bands:
			var b2 := _bounds(band)
			if not bb.intersects(b2):
				continue
			if _all_inside(band, shape):
				out.append(band)
				continue
			for piece in Geometry2D.intersect_polygons(band, shape):
				if piece.size() >= 3:
					out.append(piece)
	_clip_cache[key] = out
	return out


static func _mirror_packed(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(1.0 - p.x, p.y))
	return out


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


static func _all_inside(poly: PackedVector2Array, shape: PackedVector2Array) -> bool:
	for p in poly:
		if not Geometry2D.is_point_in_polygon(p, shape):
			return false
	return true


func _draw_crest(s: float, off: Vector2, c1: Color, c2: Color, c3: Color) -> void:
	var cc := Vector2(0.62, 0.205)
	var cs := 0.09
	if not crest.is_empty():
		_embroider_crest(Rect2(off + (cc - Vector2(cs, cs) * 0.5) * s, Vector2(cs, cs) * s))
		return
	var bg := _bg_at(cc, c1)
	var edge := c2 if absf(c2.get_luminance() - bg.get_luminance()) > 0.2 else (c3 if absf(c3.get_luminance() - bg.get_luminance()) > 0.2 else UIColors.on_color(bg))
	var r := cs * 0.42
	var sh := [cc + Vector2(-r, -r), cc + Vector2(r, -r), cc + Vector2(r, r * 0.3), cc + Vector2(0, r * 1.25), cc + Vector2(-r, r * 0.3)]
	draw_colored_polygon(_xf(sh, s, off), edge)
	var inner: Array = []
	for p: Vector2 in sh:
		inner.append(cc + (p - cc) * 0.7)
	draw_colored_polygon(_xf(inner, s, off), bg.lerp(edge, 0.25))


func _place_crest(r: Rect2) -> void:
	if r.size.x < 4.0 or crest.is_empty():
		if _crest_view != null:
			_crest_view.visible = false
		return
	if _crest_view == null:
		_crest_view = CrestView.new()
		_crest_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_crest_view, false, Node.INTERNAL_MODE_FRONT)
	_crest_view.visible = true
	if _crest_view.crest != crest:
		_crest_view.crest = crest
	if _crest_view.position != r.position or _crest_view.size != r.size:
		_crest_view.position = r.position
		_crest_view.size = r.size


## Escudo bordado no tecido: o desenho do escudo (DecalCache) com a borda de ponto cheio em volta
## e a sombra do relevo embaixo. Fica por baixo da luz e da trama da peça, que passam por cima.
func _embroider_crest(r: Rect2) -> void:
	if r.size.x < 4.0 or crest.is_empty():
		return
	var tex := DecalCache.crest_texture(crest, self)
	if tex == null or not DecalCache.is_ready(tex):
		return # no próximo quadro o escudo está pronto e a peça se redesenha
	var k := maxf(0.6, r.size.x * 0.035)
	draw_texture_rect(tex, Rect2(r.position + Vector2(0.0, k * 1.4), r.size), false, Color(0, 0, 0, 0.32))
	draw_texture_rect(tex, r.grow(k), false, Color(0, 0, 0, 0.2))
	draw_texture_rect(tex, r, false)
	# Luz rasante no alto do bordado e a linha um pouco mais escura embaixo
	draw_texture_rect(tex, Rect2(r.position + Vector2(0.0, -k * 0.5), r.size), false, Color(1, 1, 1, 0.08))


## Patrocinador estampado no tecido: sem caixa, na cor da marca que contrasta com o fundo.
## O master ganha um pequeno emblema da marca ao lado do nome.
func _draw_patch(r: Rect2, sp: Dictionary, bgs: Array, _emblem: bool = false, ov_key: String = "") -> void:
	# Logo completo da marca (BrandLogo), aplicado como nos uniformes de verdade: na cor do próprio
	# uniforme que aparece sobre tudo o que passa por baixo; sem cor que sirva (listras de tons
	# opostos), numa placa no tom do uniforme.
	var ctx := _context_ink(sp, bgs)
	var ink: Color = ctx["ink"]
	var ink2: Color = ctx["ink2"]
	if ov_key != "" and String(kit.get(ov_key, "")) != "":
		ink = Color(String(kit[ov_key])) # cor escolhida no editor de uniforme
		ink2 = ink
	var plate: Color = ctx["plate"]
	if plate.a > 0.0:
		var pr := r.grow_individual(r.size.y * 0.12, r.size.y * 0.06, r.size.y * 0.12, r.size.y * 0.06)
		var sb := StyleBoxFlat.new()
		sb.bg_color = plate
		sb.set_corner_radius_all(int(r.size.y * 0.12))
		sb.anti_aliasing = true
		draw_style_box(sb, pr)
	var outline := Color.TRANSPARENT
	if plate.a <= 0.0 and float(ctx["min"]) < 4.5 and bgs.size() > 1:
		outline = Color("#17191D") if ink.get_luminance() > 0.45 else Color("#F5F3EE")
	BrandLogo.draw(self, sp, r, ink, ink2, {"emb": true, "outline": outline})


## Cores do tecido por baixo de um retângulo da camisa (coordenadas da camisa): o fundo e as
## faixas da estampa que passam por ele.
func _area_colors(area: Rect2, c1: Color) -> Array:
	var out: Array = [c1]
	var pat := String(kit.get("pattern", "plain"))
	if pat == "plain" or bool(kit.get("tonal", false)) or pat in GRADIENTS:
		return out
	var poly := PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])
	var pc := _pattern_cols()
	for k in 2:
		for piece: PackedVector2Array in _warped(pat, k == 1):
			if KitGeom.bounds(piece).intersects(area) and not Geometry2D.intersect_polygons(piece, poly).is_empty():
				out.append(pc[k])
				break
	return out


## Contraste (WCAG) entre duas cores: 1 (igual) a 21 (preto e branco).
static func _contrast(a: Color, b: Color) -> float:
	var la := a.get_luminance()
	var lb := b.get_luminance()
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Tinta de um logo sobre as cores `bgs`: a primeira da paleta do uniforme (secundária, detalhe,
## branco, preto) e só depois as da marca, que apareça bem sobre todas elas. {ink, ink2, plate, min}.
func _context_ink(sp: Dictionary, bgs: Array) -> Dictionary:
	var c1 := _col("c1", "#FFFFFF")
	var c2 := _col("c2", "#000000")
	var c3 := Color(String(kit.get("c3", kit.get("c2", "#000000"))))
	var cands: Array = []
	for c: Color in [c2, c3, Color.WHITE, Color("#111111"), Color(String(sp.get("t", "#FFFFFF"))), Color(String(sp.get("c", "#111111")))]:
		var dup := false
		for q: Color in cands:
			if q.is_equal_approx(c):
				dup = true
		if not dup:
			cands.append(c)
	var best := Color.WHITE
	var best_m := 0.0
	var ok: Array = []
	for c: Color in cands:
		var m := 99.0
		for b: Color in bgs:
			m = minf(m, _contrast(c, b))
		if m >= 3.0:
			ok.append(c)
		if m > best_m:
			best_m = m
			best = c
	if not ok.is_empty():
		return {"ink": ok[0], "ink2": ok[1] if ok.size() > 1 else ok[0], "plate": Color(0, 0, 0, 0), "min": best_m}
	# Nenhuma tinta serve sobre todas as cores: placa no tom de base do uniforme
	var plate := c1
	var ink := best
	var im := 0.0
	for c: Color in cands:
		var m2 := _contrast(c, plate)
		if m2 > im and not c.is_equal_approx(plate):
			im = m2
			ink = c
	return {"ink": ink, "ink2": ink, "plate": plate, "min": im}


## Sombra do relevo de um bordado sobre o tecido `bg`: mais forte no claro, quase nada no escuro.
static func _relief(bg: Color) -> Color:
	return Color(0, 0, 0, 0.3 if bg.get_luminance() > 0.35 else 0.42)


## Cor de "tinta" da marca que aparece sobre o tecido.
static func _ink(sp: Dictionary, bg: Color) -> Color:
	for key in ["t", "c"]:
		var c := Color(String(sp.get(key, "#FFFFFF")))
		if absf(c.get_luminance() - bg.get_luminance()) > 0.35:
			return c
	return UIColors.on_color(bg)


## Logo da fornecedora (formas simples de BrandMark, sem marcas reais).
func _draw_supplier(c: Vector2, u: float, sp: Dictionary, bg: Color, emb: bool = false) -> void:
	# Fornecedora na cor do uniforme (detalhe, secundária, branco ou preto), não na da marca
	var col: Color = _context_ink(sp, [bg])["ink"]
	if String(kit.get("supc", "")) != "":
		col = Color(String(kit["supc"]))
	if emb:
		BrandMark.draw_brand(self, sp, c + Vector2(0.0, maxf(0.6, u * 0.12)), u, _relief(bg))
	BrandMark.draw_brand(self, sp, c, u, col)


## Texto centrado em `center`, encolhido até caber em `max_w`.
func _draw_text_centered(txt: String, center: Vector2, max_w: float, size_px: int, color: Color, variation: StringName, outline: Color = Color(0, 0, 0, 0), emb: bool = false) -> bool:
	var font := get_theme_font(&"font", variation)
	var fs := maxi(4, size_px)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var min_fs := 6
	while tw > max_w and fs > min_fs:
		fs -= 1
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > max_w or fs < 5:
		return false
	var asc := font.get_ascent(fs)
	var desc := font.get_descent(fs)
	var at := Vector2(center.x - tw * 0.5, center.y + (asc - desc) * 0.5)
	if emb:
		# Bordado: a linha fica em relevo e faz sombra no tecido logo abaixo.
		var lift := Vector2(0.0, maxf(0.6, fs * 0.07))
		var shade := Color(0, 0, 0, 0.32 if color.get_luminance() > 0.5 else 0.22)
		if outline.a > 0.0:
			draw_string_outline(font, at + lift, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, fs / 10), shade)
		draw_string(font, at + lift, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, shade)
	if outline.a > 0.0:
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, fs / 10), outline)
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	if emb and fs >= 14:
		# Brilho do fio no alto das letras
		draw_string(font, at - Vector2(0.0, maxf(0.5, fs * 0.03)), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.07))
		draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, 0.85))
	return true


## Calção (perna esquerda de quem olha; a direita é o espelho), em coordenadas do uniforme completo
## (x na largura, y na altura). Cintura sob a camisa, quadril, lateral descendo até a barra (mais
## baixa por fora) e o gancho no meio.
const SHORTS_L := [Vector2(0.3, 0.44), Vector2(0.288, 0.48), Vector2(0.27, 0.535), Vector2(0.254, 0.59), Vector2(0.24, 0.64),
	Vector2(0.234, 0.664), Vector2(0.29, 0.673), Vector2(0.36, 0.677), Vector2(0.425, 0.672), Vector2(0.475, 0.658),
	Vector2(0.488, 0.632), Vector2(0.5, 0.606)]
## Lateral (da cintura à barra) e barra do calção (de fora para dentro).
const SHORTS_SIDE := [Vector2(0.302, 0.43), Vector2(0.288, 0.48), Vector2(0.27, 0.535), Vector2(0.254, 0.59), Vector2(0.24, 0.64), Vector2(0.232, 0.672)]
const SHORTS_HEM := [Vector2(0.234, 0.664), Vector2(0.29, 0.673), Vector2(0.36, 0.677), Vector2(0.425, 0.672), Vector2(0.475, 0.658)]
## Coxa e joelho entre a barra do calção e o meião.
const LEG := [Vector2(0.255, 0.63), Vector2(0.478, 0.63), Vector2(0.47, 0.665), Vector2(0.458, 0.695), Vector2(0.452, 0.716),
	Vector2(0.3, 0.716), Vector2(0.29, 0.69), Vector2(0.272, 0.66)]
## Meião: contorno de fora e de dentro, de cima para baixo (panturrilha cheia por fora, canela reta,
## tornozelo fino).
const SOCK_OUT := [Vector2(0.298, 0.705), Vector2(0.29, 0.74), Vector2(0.283, 0.775), Vector2(0.287, 0.815), Vector2(0.3, 0.855),
	Vector2(0.312, 0.89), Vector2(0.318, 0.925)]
const SOCK_IN := [Vector2(0.453, 0.705), Vector2(0.459, 0.745), Vector2(0.461, 0.785), Vector2(0.452, 0.83), Vector2(0.434, 0.872),
	Vector2(0.42, 0.925)]
## Chuteira com o bico um pouco virado para fora: cano, peito do pé, bico e solado.
const BOOT := [Vector2(0.316, 0.913), Vector2(0.424, 0.913), Vector2(0.433, 0.94), Vector2(0.431, 0.965), Vector2(0.4, 0.976),
	Vector2(0.33, 0.979), Vector2(0.275, 0.976), Vector2(0.248, 0.97), Vector2(0.243, 0.958), Vector2(0.258, 0.946), Vector2(0.29, 0.936), Vector2(0.31, 0.926)]
const BOOT_SOLE := [Vector2(0.431, 0.962), Vector2(0.4, 0.973), Vector2(0.33, 0.976), Vector2(0.275, 0.973), Vector2(0.246, 0.966)]
const SKIN := Color("#C68E5D")
const BOOT_COL := Color("#17181B")

## Dobras do calção (perna esquerda; a direita é o espelho).
const SHORTS_FOLDS := [
	[[Vector2(0.488, 0.605), Vector2(0.466, 0.628), Vector2(0.44, 0.646)], 0.012, 0.26],
	[[Vector2(0.47, 0.57), Vector2(0.446, 0.598), Vector2(0.42, 0.614)], 0.012, 0.15],
	[[Vector2(0.262, 0.56), Vector2(0.29, 0.585), Vector2(0.322, 0.598)], 0.01, 0.14],
	[[Vector2(0.33, 0.49), Vector2(0.362, 0.505), Vector2(0.4, 0.51)], 0.01, 0.12],
]


static func _sym(pts: Array) -> Array:
	var out: Array = pts.duplicate()
	for i in range(pts.size() - 2, -1, -1):
		var p: Vector2 = pts[i]
		out.append(Vector2(1.0 - p.x, p.y))
	return out


static func _sock_poly() -> Array:
	var u: Array = SOCK_OUT.duplicate()
	for i in range(SOCK_IN.size() - 1, -1, -1):
		u.append(SOCK_IN[i])
	return u


## Faixa paralela a um caminho do uniforme completo, com a mesma largura em qualquer direção
## (trabalha em unidades da altura e volta para as coordenadas do uniforme).
static func _band_full(path: Array, d0: float, d1: float) -> PackedVector2Array:
	var pu := PackedVector2Array()
	for q: Vector2 in path:
		pu.append(Vector2(q.x * FULL_ASPECT, q.y))
	var b := KitGeom.band(KitGeom.extend(pu, 0.02, 0.02), d0, d1)
	for i in b.size():
		b[i] = Vector2(b[i].x / FULL_ASPECT, b[i].y)
	return b


## Faixa em volta do meião, do y0 ao y1: a borda curva como um anel visto um pouco de cima.
static func _sock_band(y0: float, y1: float) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 13:
		var t := i / 12.0
		var c := 2.0 * t - 1.0
		var sag := 0.006 * (1.0 - c * c)
		top.append(Vector2(lerpf(0.25, 0.49, t), y0 + sag))
		bot.append(Vector2(lerpf(0.25, 0.49, t), y1 + sag))
	bot.reverse()
	top.append_array(bot)
	return top


static func _mirror_prm(prm: Dictionary) -> Dictionary:
	var m := prm.duplicate()
	for k in ["a", "b"]:
		var v: Vector2 = prm[k]
		m[k] = Vector2(1.0 - v.x, v.y)
	m["inner"] = -float(prm.get("inner", 0.0))
	var bumps: Array = []
	for bp: Array in prm.get("bumps", []):
		var c: Vector2 = bp[0]
		bumps.append([Vector2(1.0 - c.x, c.y), bp[1], bp[2]])
	m["bumps"] = bumps
	return m


## Parâmetros de luz das peças de baixo (perna esquerda; a direita é o espelho).
static func _legs_prm(part: String, right: bool) -> Dictionary:
	var key := "lg|%s|%s" % [part, right]
	if _shade_prm.has(key):
		return _shade_prm[key]
	var prm: Dictionary
	match part:
		"shorts":
			prm = {"legs": [[Vector2(0.392, 0.47), Vector2(0.355, 0.668), 0.105, 0.122], [Vector2(0.608, 0.47), Vector2(0.645, 0.668), 0.105, 0.122]],
				"sx": FULL_ASPECT, "top": 0.478, "crotch": Vector2(0.5, 0.612), "hem_y": 0.672,
				"folds": KitShade.folds(SHORTS_FOLDS, true)}
		"thigh":
			prm = {"a": Vector2(0.367, 0.63), "b": Vector2(0.376, 0.716), "ha": 0.112, "hb": 0.078, "sx": FULL_ASPECT, "inner": -1.0,
				"bumps": [[Vector2(0.377, 0.694), Vector2(0.04, 0.016), 0.35]],
				"lines": [[0.638, 0.009, -0.75], [0.713, 0.004, -0.25]]}
		"sock":
			prm = {"a": Vector2(0.375, 0.705), "b": Vector2(0.369, 0.925), "ha": 0.082, "hb": 0.051, "sx": FULL_ASPECT, "inner": -1.0,
				"bumps": [[Vector2(0.302, 0.776), Vector2(0.034, 0.05), 0.2], [Vector2(0.379, 0.79), Vector2(0.034, 0.054), 0.18]],
				"lines": [[0.736, 0.0035, -0.55], [0.724, 0.006, 0.28], [0.708, 0.004, -0.3], [0.905, 0.012, -0.22]]}
	if right:
		prm = _mirror_prm(prm) if part != "shorts" else prm
	_shade_prm[key] = prm
	return prm


## Calção, pernas, meiões e chuteiras (modo completo). Desenhado antes da camisa, que cobre a cintura.
func _draw_legs(r: Rect2) -> void:
	var sh := Color(String(kit.get("shorts", kit.get("c2", "#111111"))))
	var sh2 := Color(String(kit.get("shorts2", kit.get("c1", "#FFFFFF"))))
	var so := Color(String(kit.get("socks", kit.get("c1", "#FFFFFF"))))
	var so2 := Color(String(kit.get("socks2", kit.get("c2", "#000000"))))
	var px := 1.0 / r.size.y
	var sock_u := _sock_poly()
	# Coxas e joelhos
	for right in [false, true]:
		var leg := PackedVector2Array(_mirror(LEG, right))
		draw_colored_polygon(_fx(r, leg), SKIN)
	draw_set_transform(r.position, 0.0, r.size)
	for right in [false, true]:
		KitShade.draw(self, KitShade.layers("thigh|%s" % right, _mirror(LEG, right), "limb", _legs_prm("thigh", right), 2, 0.012))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Meiões: tecido, faixas em volta da perna, marca na canela, luz e contorno
	var ss: String = kit.get("socks_style", "plain")
	var sb: Array = []
	match ss:
		"hoops":
			for i in 3:
				sb.append(Vector2(0.735 + i * 0.05, 0.757 + i * 0.05))
		"top_band":
			sb.append(Vector2(0.69, 0.745))
		"top_stripes":
			sb.append(Vector2(0.712, 0.722))
			sb.append(Vector2(0.728, 0.738))
		"two_tone":
			sb.append(Vector2(0.82, 0.95))
		"stripes3":
			for i in 3:
				sb.append(Vector2(0.72 + i * 0.016, 0.728 + i * 0.016))
		"hoops_thin":
			sb.append(Vector2(0.77, 0.782))
			sb.append(Vector2(0.79, 0.802))
		"band_mid":
			sb.append(Vector2(0.77, 0.815))
		"foot":
			sb.append(Vector2(0.88, 0.95))
	var sock_cls := KitShade.lum_class(so)
	for right in [false, true]:
		var sock := PackedVector2Array(_mirror(sock_u, right))
		draw_colored_polygon(_fx(r, sock), so)
		for yy: Vector2 in sb:
			var bnd := _sock_band(yy.x, yy.y)
			for piece in Geometry2D.intersect_polygons(_mirror_pv(bnd) if right else bnd, sock):
				draw_colored_polygon(_fx(r, piece), so2)
		if ss == "chevron":
			var cv := PackedVector2Array(_mirror([Vector2(0.272, 0.73), Vector2(0.372, 0.765), Vector2(0.472, 0.73), Vector2(0.472, 0.75), Vector2(0.372, 0.785), Vector2(0.272, 0.75)], right))
			for piece in Geometry2D.intersect_polygons(cv, sock):
				draw_colored_polygon(_fx(r, piece), so2)
		var sup2: Dictionary = kit.get("sup", {})
		if not sup2.is_empty() and r.size.y >= 160.0:
			var lp := Vector2(0.372, 0.795)
			var lbg := so
			for yy: Vector2 in sb:
				if lp.y >= yy.x - 0.008 and lp.y <= yy.y + 0.008:
					lbg = so2
			if ss == "chevron" and lp.y > 0.725 and lp.y < 0.79:
				lbg = so2
			_draw_supplier(_fx(r, _mirror([lp], right))[0], r.size.y * 0.0085, sup2, lbg)
		draw_set_transform(r.position, 0.0, r.size)
		KitShade.draw(self, KitShade.layers("sock|%s" % right, _mirror(sock_u, right), "limb", _legs_prm("sock", right), sock_cls, 0.01))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sk := _fx(r, sock)
		sk.append(sk[0])
		draw_polyline(sk, _edge_col(so), maxf(1.0, r.size.y * 0.004), true)
		_draw_boot(r, right)
	# Calção (a camisa cobre a cintura)
	var shorts_u := PackedVector2Array(_sym(SHORTS_L))
	var shorts := _fx(r, shorts_u)
	draw_colored_polygon(shorts, sh)
	var st: String = kit.get("shorts_style", "plain")
	var bands: Array = _shorts_bands(st)
	for b: Array in bands:
		for right in [false, true]:
			if st == "two_tone" and right:
				continue
			var bp: PackedVector2Array = _mirror_pv(b[0]) if right else b[0]
			for piece in Geometry2D.intersect_polygons(bp, shorts_u):
				var pp := _fx(r, piece)
				var col: Color = sh2 if int(b[1]) == 1 else SKIN.darkened(0.25)
				draw_colored_polygon(pp, col)
				pp.append(pp[0])
				draw_polyline(pp, col, 1.0, true)
	# Como no calção de jogo: escudo bordado numa perna, marca da fornecedora e número na outra,
	# patrocínio embaixo. Antes da luz e das dobras, que passam por cima.
	if r.size.y >= 120.0 and not back:
		var sps: Dictionary = kit.get("sp_s", {})
		if not sps.is_empty():
			_draw_patch(_fr(r, 0.56, 0.585, 0.18, 0.045), sps, [sh, _shorts_bg(Vector2(0.65, 0.6), sh, sh2, bands)], false, "spsc")
		var ch := 0.042
		var cw := ch * r.size.y / r.size.x
		_embroider_crest(_fr(r, 0.648 - cw * 0.5, 0.532 - ch * 0.5, cw, ch))
		var bg_l := _shorts_bg(Vector2(0.36, 0.53), sh, sh2, bands)
		var sup: Dictionary = kit.get("sup", {})
		if not sup.is_empty():
			_draw_supplier(_fr(r, 0.355, 0.528, 0, 0).position, r.size.y * 0.011, sup, bg_l, true)
		if number > 0:
			var bg_n := _shorts_bg(Vector2(0.355, 0.605), sh, sh2, bands)
			var nfg := UIColors.on_color(bg_n) if not kit.has("nc") else Color(String(kit["nc"]))
			if absf(nfg.get_luminance() - bg_n.get_luminance()) < 0.3:
				nfg = UIColors.on_color(bg_n)
			_draw_text_centered(str(number), _fr(r, 0.355, 0.605, 0, 0).position, r.size.x * 0.12, int(r.size.y * 0.04), nfg, &"Big")
	draw_set_transform(r.position, 0.0, r.size)
	KitShade.draw(self, KitShade.layers("shorts", shorts_u, "shorts", _legs_prm("shorts", false), KitShade.lum_class(sh), 0.012))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var so_line := shorts.duplicate()
	so_line.append(shorts[0])
	draw_polyline(so_line, _edge_col(sh), maxf(1.0, r.size.y * 0.004), true)
	# Costura do gancho
	draw_polyline(_fx(r, [Vector2(0.5, 0.5), Vector2(0.5, 0.606)]), Color(0, 0, 0, 0.18) if sh.get_luminance() > 0.15 else Color(1, 1, 1, 0.08), maxf(1.0, r.size.y * 0.003), true)


## Faixas do estilo do calção, na perna esquerda: [[polígono, cor (1 = cor 2 do calção, 2 = fenda)]].
## As laterais seguem o contorno do quadril até a barra; as da barra seguem a barra.
static func _shorts_bands(st: String) -> Array:
	var key := "sh|" + st
	if _clip_cache.has(key):
		return _clip_cache[key]
	var out: Array = []
	match st:
		"side_stripe":
			out = [[_band_full(SHORTS_SIDE, -0.024, -0.007), 1]]
		"side_panel":
			out = [[_band_full(SHORTS_SIDE, -0.042, 0.01), 1]]
		"piping":
			out = [[_band_full(SHORTS_SIDE, -0.012, -0.007), 1]]
		"stripes3":
			for i in 3:
				out.append([_band_full(SHORTS_SIDE, -0.01 - i * 0.009, -0.005 - i * 0.009), 1])
		"hem":
			out = [[_band_full(SHORTS_HEM, -0.024, 0.006), 1]]
		"hem_double":
			out = [[_band_full(SHORTS_HEM, -0.03, -0.021), 1], [_band_full(SHORTS_HEM, -0.013, 0.006), 1]]
		"two_tone":
			out = [[PackedVector2Array([Vector2(0.5, 0.4), Vector2(1, 0.4), Vector2(1, 0.7), Vector2(0.5, 0.7)]), 1]]
		"vent":
			out = [[_band_full(SHORTS_HEM, -0.016, 0.006), 1],
				[PackedVector2Array([Vector2(0.226, 0.668), Vector2(0.246, 0.618), Vector2(0.262, 0.672)]), 2]]
	_clip_cache[key] = out
	return out


## Cor do calção num ponto, considerando as faixas do estilo.
func _shorts_bg(p: Vector2, sh: Color, sh2: Color, bands: Array) -> Color:
	for b: Array in bands:
		if int(b[1]) != 1:
			continue
		var poly: PackedVector2Array = b[0]
		if Geometry2D.is_point_in_polygon(p, poly) or Geometry2D.is_point_in_polygon(Vector2(1.0 - p.x, p.y), poly):
			return sh2
	return sh


## Chuteira: cabedal escuro com luz no peito do pé, faixa da marca seguindo a lateral, solado claro
## com as travas e o cano por cima do meião.
func _draw_boot(r: Rect2, right: bool) -> void:
	var bt := _fx(r, _mirror(BOOT, right))
	draw_colored_polygon(bt, BOOT_COL)
	# Volume: luz no peito do pé e no bico, sombra no calcanhar
	var cols := PackedColorArray()
	for q: Vector2 in BOOT:
		var lit := clampf(1.0 - absf(q.x - 0.3) / 0.12, 0.0, 1.0) * clampf((0.975 - q.y) / 0.05, 0.0, 1.0)
		cols.append(Color(1, 1, 1, 0.16 * lit))
	draw_polygon(bt, cols)
	# Solado e travas
	var sole := _band_full(BOOT_SOLE, -0.004, 0.008)
	for piece in Geometry2D.intersect_polygons(sole, PackedVector2Array(BOOT)):
		draw_colored_polygon(_fx(r, _mirror(Array(piece), right)), Color("#D9DCE1"))
	for tx in [0.27, 0.32, 0.4]:
		draw_colored_polygon(_fx(r, _mirror([Vector2(tx, 0.976), Vector2(tx + 0.022, 0.976), Vector2(tx + 0.018, 0.987), Vector2(tx + 0.004, 0.987)], right)), Color("#9EA3AA"))
	# Faixa da marca na lateral (segue o contorno do pé)
	var stripe := _band_full([Vector2(0.425, 0.93), Vector2(0.39, 0.947), Vector2(0.34, 0.954), Vector2(0.29, 0.948), Vector2(0.262, 0.952)], -0.0035, 0.0035)
	for piece in Geometry2D.intersect_polygons(stripe, PackedVector2Array(BOOT)):
		var pp := _fx(r, _mirror(Array(piece), right))
		draw_colored_polygon(pp, Color(1, 1, 1, 0.85))
	# Cano (o meião entra na chuteira) e brilho no bico
	draw_polyline(_fx(r, _mirror([Vector2(0.318, 0.916), Vector2(0.37, 0.921), Vector2(0.422, 0.916)], right)), Color(1, 1, 1, 0.18), maxf(1.0, r.size.y * 0.004), true)
	draw_polygon(_fx(r, _mirror([Vector2(0.262, 0.95), Vector2(0.29, 0.942), Vector2(0.282, 0.956), Vector2(0.258, 0.962)], right)),
		PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.0)]))
	var e := bt.duplicate()
	e.append(bt[0])
	draw_polyline(e, Color(0, 0, 0, 0.6), maxf(1.0, r.size.y * 0.003), true)


## Faixas do padrão em coordenadas unitárias (serão recortadas pelo corpo da camisa).
static func pattern_bands(pattern: String) -> Array:
	var out: Array = []
	match pattern:
		"stripes_v":
			for i in 3:
				var x := 0.3 + i * 0.16
				out.append(_rect(x, 0, 0.08, 1))
		"pinstripes":
			for i in 8:
				out.append(_rect(0.25 + i * 0.07, 0, 0.018, 1))
		"wide_stripes":
			out.append(_rect(0.2, 0, 0.14, 1))
			out.append(_rect(0.43, 0, 0.14, 1))
			out.append(_rect(0.66, 0, 0.14, 1))
		"center_stripe":
			out.append(_rect(0.44, 0, 0.12, 1))
		"center_stripe_edged":
			out.append(_rect(0.415, 0, 0.03, 1))
			out.append(_rect(0.555, 0, 0.03, 1))
		"stripes_tri":
			for i in 3:
				out.append(_rect(0.225 + i * 0.19, 0, 0.075, 1))
		"twin_stripes":
			out.append(_rect(0.405, 0, 0.055, 1))
			out.append(_rect(0.54, 0, 0.055, 1))
		"tricolor_v":
			out.append(_rect(0.4167, 0, 0.1667, 1))
		"stripes_h":
			for i in 4:
				out.append(_rect(0, 0.22 + i * 0.19, 1, 0.09))
		"hoops_thin":
			for i in 8:
				out.append(_rect(0, 0.18 + i * 0.1, 1, 0.035))
		"hoops_pin":
			for i in 17:
				out.append(_rect(0, 0.1 + i * 0.05, 1, 0.012))
		"hoop_fade":
			for i in 8:
				out.append(_rect(0, 0.14 + i * 0.1, 1, 0.07 - i * 0.0075))
		"faixa":
			out.append(_rect(0, 0.36, 1, 0.14))
		"faixa_duo":
			out.append(_rect(0, 0.33, 1, 0.075))
		"double_band":
			out.append(_rect(0, 0.3, 1, 0.07))
			out.append(_rect(0, 0.43, 1, 0.07))
		"band_low":
			out.append(_rect(0, 0.62, 1, 0.12))
		"tricolor_h":
			out.append(_rect(0, 0.37, 1, 0.28))
		"diagonal":
			out.append(PackedVector2Array([Vector2(0.15, 0.05), Vector2(0.33, 0.05), Vector2(0.9, 0.95), Vector2(0.72, 0.95)]))
		"diagonal_rev":
			out.append(PackedVector2Array([Vector2(0.85, 0.05), Vector2(0.67, 0.05), Vector2(0.1, 0.95), Vector2(0.28, 0.95)]))
		"sash_thin":
			out.append(PackedVector2Array([Vector2(0.2, 0.05), Vector2(0.27, 0.05), Vector2(0.86, 0.95), Vector2(0.79, 0.95)]))
		"sash_double":
			out.append(PackedVector2Array([Vector2(0.14, 0.05), Vector2(0.2, 0.05), Vector2(0.79, 0.95), Vector2(0.73, 0.95)]))
			out.append(PackedVector2Array([Vector2(0.25, 0.05), Vector2(0.31, 0.05), Vector2(0.9, 0.95), Vector2(0.84, 0.95)]))
		"diagonal_split":
			out.append(PackedVector2Array([Vector2(0.9, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.2, 1.0)]))
		"halves":
			out.append(_rect(0.5, 0, 0.5, 1))
		"bottom_half":
			out.append(_rect(0, 0.55, 1, 0.5))
		"quarters":
			out.append(_rect(0, 0, 0.5, 0.5))
			out.append(_rect(0.5, 0.5, 0.5, 0.5))
		"chevron":
			out.append(PackedVector2Array([Vector2(0.2, 0.2), Vector2(0.5, 0.42), Vector2(0.8, 0.2), Vector2(0.8, 0.32), Vector2(0.5, 0.54), Vector2(0.2, 0.32)]))
		"v_big":
			out.append(PackedVector2Array([Vector2(0.24, 0.0), Vector2(0.36, 0.0), Vector2(0.5, 0.3), Vector2(0.64, 0.0), Vector2(0.76, 0.0), Vector2(0.5, 0.48)]))
		"side_panels":
			out.append(_rect(0.2, 0.25, 0.1, 0.8))
			out.append(_rect(0.7, 0.25, 0.1, 0.8))
		"center_panel":
			out.append(_rect(0.37, 0, 0.26, 1))
		"yoke":
			out.append(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.24), Vector2(0.5, 0.3), Vector2(0, 0.24)]))
		"shoulder_band":
			out.append(_rect(0, 0.15, 1, 0.075))
		"cross":
			out.append(_rect(0.44, 0, 0.12, 1))
			out.append(_rect(0, 0.36, 1, 0.12))
		"saltire":
			out.append(PackedVector2Array([Vector2(0.18, 0.05), Vector2(0.27, 0.05), Vector2(0.82, 0.95), Vector2(0.73, 0.95)]))
			out.append(PackedVector2Array([Vector2(0.82, 0.05), Vector2(0.73, 0.05), Vector2(0.18, 0.95), Vector2(0.27, 0.95)]))
		"checkers":
			for iy in 10:
				for ix in 7:
					if (ix + iy) % 2 == 0:
						out.append(_rect(0.2 + ix * 0.086, iy * 0.1, 0.086, 0.1))
		"tartan":
			for i in 6:
				out.append(_rect(0.25 + i * 0.1, 0, 0.035, 1))
			for i in 9:
				out.append(_rect(0, 0.08 + i * 0.1, 1, 0.035))
		"harlequin":
			for j in 11:
				for i in 7:
					if (i + j) % 2 == 0:
						out.append(_diamond(Vector2(0.25 + i * 0.0833, 0.04 + j * 0.1), 0.0833, 0.1))
		"argyle":
			for j in 6:
				for i in 4:
					out.append(_diamond(Vector2(0.25 + i * 0.1667 + (0.0833 if j % 2 == 1 else 0.0), 0.08 + j * 0.18), 0.07, 0.09))
		"pixels":
			for iy in 20:
				for ix in 14:
					if (ix * 7 + iy * 3) % 5 == 0:
						out.append(_rect(0.2 + ix * 0.043, iy * 0.05, 0.043, 0.05))
		"triangles":
			for j in 9:
				var y0 := 0.06 + j * 0.1
				for i in 5:
					var x := 0.22 + i * 0.125 + (0.0625 if j % 2 == 1 else 0.0)
					out.append(PackedVector2Array([Vector2(x, y0 + 0.1), Vector2(x + 0.0625, y0), Vector2(x + 0.125, y0 + 0.1)]))
		"zigzag":
			for j in 5:
				out.append(_wave_band(0.2 + j * 0.16, 0.05, 0.03, false))
		"waves":
			for j in 5:
				out.append(_wave_band(0.2 + j * 0.16, 0.05, 0.03, true))
		"dots":
			for j in 13:
				for i in 8:
					out.append(_circle(Vector2(0.25 + i * 0.07 + (0.035 if j % 2 == 1 else 0.0), 0.1 + j * 0.068), 0.016, 8))
		"halftone":
			for j in 12:
				var rr := 0.003 + j * 0.0024
				for i in 12:
					out.append(_circle(Vector2(0.245 + i * 0.046 + (0.023 if j % 2 == 1 else 0.0), 0.4 + j * 0.046), rr, 6))
		"gradient":
			out.append(_rect(0, 0.62, 1, 0.4))
		"fade_up":
			out.append(_rect(0, 0.78, 1, 0.3))
		"brush":
			for j in 4:
				out.append(_brush_stroke(0.24 + j * 0.2, 0.06, j))
		"sunburst":
			var c := Vector2(0.5, 1.15)
			for i in 9:
				var a0 := -PI * 0.5 + (i - 4) * 0.16 - 0.04
				var a1 := a0 + 0.08
				out.append(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 1.3, c + Vector2(cos(a1), sin(a1)) * 1.3]))
		"shatter":
			var rng := RandomNumberGenerator.new()
			rng.seed = 91
			for i in 16:
				var p := Vector2(rng.randf_range(0.25, 0.75), rng.randf_range(0.45, 0.95))
				var a := rng.randf() * TAU
				var l := rng.randf_range(0.05, 0.11)
				out.append(PackedVector2Array([p, p + Vector2(cos(a), sin(a)) * l, p + Vector2(cos(a + 0.5), sin(a + 0.5)) * l * 0.7]))
		"camo":
			var rng := RandomNumberGenerator.new()
			rng.seed = 37
			for i in 16:
				var cc := Vector2(rng.randf_range(0.22, 0.78), rng.randf_range(0.08, 0.95))
				var pts := PackedVector2Array()
				var base := rng.randf_range(0.035, 0.06)
				var ph := rng.randf() * TAU
				for k in 12:
					var a := k * TAU / 12.0
					var rr := base * (1.0 + 0.35 * sin(a * 3.0 + ph) + 0.2 * cos(a * 2.0 + ph * 1.7))
					pts.append(cc + Vector2(cos(a) * rr * 1.3, sin(a) * rr))
				out.append(pts)
		"topo":
			var cc := Vector2(0.62, 0.62)
			for k in 7:
				var rr := 0.05 + k * 0.065
				for seg in 28:
					var a0 := seg * TAU / 28.0
					var a1 := (seg + 1) * TAU / 28.0
					var w0 := rr * (1.0 + 0.08 * sin(a0 * 3.0 + k))
					var w1 := rr * (1.0 + 0.08 * sin(a1 * 3.0 + k))
					out.append(PackedVector2Array([cc + Vector2(cos(a0), sin(a0)) * w0, cc + Vector2(cos(a1), sin(a1)) * w1,
						cc + Vector2(cos(a1), sin(a1)) * (w1 + 0.012), cc + Vector2(cos(a0), sin(a0)) * (w0 + 0.012)]))
	return out


## Faixas da terceira cor (c3) das estampas tricolores.
static func pattern_bands3(pattern: String) -> Array:
	match pattern:
		"tricolor_v":
			return [_rect(0.5834, 0, 0.3, 1)]
		"tricolor_h":
			return [_rect(0, 0.65, 1, 0.4)]
		"stripes_tri":
			return [_rect(0.32, 0, 0.075, 1), _rect(0.51, 0, 0.075, 1), _rect(0.7, 0, 0.075, 1)]
		"faixa_duo":
			return [_rect(0, 0.425, 1, 0.075)]
		"center_stripe_edged":
			return [_rect(0.445, 0, 0.11, 1)]
	return []


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


static func _diamond(c: Vector2, hw: float, hh: float) -> PackedVector2Array:
	return PackedVector2Array([c + Vector2(0, -hh), c + Vector2(hw, 0), c + Vector2(0, hh), c + Vector2(-hw, 0)])


static func _circle(c: Vector2, r: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := i * TAU / n
		out.append(c + Vector2(cos(a), sin(a)) * r)
	return out


## Faixa horizontal ondulada (senoide) ou em zigue-zague.
static func _wave_band(y: float, h: float, amp: float, smooth: bool) -> PackedVector2Array:
	var top := PackedVector2Array()
	var n := 24 if smooth else 12
	for i in n + 1:
		var x := 0.2 + i * 0.6 / n
		var d: float
		if smooth:
			d = sin(i * TAU / 8.0) * amp
		else:
			d = amp if i % 2 == 0 else -amp
		top.append(Vector2(x, y + d))
	var out := top.duplicate()
	for i in range(n, -1, -1):
		out.append(top[i] + Vector2(0, h))
	return out


## Pincelada: faixa com bordas irregulares.
static func _brush_stroke(y: float, h: float, seed_i: int) -> PackedVector2Array:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 21:
		var x := 0.18 + i * 0.032
		var n1 := sin(i * 1.7 + seed_i * 2.3) * 0.012 + sin(i * 4.1 + seed_i) * 0.006
		var n2 := sin(i * 2.3 + seed_i * 1.1) * 0.012 + cos(i * 3.7 + seed_i) * 0.006
		var taper := 1.0 - pow(absf(i - 10) / 10.0, 3.0) * 0.6
		top.append(Vector2(x, y + n1 - h * 0.5 * taper))
		bot.append(Vector2(x, y + n2 + h * 0.5 * taper))
	var out := top.duplicate()
	for i in range(bot.size() - 1, -1, -1):
		out.append(bot[i])
	return out


static func _xf(pts: Array, s: float, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(off + p * s)
	return out


static func _fx(r: Rect2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(r.position + Vector2(p.x * r.size.x, p.y * r.size.y))
	return out


static func _fr(r: Rect2, x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(r.position + Vector2(x * r.size.x, y * r.size.y), Vector2(w * r.size.x, h * r.size.y))
