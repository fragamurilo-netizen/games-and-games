extends Node
## Arquivos temporários exclusivos deste processo. Não modifica imagens do jogador.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("ASSET_CACHE_FAIL: " + message)

func _ready() -> void:
	CustomAssets.clear_cache()
	var dir := "user://asset_cache_test_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(dir)
	var img := Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLUE)
	var retained: Texture2D
	for i in 40:
		var path := dir.path_join("%d.png" % i)
		check(img.save_png(path) == OK, "write temporary image")
		var tex := CustomAssets.texture(path)
		check(tex != null and tex.get_size() == Vector2(1024, 1024), "load complete image")
		if i == 0:
			retained = tex
		check(CustomAssets._cache_bytes <= CustomAssets.MAX_CACHE_BYTES, "texture byte budget")
	check(CustomAssets._cache.size() == 6, "24 MiB retains six 4 MiB images")
	check(retained.get_size() == Vector2(1024, 1024), "open view keeps evicted texture")
	var reused := dir.path_join("34.png")
	var reused_texture := CustomAssets.texture(reused)
	CustomAssets.texture(dir.path_join("0.png"))
	check(CustomAssets._cache.has(reused), "recently reused texture survives eviction")
	check(not CustomAssets._cache.has(dir.path_join("35.png")), "oldest unused texture is evicted")
	check(CustomAssets.texture(reused) == reused_texture, "cache hit preserves texture identity")
	for i in CustomAssets.MAX_CACHE_ENTRIES + 20:
		CustomAssets.texture(dir.path_join("missing_%d.png" % i))
	check(CustomAssets._cache.size() == CustomAssets.MAX_CACHE_ENTRIES, "missing files also obey entry budget")
	check(CustomAssets._cache_order.size() == CustomAssets._cache.size(), "eviction bookkeeping stays consistent")
	var large := Image.create(4096, 2048, false, Image.FORMAT_RGBA8)
	large.fill(Color.RED)
	var large_path := dir.path_join("large.png")
	large.save_png(large_path)
	var reduced := CustomAssets.texture(large_path)
	check(reduced.get_size() == Vector2(1280, 640), "full paths preserve aspect while limiting GPU size")
	CustomAssets.clear_cache()
	check(CustomAssets._cache.is_empty() and CustomAssets._cache_order.is_empty() and CustomAssets._cache_sizes.is_empty() and CustomAssets._cache_bytes == 0, "clear releases cache and accounting")
	check(reduced.get_width() == 1280 and retained.get_width() == 1024, "clearing cache preserves textures in active views")
	for i in 40:
		DirAccess.remove_absolute(dir.path_join("%d.png" % i))
	DirAccess.remove_absolute(large_path)
	DirAccess.remove_absolute(dir)
	print("ASSET_CACHE_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
