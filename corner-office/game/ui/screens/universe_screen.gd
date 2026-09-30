class_name UniverseScreen
extends Screen
## Enciclopédia do universo (Game Design Bible §§2–3, 13–14): eras, linha do
## tempo, organizações de todas as camadas, linhagens de cinturão, países,
## cidades, arenas, lutas clássicas, rivalidades, recordes e Hall da Fama.
## Tudo interligado: nomes, cidades e organizações abrem a própria página.
## Só leitura (Universe + Game.world); nenhuma regra mora aqui.

var _stack: Array = []   # [page, arg]
var _page := "home"
var _arg: Variant = null


func title() -> String:
	return "UNIVERSO"


func open(page: String, arg: Variant = null) -> void:
	_stack.append([_page, _arg])
	_page = page
	_arg = arg
	refresh()
	_scroll_top()


func back() -> bool:
	if _stack.is_empty():
		return false
	var prev: Array = _stack.pop_back()
	_page = prev[0]
	_arg = prev[1]
	refresh()
	_scroll_top()
	return true


func _scroll_top() -> void:
	var scroll := get_child(0) as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


func build() -> void:
	if not _stack.is_empty():
		_link("‹ VOLTAR", func(): back())
	match _page:
		"home": _home()
		"history": _history()
		"orgs": _orgs(str(_arg))
		"org": _org(str(_arg))
		"lineage": _lineage(_arg[0], _arg[1])
		"countries": _countries()
		"country": _country(str(_arg))
		"city": _city(str(_arg))
		"classics": _classics()
		"fight": _fight(str(_arg))
		"person": _person(str(_arg))
		"hof": _hof()
		"records": _records()
		"rivalries": _rivalries()


# --- blocos ------------------------------------------------------------------

func _link(text: String, callback: Callable) -> Button:
	var b := add_button(text, callback)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


func _small(text: String, color: Color = Tokens.MUTED) -> Label:
	var l := add_text(text, color)
	l.add_theme_font_size_override("font_size", Tokens.FONT_SMALL)
	return l


func _section(text: String) -> void:
	var l := add_text(text.to_upper(), Tokens.FIGHT_RED)
	l.add_theme_font_override("font", Tokens.DISPLAY_FONT)


func _art(city_id: String, height: int) -> void:
	var tex := CityArt.texture(city_id)
	if tex == null:
		return
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.custom_minimum_size.y = height
	body.add_child(r)


func _person_link(id: String, label: String = "") -> void:
	var text := label if not label.is_empty() else _person_label(id)
	add_fighter_row(_fighter(id), text, func(): open("person", id))


func _fighter(id: String) -> Fighter:
	return Universe.as_fighter(id, Game.world if Game.has_world() else null)


func _person_label(id: String) -> String:
	var p := Universe.person(id)
	if p.is_empty() and Game.has_world() and Game.world.fighters.has(id):
		return Game.world.fighters[id].display_name()
	return "%s  ·  %s" % [Universe.person_name(id), Universe.country_name(str(p.get("country", "")))]


func _org_name(id: String) -> String:
	return str(Universe.organization(id).get("name", id))


func _division_name(id: String) -> String:
	for w: Dictionary in ContentDB.load_json("weight_classes.json"):
		if w.id == id:
			return "%s%s" % [w.name, " (F)" if w.sex == "F" else ""]
	return id


# --- páginas -----------------------------------------------------------------

func _home() -> void:
	add_text("Trinta e cinco anos de história antes do seu primeiro evento.", Tokens.MUTED)
	if Game.has_world():
		var today := Universe.on_this_day(Game.world.date)
		if not today.is_empty():
			_section("Neste dia")
			for item: Dictionary in today.slice(0, 3):
				add_text("%d · %s" % [item.year, item.title])
				if not str(item.text).is_empty():
					_small(item.text)
	_section("Explorar")
	_link("ERAS E LINHA DO TEMPO", func(): open("history"))
	_link("ORGANIZAÇÕES GLOBAIS E CINTURÕES", func(): open("orgs", "global"))
	_link("PROMOTORAS NACIONAIS", func(): open("orgs", "national"))
	_link("CIRCUITO REGIONAL", func(): open("orgs", "regional"))
	_link("PROMOTORAS EXTINTAS", func(): open("orgs", "defunct"))
	_link("PAÍSES, CIDADES E ARENAS", func(): open("countries"))
	_link("LUTAS CLÁSSICAS", func(): open("classics"))
	_link("RIVALIDADES", func(): open("rivalries"))
	_link("HALL DA FAMA", func(): open("hof"))
	_link("RECORDES", func(): open("records"))


func _history() -> void:
	add_heading("Eras e linha do tempo")
	var events := Universe.timeline()
	for era: Dictionary in Universe.eras():
		_section("%s  %d–%d" % [era.name, int(era.from), int(era.to)])
		add_text(era.summary, Tokens.MUTED)
		for t: Dictionary in events:
			var y := int(str(t.date).left(4))
			if y < int(era.from) or y > int(era.to):
				continue
			var org_id: String = str(t.org) if t.org != null else ""
			add_text("%s · %s" % [Universe.format_date(t.date), t.title])
			_small(t.text)
			if not org_id.is_empty():
				var oid := org_id
				_link("→ " + _org_name(oid), func(): open("org", oid))


func _orgs(tier: String) -> void:
	add_heading({"global": "Organizações globais", "national": "Promotoras nacionais", "regional": "Circuito regional",
		"defunct": "Promotoras extintas"}.get(tier, tier))
	add_text({"global": "As sete marcas que disputam o mundo em 2027.", "national": "A camada que alimenta as globais e pode subir de patamar.",
		"regional": "Onde nascem os prospects. Surgem e somem o tempo todo.", "defunct": "Quem já foi grande e não sobreviveu."}.get(tier, ""), Tokens.MUTED)
	var list: Array = Universe.organizations(tier).duplicate()
	list.sort_custom(func(a, b): return int(a.get("reputation", 0)) > int(b.get("reputation", 0)) if tier != "defunct" else int(a.founded) < int(b.founded))
	for o: Dictionary in list:
		var id: String = o.id
		var line := "%s  ·  %s, %s" % [o.name, o.base_city, Universe.country_name(o.base_country)]
		if tier == "defunct":
			line += "  ·  %d–%d" % [int(o.founded), int(o.closed)]
		elif o.has("reputation"):
			line += "  ·  rep. %d" % int(o.reputation)
		_link(line, func(): open("org", id))


func _org(id: String) -> void:
	var o := Universe.organization(id)
	if o.is_empty():
		add_text("Organização desconhecida.", Tokens.MUTED)
		return
	add_heading(o.name)
	var city_id: String = str(o.get("city_id", ""))
	if not city_id.is_empty():
		_art(city_id, 220)
	var founded: Variant = o.get("founded")
	add_text("%s, %s%s" % [o.base_city, Universe.country_name(o.base_country),
		"  ·  desde %s" % (str(founded).left(4) if typeof(founded) == TYPE_STRING else str(int(founded))) if founded != null else ""], Tokens.MUTED)
	for key in ["identity", "situation", "story", "specialty"]:
		if o.has(key):
			add_text(str(o[key]))
	if o.has("season_goals"):
		for g in o.season_goals:
			add_text(str(g))
	if o.has("closed"):
		add_text("Encerrada em %d (%s)." % [int(o.closed), o.cause], Tokens.MUTED)
	if o.has("events_held"):
		_small("%d eventos realizados" % int(o.events_held))
	if o.has("events_per_year"):
		_small("%d eventos por ano · %s" % [int(o.events_per_year), o.status])
	if o.get("feeds") != null and not str(o.get("feeds", "")).is_empty():
		var feed: String = str(o.feeds)
		_link("Alimenta: " + _org_name(feed), func(): open("org", feed))
	if not city_id.is_empty():
		_link("Cidade: " + str(o.base_city), func(): open("city", city_id))
	var divisions := Universe.divisions_of(id)
	if not divisions.is_empty():
		_section("Cinturões")
		for division: String in divisions:
			var champ := Universe.current_champion(Game.world if Game.has_world() else null, id, division)
			var holder: String = champ.get("name", "VAGO")
			var div := division
			_link("%s  ·  %s" % [_division_name(division).to_upper(), holder], func(): open("lineage", [id, div]))
	var hist: Array = Universe.timeline().filter(func(t): return t.org == id)
	if not hist.is_empty():
		_section("Marcos")
		for t: Dictionary in hist:
			add_text("%s · %s" % [str(t.date).left(4), t.title])
			_small(t.text)


func _lineage(org_id: String, division: String) -> void:
	add_heading("%s · %s" % [_org_name(org_id), _division_name(division)])
	var champ := Universe.current_champion(Game.world if Game.has_world() else null, org_id, division)
	var reigns := Universe.lineage(org_id, division)
	if not champ.is_empty():
		var l := add_text("CAMPEÃO EM 2027  ·  %s" % champ.name, Tokens.CHAMP_GOLD)
		l.add_theme_font_override("font", Tokens.DISPLAY_FONT)
		var last: Dictionary = reigns[-1] if not reigns.is_empty() else {}
		if last.get("end") != null:
			_small("Ganhou o cinturão vago na reestruturação de dezembro de 2026.")
		var cid: String = champ.id
		var photo := add_portrait(_fighter(cid), 176)
		photo.accent = Tokens.CHAMP_GOLD
		_link("Ver ficha", func(): open("person", cid) if not Universe.person(cid).is_empty() else null)
	else:
		add_text("CINTURÃO VAGO", Tokens.MUTED)
	_section("Linhagem (%d reinados)" % reigns.size())
	var reversed := reigns.duplicate()
	reversed.reverse()
	for r: Dictionary in reversed:
		var id: String = r.fighter_id
		var span := "%s – %s" % [Universe.format_date(r.start), Universe.format_date(r.end) if r.end != null else "hoje"]
		add_fighter_row(_fighter(id), "%s  ·  %s" % [r.name, Universe.country_name(r.country)], func(): open("person", id))
		_small("%s · %s · %d defesa%s · %s%s" % [span, r.event, int(r.defenses), "" if int(r.defenses) == 1 else "s", r.how_won,
			("  ·  " + str(r.how_ended)) if not str(r.how_ended).is_empty() else ""])


func _countries() -> void:
	add_heading("Países, cidades e arenas")
	for region: Dictionary in Universe.regions():
		_section(region.name)
		_small(region.summary)
		var list: Array = Universe.countries().filter(func(c): return c.region == region.id)
		list.sort_custom(func(a, b): return int(a.scene) > int(b.scene))
		for c: Dictionary in list:
			var id: String = c.id
			_link("%s  ·  cena %d · mercado %d" % [c.name, int(c.scene), int(c.market)], func(): open("country", id))


func _country(id: String) -> void:
	var c := Universe.country(id)
	add_heading(c.get("name", id))
	var cities := Universe.cities(id)
	if not cities.is_empty():
		_art(cities[0].id, 240)
	add_text("Cena %d · Mercado %d · Paixão %d" % [int(c.scene), int(c.market), int(c.passion)])
	_small("Regulação: %s · Moeda: %s" % [c.commission, c.currency])
	if not c.style_tendencies.is_empty():
		_small("Tendências: " + ", ".join(c.style_tendencies))
	_section("Cidades")
	for city: Dictionary in cities:
		var cid: String = city.id
		_link("%s  ·  %d arena%s" % [city.name, city.venues.size(), "" if city.venues.size() == 1 else "s"], func(): open("city", cid))
	var orgs := Universe.organizations_in(id)
	if not orgs.is_empty():
		_section("Organizações")
		for o: Dictionary in orgs:
			var oid: String = o.id
			_link("%s  ·  %s" % [o.name, {"global": "global", "national": "nacional", "regional": "regional", "defunct": "extinta"}.get(o.get("tier", ""), "")],
				func(): open("org", oid))
	var legends := Universe.legends_from(id)
	if not legends.is_empty():
		_section("No Hall da Fama")
		for h: Dictionary in legends:
			_person_link(h.fighter_id, h.name)


func _city(id: String) -> void:
	var c := Universe.city(id)
	add_heading(c.get("name", id))
	_art(id, 360)
	add_text(c.note)
	_small("Mercado %d · Paixão da torcida %d" % [int(c.market), int(c.passion)])
	var country_id: String = c.country
	_link(Universe.country_name(country_id), func(): open("country", country_id))
	_section("Arenas")
	for v: Dictionary in Universe.venues_in(id):
		add_text("%s · %s lugares" % [v.name, _thousands(int(v.capacity))])
		_small("%s · custo-base %s por noite" % [v.tier.capitalize(), CareerText.money(int(v.cost))])
	var orgs: Array = []
	for tier in ["global", "national", "regional", "defunct"]:
		orgs.append_array(Universe.organizations(tier).filter(func(o): return o.get("city_id", "") == id))
	if not orgs.is_empty():
		_section("Sediadas aqui")
		for o: Dictionary in orgs:
			var oid: String = o.id
			_link(o.name, func(): open("org", oid))


func _classics() -> void:
	add_heading("Lutas clássicas")
	var list := Universe.classic_fights()
	list.reverse()
	for f: Dictionary in list:
		var id: String = f.id
		add_face_off(_fighter(f.red), _fighter(f.blue), "%s\n%s × %s" % [str(f.date).left(4), Universe.person_name(f.red), Universe.person_name(f.blue)],
			func(): open("fight", id))
		_small("%s · %s · %s · %s" % [f.event, _division_name(f.division), f.method, "★".repeat(int(round(float(f.stars))))])


func _fight(id: String) -> void:
	var f := Universe.fight(id)
	add_heading("%s × %s" % [Universe.person_name(f.red), Universe.person_name(f.blue)])
	add_face_off(_fighter(f.red), _fighter(f.blue), "×")
	add_text("%s · %s · %s" % [f.event, Universe.format_date(f.date), _division_name(f.division)], Tokens.MUTED)
	var winner: String = f.red if f.winner == "red" else f.blue if f.winner == "blue" else ""
	add_text(("Vitória de %s" % Universe.person_name(winner)) if not winner.is_empty() else "Empate", Tokens.CHAMP_GOLD)
	add_text("%s · round %d · %s" % [f.method, int(f.round), f.time])
	if f.has("story"):
		add_text(f.story, Tokens.MUTED)
	_person_link(f.red)
	_person_link(f.blue)
	var oid: String = f.org
	_link("→ " + _org_name(oid), func(): open("org", oid))


func _person(id: String) -> void:
	var p := Universe.person(id)
	var alive: Fighter = Game.world.fighters.get(id) if Game.has_world() else null
	if p.is_empty() and alive == null:
		add_text("Sem registro.", Tokens.MUTED)
		return
	var nick: String = str(p.get("nickname", ""))
	var photo := add_portrait(alive if alive else Universe.as_fighter(id), 220)
	if not p.get("titles", []).is_empty():
		photo.accent = Tokens.CHAMP_GOLD
	add_heading(alive.display_name() if alive else "%s%s %s" % [p.first_name, (" “%s”" % nick) if not nick.is_empty() else "", p.last_name])
	var country_id: String = alive.country if alive else str(p.country)
	add_text("%s%s" % [Universe.country_name(country_id), ("  ·  nascido em %d" % int(p.birth_year)) if p.has("birth_year") else ""], Tokens.MUTED)
	if alive:
		var fights_done := int(alive.record.wins) + int(alive.record.losses)
		add_text("Em atividade em 2027" + (" · cartel %d-%d" % [int(alive.record.wins), int(alive.record.losses)] if fights_done > 0 else ""))
	elif p.get("retired") != null:
		add_text("Aposentado em %d" % int(p.retired))
	if not str(p.get("role_text", "")).is_empty() and not alive:
		add_text(p.role_text)
	if not str(p.get("bio", "")).is_empty():
		add_text(p.bio, Tokens.MUTED)
	var titles: Array = p.get("titles", [])
	if not titles.is_empty():
		_section("Cinturões")
		for t: Dictionary in titles:
			var key := [t.org, t.division]
			_link("%s · %s  ·  %s – %s" % [_org_name(t.org), _division_name(t.division), str(t.start).left(4), str(t.end).left(4) if t.end != null else "hoje"],
				func(): open("lineage", key))
	var tf: Dictionary = p.get("title_fights", {})
	var fights := Universe.fights_of(id)
	if not fights.is_empty():
		_section("Lutas por cinturão  %d-%d%s" % [int(tf.get("wins", 0)), int(tf.get("losses", 0)), ("-%d" % int(tf.draws)) if int(tf.get("draws", 0)) else ""])
		for f: Dictionary in fights:
			var fid: String = f.id
			var opp: String = f.blue if f.red == id else f.red
			var won: bool = (f.winner == "red" and f.red == id) or (f.winner == "blue" and f.blue == id)
			_link("%s %s × %s" % [str(f.date).left(4), "V" if won else "E" if f.winner == "draw" else "D", Universe.person_name(opp)], func(): open("fight", fid))
	var rivals: Array = Universe.rivalries().filter(func(r): return r.a == id or r.b == id)
	for r: Dictionary in rivals:
		var other: String = r.b if r.a == id else r.a
		_person_link(other, "%s com %s" % [r.label, Universe.person_name(other)])


func _hof() -> void:
	add_heading("Hall da Fama")
	for h: Dictionary in Universe.hall_of_fame():
		var id: String = h.fighter_id
		add_fighter_row(_fighter(id), "%d · %s" % [int(h.inducted), h.name], func(): open("person", id))
		_small(h.citation)


func _records() -> void:
	add_heading("Recordes")
	for r: Dictionary in Universe.records():
		_section("%s · %s" % [r.category, r.title])
		for e: Dictionary in r.entries:
			var value := "%s %s" % [str(int(e.value)), e.unit]
			if e.has("fighter_id"):
				_person_link(e.fighter_id, "%s  ·  %s" % [e.name, value])
			else:
				add_text("%s  ·  %s" % [e.name, value])
				if e.has("note"):
					_small(e.note)


func _rivalries() -> void:
	add_heading("Rivalidades")
	add_text("Pares que se enfrentaram mais de uma vez valendo cinturão.", Tokens.MUTED)
	for r: Dictionary in Universe.rivalries().slice(0, 60):
		var a: String = r.a
		_link("%s  ·  %s × %s  (%d-%d)" % [r.label, r.a_name, r.b_name, int(r.score[0]), int(r.score[1])], func(): open("person", a))


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
