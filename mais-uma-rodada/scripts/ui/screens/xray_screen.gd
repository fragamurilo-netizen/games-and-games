extends BaseScreen
## Raio-X tático do último jogo: por que ganhou ou perdeu, com os lances que provam, o mapa dos
## corredores, o antes e depois das mudanças e a correção sugerida (aplicada com um toque).


func _init() -> void:
	show_nav = false
	screen_title = "Raio-X tático"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var rep: Dictionary = w.stats.get("xray", {})
	var c := content()
	UIKit.clear(c)
	if rep.is_empty():
		c.add_child(UIKit.label("Jogue uma partida para ver o Raio-X.", "Muted", true))
		return
	var opp := w.club(int(rep["opp"]))
	var sc: Array = rep["score"]
	screen_subtitle = "%s %d × %d %s" % [w.user_club().short_name, int(sc[0]), int(sc[1]), opp.short_name if opp != null else ""]
	UIManager.refresh_chrome()
	c.add_child(_numbers(w, rep, opp))
	var ins: Array = rep.get("insights", [])
	if ins.is_empty():
		c.add_child(UIKit.label("Jogo equilibrado, sem um padrão claro a corrigir.", "Muted", true))
	for i in ins.size():
		c.add_child(_insight(w, rep, ins[i]))
	c.add_child(_map_card(rep))
	var segs: Array = rep.get("segments", [])
	if segs.size() >= 2:
		c.add_child(_segments_card(segs))


func _numbers(w: GameWorld, rep: Dictionary, opp: Club) -> Control:
	var card := UIKit.card("Card", 8)
	var head := UIKit.hbox(10)
	head.add_child(UIKit.crest(w.user_club(), 44))
	var sc: Array = rep["score"]
	var s := UIKit.label("%d × %d" % [int(sc[0]), int(sc[1])], "Title")
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(s)
	if opp != null:
		head.add_child(UIKit.crest(opp, 44))
	card.add_child(head)
	var fo: Dictionary = rep["for"]
	var ag: Dictionary = rep["against"]
	for row in [["Finalizações", str(fo["shots"]), str(ag["shots"])], ["xG", TacticalXRay.dec(float(fo["xg"])), TacticalXRay.dec(float(ag["xg"]))],
			["Posse", "%d%%" % int(fo["poss"]), "%d%%" % int(ag["poss"])], ["Entradas na área", str(fo["box"]), str(ag["box"])],
			["No último terço", str(fo["ft"]), str(ag["ft"])]]:
		var r := UIKit.hbox(8)
		var a := UIKit.label(String(row[1]), "H3")
		a.custom_minimum_size.x = 90
		r.add_child(a)
		var n := UIKit.label(String(row[0]), "Small")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.add_child(n)
		var b := UIKit.label(String(row[2]), "H3")
		b.custom_minimum_size.x = 90
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(b)
		card.add_child(r)
	return UIKit.card_panel(card)


func _insight(w: GameWorld, rep: Dictionary, ins: Dictionary) -> Control:
	var card := UIKit.card("CardHighlight" if String(ins["k"]) == "against" else "Card", 8)
	card.add_child(UIKit.section(String(ins["title"])))
	for line in ins["lines"]:
		card.add_child(UIKit.label(String(line), "", true))
	var row := UIKit.hbox(8)
	var clips: Array = ins.get("clips", [])
	if not clips.is_empty():
		var b := UIKit.button("Ver lance", "GhostButton", func(): _show_clips(rep, clips), "play")
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var m := UIKit.button("Ver mapa", "GhostButton", func(): _show_map(rep), "tactics")
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(m)
	card.add_child(row)
	var fix: Dictionary = ins.get("fix", {})
	if not fix.is_empty():
		card.add_child(UIKit.button("Corrigir: %s" % String(fix["label"]), "PrimaryButton", func():
			var msg := TacticalXRay.apply_fix(w, fix)
			GameManager.save_now()
			UIManager.toast(msg if msg != "" else "Ajuste aplicado.")
			UIManager.push("prematch", {"edit": true}), "check"))
	return UIKit.card_panel(card)


func _show_clips(rep: Dictionary, clips: Array) -> void:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Os lances", "Title"))
	var chances: Array = rep["chances"]
	for i in clips:
		if int(i) >= chances.size():
			continue
		var ch: Dictionary = chances[int(i)]
		v.add_child(UIKit.label(_clip_text(rep, ch), "Small", true))
		v.add_child(XRayPitch.clip(rep, ch))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _clip_text(rep: Dictionary, ch: Dictionary) -> String:
	var names: Dictionary = rep["names"]
	var lane := int(ch.get("ul", -1))
	var where: String = (" pelo " + String(TacticalXRay.LANE_NAMES[lane])) if lane >= 0 else ""
	var who := String(names.get(int(ch["sh"]), "?"))
	var by := (", passe de %s" % names.get(int(ch["as"]), "?")) if int(ch.get("as", -1)) >= 0 else ""
	var ct: String = TacticalXRay.CT_NAMES[clampi(int(ch["ct"]), 0, TacticalXRay.CT_NAMES.size() - 1)]
	return "%d' — %s%s: %s finalizou%s. %s." % [int(ch["m"]), ct.capitalize(), where, who, by, String(ch["r"]).capitalize()]


func _show_map(rep: Dictionary) -> void:
	var v := UIKit.vbox(10)
	v.add_child(UIKit.label("Mapa dos ataques", "Title"))
	v.add_child(_legend())
	v.add_child(XRayPitch.map(rep, 620))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v, true)


func _legend() -> Control:
	var row := UIKit.hbox(12)
	row.add_child(UIKit.colored("▲ seus ataques", XRayPitch.MINE, "Small"))
	row.add_child(UIKit.colored("▼ ataques do adversário", XRayPitch.THEIRS, "Small"))
	return row


func _map_card(rep: Dictionary) -> Control:
	var card := UIKit.card("Card", 8)
	card.add_child(UIKit.section("Por onde o jogo passou"))
	card.add_child(_legend())
	card.add_child(XRayPitch.map(rep))
	return UIKit.card_panel(card)


func _segments_card(segs: Array) -> Control:
	var card := UIKit.card("Card", 6)
	card.add_child(UIKit.section("Trechos do jogo"))
	for s in segs:
		card.add_child(UIKit.label("%d'–%d' · %s" % [int(s["from"]), int(s["to"]), String(s["label"])], "H3", true))
		card.add_child(UIKit.label("%d finalizações · %s xG · %d%% de posse · %d entradas na área · sofreu %d finalizações (%s xG)" % [
			int(s["sh"]), TacticalXRay.dec(float(s["xg"])), int(s["poss"]), int(s["box"]), int(s["sh_a"]), TacticalXRay.dec(float(s["xg_a"]))], "Small", true))
	return UIKit.card_panel(card)
