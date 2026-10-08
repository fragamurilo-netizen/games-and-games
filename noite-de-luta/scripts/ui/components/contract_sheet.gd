class_name ContractSheet
extends RefCounted
## Folha de proposta de contrato: fatia da bolsa, lutas e luvas, com a chance de aceitar à vista.


static func open(w: GameWorld, f: Fighter, done: Callable) -> void:
	var state := {"cut": 0.2, "fights": 5, "bonus": 0.0}
	var v := UIKit.vbox(UITokens.S3)
	v.custom_minimum_size.x = 540
	var rebuild: Callable
	rebuild = func() -> void:
		UIKit.clear(v)
		var head := UIKit.hbox(UITokens.S2)
		head.add_child(FightKit.portrait(w, f, 72))
		var hv := UIKit.vbox(0)
		hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hv.add_child(UIKit.label(f.display_name(), "Section"))
		hv.add_child(UIKit.label("%s · %s · nível %d" % [Matchmaker.division_short(f.division), FightKit.record_detail(f), f.level()], "Small", true))
		head.add_child(hv)
		v.add_child(head)
		var why := Signing.block_reason(w, f)
		if why != "":
			v.add_child(UIKit.label(why, "Muted", true))
			return
		v.add_child(UIKit.label("Fatia das bolsas para a equipe", "Caps"))
		var cuts: Array = []
		for c: float in Signing.CUTS:
			cuts.append([str(c), "%d%%" % int(round(c * 100.0))])
		v.add_child(UIKit.segment(cuts, str(state["cut"]), func(k: String):
			state["cut"] = float(k)
			rebuild.call()))
		v.add_child(UIKit.label("Duração", "Caps"))
		var fs: Array = []
		for n: int in Signing.FIGHTS:
			fs.append([str(n), "%d lutas" % n])
		v.add_child(UIKit.segment(fs, str(state["fights"]), func(k: String):
			state["fights"] = int(k)
			rebuild.call()))
		v.add_child(UIKit.label("Luvas (bônus de assinatura)", "Caps"))
		var bs: Array = []
		for b: float in Signing.BONUS:
			bs.append([str(b), "Sem luvas" if b <= 0.0 else Fmt.money(b)])
		v.add_child(UIKit.segment(bs, str(state["bonus"]), func(k: String):
			state["bonus"] = float(k)
			rebuild.call()))
		var p := Signing.chance(w, f, float(state["cut"]), int(state["fights"]), float(state["bonus"]))
		var pc := UIColors.GREEN if p >= 0.5 else (UIColors.ORANGE if p >= 0.25 else UIColors.RED)
		v.add_child(UIKit.kv("Chance de aceitar", Signing.chance_label(p), pc))
		v.add_child(UIKit.label("Academia com mais reputação convence mais. Pedir menos da bolsa ou pagar luvas também ajuda.", "Small", true))
		v.add_child(UIKit.button("Enviar proposta", "PrimaryButton", func():
			var r := Signing.offer(w, f, float(state["cut"]), int(state["fights"]), float(state["bonus"]))
			UIManager.close_modal()
			if bool(r["ok"]):
				Sfx.play("sign", -4.0)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			GameManager.save_now()
			UIManager.refresh_chrome()
			done.call()))
	rebuild.call()
	UIManager.show_modal(v, true)
