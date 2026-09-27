class_name InboxScreen
extends BaseScreen
## Caixa de entrada do treinador: relatórios da comissão, cartas da diretoria, pedidos do elenco,
## propostas e convites. Cada mensagem pode levar direto para onde se resolve o assunto.

const FILTERS := [["all", "Todas"], ["unread", "Não lidas"], ["reply", "A responder"], ["diretoria", "Diretoria"],
	["comissao", "Comissão"], ["elenco", "Elenco"], ["mercado", "Mercado"]]

const SCREEN_LABELS := {
	"relations": "Falar com a diretoria", "kit": "Abrir uniforme e patrocínios", "squad": "Ver elenco",
	"prematch": "Escalação e tática", "training": "Abrir treino", "market": "Abrir mercado",
}

const GROUP_NAMES := {"diretoria": "Diretoria", "comissao": "Comissão técnica", "elenco": "Elenco", "mercado": "Mercado"}

var _filter := "all"
## Mensagem aberta no painel de leitura (telas largas: lista à esquerda, mensagem à direita).
var _open_id := -1


func _init() -> void:
	show_nav = false
	screen_title = "Caixa de entrada"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_filter = String(p.get("filter", "all"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	max_content_width = 1800
	var unread := InboxManager.unread_count(w)
	screen_subtitle = "%d não lida(s)" % unread if unread > 0 else "Tudo lido"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var pending := 0
	for m: Dictionary in w.inbox:
		if InboxManager.action_open(w, m):
			pending += 1
	# Resumo no topo: o que pede atenção agora.
	c.add_child(UIKit.stat_grid([
		UIKit.stat_tile(str(unread), "Não lidas", UIColors.ACCENT if unread > 0 else Color(0, 0, 0, 0)),
		UIKit.stat_tile(str(pending), "A responder", UIColors.ORANGE if pending > 0 else Color(0, 0, 0, 0)),
		UIKit.stat_tile(str(w.inbox.size()), "Mensagens"),
	], content_width()))
	var tabs: Array = []
	for f in FILTERS:
		var label: String = tr(f[1])
		if f[0] == "unread" and unread > 0:
			label += " · %d" % unread
		elif f[0] == "reply" and pending > 0:
			label += " · %d" % pending
		tabs.append([f[0], label])
	c.add_child(UIKit.scroll_tabs(tabs, _filter, func(k: String):
		_filter = k
		refresh()))
	var items: Array = w.inbox.duplicate()
	items.reverse()
	var shown: Array = []
	for m: Dictionary in items:
		if _passes(w, m):
			shown.append(m)
	var wide := UILayout.is_wide()
	var list := UIKit.vbox(UITokens.S3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not w.inbox.is_empty():
		var tools := UIKit.hbox(8)
		var count := UIKit.label(tr("%d mensagem(ns)") % shown.size(), "Caps")
		count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(count)
		var all_read := UIKit.button("Marcar lidas", "TextButton", func():
			InboxManager.mark_all_read(w)
			GameManager.save_now()
			refresh(), "check")
		all_read.disabled = unread == 0
		tools.add_child(all_read)
		tools.add_child(UIKit.button("Limpar lidas", "TextButton", func():
			var n := InboxManager.delete_read(w)
			GameManager.save_now()
			UIManager.toast("%d mensagem(ns) apagada(s)" % n if n > 0 else "Nada para apagar")
			refresh(), "close"))
		list.add_child(tools)
	# Mensagens agrupadas por dia, cada dia num cartão com filetes (como um cliente de e-mail).
	var last_key := ""
	var group: Array = []
	var on_change := func(): refresh()
	for m: Dictionary in shown:
		var key := "%d-%d" % [int(m["y"]), int(m["d"])]
		if key != last_key:
			if not group.is_empty():
				list.add_child(UIKit.menu_group(group))
			group = []
			last_key = key
			list.add_child(UIKit.eyebrow(date_of(w, m), UIColors.DIM))
		var cb := on_change
		if wide:
			var mid := int(m["id"])
			cb = func():
				InboxManager.mark_read(m)
				_open_id = mid
				refresh()
		group.append(row(w, m, on_change, cb, wide and int(m["id"]) == _open_id))
	if not group.is_empty():
		list.add_child(UIKit.menu_group(group))
	if shown.is_empty():
		var empty := UIKit.card("CardFlat", 10)
		empty.add_child(UIKit.icon_rect("mail", 48, UIColors.DIM))
		empty.add_child(UIKit.label("Nenhuma mensagem aqui." if _filter != "all" else "A caixa de entrada está vazia. Relatórios, pedidos e propostas chegam aqui ao longo da temporada.", "Muted", true))
		list.add_child(UIKit.card_panel(empty))
	if not wide:
		c.add_child(list)
		return
	# Tela larga: lista e painel de leitura lado a lado.
	var split := UIKit.hbox(UITokens.S5)
	c.add_child(split)
	list.size_flags_stretch_ratio = 0.9
	split.add_child(list)
	var open: Dictionary = {}
	for m: Dictionary in shown:
		if int(m["id"]) == _open_id:
			open = m
	if open.is_empty() and not shown.is_empty():
		open = shown[0]
		_open_id = int(open["id"])
		InboxManager.mark_read(open)
	var pane := UIKit.card("Card", 14)
	if open.is_empty():
		pane.add_child(UIKit.label("Escolha uma mensagem para ler.", "Muted"))
	else:
		pane.add_child(message_view(w, open, on_change, false))
	var pp := UIKit.card_panel(pane)
	pp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	split.add_child(pp)


func _passes(w: GameWorld, m: Dictionary) -> bool:
	match _filter:
		"unread":
			return not bool(m.get("r", false))
		"reply":
			return InboxManager.action_open(w, m)
		"all":
			return true
	return InboxManager.group_of(m) == _filter


static func date_of(w: GameWorld, m: Dictionary) -> String:
	if int(m["y"]) == w.year and w.season != null:
		var lbl := w.season.date_label(int(m["d"]), false)
		if lbl != "":
			return "%s · %d" % [lbl, int(m["y"])]
	return str(int(m["y"]))


## Linha de mensagem (também usada no cartão da tela inicial). `tap` troca o que o toque faz
## (no painel de leitura, só seleciona); `selected` destaca a linha aberta.
static func row(w: GameWorld, m: Dictionary, on_change: Callable, tap: Callable = Callable(), selected: bool = false) -> Control:
	var unread := not bool(m.get("r", false))
	var open := InboxManager.action_open(w, m)
	var r := UIKit.hbox(12)
	# Ponto de não lida: a mesma coluna sempre, para a lista não "pular".
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if unread:
		dot.draw.connect(func(): dot.draw_circle(Vector2(5, 5), 5, UIColors.ACCENT))
	r.add_child(dot)
	var p := w.player(int(m.get("p", -1))) if String(m.get("f", "")) == "jogador" else null
	var cl := w.club(int(m.get("c", -1))) if String(m.get("f", "")) == "clube" else null
	if p != null:
		var pv := UIKit.portrait(p, w.club(p.club_id), w.year, 52)
		pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pv)
	elif cl != null:
		var cv := UIKit.crest(cl, 48)
		cv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(cv)
	else:
		var tile := PanelContainer.new()
		tile.theme_type_variation = "IconTile"
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tile.add_child(UIKit.icon_rect(InboxManager.icon_of(m), 26, UIColors.ACCENT if unread else UIColors.MUTED))
		r.add_child(tile)
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var who := String(m.get("n", ""))
	var role := InboxManager.role_of(m)
	var from := UIKit.label((who + ((" · " + role) if role != "" and role != who else "")).to_upper(), "Caps")
	from.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if unread:
		from.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(from)
	var subj := UIKit.label(String(m.get("s", "")), "H3" if unread else "")
	subj.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if not unread:
		subj.add_theme_color_override(&"font_color", UIColors.MUTED)
	v.add_child(subj)
	var preview := UIKit.label(String(m.get("b", "")).split("\n")[0], "Small")
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(preview)
	r.add_child(v)
	if open:
		var pill := UIKit.pill("RESPONDER", UIColors.ORANGE, 15)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pill)
	var cb := tap if tap.is_valid() else func(): open_message(m, on_change)
	var tr_row := UIKit.tap_row(r, cb, "RowPanel", true)
	UIKit.set_row_selected(tr_row, selected)
	return tr_row


## Folha com a mensagem inteira e o atalho para resolver o assunto.
static func open_message(m: Dictionary, on_change: Callable = Callable()) -> void:
	var w := GameManager.world
	if w == null:
		return
	InboxManager.mark_read(m)
	UIManager.show_modal(message_view(w, m, on_change, true), true)
	if on_change.is_valid():
		on_change.call()


## Conteúdo da mensagem: cabeçalho com remetente, o texto e as ações. Vai na folha (celular)
## ou no painel de leitura (tela larga).
static func message_view(w: GameWorld, m: Dictionary, on_change: Callable, in_sheet: bool) -> VBoxContainer:
	var v := UIKit.vbox(14)
	var who := String(m.get("n", ""))
	var role := InboxManager.role_of(m)
	var group := InboxManager.group_of(m)
	var head := UIKit.hbox(14)
	var tile := PanelContainer.new()
	tile.theme_type_variation = "IconTile"
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_child(UIKit.icon_rect(InboxManager.icon_of(m), 34, UIColors.ACCENT))
	head.add_child(tile)
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIKit.eyebrow(String(GROUP_NAMES.get(group, "Mensagem"))))
	hv.add_child(UIKit.label(String(m.get("s", "")), "Title", true))
	head.add_child(hv)
	v.add_child(head)
	var meta := UIKit.hbox(10)
	var from := UIKit.label("%s%s" % [who, (" · " + role) if role != "" and role != who else ""], "Small", true)
	from.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(from)
	meta.add_child(UIKit.label(date_of(w, m), "Caps"))
	v.add_child(meta)
	var line := ColorRect.new()
	line.color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
	line.custom_minimum_size.y = 1
	v.add_child(line)
	var p := w.player(int(m.get("p", -1)))
	if p != null:
		var pr := UIKit.hbox(12)
		pr.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 72))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3", true))
		var pc := w.club(p.club_id)
		col.add_child(UIKit.label("%d anos · %s · %s" % [p.age(w.year), Pos.name_of(p.position), pc.short_name if pc != null else "sem clube"], "Small", true))
		pr.add_child(col)
		pr.add_child(UIKit.badge(p.overall))
		var pcard := UIKit.card("CardInset", 0)
		pcard.add_child(pr)
		v.add_child(UIKit.card_panel(pcard))
	v.add_child(UIKit.label(String(m.get("b", "")), "", true))
	var btn := _action_button(w, m, on_change)
	if btn != null:
		v.add_child(btn)
	var bottom := UIKit.hbox(10)
	var del := UIKit.button("Apagar", "GhostButton", func():
		InboxManager.delete(w, int(m["id"]))
		if in_sheet:
			UIManager.close_modal()
		GameManager.save_now()
		if on_change.is_valid():
			on_change.call(), "close")
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(del)
	if in_sheet:
		var close := UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal())
		close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom.add_child(close)
	v.add_child(bottom)
	return v


static func _action_button(w: GameWorld, m: Dictionary, on_change: Callable) -> Button:
	var a: Dictionary = m.get("a", {})
	var k := String(a.get("k", ""))
	if k == "":
		return null
	if InboxManager.is_request(m) and not InboxManager.action_open(w, m):
		var done := UIKit.button("Já respondida", "GhostButton", Callable(), "check")
		done.disabled = true
		return done
	var text := ""
	var icon := "forward"
	var cb := Callable()
	match k:
		"event":
			text = "Responder"
			cb = func():
				var ev := EventManager.find(w, int(a["id"]))
				if not ev.is_empty():
					EventDialog.open(ev, on_change)
		"talk":
			text = "Conversar"
			icon = "heart"
			cb = func(): TalkDialog.open(String(a["kind"]), int(a.get("t", -1)), on_change)
		"offers":
			text = "Ver propostas"
			icon = "swap"
			cb = func(): UIManager.goto("market", {"tab": "offers"})
		"job":
			text = "Ver o convite"
			cb = func(): UIManager.push("relations", {"tab": "board"})
		"player":
			if w.player(int(a["id"])) == null:
				return null
			text = "Ver jogador"
			icon = "shirt"
			cb = func(): UIManager.push("player", {"id": int(a["id"])})
		"club":
			text = "Ver clube"
			icon = "shield"
			cb = func(): UIManager.push("club", {"id": int(a["id"])})
		"screen":
			var s := String(a["s"])
			if s == "prematch" and (w.season == null or FixtureManager.next_fixture_for(w, w.user_club_id) == null):
				return null
			text = String(SCREEN_LABELS.get(s, "Abrir"))
			var args: Dictionary = a.get("args", {})
			cb = func():
				if s in UIManager.TABS:
					UIManager.goto(s, args)
				else:
					UIManager.push(s, args)
		_:
			return null
	var go := cb
	return UIKit.button(text, "PrimaryButton", func():
		UIManager.close_modal()
		go.call(), icon)
