extends BaseScreen
## Uniformes e patrocínios do clube do usuário. A prévia fica fixa no topo enquanto se edita.
## Na pré-temporada (até o primeiro jogo) dá para escolher uma das coleções da fornecedora ou
## redesenhar titular, reserva, terceiro e goleiro peça por peça — modelos, estampa, cores,
## gola e mangas, calção e meiões. Reserva e terceiro nunca ficam da cor do titular: as cores que
## causariam isso aparecem bloqueadas, e o jogo avisa (e ajusta) antes de apresentar os uniformes.
## Fora da pré-temporada, só mostra o que vale. Mostra também o histórico das temporadas.

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
const KIT_ORDER := ["home", "away", "third", "gk"]
## Abas do editor: [chave, nome].
const PARTS: Array = [["collections", "Coleções"], ["models", "Modelos"], ["shirt", "Estampa"], ["colors", "Cores"],
	["details", "Gola e mangas"], ["shorts", "Calção"], ["socks", "Meiões"]]
## Cores editáveis na aba Cores: [campo, nome].
const SLOTS: Array = [["c1", "Principal"], ["c2", "Estampa"], ["c3", "Detalhes"], ["nc", "Números"],
	["shorts", "Calção"], ["shorts2", "Friso do calção"], ["socks", "Meiões"], ["socks2", "Friso dos meiões"]]
## Cores de acesso rápido (além das do clube).
const QUICK := ["#FFFFFF", "#F4F1E8", "#111111", "#0B1F4B", "#D4AF37", "#8D99AE"]

var _which := "home" # "home" | "away" | "third" | "gk"
var _part := "models"
var _group := 0 # grupo de estampas
var _slot := "c1" # cor em edição na aba Cores
var _more_colors := false # paleta completa aberta
var _proposal_round := 0 # "Pedir outras propostas"
var _launch := false # aberto pelo convite de lançamento da temporada
var _history: Array = [] # [{qual: cópia do uniforme}, qual estava aberto] para desfazer
var _stage: PanelContainer


func _init() -> void:
	show_nav = false
	screen_title = "Uniformes"


func setup(p: Dictionary) -> void:
	super.setup(p)
	_launch = bool(p.get("launch", false))
	_part = String(p.get("part", "collections" if _launch else "models"))


func refresh() -> void:
	var w := world()
	if w == null:
		return
	var club := w.user_club()
	var pre := SponsorManager.is_preseason(w)
	if _launch and pre:
		screen_subtitle = "Lançamento %d" % w.year
	else:
		screen_subtitle = "Pré-temporada %d" % w.year if pre else "Temporada %d" % w.year
	UIManager.refresh_chrome()
	_build_stage(club, pre)
	var c := content()
	UIKit.clear(c)
	if pre:
		var warn := _clash_card(club)
		if warn != null:
			c.add_child(warn)
		c.add_child(_editor_card(club))
	else:
		var info := UIKit.card("Card", 8)
		info.add_child(UIKit.label("Os uniformes de %d já foram apresentados e estão em campo. Dá para redesenhar tudo na próxima pré-temporada." % w.year, "", true))
		c.add_child(UIKit.card_panel(info))
	c.add_child(_history_card(club))
	c.add_child(_sponsors_card(w, club, pre))
	var f := footer()
	UIKit.clear(f)
	var txt := "PRONTO"
	if pre and not KitDesign.launched(w):
		txt = "APRESENTAR UNIFORMES %d" % w.year
	f.add_child(UIKit.button(txt, "PrimaryButton", func(): _finish(), "check"))


## Sai da tela. Na pré-temporada, não deixa reserva ou terceiro da cor do titular.
func _finish() -> void:
	var w := world()
	var club := w.user_club()
	if not SponsorManager.is_preseason(w):
		UIManager.back()
		return
	var bad := _clashes(club)
	if not bad.is_empty():
		UIManager.confirm("Uniformes da mesma cor",
			"%s está parecido demais com o titular. Em campo, juiz e torcida não teriam como diferenciar. O jogo pode ajustar as cores mantendo o desenho." % _names(bad),
			"Ajustar e concluir", func():
				_fix_all(club)
				_done(w))
		return
	_done(w)


func _done(w: GameWorld) -> void:
	var first := not KitDesign.launched(w)
	KitDesign.mark_launched(w)
	GameManager.save_now()
	UIManager.back()
	if first:
		SocialPost.show_launch(w)


## Nome do camisa 10 do elenco, para a prévia de costas.
func _ten_name() -> String:
	for p in world().squad(world().user_club()):
		if p.shirt == 10:
			return p.display_name()
	return ""


## O uniforme guardado no clube (o dicionário que o editor altera).
func _stored(which: String) -> Dictionary:
	var club := world().user_club()
	match which:
		"gk":
			club.gk_kit() # gera na primeira vez
			return club.kit_gk
		"third":
			club.third_kit()
			return club.kit_third
		"away":
			return club.kit_away
	return club.kit_home


func _kit() -> Dictionary:
	return _stored(_which)


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


## Guarda o estado para o "Desfazer" e aplica a mudança no uniforme aberto.
func _edit(fn: Callable) -> void:
	_edit_many([_which], func(): fn.call(_kit()))


## Mudança em vários uniformes de uma vez (coleções, ajuste automático): um só "Desfazer".
func _edit_many(which: Array, fn: Callable) -> void:
	var snap := {}
	for wk: String in which:
		snap[wk] = _stored(wk).duplicate(true)
	_history.append([snap, _which])
	if _history.size() > 40:
		_history.pop_front()
	fn.call()
	refresh()


func _undo() -> void:
	if _history.is_empty():
		return
	var last: Array = _history.pop_back()
	var snap: Dictionary = last[0]
	for wk: String in snap:
		var k := _stored(wk)
		k.clear()
		k.merge(snap[wk])
	_which = String(last[1])
	refresh()


# ---------------------------------------------------------------------------
# Uniformes parecidos
# ---------------------------------------------------------------------------

## Quais uniformes de linha batem com outro: ["away"], ["third"], ...
func _clashes(club: Club) -> Array:
	var out: Array = []
	if KitDesign.clash(club.kit_home, club.kit_away):
		out.append("away")
	var t := club.third_kit()
	if KitDesign.clash(club.kit_home, t) or KitDesign.clash(club.kit_away, t):
		out.append("third")
	return out


static func _names(which: Array) -> String:
	var n: Array = []
	for wk in which:
		n.append("O " + String(KIT_NAMES[wk]).to_lower())
	return " e ".join(n) if n.size() > 1 else String(n[0])


func _fix_all(club: Club) -> void:
	KitDesign.recolor_distinct(club, club.kit_away, [club.kit_home])
	club.third_kit()
	KitDesign.recolor_distinct(club, club.kit_third, [club.kit_home, club.kit_away])


func _clash_card(club: Club) -> Control:
	var bad := _clashes(club)
	if bad.is_empty():
		return null
	var card := UIKit.card("CardHighlight", 10)
	var head := UIKit.hbox(12)
	head.add_child(UIKit.icon_rect("info", 34, UIColors.RED))
	var t := UIKit.label("%s está da mesma cor do titular" % _names(bad) if bad.size() == 1 else "Reserva e terceiro repetem as cores", "H3", true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	card.add_child(head)
	card.add_child(UIKit.label("Cada uniforme precisa de uma cor principal própria para os jogos em que as camisas se confundem. Troque a cor principal ou deixe o jogo ajustar mantendo o desenho.", "Small", true))
	card.add_child(UIKit.button("Ajustar cores automaticamente", "PrimaryButton", func():
		_edit_many(["away", "third"], func(): _fix_all(club)), "bolt"))
	return UIKit.card_panel(card)


# ---------------------------------------------------------------------------
# Prévia fixa no topo
# ---------------------------------------------------------------------------

func _build_stage(club: Club, pre: bool) -> void:
	if _stage == null:
		_stage = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = UIColors.SURFACE
		sb.border_color = UIColors.LINE
		sb.border_width_bottom = 1
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		_stage.add_theme_stylebox_override(&"panel", sb)
		var body := get_node("Body")
		body.add_child(_stage)
		body.move_child(_stage, 0)
	UIKit.clear(_stage)
	var v := UIKit.vbox(8)
	_stage.add_child(v)
	# Os quatro uniformes: toque para escolher qual editar
	var bad := _clashes(club)
	var row := UIKit.hbox(8)
	for key: String in KIT_ORDER:
		var inner := UIKit.vbox(0)
		var kv := UIKit.kit(_shown(club, key), 62, 0, club.crest)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(kv)
		var cap := String(KIT_NAMES[key]).to_upper()
		var l := UIKit.label(cap, "Caps")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if key in bad:
			l.text = "! " + cap
			l.add_theme_color_override(&"font_color", UIColors.RED)
		elif key == _which:
			l.add_theme_color_override(&"font_color", UIColors.ACCENT)
		inner.add_child(l)
		var t := UIKit.tap_row(inner, func():
			_which = key
			if _part == "collections" and key == "gk":
				_part = "models"
			refresh(), "CardHighlight" if key == _which else "RowPanel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(t)
	v.add_child(row)
	# Prévia grande: frente e costas
	var big := UIKit.hbox(18)
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	for is_back in [false, true]:
		var kv := KitView.new()
		kv.full = true
		kv.kit = _shown(club, _which)
		kv.crest = club.crest
		kv.number = 1 if _which == "gk" else 10
		kv.back = is_back
		kv.back_name = _ten_name() if _which != "gk" else ""
		kv.custom_minimum_size = Vector2(170, 300) if not is_back else Vector2(128, 226)
		kv.size_flags_vertical = Control.SIZE_SHRINK_END
		kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		big.add_child(kv)
	v.add_child(big)
	# Legenda e contraste com o titular
	var cap_row := UIKit.hbox(10)
	cap_row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap_l := UIKit.label("%s · %s" % [String(KIT_NAMES[_which]), _describe(_kit())], "Small")
	cap_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	cap_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if _which in ["home", "gk"] else HORIZONTAL_ALIGNMENT_LEFT
	cap_row.add_child(cap_l)
	if _which in ["away", "third"]:
		var sc := KitDesign.contrast_score(club.kit_home, _shown(club, _which))
		var ok := not (_which in bad)
		cap_row.add_child(UIKit.pill(("Contraste %d" % sc) if ok else "Igual ao titular", UIColors.GREEN if ok else UIColors.RED, 16))
	v.add_child(cap_row)
	if not pre:
		v.modulate = Color(1, 1, 1, 1)


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
	var card := UIKit.card("Card", 12)
	var g := ButtonGroup.new()
	var prow := UIKit.flow(8)
	for p in PARTS:
		var key: String = p[0]
		if key == "collections" and _which == "gk":
			continue
		prow.add_child(UIKit.chip(String(p[1]), key == _part, g, func():
			_part = key
			refresh()))
	card.add_child(prow)
	var k := _kit()
	match _part:
		"collections":
			_collections(card, club)
		"models":
			card.add_child(UIKit.label("Modelos prontos nas cores do clube. Depois, ajuste cada detalhe nas outras abas.", "Small", true))
			card.add_child(_template_grid(club, k))
		"shirt":
			var gg := ButtonGroup.new()
			var grow := UIKit.flow(6)
			for i in KitView.PATTERN_GROUPS.size():
				var gi := i
				grow.add_child(UIKit.chip(String(KitView.PATTERN_GROUPS[i][0]), i == _group, gg, func():
					_group = gi
					refresh()))
			card.add_child(grow)
			card.add_child(_pattern_grid(k))
			var tonal := CheckButton.new()
			tonal.text = "Tom sobre tom (estampa discreta na cor principal)"
			tonal.button_pressed = bool(k.get("tonal", false))
			tonal.focus_mode = Control.FOCUS_NONE
			tonal.custom_minimum_size.y = 56
			tonal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tonal.toggled.connect(func(v: bool):
				AudioManager.click()
				_edit(func(kk: Dictionary): kk["tonal"] = v))
			card.add_child(tonal)
		"colors":
			_colors_part(card, club, k)
		"details":
			card.add_child(UIKit.label("Gola", "Caps"))
			card.add_child(_style_grid(k, "collar", KitView.COLLARS, "round", false))
			card.add_child(UIKit.label("Mangas", "Caps"))
			card.add_child(_style_grid(k, "sleeve", KitView.SLEEVES, "same", false))
			_options(card, "Comprimento da manga", KitView.SLEEVE_LENGTHS, String(k.get("sleeve_len", "short")), "sleeve_len")
			_options(card, "Vivos", KitView.TRIMS, String(k.get("trim", "none")), "trim")
		"shorts":
			card.add_child(_style_grid(k, "shorts_style", KitView.SHORTS_STYLES, "plain", true))
			_palette(card, club, "Cor do calção", "shorts", String(k.get("shorts", k.get("c2", "#111111"))))
			_palette(card, club, "Friso do calção", "shorts2", String(k.get("shorts2", k.get("c1", "#FFFFFF"))))
		"socks":
			card.add_child(_style_grid(k, "socks_style", KitView.SOCKS_STYLES, "plain", true))
			_palette(card, club, "Cor dos meiões", "socks", String(k.get("socks", k.get("c1", "#FFFFFF"))))
			_palette(card, club, "Friso dos meiões", "socks2", String(k.get("socks2", k.get("c2", "#000000"))))
	card.add_child(UIKit.separator())
	var tools := UIKit.hbox(8)
	var undo := UIKit.button("Desfazer", "GhostButton", func(): _undo(), "back")
	undo.disabled = _history.is_empty()
	undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(undo)
	var rnd := UIKit.button("Surpreenda-me", "GhostButton", func():
		_edit(func(kk: Dictionary): _randomize(kk, club)), "bolt")
	rnd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(rnd)
	card.add_child(tools)
	# Copiar o estilo (sem as cores) de outro uniforme do clube
	var copy := UIKit.flow(8)
	copy.add_child(UIKit.label("Copiar o desenho do", "Small"))
	for key: String in KIT_ORDER:
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
		copy.add_child(b)
	card.add_child(copy)
	return UIKit.card_panel(card)


## Coleções da fornecedora: titular, reserva e terceiro que combinam entre si.
func _collections(card: VBoxContainer, club: Club) -> void:
	var w := world()
	var sup: Dictionary = club.sponsors.get("fornecedor", {})
	var brand := String(sup.get("n", "")) if not sup.is_empty() else "A fornecedora"
	card.add_child(UIKit.label("%s apresentou três coleções para %d. Cada uma traz titular, reserva e terceiro do mesmo molde, sem repetir cores. Escolha uma e ajuste o que quiser nas outras abas." % [brand, w.year], "Small", true))
	for i in 3:
		var col := KitDesign.collection(club, w.year, i + _proposal_round * 3)
		var box := UIKit.vbox(8)
		var head := UIKit.hbox(8)
		var nm := UIKit.label("Coleção " + String(col["name"]), "H3")
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(nm)
		box.add_child(head)
		box.add_child(UIKit.label(String(col["desc"]), "Small", true))
		var kits := UIKit.hbox(6)
		kits.alignment = BoxContainer.ALIGNMENT_CENTER
		for pair in [["h", "Titular"], ["a", "Reserva"], ["t", "Terceiro"]]:
			var kv := UIKit.kit(col[pair[0]], 96, 0, club.crest)
			kv.full = true
			kv.custom_minimum_size = Vector2(118, 200)
			var vb := UIKit.vbox(0)
			vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			vb.add_child(kv)
			var l := UIKit.label(String(pair[1]), "Caps")
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(l)
			kits.add_child(vb)
		box.add_child(kits)
		var cc := col
		box.add_child(UIKit.button("Usar esta coleção", "PrimaryButton" if i == 0 else "", func():
			_edit_many(["home", "away", "third"], func(): _apply_collection(club, cc))
			UIManager.toast("Coleção %s aplicada" % String(cc["name"]), UIColors.GREEN), "check"))
		var p := PanelContainer.new()
		p.theme_type_variation = "RowPanel"
		p.add_child(box)
		card.add_child(p)
	card.add_child(UIKit.button("Pedir outras propostas", "GhostButton", func():
		_proposal_round += 1
		refresh(), "swap"))


func _apply_collection(club: Club, col: Dictionary) -> void:
	for pair in [["h", club.kit_home], ["a", club.kit_away]]:
		var k: Dictionary = pair[1]
		for sk in STYLE_KEYS + COLOR_KEYS:
			k.erase(sk)
		for key in col[pair[0]]:
			if not String(key).begins_with("sp") and key != "sup":
				k[key] = col[pair[0]][key]
	club.kit_third = (col["t"] as Dictionary).duplicate(true)


## Aba Cores: combinações prontas, a peça a colorir e a paleta.
func _colors_part(card: VBoxContainer, club: Club, k: Dictionary) -> void:
	card.add_child(UIKit.label("Combinações prontas", "Caps"))
	var ways := KitDesign.colourways(club, _which, k)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for cw: Dictionary in ways:
		var mini := k.duplicate()
		mini.merge(cw, true)
		mini.erase("sp")
		var kv := UIKit.kit(mini, 64)
		kv.full = true
		kv.custom_minimum_size = Vector2(64, 108)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var cell := UIKit.tap_row(kv, func():
			_edit(func(kk: Dictionary):
				kk.merge(cw, true)
				kk.erase("nc")), "RowPanel")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cell)
	card.add_child(grid)
	card.add_child(UIKit.label("Peça por peça", "Caps"))
	var slots := GridContainer.new()
	slots.columns = 4
	slots.add_theme_constant_override(&"h_separation", 8)
	slots.add_theme_constant_override(&"v_separation", 8)
	for sl in SLOTS:
		var field: String = sl[0]
		var cur := _field_color(club, k, field)
		var inner := UIKit.vbox(4)
		var dot := _swatch(cur if cur != "" else _auto_number(k), false, Callable(), "A" if cur == "" else "")
		dot.custom_minimum_size = Vector2(40, 40)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(dot)
		var l := UIKit.label(String(sl[1]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 60
		inner.add_child(l)
		var cell := UIKit.tap_row(inner, func():
			_slot = field
			refresh(), "CardHighlight" if field == _slot else "RowPanel")
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slots.add_child(cell)
	card.add_child(slots)
	var name := ""
	for sl in SLOTS:
		if sl[0] == _slot:
			name = String(sl[1])
	_palette(card, club, "Cor: " + name.to_lower(), _slot, _field_color(club, k, _slot), _slot == "nc")
	var sw := UIKit.button("Trocar principal e estampa", "GhostButton", func():
		_edit(func(kk: Dictionary):
			var a: Variant = kk.get("c1", club.color1)
			kk["c1"] = kk.get("c2", club.color2)
			kk["c2"] = a), "swap")
	card.add_child(sw)


## Cor atual de um campo, com o mesmo padrão que o KitView usa quando o campo não existe.
static func _field_color(club: Club, k: Dictionary, field: String) -> String:
	match field:
		"c1":
			return String(k.get("c1", club.color1))
		"c2":
			return String(k.get("c2", club.color2))
		"c3":
			return String(k.get("c3", k.get("c2", club.color2)))
		"nc":
			return String(k.get("nc", ""))
		"shorts":
			return String(k.get("shorts", k.get("c2", "#111111")))
		"shorts2":
			return String(k.get("shorts2", k.get("c1", "#FFFFFF")))
		"socks":
			return String(k.get("socks", k.get("c1", "#FFFFFF")))
		"socks2":
			return String(k.get("socks2", k.get("c2", "#000000")))
	return ""


## Cor automática dos números (contrasta com a camisa).
static func _auto_number(k: Dictionary) -> String:
	return "#111111" if Color(String(k.get("c1", "#FFFFFF"))).get_luminance() > 0.55 else "#FFFFFF"


func _template_grid(club: Club, k: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	for t: Array in TEMPLATES:
		var tk := template_kit(club, t, k)
		if _which in ["away", "third"]:
			KitDesign.recolor_distinct(club, tk, [club.kit_home] if _which == "away" else [club.kit_home, club.kit_away])
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
		var ready := tk
		var cell := UIKit.tap_row(inner, func():
			_edit(func(kk: Dictionary):
				var keep := {}
				for key in kk:
					if String(key).begins_with("sp") or key == "sup":
						keep[key] = kk[key]
				kk.clear()
				kk.merge(ready)
				kk.merge(keep, true)), "RowPanel")
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


## Opções de desenho mostradas como miniaturas (gola, mangas, calção, meiões).
func _style_grid(k: Dictionary, field: String, opts: Array, default: String, full: bool) -> Control:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 8)
	var cur := String(k.get(field, default))
	for o in opts:
		var val: String = o[0]
		var mini := k.duplicate()
		for key in ["sp", "sup", "sp_m", "sp_s"]:
			mini.erase(key)
		mini[field] = val
		var inner := UIKit.vbox(0)
		var kv := UIKit.kit(mini, 84)
		if full:
			kv.full = true
			kv.custom_minimum_size = Vector2(84, 140)
		kv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		inner.add_child(kv)
		var l := UIKit.label(String(o[1]), "Small")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.custom_minimum_size.x = 104
		inner.add_child(l)
		var t := UIKit.tap_row(inner, func():
			_edit(func(kk: Dictionary): kk[field] = val), "CardHighlight" if val == cur else "RowPanel")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(t)
	return grid


func _options(card: VBoxContainer, caption: String, opts: Array, current: String, field: String) -> void:
	card.add_child(UIKit.label(caption, "Caps"))
	var g := ButtonGroup.new()
	var flow := UIKit.flow(8)
	for o in opts:
		var val: String = o[0]
		flow.add_child(UIKit.chip(String(o[1]), val == current, g, func():
			_edit(func(kk: Dictionary): kk[field] = val)))
	card.add_child(flow)


func _swatch(hex: String, selected: bool, cb: Callable, label := "", blocked := false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(52, 52)
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(hex) if hex != "" else Color(0, 0, 0, 0)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(4 if selected else 1)
	sb.border_color = UIColors.ACCENT if selected else Color(0.5, 0.5, 0.5, 0.45)
	for st in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		b.add_theme_stylebox_override(st, sb)
	var ink := Color("#111111") if (hex == "" or Color(hex).get_luminance() > 0.55) else Color.WHITE
	if hex == "":
		ink = UIColors.TEXT
	if blocked:
		b.text = "×"
		b.modulate = Color(1, 1, 1, 0.4)
		b.add_theme_font_size_override(&"font_size", 28)
	elif label != "":
		b.text = label
		b.add_theme_font_size_override(&"font_size", 16)
	for cn in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(cn, ink)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## A cor `hex` no campo deixaria reserva ou terceiro iguais ao titular?
func _blocks(club: Club, field: String, hex: String) -> bool:
	if field != "c1" or not (_which in ["away", "third"]):
		return false
	var test := _kit().duplicate()
	test["c1"] = hex
	if KitDesign.clash(club.kit_home, test):
		return true
	return _which == "third" and KitDesign.clash(club.kit_away, test)


## Paleta de um campo: cores do clube e neutras à mão, a paleta completa sob demanda e uma cor livre.
## `auto`: primeira opção "Auto" (apaga o campo e deixa o jogo escolher).
func _palette(card: VBoxContainer, club: Club, caption: String, field: String, current: String, auto: bool = false) -> void:
	card.add_child(UIKit.label(caption, "Caps"))
	var flow := UIKit.flow(8)
	var cur := Color(current).to_html(false) if current != "" else ""
	if auto:
		flow.add_child(_swatch("", current == "", func():
			_edit(func(kk: Dictionary): kk.erase(field)), "Auto"))
	var seen := {}
	var list: Array = [club.color1, club.color2]
	list.append_array(QUICK)
	if current != "":
		list.insert(2, current)
	if _more_colors:
		list.append_array(PALETTE)
	for hex in list:
		var h := Color(String(hex)).to_html(false)
		if seen.has(h):
			continue
		seen[h] = true
		var hh := "#" + h.to_upper()
		var blocked := _blocks(club, field, hh)
		flow.add_child(_swatch(hh, h == cur, func():
			if blocked:
				UIManager.toast("Essa cor deixa o %s igual ao titular" % String(KIT_NAMES[_which]).to_lower(), UIColors.RED)
				return
			AudioManager.click()
			_edit(func(kk: Dictionary): kk[field] = hh), "", blocked))
	# Cor livre
	var pick := ColorPickerButton.new()
	pick.custom_minimum_size = Vector2(52, 52)
	pick.text = "+"
	pick.edit_alpha = false
	pick.color = Color(current) if current != "" else Color.WHITE
	pick.focus_mode = Control.FOCUS_NONE
	pick.tooltip_text = "Cor livre"
	pick.popup_closed.connect(func():
		var hx := "#" + pick.color.to_html(false).to_upper()
		if hx == "#" + cur.to_upper():
			return
		if _blocks(club, field, hx):
			UIManager.toast("Essa cor deixa o %s igual ao titular" % String(KIT_NAMES[_which]).to_lower(), UIColors.RED)
			return
		_edit(func(kk: Dictionary): kk[field] = hx))
	flow.add_child(pick)
	card.add_child(flow)
	var more := UIKit.button("Menos cores" if _more_colors else "Mais cores", "GhostButton", func():
		_more_colors = not _more_colors
		refresh(), "minus" if _more_colors else "plus")
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_child(more)


# ---------------------------------------------------------------------------
# Histórico
# ---------------------------------------------------------------------------

func _history_card(club: Club) -> Control:
	var card := UIKit.card("Card", 10)
	card.add_child(UIKit.section("Temporadas anteriores"))
	var hist := KitDesign.history(club)
	var past: Array = hist.filter(func(h): return int(h[0]) != world().year)
	if past.is_empty():
		card.add_child(UIKit.label("Os uniformes entram no histórico do clube quando estreiam em campo. A partir da próxima temporada eles aparecem aqui.", "Small", true))
		return UIKit.card_panel(card)
	for h in past.slice(0, 3):
		var row := UIKit.hbox(10)
		var yl := UIKit.label(str(h[0]), "H3")
		yl.custom_minimum_size.x = 80
		row.add_child(yl)
		for key in ["h", "a", "t"]:
			var kd: Dictionary = h[1].get(key, {})
			if kd.is_empty():
				continue
			var kv := UIKit.kit(kd, 58, 0, club.crest)
			row.add_child(kv)
		card.add_child(row)
	var cid := club.id
	card.add_child(UIKit.button("Ver todos os uniformes (%d temporadas)" % past.size(), "GhostButton", func(): UIManager.push("kit_history", {"id": cid}), "clock"))
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
				nk = ClubGenerator.third_for(rng, club, club.kit_home, club.kit_away)
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


## "Casa de apostas · Inglaterra", "Material esportivo · Itália", "Companhia aérea · multinacional".
func _brand_origin(o: Dictionary) -> String:
	var e := BrandCatalog.find(String(o.get("n", "")))
	if e.is_empty():
		return ""
	var s := String(o.get("s", e.get("s", "")))
	var sector := "Material esportivo" if s == "material" else BrandCatalog.sector_name(s)
	var origin := String(e.get("o", ""))
	var where := DatabaseManager.nation_name(origin) if origin != "" else "multinacional"
	return "%s · %s" % [sector, where]


func _sponsor_row(o: Dictionary, caption: String, cb: Callable) -> Control:
	var row := UIKit.hbox(12)
	var logo := BrandBadge.make(o)
	row.add_child(logo)
	var col := UIKit.vbox(0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := "%s/ano" % Fmt.money(int(o.get("v", 0)))
	if int(o.get("b", 0)) > 0:
		val += " + %s/vitória" % Fmt.money(int(o["b"]))
	col.add_child(UIKit.label(val, "H3", true))
	var who := _brand_origin(o)
	if who != "":
		col.add_child(UIKit.label(who, "Muted"))
	col.add_child(UIKit.label(caption, "Small"))
	row.add_child(col)
	if cb.is_valid():
		return UIKit.tap_row(row, cb)
	return row
