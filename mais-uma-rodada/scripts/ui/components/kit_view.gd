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
const BODY := [Vector2(0.378, 0.062), Vector2(0.5, 0.072), Vector2(0.622, 0.062), Vector2(0.682, 0.08), Vector2(0.722, 0.114),
	Vector2(0.741, 0.2), Vector2(0.745, 0.3), Vector2(0.734, 0.45), Vector2(0.717, 0.62), Vector2(0.72, 0.78), Vector2(0.728, 0.93),
	Vector2(0.62, 0.948), Vector2(0.5, 0.955), Vector2(0.38, 0.948), Vector2(0.272, 0.93), Vector2(0.28, 0.78), Vector2(0.283, 0.62),
	Vector2(0.266, 0.45), Vector2(0.255, 0.3), Vector2(0.259, 0.2), Vector2(0.278, 0.114), Vector2(0.318, 0.08)]
## Índices do contorno do corpo: ombro direito (gola..cava), lateral direita..barra..lateral esquerda, ombro esquerdo.
const BODY_SHOULDER_R := [2, 3, 4, 5]
const BODY_SIDES := [5, 19]
const BODY_SHOULDER_L := [0, 21, 20, 19]
## Manga direita (de quem olha); a esquerda é o espelho. Braço caído junto ao corpo, deltoide
## arredondado no ombro e a boca da manga na metade do braço.
const SLEEVE_SHORT := [Vector2(0.678, 0.079), Vector2(0.75, 0.094), Vector2(0.802, 0.128), Vector2(0.838, 0.19), Vector2(0.868, 0.325),
	Vector2(0.766, 0.362), Vector2(0.746, 0.292), Vector2(0.736, 0.2)]
const SLEEVE_LONG := [Vector2(0.678, 0.079), Vector2(0.75, 0.094), Vector2(0.8, 0.128), Vector2(0.835, 0.2), Vector2(0.86, 0.33),
	Vector2(0.874, 0.47), Vector2(0.888, 0.6), Vector2(0.836, 0.616), Vector2(0.81, 0.47), Vector2(0.79, 0.37), Vector2(0.75, 0.3),
	Vector2(0.736, 0.2)]
## Índices da boca da manga em cada formato.
const CUFF_SHORT := [4, 5]
const CUFF_LONG := [6, 7]
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
	var body := _xf(BODY, s, off)
	var sleeve_col := c2 if sleeve == "contrast" or sleeve == "raglan" else c1
	var sleeves_u: Array = [_sleeve_poly(long, false), _sleeve_poly(long, true)]
	# Mangas
	for su: Array in sleeves_u:
		draw_colored_polygon(_xf(su, s, off), sleeve_col)
	# Corpo e estampa
	draw_colored_polygon(body, c1)
	if pat in GRADIENTS:
		_draw_gradient(pat, s, off, c1, pc[0])
	var carry := sleeve == "pattern" or (pat in CARRY and sleeve != "contrast" and sleeve != "raglan")
	for piece in _clipped(pat, "body", false):
		draw_colored_polygon(_xf(piece, s, off), pc[0])
	for piece in _clipped(pat, "body", true):
		draw_colored_polygon(_xf(piece, s, off), pc[1])
	if carry:
		for part in ["sl_long" if long else "sl_short"]:
			for piece in _clipped(pat, part, false):
				draw_colored_polygon(_xf(piece, s, off), pc[0])
			for piece in _clipped(pat, part, true):
				draw_colored_polygon(_xf(piece, s, off), pc[1])
	# Raglan: a cor da manga sobe até a gola
	if sleeve == "raglan":
		for sx in [false, true]:
			var rp := [Vector2(0.585, 0.064), Vector2(0.622, 0.062), Vector2(0.682, 0.08), Vector2(0.722, 0.114), Vector2(0.741, 0.2), Vector2(0.745, 0.3)]
			for piece in Geometry2D.intersect_polygons(_xf(_mirror(rp, sx), s, off), body):
				draw_colored_polygon(piece, c2)
			draw_polyline(_xf(_mirror([Vector2(0.585, 0.064), Vector2(0.745, 0.3)], sx), s, off), c3 if c3 != c2 else c2.darkened(0.3), maxf(1.0, s * 0.01), true)
	# Detalhes das mangas
	var cuff_idx: Array = CUFF_LONG if long else CUFF_SHORT
	for li in 2:
		var su: Array = sleeves_u[li]
		var a: Vector2 = su[cuff_idx[0]]
		var b: Vector2 = su[cuff_idx[1]]
		var s0: Vector2 = su[0]
		var s1: Vector2 = su[1]
		var inward: Vector2 = ((s0 + s1) * 0.5 - (a + b) * 0.5).normalized()
		match sleeve:
			"cuff":
				_band(a, b, inward, 0.0, 0.035, s, off, c3)
			"cuff_double":
				_band(a, b, inward, 0.0, 0.016, s, off, c3)
				_band(a, b, inward, 0.028, 0.016, s, off, c3)
			"tipped":
				_band(a, b, inward, 0.0, 0.03, s, off, c3)
				_band(a, b, inward, 0.01, 0.01, s, off, c2 if c2 != c3 else c1)
			"stripes":
				var t: Vector2 = su[SLEEVE_TOP]
				for i in 3:
					var d := Vector2((i - 1) * 0.018 * (-1.0 if li == 1 else 1.0), (i - 1) * 0.018)
					var p0: Vector2 = Vector2(0.682 if li == 0 else 0.318, 0.08) + d * 0.5
					draw_line(off + p0 * s, off + ((a + b) * 0.5).lerp(t, 0.35 - 0.15 * (i - 1)) * s + d * s * 0.3, c3, maxf(1.0, s * 0.011), true)
			"shoulder_stripe":
				var nk: Vector2 = Vector2(0.6, 0.064) if li == 0 else Vector2(0.4, 0.064)
				var tip: Vector2 = su[SLEEVE_TOP]
				var end: Vector2 = a.lerp(b, 0.2)
				draw_polyline(_xf([nk, tip, end], s, off), c3, maxf(1.5, s * 0.022), true)
	# Vivos
	var trim := String(kit.get("trim", "none"))
	var tw := maxf(1.0, s * 0.011)
	if trim == "sides" or trim == "both":
		for sx in [false, true]:
			draw_polyline(_xf(_mirror([Vector2(0.739, 0.31), Vector2(0.728, 0.45), Vector2(0.711, 0.62), Vector2(0.714, 0.78), Vector2(0.722, 0.925)], sx), s, off), c3, tw * 1.4, true)
	if trim == "shoulders" or trim == "both":
		for sx in [false, true]:
			draw_polyline(_xf(_mirror([Vector2(0.6, 0.066), Vector2(0.682, 0.08), Vector2(0.722, 0.114), Vector2(0.741, 0.2), Vector2(0.745, 0.3)], sx), s, off), c3, tw * 1.4, true)
	if trim == "hem":
		draw_polyline(_xf([Vector2(0.272, 0.915), Vector2(0.38, 0.933), Vector2(0.5, 0.94), Vector2(0.62, 0.933), Vector2(0.728, 0.915)], s, off), c3, maxf(1.5, s * 0.02), true)
	# Luz e dobras do tecido
	_draw_shading(s, off, long, c1)
	_draw_fabric(s, off, long)
	var show_logos := s >= 56.0
	if back:
		_place_crest(Rect2())
		# Costas: gola alta por trás, patrocinador, nome e número.
		var col := c3 if c3 != c1 else c1.darkened(0.4)
		draw_polyline(_xf([Vector2(0.39, 0.066), Vector2(0.5, 0.082), Vector2(0.61, 0.066)], s, off), col, maxf(1.5, s * 0.026), true)
		_outline(s, off, long, c1)
		var fg := _number_col(c1)
		if show_logos:
			var spc: Dictionary = kit.get("sp_c", {})
			if not spc.is_empty():
				_draw_patch(Rect2(off + Vector2(0.33, 0.12) * s, Vector2(0.34, 0.075) * s), spc, c1, false, "spcc")
			if back_name != "":
				_draw_text_centered(back_name.to_upper(), off + Vector2(0.5, 0.28) * s, s * 0.44, int(s * 0.072), fg, &"Caps", _num_edge(fg))
		if number > 0:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.58 if back_name != "" and show_logos else 0.53) * s, s * 0.46, int(s * (0.34 if show_logos else 0.44)), fg, &"Big", _num_edge(fg))
		return
	_draw_collar(s, off, c1, c3)
	_outline(s, off, long, c1)
	var sp: Dictionary = kit.get("sp", {})
	var has_master := not sp.is_empty() and show_logos
	if s >= 40.0:
		_draw_crest(s, off, c1, c2, c3)
	else:
		_place_crest(Rect2())
	if show_logos:
		if has_master:
			_draw_patch(Rect2(off + Vector2(0.29, 0.34) * s, Vector2(0.42, 0.12) * s), sp, _bg_at(Vector2(0.5, 0.4), c1), true, "spc")
		var sup: Dictionary = kit.get("sup", {})
		if not sup.is_empty():
			# Fornecedor no peito direito do jogador (esquerda de quem olha).
			_draw_supplier(off + Vector2(0.39, 0.2) * s, s * 0.035, sup, _bg_at(Vector2(0.39, 0.2), c1))
		var spm: Dictionary = kit.get("sp_m", {})
		if not spm.is_empty():
			_draw_patch(Rect2(off + Vector2(0.765, 0.15) * s, Vector2(0.1, 0.05) * s), spm, sleeve_col, false, "spmc")
	if number > 0:
		var fg := _number_col(c1)
		if has_master:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.64) * s, s * 0.26, int(s * 0.17), fg, &"Big", _num_edge(fg))
		else:
			_draw_text_centered(str(number), off + Vector2(0.5, 0.5) * s, s * 0.4, int(s * 0.3), fg, &"Big", _num_edge(fg))


## Cor por baixo de um ponto do peito (para o logo contrastar com a estampa).
func _bg_at(p: Vector2, c1: Color) -> Color:
	var pat := String(kit.get("pattern", "plain"))
	if pat == "plain" or bool(kit.get("tonal", false)) or pat in GRADIENTS:
		return c1
	for band: PackedVector2Array in pattern_bands(pat):
		if Geometry2D.is_point_in_polygon(p, band):
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


func _outline(s: float, off: Vector2, long: bool, c1: Color) -> void:
	var col := Color(1, 1, 1, 0.28) if c1.get_luminance() < 0.12 else Color(0, 0, 0, 0.45)
	var w := maxf(1.0, s * 0.01)
	for left in [false, true]:
		var sl := _xf(_sleeve_poly(long, left), s, off)
		# Só a parte de fora da manga (a de dentro fica sob o corpo)
		var n := sl.size()
		var outer := PackedVector2Array()
		for i in range(1, n - 1):
			outer.append(sl[i])
		draw_polyline(outer, col, w, true)
	var body := _xf(BODY, s, off)
	# Lados e barra (os ombros ficam por conta das mangas)
	var pts := PackedVector2Array()
	for i in range(BODY_SIDES[0], BODY_SIDES[1] + 1):
		pts.append(body[i])
	draw_polyline(pts, col, w, true)
	for idx: Array in [BODY_SHOULDER_R, BODY_SHOULDER_L]:
		var sh := PackedVector2Array()
		for i: int in idx:
			sh.append(body[i])
		draw_polyline(sh, Color(col, col.a * 0.6), w, true)


## Sombreado do tecido: laterais e barra mais escuras, peito e ombros iluminados, mangas com a parte
## de baixo na sombra, e duas dobras discretas.
func _draw_shading(s: float, off: Vector2, long: bool, c1: Color) -> void:
	var dark := c1.get_luminance() < 0.15
	var k := 0.6 if dark else 1.0
	for piece in _clipped("_shade", "body", false):
		var cols := PackedColorArray()
		for p: Vector2 in piece:
			var dx := (p.x - 0.47) / 0.25
			var a := (0.2 * dx * dx + 0.07 * clampf((p.y - 0.78) / 0.17, 0.0, 1.0)) * k
			cols.append(Color(0, 0, 0, a))
		draw_polygon(_xf(piece, s, off), cols)
	for piece in _clipped("_shine", "body", false):
		var cols := PackedColorArray()
		for p: Vector2 in piece:
			var d := (p - Vector2(0.44, 0.24)).length() / 0.2
			cols.append(Color(1, 1, 1, maxf(0.0, 0.09 * (1.0 - d * d)) * (1.6 if dark else 1.0)))
		draw_polygon(_xf(piece, s, off), cols)
	# Peitoral: luz em cima, sombra suave na linha de baixo, e o esterno discreto no meio.
	for sx in [false, true]:
		var pec := _mirror([Vector2(0.515, 0.335), Vector2(0.6, 0.35), Vector2(0.685, 0.335), Vector2(0.705, 0.355),
			Vector2(0.69, 0.385), Vector2(0.6, 0.402), Vector2(0.52, 0.385)], sx)
		draw_polygon(_xf(pec, s, off), PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0),
			Color(0, 0, 0, 0.07 * k), Color(0, 0, 0, 0.09 * k), Color(0, 0, 0, 0.06 * k)]))
		var lit := _mirror([Vector2(0.53, 0.2), Vector2(0.62, 0.19), Vector2(0.69, 0.23), Vector2(0.685, 0.33), Vector2(0.6, 0.345), Vector2(0.52, 0.32)], sx)
		draw_polygon(_xf(lit, s, off), PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.035 * (1.6 if dark else 1.0)), Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.05 * (1.6 if dark else 1.0)), Color(1, 1, 1, 0.0)]))
	draw_polyline(_xf([Vector2(0.5, 0.2), Vector2(0.5, 0.38)], s, off), Color(0, 0, 0, 0.05 * k), maxf(1.0, s * 0.014), true)
	# Mangas: a parte de baixo e o lado colado ao corpo ficam na sombra; o alto do deltoide pega luz.
	var cuff_in: int = (CUFF_LONG if long else CUFF_SHORT)[1]
	for left in [false, true]:
		var su := _sleeve_poly(long, left)
		var cols := PackedColorArray()
		for i in su.size():
			var p: Vector2 = su[i]
			var a := clampf((p.y - 0.09) / 0.3, 0.0, 1.0) * 0.14 + (0.1 if i >= cuff_in else 0.0)
			cols.append(Color(0, 0, 0, a * k))
		draw_polygon(_xf(su, s, off), cols)
		var dl := _mirror([Vector2(0.72, 0.1), Vector2(0.775, 0.105), Vector2(0.81, 0.15), Vector2(0.79, 0.19), Vector2(0.75, 0.16)], left)
		draw_polygon(_xf(dl, s, off), PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.06 * (1.6 if dark else 1.0)), Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.03)]))
	for sx in [false, true]:
		# Dobras curvas com volume e pontas que desaparecem no tecido.
		_cloth_fold(_mirror([Vector2(0.738, 0.31), Vector2(0.705, 0.34), Vector2(0.67, 0.348)], sx), 0.018, 0.13 * k, s, off)
		_cloth_fold(_mirror([Vector2(0.712, 0.64), Vector2(0.68, 0.66), Vector2(0.65, 0.685)], sx), 0.022, 0.1 * k, s, off)
		_cloth_fold(_mirror([Vector2(0.716, 0.8), Vector2(0.698, 0.813), Vector2(0.672, 0.812)], sx), 0.016, 0.07 * k, s, off)
	# Costura dupla da barra, só quando há pixels suficientes para separá-la.
	if s >= 150.0:
		for dy in [0.0, -0.009]:
			var hem := [Vector2(0.287, 0.922 + dy), Vector2(0.38, 0.94 + dy), Vector2(0.5, 0.947 + dy), Vector2(0.62, 0.94 + dy), Vector2(0.713, 0.922 + dy)]
			draw_polyline(_xf(hem, s, off), Color(0, 0, 0, 0.12 * k), maxf(0.55, s * 0.002), true)


## Três faixas de triângulos: crista, sombra e bordas transparentes. 48 triângulos
## por dobra, retidos pelo CanvasItem; sem textura, shader ou trabalho por quadro.
func _cloth_fold(curve: Array, width: float, alpha: float, s: float, off: Vector2) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	for i in 9:
		var t := float(i) / 8.0
		var a: Vector2 = curve[0].lerp(curve[1], t)
		var b: Vector2 = curve[1].lerp(curve[2], t)
		var p := a.lerp(b, t)
		var normal := (b - a).normalized().orthogonal()
		var fade := sin(PI * t)
		for j in 4:
			points.append(off + (p + normal * width * (float(j) / 3.0 - 0.5) * fade) * s)
			colors.append([Color(1, 1, 1, 0), Color(1, 1, 1, alpha * 0.55 * fade), Color(0, 0, 0, alpha * fade), Color(0, 0, 0, 0)][j])
	var indices := PackedInt32Array()
	for i in 8:
		for j in 3:
			var a := i * 4 + j
			for idx in [a, a + 4, a + 5, a, a + 5, a + 1]:
				indices.append(idx)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colors)


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
	if s < 180.0:
		return
	var texture := _knit()
	for piece: Array in [BODY, _sleeve_poly(long, false), _sleeve_poly(long, true)]:
		var uv := PackedVector2Array()
		for p: Vector2 in piece:
			uv.append(p * 8.0)
		draw_polygon(_xf(piece, s, off), PackedColorArray([Color.WHITE]), uv, texture)
	# Costura de união das mangas, no mesmo tom do tecido.
	for side in [false, true]:
		var seam := _mirror([Vector2(0.682, 0.09), Vector2(0.719, 0.12), Vector2(0.737, 0.2), Vector2(0.74, 0.292)], side)
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


func _draw_collar(s: float, off: Vector2, c1: Color, c3: Color) -> void:
	var collar: String = kit.get("collar", "round")
	var col := c3 if c3 != c1 else c1.darkened(0.4)
	var inside := c1.darkened(0.45)
	var w := maxf(1.5, s * 0.028)
	var neck: Array
	match collar:
		"v":
			neck = [Vector2(0.4, 0.064), Vector2(0.5, 0.19), Vector2(0.6, 0.064)]
		"crossover":
			neck = [Vector2(0.4, 0.064), Vector2(0.5, 0.18), Vector2(0.6, 0.064)]
		"laced":
			neck = [Vector2(0.41, 0.064), Vector2(0.45, 0.1), Vector2(0.5, 0.17), Vector2(0.55, 0.1), Vector2(0.59, 0.064)]
		"retro":
			neck = [Vector2(0.41, 0.064), Vector2(0.5, 0.2), Vector2(0.59, 0.064)]
		"wide":
			neck = [Vector2(0.365, 0.062), Vector2(0.42, 0.118), Vector2(0.5, 0.135), Vector2(0.58, 0.118), Vector2(0.635, 0.062)]
			w *= 1.3
		"mandarin", "zip", "polo":
			neck = [Vector2(0.39, 0.064), Vector2(0.44, 0.092), Vector2(0.5, 0.1), Vector2(0.56, 0.092), Vector2(0.61, 0.064)]
		_:
			neck = [Vector2(0.395, 0.064), Vector2(0.44, 0.1), Vector2(0.5, 0.112), Vector2(0.56, 0.1), Vector2(0.605, 0.064)]
	# Parte de dentro da camisa (costas por dentro da gola)
	var opening: Array = neck.duplicate()
	opening.append(Vector2(0.5, 0.05))
	draw_colored_polygon(_xf(opening, s, off), inside)
	var line := _xf(neck, s, off)
	match collar:
		"ringer":
			draw_polyline(line, col, w * 1.2, true)
			draw_polyline(_xf(_offset_y(neck, 0.006), s, off), c1 if col != c1 else Color.WHITE, maxf(1.0, w * 0.3), true)
		"crossover":
			draw_polyline(line, col, w, true)
			# A aba da esquerda passa por cima da direita
			draw_colored_polygon(_xf([Vector2(0.47, 0.15), Vector2(0.5, 0.19), Vector2(0.535, 0.145), Vector2(0.52, 0.13)], s, off), col.darkened(0.12))
			draw_line(off + Vector2(0.4, 0.064) * s, off + Vector2(0.53, 0.2) * s, col, w, true)
		"henley":
			draw_polyline(line, col, w, true)
			draw_line(off + Vector2(0.5, 0.112) * s, off + Vector2(0.5, 0.23) * s, col, maxf(1.0, s * 0.012), true)
			for i in 3:
				draw_circle(off + Vector2(0.5, 0.14 + i * 0.035) * s, maxf(1.0, s * 0.009), col.darkened(0.2))
		"laced":
			draw_polyline(line, col, w * 0.8, true)
			var lace := PackedVector2Array()
			for i in 5:
				var y := 0.08 + i * 0.018
				var hw := 0.035 * (1.0 - (y - 0.064) / 0.11)
				lace.append(off + Vector2(0.5 + (hw if i % 2 == 0 else -hw), y) * s)
			draw_polyline(lace, col.lightened(0.2), maxf(1.0, s * 0.008), true)
		"polo":
			draw_polyline(line, col, w * 0.8, true)
			for sx in [false, true]:
				draw_colored_polygon(_xf(_mirror([Vector2(0.385, 0.058), Vector2(0.5, 0.1), Vector2(0.47, 0.165), Vector2(0.405, 0.125)], sx), s, off), col)
				draw_polyline(_xf(_mirror([Vector2(0.405, 0.125), Vector2(0.47, 0.165), Vector2(0.5, 0.1)], sx), s, off), col.darkened(0.3), maxf(1.0, s * 0.008), true)
			draw_line(off + Vector2(0.5, 0.1) * s, off + Vector2(0.5, 0.24) * s, col.darkened(0.2), maxf(1.0, s * 0.012), true)
			for i in 2:
				draw_circle(off + Vector2(0.5, 0.18 + i * 0.04) * s, maxf(1.0, s * 0.009), col.darkened(0.3))
		"retro":
			draw_polyline(line, col, w * 0.7, true)
			for sx in [false, true]:
				draw_colored_polygon(_xf(_mirror([Vector2(0.37, 0.056), Vector2(0.41, 0.064), Vector2(0.5, 0.2), Vector2(0.43, 0.23), Vector2(0.39, 0.13)], sx), s, off), col)
				draw_polyline(_xf(_mirror([Vector2(0.39, 0.13), Vector2(0.43, 0.23), Vector2(0.5, 0.2)], sx), s, off), col.darkened(0.3), maxf(1.0, s * 0.008), true)
		"mandarin":
			draw_colored_polygon(_xf([Vector2(0.38, 0.045), Vector2(0.62, 0.045), Vector2(0.61, 0.092), Vector2(0.5, 0.108), Vector2(0.39, 0.092)], s, off), col)
			draw_circle(off + Vector2(0.5, 0.098) * s, maxf(1.0, s * 0.009), col.darkened(0.3))
		"zip":
			draw_colored_polygon(_xf([Vector2(0.38, 0.045), Vector2(0.62, 0.045), Vector2(0.61, 0.092), Vector2(0.5, 0.108), Vector2(0.39, 0.092)], s, off), col)
			draw_line(off + Vector2(0.5, 0.1) * s, off + Vector2(0.5, 0.25) * s, col.darkened(0.35), maxf(1.0, s * 0.014), true)
			draw_rect(Rect2(off + Vector2(0.49, 0.1) * s, Vector2(0.02, 0.03) * s), Color("#C9CCD1"))
		_:
			draw_polyline(line, col, w, true)


func _offset_y(pts: Array, dy: float) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p + Vector2(0, dy))
	return out


## Escudo no lado do coração (direita de quem olha). Sem escudo do clube, um brasão genérico.
func _draw_crest(s: float, off: Vector2, c1: Color, c2: Color, c3: Color) -> void:
	var cc := Vector2(0.61, 0.205)
	var cs := 0.09
	if not crest.is_empty():
		_place_crest(Rect2(off + (cc - Vector2(cs, cs) * 0.5) * s, Vector2(cs, cs) * s))
		return
	_place_crest(Rect2())
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


## Patrocinador estampado no tecido: sem caixa, na cor da marca que contrasta com o fundo.
## O master ganha um pequeno emblema da marca ao lado do nome.
func _draw_patch(r: Rect2, sp: Dictionary, bg: Color, emblem: bool = false, ov_key: String = "") -> void:
	var fg := _ink(sp, bg)
	if ov_key != "" and String(kit.get(ov_key, "")) != "":
		fg = Color(String(kit[ov_key])) # cor escolhida no editor de uniforme
	var name := String(sp.get("n", "")).to_upper()
	# A tinta cruza várias cores nas estampas. Um contorno de impressão fino
	# preserva a marca e a escolha do editor sem uma placa tapando o desenho.
	var outline := Color.TRANSPARENT
	if String(kit.get("pattern", "plain")) != "plain" and absf(Color(String(kit.get("c1", "#FFFFFF"))).get_luminance() - Color(String(kit.get("c2", "#111111"))).get_luminance()) > 0.25:
		outline = Color("#17191D") if fg.get_luminance() > 0.45 else Color("#F5F3EE")
	var center := r.get_center()
	var max_w := r.size.x
	if emblem:
		# Símbolo da marca (BrandCatalog) à esquerda do nome.
		var e := r.size.y * 0.32
		var ec := Vector2(r.position.x + e, center.y)
		if not BrandMark.draw(self, String(sp.get("m", "")), ec, e, fg, bg):
			BrandMark.draw(self, "alvo", ec, e, fg, bg)
		center.x += e
		max_w -= e * 2.4
	if not _draw_text_centered(name, center, max_w, int(r.size.y * 0.75), fg, &"Big", outline):
		# Espaço pequeno (manga, calção): só as iniciais da marca.
		var ini := ""
		for word in name.split(" ", false):
			ini += word.substr(0, 1)
		_draw_text_centered(ini, center, max_w, int(r.size.y * 0.8), fg, &"Big", outline)


## Cor de "tinta" da marca que aparece sobre o tecido.
static func _ink(sp: Dictionary, bg: Color) -> Color:
	for key in ["t", "c"]:
		var c := Color(String(sp.get(key, "#FFFFFF")))
		if absf(c.get_luminance() - bg.get_luminance()) > 0.35:
			return c
	return UIColors.on_color(bg)


## Logo da fornecedora (formas simples de BrandMark, sem marcas reais).
func _draw_supplier(c: Vector2, u: float, sp: Dictionary, bg: Color) -> void:
	var col := _ink(sp, bg)
	if String(kit.get("supc", "")) != "":
		col = Color(String(kit["supc"]))
	if not BrandMark.draw(self, String(sp.get("logo", "")), c, u, col, bg):
		_draw_text_centered(String(sp.get("n", "")).substr(0, 1).to_upper(), c, u * 2.0, int(u * 1.6), col, &"Big")


## Texto centrado em `center`, encolhido até caber em `max_w`.
func _draw_text_centered(txt: String, center: Vector2, max_w: float, size_px: int, color: Color, variation: StringName, outline: Color = Color(0, 0, 0, 0)) -> bool:
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
	if outline.a > 0.0:
		draw_string_outline(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, maxi(1, fs / 10), outline)
	draw_string(font, at, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	return true


## Calção (perna esquerda de quem olha; a direita é o espelho). Cintura sob a camisa, quadril
## arredondado, barra mais baixa por fora e o gancho no meio.
const SHORTS_L := [Vector2(0.3, 0.44), Vector2(0.283, 0.48), Vector2(0.262, 0.54), Vector2(0.243, 0.6), Vector2(0.226, 0.652),
	Vector2(0.29, 0.662), Vector2(0.36, 0.668), Vector2(0.43, 0.664), Vector2(0.478, 0.655), Vector2(0.49, 0.625), Vector2(0.5, 0.598)]
## Lateral (da cintura à barra) e barra do calção, prolongadas para os recortes.
const SHORTS_SIDE := [Vector2(0.3, 0.42), Vector2(0.3, 0.44), Vector2(0.283, 0.48), Vector2(0.262, 0.54), Vector2(0.243, 0.6), Vector2(0.226, 0.652), Vector2(0.22, 0.68)]
const SHORTS_HEM := [Vector2(0.2, 0.65), Vector2(0.226, 0.652), Vector2(0.29, 0.662), Vector2(0.36, 0.668), Vector2(0.43, 0.664), Vector2(0.478, 0.655), Vector2(0.5, 0.65)]
## Coxa e joelho entre a barra do calção e o meião.
const LEG := [Vector2(0.262, 0.62), Vector2(0.475, 0.62), Vector2(0.462, 0.665), Vector2(0.448, 0.712), Vector2(0.302, 0.712), Vector2(0.278, 0.665)]
## Meião: contorno de fora e de dentro, de cima para baixo (panturrilha cheia, tornozelo fino).
const SOCK_OUT := [Vector2(0.298, 0.705), Vector2(0.289, 0.74), Vector2(0.283, 0.78), Vector2(0.29, 0.83), Vector2(0.307, 0.875), Vector2(0.318, 0.922)]
const SOCK_IN := [Vector2(0.447, 0.705), Vector2(0.455, 0.745), Vector2(0.46, 0.79), Vector2(0.45, 0.84), Vector2(0.43, 0.88), Vector2(0.42, 0.922)]
## Chuteira com o bico um pouco virado para fora: cano, peito do pé, bico e solado.
const BOOT := [Vector2(0.316, 0.913), Vector2(0.424, 0.913), Vector2(0.433, 0.94), Vector2(0.431, 0.965), Vector2(0.4, 0.976),
	Vector2(0.33, 0.979), Vector2(0.275, 0.976), Vector2(0.248, 0.97), Vector2(0.243, 0.958), Vector2(0.258, 0.946), Vector2(0.29, 0.936), Vector2(0.31, 0.926)]
const BOOT_SOLE := [Vector2(0.431, 0.962), Vector2(0.4, 0.973), Vector2(0.33, 0.976), Vector2(0.275, 0.973), Vector2(0.246, 0.966)]


## Calção, pernas, meiões e chuteiras (modo completo). Desenhado antes da camisa, que cobre a cintura.
func _draw_legs(r: Rect2) -> void:
	var sh := Color(String(kit.get("shorts", kit.get("c2", "#111111"))))
	var sh2 := Color(String(kit.get("shorts2", kit.get("c1", "#FFFFFF"))))
	var so := Color(String(kit.get("socks", kit.get("c1", "#FFFFFF"))))
	var so2 := Color(String(kit.get("socks2", kit.get("c2", "#000000"))))
	var skin := Color("#C68E5D")
	var boot := Color("#1A1A1A")
	var lw := maxf(1.0, r.size.x * 0.011)
	var out_sh := Color(1, 1, 1, 0.25) if sh.get_luminance() < 0.12 else Color(0, 0, 0, 0.42)
	# Coxas e joelhos: sombra da barra do calção em cima, rótula com um toque de luz
	for sx in [false, true]:
		draw_colored_polygon(_fx(r, _mirror(LEG, sx)), skin)
		draw_polygon(_fx(r, _mirror([Vector2(0.27, 0.655), Vector2(0.47, 0.655), Vector2(0.462, 0.685), Vector2(0.285, 0.685)], sx)),
			PackedColorArray([Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.3), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
		draw_polygon(_fx(r, _mirror([Vector2(0.35, 0.68), Vector2(0.4, 0.68), Vector2(0.41, 0.695), Vector2(0.375, 0.706), Vector2(0.34, 0.695)], sx)),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.1), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.1)]))
		for side in [[Vector2(0.278, 0.665), Vector2(0.302, 0.712), Vector2(0.33, 0.712), Vector2(0.305, 0.665)],
				[Vector2(0.462, 0.665), Vector2(0.448, 0.712), Vector2(0.425, 0.712), Vector2(0.44, 0.665)]]:
			draw_polygon(_fx(r, _mirror(side, sx)), PackedColorArray([Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.16), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0)]))
	# Calção (a camisa cobre a cintura)
	var shorts_u: Array = SHORTS_L.duplicate()
	for i in range(SHORTS_L.size() - 2, -1, -1):
		var p: Vector2 = SHORTS_L[i]
		shorts_u.append(Vector2(1.0 - p.x, p.y))
	var shorts := _fx(r, shorts_u)
	draw_colored_polygon(shorts, sh)
	var st: String = kit.get("shorts_style", "plain")
	var bands: Array = []
	match st:
		"side_stripe":
			bands = [_side_strip(-0.03, -0.03, 0.016, 0.035)]
		"side_panel":
			bands = [_side_strip(-0.03, -0.03, 0.05, 0.075)]
		"piping":
			bands = [_side_strip(0.01, 0.012, 0.022, 0.024)]
		"hem":
			bands = [_hem_strip(-0.05, 0.03)]
		"hem_double":
			bands = [_hem_strip(0.036, 0.046), _hem_strip(-0.05, 0.024)]
		"two_tone":
			bands = [[Vector2(0.5, 0.4), Vector2(1, 0.4), Vector2(1, 0.7), Vector2(0.5, 0.7)]]
		"stripes3":
			for i in 3:
				var d := 0.006 + i * 0.018
				bands.append(_side_strip(d, d + 0.005, d + 0.008, d + 0.013))
		"vent":
			bands = [[Vector2(0.226, 0.652), Vector2(0.247, 0.592), Vector2(0.266, 0.657)], _hem_strip(-0.05, 0.02)]
	for b: Array in bands:
		for sx in [false, true]:
			if st == "two_tone" and sx:
				continue
			for piece in Geometry2D.intersect_polygons(_fx(r, _mirror(b, sx)), shorts):
				draw_colored_polygon(piece, sh2)
	# Sombra da camisa sobre o calção, volume das coxas e dobras do gancho
	var shade_k := 0.6 if sh.get_luminance() < 0.15 else 1.0
	for piece in Geometry2D.intersect_polygons(_fx(r, [Vector2(0.2, 0.46), Vector2(0.8, 0.46), Vector2(0.8, 0.515), Vector2(0.2, 0.515)]), shorts):
		var cols := PackedColorArray()
		for p in piece:
			cols.append(Color(0, 0, 0, 0.24 * shade_k * clampf(1.0 - ((p.y - r.position.y) / r.size.y - 0.475) / 0.04, 0.0, 1.0)))
		draw_polygon(piece, cols)
	draw_polyline(_fx(r, [Vector2(0.5, 0.52), Vector2(0.5, 0.6)]), Color(0, 0, 0, 0.18 * shade_k), lw, true)
	for sx in [false, true]:
		for piece in Geometry2D.intersect_polygons(_fx(r, _mirror(_side_strip(-0.03, -0.03, 0.04, 0.05), sx)), shorts):
			draw_colored_polygon(piece, Color(0, 0, 0, 0.12 * shade_k))
		draw_polyline(_fx(r, _mirror([Vector2(0.488, 0.61), Vector2(0.455, 0.632), Vector2(0.42, 0.645)], sx)), Color(0, 0, 0, 0.14 * shade_k), lw, true)
		draw_polyline(_fx(r, _mirror([Vector2(0.3, 0.6), Vector2(0.34, 0.625)], sx)), Color(0, 0, 0, 0.08 * shade_k), lw, true)
	var sps: Dictionary = kit.get("sp_s", {})
	if not sps.is_empty() and r.size.y >= 120.0 and not back:
		_draw_patch(_fr(r, 0.56, 0.575, 0.18, 0.045), sps, sh, false, "spsc")
	var so_line := shorts.duplicate()
	so_line.append(shorts[0])
	draw_polyline(so_line, out_sh, lw, true)
	# Meiões e chuteiras
	var ss: String = kit.get("socks_style", "plain")
	var out_so := Color(1, 1, 1, 0.25) if so.get_luminance() < 0.12 else Color(0, 0, 0, 0.42)
	var sock_u: Array = SOCK_OUT.duplicate()
	for i in range(SOCK_IN.size() - 1, -1, -1):
		sock_u.append(SOCK_IN[i])
	for sx in [false, true]:
		var sock := _fx(r, _mirror(sock_u, sx))
		draw_colored_polygon(sock, so)
		var x0 := 0.24
		var sw := 0.26
		var sb: Array = []
		match ss:
			"hoops":
				for i in 3:
					sb.append(Rect2(x0, 0.735 + i * 0.05, sw, 0.022))
			"top_band":
				sb.append(Rect2(x0, 0.7, sw, 0.045))
			"top_stripes":
				sb.append(Rect2(x0, 0.712, sw, 0.01))
				sb.append(Rect2(x0, 0.728, sw, 0.01))
			"two_tone":
				sb.append(Rect2(x0, 0.82, sw, 0.11))
			"stripes3":
				for i in 3:
					sb.append(Rect2(x0, 0.72 + i * 0.016, sw, 0.008))
			"hoops_thin":
				sb.append(Rect2(x0, 0.77, sw, 0.012))
				sb.append(Rect2(x0, 0.79, sw, 0.012))
			"band_mid":
				sb.append(Rect2(x0, 0.77, sw, 0.045))
			"foot":
				sb.append(Rect2(x0, 0.88, sw, 0.05))
		for rr: Rect2 in sb:
			var poly := _fx(r, _mirror([rr.position, rr.position + Vector2(rr.size.x, 0), rr.end, rr.position + Vector2(0, rr.size.y)], sx))
			for piece in Geometry2D.intersect_polygons(poly, sock):
				draw_colored_polygon(piece, so2)
		if ss == "chevron":
			var cv := _fx(r, _mirror([Vector2(0.272, 0.73), Vector2(0.372, 0.765), Vector2(0.472, 0.73), Vector2(0.472, 0.75), Vector2(0.372, 0.785), Vector2(0.272, 0.75)], sx))
			for piece in Geometry2D.intersect_polygons(cv, sock):
				draw_colored_polygon(piece, so2)
		# Dobra do punho, volume da panturrilha e luz na canela
		draw_line(_fx(r, _mirror([Vector2(0.29, 0.744)], sx))[0], _fx(r, _mirror([Vector2(0.455, 0.746)], sx))[0], Color(0, 0, 0, 0.14), maxf(1.0, r.size.y * 0.004), true)
		var side_a := 0.12 if so.get_luminance() > 0.15 else 0.07
		for edge: Array in [[SOCK_OUT, 0.04], [SOCK_IN, -0.045]]:
			var pts: Array = edge[0]
			var poly: Array = pts.duplicate()
			for i in range(pts.size() - 1, -1, -1):
				poly.append(pts[i] + Vector2(edge[1], 0.0))
			var cols := PackedColorArray()
			for i in poly.size():
				cols.append(Color(0, 0, 0, side_a if i < pts.size() else 0.0))
			draw_polygon(_fx(r, _mirror(poly, sx)), cols)
		draw_polygon(_fx(r, _mirror([Vector2(0.33, 0.77), Vector2(0.357, 0.76), Vector2(0.385, 0.77), Vector2(0.37, 0.9), Vector2(0.357, 0.905), Vector2(0.344, 0.9)], sx)),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.03), Color(1, 1, 1, 0.0)]))
		var sk := sock.duplicate()
		sk.append(sock[0])
		draw_polyline(sk, out_so, lw, true)
		# Chuteira: cabedal, solado com travas, faixa da marca e brilho no bico
		var bt := _fx(r, _mirror(BOOT, sx))
		draw_colored_polygon(bt, boot)
		for tx in [0.27, 0.32, 0.4]:
			draw_colored_polygon(_fx(r, _mirror([Vector2(tx, 0.975), Vector2(tx + 0.022, 0.975), Vector2(tx + 0.018, 0.986), Vector2(tx + 0.004, 0.986)], sx)), Color("#2A2A2A"))
		draw_polyline(_fx(r, _mirror(BOOT_SOLE, sx)), Color("#3A3A3A"), maxf(1.0, r.size.y * 0.006), true)
		draw_polyline(_fx(r, _mirror([Vector2(0.41, 0.952), Vector2(0.35, 0.952), Vector2(0.295, 0.944)], sx)), Color(1, 1, 1, 0.75), maxf(1.0, r.size.y * 0.005), true)
		draw_polygon(_fx(r, _mirror([Vector2(0.262, 0.95), Vector2(0.29, 0.942), Vector2(0.282, 0.956), Vector2(0.258, 0.962)], sx)),
			PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0)]))
		draw_polyline(_fx(r, _mirror([Vector2(0.33, 0.918), Vector2(0.41, 0.918)], sx)), Color(1, 1, 1, 0.12), maxf(1.0, r.size.y * 0.004), true)


## Faixa ao longo da lateral do calção: de `a` a `b` para dentro (topo → barra).
func _side_strip(a0: float, a1: float, b0: float, b1: float) -> Array:
	var n := SHORTS_SIDE.size()
	var outer: Array = []
	var inner: Array = []
	for i in n:
		var t := float(i) / float(n - 1)
		var p: Vector2 = SHORTS_SIDE[i]
		outer.append(p + Vector2(lerpf(a0, a1, t), 0.0))
		inner.append(p + Vector2(lerpf(b0, b1, t), 0.0))
	inner.reverse()
	return outer + inner


## Faixa acompanhando a barra do calção, de `a` a `b` acima dela (negativo = abaixo).
func _hem_strip(a: float, b: float) -> Array:
	var top: Array = []
	var bot: Array = []
	for p: Vector2 in SHORTS_HEM:
		top.append(p - Vector2(0.0, b))
		bot.append(p - Vector2(0.0, a))
	bot.reverse()
	return top + bot


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
