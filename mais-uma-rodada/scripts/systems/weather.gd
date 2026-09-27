class_name Weather
extends RefCounted
## Clima de cada partida: pelo clima do país, pela estação (hemisfério norte/sul) e pelo horário.
## Não é enfeite: muda o jogo nos dois motores (minuto a minuto e rápido) e aparece no campo.
##   chuva      — gramado rápido e escorregadio: mais erros, chute de longe quica e engana o goleiro
##   temporal   — gramado encharcado: a bola para nas poças, menos gols, mais faltas e desgaste
##   neve       — bola pesada, pouca técnica: menos gols e muitos erros
##   calor      — o time cansa mais e o ritmo cai no segundo tempo
##   vento      — cruzamentos e chutes de longe desviam
##   neblina    — rara; visão curta, lançamentos imprecisos
## Resultado: {kind, night, temp, pitch, fx: {goals, fatigue, errors, long, cross, pass, fouls, injury}}.

const KINDS: Array[String] = ["sun", "cloud", "rain", "storm", "snow", "heat", "wind", "fog"]
const NAMES := {"sun": "Sol", "cloud": "Nublado", "rain": "Chuva", "storm": "Temporal", "snow": "Neve", "heat": "Calor forte", "wind": "Vento", "fog": "Neblina"}

## Clima por país: temperatura média [inverno, primavera, verão, outono], chance de chuva por
## estação e chance de neve no inverno. Hemisfério sul: as estações se invertem.
const CLIMATES := {
	"oceanic": {"t": [5, 11, 19, 12], "rain": [0.38, 0.3, 0.22, 0.36], "snow": 0.03},
	"continental": {"t": [0, 10, 21, 10], "rain": [0.22, 0.28, 0.3, 0.26], "snow": 0.22},
	"nordic": {"t": [-4, 6, 17, 6], "rain": [0.2, 0.25, 0.3, 0.3], "snow": 0.45},
	"mediterranean": {"t": [11, 17, 28, 19], "rain": [0.3, 0.2, 0.05, 0.22], "snow": 0.01},
	"tropical": {"t": [24, 27, 29, 27], "rain": [0.18, 0.28, 0.42, 0.3], "snow": 0.0},
	"subtropical_s": {"t": [15, 21, 28, 22], "rain": [0.14, 0.22, 0.34, 0.24], "snow": 0.0},
	"temperate_s": {"t": [9, 16, 25, 17], "rain": [0.2, 0.22, 0.2, 0.22], "snow": 0.0},
	"desert": {"t": [19, 29, 38, 30], "rain": [0.06, 0.03, 0.01, 0.03], "snow": 0.0},
	"highland": {"t": [13, 15, 16, 15], "rain": [0.25, 0.3, 0.35, 0.3], "snow": 0.0},
	"east_asia": {"t": [1, 13, 27, 16], "rain": [0.1, 0.25, 0.45, 0.2], "snow": 0.12},
}
const NATION_CLIMATE := {
	"ENG": "oceanic", "SCO": "oceanic", "WAL": "oceanic", "IRL": "oceanic", "NED": "oceanic", "BEL": "oceanic", "FRA": "oceanic", "DEN": "oceanic",
	"GER": "continental", "AUT": "continental", "SUI": "continental", "POL": "continental", "CZE": "continental", "SVK": "continental", "HUN": "continental",
	"SRB": "continental", "ROU": "continental", "UKR": "continental", "BUL": "continental", "CRO": "continental", "SVN": "continental", "BIH": "continental",
	"NOR": "nordic", "SWE": "nordic", "FIN": "nordic", "RUS": "nordic", "ISL": "nordic", "CAN": "nordic",
	"ESP": "mediterranean", "POR": "mediterranean", "ITA": "mediterranean", "GRE": "mediterranean", "TUR": "mediterranean", "CYP": "mediterranean", "ISR": "mediterranean", "MAR": "mediterranean", "TUN": "mediterranean", "ALG": "mediterranean",
	"BRA": "tropical", "COL": "tropical", "VEN": "tropical", "NGA": "tropical", "SEN": "tropical", "CIV": "tropical", "GHA": "tropical", "CMR": "tropical", "MEX": "tropical",
	"PAR": "subtropical_s", "RSA": "subtropical_s", "AUS": "subtropical_s",
	"ARG": "temperate_s", "URU": "temperate_s", "CHI": "temperate_s", "NZL": "temperate_s",
	"KSA": "desert", "QAT": "desert", "UAE": "desert", "EGY": "desert",
	"ECU": "highland", "BOL": "highland", "PER": "highland",
	"JPN": "east_asia", "KOR": "east_asia", "CHN": "east_asia", "USA": "east_asia",
}
## Horários de jogo mais comuns em cada país (hora local) e o peso de cada um.
const KICKOFFS := {
	"BRA": {16: 0.3, 18: 0.2, 19: 0.1, 21: 0.4}, "ARG": {15: 0.1, 17: 0.25, 19: 0.3, 21: 0.35}, "URU": {15: 0.3, 17: 0.3, 20: 0.4},
	"CHI": {15: 0.3, 18: 0.35, 20: 0.35}, "COL": {16: 0.3, 18: 0.3, 20: 0.4}, "MEX": {17: 0.2, 19: 0.4, 21: 0.4}, "USA": {15: 0.2, 19: 0.5, 20: 0.3},
	"ENG": {12: 0.15, 15: 0.45, 17: 0.25, 20: 0.15}, "ESP": {14: 0.15, 16: 0.2, 18: 0.25, 21: 0.4}, "ITA": {12: 0.1, 15: 0.3, 18: 0.3, 20: 0.3},
	"GER": {15: 0.6, 17: 0.15, 20: 0.25}, "FRA": {13: 0.1, 15: 0.25, 17: 0.25, 21: 0.4}, "POR": {15: 0.2, 18: 0.35, 20: 0.45},
	"NED": {12: 0.2, 14: 0.35, 16: 0.25, 20: 0.2}, "TUR": {14: 0.2, 17: 0.3, 20: 0.5}, "KSA": {17: 0.1, 20: 0.5, 21: 0.4},
	"QAT": {17: 0.2, 20: 0.8}, "UAE": {17: 0.2, 20: 0.8}, "EGY": {17: 0.3, 20: 0.7}, "JPN": {14: 0.3, 16: 0.2, 19: 0.5},
}
const DEFAULT_KICKOFFS := {14: 0.2, 16: 0.3, 18: 0.2, 20: 0.3}
## Pôr do sol aproximado por clima e estação [inverno, primavera, verão, outono] (hora local).
const SUNSET := {"oceanic": [16.2, 19.5, 21.2, 18.0], "continental": [16.6, 19.4, 21.0, 18.2], "nordic": [15.3, 19.8, 22.5, 17.6],
	"mediterranean": [17.8, 20.2, 21.3, 19.0], "tropical": [17.9, 18.1, 18.6, 18.3], "subtropical_s": [17.6, 18.9, 19.9, 18.6],
	"temperate_s": [18.0, 19.6, 20.6, 19.1], "desert": [17.3, 18.4, 18.9, 17.9], "highland": [18.1, 18.2, 18.4, 18.3], "east_asia": [16.8, 18.8, 19.9, 17.8]}
const SOUTH: Array[String] = ["BRA", "ARG", "URU", "PAR", "CHI", "RSA", "AUS", "NZL", "BOL", "PER"]
## Estados do Brasil com inverno de verdade (frio e garoa no Sul).
const BRA_SOUTH_UF: Array[String] = ["RS", "SC", "PR"]


## Altitude (metros) das cidades onde ela pesa: o visitante sem costume cansa muito mais.
const ALTITUDE := {"La Paz": 3640, "El Alto": 4150, "Potosí": 4090, "Oruro": 3700, "Sucre": 2810, "Cochabamba": 2560,
	"Quito": 2850, "Cuenca": 2560, "Ambato": 2580, "Latacunga": 2750, "Riobamba": 2750, "Bogotá": 2640, "Tunja": 2800, "Pasto": 2530,
	"Manizales": 2150, "Cusco": 3400, "Juliaca": 3825, "Huancayo": 3250, "Arequipa": 2330, "Cajamarca": 2750, "Ciudad de México": 2240,
	"Toluca": 2660, "Pachuca": 2400, "Puebla": 2135}


## Efeito da altitude no visitante que vem do nível do mar (multiplica o cansaço dele).
static func altitude_fatigue(home: Club, away: Club) -> float:
	var h := float(ALTITUDE.get(home.city, 0))
	var a := float(ALTITUDE.get(away.city, 0)) if away != null else 0.0
	if h < 2000.0 or a >= h - 800.0:
		return 1.0
	return 1.0 + (h - maxf(a, 0.0) - 1000.0) / 3000.0 * 0.35


## Clima de um jogo do calendário (determinístico: o mesmo jogo tem sempre o mesmo tempo).
static func for_fixture(world: GameWorld, f: Fixture) -> Dictionary:
	var home := world.club(f.home)
	var month := 0
	if world.season != null and f.slot >= 0:
		var mv := world.season.month_of(f.slot)
		month = (mv - 1) % 12 + 1 if mv > 0 else 0
	var continental := world.league(f.comp) == null and f.comp != "F"
	var wx := roll(home, month, continental, hash([world.world_seed, world.year, f.home, f.away, f.slot, "clima"]))
	if not f.neutral:
		var alt := altitude_fatigue(home, world.club(f.away))
		if alt > 1.0:
			wx["alt"] = int(ALTITUDE.get(home.city, 0))
			wx["away_fatigue"] = alt
	return wx


static func roll(home: Club, month: int, continental: bool, seed_value: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var nation := home.nation if home != null else ""
	var cl: Dictionary = CLIMATES[NATION_CLIMATE.get(nation, "oceanic")]
	if month <= 0:
		month = 9
	# Estação: 0 inverno, 1 primavera, 2 verão, 3 outono (norte); o sul inverte
	var season: int = [0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 0][month - 1]
	if SOUTH.has(nation):
		season = (season + 2) % 4
	var temp := float(cl["t"][season]) + r.randfn(0.0, 3.5)
	if nation == "BRA" and home != null and BRA_SOUTH_UF.has(home.region):
		temp -= 6.0
	# Horário: o de sempre da liga; noite de copa continental; o sol se põe conforme estação e lugar
	var ko: Dictionary = KICKOFFS.get(nation, DEFAULT_KICKOFFS)
	var hour: int = int(RngUtil.weighted_key(r, ko))
	if continental:
		hour = 21 if r.randf() < 0.8 else 19
	var sunset: float = float(SUNSET[NATION_CLIMATE.get(nation, "oceanic")][season])
	var night := float(hour) + 1.0 >= sunset # o jogo termina depois do pôr do sol: refletores
	if night:
		temp -= 4.0
	var kind := "cloud"
	var rain_p := float(cl["rain"][season])
	var snow_p := float(cl["snow"]) if season == 0 else (float(cl["snow"]) * 0.2 if season in [1, 3] else 0.0)
	var roll_w := r.randf()
	if temp <= 2.0 and roll_w < snow_p:
		kind = "snow"
	elif roll_w < snow_p + rain_p:
		kind = "storm" if r.randf() < (0.3 if NATION_CLIMATE.get(nation, "") == "tropical" and season == 2 else 0.12) else "rain"
	elif temp >= 29.0 and not night:
		kind = "heat"
	elif r.randf() < 0.1:
		kind = "wind"
	elif r.randf() < 0.03 and temp < 12.0:
		kind = "fog"
	elif not night and r.randf() < 0.55:
		kind = "sun"
	var pitch := "dry"
	match kind:
		"rain":
			pitch = "wet"
		"storm":
			pitch = "heavy"
		"snow":
			pitch = "snow"
	return {"kind": kind, "night": night, "hour": hour, "temp": int(round(temp)), "pitch": pitch, "fx": effects(kind, temp)}


## Efeitos no jogo (multiplicadores; 1 = neutro).
static func effects(kind: String, temp: float) -> Dictionary:
	var fx := {"goals": 1.0, "fatigue": 1.0, "errors": 1.0, "long": 1.0, "cross": 1.0, "pass": 1.0, "fouls": 1.0, "injury": 1.0}
	match kind:
		"rain":
			fx = {"goals": 1.03, "fatigue": 1.05, "errors": 1.35, "long": 1.3, "cross": 0.95, "pass": 0.96, "fouls": 1.08, "injury": 1.08}
		"storm":
			fx = {"goals": 0.86, "fatigue": 1.18, "errors": 1.6, "long": 1.1, "cross": 0.8, "pass": 0.88, "fouls": 1.15, "injury": 1.12}
		"snow":
			fx = {"goals": 0.88, "fatigue": 1.12, "errors": 1.5, "long": 0.9, "cross": 0.85, "pass": 0.9, "fouls": 1.05, "injury": 1.15}
		"heat":
			fx = {"goals": 0.95, "fatigue": 1.25, "errors": 1.1, "long": 1.0, "cross": 1.0, "pass": 0.98, "fouls": 1.05, "injury": 1.05}
		"wind":
			fx = {"goals": 0.97, "fatigue": 1.03, "errors": 1.1, "long": 0.75, "cross": 0.8, "pass": 0.97, "fouls": 1.0, "injury": 1.0}
		"fog":
			fx = {"goals": 0.95, "fatigue": 1.0, "errors": 1.2, "long": 0.8, "cross": 0.9, "pass": 0.95, "fouls": 1.0, "injury": 1.0}
	if temp <= -2.0:
		fx["injury"] = float(fx["injury"]) * 1.1 # gramado duro
		fx["fatigue"] = float(fx["fatigue"]) * 1.03
	return fx


static func label(wx: Dictionary) -> String:
	if wx.is_empty():
		return ""
	return "%s · %d°C%s" % [NAMES.get(String(wx.get("kind", "")), ""), int(wx.get("temp", 20)), " · noite" if bool(wx.get("night", false)) else ""]
