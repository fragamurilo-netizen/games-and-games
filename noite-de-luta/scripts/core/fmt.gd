class_name Fmt
extends RefCounted
## Formatação de textos exibidos ao usuário, no idioma escolhido (I18n.lang; o padrão é pt-BR).
## Dinheiro em dólar: é a moeda das bolsas.

const MONTHS: Array[String] = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
const MONTHS_FULL: Array[String] = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro", "outubro", "novembro", "dezembro"]
const _MONTHS_IN := {
	"en": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
	"es": ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
	"de": ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."],
	"fr": ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."],
	"ru": ["янв", "фев", "мар", "апр", "мая", "июн", "июл", "авг", "сен", "окт", "ноя", "дек"],
}
const _MONTHS_FULL_IN := {
	"en": ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"],
	"es": ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"],
	"de": ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"],
	"fr": ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"],
	"ru": ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"],
}
const _WEEKDAY_SAT := {"pt": "sáb", "en": "Sat", "es": "sáb", "de": "Sa.", "fr": "sam.", "ru": "сб", "zh": "周六"}
## Separador decimal e de milhar por idioma.
const _DEC := {"en": ".", "zh": "."}
const _THOU := {"en": ",", "zh": ",", "fr": "\u202f", "ru": "\u00a0"}


## Mês curto (1 a 12) no idioma do jogo.
static func month(m: int) -> String:
	var i := clampi(m, 1, 12) - 1
	if I18n.lang == "zh":
		return "%d月" % (i + 1)
	return _MONTHS_IN[I18n.lang][i] if _MONTHS_IN.has(I18n.lang) else MONTHS[i]


static func month_full(m: int) -> String:
	var i := clampi(m, 1, 12) - 1
	if I18n.lang == "zh":
		return "%d月" % (i + 1)
	return _MONTHS_FULL_IN[I18n.lang][i] if _MONTHS_FULL_IN.has(I18n.lang) else MONTHS_FULL[i]


## "18 jan 2027" / "Jan 18, 2027" / "2027年1月18日".
static func date_short(day: int, m: int, year: int = -1) -> String:
	var y := year >= 0
	match I18n.lang:
		"en":
			return "%s %d" % [month(m), day] + (", %d" % year if y else "")
		"de":
			return "%d. %s" % [day, month(m)] + (" %d" % year if y else "")
		"zh":
			return ("%d年" % year if y else "") + "%d月%d日" % [m, day]
		"ru":
			return "%d %s" % [day, month(m)] + (" %d" % year if y else "")
	return "%d %s" % [day, month(m)] + (" %d" % year if y else "")


## "18 de janeiro de 2027" / "January 18, 2027".
static func date_long(day: int, m: int, year: int) -> String:
	match I18n.lang:
		"en":
			return "%s %d, %d" % [month_full(m), day, year]
		"es":
			return "%d de %s de %d" % [day, month_full(m), year]
		"de":
			return "%d. %s %d" % [day, month_full(m), year]
		"fr", "ru":
			return "%d %s %d" % [day, month_full(m), year]
		"zh":
			return "%d年%d月%d日" % [year, m, day]
	return "%d de %s de %d" % [day, month_full(m), year]


## "sáb, 9 jan" (dia das lutas).
static func fight_day(day: int, m: int, year: int = -1) -> String:
	var sat: String = _WEEKDAY_SAT.get(I18n.lang, "sáb")
	if I18n.lang == "zh":
		return date_short(day, m, year) + " " + sat
	return sat + ", " + date_short(day, m, year)


## "jan 2027" (mês e ano de um marco).
static func month_year(m: int, year: int) -> String:
	if I18n.lang == "zh":
		return "%d年%d月" % [year, m]
	return "%s %d" % [month(m), year]


## Sufixos de milhão e mil por idioma (o chinês conta em 万, dez mil).
const _MONEY_UNITS := {
	"pt": [" mi", " mil"], "en": ["M", "K"], "es": [" M", " mil"], "de": [" Mio.", " Tsd."],
	"fr": [" M", " k"], "ru": [" млн", " тыс."],
}


static func money(v: float) -> String:
	var neg := v < 0.0
	var a := absf(v)
	var s := ""
	if I18n.lang == "zh":
		if a >= 100_000_000.0:
			s = _decimal(a / 100_000_000.0, 2) + "亿"
		elif a >= 10_000.0:
			var w := a / 10_000.0
			s = _decimal(w, 1 if w < 100.0 else 0) + "万"
		else:
			s = str(int(round(a)))
		return ("-" if neg else "") + "US$" + s
	var u: Array = _MONEY_UNITS.get(I18n.lang, _MONEY_UNITS["pt"])
	if a >= 1_000_000.0:
		var m := a / 1_000_000.0
		s = _decimal(m, 2 if m < 10.0 else 1) + u[0]
	elif a >= 10_000.0:
		s = str(int(round(a / 1_000.0))) + u[1]
	elif a >= 1_000.0:
		s = _decimal(a / 1_000.0, 1) + u[1]
	else:
		s = str(int(round(a)))
	if I18n.lang == "en":
		return ("-" if neg else "") + "$" + s
	return ("-" if neg else "") + "US$ " + s


static func _decimal(x: float, places: int) -> String:
	if places <= 0:
		return str(int(round(x)))
	var txt := ("%." + str(places) + "f") % x
	while txt.contains(".") and (txt.ends_with("0") or txt.ends_with(".")):
		txt = txt.substr(0, txt.length() - 1)
	return txt.replace(".", _DEC.get(I18n.lang, ","))


static func dec(x: float, places: int) -> String:
	return (("%." + str(places) + "f") % x).replace(".", _DEC.get(I18n.lang, ","))


static func thousands(v: int) -> String:
	var neg := v < 0
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = String(_THOU.get(I18n.lang, ".")) + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if neg else "") + s + out


static func ordinal(n: int) -> String:
	return ordinal_in(I18n.lang, n)


static func ordinal_in(lang: String, n: int) -> String:
	match lang:
		"en":
			var t := n % 100
			if t >= 11 and t <= 13:
				return "%dth" % n
			return str(n) + ["th", "st", "nd", "rd", "th", "th", "th", "th", "th", "th"][n % 10]
		"es":
			return "%d.º" % n
		"de":
			return "%d." % n
		"fr":
			return "%der" % n if n == 1 else "%de" % n
		"ru":
			return "%d-й" % n
		"zh":
			return "第%d" % n
	return str(n) + "º"


static func signed(n: int) -> String:
	return ("+" if n > 0 else "") + str(n)


static func percent(x: float) -> String:
	return str(int(round(x * 100.0))) + "%"


## "3 lutas". Fora do português as duas formas passam pela tradução; no russo a tradução do
## plural pode trazer as três formas "боя|боёв" (2 a 4 | 5 ou mais) ou "бой|боя|боёв".
static func plural(n: int, singular: String, plural_form: String) -> String:
	if I18n.is_pt():
		return thousands(n) + " " + (singular if n == 1 else plural_form)
	var word := I18n.t(singular if n == 1 else plural_form)
	if I18n.lang == "ru":
		word = _ru_plural(n, I18n.t(singular), "|".join(I18n.forms(plural_form)))
	if I18n.lang == "zh":
		return thousands(n) + word
	return thousands(n) + " " + word


static func _ru_plural(n: int, one: String, many: String) -> String:
	var forms := many.split("|")
	var f1 := one
	var f2 := forms[0]
	var f5 := forms[forms.size() - 1]
	if forms.size() == 3:
		f1 = forms[0]
		f2 = forms[1]
	var a := absi(n) % 100
	var b := a % 10
	if a >= 11 and a <= 14:
		return f5
	if b == 1:
		return f1
	if b >= 2 and b <= 4:
		return f2
	return f5


## Altura em metros ("1,82 m") e envergadura em centímetros.
static func height(cm: int) -> String:
	return _decimal(cm / 100.0, 2) + (" м" if I18n.lang == "ru" else (" 米" if I18n.lang == "zh" else " m"))


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
