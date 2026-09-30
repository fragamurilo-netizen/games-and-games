class_name FightReplayView
extends Control
## Fight Night screen inside the game. Reuses the original JS/Canvas Fight Studio
## without a second renderer: the broadcast lives in a WebView embedded in this
## screen's stage, framed by the game's own header.
## Android: CornerOfficeStudio plugin (child view over the stage rect).
## Desktop: godot_wry `WebView` node. Browser only as a last resort.
## A whole night plays as a queue: the broadcast's "PRÓXIMA LUTA" asks this
## screen for the next bout; results were already decided by the simulation.
const HEADER_H:=96
var _bridge: Object
var _web: Control
var _html:=""
var _stage: Control
var _note: Label
var _title:=""
var _subtitle:=""
var _top_inset:=0.0
var _queue: Array=[]
var _index:=0

func open(data: Dictionary) -> void:
	open_night([data])

## Plays bouts in card order (first prelim → main event).
func open_night(replays: Array, start:=0) -> void:
	_queue=replays;_index=clampi(start,0,maxi(0,replays.size()-1))
	theme=Tokens.build_theme()
	mouse_filter=MOUSE_FILTER_STOP
	_update_safe_area()
	_stage=Control.new();_stage.mouse_filter=MOUSE_FILTER_IGNORE;add_child(_stage)
	_note=Label.new();_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_note.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;_note.add_theme_color_override("font_color",Tokens.MUTED);_stage.add_child(_note)
	_note.set_anchors_and_offsets_preset(PRESET_FULL_RECT);_note.offset_left=24;_note.offset_right=-24
	var back:=Button.new();back.text="‹ CARD";back.flat=true;back.focus_mode=FOCUS_NONE
	back.add_theme_font_override("font",Tokens.DISPLAY_FONT);back.add_theme_font_size_override("font_size",24)
	back.add_theme_color_override("font_color",Tokens.INK);back.pressed.connect(close);add_child(back);back.name="Back"
	resized.connect(_layout)
	_layout()
	if _queue.is_empty():_note.text="Nenhuma luta para transmitir.";return
	var packed:=FileAccess.get_file_as_bytes("res://presentation/fight/studio.cobundle")
	if not packed.is_empty():_html=packed.decompress_dynamic(16000000,FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	if _html.is_empty():_note.text="A transmissão não foi empacotada. Rode tools/build_studio_bundle.py.";return
	# Wait one frame so the stage has its final size before the web surface is placed.
	await get_tree().process_frame
	if not is_inside_tree():return
	_play()

func next_bout() -> void:
	if _index+1>=_queue.size():close();return
	_index+=1;_play()

## Replay handed to the broadcast, plus its place on the card (presentation only).
func bout_data(index: int) -> Dictionary:
	var data: Dictionary=_queue[index].duplicate()
	if _queue.size()>1:
		var p: Dictionary=data.get("presentation",{}).duplicate()
		p.card_position={"index":index+1,"total":_queue.size()}
		if index+1<_queue.size():p.next_bout=str(_queue[index+1].get("title",""))
		data.presentation=p
	return data

func _play() -> void:
	var data:=bout_data(_index)
	_describe(data)
	queue_redraw()
	var player:=FightReplayPlayer.new()
	if not player.load_replay(data):_note.text="Replay inválido: "+str(player.errors);_hide_web();return
	var html:=_html.replace("__CO_REPLAY_JSON__",JSON.stringify(data).replace("<","\\u003c"))
	html=html.replace("<body ","<body data-embedded=\"1\" ")
	_note.text="Preparando a transmissão…"
	if OS.get_name()=="Android":_open_android(html)
	elif ClassDB.class_exists("WebView") and DisplayServer.get_name()!="headless":_open_desktop(html)
	else:_open_browser(html)

func _hide_web() -> void:
	if _bridge:_bridge.set_visible(false)
	if _web:_web.queue_free();_web=null

func close() -> void:
	queue_free()

func _describe(data: Dictionary) -> void:
	var names: Array[String]=[]
	for id in data.get("fighter_ids",[]):
		var f: Dictionary=data.get("fighters",{}).get(id,{})
		var full: String=str(f.get("name",id))
		names.append(full.get_slice(" ",full.get_slice_count(" ")-1).to_upper())
	_title=" × ".join(names) if names.size()==2 else "FIGHT NIGHT"
	var p: Dictionary=data.get("presentation",{})
	var parts: Array[String]=[]
	for key in ["event_name","city"]:
		if not str(p.get(key,"")).is_empty():parts.append(str(p[key]).to_upper())
	if not str(p.get("title_stakes","")).is_empty():parts.append("DISPUTA DE CINTURÃO")
	if _queue.size()>1:parts.append("LUTA %d/%d"%[_index+1,_queue.size()])
	_subtitle=" / ".join(parts) if not parts.is_empty() else "CO SPORTS · FIGHT NIGHT"

func _open_android(html: String) -> void:
	if not Engine.has_singleton("CornerOfficeStudio"):
		_note.text="O APK precisa incluir o módulo de transmissão. Use a compilação Android completa.";return
	if _bridge==null:
		_bridge=Engine.get_singleton("CornerOfficeStudio")
		_bridge.connect("closed",close)
		if _bridge.has_signal("next"):_bridge.connect("next",next_bout)
	var r:=_stage_window_rect()
	# show() replaces the previous bout's WebView without emitting "closed".
	_bridge.show(html,r.position.x,r.position.y,r.size.x,r.size.y)

func _open_desktop(html: String) -> void:
	# A fresh surface per bout: godot_wry reads `html` when the node enters the tree.
	if _web:_web.queue_free()
	_web=ClassDB.instantiate("WebView")
	_web.set("full_window_size",false)
	_web.set("url","")
	_web.set("html",html)
	_web.set("devtools",false)
	_web.set("autoplay",true)
	_web.set("forward_input_events",false)
	_web.set("zoom_hotkeys",false)
	_web.set("background_color",Tokens.CANVAS)
	_web.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_web.connect("ipc_message",_on_ipc)
	_stage.add_child(_web)
	_note.text=""

func _open_browser(html: String) -> void:
	_note.text="Este sistema não tem WebView embutido. A transmissão abriu no navegador; a carreira continua salva aqui."
	var path:="user://fight-studio.html"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return
	file.store_string(html);file.close()
	if DisplayServer.get_name()!="headless":OS.shell_open(ProjectSettings.globalize_path(path))

func _on_ipc(message: String) -> void:
	if message=="close":close()
	elif message=="next":next_bout.call_deferred()

func _update_safe_area() -> void:
	_top_inset=0.0
	if OS.get_name()!="Android":return
	var safe:=DisplayServer.get_display_safe_area()
	var window:=DisplayServer.window_get_size()
	var viewport:=get_viewport_rect().size if is_inside_tree() else Vector2(window)
	if window.y>0:_top_inset=float(safe.position.y)*viewport.y/float(window.y)

func _layout() -> void:
	if _stage==null:return
	_update_safe_area()
	var top:=_top_inset+HEADER_H
	_stage.position=Vector2(0,top);_stage.size=Vector2(size.x,maxf(1,size.y-top))
	var back:=get_node_or_null("Back") as Button
	if back:back.position=Vector2(0,_top_inset);back.size=Vector2(132,HEADER_H-8)
	if _bridge:
		var r:=_stage_window_rect()
		_bridge.set_rect(r.position.x,r.position.y,r.size.x,r.size.y)
	queue_redraw()

## Stage rectangle in window pixels (the Android view system's coordinates).
func _stage_window_rect() -> Rect2i:
	var xf:=get_viewport().get_final_transform()*_stage.get_global_transform_with_canvas()
	var a:=xf*Vector2.ZERO
	var b:=xf*_stage.size
	return Rect2i(Vector2i(roundi(a.x),roundi(a.y)),Vector2i(roundi(b.x-a.x),roundi(b.y-a.y)))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Tokens.CANVAS)
	var y:=_top_inset
	var h:=float(HEADER_H-8)
	# UD3-style header: red cut block for navigation, steel band for the bout.
	draw_colored_polygon(PackedVector2Array([Vector2(0,y),Vector2(150,y),Vector2(126,y+h),Vector2(0,y+h)]),Tokens.FIGHT_RED)
	draw_colored_polygon(PackedVector2Array([Vector2(154,y),Vector2(size.x,y),Vector2(size.x,y+h),Vector2(130,y+h)]),Tokens.SURFACE)
	var width:=size.x-180
	var font_size:=30 if size.x<600 else 36
	draw_string(Tokens.DISPLAY_FONT,Vector2(160,y+44),_title,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,Tokens.INK)
	draw_string(Tokens.BODY_FONT,Vector2(162,y+74),_subtitle,HORIZONTAL_ALIGNMENT_LEFT,width,16,Tokens.MUTED)
	draw_line(Vector2(0,y+h+2),Vector2(size.x,y+h+2),Tokens.FIGHT_RED,3,true)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:close()

func _exit_tree() -> void:
	if _bridge:
		if _bridge.is_connected("closed",close):_bridge.disconnect("closed",close)
		if _bridge.has_signal("next") and _bridge.is_connected("next",next_bout):_bridge.disconnect("next",next_bout)
		_bridge.close()
