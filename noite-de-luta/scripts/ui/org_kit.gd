class_name OrgKit
extends RefCounted
## Peças das telas do presidente e do "fã que acompanha o mundo": o duelo (corner vermelho ×
## corner azul), o cartão de uma noite da liga, as contas da noite e a lista de quem o jogador
## segue. Seguem o DESIGN.md: vermelho e azul só dentro da luta, ouro só para cinturão.


## Duelo: categoria e rounds em cima; os dois lutadores frente a frente; o resultado embaixo.
static func bout_row(w: GameWorld, b: Bout, cb: Callable = Callable(), with_result: bool = true) -> PanelContainer:
	var v := UIKit.vbox(6)
	var cap := UIKit.hbox(8)
	var parts: Array = []
	if b.main_event:
		parts.append("Luta principal")
	parts.append(Matchmaker.division_short(b.division))
	parts.append("%d rounds" % b.rounds)
	var cl := UIKit.label(" · ".join(parts), "Caps")
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap.add_child(cl)
	if b.title:
		cap.add_child(UIKit.colored("Cinturão", UIColors.GOLD, "Caps"))
	v.add_child(cap)
	var h := UIKit.hbox(UITokens.S1)
	var wid := int(b.result.get("winner_id", -1)) if b.status == "feita" else -2
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		var side := UIKit.hbox(8)
		side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := ColorRect.new()
		bar.color = UIColors.CORNER_RED if i == 0 else UIColors.CORNER_BLUE
		bar.custom_minimum_size = Vector2(4, 56)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var p := FightKit.portrait(w, f, 56)
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var n := UIKit.label(f.short_name(), "H3")
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var sub := UIKit.label("%s · %s" % [w.rank_text(f), f.record_text()], "Small")
		sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if w.rank_of(f) == 0:
			sub.add_theme_color_override(&"font_color", UIColors.GOLD)
		if wid == f.id:
			n.add_theme_color_override(&"font_color", UIColors.GREEN)
		elif wid >= 0:
			n.add_theme_color_override(&"font_color", UIColors.MUTED)
		tv.add_child(n)
		tv.add_child(sub)
		if i == 1:
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			side.add_child(tv)
			side.add_child(p)
			side.add_child(bar)
		else:
			side.add_child(bar)
			side.add_child(p)
			side.add_child(tv)
		h.add_child(side)
		if i == 0:
			var vs := UIKit.label("×", "Section")
			vs.add_theme_color_override(&"font_color", UIColors.DIM)
			vs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(vs)
	v.add_child(h)
	if with_result and b.status == "feita":
		var rt := FightKit.result_text(b)
		if wid >= 0:
			rt = "%s venceu: %s" % [w.fighter(wid).short_name(), rt.substr(0, 1).to_lower() + rt.substr(1)]
		if String(b.result.get("method", "")) == "DEC":
			rt += " (%s)" % FightKit.cards_text(b)
		v.add_child(UIKit.label(rt, "Small", true))
	var row := UIKit.tap_row(v, cb)
	return row


## Cartão de uma noite da liga: nome, tipo (pay-per-view ou Fight Night), data, cidade, quantas
## lutas o card tem e a luta principal frente a frente.
static func event_card(w: GameWorld, ev: FightEvent, cb: Callable) -> PanelContainer:
	var card := UIKit.card("CardHighlight" if ev.ppv else "Card", UITokens.S2)
	var head := UIKit.hbox(8)
	var t := UIKit.label(ev.name, "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(t)
	head.add_child(UIKit.colored("Pay-per-view" if ev.ppv else "Fight Night", UIColors.GOLD if ev.ppv else UIColors.MUTED, "Caps"))
	card.add_child(head)
	var lst := Org.event_bouts(w, ev)
	card.add_child(UIKit.label("%s · %s · %s" % [GameWorld.fight_date_text(ev.week), ev.city, w.weeks_from_now(ev.week)], "Small"))
	var main: Bout = null
	for b: Bout in lst:
		if b.main_event:
			main = b
	if main != null:
		card.add_child(FightKit.faceoff(w, w.fighter(main.a), w.fighter(main.b), 96))
		if main.title:
			card.add_child(UIKit.colored("Valendo o cinturão dos %s" % Matchmaker.division_name(main.division, true), UIColors.GOLD, "Small"))
	else:
		card.add_child(UIKit.colored("Sem luta principal", UIColors.ORANGE, "H3"))
	var fill := UIKit.hbox(8)
	var fl := UIKit.label("%d de %d lutas no card" % [lst.size(), ev.slots], "Small")
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.add_child(fl)
	if ev.closed:
		var profit := float(ev.report.get("profit", 0.0))
		fill.add_child(UIKit.colored(Fmt.money(profit), UIColors.GREEN if profit >= 0.0 else UIColors.RED, "H3"))
	else:
		var pr := Org.projection(w, ev)
		fill.add_child(UIKit.label("previsão " + Fmt.money(float(pr["profit"])), "Small"))
	card.add_child(fill)
	var row := UIKit.tap_row(UIKit.card_panel(card), cb, "PanelContainer")
	return row


## Contas da noite (projeção antes, fechamento depois).
static func money_card(r: Dictionary, title: String, ppv: bool) -> PanelContainer:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label(title, "Section"))
	card.add_child(UIKit.kv("Público", "%s de %s lugares" % [Fmt.thousands(int(r.get("crowd", 0))), Fmt.thousands(int(r.get("capacity", 0)))]))
	card.add_child(UIKit.kv("Bilheteria", Fmt.money(float(r.get("gate", 0.0))), UIColors.GREEN))
	if ppv:
		card.add_child(UIKit.kv("Pay-per-view (%s compras)" % Fmt.thousands(int(r.get("ppv_buys", 0))), Fmt.money(float(r.get("ppv", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Direitos de TV", Fmt.money(float(r.get("tv", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Patrocínio", Fmt.money(float(r.get("sponsors", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Bolsas", Fmt.money(-float(r.get("purses", 0.0))), UIColors.RED))
	card.add_child(UIKit.kv("Produção e arena", Fmt.money(-float(r.get("production", 0.0))), UIColors.RED))
	var bonus := float(r.get("bonus", r.get("bonuses", 0.0)))
	card.add_child(UIKit.kv("Bônus da noite", Fmt.money(-bonus), UIColors.RED))
	card.add_child(UIKit.separator())
	var profit := float(r.get("profit", 0.0))
	card.add_child(UIKit.kv("Resultado", Fmt.money(profit), UIColors.GREEN if profit >= 0.0 else UIColors.RED))
	return UIKit.card_panel(card)


## "Quem você acompanha": cada lutador seguido com a próxima luta ou o último resultado.
static func followed_section(w: GameWorld, c: VBoxContainer) -> void:
	var ids: Array = w.followed.filter(func(id: int) -> bool: return w.fighter(id) != null)
	if ids.is_empty():
		return
	c.add_child(UIKit.section_header("Quem você acompanha"))
	for id: int in ids:
		var f := w.fighter(id)
		var line := ""
		var col := Color(0, 0, 0, 0)
		var b := w.bout(f.bout_id)
		if f.retired:
			line = "Aposentado · " + f.record_text()
		elif b != null and b.status == "marcada":
			var ev := w.event(b.event_id)
			line = "contra %s · %s, %s" % [w.fighter(b.other(f.id)).short_name(), ev.name if ev != null else "", w.weeks_from_now(b.week)]
			col = UIColors.ACCENT
		elif not f.history.is_empty():
			var h: Dictionary = f.history.back()
			var res := String(h.get("res", ""))
			line = "%s contra %s (%s) · %s" % [{"V": "Venceu", "D": "Perdeu", "E": "Empatou"}.get(res, res), String(h.get("opp_name", "")), String(h.get("detail", "")), w.weeks_from_now(int(h.get("week", w.week)))]
			col = UIColors.GREEN if res == "V" else (UIColors.RED if res == "D" else Color(0, 0, 0, 0))
		else:
			line = "Sem luta marcada · " + f.record_text()
		c.add_child(FightKit.fighter_row(w, f, func(): UIManager.push("fighter", {"id": id}), line, col))
