extends SceneTree
## Monta as capturas da ficha da Google Play (store/screenshots) a partir das telas do tour:
## fundo azul-noite, uma frase curta em Barlow Condensed no topo e a tela do jogo embaixo, em
## 1080 × 1920 (as 8 telas do plano de lançamento, store/plano-de-lancamento.html).
##   1. xvfb-run godot --path . --resolution 1080x1920 --script res://tools/screenshot_tour.gd -- --out=/tmp/tour
##   2. xvfb-run godot --path . --resolution 1080x1920 --script res://tools/store_frames.gd -- --in=/tmp/tour --out=../store/screenshots
## Em inglês: rode o tour com --lang=en e este com --lang=en (as frases mudam).

const FRAMES := [
	["01", "08_partida", "Cada minuto conta", "Every minute counts"],
	["02", "09_gol", "Gol aos 90+4. Comemora!", "90+4 winner. Celebrate!"],
	["03", "14_tabela", "Suba, caia, brigue pelo título", "Go up, go down, fight for the title"],
	["04", "11b_formacao", "Sua tática, suas regras", "Your tactics, your rules"],
	["05", "42_negociacao", "Negocie cada centavo", "Haggle over every cent"],
	["06", "06_perfil", "16 mil jogadores com história", "16,000 players with a story"],
	["07", "32_base", "Revele o próximo craque", "Discover the next star"],
	["08", "44_historia_premios", "Encha a sala de troféus", "Fill the trophy room"],
]
const W := 1080
const H := 1920
const TOP := 330 # faixa da frase

var opt_in := ""
var opt_out := ""
var opt_lang := "pt"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		if kv.size() == 2:
			set("opt_" + kv[0], kv[1])
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	OS.low_processor_usage_mode = false
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(W, H)
	DirAccess.make_dir_recursive_absolute(opt_out)
	var font: FontFile = load("res://assets/fonts/BarlowCondensed-ExtraBold.woff2")
	var ok := 0
	for fr in FRAMES:
		var src := "%s/%s.png" % [opt_in, fr[1]]
		if not FileAccess.file_exists(src):
			push_error("captura ausente: " + src)
			continue
		var canvas := _frame(Image.load_from_file(src), String(fr[3] if opt_lang == "en" else fr[2]), font)
		root.add_child(canvas)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8) # a Play não quer transparência
		img.save_png("%s/%s_%s.png" % [opt_out, fr[0], String(fr[1]).get_slice("_", 1)])
		canvas.queue_free()
		ok += 1
		print("[loja] ", fr[0], " ", fr[1])
	print("STORE_FRAMES %d de %d" % [ok, FRAMES.size()])
	quit(0 if ok == FRAMES.size() else 1)


func _frame(shot: Image, caption: String, font: FontFile) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("#162231"))
	g.set_color(1, Color("#0E1621"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	bg.texture = gt
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(W, H)
	c.add_child(bg)
	# Frase: branco-giz, com o traço dourado embaixo (um destaque por tela).
	var l := Label.new()
	l.text = caption.to_upper()
	l.add_theme_font_override(&"font", font)
	# Uma linha sempre que der: a fonte encolhe até a frase caber (mínimo 64).
	var fs := 96
	while fs > 64 and font.get_string_size(caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > W - 120:
		fs -= 2
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", Color("#EAF0F6"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(60, 40)
	l.size = Vector2(W - 120, TOP - 120)
	c.add_child(l)
	var bar := ColorRect.new()
	bar.color = Color("#FFC940")
	bar.size = Vector2(120, 8)
	bar.position = Vector2((W - 120) / 2.0, TOP - 58)
	c.add_child(bar)
	# Tela do jogo com cantos arredondados, recortada pelo próprio painel.
	var avail_h := H - TOP - 40
	var sc := minf(float(avail_h) / shot.get_height(), float(W - 120) / shot.get_width())
	var sz := Vector2(shot.get_width(), shot.get_height()) * sc
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.set_corner_radius_all(36)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override(&"panel", sb)
	p.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	p.size = sz
	p.position = Vector2((W - sz.x) / 2.0, TOP)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(shot)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = sz
	p.add_child(tr)
	c.add_child(p)
	return c
