class_name AwardCeremony
extends Control
## Cerimônia de premiação do fim de temporada: palco escuro, holofote, raios girando, o troféu
## descendo, o rosto do premiado surgindo e confete no anúncio. Um prêmio por vez, do menor para
## o maior (a Bola de Ouro fecha a noite). Toque avança; "Pular" encerra.
##
## Cada item: {kind ("ballon"|"boot"|"young"|"mvp"|"scorer"|"club"), title, sub, id, name, club, v}

signal finished

const STAGE := 4.2 # segundos por prêmio

var world: GameWorld = null
var items: Array = []
var _i := 0
var _t := 0.0
var _confetti: Array = []
var _rng := RandomNumberGenerator.new()
var _portrait: Control = null
var _crest: Control = null
var _font: Font = null
var _font_bold: Font = null


static func build_items(w: GameWorld, summary: Dictionary) -> Array:
	var out: Array = []
	var aw: Dictionary = summary.get("awards", {})
	var league := w.league_name(w.user_league_id())
	var young: Dictionary = aw.get("young", {})
	if not young.is_empty():
		out.append({"kind": "young", "title": "REVELAÇÃO", "sub": league, "id": young.get("id", -1), "name": young.get("name", ""), "club": young.get("club", ""), "v": young.get("v", "")})
	var sc: Dictionary = aw.get("scorer", {})
	if not sc.is_empty():
		out.append({"kind": "scorer", "title": "ARTILHEIRO", "sub": league, "id": sc.get("id", -1), "name": sc.get("name", ""), "club": sc.get("club", ""), "v": sc.get("v", "")})
	var mvp: Dictionary = aw.get("mvp", {})
	if not mvp.is_empty():
		out.append({"kind": "mvp", "title": "CRAQUE DO CAMPEONATO", "sub": league, "id": mvp.get("id", -1), "name": mvp.get("name", ""), "club": mvp.get("club", ""), "v": mvp.get("v", "")})
	var co: Dictionary = summary.get("coach", {})
	if not co.is_empty():
		out.append({"kind": "coach", "title": "TREINADOR DA TEMPORADA", "sub": league, "id": -1, "name": co.get("n", ""), "club": co.get("cn", ""), "v": co.get("v", ""), "club_id": int(co.get("c", -1))})
	var gk: Dictionary = summary.get("gk_world", {})
	if not gk.is_empty():
		out.append({"kind": "gk", "title": "MELHOR GOLEIRO DO MUNDO", "sub": "Votação de jornalistas", "id": gk.get("id", -1), "name": gk.get("name", ""), "club": gk.get("club", ""), "v": "%d pontos" % int(gk.get("pts", 0))})
	var wy: Dictionary = summary.get("world_young", {})
	if not wy.is_empty():
		out.append({"kind": "young", "title": "REVELAÇÃO MUNDIAL", "sub": "Melhor jogador de até 21 anos", "id": wy.get("id", -1), "name": wy.get("name", ""), "club": wy.get("club", ""), "v": ""})
	var bt: Dictionary = summary.get("boot", {})
	if not bt.is_empty():
		out.append({"kind": "boot", "title": "CHUTEIRA DE OURO", "sub": "Maior artilheiro do mundo", "id": bt.get("id", -1), "name": bt.get("name", ""), "club": bt.get("club", ""), "v": "%d gols" % int(bt.get("goals", 0))})
	var bo: Dictionary = summary.get("ballon", {})
	if not bo.is_empty():
		out.append({"kind": "ballon", "title": "BOLA DE OURO", "sub": "Melhor jogador do mundo", "id": bo.get("id", -1), "name": bo.get("name", ""), "club": bo.get("club", ""), "v": "%d gols · %d pontos na votação" % [int(bo.get("goals", 0)), int(bo.get("pts", 0))]})
	return out


func start(w: GameWorld, list: Array) -> void:
	world = w
	items = list
	_font = get_theme_default_font()
	_font_bold = get_theme_font(&"font", &"Title") if has_theme_font(&"font", &"Title") else _font
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skip := UIKit.button("Pular", "GhostButton", func(): _end())
	skip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip.position = Vector2(-150, 40)
	skip.custom_minimum_size = Vector2(120, 56)
	add_child(skip)
	_show(0)


func _show(i: int) -> void:
	_i = i
	_t = 0.0
	if _i >= items.size():
		_end()
		return
	var it: Dictionary = items[_i]
	if _portrait != null:
		_portrait.queue_free()
	if _crest != null:
		_crest.queue_free()
	_portrait = null
	_crest = null
	var p := world.player(int(it.get("id", -1)))
	if p != null:
		var club: Club = world.club(p.club_id) if p.club_id >= 0 else null
		_portrait = UIKit.portrait(p, club, world.year, 220)
		add_child(_portrait)
		if club != null:
			_crest = UIKit.crest(club, 70)
			add_child(_crest)
	elif world.club(int(it.get("club_id", -1))) != null:
		# Treinador: o escudo do clube no lugar do rosto.
		_crest = UIKit.crest(world.club(int(it["club_id"])), 70)
		add_child(_crest)
	_rng.seed = hash([it.get("id", -1), _i])
	_confetti.clear()
	AudioManager.play("whistle", -10.0)
	set_process(true)


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if _t < 1.6:
			_t = 1.6 # vai direto ao anúncio
		else:
			_show(_i + 1)
		accept_event()


func _end() -> void:
	set_process(false)
	finished.emit()
	queue_free()


func _burst() -> void:
	var it: Dictionary = items[_i]
	var gold := String(it["kind"]) in ["ballon", "boot"]
	var palette := [UIColors.GOLD, Color.WHITE, UIColors.GOLD_DARK, UIColors.ACCENT] if gold else [UIColors.ACCENT, Color.WHITE, UIColors.BLUE, UIColors.GOLD]
	for k in (140 if gold else 80):
		var pos := Vector2(size.x * 0.5 + _rng.randf_range(-40, 40), size.y * 0.42)
		var ang := _rng.randf_range(-PI * 0.95, -PI * 0.05)
		var spd := _rng.randf_range(380, 900)
		_confetti.append([pos, Vector2(cos(ang), sin(ang)) * spd, _rng.randf() * TAU, _rng.randf_range(-8, 8), palette[k % palette.size()], Vector2(_rng.randf_range(8, 15), _rng.randf_range(12, 22))])
	AudioManager.play("title", -6.0)
	AudioManager.vibrate(120)


func _process(delta: float) -> void:
	var before := _t
	_t += delta
	if before < 1.6 and _t >= 1.6:
		_burst()
	for c in _confetti:
		var vel: Vector2 = c[1]
		vel.y += 700.0 * delta
		vel.x *= 0.99
		c[1] = vel
		c[0] = (c[0] as Vector2) + vel * delta
		c[2] = float(c[2]) + float(c[3]) * delta
	_layout_nodes()
	queue_redraw()
	if _t >= STAGE:
		_show(_i + 1)


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)


func _layout_nodes() -> void:
	var appear := _ease((_t - 1.4) / 0.6)
	if _portrait != null:
		var s := 220.0 * (0.6 + 0.4 * appear)
		_portrait.scale = Vector2.ONE * (s / 220.0)
		_portrait.position = Vector2(size.x * 0.5 - s * 0.5, size.y * 0.5 + 10.0)
		_portrait.modulate.a = appear
	if _crest != null and _portrait == null:
		_crest.scale = Vector2.ONE * 2.2
		_crest.position = Vector2(size.x * 0.5 - 77.0, size.y * 0.5 + 40.0)
		_crest.modulate.a = appear
	elif _crest != null:
		_crest.position = Vector2(size.x * 0.5 + 60.0, size.y * 0.5 + 170.0)
		_crest.modulate.a = appear


func _draw() -> void:
	if items.is_empty() or _i >= items.size():
		return
	var it: Dictionary = items[_i]
	var gold := String(it["kind"]) in ["ballon", "boot"]
	var accent := UIColors.GOLD if gold else UIColors.ACCENT
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.96))
	var center := Vector2(size.x * 0.5, size.y * 0.3)
	# Raios girando atrás do troféu
	var rays := 18
	var rot := _t * 0.25
	var ray_a := 0.06 + 0.06 * _ease(_t / 1.2)
	for k in rays:
		var a0 := rot + TAU * k / rays
		var a1 := a0 + TAU / rays * 0.45
		var r := size.y
		var col := accent
		col.a = ray_a
		draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * r, center + Vector2(cos(a1), sin(a1)) * r]), col)
	# Holofote
	for k in 10:
		var col := Color(1, 1, 0.9, 0.025)
		draw_circle(center, 60.0 + k * 26.0, col)
	# Troféu descendo
	var drop := _ease(_t / 1.2)
	var tc := Vector2(center.x, lerpf(-120.0, center.y, drop))
	_trophy(String(it["kind"]), tc, 70.0 + 8.0 * sin(_t * 3.0) * (1.0 if _t > 1.2 else 0.0))
	# Título e subtítulo
	var head_a := _ease((_t - 0.3) / 0.6)
	_text(String(it["title"]), Vector2(size.x * 0.5, size.y * 0.1), 44, Color(accent, head_a), true)
	_text(String(it["sub"]), Vector2(size.x * 0.5, size.y * 0.1 + 44), 22, Color(UIColors.MUTED, head_a), false)
	# Anúncio do vencedor
	var ann := _ease((_t - 1.6) / 0.5)
	if ann > 0.0:
		var y := size.y * 0.5 + 290.0
		_text(String(it["name"]), Vector2(size.x * 0.5, y + (1.0 - ann) * 30.0), 46, Color(Color.WHITE, ann), true)
		var line := String(it.get("club", ""))
		if String(it.get("v", "")) != "":
			line += " · " + String(it["v"])
		_text(line, Vector2(size.x * 0.5, y + 50.0), 24, Color(UIColors.MUTED, ann), false)
		_text("Toque para continuar", Vector2(size.x * 0.5, size.y - 60.0), 18, Color(UIColors.DIM, ann * (0.6 + 0.4 * sin(_t * 4.0))), false)
	# Progresso
	for k in items.size():
		var col := accent if k <= _i else UIColors.LINE
		draw_circle(Vector2(size.x * 0.5 + (k - (items.size() - 1) * 0.5) * 22.0, size.y - 110.0), 5.0, col)
	# Confete
	for c in _confetti:
		var pos: Vector2 = c[0]
		if pos.y > size.y + 40.0:
			continue
		var s: Vector2 = c[5]
		draw_set_transform(pos, float(c[2]), Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, s), c[4])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _text(t: String, center: Vector2, fs: int, col: Color, bold: bool) -> void:
	var f := _font_bold if bold else _font
	if f == null:
		return
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var maxw := size.x - 40.0
	if w > maxw:
		fs = int(fs * maxw / w)
		w = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(center.x - w * 0.5, center.y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Troféus desenhados: bola dourada, chuteira dourada ou taça com estrela.
func _trophy(kind: String, c: Vector2, r: float) -> void:
	var g1 := UIColors.GOLD
	var g2 := UIColors.GOLD_DARK
	match kind:
		"ballon":
			draw_circle(c, r, g2)
			draw_circle(c + Vector2(-r * 0.08, -r * 0.08), r * 0.9, g1)
			var hexes := [Vector2(0, 0), Vector2(0, -0.62), Vector2(0.58, -0.2), Vector2(0.36, 0.5), Vector2(-0.36, 0.5), Vector2(-0.58, -0.2)]
			for h in hexes:
				var pc := c + (h as Vector2) * r
				var pts := PackedVector2Array()
				for k in 5:
					var a := -PI * 0.5 + TAU * k / 5.0
					pts.append(pc + Vector2(cos(a), sin(a)) * r * 0.2)
				draw_colored_polygon(pts, g2)
			draw_circle(c + Vector2(-r * 0.4, -r * 0.45), r * 0.14, Color(1, 1, 1, 0.55))
			draw_rect(Rect2(c.x - r * 0.55, c.y + r * 0.95, r * 1.1, r * 0.35), g2)
		"boot":
			var pts := PackedVector2Array([c + Vector2(-r * 0.9, r * 0.35), c + Vector2(-r * 0.9, -r * 0.2), c + Vector2(-r * 0.35, -r * 0.2),
				c + Vector2(-r * 0.3, -r * 0.9), c + Vector2(r * 0.25, -r * 0.9), c + Vector2(r * 0.25, -r * 0.15),
				c + Vector2(r * 0.95, r * 0.05), c + Vector2(r, r * 0.35)])
			draw_colored_polygon(pts, g1)
			draw_polyline(pts + PackedVector2Array([pts[0]]), g2, 4.0)
			for k in 4:
				draw_circle(c + Vector2(-r * 0.7 + k * r * 0.5, r * 0.45), r * 0.08, g2)
			draw_rect(Rect2(c.x - r * 0.6, c.y + r * 0.7, r * 1.2, r * 0.3), g2)
		_:
			var cup := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.5, -r * 0.05),
				c + Vector2(r * 0.12, r * 0.25), c + Vector2(r * 0.12, r * 0.6), c + Vector2(-r * 0.12, r * 0.6), c + Vector2(-r * 0.12, r * 0.25),
				c + Vector2(-r * 0.5, -r * 0.05)])
			draw_colored_polygon(cup, g1 if kind == "mvp" else Color("#D9DEE6"))
			draw_arc(c + Vector2(-r * 0.72, -r * 0.45), r * 0.28, PI * 0.5, PI * 1.5, 16, g2, 5.0)
			draw_arc(c + Vector2(r * 0.72, -r * 0.45), r * 0.28, -PI * 0.5, PI * 0.5, 16, g2, 5.0)
			draw_rect(Rect2(c.x - r * 0.5, c.y + r * 0.6, r, r * 0.3), g2)
			var star := CrestView._star(c + Vector2(0, -r * 0.4), r * 0.26, r * 0.11, 5)
			draw_colored_polygon(star, Color.WHITE)
