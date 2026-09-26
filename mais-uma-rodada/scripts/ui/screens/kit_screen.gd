extends BaseScreen
## Uniformes e patrocínios do clube do usuário. Na pré-temporada (até o primeiro jogo) dá para
## redesenhar titular, reserva, terceiro e goleiro peça por peça — modelos prontos, estampa, gola,
## mangas, vivos, calção e meiões — e fechar os patrocínios (master no peito, manga, costas e
## calção). Fora dela, só mostra o que vale.

const PALETTE: Array[String] = [
	"#FFFFFF", "#F4F1E8", "#E8DCC4", "#D9D9D9", "#8D99AE", "#5C6770", "#3A3F47", "#2B2F36", "#111111",
	"#FFF3B0", "#FFD100", "#F2C14E", "#D4AF37", "#F2A900", "#F58220", "#E4572E", "#FF5E78", "#C8102E",
	"#9B111E", "#8B0000", "#6D1A36", "#7A1F3D", "#E91E63", "#F48FB1", "#B8A1E3", "#8E44AD", "#5B2C83",
	"#1A1A2E", "#0B1F4B", "#1B3A8C", "#0033A0", "#5B6CFF", "#003A70", "#4EA8DE", "#6CACE4", "#9AD1F5",
	"#00838F", "#0E7C86", "#2BB3A3", "#004D40", "#1F4E3D", "#0B6E4F", "#009C3B", "#2E7D32", "#00A86B",
	"#8BC34A", "#C7F464", "#B5A642", "#7B3F00", "#A0522D", "#3E2723",
]

## Modelos prontos: [nome, estilo, papéis de cor]. Papéis: p (cor principal do clube), s (secundária),
## w (branco), k (preto), g (dourado), n (marinho).
const TEMPLATES: Array = [
	["Clássico", {"pattern": "plain", "collar": "round", "sleeve": "cuff", "shorts_style": "plain", "socks_style": "top_band"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "s", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Listrado tradicional", {"pattern": "stripes_v", "collar": "polo", "sleeve": "same", "shorts_style": "plain", "socks_style": "top_stripes"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "k", "shorts2": "s", "socks": "k", "socks2": "s"}],
	["Anos 70", {"pattern": "plain", "collar": "retro", "sleeve": "same", "shorts_style": "hem", "socks_style": "top_stripes"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "w", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Anos 80", {"pattern": "pinstripes", "collar": "polo", "sleeve": "raglan", "trim": "none", "shorts_style": "side_stripe", "socks_style": "hoops_thin"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "s", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Anos 90", {"pattern": "triangles", "tonal": true, "collar": "crossover", "sleeve": "pattern", "shorts_style": "side_panel", "socks_style": "chevron"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Faixa no peito", {"pattern": "faixa", "collar": "round", "sleeve": "cuff", "shorts_style": "plain", "socks_style": "top_band"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "w", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Diagonal", {"pattern": "diagonal", "collar": "v", "sleeve": "same", "shorts_style": "piping", "socks_style": "plain"},
		{"c1": "w", "c2": "p", "c3": "p", "shorts": "k", "shorts2": "p", "socks": "w", "socks2": "p"}],
	["Aros", {"pattern": "stripes_h", "collar": "ringer", "sleeve": "same", "shorts_style": "hem", "socks_style": "hoops"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "w", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Metades", {"pattern": "halves", "collar": "mandarin", "sleeve": "same", "shorts_style": "two_tone", "socks_style": "two_tone"},
		{"c1": "p", "c2": "s", "c3": "k", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Xadrez", {"pattern": "checkers", "collar": "round", "sleeve": "contrast", "shorts_style": "plain", "socks_style": "top_band"},
		{"c1": "p", "c2": "w", "c3": "s", "shorts": "w", "shorts2": "p", "socks": "s", "socks2": "w"}],
	["Chevron", {"pattern": "chevron", "collar": "v", "sleeve": "tipped", "shorts_style": "side_stripe", "socks_style": "chevron"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Minimalista", {"pattern": "plain", "collar": "crossover", "sleeve": "cuff_double", "trim": "none", "shorts_style": "plain", "socks_style": "plain"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Todo preto", {"pattern": "topo", "tonal": true, "collar": "v", "sleeve": "shoulder_stripe", "shorts_style": "piping", "socks_style": "top_stripes"},
		{"c1": "k", "c2": "p", "c3": "p", "shorts": "k", "shorts2": "p", "socks": "k", "socks2": "p"}],
	["Branco e detalhes", {"pattern": "shoulder_band", "collar": "round", "sleeve": "same", "shorts_style": "hem", "socks_style": "top_stripes"},
		{"c1": "w", "c2": "p", "c3": "p", "shorts": "w", "shorts2": "p", "socks": "w", "socks2": "p"}],
	["Degradê", {"pattern": "gradient", "collar": "zip", "sleeve": "same", "trim": "sides", "shorts_style": "side_panel", "socks_style": "foot"},
		{"c1": "p", "c2": "s", "c3": "w", "shorts": "s", "shorts2": "p", "socks": "s", "socks2": "p"}],
	["Pontilhado", {"pattern": "halftone", "collar": "v", "sleeve": "cuff", "shorts_style": "plain", "socks_style": "band_mid"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Ombros", {"pattern": "yoke", "collar": "polo", "sleeve": "same", "shorts_style": "side_stripe", "socks_style": "top_band"},
		{"c1": "p", "c2": "s", "c3": "p", "shorts": "s", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Painel central", {"pattern": "center_panel", "collar": "round", "sleeve": "contrast", "trim": "shoulders", "shorts_style": "plain", "socks_style": "stripes3"},
		{"c1": "s", "c2": "p", "c3": "p", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Arlequim", {"pattern": "harlequin", "collar": "mandarin", "sleeve": "cuff", "shorts_style": "plain", "socks_style": "hoops"},
		{"c1": "p", "c2": "s", "c3": "k", "shorts": "k", "shorts2": "p", "socks": "p", "socks2": "s"}],
	["Camuflado", {"pattern": "camo", "tonal": true, "collar": "crossover", "sleeve": "same", "trim": "sides", "shorts_style": "vent", "socks_style": "plain"},
		{"c1": "p", "c2": "s", "c3": "s", "shorts": "p", "shorts2": "s", "socks": "p", "socks2": "s"}],
	["Tricolor", {"pattern": "tricolor_v", "collar": "round", "sleeve": "same", "shorts_style": "plain", "socks_style": "top_band"},
		{"c1": "p", "c2": "w", "c3": "s", "shorts": "w", "shorts2": "p", "socks": "p", "socks2": "w"}],
	["Cruz", {"pattern": "cross", "collar": "laced", "sleeve": "same", "shorts_style": "plain", "socks_style": "top_band"},
		{"c1": "w", "c2": "p", "c3": "p", "shorts": "k", "shorts2": "w", "socks": "k", "socks2": "w"}],
	["Gala", {"pattern": "plain", "collar": "polo", "sleeve": "cuff", "trim": "both", "shorts_style": "piping", "socks_style": "top_stripes"},
		{"c1": "p", "c2": "s", "c3": "g", "shorts": "p", "shorts2": "g", "socks": "p", "socks2": "g"}],
	["Marinho", {"pattern": "sash_thin", "collar": "v", "sleeve": "cuff", "shorts_style": "hem", "socks_style": "top_band"},
		{"c1": "n", "c2": "p", "c3": "p", "shorts": "n", "shorts2": "p", "socks": "n", "socks2": "p"}],
]
const STYLE_KEYS := ["pattern", "tonal", "collar", "sleeve", "sleeve_len", "trim", "shorts_style", "socks_style"]
const COLOR_KEYS := ["c1", "c2", "c3", "nc", "shorts", "shorts2", "socks", "socks2"]
const KIT_NAMES := {"home": "Titular", "away": "Reserva", "third": "Terceiro", "gk": "Goleiro"}

var _which := "home" # "home" | "away" | "third" | "gk"
var _part := "models" # "models" | "shirt" | "details" | "shorts" | "socks"
var _group := 0 # grupo de estampas
var _back := false # prévia de costas
var _history: Array = [] # [qual, cópia do uniforme] para desfazer


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


## O uniforme em edição (o dicionário guardado no clube).
func _kit() -> Dictionary:
	var club := world().user_club()
	match _which:
		"gk":
			club.gk_kit() # gera na primeira vez
			return club.kit_gk
		"third":
			club.third_kit()
			return club.kit_third
		"away":
			return club.kit_away
	return club.kit_home


## Como o uniforme aparece (com patrocinadores e fornecedor).
func _shown(club: Club, which: String) -> Dictionary:
	match which:
		"gk":
			return club.gk_kit()
		"third":
			return club.third_kit()
		"away":
			return club.kit_away
	return club.kit_home


func _changed() -> void:
	refresh()


## Guarda o estado para o "Desfazer" e aplica a mudança.
func _edit(fn: Callable) -> void:
	var k := _kit()
	_history.append([_which, k.duplicate(true)])
	if _history.size() > 40:
		_history.pop_front()
	fn.call(k)
	_changed()


func _undo() -> void:
	if _history.is_empty():
		return
	var last: Array = _history.pop_back()
	_which = String(last[0])
	var k := _kit()
	var snap: Dictionary = last[1]
	k.clear()
	k.merge(snap)
	_changed()


# ---------------------------------------------------------------------------
# Prévia
# ---------------------------------------------------------------------------

func _preview_card(club: Club, pre: bool) -> Control:
	var card := UIKit.card("CardHighlight", 10)
	# Os quatro uniformes: toque para escolher qual editar
	var row := UIKit.hbox(8)
	for key: String in ["home", "away", "third", "gk"]:
		var inner := UIKit.vbox(2)
		var kv := UIKit.kit(_shown(club, key), 96, 0, club.crest)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(kv)
		var l := UIKit.label(String(KIT_NAMES[key]).to_upper(), "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(l)
		var t := UIKit.tap_row(inner, func():
			_which = key
			_changed(), "CardFlat" if key == _which else "RowPanel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
	card.add_child(row)
	# Prévia grande: frente e costas lado a lado
	var big := UIKit.hbox(16)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	for is_back in [false, true]:
		var kv := KitView.new()
		kv.full = true
		kv.kit = _shown(club, _which)
		kv.crest = club.crest
		kv.number = 1 if _which == "gk" else 10
		kv.back = is_back
		kv.back_name = _ten_name() if _which != "gk" else ""
		kv.custom_minimum_size = Vector2(250, 450)
		kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.add_child(kv)
	card.add_child(big)
	var cap := UIKit.label("%s · %s" % [String(KIT_NAMES[_which]), _describe(_kit())], "Small", true)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(cap)
	if pre:
		card.add_child(UIKit.label("Tudo pode mudar até o primeiro jogo da temporada: são mais de %s combinações de estilo, fora as cores." % Fmt.thousands(KitView.style_combinations()), "Small", true))
	else:
		card.add_child(UIKit.label("Os uniformes da temporada já foram apresentados. Eles podem ser redesenhados na próxima pré-temporada.", "Small", true))
	return UIKit.card_panel(card)


## Resumo em palavras: estampa, gola e mangas.
func _describe(k: Dictionary) -> String:
	var parts: Array = [KitView.pattern_name(String(k.get("pattern", "plain")))]
	if bool(k.get("tonal", false)):
		parts[0] = String(parts[0]) + " (tom sobre tom)"
	parts.append("gola " + _opt_name(KitView.COLLARS, String(k.get("collar", "round"))).to_lower())
	if String(k.get("sleeve_len", "short")) == "long":
		parts.append("manga longa")
	return ", ".join(parts)


static func _opt_name(opts: Array, key: String) -> String:
	for o in opts:
		if o[0] == key:
			return String(o[1])
	return key


# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------

func _editor_card(club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Editando: " + String(KIT_NAMES[_which]).to_lower()))
	var g := ButtonGroup.new()
	var prow := UIKit.flow(8)
	for p in [["models", "Modelos"], ["shirt", "Camisa"], ["details", "Detalhes"], ["shorts", "Calção"], ["socks", "Meiões"]]:
		var key: String = p[0]
		var chip := UIKit.chip(String(p[1]), key == _part, g, func():
			_part = key
			_changed())
		UIKit.shrink_button(chip)
		prow.add_child(chip)
	card.add_child(prow)
	var k := _kit()
	match _part:
		"models":
			card.add_child(UIKit.label("Modelos prontos nas cores do clube. Depois de escolher, dá para mexer em cada detalhe.", "Small", true))
			card.add_child(_template_grid(club, k))
		"shirt":
			var gg := ButtonGroup.new()
			var grow := UIKit.flow(6)
			for i in KitView.PATTERN_GROUPS.size():
				var gi := i
				var chip := UIKit.chip(String(KitView.PATTERN_GROUPS[i][0]), i == _group, gg, func():
					_group = gi
					_changed())
				UIKit.shrink_button(chip)
				grow.add_child(chip)
			card.add_child(grow)
			card.add_child(_pattern_grid(k))
			var tonal := CheckButton.new()
			tonal.text = "Estampa tom sobre tom (discreta, na cor principal)"
			tonal.button_pressed = bool(k.get("tonal", false))
			tonal.focus_mode = Control.FOCUS_NONE
			tonal.custom_minimum_size.y = 56
			tonal.toggled.connect(func(v: bool):
				AudioManager.click()
				_edit(func(kk: Dictionary): kk["tonal"] = v))
			card.add_child(tonal)
			_colors(card, club, "Cor principal", String(k.get("c1", club.color1)), "c1")
			_colors(card, club, "Cor da estampa", String(k.get("c2", club.color2)), "c2")
			var sw := UIKit.button("Trocar principal e estampa", "GhostButton", func():
				_edit(func(kk: Dictionary):
					var a: Variant = kk.get("c1", club.color1)
					kk["c1"] = kk.get("c2", club.color2)
					kk["c2"] = a), "swap")
			card.add_child(sw)
		"details":
			_options(card, "Gola", KitView.COLLARS, String(k.get("collar", "round")), "collar")
			_options(card, "Mangas", KitView.SLEEVES, String(k.get("sleeve", "same")), "sleeve")
			_options(card, "Comprimento da manga", KitView.SLEEVE_LENGTHS, String(k.get("sleeve_len", "short")), "sleeve_len")
			_options(card, "Vivos", KitView.TRIMS, String(k.get("trim", "none")), "trim")
			_colors(card, club, "Detalhes (gola, punhos, vivos, terceira cor)", String(k.get("c3", k.get("c2", club.color2))), "c3")
			_colors(card, club, "Números e nome", String(k.get("nc", "")), "nc", true)
			card.add_child(UIKit.section("Microdetalhes"))
			card.add_child(UIKit.label("Cor de cada logo sobre o tecido. \"Auto\" usa a cor da marca que mais contrasta.", "Small", true))
			_colors(card, club, "Patrocínio master (peito)", String(k.get("spc", "")), "spc", true)
			_colors(card, club, "Patrocínio da manga", String(k.get("spmc", "")), "spmc", true)
			_colors(card, club, "Patrocínio das costas", String(k.get("spcc", "")), "spcc", true)
			_colors(card, club, "Patrocínio do calção", String(k.get("spsc", "")), "spsc", true)
			_colors(card, club, "Logo da fornecedora", String(k.get("supc", "")), "supc", true)
		"shorts":
			_options(card, "Estilo do calção", KitView.SHORTS_STYLES, String(k.get("shorts_style", "plain")), "shorts_style")
			_colors(card, club, "Cor do calção", String(k.get("shorts", k.get("c2", "#111111"))), "shorts")
			_colors(card, club, "Detalhes do calção", String(k.get("shorts2", k.get("c1", "#FFFFFF"))), "shorts2")
		"socks":
			_options(card, "Estilo dos meiões", KitView.SOCKS_STYLES, String(k.get("socks_style", "plain")), "socks_style")
			_colors(card, club, "Cor dos meiões", String(k.get("socks", k.get("c1", "#FFFFFF"))), "socks")
			_colors(card, club, "Detalhes dos meiões", String(k.get("socks2", k.get("c2", "#000000"))), "socks2")
	var tools := UIKit.hbox(8)
	var undo := UIKit.button("Desfazer", "GhostButton", func(): _undo(), "back")
	undo.disabled = _history.is_empty()
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(undo)
	var rnd := UIKit.button("Surpreenda-me", "", func():
		_edit(func(kk: Dictionary): _randomize(kk, club)), "bolt")
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rnd)
	card.add_child(tools)
	# Copiar o estilo (sem as cores) de outro uniforme do clube
	var copy := UIKit.flow(8)
	copy.add_child(UIKit.label("Copiar estilo do", "Small"))
	for key: String in ["home", "away", "third", "gk"]:
		if key == _which:
			continue
		var src := key
		var b := UIKit.button(String(KIT_NAMES[key]).to_lower(), "GhostButton", func():
			var other := _shown(club, src)
			_edit(func(kk: Dictionary):
				for sk in STYLE_KEYS:
					if other.has(sk):
						kk[sk] = other[sk]
					else:
						kk.erase(sk)))
		UIKit.shrink_button(b)
		copy.add_child(b)
	card.add_child(copy)
	return UIKit.card_panel(card)


static func _role(club: Club, role: String) -> String:
	match role:
		"p":
			return club.color1
		"s":
			return club.color2
		"w":
			return "#FFFFFF"
		"k":
			return "#111111"
		"g":
			return "#D4AF37"
		"n":
			return "#0B1F4B"
	return role


## O modelo pronto aplicado às cores do clube (sem tocar em patrocinadores).
static func template_kit(club: Club, t: Array, base: Dictionary) -> Dictionary:
	var k := base.duplicate()
	for sk in STYLE_KEYS:
		k.erase(sk)
	for ck in COLOR_KEYS:
		k.erase(ck)
	var style: Dictionary = t[1]
	k.merge(style, true)
	var roles: Dictionary = t[2]
	for ck in roles:
		k[ck] = _role(club, String(roles[ck]))
	# Cores iguais apagam a estampa: troca a secundária por branco ou preto.
	if Color(String(k["c1"])).is_equal_approx(Color(String(k["c2"]))):
		k["c2"] = "#FFFFFF" if Color(String(k["c1"])).get_luminance() < 0.5 else "#111111"
	return k


func _template_grid(club: Club, k: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for t: Array in TEMPLATES:
		var tk := template_kit(club, t, k)
		tk.erase("sp")
		var inner := UIKit.vbox(0)
		var kv := UIKit.kit(tk, 96, 0, club.crest)
		kv.full = true
		kv.custom_minimum_size = Vector2(96, 150)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(kv)
		var l := UIKit.label(String(t[0]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 104
		inner.add_child(l)
		var tt := t
		var cell := UIKit.tap_row(inner, func():
			_edit(func(kk: Dictionary):
				var nk := template_kit(club, tt, kk)
				kk.clear()
				kk.merge(nk)), "RowPanel")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	return grid


## Miniaturas de cada estampa do grupo, já com as cores do uniforme em edição.
func _pattern_grid(k: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	var cur := String(k.get("pattern", "plain"))
	for p in KitView.group_patterns(_group):
		var key: String = p[0]
		var mini := k.duplicate()
		mini.erase("sp")
		mini.erase("sup")
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
			_edit(func(kk: Dictionary): kk["pattern"] = key), "CardHighlight" if key == cur else "RowPanel")
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
			_edit(func(kk: Dictionary): kk[field] = val)))
	card.add_child(flow)


func _swatch(hex: String, selected: bool, cb: Callable, label := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hex) if hex != "" else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(4 if selected else 1)
	sb.border_color = UIColors.ACCENT if selected else Color(1, 1, 1, 0.25)
	for st in [&"normal", &"hover", &"pressed", &"focus"]:
		b.add_theme_stylebox_override(st, sb)
	if label != "":
		b.text = label
		b.add_theme_font_size_override(&"font_size", 16)
	b.pressed.connect(cb)
	return b


## Paleta: cores do clube primeiro, depois a paleta geral e uma cor livre. `auto`: primeira opção
## "Auto" (apaga o campo e deixa o jogo escolher).
func _colors(card: VBoxContainer, club: Club, caption: String, current: String, field: String, auto: bool = false) -> void:
	card.add_child(UIKit.label(caption, "Small"))
	var flow := UIKit.flow(6)
	var cur := Color(current).to_html(false) if current != "" else ""
	if auto:
		flow.add_child(_swatch("", current == "", func():
			_edit(func(kk: Dictionary): kk.erase(field)), "Auto"))
	var seen := {}
	var list: Array = [club.color1, club.color2]
	list.append_array(PALETTE)
	if current != "" and not PALETTE.has(current):
		list.insert(2, current)
	for hex in list:
		var h := Color(String(hex)).to_html(false)
		if seen.has(h):
			continue
		seen[h] = true
		var hh := "#" + h.to_upper()
		flow.add_child(_swatch(hh, h == cur, func():
			_edit(func(kk: Dictionary): kk[field] = hh)))
	# Cor livre: roda de cores
	var pick := UIKit.icon_button("palette", func():
		ColorWheel.open(Color(current) if current != "" else Color.WHITE, caption, func(c: Color):
			var hx := "#" + c.to_html(false).to_upper()
			if hx != "#" + cur.to_upper():
				_edit(func(kk: Dictionary): kk[field] = hx)), "Roda de cores")
	pick.custom_minimum_size = Vector2(52, 52)
	flow.add_child(pick)
	card.add_child(flow)


## Desenho novo sorteado: de um modelo pronto ou do mesmo gerador dos clubes, nas cores do clube.
func _randomize(k: Dictionary, club: Club) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nk: Dictionary
	if rng.randf() < 0.3:
		nk = template_kit(club, TEMPLATES[rng.randi_range(0, TEMPLATES.size() - 1)], k)
	else:
		var hint := ""
		if rng.randf() < 0.5:
			hint = String(KitView.PATTERNS[rng.randi_range(0, KitView.PATTERNS.size() - 1)][0])
		match _which:
			"away":
				nk = ClubGenerator.away_kit(rng, club, club.kit_home)
			"third":
				var tmp := club.kit_third
				club.kit_third = {}
				var old_key := club.key
				club.key = "%s:%d" % [old_key, rng.randi()]
				nk = ClubGenerator.make_third_kit(club)
				club.key = old_key
				club.kit_third = tmp
			"gk":
				nk = ClubGenerator.make_gk_kit(club)
				var gk_patterns := ["plain", "gradient", "shatter", "brush", "hoop_fade", "triangles", "side_panels", "chevron", "camo"]
				nk["pattern"] = gk_patterns[rng.randi_range(0, gk_patterns.size() - 1)]
				nk["sleeve_len"] = "long" if rng.randf() < 0.5 else "short"
			_:
				nk = ClubGenerator.home_kit(rng, club, hint)
		if rng.randf() < 0.15:
			nk["sleeve_len"] = "long"
	for sk in STYLE_KEYS:
		k.erase(sk)
	for ck in COLOR_KEYS:
		k.erase(ck)
	for key in nk:
		if not String(key).begins_with("sp") and key != "sup":
			k[key] = nk[key]


# ---------------------------------------------------------------------------
# Patrocínios
# ---------------------------------------------------------------------------

func _sponsors_card(w: GameWorld, club: Club, _pre: bool) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Patrocínios"))
	var mk := SponsorManager.market_label(club)
	card.add_child(UIKit.kv("Receita de patrocínio na temporada", Fmt.money(club.income_sponsor), UIColors.GREEN))
	card.add_child(UIKit.kv("Momento comercial", String(mk[0]), mk[1]))
	card.add_child(UIKit.label("Contratos negociados pela diretoria. Campanhas fortes e títulos valorizam as próximas renovações.", "Small", true))
	for s in SponsorManager.SLOTS:
		var slot: String = s[0]
		card.add_child(UIKit.label(String(s[1]).to_upper(), "Caps"))
		var cur: Dictionary = club.sponsors.get(slot, {})
		if cur.is_empty():
			card.add_child(UIKit.label("Espaço livre: a diretoria negocia na próxima pré-temporada.", "Muted", true))
			continue
		var terms: Array = ["até %d" % int(cur.get("y", w.year))]
		if float(cur.get("tb", 0.0)) > 0.0:
			terms.append("+%d%% por título" % int(round(float(cur["tb"]) * 100)))
		if float(cur.get("qb", 0.0)) > 0.0:
			terms.append("+%d%% com vaga continental" % int(round(float(cur["qb"]) * 100)))
		if float(cur.get("rc", 0.0)) > 0.0:
			terms.append("−%d%% se cair" % int(round(float(cur["rc"]) * 100)))
		card.add_child(_sponsor_row(cur, " · ".join(terms), Callable()))
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
