class_name AppSettings
extends RefCounted
## Preferências do aparelho (não fazem parte do save da carreira).

const PATH := "user://settings.cfg"
const SPEED_INSTANT := 0
const SPEED_FAST := 1
const SPEED_NORMAL := 2
const SPEED_TURBO := 3
const SPEED_NAMES: Array[String] = ["Instantâneo", "Rápido", "Normal", "Turbo"]
## Ordem nas opções: do mais lento ao resultado direto.
const SPEED_ORDER: Array[int] = [SPEED_NORMAL, SPEED_FAST, SPEED_TURBO, SPEED_INSTANT]

static var sound: bool = true
static var vibration: bool = true
static var match_speed: int = SPEED_FAST
static var tutorial_done: bool = false
static var language: String = I18n.DEFAULT
## Moeda de exibição. A economia interna usa euro-base para manter o save determinístico.
const CURRENCY_EUR := 0
const CURRENCY_BRL := 1
const CURRENCY_USD := 2
const CURRENCY_NAMES: Array[String] = ["Euro (€)", "Real (R$)", "Dólar (US$)"]
static var currency: int = CURRENCY_EUR
## Interface nas cores do clube durante a carreira.
static var team_colors: bool = true
## De onde vêm as cores da interface: 0 dourado, 1 clube, 2 liga. E quanto tingem fundo e menus.
const COLOR_SOURCE_NAMES := ["Dourado", "Meu clube", "Minha liga"]
const TINT_NAMES := ["Sem cor", "Suave", "Forte"]
const TINT_AMOUNTS := [0.0, 0.35, 0.7]
static var color_source: int = 1
static var bg_tint: int = 1
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
## Partida ao vivo: 0 = lances em destaque (campo menor), 1 = campo grande, 2 = só narração.
const MATCH_VIEW_NAMES: Array[String] = ["Campo menor", "Campo grande", "Só narração"]
static var match_view: int = 0
## Visual do campo na partida: 0 = clássico 2D (bolinhas, estilo dos jogos de técnico antigos), 1 = transmissão.
const MATCH_GFX_NAMES: Array[String] = ["Clássico 2D", "Transmissão"]
static var match_gfx: int = 0
## Grafismo de TV na partida (pacote da liga): 0 = desligado (comemoração antiga), 1 = só os gols
## (faixa do gol e tarja do goleador), 2 = completo (números, tabela ao vivo, substituições,
## cartões, outros jogos, melhor em campo).
const TV_GRAPHICS_NAMES: Array[String] = ["Desligado", "Só os gols", "Completo"]
static var tv_graphics: int = 2
## Escudos, logos, fotos e uniformes em imagem dos pacotes instalados (drop-ins): ligados (true) ou
## só os desenhos do jogo (false).
static var pack_images: bool = true
## Animações de gol e transições mais curtas.
static var reduce_motion: bool = false
static var _loaded := false


static func load_settings() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		language = I18n.system_language() # primeira abertura: o idioma do aparelho
		return
	sound = cfg.get_value("audio", "sound", true)
	vibration = cfg.get_value("audio", "vibration", true)
	match_speed = clampi(int(cfg.get_value("game", "match_speed", SPEED_FAST)), SPEED_INSTANT, SPEED_TURBO)
	tutorial_done = cfg.get_value("game", "tutorial_done", false)
	language = cfg.get_value("game", "language", I18n.system_language())
	currency = clampi(int(cfg.get_value("game", "currency", CURRENCY_EUR)), CURRENCY_EUR, CURRENCY_USD)
	team_colors = cfg.get_value("game", "team_colors", true)
	color_source = clampi(int(cfg.get_value("look", "color_source", 1 if team_colors else 0)), 0, 2)
	bg_tint = clampi(int(cfg.get_value("look", "bg_tint", 1)), 0, 2)
	career_edit = cfg.get_value("game", "career_edit", false)
	theme_mode = cfg.get_value("look", "theme_mode", THEME_DARK)
	ui_scale = clampi(cfg.get_value("look", "ui_scale", 0), 0, UI_SCALES.size() - 1)
	reduce_motion = cfg.get_value("look", "reduce_motion", false)
	music = cfg.get_value("audio", "music", true)
	music_volume = cfg.get_value("audio", "music_volume", 60)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 100)
	music_track = cfg.get_value("audio", "music_track", 0)
	music_in_match = cfg.get_value("audio", "music_in_match", false)
	match_view = clampi(int(cfg.get_value("game", "match_view", 0)), 0, 2)
	match_gfx = clampi(int(cfg.get_value("game", "match_gfx", 0)), 0, 1)
	tv_graphics = clampi(int(cfg.get_value("game", "tv_graphics", 2)), 0, 2)
	pack_images = bool(cfg.get_value("look", "pack_images", true))


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("game", "match_speed", match_speed)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.set_value("game", "language", language)
	cfg.set_value("game", "currency", currency)
	cfg.set_value("game", "team_colors", color_source != 0)
	cfg.set_value("look", "color_source", color_source)
	cfg.set_value("look", "bg_tint", bg_tint)
	cfg.set_value("game", "career_edit", career_edit)
	cfg.set_value("look", "theme_mode", theme_mode)
	cfg.set_value("look", "ui_scale", ui_scale)
	cfg.set_value("look", "reduce_motion", reduce_motion)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("audio", "music_track", music_track)
	cfg.set_value("audio", "music_in_match", music_in_match)
	cfg.set_value("game", "match_view", match_view)
	cfg.set_value("game", "match_gfx", match_gfx)
	cfg.set_value("game", "tv_graphics", tv_graphics)
	cfg.set_value("look", "pack_images", pack_images)
	cfg.save(PATH)


## O modo claro está valendo agora (escolhido ou seguindo o aparelho)?
static func wants_light() -> bool:
	if theme_mode == THEME_SYSTEM:
		return not DisplayServer.is_dark_mode_supported() or not DisplayServer.is_dark_mode()
	return theme_mode == THEME_LIGHT