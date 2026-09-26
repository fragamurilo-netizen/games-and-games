extends Node
## Sons sintetizados em tempo de execução (nenhum arquivo de áudio no APK) + vibração.
## Cada som é gerado uma única vez, sob demanda, e reaproveitado.
## A música de fundo (MusicSynth) é gerada numa thread e guardada em cache no aparelho.

const RATE := 22050
const MUSIC_CACHE := "user://music_v1_%d.pcm"

var _players: Array[AudioStreamPlayer] = []
var _cache: Dictionary = {}
var _next := 0
var _music: AudioStreamPlayer
var _music_streams: Dictionary = {} # faixa -> AudioStreamWAV
var _music_task := -1
var _music_task_track := -1
var _music_samples := PackedFloat32Array()
var _in_match := false
var _fade: Tween


func _ready() -> void:
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	apply_volumes()


func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus)
	AudioServer.set_bus_send(idx, &"Master")


## Aplica os volumes das Opções (0 a 100) aos canais de música e de efeitos.
func apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"SFX"), _to_db(AppSettings.sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(&"Music"), _to_db(AppSettings.music_volume) - 6.0)


static func _to_db(v: int) -> float:
	return -80.0 if v <= 0 else linear_to_db(pow(v / 100.0, 1.6))


# ---------------------------------------------------------------------------
# Música de fundo
# ---------------------------------------------------------------------------

## Liga (ou desliga) a música conforme as Opções e a tela atual.
func start_music() -> void:
	var want := AppSettings.music and AppSettings.music_volume > 0 and (not _in_match or AppSettings.music_in_match)
	if not want:
		_fade_to(-40.0, func(): _music.stop())
		return
	var track := clampi(AppSettings.music_track, 0, MusicSynth.TRACKS.size() - 1)
	var stream: AudioStreamWAV = _music_streams.get(track)
	if stream == null:
		stream = _load_cached(track)
	if stream == null:
		_render_async(track)
		return
	_music_streams[track] = stream
	if _music.stream != stream or not _music.playing:
		_music.stream = stream
		_music.volume_db = -30.0
		_music.play()
	_fade_to(0.0)


## Avisada a cada troca de tela: durante a partida a música some (a torcida é o som do jogo).
func screen_changed(screen_name: String) -> void:
	var match_now := screen_name == "match"
	if match_now == _in_match:
		return
	_in_match = match_now
	start_music()


func _fade_to(db: float, done: Callable = Callable()) -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not _music.playing:
		if done.is_valid():
			done.call()
		return
	_fade = create_tween()
	_fade.tween_property(_music, "volume_db", db, 0.8)
	if done.is_valid():
		_fade.tween_callback(done)


func _render_async(track: int) -> void:
	if _music_task >= 0:
		return # já há uma faixa sendo gerada; ao terminar, start_music confere a escolhida
	_music_task_track = track
	_music_task = WorkerThreadPool.add_task(func():
		_music_samples = MusicSynth.new().render(track))
	set_process(true)


func _process(_delta: float) -> void:
	if _music_task < 0:
		set_process(false)
		return
	if not WorkerThreadPool.is_task_completed(_music_task):
		return
	WorkerThreadPool.wait_for_task_completion(_music_task)
	_music_task = -1
	var wav := _to_wav(_music_samples)
	_music_samples = PackedFloat32Array()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / 2
	_music_streams[_music_task_track] = wav
	var f := FileAccess.open(MUSIC_CACHE % _music_task_track, FileAccess.WRITE)
	if f != null:
		f.store_buffer(wav.data)
		f.close()
	start_music()


func _load_cached(track: int) -> AudioStreamWAV:
	var path := MUSIC_CACHE % track
	if not FileAccess.file_exists(path):
		return null
	var data := FileAccess.get_file_as_bytes(path)
	if data.size() < RATE * 2:
		return null
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = data.size() / 2
	return wav


## A faixa já foi gerada (ou está no cache do aparelho)?
func music_ready(track: int) -> bool:
	return _music_streams.has(track) or FileAccess.file_exists(MUSIC_CACHE % track)


func click() -> void:
	play("click", -8.0)


func play(name: String, volume_db: float = 0.0) -> void:
	if not AppSettings.sound:
		return
	var stream := _stream(name)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.play()


func vibrate(ms: int) -> void:
	if AppSettings.vibration and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## Celebração de gol: rugido proporcional à importância + vibração.
func goal(importance: float, ours: bool) -> void:
	if ours:
		play("goal_big" if importance >= 0.6 else "goal", 0.0)
		vibrate(int(120 + importance * 380))
	else:
		play("groan", -4.0)
		vibrate(60)


func _notification(what: int) -> void:
	# No Android o jogo em segundo plano não deve continuar tocando.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if OS.has_feature("mobile"):
			_music.stream_paused = true
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_music.stream_paused = false


func _stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var samples := PackedFloat32Array()
	match name:
		"click":
			samples = _tone(1150.0, 0.035, 0.35, 0.002, 0.03)
		"whistle":
			samples = _whistle(0.45)
		"whistle_end":
			samples = _concat([_whistle(0.3), _silence(0.12), _whistle(0.3), _silence(0.12), _whistle(0.7)])
		"goal":
			samples = _crowd(2.2, 0.55)
		"goal_big":
			samples = _mix(_crowd(3.2, 0.8), _horn(1.4), 0.35)
		"groan":
			samples = _crowd(1.1, 0.25, true)
		"chance":
			samples = _crowd(0.9, 0.3, true)
		"card":
			samples = _tone(520.0, 0.12, 0.3, 0.005, 0.1)
		"win":
			samples = _arpeggio([523.25, 659.25, 783.99, 1046.5], 0.12, 0.35)
		"lose":
			samples = _arpeggio([392.0, 329.63, 261.63], 0.18, 0.3)
		"sign":
			samples = _concat([_tone(1568.0, 0.08, 0.3, 0.002, 0.07), _tone(2349.0, 0.22, 0.3, 0.002, 0.2)])
		"title":
			samples = _concat([_arpeggio([523.25, 659.25, 783.99], 0.14, 0.35), _tone(1046.5, 0.6, 0.35, 0.01, 0.5)])
		_:
			return null
	var wav := _to_wav(samples)
	_cache[name] = wav
	return wav


# ---------------------------------------------------------------------------
# Síntese
# ---------------------------------------------------------------------------

func _tone(freq: float, dur: float, vol: float, attack: float, release: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / maxf(0.0001, attack)) * minf(1.0, (dur - t) / maxf(0.0001, release))
		out[i] = sin(TAU * freq * t) * vol * env
	return out


func _whistle(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 2950.0 + sin(TAU * 28.0 * t) * 180.0
		phase += TAU * f / RATE
		var env := minf(1.0, t / 0.02) * minf(1.0, (dur - t) / 0.05)
		var am := 0.75 + 0.25 * sin(TAU * 55.0 * t)
		out[i] = sin(phase) * 0.28 * env * am
	return out


## Torcida: ruído filtrado com envelope; `groan` gera um "uuuh" descendente.
func _crowd(dur: float, vol: float, groan: bool = false) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242 + int(dur * 1000)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var cutoff := 0.18 if not groan else 0.1 * (1.0 - 0.5 * t / dur)
		lp += (x - lp) * cutoff
		lp2 += (lp - lp2) * cutoff
		var env: float
		if groan:
			env = minf(1.0, t / 0.08) * pow(maxf(0.0, 1.0 - t / dur), 1.5)
		else:
			env = minf(1.0, t / 0.25) * minf(1.0, (dur - t) / (dur * 0.45))
		var swell := 0.8 + 0.2 * sin(TAU * 1.7 * t)
		out[i] = lp2 * 2.6 * vol * env * swell
	return out


func _horn(dur: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.05) * minf(1.0, (dur - t) / 0.3)
		var s := sin(TAU * 233.0 * t) * 0.5 + sin(TAU * 466.0 * t) * 0.25 + sin(TAU * 699.0 * t) * 0.12
		out[i] = s * 0.3 * env
	return out


func _arpeggio(freqs: Array, note: float, vol: float) -> PackedFloat32Array:
	var parts: Array = []
	for f in freqs:
		parts.append(_tone(f, note, vol, 0.005, note * 0.7))
	return _concat(parts)


func _silence(dur: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(dur * RATE))
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, b_vol: float) -> PackedFloat32Array:
	var out := a.duplicate()
	for i in mini(a.size(), b.size()):
		out[i] = a[i] + b[i] * b_vol
	return out


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
