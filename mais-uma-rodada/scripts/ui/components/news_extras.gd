class_name NewsExtras
extends RefCounted
## Blocos de dados da matéria completa, montados a partir de NewsEvent.media (chaves curtas):
##   placar (home, away, hg, ag, comp, g [[min, lado, nome, tipo]]), transferência (fee, from, wg, ce, ov,
##   st [jogos, gols, assist., nota×10], rc = 1 recorde do clube), contrato (wg, ow, ce), lesão (wk, inj),
##   rumor (rid, to, rs, vl), post (tx), recorde (rc, rv, rx), carreira (cr [jogos, gols, títulos]),
##   tabela (tb [[clube, pts, j, saldo, pos]], lg, hl, zc), artilharia (tp [[nome, clube, gols]]),
##   giro (ru [[liga, líder, pts, vice, pts, artilheiro, gols, clube]]) e clássico (op, lg).
## Notícias antigas sem essas chaves simplesmente não ganham blocos.


static func blocks(w: GameWorld, n: NewsEvent) -> Array:
	var m := n.media
	var out: Array = []
	var t := String(m.get("type", ""))
	if m.has("hg") and m.has("home"):
		out.append(_score(w, m))
	if t == "signing":
		out.append(_signing(w, n, m))
	elif m.has("ce") and m.has("wg"):
		out.append(_contract(m))
	if m.has("wk"):
		out.append(_injury(w, n, m))
	if m.has("rid"):
		out.append(_rumor(w, m))
	if m.has("tx"):
		out.append(_post(w, n, m))
	if m.get("rc", null) is String:
		out.append(_record(m))
	if m.has("cr"):
		out.append(_career(m))
	if m.has("st") and t != "signing":
		out.append(_stats("Números na temporada", m["st"]))
	if m.has("tb"):
		out.append(_table(w, m))
	if m.has("tp"):
		out.append(_scorers(w, m))
	if m.has("ru"):
		out.append(_roundup(w, m))
	if m.has("op"):
		out.append(_derby(w, n, m))
	if out.is_empty():
		out.append(_player_facts(w, n))
	return out.filter(func(x): return x != null)


static func _box(title: String) -> VBoxContainer:
	var v := UIKit.card("CardInset", 8)
	if title != "":
		v.add_child(UIKit.label(title, "Caps"))
	return v


static func _club_name(w: GameWorld, id: int, fallback: String = "—") -> String:
	var c := w.club(id)
	return c.short_name if c != null else fallback


# ---------------------------------------------------------------------------

static func _score(w: GameWorld, m: Dictionary) -> Control:
	var h := w.club(int(m.get("home", -1)))
	var a := w.club(int(m.get("away", -1)))
	if h == null or a == null:
		return null
	var comp := String(m.get("comp", ""))
	var v := _box(FootballMemory.comp_name(w, comp) if comp != "" else "Placar")
	var row := UIKit.hbox(10)
	row.add_child(UIKit.crest(h, 44))
	var hn := UIKit.label(h.short_name, "H3")
	hn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(hn)
	var sc := UIKit.label("%d x %d" % [int(m.get("hg", 0)), int(m.get("ag", 0))], "Stat")
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc.custom_minimum_size.x = 96
	row.add_child(sc)
	var an := UIKit.label(a.short_name, "H3")
	an.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	an.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	an.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(an)
	row.add_child(UIKit.crest(a, 44))
	v.add_child(row)
	var goals: Array = m.get("g", [])
	if not goals.is_empty():
		var cols := UIKit.hbox(12)
		for side in 2:
			var col := UIKit.vbox(2)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for g: Array in goals:
				if int(g[1]) != side:
					continue
				var tag := " (pên.)" if int(g[3]) == Fixture.GOAL_PENALTY else (" (contra)" if int(g[3]) == Fixture.GOAL_OWN else "")
				var l := UIKit.label("%d'  %s%s" % [int(g[0]), String(g[2]) if String(g[2]) != "" else "—", tag], "Small")
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
				l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				col.add_child(l)
			cols.add_child(col)
		v.add_child(UIKit.separator())
		v.add_child(cols)
	return UIKit.card_panel(v)


static func _signing(w: GameWorld, n: NewsEvent, m: Dictionary) -> Control:
	var v := _box("Ficha da transferência")
	if int(m.get("rc", 0)) == 1:
		v.add_child(UIKit.pill("RECORDE DO CLUBE", UIColors.GREEN, 15))
	var fee := int(m.get("fee", 0))
	v.add_child(UIKit.kv("De", _club_name(w, int(m.get("from", -1)), "Sem clube")))
	v.add_child(UIKit.kv("Para", _club_name(w, int(m.get("club", -1)))))
	v.add_child(UIKit.kv("Valor", Fmt.money(fee) if fee > 0 else "Sem custo", UIColors.ACCENT if fee > 0 else UIColors.TEXT))
	if m.has("wg"):
		v.add_child(UIKit.kv("Salário", Fmt.money_month(int(m["wg"]))))
	if m.has("ce"):
		v.add_child(UIKit.kv("Contrato até", str(int(m["ce"]))))
	if m.has("ov"):
		v.add_child(UIKit.kv("Nível na chegada", str(int(m["ov"]))))
	var st: Array = m.get("st", [])
	if st.size() >= 4:
		v.add_child(UIKit.label("Na temporada, antes da troca", "Caps"))
		v.add_child(_tiles(st))
	# Última temporada fechada (só deste jogador, na hora de abrir a matéria)
	var p := w.player(int(m.get("player", -1)))
	if p != null:
		var last: Dictionary = {}
		for row: Dictionary in p.history:
			if int(row.get("y", 0)) < n.year:
				last = row
		if not last.is_empty():
			var txt := "%d · %s: %d jogos, %d gols, %d assist." % [int(last.get("y", 0)), String(last.get("cn", "")), int(last.get("a", 0)), int(last.get("g", 0)), int(last.get("as", 0))]
			if float(last.get("r", 0.0)) > 0.0:
				txt += ", nota %.1f" % float(last["r"])
			v.add_child(UIKit.label("Última temporada", "Caps"))
			v.add_child(UIKit.label(txt, "Small", true))
	return UIKit.card_panel(v)


static func _tiles(st: Array) -> Control:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override(&"h_separation", 8)
	var r := float(st[3]) / 10.0
	for pair in [[str(int(st[0])), "Jogos"], [str(int(st[1])), "Gols"], [str(int(st[2])), "Assist."], ["%.1f" % r if r > 0.0 else "—", "Nota"]]:
		g.add_child(UIKit.stat(String(pair[0]), String(pair[1])))
	return g


static func _stats(title: String, st: Array) -> Control:
	if st.size() < 4:
		return null
	var v := _box(title)
	v.add_child(_tiles(st))
	return UIKit.card_panel(v)


static func _contract(m: Dictionary) -> Control:
	var v := _box("Contrato")
	var wg := int(m.get("wg", 0))
	if m.has("ow") and int(m["ow"]) > 0 and int(m["ow"]) != wg:
		v.add_child(UIKit.kv("Salário", "%s → %s" % [Fmt.money_month(int(m["ow"])), Fmt.money_month(wg)], UIColors.GREEN))
	else:
		v.add_child(UIKit.kv("Salário atual", Fmt.money_month(wg)))
	v.add_child(UIKit.kv("Contrato até", str(int(m.get("ce", 0)))))
	return UIKit.card_panel(v)


static func _injury(w: GameWorld, n: NewsEvent, m: Dictionary) -> Control:
	var wk := int(m.get("wk", 0))
	var v := _box("Boletim médico")
	var g := UIKit.hbox(8)
	g.add_child(UIKit.stat("%d" % wk, "semanas fora", UIColors.RED))
	g.add_child(UIKit.stat(InjuryTable.severity_label(wk).capitalize(), "gravidade"))
	g.add_child(UIKit.stat("~%d" % (n.day + 1 + wk), "volta (rodada)"))
	v.add_child(g)
	if m.has("inj") and String(m["inj"]) != "":
		v.add_child(UIKit.kv("Lesão", String(m["inj"])))
	var p := w.player(int(m.get("player", -1)))
	if p != null and n.year == w.year:
		if p.injury_weeks > 0:
			v.add_child(UIKit.label(("Hoje: ainda faltam %d semana de recuperação." if p.injury_weeks == 1 else "Hoje: ainda faltam %d semanas de recuperação.") % p.injury_weeks, "Small", true))
		else:
			v.add_child(UIKit.colored("Hoje: já está recuperado.", UIColors.GREEN, "Small", true))
	return UIKit.card_panel(v)


static func _rumor(w: GameWorld, m: Dictionary) -> Control:
	var v := _box("Situação do rumor")
	var rs := int(m.get("rs", WorldPulse.RS_OPEN))
	var head := UIKit.hbox(10)
	var to := w.club(int(m.get("to", -1)))
	if to != null:
		head.add_child(UIKit.crest(to, 36))
		var l := UIKit.label("Interessado: %s" % to.short_name, "H3")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.add_child(l)
	match rs:
		WorldPulse.RS_TRUE:
			head.add_child(UIKit.pill("CONFIRMADO", UIColors.GREEN, 14))
		WorldPulse.RS_FALSE:
			head.add_child(UIKit.pill("NÃO SE CONFIRMOU", UIColors.RED, 14))
		_:
			head.add_child(UIKit.pill("EM ABERTO", UIColors.ACCENT, 14))
	v.add_child(head)
	if m.has("vl"):
		v.add_child(UIKit.kv("Valor de mercado", Fmt.money(int(m["vl"]))))
	if rs == WorldPulse.RS_OPEN:
		v.add_child(UIKit.label("A imprensa acompanha o caso: a resposta sai nas próximas semanas.", "Small", true))
	return UIKit.card_panel(v)


static func _post(w: GameWorld, n: NewsEvent, m: Dictionary) -> Control:
	var p := w.player(int(m.get("player", -1)))
	var v := _box("")
	var head := UIKit.hbox(10)
	if p != null:
		head.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 52))
	var who := UIKit.vbox(0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := p.display_name() if p != null else "Jogador"
	who.add_child(UIKit.label(name, "H3"))
	who.add_child(UIKit.label("@" + SocialFeed.slug(name), "Small"))
	head.add_child(who)
	head.add_child(UIKit.icon_rect("heart", 22, UIColors.RED))
	v.add_child(head)
	v.add_child(UIKit.label(String(m.get("tx", "")), "H2", true))
	var h := absi(hash(n.title))
	var base := 800 + (p.overall * p.overall * 3 if p != null else 2000)
	var likes := base + h % maxi(1, base)
	v.add_child(UIKit.label("%s curtidas · %s comentários" % [SocialFeed.count(likes), SocialFeed.count(likes / 14 + 5)], "Small"))
	return UIKit.card_panel(v)


static func _record(m: Dictionary) -> Control:
	var v := _box("Em destaque")
	var big := UIKit.colored(String(m.get("rv", "")), UIColors.ACCENT, "Stat")
	v.add_child(big)
	v.add_child(UIKit.label(String(m.get("rc", "")), "H3"))
	if m.has("rx"):
		v.add_child(UIKit.label(String(m["rx"]), "Small", true))
	return UIKit.card_panel(v)


static func _career(m: Dictionary) -> Control:
	var cr: Array = m.get("cr", [])
	if cr.size() < 3:
		return null
	var v := _box("Carreira")
	var g := UIKit.hbox(8)
	g.add_child(UIKit.stat(str(int(cr[0])), "jogos"))
	g.add_child(UIKit.stat(str(int(cr[1])), "gols"))
	g.add_child(UIKit.stat(str(int(cr[2])), "títulos", UIColors.D_GOLD))
	v.add_child(g)
	return UIKit.card_panel(v)


static func _table(w: GameWorld, m: Dictionary) -> Control:
	var rows: Array = m.get("tb", [])
	if rows.is_empty():
		return null
	var lid := String(m.get("lg", ""))
	var v := _box(("Tabela · " + w.league_short(lid)) if lid != "" else "Tabela")
	var hl: Array = m.get("hl", [])
	var zc := int(m.get("zc", 0))
	var head := UIKit.hbox(8)
	var ht := UIKit.label("", "Caps")
	ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(ht)
	for cap in ["J", "SG", "PTS"]:
		var l := UIKit.label(cap, "Caps")
		l.custom_minimum_size.x = 44
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		head.add_child(l)
	v.add_child(head)
	for r: Array in rows:
		var c := w.club(int(r[0]))
		if c == null:
			continue
		var h := UIKit.hbox(8)
		var pos := int(r[4])
		var pl := UIKit.label("%d" % pos, "Mono")
		pl.custom_minimum_size.x = 30
		if zc > 0 and pos >= zc:
			pl.add_theme_color_override(&"font_color", UIColors.RED)
		h.add_child(pl)
		h.add_child(UIKit.crest(c, 24))
		var nm := UIKit.label(c.short_name, "H3" if hl.has(c.id) else "")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if hl.has(c.id):
			nm.add_theme_color_override(&"font_color", UIColors.ACCENT)
		h.add_child(nm)
		for val in [str(int(r[2])), "%+d" % int(r[3]), str(int(r[1]))]:
			var l := UIKit.label(val, "Small" if val != str(int(r[1])) else "H3")
			l.custom_minimum_size.x = 44
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			h.add_child(l)
		v.add_child(h)
	return UIKit.card_panel(v)


static func _scorers(w: GameWorld, m: Dictionary) -> Control:
	var rows: Array = m.get("tp", [])
	if rows.is_empty():
		return null
	var v := _box("Artilharia")
	for i in rows.size():
		var r: Array = rows[i]
		v.add_child(UIKit.kv("%d. %s · %s" % [i + 1, String(r[0]), _club_name(w, int(r[1]))], Fmt.n_of(int(r[2]), "%d gol", "%d gols")))
	return UIKit.card_panel(v)


static func _roundup(w: GameWorld, m: Dictionary) -> Control:
	var rows: Array = m.get("ru", [])
	if rows.is_empty():
		return null
	var v := _box("Como estão as grandes ligas")
	for i in rows.size():
		var r: Array = rows[i]
		if i > 0:
			v.add_child(UIKit.separator())
		var lid := String(r[0])
		var head := UIKit.hbox(8)
		head.add_child(UIKit.flag(String(DatabaseManager.league_cfg(lid).get("nation", "")), 28))
		head.add_child(UIKit.label(w.league_name(lid), "H3"))
		v.add_child(head)
		for k in 2:
			var c := w.club(int(r[1 + k * 2]))
			if c == null:
				continue
			var h := UIKit.hbox(8)
			h.add_child(UIKit.label("%dº" % (k + 1), "Mono"))
			h.add_child(UIKit.crest(c, 22))
			var nm := UIKit.label(c.short_name, "")
			nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(nm)
			h.add_child(UIKit.label("%d pts" % int(r[2 + k * 2]), "H3" if k == 0 else "Small"))
			v.add_child(h)
		if String(r[5]) != "":
			v.add_child(UIKit.label("Artilheiro: %s (%s), %d gols" % [String(r[5]), _club_name(w, int(r[7])), int(r[6])], "Small", true))
	return UIKit.card_panel(v)


static func _derby(w: GameWorld, n: NewsEvent, m: Dictionary) -> Control:
	var h := w.club(int(m.get("club", n.club_id)))
	var a := w.club(int(m.get("op", -1)))
	if h == null or a == null:
		return null
	var v := _box("Retrospecto")
	var hh := FootballMemory.head_to_head(w, h.id, a.id)
	if int(hh["games"]) == 0:
		var first := UIKit.hbox(10)
		first.add_child(UIKit.crest(h, 36))
		var l := UIKit.label("Primeiro encontro entre os dois.", "Small", true)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		first.add_child(l)
		first.add_child(UIKit.crest(a, 36))
		v.add_child(first)
		return UIKit.card_panel(v)
	var top := UIKit.hbox(8)
	top.add_child(UIKit.crest(h, 36))
	top.add_child(UIKit.stat(str(int(hh["wins"])), "vitórias " + h.short_name, UIColors.ACCENT))
	top.add_child(UIKit.stat(str(int(hh["draws"])), "empates"))
	top.add_child(UIKit.stat(str(int(hh["losses"])), "vitórias " + a.short_name, UIColors.BLUE))
	top.add_child(UIKit.crest(a, 36))
	v.add_child(top)
	v.add_child(UIKit.label("%d jogos no total, gols %d x %d." % [int(hh["games"]), int(hh["gf"]), int(hh["ga"])], "Small", true))
	var recent: Array = hh["recent"]
	for e: Dictionary in recent.slice(maxi(0, recent.size() - 3)):
		var home := w.club(int(e["home"]))
		var away := a if int(e["home"]) == h.id else h
		v.add_child(UIKit.kv("%d · %s" % [int(e["y"]), FootballMemory.comp_name(w, String(e["comp"]))],
			"%s %d x %d %s" % [home.short_name if home != null else "", int(e["hg"]), int(e["ag"]), away.short_name]))
	return UIKit.card_panel(v)


## Sem dados guardados: a ficha do jogador da notícia na temporada (só para notícias deste ano).
static func _player_facts(w: GameWorld, n: NewsEvent) -> Control:
	var p := w.player(n.player_id) if n.player_id >= 0 else null
	if p == null or n.year != w.year or p.club_id < 0:
		return null
	var t := p.season_totals()
	if int(t[0]) <= 0:
		return null
	var v := _box("%s · %d anos · %s" % [p.display_name(), p.age(w.year), Pos.name_of(p.position)])
	v.add_child(_tiles([int(t[0]), int(t[1]), int(t[2]), int(round(p.avg_rating() * 10.0))]))
	return UIKit.card_panel(v)
