extends SceneTree
## Hub navigation check with a real scene tree (the unit runner has none):
##   godot --headless --path game -s res://tools/check_navigation.gd
## Exits 1 on failure.
var failures: Array=[]
func check(ok: bool, message: String) -> void:
	if not ok:failures.append(message)
func check_eq(a, b, message: String) -> void:
	if a!=b:failures.append("%s (esperado %s, obtido %s)"%[message,b,a])
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	root.get_node("Game").new_game(2031)
	var scene: Control=load("res://ui/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var world=root.get_node("Game").world
	var fighter_id: String=world.player_org().roster[0]
	check_eq(scene._current,"home","Starts on the hub")
	scene._navigate("fighters",{"fighter_id":fighter_id})
	check_eq(scene._current,"fighters","Hub opens the roster")
	check_eq(scene._screens["fighters"].selected_fighter,fighter_id,"Straight to the profile")
	scene._navigate("fighters",{"mode":"official","division":world.fighters[fighter_id].division})
	check_eq(scene._screens["fighters"].mode,"official","Profile opens its division ranking")
	check_eq(scene._screens["fighters"].selected_fighter,"","Ranking view, not the profile")
	check(scene.go_back(),"Back from ranking")
	check_eq(scene._screens["fighters"].selected_fighter,fighter_id,"Back restores the profile")
	check(scene.go_back(),"Back from profile")
	check_eq(scene._current,"home","Back returns to the hub")
	check(not scene.go_back(),"Nothing left to go back to")
	scene._navigate("fighters",{"fighter_id":fighter_id})
	scene._tab_pressed("fighters")
	check_eq(scene._screens["fighters"].selected_fighter,"","Active tab resets to the list")
	scene._navigate("home",{"open":"Agenda do mercado"})
	check_eq(scene._screens["home"].collapsed.get("Agenda do mercado"),false,"Hub card opens its section")
	for f in failures:print("FAIL "+f)
	print("NAVIGATION %s"%("OK" if failures.is_empty() else "FAILED"))
	quit(0 if failures.is_empty() else 1)
