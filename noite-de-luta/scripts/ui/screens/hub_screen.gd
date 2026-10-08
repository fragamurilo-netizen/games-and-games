extends BaseScreen
## Início: a semana da academia. A noite de luta (quando há), as próximas lutas, as propostas
## que chegaram e o que aconteceu no mundo. O botão principal fecha a semana.


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
	var pending := Career.pending_user_bouts(w)
	for b: Bout in pending:
		c.add_child(_fight_night(w, b))
	var mine := w.user_fighters()
	if mine.is_empty():
		c.add_child(UIKit.state_block("empty", "Sua academia ainda não tem lutadores", "Comece pelo Mercado: amadores custam pouco e aceitam fácil. Profissionais rendem bolsas maiores, mas querem uma academia com nome.", "Ir ao Mercado", func(): UIManager.switch_area("market")))
	# Propostas
	if not w.offers.is_empty():
		c.add_child(UIKit.section_header("Propostas (%d)" % w.offers.size()))
		for o: Dictionary in w.offers:
			c.add_child(_offer_row(w, o))
	# Próximas lutas
	var booked: Array = []
	for f: Fighter in mine:
		var b := w.bout(f.bout_id)
		if b != null and b.status == "marcada" and not pending.has(b):
			booked.append([b, f])
	booked.sort_custom(func(x: Array, y: Array) -> bool: return (x[0] as Bout).week < (y[0] as Bout).week)
	if not booked.is_empty():
		c.add_child(UIKit.section_header("Próximas lutas"))
		for it: Array in booked:
			var b: Bout = it[0]
			var f: Fighter = it[1]
			var o := w.fighter(b.other(f.id))
			var ev := w.event(b.event_id)
			c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("event", {"id": b.event_id}),
				"contra %s · %s, %s" % [o.short_name(), ev.name, w.weeks_from_now(b.week)], UIColors.ACCENT if b.title else Color(0, 0, 0, 0), "Cinturão" if b.title else ""))
	# Equipe sem luta: lembrete do que dá para fazer.
	var idle := mine.filter(func(f: Fighter) -> bool: return f.bout_id < 0 and f.available() and Matchmaker.ready_to_book(w, f, 0))
	if not idle.is_empty() and w.offers.is_empty():
		c.add_child(UIKit.state_block("empty", "%s sem luta marcada" % Fmt.plural(idle.size(), "lutador", "lutadores"), "Propostas chegam com o tempo, mais rápido quanto maior a reputação da academia. Ou desafie alguém pelo Ranking.", "Ver rankings", func(): UIManager.switch_area("rankings")))
	OrgKit.followed_section(w, c)
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("belt", "Cinturões", "Os campeões e a linhagem de cada categoria", func(): UIManager.push("titles")),
		UIKit.menu_row("list", "Resultados da semana", "Todas as noites, da Liga Global ao regional", func(): UIManager.push("results")),
	]))
	# Notícias
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
	columnize(c, 1, 2, 1 + pending.size())
	var foot := footer()
	if pending.is_empty():
		foot.add_child(UIKit.button("Avançar semana", "PrimaryButton", _advance))
	else:
		var b2 := UIKit.button("Lute antes de avançar", "PrimaryButton", func(): UIManager.push("fight_plan", {"bout": (pending[0] as Bout).id}))
		foot.add_child(b2)


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
	v.add_child(UIKit.label("%s · %s" % [t.city, DataDB.nation_name(t.nation)], "Small"))
	var rep := UIKit.hbox(8)
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_value(t.reputation)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rep.add_child(st)
	rep.add_child(UIKit.label("Reputação", "Caps"))
	v.add_child(rep)
	h.add_child(v)
	card.add_child(h)
	var stats := UIKit.hbox(0)
	stats.add_child(UIKit.stat_tile(str(w.user_fighters().size()), "Lutadores"))
	stats.add_child(UIKit.stat_tile(Fmt.money(t.balance), "Caixa", UIColors.RED if t.balance < 0 else Color(0, 0, 0, 0)))
	stats.add_child(UIKit.stat_tile(Fmt.money(-(Career.RENT + Career.PER_FIGHTER * w.user_fighters().size() + t.weekly_wages())), "Por semana"))
	card.add_child(stats)
	return UIKit.card_panel(card)


func _fight_night(w: GameWorld, b: Bout) -> Control:
	var ev := w.event(b.event_id)
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Noite de luta · " + ev.name, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	card.add_child(head)
	card.add_child(UIKit.label("%s · %s%s" % [GameWorld.fight_date_text(b.week), ev.city, " · valendo o cinturão" if b.title else ""], "Small"))
	card.add_child(FightKit.faceoff(w, w.fighter(b.a), w.fighter(b.b), 120))
	var row := UIKit.hbox(UITokens.S2)
	var go := UIKit.button("Plano de luta", "PrimaryButton", func(): UIManager.push("fight_plan", {"bout": b.id}))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	card.add_child(row)
	return UIKit.card_panel(card)


func _offer_row(w: GameWorld, o: Dictionary) -> Control:
	var f := w.fighter(int(o["fighter"]))
	var opp := w.fighter(int(o["opp"]))
	var ev := w.event(int(o["event"]))
	var txt := "%s × %s (%s)" % [f.short_name(), opp.short_name(), w.rank_text(opp)]
	var line := "%s · %s · bolsa %s + %s" % [ev.name if ev != null else "", w.weeks_from_now(int(o["week"])), Fmt.money(float(o["show"])), Fmt.money(float(o["win"]))]
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(FightKit.portrait(w, f, 56))
	h.add_child(FightKit.portrait(w, opp, 56))
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var a := UIKit.label(txt, "H3")
	a.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(a)
	var b := UIKit.label(line, "Small")
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(b)
	h.add_child(v)
	var exp := UIKit.label("vence em %d sem." % maxi(0, int(o["expires"]) - w.week) if int(o["expires"]) > w.week else "última semana", "Caps")
	exp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(exp)
	var row := UIKit.tap_row(h, func(): UIManager.push("offer", {"id": int(o["id"])}))
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


func _news_row(w: GameWorld, n: Dictionary) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var ids: Array = n.get("fighters", [])
	if not ids.is_empty() and w.fighter(int(ids[0])) != null:
		h.add_child(FightKit.portrait(w, w.fighter(int(ids[0])), 56))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var kind := String(n.get("kind", ""))
	var chapeu: String = {"cinturao": "Cinturão", "resultado": "Resultado", "equipe": "Sua academia", "aposentadoria": "Aposentadoria"}.get(kind, "Notícia")
	var cap := UIKit.label("%s · %s" % [chapeu, w.weeks_from_now(int(n["week"]))], "Caps")
	if kind == "cinturao":
		cap.add_theme_color_override(&"font_color", UIColors.GOLD)
	elif kind == "equipe":
		cap.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(cap)
	v.add_child(UIKit.label(String(n["text"]), "H3" if bool(n.get("important", false)) else "", true))
	h.add_child(v)
	var cb := Callable()
	if not ids.is_empty():
		var fid := int(ids[0])
		cb = func(): UIManager.push("fighter", {"id": fid})
	var row := UIKit.tap_row(h, cb)
	return row


func _advance() -> void:
	var w := world()
	var mine := w.user_fighters().size()
	var t := w.user_team()
	if t.balance < 0.0 and mine == 0:
		UIManager.toast("Caixa negativo e ninguém para lutar. Corte custos na Academia.", UIColors.RED)
	GameManager.advance_week()
	Sfx.play("tab", -4.0)
	refresh()
	scroll_to_top()
