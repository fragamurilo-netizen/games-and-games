extends Node
## Efeitos sonoros (assets/audio/efeitos) e vibração. Música ainda não existe neste jogo.

const SFX_DIR := "res://assets/audio/efeitos/"

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0


func _ready() -> void:
	AppSettings.load_settings()
	if AudioServer.get_bus_index(&"SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, &"SFX")
		AudioServer.set_bus_send(idx, &"Master")
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var s: AudioStream = null
		for ext in [".wav", ".ogg"]:
			var path: String = SFX_DIR + sound + String(ext)
			if ResourceLoader.exists(path):
				s = load(path)
				break
		_cache[sound] = s
	return _cache[sound]


func play(sound: String, volume_db: float = 0.0) -> void:
	if not AppSettings.sound:
		return
	var s := _stream(sound)
	if s == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.volume_db = volume_db + linear_to_db(maxf(0.01, AppSettings.sfx_volume / 100.0))
	p.play()


func click() -> void:
	play("click", -8.0)


func vibrate(ms: int) -> void:
	if AppSettings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)
