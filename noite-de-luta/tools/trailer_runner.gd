extends Node
## Trechos para o trailer, gravados com o Movie Maker do Godot (quadro a quadro, sem pressa).
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --write-movie DIR/a.avi \
##   --fixed-fps 30 --script res://tools/design_shots.gd -- --runner=trailer_runner --abertura [--parte=presidente]
## Cada trecho sai no log como "[trecho] nome início fim" (quadros do vídeo); a montagem corta por eles.

var out_dir := "user://shots"
var prefix := ""
var _start := {}


func _ready() -> void:
	if "--parte=presidente" in OS.get_cmdline_user_args():
		_run_president()
	else:
		_run_manager()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera os retratos e o corpo ficarem prontos (esses quadros ficam fora dos trechos).
func _settle() -> void:
	await _frames(4)
	var g := 0
	while Portraits.pending() > 0 and g < 1200:
		await get_tree().process_frame
		g += 1
	await _frames(3)


func _begin(name: String) -> void:
	_start[name] = Engine.get_frames_drawn()


func _end(name: String) -> void:
	print("[trecho] %s %d %d" % [name, int(_start[name]), Engine.get_frames_drawn()])


func _scroll(to: int, frames: int) -> void:
	var sc: ScrollContainer = UIManager.current().scroll()
	if sc == null:
		return
	var from := sc.scroll_vertical
	for i in frames:
		var t := float(i + 1) / float(frames)
		t = t * t * (3.0 - 2.0 * t)
		sc.scroll_vertical = int(lerp(float(from), float(to), t))
		await get_tree().process_frame


func _quiet(w: GameWorld) -> void:
	w.tut["on"] = false
	w.tut["skipped"] = true
	w.tut["tips_on"] = false
	w.pops.clear()


func _press(screen: Node, text: String) -> bool:
	for b: Node in screen.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			(b as Button).pressed.emit()
			return true
	return false


func _run_manager() -> void:
	GameManager.delete_save()
	_begin("abertura")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(170)
	_end("abertura")
	var w := Career.new_career("Equipe Nova Era", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	var y := w.year()
	var m := w.month()
	var pros: Array = w.fighters.values().filter(func(f: Fighter) -> bool: return f.team_id < 0 and f.stage(y, m) == "profissional")
	pros.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	var fem: Array = pros.filter(func(f: Fighter) -> bool: return f.is_female())
	var men: Array = pros.filter(func(f: Fighter) -> bool: return not f.is_female())
	var her: Fighter = fem[1]
	for f: Fighter in [men[2], men[5], her]:
		f.team_id = w.user_team_id
		f.contract = {"cut": 0.2, "fights": 5}
	StaffMarket.hire(w, w.staff_market[0])
	GameManager.start_career(w)
	_quiet(w)
	var guard := 0
	while Career.pending_user_bouts(w).is_empty() and guard < 30:
		guard += 1
		if not w.offers.is_empty() and guard > 2:
			Matchmaker.accept_offer(w, w.offers[0])
		Career.advance_week(w)
	_quiet(w)
	# Início.
	UIManager.goto("hub")
	await _settle()
	_begin("inicio")
	await _frames(50)
	await _scroll(560, 50)
	await _frames(25)
	_end("inicio")
	# Ficha do lutador.
	var b: Bout = Career.pending_user_bouts(w)[0]
	var me := w.fighter(b.a) if w.is_user_fighter(w.fighter(b.a)) else w.fighter(b.b)
	UIManager.switch_area("team")
	UIManager.push("fighter", {"id": me.id})
	await _settle()
	_begin("ficha")
	await _frames(45)
	await _scroll(640, 45)
	await _frames(25)
	_end("ficha")
	# Plano de luta.
	UIManager.switch_area("hub")
	UIManager.push("fight_plan", {"bout": b.id})
	await _settle()
	_begin("plano")
	await _frames(40)
	await _scroll(520, 40)
	await _frames(20)
	_end("plano")
	# A luta, na velocidade normal.
	UIManager.replace("fight", {"bout": b.id})
	var fs := UIManager.current()
	fs.set("_speed", 0)
	await _settle()
	_begin("luta")
	await _frames(420)
	_end("luta")
	fs.set("_speed", 1)
	_begin("luta_rapida")
	await _frames(240)
	_end("luta_rapida")
	var g := 0
	while String(fs.get("_state")) == "round" and g < 3000:
		fs.set("_clock", 99999.0)
		fs.set("_skip", true)
		await get_tree().process_frame
		g += 1
	await _frames(20)
	_begin("intervalo")
	await _frames(70)
	_end("intervalo")
	g = 0
	while String(fs.get("_state")) != "done" and g < 6000:
		g += 1
		if String(fs.get("_state")) == "corner":
			var foot: VBoxContainer = fs.footer()
			var btns := foot.find_children("*", "Button", true, false).filter(func(x: Node) -> bool: return not x.is_queued_for_deletion() and not x.get_parent().is_queued_for_deletion())
			if not btns.is_empty():
				(btns[0] as Button).pressed.emit()
		fs.set("_clock", 99999.0)
		fs.set("_skip", true)
		await get_tree().process_frame
	await _frames(10)
	_begin("resultado")
	await _frames(90)
	_end("resultado")
	# Editor de visual.
	UIManager.goto("team")
	UIManager.push("look", {"id": her.id})
	await _settle()
	var s := UIManager.current()
	_begin("visual")
	await _frames(30)
	var sug: Array = s.call("_suggested", true)
	var cols := [5, 2, 7, 1, 4]
	for i in mini(5, sug.size()):
		s.call("_put", "hs", int(sug[(i * 3) % sug.size()]))
		s.call("_put", "hc", cols[i])
		await _frames(26)
	s.set("_tab", "maquiagem")
	s.call("_put", "mk", 3)
	s.call("_put", "lp", 5)
	s.call("_put", "sd", 2)
	await _frames(40)
	_end("visual")
	UIManager.back()
	UIManager.back()
	# Um ano depois: a noite de gala.
	AppSettings.fight_view = "2d"
	guard = 0
	while w.awards.is_empty() and guard < 70:
		guard += 1
		for o: Dictionary in w.offers.duplicate():
			if w.offers.has(o):
				Matchmaker.accept_offer(w, o)
		Career.advance_week(w, true)
	_quiet(w)
	UIManager.goto("hub")
	UIManager.push("gala", {"year": int(w.awards.back()["year"]), "review": true})
	await _settle()
	var gs := UIManager.current()
	_begin("gala")
	await _frames(40)
	for i in 2:
		gs.call("_next")
		await _settle()
		await _frames(30)
		await _scroll(700, 40)
		await _frames(20)
	_end("gala")
	GameManager.delete_save()
	get_tree().quit()


func _run_president() -> void:
	GameManager.delete_save()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	var w := Org.new_career("Liga Global de Combate", "LGC", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], 2027)
	GameManager.start_career(w)
	_quiet(w)
	var ev: FightEvent = null
	for e: FightEvent in Org.upcoming_events(w):
		if e.week - w.week >= 4 and Org.event_bouts(w, e).size() < e.slots:
			ev = e
			break
	if ev == null:
		print("sem noite aberta")
		get_tree().quit()
		return
	UIManager.goto("hub")
	UIManager.push("org_event", {"id": ev.id})
	await _settle()
	_begin("card_vazio")
	await _frames(40)
	_end("card_vazio")
	Org.auto_fill(w, ev)
	UIManager.current().refresh()
	await _settle()
	_begin("card_cheio")
	await _frames(35)
	await _scroll(700, 50)
	await _frames(20)
	_end("card_cheio")
	UIManager.push("venue", {"id": ev.id})
	await _settle()
	_begin("sede")
	await _frames(40)
	await _scroll(600, 45)
	await _frames(20)
	_end("sede")
	UIManager.back()
	UIManager.back()
	var guard := 0
	while w.week < ev.week and guard < 12:
		guard += 1
		var n := Org.night_this_week(w)
		if n != null and n != ev:
			for bb: Bout in Org.pending_bouts(w):
				Career.simulate(w, bb)
			Org.close_event(w, n, Org.auto_bonuses(w, n))
		GameManager.advance_week()
	for inc: Dictionary in FightWeek.pending(w, ev):
		if String(inc["kind"]) == "lesao":
			FightWeek.cancel_injury(w, inc, true)
		else:
			FightWeek.cancel_weight(w, inc)
	_quiet(w)
	UIManager.goto("hub")
	UIManager.push("night", {"id": ev.id})
	await _settle()
	_begin("noite")
	await _frames(45)
	await _scroll(500, 40)
	await _frames(15)
	_end("noite")
	var lst := Org.event_bouts(w, ev)
	for bb: Bout in lst.slice(0, lst.size() - 1):
		Career.simulate(w, bb)
	var main_b: Bout = lst.back()
	UIManager.push("fight", {"bout": main_b.id, "spectator": true})
	var fs := UIManager.current()
	fs.set("_speed", 0)
	await _settle()
	_begin("principal")
	await _frames(360)
	_end("principal")
	var g := 0
	while String(fs.get("_state")) != "done" and g < 6000:
		g += 1
		if String(fs.get("_state")) == "corner":
			var foot: VBoxContainer = fs.footer()
			(foot.get_child(0) as Button).pressed.emit()
		fs.set("_clock", 99999.0)
		await get_tree().process_frame
	await _frames(10)
	_begin("principal_fim")
	await _frames(80)
	_end("principal_fim")
	UIManager.back()
	await _frames(4)
	Org.close_event(w, ev, Org.auto_bonuses(w, ev))
	UIManager.goto("hub")
	UIManager.switch_area("titles")
	await _settle()
	_begin("cinturoes")
	await _frames(40)
	await _scroll(800, 60)
	await _frames(15)
	_end("cinturoes")
	GameManager.delete_save()
	get_tree().quit()
