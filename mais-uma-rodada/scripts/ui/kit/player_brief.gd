class_name PlayerBrief
extends RefCounted
## Resumo de um jogador para o painel de detalhe (mestre/detalhe em tela larga: Elenco e
## Mercado). Cabeçalho com a identidade do clube, os números que decidem uma escalação ou uma
## contratação, e a ação que leva ao perfil completo. Mesmo vocabulário do perfil.


## `on_change`: chamado depois de uma ação que muda o mundo (proposta, lista de observação).
static func make(w: GameWorld, p: Player, exact: bool, on_change: Callable = Callable()) -> Control:
	var club := w.club(p.club_id) if p.club_id >= 0 else null
	var hero := IdentityBand.wrap(club, 104.0, 150.0)
	var body: VBoxContainer = hero[1]
	var top := UIKit.hbox(UITokens.S6)
	var pv := UIKit.portrait(p, club, w.year, 118)
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(pv)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.gap(4))
	var nm := UIKit.label(p.display_name(), "Section")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UIKit.label("%s, %d anos" % [Pos.name_of(p.position), p.age(w.year)], "Small", true))
	if p.nationality != "":
		var nat := UIKit.hbox(8)
		nat.add_child(UIKit.flag(p.nationality, 26))
		nat.add_child(UIKit.label(NameGenerator.nationality_name(p.nationality), "Small"))
		col.add_child(nat)
	top.add_child(col)
	col.add_child(UIKit.player_stars(w,p,18))
	body.add_child(top)
	body.add_child(UIKit.gap(6))
	# Faixa de números: o que muda a escalação hoje.
	var strip := StatStrip.make([
		["Físico", "%d%%" % int(round(p.condition)) if p.injury_weeks == 0 else "Lesão", UIColors.TEXT if p.condition >= 85.0 and p.injury_weeks == 0 else UIColors.ORANGE],
		["Moral", UIColors.morale_label(p.morale), UIColors.morale_color(p.morale)],
		["Forma", Fmt.rating(p.form()) if not p.recent_ratings.is_empty() else "–", Fmt.match_rating_color(p.form()) if not p.recent_ratings.is_empty() else UIColors.DIM],
		["Jogos", str(int(p.season_totals()[0])), UIColors.TEXT],
	])
	body.add_child(strip)
	var st := PlayerTable.status(w, p, "squad" if exact else "market")
	body.add_child(UIKit.colored(String(st[0]), st[1], "Small", true))
	var pid := p.id
	if exact:
		body.add_child(UIKit.kv("Contrato até", str(p.contract_end), UIColors.ORANGE if p.contract_end <= w.year else UIColors.TEXT))
		body.add_child(UIKit.kv("Salário", Fmt.money_month(p.wage)))
		body.add_child(UIKit.kv("Valor de mercado", Fmt.money(p.value)))
		body.add_child(UIKit.gap(6))
		body.add_child(UIKit.button("Abrir perfil", "PrimaryButton", func(): UIManager.push("player", {"id": pid})))
		return hero[0]
	# Mercado: o que custa e o que ele pede, e a proposta a um toque.
	var club_now := w.club(p.club_id) if p.club_id >= 0 else null
	var free := p.club_id < 0 or not p.loan.is_empty()
	body.add_child(UIKit.kv("Clube", club_now.short_name if club_now != null else "Sem clube"))
	body.add_child(UIKit.kv("Contrato até", str(p.contract_end) if p.club_id >= 0 else "Livre"))
	body.add_child(UIKit.kv("Pedem" if not free else "Valor", Fmt.money(p.value if free else TransferManager.asking_price(w, p))))
	var user := w.user_club()
	var fin := FinanceManager.summary(w, user)
	var wage := TransferManager.wage_ask(w, p, user)
	var room := int(fin["wage_budget"]) - int(fin["wage_bill"])
	body.add_child(UIKit.kv("Salário que pede", Fmt.money_month(wage), UIColors.TEXT if wage <= room else UIColors.ORANGE))
	body.add_child(UIKit.gap(6))
	var row := UIKit.hbox(UITokens.S2)
	var mode := "free" if p.club_id < 0 else "buy"
	var can := p.club_id < 0 or w.transfer_window_open()
	var bid := UIKit.button(("Contratar" if p.club_id < 0 else "Fazer proposta") if can else "Janela fechada", "PrimaryButton", func(): Negotiation.open(w, p, mode, on_change))
	bid.disabled = not can
	bid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bid)
	var on := Shortlist.has(w, p)
	row.add_child(UIKit.button("Na lista" if on else "Acompanhar", "GhostButton", func():
		if not Shortlist.has(w, p) and Shortlist.is_full(w):
			UIManager.toast("Sua lista está cheia (%d)." % Shortlist.MAX_ENTRIES, UIColors.ORANGE)
			return
		Shortlist.toggle(w, p)
		GameManager.save_now()
		if on_change.is_valid():
			on_change.call()))
	body.add_child(row)
	body.add_child(UIKit.button("Abrir perfil", "TextButton", func(): UIManager.push("player", {"id": pid})))
	return hero[0]
