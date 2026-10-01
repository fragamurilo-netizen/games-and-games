class_name GameMenu
extends Control
## Android front door with an original game identity, not a management dashboard.
## UFC Undisputed 3 main-menu language: desaturated art, red title bar, a light
## panel with the option list (selected row lit red), an info panel for the
## selected option and the red command strip with its description line.
signal continued
var _list: VBoxContainer
var _info_title: Label
var _info_text: Label
var _hints: Ud3Chrome.HintBar
var _confirm: ConfirmationDialog
var _body: BoxContainer
var _info_panel: PanelContainer
func _ready() -> void:
	theme=Tokens.build_theme()
	var bg:=Ud3Chrome.Backdrop.new();bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
	var stage:=VBoxContainer.new();stage.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	stage.add_theme_constant_override("separation",0);add_child(stage)
	var title:=Ud3Chrome.TitleBar.new();title.title="Menu principal";title.context="MMA Promoter Simulator";stage.add_child(title)
	var margin:=MarginContainer.new();margin.size_flags_vertical=SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,Tokens.SPACE_M)
	stage.add_child(margin)
	_body=HBoxContainer.new();_body.add_theme_constant_override("separation",Tokens.SPACE_M);margin.add_child(_body)
	var list_panel:=PanelContainer.new();list_panel.custom_minimum_size.x=460
	list_panel.size_flags_vertical=SIZE_SHRINK_BEGIN
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",Tokens.SPACE_XS);list_panel.add_child(column)
	column.add_child(Ud3Chrome.header_bar("Corner Office"))
	_list=VBoxContainer.new();_list.add_theme_constant_override("separation",Tokens.SPACE_XS);column.add_child(_list)
	_body.add_child(list_panel)
	_info_panel=PanelContainer.new();_info_panel.size_flags_horizontal=SIZE_EXPAND_FILL;_info_panel.size_flags_vertical=SIZE_SHRINK_BEGIN
	var info:=VBoxContainer.new();info.add_theme_constant_override("separation",Tokens.SPACE_S);_info_panel.add_child(info)
	var head:=Ud3Chrome.header_bar("");_info_title=head.get_child(0);info.add_child(head)
	_info_text=Label.new();_info_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_info_text.add_theme_font_size_override("font_size",Tokens.FONT_SMALL+2)
	info.add_child(_info_text)
	if Game.has_world():
		var org:=Game.world.player_org()
		info.add_child(StatWidgets.tile_row([StatWidgets.tile("Promoção",org.name,"",true),StatWidgets.tile("Data",GameDate.format(Game.world.date)),StatWidgets.tile("Caixa",CareerText.money(org.cash))],0))
	_body.add_child(_info_panel)
	_hints=Ud3Chrome.HintBar.new();stage.add_child(_hints)
	_hints.hide_commands()
	var where:=""
	if Game.has_world():where=" "+Game.world.player_org().name+", "+GameDate.format(Game.world.date)+"."
	_add("Continuar carreira","Retome sua promoção de onde parou."+where,func():continued.emit();queue_free())
	_add("Nova carreira","Funde uma promoção do zero. A carreira atual fica guardada no slot de backup.",func():_confirm.popup_centered(Vector2i(600,330)))
	_add("Universo","Enciclopédia do mundo: história do MMA (1991–2026), organizações, cinturões, cidades e arenas.",func():UniverseView.open_over(get_tree()))
	_add("Assistir demonstração","Uma luta completa na transmissão CO Sports, sem mexer na sua carreira.",func():
		var viewer:=FightReplayView.new();viewer.set_anchors_and_offsets_preset(PRESET_FULL_RECT);get_tree().root.add_child(viewer)
		viewer.open(ContentDB.load_json("replays/sim_women.json")))
	_confirm=ConfirmationDialog.new();_confirm.title="Nova carreira";_confirm.dialog_text="Substituir a carreira deste aparelho?\nO progresso atual ficará no slot backup."
	_confirm.ok_button_text="Começar";_confirm.cancel_button_text="Voltar"
	_confirm.confirmed.connect(func():
		if Game.save_game("backup")!=OK:
			_confirm.dialog_text="Falha ao salvar o backup. A carreira atual foi preservada.";_confirm.popup_centered();return
		Game.new_game(Time.get_ticks_usec());Game.save_game("autosave");continued.emit();queue_free())
	add_child(_confirm)
	resized.connect(_layout);_layout()
	_select(_list.get_child(0))
	_list.get_child(0).grab_focus.call_deferred()
func _add(text: String,info: String,action: Callable) -> void:
	var button:=Button.new();button.text=text.to_upper();button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=Tokens.TOUCH_MIN;button.set_meta("info",info)
	button.add_theme_font_size_override("font_size",26)
	button.focus_entered.connect(_select.bind(button));button.mouse_entered.connect(_select.bind(button))
	button.pressed.connect(action);_list.add_child(button)
func _select(button: Button) -> void:
	_info_title.text=button.text;_info_text.text=button.get_meta("info");_hints.set_hint(button.get_meta("info"))
## Portrait stacks the list over the info panel; landscape puts them side by side.
func _layout() -> void:
	if _body==null:return
	var portrait:=size.y>size.x
	var want_vertical:=portrait
	if (_body is VBoxContainer)==want_vertical:return
	var parent:=_body.get_parent();var kids:=_body.get_children()
	var box: BoxContainer=VBoxContainer.new() if want_vertical else HBoxContainer.new()
	box.add_theme_constant_override("separation",Tokens.SPACE_M)
	if want_vertical:box.alignment=BoxContainer.ALIGNMENT_END
	for k in kids:_body.remove_child(k);box.add_child(k)
	kids[0].custom_minimum_size.x=0 if want_vertical else 460
	parent.remove_child(_body);_body.queue_free();_body=box;parent.add_child(box)
