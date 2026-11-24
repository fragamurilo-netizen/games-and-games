extends Node

var in_path := ""
var _rows: Array = []


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Mede a montagem (a parte que trava o toque) e o tempo até dois quadros depois.
func _time(name: String, open: Callable) -> void:
	await _frames(3)
	var t0 := Time.get_ticks_usec()
	open.call()
	var build := float(Time.get_ticks_usec() - t0) / 1000.0
	await _frames(2)
	var total := float(Time.get_ticks_usec() - t0) / 1000.0
	var nodes := 0
	var cur := UIManager.current()
	if cur != null:
		nodes = cur.find_children("*", "", true, false).size()
	_rows.append([name, build, total, nodes])
	print("   %-34s montar %7.1f ms · com dois quadros %7.1f ms · %5d nós" % [name, build, total, nodes])


func _run() -> void:
	var raw := FileAccess.get_file_as_string(in_path)
	if raw.begins_with("{\"team\"") or raw.find("\n") > 0 and raw.find("\n") < 400:
		raw = raw.substr(raw.find("\n") + 1)
	var t0 := Time.get_ticks_usec()
	var d: Variant = JSON.parse_string(raw)
	var w := GameWorld.from_dict(d)
	print("abrir o save: %.0f ms (%d KB)" % [float(Time.get_ticks_usec() - t0) / 1000.0, raw.length() / 1024])
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	GameManager.world = w
	GameManager.world_changed.emit()
	var pres := w.is_president()
	print("papel %s, %s, %d lutadores" % [w.role, GameWorld.week_text(w.week), w.fighters.size()])
	await _time("início", func() -> void: UIManager.goto("hub"))
	for a: String in UIManager.tabs():
		if a != "hub":
			await _time("área " + a, func() -> void: UIManager.switch_area(a))
	# Fichas: um campeão veterano e, na academia, um lutador da casa.
	var champs: Array = []
	for div: String in w.champions:
		var c := w.fighter(int(w.champions[div]))
		if c != null:
			champs.append(c)
	champs.sort_custom(func(x: Fighter, y: Fighter) -> bool: return x.history.size() > y.history.size())
	UIManager.switch_area("rankings")
	if not champs.is_empty():
		var cid: int = (champs[0] as Fighter).id
		await _time("ficha de campeão (%d lutas)" % (champs[0] as Fighter).history.size(), func() -> void: UIManager.push("fighter", {"id": cid}))
		UIManager.back()
	if not pres and not w.user_fighters().is_empty():
		var mid: int = (w.user_fighters()[0] as Fighter).id
		UIManager.switch_area("team")
		await _time("ficha de lutador da casa", func() -> void: UIManager.push("fighter", {"id": mid}))
		await _time("visual", func() -> void: UIManager.push("look", {"id": mid}))
		UIManager.back()
		UIManager.back()
	UIManager.switch_area("hub")
	for s: Array in [["cinturões", "titles", {}], ["resultados", "results", {}], ["legado: prêmios", "legacy", {}], ["legado: hall", "legacy", {"tab": "hall"}],
			["legado: recordes", "legacy", {"tab": "recordes"}], ["caixa de entrada", "inbox", {}], ["temporada: metas", "season", {}],
			["temporada: conquistas", "season", {"tab": "conquistas"}], ["configurações", "settings", {}]]:
		await _time(String(s[0]), func() -> void: UIManager.push(String(s[1]), s[2]))
		UIManager.back()
	var done: Array = w.events.values().filter(func(e: FightEvent) -> bool: return e.done)
	done.sort_custom(func(x: FightEvent, y: FightEvent) -> bool: return x.week > y.week)
	var next: Array = w.events.values().filter(func(e: FightEvent) -> bool: return not e.done and (not pres or e.tier == 2))
	next.sort_custom(func(x: FightEvent, y: FightEvent) -> bool: return x.week < y.week)
	if not done.is_empty():
		var eid: int = (done[0] as FightEvent).id
		await _time("card de noite passada", func() -> void: UIManager.push("event", {"id": eid}))
		UIManager.back()
	if pres and not next.is_empty():
		var nid: int = (next[0] as FightEvent).id
		await _time("montagem do evento", func() -> void: UIManager.push("org_event", {"id": nid}))
		await _time("casar luta", func() -> void: UIManager.push("book", {"event": nid, "div": ""}))
		UIManager.back()
		await _time("local e ingressos", func() -> void: UIManager.push("venue", {"id": nid}))
		UIManager.back()
		UIManager.back()
		await _time("contrato de TV", func() -> void: UIManager.push("tv"))
		UIManager.back()
	# Salvar e virar a semana, como o jogo faz.
	t0 = Time.get_ticks_usec()
	GameManager.save_now()
	GameManager.flush()
	print("   %-34s %7.1f ms" % ["salvar", float(Time.get_ticks_usec() - t0) / 1000.0])
	t0 = Time.get_ticks_usec()
	Career.advance_week(w, true)
	print("   %-34s %7.1f ms" % ["virar a semana", float(Time.get_ticks_usec() - t0) / 1000.0])
	_rows.sort_custom(func(x: Array, y: Array) -> bool: return float(x[1]) > float(y[1]))
	print("mais pesadas: ", ", ".join(_rows.slice(0, 5).map(func(r: Array) -> String: return "%s %.0f ms" % [r[0], r[1]])))
	GameManager.world = null
	get_tree().quit()
