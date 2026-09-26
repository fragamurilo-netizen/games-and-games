class_name PrestigeCard
extends RefCounted
## Prestígio do treinador: barra de nível e os feitos de uma rodada (ou os últimos da carreira).


## Barra do nível atual: "Nível 7 · Promissor", prestígio dentro do nível e quanto falta.
static func level_row(w: GameWorld) -> Control:
	var lv := ManagerFeats.level(w)
	var v := UIKit.vbox(4)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.label("Nível %d · %s" % [int(lv[0]), ManagerFeats.level_name(int(lv[0]))], "H3"))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.label("%d / %d" % [int(lv[1]), int(lv[2])], "Small"))
	v.add_child(head)
	v.add_child(UIKit.bar(float(lv[1]), float(lv[2]), UIColors.ACCENT, 10))
	return v


## Card da tela de resultados. `rep` = report["feats"]; null se não houve nada.
static func round_card(w: GameWorld, rep: Dictionary) -> Control:
	if rep.is_empty():
		return null
	var feats: Array = rep.get("feats", [])
	var card := UIKit.card("Card", 8)
	var head := UIKit.hbox(8)
	head.add_child(UIKit.section("Prestígio"))
	head.add_child(UIKit.spacer())
	head.add_child(UIKit.pill("+%d" % int(rep.get("xp", 0)), UIColors.ACCENT, 18))
	card.add_child(head)
	if String(rep.get("why", "")) != "":
		card.add_child(UIKit.colored("Jogo de peso (%s): tudo vale %s" % [String(rep["why"]), "%d%% a mais" % int(round((float(rep.get("weight", 1.0)) - 1.0) * 100.0))], UIColors.ORANGE, "Small", true))
	if bool(rep.get("up", false)):
		var up := UIKit.hbox(10)
		up.add_child(UIKit.icon_rect("up", 26, UIColors.GREEN))
		up.add_child(UIKit.colored("Subiu para o nível %d! Diretoria e torcida comemoram com você." % int(rep.get("lv1", 1)), UIColors.GREEN, "H3", true))
		card.add_child(up)
	card.add_child(level_row(w))
	for ft: Dictionary in feats:
		var row := UIKit.hbox(10)
		row.add_child(UIKit.icon_rect("trophy" if String(ft["id"]) in ["final", "marco", "recorde"] else "star", 24, UIColors.ACCENT))
		var col := UIKit.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(UIKit.label(String(ft["name"]), "H3", true))
		col.add_child(UIKit.label(String(ft["text"]), "Small", true))
		if String(ft.get("rew", "")) != "":
			col.add_child(UIKit.colored(String(ft["rew"]), UIColors.GREEN, "Small", true))
		row.add_child(col)
		if int(ft.get("xp", 0)) > 0:
			row.add_child(UIKit.label("+%d" % int(ft["xp"]), "H3"))
		card.add_child(row)
	if feats.is_empty() and int(rep.get("base", 0)) > 0:
		card.add_child(UIKit.label("Resultado: +%d de prestígio." % int(rep["base"]), "Small", true))
	if String(rep.get("streak", "")) != "":
		card.add_child(UIKit.kv("Sequência", String(rep["streak"]), UIColors.ACCENT))
	return UIKit.card_panel(card)


## Card da carreira: nível, melhores sequências, feitos mais comuns e os últimos da lista.
static func career_card(w: GameWorld) -> Control:
	var d := ManagerFeats.data(w)
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Prestígio e feitos"))
	card.add_child(level_row(w))
	var best: Dictionary = d.get("best", {})
	var row := UIKit.hbox(4)
	row.add_child(UIKit.stat(str(int(best.get("u", 0))), "maior invencib."))
	row.add_child(UIKit.stat(str(int(best.get("w", 0))), "vitórias seguidas"))
	row.add_child(UIKit.stat(str(int(best.get("cs", 0))), "sem sofrer gol"))
	card.add_child(row)
	var n: Dictionary = d.get("n", {})
	var shown: Array = []
	for id in ["final", "zebra", "classico", "virada", "lider", "mata", "apagar", "goleada", "freguesia"]:
		if int(n.get(id, 0)) > 0:
			shown.append("%s ×%d" % [String(ManagerFeats.FEATS[id]["name"]), int(n[id])])
	if not shown.is_empty():
		card.add_child(UIKit.label(" · ".join(shown), "Small", true))
	var lg: Array = d.get("log", [])
	for i in range(lg.size() - 1, maxi(-1, lg.size() - 6), -1):
		card.add_child(UIKit.label("%d · %s" % [int(lg[i]["y"]), String(lg[i]["t"])], "Small", true))
	if lg.is_empty():
		card.add_child(UIKit.label("Zebras, viradas, clássicos e sequências viram prestígio aqui.", "Muted", true))
	return UIKit.card_panel(card)
