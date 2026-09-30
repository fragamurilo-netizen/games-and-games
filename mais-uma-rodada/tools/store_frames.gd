extends SceneTree
## Monta as capturas da ficha da Google Play (store/screenshots): fundo ardósia (DESIGN.md), uma
## frase curta em giz no topo e a tela do jogo embaixo, em 1080 × 1920.
##   1. Telas: xvfb-run godot --path . --resolution 1080x1920 --script res://tools/design_shots.gd --
##      --out=/tmp/loja --only=hub,tactics,squad,player,~buy,table,club:history --rounds=6
##   2. Partida: tools/match_shots.gd na mesma resolução; copie um quadro como /tmp/loja/partida.png
##   3. xvfb-run godot --path . --resolution 1080x1920 --script res://tools/store_frames.gd -- --in=/tmp/loja --out=../store/screenshots
## Em inglês: rode o tour com --lang=en e este com --lang=en (as frases mudam).

const FRAMES := [
	["01", "partida", "Cada minuto conta", "Every minute counts"],
	["02", "hub", "Dia de jogo: você decide", "Matchday: your call"],
	["03", "tactics", "Sua tática, suas regras", "Your tactics, your rules"],
	["04", "squad", "Conheça cada jogador", "Know every player"],
	["05", "player", "Jogadores com história", "Players with a story"],
	["06", "dlg_buy", "Negocie cada centavo", "Haggle over every cent"],
	["07", "table", "Suba, caia, brigue pelo título", "Go up, go down, fight for the title"],
	["08", "club_history", "Escreva a história do clube", "Write your club's history"],
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
	var font: Font = ThemeDB.get_project_theme().get_font(&"font",&"Title")
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
		img.save_png("%s/%s_%s.png" % [opt_out, fr[0], String(fr[1]).replace("dlg_", "")])
		canvas.queue_free()
		ok += 1
		print("[loja] ", fr[0], " ", fr[1])
	print("STORE_FRAMES %d de %d" % [ok, FRAMES.size()])
	quit(0 if ok == FRAMES.size() else 1)


func _frame(shot: Image, caption: String, font: Font) -> Control:
	var c := Control.new()
	c.size = Vector2(W, H)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color("#1C2024"))
	g.set_color(1, Color("#15181B"))
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
	# Frase em giz, com um traço discreto embaixo (paleta do DESIGN.md).
	var l := Label.new()
	l.text = caption.to_upper()
	l.add_theme_font_override(&"font", font)
	# Uma linha sempre que der: a fonte encolhe até a frase caber (mínimo 64).
	var fs := 96
	while fs > 64 and font.get_string_size(caption.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > W - 120:
		fs -= 2
	l.add_theme_font_size_override(&"font_size", fs)
	l.add_theme_color_override(&"font_color", Color("#F1F0EC"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector2(60, 40)
	l.size = Vector2(W - 120, TOP - 120)
	c.add_child(l)
	var bar := ColorRect.new()
	bar.color = Color("#A5ABB2")
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
