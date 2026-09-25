class_name CoachScreen
extends BaseScreen
## Perfil de um técnico da IA: rosto (de terno, com as cores do clube), estilo, nível, trabalho
## atual, segurança no cargo e a relação com você. Dá para puxar conversa daqui.

var _club := -1


func _init() -> void:
	show_nav = false
	screen_title = "Técnico"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_club = int(p.get("club", -1))


## Rosto fixo por técnico: semente e origem derivadas do id (nada é salvo a mais).
static func portrait(world: GameWorld, co: Dictionary, club: Club, px: int) -> PortraitView:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, "coach", int(co.get("id", 0))])
	var origin := NameGenerator.pick_origin(rng, String(co.get("nat", "BRA")))
	var v := PortraitView.new()
	v.custom_minimum_size = Vector2(px, px)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_person(rng.randi() & 0x7FFFFFFF, int(origin["eth"]), world.year - int(co.get("by", world.year - 50)), club)
	return v


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.club(_club)
	var co := People.coach_of(w, _club) if club != null else {}
	var c := content()
	UIKit.clear(c)
	if co.is_empty():
		c.add_child(UIKit.label("Sem técnico no momento.", "Muted"))
		return
	screen_title = String(co["n"])
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	c.add_child(_hero(w, co, club))
	c.add_child(_work(w, co, club))
	c.add_child(_style_card(co))
	var f := footer()
	UIKit.clear(f)
	var cid := club.id
	f.add_child(UIKit.button("Conversar", "PrimaryButton", func(): TalkDialog.open("coach", cid, func(): refresh()), "mail"))


func _hero(w: GameWorld, co: Dictionary, club: Club) -> Control:
	var card := UIKit.card("Card", 8)
	var row := UIKit.hbox(16)
	row.add_child(portrait(w, co, club, 150))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(String(co["n"]), "Title", true))
	var nrow := UIKit.hbox(8)
	nrow.add_child(UIKit.flag(String(co["nat"]), 34))
	nrow.add_child(UIKit.label("%s · %d anos" % [DatabaseManager.nation_name(String(co["nat"])), w.year - int(co.get("by", w.year - 50))], "Small", true))
	col.add_child(nrow)
	col.add_child(UIKit.pill(People.style_name(String(co["st"])).to_upper(), UIColors.ACCENT, 16))
	var crow := UIKit.hbox(8)
	crow.add_child(UIKit.crest(club, 30))
	crow.add_child(UIKit.label("Técnico do %s desde %d" % [club.short_name, int(co.get("since", w.year))], "Small", true))
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
	row.add_child(UIKit.stat(str(int(round(float(co.get("rep", 50.0))))), "reputação"))
	card.add_child(row)
	var job := float(co.get("job", 60.0))
	var jl := "Prestigiado" if job >= 75.0 else ("Estável" if job >= 50.0 else ("Pressionado" if job >= 30.0 else "Cargo balançando"))
	var jc := UIColors.GREEN if job >= 50.0 else (UIColors.ORANGE if job >= 30.0 else UIColors.RED)
	card.add_child(UIKit.kv("Situação no cargo", jl, jc))
	var bar := UIKit.bar(job, 100.0, jc, 10)
	card.add_child(bar)
	var fired := int(co.get("fired", 0))
	if fired > 0:
		card.add_child(UIKit.kv("Demissões na carreira", str(fired)))
	var rel := People.coach_rel(w, int(co["id"]))
	card.add_child(UIKit.kv("Relação com você", People.coach_rel_label(rel), UIColors.GREEN if rel >= 12.0 else (UIColors.RED if rel <= -12.0 else UIColors.MUTED)))
	if club.sheet != null:
		var tac := DatabaseManager.tactics()
		card.add_child(UIKit.kv("Time-base", "%s · %s" % [club.sheet.formation, String(tac["styles"][club.sheet.style]["name"])]))
	var h2h := FootballMemory.head_to_head(w, w.user_club_id, club.id) if w.has_user() and not w.is_user_club(club.id) else {}
	if int(h2h.get("games", 0)) > 0:
		card.add_child(UIKit.kv("Seu retrospecto contra o %s" % club.short_name, FootballMemory.h2h_line(h2h)))
	return UIKit.card_panel(card)


func _style_card(co: Dictionary) -> Control:
	var card := UIKit.card("Card", 6)
	var st: Dictionary = People.COACH_STYLES.get(String(co["st"]), {})
	card.add_child(UIKit.section("Estilo de trabalho"))
	card.add_child(UIKit.label(String(st.get("name", "")), "H3"))
	if st.has("desc"):
		card.add_child(UIKit.label(String(st["desc"]), "Small", true))
	return UIKit.card_panel(card)


static func _stars(sk: float) -> String:
	var n := clampi(int(round((sk - 20.0) / 15.0)), 1, 5)
	return "★".repeat(n) + "☆".repeat(5 - n)
