class_name BrandBanner
extends Control
## Corner Office broadcast identity: cut corners, restrained metal, crimson rule.
## Original artwork + OFL typography. Bible §§15–16,24.
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
	var y:=size.y-82 if show_art else 0.0
	var band:=PackedVector2Array([Vector2(0,y),Vector2(size.x,y),Vector2(size.x-20,y+70),Vector2(0,y+70)])
	draw_colored_polygon(band,Color(Tokens.SURFACE,.95))
	draw_line(Vector2(0,y),Vector2(size.x,y),Tokens.STEEL,2,true)
	draw_rect(Rect2(0,y,7,70),Tokens.FIGHT_RED)
	var font_size:=32 if size.x<550 else 40
	draw_string(Tokens.DISPLAY_FONT,Vector2(24,y+35),headline.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-40,font_size,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(25,y+59),subtitle.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,size.x-40,15,Tokens.MUTED)
	draw_line(Vector2(0,y+72),Vector2(size.x-20,y+72),Tokens.FIGHT_RED,3,true)
