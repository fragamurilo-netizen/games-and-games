extends BaseScreen
## Uniformes e patrocínios do clube do usuário. Na pré-temporada (até o primeiro jogo) dá para
## redesenhar titular e reserva peça por peça — camisa, gola, mangas, calção e meiões — e fechar
## os patrocínios (master no peito, manga, costas e calção). Fora dela, só mostra o que vale.

const PALETTE: Array[String] = [
	"#FFFFFF", "#F4F1E8", "#D9D9D9", "#8D99AE", "#4A4A4A", "#111111",
	"#FFD100", "#F2C14E", "#F2A900", "#F58220", "#E4572E", "#C8102E",
	"#8B0000", "#6D1A36", "#E91E63", "#F48FB1", "#8E44AD", "#5B2C83",
	"#1B3A8C", "#0033A0", "#003A70", "#4EA8DE", "#6CACE4", "#00838F",
	"#004D40", "#0B6E4F", "#009C3B", "#2E7D32", "#00A86B", "#8BC34A",
	"#B5A642", "#C9A227", "#7B3F00", "#3E2723", "#A0522D", "#1A1A2E",
]

var _which := "home" # "home" | "away"
var _part := "shirt" # "shirt" | "shorts" | "socks"
var _back := false # prévia de costas


func _init() -> void:
	show_nav = false
	screen_title = "Uniformes"


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var pre := SponsorManager.is_preseason(w)
	screen_subtitle = "Pré-temporada %d" % w.year if pre else "Temporada %d" % w.year
	UIManager.refresh_chrome()
	var c := content()
	UIKit.clear(c)
	c.add_child(_preview_card(club, pre))
	if pre:
		c.add_child(_editor_card(club))
	c.add_child(_sponsors_card(w, club, pre))
	var f := footer()
	UIKit.clear(f)
	f.add_child(UIKit.button("PRONTO", "PrimaryButton", func():
		GameManager.save_now()
		UIManager.back(), "check"))


## Nome do camisa 10 do elenco, para a prévia de costas.
func _ten_name() -> String:
	for p in world().squad(world().user_club()):
		if p.shirt == 10:
			return p.display_name()
	return ""


func _kit() -> Dictionary:
	var club := world().user_club()
	if _which == "gk":
		club.gk_kit() # gera na primeira vez
		return club.kit_gk
	return club.kit_home if _which == "home" else club.kit_away


func _changed() -> void:
	refresh()


# ---------------------------------------------------------------------------
# Prévia
# ---------------------------------------------------------------------------

func _preview_card(club: Club, pre: bool) -> Control:
	var card := UIKit.card("CardHighlight", 10)
	var vg := ButtonGroup.new()
	var vrow := UIKit.hbox(8)
	for vb in [[false, "Frente"], [true, "Costas"]]:
		var is_back: bool = vb[0]
		var chip := UIKit.chip(String(vb[1]), is_back == _back, vg, func():
			_back = is_back
			_changed())
		UIKit.shrink_button(chip)
		vrow.add_child(chip)
	card.add_child(vrow)
	var row := UIKit.hbox(12)
	for k in [["home", "Titular", club.kit_home], ["away", "Reserva", club.kit_away], ["gk", "Goleiro", club.gk_kit()]]:
		var key: String = k[0]
		var v := UIKit.vbox(4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kv := KitView.new()
		kv.full = true
		kv.kit = k[2]
		kv.number = 1 if key == "gk" else 10
		kv.back = _back
		kv.back_name = _ten_name() if key != "gk" else ""
		kv.custom_minimum_size = Vector2(190, 340)
		kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var inner := UIKit.vbox(4)
		inner.add_child(kv)
		var l := UIKit.label(String(k[1]).to_upper(), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(l)
		if pre:
			var t := UIKit.tap_row(inner, func():
				_which = key
				_changed(), "CardFlat" if key == _which else "RowPanel")
			v.add_child(t)
		else:
			v.add_child(inner)
		row.add_child(v)
	card.add_child(row)
	if pre:
		card.add_child(UIKit.label("Toque num uniforme para editá-lo. Dá para mudar tudo até o primeiro jogo da temporada: são mais de %s combinações de estilo, fora as cores." % Fmt.thousands(KitView.style_combinations()), "Small", true))
	else:
		card.add_child(UIKit.label("O uniforme da temporada já foi apresentado. Ele pode ser redesenhado na próxima pré-temporada.", "Small", true))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------

func _editor_card(club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Editando: " + ("titular" if _which == "home" else "reserva")))
	var g := ButtonGroup.new()
	var prow := UIKit.hbox(8)
	for p in [["shirt", "Camisa"], ["shorts", "Calção"], ["socks", "Meiões"]]:
		var key: String = p[0]
		var chip := UIKit.chip(String(p[1]), key == _part, g, func():
			_part = key
			_changed())
		UIKit.shrink_button(chip)
		prow.add_child(chip)
	card.add_child(prow)
	var k := _kit()
	match _part:
		"shorts":
			_options(card, "Estilo do calção", KitView.SHORTS_STYLES, String(k.get("shorts_style", "plain")), "shorts_style")
			_colors(card, "Cor do calção", String(k.get("shorts", k.get("c2", "#111111"))), "shorts")
			_colors(card, "Detalhes do calção", String(k.get("shorts2", k.get("c1", "#FFFFFF"))), "shorts2")
		"socks":
			_options(card, "Estilo dos meiões", KitView.SOCKS_STYLES, String(k.get("socks_style", "plain")), "socks_style")
			_colors(card, "Cor dos meiões", String(k.get("socks", k.get("c1", "#FFFFFF"))), "socks")
			_colors(card, "Detalhes dos meiões", String(k.get("socks2", k.get("c2", "#000000"))), "socks2")
		_:
			card.add_child(UIKit.label("Estilo da camisa", "Small"))
			card.add_child(_pattern_grid(k))
			_options(card, "Gola", KitView.COLLARS, String(k.get("collar", "round")), "collar")
			_options(card, "Mangas", KitView.SLEEVES, String(k.get("sleeve", "same")), "sleeve")
			_colors(card, "Cor principal", String(k.get("c1", club.color1)), "c1")
			_colors(card, "Cor secundária (estampa)", String(k.get("c2", club.color2)), "c2")
			_colors(card, "Detalhes (gola, punhos, frisos)", String(k.get("c3", k.get("c2", club.color2))), "c3")
	var tools := UIKit.hbox(8)
	var rnd := UIKit.button("Surpreenda-me", "", func():
		_randomize(k, club)
		_changed(), "bolt")
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rnd)
	var other := club.kit_away if _which == "home" else club.kit_home
	var cp := UIKit.button("Copiar estilo do " + ("reserva" if _which == "home" else "titular"), "GhostButton", func():
		for key in ["pattern", "collar", "sleeve", "shorts_style", "socks_style"]:
			if other.has(key):
				k[key] = other[key]
		_changed(), "swap")
	cp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(cp)
	card.add_child(tools)
	return UIKit.card_panel(card)


## Miniaturas de cada estampa, já com as cores do uniforme em edição.
func _pattern_grid(k: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	var cur := String(k.get("pattern", "plain"))
	for p in KitView.PATTERNS:
		var key: String = p[0]
		var mini := k.duplicate()
		mini.erase("sp")
		mini["pattern"] = key
		var inner := UIKit.vbox(0)
		var kv := UIKit.kit(mini, 84)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(kv)
		var l := UIKit.label(String(p[1]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 104
		inner.add_child(l)
		var t := UIKit.tap_row(inner, func():
			k["pattern"] = key
			_changed(), "CardHighlight" if key == cur else "RowPanel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	return grid


func _options(card: VBoxContainer, caption: String, opts: Array, current: String, field: String) -> void:
	card.add_child(UIKit.label(caption, "Small"))
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for o in opts:
		var val: String = o[0]
		flow.add_child(UIKit.chip(String(o[1]), val == current, g, func():
			_kit()[field] = val
			_changed()))
	card.add_child(flow)


func _colors(card: VBoxContainer, caption: String, current: String, field: String) -> void:
	card.add_child(UIKit.label(caption, "Small"))
	var flow := UIKit.flow(6)
	for hex in PALETTE:
		var h: String = hex
		var b := Button.new()
		b.custom_minimum_size = Vector2(52, 52)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(h)
		sb.set_corner_radius_all(26)
		var selected := Color(h).to_html(false) == Color(current).to_html(false)
		sb.set_border_width_all(4 if selected else 1)
		sb.border_color = UIColors.ACCENT if selected else Color(1, 1, 1, 0.25)
		for st in [&"normal", &"hover", &"pressed", &"focus"]:
			b.add_theme_stylebox_override(st, sb)
		b.pressed.connect(func():
			_kit()[field] = h
			_changed())
		flow.add_child(b)
	card.add_child(flow)


func _randomize(k: Dictionary, club: Club) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	k["pattern"] = KitView.PATTERNS[rng.randi_range(0, KitView.PATTERNS.size() - 1)][0]
	k["collar"] = KitView.COLLARS[rng.randi_range(0, KitView.COLLARS.size() - 1)][0]
	k["sleeve"] = KitView.SLEEVES[rng.randi_range(0, KitView.SLEEVES.size() - 1)][0]
	k["shorts_style"] = KitView.SHORTS_STYLES[rng.randi_range(0, KitView.SHORTS_STYLES.size() - 1)][0]
	k["socks_style"] = KitView.SOCKS_STYLES[rng.randi_range(0, KitView.SOCKS_STYLES.size() - 1)][0]
	# Cores: parte da identidade do clube, com um toque de contraste.
	var base := [club.color1, club.color2, "#FFFFFF", "#111111"]
	var main := String(base[rng.randi_range(0, 1)]) if _which == "home" else String(base[rng.randi_range(1, 3)])
	var sec := String(base[rng.randi_range(0, 3)])
	if Color(sec).to_html(false) == Color(main).to_html(false):
		sec = club.color2 if main != club.color2 else club.color1
	k["c1"] = main
	k["c2"] = sec
	k["c3"] = String(base[rng.randi_range(0, 3)])
	k["shorts"] = [main, sec, "#FFFFFF", "#111111"][rng.randi_range(0, 3)]
	k["shorts2"] = sec if k["shorts"] != sec else main
	k["socks"] = [main, sec, k["shorts"]][rng.randi_range(0, 2)]
	k["socks2"] = sec if k["socks"] != sec else main


# ---------------------------------------------------------------------------
# Patrocínios
# ---------------------------------------------------------------------------

func _sponsors_card(w: GameWorld, club: Club, pre: bool) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Patrocínios"))
	card.add_child(UIKit.kv("Receita de patrocínio na temporada", Fmt.money(club.income_sponsor), UIColors.GREEN))
	if pre:
		card.add_child(UIKit.label("Escolha uma proposta para cada espaço. Valor fixo é garantido; por vitória paga menos de base e um bônus a cada vitória; longo prazo trava o valor por 3 temporadas. O que ficar vazio, a diretoria fecha com o valor fixo no primeiro jogo.", "Small", true))
	for s in SponsorManager.SLOTS:
		var slot: String = s[0]
		card.add_child(UIKit.label(String(s[1]).to_upper(), "Caps"))
		var cur: Dictionary = club.sponsors.get(slot, {})
		if not cur.is_empty():
			card.add_child(_sponsor_row(cur, "Contrato até %d" % int(cur.get("y", w.year)), Callable()))
			continue
		var offers := SponsorManager.offers_for(w, slot) if pre else []
		if offers.is_empty():
			card.add_child(UIKit.label("Sem patrocinador neste espaço." if not pre else "Nenhuma proposta.", "Muted"))
			continue
		for i in offers.size():
			var idx := i
			var o: Dictionary = offers[i]
			card.add_child(_sponsor_row(o, String(SponsorManager.KIND_NAMES.get(String(o.get("kind", "")), "")), func():
				UIManager.confirm("Fechar com %s?" % String(o["n"]), "%s por %s/ano%s, por %s." % [SponsorManager.slot_name(slot), Fmt.money(int(o["v"])),
					(" + %s por vitória" % Fmt.money(int(o["b"]))) if int(o.get("b", 0)) > 0 else "", Fmt.plural(int(o.get("yrs", 1)), "temporada", "temporadas")], "Assinar", func():
					var r := SponsorManager.sign(w, slot, idx)
					UIManager.toast(r["msg"], UIColors.GREEN if r["ok"] else UIColors.RED)
					if r["ok"]:
						AudioManager.play("sign")
						GameManager.save_now()
					_changed())))
	return UIKit.card_panel(card)


func _sponsor_row(o: Dictionary, caption: String, cb: Callable) -> Control:
	var row := UIKit.hbox(12)
	var logo := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(String(o.get("c", "#FFFFFF")))
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	logo.add_theme_stylebox_override(&"panel", sb)
	logo.custom_minimum_size = Vector2(190, 48)
	var ln := UIKit.label(String(o.get("n", "")).to_upper(), "Caps")
	ln.add_theme_color_override(&"font_color", Color(String(o.get("t", "#111111"))))
	ln.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ln.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ln.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ln.custom_minimum_size.x = 170
	logo.add_child(ln)
	row.add_child(logo)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := "%s/ano" % Fmt.money(int(o.get("v", 0)))
	if int(o.get("b", 0)) > 0:
		val += " + %s/vitória" % Fmt.money(int(o["b"]))
	col.add_child(UIKit.label(val, "H3", true))
	col.add_child(UIKit.label(caption, "Small"))
	row.add_child(col)
	if cb.is_valid():
		return UIKit.tap_row(row, cb)
	return row
