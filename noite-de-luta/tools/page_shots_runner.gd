extends Node
## Páginas inteiras de um save: abre cada área e algumas telas internas e captura do topo ao fim
## da rolagem (um arquivo por dobra). Serve para rever o que fica abaixo da primeira dobra.
## xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 \
##   --script res://tools/design_shots.gd -- --runner=page_shots_runner --out=DIR --in=SAVE.json [--only=hub,team]

var out_dir := "user://shots"
var prefix := ""
var _only: Array = []


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(name: String) -> void:
	await _frames(6)
	var guard := 0
	while Portraits.pending() > 0 and guard < 1200:
		await get_tree().process_frame
		guard += 1
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s%s.png" % [out_dir, prefix, name])
	print("[tela] ", name)


## A tela atual, dobra a dobra, até o fim da rolagem (no máximo `max_pages`).
func _page(name: String, max_pages: int = 4) -> void:
	if not _only.is_empty() and not _only.has(name):
		return
	await _frames(4)
	var cur := UIManager.current()
	if cur == null:
		return
	var sc := cur.scroll()
	if sc == null:
		await _snap(name + "_1")
		return
	sc.scroll_vertical = 0
	var step := maxf(200.0, sc.size.y - 120.0)
	for i in max_pages:
		await _snap("%s_%d" % [name, i + 1])
		var bar := sc.get_v_scroll_bar()
		var last := bar.max_value - bar.page
		if float(sc.scroll_vertical) >= last - 2.0:
			break
		sc.scroll_vertical = int(minf(last, float(sc.scroll_vertical) + step))


func _run() -> void:
	var in_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			in_path = a.substr(5)
		if a.begins_with("--only="):
			_only = Array(a.substr(7).split(","))
	var raw := FileAccess.get_file_as_string(in_path)
	if raw.find("\n") > 0 and raw.find("\n") < 400:
		raw = raw.substr(raw.find("\n") + 1)
	var w := GameWorld.from_dict(JSON.parse_string(raw))
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	GameManager.world = w
	GameManager.world_changed.emit()
	UIManager.goto("hub")
	await _page("hub", 5)
	for a: String in UIManager.tabs():
		if a != "hub":
			UIManager.switch_area(a)
			await _page(a, 3)
	# A ficha de um lutador da casa (ou de um campeão, na liga), aba a aba.
	var who: Fighter = null
	var mine := w.user_fighters()
	if not mine.is_empty():
		who = mine[0]
	else:
		for div: String in w.champions:
			who = w.fighter(int(w.champions[div]))
			if who != null:
				break
	if who != null:
		for tab: String in ["ficha", "carreira", "treino", "contrato"]:
			UIManager.goto("hub")
			UIManager.push("fighter", {"id": who.id, "tab": tab})
			await _page("fighter_" + tab, 4)
	for s: String in ["inbox", "season", "titles", "results", "legacy", "settings"]:
		UIManager.goto("hub")
		UIManager.push(s)
		await _page(s, 3)
	if w.is_president():
		for s: String in ["tv", "venue"]:
			UIManager.goto("hub")
			UIManager.push(s)
			await _page(s, 3)
	print("fim")
	get_tree().quit()
