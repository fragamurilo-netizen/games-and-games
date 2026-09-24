extends BaseScreen
## Nova carreira: mundo (padrão/aleatório + seed), dificuldade, nome e clube.
## O Mundo padrão já começa a ser gerado ao abrir a tela: escolher o clube leva segundos.

var _world: GameWorld = null
var _type := "padrao"
var _seed := WorldGenerator.DEFAULT_SEED
var _difficulty := GameWorld.DIFF_NORMAL
var _division := 3
var _selected := -1
var _manager := "Treinador"
var _list: VBoxContainer
var _details: VBoxContainer
var _status: Label
var _seed_edit: LineEdit
var _start_btn: Button


func _init() -> void:
	screen_title = "Nova carreira"
	screen_subtitle = "Escolha um clube e comece"
	show_nav = false


func on_show() -> void:
	if _list == null:
		_build()
		_generate()


func refresh() -> void:
	_fill_clubs()


func _build() -> void:
	var c := content()
	UIKit.clear(c)
	# Mundo
	c.add_child(UIKit.section("Mundo"))
	var g := ButtonGroup.new()
	var row := UIKit.hbox(10)
	row.add_child(UIKit.chip("Mundo padrão", true, g, func(): _set_type("padrao")))
	row.add_child(UIKit.chip("Mundo aleatório", false, g, func(): _set_type("aleatorio")))
	c.add_child(row)
	var seed_row := UIKit.hbox(10)
	var seed_lbl := UIKit.label("Seed", "Muted")
	seed_row.add_child(seed_lbl)
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
	c.add_child(seed_row)
	var hint := UIKit.label("Mesmo seed = mesmo universo. O Mundo padrão tem os 80 clubes de Valdora; o aleatório cria clubes e cidades novos.", "Small", true)
	c.add_child(hint)
	# Dificuldade
	c.add_child(UIKit.section("Dificuldade"))
	var gd := ButtonGroup.new()
	var drow := UIKit.hbox(10)
	for i in 3:
		var idx := i
		drow.add_child(UIKit.chip(GameWorld.DIFF_NAMES[i], i == _difficulty, gd, func(): _difficulty = idx))
	c.add_child(drow)
	c.add_child(UIKit.label("A dificuldade muda orçamento, paciência da diretoria e margem nas negociações — nunca a força dos adversários.", "Small", true))
	# Treinador
	c.add_child(UIKit.section("Seu nome"))
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Treinador"
	name_edit.max_length = 24
	name_edit.text_changed.connect(func(t): _manager = t)
	c.add_child(name_edit)
	# Clubes
	c.add_child(UIKit.section("Escolha seu clube"))
	var gdv := ButtonGroup.new()
	var divrow := UIKit.hbox(8)
	for d in 4:
		var dd := d
		divrow.add_child(UIKit.chip("%dª Divisão" % (d + 1), d == _division, gdv, func():
			_division = dd
			_selected = -1
			_fill_clubs()))
	c.add_child(divrow)
	c.add_child(UIKit.label("Começar na 4ª divisão é a jornada mais longa: décadas até o topo.", "Small", true))
	_status = UIKit.label("Gerando mundo...", "Accent")
	c.add_child(_status)
	_list = UIKit.vbox(8)
	c.add_child(_list)
	# Rodapé fixo
	var f := footer()
	_details = UIKit.vbox(6)
	f.add_child(_details)
	_start_btn = UIKit.button("COMEÇAR CARREIRA", "PrimaryButton", _start, "play")
	_start_btn.custom_minimum_size.y = 96
	_start_btn.disabled = true
	f.add_child(_start_btn)


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


func _generate() -> void:
	_world = null
	_selected = -1
	_status.text = "Gerando mundo (80 clubes, ~2.000 jogadores)..."
	_status.visible = true
	UIKit.clear(_list)
	_update_details()
	var requested := [_seed, _type]
	GameManager.generate_world_async(_seed, _type, func(w: GameWorld):
		if requested != [_seed, _type]:
			_generate() # o usuário mudou o seed durante a geração
			return
		_world = w
		_status.visible = false
		_fill_clubs())


func _fill_clubs() -> void:
	if _list == null:
		return
	UIKit.clear(_list)
	if _world == null:
		return
	var clubs: Array = []
	for cl in _world.clubs:
		if cl.division == _division:
			clubs.append(cl)
	clubs.sort_custom(func(a, b): return a.reputation > b.reputation)
	for cl: Club in clubs:
		_list.add_child(_club_row(cl))
	_update_details()


func _club_row(cl: Club) -> Control:
	var row := UIKit.hbox(14)
	row.add_child(UIKit.crest(cl, 64))
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var nm := UIKit.label(cl.name, "H3")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	var goal: Array = SeasonManager.goal_of(_world, cl.id)
	col.add_child(UIKit.label("%s · %s" % [cl.city, cl.arch().get("tag", "")], "Small"))
	col.add_child(UIKit.label("Meta: %s" % String(goal[0]).to_lower(), "Small"))
	row.add_child(col)
	var right := UIKit.vbox(4)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	var st := StarsView.new()
	st.star_size = 18
	st.stars = StarsView.from_reputation(cl.reputation)
	right.add_child(st)
	var strength := ClubAI._compute_strength(_world, cl)
	var sl := UIKit.label("Força %d" % int(round(strength)), "Small")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(sl)
	row.add_child(right)
	# (lambdas capturam variáveis locais por valor: identificamos a linha pelo id do clube)
	var tr := UIKit.tap_row(row, func():
		_selected = cl.id
		for other in _list.get_children():
			UIKit.set_row_selected(other, other.get_meta("cid", -1) == cl.id)
		_update_details(), "RowPanel", true)
	tr.set_meta("cid", cl.id)
	UIKit.set_row_selected(tr, cl.id == _selected)
	return tr


func _update_details() -> void:
	if _details == null:
		return
	UIKit.clear(_details)
	_start_btn.disabled = _world == null or _selected < 0
	if _world == null or _selected < 0:
		_details.add_child(UIKit.label("Toque em um clube para ver os detalhes.", "Muted"))
		return
	var cl: Club = _world.club(_selected)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.crest(cl, 56))
	var t := UIKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.add_child(UIKit.label(cl.short_name, "H2"))
	t.add_child(UIKit.label(String(cl.arch().get("desc", "")), "Small", true))
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
	GameManager.start_career(_world, _selected, _manager, _difficulty, slot)
	UIManager.goto("hub")
	UIManager.toast("Bem-vindo ao %s! Boa sorte, %s." % [_world.user_club().short_name, _world.manager_name])
