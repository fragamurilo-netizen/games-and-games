extends BaseScreen
## Legado da liga: os prêmios de cada ano, o Hall da Fama e os recordes. É a memória do mundo:
## quem marcou época continua aqui depois de aposentado.

var _tab := "premios"
var _year := -1


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Legado"
	show_nav = false
	_tab = String(p.get("tab", "premios"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	screen_subtitle = w.league_name()
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(UIKit.segment([["premios", "Prêmios"], ["hall", "Hall da Fama"], ["recordes", "Recordes"]], _tab, func(k: String):
		_tab = k
		refresh()))
	match _tab:
		"hall":
			_hall(w, c)
		"recordes":
			_records(w, c)
		_:
			_awards(w, c)


func _awards(w: GameWorld, c: VBoxContainer) -> void:
	if w.awards.is_empty():
		var y := w.year()
		c.add_child(UIKit.state_block("empty", "Os primeiros prêmios saem em janeiro de %d" % (y + 1), "No fim de cada ano a liga escolhe o lutador e a lutadora do ano, a revelação, a luta, o nocaute e a finalização do ano."))
		_season(w, c)
		return
	var years: Array = []
	for a: Dictionary in w.awards:
		years.append(int(a["year"]))
	years.sort()
	years.reverse()
	if _year < 0 or not years.has(_year):
		_year = int(years[0])
	if years.size() > 1:
		c.add_child(UIKit.scroll_tabs(years.slice(0, 12).map(func(y: int) -> Array: return [str(y), str(y)]), str(_year), func(k: String):
			_year = int(k)
			refresh()))
	for a: Dictionary in w.awards:
		if int(a["year"]) != _year:
			continue
		for it: Dictionary in a["items"]:
			c.add_child(award_card(w, it, _year))
	if _year == int(years[0]):
		_season(w, c)
	columnize(c, 1, 2)


## Um prêmio: lutador (ou os dois da luta), o título e o porquê.
static func award_card(w: GameWorld, it: Dictionary, year: int) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_rect("trophy", 22, UIColors.GOLD))
	var t := UIKit.colored("%s %d" % [String(it["title"]), year], UIColors.GOLD, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	card.add_child(head)
	if it.has("a"):
		var fa := w.fighter(int(it["a"]))
		var fb := w.fighter(int(it["b"]))
		if fa != null and fb != null:
			card.add_child(FightKit.faceoff(w, fa, fb, 96, false))
	else:
		var f := w.fighter(int(it.get("id", -1)))
		if f != null:
			var fid := f.id
			card.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": fid}), "%s · %s" % [Matchmaker.division_short(f.division), f.record_text()]))
	var txt := String(it.get("text", ""))
	if it.has("event") and String(it["event"]) != "":
		txt += " · " + String(it["event"])
	card.add_child(UIKit.label(txt, "Small", true))
	return UIKit.card_panel(card)


## Ano em curso: quem está na frente na luta, no nocaute e na finalização do ano.
func _season(w: GameWorld, c: VBoxContainer) -> void:
	if String(w.season.get("year", "")) != str(w.year()):
		return
	var rows: Array = []
	for k: Array in [["luta", "Luta do ano"], ["nocaute", "Nocaute do ano"], ["finalizacao", "Finalização do ano"]]:
		if w.season.has(k[0]):
			rows.append([String(k[1]), String((w.season[k[0]] as Dictionary).get("text", ""))])
	if rows.is_empty():
		return
	c.add_child(UIKit.section_header("Na disputa em %d" % w.year()))
	var card := UIKit.card("Card", UITokens.S1)
	for r: Array in rows:
		card.add_child(UIKit.label(String(r[0]), "Caps"))
		card.add_child(UIKit.label(String(r[1]), "Small", true))
	c.add_child(UIKit.card_panel(card))


func _hall(w: GameWorld, c: VBoxContainer) -> void:
	if w.hall.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém no Hall da Fama ainda", "Campeões e veteranos de muitas vitórias entram no ano seguinte ao que se aposentam. A cerimônia é em janeiro."))
		_hall_watch(w, c)
		return
	var by_year := {}
	for h: Dictionary in w.hall:
		var y := int(h["year"])
		if not by_year.has(y):
			by_year[y] = []
		(by_year[y] as Array).append(h)
	var ys: Array = by_year.keys()
	ys.sort()
	ys.reverse()
	for y: int in ys:
		c.add_child(UIKit.section_header("Turma de %d" % y))
		for h: Dictionary in by_year[y]:
			var f := w.fighter(int(h["id"]))
			if f == null:
				c.add_child(UIKit.label("%s · %s" % [String(h["name"]), String(h["text"])], "Small", true))
				continue
			var fid := f.id
			c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": fid}), String(h["text"]), UIColors.GOLD, Matchmaker.division_short(String(h["div"]))))
	_hall_watch(w, c)


## Quem está na fila: aposentados à espera da cerimônia e ativos que já têm legado de Hall da Fama.
func _hall_watch(w: GameWorld, c: VBoxContainer) -> void:
	var cands: Array = []
	for f: Fighter in w.fighters.values():
		if not Legacy.in_hall(w, f.id) and Legacy.legacy_score(f) >= Legacy.HOF_MIN:
			cands.append(f)
	if cands.is_empty():
		return
	cands.sort_custom(func(a: Fighter, b: Fighter) -> bool: return Legacy.legacy_score(a) > Legacy.legacy_score(b))
	c.add_child(UIKit.section_header("Caminho do Hall da Fama"))
	for f: Fighter in cands.slice(0, 8):
		var fid := f.id
		var line := "%s · %s" % ["Aposentado" if f.retired else "Na ativa", f.record_text()]
		if f.titles_won > 0:
			line += " · %d %s" % [f.titles_won, "cinturão" if f.titles_won == 1 else "cinturões"]
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": fid}), line))


func _records(w: GameWorld, c: VBoxContainer) -> void:
	for r: Dictionary in Legacy.records(w):
		var card := UIKit.card("Card", UITokens.S1)
		card.add_child(UIKit.label(String(r["title"]), "Section"))
		var top: Array = r["top"]
		if top.is_empty():
			card.add_child(UIKit.label("Ninguém ainda.", "Muted"))
		for i in top.size():
			var v := int(top[i][0])
			var f: Fighter = top[i][1]
			var fid := f.id
			card.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": fid}), "%s%s · %s" % ["Aposentado · " if f.retired else "", Matchmaker.division_short(f.division), f.record_text()], Color(0, 0, 0, 0), str(v)))
		c.add_child(UIKit.card_panel(card))
	columnize(c, 1, 2)
