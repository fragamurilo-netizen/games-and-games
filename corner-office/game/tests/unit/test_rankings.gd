extends TestCase
## Ranking Engine: oposição, limite de saltos, atividade, campeão, P4P.
## Game Design Bible §7 Rankings; MMA Bible §12, §23.

const DIV := "m_lightweight"


## Mundo mínimo: uma organização com `n` lutadores de cartel igual.
func _world(n: int) -> WorldState:
	var w := WorldState.new()
	var org := Organization.new(); org.id = "org_a"
	w.add("organizations", org)
	for i in n:
		var f := Fighter.new()
		f.id = "f%02d" % i; f.first_name = "F"; f.last_name = str(i)
		f.division = DIV; f.organization_id = org.id
		f.record = {"wins": 10 - i % 3, "losses": 3, "draws": 0, "nc": 0}
		w.add("fighters", f)
		org.roster.append(f.id)
	return w


func _fight(w: WorldState, winner: String, loser: String, method := "decision", days_ago := 0) -> void:
	var ev := FightEvent.new(); ev.id = w.new_id("evt"); ev.date = GameDate.add_days(w.date, -days_ago)
	ev.organization_id = "org_a"; ev.status = "completed"
	w.add("events", ev)
	var fight := Fight.new(); fight.id = w.new_id("fgt"); fight.event_id = ev.id
	fight.fighter_a_id = winner; fight.fighter_b_id = loser; fight.division = DIV
	fight.status = "completed"; fight.winner_id = winner; fight.method = method
	w.add("fights", fight)
	for id: String in [winner, loser]:
		w.fighters[id].fight_ids.append(fight.id)
	w.fighters[winner].record.wins += 1
	w.fighters[loser].record.losses += 1


func test_win_over_ranked_opponent_explains_the_climb() -> void:
	var w := _world(10)
	var r := Rankings.new()
	var first := r.update(w, "org_a", DIV)
	var low: String = first.entries[4]; var top: String = first.entries[0]
	w.date = GameDate.add_days(w.date, 7)
	_fight(w, low, top, "ko_tko")
	var second := r.update(w, "org_a", DIV)
	check(second.entries.find(low) < 4, "vencedor sobe: " + str(second.entries))
	check(second.entries.find(top) > 0, "derrotado cai")
	check_eq(second.changes[low].reason.code, "WIN_OVER", "motivo da subida")
	check_eq(int(second.changes[low].reason.data.opponent_rank), 0, "registra a posição do oponente")
	check_eq(second.changes[top].reason.code, "LOSS_TO", "motivo da queda")


func test_climb_is_capped_without_exceptional_win() -> void:
	var w := _world(14)
	var r := Rankings.new()
	var first := r.update(w, "org_a", DIV)
	var bottom: String = first.entries[13]; var next: String = first.entries[12]
	w.date = GameDate.add_days(w.date, 7)
	for i in 3:
		_fight(w, bottom, next, "ko_tko")
	var second := r.update(w, "org_a", DIV)
	check(second.entries.find(bottom) >= 13 - int(ContentDB.load_json("ranking_tuning.json").max_climb), "subida limitada: posição %d" % second.entries.find(bottom))
	check_eq(second.changes[bottom].reason.code, "JUMP_CAPPED", "UI sabe que foi limitado")


func test_exceptional_win_can_jump_to_opponent_spot() -> void:
	var w := _world(14)
	var r := Rankings.new()
	var first := r.update(w, "org_a", DIV)
	var bottom: String = first.entries[13]; var top: String = first.entries[0]
	w.date = GameDate.add_days(w.date, 7)
	for i in 3:
		_fight(w, bottom, top, "submission")
	var second := r.update(w, "org_a", DIV)
	check(second.entries.find(bottom) < 8, "vitória sobre o #1 libera salto grande: %d" % second.entries.find(bottom))


func test_inactivity_lowers_position_without_erasing_record() -> void:
	var w := _world(6)
	var r := Rankings.new()
	var ids: Array = w.fighters.keys()
	for id: String in ids:
		if id != "f00": _fight(w, id, "f00" if id == "f01" else "f01", "decision", 30)
	var idle: Fighter = w.fighters.f02
	var before := r.update(w, "org_a", DIV).entries.find(idle.id)
	var wins: int = idle.record.wins
	w.date = GameDate.add_days(w.date, 900)
	for id: String in ids:
		if id not in ["f02", "f00"]: _fight(w, id, "f00", "decision", 10)
	var after := r.update(w, "org_a", DIV)
	check(after.entries.find(idle.id) > before, "inativo perde posição (%d → %d)" % [before, after.entries.find(idle.id)])
	check_eq(idle.record.wins, wins, "cartel preservado")


func test_champion_is_listed_apart_and_lists_stay_separate() -> void:
	var w := _world(8)
	var outsider := Fighter.new(); outsider.id = "free"; outsider.division = DIV
	outsider.record = {"wins": 30, "losses": 0, "draws": 0, "nc": 0}
	w.add("fighters", outsider)
	w.organizations.org_a.titles[DIV] = {"champion_id": "f03"}
	var r := Rankings.new()
	var official := r.update(w, "org_a", DIV)
	check_eq(official.champion_id, "f03", "campeão no snapshot")
	check(not "f03" in official.entries, "campeão fora da lista numerada")
	check(not "free" in official.entries, "lista oficial só tem atletas da organização")
	var wci := r.update(w, Rankings.WCI_ORG_ID, DIV)
	check_eq(wci.entries[0], "free", "WCI é independente e global")
	check_eq(wci.model, "algorithmic", "WCI é algorítmico")
	var p4p := r.update_p4p(w)
	check(p4p.entries.size() > 0 and p4p.entries.size() <= 15, "P4P gerado a partir do WCI")
	check_eq(r.latest(w, Rankings.WCI_ORG_ID, Rankings.P4P_DIVISION), p4p, "P4P salvo no histórico")


func test_snapshots_are_append_only_and_serializable() -> void:
	var w := _world(6)
	var r := Rankings.new()
	r.update(w, "org_a", DIV)
	check_eq(r.update(w, "org_a", DIV), r.latest(w, "org_a", DIV), "sem mudança não cria snapshot")
	w.date = GameDate.add_days(w.date, 7)
	_fight(w, "f05", "f00", "ko_tko")
	r.update(w, "org_a", DIV)
	check_eq(w.rankings[Rankings.key("org_a", DIV)].size(), 2, "histórico cresce")
	check(r.peak(w, "org_a", DIV, "f05") >= 0, "melhor posição disponível")
	var restored := Ranking.new().load_dict(JSON.parse_string(JSON.stringify(r.latest(w, "org_a", DIV).to_dict())))
	check_eq(restored.changes.keys().size(), r.latest(w, "org_a", DIV).changes.keys().size(), "mudanças sobrevivem ao save")
