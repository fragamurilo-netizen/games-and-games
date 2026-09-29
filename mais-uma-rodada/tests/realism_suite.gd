extends RefCounted
var failures:=0
var checks:=0
var metrics:={}
var w:GameWorld
var tree:SceneTree
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok: failures+=1;push_error("REALISM_FAIL: "+label)
func run(host:SceneTree) -> int:
	tree=host
	DatabaseManager.load_all()
	w=WorldGenerator.generate(19031911,"padrao")
	_test_rosters()
	_test_budgets()
	_test_accounting()
	_test_faces()
	await _test_ui()
	metrics["checks"]=checks;metrics["failures"]=failures
	var path:=OS.get_environment("REALISM_REPORT")
	if path=="": path="user://realism-report.json"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(metrics,"  "));f.close()
	print("REALISM_METRICS ",JSON.stringify(metrics))
	if failures==0:print("REALISM_REGRESSION_OK")
	return 0 if failures==0 else 1
func _test_rosters() -> void:
	var data:Dictionary=w.stats[RealWorldData.KEY]
	check(data["players"].size()==52,"52 identifiable factual pilot players")
	var uids:={}
	for key:String in data["players"]:
		var p:=w.player(int(key));var e:Dictionary=data["players"][key]
		check(p!=null and p.display_name()==e["known"],"identity applied "+key)
		check(not uids.has(e["uid"]),"no duplicate factual identity")
		uids[e["uid"]]=true
		check(p.history.is_empty() and p.career_goals==0 and p.career_apps==0,"unknown real history not invented")
		check(p.height>=150 and p.height<=210,"height bounds")
		check(p.potential>=p.overall,"potential remains valid")
	var pal:=w.club_by_key("BRA_VPA");var bar:=w.club_by_key("ESP_BLG")
	check(pal.player_ids.size()==25 and bar.player_ids.size()==27,"exact two-club pilot roster counts")
	for e:Dictionary in RealWorldData.pack()["players"]:
		var found:=PlayerMods.find(w,w.club_by_key(e["club"]),e["known"])
		check(found!=null and found.height==int(e["height"]) and found.birth_year==int(e["birth"]) and found.shirt==int(e["shirt"]),"factual fields retained "+String(e["known"]))
	People.ensure(w)
	for key:String in ["BRA_VPA","ESP_BLG"]:
		var co:Dictionary=People.coach_of(w,w.club_by_key(key).id)
		check(co.has("real_source") and co["car"].size()==1 and co["pl"].is_empty(),"real coach no fictional past")
	var p:=w.player(pal.player_ids[0]);p.known_as="Edição do usuário"
	RealWorldData.apply_new_world(w)
	check(p.known_as=="Edição do usuário","new-world import is idempotent")
	p.known_as=String(data["players"][str(p.id)]["known"])
	metrics["pilot"]={"players":uids.size(),"clubs":2,"coaches":2,"official_license_obtained":false,"ratings_are_estimates":true}
func _test_budgets() -> void:
	var c:=w.club_by_key("BRA_VPA");var seller:=w.club_by_key("BRA_TIM")
	w.user_club_id=c.id;w.manager_name="Teste Contábil"
	c.balance=1000000000;seller.balance=1000000000
	w.stats.erase(BoardBudget.KEY)
	BoardBudget.open_year(w,c,50000000)
	BoardBudget.spend(w,c,7000000)
	BoardBudget.open_year(w,c,900000000)
	check(c.transfer_budget==43000000,"opening panels does not replenish annual authorization")
	check(BoardBudget.can_commit(w,c,43000001,1)!="","installments cannot bypass total authorization")
	var once:=BoardBudget.grant(w,c,100000,"Teste","same")
	check(once==100000 and BoardBudget.grant(w,c,100000,"Teste","same")==0,"one-off budget grants not farmable")
	var p:Player=w.squad(seller)[5]
	p.clauses={}
	var fee:=12000001;var deal:Dictionary={"inst":3,"bonus":1000000}
	var initial_budget:=c.transfer_budget
	var initial_cash:=c.balance;var seller_cash:=seller.balance
	TransferManager.complete_transfer(w,p,c,fee,p.wage,3)
	TransferManager.apply_deal(w,p,c,seller.id,fee,deal)
	check(initial_budget-c.transfer_budget==TransferManager.committed_cost(fee,deal),"full fee agent and bonus committed once")
	check(initial_cash-c.balance==TransferManager.upfront_cost(fee,deal),"only exact upfront cash charged")
	check(seller.balance-seller_cash==int(ceil(float(fee)/3)),"seller receives only first installment")
	var outstanding:=BoardBudget.pending(w,c)
	check(outstanding==fee-int(ceil(float(fee)/3)),"future installments sum exactly")
	var budget:=c.transfer_budget
	var other:=w.club_by_key("BRA_MOR")
	w.user_club_id=other.id
	var other_cash:=other.balance
	w.year+=1
	var due_cash:=c.balance
	TransferManager.pay_installments(w)
	check(other.balance==other_cash,"changing managed club does not transfer debts")
	check(c.balance<due_cash and c.transfer_budget==budget,"future installment changes cash not authorization twice")
	var after:=c.balance
	TransferManager.pay_installments(w)
	check(c.balance==after,"installment payment idempotent")
	w.year-=1;w.user_club_id=c.id
	BoardBudget.review(w,c);budget=c.transfer_budget
	BoardBudget.review(w,c);check(c.transfer_budget==budget,"midseason review not repeatable")
	w.year+=1;BoardBudget.open_year(w,c,1234567)
	check(c.transfer_budget==1234567,"unused prior budget not added to fresh authorization")
	w.year-=1
	metrics["budget"]={"full_commitment":TransferManager.committed_cost(fee,deal),"initial_cash_charge":TransferManager.upfront_cost(fee,deal),"initial_future_installments":outstanding}
func _test_accounting() -> void:
	var a:=w.club_by_key("BRA_VPA");var b:=w.club_by_key("BRA_TIM")
	var sa:=ClubAI.auto_sheet(w,a,"");var sb:=ClubAI.auto_sheet(w,b,"")
	var goal_total:=0;var assist_total:=0;var own_total:=0;var by_position:={}
	var last:Dictionary={}
	for i in 240:
		var res:=QuickMatch.play(w,a,b,sa.duplicate_sheet(),sb.duplicate_sheet(),{"competition":a.league_id,"attendance":30000},17000+i)
		var own:=[0,0]
		for g:Array in res["goals"]:
			if int(g[3])==2:own[int(g[1])]+=1
		for side in 2:
			var goals:=0;var assists:=0
			for ln:Array in res["lines"][side]:
				goals+=int(ln[QuickMatch.L_G]);assists+=int(ln[QuickMatch.L_A])
				var player:Player=ln[QuickMatch.L_P]
				var k:=Pos.code(player.position)
				by_position[k]=int(by_position.get(k,0))+int(ln[QuickMatch.L_G])
			check(goals+int(own[side])==int(res["hg"] if side==0 else res["ag"]),"player goals plus own goals equal scoreboard")
			check(assists<=goals,"at most one assist per eligible goal")
			goal_total+=goals;assist_total+=assists;own_total+=int(own[side])
		last=res
	var fixture:=Fixture.new()
	fixture.home=a.id;fixture.away=b.id;fixture.comp=a.league_id
	SeasonManager._apply_match(w,fixture,last,{}, {})
	var before:={}
	for p:Player in w.squad(a)+w.squad(b):before[p.id]=[p.stats.duplicate(),p.career_goals,p.career_assists,p.minutes_season]
	var manager_games:int=w.manager_stats.get("games",0)
	SeasonManager._apply_match(w,fixture,last,{}, {})
	for p:Player in w.squad(a)+w.squad(b):check(before[p.id]==[p.stats,p.career_goals,p.career_assists,p.minutes_season],"repeated result has no effect")
	check(manager_games==int(w.manager_stats.get("games",0)),"repeated result does not change coach record")
	var cached:Dictionary={"finished_report":{"day":-1,"user":{}}}
	check(SeasonManager.finish_matchday(w,cached)==cached["finished_report"],"completed matchday returns cached report")
	metrics["accounting_sample"]={"matches":240,"goals":goal_total,"assists":assist_total,"own_goals":own_total,"goals_by_position":by_position,"not_empirical_calibration":true}
func _test_faces() -> void:
	check(FaceGen.HAIR_STYLES.size()==PortraitView.STYLE_P.size() and FaceGen.HAIR_STYLES.size()==FaceGen.STYLE_TEX_W.size(),"all hair styles have render parameters")
	check(FaceGen.BEARDS.size()==FaceGen.BEARD_PARTS.size() and FaceGen.BEARDS.size()==FaceGen.BEARD_POP.size() and FaceGen.BEARDS.size()==FaceGen.BEARD_MIN_CAP.size(),"all beard arrays align")
	for hs in range(FaceGen.HAIR_STYLES.size()-8,FaceGen.HAIR_STYLES.size()):
		for bd in range(FaceGen.BEARDS.size()-4,FaceGen.BEARDS.size()):
			var f:=FaceGen.features(7721,1,27,{"hs":hs,"bd":bd})
			check(int(f["style"])==hs and int(f["beard"])==bd,"new appearance indices usable")
	metrics["appearance"]={"hair_styles":FaceGen.HAIR_STYLES.size(),"beards":FaceGen.BEARDS.size(),"new_hair":8,"new_beards":4}
func _test_ui() -> void:
	var num=load("res://scripts/ui/screens/numbers_screen.gd")
	for width in [480.0,640.0,920.0,1280.0,1800.0]:
		var n:int=num.grid_columns(width)
		check(n*138+(n-1)*10<=width,"shirt grid columns fit available width")
	var p:Player=w.squad(w.user_club())[0]
	check(num._react_once(w,p.id) and not num._react_once(w,p.id),"shirt reassignment cannot farm morale")
	var main=load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 4:await tree.process_frame
	GameManager.world=w
	for light in [false,true]:
		UIColors.set_light(light)
		UIColors.apply_context(w.user_club(),{})
		var theme:Theme=load("res://assets/theme/main_theme.tres")
		for pair:Array in [["normal","font_color"],["hover","font_hover_color"],["pressed","font_pressed_color"]]:
			var box:StyleBoxFlat=theme.get_stylebox(pair[0],"PrimaryButton")
			check(UIColors.contrast(box.bg_color,theme.get_color(pair[1],"PrimaryButton"))>=4.49,"primary action text contrast "+str(pair))
	for screen:String in ["numbers","club","player"]:
		UIManager.goto(screen,{"id":p.id} if screen=="player" else {})
		for i in 3:await tree.process_frame
		check(UIManager.current()!=null and UIManager.current().content().get_child_count()>0,"refined screen mounts "+screen)
	UIManager.goto("menu");GameManager.world=null
	main.queue_free()
	for i in 3:await tree.process_frame
