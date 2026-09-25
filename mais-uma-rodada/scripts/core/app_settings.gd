class_name AppSettings
extends RefCounted
## Preferências do aparelho (não fazem parte do save da carreira).

const PATH := "user://settings.cfg"
const SPEED_INSTANT := 0
const SPEED_FAST := 1
const SPEED_NORMAL := 2
const SPEED_NAMES: Array[String] = ["Instantâneo", "Rápido", "Normal"]

static var sound: bool = true
static var vibration: bool = true
static var match_speed: int = SPEED_FAST
static var tutorial_done: bool = false
static var language: String = I18n.DEFAULT
## Interface nas cores do clube durante a carreira.
static var team_colors: bool = true
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sound = cfg.get_value("audio", "sound", true)
	vibration = cfg.get_value("audio", "vibration", true)
	match_speed = cfg.get_value("game", "match_speed", SPEED_FAST)
	tutorial_done = cfg.get_value("game", "tutorial_done", false)
	language = cfg.get_value("game", "language", I18n.DEFAULT)
	team_colors = cfg.get_value("game", "team_colors", true)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("game", "match_speed", match_speed)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "team_colors", team_colors)
	cfg.save(PATH)
