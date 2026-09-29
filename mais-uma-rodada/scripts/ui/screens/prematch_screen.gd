extends BaseScreen
## Pré-jogo: escalação (toque no jogador para trocar), formação, tática, bola parada e banco.
## Em modo "edit" (vindo do elenco) só salva; no fluxo normal inicia a partida.

var _edit := false
var _pitch: PitchView
var _notes: Array = []
var _extras_open := false
var _deep_open := false
## Tocar numa vaga do campinho muda a posição dela (formação personalizada) em vez do jogador.
var _pos_edit := false


func _init() -> void:
	show_nav = false
	screen_title = "Escalação"
	max_content_width = 1600.0


func setup(p: Dictionary) -> void:
	super.setup(p)
	_edit = p.get("edit", false) or screen_name == "tactics"
	# Na área Tática a escalação é a raiz e a barra de navegação fica à vista.
	show_nav = _edit


func on_show() -> void:
	var w := world()
	var club := w.user_club()
	_notes = ClubAI.validate_user_sheet(w, club)
	TacticsManager.ensure(club)
	refresh()


func _sheet() -> TeamSheet:
	return world().user_club().sheet


func refresh() -> void:
	var w := world()
	var club := w.user_club()
	var sheet := _sheet()
	var f := FixtureManager.next_fixture_for(w, club.id)
	screen_subtitle = "Rodada %d" % (f.round + 1) if f != null else ""
	screen_title = "Tática" if screen_name == "tactics" else ("Escalação e tática" if _edit else "Pré-jogo")
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	# Modo Futebol (DESIGN.md): o campo domina. Em retrato: formação, campo, banco e o plano
	# embaixo. Deitado/tablet: o campo ocupa a altura toda à esquerda; banco e plano ao lado.
	var wide := content_width() >= 1000.0
	var left: VBoxContainer = c
	var right: VBoxContainer = c
	if wide:
		var split := UIKit.hbox(UITokens.S6)
		left = UIKit.vbox(UITokens.S2)
		right = UIKit.vbox(UITokens.S3)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.4
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		split.add_child(left)
		split.add_child(right)
		c.add_child(split)
	left.add_child(_formation_header(w, club, sheet))
	# Avisos da escalação: dois à vista; o resto num popover junto deles (o campo não desce).
	var note_box: VBoxContainer = right if wide else left
	for n in _notes.slice(0, 2):
		note_box.add_child(UIKit.colored(n, UIColors.ORANGE, "Small", true))
	if _notes.size() > 2:
		var rest: Array = _notes.slice(2)
		var more := UIKit.button("E mais %d aviso(s)" % rest.size(), "TextButton", Callable())
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		more.pressed.connect(func():
			var l := UIKit.label("\n".join(PackedStringArray(rest)), "", true)
			UIManager.popover(l, more))
		note_box.add_child(more)
	# Campo
	_pitch = PitchView.new()
	_pitch.mode = "lineup"
	var vh := get_viewport_rect().size.y
	var landscape := UILayout.is_landscape()
	_pitch.horizontal = landscape and not UILayout.is_tablet()
	# Altura livre: tela menos barra superior, navegação (embaixo só no celular), cabeçalho da
	# formação e margens; no celular também o banco, para campo e banco caberem juntos.
	var avail := vh - 88.0 - 110.0 - 48.0 - (0.0 if wide else 96.0 + 190.0)
	var pw := content_width() * (0.58 if wide else 1.0)
	var ph := (pw / 1.55) if _pitch.horizontal else (pw / 0.74)
	_pitch.custom_minimum_size = Vector2(0, clampf(minf(ph, avail), 380.0, 1100.0))
	_pitch.mouse_filter = Control.MOUSE_FILTER_STOP
	_pitch.chip_color = club.primary_color()
	_update_chips()
	_pitch.slot_tapped.connect(_on_slot)
	left.add_child(_pitch)
	var rule := SquadRules.describe(club)
	if rule != "":
		var used := SquadRules.count(w, club, sheet.starters + sheet.bench)
		var lim := int(SquadRules.limit(club)["max"])
		if used > lim:
			left.add_child(UIKit.colored("%s: %d de %d." % [rule, used, lim], UIColors.ORANGE, "Small", true))
	# Banco: faixa de camisas logo abaixo do campo (ao lado, em tela larga).
	(right if wide else left).add_child(_bench_strip(w, club, sheet, wide))
	if f != null and not _edit:
		right.add_child(_opponent_card(w, f))
		right.add_child(_assistant_card(w, f))
	# Plano de jogo: cada escolha é uma linha com o valor atual; tocar abre as opções numa folha.
	var tac := DatabaseManager.tactics()
	var base := DatabaseManager.formation_base(sheet.formation)
	var custom := sheet.formation.begins_with("C:")
	right.add_child(UIKit.label("Plano de jogo", "Section"))
	var plan := UIKit.card("Card", 0)
	plan.add_child(_picker_row("Formação", base + (" (variação)" if custom else ""), TacticsManager.formation_fam(club, sheet.formation), _formation_sheet))
	plan.add_child(_picker_row("Mentalidade", String(tac["mentalities"][sheet.mentality]["name"]), -1.0, _mentality_sheet))
	plan.add_child(_picker_row("Estilo", String(tac["styles"][sheet.style]["short"]), TacticsManager.style_fam(club, sheet.style), _style_sheet))
	var adj := "Intensidade %s, linha %s" % [String(tac["intensity"][sheet.intensity]["name"]).to_lower(), String(tac["line"][sheet.line]["name"]).to_lower()]
	plan.add_child(_picker_row("Ajustes", adj, -1.0, _extras_sheet))
	var deep := TacticsManager.deep_summary(sheet)
	plan.add_child(_picker_row("Instruções", deep if deep != "" else "Padrão", -1.0, _section_sheet.bind("Instruções de equipe", func(v: VBoxContainer):
		_deep_open = true
		_deep_section(v, w, sheet))))
	plan.add_child(_picker_row("Por placar", "A partir dos %d'" % sheet.plan_minute, -1.0, _section_sheet.bind("Plano por placar", func(v: VBoxContainer): _plan_section(v, sheet))))
	plan.add_child(_picker_row("Individuais", "Por jogador", -1.0, _section_sheet.bind("Instruções individuais", func(v: VBoxContainer): _instructions_section(v, w, sheet))))
	var cap := w.player(sheet.captain)
	plan.add_child(_picker_row("Bola parada", ("Capitão " + cap.short_name()) if cap != null else "Capitão e cobradores", -1.0, _section_sheet.bind("Capitão e bola parada", func(v: VBoxContainer):
		for item in [["Capitão", "captain"], ["Pênaltis", "penalty_taker"], ["Faltas", "freekick_taker"], ["Escanteios", "corner_taker"]]:
			v.add_child(_taker_row(w, sheet, item[0], item[1]))
		v.add_child(_shootout_row(w, sheet)))))
	right.add_child(UIKit.card_panel(plan))
	right.add_child(_style_fit_label(w, sheet, tac["styles"][sheet.style]))
	_build_footer(w)


## Cabeçalho do campo: a formação em destaque, a força do time e as ferramentas rápidas.
func _formation_header(w: GameWorld, club: Club, sheet: TeamSheet) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var base := DatabaseManager.formation_base(sheet.formation)
	var tv := UIKit.vbox(-4)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fl := UIKit.label(base + ("*" if sheet.formation.begins_with("C:") else ""), "Title")
	tv.add_child(fl)
	var strength := ClubAI.lineup_strength(w, sheet.formation, sheet.starters) / 11.0
	tv.add_child(UIKit.label("%d titulares" % sheet.starters.filter(func(pid): return pid >= 0).size(), "Muted"))
	h.add_child(tv)
	var pe := UIKit.button("Mover posições", "ChipButton", func():
		_pos_edit = not _pos_edit
		refresh())
	pe.toggle_mode = true
	pe.button_pressed = _pos_edit
	pe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pe.custom_minimum_size.y = UITokens.H_CHIP
	h.add_child(pe)
	var tools := UIKit.icon_button("menu", func(): _tools_sheet(w, club), "Mais")
	tools.theme_type_variation = "GhostButton"
	tools.custom_minimum_size = Vector2(UITokens.H_CHIP, UITokens.H_CHIP)
	tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tools)
	return h


## Escalação automática e poupar cansados, num menu (ações de vez em quando, não o tempo todo).
func _tools_sheet(w: GameWorld, club: Club) -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label("Escalação", "Section"))
	v.add_child(UIKit.gap(UITokens.S2))
	var items := [
		["Escalação automática", "Os melhores disponíveis na formação atual.", func():
			club.sheet = ClubAI.auto_sheet(w, club, _sheet().formation)
			UIManager.toast("Melhores disponíveis escalados.")],
		["Poupar cansados", "Troca titulares abaixo do ideal por reservas à altura.", func():
			var msgs := SquadManager.rest_tired(w, club, _sheet())
			if msgs.is_empty():
				UIManager.toast("Ninguém cansado com substituto à altura.")
			else:
				_notes = msgs
				UIManager.toast("%d titular(es) poupado(s)." % msgs.size())],
	]
	for it in items:
		var box := UIKit.vbox(0)
		box.add_child(UIKit.label(String(it[0]), "H3"))
		box.add_child(UIKit.label(String(it[1]), "Muted", true))
		var cb: Callable = it[2]
		var row := UIKit.tap_row(box, func():
			UIManager.close_modal()
			cb.call()
			refresh())
		row.custom_minimum_size.y = UITokens.H_ROW
		v.add_child(row)
	UIManager.show_modal(v, true)


## Folha com uma seção do plano (instruções, plano por placar, individuais, bola parada).
func _section_sheet(title: String, build: Callable) -> void:
	var v := UIKit.vbox(UITokens.S2)
	var head := UIKit.hbox(8)
	var t := UIKit.label(title, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.button("Pronto", "TextButton", func():
		UIManager.close_modal()
		refresh()))
	v.add_child(head)
	build.call(v)
	UIManager.show_modal(v, true)


## Banco como faixa de camisas: número, sobrenome, geral e físico. Tocar escolhe quem troca.
func _bench_strip(w: GameWorld, club: Club, sheet: TeamSheet, wide: bool) -> Control:
	var out := UIKit.vbox(UITokens.S1)
	out.add_child(UIKit.label("Banco (%d)" % sheet.bench.size(), "Section"))
	var row: Container
	if wide:
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override(&"h_separation", UITokens.S1)
		g.add_theme_constant_override(&"v_separation", UITokens.S1)
		row = g
		out.add_child(g)
	else:
		var sc := ScrollContainer.new()
		sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
		sc.custom_minimum_size.y = 150
		var hb := UIKit.hbox(UITokens.S1)
		sc.add_child(hb)
		row = hb
		out.add_child(sc)
	for i in sheet.bench.size():
		var p := w.player(sheet.bench[i])
		if p == null:
			continue
		var bi := i
		var v := UIKit.vbox(0)
		v.custom_minimum_size.x = 118
		var kit := UIKit.shirt_back(club, p.shirt, 62, false, p.position == Pos.GK)
		kit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(kit)
		var nm := UIKit.label(p.short_name(), "Small")
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.add_theme_color_override(&"font_color", UIColors.TEXT)
		v.add_child(nm)
		var meta := UIKit.hbox(6)
		meta.alignment = BoxContainer.ALIGNMENT_CENTER
		meta.add_child(UIKit.colored(Pos.code(p.position), Pos.group_color(p.position), "Caps"))
		var ov := UIKit.player_stars(w,p,13)
		meta.add_child(ov)
		if p.injury_weeks > 0 or p.suspension > 0:
			meta.add_child(UIKit.colored("fora", UIColors.RED, "Caps"))
		elif p.condition < 85.0:
			meta.add_child(UIKit.colored("%d%%" % int(p.condition), UIColors.ORANGE, "Caps"))
		v.add_child(meta)
		var tap := UIKit.tap_row(v, func(): _pick_for_bench(bi), "PanelContainer")
		tap.tooltip_text = p.display_name()
		row.add_child(tap)
	return out


## Linha do painel rápido: nome à esquerda, valor e entrosamento à direita.
func _picker_row(title: String, value: String, fam: float, cb: Callable) -> Control:
	var h := UIKit.hbox(12)
	var t := UIKit.label(title, "Muted")
	t.custom_minimum_size.x = 170
	h.add_child(t)
	var v := UIKit.label(value)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(v)
	if fam >= 0.0:
		h.add_child(UIKit.colored(TacticsManager.fam_label(fam), TacticsManager.fam_color(fam), "Small"))
	h.add_child(UIKit.icon_rect("forward", 20, UIColors.DIM))
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


## Folha de opções: uma linha por opção, a atual marcada; escolher fecha e aplica.
func _option_sheet(title: String, items: Array, current: int, pick: Callable, extra: Control = null) -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, "H2"))
	v.add_child(UIKit.gap(8))
	if extra != null:
		v.add_child(extra)
	for i in items.size():
		var it: Array = items[i]
		var box := UIKit.vbox(0)
		var name := UIKit.label(String(it[0]))
		if i == current:
			name.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
		box.add_child(name)
		if it.size() > 1 and String(it[1]) != "":
			box.add_child(UIKit.label(String(it[1]), "Muted", true))
		var idx := i
		var row := UIKit.tap_row(box, func():
			UIManager.close_modal()
			pick.call(idx)
			refresh())
		row.custom_minimum_size.y = 72
		v.add_child(row)
	UIManager.show_modal(v, true)


func _formation_sheet() -> void:
	var sheet := _sheet()
	var club := world().user_club()
	var names: Array = DatabaseManager.formation_names()
	var base := DatabaseManager.formation_base(sheet.formation)
	var items: Array = []
	for fname in names:
		items.append([String(fname), TacticsManager.fam_label(TacticsManager.formation_fam(club, String(fname)))])
	var extra: Control = null
	if sheet.formation.begins_with("C:"):
		var ov := DatabaseManager.formation_overrides(sheet.formation)
		var base_slots: Array = DatabaseManager.formation(base)["slots"]
		var changes: Array = []
		for k in ov:
			changes.append("%s → %s" % [Pos.code(int(base_slots[int(k)]["pos"])), Pos.code(DatabaseManager.POS_BY_CODE[ov[k]])])
		extra = UIKit.label("Variação do %s: %s. Escolher uma formação desfaz a variação." % [base, ", ".join(PackedStringArray(changes))], "Muted", true)
	_option_sheet("Formação", items, names.find(base), func(i: int): _set_formation(String(names[i])), extra)


func _mentality_sheet() -> void:
	var sheet := _sheet()
	var tac := DatabaseManager.tactics()
	var items: Array = []
	for m: Dictionary in tac["mentalities"]:
		items.append([String(m["name"]), String(m.get("desc", ""))])
	_option_sheet("Mentalidade", items, sheet.mentality, func(i: int): sheet.mentality = i)


func _style_sheet() -> void:
	var sheet := _sheet()
	var club := world().user_club()
	var tac := DatabaseManager.tactics()
	var items: Array = []
	for i in 6:
		var st: Dictionary = tac["styles"][i]
		items.append([String(st["name"]), "%s · %s" % [String(st.get("desc", "")), TacticsManager.fam_label(TacticsManager.style_fam(club, i))]])
	_option_sheet("Estilo de jogo", items, sheet.style, func(i: int): sheet.style = i)


## Intensidade, linha, pressão, largura e substituições do assistente, numa folha só.
func _extras_sheet() -> void:
	var sheet := _sheet()
	var tac := DatabaseManager.tactics()
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Ajustes", "H2"))
	_segment(v, "Intensidade", tac["intensity"], sheet.intensity, func(i): sheet.intensity = i)
	_segment(v, "Linha defensiva", tac["line"], sheet.line, func(i): sheet.line = i)
	_segment(v, "Pressão", tac["pressing"], sheet.pressing, func(i): sheet.pressing = i)
	var wopts: Array = []
	for wi in TeamSheet.WIDTH_NAMES.size():
		wopts.append({"name": TeamSheet.WIDTH_NAMES[wi]})
	_segment(v, "Largura", wopts, sheet.width, func(i): sheet.width = i)
	var auto_subs := CheckButton.new()
	auto_subs.text = "Assistente faz substituições por cansaço e lesão"
	auto_subs.button_pressed = sheet.auto_subs
	auto_subs.toggled.connect(func(on): sheet.auto_subs = on)
	v.add_child(auto_subs)
	v.add_child(UIKit.button("Pronto", "PrimaryButton", func():
		UIManager.close_modal()
		refresh()))
	UIManager.show_modal(v, true)


func _opponent_card(w: GameWorld, f: Fixture) -> Control:
	var club := w.user_club()
	var opp := w.club(f.opponent_of(club.id))
	var league := w.league_of(opp.id) # a liga do adversário (em copa pode ser outra divisão ou país)
	var card := UIKit.card("Card", 6)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.crest(opp, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(("vs " if f.home == club.id else "@ ") + opp.short_name, "H2"))
	var where := ""
	if league != null and league.table.has(opp.id):
		where = "%dº na %s · " % [CompetitionManager.position_of(league, opp.id), league.short_name]
	col.add_child(UIKit.label("%s%s" % [where, opp.arch().get("tag", "")], "Small", true))
	row.add_child(col)
	if league != null and league.table.has(opp.id):
		var fd := FormDots.new()
		fd.dot = 18
		fd.form = league.table[opp.id]["form"]
		row.add_child(fd)
	card.add_child(row)
	if MatchEngine.is_derby(w, f.home, f.away):
		var derby := UIKit.pill("CLÁSSICO", UIColors.RED, 14)
		derby.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.add_child(derby)
	card.add_child(RivalryView.summary(w, club.id, opp.id))
	var opp_sheet := opp.sheet
	if opp_sheet != null:
		var tac := DatabaseManager.tactics()
		card.add_child(UIKit.label("Costuma jogar no %s, %s." % [opp_sheet.formation, String(tac["styles"][opp_sheet.style]["name"]).to_lower()], "Small"))
	card.add_child(UIKit.label("Filosofia: " + ClubPhilosophy.summary(opp), "Small", true))
	var h2h := FootballMemory.head_to_head(w, club.id, opp.id)
	card.add_child(UIKit.button("Ver confrontos anteriores", "GhostButton", func(): UIManager.push("rivalry", {"a": club.id, "b": opp.id}), "ball"))
	if int(h2h["games"]) > 0:
		var last: Array = h2h["recent"]
		var tail := ""
		if not last.is_empty():
			var e: Dictionary = last[-1]
			tail = " Último: %d x %d (%s %d)." % [int(e["gf"]), int(e["ga"]), FootballMemory.comp_name(w, String(e["comp"])), int(e["y"])]
		card.add_child(UIKit.label("Retrospecto: %s.%s" % [FootballMemory.h2h_line(h2h), tail], "Small", true))
	var stars: Array = w.squad(opp).duplicate()
	stars.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var names: Array = []
	for p: Player in stars.slice(0, 3):
		names.append("%s (%s)" % [p.display_name(), PlayStyle.of(p).to_lower()])
	if not names.is_empty():
		card.add_child(UIKit.label("De olho em: " + ", ".join(names) + ".", "Small", true))
	var ref := Referees.assign(w, f, MatchEngine.importance_of(w, f))
	var rs := Referees.summary(w, ref)
	if rs != "":
		var rrow := UIKit.hbox(8)
		rrow.add_child(UIKit.icon_rect("whistle", 22, UIColors.MUTED))
		rrow.add_child(UIKit.flag(String(ref[0]), 26))
		var rl := UIKit.label("Árbitro: " + rs, "Small", true)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rrow.add_child(rl)
		card.add_child(rrow)
	return UIKit.card_panel(card)


func _fam_row(title: String, v: float) -> Control:
	var row := UIKit.hbox(8)
	row.add_child(UIKit.label(title, "Small"))
	row.add_child(UIKit.spacer())
	var bar := UIKit.bar(v, 100.0, TacticsManager.fam_color(v), 8)
	bar.custom_minimum_size.x = 120
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var l := UIKit.colored(TacticsManager.fam_label(v), TacticsManager.fam_color(v), "Small")
	l.custom_minimum_size.x = 110
	row.add_child(l)
	return row


## Dossiê do auxiliar: como o rival joga, onde sofre, onde é perigoso, como deve vir contra nós
## e o plano completo para o jogo (aplicável com um toque).
func _assistant_card(w: GameWorld, f: Fixture) -> Control:
	var club := w.user_club()
	var opp := w.club(f.opponent_of(club.id))
	var d := Assistant.dossier(w, club, opp, f.home == club.id)
	var plan: Dictionary = d["plan"]
	var card := UIKit.card("Card", 6)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_rect("tactics", 22, UIColors.ACCENT))
	var ht := UIKit.label("Dossiê do auxiliar · %s" % Assistant.name_of(w), "Caps")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	card.add_child(head)
	for t in d["how"]:
		card.add_child(UIKit.label(String(t), "Small", true))
	if String(d["coach"]) != "":
		card.add_child(UIKit.label(String(d["coach"]), "Small", true))
	card.add_child(UIKit.colored("Momento: " + String(d["evo"]), UIColors.MUTED, "Small", true))
	if not (d["weak"] as Array).is_empty():
		card.add_child(UIKit.colored("Onde eles sofrem", UIColors.GREEN, "Caps"))
		for t in d["weak"]:
			card.add_child(UIKit.label("• " + String(t), "Small", true))
	if not (d["danger"] as Array).is_empty():
		card.add_child(UIKit.colored("Cuidado", UIColors.ORANGE, "Caps"))
		for t in d["danger"]:
			card.add_child(UIKit.label("• " + String(t), "Small", true))
	if String(d["pred"]) != "":
		card.add_child(UIKit.label(String(d["pred"]), "Small", true))
	if String(d["blind"]) != "":
		card.add_child(UIKit.colored(String(d["blind"]), UIColors.MUTED, "Small", true))
	card.add_child(UIKit.label("Nosso plano", "Caps"))
	for r in plan["reasons"]:
		card.add_child(UIKit.label("• " + String(r), "Small", true))
	var sheet := _sheet()
	if Assistant.plan_matches(sheet, plan):
		card.add_child(UIKit.colored("Sua tática já segue o plano.", UIColors.GREEN, "Small"))
	else:
		card.add_child(UIKit.label(Assistant.plan_summary(plan) + ".", "Small", true))
		card.add_child(UIKit.button("Aplicar o plano do auxiliar", "GhostButton", func():
			Assistant.apply_plan(sheet, plan)
			UIManager.toast("Plano do auxiliar aplicado.")
			refresh(), "tactics"))
	return UIKit.card_panel(card)


## Plano de jogo: o que fazer sozinho a partir de certo minuto conforme o placar.
## Instruções de equipe (ritmo, passe, marcação, perda da bola, foco, cera, escanteios).
func _deep_section(c: VBoxContainer, w: GameWorld, sheet: TeamSheet) -> void:
	c.add_child(UIKit.section("Instruções de equipe"))
	var summary := TacticsManager.deep_summary(sheet)
	c.add_child(UIKit.colored(summary if summary != "" else "Padrão", UIColors.ACCENT if summary != "" else UIColors.MUTED, "Small", true))
	var btn := UIKit.button(("Esconder" if _deep_open else "Mostrar") + " ritmo, passe, marcação e bola parada", "GhostButton", func():
		_deep_open = not _deep_open
		refresh())
	c.add_child(btn)
	if not _deep_open:
		return
	var vals := sheet.deep_values()
	for k in TacticsManager.DEEP.size():
		var key: String = TacticsManager.DEEP[k]
		var opts := TacticsManager.deep_options(key)
		if opts.is_empty():
			continue
		_segment(c, String(TacticsManager.DEEP_TITLES[key]), opts, int(vals[k]), func(i): sheet.set(key, i))
		var cur: Dictionary = opts[clampi(int(vals[k]), 0, opts.size() - 1)]
		if cur.has("fit"):
			c.add_child(_style_fit_label(w, sheet, cur))


func _plan_section(c: VBoxContainer, sheet: TeamSheet) -> void:
	var tac := DatabaseManager.tactics()
	c.add_child(UIKit.section("Plano de jogo"))
	var minutes := [60, 70, 80]
	c.add_child(UIKit.label("A partir do minuto", "Caps"))
	var gmin := ButtonGroup.new()
	var mrow := UIKit.hbox(8)
	for mn in minutes:
		var mv: int = mn
		var chip := UIKit.chip("%d'" % mv, sheet.plan_minute == mv, gmin, func():
			sheet.plan_minute = mv
			refresh())
		UIKit.shrink_button(chip)
		mrow.add_child(chip)
	c.add_child(mrow)
	for item in [["Se estiver perdendo", "plan_losing", [-1, TeamSheet.MENT_OFENSIVA, TeamSheet.MENT_TUDO]],
			["Se estiver vencendo", "plan_winning", [-1, TeamSheet.MENT_DEFENSIVA, TeamSheet.MENT_RETRANCA]]]:
		c.add_child(UIKit.label(String(item[0]), "Caps"))
		var key: String = item[1]
		var g := ButtonGroup.new()
		var row := UIKit.hbox(8)
		for opt in item[2]:
			var ov: int = opt
			var name := "Não mexer" if ov < 0 else String(tac["mentalities"][ov]["name"])
			var chip := UIKit.chip(name, int(sheet.get(key)) == ov, g, func():
				sheet.set(key, ov)
				refresh())
			UIKit.shrink_button(chip)
			row.add_child(chip)
		c.add_child(row)


func _style_fit_label(w: GameWorld, sheet: TeamSheet, st: Dictionary) -> Label:
	var fit_sum := 0.0
	var ovr_sum := 0.0
	var n := 0
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	for i in sheet.starters.size():
		var p := w.player(sheet.starters[i])
		if p == null or i == 0:
			continue
		var s := 0.0
		for code in st["fit"]:
			s += p.attrs[DatabaseManager.attr_index(code)]
		fit_sum += s / st["fit"].size()
		ovr_sum += p.rating_at(slots[i]["pos"])
		n += 1
	var diff := (fit_sum - ovr_sum) / maxf(1.0, n)
	var txt := "Encaixe bom" if diff >= 2.0 else ("Encaixe razoável" if diff >= -2.0 else "Encaixe ruim")
	return UIKit.colored(txt, UIColors.GREEN if diff >= 2.0 else (UIColors.MUTED if diff >= -2.0 else UIColors.ORANGE), "Small")


func _segment(c: VBoxContainer, title: String, options: Array, current: int, setter: Callable) -> void:
	c.add_child(UIKit.label(title, "Caps"))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in options.size():
		var idx := i
		var chip := UIKit.chip(String(options[i]["name"]), i == current, g, func():
			setter.call(idx)
			refresh())
		UIKit.shrink_button(chip)
		row.add_child(chip)
	c.add_child(row)


func _taker_row(w: GameWorld, sheet: TeamSheet, label_text: String, key: String) -> Control:
	var pid: int = sheet.get(key)
	var p := w.player(pid)
	var row := UIKit.hbox(10)
	var l := UIKit.label(label_text, "Muted")
	l.custom_minimum_size.x = 170
	row.add_child(l)
	var v := UIKit.label(p.display_name() if p != null else "—", "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	row.add_child(UIKit.icon_rect("swap", 22, UIColors.MUTED))
	return UIKit.tap_row(row, func(): _pick_taker(key, label_text))


func _pick_taker(key: String, label_text: String) -> void:
	var w := world()
	var sheet := _sheet()
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label(label_text, "Title"))
	for pid in sheet.starters:
		var p := w.player(pid)
		if p == null:
			continue
		var ppid: int = pid
		v.add_child(PlayerRowView.make(w, p, {"mode": "pick"}, func():
			sheet.set(key, ppid)
			UIManager.close_modal()
			refresh()))
	_show_sheet(v)


## Ordem dos batedores se o jogo for para os pênaltis.
func _shootout_row(w: GameWorld, sheet: TeamSheet) -> Control:
	var row := UIKit.hbox(10)
	var l := UIKit.label("Disputa de pênaltis", "Muted")
	l.custom_minimum_size.x = 170
	row.add_child(l)
	var names: Array = []
	for p: Player in _shootout_players(w, sheet).slice(0, 5):
		names.append(p.short_name())
	var txt := "Automática" if sheet.shootout_order.is_empty() else ", ".join(names)
	var v := UIKit.label(txt, "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.clip_text = true
	row.add_child(v)
	row.add_child(UIKit.icon_rect("swap", 22, UIColors.MUTED))
	return UIKit.tap_row(row, _pick_shootout_order)


func _shootout_players(w: GameWorld, sheet: TeamSheet) -> Array:
	var ps: Array = []
	for pid in sheet.starters:
		var p := w.player(pid)
		if p != null:
			ps.append(p)
	return ShootoutOrderView.ordered(ps, sheet.shootout_order)


func _pick_shootout_order() -> void:
	var w := world()
	var sheet := _sheet()
	var auto := ShootoutOrderView.ordered(_shootout_players(w, sheet), [])
	_show_sheet(ShootoutOrderView.build("Batedores na disputa de pênaltis",
		"",
		_shootout_players(w, sheet), auto, func(ids: Array):
			sheet.shootout_order = ids
			UIManager.close_modal()
			refresh()))


func _show_sheet(v: VBoxContainer) -> void:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.custom_minimum_size = Vector2(0, 860)
	s.scroll_deadzone = 14
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(v)
	UIManager.show_modal(s, true)


func _update_chips() -> void:
	var w := world()
	var sheet := _sheet()
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	var club := w.user_club()
	var kh: Dictionary = club.kit_home
	var kg: Dictionary = club.gk_kit()
	var chips: Array = []
	for i in slots.size():
		var pid: int = sheet.starters[i] if i < sheet.starters.size() and sheet.starters[i] != null else -1
		var p := w.player(pid)
		var s: Dictionary = slots[i]
		var ch := {"x": s["x"], "y": s["y"], "number": p.shirt if p != null else "?", "name": p.short_name() if p != null else "vazio",
			"rating": 0,
			"c1": Color(String((kg if int(s["pos"]) == Pos.GK else kh).get("c1", club.color1))),
			"c2": Color(String((kg if int(s["pos"]) == Pos.GK else kh).get("c2", club.color2))),
			"cond": p.condition if p != null else 100.0}
		if p != null and Pos.familiarity(p.position, p.secondary, s["pos"]) < 0.9:
			ch["warn"] = true
		if p != null and p.id == sheet.captain:
			ch["name"] = ch["name"] + " (C)"
		chips.append(ch)
	_pitch.chips = chips
	_pitch.queue_redraw()


func _set_formation(fname: String) -> void:
	var w := world()
	var club := w.user_club()
	var sheet := _sheet()
	sheet.formation = fname
	# Reorganiza os mesmos jogadores (e completa com o banco) na nova formação.
	var pool: Array = sheet.starters.duplicate()
	var ids := ClubAI.best_eleven(w, club, fname)
	var keep: Array = []
	for pid in ids:
		keep.append(pid)
	sheet.starters = keep
	sheet.bench = ClubAI.pick_bench(w, club, sheet.starters)
	for key in ["captain", "penalty_taker", "freekick_taker", "corner_taker"]:
		if not sheet.starters.has(sheet.get(key)):
			ClubAI.pick_set_pieces(w, sheet)
			break
	if pool.size() > 0:
		UIManager.toast("Formação %s: time reorganizado." % fname)
	refresh()


## Instruções individuais dos titulares (toque para mudar).
func _instructions_section(c: VBoxContainer, w: GameWorld, sheet: TeamSheet) -> void:
	c.add_child(UIKit.section("Instruções individuais"))
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	for i in range(1, mini(slots.size(), sheet.starters.size())):
		var p := w.player(sheet.starters[i])
		if p == null:
			continue
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(int(slots[i]["pos"])))
		var nc := UIKit.vbox(0)
		nc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(p.display_name(), "")
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nc.add_child(nl)
		var sl := UIKit.label(PlayStyle.full(p), "Small")
		sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nc.add_child(sl)
		row.add_child(nc)
		var ins := sheet.instruction_of(p.id)
		row.add_child(UIKit.colored(String(ins.get("name", "Padrão da função")), UIColors.ACCENT if not ins.is_empty() else UIColors.MUTED, "Small"))
		var pid := p.id
		c.add_child(UIKit.tap_row(row, func(): _pick_instruction(pid), "CardFlat"))


func _pick_instruction(pid: int) -> void:
	var w := world()
	var sheet := _sheet()
	var p := w.player(pid)
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Instrução para %s" % p.display_name(), "Title", true))
	var st := PlayStyle.describe(p)
	v.add_child(UIKit.label(String(st["name"]), "Small", true))
	var match_key := String(st["instruction"])
	v.add_child(UIKit.button("Padrão da função", "GhostButton", func():
		sheet.instr.erase(pid)
		UIManager.close_modal()
		refresh()))
	for k in TeamSheet.INSTRUCTION_ORDER:
		var key: String = k
		var d: Dictionary = TeamSheet.INSTRUCTIONS[key]
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if key == match_key:
			var hr := UIKit.hbox(8)
			hr.add_child(UIKit.label(String(d["name"]), "H3"))
			hr.add_child(UIKit.pill("COMBINA COM O ESTILO", UIColors.GREEN, 13))
			col.add_child(hr)
		else:
			col.add_child(UIKit.label(String(d["name"]), "H3"))
		col.add_child(UIKit.label(String(d["desc"]), "Small", true))
		v.add_child(UIKit.tap_row(col, func():
			sheet.instr[pid] = key
			UIManager.close_modal()
			refresh()))
	_show_sheet(v)


## Muda a posição de uma vaga (formação personalizada a partir da base).
func _pick_slot_position(index: int) -> void:
	var sheet := _sheet()
	if index == 0:
		UIManager.toast("O goleiro fica no gol.")
		return
	var base := DatabaseManager.formation_base(sheet.formation)
	var base_pos: int = DatabaseManager.formation(base)["slots"][index]["pos"]
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Nova posição da vaga", "Title"))
	var fl := UIKit.flow(8)
	for pos in Pos.DISPLAY_ORDER:
		if pos == Pos.GK:
			continue
		var pp: int = pos
		fl.add_child(UIKit.button(Pos.name_of(pp), "PrimaryButton" if pp == int(DatabaseManager.formation(sheet.formation)["slots"][index]["pos"]) else "", func():
			var ov := DatabaseManager.formation_overrides(sheet.formation)
			if pp == base_pos:
				ov.erase(index)
			else:
				ov[index] = Pos.CODES_I18N["en"][pp]
			sheet.formation = DatabaseManager.custom_formation_name(base, ov)
			UIManager.close_modal()
			refresh()))
	v.add_child(fl)
	_show_sheet(v)


func _on_slot(index: int) -> void:
	if _pos_edit:
		_pick_slot_position(index)
		return
	var w := world()
	var sheet := _sheet()
	_pitch.selected = index
	_pitch.queue_redraw()
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	var pos: int = slots[index]["pos"]
	var current: int = sheet.starters[index]
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Escolher %s" % Pos.name_of(pos), "Title"))
	var cands: Array = []
	for pid in w.user_club().player_ids:
		if pid != current:
			cands.append(w.player(pid))
	cands.sort_custom(func(a, b): return a.rating_at(pos) > b.rating_at(pos))
	for p: Player in cands:
		var pid := p.id
		var tag := ""
		if sheet.starters.has(pid):
			tag = "titular"
		elif sheet.bench.has(pid):
			tag = "banco"
		var row := PlayerRowView.make(w, p, {"mode": "pick", "pos": pos}, func(): _assign(index, pid))
		if not p.is_available():
			row.modulate = Color(1, 1, 1, 0.45)
		if tag != "":
			var box := UIKit.vbox(2)
			box.add_child(UIKit.label(tag, "Caps"))
			box.add_child(row)
			v.add_child(box)
		else:
			v.add_child(row)
	_show_sheet(v)


func _assign(index: int, pid: int) -> void:
	var w := world()
	var sheet := _sheet()
	var p := w.player(pid)
	if p == null:
		return
	if not p.is_available():
		UIManager.toast("%s está %s." % [p.display_name(), "lesionado" if p.is_injured() else ("a serviço da seleção" if p.intl_duty else "suspenso")], UIColors.RED)
		return
	var old: int = sheet.starters[index]
	var j := sheet.starters.find(pid)
	if j >= 0:
		sheet.starters[j] = old
	else:
		var b := sheet.bench.find(pid)
		if b >= 0:
			sheet.bench[b] = old
	sheet.starters[index] = pid
	for key in ["captain", "penalty_taker", "freekick_taker", "corner_taker"]:
		if not sheet.starters.has(sheet.get(key)):
			ClubAI.pick_set_pieces(w, sheet)
			break
	UIManager.close_modal()
	_pitch.selected = -1
	refresh()


func _pick_for_bench(bench_index: int) -> void:
	var w := world()
	var sheet := _sheet()
	var v := UIKit.vbox(8)
	v.add_child(UIKit.label("Trocar reserva", "Title"))
	var cands: Array = []
	for pid in w.user_club().player_ids:
		if not sheet.starters.has(pid) and not sheet.bench.has(pid):
			cands.append(w.player(pid))
	cands.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	if cands.is_empty():
		v.add_child(UIKit.label("Todo o elenco disponível já está relacionado.", "Muted"))
	for p: Player in cands:
		var pid := p.id
		v.add_child(PlayerRowView.make(w, p, {"mode": "pick"}, func():
			if not p.is_available():
				UIManager.toast("%s está indisponível." % p.display_name(), UIColors.RED)
				return
			sheet.bench[bench_index] = pid
			UIManager.close_modal()
			refresh()))
	_show_sheet(v)


func _build_footer(w: GameWorld) -> void:
	var f := footer()
	UIKit.clear(f)
	if screen_name == "tactics":
		hide_footer() # a escalação vale na hora; o jogo salva sozinho ao avançar
		return
	if _edit:
		f.add_child(UIKit.button("SALVAR ESCALAÇÃO", "PrimaryButton", func():
			GameManager.save_now()
			UIManager.toast("Escalação salva.")
			UIManager.back(), "check"))
		return
	var items: Array = []
	for i in AppSettings.SPEED_ORDER:
		items.append([str(i), AppSettings.SPEED_NAMES[i]])
	var row := UIKit.segment(items, str(AppSettings.match_speed), func(key: String):
		AppSettings.match_speed = int(key)
		AppSettings.save_settings())
	f.add_child(row)
	var start := UIKit.button("INICIAR PARTIDA", "PrimaryButton", _start, "whistle")
	start.custom_minimum_size.y = 100
	f.add_child(start)


func _start() -> void:
	var w := world()
	var sheet := _sheet()
	var missing := 0
	for pid in sheet.starters:
		if w.player(pid) == null:
			missing += 1
	if missing > 0:
		UIManager.info("Escalação incompleta", "Faltam %d jogador(es) no time titular." % missing)
		return
	Sfx.play("whistle", -4.0)
	if AppSettings.match_speed == AppSettings.SPEED_INSTANT:
		GameManager.play_instant_async(func(report: Dictionary) -> void:
			UIManager.replace("results", {"report": report}))
	else:
		GameManager.begin_match()
		UIManager.replace("match")
