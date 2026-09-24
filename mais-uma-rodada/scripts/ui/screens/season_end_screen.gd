extends BaseScreen
## Fim de temporada: campeões, acessos e quedas, o balanço do seu clube, despedidas e a base.
## Abrir esta tela vira a página: processa o fim do ano e prepara a próxima temporada.

var _summary: Dictionary = {}
var _overlay: GoalOverlay
var _celebrated := false


func _init() -> void:
	show_nav = false
	screen_title = "Fim de temporada"


func on_show() -> void:
	if _summary.is_empty():
		_summary = GameManager.end_season() if GameManager.season_over() else GameManager.last_summary
	refresh()
	if not _celebrated:
		_celebrated = true
		_celebrate()


func _celebrate() -> void:
	var u: Dictionary = _summary.get("user", {})
	if u.is_empty():
		return
	var w := world()
	var club := w.user_club()
	var title := ""
	var tag := ""
	if u.get("champion", false):
		title = "CAMPEÃO!"
		tag = String(_division_name(int(u.get("div", 0)))).to_upper()
	elif u.get("promoted", false):
		title = "ACESSO!"
		tag = "RUMO À %s" % String(w.division_name(int(u.get("div", 1)) - 1)).to_upper()
	if title == "":
		if u.get("relegated", false):
			AudioManager.play("lose", -4.0)
		return
	_overlay = GoalOverlay.new()
	add_child(_overlay)
	AudioManager.play("title")
	AudioManager.vibrate(400)
	_overlay.play(3, title, club.short_name, tag, "Temporada %d" % int(_summary.get("year", w.year - 1)), club.primary_color(), club.secondary_color(), 1.0)


func _division_name(div: int) -> String:
	for d in _summary.get("divisions", []):
		if int(d["div"]) == div:
			return String(d["name"])
	return world().division_name(div)


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var year := int(_summary.get("year", w.year - 1))
	screen_subtitle = "Temporada %d" % year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	if _summary.is_empty():
		c.add_child(UIKit.label("A temporada ainda não terminou.", "Muted"))
		_footer(w)
		return
	c.add_child(_user_card(w, year))
	for d in _summary.get("divisions", []):
		c.add_child(_division_card(w, d))
	var mine := _club_card(w)
	if mine != null:
		c.add_child(mine)
	_footer(w)


func _user_card(w: GameWorld, year: int) -> Control:
	var u: Dictionary = _summary.get("user", {})
	var card := UIKit.card("CardHighlight", 10)
	if u.is_empty():
		card.add_child(UIKit.label("Temporada %d encerrada." % year, "Title"))
		return UIKit.card_panel(card)
	var fired: bool = u.get("fired", false)
	var club: Club = w.club(int(w.stats.get("fired", {}).get("from", w.user_club_id))) if fired else w.user_club()
	var row := UIKit.hbox(14)
	row.add_child(UIKit.crest(club, 88))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(club.short_name, "Title"))
	col.add_child(UIKit.label("%dº lugar na %s" % [int(u.get("pos", 0)), _division_name(int(u.get("div", 0)))], "H3"))
	row.add_child(col)
	card.add_child(row)
	var tags := UIKit.flow(8)
	if u.get("champion", false):
		tags.add_child(UIKit.pill("CAMPEÃO", UIColors.ACCENT, 20))
	if u.get("promoted", false):
		tags.add_child(UIKit.pill("ACESSO", UIColors.GREEN, 20))
	if u.get("relegated", false):
		tags.add_child(UIKit.pill("REBAIXADO", UIColors.RED, 20))
	tags.add_child(UIKit.pill("META CUMPRIDA" if u.get("goal_met", false) else "META NÃO CUMPRIDA", UIColors.GREEN if u.get("goal_met", false) else UIColors.ORANGE, 18))
	card.add_child(tags)
	card.add_child(UIKit.kv("Meta da diretoria", String(u.get("goal", ""))))
	if fired:
		card.add_child(UIKit.colored("A diretoria decidiu trocar o treinador. Clubes interessados esperam sua resposta no hub.", UIColors.RED, "H3"))
	else:
		var delta := float(u.get("board_delta", 0.0))
		var conf := float(u.get("board", club.board_confidence))
		card.add_child(UIKit.kv("Diretoria", "%s (%s)" % [BoardManager.label(conf), "subiu" if delta > 0 else "caiu"], BoardManager.color(conf)))
	return UIKit.card_panel(card)


func _division_card(w: GameWorld, d: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section(String(d["name"])))
	var champ := w.club(int(d["champion"]))
	var row := UIKit.hbox(12)
	row.add_child(UIKit.icon_rect("trophy", 34, UIColors.ACCENT))
	row.add_child(UIKit.crest(champ, 48))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Campeão", "Caps"))
	var cn := UIKit.label(champ.name, "H3", true)
	if w.is_user_club(champ.id):
		cn.add_theme_color_override(&"font_color", UIColors.ACCENT)
	col.add_child(cn)
	row.add_child(col)
	var cid := champ.id
	card.add_child(UIKit.tap_row(row, func(): _open_club(cid), "CardFlat"))
	var promoted: Array = d.get("promoted", [])
	if not promoted.is_empty():
		card.add_child(_club_list(w, "Acesso", promoted, UIColors.GREEN))
	var relegated: Array = d.get("relegated", [])
	if not relegated.is_empty():
		card.add_child(_club_list(w, "Rebaixados", relegated, UIColors.RED))
	var sc: Dictionary = d.get("scorer", {})
	if not sc.is_empty():
		card.add_child(UIKit.kv("Artilheiro", "%s (%s) · %d gols" % [sc.get("name", ""), sc.get("club", ""), int(sc.get("goals", 0))]))
	return UIKit.card_panel(card)


func _club_list(w: GameWorld, title: String, ids: Array, color: Color) -> Control:
	var v := UIKit.vbox(2)
	v.add_child(UIKit.colored(title.to_upper(), color, "Caps"))
	var f := UIKit.flow(8)
	for id in ids:
		var cl := w.club(int(id))
		var p := UIKit.pill(cl.short_name, UIColors.ACCENT if w.is_user_club(cl.id) else color, 17)
		f.add_child(p)
	v.add_child(f)
	return v


func _open_club(cid: int) -> void:
	if world().is_user_club(cid):
		UIManager.push("club")
	else:
		UIManager.push("club", {"id": cid})


func _club_card(w: GameWorld) -> Control:
	var retired: Array = _summary.get("retired", [])
	var left: Array = _summary.get("left", [])
	var youth: Array = _summary.get("youth", [])
	if retired.is_empty() and left.is_empty() and youth.is_empty():
		return null
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Seu elenco"))
	if not retired.is_empty():
		card.add_child(UIKit.kv("Aposentaram-se", ", ".join(PackedStringArray(retired))))
	if not left.is_empty():
		card.add_child(UIKit.label("Saíram com o fim do contrato: %s." % ", ".join(PackedStringArray(left)), "", true))
	if not youth.is_empty():
		card.add_child(UIKit.label("Subiram da base: %s." % ", ".join(PackedStringArray(youth)), "", true))
		card.add_child(UIKit.label("Os jovens já estão no elenco. O potencial é uma estimativa: alguns explodem, outros não.", "Small", true))
	return UIKit.card_panel(card)


func _footer(w: GameWorld) -> void:
	var f := footer()
	UIKit.clear(f)
	var fired := not BoardManager.pending_job_offers(w).is_empty()
	var text := "ESCOLHER NOVO CLUBE" if fired else "COMEÇAR TEMPORADA %d" % w.year
	f.add_child(UIKit.button(text, "PrimaryButton", func(): UIManager.goto("hub"), "play"))
