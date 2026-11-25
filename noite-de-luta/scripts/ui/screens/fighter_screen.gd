extends BaseScreen
## Perfil do lutador: retrato sob a luz do octógono, ficha (atributos em três blocos e físico),
## carreira e, se for da equipe, treino e contrato. Daqui sai o desafio e a contratação.

var _tab := "ficha"
var _f: Fighter
## A lista do que pesa na moral está aberta.
var _moral_open := false


func setup(p: Dictionary) -> void:
	super.setup(p)
	_tab = String(p.get("tab", "ficha"))


func refresh() -> void:
	var w := world()
	_f = w.fighter(int(params["id"]))
	var f := _f
	screen_title = f.display_name()
	screen_subtitle = Matchmaker.division_short(f.division) + " · " + w.rank_text(f)
	UIManager.refresh_chrome()
	var c := reset()
	c.add_child(_header(w, f))
	var tabs := [["ficha", "Ficha"], ["carreira", "Carreira"]]
	var mine := w.is_user_fighter(f)
	if mine:
		tabs.append(["treino", "Treino"])
		tabs.append(["contrato", "Contrato"])
	c.add_child(UIKit.tabs(tabs, _tab, func(k: String):
		_tab = k
		refresh()))
	match _tab:
		"ficha":
			_ficha(w, f, c)
		"carreira":
			_carreira(w, f, c)
		"treino":
			_treino(w, f, c)
		"contrato":
			_contrato(w, f, c)
	_actions(w, f)
	TutorialKit.tip(self, "fighter")


func _header(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S2)
	var h := UIKit.hbox(UITokens.S3)
	h.add_child(FightKit.portrait(w, f, 150))
	var v := UIKit.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if f.nickname != "":
		v.add_child(UIKit.label("“%s”" % f.nickname, "Accent"))
	var nm := UIKit.label(f.display_name(), "Section", true)
	v.add_child(nm)
	var nat := UIKit.hbox(8)
	nat.add_child(UIKit.flag(f.nation, 34))
	nat.add_child(UIKit.label("%s · %d anos" % [DataDB.nation_name(f.nation), w.age_of(f)], "Small"))
	v.add_child(nat)
	v.add_child(UIKit.label(FightKit.record_detail(f), "H3"))
	var t := w.team(f.team_id)
	v.add_child(UIKit.label(t.name if t != null else "Sem equipe", "Small"))
	var rk := UIKit.hbox(12)
	var r := UIKit.label(w.rank_text(f) + " · " + Matchmaker.division_short(f.division), "Caps")
	if w.rank_of(f) == 0:
		r.add_theme_color_override(&"font_color", UIColors.GOLD)
	rk.add_child(r)
	rk.add_child(UIKit.spacer())
	rk.add_child(UIKit.label("Nível", "Caps"))
	rk.add_child(FightKit.level_label(f.level(), "Stat"))
	v.add_child(rk)
	h.add_child(v)
	card.add_child(h)
	var st := FightKit.status_text(w, f)
	var srow := UIKit.hbox(8)
	var sl := UIKit.colored(String(st[0]), st[1], "Small", true)
	srow.add_child(sl)
	var following := w.is_followed(f)
	var fb := UIKit.button("Seguindo" if following else "Seguir", "TextButton", func():
		w.toggle_follow(f)
		GameManager.save_now()
		UIManager.toast(("Você acompanha %s: a próxima luta e o último resultado aparecem no Início." % f.short_name()) if w.is_followed(f) else "Você deixou de acompanhar %s." % f.short_name())
		refresh(), "star")
	if following:
		fb.add_theme_color_override(&"font_color", UIColors.GOLD)
		fb.add_theme_color_override(&"icon_normal_color", UIColors.GOLD)
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(fb)
	var lb := UIKit.button("Visual", "TextButton", func(): UIManager.push("look", {"id": f.id}), "palette")
	lb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	srow.add_child(lb)
	card.add_child(srow)
	return UIKit.card_panel(card)


func _ficha(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var body := UIKit.card("Card", UITokens.S1)
	body.add_child(UIKit.label("Físico", "Section"))
	var fig := UIKit.hbox(UITokens.S2)
	fig.add_child(FightKit.body(w, f, 300))
	var ft := UIKit.label(FightKit.physique_text(f), "Small", true)
	ft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ft.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fig.add_child(ft)
	body.add_child(fig)
	body.add_child(UIKit.button("Editar visual", "GhostButton", func(): UIManager.push("look", {"id": f.id, "tab": "corpo"}), "palette"))
	body.add_child(UIKit.kv("Estilo", f.style_label()))
	body.add_child(UIKit.kv("Arte de base", Styles.describe(f)))
	body.add_child(UIKit.kv("Altura · envergadura", "%s · %d cm" % [Fmt.height(f.height_cm), f.reach_cm]))
	body.add_child(UIKit.kv("Base", "Canhota" if f.southpaw else "Ortodoxa"))
	var limit := float(DataDB.division(f.division).get("limit_kg", 70.0))
	var cut := maxf(0.0, (f.natural_kg - limit) / f.natural_kg)
	body.add_child(UIKit.kv("Peso fora de luta", "%s (corte de %d%%)" % [Fmt.kg(f.natural_kg), int(round(cut * 100.0))], UIColors.ORANGE if cut > 0.11 else UIColors.TEXT))
	body.add_child(UIKit.kv("Condição física", "%d%%" % int(f.condition), UIColors.GREEN if f.condition >= 90.0 else (UIColors.ORANGE if f.condition >= 70.0 else UIColors.RED)))
	# Primeiro o que decide uma contratação ou uma luta: os atributos, o teto e o humor. O físico,
	# o estilo e a personalidade vêm depois.
	var cards: Array = [FightKit.attr_card(f)]
	if not f.retired:
		cards.append(_potential_card(w, f))
		cards.append(_moral_card(w, f))
		var rv := _rivals_card(w, f)
		if rv != null:
			cards.append(rv)
	cards.append(UIKit.card_panel(body))
	cards.append(_style_card(f))
	cards.append(_persona_card(f))
	for x: Control in cards:
		c.add_child(x)
	columnize(c, 2, 2)


## Rivais (quem tem história com ele e por quê) e, para quem está perto do cinturão, o que a
## liga sinalizou: a vez na fila, o interino, a unificação.
func _rivals_card(w: GameWorld, f: Fighter) -> Control:
	var rivals := Rivalry.of(w, f)
	var notes: Array = []
	if w.is_interim(f):
		notes.append("%s interin%s: a próxima luta é a unificação contra o campeão." % ["Campeã" if f.is_female() else "Campeão", "a" if f.is_female() else "o"])
	elif w.rank_of(f) == 0:
		var out := Titles.champion_out(w, f.division)
		var it := Titles.interim_of(w, f.division)
		if it != null:
			notes.append("Há campeão interino na categoria (%s): a próxima defesa é a unificação." % it.display_name())
		elif out != "":
			notes.append("Fora de combate: a liga pode criar um cinturão interino.")
	elif Matchmaker.shot_promised(w, f):
		var champ := w.fighter(int(w.champions.get(f.division, -1)))
		notes.append("A liga sinalizou a próxima disputa de cinturão para %s, contra %s. Vale esperar a proposta em vez de aceitar outra luta." % [f.short_name(), champ.display_name() if champ != null else "o campeão"])
	if rivals.is_empty() and notes.is_empty():
		return null
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Rivais e cinturão" if not notes.is_empty() else "Rivais", "Section"))
	for n: String in notes:
		card.add_child(UIKit.colored(n, UIColors.GOLD, "Small", true))
	for it2: Array in rivals.slice(0, 3):
		var o: Fighter = it2[0]
		var e: Dictionary = it2[1]
		var heat := float(e.get("heat", 0.0))
		var oid := o.id
		var h2h := Rivalry.h2h_text(f, o.id)
		var line := "%s · %s" % [Rivalry.label(heat), String(e.get("why", "eles têm história"))]
		card.add_child(FightKit.fighter_row(w, o, func(): UIManager.push("fighter", {"id": oid}), line, UIColors.ORANGE if heat >= Rivalry.NAMED else Color(0, 0, 0, 0), h2h))
	if not rivals.is_empty():
		card.add_child(UIKit.label("Luta contra rival vende mais, a equipe dele aceita mais fácil e ganhar (ou perder) mexe mais com a moral.", "Small", true))
	return UIKit.card_panel(card)


## Moral: o humor de hoje, o que pesa, o que mexeu nas últimas semanas e, na equipe do jogador,
## a conversa.
func _moral_card(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var mine := w.is_user_fighter(f)
	var col: Color = [UIColors.RED, UIColors.ORANGE, UIColors.MUTED, UIColors.GREEN, UIColors.GREEN][Morale.tone(f) + 2]
	var head := UIKit.hbox(8)
	var t := UIKit.label("Moral", "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.pill(Morale.label(f), col, 20))
	card.add_child(head)
	card.add_child(UIKit.bar(f.morale, 100.0, col, 10))
	var tr := Morale.trend(w, f)
	card.add_child(UIKit.label(Morale.effect_text(f) + (" Está subindo." if tr > 0 else (" Está caindo." if tr < 0 else "")), "Small", true))
	if mine:
		if not f.promise.is_empty():
			card.add_child(UIKit.label("Promessa em aberto: luta marcada em até %s." % Fmt.plural(maxi(0, int(f.promise.get("until", w.week)) - w.week), "semana", "semanas"), "Small", true))
		if w.week < f.push_until:
			card.add_child(UIKit.label("Cobrança em curso: treina mais forte por %s." % Fmt.plural(f.push_until - w.week, "semana", "semanas"), "Small", true))
	# O porquê fica a um toque: a lista inteira aberta empurrava o resto da ficha para baixo.
	var fs := Morale.factors(w, f)
	var has_detail := not fs.is_empty() or not f.mood_log.is_empty()
	var foot := UIKit.hbox(8)
	if has_detail:
		var more := UIKit.button("Fechar" if _moral_open else "O que pesa", "TextButton", func():
			_moral_open = not _moral_open
			refresh())
		more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		foot.add_child(more)
	foot.add_child(UIKit.spacer())
	if mine:
		var wait := Morale.talk_wait(w, f)
		if wait > 0:
			var wl := UIKit.label("Nova conversa em %s" % Fmt.plural(wait, "semana", "semanas"), "Muted")
			wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			foot.add_child(wl)
		else:
			var talk := UIKit.button("Conversar", "GhostButton", func(): TalkSheet.open(w, f, func(): refresh()), "chat")
			talk.size_flags_horizontal = Control.SIZE_SHRINK_END
			foot.add_child(talk)
	if foot.get_child_count() > 1:
		card.add_child(foot)
	else:
		foot.free()
	if _moral_open and has_detail:
		if not fs.is_empty():
			card.add_child(UIKit.label("O que pesa", "Caps"))
			for it: Array in fs:
				var v := int(round(float(it[1])))
				if v != 0:
					card.add_child(UIKit.kv(String(it[0]), Fmt.signed(v), UIColors.GREEN if v > 0 else UIColors.RED))
		if not f.mood_log.is_empty():
			card.add_child(UIKit.label("Últimas semanas", "Caps"))
			for i in range(f.mood_log.size() - 1, maxi(-1, f.mood_log.size() - 4), -1):
				var e: Array = f.mood_log[i]
				card.add_child(UIKit.kv("%s, %s" % [String(e[2]), w.weeks_from_now(int(e[0]))], Fmt.signed(int(e[1])), UIColors.GREEN if int(e[1]) > 0 else UIColors.RED))
	return UIKit.card_panel(card)


## Potencial: a faixa de estrelas que a equipe enxerga, o relatório em frases e o olheiro.
func _potential_card(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	var mine := w.is_user_fighter(f)
	var est := Scouting.estimate(w, f)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Potencial", "Section")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	if not bool(est.get("none", false)):
		var stv := StarsView.new()
		stv.star_size = 22
		stv.stars = StarsView.from_value(float(est["lo"]))
		var up := StarsView.from_value(float(est["hi"]))
		stv.upper_stars = up if up > stv.stars else -1.0
		stv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(stv)
	card.add_child(head)
	if bool(est.get("none", false)):
		card.add_child(UIKit.label("Sem olheiro, o teto de quem não treina com você é um mistério.", "Small", true))
		if not w.is_president():
			card.add_child(UIKit.button("Contratar um olheiro", "GhostButton", func(): UIManager.switch_area("market"), "search"))
		return UIKit.card_panel(card)
	var k := float(est["known"])
	var kr := UIKit.hbox(8)
	var kl := UIKit.label("O quanto %s conhece" % ("a casa" if mine else "o olheiro"), "Muted")
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kr.add_child(kl)
	kr.add_child(UIKit.label(Fmt.percent(k)))
	card.add_child(kr)
	card.add_child(UIKit.bar(k * 100.0, 100.0, UIColors.GOLD, 6))
	for line: String in Scouting.report_lines(w, f):
		card.add_child(UIKit.label(line, "Small", true))
	if float(est["hi"]) - float(est["lo"]) >= 4.0:
		card.add_child(UIKit.label("As estrelas apagadas são a dúvida: a faixa fecha quando se conhece mais.", "Muted", true))
	if mine:
		return UIKit.card_panel(card)
	var job := Scouting.job_of(w, f)
	if not job.is_empty():
		card.add_child(UIKit.colored("Olheiro observando: relatório em %s." % Fmt.plural(int(job["left"]), "semana", "semanas"), UIColors.GOLD, "Small", true))
		card.add_child(UIKit.bar(float(int(job["total"]) - int(job["left"])), float(job["total"]), UIColors.GOLD, 6))
		return UIKit.card_panel(card)
	var why := Scouting.block_reason(w, f)
	if why == "":
		card.add_child(UIKit.label("A viagem do olheiro custa %s e o relatório chega em %s." % [Fmt.money(Scouting.cost_for(w, f)), Fmt.plural(Scouting.weeks_for(w, f), "semana", "semanas")], "Muted", true))
		card.add_child(UIKit.button("Mandar observar", "GhostButton", func():
			var err := Scouting.assign(w, f)
			if err != "":
				UIManager.toast(err, UIColors.RED)
			else:
				UIManager.toast("O olheiro viaja para ver %s. O relatório chega em %s." % [f.short_name(), Fmt.plural(Scouting.weeks_for(w, f), "semana", "semanas")], UIColors.GREEN)
				GameManager.save_now()
			UIManager.refresh_chrome()
			refresh(), "search"))
	elif not f.retired:
		card.add_child(UIKit.label(why, "Muted", true))
	return UIKit.card_panel(card)


## Personalidade: os dois traços e o que cada um faz no jogo.
func _persona_card(f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Personalidade", "Section"))
	for t: String in f.traits:
		card.add_child(UIKit.label(Persona.name_of(t), "H3"))
		card.add_child(UIKit.label(Persona.desc_of(t), "Small", true))
	if f.traits.is_empty():
		card.add_child(UIKit.label("Ainda não deu para conhecer.", "Muted"))
	return UIKit.card_panel(card)


## Estilo de luta: de onde ele vem, as marcas da escola e as armas que mais usa.
func _style_card(f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Estilo de luta", "Section"))
	card.add_child(UIKit.label(String(Styles.base(f.base).get("desc", "")), "Small", true))
	if f.base2 != "" and f.base2 != f.base:
		card.add_child(UIKit.label("Completou o jogo com %s." % Styles.name(f.base2).to_lower(), "Small", true))
	for t: Array in Styles.trait_list(f):
		card.add_child(UIKit.kv(String(t[0]), String(t[1])))
	var p := Styles.profile(f)
	var fav := func(d: Dictionary, n: int, info: Callable) -> String:
		var ks := d.keys()
		ks.sort_custom(func(a: String, b: String) -> bool: return float(d[a]) > float(d[b]))
		var names: Array = []
		for k: String in ks.slice(0, n):
			names.append(String(info.call(k).get("name", k)))
		return ", ".join(names)
	card.add_child(UIKit.kv("Quedas", fav.call(p["td"], 2, Styles.takedown)))
	card.add_child(UIKit.kv("Finalizações", fav.call(p["subs"], 3, Styles.sub)))
	return UIKit.card_panel(card)


func _carreira(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var r := f.record
	var sum := UIKit.card("Card", UITokens.S1)
	sum.add_child(UIKit.label("Cartel profissional", "Section"))
	var g := UIKit.hbox(0)
	g.add_child(UIKit.stat_tile(str(int(r["w"])), "Vitórias", UIColors.GREEN))
	g.add_child(UIKit.stat_tile(str(int(r["l"])), "Derrotas", UIColors.RED))
	g.add_child(UIKit.stat_tile(str(int(r["d"])), "Empates"))
	sum.add_child(g)
	sum.add_child(UIKit.kv("Vitórias por nocaute", str(int(r["ko_w"]))))
	sum.add_child(UIKit.kv("Vitórias por finalização", str(int(r["sub_w"]))))
	sum.add_child(UIKit.kv("Vitórias por decisão", str(int(r["dec_w"]))))
	sum.add_child(UIKit.kv("Cartel amador", "%d-%d" % [int(f.amateur.get("w", 0)), int(f.amateur.get("l", 0))]))
	if f.titles_won > 0:
		sum.add_child(UIKit.kv("Cinturões", "%d (%d defesas)" % [f.titles_won, f.title_defenses], UIColors.GOLD))
	for hn: String in Legacy.honors(w, f):
		var hl := UIKit.colored(hn, UIColors.GOLD, "Small", true)
		sum.add_child(UIKit.tap_row(hl, func(): UIManager.push("legacy", {"tab": "hall" if hn.begins_with("Hall") else "premios"})))
	c.add_child(UIKit.card_panel(sum))
	c.add_child(_evolution_card(w, f))
	if f.is_pro():
		c.add_child(_numbers_card(w, f))
		c.add_child(_marks_card(w, f))
	c.add_child(_fights_block(w, f))


var _all_fights := false


## As lutas dele, da mais nova para a mais antiga: as do jogo e, depois, as de antes (PastFights).
func _fights_block(w: GameWorld, f: Fighter) -> Control:
	var box := UIKit.vbox(0)
	var past := PastFights.of(w, f)
	var all: Array = []
	for i in range(f.history.size() - 1, -1, -1):
		all.append(f.history[i])
	for i in range(past.size() - 1, -1, -1):
		all.append(past[i])
	box.add_child(UIKit.section_header("Lutas (%d)" % all.size() if not all.is_empty() else "Lutas"))
	if all.is_empty():
		box.add_child(UIKit.label("Ainda não lutou como profissional.", "Muted", true))
		return box
	var shown := all.size() if _all_fights else mini(all.size(), 8)
	for i in shown:
		box.add_child(_fight_row(w, all[i]))
	if all.size() > shown:
		box.add_child(UIKit.button("Ver as %d lutas" % all.size(), "TextButton", func():
			_all_fights = true
			refresh()))
	return box


func _fight_row(w: GameWorld, hst: Dictionary) -> Control:
	var h := UIKit.hbox(UITokens.S2)
	var res := String(hst["res"])
	var rl := UIKit.label(res, "Section")
	rl.custom_minimum_size.x = 40
	rl.add_theme_color_override(&"font_color", UIColors.ink(UIColors.result_color(res)))
	h.add_child(rl)
	var v := UIKit.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var who := "contra " + String(hst["opp_name"])
	if hst.has("opp_rec"):
		who += " (%s)" % String(hst["opp_rec"])
	var t := UIKit.label(("Cinturão · " if bool(hst.get("title", false)) else "") + who, "H3")
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	var how := String(hst.get("detail", ""))
	if not String(hst["method"]) in ["DEC", "EMP"]:
		how += ", %dº round" % int(hst.get("round", 1))
	# Quebra em duas linhas quando não cabe: aqui o detalhe vale mais do que a altura da linha.
	var sub := UIKit.label("%s · %s · %s" % [how, String(hst.get("event", "")), GameWorld.fight_date_text(int(hst["week"]), true).trim_prefix("sáb, ")], "Small", true)
	v.add_child(sub)
	# Os números dele naquela luta.
	var nums := CareerStats.bout_line(hst)
	if nums != "":
		v.add_child(UIKit.label(nums, "Caps", true))
	h.add_child(v)
	var oid := int(hst["opp"])
	if oid < 0 or w.fighter(oid) == null:
		var pc := PanelContainer.new()
		pc.theme_type_variation = "RowPanel"
		pc.add_child(h)
		return pc
	return UIKit.tap_row(h, func(): UIManager.push("fighter", {"id": oid}))


## Evolução: o nível pela idade, com as lutas do jogo, o auge e o teto que o olheiro enxerga, e
## o que subiu e caiu nos últimos meses.
func _evolution_card(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Evolução", "Section"))
	card.add_child(UIKit.label("Nível geral pela idade.", "Small"))
	var pts := CareerStats.curve_points(w, f)
	var est := Scouting.estimate(w, f)
	var pk := Scouting.peak_guess(w, f)
	var age := w.age_of(f)
	var band := Vector2(-1.0, -1.0)
	if not f.retired and not bool(est.get("none", false)) and age <= (pk if pk > 0 else 29):
		band = Vector2(float(est["lo"]), float(est["hi"]))
	var chart := EvolutionChart.new()
	chart.setup(pts, CareerStats.fight_points(w, f), band, float(pk) if pk > 0 else 0.0)
	card.add_child(chart)
	if not f.history.is_empty():
		card.add_child(EvolutionChart.legend())
	# O melhor momento e o de hoje.
	var best := 0.0
	var best_age := 0.0
	for p: Array in pts:
		if float(p[1]) > best:
			best = float(p[1])
			best_age = float(p[0])
	if best > float(f.level()) + 0.5:
		card.add_child(UIKit.kv("Melhor fase", "nível %d, aos %d anos" % [int(best), int(best_age)]))
	if not pts.is_empty() and int((pts[0] as Array)[2]) < 0:
		card.add_child(UIKit.label("A parte apagada da linha é de antes do jogo, estimada pela idade.", "Muted", true))
	var tr := CareerStats.trend(f)
	if not tr.is_empty():
		var months := maxi(1, int(round(float(CareerStats.trend_weeks(w, f)) / 4.35)))
		card.add_child(UIKit.label("Nos últimos %s" % Fmt.plural(months, "mês", "meses"), "Caps"))
		var keys := tr.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(tr[a]) > int(tr[b]))
		# Os que mais subiram e os que mais caíram (a lista inteira vira parede de texto).
		var ups: Array = keys.filter(func(k: String) -> bool: return int(tr[k]) > 0).slice(0, 5)
		var downs: Array = keys.filter(func(k: String) -> bool: return int(tr[k]) < 0)
		downs = downs.slice(maxi(0, downs.size() - 4))
		var fl := UIKit.flow(8)
		for k: String in ups + downs:
			var d := int(tr[k])
			fl.add_child(UIKit.pill("%s %s" % [String(Fighter.ATTR_NAMES.get(k, k)), Fmt.signed(d)], UIColors.GREEN if d > 0 else UIColors.RED, 19))
		card.add_child(fl)
		var rest := keys.size() - ups.size() - downs.size()
		if rest > 0:
			card.add_child(UIKit.label("e mais %s com mudança menor." % Fmt.plural(rest, "atributo", "atributos"), "Muted"))
	elif w.is_user_fighter(f) or w.is_followed(f):
		card.add_child(UIKit.label("O que subiu e caiu aparece aqui a cada três meses.", "Muted", true))
	else:
		card.add_child(UIKit.label("Toque em Seguir para acompanhar o que sobe e cai nos atributos.", "Muted", true))
	return UIKit.card_panel(card)


## Números da carreira, no padrão das estatísticas do MMA, ao lado da média da categoria.
func _numbers_card(w: GameWorld, f: Fighter) -> Control:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Números da carreira", "Section"))
	var r := CareerStats.rates(f)
	if int(r["n"]) <= 0:
		card.add_child(UIKit.label("Sem lutas contadas ainda.", "Muted", true))
		return UIKit.card_panel(card)
	var d := CareerStats.division_rates(w, f.division)
	card.add_child(UIKit.label("Em %s. Ao lado, a média dos %s." % [Fmt.plural(int(r["n"]), "luta", "lutas"), Matchmaker.division_name(f.division, true)], "Small", true))
	# [chave, rótulo, formato, sentido] (sentido: 1 = mais é melhor, -1 = menos é melhor, 0 = neutro)
	var rows := [
		["slpm", "Golpes certos por minuto", "dec", 1], ["acc", "Precisão dos golpes", "pct", 1],
		["sapm", "Golpes sofridos por minuto", "dec", -1], ["def", "Defesa de golpes", "pct", 1],
		["td15", "Quedas a cada 15 min", "dec", 1], ["tdacc", "Precisão de quedas", "pct", 1],
		["tddef", "Defesa de quedas", "pct", 1], ["sub15", "Finalizações tentadas/15 min", "dec", 1],
		["kd", "Knockdowns por luta", "dec", 1], ["ctrl15", "Controle a cada 15 min", "time", 1],
		["avg_t", "Tempo médio de luta", "time", 0],
	]
	var fmt := func(v: float, kind: String) -> String:
		if kind == "pct":
			return Fmt.percent(v)
		if kind == "time":
			return Fmt.elapsed(v)
		return Fmt.dec(v, 2)
	for it: Array in rows:
		var k := String(it[0])
		var mine := float(r[k])
		var avg := float(d.get(k, mine))
		var col := UIColors.TEXT
		var rel := (mine - avg) / maxf(0.05, absf(avg))
		if int(it[3]) != 0 and absf(rel) >= 0.1:
			col = UIColors.GREEN if rel * int(it[3]) > 0.0 else UIColors.RED
		card.add_child(UIKit.kv(String(it[1]), "%s · média %s" % [fmt.call(mine, String(it[2])), fmt.call(avg, String(it[2]))], col))
	return UIKit.card_panel(card)


## Marcos: os que chegaram no jogo (com data), o que ele já trazia e os próximos ao alcance.
func _marks_card(w: GameWorld, f: Fighter) -> Control:
	CareerStats.ensure_marks(w, f)
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Marcos da carreira", "Section"))
	var dated: Array = f.marks.filter(func(m: Array) -> bool: return int(m[1]) >= 0)
	dated.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	for m: Array in dated.slice(0, 8):
		var row := UIKit.hbox(8)
		row.custom_minimum_size.y = 44
		row.add_child(UIKit.icon_rect("medal", 22, UIColors.GOLD))
		var nm := UIKit.label(CareerStats.mark_name(String(m[0])), "", true)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var d := GameWorld.date_of(int(m[1]), 5)
		row.add_child(UIKit.label("%s %d" % [Fmt.MONTHS[int(d["month"]) - 1], int(d["year"])], "Caps"))
		card.add_child(row)
	if dated.size() > 8:
		card.add_child(UIKit.label("e mais %d." % (dated.size() - 8), "Muted"))
	var past := CareerStats.past_summary(f)
	if not past.is_empty():
		card.add_child(UIKit.label("Antes do jogo", "Caps"))
		card.add_child(UIKit.label(" · ".join(past), "Small", true))
	if dated.is_empty() and past.is_empty():
		card.add_child(UIKit.label("Os marcos aparecem aqui conforme a carreira anda.", "Muted", true))
	if f.retired:
		return UIKit.card_panel(card)
	var nxt := CareerStats.next_marks(f)
	if not nxt.is_empty():
		card.add_child(UIKit.label("A seguir", "Caps"))
		for it: Array in nxt:
			card.add_child(UIKit.kv(String(it[0]), "%d de %d" % [int(it[1]), int(it[2])]))
			card.add_child(UIKit.bar(float(it[1]), float(it[2]), UIColors.GOLD, 6))
	return UIKit.card_panel(card)


func _treino(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	if Camp.bout_of(w, f) != null:
		c.add_child(_camp_card(w, f))
	else:
		c.add_child(UIKit.label("Sem luta marcada. Quando houver, o camp para a luta aparece aqui: foco, onde treinar e sparring.", "Small", true))
	c.add_child(UIKit.section_header("Foco do treino"))
	var items: Array = []
	for k: String in Development.FOCUS:
		var fo: Dictionary = Development.FOCUS[k]
		items.append([k, String(fo["name"]), String(fo["help"])])
	c.add_child(UIKit.option_grid(items, String(f.training.get("focus", "equilibrado")), func(k: String):
		f.training["focus"] = k
		Tutorial.mark(world(), "treino")
		refresh()))
	c.add_child(UIKit.section_header("Intensidade"))
	c.add_child(UIKit.segment([["0", "Leve"], ["1", "Normal"], ["2", "Pesado"]], str(int(f.training.get("intensity", 1))), func(k: String):
		f.training["intensity"] = int(k)
		Tutorial.mark(world(), "treino")
		refresh()))
	var txt: String = ["Evolui devagar, quase sem risco de lesão. Bom na semana antes da luta.", "O ritmo de sempre.", "Evolui mais rápido, mas a condição física cai e o risco de lesão sobe."][int(f.training.get("intensity", 1))]
	c.add_child(UIKit.label(txt, "Small", true))
	var t := w.user_team()
	var staff := UIKit.card("Card", UITokens.S1)
	staff.add_child(UIKit.label("Quem treina", "Section"))
	for role: String in ["striking", "wrestling", "jiujitsu", "fisico"]:
		var s := t.staff_of(role)
		staff.add_child(UIKit.kv(StaffMarket.role_name(role), String(s["name"]) + " (%d)" % int(s["quality"]) if not s.is_empty() else "ninguém", UIColors.TEXT if not s.is_empty() else UIColors.ORANGE))
	var mk := Morale.train_k(w, f)
	staff.add_child(UIKit.kv("Moral no treino", "%s (%s%d%%)" % [Morale.label(f).to_lower(), "+" if mk >= 1.0 else "", int(round((mk - 1.0) * 100.0))], UIColors.GREEN if mk >= 1.03 else (UIColors.RED if mk <= 0.97 else UIColors.TEXT)))
	c.add_child(UIKit.card_panel(staff))
	# O que a casa enxerga do futuro dele (pela faixa do potencial, não pelo número escondido).
	var est := Scouting.estimate(w, f)
	var gap := float(est.get("mid", f.level())) - float(f.level())
	var age := w.age_of(f)
	var pk := Scouting.peak_guess(w, f)
	var outlook := "Ainda tem bastante para crescer." if gap > 8 and age < 28 else ("Perto do auge: treino mantém mais do que melhora." if age >= 29 else "Cresce aos poucos.")
	if pk > 0 and age > pk + 1:
		outlook = "Passou do auge: velocidade, fôlego e queixo começam a cair."
	c.add_child(UIKit.label(outlook, "Muted", true))


## Camp: as semanas antes da luta marcada. Foco, onde treinar, sparring e o que isso rende na noite.
func _camp_card(w: GameWorld, f: Fighter) -> Control:
	var b := Camp.bout_of(w, f)
	var o := w.fighter(b.other(f.id))
	var ev := w.event(b.event_id)
	var cp := Camp.ensure(w, f)
	var team := w.user_team()
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(UIKit.label("Camp para a luta", "Section"))
	card.add_child(UIKit.label("Contra %s · %s · %s" % [o.display_name(), ev.name if ev != null else "", w.weeks_from_now(b.week)], "Small", true))
	var pts := float(cp.get("pts", 0.0))
	var left := Camp.weeks_left(w, f)
	var gain := Camp.week_gain(w, f, team)
	var proj := minf(100.0, pts + gain * left)
	var wait := Camp.starts_in(w, f)
	if wait > 0:
		card.add_child(UIKit.label("O camp começa em %s (oito antes da luta). Deixe tudo escolhido desde já." % Fmt.plural(wait, "semana", "semanas"), "Small", true))
	card.add_child(UIKit.kv("Forma até aqui", "%d%%" % int(round(pts))))
	card.add_child(UIKit.bar(pts, 100.0, UIColors.GOLD, 10))
	if left > 0:
		card.add_child(UIKit.kv("Na noite da luta, neste ritmo", "%d%% · %s" % [int(round(proj)), Camp.label(proj)], UIColors.GREEN if proj >= 65.0 else (UIColors.ORANGE if proj < 45.0 else UIColors.TEXT)))
	else:
		card.add_child(UIKit.label("Semana da luta: o camp acabou, agora é a pesagem.", "Small", true))
	card.add_child(UIKit.label("Foco", "Caps"))
	var items: Array = []
	for k: String in Camp.FOCUS_ORDER:
		items.append([k, String(Camp.FOCUS[k]["name"]), String(Camp.FOCUS[k]["help"])])
	card.add_child(UIKit.option_grid(items, String(cp.get("focus", "plano")), func(k: String):
		cp["focus"] = k
		refresh(), 1))
	card.add_child(UIKit.label("Onde", "Caps"))
	card.add_child(UIKit.segment([["casa", "Em casa"], ["fora", "Fora · %s/sem" % Fmt.money(Camp.away_cost(w, f))]], String(cp.get("place", "casa")), func(k: String):
		cp["place"] = k
		refresh()))
	var home_q := int(round(Morale.gym_quality(w, team)))
	card.add_child(UIKit.label("Numa academia grande, técnicos de nível %d cuidam do camp." % int(Camp.AWAY_QUALITY) if String(cp.get("place", "casa")) == "fora" else "Os técnicos da casa tocam o camp (média %d). Técnico melhor junta forma mais rápido." % home_q, "Small", true))
	card.add_child(UIKit.label("Sparring", "Caps"))
	card.add_child(UIKit.segment([["0", "Só os da casa"], ["1", "Contratado · %s/sem" % Fmt.money(Camp.spar_cost(w, f))]], "1" if bool(cp.get("spar", false)) else "0", func(k: String):
		cp["spar"] = k == "1"
		refresh()))
	card.add_child(UIKit.label("Parceiros pagos para imitar %s: a forma sobe 20%% mais rápido e o estudo do adversário rende mais. Há um risco pequeno de lesão." % o.short_name(), "Small", true))
	# O que isso rende na noite.
	var focus := String(cp.get("focus", "plano"))
	var lines := Camp.gain_lines(Camp.mods_for(proj if left > 0 else pts, focus, f, o, b, bool(cp.get("spar", false))))
	if focus == "peso":
		lines.insert(0, "corte de peso %d%% mais leve" % int(round(clampf((proj if left > 0 else pts) / 100.0, 0.0, 1.0) * 80.0)))
	card.add_child(UIKit.label("O que rende na noite", "Caps"))
	card.add_child(UIKit.label(", ".join(lines) + "." if not lines.is_empty() else "Quase nada: o camp está curto demais.", "", true))
	if float(cp.get("cost", 0.0)) > 0.0:
		card.add_child(UIKit.kv("Gasto até aqui", Fmt.money(float(cp["cost"]))))
	card.add_child(UIKit.label("A intensidade é a do treino, logo abaixo. Pesado junta forma mais rápido e derruba a condição física (hoje %d%%): chegue à semana da luta perto de 100%%, com treino leve no fim." % int(f.condition), "Small", true))
	return UIKit.card_panel(card)


func _contrato(w: GameWorld, f: Fighter, c: VBoxContainer) -> void:
	var card := UIKit.card("Card", UITokens.S1)
	card.add_child(UIKit.label("Contrato", "Section"))
	var cut := float(f.contract.get("cut", 0.2))
	card.add_child(UIKit.kv("Fatia das bolsas para a equipe", "%d%%" % int(round(cut * 100.0))))
	var left := int(f.contract.get("fights", 0))
	card.add_child(UIKit.kv("Lutas restantes", str(maxi(0, left)), UIColors.RED if left <= 0 else UIColors.TEXT))
	c.add_child(UIKit.card_panel(card))
	if left <= 1:
		c.add_child(UIKit.label("Renove antes que acabe: com o contrato vencido, ele pode sair a qualquer semana.", "Small", true))
		c.add_child(UIKit.button("Renovar por 5 lutas (20%)", "GhostButton", func():
			var r := Signing.renew(w, f, 0.2, 5)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			if not bool(r["ok"]):
				UIManager.back()
			else:
				refresh()))
	c.add_child(UIKit.button("Dispensar", "DangerButton", func():
		UIManager.confirm("Dispensar %s?" % f.display_name(), "Ele sai da equipe na hora e uma luta marcada é cancelada.", "Dispensar", func():
			Signing.release(w, f)
			UIManager.back())))


func _actions(w: GameWorld, f: Fighter) -> void:
	var foot := footer()
	if w.is_president():
		_president_actions(w, f, foot)
		return
	if w.is_user_fighter(f):
		var offers := w.offers.filter(func(o: Dictionary) -> bool: return int(o["fighter"]) == f.id)
		if not offers.is_empty():
			foot.add_child(UIKit.button("Ver proposta (%d)" % offers.size(), "PrimaryButton", func(): UIManager.push("offer", {"id": int(offers[0]["id"])})))
		elif f.bout_id < 0 and f.is_pro():
			foot.add_child(UIKit.button("Desafiar alguém", "PrimaryButton", func(): UIManager.push("rankings", {"challenger": f.id, "div": f.division})))
		else:
			hide_footer()
		return
	if f.team_id < 0 and not f.retired:
		foot.add_child(UIKit.button("Fazer proposta de contrato", "PrimaryButton", func(): ContractSheet.open(w, f, func(): refresh())))
		return
	var mine := w.user_fighters().filter(func(m: Fighter) -> bool: return m.division == f.division)
	if not mine.is_empty() and not f.retired:
		foot.add_child(UIKit.button("Desafiar", "PrimaryButton", func(): UIManager.push("challenge", {"target": f.id})))
	else:
		hide_footer()



## Presidente: marcar luta para este lutador na próxima noite da liga em que ele pode lutar, ou
## ver o card em que ele já está.
func _president_actions(w: GameWorld, f: Fighter, foot: VBoxContainer) -> void:
	var b := w.bout(f.bout_id)
	if b != null and b.status == "marcada":
		var ev := w.event(b.event_id)
		if ev != null and ev.tier == 2:
			foot.add_child(UIKit.button("Ver o card da %s" % ev.name, "GhostButton", func(): UIManager.push("org_event", {"id": ev.id})))
		else:
			foot.add_child(UIKit.button("Ver o card da %s" % (ev.name if ev != null else "noite"), "GhostButton", func(): UIManager.push("event", {"id": b.event_id})))
		return
	if not Org.eligible(w, f) or not f.injury.is_empty() or f.retired:
		hide_footer()
		return
	var target: FightEvent = null
	for ev: FightEvent in Org.upcoming_events(w):
		if ev.week - w.week >= 2 and Org.event_bouts(w, ev).size() < ev.slots and Matchmaker.ready_to_book(w, f, ev.week - w.week) and f.suspension <= ev.week - w.week:
			target = ev
			break
	if target == null:
		hide_footer()
		return
	var tid := target.id
	foot.add_child(UIKit.button("Marcar luta na %s" % target.name, "PrimaryButton", func(): UIManager.push("book", {"event": tid, "a": f.id})))
