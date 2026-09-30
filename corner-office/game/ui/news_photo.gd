class_name NewsPhoto
extends Control
## Foto de notícia/post (Game Design Bible §10, §16). Não é um gerador novo:
## rostos vêm do FighterPortrait (Fight Studio, PR de rankings) quando esse
## componente existe no projeto; cidades vêm de res://assets/cities/<cidade>.png
## quando a ilustração existir. Sem eles, a foto é uma composição editorial
## (faixas nas cores do corner + iniciais) só com Tokens.
## Toque sem arrastar emite `opened` (a lista rola normalmente).

signal opened

const CITY_DIR := "res://assets/cities"
const TAP_SLOP := 14.0

var world: WorldState
var item: NewsItem
var fighters: Array = []
var event: FightEvent
var _city: Texture2D
var _portraits := false
var _press := Vector2.INF


static func make(w: WorldState, n: NewsItem, box: Vector2) -> NewsPhoto:
	var p := NewsPhoto.new()
	p.world = w
	p.item = n
	p.custom_minimum_size = box
	p.clip_contents = true
	for id: String in n.entity_ids:
		if w.fighters.has(id) and p.fighters.size() < 2:
			p.fighters.append(w.fighters[id])
		elif w.events.has(id) and p.event == null:
			p.event = w.events[id]
	if n.channel == "social" and w.fighters.has(n.author_id):
		p.fighters.erase(w.fighters[n.author_id])
		p.fighters.push_front(w.fighters[n.author_id])
	return p


## Legenda de rodapé: quem está na foto, ou a noite/cidade.
func caption() -> String:
	var names: Array = fighters.map(func(f: Fighter): return "%s (%s)" % [f.display_name(), f.record_string()])
	if not names.is_empty():
		return " × ".join(names)
	if event:
		return "%s · %s" % [event.name, event.city]
	return Media.outlet(item.outlet_id).get("name", "")


static func city_slug(city: String) -> String:
	return Media._slug(city)


static func _portrait_script() -> Script:
	for c: Dictionary in ProjectSettings.get_global_class_list():
		if c["class"] == &"FighterPortrait":
			return load(c.path)
	return null


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_PASS
	var city := event.city if event else ""
	if city.is_empty() and not fighters.is_empty():
		city = fighters[0].city
	var path := "%s/%s.png" % [CITY_DIR, city_slug(city)]
	if not city.is_empty() and ResourceLoader.exists(path):
		_city = load(path)
	resized.connect(_layout)
	var script := _portrait_script()
	if script and not fighters.is_empty():
		_portraits = true
		var accents := [Tokens.FIGHT_RED, Tokens.STEEL]
		for i in fighters.size():
			var portrait: Control = script.make(fighters[i], 10.0, accents[i] if fighters.size() == 2 else Tokens.STEEL)
			portrait.custom_minimum_size = Vector2.ZERO
			add_child(portrait)
	_layout()


func _layout() -> void:
	if not _portraits:
		queue_redraw()
		return
	var h := size.y
	var w := minf(h * 0.8, size.x / maxf(1, get_child_count()))
	var n := get_child_count()
	for i in n:
		var c: Control = get_child(i)
		var x := (size.x - w * n) / 2.0 + w * i if n == 1 else (0.0 if i == 0 else size.x - w)
		c.position = Vector2(x, 0)
		c.size = Vector2(w, h)
	queue_redraw()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = e.position
		elif _press != Vector2.INF and e.position.distance_to(_press) < TAP_SLOP:
			_press = Vector2.INF
			opened.emit()
			accept_event()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.SURFACE)
	if _city:
		var t := _city.get_size()
		var s := maxf(w / t.x, h / t.y)
		var src := Vector2(w, h) / s
		draw_texture_rect_region(_city, Rect2(Vector2.ZERO, size), Rect2((t - src) / 2.0, src))
		var veil := Tokens.CANVAS
		veil.a = 0.35
		draw_rect(Rect2(Vector2.ZERO, size), veil)
	if fighters.size() == 2:
		for i in 2:
			var c: Color = [Tokens.FIGHT_RED, Tokens.STEEL][i]
			c.a = 0.75
			var x0 := 0.0 if i == 0 else w * 0.55
			draw_colored_polygon(PackedVector2Array([Vector2(x0, h * 0.55), Vector2(x0 + w * 0.45, h * 0.35), Vector2(x0 + w * 0.45, h), Vector2(x0, h)]), c)
	else:
		var c := Tokens.STEEL
		c.a = 0.8
		draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.62), Vector2(w, h * 0.34), Vector2(w, h), Vector2(0, h)]), c)
	var fs := int(clampf(h * 0.3, 18, 140))
	if not _portraits and not fighters.is_empty():
		for i in fighters.size():
			var f: Fighter = fighters[i]
			var text := (f.first_name.left(1) + f.last_name.left(1)).to_upper()
			var cx := w * (0.5 if fighters.size() == 1 else (0.25 if i == 0 else 0.75))
			var tw := Tokens.DISPLAY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(Tokens.DISPLAY_FONT, Vector2(cx - tw / 2.0, h * 0.5 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Tokens.INK)
	elif fighters.is_empty():
		var title := (event.name if event else str(Media.outlet(item.outlet_id).get("name", ""))).to_upper()
		var sub := (event.city if event else "").to_upper()
		var ts := int(clampf(h * 0.16, 16, 72))
		draw_string(Tokens.DISPLAY_FONT, Vector2(Tokens.SPACE_M, h * 0.5), title, HORIZONTAL_ALIGNMENT_LEFT, w - Tokens.SPACE_L, ts, Tokens.INK)
		if not sub.is_empty():
			draw_string(Tokens.BODY_FONT, Vector2(Tokens.SPACE_M, h * 0.5 + ts), sub, HORIZONTAL_ALIGNMENT_LEFT, w - Tokens.SPACE_L, int(ts * 0.55), Tokens.MUTED)
	if fighters.size() == 2 and h >= 120:
		var vs := int(h * 0.14)
		var vw := Tokens.DISPLAY_FONT.get_string_size("×", HORIZONTAL_ALIGNMENT_LEFT, -1, vs).x
		draw_string(Tokens.DISPLAY_FONT, Vector2((w - vw) / 2.0, h * 0.55), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, vs, Tokens.INK)
	draw_rect(Rect2(0, h - 4, w, 4), Tokens.FIGHT_RED if item.importance >= 3 else Tokens.STEEL)
