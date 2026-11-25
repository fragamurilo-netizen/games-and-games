extends SceneTree
## Tira de quadros da luta 2D em movimento: um FightStage2D do tamanho que ele tem no celular toca
## uma sequência de lances e a ferramenta fotografa um quadro a cada tantos, lado a lado. Serve
## para conferir câmera, passos, impacto e apresentação, que não aparecem numa pose parada.
## xvfb-run -a -s "-screen 0 700x520x24" godot --path . --resolution 600x420 --script res://tools/fight_strip.gd -- --out=/tmp/tira.png --case=troca [--every=5] [--from=0] [--max=48] [--at=30,90,150] [--cols=6] [--scale=0.5] [--fem] [--div=M77]
## Casos: intro, troca, clinch, chao, intervalo, ko.

var SW := 568
var SH := 384


func _b(type: String, side: int, pos: String, data: Dictionary = {}) -> Dictionary:
	var parts := pos.split(":")
	var b := {"r": 1, "t": 12.3, "type": type, "side": side, "pos": parts[0], "g": parts[1] if parts.size() > 1 else "",
		"top": int(parts[2]) if parts.size() > 2 else -1, "cage": parts.size() > 3 and parts[3] == "cage", "dist": 1}
	b.merge(data, true)
	return b


func _cases() -> Dictionary:
	var S := "solto"
	return {
		"parado": [{"wait": 30.0}],
		"intro": [_b("round", -1, S, {"n": 1}), _b("estudo", 0, S, {"t": 1.0}), _b("golpe", 0, S, {"k": "jab", "z": "head", "hit": true, "dmg": 0.4})],
		"troca": [
			_b("estudo", 0, S, {"t": 2.0, "dist": 0}),
			_b("golpe", 0, S, {"k": "jab", "z": "head", "hit": true, "dmg": 0.4, "dist": 1}),
			_b("golpe", 0, S, {"k": "direto", "z": "head", "hit": true, "dmg": 1.0, "dist": 1}),
			_b("golpe", 1, S, {"k": "chute_baixo", "z": "leg", "hit": true, "dmg": 0.7, "dist": 1}),
			_b("golpe", 0, S, {"k": "gancho", "z": "head", "hit": false, "t": 3.0, "dist": 2}),
			_b("golpe", 1, S, {"k": "chute_corpo", "z": "body", "hit": true, "dmg": 0.9, "dist": 1}),
			_b("golpe", 1, S, {"k": "chute_baixo", "z": "leg", "hit": true, "dmg": 0.8, "dist": 1}),
			_b("golpe", 0, S, {"k": "overhand", "z": "head", "hit": true, "dmg": 1.6, "dist": 2, "cut": [0.0, 0.6], "head": [0.2, 1.4]}),
			_b("balanca", 0, S, {"dist": 2}),
			_b("golpe", 1, S, {"k": "chute_alto", "z": "head", "hit": true, "dmg": 1.3, "dist": 1}),
			_b("estudo", 1, S, {"t": 4.0, "dist": 0}),
		],
		"clinch": [
			_b("clinch", 1, "clinch", {"plum": true}),
			_b("golpe", 1, "clinch", {"k": "joelhada", "z": "body", "hit": true, "dmg": 0.9}),
			_b("golpe", 0, "clinch", {"k": "cotovelada", "z": "head", "hit": true, "dmg": 0.8}),
			_b("clinch", 0, "clinch::-1:cage"),
			_b("golpe", 0, "clinch::-1:cage", {"k": "joelhada", "z": "body", "hit": true, "dmg": 0.6}),
			_b("solta", 0, S),
		],
		"chao": [
			_b("queda", 0, "chao:guarda:0", {"td": "duas_pernas", "ok": true}),
			_b("gnp", 0, "chao:guarda:0", {"hit": true, "dmg": 0.6}),
			_b("gnp", 0, "chao:guarda:0", {"hit": true, "dmg": 0.9, "t": 12.4}),
			_b("passa", 0, "chao:meia:0"),
			_b("passa", 0, "chao:montada:0"),
			_b("gnp", 0, "chao:montada:0", {"hit": true, "dmg": 1.0}),
			_b("fin", 0, "chao:montada:0", {"sub": "chave_braco", "lock": true}),
			_b("levanta", 1, S),
			_b("queda", 1, "chao:guarda:1", {"td": "suplex", "ok": true}),
		],
		"intervalo": [
			_b("golpe", 0, S, {"k": "direto", "z": "head", "hit": true, "dmg": 1.5}),
			_b("queda", 1, "chao:guarda:1", {"td": "duas_pernas", "ok": true}),
			_b("levanta", 0, S),
			_b("fim_round", -1, S, {"n": 1}),
			{"wait": 9.5},
			_b("round", -1, S, {"n": 2}),
			_b("golpe", 1, S, {"k": "jab", "z": "head", "hit": true, "dmg": 0.4}),
		],
		"ko": [
			_b("golpe", 0, S, {"k": "jab", "z": "head", "hit": true, "dmg": 0.4}),
			_b("golpe", 1, S, {"k": "direto", "z": "head", "hit": true, "dmg": 1.1, "cut": [0.5, 0.0], "head": [1.2, 0.3]}),
			_b("kd", 1, S, {"k": "direto"}),
			_b("golpe", 0, S, {"k": "gancho", "z": "head", "hit": true, "dmg": 2.0, "dist": 2}),
			_b("fim", 0, S, {"m": "KO"}),
		],
	}


func _initialize() -> void:
	var out := "/tmp/tira.png"
	var which := "troca"
	var every := 5
	var max_n := 48
	var cols := 6
	var scale := 0.5
	var fem := false
	var div := ""
	var tail := 1.2
	var from := 0
	var at: Array = []
	var base_a := "boxe"
	var base_b := "muay_thai"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--case="):
			which = a.substr(7)
		elif a.begins_with("--every="):
			every = int(a.substr(8))
		elif a.begins_with("--max="):
			max_n = int(a.substr(6))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--scale="):
			scale = float(a.substr(8))
		elif a.begins_with("--div="):
			div = a.substr(6)
		elif a.begins_with("--tail="):
			tail = float(a.substr(7))
		elif a.begins_with("--from="):
			from = int(a.substr(7))
		elif a.begins_with("--ba="):
			base_a = a.get_slice("=", 1)
		elif a.begins_with("--bb="):
			base_b = a.get_slice("=", 1)
		elif a.begins_with("--sw="):
			SW = int(a.get_slice("=", 1))
		elif a.begins_with("--sh="):
			SH = int(a.get_slice("=", 1))
		elif a.begins_with("--at="):
			for part in a.substr(5).split(","):
				at.append(int(part))
		elif a == "--fem":
			fem = true
	if div == "":
		div = "F57" if fem else "M77"
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var w := GameWorld.new()
	w.rng.seed = 5
	var fa := FighterGenerator.make(w, div, 70.0, 0, false, "BRA")
	var fb := FighterGenerator.make(w, div, 70.0, 0, false, "USA")
	fa.base = base_a
	fb.base = base_b
	fa.nickname = "Pitbull"
	fa.record = {"w": 14, "l": 2, "d": 0}
	fb.record = {"w": 9, "l": 3, "d": 1}
	var bg := ColorRect.new()
	bg.color = Color("#1A1B20")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var st := FightStage2D.new()
	st.setup(w, fa, fb)
	st.position = Vector2.ZERO
	st.size = Vector2(SW, SH)
	root.add_child(st)
	await process_frame
	st.set_process(false)
	var beats: Array = (_cases().get(which, []) as Array).duplicate()
	var shots: Array = []
	var frame := 0
	var after := 0.0
	if which != "intro":
		for k in 50:
			st._process(1.0 / 60.0)
	if not at.is_empty():
		max_n = at.size()
	while shots.size() < max_n:
		if st.idle() and not beats.is_empty() and (beats[0] as Dictionary).has("wait"):
			beats[0]["wait"] = float(beats[0]["wait"]) - 1.0 / 60.0
			if float(beats[0]["wait"]) <= 0.0:
				beats.pop_front()
		elif st.idle() and not beats.is_empty():
			st.add_beat(beats.pop_front())
		elif st.idle():
			after += 1.0 / 60.0
			if after > tail:
				break
		st._process(1.0 / 60.0)
		if (frame in at) if not at.is_empty() else (frame >= from and frame % every == 0):
			await process_frame
			await process_frame
			shots.append(root.get_texture().get_image().get_region(Rect2i(0, 0, SW, SH)))
		frame += 1
	var cw := int(SW * scale)
	var ch := int(SH * scale)
	var rows := int(ceil(float(shots.size()) / float(cols)))
	var sheet := Image.create(cols * (cw + 4) + 4, rows * (ch + 4) + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#1A1B20"))
	for i in shots.size():
		var im: Image = shots[i]
		im.convert(Image.FORMAT_RGBA8)
		if scale != 1.0:
			im.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(0, 0, cw, ch), Vector2i(4 + (i % cols) * (cw + 4), 4 + (i / cols) * (ch + 4)))
	sheet.save_png(out)
	print("ok ", out, " quadros=", shots.size(), " de ", frame)
	quit()
