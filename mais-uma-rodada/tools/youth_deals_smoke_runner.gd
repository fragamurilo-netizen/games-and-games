extends Node
## Lógica de youth_deals_smoke.gd (carregada depois dos autoloads).


func _ready() -> void:
	if "--career" in OS.get_cmdline_user_args():
		_career()
		return
	if "--deals" in OS.get_cmdline_user_args():
		_deals()
		return
	var t0 := Time.get_ticks_msec()
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club: Club = w.clubs_in_league("BRA1")[0]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--club="):
			for c: Club in w.clubs:
				if c.name.to_lower().contains(a.substr(7).to_lower()):
					club = c
					break
	w.user_club_id = club.id
	YouthManager.ensure_academy(w)
	YouthManager.build_league(w)
	print("clube: %s (%s) · base %d · calendário %d datas" % [club.name, club.league_id, club.youth_level, w.season.calendar.size()])
	for k in YouthCups.keys(w):
		var d := YouthCups.comp(w, k)
		var slots: Array = []
		for r in d["rounds"]:
			slots.append(int(r["slot"]))
		print("  %s: %s · %d times · usuário: %s · datas %s" % [k, d["name"], d["teams"].size(), str(d["user_in"]), str(slots)])
	var kid: Player = YouthManager.academy(w)[0]
	YouthAcademy.set_plan(w, kid, "finalizacao", 2)
	for slot in w.season.calendar.size():
		if not w.season.is_weekend(slot):
			continue
		w.season.day = slot
		YouthManager.weekly(w)
		YouthManager.play_slot(w, slot)
	var fin := YouthManager.finish_league(w)
	for e in fin.get("cups", []):
		var ch: Variant = e["champion"]
		var cname := DatabaseManager.nation_name(String(ch)) if ch is String else w.club(int(ch)).short_name
		print("  fim %s: campeão %s · usuário: %s" % [e["name"], cname, e.get("user", "-")])
		var d := YouthCups.comp(w, String(e["key"]))
		for s in YouthCups.top_scorers(d, 3):
			print("      artilharia: %s %d" % [s["n"], int(s["g"])])
	var intl := YouthCups.comp(w, "intl")
	if not intl.is_empty():
		print("  convocados do usuário no %s: %s" % [intl["name"], str(YouthCups.user_called(w, intl))])
	print("  por competição (%s): %s" % [kid.display_name(), str(YouthAcademy.season_by_comp(w, kid.id))])
	w.year += 1
	var turn := YouthManager.season_turnover(w)
	print("  virada: %d novos, %d saíram, custo técnicos %s" % [turn["new"].size(), turn["left"].size(), Fmt.money(int(turn["staff_cost"]))])
	print("  histórico %s: %s" % [kid.display_name(), str(YouthAcademy.history(w, kid.id))])
	YouthManager.build_league(w)
	print("  nova temporada: %s" % str(YouthCups.keys(w)))
	print("honrarias: %s" % str(w.youth.get("hon", [])))
	print("ok em %d ms" % (Time.get_ticks_msec() - t0))
	get_tree().quit()


## Carreira de verdade (GameManager): algumas rodadas e o estado das copas de base.
func _career() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var club: Club = w.clubs_in_league("BRA1")[3]
	AppSettings.tutorial_done = true
	GameManager.start_career(w, club.id, "Teste", GameWorld.DIFF_NORMAL, 5)
	print("dia %d · comps %s" % [w.season.day, str(YouthCups.keys(w))])
	var full := "--full" in OS.get_cmdline_user_args()
	var t0 := Time.get_ticks_msec()
	var i := 0
	while not GameManager.season_over() and (full or i < 12):
		GameManager.play_instant()
		GameManager.advance_to_end()
		var d := YouthCups.comp(w, "cup20")
		if i % 10 == 0:
			print("rodada %d · dia %d · copinha: %s · próxima %d" % [i, w.season.day, YouthCups.result_text(w, d), YouthCups.next_slot(w, d)])
		i += 1
	if full:
		print("temporada jogada em %d s" % ((Time.get_ticks_msec() - t0) / 1000))
		var sm := GameManager.end_season()
		print("fim: base %s" % str(sm.get("youth_league", {}).get("cups", [])))
		print("novas copas: %s · ano %d" % [str(YouthCups.keys(w)), w.year])
		# Salva e carrega (formato do save com os campos novos)
		GameManager.save_blocking()
		print("save ok; carregando...")
		print("carregou: %s" % str(GameManager.load_career(GameManager.slot)))
		print("comps após carregar: %s" % str(YouthCups.keys(GameManager.world)))
	get_tree().quit()


## Negociações: paciência do vendedor, bônus/promessa/empresário, empréstimo com obrigação,
## venda estruturada (parcelas, revenda, recompra, bônus por metas) e o fim de temporada.
func _deals() -> void:
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	var user: Club = w.clubs_in_league("BRA1")[2]
	w.user_club_id = user.id
	user.transfer_budget = 80_000_000
	user.wage_budget = FinanceManager.wage_bill(w, user) * 3
	print("janela aberta: %s · dia %d" % [str(w.transfer_window_open()), w.season.day])
	# Alvo: titular de outro clube brasileiro, sem bloqueio de venda
	var target: Player = null
	for c: Club in w.clubs_in_league("BRA1"):
		if c.id == user.id or user.is_rival(c.id):
			continue
		for q: Player in w.squad(c):
			if q.squad_status == Player.STATUS_ROTATION and q.loan.is_empty() and TransferManager.sale_block(w, c, user, q) == "":
				target = q
				break
		if target != null:
			break
	var ask := TransferManager.asking_price(w, target)
	print("alvo %s (%s) valor %s pedido %s" % [target.display_name(), w.club(target.club_id).short_name, Fmt.money(target.value), Fmt.money(ask)])
	for i in 3:
		var r := TransferManager.user_bid(w, target, int(ask * 0.4), {})
		print("  lance baixo %d: %s · %s" % [i, r["result"], r["msg"]])
	var ok := TransferManager.user_bid(w, target, ask * 2, {})
	print("  lance alto (conversa encerrada?): %s" % ok["result"])
	w.stats.erase("neg")
	var c1 := TransferManager.user_bid(w, target, int(ask * 0.85), {"inst": 3})
	print("  parcelado 85%%: %s · %s" % [c1["result"], c1["msg"]])
	var c2 := TransferManager.user_bid(w, target, int(ask * 0.9), {"addon": 0.3})
	print("  90%% + 30%% bônus: %s · %s" % [c2["result"], c2["msg"]])
	# Termos: pedido com e sem bônus/promessa/corte de comissão
	var base_d := {"clause": 3}
	var r0 := TransferManager.user_terms(w, target, 1, 3, base_d)
	var d1 := {"clause": 3, "ab": DealTerms.bonus_options("ab", int(r0["wage"]))[2], "gb": DealTerms.bonus_options("gb", int(r0["wage"]))[2], "role": Player.STATUS_STARTER}
	var r1 := TransferManager.user_terms(w, target, 1, 3, d1)
	var r2 := TransferManager.user_terms(w, target, 1, 3, {"clause": 3, "agent": 0.75})
	var r3 := TransferManager.user_terms(w, target, 1, 3, {"clause": 3, "agent": 0.5})
	print("  pedido base %s · com bônus+promessa %s (acredita: %s) · comissão -25%% %s · -50%%: %s" % [Fmt.money(int(r0["wage"])), Fmt.money(int(r1["wage"])), str(DealTerms.promise_credible(w, target, user, Player.STATUS_STARTER)), Fmt.money(int(r2["wage"])), r3["msg"]])
	var deal := {"clause": 3, "agent_pct": DealTerms.agent_pct(w, target), "agent": 1.0, "addon": 0.2, "mode": "buy", "role": Player.STATUS_STARTER,
		"ab": int(d1["ab"]), "gb": int(d1["gb"])}
	var bal0 := user.balance
	var sg := TransferManager.user_sign(w, target, ask, int(r1["wage"]) + 1000, 3, deal)
	print("  assinatura: %s · caixa %s · cláusulas %s · add-ons %s" % [sg["msg"], Fmt.money(user.balance - bal0), str(target.clauses), str(DealTerms.user_addons(w))])
	# Empréstimo com obrigação
	var loanee: Player = null
	for c: Club in w.clubs_in_league("BRA1"):
		if c.id == user.id or user.is_rival(c.id) or c.is_rival(user.id):
			continue
		for q: Player in w.squad(c):
			if q.squad_status == Player.STATUS_STARTER and q.age(w.year) > 21 and q.loan.is_empty():
				loanee = q
				break
		if loanee != null:
			break
	print("  empréstimo simples de titular: %s" % TransferManager.loan_in_terms(w, loanee, {})["msg"])
	var li := TransferManager.loan_in(w, loanee, {"kind": "obl", "ws": 1.0})
	print("  com obrigação: %s · loan %s" % [li["msg"], str(loanee.loan)])
	loanee.stats[Player.S_APPS] = 14
	# Promessa descumprida: titular prometido com 0 jogos
	# Venda estruturada de um garoto do usuário
	var mine: Player = null
	for q: Player in w.squad(user):
		if q.age(w.year) <= 23 and q.loan.is_empty() and q.id != target.id:
			mine = q
			break
	var buyer := MarketAI.find_buyer_for(w, mine)
	if buyer == null:
		buyer = w.clubs_in_league("ENG1")[0]
	var o := TransferOffer.new()
	o.id = 9999
	o.player_id = mine.id
	o.buyer_id = buyer.id
	o.seller_id = user.id
	o.fee = Valuation.round_value(mine.value)
	o.max_fee = int(o.fee * 1.2)
	o.inst = 3
	o.addon = Valuation.round_value(mine.value * 0.1)
	o.created_day = w.current_turn()
	o.expires_day = w.current_turn() + 2
	w.offers.append(o)
	print("  pedido revenda: %s" % TransferManager.respond_offer(w, o, "so"))
	print("  pedido recompra: %s" % TransferManager.respond_offer(w, o, "bb"))
	var sb0 := user.balance
	print("  venda: %s · caixa agora %s · a receber %s · cláusulas %s" % [TransferManager.respond_offer(w, o, "accept"), Fmt.money(user.balance - sb0), Fmt.money(DealTerms.pending_receivables(w)), str(mine.clauses)])
	print("  recompra disponível: %s" % str(DealTerms.buyback_of(w, mine)))
	# Fim de temporada
	var lg := w.league_of(user.id)
	for r in lg.rounds:
		for f in r:
			f.played = true
	target.stats[Player.S_APPS] = 30
	target.stats[Player.S_GOALS] = 6
	var sb1 := user.balance
	var back := TransferManager.return_loans(w)
	print("  fim de temporada: caixa %s · %s agora no %s · moral %s %.0f" % [Fmt.money(user.balance - sb1), loanee.display_name(), w.club(loanee.club_id).short_name, target.display_name(), target.morale])
	w.year += 1
	TransferManager.pay_installments(w)
	print("  virada: a receber %s" % Fmt.money(DealTerms.pending_receivables(w)))
	for n in w.news.slice(maxi(0, w.news.size() - 6)):
		print("  notícia: %s" % n.title)
	get_tree().quit()
