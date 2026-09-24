class_name TableRows
extends RefCounted
## Linhas de classificação e de rankings reutilizadas pela tabela e pelos resultados da rodada.

const COLS_COMPACT := ["J", "SG", "PTS"]
const COLS_FULL := ["J", "V", "E", "D", "SG", "PTS"]


static func header(compact: bool) -> HBoxContainer:
	var h := UIKit.hbox(6)
	var gap := Control.new()
	gap.custom_minimum_size.x = 5 + 36 + 30 + 12
	h.add_child(gap)
	var n := UIKit.label("CLUBE", "Caps")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(n)
	for col in (COLS_COMPACT if compact else COLS_FULL):
		var l := UIKit.label(col, "Caps")
		l.custom_minimum_size.x = 52 if compact else 40
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(l)
	return h


static func row(w: GameWorld, league: League, club_id: int, pos: int, compact: bool) -> Control:
	var r: Dictionary = league.table[club_id]
	var cl := w.club(club_id)
	var is_user := w.is_user_club(club_id)
	var h := UIKit.hbox(6)
	var bar := ColorRect.new()
	bar.custom_minimum_size = Vector2(5, 0)
	bar.color = CompetitionManager.zone_color(CompetitionManager.zone_of(league, pos))
	h.add_child(bar)
	var pl := UIKit.label(str(pos), "H3")
	pl.custom_minimum_size.x = 36
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(pl)
	h.add_child(UIKit.crest(cl, 30))
	var n := UIKit.label(cl.short_name, "H3" if is_user else "")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_user:
		n.add_theme_color_override(&"font_color", UIColors.ACCENT)
	h.add_child(n)
	var sg: int = int(r["gf"]) - int(r["ga"])
	var values: Array = [r["pl"], sg, r["pts"]] if compact else [r["pl"], r["w"], r["d"], r["l"], sg, r["pts"]]
	for i in values.size():
		var last := i == values.size() - 1
		var txt := str(values[i])
		if (compact and i == 1) or (not compact and i == 4):
			txt = Fmt.signed(int(values[i]))
		var l := UIKit.label(txt, "H3" if last else "")
		l.custom_minimum_size.x = 52 if compact else 40
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if not last:
			l.add_theme_color_override(&"font_color", UIColors.MUTED)
		h.add_child(l)
	var cid := club_id
	var row := UIKit.tap_row(h, func():
		if w.is_user_club(cid):
			UIManager.goto("club")
		else:
			UIManager.push("club", {"id": cid}), "CardFlat")
	if is_user:
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.SURFACE_2
		sb.border_color = UIColors.ACCENT
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(14)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		row.add_theme_stylebox_override(&"panel", sb)
	return row


## Legenda das zonas da divisão (título, acesso, rebaixamento).
static func legend(league: League) -> HFlowContainer:
	var f := UIKit.flow(14)
	var cfg := DatabaseManager.division_config(league.division)
	if league.division == 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_TITLE), "Campeão"))
	if int(cfg["promoted"]) > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_PROMOTION), "Acesso (%d)" % int(cfg["promoted"])))
	if int(cfg["relegated"]) > 0:
		f.add_child(_legend_item(CompetitionManager.zone_color(CompetitionManager.ZONE_RELEGATION), "Rebaixamento (%d)" % int(cfg["relegated"])))
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
