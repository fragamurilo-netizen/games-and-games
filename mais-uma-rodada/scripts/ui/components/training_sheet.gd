class_name TrainingSheet
extends RefCounted
## Folha de treino individual: carga, foco de atributos, estilo de jogo a desenvolver, posição em
## aprendizado e o que mudou nas últimas semanas.


static func open(p: Player, on_done: Callable = Callable()) -> void:
	var w := GameManager.world
	var v := UIKit.vbox(12)
	var body := UIKit.vbox(12)
	v.add_child(body)
	_build(w, p, body)
	v.add_child(UIKit.button("Pronto", "PrimaryButton", func():
		UIManager.close_modal()
		if on_done.is_valid():
			on_done.call()))
	UIManager.show_modal(v, true)


static func _build(w: GameWorld, p: Player, body: VBoxContainer) -> void:
	UIKit.clear(body)
	var rebuild := func(): _build(w, p, body)
	var club := w.club(p.club_id)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, club, w.year, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Treino de %s" % p.display_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.name_of(p.position), p.age(w.year), PlayStyle.full(p)], "Small", true))
	head.add_child(col)
	var tr_v := TrainingManager.trend(p)
	head.add_child(_trend_badge(tr_v))
	body.add_child(head)
	_recent(p, body)
	# Carga
	body.add_child(UIKit.section("Carga de treino"))
	var ld := clampi(int(p.train.get("ld", 1)), 0, 2)
	var li: Array = []
	for i in TrainingManager.LOAD.size():
		li.append([str(i), String(TrainingManager.LOAD[i]["name"])])
	body.add_child(UIKit.segment(li, str(ld), func(k: String):
		if int(k) == 1:
			p.train.erase("ld")
		else:
			p.train["ld"] = int(k)
		rebuild.call()))
	var lo: Dictionary = TrainingManager.LOAD[ld]
	if ld != 1:
		body.add_child(UIKit.effect_pills([["Evolução", _pct(lo["growth"]), true], ["Recuperação", _pct(lo["recovery"]), true], ["Risco de lesão", _pct(lo["injury"]), false]]))
	if p.condition < 70.0 and ld == 2:
		body.add_child(UIKit.colored("Cansado · %d%%" % int(p.condition), UIColors.ORANGE, "Small", true))
	# Foco de atributos
	body.add_child(UIKit.section("Foco individual"))
	var fg := ButtonGroup.new()
	var flow := UIKit.flow(8)
	var cur := String(p.train.get("f", ""))
	for key in TrainingManager.PLAYER_FOCUS_ORDER:
		var k: String = key
		flow.add_child(UIKit.chip(String(TrainingManager.PLAYER_FOCUS[k]["name"]), k == cur, fg, func():
			if k == "":
				p.train.erase("f")
			else:
				p.train["f"] = k
			rebuild.call()))
	body.add_child(flow)
	var fattrs: Array = TrainingManager.PLAYER_FOCUS.get(cur, {}).get("attrs", [])
	if not fattrs.is_empty():
		body.add_child(_attr_bars(p, fattrs))
	# Estilo de jogo
	body.add_child(UIKit.section("Estilo de jogo"))
	var target := String(p.train.get("st", ""))
	body.add_child(UIKit.label("Hoje: %s" % PlayStyle.of(p), "Small", true))
	var sg := ButtonGroup.new()
	var sflow := UIKit.flow(8)
	sflow.add_child(UIKit.chip("Nenhum", target == "", sg, func():
		TrainingManager.set_style_target(p, "")
		rebuild.call()))
	var main_k := String(PlayStyle.primary(p)["k"])
	for e: Dictionary in PlayStyle.options_for(p):
		var ek := String(e["k"])
		if ek == main_k:
			continue
		sflow.add_child(UIKit.chip(String(e["n"]), ek == target, sg, func():
			TrainingManager.set_style_target(p, ek)
			rebuild.call()))
	body.add_child(sflow)
	if target != "":
		var te := PlayStyle.find(p, target)
		var prog := TrainingManager.style_progress(p)
		var names: Array = []
		for a in PlayStyle.attrs_of(te):
			names.append("%s %d" % [Attr.SHORT[int(a)], p.attrs[int(a)]])
		var inset := UIKit.card("CardInset", 6)
		inset.add_child(UIKit.label("%s: %d%%" % [String(te["n"]), int(prog * 100.0)], "H3"))
		inset.add_child(UIKit.bar(prog, 1.0, UIColors.GREEN, 10))
		inset.add_child(UIKit.label("Trabalha: " + " · ".join(PackedStringArray(names)), "Small", true))
		body.add_child(UIKit.card_panel(inset))
	# Posição nova
	body.add_child(UIKit.section("Aprender posição"))
	var learning := int(p.train.get("pos", -1))
	if learning >= 0:
		var pprog := float(p.train.get("prog", 0.0))
		var rate := TrainingManager.position_rate(w, club, p, learning)
		var weeks := int(ceil((1.0 - pprog) / maxf(0.001, rate)))
		body.add_child(UIKit.label(("Aprendendo %s: %d%% · cerca de %d semana" if weeks == 1 else "Aprendendo %s: %d%% · cerca de %d semanas") % [Pos.name_of(learning), int(pprog * 100.0), weeks], "", true))
		body.add_child(UIKit.bar(pprog, 1.0, UIColors.GREEN, 10))
	var pg := ButtonGroup.new()
	var pflow := UIKit.flow(8)
	pflow.add_child(UIKit.chip("Nenhuma", learning < 0, pg, func():
		p.train.erase("pos")
		p.train.erase("prog")
		rebuild.call()))
	for pos in TrainingManager.learnable_positions(p):
		var ps: int = pos
		pflow.add_child(UIKit.chip(Pos.code(ps), ps == learning, pg, func():
			if int(p.train.get("pos", -1)) != ps:
				p.train["pos"] = ps
				p.train["prog"] = 0.0
			rebuild.call()))
	body.add_child(pflow)


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
	var pl := UIKit.pill(("%+.1f" % v).replace(".", ","), UIColors.GREEN if v > 0.0 else UIColors.RED, 16)
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
