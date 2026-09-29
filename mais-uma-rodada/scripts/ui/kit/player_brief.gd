class_name PlayerBrief
extends RefCounted
## Resumo de um jogador para o painel de detalhe (mestre/detalhe em tela larga: Elenco e
## Mercado). Cabeçalho com a identidade do clube, os números que decidem uma escalação ou uma
## contratação, e a ação que leva ao perfil completo. Mesmo vocabulário do perfil.


static func make(w: GameWorld, p: Player, exact: bool) -> Control:
	var club := w.club(p.club_id) if p.club_id >= 0 else null
	var hero := IdentityBand.wrap(club, 104.0, 150.0)
	var body: VBoxContainer = hero[1]
	var top := UIKit.hbox(UITokens.S3)
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
	var ovr := p.overall if exact else PlayerRowView.estimate(w, p, p.overall)
	var ob := UIKit.badge(ovr, 72, 56, 48)
	if not exact:
		ob.text_override = "~%d" % ovr
	ob.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(ob)
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
	body.add_child(UIKit.kv("Contrato até", str(p.contract_end) if p.club_id >= 0 else "Livre", UIColors.ORANGE if exact and p.contract_end <= w.year else UIColors.TEXT))
	body.add_child(UIKit.kv("Salário", Fmt.money_month(p.wage) if p.club_id >= 0 else "–"))
	body.add_child(UIKit.kv("Valor de mercado", Fmt.money(p.value)))
	var pid := p.id
	var open := UIKit.button("Abrir perfil", "PrimaryButton", func(): UIManager.push("player", {"id": pid}))
	body.add_child(UIKit.gap(6))
	body.add_child(open)
	return hero[0]
