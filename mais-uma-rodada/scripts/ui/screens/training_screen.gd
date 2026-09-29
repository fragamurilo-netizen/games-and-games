extends BaseScreen
## Treino: plano da semana (foco, intensidade, preparação para o jogo e qualidade do treino),
## treino individual de cada jogador e a evolução do elenco nas últimas semanas.


func _init() -> void:
	screen_title = "Treino"


const FOCUS_ICONS := {"equilibrado": "list", "fisico": "bolt", "tecnico": "ball", "tatico": "tactics",
	"ataque": "up", "defesa": "shield", "recuperacao": "heart"}
const TABS := [["semana", "Semana"], ["jogadores", "Jogadores"], ["evolucao", "Evolução"]]
const GROUP_NAMES := ["Goleiros", "Defensores", "Meio-campistas", "Atacantes"]

var _tab := "semana"


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
	var f := TrainingManager.focus_of(club)
	var it := TrainingManager.intensity_of(club)
	var q := TrainingManager.quality(w, club)
	c.add_child(UIKit.stat_grid([
		UIKit.stat_tile(String(f["name"]), "Foco da semana", UIColors.ACCENT),
		UIKit.stat_tile(String(it["name"]), "Intensidade"),
		UIKit.stat_tile(str(int(round(q * 100.0))), "Qualidade do treino", UIColors.morale_color(q * 100.0)),
		UIKit.stat_tile(str(int(club.cohesion)), "Entrosamento", UIColors.morale_color(club.cohesion)),
	], content_width()))
	c.add_child(UIKit.tabs(TABS, _tab, func(k: String):
		_tab = k
		refresh()
		scroll_to_top()))
	var start := c.get_child_count()
	match _tab:
		"jogadores":
			c.add_child(_players_card(w, club))
		"evolucao":
			for card in _evolution_cards(w, club):
				c.add_child(card)
			columnize(c, start, 2, 0)
		_:
			c.add_child(_balance_card(w, club))
			c.add_child(_focus_card(club))
			c.add_child(_intensity_card(club))
			c.add_child(_prep_card(w, club))
			c.add_child(_quality_card(w, club))
			columnize(c, start, 2, 0)


func _pct(v: Variant) -> int:
	return int(round((float(v) - 1.0) * 100.0))


## Balanço da semana: foco × intensidade × preparação, no que o técnico precisa decidir.
func _balance_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	card.add_child(UIKit.section_header("Balanço da semana"))
	var f := TrainingManager.focus_of(club)
	var it := TrainingManager.intensity_of(club)
	var pr := TrainingManager.prep_of(club)
	var growth := float(f["growth"]) * float(it["growth"]) * float(pr["growth"])
	var rec := float(f["recovery"]) * float(it["recovery"])
	var inj := float(f["injury"]) * float(it["injury"])
	card.add_child(_meter("Evolução", growth, true))
	card.add_child(_meter("Recuperação física", rec, true))
	card.add_child(_meter("Risco de lesão", inj, false))
	var flags := UIKit.flow(8)
	if inj * People.injury_mult(w) > 0.95:
		flags.add_child(UIKit.pill("CARGA ALTA", UIColors.ORANGE, 15))
	var tired := 0
	for p: Player in w.squad(club):
		if not p.is_injured() and p.condition < 70.0:
			tired += 1
	if tired >= 4 and rec < 1.0:
		flags.add_child(UIKit.pill("%d CANSADOS" % tired, UIColors.ORANGE, 15))
	if flags.get_child_count() > 0:
		card.add_child(flags)
	else:
		flags.free()
	return UIKit.card_panel(card)


## Barra centrada em "normal" (1,0): verde quando ajuda, vermelha quando atrapalha.
func _meter(title: String, v: float, higher_good: bool) -> Control:
	var box := UIKit.vbox(2)
	var d := int(round((v - 1.0) * 100.0))
	var good := (d > 0) == higher_good
	var col := UIColors.MUTED if d == 0 else (UIColors.GREEN if good else UIColors.RED)
	var row := UIKit.hbox(8)
	var t := UIKit.label(title, "Small")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(UIKit.colored("Normal" if d == 0 else "%+d%%" % d, col, "H3"))
	box.add_child(row)
	box.add_child(UIKit.bar(clampf(v, 0.4, 1.6) - 0.4, 1.2, col, 8))
	return box


func _focus_card(club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section_header("Foco coletivo"))
	var cur := String(club.training.get("focus", "equilibrado"))
	var items: Array = []
	for key in TrainingManager.FOCUS_ORDER:
		var k: String = key
		items.append([k, String(TrainingManager.TEAM_FOCUS[k]["name"]), "", String(FOCUS_ICONS.get(k, "list"))])
	card.add_child(UIKit.option_grid(items, cur, func(k: String):
		club.training["focus"] = k
		refresh(), 2))
	var f := TrainingManager.focus_of(club)
	var detail := UIKit.card("CardInset", 8)
	if not Array(f["attrs"]).is_empty():
		var names: Array = []
		for a in f["attrs"]:
			names.append(Attr.NAMES[int(a)])
		detail.add_child(UIKit.label(tr("Prioriza: %s") % ", ".join(names), "Small", true))
	var fx := UIKit.effect_pills([["Evolução", _pct(f["growth"]), true], ["Recuperação", _pct(f["recovery"]), true], ["Risco de lesão", _pct(f["injury"]), false]])
	if fx.get_child_count() > 0:
		detail.add_child(fx)
	else:
		fx.free()
	if float(f["cohesion"]) > 0.0:
		detail.add_child(UIKit.pill("Entrosamento sobe mais rápido", UIColors.GREEN, 16))
	if detail.get_child_count() > 0:
		card.add_child(UIKit.card_panel(detail))
	else:
		detail.free()
	return UIKit.card_panel(card)


func _intensity_card(club: Club) -> Control:
	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section_header("Intensidade"))
	var cur := int(club.training.get("int", 1))
	var items: Array = []
	for i in TrainingManager.INTENSITY.size():
		items.append([str(i), String(TrainingManager.INTENSITY[i]["name"])])
	card.add_child(UIKit.segment(items, str(cur), func(k: String):
		club.training["int"] = int(k)
		refresh()))
	var it: Dictionary = TrainingManager.INTENSITY[cur]
	card.add_child(UIKit.effect_pills([["Evolução", _pct(it["growth"]), true], ["Recuperação", _pct(it["recovery"]), true], ["Risco de lesão", _pct(it["injury"]), false]]))
	if float(it["morale"]) != 0.0:
		card.add_child(UIKit.colored("Elenco gosta" if float(it["morale"]) > 0.0 else "Elenco reclama", UIColors.GREEN if float(it["morale"]) > 0.0 else UIColors.ORANGE, "Small"))
	return UIKit.card_panel(card)


func _prep_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section_header("Preparação para o jogo"))
	var cur := String(club.training.get("prep", ""))
	var items: Array = []
	for k in TrainingManager.PREP_ORDER:
		items.append([k if k != "" else "-", String(TrainingManager.PREP[k]["name"])])
	card.add_child(UIKit.segment(items, cur if cur != "" else "-", func(k: String):
		if k == "-":
			club.training.erase("prep")
		else:
			club.training["prep"] = k
		refresh()))
	var pr := TrainingManager.prep_of(club)
	var pills: Array = [["Evolução", _pct(pr["growth"]), true]]
	var sp := TrainingManager.set_piece_bonus(w, club)
	if sp > 0.0:
		pills.append(["Perigo na bola parada", int(round(sp * 100.0)), true])
	var st := TrainingManager.study_bonus(w, club)
	if st > 0.0:
		pills.append(["Leitura do rival", int(round(st * 100.0)), true])
	card.add_child(UIKit.effect_pills(pills))
	return UIKit.card_panel(card)


func _quality_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Qualidade do treino"))
	for pt in TrainingManager.quality_parts(w, club):
		var v := float(pt[1]) * 100.0
		var row := UIKit.hbox(8)
		var n := UIKit.label(String(pt[0]), "Small")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		row.add_child(UIKit.colored(str(int(round(v))), UIColors.morale_color(v), "H3"))
		card.add_child(row)
		card.add_child(UIKit.bar(v, 100.0, UIColors.morale_color(v), 8))
	var lm := TrainingManager.learn_mult(w, club)
	var d := _pct(lm)
	if absi(d) >= 2:
		card.add_child(UIKit.effect_pills([["Aprendizado", d, true]]))
	return UIKit.card_panel(card)


func _players_card(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("Treino individual"))
	var squad := w.squad(club)
	squad.sort_custom(func(a: Player, b: Player): return a.position < b.position if a.position != b.position else a.overall > b.overall)
	var last_group := -1
	for p: Player in squad:
		if Pos.group(p.position) != last_group:
			last_group = Pos.group(p.position)
			card.add_child(UIKit.eyebrow(GROUP_NAMES[clampi(last_group, 0, 3)], Pos.group_color(p.position)))
		card.add_child(_player_row(w, p))
	return UIKit.card_panel(card)


func _player_row(w: GameWorld, p: Player, plain: bool = false) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.pos_badge(p.position))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UIKit.label(p.display_name(), "H3")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nl)
	var bits: Array = []
	var fk := String(p.train.get("f", ""))
	if TrainingManager.PLAYER_FOCUS.has(fk) and fk != "":
		bits.append(String(TrainingManager.PLAYER_FOCUS[fk]["name"]))
	var ld := int(p.train.get("ld", 1))
	if ld != 1:
		bits.append(String(TrainingManager.LOAD[ld]["name"]).to_lower())
	var st := String(p.train.get("st", ""))
	if st != "":
		bits.append("%s %d%%" % [String(PlayStyle.find(p, st).get("n", "")), int(TrainingManager.style_progress(p) * 100.0)])
	var lp := int(p.train.get("pos", -1))
	if lp >= 0:
		bits.append("%s %d%%" % [Pos.code(lp), int(float(p.train.get("prog", 0.0)) * 100.0)])
	var active := not bits.is_empty() and not plain
	if plain:
		bits = ["%d anos" % p.age(w.year), PlayStyle.of(p)]
	elif not active:
		bits.append("Treino do grupo")
	var sub := UIKit.colored(" · ".join(bits), UIColors.ACCENT if active else UIColors.MUTED, "Small")
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(sub)
	row.add_child(col)
	if p.is_injured():
		var inj := UIKit.pill("LESÃO", UIColors.RED, 14)
		inj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(inj)
	row.add_child(TrainingSheet.trend_label(TrainingManager.trend(p)))
	row.add_child(UIKit.badge(p.overall, 52, 38, 22))
	var pp := p
	return UIKit.tap_row(row, func(): TrainingSheet.open(pp, func(): refresh()))


## Quem está crescendo, quem está caindo e as últimas mudanças de atributo do elenco.
func _evolution_cards(w: GameWorld, club: Club) -> Array:
	var squad := w.squad(club)
	var with_hist: Array = []
	for p: Player in squad:
		if Array(p.train.get("oh", [])).size() >= 2:
			with_hist.append(p)
	if with_hist.is_empty():
		return [UIKit.empty_state("up", "Sem histórico ainda", "")]
	var weeks := 0
	for p: Player in with_hist:
		weeks = maxi(weeks, Array(p.train.get("oh", [])).size() - 1)
	with_hist.sort_custom(func(a: Player, b: Player): return TrainingManager.trend(a) > TrainingManager.trend(b))
	var up: Array = []
	var down: Array = []
	for p: Player in with_hist:
		var t := TrainingManager.trend(p)
		if t >= 0.1 and up.size() < 6:
			up.append(p)
	for i in range(with_hist.size() - 1, -1, -1):
		var p: Player = with_hist[i]
		if TrainingManager.trend(p) <= -0.1 and down.size() < 5:
			down.append(p)
	var out: Array = []
	out.append(_trend_card("Em alta", "Últimas %d semana(s)" % weeks, up, "Ninguém."))
	out.append(_trend_card("Em queda", "", down, "Ninguém."))
	# Últimas mudanças de atributo no elenco
	var all_ch: Array = []
	for p: Player in squad:
		for ch in TrainingManager.recent_changes(p):
			all_ch.append([int(ch[0]), p, int(ch[1]), int(ch[2])])
	all_ch.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("Últimas mudanças"))
	if all_ch.is_empty():
		card.add_child(UIKit.label("Nenhum atributo mudou ainda.", "Muted"))
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
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(p.position))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3"))
		col.add_child(TrainingSheet.change_pills(by_player[p.id], 6))
		row.add_child(col)
		var pp := p
		card.add_child(UIKit.tap_row(row, func(): TrainingSheet.open(pp, func(): refresh())))
	out.append(UIKit.card_panel(card))
	return out


func _trend_card(title: String, sub: String, list: Array, empty: String) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header(title))
	if sub != "":
		card.add_child(UIKit.label(sub, "Small", true))
	if list.is_empty():
		card.add_child(UIKit.label(empty, "Muted"))
	for p: Player in list:
		card.add_child(_player_row(world(), p, true))
	return UIKit.card_panel(card)
