extends SceneTree
## Distribuição de penteados e barbas no mundo gerado (por idade e origem).
## godot --headless --path . --script res://tools/hair_stats.gd


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var hs: Dictionary = {}
	var bd: Dictionary = {}
	var n := 0
	var cat := {"flashy": 0, "long": 0, "bald": 0, "dyed": 0}
	var bcat := {"limpo": 0, "rala/por fazer": 0, "barba": 0, "classica": 0, "exotica": 0}
	var by_age: Dictionary = {}
	var by_eth: Dictionary = {}
	var real := FaceGen._beard_realism()
	for p: Player in w.players.values():
		var age := p.age(w.year)
		var f := FaceGen.features(p.face_seed, p.eth, age, p.look)
		n += 1
		var s := int(f["style"])
		var b := int(f["beard"])
		hs[s] = int(hs.get(s, 0)) + 1
		bd[b] = int(bd.get(b, 0)) + 1
		var name: String = FaceGen.HAIR_STYLES[s]
		if name in FaceGen.FLASHY_STYLE_NAMES:
			cat["flashy"] += 1
		if name in FaceGen.LONG_STYLE_NAMES:
			cat["long"] += 1
		if s == FaceGen.H_BALD:
			cat["bald"] += 1
		if int(f["hair_i"]) in FaceGen.DYED or bool(f.get("tips", false)):
			cat["dyed"] += 1
		var k := "limpo"
		if b != FaceGen.B_NONE:
			var m := real[b]
			k = "rala/por fazer" if m == 1.0 else ("barba" if m == 1.5 else ("classica" if m == 0.9 else "exotica"))
		bcat[k] += 1
		var ab := "<21" if age < 21 else ("21-25" if age < 26 else ("26-30" if age < 31 else "31+"))
		var row: Dictionary = by_age.get(ab, {"n": 0, "limpo": 0, "barba": 0, "flashy": 0, "bald": 0})
		row["n"] += 1
		if b == FaceGen.B_NONE:
			row["limpo"] += 1
		elif k == "barba" or k == "classica" or k == "exotica":
			row["barba"] += 1
		if name in FaceGen.FLASHY_STYLE_NAMES:
			row["flashy"] += 1
		if s == FaceGen.H_BALD or s == FaceGen.H_BUZZ:
			row["bald"] += 1
		by_age[ab] = row
		var eg := FaceGen.style_group(p.eth)
		var er: Dictionary = by_eth.get(eg, {"n": 0, "limpo": 0, "barba": 0, "top": {}})
		er["n"] += 1
		if b == FaceGen.B_NONE:
			er["limpo"] += 1
		elif k != "rala/por fazer":
			er["barba"] += 1
		er["top"][name] = int(er["top"].get(name, 0)) + 1
		by_eth[eg] = er
	print("jogadores: ", n)
	for k in cat:
		print("  %-8s %5.1f%%" % [k, 100.0 * cat[k] / n])
	for k in bcat:
		print("  barba %-15s %5.1f%%" % [k, 100.0 * bcat[k] / n])
	for ab in ["<21", "21-25", "26-30", "31+"]:
		var r: Dictionary = by_age.get(ab, {})
		if r.is_empty():
			continue
		var rn := float(r["n"])
		print("  idade %-6s n=%5d limpo %4.0f%% barba %4.0f%% chamativo %4.1f%% careca/máquina %4.1f%%" % [ab, r["n"], 100 * r["limpo"] / rn, 100 * r["barba"] / rn, 100 * r["flashy"] / rn, 100 * r["bald"] / rn])
	for eg in by_eth:
		var r2: Dictionary = by_eth[eg]
		var top: Array = (r2["top"] as Dictionary).keys()
		top.sort_custom(func(a, b): return r2["top"][a] > r2["top"][b])
		var tops: Array = []
		for t in top.slice(0, 6):
			tops.append("%s %.0f%%" % [t, 100.0 * r2["top"][t] / r2["n"]])
		print("  grupo %d n=%5d limpo %3.0f%% barba %3.0f%% | %s" % [eg, r2["n"], 100.0 * r2["limpo"] / r2["n"], 100.0 * r2["barba"] / r2["n"], ", ".join(tops)])
	var hk := hs.keys()
	hk.sort_custom(func(a, b): return hs[a] > hs[b])
	print("penteados mais comuns:")
	for s in hk.slice(0, 25):
		print("  %5.1f%% %3d %s" % [100.0 * hs[s] / n, s, FaceGen.HAIR_STYLES[s]])
	var bk := bd.keys()
	bk.sort_custom(func(a, b): return bd[a] > bd[b])
	print("barbas mais comuns:")
	for b in bk.slice(0, 25):
		print("  %5.1f%% %3d %s" % [100.0 * bd[b] / n, b, FaceGen.BEARDS[b]])
	quit()
