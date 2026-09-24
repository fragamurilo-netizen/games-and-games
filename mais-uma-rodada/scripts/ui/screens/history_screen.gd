extends BaseScreen
## Memória do save: a carreira do treinador, campeões de cada competição ano a ano,
## prêmios individuais, recordes do clube e as lendas aposentadas.

const TABS := [["career", "Carreira"], ["champions", "Campeões"], ["awards", "Prêmios"], ["club", "Clube"], ["legends", "Lendas"]]

var _tab := "career"
var _comp := ""


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
	screen_subtitle = "%d temporada(s) no save" % w.history.size()
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
	card.add_child(UIKit.label(w.manager_name, "Title"))
	card.add_child(UIKit.label("Treinador · %s" % GameWorld.DIFF_NAMES[w.difficulty], "Small"))
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
		if String(cfg.get("confed", "")) == confed or String(cfg.get("confed", "")) == "" or cid == "CWC":
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
	card.add_child(UIKit.section(title))
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
		var card := UIKit.card("Card", 6)
		card.add_child(UIKit.section("Temporada %d" % int(h["y"])))
		var ballon: Dictionary = h.get("ballon", {})
		if not ballon.is_empty():
			any = true
			var row := UIKit.hbox(10)
			row.add_child(UIKit.icon_rect("star", 30, UIColors.ACCENT))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label("Melhor do mundo", "Caps"))
			col.add_child(UIKit.label("%s (%s) · %d gols" % [ballon["name"], ballon["club"], int(ballon.get("goals", 0))], "H3", true))
			row.add_child(col)
			row.add_child(UIKit.flag(String(ballon.get("nat", "")), 36))
			card.add_child(_player_tap(row, int(ballon["id"])))
		var lid := w.user_league_id()
		var u: Dictionary = h.get("user", {})
		if not u.is_empty():
			lid = String(u.get("league", lid))
		var aw: Dictionary = h.get("leagues", {}).get(lid, {}).get("awards", {})
		if not aw.is_empty():
			any = true
			card.add_child(UIKit.label(w.league_name(lid), "Small"))
			for k in ["mvp", "young", "gk", "assist"]:
				if not aw.has(k):
					continue
				var a: Dictionary = aw[k]
				var row := UIKit.hbox(10)
				var kl := UIKit.label(AwardManager.award_name(k), "Small")
				kl.custom_minimum_size.x = 170
				row.add_child(kl)
				var nl := UIKit.label("%s (%s)" % [a["name"], a["club"]], "", true)
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
