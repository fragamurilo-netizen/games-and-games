extends SceneTree
## Folha com os símbolos das marcas (BrandMark), para conferir o desenho.
## xvfb-run -a godot --path . --resolution 1500x1100 --script res://tools/brand_sheet.gd -- --out=/tmp/marcas.png
## Opções: --suppliers (só fornecedoras), --page=N (páginas de --per=96 marcas do catálogo),
## --cell=120, --cols=12, --logo (composição completa com o nome, BrandLogo, se existir)

var _out := "user://marcas.png"


func _initialize() -> void:
	var suppliers := false
	var logo := false
	var page := 0
	var per := 96
	var cell := 120
	var cols := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a == "--logo":
			logo = true
		elif a == "--suppliers":
			suppliers = true
		elif a.begins_with("--page="):
			page = int(a.substr(7))
		elif a.begins_with("--per="):
			per = int(a.substr(6))
		elif a.begins_with("--cell="):
			cell = int(a.substr(7))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.theme = load("res://assets/theme/main_theme.tres")
	var list: Array = []
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/brands.json"))
	if suppliers:
		for s: Dictionary in data["suppliers"]:
			list.append(s)
	else:
		for code: String in data["nations"]:
			for b: Dictionary in data["nations"][code].get("brands", []):
				list.append(b)
		for b: Dictionary in data["global"]:
			list.append(b)
		list = list.slice(page * per, (page + 1) * per)
	var bg := ColorRect.new()
	bg.color = Color("#E9E7E2")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var sheet := Sheet.new()
	sheet.list = list
	sheet.cell = cell
	sheet.cols = cols
	sheet.logo = logo
	sheet.size = Vector2(4000, 4000)
	root.add_child(sheet)


var _frames := 0


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("ok ", _out)
		return true
	return false


class Sheet:
	extends Control
	var list: Array = []
	var cell := 120
	var cols := 12
	var logo := false

	func _draw() -> void:
		if logo:
			_draw_logos()
			return
		var font := get_theme_font(&"font", &"Small")
		for i in list.size():
			var b: Dictionary = list[i]
			var x := 8 + (i % cols) * (cell + 8)
			var y := 8 + (i / cols) * (cell + 26)
			var r := Rect2(x, y, cell, cell)
			var c1 := Color(String(b.get("c", "#FFFFFF")))
			var c2 := Color(String(b.get("t", "#111111")))
			var sb := StyleBoxFlat.new()
			sb.bg_color = c1
			sb.set_corner_radius_all(10)
			if c1.get_luminance() > 0.9:
				sb.border_color = Color(0, 0, 0, 0.12)
				sb.set_border_width_all(1)
			draw_style_box(sb, r)
			BrandMark.draw_brand(self, b, r.get_center(), cell * 0.32, c2, c2.lerp(c1, 0.35) if absf(c2.get_luminance() - c1.get_luminance()) > 0.5 else c2)
			draw_string(font, Vector2(x, y + cell + 16), String(b.get("n", "")), HORIZONTAL_ALIGNMENT_CENTER, cell, 11, Color("#333333"))

	## Composições completas: cartão na cor da marca e a mesma marca impressa num tecido claro e num escuro.
	func _draw_logos() -> void:
		var font := get_theme_font(&"font", &"Small")
		var w := cell * 2
		var h := int(cell * 0.62)
		for i in list.size():
			var b: Dictionary = list[i]
			var x := 8 + (i % cols) * (w + 10)
			var y := 8 + (i / cols) * (h * 3 + 30)
			var c1 := Color(String(b.get("c", "#FFFFFF")))
			var c2 := Color(String(b.get("t", "#111111")))
			var r := Rect2(x, y, w, h)
			var sb := StyleBoxFlat.new()
			sb.bg_color = c1
			sb.set_corner_radius_all(8)
			draw_style_box(sb, r)
			BrandLogo.draw(self, b, r.grow(-h * 0.16), c2)
			var r2 := Rect2(x, y + h + 4, w, h)
			draw_rect(r2, Color("#F3F1EC"))
			var ink := c1 if c1.get_luminance() < 0.75 else c2
			BrandLogo.draw(self, b, r2.grow(-h * 0.16), ink, c2 if absf(c2.get_luminance() - 0.95) > 0.3 else ink)
			var r3 := Rect2(x, y + h * 2 + 8, w, h)
			draw_rect(r3, Color("#14171C"))
			var ink3 := c1 if c1.get_luminance() > 0.3 else c2
			if ink3.get_luminance() < 0.3:
				ink3 = Color.WHITE
			BrandLogo.draw(self, b, r3.grow(-h * 0.16), ink3)
			draw_string(font, Vector2(x, y + h * 3 + 24), String(b.get("n", "")), HORIZONTAL_ALIGNMENT_CENTER, w, 11, Color("#333333"))
