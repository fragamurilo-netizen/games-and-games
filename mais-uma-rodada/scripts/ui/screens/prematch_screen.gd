extends BaseScreen
## Pré-jogo: escalação (toque no jogador para trocar), formação, tática, bola parada e banco.
## Em modo "edit" (vindo do elenco) só salva; no fluxo normal inicia a partida.

var _edit := false
var _pitch: PitchView
var _notes: Array = []
var _extras_open := false
## Tocar numa vaga do campinho muda a posição dela (formação personalizada) em vez do jogador.
var _pos_edit := false


func _init() -> void:
	show_nav = false
	screen_title = "Escalação"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_edit = p.get("edit", false)


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
	screen_title = "Escalação e tática" if _edit else "Pré-jogo"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if f != null and not _edit:
		c.add_child(_opponent_card(w, f))
		c.add_child(_assistant_card(w, f))
	for n in _notes:
		c.add_child(UIKit.colored(n, UIColors.ORANGE, "Small"))
	# Campo
	_pitch = PitchView.new()
	_pitch.mode = "lineup"
	_pitch.custom_minimum_size = Vector2(0, 700)
	_pitch.mouse_filter = Control.MOUSE_FILTER_STOP
	_pitch.chip_color = club.primary_color()
	_update_chips()
	_pitch.slot_tapped.connect(_on_slot)
	c.add_child(_pitch)
	var strength := ClubAI.lineup_strength(w, sheet.formation, sheet.starters) / 11.0
	var hint := UIKit.hbox(8)
	hint.add_child(UIKit.label("Toque numa vaga para mudar a posição dela." if _pos_edit else "Toque em um jogador para trocar.", "Small"))
	hint.add_child(UIKit.spacer())
	hint.add_child(UIKit.label("Força do time: %d" % int(round(strength)), "H3"))
	c.add_child(hint)
	var rule := SquadRules.describe(club)
	if rule != "":
		var used := SquadRules.count(w, club, sheet.starters + sheet.bench)
		var lim := int(SquadRules.limit(club)["max"])
		c.add_child(UIKit.colored("%s: %d/%d%s" % [rule, used, lim, " — acima do limite, o assistente ajusta antes do jogo." if used > lim else ""], UIColors.ORANGE if used > lim else UIColors.MUTED, "Small", true))
	var tools := UIKit.hbox(8)
	var auto := UIKit.button("Escalação automática", "GhostButton", func():
		club.sheet = ClubAI.auto_sheet(w, club, sheet.formation)
		UIManager.toast("Melhores disponíveis escalados.")
		refresh(), "bolt")
	auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(auto)
	var rest := UIKit.button("Poupar cansados", "GhostButton", func():
		var msgs := SquadManager.rest_tired(w, club, sheet)
		if msgs.is_empty():
			UIManager.toast("Ninguém cansado com substituto à altura.")
		else:
			_notes = msgs
			UIManager.toast("%d titular(es) poupado(s)." % msgs.size())
		refresh(), "heart")
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rest)
	c.add_child(tools)
	var pe := CheckButton.new()
	pe.text = "Editar posições no campo (formação personalizada)"
	pe.button_pressed = _pos_edit
	pe.toggled.connect(func(v):
		_pos_edit = v
		refresh())
	c.add_child(pe)
	# Formação
	var base := DatabaseManager.formation_base(sheet.formation)
	var custom := sheet.formation.begins_with("C:")
	c.add_child(UIKit.section("Formação" + (" · variação do %s" % base if custom else "")))
	var gf := ButtonGroup.new()
	var fl := UIKit.flow(8)
	for fname in DatabaseManager.formation_names():
		var fn: String = fname
		fl.add_child(UIKit.chip(fn + ("*" if custom and fn == base else ""), fn == base, gf, func(): _set_formation(fn)))
	c.add_child(fl)
	c.add_child(UIKit.label(String(DatabaseManager.formation(sheet.formation)["desc"]), "Small", true))
	if custom:
		var ov := DatabaseManager.formation_overrides(sheet.formation)
		var base_slots: Array = DatabaseManager.formation(base)["slots"]
		var changes: Array = []
		for k in ov:
			changes.append("%s → %s" % [Pos.code(int(base_slots[int(k)]["pos"])), Pos.code(DatabaseManager.POS_BY_CODE[ov[k]])])
		c.add_child(UIKit.label("Mudanças: %s" % ", ".join(PackedStringArray(changes)), "Small", true))
		c.add_child(UIKit.button("Voltar ao %s original" % base, "GhostButton", func(): _set_formation(base), "back"))
	c.add_child(_fam_row("Entrosamento com o %s" % base, TacticsManager.formation_fam(club, sheet.formation)))
	# Mentalidade
	var tac := DatabaseManager.tactics()
	c.add_child(UIKit.section("Mentalidade"))
	var gm := ButtonGroup.new()
	var ml := UIKit.flow(8)
	for i in 5:
		var idx := i
		ml.add_child(UIKit.chip(String(tac["mentalities"][i]["name"]), i == sheet.mentality, gm, func():
			sheet.mentality = idx
			refresh()))
	c.add_child(ml)
	c.add_child(UIKit.label(String(tac["mentalities"][sheet.mentality]["desc"]), "Small", true))
	# Estilo
	c.add_child(UIKit.section("Estilo de jogo"))
	var gs := ButtonGroup.new()
	var sl := UIKit.flow(8)
	for i in 6:
		var idx := i
		sl.add_child(UIKit.chip(String(tac["styles"][i]["short"]), i == sheet.style, gs, func():
			sheet.style = idx
			refresh()))
	c.add_child(sl)
	var st: Dictionary = tac["styles"][sheet.style]
	c.add_child(UIKit.label(String(st["desc"]), "Small", true))
	c.add_child(_style_fit_label(w, sheet, st))
	c.add_child(_fam_row("Entrosamento com o estilo", TacticsManager.style_fam(club, sheet.style)))
	if TacticsManager.sheet_fam(club, sheet) < 45.0:
		c.add_child(UIKit.colored("Pouco entrosamento com esta ideia de jogo: o time rende menos.", UIColors.ORANGE, "Small", true))
	# Ajustes finos
	var more := UIKit.button(("▼ " if _extras_open else "▶ ") + "Mais ajustes: intensidade, linha, pressão", "GhostButton", func():
		_extras_open = not _extras_open
		refresh())
	more.text = ("Esconder" if _extras_open else "Mostrar") + " ajustes: intensidade, linha, pressão"
	c.add_child(more)
	if _extras_open:
		_segment(c, "Intensidade", tac["intensity"], sheet.intensity, func(i): sheet.intensity = i)
		_segment(c, "Linha defensiva", tac["line"], sheet.line, func(i): sheet.line = i)
		_segment(c, "Pressão", tac["pressing"], sheet.pressing, func(i): sheet.pressing = i)
		var wdesc := ["Time compacto por dentro: fecha o meio e ataca menos pelos lados.", "Largura da formação escolhida.", "Campo aberto: mais jogadas pelas pontas, cruzamentos e escanteios; deixa espaços por dentro."]
		var wopts: Array = []
		for wi in TeamSheet.WIDTH_NAMES.size():
			wopts.append({"name": TeamSheet.WIDTH_NAMES[wi], "desc": wdesc[wi]})
		_segment(c, "Largura", wopts, sheet.width, func(i): sheet.width = i)
		var auto_subs := CheckButton.new()
		auto_subs.text = "Assistente faz substituições por cansaço e lesão"
		auto_subs.button_pressed = sheet.auto_subs
		auto_subs.toggled.connect(func(v): sheet.auto_subs = v)
		c.add_child(auto_subs)
	_plan_section(c, sheet)
	_instructions_section(c, w, sheet)
	# Bola parada
	c.add_child(UIKit.section("Capitão e bola parada"))
	for item in [["Capitão", "captain"], ["Pênaltis", "penalty_taker"], ["Faltas", "freekick_taker"], ["Escanteios", "corner_taker"]]:
		c.add_child(_taker_row(w, sheet, item[0], item[1]))
	# Banco
	c.add_child(UIKit.section("Banco de reservas (%d)" % sheet.bench.size()))
	for i in sheet.bench.size():
		var p := w.player(sheet.bench[i])
		if p == null:
			continue
		var bi := i
		c.add_child(PlayerRowView.make(w, p, {"mode": "pick"}, func(): _pick_for_bench(bi)))
	_build_footer(w)


func _opponent_card(w: GameWorld, f: Fixture) -> Control:
	var club := w.user_club()
	var opp := w.club(f.opponent_of(club.id))
	var league := w.league_of(club.id)
	var card := UIKit.card("Card", 6)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.crest(opp, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(("vs " if f.home == club.id else "@ ") + opp.short_name, "H2"))
	var pos := CompetitionManager.position_of(league, opp.id)
	col.add_child(UIKit.label("%dº colocado · força %d · %s" % [pos, int(round(ClubAI._compute_strength(w, opp))), opp.arch().get("tag", "")], "Small"))
	row.add_child(col)
	var fd := FormDots.new()
	fd.dot = 18
	fd.form = league.table[opp.id]["form"]
	row.add_child(fd)
	card.add_child(row)
	if MatchEngine.is_derby(w, f.home, f.away):
		card.add_child(UIKit.colored("CLÁSSICO: jogadores de jogos grandes crescem; os tímidos sentem.", UIColors.RED, "Small"))
	card.add_child(RivalryView.summary(w, club.id, opp.id))
	var opp_sheet := opp.sheet
	if opp_sheet != null:
		var tac := DatabaseManager.tactics()
		card.add_child(UIKit.label("Costuma jogar no %s, %s." % [opp_sheet.formation, String(tac["styles"][opp_sheet.style]["name"]).to_lower()], "Small"))
	card.add_child(UIKit.label("Filosofia: " + ClubPhilosophy.summary(opp), "Small", true))
	var h2h := FootballMemory.head_to_head(w, club.id, opp.id)
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


## Leitura do auxiliar: sugestão de mentalidade e estilo contra o próximo rival.
func _assistant_card(w: GameWorld, f: Fixture) -> Control:
	var club := w.user_club()
	var opp := w.club(f.opponent_of(club.id))
	var sug := TacticsManager.suggest(w, club, opp, f.home == club.id)
	var tac := DatabaseManager.tactics()
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.label("Leitura do auxiliar", "Caps"))
	for r in sug["reasons"]:
		card.add_child(UIKit.label("• " + String(r), "Small", true))
	var m: int = sug["mentality"]
	var st: int = sug["style"]
	var sheet := _sheet()
	if m == sheet.mentality and st == sheet.style:
		card.add_child(UIKit.colored("Sua tática já segue essa ideia.", UIColors.GREEN, "Small"))
	else:
		card.add_child(UIKit.button("Aplicar: %s, %s" % [String(tac["mentalities"][m]["name"]), String(tac["styles"][st]["short"]).to_lower()], "GhostButton", func():
			sheet.mentality = m
			sheet.style = st
			UIManager.toast("Sugestão do auxiliar aplicada.")
			refresh(), "tactics"))
	return UIKit.card_panel(card)


## Plano de jogo: o que fazer sozinho a partir de certo minuto conforme o placar.
func _plan_section(c: VBoxContainer, sheet: TeamSheet) -> void:
	var tac := DatabaseManager.tactics()
	c.add_child(UIKit.section("Plano de jogo"))
	c.add_child(UIKit.label("O time muda a mentalidade sozinho conforme o placar. Empatando, volta ao que você escolheu.", "Small", true))
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
	var txt := "Seu elenco se encaixa bem neste estilo." if diff >= 2.0 else ("Encaixe razoável com o seu elenco." if diff >= -2.0 else "Seu elenco não tem o perfil ideal para este estilo.")
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
	c.add_child(UIKit.label(String(options[current]["desc"]), "Small", true))


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
	var chips: Array = []
	for i in slots.size():
		var pid: int = sheet.starters[i] if i < sheet.starters.size() and sheet.starters[i] != null else -1
		var p := w.player(pid)
		var s: Dictionary = slots[i]
		var ch := {"x": s["x"], "y": s["y"], "number": p.shirt if p != null else "?", "name": p.short_name() if p != null else "vazio",
			"rating": int(round(p.rating_at(s["pos"]))) if p != null else 0}
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
		var nl := UIKit.label(p.display_name(), "")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nl)
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
	v.add_child(UIKit.button("Padrão da função", "GhostButton", func():
		sheet.instr.erase(pid)
		UIManager.close_modal()
		refresh()))
	for k in TeamSheet.INSTRUCTION_ORDER:
		var key: String = k
		var d: Dictionary = TeamSheet.INSTRUCTIONS[key]
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	v.add_child(UIKit.label("O time leva um tempo para se acostumar: cada vaga mudada custa um pouco de entrosamento.", "Small", true))
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
	v.add_child(UIKit.label("Ordenado por rendimento nesta posição.", "Small"))
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
			box.add_child(UIKit.label(tag.to_upper(), "Caps"))
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
		UIManager.toast("%s está %s." % [p.display_name(), "lesionado" if p.is_injured() else "suspenso"], UIColors.RED)
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
	if _edit:
		f.add_child(UIKit.button("SALVAR ESCALAÇÃO", "PrimaryButton", func():
			GameManager.save_now()
			UIManager.toast("Escalação salva.")
			UIManager.back(), "check"))
		return
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for i in 3:
		var idx := i
		var chip := UIKit.chip(AppSettings.SPEED_NAMES[i], i == AppSettings.match_speed, g, func():
			AppSettings.match_speed = idx
			AppSettings.save_settings())
		UIKit.shrink_button(chip)
		row.add_child(chip)
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
	AudioManager.play("whistle", -4.0)
	if AppSettings.match_speed == AppSettings.SPEED_INSTANT:
		var report := GameManager.play_instant()
		UIManager.replace("results", {"report": report})
	else:
		GameManager.begin_match()
		UIManager.replace("match")
