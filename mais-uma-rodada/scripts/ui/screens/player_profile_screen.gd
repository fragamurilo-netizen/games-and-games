extends BaseScreen
## Perfil do jogador. Primeiro responde "esse jogador é bom para o meu time?";
## depois atributos, personalidade e histórico.

var _pid := -1
var _tab := "geral"
var _season_filter := 0 # temporada a temporada: 0 todas, 1 liga, 2 outras competições
const TABS := [["geral", "Visão"], ["atributos", "Atributos"], ["numeros", "Forma"], ["carreira", "Histórico"], ["contrato", "Contrato"], ["origem", "Origem"]]


func _init() -> void:
	pass


func setup(p: Dictionary) -> void:
	super.setup(p)
	var np := int(p.get("id", -1))
	if np != _pid:
		_tab = String(p.get("tab", "geral"))
	_pid = np


func refresh() -> void:
	var w := world()
	var p := w.player(_pid) if w != null else null
	var c := content()
	UIKit.clear(c)
	if p == null:
		screen_title = "Jogador"
		screen_subtitle = ""
		UIManager.refresh_chrome()
		c.add_child(UIKit.label("Este jogador não está mais em atividade.", "Muted"))
		hide_footer()
		return
	var own := p.club_id >= 0 and w.is_user_club(p.club_id)
	NationalityManager.ensure(w, p)
	var club := w.club(p.club_id) if p.club_id >= 0 else null
	screen_title = p.display_name()
	screen_subtitle = club.short_name if club != null else "Sem clube"
	UIManager.refresh_chrome()
	max_content_width = 1800.0
	if club != null and not UILayout.is_landscape():
		var nav := _squad_nav(w, p, club)
		if nav != null:
			c.add_child(nav)
	c.add_child(_header(w, p, club))
	c.add_child(_tabs_row(p))
	match _tab:
		"origem":
			c.add_child(_origin_card(w, p))
		"numeros":
			c.add_child(_stats(w, p))
		"carreira":
			c.add_child(_career(w, p))
			c.add_child(_memory(w, p))
		"atributos":
			UIKit.columns(c, [_attributes(w, p, own), _style_card(p), _positions_card(w, p, own)], content_width())
		"contrato", "perfil":
			var cards: Array = [_summary(w, p, own), _rep_card(w, p)]
			UIKit.columns(c, cards, content_width())
		_:
			var ov: Array = [_condition_block(w, p), _fit_card(w, p, own)]
			ov.append(_personality(w, p, own))
			if own:
				ov.append(RelationsScreen.player_card(w, p, func(): refresh()))
			var social: Control = SocialPost.mini_card(w, -1, p.id)
			if social != null:
				ov.append(social)
			# Tablet: os atributos já aparecem ao lado, sem trocar de aba.
			if UILayout.columns_for(content_width()) >= 2:
				var left := UIKit.vbox(UITokens.S4)
				for card: Control in ov:
					if card != null:
						left.add_child(card)
				ov = [left, _attributes(w, p, own)]
			UIKit.columns(c, ov.filter(func(x) -> bool: return x != null), content_width(), 2)
	hide_footer()
	_actions(w, p, own)
	if UILayout.is_landscape() and club != null:
		var nav := _squad_nav(w,p,club)
		if nav != null: _acts.add_child(nav)


## Setas para o jogador anterior/seguinte do mesmo elenco (na ordem de posição e nível),
## sem empilhar telas: troca o perfil no lugar e mantém a aba aberta.
func _squad_nav(w: GameWorld, p: Player, club: Club) -> Control:
	var sq: Array = w.squad(club)
	if sq.size() < 2:
		return null
	sq.sort_custom(func(a: Player, b: Player):
		var ia := Pos.DISPLAY_ORDER.find(a.position)
		var ib := Pos.DISPLAY_ORDER.find(b.position)
		if ia != ib:
			return ia < ib
		return a.ovr_f > b.ovr_f)
	var i := sq.find(p)
	if i < 0:
		return null
	var prev: Player = sq[(i - 1 + sq.size()) % sq.size()]
	var next: Player = sq[(i + 1) % sq.size()]
	var row := UIKit.hbox(8)
	var bp := UIKit.button("%s %s" % [Pos.code(prev.position), prev.short_name()], "TextButton", func(): _go(prev.id), "back")
	bp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bp.alignment = HORIZONTAL_ALIGNMENT_LEFT
	bp.clip_text = true
	bp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bp.custom_minimum_size.y = UITokens.H_BUTTON
	row.add_child(bp)
	var pos := UIKit.label("%d/%d" % [i + 1, sq.size()], "Caps")
	pos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pos)
	var bn := UIKit.button("%s %s" % [next.short_name(), Pos.code(next.position)], "TextButton", func(): _go(next.id), "forward")
	bn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bn.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bn.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	bn.clip_text = true
	bn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bn.custom_minimum_size.y = UITokens.H_BUTTON
	row.add_child(bn)
	return row


func _go(pid: int) -> void:
	_pid = pid
	params["id"] = pid
	refresh()
	scroll_to_top()


func _tabs_row(p: Player) -> Control:
	var row := UIKit.hbox(8)
	var t := UIKit.scroll_tabs(TABS, _tab, func(key: String):
		_tab = key
		refresh()
		scroll_to_top())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var pid := p.id
	var w := world()
	if w != null and w.has_user() and not w.is_user_club(p.club_id) and not w.academy.has(p.id) and not p.retiring:
		row.add_child(_shortlist_button(w, p))
	row.add_child(UIKit.icon_button("swap", func(): UIManager.push("compare", {"a": pid}), "Comparar"))
	return row


## Estrela da lista de observação do mercado (acesa = jogador na lista).
func _shortlist_button(w: GameWorld, p: Player) -> Button:
	var on := Shortlist.has(w, p)
	var b := UIKit.icon_button("star", func():
		if not Shortlist.has(w, p) and Shortlist.is_full(w):
			UIManager.toast("Sua lista está cheia (%d). Tire alguém no Mercado > Lista." % Shortlist.MAX_ENTRIES, UIColors.ORANGE)
			return
		var added := Shortlist.toggle(w, p)
		UIManager.toast("%s entrou na sua lista de observação." % p.display_name() if added else "%s saiu da sua lista." % p.display_name(), UIColors.GREEN if added else UIColors.TEXT)
		GameManager.save_now()
		refresh(), "Tirar da lista" if on else "Pôr na lista")
	var tint := UIColors.ACCENT if on else UIColors.MUTED
	for k in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_focus_color"]:
		b.add_theme_color_override(k, tint)
	return b


func _header(w: GameWorld, p: Player, club: Club) -> Control:
	var compact := UILayout.is_landscape()
	var ps := 84 if compact else 104
	# A faixa diagonal passa ~78 px além do bloco: bloco = retrato − 48 deixa o nome livre
	# (margem 18 + retrato + 12). Altura do bloco = só a do retrato, que fica no topo.
	var hero := IdentityBand.wrap(club, float(ps) - 48.0, float(ps) + 36.0)
	var card: VBoxContainer = hero[1]
	var row := UIKit.hbox(UITokens.S2)
	# Foto de ficha (estúdio) no lugar do retrato simples
	var pv := UIKit.photo(p, club, w.year, Vector2(ps, ps), "perfil")
	pv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(pv)
	var names := UIKit.vbox(UITokens.S1)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UIKit.label(p.display_name(), "Section" if compact else "Title", true)
	title.max_lines_visible = 2
	title.tooltip_text = p.full_name()
	names.add_child(title)
	names.add_child(UIKit.label("%s · %d anos" % [Pos.name_of(p.position),p.age(w.year)], "Small", true))
	var assessment := UIKit.hbox(UITokens.S2)
	assessment.add_child(UIKit.player_stars(w,p,17))
	var confidence_label := UIKit.label(PlayerAssessment.confidence_name(w,p),"Small",true)
	confidence_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not compact: assessment.add_child(confidence_label)
	else: confidence_label.free()
	names.add_child(assessment)
	row.add_child(names)
	card.add_child(row)
	if club != null:
		var cr := UIKit.hbox(UITokens.S1)
		cr.add_child(UIKit.crest(club,28))
		if p.shirt > 0: cr.add_child(UIKit.shirt_number(p,club,44))
		var label := UIKit.label(club.short_name + (" · emprestado" if not p.loan.is_empty() else ""), "", true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cr.add_child(label)
		cr.add_child(UIKit.icon_rect("forward",20,UIColors.DIM))
		var cid := club.id
		var info_parent: VBoxContainer = names if compact else card
		info_parent.add_child(UIKit.tap_row(cr,func(): UIManager.push("club",{"id":cid}),"PanelContainer"))
		info_parent.add_child(UIKit.label(p.club_tenure(w.year),"Small",true))
	if p.injury_weeks > 0:
		card.add_child(UIKit.colored(("Fora por lesão · %s · %d semana" if p.injury_weeks == 1 else "Fora por lesão · %s · %d semanas") % [p.injury_name,p.injury_weeks],UIColors.ORANGE,"",true))
	elif p.suspension > 0:
		card.add_child(UIKit.colored(("Suspenso · %d jogo" if p.suspension == 1 else "Suspenso · %d jogos") % p.suspension,UIColors.ORANGE,"",true))
	elif p.intl_duty:
		card.add_child(UIKit.colored("A serviço da seleção",UIColors.ORANGE,"",true))
	_acts = UIKit.vbox(UITokens.S2)
	if compact:
		_acts.custom_minimum_size.x = 390
		_acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(_acts)
	else:
		card.add_child(_acts)
	return hero[0]


func _fact(value: String, caption: String, lead: Control = null) -> Control:
	var v := UIKit.card("CardFlat", 0)
	var panel := UIKit.card_panel(v)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.self_modulate = Color(1, 1, 1, 0.85)
	var top := UIKit.hbox(6)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	if lead != null:
		top.add_child(lead)
	top.add_child(UIKit.label(value, "H3"))
	v.add_child(top)
	var c := UIKit.label(caption, "Caps")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_theme_font_size_override(&"font_size", 13)
	v.add_child(c)
	return panel


## Selo da ficha: overall grande e, embaixo, o potencial em palavras.
func _ovr_block(w: GameWorld, p: Player, _own: bool) -> Control:
	return UIKit.player_stars(w,p,18)


func _rep_card(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section_header("Reputação", "Ranking", func(): UIManager.push("reputation")))
	var rep := Reputation.player_rep(w, p)
	var honours := 0.0
	var best: Dictionary = {}
	for t in p.trophies:
		var k := String(t.get("k", ""))
		var v := Reputation.title_value(k)
		honours += v
		if not best.has(k):
			best[k] = [0, v]
		best[k][0] += 1
	card.add_child(UIKit.stat_grid([
		UIKit.stat_tile(str(int(round(rep))), Reputation.player_label(rep), Reputation.color(rep)),
		UIKit.stat_tile(str(p.titles), "títulos"),
		UIKit.stat_tile(str(int(round(honours))), "prestígio"),
	], 600))
	var keys := best.keys()
	keys.sort_custom(func(a, b): return float(best[a][1]) > float(best[b][1]))
	for i in mini(4, keys.size()):
		var k: String = keys[i]
		card.add_child(UIKit.kv("%dx %s" % [int(best[k][0]), Reputation.comp_name(w, k)], "%d pts cada" % int(round(float(best[k][1])))))
	if keys.is_empty():
		card.add_child(UIKit.label("Ainda sem títulos.", "Small", true))
	return UIKit.card_panel(card)


## Contrato e dinheiro: o que pesa numa negociação, em linhas chave-valor.
func _summary(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 4)
	card.add_child(UIKit.section_header("Contrato"))
	card.add_child(UIKit.kv("Valor de mercado", Fmt.money(p.value)))
	if p.club_id >= 0:
		card.add_child(UIKit.kv("Salário", Fmt.money_month(p.wage)))
		card.add_child(UIKit.kv("Contrato até", str(p.contract_end), UIColors.ORANGE if own and p.contract_end <= w.year else UIColors.TEXT))
		card.add_child(UIKit.kv("Papel no elenco", Player.STATUS_NAMES[p.squad_status]))
	else:
		card.add_child(UIKit.kv("Situação", "Livre, sem taxa"))
	var rc := MarketAI._clause_of(w.club(p.club_id), p) if p.club_id >= 0 else 0
	if rc > 0:
		card.add_child(UIKit.kv("Multa rescisória", Fmt.money(rc)))
	if p.transfer_listed:
		card.add_child(UIKit.kv("À venda por", Fmt.money(TransferManager.asking_price(w, p)), UIColors.GREEN))
	elif not own and p.club_id >= 0 and p.loan.is_empty():
		card.add_child(UIKit.kv("Pedem", Fmt.money(TransferManager.asking_price(w, p))))
	if not p.loan.is_empty():
		var owner := w.club(int(p.loan.get("from", -1)))
		if TransferRules.is_held(p):
			card.add_child(UIKit.kv("Vendido ao", "%s, chega em %d" % [owner.short_name if owner != null else "?", int(p.loan.get("until", w.year)) + 1], UIColors.ORANGE))
		else:
			card.add_child(UIKit.kv("Emprestado pelo", "%s até %d" % [owner.short_name if owner != null else "?", int(p.loan.get("until", w.year))], UIColors.ORANGE))
	if p.retiring:
		card.add_child(UIKit.colored("Anunciou que vai se aposentar ao fim da temporada.", UIColors.ORANGE, "Small", true))
	return UIKit.card_panel(card)


## Situação para o próximo jogo: faixa de números (físico, moral, forma, temporada) e, embaixo,
## o que impede ou ameaça a escalação. Um bloco de informação, não um card por métrica.
func _condition_block(w: GameWorld, p: Player) -> Control:
	var v := UIKit.vbox(UITokens.S2)
	v.add_child(UIKit.label("Agora", "Section"))
	var t := p.season_totals()
	var items: Array = []
	if p.injury_weeks > 0:
		items.append(["Lesão", "%d sem." % p.injury_weeks, UIColors.RED])
	else:
		items.append(["Físico", "%d%%" % int(p.condition), UIColors.TEXT if p.condition >= 85 else (UIColors.ORANGE if p.condition >= 70 else UIColors.RED)])
	items.append(["Moral", UIColors.morale_label(p.morale), UIColors.morale_color(p.morale)])
	items.append(["Forma", Fmt.rating(p.form()) if not p.recent_ratings.is_empty() else "–", Fmt.match_rating_color(p.form()) if not p.recent_ratings.is_empty() else UIColors.DIM])
	items.append(["Jogos", str(int(t[0])), UIColors.TEXT])
	items.append(["Gols", str(int(t[1])), UIColors.TEXT])
	v.add_child(StatStrip.make(items))
	if p.injury_weeks > 0:
		v.add_child(UIKit.colored("%s. Volta em %d semana(s)." % [p.injury_name, p.injury_weeks], UIColors.RED, "Small", true))
	if p.suspension > 0:
		v.add_child(UIKit.colored("Suspenso por %d jogo(s)." % p.suspension, UIColors.RED, "Small", true))
	return v

func _tile(value: String, caption: String, color: Color = UIColors.TEXT, fill: float = -1.0) -> Control:
	var v := UIKit.card("CardFlat", 2)
	var panel := UIKit.card_panel(v)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Mesmo desenho dos ladrilhos de número do resto do jogo: valor condensado, legenda em caixa alta.
	var l := UIKit.label(value, "Stat")
	l.add_theme_color_override(&"font_color", UIColors.ink(color))
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 40
	v.add_child(l)
	var c := UIKit.label(caption.to_upper(), "Caps")
	# Legenda quebra em vez de cortar ("valor de mer...") quando o bloco fica estreito
	c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.custom_minimum_size.x = 40
	v.add_child(c)
	if fill >= 0.0:
		var b := UIKit.bar(fill * 100.0, 100.0, color if color != UIColors.TEXT else UIColors.BLUE, 5)
		v.add_child(b)
	return panel


## "Esse jogador é bom para meu time?"
## Onde ele joga: mini campo com a posição principal, as secundárias e as vizinhas, pé e rendimento.
## Estilo de jogo e traço: o que o jogador faz em campo e como isso muda o jogo do time.
func _style_card(p: Player) -> Control:
	var d := PlayStyle.describe(p)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Estilo de jogo"))
	var head := UIKit.flow(8)
	head.add_child(UIKit.pill(String(d["name"]).to_upper(), UIColors.BLUE, 16))
	if String(d["trait"]) != "":
		head.add_child(UIKit.pill(String(d["trait"]).to_upper(), UIColors.ACCENT, 16))
	card.add_child(head)
	card.add_child(UIKit.label(String(d["desc"]), "", true))
	if String(d["instruction_name"]) != "":
		card.add_child(UIKit.colored("Instrução ideal: %s" % String(d["instruction_name"]), UIColors.GREEN, "Small", true))
	return UIKit.card_panel(card)


func _positions_card(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Posições"))
	var row := UIKit.hbox(16)
	row.add_child(PositionMap.make(p, 170))
	var col := UIKit.vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list: Array = [[p.position, "Principal", Color("#FFC940")]]
	for s in p.secondary:
		list.append([int(s), "Secundária", UIColors.GREEN])
	for k in Pos.RELATED[p.position]:
		if float(Pos.RELATED[p.position][k]) >= 0.85 and not p.secondary.has(k):
			list.append([int(k), "Improvisa", UIColors.MUTED])
	for e in list.slice(0, 6):
		var r := UIKit.hbox(8)
		r.add_child(UIKit.pos_badge(int(e[0])))
		var nm := UIKit.vbox(0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.add_child(UIKit.label(Pos.name_of(int(e[0])), "", true))
		nm.add_child(UIKit.colored(String(e[1]), e[2], "Small"))
		r.add_child(nm)
		r.add_child(UIKit.player_stars(w,p,13,false,int(e[0])))
		col.add_child(r)
	var frow := UIKit.hbox(10)
	frow.add_child(FootView.make(p.foot, 34))
	frow.add_child(UIKit.label(["Destro", "Canhoto", "Ambidestro"][p.foot], "Small", true))
	col.add_child(frow)
	row.add_child(col)
	card.add_child(row)
	return UIKit.card_panel(card)


func _fit_card(w: GameWorld, p: Player, _own: bool) -> Control:
	var card := UIKit.card("Card",UITokens.S2)
	var club := w.user_club()
	card.add_child(UIKit.section("Para o elenco do " + club.short_name if club != null else "Avaliação da comissão"))
	card.add_child(UIKit.label(PlayerAssessment.fit_text(w,p),"H3",true))
	var ratings := UIKit.hbox(UITokens.S4)
	for future in [false,true]:
		var col := UIKit.vbox(UITokens.S1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label("Projeção de evolução" if future else Pos.name_of(p.position),"Small",true))
		col.add_child(UIKit.player_stars(w,p,20,future))
		ratings.add_child(col)
	card.add_child(ratings)
	card.add_child(UIKit.label("Estrelas claras: margem de incerteza. A projeção depende de treino e minutos em campo.","Small",true))
	card.add_child(UIKit.separator())
	card.add_child(UIKit.label("Pontos fortes", "Small"))
	card.add_child(UIKit.label(PlayerAssessment.standout(w,p),"",true))
	card.add_child(UIKit.label("Atenção na função", "Small"))
	card.add_child(UIKit.label(PlayerAssessment.standout(w,p,-1,true),"",true))
	card.add_child(UIKit.button("Ver todos os atributos","TextButton",func():
		_tab = "atributos"
		refresh()))
	return UIKit.card_panel(card)


func _attr_val(p: Player, a: int, _own: bool) -> int:
	return PlayerAssessment.attribute(world(),p,a)


func _attributes(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Atributos" + ("" if own else " (avaliação do olheiro)")))
	var groups: Array = []
	for g: Array in Attr.UI_GROUPS:
		if String(g[0]) == "Goleiro" and p.position != Pos.GK:
			continue
		groups.append(g)
	if p.position == Pos.GK:
		groups.erase(groups[groups.size() - 1])
		groups.insert(0, ["Goleiro", [Attr.GOL, Attr.REF]])
	# Radar com a média de cada grupo, para ler o jogador num relance
	var axes: Array = []
	var avgs: Array = []
	for g: Array in groups:
		var sum := 0
		for a in g[1]:
			sum += _attr_val(p, int(a), own)
		var avg := int(round(float(sum) / (g[1] as Array).size()))
		axes.append([String(g[0]), avg])
		avgs.append(avg)
	for gi in groups.size():
		var g: Array = groups[gi]
		var head := UIKit.hbox(8)
		var gl := UIKit.label(String(g[0]), "Caps")
		gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(gl)
		card.add_child(UIKit.gap(4))
		card.add_child(head)
		# Dois atributos por linha: nome e número em cima, barra fina embaixo
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override(&"h_separation", 22)
		grid.add_theme_constant_override(&"v_separation", 10)
		for a in g[1]:
			var v := _attr_val(p, int(a), own)
			var cell := UIKit.vbox(4)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var top := UIKit.hbox(6)
			var n := UIKit.label(Attr.NAMES[a], "")
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			n.custom_minimum_size.x = 60
			top.add_child(n)
			var num := UIKit.label(PlayerAssessment.attribute_text(w,p,int(a)), "H3")
			num.add_theme_color_override(&"font_color", Fmt.rating_color(v))
			top.add_child(num)
			cell.add_child(top)
			cell.add_child(UIKit.bar(v, 100.0, Fmt.rating_color(v), 6))
			grid.add_child(cell)
		card.add_child(grid)
	var radar := AttrRadar.make(axes,300)
	radar.visible = false
	card.add_child(UIKit.button("Gráfico dos atributos","TextButton",func(): radar.visible = not radar.visible))
	card.add_child(radar)
	return UIKit.card_panel(card)


func _personality(w: GameWorld, p: Player, own: bool) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Personalidade"))
	for t in p.traits:
		var d := DatabaseManager.trait_data(t)
		card.add_child(UIKit.label(String(d.get("name", t)), "H3"))
		card.add_child(UIKit.label(String(d.get("desc", "")), "Muted", true))
	if own:
		card.add_child(UIKit.label("Consistência: %s · Propensão a lesões: %s" % [_level(p.consistency, false), _level(p.injury_prone, true)], "Small", true))
	# Personalidade oculta: nunca o número, só o que a comissão percebe com a convivência.
	card.add_child(UIKit.label("O que a comissão percebe", "Caps"))
	if not own:
		card.add_child(UIKit.label("Desconhecido.", "Muted", true))
	elif not HiddenPersona.known(w, p):
		card.add_child(UIKit.label("Em observação.", "Muted", true))
	else:
		var rep_lines := HiddenPersona.report(p)
		if rep_lines.is_empty():
			card.add_child(UIKit.label("Equilibrado.", "Muted", true))
		for ln: Array in rep_lines:
			card.add_child(UIKit.colored(String(ln[0]), UIColors.GREEN if ln[1] else UIColors.RED, "Small", true))
	if not p.persona_log.is_empty():
		card.add_child(UIKit.label("Como ele mudou", "Caps"))
		for i in range(p.persona_log.size() - 1, maxi(-1, p.persona_log.size() - 6), -1):
			var e: Dictionary = p.persona_log[i]
			var nm := String(DatabaseManager.trait_data(String(e["t"])).get("name", e["t"]))
			var line := "%d · %s %s. %s" % [int(e["y"]), "Virou" if e.get("add", false) else "Deixou de ser", nm.to_lower(), String(e.get("why", ""))]
			card.add_child(UIKit.colored(line, UIColors.GREEN if e.get("add", false) else UIColors.MUTED, "Small", true))
	return UIKit.card_panel(card)


static func _level(v: int, inverted: bool) -> String:
	var x := 21 - v if inverted else v
	if x >= 16:
		return "alta" if not inverted else "baixa"
	if x >= 9:
		return "média"
	return "baixa" if not inverted else "alta"


func _stats(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Temporada %d" % w.year))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(p.stats[Player.S_APPS]), "jogos"))
	row.add_child(UIKit.stat(str(p.stats[Player.S_GOALS]), "gols"))
	row.add_child(UIKit.stat(str(p.stats[Player.S_ASSISTS]), "assist."))
	row.add_child(UIKit.stat(Fmt.rating(p.avg_rating()) if p.stats[Player.S_APPS] > 0 else "—", "nota"))
	row.add_child(UIKit.stat("%d/%d" % [p.stats[Player.S_YELLOWS], p.stats[Player.S_REDS]], "cartões"))
	card.add_child(row)
	var row_b := UIKit.hbox(4)
	var mins := p.stats[Player.S_MINUTES]
	row_b.add_child(UIKit.stat(str(p.stats[Player.S_STARTS]), "titular"))
	row_b.add_child(UIKit.stat(str(mins), "minutos"))
	row_b.add_child(UIKit.stat(str(p.stats[Player.S_MOTM]), "craque jogo"))
	if Pos.group(p.position) <= Pos.G_DEF:
		row_b.add_child(UIKit.stat(str(p.stats[Player.S_CLEAN]), "sem sofrer"))
	else:
		row_b.add_child(UIKit.stat("%.2f" % ((p.stats[Player.S_GOALS] + p.stats[Player.S_ASSISTS]) * 90.0 / mins) if mins >= 90 else "—", "G+A /90"))
	var d := p.season_delta()
	row_b.add_child(UIKit.stat("Em evolução" if d > 0 else "Em queda" if d < 0 else "Estável", "Treino recente"))
	card.add_child(row_b)
	if p.stats[Player.S_APPS] > 0:
		card.add_child(UIKit.label("Números detalhados (liga)", "Caps"))
		var gk := p.position == Pos.GK
		var row_c := UIKit.hbox(4)
		if gk:
			row_c.add_child(UIKit.stat(str(p.stats[Player.S_SAVES]), "defesas"))
			row_c.add_child(UIKit.stat("%.1f" % p.per90(Player.S_SAVES), "defesas /90"))
			row_c.add_child(UIKit.stat(str(p.stats[Player.S_CONCEDED]), "gols sofridos"))
			row_c.add_child(UIKit.stat("%d%%" % int(round(p.save_pct())) if p.stats[Player.S_SAVES] + p.stats[Player.S_CONCEDED] > 0 else "—", "chutes defendidos"))
			row_c.add_child(UIKit.stat("%d%%" % int(round(p.pass_pct())), "passes certos"))
		else:
			row_c.add_child(UIKit.stat("%d (%d)" % [p.stats[Player.S_SHOTS], p.stats[Player.S_SHOTS_ON]], "chutes (alvo)"))
			row_c.add_child(UIKit.stat("%.1f" % p.xg(), "xG"))
			row_c.add_child(UIKit.stat(str(p.stats[Player.S_KEY_PASSES]), "passes decisivos"))
			row_c.add_child(UIKit.stat("%d%%" % int(round(p.pass_pct())), "passes certos"))
		card.add_child(row_c)
		if not gk:
			var row_d := UIKit.hbox(4)
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_DRIBBLES]), "dribles"))
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_TACKLES]), "desarmes"))
			row_d.add_child(UIKit.stat(str(p.stats[Player.S_INTERCEPTIONS]), "interceptações"))
			var conv := 100.0 * p.stats[Player.S_GOALS] / p.stats[Player.S_SHOTS] if p.stats[Player.S_SHOTS] > 0 else 0.0
			row_d.add_child(UIKit.stat("%d%%" % int(round(conv)), "aproveitamento"))
			card.add_child(row_d)
			var row_e := UIKit.hbox(4)
			var on_pct := 100.0 * p.stats[Player.S_SHOTS_ON] / p.stats[Player.S_SHOTS] if p.stats[Player.S_SHOTS] > 0 else 0.0
			row_e.add_child(UIKit.stat("%d%%" % int(round(on_pct)) if p.stats[Player.S_SHOTS] > 0 else "—", "chutes no alvo"))
			row_e.add_child(UIKit.stat(str(p.stats[Player.S_AERIAL]), "duelos aéreos"))
			row_e.add_child(UIKit.stat(str(p.stats[Player.S_FOULS]), "faltas"))
			row_e.add_child(UIKit.stat(str(p.stats[Player.S_MINUTES] / p.stats[Player.S_GOALS]) if p.stats[Player.S_GOALS] > 0 else "—", "min por gol"))
			card.add_child(row_e)
			if mins >= 270:
				card.add_child(UIKit.label("Por 90 minutos", "Caps"))
				var row_f := UIKit.hbox(4)
				row_f.add_child(UIKit.stat(Fmt.dec(p.per90(Player.S_GOALS), 2), "gols"))
				row_f.add_child(UIKit.stat(Fmt.dec(p.per90(Player.S_ASSISTS), 2), "assist."))
				row_f.add_child(UIKit.stat(Fmt.dec(p.per90(Player.S_SHOTS), 1), "chutes"))
				row_f.add_child(UIKit.stat(Fmt.dec(p.per90(Player.S_KEY_PASSES), 1), "passes decisivos"))
				row_f.add_child(UIKit.stat(Fmt.dec(p.per90(Player.S_TACKLES) + p.per90(Player.S_INTERCEPTIONS), 1), "desarmes + intercept."))
				card.add_child(row_f)
			var diff := p.stats[Player.S_GOALS] - p.xg()
			if p.stats[Player.S_SHOTS] >= 15 and absf(diff) >= 2.0:
				card.add_child(UIKit.colored("Gols vs. esperado: %+.1f" % diff, UIColors.GREEN if diff > 0 else UIColors.ORANGE, "Small", true))
	var tot := p.season_totals()
	if int(tot[0]) > p.stats[Player.S_APPS]:
		card.add_child(UIKit.label("Com as copas: %d jogos, %d gols e %d assistências." % [int(tot[0]), int(tot[1]), int(tot[2])], "Small", true))
	return UIKit.card_panel(card)


## Aba Carreira: números da carreira, seleção, prêmios, títulos, transferências e ano a ano.
func _origin_card(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", UITokens.S2)
	card.add_child(UIKit.section("Origem e seleção"))
	card.add_child(UIKit.label(p.full_name(),"H3",true))
	card.add_child(UIKit.label("%s · %s · %s" % [Fmt.height(p.height), BodyGrowth.weight_text(p, world().year), ["Destro","Canhoto","Ambidestro"][p.foot]],"",true))
	var heart := HeartClubs.known_text(w,p)
	if heart != "": card.add_child(UIKit.label(heart,"Small",true))
	card.add_child(UIKit.label("Nascimento", "Small"))
	card.add_child(UIKit.label(NationalityManager.birthplace(p), "H3", true))
	var away := Geo.home_text(p, w.club(p.club_id)) if p.club_id >= 0 else ""
	if away != "":
		card.add_child(UIKit.label(away, "Small", true))
	card.add_child(UIKit.label("Idiomas", "Small"))
	card.add_child(UIKit.label(Languages.text(p), "", true))
	card.add_child(UIKit.separator())
	card.add_child(UIKit.section("Nacionalidades"))
	for code in NationalityManager.passports(p):
		var row := UIKit.hbox(UITokens.S2)
		row.add_child(UIKit.flag(code, 40))
		var info: Dictionary = p.origin["passports"].get(code, {})
		var basis := String(info.get("basis", "birth"))
		var detail := "Desde o nascimento" if basis == "birth" else "Vínculo familiar" if basis == "parent" else "Naturalizado em %d" % int(info.get("since", w.year))
		var text := UIKit.label(DatabaseManager.nation_name(code) + "\n" + detail, "", true)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		card.add_child(row)
	card.add_child(UIKit.separator())
	card.add_child(UIKit.section("Seleção: " + DatabaseManager.nation_name(NationalityManager.team(p))))
	for code in p.origin.get("records", {}):
		var rec: Dictionary = p.origin["records"][code]
		card.add_child(UIKit.label(("" if code == NationalityManager.team(p) else DatabaseManager.nation_name(code)+" · ") + "%d jogos · %d gols · %d assistências" % [int(rec.get("apps",0)),int(rec.get("goals",0)),int(rec.get("assists",0))], "", true))
	var alternatives: Array = []
	for code in NationalityManager.passports(p):
		if code != NationalityManager.team(p) and NationalityManager.eligible(w, p, code): alternatives.append(DatabaseManager.nation_name(code))
	if not alternatives.is_empty():
		card.add_child(UIKit.label("Também pode representar: " + ", ".join(alternatives), "Small", true))
	elif NationalTeamManager.caps_of(w, p.id)[0] > 0:
		card.add_child(UIKit.label("Vinculado à seleção atual pelo histórico internacional.", "Small", true))
	var coach := NationalCoach.nation(w)
	if coach != "" and coach != NationalityManager.team(p) and NationalityManager.eligible(w, p, coach):
		card.add_child(UIKit.button("Convidar para " + DatabaseManager.nation_name(coach), "PrimaryButton", func():
			if NationalityManager.choose(w, p, coach):
				GameManager.save_now()
				refresh()))
	var status := NationalityManager.progress(w, p)
	var nation := String(status["nation"])
	if nation != "" and not NationalityManager.passports(p).has(nation):
		card.add_child(UIKit.separator())
		card.add_child(UIKit.section("Residência em " + DatabaseManager.nation_name(nation)))
		card.add_child(UIKit.label("Desde %d · %d temporadas completas" % [int(p.origin["residence"].get("since", w.year)),int(status["years"])], "", true))
		if bool(status["paused"]):
			card.add_child(UIKit.label("Sem registro atual de residência para continuar a contagem.", "Small", true))
		elif int(status["required"]) > 0:
			var left := maxi(0, int(status["required"]) - int(status["years"]))
			card.add_child(UIKit.label("Pode solicitar naturalização." if bool(status["ready"]) else "Prazo de naturalização na carreira: %d temporada(s) restante(s)." % left, "Small", true))
			if bool(status["ready"]) and w.is_user_club(p.club_id):
				card.add_child(UIKit.button("Solicitar naturalização", "PrimaryButton", func():
					if NationalityManager.naturalize(w, p):
						GameManager.save_now()
						refresh()))
		else:
			card.add_child(UIKit.label("Sem naturalização automática por tempo de clube neste país.", "Small", true))
	for event: Dictionary in p.origin.get("events", []):
		card.add_child(UIKit.label("%d · %s %s" % [int(event["y"]),"Obteve a nacionalidade de" if event["kind"] == "citizenship" else "Escolheu representar",DatabaseManager.nation_name(event["nation"])], "Small", true))
	return UIKit.card_panel(card)


func _career(w: GameWorld, p: Player) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Carreira"))
	var row2 := UIKit.hbox(4)
	row2.add_child(UIKit.stat(str(p.career_apps), "jogos"))
	row2.add_child(UIKit.stat(str(p.career_goals), "gols"))
	row2.add_child(UIKit.stat(str(p.career_assists), "assist."))
	row2.add_child(UIKit.stat(str(p.titles), "títulos"))
	card.add_child(row2)
	if p.career_apps > 0:
		var cx := p.career_extra()
		var row2b := UIKit.hbox(4)
		row2b.add_child(UIKit.stat(Fmt.dec(float(p.career_goals) / p.career_apps, 2), "gols por jogo"))
		row2b.add_child(UIKit.stat(Fmt.dec(float(p.career_goals + p.career_assists) / p.career_apps, 2), "G+A por jogo"))
		row2b.add_child(UIKit.stat(str(int(cx["mo"])), "craque do jogo"))
		if Pos.group(p.position) <= Pos.G_DEF:
			row2b.add_child(UIKit.stat(str(int(cx["cs"])), "sem sofrer gol"))
		card.add_child(row2b)
	var caps := NationalTeamManager.caps_of(w, p.id)
	var nt_titles := NationalTeamManager.player_titles(w, p.id)
	if caps[0] > 0 or NationalTeamManager.is_called(w, p):
		card.add_child(UIKit.section("Carreira internacional"))
		var row3 := UIKit.hbox(4)
		row3.add_child(UIKit.stat(str(caps[0]), "jogos"))
		row3.add_child(UIKit.stat(str(caps[1]), "gols"))
		row3.add_child(UIKit.stat(str(caps[2]), "assist."))
		row3.add_child(UIKit.stat("Sim" if NationalTeamManager.is_called(w, p) else "Não", "convocado", UIColors.GREEN if NationalTeamManager.is_called(w, p) else UIColors.MUTED))
		card.add_child(row3)
		if not nt_titles.is_empty():
			var tf := UIKit.flow(8)
			for t in nt_titles:
				tf.add_child(UIKit.pill("%s %d" % [String(NationalTeamManager.tcfg(t[0]).get("short", t[0])), int(t[1])], UIColors.ACCENT, 16))
			card.add_child(tf)
	if not p.awards.is_empty():
		card.add_child(UIKit.section("Prêmios"))
		var af := UIKit.flow(8)
		for i in range(p.awards.size() - 1, -1, -1):
			var a: Dictionary = p.awards[i]
			var wh := AwardManager.award_where(w, a)
			var where := "" if wh == "" else " · " + wh
			var big := AwardManager.award_weight(String(a["k"])) >= 5
			af.add_child(UIKit.pill("%s %d%s" % [AwardManager.award_name(String(a["k"]), String(a.get("l", ""))), int(a["y"]), where], UIColors.ACCENT if big else UIColors.BLUE, 16))
		card.add_child(af)
	if not p.trophies.is_empty():
		card.add_child(UIKit.section("Títulos"))
		card.add_child(_trophies(w, p))
	if not p.spells.is_empty():
		card.add_child(UIKit.section("Clubes e transferências"))
		var total := 0
		var top := 0
		for sp: Dictionary in p.spells:
			total += int(sp.get("fee", 0))
			top = maxi(top, int(sp.get("fee", 0)))
		if total > 0:
			var fr := UIKit.flow(UITokens.S2)
			fr.add_child(UIKit.stat(Fmt.money(total), "em transferências"))
			fr.add_child(UIKit.stat(Fmt.money(top), "maior valor pago"))
			fr.add_child(UIKit.stat(Fmt.money(p.value), "valor hoje", UIColors.GREEN))
			card.add_child(fr)
		for i in range(p.spells.size() - 1, -1, -1):
			card.add_child(_spell_row(w, p.spells[i], i == p.spells.size() - 1))
	if not p.history.is_empty():
		card.add_child(UIKit.section("Notas por temporada"))
		var chart := EvolutionChart.new()
		chart.custom_minimum_size = Vector2(0, 150)
		chart.setup(p, w.year)
		card.add_child(chart)
		var gsf := ButtonGroup.new()
		var sfr := UIKit.hbox(8)
		for i in 3:
			var fi := i
			var chip := UIKit.chip(["Todas", "Liga", "Outras competições"][i], i == _season_filter, gsf, func():
				_season_filter = fi
				refresh())
			UIKit.shrink_button(chip)
			sfr.add_child(chip)
		card.add_child(sfr)
		card.add_child(_season_header())
		for i in range(p.history.size() - 1, -1, -1):
			card.add_child(_season_row(w, p, p.history[i], i % 2 == 0))
		card.add_child(_season_totals(p))
	return UIKit.card_panel(card)


# --- Temporada a temporada: colunas alinhadas, escudo, nota na escala de cores e chips ---

const SEASON_COLS := [["J", 50], ["G", 50], ["A", 50], ["NOTA", 70]]


func _num_cell(text: String, w: int, col: Color = UIColors.TEXT, variation := "H3") -> Label:
	var l := UIKit.colored(text, col, variation)
	l.custom_minimum_size.x = w
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## J, G, A e se a nota vale, conforme o filtro (a nota guardada é a da liga).
func _season_nums(h: Dictionary) -> Array:
	var la := int(h.get("a", 0))
	var lg := int(h.get("g", 0))
	var las := int(h.get("as", 0))
	var ca := int(h.get("ca", 0))
	var cg := int(h.get("cg", 0))
	var cas := int(h.get("cas", 0))
	match _season_filter:
		1:
			return [la, lg, las, true]
		2:
			return [ca, cg, cas, false]
	return [la + ca, lg + cg, las + cas, true]


func _season_header() -> Control:
	if content_width() < 850:
		return UIKit.label("Temporadas", "Small")
	var h := UIKit.hbox(6)
	var a := UIKit.label("TEMPORADA", "Caps")
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	for c in SEASON_COLS:
		h.add_child(_num_cell(String(c[0]), int(c[1]), UIColors.MUTED, "Caps"))
	return h


func _season_row(w: GameWorld, p: Player, h: Dictionary, shade: bool) -> Control:
	var box := UIKit.vbox(4)
	var row := UIKit.hbox(6)
	var compact := content_width() < 850
	var y := UIKit.label(str(h.get("y", "")), "H3")
	y.custom_minimum_size.x = 60
	row.add_child(y)
	var cl := w.club(int(h.get("c", -1))) if int(h.get("c", -1)) >= 0 else null
	if cl != null:
		row.add_child(UIKit.crest(cl, 34))
	var names := UIKit.vbox(0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cn := UIKit.label(String(h.get("cn", "")).replace(" (empr.)", ""), "")
	cn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(cn)
	var sub: Array = []
	var lid := String(h.get("l", ""))
	if lid != "" and DatabaseManager.has_league(lid):
		sub.append(w.league_short(lid))
	if bool(h.get("lo", false)) or String(h.get("cn", "")).ends_with("(empr.)"):
		sub.append("emprestado")
	if not sub.is_empty():
		names.add_child(UIKit.label(" · ".join(sub), "Small"))
	row.add_child(names)
	if compact:
		box.add_child(row)
		row = UIKit.hbox(UITokens.S2)
	var nums := _season_nums(h)
	var apps: int = nums[0]
	var goals: int = nums[1]
	var ast: int = nums[2]
	var rated: bool = nums[3] and int(h.get("a", 0)) > 0
	var dim := UIColors.MUTED
	if compact:
		for value in [[str(apps),"Jogos"],[str(goals),"Gols"],[str(ast),"Assist."],[Fmt.rating(float(h.get("r", 0.0))) if rated else "—","Nota"]]:
			row.add_child(UIKit.stat(value[0], value[1]))
	else:
		row.add_child(_num_cell(str(apps), 50, UIColors.TEXT if apps > 0 else dim))
		row.add_child(_num_cell(str(goals), 50, UIColors.TEXT if goals > 0 else dim))
		row.add_child(_num_cell(str(ast), 50, UIColors.TEXT if ast > 0 else dim))
		var r := float(h.get("r", 0.0))
		row.add_child(_num_cell(Fmt.rating(r) if rated and r > 0.0 else "—", 70, Fmt.match_rating_color(r) if rated and r > 0.0 else dim))
	box.add_child(row)
	# Destaques do ano em chips: prêmios e craque do jogo em dourado, jogos sem sofrer gol em azul,
	# lesões em vermelho (e não tudo na cor do clube, que parecia erro)
	var chips := UIKit.flow(6)
	var gold := Color("#E8C547")
	var yr := int(h.get("y", 0))
	for k in p.awards_in(yr):
		chips.add_child(UIKit.pill(AwardManager.award_name(k), gold, 14))
	if int(h.get("mo", 0)) > 0:
		chips.add_child(UIKit.pill("%d× craque do jogo" % int(h["mo"]), gold, 14))
	if int(h.get("cs", 0)) > 0 and Pos.group(p.position) <= Pos.G_DEF:
		chips.add_child(UIKit.pill(("%d jogo sem sofrer gol" if int(h["cs"]) == 1 else "%d jogos sem sofrer gol") % int(h["cs"]), UIColors.BLUE, 14))
	for inj in h.get("inj", []):
		chips.add_child(UIKit.pill("%s · %d sem." % [String(inj[0]), int(inj[1])], UIColors.RED, 14))
	if chips.get_child_count() > 0:
		box.add_child(UIKit.margin(chips, 66, 0, 0, 0))
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.035) if shade else Color(0, 0, 0, 0)
	st.set_corner_radius_all(8)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	panel.add_theme_stylebox_override(&"panel", st)
	panel.add_child(box)
	return panel


func _season_totals(p: Player) -> Control:
	var apps := 0
	var goals := 0
	var ast := 0
	var rs := 0.0
	var rn := 0
	for h: Dictionary in p.history:
		var nums := _season_nums(h)
		apps += int(nums[0])
		goals += int(nums[1])
		ast += int(nums[2])
		var la := int(h.get("a", 0))
		if bool(nums[3]) and la > 0 and float(h.get("r", 0.0)) > 0.0:
			rs += float(h["r"]) * la
			rn += la
	var row := UIKit.hbox(6)
	var t := UIKit.label("Total · %d temporadas" % p.history.size(), "Caps", true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(_num_cell(str(apps), 50))
	row.add_child(_num_cell(str(goals), 50))
	row.add_child(_num_cell(str(ast), 50))
	var avg := rs / maxf(1.0, rn)
	row.add_child(_num_cell(Fmt.rating(avg) if rn > 0 else "—", 70, Fmt.match_rating_color(avg) if rn > 0 else UIColors.MUTED))
	var v := UIKit.vbox(4)
	v.add_child(UIKit.separator())
	v.add_child(row)
	return v


## Uma passagem: escudo, clube, anos, como chegou (base, compra, sem custo, empréstimo) e números.
func _spell_row(w: GameWorld, s: Dictionary, _current: bool) -> Control:
	var line := UIKit.hbox(10)
	var cl := w.club(int(s.get("c", -1))) if int(s.get("c", -1)) >= 0 else null
	if cl != null:
		line.add_child(UIKit.crest(cl, 40))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var to := int(s.get("to", 0))
	var from := int(s.get("from", 0))
	var years := ("%d–%s" % [from, str(to) if to > 0 else "hoje"]) if to != from else str(to)
	var name_l := UIKit.label(String(s.get("cn", "?")).replace(" (empr.)", ""), "H3")
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(name_l)
	col.add_child(UIKit.label("%s · %d jogos · %d gols" % [years, int(s.get("a", 0)), int(s.get("g", 0))], "Small", true))
	line.add_child(col)
	var k := String(s.get("k", ""))
	if k == "" and (bool(s.get("lo", false)) or String(s.get("cn", "")).ends_with("(empr.)")):
		k = "e"
	match k:
		"b":
			line.add_child(UIKit.pill("BASE", UIColors.GREEN, 15))
		"e":
			line.add_child(UIKit.pill("EMPRÉSTIMO", UIColors.BLUE, 15))
		"l":
			line.add_child(UIKit.pill("SEM CUSTO", UIColors.MUTED, 15))
		"c":
			line.add_child(UIKit.pill(Fmt.money(int(s.get("fee", 0))), UIColors.ACCENT, 15))
	if cl != null:
		var ccid := cl.id
		return UIKit.tap_row(line, func(): UIManager.push("club", {"id": ccid}), "CardFlat")
	return line


## Football Memory: os fatos que definem a carreira e a linha do tempo, ano a ano.
func _memory(w: GameWorld, p: Player) -> Control:
	var tl := FootballMemory.timeline(w, p)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Linha do tempo"))
	card.add_child(UIKit.label("%s, %d anos" % [p.display_name(), p.age(w.year)], "H3"))
	for f: String in tl["facts"]:
		card.add_child(UIKit.colored(f, UIColors.ACCENT, "Small", true))
	card.add_child(UIKit.separator())
	var events: Array = tl["events"]
	var start := maxi(0, events.size() - 30)
	var last_y := -1
	for i in range(start, events.size()):
		var e: Dictionary = events[i]
		var row := UIKit.hbox(10)
		var y := int(e["y"])
		var yl := UIKit.label(str(y) if y != last_y else "", "H3")
		yl.custom_minimum_size.x = 64
		row.add_child(yl)
		last_y = y
		var t := UIKit.label(String(e["t"]), "", true)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if String(e["k"]) in ["title", "goal", "record"]:
			t.add_theme_color_override(&"font_color", UIColors.ACCENT)
		row.add_child(t)
		card.add_child(row)
	return UIKit.card_panel(card)


## Estante do jogador: cada título com o troféu, quantas vezes e em que anos.
func _trophies(w: GameWorld, p: Player) -> Control:
	var groups := {} # chave -> [anos]
	for t: Dictionary in p.trophies:
		var k := String(t.get("k", ""))
		if not groups.has(k):
			groups[k] = []
		groups[k].append(int(t.get("y", 0)))
	var keys: Array = groups.keys()
	keys.sort_custom(func(a, b):
		var ra := _trophy_rank(a)
		var rb := _trophy_rank(b)
		return ra < rb if ra != rb else groups[a].size() > groups[b].size())
	var box := UIKit.vbox(6)
	for k: String in keys:
		var ys: Array = groups[k]
		ys.sort()
		var row := UIKit.hbox(10)
		var name := ""
		if k.begins_with("N:"):
			name = NationalTeamManager.tournament_name(k.substr(2))
		else:
			row.add_child(TrophyView.make(k, 40, w))
			name = TrophyView.trophy_name(k, w)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(("%d× " % ys.size() if ys.size() > 1 else "") + name, "H3", true))
		col.add_child(UIKit.label(", ".join(ys.map(func(y): return str(y))), "Small", true))
		row.add_child(col)
		box.add_child(row)
	return box


## Ordem da estante: seleção, mundial, continentais, ligas (pela divisão), estaduais.
static func _trophy_rank(k: String) -> int:
	match k.substr(0, 2):
		"N:":
			return -1
		"W:":
			return 0
		"C:":
			return 1
		"D:":
			return 7
		"S:":
			return 8
		"U:":
			return 9
		"L:":
			return 2 + int(DatabaseManager.league_cfg(k.substr(2)).get("tier", 1))
	return 10


## Ações do jogador dentro do cabeçalho (sem rodapé fixo ocupando a tela): a principal em
## giz e as outras num menu.
var _acts: VBoxContainer = null


func _actions(w: GameWorld, p: Player, own: bool) -> void:
	var f := _acts
	if f == null:
		return
	UIKit.clear(f)
	var refresh_cb := func(): refresh()
	if w.academy.has(p.id):
		var arow := UIKit.hbox(10)
		var up := UIKit.button("SUBIR AO PROFISSIONAL", "PrimaryButton", func():
			UIManager.toast(YouthManager.promote(w, p))
			GameManager.save_now()
			refresh(), "up")
		up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arow.add_child(up)
		if Store.career_edit_on():
			arow.add_child(UIKit.button("Editar", "", func(): UIManager.push("editor", {"player": p.id}), "gear"))
		f.add_child(arow)
		return
	if own and not p.loan.is_empty():
		var owner := w.club(int(p.loan.get("from", -1)))
		f.add_child(UIKit.label("Emprestado pelo %s." % (owner.short_name if owner != null else "clube"), "Small", true))
		if p.loan.has("opt"):
			var opt_price := int(p.loan["opt"])
			var obl := bool(p.loan.get("obl", false))
			f.add_child(UIKit.label(("Obrigação de compra por %s se fizer %d jogos (tem %d)." % [Fmt.money(opt_price), DealTerms.OBLIGATION_APPS, DealTerms.season_apps(p)]) if obl else ("Opção de compra: %s." % Fmt.money(opt_price)), "Small", true))
			if not obl:
				f.add_child(UIKit.button("EXERCER OPÇÃO (%s)" % Fmt.money(opt_price), "PrimaryButton", func():
					UIManager.confirm("Comprar %s?" % p.display_name(), "Você paga %s ao %s e ele fica em definitivo, com o salário atual." % [Fmt.money(opt_price), owner.short_name if owner != null else "clube"], "Comprar", func():
						var r := DealTerms.exercise_option(w, p)
						UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] else UIColors.RED)
						if r["ok"]:
							Sfx.play("sign")
							GameManager.save_now()
						refresh()), "check"))
		var tb := UIKit.button("Treino individual", "", func(): TrainingSheet.open(p, refresh_cb), "tactics")
		f.add_child(tb)
		return
	if not own and not p.loan.is_empty() and w.is_user_club(int(p.loan.get("from", -1))):
		f.add_child(UIKit.label("Emprestado até o fim da temporada.", "Small", true))
		return
	if own:
		# Uma ação principal (contrato) e o resto num menu: treino, venda, empréstimo, rescisão.
		var row := UIKit.hbox(10)
		var neg := UIKit.button("Renovar contrato", "PrimaryButton", func(): Negotiation.open(w, p, "renew", refresh_cb))
		neg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		neg.custom_minimum_size.y = UITokens.H_BUTTON
		row.add_child(neg)
		row.add_child(UIKit.button("Treino", "GhostButton", func(): TrainingSheet.open(p, refresh_cb)))
		var more := UIKit.icon_button("menu", func(): _more_sheet(w, p, refresh_cb), "Mais ações")
		more.theme_type_variation = "GhostButton"
		more.custom_minimum_size = Vector2(UITokens.H_BUTTON, UITokens.H_BUTTON)
		row.add_child(more)
		f.add_child(row)
	elif p.club_id < 0:
		f.add_child(UIKit.button("CONTRATAR (LIVRE)", "PrimaryButton", func(): Negotiation.open(w, p, "free", refresh_cb), "check"))
	else:
		var bb := DealTerms.buyback_of(w, p)
		if not bb.is_empty():
			var bbb := UIKit.button("RECOMPRAR POR %s" % Fmt.money(int(bb["price"])), "PrimaryButton", func(): Negotiation.open(w, p, "buyback", refresh_cb), "money")
			bbb.disabled = not w.transfer_window_open()
			f.add_child(bbb)
			f.add_child(UIKit.label("Cláusula de recompra válida até %d: o clube dele não pode recusar." % int(bb["until"]), "Small", true))
		var b := UIKit.button("FAZER PROPOSTA", "PrimaryButton", func(): Negotiation.open(w, p, "buy", refresh_cb), "swap")
		if not w.transfer_window_open():
			b.disabled = true
			b.text = "JANELA FECHADA"
		f.add_child(b)
		# Fim de contrato: pré-contrato (chega de graça no fim da temporada)
		var pre := TransferManager.precontract_of(w, p)
		if not pre.is_empty():
			var pc := w.club(int(pre.get("club", -1)))
			f.add_child(UIKit.label("Assinou pré-contrato com o %s." % (pc.short_name if pc != null else "?"), "Small", true))
		elif TransferManager.precontract_block(w, p, w.user_club()) == "":
			f.add_child(UIKit.button("PROPOR PRÉ-CONTRATO", "GhostButton", func(): Negotiation.open(w, p, "pre", refresh_cb), "clock"))


## Menu de ações do próprio jogador (fora a principal). Abre o que já existia, sem modal
## sobre modal: a folha fecha antes de abrir a negociação ou a confirmação.
func _more_sheet(w: GameWorld, p: Player, refresh_cb: Callable) -> void:
	var v := UIKit.vbox(0)
	v.add_child(UIKit.label(p.display_name(), "H2"))
	v.add_child(UIKit.gap(8))
	var items: Array = []
	items.append(["Comparar com outro jogador", func(): UIManager.push("compare", {"a": p.id}), false])
	if p.transfer_listed:
		items.append(["Tirar da lista de venda", func():
			p.transfer_listed = false
			p.asking_price = 0
			UIManager.toast("%s não está mais à venda." % p.display_name())
			refresh(), false])
	else:
		items.append(["Pôr à venda", func(): Negotiation.open(w, p, "sell", refresh_cb), false])
	items.append(["Emprestar", func(): _loan_sheet(w, p), false])
	if Store.career_edit_on():
		items.append(["Editar jogador", func(): UIManager.push("editor", {"player": p.id}), false])
	items.append(["Rescindir contrato", func():
		var cost := TransferManager.release_cost(w, p)
		UIManager.confirm("Rescindir com %s?" % p.display_name(), "Multa rescisória: %s (metade dos salários restantes). Ele sai do clube imediatamente." % Fmt.money(cost), "Rescindir", func():
			TransferManager.release(w, p)
			UIManager.toast("%s não é mais jogador do clube." % p.display_name())
			UIManager.back()), true])
	for it in items:
		var l := UIKit.label(String(it[0]))
		if bool(it[2]):
			l.add_theme_color_override(&"font_color", UIColors.RED)
		var cb: Callable = it[1]
		var row := UIKit.tap_row(l, func():
			UIManager.close_modal()
			cb.call())
		row.custom_minimum_size.y = 72
		v.add_child(row)
	UIManager.show_modal(v, true)


## Empréstimo de um jogador do elenco: simples, com opção ou com obrigação de compra.
func _loan_sheet(w: GameWorld, p: Player) -> void:
	var v := UIKit.vbox(12)
	var head := UIKit.hbox(8)
	var t := UIKit.label("Emprestar %s" % p.display_name(), "Title", true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(UIKit.icon_button("close", func(): UIManager.close_modal()))
	v.add_child(head)
	v.add_child(UIKit.label("Ele vai para um clube onde deve jogar mais, até o fim da temporada. O salário fica por conta do outro clube.", "Small", true))
	var price := DealTerms.loan_option_price(w, p)
	for opt in [["", "Empréstimo simples", "Volta no fim da temporada."],
			["opt", "Com opção de compra", "O clube pode comprá-lo por %s no fim, se gostar." % Fmt.money(price)],
			["obl", "Com obrigação de compra", "Se fizer %d jogos, a venda por %s é automática." % [DealTerms.OBLIGATION_APPS, Fmt.money(price)]]]:
		var kind: String = opt[0]
		var col := UIKit.vbox(2)
		col.add_child(UIKit.label(String(opt[1]), "H3"))
		col.add_child(UIKit.label(String(opt[2]), "Small", true))
		v.add_child(UIKit.tap_row(col, func():
			UIManager.close_modal()
			var r := TransferManager.loan_out(w, p, kind)
			UIManager.toast(r["msg"], UIColors.GREEN if r["ok"] else UIColors.RED)
			if r["ok"]:
				GameManager.save_now()
				UIManager.back()))
	UIManager.show_modal(v, true)


## Botão compacto do rodapé: ícone em cima e o nome curto embaixo.
func _act(text: String, icon_name: String, cb: Callable, variation: String = "") -> Button:
	var b := UIKit.button(text, variation, cb, icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", 18)
	b.add_theme_constant_override(&"h_separation", 2)
	b.clip_text = true
	return b


func color_context() -> Dictionary:
	var w := GameManager.world
	var p := w.player(_pid) if w != null else null
	return club_context(p.club_id) if p != null else {}
