extends Node
## Lógica de events_smoke.gd (carregada depois dos autoloads).
## Monta cada tipo de evento do usuário, descreve e resolve todas as opções (pega erro de execução).


func _ready() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	for i in 8:
		SeasonManager.play_matchday_instant(w)
	var ok := 0
	var skipped: Array = []
	ok += _pass(w, EventManager.KINDS.keys(), skipped)
	# Segunda passada com o clube em crise, para os tipos que dependem de má fase.
	var c := w.user_club()
	c.balance = -2000000
	c.board_confidence = 30.0
	c.fan_mood = 30.0
	c.streak_losses = 3
	c.streak_winless = 5
	var i := 0
	for p: Player in w.squad(c):
		if p.squad_status <= Player.STATUS_STARTER:
			if i < 2:
				p.injury_weeks = 3
				p.injury_name = "Lesão muscular"
			else:
				p.condition = 70.0
			i += 1
		if i == 3:
			p.contract_end = w.year
		if i == 4:
			p.birth_year = w.year - 34
			p.joined_year = w.year - 7
			p.contract_end = w.year
			i += 1
		if p.nationality != c.nation and not p.is_injured():
			p.injury_weeks = 4
			p.injury_name = "Lesão no joelho"
	if not c.rivals.is_empty():
		print("rival: ", w.club(int(c.rivals[0])).short_name)
	var again := skipped.duplicate()
	skipped.clear()
	ok += _pass(w, again, skipped)
	print("tipos testados: %d · sem candidato no elenco: %s" % [ok, str(skipped)])
	for t in 6:
		EventPack.after_turn(w, w.current_turn() + t, ["V", "E", "D"][t % 3])
	get_tree().quit()


func _pass(w: GameWorld, kinds: Array, skipped: Array) -> int:
	var ok := 0
	for k in kinds:
		var built := false
		for attempt in 40:
			var ev := EventManager._build(w, k)
			if ev.is_empty():
				continue
			built = true
			var desc := EventManager.describe(w, ev)
			print("== %s | %s" % [desc["title"], desc["body"]])
			for opt in (desc["options"] as Array).size():
				var e2 := ev.duplicate(true)
				w.events.append(e2)
				var msg := EventManager.resolve(w, e2, opt)
				print("%-10s opção %d: %s" % [k, opt, msg])
			ok += 1
			break
		if not built:
			skipped.append(k)
	return ok

