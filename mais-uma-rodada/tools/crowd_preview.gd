extends SceneTree
## Gera amostras das torcidas em WAV (para ouvir e calibrar) e mede o tempo de síntese.
## Uso: godot --headless --path . --script res://tools/crowd_preview.gd -- --out=/pasta


func _initialize() -> void:
	var out := "user://crowd"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var w := WorldGenerator.generate(WorldGenerator.DEFAULT_SEED, "padrao")
	for key in ["ARG_XEN", "GER_DOR", "BRA_RNC", "TUR_IAS", "ENG_MSR", "ITA_NAP", "JPN", "MEX"]:
		var c: Club = null
		for cl: Club in w.clubs:
			if cl.key == key or (key.length() == 3 and cl.nation == key):
				c = cl
				break
		if c == null:
			continue
		var prof := CrowdProfile.for_club(c)
		var t := Time.get_ticks_msec()
		var samples := CrowdSynth.render(prof)
		var pcm := CrowdSynth.to_pcm16(samples)
		var ms := Time.get_ticks_msec() - t
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = CrowdSynth.RATE
		wav.data = pcm
		# Duas voltas do loop para ouvir a emenda
		var two := pcm.duplicate()
		two.append_array(pcm)
		wav.data = two
		var name := "%s_%s.wav" % [c.short_name.replace(" ", "_").replace("ç", "c").replace("ş", "s"), prof["style"]]
		wav.save_to_wav(out.path_join(name))
		print("%-28s %-9s %3d bpm  %5.1f s  %d ms" % [c.short_name, prof["style"], int(prof["bpm"]), samples.size() / float(CrowdSynth.RATE), ms])
	quit()
