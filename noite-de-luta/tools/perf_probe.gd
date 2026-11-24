extends "res://tools/season_probe.gd"
## Sonda de desempenho: joga N semanas sozinha e mede o tempo de cada parte da virada de semana
## e do save (montar o dicionário, escrever, ler de volta). Serve para achar o que pesa em
## celular fraco e conferir o tamanho do save em carreira longa.
## godot --headless --path . --script res://tools/perf_probe.gd -- --weeks=104 [--role=presidente] [--seed=2027] [--save=ARQ]


func _initialize() -> void:
	var weeks := 104
	var role := "empresario"
	var seed_v := 2027
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--weeks="):
			weeks = int(a.substr(8))
		elif a.begins_with("--role="):
			role = a.substr(7)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
		elif a.begins_with("--save="):
			out = a.substr(7)
	var pres := role == "presidente"
	var t0 := Time.get_ticks_usec()
	var w: GameWorld
	if pres:
		w = Org.new_career("Liga Teste", "LT", "USA", Color("#B3262E"), Color("#F1F0EC"), Org.START_FUNDS[1], seed_v)
	else:
		w = Career.new_career("Equipe Teste", "TST", "BRA", "Recife", Color("#B3262E"), Color("#F1F0EC"), Career.START_FUNDS[1], seed_v)
	print("papel %s · mundo novo em %.0f ms" % [role, _ms(t0)])
	var sum := 0.0
	var worst := 0.0
	var block := 0.0
	for i in weeks:
		if pres:
			_president_turn(w)
		else:
			_manager_turn(w, false)
		var t1 := Time.get_ticks_usec()
		Career.advance_week(w, true)
		var ms := _ms(t1)
		sum += ms
		block += ms
		worst = maxf(worst, ms)
		if (i + 1) % 52 == 0:
			print("   ano %d: média %.0f ms por semana (pior até aqui %.0f ms) · %s" % [(i + 1) / 52, block / 52.0, worst, _size(w)])
			block = 0.0
	print("virada de semana: média %.0f ms, pior %.0f ms em %d semanas" % [sum / float(maxi(1, weeks)), worst, weeks])
	# Partes da semana, uma a uma (média de cinco chamadas; não são idempotentes, mas o tempo vale).
	var parts := {
		"ranking": func() -> void: Rankings.rebuild(w),
		"treino e idade": func() -> void: Development.week(w),
		"casar lutas (CPU)": func() -> void: Matchmaker.book_cpu(w),
		"rivalidades": func() -> void: Rivalry.week(w),
		"marcas de carreira": func() -> void: CareerStats.weekly_marks(w),
		"amostra de carreira": func() -> void: CareerStats.sample_all(w),
		"temporada": func() -> void: Season.week(w),
		"conquistas": func() -> void: Achievements.check(w),
		"caixa de entrada": func() -> void: Inbox.scan(w),
		"calendário": func() -> void: Calendar.ensure_events(w),
	}
	for k: String in parts:
		var t2 := Time.get_ticks_usec()
		for _i in 5:
			(parts[k] as Callable).call()
		print("   %-22s %7.1f ms" % [k, _ms(t2) / 5.0])
	# Uma luta simulada (sem narração).
	var bouts: Array = w.bouts.values().filter(func(b: Bout) -> bool: return b.status == "marcada")
	if not bouts.is_empty():
		var t3 := Time.get_ticks_usec()
		var n := mini(10, bouts.size())
		for i in n:
			var e := Career.engine_for(w, bouts[i], false)
			e.run_all()
		print("   %-22s %7.1f ms (cada; a semana tem perto de %d)" % ["luta simulada", _ms(t3) / float(n), w.bouts.values().filter(func(b: Bout) -> bool: return b.week == w.week + 1).size()])
	# Save.
	var t4 := Time.get_ticks_usec()
	var d := w.to_dict()
	var ms_dict := _ms(t4)
	t4 = Time.get_ticks_usec()
	var js := JSON.stringify(d)
	var ms_json := _ms(t4)
	t4 = Time.get_ticks_usec()
	var back: Variant = JSON.parse_string(js)
	var ms_parse := _ms(t4)
	t4 = Time.get_ticks_usec()
	var w2 := GameWorld.from_dict(back)
	var ms_from := _ms(t4)
	t4 = Time.get_ticks_usec()
	var raw := var_to_bytes(d)
	var ms_bin := _ms(t4)
	t4 = Time.get_ticks_usec()
	var zip := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var ms_zip := _ms(t4)
	t4 = Time.get_ticks_usec()
	var back2: Variant = bytes_to_var(zip.decompress(raw.size(), FileAccess.COMPRESSION_ZSTD))
	var ms_unbin := _ms(t4)
	print("save: montar %.0f ms · JSON %.0f ms (%d KB) · ler JSON %.0f ms · remontar %.0f ms" % [ms_dict, ms_json, js.length() / 1024, ms_parse, ms_from])
	print("save binário (só para comparar): %.0f ms (%d KB) · comprimir %.0f ms (%d KB) · ler %.0f ms" % [ms_bin, raw.size() / 1024, ms_zip, zip.size() / 1024, ms_unbin])
	# Segundo save seguido (o que o jogo paga depois do primeiro): o histórico já está convertido.
	t4 = Time.get_ticks_usec()
	var d_again := w.to_dict()
	var ms_dict2 := _ms(t4)
	t4 = Time.get_ticks_usec()
	JSON.stringify(d_again)
	print("save seguinte: montar %.0f ms · JSON %.0f ms" % [ms_dict2, _ms(t4)])
	# Abrir e salvar de novo tem de dar o mesmo arquivo (a primeira leitura troca inteiros por
	# números quebrados em alguns campos; da segunda em diante nada mais pode mudar).
	var js2 := JSON.stringify(w2.to_dict())
	var js3 := JSON.stringify(GameWorld.from_dict(JSON.parse_string(js2)).to_dict())
	print("reabrir e salvar dá o mesmo arquivo: %s (%d KB e %d KB)" % [js2 == js3, js2.length() / 1024, js3.length() / 1024])
	if back2 == null:
		print("leitura binária falhou")
	print("mundo: ", _size(w))
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(js)
		f.close()
	quit()


func _ms(t0: int) -> float:
	return float(Time.get_ticks_usec() - t0) / 1000.0


func _size(w: GameWorld) -> String:
	var retired := 0
	var hist := 0
	for f: Fighter in w.fighters.values():
		if f.retired:
			retired += 1
		hist += f.history.size()
	return "%d lutadores (%d aposentados), %d lutas guardadas, %d eventos, %d entradas de histórico, %d notícias" % [w.fighters.size(), retired, w.bouts.size(), w.events.size(), hist, w.news.size()]
