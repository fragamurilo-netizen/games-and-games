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
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
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


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("jogo", "fight_speed", fight_speed)
	cfg.set_value("jogo", "reduce_motion", reduce_motion)
	cfg.set_value("jogo", "fight_view", fight_view)
	cfg.save(PATH)
