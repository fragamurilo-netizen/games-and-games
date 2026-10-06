class_name JobsScreen
extends BaseScreen
## Mercado de técnicos (JobMarket): propostas na mesa, vagas abertas para mandar currículo e
## fazer entrevista, cargos por um fio e, no fim, o pedido de demissão.


func _init() -> void:
	screen_title = "Vagas"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var out := JobMarket.unemployed(w)
	screen_subtitle = "Sem clube" if out else "Temporada %d" % w.year
	show_nav = not out
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	max_content_width = 1500.0
	c.add_child(_status(w, out))
	var start := c.get_child_count()
	var offers := _offers(w, out)
	if offers != null:
		c.add_child(offers)
	c.add_child(_vacancies(w))
	var hot := _hot_seats(w)
	if hot != null:
		c.add_child(hot)
	if not out:
		c.add_child(_my_job(w))
	columnize(c, start)


## Faixa de situação: reputação, cargo e candidaturas da temporada.
func _status(w: GameWorld, out: bool) -> Control:
	var v := UIKit.vbox(UITokens.S2)
	var rep := People.manager_rep(w)
	var apps: Dictionary = JobMarket.data(w)["apps"]
	var items: Array = [["Reputação", Reputation.label(rep), Reputation.color(rep)]]
	if out:
		items.append(["Situação", "Sem clube", UIColors.ORANGE])
	else:
		var conf := w.user_club().board_confidence
		items.append(["No cargo", BoardManager.label(conf), BoardManager.color(conf)])
	items.append(["Candidaturas", str(apps.size()), UIColors.TEXT])
	v.add_child(StatStrip.make(items))
	if out:
		var f: Dictionary = w.stats.get("fired", {})
		var old := w.club(int(f.get("from", -1)))
		var name := old.short_name if old != null else "clube"
		var t := "Você entregou o cargo no %s." % name if bool(f.get("res", false)) else "A diretoria do %s trocou o comando técnico." % name
		v.add_child(UIKit.label(t + " Escolha uma proposta ou mande currículo para um clube com vaga.", "Muted", true))
	return v


# ---------------------------------------------------------------------------
# Propostas
# ---------------------------------------------------------------------------

func _offers(w: GameWorld, out: bool) -> Control:
	var rows: Array = []
	var approach := People.job_offer(w)
	if not approach.is_empty():
		var oc := w.club(int(approach["c"]))
		rows.append(_offer_row(w, oc, "Ligou para você", func():
			UIManager.confirm("Deixar o %s?" % w.user_club().short_name, "Você assume o %s agora. A torcida atual não vai gostar." % oc.short_name, "Assumir", func():
				People.accept_offer(w)
				_signed(oc)), func():
			People.decline_offer(w)
			UIManager.toast("Você ficou. Presidente e torcida gostaram.", UIColors.GREEN)
			GameManager.save_now()
			refresh()))
	var apps: Dictionary = JobMarket.data(w)["apps"]
	for cid in apps:
		if not JobMarket.offer_open(w, int(cid)):
			continue
		var cl := w.club(int(cid))
		var ccid := int(cid)
		rows.append(_offer_row(w, cl, "Proposta depois da entrevista", func():
			var body := "Você assume o %s agora." % cl.short_name
			if not out:
				body += " A torcida do %s não vai gostar." % w.user_club().short_name
			UIManager.confirm("Assinar com o %s?" % cl.short_name, body, "Assinar", func():
				JobMarket.accept(w, ccid)
				_signed(cl)), func():
			JobMarket.decline(w, ccid)
			GameManager.save_now()
			refresh()))
	if out:
		for cid in BoardManager.pending_job_offers(w):
			var cl2 := w.club(int(cid))
			if cl2 == null:
				continue
			var ccid2 := int(cid)
			rows.append(_offer_row(w, cl2, "Quer conversar", func():
				UIManager.confirm("Assumir o %s?" % cl2.short_name, "Você será o novo treinador do clube a partir de agora.", "Assumir", func():
					JobMarket.accept(w, ccid2)
					_signed(cl2)), Callable()))
	if rows.is_empty():
		return null
	var card := UIKit.card("CardHighlight", 12)
	card.add_child(UIKit.section("Propostas"))
	for r in rows:
		card.add_child(r)
	return UIKit.card_panel(card)


func _offer_row(w: GameWorld, cl: Club, why: String, on_accept: Callable, on_decline: Callable) -> Control:
	var v := UIKit.vbox(UITokens.S2)
	var row := UIKit.hbox(12)
	row.add_child(UIKit.crest(cl, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(cl.name, "H3", true))
	col.add_child(UIKit.label("%s · %s" % [w.league_short(cl.league_id), why], "Small", true))
	col.add_child(UIKit.label("Meta: %s" % String(SeasonManager.goal_of(w, cl.id)[0]).to_lower(), "Muted", true))
	row.add_child(col)
	v.add_child(row)
	var b := UIKit.hbox(12)
	var acc := UIKit.button("Assumir", "PrimaryButton", on_accept)
	acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_child(acc)
	if on_decline.is_valid():
		var dec := UIKit.button("Recusar", "GhostButton", on_decline)
		dec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_child(dec)
	v.add_child(b)
	return v


func _signed(cl: Club) -> void:
	GameManager.save_now()
	Sfx.play("sign")
	UIManager.toast("Bem-vindo ao %s!" % cl.short_name, UIColors.GREEN)
	UIManager.goto("hub")


# ---------------------------------------------------------------------------
# Vagas abertas
# ---------------------------------------------------------------------------

func _vacancies(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("Vagas abertas"))
	var list := JobMarket.vacancies(w)
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum clube está sem técnico agora. Quando alguém cair, a vaga aparece aqui.", "Muted", true))
		return UIKit.card_panel(card)
	card.add_child(UIKit.label("Clubes com interino no comando. Mande o currículo e, se chamarem, encare a entrevista com o presidente.", "Muted", true))
	var shown := 0
	for cl: Club in list:
		if shown >= 30:
			break
		shown += 1
		card.add_child(_club_row(w, cl, "Interino no comando", func(): _vacancy_sheet(w, cl)))
	return UIKit.card_panel(card)


func _club_row(w: GameWorld, cl: Club, what: String, cb: Callable) -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.crest(cl, 56))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(cl.name, "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UIKit.label("%s · %s" % [w.league_short(cl.league_id), what], "Small", true))
	row.add_child(col)
	var app := JobMarket.app_of(w, cl.id)
	var tail: Label
	if not app.is_empty():
		var st := String(app.get("st", ""))
		tail = UIKit.colored(JobMarket.app_status_text(st), UIColors.GREEN if st in ["ent", "prop"] else UIColors.MUTED, "Small")
	else:
		var f := JobMarket.fit(w, cl)
		tail = UIKit.colored(JobMarket.fit_label(f), JobMarket.fit_color(f), "Small")
	tail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(tail)
	return UIKit.tap_row(row, cb)


## Ficha da vaga: o clube, o que a diretoria quer, sua cotação e a ação (candidatura/entrevista).
func _vacancy_sheet(w: GameWorld, cl: Club) -> void:
	var v := _sheet_head(w, cl)
	var app := JobMarket.app_of(w, cl.id)
	var st := String(app.get("st", ""))
	var why := JobMarket.can_apply(w, cl)
	if st == "ent":
		v.add_child(UIKit.label("O presidente marcou a entrevista. São quatro perguntas: projeto, estilo de jogo, o seu momento e um tema dele.", "Muted", true))
		v.add_child(UIKit.button("Fazer a entrevista", "PrimaryButton", func():
			UIManager.close_modal()
			TalkDialog.open("interview", cl.id, refresh)))
	elif st == "prop" and JobMarket.offer_open(w, cl.id):
		v.add_child(UIKit.label("A proposta está de pé. Assine na lista de propostas.", "Muted", true))
	elif why == "":
		if not JobMarket.unemployed(w):
			v.add_child(UIKit.label("Você ainda tem clube: a candidatura pode vazar para a imprensa, e a diretoria e a torcida do %s vão saber." % w.user_club().short_name, "Muted", true))
		v.add_child(UIKit.button("Enviar candidatura", "PrimaryButton", func():
			UIManager.close_modal()
			var res := JobMarket.apply(w, cl.id)
			GameManager.save_now()
			refresh()
			if bool(res["ok"]):
				UIManager.dialog("Entrevista marcada", String(res["text"]), [
					{"text": "Fazer agora", "style": "PrimaryButton", "cb": func(): TalkDialog.open("interview", cl.id, refresh)},
					{"text": "Depois", "style": "GhostButton"}])
			else:
				UIManager.toast(String(res["text"]), UIColors.ORANGE)))
	else:
		v.add_child(UIKit.colored(why, UIColors.MUTED, "", true))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _sheet_head(w: GameWorld, cl: Club) -> VBoxContainer:
	var v := UIKit.vbox(UITokens.S3)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.crest(cl, 88))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(cl.name, "Title", true))
	col.add_child(UIKit.label(w.league_name(cl.league_id), "Small", true))
	head.add_child(col)
	v.add_child(head)
	var league := w.league_of(cl.id)
	var pos := CompetitionManager.position_of(league, cl.id) if league != null else 0
	var pst := People.pres_style(w, cl.id)
	var f := JobMarket.fit(w, cl)
	v.add_child(UIKit.kv("Meta da diretoria", String(SeasonManager.goal_of(w, cl.id)[0])))
	if pos > 0:
		v.add_child(UIKit.kv("Na tabela", "%dº lugar" % pos))
	v.add_child(UIKit.kv("Presidente", String(pst.get("name", ""))))
	v.add_child(UIKit.kv("Jeito de jogar do clube", ClubDNA.name_of("tac", ClubDNA.tac(cl))))
	v.add_child(UIKit.kv("Sua cotação", JobMarket.fit_label(f), JobMarket.fit_color(f)))
	var ln := JobMarket.language_note(w, cl)
	if ln != "":
		v.add_child(UIKit.colored(ln, UIColors.ORANGE, "Small", true))
	return v


# ---------------------------------------------------------------------------
# Cargos por um fio
# ---------------------------------------------------------------------------

func _hot_seats(w: GameWorld) -> Control:
	var list := JobMarket.hot_seats(w)
	if list.is_empty():
		return null
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section_header("Cargos por um fio"))
	card.add_child(UIKit.label("O técnico ainda está lá, mas a pressão é grande. Deixe o seu nome à disposição: se ele cair, o clube liga primeiro para você.", "Muted", true))
	for cl: Club in list.slice(0, 12):
		var what := "%s pressionado" % People.coach_name(w, cl.id)
		if JobMarket.watching(w, cl.id):
			what = "seu nome está com o presidente"
		card.add_child(_club_row(w, cl, what, func(): _hot_sheet(w, cl)))
	return UIKit.card_panel(card)


func _hot_sheet(w: GameWorld, cl: Club) -> void:
	var v := _sheet_head(w, cl)
	v.add_child(UIKit.kv("Técnico", People.coach_name(w, cl.id)))
	if JobMarket.watching(w, cl.id):
		v.add_child(UIKit.label("O presidente já sabe do seu interesse.", "Muted", true))
	else:
		if not JobMarket.unemployed(w):
			v.add_child(UIKit.label("Pode vazar: a diretoria do %s não vai gostar." % w.user_club().short_name, "Muted", true))
		v.add_child(UIKit.button("Deixar o nome à disposição", "PrimaryButton", func():
			UIManager.close_modal()
			JobMarket.watch(w, cl.id)
			GameManager.save_now()
			UIManager.toast("O presidente do %s sabe que você tem interesse." % cl.short_name)
			refresh()))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


# ---------------------------------------------------------------------------
# Seu cargo
# ---------------------------------------------------------------------------

func _my_job(w: GameWorld) -> Control:
	var club := w.user_club()
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Seu cargo no %s" % club.short_name))
	card.add_child(UIKit.kv("Confiança da diretoria", BoardManager.label(club.board_confidence), BoardManager.color(club.board_confidence)))
	card.add_child(UIKit.kv("Relação com o presidente", People.rel_label(People.pres_rel(w)), UIColors.morale_color(People.pres_rel(w))))
	card.add_child(UIKit.kv("Torcida", People.support_label(People.fan_support(w)), UIColors.morale_color(People.fan_support(w))))
	card.add_child(UIKit.button("Pedir demissão", "GhostButton", func():
		var mid := w.season != null and not w.season.finished and w.current_turn() > 0
		var body := "Você deixa o %s agora e fica sem clube até aceitar uma proposta ou passar numa entrevista." % club.short_name
		if mid:
			body += " Sair no meio da temporada pesa um pouco na sua reputação."
		UIManager.confirm("Pedir demissão?", body, "Sair do %s" % club.short_name, func():
			JobMarket.resign(w)
			GameManager.save_now()
			UIManager.goto("hub"))))
	return UIKit.card_panel(card)
