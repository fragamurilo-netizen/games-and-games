extends BaseScreen
## Desafio: escolher quem da academia chama o alvo, ver se é possível e a chance de aceitarem.

var _mine := -1


func setup(p: Dictionary) -> void:
	super.setup(p)
	screen_title = "Desafio"
	show_nav = false
	_mine = int(p.get("mine", -1))


func refresh() -> void:
	var w := world()
	var target := w.fighter(int(params["target"]))
	var c := reset()
	var options := w.user_fighters().filter(func(m: Fighter) -> bool: return m.division == target.division)
	if _mine < 0 and options.size() == 1:
		_mine = (options[0] as Fighter).id
	screen_subtitle = "contra " + target.display_name()
	UIManager.refresh_chrome()
	if options.is_empty():
		c.add_child(UIKit.state_block("empty", "Ninguém da academia nessa categoria"))
		return
	if _mine < 0:
		c.add_child(UIKit.section_header("Quem desafia?"))
		for m: Fighter in options:
			c.add_child(FightKit.fighter_row(w, m, func():
				_mine = m.id
				refresh(), String(FightKit.status_text(w, m)[0])))
		return
	var mine := w.fighter(_mine)
	var card := UIKit.card("CardHighlight", UITokens.S2)
	card.add_child(FightKit.faceoff(w, mine, target, 130, false))
	c.add_child(UIKit.card_panel(card))
	var why := Matchmaker.challenge_block_reason(w, mine, target)
	var info := UIKit.card("Card", UITokens.S1)
	if why != "":
		info.add_child(UIKit.colored("Não dá para desafiar", UIColors.RED, "Section"))
		info.add_child(UIKit.label(why, "", true))
	else:
		var p := Matchmaker.challenge_chance(w, mine, target)
		info.add_child(UIKit.label("A equipe de %s responde na hora" % target.short_name(), "Section"))
		info.add_child(UIKit.kv("Chance de aceitar", Signing.chance_label(p), UIColors.GREEN if p >= 0.5 else UIColors.ORANGE))
		if w.rank_of(target) == 0:
			info.add_child(UIKit.colored("Valendo o cinturão, em 5 rounds.", UIColors.GOLD, "H3"))
		info.add_child(UIKit.label("Recusou, só dá para chamar de novo daqui a seis semanas. Perder uma luta trava os desafios para cima por oito.", "Small", true))
	c.add_child(UIKit.card_panel(info))
	var tape := UIKit.card("Card", UITokens.S1)
	tape.add_child(FightKit.tape(w, mine, target))
	c.add_child(UIKit.card_panel(tape))
	if why == "":
		footer().add_child(UIKit.button("Desafiar", "PrimaryButton", func():
			var r := Matchmaker.challenge(w, mine, target)
			UIManager.toast(String(r["text"]), UIColors.GREEN if bool(r["ok"]) else UIColors.RED)
			GameManager.save_now()
			if bool(r["ok"]):
				Sfx.play("sign", -4.0)
				UIManager.goto("hub")
			else:
				refresh()))
