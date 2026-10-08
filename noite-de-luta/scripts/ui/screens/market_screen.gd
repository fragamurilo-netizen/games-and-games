extends BaseScreen
## Mercado: lutadores sem equipe (amadores, profissionais e veteranos, como no LEATHER) e
## candidatos a staff.

var _tab := "lutadores"
var _stage := "amador"
var _div := ""


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Mercado"


func refresh() -> void:
	var w := world()
	var c := reset()
	c.add_child(UIKit.tabs([["lutadores", "Lutadores"], ["staff", "Staff"]], _tab, func(k: String):
		_tab = k
		refresh()))
	if _tab == "staff":
		_staff(w, c)
		return
	c.add_child(UIKit.segment([["amador", "Amadores"], ["profissional", "Profissionais"], ["veterano", "Veteranos"]], _stage, func(k: String):
		_stage = k
		refresh()))
	var items: Array = [["", "Todas"]]
	for d: Dictionary in DataDB.divisions():
		items.append([String(d["id"]), Matchmaker.division_short(String(d["id"]))])
	c.add_child(UIKit.scroll_tabs(items, _div, func(k: String):
		_div = k
		refresh()))
	var y := w.year()
	var m := w.month()
	var lst: Array = w.fighters.values().filter(func(f: Fighter) -> bool:
		return not f.retired and f.team_id < 0 and f.stage(y, m) == _stage and (_div == "" or f.division == _div))
	lst.sort_custom(func(a: Fighter, b: Fighter) -> bool: return a.level() > b.level())
	screen_subtitle = Fmt.plural(lst.size(), "lutador livre", "lutadores livres")
	UIManager.refresh_chrome()
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém livre aqui agora", "Contratos acabam e novos amadores aparecem todo mês."))
		return
	var hint := {"amador": "Baratos e dispostos. Alguns viram campeões; quase todos precisam de anos.", "profissional": "Já lutam e rendem bolsas, mas olham a reputação da academia.", "veterano": "Experiência e cartel, pouco tempo de carreira pela frente."}
	c.add_child(UIKit.label(String(hint[_stage]), "Small", true))
	for i in mini(lst.size(), 80):
		var f: Fighter = lst[i]
		var p := Signing.chance(w, f, 0.2, 5, 0.0)
		var line := "%s · %d anos · %s · aceitaria: %s" % [Matchmaker.division_short(f.division), w.age_of(f), FightKit.record_detail(f).split(" · ")[0], Signing.chance_label(p).to_lower()]
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": f.id}), line, UIColors.GREEN if p >= 0.5 else Color(0, 0, 0, 0)))


func _staff(w: GameWorld, c: VBoxContainer) -> void:
	screen_subtitle = "Candidatos deste mês"
	UIManager.refresh_chrome()
	c.add_child(UIKit.label("Mais velho e mais rodado custa mais e rende mais. Os candidatos mudam todo mês.", "Small", true))
	var t := w.user_team()
	for role: String in StaffMarket.ORDER:
		c.add_child(UIKit.section_header(StaffMarket.role_name(role)))
		c.add_child(UIKit.label(String(StaffMarket.ROLES[role]["help"]), "Small", true))
		var cur := t.staff_of(role)
		if not cur.is_empty():
			c.add_child(UIKit.colored("Na academia: %s (%d)" % [String(cur["name"]), int(cur["quality"])], UIColors.ACCENT, "Small"))
		for cand: Dictionary in w.staff_market:
			if String(cand["role"]) == role:
				c.add_child(StaffRow.make(w, cand, func(): _hire(w, cand)))


func _hire(w: GameWorld, cand: Dictionary) -> void:
	UIManager.confirm("Contratar %s?" % String(cand["name"]), "%s, %d anos. Salário de %s por semana." % [StaffMarket.role_name(String(cand["role"])), int(cand["age"]), Fmt.money(float(cand["wage"]))], "Contratar", func():
		var err := StaffMarket.hire(w, cand)
		if err != "":
			UIManager.toast(err, UIColors.RED)
		else:
			Sfx.play("sign", -4.0)
			UIManager.toast("%s contratado." % String(cand["name"]), UIColors.GREEN)
			GameManager.save_now()
		UIManager.refresh_chrome()
		refresh())
