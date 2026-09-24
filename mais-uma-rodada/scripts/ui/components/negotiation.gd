class_name Negotiation
extends RefCounted
## Fluxos de negociação em diálogo: compra (proposta → termos), jogador livre, renovação e venda.

var w: GameWorld
var p: Player
var mode: String # "buy" | "free" | "renew" | "sell"
var fee: int = 0
var agreed_fee: int = -1
var wage: int = 0
var years: int = 3
var message: String = ""
var message_color: Color = UIColors.MUTED
var counter_fee: int = -1
var counter_wage: int = -1
var box: VBoxContainer
var on_done: Callable


static func open(world: GameWorld, player: Player, kind: String, done: Callable) -> void:
	var n := Negotiation.new()
	n.w = world
	n.p = player
	n.mode = kind
	n.on_done = done
	n._init_values()
	n.box = UIKit.vbox(14)
	n.box.custom_minimum_size.x = 600
	n._render()
	UIManager.show_modal(n.box, true)


func _init_values() -> void:
	years = TransferManager.preferred_years(w, p)
	match mode:
		"buy":
			fee = p.value
		"sell":
			fee = Valuation.round_value(p.value * 1.1) if p.asking_price <= 0 else p.asking_price
		"renew":
			wage = Valuation.wage_demand(p, w.user_club(), w.year)
		_:
			wage = TransferManager.wage_ask(w, p, w.user_club())
	if mode == "free":
		wage = TransferManager.wage_ask(w, p, w.user_club())


func _step(v: int) -> int:
	if v >= 1_000_000:
		return 50_000
	if v >= 200_000:
		return 10_000
	if v >= 20_000:
		return 1_000
	return 500


func _wage_step(v: int) -> int:
	if v >= 50_000:
		return 2_500
	if v >= 10_000:
		return 500
	if v >= 2_000:
		return 100
	return 50


func _render() -> void:
	UIKit.clear(box)
	var head := UIKit.hbox(12)
	var club := w.club(p.club_id) if p.club_id >= 0 else null
	head.add_child(UIKit.portrait(p, club, w.year, 72))
	var t := UIKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var titles := {"buy": "Proposta por", "free": "Contratar", "renew": "Renovar com", "sell": "Colocar à venda"}
	t.add_child(UIKit.label(titles.get(mode, ""), "Caps"))
	t.add_child(UIKit.label(p.display_name(), "Title"))
	t.add_child(UIKit.label("%s · %d anos · valor %s" % [Pos.code(p.position), p.age(w.year), Fmt.money(p.value)], "Small"))
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	box.add_child(head)
	var user := w.user_club()
	match mode:
		"buy":
			if agreed_fee < 0:
				_render_fee("Sua proposta ao %s" % club.short_name, "Orçamento para contratações: %s" % Fmt.money(user.transfer_budget))
			else:
				_render_terms("Taxa acertada: %s. Agora, o contrato:" % Fmt.money(agreed_fee))
		"free":
			_render_terms("Jogador livre: sem taxa de transferência.")
		"renew":
			_render_terms("Contrato atual: %s até %d." % [Fmt.money_month(p.wage), p.contract_end])
		"sell":
			_render_fee("Preço pedido", "Clubes interessados farão propostas durante a janela.")
	if message != "":
		var m := UIKit.label(message, "H3", true)
		m.add_theme_color_override(&"font_color", message_color)
		box.add_child(m)


func _stepper(value_text: String, minus: Callable, plus: Callable) -> HBoxContainer:
	var row := UIKit.hbox(10)
	var mb := UIKit.icon_button("minus", minus)
	mb.theme_type_variation = "Button"
	mb.custom_minimum_size = Vector2(84, 76)
	row.add_child(mb)
	var l := UIKit.label(value_text, "Big")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var pb := UIKit.icon_button("plus", plus)
	pb.theme_type_variation = "Button"
	pb.custom_minimum_size = Vector2(84, 76)
	row.add_child(pb)
	return row


func _render_fee(caption: String, hint: String) -> void:
	box.add_child(UIKit.section(caption))
	box.add_child(_stepper(Fmt.money(fee), func():
		fee = maxi(0, fee - _step(fee))
		_render(), func():
		fee += _step(fee)
		_render()))
	var quick := UIKit.hbox(8)
	for q in [["Valor", 1.0], ["+10%", 1.1], ["+25%", 1.25], ["-10%", 0.9]]:
		var mult: float = q[1]
		var b := UIKit.button(q[0], "ChipButton", func():
			fee = Valuation.round_value(p.value * mult)
			_render())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		quick.add_child(b)
	box.add_child(quick)
	box.add_child(UIKit.label(hint, "Small", true))
	if counter_fee > 0 and mode == "buy":
		box.add_child(UIKit.button("Aceitar contraproposta de %s" % Fmt.money(counter_fee), "", func():
			fee = counter_fee
			_send_bid()))
	if mode == "buy":
		box.add_child(UIKit.button("ENVIAR PROPOSTA", "PrimaryButton", _send_bid, "swap"))
	else:
		box.add_child(UIKit.button("ANUNCIAR POR %s" % Fmt.money(fee), "PrimaryButton", func():
			p.transfer_listed = true
			p.asking_price = fee
			UIManager.close_modal()
			UIManager.toast("%s está à venda por %s." % [p.display_name(), Fmt.money(fee)])
			_done()))


func _send_bid() -> void:
	var r := TransferManager.user_bid(w, p, fee)
	message = r["msg"]
	match r["result"]:
		"accepted":
			agreed_fee = fee
			message_color = UIColors.GREEN
			wage = TransferManager.wage_ask(w, p, w.user_club())
			AudioManager.play("sign", -6.0)
		"counter":
			counter_fee = int(r["fee"])
			message_color = UIColors.ACCENT
		_:
			message_color = UIColors.RED
	_render()


func _render_terms(caption: String) -> void:
	box.add_child(UIKit.label(caption, "Muted", true))
	box.add_child(UIKit.section("Salário mensal"))
	box.add_child(_stepper(Fmt.money(wage), func():
		wage = maxi(300, wage - _wage_step(wage))
		_render(), func():
		wage += _wage_step(wage)
		_render()))
	box.add_child(UIKit.section("Duração"))
	var g := ButtonGroup.new()
	var yrow := UIKit.hbox(8)
	for y in range(1, 6):
		var yy := y
		var chip := UIKit.chip("%d ano%s" % [y, "" if y == 1 else "s"], y == years, g, func():
			years = yy)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		yrow.add_child(chip)
	box.add_child(yrow)
	var fin := FinanceManager.summary(w, w.user_club())
	var bill: int = fin["wage_bill"] - (p.wage if mode == "renew" else 0) + wage
	var fits: bool = bill <= int(fin["wage_budget"] * 1.02)
	var bl := UIKit.label("Folha após o acordo: %s / limite %s" % [Fmt.money_month(bill), Fmt.money(fin["wage_budget"])], "Small", true)
	bl.add_theme_color_override(&"font_color", UIColors.MUTED if fits else UIColors.RED)
	box.add_child(bl)
	if counter_wage > 0:
		box.add_child(UIKit.button("Aceitar pedido de %s" % Fmt.money_month(counter_wage), "", func():
			wage = counter_wage
			_send_terms()))
	box.add_child(UIKit.button("OFERECER CONTRATO", "PrimaryButton", _send_terms, "check"))


func _send_terms() -> void:
	var r: Dictionary
	match mode:
		"buy":
			r = TransferManager.user_sign(w, p, agreed_fee, wage, years)
		"free":
			r = TransferManager.user_sign_free(w, p, wage, years)
		"renew":
			var rr := TransferManager.renewal_terms(w, p, wage, years)
			if rr["result"] == "accepted":
				TransferManager.apply_renewal(w, p, wage, years)
				r = {"ok": true, "msg": "%s renovou até %d!" % [p.display_name(), p.contract_end]}
			else:
				r = {"ok": false, "msg": rr["msg"], "wage": rr.get("wage", 0), "result": rr["result"]}
	if r.get("ok", false):
		UIManager.close_modal()
		AudioManager.play("sign")
		AudioManager.vibrate(40)
		UIManager.toast(r["msg"], UIColors.GREEN)
		_done()
		return
	message = r["msg"]
	message_color = UIColors.RED
	if int(r.get("wage", 0)) > 0 and r.get("result", "") == "counter":
		counter_wage = int(r["wage"])
		message_color = UIColors.ACCENT
	_render()


func _done() -> void:
	if on_done.is_valid():
		on_done.call()
