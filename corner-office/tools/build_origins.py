"""Gera game/content/origins.json: grupos culturais por país (cidades, população facial,
artes marciais, personalidade) + pools de nomes de tools/origins_names.py.
Uso: python3 tools/build_origins.py"""
import json, os
exec(open(os.path.join(os.path.dirname(__file__), "origins_names.py"), encoding="utf-8").read())

G = {}
def g(country, gid, name, weight, pops, cities, first, last=None, **extra):
    d = {"id": gid, "name": name, "weight": weight, "populations": pops,
         "cities": [c.strip() for c in cities.split("|")], "first": first, "last": last or first}
    d.update(extra)
    G.setdefault(country, []).append(d)

# Brasil
g("BR", "br_sul_sudeste", "Sul e Sudeste", 5, {"latino": 3, "mediterraneo": 2, "europa_norte": 0.8, "afro_diaspora": 1.2},
  "Curitiba|São Paulo|Porto Alegre|Belo Horizonte|Florianópolis|Campinas|Santos|Londrina|Joinville|Ribeirão Preto|Juiz de Fora|Caxias do Sul", "pt_br")
g("BR", "br_norte_nordeste", "Norte e Nordeste", 4, {"afro_diaspora": 3, "latino": 3, "andino": 0.6},
  "Salvador|Natal|Manaus|Recife|Fortaleza|Belém|João Pessoa|Teresina|Maceió|São Luís|Aracaju|Macapá", "pt_br")
g("BR", "br_rio", "Rio de Janeiro", 2, {"afro_diaspora": 2.5, "latino": 2.5, "mediterraneo": 1},
  "Rio de Janeiro|Niterói|Duque de Caxias|Nova Iguaçu|São Gonçalo|Petrópolis", "pt_br")
# EUA
g("US", "us_white", "Americano branco", 4, {"europa_norte": 5, "mediterraneo": 1.5, "leste_europeu": 0.6},
  "Denver|Columbus|Omaha|Milwaukee|Boise|Sacramento|Tampa|Iowa City|Pittsburgh|Nashville|Albany|Salt Lake City|Spokane|Kansas City", "en_us")
g("US", "us_black", "Afro-americano", 3.5, {"afro_diaspora": 1},
  "Atlanta|Philadelphia|Detroit|Chicago|Houston|Memphis|Baltimore|Oakland|Newark|New Orleans|Cleveland|Charlotte", "african_american",
  disciplines_bonus={"boxing": 2.0, "folkstyle_wrestling": 1.3})
g("US", "us_hispanic", "Latino dos EUA", 2, {"latino": 3, "andino": 1},
  "San Antonio|Los Angeles|El Paso|Phoenix|Miami|Fresno|Albuquerque|Houston|Denver|San Diego", "es_us", "es_mx",
  disciplines_bonus={"boxing": 1.8})
g("US", "us_asian", "Ásio-americano", 0.5, {"leste_asiatico": 3, "sudeste_asiatico": 1.5, "sul_asiatico": 0.8},
  "San Jose|Seattle|Honolulu|Nova York|Los Angeles|Houston", "en_us", "asian_us_last")
g("US", "us_pacific", "Havaiano e das ilhas", 0.25, {"polinesia": 1}, "Honolulu|Hilo|Salt Lake City|Oakland|Kahului", "pacific")
g("US", "us_arab", "Árabe-americano", 0.3, {"oriente_medio": 1}, "Dearborn|Chicago|Nova York|Paterson|Anaheim", "arab")
# México
g("MX", "mx_mestizo", "Mestiço", 6, {"latino": 6, "mediterraneo": 1},
  "Monterrey|Tijuana|Guadalajara|Hermosillo|León|Chihuahua|Ciudade do México|Culiacán|Mexicali|Toluca|Querétaro|Aguascalientes", "es_mx")
g("MX", "mx_sul", "Sul indígena", 2, {"andino": 3, "latino": 1},
  "Oaxaca|Puebla|Mérida|Tuxtla Gutiérrez|Villahermosa|Cancún|Campeche", "es_mx")
# Reino Unido
g("GB", "gb_white", "Britânico", 6, {"europa_norte": 1},
  "Manchester|Liverpool|Birmingham|Leeds|Glasgow|Cardiff|Bristol|Newcastle|Sheffield|Nottingham|Swansea|Edimburgo|Aberdeen|Belfast", "en_uk")
g("GB", "gb_black", "Britânico negro", 1.7, {"afro_diaspora": 1.5, "africa_ocidental": 0.9},
  "Londres|Birmingham|Manchester|Croydon|Leeds|Nottingham", "black_british")
g("GB", "gb_south_asian", "Britânico sul-asiático", 1, {"sul_asiatico": 1}, "Bradford|Leicester|Birmingham|Londres|Luton|Blackburn", "pakistani")
g("GB", "gb_arab", "Britânico árabe", 0.4, {"oriente_medio": 1}, "Londres|Manchester|Sheffield|Liverpool", "arab")
# Irlanda
g("IE", "ie", "Irlandês", 1, {"europa_norte": 1}, "Dublin|Cork|Galway|Limerick|Waterford|Drogheda|Sligo|Kilkenny", "irish")
# França
g("FR", "fr_french", "Francês", 4, {"mediterraneo": 2, "europa_norte": 2},
  "Lyon|Toulouse|Nice|Lille|Bordeaux|Nantes|Rennes|Montpellier|Grenoble|Strasbourg|Dijon|Brest", "fr_fr",
  disciplines_bonus={"savate": 1.6, "judo": 1.3})
g("FR", "fr_maghreb", "Franco-magrebino", 1.5, {"oriente_medio": 1}, "Marselha|Paris|Lyon|Saint-Denis|Roubaix|Nice", "maghrebi",
  disciplines_bonus={"kickboxing": 1.5, "boxing": 1.4})
g("FR", "fr_african", "Franco-africano", 1.5, {"africa_ocidental": 1}, "Paris|Saint-Denis|Évry|Marselha|Lyon|Créteil", "west_african_fr")
# Polônia
g("PL", "pl", "Polonês", 1, {"leste_europeu": 1}, "Cracóvia|Wrocław|Gdańsk|Poznań|Łódź|Varsóvia|Lublin|Katowice|Szczecin|Olsztyn|Opole", "polish")
# Japão, Coreia, China
g("JP", "jp", "Japonês", 1, {"leste_asiatico": 1}, "Osaka|Tóquio|Nagoya|Fukuoka|Sapporo|Kobe|Yokohama|Hiroshima|Sendai|Chiba|Kyoto|Okinawa", "japanese",
  personality={"technician": 2, "humble_worker": 2, "warrior_code": 1.5, "silent_killer": 1.5})
g("KR", "kr", "Coreano", 1, {"leste_asiatico": 1}, "Seul|Busan|Incheon|Daegu|Gwangju|Daejeon|Ulsan|Suwon|Jeju", "korean")
g("CN", "cn_han", "Chinês han", 1, {"leste_asiatico": 1}, "Chengdu|Pequim|Xangai|Kunming|Harbin|Wuhan|Shenzhen|Xi'an|Guangzhou|Zhengzhou|Changsha|Qingdao", "chinese")
# Cazaquistão
g("KZ", "kz_kazakh", "Cazaque", 4, {"asia_central": 1}, "Almaty|Astana|Shymkent|Taraz|Kyzylorda|Aktobe|Atyrau|Turkistan", "kazakh")
g("KZ", "kz_russian", "Russo do Cazaquistão", 1, {"leste_europeu": 1}, "Karaganda|Pavlodar|Oskemen|Petropavl|Kostanay", "russian")
# Geórgia
g("GE", "ge", "Georgiano", 1, {"caucaso": 1}, "Tbilisi|Batumi|Kutaisi|Rustavi|Zugdidi|Gori|Telavi|Poti", "georgian",
  personality={"warrior_code": 2, "local_hero": 1.5})
# Austrália e Nova Zelândia
g("AU", "au_anglo", "Australiano", 5, {"europa_norte": 1}, "Sydney|Brisbane|Perth|Adelaide|Gold Coast|Melbourne|Newcastle|Townsville|Hobart|Geelong", "anglo_au_first", "en_uk")
g("AU", "au_med", "Australiano mediterrâneo", 1, {"mediterraneo": 3, "oriente_medio": 1}, "Melbourne|Sydney|Adelaide|Wollongong", "med_au")
g("AU", "au_pacific", "Australiano das ilhas", 1, {"polinesia": 1}, "Sydney|Brisbane|Logan|Ipswich", "pacific")
g("AU", "au_asian", "Ásio-australiano", 0.6, {"leste_asiatico": 2, "sudeste_asiatico": 1}, "Sydney|Melbourne|Perth", "anglo_au_first", "asian_us_last")
g("NZ", "nz_pakeha", "Neozelandês", 3, {"europa_norte": 1}, "Auckland|Wellington|Christchurch|Hamilton|Dunedin|Tauranga", "en_uk")
g("NZ", "nz_maori", "Maori e pasifika", 3, {"polinesia": 1}, "Auckland|Rotorua|Gisborne|Whangārei|Porirua|Hamilton", "maori")
# Nigéria, Camarões, Senegal
g("NG", "ng_yoruba", "Iorubá", 1.2, {"africa_ocidental": 1}, "Lagos|Ibadan|Abeokuta|Oshogbo|Akure|Ilorin", "yoruba")
g("NG", "ng_igbo", "Igbo", 1, {"africa_ocidental": 1}, "Enugu|Onitsha|Owerri|Aba|Awka|Port Harcourt", "igbo")
g("NG", "ng_hausa", "Hauçá", 1, {"africa_ocidental": 1}, "Kano|Kaduna|Abuja|Sokoto|Zaria|Katsina", "hausa",
  disciplines_bonus={"boxing": 1.6})
g("CM", "cm", "Camaronês", 1, {"africa_ocidental": 3, "africa_oriental": 1}, "Douala|Yaoundé|Bafoussam|Garoua|Bamenda|Maroua|Limbe", "cameroon")
g("SN", "sn", "Senegalês", 1, {"africa_ocidental": 1}, "Dakar|Thiès|Saint-Louis|Ziguinchor|Kaolack|Mbour|Touba|Rufisque", "west_african_fr")
# Sudeste asiático
g("TH", "th", "Tailandês", 1, {"sudeste_asiatico": 1}, "Bangkok|Chiang Mai|Buriram|Khon Kaen|Nakhon Ratchasima|Phuket|Udon Thani|Pattaya|Surin|Ubon Ratchathani", "thai")
g("PH", "ph", "Filipino", 1, {"sudeste_asiatico": 1}, "Manila|Cebu|Baguio|Davao|Iloilo|General Santos|Bacolod|Cagayan de Oro", "filipino")
# Cuba
g("CU", "cu", "Cubano", 1, {"latino": 3, "afro_diaspora": 3, "mediterraneo": 0.5}, "Havana|Santiago de Cuba|Camagüey|Holguín|Pinar del Río|Cienfuegos|Guantánamo|Matanzas", "es_cu")
# Holanda, Suécia
g("NL", "nl_dutch", "Holandês", 4, {"europa_norte": 1}, "Amsterdã|Roterdã|Utrecht|Eindhoven|Haia|Groningen|Breda|Tilburg|Nijmegen", "dutch")
g("NL", "nl_moroccan", "Marroquino-holandês", 2, {"oriente_medio": 1}, "Amsterdã|Roterdã|Utrecht|Haia|Gouda", "maghrebi",
  disciplines_bonus={"kickboxing": 2.0})
g("NL", "nl_surinamese", "Surinamês-holandês", 2, {"afro_diaspora": 1}, "Amsterdã|Roterdã|Haia|Almere|Paramaribo", "surinamese",
  disciplines_bonus={"kickboxing": 2.0})
g("SE", "se_swedish", "Sueco", 5, {"europa_norte": 1}, "Estocolmo|Gotemburgo|Malmö|Uppsala|Örebro|Umeå|Västerås|Linköping", "swedish")
g("SE", "se_arab", "Sueco do Oriente Médio", 1, {"oriente_medio": 1}, "Malmö|Estocolmo|Gotemburgo|Södertälje", "arab")
g("SE", "se_somali", "Sueco-somali", 0.5, {"africa_oriental": 1}, "Estocolmo|Gotemburgo|Örebro", "somali")
# Rússia
g("RU", "ru_dagestan", "Daguestanês", 3, {"caucaso": 1},
  "Makhachkala|Khasavyurt|Kaspiysk|Derbent|Buynaksk|Kizlyar|Izberbash|Gunib", "dagestani",
  disciplines={"freestyle_wrestling": 6, "combat_sambo": 3, "sambo": 2, "mma": 2.5, "sanda": 1.2, "judo": 0.8, "boxing": 0.6, "greco_roman": 0.8},
  personality={"warrior_code": 3.5, "silent_killer": 2, "humble_worker": 2, "family_man": 1.5, "showman": 0.3})
g("RU", "ru_chechnya", "Checheno", 1.5, {"caucaso": 1}, "Grozny|Gudermes|Argun|Shali|Urus-Martan|Nazran", "chechen",
  disciplines={"freestyle_wrestling": 5, "boxing": 2, "kickboxing": 1.5, "mma": 2.5, "combat_sambo": 1.5, "greco_roman": 0.8},
  personality={"warrior_code": 3, "silent_killer": 2, "hothead": 1.2, "showman": 0.4})
g("RU", "ru_russian", "Russo", 3, {"leste_europeu": 1},
  "Moscou|São Petersburgo|Yekaterinburg|Krasnodar|Novosibirsk|Rostov-on-Don|Omsk|Stary Oskol|Chelyabinsk|Samara|Voronezh|Perm", "russian",
  disciplines={"sambo": 3, "boxing": 3, "kickboxing": 2, "combat_sambo": 2.5, "mma": 1.5, "judo": 1, "karate_kyokushin": 0.8, "greco_roman": 0.8})
g("RU", "ru_tatar", "Tártaro e bashkir", 1, {"leste_europeu": 1, "asia_central": 1}, "Kazan|Ufa|Naberezhnye Chelny|Almetyevsk|Sterlitamak", "tatar",
  disciplines={"kazakh_kuresi": 2, "sambo": 2, "freestyle_wrestling": 2, "judo": 1.5, "boxing": 1, "mma": 1})
g("RU", "ru_siberia", "Iacute e buriato", 0.6, {"asia_central": 1}, "Yakutsk|Ulan-Ude|Kyzyl|Chita|Mirny", "siberian",
  disciplines={"freestyle_wrestling": 5, "boxing": 1.5, "sambo": 1.5, "mma": 1})
# Índia
g("IN", "in_north", "Punjabi e haryanvi", 2, {"sul_asiatico": 1}, "Chandigarh|Rohtak|Bhiwani|Sonipat|Amritsar|Ludhiana|Jalandhar|Patiala", "south_asian",
  disciplines={"freestyle_wrestling": 4, "pehlwani": 3, "boxing": 2.5, "judo": 0.5, "mma": 1})
g("IN", "in_urban", "Indiano urbano", 2, {"sul_asiatico": 1}, "Délhi|Mumbai|Pune|Bangalore|Hyderabad|Chennai|Kochi|Kolkata|Imphal", "south_asian")
# Canadá
g("CA", "ca_anglo", "Canadense anglófono", 4, {"europa_norte": 1}, "Toronto|Calgary|Winnipeg|Vancouver|Edmonton|Halifax|Ottawa|Regina|Saskatoon", "en_us", "en_uk")
g("CA", "ca_quebec", "Quebequense", 2, {"europa_norte": 3, "mediterraneo": 1}, "Montreal|Quebec|Laval|Gatineau|Sherbrooke|Trois-Rivières", "fr_ca")
g("CA", "ca_black", "Canadense negro", 0.8, {"afro_diaspora": 1}, "Toronto|Montreal|Brampton|Ottawa", "black_british")
g("CA", "ca_asian", "Canadense asiático", 1, {"leste_asiatico": 2, "sul_asiatico": 2}, "Vancouver|Toronto|Richmond|Brampton|Surrey", "en_us", "asian_us_last")


used = set()
for groups in G.values():
    for grp in groups:
        used.add(grp["first"]); used.add(grp["last"])
missing = used - set(P)
assert not missing, missing
out = {
    "_note": "Origens dos atletas (Game Design Bible §§4,5): cada país tem grupos culturais com peso, cidades, população facial (content/fighter_generation.json → population_names) e pools de nome. 'first'/'last' apontam para name_pools; 'disciplines' substitui as artes do país e 'disciplines_bonus' multiplica. 'personality' pondera arquétipos (content/personalities.json). Nomes são comuns e as combinações são fictícias.",
    "surname_rules": {
        "slavic": [["skiy", "skaya"], ["sky", "skaya"], ["ov", "ova"], ["ev", "eva"], ["yev", "yeva"], ["in", "ina"]],
        "polish": [["ski", "ska"], ["cki", "cka"], ["dzki", "dzka"]],
        "kazakh": [["uly", "kyzy"], ["ov", "ova"], ["ev", "eva"], ["in", "ina"]],
    },
    "countries": G,
    "name_pools": {k: P[k] for k in sorted(used)},
}
path = os.path.join(os.path.dirname(__file__), "..", "game", "content", "origins.json")
import re
text = json.dumps(out, ensure_ascii=False, indent=1)
text = re.sub(r'\[\n\s*("(?:[^"\\]|\\.)*"(?:,\n\s*"(?:[^"\\]|\\.)*")*)\n\s*\]', lambda m: "[" + re.sub(r",\n\s*", ", ", m.group(1)) + "]", text)
open(path, "w").write(text + "\n")
print(sum(len(v) for v in G.values()), "grupos,", len(out["name_pools"]), "pools")
