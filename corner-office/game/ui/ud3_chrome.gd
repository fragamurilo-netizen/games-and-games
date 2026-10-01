class_name Ud3Chrome
extends RefCounted
## Moldura das telas na linguagem de menus de UFC Undisputed 3 (2012): foto
## dessaturada ao fundo, faixa vermelha de título no alto e, embaixo, a faixa
## vermelha de comandos com a linha de descrição do item selecionado.
## Só a linguagem é referência; marca, arte e textos são do Corner Office.


## Key art própria em tons de cinza, clareada, atrás de tudo.
class Backdrop extends Control:
	var art: Texture2D=preload("res://assets/brand/corner-office-menu.png")
	static var _material: ShaderMaterial
	func _init() -> void:
		mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
		if _material==null:
			var shader:=Shader.new()
			shader.code="shader_type canvas_item;\nvoid fragment(){vec4 c=texture(TEXTURE,UV);float g=dot(c.rgb,vec3(.299,.587,.114));COLOR=vec4(vec3(mix(g,.78,.28)),c.a);}"
			_material=ShaderMaterial.new();_material.shader=shader
		material=_material
	func _draw() -> void:
		var source:=art.get_size()
		var width:=minf(source.x,source.y*size.x/size.y)
		var region:=Rect2((source.x-width)*.7,0,width,source.y)
		draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),region)


## Faixa vermelha de título, ponta esquerda cortada e filete escuro por cima.
class TitleBar extends Control:
	var title:="";var context:=""
	func _init() -> void:
		custom_minimum_size.y=64;mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		var h:=size.y
		draw_rect(Rect2(0,0,size.x,10),Color(Tokens.CANVAS,.85))
		var cut:=40.0
		draw_colored_polygon(PackedVector2Array([Vector2(cut,10),Vector2(size.x,10),Vector2(size.x,h),Vector2(0,h),Vector2(0,10+cut*.6)]),Tokens.TITLE_RED)
		draw_line(Vector2(cut,11),Vector2(size.x,11),Color(1,1,1,.25),2)
		var fs:=30 if size.x>600 else 26
		draw_string(Tokens.italic_font(),Vector2(48,10+(h-10)*.5+fs*.36),title.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x*.6,fs,Color.WHITE)
		draw_string(Tokens.BODY_FONT,Vector2(size.x*.45,10+(h-10)*.5+6),context.to_upper(),HORIZONTAL_ALIGNMENT_RIGHT,size.x*.55-20,15,Color(1,1,1,.8))


## Faixa de comandos (marca + ações tocáveis) e linha de descrição embaixo.
class HintBar extends VBoxContainer:
	signal back_pressed
	signal menu_pressed
	var _line: Label
	var _back: Button
	func _init() -> void:
		add_theme_constant_override("separation",0)
		var strip:=PanelContainer.new()
		strip.add_theme_stylebox_override("panel",Tokens.flat_box(Tokens.TITLE_RED,Color.TRANSPARENT,0,Tokens.SPACE_M))
		strip.custom_minimum_size.y=52
		var row:=HBoxContainer.new();row.add_theme_constant_override("separation",Tokens.SPACE_S);strip.add_child(row)
		var brand:=Label.new();brand.text="CORNER OFFICE";brand.size_flags_horizontal=SIZE_EXPAND_FILL
		brand.add_theme_font_override("font",Tokens.italic_font());brand.add_theme_font_size_override("font_size",24)
		brand.add_theme_color_override("font_color",Color.WHITE);row.add_child(brand)
		_back=_command(row,"VOLTAR");_back.pressed.connect(func():back_pressed.emit())
		_command(row,"MENU").pressed.connect(func():menu_pressed.emit())
		add_child(strip)
		var info:=PanelContainer.new()
		var info_box:=Tokens.flat_box(Color(Tokens.CANVAS,.92),Color.TRANSPARENT,0,Tokens.SPACE_M)
		info_box.content_margin_top=6;info_box.content_margin_bottom=8
		info.add_theme_stylebox_override("panel",info_box)
		_line=Label.new();_line.add_theme_color_override("font_color",Tokens.HINT_TEXT)
		_line.add_theme_font_override("font",Tokens.DISPLAY_FONT);_line.add_theme_font_size_override("font_size",17)
		_line.clip_text=true;_line.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
		info.add_child(_line);add_child(info)
	func _command(row: HBoxContainer, text: String) -> Button:
		var b:=Button.new();b.text="●  "+text;b.flat=true
		b.custom_minimum_size=Vector2(0,48);b.add_theme_font_size_override("font_size",20)
		b.add_theme_color_override("font_color",Color.WHITE)
		for state in ["normal","hover","pressed","hover_pressed","focus"]:
			b.add_theme_stylebox_override(state,Tokens.flat_box(Color(0,0,0,.18) if state!="normal" else Color.TRANSPARENT,Color.TRANSPARENT,0,Tokens.SPACE_S))
		row.add_child(b);return b
	func set_hint(text: String) -> void:_line.text=text
	## O menu principal não tem para onde voltar nem menu para abrir.
	func hide_commands() -> void:
		for b in _back.get_parent().get_children():
			if b is Button:b.visible=false
	func set_can_go_back(value: bool) -> void:_back.modulate.a=1.0 if value else .45


## Painel claro com cabeçalho cinza-escuro de texto centralizado (ex.: menu à esquerda).
static func header_bar(text: String, height: float=48) -> PanelContainer:
	var bar:=PanelContainer.new()
	var box:=Tokens.slanted_box(Tokens.HEADER_BAR,height);box.content_margin_top=6;box.content_margin_bottom=6
	bar.add_theme_stylebox_override("panel",box)
	var l:=Label.new();l.text=text.to_upper();l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font",Tokens.italic_font());l.add_theme_font_size_override("font_size",22)
	l.add_theme_color_override("font_color",Tokens.HEADER_TEXT);bar.add_child(l)
	return bar
