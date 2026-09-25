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

var _filter := "all"


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
	var unread := InboxManager.unread_count(w)
	screen_subtitle = "%d não lida(s)" % unread if unread > 0 else "Tudo lido"
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var chips := UIKit.flow(8)
	for f in FILTERS:
		var key: String = f[0]
		var chip := UIKit.chip(f[1], key == _filter, g, func():
			_filter = key
			refresh())
		chip.add_theme_font_size_override(&"font_size", 18)
		chips.add_child(chip)
	c.add_child(chips)
	if not w.inbox.is_empty():
		var tools := UIKit.hbox(10)
		var all_read := UIKit.button("Marcar todas como lidas", "GhostButton", func():
			InboxManager.mark_all_read(w)
			GameManager.save_now()
			refresh(), "check")
		all_read.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		all_read.disabled = unread == 0
		tools.add_child(all_read)
		var clean := UIKit.button("Limpar lidas", "GhostButton", func():
			var n := InboxManager.delete_read(w)
			GameManager.save_now()
			UIManager.toast("%d mensagem(ns) apagada(s)" % n if n > 0 else "Nada para apagar")
			refresh(), "close")
		clean.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(clean)
		c.add_child(tools)
	var items: Array = w.inbox.duplicate()
	items.reverse()
	var shown := 0
	var last_key := ""
	for m: Dictionary in items:
		if not _passes(w, m):
			continue
		var key := "%d-%d" % [int(m["y"]), int(m["d"])]
		if key != last_key:
			last_key = key
			c.add_child(UIKit.section(date_of(w, m)))
		c.add_child(row(w, m, func(): refresh()))
		shown += 1
	if shown == 0:
		c.add_child(UIKit.label("Nenhuma mensagem aqui." if _filter != "all" else "A caixa de entrada está vazia. Relatórios, pedidos e propostas chegam aqui ao longo da temporada.", "Muted", true))


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


## Linha de mensagem (também usada no cartão da tela inicial).
static func row(w: GameWorld, m: Dictionary, on_change: Callable) -> Control:
	var unread := not bool(m.get("r", false))
	var open := InboxManager.action_open(w, m)
	var r := UIKit.hbox(12)
	var p := w.player(int(m.get("p", -1))) if String(m.get("f", "")) == "jogador" else null
	var cl := w.club(int(m.get("c", -1))) if String(m.get("f", "")) == "clube" else null
	if p != null:
		var pv := UIKit.portrait(p, w.club(p.club_id), w.year, 48)
		pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(pv)
	elif cl != null:
		var cv := UIKit.crest(cl, 44)
		cv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(cv)
	else:
		var ic := UIKit.icon_rect(InboxManager.icon_of(m), 30, UIColors.ACCENT if unread else UIColors.MUTED)
		ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		r.add_child(ic)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var who := String(m.get("n", ""))
	var role := InboxManager.role_of(m)
	var from := UIKit.label(who + ((" · " + role) if role != "" and role != who else ""), "Caps")
	from.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if unread:
		from.add_theme_color_override(&"font_color", UIColors.ACCENT)
	v.add_child(from)
	v.add_child(UIKit.label(String(m.get("s", "")), "H3" if unread else "", true))
	var preview := UIKit.label(String(m.get("b", "")).split("\n")[0], "Small")
	preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(preview)
	r.add_child(v)
	if open:
		var pill := UIKit.pill("RESPONDER", UIColors.ORANGE, 15)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(pill)
	return UIKit.tap_row(r, func(): open_message(m, on_change))


## Folha com a mensagem inteira e o atalho para resolver o assunto.
static func open_message(m: Dictionary, on_change: Callable = Callable()) -> void:
	var w := GameManager.world
	if w == null:
		return
	InboxManager.mark_read(m)
	var v := UIKit.vbox(14)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect(InboxManager.icon_of(m), 40, UIColors.ACCENT))
	head.add_child(UIKit.label(String(m.get("s", "")), "Title", true))
	v.add_child(head)
	var who := String(m.get("n", ""))
	var role := InboxManager.role_of(m)
	v.add_child(UIKit.label("De: %s%s · %s" % [who, (" (" + role + ")") if role != "" and role != who else "", date_of(w, m)], "Small", true))
	var p := w.player(int(m.get("p", -1)))
	if p != null:
		var pr := UIKit.hbox(12)
		pr.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 64))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3", true))
		var pc := w.club(p.club_id)
		col.add_child(UIKit.label("%d anos · %s · %s" % [p.age(w.year), Pos.name_of(p.position), pc.short_name if pc != null else "sem clube"], "Small", true))
		pr.add_child(col)
		pr.add_child(UIKit.badge(p.overall))
		v.add_child(pr)
	v.add_child(UIKit.label(String(m.get("b", "")), "", true))
	var btn := _action_button(w, m, on_change)
	if btn != null:
		v.add_child(btn)
	var bottom := UIKit.hbox(10)
	var del := UIKit.button("Apagar", "GhostButton", func():
		InboxManager.delete(w, int(m["id"]))
		UIManager.close_modal()
		GameManager.save_now()
		if on_change.is_valid():
			on_change.call(), "close")
	del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(del)
	var close := UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal())
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(close)
	v.add_child(bottom)
	UIManager.show_modal(v, true)
	if on_change.is_valid():
		on_change.call()


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
