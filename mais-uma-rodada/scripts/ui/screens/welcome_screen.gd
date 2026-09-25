extends BaseScreen
## Apresentação ao assumir o clube: quem é o clube, o que a diretoria espera, o jeito da torcida,
## as particularidades (filosofia, base, finanças, rival) e o elenco que você herda — as estrelas,
## o capitão, as promessas, os veteranos e onde o time é mais fraco.
## Abre depois de começar a carreira e também pela página do clube.

const FAM_NAMES := ["goleiro", "zagueiro", "lateral", "volante/meia central", "meia/ponta", "centroavante"]


func _init() -> void:
	show_nav = false
	screen_title = "Bem-vindo"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	screen_subtitle = club.name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_hero(w, club))
	c.add_child(_expectations(w, club))
	c.add_child(_traits(w, club))
	c.add_child(_squad(w, club))
	_footer(w)


func _hero(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	var row := UIKit.hbox(16)
	row.add_child(UIKit.crest(club, 140))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Bem-vindo ao", "Small"))
	col.add_child(UIKit.label(club.name, "Title", true))
	if club.nickname != "":
		col.add_child(UIKit.label("\"%s\"" % club.nickname, "Accent"))
	var place := UIKit.hbox(8)
	place.add_child(UIKit.flag(club.nation, 30))
	place.add_child(UIKit.label("%s · desde %d" % [club.city, club.founded], "Small", true))
	col.add_child(place)
	var stars := StarsView.new()
	stars.star_size = 22.0
	stars.stars = clampf(club.reputation / 20.0, 0.5, 5.0)
	col.add_child(stars)
	row.add_child(col)
	card.add_child(row)
	card.add_child(UIKit.label("%s, treinador do %s. %s lugares no %s, uma torcida de %s e uma história para honrar." % [
		w.manager_name, club.short_name, Fmt.thousands(club.capacity), club.stadium, _fans_text(club)], "", true))
	return HeroBackdrop.attach(UIKit.card_panel(card), club)


func _fans_text(club: Club) -> String:
	if club.fan_base >= 20000000:
		return "dezenas de milhões"
	if club.fan_base >= 3000000:
		return "milhões de apaixonados"
	if club.fan_base >= 500000:
		return "centenas de milhares"
	return "fiéis de bairro"


func _expectations(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("O que esperam de você"))
	var goal := SeasonManager.goal_of(w, club.id)
	card.add_child(UIKit.kv("Meta da diretoria", String(goal[0])))
	var pr := People.president(w, club.id)
	if not pr.is_empty():
		var st := People.pres_style(w, club.id)
		card.add_child(UIKit.kv("Presidente", "%s · %s" % [String(pr.get("n", "")), String(st.get("name", ""))]))
		card.add_child(UIKit.label(String(st.get("desc", "")), "Small", true))
	card.add_child(UIKit.kv("Verba para contratações", Fmt.money(club.transfer_budget)))
	card.add_child(UIKit.kv("Teto salarial", "%s/mês" % Fmt.money(club.wage_budget)))
	card.add_child(UIKit.kv("Finanças", FinanceManager.health_label(w, club)))
	var rival := w.club(club.main_rival())
	if rival != null:
		var rr := UIKit.hbox(10)
		rr.add_child(UIKit.crest(rival, 40))
		var rc := UIKit.vbox(0)
		rc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rc.add_child(UIKit.label("Maior rival", "Caps"))
		rc.add_child(UIKit.label("%s — vencer o clássico vale mais que três pontos para a torcida." % rival.name, "Small", true))
		rr.add_child(rc)
		card.add_child(rr)
	return UIKit.card_panel(card)


func _traits(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Particularidades do clube"))
	var arch := club.arch()
	var tags := UIKit.flow(8)
	tags.add_child(UIKit.pill(String(arch.get("tag", "")).to_upper(), UIColors.ACCENT, 16))
	if club.youth_level >= 75:
		tags.add_child(UIKit.pill("BASE FORTE", UIColors.GREEN, 16))
	if club.facilities >= 75:
		tags.add_child(UIKit.pill("CT DE PONTA", UIColors.BLUE, 16))
	if club.capacity >= 60000:
		tags.add_child(UIKit.pill("CALDEIRÃO", UIColors.RED, 16))
	if club.balance < 0:
		tags.add_child(UIKit.pill("ENDIVIDADO", UIColors.ORANGE, 16))
	card.add_child(tags)
	if arch.has("desc"):
		card.add_child(UIKit.label(String(arch["desc"]), "Small", true))
	var pol := ClubPolicy.of(club)
	if not pol.is_empty():
		card.add_child(UIKit.label("Filosofia: %s" % String(pol.get("name", "")), "H3", true))
		card.add_child(UIKit.label(String(pol.get("desc", "")), "Small", true))
	card.add_child(UIKit.kv("Categorias de base", "%d/100" % club.youth_level))
	card.add_child(UIKit.kv("Centro de treinamento", "%d/100" % club.facilities))
	var patience := float(arch.get("fan_patience", 50))
	card.add_child(UIKit.label("Torcida %s." % ("exigente: não perdoa sequência ruim" if patience < 40 else ("paciente com trabalho a longo prazo" if patience > 60 else "apaixonada, cobra mas apoia")), "Small", true))
	return UIKit.card_panel(card)


func _squad(w: GameWorld, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	var squad := w.squad(club)
	var n := squad.size()
	var age_sum := 0
	var foreign := 0
	for p: Player in squad:
		age_sum += p.age(w.year)
		if p.nationality != club.nation:
			foreign += 1
	card.add_child(UIKit.section("O elenco que você herda"))
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(n), "jogadores"))
	row.add_child(UIKit.stat("%.1f" % (float(age_sum) / maxf(1.0, n)), "idade média"))
	row.add_child(UIKit.stat(str(foreign), "estrangeiros"))
	var sheet := club.sheet
	row.add_child(UIKit.stat(sheet.formation if sheet != null else "—", "formação"))
	card.add_child(row)
	var by_ovr := squad.duplicate()
	by_ovr.sort_custom(func(a: Player, b: Player): return a.overall > b.overall if a.overall != b.overall else a.id < b.id)
	card.add_child(UIKit.label("Estrelas do time", "Caps"))
	for i in mini(3, by_ovr.size()):
		card.add_child(_player_line(w, club, by_ovr[i], _star_note(w, by_ovr[i])))
	var young: Player = null
	var vet: Player = null
	for p: Player in by_ovr:
		var a := p.age(w.year)
		if a <= 21 and (young == null or p.potential_estimate(0.8) > young.potential_estimate(0.8)):
			young = p
		if a >= 31 and (vet == null or p.career_apps > vet.career_apps):
			vet = p
	if young != null:
		card.add_child(UIKit.label("A promessa", "Caps"))
		card.add_child(_player_line(w, club, young, "%d anos · %s" % [young.age(w.year), Player.potential_label(young.potential_estimate(0.8))]))
	if vet != null:
		card.add_child(UIKit.label("A voz da experiência", "Caps"))
		card.add_child(_player_line(w, club, vet, "%d anos · %d jogos na carreira" % [vet.age(w.year), vet.career_apps]))
	var needs := TransferManager.squad_needs(w, club)
	if not needs.is_empty():
		var weak: Array = []
		for nd in needs.slice(0, 2):
			weak.append(FAM_NAMES[int(nd["fam"])])
		card.add_child(UIKit.colored("Carência: o elenco pede reforço de %s." % " e ".join(PackedStringArray(weak)), UIColors.ORANGE, "Small", true))
	else:
		card.add_child(UIKit.colored("Elenco equilibrado: nenhuma posição urgente.", UIColors.GREEN, "Small", true))
	return UIKit.card_panel(card)


func _star_note(w: GameWorld, p: Player) -> String:
	var bits: Array = ["%s · %d anos" % [Pos.name_of(p.position), p.age(w.year)]]
	for t in p.traits.slice(0, 1):
		bits.append(String(DatabaseManager.trait_data(t).get("name", t)).to_lower())
	if p.contract_years_left(w.year) <= 1:
		bits.append("contrato acabando")
	return " · ".join(PackedStringArray(bits))


func _player_line(w: GameWorld, club: Club, p: Player, note: String) -> Control:
	var row := UIKit.hbox(10)
	row.add_child(UIKit.portrait(p, club, w.year, 60))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nl := UIKit.label(p.display_name(), "H3")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nl)
	col.add_child(UIKit.label(note, "Small", true))
	row.add_child(col)
	row.add_child(UIKit.badge(p.overall, 52, 38, 22))
	var pid := p.id
	return UIKit.tap_row(row, func(): UIManager.push("player", {"id": pid}))


func _footer(w: GameWorld) -> void:
	var f := footer()
	UIKit.clear(f)
	var row := UIKit.hbox(10)
	var mb := UIKit.button("Seu treinador", "GhostButton", func(): UIManager.push("manager"), "star")
	mb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mb)
	var go := UIKit.button("COMEÇAR", "PrimaryButton", func(): UIManager.goto("hub"), "forward")
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(go)
	f.add_child(row)
