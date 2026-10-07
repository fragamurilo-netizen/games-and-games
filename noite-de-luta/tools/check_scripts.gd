extends SceneTree
## Compila todos os scripts do projeto e reporta erros (uso: godot --headless --script res://tools/check_scripts.gd)

func _initialize() -> void:
	var failed := 0
	var total := 0
	for path in _list("res://scripts") + _list("res://tests") + _list("res://tools"):
		total += 1
		var s: Script = load(path)
		if s == null or not s.can_instantiate():
			failed += 1
			print("FALHOU: ", path)
	print("scripts: %d, com erro: %d" % [total, failed])
	quit(1 if failed > 0 else 0)


func _list(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_list(dir + "/" + sub))
	return out
