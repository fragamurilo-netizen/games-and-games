class_name OfficeView
extends Control
## Sede 2D viva (hub do jogo). Só REPRESENTA a simulação: posição, pose e
## balões vêm de StaffMember.activity/status e dos fatos do mundo. Movimento e
## micro-animações são cosméticos, com RNG visual próprio (não é o da liga).
## Um único nó desenha tudo; os atores são dicionários leves (sem lógica por
## personagem a cada frame além de interpolar posição).

signal person_pressed(staff_id: String)
signal hotspot_pressed(action: String, payload: Dictionary)

const SPEED := 110.0             # unidades de projeto por segundo
const FPS := 30.0

var day_fraction := 0.0          # relógio do dia (TimeController)
var selected_id := ""
var _actors := {}                # staff_id -> {pos, path, seat, mode, phase, alpha, emote, emote_until, leaving}
var _hotspots: Array = []        # [{rect (projeto), action, payload, label}]
var _hover_id := ""
var _hover_spot := -1
var _t := 0.0
var _acc := 0.0
var _vis := RandomNumberGenerator.new()
var _scale := 1.0
var _origin := Vector2.ZERO
var _last_date := {}
var _entering := 0              # fila de entrada pela porta (um de cada vez)


func _ready() -> void:
	_vis.seed = 4242
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(0, 360)
	resized.connect(queue_redraw)
	EventBus.office_changed.connect(sync)
	EventBus.world_loaded.connect(func(): _actors.clear(); sync())
	sync()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for id: String in _actors.keys():
		var a: Dictionary = _actors[id]
		_step(a, delta)
		if a.leaving and a.path.is_empty():
			a.alpha -= delta * 1.5
			if a.alpha <= 0.0:
				_actors.erase(id)
	_idle_life(delta)
	_acc += delta
	if _acc >= 1.0 / FPS:
		_acc = 0.0
		queue_redraw()


# ------------------------------------------------------------------ simulação → cena

## Reconcilia atores com a equipe real (contratou → entra pela porta;
## saiu → vai embora; férias → mesa com bilhete).
func sync() -> void:
	if not Game.has_world():
		return
	var w := Game.world
	var team := Office.active_staff(w)
	var present := {}
	var meeting_i := 0
	var pantry_i := 0
	var talkers := {}
	for s: StaffMember in team:
		if s.status == "vacation":
			continue
		present[s.id] = true
		var a: Dictionary = _actors.get(s.id, {})
		if a.is_empty():
			# Recém-contratado entra pela porta (a equipe fundadora já está na mesa).
			var started: Dictionary = w.player_org().office_state.get("started", {})
			var fresh := not s.hired_on.is_empty() and s.hired_on != started and GameDate.days_between(s.hired_on, w.date) <= 1
			a = {"pos": OfficeLayout.DOOR if fresh else _seat(s), "path": [], "mode": "sit", "phase": _vis.randf(), "alpha": 1.0, "emote": "new" if fresh else "", "emote_until": _t + 6.0 if fresh else 0.0, "leaving": false, "home": Vector2.ZERO, "wait": _entering * 1.1 if fresh else 0.0}
			if fresh:
				_entering += 1
			_actors[s.id] = a
		a.leaving = false
		var target := _seat(s)
		var mode := "sit"
		match s.activity:
			"meeting":
				if Office.has_room(w.player_org(), "meeting"):
					target = OfficeLayout.meeting_seat(meeting_i); meeting_i += 1; mode = "stand"
			"break":
				target = OfficeLayout.pantry_spot(pantry_i); pantry_i += 1; mode = "stand"
			"talking":
				var friend := _talk_partner(w, s)
				if not friend.is_empty() and talkers.has(friend):
					target = talkers[friend] + Vector2(22, 0); mode = "stand"
				else:
					target = OfficeLayout.pantry_spot(pantry_i); pantry_i += 1; mode = "stand"
					talkers[s.id] = target
			"celebrating":
				mode = "stand"
				target = _seat(s) + Vector2(0, 30)
		a.home = target
		a.mode = mode
		if a.pos.distance_to(target) > 4.0 and a.path.is_empty():
			a.path = OfficeLayout.path(a.pos, target)
	# Quem saiu hoje caminha até a porta; os demais somem.
	for id: String in _actors.keys():
		if present.has(id):
			continue
		var s: StaffMember = w.staff.get(id)
		var a: Dictionary = _actors[id]
		if s and s.status == "gone" and not a.leaving:
			a.leaving = true
			a.emote = "unhappy"
			a.emote_until = _t + 4.0
			a.path = OfficeLayout.path(a.pos, OfficeLayout.DOOR)
		elif s == null or s.status == "vacation":
			_actors.erase(id)
	_last_date = w.date.duplicate()
	queue_redraw()


func _seat(s: StaffMember) -> Vector2:
	return OfficeLayout.desk_slot(maxi(0, s.desk)).seat


func _talk_partner(w: WorldState, s: StaffMember) -> String:
	for id: String in s.relationships:
		var o: StaffMember = w.staff.get(id)
		if o and o.activity == "talking" and str(s.relationships[id].kind) in ["friend", "mentor", "mentee"]:
			return id
	return ""


func _step(a: Dictionary, delta: float) -> void:
	if a.path.is_empty():
		return
	if float(a.get("wait", 0.0)) > 0.0:
		a.wait -= delta
		if a.wait <= 0.0:
			_entering = maxi(0, _entering - 1)
		return
	var to: Vector2 = a.path[0]
	var d: Vector2 = to - a.pos
	var move := SPEED * delta
	a.phase = fmod(a.phase + delta * 1.6, 1.0)
	if d.length() <= move:
		a.pos = to
		a.path.pop_front()
	else:
		a.pos += d.normalized() * move


## Vida entre os dias: quem trabalha às vezes levanta para um café e volta.
func _idle_life(_delta: float) -> void:
	if _vis.randf() > 0.004 or not Game.has_world():
		return
	var ids := _actors.keys()
	if ids.is_empty():
		return
	var id: String = ids[_vis.randi_range(0, ids.size() - 1)]
	var a: Dictionary = _actors[id]
	var s: StaffMember = Game.world.staff.get(id)
	if s == null or a.leaving or not a.path.is_empty() or s.activity != "working":
		return
	var spot := OfficeLayout.pantry_spot(_vis.randi_range(0, 5))
	a.path = OfficeLayout.path(a.pos, spot) + OfficeLayout.path(spot, a.home)


# ------------------------------------------------------------------ desenho

func _draw() -> void:
	if not Game.has_world():
		return
	var w := Game.world
	var org := w.player_org()
	_scale = minf(size.x / OfficeLayout.W, size.y / OfficeLayout.H)
	_origin = (size - Vector2(OfficeLayout.W, OfficeLayout.H) * _scale) * 0.5
	draw_set_transform(_origin, 0.0, Vector2(_scale, _scale))
	_hotspots.clear()
	draw_rect(Rect2(0, 0, OfficeLayout.W, OfficeLayout.H), Tokens.OFFICE_WALL)
	var rooms: Array = Office.level_info(org).rooms
	for room: String in OfficeLayout.ROOMS:
		var info: Dictionary = OfficeLayout.ROOMS[room]
		var r: Rect2 = info.rect.grow(-3)
		if OfficeLayout.unlocked(rooms, room):
			_floor(r, str(info.floor))
			_furnish(room, r, w, org)
		else:
			_locked(r, room, info)
		draw_string(Tokens.BODY_FONT, r.position + Vector2(8, 16), str(info.label).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12, 11, Color(Tokens.INK, 0.45))
	_walls()
	_top_wall(w, org)
	# Mesas e pessoas ordenadas por profundidade.
	var items: Array = []
	var furnished := Office.desks(org)
	var owners := {}
	for s: StaffMember in Office.active_staff(w):
		owners[s.desk] = s
	for i in 24:
		var slot := OfficeLayout.desk_slot(i)
		items.append({"y": slot.desk.position.y + 12.0, "desk": i, "furnished": i < furnished, "owner": owners.get(i)})
	for id: String in _actors:
		var a: Dictionary = _actors[id]
		var seated: bool = a.mode == "sit" and a.path.is_empty() and a.pos.distance_to(a.home) < 2.0
		items.append({"y": a.pos.y - (6.0 if seated else 0.0), "actor": id})
	items.sort_custom(func(x, y): return x.y < y.y)
	for it: Dictionary in items:
		if it.has("desk"):
			_desk(int(it.desk), bool(it.furnished), it.owner)
		else:
			_actor(str(it.actor), w)
	_clock()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _floor(r: Rect2, kind: String) -> void:
	match kind:
		"wood":
			draw_rect(r, Tokens.OFFICE_WOOD)
			var y := r.position.y + 14.0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Tokens.OFFICE_WOOD.darkened(0.12), 1.0)
				y += 14.0
		"tile":
			draw_rect(r, Tokens.OFFICE_TILE)
			var x := r.position.x + 28.0
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Tokens.OFFICE_TILE_LINE, 1.0)
				x += 28.0
			var y := r.position.y + 28.0
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Tokens.OFFICE_TILE_LINE, 1.0)
				y += 28.0
		_:
			draw_rect(r, Tokens.OFFICE_CARPET)
			var x := r.position.x + 40.0
			while x < r.end.x:
				draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Tokens.OFFICE_CARPET_LINE, 2.0)
				x += 40.0


func _locked(r: Rect2, room: String, info: Dictionary) -> void:
	draw_rect(r, Tokens.OFFICE_LOCKED)
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var a := Vector2(maxf(x, r.position.x), r.position.y + maxf(0.0, r.position.x - x))
		var b := Vector2(minf(x + r.size.y, r.end.x), r.end.y - maxf(0.0, x + r.size.y - r.end.x))
		draw_line(a, b, Color(Tokens.WARN, 0.12), 6.0)
		x += 26.0
	draw_string(Tokens.DISPLAY_FONT, r.get_center() + Vector2(-r.size.x * 0.45, -4), "EM OBRAS", HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 0.9, 14, Color(Tokens.WARN, 0.8))
	draw_string(Tokens.BODY_FONT, r.get_center() + Vector2(-r.size.x * 0.45, 14), "NÍVEL %d DA SEDE" % OfficeLayout.unlock_level(room), HORIZONTAL_ALIGNMENT_CENTER, r.size.x * 0.9, 11, Color(Tokens.WARN, 0.65))
	_hotspots.append({"rect": r, "action": "expand", "payload": {"room": room}, "label": "%s — libera no nível %d" % [info.label, OfficeLayout.unlock_level(room)]})


func _walls() -> void:
	var wall := Tokens.OFFICE_WALL_TOP
	for room: String in OfficeLayout.ROOMS:
		var r: Rect2 = OfficeLayout.ROOMS[room].rect
		# Paredes com vão de porta na face voltada para o corredor.
		var door_bottom := r.position.y < OfficeLayout.ROW_B.position.y
		for side in 4:
			var a: Vector2; var b: Vector2
			match side:
				0: a = r.position; b = Vector2(r.end.x, r.position.y)
				1: a = Vector2(r.end.x, r.position.y); b = r.end
				2: a = r.end; b = Vector2(r.position.x, r.end.y)
				3: a = Vector2(r.position.x, r.end.y); b = r.position
			if room == "desks" and side in [0, 2]:
				continue
			if (side == 2 and door_bottom) or (side == 0 and not door_bottom and room != "desks"):
				var mid := (a + b) * 0.5
				var dir := (b - a).normalized()
				draw_line(a, mid - dir * 30, wall, 5.0)
				draw_line(mid + dir * 30, b, wall, 5.0)
			else:
				draw_line(a, b, wall, 5.0)


func _top_wall(w: WorldState, org: Organization) -> void:
	draw_rect(Rect2(0, 0, OfficeLayout.W, 36), Tokens.OFFICE_WALL)
	draw_rect(Rect2(0, 30, OfficeLayout.W, 6), Tokens.OFFICE_WALL_TOP)
	# Letreiro da promotora e nível da sede.
	var name := org.name.to_upper()
	draw_string(Tokens.italic_font(), Vector2(14, 25), name, HORIZONTAL_ALIGNMENT_LEFT, 560, 20, Tokens.INK)
	var lvl := Office.level_info(org)
	draw_string(Tokens.BODY_FONT, Vector2(0, 24), "SEDE: %s" % str(lvl.label).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, OfficeLayout.W - 14, 13, Tokens.MUTED)


func _furnish(room: String, r: Rect2, w: WorldState, org: Organization) -> void:
	var c := r.get_center()
	match room:
		"president":
			# Mesa grande, cadeira, telefone com as decisões pendentes.
			var desk := Rect2(c + Vector2(-80, -10), Vector2(160, 44))
			draw_rect(desk.grow(2), Tokens.OFFICE_SHADOW)
			draw_rect(desk, Tokens.OFFICE_DESK)
			draw_rect(Rect2(desk.position, Vector2(desk.size.x, 8)), Tokens.OFFICE_DESK_TOP)
			draw_circle(c + Vector2(0, -34), 14, Tokens.STEEL)
			var phone := Rect2(desk.position + Vector2(112, 14), Vector2(30, 20))
			draw_rect(phone, Tokens.CANVAS)
			var pending := Dilemmas.open(w).size()
			var blink := pending > 0 and fmod(_t, 1.2) < 0.8
			draw_circle(phone.get_center(), 5, Tokens.FIGHT_RED if blink else Tokens.STEEL)
			if pending > 0:
				draw_circle(phone.position + Vector2(30, 0), 10, Tokens.FIGHT_RED)
				draw_string(Tokens.DISPLAY_FONT, phone.position + Vector2(25, 5), str(pending), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tokens.INK)
			_hotspots.append({"rect": desk.grow(12), "action": "inbox", "payload": {}, "label": "Caixa de entrada (%d decisões)" % pending})
			# Estante de cinturões (títulos da liga).
			var belts := org.titles.size()
			var case := Rect2(r.position + Vector2(r.size.x - 70, 30), Vector2(56, 90))
			draw_rect(case, Tokens.OFFICE_GLASS)
			draw_rect(case, Tokens.OFFICE_METAL, false, 2.0)
			for k in mini(belts, 4):
				draw_rect(Rect2(case.position + Vector2(8, 10 + k * 20), Vector2(40, 8)), Tokens.CHAMP_GOLD)
			_hotspots.append({"rect": case.grow(6), "action": "rankings", "payload": {}, "label": "Cinturões e rankings"})
			_plant(r.position + Vector2(24, r.size.y - 22))
		"meeting":
			var table := Rect2(c + Vector2(-110, -26), Vector2(220, 56))
			draw_rect(table.grow(2), Tokens.OFFICE_SHADOW)
			draw_rect(table, Tokens.OFFICE_DESK_TOP)
			var board := Rect2(r.position + Vector2(20, 24), Vector2(110, 40))
			draw_rect(board, Tokens.PAPER)
			var next := CareerStats.next_event(w)
			var line := "SEM NOITE MARCADA" if next == null else "%s · %d lutas" % [next.name.to_upper(), next.fight_ids.size()]
			draw_string(Tokens.BODY_FONT, board.position + Vector2(6, 16), line, HORIZONTAL_ALIGNMENT_LEFT, board.size.x - 10, 10, Tokens.CANVAS)
			if next:
				draw_string(Tokens.BODY_FONT, board.position + Vector2(6, 32), GameDate.format(next.date), HORIZONTAL_ALIGNMENT_LEFT, board.size.x - 10, 10, Tokens.FIGHT_RED)
			_hotspots.append({"rect": r, "action": "events", "payload": {"event_id": next.id} if next else {"create": true}, "label": "Reunião: " + line})
		"pantry":
			var counter := Rect2(r.position + Vector2(10, 26), Vector2(r.size.x - 20, 26))
			draw_rect(counter, Tokens.OFFICE_METAL.darkened(0.3))
			draw_rect(Rect2(counter.position + Vector2(20, -12), Vector2(22, 20)), Tokens.CANVAS)
			for k in 3:
				var sx := counter.position.x + 31 + sin(_t * 2 + k) * 2
				draw_line(Vector2(sx, counter.position.y - 16 - k * 5), Vector2(sx + 2, counter.position.y - 20 - k * 5), Color(Tokens.INK, 0.35), 1.5)
			draw_circle(c + Vector2(0, 40), 26, Tokens.OFFICE_DESK_TOP)
			_plant(r.position + Vector2(r.size.x - 22, r.size.y - 20))
		"reception":
			var counter := Rect2(r.position + Vector2(20, 40), Vector2(r.size.x - 40, 26))
			draw_rect(counter, Tokens.OFFICE_DESK)
			draw_rect(Rect2(counter.position, Vector2(counter.size.x, 6)), Tokens.OFFICE_DESK_TOP)
			draw_rect(Rect2(OfficeLayout.DOOR + Vector2(-34, 8), Vector2(68, 12)), Tokens.CANVAS)
		"medical":
			var bed := Rect2(r.position + Vector2(24, 50), Vector2(90, 40))
			draw_rect(bed, Tokens.PAPER.darkened(0.1))
			draw_rect(Rect2(bed.position, Vector2(22, bed.size.y)), Tokens.PAPER)
			var cross := r.position + Vector2(r.size.x - 50, 50)
			draw_rect(Rect2(cross + Vector2(-5, -15), Vector2(10, 30)), Tokens.GOOD)
			draw_rect(Rect2(cross + Vector2(-15, -5), Vector2(30, 10)), Tokens.GOOD)
			var hurt := _injured(w, org)
			draw_string(Tokens.BODY_FONT, r.position + Vector2(24, r.size.y - 16), "%d em recuperação" % hurt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 30, 12, Tokens.INK if hurt > 0 else Tokens.MUTED)
			_hotspots.append({"rect": r, "action": "fighters", "payload": {"mode": "roster"}, "label": "Médico: %d atletas em recuperação" % hurt})
		"studio":
			var ring := r.position + Vector2(70, 110)
			draw_arc(ring, 30, 0, TAU, 24, Tokens.PAPER, 4.0)
			draw_rect(Rect2(r.position + Vector2(150, 90), Vector2(60, 36)), Tokens.CANVAS)
			draw_circle(r.position + Vector2(180, 108), 10, Tokens.STEEL)
			draw_circle(r.position + Vector2(208, 96), 3, Tokens.FIGHT_RED if fmod(_t, 1.0) < 0.5 else Tokens.CANVAS)
			_hotspots.append({"rect": r, "action": "news", "payload": {}, "label": "Mídia: notícias e redes"})
		"film":
			var screen := Rect2(r.position + Vector2(14, 30), Vector2(r.size.x - 28, 60))
			draw_rect(screen, Tokens.CANVAS)
			draw_rect(screen.grow(-4), Tokens.OFFICE_SCREEN.darkened(0.6))
			for k in 3:
				draw_rect(Rect2(r.position + Vector2(20 + k * 38, 120), Vector2(28, 18)), Tokens.STEEL)
			_hotspots.append({"rect": r, "action": "market", "payload": {}, "label": "Scouting: mercado e prospects"})
		"hall":
			for k in 3:
				var p := r.position + Vector2(24 + k * 38, 50)
				draw_rect(Rect2(p, Vector2(26, 70)), Tokens.OFFICE_GLASS)
				draw_rect(Rect2(p + Vector2(4, 30), Vector2(18, 8)), Tokens.CHAMP_GOLD if k < org.titles.size() else Tokens.STEEL)
			_hotspots.append({"rect": r, "action": "rankings", "payload": {}, "label": "Hall dos cinturões"})


func _injured(w: WorldState, org: Organization) -> int:
	var n := 0
	for id: String in org.roster:
		var f: Fighter = w.fighters.get(id)
		if f and (not f.injuries.is_empty() or (not f.medical_suspension_until.is_empty() and GameDate.days_between(w.date, f.medical_suspension_until) > 0)):
			n += 1
	return n


func _plant(p: Vector2) -> void:
	draw_circle(p + Vector2(0, 6), 9, Tokens.OFFICE_DESK)
	for k in 5:
		var a := -PI / 2 + (k - 2) * 0.5 + sin(_t + k) * 0.03
		draw_line(p, p + Vector2(cos(a), sin(a)) * 16, Tokens.OFFICE_PLANT, 5.0)


func _desk(i: int, furnished: bool, owner) -> void:
	var slot := OfficeLayout.desk_slot(i)
	var r: Rect2 = slot.desk
	if not furnished:
		draw_rect(r, Color(Tokens.OFFICE_CARPET_LINE, 0.6), false, 1.0)
		return
	draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Tokens.OFFICE_SHADOW)
	draw_rect(r, Tokens.OFFICE_DESK)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Tokens.OFFICE_DESK_TOP)
	# Costas do monitor viradas para quem olha.
	var mon := Rect2(slot.screen + Vector2(-16, -14), Vector2(32, 14))
	var working: bool = owner != null and owner.activity in ["working", "overloaded", "tired"] and _actors.has(owner.id) and _actors[owner.id].path.is_empty()
	draw_rect(mon, Tokens.CANVAS)
	if working:
		draw_rect(Rect2(mon.position + Vector2(0, -2), Vector2(mon.size.x, 2)), Color(Tokens.OFFICE_SCREEN, 0.6 + 0.3 * sin(_t * 3 + i)))
	if owner == null:
		_hotspots.append({"rect": r.grow(8), "action": "hire", "payload": {}, "label": "Mesa livre — contratar"})
		draw_string(Tokens.BODY_FONT, r.position + Vector2(4, 24), "LIVRE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 10, Color(Tokens.INK, 0.4))
	elif owner.status == "vacation":
		draw_rect(Rect2(r.position + Vector2(50, 10), Vector2(22, 16)), Tokens.CHAMP_GOLD.lightened(0.3))
		draw_string(Tokens.BODY_FONT, r.position + Vector2(4, 24), "FÉRIAS", HORIZONTAL_ALIGNMENT_LEFT, 46, 10, Tokens.CANVAS)
		_hotspots.append({"rect": r.grow(8), "action": "person", "payload": {"staff_id": owner.id}, "label": owner.full_name() + " — de férias"})


func _actor(id: String, w: WorldState) -> void:
	var a: Dictionary = _actors[id]
	var s: StaffMember = w.staff.get(id)
	if s == null:
		return
	var moving: bool = not a.path.is_empty()
	var seated: bool = a.mode == "sit" and not moving and a.pos.distance_to(a.home) < 2.0
	var pose := "walk" if moving else ("sit" if seated else "stand")
	var u := 1.05
	var mood := clampf((s.morale - 55.0) / 35.0, -1.0, 1.0)
	var opts := {"pose": pose, "phase": a.phase, "t": _t + a.phase * 7.0, "alpha": a.alpha, "shirt": PeopleArt.shirt(s.role), "sex": s.sex, "mood": mood, "tired": s.activity == "tired", "typing": seated and s.activity in ["working", "overloaded"], "highlight": id == selected_id or id == _hover_id}
	if s.activity == "celebrating" and not moving:
		opts.raise = 4.0 + sin(_t * 8.0) * 2.0
	var base: Vector2 = a.pos + (Vector2(0, -10) if seated else Vector2.ZERO)
	PeopleArt.draw_person(self, base, u, s.look, opts)
	# Balões: estado da simulação tem prioridade sobre o cosmético.
	var emote := ""
	if a.emote_until > _t:
		emote = a.emote
	elif s.activity == "celebrating":
		emote = "celebrate"
	else:
		match Office.problem(s):
			"stress": emote = "stress"
			"tired": emote = "tired"
			"unhappy": emote = "unhappy"
			"conflict": emote = "conflict" if fmod(_t + a.phase * 5, 6.0) < 2.5 else ""
		if emote.is_empty() and s.activity == "talking" and not moving:
			emote = "talk"
		if emote.is_empty() and s.morale > 82 and fmod(_t + a.phase * 9, 8.0) < 1.5:
			emote = "happy"
	for d: Dilemma in Dilemmas.open(w):
		if id in d.staff_ids and d.priority in ["high", "critical"]:
			emote = "problem"
	if not emote.is_empty():
		PeopleArt.draw_emote(self, base + Vector2(14, -66) * u, emote, u, _t)
	if id == selected_id or id == _hover_id:
		var tag := s.first_name
		var tw := Tokens.BODY_FONT.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 12
		var at := base + Vector2(-tw * 0.5, 10)
		draw_rect(Rect2(at, Vector2(tw, 18)), Color(Tokens.CANVAS, 0.85))
		draw_string(Tokens.BODY_FONT, at + Vector2(6, 14), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tokens.INK)


func _clock() -> void:
	var c := Vector2(170, 590)
	draw_circle(c, 16, Tokens.PAPER)
	draw_arc(c, 16, 0, TAU, 24, Tokens.CANVAS, 2.0)
	var hours := 8.0 + day_fraction * 11.0
	var ah := -PI / 2 + hours / 12.0 * TAU
	var am := -PI / 2 + fmod(hours, 1.0) * TAU
	draw_line(c, c + Vector2(cos(ah), sin(ah)) * 8, Tokens.CANVAS, 2.5)
	draw_line(c, c + Vector2(cos(am), sin(am)) * 12, Tokens.CANVAS, 1.5)


# ------------------------------------------------------------------ entrada

func _to_design(p: Vector2) -> Vector2:
	return (p - _origin) / maxf(_scale, 0.001)


func _pick(p: Vector2) -> Dictionary:
	var best := ""
	var best_d := 26.0
	for id: String in _actors:
		var a: Dictionary = _actors[id]
		if a.leaving:
			continue
		var center: Vector2 = a.pos + Vector2(0, -30)
		var d := center.distance_to(p)
		if d < best_d:
			best_d = d
			best = id
	if not best.is_empty():
		return {"kind": "person", "id": best}
	for i in range(_hotspots.size() - 1, -1, -1):
		if (_hotspots[i].rect as Rect2).has_point(p):
			return {"kind": "spot", "index": i}
	return {}


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _pick(_to_design(event.position))
		_hover_id = str(hit.get("id", "")) if hit.get("kind") == "person" else ""
		_hover_spot = int(hit.get("index", -1)) if hit.get("kind") == "spot" else -1
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if not hit.is_empty() else CURSOR_ARROW
		tooltip_text = _hotspots[_hover_spot].label if _hover_spot >= 0 else ""
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hit := _pick(_to_design(event.position))
		if hit.get("kind") == "person":
			selected_id = str(hit.id)
			person_pressed.emit(selected_id)
			accept_event()
		elif hit.get("kind") == "spot":
			var spot: Dictionary = _hotspots[int(hit.index)]
			if spot.action == "person":
				selected_id = str(spot.payload.staff_id)
				person_pressed.emit(selected_id)
			else:
				hotspot_pressed.emit(str(spot.action), spot.payload)
			accept_event()


## Para testes/QA: posição na tela de uma pessoa (centro do corpo).
func screen_point_of(staff_id: String) -> Vector2:
	if not _actors.has(staff_id):
		return Vector2(-1, -1)
	return _origin + (_actors[staff_id].pos + Vector2(0, -30)) * _scale
