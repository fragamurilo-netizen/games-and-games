"""Gera os logos de competição de data/world/identity.json (formato do CrestView, chave "logo").

Uso (em mais-uma-rodada/): python3 tools/crest_gen/logos.py .
Refaz todos os logos daqui; logos de competições que não estão aqui ficam como estão.
"""
import json, sys, colorsys

ROOT = sys.argv[1]
GOLD = "#E2B84A"
SILVER = "#DDE2E8"
INK = "#15171B"


def lum(h):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)


def darken(h, k):
    h = h.lstrip('#')
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    hh, l, s = colorsys.rgb_to_hls(r, g, b)
    r, g, b = colorsys.hls_to_rgb(hh, l * (1 - k), s)
    return '#%02X%02X%02X' % (round(r * 255), round(g * 255), round(b * 255))


def L(shape, c1, symbol, sc=None, **kw):
    d = {"logo": True, "shape": shape, "field": "plain", "c1": c1, "c2": kw.pop("c2", "#FFFFFF"), "symbol": symbol, "border": kw.pop("border", "none")}
    if sc:
        d["sc"] = sc
    d.update(kw)
    return d


def metal_for(c1):
    """Ouro na maioria; prata quando o fundo é dourado/amarelo."""
    return SILVER if abs(lum(c1) - lum(GOLD)) < 0.22 or lum(c1) > 0.4 else GOLD


def deep(c1):
    """Fundo claro demais para o metal aparecer: escurece e devolve a cor original para o aro."""
    if lum(c1) > 0.35:
        return darken(c1, 0.55), c1
    return c1, None


FLAGS = {
    "ITA": ["#009246", "#FFFFFF", "#CE2B37"], "FRA": ["#0055A4", "#FFFFFF", "#EF4135"], "BEL": ["#1B1B1B", "#FDDA24", "#EF3340"],
    "GER": ["#1B1B1B", "#DD0000", "#FFCE00"], "NGA": ["#008751", "#FFFFFF", "#008751"], "SEN": ["#00853F", "#FDEF42", "#E31B23"],
    "PER": ["#D91023", "#FFFFFF", "#D91023"], "COL": ["#FCD116", "#003893", "#CE1126"], "ECU": ["#FFD100", "#034EA2", "#EF3340"],
    "BOL": ["#D52B1E", "#F9E300", "#007934"], "ROU": [], "IRL": [], "MEX": ["#006847", "#FFFFFF", "#CE1126"],
    "AUT": ["#ED2939", "#FFFFFF", "#ED2939"], "UKR": ["#0057B7", "#FFD700"], "ARG": ["#74ACDF", "#FFFFFF", "#74ACDF"],
    "URU": ["#FFFFFF", "#5CBFEB", "#FFFFFF", "#5CBFEB"], "VEN": ["#FFCC00", "#00247D", "#CF142B"], "CHI": ["#0039A6", "#FFFFFF", "#D52B1E"],
    "PAR": ["#D52B1E", "#FFFFFF", "#0038A8"], "CRO": ["#FF0000", "#FFFFFF", "#171796"], "SRB": ["#C6363C", "#0C4076", "#FFFFFF"],
    "CZE": ["#FFFFFF", "#D7141A", "#11457E"], "NED": ["#AE1C28", "#FFFFFF", "#21468B"], "RSA": ["#007749", "#FFB81C", "#DE3831", "#002395"],
    "EGY": ["#CE1126", "#FFFFFF", "#1B1B1B"], "UAE": ["#00732F", "#FFFFFF", "#1B1B1B"], "KOR": ["#CD2E3A", "#FFFFFF", "#0047A0"],
    "GRE": ["#0D5EAF", "#FFFFFF", "#0D5EAF"], "SUI": ["#DA291C", "#FFFFFF", "#DA291C"], "DEN": ["#C8102E", "#FFFFFF", "#C8102E"],
    "POR": ["#006600", "#FF0000"], "ESP": ["#AA151B", "#F1BF00", "#AA151B"], "BRA": ["#009C3B", "#FFDF00", "#002776"],
    "TUR": ["#E30A17", "#FFFFFF"], "SCO": ["#0065BD", "#FFFFFF", "#0065BD"], "ENG": ["#FFFFFF", "#CE1124", "#FFFFFF"],
    "MAR": ["#C1272D", "#006233", "#C1272D"], "TUN": ["#E70013", "#FFFFFF", "#E70013"], "KSA": ["#006C35", "#FFFFFF", "#006C35"],
    "JPN": ["#FFFFFF", "#BC002D", "#FFFFFF"], "CHN": ["#DE2910", "#FFDE00", "#DE2910"], "AUS": ["#012169", "#FFFFFF", "#E4002B"],
    "QAT": ["#8A1538", "#FFFFFF"], "USA": ["#B31942", "#FFFFFF", "#0A3161"],
}

logos = {}

# ---------------------------------------------------------------------------------------- Ligas
logos["ENG1"] = L("round", "#FFFFFF", "match_lion", "#37003C", c2="#FFFFFF", ring_c="#37003C", sym_scale=1.1, wordmark="PREMIER LEAGUE")
logos["ENG2"] = L("badge", "#0B1C3F", "lion_passant", "#D4AF37", ring_c="#D4AF37", sym_scale=1.15, wordmark="CHAMPIONSHIP")
logos["ESP1"] = L("tile", "#FF4B44", "match_ll", "#FFFFFF", wordmark="LALIGA")
logos["ESP2"] = L("tile", "#1B1B1B", "match_ll", "#FF4B44", num="2", accent="#FF4B44", wordmark="LALIGA")
logos["GER1"] = L("tile", "#D20515", "match_striker", "#FFFFFF", wordmark="BUNDESLIGA")
logos["GER2"] = L("tile", "#1B1B1B", "match_striker", "#FFFFFF", num="2", accent="#D20515", wordmark="BUNDESLIGA")
logos["ITA1"] = L("badge", "#FFFFFF", "match_a", "#187BD1", dc="#0A2D73", c2="#0A2D73", flag=FLAGS["ITA"], wordmark="SERIE A")
logos["ITA2"] = L("badge", "#0B7B3E", "match_b", "#FFFFFF", flag=FLAGS["ITA"], wordmark="SERIE B")
logos["FRA1"] = L("tile", "#091C3E", "match_hex", "#DAE025", num="1", accent="#DAE025", wordmark="LIGUE 1")
logos["FRA2"] = L("tile", "#0E3B7D", "match_hex", "#F28C28", num="2", accent="#F28C28", wordmark="LIGUE 2")
logos["POR1"] = L("round", "#00205B", "caravel", "#00C1D5", ring_c="#00C1D5", wordmark="LIGA PORTUGAL")
logos["POR2"] = L("round", "#1D3F91", "caravel", "#FFCC00", num="2", accent="#FFCC00", wordmark="LIGA PORTUGAL")
logos["NED1"] = L("tile", "#F36C21", "ball", "#FFFFFF", wordmark="EREDIVISIE")
logos["TUR1"] = L("round", "#E30A17", "crescent", "#FFFFFF", ring_c="#FFFFFF", wordmark="SÜPER LIG")
logos["BEL1"] = L("badge", "#1B1B1B", "lion", "#FDDA24", flag=FLAGS["BEL"], wordmark="PRO LEAGUE")
logos["SCO1"] = L("round", "#4B2C83", "lion", "#FFD100", ring_c="#FFD100", wordmark="PREMIERSHIP")
logos["GRE1"] = L("round", "#0D5EAF", "warrior", "#FFFFFF", ring_c="#FFFFFF", wordmark="SUPER LEAGUE")
logos["AUT1"] = L("tile", "#ED2939", "eagle", "#FFFFFF", wordmark="BUNDESLIGA")
logos["SUI1"] = L("tile", "#DA291C", "ball", "#FFFFFF", sym_top="cross_pattee", accent="#FFFFFF", wordmark="SUPER LEAGUE")
logos["UKR1"] = L("round", "#005BBB", "trident", "#FFD500", ring_c="#FFD500", wordmark="UPL")
logos["CRO1"] = L("badge", "#171796", "ball", "#FFFFFF", flag=["#FF0000", "#FFFFFF", "#FF0000", "#FFFFFF", "#FF0000"], wordmark="HNL")
logos["SRB1"] = L("badge", "#C6363C", "eagle", "#FFFFFF", flag=FLAGS["SRB"], wordmark="SUPERLIGA")
logos["CZE1"] = L("round", "#11457E", "lion", "#FFFFFF", ring_c="#D7141A", wordmark="CHANCE LIGA")
logos["DEN1"] = L("tile", "#C8102E", "lion", "#FFFFFF", sym_top="crown", accent="#FFFFFF", wordmark="SUPERLIGA")
logos["BRA1"] = L("badge", "#00A859", "trophy_tall", "#FFCC29", flag=FLAGS["BRA"], wordmark="BRASILEIRÃO")
logos["BRA2"] = L("badge", "#1C3F94", "trophy_tall", "#FFCC29", flag=FLAGS["BRA"], num="B", accent="#FFCC29", wordmark="BRASILEIRÃO")
logos["BRA3"] = L("badge", "#D35400", "trophy_tall", "#FFFFFF", flag=FLAGS["BRA"], num="C", accent="#FFFFFF", wordmark="BRASILEIRÃO")
logos["BRA4"] = L("badge", "#7B2D8E", "trophy_tall", "#FFFFFF", flag=FLAGS["BRA"], num="D", accent="#FFFFFF", wordmark="BRASILEIRÃO")
logos["BRA5"] = L("badge", "#5A6270", "ball", "#FFFFFF", flag=FLAGS["BRA"], wordmark="ESTADUAIS")
logos["ARG1"] = L("round", "#1D3F91", "sunrise", "#F6B40E", ring_c="#75AADB", flag=FLAGS["ARG"], wordmark="LPF")
logos["ARG2"] = L("round", "#75AADB", "sunrise", "#1D3F91", ring_c="#FFFFFF", num="2", accent="#1D3F91", wordmark="PRIMERA NAC.")
logos["URU1"] = L("round", "#0B2A5B", "sunrise", "#F6B40E", ring_c="#5CBFEB", wordmark="URUGUAYO")
logos["COL1"] = L("badge", "#003893", "ball", "#FFFFFF", flag=FLAGS["COL"], wordmark="LIGA BETPLAY")
logos["CHI1"] = L("round", "#0039A6", "star", "#FFFFFF", ring_c="#D52B1E", wordmark="PRIMERA")
logos["ECU1"] = L("badge", "#034EA2", "mountain", "#FFFFFF", flag=FLAGS["ECU"], wordmark="LIGAPRO")
logos["PER1"] = L("badge", "#D91023", "ball", "#FFFFFF", flag=["#FFFFFF", "#D91023", "#FFFFFF"], wordmark="LIGA 1")
logos["PAR1"] = L("badge", "#0B2A5B", "star", "#FFFFFF", flag=FLAGS["PAR"], wordmark="APF")
logos["BOL1"] = L("badge", "#007934", "mountain", "#F9E300", flag=FLAGS["BOL"], wordmark="PROFESIONAL")
logos["VEN1"] = L("tile", "#CF142B", "star", "#FFCC00", wordmark="LIGA FUTVE")
logos["MEX1"] = L("round", "#0A2240", "ball", "#FFFFFF", ring_c="#C5A572", wordmark="LIGA MX")
logos["USA1"] = L("badge", "#001F5B", "stars:3", "#FFFFFF", field="sash", fc="#E03A3E", wordmark="MLS")
logos["EGY1"] = L("round", "#CE1126", "eagle", GOLD, ring_c="#1B1B1B", wordmark="EPL")
logos["MAR1"] = L("round", "#C1272D", "star", "#FFFFFF", ring_c="#006233", wordmark="BOTOLA")
logos["TUN1"] = L("round", "#FFFFFF", "crescent", "#E70013", ring_c="#E70013", wordmark="LIGUE 1")
logos["RSA1"] = L("tile", "#007749", "ball", "#FFB81C", wordmark="PREMIERSHIP")
logos["NGA1"] = L("badge", "#008751", "eagle", "#FFFFFF", flag=FLAGS["NGA"], wordmark="NPFL")
logos["SEN1"] = L("round", "#00853F", "lion", "#FDEF42", ring_c="#E31B23", wordmark="LIGUE 1")
logos["KSA1"] = L("tile", "#0B6E4F", "swords", "#FFFFFF", sym_top="tree", accent="#FFFFFF", wordmark="PRO LEAGUE")
logos["JPN1"] = L("round", "#FFFFFF", "sunrise", "#E60012", ring_c="#E60012", wordmark="J1 LEAGUE")
logos["KOR1"] = L("round", "#0047A0", "tiger", "#FFFFFF", ring_c="#CD2E3A", wordmark="K LEAGUE 1")
logos["QAT1"] = L("tile", "#8A1538", "ball", "#FFFFFF", wordmark="STARS LEAGUE")
logos["UAE1"] = L("badge", "#00732F", "eagle", "#FFFFFF", flag=FLAGS["UAE"], wordmark="PRO LEAGUE")
logos["CHN1"] = L("round", "#DE2910", "dragon", "#FFDE00", ring_c="#FFDE00", wordmark="SUPER LEAGUE")
logos["AUS1"] = L("tile", "#1B1B1B", "letter", "#FF6B00", initials="A", sym_top="star", accent="#FF6B00", wordmark="A-LEAGUE")

# ---------------------------------------------------------------- Continentais e Mundial (marcas fortes)
logos["UCL"] = L("round", "#0B1F4B", "starball", "#FFFFFF", ring_c="#C9D6EA", wordmark="CHAMPIONS")
logos["UEL"] = L("round", "#1B1B1B", "trophy_ears", SILVER, ring_c="#F26B0F", wordmark="LIGA EUROPA")
logos["UECL"] = L("round", "#0A2E1F", "trophy_tall", SILVER, ring_c="#00A650", wordmark="CONFERÊNCIA")
logos["LIB"] = L("round", "#0A0A0A", "trophy_tall", "#E3B23C", c3="#E3B23C", ring_c="#E3B23C", laurel=True, wordmark="LIBERTADORES")
logos["SUD"] = L("round", "#003DA5", "trophy_lid", "#F5C400", ring_c="#F5C400", wordmark="SUL-AMERICANA")
logos["CCC"] = L("round", "#1F3A93", "trophy_ears", SILVER, ring_c="#F2F2F2", wordmark="CONCACAF")
logos["CAF"] = L("round", "#0B6E4F", "trophy_ears", "#F2C14E", ring_c="#F2C14E", wordmark="ÁFRICA")
logos["AFC"] = L("round", "#3C0F5E", "trophy", "#E0C3FC", ring_c="#E0C3FC", wordmark="ÁSIA")
logos["CWC"] = L("round", "#14213D", "globe", GOLD, ring_c=GOLD, c3=GOLD, laurel=True, wordmark="MUNDIAL")

# ------------------------------------------------------------------ Estaduais e regionais do Brasil
# Escudo de competição com o desenho da bandeira do estado e faixa com o nome
def state(c1, field, symbol, sc, ribbon, **kw):
    d = {"logo": True, "shape": "badge", "field": field, "c1": c1, "c2": kw.pop("c2", "#FFFFFF"), "symbol": symbol, "sc": sc,
         "border": "gold", "c3": kw.pop("c3", GOLD), "ribbon": ribbon}
    d.update(kw)
    return d
logos["SPE"] = state("#FFFFFF", "stripes:7", "star", "#E30613", "PAULISTÃO", fc="#111111", canton="#E30613", canton_sym="star", symbol_none=True)
logos["RJE"] = state("#0055A4", "plain", "mountain", "#FFFFFF", "CARIOCA", sym_top="sunrise", accent="#FFD100")
logos["MGE"] = state("#FFFFFF", "plain", "mountain", "#E30613", "MINEIRO", c2="#E30613")
logos["RSE"] = state("#009B3A", "sash", "star", "#FFFFFF", "GAUCHÃO", fc="#E30613", c3="#FFD100")
logos["PRE"] = state("#00843D", "sash_r", "southern_cross", "#FFFFFF", "PARANAENSE", fc="#FFFFFF", sc_c="#00843D")
logos["SCE"] = state("#FFFFFF", "hoops:3", "star", "#2E8B3A", "CATARINENSE", fc="#C8102E")
logos["CEE"] = state("#2E8B3A", "plain", "sunrise", "#FFD100", "CEARENSE", border="gold")
logos["GOE"] = state("#006437", "stripes:5", "southern_cross", "#FFFFFF", "GOIANÃO", fc="#FFD100", plate="none")
logos["NOR"] = L("round", "#1B3A8C", "sunrise", "#F07F13", ring_c="#F07F13", wordmark="NORDESTÃO")
logos["VER"] = L("round", "#2E7D32", "tree", "#FFD100", ring_c="#FFD100", wordmark="COPA VERDE")

# --------------------------------------------------------------------------- Copas nacionais
dom = json.load(open(ROOT + "/data/world/domestic.json"))["cups"]
con = json.load(open(ROOT + "/data/world/continental.json"))["cups"]
intl = json.load(open(ROOT + "/data/world/international.json"))["tournaments"]

CUP_TROPHY = {
    "FAC": "trophy", "CDR": "trophy_lid", "CIT": "trophy_lid", "DFB": "trophy_ears", "CDF": "trophy_tall", "TDP": "trophy_lid",
    "KNV": "trophy", "TKK": "trophy_ears", "BEC": "trophy", "SCC": "trophy", "GRC": "trophy_lid", "OFB": "trophy_ears",
    "SUC": "trophy", "UKC": "trophy_lid", "CRC": "trophy", "SRC": "trophy_lid", "CZC": "trophy", "DBU": "trophy_lid",
    "CDB": "trophy_tall", "CAR": "trophy", "CAU": "trophy_lid", "CCO": "trophy_tall", "CCH": "trophy", "CEC": "trophy_tall",
    "CPE": "trophy_lid", "CPY": "trophy", "CBO": "trophy_tall", "CVE": "trophy_lid", "USO": "trophy", "EGC": "trophy_ears",
    "CDT": "trophy_lid", "CTN": "trophy", "NDB": "trophy_ears", "NFC": "trophy", "CSN": "trophy_lid", "KSC": "trophy_lid",
    "EMP": "trophy_ears", "KRC": "trophy", "EMC": "trophy_lid", "UPC": "trophy", "CFA": "trophy_ears", "AUC": "trophy",
}
SUPER_TROPHY = ["trophy_ears", "trophy_lid", "trophy", "trophy_tall"]
for i, (cid, cfg) in enumerate(dom.items()):
    if cid in logos:
        continue
    c1, c2 = cfg["colors"][0], cfg["colors"][1]
    kind = cfg.get("kind", "national")
    name = cfg.get("name", cid).upper()
    short = cfg.get("short", cid).upper()
    word = name if len(name) <= 15 else short
    light = lum(c1) > 0.35
    # Fundo claro (amarelo, celeste): taça na segunda cor; fundo escuro: taça de metal
    metal = (c2 if abs(lum(c2) - lum(c1)) > 0.3 else INK) if light else metal_for(c1)
    ring = c2 if abs(lum(c2) - lum(c1)) > 0.2 else GOLD
    if kind == "super":
        # Supercopa: escudo com a taça e uma estrela em cima, faixa com as cores do país
        logos[cid] = L("badge", c1, SUPER_TROPHY[i % len(SUPER_TROPHY)], metal, sym_top="star", accent=metal, wordmark=word)
    elif kind == "league_cup":
        logos[cid] = L("tile", c1, "trophy_lid", metal, wordmark=word)
    else:
        logos[cid] = L("round", c1, CUP_TROPHY.get(cid, "trophy"), metal, ring_c=ring, wordmark=word)

# FA Cup e Copa do Rei com o nome conhecido; Copa do Brasil com o dourado da CBF
logos["FAC"]["ring_c"] = "#FFFFFF"
# Copas do rei, do trono e do emir: coroa em cima da taça
for cid in ("CDR", "KSC", "CDT", "EMC"):
    logos[cid].update({"sym_top": "crown", "accent": logos[cid]["sc"]})
# Coppa Italia e Coupe de France: placa com a faixa da bandeira, como a marca de verdade
logos["CIT"].update({"shape": "tile", "flag": FLAGS["ITA"]})
logos["CIT"].pop("ring_c", None)
logos["CDF"].update({"shape": "tile", "flag": FLAGS["FRA"]})
logos["CDF"].pop("ring_c", None)
logos["CDB"].update({"sc": GOLD, "ring_c": "#F2C230"})
logos["CSH"] = L("badge", "#C8102E", "trophy_plate", SILVER, wordmark="COMMUNITY SHIELD")
logos["USC"] = L("round", "#0B1F4B", "trophy_ears", SILVER, sym_top="star", accent=GOLD, ring_c=GOLD, wordmark="SUPERCOPA")
logos["REC"] = L("round", "#0A0A0A", "trophy_tall", "#E3B23C", sym_top="star", accent="#E3B23C", ring_c="#E3B23C", wordmark="RECOPA")
logos["CPC"] = L("round", "#1F3A93", "trophy", GOLD, sym_top="star", accent=GOLD, ring_c=GOLD, wordmark="CAMPEONES CUP")

# --------------------------------------------------------------------------- Seleções
logos["WC"] = L("round", "#14213D", "trophy_globe", GOLD, ring_c=GOLD, wordmark="COPA DO MUNDO")
logos["EURO"] = L("round", "#143CDB", "trophy_ears", SILVER, ring_c="#DCE4FF", wordmark="EUROCOPA")
logos["CA"] = L("round", "#0B2A5B", "trophy_tall", SILVER, ring_c="#E3C15A", wordmark="COPA AMÉRICA")
logos["AFCON"] = L("round", "#0B6E4F", "trophy_ears", "#F2C14E", ring_c="#F2C14E", wordmark="COPA AFRICANA")
logos["ASIAN"] = L("round", "#3C0F5E", "trophy_lid", SILVER, ring_c="#E0C3FC", wordmark="COPA DA ÁSIA")
logos["GOLD"] = L("round", "#1F3A93", "trophy", "#F2C14E", ring_c="#F2C14E", wordmark="COPA OURO")
logos["OFC"] = L("round", "#163E77", "trophy", SILVER, ring_c="#FFFFFF", wordmark="OCEANIA")
logos["UNL"] = L("round", "#15366B", "trophy_tall", SILVER, ring_c="#E1E5ED", wordmark="NATIONS LEAGUE")
logos["CNL"] = L("round", "#15366B", "trophy_plate", GOLD, ring_c="#E1E5ED", wordmark="NATIONS LEAGUE")

# Limpeza: chaves auxiliares
for k, v in logos.items():
    for aux in ("symbol_none", "sc_c"):
        v.pop(aux, None)
logos["SPE"]["symbol"] = "none"

p = ROOT + "/data/world/identity.json"
data = json.load(open(p))
old = data.get("logos", {})
for k, v in old.items():
    if k not in logos:
        logos[k] = v
        print("mantido:", k)
data["logos"] = logos
# Este gerador é dono só de "logos". Preserva documentação, placares e pacotes de TV.
open(p, "w").write(json.dumps(data, ensure_ascii=False, indent='\t') + '\n')
print("logos:", len(logos))
