extends BaseScreen
## Editor: nomes, cores e escudos de clubes (com imagem importada), jogadores (nome, posição,
## aparência, foto, atributos e personalidade), nomes, logos e cores de competições e o treinador.
##
## Com uma carreira aberta, clubes e jogadores do save mudam na hora; o que for marcado como
## "padrão" também vale para novas carreiras (Overrides). Sem carreira, edita só o padrão.

const PALETTE: Array[String] = [
	"#FFFFFF", "#111111", "#C8102E", "#8B0000", "#E4572E", "#F2A900", "#FFD100", "#2E7D32",
	"#0B6E4F", "#00A86B", "#1B3A8C", "#0033A0", "#4EA8DE", "#6CACE4", "#5B2C83", "#8E44AD",
	"#7B3F00", "#8D99AE", "#B5A642", "#F58220", "#E91E63", "#00838F", "#004D40", "#3E2723",
]

var _view := "home"
var _club: Club = null
var _club_dirty: Array = []
var _pid := -1
var _comp_kind := ""
var _comp_id := ""
var _nation := ""
var _league := ""
var _search := ""
var _pclub := -1 # clube aberto na lista de jogadores (-2 = sem clube)
var _match := "" # nome original do jogador em edição (Editor geral)
var _uid := "" # jogador criado no Editor geral
var _ovr_badge: RatingBadge = null
var _ovr_label: Label = null
var _kit_sel := "h" # uniforme aberto no editor de clube: h, a, t, g


func _init() -> void:
	show_nav = false
	screen_title = "Editor"


func setup(p: Dictionary) -> void:
	super.setup(p)
	if String(p.get("tab", "")) == "mods":
		_view = "mods"
	if p.has("player"):
		_view = "player"
		_pid = int(p["player"])
		var pl: Player = world().player(_pid) if world() != null else null
		_match = (pl.first_name + " " + pl.last_name) if pl != null else ""
		_uid = ""
	elif p.has("club"):
		var w := world()
		if w != null:
			_club = w.club(int(p["club"]))
			_view = "club"


func has_career() -> bool:
	return GameManager.has_career()


func refresh() -> void:
	var c := content()
	UIKit.clear(c)
	hide_footer()
	match _view:
		"club":
			_club_editor(c)
		"player":
			_player_editor(c)
		"comp":
			_comp_editor(c)
		"pick_club":
			_club_picker(c)
		"pick_player":
			_player_picker(c)
		"pick_comp":
			_comp_picker(c)
		"mods":
			_mods_view(c)
		_:
			_home(c)
	UIManager.refresh_chrome()


func _go(view: String) -> void:
	_view = view
	refresh()
	scroll_to_top()


# ---------------------------------------------------------------------------
# Início
# ---------------------------------------------------------------------------

func _home(c: VBoxContainer) -> void:
	screen_subtitle = "" if has_career() else "Mundo padrão das novas carreiras"
	var items: Array = []
	var edit_ok := not has_career() or AppSettings.career_edit
	if has_career():
		items.append(["shield", "Meu clube", "", func():
			_club = world().user_club()
			_club_dirty.clear()
			_go("club")])
	if edit_ok:
		items.append(["search", "Clubes", "Qualquer clube do mundo" + ("" if has_career() else ": nomes, escudos, estádios e uniformes"), func(): _go("pick_club")])
		items.append(["shirt", "Jogadores", "", func(): _go("pick_player")])
	items.append(["trophy", "Competições", "Nomes, logos, cores e placar da TV", func(): _go("pick_comp")])
	if has_career():
		items.append(["star", "Treinador", "Nome, rosto, nacionalidade e estilo", func(): UIManager.push("manager")])
	items.append(["list", "Mods", "", func(): _go("mods")])
	# Início do editor: um ladrilho grande por área (como o hub de criação de um jogo de esporte).
	max_content_width = 1500
	c.add_child(UIKit.eyebrow("O que você quer editar?"))
	var tiles: Array = []
	for it in items:
		tiles.append(UIKit.action_tile(String(it[0]), String(it[1]), String(it[2]), it[3], tiles.is_empty()))
	c.add_child(UIKit.tile_grid(tiles, 3 if UILayout.is_wide() else 2))
	var info := UIKit.card("Card", 6)
	if has_career() and not AppSettings.career_edit:
		info.add_child(UIKit.label("Edição na carreira desligada em Opções.", "Small", true))
		c.add_child(UIKit.card_panel(info))


func _manager_name() -> void:
	var w := world()
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Nome do treinador", "Title"))
	var le := LineEdit.new()
	le.text = w.manager_name
	le.max_length = 28
	v.add_child(le)
	v.add_child(UIKit.button("Salvar", "PrimaryButton", func():
		if le.text.strip_edges() != "":
			w.manager_name = le.text.strip_edges()
			GameManager.save_now()
		UIManager.close_modal()))
	UIManager.show_modal(v)


# ---------------------------------------------------------------------------
# Escolher clube
# ---------------------------------------------------------------------------

func _club_picker(c: VBoxContainer) -> void:
	screen_subtitle = "Escolha um clube"
	if _nation == "":
		_nation = world().user_nation() if has_career() else "BRA"
	var nations: Array = DatabaseManager.league_nations()
	var ob := OptionButton.new()
	for i in nations.size():
		ob.add_item(DatabaseManager.nation_name(String(nations[i])), i)
		if String(nations[i]) == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(nations[i])
		_league = ""
		refresh())
	c.add_child(ob)
	var leagues: Array = DatabaseManager.leagues_of_nation(_nation)
	if _league == "" or not leagues.has(_league):
		_league = String(leagues[0])
	var litems: Array = []
	for id in leagues:
		litems.append([String(id), String(DatabaseManager.league_cfg(String(id)).get("short", id))])
	c.add_child(UIKit.scroll_tabs(litems, _league, func(k: String):
		_league = k
		refresh()))
	var card := UIKit.card("Card", 4)
	for cl: Club in _clubs_of(_league):
		var row := UIKit.hbox(12)
		row.add_child(UIKit.crest(cl, 44))
		var nl := UIKit.label(cl.name, "H3", true)
		row.add_child(nl)
		if not Overrides.club(cl.key).is_empty():
			row.add_child(UIKit.pill("EDITADO", UIColors.BLUE, 14))
		var cc := cl
		card.add_child(UIKit.tap_row(row, func():
			_club = cc
			_club_dirty.clear()
			_go("club")))
	if card.get_child_count() == 0:
		card.add_child(UIKit.label("Clubes gerados só na carreira.", "Muted", true))
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


## Clubes da liga: os do save (com carreira) ou os autorais montados na hora (sem carreira).
func _clubs_of(league_id: String) -> Array:
	if has_career():
		return world().clubs_in_league(league_id)
	var cfg := DatabaseManager.league_cfg(league_id)
	var out: Array = []
	for d in DatabaseManager.club_data(String(cfg["nation"])):
		if String(d.get("league", "")) != league_id:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(String(d.get("key", d.get("name", ""))))
		var cl := ClubGenerator.from_data(null, rng, d, out.size(), cfg)
		Overrides.apply_club(cl)
		out.append(cl)
	return out


# ---------------------------------------------------------------------------
# Editar clube
# ---------------------------------------------------------------------------

func _club_editor(c: VBoxContainer) -> void:
	var cl := _club
	if cl == null:
		_go("home")
		return
	screen_subtitle = cl.name
	var head := UIKit.card("CardHighlight", 10)
	var row := UIKit.hbox(16)
	var crest := UIKit.crest(cl, 110)
	row.add_child(crest)
	row.add_child(UIKit.kit(cl.kit_home, 96, 10, cl.crest))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(cl.name, "Title", true))
	col.add_child(UIKit.label("%s · %s" % [cl.abbr, cl.city], "Small", true))
	var key_l := UIKit.label("Chave para mods: %s" % cl.key, "Small")
	key_l.add_theme_color_override(&"font_color", UIColors.DIM)
	col.add_child(key_l)
	row.add_child(col)
	head.add_child(row)
	c.add_child(UIKit.card_panel(head))
	var names := UIKit.card("Card", 8)
	names.add_child(UIKit.section("Identidade"))
	for f in [["name", "Nome completo", cl.name, 40], ["short", "Nome curto", cl.short_name, 20], ["abbr", "Sigla", cl.abbr, 4], ["nick", "Apelido", cl.nickname, 24], ["city", "Cidade", cl.city, 28], ["official", "Nome oficial (opcional)", cl.official, 80]]:
		var key: String = f[0]
		names.add_child(_field(String(f[1]), String(f[2]), int(f[3]), func(t: String):
			_set_club_field(cl, key, t)))
	c.add_child(UIKit.card_panel(names))
	var colors := UIKit.card("Card", 8)
	colors.add_child(UIKit.section("Cores"))
	colors.add_child(UIKit.label("Principal", "Small"))
	colors.add_child(_swatches(cl.color1, func(hex: String):
		Overrides.set_colors(cl, hex, cl.color2)
		_mark("c1")
		refresh()))
	colors.add_child(UIKit.label("Secundária", "Small"))
	colors.add_child(_swatches(cl.color2, func(hex: String):
		Overrides.set_colors(cl, cl.color1, hex)
		_mark("c1")
		refresh()))
	c.add_child(UIKit.card_panel(colors))
	c.add_child(_crest_card(cl))
	c.add_child(_stadium_card(cl))
	c.add_child(_kits_card(cl))
	var f := footer()
	UIKit.clear(f)
	var btns := UIKit.hbox(10)
	var done := UIKit.button("PRONTO", "PrimaryButton", func():
		if has_career():
			GameManager.save_now()
			UIManager.toast("Clube atualizado.")
		elif not _club_dirty.is_empty():
			_store_partial(cl)
			UIManager.toast("Salvo como padrão das novas carreiras.")
		_go("home"), "check")
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(done)
	if has_career():
		btns.add_child(UIKit.button("Usar em novas carreiras", "", func():
			Overrides.store_club(cl)
			UIManager.toast("Esse visual será usado nas próximas carreiras.")))
	if not Overrides.club(cl.key).is_empty():
		btns.add_child(UIKit.icon_button("close", func():
			Overrides.clear_club(cl.key)
			UIManager.toast("Personalização padrão removida."), "Remover padrão"))
	f.add_child(btns)


func _crest_card(cl: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Escudo"))
	var img := String(cl.crest.get("img", ""))
	var row := UIKit.hbox(10)
	row.add_child(UIKit.button("Importar imagem", "", func():
		ImagePicker.pick("crest", func(file: String):
			CustomAssets.remove(String(cl.crest.get("img", "")))
			cl.crest["img"] = file
			_mark("crest")
			refresh()), "plus"))
	if img != "":
		row.add_child(UIKit.button("Usar escudo desenhado", "GhostButton", func():
			CustomAssets.remove(String(cl.crest.get("img", "")))
			cl.crest.erase("img")
			_mark("crest")
			refresh()))
	card.add_child(row)
	if img != "":
		card.add_child(UIKit.label("Imagem do pacote." if img.begins_with("@") else "Usando a imagem importada.", "Small", true))
	for group in [["shape", "Formato", ClubGenerator.CREST_SHAPES, ClubGenerator.CREST_SHAPE_NAMES],
			["field", "Campo", ClubGenerator.CREST_FIELDS, ClubGenerator.CREST_FIELD_NAMES],
			["symbol", "Símbolo", ClubGenerator.CREST_SYMBOLS, ClubGenerator.CREST_SYMBOL_NAMES],
			["border", "Borda", ClubGenerator.CREST_BORDERS, ClubGenerator.CREST_BORDER_NAMES]]:
		var key: String = group[0]
		card.add_child(UIKit.label(String(group[1]), "Small"))
		var g := ButtonGroup.new()
		var flow := UIKit.flow(8)
		var vals: Array = group[2]
		var labels: Array = group[3]
		var current := String(CrestView.spec(cl.crest).get(key, "")) if key != "symbol" else String(cl.crest.get(key, ""))
		for i in vals.size():
			var val: String = vals[i]
			flow.add_child(UIKit.chip(String(labels[i]), current == val, g, func():
				cl.crest[key] = val
				cl.crest.erase("stripes")
				cl.crest["edited"] = true
				_mark("crest")
				refresh()))
		card.add_child(flow)
	# Estrelas de títulos em cima do escudo
	var st := UIKit.hbox(10)
	var sl := UIKit.label("Estrelas em cima", "")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(sl)
	var stars := int(cl.crest.get("stars", 0))
	st.add_child(UIKit.button("−", "GhostButton", func():
		cl.crest["stars"] = maxi(0, stars - 1)
		cl.crest["edited"] = true
		_mark("crest")
		refresh()))
	st.add_child(UIKit.label(str(stars), ""))
	st.add_child(UIKit.button("+", "GhostButton", func():
		cl.crest["stars"] = mini(7, stars + 1)
		cl.crest["edited"] = true
		_mark("crest")
		refresh()))
	card.add_child(st)
	var cw := UIKit.hbox(10)
	var cwl := UIKit.label("Coroa", "")
	cwl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cw.add_child(cwl)
	var cb := CheckButton.new()
	cb.button_pressed = int(cl.crest.get("crown", 0)) > 0
	cb.toggled.connect(func(on: bool):
		cl.crest["crown"] = 1 if on else 0
		cl.crest["edited"] = true
		_mark("crest")
		refresh())
	cw.add_child(cb)
	card.add_child(cw)
	return UIKit.card_panel(card)


## Estádio: nome, capacidade, tipo (muda o desenho e o corte do gramado na partida), foto e extras.
func _stadium_card(cl: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Estádio"))
	var photo := DropIns.venue_photo(cl)
	if photo != null:
		var tr := TextureRect.new()
		tr.texture = photo
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.custom_minimum_size = Vector2(0, 200)
		tr.clip_contents = true
		card.add_child(tr)
	card.add_child(_field("Nome do estádio", cl.stadium, 48, func(t: String): _set_club_field(cl, "stadium", t)))
	var cap_fmt := func(v: int) -> String: return Fmt.thousands(v * 500)
	var cap_set := func(v: int) -> void:
		cl.capacity = v * 500
		_mark("cap")
	card.add_child(_stepper("Capacidade", clampi(int(round(cl.capacity / 500.0)), 1, 400), 1, 400, cap_set, cap_fmt))
	for extra in [["nick", "Apelido do estádio", 32], ["built", "Inauguração (ano)", 4]]:
		var key: String = extra[0]
		card.add_child(_field(String(extra[1]), str(cl.venue.get(key, "")), int(extra[2]), func(t: String):
			var v := t.strip_edges()
			if v == "":
				cl.venue.erase(key)
			else:
				cl.venue[key] = int(v) if key == "built" and v.is_valid_int() else v
			_mark("venue")))
	card.add_child(UIKit.label("Tipo de estádio", "Small"))
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	var cur := String(cl.venue.get("kind", ""))
	for k in LicensedData.VENUE_KIND_NAMES:
		var kind: String = k
		flow.add_child(UIKit.chip(String(LicensedData.VENUE_KIND_NAMES[kind]), cur == kind, g, func():
			if kind == "":
				cl.venue.erase("kind")
			else:
				cl.venue["kind"] = kind
			_mark("venue")
			refresh()))
	card.add_child(flow)
	var row := UIKit.hbox(10)
	row.add_child(UIKit.button("Importar foto", "", func():
		ImagePicker.pick("stadium", func(file: String):
			CustomAssets.remove(String(cl.venue.get("photo", "")))
			cl.venue["photo"] = file
			_mark("venue")
			refresh()), "plus"))
	if String(cl.venue.get("photo", "")) != "":
		row.add_child(UIKit.button("Remover foto", "GhostButton", func():
			CustomAssets.remove(String(cl.venue.get("photo", "")))
			cl.venue.erase("photo")
			_mark("venue")
			refresh()))
	card.add_child(row)
	return UIKit.card_panel(card)


## Uniforme em edição (o dicionário do próprio clube, para mudar na hora).
func _kit_ref(cl: Club, which: String) -> Dictionary:
	match which:
		"a":
			return cl.kit_away
		"t":
			cl.third_kit()
			return cl.kit_third
		"g":
			cl.gk_kit()
			return cl.kit_gk
	return cl.kit_home


## Uniformes: os quatro lado a lado; o escolhido ganha estampa e cores (o desenho completo, peça
## por peça, fica na tela de uniformes da carreira).
func _kits_card(cl: Club) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Uniformes"))
	var kits := UIKit.hbox(8)
	for it in [["h", "Titular", cl.kit_home], ["a", "Reserva", cl.kit_away], ["t", "Terceiro", cl.third_kit()], ["g", "Goleiro", cl.gk_kit()]]:
		var which: String = it[0]
		var v := UIKit.vbox(4)
		var kv := UIKit.kit(it[2], 84, 0, cl.crest)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(kv)
		var l := UIKit.label(String(it[1]).to_upper(), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if which == _kit_sel:
			l.add_theme_color_override(&"font_color", UIColors.ACCENT)
		v.add_child(l)
		var tap := UIKit.tap_row(v, func():
			_kit_sel = which
			refresh(), "RowPanel", which == _kit_sel)
		tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kits.add_child(tap)
	card.add_child(kits)
	var k := _kit_ref(cl, _kit_sel)
	card.add_child(UIKit.label("Estampa", "Small"))
	var ob := OptionButton.new()
	for i in KitView.PATTERNS.size():
		ob.add_item(String(KitView.PATTERNS[i][1]), i)
		if String(KitView.PATTERNS[i][0]) == String(k.get("pattern", "plain")):
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		k["pattern"] = String(KitView.PATTERNS[i][0])
		_mark("kits")
		refresh())
	card.add_child(ob)
	for part in [["c1", "Camisa"], ["c2", "Detalhes"], ["shorts", "Calção"], ["socks", "Meiões"]]:
		var field: String = part[0]
		card.add_child(UIKit.label(String(part[1]), "Small"))
		card.add_child(_swatches(String(k.get(field, k.get("c1", "#FFFFFF"))), func(hex: String):
			k[field] = hex
			if field == "c2" and not k.has("c3"):
				k["c3"] = hex
			_mark("kits")
			refresh()))
	return UIKit.card_panel(card)


func _set_club_field(cl: Club, key: String, t: String) -> void:
	var v := t.strip_edges()
	if v == "":
		return
	match key:
		"name":
			cl.name = v
		"short":
			cl.short_name = v
		"abbr":
			cl.abbr = v.to_upper()
			cl.crest["initials"] = v.to_upper().substr(0, 3)
			cl.crest["edited"] = true
		"nick":
			cl.nickname = v
		"city":
			cl.city = v
		"stadium":
			cl.stadium = v
		"official":
			cl.official = v
	_mark(key)


func _mark(key: String) -> void:
	if not _club_dirty.has(key):
		_club_dirty.append(key)


## Sem carreira: grava só o que foi mexido (o resto segue o gerador).
func _store_partial(cl: Club) -> void:
	var cur := Overrides.club(cl.key).duplicate(true)
	for k in _club_dirty:
		match String(k):
			"name":
				cur["name"] = cl.name
			"short":
				cur["short"] = cl.short_name
			"abbr":
				cur["abbr"] = cl.abbr
			"nick":
				cur["nick"] = cl.nickname
			"city":
				cur["city"] = cl.city
			"stadium":
				cur["stadium"] = cl.stadium
			"official":
				cur["official"] = cl.official
			"cap":
				cur["cap"] = cl.capacity
			"venue":
				cur["venue"] = cl.venue.duplicate(true)
			"kits":
				cur["kits"] = Overrides.kits_of(cl)
			"c1":
				cur["c1"] = cl.color1
				cur["c2"] = cl.color2
				cur["crest"] = cl.crest.duplicate(true)
			"crest":
				cur["crest"] = cl.crest.duplicate(true)
	Overrides.data()["clubs"][cl.key] = cur
	Overrides.save()


func _field(caption: String, value: String, max_len: int, on_change: Callable) -> Control:
	var v := UIKit.vbox(2)
	v.add_child(UIKit.label(caption, "Small"))
	var le := LineEdit.new()
	le.text = value
	le.max_length = max_len
	le.text_changed.connect(on_change)
	v.add_child(le)
	return v


func _swatches(current: String, cb: Callable) -> Control:
	var flow := UIKit.flow(6)
	var hexes: Array[String] = PALETTE.duplicate()
	if current != "" and not PALETTE.any(func(h: String): return Color(h).to_html(false) == Color(current).to_html(false)):
		hexes.push_front(current)
	for hex in hexes:
		var h: String = hex
		var b := Button.new()
		b.custom_minimum_size = Vector2(56, 56)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(h)
		sb.set_corner_radius_all(28)
		var selected := Color(h).to_html(false) == Color(current).to_html(false)
		sb.set_border_width_all(4 if selected else 1)
		sb.border_color = UIColors.ACCENT if selected else Color(1, 1, 1, 0.25)
		b.add_theme_stylebox_override(&"normal", sb)
		b.add_theme_stylebox_override(&"hover", sb)
		b.add_theme_stylebox_override(&"pressed", sb)
		b.add_theme_stylebox_override(&"focus", sb)
		b.pressed.connect(func(): cb.call(h))
		flow.add_child(b)
	return flow


# ---------------------------------------------------------------------------
# Escolher jogador
# ---------------------------------------------------------------------------

## Mundo em edição: o da carreira ou, no Editor geral, o mundo padrão carregado para edição.
func _w() -> GameWorld:
	return world() if has_career() else GameManager.preview_world


func _player_picker(c: VBoxContainer) -> void:
	screen_subtitle = "Escolha um jogador"
	var w := _w()
	if w == null:
		var wait := UIKit.card("Card", 8)
		wait.add_child(UIKit.label("Carregando o mundo padrão…", "H2"))
		wait.add_child(UIKit.label("Montando os clubes…", "Small", true))
		c.add_child(UIKit.card_panel(wait))
		c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))
		GameManager.ensure_preview_world(func():
			if is_inside_tree() and _view == "pick_player":
				refresh())
		return
	var le := LineEdit.new()
	le.placeholder_text = "Buscar pelo nome (3 letras ou mais)"
	le.text = _search
	le.text_submitted.connect(func(t: String):
		_search = t.strip_edges()
		refresh())
	var srow := UIKit.hbox(8)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(le)
	srow.add_child(UIKit.icon_button("search", func():
		_search = le.text.strip_edges()
		refresh(), "Buscar"))
	if _search != "":
		srow.add_child(UIKit.icon_button("close", func():
			_search = ""
			refresh(), "Limpar"))
	c.add_child(srow)
	if _search.length() >= 3:
		var q := _search.to_lower()
		var found: Array = []
		for p: Player in w.players.values():
			if (p.first_name + " " + p.last_name + " " + p.known_as).to_lower().contains(q):
				found.append(p)
				if found.size() >= 60:
					break
		c.add_child(_player_list_card(w, "Resultados", found, null))
		c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))
		return
	# Navegação: país → divisão → clube
	if _pclub < 0 and _pclub != -2:
		_pclub = w.user_club_id if has_career() else -1
	if _nation == "":
		_nation = w.user_nation() if has_career() else "BRA"
	var nations: Array = DatabaseManager.league_nations()
	var ob := OptionButton.new()
	for i in nations.size():
		ob.add_item(DatabaseManager.nation_name(String(nations[i])), i)
		if String(nations[i]) == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(nations[i])
		_league = ""
		_pclub = -1
		refresh())
	c.add_child(ob)
	var leagues: Array = DatabaseManager.leagues_of_nation(_nation)
	if _league == "" or not leagues.has(_league):
		_league = String(leagues[0])
	var g := ButtonGroup.new()
	var lflow := UIKit.flow(8)
	for id in leagues:
		var lid: String = id
		lflow.add_child(UIKit.chip(String(DatabaseManager.league_cfg(lid).get("short", lid)), lid == _league and _pclub != -2, g, func():
			_league = lid
			_pclub = -1
			refresh()))
	lflow.add_child(UIKit.chip("Sem clube", _pclub == -2, g, func():
		_pclub = -2
		refresh()))
	c.add_child(lflow)
	if _pclub == -2:
		var free: Array = w.free_agents().duplicate()
		free.sort_custom(func(a, b): return a.overall > b.overall)
		c.add_child(_player_list_card(w, "Jogadores sem clube", free.slice(0, 80), null))
	else:
		var clubs: Array = w.clubs_in_league(_league)
		var cflow := UIKit.flow(6)
		var cg := ButtonGroup.new()
		for cl: Club in clubs:
			var cid := cl.id
			var inner := UIKit.hbox(6)
			inner.add_child(UIKit.crest(cl, 26))
			inner.add_child(UIKit.label(cl.short_name, "Small"))
			var row := UIKit.tap_row(inner, func():
				_pclub = cid
				refresh(), "CardFlat" if cid != _pclub else "CardHighlight")
			cflow.add_child(row)
		c.add_child(cflow)
		var club := w.club(_pclub)
		if club != null and club.league_id == _league:
			var list: Array = w.squad(club)
			if has_career() and w.is_user_club(club.id):
				list.append_array(YouthManager.academy(w))
			c.add_child(_player_list_card(w, club.name, list, club))
		else:
			c.add_child(UIKit.label("Escolha um clube.", "Muted", true))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


func _player_list_card(w: GameWorld, title: String, list: Array, club: Club) -> Control:
	var card := UIKit.card("Card", 4)
	var head := UIKit.hbox(8)
	var hl := UIKit.section(title)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	if club != null:
		var cc := club
		head.add_child(UIKit.button("Novo jogador", "GhostButton", func(): _new_player(cc), "plus"))
	card.add_child(head)
	for p: Player in list:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 52))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3"))
		var cl := w.club(p.club_id)
		col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.code(p.position), p.age(w.year), cl.short_name if cl != null else "Sem clube"], "Small"))
		row.add_child(col)
		if not has_career() and PlayerMods.key_of(w, p) != "":
			row.add_child(UIKit.pill("EDITADO", UIColors.BLUE, 14))
		row.add_child(UIKit.badge(p.overall, 52, 38, 22))
		var pid := p.id
		card.add_child(UIKit.tap_row(row, func(): _open_player(pid)))
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém encontrado.", "Muted"))
	return UIKit.card_panel(card)


## Abre o editor de um jogador lembrando de onde ele veio (nome original ou uid de jogador criado).
func _open_player(pid: int) -> void:
	var w := _w()
	var p := w.player(pid)
	if p == null:
		return
	_pid = pid
	_uid = ""
	_match = p.first_name + " " + p.last_name
	var key := PlayerMods.key_of(w, p)
	if key.begins_with("uid:"):
		_uid = key.substr(4)
	elif key.contains("/"):
		_match = key.substr(key.find("/") + 1)
	_go("player")


## Jogador novo num clube: nasce com nível de titular do clube e fica guardado quando salvar.
func _new_player(club: Club) -> void:
	var w := _w()
	var uid := "%x" % (randi() ^ Time.get_ticks_usec())
	var e := {"uid": uid, "club": club.key, "pos": "MC", "age": 22, "ovr": int(round(PlayerGenerator.club_level(club))),
		"first": "Novo", "last": "Jogador"}
	var marks: Dictionary = w.stats.get("pmods", {})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	PlayerMods._apply_one(w, rng, e, WorldGenerator.used_names_of(w), marks)
	w.stats["pmods"] = marks
	for k in marks:
		if String(marks[k]) == "uid:" + uid:
			_pid = int(k)
	_uid = uid
	_match = ""
	PlayerGenerator.assign_shirt_numbers(w, club)
	_go("player")


# ---------------------------------------------------------------------------
# Editar jogador
# ---------------------------------------------------------------------------

func _player_editor(c: VBoxContainer) -> void:
	var w := _w()
	var p: Player = w.player(_pid) if w != null else null
	if p == null:
		_go("home")
		return
	screen_subtitle = p.display_name()
	var club := w.club(p.club_id)
	# Cabeçalho: foto, nome, posição, overall e potencial (atualizam enquanto você mexe)
	var head := UIKit.card("CardHighlight", 10)
	var row := UIKit.hbox(16)
	row.add_child(UIKit.portrait(p, club, w.year, 150))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.full_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.name_of(p.position), p.age(w.year), club.short_name if club != null else "Sem clube"], "Small", true))
	var ob := UIKit.hbox(10)
	_ovr_badge = UIKit.badge(p.overall)
	ob.add_child(_ovr_badge)
	_ovr_label = UIKit.label("", "Small")
	ob.add_child(_ovr_label)
	col.add_child(ob)
	row.add_child(col)
	head.add_child(row)
	var prow := UIKit.hbox(8)
	prow.add_child(UIKit.button("Importar foto", "", func():
		ImagePicker.pick("photo", func(file: String):
			CustomAssets.remove(String(p.look.get("photo", "")))
			p.look["photo"] = file
			refresh()), "plus"))
	if String(p.look.get("photo", "")) != "":
		prow.add_child(UIKit.button("Remover foto", "GhostButton", func():
			CustomAssets.remove(String(p.look.get("photo", "")))
			p.look.erase("photo")
			refresh()))
	head.add_child(prow)
	if not has_career():
		head.add_child(UIKit.label("Mundo padrão das novas carreiras.", "Small", true))
	c.add_child(UIKit.card_panel(head))
	_update_ovr_label(p)
	# Identidade
	var names := UIKit.card("Card", 8)
	names.add_child(UIKit.section("Identidade"))
	names.add_child(_field("Nome", p.first_name, 24, func(t: String):
		if t.strip_edges() != "":
			p.first_name = t.strip_edges()))
	names.add_child(_field("Sobrenome", p.last_name, 28, func(t: String):
		if t.strip_edges() != "":
			p.last_name = t.strip_edges()))
	names.add_child(_field("Nome na camisa (vazio = sobrenome)", p.known_as, 20, func(t: String): p.known_as = t.strip_edges()))
	var nat_row := UIKit.hbox(8)
	nat_row.add_child(UIKit.label("Nacionalidade", "Small"))
	var nob := OptionButton.new()
	var codes: Array = DatabaseManager.nations().keys()
	codes.sort_custom(func(a, b): return DatabaseManager.nation_name(String(a)) < DatabaseManager.nation_name(String(b)))
	for i in codes.size():
		nob.add_item(DatabaseManager.nation_name(String(codes[i])), i)
		if String(codes[i]) == p.nationality:
			nob.select(i)
	nob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nob.item_selected.connect(func(i: int): p.nationality = String(codes[i]))
	nat_row.add_child(nob)
	names.add_child(nat_row)
	names.add_child(_stepper("Ano de nascimento", p.birth_year, w.year - 45, w.year - 15, func(v: int): p.birth_year = v,
		func(v: int): return "%d (%d anos)" % [v, w.year - v]))
	names.add_child(_stepper("Número da camisa", maxi(1, p.shirt), 1, 99, func(v: int): p.shirt = v))
	c.add_child(UIKit.card_panel(names))
	# Posições
	var pc := UIKit.card("Card", 8)
	pc.add_child(UIKit.section("Posição"))
	var pg := ButtonGroup.new()
	var pflow := UIKit.flow(8)
	for i in Pos.COUNT:
		var ps := i
		pflow.add_child(UIKit.chip(Pos.code(ps), ps == p.position, pg, func():
			p.secondary.erase(ps)
			p.position = ps
			p.recompute_overall()
			refresh()))
	pc.add_child(pflow)
	pc.add_child(UIKit.label("Outras posições (joga bem também em)", "Small"))
	var sflow := UIKit.flow(8)
	for i in Pos.COUNT:
		if i == p.position:
			continue
		var ps2 := i
		var sb := UIKit.chip(Pos.code(ps2), p.secondary.has(ps2), null, func():
			if p.secondary.has(ps2):
				p.secondary.erase(ps2)
			elif p.secondary.size() < 3:
				p.secondary.append(ps2)
			else:
				UIManager.toast("No máximo três posições extras.")
			refresh())
		sb.toggle_mode = true
		sb.button_pressed = p.secondary.has(ps2)
		sflow.add_child(sb)
	pc.add_child(sflow)
	c.add_child(UIKit.card_panel(pc))
	# Físico
	var fc := UIKit.card("Card", 8)
	fc.add_child(UIKit.section("Físico"))
	fc.add_child(_stepper("Altura", p.height, 155, 210, func(v: int): p.height = v, func(v: int): return "%d cm" % v))
	fc.add_child(_stepper("Peso", p.weight, 50, 110, func(v: int): p.weight = v, func(v: int): return "%d kg" % v))
	fc.add_child(UIKit.label("Pé preferido", "Small"))
	var fg := ButtonGroup.new()
	var frow := UIKit.hbox(8)
	frow.add_child(FootView.make(p.foot, 40))
	for i in Player.FOOT_NAMES.size():
		var fi := i
		var chip := UIKit.chip(Player.FOOT_NAMES[i], p.foot == fi, fg, func():
			p.foot = fi
			refresh())
		UIKit.shrink_button(chip)
		frow.add_child(chip)
	fc.add_child(frow)
	c.add_child(UIKit.card_panel(fc))
	# Nível
	var lc := UIKit.card("Card", 8)
	lc.add_child(UIKit.section("Nível"))
	lc.add_child(_stepper("Overall (ajusta todos os atributos juntos)", p.overall, 30, 99, func(v: int):
		PlayerMods.scale_to(p, v)
		p.potential = maxi(p.potential, p.overall)
		refresh.call_deferred()))
	lc.add_child(_stepper("Potencial (oculto no jogo)", p.potential, 30, 99, func(v: int):
		p.potential = maxi(v, p.overall)
		_update_ovr_label(p)))
	c.add_child(UIKit.card_panel(lc))
	c.add_child(_attrs_card(p))
	c.add_child(_traits_card(p))
	c.add_child(_look_card(p))
	# Rodapé
	var f := footer()
	UIKit.clear(f)
	var btns := UIKit.hbox(10)
	if has_career():
		var done := UIKit.button("PRONTO", "PrimaryButton", func():
			Valuation.update_value(p, w.year)
			GameManager.save_now()
			UIManager.toast("Jogador atualizado.")
			_go("pick_player"), "check")
		done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(done)
	else:
		var save := UIKit.button("SALVAR NO PADRÃO", "PrimaryButton", func():
			Valuation.update_value(p, w.year)
			var e := PlayerMods.snapshot(w, p, club, _match, _uid)
			PlayerMods.store(e)
			var marks: Dictionary = w.stats.get("pmods", {})
			marks[str(p.id)] = PlayerMods.entry_key(e)
			w.stats["pmods"] = marks
			UIManager.toast("Salvo: vale para as próximas carreiras.")
			_go("pick_player"), "check")
		save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btns.add_child(save)
		btns.add_child(UIKit.icon_button("close", func(): _remove_player_dialog(w, p, club), "Tirar do mundo ou desfazer"))
	f.add_child(btns)


## Editor geral: desfazer a personalização ou tirar o jogador do mundo padrão.
func _remove_player_dialog(w: GameWorld, p: Player, club: Club) -> void:
	var key := PlayerMods.key_of(w, p)
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label(p.display_name(), "Title"))
	if key != "":
		v.add_child(UIKit.button("Desfazer minhas mudanças", "", func():
			PlayerMods.unstore(key)
			UIManager.close_modal()
			UIManager.toast("Personalização removida (vale na próxima vez que o mundo for montado).")
			GameManager.preview_world = null
			_go("pick_player"), "back"))
	if _uid == "":
		v.add_child(UIKit.button("Tirar do mundo padrão", "", func():
			PlayerMods.store({"club": club.key if club != null else "", "match": _match, "remove": true})
			PlayerMods._remove(w, p)
			UIManager.close_modal()
			UIManager.toast("Jogador removido das próximas carreiras.")
			_go("pick_player"), "close"))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


func _update_ovr_label(p: Player) -> void:
	if _ovr_badge != null and is_instance_valid(_ovr_badge):
		_ovr_badge.value = p.overall
	if _ovr_label != null and is_instance_valid(_ovr_label):
		_ovr_label.text = "overall · potencial %d" % p.potential


## Linha com − valor +. `on_change(v)` aplica a mudança; `fmt(v)` devolve o texto mostrado.
func _stepper(caption: String, value: int, lo: int, hi: int, on_change: Callable, fmt: Callable = Callable()) -> Control:
	var row := UIKit.hbox(8)
	var l := UIKit.label(caption, "")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(l)
	var cur := [clampi(value, lo, hi)]
	var show := func(v: int) -> String: return String(fmt.call(v)) if fmt.is_valid() else str(v)
	var val := UIKit.label(show.call(cur[0]), "H3")
	val.custom_minimum_size.x = 150
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_step_btn("−", func():
		cur[0] = maxi(lo, cur[0] - 1)
		on_change.call(cur[0])
		val.text = show.call(cur[0])))
	row.add_child(val)
	row.add_child(_step_btn("+", func():
		cur[0] = mini(hi, cur[0] + 1)
		on_change.call(cur[0])
		val.text = show.call(cur[0])))
	return row


func _look_card(p: Player) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Aparência"))
	var w := _w()
	var feats := FaceGen.features(p.face_seed, p.eth, p.age(w.year), p.look)
	var top := UIKit.hbox(14)
	top.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 132))
	var picks := UIKit.vbox(4)
	picks.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picks.add_child(_cycler(p, "hs", "Penteado", FaceGen.HAIR_STYLES, int(feats["style"])))
	picks.add_child(_cycler(p, "bd", "Barba", FaceGen.BEARDS, int(feats["beard"])))
	picks.add_child(_cycler(p, "hc", "Cabelo", FaceGen.HAIR_COLOR_NAMES, int(feats["hair_i"])))
	top.add_child(picks)
	card.add_child(top)
	card.add_child(_cycler(p, "fs", "Rosto", FaceGen.FACE_SHAPES, int(feats["face_shape"])))
	card.add_child(_cycler(p, "ey", "Olhos", FaceGen.EYE_NAMES, int(feats["eye_i"])))
	card.add_child(UIKit.label("Tom de pele", "Small"))
	var sl := HSlider.new()
	sl.min_value = FaceGen.SKIN_MIN
	sl.max_value = FaceGen.SKIN_MAX
	sl.step = 0.25
	sl.value = float(feats["skin_i"])
	sl.custom_minimum_size.y = 48
	sl.drag_ended.connect(func(_changed: bool):
		p.look["sk"] = sl.value
		refresh())
	card.add_child(sl)
	card.add_child(UIKit.label("Beleza", "Small"))
	var bs := HSlider.new()
	bs.min_value = 0.0
	bs.max_value = 1.0
	bs.step = 0.05
	bs.value = float(feats["beauty"])
	bs.custom_minimum_size.y = 48
	bs.drag_ended.connect(func(_changed: bool):
		p.look["bt"] = bs.value
		refresh())
	card.add_child(bs)
	var row := UIKit.hbox(8)
	row.add_child(UIKit.button("Rosto aleatório", "", func():
		var keep_photo := String(p.look.get("photo", ""))
		p.face_seed = randi()
		p.look = {}
		if keep_photo != "":
			p.look["photo"] = keep_photo
		refresh(), "bolt"))
	row.add_child(UIKit.button("Voltar ao original", "GhostButton", func():
		var keep_photo := String(p.look.get("photo", ""))
		p.look = {}
		if keep_photo != "":
			p.look["photo"] = keep_photo
		refresh()))
	card.add_child(row)
	return UIKit.card_panel(card)


## "‹ Raspado ›": troca a opção de aparência para a anterior/próxima (a prévia acompanha).
func _cycler(p: Player, key: String, caption: String, names: Array, current: int) -> Control:
	var row := UIKit.hbox(6)
	var cl := UIKit.label(caption, "Small")
	cl.custom_minimum_size.x = 96
	row.add_child(cl)
	var step := func(d: int):
		p.look[key] = posmod(current + d, names.size())
		refresh()
	var prev := UIKit.icon_button("back", func(): step.call(-1), "Anterior")
	row.add_child(prev)
	var v := UIKit.label(String(names[clampi(current, 0, names.size() - 1)]), "H3")
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(v)
	row.add_child(UIKit.icon_button("forward", func(): step.call(1), "Próximo"))
	return row


## Atributos por grupo, com barra deslizante (o overall acompanha na hora).
func _attrs_card(p: Player) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Atributos"))
	var groups: Array = Attr.UI_GROUPS.duplicate()
	if p.position == Pos.GK:
		groups.push_front(["Goleiro", [Attr.GOL]])
	for grp in groups:
		card.add_child(UIKit.label(String(grp[0]).to_upper(), "Caps"))
		for ai_v in grp[1]:
			var ai: int = ai_v
			var row := UIKit.hbox(10)
			var nl := UIKit.label(Attr.name_of(ai), "")
			nl.custom_minimum_size.x = 210
			nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			row.add_child(nl)
			var sl := HSlider.new()
			sl.min_value = 1
			sl.max_value = 99
			sl.step = 1
			sl.value = p.attrs[ai]
			sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			sl.custom_minimum_size.y = 44
			row.add_child(sl)
			var val := UIKit.label(str(p.attrs[ai]), "Stat")
			val.custom_minimum_size.x = 50
			val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(val)
			sl.value_changed.connect(func(v: float):
				p.set_attr(ai, int(v))
				p.recompute_overall()
				p.potential = maxi(p.potential, p.overall)
				val.text = str(int(v))
				_update_ovr_label(p))
			card.add_child(row)
	return UIKit.card_panel(card)


func _step_btn(text: String, cb: Callable) -> Button:
	var b := UIKit.button(text, "GhostButton", cb)
	b.custom_minimum_size = Vector2(62, 52)
	return b


func _traits_card(p: Player) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Personalidade (até 2)"))
	var flow := UIKit.flow(6)
	for t in DatabaseManager.trait_ids():
		var tid: String = t
		var on := p.traits.has(tid)
		var b := UIKit.chip(String(DatabaseManager.trait_data(tid).get("name", tid)), on, null, func():
			var tr: Array = p.traits.duplicate()
			if tr.has(tid):
				tr.erase(tid)
			elif tr.size() < 2:
				tr.append(tid)
			else:
				UIManager.toast("No máximo duas características.")
				refresh()
				return
			p.set_traits(tr)
			refresh())
		b.toggle_mode = true
		b.button_pressed = on
		flow.add_child(b)
	card.add_child(flow)
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Competições
# ---------------------------------------------------------------------------

func _comp_picker(c: VBoxContainer) -> void:
	screen_subtitle = "Ligas e copas"
	var cups := UIKit.card("Card", 4)
	cups.add_child(UIKit.section("Copas internacionais"))
	for cid in DatabaseManager.cups_cfg():
		var id: String = cid
		if DatabaseManager.cup_cfg(id).has("nation"):
			continue # copas de um país ficam com as ligas dele
		cups.add_child(_comp_row("cups", id, CupManager.cup_name(id)))
	c.add_child(UIKit.card_panel(cups))
	if _nation == "":
		_nation = world().user_nation() if has_career() else "BRA"
	var nations: Array = DatabaseManager.league_nations()
	var ob := OptionButton.new()
	for i in nations.size():
		ob.add_item(DatabaseManager.nation_name(String(nations[i])), i)
		if String(nations[i]) == _nation:
			ob.select(i)
	ob.item_selected.connect(func(i: int):
		_nation = String(nations[i])
		refresh())
	c.add_child(ob)
	var leagues := UIKit.card("Card", 4)
	leagues.add_child(UIKit.section("Ligas"))
	for lid in DatabaseManager.leagues_of_nation(_nation):
		var id: String = lid
		leagues.add_child(_comp_row("leagues", id, String(DatabaseManager.league_cfg(id).get("name", id))))
	var first_cup := true
	for cid in DatabaseManager.cups_cfg():
		var cfg2: Dictionary = DatabaseManager.cup_cfg(cid)
		if String(cfg2.get("nation", "")) != _nation:
			continue
		if first_cup:
			leagues.add_child(UIKit.section("Copas do país"))
			first_cup = false
		leagues.add_child(_comp_row("cups", String(cid), CupManager.cup_name(String(cid))))
	c.add_child(UIKit.card_panel(leagues))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


func _comp_row(kind: String, id: String, name: String) -> Control:
	var row := UIKit.hbox(12)
	row.add_child(comp_logo(id, 40))
	var l := UIKit.label(name, "H3", true)
	row.add_child(l)
	if not Overrides.comp(kind, id).is_empty():
		row.add_child(UIKit.pill("EDITADO", UIColors.BLUE, 14))
	return UIKit.tap_row(row, func():
		_comp_kind = kind
		_comp_id = id
		_go("comp"))


static func comp_logo(id: String, px: int) -> Control:
	return UIKit.comp_logo(id, px)


func _comp_editor(c: VBoxContainer) -> void:
	var cfg: Dictionary = DatabaseManager.league_cfg(_comp_id) if _comp_kind == "leagues" else DatabaseManager.cup_cfg(_comp_id)
	screen_subtitle = String(cfg.get("name", _comp_id))
	var card := UIKit.card("Card", 10)
	var head := UIKit.hbox(14)
	head.add_child(comp_logo(_comp_id, 96))
	head.add_child(UIKit.label(String(cfg.get("name", _comp_id)), "Title", true))
	card.add_child(head)
	var name_v := [String(cfg.get("name", _comp_id))]
	var short_v := [String(cfg.get("short", _comp_id))]
	var logo_v := [String(cfg.get("logo", ""))]
	var cols := CompText.colors(_comp_id)
	var colors_v := ["#" + cols[0].to_html(false).to_upper(), "#" + cols[1].to_html(false).to_upper()]
	card.add_child(_field("Nome", name_v[0], 40, func(t: String): name_v[0] = t.strip_edges()))
	card.add_child(_field("Nome curto", short_v[0], 20, func(t: String): short_v[0] = t.strip_edges()))
	var row := UIKit.hbox(8)
	row.add_child(UIKit.button("Importar logo", "", func():
		ImagePicker.pick("logo", func(file: String):
			Overrides.store_comp(_comp_kind, _comp_id, name_v[0], short_v[0], file, colors_v)
			refresh()), "plus"))
	if logo_v[0] != "":
		row.add_child(UIKit.button("Remover logo", "GhostButton", func():
			CustomAssets.remove(logo_v[0])
			Overrides.store_comp(_comp_kind, _comp_id, name_v[0], short_v[0], "", colors_v)
			refresh()))
	card.add_child(row)
	c.add_child(UIKit.card_panel(card))
	var colors := UIKit.card("Card", 8)
	colors.add_child(UIKit.section("Cores"))
	colors.add_child(UIKit.comp_stripe(_comp_id, 10))
	for i in 2:
		var idx: int = i
		colors.add_child(UIKit.label("Principal" if idx == 0 else "Destaque", "Small"))
		colors.add_child(_swatches(colors_v[idx], func(hex: String):
			colors_v[idx] = hex
			Overrides.store_comp(_comp_kind, _comp_id, name_v[0], short_v[0], logo_v[0], colors_v)
			refresh()))
	c.add_child(UIKit.card_panel(colors))
	c.add_child(_scoreboard_card())
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("SALVAR", "PrimaryButton", func():
		if name_v[0] == "" or short_v[0] == "":
			UIManager.toast("Nome e nome curto não podem ficar vazios.")
			return
		Overrides.store_comp(_comp_kind, _comp_id, name_v[0], short_v[0], logo_v[0], colors_v)
		UIManager.toast("Competição atualizada.")
		_go("pick_comp"), "check"))


## Placar da transmissão: desenho e cores (vale na partida, na chamada do jogo e no painel).
func _scoreboard_card() -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Placar da TV"))
	var own := ScoreboardTheme.comp_style(_comp_id).duplicate(true)
	var th := ScoreboardTheme.for_competition(_w(), _comp_id)
	card.add_child(ScoreboardView.preview(_w(), _comp_id))
	card.add_child(UIKit.label("Desenho", "Small"))
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	var cur := String(own.get("layout", ""))
	var opts: Array = [""]
	opts.append_array(ScoreboardTheme.LAYOUTS)
	for l in opts:
		var layout: String = l
		var caption := "Automático (%s)" % ScoreboardTheme.layout_name(ScoreboardTheme.layout_for(_comp_id, false)) if layout == "" else ScoreboardTheme.layout_name(layout)
		flow.add_child(UIKit.chip(caption, cur == layout, g, func():
			if layout == "":
				own.erase("layout")
			else:
				own["layout"] = layout
			Overrides.store_scoreboard(_comp_kind, _comp_id, own)
			refresh()))
	card.add_child(flow)
	var bg: Color = th["bg"]
	var acc: Color = th["accent"]
	for i in 2:
		var idx: int = i
		card.add_child(UIKit.label("Fundo" if idx == 0 else "Destaque", "Small"))
		card.add_child(_swatches("#" + (bg if idx == 0 else acc).to_html(false), func(hex: String):
			var b := Color(hex) if idx == 0 else bg
			var a := Color(hex) if idx == 1 else acc
			own["colors"] = ["#" + b.to_html(false), "#" + b.lightened(0.1).to_html(false), "#" + a.to_html(false)]
			Overrides.store_scoreboard(_comp_kind, _comp_id, own)
			refresh()))
	if not own.is_empty():
		card.add_child(UIKit.button("Voltar ao placar original", "GhostButton", func():
			Overrides.store_scoreboard(_comp_kind, _comp_id, {})
			refresh()))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Mods
# ---------------------------------------------------------------------------

func _mods_view(c: VBoxContainer) -> void:
	screen_subtitle = "Mods"
	if not Store.unlocked():
		var lk := UIKit.card("CardHighlight", 10)
		lk.add_child(UIKit.label("Mods fazem parte da Carreira Completa", "Title", true))
		lk.add_child(UIKit.label("Requer a Carreira Completa (%s)." % Store.price(), "Muted", true))
		lk.add_child(UIKit.button("VER A CARREIRA COMPLETA", "PrimaryButton", func(): UIManager.push("paywall", {"reason": "mods"}), "star"))
		c.add_child(UIKit.card_panel(lk))
		return
	var list := Mods.list()
	c.add_child(_licensing_card(list))
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Pacotes"))
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum.", "Muted", true))
	else:
		card.add_child(UIKit.label("O de baixo ganha.", "Small", true))
	for m in list:
		var id := String(m["id"])
		var row := UIKit.hbox(10)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(m["name"]), "H3", true))
		var by := String(m["author"])
		var meta_parts: Array = []
		if by != "":
			meta_parts.append("por %s" % by)
		if String(m["version"]) != "":
			meta_parts.append("v%s" % m["version"])
		var meta := " · ".join(meta_parts)
		if meta != "":
			col.add_child(UIKit.label(meta, "Small"))
		var cnt := DropIns.counts(id)
		if not cnt.is_empty():
			var parts: Array = []
			for kind in DropIns.KINDS:
				if cnt.has(kind):
					parts.append("%s %d" % [DropIns.KIND_NAMES[kind], cnt[kind]])
			col.add_child(UIKit.label(" · ".join(parts), "Small", true))
			if bool(m["enabled"]):
				var miss := _misses(DropIns.report(id, _report_world()))
				if miss > 0:
					col.add_child(UIKit.colored("⚠ %d sem dono" % miss, UIColors.RED, "Small"))
		for pr in Mods.problems(id):
			col.add_child(UIKit.colored("⚠ %s: %s" % [pr["file"], pr["msg"]], UIColors.RED, "Small", true))
		row.add_child(col)
		if not cnt.is_empty():
			row.add_child(UIKit.icon_button("info", func(): _pack_files_dialog(id, String(m["name"])), "Arquivos"))
		if bool(m["enabled"]):
			row.add_child(UIKit.icon_button("up", func():
				Mods.move(id, -1)
				_mods_changed(), "Subir"))
			row.add_child(UIKit.icon_button("down", func():
				Mods.move(id, 1)
				_mods_changed(), "Descer"))
		var tg := CheckButton.new()
		tg.button_pressed = bool(m["enabled"])
		tg.toggled.connect(func(on: bool):
			Mods.set_enabled(id, on)
			_mods_changed())
		row.add_child(tg)
		row.add_child(UIKit.icon_button("close", func():
			UIManager.confirm("Apagar \"%s\"?" % String(m["name"]), "Carreiras começadas continuam como estão.", "Apagar", func():
				Mods.remove(id)
				_mods_changed()), "Apagar"))
		card.add_child(row)
	c.add_child(UIKit.card_panel(card))
	var act := UIKit.card("Card", 8)
	act.add_child(UIKit.section("Minhas edições"))
	act.add_child(UIKit.button("Exportar como mod", "", func(): _export_mod_dialog(), "save"))
	act.add_child(UIKit.button("Exportar como pasta", "", func(): _export_folder_dialog(), "list"))
	act.add_child(UIKit.button("Como criar um mod", "GhostButton", func(): _mods_help(), "info"))
	c.add_child(UIKit.card_panel(act))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


## Licenciamento: pasta, recarregar, importar/exportar pacote, modelo e o que casou.
func _licensing_card(list: Array) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Licenciamento"))
	# Totais das imagens soltas nos pacotes ligados
	var ok := {}
	var miss := {}
	for m in list:
		if not bool(m["enabled"]):
			continue
		var rep := DropIns.report(String(m["id"]), _report_world())
		for kind in rep:
			ok[kind] = int(ok.get(kind, 0)) + rep[kind]["ok"].size()
			miss[kind] = int(miss.get(kind, 0)) + rep[kind]["miss"].size()
	var grid := GridContainer.new()
	grid.columns = 5 if UILayout.is_wide() else 3
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for kind in DropIns.KINDS:
		var n := int(ok.get(kind, 0))
		var bad := int(miss.get(kind, 0))
		var t := UIKit.stat_tile("%d" % n if bad == 0 else "%d/%d" % [n, n + bad], String(DropIns.KIND_NAMES[kind]),
			UIColors.RED if bad > 0 else (UIColors.GREEN if n > 0 else Color(0, 0, 0, 0)))
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	card.add_child(grid)
	var btns: Array = [
		UIKit.button("Recarregar", "PrimaryButton", func(): _reload_mods(), "swap"),
		UIKit.button("Importar", "", func(): _pick_mod_file(), "plus"),
		UIKit.button("Exportar", "", func(): _export_pack_dialog(), "save"),
		UIKit.button("Gerar modelo", "", func(): _make_template(), "table"),
	]
	var path := ProjectSettings.globalize_path(Mods.DIR)
	if OS.has_feature("pc"):
		btns.append(UIKit.button("Abrir pasta", "GhostButton", func():
			DirAccess.make_dir_recursive_absolute(Mods.DIR)
			OS.shell_open(path), "list"))
	var bg := GridContainer.new()
	bg.columns = 2
	bg.add_theme_constant_override(&"h_separation", 8)
	bg.add_theme_constant_override(&"v_separation", 8)
	for b: Control in btns:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bg.add_child(b)
	card.add_child(bg)
	var pl := UIKit.label(path.path_join("…") + "/" + " · ".join(DropIns.KINDS), "Small", true)
	pl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	card.add_child(pl)
	return UIKit.card_panel(card)


## Mundo para conferir as fotos de jogadores: o da carreira ou o do Editor geral, se já existir.
func _report_world() -> GameWorld:
	return world() if has_career() else GameManager.preview_world


func _misses(rep: Dictionary) -> int:
	var n := 0
	for kind in rep:
		n += rep[kind]["miss"].size()
	return n


## Arquivos de um pacote: com quem cada um casou e os que ficaram sem dono.
func _pack_files_dialog(id: String, title: String) -> void:
	var v := UIKit.vbox(8)
	v.custom_minimum_size.x = 620
	v.add_child(UIKit.label(title, "Title"))
	var rep := DropIns.report(id, _report_world()) if Mods.active_ids().has(id) else {}
	if rep.is_empty():
		v.add_child(UIKit.label("Desligado.", "Muted"))
	for kind in DropIns.KINDS:
		if not rep.has(kind):
			continue
		v.add_child(UIKit.section(String(DropIns.KIND_NAMES[kind])))
		for f in rep[kind]["miss"]:
			v.add_child(UIKit.colored("✕ " + String(f).get_file(), UIColors.RED, "Small", true))
		for pair in rep[kind]["ok"]:
			var who := String(pair[1])
			v.add_child(UIKit.label("✓ %s → %s" % [String(pair[0]).get_file(), who if who != "?" else "(abra uma carreira)"], "Small", true))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


## Relê pastas e pacotes. Sem carreira, recarrega os dados; com carreira, só as imagens.
func _reload_mods() -> void:
	Mods.rescan()
	_mods_changed()


## Depois de ligar/desligar/apagar/recarregar: sem carreira, relê os dados na hora; com carreira,
## escudos e camisas soltos entram no mundo aberto.
func _mods_changed() -> void:
	if not has_career():
		DatabaseManager.reload()
		GameManager.preview_world = null
	else:
		DropIns.rescan()
		DropIns.apply_world(world())
	UIManager.toast("Mods recarregados.")
	refresh()


func _export_pack_dialog() -> void:
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Exportar pacote", "Title"))
	var name_v := ["Meu pacote"]
	var author_v := [world().manager_name if has_career() else ""]
	v.add_child(_field("Nome", name_v[0], 40, func(t: String): name_v[0] = t.strip_edges()))
	v.add_child(_field("Autor", author_v[0], 40, func(t: String): author_v[0] = t.strip_edges()))
	v.add_child(UIKit.button("EXPORTAR", "PrimaryButton", func():
		var r := LicensePack.export_pack(name_v[0] if name_v[0] != "" else "Meu pacote", author_v[0])
		UIManager.close_modal()
		var ct: Dictionary = r["counts"]
		var summary := "%d clubes · %d competições · %d jogadores · %d imagens" % [ct["clubs"], ct["comps"], ct["players"], ct["images"]]
		if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
			DisplayServer.file_dialog_show("Salvar pacote", "", String(r["zip"]).get_file(), false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
				PackedStringArray(["*.zip ; Pacote"]), func(status: bool, paths: PackedStringArray, _idx: int):
					if status and not paths.is_empty():
						var okc := DirAccess.copy_absolute(String(r["zip_local"]), paths[0]) == OK
						UIManager.toast(summary if okc else "Não foi possível salvar aí.", UIColors.GREEN if okc else UIColors.RED))
			return
		UIManager.info("Pacote exportado", summary + "\n\n" + String(r["zip"])), "save"))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


## Pacote vazio com a planilha de nomes (ids e nomes atuais) e as pastas de imagens.
func _make_template() -> void:
	var done := func(w: GameWorld):
		var r := LicensePack.make_template(w)
		if r.is_empty():
			UIManager.toast("Não foi possível criar o modelo.", UIColors.RED)
			return
		Mods.rescan()
		refresh()
		UIManager.info("Modelo criado", "%d linhas\n\n%s" % [int(r["rows"]), r["csv"]])
	var w := world() if has_career() else GameManager.preview_world
	if w != null and w.world_seed == WorldGenerator.DEFAULT_SEED:
		done.call(w)
		return
	UIManager.toast("Gerando o modelo…")
	GameManager.ensure_preview_world(func(): done.call(GameManager.preview_world))


func _pick_mod_file() -> void:
	var filters := PackedStringArray(["*.zip, *.json, *.csv ; Mods e pacotes"])
	var finish := func(path: String):
		var r := Mods.install(path)
		UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] else UIColors.RED)
		if r["ok"]:
			_mods_changed()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Escolha o pacote", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(status: bool, paths: PackedStringArray, _idx: int):
				if status and not paths.is_empty():
					finish.call(paths[0]))
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = filters
	fd.title = "Escolha o pacote"
	fd.size = Vector2i(680, 900)
	UIManager.main.add_child(fd)
	fd.file_selected.connect(func(path: String):
		finish.call(path)
		fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered()


func _export_mod_dialog() -> void:
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Exportar como mod", "Title"))
	v.add_child(UIKit.label("Clubes, competições e jogadores editados, com as imagens.", "Small", true))
	var name_v := ["Meu mod"]
	var author_v := [world().manager_name if has_career() else ""]
	v.add_child(_field("Nome do mod", name_v[0], 40, func(t: String): name_v[0] = t.strip_edges()))
	v.add_child(_field("Autor", author_v[0], 40, func(t: String): author_v[0] = t.strip_edges()))
	v.add_child(UIKit.button("EXPORTAR", "PrimaryButton", func():
		var bundle := Mods.export_bundle(name_v[0] if name_v[0] != "" else "Meu mod", author_v[0])
		var fname: String = (name_v[0] if name_v[0] != "" else "mod").validate_filename().replace(" ", "_") + ".json"
		UIManager.close_modal()
		_save_export(fname, JSON.stringify(bundle, "\t")), "save"))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


## Exporta as personalizações numa pasta de mod (JSON legível, imagens em img/) e num .zip ao lado.
func _export_folder_dialog() -> void:
	var v := UIKit.vbox(12)
	v.add_child(UIKit.label("Exportar como pasta", "Title"))
	v.add_child(UIKit.label("Pasta com JSON e imagens para editar à mão; um .zip fica em exports/.", "Small", true))
	var name_v := ["Meu mod"]
	var author_v := [world().manager_name if has_career() else ""]
	v.add_child(_field("Nome do mod", name_v[0], 40, func(t: String): name_v[0] = t.strip_edges()))
	v.add_child(_field("Autor", author_v[0], 40, func(t: String): author_v[0] = t.strip_edges()))
	v.add_child(UIKit.button("EXPORTAR", "PrimaryButton", func():
		var r := Mods.export_folder(name_v[0] if name_v[0] != "" else "Meu mod", author_v[0])
		UIManager.close_modal()
		refresh()
		UIManager.info("Pasta de mod criada", "Pasta:\n%s\n\nZip:\n%s" % [r["folder"], r["zip"]]), "save"))
	v.add_child(UIKit.button("Cancelar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


## Grava o mod exportado onde o usuário escolher (ou em Documentos / pasta do jogo).
func _save_export(fname: String, text: String) -> void:
	var write := func(path: String) -> bool:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(text)
		return true
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Salvar mod", "", fname, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json ; Mod"]),
			func(status: bool, paths: PackedStringArray, _idx: int):
				if status and not paths.is_empty():
					UIManager.toast("Mod salvo." if write.call(paths[0]) else "Não foi possível salvar aí.", UIColors.GREEN))
		return
	var docs := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	var target := docs.path_join(fname) if docs != "" else ""
	if target == "" or not write.call(target):
		DirAccess.make_dir_recursive_absolute("user://exports")
		target = ProjectSettings.globalize_path("user://exports/" + fname)
		write.call(target)
	UIManager.info("Mod exportado", "Arquivo salvo em:\n%s" % target)


func _mods_help() -> void:
	var v := UIKit.vbox(10)
	v.custom_minimum_size.x = 620
	v.add_child(UIKit.label("Como criar um mod", "Title"))
	for t in [
		["1. O jeito fácil", "Solte imagens em crests/, logos/, cutouts/, kits/ ou stadiums/ dentro de uma pasta de pacote, com o nome do clube, da competição ou do jogador, e toque em Recarregar. Para nomes: Gerar modelo, preencha o names.csv e Recarregar."],
		["2. Jogadores reais", "No mod, o players.json lista jogadores: com \"match\" edita um jogador gerado (pelo nome original), sem \"match\" cria um novo e com \"remove\": true tira do mundo. Campos: club, first, last, known, nat, pos, sec, birth, height, weight, foot, shirt, ovr, pot, attrs, traits."],
		["3. Mudar qualquer dado", "Todos os dados do jogo são JSON em data/. Um arquivo data/<caminho>.json no mod substitui o original; um data/<caminho>.patch.json muda só o que você escrever. Em listas, use {\"_by\": \"key\", \"items\": [...]} para mexer em itens pela chave."],
		["4. Estádios, uniformes e placares", "No arquivo de clubes, \"stadium\" pode ser um objeto {name, capacity, kind, photo, nick, built} e \"kits\" traz os uniformes (também por temporada). Nas ligas e copas, \"scoreboard\": {layout, colors} escolhe o placar da TV. Imagens vão em img/ do mod."],
		["5. Exemplos", "Renomear clube: data/world/clubs/BRA.patch.json. Regras das copas: data/world/domestic.patch.json (fases em ida e volta, vagas). Vagas continentais: data/world/continental.patch.json. Narração e notícias: data/text/."],
		["Documentação completa", "docs/MODS.md no repositório do jogo, com o formato de cada arquivo."]]:
		v.add_child(UIKit.label(String(t[0]), "H3"))
		v.add_child(UIKit.label(String(t[1]), "Small", true))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)
