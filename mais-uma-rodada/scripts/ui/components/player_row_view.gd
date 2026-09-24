class_name PlayerRowView
extends RefCounted
## Linha de jogador: número, posição, nome, situação, físico e overall.
## opts: {mode: "squad"|"market"|"pick", pos: int (rende nesta posição), known: bool (dados exatos)}


static func make(w: GameWorld, p: Player, opts: Dictionary, cb: Callable) -> PanelContainer:
	var mode: String = opts.get("mode", "squad")
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	var row := UIKit.hbox(10)
	if mode != "market":
		var num := UIKit.label(str(p.shirt) if p.shirt > 0 else "–", "Mono")
		num.custom_minimum_size.x = 38
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_color_override(&"font_color", UIColors.DIM)
		row.add_child(num)
	row.add_child(UIKit.pos_badge(p.position))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(p.display_name(), "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UIKit.label(subtitle(w, p, mode), "Small"))
	row.add_child(col)
	# Ícones de situação
	var icons := UIKit.hbox(4)
	if p.injury_weeks > 0:
		icons.add_child(UIKit.icon_rect("cross", 22, UIColors.RED))
	if p.suspension > 0:
		icons.add_child(UIKit.icon_rect("card", 22, UIColors.RED))
	elif p.yellow_acc >= int(DatabaseManager.squad_rules()["yellow_limit"]) - 1 and own:
		icons.add_child(UIKit.icon_rect("card", 22, UIColors.ACCENT))
	if own and p.contract_end <= w.year:
		icons.add_child(UIKit.icon_rect("clock", 22, UIColors.ORANGE))
	if p.transfer_listed:
		icons.add_child(UIKit.icon_rect("money", 22, UIColors.GREEN))
	if p.retiring:
		icons.add_child(UIKit.icon_rect("heart", 22, UIColors.MUTED))
	if icons.get_child_count() > 0:
		row.add_child(icons)
	if mode != "market":
		var cond := UIKit.vbox(2)
		cond.alignment = BoxContainer.ALIGNMENT_CENTER
		cond.custom_minimum_size.x = 56
		var bar := UIKit.bar(p.condition, 100.0, _cond_color(p.condition), 8)
		cond.add_child(bar)
		var mor := UIKit.label(UIColors.morale_label(p.morale), "Caps")
		mor.add_theme_color_override(&"font_color", UIColors.morale_color(p.morale))
		mor.add_theme_font_size_override(&"font_size", 14)
		cond.add_child(mor)
		row.add_child(cond)
	else:
		var val := UIKit.label(Fmt.money(p.value), "Stat")
		val.add_theme_font_size_override(&"font_size", 24)
		row.add_child(val)
	var pos: int = opts.get("pos", -1)
	var shown := int(round(p.rating_at(pos))) if pos >= 0 else p.overall
	if own or opts.get("known", false):
		row.add_child(UIKit.badge(shown))
	else:
		var est := estimate(w, p, shown)
		var b := UIKit.badge(est)
		b.text_override = "~%d" % est
		row.add_child(b)
	return UIKit.tap_row(row, cb)


static func subtitle(w: GameWorld, p: Player, mode: String) -> String:
	var age := p.age(w.year)
	if mode == "market":
		var cname := "Livre" if p.club_id < 0 else w.club(p.club_id).short_name
		return "%d anos · %s · %s" % [age, PlayStyle.of(p), cname]
	var parts: Array = ["%d anos" % age, PlayStyle.of(p)]
	if p.injury_weeks > 0:
		parts.append("lesionado (%d sem.)" % p.injury_weeks)
	elif p.suspension > 0:
		parts.append("suspenso")
	else:
		parts.append(Player.STATUS_NAMES[p.squad_status])
	if p.club_id >= 0 and w.is_user_club(p.club_id):
		parts.append("até %d" % p.contract_end)
	if p.stats[Player.S_APPS] > 0:
		parts.append("%dj %dg" % [p.stats[Player.S_APPS], p.stats[Player.S_GOALS]])
	return " · ".join(parts)


static func _cond_color(c: float) -> Color:
	if c >= 85.0:
		return UIColors.GREEN
	if c >= 70.0:
		return UIColors.ACCENT
	return UIColors.RED


## Overall aproximado de jogadores de outros clubes (conhecimento imperfeito).
## Jogadores da mesma divisão são mais conhecidos; livres e de longe, menos.
static func estimate(w: GameWorld, p: Player, value: int) -> int:
	var err := 3.0
	if p.club_id >= 0 and w.has_user() and w.club(p.club_id).league_id == w.user_league_id():
		err = 1.5
	return clampi(value + int(round(p.scout_noise / 6.0 * err)), 1, 99)
