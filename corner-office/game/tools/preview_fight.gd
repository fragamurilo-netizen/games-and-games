extends SceneTree
## godot --headless --path game -s res://tools/preview_fight.gd -- input.json output.json
## Laboratory matchup: outside career eligibility/matchmaking, same combat engine.
func _initialize() -> void:
	# Runtime load: CLI entry scripts are parsed before autoload identifiers.
	var generator: GDScript=load("res://simulation/world/world_generator.gd")
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected input.json output.json")
		quit(1)
		return
	var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not config is Dictionary:
		quit(1)
		return
	var world: WorldState = generator.generate(int(config.get("seed",2027)),"regional_promoter",false)
	var fight := Fight.new()
	fight.id = "lab_%d" % world.seed_value
	fight.fighter_a_id = str(config.get("red","ftr_carter"))
	fight.fighter_b_id = str(config.get("blue","ftr_moreira"))
	fight.rounds = int(config.get("rounds",3))
	fight.status = "booked"
	if not world.fighters.has(fight.fighter_a_id) or not world.fighters.has(fight.fighter_b_id) or fight.fighter_a_id == fight.fighter_b_id:
		quit(1)
		return
	var event := FightEvent.new()
	event.id = "lab_event"
	event.organization_id = str(config.get("organization","org_crown"))
	if not world.organizations.has(event.organization_id):
		quit(1)
		return
	world.add("events",event)
	fight.event_id = event.id
	var styles: Dictionary = ContentDB.load_json("fight_tuning.json").styles
	for item: Array in [["red_style",fight.fighter_a_id],["blue_style",fight.fighter_b_id]]:
		if config.has(item[0]) and not str(config[item[0]]).is_empty():
			if not styles.has(config[item[0]]):
				quit(1)
				return
			world.fighters[item[1]].martial_base = config[item[0]]
	world.add("fights",fight)
	FightEngine.new().simulate(world,fight)
	var replay := FightReplayBuilder.build(world,fight)
	var player := FightReplayPlayer.new()
	if not player.load_replay(replay):
		push_error(str(player.errors))
		quit(1)
		return
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	file.store_string(JSON.stringify(replay)+"\n")
	print("SIMULATED %s: %s / %s R%d %ds (%d events)" % [fight.id,fight.method,fight.method_detail,fight.end_round,fight.end_time_s,replay.events.size()])
	quit()
