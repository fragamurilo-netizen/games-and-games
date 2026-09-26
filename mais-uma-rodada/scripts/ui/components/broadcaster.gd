class_name Broadcaster
extends RefCounted
## Emissora (fictícia) que transmite cada competição, como na TV de verdade: copas continentais e
## seleções com a sua, cada país com um canal aberto para a elite e um fechado para o resto
## (divisões de baixo, copas e estaduais). O placar da partida mostra o selo dela no canto e a
## pré-partida diz onde passa. Retorna {name, short, c1 (fundo do selo), c2 (letras)}.

const CUPS := {
	"UCL": ["Estrela Sports", "E★", "#0B1640", "#FFFFFF"],
	"UEL": ["Estrela Sports 2", "E2", "#1B1B1B", "#F58220"],
	"UECL": ["Estrela Sports 3", "E3", "#0F2A1D", "#35D07F"],
	"LIB": ["Continental TV", "CTV", "#1A1406", "#D4AF37"],
	"SUD": ["Continental TV 2", "CT2", "#0E2340", "#7FB8FF"],
	"CCC": ["Norte Sports", "NS", "#0A2342", "#3FC1C9"],
	"CAF": ["Sahel Sports", "SS", "#0B3D1A", "#F2C94C"],
	"AFC": ["Ásia Arena", "AA", "#2B0A36", "#E0B04D"],
	"CWC": ["Mundo TV", "MTV", "#2A1F00", "#F2C94C"],
	"NT": ["Mundo TV", "MTV", "#2A1F00", "#F2C94C"],
}
## País: [canal aberto (elite), sigla, fundo, letras, canal fechado (resto), sigla]
const NATIONS := {
	"BRA": ["Rede Tropical", "RT", "#0B5D2A", "#FFD23F", "TropiSport", "TS"],
	"ENG": ["Albion Sports", "AS", "#3D0A57", "#00F0C8", "Albion Sports 2", "AS2"],
	"ESP": ["Canal Liga+", "L+", "#101010", "#FF4B4B", "Canal Liga+ 2", "L+2"],
	"ITA": ["Tricolore TV", "T3", "#062E6F", "#FFFFFF", "Tricolore Sport", "TS"],
	"GER": ["Kanal Elf", "K11", "#151515", "#E4002B", "Kanal Elf 2", "K12"],
	"FRA": ["Hexa Sport", "HX", "#0A1F5C", "#FFFFFF", "Hexa Sport 2", "HX2"],
	"POR": ["Sport Lusa", "SL", "#8A0F14", "#FFD200", "Sport Lusa 2", "SL2"],
	"NED": ["Oranje TV", "OTV", "#F36C21", "#FFFFFF", "Oranje TV 2", "OT2"],
	"ARG": ["Pampa Deportes", "PD", "#0E3B66", "#7EC8F2", "Pampa Deportes 2", "PD2"],
	"MEX": ["Canal Sol", "SOL", "#0C4B2E", "#FFB81C", "Canal Sol 2", "SO2"],
	"USA": ["Stars & Goals", "S&G", "#0A2240", "#E03A3E", "Stars & Goals+", "SG+"],
	"JPN": ["Sakura Sports", "SKR", "#2A0A1A", "#FF8FB1", "Sakura Sports 2", "SK2"],
	"KSA": ["Falcão Sports", "FLC", "#0B3B24", "#FFFFFF", "Falcão Sports 2", "FL2"],
	"TUR": ["Bósforo Spor", "BSP", "#7A0A12", "#FFFFFF", "Bósforo Spor 2", "BS2"],
	"SCO": ["Highland TV", "HTV", "#0B2A5B", "#FFFFFF", "Highland TV 2", "HT2"],
	"BEL": ["Canal Diabo", "CD", "#1A1A1A", "#E30613", "Canal Diabo 2", "CD2"],
	"URU": ["Celeste TV", "CEL", "#0B3C73", "#8FD3FF", "Celeste TV 2", "CE2"],
	"COL": ["Cafetal TV", "CAF", "#3A1F0B", "#FCD116", "Cafetal TV 2", "CA2"],
	"CHI": ["Andes Sport", "AND", "#0033A0", "#FFFFFF", "Andes Sport 2", "AN2"],
}


static func for_competition(w: GameWorld, comp: String) -> Dictionary:
	var th := ScoreboardTheme.for_competition(w, comp) if w != null else {}
	if CUPS.has(comp):
		return _make(CUPS[comp])
	var nation := ""
	var elite := false
	var league := w.league(comp) if w != null else null
	if league != null:
		nation = league.nation
		elite = league.tier == 1
	else:
		nation = String(DatabaseManager.cup_cfg(comp).get("nation", ""))
	if NATIONS.has(nation):
		var n: Array = NATIONS[nation]
		return _make([n[0], n[1], n[2], n[3]] if elite else [n[4], n[5], n[2], n[3]])
	# País sem canal próprio nos dados: "Esporte <país>", nas cores do placar da competição
	var nm := DatabaseManager.nation_name(nation) if nation != "" else ""
	var bg: Color = th.get("bg2", Color("#18191C"))
	var fg: Color = th.get("accent", Color("#FFC940"))
	return {"name": ("Esporte %s" % nm) if nm != "" else "Esporte TV", "short": (nation.left(2) + "S") if nation != "" else "ETV",
		"c1": bg, "c2": fg}


static func _make(a: Array) -> Dictionary:
	return {"name": String(a[0]), "short": String(a[1]), "c1": Color(String(a[2])), "c2": Color(String(a[3]))}


## Selo da emissora (retângulo com a sigla) e, opcionalmente, o "AO VIVO" com a bolinha vermelha.
static func bug(b: Dictionary, live := true) -> Control:
	var row := UIKit.hbox(6)
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = b["c1"]
	st.border_color = (b["c2"] as Color)
	st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	p.add_theme_stylebox_override(&"panel", st)
	var l := UIKit.label(String(b["short"]), "Caps")
	l.add_theme_color_override(&"font_color", b["c2"])
	p.add_child(l)
	row.add_child(p)
	if live:
		var dot := UIKit.label("● AO VIVO", "Caps")
		dot.add_theme_color_override(&"font_color", Color("#FF4B4B"))
		row.add_child(dot)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row
