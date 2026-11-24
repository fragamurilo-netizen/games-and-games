extends BaseScreen
## Marcar uma luta numa noite da liga (presidente). Primeiro o lutador do corner vermelho
## (por categoria, do campeão para baixo), depois o adversário (sugestões perto no ranking, com a
## chance de as duas academias aceitarem) e por fim a oferta: cinturão, luta principal e bolsa.

var _div := ""
var _a := -1
var _all := false


func setup(p: Dictionary) -> void:
	super.setup(p)
	show_nav = false
	_a = int(p.get("a", -1))
	_div = String(p.get("div", ""))


func refresh() -> void:
	var w := world()
	var ev := w.event(int(params["event"]))
	var c := reset()
	if ev == null:
		c.add_child(UIKit.state_block("empty", "Evento não encontrado"))
		return
	screen_title = "Marcar luta"
	screen_subtitle = "%s · %s" % [ev.name, GameWorld.fight_date_text(ev.week)]
	UIManager.refresh_chrome()
	var fa := w.fighter(_a)
	if fa != null and _div == "":
		_div = fa.division
	if _div == "":
		_div = String((DataDB.divisions()[3] as Dictionary)["id"])
	if fa == null:
		_pick_first(w, ev, c)
	else:
		_pick_second(w, ev, fa, c)
	hide_footer()
	TutorialKit.tip(self, "book")


func _div_tabs(c: VBoxContainer) -> void:
	var items: Array = []
	for d: Dictionary in DataDB.divisions():
		items.append([String(d["id"]), Matchmaker.division_short(String(d["id"]))])
	c.add_child(UIKit.scroll_tabs(items, _div, func(k: String):
		_div = k
		_a = -1
		refresh()))


## Passo 1: quem entra no card (os da liga na categoria, o campeão primeiro).
func _pick_first(w: GameWorld, ev: FightEvent, c: VBoxContainer) -> void:
	_div_tabs(c)
	var champ_id := int(w.champions.get(_div, -1))
	var tb := Org.title_booked(w, _div)
	if tb != null:
		c.add_child(UIKit.colored("Já há luta pelo cinturão marcada nesta categoria (%s)." % w.event(tb.event_id).name, UIColors.GOLD, "Small", true))
	elif champ_id < 0:
		c.add_child(UIKit.colored("Cinturão vago: marque dois do top 10 valendo o título.", UIColors.GOLD, "Small", true))
	else:
		var it := Titles.interim_of(w, _div)
		var out := Titles.champion_out(w, _div)
		if it != null:
			c.add_child(UIKit.colored("%s é o campeão interino: a próxima disputa de cinturão é a unificação contra o campeão." % it.display_name(), UIColors.GOLD, "Small", true))
		elif out != "":
			c.add_child(UIKit.colored("%s. Dá para marcar uma disputa de cinturão interino entre dois dos oito primeiros." % (out.substr(0, 1).to_upper() + out.substr(1)), UIColors.GOLD, "Small", true))
	c.add_child(UIKit.label("Escolha o primeiro lutador.", "Muted"))
	for f: Fighter in Org.roster(w, _div):
		var why := _status(w, ev, f)
		var col := UIColors.RED if why != "" else Color(0, 0, 0, 0)
		var fid := f.id
		var row := FightKit.fighter_row(w, f, func():
			if why != "":
				UIManager.toast(why, UIColors.RED)
				return
			_a = fid
			_all = false
			refresh(), why if why != "" else "%s · %s" % [f.record_text(), _last(w, f)], col)
		if why != "":
			row.modulate.a = 0.6
		c.add_child(row)


## Passo 2: o adversário.
func _pick_second(w: GameWorld, ev: FightEvent, fa: Fighter, c: VBoxContainer) -> void:
	c.add_child(UIKit.section_header("Corner vermelho", "Trocar", func():
		_a = -1
		refresh()))
	c.add_child(FightKit.fighter_row(w, fa, func(): UIManager.push("fighter", {"id": fa.id}), "%s · %s" % [fa.record_text(), _last(w, fa)]))
	var sugg := Org.suggestions(w, ev, fa, 10)
	c.add_child(UIKit.section_header("Adversários sugeridos" if not _all else "Todos da categoria", "Ver todos" if not _all else "Só sugestões", func():
		_all = not _all
		refresh()))
	var lst: Array = sugg
	if _all:
		lst = Org.roster(w, fa.division).filter(func(o: Fighter) -> bool: return o.id != fa.id)
	if lst.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém disponível para essa data", "Quem tem luta marcada, está machucado ou descansando não entra. Tente outra noite."))
	for o: Fighter in lst:
		var why := Org.book_reason(w, ev, fa, o)
		var line := why
		var col := UIColors.RED
		if why == "":
			var title := Org.title_reason(w, fa, o) == "" and (w.rank_of(fa) == 0 or w.rank_of(o) == 0 or int(w.champions.get(fa.division, -1)) < 0)
			var p := _chance(w, ev, fa, o, title, 1.0)
			var hv := float(Hype.pair(w, fa, o, title, false, ev.nation)["value"])
			line = "%s · aceite %s · hype %d" % [o.record_text(), Signing.chance_label(p).to_lower(), int(round(hv))]
			col = Color(0, 0, 0, 0)
		var oid := o.id
		var row := FightKit.fighter_row(w, o, func():
			if why != "":
				UIManager.toast(why, UIColors.RED)
				return
			_offer_sheet(w, ev, fa, w.fighter(oid)), line, col)
		if why != "":
			row.modulate.a = 0.6
		c.add_child(row)


static func _chance(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter, title: bool, mult: float) -> float:
	return float(Org.acceptance(w, ev, fa, fb, title, mult)[0]) * float(Org.acceptance(w, ev, fb, fa, title, mult)[0])


func _status(w: GameWorld, ev: FightEvent, f: Fighter) -> String:
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada":
		var e2 := w.event(b.event_id)
		return "Luta marcada na %s" % (e2.name if e2 != null else "outra noite")
	if not f.injury.is_empty():
		return "Machucado (%s)" % String(f.injury.get("name", "lesão")).to_lower()
	if f.suspension > ev.week - w.week:
		return "Suspenso pelo médico"
	if not Matchmaker.ready_to_book(w, f, ev.week - w.week):
		return "Descansando até depois dessa data"
	return ""


func _last(w: GameWorld, f: Fighter) -> String:
	if f.history.is_empty():
		return "sem luta na liga ainda"
	var h: Dictionary = f.history.back()
	return "%s %s" % [{"V": "venceu", "D": "perdeu", "E": "empatou"}.get(String(h.get("res", "")), ""), w.weeks_from_now(int(h.get("week", w.week)))]


## A oferta: cinturão ou interino (quando pode), luta principal e a bolsa, com o hype que a
## luta traz para a noite, o lugar dela no card e a chance de aceite.
func _offer_sheet(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter) -> void:
	var can_title := Org.title_reason(w, fa, fb) == ""
	var can_interim := not can_title and Titles.interim_reason(w, fa, fb) == ""
	var state := {"title": can_title and (w.rank_of(fa) == 0 or w.rank_of(fb) == 0 or int(w.champions.get(fa.division, -1)) < 0),
		"interim": can_interim, "main": not Org.has_main(w, ev), "mult": 1.0}
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 560
	v.add_child(FightKit.faceoff(w, fa, fb, 84))
	var heat := UIKit.vbox(0)
	v.add_child(heat)
	var opts := UIKit.vbox(UITokens.S1)
	v.add_child(opts)
	var info := UIKit.vbox(4)
	v.add_child(info)
	var update := func() -> void:
		UIKit.clear(heat)
		UIKit.clear(info)
		var mult: float = state["mult"]
		var belt := bool(state["title"]) or bool(state["interim"])
		heat.add_child(EventKit.thermometer(Hype.pair(w, fa, fb, bool(state["title"]), bool(state["interim"]), ev.nation), "Hype da luta", "", false, 4))
		var slot := "principal" if belt or bool(state["main"]) else Card.slot_guess(w, ev, fa, fb, false)
		if slot == "principal" and not belt and not bool(state["main"]):
			slot = "co"
		info.add_child(UIKit.kv("Lugar no card", Card.slot_name(slot)))
		for f: Fighter in [fa, fb]:
			var p := Org.table_purse(w, f, bool(state["title"]))
			var k := mult * (Titles.PURSE_K if bool(state["interim"]) else 1.0)
			info.add_child(UIKit.kv("Bolsa de %s" % f.short_name(), "%s + %s" % [Fmt.money(snappedf(float(p["show"]) * k, 500.0)), Fmt.money(snappedf(float(p["win"]) * k, 500.0))]))
		var ch := _chance(w, ev, fa, fb, belt, mult)
		info.add_child(UIKit.kv("Chance de as equipes aceitarem", Signing.chance_label(ch), UIColors.GREEN if ch >= 0.5 else UIColors.ORANGE))
	if can_title:
		var unify := Titles.interim_of(w, fa.division) != null and int(w.champions.get(fa.division, -1)) >= 0
		var tb := CheckButton.new()
		tb.text = "Unificação do cinturão (5 rounds)" if unify else "Valendo o cinturão (5 rounds)"
		tb.button_pressed = bool(state["title"])
		tb.custom_minimum_size.y = UITokens.H_BUTTON_SM
		tb.toggled.connect(func(on: bool):
			state["title"] = on
			update.call())
		opts.add_child(tb)
	elif can_interim:
		var ib := CheckButton.new()
		ib.text = "Valendo o cinturão interino (5 rounds)"
		ib.button_pressed = true
		ib.custom_minimum_size.y = UITokens.H_BUTTON_SM
		ib.toggled.connect(func(on: bool):
			state["interim"] = on
			update.call())
		opts.add_child(ib)
		var out := Titles.champion_out(w, fa.division)
		opts.add_child(UIKit.label("%s. O vencedor fica com o interino e enfrenta o campeão na volta." % (out.substr(0, 1).to_upper() + out.substr(1)), "Small", true))
	var mb := CheckButton.new()
	mb.text = "Luta principal da noite"
	mb.button_pressed = bool(state["main"])
	mb.custom_minimum_size.y = UITokens.H_BUTTON_SM
	mb.toggled.connect(func(on: bool):
		state["main"] = on
		update.call())
	opts.add_child(mb)
	var items: Array = []
	for i in Org.PURSE_STEPS.size():
		items.append([str(i), Org.PURSE_NAMES[i]])
	opts.add_child(UIKit.label("Bolsa oferecida", "Caps"))
	opts.add_child(UIKit.segment(items, "0", func(k: String):
		state["mult"] = Org.PURSE_STEPS[int(k)]
		update.call()))
	update.call()
	var go := UIKit.button("Oferecer a luta", "PrimaryButton", func():
		var r := Org.offer_bout(w, ev, fa, fb, bool(state["title"]), bool(state["main"]), float(state["mult"]), bool(state["interim"]) and not bool(state["title"]))
		UIManager.close_modal()
		GameManager.save_now()
		if bool(r["ok"]):
			Sfx.play("sign", -4.0)
			UIManager.toast(String(r["text"]), UIColors.GREEN)
			UIManager.back()
		else:
			UIManager.toast(String(r["text"]), UIColors.RED)
			refresh())
	v.add_child(go)
	UIManager.show_modal(v, true)
