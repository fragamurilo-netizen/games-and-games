extends SceneTree
## De onde vêm os reforços de cada país (calibração com o Transfermarkt): por nacionalidade do
## jogador (do país, sul-americano, europeu, outro) e por onde ele jogava (no país, fora). No fim,
## a fatia de estrangeiros e de europeus nos elencos da 1ª divisão.
## godot --headless --path . --script res://tools/transfer_flow_report.gd -- [--seasons=N] [--cal=ano|eu] [--nations=BRA,ARG,...]

const SA := ["BRA", "ARG", "URU", "COL", "CHI", "ECU", "PER", "PAR", "BOL", "VEN"]

var opt_cal := "ano"
var opt_seasons := 1
var opt_nations: Array = ["BRA", "ARG", "URU", "COL", "CHI", "MEX", "USA", "POR", "ESP", "ENG", "ITA", "KSA"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cal="):
			opt_cal = a.substr(6)
		elif a.begins_with("--seasons="):
			opt_seasons = int(a.substr(10))
		elif a.begins_with("--nations="):
			opt_nations = Array(a.substr(10).split(","))
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	w.user_club_id = w.clubs_in_league("BRA1")[0].id
	w.stats["cal"] = "ano" if opt_cal == "ano" else ""
	w.season = SeasonManager.build_season(w)
	SeasonManager.compute_goals(w)
	print("== elencos no começo ==")
	_stock(w)
	var t0 := Time.get_ticks_msec()
	var seasons := 0
	var guard := 0
	while seasons < opt_seasons:
		while not w.season.finished and guard < 400 * opt_seasons:
			SeasonManager.play_matchday_instant(w)
			guard += 1
		seasons += 1
		if seasons < opt_seasons:
			SeasonManager.end_season(w)
	print("%d temporada(s), %.1fs, transferências no log: %d" % [opt_seasons, (Time.get_ticks_msec() - t0) / 1000.0, w.transfer_log.size()])
	print("== reforços por país do comprador (só clubes da IA, compras e livres) ==")
	print("país  n     do país(dentro) repatriado  sul-amer.  europeu  outro | europeus: idade média, %% livres")
	for nat in opt_nations:
		var c := {"n": 0, "dom": 0, "rep": 0, "sa": 0, "eu": 0, "oth": 0, "eu_age": 0, "eu_free": 0}
		for t: Transfer in w.transfer_log:
			if t.kind == Transfer.KIND_RELEASE:
				continue
			var to := w.club(t.to_id)
			if to == null or to.nation != nat or w.is_user_club(to.id):
				continue
			var p: Player = w.players.get(t.player_id)
			if p == null:
				continue
			var from := w.club(t.from_id)
			c["n"] += 1
			var pn := p.nationality
			if pn == nat:
				if from != null and from.nation != nat:
					c["rep"] += 1
				else:
					c["dom"] += 1
			elif SA.has(pn):
				c["sa"] += 1
			elif _confed(pn) == "UEFA":
				c["eu"] += 1
				c["eu_age"] += t.age
				if from == null:
					c["eu_free"] += 1
			else:
				c["oth"] += 1
		var n := maxi(1, int(c["n"]))
		print("%s  %-5d %5.0f%%          %5.0f%%     %5.0f%%   %5.0f%%  %5.0f%% | %s" % [nat, c["n"], 100.0 * c["dom"] / n, 100.0 * c["rep"] / n,
			100.0 * c["sa"] / n, 100.0 * c["eu"] / n, 100.0 * c["oth"] / n,
			("%.1f anos, %.0f%% livres" % [float(c["eu_age"]) / c["eu"], 100.0 * c["eu_free"] / c["eu"]]) if int(c["eu"]) > 0 else "-"])
	print("== elencos no fim ==")
	_stock(w)
	quit()


## Fatia de estrangeiros (e de europeus) nos elencos da 1ª divisão de cada país.
func _stock(w: GameWorld) -> void:
	for nat in opt_nations:
		var tot := 0
		var fo := 0
		var eu := 0
		var sa := 0
		for c: Club in w.clubs:
			if c.nation != nat or c.tier != 1:
				continue
			for pid in c.player_ids:
				var p: Player = w.players.get(pid)
				if p == null:
					continue
				tot += 1
				if p.nationality != nat:
					fo += 1
					if _confed(p.nationality) == "UEFA":
						eu += 1
					elif SA.has(p.nationality):
						sa += 1
		if tot > 0:
			print("%s 1ª div: %d jogadores · estrangeiros %.0f%% · sul-americanos %.0f%% · europeus %.0f%%" % [nat, tot, 100.0 * fo / tot, 100.0 * sa / tot, 100.0 * eu / tot])


func _confed(nat: String) -> String:
	return String(DatabaseManager.nation(nat).get("confed", ""))
