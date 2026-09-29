class_name FightReplayView
extends Control
## Reuses the original JS/Canvas Fight Studio without a second renderer.
## Android: offline WebView plugin. Desktop preview: the same standalone HTML.
var _bridge: Object
var _html:=""
func open(data: Dictionary) -> void:
	theme=Tokens.build_theme()
	var bg:=ColorRect.new();bg.color=Tokens.CANVAS;bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);add_child(bg)
	var box:=VBoxContainer.new();box.set_anchors_and_offsets_preset(PRESET_FULL_RECT);box.offset_left=24;box.offset_right=-24;box.offset_top=32;add_child(box)
	var title:=Label.new();title.text="TRANSMISSÃO DA LUTA";title.add_theme_font_override("font",Tokens.DISPLAY_FONT);box.add_child(title)
	var note:=Label.new();note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;box.add_child(note)
	var back:=Button.new();back.text="VOLTAR AO CARD";back.custom_minimum_size.y=Tokens.TOUCH_MIN;back.pressed.connect(queue_free);box.add_child(back)
	var player:=FightReplayPlayer.new()
	if not player.load_replay(data):note.text="Replay inválido: "+str(player.errors);return
	var packed:=FileAccess.get_file_as_bytes("res://presentation/fight/studio.html.gz")
	_html=packed.decompress_dynamic(16000000,FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	if _html.is_empty():note.text="A transmissão não foi empacotada. Rode tools/build_studio_bundle.py.";return
	_html=_html.replace("__CO_REPLAY_JSON__",JSON.stringify(data).replace("<","\\u003c"))
	if OS.get_name()=="Android":
		if not Engine.has_singleton("CornerOfficeStudio"):
			note.text="O APK precisa incluir o módulo de transmissão. Use a compilação Android completa.";return
		_bridge=Engine.get_singleton("CornerOfficeStudio")
		_bridge.connect("closed",queue_free)
		_bridge.show(_html)
	else:
		note.text="A transmissão original do Fight Studio abriu no navegador. A carreira continua salva aqui."
		var button:=Button.new();button.text="ABRIR TRANSMISSÃO NOVAMENTE";button.custom_minimum_size.y=Tokens.TOUCH_MIN;button.pressed.connect(_open_desktop);box.add_child(button)
		_open_desktop()
func _open_desktop() -> void:
	var path:="user://fight-studio.html"
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:return
	file.store_string(_html);file.close()
	OS.shell_open(ProjectSettings.globalize_path(path))
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_GO_BACK_REQUEST:queue_free()
func _exit_tree() -> void:
	if _bridge:
		if _bridge.is_connected("closed",queue_free):_bridge.disconnect("closed",queue_free)
		_bridge.close()
