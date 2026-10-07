class_name Calendar
extends RefCounted
## Calendário: a Liga Global faz uma noite a cada duas semanas; o circuito continental, uma
## por semana, girando entre os continentes; os eventos regionais, três por semana, nos
## países que mais formam lutadores. Montado com dez semanas de antecedência.

const AHEAD := 11
const CONT_ORDER := ["CONMEBOL", "UEFA", "CONCACAF", "UEFA", "AFC", "CONMEBOL", "CONCACAF", "UEFA", "CAF", "AFC", "OFC", "UEFA"]


static func ensure_events(w: GameWorld) -> void:
	for wk in range(w.week, w.week + AHEAD):
		if w.calendar_weeks.has(wk):
			continue
		w.calendar_weeks.append(wk)
		if wk % 2 == 0:
			_lgc(w, wk)
		_continental(w, wk)
		for _i in 3:
			_regional(w, wk)
	# Semanas antigas saem da lista (o calendário só precisa do que vem pela frente).
	w.calendar_weeks = w.calendar_weeks.filter(func(x: int) -> bool: return x >= w.week - 1)


static func _next_num(w: GameWorld, key: String, start: int) -> int:
	var n := int(w.event_counters.get(key, start)) + 1
	w.event_counters[key] = n
	return n


static func _new_event(w: GameWorld, wk: int, tier: int, name: String, city: String, nation: String, slots: int) -> FightEvent:
	var e := FightEvent.new()
	e.id = w.new_id()
	e.week = wk
	e.tier = tier
	e.name = name
	e.city = city
	e.nation = nation
	e.slots = slots
	w.events[e.id] = e
	return e


static func _lgc(w: GameWorld, wk: int) -> void:
	var cities: Array = DataDB.mma()["lgc_cities"]
	var c: Array = cities[w.rng.randi_range(0, cities.size() - 1)]
	var n := _next_num(w, "LGC", 40)
	_new_event(w, wk, 2, "LGC %d" % n, String(c[0]), String(c[1]), 11)


static func _continental(w: GameWorld, wk: int) -> void:
	var confed: String = CONT_ORDER[wk % CONT_ORDER.size()]
	var name := String((DataDB.mma()["continental"] as Dictionary).get(confed, "Circuito Continental"))
	var nations: Array = []
	for code in DataDB.fight_nations():
		if String(DataDB.nation(code).get("confed", "")) == confed:
			nations.append(code)
	var nat: String = nations[w.rng.randi_range(0, nations.size() - 1)] if not nations.is_empty() else "USA"
	var n := _next_num(w, name, 20)
	_new_event(w, wk, 1, "%s %d" % [name, n], _city(w, nat), nat, 8)


static func _regional(w: GameWorld, wk: int) -> void:
	var nat := FighterGenerator.pick_nation(w.rng, false)
	var city := _city(w, nat)
	var pats: Array = DataDB.mma()["regional_patterns"]
	var key := String(pats[abs(hash(city)) % pats.size()]).format({"c": city})
	var n := _next_num(w, key, w.rng.randi_range(0, 30))
	_new_event(w, wk, 0, "%s %d" % [key, n], city, nat, 6)


static func _city(w: GameWorld, nat: String) -> String:
	var cities: Array = DataDB.cities(nat)
	if cities.is_empty():
		return DataDB.nation_name(nat)
	return String((cities[w.rng.randi_range(0, mini(cities.size() - 1, 9))] as Array)[0])


static func events_in_week(w: GameWorld, wk: int) -> Array:
	var out: Array = []
	for e: FightEvent in w.events.values():
		if e.week == wk:
			out.append(e)
	out.sort_custom(func(a: FightEvent, b: FightEvent) -> bool: return a.tier > b.tier)
	return out


## Eventos futuros com vaga numa camada, entre as semanas `from` e `to`.
static func open_events(w: GameWorld, tier: int, from: int, to: int) -> Array:
	var out: Array = []
	for e: FightEvent in w.events.values():
		if e.tier == tier and e.week >= from and e.week <= to and not e.done and e.bouts.size() < e.slots:
			out.append(e)
	out.sort_custom(func(a: FightEvent, b: FightEvent) -> bool: return a.week < b.week)
	return out
