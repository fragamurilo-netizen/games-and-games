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


func _init() -> void:
	show_nav = false
	screen_title = "Editor"


func setup(p: Dictionary) -> void:
	super.setup(p)
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
	screen_subtitle = "Personalize o seu futebol" if has_career() else "Mundo padrão das novas carreiras"
	var items: Array = []
	var edit_ok := not has_career() or AppSettings.career_edit
	if has_career():
		items.append(["shield", "Meu clube", "Nome, cores, escudo e imagem do escudo", func():
			_club = world().user_club()
			_club_dirty.clear()
			_go("club")])
	if edit_ok:
		items.append(["search", "Clubes", "Qualquer clube do mundo" + ("" if has_career() else ": nomes, cores e escudos"), func(): _go("pick_club")])
		items.append(["shirt", "Jogadores", "Editar qualquer jogador ou criar jogadores reais: nome, posições, físico, atributos, foto e aparência" if not has_career() else "Nome, posição, físico, atributos, foto e personalidade", func(): _go("pick_player")])
	items.append(["trophy", "Competições", "Nomes, logos e cores de ligas e copas", func(): _go("pick_comp")])
	if has_career():
		items.append(["star", "Treinador", "Seu nome na carreira", func(): _manager_name()])
	items.append(["list", "Mods", "Instalar, ligar e criar mods; exportar suas personalizações", func(): _go("mods")])
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
	if has_career() and not AppSettings.career_edit:
		info.add_child(UIKit.label("Para editar jogadores e outros clubes nesta carreira, ligue \"Editar jogadores e clubes durante a carreira\" em Opções. No Editor do menu inicial você sempre edita o mundo padrão das novas carreiras.", "Small", true))
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
	var key_l := UIKit.label("Chave para mods: %s" % cl.key, "Small")
	key_l.add_theme_color_override(&"font_color", UIColors.DIM)
	col.add_child(key_l)
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
		_mark("crest")
		refresh()))
	st.add_child(UIKit.label(str(stars), ""))
	st.add_child(UIKit.button("+", "GhostButton", func():
		cl.crest["stars"] = mini(7, stars + 1)
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
		_mark("crest")
		refresh())
	cw.add_child(cb)
	card.add_child(cw)
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

## Mundo em edição: o da carreira ou, no Editor geral, o mundo padrão carregado para edição.
func _w() -> GameWorld:
	return world() if has_career() else GameManager.preview_world


func _player_picker(c: VBoxContainer) -> void:
	screen_subtitle = "Escolha um jogador"
	var w := _w()
	if w == null:
		var wait := UIKit.card("Card", 8)
		wait.add_child(UIKit.label("Carregando o mundo padrão…", "H2"))
		wait.add_child(UIKit.label("Uns segundos: o editor monta os 672 clubes com os elencos que as novas carreiras vão receber, já com as suas personalizações.", "Small", true))
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
			c.add_child(UIKit.label("Toque num clube para ver o elenco.", "Muted", true))
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
		head.add_child(UIKit.label("Editor geral: salvar grava este jogador no mundo padrão das próximas carreiras (e entra em \"Exportar como mod\").", "Small", true))
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


# ---------------------------------------------------------------------------
# Mods
# ---------------------------------------------------------------------------

func _mods_view(c: VBoxContainer) -> void:
	screen_subtitle = "Mods"
	if not Store.unlocked():
		var lk := UIKit.card("CardHighlight", 10)
		lk.add_child(UIKit.label("Mods fazem parte da Carreira Completa", "Title", true))
		lk.add_child(UIKit.label("Instale mods, ligue e desligue e exporte suas personalizações depois de desbloquear a Carreira Completa (pagamento único de %s)." % Store.price(), "Muted", true))
		lk.add_child(UIKit.button("VER A CARREIRA COMPLETA", "PrimaryButton", func(): UIManager.push("paywall", {"reason": "mods"}), "star"))
		c.add_child(UIKit.card_panel(lk))
		return
	var intro := UIKit.card("Card", 6)
	intro.add_child(UIKit.label("Mods mudam os dados do jogo (clubes, ligas, copas, regras, textos) e colocam jogadores reais nos elencos. Os ligados valem na ordem da lista: o de baixo ganha.", "Small", true))
	if has_career():
		intro.add_child(UIKit.label("Com uma carreira aberta, ligar ou desligar um mod vale para as próximas carreiras (e quando você reabrir o jogo).", "Small", true))
	c.add_child(UIKit.card_panel(intro))
	var list := Mods.list()
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Instalados"))
	if list.is_empty():
		card.add_child(UIKit.label("Nenhum mod instalado ainda.", "Muted", true))
	for m in list:
		var id := String(m["id"])
		var row := UIKit.hbox(10)
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(m["name"]), "H3", true))
		var by := String(m["author"])
		col.add_child(UIKit.label(("por %s" % by if by != "" else "") + (" · v%s" % m["version"] if String(m["version"]) != "" else ""), "Small"))
		if String(m["description"]) != "":
			col.add_child(UIKit.label(String(m["description"]), "Small", true))
		row.add_child(col)
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
			UIManager.confirm("Apagar o mod?", "\"%s\" sai do aparelho. Carreiras já começadas continuam como estão." % String(m["name"]), "Apagar", func():
				Mods.remove(id)
				_mods_changed()), "Apagar"))
		card.add_child(row)
	c.add_child(UIKit.card_panel(card))
	var act := UIKit.card("Card", 8)
	act.add_child(UIKit.section("Criar e compartilhar"))
	act.add_child(UIKit.button("Instalar mod (.zip ou .json)", "", func(): _pick_mod_file(), "plus"))
	act.add_child(UIKit.button("Exportar minhas personalizações como mod", "", func(): _export_mod_dialog(), "save"))
	act.add_child(UIKit.button("Como criar um mod", "GhostButton", func(): _mods_help(), "info"))
	var path := ProjectSettings.globalize_path(Mods.DIR)
	act.add_child(UIKit.label("Pasta dos mods: %s" % path, "Small", true))
	if OS.has_feature("pc"):
		act.add_child(UIKit.button("Abrir a pasta", "GhostButton", func():
			DirAccess.make_dir_recursive_absolute(Mods.DIR)
			OS.shell_open(path)))
	c.add_child(UIKit.card_panel(act))
	c.add_child(UIKit.button("Voltar", "GhostButton", func(): _go("home")))


## Depois de ligar/desligar/apagar: sem carreira, relê os dados na hora.
func _mods_changed() -> void:
	if not has_career():
		DatabaseManager.reload()
		GameManager.preview_world = null
		UIManager.toast("Dados recarregados com os mods ligados.")
	refresh()


func _pick_mod_file() -> void:
	var filters := PackedStringArray(["*.zip, *.json ; Mods"])
	var finish := func(path: String):
		var r := Mods.install(path)
		UIManager.toast(String(r["msg"]), UIColors.GREEN if r["ok"] else UIColors.RED)
		if r["ok"]:
			_mods_changed()
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Escolha o mod", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(status: bool, paths: PackedStringArray, _idx: int):
				if status and not paths.is_empty():
					finish.call(paths[0]))
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = filters
	fd.title = "Escolha o mod"
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
	v.add_child(UIKit.label("Junta num arquivo só os clubes, competições e jogadores que você editou no padrão, com as imagens. Quem instalar recebe tudo igual.", "Small", true))
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
		["1. O jeito fácil", "Edite clubes, competições e jogadores aqui no Editor do menu inicial e use \"Exportar minhas personalizações como mod\". O arquivo .json pode ser mandado para qualquer pessoa, que instala com \"Instalar mod\"."],
		["2. Jogadores reais", "No mod, o players.json lista jogadores: com \"match\" edita um jogador gerado (pelo nome original), sem \"match\" cria um novo e com \"remove\": true tira do mundo. Campos: club, first, last, known, nat, pos, sec, birth, height, weight, foot, shirt, ovr, pot, attrs, traits."],
		["3. Mudar qualquer dado", "Todos os dados do jogo são JSON em data/. Um arquivo data/<caminho>.json no mod substitui o original; um data/<caminho>.patch.json muda só o que você escrever. Em listas, use {\"_by\": \"key\", \"items\": [...]} para mexer em itens pela chave."],
		["4. Exemplos", "Renomear clube: data/world/clubs/BRA.patch.json. Regras das copas: data/world/domestic.patch.json (fases em ida e volta, vagas). Vagas continentais: data/world/continental.patch.json. Narração e notícias: data/text/."],
		["Documentação completa", "docs/MODS.md no repositório do jogo, com o formato de cada arquivo."]]:
		v.add_child(UIKit.label(String(t[0]), "H3"))
		v.add_child(UIKit.label(String(t[1]), "Small", true))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)
