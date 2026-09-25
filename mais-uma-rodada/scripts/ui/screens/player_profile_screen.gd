extends BaseScreen
## Perfil do jogador. Primeiro responde "esse jogador é bom para o meu time?";
## depois atributos, personalidade e histórico.

var _pid := -1


func _init() -> void:
	show_nav = false


func setup(p: Dictionary) -> void:
	super.setup(p)
	_pid = int(p.get("id", -1))


func refresh() -> void:
	var w := world()
	var p := w.player(_pid) if w != null else null
	var c := content()
	UIKit.clear(c)
	if p == null:
		screen_title = "Jogador"
		screen_subtitle = ""
		UIManager.refresh_chrome()
		c.add_child(UIKit.label("Este jogador não está mais em atividade.", "Muted"))
		hide_footer()
		return
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	var club := w.club(p.club_id) if p.club_id >= 0 else null
	screen_title = p.display_name()
	screen_subtitle = club.short_name if club != null else "Sem clube"
	UIManager.refresh_chrome()
	c.add_child(_header(w, p, club))
	c.add_child(_summary(w, p, own))
	c.add_child(_fit_card(w, p, own))
	c.add_child(_attributes(w, p, own))
	c.add_child(_personality(p, own))
	if own:
		c.add_child(RelationsScreen.player_card(w, p, func(): refresh()))
	c.add_child(_stats(w, p))
	_actions(w, p, own)


func _header(w: GameWorld, p: Player, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	var row := UIKit.hbox(16)
	row.add_child(UIKit.portrait(p, club, w.year, 132))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.display_name(), "Title"))
	col.add_child(UIKit.label(p.full_name(), "Small", true))
	var r1 := UIKit.hbox(8)
	r1.add_child(UIKit.pos_badge(p.position))
	var sec := ""
	if not p.secondary.is_empty():
		var codes: Array = []
		for s in p.secondary:
			codes.append(Pos.code(s))
		sec = " (também " + ", ".join(codes) + ")"
	r1.add_child(UIKit.label(Pos.name_of(p.position) + sec, "Small", true))
	col.add_child(r1)
	var nat := NameGenerator.nationality_name(p.nationality)
	if p.nationality != "":
		var nrow := UIKit.hbox(8)
		nrow.add_child(UIKit.flag(p.nationality, 36))
		nrow.add_child(UIKit.label(nat, "Small"))
		col.add_child(nrow)
	var born := p.hometown if p.hometown != "" else nat
	col.add_child(UIKit.label("%d anos · %s · %d kg · pé %s" % [p.age(w.year), Fmt.height(p.height), p.weight, Player.FOOT_NAMES[p.foot].to_lower()], "Small", true))
	col.add_child(UIKit.label("De %s" % born, "Small", true))
	if club != null:
		# Toque no clube abre a página dele
		var cr := UIKit.hbox(8)
		cr.add_child(UIKit.crest(club, 30))
		var cl := UIKit.label("%s · camisa %d" % [club.short_name, p.shirt], "Small")
		cl.add_theme_color_override(&"font_color", UIColors.BLUE)
		cr.add_child(cl)
		cr.add_child(UIKit.label("›", "Small"))
		var cid := club.id
		col.add_child(UIKit.tap_row(cr, func(): UIManager.push("club", {"id": cid}), "CardFlat"))
	row.add_child(col)
	card.add_child(row)
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(p.playstyle().to_upper(), UIColors.BLUE))
	for t in p.traits:
		tags.add_child(UIKit.pill(String(DatabaseManager.trait_data(t).get("name", t)).to_upper(), UIColors.ACCENT))
	card.add_child(tags)
	return UIKit.card_panel(card)


func _summary(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 12)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 14)
	var ovr := p.overall if own else PlayerRowView.estimate(w, p, p.overall)
	var ob := UIKit.badge(ovr, 84, 64, 40)
	if not own:
		ob.text_override = "~%d" % ovr
	var ov := UIKit.vbox(2)
	ov.add_child(ob)
	ov.add_child(UIKit.label("overall", "Small"))
	ov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(ov)
	var precision := 0.8 if own else 0.2
	var pot := p.potential_estimate(precision)
	var age := p.age(w.year)
	var pot_label := Player.potential_label(pot) if age <= 25 else ("No auge" if age <= 30 else "Veterano")
	grid.add_child(_mini(pot_label, "potencial", UIColors.ACCENT if pot >= p.overall + 8 and age <= 25 else UIColors.TEXT))
	grid.add_child(_mini(Fmt.money(p.value), "valor"))
	grid.add_child(_mini(Fmt.money(p.wage) if p.club_id >= 0 else "—", "salário/mês"))
	grid.add_child(_mini(str(p.contract_end) if p.club_id >= 0 else "Livre", "contrato até", UIColors.ORANGE if own and p.contract_end <= w.year else UIColors.TEXT))
	var form := p.form()
	grid.add_child(_mini(Fmt.rating(form) if not p.recent_ratings.is_empty() else "—", "forma", Fmt.match_rating_color(form) if not p.recent_ratings.is_empty() else UIColors.TEXT))
	grid.add_child(_mini(UIColors.morale_label(p.morale), "moral", UIColors.morale_color(p.morale)))
	var cond_txt := "%d%%" % int(p.condition)
	if p.injury_weeks > 0:
		cond_txt = "Lesão"
	grid.add_child(_mini(cond_txt, "físico" if p.injury_weeks == 0 else "%d semana(s)" % p.injury_weeks, UIColors.RED if p.injury_weeks > 0 else UIColors.TEXT))
	card.add_child(grid)
	if p.injury_weeks > 0:
		card.add_child(UIKit.colored("%s — volta em %d semana(s)." % [p.injury_name, p.injury_weeks], UIColors.RED, "Small"))
	if p.suspension > 0:
		card.add_child(UIKit.colored("Suspenso por %d jogo(s)." % p.suspension, UIColors.RED, "Small"))
	if p.retiring:
		card.add_child(UIKit.colored("Anunciou que vai se aposentar ao fim da temporada.", UIColors.ACCENT, "Small"))
	if p.transfer_listed:
		card.add_child(UIKit.colored("À venda por %s." % Fmt.money(TransferManager.asking_price(w, p)), UIColors.GREEN, "Small"))
	if p.release_clause > 0 and p.club_id >= 0:
		card.add_child(UIKit.colored("Multa rescisória: %s." % Fmt.money(p.release_clause), UIColors.MUTED, "Small"))
	if not p.loan.is_empty():
		var owner := w.club(int(p.loan.get("from", -1)))
		card.add_child(UIKit.colored("Emprestado pelo %s até o fim de %d." % [owner.short_name if owner != null else "?", int(p.loan.get("until", w.year))], UIColors.BLUE, "Small"))
	return UIKit.card_panel(card)


func _mini(value: String, caption: String, color: Color = UIColors.TEXT) -> VBoxContainer:
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UIKit.label(value, "H3")
	l.add_theme_color_override(&"font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(l)
	v.add_child(UIKit.label(caption, "Small"))
	return v


## "Esse jogador é bom para meu time?"
func _fit_card(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("CardHighlight" if not own else "Card", 6)
	var user := w.user_club()
	var mine: Array = []
	for q in w.squad(user):
		if q.id != p.id and Pos.group(q.position) == Pos.group(p.position):
			mine.append(q)
	mine.sort_custom(func(a, b): return a.rating_at(p.position) > b.rating_at(p.position))
	var rating := p.rating_at(p.position)
	if not own:
		rating = float(PlayerRowView.estimate(w, p, int(round(rating))))
	var text := ""
	var color := UIColors.TEXT
	var starters_in_group := 1
	match Pos.group(p.position):
		Pos.G_DEF:
			starters_in_group = 4
		Pos.G_MID:
			starters_in_group = 4
		Pos.G_ATT:
			starters_in_group = 2
	var better := 0
	for q in mine:
		if q.rating_at(p.position) > rating + 0.5:
			better += 1
	if own:
		card.add_child(UIKit.section("No seu elenco"))
		if better == 0:
			text = "Melhor opção do elenco no setor."
			color = UIColors.GREEN
		elif better < starters_in_group:
			text = "Titular: %dº melhor do setor." % (better + 1)
		else:
			text = "Reserva: %d companheiros de setor rendem mais." % better
			color = UIColors.MUTED
	else:
		card.add_child(UIKit.section("Bom para o seu time?"))
		var ref: Player = null
		if not mine.is_empty():
			ref = mine[mini(starters_in_group - 1, mine.size() - 1)]
		if better < starters_in_group:
			color = UIColors.GREEN
			text = "Seria titular no %s." % user.short_name
			if ref != null:
				text += " Hoje, o %dº titular do setor é %s (%d)." % [mini(starters_in_group, mine.size()), ref.display_name(), int(round(ref.rating_at(p.position)))]
		elif better < starters_in_group + 2:
			color = UIColors.ACCENT
			text = "Brigaria por vaga: seria opção de banco forte."
		else:
			color = UIColors.MUTED
			text = "Não melhora o seu time hoje: %d jogadores do elenco rendem mais no setor." % better
		if p.age(w.year) <= 21 and p.potential_estimate(0.2) >= user.reputation * 0.2 + 60:
			text += " Jovem com margem para crescer."
	var l := UIKit.label(text, "H3", true)
	l.add_theme_color_override(&"font_color", color)
	card.add_child(l)
	return UIKit.card_panel(card)


func _attributes(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Atributos" + ("" if own else " (avaliação do olheiro)")))
	var groups: Array = Attr.UI_GROUPS.duplicate()
	if p.position == Pos.GK:
		groups.insert(0, ["Goleiro", [Attr.GOL]])
	for g in groups:
		card.add_child(UIKit.label(g[0], "Caps"))
		for a in g[1]:
			var row := UIKit.hbox(10)
			var n := UIKit.label(Attr.NAMES[a], "")
			n.custom_minimum_size.x = 210
			row.add_child(n)
			var v: int = p.attrs[a]
			if not own:
				v = clampi(v + int(round(RngUtil.noise(p.id, a, 7) * 5.0)), 1, 99)
			var bar := UIKit.bar(v, 100.0, Fmt.rating_color(v), 12)
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(bar)
			var num := UIKit.label(str(v) if own else "~%d" % v, "Mono")
			num.custom_minimum_size.x = 58
			num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			num.add_theme_color_override(&"font_color", Fmt.rating_color(v))
			row.add_child(num)
			card.add_child(row)
	return UIKit.card_panel(card)


func _personality(p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Personalidade"))
	for t in p.traits:
		var d := DatabaseManager.trait_data(t)
		card.add_child(UIKit.label(String(d.get("name", t)), "H3"))
		card.add_child(UIKit.label(String(d.get("desc", "")), "Muted", true))
	if own:
		card.add_child(UIKit.label("Consistência: %s · Propensão a lesões: %s" % [_level(p.consistency, false), _level(p.injury_prone, true)], "Small", true))
	if not p.persona_log.is_empty():
		card.add_child(UIKit.label("Como ele mudou", "Caps"))
		for i in range(p.persona_log.size() - 1, maxi(-1, p.persona_log.size() - 6), -1):
			var e: Dictionary = p.persona_log[i]
			var nm := String(DatabaseManager.trait_data(String(e["t"])).get("name", e["t"]))
			var line := "%d · %s %s. %s" % [int(e["y"]), "Virou" if e.get("add", false) else "Deixou de ser", nm.to_lower(), String(e.get("why", ""))]
			card.add_child(UIKit.colored(line, UIColors.GREEN if e.get("add", false) else UIColors.MUTED, "Small", true))
	return UIKit.card_panel(card)


static func _level(v: int, inverted: bool) -> String:
	var x := 21 - v if inverted else v
	if x >= 16:
		return "alta" if not inverted else "baixa"
	if x >= 9:
		return "média"
	return "baixa" if not inverted else "alta"


func _stats(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Temporada %d" % w.year))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(p.stats[Player.S_APPS]), "jogos"))
	row.add_child(UIKit.stat(str(p.stats[Player.S_GOALS]), "gols"))
	row.add_child(UIKit.stat(str(p.stats[Player.S_ASSISTS]), "assist."))
	row.add_child(UIKit.stat(Fmt.rating(p.avg_rating()) if p.stats[Player.S_APPS] > 0 else "—", "nota"))
	row.add_child(UIKit.stat("%d/%d" % [p.stats[Player.S_YELLOWS], p.stats[Player.S_REDS]], "cartões"))
	card.add_child(row)
	var row_b := UIKit.hbox(4)
	var mins := p.stats[Player.S_MINUTES]
	row_b.add_child(UIKit.stat(str(p.stats[Player.S_STARTS]), "titular"))
	row_b.add_child(UIKit.stat(str(mins), "minutos"))
	row_b.add_child(UIKit.stat(str(p.stats[Player.S_MOTM]), "craque jogo"))
	if Pos.group(p.position) <= Pos.G_DEF:
		row_b.add_child(UIKit.stat(str(p.stats[Player.S_CLEAN]), "sem sofrer"))
	else:
		row_b.add_child(UIKit.stat("%.2f" % ((p.stats[Player.S_GOALS] + p.stats[Player.S_ASSISTS]) * 90.0 / mins) if mins >= 90 else "—", "G+A /90"))
	var d := p.season_delta()
	row_b.add_child(UIKit.stat(("+%d" % d) if d > 0 else str(d), "overall no ano", UIColors.GREEN if d > 0 else (UIColors.RED if d < 0 else UIColors.TEXT)))
	card.add_child(row_b)
	var tot := p.season_totals()
	if int(tot[0]) > p.stats[Player.S_APPS]:
		card.add_child(UIKit.label("Com as copas: %d jogos, %d gols e %d assistências." % [int(tot[0]), int(tot[1]), int(tot[2])], "Small", true))
	card.add_child(UIKit.section("Carreira"))
	var row2 := UIKit.hbox(4)
	row2.add_child(UIKit.stat(str(p.career_apps), "jogos"))
	row2.add_child(UIKit.stat(str(p.career_goals), "gols"))
	row2.add_child(UIKit.stat(str(p.career_assists), "assist."))
	row2.add_child(UIKit.stat(str(p.titles), "títulos"))
	card.add_child(row2)
	var caps := NationalTeamManager.caps_of(w, p.id)
	var nt_titles := NationalTeamManager.player_titles(w, p.id)
	if caps[0] > 0 or NationalTeamManager.is_called(w, p):
		card.add_child(UIKit.section("Seleção · %s" % DatabaseManager.nation_name(p.nationality)))
		var row3 := UIKit.hbox(4)
		row3.add_child(UIKit.stat(str(caps[0]), "jogos"))
		row3.add_child(UIKit.stat(str(caps[1]), "gols"))
		row3.add_child(UIKit.stat("Sim" if NationalTeamManager.is_called(w, p) else "Não", "convocado", UIColors.GREEN if NationalTeamManager.is_called(w, p) else UIColors.MUTED))
		card.add_child(row3)
		if not nt_titles.is_empty():
			var tf := UIKit.flow(8)
			for t in nt_titles:
				tf.add_child(UIKit.pill("%s %d" % [String(NationalTeamManager.tcfg(t[0]).get("short", t[0])), int(t[1])], UIColors.ACCENT, 16))
			card.add_child(tf)
	if not p.awards.is_empty():
		card.add_child(UIKit.section("Prêmios"))
		var af := UIKit.flow(8)
		for i in range(p.awards.size() - 1, -1, -1):
			var a: Dictionary = p.awards[i]
			var wh := AwardManager.award_where(w, a)
			var where := "" if wh == "" else " · " + wh
			var big := AwardManager.award_weight(String(a["k"])) >= 5
			af.add_child(UIKit.pill("%s %d%s" % [AwardManager.award_name(String(a["k"])), int(a["y"]), where], UIColors.ACCENT if big else UIColors.BLUE, 16))
		card.add_child(af)
	if not p.trophies.is_empty():
		card.add_child(UIKit.section("Títulos"))
		card.add_child(_trophies(w, p))
	if not p.spells.is_empty():
		card.add_child(UIKit.section("Clubes"))
		for i in range(p.spells.size() - 1, -1, -1):
			var s: Dictionary = p.spells[i]
			var line := UIKit.hbox(10)
			var cl := w.club(int(s.get("c", -1))) if int(s.get("c", -1)) >= 0 else null
			if cl != null:
				line.add_child(UIKit.crest(cl, 28))
			var to := int(s.get("to", 0))
			var years := ("%d–%s" % [int(s.get("from", 0)), str(to) if to > 0 else "hoje"]) if to != int(s.get("from", 0)) else str(to)
			var name_l := UIKit.label("%s (%s)%s" % [s.get("cn", "?"), years, "  emprestado" if bool(s.get("lo", false)) else ""], "")
			name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(name_l)
			line.add_child(UIKit.label("%d j · %d g" % [int(s.get("a", 0)), int(s.get("g", 0))], "Muted"))
			if cl != null:
				var ccid := cl.id
				card.add_child(UIKit.tap_row(line, func(): UIManager.push("club", {"id": ccid}), "CardFlat"))
			else:
				card.add_child(line)
	if not p.history.is_empty():
		card.add_child(UIKit.section("Temporada a temporada"))
		var chart := EvolutionChart.new()
		chart.custom_minimum_size = Vector2(0, 150)
		chart.setup(p, w.year)
		card.add_child(chart)
		var hdr := UIKit.hbox(8)
		var hl := UIKit.label("Ano  Clube", "Caps")
		hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hdr.add_child(hl)
		hdr.add_child(UIKit.label("J  G  A  NOTA  OVR", "Caps"))
		card.add_child(hdr)
		for i in range(p.history.size() - 1, -1, -1):
			var h: Dictionary = p.history[i]
			var line := UIKit.hbox(8)
			var y := UIKit.label(str(h.get("y", "")), "Mono")
			y.custom_minimum_size.x = 64
			line.add_child(y)
			var cn := UIKit.label(String(h.get("cn", "")) + (" (emp.)" if bool(h.get("lo", false)) else ""), "")
			cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			line.add_child(cn)
			var apps := int(h.get("a", 0)) + int(h.get("ca", 0))
			var goals := int(h.get("g", 0)) + int(h.get("cg", 0))
			var ast := int(h.get("as", 0)) + int(h.get("cas", 0))
			line.add_child(UIKit.label("%d  %d  %d  %s" % [apps, goals, ast, Fmt.rating(float(h.get("r", 0.0)))], "Mono"))
			var o := int(h.get("o", 0))
			var ol := UIKit.label("—" if o <= 0 else str(o), "Mono")
			ol.custom_minimum_size.x = 84
			ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if o > 0 and h.has("o0"):
				var dd := o - int(h["o0"])
				if dd != 0:
					ol.text = "%d %s%d" % [o, "+" if dd > 0 else "", dd]
					ol.add_theme_color_override(&"font_color", UIColors.GREEN if dd > 0 else UIColors.RED)
			line.add_child(ol)
			card.add_child(line)
			var extra: Array = []
			if int(h.get("mo", 0)) > 0:
				extra.append("%d× craque do jogo" % int(h["mo"]))
			if int(h.get("cs", 0)) > 0 and Pos.group(p.position) <= Pos.G_DEF:
				extra.append(("%d jogo sem sofrer gol" if int(h["cs"]) == 1 else "%d jogos sem sofrer gol") % int(h["cs"]))
			for k in p.awards_in(int(h.get("y", 0))):
				if k != "team":
					extra.append(AwardManager.award_name(k))
			if p.awards_in(int(h.get("y", 0))).has("team"):
				extra.append(AwardManager.award_name("team"))
			if not extra.is_empty():
				var el := UIKit.label("      " + " · ".join(extra), "Small", true)
				el.add_theme_color_override(&"font_color", UIColors.ACCENT)
				card.add_child(el)
	return UIKit.card_panel(card)


## Estante do jogador: cada título com o troféu, quantas vezes e em que anos.
func _trophies(w: GameWorld, p: Player) -> Control:
	var groups := {} # chave -> [anos]
	for t: Dictionary in p.trophies:
		var k := String(t.get("k", ""))
		if not groups.has(k):
			groups[k] = []
		groups[k].append(int(t.get("y", 0)))
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b):
		var ra := _trophy_rank(a)
		var rb := _trophy_rank(b)
		return ra < rb if ra != rb else groups[a].size() > groups[b].size())
	var box := UIKit.vbox(6)
	for k: String in keys:
		var ys: Array = groups[k]
		ys.sort()
		var row := UIKit.hbox(10)
		var name := ""
		if k.begins_with("N:"):
			name = NationalTeamManager.tournament_name(k.substr(2))
		else:
			row.add_child(TrophyView.make(k, 40, w))
			name = TrophyView.trophy_name(k, w)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(("%d× " % ys.size() if ys.size() > 1 else "") + name, "H3", true))
		col.add_child(UIKit.label(", ".join(ys.map(func(y): return str(y))), "Small", true))
		row.add_child(col)
		box.add_child(row)
	return box


## Ordem da estante: seleção, mundial, continentais, ligas (pela divisão), estaduais.
static func _trophy_rank(k: String) -> int:
	match k.substr(0, 2):
		"N:":
			return -1
		"W:":
			return 0
		"C:":
			return 1
		"S:":
			return 8
		"L:":
			return 2 + int(DatabaseManager.league_cfg(k.substr(2)).get("tier", 1))
	return 9


func _actions(w: GameWorld, p: Player, own: bool) -> void:
	var f := footer()
	UIKit.clear(f)
	var refresh_cb := func(): refresh()
	if w.academy.has(p.id):
		var arow := UIKit.hbox(10)
		var up := UIKit.button("SUBIR AO PROFISSIONAL", "PrimaryButton", func():
			UIManager.toast(YouthManager.promote(w, p))
			GameManager.save_now()
			refresh(), "up")
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(up)
		arow.add_child(UIKit.button("Editar", "", func(): UIManager.push("editor", {"player": p.id}), "gear"))
		f.add_child(arow)
		return
	if own and not p.loan.is_empty():
		var owner := w.club(int(p.loan.get("from", -1)))
		f.add_child(UIKit.label("Emprestado pelo %s até o fim da temporada." % (owner.short_name if owner != null else "clube"), "Small", true))
		var tb := UIKit.button("Treino individual", "", func(): TrainingSheet.open(p, refresh_cb), "tactics")
		f.add_child(tb)
		return
	if not own and not p.loan.is_empty() and w.is_user_club(int(p.loan.get("from", -1))):
		f.add_child(UIKit.label("Seu jogador, emprestado até o fim da temporada. Volta ao clube na virada do ano.", "Small", true))
		return
	if own:
		var trow := UIKit.hbox(10)
		var tr := UIKit.button("Treino individual", "", func(): TrainingSheet.open(p, refresh_cb), "tactics")
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		trow.add_child(tr)
		trow.add_child(UIKit.button("Emprestar", "", func():
			UIManager.confirm("Emprestar %s?" % p.display_name(), "Ele vai para um clube onde deve jogar mais, até o fim da temporada. O salário fica por conta do outro clube.", "Emprestar", func():
				var r := TransferManager.loan_out(w, p)
				UIManager.toast(r["msg"], UIColors.GREEN if r["ok"] else UIColors.RED)
				if r["ok"]:
					GameManager.save_now()
					UIManager.back()), "swap"))
		trow.add_child(UIKit.button("Editar", "", func(): UIManager.push("editor", {"player": p.id}), "gear"))
		f.add_child(trow)
		var row := UIKit.hbox(10)
		var renew := UIKit.button("Renovar", "", func(): Negotiation.open(w, p, "renew", refresh_cb), "clock")
		renew.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(renew)
		if p.transfer_listed:
			var unl := UIKit.button("Tirar da venda", "", func():
				p.transfer_listed = false
				p.asking_price = 0
				UIManager.toast("%s não está mais à venda." % p.display_name())
				refresh(), "money")
			unl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(unl)
		else:
			var sell := UIKit.button("Vender", "", func(): Negotiation.open(w, p, "sell", refresh_cb), "money")
			sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(sell)
		var rel := UIKit.button("Rescindir", "DangerButton", func():
			var cost := TransferManager.release_cost(w, p)
			UIManager.confirm("Rescindir com %s?" % p.display_name(), "Multa rescisória: %s (metade dos salários restantes). Ele sai do clube imediatamente." % Fmt.money(cost), "Rescindir", func():
				TransferManager.release(w, p)
				UIManager.toast("%s não é mais jogador do clube." % p.display_name())
				UIManager.back()))
		row.add_child(rel)
		f.add_child(row)
	elif p.club_id < 0:
		f.add_child(UIKit.button("CONTRATAR (LIVRE)", "PrimaryButton", func(): Negotiation.open(w, p, "free", refresh_cb), "check"))
	else:
		var b := UIKit.button("FAZER PROPOSTA", "PrimaryButton", func(): Negotiation.open(w, p, "buy", refresh_cb), "swap")
		if not w.transfer_window_open():
			b.disabled = true
			b.text = "JANELA FECHADA"
		f.add_child(b)
