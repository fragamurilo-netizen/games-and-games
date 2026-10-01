class_name StatWidgets
extends RefCounted
## Stat panels in the UFC Undisputed 3 menu language, drawn on light panels:
## blue column labels, dark figures, striped rows, red for the selected or the
## elite value. Presentation only (Bible §§15–16,24).


## Callers still pass the dark-screen colours; map them onto the light panel.
static func ink(c: Color) -> Color:
	if c==Tokens.INK:return Tokens.PANEL_INK
	if c==Tokens.MUTED:return Tokens.PANEL_MUTED
	if c==Tokens.STEEL:return Tokens.HEADER_BAR
	return c


## Stat box: blue caption, big dark figure, small note (like COMPLETED / GRADE).
class Tile extends Control:
	var label:="";var value:="";var note:="";var accent:=false
	func _init() -> void:
		custom_minimum_size=Vector2(0,104);size_flags_horizontal=SIZE_EXPAND_FILL
		mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(Color.WHITE,.55))
		draw_rect(Rect2(Vector2.ZERO,size),Tokens.PANEL_LINE,false,1.0)
		if accent:draw_rect(Rect2(0,0,6,size.y),Tokens.FIGHT_RED)
		var x:=16.0;var width:=size.x-28
		draw_string(Tokens.DISPLAY_FONT,Vector2(x,26),label.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,width,16,Tokens.TABLE_BLUE)
		var fs:=36 if size.x>220 else 28
		while fs>18 and Tokens.italic_font().get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>width:fs-=2
		draw_string(Tokens.italic_font(),Vector2(x,30+fs),value,HORIZONTAL_ALIGNMENT_LEFT,width,fs,Tokens.PANEL_INK)
		if not note.is_empty():draw_string(Tokens.BODY_FONT,Vector2(x,size.y-12),note,HORIZONTAL_ALIGNMENT_LEFT,width,14,Tokens.FIGHT_RED if accent else Tokens.PANEL_MUTED)


## Labelled 0..max bar that fills in when shown.
class Bar extends Control:
	var label:="";var value:=0.0;var maximum:=100.0;var text:="";var color:=Tokens.PANEL_INK
	var _shown:=0.0
	func _init() -> void:
		custom_minimum_size=Vector2(0,40);size_flags_horizontal=SIZE_EXPAND_FILL
		mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _ready() -> void:
		var t:=create_tween();t.tween_method(func(v):_shown=v;queue_redraw(),0.0,1.0,.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	func _draw() -> void:
		var label_w:=minf(size.x*.42,280.0)
		draw_string(Tokens.DISPLAY_FONT,Vector2(0,26),label.to_upper(),HORIZONTAL_ALIGNMENT_LEFT,label_w-8,17,Tokens.PANEL_INK)
		var track:=Rect2(label_w,12,size.x-label_w-100,16)
		draw_rect(track,Tokens.PANEL_LINE)
		var ratio:=clampf(value/maxf(maximum,.001),0,1)*_shown
		if ratio>0:draw_rect(Rect2(track.position,Vector2(maxf(track.size.x*ratio,6),track.size.y)),StatWidgets.ink(color))
		draw_string(Tokens.italic_font(),Vector2(size.x-92,28),text if not text.is_empty() else str(roundi(value)),HORIZONTAL_ALIGNMENT_RIGHT,92,20,Tokens.PANEL_INK)


## Striped table with blue column headers (the SKILL NAME / BONUS / TOTAL layout).
## rows: Array of Arrays of strings; `widths` are fractions of the width; a
## numeric last column >= `highlight` is drawn red.
class Table extends Control:
	var headers: Array=[];var rows: Array=[];var widths: Array=[];var highlight:=80.0
	const ROW:=34
	func _init() -> void:
		size_flags_horizontal=SIZE_EXPAND_FILL;mouse_filter=MOUSE_FILTER_IGNORE;resized.connect(queue_redraw)
	func _ready() -> void:
		custom_minimum_size.y=ROW+8+rows.size()*ROW
	func _draw() -> void:
		var xs: Array=[0.0];var acc:=0.0
		for w in widths:
			acc+=float(w)*size.x;xs.append(acc)
		for c in headers.size():
			var align:=HORIZONTAL_ALIGNMENT_LEFT if c==0 else HORIZONTAL_ALIGNMENT_RIGHT
			draw_string(Tokens.DISPLAY_FONT,Vector2(xs[c]+8,ROW-8),str(headers[c]).to_upper(),align,xs[c+1]-xs[c]-16,17,Tokens.TABLE_BLUE)
		draw_line(Vector2(0,ROW+2),Vector2(size.x,ROW+2),Tokens.PANEL_LINE,1)
		for r in rows.size():
			var y:=ROW+6+r*ROW
			if r%2==1:draw_rect(Rect2(0,y,size.x,ROW),Color(Tokens.PANEL_ROW,.9))
			var row: Array=rows[r]
			for c in row.size():
				var cell:=str(row[c]);var align:=HORIZONTAL_ALIGNMENT_LEFT if c==0 else HORIZONTAL_ALIGNMENT_RIGHT
				var col:=Tokens.PANEL_INK
				if c==row.size()-1 and cell.is_valid_float() and float(cell)>=highlight:col=Tokens.FIGHT_RED
				draw_string(Tokens.DISPLAY_FONT,Vector2(xs[c]+8,y+ROW-10),cell.to_upper() if c==0 else cell,align,xs[c+1]-xs[c]-16,17,col)


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
			if i%2==1:draw_rect(Rect2(0,y,size.x,ROW-6),Color(Tokens.PANEL_ROW,.9))
			var red:=float(row.red);var blue:=float(row.blue)
			draw_string(Tokens.DISPLAY_FONT,Vector2(mid-110,y+24),str(row.label).to_upper(),HORIZONTAL_ALIGNMENT_CENTER,220,15,Tokens.TABLE_BLUE)
			# Escala 20–100: atributos raramente ficam abaixo de 20 e a diferença aparece.
			var rw:=half*clampf((red-20)/80.0,.04,1)*_shown;var bw:=half*clampf((blue-20)/80.0,.04,1)*_shown
			draw_rect(Rect2(mid-110-rw,y+10,rw,18),Tokens.FIGHT_RED if red>=blue else Color(Tokens.FIGHT_RED,.45))
			draw_rect(Rect2(mid+110,y+10,bw,18),Tokens.CORNER_BLUE if blue>=red else Color(Tokens.CORNER_BLUE,.45))
			draw_string(Tokens.italic_font(),Vector2(4,y+27),str(roundi(red)),HORIZONTAL_ALIGNMENT_LEFT,60,20,Tokens.PANEL_INK)
			draw_string(Tokens.italic_font(),Vector2(size.x-64,y+27),str(roundi(blue)),HORIZONTAL_ALIGNMENT_RIGHT,60,20,Tokens.PANEL_INK)


## Last results as chips: V (win) red, D (loss) dark grey, E (draw) light.
class Form extends Control:
	var results: Array=[]
	func _init() -> void:
		custom_minimum_size=Vector2(0,40);mouse_filter=MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if results.is_empty():
			draw_string(Tokens.BODY_FONT,Vector2(0,26),"Sem lutas nesta carreira ainda.",HORIZONTAL_ALIGNMENT_LEFT,-1,Tokens.FONT_SMALL,Tokens.PANEL_MUTED);return
		for i in results.size():
			var x:=i*52.0;var lean:=36*Tokens.SLANT*.5
			var fill: Color={"V":Tokens.FIGHT_RED,"D":Tokens.HEADER_BAR}.get(results[i],Tokens.PANEL_LINE)
			draw_colored_polygon(PackedVector2Array([Vector2(x+lean,2),Vector2(x+44+lean,2),Vector2(x+44-lean,38),Vector2(x-lean,38)]),fill)
			draw_string(Tokens.italic_font(),Vector2(x,29),results[i],HORIZONTAL_ALIGNMENT_CENTER,44,20,Color.WHITE if results[i]!="E" else Tokens.PANEL_INK)


## Hub card: grey header bar (lights red on touch) over a light body with one
## big figure and a line of context; a door to another area in one tap.
class HubCard extends Button:
	var heading:="";var figure:="";var detail:="";var soon:=false
	func _init() -> void:
		custom_minimum_size=Vector2(0,148);size_flags_horizontal=SIZE_EXPAND_FILL
		clip_contents=true;flat=true
		for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	func _ready() -> void:
		disabled=soon
	func _draw() -> void:
		var lit:=not soon and (is_hovered() or button_pressed or has_focus())
		draw_rect(Rect2(Vector2.ZERO,size),Color(Color.WHITE,.5 if not soon else .25))
		draw_rect(Rect2(Vector2.ZERO,size),Tokens.PANEL_LINE,false,1.0)
		var lean:=40*Tokens.SLANT*.5
		var bar:=Tokens.FIGHT_RED if lit else Tokens.HEADER_BAR
		draw_colored_polygon(PackedVector2Array([Vector2(lean,0),Vector2(size.x,0),Vector2(size.x-lean,40),Vector2(0,40)]),bar if not soon else Color(Tokens.HEADER_BAR,.5))
		draw_string(Tokens.italic_font(),Vector2(0,28),heading.to_upper(),HORIZONTAL_ALIGNMENT_CENTER,size.x,20,Color.WHITE if lit else Tokens.HEADER_TEXT)
		var w:=size.x-56
		var fs:=38
		while fs>20 and Tokens.italic_font().get_string_size(figure,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x>w:fs-=2
		draw_string(Tokens.italic_font(),Vector2(14,50+fs),figure,HORIZONTAL_ALIGNMENT_LEFT,w,fs,Tokens.PANEL_MUTED if soon else Tokens.PANEL_INK)
		draw_string(Tokens.BODY_FONT,Vector2(14,size.y-14),detail,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,16,Tokens.PANEL_MUTED)
		if not soon:draw_string(Tokens.italic_font(),Vector2(size.x-36,50+fs),"›",HORIZONTAL_ALIGNMENT_LEFT,-1,40,Tokens.FIGHT_RED)


static func hub_card(heading: String, figure: String, detail: String, soon: bool=false) -> HubCard:
	var c:=HubCard.new();c.heading=heading;c.figure=figure;c.detail=detail;c.soon=soon;return c


static func tile(label: String, value: String, note: String="", accent: bool=false) -> Tile:
	var t:=Tile.new();t.label=label;t.value=value;t.note=note;t.accent=accent;return t


static func bar(label: String, value: float, maximum: float=100.0, text: String="", color: Color=Tokens.INK) -> Bar:
	var b:=Bar.new();b.label=label;b.value=value;b.maximum=maximum;b.text=text;b.color=color;return b


static func table(headers: Array, rows: Array, widths: Array) -> Table:
	var t:=Table.new();t.headers=headers;t.rows=rows;t.widths=widths;return t


## Colour a 1–100 attribute like a scouting sheet: elite red, solid ink, weak grey.
static func attribute_color(v: float) -> Color:
	return Tokens.FIGHT_RED if v>=80 else Tokens.PANEL_INK if v>=55 else Tokens.PANEL_MUTED


## Row of tiles that wraps to two columns on narrow screens.
static func tile_row(tiles: Array, width: float) -> GridContainer:
	var grid:=GridContainer.new();grid.columns=tiles.size() if width>900 else 2
	grid.add_theme_constant_override("h_separation",Tokens.SPACE_S);grid.add_theme_constant_override("v_separation",Tokens.SPACE_S)
	for t in tiles:grid.add_child(t)
	return grid


## Photo box with the name over the bottom edge (the 2012 portrait frame),
## built on the shared FighterPortrait.
static func portrait_frame(f: Fighter, width: float) -> Control:
	var frame:=PanelContainer.new()
	frame.add_theme_stylebox_override("panel",Tokens.flat_box(Tokens.CANVAS,Color.WHITE,3,0))
	frame.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;frame.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
	var photo:=FighterPortrait.make(f,width,Tokens.FIGHT_RED)
	frame.add_child(photo)
	var name:=Label.new();name.text=f.first_name+"\n"+f.last_name
	name.add_theme_font_override("font",Tokens.italic_font());name.add_theme_font_size_override("font_size",20)
	name.add_theme_color_override("font_color",Color.WHITE)
	name.add_theme_color_override("font_outline_color",Color.BLACK);name.add_theme_constant_override("outline_size",6)
	name.size_flags_vertical=Control.SIZE_SHRINK_END;name.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	var pad:=MarginContainer.new();pad.add_theme_constant_override("margin_left",8);pad.add_theme_constant_override("margin_bottom",6)
	pad.mouse_filter=Control.MOUSE_FILTER_IGNORE;pad.add_child(name);frame.add_child(pad)
	return frame
