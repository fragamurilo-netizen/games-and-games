extends SceneTree
## Confere determinismo, índices salvos, traços finitos e compatibilidade da
## identidade (cabelo/pele) quando novas anatomias entram no sorteio.
## --baseline=res://...gd permite comparar com FaceGen antigo sem class_name.


func _initialize() -> void:
	var baseline: Script = null
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="):
			baseline = load(arg.substr(11))
	var checked := 0
	var saved := {"fs": 0, "es": 0, "ns": 0, "mt": 0, "er": 0}
	var catalogs := {"fs": [FaceGen.FACE_SHAPES, "face_shape"], "es": [FaceGen.EYE_SHAPES, "eye_shape"], "ns": [FaceGen.NOSE_TYPES, "nose_type"], "mt": [FaceGen.MOUTH_TYPES, "mouth_type"], "er": [FaceGen.EAR_TYPES, "ear_type"]}
	for eth in 13:
		for age in [17, 28, 45, 65]:
			for i in 12:
				var seed_value := 1000 + i * 7919
				var face := FaceGen.features(seed_value, eth, age)
				if face != FaceGen.features(seed_value, eth, age):
					_fail("sorteio não determinístico")
					return
				for value: Variant in face.values():
					if value is float and not is_finite(value):
						_fail("medida não finita")
						return
				if baseline != null:
					var old: Dictionary = baseline.features(seed_value, eth, age, saved)
					var explicit := FaceGen.features(seed_value, eth, age, saved)
					for key: String in old:
						if explicit.get(key) != old[key]:
							_fail("escolha antiga mudou: " + key)
							return
					old = baseline.features(seed_value, eth, age)
					for key in ["hair_i", "hair_seed", "beard", "beard_seed", "skin", "eye_i", "texture_seed"]:
						if old[key] != face[key]:
							_fail("anatomia alterou outra parte da identidade: " + key)
							return
				checked += 1
	# Um índice gravado precisa continuar sendo escolhido exatamente, inclusive
	# os antigos e os extremos das novas listas, sem remapear no carregamento.
	for key: String in catalogs:
		for index in catalogs[key][0].size():
			var look := saved.duplicate()
			look[key] = index
			var face := FaceGen.features(4921, 7, 30, look)
			if face[catalogs[key][1]] != index:
				_fail("índice não respeitado: %s=%d" % [key, index])
				return
			checked += 1
	print("anatomia: %d casos, com erro: 0" % checked)
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
