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
## Condições: parcelas, % de revenda (compra), luvas e multa rescisória (contrato).
var deal: Dictionary = {"inst": 1, "sell_on": 0.0, "bonus": 0, "clause": 3}
var loan_mode := false


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
				var g := ButtonGroup.new()
				var mrow := UIKit.hbox(8)
				for m in [[false, "Compra"], [true, "Empréstimo"]]:
					var lm: bool = m[0]
					var chip := UIKit.chip(String(m[1]), lm == loan_mode, g, func():
						loan_mode = lm
						message = ""
						_render())
					chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					mrow.add_child(chip)
				box.add_child(mrow)
				if loan_mode:
					_render_loan()
				else:
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
	if mode == "buy":
		box.add_child(UIKit.section("Condições"))
		box.add_child(_choice("Pagamento", [["À vista", 1], ["2 parcelas", 2], ["3 parcelas", 3]], int(deal["inst"]), func(v): deal["inst"] = int(v)))
		box.add_child(_choice("Revenda para o %s" % w.club(p.club_id).short_name, [["0%", 0.0], ["10%", 0.1], ["20%", 0.2]], float(deal["sell_on"]), func(v): deal["sell_on"] = float(v)))
		box.add_child(UIKit.label("Sai do caixa agora: %s (1ª parcela + 5%% do empresário). Parcelar deixa a oferta menos atraente; dar %% de revenda deixa mais." % Fmt.money(TransferManager.upfront_cost(fee, deal)), "Small", true))
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


## Linha de opções mutuamente exclusivas.
func _choice(caption: String, opts: Array, current: Variant, cb: Callable) -> Control:
	var v := UIKit.vbox(4)
	if caption != "":
		v.add_child(UIKit.label(caption, "Small"))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(8)
	for o in opts:
		var val: Variant = o[1]
		var chip := UIKit.chip(String(o[0]), val == current, g, func():
			cb.call(val)
			_render())
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(chip)
	v.add_child(row)
	return v


func _render_loan() -> void:
	var r := TransferManager.loan_in_terms(w, p)
	box.add_child(UIKit.section("Empréstimo até o fim da temporada"))
	box.add_child(UIKit.kv("Taxa de empréstimo", Fmt.money(TransferManager.loan_fee(p))))
	box.add_child(UIKit.kv("Salário (pago por você)", Fmt.money_month(p.wage)))
	box.add_child(UIKit.label(String(r["msg"]), "Small", true))
	var b := UIKit.button("PEDIR EMPRESTADO", "PrimaryButton", func():
		var res := TransferManager.loan_in(w, p)
		if res["ok"]:
			UIManager.close_modal()
			AudioManager.play("sign")
			UIManager.toast(res["msg"], UIColors.GREEN)
			_done()
		else:
			message = res["msg"]
			message_color = UIColors.RED
			_render(), "swap")
	b.disabled = not r["ok"]
	box.add_child(b)


func _send_bid() -> void:
	var r := TransferManager.user_bid(w, p, fee, deal)
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
	box.add_child(UIKit.section("Luvas (pagas na assinatura)"))
	var monthly := maxi(wage, 1)
	box.add_child(_choice("", [["Nenhuma", 0], ["3 salários", monthly * 3], ["6 salários", monthly * 6], ["12 salários", monthly * 12]], int(deal["bonus"]), func(v): deal["bonus"] = int(v)))
	box.add_child(UIKit.label("Luvas reduzem o salário pedido: dinheiro agora em troca de uma folha mais leve.", "Small", true))
	box.add_child(_choice("Multa rescisória", [["Sem multa", 0], ["2× valor", 2], ["3× valor", 3], ["5× valor", 5]], int(deal["clause"]), func(v): deal["clause"] = int(v)))
	box.add_child(UIKit.label("Multa baixa agrada o jogador, mas um clube rico pode pagá-la e levá-lo.", "Small", true))
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
			r = TransferManager.user_sign(w, p, agreed_fee, wage, years, deal)
		"free":
			r = TransferManager.user_sign_free(w, p, wage, years, deal)
		"renew":
			var rr := TransferManager.renewal_terms(w, p, wage, years, deal)
			if rr["result"] == "accepted":
				TransferManager.apply_renewal(w, p, wage, years)
				TransferManager.apply_deal(w, p, w.user_club(), -1, 0, deal)
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
