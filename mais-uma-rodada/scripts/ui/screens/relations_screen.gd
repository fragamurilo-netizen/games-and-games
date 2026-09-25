class_name RelationsScreen
extends BaseScreen
## Relações: vestiário (confiança e laços), comissão técnica, presidente, torcida, imprensa
## e os técnicos da liga. Tudo aqui abre conversas (TalkDialog).

const TABS := [["squad", "Vestiário"], ["staff", "Comissão"], ["board", "Diretoria"], ["fans", "Torcida"], ["press", "Imprensa"], ["coaches", "Técnicos"]]

var _tab := "squad"


func _init() -> void:
	show_nav = false
	screen_title = "Relações"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "squad"))


func refresh() -> void:
	var w := world()
	if w == null or not w.has_user():
		return
	People.ensure(w)
	var club := w.user_club()
	screen_subtitle = "%s · %s" % [w.manager_name, club.short_name]
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var pend := pending_card(w, func(): refresh(), false)
	if pend != null:
		c.add_child(pend)
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for t in TABS:
		var key: String = t[0]
		row.add_child(UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh()))
	c.add_child(row)
	var cb := func(): refresh()
	match _tab:
		"squad":
			_squad(w, c, cb)
		"staff":
			_staff(w, c, cb)
		"board":
			_board(w, c, cb)
		"fans":
			_fans(w, c, cb)
		"press":
			_press(w, c, cb)
		"coaches":
			_coaches(w, c, cb)


static func _trust_color(t: float) -> Color:
	return UIColors.morale_color(t)


static func _bond_color(b: Dictionary) -> Color:
	match String(b["k"]):
		People.BOND_RIVAL:
			return UIColors.RED
		People.BOND_MENTOR:
			return UIColors.BLUE
	return UIColors.GREEN


# ---------------------------------------------------------------------------
# Pendências (também usado no hub)
# ---------------------------------------------------------------------------

## Pedidos de conversa, convocação do presidente, coletiva e propostas. `always` mostra o card
## mesmo sem pendências (atalho para a tela).
static func pending_card(w: GameWorld, on_done: Callable, always: bool) -> Control:
	var reqs := People.requests(w)
	var offer := People.job_offer(w)
	if reqs.is_empty() and offer.is_empty() and not always:
		return null
	var card := UIKit.card("CardHighlight" if not reqs.is_empty() or not offer.is_empty() else "Card", 8)
	card.add_child(UIKit.section("Bastidores"))
	if not offer.is_empty():
		var oc := w.club(int(offer["c"]))
		var row := UIKit.hbox(12)
		row.add_child(UIKit.crest(oc, 44))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("O %s quer você como técnico" % oc.short_name, "H3", true))
		col.add_child(UIKit.label("%s · meta: %s" % [w.league_short(oc.league_id), String(SeasonManager.goal_of(w, oc.id)[0]).to_lower()], "Small", true))
		row.add_child(col)
		card.add_child(row)
		var brow := UIKit.hbox(10)
		var acc := UIKit.button("Aceitar", "PrimaryButton", func():
			UIManager.confirm("Deixar o %s?" % w.user_club().short_name, "Você assume o %s agora. A torcida atual não vai gostar." % oc.short_name, "Assumir", func():
				People.accept_offer(w)
				GameManager.save_now()
				UIManager.goto("hub")))
		acc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(acc)
		var dec := UIKit.button("Recusar e ficar", "GhostButton", func():
			People.decline_offer(w)
			UIManager.toast("Você ficou. Presidente e torcida gostaram.", UIColors.GREEN)
			GameManager.save_now()
			if on_done.is_valid():
				on_done.call())
		dec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(dec)
		card.add_child(brow)
	for q in reqs:
		var row := UIKit.hbox(12)
		var text := ""
		var icon := "info"
		var kind := String(q["k"])
		var target := int(q.get("t", -1))
		match kind:
			"player":
				var p := w.player(target)
				if p == null:
					continue
				text = "%s pediu para conversar" % p.display_name()
				icon = "shirt"
			"board":
				text = "O presidente chamou você para uma reunião"
				icon = "shield"
			"press":
				text = "Imprensa na zona mista: fale sobre o jogo" if q.get("post", false) else "Coletiva de imprensa antes do próximo jogo"
				icon = "news"
		row.add_child(UIKit.icon_rect(icon, 30, UIColors.ACCENT))
		var l := UIKit.label(text, "", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("›", "H2"))
		card.add_child(UIKit.tap_row(row, func(): TalkDialog.open(kind, target, on_done), "Card"))
	if always:
		var b := UIKit.button("Vestiário, diretoria, torcida e imprensa", "GhostButton", func(): UIManager.push("relations"), "heart")
		card.add_child(b)
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Vestiário
# ---------------------------------------------------------------------------

func _squad(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	var club := w.user_club()
	var squad := w.squad(club)
	var sum := 0.0
	var low := 0
	var high := 0
	for p: Player in squad:
		var t := People.trust_of(w, p)
		sum += t
		if t < 35.0:
			low += 1
		elif t >= 65.0:
			high += 1
	var avg := sum / maxf(1.0, squad.size())
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Clima do vestiário"))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(People.trust_label(avg), "confiança média", _trust_color(avg)))
	row.add_child(UIKit.stat(str(high), "fecham com você", UIColors.GREEN))
	row.add_child(UIKit.stat(str(low), "insatisfeitos", UIColors.RED if low > 0 else UIColors.TEXT))
	card.add_child(row)
	var cap := w.player(int(People.data(w).get("captain", -1)))
	if cap != null and cap.club_id == club.id:
		card.add_child(UIKit.kv("Capitão", cap.display_name(), UIColors.ACCENT))
	c.add_child(UIKit.card_panel(card))
	var bonds: Array = People.data(w)["bonds"]
	if not bonds.is_empty():
		var bc := UIKit.card("Card", 6)
		bc.add_child(UIKit.section("Laços no elenco"))
		var sorted := bonds.duplicate()
		sorted.sort_custom(func(a, b): return absf(float(a["v"])) > absf(float(b["v"])))
		for b: Dictionary in sorted.slice(0, 10):
			var pa := w.player(int(b["a"]))
			var pb := w.player(int(b["b"]))
			if pa == null or pb == null:
				continue
			var r := UIKit.hbox(10)
			r.add_child(UIKit.pill(People.bond_text(b).to_upper(), _bond_color(b), 15))
			var l := UIKit.label("%s e %s" % [pa.display_name(), pb.display_name()] if String(b["k"]) != People.BOND_MENTOR else "%s orienta %s" % [pa.display_name(), pb.display_name()], "", true)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_child(l)
			bc.add_child(r)
		c.add_child(UIKit.card_panel(bc))
	var lc := UIKit.card("Card", 6)
	lc.add_child(UIKit.section("Conversar com um jogador"))
	squad.sort_custom(func(a, b): return People.trust_of(w, a) < People.trust_of(w, b))
	for p: Player in squad:
		lc.add_child(_player_row(w, p, cb))
	c.add_child(UIKit.card_panel(lc))


static func _player_row(w: GameWorld, p: Player, cb: Callable) -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 56))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := People.trust_of(w, p)
	var top := UIKit.hbox(8)
	var n := UIKit.label(p.display_name(), "H3")
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	top.add_child(UIKit.colored(People.trust_label(t), _trust_color(t), "Small"))
	col.add_child(top)
	col.add_child(UIKit.bar(t, 100.0, _trust_color(t), 8))
	var tags: Array = []
	for b: Dictionary in People.bonds_of(w, p.id):
		var o := w.player(People.bond_other(b, p.id))
		if o != null:
			tags.append("%s: %s" % [People.bond_text(b), o.display_name()])
	col.add_child(UIKit.label("%s · %s%s" % [Pos.code(p.position), Player.STATUS_NAMES[p.squad_status], (" · " + ", ".join(tags)) if not tags.is_empty() else ""], "Small", true))
	row.add_child(col)
	var pid := p.id
	return UIKit.tap_row(row, func(): TalkDialog.open("player", pid, cb))


## Card de relações no perfil de um jogador do usuário.
static func player_card(w: GameWorld, p: Player, cb: Callable) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Relação com o treinador"))
	var t := People.trust_of(w, p)
	var r := UIKit.hbox(10)
	r.add_child(UIKit.label("Confiança em você", "Muted"))
	r.add_child(UIKit.spacer())
	r.add_child(UIKit.colored(People.trust_label(t), _trust_color(t), "H3"))
	card.add_child(r)
	card.add_child(UIKit.bar(t, 100.0, _trust_color(t), 10))
	var bonds := People.bonds_of(w, p.id)
	if not bonds.is_empty():
		var fl := UIKit.flow(8)
		for b: Dictionary in bonds:
			var o := w.player(People.bond_other(b, p.id))
			if o != null:
				fl.add_child(UIKit.pill("%s · %s" % [People.bond_text(b), o.display_name()], _bond_color(b), 15))
		card.add_child(fl)
	var pid := p.id
	card.add_child(UIKit.button("Conversar com %s" % p.display_name(), "GhostButton", func(): TalkDialog.open("player", pid, cb), "heart"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Comissão técnica
# ---------------------------------------------------------------------------

func _staff(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	var head := UIKit.card("Card", 8)
	head.add_child(UIKit.section("Comissão técnica"))
	head.add_child(UIKit.kv("Folha da comissão (mês)", "%s / %s" % [Fmt.money(People.staff_wage_bill(w)), Fmt.money(People.staff_budget(w))]))
	c.add_child(UIKit.card_panel(head))
	var st := People.staff(w)
	for i in People.STAFF_ORDER.size():
		var role: String = People.STAFF_ORDER[i]
		var s: Dictionary = st.get(role, {})
		var info: Dictionary = People.STAFF_ROLES[role]
		var card := UIKit.card("Card", 8)
		var row := UIKit.hbox(12)
		row.add_child(UIKit.icon_rect(String(info["icon"]), 36, UIColors.ACCENT))
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(info["name"]).to_upper(), "Caps"))
		col.add_child(UIKit.label(String(s.get("n", "Vago")), "H3", true))
		if not s.is_empty():
			col.add_child(UIKit.label("%d anos · %s/mês · sintonia %s" % [w.year - int(s["by"]), Fmt.money(int(s["w"])), People.rel_label(float(s.get("rel", 50.0))).to_lower()], "Small", true))
		row.add_child(col)
		var stars := StarsView.new()
		stars.star_size = 20.0
		stars.stars = clampf(float(s.get("sk", 0.0)) / 20.0, 0.5, 5.0)
		row.add_child(stars)
		card.add_child(row)
		card.add_child(UIKit.label(String(info["desc"]), "Small", true))
		var brow := UIKit.hbox(10)
		var idx := i
		var talk := UIKit.button("Pedir relatório", "GhostButton", func(): TalkDialog.open("staff", idx, cb), "list")
		talk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(talk)
		var swap := UIKit.button("Trocar", "GhostButton", func(): _candidates(w, role, cb), "swap")
		swap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		brow.add_child(swap)
		card.add_child(brow)
		c.add_child(UIKit.card_panel(card))


static func _candidates(w: GameWorld, role: String, cb: Callable) -> void:
	var v := UIKit.vbox(12)
	v.custom_minimum_size.x = 600
	v.add_child(UIKit.label("Candidatos: %s" % String(People.STAFF_ROLES[role]["name"]).to_lower(), "Title", true))
	var sev := People.staff_severance(w, role)
	if sev > 0:
		v.add_child(UIKit.label("Rescisão do atual: %s (três salários)." % Fmt.money(sev), "Small", true))
	for cand: Dictionary in People.candidates(w, role):
		var row := UIKit.hbox(12)
		var col := UIKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(cand["n"]), "H3", true))
		col.add_child(UIKit.label("%d anos · %s/mês" % [w.year - int(cand["by"]), Fmt.money(int(cand["w"]))], "Small"))
		row.add_child(col)
		var stars := StarsView.new()
		stars.star_size = 20.0
		stars.stars = clampf(float(cand["sk"]) / 20.0, 0.5, 5.0)
		row.add_child(stars)
		var cid := int(cand["id"])
		v.add_child(UIKit.tap_row(row, func():
			var err := People.hire_staff(w, role, cid)
			UIManager.close_modal()
			if err != "":
				UIManager.toast(err, UIColors.RED)
			else:
				UIManager.toast("Contratado!", UIColors.GREEN)
				GameManager.save_now()
			if cb.is_valid():
				cb.call(), "Card"))
	v.add_child(UIKit.button("Manter como está", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


# ---------------------------------------------------------------------------
# Diretoria
# ---------------------------------------------------------------------------

func _board(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	var club := w.user_club()
	var pr := People.president(w, club.id)
	var st := People.pres_style(w, club.id)
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Presidente"))
	card.add_child(UIKit.label(String(pr["n"]), "Title", true))
	card.add_child(UIKit.label("%d anos · no cargo desde %d · mandato até %d" % [w.year - int(pr["by"]), int(pr["since"]), int(pr["term"])], "Small", true))
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(String(st["name"]).to_upper(), UIColors.ACCENT, 16))
	card.add_child(tags)
	card.add_child(UIKit.label(String(st["desc"]), "Small", true))
	var rel := float(pr.get("rel", 50.0))
	var rr := UIKit.hbox(10)
	rr.add_child(UIKit.label("Relação pessoal", "Muted"))
	rr.add_child(UIKit.spacer())
	rr.add_child(UIKit.colored(People.rel_label(rel), UIColors.morale_color(rel), "H3"))
	card.add_child(rr)
	card.add_child(UIKit.bar(rel, 100.0, UIColors.morale_color(rel), 10))
	var conf := club.board_confidence
	var cr := UIKit.hbox(10)
	cr.add_child(UIKit.label("Confiança no trabalho", "Muted"))
	cr.add_child(UIKit.spacer())
	cr.add_child(UIKit.colored(BoardManager.label(conf), BoardManager.color(conf), "H3"))
	card.add_child(cr)
	card.add_child(UIKit.bar(conf, 100.0, BoardManager.color(conf), 10))
	card.add_child(UIKit.kv("Meta da temporada", String(SeasonManager.goal_of(w, club.id)[0])))
	var grace := int(People.data(w).get("grace", -1))
	if grace >= w.current_turn():
		card.add_child(UIKit.colored("Prazo dado pelo presidente: mais %d jogo(s) sem risco de demissão." % (grace - w.current_turn()), UIColors.GREEN, "Small", true))
	elif conf < BoardManager.ULTIMATUM:
		card.add_child(UIKit.colored("Ultimato: sem reação, a diretoria pode trocar o técnico a qualquer momento.", UIColors.RED, "Small", true))
	card.add_child(UIKit.button("Pedir uma reunião", "PrimaryButton", func(): TalkDialog.open("board", -1, cb), "shield"))
	c.add_child(UIKit.card_panel(card))
	var lg: Array = People.data(w).get("log", [])
	if not lg.is_empty():
		var lc := UIKit.card("Card", 6)
		lc.add_child(UIKit.section("Diário de bastidores"))
		var list := lg.duplicate()
		list.reverse()
		for e in list.slice(0, 10):
			lc.add_child(UIKit.label("%d · %s" % [int(e["y"]), String(e["t"])], "Small", true))
		c.add_child(UIKit.card_panel(lc))


# ---------------------------------------------------------------------------
# Torcida
# ---------------------------------------------------------------------------

func _fans(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	var club := w.user_club()
	var fans: Dictionary = People.data(w)["fans"]
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Torcida"))
	card.add_child(UIKit.label(String(fans.get("group", "")), "Title", true))
	card.add_child(UIKit.label("Líder: %s · %s torcedores de estádio" % [String(fans.get("leader", "")), Fmt.thousands(club.fan_base)], "Small", true))
	var sup := People.fan_support(w)
	var r1 := UIKit.hbox(10)
	r1.add_child(UIKit.label("Apoio ao treinador", "Muted"))
	r1.add_child(UIKit.spacer())
	r1.add_child(UIKit.colored(People.support_label(sup), UIColors.morale_color(sup), "H3"))
	card.add_child(r1)
	card.add_child(UIKit.bar(sup, 100.0, UIColors.morale_color(sup), 10))
	var r2 := UIKit.hbox(10)
	r2.add_child(UIKit.label("Humor com o clube", "Muted"))
	r2.add_child(UIKit.spacer())
	r2.add_child(UIKit.colored(UIColors.fans_label(club.fan_mood), UIColors.morale_color(club.fan_mood), "H3"))
	card.add_child(r2)
	card.add_child(UIKit.bar(club.fan_mood, 100.0, UIColors.morale_color(club.fan_mood), 10))
	card.add_child(UIKit.button("Ir até a organizada", "PrimaryButton", func(): TalkDialog.open("fans", -1, cb), "heart"))
	c.add_child(UIKit.card_panel(card))
	var chants: Array = fans.get("chants", [])
	if not chants.is_empty():
		var cc := UIKit.card("Card", 6)
		cc.add_child(UIKit.section("Nas arquibancadas"))
		var list := chants.duplicate()
		list.reverse()
		for ch in list:
			cc.add_child(UIKit.label(String(ch["t"]), "", true))
		c.add_child(UIKit.card_panel(cc))


# ---------------------------------------------------------------------------
# Imprensa
# ---------------------------------------------------------------------------

func _press(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	PressRoom.ensure_predictions(w, false)
	# Termômetro do cargo e bolsa de apostas
	var hc := UIKit.card("Card", 6)
	hc.add_child(UIKit.section("Termômetro do cargo"))
	var h := PressRoom.heat(w)
	var hcol := UIColors.RED if h >= PressRoom.HOT else (UIColors.ACCENT if h >= 50.0 else UIColors.GREEN)
	hc.add_child(UIKit.kv(PressRoom.heat_label(h), "%d/100" % int(round(h)), hcol))
	hc.add_child(UIKit.bar(h, 100.0, hcol))
	var race := PressRoom.sack_race(w, 4)
	if not race.is_empty():
		hc.add_child(UIKit.label("Bolsa de apostas: quem cai primeiro", "Caps"))
		for x in race:
			var cl := w.club(int(x[1]))
			hc.add_child(UIKit.kv("%s (%s)" % [String(x[0]), cl.short_name if cl != null else ""], "%.1f" % float(x[2]),
				UIColors.ACCENT if w.is_user_club(int(x[1])) else UIColors.TEXT))
	c.add_child(UIKit.card_panel(hc))
	# Palpites da pré-temporada
	var pred: Dictionary = People.data(w)["press"].get("pred", {})
	if not Array(pred.get("list", [])).is_empty():
		var pc := UIKit.card("Card", 6)
		pc.add_child(UIKit.section("Palpites da temporada"))
		var l := w.league_of(w.user_club_id)
		var now := CompetitionManager.position_of(l, w.user_club_id) if l != null and l.rounds_played() > 0 else 0
		pc.add_child(UIKit.label("A imprensa espera o time em %dº%s." % [PressRoom.consensus(w), " · hoje: %dº" % now if now > 0 else ""], "Small", true))
		for e: Dictionary in pred["list"]:
			var j := People.journalist(w, int(e["j"]))
			var ch := w.club(int(e["champ"]))
			pc.add_child(UIKit.kv(String(j.get("n", "")), "%dº · campeão: %s" % [int(e["pos"]), ch.short_name if ch != null else "?"]))
		c.add_child(UIKit.card_panel(pc))
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Setoristas"))
	for j: Dictionary in People.journalists(w):
		var row := UIKit.hbox(10)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(j["n"]), "H3"))
		col.add_child(UIKit.label("%s · %s · acerta %d%% dos rumores" % [String(j["o"]), String(People.PRESS_TONES.get(String(j["t"]), "")).to_lower(),
			int(round(PressRoom.accuracy(w, j) * 100.0))], "Small", true))
		row.add_child(col)
		var rel := float(j.get("rel", 50.0))
		row.add_child(UIKit.colored(People.rel_label(rel), UIColors.morale_color(rel), "Small"))
		card.add_child(row)
	var last := int(People.data(w)["press"].get("last", -99))
	var can := w.current_turn() - last >= 2
	var b := UIKit.button("Convocar coletiva" if can else "Coletiva feita há pouco", "PrimaryButton", func(): TalkDialog.open("press", -1, cb), "news")
	b.disabled = not can
	card.add_child(b)
	c.add_child(UIKit.card_panel(card))
	var rums: Array = People.data(w)["press"].get("rum", [])
	if not rums.is_empty():
		var rc := UIKit.card("Card", 6)
		rc.add_child(UIKit.section("Rumores de mercado"))
		var shown := 0
		for i in range(rums.size() - 1, -1, -1):
			var x: Dictionary = rums[i]
			var st := String(x["st"])
			var j := People.journalist(w, int(x["j"]))
			var row := UIKit.hbox(8)
			var nl := UIKit.label("%s → %s" % [String(x["n"]), String(x["tn"])], "", true)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(UIKit.pill("Confirmado" if st == "hit" else ("Não rolou" if st == "miss" else "Em aberto"),
				UIColors.GREEN if st == "hit" else (UIColors.MUTED if st == "miss" else UIColors.BLUE), 15))
			rc.add_child(row)
			rc.add_child(UIKit.label(String(j.get("o", "")), "Small"))
			shown += 1
			if shown >= 6:
				break
		c.add_child(UIKit.card_panel(rc))
	var nc := UIKit.card("Card", 6)
	nc.add_child(UIKit.section("Na imprensa"))
	var n := 0
	for i in range(w.news.size() - 1, -1, -1):
		var ne: NewsEvent = w.news[i]
		if not ne.category in ["imprensa", "tecnicos", "torcida", "rumor"]:
			continue
		nc.add_child(UIKit.label(ne.title, "H3", true))
		if ne.body != "":
			nc.add_child(UIKit.label(ne.body, "Small", true))
		n += 1
		if n >= 6:
			break
	if n == 0:
		nc.add_child(UIKit.label("Nada publicado ainda.", "Muted"))
	c.add_child(UIKit.card_panel(nc))


# ---------------------------------------------------------------------------
# Técnicos
# ---------------------------------------------------------------------------

func _coaches(w: GameWorld, c: VBoxContainer, cb: Callable) -> void:
	var me := UIKit.card("Card", 8)
	me.add_child(UIKit.section("Você no mercado"))
	var rep := People.manager_rep(w)
	var stars := StarsView.new()
	stars.star_size = 22.0
	stars.stars = clampf(rep / 20.0, 0.5, 5.0)
	me.add_child(stars)
	me.add_child(UIKit.label("Sua reputação decide quem te procura quando um clube troca de técnico.", "Small", true))
	c.add_child(UIKit.card_panel(me))
	var club := w.user_club()
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Técnicos da %s" % w.league_short(club.league_id)))
	var list: Array = []
	for cl: Club in w.clubs_in_league(club.league_id):
		if not w.is_user_club(cl.id):
			list.append(cl)
	list.sort_custom(func(a, b): return a.reputation > b.reputation)
	for cl: Club in list:
		var co := People.coach_of(w, cl.id)
		if co.is_empty():
			continue
		var row := UIKit.hbox(12)
		row.add_child(UIKit.crest(cl, 44))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(co["n"]), "H3", true))
		var job := float(co.get("job", 60.0))
		col.add_child(UIKit.label("%s · %s · %dV %dE %dD%s" % [cl.short_name, People.style_name(String(co["st"])), int(co.get("w", 0)), int(co.get("d", 0)), int(co.get("l", 0)), " · cargo balançando" if job < 30.0 else ""], "Small", true))
		row.add_child(col)
		var rel := People.coach_rel(w, int(co["id"]))
		row.add_child(UIKit.colored(People.coach_rel_label(rel), UIColors.GREEN if rel >= 12.0 else (UIColors.RED if rel <= -12.0 else UIColors.MUTED), "Small"))
		var cid := cl.id
		card.add_child(UIKit.tap_row(row, func(): TalkDialog.open("coach", cid, cb)))
	c.add_child(UIKit.card_panel(card))
