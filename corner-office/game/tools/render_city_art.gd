extends SceneTree
## Renderiza as ilustrações de cidade para revisão (CityArt, Game Design Bible §16).
##   godot --headless --path game -s res://tools/render_city_art.gd -- <pasta> [cidade_id ...]
## Grava cada cidade em <pasta>/<id>.png e uma folha de contato contact_sheet.png.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://city_art_review"
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = args.slice(1) if args.size() > 1 else Universe.cities().map(func(c): return c.id)
	var thumb := Vector2i(320, 180)
	var cols := 6
	var sheet := Image.create(thumb.x * cols, thumb.y * int(ceil(ids.size() / float(cols))), false, Image.FORMAT_RGB8)
	var started := Time.get_ticks_msec()
	for i in ids.size():
		var img := CityArt.render(Universe.city(ids[i]))
		img.save_png("%s/%s.png" % [out, ids[i]])
		img.resize(thumb.x, thumb.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, thumb), Vector2i((i % cols) * thumb.x, (i / cols) * thumb.y))
	sheet.save_png("%s/contact_sheet.png" % out)
	print("%d cidades em %d ms" % [ids.size(), Time.get_ticks_msec() - started])
	quit()
