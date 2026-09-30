extends TestCase
## Calibragem ampla do FightEngine (Game Design Bible §21; MMA Bible Apêndice A).
## 600 lutas entre atletas gerados. Faixas largas de propósito: detectam
## regressões grosseiras (ex.: metade das lutas em finalização), não ajuste fino.
## Soak completo: godot --headless --path game -s res://tools/soak_fights.gd -- 3000


func test_method_distribution_and_upsets_stay_in_realistic_bands() -> void:
	var lib: GDScript = load("res://tools/soak_lib.gd")
	var r: Dictionary = lib.run(600, 7)
	var m: Dictionary = r.share.m
	var f: Dictionary = r.share.f
	check(float(m.get("submission", 0)) >= .08 and float(m.get("submission", 0)) <= .32, "Finalizações masc. %.2f" % m.get("submission", 0))
	check(float(m.get("ko_tko", 0)) >= .18 and float(m.get("ko_tko", 0)) <= .45, "KO/TKO masc. %.2f" % m.get("ko_tko", 0))
	check(float(m.get("decision", 0)) >= .32 and float(m.get("decision", 0)) <= .65, "Decisões masc. %.2f" % m.get("decision", 0))
	check(float(f.get("ko_tko", 0)) < float(m.get("ko_tko", 0)) + .05, "Feminino não nocauteia mais que masculino")
	check(float(f.get("decision", 0)) >= .40, "Decisões fem. %.2f" % f.get("decision", 0))
	check(float(r.big_gap_favorite_win_rate) < .98, "Grande favorito ainda perde às vezes: %.2f" % r.big_gap_favorite_win_rate)
	check(float(r.favorite_win_rate) > .6, "Técnica importa: favorito vence %.2f" % r.favorite_win_rate)
	print("  Calibração: ", r)
