class_name ScoutReportView
extends RefCounted
## Relatório do olheiro sobre um jogador: a recomendação, o quanto ele já foi visto, a faixa
## de nível hoje e do que pode virar, pontos fortes e fracos, personalidade e o que só se vê de
## perto, e os números da temporada. Embaixo, observar mais e descartar.


static func make(w: GameWorld, p: Player, on_change: Callable) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var know := Scouting.knowledge(w, p)
	var v := Scouting.verdict(w, p)
	# Cabeçalho: a letra da recomendação e o conhecimento.
	var head := UIKit.hbox(UITokens.S2)
	var grade := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(v["color"], 0.18)
	sb.border_color = v["color"]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(UITokens.R_SM)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	grade.add_theme_stylebox_override(&"panel", sb)
	var gl := UIKit.label(String(v["grade"]), "Title")
	gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gl.add_theme_color_override(&"font_color", UIColors.ink(v["color"]))
	grade.add_child(gl)
	grade.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(grade)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Relatório do olheiro", "Caps"))
	col.add_child(UIKit.colored(String(v["label"]), UIColors.ink(v["color"]), "Section"))
	col.add_child(_know_bar(know))
	head.add_child(col)
	card.add_child(head)
	card.add_child(UIKit.gap(UITokens.S1))
	var r := PlayerAssessment.report(w, p)
	card.add_child(UIKit.kv("Nível hoje", PlayerAssessment.range_text(r["low"], r["high"])))
	if p.age(w.year) <= 27:
		card.add_child(UIKit.kv("Pode chegar a", PlayerAssessment.range_text(r["future_low"], r["future_high"])))
	card.add_child(UIKit.kv("No seu elenco", PlayerAssessment.fit_text(w, p)))
	card.add_child(UIKit.kv("Estilo", PlayStyle.of(p)))
	var n := Scouting.notes(w, p)
	card.add_child(UIKit.kv("Pé", String(n["foot"])))
	_list(card, "Pontos fortes", n["strong"], UIColors.GREEN)
	_list(card, "Pontos fracos", n["weak"], UIColors.ORANGE)
	if know >= Scouting.KNOW_TRAITS:
		_list(card, "Personalidade", n["person"] if not (n["person"] as Array).is_empty() else ["Nada que chame atenção"], UIColors.TEXT)
	if know >= Scouting.KNOW_HIDDEN and not (n["risks"] as Array).is_empty():
		_list(card, "De perto", n["risks"], UIColors.TEXT)
	if know < Scouting.KNOW_HIDDEN:
		card.add_child(UIKit.label("Personalidade e histórico físico aparecem com %d%% de conhecimento." % (Scouting.KNOW_TRAITS if know < Scouting.KNOW_TRAITS else Scouting.KNOW_HIDDEN), "Small", true))
	# Números da temporada na liga dele.
	var apps := p.stats[Player.S_APPS]
	if apps > 0:
		card.add_child(UIKit.gap(UITokens.S1))
		card.add_child(UIKit.label("Temporada na liga", "Caps"))
		card.add_child(StatStrip.make([
			["Jogos", str(apps), UIColors.TEXT],
			["Gols", str(p.stats[Player.S_GOALS]), UIColors.TEXT],
			["Assist.", str(p.stats[Player.S_ASSISTS]), UIColors.TEXT],
			["Nota", Fmt.rating(LeagueStats.player_rating(p)), Fmt.match_rating_color(LeagueStats.player_rating(p))],
		]))
	# Ações do olheiro.
	card.add_child(UIKit.gap(UITokens.S1))
	var row := UIKit.hbox(UITokens.S2)
	var watching := false
	for j: Dictionary in Scouting.jobs(w):
		if String(j["k"]) == "jogador" and int(j.get("p", -1)) == p.id:
			watching = true
	if know < 100:
		var txt := "Olheiro observando" if watching else ("Observar de perto" if Scouting.can_send(w) else "Olheiros ocupados")
		var b := UIKit.button(txt, "SecondaryButton", func():
			if Scouting.watch_player(w, p):
				UIManager.toast("Olheiro a caminho: relatório completo em %s." % Fmt.plural(Scouting.job_length(w, {"k": "jogador", "p": p.id}), "rodada", "rodadas"), UIColors.GREEN)
				GameManager.save_now()
			if on_change.is_valid():
				on_change.call())
		b.disabled = watching or not Scouting.can_send(w)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	if Scouting.is_scouted(w, p):
		var d := UIKit.button("Descartar", "TextButton", func():
			Scouting.forget(w, p)
			GameManager.save_now()
			if on_change.is_valid():
				on_change.call())
		row.add_child(d)
	if row.get_child_count() > 0:
		card.add_child(row)
	return UIKit.card_panel(card)


static func _list(card: VBoxContainer, title: String, items: Array, color: Color) -> void:
	if items.is_empty():
		return
	card.add_child(UIKit.gap(4))
	card.add_child(UIKit.label(title, "Caps"))
	for it in items:
		var h := UIKit.hbox(UITokens.S1)
		var dot := ColorRect.new()
		dot.color = color
		dot.custom_minimum_size = Vector2(6, 6)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
		var l := UIKit.label(String(it), "", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		card.add_child(h)


## Conhecimento: barra fina e o número.
static func _know_bar(know: int) -> Control:
	var h := UIKit.hbox(UITokens.S1)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = know
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(120, 8)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var l := UIKit.label("%d%% visto" % know, "Small")
	l.add_theme_font_override(&"font", DataTable.tabular_font())
	h.add_child(l)
	return h
