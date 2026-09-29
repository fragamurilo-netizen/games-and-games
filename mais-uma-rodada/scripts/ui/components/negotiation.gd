class_name Negotiation
extends RefCounted
## Fluxos de negociação em diálogo: compra (proposta → termos), jogador livre, renovação, venda,
## pré-contrato e recompra. A compra tem três abas (valor, condições e troca) e os termos duas
## (salário e duração; bônus, promessa e empresário). As regras ficam em TransferManager e DealTerms.

var w: GameWorld
var p: Player
var mode: String # "buy" | "free" | "renew" | "sell" | "pre" (pré-contrato) | "buyback" (recompra)
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
## Condições: parcelas, % de revenda e bônus por metas (compra), luvas, multa rescisória, bônus
## por jogo/gol (níveis abl/gbl), promessa de papel e corte na comissão do empresário (contrato).
var deal: Dictionary = {"inst": 1, "sell_on": 0.0, "bonus": 0, "clause": 3, "swap": [], "addon": 0.0,
	"agent": 1.0, "abl": 0, "gbl": 0, "role": -1}
var loan_mode := false
## Empréstimo: {kind: ""|"opt"|"obl", ws: parte do salário paga pelo usuário}.
var loan_terms: Dictionary = {"kind": "", "ws": 1.0}
## Aba da proposta ("fee", "cond", "swap") e dos termos ("base", "extra").
var buy_tab := "fee"
var terms_tab := "base"
## Escolhendo jogadores do elenco para incluir na troca.
var picking_swap := false
## A multa rescisória foi paga (o vendedor não pode recusar).
var clause_paid := false
const MAX_SWAP := 2
## Última negociação aberta (capturas de tela).
static var last: Negotiation = null


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
	last = n
	UIManager.show_modal(n.box, true)


func _init_values() -> void:
	years = TransferManager.preferred_years(w, p)
	deal["mode"] = "buy" if mode == "buyback" else mode
	match mode:
		"buy":
			fee = p.value
		"sell":
			fee = Valuation.round_value(p.value * 1.1) if p.asking_price <= 0 else p.asking_price
		"renew":
			wage = Valuation.wage_demand(p, w.user_club(), w.year)
		"buyback":
			agreed_fee = int(DealTerms.buyback_of(w, p).get("price", p.value))
			wage = TransferManager.wage_ask(w, p, w.user_club())
		_:
			wage = TransferManager.wage_ask(w, p, w.user_club())
	if mode in ["buy", "buyback"]:
		deal["agent_pct"] = DealTerms.agent_pct(w, p)
	if mode == "free" or mode == "pre":
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
	var titles := {"buy": "Proposta por", "free": "Contratar", "renew": "Renovar com", "sell": "Colocar à venda", "pre": "Pré-contrato com", "buyback": "Recompra de"}
	t.add_child(UIKit.eyebrow(titles.get(mode, "")))
	t.add_child(UIKit.label(p.display_name().to_upper(), "Title"))
	t.add_child(UIKit.label("%s · %d anos · valor %s" % [Pos.code(p.position), p.age(w.year), Fmt.money(p.value)], "Small"))
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	box.add_child(head)
	var user := w.user_club()
	if picking_swap:
		_render_swap_picker()
		return
	match mode:
		"buy":
			if agreed_fee < 0:
				box.add_child(UIKit.segment([["buy", "Compra"], ["loan", "Empréstimo"]], "loan" if loan_mode else "buy", func(k: String):
					loan_mode = k == "loan"
					message = ""
					_render()))
				if loan_mode:
					_render_loan()
				else:
					_render_buy()
			else:
				var how := "Multa depositada: %s. Agora, o contrato:" if clause_paid else "Taxa acertada: %s. Agora, o contrato:"
				_render_terms(how % Fmt.money(agreed_fee))
		"buyback":
			_render_terms("Cláusula de recompra: %s, o %s não pode recusar. Agora, o contrato:" % [Fmt.money(agreed_fee), club.short_name if club != null else "clube"])
		"free":
			_render_terms("Jogador livre.")
		"pre":
			_render_terms("Chega de graça no fim da temporada.")
		"renew":
			_render_terms("Contrato atual: %s até %d." % [Fmt.money_month(p.wage), p.contract_end])
		"sell":
			_render_fee("Preço pedido", "")
			_render_sell_buttons()
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
	l.add_theme_color_override(&"font_color", UIColors.ACCENT)
	var inset := PanelContainer.new()
	inset.theme_type_variation = "CardInset"
	inset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inset.add_child(l)
	row.add_child(inset)
	var pb := UIKit.icon_button("plus", plus)
	pb.theme_type_variation = "Button"
	pb.custom_minimum_size = Vector2(84, 76)
	row.add_child(pb)
	return row


func _render_fee(caption: String, hint: String) -> void:
	box.add_child(UIKit.section_header(caption))
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
	if hint != "":
		box.add_child(UIKit.label(hint, "Small", true))


func _render_sell_buttons() -> void:
	box.add_child(UIKit.button("ANUNCIAR POR %s" % Fmt.money(fee), "PrimaryButton", func():
		p.transfer_listed = true
		p.asking_price = fee
		UIManager.close_modal()
		UIManager.toast("%s está à venda por %s." % [p.display_name(), Fmt.money(fee)])
		_done()))
	var shop := UIKit.button("OFERECER AOS CLUBES AGORA", "", func():
		var r := TransferManager.shop_player(w, p)
		if int(r["n"]) > 0:
			UIManager.close_modal()
			UIManager.toast(r["msg"], UIColors.GREEN)
			GameManager.save_now()
			UIManager.goto("market", {"tab": "offers"})
			return
		message = r["msg"]
		message_color = UIColors.RED if not r["ok"] else UIColors.MUTED
		_render(), "swap")
	shop.disabled = not w.transfer_window_open()
	box.add_child(shop)
	box.add_child(UIKit.label("Nas propostas que chegarem, dá para pedir % de revenda e cláusula de recompra (jogadores jovens)." , "Small", true))


## Proposta de compra: abas de valor, condições e troca, e o resumo sempre à vista.
func _render_buy() -> void:
	var seller := w.club(p.club_id)
	var user := w.user_club()
	var clause := MarketAI._clause_of(seller, p)
	if clause > 0:
		var cc := UIKit.card("CardFlat", 4)
		cc.add_child(UIKit.label("Multa rescisória: %s" % Fmt.money(clause), "H3"))
		cc.add_child(UIKit.label("Depositando a multa, o %s não pode recusar: você negocia só com o jogador." % seller.short_name, "Small", true))
		var pay := UIKit.button("PAGAR A MULTA", "", func():
			if TransferManager.upfront_cost(clause, deal) > user.transfer_budget:
				message = "A multa (mais a comissão) passa do orçamento de %s." % Fmt.money(user.transfer_budget)
				message_color = UIColors.RED
				_render()
				return
			if TransferManager.interest(w, p, user) < 0.18:
				message = "%s não quer jogar no %s: não adianta pagar a multa." % [p.display_name(), user.short_name]
				message_color = UIColors.RED
				_render()
				return
			clause_paid = true
			agreed_fee = clause
			deal["inst"] = 1
			wage = TransferManager.wage_ask(w, p, user)
			message = ""
			_render(), "money")
		pay.disabled = not w.transfer_window_open()
		cc.add_child(pay)
		box.add_child(UIKit.card_panel(cc))
	box.add_child(UIKit.segment([["fee", "Valor"], ["cond", "Condições"], ["swap", "Troca"]], buy_tab, func(k: String):
		buy_tab = k
		_render()))
	match buy_tab:
		"fee":
			_render_fee("Sua proposta ao %s" % seller.short_name, "Orçamento para contratações: %s" % Fmt.money(user.transfer_budget))
		"cond":
			box.add_child(_choice("Pagamento", [["À vista", 1], ["2 parcelas", 2], ["3 parcelas", 3]], int(deal["inst"]), func(v): deal["inst"] = int(v)))
			box.add_child(UIKit.label("Parcelar alivia o caixa agora, mas o vendedor desconta: vale menos para ele.", "Small", true))
			box.add_child(_choice("Revenda para o %s" % seller.short_name, [["0%", 0.0], ["10%", 0.1], ["20%", 0.2]], float(deal["sell_on"]), func(v): deal["sell_on"] = float(v)))
			box.add_child(_choice("Bônus por metas (após %d jogos)" % DealTerms.ADDON_APPS, [["Sem", 0.0], ["+10%", 0.1], ["+20%", 0.2], ["+30%", 0.3]], float(deal["addon"]), func(v): deal["addon"] = float(v)))
			if float(deal["addon"]) > 0.0:
				box.add_child(UIKit.label("Você paga mais %s só se ele completar %d jogos pelo clube em até %d anos. O vendedor conta isso como meio dinheiro." % [Fmt.money(DealTerms.addon_amount(fee, deal)), DealTerms.ADDON_APPS, DealTerms.ADDON_YEARS], "Small", true))
			box.add_child(_choice("Comissão do empresário (%d%%)" % int(round(float(deal["agent_pct"]) * 100.0)), _agent_opts(), float(deal["agent"]), func(v): deal["agent"] = float(v)))
		"swap":
			_render_swap_summary()
	var hint := DealTerms.deadline_hint(w, seller, p)
	if hint != "":
		box.add_child(UIKit.colored(hint, UIColors.ORANGE, "Small", true))
	var sum := UIKit.card("CardInset", 2)
	sum.add_child(UIKit.kv("Proposta", Fmt.money(fee) + ("" if int(deal["inst"]) == 1 else " em %d parcelas" % int(deal["inst"]))))
	sum.add_child(UIKit.kv("Comissão do empresário", Fmt.money(int(fee * float(deal["agent_pct"]) * float(deal["agent"])))))
	sum.add_child(UIKit.kv("Sai do caixa agora", Fmt.money(TransferManager.upfront_cost(fee, deal)), UIColors.ACCENT))
	box.add_child(UIKit.card_panel(sum))
	if counter_fee > 0:
		box.add_child(UIKit.button("Aceitar contraproposta de %s" % Fmt.money(counter_fee), "", func():
			fee = counter_fee
			_send_bid()))
	box.add_child(UIKit.button("ENVIAR PROPOSTA", "PrimaryButton", _send_bid, "swap"))


func _agent_opts() -> Array:
	var out: Array = []
	for a in DealTerms.AGENT_CUTS:
		out.append([String(a[1]), float(a[0])])
	return out


## Linha de opções mutuamente exclusivas.
func _choice(caption: String, opts: Array, current: Variant, cb: Callable) -> Control:
	var v := UIKit.vbox(4)
	if caption != "":
		v.add_child(UIKit.label(caption, "Small"))
	var items: Array = []
	var sel := ""
	for i in opts.size():
		items.append([str(i), String(opts[i][0])])
		if opts[i][1] == current:
			sel = str(i)
	v.add_child(UIKit.segment(items, sel, func(k: String):
		cb.call(opts[int(k)][1])
		counter_fee = -1
		_render()))
	return v


## Resumo da troca na proposta de compra: jogadores incluídos e quanto o vendedor vê neles.
func _render_swap_summary() -> void:
	var seller := w.club(p.club_id)
	var swaps := TransferManager.swap_players(w, deal)
	box.add_child(UIKit.label("Jogadores do seu elenco entram como parte do pagamento, pelo quanto o %s acha que eles valem." % seller.short_name, "Small", true))
	for sp: Player in swaps:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(sp.position))
		var nl := UIKit.label(sp.display_name(), "H3")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nl)
		row.add_child(UIKit.label("vale %s p/ eles" % Fmt.money(TransferManager.swap_worth(w, sp, seller)), "Small"))
		var sid := sp.id
		row.add_child(UIKit.icon_button("close", func():
			(deal["swap"] as Array).erase(sid)
			counter_fee = -1
			_render()))
		box.add_child(row)
	if swaps.size() < MAX_SWAP:
		box.add_child(UIKit.button("Incluir jogador na troca", "GhostButton", func():
			picking_swap = true
			_render(), "plus"))


func _render_swap_picker() -> void:
	var seller := w.club(p.club_id)
	box.add_child(UIKit.section("Quem vai para o %s?" % seller.short_name))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 560
	var list := UIKit.vbox(6)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var squad: Array = w.squad(w.user_club()).duplicate()
	squad.sort_custom(func(a, b): return a.value > b.value)
	var chosen: Array = deal["swap"]
	for sp: Player in squad:
		if not sp.loan.is_empty() or chosen.has(sp.id):
			continue
		var row := UIKit.hbox(10)
		row.add_child(UIKit.pos_badge(sp.position))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(sp.display_name(), "H3"))
		var willing := TransferManager.interest(w, sp, seller) >= 0.2
		col.add_child(UIKit.label("%d anos · ovr %d%s" % [sp.age(w.year), sp.overall, "" if willing else " · não quer ir"], "Small"))
		row.add_child(col)
		row.add_child(UIKit.colored(Fmt.money(TransferManager.swap_worth(w, sp, seller)), UIColors.ACCENT if willing else UIColors.MUTED, "H3"))
		var sid := sp.id
		list.add_child(UIKit.tap_row(row, func():
			chosen.append(sid)
			counter_fee = -1
			picking_swap = false
			_render()))
	box.add_child(scroll)
	box.add_child(UIKit.button("Voltar", "GhostButton", func():
		picking_swap = false
		_render(), "back"))


func _render_loan() -> void:
	box.add_child(UIKit.section("Empréstimo até o fim da temporada"))
	var price := DealTerms.loan_option_price(w, p)
	box.add_child(_loan_choice("Compra no fim", [["Sem compra", ""], ["Opção", "opt"], ["Obrigação", "obl"]], String(loan_terms["kind"]), "kind"))
	if String(loan_terms["kind"]) == "opt":
		box.add_child(UIKit.label("Você pode comprá-lo por %s até o fim do empréstimo (no perfil dele). O dono cobra menos pelo empréstimo." % Fmt.money(price), "Small", true))
	elif String(loan_terms["kind"]) == "obl":
		box.add_child(UIKit.label("A compra por %s vira obrigatória se ele fizer %d jogos. Com a venda garantida, o dono libera até titular e quase não cobra o empréstimo." % [Fmt.money(price), DealTerms.OBLIGATION_APPS], "Small", true))
	box.add_child(_loan_choice("Salário pago por você", [["100%", 1.0], ["75%", 0.75], ["50%", 0.5]], float(loan_terms["ws"]), "ws"))
	var r := TransferManager.loan_in_terms(w, p, loan_terms)
	var sum := UIKit.card("CardInset", 2)
	sum.add_child(UIKit.kv("Taxa de empréstimo", Fmt.money(DealTerms.loan_fee_with(w, p, loan_terms)), UIColors.ACCENT))
	sum.add_child(UIKit.kv("Salário (sua parte)", Fmt.money_month(int(p.wage * float(loan_terms["ws"])))))
	box.add_child(UIKit.card_panel(sum))
	box.add_child(UIKit.colored(String(r["msg"]), UIColors.MUTED if r["ok"] else UIColors.RED, "Small", true))
	var b := UIKit.button("PEDIR EMPRESTADO", "PrimaryButton", func():
		var res := TransferManager.loan_in(w, p, loan_terms)
		if res["ok"]:
			UIManager.close_modal()
			Sfx.play("sign")
			UIManager.toast(res["msg"], UIColors.GREEN)
			_done()
		else:
			message = res["msg"]
			message_color = UIColors.RED
			_render(), "swap")
	b.disabled = not r["ok"]
	box.add_child(b)


func _loan_choice(caption: String, opts: Array, current: Variant, key: String) -> Control:
	return _choice(caption, opts, current, func(v): loan_terms[key] = v)


func _send_bid() -> void:
	var r := TransferManager.user_bid(w, p, fee, deal)
	message = r["msg"]
	match r["result"]:
		"accepted":
			agreed_fee = fee
			message_color = UIColors.GREEN
			wage = TransferManager.wage_ask(w, p, w.user_club())
			Sfx.play("sign", -6.0)
		"counter":
			counter_fee = int(r["fee"])
			message_color = UIColors.ACCENT
		_:
			message_color = UIColors.RED
	_render()


## Valores de bônus pelo salário atual (os níveis ficam no acordo e acompanham o salário).
func _sync_bonus() -> void:
	deal["ab"] = int(DealTerms.bonus_options("ab", wage)[int(deal["abl"])])
	deal["gb"] = int(DealTerms.bonus_options("gb", wage)[int(deal["gbl"])])


func _render_terms(caption: String) -> void:
	_sync_bonus()
	box.add_child(UIKit.label(caption, "Muted", true))
	box.add_child(UIKit.segment([["base", "Salário e duração"], ["extra", "Bônus e promessas"]], terms_tab, func(k: String):
		terms_tab = k
		_render()))
	var club := w.user_club()
	if terms_tab == "base":
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
			UIKit.shrink_button(chip)
			yrow.add_child(chip)
		box.add_child(yrow)
		var monthly := maxi(wage, 1)
		box.add_child(_choice("Luvas (pagas na assinatura)", [["Nenhuma", 0], ["3 salários", monthly * 3], ["6 salários", monthly * 6], ["12 salários", monthly * 12]], int(deal["bonus"]), func(v): deal["bonus"] = int(v)))
		box.add_child(_choice("Multa rescisória", [["Sem multa", 0], ["2× valor", 2], ["3× valor", 3], ["5× valor", 5]], int(deal["clause"]), func(v): deal["clause"] = int(v)))
	else:
		var abo := DealTerms.bonus_options("ab", wage)
		var gbo := DealTerms.bonus_options("gb", wage)
		box.add_child(_choice("Bônus por jogo", [["Sem", 0], [Fmt.money(abo[1]), 1], [Fmt.money(abo[2]), 2]], int(deal["abl"]), func(v): deal["abl"] = int(v)))
		box.add_child(_choice("Bônus por gol", [["Sem", 0], [Fmt.money(gbo[1]), 1], [Fmt.money(gbo[2]), 2]], int(deal["gbl"]), func(v): deal["gbl"] = int(v)))
		box.add_child(UIKit.label("Bônus saem no fim da temporada, pelo que ele jogar e marcar. Em troca, ele aceita um fixo menor (vale uns %s/mês para ele)." % Fmt.money(int(DealTerms.bonus_monthly_value(p, deal))), "Small", true))
		var roles: Array = []
		for r in DealTerms.ROLE_OPTIONS:
			roles.append([String(r[1]), int(r[0])])
		box.add_child(_choice("Promessa de papel no elenco", roles, int(deal["role"]), func(v): deal["role"] = int(v)))
		var role := int(deal["role"])
		if role >= 0:
			if DealTerms.promise_credible(w, p, club, role):
				box.add_child(UIKit.label("Ele aceita ganhar menos pela promessa. Se não for %s de verdade (jogos como titular), vai cobrar no fim da temporada." % DealTerms.role_name(role).to_lower(), "Small", true))
			else:
				box.add_child(UIKit.colored("Ele não acredita: há gente melhor na posição. A promessa não muda o pedido.", UIColors.ORANGE, "Small", true))
		var lump := DealTerms.agent_cost(w, p, agreed_fee if agreed_fee > 0 else 0, String(deal.get("mode", mode)), wage, {"agent": 1.0, "agent_pct": deal.get("agent_pct", 0.05)})
		box.add_child(_choice("Comissão do empresário (cheia: %s)" % Fmt.money(lump), _agent_opts(), float(deal["agent"]), func(v): deal["agent"] = float(v)))
		if float(deal["agent"]) < 1.0:
			box.add_child(UIKit.label("Cortar a comissão faz o empresário pedir um salário maior; pela metade, ele pode travar o acordo.", "Small", true))
	var fin := FinanceManager.summary(w, club)
	var bill: int = fin["wage_bill"] - (p.wage if mode == "renew" else 0) + wage
	var fits: bool = bill <= int(fin["wage_budget"] * 1.02)
	var sum := UIKit.card("CardInset", 2)
	sum.add_child(UIKit.kv("Contrato", "%s/mês · %d ano%s" % [Fmt.money(wage), years, "" if years == 1 else "s"]))
	var extras: Array = []
	if int(deal["ab"]) > 0:
		extras.append("%s/jogo" % Fmt.money(int(deal["ab"])))
	if int(deal["gb"]) > 0:
		extras.append("%s/gol" % Fmt.money(int(deal["gb"])))
	if int(deal["role"]) >= 0:
		extras.append("promessa: " + DealTerms.role_name(int(deal["role"])).to_lower())
	if not extras.is_empty():
		sum.add_child(UIKit.kv("Extras", ", ".join(PackedStringArray(extras))))
	sum.add_child(UIKit.kv("Comissão do empresário", Fmt.money(DealTerms.agent_cost(w, p, agreed_fee if agreed_fee > 0 else 0, String(deal.get("mode", mode)), wage, deal))))
	var bl := UIKit.kv("Folha após o acordo", "%s / %s" % [Fmt.money_month(bill), Fmt.money(fin["wage_budget"])], UIColors.TEXT if fits else UIColors.RED)
	sum.add_child(bl)
	box.add_child(UIKit.card_panel(sum))
	if counter_wage > 0:
		box.add_child(UIKit.button("Aceitar pedido de %s" % Fmt.money_month(counter_wage), "", func():
			wage = counter_wage
			_send_terms()))
	box.add_child(UIKit.button("OFERECER CONTRATO", "PrimaryButton", _send_terms, "check"))


func _send_terms() -> void:
	_sync_bonus()
	var r: Dictionary
	match mode:
		"buy", "buyback":
			r = TransferManager.user_sign(w, p, agreed_fee, wage, years, deal)
		"free":
			r = TransferManager.user_sign_free(w, p, wage, years, deal)
		"pre":
			r = TransferManager.user_precontract(w, p, wage, years, deal)
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
		Sfx.play("sign")
		Sfx.vibrate(40)
		if not SigningCeremony.play_pending(w):
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
