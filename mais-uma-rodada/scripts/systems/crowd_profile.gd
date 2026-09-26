class_name CrowdProfile
extends RefCounted
## Como soa a torcida de cada clube: o estilo da cultura de arquibancada do país e, para as
## torcidas famosas, o jeito delas (a Bombonera que não para de cantar, a Muralha Amarela do
## Dortmund, o inferno turco de apitos, o "You'll Never Walk Alone" lento de Anfield...).
## Clubes sem perfil próprio variam andamento, tom e melodia pelo id: nenhuma torcida é igual.
## Retorna {style, bpm, pitch, seed, legato, sing, loud, whistle, vuvuzela}.

const NATION_STYLE := {
	"BRA": "samba",
	"ARG": "hinchada", "URU": "hinchada", "CHI": "hinchada", "COL": "hinchada", "PAR": "hinchada",
	"PER": "hinchada", "ECU": "hinchada", "BOL": "hinchada", "VEN": "hinchada",
	"ENG": "terrace", "SCO": "terrace", "WAL": "terrace", "IRL": "terrace", "NIR": "terrace", "AUS": "terrace",
	"ITA": "ultras", "TUR": "ultras", "GRE": "ultras", "SRB": "ultras", "CRO": "ultras", "POR": "ultras",
	"ESP": "ultras", "FRA": "ultras", "ROU": "ultras", "BUL": "ultras",
	"GER": "curva", "NED": "curva", "AUT": "curva", "SUI": "curva", "BEL": "curva", "POL": "curva",
	"DEN": "curva", "SWE": "curva", "NOR": "curva", "CZE": "curva", "RUS": "curva", "UKR": "curva",
	"JPN": "taiko", "KOR": "taiko", "CHN": "taiko", "KSA": "taiko", "QAT": "taiko", "UAE": "taiko",
	"IRN": "taiko", "IND": "taiko",
	"NGA": "africa", "GHA": "africa", "RSA": "africa", "EGY": "africa", "MAR": "africa", "SEN": "africa",
	"CMR": "africa", "CIV": "africa", "ALG": "africa", "TUN": "africa",
	"MEX": "banda", "USA": "banda", "CAN": "banda", "CRC": "banda", "HON": "banda",
}

## Torcidas famosas: o que muda em relação ao estilo do país.
const CLUBS := {
	"ARG_XEN": {"style": "hinchada", "bpm": 104.0, "sing": 1.35, "loud": 1.3, "pitch": 196.0}, # Boca, a 12
	"ARG_MIL": {"style": "hinchada", "bpm": 108.0, "sing": 1.2, "loud": 1.15, "pitch": 208.0}, # River
	"ARG_ACA": {"style": "hinchada", "bpm": 100.0, "sing": 1.15, "loud": 1.1},
	"ARG_ROJ": {"style": "hinchada", "bpm": 102.0, "sing": 1.1, "loud": 1.05},
	"ARG_RCA": {"style": "hinchada", "bpm": 106.0, "sing": 1.15, "loud": 1.1},
	"ARG_LEP": {"style": "hinchada", "bpm": 98.0, "sing": 1.15, "loud": 1.1},
	"GER_DOR": {"style": "curva", "bpm": 120.0, "sing": 1.35, "loud": 1.35, "pitch": 176.0}, # Muralha Amarela
	"GER_UNI": {"style": "curva", "bpm": 116.0, "sing": 1.25, "loud": 1.2},
	"GER_PAU": {"style": "curva", "bpm": 112.0, "sing": 1.2, "loud": 1.15},
	"GER_GEL": {"style": "curva", "bpm": 114.0, "sing": 1.2, "loud": 1.2},
	"GER_FFM": {"style": "curva", "bpm": 118.0, "sing": 1.2, "loud": 1.2},
	"GER_KOE": {"style": "curva", "bpm": 110.0, "sing": 1.15, "loud": 1.1},
	"TUR_IAS": {"style": "ultras", "bpm": 116.0, "whistle": 1.0, "loud": 1.45, "sing": 1.2}, # Galatasaray, o inferno
	"TUR_IKN": {"style": "ultras", "bpm": 114.0, "whistle": 1.0, "loud": 1.4, "sing": 1.2}, # Fenerbahçe
	"TUR_IKR": {"style": "ultras", "bpm": 118.0, "whistle": 0.9, "loud": 1.4, "sing": 1.25}, # Beşiktaş
	"TUR_FIR": {"style": "ultras", "bpm": 112.0, "whistle": 0.8, "loud": 1.25},
	"ENG_MSR": {"style": "terrace", "bpm": 72.0, "legato": 1.6, "sing": 1.3, "loud": 1.2, "pitch": 190.0}, # Anfield
	"ENG_TYN": {"style": "terrace", "bpm": 96.0, "sing": 1.2, "loud": 1.15},
	"ENG_MRD": {"style": "terrace", "bpm": 92.0, "sing": 1.1, "loud": 1.1},
	"ENG_LIO": {"style": "terrace", "bpm": 98.0, "sing": 1.15, "loud": 1.1},
	"SCO_GLE": {"style": "terrace", "bpm": 90.0, "legato": 1.4, "sing": 1.3, "loud": 1.25}, # Celtic Park
	"SCO_GLR": {"style": "terrace", "bpm": 96.0, "sing": 1.25, "loud": 1.2},
	"BRA_RNC": {"style": "samba", "bpm": 118.0, "sing": 1.3, "loud": 1.3, "pitch": 230.0}, # Flamengo, a Nação
	"BRA_TIM": {"style": "samba", "bpm": 114.0, "sing": 1.3, "loud": 1.3, "pitch": 214.0}, # Corinthians, a Fiel
	"BRA_VPA": {"style": "samba", "bpm": 112.0, "sing": 1.2, "loud": 1.2},
	"BRA_GAL": {"style": "samba", "bpm": 116.0, "sing": 1.25, "loud": 1.25},
	"BRA_IMT": {"style": "hinchada", "bpm": 106.0, "sing": 1.25, "loud": 1.2}, # Grêmio, a Geral com bombo
	"BRA_COL": {"style": "samba", "bpm": 110.0, "sing": 1.2, "loud": 1.2},
	"BRA_ESQ": {"style": "samba", "bpm": 120.0, "sing": 1.2, "loud": 1.2},
	"BRA_CMA": {"style": "samba", "bpm": 116.0, "sing": 1.2, "loud": 1.2},
	"BRA_PIC": {"style": "samba", "bpm": 118.0, "sing": 1.15, "loud": 1.15},
	"ITA_NAP": {"style": "ultras", "bpm": 110.0, "sing": 1.3, "loud": 1.3, "whistle": 0.5},
	"ITA_RGR": {"style": "ultras", "bpm": 104.0, "sing": 1.25, "loud": 1.2},
	"ITA_RBC": {"style": "ultras", "bpm": 106.0, "sing": 1.2, "loud": 1.2},
	"ITA_MNZ": {"style": "ultras", "bpm": 108.0, "sing": 1.2, "loud": 1.2},
	"ITA_MRN": {"style": "ultras", "bpm": 108.0, "sing": 1.2, "loud": 1.2},
	"POR_ENC": {"style": "ultras", "bpm": 110.0, "sing": 1.2, "loud": 1.2},
	"POR_DRA": {"style": "ultras", "bpm": 112.0, "sing": 1.2, "loud": 1.2},
	"NED_ROT": {"style": "curva", "bpm": 112.0, "sing": 1.3, "loud": 1.25}, # De Kuip
	"ESP_BIL": {"style": "ultras", "bpm": 100.0, "sing": 1.2, "loud": 1.2}, # San Mamés
	"ESP_VBL": {"style": "ultras", "bpm": 104.0, "sing": 1.25, "loud": 1.2},
	"MEX_AME": {"style": "banda", "bpm": 110.0, "loud": 1.15},
}


static func for_club(c: Club) -> Dictionary:
	var style := String(NATION_STYLE.get(c.nation, "terrace"))
	var h := absi(hash(c.key if c.key != "" else str(c.id)))
	# Tamanho da torcida pesa no volume: clubes grandes cantam mais alto
	var loud := clampf(0.7 + c.reputation / 160.0, 0.7, 1.25)
	var prof := {
		"style": style,
		"bpm": _base_bpm(style) + float(h % 13) - 6.0,
		"pitch": 180.0 + float((h / 13) % 70),
		"seed": h,
		"legato": 1.0,
		"sing": 1.0,
		"loud": loud,
		"whistle": 0.8 if c.nation == "TUR" else (0.35 if c.nation in ["GRE", "ITA", "SRB"] else 0.2),
		"vuvuzela": c.nation == "RSA",
	}
	if CLUBS.has(c.key):
		var o: Dictionary = CLUBS[c.key]
		for k in o:
			prof[k] = o[k]
	return prof


static func _base_bpm(style: String) -> float:
	match style:
		"samba":
			return 112.0
		"hinchada":
			return 102.0
		"terrace":
			return 92.0
		"ultras":
			return 106.0
		"curva":
			return 112.0
		"taiko":
			return 100.0
		"africa":
			return 110.0
		"banda":
			return 104.0
	return 100.0


## Chave para cache do áudio já gerado.
static func key_of(p: Dictionary) -> String:
	return "%s_%d_%d_%d" % [p["style"], int(p["bpm"]), int(p["pitch"]), int(p["seed"]) % 1000]
