class_name MomentumView
extends Control
## Gráfico de pressão da partida: uma barra por minuto (acima do meio = mandante,
## abaixo = visitante), suavizada, com os gols marcados e a divisão dos tempos.

## [tempo, minuto, valor] vindo de MatchSimulation.pressure.
var pressure: Array = []
## [[tempo, minuto, lado]] dos gols.
var goals: Array = []
var home_color: Color = Color("#1B3A8C")
var away_color: Color = Color("#B3122E")
## Minutos desenhados no eixo (cresce na prorrogação).
var span: int = 96


func refresh(p_pressure: Array, p_goals: Array) -> void:
	pressure = p_pressure
	goals = p_goals
	queue_redraw()


func _x_of(half: int, minute: int, w: float) -> float:
	# Posição contínua: acréscimos do 1º tempo empurram o 2º um pouco para frente.
	var m := float(minute)
	if half == 2:
		m = 45.0 + (m - 45.0) + 3.0
	elif half >= 3:
		m = 96.0 + (m - 90.0)
	return clampf(m / float(span), 0.0, 1.0) * w


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := h * 0.5
	draw_rect(Rect2(0, 0, w, h), Color(1, 1, 1, 0.03))
	draw_line(Vector2(0, mid), Vector2(w, mid), Color(1, 1, 1, 0.18), 1.0)
	var ht := _x_of(2, 45, w) - w / float(span) * 1.5
	draw_line(Vector2(ht, 2), Vector2(ht, h - 2), Color(1, 1, 1, 0.14), 1.0)
	if pressure.is_empty():
		return
	for p in pressure:
		if int(p[0]) >= 3 and span < 126:
			span = 126
	var bar_w := maxf(1.5, w / float(span) - 1.0)
	var smooth := 0.0
	var hc := _visible(home_color)
	var ac := _visible(away_color)
	for i in pressure.size():
		var p: Array = pressure[i]
		# Média móvel curta: o gráfico mostra quem manda no jogo, não cada lance.
		var v := 0.0
		var n := 0.0
		for j in range(maxi(0, i - 2), mini(pressure.size(), i + 1)):
			var wgt := 1.0 if j == i else 0.6
			v += float(pressure[j][2]) * wgt
			n += wgt
		smooth = v / n
		var x := _x_of(int(p[0]), int(p[1]), w)
		var len := clampf(absf(smooth) * 1.8, 0.0, 1.0) * (mid - 3.0)
		if smooth >= 0.0:
			draw_rect(Rect2(x - bar_w * 0.5, mid - len, bar_w, len), Color(hc.r, hc.g, hc.b, 0.85))
		else:
			draw_rect(Rect2(x - bar_w * 0.5, mid, bar_w, len), Color(ac.r, ac.g, ac.b, 0.85))
	for g in goals:
		var gx := _x_of(int(g[0]), int(g[1]), w)
		var gy := 5.0 if int(g[2]) == 0 else h - 5.0
		draw_circle(Vector2(gx, gy), 4.5, Color.WHITE)
		draw_circle(Vector2(gx, gy), 2.0, Color(0.1, 0.1, 0.1))


static func _visible(c: Color) -> Color:
	if c.get_luminance() < 0.12:
		return c.lightened(0.45)
	return c
