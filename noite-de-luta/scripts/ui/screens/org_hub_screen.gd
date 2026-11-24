extends BaseScreen
## Início do presidente: o painel da semana. Em cima, a organização (caixa com tendência,
## prestígio e os números); depois a noite desta semana ou a próxima, o que espera decisão (a
## caixa de entrada), a agenda, os campeões numa faixa e as notícias. O botão principal leva à
## noite de luta (se ela é nesta semana) ou fecha a semana.

const HATS := {"cinturao": "Cinturão", "resultado": "Resultado", "organizacao": "Sua organização", "aposentadoria": "Aposentadoria",
	"marco": "Marco", "olheiro": "Olheiros", "mercado": "Mercado", "rivalidade": "Rivalidade", "tv": "Contrato de TV", "premio": "Prêmios",
	"hall": "Hall da Fama", "categoria": "Categoria", "visual": "Visual"}


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Início"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	Inbox.scan(w)
	screen_subtitle = "Semana de " + GameWorld.week_text(w.week)
	UIManager.refresh_chrome()
	var c := reset()
	var t := w.user_team()
	var champs := 0
	for div: String in w.champions:
		if int(w.champions[div]) >= 0:
			champs += 1
	var ups_all := Org.upcoming_events(w)
	var tv := String({"aberta": "Aberta", "cabo": "Assinatura", "streaming": "Streaming"}.get(String(w.tv.get("partner", "")), "Sem contrato"))
	c.add_child(DashKit.identity(w, t, "Presidente · sede em %s" % DataDB.nation_name(t.nation), "Prestígio", [
		[str(ups_all.size()), "Noites marcadas"], ["%d/%d" % [champs, w.champions.size()], "Campeões"], [tv, "TV"]], intro_pending))
	var night := Org.night_this_week(w)
	var hero := 0
	var ups := ups_all.filter(func(e: FightEvent) -> bool: return e != night)
	if night != null:
		c.add_child(_night_card(w, night))
		hero = 1
	elif not ups.is_empty():
		var nx: FightEvent = ups[0]
		var nid0 := nx.id
		var hv := UIKit.vbox(UITokens.S1)
		hv.add_child(UIKit.section_header("Próxima noite", "Ver todas", func(): UIManager.switch_area("events")))
		hv.add_child(OrgKit.event_card(w, nx, func(): UIManager.push("org_event", {"id": nid0})))
		c.add_child(hv)
		hero = 1
	c.add_child(InboxKit.todo_block(w, refresh))
	var ag := DashKit.agenda(w, _agenda(w, ups, hero == 1 and night == null), 7)
	if ag != null:
		c.add_child(ag)
	c.add_child(_champions_strip(w))
	OrgKit.awards_banner(w, c)
	OrgKit.followed_section(w, c)
	var nb := UIKit.vbox(UITokens.S1)
	DashKit.news(w, nb, HATS)
	c.add_child(nb)
	columnize(c, 1, 2, hero)
	var foot := footer()
	var urgent := FightWeek.pending(w, night) if night != null else []
	if not urgent.is_empty():
		var first: Dictionary = urgent[0]
		foot.add_child(UIKit.button("Resolver problemas da noite (%d)" % urgent.size(), "PrimaryButton", func(): WeekKit.open_incident(w, first, refresh)))
	elif night != null:
		var nid := night.id
		foot.add_child(UIKit.button("Ir para a noite de luta", "PrimaryButton", func(): UIManager.push("night", {"id": nid})))
	else:
		foot.add_child(UIKit.button("Avançar semana", "PrimaryButton", _advance, "fast"))


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
		elif main.interim:
			card.add_child(UIKit.colored("Valendo o cinturão interino dos %s" % Matchmaker.division_name(main.division, true), UIColors.GOLD, "Small"))
		var hv := Hype.event_value(w, ev)
		var hb := HeatBar.new()
		hb.bar_h = 8.0
		hb.marker = false
		Anim.grow(hb, "value", hv, 0.6, 0.1)
		card.add_child(hb)
		card.add_child(EventKit.hype_tag(hv, true))
	else:
		card.add_child(UIKit.colored("O card está vazio: a noite vai ser cancelada se ninguém lutar.", UIColors.RED, "Small", true))
	return UIKit.card_panel(card)


## As próximas noites (menos a que já está em destaque), a venda de ingressos, o fim do contrato
## de TV e a virada do ano.
func _agenda(w: GameWorld, ups: Array, skip_first: bool) -> Array:
	var items: Array = []
	var k := 0
	for ev: FightEvent in ups:
		var id := ev.id
		k += 1
		var lock := ev.week - Venue.LOCK_WEEKS
		if lock > w.week and k <= 2:
			items.append({"week": lock, "title": "Ingressos da %s à venda" % ev.name, "text": "Sede e arena travam: %s, %s" % [ev.city, Venue.type_name(ev).to_lower()],
				"cb": func(): UIManager.push("venue", {"id": id})})
		if skip_first and k == 1:
			continue
		if k > 5:
			continue
		var n := Org.event_bouts(w, ev).size()
		var belt := Card.has_belt(w, ev)
		items.append({"week": ev.week, "title": ev.name, "text": "%s · %d de %d lutas%s" % [ev.city, n, ev.slots, " · hype %d" % int(round(Hype.event_value(w, ev))) if n > 0 else ""],
			"color": UIColors.GOLD if belt else Color(0, 0, 0, 0), "cb": func(): UIManager.push("org_event", {"id": id})})
	var until := int(w.tv.get("until", 0))
	if until > w.week and until - w.week <= 16:
		items.append({"week": until, "title": "Fim do contrato de TV", "text": "%s · as propostas chegam %d semanas antes" % [String(TVDeal.partner_of(w).get("name", "")), TVDeal.NOTICE],
			"cb": func(): UIManager.push("tv")})
	var aw := DashKit.awards_week(w)
	if aw >= 0:
		items.append({"week": aw, "title": "Prêmios de %d" % w.year(), "text": "Lutador, luta, nocaute e revelação do ano", "color": UIColors.GOLD,
			"cb": func(): UIManager.push("legacy")})
	return items


## Os campeões da liga, categoria por categoria: quando defendem, quem está fora e o que vagou.
func _champions_strip(w: GameWorld) -> Control:
	var tiles: Array = []
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var f := w.fighter(int(w.champions.get(div, -1)))
		var tag := Matchmaker.division_short(div)
		if f == null:
			var tb := Org.title_booked(w, div)
			tiles.append(DashKit.fighter_tile(w, null, tag, Color(0, 0, 0, 0), "Disputa " + DashKit.short_when(w, tb.week) if tb != null else "Sem disputa",
				UIColors.TEXT if tb != null else UIColors.RED, func(): UIManager.switch_area("titles")))
			continue
		var fid := f.id
		var line := "Sem luta"
		var col := UIColors.MUTED
		var b := w.bout(f.bout_id)
		var out := Titles.champion_out(w, div)
		if b != null and b.status == "marcada":
			line = "Defende " + DashKit.short_when(w, b.week)
			col = UIColors.TEXT
		elif out != "":
			line = "Fora de combate"
			col = UIColors.RED
		elif Titles.interim_of(w, div) != null:
			line = "Falta unificar"
			col = UIColors.ORANGE
		tiles.append(DashKit.fighter_tile(w, f, tag, UIColors.GOLD, line, col, func(): UIManager.push("fighter", {"id": fid})))
	return DashKit.strip("Campeões", tiles, "Cinturões", func(): UIManager.switch_area("titles"))


func _advance() -> void:
	var w := world()
	var cash := w.user_team().balance
	var keys := DashKit.open_keys(w)
	GameManager.advance_week()
	DashKit.week_turn(world(), cash, keys)
	intro_pending = true
	refresh()
	play_intro()
	scroll_to_top()
