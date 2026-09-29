extends SceneTree
## Runner headless:
##   godot --headless --path game -s res://tests/run_tests.gd [-- unit|sim]
## Sai com código 1 se qualquer teste falhar (usado na CI).

const SUITES := ["unit", "sim"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var suites: Array = SUITES if args.is_empty() else args
	var passed := 0
	var failed := 0
	for suite in suites:
		for path in _find_tests("res://tests/%s" % suite):
			var script: GDScript = load(path)
			if script == null or not script.can_instantiate():
				failed += 1
				print("  FAIL %s (não compilou)" % path.get_file())
				continue
			var instance: TestCase = script.new()
			for m in instance.get_method_list():
				if not m.name.begins_with("test_"):
					continue
				instance.failures.clear()
				instance.checks = 0
				instance.call(m.name)
				if instance.checks == 0:
					instance.failures.append("nenhuma verificação executada (erro de script?)")
				if instance.failures.is_empty():
					passed += 1
					print("  ok   %s::%s" % [path.get_file(), m.name])
				else:
					failed += 1
					print("  FAIL %s::%s" % [path.get_file(), m.name])
					for f in instance.failures:
						print("       - " + f)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


func _find_tests(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append("%s/%s" % [dir_path, f])
	out.sort()
	return out
