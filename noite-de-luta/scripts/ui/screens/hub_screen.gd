extends BaseScreen
## Início da academia: o painel da semana. Em cima, a casa (caixa com tendência, reputação e os
## números); depois a noite de luta ou a próxima luta, o que espera decisão (a caixa de entrada),
## a agenda das próximas semanas, a equipe numa faixa e as notícias. O botão fecha a semana.

const HATS := {"cinturao": "Cinturão", "resultado": "Resultado", "equipe": "Sua academia", "aposentadoria": "Aposentadoria",
	"marco": "Marco", "olheiro": "Olheiro", "mercado": "Mercado", "rivalidade": "Rivalidade", "premio": "Prêmios", "hall": "Hall da Fama",
	"categoria": "Categoria", "visual": "Visual", "meta": "Temporada", "apoio": "Cidade", "conquista": "Conquista"}

## A virada da semana está em andamento (segura o segundo toque no botão).
var _turning := false


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Início"


func on_show() -> void:
	super.on_show()
	var w := world()
	if w != null:
		(func(): SeasonKit.board_event(w, refresh)).call_deferred()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	TutorialKit.sync(w)
	Inbox.scan(w)
	screen_subtitle = "Semana de " + GameWorld.week_text(w.week)
	UIManager.refresh_chrome()
	var c := reset()
	var t := w.user_team()
	var mine := w.user_fighters()
	var weekly := Career.weekly_net(w)
	var best := ""
	for f: Fighter in mine:
		var r := w.rank_of(f)
		if r == 0:
			best = "Campeão"
		elif r > 0 and best != "Campeão" and (best == "" or r < int(best.trim_prefix("#"))):
			best = "#%d" % r
	c.add_child(DashKit.identity(w, t, "%s · %s" % [t.city, DataDB.nation_name(t.nation)], "Reputação", [
		[str(mine.size()), "Lutadores"], [("+" if weekly > 0.0 else "") + Fmt.money(weekly), "Fixo por semana", UIColors.RED if weekly < 0.0 else Color(0, 0, 0, 0)], [best if best != "" else "sem", "Melhor ranking", UIColors.GOLD if best == "Campeão" else Color(0, 0, 0, 0)]], intro_pending))
	var guide := TutorialKit.hub_card(w, refresh)
	if guide != null:
		c.add_child(guide)
	var pending := Career.pending_user_bouts(w)
	for b: Bout in pending:
		c.add_child(_fight_night(w, b))
	var hero := 0
	if pending.is_empty():
		var nxt := _next_fight(w, mine)
		if nxt != null:
			c.add_child(nxt)
			hero = 1
	c.add_child(InboxKit.todo_block(w, refresh))
	var season := SeasonKit.hub_card(w, intro_pending)
	if season != null:
		c.add_child(season)
	var ag := DashKit.agenda(w, _agenda(w, mine, pending))
	if ag != null:
		c.add_child(ag)
	if not mine.is_empty():
		c.add_child(_team_strip(w, mine))
	OrgKit.awards_banner(w, c)
	OrgKit.followed_section(w, c)
	c.add_child(UIKit.menu_group([
		UIKit.menu_row("belt", "Cinturões", "Os campeões e a linhagem de cada categoria", func(): UIManager.push("titles")),
		UIKit.menu_row("list", "Resultados da semana", "Todas as noites, da Liga Global ao regional", func(): UIManager.push("results")),
		UIKit.menu_row("trophy", "Legado", "Prêmios do ano, Hall da Fama e recordes", func(): UIManager.push("legacy")),
	]))
	var nb := UIKit.vbox(UITokens.S1)
	DashKit.news(w, nb, HATS)
	c.add_child(nb)
	columnize(c, 1, 2, pending.size() + hero + (1 if guide != null else 0))
	SeasonKit.celebrate(w)
	var foot := footer()
	if pending.is_empty():
		foot.add_child(UIKit.button("Avançar semana", "PrimaryButton", _advance, "fast"))
	else:
		foot.add_child(UIKit.button("Lute antes de avançar", "PrimaryButton", func(): UIManager.push("fight_plan", {"bout": (pending[0] as Bout).id})))


func _fight_night(w: GameWorld, b: Bout) -> Control:
	var ev := w.event(b.event_id)
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Noite de luta · " + ev.name, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	card.add_child(head)
	var what := " · valendo o cinturão" if b.title else (" · valendo o interino" if b.interim else "")
	card.add_child(UIKit.label("%s · %s%s" % [GameWorld.fight_date_text(b.week), ev.city, what], "Small"))
	card.add_child(FightKit.faceoff(w, w.fighter(b.a), w.fighter(b.b), 120))
	var go := UIKit.button("Plano de luta", "PrimaryButton", func(): UIManager.push("fight_plan", {"bout": b.id}))
	card.add_child(go)
	return UIKit.card_panel(card)


## Sem luta nesta semana: a próxima da equipe, com a contagem e o camp.
func _next_fight(w: GameWorld, mine: Array) -> Control:
	var best: Bout = null
	var who: Fighter = null
	for f: Fighter in mine:
		var b := Camp.bout_of(w, f)
		if b != null and b.week > w.week and (best == null or b.week < best.week):
			best = b
			who = f
	if best == null:
		return null
	var ev := w.event(best.event_id)
	var left := best.week - w.week
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	var el := UIKit.eyebrow("Próxima luta")
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(el)
	var cnt := UIKit.colored("Faltam %s" % Fmt.plural(left, "semana", "semanas"), UIColors.GOLD if best.title or best.interim else UIColors.TEXT, "Caps")
	head.add_child(cnt)
	card.add_child(head)
	card.add_child(FightKit.faceoff(w, w.fighter(best.a), w.fighter(best.b), 96))
	var what := " · cinturão" if best.title else (" · cinturão interino" if best.interim else "")
	var info := UIKit.label("%s · %s%s" % [ev.name if ev != null else "", GameWorld.fight_date_text(best.week, false), what], "Small")
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(info)
	if Camp.in_window(w, who) or float(who.camp.get("pts", 0.0)) > 0.0:
		var pts := float(Camp.ensure(w, who).get("pts", 0.0))
		var row := UIKit.hbox(UITokens.S2)
		row.add_child(UIKit.label("Camp", "Caps"))
		var bar := UIKit.bar(0.0, 100.0, UIColors.ACCENT, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		Anim.grow(bar, "value", pts, 0.6, 0.15)
		row.add_child(bar)
		row.add_child(UIKit.label("%d%% · %s" % [int(round(pts)), Camp.label(pts).to_lower()], "Caps"))
		card.add_child(row)
	elif Camp.starts_in(w, who) > 0:
		var cl := UIKit.label("O camp de %s começa em %s." % [who.short_name(), Fmt.plural(Camp.starts_in(w, who), "semana", "semanas")], "Small")
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(cl)
	var fid := who.id
	var p := UIKit.card_panel(card)
	var tap := Button.new()
	tap.theme_type_variation = "RowOverlay"
	tap.pressed.connect(func():
		Sfx.click()
		UIManager.push("fighter", {"id": fid, "tab": "treino"}))
	UIKit.attach_row_overlay(p, tap)
	return p


func _agenda(w: GameWorld, mine: Array, pending: Array) -> Array:
	var items: Array = []
	for f: Fighter in mine:
		var fid := f.id
		var b := Camp.bout_of(w, f)
		if b != null and not pending.has(b):
			var opp := w.fighter(b.other(f.id))
			var ev := w.event(b.event_id)
			var what := " · cinturão" if b.title else (" · interino" if b.interim else "")
			items.append({"week": b.week, "title": "%s × %s" % [f.short_name(), opp.short_name()], "text": "%s%s" % [ev.name if ev != null else "", what],
				"color": UIColors.GOLD if b.title or b.interim else Color(0, 0, 0, 0), "cb": func(): UIManager.push("fighter", {"id": fid, "tab": "treino"})})
			if Camp.starts_in(w, f) > 0:
				items.append({"week": w.week + Camp.starts_in(w, f), "title": "Começa o camp de %s" % f.short_name(), "text": "Oito semanas até a luta contra %s" % opp.short_name(),
					"cb": func(): UIManager.push("fighter", {"id": fid, "tab": "treino"})})
		if not f.injury.is_empty():
			items.append({"week": w.week + int(f.injury["weeks"]), "title": "%s volta da lesão" % f.short_name(), "text": String(f.injury["name"]),
				"cb": func(): UIManager.push("fighter", {"id": fid})})
	for j: Dictionary in Scouting.jobs(w):
		var sf := w.fighter(int(j["id"]))
		if sf != null:
			var sid := sf.id
			items.append({"week": w.week + int(j.get("left", 1)), "title": "Relatório do olheiro", "text": "%s (%s)" % [sf.display_name(), Matchmaker.division_short(sf.division)],
				"cb": func(): UIManager.push("fighter", {"id": sid})})
	for o: Dictionary in w.offers:
		var of := w.fighter(int(o["fighter"]))
		var oo := w.fighter(int(o["opp"]))
		if of != null and oo != null and int(o["expires"]) > w.week:
			var oid := int(o["id"])
			items.append({"week": int(o["expires"]), "title": "Vence a proposta para %s" % of.short_name(), "text": "Contra %s" % oo.short_name(),
				"cb": func(): UIManager.push("offer", {"id": oid})})
	var aw := DashKit.awards_week(w)
	if aw >= 0:
		items.append({"week": aw, "title": "Noite de gala de %d" % w.year(), "text": "Prêmios do ano, balanço das metas e metas novas", "color": UIColors.GOLD,
			"cb": func(): UIManager.push("season")})
	return items


func _team_strip(w: GameWorld, mine: Array) -> Control:
	var order := mine.duplicate()
	order.sort_custom(func(a: Fighter, b: Fighter) -> bool:
		var ba := Camp.bout_of(w, a)
		var bb := Camp.bout_of(w, b)
		if (ba != null) != (bb != null):
			return ba != null
		if ba != null and ba.week != bb.week:
			return ba.week < bb.week
		return a.level() > b.level())
	var tiles: Array = []
	for f: Fighter in order:
		var fid := f.id
		var line := "Livre"
		var col := UIColors.GREEN
		var b := Camp.bout_of(w, f)
		if not f.injury.is_empty():
			line = "Lesão · %d sem." % int(f.injury["weeks"])
			col = UIColors.RED
		elif b != null:
			line = "Luta " + DashKit.short_when(w, b.week)
			col = UIColors.TEXT
		elif f.suspension > 0:
			line = "Suspenso · %d sem." % f.suspension
			col = UIColors.ORANGE
		elif not Matchmaker.ready_to_book(w, f, 0):
			line = "Descansando"
			col = UIColors.MUTED
		var tone := Morale.tone(f)
		var tag := w.rank_text(f)
		var tcol := UIColors.GOLD if w.rank_of(f) == 0 else Color(0, 0, 0, 0)
		if tone < 0:
			tag = Morale.label(f)
			tcol = UIColors.RED if tone <= -2 else UIColors.ORANGE
		tiles.append(DashKit.fighter_tile(w, f, tag, tcol, line, col, func(): UIManager.push("fighter", {"id": fid})))
	return DashKit.strip("Equipe (%d)" % mine.size(), tiles, "Ver equipe", func(): UIManager.switch_area("team"))


func _advance() -> void:
	if _turning:
		return
	_turning = true
	var w := world()
	var mine := w.user_fighters().size()
	var t := w.user_team()
	if t.balance < 0.0 and mine == 0:
		UIManager.toast("Caixa negativo e ninguém para lutar. Corte custos na Academia.", UIColors.RED)
	var cash := t.balance
	var keys := DashKit.open_keys(w)
	await UIManager.busy("Fechando a semana…")
	GameManager.advance_week()
	UIManager.busy_done()
	_turning = false
	DashKit.week_turn(world(), cash, keys)
	intro_pending = true
	refresh()
	play_intro()
	scroll_to_top()
	SeasonKit.after_week(world(), refresh)
