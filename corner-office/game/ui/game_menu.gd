class_name GameMenu
extends Control
## Android front door with an original game identity, not a management dashboard.
signal continued
var _buttons: VBoxContainer
var _confirm: ConfirmationDialog
var art: Texture2D=preload("res://assets/brand/corner-office-menu.png")
func _ready() -> void:
	theme=Tokens.build_theme();resized.connect(_layout)
	_buttons=VBoxContainer.new();_buttons.add_theme_constant_override("separation",12);add_child(_buttons)
	_add("CONTINUAR CARREIRA",func():continued.emit();queue_free())
	_add("NOVA CARREIRA",func():_confirm.popup_centered(Vector2i(600,330)))
	_add("ASSISTIR DEMONSTRAÇÃO",func():
		var viewer:=FightReplayView.new();viewer.set_anchors_and_offsets_preset(PRESET_FULL_RECT);get_tree().root.add_child(viewer)
		viewer.open(ContentDB.load_json("replays/sim_women.json")))
	_confirm=ConfirmationDialog.new();_confirm.title="Nova carreira";_confirm.dialog_text="Substituir a carreira deste aparelho?\nO progresso atual ficará no slot backup."
	_confirm.ok_button_text="Começar";_confirm.cancel_button_text="Voltar"
	_confirm.confirmed.connect(func():
		if Game.save_game("backup")!=OK:
			_confirm.dialog_text="Falha ao salvar o backup. A carreira atual foi preservada.";_confirm.popup_centered();return
		Game.new_game(Time.get_ticks_usec());Game.save_game("autosave");continued.emit();queue_free())
	add_child(_confirm);_layout()
func _add(text: String,action: Callable) -> void:
	var button:=Button.new();button.text=text;button.alignment=HORIZONTAL_ALIGNMENT_LEFT;button.custom_minimum_size.y=Tokens.TOUCH_MIN+4;button.pressed.connect(action);_buttons.add_child(button)
func _layout() -> void:
	if _buttons==null:return
	var portrait:=size.y>size.x
	_buttons.position=Vector2(32,size.y-345 if portrait else size.y*.47)
	_buttons.size=Vector2(size.x-64 if portrait else minf(520,size.x*.45),290)
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
	draw_rect(Rect2(32,42,8,145),Tokens.FIGHT_RED)
	var font_size:=72 if portrait else 84
	draw_string(Tokens.DISPLAY_FONT,Vector2(55,105),"CORNER",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Tokens.INK)
	draw_string(Tokens.DISPLAY_FONT,Vector2(55,180),"OFFICE",HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(57,212),"MMA PROMOTER SIMULATOR",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(32,size.y-24),"CONSTRUA ESTRELAS. ORGANIZE LUTAS. DOMINE A NOITE.",HORIZONTAL_ALIGNMENT_LEFT,size.x-50,14,Tokens.MUTED)
