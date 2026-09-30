"""Pessoas históricas do universo (Game Design Bible §§2, 13–14). Tudo fictício.

NAME_POOLS alimentam os campeões gerados de 1991–2026. LEGENDS são figuras
autorais com lugar fixo na história; PINNED_REIGNS prende seus reinados (e os
do roster canônico de 2027) nas linhagens de cinturão.
"""

# país -> (nomes masculinos, nomes femininos, sobrenomes, idioma dos apelidos)
NAME_POOLS = {
    "US": (["Tyrell", "Brandon", "Cody", "Dustin", "Marcus", "Jarrod", "Wade", "Travis", "Derek", "Rashad", "Clay", "Bo", "Kyle", "Dante", "Luke", "Garrett", "Terrell", "Shane"],
           ["Kayla", "Brianna", "Shannon", "Tasha", "Megan", "Alexis", "Jordyn", "Raven", "Kelsey", "Destiny"],
           ["Harlan", "Whitaker", "Boone", "McAllister", "Graves", "Pruitt", "Dawson", "Rollins", "Tanner", "Coleman", "Haskins", "Brooks", "Fletcher", "Crowder", "Maddox", "Sutton", "Keller", "Price", "Vance", "Holt"], "en"),
    "CA": (["Mathieu", "Olivier", "Tristan", "Jean-Luc", "Connor", "Gabriel", "Rémi", "Evan"],
           ["Émilie", "Chloé", "Maude", "Kristen", "Geneviève"],
           ["Tremblay", "Gagnon", "Côté", "Bouchard", "Pelletier", "MacLeod", "Fraser", "Lavoie", "Roy", "Gauthier"], "en"),
    "BR": (["Anderson", "Wellington", "Cleiton", "Edson", "Jailton", "Ronaldo", "Maurício", "Fabrício", "Gilberto", "Douglas", "Renan", "Ubiratan", "Rogério", "Josué", "Adriano", "Cícero", "Wanderson", "Luciano"],
           ["Juliana", "Amanda", "Priscila", "Viviane", "Jéssica", "Cláudia", "Taís", "Raquel", "Bianca", "Lorena"],
           ["Farias", "Nóbrega", "Bezerra", "Cavalcante", "Pimentel", "Assunção", "Freitas", "Teixeira", "Barros", "Carvalho", "Queiroz", "Rocha", "Lacerda", "Magalhães", "Brandão", "Siqueira", "Aragão", "Macedo", "Pacheco", "Vilela"], "pt"),
    "MX": (["Érik", "Jorge", "Ricardo", "Brandon", "Yair", "Alejandro", "Iván", "Héctor", "Saúl", "Efraín", "Octavio", "Rodrigo"],
           ["Alexa", "Irene", "Yazmín", "Lupita", "Montserrat", "Ximena"],
           ["Castañeda", "Villalobos", "Guerrero", "Ramírez", "Zamora", "Ocampo", "Tapia", "Salcedo", "Arriaga", "Medina", "Barajas", "Lozano"], "es"),
    "AR": (["Santiago", "Facundo", "Nahuel", "Martín", "Agustín", "Emiliano"], ["Florencia", "Camila", "Lucía"],
           ["Ibarra", "Coronel", "Sosa", "Aguirre", "Villegas", "Paz"], "es"),
    "PE": (["Renzo", "Joaquín", "Piero", "Claudio"], ["Valeria", "Milagros"], ["Quispe", "Huamán", "Chávez", "Vargas", "Rojas"], "es"),
    "GB": (["Liam", "Callum", "Darren", "Jamie", "Reece", "Tom", "Nathan", "Harvey", "Owen", "Kieran", "Stuart", "Ashley"],
           ["Molly", "Chelsea", "Rosie", "Leah", "Gemma", "Stacey"],
           ["Whitfield", "Barnes", "Ashworth", "Pickering", "Gallagher", "Denholm", "Crossley", "Hartley", "Rudd", "Kenworthy", "Blythe", "Marsh"], "en"),
    "IE": (["Conor", "Declan", "Ciarán", "Padraig", "Eoin"], ["Aoife", "Siobhán", "Niamh"], ["Ó Briain", "Doherty", "Keane", "Mulligan", "Quinlan", "Fitzgerald"], "en"),
    "NL": (["Remy", "Jeroen", "Bas", "Tyrone", "Joost", "Melvin"], ["Femke", "Sanne", "Lotte"], ["van Dijk", "de Graaf", "Hoekstra", "Bakker", "Visser", "Kuipers", "Zwart"], "en"),
    "FR": (["Florian", "Nassim", "Mathis", "Karim", "Anthony", "Yoann"], ["Manon", "Léa", "Inès"], ["Lemaire", "Doré", "Rousseau", "Benali", "Fournier", "Delacroix"], "fr"),
    "PL": (["Mariusz", "Krzysztof", "Mateusz", "Łukasz", "Tomasz", "Kamil", "Paweł"], ["Natalia", "Karolina", "Agnieszka", "Marta"],
           ["Kowalczyk", "Nowak", "Wróbel", "Zieliński", "Szymański", "Dąbrowski", "Pawlak", "Mazur"], "pl"),
    "RS": (["Miloš", "Nemanja", "Dušan", "Stefan", "Vuk"], ["Jelena", "Milica", "Ivana"], ["Jović", "Petrović", "Stanković", "Ilić", "Marković-Lazić", "Radovanović"], "en"),
    "HR": (["Ante", "Mirko", "Luka", "Ivan"], ["Petra", "Ana"], ["Filipović", "Šarić", "Babić", "Kovač"], "en"),
    "SE": (["Johan", "Alexander", "Niklas", "Oskar"], ["Ellinor", "Frida"], ["Lindqvist", "Berg", "Sandström", "Ekholm"], "en"),
    "RU": (["Aleksei", "Fedor", "Rustam", "Ruslan", "Timur", "Vadim", "Sergei", "Islam", "Zaur", "Magomed-Shapi", "Artem"],
           ["Yana", "Olga", "Valentina", "Irina", "Marina"],
           ["Vlasov", "Emelin", "Gadzhiev", "Nurmatov", "Abdulaev", "Kurbanov", "Zubairov", "Orlov", "Belov", "Temirov", "Saidov", "Makarov"], "ru"),
    "KZ": (["Nurlan", "Yerlan", "Azamat", "Daulet", "Kairat", "Arman"], ["Aigerim", "Madina", "Dana"], ["Zhakupov", "Nurgaliyev", "Tokhtarov", "Seitkali", "Abenov", "Bekov"], "ru"),
    "GE": (["Giorgi", "Levan", "Zviad", "Merab", "Irakli"], ["Nino", "Tamar"], ["Chikovani", "Beridze", "Gelashvili", "Tsiklauri", "Maisuradze"], "ru"),
    "UZ": (["Bakhodir", "Jasur", "Sardor", "Otabek"], ["Dilnoza", "Shahnoza"], ["Rakhimov", "Tursunov", "Ergashev", "Karimov"], "ru"),
    "AZ": (["Rashad", "Elvin", "Tural"], ["Leyla"], ["Aliyev", "Mammadli", "Huseynov"], "ru"),
    "JP": (["Kazuo", "Takeshi", "Hiroshi", "Ryo", "Shinya", "Yuki", "Daisuke", "Masato", "Kiyoshi", "Tetsuya", "Genki", "Hayato"],
           ["Ayaka", "Misaki", "Rena", "Yui", "Kanna", "Megumi"],
           ["Kurogane", "Tanabe", "Hayashida", "Morimoto", "Kawase", "Ishida", "Nakamura", "Fujita", "Okuda", "Shimizu", "Takeuchi", "Wada"], "ja"),
    "KR": (["Min-ho", "Hyun-woo", "Jae-won", "Seung-woo", "Tae-yang"], ["Ji-yeon", "Seo-hee", "Da-eun"], ["Kim", "Park", "Choi", "Jung", "Kang", "Yoon"], "en"),
    "CN": (["Wei", "Jianguo", "Hao", "Zhen", "Long"], ["Xiaoli", "Mei", "Yan"], ["Zhang", "Li", "Wang", "Liu", "Chen", "Song"], "en"),
    "MN": (["Batbayar", "Tumur", "Ganzorig"], ["Oyuna"], ["Enkhbold", "Dorj", "Baatar"], "en"),
    "PH": (["Eduard", "Joshua", "Kevin", "Honorio"], ["Denice", "Jenny"], ["Dimaculangan", "Villarosa", "Magbanua", "Tolentino", "Buenaflor"], "en"),
    "TH": (["Kongsak", "Thanawat", "Suriya", "Apichai"], ["Pimchanok", "Waraporn"], ["Sor Thanachai", "Kiatphayak", "Sitsongsaeng", "Por Pramuk"], "en"),
    "AU": (["Declan", "Jai", "Tyson", "Brodie", "Mitch", "Cam"], ["Bec", "Jess", "Holly", "Tahlia"], ["Moss", "Lawlor", "Burke", "Hooper", "Kinnear", "Doyle"], "en"),
    "NZ": (["Wiremu", "Kai", "Tane", "Mikaere"], ["Aroha", "Kiri"], ["Tupou", "Rangi", "Ngata", "Wharepapa"], "en"),
    "NG": (["Kelechi", "Chidi", "Emeka", "Obinna", "Tunde"], ["Ngozi", "Adaeze"], ["Okafor", "Adeyemi", "Eze", "Balogun", "Nwosu"], "en"),
    "CM": (["Aurélien", "Arnaud", "Serge"], ["Christelle"], ["Nkoulou", "Mbarga", "Etoundi"], "fr"),
    "ZA": (["Pieter", "Sipho", "Thabo"], ["Lerato"], ["du Toit", "Mokoena", "van der Merwe"], "en"),
    "TR": (["Emre", "Burak", "Ali"], ["Elif"], ["Yıldız", "Demir", "Şahin"], "en"),
}

NICKNAMES = {
    "pt": ["Tigre", "Furacão", "Trator", "Carrasco", "Monstro", "Cangaceiro", "Tubarão", "Relâmpago", "Pantera", "Machadinho", "Bronco", "Sucuri", "Muralha", "Sombra", "Leão", "Carcará", "Tsunami", "Canhão"],
    "en": ["The Hammer", "Bulldozer", "Frost", "Night Train", "The Mechanic", "Wildfire", "Slick", "Outlaw", "The Wall", "Thunder", "Tank", "The Surgeon", "Rattlesnake", "Iron", "Ghost", "Blackout"],
    "es": ["El Toro", "La Pantera", "El Martillo", "Cuervo", "El Gallo", "Dinamita", "Pesadilla", "El Terror"],
    "ru": ["Hawk", "Tsar", "Bear", "Steel", "Sniper", "Wolf", "Machine", "Mountain"],
    "ja": ["Samurai", "Kamikaze", "Daimyo", "Ronin", "Oni", "Tsunami", "Raijin", "Katana"],
    "fr": ["Le Lion", "Le Bûcheron", "Panthère", "Le Marteau"],
    "pl": ["Młot", "Wilk", "Tytan", "Szeryf"],
}

# Figuras autorais. id, nome, sobrenome, apelido, país, sexo, nascimento,
# divisão principal, aposentadoria (None = ainda ativo fora do roster), papel
# pós-carreira, bio
LEGENDS = [
    ("hist_farias", "Ubiratan", "Farias", "Tigre", "BR", "M", 1966, "m_heavyweight", 2001, "coach:gym_spcl",
     "O primeiro mito do Vale-Tudo Mundial: 22 lutas sem categorias de peso, 19 vitórias, nenhuma por pontos."),
    ("hist_harlan", "Buck", "Harlan", "The Hammer", "US", "M", 1968, "m_heavyweight", 2004, "commentator:out_inside",
     "Wrestler universitário que venceu a OCI de 1994 e virou o primeiro campeão dos pesados da Crown."),
    ("hist_tanabe", "Hideo", "Tanabe", "Ronin", "JP", "M", 1970, "m_light_heavyweight", 2006, "executive:org_shinsei",
     "Judoca que fundou a mística da Shinsei; hoje é diretor esportivo da promoção."),
    ("hist_kurogane", "Takeshi", "Kurogane", "Oni", "JP", "M", 1976, "m_heavyweight", 2012, "gym_owner:gym_shinjuku",
     "O ídolo da Imperial. O nocaute sofrido no Réveillon de Saitama é a cena mais reprisada da TV japonesa."),
    ("hist_braga", "Edson", "Braga", "Muralha", "BR", "M", 1978, "m_heavyweight", 2014, "coach:gym_spcl",
     "O azarão do Réveillon de Saitama. Depois foi campeão dos pesados da Crown."),
    ("hist_whitfield", "Liam", "Whitfield", "Frost", "GB", "M", 1979, "m_middleweight", 2015, "commentator:out_journal",
     "Primeiro campeão unificado Crown x Atlantic; wrestling cerebral e zero trash talk."),
    ("hist_okafor", "Chidi", "Okafor", "Night Train", "NG", "M", 1980, "m_middleweight", 2016, "gym_owner:gym_blackwater",
     "Último campeão médio da Atlantic Fight League e pioneiro nigeriano nas grandes ligas."),
    ("hist_mendes", "Diego", "Mendes", "Cangaceiro", "BR", "M", 1993, "m_lightweight", None, "inactive",
     "Ex-campeão pena da Crown. Perdeu a luta de 2022 contra Carter por decisão dividida e está parado desde 2024 por lesão. Fala em voltar só para a revanche."),
    ("hist_castaneda", "Érik", "Castañeda", "El Terror", "MX", "M", 1984, "m_featherweight", 2019, "promoter:nat_azteca",
     "Primeiro grande ídolo mexicano; hoje é sócio da Azteca Combate."),
    ("hist_orlov", "Vadim", "Orlov", "Bear", "RU", "M", 1977, "m_heavyweight", 2013, "coach:gym_mountain",
     "Invicto por nove anos no sambo profissional. Campeão da Imperial e da Taiga; nunca lutou na Crown."),
    ("hist_harper", "Tessa", "Harper", "Hurricane", "US", "F", 1987, "w_bantamweight", 2018, "media",
     "Primeira campeã feminina da Crown (2013). Levou as mulheres ao evento principal."),
    ("hist_lacerda", "Juliana", "Lacerda", "Carcará", "BR", "F", 1988, "w_bantamweight", 2021, "gym_owner:gym_spcl",
     "Dominou duas categorias da Crown e aposentou-se campeã em 2021."),
    ("hist_zhakupov", "Nurlan", "Zhakupov", "Steel", "KZ", "M", 1985, "m_welterweight", 2022, "executive:org_iron",
     "O primeiro campeão da Iron Circle; hoje comanda o departamento de talentos da organização."),
    ("hist_morimoto", "Misaki", "Morimoto", "Kitsune", "JP", "F", 1992, "w_strawweight", 2024, "commentator:out_inside",
     "Rainha do Grand Prix feminino da Shinsei, três vezes vencedora."),
    ("hist_doyle", "Mitch", "Doyle", "The Mechanic", "AU", "M", 1986, "m_middleweight", 2023, "coach:gym_kingsway",
     "Primeiro campeão médio da Pacific Fight League."),
    ("hist_kowalczyk", "Bartosz", "Kowalczyk", "Młot", "PL", "M", 1979, "m_heavyweight", 2017, "promoter:nat_wisla",
     "O homem que lotou um estádio em Varsóvia; ex-campeão pesado da Frontline."),
]

# Reinados presos. org, divisão, lutador, início, fim (None = atual), defesas,
# como ganhou, como terminou
PINNED_REIGNS = [
    ("org_crown", "m_heavyweight", "hist_harlan", "2000-11-18", "2003-06-14", 3, "Torneio inaugural", "Perdeu o cinturão"),
    ("org_crown", "m_heavyweight", "hist_braga", "2009-04-11", "2011-10-22", 3, "Nocaute", "Perdeu o cinturão"),
    ("org_crown", "m_heavyweight", "ftr_volkovic", "2016-02-27", "2019-11-09", 4, "Nocaute", "Perdeu o cinturão"),
    ("org_crown", "m_middleweight", "hist_whitfield", "2009-08-08", "2013-05-25", 6, "Decisão unânime", "Perdeu o cinturão"),
    ("org_crown", "m_welterweight", "ftr_reed", "2012-05-19", "2017-10-07", 9, "Nocaute técnico", "Perdeu o cinturão"),
    ("org_crown", "m_lightweight", "ftr_carter", "2020-03-07", None, 6, "Nocaute", ""),
    ("org_crown", "m_featherweight", "hist_castaneda", "2010-12-11", "2014-02-22", 5, "Nocaute técnico", "Perdeu o cinturão"),
    ("org_crown", "m_featherweight", "hist_mendes", "2017-09-16", "2021-06-12", 4, "Finalização", "Vagou para subir de categoria"),
    ("org_crown", "w_bantamweight", "hist_harper", "2013-02-23", "2015-11-14", 4, "Finalização", "Perdeu o cinturão"),
    ("org_crown", "w_bantamweight", "hist_lacerda", "2016-07-09", "2021-03-06", 6, "Nocaute técnico", "Aposentou-se campeã"),
    ("org_crown", "w_bantamweight", "ftr_markovic", "2021-04-24", None, 5, "Decisão unânime", ""),
    ("org_iron", "m_welterweight", "hist_zhakupov", "2011-06-18", "2016-09-03", 5, "Finalização", "Perdeu o cinturão"),
    ("org_iron", "m_welterweight", "ftr_arsanov", "2023-05-13", None, 3, "Finalização", ""),
    ("org_frontline", "m_heavyweight", "hist_kowalczyk", "2012-06-09", "2015-04-18", 3, "Nocaute", "Perdeu o cinturão"),
    ("org_frontline", "m_middleweight", "ftr_holloway", "2022-03-19", None, 4, "Decisão dividida", ""),
    ("org_vale", "m_middleweight", "ftr_ramos", "2008-06-14", "2013-11-30", 6, "Nocaute", "Perdeu o cinturão"),
    ("org_vale", "m_middleweight", "ftr_ramos", "2017-03-25", "2018-09-22", 1, "Nocaute técnico", "Perdeu o cinturão"),
    ("org_vale", "w_flyweight", "ftr_costa", "2022-08-20", None, 3, "Nocaute técnico", ""),
    ("org_shinsei", "m_light_heavyweight", "hist_tanabe", "1998-12-31", "2002-12-31", 4, "Final do Grand Prix", "Perdeu o cinturão"),
    ("org_shinsei", "m_heavyweight", "hist_kurogane", "2008-12-31", "2011-12-31", 3, "Final do Grand Prix", "Aposentou-se"),
    ("org_shinsei", "m_bantamweight", "ftr_sato", "2014-12-31", "2016-12-31", 3, "Final do Grand Prix", "Perdeu o cinturão"),
    ("org_shinsei", "m_bantamweight", "ftr_sato", "2019-12-31", "2023-12-31", 4, "Decisão", "Perdeu o cinturão"),
    ("org_shinsei", "w_strawweight", "hist_morimoto", "2016-12-31", "2023-06-17", 5, "Final do Grand Prix", "Aposentou-se campeã"),
    ("org_pfl", "m_middleweight", "hist_doyle", "2012-10-13", "2017-02-11", 5, "Luta inaugural", "Perdeu o cinturão"),
]

# Ano de criação de cada divisão por organização (as que não aparecem não
# existem naquela promoção).
DIVISIONS = {
    "org_crown": {"m_heavyweight": 2000, "m_light_heavyweight": 2001, "m_middleweight": 2001, "m_welterweight": 2001, "m_lightweight": 2002,
                  "m_featherweight": 2009, "m_bantamweight": 2009, "m_flyweight": 2012, "w_bantamweight": 2013, "w_strawweight": 2015,
                  "w_flyweight": 2018, "w_featherweight": 2019},
    "org_shinsei": {"m_heavyweight": 1998, "m_light_heavyweight": 1998, "m_middleweight": 2003, "m_lightweight": 2005, "m_featherweight": 2008,
                    "m_bantamweight": 2010, "m_flyweight": 2014, "w_strawweight": 2016, "w_flyweight": 2019},
    "org_vale": {"m_heavyweight": 2001, "m_light_heavyweight": 2002, "m_middleweight": 2001, "m_welterweight": 2002, "m_lightweight": 2002,
                 "m_featherweight": 2006, "m_bantamweight": 2008, "m_flyweight": 2014, "w_bantamweight": 2014, "w_strawweight": 2017, "w_flyweight": 2019},
    "org_frontline": {"m_heavyweight": 2006, "m_light_heavyweight": 2006, "m_middleweight": 2006, "m_welterweight": 2006, "m_lightweight": 2007,
                      "m_featherweight": 2010, "m_bantamweight": 2012, "m_flyweight": 2016, "w_bantamweight": 2015, "w_flyweight": 2019, "w_strawweight": 2021},
    "org_iron": {"m_heavyweight": 2011, "m_light_heavyweight": 2011, "m_middleweight": 2011, "m_welterweight": 2011, "m_lightweight": 2011,
                 "m_featherweight": 2012, "m_bantamweight": 2013, "m_flyweight": 2016, "w_strawweight": 2020, "w_bantamweight": 2022},
    "org_pfl": {"m_heavyweight": 2012, "m_light_heavyweight": 2013, "m_middleweight": 2012, "m_welterweight": 2012, "m_lightweight": 2012,
                "m_featherweight": 2013, "m_bantamweight": 2014, "m_flyweight": 2017, "w_flyweight": 2018, "w_strawweight": 2018, "w_bantamweight": 2020},
    "org_ascend": {"m_heavyweight": 2014, "m_light_heavyweight": 2014, "m_middleweight": 2014, "m_welterweight": 2014, "m_lightweight": 2014,
                   "m_featherweight": 2014, "m_bantamweight": 2015, "m_flyweight": 2015, "w_bantamweight": 2015, "w_strawweight": 2015,
                   "w_flyweight": 2016, "w_featherweight": 2020},
}

# Primeira noite de cada global (a numeração de eventos parte daqui).
FOUNDED = {"org_crown": "2000-11-18", "org_shinsei": "1997-07-19", "org_vale": "2001-03-10", "org_frontline": "2006-02-18",
           "org_iron": "2011-01-15", "org_pfl": "2012-04-21", "org_ascend": "2014-08-08"}

# De onde vêm os campeões gerados de cada organização (peso por país).
TALENT = {
    "org_crown": {"US": 36, "BR": 16, "GB": 5, "CA": 5, "MX": 5, "RU": 7, "PL": 3, "NL": 3, "AU": 4, "NG": 3, "KZ": 2, "GE": 2, "IE": 3, "JP": 2, "KR": 2, "NZ": 2},
    "org_ascend": {"US": 34, "MX": 12, "BR": 10, "CA": 5, "RU": 6, "KR": 4, "CN": 4, "AU": 4, "GB": 4, "NG": 4, "PH": 3, "AR": 3, "PE": 2, "FR": 3},
    "org_vale": {"BR": 62, "AR": 8, "PE": 6, "MX": 5, "US": 6, "CA": 2, "RU": 3, "NL": 2},
    "org_shinsei": {"JP": 50, "KR": 10, "BR": 10, "US": 6, "RU": 6, "NL": 4, "CN": 3, "MN": 3, "PH": 3, "TH": 3},
    "org_frontline": {"GB": 32, "IE": 8, "PL": 10, "NL": 8, "FR": 7, "SE": 5, "RS": 5, "HR": 4, "BR": 5, "US": 4, "RU": 4, "TR": 3},
    "org_iron": {"RU": 30, "KZ": 22, "GE": 10, "UZ": 9, "AZ": 5, "RS": 4, "US": 4, "BR": 5, "MN": 4, "PL": 3},
    "org_pfl": {"AU": 32, "NZ": 18, "CN": 8, "PH": 8, "JP": 6, "KR": 6, "US": 6, "TH": 6, "BR": 5, "GB": 3, "ZA": 2},
}
