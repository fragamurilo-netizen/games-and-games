class_name SigningPhoto
extends Control
## Foto de apresentação de reforço: o jogador na frente do painel de patrocínio do clube novo,
## vestindo o uniforme e segurando a camisa de costas com o nome e o número dele. Serve de
## imagem das notícias de contratação e é o palco da animação das contratações importantes.
## `compact` desliga os flashes (miniatura nas listas).

var compact := false
## 0 = camisa abaixo da foto, 1 = camisa erguida no peito (a animação mexe nisso).
var lift := 1.0:
	set(v):
		lift = v
		_place()
## Faixa "OFICIAL" no canto.
var show_tag := true

var _backdrop: PressRoomView
var _portrait: PortraitView
var _shirt: KitView
var _hands: Control
var _desk: Control
var _skin := Color("#C68E68")
var _c1 := Color("#1B3A8C")
var _c2 := Color("#FFFFFF")
var _tag := "OFICIAL"


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Monta a foto. year = ano da assinatura (idade do rosto na época).
func setup(w: GameWorld, p: Player, club: Club, number: int, year: int = -1) -> void:
	if year < 0:
		year = w.year
	_c1 = Color(club.color1)
	_c2 = Color(club.color2)
	_tag = "EMPRESTADO" if not p.loan.is_empty() and p.club_id == club.id else "OFICIAL"
	_backdrop = PressRoomView.new()
	_backdrop.compact = compact
	_backdrop.backdrop_only = true
	_backdrop.setup(w, club)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_portrait = PortraitView.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.cutout = true
	_portrait.set_player(p, club, year)
	add_child(_portrait)
	_desk = Control.new()
	_desk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desk.draw.connect(_draw_desk)
	add_child(_desk)
	var goalkeeper := p.position == Pos.GK
	_shirt = UIKit.shirt_back(club, maxi(1, number), 64, false, goalkeeper)
	_shirt.back_name = p.last_name if p.last_name != "" else p.short_name()
	_shirt.size_flags_vertical = Control.SIZE_FILL
	add_child(_shirt)
	var f := FaceGen.features(p.face_seed, p.eth, p.age(year), p.look)
	_skin = f.get("skin", _skin)
	_hands = Control.new()
	_hands.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hands.draw.connect(_draw_hands)
	add_child(_hands)
	resized.connect(_place)
	_place()


## Versão a partir da mídia guardada na notícia ({player, club, n}). Nulo se o jogador sumiu.
static func from_media(w: GameWorld, m: Dictionary, year: int, is_compact: bool) -> SigningPhoto:
	var p := w.player(int(m.get("player", -1)))
	var c := w.club(int(m.get("club", -1)))
	if p == null or c == null:
		return null
	var ph := SigningPhoto.new()
	ph.compact = is_compact
	ph.setup(w, p, c, int(m.get("n", p.shirt)), year)
	return ph


func _place() -> void:
	if _portrait == null:
		return
	var w := size.x
	var h := size.y
	if w < 4.0 or h < 4.0:
		return
	# Busto grande: rosto no terço de cima, ombros saindo pelos lados e pela borda de baixo.
	var ps := h * 0.95
	_portrait.size = Vector2(ps, ps)
	_portrait.position = Vector2(w * 0.5 - ps * 0.5, h * 0.3 - ps * 0.4)
	# Camisa erguida na altura do peito, abaixo do queixo.
	var ss := h * 0.46
	_shirt.size = Vector2(ss, ss)
	var y_up := h * 0.53
	var y_down := h * 1.05
	_shirt.position = Vector2(w * 0.5 - ss * 0.5, lerpf(y_down, y_up, clampf(lift, 0.0, 1.0)))
	_desk.position = Vector2.ZERO
	_desk.size = size
	_desk.queue_redraw()
	_hands.position = Vector2.ZERO
	_hands.size = size
	_hands.queue_redraw()
	queue_redraw()


## Mesa da assinatura na frente do busto: tampo, toalha nas cores do clube, o contrato e a caneta.
func _draw_desk() -> void:
	var w := size.x
	var h := size.y
	var top := h * 0.84
	_desk.draw_rect(Rect2(0, top - h * 0.012, w, h * 0.02), Color("#D9DCE0"))
	_desk.draw_rect(Rect2(0, top, w, h - top), _c1.darkened(0.2))
	_desk.draw_rect(Rect2(0, top, w, h * 0.012), _c2.lerp(_c1, 0.3))
	for i in 5:
		_desk.draw_rect(Rect2(0, top + (h - top) * (0.3 + i * 0.14), w, (h - top) * 0.14), Color(0, 0, 0, 0.04 * i))
	# Contrato e caneta à direita.
	var paper := PackedVector2Array([Vector2(w * 0.66, top - h * 0.005), Vector2(w * 0.84, top - h * 0.005), Vector2(w * 0.86, top - h * 0.03), Vector2(w * 0.68, top - h * 0.03)])
	_desk.draw_colored_polygon(paper, Color("#F4F4F2"))
	_desk.draw_line(Vector2(w * 0.72, top - h * 0.018), Vector2(w * 0.8, top - h * 0.018), Color(0.2, 0.2, 0.3, 0.6), maxf(1.0, h * 0.003), true)
	_desk.draw_line(Vector2(w * 0.6, top - h * 0.01), Vector2(w * 0.66, top - h * 0.035), Color("#1B1B1F"), maxf(2.0, h * 0.008), true)
	_desk.draw_line(Vector2(w * 0.655, top - h * 0.033), Vector2(w * 0.662, top - h * 0.036), Color("#D4AF37"), maxf(2.0, h * 0.008), true)


## Mãos segurando a camisa pelos ombros: a mão fica atrás do tecido e os quatro dedos dobram
## por cima da costura do ombro, com nós, unhas, dobras e sombra no pano. Depois, a faixa "OFICIAL".
func _draw_hands() -> void:
	var r := Rect2(_shirt.position, _shirt.size)
	var s := r.size.x
	for si in 2:
		var side := -1.0 if si == 0 else 1.0
		# Costura do ombro da camisa (KitView): sobe da manga até a gola.
		var c := r.position + Vector2(0.5 + side * 0.225, 0.088) * s
		_draw_hand(c, s, side * 0.3, side)
	_draw_tag()


func _draw_hand(c: Vector2, s: float, rot: float, side: float) -> void:
	var fw := s * 0.042 # largura de um dedo
	var fl := s * 0.105 # quanto o dedo desce na frente da camisa
	var skin := _skin
	var shade := skin.darkened(0.3)
	var lw := maxf(1.0, s * 0.004)
	_hands.draw_set_transform(c, rot, Vector2.ONE)
	# Sombra dos dedos no tecido.
	_hands.draw_colored_polygon(_capsule(Vector2(fw * 0.35, fl * 0.12), fw * 4.3, fl * 1.05, fw * 0.9), Color(0, 0, 0, 0.22))
	# Dorso da mão aparecendo atrás da costura (só a curva dos nós).
	var back := _capsule(Vector2(0, -fl * 0.2), fw * 4.4, fl * 0.55, fw * 1.1)
	_hands.draw_polygon(back, _shaded(back, skin.darkened(0.12), 0.0, fw * 2.2))
	# Quatro dedos: indicador e médio maiores, anelar e mínimo mais curtos.
	var lens := [0.92, 1.0, 0.94, 0.8]
	var widths := [1.0, 1.04, 0.98, 0.86]
	for k in 4:
		var i := k if side > 0.0 else 3 - k
		var fx := (float(k) - 1.5) * fw * 0.98
		var w := fw * float(widths[i])
		var l := fl * float(lens[i])
		var top := -fl * 0.12
		var poly := _capsule(Vector2(fx, top + l * 0.5), w, l, w * 0.5)
		_hands.draw_polygon(poly, _shaded(poly, skin, fx - w * 0.5, w))
		var outline := poly.duplicate()
		outline.append(poly[0])
		_hands.draw_polyline(outline, shade, lw, true)
		# Dobras das falanges.
		for j in 2:
			var yy := top + l * (0.34 + j * 0.28)
			_hands.draw_line(Vector2(fx - w * 0.3, yy), Vector2(fx + w * 0.25, yy + w * 0.05), Color(shade, 0.7), lw * 0.8, true)
		# Unha na ponta.
		var tip := Vector2(fx, top + l - w * 0.42)
		_hands.draw_set_transform(c + tip.rotated(rot), rot, Vector2(1.0, 1.25))
		_hands.draw_circle(Vector2.ZERO, w * 0.28, skin.lightened(0.35).lerp(Color("#F2D7CF"), 0.35), true, -1.0, true)
		_hands.draw_set_transform(c, rot, Vector2.ONE)
		# Brilho do nó.
		_hands.draw_circle(Vector2(fx - w * 0.12, top + w * 0.05), w * 0.22, Color(1, 1, 1, 0.12), true, -1.0, true)
	# Polegar atrás do pano, só a ponta saindo pela lateral de fora.
	var th := _capsule(Vector2(side * fw * 2.35, fl * 0.05), fw * 0.95, fl * 0.5, fw * 0.45)
	_hands.draw_polygon(th, _shaded(th, skin.darkened(0.18), side * fw * 1.9, fw))
	_hands.draw_set_transform_matrix(Transform2D.IDENTITY)


## Retângulo de cantos redondos centrado em `c` (w × h, raio rr), como polígono.
static func _capsule(c: Vector2, w: float, h: float, rr: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	rr = minf(rr, minf(w, h) * 0.5)
	var hw := w * 0.5 - rr
	var hh := h * 0.5 - rr
	var centers := [Vector2(hw, hh), Vector2(-hw, hh), Vector2(-hw, -hh), Vector2(hw, -hh)]
	for q in 4:
		for k in 5:
			var a := PI * 0.5 * q + PI * 0.5 * float(k) / 4.0
			out.append(c + (centers[q] as Vector2) + Vector2(cos(a), sin(a)) * rr)
	return out


## Cor por vértice: luz vindo da esquerda (x0 = borda esquerda do dedo, w = largura).
static func _shaded(poly: PackedVector2Array, base: Color, x0: float, w: float) -> PackedColorArray:
	var cols := PackedColorArray()
	for p in poly:
		var t := clampf((p.x - x0) / maxf(w, 0.001), 0.0, 1.0)
		cols.append(base.lightened(0.14 * (1.0 - t)).darkened(0.22 * t * t))
	return cols


func _draw_tag() -> void:
	if not show_tag:
		return
	var font := get_theme_font(&"font", &"Stat")
	var fs := int(clampf(size.y * 0.055, 10.0, 24.0))
	var tw := font.get_string_size(_tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(Vector2(size.y * 0.04, size.y * 0.04), Vector2(tw + fs * 1.2, fs * 1.6))
	var tc := _c2 if absf(_c2.get_luminance() - _c1.get_luminance()) > 0.3 else Color.WHITE
	_hands.draw_rect(box, _c1)
	_hands.draw_rect(Rect2(box.position, Vector2(fs * 0.22, box.size.y)), tc)
	_hands.draw_string(font, Vector2(box.position.x + fs * 0.7, box.get_center().y + fs * 0.36), _tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tc)
