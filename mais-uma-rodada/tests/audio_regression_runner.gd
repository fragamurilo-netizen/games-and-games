extends Node

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("AUDIO_FAIL: " + message)


func _ready() -> void:
	_run()


func _run() -> void:
	var audio := get_node("/root/AudioManager")
	AudioServer.set_bus_mute(0, true) # exercises mixing without audible test noise
	AppSettings.sound = true
	AppSettings.music = false
	# Cross the end of tiny, full-block and partial-block PCM loops repeatedly.
	for frames in [1, 2, 17, 2048, 4096, 4097, 22050]:
		for stereo in [false, true]:
			var samples := PackedFloat32Array()
			samples.resize(frames * (2 if stereo else 1))
			for i in samples.size():
				samples[i] = sin(i * 0.07) * 0.2
			var wav: AudioStreamWAV = audio._to_wav(samples)
			wav.stereo = stereo
			audio._loop_pcm(wav)
			check(wav.loop_end >= 0 and wav.loop_end < frames, "loop endpoint stays inside PCM allocation")
			var playback := wav.instantiate_playback()
			playback.start(maxf(0.0, wav.get_length() - 0.0001))
			for i in 12:
				var mixed := playback.mix_audio(1.0, 4096)
				check(mixed.size() == 4096 if frames > 1 else mixed.size() <= 4096, "mixer crosses loop boundaries or ends a one-frame sample")
			playback.stop()
	var old := {"style": "terrace", "bpm": 92.0, "pitch": 200.0, "seed": 73123, "loud": 0.7}
	var recent := {"style": "curva", "bpm": 110.0, "pitch": 210.0, "seed": 73456, "loud": 0.8}
	audio.crowd_start(old, old, 0.8, 0.2)
	var jobs: Array = audio._crowd_task.duplicate()
	for i in 12:
		audio.crowd_start(recent, recent, 0.8, 0.2)
		check(audio._crowd_task == jobs, "rapid match switches retain outstanding crowd jobs")
	var until := Time.get_ticks_msec() + 180000
	while (audio._crowd_task[0] >= 0 or audio._crowd_task[1] >= 0) and Time.get_ticks_msec() < until:
		await get_tree().process_frame
	check(audio._crowd_task[0] < 0 and audio._crowd_task[1] < 0, "all crowd workers settle")
	var key := CrowdProfile.key_of(recent)
	check(audio._crowd_cache.has(key), "latest match crowd eventually rendered")
	for player in audio._crowd_p:
		var expected: AudioStreamWAV = audio._crowd_cache.get(key)
		check(player.stream is AudioStreamWAV and expected != null and player.stream.data == expected.data, "old crowd cannot replace the latest match")
		if player.stream is AudioStreamWAV:
			check(player.stream.loop_end < player.stream.data.size() / 2, "generated stadium audio uses bounded PCM loops")
	audio.crowd_stop(true)
	AppSettings.sound = false
	print("AUDIO_REGRESSION_RESULT failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
