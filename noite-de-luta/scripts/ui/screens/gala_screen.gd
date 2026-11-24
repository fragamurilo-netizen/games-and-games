extends BaseScreen
## Noite de gala: a cerimônia da virada do ano, em etapas. Abre com os números da casa no ano,
## entrega os prêmios (lutador, lutadora, revelação, luta, nocaute e finalização do ano), recebe
## a turma do Hall da Fama, faz o balanço das metas do jogador com o veredito da temporada e
## apresenta as metas do ano novo. O jogador avança etapa por etapa; dá para rever depois na
## tela da temporada.

var _year := 0
var _page := 0
var _pages: Array = []
var _review := false
var _opened := false


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Noite de gala"
	show_nav = false
	_year = int(p.get("year", 0))
	_review = bool(p.get("review", false))


func on_show() -> void:
	super.on_show()
	if not _opened:
		_opened = true
		Sfx.play("title", -10.0)


func _awards(w: GameWorld) -> Array:
	for a: Dictionary in w.awards:
		if int(a["year"]) == _year:
			return a["items"]
	return []


func _hall(w: GameWorld) -> Array:
	return w.hall.filter(func(h: Dictionary) -> bool: return int(h["year"]) == _year)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if _year <= 0:
		_year = int(w.gala.get("year", w.year() - 1))
	screen_subtitle = "%d · %s" % [_year, w.league_name()]
	UIManager.refresh_chrome()
	var rv := Season.review(w, _year)
	_pages = ["abertura"]
	if not _awards(w).is_empty():
		_pages.append("premios")
	if not _hall(w).is_empty():
		_pages.append("hall")
	if not rv.is_empty():
		_pages.append("balanco")
	if int(w.goals.get("year", 0)) == _year + 1:
		_pages.append("metas")
	_page = clampi(_page, 0, _pages.size() - 1)
	var c := reset()
	c.add_child(_pips())
	match String(_pages[_page]):
		"premios":
			_page_awards(w, c)
		"hall":
			_page_hall(w, c)
		"balanco":
			_page_review(w, c, rv)
		"metas":
			_page_goals(w, c)
		_:
			_page_open(w, c, rv)
	var foot := footer()
	var last := _page >= _pages.size() - 1
	var text := "Continuar"
	if last:
		text = "Fechar" if _review or String(_pages[_page]) != "metas" else "Começar %d" % (_year + 1)
	foot.add_child(UIKit.button(text, "PrimaryButton", _next, "" if last else "forward"))


## Em que etapa da cerimônia o jogador está.
func _pips() -> Control:
	var names := {"abertura": "Abertura", "premios": "Prêmios", "hall": "Hall da Fama", "balanco": "Sua temporada", "metas": "Ano novo"}
	var v := UIKit.vbox(6)
	var h := UIKit.hbox(4)
	for i in _pages.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(0, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.color = UIColors.GOLD if i <= _page else UIColors.SURFACE_3
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(pip)
	v.add_child(h)
	v.add_child(UIKit.label("%s · %d de %d" % [String(names.get(String(_pages[_page]), "")), _page + 1, _pages.size()], "Caps"))
	return v


func _next() -> void:
	if _page >= _pages.size() - 1:
		_finish()
		return
	_page += 1
	intro_pending = true
	refresh()
	play_intro()
	var s := scroll()
	if s != null:
		s.scroll_vertical = 0
	match String(_pages[_page]):
		"premios":
			Sfx.play("applause", -9.0)
		"hall":
			Sfx.play("applause", -12.0)
		"balanco":
			var met := int(Season.review(world(), _year).get("met", 0))
			Sfx.play("win" if met >= 2 else "notify", -8.0)
		"metas":
			Sfx.play("week", -6.0)


func _finish() -> void:
	var w := world()
	if w != null and not _review and int(w.gala.get("year", 0)) == _year and not bool(w.gala.get("seen", false)):
		w.gala["seen"] = true
		GameManager.save_now()
	UIManager.back()


func _big_title(text: String, sub: String, color: Color, icon_name: String = "trophy") -> Control:
	var v := UIKit.vbox(2)
	var ic := UIKit.icon_rect(icon_name, 64, color)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var t := UIKit.colored(text, color, "Title", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UIKit.label(sub, "Small", true)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	return v


# --- Abertura ----------------------------------------------------------------------------

func _page_open(w: GameWorld, c: VBoxContainer, rv: Dictionary) -> void:
	var t := w.user_team()
	var pres := w.is_president()
	c.add_child(_big_title("Noite de gala de %d" % _year, "O mundo do MMA se reúne para fechar o ano: os prêmios, o Hall da Fama e o balanço da %s." % t.name, UIColors.GOLD))
	if rv.is_empty():
		c.add_child(UIKit.label("A temporada de %d não tem balanço guardado: as metas começaram depois." % _year, "Muted", true))
		return
	var k: Dictionary = rv.get("c", {})
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var head := UIKit.hbox(UITokens.S2)
	var badge := TeamBadge.new()
	badge.team = t
	badge.custom_minimum_size = Vector2(64, 64)
	head.add_child(badge)
	var hv := UIKit.vbox(0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_child(UIKit.label(t.name, "Section"))
	hv.add_child(UIKit.label("O ano de %d em números" % _year, "Caps"))
	head.add_child(hv)
	card.add_child(head)
	var tiles: Array = []
	if pres:
		tiles = [
			[str(int(float(k.get("nights", 0.0)))), "Noites"],
			[Fmt.thousands(int(float(k.get("crowd", 0.0)))), "Público"],
			[str(int(float(k.get("title_bouts", 0.0)))), "Cinturões em jogo"],
			[str(int(float(k.get("hot", 0.0)))), "Noites quentes"],
			[Fmt.thousands(int(float(k.get("ppv", 0.0)))), "Compras de pay-per-view"],
			[Fmt.money(float(k.get("profit", 0.0))), "Lucro das noites", UIColors.GREEN if float(k.get("profit", 0.0)) >= 0.0 else UIColors.RED],
		]
	else:
		tiles = [
			["%d-%d-%d" % [int(float(k.get("wins", 0.0))), int(float(k.get("losses", 0.0))), int(float(k.get("draws", 0.0)))], "Cartel do ano"],
			[str(int(float(k.get("fin", 0.0)))), "Vitórias antes do fim"],
			[str(int(float(k.get("belts", 0.0)) + float(k.get("defs", 0.0)))), "Cinturões vencidos", UIColors.GOLD if float(k.get("belts", 0.0)) + float(k.get("defs", 0.0)) > 0.0 else Color(0, 0, 0, 0)],
			[Fmt.money(float(k.get("purse", 0.0))), "Bolsas da academia"],
			[Fmt.money(float(k.get("sponsor", 0.0))), "Patrocínio local"],
			[str(int(float(k.get("fights", 0.0)))), "Lutas"],
		]
	var cash := float(rv.get("cash1", 0.0)) - float(rv.get("cash0", 0.0))
	var rep := float(rv.get("rep1", 0.0)) - float(rv.get("rep0", 0.0))
	tiles.append(["%s%s" % ["+" if cash >= 0.0 else "−", Fmt.money(absf(cash))], "Caixa no ano", UIColors.GREEN if cash >= 0.0 else UIColors.RED])
	tiles.append(["%s%s" % ["+" if rep >= 0.0 else "−", Fmt.dec(absf(rep), 1)], "Prestígio no ano" if pres else "Reputação no ano", UIColors.GREEN if rep >= 0.0 else UIColors.RED])
	var grid := GridContainer.new()
	grid.columns = 2 if content_width() < 760.0 else 4
	grid.add_theme_constant_override(&"h_separation", UITokens.S2)
	grid.add_theme_constant_override(&"v_separation", UITokens.S2)
	for it: Array in tiles:
		grid.add_child(UIKit.stat_tile(String(it[0]), String(it[1]), it[2] if it.size() > 2 else Color(0, 0, 0, 0)))
	card.add_child(grid)
	c.add_child(UIKit.card_panel(card))


# --- Prêmios -----------------------------------------------------------------------------

func _page_awards(w: GameWorld, c: VBoxContainer) -> void:
	var items := _awards(w)
	var mine := 0
	for it: Dictionary in items:
		c.add_child(_award_card(w, it))
		if _is_mine(w, it):
			mine += 1
	if mine > 0 and not w.is_president():
		c.add_child(UIKit.colored("%s para a sua academia nesta noite." % Fmt.plural(mine, "prêmio", "prêmios"), UIColors.GOLD, "H3", true))
	columnize(c, 1, 2)


func _is_mine(w: GameWorld, it: Dictionary) -> bool:
	if w.is_president():
		return false
	for k: String in ["id", "a", "b"]:
		if it.has(k) and w.is_user_fighter(w.fighter(int(it[k]))):
			return true
	return false


func _award_card(w: GameWorld, it: Dictionary) -> Control:
	var mine := _is_mine(w, it)
	var card := UIKit.card("CardHighlight" if mine else "Card", UITokens.S1)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_rect("trophy", 22, UIColors.GOLD))
	var t := UIKit.colored(String(it["title"]), UIColors.GOLD, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	if mine:
		head.add_child(UIKit.pill("Da sua academia", UIColors.GOLD))
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
		else:
			card.add_child(UIKit.label(String(it.get("name", "")), "H3"))
	var txt := String(it.get("text", ""))
	if it.has("event") and String(it["event"]) != "":
		txt += " · " + String(it["event"])
	card.add_child(UIKit.label(txt, "Small", true))
	return UIKit.card_panel(card)


# --- Hall da Fama ------------------------------------------------------------------------

func _page_hall(w: GameWorld, c: VBoxContainer) -> void:
	c.add_child(_big_title("Hall da Fama", "A turma de %d: quem se aposentou e deixou história." % _year, UIColors.GOLD))
	for h: Dictionary in _hall(w):
		var f := w.fighter(int(h["id"]))
		if f == null:
			c.add_child(UIKit.label("%s · %s" % [String(h["name"]), String(h["text"])], "Small", true))
			continue
		var fid := f.id
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": fid}), String(h["text"]), UIColors.GOLD, Matchmaker.division_short(String(h["div"]))))


# --- Sua temporada -----------------------------------------------------------------------

func _page_review(w: GameWorld, c: VBoxContainer, rv: Dictionary) -> void:
	var pres := w.is_president()
	var met := int(rv.get("met", 0))
	var col: Color = [UIColors.RED, UIColors.ORANGE, UIColors.GREEN, UIColors.GOLD][clampi(met, 0, 3)]
	var who := "Os sócios" if pres else "A cidade"
	var line: String = [
		"%s esperavam muito mais. O ano que vem precisa ser outro." % who if pres else "%s esperava muito mais. O ano que vem precisa ser outro." % who,
		"Uma meta cumprida de três. %s." % ("Os sócios cobram mais regularidade" if pres else "A cidade quer ver mais"),
		"Duas metas de três. %s." % ("Os sócios saem satisfeitos da reunião" if pres else "A cidade reconhece o trabalho"),
		"As três metas cumpridas. %s." % ("Os sócios aplaudem de pé" if pres else "A cidade faz festa para a academia"),
	][clampi(met, 0, 3)]
	c.add_child(_big_title(SeasonKit.cap(Season.verdict(met)), line, col))
	var card := UIKit.card("Card", UITokens.S2)
	card.add_child(UIKit.label("Metas de %d" % _year, "Section"))
	for it: Dictionary in rv.get("items", []):
		var ok := bool(it["ok"])
		var h := UIKit.hbox(UITokens.S2)
		var mark := SeasonKit.GoalMark.new()
		mark.ok = ok
		h.add_child(mark)
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var gl := UIKit.label(String(it["t"]), "H3", true)
		if not ok:
			gl.add_theme_color_override(&"font_color", UIColors.MUTED)
		v.add_child(gl)
		v.add_child(UIKit.label(String(it["text"]), "Small"))
		v.add_child(UIKit.colored("Recompensa: %s" % String(it["reward"]) if ok else "Custou %d de %s" % [int(Season.sup_loss(w)), "confiança" if pres else "apoio"], UIColors.GREEN if ok else UIColors.RED, "Caps", true))
		h.add_child(v)
		card.add_child(h)
	c.add_child(UIKit.card_panel(card))
	var sc := UIKit.card("Card", UITokens.S1)
	var v0 := float(rv.get("v0", 50.0))
	var v1 := float(rv.get("v1", 50.0))
	sc.add_child(UIKit.label(Season.meter_name(w), "Caps"))
	var row := UIKit.hbox(UITokens.S2)
	var num := UIKit.label(str(int(round(v1))), "Title")
	num.add_theme_color_override(&"font_color", UIColors.ink(SupportBar.tone(v1)))
	if intro_pending:
		Anim.count(num, v0, v1, func(x: float) -> String: return str(int(round(x))), 0.9)
	row.add_child(num)
	var rvb := UIKit.vbox(2)
	rvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rvb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d := v1 - v0
	rvb.add_child(UIKit.label("%s · %s%d no ano" % [Season.level_name(w, v1), "+" if d >= 0.0 else "−", int(round(absf(d)))], "Small"))
	var bar := SupportBar.new()
	bar.marker = false
	bar.bar_h = 10.0
	if intro_pending:
		Anim.grow(bar, "value", v1, 0.9, 0.1, v0)
	else:
		bar.value = v1
	rvb.add_child(bar)
	row.add_child(rvb)
	sc.add_child(row)
	var bonus: Dictionary = rv.get("bonus", {})
	if not bonus.is_empty():
		sc.add_child(UIKit.colored("%s Bônus: %s." % [String(bonus.get("text", "")), Fmt.money(float(bonus.get("money", 0.0)))], UIColors.GREEN, "Small", true))
	var div := float(rv.get("div", 0.0))
	if div > 0.0:
		sc.add_child(UIKit.label("Os sócios retiraram %s em dividendos: %d%% do lucro do ano. O resto fica no caixa da liga." % [Fmt.money(div), int(Org.DIVIDEND * 100.0)], "Small", true))
	c.add_child(UIKit.card_panel(sc))
	var feats := _feats_of_year(w)
	if not feats.is_empty():
		var fc := UIKit.card("Card", UITokens.S1)
		fc.add_child(UIKit.label("Conquistas de %d (%d)" % [_year, feats.size()], "Section"))
		for dd: Array in feats.slice(0, 5):
			var fh := UIKit.hbox(UITokens.S1)
			fh.add_child(UIKit.icon_rect("medal", 22, SeasonKit.tier_color(int(dd[3]))))
			var fl := UIKit.label(String(dd[4]), "Small")
			fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			fh.add_child(fl)
			fh.add_child(UIKit.label(String(Achievements.TIER_NAMES[int(dd[3])]), "Caps"))
			fc.add_child(fh)
		if feats.size() > 5:
			fc.add_child(UIKit.label("E mais %d." % (feats.size() - 5), "Caps"))
		c.add_child(UIKit.card_panel(fc))
	columnize(c, 2, 2)


func _feats_of_year(w: GameWorld) -> Array:
	var out: Array = []
	for d: Array in Achievements.list(w):
		var key := String(d[0])
		if w.feats.has(key) and int(w.feats[key]) > 0 and int(GameWorld.date_of(int(w.feats[key]) - 1)["year"]) == _year:
			out.append(d)
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[3]) > int(b[3]))
	return out


# --- Ano novo ----------------------------------------------------------------------------

func _page_goals(w: GameWorld, c: VBoxContainer) -> void:
	var pres := w.is_president()
	c.add_child(_big_title("Metas de %d" % (_year + 1), "O que %s para a temporada que começa." % ("os sócios pedem" if pres else "a cidade espera da academia"), UIColors.TEXT, "star"))
	for g: Dictionary in Season.items(w):
		var card := UIKit.card("Card", UITokens.S1)
		card.add_child(SeasonKit.goal_row(w, g, true))
		c.add_child(UIKit.card_panel(card))
	columnize(c, 2, 2)
