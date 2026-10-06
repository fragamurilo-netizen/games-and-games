class_name TableRows
extends RefCounted
## Linhas de classificação e de rankings reutilizadas pela tabela e pelos resultados da rodada.

const COLS_COMPACT := ["J", "SG", "PTS"]
const COLS_FULL := ["J", "V", "E", "D", "SG", "PTS"]
const COLS_FORM := ["ÚLTIMOS 5", "APR", "PTS"]
## Tela larga (tablet): gols pró e contra e os últimos jogos na própria classificação.
const COLS_WIDE := ["J", "V", "E", "D", "GP", "GC", "SG", "ÚLTIMOS 5", "PTS"]
const COLS_WIDE_SIDE := ["J", "V", "E", "D", "GP", "GC", "SG", "PTS"]
## Visões da classificação: geral, só jogos em casa, só fora, e o momento (últimos 5 jogos).
const VIEW_ALL := "all"
const VIEW_HOME := "home"
const VIEW_AWAY := "away"
const VIEW_FORM := "form"
## Margem lateral das linhas (CardFlat): o cabeçalho usa a mesma para alinhar as colunas.
const ROW_PAD := 14
const W_POS := 36
const W_CREST := 30
const W_FORM := 5 * 18 + 4 * 4


static func _col_width(col: String, compact: bool) -> int:
	if compact:
		return 52
	match col:
		"SG":
			return 52
		"PTS", "APR":
			return 56
		"ÚLTIMOS 5":
			return W_FORM
	return 40


## Colunas de números de uma visão da classificação.
static func _cols(compact: bool, view: String, wide: bool) -> Array:
	if compact:
		return COLS_COMPACT
	if view == VIEW_FORM:
		return COLS_FORM
	if wide:
		return COLS_WIDE if view == VIEW_ALL else COLS_WIDE_SIDE
	return COLS_FULL


static func header(compact: bool, view: String = VIEW_ALL, wide: bool = false) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var gap := Control.new()
	# Mesma soma da linha: margem, faixa da zona, posição e escudo (com os espaçamentos).
	gap.custom_minimum_size.x = ROW_PAD + 5 + 6 + W_POS + 6 + W_CREST
	h.add_child(gap)
	var n := UIKit.label("CLUBE", "Caps")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var cols: Array = _cols(compact, view, wide)
	for col in cols:
		var l := UIKit.label(col, "Caps")
		l.custom_minimum_size.x = _col_width(col, compact)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if col == "ÚLTIMOS 5" else HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	var end := Control.new()
	end.custom_minimum_size.x = ROW_PAD - 6
	h.add_child(end)
	return h


static func row(w: GameWorld, league: League, club_id: int, pos: int, compact: bool) -> Control:
	return table_row(w, league.table[club_id], club_id, pos, compact, CompetitionManager.zone_color(CompetitionManager.zone_of(league, pos)))


## Linha de classificação a partir de uma linha de tabela (liga ou grupo de copa).
## `move`: posições ganhas (+) ou perdidas (-) desde a rodada anterior. `on_tap` troca o destino
## do toque (por padrão abre o clube).
static func table_row(w: GameWorld, r: Dictionary, club_id: int, pos: int, compact: bool, zone: Color,
		view: String = VIEW_ALL, move: int = 0, on_tap: Callable = Callable(), wide: bool = false) -> Control:
	var cl := w.club(club_id)
	var is_user := w.is_user_club(club_id)
	var h := UIKit.hbox(6)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(3, 0)
	bar.color = zone
	h.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = W_POS
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	h.add_child(UIKit.crest(cl, W_CREST))
	var n := UIKit.label(cl.short_name, "H3" if is_user else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	if is_user:
		n.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	h.add_child(n)
	if move != 0:
		var up := move > 0
		var mv := UIKit.colored(("▲" if up else "▼") + str(absi(move)), UIColors.GREEN if up else UIColors.RED, "Small")
		mv.add_theme_font_size_override(&"font_size", 16)
		h.add_child(mv)
	var pl_n := int(r["pl"])
	if view == VIEW_FORM and not compact:
		var fd := form_dots(String(r.get("form", "")), 18)
		fd.custom_minimum_size.x = W_FORM
		h.add_child(fd)
		var apr := UIKit.label(("%d%%" % roundi(100.0 * int(r["pts"]) / (3.0 * pl_n))) if pl_n > 0 else "–", "")
		apr.custom_minimum_size.x = _col_width("APR", false)
		apr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		apr.add_theme_color_override(&"font_color", UIColors.MUTED)
		h.add_child(apr)
		var pt := UIKit.label(str(r["pts"]), "H3")
		pt.custom_minimum_size.x = _col_width("PTS", false)
		pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(pt)
	else:
		var sg: int = int(r["gf"]) - int(r["ga"])
		var cols: Array = _cols(compact, view, wide)
		var by_col := {"J": r["pl"], "V": r["w"], "E": r["d"], "D": r["l"], "GP": r["gf"], "GC": r["ga"], "SG": sg, "PTS": r["pts"]}
		var values: Array = []
		for col in cols:
			values.append(by_col.get(col, 0))
		for i in values.size():
			var last := i == values.size() - 1
			if cols[i] == "ÚLTIMOS 5":
				var fdw := form_dots(String(r.get("form", "")), 18)
				fdw.custom_minimum_size.x = W_FORM
				h.add_child(fdw)
				continue
			var txt := str(values[i])
			var is_sg: bool = cols[i] == "SG"
			if is_sg:
				txt = Fmt.signed(int(values[i]))
			var l := UIKit.label(txt, "H3" if last else "")
			l.custom_minimum_size.x = _col_width(cols[i], compact)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if not last:
				l.add_theme_color_override(&"font_color", UIColors.MUTED)
			elif int(r.get("ded", 0)) > 0:
				# Pontos perdidos fora de campo (punição): número em vermelho e o desconto ao lado
				l.add_theme_color_override(&"font_color", UIColors.RED)
				l.tooltip_text = "-%d pontos de punição" % int(r["ded"])
				var dl := UIKit.colored("-%d" % int(r["ded"]), UIColors.RED, "Small")
				h.add_child(dl)
			h.add_child(l)
	var cid := club_id
	var tap := on_tap
	var row := UIKit.tap_row(h, func():
		if tap.is_valid():
			tap.call()
		elif w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "RowPanel")
	row.custom_minimum_size.y = UITokens.H_ROW
	row.tooltip_text = cl.name
	# Linha de tabela clássica: filete embaixo; o clube do usuário ganha só um fundo tingido.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UIColors.ACCENT, 0.12) if is_user else Color(0, 0, 0, 0)
	sb.border_color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
	sb.border_width_bottom = 1
	sb.content_margin_left = ROW_PAD
	sb.content_margin_right = ROW_PAD
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	row.add_theme_stylebox_override(&"panel", sb)
	for l in h.get_children():
		if l is Label and (l as Label).text.is_valid_int() or (l is Label and (l as Label).text.begins_with("+")):
			(l as Label).add_theme_font_override(&"font", DataTable.tabular_font())
	return row


## Classificação como tabela de dados (celular em pé): posição, escudo e nome presos à esquerda;
## J, SG e PTS logo de cara e, passando o dedo, V, E, D, gols, os últimos jogos e o aproveitamento.
## `lines`: [{id, pos, zone (Color), move, row (Dictionary)}] já na ordem da tabela.
static func standings_table(w: GameWorld, lines: Array, view: String, on_tap: Callable, state: Dictionary) -> DataTable:
	var t := DataTable.new()
	t.row_height = UITokens.H_ROW - 8
	t.lead_width = 300.0
	t.lead_min = 290.0
	t.marker = func(it: Dictionary) -> Color: return it["zone"]
	t.highlight = func(it: Dictionary) -> bool: return w.is_user_club(int(it["id"]))
	t.row_pressed.connect(func(it: Variant): on_tap.call(int((it as Dictionary)["id"])))
	var num := func(key: String, title: String, tip: String, strong: bool = false) -> Dictionary:
		return {"key": key, "title": title, "w": 56 if strong else 44, "tip": tip, "strong": strong,
			"text": func(it: Dictionary) -> String:
				var r: Dictionary = it["row"]
				return Fmt.signed(int(r["gf"]) - int(r["ga"])) if key == "sg" else str(int(r[key])),
			"sort": func(it: Dictionary) -> int:
				var r: Dictionary = it["row"]
				return int(r["gf"]) - int(r["ga"]) if key == "sg" else int(r[key]),
			"color": func(it: Dictionary) -> Color:
				if strong:
					return UIColors.RED if int((it["row"] as Dictionary).get("ded", 0)) > 0 else UIColors.TEXT
				return UIColors.MUTED}
	var c := {}
	c["club"] = {"key": "club", "title": "Clube", "first": "asc",
		"sort": func(it: Dictionary) -> int: return int(it["pos"]),
		"cell": func(it: Dictionary) -> Control: return _standing_lead(w, it)}
	c["pl"] = num.call("pl", "J", "Jogos")
	c["sg"] = num.call("sg", "SG", "Saldo de gols")
	c["sg"]["w"] = 52
	c["pts"] = num.call("pts", "PTS", "Pontos", true)
	c["w"] = num.call("w", "V", "Vitórias")
	c["d"] = num.call("d", "E", "Empates")
	c["l"] = num.call("l", "D", "Derrotas")
	c["gf"] = num.call("gf", "GP", "Gols pró")
	c["ga"] = num.call("ga", "GC", "Gols contra")
	c["form"] = {"key": "form", "title": "Últimos 5", "w": W_FORM, "align": "c",
		"cell": func(it: Dictionary) -> Control: return form_dots(String((it["row"] as Dictionary).get("form", "")), 18)}
	c["apr"] = {"key": "apr", "title": "Aprov.", "w": 68, "tip": "Aproveitamento dos pontos",
		"text": func(it: Dictionary) -> String:
			var r: Dictionary = it["row"]
			return ("%d%%" % roundi(100.0 * int(r["pts"]) / (3.0 * int(r["pl"])))) if int(r["pl"]) > 0 else "–",
		"sort": func(it: Dictionary) -> float:
			var r: Dictionary = it["row"]
			return float(r["pts"]) / maxf(1.0, int(r["pl"])),
		"color": func(_it: Dictionary) -> Color: return UIColors.MUTED}
	var keys: Array = ["form", "apr", "pts", "pl", "w", "d", "l", "gf", "ga", "sg"] if view == VIEW_FORM \
		else ["pl", "sg", "pts", "w", "d", "l", "gf", "ga", "form", "apr"]
	var cols: Array = [c["club"]]
	for k in keys:
		cols.append(c[k])
	return t.setup(cols, lines, state)


static func _standing_lead(w: GameWorld, it: Dictionary) -> Control:
	var cid := int(it["id"])
	var cl := w.club(cid)
	var is_user := w.is_user_club(cid)
	var h := UIKit.hbox(6)
	var pl := UIKit.label(str(int(it["pos"])), "H3")
	pl.custom_minimum_size.x = 30
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pl.add_theme_font_override(&"font", DataTable.tabular_font())
	h.add_child(pl)
	var cr := UIKit.crest(cl, W_CREST)
	cr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(cr)
	var n := UIKit.label(cl.short_name, "H3" if is_user else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_user:
		n.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
	h.add_child(n)
	var move := int(it.get("move", 0))
	if move != 0:
		var up := move > 0
		var mv := UIKit.colored(("▲" if up else "▼") + str(absi(move)), UIColors.GREEN if up else UIColors.RED, "Small")
		mv.add_theme_font_size_override(&"font_size", 16)
		mv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(mv)
	h.tooltip_text = cl.name
	return h


## Quadradinhos dos últimos jogos (V verde, E cinza, D vermelho), do mais antigo ao mais recente.
static func form_dots(form: String, px: int = 18, slots: int = 5) -> HBoxContainer:
	var h := UIKit.hbox(4)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in slots:
		var k := i - (slots - form.length())
		var ch := form[k] if k >= 0 else ""
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(4)
		sb.bg_color = {"V": UIColors.GREEN, "E": UIColors.DIM, "D": UIColors.RED}.get(ch, UIColors.SURFACE_3)
		p.add_theme_stylebox_override(&"panel", sb)
		p.custom_minimum_size = Vector2(px, px)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(p)
	return h


## Tabela só com os jogos em casa (VIEW_HOME) ou fora (VIEW_AWAY) da liga, já disputados.
## Conta a fase regular e o split (os playoffs não entram na classificação).
static func side_table(league: League, view: String) -> Dictionary:
	var t := {}
	for cid in league.club_ids:
		t[cid] = CompetitionManager.empty_row()
	var last := league.rounds.size() if LeagueFormat.kind(league) != "playoff" else league.regular_rounds
	for r in mini(last, league.rounds.size()):
		for f: Fixture in league.rounds[r]:
			if not f.played or not t.has(f.home) or not t.has(f.away):
				continue
			var tmp := {f.home: t[f.home].duplicate(), f.away: t[f.away].duplicate()}
			CompetitionManager.apply_to_table(tmp, f)
			if view == VIEW_HOME:
				t[f.home] = tmp[f.home]
			else:
				t[f.away] = tmp[f.away]
	return t


## Posições ao fim da penúltima rodada disputada ({club_id: posição}); vazio sem histórico.
static func previous_positions(league: League) -> Dictionary:
	var played := league.rounds_played()
	if played < 2 or not league.phase_groups.is_empty():
		return {}
	var t := {}
	for cid in league.club_ids:
		t[cid] = CompetitionManager.empty_row()
	for r in played - 1:
		for f: Fixture in league.rounds[r]:
			if f.played and t.has(f.home) and t.has(f.away):
				CompetitionManager.apply_to_table(t, f)
	var out := {}
	var ids := CompetitionManager.sort_table(league.club_ids, t)
	for i in ids.size():
		out[ids[i]] = i + 1
	return out


## Legenda das zonas da liga (título, vaga continental, acesso, rebaixamento).
static func legend(league: League) -> HFlowContainer:
	var f := UIKit.flow(14)
	f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_TITLE), "Campeão"))
	for band in CupManager.qualification_bands(league):
		var zone := CompetitionManager.zone_of(league, int(band["from"])) if int(band["from"]) > 1 else CompetitionManager.ZONE_CONTINENTAL
		f.add_child(_legend_item(CompetitionManager.zone_color(zone), "%s (%d)" % [CupManager.cup_short(band["cup"]), int(band["to"]) - int(band["from"]) + 1]))
	var direct := CompetitionManager.direct_up(league)
	if direct > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION), "Acesso (%d)" % direct))
	var pr := CompetitionManager.playoff_range(league)
	if not pr.is_empty():
		var promo := LeagueFormat.kind(league) == "promo"
		var span := ("%dº" % int(pr[0])) if int(pr[0]) == int(pr[1]) else ("%dº–%dº" % [int(pr[0]), int(pr[1])])
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_PLAYOFF), ("Playoffs de acesso (%s)" if promo else "Repescagem (%s)") % span))
	var rel := league.relegated_count() - (1 if LeagueFormat.uses_promedios(league) else 0)
	if rel > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_RELEGATION), "Rebaixamento (%d)" % rel))
	return f


static func _legend_item(c: Color, text: String) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var sw := ColorRect.new()
	sw.color = c
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sw)
	h.add_child(UIKit.label(text, "Small"))
	return h


## Linha de ranking individual (artilharia, assistências, notas).
static func ranking_row(w: GameWorld, p: Player, rank: int, value: String, caption: String) -> Control:
	var h := UIKit.hbox(10)
	var rl := UIKit.label(str(rank), "Mono")
	rl.custom_minimum_size.x = 32
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if rank > 3:
		rl.add_theme_color_override(&"font_color", UIColors.MUTED)
	h.add_child(rl)
	var cl: Club = w.club(p.club_id) if p.club_id >= 0 else null
	h.add_child(UIKit.crest(cl, 32))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := UIKit.label(p.display_name(), "H3")
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if cl != null and w.is_user_club(cl.id):
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	col.add_child(n)
	col.add_child(UIKit.label("%s · %s" % [cl.short_name if cl != null else "sem clube", caption], "Small"))
	h.add_child(col)
	var vl := UIKit.label(value, "Stat")
	vl.custom_minimum_size.x = 48
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(vl)
	var pid := p.id
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "RowPanel")


## Linhas de ranking numa lista só, separadas por filetes (sem uma caixa por linha).
static func ranking_list(rows: Array) -> Control:
	var group := UIKit.menu_group(rows)
	group.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	return group


## Detalhes de um jogo (gols, craque, público) ou a prévia (campanhas) se ainda não aconteceu.
static func fixture_details(w: GameWorld, f: Fixture) -> void:
	var v := UIKit.vbox(12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var home := w.club(f.home)
	var away := w.club(f.away)
	var t := UIKit.label("%s %s %s" % [home.short_name, ("%d – %d" % [f.hg, f.ag]) if f.played else "×", away.short_name], "Title", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UIKit.label("%s · %s" % ["Campo neutro" if f.neutral else home.stadium, w.season.date_label(f.slot)], "Small"))
	if not f.played:
		for cl in [home, away]:
			var lg := w.league_of(cl.id)
			if lg != null and lg.table.has(cl.id):
				var r: Dictionary = lg.table[cl.id]
				v.add_child(UIKit.kv("%s (%s)" % [cl.short_name, lg.short_name], "%d pts, %dV %dE %dD" % [r["pts"], r["w"], r["d"], r["l"]]))
		if MatchEngine.is_derby(w, f.home, f.away):
			v.add_child(UIKit.colored("Clássico.", UIColors.RED, "H3"))
	else:
		if f.extra_time:
			v.add_child(UIKit.label("Decidido na prorrogação" if not f.has_penalties() else "Pênaltis: %d x %d" % [f.pen_h, f.pen_a], "Accent"))
		for side in 2:
			for g in f.goals:
				if int(g[1]) != side:
					continue
				var p := w.player(int(g[2]))
				var txt := "%s  %s" % [Fmt.minute(int(g[0]), int(g[4]) if g.size() > 4 else 0), p.short_name() if p != null else "?"]
				if int(g[3]) == Fixture.GOAL_PENALTY:
					txt += " (p)"
				elif int(g[3]) == Fixture.GOAL_OWN:
					txt += " (contra)"
				var l := UIKit.label(txt, "")
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
				v.add_child(l)
		var motm := w.player(f.motm)
		if motm != null:
			v.add_child(UIKit.kv("Craque do jogo", motm.display_name(), UIColors.ACCENT))
		if f.attendance > 0:
			v.add_child(UIKit.kv("Público", Fmt.thousands(f.attendance)))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)
