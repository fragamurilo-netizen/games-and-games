class_name TrainingSheet
extends RefCounted
## Folha de treino individual: foco de atributos e posição em aprendizado.


static func open(p: Player, on_done: Callable = Callable()) -> void:
	var w := GameManager.world
	var v := UIKit.vbox(12)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.portrait(p, w.club(p.club_id), w.year, 64))
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label("Treino de %s" % p.display_name(), "Title", true))
	col.add_child(UIKit.label("%s · %d anos · %s" % [Pos.name_of(p.position), p.age(w.year), p.playstyle()], "Small", true))
	head.add_child(col)
	v.add_child(head)
	v.add_child(UIKit.section("Foco individual"))
	v.add_child(UIKit.label("Os atributos do foco crescem com prioridade (o ritmo depende da idade e do potencial).", "Small", true))
	var fg := ButtonGroup.new()
	var flow := UIKit.flow(8)
	var cur := String(p.train.get("f", ""))
	for key in TrainingManager.PLAYER_FOCUS_ORDER:
		var k: String = key
		var chip := UIKit.chip(String(TrainingManager.PLAYER_FOCUS[k]["name"]), k == cur, fg, func():
			if k == "":
				p.train.erase("f")
			else:
				p.train["f"] = k)
		flow.add_child(chip)
	v.add_child(flow)
	v.add_child(UIKit.section("Aprender posição"))
	var learning := int(p.train.get("pos", -1))
	if learning >= 0:
		var prog := float(p.train.get("prog", 0.0))
		v.add_child(UIKit.label("Aprendendo %s: %d%%" % [Pos.name_of(learning), int(prog * 100.0)], "", true))
		v.add_child(UIKit.bar(prog, 1.0, UIColors.GREEN, 10))
	else:
		v.add_child(UIKit.label("Treinos específicos ensinam uma posição nova em algumas semanas (jovens aprendem mais rápido; posições do mesmo setor também).", "Small", true))
	var pg := ButtonGroup.new()
	var pflow := UIKit.flow(8)
	pflow.add_child(UIKit.chip("Nenhuma", learning < 0, pg, func():
		p.train.erase("pos")
		p.train.erase("prog")))
	for pos in TrainingManager.learnable_positions(p):
		var ps: int = pos
		pflow.add_child(UIKit.chip(Pos.code(ps), ps == learning, pg, func():
			if int(p.train.get("pos", -1)) != ps:
				p.train["pos"] = ps
				p.train["prog"] = 0.0))
	v.add_child(pflow)
	v.add_child(UIKit.button("Pronto", "PrimaryButton", func():
		UIManager.close_modal()
		if on_done.is_valid():
			on_done.call()))
	UIManager.show_modal(v, true)
