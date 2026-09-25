class_name TableRows
extends RefCounted
## Linhas de classificação e de rankings reutilizadas pela tabela e pelos resultados da rodada.

const COLS_COMPACT := ["J", "SG", "PTS"]
const COLS_FULL := ["J", "V", "E", "D", "SG", "PTS"]
const COLS_FORM := ["ÚLTIMOS 5", "APR", "PTS"]
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


static func header(compact: bool, view: String = VIEW_ALL) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var gap := Control.new()
	# Mesma soma da linha: margem, faixa da zona, posição e escudo (com os espaçamentos).
	gap.custom_minimum_size.x = ROW_PAD + 5 + 6 + W_POS + 6 + W_CREST
	h.add_child(gap)
	var n := UIKit.label("CLUBE", "Caps")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	var cols: Array = COLS_COMPACT if compact else (COLS_FORM if view == VIEW_FORM else COLS_FULL)
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
		view: String = VIEW_ALL, move: int = 0, on_tap: Callable = Callable()) -> Control:
	var cl := w.club(club_id)
	var is_user := w.is_user_club(club_id)
	var h := UIKit.hbox(6)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
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
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
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
		var values: Array = [r["pl"], sg, r["pts"]] if compact else [r["pl"], r["w"], r["d"], r["l"], sg, r["pts"]]
		var cols: Array = COLS_COMPACT if compact else COLS_FULL
		for i in values.size():
			var last := i == values.size() - 1
			var txt := str(values[i])
			var is_sg: bool = cols[i] == "SG"
			if is_sg:
				txt = Fmt.signed(int(values[i]))
			var l := UIKit.label(txt, "H3" if last else "")
			l.custom_minimum_size.x = _col_width(cols[i], compact)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if not last:
				l.add_theme_color_override(&"font_color", UIColors.MUTED)
			h.add_child(l)
	var cid := club_id
	var tap := on_tap
	var row := UIKit.tap_row(h, func():
		if tap.is_valid():
			tap.call()
		elif w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "CardFlat")
	if is_user:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.SURFACE_2
		sb.border_color = UIColors.ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = ROW_PAD
		sb.content_margin_right = ROW_PAD
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		row.add_theme_stylebox_override(&"panel", sb)
	return row


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
	if league.promoted_count() > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION), "Acesso (%d)" % league.promoted_count()))
	if league.relegated_count() > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_RELEGATION), "Rebaixamento (%d)" % league.relegated_count()))
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
	var rl := UIKit.label(str(rank), "H3")
	rl.custom_minimum_size.x = 36
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	h.add_child(UIKit.label(value, "Stat"))
	var pid := p.id
	return UIKit.tap_row(h, func(): UIManager.push("player", {"id": pid}), "CardFlat")


## Detalhes de um jogo (gols, craque, público) ou a prévia (campanhas) se ainda não aconteceu.
static func fixture_details(w: GameWorld, f: Fixture) -> void:
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 600
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
