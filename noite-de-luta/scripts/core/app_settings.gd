class_name AppSettings
extends RefCounted
## Preferências do aparelho (não fazem parte do save da carreira).

const PATH := "user://settings.cfg"
## Velocidade da luta ao vivo: segundos de luta por segundo de tela.
const FIGHT_SPEEDS: Array[float] = [6.0, 14.0, 40.0]
const FIGHT_SPEED_NAMES: Array[String] = ["Normal", "Rápida", "Muito rápida"]

static var sound: bool = true
static var vibration: bool = true
static var sfx_volume: int = 90
static var fight_speed: int = 1
## Como a luta ao vivo aparece: "2d" ou "3d" (animada) ou "texto" (só a narração).
const FIGHT_VIEWS: Array[String] = ["2d", "3d", "texto"]
const FIGHT_VIEW_NAMES: Array[String] = ["2D", "3D", "Texto"]
static var fight_view: String = "2d"
## Transições mais curtas.
static var reduce_motion: bool = false
## A abertura animada ao abrir o app (ferramentas e passeios de telas desligam; não é salvo).
static var intro: bool = true
## Idioma do jogo (I18n.LANGS). Vazio: o do aparelho na primeira abertura do app instalado;
## rodando do editor ou das ferramentas, português. `--lang=xx` na linha de comando vale antes.
static var lang: String = ""
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	_read()
	apply_lang()


static func _read() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sound = bool(cfg.get_value("audio", "sound", sound))
	vibration = bool(cfg.get_value("audio", "vibration", vibration))
	sfx_volume = int(cfg.get_value("audio", "sfx_volume", sfx_volume))
	fight_speed = clampi(int(cfg.get_value("jogo", "fight_speed", fight_speed)), 0, FIGHT_SPEEDS.size() - 1)
	reduce_motion = bool(cfg.get_value("jogo", "reduce_motion", reduce_motion))
	fight_view = String(cfg.get_value("jogo", "fight_view", fight_view))
	if fight_view not in FIGHT_VIEWS:
		fight_view = "2d"
	lang = String(cfg.get_value("jogo", "lang", lang))


## Idioma salvo, o da linha de comando ou o do aparelho; aplica no TranslationServer.
static func apply_lang() -> void:
	var code := lang
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			code = a.substr(7)
	if code == "" and not OS.has_feature("template"):
		code = I18n.DEFAULT
	I18n.apply(code)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--i18n-miss="):
			I18n.log_misses = true
			I18n.miss_path = a.substr(12)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("jogo", "fight_speed", fight_speed)
	cfg.set_value("jogo", "reduce_motion", reduce_motion)
	cfg.set_value("jogo", "fight_view", fight_view)
	cfg.set_value("jogo", "lang", lang)
	cfg.save(PATH)
