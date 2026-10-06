class_name Sfx
extends RefCounted
## Acesso ao autoload AudioManager sem citar o nome dele no código: com --script (testes e
## ferramentas) o Godot compila o script principal antes de registrar os autoloads, e qualquer
## script que escreva "Sfx." deixa de compilar. Sem o autoload (testes), tudo vira nada.


static func _a() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null


static func click() -> void:
	var a := _a()
	if a != null:
		a.click()


static func play(sound: String, volume_db: float = 0.0) -> void:
	var a := _a()
	if a != null:
		a.play(sound, volume_db)


static func vibrate(ms: int) -> void:
	var a := _a()
	if a != null:
		a.vibrate(ms)


static func goal(importance: float, ours: bool) -> void:
	var a := _a()
	if a != null:
		a.goal(importance, ours)


static func start_music() -> void:
	var a := _a()
	if a != null:
		a.start_music()


static func apply_volumes() -> void:
	var a := _a()
	if a != null:
		a.apply_volumes()


static func screen_changed(screen_name: String) -> void:
	var a := _a()
	if a != null:
		a.screen_changed(screen_name)


static func music_ready(track: int) -> bool:
	var a := _a()
	return a != null and bool(a.music_ready(track))


static func match_muted() -> bool:
	var a := _a()
	return a != null and bool(a.match_muted())


static func set_match_muted(muted: bool) -> void:
	var a := _a()
	if a != null:
		a.set_match_muted(muted)


static func crowd_start(home: Dictionary, away: Dictionary, fill: float, away_share: float) -> void:
	var a := _a()
	if a != null:
		a.crowd_start(home, away, fill, away_share)


static func crowd_stop(now := false) -> void:
	var a := _a()
	if a != null:
		a.crowd_stop(now)


static func crowd_event(kind: String, side: int) -> void:
	var a := _a()
	if a != null:
		a.crowd_event(kind, side)


static func crowd_clip(side: int, kind: String) -> bool:
	var a := _a()
	return a != null and bool(a.crowd_clip(side, kind))


static func stop_all() -> void:
	var a := _a()
	if a != null:
		a.stop_all()


static func crowd_resume() -> void:
	var a := _a()
	if a != null:
		a.crowd_resume()
