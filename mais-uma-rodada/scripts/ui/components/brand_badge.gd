class_name BrandBadge
extends Control
## Logo de uma marca do BrandCatalog: fundo na cor da marca, símbolo e nome.
## Serve para telas de patrocínio, sala de imprensa e posts (passe o dicionário da marca ou do contrato).

var brand: Dictionary = {}:
	set(v):
		brand = v
		queue_redraw()


static func make(b: Dictionary, min_size: Vector2 = Vector2(190, 48)) -> BrandBadge:
	var x := BrandBadge.new()
	var full := b.duplicate()
	var e := BrandCatalog.find(String(b.get("n", "")))
	for k in ["m", "logo", "s"]:
		if String(full.get(k, "")) == "" and e.has(k):
			full[k] = e[k]
	x.brand = full
	x.custom_minimum_size = min_size
	return x


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var bg := Color(String(brand.get("c", "#FFFFFF")))
	var fg := Color(String(brand.get("t", "#111111")))
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	draw_style_box(sb, r)
	var mark := String(brand.get("m", ""))
	if mark == "":
		mark = String(brand.get("logo", ""))
	var font := get_theme_font(&"font", &"Caps")
	var txt := String(brand.get("n", "")).to_upper()
	var fs := int(clampf(size.y * 0.36, 9.0, 22.0))
	var mu := size.y * 0.24
	var mark_w := mu * 2.7 if BrandMark.has(mark) else 0.0
	var maxw := size.x - 20.0 - mark_w
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > maxw:
		fs = maxi(7, int(fs * maxw / tw))
		tw = font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := (size.x - tw - mark_w) * 0.5
	if mark_w > 0.0:
		BrandMark.draw(self, mark, Vector2(x0 + mu, size.y * 0.5), mu, fg, bg)
	draw_string(font, Vector2(x0 + mark_w, size.y * 0.5 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
