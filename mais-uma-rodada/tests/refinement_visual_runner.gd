extends Node
var out_dir:= "/mnt/data/refine_shots"
var errors:=0
var manifest:Array=[]
func _ready()->void:
	_run.call_deferred()
func _frames(n:int)->void:
	for i in n:await get_tree().process_frame
func _capture(label:String)->void:
	await _frames(12)
	await RenderingServer.frame_post_draw
	var image:=get_viewport().get_texture().get_image()
	if image==null or image.is_empty():
		errors+=1;return
	image.save_png(out_dir.path_join(label+".png"))
	manifest.append({"name":label,"pixels":[image.get_width(),image.get_height()],"viewport":[UILayout.viewport.x,UILayout.viewport.y]})
	print("REFINEMENT_SCREENSHOT ",label," ",image.get_size())
func _run()->void:
	if OS.get_environment("REFINEMENT_SHOTS")!="":out_dir=OS.get_environment("REFINEMENT_SHOTS")
	DirAccess.make_dir_recursive_absolute(out_dir)
	I18n.apply("pt")
	OS.low_processor_usage_mode=false
	Engine.max_fps=30
	AppSettings.reduce_motion=true
	AppSettings.theme_mode=AppSettings.THEME_DARK
	AppSettings.tutorial_done=true
	var w:=WorldGenerator.generate(19031911,"padrao")
	w.user_club_id=w.clubs_in_league("BRA1")[0].id
	w.manager_name="Teste de interface"
	w.manager_stats["games"]=600
	AppSettings.language="pt"
	I18n.apply("pt")
	GameManager.world=w
	YouthManager.ensure_academy(w)
	FinanceManager.set_budgets(w,w.user_club())
	# A few actual simulated fixtures populate the production panel; never fake its numbers.
	var count:=0
	for round_fixtures in w.league("BRA1").rounds:
		for fixture:Fixture in round_fixtures:
			if count>=3 or (fixture.home!=w.user_club_id and fixture.away!=w.user_club_id):continue
			var a:=w.club(fixture.home);var b:=w.club(fixture.away)
			var sa:=ClubAI.auto_sheet(w,a,"");var sb:=ClubAI.auto_sheet(w,b,"")
			var result:=QuickMatch.play(w,a,b,sa,sb,{"competition":"BRA1","attendance":0},87600+count)
			SeasonManager._apply_match(w,fixture,result,{}, {})
			for p:Player in w.squad(w.user_club()):p.condition=95;p.injury_weeks=0;p.suspension=0
			count+=1
	var main:Node=load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames(8)
	for config in [["phone",720,1280,false],["landscape",1280,720,false],["tablet",1500,1100,true]]:
		UILayout.force_tablet=bool(config[3])
		DisplayServer.window_set_size(Vector2i(config[1],config[2]))
		get_tree().root.size=Vector2i(config[1],config[2])
		main.call("_update_layout")
		await _frames(8)
		for route in ["numbers","club","team_stats"]:
			UIManager.goto(route,{"tab":"manage"} if route=="club" else {"id":w.user_club_id} if route=="team_stats" else {})
			await _capture(String(config[0])+"_"+route)
		if config[0]=="phone":
			UIManager.goto("academy")
			await _capture("phone_academy")
			var p:Player=w.academy.values()[0]
			UIManager.show_modal(AcademyPlan.controls(w,p),true)
			await _capture("phone_academy_plan")
			UIManager.close_all_modals()
			Negotiation.open(w,w.squad(w.user_club())[5],"renew",func():pass)
			await _capture("phone_contract")
			UIManager.close_all_modals()
		if config[0]=="landscape":
			Negotiation.open(w,w.squad(w.user_club())[5],"renew",func():pass)
			await _capture("landscape_contract")
			for scroll:ScrollContainer in UIManager._modals.back().find_children("*","ScrollContainer",true,false):
				scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
			await _capture("landscape_contract_bottom")
			UIManager.close_all_modals()
			UIManager.goto("club",{"tab":"manage"})
			AppSettings.theme_mode=AppSettings.THEME_LIGHT
			UIManager.apply_look()
			await _capture("landscape_club_light")
			AppSettings.theme_mode=AppSettings.THEME_DARK
			UIManager.apply_look()
	# Capture added styles with the actual drawing component, not imagined portraits.
	UIManager.goto("numbers")
	var preview:=Control.new()
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg:=ColorRect.new();bg.color=UIColors.BG;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);preview.add_child(bg)
	var row:=GridContainer.new();row.columns=3;row.position=Vector2(36,40);row.add_theme_constant_override("h_separation",35);row.add_theme_constant_override("v_separation",16);preview.add_child(row)
	for i in 6:
		var col:=VBoxContainer.new();row.add_child(col)
		var face:=PortraitView.new();face.custom_minimum_size=Vector2(400,400);face.face_seed=12345;face.age=28;face.eth=1
		face.look={"hs":211+i,"bd":141+i%4};col.add_child(face)
		col.add_child(UIKit.label(FaceGen.HAIR_STYLES[211+i],"H3",true))
		col.add_child(UIKit.label(FaceGen.BEARDS[141+i%4],"Small",true))
	main.add_child(preview)
	await _capture("new_hair_beards")
	preview.queue_free();await _frames(4)
	var f:=FileAccess.open(out_dir.path_join("manifest.json"),FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(manifest,"  "));f.close()
	print("REFINEMENT_VISUAL_OK" if errors==0 else "REFINEMENT_VISUAL_FAILED")
	get_tree().quit(errors)
