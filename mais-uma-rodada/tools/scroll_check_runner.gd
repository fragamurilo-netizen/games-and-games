extends Node
## Lógica do scroll_check.gd (carregada depois dos autoloads).

var _fails := 0


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ms(ms: int) -> void:
	var t := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < t:
		await get_tree().process_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALHA ") + what)
	if not ok:
		_fails += 1


## Coordenadas do viewport → janela (o evento de toque chega em pixels da janela).
func _win(pos: Vector2) -> Vector2:
	return get_viewport().get_screen_transform() * pos


func _touch(pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = _win(pos)
	t.pressed = pressed
	Input.parse_input_event(t)
	Input.flush_buffered_events()


func _swipe(a: Vector2, b: Vector2, steps: int = 12) -> void:
	_touch(a, true)
	await _frames(1)
	var p := a
	for i in steps:
		var np := a.lerp(b, float(i + 1) / steps)
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = _win(np)
		d.relative = _win(np) - _win(p)
		d.velocity = d.relative * 60.0
		Input.parse_input_event(d)
		Input.flush_buffered_events()
		p = np
		await _ms(16)
	_touch(b, false)
	await _frames(1)


func _run() -> void:
	# Toques viram cliques emulados, como no Android.
	Input.emulate_mouse_from_touch = true
	await _frames(2)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(6)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club_id: int = w.clubs_in_league("BRA1")[0].id
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club_id, "Teste", GameWorld.DIFF_NORMAL, 5)
	UIManager.goto("squad")
	await _frames(10)
	var screen := UIManager.current()
	var sc := screen.scroll()
	var mid := sc.get_global_rect().get_center()
	print("Rolagem por arrasto")
	await _swipe(mid + Vector2(0, 250), mid + Vector2(0, -250))
	await _ms(1500)
	var after_swipe := sc.scroll_vertical
	_check(after_swipe >= 400, "arrastar sobre as linhas rola a lista (%d px)" % after_swipe)
	_check(UIManager.current() == screen, "arrastar não abre o jogador sob o dedo")
	var shrunk := 0
	for n in screen.find_children("Tap", "Button", true, false):
		if (n.get_parent() as Control).scale != Vector2.ONE:
			shrunk += 1
	_check(shrunk == 0, "a linha tocada volta ao tamanho normal depois do arrasto")
	await _swipe(mid + Vector2(0, -200), mid + Vector2(0, 100), 6)
	await _ms(1500)
	_check(sc.scroll_vertical < after_swipe, "arrastar para baixo sobe a lista (%d px)" % sc.scroll_vertical)
	var keep := sc.scroll_vertical
	# Toque simples numa linha ainda abre o perfil.
	var row := _first_row_at_middle(screen, sc)
	_check(row != null, "há uma linha de jogador no meio da tela")
	if row != null:
		var c := row.get_global_rect().get_center()
		_touch(c, true)
		await _frames(1)
		_touch(c, false)
		await _frames(6)
		_check(UIManager.current() != screen and UIManager.current().screen_name == "player", "tocar numa linha abre o perfil")
		UIManager.back()
		await _frames(8)
		_check(absi(sc.scroll_vertical - keep) <= 2, "voltar mantém a posição da lista (%d → %d)" % [keep, sc.scroll_vertical])
	print("Modal alto")
	var v := UIKit.vbox(10)
	for i in 30:
		v.add_child(UIKit.button("Opção %d" % (i + 1), "", func(): pass))
	var screen_before := sc.scroll_vertical
	var dim := UIManager.show_modal(v, true)
	await _ms(400)
	var msc := v.get_parent() as ScrollContainer
	_check(msc != null, "conteúdo alto ganha rolagem dentro do modal")
	if msc != null:
		var vp := get_viewport().get_visible_rect()
		_check(vp.encloses(msc.get_global_rect().grow(-1)), "o modal cabe na tela")
		var c := msc.get_global_rect().get_center()
		await _swipe(c + Vector2(0, 200), c + Vector2(0, -200))
		await _ms(800)
		_check(msc.scroll_vertical > 200, "arrastar rola o modal (%d px)" % msc.scroll_vertical)
		_check(sc.scroll_vertical == screen_before, "a tela por trás não rola")
		_check(UIManager.has_modal(), "arrastar não fecha o modal")
	UIManager.close_all_modals()
	await _frames(2)
	print("SCROLL %s: %d falha(s)" % ["OK" if _fails == 0 else "FALHOU", _fails])
	get_tree().quit(1 if _fails > 0 else 0)


func _first_row_at_middle(screen: Control, sc: ScrollContainer) -> Control:
	var area := sc.get_global_rect().grow_individual(0, -40, 0, -40)
	var y := area.get_center().y
	var best: Control = null
	for n in screen.find_children("Tap", "Button", true, false):
		var b := n as Control
		var r := b.get_global_rect()
		if not b.is_visible_in_tree() or not area.encloses(r):
			continue
		if best == null or absf(r.get_center().y - y) < absf(best.get_global_rect().get_center().y - y):
			best = b
	return best
