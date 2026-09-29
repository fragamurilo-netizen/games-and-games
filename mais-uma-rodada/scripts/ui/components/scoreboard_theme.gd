class_name ScoreboardTheme
extends RefCounted
## Visual do placar da partida por competição, como numa transmissão de TV:
## copas continentais com identidade própria e ligas com as cores da bandeira do país.
## Retorna {bg, bg2, accent, text, caps} (cores) — o fundo é sempre escuro para manter a leitura —
## e `layout`, o desenho do placar de cada competição:
##   faixa    — faixa arredondada com o nome e o placar numa caixa com borda
##   tv       — barra reta de transmissão, blocos na cor de cada time e placar cheio na cor da liga
##   angular  — peças inclinadas, como os grafismos modernos de TV
##   capsula  — tudo arredondado, com brilho na cor da competição (noites de copa)
##   classico — placar de estádio antigo: caixa preta e números âmbar
##   compacto — selo pequeno no canto, siglas em fichas coloridas (ScoreboardView)
##   painel   — um time por linha, relógio numa coluna
##   neon     — vidro escuro e filetes acesos
## O desenho de cada um fica em ScoreboardView.
##
## Dados (todos opcionais, do mais forte para o mais fraco):
##   "scoreboard" na própria competição (leagues.json, continental.json, domestic.json ou Editor):
##       {"colors": ["#fundo", "#fundo2", "#destaque"], "layout": "tv", "text": "#texto"}
##   identity.json → scoreboard {id: [3 cores]} e scoreboard_layout {id: "layout"}
##   CUPS e LAYOUT_OF abaixo; senão as cores da liga (ou da bandeira) e um desenho sorteado pelo id.

const CUPS := {
	"UCL": ["#0B1640", "#16266B", "#C9D6E8"],
	"LIB": ["#111111", "#2A2412", "#D4AF37"],
	"CCC": ["#0A2342", "#12365E", "#3FC1C9"],
	"CAF": ["#0B3D1A", "#135C28", "#F2C94C"],
	"AFC": ["#2B0A36", "#44104F", "#E0B04D"],
	"CWC": ["#2A1F00", "#4A3700", "#F2C94C"],
}
const DEFAULT := ["#0F1012", "#18191C", "#FFC940"]
const LAYOUTS: Array[String] = ["faixa", "tv", "angular", "capsula", "classico", "compacto", "painel", "neon"]
const LAYOUT_NAMES := {"faixa": "Faixa", "tv": "TV", "angular": "Angular", "capsula": "Cápsula", "classico": "Clássico",
	"compacto": "Compacto", "painel": "Painel", "neon": "Neon"}
const LAYOUT_HINTS := {
	"faixa": "Faixa arredondada com o nome da competição e o placar numa caixa com borda.",
	"tv": "Barra reta de transmissão, blocos na cor de cada time e placar cheio na cor da liga.",
	"angular": "Peças inclinadas, como os grafismos modernos de TV.",
	"capsula": "Tudo arredondado, com brilho na cor da competição (noites de copa).",
	"classico": "Placar de estádio antigo: caixa preta e números âmbar.",
	"compacto": "Selo no canto: logo, siglas em fichas coloridas, placar e relógio numa linha só.",
	"painel": "Um time por linha, com o placar empilhado e o relógio numa coluna ao lado.",
	"neon": "Vidro escuro, filetes acesos na cor da competição e números grandes.",
}
const LAYOUT_OF := {
	"UCL": "faixa", "LIB": "classico", "CWC": "faixa", "CCC": "angular", "CAF": "tv", "AFC": "angular",
	"ENG1": "compacto", "ENG2": "faixa", "ESP1": "angular", "GER1": "tv", "ITA1": "painel", "FRA1": "angular",
	"POR1": "faixa", "NED1": "painel", "BRA1": "compacto", "BRA2": "tv", "ARG1": "classico", "MEX1": "angular",
	"USA1": "painel", "KSA1": "tv", "JPN1": "angular", "TUR1": "classico", "UEL": "angular", "UECL": "tv", "SUD": "painel",
}


static func for_competition(w: GameWorld, comp: String) -> Dictionary:
	var pal: Array = DEFAULT
	var custom: Dictionary = DatabaseManager.get_data("identity").get("scoreboard", {})
	var own := comp_style(comp)
	var text := Color("#F4F6F8")
	if own.get("text", null) is String:
		text = Color(String(own["text"]))
	if own.get("colors", null) is Array and (own["colors"] as Array).size() >= 3:
		pal = own["colors"]
	elif custom.has(comp):
		pal = custom[comp]
	elif CUPS.has(comp):
		pal = CUPS[comp]
	elif DatabaseManager.has_league(comp):
		pal = _league_palette(w, comp)
	var bg := Color(String(pal[0]))
	var bg2 := Color(String(pal[1]))
	var accent := Color(String(pal[2]))
	return {"bg": bg, "bg2": bg2, "accent": accent, "text": text, "caps": accent.lerp(Color.WHITE, 0.35), "layout": layout_for(comp)}


## Placar escrito na própria competição (dados, mods ou Editor), ou {}.
static func comp_style(comp: String) -> Dictionary:
	var cfg: Dictionary = DatabaseManager.league_cfg(comp) if DatabaseManager.has_league(comp) else DatabaseManager.cup_cfg(comp)
	var sb: Variant = cfg.get("scoreboard", {})
	return sb if sb is Dictionary else {}


## Placar dos dados (sem a personalização do Editor), ou {}.
static func data_style(comp: String) -> Dictionary:
	var cfg: Dictionary = DatabaseManager.league_cfg(comp) if DatabaseManager.has_league(comp) else DatabaseManager.cup_cfg(comp)
	var sb: Variant = cfg["_orig"].get("scoreboard", {}) if cfg.get("_orig", null) is Dictionary else cfg.get("scoreboard", {})
	return sb if sb is Dictionary else {}


static func layout_name(layout: String) -> String:
	return String(LAYOUT_NAMES.get(layout, layout.capitalize()))


static func layout_hint(layout: String) -> String:
	return String(LAYOUT_HINTS.get(layout, ""))


## Desenho do placar da competição. Com `with_editor` falso, ignora o que foi escolhido no Editor
## (é o "automático" que o Editor mostra).
static func layout_for(comp: String, with_editor: bool = true) -> String:
	var style := comp_style(comp) if with_editor else data_style(comp)
	var own := String(style.get("layout", ""))
	if LAYOUTS.has(own):
		return own
	var custom: Dictionary = DatabaseManager.get_data("identity").get("scoreboard_layout", {})
	if custom.has(comp):
		return String(custom[comp])
	if LAYOUT_OF.has(comp):
		return String(LAYOUT_OF[comp])
	# Lower divisions share the country's broadcast grammar instead of choosing
	# arbitrary effects from a hash. Competition/editor overrides still win.
	var nation := String(DatabaseManager.league_cfg(comp).get("nation", "")) if DatabaseManager.has_league(comp) else String(DatabaseManager.cup_cfg(comp).get("nation", ""))
	return String(LAYOUT_OF.get(nation + "1", "tv"))


## Liga: fundo escuro na cor da marca da liga e destaque com a segunda cor (como a transmissão
## oficial); sem cores próprias, a bandeira do país. Divisões de baixo ficam mais sóbrias.
static func _league_palette(w: GameWorld, comp: String) -> Array:
	# Sem carreira (Editor), a divisão e o país vêm dos dados.
	var cfg := DatabaseManager.league_cfg(comp)
	var league_tier := int(cfg.get("tier", 1))
	var league_nation := String(cfg.get("nation", ""))
	if w != null:
		var league := w.league(comp)
		if league == null:
			return DEFAULT
		league_tier = league.tier
		league_nation = league.nation
	var brand: Array = DatabaseManager.league_cfg(comp).get("colors", [])
	if brand.size() >= 2:
		var b0 := Color(String(brand[0]))
		var b1 := Color(String(brand[1]))
		var fd := clampf(0.12 * (league_tier - 1), 0.0, 0.4)
		if b0.get_luminance() > 0.6: # marca clara: fundo na segunda cor
			var tmp := b0
			b0 = b1
			b1 = tmp
		if b1.get_luminance() < 0.3:
			b1 = b1.lightened(0.55)
		return [b0.darkened(0.6).lerp(Color("#0F1012"), fd).to_html(false), b0.darkened(0.4).lerp(Color("#18191C"), fd).to_html(false), b1.lerp(Color("#C8CED6"), fd).to_html(false)]
	var flag: Dictionary = DatabaseManager.nation(league_nation).get("flag", {})
	var cols: Array = flag.get("c", [])
	if cols.is_empty():
		return DEFAULT
	var sorted: Array = []
	for c in cols:
		sorted.append(Color(String(c)))
	# Cor mais saturada vira o fundo; a mais clara (ou outra saturada) o destaque.
	sorted.sort_custom(func(a: Color, b: Color): return a.s > b.s)
	var base: Color = sorted[0]
	var acc: Color = sorted[1] if sorted.size() > 1 else Color("#FFFFFF")
	if acc.get_luminance() < 0.35:
		acc = acc.lightened(0.5)
	if absf(acc.h - base.h) < 0.04 and absf(acc.s - base.s) < 0.2:
		acc = Color("#FFFFFF")
	var fade := clampf(0.15 * (league_tier - 1), 0.0, 0.45)
	var bg := base.darkened(0.72).lerp(Color("#0F1012"), fade)
	var bg2 := base.darkened(0.55).lerp(Color("#18191C"), fade)
	return [bg.to_html(false), bg2.to_html(false), acc.lerp(Color("#C8CED6"), fade).to_html(false)]
