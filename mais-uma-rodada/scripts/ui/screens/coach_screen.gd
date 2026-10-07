class_name CoachScreen
extends BaseScreen
## Perfil de um técnico da IA: rosto (de terno, com as cores do clube), estilo, nível, trabalho
## atual, segurança no cargo e a relação com você. Dá para puxar conversa daqui.
## Também mostra a carreira inteira (clubes, campanhas, títulos, como saiu) e abre técnicos livres.

var _club := -1
var _coach := -1
var _tab := "profile"


func _init() -> void:
	screen_title = "Técnico"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club = int(p.get("club", -1))
	_coach = int(p.get("coach", -1))


## Rosto fixo por técnico: semente e origem derivadas do id (nada é salvo a mais).
static func portrait(world: GameWorld, co: Dictionary, club: Club, px: int) -> PortraitView:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "coach", int(co.get("id", 0))])
	var origin := NameGenerator.pick_origin(rng, String(co.get("nat", "BRA")))
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_person(rng.randi() & 0x7FFFFFFF, int(origin["eth"]), world.year - int(co.get("by", world.year - 50)), club)
	UIKit.portrait_ground(v, club) # mesmo quadro dos retratos dos jogadores
	return v


## Foto de coletiva do técnico (PhotoPortrait), mesmo rosto do retrato.
static func photo(world: GameWorld, co: Dictionary, club: Club, px: Vector2) -> PhotoPortrait:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "coach", int(co.get("id", 0))])
	var origin := NameGenerator.pick_origin(rng, String(co.get("nat", "BRA")))
	var ph := PhotoPortrait.new()
	ph.custom_minimum_size = px
	ph.mood = PhotoPortrait.for_moment("tecnico")
	ph.set_person(rng.randi() & 0x7FFFFFFF, int(origin["eth"]), world.year - int(co.get("by", world.year - 50)), club)
	return ph


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var co: Dictionary = {}
	var club: Club = null
	if _coach >= 0:
		co = CoachCareer.find(w, _coach)
		club = w.club(int(co.get("c", -1))) if not co.is_empty() else null
		if club != null and w.is_user_club(club.id):
			club = null
	else:
		club = w.club(_club)
		co = People.coach_of(w, _club) if club != null else {}
	var c := content()
	UIKit.clear(c)
	var f := footer()
	UIKit.clear(f)
	if co.is_empty():
		c.add_child(UIKit.label("Esse técnico não está mais no futebol." if _coach >= 0 else "Sem técnico no momento.", "Muted"))
		return
	screen_title = String(co["n"])
	screen_subtitle = club.short_name if club != null else "Sem clube"
	UIManager.refresh_chrome()
	c.add_child(_hero(w, co, club))
	c.add_child(UIKit.tabs([["profile", "Perfil"], ["career", "Carreira"]], _tab, func(key: String):
		_tab = key
		refresh()))
	if _tab == "profile":
		if club != null:
			c.add_child(_work(w, co, club))
		c.add_child(_style_card(w, co))
		c.add_child(_school_card(w, co))
	else:
		c.add_child(_career(w, co))
		c.add_child(_stories(w, co))
	max_content_width = 1600
	columnize(c, 2, 2, 0)
	if club != null:
		var cid := club.id
		f.add_child(UIKit.button("Conversar", "PrimaryButton", func(): TalkDialog.open("coach", cid, func(): refresh()), "mail"))


func _hero(w: GameWorld, co: Dictionary, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(16)
	row.add_child(photo(w, co, club, Vector2(150, 150)))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(String(co["n"]), "Title", true))
	var nrow := UIKit.hbox(8)
	nrow.add_child(UIKit.flag(String(co["nat"]), 34))
	nrow.add_child(UIKit.label("%s · %d anos" % [DatabaseManager.nation_name(String(co["nat"])), w.year - int(co.get("by", w.year - 50))], "Small", true))
	col.add_child(nrow)
	if club != null and w.is_user_club(club.id) and not bool(co.get("int", false)):
		col.add_child(UIKit.label(Languages.coach_text(w), "Small", true))
	var pills := UIKit.flow(6)
	pills.add_child(UIKit.pill(People.style_name(String(co["st"])).to_upper(), UIColors.ACCENT, 16))
	pills.add_child(UIKit.pill(CoachStories.temper_name(w, co).to_upper(), UIColors.BLUE, 16))
	col.add_child(pills)
	var nick := CoachStories.nickname(w, co)
	if nick != "":
		col.add_child(UIKit.colored("\"%s\"" % nick, UIColors.ACCENT, "H3", true))
	var crow := UIKit.hbox(8)
	if club != null:
		crow.add_child(UIKit.crest(club, 30))
		var role := "Interino" if bool(co.get("int", false)) else "Técnico"
		crow.add_child(UIKit.label("%s do %s desde %d" % [role, club.short_name, int(co.get("since", w.year))], "Small", true))
	else:
		var car: Array = co.get("car", [])
		var last := int(car.back().get("to", 0)) if not car.is_empty() else 0
		crow.add_child(UIKit.label("Sem clube" + (" desde %d" % last if last > 0 else ""), "Small", true))
	col.add_child(crow)
	row.add_child(col)
	card.add_child(row)
	return HeroBackdrop.attach(UIKit.card_panel(card), club)


func _work(w: GameWorld, co: Dictionary, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Trabalho"))
	var row := UIKit.hbox(4)
	var games := int(co.get("w", 0)) + int(co.get("d", 0)) + int(co.get("l", 0))
	row.add_child(UIKit.stat("%d-%d-%d" % [int(co.get("w", 0)), int(co.get("d", 0)), int(co.get("l", 0))], "V-E-D"))
	row.add_child(UIKit.stat("%d%%" % int(round(100.0 * (int(co.get("w", 0)) * 3 + int(co.get("d", 0))) / maxf(1.0, games * 3.0))) if games > 0 else "—", "aproveitamento"))
	row.add_child(UIKit.stat(_stars(float(co.get("sk", 50.0))), "nível"))
	row.add_child(UIKit.stat(Reputation.label(float(co.get("rep", 50.0))), "reputação"))
	card.add_child(row)
	var job := float(co.get("job", 60.0))
	var jl := "Prestigiado" if job >= 75.0 else ("Estável" if job >= 50.0 else ("Pressionado" if job >= 30.0 else "Cargo balançando"))
	var jc := UIColors.GREEN if job >= 50.0 else (UIColors.ORANGE if job >= 30.0 else UIColors.RED)
	card.add_child(UIKit.kv("Situação no cargo", jl, jc))
	var bar := UIKit.bar(job, 100.0, jc, 10)
	card.add_child(bar)
	if int(co.get("ct", 0)) > 0 and not bool(co.get("int", false)):
		card.add_child(UIKit.kv("Contrato", "até o fim de %d" % int(co["ct"])))
	var fired := int(co.get("fired", 0))
	if fired > 0:
		card.add_child(UIKit.kv("Demissões na carreira", str(fired)))
	var vs := CoachStories.vs_user(co)
	if int(vs[0]) + int(vs[1]) + int(vs[2]) > 0:
		var tone := UIColors.GREEN if int(vs[0]) > int(vs[2]) else (UIColors.RED if int(vs[2]) > int(vs[0]) else UIColors.TEXT)
		card.add_child(UIKit.kv("Você contra ele", "%dV %dE %dD" % [int(vs[0]), int(vs[1]), int(vs[2])], tone))
	var rel := People.coach_rel(w, int(co["id"]))
	card.add_child(UIKit.kv("Relação com você", People.coach_rel_label(rel), UIColors.GREEN if rel >= 12.0 else (UIColors.RED if rel <= -12.0 else UIColors.MUTED)))
	if club.sheet != null:
		var tac := DatabaseManager.tactics()
		card.add_child(UIKit.kv("Time-base", "%s · %s" % [club.sheet.formation, String(tac["styles"][club.sheet.style]["name"])]))
	var h2h := FootballMemory.head_to_head(w, w.user_club_id, club.id) if w.has_user() and not w.is_user_club(club.id) else {}
	if int(h2h.get("games", 0)) > 0:
		card.add_child(UIKit.kv("Seu retrospecto contra o %s" % club.short_name, FootballMemory.h2h_line(h2h)))
	return UIKit.card_panel(card)


func _style_card(w: GameWorld, co: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	var st: Dictionary = People.COACH_STYLES.get(String(co["st"]), {})
	card.add_child(UIKit.section("Estilo de trabalho"))
	card.add_child(UIKit.label(String(st.get("name", "")), "H3"))
	card.add_child(UIKit.label("Temperamento: " + CoachStories.temper_name(w, co), "H3"))
	return UIKit.card_panel(card)


## Escola do técnico: de quem aprendeu, o jeito de jogar (traços) e quem aprendeu com ele.
func _school_card(w: GameWorld, co: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Escola"))
	var s := CoachSchools.school_of(w, co)
	if not s.is_empty():
		var sid := int(s["id"])
		var b := UIKit.button(String(s["n"]), "ChipButton", func(): UIManager.push("coach_schools", {"school": sid}), "star")
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		card.add_child(b)
		if int(s["f"]) == int(co.get("id", -1)):
			card.add_child(UIKit.label("Fundador da escola, em %d." % int(s["y"]), "Small", true))
	else:
		card.add_child(UIKit.label("Sem escola: jeito próprio.", "Small", true))
	var mt := int(co.get("mt", 0))
	if mt == -2:
		card.add_child(UIKit.kv("Aprendeu com", w.manager_name, UIColors.ACCENT))
	elif mt > 0:
		var m := CoachCareer.find(w, mt)
		var mn := String(m.get("n", ""))
		if mn == "":
			for e in s.get("e", []):
				if int(e[0]) == mt:
					mn = String(e[1])
					break
		if mn != "":
			card.add_child(UIKit.kv("Aprendeu com", mn))
	var pills := UIKit.flow(6)
	for n in CoachSchools.trait_names(co.get("tr", [])):
		pills.add_child(UIKit.pill(String(n), UIColors.ACCENT, 18))
	card.add_child(pills)
	var ds := CoachSchools.disciples(w, int(co.get("id", 0)))
	if not ds.is_empty():
		var names: Array = []
		for d: Dictionary in ds.slice(0, 5):
			names.append(String(d["n"]))
		card.add_child(UIKit.kv("Discípulos", ", ".join(PackedStringArray(names)) + (" e mais %d" % (ds.size() - 5) if ds.size() > 5 else "")))
	return UIKit.card_panel(card)


## A história do técnico: o arco em andamento, o que a carreira justifica e os momentos marcantes.
func _stories(w: GameWorld, co: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("História"))
	var arc := CoachStories.arc_text(co)
	if arc != "":
		card.add_child(UIKit.colored(arc, UIColors.ORANGE, "H3", true))
	var ls := CoachStories.labels(w, co)
	if not ls.is_empty():
		var fl := UIKit.flow(6)
		for l in ls.slice(0, 4):
			fl.add_child(UIKit.pill(String(l["n"]).to_upper(), UIColors.ACCENT, 13))
		card.add_child(fl)
	var aw: Array = co.get("aw", [])
	for a in aw:
		var what := "Treinador do ano" if String(a[1]) == "coach_world" else "Treinador da temporada (%s)" % w.league_short(String(a[2]))
		card.add_child(UIKit.colored("%d · %s" % [int(a[0]), what], UIColors.ACCENT, "Small", true))
	var tl := CoachStories.moments(co)
	for i in range(tl.size() - 1, -1, -1):
		card.add_child(UIKit.label("%d · %s" % [int(tl[i]["y"]), String(tl[i]["t"])], "Small", true))
	if arc == "" and ls.is_empty() and aw.is_empty() and tl.is_empty():
		card.add_child(UIKit.label("Ainda sem capítulos marcantes.", "Muted", true))
	return UIKit.card_panel(card)


## Carreira: números somados, passado de jogador e cada trabalho (do mais recente ao primeiro).
func _career(w: GameWorld, co: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Carreira"))
	var t := CoachCareer.totals(co)
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(int(t["g"])), "jogos"))
	var pct := int(round(100.0 * (int(t["w"]) * 3 + int(t["d"])) / maxf(1.0, int(t["g"]) * 3.0)))
	row.add_child(UIKit.stat(("%d%%" % pct) if int(t["g"]) > 0 else "—", "aproveit."))
	row.add_child(UIKit.stat(str(int(t["t"])), "títulos", UIColors.ACCENT if int(t["t"]) > 0 else UIColors.TEXT))
	row.add_child(UIKit.stat(str(int(t["clubs"])), "clubes"))
	card.add_child(row)
	if int(t["dem"]) > 0:
		card.add_child(UIKit.kv("Demissões", str(int(t["dem"]))))
	if int(co.get("pid", -1)) >= 0:
		var pid := int(co["pid"])
		card.add_child(UIKit.tap_row(UIKit.label("Ex-jogador · ver carreira", "Small", true), func(): UIManager.push("player", {"id": pid}), "CardFlat"))
	else:
		card.add_child(UIKit.label(CoachCareer.player_text(co), "Small", true))
	var car: Array = co.get("car", [])
	if car.is_empty():
		card.add_child(UIKit.label("Primeiro trabalho como técnico.", "Muted"))
	for i in range(car.size() - 1, -1, -1):
		card.add_child(_spell_row(w, car[i]))
	return UIKit.card_panel(card)


func _spell_row(w: GameWorld, sp: Dictionary) -> Control:
	var line := UIKit.hbox(10)
	var cl := w.club(int(sp.get("c", -1)))
	if cl != null:
		line.add_child(UIKit.crest(cl, 38))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var to := int(sp.get("to", 0))
	var from := int(sp.get("from", 0))
	var years := ("%d–%s" % [from, str(to) if to > 0 else "hoje"]) if to != from else str(from)
	var nl := UIKit.label(String(sp.get("cn", "?")), "H3")
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nl)
	var parts: Array = [years, CoachCareer.role_text(sp)]
	var k := String(sp.get("k", ""))
	var games := int(sp.get("w", 0)) + int(sp.get("d", 0)) + int(sp.get("l", 0))
	if to == 0 and k != "aux" and k != "base":
		var co := CoachCareer.find(w, _coach) if _coach >= 0 else People.coach_of(w, _club)
		games += int(co.get("w", 0)) + int(co.get("d", 0)) + int(co.get("l", 0))
		parts.append("%dV %dE %dD" % [int(sp["w"]) + int(co.get("w", 0)), int(sp["d"]) + int(co.get("d", 0)), int(sp["l"]) + int(co.get("l", 0))])
	elif games > 0:
		parts.append("%dV %dE %dD" % [int(sp["w"]), int(sp["d"]), int(sp["l"])])
	col.add_child(UIKit.label(" · ".join(parts), "Small", true))
	var titles: Array = sp.get("t", [])
	if not titles.is_empty():
		var names: Array = []
		for key in titles:
			names.append(TrophyView.trophy_name(String(key), w))
		col.add_child(UIKit.colored("Títulos: " + ", ".join(names), UIColors.ACCENT, "Small", true))
	line.add_child(col)
	var end := CoachCareer.end_text(sp)
	if end != "":
		var e := String(sp.get("e", ""))
		var tone := UIColors.RED if e == "dem" else (UIColors.GREEN if e in ["sai", "prom"] else UIColors.MUTED)
		line.add_child(UIKit.pill(end.to_upper(), tone, 13))
	if cl != null:
		var ccid := cl.id
		return UIKit.tap_row(line, func(): UIManager.push("club", {"id": ccid}), "CardFlat")
	return line


static func _stars(sk: float) -> String:
	var n := clampi(int(round((sk - 20.0) / 15.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)


func color_context() -> Dictionary:
	return club_context(_club)
