class_name CustomAssets
extends RefCounted
## Imagens importadas pelo editor (fotos de jogadores, escudos, logos de competições).
## Ficam em user://custom/img como PNG quadrado de até 256 px; o jogo guarda só o nome do arquivo.

const DIR := "user://custom/img"
const MAX_SIDE := 256

static var _cache: Dictionary = {}


## Textura de um arquivo importado ("" ou inexistente → null). Cacheada.
static func texture(file: String) -> Texture2D:
	if file == "":
		return null
	if _cache.has(file):
		return _cache[file]
	var path := "%s/%s" % [DIR, file]
	var tex: Texture2D = null
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_cache[file] = tex
	return tex


## Importa uma imagem do aparelho: recorta o centro em quadrado, reduz e salva.
## Retorna o nome do arquivo salvo ou "" se a imagem não pôde ser lida.
static func import_image(src_path: String, prefix: String) -> String:
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		return ""
	return save_image(img, prefix)


static func save_image(img: Image, prefix: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var side := mini(img.get_width(), img.get_height())
	var sq := img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
	if side > MAX_SIDE:
		sq.resize(MAX_SIDE, MAX_SIDE, Image.INTERPOLATE_LANCZOS)
	sq.convert(Image.FORMAT_RGBA8)
	var file := "%s_%d_%d.png" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]
	if sq.save_png("%s/%s" % [DIR, file]) != OK:
		return ""
	_cache.erase(file)
	return file


static func remove(file: String) -> void:
	if file == "":
		return
	_cache.erase(file)
	var path := "%s/%s" % [DIR, file]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
