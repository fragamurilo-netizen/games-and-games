class_name SeasonState
extends RefCounted
## Estado da temporada corrente: ligas de todas as nações, copas, calendário unificado e progresso.
## O calendário é uma sequência de datas ("slots"): W = rodada de liga (fim de semana),
## Cn = data continental (meio de semana), Xn = Mundial de Clubes.

const MONTHS: Array[String] = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
const MONTHS_I18N: Dictionary = {
	"en": ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"],
	"es": ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"],
}
const WEEKDAYS_I18N: Dictionary = {
	"pt": ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"],
	"en": ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
	"es": ["dom", "lun", "mar", "mié", "jue", "vie", "sáb"],
}

var year: int = 2026
var leagues: Dictionary = {} # id -> League
var league_order: Array = [] # ids na ordem dos dados
var cups: Dictionary = {} # id -> Cup
## Datas: {"t": "W"|"C1".."C13"|"X1".."X3", "d": dia do ano (0 = 1º de janeiro do ano da temporada)}
var calendar: Array = []
var day: int = 0 # próxima data a disputar
var finished: bool = false
var turn: int = 0 # jogos do usuário já disputados (prazos de propostas e negociações)


func total_days() -> int:
	return calendar.size()


func current_entry() -> Dictionary:
	if day < 0 or day >= calendar.size():
		return {}
	return calendar[day]


func slot_type(slot: int) -> String:
	if slot < 0 or slot >= calendar.size():
		return ""
	return calendar[slot]["t"]


func is_weekend(slot: int) -> bool:
	return slot_type(slot) == "W"


## Janelas e aposentadorias de saves com o calendário antigo (sem as marcas "win"/"ret").
const LEGACY_WINDOWS: Array = [[0, 5], [32, 36]]
const LEGACY_RETIRE := 48


var _windows_cache: Array = []


func _marked() -> bool:
	return calendar.any(func(e): return e.has("win"))


## Faixas [início, fim] (índices) em que a janela de transferências fica aberta, na ordem.
func window_ranges() -> Array:
	if not _windows_cache.is_empty():
		return _windows_cache
	if not _marked():
		_windows_cache = LEGACY_WINDOWS
		return _windows_cache
	var out: Array = []
	var a := -1
	for i in calendar.size():
		var open := bool(calendar[i].get("win", false))
		if open and a < 0:
			a = i
		elif not open and a >= 0:
			out.append([a, i - 1])
			a = -1
	if a >= 0:
		out.append([a, calendar.size() - 1])
	_windows_cache = out
	return out


func is_retire_slot(slot: int) -> bool:
	if not _marked():
		return slot == LEGACY_RETIRE
	return slot >= 0 and slot < calendar.size() and bool(calendar[slot].get("ret", false))


## Índice da data com o código `code` ("C1", "X3"...), ou -1.
func slot_of(code: String) -> int:
	for i in calendar.size():
		if calendar[i]["t"] == code:
			return i
	return -1


func league(id: String) -> League:
	return leagues.get(id, null)


func cup(id: String) -> RefCounted:
	return cups.get(id, null)


## Todos os jogos de uma data (ligas e copas).
func fixtures_at(slot: int) -> Array:
	var out: Array = []
	for id in league_order:
		var l: League = leagues[id]
		var r := l.round_at_slot(slot)
		if r >= 0:
			out.append_array(l.rounds[r])
	for cid in cups:
		out.append_array(cups[cid].fixtures_at(slot))
	return out


## Mês (1..12) e ano de um slot, para "simular até o fim do mês".
func month_of(slot: int) -> int:
	if slot < 0 or slot >= calendar.size():
		return 0
	var doy: int = calendar[slot]["d"]
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1}) + doy * 86400
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	return int(dt["year"]) * 12 + int(dt["month"])


## Data legível de um slot: "sáb 15 ago".
func date_label(slot: int, with_weekday: bool = true) -> String:
	if slot < 0 or slot >= calendar.size():
		return ""
	var doy: int = calendar[slot]["d"]
	var unix := Time.get_unix_time_from_datetime_dict({"year": year, "month": 1, "day": 1}) + doy * 86400
	var dt := Time.get_datetime_dict_from_unix_time(unix)
	var s := "%d %s" % [int(dt["day"]), MONTHS_I18N.get(I18n.lang, MONTHS)[int(dt["month"]) - 1]]
	if with_weekday:
		s = WEEKDAYS_I18N.get(I18n.lang, WEEKDAYS_I18N["pt"])[int(dt["weekday"])] + " " + s
	return s


func to_dict() -> Dictionary:
	var ls: Dictionary = {}
	for id in leagues:
		ls[id] = leagues[id].to_dict()
	var cs: Dictionary = {}
	for id in cups:
		cs[id] = cups[id].to_dict()
	return {"year": year, "leagues": ls, "order": league_order, "cups": cs, "cal": calendar, "day": day, "fin": finished, "turn": turn}


static func from_dict(d: Dictionary) -> SeasonState:
	var s := SeasonState.new()
	s.year = int(d.get("year", 2026))
	var ls: Dictionary = d.get("leagues", {})
	for id in ls:
		s.leagues[id] = League.from_dict(ls[id])
	s.league_order = Array(d.get("order", ls.keys()))
	var cs: Dictionary = d.get("cups", {})
	for id in cs:
		s.cups[id] = Cup.from_dict(cs[id])
	s.calendar = Array(d.get("cal", []))
	s.day = int(d.get("day", 0))
	s.finished = bool(d.get("fin", false))
	s.turn = int(d.get("turn", 0))
	return s
