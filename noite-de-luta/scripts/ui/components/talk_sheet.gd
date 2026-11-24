class_name TalkSheet
extends RefCounted
## Folha de conversa com o lutador: quem ele é (os dois traços), como está e o que dá para dizer.
## A resposta vem pelo jeito dele (ver Morale.talk) e aparece numa caixa depois da escolha.


static func open(w: GameWorld, f: Fighter, done: Callable) -> void:
	var v := UIKit.vbox(UITokens.S2)
	v.custom_minimum_size.x = 540
	var head := UIKit.hbox(UITokens.S2)
	head.add_child(FightKit.portrait(w, f, 96))
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hv.add_child(UIKit.label("Conversa com %s" % f.short_name(), "Section", true))
	hv.add_child(UIKit.label(Persona.label(f), "Small", true))
	hv.add_child(UIKit.label("Moral: %s" % Morale.label(f).to_lower(), "Caps"))
	head.add_child(hv)
	v.add_child(head)
	v.add_child(UIKit.label("Cada um reage do seu jeito: leia a personalidade antes de falar. Depois da conversa, a próxima só em %d semanas." % Morale.TALK_GAP, "Small", true))
	for o: Dictionary in Morale.talk_options(w, f):
		var key := String(o["key"])
		var h := UIKit.hbox(UITokens.S2)
		var ic := UIKit.icon_rect({"elogiar": "star", "cobrar": "bolt", "prometer": "glove", "folga": "clock"}.get(key, "chat"), 26, UIColors.MUTED)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var tv := UIKit.vbox(2)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_child(UIKit.label(String(o["title"]), "H3"))
		tv.add_child(UIKit.label(String(o["desc"]), "Small", true))
		h.add_child(tv)
		v.add_child(UIKit.tap_row(h, func():
			var r := Morale.talk(w, f, key)
			UIManager.close_modal()
			GameManager.save_now()
			done.call()
			var d := int(r["delta"])
			var tail := "A moral não mudou." if d == 0 else ("A moral %s (%s)." % ["subiu" if d > 0 else "caiu", Fmt.signed(d)])
			UIManager.info(String(o["title"]), "%s %s" % [String(r["text"]), tail]), "CardFlat"))
	UIManager.show_modal(v, true)
