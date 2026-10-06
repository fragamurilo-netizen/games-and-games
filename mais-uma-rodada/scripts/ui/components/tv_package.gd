class_name TvPackage
extends RefCounted
## Pacote gráfico da transmissão de cada competição, inspirado no que cada liga mostra na TV de
## verdade (paleta, forma e a palavra do gol na língua da transmissão), em desenho próprio: sem logos
## nem fontes das ligas. Vale para o placar (layout "pacote" do ScoreboardView), a faixa de gol, o
## cartão do goleador, números, tabela ao vivo, substituição, cartão, melhor em campo e a escalação
## por setor (TvGraphics).
##
## Campos de um pacote:
##   bg, bg2       fundo escuro das peças e um degrau acima
##   accent        cor de destaque da competição (filete, legenda, aba)
##   ink           texto sobre bg
##   light         peças claras (papel branco, texto escuro), como a Bundesliga e a LaLiga
##   paper, paper_ink  papel das peças claras e o texto sobre ele
##   team          "fill" (sigla sobre a cor do clube), "bar" (sigla no papel com filete do clube)
##                 ou "crest" (escudo e sigla)
##   score_bg/score_ink, time_bg/time_ink, logo_bg  placar, aba do tempo e ladrilho do logo
##   radius, skew  cantos (px) e inclinação das peças
##   goal          a palavra do gol na faixa ("GOAL", "GOL", "TOR", "BUT", "GOLO")
##
## Competições sem pacote próprio herdam o do país (ligas e copas nacionais) ou ganham um genérico
## com as cores do placar (ScoreboardTheme). identity.json → "tv" {comp: id do pacote} muda isso.

const PACKS := {
	"premier": {"name": "Premier League", "bg": "#37003C", "bg2": "#4E0D57", "accent": "#00FF85", "ink": "#FFFFFF",
		"light": false, "team": "fill", "score_bg": "#FFFFFF", "score_ink": "#37003C", "time_bg": "#00FF85", "time_ink": "#37003C",
		"logo_bg": "#FFFFFF", "radius": 6, "skew": 0.0, "goal": "GOAL"},
	"efl": {"name": "EFL", "bg": "#0E1638", "bg2": "#1B2552", "accent": "#FFCD00", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FFCD00", "score_ink": "#0E1638", "time_bg": "#1B2552", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 2, "skew": 0.0, "goal": "GOAL"},
	"facup": {"name": "FA Cup", "bg": "#0A1F44", "bg2": "#15305E", "accent": "#C8102E", "ink": "#FFFFFF",
		"light": true, "paper": "#FFFFFF", "paper_ink": "#0A1F44", "team": "crest", "score_bg": "#0A1F44", "score_ink": "#FFFFFF",
		"time_bg": "#C8102E", "time_ink": "#FFFFFF", "logo_bg": "#FFFFFF", "radius": 4, "skew": 0.0, "goal": "GOAL"},
	"laliga": {"name": "LaLiga", "bg": "#141414", "bg2": "#262626", "accent": "#FF4B44", "ink": "#FFFFFF",
		"light": true, "paper": "#FFFFFF", "paper_ink": "#141414", "team": "crest", "score_bg": "#141414", "score_ink": "#FFFFFF",
		"time_bg": "#FF4B44", "time_ink": "#FFFFFF", "logo_bg": "#FFFFFF", "radius": 3, "skew": 0.0, "goal": "GOL"},
	"seriea": {"name": "Serie A", "bg": "#0A1E50", "bg2": "#14307A", "accent": "#3CC7F0", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FFFFFF", "score_ink": "#0A1E50", "time_bg": "#3CC7F0", "time_ink": "#0A1E50",
		"logo_bg": "#FFFFFF", "radius": 14, "skew": 0.0, "goal": "GOL"},
	"bundesliga": {"name": "Bundesliga", "bg": "#121212", "bg2": "#262626", "accent": "#D20515", "ink": "#FFFFFF",
		"light": true, "paper": "#FFFFFF", "paper_ink": "#121212", "team": "bar", "score_bg": "#121212", "score_ink": "#FFFFFF",
		"time_bg": "#D20515", "time_ink": "#FFFFFF", "logo_bg": "#D20515", "radius": 0, "skew": 0.0, "goal": "TOR"},
	"ligue1": {"name": "Ligue 1", "bg": "#091C3E", "bg2": "#13305F", "accent": "#DAE025", "ink": "#FFFFFF",
		"light": false, "team": "fill", "score_bg": "#DAE025", "score_ink": "#091C3E", "time_bg": "#13305F", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 0, "skew": 0.22, "goal": "BUT"},
	"liganos": {"name": "Liga Portugal", "bg": "#0B1F4B", "bg2": "#173273", "accent": "#1FD1B2", "ink": "#FFFFFF",
		"light": false, "team": "fill", "score_bg": "#FFFFFF", "score_ink": "#0B1F4B", "time_bg": "#1FD1B2", "time_ink": "#0B1F4B",
		"logo_bg": "#FFFFFF", "radius": 6, "skew": 0.0, "goal": "GOLO"},
	"eredivisie": {"name": "Eredivisie", "bg": "#101B33", "bg2": "#1D2B4D", "accent": "#F36C21", "ink": "#FFFFFF",
		"light": true, "paper": "#FFFFFF", "paper_ink": "#101B33", "team": "bar", "score_bg": "#F36C21", "score_ink": "#FFFFFF",
		"time_bg": "#101B33", "time_ink": "#FFFFFF", "logo_bg": "#FFFFFF", "radius": 4, "skew": 0.0, "goal": "GOAL"},
	"superlig": {"name": "Süper Lig", "bg": "#22093A", "bg2": "#381058", "accent": "#E30A17", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#E30A17", "score_ink": "#FFFFFF", "time_bg": "#381058", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 4, "skew": 0.18, "goal": "GOL"},
	"brasileirao": {"name": "Brasileirão", "bg": "#0B2E1E", "bg2": "#124A30", "accent": "#FFD100", "ink": "#FFFFFF",
		"light": true, "paper": "#FFFFFF", "paper_ink": "#15171A", "team": "crest", "score_bg": "#0E7A3A", "score_ink": "#FFFFFF",
		"time_bg": "#15171A", "time_ink": "#FFD100", "logo_bg": "#FFFFFF", "radius": 8, "skew": 0.0, "goal": "GOL"},
	"lpf": {"name": "Liga Profesional", "bg": "#0D2340", "bg2": "#173763", "accent": "#75AADB", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FFFFFF", "score_ink": "#0D2340", "time_bg": "#75AADB", "time_ink": "#0D2340",
		"logo_bg": "#FFFFFF", "radius": 4, "skew": 0.0, "goal": "GOL"},
	"mls": {"name": "MLS", "bg": "#101010", "bg2": "#232323", "accent": "#FFFFFF", "ink": "#FFFFFF",
		"light": false, "team": "bar", "score_bg": "#FFFFFF", "score_ink": "#101010", "time_bg": "#232323", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 6, "skew": 0.0, "goal": "GOAL"},
	"jleague": {"name": "J.League", "bg": "#151515", "bg2": "#2A2A2A", "accent": "#E60012", "ink": "#FFFFFF",
		"light": false, "team": "bar", "score_bg": "#E60012", "score_ink": "#FFFFFF", "time_bg": "#2A2A2A", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 2, "skew": 0.0, "goal": "GOAL"},
	"ucl": {"name": "Champions", "bg": "#0B1640", "bg2": "#16266B", "accent": "#C9D6E8", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FFFFFF", "score_ink": "#0B1640", "time_bg": "#16266B", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 12, "skew": 0.0, "goal": "GOAL"},
	"uel": {"name": "Liga Europa", "bg": "#141414", "bg2": "#2A2A2A", "accent": "#FF6900", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FF6900", "score_ink": "#141414", "time_bg": "#2A2A2A", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 8, "skew": 0.0, "goal": "GOAL"},
	"uecl": {"name": "Conference", "bg": "#0C1E14", "bg2": "#173826", "accent": "#00BE14", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#00BE14", "score_ink": "#0C1E14", "time_bg": "#173826", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 8, "skew": 0.0, "goal": "GOAL"},
	"lib": {"name": "Libertadores", "bg": "#111111", "bg2": "#2A2412", "accent": "#D4AF37", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#D4AF37", "score_ink": "#111111", "time_bg": "#2A2412", "time_ink": "#D4AF37",
		"logo_bg": "#111111", "radius": 4, "skew": 0.0, "goal": "GOL"},
	"sud": {"name": "Sul-Americana", "bg": "#0A2A66", "bg2": "#123C8C", "accent": "#5BC2E7", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#FFFFFF", "score_ink": "#0A2A66", "time_bg": "#5BC2E7", "time_ink": "#0A2A66",
		"logo_bg": "#FFFFFF", "radius": 4, "skew": 0.0, "goal": "GOL"},
	"cwc": {"name": "Mundial", "bg": "#16120A", "bg2": "#2E2510", "accent": "#C9A227", "ink": "#FFFFFF",
		"light": false, "team": "crest", "score_bg": "#C9A227", "score_ink": "#16120A", "time_bg": "#2E2510", "time_ink": "#FFFFFF",
		"logo_bg": "#FFFFFF", "radius": 10, "skew": 0.0, "goal": "GOAL"},
}

## Competição → pacote (antes do país).
const COMPS := {
	"ENG1": "premier", "ENG2": "efl", "EFL": "efl", "FAC": "facup", "CSH": "facup",
	"UCL": "ucl", "USC": "ucl", "UEL": "uel", "UECL": "uecl", "LIB": "lib", "REC": "lib", "SUD": "sud", "CWC": "cwc",
}
## País → pacote das ligas e copas nacionais (a TV do país usa a mesma linguagem nas divisões).
const NATIONS := {
	"ESP": "laliga", "GER": "bundesliga", "ITA": "seriea", "FRA": "ligue1", "POR": "liganos", "NED": "eredivisie",
	"TUR": "superlig", "BRA": "brasileirao", "ARG": "lpf", "USA": "mls", "JPN": "jleague",
}

const COLOR_KEYS: Array[String] = ["bg", "bg2", "accent", "ink", "paper", "paper_ink", "score_bg", "score_ink", "time_bg", "time_ink", "logo_bg"]


## Id do pacote de uma competição ("" = sem pacote próprio).
static func id_for(comp: String) -> String:
	if comp == "" or comp == "F":
		return ""
	var custom: Dictionary = DatabaseManager.get_data("identity").get("tv", {})
	if custom.has(comp) and PACKS.has(String(custom[comp])):
		return String(custom[comp])
	if COMPS.has(comp):
		return String(COMPS[comp])
	var nation := ""
	if DatabaseManager.has_league(comp):
		nation = String(DatabaseManager.league_cfg(comp).get("nation", ""))
	else:
		nation = String(DatabaseManager.cup_cfg(comp).get("nation", ""))
	# Estaduais e regionais brasileiros não têm "nation" no continental.json
	if nation == "" and comp in ["SPE", "RJE", "MGE", "RSE", "PRE", "SCE", "CEE", "GOE", "NOR", "VER"]:
		nation = "BRA"
	return String(NATIONS.get(nation, ""))


static func has(comp: String) -> bool:
	return id_for(comp) != ""


## Pacote pronto para desenhar (cores já em Color). Sem pacote próprio: genérico nas cores do
## placar da competição.
static func for_comp(w: GameWorld, comp: String) -> Dictionary:
	var id := id_for(comp)
	if id != "":
		return _resolve(id, PACKS[id])
	var th := ScoreboardTheme.for_competition(w, comp)
	var acc: Color = th["accent"]
	return {
		"id": "", "name": "", "bg": th["bg"], "bg2": th["bg2"], "accent": acc, "ink": th["text"],
		"light": false, "paper": th["bg2"], "paper_ink": th["text"], "team": "crest",
		"score_bg": th["bg2"], "score_ink": th["text"], "time_bg": acc, "time_ink": UIColors.on_color(acc),
		"logo_bg": Color(0, 0, 0, 0), "radius": 6, "skew": 0.0, "goal": "GOL",
	}


static func _resolve(id: String, raw: Dictionary) -> Dictionary:
	var out := raw.duplicate()
	out["id"] = id
	for k in COLOR_KEYS:
		if out.has(k):
			out[k] = Color(String(out[k]))
	if not out.has("paper"):
		out["paper"] = out["bg2"]
		out["paper_ink"] = out["ink"]
	return out


## Fundo e texto das peças de informação (claras nos pacotes de papel, escuras nos outros).
static func panel_colors(pk: Dictionary) -> Array:
	if bool(pk.get("light", false)):
		return [pk["paper"], pk["paper_ink"]]
	return [pk["bg"], pk["ink"]]
