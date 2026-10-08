extends BaseScreen
## Perfil do lutador: retrato sob a luz do octógono, ficha (atributos em três blocos e físico),
## carreira e, se for da equipe, treino e contrato. Daqui sai o desafio e a contratação.

var _tab := "ficha"
var _f: Fighter


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "ficha"))


func refresh() -> void:
	var w := world()
	_f = w.fighter(int(params["id"]))
	var f := _f
	screen_title = f.display_name()
	screen_subtitle = Matchmaker.division_short(f.division) + " · " + w.rank_text(f)
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(_header(w, f))
	var tabs := [["ficha", "Ficha"], ["carreira", "Carreira"]]
	var mine := w.is_user_fighter(f)
	if mine:
		tabs.append(["treino", "Treino"])
		tabs.append(["contrato", "Contrato"])
	c.add_child(UIKit.tabs(tabs, _tab, func(k: String):
		_tab = k
		refresh()))
	match _tab:
		"ficha":
			_ficha(w, f, c)
		"carreira":
			_carreira(w, f, c)
		"treino":
			_treino(w, f, c)
		"contrato":
			_contrato(w, f, c)
	_actions(w, f)


func _header(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S2)
	var h := UIKit.hbox(UITokens.S3)
	h.add_child(FightKit.portrait(w, f, 150))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if f.nickname != "":
		v.add_child(UIKit.label("“%s”" % f.nickname, "Accent"))
	var nm := UIKit.label(f.display_name(), "Section", true)
	v.add_child(nm)
	var nat := UIKit.hbox(8)
	nat.add_child(UIKit.flag(f.nation, 34))
	nat.add_child(UIKit.label("%s · %d anos" % [DataDB.nation_name(f.nation), w.age_of(f)], "Small"))
	v.add_child(nat)
	v.add_child(UIKit.label(FightKit.record_detail(f), "H3"))
	var t := w.team(f.team_id)
	v.add_child(UIKit.label(t.name if t != null else "Sem equipe", "Small"))
	var rk := UIKit.hbox(12)
	var r := UIKit.label(w.rank_text(f) + " · " + Matchmaker.division_short(f.division), "Caps")
	if w.rank_of(f) == 0:
		r.add_theme_color_override(&"font_color", UIColors.GOLD)
	rk.add_child(r)
	rk.add_child(UIKit.spacer())
	rk.add_child(UIKit.label("Nível", "Caps"))
	rk.add_child(FightKit.level_label(f.level(), "Stat"))
	v.add_child(rk)
	h.add_child(v)
	card.add_child(h)
	var st := FightKit.status_text(w, f)
	var srow := UIKit.hbox(8)
	var sl := UIKit.colored(String(st[0]), st[1], "Small", true)
	srow.add_child(sl)
	var following := w.is_followed(f)
	var fb := UIKit.button("Seguindo" if following else "Seguir", "TextButton", func():
		w.toggle_follow(f)
		GameManager.save_now()
		UIManager.toast(("Você acompanha %s: a próxima luta e o último resultado aparecem no Início." % f.short_name()) if w.is_followed(f) else "Você deixou de acompanhar %s." % f.short_name())
		refresh(), "star")
	if following:
		fb.add_theme_color_override(&"font_color", UIColors.GOLD)
		fb.add_theme_color_override(&"icon_normal_color", UIColors.GOLD)
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(fb)
	card.add_child(srow)
	return UIKit.card_panel(card)


func _ficha(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var body := UIKit.card("Card", UITokens.S1)
	body.add_child(UIKit.label("Físico", "Section"))
	body.add_child(UIKit.kv("Estilo", f.style_label()))
	body.add_child(UIKit.kv("Arte de base", Styles.describe(f)))
	body.add_child(UIKit.kv("Altura · envergadura", "%s · %d cm" % [Fmt.height(f.height_cm), f.reach_cm]))
	body.add_child(UIKit.kv("Base", "Canhota" if f.southpaw else "Ortodoxa"))
	var limit := float(DataDB.division(f.division).get("limit_kg", 70.0))
	var cut := maxf(0.0, (f.natural_kg - limit) / f.natural_kg)
	body.add_child(UIKit.kv("Peso fora de luta", "%s (corte de %d%%)" % [Fmt.kg(f.natural_kg), int(round(cut * 100.0))], UIColors.ORANGE if cut > 0.11 else UIColors.TEXT))
	body.add_child(UIKit.kv("Condição física", "%d%%" % int(f.condition), UIColors.GREEN if f.condition >= 90.0 else (UIColors.ORANGE if f.condition >= 70.0 else UIColors.RED)))
	var pot := UIKit.hbox(8)
	pot.custom_minimum_size.y = 44
	var pl := UIKit.label("Potencial", "Muted")
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pot.add_child(pl)
	var team := w.user_team()
	var scout := team.staff_quality("olheiro") if team != null else 0.0
	if w.is_user_fighter(f) or scout > 0.0:
		var stv := StarsView.new()
		stv.star_size = 18
		# O olheiro erra mais quanto pior ele é (o erro é fixo por lutador, não muda a cada olhada).
		var err := 0.0 if w.is_user_fighter(f) else (100.0 - scout) / 25.0
		var est := f.potential + (float(abs(hash([f.id, "olheiro"])) % 100) / 50.0 - 1.0) * err * 2.0
		stv.stars = StarsView.from_value(est - err * 3.0)
		stv.upper_stars = StarsView.from_value(est + err * 3.0) if err > 0.0 else -1.0
		stv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pot.add_child(stv)
	else:
		pot.add_child(UIKit.label("Contrate um olheiro", "Small"))
	body.add_child(pot)
	var cards: Array = [UIKit.card_panel(body), _style_card(f)]
	cards.append_array(FightKit.attr_blocks(f))
	for x: Control in cards:
		c.add_child(x)
	columnize(c, 2, 2)


## Estilo de luta: de onde ele vem, as marcas da escola e as armas que mais usa.
func _style_card(f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Estilo de luta", "Section"))
	card.add_child(UIKit.label(String(Styles.base(f.base).get("desc", "")), "Small", true))
	if f.base2 != "" and f.base2 != f.base:
		card.add_child(UIKit.label("Completou o jogo com %s." % Styles.name(f.base2).to_lower(), "Small", true))
	for t: Array in Styles.trait_list(f):
		card.add_child(UIKit.kv(String(t[0]), String(t[1])))
	var p := Styles.profile(f)
	var fav := func(d: Dictionary, n: int, info: Callable) -> String:
		var ks := d.keys()
		ks.sort_custom(func(a: String, b: String) -> bool: return float(d[a]) > float(d[b]))
		var names: Array = []
		for k: String in ks.slice(0, n):
			names.append(String(info.call(k).get("name", k)))
		return ", ".join(names)
	card.add_child(UIKit.kv("Quedas", fav.call(p["td"], 2, Styles.takedown)))
	card.add_child(UIKit.kv("Finalizações", fav.call(p["subs"], 3, Styles.sub)))
	return UIKit.card_panel(card)


func _carreira(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var r := f.record
	var sum := UIKit.card("Card", UITokens.S1)
	sum.add_child(UIKit.label("Cartel profissional", "Section"))
	var g := UIKit.hbox(0)
	g.add_child(UIKit.stat_tile(str(int(r["w"])), "Vitórias", UIColors.GREEN))
	g.add_child(UIKit.stat_tile(str(int(r["l"])), "Derrotas", UIColors.RED))
	g.add_child(UIKit.stat_tile(str(int(r["d"])), "Empates"))
	sum.add_child(g)
	sum.add_child(UIKit.kv("Vitórias por nocaute", str(int(r["ko_w"]))))
	sum.add_child(UIKit.kv("Vitórias por finalização", str(int(r["sub_w"]))))
	sum.add_child(UIKit.kv("Vitórias por decisão", str(int(r["dec_w"]))))
	sum.add_child(UIKit.kv("Cartel amador", "%d-%d" % [int(f.amateur.get("w", 0)), int(f.amateur.get("l", 0))]))
	if f.titles_won > 0:
		sum.add_child(UIKit.kv("Cinturões", "%d (%d defesas)" % [f.titles_won, f.title_defenses], UIColors.GOLD))
	c.add_child(UIKit.card_panel(sum))
	c.add_child(UIKit.section_header("Lutas no jogo"))
	if f.history.is_empty():
		c.add_child(UIKit.label("O cartel acima vem de antes do início da carreira. As lutas a partir de agora aparecem aqui.", "Muted", true))
		return
	for i in range(f.history.size() - 1, -1, -1):
		var hst: Dictionary = f.history[i]
		var h := UIKit.hbox(UITokens.S2)
		var res := String(hst["res"])
		var rl := UIKit.label(res, "Section")
		rl.custom_minimum_size.x = 40
		rl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.result_color(res)))
		h.add_child(rl)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UIKit.label(("Cinturão · " if bool(hst.get("title", false)) else "") + "contra " + String(hst["opp_name"]), "H3")
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(t)
		var how := String(hst.get("detail", ""))
		if String(hst["method"]) != "DEC" and String(hst["method"]) != "EMP":
			how += ", %dº round" % int(hst.get("round", 1))
		var sub := UIKit.label("%s · %s · %s" % [how, String(hst.get("event", "")), GameWorld.fight_date_text(int(hst["week"]), true)], "Small")
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(sub)
		h.add_child(v)
		var oid := int(hst["opp"])
		c.add_child(UIKit.tap_row(h, func(): UIManager.push("fighter", {"id": oid})))


func _treino(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	c.add_child(UIKit.section_header("Foco do treino"))
	var items: Array = []
	for k: String in Development.FOCUS:
		var fo: Dictionary = Development.FOCUS[k]
		items.append([k, String(fo["name"]), String(fo["help"])])
	c.add_child(UIKit.option_grid(items, String(f.training.get("focus", "equilibrado")), func(k: String):
		f.training["focus"] = k
		refresh()))
	c.add_child(UIKit.section_header("Intensidade"))
	c.add_child(UIKit.segment([["0", "Leve"], ["1", "Normal"], ["2", "Pesado"]], str(int(f.training.get("intensity", 1))), func(k: String):
		f.training["intensity"] = int(k)
		refresh()))
	var txt: String = ["Evolui devagar, quase sem risco de lesão. Bom na semana antes da luta.", "O ritmo de sempre.", "Evolui mais rápido, mas a condição física cai e o risco de lesão sobe."][int(f.training.get("intensity", 1))]
	c.add_child(UIKit.label(txt, "Small", true))
	var t := w.user_team()
	var staff := UIKit.card("Card", UITokens.S1)
	staff.add_child(UIKit.label("Quem treina", "Section"))
	for role: String in ["striking", "wrestling", "jiujitsu", "fisico"]:
		var s := t.staff_of(role)
		staff.add_child(UIKit.kv(StaffMarket.role_name(role), String(s["name"]) + " (%d)" % int(s["quality"]) if not s.is_empty() else "ninguém", UIColors.TEXT if not s.is_empty() else UIColors.ORANGE))
	c.add_child(UIKit.card_panel(staff))
	var gap := f.potential - f.level()
	var age := w.age_of(f)
	var outlook := "Ainda tem bastante para crescer." if gap > 8 and age < 28 else ("Perto do auge: treino mantém mais do que melhora." if age >= 29 else "Cresce aos poucos.")
	if age > f.peak_age + 1:
		outlook = "Passou do auge: velocidade, fôlego e queixo começam a cair."
	c.add_child(UIKit.label(outlook, "Muted", true))


func _contrato(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Contrato", "Section"))
	var cut := float(f.contract.get("cut", 0.2))
	card.add_child(UIKit.kv("Fatia das bolsas para a equipe", "%d%%" % int(round(cut * 100.0))))
	var left := int(f.contract.get("fights", 0))
	card.add_child(UIKit.kv("Lutas restantes", str(maxi(0, left)), UIColors.RED if left <= 0 else UIColors.TEXT))
	c.add_child(UIKit.card_panel(card))
	if left <= 1:
		c.add_child(UIKit.label("Renove antes que acabe: com o contrato vencido, ele pode sair a qualquer semana.", "Small", true))
		c.add_child(UIKit.button("Renovar por 5 lutas (20%)", "GhostButton", func():
			var r := Signing.renew(w, f, 0.2, 5)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			if not bool(r["ok"]):
				UIManager.back()
			else:
				refresh()))
	c.add_child(UIKit.button("Dispensar", "DangerButton", func():
		UIManager.confirm("Dispensar %s?" % f.display_name(), "Ele sai da equipe na hora e uma luta marcada é cancelada.", "Dispensar", func():
			Signing.release(w, f)
			UIManager.back())))


func _actions(w: GameWorld, f: Fighter) -> void:
	var foot := footer()
	if w.is_president():
		_president_actions(w, f, foot)
		return
	if w.is_user_fighter(f):
		var offers := w.offers.filter(func(o: Dictionary) -> bool: return int(o["fighter"]) == f.id)
		if not offers.is_empty():
			foot.add_child(UIKit.button("Ver proposta (%d)" % offers.size(), "PrimaryButton", func(): UIManager.push("offer", {"id": int(offers[0]["id"])})))
		elif f.bout_id < 0 and f.is_pro():
			foot.add_child(UIKit.button("Desafiar alguém", "PrimaryButton", func(): UIManager.push("rankings", {"challenger": f.id, "div": f.division})))
		else:
			hide_footer()
		return
	if f.team_id < 0 and not f.retired:
		foot.add_child(UIKit.button("Fazer proposta de contrato", "PrimaryButton", func(): ContractSheet.open(w, f, func(): refresh())))
		return
	var mine := w.user_fighters().filter(func(m: Fighter) -> bool: return m.division == f.division)
	if not mine.is_empty() and not f.retired:
		foot.add_child(UIKit.button("Desafiar", "PrimaryButton", func(): UIManager.push("challenge", {"target": f.id})))
	else:
		hide_footer()



## Presidente: marcar luta para este lutador na próxima noite da liga em que ele pode lutar, ou
## ver o card em que ele já está.
func _president_actions(w: GameWorld, f: Fighter, foot: VBoxContainer) -> void:
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada":
		var ev := w.event(b.event_id)
		if ev != null and ev.tier == 2:
			foot.add_child(UIKit.button("Ver o card da %s" % ev.name, "GhostButton", func(): UIManager.push("org_event", {"id": ev.id})))
		else:
			foot.add_child(UIKit.button("Ver o card da %s" % (ev.name if ev != null else "noite"), "GhostButton", func(): UIManager.push("event", {"id": b.event_id})))
		return
	if not Org.eligible(w, f) or not f.injury.is_empty() or f.retired:
		hide_footer()
		return
	var target: FightEvent = null
	for ev: FightEvent in Org.upcoming_events(w):
		if ev.week - w.week >= 2 and Org.event_bouts(w, ev).size() < ev.slots and Matchmaker.ready_to_book(w, f, ev.week - w.week) and f.suspension <= ev.week - w.week:
			target = ev
			break
	if target == null:
		hide_footer()
		return
	var tid := target.id
	foot.add_child(UIKit.button("Marcar luta na %s" % target.name, "PrimaryButton", func(): UIManager.push("book", {"event": tid, "a": f.id})))
