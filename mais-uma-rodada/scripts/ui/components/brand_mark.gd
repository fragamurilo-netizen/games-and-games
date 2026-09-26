class_name BrandMark
extends RefCounted
## Símbolos das marcas fictícias (BrandCatalog: campo "m" dos patrocinadores e "logo" das
## fornecedoras), desenhados com formas simples num quadrado de lado 2u centrado em `c`.
## Usado no peito da camisa, nas placas e nas faixas do alambrado.


static func has(mark: String) -> bool:
	return mark in ["curva", "barras", "triangulo", "raio", "asas", "asa", "diamante", "trevo", "estrela", "chevron", "alvo",
		"escudo", "colunas", "anel", "hexagono", "seta", "coroa", "espiga", "gota", "onda", "sinal", "sol", "chama", "guarda",
		"sacola", "pixel", "telhado", "folha", "cruz", "livro", "play", "montanha", "circulo"]


## Desenha o símbolo. Devolve false se a marca não tem símbolo (quem chama decide o que pôr).
static func draw(ci: CanvasItem, mark: String, c: Vector2, u: float, col: Color, bg: Color = Color(0, 0, 0, 0)) -> bool:
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	var lw := maxf(1.0, u * 0.26)
	match mark:
		"curva":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, 0.1), P.call(-0.6, 0.6), P.call(0.2, 0.4), P.call(1.1, -0.5), P.call(0.1, 0.1), P.call(-0.55, 0.3)]), col)
		"barras":
			for i in 3:
				var x := -0.8 + i * 0.6
				var hh := 0.5 + i * 0.35
				ci.draw_colored_polygon(PackedVector2Array([P.call(x, 0.6), P.call(x + 0.35, 0.6), P.call(x + 0.35 + hh * 0.5, 0.6 - hh), P.call(x + hh * 0.5, 0.6 - hh)]), col)
		"triangulo":
			for i in 3:
				var y := 0.6 - i * 0.45
				var hw := 1.0 - i * 0.33
				ci.draw_colored_polygon(PackedVector2Array([P.call(-hw, y), P.call(hw, y), P.call(hw * 0.8, y - 0.3), P.call(-hw * 0.8, y - 0.3)]), col)
		"raio":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.3, -0.9), P.call(-0.6, 0.15), P.call(-0.05, 0.15), P.call(-0.3, 0.9), P.call(0.6, -0.2), P.call(0.05, -0.2)]), col)
		"asas":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, -0.5), P.call(0.0, 0.1), P.call(1.0, -0.5), P.call(0.0, 0.6)]), col)
		"asa":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, 0.5), P.call(0.9, -0.7), P.call(0.4, 0.0), P.call(0.9, -0.05), P.call(0.1, 0.5)]), col)
		"diamante":
			ci.draw_polyline(PackedVector2Array([P.call(0, -0.85), P.call(0.75, 0), P.call(0, 0.85), P.call(-0.75, 0), P.call(0, -0.85)]), col, lw, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.35), P.call(0.3, 0), P.call(0, 0.35), P.call(-0.3, 0)]), col)
		"trevo":
			for a in [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]:
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * u * 0.42, u * 0.38, col)
		"estrela":
			var pts := PackedVector2Array()
			for i in 10:
				var rr := 0.95 if i % 2 == 0 else 0.4
				var a := -PI / 2.0 + i * PI / 5.0
				pts.append(c + Vector2(cos(a), sin(a)) * u * rr)
			ci.draw_colored_polygon(pts, col)
		"chevron":
			for i in 2:
				var y := -0.3 + i * 0.55
				ci.draw_polyline(PackedVector2Array([P.call(-0.8, y), P.call(0, y + 0.45), P.call(0.8, y)]), col, lw, true)
		"alvo":
			ci.draw_circle(c, u * 0.9, col)
			if bg.a > 0.0:
				ci.draw_circle(c, u * 0.58, bg)
			ci.draw_circle(c, u * 0.3, col)
		"escudo":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.8, -0.85), P.call(0.8, -0.85), P.call(0.8, 0.1), P.call(0, 0.95), P.call(-0.8, 0.1)]), col)
			if bg.a > 0.0:
				ci.draw_line(P.call(0, -0.6), P.call(0, 0.55), bg, maxf(1.0, u * 0.18))
		"colunas":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, -0.45), P.call(0, -0.95), P.call(1.0, -0.45)]), col)
			for i in 3:
				var x := -0.65 + i * 0.65
				ci.draw_rect(Rect2(P.call(x - 0.14, -0.35), Vector2(0.28, 0.95) * u), col)
			ci.draw_rect(Rect2(P.call(-1.0, 0.7), Vector2(2.0, 0.22) * u), col)
		"anel", "circulo":
			ci.draw_arc(c, u * 0.78, 0.0, TAU, 28, col, lw * (1.3 if mark == "anel" else 1.0), true)
			if mark == "circulo":
				ci.draw_circle(c, u * 0.3, col)
		"hexagono":
			var hx := PackedVector2Array()
			for i in 7:
				var a := PI / 6.0 + i * PI / 3.0
				hx.append(c + Vector2(cos(a), sin(a)) * u * 0.85)
			ci.draw_polyline(hx, col, lw, true)
			ci.draw_circle(c, u * 0.25, col)
		"seta":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.9, -0.25), P.call(0.15, -0.25), P.call(0.15, -0.7), P.call(0.95, 0), P.call(0.15, 0.7), P.call(0.15, 0.25), P.call(-0.9, 0.25)]), col)
		"coroa":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.9, 0.6), P.call(-0.9, -0.5), P.call(-0.45, 0.0), P.call(0, -0.75), P.call(0.45, 0.0), P.call(0.9, -0.5), P.call(0.9, 0.6)]), col)
		"espiga":
			ci.draw_line(P.call(0, 0.95), P.call(0, -0.9), col, maxf(1.0, u * 0.16))
			for i in 4:
				var y := -0.65 + i * 0.4
				ci.draw_colored_polygon(PackedVector2Array([P.call(0, y + 0.2), P.call(-0.55, y - 0.05), P.call(-0.1, y - 0.25)]), col)
				ci.draw_colored_polygon(PackedVector2Array([P.call(0, y + 0.2), P.call(0.55, y - 0.05), P.call(0.1, y - 0.25)]), col)
		"gota":
			ci.draw_circle(P.call(0, 0.3), u * 0.58, col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.95), P.call(0.52, 0.1), P.call(-0.52, 0.1)]), col)
		"onda":
			for k in 2:
				var pts2 := PackedVector2Array()
				for i in 13:
					var x := -1.0 + i / 6.0
					pts2.append(P.call(x, -0.25 + k * 0.55 + sin(x * PI * 1.5) * 0.25))
				ci.draw_polyline(pts2, col, lw, true)
		"sinal":
			ci.draw_circle(P.call(-0.6, 0.6), u * 0.2, col)
			for i in 3:
				ci.draw_arc(P.call(-0.6, 0.6), u * (0.55 + i * 0.45), -PI / 2.0, 0.0, 10, col, lw, true)
		"sol":
			ci.draw_circle(c, u * 0.45, col)
			for i in 8:
				var a := i * PI / 4.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * u * 0.62, c + Vector2(cos(a), sin(a)) * u * 0.95, col, maxf(1.0, u * 0.18))
		"chama":
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -0.95), P.call(0.55, -0.1), P.call(0.6, 0.45), P.call(0.25, 0.9), P.call(-0.25, 0.9), P.call(-0.6, 0.45), P.call(-0.35, -0.05), P.call(-0.1, 0.2)]), col)
		"guarda":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.95, 0.05), P.call(-0.6, -0.55), P.call(0, -0.8), P.call(0.6, -0.55), P.call(0.95, 0.05)]), col)
			ci.draw_line(P.call(0, -0.1), P.call(0, 0.7), col, maxf(1.0, u * 0.16))
			ci.draw_arc(P.call(-0.2, 0.7), u * 0.2, 0.0, PI, 6, col, maxf(1.0, u * 0.16))
		"sacola":
			ci.draw_rect(Rect2(P.call(-0.7, -0.3), Vector2(1.4, 1.15) * u), col)
			ci.draw_arc(P.call(0, -0.3), u * 0.4, PI, TAU, 10, col, maxf(1.0, u * 0.18))
		"pixel":
			for i in 4:
				ci.draw_rect(Rect2(P.call(-0.85 + (i % 2) * 0.95, -0.85 + (i / 2) * 0.95), Vector2(0.75, 0.75) * u), col if i != 3 else Color(col.r, col.g, col.b, 0.55))
		"telhado":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, 0.0), P.call(0, -0.9), P.call(1.0, 0.0), P.call(0.65, 0.0), P.call(0.65, 0.85), P.call(-0.65, 0.85), P.call(-0.65, 0.0)]), col)
		"folha":
			var lf := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				lf.append(P.call(lerpf(-0.8, 0.8, t), lerpf(0.8, -0.8, t) - sin(t * PI) * 0.45))
			for i in range(11, 0, -1):
				var t := i / 12.0
				lf.append(P.call(lerpf(-0.8, 0.8, t), lerpf(0.8, -0.8, t) + sin(t * PI) * 0.45))
			ci.draw_colored_polygon(lf, col)
		"cruz":
			ci.draw_rect(Rect2(P.call(-0.3, -0.9), Vector2(0.6, 1.8) * u), col)
			ci.draw_rect(Rect2(P.call(-0.9, -0.3), Vector2(1.8, 0.6) * u), col)
		"livro":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.95, -0.6), P.call(-0.05, -0.4), P.call(-0.05, 0.8), P.call(-0.95, 0.6)]), col)
			ci.draw_colored_polygon(PackedVector2Array([P.call(0.95, -0.6), P.call(0.05, -0.4), P.call(0.05, 0.8), P.call(0.95, 0.6)]), col)
		"play":
			ci.draw_arc(c, u * 0.88, 0.0, TAU, 24, col, maxf(1.0, u * 0.18), true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.3, -0.45), P.call(0.5, 0), P.call(-0.3, 0.45)]), col)
		"montanha":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-1.0, 0.75), P.call(-0.3, -0.6), P.call(0.05, 0.0), P.call(0.35, -0.3), P.call(1.0, 0.75)]), col)
		_:
			return false
	return true
