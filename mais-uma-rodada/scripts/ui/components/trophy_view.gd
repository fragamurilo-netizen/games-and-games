@tool
class_name TrophyView
extends Control
## Troféu procedural de uma competição. Cada liga e copa tem o seu: o formato sai da própria
## competição (fixo entre saves), o metal do nível (ouro na elite, prata na segunda divisão,
## bronze abaixo) e a fita da base leva as cores da bandeira do país (ou da confederação).
## `key` usa o formato dos títulos do clube: "L:ENG1" (liga), "C:UCL" (continental),
## "W:CWC" (Mundial), "S:SPE" (estadual), "D:FAC" (copa nacional ou da liga), "U:CSH" (supercopa),
## "P:ENG2" (acesso), "Y:ENG1" (sub-20).

const STYLE_CUP := 0 # taça clássica de duas alças
const STYLE_CHALICE := 1 # cálice alto com tampa
const STYLE_PLATE := 2 # salva (prato) em pé
const STYLE_GLOBE := 3 # globo sobre colunas
const STYLE_STAR := 4 # obelisco com estrela
const STYLE_EARS := 5 # "orelhuda" das grandes copas
const STYLE_PLAQUE := 6 # placa (acesso, base)
## Formatos sorteáveis para ligas (o globo fica só para o Mundial).
const LEAGUE_STYLES: Array[int] = [STYLE_CUP, STYLE_CHALICE, STYLE_PLATE, STYLE_STAR, STYLE_EARS]

const GOLD: Array[Color] = [Color("#E2B33C"), Color("#FFE391"), Color("#9C7416")]
const SILVER: Array[Color] = [Color("#C5CBD3"), Color("#F4F6F9"), Color("#7F8791")]
const BRONZE: Array[Color] = [Color("#C27A3E"), Color("#EDB07A"), Color("#7E4920")]
const WOOD := Color("#3B2A1E")
const WOOD_LIGHT := Color("#5A4130")
const CONFED_COLORS := {
	"UEFA": ["#1B3A8C", "#FFFFFF"], "CONMEBOL": ["#0B6E4F", "#F2C230"], "CONCACAF": ["#B22234", "#FFFFFF"],
	"CAF": ["#128A3E", "#F2C230"], "AFC": ["#1F6FB2", "#FFFFFF"], "FIFA": ["#1C2A4A", "#E2B33C"],
}

@export var key: String = "L:ENG1":
	set(v):
		key = v
		_resolve()
		queue_redraw()

var _style := STYLE_CUP
var _metal: Array[Color] = GOLD
var _ribbon: Array[Color] = [Color("#1B3A8C"), Color("#FFFFFF")]


static func make(k: String, px: int, w: GameWorld = null) -> TrophyView:
	var v := TrophyView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.key = k
	v.tooltip_text = trophy_name(k, w)
	return v


## Nome do troféu ("Taça da Liga Espanhola", "Liga dos Campeões"...).
static func trophy_name(k: String, w: GameWorld = null) -> String:
	var kind := k.substr(0, 2)
	var id := k.substr(2)
	match kind:
		"W:", "C:", "S:", "D:", "U:":
			return CupManager.cup_name(id)
		"L:":
			var n: String = w.league_name(id) if w != null else String(DatabaseManager.league_cfg(id).get("name", id))
			return "Taça " + n
		"P:":
			var n2 := String(DatabaseManager.league_cfg(id).get("short", id))
			return "Acesso · " + n2
		"Y:":
			return "Liga sub-20 · " + String(DatabaseManager.league_cfg(id).get("short", id))
	return k


func _resolve() -> void:
	var kind := key.substr(0, 2)
	var id := key.substr(2)
	var h := absi(hash(id))
	match kind:
		"W:":
			_style = STYLE_GLOBE
			_metal = GOLD
			_ribbon = _colors(CONFED_COLORS["FIFA"])
		"C:":
			var confed := String(CupManager.cfg(id).get("confed", "UEFA"))
			_style = STYLE_EARS if h % 2 == 0 else STYLE_CHALICE
			_metal = GOLD
			_ribbon = _colors(CONFED_COLORS.get(confed, ["#1C2A4A", "#E2B33C"]))
		"S:", "D:", "U:":
			var cc := CupManager.cfg(id)
			var kind_c := String(cc.get("kind", ""))
			if kind_c == "super":
				_style = STYLE_PLATE
				_metal = SILVER
			elif kind_c == "league_cup":
				_style = STYLE_CHALICE if h % 2 == 0 else STYLE_CUP
				_metal = SILVER
			else:
				_style = STYLE_CUP if kind_c == "national" else [STYLE_CUP, STYLE_CHALICE, STYLE_STAR][h % 3]
				_metal = GOLD if kind_c == "national" else SILVER
			var cols: Array = cc.get("colors", [])
			_ribbon = _colors(cols) if cols.size() >= 2 else _nation_colors(String(cc.get("nation", "")))
		"P:", "Y:":
			_style = STYLE_PLAQUE
			_metal = SILVER if kind == "P:" else BRONZE
			_ribbon = _nation_colors(String(DatabaseManager.league_cfg(id).get("nation", "")))
		_:
			var cfg := DatabaseManager.league_cfg(id)
			var tier := int(cfg.get("tier", 1))
			_style = int(cfg.get("trophy", LEAGUE_STYLES[h % LEAGUE_STYLES.size()]))
			_metal = GOLD if tier <= 1 else (SILVER if tier == 2 else BRONZE)
			_ribbon = _nation_colors(String(cfg.get("nation", "")))


static func _colors(arr: Array) -> Array[Color]:
	var out: Array[Color] = []
	for c in arr:
		out.append(Color(String(c)))
	return out


static func _nation_colors(code: String) -> Array[Color]:
	var fl: Dictionary = DatabaseManager.nation(code).get("flag", {}) if code != "" else {}
	var cs: Array = fl.get("c", [])
	var out: Array[Color] = []
	for c in cs:
		out.append(Color(String(c)))
	if out.is_empty():
		out = [Color("#1B3A8C"), Color("#FFFFFF")]
	# Evita duas faixas brancas seguidas: a fita precisa aparecer sobre a madeira.
	if out.size() == 1:
		out.append(Color.WHITE if out[0].get_luminance() < 0.6 else Color("#1C2A4A"))
	return out


func _draw() -> void:
	var s := minf(size.x, size.y)
	if s <= 4.0:
		return
	var o := Vector2((size.x - s) * 0.5, (size.y - s) * 0.5)
	_plinth(s, o)
	match _style:
		STYLE_CUP:
			_cup(s, o, 0.22, 0.10)
		STYLE_EARS:
			_cup(s, o, 0.2, 0.17)
		STYLE_CHALICE:
			_chalice(s, o)
		STYLE_PLATE:
			_plate(s, o)
		STYLE_GLOBE:
			_globe(s, o)
		STYLE_STAR:
			_star(s, o)
		STYLE_PLAQUE:
			_plaque(s, o)


func _p(s: float, o: Vector2, x: float, y: float) -> Vector2:
	return o + Vector2(x, y) * s


func _rect(s: float, o: Vector2, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	draw_rect(Rect2(_p(s, o, x0, y0), Vector2(x1 - x0, y1 - y0) * s), c)


func _poly(s: float, o: Vector2, pts: Array, c: Color) -> void:
	var arr := PackedVector2Array()
	for q in pts:
		arr.append(_p(s, o, q[0], q[1]))
	draw_colored_polygon(arr, c)


## Base de madeira com a fita nas cores do país.
func _plinth(s: float, o: Vector2) -> void:
	draw_rect(Rect2(_p(s, o, 0.27, 0.92), Vector2(0.46, 0.03) * s), Color(0, 0, 0, 0.22))
	_poly(s, o, [[0.3, 0.74], [0.7, 0.74], [0.73, 0.92], [0.27, 0.92]], WOOD)
	_rect(s, o, 0.3, 0.74, 0.7, 0.765, WOOD_LIGHT)
	var n := _ribbon.size()
	var w := 0.4 / n
	for i in n:
		_rect(s, o, 0.3 + i * w, 0.8, 0.3 + (i + 1) * w, 0.855, _ribbon[i])
	# Plaquinha de metal
	_rect(s, o, 0.43, 0.87, 0.57, 0.9, _metal[1])


## Pé e haste comuns às taças.
func _foot(s: float, o: Vector2, top: float) -> void:
	_rect(s, o, 0.465, top, 0.535, 0.66, _metal[2])
	_rect(s, o, 0.47, top, 0.49, 0.66, _metal[0])
	_poly(s, o, [[0.44, 0.62], [0.56, 0.62], [0.54, 0.6], [0.46, 0.6]], _metal[0])
	_poly(s, o, [[0.36, 0.74], [0.64, 0.74], [0.6, 0.66], [0.4, 0.66]], _metal[0])
	_poly(s, o, [[0.36, 0.74], [0.42, 0.74], [0.44, 0.66], [0.4, 0.66]], _metal[1])


func _bowl(s: float, o: Vector2, cx: float, top: float, rx: float, ry: float) -> void:
	var pts := PackedVector2Array()
	var hl := PackedVector2Array()
	for i in 21:
		var a := PI * i / 20.0
		pts.append(_p(s, o, cx + rx * cos(a), top + ry * sin(a)))
	draw_colored_polygon(pts, _metal[0])
	# Sombra do lado direito e brilho do lado esquerdo
	for i in 11:
		var a := PI * i / 20.0
		hl.append(_p(s, o, cx + rx * cos(a), top + ry * sin(a)))
	hl.append(_p(s, o, cx + rx * 0.35, top))
	draw_colored_polygon(hl, _metal[2].lerp(_metal[0], 0.45))
	var shine := PackedVector2Array()
	for i in 9:
		var a := PI * (0.62 + i * 0.035)
		shine.append(_p(s, o, cx + rx * 0.78 * cos(a), top + ry * 0.85 * sin(a)))
	for i in range(8, -1, -1):
		var a := PI * (0.62 + i * 0.035)
		shine.append(_p(s, o, cx + rx * 0.6 * cos(a), top + ry * 0.6 * sin(a)))
	draw_colored_polygon(shine, _metal[1])
	# Borda
	_rect(s, o, cx - rx - 0.015, top - 0.015, cx + rx + 0.015, top + 0.02, _metal[1])


func _cup(s: float, o: Vector2, rx: float, ear: float) -> void:
	_foot(s, o, 0.44)
	var top := 0.12
	var w := maxf(2.0, s * 0.035)
	# Alças
	draw_arc(_p(s, o, 0.5 - rx - ear * 0.35, top + 0.13), ear * s, PI * 0.5, PI * 1.5, 18, _metal[2], w, true)
	draw_arc(_p(s, o, 0.5 + rx + ear * 0.35, top + 0.13), ear * s, -PI * 0.5, PI * 0.5, 18, _metal[2], w, true)
	_bowl(s, o, 0.5, top, rx, 0.33)


func _chalice(s: float, o: Vector2) -> void:
	_foot(s, o, 0.42)
	_bowl(s, o, 0.5, 0.18, 0.15, 0.27)
	# Tampa com pináculo
	_poly(s, o, [[0.34, 0.165], [0.66, 0.165], [0.56, 0.1], [0.44, 0.1]], _metal[0])
	_poly(s, o, [[0.34, 0.165], [0.42, 0.165], [0.47, 0.1], [0.44, 0.1]], _metal[1])
	draw_circle(_p(s, o, 0.5, 0.07), 0.04 * s, _metal[0])
	draw_circle(_p(s, o, 0.49, 0.06), 0.015 * s, _metal[1])


func _plate(s: float, o: Vector2) -> void:
	_foot(s, o, 0.5)
	var c := _p(s, o, 0.5, 0.33)
	draw_circle(c, 0.28 * s, _metal[2])
	draw_circle(c, 0.26 * s, _metal[0])
	draw_circle(c, 0.19 * s, _metal[1].lerp(_metal[0], 0.35))
	draw_arc(c, 0.225 * s, 0.0, TAU, 40, _metal[2], maxf(1.0, s * 0.012), true)
	_star_poly(s, o, 0.5, 0.33, 0.1, _metal[0])
	draw_arc(c, 0.24 * s, PI * 1.05, PI * 1.45, 12, _metal[1], maxf(1.0, s * 0.02), true)


func _globe(s: float, o: Vector2) -> void:
	# Colunas espiraladas segurando o globo
	var w := maxf(2.0, s * 0.03)
	for x in [0.4, 0.5, 0.6]:
		draw_line(_p(s, o, x, 0.64), _p(s, o, 0.5 + (x - 0.5) * 1.7, 0.36), _metal[2] if x != 0.4 else _metal[0], w, true)
	_poly(s, o, [[0.36, 0.74], [0.64, 0.74], [0.6, 0.63], [0.4, 0.63]], _metal[0])
	_poly(s, o, [[0.36, 0.74], [0.42, 0.74], [0.44, 0.63], [0.4, 0.63]], _metal[1])
	var c := _p(s, o, 0.5, 0.27)
	var r := 0.18 * s
	draw_circle(c, r, _metal[0])
	draw_circle(c + Vector2(-0.05, -0.05) * s, r * 0.45, _metal[1].lerp(_metal[0], 0.3))
	var lw := maxf(1.0, s * 0.01)
	draw_arc(c, r, 0.0, TAU, 36, _metal[2], lw, true)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), _metal[2], lw, true)
	for k in [0.45, 0.8]:
		var pts := PackedVector2Array()
		for i in 25:
			var a := -PI * 0.5 + PI * i / 24.0
			pts.append(c + Vector2(cos(a) * r * k, sin(a) * r))
		draw_polyline(pts, _metal[2], lw, true)
		var pts2 := PackedVector2Array()
		for p in pts:
			pts2.append(Vector2(2.0 * c.x - p.x, p.y))
		draw_polyline(pts2, _metal[2], lw, true)


func _star(s: float, o: Vector2) -> void:
	_poly(s, o, [[0.43, 0.66], [0.57, 0.66], [0.535, 0.3], [0.465, 0.3]], _metal[0])
	_poly(s, o, [[0.43, 0.66], [0.47, 0.66], [0.485, 0.3], [0.465, 0.3]], _metal[1])
	_poly(s, o, [[0.53, 0.66], [0.57, 0.66], [0.535, 0.3], [0.52, 0.3]], _metal[2])
	_poly(s, o, [[0.36, 0.74], [0.64, 0.74], [0.6, 0.66], [0.4, 0.66]], _metal[0])
	_rect(s, o, 0.44, 0.44, 0.56, 0.47, _ribbon[0])
	_star_poly(s, o, 0.5, 0.19, 0.16, _metal[2])
	_star_poly(s, o, 0.5, 0.19, 0.135, _metal[0])
	_star_poly(s, o, 0.49, 0.18, 0.05, _metal[1])


func _plaque(s: float, o: Vector2) -> void:
	_poly(s, o, [[0.3, 0.2], [0.7, 0.2], [0.7, 0.62], [0.5, 0.72], [0.3, 0.62]], _metal[2])
	_poly(s, o, [[0.33, 0.23], [0.67, 0.23], [0.67, 0.6], [0.5, 0.69], [0.33, 0.6]], _metal[0])
	_poly(s, o, [[0.33, 0.23], [0.4, 0.23], [0.4, 0.64], [0.33, 0.6]], _metal[1])
	_star_poly(s, o, 0.5, 0.42, 0.1, _metal[2])
	_rect(s, o, 0.3, 0.14, 0.7, 0.2, _ribbon[0])
	if _ribbon.size() > 1:
		_rect(s, o, 0.43, 0.14, 0.57, 0.2, _ribbon[1])


func _star_poly(s: float, o: Vector2, cx: float, cy: float, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + PI * i / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(_p(s, o, cx + cos(a) * rr, cy + sin(a) * rr))
	draw_colored_polygon(pts, c)


## Sala de troféus de um clube: um troféu por competição vencida, com a contagem e o último ano.
static func cabinet(w: GameWorld, club: Club, px: int = 76) -> Control:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override(&"h_separation", 10)
	flow.add_theme_constant_override(&"v_separation", 10)
	var keys: Array = club.titles.keys()
	keys.sort_custom(func(a, b): return _rank(String(a)) < _rank(String(b)) if _rank(String(a)) != _rank(String(b)) else String(a) < String(b))
	for k in keys:
		var n := club.title_count(String(k))
		if n <= 0:
			continue
		var tile := VBoxContainer.new()
		tile.custom_minimum_size.x = px + 44
		tile.add_theme_constant_override(&"separation", 2)
		var tv := make(String(k), px, w)
		tv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.add_child(tv)
		var cnt := _label("%d×" % n, "H3")
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.add_theme_color_override(&"font_color", UIColors.ACCENT if String(k).substr(0, 2) != "P:" else UIColors.GREEN)
		tile.add_child(cnt)
		var nm := _label(_short(w, String(k)), "Small", true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tile.add_child(nm)
		flow.add_child(tile)
	if flow.get_child_count() == 0:
		return _label("A estante ainda está vazia. O primeiro troféu vai ficar aqui.", "Muted", true)
	return flow


static func _rank(k: String) -> int:
	match k.substr(0, 2):
		"W:":
			return 0
		"C:":
			return 1
		"L:":
			return 2 + int(DatabaseManager.league_cfg(k.substr(2)).get("tier", 1))
		"D:":
			return 8 if String(CupManager.cfg(k.substr(2)).get("kind", "")) == "national" else 10
		"S:":
			return 12
		"U:":
			return 14
		"P:":
			return 20
	return 30


static func _short(w: GameWorld, k: String) -> String:
	var id := k.substr(2)
	match k.substr(0, 2):
		"W:", "C:", "S:", "D:", "U:":
			return CupManager.cup_short(id)
		"L:":
			return w.league_short(id) if w != null else id
		"P:":
			return "Acesso " + (w.league_short(id) if w != null else id)
		"Y:":
			return "Sub-20"
	return k


## Rótulo simples (sem depender do UIKit, que puxa autoloads: o componente roda nos testes).
static func _label(text: String, variation: String = "", wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
