class_name Fmt
extends RefCounted
## Formatação de textos exibidos ao usuário (pt-BR).


## Dinheiro compacto: $ 850, $ 12 mil, $ 1,2 mi, $ -3,4 mi.
static func money(v: float) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var s := ""
	if a >= 1_000_000.0:
		var m := a / 1_000_000.0
		s = _decimal(m, 1 if m < 100.0 else 0) + " mi"
	elif a >= 1_000.0:
		s = str(int(round(a / 1_000.0))) + " mil"
	else:
		s = str(int(round(a)))
	return ("-$ " if neg else "$ ") + s


static func money_month(v: float) -> String:
	return money(v) + "/mês"


static func _decimal(x: float, places: int) -> String:
	if places <= 0:
		return str(int(round(x)))
	var txt := ("%." + str(places) + "f") % x
	if txt.ends_with(".0"):
		txt = txt.substr(0, txt.length() - 2)
	return txt.replace(".", ",")


## Nota de partida sempre com uma casa: 7,0 / 6,4.
static func rating(r: float) -> String:
	return ("%.1f" % r).replace(".", ",")


static func thousands(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


static func ordinal(n: int) -> String:
	return str(n) + "º"


static func height(cm: int) -> String:
	return _decimal(cm / 100.0, 2) + " m"


static func signed(n: int) -> String:
	return ("+" if n > 0 else "") + str(n)


static func percent(x: float) -> String:
	return str(int(round(x * 100.0))) + "%"


## Minuto no formato "45+2'" (m > limite do tempo vira acréscimo).
static func minute(m: int, half: int = 0) -> String:
	if half == 1 and m > 45:
		return "45+" + str(m - 45) + "'"
	if half == 2 and m > 90:
		return "90+" + str(m - 90) + "'"
	return str(m) + "'"


static func plural(n: int, singular: String, plural_form: String) -> String:
	return str(n) + " " + (singular if n == 1 else plural_form)


## Cor de destaque para um overall (vermelho → cinza → verde → dourado).
static func rating_color(ovr: int) -> Color:
	if ovr >= 80:
		return Color("#FFC940")
	if ovr >= 70:
		return Color("#3DBE7A")
	if ovr >= 60:
		return Color("#8FD694")
	if ovr >= 50:
		return Color("#C9D3DD")
	if ovr >= 40:
		return Color("#F0A35E")
	return Color("#E5484D")


## Cor para notas de partida (3–10).
static func match_rating_color(r: float) -> Color:
	if r >= 8.0:
		return Color("#FFC940")
	if r >= 7.0:
		return Color("#3DBE7A")
	if r >= 6.0:
		return Color("#C9D3DD")
	if r >= 5.0:
		return Color("#F0A35E")
	return Color("#E5484D")
