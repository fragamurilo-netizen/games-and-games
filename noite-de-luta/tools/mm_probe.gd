extends SceneTree
## Confere o atalho "Deixar com o matchmaker": pendências de card e de cinturão vago antes e depois.
func _initialize() -> void:
	var w := Org.new_career("Liga Teste", "LT", "BRA", Color.RED, Color.WHITE, 2.0e7, 7)
	var freed := 0
	for d: Dictionary in DataDB.divisions():
		if freed < 2 and Org.title_booked(w, String(d["id"])) == null and Titles.booked(w, String(d["id"])) == null:
			w.champions[String(d["id"])] = -1
			freed += 1
	for ev: FightEvent in Org.upcoming_events(w).slice(1, 3):
		for bt: Bout in Org.event_bouts(w, ev).slice(0, 3):
			Org.cancel(w, bt)
	Inbox.scan(w)
	var count := func() -> int:
		return Inbox.pending(w).filter(func(m: Dictionary) -> bool: return String(m["act"]) == "org_event" or String(m.get("key", "")).begins_with("vago:")).size()
	print("eventos=", Org.upcoming_events(w).size(), " pend=", Inbox.pending(w).map(func(m: Dictionary) -> String: return String(m.get("key", ""))), " pres=", w.is_president())
	var before: int = count.call()
	var res := Org.matchmaker_now(w, Inbox.CARD_WEEKS)
	Inbox.scan(w)
	print("antes=", before, " depois=", count.call(), " ", res)
	quit()
