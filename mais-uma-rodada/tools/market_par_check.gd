extends SceneTree
## Mercado da IA em várias threads = em uma só: mesmo mundo, mesmas datas, mesmo resultado
## (planos da janela, memória dos olheiros, transferências e onde cada jogador está).
## godot --headless --path . --script res://tools/market_par_check.gd -- --days=4


func _init() -> void:
	var days := 4
	var par_first := false
	var modes := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--days="):
			days = int(a.substr(7))
		elif a == "--par-first":
			par_first = true
		elif a.begins_with("--modes="):
			modes = a.substr(8) # ex.: 00 = sequencial duas vezes (mundo anterior contamina o seguinte?)
	var sigs: Array = []
	var times: Array = []
	for k in 2:
		var mode := (1 - k) if par_first else k
		if modes.length() == 2:
			mode = int(modes[k])
		SeasonManager.parallel = mode == 1
		var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
		w.user_club_id = w.clubs_in_league("BRA1")[5].id
		w.manager_name = "Teste"
		var c := w.user_club()
		FinanceManager.set_budgets(w, c)
		c.sheet = ClubAI.auto_sheet(w, c, "")
		YouthManager.ensure_academy(w)
		YouthManager.build_league(w)
		SeasonManager.timings.clear()
		var t := Time.get_ticks_msec()
		for d in days:
			if w.season.finished:
				break
			SeasonManager.play_matchday_instant(w)
		times.append(Time.get_ticks_msec() - t)
		print("%s: %d ms  plano paralelo %.0f ms, plano em ordem %.0f ms" % ["paralelo" if mode == 1 else "sequencial", times[-1],
			int(SeasonManager.timings.get("pl_paralelo", 0)) / 1000.0, int(SeasonManager.timings.get("pl_ordem", 0)) / 1000.0])
		_top(SeasonManager.timings, 18)
		sigs.append(_sig(w))
	if par_first:
		sigs.reverse()
	SeasonManager.parallel = true
	print("assinatura: %s" % [[sigs[0][0], sigs[0][1], sigs[0][2], sigs[0][3]]])
	var names := ["planos", "olheiros", "transferências", "jogadores"]
	var ok := true
	for i in names.size():
		var same: bool = sigs[0][i] == sigs[1][i]
		ok = ok and same
		print("  %s: %s" % [names[i], "iguais" if same else "DIFERENTES"])
	print("transferências: %d" % sigs[0][4])
	if not ok:
		_explain(sigs[0][5], sigs[1][5])
	print("RESULTADO: %s" % ("OK" if ok else "FALHOU"))
	quit(0 if ok else 1)


func _top(d: Dictionary, n: int) -> void:
	var keys := d.keys()
	keys.sort_custom(func(a, b): return int(d[a]) > int(d[b]))
	var parts: Array = []
	for k in keys.slice(0, n):
		parts.append("%s %.0f" % [k, int(d[k]) / 1000.0])
	print("    etapas (ms): " + ", ".join(PackedStringArray(parts)))


func _sig(w: GameWorld) -> Array:
	var st: Dictionary = w.stats.get("mkt", {})
	var tl: Array = []
	for t: Transfer in w.transfer_log:
		tl.append([t.player_id, t.from_id, t.to_id, t.fee, t.year])
	var ids: Array = w.players.keys()
	ids.sort()
	var ps: Array = []
	for pid in ids:
		var p: Player = w.players[pid]
		ps.append([pid, p.club_id, p.wage, p.transfer_listed, p.loan, snappedf(p.condition, 0.001), snappedf(p.morale, 0.001),
			p.injury_weeks, p.suspension, p.yellow_acc, p.stats, p.recent_ratings, p.minutes_season])
	var det := {"csn": w.stats.get("csn", {}).duplicate(true), "plans": st.get("plans", {}).duplicate(true), "pl": {}}
	for e: Array in ps:
		det["pl"][e[0]] = e
	return [hash(var_to_bytes(st.get("plans", {}))), hash(var_to_bytes(w.stats.get("csn", {}))),
		hash(var_to_bytes(tl)), hash(var_to_bytes(ps)), tl.size(), det]


## Onde as duas execuções divergem (os primeiros casos de cada parte).
func _explain(a: Dictionary, b: Dictionary) -> void:
	var names := ["id", "clube", "salário", "listado", "empréstimo", "condição", "moral", "lesão", "suspensão", "amarelos", "stats", "notas", "minutos"]
	var n := 0
	var fields := {}
	for pid in a["pl"]:
		var x: Array = a["pl"][pid]
		var y: Array = b["pl"].get(pid, [])
		if y.is_empty() or var_to_bytes(x) != var_to_bytes(y):
			for i in x.size():
				if y.is_empty() or var_to_bytes(x[i]) != var_to_bytes(y[i]):
					fields[names[i]] = int(fields.get(names[i], 0)) + 1
					if n < 6:
						print("  jogador %d %s: %s × %s" % [pid, names[i], str(x[i]).left(160), str(y[i] if not y.is_empty() else "-").left(160)])
			n += 1
	print("  jogadores diferentes: %d  campos: %s" % [n, fields])
	n = 0
	for cid in a["csn"]:
		var x: Dictionary = a["csn"][cid]
		var y: Dictionary = b["csn"].get(cid, {})
		if var_to_bytes(x) != var_to_bytes(y):
			if n < 3:
				var kx: Dictionary = x.get("k", {})
				var ky: Dictionary = y.get("k", {})
				var only_a := kx.keys().filter(func(k): return not ky.has(k))
				var only_b := ky.keys().filter(func(k): return not kx.has(k))
				var diffv := kx.keys().filter(func(k): return ky.has(k) and kx[k] != ky[k])
				print("  olheiros clube %s: %d × %d conhecidos; só A %s, só B %s, valor diferente %s" % [cid, kx.size(), ky.size(), only_a.slice(0, 5), only_b.slice(0, 5), diffv.slice(0, 5)])
			n += 1
	print("  clubes com olheiros diferentes: %d" % n)
	n = 0
	for cid in a["plans"]:
		if var_to_bytes(a["plans"][cid]) != var_to_bytes(b["plans"].get(cid, {})):
			if n < 2:
				print("  plano %s:\n    %s\n    %s" % [cid, str(a["plans"][cid]).left(400), str(b["plans"].get(cid, {})).left(400)])
			n += 1
	print("  planos diferentes: %d" % n)
