extends BaseScreen
## Rankings por categoria: o campeão em destaque e a fila do primeiro ao último. Os lutadores da
## academia aparecem marcados. Aberta com `challenger`, vira a escolha de quem desafiar.

var _div := "M70"
var _sex := "m"
var _shown := 50


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Rankings"
	if p.has("div"):
		_div = String(p["div"])
	elif GameManager.world != null:
		var mine := GameManager.world.user_fighters()
		if not mine.is_empty():
			_div = (mine[0] as Fighter).division
	_sex = String(DataDB.division(_div).get("sex", "m"))


func refresh() -> void:
	var w := world()
	var challenger := w.fighter(int(params.get("challenger", -1)))
	screen_subtitle = ("Escolha quem %s vai desafiar" % challenger.short_name()) if challenger != null else Matchmaker.division_title(_div)
	UIManager.refresh_chrome()
	var c := reset()
	if challenger == null:
		c.add_child(UIKit.segment([["m", "Masculino"], ["f", "Feminino"]], _sex, func(k: String):
			_sex = k
			for d: Dictionary in DataDB.divisions():
				if String(d["sex"]) == k:
					_div = String(d["id"])
					break
			refresh()))
		var items: Array = []
		for d: Dictionary in DataDB.divisions():
			if String(d["sex"]) == _sex:
				items.append([String(d["id"]), String(d["name"])])
		c.add_child(UIKit.scroll_tabs(items, _div, func(k: String):
			_div = k
			_shown = 50
			refresh()))
	var limit := float(DataDB.division(_div).get("limit_kg", 0.0))
	c.add_child(UIKit.label("Limite da pesagem: %s · %d no ranking · os %d primeiros lutam na Liga Global" % [Fmt.kg(limit), (w.rankings.get(_div, []) as Array).size(), Rankings.lgc_size(_div)], "Small", true))
	var champ := w.fighter(int(w.champions.get(_div, -1)))
	if champ != null:
		var card := UIKit.vbox(UITokens.S2)
		var h := UIKit.hbox(UITokens.S3)
		h.add_child(FightKit.portrait(w, champ, 120))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UIKit.colored("Campeão", UIColors.GOLD, "Caps"))
		v.add_child(UIKit.label(champ.display_name(), "Section", true))
		var fl := UIKit.hbox(8)
		fl.add_child(UIKit.flag(champ.nation, 30))
		fl.add_child(UIKit.label(FightKit.record_detail(champ), "Small"))
		v.add_child(fl)
		v.add_child(UIKit.label("%d defesas · %s" % [champ.title_defenses, w.team(champ.team_id).name if w.team(champ.team_id) != null else "sem equipe"], "Small"))
		h.add_child(v)
		card.add_child(h)
		c.add_child(UIKit.tap_row(card, func(): _open(w, champ, challenger), "CardHighlight"))
	else:
		c.add_child(UIKit.state_block("empty", "Cinturão vago", "Os dois primeiros do ranking disputam na próxima noite da Liga Global."))
	var lst: Array = w.rankings.get(_div, [])
	for i in mini(_shown, lst.size()):
		var f := w.fighter(int(lst[i]))
		var mine := w.is_user_fighter(f)
		var line := "%s · %s" % [f.record_text(), w.team(f.team_id).short if w.team(f.team_id) != null else "sem equipe"]
		var col := UIColors.ACCENT if mine else Color(0, 0, 0, 0)
		if challenger != null and not mine:
			var why := Matchmaker.challenge_block_reason(w, challenger, f)
			if why == "":
				line = "Pode desafiar · " + line
				col = UIColors.GREEN
		c.add_child(FightKit.fighter_row(w, f, func(): _open(w, f, challenger), line, col, "#%d" % (i + 1)))
	if _shown < lst.size():
		c.add_child(UIKit.button("Mostrar mais", "TextButton", func():
			_shown += 50
			refresh()))


func _open(w: GameWorld, f: Fighter, challenger: Fighter) -> void:
	if challenger != null and not w.is_user_fighter(f):
		UIManager.push("challenge", {"mine": challenger.id, "target": f.id})
	else:
		UIManager.push("fighter", {"id": f.id})
