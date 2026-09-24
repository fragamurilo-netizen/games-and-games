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


func _init() -> void:
	show_nav = false
	screen_title = "Editor"


func setup(p: Dictionary) -> void:
	super.setup(p)
	if p.has("player"):
		_view = "player"
		_pid = int(p["player"])
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
	screen_subtitle = "Personalize o seu futebol"
	var items: Array = []
	if has_career():
		items.append(["shield", "Meu clube", "Nome, cores, escudo e imagem do escudo", func():
			_club = world().user_club()
			_club_dirty.clear()
			_go("club")])
	items.append(["search", "Clubes", "Qualquer clube do mundo" + ("" if has_career() else " (padrão das novas carreiras)"), func(): _go("pick_club")])
	if has_career():
		items.append(["shirt", "Jogadores", "Nome, posição, aparência, foto, atributos e personalidade", func(): _go("pick_player")])
	items.append(["trophy", "Competições", "Nomes, logos e cores de ligas e copas", func(): _go("pick_comp")])
	if has_career():
		items.append(["star", "Treinador", "Seu nome na carreira", func(): _manager_name()])
	for it in items:
		var row := UIKit.hbox(14)
		row.add_child(UIKit.icon_rect(String(it[0]), 40, UIColors.ACCENT))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(it[1]), "H2"))
		col.add_child(UIKit.label(String(it[2]), "Small", true))
		row.add_child(col)
		c.add_child(UIKit.tap_row(row, it[3], "Card"))
	var info := UIKit.card("Card", 6)
	info.add_child(UIKit.label("Imagens importadas (escudos, logos e fotos) ficam guardadas no aparelho e são recortadas em quadrado automaticamente.", "Small", true))
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
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for id in leagues:
		var lid: String = id
		flow.add_child(UIKit.chip(String(DatabaseManager.league_cfg(lid).get("short", lid)), lid == _league, g, func():
			_league = lid
			refresh()))
	c.add_child(flow)
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
		card.add_child(UIKit.label("Esta liga só tem clubes gerados na hora da carreira: edite-os com uma carreira aberta.", "Muted", true))
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
	row.add_child(UIKit.kit(cl.kit_home, 96, 10))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(cl.name, "Title", true))
	col.add_child(UIKit.label("%s · %s" % [cl.abbr, cl.city], "Small", true))
	row.add_child(col)
	head.add_child(row)
	c.add_child(UIKit.card_panel(head))
	var names := UIKit.card("Card", 8)
	names.add_child(UIKit.section("Identidade"))
	for f in [["name", "Nome completo", cl.name, 40], ["short", "Nome curto", cl.short_name, 20], ["abbr", "Sigla", cl.abbr, 4], ["nick", "Apelido", cl.nickname, 24], ["city", "Cidade", cl.city, 28], ["stadium", "Estádio", cl.stadium, 36]]:
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
		card.add_child(UIKit.label("Usando a imagem importada. As opções abaixo valem para o escudo desenhado.", "Small", true))
	for group in [["shape", "Formato", ClubGenerator.CREST_SHAPES, ClubGenerator.CREST_SHAPE_NAMES], ["symbol", "Símbolo", ClubGenerator.CREST_SYMBOLS, ClubGenerator.CREST_SYMBOL_NAMES], ["border", "Borda", ClubGenerator.CREST_BORDERS, ["Sem borda", "Fina", "Grossa", "Dupla"]]]:
		var key: String = group[0]
		card.add_child(UIKit.label(String(group[1]), "Small"))
		var g := ButtonGroup.new()
		var flow := UIKit.flow(8)
		var vals: Array = group[2]
		var labels: Array = group[3]
		for i in vals.size():
			var val: String = vals[i]
			flow.add_child(UIKit.chip(String(labels[i]), String(cl.crest.get(key, "")) == val, g, func():
				cl.crest[key] = val
				_mark("crest")
				refresh()))
		card.add_child(flow)
	var st := UIKit.hbox(10)
	var sl := UIKit.label("Listras", "")
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.add_child(sl)
	var cb := CheckButton.new()
	cb.button_pressed = bool(cl.crest.get("stripes", false))
	cb.toggled.connect(func(on: bool):
		cl.crest["stripes"] = on
		_mark("crest")
		refresh())
	st.add_child(cb)
	card.add_child(st)
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
		"nick":
			cl.nickname = v
		"city":
			cl.city = v
		"stadium":
			cl.stadium = v
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

func _player_picker(c: VBoxContainer) -> void:
	var w := world()
	screen_subtitle = "Escolha um jogador"
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
	c.add_child(srow)
	var card := UIKit.card("Card", 4)
	var list: Array = []
	if _search.length() >= 3:
		var q := _search.to_lower()
		for p: Player in w.players.values():
			if (p.first_name + " " + p.last_name + " " + p.known_as).to_lower().contains(q):
				list.append(p)
				if list.size() >= 60:
					break
		card.add_child(UIKit.section("Resultados"))
	else:
		list = w.squad(w.user_club())
		list.append_array(YouthManager.academy(w))
		card.add_child(UIKit.section("Seu elenco e a base"))
	for p: Player in list:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 52))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(p.display_name(), "H3"))
		var cl := w.club(p.club_id)
		col.add_child(UIKit.label("%s · %s" % [Pos.code(p.position), cl.short_name if cl != null else "Sem clube"], "Small"))
		row.add_child(col)
		row.add_child(UIKit.badge(p.overall, 52, 38, 22))
		var pid := p.id
		card.add_child(UIKit.tap_row(row, func():
			_pid = pid
			_go("player")))
	if list.is_empty():
		card.add_child(UIKit.label("Ninguém encontrado.", "Muted"))
	c.add_child(UIKit.card_panel(card))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


# ---------------------------------------------------------------------------
# Editar jogador
# ---------------------------------------------------------------------------

func _player_editor(c: VBoxContainer) -> void:
	var w := world()
	var p: Player = w.player(_pid) if w != null else null
	if p == null:
		_go("home")
		return
	screen_subtitle = p.display_name()
	var club := w.club(p.club_id)
	var head := UIKit.card("CardHighlight", 10)
	var row := UIKit.hbox(16)
	row.add_child(UIKit.portrait(p, club, w.year, 150))
	var col := UIKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(p.full_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.name_of(p.position), p.age(w.year), p.playstyle()], "Small", true))
	var ob := UIKit.hbox(8)
	ob.add_child(UIKit.badge(p.overall))
	ob.add_child(UIKit.label("overall", "Small"))
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
	c.add_child(UIKit.card_panel(head))
	# Nomes
	var names := UIKit.card("Card", 8)
	names.add_child(UIKit.section("Nome"))
	names.add_child(_field("Nome", p.first_name, 24, func(t: String):
		if t.strip_edges() != "":
			p.first_name = t.strip_edges()))
	names.add_child(_field("Sobrenome", p.last_name, 28, func(t: String):
		if t.strip_edges() != "":
			p.last_name = t.strip_edges()))
	names.add_child(_field("Conhecido como (vazio = sobrenome)", p.known_as, 20, func(t: String): p.known_as = t.strip_edges()))
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
	c.add_child(UIKit.card_panel(names))
	# Posição
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
	c.add_child(UIKit.card_panel(pc))
	# Aparência
	c.add_child(_look_card(p))
	# Atributos
	c.add_child(_attrs_card(p))
	# Personalidade
	c.add_child(_traits_card(p))
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("PRONTO", "PrimaryButton", func():
		Valuation.update_value(p, w.year)
		GameManager.save_now()
		UIManager.toast("Jogador atualizado.")
		_go("pick_player"), "check"))


func _look_card(p: Player) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Aparência"))
	var feats := FaceGen.features(p.face_seed, p.eth, p.age(world().year), p.look)
	card.add_child(UIKit.label("Penteado", "Small"))
	card.add_child(_look_chips(p, "hs", FaceGen.HAIR_STYLES, int(feats["style"])))
	card.add_child(UIKit.label("Barba", "Small"))
	card.add_child(_look_chips(p, "bd", FaceGen.BEARDS, int(feats["beard"])))
	card.add_child(UIKit.label("Cor do cabelo", "Small"))
	card.add_child(_look_chips(p, "hc", FaceGen.HAIR_COLOR_NAMES, int(feats["hair_i"])))
	card.add_child(UIKit.label("Tom de pele", "Small"))
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 9.0
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
	card.add_child(UIKit.label("Olhos", "Small"))
	card.add_child(_look_chips(p, "ey", FaceGen.EYE_NAMES, int(feats["eye_i"])))
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


func _look_chips(p: Player, key: String, names: Array, current: int) -> Control:
	var g := ButtonGroup.new()
	var flow := UIKit.flow(6)
	for i in names.size():
		var idx := i
		var chip := UIKit.chip(String(names[i]), i == current, g, func():
			p.look[key] = idx
			refresh())
		chip.add_theme_font_size_override(&"font_size", 17)
		flow.add_child(chip)
	return flow


func _attrs_card(p: Player) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Atributos"))
	card.add_child(UIKit.label("Mexer nos atributos muda o overall e o valor de mercado na hora.", "Small", true))
	for i in Attr.COUNT:
		var ai := i
		var row := UIKit.hbox(8)
		var nl := UIKit.label(Attr.NAMES[i], "")
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var val := UIKit.label(str(p.attrs[i]), "Stat")
		val.custom_minimum_size.x = 50
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		for d in [-5, -1]:
			var dd: int = d
			row.add_child(_step_btn(str(dd), func():
				p.set_attr(ai, p.attrs[ai] + dd)
				p.recompute_overall()
				p.potential = maxi(p.potential, p.overall)
				val.text = str(p.attrs[ai])))
		row.add_child(val)
		for d in [1, 5]:
			var dd: int = d
			row.add_child(_step_btn("+%d" % dd, func():
				p.set_attr(ai, p.attrs[ai] + dd)
				p.recompute_overall()
				p.potential = maxi(p.potential, p.overall)
				val.text = str(p.attrs[ai])))
		card.add_child(row)
	var pot := UIKit.hbox(8)
	var pl := UIKit.label("Potencial (oculto no jogo)", "")
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pot.add_child(pl)
	var pv := UIKit.label(str(p.potential), "Stat")
	pv.custom_minimum_size.x = 50
	pot.add_child(_step_btn("-", func():
		p.potential = maxi(p.overall, p.potential - 1)
		pv.text = str(p.potential)))
	pot.add_child(pv)
	pot.add_child(_step_btn("+", func():
		p.potential = mini(99, p.potential + 1)
		pv.text = str(p.potential)))
	card.add_child(pot)
	card.add_child(UIKit.button("Atualizar overall", "GhostButton", func(): refresh()))
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
	cups.add_child(UIKit.section("Copas"))
	for cid in DatabaseManager.cups_cfg():
		var id: String = cid
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
	card.add_child(UIKit.label("Os nomes das competições valem para todas as carreiras. Copas já sorteadas nesta temporada mudam de nome na próxima.", "Small", true))
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
	colors.add_child(UIKit.label("As cores aparecem no selo da competição, nas tabelas e na próxima partida.", "Small", true))
	c.add_child(UIKit.card_panel(colors))
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("SALVAR", "PrimaryButton", func():
		if name_v[0] == "" or short_v[0] == "":
			UIManager.toast("Nome e nome curto não podem ficar vazios.")
			return
		Overrides.store_comp(_comp_kind, _comp_id, name_v[0], short_v[0], logo_v[0], colors_v)
		UIManager.toast("Competição atualizada.")
		_go("pick_comp"), "check"))
