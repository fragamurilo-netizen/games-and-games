class_name StatWidgets
extends RefCounted
## Stat panels in the Undisputed 3 language: slanted tiles, animated bars,
## tale of the tape and a form strip. Presentation only (Bible §§15–16,24).


## Big number on a slanted tile. `accent` lights the top rule red.
class Tile extends Control:
	var label:="";var value:="";var note:="";var accent:=false
	func _init() -> void:
		custom_minimum_size=Vector2(0,112);size_flags_horizontal=SIZE_EXPAND_FILL
		mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		var lean:=size.y*Tokens.SLANT*.5
		draw_colored_polygon(PackedVector2Array([Vector2(lean,0),Vector2(size.x,0),Vector2(size.x-lean,size.y),Vector2(0,size.y)]),Tokens.SURFACE)
		draw_line(Vector2(lean,1),Vector2(size.x,1),Tokens.FIGHT_RED if accent else Tokens.STEEL,3)
		var x:=lean+12;var width:=size.x-lean*2-20
		draw_string(Tokens.BODY_FONT,Vector2(x,28),label.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,width,14,Tokens.MUTED)
		# Shrink the number until it fits; never clip a value.
		var fs:=40 if size.x>220 else 30
		while fs>18 and Tokens.italic_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width:fs-=2
		draw_string(Tokens.italic_font(),Vector2(x-4,32+fs),value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,Tokens.INK)
		if not note.is_empty():draw_string(Tokens.BODY_FONT,Vector2(x-8,size.y-10),note,HORIZONTAL_ALIGNMENT_LEFT,width,14,Tokens.FIGHT_RED if accent else Tokens.MUTED)


## Labelled 0..max bar that fills in when shown.
class Bar extends Control:
	var label:="";var value:=0.0;var maximum:=100.0;var text:="";var color:=Tokens.INK
	var _shown:=0.0
	func _init() -> void:
		custom_minimum_size=Vector2(0,44);size_flags_horizontal=SIZE_EXPAND_FILL
		mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _ready() -> void:
		var t:=create_tween();t.tween_method(func(v):_shown=v;queue_redraw(),0.0,1.0,.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	func _draw() -> void:
		var label_w:=minf(size.x*.42,260.0)
		draw_string(Tokens.BODY_FONT,Vector2(0,28),label,HORIZONTAL_ALIGNMENT_LEFT,label_w-8,Tokens.FONT_SMALL,Tokens.MUTED)
		var track:=Rect2(label_w,12,size.x-label_w-100,20)
		_slant(track,Color(Tokens.STEEL,.45))
		var ratio:=clampf(value/maxf(maximum,.001),0,1)*_shown
		if ratio>0:_slant(Rect2(track.position,Vector2(maxf(track.size.x*ratio,8),track.size.y)),color)
		draw_string(Tokens.italic_font(),Vector2(size.x-92,31),text if not text.is_empty() else str(roundi(value)),HORIZONTAL_ALIGNMENT_RIGHT,92,Tokens.FONT_SMALL+2,Tokens.INK)
	func _slant(r: Rect2, c: Color) -> void:
		var lean:=r.size.y*Tokens.SLANT
		draw_colored_polygon(PackedVector2Array([Vector2(r.position.x+lean,r.position.y),Vector2(r.end.x,r.position.y),Vector2(r.end.x-lean,r.end.y),Vector2(r.position.x,r.end.y)]),c)


## Red corner vs blue corner, one row per attribute, bars growing from the middle.
class Tape extends Control:
	var rows: Array=[]   # [{label, red, blue}]
	var red_name:="";var blue_name:=""
	var _shown:=0.0
	const ROW:=46
	func _init() -> void:
		size_flags_horizontal=SIZE_EXPAND_FILL;mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _ready() -> void:
		custom_minimum_size.y=56+rows.size()*ROW
		var t:=create_tween();t.tween_method(func(v):_shown=v;queue_redraw(),0.0,1.0,.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	func _draw() -> void:
		var mid:=size.x*.5;var half:=mid-160
		draw_string(Tokens.italic_font(),Vector2(0,30),red_name.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,mid-20,22,Tokens.FIGHT_RED)
		draw_string(Tokens.italic_font(),Vector2(mid+20,30),blue_name.to_upper(),HORIZONTAL_ALIGNMENT_RIGHT,mid-20,22,Tokens.CORNER_BLUE)
		for i in rows.size():
			var row: Dictionary=rows[i];var y:=56.0+i*ROW
			var red:=float(row.red);var blue:=float(row.blue)
			draw_string(Tokens.BODY_FONT,Vector2(mid-110,y+22),str(row.label).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,220,15,Tokens.MUTED)
			# Escala 20–100: atributos raramente ficam abaixo de 20 e a diferença aparece.
			var rw:=half*clampf((red-20)/80.0,.04,1)*_shown;var bw:=half*clampf((blue-20)/80.0,.04,1)*_shown
			draw_rect(Rect2(mid-110-rw,y+8,rw,18),Tokens.FIGHT_RED if red>=blue else Color(Tokens.FIGHT_RED,.55))
			draw_rect(Rect2(mid+110,y+8,bw,18),Tokens.CORNER_BLUE if blue>=red else Color(Tokens.CORNER_BLUE,.55))
			draw_string(Tokens.italic_font(),Vector2(0,y+25),str(roundi(red)),HORIZONTAL_ALIGNMENT_LEFT,60,20,Tokens.INK)
			draw_string(Tokens.italic_font(),Vector2(size.x-60,y+25),str(roundi(blue)),HORIZONTAL_ALIGNMENT_RIGHT,60,20,Tokens.INK)


## Last results as slanted chips: V (win) lit red, D (loss) steel, E (draw) muted.
class Form extends Control:
	var results: Array=[]
	func _init() -> void:
		custom_minimum_size=Vector2(0,40);mouse_filter=MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if results.is_empty():
			draw_string(Tokens.BODY_FONT,Vector2(0,26),"Sem lutas nesta carreira ainda.",HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SMALL,Tokens.MUTED);return
		for i in results.size():
			var x:=i*52.0;var lean:=36*Tokens.SLANT*.5
			var fill: Color={"V":Tokens.FIGHT_RED,"D":Tokens.STEEL}.get(results[i],Tokens.SURFACE)
			draw_colored_polygon(PackedVector2Array([Vector2(x+lean,2),Vector2(x+44+lean,2),Vector2(x+44-lean,38),Vector2(x-lean,38)]),fill)
			draw_string(Tokens.italic_font(),Vector2(x,29),results[i],HORIZONTAL_ALIGNMENT_CENTER,44,20,Tokens.INK)


static func tile(label: String, value: String, note: String="", accent: bool=false) -> Tile:
	var t:=Tile.new();t.label=label;t.value=value;t.note=note;t.accent=accent;return t


static func bar(label: String, value: float, maximum: float=100.0, text: String="", color: Color=Tokens.INK) -> Bar:
	var b:=Bar.new();b.label=label;b.value=value;b.maximum=maximum;b.text=text;b.color=color;return b


## Colour a 1–100 attribute like a scouting sheet: elite red, solid ink, weak steel.
static func attribute_color(v: float) -> Color:
	return Tokens.FIGHT_RED if v>=80 else Tokens.INK if v>=55 else Tokens.MUTED


## Row of tiles that wraps to two columns on narrow screens.
static func tile_row(tiles: Array, width: float) -> GridContainer:
	var grid:=GridContainer.new();grid.columns=tiles.size() if width>900 else 2
	grid.add_theme_constant_override("h_separation",Tokens.SPACE_S);grid.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	for t in tiles:grid.add_child(t)
	return grid
