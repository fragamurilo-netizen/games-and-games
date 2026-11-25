extends BaseScreen
## Temporada: as três metas do ano, o termômetro de quem cobra o jogador (a cidade ou os sócios)
## com os motivos de cada subida e descida, as conquistas da carreira e o balanço dos anos
## fechados. As regras estão em Season e Achievements.

var _tab := "metas"
var _cat := ""


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Temporada"
	show_nav = false
	_tab = String(p.get("tab", "metas"))


func on_show() -> void:
	Tutorial.mark(world(), "season")
	super.on_show()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	Season.ensure(w)
	screen_subtitle = "%d · %s" % [int(w.goals.get("year", w.year())), w.user_team().name]
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(UIKit.segment([["metas", "Metas"], ["apoio", Season.meter_short(w)], ["conquistas", "Conquistas"], ["anos", "Anos"]], _tab, func(k: String):
		_tab = k
		intro_pending = true
		refresh()
		play_intro()))
	match _tab:
		"apoio":
			_support(w, c)
		"conquistas":
			_feats(w, c)
		"anos":
			_years(w, c)
		_:
			_goals(w, c)
	TutorialKit.tip(self, "season")
	SeasonKit.celebrate(w)


# --- Metas -------------------------------------------------------------------------------

func _goals(w: GameWorld, c: VBoxContainer) -> void:
	var pres := w.is_president()
	if Season.gala_pending(w):
		var y := int(w.gala["year"])
		var gc := UIKit.card("CardHighlight", UITokens.S1)
		gc.add_child(UIKit.colored("Noite de gala de %d" % y, UIColors.GOLD, "Section"))
		gc.add_child(UIKit.label("Os prêmios do ano, o balanço da sua temporada e as metas novas.", "Small", true))
		gc.add_child(UIKit.button("Ir para a cerimônia", "PrimaryButton", func(): UIManager.push("gala", {"year": y})))
		c.add_child(UIKit.card_panel(gc))
	var items := Season.items(w)
	var met := 0
	for g: Dictionary in items:
		if bool(Season.progress(w, g)["ok"]):
			met += 1
	var head := UIKit.card("Card", UITokens.S1)
	var hh := UIKit.hbox(0)
	hh.add_child(UIKit.stat_tile("%d de %d" % [met, items.size()], "Metas no caminho", UIColors.GREEN if met == items.size() else Color(0, 0, 0, 0)))
	hh.add_child(UIKit.stat_tile(str(SeasonKit.weeks_left(w)), "Semanas restantes"))
	hh.add_child(UIKit.stat_tile(str(int(round(Season.value_of(w)))), Season.meter_short(w), SupportBar.tone(Season.value_of(w))))
	head.add_child(hh)
	c.add_child(UIKit.card_panel(head))
	for g: Dictionary in items:
		var card := UIKit.card("Card", UITokens.S1)
		card.add_child(SeasonKit.goal_row(w, g, true, intro_pending))
		c.add_child(UIKit.card_panel(card))
	columnize(c, 1, 2, 1)


# --- Cidade ou sócios --------------------------------------------------------------------

func _support(w: GameWorld, c: VBoxContainer) -> void:
	var pres := w.is_president()
	var v := Season.value_of(w)
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(SeasonKit.meter(w, true, intro_pending))
	var log: Array = w.support.get("log", [])
	if log.size() >= 3:
		var sp := Sparkline.new()
		sp.values = log
		sp.zero = false
		sp.color = SupportBar.tone(v)
		sp.custom_minimum_size = Vector2(0, 64)
		if intro_pending:
			Anim.grow(sp, "reveal", 1.0, 0.7, 0.1)
		card.add_child(sp)
		card.add_child(UIKit.label("Últimas %s" % Fmt.plural(log.size(), "semana", "semanas"), "Caps"))
	card.add_child(UIKit.label(Season.perk_text(w), "Small", true))
	c.add_child(UIKit.card_panel(card))
	var ult: Dictionary = w.support.get("ult", {})
	if pres and not ult.is_empty():
		var uc := UIKit.card("Card", UITokens.S1)
		uc.add_child(UIKit.colored("Ultimato dos sócios", UIColors.RED, "Section"))
		uc.add_child(UIKit.label("A confiança precisa estar em %d ou mais até %s (%s). Sem isso, os sócios %s." % [int(float(ult["need"])),
			GameWorld.week_text(int(ult["until"])), w.weeks_from_now(int(ult["until"])),
			"encerram o seu mandato" if int(w.support.get("strikes", 0)) >= 1 else "intervêm: tiram 15% do caixa e a liga perde 6 de prestígio"], "Small", true))
		c.add_child(UIKit.card_panel(uc))
	# O que cada faixa rende ou custa.
	var bands := UIKit.card("Card", UITokens.S1)
	bands.add_child(UIKit.label("O que muda em cada faixa", "Section"))
	var rows: Array = []
	if pres:
		rows = [
			["75 ou mais", "Verba de marketing: +3 de hype em toda noite. Na virada do ano, bônus dos sócios.", UIColors.GREEN],
			["40 a 74", "Os sócios acompanham sem interferir.", UIColors.BLUE],
			["20 a 39", "Os sócios avisam que estão inquietos.", UIColors.ORANGE],
			["Abaixo de 20", "Verba de marketing segurada: −2 de hype. Três semanas seguidas aqui e vem o ultimato de %d semanas." % Season.ULT_WEEKS, UIColors.RED],
		]
	else:
		rows = [
			["75 ou mais", "Tatame cheio e patrocínio local no máximo. Lutadores da terra assinam mais fácil e a prefeitura premia na virada do ano.", UIColors.GREEN],
			["40 a 74", "Mais alunos procuram a academia e o comércio local patrocina toda semana. Os dois crescem com o apoio e com a reputação.", UIColors.BLUE],
			["20 a 39", "Sem patrocínio local, e os alunos começam a sair.", UIColors.ORANGE],
			["Abaixo de 20", "Por três semanas seguidas, a cidade vira as costas: a academia perde 3 de reputação e o patrocínio só volta com o apoio em 40.", UIColors.RED],
		]
	for r: Array in rows:
		var h := UIKit.hbox(UITokens.S2)
		var k := UIKit.colored(String(r[0]), r[2], "Caps")
		k.custom_minimum_size.x = 132
		h.add_child(k)
		h.add_child(UIKit.label(String(r[1]), "Small", true))
		bands.add_child(h)
	if pres:
		var st := int(w.support.get("strikes", 0))
		bands.add_child(UIKit.label("Mandato %d. Ultimatos perdidos neste mandato: %d de 2 (no segundo, o mandato acaba)." % [int(w.support.get("terms", 1)), st], "Caps", true))
	c.add_child(UIKit.card_panel(bands))
	# Por que subiu e por que caiu.
	var why := UIKit.card("Card", UITokens.S1)
	why.add_child(UIKit.label("O que mexeu no termômetro", "Section"))
	var rs := Season.reasons(w, 12)
	if rs.is_empty():
		why.add_child(UIKit.label("Nada ainda. %s" % ("Cada noite fechada entra aqui." if pres else "Cada luta da academia entra aqui."), "Muted", true))
	for e: Array in rs:
		var d := float(e[1])
		var h2 := UIKit.hbox(UITokens.S2)
		var dl := UIKit.colored("%s%s" % ["+" if d > 0.0 else "−", Fmt.dec(absf(d), 1)], UIColors.GREEN if d > 0.0 else UIColors.RED, "H3")
		dl.custom_minimum_size.x = 76
		h2.add_child(dl)
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(String(e[2]), "Small", true))
		tv.add_child(UIKit.label(w.weeks_from_now(int(e[0])), "Caps"))
		h2.add_child(tv)
		why.add_child(h2)
	c.add_child(UIKit.card_panel(why))
	columnize(c, 1, 2, 1)


# --- Conquistas --------------------------------------------------------------------------

func _feats(w: GameWorld, c: VBoxContainer) -> void:
	c.add_child(SeasonKit.rank_card(w, intro_pending))
	var all := Achievements.list(w)
	var cats: Array = [["", "Todas"]]
	for k: Array in Achievements.CATS:
		if all.any(func(d: Array) -> bool: return String(d[2]) == String(k[0])):
			cats.append(k)
	c.add_child(UIKit.scroll_tabs(cats, _cat, func(k: String):
		_cat = k
		refresh()))
	var lst := all.filter(func(d: Array) -> bool: return _cat == "" or String(d[2]) == _cat)
	# As conquistadas primeiro (as mais novas no alto), depois as mais perto de sair.
	var got: Array = lst.filter(func(d: Array) -> bool: return w.feats.has(String(d[0])))
	got.sort_custom(func(a: Array, b: Array) -> bool: return int(w.feats[String(a[0])]) > int(w.feats[String(b[0])]))
	var open: Array = lst.filter(func(d: Array) -> bool: return not w.feats.has(String(d[0])))
	var fr := {}
	for d: Array in open:
		fr[String(d[0])] = float(Achievements.progress(w, d)["frac"]) - (10.0 if bool(d[8]) else 0.0)
	open.sort_custom(func(a: Array, b: Array) -> bool: return float(fr[String(a[0])]) > float(fr[String(b[0])]))
	if not open.is_empty():
		c.add_child(UIKit.section_header("Por conquistar (%d)" % open.size()))
		var rows: Array = []
		for d: Array in open:
			rows.append(UIKit.tap_row(SeasonKit.feat_row(w, d, intro_pending), Callable()))
		c.add_child(UIKit.menu_group(rows))
	if not got.is_empty():
		c.add_child(UIKit.section_header("Conquistadas (%d)" % got.size()))
		var rows2: Array = []
		for d: Array in got:
			rows2.append(UIKit.tap_row(SeasonKit.feat_row(w, d), Callable()))
		c.add_child(UIKit.menu_group(rows2))


# --- Anos fechados -----------------------------------------------------------------------

func _years(w: GameWorld, c: VBoxContainer) -> void:
	var pres := w.is_president()
	var past: Array = (w.goals.get("past", []) as Array).duplicate()
	past.reverse()
	if past.is_empty():
		c.add_child(UIKit.state_block("empty", "O primeiro balanço sai em janeiro de %d" % (w.year() + 1), "Na virada do ano a liga faz a noite de gala: os prêmios, as metas cumpridas e as metas do ano novo."))
		return
	for p: Dictionary in past:
		var y := int(p["year"])
		var met := int(p.get("met", 0))
		var card := UIKit.card("Card", UITokens.S1)
		var head := UIKit.hbox(8)
		var t := UIKit.label(str(y), "Section")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		head.add_child(UIKit.colored(SeasonKit.cap(Season.verdict(met)), UIColors.GREEN if met >= 2 else (UIColors.ORANGE if met == 1 else UIColors.RED), "Caps"))
		card.add_child(head)
		for it: Dictionary in p.get("items", []):
			var h := UIKit.hbox(UITokens.S1)
			var mark := SeasonKit.GoalMark.new()
			mark.ok = bool(it["ok"])
			mark.custom_minimum_size = Vector2(22, 22)
			h.add_child(mark)
			var gl := UIKit.label(String(it["t"]), "Small", true)
			if not bool(it["ok"]):
				gl.add_theme_color_override(&"font_color", UIColors.MUTED)
			h.add_child(gl)
			card.add_child(h)
		var cash := float(p.get("cash1", 0.0)) - float(p.get("cash0", 0.0))
		var rep := float(p.get("rep1", 0.0)) - float(p.get("rep0", 0.0))
		var st := UIKit.hbox(0)
		var ct := UIKit.stat_tile("%s%s" % ["+" if cash >= 0.0 else "−", Fmt.money(absf(cash))], "Caixa no ano", UIColors.GREEN if cash >= 0.0 else UIColors.RED)
		ct.size_flags_stretch_ratio = 1.6
		st.add_child(ct)
		st.add_child(UIKit.stat_tile("%s%s" % ["+" if rep >= 0.0 else "−", Fmt.dec(absf(rep), 1)], "Prestígio" if pres else "Reputação", UIColors.GREEN if rep >= 0.0 else UIColors.RED))
		st.add_child(UIKit.stat_tile("%d → %d" % [int(round(float(p.get("v0", 50.0)))), int(round(float(p.get("v1", 50.0))))], Season.meter_short(w)))
		card.add_child(st)
		card.add_child(UIKit.button("Rever a cerimônia", "GhostButton", func(): UIManager.push("gala", {"year": y, "review": true})))
		c.add_child(UIKit.card_panel(card))
	columnize(c, 1, 2)
