extends BaseScreen
## "Mais uma temporada?": a primeira temporada é grátis; daqui em diante (e nos mods) vale a
## Carreira Completa, paga uma vez só. Quando a compra é confirmada, a carreira segue de onde parou.


func _init() -> void:
	show_nav = false
	screen_title = "Carreira Completa"


func _ready() -> void:
	Store.changed.connect(_on_store_changed)
	Store.message.connect(_on_message)


func _exit_tree() -> void:
	if Store.changed.is_connected(_on_store_changed):
		Store.changed.disconnect(_on_store_changed)
	if Store.message.is_connected(_on_message):
		Store.message.disconnect(_on_message)


func refresh() -> void:
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var w := world()
	var hero := UIKit.card("CardHighlight", 12)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(150, 150)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hero.add_child(icon)
	var mods := String(params.get("reason", "")) == "mods"
	var t := UIKit.label("MODS NA CARREIRA COMPLETA" if mods else "MAIS UMA TEMPORADA?", "Big", true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(t)
	var lead := ""
	if mods:
		lead = "Instalar e ligar mods faz parte da Carreira Completa."
	elif w != null and w.user_club() != null:
		lead = "Sua primeira temporada no %s acabou. A carreira está salva e continua exatamente de onde parou." % w.user_club().short_name
	else:
		lead = "A temporada de demonstração acabou. A carreira está salva e continua de onde parou."
	var l := UIKit.label(lead, "Muted", true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_child(l)
	c.add_child(UIKit.card_panel(hero))

	var card := UIKit.card("Card", 12)
	card.add_child(UIKit.section("A Carreira Completa libera"))
	for row in [
		["play", "Temporadas sem limite", "Leve o clube por quantos anos quiser: títulos, base, mercado e Hall da Fama."],
		["list", "Mods", "Instale mods e monte o seu próprio mundo do futebol."],
		["star", "Pagamento único", "Paga uma vez e é sua. Sem anúncios, sem assinatura e sem moedas."],
	]:
		var h := UIKit.hbox(14)
		h.add_child(UIKit.icon_rect(row[0], 40, UIColors.ACCENT))
		var v := UIKit.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(UIKit.label(row[1], "H3"))
		v.add_child(UIKit.label(row[2], "Small", true))
		h.add_child(v)
		card.add_child(h)
	c.add_child(UIKit.card_panel(card))
	if Store.pending:
		c.add_child(UIKit.colored("Pagamento pendente. A compra é liberada assim que o Google confirmar.", UIColors.ORANGE, "Small", true))
	_footer()


func _footer() -> void:
	var f := footer()
	UIKit.clear(f)
	var buy := UIKit.button("DESBLOQUEAR · %s" % Store.price(), "PrimaryButton", func(): Store.buy(Store.FULL), "star")
	buy.custom_minimum_size.y = 96
	f.add_child(buy)
	var row := UIKit.hbox(10)
	var rs := UIKit.button("Restaurar compras", "GhostButton", func(): Store.restore())
	rs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rs)
	var out := UIKit.button("Voltar ao menu" if world() != null else "Voltar", "GhostButton", _leave)
	out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(out)
	f.add_child(row)


func _leave() -> void:
	if world() != null and String(params.get("reason", "")) != "mods":
		GameManager.close_career()
		UIManager.goto("menu")
	elif not UIManager.back():
		UIManager.goto("menu")


func _on_message(text: String) -> void:
	UIManager.toast(text)


func _on_store_changed() -> void:
	if not is_inside_tree():
		return
	if Store.unlocked():
		AudioManager.play("title")
		if String(params.get("reason", "")) == "mods":
			if not UIManager.back():
				UIManager.goto("menu")
			return
		UIManager.goto("hub")
		if world() != null and PreseasonManager.is_active(world()):
			UIManager.push("preseason")
		return
	refresh()
