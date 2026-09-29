extends RefCounted
## Paired contexts; no result is applied to the world. Not an empirical real-football fit.
func run(tree:SceneTree)->void:
	DatabaseManager.load_all()
	var w:=WorldGenerator.generate(19031911,"padrao")
	var report:Array=[]
	for league in ["ENG1","FRA1","BRA1","ESP1","ITA1","GER1"]:
		var clubs:=w.clubs_in_league(league)
		var row:={"league":league,"pairs":160,"native_goals":0,"bulk_goals":0,"native_xg":0.0,"bulk_xg":0.0,"native_draws":0,"bulk_draws":0,"native_shots":0,"bulk_shots":0}
		for i in 160:
			var a:Club=clubs[(i*7)%clubs.size()]
			var b:Club=clubs[(i*11+1)%clubs.size()]
			if a==b:b=clubs[(clubs.find(b)+1)%clubs.size()]
			var sa:=ClubAI.prepare_ai_sheet(w,a,b,true)
			var sb:=ClubAI.prepare_ai_sheet(w,b,a,false)
			var ctx:={"competition":league,"attendance":int(a.capacity*0.7),"derby":false,"importance":0.3}
			var sim:=MatchSimulation.new()
			sim.setup(w,a,b,sa,sb,ctx,99111+i,false)
			sim.run_to_end()
			var results:Array=[sim.to_result(),QuickMatch.play(w,a,b,sa,sb,ctx,99111+i)]
			for j in 2:
				var mode:String="native" if j==0 else "bulk"
				var res:Dictionary=results[j]
				row[mode+"_goals"]+=int(res["hg"])+int(res["ag"])
				if res["hg"]==res["ag"]:row[mode+"_draws"]+=1
				for stats:Array in res["pstats"].values():
					row[mode+"_xg"]+=float(stats[3])
					row[mode+"_shots"]+=int(stats[0])
		report.append(row)
		print("REFINEMENT_CALIBRATION ",JSON.stringify(row))
		await tree.process_frame
	var path:=OS.get_environment("CALIBRATION_REPORT")
	if path=="":path="user://paired-calibration.json"
	var f:=FileAccess.open(path,FileAccess.WRITE)
	if f!=null:f.store_string(JSON.stringify(report,"  "));f.close()
	print("REFINEMENT_CALIBRATION_OK")
	tree.quit()
