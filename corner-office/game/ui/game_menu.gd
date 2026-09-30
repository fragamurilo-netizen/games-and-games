class_name GameMenu
extends Control
## Android front door with an original game identity, not a management dashboard.
## Layout follows the UFC Undisputed 3 menus: stacked slanted bars, the
## selected one lit red, a description plate under the list and a hint strip.
signal continued
const HINT_H:=52
var _buttons: VBoxContainer
var _width:=0.0
var _info: Label
var _confirm: ConfirmationDialog
var art: Texture2D=preload("res://assets/brand/corner-office-menu.png")
func _ready() -> void:
	theme=Tokens.build_theme();resized.connect(_layout)
	_buttons=VBoxContainer.new();_buttons.add_theme_constant_override("separation",Tokens.SPACE_S);add_child(_buttons)
	_info=Label.new();_info.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_info.add_theme_color_override("font_color",Tokens.MUTED)
	_info.add_theme_font_size_override("font_size",Tokens.FONT_SMALL);add_child(_info)
	var where:=""
	if Game.has_world():where=" "+Game.world.player_org().name+", "+GameDate.format(Game.world.date)+"."
	_add("CONTINUAR CARREIRA","Retome sua promoção de onde parou."+where,func():continued.emit();queue_free())
	_add("NOVA CARREIRA","Funde uma promoção do zero. A carreira atual fica guardada no slot de backup.",func():_confirm.popup_centered(Vector2i(600,330)))
	_add("ASSISTIR DEMONSTRAÇÃO","Uma luta completa na transmissão CO Sports, sem mexer na sua carreira.",func():
		var viewer:=FightReplayView.new();viewer.set_anchors_and_offsets_preset(PRESET_FULL_RECT);get_tree().root.add_child(viewer)
		viewer.open(ContentDB.load_json("replays/sim_women.json")))
	_confirm=ConfirmationDialog.new();_confirm.title="Nova carreira";_confirm.dialog_text="Substituir a carreira deste aparelho?\nO progresso atual ficará no slot backup."
	_confirm.ok_button_text="Começar";_confirm.cancel_button_text="Voltar"
	_confirm.confirmed.connect(func():
		if Game.save_game("backup")!=OK:
			_confirm.dialog_text="Falha ao salvar o backup. A carreira atual foi preservada.";_confirm.popup_centered();return
		Game.new_game(Time.get_ticks_usec());Game.save_game("autosave");continued.emit();queue_free())
	add_child(_confirm);_layout()
	_select(_buttons.get_child(0))
	_buttons.get_child(0).grab_focus.call_deferred()
func _add(text: String,info: String,action: Callable) -> void:
	var button:=Button.new();button.text=text;button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y=Tokens.TOUCH_MIN;button.set_meta("info",info)
	button.add_theme_font_size_override("font_size",30)
	# Focus lights the whole bar, as the highlighted row does in the reference.
	button.add_theme_stylebox_override("focus",Tokens.slanted_box(Tokens.FIGHT_RED))
	button.focus_entered.connect(_select.bind(button));button.mouse_entered.connect(_select.bind(button))
	button.pressed.connect(action);_buttons.add_child(button)
func _select(button: Button) -> void:
	_info.text=button.get_meta("info")
	# The selected bar reaches further right, like the Undisputed 3 cursor.
	for other: Button in _buttons.get_children():
		other.set_meta("selected",other==button)
	_size_buttons()
	queue_redraw()
func _size_buttons() -> void:
	for button: Button in _buttons.get_children():
		button.size_flags_horizontal=SIZE_SHRINK_BEGIN
		button.custom_minimum_size.x=_width if button.get_meta("selected",false) else _width-Tokens.SPACE_XL*2
	_buttons.size=Vector2(_width,_buttons.size.y)
func _layout() -> void:
	if _buttons==null:return
	var portrait:=size.y>size.x
	var width:=size.x-96 if portrait else minf(520,size.x*.42)
	var list_h:=3*Tokens.TOUCH_MIN+2*Tokens.SPACE_S
	var top:=size.y-HINT_H-list_h-120 if portrait else size.y*.40
	_buttons.position=Vector2(32,top);_buttons.size=Vector2(width,list_h)
	_info.position=Vector2(40,top+list_h+Tokens.SPACE_M);_info.size=Vector2(width,80)
	_width=width;_size_buttons()
	queue_redraw()
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.CANVAS)
	var portrait:=size.y>size.x
	var source:=art.get_size();var width:=minf(source.x,source.y*size.x/size.y)
	var region:=Rect2(clampf(source.x*.78-width*.5,0,source.x-width),0,width,source.y)
	if not portrait:region=Rect2(Vector2.ZERO,source)
	draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),region)
	# Matte gradients are light occlusion over photography, without bright UI effects.
	for i in 256:
		var f:=float(i)/256.0
		if portrait:
			var y:=floorf(size.y*f);var end:=floorf(size.y*(i+1)/256.0)
			draw_rect(Rect2(0,y,size.x,end-y),Color(Tokens.CANVAS,.9*pow(f,1.2)))
		else:
			var x:=floorf(size.x*f);var end:=floorf(size.x*(i+1)/256.0)
			draw_rect(Rect2(x,0,end-x,size.y),Color(Tokens.CANVAS,.88*pow(1-f,1.2)))
	var font_size:=72 if portrait else 84
	var italic:=Tokens.italic_font()
	draw_rect(Rect2(32,42,8,145),Tokens.FIGHT_RED)
	draw_string(italic,Vector2(55,105),"CORNER",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Tokens.INK)
	draw_string(italic,Vector2(55,180),"OFFICE",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(57,212),"MMA PROMOTER SIMULATOR",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Tokens.INK)
	# Description plate: thin red rule on the left, as under the reference menus.
	if _info:draw_rect(Rect2(_info.position.x-10,_info.position.y+4,4,52),Tokens.FIGHT_RED)
	# Hint strip along the bottom edge, where the console showed button prompts.
	var y:=size.y-HINT_H
	draw_rect(Rect2(0,y,size.x,HINT_H),Color(Tokens.SURFACE,.96))
	draw_line(Vector2(0,y),Vector2(size.x,y),Tokens.STEEL,2)
	var lean:=HINT_H*Tokens.SLANT*.5
	draw_colored_polygon(PackedVector2Array([Vector2(24+lean,y+12),Vector2(44+lean,y+12),Vector2(44-lean,y+HINT_H-12),Vector2(24-lean,y+HINT_H-12)]),Tokens.FIGHT_RED)
	draw_string(italic,Vector2(56,y+34),"SELECIONAR",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(0,y+33),"CONSTRUA ESTRELAS. ORGANIZE LUTAS. DOMINE A NOITE.",HORIZONTAL_ALIGNMENT_RIGHT,size.x-24,14,Tokens.MUTED)
