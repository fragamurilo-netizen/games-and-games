extends BaseScreen
## Início do presidente: a organização (caixa, reputação), a noite desta semana quando há, as
## próximas noites da liga, quem o jogador acompanha e o que aconteceu no mundo. O botão
## principal leva à noite de luta (se ela é nesta semana) ou fecha a semana.


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Início"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = "Semana de " + GameWorld.week_text(w.week)
	UIManager.refresh_chrome()
	var c := reset()
	var t := w.user_team()
	c.add_child(_identity(w, t))
	var night := Org.night_this_week(w)
	if night != null:
		c.add_child(_night_card(w, night))
	var ups := Org.upcoming_events(w).filter(func(e: FightEvent) -> bool: return e != night)
	if not ups.is_empty():
		c.add_child(UIKit.section_header("Próximas noites", "Ver todas", func(): UIManager.switch_area("events")))
		for ev: FightEvent in ups.slice(0, 2):
			var id := ev.id
			c.add_child(OrgKit.event_card(w, ev, func(): UIManager.push("org_event", {"id": id})))
	OrgKit.followed_section(w, c)
	c.add_child(UIKit.section_header("Notícias", "Resultados", func(): UIManager.push("results")))
	var shown := 0
	for i in range(w.news.size() - 1, -1, -1):
		var n: Dictionary = w.news[i]
		if w.week - int(n["week"]) > 6:
			break
		c.add_child(_news_row(w, n))
		shown += 1
		if shown >= 12:
			break
	if shown == 0:
		c.add_child(UIKit.label("Semana calma no mundo do MMA.", "Muted"))
	columnize(c, 1, 2, 1 + (1 if night != null else 0))
	var foot := footer()
	if night != null:
		var nid := night.id
		foot.add_child(UIKit.button("Ir para a noite de luta", "PrimaryButton", func(): UIManager.push("night", {"id": nid})))
	else:
		foot.add_child(UIKit.button("Avançar semana", "PrimaryButton", _advance))


func _identity(w: GameWorld, t: Team) -> Control:
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var h := UIKit.hbox(UITokens.S3)
	var badge := TeamBadge.new()
	badge.team = t
	badge.custom_minimum_size = Vector2(80, 80)
	h.add_child(badge)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(t.name, "Section")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	v.add_child(UIKit.label("Presidente · sede em %s" % DataDB.nation_name(t.nation), "Small"))
	var rep := UIKit.hbox(8)
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_value(t.reputation)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rep.add_child(st)
	rep.add_child(UIKit.label("Prestígio", "Caps"))
	v.add_child(rep)
	h.add_child(v)
	card.add_child(h)
	var stats := UIKit.hbox(0)
	var champs := 0
	for div: String in w.champions:
		if int(w.champions[div]) >= 0:
			champs += 1
	stats.add_child(UIKit.stat_tile(Fmt.money(t.balance), "Caixa", UIColors.RED if t.balance < 0 else Color(0, 0, 0, 0)))
	stats.add_child(UIKit.stat_tile(str(Org.upcoming_events(w).size()), "Noites marcadas"))
	stats.add_child(UIKit.stat_tile("%d/%d" % [champs, w.champions.size()], "Campeões"))
	card.add_child(stats)
	return UIKit.card_panel(card)


func _night_card(w: GameWorld, ev: FightEvent) -> Control:
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(UIKit.label("Noite de luta · " + ev.name, "Section"))
	var lst := Org.event_bouts(w, ev)
	var done := lst.filter(func(b: Bout) -> bool: return b.status == "feita").size()
	card.add_child(UIKit.label("%s · %s · %d de %d lutas feitas" % [GameWorld.fight_date_text(ev.week), ev.city, done, lst.size()], "Small"))
	if not lst.is_empty():
		var main: Bout = lst.back()
		card.add_child(FightKit.faceoff(w, w.fighter(main.a), w.fighter(main.b), 120))
		if main.title:
			card.add_child(UIKit.colored("Valendo o cinturão dos %s" % Matchmaker.division_name(main.division, true), UIColors.GOLD, "Small"))
	else:
		card.add_child(UIKit.colored("O card está vazio: a noite vai ser cancelada se ninguém lutar.", UIColors.RED, "Small", true))
	return UIKit.card_panel(card)


func _news_row(w: GameWorld, n: Dictionary) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var ids: Array = n.get("fighters", [])
	if not ids.is_empty() and w.fighter(int(ids[0])) != null:
		h.add_child(FightKit.portrait(w, w.fighter(int(ids[0])), 56))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind := String(n.get("kind", ""))
	var chapeu: String = {"cinturao": "Cinturão", "resultado": "Resultado", "organizacao": "Sua organização", "aposentadoria": "Aposentadoria"}.get(kind, "Notícia")
	var cap := UIKit.label("%s · %s" % [chapeu, w.weeks_from_now(int(n["week"]))], "Caps")
	if kind == "cinturao":
		cap.add_theme_color_override(&"font_color", UIColors.GOLD)
	elif kind == "organizacao":
		cap.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(cap)
	v.add_child(UIKit.label(String(n["text"]), "H3" if bool(n.get("important", false)) else "", true))
	h.add_child(v)
	var cb := Callable()
	if not ids.is_empty():
		var fid := int(ids[0])
		cb = func(): UIManager.push("fighter", {"id": fid})
	return UIKit.tap_row(h, cb)


func _advance() -> void:
	GameManager.advance_week()
	Sfx.play("tab", -4.0)
	refresh()
	scroll_to_top()
