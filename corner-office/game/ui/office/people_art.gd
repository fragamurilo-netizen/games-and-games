class_name PeopleArt
extends RefCounted
## Personagens 2D modulares da sede: as mesmas peças (corpo, camisa do setor,
## pele, cabelo, óculos, barba, expressão) servem o sprite do escritório e o
## busto das fichas. A aparência vem de StaffMember.look — sem atlas de sprites.

const HAIR_M := 5    # estilos masculinos: curto, raspado, topete, cacheado, careca
const HAIR_F := 6    # femininos: chanel, longo, rabo, coque, curto, volumoso


static func skin(look: Dictionary) -> Color:
	var tones: Array = Office.config().skin_tones
	return Color(tones[clampi(int(look.get("skin", 0)), 0, tones.size() - 1)])


static func hair_color(look: Dictionary) -> Color:
	var colors: Array = Office.config().hair_colors
	return Color(colors[clampi(int(look.get("hair_color", 0)), 0, colors.size() - 1)])


static func shirt(role: String) -> Color:
	return Color(Office.config().shirt_by_department.get(Office.department(role), "#46535E"))


## Pessoa inteira com os pés em `base`. u = escala (1.0 ≈ 50 px de altura).
## opts: pose (stand|walk|sit), phase (0..1 do passo), typing, mood (-1..1),
## alpha, sex, role, highlight.
static func draw_person(ci: CanvasItem, base: Vector2, u: float, look: Dictionary, opts: Dictionary) -> void:
	var alpha := float(opts.get("alpha", 1.0))
	var shirt_c := Color(opts.get("shirt", Tokens.STEEL), alpha)
	var pants := Color(Tokens.CANVAS.lerp(Tokens.STEEL, 0.25), alpha)
	var skin_c := Color(skin(look), alpha)
	var pose := str(opts.get("pose", "stand"))
	var phase := float(opts.get("phase", 0.0))
	var build := int(look.get("build", 1))
	var bw: float = [8.5, 10.0, 11.5][clampi(build, 0, 2)] * u
	var bob := sin(phase * TAU * 2.0) * 1.2 * u if pose == "walk" else 0.0
	if opts.get("highlight", false):
		ci.draw_circle(base, 17 * u, Color(Tokens.INK, 0.12 * alpha))
	# Sombra no chão.
	ci.draw_colored_polygon(_ellipse(base + Vector2(0, 1 * u), Vector2(13, 4) * u), Color(Tokens.OFFICE_SHADOW, Tokens.OFFICE_SHADOW.a * alpha))
	var hip := base + Vector2(0, -15 * u + bob)
	if pose != "sit":
		var swing := sin(phase * TAU) * 4.0 * u if pose == "walk" else 0.0
		ci.draw_rect(Rect2(hip + Vector2(-bw * 0.8, 0), Vector2(bw * 0.7, 15 * u - bob)).abs(), pants)
		ci.draw_rect(Rect2(hip + Vector2(bw * 0.1, 0), Vector2(bw * 0.7, 15 * u - bob)).abs(), pants)
		if swing != 0.0:
			ci.draw_rect(Rect2(base + Vector2(-bw * 0.8 + swing * 0.3, -3 * u), Vector2(bw * 0.7, 3 * u)), Color(Tokens.CANVAS, alpha))
			ci.draw_rect(Rect2(base + Vector2(bw * 0.1 - swing * 0.3, -3 * u), Vector2(bw * 0.7, 3 * u)), Color(Tokens.CANVAS, alpha))
	# Tronco (camisa do setor) com ombros arredondados.
	var top := hip + Vector2(0, -19 * u)
	var torso := PackedVector2Array([top + Vector2(-bw, 3 * u), top + Vector2(-bw * 0.7, 0), top + Vector2(bw * 0.7, 0), top + Vector2(bw, 3 * u), hip + Vector2(bw * 0.9, 1 * u), hip + Vector2(-bw * 0.9, 1 * u)])
	ci.draw_colored_polygon(torso, shirt_c)
	# Gola.
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-3 * u, 0), top + Vector2(3 * u, 0), top + Vector2(0, 4 * u)]), Color(skin_c.darkened(0.08), alpha))
	# Braços: digitando vão à frente; andando balançam.
	var arm_y := top + Vector2(0, 3 * u)
	if opts.get("typing", false):
		var tap := sin(float(opts.get("t", 0.0)) * 18.0) * 1.2 * u
		ci.draw_line(arm_y + Vector2(-bw, 0), arm_y + Vector2(-bw * 0.4, 12 * u + tap), shirt_c.darkened(0.1), 3.5 * u)
		ci.draw_line(arm_y + Vector2(bw, 0), arm_y + Vector2(bw * 0.4, 12 * u - tap), shirt_c.darkened(0.1), 3.5 * u)
		ci.draw_circle(arm_y + Vector2(-bw * 0.4, 12 * u + tap), 1.8 * u, skin_c)
		ci.draw_circle(arm_y + Vector2(bw * 0.4, 12 * u - tap), 1.8 * u, skin_c)
	else:
		var sw := sin(phase * TAU) * 3.0 * u if pose == "walk" else 0.0
		var raise := float(opts.get("raise", 0.0)) * u
		ci.draw_line(arm_y + Vector2(-bw, 0), arm_y + Vector2(-bw - 1.5 * u, 14 * u + sw - raise * 2.2), shirt_c.darkened(0.1), 3.5 * u)
		ci.draw_line(arm_y + Vector2(bw, 0), arm_y + Vector2(bw + 1.5 * u, 14 * u - sw - raise * 2.2), shirt_c.darkened(0.1), 3.5 * u)
		ci.draw_circle(arm_y + Vector2(-bw - 1.5 * u, 14 * u + sw - raise * 2.2), 1.9 * u, skin_c)
		ci.draw_circle(arm_y + Vector2(bw + 1.5 * u, 14 * u - sw - raise * 2.2), 1.9 * u, skin_c)
	draw_head(ci, top + Vector2(0, -9 * u), 9.0 * u, look, opts)


## Cabeça com cabelo, rosto e acessórios. `center` = centro do crânio.
static func draw_head(ci: CanvasItem, center: Vector2, r: float, look: Dictionary, opts: Dictionary) -> void:
	var alpha := float(opts.get("alpha", 1.0))
	var skin_c := Color(skin(look), alpha)
	var hair_c := Color(hair_color(look), alpha)
	var female := str(opts.get("sex", "m")) == "f"
	var style := int(look.get("hair", 0))
	# Cabelo de trás (longo/rabo) antes do rosto.
	if female and style in [1, 5]:
		ci.draw_rect(Rect2(center + Vector2(-r * 1.05, -r * 0.2), Vector2(r * 2.1, r * (1.9 if style == 1 else 1.3))), hair_c)
	if female and style == 5:
		for k in 6:
			var a := PI + k * PI / 5.0
			ci.draw_circle(center + Vector2(cos(a), sin(a) * 0.9) * r * 1.05, r * 0.42, hair_c)
	if female and style == 2:
		ci.draw_circle(center + Vector2(r * 1.05, r * 0.2), r * 0.45, hair_c)
	ci.draw_circle(center + Vector2(0, r * 0.95), r * 0.35, skin_c.darkened(0.12))   # pescoço
	ci.draw_circle(center, r, skin_c)
	# Orelhas.
	ci.draw_circle(center + Vector2(-r * 0.98, r * 0.1), r * 0.22, skin_c.darkened(0.06))
	ci.draw_circle(center + Vector2(r * 0.98, r * 0.1), r * 0.22, skin_c.darkened(0.06))
	# Cabelo de cima.
	if female:
		match style:
			0, 1, 2, 5:
				ci.draw_colored_polygon(_cap(center, r, 0.35), hair_c)
			3:
				ci.draw_colored_polygon(_cap(center, r, 0.2), hair_c)
				ci.draw_circle(center + Vector2(0, -r * 1.05), r * 0.45, hair_c)
			4:
				ci.draw_colored_polygon(_cap(center, r, 0.05), hair_c)
	else:
		match style:
			0:
				ci.draw_colored_polygon(_cap(center, r, 0.05), hair_c)
			1:
				ci.draw_colored_polygon(_cap(center, r, -0.25), Color(hair_c, alpha * 0.75))
			2:
				ci.draw_colored_polygon(_cap(center, r, 0.1), hair_c)
				ci.draw_circle(center + Vector2(-r * 0.35, -r * 0.85), r * 0.4, hair_c)
			3:
				for k in 7:
					var a := PI + k * PI / 6.0
					ci.draw_circle(center + Vector2(cos(a), sin(a) * 0.85) * r * 0.82, r * 0.34, hair_c)
			4:
				pass
	if look.get("beard", false):
		var jaw := PackedVector2Array()
		for k in 9:
			var a := k * PI / 8.0
			jaw.append(center + Vector2(cos(a) * r * 0.92, sin(a) * r * 0.95))
		jaw.append(center + Vector2(-r * 0.7, r * 0.25))
		jaw.append(center + Vector2(r * 0.7, r * 0.25))
		ci.draw_colored_polygon(_hull(jaw), Color(hair_c, alpha * 0.85))
		ci.draw_circle(center + Vector2(0, r * 0.45), r * 0.28, skin_c)
	# Rosto: olhos, boca pela moral (-1 triste … 1 feliz).
	var mood := float(opts.get("mood", 0.0))
	var eye := Color(Tokens.CANVAS, alpha)
	var tired := bool(opts.get("tired", false))
	if tired:
		ci.draw_line(center + Vector2(-r * 0.45, 0), center + Vector2(-r * 0.15, 0), eye, maxf(1.0, r * 0.14))
		ci.draw_line(center + Vector2(r * 0.15, 0), center + Vector2(r * 0.45, 0), eye, maxf(1.0, r * 0.14))
	else:
		ci.draw_circle(center + Vector2(-r * 0.33, -r * 0.02), maxf(0.8, r * 0.12), eye)
		ci.draw_circle(center + Vector2(r * 0.33, -r * 0.02), maxf(0.8, r * 0.12), eye)
	if mood < -0.4:
		ci.draw_line(center + Vector2(-r * 0.55, -r * 0.3), center + Vector2(-r * 0.15, -r * 0.18), eye, maxf(1.0, r * 0.1))
		ci.draw_line(center + Vector2(r * 0.55, -r * 0.3), center + Vector2(r * 0.15, -r * 0.18), eye, maxf(1.0, r * 0.1))
	var mouth := PackedVector2Array()
	for k in 5:
		var x := -0.28 + k * 0.14
		mouth.append(center + Vector2(x * r, r * 0.45 - mood * (0.08 - x * x) * r * 1.6))
	ci.draw_polyline(mouth, Color(skin_c.darkened(0.45), alpha), maxf(1.0, r * 0.11), true)
	if look.get("glasses", false):
		var g := Color(Tokens.CANVAS, alpha * 0.9)
		ci.draw_arc(center + Vector2(-r * 0.33, 0), r * 0.26, 0, TAU, 12, g, maxf(1.0, r * 0.08))
		ci.draw_arc(center + Vector2(r * 0.33, 0), r * 0.26, 0, TAU, 12, g, maxf(1.0, r * 0.08))
		ci.draw_line(center + Vector2(-r * 0.07, 0), center + Vector2(r * 0.07, 0), g, maxf(1.0, r * 0.08))


## Busto para listas e fichas: fundo na cor do setor, cabeça e ombros.
static func draw_bust(ci: CanvasItem, rect: Rect2, s: StaffMember, opts: Dictionary = {}) -> void:
	var dept := Color(Office.config().departments.get(Office.department(s.role), {}).get("color", "#46535E"))
	ci.draw_rect(rect, Tokens.SURFACE)
	ci.draw_colored_polygon(PackedVector2Array([rect.position + Vector2(0, rect.size.y * 0.62), rect.position + Vector2(rect.size.x, rect.size.y * 0.38), rect.end, rect.position + Vector2(0, rect.size.y)]), Color(dept, 0.55))
	var r := rect.size.x * 0.24
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.44)
	var sh := shirt(s.role)
	var shoulders := PackedVector2Array([center + Vector2(-r * 1.9, r * 2.4), center + Vector2(-r * 1.5, r * 1.35), center + Vector2(r * 1.5, r * 1.35), center + Vector2(r * 1.9, r * 2.4)])
	ci.draw_colored_polygon(PackedVector2Array([shoulders[0], shoulders[1], shoulders[2], shoulders[3], Vector2(shoulders[3].x, rect.end.y), Vector2(shoulders[0].x, rect.end.y)]), sh)
	var o := opts.duplicate()
	o.sex = s.sex
	if not o.has("mood"):
		o.mood = clampf((s.morale - 55.0) / 35.0, -1.0, 1.0)
	o.tired = s.energy < Office.tuning().tired_energy
	draw_head(ci, center, r, s.look, o)
	ci.draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - 3), Vector2(rect.size.x, 3)), dept)


## Balões e ícones sobre a cabeça (estado vindo da simulação).
static func draw_emote(ci: CanvasItem, at: Vector2, kind: String, u: float, t: float) -> void:
	var float_y := sin(t * 3.0) * 1.5 * u
	var p := at + Vector2(0, float_y)
	match kind:
		"stress":
			ci.draw_circle(p, 7 * u, Color(Tokens.MUTED, 0.9))
			ci.draw_circle(p + Vector2(-5, 2) * u, 5 * u, Color(Tokens.MUTED, 0.9))
			ci.draw_circle(p + Vector2(5, 2) * u, 5 * u, Color(Tokens.MUTED, 0.9))
			var zig := PackedVector2Array([p + Vector2(-5, 1) * u, p + Vector2(-2, -3) * u, p + Vector2(1, 2) * u, p + Vector2(4, -2) * u, p + Vector2(6, 1) * u])
			ci.draw_polyline(zig, Tokens.CANVAS, 1.4 * u)
		"tired":
			for k in 3:
				var q := p + Vector2(k * 4.5, -k * 4.5) * u + Vector2(0, sin(t * 2 + k) * u)
				ci.draw_string(Tokens.DISPLAY_FONT, q, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int((8 + k * 2) * u), Color(Tokens.OFFICE_SCREEN, 0.95))
		"unhappy":
			_bubble(ci, p, u, Tokens.FIGHT_RED)
			ci.draw_arc(p + Vector2(0, 3) * u, 3 * u, PI * 1.15, PI * 1.85, 8, Tokens.INK, 1.4 * u)
		"conflict":
			_bubble(ci, p, u, Tokens.WARN)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(1, -5) * u, p + Vector2(-3, 1) * u, p + Vector2(0, 1) * u, p + Vector2(-1, 5) * u, p + Vector2(3, -1) * u, p + Vector2(0, -1) * u]), Tokens.INK)
		"problem":
			_bubble(ci, p, u, Tokens.FIGHT_RED)
			ci.draw_rect(Rect2(p + Vector2(-1, -5) * u, Vector2(2, 6) * u), Tokens.INK)
			ci.draw_rect(Rect2(p + Vector2(-1, 2.5) * u, Vector2(2, 2) * u), Tokens.INK)
		"talk":
			_bubble(ci, p, u, Tokens.PAPER)
			for k in 3:
				ci.draw_circle(p + Vector2(-3 + k * 3, 0) * u, 1.0 * u * (1.0 + 0.4 * sin(t * 6 + k)), Tokens.CANVAS)
		"happy":
			for k in 4:
				var a := t * 2.0 + k * TAU / 4.0
				var q := p + Vector2(cos(a), sin(a)) * 6 * u
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -2.5) * u, q + Vector2(1, 0), q + Vector2(0, 2.5) * u, q + Vector2(-1, 0)]), Tokens.CHAMP_GOLD)
		"celebrate":
			for k in 8:
				var a := k * TAU / 8.0 + t
				var q := p + Vector2(cos(a) * 9, sin(a) * 5 - fmod(t * 8 + k, 8)) * u
				ci.draw_rect(Rect2(q, Vector2(2, 3) * u), [Tokens.FIGHT_RED, Tokens.CHAMP_GOLD, Tokens.INFO, Tokens.GOOD][k % 4])
		"new":
			_bubble(ci, p, u, Tokens.GOOD)
			ci.draw_string(Tokens.DISPLAY_FONT, p + Vector2(-3.5, 3.5) * u, "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * u), Tokens.INK)


static func _bubble(ci: CanvasItem, p: Vector2, u: float, c: Color) -> void:
	ci.draw_circle(p, 7.5 * u, c)
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-2, 6) * u, p + Vector2(2, 6) * u, p + Vector2(-1, 10) * u]), c)


static func _ellipse(c: Vector2, r: Vector2, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := k * TAU / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## Calota de cabelo: arco superior do crânio descendo até `drop` (fração do raio).
static func _cap(c: Vector2, r: float, drop: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var from := PI + asin(clampf(-drop, -0.99, 0.99))
	var to := TAU - asin(clampf(-drop, -0.99, 0.99))
	for k in 13:
		var a := lerpf(from, to, k / 12.0)
		pts.append(c + Vector2(cos(a), sin(a)) * r * 1.06)
	pts.append(c + Vector2(r * 0.95, r * drop))
	pts.append(c + Vector2(-r * 0.95, r * drop))
	return pts


static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0] == hull[-1]:
		hull.remove_at(hull.size() - 1)
	return hull
