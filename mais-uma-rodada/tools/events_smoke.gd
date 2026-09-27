extends SceneTree
## Monta cada tipo de evento do usuário, descreve e resolve todas as opções (pega erro de execução).


func _initialize() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	for i in 8:
		SeasonManager.play_matchday_instant(w)
	var ok := 0
	var skipped: Array = []
	for k in ["party", "betting", "baby", "social", "extra", "rebel", "chairman", "discipline", "fight", "mercenary"]:
		var built := false
		for attempt in 40:
			var ev := EventManager._build(w, k)
			if ev.is_empty():
				continue
			built = true
			var desc := EventManager.describe(w, ev)
			for opt in (desc["options"] as Array).size():
				var e2 := ev.duplicate(true)
				w.events.append(e2)
				var msg := EventManager.resolve(w, e2, opt)
				print("%-10s opção %d: %s" % [k, opt, msg])
			ok += 1
			break
		if not built:
			skipped.append(k)
	print("tipos testados: %d · sem candidato no elenco: %s" % [ok, str(skipped)])
	quit()
