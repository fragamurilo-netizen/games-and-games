class_name TutorialKit
extends RefCounted
## Interface do tutorial guiado: o cartão "Primeiros passos" do Início (o passo da vez, o botão
## que leva até lá e a opção de pular) e a dica de primeira vez no alto das telas. As regras
## estão em Tutorial.


## Cartão do Início, ou null quando o guia está desligado ou já acabou.
static func hub_card(w: GameWorld, on_change: Callable) -> Control:
	if not Tutorial.active(w):
		return null
	var steps := Tutorial.steps(w)
	var cur := Tutorial.current(w)
	var done := Tutorial.done_count(w)
	var card := UIKit.card("CardHighlight", UITokens.S2)
	var head := UIKit.hbox(8)
	var el := UIKit.eyebrow("Primeiros passos", UIColors.ACCENT)
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(el)
	head.add_child(UIKit.label("Passo %d de %d" % [done + 1, steps.size()], "Caps"))
	card.add_child(head)
	var pips := UIKit.hbox(4)
	for i in steps.size():
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(0, 5)
		pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pip.color = UIColors.GREEN if i < done else (UIColors.ACCENT if i == done else UIColors.SURFACE_3)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	card.add_child(pips)
	card.add_child(UIKit.label(String(cur[1]), "Section", true))
	card.add_child(UIKit.label(String(cur[2]), "Small", true))
	var bar := UIKit.hbox(UITokens.S1)
	var skip := UIKit.button("Pular o guia", "GhostButton", func():
		UIManager.confirm("Pular os primeiros passos?", "As dicas das telas continuam aparecendo na primeira vez. Dá para rever tudo jogando.", "Pular", func():
			Tutorial.skip(w)
			GameManager.save_now()
			on_change.call()))
	skip.custom_minimum_size.y = UITokens.H_BUTTON_SM
	skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(skip)
	var dest := String(cur[4])
	if dest != "":
		var go := UIKit.button(String(cur[3]), "PrimaryButton", func(): _go(w, dest))
		go.custom_minimum_size.y = UITokens.H_BUTTON_SM
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.size_flags_stretch_ratio = 1.4
		go.clip_text = true
		bar.add_child(go)
	else:
		card.add_child(UIKit.colored("Acontece na semana da luta. Avance as semanas até lá.", UIColors.MUTED, "Caps", true))
	card.add_child(bar)
	return UIKit.card_panel(card)


static func _go(w: GameWorld, dest: String) -> void:
	if dest.begins_with("area:"):
		UIManager.switch_area(dest.substr(5))
	elif dest.begins_with("push:"):
		UIManager.push(dest.substr(5))
	elif dest.begins_with("fighter:"):
		var mine := w.user_fighters()
		if mine.is_empty():
			UIManager.switch_area("market")
		else:
			UIManager.push("fighter", {"id": (mine[0] as Fighter).id, "tab": dest.substr(8)})
	elif dest == "next_event" or dest == "next_venue":
		var ups := Org.upcoming_events(w).filter(func(e: FightEvent) -> bool: return e.week > w.week)
		if dest == "next_venue":
			var open := ups.filter(func(e: FightEvent) -> bool: return not Venue.locked(w, e))
			if not open.is_empty():
				ups = open
		if ups.is_empty():
			UIManager.switch_area("events")
		else:
			UIManager.push("venue" if dest == "next_venue" else "org_event", {"id": (ups[0] as FightEvent).id})


## Passos que acabaram de ser cumpridos: avisa e devolve se algum saiu.
static func sync(w: GameWorld) -> bool:
	var done := Tutorial.sync(w)
	if done.is_empty():
		return false
	if UIManager.main != null:
		for i in done.size():
			UIManager.award_toast("Passo concluído", String(done[i]), "check", i == 0)
		if bool(w.tut.get("finished", false)):
			UIManager.toast("Primeiros passos concluídos. Agora a temporada é sua.", UIColors.GREEN)
	return true


## Dica de primeira vez: entra no alto do conteúdo da tela, uma vez por carreira. Chamar no fim
## de `refresh()` (depois das colunas). Continua visível enquanto a tela estiver aberta.
static func tip(screen: BaseScreen, key: String) -> void:
	var w := GameManager.world
	if w == null or screen == null or screen.content() == null:
		return
	var showing := String(screen.get_meta(&"tip", "")) == key
	if not showing and not Tutorial.tip_due(w, key):
		return
	if not showing:
		Tutorial.tip_seen(w, key)
		screen.set_meta(&"tip", key)
	var d: Array = Tutorial.TIPS[key]
	var card := UIKit.card("CardFlat", UITokens.S1)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.icon_rect("info", 22, UIColors.ACCENT))
	var t := UIKit.colored("Dica · %s" % String(d[0]), UIColors.ACCENT, "Caps")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	card.add_child(head)
	card.add_child(UIKit.label(String(d[1]), "Small", true))
	var p := UIKit.card_panel(card)
	var bar := UIKit.hbox(UITokens.S1)
	var off := UIKit.button("Não mostrar dicas", "TextButton", func():
		Tutorial.tips_off(w)
		screen.remove_meta(&"tip")
		p.queue_free())
	off.add_theme_color_override(&"font_color", UIColors.MUTED)
	bar.add_child(off)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)
	var ok := UIKit.button("Entendi", "TextButton", func():
		screen.remove_meta(&"tip")
		p.queue_free())
	bar.add_child(ok)
	card.add_child(bar)
	var c := screen.content()
	c.add_child(p)
	c.move_child(p, 0)
