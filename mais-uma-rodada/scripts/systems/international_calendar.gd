class_name InternationalCalendar
extends RefCounted
## Official men's windows 2026-2030. Beyond coverage, explicitly projected game dates.
static var _data: Dictionary = {}

static func stamp(iso: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(iso + "T00:00:00"))

static func iso(day: int) -> String:
	return Time.get_date_string_from_unix_time(day)

static func windows(year: int) -> Array:
	if _data.is_empty():
		var raw: Variant = DatabaseManager.read_json("res://data/world/international_windows.json")
		_data = raw if raw is Dictionary else {}
	var rows: Array = _data.get("years", {}).get(str(year), [])
	var projected := rows.is_empty()
	if projected:
		# Stable template, intentionally NOT labelled as an official future FIFA calendar.
		for md in [[3, 3, 9, 2], [6, 1, 9, 2], [9, 3, 16, 4], [11, 2, 9, 2]]:
			var first := stamp("%04d-%02d-01" % [year, int(md[0])])
			var weekday := int(Time.get_datetime_dict_from_unix_time(first)["weekday"])
			var begin := first + ((1 - weekday + 7) % 7 + (int(md[1]) - 1) * 7) * 86400
			rows.append({"start": iso(begin), "end": iso(begin + (int(md[2]) - 1) * 86400), "max_matches": int(md[3])})
	var out: Array = []
	for r: Dictionary in rows:
		var item := r.duplicate()
		item["a"] = stamp(String(r["start"]))
		item["b"] = stamp(String(r["end"]))
		item["id"] = String(r["start"])
		item["projected"] = projected
		out.append(item)
	return out

static func season_date(w: GameWorld, slot: int = -1) -> int:
	if w.season == null or w.season.calendar.is_empty():
		return stamp("%04d-01-01" % w.year)
	var index := clampi(w.season.day if slot < 0 else slot, 0, w.season.calendar.size() - 1)
	return stamp("%04d-01-01" % w.season.year) + int(w.season.calendar[index]["d"]) * 86400

static func upcoming(day: int) -> Array:
	var y := int(Time.get_datetime_dict_from_unix_time(day)["year"])
	return (windows(y) + windows(y + 1)).filter(func(w): return int(w["b"]) >= day)

static func reserve(calendar: Array, year: int) -> Array:
	if calendar.is_empty(): return calendar
	var jan := stamp("%04d-01-01" % year)
	var all_windows := windows(year) + windows(year + 1) + windows(year + 2)
	var rows := calendar.duplicate(true)
	rows.sort_custom(func(a,b): return int(a["d"]) < int(b["d"]))
	var prev := -10000
	for entry: Dictionary in rows:
		var day := maxi(int(entry["d"]), prev + 2)
		for window: Dictionary in all_windows:
			if jan + day * 86400 >= int(window["a"]) and jan + day * 86400 <= int(window["b"]):
				day = int((int(window["b"]) - jan) / 86400) + 1
		entry["d"] = day
		prev = day
	var first := int(rows[0]["d"])
	var last := int(rows.back()["d"])
	for window: Dictionary in all_windows:
		var day := int((int(window["b"]) - jan) / 86400)
		if day < first or day > last: continue
		rows.append({"t":"I", "d":day, "intl":window["id"], "max_matches":window["max_matches"]})
		var announce := int((int(window["a"]) - jan) / 86400) - 10
		if announce >= first:
			rows.append({"t":"IA", "d":announce, "intl":window["id"]})
	rows.sort_custom(func(a,b): return int(a["d"]) < int(b["d"]))
	return rows
