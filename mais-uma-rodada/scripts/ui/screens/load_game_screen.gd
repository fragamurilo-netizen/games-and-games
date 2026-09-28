extends BaseScreen
## Carregar jogo: os cinco espaços de save com clube, temporada e data; carregar ou apagar.


func _init() -> void:
	show_nav = false
	screen_title = "Carregar jogo"


func refresh() -> void:
	max_content_width = 1500
	screen_subtitle = "%d espaços" % SaveManager.SLOTS
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var slots: Array = []
	var any := false
	for s in range(1, SaveManager.SLOTS + 1):
		var meta := SaveManager.read_meta(s)
		var has := SaveManager.has_save(s)
		if has:
			any = true
			slots.append({"s": s, "meta": meta, "unix": float(meta.get("unix", 0.0))})
	# A mais recente em destaque no topo; as outras e os espaços livres embaixo.
	slots.sort_custom(func(a, b): return a["unix"] > b["unix"])
	c.add_child(UIKit.eyebrow("Suas carreiras"))
	if not any:
		var empty := UIKit.card("CardHighlight", 14)
		empty.add_child(UIKit.icon_rect("save", 56, UIColors.ACCENT))
		empty.add_child(UIKit.label("Nenhuma carreira salva ainda", "H3"))
		empty.add_child(UIKit.button("NOVA CARREIRA", "PrimaryButton", func(): UIManager.replace("new_career"), "plus"))
		c.add_child(UIKit.card_panel(empty))
	var cards: Array = []
	var first := true
	for d: Dictionary in slots:
		cards.append(_slot_card(int(d["s"]), d["meta"], first))
		first = false
	var free: Array = []
	for s in range(1, SaveManager.SLOTS + 1):
		if not SaveManager.has_save(s):
			free.append(s)
	var holder := UIKit.vbox(UITokens.S4)
	c.add_child(holder)
	UIKit.columns(holder, cards, content_width())
	if any and not free.is_empty():
		c.add_child(UIKit.section_header("Espaços livres"))
		var rows: Array = []
		for s: int in free:
			rows.append(UIKit.menu_row("plus", "Espaço %d" % s, "Livre", func(): UIManager.replace("new_career")))
		c.add_child(UIKit.menu_group(rows))


static func _meta_color(v: Variant, fallback: Color) -> Color:
	if v is Color:
		return v
	var t := String(v).strip_edges()
	if t.begins_with("("):
		var n := t.trim_prefix("(").trim_suffix(")").split(",")
		if n.size() >= 3:
			return Color(float(n[0]), float(n[1]), float(n[2]))
	return Color.from_string(t, fallback) if t != "" else fallback


func _slot_card(s: int, meta: Dictionary, featured: bool) -> Control:
	var ok := SaveManager.is_compatible(meta) if not meta.is_empty() else true
	var cd: Variant = meta.get("crest", {})
	var tone := UIColors.ACCENT
	if cd is Dictionary and not cd.is_empty():
		tone = UIColors.tone_of(_meta_color(cd.get("c1", ""), UIColors.ACCENT), _meta_color(cd.get("c2", ""), UIColors.ACCENT))
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = UIColors.SURFACE.lerp(tone, 0.10 if featured else 0.05)
	box.set_corner_radius_all(UITokens.R_LG)
	# A borda na cor do clube, mais grossa à esquerda (a faixa de identidade do save).
	box.border_color = tone
	box.set_border_width_all(2 if featured else 0)
	box.border_width_left = 8 if featured else 6
	box.anti_aliasing = true
	panel.add_theme_stylebox_override(&"panel", box)
	var v := UIKit.vbox(UITokens.S3)
	panel.add_child(UIKit.margin(v, 22, 18, 20, 18))
	var top := UIKit.hbox(16)
	v.add_child(top)
	var crest := CrestView.new()
	var px := 96 if featured else 76
	crest.custom_minimum_size = Vector2(px, px)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if cd is Dictionary and not cd.is_empty():
		crest.crest = cd
	top.add_child(crest)
	var col := UIKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var eb := "Última carreira jogada" if featured else "Espaço %d" % s
	col.add_child(UIKit.eyebrow(eb, tone if featured else UIColors.DIM))
	var club_lbl := UIKit.label(String(meta.get("club", "Carreira salva")).to_upper(), "H2" if featured else "H3")
	club_lbl.clip_text = true
	club_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(club_lbl)
	if not meta.is_empty():
		col.add_child(UIKit.label(String(meta.get("division", "")), "Muted"))
	top.add_child(col)
	var del := UIKit.icon_button("close", func(): _delete(s, meta), "Apagar")
	del.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(del)
	if not ok:
		v.add_child(UIKit.pill("Versão antiga do jogo: não abre mais", UIColors.RED, 17))
		return panel
	if not meta.is_empty():
		var facts := UIKit.hbox(10)
		facts.add_child(UIKit.pill("Temporada %d" % int(meta.get("year", 0)), tone, 17))
		var date := String(meta.get("date", ""))
		if date != "":
			facts.add_child(UIKit.pill(date, UIColors.MUTED, 17))
		v.add_child(facts)
		var foot := UIKit.hbox(12)
		var who := UIKit.vbox(0)
		who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		who.add_child(UIKit.label(tr("Técnico: %s") % String(meta.get("manager", "")), "Small"))
		who.add_child(UIKit.label(tr("Salvo em %s") % _date(String(meta.get("saved_at", ""))), "Caps"))
		foot.add_child(who)
		var play := UIKit.button("CARREGAR" if featured else "Abrir", "PrimaryButton" if featured else "Button", func(): _load(s), "play")
		play.custom_minimum_size.x = 220 if featured else 160
		foot.add_child(play)
		v.add_child(foot)
	return panel


static func _date(iso: String) -> String:
	# "2026-09-24 18:30:12" → "24/09/2026 18:30"
	var parts := iso.split(" ")
	if parts.size() < 2:
		return iso
	var d := parts[0].split("-")
	if d.size() < 3:
		return iso
	return "%s/%s/%s %s" % [d[2], d[1], d[0], parts[1].substr(0, 5)]


func _load(s: int) -> void:
	if GameManager.has_career():
		GameManager.close_career()
	if GameManager.load_career(s):
		AudioManager.play("whistle", -6.0)
		UIManager.goto("hub")
	else:
		UIManager.info("Não foi possível carregar", "O save do espaço %d não pôde ser lido (nem a cópia de segurança)." % s)


func _delete(s: int, meta: Dictionary) -> void:
	var what := String(meta.get("club", "a carreira")) if not meta.is_empty() else "a carreira"
	UIManager.confirm("Apagar o espaço %d?" % s, "Isso apaga %s para sempre, incluindo a cópia de segurança." % what, "Apagar", func():
		if GameManager.slot == s and GameManager.has_career():
			UIManager.toast("Essa carreira está aberta. Saia para o menu antes de apagar.", UIColors.RED)
			return
		SaveManager.delete_slot(s)
		UIManager.toast("Espaço %d apagado." % s)
		refresh())
