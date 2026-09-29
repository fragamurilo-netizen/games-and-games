extends BaseScreen
## Nova carreira: mundo (padrão/aleatório + seed), dificuldade, nome, país, divisão e clube.
## O mundo começa a ser gerado ao abrir a tela; escolher país e clube acontece enquanto isso.

const CONFEDS: Array = [["UEFA", "Europa"], ["CONMEBOL", "América do Sul"], ["CONCACAF", "América do Norte"], ["CAF", "África"], ["AFC", "Ásia"]]

const STEPS := [["setup", "Carreira"], ["nation", "País"], ["club", "Clube"]]

var _world: GameWorld = null
var _type := "padrao"
var _seed := WorldGenerator.DEFAULT_SEED
var _difficulty := GameWorld.DIFF_NORMAL
var _confed := "CONMEBOL"
var _nation := "BRA"
var _league := "BRA1"
var _selected := -1
var _manager := "Treinador"
var _step := 0
var _nations_box: Control
var _leagues_row: Control
var _list: Container
var _details: VBoxContainer
var _status: Label
var _seed_edit: LineEdit
var _start_btn: Button
var _built := false


func _init() -> void:
	screen_title = "Nova carreira"
	screen_subtitle = ""
	show_nav = false


func on_show() -> void:
	if not _built:
		_built = true
		_generate()
	_build()


func refresh() -> void:
	if _built:
		_build()


## Assistente em três passos (carreira → país → clube), com o indicador no topo e os botões
## de voltar/avançar fixos no rodapé. O mundo é gerado em segundo plano desde o início.
func _build() -> void:
	StadiumBackdrop.attach(self)
	var c := content()
	UIKit.clear(c)
	max_content_width = 1500.0
	_list = null
	_nations_box = null
	_leagues_row = null
	c.add_child(_stepper())
	_status = UIKit.label("", "Small")
	_status.visible = false
	match _step:
		0:
			_build_setup(c)
		1:
			_build_nation(c)
		_:
			_build_club(c)
	c.add_child(_status)
	_update_status_label()
	_build_footer()


func _stepper() -> Control:
	var row := UIKit.hbox(8)
	for i in STEPS.size():
		var done := i < _step
		var cur := i == _step
		var col := UIColors.ACCENT if done or cur else UIColors.DIM
		var v := UIKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar := ColorRect.new()
		bar.color = col if done or cur else UIColors.SURFACE_3
		bar.custom_minimum_size.y = 4
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bar)
		var l := UIKit.label("%d  %s" % [i + 1, String(STEPS[i][1]).to_upper()], "Eyebrow")
		l.add_theme_color_override(&"font_color", UIColors.TEXT if cur else col)
		v.add_child(l)
		var idx := i
		var tap := UIKit.tap_row(v, func():
			if idx <= _step or _can_go(idx):
				_step = idx
				_build(), "PanelContainer")
		tap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(tap)
	return row


func _can_go(idx: int) -> bool:
	return idx <= 1 or _world != null


func _build_footer() -> void:
	var f := footer()
	UIKit.clear(f)
	_details = UIKit.vbox(6)
	f.add_child(_details)
	var row := UIKit.hbox(10)
	if _step > 0:
		var back := UIKit.button("Voltar", "GhostButton", func():
			_step -= 1
			_build(), "back")
		back.custom_minimum_size.y = 88
		row.add_child(back)
	if _step < STEPS.size() - 1:
		var nxt := UIKit.button("CONTINUAR", "PrimaryButton", func():
			_step += 1
			_build(), "forward")
		nxt.custom_minimum_size.y = 88
		nxt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nxt)
		_start_btn = null
	else:
		_start_btn = UIKit.button("COMEÇAR CARREIRA", "PrimaryButton", _start, "play")
		_start_btn.custom_minimum_size.y = 88
		_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_start_btn)
	f.add_child(row)
	_update_details()


# --- Passo 1: treinador, dificuldade e mundo ----------------------------------------

func _build_setup(c: VBoxContainer) -> void:
	var cards: Array = []
	var who := UIKit.card("Card", 10)
	who.add_child(UIKit.section("Seu nome"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Treinador"
	name_edit.max_length = 24
	name_edit.text = "" if _manager == "Treinador" else _manager
	name_edit.text_changed.connect(func(t): _manager = t if t != "" else "Treinador")
	who.add_child(name_edit)
	who.add_child(UIKit.section("Dificuldade"))
	for i in 3:
		var idx := i
		var inner := UIKit.hbox(12)
		var dot := UIKit.icon_rect("check" if i == _difficulty else "minus", 26, UIColors.ACCENT if i == _difficulty else UIColors.DIM)
		inner.add_child(dot)
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(GameWorld.DIFF_NAMES[i], "H3"))
		inner.add_child(tv)
		var r := UIKit.tap_row(inner, func():
			_difficulty = idx
			_build(), "RowPanel", true)
		UIKit.set_row_selected(r, i == _difficulty)
		who.add_child(r)
	cards.append(UIKit.card_panel(who))
	var wc := UIKit.card("Card", 10)
	wc.add_child(UIKit.section("Mundo"))
	wc.add_child(UIKit.segment([["padrao", "Mundo padrão"], ["aleatorio", "Mundo aleatório"]], _type, func(k: String): _set_type(k)))
	wc.add_child(UIKit.label("%d países · %d ligas · %d clubes" % _world_counts(), "Small", true))
	var seed_row := UIKit.hbox(10)
	seed_row.add_child(UIKit.label("Seed", "Muted"))
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(_seed)
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.text_submitted.connect(func(_t): _apply_seed())
	seed_row.add_child(_seed_edit)
	seed_row.add_child(UIKit.button("Gerar", "GhostButton", _apply_seed))
	seed_row.add_child(UIKit.icon_button("bolt", func():
		_seed_edit.text = str(WorldGenerator.random_seed())
		_apply_seed(), "Seed aleatório"))
	wc.add_child(seed_row)
	cards.append(UIKit.card_panel(wc))
	UIKit.columns(c, cards, content_width())


# --- Passo 2: continente, país e divisão ------------------------------------------

func _build_nation(c: VBoxContainer) -> void:
	c.add_child(UIKit.scroll_tabs(CONFEDS, _confed, func(code: String):
		_confed = code
		_build()))
	var grid := GridContainer.new()
	grid.columns = 3 if not UILayout.is_wide() else 5
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	_nations_box = grid
	c.add_child(grid)
	c.add_child(UIKit.section_header("Divisão"))
	_leagues_row = UIKit.vbox(8)
	c.add_child(_leagues_row)
	_fill_nations()


func _fill_nations() -> void:
	if _nations_box == null:
		return
	UIKit.clear(_nations_box)
	var codes: Array = []
	for n in DatabaseManager.league_nations():
		if DatabaseManager.nation(n).get("confed", "") == _confed:
			codes.append(n)
	if not codes.has(_nation):
		_set_nation(codes[0] if not codes.is_empty() else _nation, false)
	for n in codes:
		var code: String = n
		var inner := UIKit.vbox(6)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		var fl := UIKit.flag(code, 72)
		fl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(fl)
		var nl := UIKit.label(DatabaseManager.nation_name(code), "Small")
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		inner.add_child(nl)
		var tr := UIKit.tap_row(inner, func(): _set_nation(code, true), "RowPanel", true)
		tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tr.custom_minimum_size.y = 120
		tr.set_meta("nation", code)
		UIKit.set_row_selected(tr, code == _nation)
		_nations_box.add_child(tr)
	_fill_leagues()


func _set_nation(code: String, refill: bool) -> void:
	_nation = code
	var ids := DatabaseManager.leagues_of_nation(code)
	_league = ids[0] if not ids.is_empty() else ""
	_selected = -1
	if refill and _nations_box != null:
		for tr in _nations_box.get_children():
			UIKit.set_row_selected(tr, tr.get_meta("nation", "") == code)
		_fill_leagues()


func _fill_leagues() -> void:
	if _leagues_row == null:
		return
	UIKit.clear(_leagues_row)
	for lid in DatabaseManager.leagues_of_nation(_nation):
		var id: String = lid
		var cfg := DatabaseManager.league_cfg(id)
		var inner := UIKit.hbox(14)
		inner.add_child(UIKit.comp_logo(id, 48))
		var tv := UIKit.vbox(0)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(String(cfg.get("name", id)), "H3"))
		tv.add_child(UIKit.label("%dª divisão · %d clubes" % [int(cfg["tier"]), int(cfg.get("teams", 0))], "Small"))
		inner.add_child(tv)
		var r := UIKit.tap_row(inner, func():
			_league = id
			_selected = -1
			_fill_leagues(), "RowPanel", true)
		UIKit.set_row_selected(r, id == _league)
		_leagues_row.add_child(r)


# --- Passo 3: clube ---------------------------------------------------------------

func _build_club(c: VBoxContainer) -> void:
	var cfg := DatabaseManager.league_cfg(_league)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.flag(_nation, 42))
	head.add_child(UIKit.comp_logo(_league, 42))
	var hl := UIKit.label(String(cfg.get("name", _league)), "H2")
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(hl)
	c.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 1 if not UILayout.is_wide() else 2
	grid.add_theme_constant_override(&"h_separation", 10)
	grid.add_theme_constant_override(&"v_separation", 10)
	_list = grid
	c.add_child(grid)
	_fill_clubs()


func _update_status_label() -> void:
	if _status == null:
		return
	_status.visible = _world == null
	_status.text = "Gerando o mundo (%d clubes, ~%d mil jogadores)..." % [_world_counts()[2], roundi(_world_counts()[2] * 24 / 1000.0)]


func _set_type(t: String) -> void:
	if t == _type:
		return
	_type = t
	if t == "aleatorio" and int(_seed_edit.text) == WorldGenerator.DEFAULT_SEED:
		_seed_edit.text = str(WorldGenerator.random_seed())
	elif t == "padrao":
		_seed_edit.text = str(WorldGenerator.DEFAULT_SEED)
	_apply_seed()


func _apply_seed() -> void:
	var s := int(_seed_edit.text)
	if s <= 0:
		s = WorldGenerator.random_seed()
		_seed_edit.text = str(s)
	_seed = s
	_generate()


## [países, ligas, clubes] do banco de dados.
func _world_counts() -> Array:
	var nations := {}
	var clubs := 0
	for id in DatabaseManager.league_ids():
		var cfg := DatabaseManager.league_cfg(id)
		nations[cfg["nation"]] = true
		clubs += int(cfg["teams"])
	return [nations.size(), DatabaseManager.league_ids().size(), clubs]


func _generate() -> void:
	_world = null
	_selected = -1
	_update_status_label()
	if _list != null:
		UIKit.clear(_list)
	_update_details()
	var requested := [_seed, _type]
	GameManager.generate_world_async(_seed, _type, func(w: GameWorld):
		if requested != [_seed, _type]:
			_generate() # o usuário mudou o seed durante a geração
			return
		_world = w
		_update_status_label()
		_fill_clubs())


func _fill_clubs() -> void:
	if _list == null or not is_instance_valid(_list):
		_update_details()
		return
	UIKit.clear(_list)
	if _world == null:
		_update_details()
		return
	var clubs := _world.clubs_in_league(_league)
	clubs.sort_custom(func(a, b): return a.reputation > b.reputation)
	for cl: Club in clubs:
		_list.add_child(_club_row(cl))
	_update_details()


func _club_row(cl: Club) -> Control:
	var row := UIKit.hbox(14)
	row.add_child(UIKit.crest(cl, 72))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UIKit.label(cl.name, "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var goal: Array = SeasonManager.goal_of(_world, cl.id)
	col.add_child(UIKit.label("%s · %s" % [cl.city, cl.arch().get("tag", "")], "Small"))
	col.add_child(UIKit.label("Meta: %s" % String(goal[0]).to_lower(), "Small"))
	var cups := UIKit.flow(6)
	for cid in _world.season.cups:
		if _world.season.cups[cid].has_club(cl.id):
			cups.add_child(UIKit.pill(_world.season.cups[cid].short_name, UIColors.ACCENT, 15))
	if cups.get_child_count() > 0:
		col.add_child(cups)
	row.add_child(col)
	var right := UIKit.vbox(6)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_reputation(cl.reputation)
	right.add_child(st)
	var strength := int(round(ClubAI._compute_strength(_world, cl)))
	var b := UIKit.badge(strength, 60, 44, 26)
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(b)
	row.add_child(right)
	# (lambdas capturam variáveis locais por valor: identificamos a linha pelo id do clube)
	var tr := UIKit.tap_row(row, func():
		_selected = cl.id
		for other in _list.get_children():
			if other is PanelContainer:
				UIKit.set_row_selected(other, other.get_meta("cid", -1) == cl.id)
		_update_details(), "RowPanel", true)
	tr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.set_meta("cid", cl.id)
	UIKit.set_row_selected(tr, cl.id == _selected)
	return tr


## Resumo no rodapé: o clube escolhido (passo 3) ou as escolhas feitas até aqui.
func _update_details() -> void:
	if _details == null or not is_instance_valid(_details):
		return
	UIKit.clear(_details)
	if _start_btn != null and is_instance_valid(_start_btn):
		_start_btn.disabled = _world == null or _selected < 0
	if _step < 2:
		var cfg := DatabaseManager.league_cfg(_league)
		var line := "%s · %s · %s" % [GameWorld.DIFF_NAMES[_difficulty], DatabaseManager.nation_name(_nation), cfg.get("name", _league)]
		_details.add_child(UIKit.label(line, "Small"))
		return
	if _world == null or _selected < 0:
		_details.add_child(UIKit.label("Escolha um clube.", "Muted"))
		return
	var cl: Club = _world.club(_selected)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.crest(cl, 56))
	var t := UIKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(cl.short_name, "H2")
	nm.uppercase = true
	t.add_child(nm)
	head.add_child(t)
	_details.add_child(head)
	var stats := UIKit.hbox(8)
	stats.add_child(UIKit.stat(Fmt.money(cl.balance), "caixa", UIColors.GREEN if cl.balance >= 0 else UIColors.RED))
	stats.add_child(UIKit.stat(Fmt.money(maxi(0, int(cl.balance * [0.6, 0.45, 0.35][_difficulty]))), "p/ contratar"))
	stats.add_child(UIKit.stat(Fmt.thousands(cl.capacity), "lugares"))
	_details.add_child(stats)


func _start() -> void:
	if _world == null or _selected < 0:
		return
	AudioManager.play("whistle", -4.0)
	var slot := SaveManager.first_free_slot()
	if slot < 0:
		UIManager.dialog("Todos os slots estão ocupados", "Escolha um slot para substituir (a carreira antiga será apagada).", _slot_buttons())
		return
	_begin(slot)


func _slot_buttons() -> Array:
	var out: Array = []
	for i in range(1, SaveManager.SLOTS + 1):
		var m := SaveManager.read_meta(i)
		var slot := i
		out.append({"text": "Slot %d · %s %s" % [i, m.get("short", "vazio"), str(m.get("year", ""))], "style": "", "cb": func():
			SaveManager.delete_slot(slot)
			_begin(slot)})
	out.append({"text": "Cancelar", "style": "GhostButton"})
	return out


func _begin(slot: int) -> void:
	var w := _world
	GameManager.start_career_async(w, _selected, _manager, _difficulty, slot, func() -> void:
		UIManager.goto("welcome")
		UIManager.toast("Bem-vindo ao %s! Boa sorte, %s." % [w.user_club().short_name, w.manager_name]))
