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
	var cup_title := ""
	for cu in u.get("cups", []):
		if cu.get("champion", false):
			cup_title = String(cu["name"])
	if cup_title != "":
		title = "CAMPEÃO!"
		tag = cup_title.to_upper()
	elif u.get("champion", false):
		title = "CAMPEÃO!"
		tag = String(u.get("league_name", "")).to_upper()
	elif u.get("promoted", false):
		title = "ACESSO!"
		tag = "RUMO À %s" % w.league_name(club.league_id).to_upper()
	if title == "":
		if u.get("relegated", false):
			AudioManager.play("lose", -4.0)
		return
	_overlay = GoalOverlay.new()
	add_child(_overlay)
	AudioManager.play("title")
	AudioManager.vibrate(400)
	_overlay.play(3, title, club.short_name, tag, "Temporada %d" % int(_summary.get("year", w.year - 1)), club.primary_color(), club.secondary_color(), 1.0)


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
	var rv: Dictionary = _summary.get("review", {})
	if not rv.is_empty():
		c.add_child(_grade_card(rv))
		c.add_child(_numbers_card(w, rv))
		var stars := _stars_card(w, rv)
		if stars != null:
			c.add_child(stars)
		var ach := _achievements_card(rv)
		if ach != null:
			c.add_child(ach)
		c.add_child(_career_card(w))
	var aw := _awards_card(w)
	if aw != null:
		c.add_child(aw)
	for cu in _summary.get("cups", []):
		c.add_child(_cup_card(w, cu))
	var nat := w.user_nation()
	var others: Array = []
	for d in _summary.get("leagues", []):
		if String(d["nation"]) == nat:
			c.add_child(_division_card(w, d))
		elif int(d["tier"]) == 1:
			others.append(d)
	if not others.is_empty():
		c.add_child(_world_card(w, others))
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
	col.add_child(UIKit.label(club.short_name, "Title", true))
	col.add_child(UIKit.label("%dº lugar na %s" % [int(u.get("pos", 0)), String(u.get("league_name", ""))], "H3", true))
	for cu in u.get("cups", []):
		col.add_child(UIKit.label("%s: %s" % [cu["name"], cu["stage"]], "Small", true))
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
		card.add_child(UIKit.colored("A diretoria decidiu trocar o treinador. Clubes interessados esperam sua resposta no hub.", UIColors.RED, "H3", true))
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
		card.add_child(UIKit.label("Artilheiro: %s (%s) · %d gols" % [sc.get("name", ""), sc.get("club", ""), int(sc.get("goals", 0))], "Small", true))
	return UIKit.card_panel(card)


func _cup_card(w: GameWorld, cu: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section(String(cu["name"])))
	var champ := w.club(int(cu["champion"]))
	if champ == null:
		card.add_child(UIKit.label("Sem campeão.", "Muted"))
		return UIKit.card_panel(card)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.icon_rect("trophy", 34, UIColors.ACCENT))
	row.add_child(UIKit.crest(champ, 48))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Campeão · %s" % DatabaseManager.nation_name(champ.nation), "Caps"))
	var cn := UIKit.label(champ.name, "H3", true)
	if w.is_user_club(champ.id):
		cn.add_theme_color_override(&"font_color", UIColors.ACCENT)
	col.add_child(cn)
	var ru := w.club(int(cu.get("runner_up", -1)))
	if ru != null:
		col.add_child(UIKit.label("Vice: %s" % ru.short_name, "Small"))
	row.add_child(col)
	var cid := champ.id
	card.add_child(UIKit.tap_row(row, func(): _open_club(cid), "CardFlat"))
	var sc: Dictionary = cu.get("scorer", {})
	if not sc.is_empty():
		card.add_child(UIKit.label("Artilheiro: %s (%s) · %d gols" % [sc.get("name", ""), sc.get("club", ""), int(sc.get("goals", 0))], "Small", true))
	return UIKit.card_panel(card)


## Prêmios da liga do usuário, melhor do mundo e o sub-20.
func _awards_card(w: GameWorld) -> Control:
	var aw: Dictionary = _summary.get("awards", {})
	var ballon: Dictionary = _summary.get("ballon", {})
	var yl: Dictionary = _summary.get("youth_league", {})
	if aw.is_empty() and ballon.is_empty() and yl.is_empty():
		return null
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Prêmios da temporada"))
	if not ballon.is_empty():
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon_rect("star", 34, UIColors.ACCENT))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("Melhor jogador do mundo", "Caps"))
		col.add_child(UIKit.label("%s (%s) · %d gols" % [ballon["name"], ballon["club"], int(ballon.get("goals", 0))], "H3", true))
		row.add_child(col)
		row.add_child(UIKit.flag(String(ballon.get("nat", "")), 40))
		card.add_child(row)
	for k in ["mvp", "young", "gk", "assist"]:
		if not aw.has(k):
			continue
		var a: Dictionary = aw[k]
		var row := UIKit.hbox(10)
		var kl := UIKit.label(AwardManager.award_name(k), "Small")
		kl.custom_minimum_size.x = 170
		row.add_child(kl)
		var nl := UIKit.label("%s (%s)" % [a["name"], a["club"]], "", true)
		row.add_child(nl)
		row.add_child(UIKit.label(String(a.get("v", "")), "Small"))
		card.add_child(row)
	if not yl.is_empty():
		var champ := w.club(int(yl.get("champion", -1)))
		if champ != null:
			card.add_child(UIKit.kv(String(yl.get("name", "Sub-20")), "%s · seu time %dº" % [champ.short_name, int(yl.get("user_pos", 0))], UIColors.ACCENT if w.is_user_club(champ.id) else UIColors.TEXT))
	return UIKit.card_panel(card)


## Campeões das primeiras divisões dos outros países.
func _world_card(w: GameWorld, leagues: Array) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Campeões pelo mundo"))
	for d in leagues:
		var champ := w.club(int(d["champion"]))
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(String(d["nation"]), 32))
		row.add_child(UIKit.crest(champ, 32))
		var l := UIKit.label(champ.short_name, "H3")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label(w.league_short(String(d["id"])), "Small"))
		var cid := champ.id
		card.add_child(UIKit.tap_row(row, func(): _open_club(cid), "CardFlat"))
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
		card.add_child(UIKit.label("Chegaram à base: %s." % ", ".join(PackedStringArray(youth)), "", true))
		card.add_child(UIKit.label("Acompanhe os garotos em Central do clube → Base. O potencial é uma estimativa: alguns explodem, outros não.", "Small", true))
	var yleft: Array = _summary.get("youth_left", [])
	if not yleft.is_empty():
		card.add_child(UIKit.label("Deixaram a base (idade limite): %s." % ", ".join(PackedStringArray(yleft)), "Small", true))
	return UIKit.card_panel(card)


func _footer(w: GameWorld) -> void:
	var f := footer()
	UIKit.clear(f)
	var fired := not BoardManager.pending_job_offers(w).is_empty()
	if fired:
		f.add_child(UIKit.button("ESCOLHER NOVO CLUBE", "PrimaryButton", func(): UIManager.goto("hub"), "play"))
		return
	f.add_child(UIKit.button("IR PARA A PRÉ-TEMPORADA %d" % w.year, "PrimaryButton", func():
		UIManager.goto("hub")
		if PreseasonManager.is_active(world()):
			UIManager.push("preseason"), "play"))


## Nota da temporada: letra grande, rótulo e a manchete do ano.
func _grade_card(rv: Dictionary) -> Control:
	var card := UIKit.card("CardHighlight", 8)
	card.add_child(UIKit.section("Nota da temporada"))
	var row := UIKit.hbox(18)
	var color := SeasonReview.grade_color(String(rv["grade"]))
	var letter := UIKit.label(String(rv["grade"]), "Big")
	letter.add_theme_font_size_override(&"font_size", 96)
	letter.add_theme_color_override(&"font_color", color)
	letter.custom_minimum_size.x = 150
	letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(letter)
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(UIKit.colored(String(rv["grade_label"]), color, "H2", true))
	col.add_child(UIKit.label(String(rv["headline"]), "", true))
	var bar := UIKit.bar(float(rv["score"]), 100.0, color, 12)
	col.add_child(bar)
	col.add_child(UIKit.label("%d de 100 pontos de avaliação" % int(rv["score"]), "Small"))
	row.add_child(col)
	card.add_child(row)
	if bool(rv.get("best_pos", false)):
		card.add_child(UIKit.colored("Melhor campanha do clube nesta divisão desde que você chegou.", UIColors.ACCENT, "Small", true))
	return UIKit.card_panel(card)


## Campanha em números, dinheiro e o crescimento do clube.
func _numbers_card(w: GameWorld, rv: Dictionary) -> Control:
	var rec: Dictionary = rv["record"]
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("A campanha em números"))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(int(rec["w"])), "vitórias", UIColors.GREEN))
	row.add_child(UIKit.stat(str(int(rec["d"])), "empates", UIColors.MUTED))
	row.add_child(UIKit.stat(str(int(rec["l"])), "derrotas", UIColors.RED))
	row.add_child(UIKit.stat("%d%%" % int(rec["aprov"]), "aproveit.", UIColors.ACCENT))
	card.add_child(row)
	var row2 := UIKit.hbox(4)
	row2.add_child(UIKit.stat(str(int(rec["pts"])), "pontos"))
	row2.add_child(UIKit.stat(str(int(rec["gf"])), "gols pró"))
	row2.add_child(UIKit.stat(str(int(rec["ga"])), "gols contra"))
	row2.add_child(UIKit.stat(Fmt.signed(int(rec["gf"]) - int(rec["ga"])), "saldo"))
	card.add_child(row2)
	card.add_child(UIKit.separator())
	card.add_child(UIKit.kv("Premiação pela colocação", Fmt.money(int(rv["prize"])), UIColors.GREEN))
	var net := int(rv["income"]) - int(rv["expense"])
	card.add_child(UIKit.kv("Resultado financeiro do ano", Fmt.money(net), UIColors.GREEN if net >= 0 else UIColors.RED))
	var drep := float(rv["rep1"]) - float(rv["rep0"])
	card.add_child(UIKit.kv("Reputação do clube", "%d (%s%.1f)" % [int(round(float(rv["rep1"]))), "+" if drep >= 0 else "", drep], UIColors.GREEN if drep >= 0 else UIColors.RED))
	var f0 := int(rv["fans0"])
	var f1 := int(rv["fans1"])
	var pf := 100.0 * (f1 - f0) / maxf(1.0, f0)
	card.add_child(UIKit.kv("Torcida", "%s (%s%.1f%%)" % [Fmt.thousands(f1), "+" if pf >= 0 else "", pf], UIColors.GREEN if pf >= 0 else UIColors.RED))
	return UIKit.card_panel(card)


## Destaques do elenco no ano, com retrato.
func _stars_card(w: GameWorld, rv: Dictionary) -> Control:
	var stars: Dictionary = rv.get("stars", {})
	if stars.is_empty():
		return null
	var club := w.user_club()
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Destaques do seu elenco"))
	var names := {"scorer": "Artilheiro", "assists": "Garçom", "rating": "Melhor nota", "apps": "Mais jogos", "young": "Revelação"}
	for k in ["scorer", "assists", "rating", "young", "apps"]:
		if not stars.has(k):
			continue
		var st: Dictionary = stars[k]
		var row := UIKit.hbox(12)
		var p := w.player(int(st["id"]))
		if p != null:
			row.add_child(UIKit.portrait(p, club, w.year, 60))
		else:
			row.add_child(UIKit.pos_badge(int(st.get("pos", 0))))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(names[k]).to_upper(), "Caps"))
		col.add_child(UIKit.label(String(st["name"]), "H3", true))
		row.add_child(col)
		row.add_child(UIKit.colored(String(st["text"]), UIColors.ACCENT, "H3"))
		if p != null:
			var pid := p.id
			card.add_child(UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}), "CardFlat"))
		else:
			card.add_child(row)
	return UIKit.card_panel(card)


func _achievements_card(rv: Dictionary) -> Control:
	var list: Array = rv.get("achievements", [])
	if list.is_empty():
		return null
	var card := UIKit.card("CardHighlight", 8)
	card.add_child(UIKit.section("Conquistas desbloqueadas"))
	for k in list:
		var a: Dictionary = SeasonReview.ACHIEVEMENTS.get(String(k), {})
		if a.is_empty():
			continue
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(a["icon"]), 36, UIColors.ACCENT))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.colored(String(a["name"]), UIColors.ACCENT, "H3"))
		col.add_child(UIKit.label(String(a["desc"]), "Small", true))
		row.add_child(col)
		card.add_child(row)
	return UIKit.card_panel(card)


## A carreira do treinador até aqui.
func _career_card(w: GameWorld) -> Control:
	var ms := w.manager_stats
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Sua carreira"))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(int(ms.get("seasons", 0))), "temporadas"))
	row.add_child(UIKit.stat(str(int(ms.get("games", 0))), "jogos"))
	row.add_child(UIKit.stat(str(int(ms.get("titles", 0))), "títulos", UIColors.ACCENT))
	row.add_child(UIKit.stat(str(int(ms.get("promotions", 0))), "acessos", UIColors.GREEN))
	card.add_child(row)
	var games := maxi(1, int(ms.get("games", 0)))
	card.add_child(UIKit.label("%dV %dE %dD · aproveitamento de %d%% · %d de %d conquistas" % [int(ms.get("w", 0)), int(ms.get("d", 0)), int(ms.get("l", 0)),
		int(round(100.0 * (int(ms.get("w", 0)) * 3 + int(ms.get("d", 0))) / (games * 3.0))), (w.stats.get("ach", []) as Array).size(), SeasonReview.ACH_ORDER.size()], "Small", true))
	return UIKit.card_panel(card)
