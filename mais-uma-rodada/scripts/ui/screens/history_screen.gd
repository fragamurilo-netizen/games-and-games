extends BaseScreen
## Memória do save: a carreira do treinador, campeões de cada competição ano a ano,
## prêmios individuais, recordes do clube e as lendas aposentadas.

const TABS := [["career", "Carreira"], ["seasons", "Temporadas"], ["champions", "Campeões"], ["awards", "Prêmios"], ["club", "Clube"], ["legends", "Lendas"]]

var _tab := "career"
var _comp := ""
var _year := -1 # temporada escolhida na aba Temporadas
var _arch_league := ""
var _arch_view := "tb" # tb (tabela) | sc | as | rt
var _month_pick := 0 # seleção do mês mostrada na aba Temporadas


func _init() -> void:
	show_nav = false
	screen_title = "História"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "career"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var played := 0
	for h in w.history:
		if not h.get("pre", false):
			played += 1
	screen_subtitle = "%d temporada(s) no save" % played
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var g := ButtonGroup.new()
	var row := UIKit.flow(8)
	for t in TABS:
		var key: String = t[0]
		row.add_child(UIKit.chip(t[1], key == _tab, g, func():
			_tab = key
			refresh()))
	c.add_child(row)
	match _tab:
		"career":
			c.add_child(_career(w))
		"seasons":
			_seasons(w, c)
		"champions":
			_champions(w, c)
		"awards":
			c.add_child(_awards(w))
		"club":
			_club(w, c)
		"legends":
			c.add_child(_legends(w))


# ---------------------------------------------------------------------------
# Carreira
# ---------------------------------------------------------------------------

func _career(w: GameWorld) -> Control:
	var card := UIKit.card("CardHighlight", 10)
	var ms := w.manager_stats
	var head := UIKit.hbox(14)
	head.add_child(ManagerProfile.portrait(w, 96))
	var hc := UIKit.vbox(2)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hc.add_child(UIKit.label(w.manager_name, "Title", true))
	hc.add_child(UIKit.label("Treinador · %s · %s" % [ManagerProfile.style_name(ManagerProfile.style(w)), GameWorld.DIFF_NAMES[w.difficulty]], "Small", true))
	var fame := CoachIdentity.headline(w)
	if fame != "":
		var fp := UIKit.pill(fame.to_upper(), UIColors.ACCENT, 14)
		fp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		hc.add_child(fp)
	head.add_child(hc)
	card.add_child(head)
	var r1 := UIKit.hbox(4)
	r1.add_child(UIKit.stat(str(int(ms.get("seasons", 0))), "temporadas"))
	r1.add_child(UIKit.stat(str(int(ms.get("games", 0))), "jogos"))
	r1.add_child(UIKit.stat(str(int(ms.get("titles", 0))), "títulos", UIColors.ACCENT))
	r1.add_child(UIKit.stat(str(int(ms.get("promotions", 0))), "acessos", UIColors.GREEN))
	card.add_child(r1)
	var games := maxi(1, int(ms.get("games", 0)))
	var wins := int(ms.get("w", 0))
	card.add_child(UIKit.kv("Vitórias / empates / derrotas", "%d / %d / %d" % [wins, int(ms.get("d", 0)), int(ms.get("l", 0))]))
	card.add_child(UIKit.kv("Aproveitamento", "%d%%" % int(round(100.0 * (wins * 3 + int(ms.get("d", 0))) / (games * 3.0)))))
	var out := UIKit.vbox(12)
	out.add_child(UIKit.card_panel(card))
	var tl := UIKit.card("Card", 6)
	tl.add_child(UIKit.section("Linha do tempo"))
	var any := false
	for i in range(w.history.size() - 1, -1, -1):
		var h: Dictionary = w.history[i]
		var u: Dictionary = h.get("user", {})
		if u.is_empty():
			continue
		any = true
		var cl := w.club(int(h.get("club", w.user_club_id)))
		var row := UIKit.hbox(10)
		row.add_child(UIKit.label(str(int(h["y"])), "H3"))
		if cl != null:
			row.add_child(UIKit.crest(cl, 36))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("%dº · %s" % [int(u.get("pos", 0)), String(u.get("league_name", ""))], "", true))
		var bits: Array = []
		for cu in u.get("cups", []):
			bits.append("%s: %s" % [CupManager.cup_short(String(cu["id"])), "CAMPEÃO" if cu.get("champion", false) else String(cu.get("stage", ""))])
		if not bits.is_empty():
			col.add_child(UIKit.label(" · ".join(bits), "Small", true))
		row.add_child(col)
		if u.get("champion", false):
			row.add_child(UIKit.pill("CAMPEÃO", UIColors.ACCENT, 16))
		elif u.get("promoted", false):
			row.add_child(UIKit.pill("ACESSO", UIColors.GREEN, 16))
		elif u.get("relegated", false):
			row.add_child(UIKit.pill("QUEDA", UIColors.RED, 16))
		tl.add_child(row)
	if not any:
		tl.add_child(UIKit.label("A primeira temporada ainda está em andamento. A história começa a ser escrita no fim do ano.", "Muted", true))
	out.add_child(UIKit.card_panel(tl))
	return out


# ---------------------------------------------------------------------------
# Temporadas anteriores
# ---------------------------------------------------------------------------

func _seasons(w: GameWorld, c: VBoxContainer) -> void:
	if w.history.is_empty():
		var empty := UIKit.card("Card", 6)
		empty.add_child(UIKit.label("A tabela e os números ficam guardados aqui no fim do ano.", "Muted", true))
		c.add_child(UIKit.card_panel(empty))
		return
	var idx := -1
	for i in w.history.size():
		if int(w.history[i]["y"]) == _year:
			idx = i
	if idx < 0:
		idx = w.history.size() - 1
		_year = int(w.history[idx]["y"])
	var h: Dictionary = w.history[idx]
	# Navegação entre anos
	var nav := UIKit.hbox(10)
	var prev := UIKit.button("", "", func():
		_year = int(w.history[idx - 1]["y"])
		refresh(), "back")
	prev.disabled = idx <= 0
	nav.add_child(prev)
	var yl := UIKit.label("Temporada %d" % _year, "Title")
	yl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	yl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(yl)
	var nxt := UIKit.button("", "", func():
		_year = int(w.history[idx + 1]["y"])
		refresh(), "play")
	nxt.disabled = idx >= w.history.size() - 1
	nav.add_child(nxt)
	c.add_child(nav)
	# Resumo do usuário
	var u: Dictionary = h.get("user", {})
	if not u.is_empty():
		var uc := UIKit.card("CardHighlight", 6)
		var cl := w.club(int(h.get("club", w.user_club_id)))
		var row := UIKit.hbox(10)
		if cl != null:
			row.add_child(UIKit.crest(cl, 48))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("%dº na %s" % [int(u.get("pos", 0)), String(u.get("league_name", ""))], "H3", true))
		col.add_child(UIKit.label("Meta: %s · %s" % [String(u.get("goal", "")), "cumprida" if u.get("goal_met", false) else "não cumprida"], "Small", true))
		row.add_child(col)
		if u.get("champion", false):
			row.add_child(UIKit.pill("CAMPEÃO", UIColors.ACCENT, 16))
		elif u.get("promoted", false):
			row.add_child(UIKit.pill("ACESSO", UIColors.GREEN, 16))
		elif u.get("relegated", false):
			row.add_child(UIKit.pill("QUEDA", UIColors.RED, 16))
		uc.add_child(row)
		var cp: Dictionary = h.get("cp", {})
		if not cp.is_empty():
			uc.add_child(UIKit.kv(AwardManager.award_name("club"), "%s · nota %s" % [cp["name"], cp.get("v", "")], UIColors.ACCENT))
		c.add_child(UIKit.card_panel(uc))
	# Liga arquivada
	var arch: Dictionary = h.get("arch", {})
	if arch.is_empty():
		var old := UIKit.card("Card", 6)
		if h.get("pre", false):
			old.add_child(UIKit.section("Antes do seu início"))
			var lines: Array = []
			for lid in h.get("leagues", {}):
				var champ := w.club(int(h["leagues"][lid]["champion"]))
				if champ != null and (DatabaseManager.league_cfg(String(lid)).get("tier", 1) == 1 or DatabaseManager.league_cfg(String(lid)).get("nation", "") == w.user_nation()):
					lines.append([w.league_short(String(lid)), champ, "L:" + String(lid)])
			for cid in h.get("cups", {}):
				var champ := w.club(int(h["cups"][cid]["champion"]))
				if champ != null and CupManager.relevant_to_user(w, String(cid)):
					lines.append([CupManager.cup_short(String(cid)), champ, CupManager.title_key(String(cid))])
			for ln in lines:
				var row := UIKit.hbox(10)
				row.add_child(TrophyView.make(String(ln[2]), 34, w))
				var ll := UIKit.label(String(ln[0]), "Small")
				ll.custom_minimum_size.x = 170
				row.add_child(ll)
				row.add_child(UIKit.crest(ln[1], 28))
				var nl := UIKit.label((ln[1] as Club).name, "", true)
				if w.is_user_club((ln[1] as Club).id):
					nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
				row.add_child(nl)
				old.add_child(row)
			old.add_child(UIKit.label("Temporada anterior ao início do jogo: ficam registrados só os campeões.", "Muted", true))
		else:
			old.add_child(UIKit.label("Esta temporada foi jogada antes do arquivo de estatísticas existir: só campeões e prêmios foram guardados.", "Muted", true))
		c.add_child(UIKit.card_panel(old))
	else:
		if not arch.has(_arch_league):
			_arch_league = String(u.get("league", "")) if arch.has(String(u.get("league", ""))) else String(arch.keys()[0])
		var g := ButtonGroup.new()
		var flow := UIKit.flow(8)
		for lid in arch:
			var id := String(lid)
			flow.add_child(UIKit.chip(w.league_short(id), id == _arch_league, g, func():
				_arch_league = id
				refresh()))
		c.add_child(flow)
		c.add_child(_arch_card(w, h, arch[_arch_league]))
	# Bola de Ouro do ano
	var bo: Array = h.get("bo", [])
	if not bo.is_empty():
		var bc := UIKit.card("Card", 4)
		bc.add_child(UIKit.section("Bola de Ouro · votação"))
		for i in bo.size():
			var e: Dictionary = bo[i]
			var row := UIKit.hbox(10)
			var rk := UIKit.label(str(i + 1), "H3")
			rk.custom_minimum_size.x = 36
			if i == 0:
				rk.add_theme_color_override(&"font_color", UIColors.ACCENT)
			row.add_child(rk)
			row.add_child(UIKit.flag(String(e.get("nat", "")), 30))
			var nl := UIKit.label("%s (%s)" % [e["name"], e["club"]], "", true)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(UIKit.label("%d pts" % int(e.get("pts", 0)), "Small"))
			bc.add_child(_player_tap(row, int(e["id"])))
		c.add_child(UIKit.card_panel(bc))
	# Seleções do mês
	var months: Array = h.get("months", [])
	if not months.is_empty():
		var mc := UIKit.card("Card", 6)
		mc.add_child(UIKit.section("Seleções do mês"))
		var g := ButtonGroup.new()
		var fl := UIKit.flow(8)
		_month_pick = clampi(_month_pick, 0, months.size() - 1)
		for i in months.size():
			var mi := i
			fl.add_child(UIKit.chip(WeeklyAwards.month_label(int(months[i]["m"])).capitalize(), i == _month_pick, g, func():
				_month_pick = mi
				refresh()))
		mc.add_child(fl)
		var m: Dictionary = months[_month_pick]
		var best := w.player(int(m["best"]))
		if best != null:
			mc.add_child(_player_tap(UIKit.label("Craque do mês: %s" % best.display_name(), "H3", true), best.id))
		if Array(m.get("ids", [])).size() == 11:
			mc.add_child(XIPitch.make(w, m.get("ids", []), m.get("rt", []), int(m["best"])))
		else:
			mc.add_child(UIKit.label(_xi_text(w, m.get("ids", [])), "Small", true))
		c.add_child(UIKit.card_panel(mc))
	# Elenco do usuário no ano
	var sq: Array = h.get("sq", [])
	if not sq.is_empty():
		c.add_child(_squad_card(w, sq))
	# Copas do ano
	var cups: Dictionary = h.get("cups", {})
	if not cups.is_empty():
		var cc := UIKit.card("Card", 4)
		cc.add_child(UIKit.section("Copas"))
		for cid in cups:
			var e: Dictionary = cups[cid]
			var champ := w.club(int(e.get("champion", -1)))
			if champ == null or not (CupManager.relevant_to_user(w, String(cid)) or w.is_user_club(champ.id)):
				continue
			var row := UIKit.hbox(10)
			row.add_child(TrophyView.make(CupManager.title_key(String(cid)), 40, w))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label(CupManager.cup_name(String(cid)), "Small"))
			var nl := UIKit.label(champ.name, "H3", true)
			if w.is_user_club(champ.id):
				nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
			col.add_child(nl)
			var mvp: Dictionary = e.get("mvp", {})
			if not mvp.is_empty():
				col.add_child(UIKit.label("Craque da copa: %s (%s)" % [mvp["name"], mvp["club"]], "Small", true))
			row.add_child(col)
			cc.add_child(row)
		c.add_child(UIKit.card_panel(cc))


func _arch_card(w: GameWorld, h: Dictionary, a: Dictionary) -> Control:
	var card := UIKit.card("Card", 4)
	var head := UIKit.hbox(10)
	head.add_child(TrophyView.make("L:" + _arch_league, 44, w))
	var t := UIKit.section(w.league_name(_arch_league))
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	card.add_child(head)
	var g := ButtonGroup.new()
	var views := UIKit.flow(8)
	for v in [["tb", "Tabela"], ["sc", "Gols"], ["as", "Assistências"], ["rt", "Notas"], ["aw", "Prêmios"]]:
		var key: String = v[0]
		views.add_child(UIKit.chip(String(v[1]), key == _arch_view, g, func():
			_arch_view = key
			refresh()))
	card.add_child(views)
	var lh: Dictionary = h.get("leagues", {}).get(_arch_league, {})
	match _arch_view:
		"tb":
			var tb: Array = a.get("tb", [])
			var promoted: Array = lh.get("promoted", [])
			var relegated: Array = lh.get("relegated", [])
			var hdr := UIKit.hbox(6)
			var hl := UIKit.label("#  Clube", "Caps")
			hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hdr.add_child(hl)
			hdr.add_child(UIKit.label("PTS  V-E-D  SG", "Caps"))
			card.add_child(hdr)
			for i in tb.size():
				var r: Array = tb[i]
				var row := UIKit.hbox(6)
				var pos := UIKit.label(str(i + 1), "Mono")
				pos.custom_minimum_size.x = 40
				var cid := int(r[0])
				if i == 0:
					pos.add_theme_color_override(&"font_color", UIColors.ACCENT)
				elif promoted.has(cid):
					pos.add_theme_color_override(&"font_color", UIColors.GREEN)
				elif relegated.has(cid):
					pos.add_theme_color_override(&"font_color", UIColors.RED)
				row.add_child(pos)
				var cl := w.club(cid)
				if cl != null:
					row.add_child(UIKit.crest(cl, 26))
				var nl := UIKit.label(String(r[1]), "")
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				if w.is_user_club(cid):
					nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
				row.add_child(nl)
				var gd := int(r[6]) - int(r[7])
				row.add_child(UIKit.label("%d  %d-%d-%d  %s%d" % [int(r[2]), int(r[3]), int(r[4]), int(r[5]), "+" if gd > 0 else "", gd], "Mono"))
				card.add_child(row)
		"sc", "as", "rt":
			var list: Array = a.get(_arch_view, [])
			if list.is_empty():
				card.add_child(UIKit.label("Sem registros.", "Muted"))
			for i in list.size():
				var r: Array = list[i]
				var row := UIKit.hbox(10)
				var rk := UIKit.label(str(i + 1), "H3")
				rk.custom_minimum_size.x = 36
				row.add_child(rk)
				var nl := UIKit.label("%s (%s)" % [r[1], r[2]], "", true)
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(nl)
				row.add_child(UIKit.label(Fmt.rating(float(r[3])) if _arch_view == "rt" else str(int(r[3])), "Stat"))
				card.add_child(_player_tap(row, int(r[0])))
		"aw":
			var aw: Dictionary = lh.get("awards", {})
			for k in AwardManager.LEAGUE_KEYS:
				if not aw.has(k):
					continue
				var ad: Dictionary = aw[k]
				var row := UIKit.hbox(10)
				var kl := UIKit.label(AwardManager.award_name(k), "Small")
				kl.custom_minimum_size.x = 170
				row.add_child(kl)
				var nl := UIKit.label("%s (%s)" % [ad["name"], ad["club"]], "", true)
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(nl)
				row.add_child(UIKit.label(String(ad.get("v", "")), "Small"))
				card.add_child(_player_tap(row, int(ad["id"])))
			var co: Dictionary = lh.get("coach", {})
			if not co.is_empty():
				var row := UIKit.hbox(10)
				var kl := UIKit.label(AwardManager.award_name("coach"), "Small")
				kl.custom_minimum_size.x = 170
				row.add_child(kl)
				var nl := UIKit.label("%s (%s)" % [co["n"], co["cn"]], "", true)
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				if co.get("user", false):
					nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
				row.add_child(nl)
				row.add_child(UIKit.label(String(co.get("v", "")), "Small"))
				card.add_child(row)
			var team: Array = lh.get("team", [])
			if team.size() == 11:
				card.add_child(UIKit.label(AwardManager.award_name("team"), "Caps"))
				card.add_child(XIPitch.make(w, team, [], -1, 640))
			elif not team.is_empty():
				card.add_child(UIKit.label(AwardManager.award_name("team"), "Caps"))
				card.add_child(UIKit.label(_xi_text(w, team), "Small", true))
			if aw.is_empty():
				card.add_child(UIKit.label("Sem prêmios registrados.", "Muted"))
	return UIKit.card_panel(card)


static func _xi_text(w: GameWorld, ids: Array) -> String:
	var names: Array = []
	for pid in ids:
		var p := w.player(int(pid))
		names.append(p.display_name() if p != null else "—")
	if names.size() != 11:
		return ", ".join(names)
	return "%s · %s · %s · %s" % [names[0], ", ".join(names.slice(1, 5)), ", ".join(names.slice(5, 8)), ", ".join(names.slice(8, 11))]


func _squad_card(w: GameWorld, sq: Array) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section("Seu elenco no ano"))
	var hdr := UIKit.hbox(6)
	var hl := UIKit.label("Jogador", "Caps")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(hl)
	hdr.add_child(UIKit.label("J  G  A  NOTA  OVR", "Caps"))
	card.add_child(hdr)
	for r: Array in sq:
		var row := UIKit.hbox(8)
		row.add_child(UIKit.pos_badge(int(r[2])))
		var nl := UIKit.label(String(r[1]), "")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(nl)
		row.add_child(UIKit.label("%d  %d  %d  %s" % [int(r[3]), int(r[4]), int(r[5]), Fmt.rating(float(r[6]))], "Mono"))
		var d := int(r[8]) if r.size() > 8 else 0
		var ol := UIKit.label("%d%s" % [int(r[7]), (" +%d" % d) if d > 0 else ((" %d" % d) if d < 0 else "")], "Mono")
		ol.custom_minimum_size.x = 92
		ol.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if d != 0:
			ol.add_theme_color_override(&"font_color", UIColors.GREEN if d > 0 else UIColors.RED)
		row.add_child(ol)
		card.add_child(_player_tap(row, int(r[0])))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Campeões
# ---------------------------------------------------------------------------

func _comp_options(w: GameWorld) -> Array:
	var out: Array = []
	var nat := w.user_nation()
	for id in DatabaseManager.leagues_of_nation(nat):
		out.append([id, w.league_short(id)])
	var confed := String(DatabaseManager.nation(nat).get("confed", ""))
	for cid in DatabaseManager.cups_cfg():
		var cfg := DatabaseManager.cup_cfg(cid)
		if cfg.has("nation"):
			if String(cfg.get("nation", "")) == nat:
				out.append([cid, String(cfg.get("short", cid))])
		elif String(cfg.get("confed", "")) == confed or String(cfg.get("confed", "")) == "" or cid == "CWC":
			out.append([cid, String(cfg.get("short", cid))])
	for id in ["ENG1", "ESP1", "ITA1", "GER1", "FRA1", "BRA1", "ARG1"]:
		if DatabaseManager.has_league(id) and not DatabaseManager.leagues_of_nation(nat).has(id):
			out.append([id, w.league_short(id)])
	out.append(["YOUTH", "Sub-20"])
	return out


func _champions(w: GameWorld, c: VBoxContainer) -> void:
	var opts := _comp_options(w)
	if _comp == "":
		_comp = String(opts[0][0])
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for o in opts:
		var id: String = o[0]
		flow.add_child(UIKit.chip(String(o[1]), id == _comp, g, func():
			_comp = id
			refresh()))
	c.add_child(flow)
	var card := UIKit.card("Card", 6)
	var is_league := DatabaseManager.has_league(_comp)
	var title := w.league_name(_comp) if is_league else ("Sub-20" if _comp == "YOUTH" else CupManager.cup_name(_comp))
	var head := UIKit.hbox(12)
	if _comp != "YOUTH":
		head.add_child(TrophyView.make(("L:" + _comp if is_league else CupManager.title_key(_comp)), 72, w))
	var hcol := UIKit.vbox(0)
	hcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hcol.add_child(UIKit.section(title))
	if _comp != "YOUTH":
		hcol.add_child(UIKit.label(TrophyView.trophy_name(("L:" + _comp if is_league else CupManager.title_key(_comp)), w), "Small", true))
	head.add_child(hcol)
	card.add_child(head)
	var any := false
	for i in range(w.history.size() - 1, -1, -1):
		var h: Dictionary = w.history[i]
		var e: Dictionary = {}
		if _comp == "YOUTH":
			e = h.get("yl", {})
		elif is_league:
			e = h.get("leagues", {}).get(_comp, {})
		else:
			e = h.get("cups", {}).get(_comp, {})
		if e.is_empty() or int(e.get("champion", -1)) < 0:
			continue
		any = true
		var champ := w.club(int(e["champion"]))
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(int(h["y"])), "H3")
		yl.custom_minimum_size.x = 64
		row.add_child(yl)
		row.add_child(UIKit.crest(champ, 40))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIKit.label(champ.name, "H3", true)
		if w.is_user_club(champ.id):
			nl.add_theme_color_override(&"font_color", UIColors.ACCENT)
		col.add_child(nl)
		var sub: Array = []
		if int(e.get("runner_up", -1)) >= 0:
			sub.append("Vice: %s" % w.club(int(e["runner_up"])).short_name)
		var sc: Dictionary = e.get("scorer", {})
		if not sc.is_empty():
			if sc.has("goals"):
				sub.append("Artilheiro: %s (%d)" % [sc.get("name", ""), int(sc.get("goals", 0))])
			elif sc.has("g"):
				sub.append("Artilheiro: %s (%d)" % [sc.get("n", ""), int(sc.get("g", 0))])
		if not sub.is_empty():
			col.add_child(UIKit.label(" · ".join(sub), "Small", true))
		row.add_child(col)
		var cid := champ.id
		card.add_child(UIKit.tap_row(row, func(): UIManager.push("club", {"id": cid}) if not w.is_user_club(cid) else UIManager.push("club")))
	if not any:
		card.add_child(UIKit.label("Nenhuma edição terminou ainda neste save.", "Muted", true))
	c.add_child(UIKit.card_panel(card))


# ---------------------------------------------------------------------------
# Prêmios
# ---------------------------------------------------------------------------

func _awards(w: GameWorld) -> Control:
	var out := UIKit.vbox(12)
	var any := false
	for i in range(w.history.size() - 1, -1, -1):
		var h: Dictionary = w.history[i]
		if h.get("pre", false):
			continue
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.section("Temporada %d" % int(h["y"])))
		var ballon: Dictionary = h.get("ballon", {})
		if not ballon.is_empty():
			any = true
			var row := UIKit.hbox(10)
			row.add_child(UIKit.icon_rect("star", 30, UIColors.ACCENT))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label("Bola de Ouro", "Caps"))
			col.add_child(UIKit.label("%s (%s) · %d gols" % [ballon["name"], ballon["club"], int(ballon.get("goals", 0))], "H3", true))
			row.add_child(col)
			row.add_child(UIKit.flag(String(ballon.get("nat", "")), 36))
			card.add_child(_player_tap(row, int(ballon["id"])))
		for wk in [["wy", "world_young"], ["boot", "boot"]]:
			var wd: Dictionary = h.get(wk[0], {})
			if wd.is_empty():
				continue
			any = true
			var wrow := UIKit.hbox(10)
			var wl := UIKit.label(AwardManager.award_name(wk[1]), "Small")
			wl.custom_minimum_size.x = 170
			wrow.add_child(wl)
			wrow.add_child(UIKit.label("%s (%s)" % [wd["name"], wd["club"]], "", true))
			if wd.has("goals"):
				wrow.add_child(UIKit.label("%d gols" % int(wd["goals"]), "Small"))
			card.add_child(_player_tap(wrow, int(wd["id"])))
		var lid := w.user_league_id()
		var u: Dictionary = h.get("user", {})
		if not u.is_empty():
			lid = String(u.get("league", lid))
		var aw: Dictionary = h.get("leagues", {}).get(lid, {}).get("awards", {})
		if not aw.is_empty():
			any = true
			card.add_child(UIKit.label(w.league_name(lid), "Small"))
			for k in AwardManager.LEAGUE_KEYS:
				if not aw.has(k):
					continue
				var a: Dictionary = aw[k]
				var row := UIKit.hbox(10)
				var kl := UIKit.label(AwardManager.award_name(k), "Small")
				kl.custom_minimum_size.x = 170
				row.add_child(kl)
				var nl := UIKit.label("%s (%s)" % [a["name"], a["club"]], "", true)
				nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(nl)
				row.add_child(UIKit.label(String(a.get("v", "")), "Small"))
				card.add_child(_player_tap(row, int(a["id"])))
		out.add_child(UIKit.card_panel(card))
	if not any:
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.label("Os prêmios são entregues no fim de cada temporada.", "Muted", true))
		return UIKit.card_panel(card)
	return out


func _player_tap(row: Control, pid: int) -> Control:
	return UIKit.tap_row(row, func():
		if world().player(pid) != null:
			UIManager.push("player", {"id": pid})
		else:
			UIManager.toast("Esse jogador já se aposentou."))


# ---------------------------------------------------------------------------
# Clube
# ---------------------------------------------------------------------------

func _club(w: GameWorld, c: VBoxContainer) -> void:
	var club := w.user_club()
	var cab := UIKit.card("Card", 6)
	cab.add_child(UIKit.section("Sala de troféus"))
	cab.add_child(TrophyView.cabinet(w, club))
	c.add_child(UIKit.card_panel(cab))
	# Temporadas
	var seasons := UIKit.card("Card", 4)
	seasons.add_child(UIKit.section("Campanhas do %s" % club.short_name))
	if club.history.is_empty():
		seasons.add_child(UIKit.label("Sem temporadas completas ainda.", "Muted"))
	for i in range(club.history.size() - 1, maxi(-1, club.history.size() - 16), -1):
		var hh: Dictionary = club.history[i]
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(int(hh["y"])), "H3")
		yl.custom_minimum_size.x = 64
		row.add_child(yl)
		var pos := int(hh["p"])
		row.add_child(UIKit.text_badge("%dº" % pos, UIColors.ACCENT if pos == 1 else UIColors.MUTED, 56, 34, 18))
		var l := UIKit.label(w.league_short(String(hh["l"])), "")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		row.add_child(UIKit.label("%d pts · %d-%d-%d" % [int(hh["pts"]), int(hh["w"]), int(hh["dr"]), int(hh["lo"])], "Small"))
		seasons.add_child(row)
	c.add_child(UIKit.card_panel(seasons))
	# Recordes do clube (jogadores atuais e aposentados)
	var totals := {}
	for p: Player in w.players.values():
		for s in p.spells:
			if int(s.get("c", -1)) == club.id:
				var extra := p.stats[Player.S_GOALS] if p.club_id == club.id and int(s.get("to", 0)) == 0 else 0
				var extra_a := p.stats[Player.S_APPS] if p.club_id == club.id and int(s.get("to", 0)) == 0 else 0
				_acc(totals, "p%d" % p.id, p.display_name(), int(s.get("g", 0)) + extra, int(s.get("a", 0)) + extra_a, p.id)
	for r in w.retired:
		for s in r.get("spells", []):
			if int(s.get("c", -1)) == club.id:
				_acc(totals, "r%d" % int(r["id"]), String(r.get("ka", r.get("name", ""))), int(s.get("g", 0)), int(s.get("a", 0)), -1)
	var arr: Array = totals.values()
	for kind in [["g", "Artilheiros históricos", "gols"], ["a", "Mais jogos pelo clube", "jogos"]]:
		var key: String = kind[0]
		arr.sort_custom(func(x: Dictionary, y: Dictionary): return int(x[key]) > int(y[key]))
		var card := UIKit.card("Card", 4)
		card.add_child(UIKit.section(String(kind[1])))
		var shown := 0
		for e: Dictionary in arr:
			if shown >= 10 or int(e[key]) <= 0:
				break
			shown += 1
			var row := UIKit.hbox(10)
			var rk := UIKit.label(str(shown), "H3")
			rk.custom_minimum_size.x = 36
			row.add_child(rk)
			var nl := UIKit.label(String(e["n"]) + ("" if int(e["pid"]) >= 0 else " (aposentado)"), "")
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(nl)
			row.add_child(UIKit.label("%d %s" % [int(e[key]), kind[2]], "Stat"))
			card.add_child(row)
		if shown == 0:
			card.add_child(UIKit.label("Ainda sem registros.", "Muted"))
		c.add_child(UIKit.card_panel(card))


static func _acc(totals: Dictionary, key: String, name: String, g: int, a: int, pid: int) -> void:
	if not totals.has(key):
		totals[key] = {"n": name, "g": 0, "a": 0, "pid": pid}
	totals[key]["g"] = int(totals[key]["g"]) + g
	totals[key]["a"] = int(totals[key]["a"]) + a


# ---------------------------------------------------------------------------
# Lendas
# ---------------------------------------------------------------------------

func _legends(w: GameWorld) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Lendas aposentadas"))
	var arr: Array = w.retired.duplicate()
	arr.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.get("goals", 0)) + int(a.get("titles", 0)) * 10 > int(b.get("goals", 0)) + int(b.get("titles", 0)) * 10)
	if arr.is_empty():
		card.add_child(UIKit.label("Quando grandes jogadores pendurarem as chuteiras, eles aparecem aqui.", "Muted", true))
	for r: Dictionary in arr.slice(0, 40):
		var row := UIKit.hbox(10)
		row.add_child(UIKit.flag(String(r.get("nat", "")), 36))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(r.get("ka", r.get("name", ""))), "H3"))
		var clubs: Array = []
		for s in r.get("spells", []):
			clubs.append(String(s.get("cn", "")))
		col.add_child(UIKit.label("%s · parou em %d · %s" % [Pos.code(int(r.get("pos", 0))), int(r.get("year", 0)), ", ".join(clubs.slice(0, 4))], "Small", true))
		row.add_child(col)
		row.add_child(UIKit.label("%d J · %d G · %d tít." % [int(r.get("apps", 0)), int(r.get("goals", 0)), int(r.get("titles", 0))], "Small"))
		card.add_child(row)
	return UIKit.card_panel(card)
