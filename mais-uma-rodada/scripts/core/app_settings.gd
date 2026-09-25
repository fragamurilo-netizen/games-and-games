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
## Editar jogadores e clubes do save durante a carreira (desligado = carreira "limpa"; o Editor do menu
## continua mudando o padrão das novas carreiras).
static var career_edit: bool = false
## Aparência: 0 = escuro, 1 = claro, 2 = igual ao aparelho.
const THEME_DARK := 0
const THEME_LIGHT := 1
const THEME_SYSTEM := 2
const THEME_NAMES: Array[String] = ["Escuro", "Claro", "Do aparelho"]
static var theme_mode: int = THEME_DARK
## Tamanho da interface (fator de escala do conteúdo).
const UI_SCALES: Array[float] = [1.0, 1.1, 1.2]
const UI_SCALE_NAMES: Array[String] = ["Normal", "Grande", "Maior"]
static var ui_scale: int = 0
## Música de fundo (gerada pelo jogo) e volumes de 0 a 100.
static var music: bool = true
static var music_volume: int = 60
static var sfx_volume: int = 100
static var music_track: int = 0
static var music_in_match: bool = false
## Animações de gol e transições mais curtas.
static var reduce_motion: bool = false
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
	career_edit = cfg.get_value("game", "career_edit", false)
	theme_mode = cfg.get_value("look", "theme_mode", THEME_DARK)
	ui_scale = clampi(cfg.get_value("look", "ui_scale", 0), 0, UI_SCALES.size() - 1)
	reduce_motion = cfg.get_value("look", "reduce_motion", false)
	music = cfg.get_value("audio", "music", true)
	music_volume = cfg.get_value("audio", "music_volume", 60)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 100)
	music_track = cfg.get_value("audio", "music_track", 0)
	music_in_match = cfg.get_value("audio", "music_in_match", false)


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("game", "match_speed", match_speed)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "team_colors", team_colors)
	cfg.set_value("game", "career_edit", career_edit)
	cfg.set_value("look", "theme_mode", theme_mode)
	cfg.set_value("look", "ui_scale", ui_scale)
	cfg.set_value("look", "reduce_motion", reduce_motion)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_track", music_track)
	cfg.set_value("audio", "music_in_match", music_in_match)
	cfg.save(PATH)


## O modo claro está valendo agora (escolhido ou seguindo o aparelho)?
static func wants_light() -> bool:
	if theme_mode == THEME_SYSTEM:
		return not DisplayServer.is_dark_mode_supported() or not DisplayServer.is_dark_mode()
	return theme_mode == THEME_LIGHT
