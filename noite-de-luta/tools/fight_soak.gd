extends SceneTree
## Calibragem do motor: milhares de lutas entre lutadores gerados de nível parecido, por categoria.
## godot --headless --path . --script res://tools/fight_soak.gd -- --n=400 --seed=7
## Mostra a divisão KO/TKO, finalização e decisão (alvo do MMA real: ~31% / 19% / 50% nos homens,
## ~15% / 22% / 63% nas mulheres; pesos pesados nocauteiam mais), quantas vezes o melhor ganha e
## números médios por luta (golpes, quedas, tentativas de finalização).


func _initialize() -> void:
	var n := 300
	var seed_v := 7
	var verbose := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a == "--log":
			verbose = true
	var w := GameWorld.new()
	w.rng.seed = seed_v
	var all := {"KO": 0, "TKO": 0, "FIN": 0, "DEC": 0, "EMP": 0}
	var t0 := Time.get_ticks_msec()
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var cnt := {"KO": 0, "TKO": 0, "FIN": 0, "DEC": 0, "EMP": 0}
		var fav_w := 0
		var fav_n := 0
		var sig := 0.0
		var land := 0.0
		var td := 0.0
		var sub := 0.0
		var r5 := 0
		for i in n:
			var lvl := w.rng.randf_range(48.0, 82.0)
			var fa := FighterGenerator.make(w, div, lvl + w.rng.randf_range(-6.0, 6.0))
			var fb := FighterGenerator.make(w, div, lvl + w.rng.randf_range(-6.0, 6.0))
			var e := FightEngine.new()
			var rounds := 5 if i % 10 == 0 else 3
			e.setup(fa, fb, rounds, false, w.rng, {"narrate": verbose and i < 2, "ko": float(d["ko"])})
			var res := e.run_all()
			var m := String(res["method"])
			cnt[m] += 1
			all[m] += 1
			if absi(fa.level() - fb.level()) >= 5 and int(res["winner"]) >= 0:
				fav_n += 1
				var fav := 0 if fa.level() > fb.level() else 1
				if int(res["winner"]) == fav:
					fav_w += 1
			for st: Dictionary in res["stats"]:
				sig += float(st["sig_att"])
				land += float(st["sig_land"])
				td += float(st["td"])
				sub += float(st["sub_att"])
			if verbose and i < 2:
				for ev: Dictionary in e.events:
					print("  R%d %s  %s" % [int(ev["r"]), Fmt.clock(300.0 - float(ev["t"])), ev["text"]])
				print(res)
		var tot := float(n)
		print("%-5s KO/TKO %4.1f%%  FIN %4.1f%%  DEC %4.1f%%  EMP %3.1f%% | melhor vence %4.1f%% | golpes/luta %5.1f (acerto %4.1f%%) quedas %4.2f fin.tent %4.2f" % [
			div, (cnt["KO"] + cnt["TKO"]) * 100.0 / tot, cnt["FIN"] * 100.0 / tot, cnt["DEC"] * 100.0 / tot, cnt["EMP"] * 100.0 / tot,
			fav_w * 100.0 / maxf(1.0, fav_n), sig / tot, land * 100.0 / maxf(1.0, sig), td / tot, sub / tot])
	var T := 0.0
	for k in all:
		T += all[k]
	print("TOTAL KO %4.1f%% TKO %4.1f%% FIN %4.1f%% DEC %4.1f%% EMP %3.1f%%  (%d lutas, %d ms)" % [all["KO"] * 100.0 / T, all["TKO"] * 100.0 / T, all["FIN"] * 100.0 / T, all["DEC"] * 100.0 / T, all["EMP"] * 100.0 / T, int(T), Time.get_ticks_msec() - t0])
	quit()
