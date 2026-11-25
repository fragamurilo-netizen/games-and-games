extends Node
## Deterministic corruption/storage-failure tests outside the five user slots.
const SLOT := 96
var failures := 0
var save_errors := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("SAVE_RESILIENCE_FAIL: " + message)

func _ready() -> void:
	_run()

func _run() -> void:
	SaveManager.delete_slot(SLOT)
	var w := GameWorld.new()
	w.world_type = "aleatorio"
	w.season = SeasonState.new()
	var c := Club.new()
	c.id = 0
	c.name = "Save Test"
	c.short_name = c.name
	c.league_id = "BRA1"
	c.nation = "BRA"
	w.clubs.append(c)
	w.user_club_id = 0
	check(SaveManager.save_world(w, SLOT) == OK, "initial save")
	var path := SaveManager.slot_path(SLOT)
	var original := FileAccess.get_file_as_bytes(path)
	var loaded := SaveManager.load_world(SLOT)
	check(loaded != null and loaded.year == w.year, "valid v3 round trip")
	loaded = null
	var incomplete := SaveManager.Writer.open(SLOT, 2, 0)
	incomplete.add(c.to_dict())
	check(incomplete.finish(w) != OK, "incomplete writer cannot replace a complete save")
	check(FileAccess.get_file_as_bytes(path) == original, "failed save preserves original bytes")
	check(not FileAccess.file_exists(path + ".tmp"), "incomplete temporary file removed")
	var invalid := SaveManager.Writer.open(SLOT, 1, 0)
	invalid.add_encoded([2, "not bytes"])
	check(invalid.finish(w) != OK, "invalid encoded block rejected")
	check(FileAccess.get_file_as_bytes(path) == original, "invalid block preserves original")
	# Create a valid backup before truncating/corrupting the current slot.
	w.year += 1
	check(SaveManager.save_world(w, SLOT) == OK, "second save creates backup")
	for n in [4, 8, 12, 20, original.size() - 1]:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(original.slice(0, n))
		f.close()
		check(SaveManager._load_v3(path) == null, "reject truncated v3 at byte " + str(n))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer("MUR3".to_ascii_buffer())
	f.store_32(0x7fffffff)
	f.store_32(0x7fffffff)
	f.close()
	check(SaveManager._load_v3(path) == null, "hostile record counts rejected before allocation")
	loaded = SaveManager.load_world(SLOT)
	check(loaded != null and loaded.year == w.year - 1, "corrupted current file recovers prior backup")
	loaded = null
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(original)
	f.seek(12)
	f.store_32(0x7fffffff)
	f.close()
	check(SaveManager._load_v3(path) == null, "oversized decompression length rejected")
	# A queued save must never attach itself to a later career or a null world.
	GameManager.world = w
	GameManager.slot = SLOT
	GameManager._save_busy = true
	GameManager._run_save.call_deferred(GameManager._save_gen)
	GameManager._cancel_save()
	GameManager.world = null
	await get_tree().process_frame
	check(GameManager._save_writer == null and GameManager._save_phase == 0, "cancelled deferred save does not reopen writer")
	GameManager.world = w
	GameManager.slot = SLOT
	GameManager.save_failed.connect(func(): save_errors += 1)
	# A directory at the temporary-file path deterministically reproduces an
	# unwritable save destination without changing machine permissions/storage.
	DirAccess.make_dir_absolute(path + ".tmp")
	GameManager._save_dirty = true
	check(not GameManager.save_blocking(), "blocking save reports storage failure")
	check(GameManager._save_dirty and save_errors == 1, "failed save retains pending progress and signals UI")
	var closed := {"yes": false}
	GameManager.close_career_async(func(): closed["yes"] = true)
	while GameManager.is_busy():
		await get_tree().process_frame
	await get_tree().process_frame
	check(GameManager.world == w and not closed["yes"], "failed exit save keeps career open")
	check(GameManager._save_dirty and save_errors >= 2, "failed exit remains retryable")
	DirAccess.remove_absolute(path + ".tmp")
	check(GameManager.save_blocking(), "save recovers after storage is writable")
	check(not GameManager._save_dirty, "successful retry clears pending progress")
	GameManager._cancel_save()
	GameManager.world = null
	GameManager.slot = -1
	SaveManager.delete_slot(SLOT)
	print("SAVE_RESILIENCE_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
