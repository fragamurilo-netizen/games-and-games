class_name EventKit
extends RefCounted
## Peças das telas de montagem dos eventos: o termômetro de hype com os motivos, as etiquetas
## de uma luta (cinturão interino, rivalidade, revanche), o card em blocos (luta principal,
## co-principal, card principal, preliminares) e os cartões de sede, ingresso e contrato de TV.
## Cores só da paleta: o termômetro vai do azul (frio) ao vermelho (pegando fogo).


## Cor da faixa do termômetro em que o valor está.
static func tone_color(v: float) -> Color:
	match Hype.tone(v):
		0:
			return UIColors.BLUE
		1:
			return UIColors.MUTED
		2:
			return UIColors.MUTED.lerp(UIColors.ORANGE, 0.6)
		3:
			return UIColors.ORANGE
	return UIColors.RED


## "+10", "−4", "+2,5".
static func pts_text(p: float) -> String:
	var a := absf(p)
	var s := str(int(round(a)))
	if a < 9.95 and absf(a - round(a)) > 0.05:
		s = Fmt.dec(a, 1)
	return ("+" if p > 0.0 else "−") + s


## Lista de motivos: o texto à esquerda e os pontos que ele soma (verde) ou tira (vermelho).
static func reasons(parent: Container, rs: Array, limit: int = 0) -> void:
	var n := 0
	for r: Array in rs:
		if limit > 0 and n >= limit:
			break
		var pts := float(r[1])
		var h := UIKit.hbox(10)
		var l := UIKit.label(String(r[0]), "Small", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if absf(pts) >= 0.05:
			var t := UIKit.colored(pts_text(pts), UIColors.GREEN if pts > 0.0 else UIColors.RED, "Small")
			t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			h.add_child(t)
		parent.add_child(h)
		n += 1


## O termômetro: nome da faixa, o número, a barra de cinco faixas e os motivos. `h` é o que
## `Hype.event` ou `Hype.pair` devolvem. Com `main` (noite), os motivos da luta principal vêm
## embaixo.
## `limit` > 0 mostra só os motivos que mais pesam (para folhas e cartões pequenos).
static func thermometer(h: Dictionary, title: String = "Termômetro da noite", note: String = "", boxed: bool = true, limit: int = 0) -> Control:
	var v := float(h.get("value", 0.0))
	var col := tone_color(v)
	var card := UIKit.card("Card", UITokens.S1) if boxed else UIKit.vbox(UITokens.S1)
	var head := UIKit.hbox(12)
	var tl := UIKit.vbox(0)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.add_child(UIKit.eyebrow(title))
	tl.add_child(UIKit.colored(Hype.label(v), col, "Section"))
	head.add_child(tl)
	var num := UIKit.colored(str(int(round(v))), col, "Title")
	num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(num)
	card.add_child(head)
	var hb := HeatBar.new()
	hb.value = v
	card.add_child(hb)
	var rs: Array = h.get("reasons", [])
	if limit > 0 and rs.size() > limit:
		var order: Array = rs.duplicate()
		order.sort_custom(func(x: Array, y: Array) -> bool: return absf(float(x[1])) > absf(float(y[1])))
		var keep: Array = order.slice(0, limit)
		var rest := 0.0
		for r: Array in order.slice(limit):
			rest += float(r[1])
		reasons(card, rs.filter(func(r: Array) -> bool: return keep.has(r)))
		reasons(card, [["E mais %s" % Fmt.plural(rs.size() - limit, "motivo menor", "motivos menores"), rest]])
	else:
		reasons(card, rs)
	var main: Dictionary = h.get("main", {})
	var mrs: Array = main.get("reasons", [])
	if not mrs.is_empty():
		card.add_child(UIKit.separator())
		card.add_child(UIKit.eyebrow("Por que a luta principal vende"))
		reasons(card, mrs)
	if note != "":
		card.add_child(UIKit.label(note, "Small", true))
	return UIKit.card_panel(card) if boxed else card


## Linha curta para listas: "Hype 74 · Quente" na cor da faixa.
static func hype_tag(v: float, long: bool = false) -> Label:
	var t := "Hype %d · %s" % [int(round(v)), Hype.label(v)] if long else "Hype %d" % int(round(v))
	return UIKit.colored(t, tone_color(v), "Caps")


## Etiqueta que mais importa numa luta: [texto, cor] ("" quando não há).
static func bout_tag(w: GameWorld, b: Bout) -> Array:
	if b.interim:
		return ["Cinturão interino", UIColors.GOLD]
	if b.title:
		var it := int(w.interim.get(b.division, -1))
		if it >= 0 and b.has(it) and b.has(int(w.champions.get(b.division, -1))):
			return ["Unificação", UIColors.GOLD]
		return ["Cinturão" if b.title_for < 0 else "Cinturão vago", UIColors.GOLD]
	var heat := Rivalry.heat(w, w.fighter(b.a), w.fighter(b.b))
	if heat >= 20.0:
		return [Rivalry.label(heat), UIColors.ORANGE]
	return ["", Color(0, 0, 0, 0)]


## "Revanche", "Trilogia"... só antes de a luta acontecer.
static func rematch_text(w: GameWorld, b: Bout) -> String:
	if b.status != "marcada":
		return ""
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	return Rivalry.rematch_kind(fa, fb) if fa != null and fb != null else ""


## O card em blocos, da luta principal para as preliminares. `cb` recebe a luta tocada.
static func card_blocks(w: GameWorld, ev: FightEvent, cb: Callable, with_hype: bool = true) -> VBoxContainer:
	var box := UIKit.vbox(UITokens.S2)
	var lst := Card.bouts(w, ev)
	var by := {}
	for b: Bout in lst:
		var s := Card.slot(w, ev, b)
		if not by.has(s):
			by[s] = []
		(by[s] as Array).push_front(b)
	for s: String in Card.SLOT_ORDER:
		var group: Array = by.get(s, [])
		if group.is_empty():
			continue
		var title := Card.slot_name(s)
		if s == "prelim" or (s == "card" and group.size() > 1):
			title = "%s · %s" % [title, Fmt.plural(group.size(), "luta", "lutas")]
		box.add_child(UIKit.section_header(title))
		for b: Bout in group:
			var bb := b
			var row_cb := Callable()
			if cb.is_valid():
				row_cb = func(): cb.call(bb)
			box.add_child(OrgKit.bout_row(w, b, row_cb, true, Hype.bout_value(w, b) if with_hype and b.status == "marcada" else -1.0, false))
	return box


## Cartão "Sede e ingressos" da noite: cidade, arena, preço e a procura contra a lotação.
static func venue_card(w: GameWorld, ev: FightEvent, pr: Dictionary, cb: Callable) -> PanelContainer:
	var card := UIKit.card("Card", UITokens.S1)
	var locked := Venue.locked(w, ev)
	card.add_child(UIKit.section_header("Sede e ingressos", "Mudar" if not (ev.done or ev.closed) else "", cb))
	card.add_child(UIKit.kv("Sede", "%s, %s" % [ev.city, DataDB.nation_name(ev.nation)]))
	card.add_child(UIKit.kv(Venue.type_name(ev), "%s lugares" % Fmt.thousands(int(pr.get("capacity", Venue.capacity(ev))))))
	card.add_child(UIKit.kv("Ingresso %s" % String(Venue.PRICE_NAMES[clampi(ev.ticket, 0, 4)]).to_lower(), Fmt.money(float(pr.get("ticket", 0.0)))))
	var cap := int(pr.get("capacity", 1))
	var want := int(pr.get("demand", 0))
	var crowd := int(pr.get("crowd", 0))
	card.add_child(UIKit.kv("Procura", "%s pessoas" % Fmt.thousands(want), UIColors.GREEN if want >= cap else (UIColors.ORANGE if want >= cap * 0.75 else UIColors.RED)))
	var note := Venue.fill_text(ev, crowd)
	if want > cap * 1.5:
		note = "Casa cheia com folga: %s ficam de fora. Cabe um lugar maior ou um ingresso mais caro." % Fmt.thousands(want - cap)
	card.add_child(UIKit.label(note, "Small", true))
	if locked and not (ev.done or ev.closed):
		card.add_child(UIKit.colored("Ingressos à venda: sede e arena não mudam mais. O preço ainda pode mudar.", UIColors.MUTED, "Small", true))
	return UIKit.card_panel(card)


## Cartão do contrato de TV em vigor (e o aviso de propostas na mesa).
static func tv_card(w: GameWorld, cb: Callable) -> PanelContainer:
	TVDeal.ensure(w)
	var p := TVDeal.partner_of(w)
	var card := UIKit.card("CardHighlight" if TVDeal.pending(w) else "Card", UITokens.S1)
	card.add_child(UIKit.section_header("Contrato de TV", "Propostas" if TVDeal.pending(w) else "Ver", cb))
	var head := UIKit.hbox(8)
	var nm := UIKit.label(String(p["name"]), "H3")
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nm)
	head.add_child(UIKit.label(String(p["kind"]), "Caps"))
	card.add_child(head)
	card.add_child(UIKit.kv("Por Fight Night", Fmt.money(float(w.tv.get("fee", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Por evento numerado", Fmt.money(float(w.tv.get("fee_ppv", 0.0))), UIColors.GREEN))
	card.add_child(UIKit.kv("Pay-per-view", "é da organização" if float(p["ppv_k"]) > 0.0 else "dentro do contrato"))
	var left := TVDeal.weeks_left(w)
	card.add_child(UIKit.kv("Termina", "em %s" % Fmt.plural(left, "semana", "semanas"), UIColors.ORANGE if left <= TVDeal.NOTICE else UIColors.TEXT))
	if w.tv.has("next"):
		var nx: Dictionary = w.tv["next"]
		card.add_child(UIKit.colored("Depois entra a %s, já assinada." % String(TVDeal.partner(String(nx["partner"]))["name"]), UIColors.GREEN, "Small", true))
	elif TVDeal.pending(w):
		card.add_child(UIKit.colored("%s na mesa. Sem decisão até o fim, o contrato renova por seis meses pagando menos." % Fmt.plural(w.tv_offers.size(), "proposta", "propostas"), UIColors.ORANGE, "Small", true))
	return UIKit.card_panel(card)


## Tabela pequena de comparação: a primeira coluna à esquerda, as outras alinhadas à direita.
## A linha escolhida fica em destaque; `colors` (opcional) pinta a última coluna de cada linha.
static func mini_table(headers: Array, rows: Array, selected: int = -1, colors: Array = []) -> GridContainer:
	var g := GridContainer.new()
	g.columns = headers.size()
	g.add_theme_constant_override(&"h_separation", 14)
	g.add_theme_constant_override(&"v_separation", 6)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in headers.size():
		var hl := UIKit.label(String(headers[i]), "Caps")
		hl.add_theme_color_override(&"font_color", UIColors.DIM)
		if i == 0:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(hl)
	for r in rows.size():
		var row: Array = rows[r]
		for i in row.size():
			var l := UIKit.label(String(row[i]), "Small")
			l.add_theme_font_override(&"font", DataTable.tabular_font())
			var col := UIColors.TEXT if r == selected or selected < 0 else UIColors.MUTED
			if i == row.size() - 1 and r < colors.size() and (colors[r] as Color).a > 0.0:
				col = colors[r]
			l.add_theme_color_override(&"font_color", col)
			if i == 0:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if r == selected:
					l.text = "› " + l.text
			else:
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			g.add_child(l)
	return g


## Tabela que escolhe: cada linha é um toque. `widths` = largura das colunas depois da primeira.
## `cb` recebe o índice da linha; `locked` desliga os toques.
static func pick_table(headers: Array, rows: Array, widths: Array, selected: int, cb: Callable, colors: Array = [], locked: bool = false) -> VBoxContainer:
	var box := UIKit.vbox(2)
	var head := UIKit.hbox(10)
	for i in headers.size():
		var hl := UIKit.label(String(headers[i]), "Caps")
		hl.add_theme_color_override(&"font_color", UIColors.DIM)
		if i == 0:
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			hl.custom_minimum_size.x = float(widths[i - 1])
			hl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(hl)
	box.add_child(UIKit.margin(head, 12, 0, 12, 0))
	for r in rows.size():
		var row: Array = rows[r]
		var h := UIKit.hbox(10)
		for i in row.size():
			var l := UIKit.label(String(row[i]), "H3" if i == 0 else "Small")
			if i > 0:
				l.add_theme_font_override(&"font", DataTable.tabular_font())
			var col := UIColors.TEXT if r == selected else UIColors.MUTED
			if i == row.size() - 1 and r < colors.size() and (colors[r] as Color).a > 0.0:
				col = colors[r]
			l.add_theme_color_override(&"font_color", col)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if i == 0:
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			else:
				l.custom_minimum_size.x = float(widths[i - 1])
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(l)
		var idx := r
		var tap := UIKit.tap_row(h, (func(): cb.call(idx)) if not locked else Callable(), "RowPanel", true)
		tap.custom_minimum_size.y = 58
		UIKit.set_row_selected(tap, r == selected)
		if locked and r != selected:
			tap.modulate.a = 0.6
		box.add_child(tap)
	return box


## Desliga os botões de um seletor (quando a escolha está travada).
static func lock_segment(seg: Control) -> void:
	for b in seg.find_children("*", "Button", true, false):
		(b as Button).disabled = true
