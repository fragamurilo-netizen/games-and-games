extends Node
## Ver load_profile.gd.

const SLOT := 19 # slot próprio: outras ferramentas usam o 9
var keep := false


func _ready() -> void:
	_run()


func _ms(t0: int) -> float:
	return (Time.get_ticks_usec() - t0) / 1000.0


func _run() -> void:
	await get_tree().process_frame
	if not keep or not FileAccess.file_exists(SaveManager.slot_path(SLOT)):
		var t0 := Time.get_ticks_usec()
		var w0 := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
		print("gerar mundo: %.0f ms" % _ms(t0))
		AppSettings.tutorial_done = true
		t0 = Time.get_ticks_usec()
		GameManager.start_career(w0, w0.clubs_in_league("BRA1")[2].id, "Teste", GameWorld.DIFF_NORMAL, SLOT)
		print("começar carreira: %.0f ms" % _ms(t0))
		GameManager.slot = -1
		for i in 3:
			GameManager.play_instant()
		SaveManager.save_world(w0, SLOT)
	var path := SaveManager.slot_path(SLOT)
	print("save: %d KB" % (FileAccess.get_file_as_bytes(path).size() / 1024))
	var total := Time.get_ticks_usec()
	var t := Time.get_ticks_usec()
	var f := FileAccess.open(path, FileAccess.READ)
	f.get_buffer(4)
	var n_clubs := f.get_32()
	var n_players := f.get_32()
	var clubs: Array = []
	for i in n_clubs:
		clubs.append(Club.from_dict(SaveManager._read_block(f)))
	print("clubes (%d): %.0f ms" % [n_clubs, _ms(t)])
	t = Time.get_ticks_usec()
	var sizes := PackedInt32Array()
	sizes.resize(n_players)
	var blobs: Array = []
	blobs.resize(n_players)
	for i in n_players:
		var raw_n := f.get_32()
		var z_n := f.get_32()
		sizes[i] = raw_n
		blobs[i] = f.get_buffer(z_n)
	print("ler blocos dos jogadores (%d): %.0f ms" % [n_players, _ms(t)])
	t = Time.get_ticks_usec()
	var raw := Parallel.map_chunks(n_players, func(a: int, b: int) -> Array:
		var out: Array = []
		for i in range(a, b):
			out.append(bytes_to_var((blobs[i] as PackedByteArray).decompress(sizes[i], FileAccess.COMPRESSION_ZSTD)))
		return out, 128)
	print("descomprimir + bytes_to_var (paralelo): %.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var players := Parallel.map_chunks(n_players, func(a: int, b: int) -> Array:
		var out: Array = []
		for i in range(a, b):
			out.append(Player.from_dict(raw[i], true))
		return out, 128)
	print("Player.from_dict (paralelo): %.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	var head: Variant = SaveManager._read_block(f)
	f.close()
	print("cabeçalho do mundo: %.0f ms" % _ms(t))
	t = Time.get_ticks_usec()
	head = SaveManager.migrate(head)
	var w := GameWorld.from_dict(head, clubs, players)
	print("GameWorld.from_dict: %.0f ms" % _ms(t))
	var steps := [
		["ClubGenerator.upgrade_crests", func(): ClubGenerator.upgrade_crests(w)],
		["KitDesign.ensure_all", func(): KitDesign.ensure_all(w)],
		["DropIns.apply_world", func(): DropIns.apply_world(w)],
		["WorldGenerator.forget_static_state", func(): WorldGenerator.forget_static_state()],
		["HeartClubs.ensure_all", func(): HeartClubs.ensure_all(w)],
		["SponsorManager.ensure_all", func(): SponsorManager.ensure_all(w)],
		["Economy.ensure", func(): Economy.ensure(w)],
		["LeagueReputation.ensure", func(): LeagueReputation.ensure(w)],
		["Valuation.refresh_shift", func(): Valuation.refresh_shift(w)],
		["MarketReality.ensure_world", func(): MarketReality.ensure_world(w)],
	]
	for s in steps:
		t = Time.get_ticks_usec()
		(s[1] as Callable).call()
		print("%s: %.0f ms" % [s[0], _ms(t)])
	print("TOTAL (medido por partes): %.0f ms" % _ms(total))
	t = Time.get_ticks_usec()
	var w2 := SaveManager.load_world(SLOT)
	print("SaveManager.load_world inteiro: %.0f ms (%s)" % [_ms(t), "ok" if w2 != null else "falhou"])
	t = Time.get_ticks_usec()
	var ok := GameManager.load_career(SLOT)
	print("GameManager.load_career: %.0f ms (%s)" % [_ms(t), ok])
	get_tree().quit()
