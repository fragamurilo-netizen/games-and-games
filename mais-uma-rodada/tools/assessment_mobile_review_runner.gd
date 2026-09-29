extends "res://tools/career_mobile_review_runner.gd"

var tables_only := false

func _run() -> void:
	_check(OS.get_user_data_dir().contains("QA"), "isolated QA")
	DirAccess.make_dir_recursive_absolute(out_dir)
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await _frames()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED,"padrao")
	AppSettings.tutorial_done = true
	GameManager.start_career(w,w.clubs_in_league("FRA1")[0].id,"QA",GameWorld.DIFF_NORMAL,97)
	if tables_only:
		UIManager.close_all_modals()
		for dim in SIZES:
			await _resize(dim)
			for destination in ["squad","market"]:
				UIManager.goto(destination)
				await _shot(destination)
		GameManager.save_blocking()
		SaveManager.delete_slot(97)
		print("ASSESSMENT_TABLE_REVIEW failures=",failures)
		get_tree().quit(0 if failures == 0 else 1)
		return
	var p: Player = w.squad(w.user_club())[0]
	p.known_as = "Alexandre Maximiliano"
	var before := PlayerAssessment.report(w,p)
	var rng_before := w.rng.state
	var ca := p.overall
	var pa := p.potential
	p.overall = 1
	p.potential = 99 if pa < 99 else 30
	_check(PlayerAssessment.report(w,p) == before,"assessment ignores CA/PA")
	_check(w.rng.state == rng_before,"assessment does not consume world RNG")
	p.overall = ca
	p.potential = pa
	var attrs := p.attrs.duplicate()
	var strength := PlayerAssessment.score(w,p)
	for i in Attr.COUNT: p.attrs[i] = maxi(1,p.attrs[i]-20)
	_check(PlayerAssessment.score(w,p) < strength-10,"attributes determine assessment")
	p.attrs = attrs
	var foreign: Player = w.squad(w.clubs_in_league("BRA1")[0])[0]
	var unknown := PlayerAssessment.confidence(w,foreign)
	Scouting.state(w)["ids"][str(foreign.id)] = w.current_turn()
	_check(PlayerAssessment.confidence(w,foreign)>unknown,"scouting improves confidence")
	_check(PlayerAssessment.score(w,p,Pos.GK)>PlayerAssessment.score(w,p,Pos.ST),"assessment follows position")
	var saved := Player.from_dict(p.to_dict())
	_check(saved.potential == p.potential and saved.attrs == p.attrs,"hidden development data survives save")
	_check(NationalCoach.nation(w) == "","French club does not assign France job")
	NationalCoach.accept(w,"FRA")
	_check(NationalCoach.nation(w) == "","cannot take a national job without an offer")
	for dim in SIZES:
		await _resize(dim)
		for destination in ["hub","tactics","prematch"]:
			UIManager.goto(destination)
			await _shot(destination)
		main.top_bar.menu_btn.pressed.emit()
		await _shot("top-menu")
		UIManager.close_all_modals()
		UIManager.goto("club")
		await _frames()
		var tapped := false
		for n in UIManager.current().find_children("Tap","Button",true,false):
			if not n.is_visible_in_tree(): continue
			var panel: Control = n.get_parent().get_parent()
			_check(n.get_global_rect().is_equal_approx(panel.get_global_rect()),"full-row selection bounds")
			if not tapped and panel.theme_type_variation == "RowPanel":
				n.toggle_mode = true
				n.set_pressed_no_signal(true)
				tapped = true
		await _shot("club-selected")
		UIManager.goto("squad")
		await _shot("squad")
		for tab in ["geral","atributos","origem","carreira"]:
			UIManager.push("player",{"id":p.id,"tab":tab})
			await _frames()
			_check(UIManager.current().content().size.x <= get_viewport().get_visible_rect().size.x+1,"profile width")
			await _shot("player-"+tab)
			UIManager.back()
		UIManager.goto("market")
		await _shot("market")
		UIManager.goto("national",{"nation":"FRA"})
		await _shot("france-consultation")
		_check(NationalCoach.nation(w) == "","browsing France does not appoint coach")
		NationalCoach.state(w)["offers"] = [{"n":"FRA","y":w.year}]
		UIManager.current().refresh()
		await _frames()
		var yes := _button(UIManager.current(),"Assumir seleção")
		_check(yes != null,"offer accept action")
		yes.pressed.emit()
		await _frames()
		_check(NationalCoach.nation(w) == "","offer requires explicit confirmation")
		await _shot("national-job-confirmation")
		UIManager.close_all_modals()
		NationalCoach.state(w)["offers"] = []
	for screen in ["academy","training","contracts","compare","prematch"]:
		UIManager.goto(screen,{"a":p.id})
		await _shot("extra-"+screen)
	GameManager.begin_match()
	UIManager.replace("match")
	await _frames()
	UIManager.current().set("_paused",true)
	UIManager.close_all_modals()
	for dim in SIZES:
		await _resize(dim)
		await _shot("match")
	UIManager.current().set_process(false)
	GameManager.save_blocking()
	SaveManager.delete_slot(97)
	print("ASSESSMENT_MOBILE_REVIEW failures=",failures)
	get_tree().quit(0 if failures == 0 else 1)
