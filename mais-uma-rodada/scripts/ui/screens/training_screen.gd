extends BaseScreen
## Treino: plano da semana (foco, intensidade, preparação para o jogo e qualidade do treino),
## treino individual de cada jogador e a evolução do elenco nas últimas semanas.
## Segue o padrão da Tática (DESIGN.md): o plano são linhas de escolha que abrem folhas de
## opções; os jogadores ficam na mesma tabela do elenco.


func _init() -> void:
	screen_title = "Treino"


const TABS := [["semana", "Semana"], ["jogadores", "Jogadores"], ["evolucao", "Evolução"]]

var _tab := "semana"
var _state := {}


func setup(p: Dictionary) -> void:
	super.setup(p)
	if p.has("tab"):
		_tab = String(p["tab"])


func refresh() -> void:
	var w := world()
	if w == null:
		return
	max_content_width = 1700
	var club := w.user_club()
	screen_subtitle = "Semana de treino"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_header(w, club))
	c.add_child(UIKit.tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()
		scroll_to_top()))
	var start := c.get_child_count()
	match _tab:
		"jogadores":
			c.add_child(_players(w, club))
		"evolucao":
			for block in _evolution(w, club):
				c.add_child(block)
			columnize(c, start, 2, 0)
		_:
			c.add_child(_plan_card(w, club))
			c.add_child(_effect_card(w, club))
			c.add_child(_quality_card(w, club))
			columnize(c, start, 2, 0)


## Resumo em frase: o que o time está treinando e quanto o treino rende.
func _header(w: GameWorld, club: Club) -> Control:
	var f := TrainingManager.focus_of(club)
	var it := TrainingManager.intensity_of(club)
	var pr := TrainingManager.prep_of(club)
	var q := int(round(TrainingManager.quality(w, club) * 100.0))
	var prep := "sem preparação específica" if String(club.training.get("prep", "")) == "" else "preparação: %s" % String(pr["name"]).to_lower()
	var txt := "Foco %s, intensidade %s, %s. O treino rende %d de 100 e o entrosamento está em %d." % [
		String(f["name"]).to_lower(), String(it["name"]).to_lower(), prep, q, int(club.cohesion)]
	return UIKit.label(txt, "Muted", true)


func _pct(v: Variant) -> int:
	return int(round((float(v) - 1.0) * 100.0))


## "Evolução +15%, recuperação −12%, risco de lesão +40%": só o que muda.
func _fx_text(growth: Variant, recovery: Variant, injury: Variant) -> String:
	var bits: Array = []
	for e in [["Evolução", growth], ["recuperação", recovery], ["risco de lesão", injury]]:
		var d := _pct(e[1])
		if d != 0:
			bits.append("%s %+d%%" % [e[0], d])
	if bits.is_empty():
		return "Sem efeito em evolução, recuperação ou lesões."
	var s: String = ", ".join(bits)
	return s.substr(0, 1).to_upper() + s.substr(1) + "."


# --- Semana -------------------------------------------------------------------------------------

func _plan_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 0)
	card.add_child(UIKit.label("Plano da semana", "Section"))
	card.add_child(UIKit.gap(UITokens.S1))
	var f := TrainingManager.focus_of(club)
	var it := TrainingManager.intensity_of(club)
	var pr := TrainingManager.prep_of(club)
	card.add_child(_picker_row("Foco", String(f["name"]), func(): _focus_sheet(club)))
	card.add_child(_picker_row("Intensidade", String(it["name"]), func(): _intensity_sheet(club)))
	card.add_child(_picker_row("Preparação", String(pr["name"]), func(): _prep_sheet(club)))
	var detail := String(f["desc"])
	if not Array(f["attrs"]).is_empty():
		var names: Array = []
		for a in f["attrs"]:
			names.append(Attr.NAMES[int(a)])
		detail += " " + tr("Prioriza: %s") % ", ".join(names) + "."
	card.add_child(UIKit.gap(UITokens.S2))
	card.add_child(UIKit.label(detail, "Muted", true))
	return UIKit.card_panel(card)


func _picker_row(title: String, value: String, cb: Callable) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var t := UIKit.label(title, "Muted")
	t.custom_minimum_size.x = 170
	h.add_child(t)
	var v := UIKit.label(value)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(v)
	h.add_child(UIKit.icon_rect("forward", 20, UIColors.DIM))
	var row := UIKit.tap_row(h, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


## Folha de opções: uma linha por opção, a atual marcada; escolher fecha e aplica.
func _option_sheet(title: String, items: Array, current: int, pick: Callable) -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(title, "H2"))
	v.add_child(UIKit.gap(UITokens.S1))
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


func _focus_sheet(club: Club) -> void:
	var items: Array = []
	var cur := 0
	for i in TrainingManager.FOCUS_ORDER.size():
		var k: String = TrainingManager.FOCUS_ORDER[i]
		var f: Dictionary = TrainingManager.TEAM_FOCUS[k]
		if k == String(club.training.get("focus", "equilibrado")):
			cur = i
		var sub := String(f["desc"])
		var fx := _fx_text(f["growth"], f["recovery"], f["injury"])
		if not fx.begins_with("Sem efeito"):
			sub += " " + fx
		if float(f["cohesion"]) > 0.0:
			sub += " Entrosamento sobe mais rápido."
		items.append([String(f["name"]), sub])
	_option_sheet("Foco coletivo", items, cur, func(i: int):
		club.training["focus"] = TrainingManager.FOCUS_ORDER[i])


func _intensity_sheet(club: Club) -> void:
	var items: Array = []
	for it: Dictionary in TrainingManager.INTENSITY:
		var sub := _fx_text(it["growth"], it["recovery"], it["injury"])
		if float(it["morale"]) != 0.0:
			sub += " O elenco gosta." if float(it["morale"]) > 0.0 else " O elenco reclama."
		items.append([String(it["name"]), sub])
	_option_sheet("Intensidade", items, int(club.training.get("int", 1)), func(i: int):
		club.training["int"] = i)


func _prep_sheet(club: Club) -> void:
	var items: Array = []
	var cur := 0
	for i in TrainingManager.PREP_ORDER.size():
		var k: String = TrainingManager.PREP_ORDER[i]
		if k == String(club.training.get("prep", "")):
			cur = i
		var pr: Dictionary = TrainingManager.PREP[k]
		var sub := String(pr["desc"])
		if _pct(pr["growth"]) != 0:
			sub += " Evolução %+d%%." % _pct(pr["growth"])
		items.append([String(pr["name"]), sub])
	_option_sheet("Preparação para o jogo", items, cur, func(i: int):
		var k: String = TrainingManager.PREP_ORDER[i]
		if k == "":
			club.training.erase("prep")
		else:
			club.training["prep"] = k)


## Efeito da semana: foco × intensidade × preparação, numa faixa de números.
func _effect_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", UITokens.S2)
	card.add_child(UIKit.label("Efeito na semana", "Section"))
	var f := TrainingManager.focus_of(club)
	var it := TrainingManager.intensity_of(club)
	var pr := TrainingManager.prep_of(club)
	var growth := float(f["growth"]) * float(it["growth"]) * float(pr["growth"])
	var rec := float(f["recovery"]) * float(it["recovery"])
	var inj := float(f["injury"]) * float(it["injury"])
	card.add_child(StatStrip.make([_fx_item("Evolução", growth, true), _fx_item("Recuperação", rec, true), _fx_item("Risco de lesão", inj, false)]))
	var notes: Array = []
	if inj * People.injury_mult(w) > 0.95:
		notes.append([tr("Carga alta: o risco de lesão está acima do normal."), UIColors.ORANGE])
	var tired := 0
	for p: Player in w.squad(club):
		if not p.is_injured() and p.condition < 70.0:
			tired += 1
	if tired >= 4 and rec < 1.0:
		notes.append([tr("%d jogadores cansados e a semana recupera pouco.") % tired, UIColors.ORANGE])
	if float(it["morale"]) != 0.0:
		notes.append(["O elenco gosta da carga leve." if float(it["morale"]) > 0.0 else "O elenco reclama da carga intensa.",
			UIColors.GREEN if float(it["morale"]) > 0.0 else UIColors.ORANGE])
	var sp := TrainingManager.set_piece_bonus(w, club)
	if sp > 0.0:
		notes.append([tr("Bola parada mais perigosa: +%d%%.") % int(round(sp * 100.0)), UIColors.MUTED])
	var st := TrainingManager.study_bonus(w, club)
	if st > 0.0:
		notes.append([tr("Leitura do próximo rival: +%d%%.") % int(round(st * 100.0)), UIColors.MUTED])
	for n in notes:
		card.add_child(UIKit.colored(String(n[0]), n[1], "Small"))
	return UIKit.card_panel(card)


func _fx_item(label: String, v: float, higher_good: bool) -> Array:
	var d := int(round((v - 1.0) * 100.0))
	var good := (d > 0) == higher_good
	var col := UIColors.MUTED if d == 0 else (UIColors.GREEN if good else UIColors.RED)
	return [label, "Normal" if d == 0 else "%+d%%" % d, col]


func _quality_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(UITokens.S2)
	var t := UIKit.label("Qualidade do treino", "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var q := TrainingManager.quality(w, club) * 100.0
	head.add_child(UIKit.colored(str(int(round(q))), UIColors.morale_color(q), "Section"))
	card.add_child(head)
	for pt in TrainingManager.quality_parts(w, club):
		var v := float(pt[1]) * 100.0
		var row := UIKit.hbox(UITokens.S2)
		var n := UIKit.label(String(pt[0]), "Small")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UIKit.colored(str(int(round(v))), UIColors.morale_color(v), "H3"))
		card.add_child(row)
		card.add_child(UIKit.bar(v, 100.0, UIColors.morale_color(v), 6))
	var d := _pct(TrainingManager.learn_mult(w, club))
	if absi(d) >= 2:
		card.add_child(UIKit.gap(UITokens.S1))
		card.add_child(UIKit.colored(tr("Aprendizado %+d%% por causa da comissão.") % d, UIColors.GREEN if d > 0 else UIColors.ORANGE, "Small"))
	return UIKit.card_panel(card)


# --- Jogadores ----------------------------------------------------------------------------------

## O que o jogador treina além do grupo ("" = treino do grupo).
func _plan(p: Player) -> String:
	var bits: Array = []
	var fk := String(p.train.get("f", ""))
	if TrainingManager.PLAYER_FOCUS.has(fk) and fk != "":
		bits.append(String(TrainingManager.PLAYER_FOCUS[fk]["name"]))
	var ld := int(p.train.get("ld", 1))
	if ld != 1:
		bits.append(String(TrainingManager.LOAD[ld]["name"]).to_lower() if not bits.is_empty() else String(TrainingManager.LOAD[ld]["name"]))
	var st := String(p.train.get("st", ""))
	if st != "":
		bits.append("%s %d%%" % [String(PlayStyle.find(p, st).get("n", "")), int(TrainingManager.style_progress(p) * 100.0)])
	var lp := int(p.train.get("pos", -1))
	if lp >= 0:
		bits.append("%s %d%%" % [Pos.code(lp), int(float(p.train.get("prog", 0.0)) * 100.0)])
	return ", ".join(bits)


## Celular: só o plano ao lado do overall (o nome precisa do espaço). Com espaço, a tendência.
func _trend_col() -> Dictionary:
	return {"key": "trend", "title": "Evolução", "w": 126, "tip": "Tendência nas últimas semanas",
		"sort": func(p: Player) -> float: return TrainingManager.trend(p),
		"cell": func(p: Player) -> Control: return TrainingSheet.trend_label(TrainingManager.trend(p))}


func _train_cols(_w: GameWorld) -> Array:
	var wide := content_width() >= 760.0
	var plan := [
		{"key": "plan", "title": "Treino", "w": 150 if not wide else 260, "align": "l", "first": "asc",
			"text": func(p: Player) -> String:
				var s := _plan(p)
				return s if s != "" else "Grupo",
			"sort": func(p: Player) -> String: return _plan(p) if _plan(p) != "" else "~",
			"color": func(p: Player) -> Color: return UIColors.TEXT if _plan(p) != "" else UIColors.DIM},
	]
	return [_trend_col()] + plan if wide else plan


func _players(w: GameWorld, club: Club) -> Control:
	var v := UIKit.vbox(UITokens.S1)
	var squad := w.squad(club)
	var active := 0
	for p: Player in squad:
		if _plan(p) != "":
			active += 1
	var txt := "Todos treinam com o grupo." if active == 0 else ("%d jogador com treino individual." % active if active == 1 else "%d jogadores com treino individual." % active)
	v.add_child(UIKit.label(txt + " Toque num jogador para definir foco, carga, posição ou estilo.", "Muted", true))
	v.add_child(PlayerTable.make(w, squad, "squad", _state, func(p: Player):
		TrainingSheet.open(p, func(): refresh()), _train_cols(w), "treino", content_width() >= 760.0))
	return v


# --- Evolução -----------------------------------------------------------------------------------

## Quem está crescendo, quem está caindo e as últimas mudanças de atributo do elenco.
func _evolution(w: GameWorld, club: Club) -> Array:
	var squad := w.squad(club)
	var with_hist: Array = []
	for p: Player in squad:
		if Array(p.train.get("oh", [])).size() >= 2:
			with_hist.append(p)
	if with_hist.is_empty():
		return [UIKit.empty_state("up", "Sem histórico ainda", "A evolução aparece depois de duas semanas de treino: quem cresce, quem cai e cada atributo que mudou.")]
	var weeks := 0
	for p: Player in with_hist:
		weeks = maxi(weeks, Array(p.train.get("oh", [])).size() - 1)
	with_hist.sort_custom(func(a: Player, b: Player): return TrainingManager.trend(a) > TrainingManager.trend(b))
	var up: Array = []
	var down: Array = []
	for p: Player in with_hist:
		if TrainingManager.trend(p) >= 0.1 and up.size() < 6:
			up.append(p)
	for i in range(with_hist.size() - 1, -1, -1):
		var p: Player = with_hist[i]
		if TrainingManager.trend(p) <= -0.1 and down.size() < 5:
			down.append(p)
	var out: Array = []
	out.append(_trend_block(w, "Em alta", tr("Últimas %d semana(s)") % weeks, up, "Ninguém subiu de forma clara."))
	out.append(_trend_block(w, "Em queda", "", down, "Ninguém caiu."))
	out.append(_changes_block(w, squad))
	return out


func _trend_block(w: GameWorld, title: String, sub: String, list: Array, empty: String) -> Control:
	var v := UIKit.vbox(UITokens.S1)
	var head := UIKit.hbox(UITokens.S2)
	head.add_child(UIKit.label(title, "Section"))
	if sub != "":
		var s := UIKit.label(sub, "Muted")
		s.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(s)
	v.add_child(head)
	if list.is_empty():
		v.add_child(UIKit.label(empty, "Muted"))
		return v
	var st := {"sort": "trend", "desc": title == "Em alta"}
	v.add_child(PlayerTable.make(w, list, "squad", st, func(p: Player):
		TrainingSheet.open(p, func(): refresh()), [_trend_col()], "treino", false))
	return v


func _changes_block(w: GameWorld, squad: Array) -> Control:
	var all_ch: Array = []
	for p: Player in squad:
		for ch in TrainingManager.recent_changes(p):
			all_ch.append([int(ch[0]), p, int(ch[1]), int(ch[2])])
	all_ch.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var v := UIKit.vbox(UITokens.S1)
	v.add_child(UIKit.label("Últimas mudanças", "Section"))
	if all_ch.is_empty():
		v.add_child(UIKit.label("Nenhum atributo mudou ainda.", "Muted"))
		return v
	var by_player := {}
	var order: Array = []
	for e in all_ch:
		var p: Player = e[1]
		if not by_player.has(p.id):
			if order.size() >= 8:
				continue
			by_player[p.id] = []
			order.append(p)
		by_player[p.id].append([e[0], e[2], e[3]])
	for p: Player in order:
		var row := UIKit.hbox(UITokens.S2)
		row.add_child(UIKit.pos_badge(p.position))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3"))
		col.add_child(TrainingSheet.change_pills(by_player[p.id], 6))
		row.add_child(col)
		var pp := p
		v.add_child(UIKit.tap_row(row, func(): TrainingSheet.open(pp, func(): refresh())))
	return v
