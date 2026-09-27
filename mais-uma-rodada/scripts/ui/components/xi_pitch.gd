class_name XIPitch
extends Control
## Seleção (da rodada, do mês, do campeonato...) desenhada num campinho 1-4-3-3: rosto, nome,
## escudo do clube e nota de cada um; o craque ganha estrela dourada e os jogadores do seu time,
## a cor de destaque. Tocar numa ficha abre o perfil.
##
## ids chegam na ordem goleiro, 4 defensores, 3 meias e 3 atacantes (AwardManager.TEAM_SHAPE).

const LINES := [[0, 1, 0.9], [1, 5, 0.67], [5, 8, 0.42], [8, 11, 0.16]] # [início, fim, altura]

var world: GameWorld = null
var ids: Array = []
var ratings: Array = []
var best_id := -1
var _chips: Array = [] # [Control, x, y]


static func make(w: GameWorld, player_ids: Array, rts: Array = [], best: int = -1, height: int = 700) -> XIPitch:
	var v := XIPitch.new()
	v.world = w
	v.ids = player_ids
	v.ratings = rts
	v.best_id = best
	v.custom_minimum_size = Vector2(0, height)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return v


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_build()
	resized.connect(_layout)
	_layout()


## Lado do campo pela posição (esquerda 0 · centro 1 · direita 2) para ordenar cada linha.
static func _side(pos: int) -> int:
	if pos == Pos.LB or pos == Pos.LM or pos == Pos.LW:
		return 0
	if pos == Pos.RB or pos == Pos.RM or pos == Pos.RW:
		return 2
	return 1


func _build() -> void:
	if world == null or ids.size() != 11:
		return
	for ln in LINES:
		var group: Array = []
		for i in range(int(ln[0]), int(ln[1])):
			group.append(i)
		group.sort_custom(func(a: int, b: int):
			var pa := world.player(int(ids[a]))
			var pb := world.player(int(ids[b]))
			var sa := _side(pa.position) if pa != null else 1
			var sb := _side(pb.position) if pb != null else 1
			return sa < sb if sa != sb else a < b)
		for k in group.size():
			var i: int = group[k]
			var x := (k + 1.0) / (group.size() + 1.0)
			_chips.append([_chip(i), x, float(ln[2])])


func _chip(i: int) -> Control:
	var p := world.player(int(ids[i]))
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(150, 0)
	var club: Club = world.club(p.club_id) if p != null and p.club_id >= 0 else null
	var face_row := HBoxContainer.new()
	face_row.alignment = BoxContainer.ALIGNMENT_CENTER
	face_row.add_theme_constant_override(&"separation", -10)
	if p != null:
		face_row.add_child(UIKit.portrait(p, club, world.year, 70))
	if club != null:
		var cr := UIKit.crest(club, 30)
		cr.size_flags_vertical = Control.SIZE_SHRINK_END
		face_row.add_child(cr)
	v.add_child(face_row)
	var star := p != null and p.id == best_id
	var mine := p != null and p.club_id >= 0 and world.is_user_club(p.club_id)
	var name_txt := (("★ " if star else "") + p.short_name()) if p != null else "—"
	var nl := UIKit.pill(name_txt, UIColors.GOLD if star else (UIColors.ACCENT if mine else Color(0.05, 0.1, 0.08, 0.85)), 16)
	nl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(nl)
	if i < ratings.size() and float(ratings[i]) > 0.0:
		var rl := UIKit.label(Fmt.rating(float(ratings[i])), "Small")
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rl.add_theme_color_override(&"font_color", Color.WHITE)
		v.add_child(rl)
	add_child(v)
	UIKit._ignore_mouse(v)
	v.mouse_filter = Control.MOUSE_FILTER_STOP
	if p != null:
		var pid := p.id
		v.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and not e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				UIManager.push("player", {"id": pid}))
	return v


func _layout() -> void:
	for c in _chips:
		var ctrl: Control = c[0]
		var s := ctrl.get_combined_minimum_size()
		ctrl.size = s
		ctrl.position = Vector2(size.x * float(c[1]) - s.x * 0.5, size.y * float(c[2]) - s.y * 0.55)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, UIColors.PITCH_A)
	var bands := 8
	for i in bands:
		if i % 2 == 1:
			draw_rect(Rect2(0, size.y * i / bands, size.x, size.y / bands), UIColors.PITCH_B)
	var lc := UIColors.PITCH_LINE
	lc.a = 0.5
	var m := 12.0
	draw_rect(Rect2(m, m, size.x - m * 2, size.y - m * 2), lc, false, 2.0)
	# Meio-campo no topo (o time ataca para cima) e a grande área embaixo.
	draw_line(Vector2(m, m), Vector2(size.x - m, m), lc, 2.0)
	draw_arc(Vector2(size.x * 0.5, m), size.x * 0.13, 0, PI, 32, lc, 2.0)
	var bw := size.x * 0.56
	var bh := size.y * 0.16
	draw_rect(Rect2((size.x - bw) * 0.5, size.y - m - bh, bw, bh), lc, false, 2.0)
	var sw := size.x * 0.26
	var sh := size.y * 0.06
	draw_rect(Rect2((size.x - sw) * 0.5, size.y - m - sh, sw, sh), lc, false, 2.0)
	draw_arc(Vector2(size.x * 0.5, size.y - m - bh), size.x * 0.1, PI, TAU, 24, lc, 2.0)
