class_name ScoreboardTheme
extends RefCounted
## Visual do placar da partida por competição, como numa transmissão de TV:
## copas continentais com identidade própria e ligas com as cores da bandeira do país.
## Retorna {bg, bg2, accent, text, caps} (cores) — o fundo é sempre escuro para manter a leitura.

const CUPS := {
	"UCL": ["#0B1640", "#16266B", "#C9D6E8"],
	"LIB": ["#111111", "#2A2412", "#D4AF37"],
	"CCC": ["#0A2342", "#12365E", "#3FC1C9"],
	"CAF": ["#0B3D1A", "#135C28", "#F2C94C"],
	"AFC": ["#2B0A36", "#44104F", "#E0B04D"],
	"CWC": ["#2A1F00", "#4A3700", "#F2C94C"],
}
const DEFAULT := ["#10151C", "#18202A", "#FFC940"]


static func for_competition(w: GameWorld, comp: String) -> Dictionary:
	var pal: Array = DEFAULT
	var custom: Dictionary = DatabaseManager.get_data("identity").get("scoreboard", {})
	if custom.has(comp):
		pal = custom[comp]
	elif CUPS.has(comp):
		pal = CUPS[comp]
	elif DatabaseManager.has_league(comp):
		pal = _league_palette(w, comp)
	var bg := Color(String(pal[0]))
	var bg2 := Color(String(pal[1]))
	var accent := Color(String(pal[2]))
	return {"bg": bg, "bg2": bg2, "accent": accent, "text": Color("#F4F6F8"), "caps": accent.lerp(Color.WHITE, 0.35)}


## Liga: fundo escuro na cor da marca da liga e destaque com a segunda cor (como a transmissão
## oficial); sem cores próprias, a bandeira do país. Divisões de baixo ficam mais sóbrias.
static func _league_palette(w: GameWorld, comp: String) -> Array:
	var league := w.league(comp)
	if league == null:
		return DEFAULT
	var brand: Array = DatabaseManager.league_cfg(comp).get("colors", [])
	if brand.size() >= 2:
		var b0 := Color(String(brand[0]))
		var b1 := Color(String(brand[1]))
		var fd := clampf(0.12 * (league.tier - 1), 0.0, 0.4)
		if b0.get_luminance() > 0.6: # marca clara: fundo na segunda cor
			var tmp := b0
			b0 = b1
			b1 = tmp
		if b1.get_luminance() < 0.3:
			b1 = b1.lightened(0.55)
		return [b0.darkened(0.6).lerp(Color("#10151C"), fd).to_html(false), b0.darkened(0.4).lerp(Color("#18202A"), fd).to_html(false), b1.lerp(Color("#C8CED6"), fd).to_html(false)]
	var flag: Dictionary = DatabaseManager.nation(league.nation).get("flag", {})
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
	var fade := clampf(0.15 * (league.tier - 1), 0.0, 0.45)
	var bg := base.darkened(0.72).lerp(Color("#10151C"), fade)
	var bg2 := base.darkened(0.55).lerp(Color("#18202A"), fade)
	return [bg.to_html(false), bg2.to_html(false), acc.lerp(Color("#C8CED6"), fade).to_html(false)]
