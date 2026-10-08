extends SceneTree
## Laboratório de estilos: confronto de duas artes de base, mesmo nível, muitas lutas.
## godot --headless --path . --script res://tools/style_lab.gd -- --a=wrestling --b=muay_thai [--div=M70] [--n=300] [--log=2] [--lvl=70] [--notraits]
## Sem --a/--b: tabela de cada base contra um "Formado no MMA" do mesmo nível.
## --world: lutadores gerados como no jogo (país, base e segunda arte), aproveitamento por base.
## Mostra quem vence, como (KO/TKO, finalização, decisão), quedas por luta e as finalizações e
## golpes de nocaute mais comuns de cada lado.


func _initialize() -> void:
	var a := ""
	var b := ""
	var div := "M70"
	var n := 300
	var logs := 0
	var lvl := 70.0
	for arg in OS.get_cmdline_user_args():
		if arg == "--notraits":
			no_traits = true
		if arg.begins_with("--a="):
			a = arg.substr(4)
		elif arg.begins_with("--b="):
			b = arg.substr(4)
		elif arg.begins_with("--div="):
			div = arg.substr(6)
		elif arg.begins_with("--n="):
			n = int(arg.substr(4))
		elif arg.begins_with("--log="):
			logs = int(arg.substr(6))
		elif arg.begins_with("--lvl="):
			lvl = float(arg.substr(6))
	var w := GameWorld.new()
	w.rng.seed = 11
	if OS.get_cmdline_user_args().has("--world"):
		_world(w, n)
	elif a != "" and b != "":
		_matchup(w, a, b, div, n, logs, lvl, true)
	else:
		for id: String in Styles.bases():
			if id != "mma":
				_matchup(w, id, "mma", div, n, 0, lvl, false)
	quit()


var no_traits := false


func _make(w: GameWorld, base: String, div: String, lvl: float) -> Fighter:
	var f := FighterGenerator.make(w, div, lvl)
	f.base = base
	f.base2 = ""
	# Refaz os atributos com a base forçada (o gerador já sorteou outra).
	FighterGenerator._make_attrs(f, w.rng, lvl, 28, DataDB.division(div))
	return f


func _matchup(w: GameWorld, a: String, b: String, div: String, n: int, logs: int, lvl: float, detail: bool) -> void:
	var wins := [0, 0]
	var how := [{"KO": 0, "TKO": 0, "FIN": 0, "DEC": 0}, {"KO": 0, "TKO": 0, "FIN": 0, "DEC": 0}]
	var details := [{}, {}]
	var td := [0.0, 0.0]
	var d := DataDB.division(div)
	for i in n:
		var fa := _make(w, a, div, lvl + w.rng.randf_range(-3.0, 3.0))
		var fb := _make(w, b, div, lvl + w.rng.randf_range(-3.0, 3.0))
		var e := FightEngine.new()
		e.setup(fa, fb, 3, false, w.rng, {"narrate": i < logs, "ko": float(d.get("ko", 1.0))})
		if no_traits:
			# Comparação: mesmo lutador, sem as marcas da escola (só atributos e repertório).
			for k in 2:
				var pr: Dictionary = (e.prof[k] as Dictionary).duplicate()
				pr["traits"] = {}
				e.prof[k] = pr
		var res := e.run_all()
		var win := int(res["winner"])
		if i < logs:
			print("\n--- %s (%s) × %s (%s)" % [fa.display_name(), Styles.describe(fa), fb.display_name(), Styles.describe(fb)])
			for ev: Dictionary in e.events:
				print("  R%d %s  %s" % [int(ev["r"]), Fmt.clock(300.0 - float(ev["t"])), ev["text"]])
			print("  => ", res["detail"], " ", "vermelho" if win == 0 else ("azul" if win == 1 else "empate"))
		for k in 2:
			td[k] += float(res["stats"][k]["td"])
		if win < 0:
			continue
		wins[win] += 1
		var m := String(res["method"])
		if how[win].has(m):
			how[win][m] += 1
		var det := String(res["detail"])
		if m != "DEC":
			details[win][det] = int(details[win].get(det, 0)) + 1
	var line := "%-14s × %-14s  vence %4.1f%% (KO/TKO %3d FIN %3d DEC %3d) | quedas/luta %4.2f × %4.2f" % [
		Styles.short(a), Styles.short(b), wins[0] * 100.0 / maxf(1.0, wins[0] + wins[1]),
		how[0]["KO"] + how[0]["TKO"], how[0]["FIN"], how[0]["DEC"], td[0] / n, td[1] / n]
	print(line)
	if detail:
		for k in 2:
			var dd: Dictionary = details[k]
			var keys := dd.keys()
			keys.sort_custom(func(x: String, y: String) -> bool: return int(dd[x]) > int(dd[y]))
			var top: Array = []
			for kk: String in keys.slice(0, 6):
				top.append("%s %d" % [kk, int(dd[kk])])
			print("  %s: %s" % [Styles.short(a if k == 0 else b), ", ".join(top)])


## Como no jogo: dois lutadores sorteados do mesmo nível em todas as categorias; aproveitamento
## de cada base (com a segunda arte que o gerador der).
func _world(w: GameWorld, n: int) -> void:
	var tally := {}
	for i in n * 10:
		var d: Dictionary = DataDB.divisions()[i % DataDB.divisions().size()]
		var div := String(d["id"])
		var lvl := w.rng.randf_range(50.0, 82.0)
		var fa := FighterGenerator.make(w, div, lvl)
		var fb := FighterGenerator.make(w, div, lvl)
		var e := FightEngine.new()
		e.setup(fa, fb, 3, false, w.rng, {"narrate": false, "ko": float(d.get("ko", 1.0))})
		var res := e.run_all()
		var win := int(res["winner"])
		for k in 2:
			var f := fa if k == 0 else fb
			var t: Dictionary = tally.get(f.base, {"n": 0, "w": 0, "ko": 0, "fin": 0})
			t["n"] += 1
			if win == k:
				t["w"] += 1
				if String(res["method"]) in ["KO", "TKO"]:
					t["ko"] += 1
				elif String(res["method"]) == "FIN":
					t["fin"] += 1
			tally[f.base] = t
	var keys := tally.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return int(tally[x]["n"]) > int(tally[y]["n"]))
	for k: String in keys:
		var t: Dictionary = tally[k]
		print("%-18s lutas %5d  aproveitamento %4.1f%%  vitórias: KO %4.1f%% FIN %4.1f%%" % [Styles.short(k), int(t["n"]), t["w"] * 100.0 / maxf(1.0, t["n"]),
			t["ko"] * 100.0 / maxf(1.0, t["w"]), t["fin"] * 100.0 / maxf(1.0, t["w"])])
