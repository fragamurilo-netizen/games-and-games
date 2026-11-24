class_name InboxKit
extends RefCounted
## Peças da caixa de entrada: a linha de uma mensagem, o cartão de uma pendência com os botões
## de ação, a folha com a mensagem inteira e quem executa cada ação. As regras estão em Inbox.

const CAT_ICON := {"luta": "glove", "equipe": "users", "contrato": "book", "olheiro": "search", "financas": "money",
	"noite": "bell", "tv": "play", "cinturao": "belt", "mundo": "globe"}
const MAIN_LABEL := {"offer": "Ver proposta", "fight_plan": "Plano de luta", "talk": "Conversar", "renew": "Renovar contrato",
	"camp": "Montar o camp", "fighter": "Abrir a ficha", "market": "Ir ao Mercado", "gym": "Ver as contas", "incident": "Decidir",
	"night": "Ir para a noite", "tv": "Ver propostas", "org_event": "Montar o card", "venue": "Sede e ingressos", "book_div": "Marcar a luta"}


static func cat_color(cat: String) -> Color:
	match cat:
		"cinturao":
			return UIColors.GOLD
		"financas":
			return UIColors.RED
		"equipe", "contrato":
			return UIColors.ORANGE
		"olheiro", "tv":
			return UIColors.BLUE
		"mundo":
			return UIColors.MUTED
	return UIColors.ACCENT


static func when_text(w: GameWorld, m: Dictionary) -> String:
	return w.weeks_from_now(int(m["wk"]))


static func _arg_id(m: Dictionary, key: String = "id") -> int:
	return int((m.get("arg", {}) as Dictionary).get(key, -1))


static func _offer(w: GameWorld, id: int) -> Dictionary:
	for o: Dictionary in w.offers:
		if int(o["id"]) == id:
			return o
	return {}


static func _incident(w: GameWorld, id: int) -> Dictionary:
	for i: Dictionary in w.incidents:
		if int(i["id"]) == id:
			return i
	return {}


## A próxima noite com vaga para uma disputa de cinturão (de preferência um evento numerado
## ainda sem cinturão), a pelo menos três semanas.
static func title_night(w: GameWorld) -> FightEvent:
	var best: FightEvent = null
	for ev: FightEvent in Org.upcoming_events(w):
		if ev.week - w.week < 3 or Org.event_bouts(w, ev).size() >= ev.slots:
			continue
		if best == null:
			best = ev
		if ev.ppv and not Card.has_belt(w, ev):
			return ev
	return best


## A ação principal da mensagem (o toque na linha no Início; o botão cheio na caixa).
static func run(w: GameWorld, m: Dictionary, on_change: Callable) -> void:
	var act := String(m["act"])
	Inbox.mark_read(m)
	match act:
		"offer":
			if _offer(w, _arg_id(m)).is_empty():
				UIManager.toast("Essa proposta não está mais na mesa.")
				on_change.call()
			else:
				UIManager.push("offer", {"id": _arg_id(m)})
		"fight_plan":
			UIManager.push("fight_plan", {"bout": _arg_id(m, "bout")})
		"talk":
			var f := w.fighter(_arg_id(m))
			if f != null and Morale.talk_wait(w, f) == 0:
				TalkSheet.open(w, f, on_change)
			elif f != null:
				UIManager.push("fighter", {"id": f.id})
		"renew":
			var f2 := w.fighter(_arg_id(m))
			if f2 != null:
				UIManager.push("fighter", {"id": f2.id, "tab": "contrato"})
		"camp":
			Inbox.handle(m)
			UIManager.push("fighter", {"id": _arg_id(m), "tab": "treino"})
		"fighter":
			if bool(m.get("pend", false)):
				Inbox.handle(m)
			if w.fighter(_arg_id(m)) != null:
				UIManager.push("fighter", {"id": _arg_id(m)})
		"market":
			UIManager.switch_area("market")
		"gym":
			UIManager.switch_area("org" if w.is_president() else "gym")
		"incident":
			var i := _incident(w, _arg_id(m))
			if i.is_empty() or bool(i.get("done", false)):
				UIManager.toast("Isso já foi resolvido.")
				on_change.call()
			else:
				WeekKit.open_incident(w, i, on_change)
		"night":
			UIManager.push("night", {"id": _arg_id(m)})
		"tv":
			UIManager.push("tv")
		"org_event":
			UIManager.push("org_event", {"id": _arg_id(m)})
		"venue":
			Inbox.handle(m)
			UIManager.push("venue", {"id": _arg_id(m)})
		"book_div":
			var ev := title_night(w)
			if ev == null:
				UIManager.toast("Nenhuma noite com vaga daqui a três semanas ou mais. Abra espaço num card.", UIColors.RED)
			else:
				UIManager.push("book", {"event": ev.id, "div": String((m.get("arg", {}) as Dictionary).get("div", ""))})


## Botões da mensagem: [{text, style, cb}], o principal por último (fica à direita).
static func buttons(w: GameWorld, m: Dictionary, on_change: Callable) -> Array:
	var out: Array = []
	var act := String(m["act"])
	if act == "none" or (bool(m.get("pend", false)) and int(m["st"]) == Inbox.CLOSED):
		return out
	if act == "offer":
		var o := _offer(w, _arg_id(m))
		if o.is_empty():
			return out
		out.append({"text": "Recusar", "style": "GhostButton", "cb": func():
			w.offers.erase(o)
			GameManager.save_now()
			UIManager.toast("Proposta recusada.")
			on_change.call()})
		out.append({"text": "Detalhes", "style": "GhostButton", "cb": func(): run(w, m, on_change)})
		out.append({"text": "Aceitar", "style": "PrimaryButton", "cb": func():
			var f := w.fighter(int(o["fighter"]))
			var opp := w.fighter(int(o["opp"]))
			var err := Matchmaker.accept_offer(w, o)
			if err != "":
				UIManager.toast(err, UIColors.RED)
			else:
				Sfx.play("sign", -4.0)
				UIManager.toast("Luta fechada: %s × %s." % [f.short_name(), opp.short_name()], UIColors.GREEN)
			GameManager.save_now()
			on_change.call()})
		return out
	if act == "renew":
		var rf := w.fighter(_arg_id(m))
		if rf == null:
			return out
		out.append({"text": "Ver contrato", "style": "GhostButton", "cb": func(): run(w, m, on_change)})
		out.append({"text": "Renovar por 5 lutas", "style": "PrimaryButton", "cb": func():
			var r := Signing.renew(w, rf, 0.2, 5)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			GameManager.save_now()
			on_change.call()})
		return out
	if act == "org_event" and bool(m.get("pend", false)):
		var ev := w.event(_arg_id(m))
		if ev != null and Org.event_bouts(w, ev).size() < ev.slots:
			out.append({"text": "Completar", "style": "GhostButton", "cb": func():
				var n := Org.auto_fill(w, ev)
				GameManager.save_now()
				UIManager.toast("O matchmaker fechou %s." % Fmt.plural(n, "luta", "lutas") if n > 0 else "Ninguém disponível para completar o card.")
				on_change.call()})
	if act == "talk":
		out.append({"text": "Ficha", "style": "GhostButton", "cb": func(): UIManager.push("fighter", {"id": _arg_id(m)})})
	out.append({"text": String(MAIN_LABEL.get(act, "Abrir")), "style": "PrimaryButton" if Inbox.is_open(m) else "GhostButton", "cb": func(): run(w, m, on_change)})
	return out


static func _faces(w: GameWorld, m: Dictionary, px: int) -> Control:
	var ids: Array = m.get("f", [])
	var h := UIKit.hbox(4)
	h.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	for id in ids.slice(0, 2):
		var f := w.fighter(int(id))
		if f != null:
			h.add_child(FightKit.portrait(w, f, px))
	if h.get_child_count() == 0:
		var tile := PanelContainer.new()
		tile.theme_type_variation = "IconTile"
		tile.custom_minimum_size = Vector2(px, px)
		var ic := UIKit.icon_rect(String(CAT_ICON.get(String(m["cat"]), "mail")), int(px * 0.5), cat_color(String(m["cat"])))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_child(ic)
		h.add_child(tile)
	return h


static func _head(w: GameWorld, m: Dictionary) -> HBoxContainer:
	var h := UIKit.hbox(8)
	if not bool(m.get("rd", false)):
		var dot := UnreadDot.new()
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(dot)
	var from := UIKit.colored(String(m["from"]), cat_color(String(m["cat"])), "Caps")
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	from.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(from)
	h.add_child(UIKit.label(when_text(w, m), "Caps"))
	return h


## Linha compacta: quem mandou, título e uma linha do texto. `cb` vazio = a ação principal.
static func row(w: GameWorld, m: Dictionary, on_change: Callable, cb: Callable = Callable(), lines: int = 2) -> PanelContainer:
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(_faces(w, m, 48 if lines <= 1 else 56))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_head(w, m))
	var pend := bool(m.get("pend", false))
	if pend:
		var t := UIKit.label(String(m["t"]), "H3")
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(t)
	var x := UIKit.label(String(m["x"]), "Small" if pend else "", true)
	x.max_lines_visible = lines if pend else lines + 2
	x.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(x)
	h.add_child(v)
	if Inbox.is_open(m) or String(m["act"]) != "none":
		var ic := UIKit.icon_rect("forward", 20, UIColors.DIM)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var go := cb if cb.is_valid() else (func(): run(w, m, on_change))
	return UIKit.tap_row(h, go if String(m["act"]) != "none" or cb.is_valid() else Callable())


## Cartão de pendência na caixa de entrada: a mensagem inteira e os botões de ação.
static func card(w: GameWorld, m: Dictionary, on_change: Callable) -> PanelContainer:
	var c := UIKit.card("CardHighlight" if Inbox.is_open(m) else "Card", UITokens.S1)
	c.add_child(_head(w, m))
	var h := UIKit.hbox(UITokens.S2)
	h.add_child(_faces(w, m, 64))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label(String(m["t"]), "H3", true))
	v.add_child(UIKit.label(String(m["x"]), "Small", true))
	h.add_child(v)
	c.add_child(h)
	var st := int(m["st"])
	if st == Inbox.CLOSED:
		c.add_child(UIKit.label("Resolvido", "Caps"))
	else:
		var btns := buttons(w, m, on_change)
		if not btns.is_empty():
			var bar := UIKit.hbox(UITokens.S1)
			for b: Dictionary in btns:
				var cb: Callable = b["cb"]
				var btn := UIKit.button(String(b["text"]), String(b["style"]), cb)
				btn.custom_minimum_size.y = UITokens.H_BUTTON_SM
				btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				btn.size_flags_stretch_ratio = 1.4 if String(b["style"]) == "PrimaryButton" else 1.0
				btn.clip_text = true
				bar.add_child(btn)
			c.add_child(bar)
	return UIKit.card_panel(c)


## Bloco "Para resolver" do Início: as pendências mais urgentes, cada uma a um toque da ação.
## Devolve null quando não há nenhuma.
static func todo_block(w: GameWorld, on_change: Callable, limit: int = 4) -> Control:
	var pend := Inbox.pending(w)
	var v := UIKit.vbox(UITokens.S1)
	var link := "Caixa de entrada"
	v.add_child(UIKit.section_header("Para resolver" + (" (%d)" % pend.size() if not pend.is_empty() else ""), link, func(): UIManager.push("inbox")))
	if pend.is_empty():
		var ok := UIKit.hbox(UITokens.S2)
		ok.add_child(UIKit.icon_rect("check", 24, UIColors.GREEN))
		var l := UIKit.label("Nada esperando decisão. Pode avançar a semana.", "Small", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ok.add_child(l)
		v.add_child(ok)
		return v
	var rows: Array = []
	for m: Dictionary in pend.slice(0, limit):
		rows.append(row(w, m, on_change, Callable(), 1))
	v.add_child(UIKit.menu_group(rows))
	if pend.size() > limit:
		var more := UIKit.button("Mais %s na caixa de entrada" % Fmt.plural(pend.size() - limit, "pendência", "pendências"), "TextButton", func(): UIManager.push("inbox"))
		v.add_child(more)
	return v


## Pontinho de mensagem não lida.
class UnreadDot extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(12, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(size * 0.5, 5.0, UIColors.ACCENT)
