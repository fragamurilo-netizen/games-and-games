class_name CoachMovesScreen
extends BaseScreen
## Dança das cadeiras: todas as trocas de técnico (quem caiu, quem pediu para sair, quem foi
## tirado de outro clube, interinos) e os técnicos sem clube à espera de uma chance.

const SCOPES := [["league", "Minha liga"], ["nation", "Meu país"], ["world", "Mundo"]]
const TABS := [["moves", "Trocas"], ["free", "Sem clube"]]

var _scope := "league"
var _tab := "moves"


func _init() -> void:
	show_nav = false
	screen_title = "Dança das cadeiras"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	if not w.has_user():
		_scope = "world"
	screen_subtitle = "Temporada %d" % w.year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_chips(TABS, _tab, func(k: String): _tab = k))
	if w.has_user():
		c.add_child(_chips(SCOPES, _scope, func(k: String): _scope = k))
	if _tab == "free":
		_free(w, c)
	else:
		_moves(w, c)


func _chips(opts: Array, cur: String, set_fn: Callable) -> Control:
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for o in opts:
		var key: String = o[0]
		var chip := UIKit.chip(o[1], key == cur, g, func():
			set_fn.call(key)
			refresh())
		UIKit.shrink_button(chip)
		chip.add_theme_font_size_override(&"font_size", 18)
		row.add_child(chip)
	return row


func _in_scope(w: GameWorld, club: Club) -> bool:
	if club == null:
		return false
	match _scope:
		"league":
			return club.league_id == w.user_club().league_id
		"nation":
			return club.nation == w.user_club().nation
	return true


func _moves(w: GameWorld, c: VBoxContainer) -> void:
	var all: Array = CoachCareer.moves(w)
	var list: Array = []
	for i in range(all.size() - 1, -1, -1):
		var e: Dictionary = all[i]
		if int(e["y"]) < w.year - 2:
			break
		if _in_scope(w, w.club(int(e["c"]))):
			list.append(e)
	# Resumo da temporada
	var this_year := list.filter(func(e): return int(e["y"]) == w.year and String(e["why"]) != "efe")
	var fired := this_year.filter(func(e): return String(e["why"]) in ["resultados", "temporada"]).size()
	var per_club := {}
	for e: Dictionary in this_year:
		per_club[int(e["c"])] = int(per_club.get(int(e["c"]), 0)) + 1
	var top := -1
	for cid in per_club:
		if top < 0 or int(per_club[cid]) > int(per_club[top]):
			top = int(cid)
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Temporada %d" % w.year))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(this_year.size()), "trocas"))
	row.add_child(UIKit.stat(str(fired), "demissões", UIColors.RED if fired > 0 else UIColors.TEXT))
	row.add_child(UIKit.stat(str(this_year.filter(func(e): return bool(e.get("i", false))).size()), "interinos"))
	card.add_child(row)
	if top >= 0 and int(per_club[top]) >= 2:
		card.add_child(UIKit.kv("Quem mais trocou", "%s (%d)" % [w.club(top).short_name, int(per_club[top])]))
	c.add_child(UIKit.card_panel(card))
	if list.is_empty():
		c.add_child(UIKit.label("Nenhuma troca de técnico por aqui ainda.", "Muted"))
		return
	var box := UIKit.card("Card", 6)
	var last_key := ""
	for e: Dictionary in list:
		var key := "%d-%s" % [int(e["y"]), "f" if bool(e.get("fim", false)) else str(int(e["d"]))]
		if key != last_key:
			last_key = key
			box.add_child(UIKit.section(("Fim da temporada %d" % int(e["y"])) if bool(e.get("fim", false)) else ("Rodada %d · %d" % [int(e["d"]) + 1, int(e["y"])])))
		box.add_child(_move_row(w, e))
	c.add_child(UIKit.card_panel(box))


func _move_row(w: GameWorld, e: Dictionary) -> Control:
	var club := w.club(int(e["c"]))
	var line := UIKit.hbox(10)
	line.add_child(UIKit.crest(club, 38))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var why := String(e["why"])
	var head := ""
	if why == "efe":
		head = "%s efetivado" % String(e["n"])
	elif String(e["o"]) != "":
		head = "Sai %s, entra %s" % [String(e["o"]), String(e["n"])]
	else:
		head = "Chega %s" % String(e["n"])
	var hl := UIKit.label(head, "H3", true)
	col.add_child(hl)
	var parts: Array = [club.short_name]
	if why != "efe":
		parts.append(CoachCareer.why_text(w, e))
	var fr := w.club(int(e.get("fr", -1)))
	if fr != null:
		parts.append("veio do %s" % fr.short_name)
	if int(e.get("fee", 0)) > 0:
		parts.append("multa de %s" % Fmt.money(int(e["fee"])))
	if bool(e.get("i", false)):
		parts.append("interino")
	col.add_child(UIKit.label(" · ".join(parts), "Small", true))
	line.add_child(col)
	var ni := int(e.get("ni", -1))
	if ni >= 0 and not CoachCareer.find(w, ni).is_empty():
		return UIKit.tap_row(line, func(): UIManager.push("coach", {"coach": ni}), "CardFlat")
	return line


func _free(w: GameWorld, c: VBoxContainer) -> void:
	var pool: Array = People.data(w)["free"].duplicate()
	if _scope != "world":
		var nat := w.user_club().nation
		pool = pool.filter(func(co): return String(co.get("nat", "")) == nat or _last_nation(w, co) == nat)
	pool.sort_custom(func(a, b): return float(a.get("rep", 0.0)) > float(b.get("rep", 0.0)))
	if pool.is_empty():
		c.add_child(UIKit.label("Nenhum técnico livre com esse filtro.", "Muted"))
		return
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Técnicos sem clube"))
	for co: Dictionary in pool.slice(0, 40):
		var row := UIKit.hbox(12)
		row.add_child(CoachScreen.portrait(w, co, null, 56))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(co["n"]), "H3", true))
		var car: Array = co.get("car", [])
		var last: Dictionary = car.back() if not car.is_empty() else {}
		var t := CoachCareer.totals(co)
		var info: Array = ["%s, %d anos" % [DatabaseManager.nation_name(String(co.get("nat", ""))), w.year - int(co.get("by", w.year - 50))]]
		if not last.is_empty():
			info.append("último: %s (%s)" % [String(last.get("cn", "")), CoachCareer.end_text(last).to_lower()] if CoachCareer.end_text(last) != "" else "último: %s" % String(last.get("cn", "")))
		if int(t["t"]) > 0:
			info.append("%d título(s)" % int(t["t"]))
		col.add_child(UIKit.label(" · ".join(info), "Small", true))
		row.add_child(col)
		row.add_child(UIKit.label(CoachScreen._stars(float(co.get("sk", 50.0))), "Small"))
		var id := int(co["id"])
		card.add_child(UIKit.tap_row(row, func(): UIManager.push("coach", {"coach": id})))
	c.add_child(UIKit.card_panel(card))


static func _last_nation(w: GameWorld, co: Dictionary) -> String:
	var car: Array = co.get("car", [])
	for i in range(car.size() - 1, -1, -1):
		var cl := w.club(int(car[i].get("c", -1)))
		if cl != null:
			return cl.nation
	return ""
