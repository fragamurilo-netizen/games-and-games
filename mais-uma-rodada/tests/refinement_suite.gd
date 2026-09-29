extends RefCounted
## Synthetic regression fixtures and samples; no real user save is read or overwritten.
var failures:=0
var checks:=0
var metrics:={}
var w:GameWorld
var tree:SceneTree
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("REFINEMENT_FAIL: "+message)
func run(host:SceneTree)->int:
	tree=host
	var base=load("res://tests/depth_suite.gd").new()
	var base_result:int=await base.run(host)
	check(base_result==0,"previous depth and selection features preserved")
	w=base.w
	metrics["depth"]=base.metrics
	_test_faces()
	_test_quality()
	_test_metrics()
	_test_budgets()
	_test_transfers()
	_test_scope()
	_test_academy_events()
	_test_save()
	await _test_ui()
	metrics["checks"]=checks
	metrics["failures"]=failures
	var path:=OS.get_environment("REFINEMENT_REPORT")
	if path=="":path="user://refinement-validation.json"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(metrics,"  "));f.close()
	print("REFINEMENT_METRICS ",JSON.stringify(metrics))
	if failures==0:print("REFINEMENT_REGRESSION_OK")
	return 0 if failures==0 else 1
func _test_faces()->void:
	var legacy=load("res://tests/legacy_face_gen.gd")
	check(FaceGen.HAIR_STYLES.size()==217,"six appended hair styles")
	check(FaceGen.BEARDS.size()==145,"four appended beards")
	check(FaceGen.HAIR_STYLES.size()==PortraitView.STYLE_P.size(),"hair renderer and catalog aligned")
	check(FaceGen.BEARDS.size()==FaceGen.BEARD_PARTS.size() and FaceGen.BEARDS.size()==FaceGen.BEARD_MIN_CAP.size() and FaceGen.BEARDS.size()==FaceGen.BEARD_POP.size(),"beard arrays aligned")
	for i in 211:check(FaceGen.HAIR_STYLES[i]==legacy.HAIR_STYLES[i],"legacy hair index unchanged")
	for i in 141:check(FaceGen.BEARDS[i]==legacy.BEARDS[i],"legacy beard index unchanged")
	for i in 64:
		var a:=FaceGen.features(12345+i,i%13,18+i%25,{})
		var b:Dictionary=legacy.features(12345+i,i%13,18+i%25,{})
		check(a==b,"existing procedural identity preserved "+str(i))
	for i in 6:
		var a:=FaceGen.features(9876,1,28,{"hs":211+i,"bd":141+i%4})
		check(a["style"]==211+i and a["beard"]==141+i%4,"new styles explicitly editable")
	metrics["faces"]={"hair_added":6,"beards_added":4,"legacy_identity_samples":64}
func _test_metrics()->void:
	var clubs:=w.clubs_in_league("BRA1")
	var goals:=0
	var assists:=0
	var shots:=0
	var xg:=0.0
	var draws:=0
	var by_pos:={}
	var tally:={}
	for i in 600:
		var a:Club=clubs[(i*7)%clubs.size()]
		var b:Club=clubs[((i*7)+1+i%19)%clubs.size()]
		if a.id==b.id:b=clubs[(clubs.find(b)+1)%clubs.size()]
		var sa:=ClubAI.auto_sheet(w,a,"")
		var sb:=ClubAI.auto_sheet(w,b,"")
		var res:Dictionary
		if i<100:
			var sim:=MatchSimulation.new()
			sim.setup(w,a,b,sa,sb,{"neutral":true,"competition":"F","attendance":0},90320+i,false)
			sim.run_to_end();res=sim.to_result()
		else:res=QuickMatch.play(w,a,b,sa,sb,{"neutral":false,"competition":"BRA1","attendance":0},90320+i)
		check(bool(res.get("stats_observed",false)),"both match modes expose observed production")
		goals+=int(res["hg"])+int(res["ag"])
		if res["hg"]==res["ag"]:draws+=1
		var fx:=Fixture.new();fx.home=a.id;fx.away=b.id;fx.comp="BRA1";fx.round=i;fx.slot=i
		var state:=w.rng.state
		var detailed:=MatchStats.build(w,fx,res)
		check(state==w.rng.state,"presentation statistics do not alter world RNG")
		for side in 2:
			var score:int=res["hg"] if side==0 else res["ag"]
			var own:=0;var pen:=0;var player_goals:=0;var side_assists:=0
			for ev in res["goals"]:
				if int(ev[1])!=side:continue
				if int(ev[3])==Fixture.GOAL_OWN:own+=1
				if int(ev[3])==Fixture.GOAL_PENALTY:pen+=1
			for ln in res["lines"][side]:
				var p:Player=ln[QuickMatch.L_P]
				var g:=int(ln[QuickMatch.L_G]);var ast:=int(ln[QuickMatch.L_A])
				player_goals+=g;side_assists+=ast
				if g>0:by_pos[str(p.position)]=int(by_pos.get(str(p.position),0))+g
				var v:Array=res["pstats"].get(p.id,[0,0,0,0.0,0,0.0,0.0,0])
				shots+=int(v[0]);xg+=float(v[3])
				check(int(v[0])>=int(v[1]) and int(v[1])>=g,"goals <= on-target <= shots")
				check(float(v[3])>=float(v[6]) and float(v[6])>=0.0,"penalty xG cannot exceed total xG")
				check(int(detailed[p.id][MatchStats.XG])==int(round(float(v[3])*100.0)),"xG uses pre-outcome chances")
				check(int(detailed[p.id][MatchStats.KP])==int(v[4]),"key passes exclude converted assists")
				if int(ln[QuickMatch.L_MINS])==0:check(g==0 and ast==0,"unused substitute earns no production")
			check(player_goals+own==score,"scorer tally reconciles with team including own goals")
			check(side_assists<=score-own-pen,"penalties and own goals cannot create assists")
			assists+=side_assists
		if i==0:
			PerformanceLedger.record(w,fx,res)
			var h:=hash(w.stats[PerformanceLedger.KEY])
			PerformanceLedger.record(w,fx,res)
			check(hash(w.stats[PerformanceLedger.KEY])==h,"ledger result idempotent")
			SeasonManager._apply_match(w,fx,res,{}, {})
			var saved:=hash([w.squad(a).map(func(p):return p.stats),w.squad(b).map(func(p):return p.stats),a.balance,b.balance])
			SeasonManager._apply_match(w,fx,res,{}, {})
			check(saved==hash([w.squad(a).map(func(p):return p.stats),w.squad(b).map(func(p):return p.stats),a.balance,b.balance]),"applied fixture cannot duplicate stats or cash")
	check(PerformanceLedger.per90(1,90)==1.0 and PerformanceLedger.per90(4,0)==0.0,"safe per90 denominator")
	metrics["production_sample"]={"matches":600,"native":100,"bulk":500,"goals":goals,"assists":assists,"shots":shots,"xg":xg,"goals_per_match":goals/600.0,"draw_rate":draws/600.0,"goals_by_position":by_pos,"note":"Technical mixed sample, not empirical real-football calibration"}
	print("REFINEMENT_PRODUCTION_DONE ",metrics["production_sample"])
func _test_budgets()->void:
	var c:=w.user_club()
	var old_difficulty:=w.difficulty
	var baseline:Dictionary={}
	for d in 3:
		w.difficulty=d
		var v:=FinanceManager.board_limits(w,c)
		if baseline.is_empty():baseline=v
		check(v==baseline,"board policy does not favor user difficulty")
	w.difficulty=old_difficulty
	FinanceManager.set_budgets(w,c)
	var before:=c.transfer_budget
	FinanceManager.commit_budget(w,c,mini(10000,before))
	var spent:=c.transfer_budget
	FinanceManager.set_budgets(w,c)
	check(c.transfer_budget<=spent,"reopening allocation cannot replenish spent budget")
	var cash:=c.balance
	c.add_ledger("patrocinio",9999)
	check(c.transfer_budget<=spent,"income is cash, not automatically manager allowance")
	FinanceManager.mid_season_review(w,c)
	var review:=c.transfer_budget
	FinanceManager.mid_season_review(w,c)
	check(c.transfer_budget==review,"midseason budget review cannot be farmed")
	var old_year:=w.year
	w.year+=1
	FinanceManager.set_budgets(w,c)
	check(c.transfer_budget==int(FinanceManager.board_limits(w,c)["transfer"]),"yearly authorization replaces old unused allowance")
	w.year=old_year
	var saved_budget:=c.transfer_budget
	c.transfer_budget=0
	var before_cash:=c.balance
	var first_grant:=FinanceManager.authorize_extra(w,c,1000000,"regression_grant")
	var repeat_grant:=FinanceManager.authorize_extra(w,c,1000000,"regression_grant")
	check(c.balance==before_cash,"board grants do not create club cash")
	check(repeat_grant==0 or first_grant==0,"board grant reason cannot be farmed")
	c.balance=-1
	check(FinanceManager.authorize_extra(w,c,1000000,"regression_insolvent")==0,"no budget gift in negative cash")
	c.balance=before_cash
	c.transfer_budget=saved_budget
	metrics["budget"]={"same_policy_all_difficulties":true,"no_income_auto_allowance":true,"yearly_reset":true}
func _test_transfers()->void:
	var clubs:=w.clubs_in_league("BRA1")
	var seller:Club=clubs[2];var buyer:Club=clubs[3];var creditor:Club=clubs[4]
	var p:Player=w.squad(seller)[7]
	p.clauses={"so":creditor.id,"pct":0.17}
	var fee:=1000001
	buyer.transfer_budget=fee*4;buyer.balance=fee*6;buyer.wage_budget=100000000
	var money:=buyer.balance+seller.balance+creditor.balance
	var cb:=buyer.balance;var sb:=seller.balance;var cr:=creditor.balance;var budget:=buyer.transfer_budget
	TransferManager.complete_transfer(w,p,buyer,fee,1000,3,{"inst":3})
	check(buyer.transfer_budget==budget-fee,"full purchase consumes authorization even when financed")
	check(buyer.balance+seller.balance+creditor.balance==money,"upfront payment has matching credits")
	check(TransferManager.pending_installments(w,buyer.id)==fee-(cb-buyer.balance),"future amount reconciles to signed fee")
	var old_user:=w.user_club_id;var year:=w.year
	w.user_club_id=clubs[6].id
	w.year+=1;TransferManager.pay_installments(w)
	var again:=buyer.balance+seller.balance+creditor.balance
	TransferManager.pay_installments(w)
	check(again==buyer.balance+seller.balance+creditor.balance,"installment payment idempotent")
	w.year+=1;TransferManager.pay_installments(w)
	check(cb-buyer.balance==fee and (seller.balance-sb)+(creditor.balance-cr)==fee,"all installments settle exact total and original debtor despite job change")
	check(TransferManager.pending_installments(w,buyer.id)==0,"paid obligations cleared")
	var terms:={"bonus":12345,"inst":3,"clause":3}
	TransferManager.apply_deal(w,p,buyer,seller.id,fee,terms)
	var once:=buyer.balance
	TransferManager.apply_deal(w,p,buyer,seller.id,fee,terms)
	check(buyer.balance==once,"terms callback does not double charge")
	w.year=year;w.user_club_id=old_user
	var candidate:Player=w.squad(seller)[8]
	var wage:=1000
	check(TransferManager._register_pre(w,candidate,buyer,wage,3,{"bonus":200}),"valid precontract reserves wage and pays signature bonus")
	check(TransferManager.pending_wages(w,buyer.id)==wage,"precontract wage commitment tracked")
	var once_bonus:=buyer.balance
	check(not TransferManager._register_pre(w,candidate,buyer,wage,3,{"bonus":200}) and buyer.balance==once_bonus,"duplicate precontract blocked")
	buyer.wage_budget=FinanceManager.wage_bill(w,buyer)+wage
	check(not TransferManager._wage_fits(w,buyer,w.squad(seller)[9],1),"future promised salaries restrict new contracts")
	metrics["transfers"]={"three_installments":true,"sell_on_conservation":true,"retains_original_debtor":true,"precontract_reservations":true}
func _test_scope()->void:
	var clubs:=w.clubs_in_league("BRA1")
	var old:Club=clubs[7];var next:Club=clubs[8]
	var p:Player=w.squad(old)[5]
	p.reset_season_stats();p.minutes_season=900
	p.stats[Player.S_APPS]=10;p.stats[Player.S_GOALS]=8;p.stats[Player.S_ASSISTS]=4;p.stats[Player.S_MINUTES]=900;p.stats[Player.S_RATING_SUM]=700
	TransferManager.complete_transfer(w,p,next,0,p.wage,2)
	p.stats[Player.S_APPS]+=2;p.stats[Player.S_GOALS]+=1;p.stats[Player.S_ASSISTS]+=2;p.stats[Player.S_MINUTES]+=180;p.minutes_season+=180;p.stats[Player.S_RATING_SUM]+=130
	var a:=TeamStatsScreen.table_rows(w,old,0).filter(func(r):return r["id"]==p.id)
	var b:=TeamStatsScreen.table_rows(w,next,0).filter(func(r):return r["id"]==p.id)
	check(a.size()==1 and b.size()==1,"departed players remain attributed to original club")
	if not a.is_empty() and not b.is_empty():
		check(a[0]["g"]==8 and b[0]["g"]==1 and a[0]["as"]==4 and b[0]["as"]==2,"club contribution not duplicated after transfer")
		check(a[0]["m"]==900 and b[0]["m"]==180,"minutes follow the same club scope")
func _test_academy_events()->void:
	YouthManager.ensure_academy(w)
	var p:Player=w.academy.values()[0]
	var attrs:=p.attrs.duplicate();var pot:=p.potential
	for option in AcademyPlan.OPTIONS:
		check(AcademyPlan.choose(w,p,option[0]),"reachable individual youth focus")
		check(p.attrs==attrs and p.potential==pot,"selecting a focus never creates attributes")
	AcademyPlan.choose(w,p,"recovery")
	p.condition=50
	w.season.day+=1
	AcademyPlan.weekly(w,p)
	var condition:=p.condition
	AcademyPlan.weekly(w,p)
	check(condition==p.condition,"same-day rest cannot be farmed")
	var youth:=w.academy.size()
	var buyer:Club=w.clubs_in_league("BRA1")[1]
	var budget:=buyer.transfer_budget;buyer.transfer_budget=0
	YouthManager.sell(w,p,buyer,100000)
	check(w.academy.size()==youth and w.academy.has(p.id),"academy sale respects purchaser budget")
	buyer.transfer_budget=budget
	var q:Player=w.squad(w.user_club())[4]
	q.condition=40;q.minutes_season=900;q.injury_weeks=0;q.train["ld"]=2
	var ev:=RefinementEvents.build(w,"ref_workload")
	check(not ev.is_empty(),"workload event has actual condition predicate")
	ev["id"]=91819
	var pre:=q.attrs.duplicate()
	EventManager.resolve(w,ev,0)
	var snapshot:=hash([w.stats.get("load_reviews_v1",{}),q.attrs])
	EventManager.resolve(w,ev,0)
	check(snapshot==hash([w.stats.get("load_reviews_v1",{}),q.attrs]),"event choice cannot apply twice")
	check(pre==q.attrs,"new event does not grant attributes")
func _test_save()->void:
	var restored:=GameWorld.from_dict(bytes_to_var(var_to_bytes(w.to_dict(false))))
	check(restored.rng.state==w.rng.state,"roundtrip keeps RNG state")
	check(restored.stats.get("performance_v1",{})==w.stats.get("performance_v1",{}),"production ledger survives save")
	check(restored.stats.get("board_budgets_v1",{})==w.stats.get("board_budgets_v1",{}),"board budgets survive save")
	check(restored.stats.get(AcademyPlan.KEY,{})==w.stats.get(AcademyPlan.KEY,{}),"academy plan survives save")
func _test_ui()->void:
	var gm:=tree.root.get_node("GameManager");gm.world=w
	var main:Node=load("res://scenes/main.tscn").instantiate()
	tree.root.add_child(main)
	for i in 4:await tree.process_frame
	var ui:=tree.root.get_node("UIManager")
	for size in [Vector2i(720,1280),Vector2i(1280,720),Vector2i(1100,1500),Vector2i(1500,1100)]:
		tree.root.size=size
		UILayout.force_tablet=size.x==1100 or size.y==1100
		main.call("_update_layout")
		for i in 4:await tree.process_frame
		for screen in ["numbers","club","academy","team_stats"]:
			var params:Dictionary={"tab":"manage"} if screen=="club" else ({"id":w.user_club_id} if screen=="team_stats" else {})
			ui.goto(screen,params)
			for i in 3:await tree.process_frame
			check(ui.current()!=null and ui.current().content().get_child_count()>0,"screen builds at "+str(size)+" "+screen)
	# Modals must fit after opening AND while rotating with a long form still open.
	var links_before:=tree.root.get_signal_connection_list("size_changed").size()
	for sheet in [false,true]:
		var col:=VBoxContainer.new()
		col.custom_minimum_size=Vector2(560,9000)
		var modal=ui.show_modal(col,sheet)
		for size in [Vector2i(720,1280),Vector2i(1280,720),Vector2i(1500,1100),Vector2i(720,1280)]:
			tree.root.size=size
			main.call("_update_layout")
			for i in 10:await tree.process_frame
			await tree.create_timer(0.3).timeout
			var viewport:=tree.root.get_visible_rect().size
			for node in modal.find_children("*","ModalLayout",true,false):
				var panel:PanelContainer=node.panel
				check(panel.get_global_rect().end.y<=viewport.y+1.0,"modal stays within bottom edge after rotation")
				check(panel.get_global_rect().position.y>=-1.0,"modal stays within top edge")
				check(node.body.get_v_scroll_bar().max_value>node.body.size.y,"long modal remains scrollable")
		ui.close_all_modals()
		for i in 4:await tree.process_frame
	check(tree.root.get_signal_connection_list("size_changed").size()==links_before,"modal resize connections released after closing")
	var ns=load("res://scripts/ui/screens/numbers_screen.gd")
	check(ns.grid_columns(600)==4 and ns.grid_columns(280)==2,"numbers grid follows available width")
	for is_light in [false,true]:
		UIColors.set_light(is_light)
		for color in [Color("#fef100"),Color("#001122"),Color("#ffffff"),Color("#cc1230")]:
			check(UIColors.contrast(color,UIColors.on_color(color))>=4.5,"accent chooses legible foreground")
	UILayout.force_tablet=false
	ui.goto("menu");gm.world=null
	main.queue_free()
	for i in 3:await tree.process_frame

func _test_quality()->void:
	for typ in MatchSimulation.BASE_XG.size():
		var previous:=0.0
		for i in 100:
			var x:=MatchSimulation.calibrated_xg(typ, i/100.0)
			check(x>=previous,"chance quality remains monotonic")
			check(x>=0.0 and x<=1.0,"valid pre-shot probability")
			previous=x
	check(is_equal_approx(MatchSimulation.calibrated_xg(MatchSimulation.CH_PENALTY,0.76),0.76),"penalties not globally reduced")
	var b:=MatchSimulation.BASE_XG[MatchSimulation.CH_THROUGH]
	check(MatchSimulation.calibrated_xg(MatchSimulation.CH_THROUGH,b*2.0)<b*2.0,"stacked tactical multipliers have diminishing returns")
