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
	var pad := Vector2(size.y * 0.22, size.y * 0.18)
	BrandLogo.draw(self, brand, Rect2(r.position + pad, r.size - pad * 2.0), fg)
