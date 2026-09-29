extends Node
var opt_reference := ""

func _ready() -> void:
	if opt_reference == "":
		push_error("Pass --reference=path to pre-change quick_match.gd")
		get_tree().quit(1)
		return
	var legacy = load(opt_reference)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED,"padrao")
	var old_us := 0
	var new_us := 0
	var reds := 0
	var extra := 0
	var injured := 0
	for i in 600:
		var h: Club = w.clubs[(i*7)%w.clubs.size()]
		var a: Club = w.clubs[(i*7+1)%w.clubs.size()]
		var hs := ClubAI.prepare_ai_sheet(w,h,a,true)
		var as_ := ClubAI.prepare_ai_sheet(w,a,h,false)
		var ctx := {"ko": i%2 == 0,"agg":[0,0],"neutral":i%3 == 0}
		var t0 := Time.get_ticks_usec()
		var before: Dictionary = legacy.play(w,h,a,hs,as_,ctx,5700+i)
		old_us += Time.get_ticks_usec()-t0
		t0 = Time.get_ticks_usec()
		var after := QuickMatch.play(w,h,a,hs,as_,ctx,5700+i)
		new_us += Time.get_ticks_usec()-t0
		if before != after:
			push_error("Engine result mismatch at seed "+str(5700+i))
			get_tree().quit(1)
			return
		reds += int(after["rc"][0])+int(after["rc"][1])
		if after["et"]: extra += 1
		for side in after["lines"]:
			for line in side:
				if int(line[QuickMatch.L_INJ]) > 0: injured += 1
	print("QUICK_PARITY matches=600 exact=true red_cards=",reds," extra_time=",extra," injuries=",injured," before_us=",old_us," after_us=",new_us)
	get_tree().quit()
