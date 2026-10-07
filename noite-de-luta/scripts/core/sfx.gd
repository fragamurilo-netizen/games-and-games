class_name Sfx
extends RefCounted
## Acesso ao autoload AudioManager sem citar o nome dele no código: com --script (testes e
## ferramentas) o Godot compila o script principal antes de registrar os autoloads. Sem o
## autoload, tudo vira nada.


static func _a() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("AudioManager") if tree != null else null


static func click() -> void:
	play("click", -8.0)


static func play(sound: String, volume_db: float = 0.0) -> void:
	var a := _a()
	if a != null:
		a.play(sound, volume_db)


static func vibrate(ms: int) -> void:
	var a := _a()
	if a != null:
		a.vibrate(ms)


static func screen_changed(_screen_name: String) -> void:
	pass
