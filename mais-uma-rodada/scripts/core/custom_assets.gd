class_name CustomAssets
extends RefCounted
## Imagens importadas pelo editor (fotos de jogadores, escudos, logos de competições, estádios) e
## imagens de mods. Os dados guardam só o nome (ou o caminho a partir de img/ no mod):
##   "crest_123.png"          importada pelo editor (user://custom/img)
##   "escudos/meu_clube.png"  de um mod ligado (user://mods/<id>/img/escudos/meu_clube.png)
##   "res://..." / "user://..." caminho completo (pacotes de imagens que venham com o jogo)
##   "@crests/flamengo"       imagem solta numa pasta de pacote (ver DropIns)
## Importadas pelo editor viram PNG quadrado de até 256 px (estádios: até 640 px, sem cortar).

const DIR := "user://custom/img"
const MAX_SIDE := 256
const MAX_WIDE := 640
const EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
## Prefixos de importação que guardam a imagem inteira (fotos largas).
const WIDE_PREFIXES: Array[String] = ["stadium"]

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Caminho real de uma imagem citada nos dados ("" se não existir em lugar nenhum).
static func path_of(file: String) -> String:
	if file == "" or file.contains(".."):
		return ""
	if file.begins_with("@"):
		return DropIns.path_of_ref(file)
	if file.begins_with("res://") or file.begins_with("user://"):
		return file if FileAccess.file_exists(file) or ResourceLoader.exists(file) else ""
	var own := "%s/%s" % [DIR, file]
	if FileAccess.file_exists(own):
		return own
	return Mods.image_path(file)


## Textura de um arquivo importado ou de mod ("" ou inexistente → null). Cacheada.
static func texture(file: String) -> Texture2D:
	if file == "":
		return null
	if _cache.has(file):
		return _cache[file]
	var path := path_of(file)
	var tex: Texture2D = null
	if path.begins_with("res://") and ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	elif path != "":
		var img := Image.load_from_file(path)
		if img != null and not img.is_empty():
			if file.begins_with("@"):
				_shrink(img, DropIns.MAX_WIDE if file.begins_with("@stadiums/") else DropIns.MAX_SIDE)
			tex = ImageTexture.create_from_image(img)
	_cache[file] = tex
	return tex


## Fotos grandes soltas nas pastas dos pacotes ficam menores na memória.
static func _shrink(img: Image, max_side: int) -> void:
	var big := maxi(img.get_width(), img.get_height())
	if big > max_side:
		var k := float(max_side) / big
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)


## Importa uma imagem do aparelho: recorta o centro em quadrado, reduz e salva.
## Retorna o nome do arquivo salvo ou "" se a imagem não pôde ser lida.
static func import_image(src_path: String, prefix: String) -> String:
	var img := Image.load_from_file(src_path)
	if img == null or img.is_empty():
		return ""
	return save_image(img, prefix)


static func save_image(img: Image, prefix: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var out: Image
	if WIDE_PREFIXES.has(prefix):
		out = img.duplicate() as Image
		if out.get_width() > MAX_WIDE:
			out.resize(MAX_WIDE, int(out.get_height() * float(MAX_WIDE) / out.get_width()), Image.INTERPOLATE_LANCZOS)
	else:
		var side := mini(img.get_width(), img.get_height())
		out = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
		if side > MAX_SIDE:
			out.resize(MAX_SIDE, MAX_SIDE, Image.INTERPOLATE_LANCZOS)
	out.convert(Image.FORMAT_RGBA8)
	var file := "%s_%d_%d.png" % [prefix, Time.get_unix_time_from_system(), randi() % 100000]
	if out.save_png("%s/%s" % [DIR, file]) != OK:
		return ""
	_cache.erase(file)
	return file


## Apaga uma imagem importada pelo editor (imagens de mods ficam: são do mod).
static func remove(file: String) -> void:
	if file == "" or file.contains("/"):
		return
	_cache.erase(file)
	var path := "%s/%s" % [DIR, file]
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
