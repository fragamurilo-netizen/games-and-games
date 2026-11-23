extends SceneTree
## Folha de poses da luta animada 2D: cada quadro é um FightStage2D parado num momento de um lance.
## xvfb-run -a -s "-screen 0 1700x2600x24" godot --path . --resolution 1600x2460 --script res://tools/stage_sheet.gd -- --out=/tmp/palco.png [--a=boxe --b=muay_thai] [--div=M77]

const PW := 390
const PH := 300


func _b(type: String, side: int, pos: String, data: Dictionary = {}) -> Dictionary:
	var parts := pos.split(":")
	var b := {"r": 1, "t": 12.3, "type": type, "side": side, "pos": parts[0], "g": parts[1] if parts.size() > 1 else "",
		"top": int(parts[2]) if parts.size() > 2 else -1, "cage": parts.size() > 3 and parts[3] == "cage", "dist": 1}
	b.merge(data, true)
	return b


func _initialize() -> void:
	var out := "/tmp/palco.png"
	var base_a := "boxe"
	var base_b := "muay_thai"
	var div := "M77"
	var three := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--a="):
			base_a = a.substr(4)
		elif a.begins_with("--b="):
			base_b = a.substr(4)
		elif a == "--3d":
			three = true
		elif a.begins_with("--div="):
			div = a.substr(6)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var w := GameWorld.new()
	w.rng.seed = 5
	var fa := FighterGenerator.make(w, div, 70.0, 0, false, "BRA")
	var fb := FighterGenerator.make(w, div, 70.0, 0, false, "USA")
	fa.base = base_a
	fb.base = base_b
	var S := "solto"
	var cases := [
		["guarda", [], 0.6],
		["jab (acerta)", [_b("golpe", 0, S, {"k": "jab", "z": "head", "hit": true, "dmg": 0.4})], 0.19],
		["direto (acerta)", [_b("golpe", 0, S, {"k": "direto", "z": "head", "hit": true, "dmg": 1.0})], 0.2],
		["gancho (esquiva)", [_b("golpe", 0, S, {"k": "gancho", "z": "head", "hit": false})], 0.19],
		["overhand", [_b("golpe", 0, S, {"k": "overhand", "z": "head", "hit": true, "dmg": 1.2})], 0.2],
		["uppercut", [_b("golpe", 0, S, {"k": "uppercut", "z": "head", "hit": true, "dmg": 0.8})], 0.2],
		["chute alto", [_b("golpe", 1, S, {"k": "chute_alto", "z": "head", "hit": true, "dmg": 1.3})], 0.27],
		["chute baixo", [_b("golpe", 1, S, {"k": "chute_baixo", "z": "leg", "hit": true, "dmg": 0.5})], 0.27],
		["chute no corpo", [_b("golpe", 1, S, {"k": "chute_corpo", "z": "body", "hit": true, "dmg": 0.7})], 0.27],
		["frontal (teep)", [_b("golpe", 1, S, {"k": "chute_frontal", "z": "body", "hit": true, "dmg": 0.4})], 0.27],
		["giratório", [_b("golpe", 1, S, {"k": "chute_giratorio", "z": "body", "hit": true, "dmg": 0.9})], 0.34],
		["joelhada voadora", [_b("golpe", 1, S, {"k": "joelhada_voadora", "z": "head", "hit": true, "dmg": 1.4})], 0.27],
		["knockdown", [_b("kd", 0, S, {"k": "gancho"})], 1.0],
		["clinch thai", [_b("clinch", 1, "clinch", {"plum": true})], 1.0],
		["joelhada no clinch", [_b("clinch", 1, "clinch", {"plum": true}), _b("golpe", 1, "clinch", {"k": "joelhada", "z": "body", "hit": true, "dmg": 0.6})], 0.85],
		["grade", [_b("clinch", 0, "clinch::-1:cage")], 2.5],
		["entrada de queda", [_b("queda", 0, "chao:guarda:0", {"td": "duas_pernas", "ok": true})], 0.4],
		["suplex", [_b("queda", 0, "chao:guarda:0", {"td": "suplex", "ok": true})], 0.5],
		["sprawl", [_b("queda", 0, S, {"td": "duas_pernas", "ok": false})], 0.6],
		["guarda + gnp", [_b("queda", 0, "chao:guarda:0", {"td": "single", "ok": true}), _b("gnp", 0, "chao:guarda:0", {"hit": true, "dmg": 0.5})], 1.5],
		["meia-guarda", [_b("passa", 0, "chao:meia:0")], 1.4],
		["cem quilos", [_b("passa", 0, "chao:lateral:0")], 1.4],
		["montada + gnp", [_b("passa", 0, "chao:montada:0"), _b("gnp", 0, "chao:montada:0", {"hit": true, "dmg": 0.6})], 0.9],
		["costas: mata-leão", [_b("passa", 1, "chao:costas:1"), _b("fin", 1, "chao:costas:1", {"sub": "mata_leao", "lock": true})], 1.9],
		["triângulo por baixo", [_b("queda", 1, "chao:guarda:1", {"td": "single", "ok": true}), _b("fin", 0, "chao:guarda:1", {"sub": "triangulo", "lock": false})], 2.2],
		["chave de braço", [_b("passa", 1, "chao:montada:1"), _b("fin", 1, "chao:montada:1", {"sub": "chave_braco", "lock": false})], 1.6],
		["fim: nocaute", [_b("fim", 1, S, {"m": "KO"})], 2.5],
		["intervalo", [_b("fim_round", -1, S, {"n": 1})], 2.0],
		["corte e sangue", [_b("golpe", 0, S, {"k": "cotovelada", "z": "head", "hit": true, "dmg": 1.4, "cut": [0.0, 1.1], "head": [0.3, 2.2]})], 0.5],
		["árbitro separa", [_b("clinch", 0, "clinch"), _b("solta", 0, S)], 0.8],
		["replay do nocaute", [_b("golpe", 0, S, {"k": "gancho", "z": "head", "hit": true, "dmg": 2.0}), _b("fim", 0, S, {"m": "KO"})], 4.4],
		["mão levantada (decisão)", [_b("fim", 1, S, {"m": "DEC"})], 3.0],
	]
	var cols := 4
	var bg := ColorRect.new()
	bg.color = Color("#1A1B20")
	bg.size = Vector2(4000, 4000)
	root.add_child(bg)
	var stages: Array = []
	for i in cases.size():
		var c: Array = cases[i]
		var st := FightStage2D.new()
		st.setup(w, fa, fb)
		var holder: Control = st
		if three:
			var v := FightView3D.new()
			v.setup(st, Color("#C8102E"), "Noite de Luta")
			holder = v
		holder.position = Vector2(4 + (i % cols) * (PW + 4), 4 + (i / cols) * (PH + 4))
		holder.size = Vector2(PW, PH)
		root.add_child(holder)
		var l := Label.new()
		l.text = String(c[0])
		l.position = holder.position + Vector2(6, 4)
		l.add_theme_font_size_override(&"font_size", 13)
		root.add_child(l)
		stages.append(holder)
	await process_frame
	for h: Control in stages:
		h.set_process(false)
		if h is FightView3D:
			(h as FightView3D).brain.set_process(false)
	for i in cases.size():
		var c: Array = cases[i]
		var h: Control = stages[i]
		var st: FightStage2D = (h as FightView3D).brain if h is FightView3D else h
		st._process(0.0)
		st._process(1.0 / 60.0)
		for k in 60:
			st._process(1.0 / 60.0)
		for b: Dictionary in c[1]:
			st.add_beat(b)
		var n := int(float(c[2]) * 60.0)
		for k in n:
			st._process(1.0 / 60.0)
		if h is FightView3D:
			for k in 200:
				h._process(1.0 / 60.0)
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
