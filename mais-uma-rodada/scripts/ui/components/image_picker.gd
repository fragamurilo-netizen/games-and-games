class_name ImagePicker
extends RefCounted
## Escolhe uma imagem do aparelho (seletor nativo no Android; janela de arquivos no PC),
## importa como PNG quadrado e devolve o nome do arquivo salvo (ou "" se cancelado/erro).


static func pick(prefix: String, done: Callable) -> void:
	var filters := PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Imagens"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Escolha uma imagem", "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			func(status: bool, paths: PackedStringArray, _idx: int):
				_finish(status, paths, prefix, done))
		return
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = filters
	fd.title = "Escolha uma imagem"
	fd.size = Vector2i(680, 900)
	UIManager.main.add_child(fd)
	fd.file_selected.connect(func(path: String):
		_finish(true, PackedStringArray([path]), prefix, done)
		fd.queue_free())
	fd.canceled.connect(func(): fd.queue_free())
	fd.popup_centered()


static func _finish(status: bool, paths: PackedStringArray, prefix: String, done: Callable) -> void:
	if not status or paths.is_empty():
		return
	var file := CustomAssets.import_image(paths[0], prefix)
	if file == "":
		UIManager.toast("Não foi possível ler essa imagem.", UIColors.RED)
		return
	done.call(file)
