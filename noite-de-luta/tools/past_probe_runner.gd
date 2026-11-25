extends Node


func _ready() -> void:
	var w := Career.new_career("Equipe Teste", "", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), 250000.0, 2027)
	var bad := 0
	var n := 0
	var t0 := Time.get_ticks_usec()
	var shown := 0
	for f: Fighter in w.fighters.values():
		if not f.is_pro():
			continue
		n += 1
		var l := PastFights.of(w, f)
		var err := ""
		if l.size() != f.fights():
			err = "total %d != %d" % [l.size(), f.fights()]
		var st := 0
		for h: Dictionary in l:
			var r := String(h["res"])
			st = (st + 1 if st >= 0 else 1) if r == "V" else ((st - 1 if st <= 0 else -1) if r == "D" else 0)
		if st != f.streak and err == "":
			err = "sequência %d != %d" % [st, f.streak]
		for i in range(1, l.size()):
			if int(l[i]["week"]) <= int(l[i - 1]["week"]):
				err = "datas fora de ordem"
		if not l.is_empty():
			var d := GameWorld.date_of(int(l[0]["week"]))
			if int(d["year"]) - f.birth_year < 17:
				err = "estreia aos %d" % (int(d["year"]) - f.birth_year)
			if int(l.back()["week"]) != f.last_fight_week:
				err = "última luta fora da data"
		if err != "":
			bad += 1
			if bad <= 8:
				print("ERRO ", f.display_name(), " ", f.record_text(), ": ", err)
		elif shown < 3 and (f.titles_won > 0 or f.fights() >= 18) and shown * 600 < n:
			shown += 1
			print("--- ", f.display_name(), " ", f.record_text(), " · ", w.age_of(f), " anos · cinturões ", f.titles_won, "+", f.title_defenses, " · sequência ", f.streak)
			for h: Dictionary in l:
				print("  %s %-26s %-7s %-40s R%d  %-28s %s%s" % [h["res"], h["opp_name"], h["opp_rec"], h["detail"], h["round"], h["event"], GameWorld.fight_date_text(int(h["week"])), "  CINTURÃO" if h["title"] else ""])
	# Vida: terra, dons e artes raras.
	var by_cult := {}
	var gifts := {}
	var sample := 0
	for f: Fighter in w.fighters.values():
		var c := Bio.culture(f)
		if f.nation == "RUS" or c in ["dag", "chech"]:
			var k := "%s/%s" % [f.nation, c]
			by_cult[k] = int(by_cult.get(k, 0)) + 1
		if f.gift != "":
			gifts[f.gift] = int(gifts.get(f.gift, 0)) + 1
		if (c in ["chech", "dag"] or f.gift != "" or f.nation in ["BRA", "THA", "USA"]) and sample < 7 and f.id % 9 == 0:
			sample += 1
			print("=== ", f.display_name(), " · ", DataDB.nation_name(f.nation), " · ", Styles.describe(f), " · ", f.record_text(), (" · DOM: " + Bio.gift_name(f)) if f.gift != "" else "")
			for l: String in Bio.lines(w, f):
				print("   ", l)
			for t: Dictionary in Bio.timeline(w, f):
				print("   %d  %s: %s" % [t["year"], t["title"], t["text"]])
	print("russos e caucasianos: ", by_cult)
	print("dons: ", gifts, " de ", w.fighters.size())
	print("lutadores profissionais: %d · com erro: %d · %.1f ms no total" % [n, bad, float(Time.get_ticks_usec() - t0) / 1000.0])
	get_tree().quit()
