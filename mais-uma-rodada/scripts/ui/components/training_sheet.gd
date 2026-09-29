class_name TrainingSheet
extends RefCounted
## Folha de treino individual: carga, foco de atributos, estilo de jogo a desenvolver, posição em
## aprendizado e o que mudou nas últimas semanas.


## `mode`: abre direto numa lista de opções ("ld", "f", "st", "pos"); vazio = resumo.
static func open(p: Player, on_done: Callable = Callable(), mode: String = "") -> void:
	var w := GameManager.world
	var v := UIKit.vbox(12)
	var body := UIKit.vbox(12)
	v.add_child(body)
	_build(w, p, body, mode)
	v.add_child(UIKit.button("Pronto", "PrimaryButton", func():
		UIManager.close_modal()
		if on_done.is_valid():
			on_done.call()))
	UIManager.show_modal(v, true)


static func _build(w: GameWorld, p: Player, body: VBoxContainer, mode: String = "") -> void:
	UIKit.clear(body)
	if mode != "":
		_options(w, p, body, mode)
		return
	var rebuild := func(m: String): _build(w, p, body, m)
	var club := w.club(p.club_id)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, club, w.year, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UIKit.label(p.display_name(), "Screen")
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(nm)
	col.add_child(UIKit.label("%s, %d anos. %s" % [Pos.name_of(p.position), p.age(w.year), PlayStyle.full(p)], "Muted", true))
	head.add_child(col)
	var tr_v := TrainingManager.trend(p)
	var tb := _trend_badge(tr_v)
	tb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(tb)
	body.add_child(head)
	_recent(p, body)
	var plan := UIKit.vbox(0)
	# Carga
	var ld := clampi(int(p.train.get("ld", 1)), 0, 2)
	var lo: Dictionary = TrainingManager.LOAD[ld]
	var ld_note := "" if ld == 1 else _fx(lo)
	if p.condition < 70.0 and ld == 2:
		ld_note += " Está cansado (%d%%)." % int(p.condition)
	plan.add_child(_row("Carga", String(lo["name"]), ld_note, func(): rebuild.call("ld")))
	# Foco de atributos
	var cur := String(p.train.get("f", ""))
	plan.add_child(_row("Foco", String(TrainingManager.PLAYER_FOCUS.get(cur, {"name": "Sem foco"})["name"]), "", func(): rebuild.call("f")))
	var fattrs: Array = TrainingManager.PLAYER_FOCUS.get(cur, {}).get("attrs", [])
	if not fattrs.is_empty():
		plan.add_child(_attr_bars(p, fattrs))
	# Estilo de jogo
	var target := String(p.train.get("st", ""))
	var st_note := "Hoje: %s." % PlayStyle.of(p)
	plan.add_child(_row("Estilo", String(PlayStyle.find(p, target).get("n", "")) if target != "" else "Nenhum", st_note, func(): rebuild.call("st")))
	if target != "":
		var te := PlayStyle.find(p, target)
		var prog := TrainingManager.style_progress(p)
		var names: Array = []
		for a in PlayStyle.attrs_of(te):
			names.append("%s %d" % [Attr.SHORT[int(a)], p.attrs[int(a)]])
		plan.add_child(UIKit.gap(UITokens.S1))
		plan.add_child(_progress(prog, "%d%%, trabalha %s" % [int(prog * 100.0), ", ".join(PackedStringArray(names))]))
	# Posição nova
	var learning := int(p.train.get("pos", -1))
	plan.add_child(_row("Posição", Pos.name_of(learning) if learning >= 0 else "Nenhuma", "", func(): rebuild.call("pos")))
	if learning >= 0:
		var pprog := float(p.train.get("prog", 0.0))
		var rate := TrainingManager.position_rate(w, club, p, learning)
		var weeks := int(ceil((1.0 - pprog) / maxf(0.001, rate)))
		plan.add_child(UIKit.gap(UITokens.S1))
		plan.add_child(_progress(pprog, "%d%%, cerca de %d semana(s)" % [int(pprog * 100.0), weeks]))
	body.add_child(plan)


## "Evolução +15%, recuperação −10%, risco de lesão +35%."
static func _fx(e: Dictionary) -> String:
	var bits: Array = []
	for it in [["Evolução", e["growth"]], ["recuperação", e["recovery"]], ["risco de lesão", e["injury"]]]:
		var d := _pct(it[1])
		if d != 0:
			bits.append("%s %+d%%" % [it[0], d])
	if bits.is_empty():
		return ""
	var s: String = ", ".join(bits)
	return s.substr(0, 1).to_upper() + s.substr(1) + "."


## Linha do plano: rótulo, valor e seta; toque abre as opções. Nota curta embaixo.
static func _row(title: String, value: String, note: String, cb: Callable) -> Control:
	var v := UIKit.vbox(0)
	var h := UIKit.hbox(UITokens.S2)
	var t := UIKit.label(title, "Muted")
	t.custom_minimum_size.x = 130
	h.add_child(t)
	var vl := UIKit.label(value)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(vl)
	h.add_child(UIKit.icon_rect("forward", 20, UIColors.DIM))
	v.add_child(h)
	if note != "":
		var n := UIKit.label(note, "Small", true)
		v.add_child(n)
	var row := UIKit.tap_row(v, cb)
	row.custom_minimum_size.y = UITokens.H_ROW
	return row


static func _progress(v: float, text: String) -> Control:
	var box := UIKit.vbox(4)
	box.add_child(UIKit.bar(v, 1.0, UIColors.GREEN, 6))
	box.add_child(UIKit.label(text, "Small", true))
	return box


## Lista de opções de um item do plano, dentro da mesma folha, com volta ao resumo.
static func _options(w: GameWorld, p: Player, body: VBoxContainer, mode: String) -> void:
	var back := func(): _build(w, p, body, "")
	var bb := UIKit.button("Voltar", "TextButton", back, "back")
	bb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(bb)
	var items: Array = []  # [rótulo, descrição, atual, aplicar]
	match mode:
		"ld":
			body.add_child(UIKit.label("Carga de treino", "H2"))
			var ld := clampi(int(p.train.get("ld", 1)), 0, 2)
			for i in TrainingManager.LOAD.size():
				var e: Dictionary = TrainingManager.LOAD[i]
				var idx := i
				items.append([String(e["name"]), String(e["desc"]) + (" " + _fx(e) if _fx(e) != "" else ""), i == ld, func():
					if idx == 1:
						p.train.erase("ld")
					else:
						p.train["ld"] = idx])
		"f":
			body.add_child(UIKit.label("Foco individual", "H2"))
			var cur := String(p.train.get("f", ""))
			for key in TrainingManager.PLAYER_FOCUS_ORDER:
				var k: String = key
				var e: Dictionary = TrainingManager.PLAYER_FOCUS[k]
				var names: Array = []
				for a in e["attrs"]:
					names.append("%s %d" % [Attr.NAMES[int(a)], p.attrs[int(a)]])
				items.append([String(e["name"]), ("Trabalha: " + ", ".join(names) + ".") if not names.is_empty() else "Treina com o grupo.", k == cur, func():
					if k == "":
						p.train.erase("f")
					else:
						p.train["f"] = k])
		"st":
			body.add_child(UIKit.label("Estilo de jogo", "H2"))
			body.add_child(UIKit.label("Hoje: %s." % PlayStyle.of(p), "Muted", true))
			var target := String(p.train.get("st", ""))
			items.append(["Nenhum", "Sem estilo a desenvolver.", target == "", func(): TrainingManager.set_style_target(p, "")])
			var main_k := String(PlayStyle.primary(p)["k"])
			for e: Dictionary in PlayStyle.options_for(p):
				var ek := String(e["k"])
				if ek == main_k:
					continue
				var names: Array = []
				for a in PlayStyle.attrs_of(e):
					names.append("%s %d" % [Attr.SHORT[int(a)], p.attrs[int(a)]])
				items.append([String(e["n"]), "Trabalha: " + ", ".join(names) + ".", ek == target, func(): TrainingManager.set_style_target(p, ek)])
		"pos":
			body.add_child(UIKit.label("Aprender posição", "H2"))
			var learning := int(p.train.get("pos", -1))
			items.append(["Nenhuma", "Fica só nas posições que já joga.", learning < 0, func():
				p.train.erase("pos")
				p.train.erase("prog")])
			for pos in TrainingManager.learnable_positions(p):
				var ps: int = pos
				items.append([Pos.name_of(ps), Pos.code(ps), ps == learning, func():
					if int(p.train.get("pos", -1)) != ps:
						p.train["pos"] = ps
						p.train["prog"] = 0.0])
	for it in items:
		var box := UIKit.vbox(0)
		var nm := UIKit.label(String(it[0]))
		if bool(it[2]):
			nm.add_theme_color_override(&"font_color", UIColors.ink(UIColors.ACCENT))
		box.add_child(nm)
		if String(it[1]) != "":
			box.add_child(UIKit.label(String(it[1]), "Muted", true))
		var apply: Callable = it[3]
		var row := UIKit.tap_row(box, func():
			apply.call()
			_build(w, p, body, ""))
		row.custom_minimum_size.y = 72
		body.add_child(row)


## Evolução recente: tendência do overall e as últimas mudanças de atributo.
static func _recent(p: Player, body: VBoxContainer) -> void:
	var ch := TrainingManager.recent_changes(p)
	if ch.is_empty():
		return
	body.add_child(UIKit.section("Mudou nas últimas semanas"))
	body.add_child(change_pills(ch, 8))


## Pílulas "+1 PAS" / "-1 VEL" das mudanças mais recentes.
static func change_pills(changes: Array, max_n: int) -> HFlowContainer:
	# Soma por atributo (duas quedas de ACE viram "-2 ACE"), na ordem da mais recente.
	var sums := {}
	var order: Array = []
	for c in changes:
		var a := int(c[1])
		if not sums.has(a):
			order.append(a)
			sums[a] = 0
		sums[a] = int(sums[a]) + int(c[2])
	var f := UIKit.flow(6)
	var n := 0
	for a in order:
		var d := int(sums[a])
		if d == 0 or n >= max_n:
			continue
		n += 1
		f.add_child(UIKit.pill("%+d %s" % [d, Attr.SHORT[a]], UIColors.GREEN if d > 0 else UIColors.RED, 14))
	return f


## Selo com a variação de overall das últimas semanas ("+1,2").
static func _trend_badge(v: float) -> Control:
	if absf(v) < 0.05:
		return UIKit.label("", "Small")
	var pl := UIKit.pill("Evoluindo" if v > 0.0 else "Em queda", UIColors.GREEN if v > 0.0 else UIColors.RED, 16)
	pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return pl


static func trend_label(v: float) -> Control:
	return _trend_badge(v)


static func _attr_bars(p: Player, attrs: Array) -> Control:
	var box := UIKit.vbox(4)
	for a in attrs:
		var r := UIKit.hbox(8)
		var n := UIKit.label(Attr.NAMES[int(a)], "Small")
		n.custom_minimum_size.x = 150
		r.add_child(n)
		var b := UIKit.bar(float(p.attrs[int(a)]), 99.0, UIColors.ACCENT, 8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(b)
		r.add_child(UIKit.label(str(p.attrs[int(a)]), "H3"))
		box.add_child(r)
	return box


static func _pct(v: Variant) -> int:
	return int(round((float(v) - 1.0) * 100.0))
