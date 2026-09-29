class_name GameDate
extends RefCounted
## Datas da simulação como dicionários {year, month, day} (serializáveis).
## A campanha padrão começa em 1º de janeiro de 2027 (Game Design Bible §2).

const START := {"year": 2027, "month": 1, "day": 1}


static func to_unix(d: Dictionary) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12, "minute": 0, "second": 0})


static func from_unix(t: int) -> Dictionary:
	var dt := Time.get_datetime_dict_from_unix_time(t)
	return {"year": dt.year, "month": dt.month, "day": dt.day}


static func add_days(d: Dictionary, days: int) -> Dictionary:
	return from_unix(to_unix(d) + days * 86400)


static func days_between(a: Dictionary, b: Dictionary) -> int:
	return int((to_unix(b) - to_unix(a)) / 86400)


static func format(d: Dictionary) -> String:
	return "%02d/%02d/%04d" % [d.day, d.month, d.year]
