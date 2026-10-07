extends SceneTree
## Folha de retratos de lutadores para conferir o gerador (luz, corpo, rostos femininos).
## xvfb-run -a -s "-screen 0 1600x1600x24" godot --path . --resolution 1500x900 --script res://tools/face_sheet.gd -- --out=/tmp/lutadores.png
## Opções: --size=N (lado de cada retrato), --cols=N, --seed=N, --eth=1,7,4 (uma linha por etnia),
## --fem (só mulheres), --mix (alterna homens e mulheres por linha), --ages=22,26,…,
## --weights=0,3,7 (categoria de peso por coluna, 0 = mosca … 7 = pesado).

var _out := "user://lutadores.png"


func _initialize() -> void:
	var px := 160
	var cols := 8
	var seed_base := 4000
	var eths: Array = [1, 7, 4, 8, 3, 6]
	var ages: Array = [22, 25, 27, 29, 31, 33, 35, 38]
	var weights: Array = []
	var fem_mode := 0 # 0 homens, 1 mulheres, 2 alterna por linha
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--size="):
			px = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
		elif a.begins_with("--eth="):
			eths = Array(a.substr(6).split(",")).map(func(x): return int(x))
		elif a.begins_with("--ages="):
			ages = Array(a.substr(7).split(",")).map(func(x): return int(x))
		elif a.begins_with("--weights="):
			weights = Array(a.substr(10).split(",")).map(func(x): return int(x))
		elif a == "--fem":
			fem_mode = 1
		elif a == "--mix":
			fem_mode = 2
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var bg := ColorRect.new()
	bg.color = Color("#0B0B0D")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	for r in eths.size():
		var e: int = eths[r]
		var fem := fem_mode == 1 or (fem_mode == 2 and r % 2 == 1)
		for k in cols:
			var v := PortraitView.new()
			v.position = Vector2(6 + k * (px + 6), 6 + r * (px + 6))
			v.size = Vector2(px, px)
			var look := {}
			if fem:
				look["fem"] = 1
			var wc: int = weights[k % weights.size()] if not weights.is_empty() else (k * 7) / maxi(1, cols - 1)
			look["wt"] = wc / 7.0
			v.set_face(seed_base + e * 97 + k * 7919 + (31 if fem else 0), e, ages[k % ages.size()], look)
			root.add_child(v)
	process_frame.connect(_shot, CONNECT_ONE_SHOT)


func _shot() -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(_out)
	print("ok ", _out)
	quit()
