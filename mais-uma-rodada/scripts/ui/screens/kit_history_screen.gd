extends BaseScreen
## Histórico de uniformes de um clube: titular, reserva, terceiro e goleiro de cada temporada, com
## o técnico da época. Toque num uniforme para ver frente e costas. Na pré-temporada, o clube do
## usuário pode trazer de volta um uniforme antigo (edição retrô). Com {"id": x} mostra outro clube.

const NAMES := {"h": "Titular", "a": "Reserva", "t": "Terceiro", "g": "Goleiro"}


func _init() -> void:
	show_nav = false
	screen_title = "Uniformes por temporada"


func _club() -> Club:
	var w := world()
	var id := int(params.get("id", w.user_club_id))
	var c := w.club(id)
	return c if c != null else w.user_club()


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := _club()
	screen_subtitle = club.short_name
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	var hist := KitDesign.history(club)
	if hist.is_empty():
		var card := UIKit.card("Card", 8)
		card.add_child(UIKit.label("Ainda não há uniformes no histórico. Eles entram aqui quando estreiam em campo, no primeiro jogo de cada temporada.", "", true))
		c.add_child(UIKit.card_panel(card))
		return
	for h in hist:
		c.add_child(_season_card(w, club, int(h[0]), h[1]))


func _season_card(w: GameWorld, club: Club, year: int, kits: Dictionary) -> Control:
	var card := UIKit.card("CardHighlight" if year == w.year else "Card", 8)
	var head := UIKit.hbox(10)
	var t := UIKit.label(("Temporada %d" % year) + (" (atual)" if year == w.year else ""), "H3")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var coach := String(kits.get("coach", ""))
	if coach != "":
		head.add_child(UIKit.label(coach, "Small"))
	card.add_child(head)
	var row := UIKit.hbox(6)
	for key in ["h", "a", "t", "g"]:
		var kd: Dictionary = kits.get(key, {})
		if kd.is_empty():
			continue
		var vb := UIKit.vbox(0)
		var kv := UIKit.kit(kd, 96, 0, club.crest)
		kv.full = true
		kv.custom_minimum_size = Vector2(110, 186)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		vb.add_child(kv)
		var l := UIKit.label(String(NAMES[key]).to_upper(), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		var k := kd
		var kk: String = key
		var cell := UIKit.tap_row(vb, func(): _detail(club, year, kk, k), "RowPanel")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cell)
	card.add_child(row)
	return UIKit.card_panel(card)


## Frente e costas de um uniforme antigo; na pré-temporada, opção de relançá-lo.
func _detail(club: Club, year: int, key: String, k: Dictionary) -> void:
	var w := world()
	var v := UIKit.vbox(14)
	v.custom_minimum_size.x = 600
	v.add_child(UIKit.label("%s de %d" % [String(NAMES[key]), year], "Title", true))
	var big := UIKit.hbox(16)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	for is_back in [false, true]:
		var kv := KitView.new()
		kv.full = true
		kv.kit = k
		kv.crest = club.crest
		kv.number = 1 if key == "g" else 10
		kv.back = is_back
		kv.custom_minimum_size = Vector2(200, 360)
		kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.add_child(kv)
	v.add_child(big)
	v.add_child(UIKit.label(_describe(k), "Small", true))
	var own := club.id == w.user_club_id
	if own and SponsorManager.is_preseason(w) and year != w.year:
		var target := {"h": "home", "a": "away", "t": "third", "g": "gk"}[key] as String
		v.add_child(UIKit.button("Relançar como %s de %d" % [String(NAMES[key]).to_lower(), w.year], "PrimaryButton", func():
			_relaunch(club, target, k)
			UIManager.close_modal()
			UIManager.toast("Edição retrô: o %s de %d volta a campo" % [String(NAMES[key]).to_lower(), year], UIColors.GREEN)
			refresh(), "swap"))
	v.add_child(UIKit.button("Fechar", "GhostButton", func(): UIManager.close_modal()))
	UIManager.show_modal(v)


static func _describe(k: Dictionary) -> String:
	var s := KitView.pattern_name(String(k.get("pattern", "plain")))
	if bool(k.get("tonal", false)):
		s += " (tom sobre tom)"
	var sp: Dictionary = k.get("sp", {})
	if not sp.is_empty():
		s += " · patrocínio " + String(sp.get("n", ""))
	return s


## Copia desenho e cores do uniforme antigo, mantendo os patrocinadores atuais.
static func _relaunch(club: Club, target: String, old: Dictionary) -> void:
	var k: Dictionary
	match target:
		"away":
			k = club.kit_away
		"third":
			club.third_kit()
			k = club.kit_third
		"gk":
			club.gk_kit()
			k = club.kit_gk
		_:
			k = club.kit_home
	var keep := {}
	for key in k:
		if String(key).begins_with("sp") or key == "sup":
			keep[key] = k[key]
	k.clear()
	for key in old:
		if not String(key).begins_with("sp") and key != "sup":
			k[key] = old[key]
	if target in ["home", "away"]:
		k.merge(keep, true)
