class_name TutorialKit
extends RefCounted

static var force_tips := false
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
	# Compacto: o passo da vez com o botão que leva até lá; o andamento em pontinhos; pular no x.
	var card := UIKit.card("Card", UITokens.S1)
	var head := UIKit.hbox(8)
	var el := UIKit.kicker("Primeiros passos · %d de %d" % [done + 1, steps.size()])
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	el.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(el)
	var skip := UIKit.button("Pular", "TextButton", func():
		UIManager.confirm("Pular os primeiros passos?", "", "Pular", func():
			Tutorial.skip(w)
			GameManager.save_now()
			on_change.call()))
	skip.custom_minimum_size.y = 44
	skip.add_theme_color_override(&"font_color", UIColors.DIM)
	head.add_child(skip)
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
	var body := UIKit.hbox(UITokens.S2)
	var tv := UIKit.vbox(2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tv.add_child(UIKit.label(String(cur[1]), "Section", true))
	body.add_child(tv)
	var dest := String(cur[4])
	if dest != "":
		var go := UIKit.button(String(cur[3]), "PrimaryButton", func(): _go(w, dest))
		go.custom_minimum_size.y = UITokens.H_BUTTON_SM
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		body.add_child(go)
	card.add_child(body)
	if dest == "":
		card.add_child(UIKit.colored("Na semana da luta.", UIColors.MUTED, "Caps", true))
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
	# Faixas de dica desligadas: o jogo se explica jogando (pedido do dono, 1.2.0). `force_tips`
	# liga de volta para quem quiser testar.
	if not force_tips:
		return
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
	# Uma faixa fina: o ícone, o texto e o x. Um toque em qualquer ponto dela fecha. (Desligar as
	# dicas de vez fica nas Opções.)
	var row := UIKit.hbox(UITokens.S2)
	var ic := UIKit.icon_rect("info", 24, UIColors.ACCENT)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var t := UIKit.label(String(d[1]), "Small", true)
	# Duas linhas bastam para dizer do que se trata; o primeiro toque abre o resto.
	t.max_lines_visible = 2
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(t)
	var x := UIKit.icon_rect("close", 20, UIColors.DIM)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(x)
	var holder: Array = [null]
	var p := UIKit.tap_row(row, func():
		if t.max_lines_visible > 0 and t.get_line_count() > t.max_lines_visible:
			t.max_lines_visible = -1
			return
		screen.remove_meta(&"tip")
		if is_instance_valid(holder[0]):
			(holder[0] as Node).queue_free(), "CardFlat")
	holder[0] = p
	p.set_meta(&"tip_card", true)
	var c := screen.content()
	c.add_child(p)
	c.move_child(p, 0)
