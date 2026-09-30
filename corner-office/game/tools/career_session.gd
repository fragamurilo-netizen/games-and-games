extends SceneTree
## Local web adapter, using the same Godot services/save format as native UI.
## Bible §§15,17–18. Server serializes access and commits save only after success.
func _initialize() -> void:
	# Runtime load: CLI entry scripts are parsed before autoload identifiers.
	var generator: GDScript=load("res://simulation/world/world_generator.gd")
	var args:=OS.get_cmdline_user_args()
	if args.size()!=3:quit(1);return
	var config: Variant=JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not config is Dictionary:quit(1);return
	var actions: GDScript=load("res://simulation/career/career_actions.gd")
	# Idem: o builder chega em Rankings, que emite pelo EventBus (autoload).
	var builder: GDScript=load("res://presentation/fight/fight_replay_builder.gd")
	var replay_player: GDScript=load("res://presentation/fight/fight_replay_player.gd")
	var action:=str(config.get("action","state"))
	var world: WorldState
	if action=="new":
		world=generator.generate(int(config.get("seed",2027)),"regional_promoter")
	elif FileAccess.file_exists(args[2]):
		world=SaveSystem.decode(FileAccess.get_file_as_string(args[2]))
		if world==null:_reply(args[1],{"ok":false,"error":"Save inválido. O arquivo existente foi preservado."});return
	else:
		_reply(args[1],{"ok":action=="state","has_save":false,"message":"Comece uma carreira regional."});return
	if action=="replay":
		var fight: Fight=world.fights.get(str(config.get("fight_id","")))
		if fight==null or fight.status!="completed":_reply(args[1],{"ok":false,"error":"Luta ainda não concluída."});return
		var replay: Dictionary=builder.build(world,fight)
		var player: Variant=replay_player.new()
		if not player.load_replay(replay):push_error(str(player.errors));quit(1);return
		_reply(args[1],{"ok":true,"replay":replay});return
	var result: Dictionary={"ok":true,"message":"Carreira regional iniciada."} if action=="new" else actions.perform(world,action,config)
	if result.ok and action not in ["state","evaluate"]:
		var file:=FileAccess.open(args[2],FileAccess.WRITE)
		if file==null:quit(1);return
		file.store_string(SaveSystem.encode(world));file.close()
	result.has_save=true
	result.world=actions.snapshot(world)
	_reply(args[1],result)

func _reply(path: String, data: Dictionary) -> void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:quit(1);return
	file.store_string(JSON.stringify(data));file.close()
	quit()
