extends BaseScreen
## Carregar jogo: os cinco espaços de save com clube, temporada e data; carregar ou apagar.


func _init() -> void:
	show_nav = false
	screen_title = "Carregar jogo"


func refresh() -> void:
	screen_subtitle = "%d espaços" % SaveManager.SLOTS
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var any := false
	for s in range(1, SaveManager.SLOTS + 1):
		var meta := SaveManager.read_meta(s)
		var has := SaveManager.has_save(s)
		if has:
			any = true
		c.add_child(_slot_card(s, meta, has))
	if not any:
		c.add_child(UIKit.label("Nenhuma carreira salva ainda.", "Muted"))
		c.add_child(UIKit.button("NOVA CARREIRA", "PrimaryButton", func(): UIManager.replace("new_career"), "plus"))
	c.add_child(UIKit.label("Salvo a cada rodada, com cópia de segurança.", "Small", true))


func _slot_card(s: int, meta: Dictionary, has: bool) -> Control:
	var row := UIKit.hbox(14)
	var num := UIKit.label(str(s), "Big")
	num.custom_minimum_size.x = 44
	num.add_theme_color_override(&"font_color", UIColors.DIM)
	row.add_child(num)
	if not has:
		var l := UIKit.label("Espaço vazio", "Muted")
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var card := UIKit.card("CardFlat", 0)
		card.add_child(row)
		return UIKit.card_panel(card)
	var crest := CrestView.new()
	crest.custom_minimum_size = Vector2(64, 64)
	crest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cd: Variant = meta.get("crest", {})
	if cd is Dictionary and not cd.is_empty():
		crest.crest = cd
	row.add_child(crest)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIKit.label(String(meta.get("club", "Carreira")) if not meta.is_empty() else "Carreira salva", "H3", true))
	if not meta.is_empty():
		col.add_child(UIKit.label("%s · %d · %s" % [meta.get("division", ""), int(meta.get("year", 0)), meta.get("date", "")] if SaveManager.is_compatible(meta) else "Versão antiga do jogo (mundo de Valdora): não abre mais", "Small", true))
		col.add_child(UIKit.label("%s · salvo em %s" % [meta.get("manager", ""), _date(String(meta.get("saved_at", "")))], "Small"))
	row.add_child(col)
	var del := UIKit.icon_button("close", func(): _delete(s, meta))
	del.tooltip_text = "Apagar"
	var holder := UIKit.hbox(8)
	holder.add_child(UIKit.tap_row(row, func(): _load(s), "Card"))
	holder.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(del)
	return holder


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
