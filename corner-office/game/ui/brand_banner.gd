class_name BrandBanner
extends Control
## Cabeçalho de tela na linguagem de menus de UFC Undisputed 3: placa vermelha
## em paralelogramo com o título em itálico, faixa carvão e régua metálica.
## Arte própria + tipografia OFL. Bible §§15–16,24.
var headline:="CORNER OFFICE"
var subtitle:="MMA PROMOTER SIMULATOR"
var show_art:=false
var art: Texture2D=preload("res://assets/brand/corner-office-menu.png")
func _init() -> void:
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.CANVAS)
	if show_art:
		var source:=art.get_size()
		var source_width:=minf(source.x,source.y*size.x/size.y)
		var region:=Rect2(source.x-source_width,0,source_width,source.y)
		draw_texture_rect_region(art,Rect2(Vector2.ZERO,size),region)
		for i in 256:
			var alpha: float=.92*pow(1.0-float(i)/256.0,1.4)
			var x:=floorf(size.x*i/256.0);var end:=floorf(size.x*(i+1)/256.0)
			draw_rect(Rect2(x,0,end-x,size.y),Color(Tokens.CANVAS,alpha))
	var h:=70.0
	var y:=size.y-h-8 if show_art else 0.0
	var lean:=h*Tokens.SLANT
	# Faixa carvão por trás de toda a largura.
	draw_colored_polygon(PackedVector2Array([Vector2(0,y+10),Vector2(size.x,y+10),Vector2(size.x,y+h),Vector2(0,y+h)]),Color(Tokens.SURFACE,.95))
	var font_size:=32 if size.x<550 else 40
	var font:=Tokens.italic_font()
	var title:=headline.to_upper()
	var plate_w:=minf(size.x-60,font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x+56+lean)
	# Placa vermelha do título, cortada na diagonal como nos menus de 2012.
	draw_colored_polygon(PackedVector2Array([Vector2(0,y),Vector2(plate_w+lean,y),Vector2(plate_w,y+h),Vector2(0,y+h)]),Tokens.FIGHT_RED)
	draw_colored_polygon(PackedVector2Array([Vector2(plate_w+lean+6,y+10),Vector2(plate_w+lean+16,y+10),Vector2(plate_w+10,y+h),Vector2(plate_w,y+h)]),Tokens.INK)
	draw_string(font,Vector2(22,y+h*.5+font_size*.36),title,HORIZONTAL_ALIGNMENT_LEFT,plate_w-30,font_size,Tokens.INK)
	var sub_x:=plate_w+lean+30
	var sub_w:=Tokens.BODY_FONT.get_string_size(subtitle.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	if size.x-sub_x-12>=sub_w or not show_art:
		draw_string(Tokens.BODY_FONT,Vector2(sub_x,y+h*.5+16),subtitle.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-sub_x-12,15,Tokens.MUTED)
	else:
		draw_string(Tokens.BODY_FONT,Vector2(8,y-12),subtitle.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-16,15,Tokens.INK)
	draw_line(Vector2(0,y+h+1),Vector2(size.x,y+h+1),Tokens.STEEL,2,true)
