class_name BroadcastIntro
extends RefCounted
## Abertura da transmissão antes do apito, em etapas como na TV:
##   1. o confronto: emissora, cabine, escudos, tabela, estádio, clima, horário e árbitro;
##   2. a entrada dos times, com o ritual da torcida de cada lugar (WalkoutView);
##   3. e 4. as escalações de cada time no campinho, com técnico e banco (LineupBoard);
##   5. quem merece atenção e o apito.
## "Pular" vai direto ao jogo.

const RITUAL_TEXT := {
	"ucl": "Toca o hino da competição. Noite de gala no estádio.",
	"libertad": "Papel picado e sinalizadores: noite de copa continental.",
	"samba": "Bandeirões, bateria e fogos: a torcida recebe o time.",
	"hinchada": "Papelitos e fumaça: a hinchada canta sem parar.",
	"terrace": "Cachecóis erguidos para receber os times.",
	"ultras": "Mosaico na curva e sinalizadores acesos.",
	"wall": "A muralha amarela canta: o estádio treme.",
}

const WEATHER := {
	"sun": "Sol", "cloud": "Nublado", "rain": "Chuva", "heat": "Calor forte", "wind": "Vento",
	"night": "Noite limpa", "night_rain": "Noite de chuva", "cold": "Frio",
}


static func show(w: GameWorld, sim: MatchSimulation, fx: Fixture, stadium: Dictionary, on_done: Callable, colors: Array = []) -> void:
	var home: Club = sim.teams[0].club
	var away: Club = sim.teams[1].club
	var b := Broadcaster.for_competition(w, fx.comp)
	var th := ScoreboardTheme.for_competition(w, fx.comp)
	if colors.size() < 4:
		colors = [Color(String(home.kit_home.get("c1", home.color1))), Color(String(home.kit_home.get("c2", home.color2))),
			Color(String(away.kit_away.get("c1", away.color1))), Color(String(away.kit_away.get("c2", away.color2)))]
	var frame := UIKit.vbox(10)
	var body := UIKit.vbox(10)
	frame.add_child(body)
	var nav := UIKit.hbox(8)
	frame.add_child(nav)
	var step := [0]
	var pages: Array = []
	var root := UIKit.vbox(10)
	pages.append(root)
	# Faixa da emissora
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = b["c1"]
	hs.set_corner_radius_all(10)
	hs.content_margin_left = 12
	hs.content_margin_right = 12
	hs.content_margin_top = 8
	hs.content_margin_bottom = 8
	head.add_theme_stylebox_override(&"panel", hs)
	var hr := UIKit.hbox(10)
	var lg := BroadcasterLogo.make(b, 40.0)
	lg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(lg)
	var ch := UIKit.label(String(b["name"]).to_upper(), "H3")
	ch.add_theme_color_override(&"font_color", b["c2"])
	ch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(ch)
	var live := UIKit.label("● AO VIVO", "Caps")
	live.add_theme_color_override(&"font_color", Color("#FF4B4B"))
	hr.add_child(live)
	head.add_child(hr)
	root.add_child(head)
	# Competição
	var cr := UIKit.hbox(8)
	cr.add_child(UIKit.comp_logo(fx.comp, 40))
	var ct := UIKit.label(CompText.fixture_title(w, fx) if fx.comp != "F" else "Amistoso", "Small", true)
	ct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cr.add_child(ct)
	root.add_child(cr)
	# Confronto
	var vs := UIKit.hbox(8)
	vs.add_child(_side(home, _table_text(w, fx, home)))
	var x := UIKit.label("×", "Score")
	x.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vs.add_child(x)
	vs.add_child(_side(away, _table_text(w, fx, away)))
	root.add_child(vs)
	if sim.derby:
		var d := UIKit.pill("CLÁSSICO", UIColors.RED, 18)
		d.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		root.add_child(d)
	# Estádio, público, clima, árbitro, cabine
	var info := UIKit.vbox(2)
	var place := home.stadium if not sim.neutral else "Campo neutro"
	info.add_child(UIKit.kv("Estádio", place))
	info.add_child(UIKit.kv("Público", "%s torcedores" % Fmt.thousands(sim.attendance)))
	var wx := sim.wx
	if not wx.is_empty():
		info.add_child(UIKit.kv("Clima", "%s · %d°C · %dh" % [Weather.NAMES.get(String(wx.get("kind", "")), ""), int(wx.get("temp", 20)), int(wx.get("hour", 16))]))
		if wx.has("alt"):
			info.add_child(UIKit.kv("Altitude", "%s m" % Fmt.thousands(int(wx["alt"]))))
	else:
		info.add_child(UIKit.kv("Clima", String(WEATHER.get(String(stadium.get("weather", "")), "—"))))
	var rs := Referees.summary(w, sim.ref)
	if rs != "":
		info.add_child(UIKit.kv("Árbitro", rs.get_slice(" · ", 0)))
	var booth := _booth(w, fx, b)
	info.add_child(UIKit.kv("Narração", booth[0]))
	info.add_child(UIKit.kv("Comentários", booth[1]))
	root.add_child(info)
	# Estúdio: prévia dos comentaristas nos jogos grandes
	if Pundits.is_big(sim):
		var nat := w.league(fx.comp).nation if w.league(fx.comp) != null else home.nation
		var studio := UIKit.vbox(10)
		studio.add_child(UIKit.label("No estúdio", "Title", true))
		studio.add_child(Pundits.card("Prévia", Pundits.preview(w, sim, nat)))
		pages.append(studio)
	# 2. Entrada dos times
	var rit := WalkoutView.ritual_for(w, fx.comp, home)
	var walk := UIKit.vbox(8)
	walk.add_child(UIKit.label("Os times entram em campo", "Title", true))
	walk.add_child(WalkoutView.make(colors[0], colors[1], colors[2], colors[3], rit, bool(stadium.get("night", false)), String(RITUAL_TEXT.get(rit, "")), hash([fx.home, fx.away])))
	pages.append(walk)
	# 3 e 4. Escalações no campinho
	for t: MatchTeam in sim.teams:
		var lb := LineupBoard.make(t, th["accent"], th["bg"], colors[0 if t.side == 0 else 2], colors[1 if t.side == 0 else 3], People.coach_name(w, t.club.id))
		pages.append(lb)
	# 5. Fique de olho
	var last := UIKit.vbox(12)
	last.add_child(UIKit.label("Fique de olho", "Title", true))
	for t: MatchTeam in sim.teams:
		var star := _star(t)
		if star != null:
			var row := UIKit.hbox(12)
			row.add_child(UIKit.portrait(star, t.club, w.year, 96))
			var col := UIKit.vbox(0)
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_child(UIKit.label(t.club.short_name.to_upper(), "Caps"))
			col.add_child(UIKit.label(star.display_name(), "H2"))
			var sg: int = star.stats[Player.S_GOALS] if star.stats.size() > Player.S_GOALS else 0
			var sa: int = star.stats[Player.S_ASSISTS] if star.stats.size() > Player.S_ASSISTS else 0
			col.add_child(UIKit.label("%s · %d gols · %d assistências na temporada" % [Pos.code(star.position), sg, sa], "Small", true))
			row.add_child(col)
			last.add_child(UIKit.card_panel(_wrap(row)))
	pages.append(last)
	var next_btn := UIKit.button("Próximo", "PrimaryButton", Callable(), "forward")
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.custom_minimum_size.y = 84
	var skip_btn := UIKit.button("Pular", "GhostButton", func():
		UIManager.close_modal()
		on_done.call(), "skip")
	skip_btn.custom_minimum_size = Vector2(180, 84)
	next_btn.pressed.connect(func():
		step[0] += 1
		if step[0] >= pages.size():
			UIManager.close_modal()
			on_done.call()
			return
		if step[0] == pages.size() - 1:
			next_btn.text = "Apito inicial"
		# Mantém as páginas vivas fora da árvore enquanto não aparecem
		for pg: Control in pages:
			if pg.get_parent() == body:
				body.remove_child(pg)
		body.add_child(pages[step[0]])
		if pages[step[0]] is VBoxContainer and pages[step[0]].get_child_count() > 1 and pages[step[0]].get_child(1) is WalkoutView:
			Sfx.crowd_clip(0, "entrada"))
	nav.add_child(skip_btn)
	nav.add_child(next_btn)
	body.add_child(pages[0])
	frame.tree_exited.connect(func():
		for pg: Control in pages:
			if is_instance_valid(pg) and pg.get_parent() == null:
				pg.queue_free())
	UIManager.show_modal(frame, true, false)


static func _wrap(c: Control) -> VBoxContainer:
	var v := UIKit.card("Card", 6)
	v.add_child(c)
	return v


static func _side(c: Club, sub: String) -> Control:
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cr := UIKit.crest(c, 92)
	cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cr)
	var n := UIKit.label(c.short_name, "H3")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	v.add_child(n)
	if sub != "":
		var s := UIKit.label(sub, "Small")
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	return v


## "3º · 24 pts" quando é jogo de liga.
static func _table_text(w: GameWorld, fx: Fixture, c: Club) -> String:
	if not fx.is_league():
		return ""
	var league := w.league(fx.comp)
	if league == null or not league.table.has(c.id) or int(league.table[c.id]["pl"]) == 0:
		return ""
	var pos := CompetitionManager.position_of(league, c.id)
	var pts := int(league.table[c.id]["pts"])
	return ("%dº · %d pts" % [pos, pts]) if pos > 0 else ("%d pts" % pts)


## Narrador e comentarista: nomes do país da competição, fixos por emissora.
static func _booth(w: GameWorld, fx: Fixture, b: Dictionary) -> Array:
	var nation := ""
	var league := w.league(fx.comp)
	if league != null:
		nation = league.nation
	else:
		nation = String(DatabaseManager.cup_cfg(fx.comp).get("nation", ""))
	if nation == "":
		var home := w.club(fx.home)
		nation = home.nation if home != null else "BRA"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(b["name"]) + str(w.world_seed))
	var out: Array = []
	for i in 2:
		var o := NameGenerator.pick_origin(rng, nation)
		var n := NameGenerator.generate(rng, String(o["c"]), {}, {})
		out.append("%s %s" % [n["first"], n["last"]])
	return out


static func _lineup(t: MatchTeam) -> Control:
	var v := UIKit.vbox(1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(UIKit.label("%s · %s" % [t.club.abbr, t.formation_name], "Caps"))
	var xi: Array = []
	for mp in t.slots:
		if mp != null:
			xi.append(mp)
	xi.sort_custom(func(a: MatchPlayer, c: MatchPlayer): return a.pos < c.pos)
	for mp: MatchPlayer in xi:
		var l := UIKit.label("%2d  %s" % [mp.p.shirt, mp.p.short_name()], "Small")
		l.clip_text = true
		v.add_child(l)
	return v


## Quem merece atenção: o craque de frente (atacantes e meias pesam mais), com peso para quem
## está fazendo gols; goleiro só se não houver mais ninguém.
static func _star(t: MatchTeam) -> Player:
	var best: Player = null
	var best_v := -1.0
	for mp in t.slots:
		if mp == null:
			continue
		var g: int = mp.p.stats[Player.S_GOALS] if mp.p.stats.size() > Player.S_GOALS else 0
		var a: int = mp.p.stats[Player.S_ASSISTS] if mp.p.stats.size() > Player.S_ASSISTS else 0
		var v: float = float(mp.p.overall) + [-12.0, -3.0, 1.0, 3.0][Pos.group(mp.p.position)] + g * 1.5 + a * 0.8
		if v > best_v:
			best_v = v
			best = mp.p
	return best
