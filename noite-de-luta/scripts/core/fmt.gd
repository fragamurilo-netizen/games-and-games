class_name Fmt
extends RefCounted
## Formatação de textos exibidos ao usuário (pt-BR). Dinheiro em dólar: é a moeda das bolsas.

const MONTHS: Array[String] = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
const MONTHS_FULL: Array[String] = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]


static func money(v: float) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var s := ""
	if a >= 1_000_000.0:
		var m := a / 1_000_000.0
		s = _decimal(m, 2 if m < 10.0 else 1) + " mi"
	elif a >= 10_000.0:
		s = str(int(round(a / 1_000.0))) + " mil"
	elif a >= 1_000.0:
		s = _decimal(a / 1_000.0, 1) + " mil"
	else:
		s = str(int(round(a)))
	return ("-" if neg else "") + "US$ " + s


static func _decimal(x: float, places: int) -> String:
	if places <= 0:
		return str(int(round(x)))
	var txt := ("%." + str(places) + "f") % x
	while txt.contains(".") and (txt.ends_with("0") or txt.ends_with(".")):
		txt = txt.substr(0, txt.length() - 1)
	return txt.replace(".", ",")


static func dec(x: float, places: int) -> String:
	return (("%." + str(places) + "f") % x).replace(".", ",")


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


static func signed(n: int) -> String:
	return ("+" if n > 0 else "") + str(n)


static func percent(x: float) -> String:
	return str(int(round(x * 100.0))) + "%"


static func plural(n: int, singular: String, plural_form: String) -> String:
	return thousands(n) + " " + (singular if n == 1 else plural_form)


## Altura em metros ("1,82 m") e envergadura em centímetros.
static func height(cm: int) -> String:
	return _decimal(cm / 100.0, 2) + " m"


static func kg(v: float) -> String:
	return _decimal(v, 1) + " kg"


## Relógio da luta: segundos restantes no round → "3:07".
static func clock(seconds_left: float) -> String:
	var s := maxi(0, int(ceil(seconds_left)))
	return "%d:%02d" % [s / 60, s % 60]


## Tempo decorrido no round (como no resultado oficial: "R2 3:41").
static func elapsed(seconds: float) -> String:
	var s := maxi(0, int(round(seconds)))
	return "%d:%02d" % [s / 60, s % 60]
