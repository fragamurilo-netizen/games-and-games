extends TestCase
## Stat panels only count recorded history (Bible §15). Plays one night through
## CareerActions and checks the aggregations match what the engine wrote.

func _play(world: WorldState) -> FightEvent:
	var id: String=load("res://tools/capture_career.gd").play_one_night(world)
	check(not id.is_empty(),"A night was played")
	for ev: FightEvent in world.events.values():
		if ev.organization_id==world.player_org_id and ev.status=="completed":return ev
	return null

func test_summary_matches_completed_night() -> void:
	var world:=WorldGenerator.generate(44,"regional_promoter")
	check_eq(CareerStats.org_summary(world).events,0,"No nights before playing")
	var ev:=_play(world)
	check(ev!=null,"Completed night exists")
	var s:=CareerStats.org_summary(world)
	check_eq(s.events,1,"One completed night")
	check_eq(s.fights,ev.fight_ids.size(),"Every bout counted")
	check_eq(s.margin,int(ev.actual.margin),"Margin comes from the settlement")
	var finishes:=0
	for id: String in ev.fight_ids:
		if world.fights[id].method in ["ko_tko","submission"]:finishes+=1
	check_eq(s.finishes,finishes,"Finishes counted from results")

func test_form_streak_and_methods_follow_results() -> void:
	var world:=WorldGenerator.generate(45,"regional_promoter")
	var ev:=_play(world)
	for id: String in ev.fight_ids:
		var fight: Fight=world.fights[id]
		if fight.winner_id.is_empty():continue
		var winner: Fighter=world.fighters[fight.winner_id]
		var loser: Fighter=world.fighters[fight.fighter_b_id if fight.winner_id==fight.fighter_a_id else fight.fighter_a_id]
		check_eq(CareerStats.form(world,winner),["V"],"Winner form")
		check_eq(CareerStats.form(world,loser),["D"],"Loser form")
		check_eq(CareerStats.streak(world,winner),1,"Winner streak")
		check_eq(CareerStats.streak(world,loser),-1,"Loser streak")
		var methods:=CareerStats.win_methods(world,winner)
		check_eq(methods.ko_tko+methods.submission+methods.decision,1 if fight.method in methods else 0,"One recorded win by method")
		check(CareerStats.fight_averages(world,winner).fights==1,"Averages from the engine stats")

func test_streak_counts_consecutive_results() -> void:
	check_eq(CareerStats.streak_label(3),"3 vitórias seguidas","Win streak label")
	check_eq(CareerStats.streak_label(-2),"2 derrotas seguidas","Loss streak label")
	check_eq(CareerStats.streak_label(1),"","Single result is not a streak")
