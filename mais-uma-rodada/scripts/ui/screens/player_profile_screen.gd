extends BaseScreen
## Perfil do jogador. Primeiro responde "esse jogador é bom para o meu time?";
## depois atributos, personalidade e histórico.

var _pid := -1
var _tab := "geral"
const TABS := [["geral", "Visão geral"], ["numeros", "Números"], ["carreira", "Carreira"]]


func _init() -> void:
	show_nav = false


func setup(p: Dictionary) -> void:
	super.setup(p)
	var np := int(p.get("id", -1))
	if np != _pid:
		_tab = String(p.get("tab", "geral"))
	_pid = np


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
	c.add_child(_tabs_row(p))
	match _tab:
		"numeros":
			c.add_child(_stats(w, p))
		"carreira":
			c.add_child(_career(w, p))
			c.add_child(_memory(w, p))
		_:
			c.add_child(_summary(w, p, own))
			c.add_child(_fit_card(w, p, own))
			c.add_child(_positions_card(w, p, own))
			c.add_child(_attributes(w, p, own))
			c.add_child(_personality(w, p, own))
			c.add_child(SocialPost.mini_card(w, -1, p.id))
			if own:
				c.add_child(RelationsScreen.player_card(w, p, func(): refresh()))
	_actions(w, p, own)


func _tabs_row(p: Player) -> Control:
	var row := UIKit.hbox(8)
	var g := ButtonGroup.new()
	for t in TABS:
		var key: String = t[0]
		var ch := UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh()
			scroll_to_top())
		ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(ch)
	var pid := p.id
	row.add_child(UIKit.icon_button("swap", func(): UIManager.push("compare", {"a": pid}), "Comparar"))
	return row


func _header(w: GameWorld, p: Player, club: Club) -> Control:
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	var card := UIKit.card("Card", 14)
	var row := UIKit.hbox(18)
	var pv := UIKit.portrait(p, club, w.year, 176)
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pv)
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Nome e, ao lado, o selo de overall/potencial (como uma ficha de jogador)
	var top := UIKit.hbox(10)
	var names := UIKit.vbox(4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UIKit.label(p.display_name(), "Title")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nl.custom_minimum_size.x = 60
	names.add_child(nl)
	if p.full_name() != p.display_name():
		names.add_child(UIKit.label(p.full_name(), "Small", true))
	var r1 := UIKit.hbox(8)
	r1.add_child(UIKit.pos_badge(p.position))
	var pn := UIKit.label(Pos.name_of(p.position), "Small", true)
	pn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(pn)
	names.add_child(UIKit.gap(4))
	names.add_child(r1)
	# Nacionalidade, físico e origem seguem na coluna do nome (sem buraco ao lado do selo)
	var nat := NameGenerator.nationality_name(p.nationality)
	if p.nationality != "":
		var nrow := UIKit.hbox(8)
		nrow.add_child(UIKit.flag(p.nationality, 32))
		var caps_h := NationalTeamManager.caps_of(w, p.id)
		nrow.add_child(UIKit.label(nat + ((" · %d jogos, %d gols pela seleção" % [caps_h[0], caps_h[1]]) if caps_h[0] > 0 else ""), "Small", true))
		names.add_child(nrow)
	var brow := UIKit.hbox(8)
	brow.add_child(UIKit.label("%d anos · %s · %d kg" % [p.age(w.year), Fmt.height(p.height), p.weight], "Small"))
	brow.add_child(FootView.make(p.foot, 24))
	brow.add_child(UIKit.label(["destro", "canhoto", "ambidestro"][p.foot], "Small"))
	names.add_child(brow)
	var born := p.hometown if p.hometown != "" else nat
	if born != "":
		names.add_child(UIKit.label("De %s" % born, "Small", true))
	var heart_txt := HeartClubs.known_text(w, p)
	if heart_txt != "":
		var hrow := UIKit.hbox(8)
		hrow.add_child(UIKit.icon_rect("heart", 20, UIColors.RED))
		var hc := HeartClubs.club_of(w, p)
		if hc != null:
			hrow.add_child(UIKit.crest(hc, 22))
		hrow.add_child(UIKit.label(("Torce para o %s" % hc.short_name) if hc != null else heart_txt, "Small", true))
		names.add_child(hrow)
	top.add_child(names)
	top.add_child(_ovr_block(w, p, own))
	col.add_child(top)
	row.add_child(col)
	card.add_child(row)
	if club != null:
		# Toque no clube abre a página dele: faixa larga com escudo, camisa e contrato
		var cr := UIKit.hbox(10)
		cr.add_child(UIKit.crest(club, 34))
		if p.shirt > 0:
			cr.add_child(UIKit.shirt_back(club, p.shirt, 40, false, p.position == Pos.GK))
		var cv := UIKit.vbox(0)
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cl := UIKit.label(club.short_name, "H3")
		cl.add_theme_color_override(&"font_color", UIColors.BLUE)
		cv.add_child(cl)
		var sub := "Camisa %d" % p.shirt if p.shirt > 0 else "Sem número"
		if not p.loan.is_empty():
			sub += " · emprestado"
		elif p.contract_end > 0:
			sub += " · contrato até %d" % p.contract_end
		cv.add_child(UIKit.label(sub, "Small"))
		cr.add_child(cv)
		cr.add_child(UIKit.label("›", "H3"))
		var cid := club.id
		card.add_child(UIKit.tap_row(cr, func(): UIManager.push("club", {"id": cid}), "CardFlat"))
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(p.playstyle().to_upper(), UIColors.BLUE, 16))
	if p.signature != "":
		tags.add_child(UIKit.pill("★ " + String(Player.SIGNATURE_NAMES.get(p.signature, p.signature)).to_upper(), UIColors.GOLD, 16))
	for sp in p.specialties():
		tags.add_child(UIKit.pill(String(sp).to_upper(), UIColors.GREEN, 16))
	for t in p.traits:
		tags.add_child(UIKit.pill(String(DatabaseManager.trait_data(t).get("name", t)).to_upper(), UIColors.ACCENT, 16))
	card.add_child(tags)
	card.add_child(UIKit.gap(2))
	return HeroBackdrop.attach(UIKit.card_panel(card), club, 0.08)


## Selo da ficha: overall grande e, embaixo, o potencial em palavras.
func _ovr_block(w: GameWorld, p: Player, own: bool) -> Control:
	var v := UIKit.vbox(2)
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var ovr := p.overall if own else PlayerRowView.estimate(w, p, p.overall)
	var ob := UIKit.badge(ovr, 96, 72, 46)
	if not own:
		ob.text_override = "~%d" % ovr
	v.add_child(ob)
	var cap := UIKit.label("OVERALL", "Caps")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override(&"font_size", 14)
	v.add_child(cap)
	var precision := 0.8 if own else (0.75 if Scouting.is_scouted(w, p) else 0.2)
	var pot := p.potential_estimate(precision)
	var age := p.age(w.year)
	var pot_label := Player.potential_label(pot) if age <= 25 else ("No auge" if age <= 30 else "Veterano")
	var pl := UIKit.colored(pot_label, UIColors.ACCENT if pot >= p.overall + 8 and age <= 25 else UIColors.MUTED, "Small")
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.custom_minimum_size.x = 96
	pl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(pl)
	return v


func _summary(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 12)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	grid.add_child(_tile(Fmt.money(p.value), "valor de mercado"))
	grid.add_child(_tile(Fmt.money(p.wage) if p.club_id >= 0 else "—", "salário/mês"))
	grid.add_child(_tile(str(p.contract_end) if p.club_id >= 0 else "Livre", "contrato até", UIColors.ORANGE if own and p.contract_end <= w.year else UIColors.TEXT))
	var form := p.form()
	grid.add_child(_tile(Fmt.rating(form) if not p.recent_ratings.is_empty() else "—", "forma", Fmt.match_rating_color(form) if not p.recent_ratings.is_empty() else UIColors.TEXT))
	grid.add_child(_tile(UIColors.morale_label(p.morale), "moral", UIColors.morale_color(p.morale)))
	var cond_txt := "%d%%" % int(p.condition)
	if p.injury_weeks > 0:
		cond_txt = "Lesão"
	grid.add_child(_tile(cond_txt, "físico" if p.injury_weeks == 0 else "%d semana(s)" % p.injury_weeks, UIColors.RED if p.injury_weeks > 0 else (UIColors.GREEN if p.condition >= 90 else UIColors.TEXT), p.condition / 100.0 if p.injury_weeks == 0 else -1.0))
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


## Quadradinho da ficha: valor grande, legenda e, se houver, uma barrinha de nível.
func _tile(value: String, caption: String, color: Color = UIColors.TEXT, fill: float = -1.0) -> Control:
	var v := UIKit.card("CardFlat", 2)
	var panel := UIKit.card_panel(v)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var l := UIKit.label(value, "H3")
	l.add_theme_color_override(&"font_color", color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 40
	v.add_child(l)
	var c := UIKit.label(caption, "Small")
	c.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	c.custom_minimum_size.x = 40
	v.add_child(c)
	if fill >= 0.0:
		var b := UIKit.bar(fill * 100.0, 100.0, color if color != UIColors.TEXT else UIColors.BLUE, 5)
		v.add_child(b)
	return panel


## "Esse jogador é bom para meu time?"
## Onde ele joga: mini campo com a posição principal, as secundárias e as vizinhas, pé e rendimento.
func _positions_card(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Posições"))
	var row := UIKit.hbox(16)
	row.add_child(PositionMap.make(p, 170))
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list: Array = [[p.position, "Principal", Color("#FFC940")]]
	for s in p.secondary:
		list.append([int(s), "Secundária", UIColors.GREEN])
	for k in Pos.RELATED[p.position]:
		if float(Pos.RELATED[p.position][k]) >= 0.85 and not p.secondary.has(k):
			list.append([int(k), "Improvisa", UIColors.MUTED])
	for e in list.slice(0, 6):
		var r := UIKit.hbox(8)
		r.add_child(UIKit.pos_badge(int(e[0])))
		var nm := UIKit.vbox(0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_child(UIKit.label(Pos.name_of(int(e[0])), "", false))
		nm.add_child(UIKit.colored(String(e[1]), e[2], "Small"))
		r.add_child(nm)
		var val := int(round(p.rating_at(int(e[0]))))
		if not own:
			val = PlayerRowView.estimate(w, p, val)
		r.add_child(UIKit.badge(val, 52, 36, 22))
		col.add_child(r)
	var frow := UIKit.hbox(10)
	frow.add_child(FootView.make(p.foot, 34))
	frow.add_child(UIKit.label(["Destro", "Canhoto", "Ambidestro: chuta bem com os dois"][p.foot], "Small", true))
	col.add_child(frow)
	row.add_child(col)
	card.add_child(row)
	return UIKit.card_panel(card)


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


func _attr_val(p: Player, a: int, own: bool) -> int:
	var v: int = p.attrs[a]
	if not own:
		v = clampi(v + int(round(RngUtil.noise(p.id, a, 7) * 5.0)), 1, 99)
	return v


func _attributes(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Atributos" + ("" if own else " (avaliação do olheiro)")))
	var groups: Array = []
	for g: Array in Attr.UI_GROUPS:
		if String(g[0]) == "Goleiro" and p.position != Pos.GK:
			continue
		groups.append(g)
	if p.position == Pos.GK:
		groups.erase(groups[groups.size() - 1])
		groups.insert(0, ["Goleiro", [Attr.GOL, Attr.REF]])
	# Radar com a média de cada grupo, para ler o jogador num relance
	var axes: Array = []
	var avgs: Array = []
	for g: Array in groups:
		var sum := 0
		for a in g[1]:
			sum += _attr_val(p, int(a), own)
		var avg := int(round(float(sum) / (g[1] as Array).size()))
		axes.append([String(g[0]), avg])
		avgs.append(avg)
	card.add_child(AttrRadar.make(axes, 390))
	for gi in groups.size():
		var g: Array = groups[gi]
		var head := UIKit.hbox(8)
		var gl := UIKit.label(String(g[0]).to_upper(), "Caps")
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gl)
		head.add_child(UIKit.badge(int(avgs[gi]), 48, 30, 18))
		card.add_child(UIKit.gap(4))
		card.add_child(head)
		for a in g[1]:
			var row := UIKit.hbox(10)
			var n := UIKit.label(Attr.NAMES[a], "")
			n.custom_minimum_size.x = 210
			row.add_child(n)
			var v := _attr_val(p, int(a), own)
			var bar := UIKit.bar(v, 100.0, Fmt.rating_color(v), 10)
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


func _personality(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Personalidade"))
	for t in p.traits:
		var d := DatabaseManager.trait_data(t)
		card.add_child(UIKit.label(String(d.get("name", t)), "H3"))
		card.add_child(UIKit.label(String(d.get("desc", "")), "Muted", true))
	if own:
		card.add_child(UIKit.label("Consistência: %s · Propensão a lesões: %s" % [_level(p.consistency, false), _level(p.injury_prone, true)], "Small", true))
	# Personalidade oculta: nunca o número, só o que a comissão percebe com a convivência.
	card.add_child(UIKit.label("O que a comissão percebe", "Caps"))
	if not own:
		card.add_child(UIKit.label("Por dentro, só a convivência revela. Contrate para conhecer.", "Muted", true))
	elif not HiddenPersona.known(w, p):
		card.add_child(UIKit.label("Ainda conhecendo o jogador. A comissão precisa de mais tempo com ele.", "Muted", true))
	else:
		var rep_lines := HiddenPersona.report(p)
		if rep_lines.is_empty():
			card.add_child(UIKit.label("Nada fora do comum: um jogador equilibrado por dentro.", "Muted", true))
		for ln: Array in rep_lines:
			card.add_child(UIKit.colored(String(ln[0]), UIColors.GREEN if ln[1] else UIColors.RED, "Small", true))
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
	if p.stats[Player.S_APPS] > 0:
		card.add_child(UIKit.label("Números detalhados (liga)", "Caps"))
		var gk := p.position == Pos.GK
		var row_c := UIKit.hbox(4)
		if gk:
			row_c.add_child(UIKit.stat(str(p.stats[Player.S_SAVES]), "defesas"))
			row_c.add_child(UIKit.stat("%.1f" % p.per90(Player.S_SAVES), "defesas /90"))
			row_c.add_child(UIKit.stat("%d%%" % int(round(p.pass_pct())), "passes certos"))
		else:
			row_c.add_child(UIKit.stat("%d (%d)" % [p.stats[Player.S_SHOTS], p.stats[Player.S_SHOTS_ON]], "chutes (alvo)"))
			row_c.add_child(UIKit.stat("%.1f" % p.xg(), "xG"))
			row_c.add_child(UIKit.stat(str(p.stats[Player.S_KEY_PASSES]), "passes decisivos"))
			row_c.add_child(UIKit.stat("%d%%" % int(round(p.pass_pct())), "passes certos"))
		card.add_child(row_c)
		if not gk:
			var row_d := UIKit.hbox(4)
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_DRIBBLES]), "dribles"))
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_TACKLES]), "desarmes"))
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_INTERCEPTIONS]), "interceptações"))
			var conv := 100.0 * p.stats[Player.S_GOALS] / p.stats[Player.S_SHOTS] if p.stats[Player.S_SHOTS] > 0 else 0.0
			row_d.add_child(UIKit.stat("%d%%" % int(round(conv)), "aproveitamento"))
			card.add_child(row_d)
			var diff := p.stats[Player.S_GOALS] - p.xg()
			if p.stats[Player.S_SHOTS] >= 15 and absf(diff) >= 2.0:
				card.add_child(UIKit.colored(("Marcando %.1f gols acima do esperado: fase iluminada." if diff > 0 else "%.1f gols abaixo do esperado: está desperdiçando chances.") % absf(diff), UIColors.GREEN if diff > 0 else UIColors.ORANGE, "Small", true))
	var tot := p.season_totals()
	if int(tot[0]) > p.stats[Player.S_APPS]:
		card.add_child(UIKit.label("Com as copas: %d jogos, %d gols e %d assistências." % [int(tot[0]), int(tot[1]), int(tot[2])], "Small", true))
	return UIKit.card_panel(card)


## Aba Carreira: números da carreira, seleção, prêmios, títulos, transferências e ano a ano.
func _career(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", 10)
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
		card.add_child(UIKit.section("Clubes e transferências"))
		var total := 0
		var top := 0
		for sp: Dictionary in p.spells:
			total += int(sp.get("fee", 0))
			top = maxi(top, int(sp.get("fee", 0)))
		if total > 0:
			var fr := UIKit.hbox(4)
			fr.add_child(UIKit.stat(Fmt.money(total), "em transferências"))
			fr.add_child(UIKit.stat(Fmt.money(top), "maior valor pago"))
			fr.add_child(UIKit.stat(Fmt.money(p.value), "valor hoje", UIColors.GREEN))
			card.add_child(fr)
		for i in range(p.spells.size() - 1, -1, -1):
			card.add_child(_spell_row(w, p.spells[i], i == p.spells.size() - 1))
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
			for inj in h.get("inj", []):
				var il := UIKit.label("      %s · %d semanas fora" % [String(inj[0]), int(inj[1])], "Small", true)
				il.add_theme_color_override(&"font_color", UIColors.RED)
				card.add_child(il)
	return UIKit.card_panel(card)


## Uma passagem: escudo, clube, anos, como chegou (base, compra, sem custo, empréstimo) e números.
func _spell_row(w: GameWorld, s: Dictionary, _current: bool) -> Control:
	var line := UIKit.hbox(10)
	var cl := w.club(int(s.get("c", -1))) if int(s.get("c", -1)) >= 0 else null
	if cl != null:
		line.add_child(UIKit.crest(cl, 40))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var to := int(s.get("to", 0))
	var from := int(s.get("from", 0))
	var years := ("%d–%s" % [from, str(to) if to > 0 else "hoje"]) if to != from else str(to)
	var name_l := UIKit.label(String(s.get("cn", "?")).replace(" (empr.)", ""), "H3")
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	col.add_child(UIKit.label("%s · %d jogos · %d gols" % [years, int(s.get("a", 0)), int(s.get("g", 0))], "Small"))
	line.add_child(col)
	var k := String(s.get("k", ""))
	if k == "" and (bool(s.get("lo", false)) or String(s.get("cn", "")).ends_with("(empr.)")):
		k = "e"
	match k:
		"b":
			line.add_child(UIKit.pill("BASE", UIColors.GREEN, 15))
		"e":
			line.add_child(UIKit.pill("EMPRÉSTIMO", UIColors.BLUE, 15))
		"l":
			line.add_child(UIKit.pill("SEM CUSTO", UIColors.MUTED, 15))
		"c":
			line.add_child(UIKit.pill(Fmt.money(int(s.get("fee", 0))), UIColors.ACCENT, 15))
	if cl != null:
		var ccid := cl.id
		return UIKit.tap_row(line, func(): UIManager.push("club", {"id": ccid}), "CardFlat")
	return line


## Football Memory: os fatos que definem a carreira e a linha do tempo, ano a ano.
func _memory(w: GameWorld, p: Player) -> Control:
	var tl := FootballMemory.timeline(w, p)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Linha do tempo"))
	card.add_child(UIKit.label("%s, %d anos" % [p.display_name(), p.age(w.year)], "H3"))
	for f: String in tl["facts"]:
		card.add_child(UIKit.colored(f, UIColors.ACCENT, "Small", true))
	card.add_child(UIKit.separator())
	var events: Array = tl["events"]
	var start := maxi(0, events.size() - 30)
	if start > 0:
		card.add_child(UIKit.label("(%d momentos mais antigos omitidos)" % start, "Small"))
	var last_y := -1
	for i in range(start, events.size()):
		var e: Dictionary = events[i]
		var row := UIKit.hbox(10)
		var y := int(e["y"])
		var yl := UIKit.label(str(y) if y != last_y else "", "H3")
		yl.custom_minimum_size.x = 64
		row.add_child(yl)
		last_y = y
		var t := UIKit.label(String(e["t"]), "", true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if String(e["k"]) in ["title", "goal", "record"]:
			t.add_theme_color_override(&"font_color", UIColors.ACCENT)
		row.add_child(t)
		card.add_child(row)
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
		"D:":
			return 7
		"S:":
			return 8
		"U:":
			return 9
		"L:":
			return 2 + int(DatabaseManager.league_cfg(k.substr(2)).get("tier", 1))
	return 10


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
		if AppSettings.career_edit:
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
		# Uma fileira só de ações compactas (ícone em cima, nome embaixo): a ficha ganha tela
		var row := UIKit.hbox(8)
		row.add_child(_act("Treino", "tactics", func(): TrainingSheet.open(p, refresh_cb)))
		row.add_child(_act("Renovar", "clock", func(): Negotiation.open(w, p, "renew", refresh_cb)))
		if p.transfer_listed:
			row.add_child(_act("Tirar venda", "money", func():
				p.transfer_listed = false
				p.asking_price = 0
				UIManager.toast("%s não está mais à venda." % p.display_name())
				refresh()))
		else:
			row.add_child(_act("Vender", "money", func(): Negotiation.open(w, p, "sell", refresh_cb)))
		row.add_child(_act("Emprestar", "swap", func():
			UIManager.confirm("Emprestar %s?" % p.display_name(), "Ele vai para um clube onde deve jogar mais, até o fim da temporada. O salário fica por conta do outro clube.", "Emprestar", func():
				var r := TransferManager.loan_out(w, p)
				UIManager.toast(r["msg"], UIColors.GREEN if r["ok"] else UIColors.RED)
				if r["ok"]:
					GameManager.save_now()
					UIManager.back())))
		if AppSettings.career_edit:
			row.add_child(_act("Editar", "gear", func(): UIManager.push("editor", {"player": p.id})))
		row.add_child(_act("Rescindir", "close", func():
			var cost := TransferManager.release_cost(w, p)
			UIManager.confirm("Rescindir com %s?" % p.display_name(), "Multa rescisória: %s (metade dos salários restantes). Ele sai do clube imediatamente." % Fmt.money(cost), "Rescindir", func():
				TransferManager.release(w, p)
				UIManager.toast("%s não é mais jogador do clube." % p.display_name())
				UIManager.back()), "DangerButton"))
		f.add_child(row)
	elif p.club_id < 0:
		f.add_child(UIKit.button("CONTRATAR (LIVRE)", "PrimaryButton", func(): Negotiation.open(w, p, "free", refresh_cb), "check"))
	else:
		var b := UIKit.button("FAZER PROPOSTA", "PrimaryButton", func(): Negotiation.open(w, p, "buy", refresh_cb), "swap")
		if not w.transfer_window_open():
			b.disabled = true
			b.text = "JANELA FECHADA"
		f.add_child(b)


## Botão compacto do rodapé: ícone em cima e o nome curto embaixo.
func _act(text: String, icon_name: String, cb: Callable, variation: String = "") -> Button:
	var b := UIKit.button(text, variation, cb, icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", 18)
	b.add_theme_constant_override(&"h_separation", 2)
	b.clip_text = true
	return b
