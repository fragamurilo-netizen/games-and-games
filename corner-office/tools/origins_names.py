"""Pools de nomes de content/origins.json (fonte editável; rode tools/build_origins.py)."""
# Pools de nomes (primeiros nomes e sobrenomes comuns; combinações fictícias).
# Separador "|" permite nomes compostos.
P = {}

def pool(pid, male, female, last, rule=None):
    P[pid] = {"male": [x.strip() for x in male.split("|") if x.strip()],
              "female": [x.strip() for x in female.split("|") if x.strip()],
              "last": [x.strip() for x in last.split("|") if x.strip()]}
    if rule:
        P[pid]["surname_rule"] = rule

pool("pt_br",
 "João|Pedro|Lucas|Gabriel|Matheus|Rafael|Thiago|Felipe|Gustavo|Bruno|Rodrigo|Diego|Leandro|Marcelo|Fábio|André|Vinícius|Caio|Renan|Wellington|Anderson|Cleiton|Jailton|Edson|Adriano|Rogério|Márcio|Paulo|Carlos|Antônio|Francisco|José|Luiz|Ronaldo|Robson|Alex|Jefferson|Washington|Éverton|Wanderlei|Kaique|Davi|Arthur|Enzo|Heitor|Murilo|Igor|Iago|Otávio|Renato|Sandro|Valdir|Gilberto|Edvaldo|Josué|Natan|Ítalo|Cauã|Ryan|Alisson|Daniel|Samuel|Elias|Jean|Wesley|João Pedro|João Victor|Luiz Felipe|Carlos Eduardo|Paulo Henrique|José Aldo|Pedro Henrique|Marcos Vinícius",
 "Ana|Amanda|Bruna|Camila|Carla|Cláudia|Daniela|Débora|Fernanda|Gabriela|Isabela|Jéssica|Juliana|Larissa|Letícia|Luana|Mariana|Natália|Patrícia|Priscila|Raquel|Renata|Tatiane|Thaís|Vanessa|Viviane|Aline|Beatriz|Bianca|Karine|Kelly|Joice|Taila|Ketlen|Mayra|Poliana|Ana Clara|Maria Eduarda|Ana Paula|Maria Clara",
 "Silva|Santos|Oliveira|Souza|Rodrigues|Ferreira|Alves|Pereira|Lima|Gomes|Costa|Ribeiro|Martins|Carvalho|Almeida|Lopes|Soares|Fernandes|Vieira|Barbosa|Rocha|Dias|Nascimento|Andrade|Moreira|Nunes|Marques|Machado|Mendes|Freitas|Cardoso|Ramos|Gonçalves|Santana|Teixeira|Araújo|Pinto|Correia|Moura|Cavalcanti|Batista|Campos|Monteiro|Cunha|Reis|Brito|Farias|Nogueira|Bezerra|Maciel|Siqueira|Pacheco|Tavares|Sampaio|Borges|Queiroz|Xavier|Aguiar|Bastos|Leão|Figueiredo|Guimarães|Magalhães|Prates|Albuquerque|Coutinho|Medeiros|Sales|Paiva|Duarte")

pool("en_us",
 "Jake|Tyler|Cody|Ryan|Kyle|Brandon|Justin|Austin|Dustin|Travis|Chase|Hunter|Colby|Garrett|Bryce|Logan|Mason|Wyatt|Cole|Blake|Zach|Shane|Brett|Derek|Trevor|Casey|Jordan|Kevin|Michael|Matt|Chris|Josh|Nick|Sean|Danny|Tom|Jimmy|Bobby|Clay|Jared|Nate|Luke|Caleb|Evan|Colton|Brady|Tanner|Grant|Dalton|Jesse",
 "Ashley|Brittany|Kayla|Megan|Taylor|Jessica|Amanda|Sarah|Rachel|Lauren|Kelsey|Morgan|Paige|Alexis|Haley|Brooke|Shelby|Courtney|Danielle|Heather|Jenna|Kaitlyn|Madison|Emily|Katie|Mackenzie|Tessa|Holly|Cassidy|Jillian",
 "Smith|Johnson|Miller|Davis|Wilson|Anderson|Taylor|Thomas|Moore|Martin|Thompson|White|Clark|Lewis|Walker|Hall|Allen|Young|King|Wright|Scott|Green|Baker|Adams|Nelson|Hill|Campbell|Mitchell|Carter|Roberts|Phillips|Evans|Turner|Parker|Collins|Edwards|Stewart|Morris|Murphy|Cook|Rogers|Morgan|Cooper|Peterson|Reed|Bailey|Bell|Kelly|Howard|Cox|Ward|Brooks|Gray|Hughes|Price|Sanders|Myers|Long|Ross|Foster|Powell|Jenkins|Perry|Russell|Sullivan|Fisher|Hayes|Graham|Wallace|Cole|West|Jordan|Owens|Reynolds|Hansen|Larson|Schmidt|Mueller|Olson|Novak|Kowalski|Brennan|McCarthy|Doyle")

pool("african_american",
 "Malik|Jamal|DeAndre|Tyrone|Darius|Marcus|Terrell|Andre|Jalen|Deshawn|Darnell|Cedric|Lamar|Rashad|Tremaine|Kendrick|Jermaine|Quincy|Isaiah|Xavier|Elijah|Kareem|Dominique|Terrence|Demetrius|Reggie|Curtis|Derrick|Anthony|Corey|Devon|Trey|Khalil|Jaylen|Keon|Marquise|Roderick|Alonzo|Cornell|Montel|Tavon|Desmond|Maurice|Dwayne|Byron|Julius",
 "Aaliyah|Imani|Jasmine|Keisha|Tamika|Ebony|Shanice|Aisha|Destiny|Monique|Tiana|Brianna|Kiara|Jada|Nia|Latoya|Kimberly|Danielle|Angela|Tasha|Raven|Candace|Janelle|Simone|Deja|Amara",
 "Washington|Jackson|Johnson|Williams|Brown|Jones|Davis|Robinson|Harris|Jefferson|Coleman|Freeman|Banks|Booker|Mosley|Gaines|Sims|Wooten|Hairston|Pettaway|Merriweather|Battle|Ivory|Bethea|Dorsey|Toliver|Fields|Hawkins|Holloway|Grant|Carter|Simmons|Henderson|Patterson|Bryant|Alexander|Jenkins|Wallace|Hayes|Bennett|Dixon|Reed|Mack|Glover|Pugh|Tate|Bivens|Dawkins|Lockhart|McCall")

pool("es_mx",
 "José|Juan|Luis|Carlos|Jorge|Miguel|Alejandro|Eduardo|Fernando|Ricardo|Roberto|Francisco|Javier|Sergio|Raúl|Daniel|Arturo|Héctor|Oscar|Manuel|Rafael|Andrés|Gerardo|Adrián|Iván|Saúl|Erick|Brandon|Kevin|Ulises|Rodrigo|Martín|Emiliano|Diego|Joaquín|Ramón|Alfonso|Armando|Gustavo|Octavio|Pablo|Rubén|Santiago|Yair|Édgar|Leonardo|Juan Carlos|José Luis|Luis Ángel|Juan Pablo",
 "María|Guadalupe|Alejandra|Fernanda|Daniela|Gabriela|Mariana|Andrea|Karla|Paola|Ximena|Valeria|Sofía|Brenda|Diana|Jazmín|Leticia|Rocío|Yesenia|Lorena|Vanessa|Irene|Montserrat|Itzel|Araceli|Nayeli|María José",
 "Hernández|García|Martínez|López|González|Pérez|Rodríguez|Sánchez|Ramírez|Cruz|Flores|Gómez|Morales|Vázquez|Reyes|Jiménez|Torres|Díaz|Gutiérrez|Ruiz|Mendoza|Aguilar|Ortiz|Moreno|Castillo|Romero|Álvarez|Méndez|Chávez|Rivera|Juárez|Ramos|Domínguez|Herrera|Medina|Castro|Vargas|Guzmán|Velázquez|Rojas|Contreras|Salazar|Luna|Ortega|Cervantes|Estrada|Delgado|Figueroa|Espinoza|Villarreal|Rosales|Zamora|Guerrero|Navarro|Ibarra|Valenzuela|Cortés|Robles|Acosta|Cisneros|Trejo|Pacheco|Quintero|Barrera|Montoya")

pool("es_us",
 "Anthony|Adrian|Brandon|Christian|Daniel|David|Eric|Gabriel|Isaac|Jonathan|Joseph|Julian|Kevin|Marco|Mario|Nathan|Oscar|Richard|Steven|Victor|Alex|Angel|Andrew|Aaron|Jesús|José|Luis|Carlos|Miguel|Diego|Ricky|Manny|Rudy|Frankie|Tony|Danny|Joey|Sal|Hector|Rey",
 "Alyssa|Andrea|Ariana|Briana|Cristina|Daisy|Diana|Erica|Gabriela|Isabel|Jasmine|Jennifer|Karina|Leslie|Marisol|Melissa|Monica|Nicole|Priscilla|Selena|Stephanie|Vanessa|Veronica|Yvette",
 "")

pool("es_cu",
 "Yoel|Yordenis|Yunier|Yasmany|Yoandy|Lázaro|Osmany|Yuniel|Robeisy|Andy|Yander|Reinier|Dairon|Liván|Yosvany|Adonis|Erislandy|Julio César|Alexei|Frank|Ernesto|Raúl|Orlando|Pedro|Jorge Luis|Leinier|Yusniel|Dayron|Maikel|Rolando|Arlen|Yamil|Guillermo|Odlanier|Yunieski|Héctor|Ariel|Luis Ángel",
 "Yaimara|Yudelkis|Yaneisy|Yurisleidy|Dayana|Idalys|Yarelis|Legna|Yamilé|Mailín|Odalys|Yoana|Liset|Yanet|Arianna|Mayelín|Yulieski|Daylín|Leidis|Yuleisy",
 "Pérez|González|Rodríguez|Hernández|García|Martínez|Fernández|López|Díaz|Sánchez|Romero|Álvarez|Ruiz|Torres|Castillo|Cruz|Morales|Suárez|Rivero|Duvergel|Savón|La Cruz|Despaigne|Stevenson|Correa|Iglesias|Solís|Ramírez|Echevarría|Rigondeaux|Barthelemy|Portuondo|Kindelán|Veitía|Gamboa|Toledo|Cabrera|Pedroso|Mijaín|Ortiz|Batista|Quesada|Ceballos|Oquendo|Machado")

pool("en_uk",
 "James|Jack|Harry|Charlie|Thomas|George|Oliver|Callum|Connor|Liam|Jordan|Ryan|Lewis|Jamie|Scott|Craig|Dean|Lee|Wayne|Gary|Darren|Mark|Paul|Stuart|Kieran|Reece|Brad|Aaron|Luke|Sam|Tom|Dan|Josh|Mitchell|Declan|Owen|Rhys|Gareth|Aled|Ewan|Fraser|Alfie|Archie|Tommy|Joe|Billy|Nathan|Leon|Ross|Danny",
 "Emma|Chloe|Sophie|Lauren|Megan|Jade|Hannah|Charlotte|Amy|Holly|Rebecca|Stacey|Gemma|Kirsty|Leanne|Rhiannon|Bethan|Eilidh|Kayleigh|Molly|Ellie|Georgia|Abbie|Zoe|Lucy|Katie|Nicola|Hayley",
 "Smith|Jones|Taylor|Brown|Williams|Wilson|Johnson|Davies|Robinson|Wright|Thompson|Evans|Walker|White|Roberts|Green|Hall|Wood|Jackson|Clarke|Hughes|Edwards|Turner|Harris|Martin|Cooper|Hill|Ward|Morris|Moore|King|Watson|Harrison|Morgan|Baker|Young|Allen|Mitchell|James|Anderson|Phillips|Lee|Bell|Parker|Davis|Price|Bennett|Griffiths|Pritchard|Llewellyn|MacDonald|Campbell|Stewart|Fraser|McKenzie|Robertson|Reid|Murray|Ferguson|Hamilton|Sutherland|Ashworth|Pennington|Hargreaves|Whitfield|Barlow|Crossley|Holt|Hodgson|Doherty")

pool("irish",
 "Conor|Sean|Liam|Cian|Darragh|Eoin|Ciarán|Padraig|Declan|Colm|Oisín|Niall|Ronan|Fionn|Shane|Kieran|Aidan|Brendan|Cathal|Diarmuid|Tadhg|Fergal|Rory|Donal|Killian|Seamus|Paddy|Dylan|Jack|Michael",
 "Aoife|Niamh|Siobhán|Ciara|Orla|Sinéad|Caoimhe|Roisín|Saoirse|Clodagh|Aisling|Eimear|Gráinne|Deirdre|Emer|Méabh|Nuala|Fiona|Katie|Sarah",
 "Murphy|Kelly|O'Sullivan|Walsh|Smith|O'Brien|Byrne|Ryan|O'Connor|O'Neill|O'Reilly|Doyle|McCarthy|Gallagher|O'Doherty|Kennedy|Lynch|Murray|Quinn|Moore|McLoughlin|O'Carroll|Connolly|Daly|O'Connell|Wilson|Dunne|Brennan|Burke|Collins|Campbell|Clarke|Johnston|Hughes|Farrell|Fitzgerald|Brown|Martin|Maguire|Nolan|Flynn|Thompson|Callaghan|O'Donnell|Duffy|Mahony|Boyle|Healy|Shanahan|Keane")

pool("black_british",
 "Leon|Tyrese|Kwame|Jermaine|Darren|Marcus|Kofi|Andre|Jordan|Reuben|Tunde|Chidi|Kieron|Ashley|Nathaniel|Ethan|Isaac|Joel|Delroy|Winston|Clinton|Emmanuel|Samuel|Kyle|Tayo|Femi|Kemi|Lamar|Ricardo|Daniel",
 "Chantelle|Shanice|Abena|Adwoa|Kemi|Funmi|Tanisha|Jade|Keisha|Nadia|Aaliyah|Zara|Imani|Precious|Grace|Esther|Latisha|Ruth|Naomi|Blessing",
 "Johnson|Williams|Brown|Campbell|Thomas|Richards|Bailey|Clarke|Francis|Gordon|Grant|Morgan|Stephenson|Anderson|Mensah|Boateng|Owusu|Asante|Adebayo|Okafor|Oduya|Adeyemi|Nwosu|Okonkwo|Bello|Afolabi|Henry|Lewis|Reid|Samuels|Blake|Wright|Edwards|Hinds|Morrison|Joseph")

pool("south_asian",
 "Arjun|Rohit|Vikram|Rahul|Amit|Sanjay|Deepak|Ravi|Suresh|Manoj|Karan|Aman|Harpreet|Gurpreet|Jaspreet|Manpreet|Sandeep|Rajesh|Anil|Sunil|Vijay|Ajay|Nikhil|Varun|Pradeep|Ashok|Sachin|Yogesh|Naveen|Satish|Bajrang|Sushil|Ravinder|Deepak|Hardeep|Kuldeep|Inderjit|Mohit|Neeraj|Vinesh",
 "Priya|Anjali|Pooja|Neha|Sakshi|Vinesh|Geeta|Babita|Ritu|Sonam|Nisha|Kavita|Sunita|Pinki|Manpreet|Harleen|Simran|Jasleen|Lovlina|Nikhat|Divya|Anshu|Antim|Mansi|Kiran",
 "Singh|Kumar|Sharma|Yadav|Malik|Dahiya|Phogat|Punia|Sangwan|Chahal|Gill|Sandhu|Dhillon|Sidhu|Grewal|Brar|Rana|Chauhan|Tomar|Rathore|Verma|Gupta|Patel|Mehta|Joshi|Pandey|Mishra|Tiwari|Reddy|Nair|Menon|Iyer|Pillai|Rao|Khatri|Dagar|Hooda|Deswal|Rathee")

pool("pakistani",
 "Imran|Faisal|Zain|Hamza|Bilal|Usman|Adnan|Tariq|Asif|Kamran|Shahid|Waqar|Naveed|Irfan|Omar|Yasir|Junaid|Saqib|Arslan|Haris|Danyal|Rizwan|Shoaib|Zubair|Aamir|Nadeem|Sajid|Wasim|Umair|Fahad",
 "Aisha|Ayesha|Sana|Fatima|Zara|Hira|Mehwish|Nadia|Saima|Amna|Iqra|Maryam|Rabia|Sadia|Noor|Hina",
 "Khan|Ahmed|Hussain|Qureshi|Sheikh|Chaudhry|Bhatti|Butt|Mirza|Rehman|Malik|Iqbal|Akhtar|Siddiqui|Raza|Shah|Javed|Aslam|Anwar|Rashid|Hanif|Nawaz|Saleem|Yousaf|Mahmood|Abbasi|Awan|Rana|Janjua|Dar")

pool("fr_fr",
 "Thomas|Nicolas|Julien|Maxime|Alexandre|Kevin|Romain|Antoine|Quentin|Florian|Mathieu|Guillaume|Benjamin|Adrien|Hugo|Lucas|Théo|Baptiste|Clément|Pierre|Louis|Jérémy|Anthony|Sébastien|Cédric|Loïc|Yoann|Damien|Arnaud|Fabien|Gaël|Mickaël|Nathan|Enzo|Léo|Tristan|Valentin|Corentin|Cyril|Jonathan",
 "Marie|Camille|Léa|Manon|Chloé|Laura|Julie|Sarah|Pauline|Émilie|Mathilde|Océane|Justine|Charlotte|Marion|Anaïs|Clara|Lucie|Élodie|Audrey|Morgane|Mélanie|Aurélie|Inès|Margaux",
 "Martin|Bernard|Dubois|Thomas|Robert|Richard|Petit|Durand|Leroy|Moreau|Simon|Laurent|Lefebvre|Michel|Garcia|David|Bertrand|Roux|Vincent|Fournier|Morel|Girard|André|Lefèvre|Mercier|Dupont|Lambert|Bonnet|François|Martinez|Legrand|Garnier|Faure|Rousseau|Blanc|Guérin|Muller|Henry|Roussel|Nicolas|Perrin|Morin|Mathieu|Clément|Gauthier|Dumont|Lopez|Fontaine|Chevalier|Robin|Masson|Sanchez|Gérard|Nguyen|Boyer|Denis|Lemaire|Duval|Joly|Gautier|Roger|Roche|Roy|Noël|Meyer|Lucas|Meunier|Jean|Perez|Marchand")

pool("maghrebi",
 "Karim|Nassim|Mehdi|Yassine|Sofiane|Rachid|Samir|Bilal|Hakim|Farid|Mourad|Nabil|Walid|Amine|Ilyes|Ryad|Anis|Mohamed|Ahmed|Youssef|Hamza|Adel|Nordine|Riad|Salim|Tarik|Zakaria|Oussama|Ayoub|Badr|Soufiane|Khalid|Redouane|Ismaël|Abdel|Moussa|Sami|Jamel|Lotfi|Azzedine",
 "Nadia|Samira|Leïla|Yasmine|Sarah|Imane|Inès|Amel|Karima|Meriem|Sabrina|Djamila|Fatima|Nora|Rania|Salma|Hafsa|Soraya|Lina|Zineb|Khadija|Houda|Siham",
 "Benali|Bouzid|Haddad|Mansouri|Belkacem|Saidi|Amrani|Brahimi|Cherif|Djebbar|Ferhat|Guendouzi|Hamidi|Khelifi|Larbi|Meziane|Nacer|Ouali|Rahmani|Slimani|Taleb|Yahiaoui|Zidane|Bouazza|El Idrissi|El Amrani|Benjelloun|Tahiri|Alaoui|Bennani|Ouahbi|Boukhari|Chaoui|Harrak|Moussaoui|Azzouzi|Belhaj|Bensaid|Ziani|Aït Ali|Boussaid|Kaddour|Messaoudi|Ghezzal|Belarbi|Hadjadj")

pool("west_african_fr",
 "Moussa|Mamadou|Ibrahima|Ousmane|Cheikh|Abdoulaye|Modou|Aliou|Pape|Babacar|Lamine|Serigne|Omar|Amadou|Souleymane|Boubacar|Samba|Malick|Assane|Idrissa|Djibril|Youssou|Mbaye|Balla|Mame|Saliou|Birame|Alioune|Demba|El Hadji|Francis|Didier|Christian|Jean-Pierre|Patrick|Blaise|Hervé|Roger|Stéphane|Arnaud",
 "Aminata|Fatou|Awa|Mariama|Aïssatou|Khady|Ndèye|Coumba|Adama|Astou|Bineta|Rokhaya|Dieynaba|Sokhna|Yacine|Marème|Nafi|Oumou|Seynabou|Kiné|Christelle|Josiane|Brigitte|Solange",
 "Diop|Ndiaye|Fall|Sow|Diallo|Gueye|Faye|Seck|Sarr|Mbaye|Cissé|Ba|Camara|Diouf|Thiam|Niang|Kane|Sy|Touré|Sall|Dieng|Wade|Mbengue|Sène|Ndour|Diagne|Konaté|Traoré|Sané|Dramé|Coulibaly|Keïta|Kouyaté|Balde|Badji|Diatta|Manga|Tendeng")

pool("cameroon",
 "Francis|Jean-Pierre|Patrick|Blaise|Hervé|Roger|Stéphane|Arnaud|Emmanuel|Samuel|Christian|Didier|Serge|Eric|Joël|Yannick|Landry|Aristide|Gaël|Junior|Cédric|Rodrigue|Thierry|Alain|Achille|Olivier|Paul|Joseph|Vincent|Martial|Aboubakar|Moussa|Hamidou|Ousmane",
 "Christelle|Josiane|Brigitte|Solange|Nadège|Carine|Rosine|Gisèle|Sandrine|Estelle|Florence|Mireille|Clarisse|Laure|Ornella|Prisca|Rachel|Aïcha|Hadja|Madeleine",
 "Ngannou|Mbarga|Eto'o|Nkoulou|Mbia|Song|Atangana|Essomba|Fotso|Kamga|Tchoupo|Njoya|Ekotto|Nganga|Abega|Onana|Mbappé|Makoun|Moukandjo|Tchami|Nguemo|Ndjeng|Mvondo|Owona|Ebanda|Nkono|Bella|Ateba|Manga|Mballa|Tsafack|Fokou|Kengne|Djeumo|Tagne|Wandji|Nana|Simo|Ngassa|Kamdem|Feudjio|Tchatchoua")

pool("polish",
 "Mateusz|Michał|Kamil|Łukasz|Tomasz|Paweł|Krzysztof|Marcin|Piotr|Jakub|Bartosz|Adrian|Dawid|Damian|Grzegorz|Mariusz|Artur|Rafał|Sebastian|Szymon|Wojciech|Przemysław|Arkadiusz|Daniel|Karol|Maciej|Patryk|Robert|Marek|Sławomir|Janusz|Norbert|Hubert|Oskar|Filip|Konrad|Radosław|Jan|Zbigniew|Igor",
 "Anna|Katarzyna|Magdalena|Agnieszka|Joanna|Karolina|Monika|Natalia|Aleksandra|Paulina|Justyna|Marta|Ewelina|Weronika|Dominika|Izabela|Kinga|Sylwia|Klaudia|Patrycja|Zuzanna|Martyna|Iwona|Beata",
 "Nowak|Kowalski|Wiśniewski|Wójcik|Kowalczyk|Kamiński|Lewandowski|Zieliński|Szymański|Woźniak|Dąbrowski|Kozłowski|Jankowski|Mazur|Wojciechowski|Kwiatkowski|Krawczyk|Kaczmarek|Piotrowski|Grabowski|Zając|Pawłowski|Michalski|Król|Wieczorek|Jabłoński|Wróbel|Nowakowski|Majewski|Olszewski|Stępień|Malinowski|Jaworski|Adamczyk|Dudek|Nowicki|Pawlak|Górski|Witkowski|Walczak|Sikora|Baran|Rutkowski|Michalak|Szewczyk|Ostrowski|Tomaszewski|Pietrzak|Zalewski|Wróblewski|Błachowicz|Jędrzejczyk|Kowalkiewicz|Materla|Khalidov|Pudzianowski|Chmielewski|Sobczak", "polish")

pool("japanese",
 "Takashi|Hiroshi|Kenji|Daisuke|Yuki|Ryota|Shota|Takumi|Kazuki|Yuta|Haruto|Sota|Kaito|Ren|Riku|Hayato|Kenta|Naoki|Tatsuya|Yusuke|Kohei|Masato|Shinya|Tomoya|Takeshi|Makoto|Satoshi|Akira|Kazuya|Ryo|Tsuyoshi|Yoshihiro|Kazushi|Genki|Kyoji|Rin|Asahi|Ryuichi|Hideo|Koji|Shuhei|Jun|Tetsuya|Yoshiaki|Katsunori|Mitsuhiro|Daiki|Hiroki|Ryusei|Taiga",
 "Yuki|Aoi|Sakura|Haruka|Misaki|Ayaka|Nanami|Rina|Mai|Miyu|Saki|Kana|Emi|Asuka|Megumi|Yuka|Ayumi|Natsuki|Shizuka|Rena|Hina|Mizuki|Kaori|Mika|Tomomi|Satomi|Seika|Itsuki|Miku|Nao",
 "Sato|Suzuki|Takahashi|Tanaka|Watanabe|Ito|Yamamoto|Nakamura|Kobayashi|Kato|Yoshida|Yamada|Sasaki|Yamaguchi|Matsumoto|Inoue|Kimura|Hayashi|Shimizu|Yamazaki|Mori|Abe|Ikeda|Hashimoto|Yamashita|Ishikawa|Nakajima|Maeda|Fujita|Ogawa|Goto|Okada|Hasegawa|Murakami|Kondo|Ishii|Saito|Sakamoto|Endo|Aoki|Fujii|Nishimura|Fukuda|Ota|Miura|Okamoto|Matsuda|Nakagawa|Horiguchi|Asakura|Sakuraba|Takanohana|Kamikaze|Ishida|Uno|Tokoro|Hirota|Kitaoka|Aoyama|Kawajiri")

pool("korean",
 "Min-jun|Seo-jun|Do-yun|Ji-ho|Joon-ho|Hyun-woo|Sung-min|Dong-hyun|Tae-hyun|Jae-won|Chan-sung|Doo-ho|Kyung-ho|Seung-woo|Jun-young|Ki-won|Sang-hoon|Young-jin|Woo-jin|Jin-soo|Hyun-gyu|Dong-sik|Myung-hwan|Da-un|Jung-yong|Chang-min|Sung-hoon|Yong-jae|Hee-seung|Kwang-hee",
 "Ji-yeon|Seo-yeon|Min-seo|Ha-eun|Ji-woo|Soo-bin|Yu-jin|Da-hye|Eun-ji|Hye-jin|Na-rae|Ji-hyun|Seul-gi|Bo-ra|Mi-rae|Ye-jin|Hyo-joo|Chae-won|Ga-eun|So-hee",
 "Kim|Lee|Park|Choi|Jung|Kang|Cho|Yoon|Jang|Lim|Han|Oh|Seo|Shin|Kwon|Hwang|Ahn|Song|Jeon|Hong|Yoo|Ko|Moon|Yang|Son|Bae|Baek|Heo|Nam|Noh|Ha|Kwak|Sung|Cha|Joo|Woo|Min|Ryu|Na|Jin")

pool("kazakh",
 "Nurlan|Yerlan|Aibek|Daniyar|Askar|Arman|Yerzhan|Bauyrzhan|Dauren|Zhandos|Nursultan|Aslan|Madi|Sanzhar|Alibek|Timur|Rustem|Marat|Serik|Kairat|Beibit|Azamat|Nurzhan|Yermek|Olzhas|Shyngys|Temirlan|Zhanibek|Miras|Dias|Gennadiy|Ilyas|Kanat|Bekzat|Birzhan|Yerbol|Adil|Almas|Samat|Ruslan",
 "Aigerim|Dana|Madina|Aruzhan|Zhanar|Dinara|Gulnara|Aizhan|Assel|Saule|Zarina|Kamila|Aliya|Akmaral|Togzhan|Meruert|Balnur|Zhansaya|Anel|Tomiris|Laura|Aisulu",
 "Nurmagambetov|Abenov|Bekov|Dzhaksybekov|Iskakov|Kassymov|Mukhametov|Nurlanov|Ospanov|Rakhimov|Sadykov|Tokayev|Zhumabekov|Seitkali|Suleimenov|Baimukhanov|Zhakupov|Akhmetov|Kenzhebayev|Bekmukhambetov|Temirov|Serikov|Yeleusinov|Levit|Kulmanov|Alimkhanuly|Sapiyev|Beibitov|Aubakirov|Karimov|Ismailov|Omarov|Utebayev|Zholdasbekov|Kaliev|Dosmagambetov|Tuleubayev|Zhanabayev|Mamyrbayev|Sultanbekov|Yessenov|Kuanyshbekuly|Nurzhanuly|Daniyaruly|Marat uly", "kazakh")

pool("russian",
 "Aleksandr|Aleksei|Andrei|Anton|Artem|Denis|Dmitri|Egor|Evgeni|Fedor|Igor|Ilya|Ivan|Kirill|Konstantin|Maksim|Mikhail|Nikita|Nikolai|Oleg|Pavel|Roman|Ruslan|Sergei|Stanislav|Vadim|Valentin|Vasili|Viktor|Vitali|Vladimir|Vladislav|Vyacheslav|Yuri|Zakhar|Gleb|Timofei|Matvei|Arseni|Bogdan|Georgi|Leonid|Mark|Petr|Semyon|Yaroslav|Daniil|Grigori|Anatoli|Boris",
 "Anastasia|Maria|Daria|Anna|Elena|Olga|Irina|Ekaterina|Tatiana|Natalia|Svetlana|Yulia|Ksenia|Viktoria|Polina|Alina|Valentina|Evgenia|Kristina|Marina|Sofia|Vera|Yana|Alena|Lyudmila|Veronika|Diana|Galina",
 "Ivanov|Smirnov|Kuznetsov|Popov|Vasiliev|Petrov|Sokolov|Mikhailov|Novikov|Fedorov|Morozov|Volkov|Alekseev|Lebedev|Semenov|Egorov|Pavlov|Kozlov|Stepanov|Nikolaev|Orlov|Andreev|Makarov|Nikitin|Zakharov|Zaitsev|Soloviev|Borisov|Yakovlev|Grigoriev|Romanov|Vorobiev|Sergeev|Kuzmin|Frolov|Aleksandrov|Dmitriev|Korolev|Gusev|Kiselev|Ilyin|Maksimov|Polyakov|Sorokin|Vinogradov|Kovalev|Belov|Medvedev|Antonov|Tarasov|Zhukov|Baranov|Filippov|Komarov|Davydov|Belyaev|Gerasimov|Bogdanov|Osipov|Sidorov|Matveev|Titov|Markov|Mironov|Krylov|Kulikov|Karpov|Vlasov|Melnikov|Denisov|Gavrilov|Tikhonov|Kazakov|Afanasiev|Danilov|Savelyev|Timofeev|Fomin|Chernov|Abramov|Emelianenko|Shlemenko|Vyazigin|Levin|Kharitonov", "slavic")

pool("dagestani",
 "Magomed|Abdulrashid|Khabib|Islam|Zabit|Shamil|Gadzhi|Umar|Rasul|Ali|Akhmed|Abubakar|Murad|Saygid|Arsen|Magomedrasul|Abdulmanap|Usman|Tagir|Ramazan|Ibragim|Rustam|Kurban|Omar|Ruslan|Makhach|Said|Gasan|Nurmagomed|Zaur|Muslim|Abdulkadyr|Kamil|Dzhamal|Gamid|Khasbulat|Uvais|Mairbek|Tagir|Rashid|Artur|Eldar|Nariman|Zubair|Abusupiyan|Magomedkhan|Yusup|Suleiman|Shakhban|Gadzhimurad",
 "Aminat|Patimat|Madina|Zaira|Khadizhat|Aishat|Zarema|Saida|Diana|Maryam|Asiyat|Fatima|Zalina|Milana|Gulnara|Kamila|Ayna|Salimat|Umukusum|Barinat",
 "Magomedov|Nurmagomedov|Abdulaev|Gadzhiev|Aliev|Omarov|Ramazanov|Akhmedov|Gasanov|Makhachev|Khalidov|Magomedsharipov|Ibragimov|Kurbanov|Isaev|Mustafaev|Dzhamaldinov|Abakarov|Saidov|Rasulov|Gadzhimuradov|Magomedaliev|Tagirov|Musaev|Nurmagomedov|Kasimov|Salikhov|Guseinov|Mamedov|Zubairaev|Umarov|Abdurakhmanov|Suleimanov|Yusupov|Sharapudinov|Magomedkhanov|Kerimov|Batirov|Saadulaev|Chalaev|Omargadzhiev|Aliyarov|Dakhaev|Gamzatov|Murtuzaliev|Shikhsaidov|Alibekov|Khizriev|Abdulmanapov|Kamilov|Akhmedkhanov|Bagomedov|Gaziev|Ismailov|Magomedrasulov|Shakhbanov", "slavic")

pool("chechen",
 "Khamzat|Akhmed|Magomed|Ibragim|Adam|Ruslan|Rasul|Islam|Abdul-Kerim|Alikhan|Aslambek|Bekkhan|Dzhabrail|Imam|Isa|Khasan|Khusein|Lom-Ali|Mansur|Movsar|Musa|Rizvan|Shamil|Turpal|Umar|Yusup|Zelimkhan|Albert|Apti|Ayub|Baysangur|Dukvakha|Salman|Said-Emi|Zaurbek|Ilyas|Aslan|Anzor|Arbi|Alvi",
 "Aminat|Madina|Zarema|Kheda|Malika|Petimat|Milana|Luiza|Zalina|Khava|Satsita|Aishat|Raisa|Seda|Liana|Taisa|Zura|Iman|Maryam|Amina",
 "Chimaev|Kadyrov|Dudaev|Magomadov|Tsarnaev|Umarov|Dzhabrailov|Bisultanov|Khasbulatov|Yandarbiev|Makhmudov|Edilov|Gaitamirov|Albakov|Arsaev|Bakaev|Basaev|Dadaev|Ekhiev|Gakaev|Idrisov|Israilov|Khadzhiev|Kurbanov|Labazanov|Mamakaev|Musaev|Nazirov|Salgiriev|Saidulaev|Temirkhanov|Tovsultanov|Tutaev|Umkhaev|Vakhaev|Zakriev|Zavgaev|Alkhanov|Akhmadov|Dudurkaev|Saidov|Yusupov|Elmurzaev|Abdurakhmanov|Tagaev|Batukaev", "slavic")

pool("tatar",
 "Rinat|Ramil|Marat|Ilnur|Airat|Ilgiz|Rustem|Radik|Renat|Ruslan|Azat|Aydar|Almaz|Ilshat|Fanis|Rafael|Damir|Ildar|Timur|Emil|Artur|Rafik|Nail|Zufar|Shamil|Linar|Ilyas|Bulat|Albert|Salavat",
 "Alsu|Gulnaz|Dilyara|Leysan|Aigul|Guzel|Elvira|Liliya|Rezeda|Alina|Zulfiya|Ilsiya|Kamila|Adelina|Regina|Aliya|Chulpan|Dinara",
 "Galiullin|Khairullin|Nurullin|Sharipov|Zaripov|Mukhametshin|Khabibullin|Gilmutdinov|Safin|Valiev|Garipov|Minnikhanov|Fatkullin|Sabirov|Yunusov|Akhmetzyanov|Gataullin|Ziganshin|Kamaletdinov|Nizamov|Latypov|Zakirov|Tukhvatullin|Gainullin|Iskhakov|Salikhov|Shaimardanov|Bikbulatov|Yusupov|Mingazov|Ibragimov|Galimov|Nabiullin|Saifullin", "slavic")

pool("siberian",
 "Aian|Erel|Nyurgun|Semyon|Vasili|Ivan|Nikolai|Afanasi|Innokenti|Petr|Aital|Erkin|Bair|Batu|Chingis|Zhargal|Aldar|Tumen|Munko|Solbon|Dashi|Bato|Arsalan|Timur|Sayan|Aisen|Nyurbu|Egor|Mikhail|Aleksei",
 "Sardana|Aitalina|Tuyara|Nyurguyana|Kyunney|Saina|Sayana|Oyuna|Dulma|Tsyrena|Erzhena|Aryuna|Darima|Sesegma|Anastasia|Maria",
 "Sivtsev|Nikolaev|Vasiliev|Petrov|Ivanov|Egorov|Andreev|Stepanov|Gotovtsev|Argunov|Popov|Pavlov|Dambaev|Tsydenov|Batuev|Dorzhiev|Badmaev|Balzhinimaev|Zhambalov|Namsaraev|Tsybikov|Buyantuev|Sanzhiev|Budaev|Ochirov|Zhigzhitov|Garmaev|Dashiev|Tsyrenov|Radnaev|Aldarov|Mongush|Oorzhak|Kuular|Saryglar|Ondar", "slavic")

pool("georgian",
 "Giorgi|Levan|Davit|Nika|Luka|Irakli|Zurab|Lasha|Beka|Tornike|Sandro|Shota|Vakhtang|Merab|Guram|Gela|Tamaz|Revaz|Nodar|Mamuka|Otar|Paata|Archil|Temur|Ilia|Saba|Vazha|Avtandil|Kakha|Mikheil|Lado|Dato|Goga|Teimuraz|Varlam|Koba|Badri|Zviad|Gocha|Ramaz",
 "Nino|Tamar|Mariam|Ana|Salome|Eka|Natia|Sophio|Keti|Lika|Maka|Tiko|Nana|Manana|Khatia|Eliso|Tsiala|Mzia|Lela|Ketevan",
 "Beridze|Kapanadze|Gelashvili|Maisuradze|Giorgadze|Lomidze|Tsiklauri|Bolkvadze|Kvaratskhelia|Nozadze|Mchedlidze|Khutsishvili|Abashidze|Chkheidze|Dvalishvili|Topuria|Kavtaradze|Jorjadze|Gogoladze|Tsertsvadze|Kiknadze|Kalandadze|Makharadze|Mikautadze|Gvasalia|Shengelia|Janelidze|Tsereteli|Gabunia|Khvichia|Kobakhidze|Datunashvili|Natsvlishvili|Tabatadze|Jikia|Chikovani|Burjanadze|Mamulashvili|Kvirkvelia|Lagvilava|Revishvili|Svanidze|Chanturia|Gigauri|Gogua|Kurtanidze|Zaalishvili|Kharaishvili")

pool("pacific",
 "Tevita|Sione|Viliami|Siaosi|Tui|Manu|Pita|Semisi|Tama|Iosefa|Lealaiauloto|Junior|Toa|Mose|Faafetai|Kalani|Keoni|Makoa|Nainoa|Kai|Ikaika|Afa|Kaleo|Lani|Tanoai|Losa|Soliai|Talalelei|Fuimaono|Tavita",
 "Leilani|Moana|Mele|Malia|Lesieli|Seini|Ana|Lupe|Losana|Fetu|Kalea|Nalani|Mahina|Keala|Pua|Sina|Tiare|Lani",
 "Tuivasa|Fonoti|Tuiasosopo|Mauga|Leavasa|Tupou|Taufa|Latu|Havili|Vainikolo|Fifita|Kaufusi|Fuimaono|Aumua|Peni|Sopoaga|Tago|Faleolo|Talataina|Ioane|Kahananui|Kealoha|Kamakana|Makoa|Akana|Kahale|Nakoa|Pomaikai|Tuilagi|Sapolu|Tuiali'i|Masoe|Paepae|Afoa|Leiataua")

pool("maori",
 "Wiremu|Tamati|Hemi|Rawiri|Ihaia|Te Ariki|Nikau|Manaia|Kauri|Tane|Rangi|Hohepa|Pita|Aperahama|Matiu|Tipene|Hone|Kahu|Tama|Ropata|Israel|Kai|Mason|Jahvis|Ariki",
 "Aroha|Mere|Hine|Kiri|Moana|Ngaire|Anahera|Ataahua|Huia|Manaia|Marama|Tui|Waimarie|Kahurangi|Maia|Ria",
 "Adesanya|Te Huna|Walker|Ngata|Parata|Tamihana|Tawhiri|Rangihuna|Paewai|Horomona|Te Rangi|Tipene|Wihongi|Kereama|Paki|Rewiti|Tahana|Takerei|Waaka|Whaanga|Hapi|Karaka|Kingi|Mahuika|Ngarimu|Pomare|Poutama|Ruatapu|Tahere|Tupaea|Herewini|Ruru|Hohaia|Te Kani|Ormsby|Hetaraka")

pool("yoruba",
 "Kamaru|Babatunde|Oluwaseun|Adewale|Olumide|Ayodele|Femi|Tunde|Segun|Kunle|Wale|Dayo|Bayo|Gbenga|Yemi|Tobi|Damilola|Sodiq|Ayomide|Ibrahim|Ademola|Rotimi|Kehinde|Taiwo|Idowu|Abiodun|Olamide|Akin|Jide|Lanre",
 "Adenike|Folake|Funmilayo|Titilayo|Yetunde|Bukola|Omolara|Adeola|Bisola|Kemi|Temitope|Ronke|Toyin|Damilola|Abimbola|Motunrayo|Olayinka|Iyabo",
 "Adesanya|Usman|Adebayo|Adeyemi|Afolabi|Ogunleye|Olawale|Oladipo|Oyelaran|Akinola|Bamidele|Ogundipe|Okunola|Adeleke|Ajayi|Alabi|Balogun|Fashola|Ige|Lawal|Martins|Obafemi|Odukoya|Ogunbanjo|Oyewole|Salami|Sanni|Shittu|Adewumi|Olaniyan|Akande|Ayinde|Babalola|Ojo|Oni|Oyebanji")

pool("igbo",
 "Chinedu|Chukwuemeka|Obinna|Ikenna|Emeka|Nnamdi|Uchenna|Chidi|Kelechi|Ifeanyi|Chiamaka|Somtochukwu|Tochukwu|Okechukwu|Chibuike|Ebuka|Kenechukwu|Onyekachi|Chisom|Uzoma|Ugochukwu|Nonso|Kosi|Arinze|Izuchukwu|Jideofor|Chinonso|Kingsley|Godwin|Sunday",
 "Adaeze|Chiamaka|Ngozi|Nneka|Chioma|Ifeoma|Uchechi|Amarachi|Obiageli|Nkechi|Chinwe|Ogechi|Ebere|Ijeoma|Somto|Oluchi|Onyinye|Kosisochukwu",
 "Okafor|Okonkwo|Nwosu|Eze|Obi|Nwachukwu|Okeke|Onyeka|Chukwu|Ibe|Nwankwo|Anyanwu|Okoro|Ugwu|Ezeh|Nnaji|Obiora|Onuoha|Uchenna|Agu|Ekwueme|Iwobi|Nwafor|Odoh|Ofor|Ogbonna|Okoye|Onwuachi|Umeh|Asogwa|Okpara|Emenike|Nwokolo|Ezeani")

pool("hausa",
 "Abubakar|Aliyu|Musa|Ibrahim|Sani|Usman|Yusuf|Bello|Haruna|Suleiman|Abdullahi|Nasiru|Shehu|Umar|Garba|Hamza|Kabiru|Lawal|Mustapha|Bashir|Idris|Adamu|Isa|Jibril|Mansur|Yakubu|Zakari|Danjuma|Tanko|Auwal",
 "Aisha|Hadiza|Fatima|Zainab|Maryam|Hauwa|Amina|Rabi|Halima|Khadija|Safiya|Bilkisu|Jamila|Sadiya|Hafsat|Asma'u",
 "Abubakar|Bello|Danladi|Garba|Ibrahim|Lawal|Musa|Sani|Shehu|Umar|Usman|Yakubu|Yusuf|Aliyu|Dikko|Gambo|Kano|Maikudi|Mohammed|Sokoto|Tukur|Waziri|Zubairu|Jibrin|Kurfi|Bako|Dauda|Idris|Ladan|Magaji")

pool("thai",
 "Somchai|Buakaw|Saenchai|Yodsanklai|Sittichai|Rodtang|Superbon|Petchpanomrung|Nong-O|Tawanchai|Kaew|Pongsiri|Anucha|Chaiya|Kiattisak|Nattapong|Phanuwat|Sakda|Thanawat|Wichai|Yodkhunpon|Singdam|Sam-A|Kongsak|Petchmorakot|Jitmuangnon|Rungrat|Chatchai|Worawut|Suriya|Apichat|Teerapong|Jakkrit|Pakorn|Songkran",
 "Somjai|Anong|Kanya|Malee|Nok|Ploy|Siriporn|Supaporn|Wassana|Rattana|Kanokwan|Pimchanok|Nong Stamp|Dang|Fon|Mint|Chompoo|Jintara|Pornthip|Duangjai",
 "Sor Kingstar|Por Pramuk|Sitsongpeenong|Petchyindee|Kiatmoo9|Jitmuangnon|Sor Jor|Tor Laksong|Banchamek|Chuwattana|Wor Wanchai|Sitmonchai|Evolve|Kaewsamrit|Sakchaichote|Sitthichai|Jaroensuk|Thongchai|Srisuk|Wongsawat|Rattanakorn|Boonmee|Saetang|Phrommas|Kongprasert|Chaiyaphum|Sombat|Suwannarat|Thaweesak|Yodkhunpon|Singhapat|Naksuriya")

pool("filipino",
 "Jose|Juan|Mark|John|Michael|Rey|Jerome|Kevin|Christian|Joshua|Ramon|Eduard|Honorio|Lito|Danny|Rolando|Joey|Jomar|Rene|Arnel|Bong|Jeff|Jericho|Kenneth|Paolo|Marlon|Richard|Ryan|Jayson|Carlo|Miguel|Angelo|Emmanuel|Nonito|Donnie",
 "Maria|Angelica|Kristine|Jasmine|Mary Joy|Rose|Ana|Grace|Lovely|Princess|Jessa|Mylene|Denice|Jenelyn|April|Hergie|Rhea|Joanna",
 "Santos|Reyes|Cruz|Bautista|Garcia|Mendoza|Ramos|Aquino|Castillo|Villanueva|Del Rosario|Dela Cruz|Gonzales|Fernandez|Lopez|Pacquiao|Folayang|Nievera|Banario|Eustaquio|Vitasa|Alvarez|Belingon|Kiamco|Macaraeg|Tolentino|Manalo|Soriano|Magbanua|Dimaculangan|Lagman|Pangilinan|Salazar|Navarro|Buenaventura|Evangelista|Galang|Ocampo")

pool("chinese",
 "Wei|Jun|Hao|Lei|Tao|Qiang|Peng|Bo|Chao|Long|Yang|Jian|Zhen|Ming|Kai|Jie|Yu|Feng|Liang|Gang|Bin|Hui|Xiang|Zhi|Rui|Hang|Yong|Shuai|Haoran|Zihao|Yuxuan|Jiahao|Mingyu|Tianyi|Zhihao|Jingliang|Kenan|Zhipeng|Yadong|Hongxiang",
 "Li|Na|Jing|Ying|Hua|Mei|Xue|Yan|Lin|Fang|Ting|Qian|Xin|Yue|Hong|Juan|Weili|Yan Xiaonan|Jiayi|Yuqi|Xiaoxue|Shuang|Lina|Ni",
 "Wang|Li|Zhang|Liu|Chen|Yang|Huang|Zhao|Wu|Zhou|Xu|Sun|Ma|Zhu|Hu|Guo|He|Gao|Lin|Luo|Zheng|Liang|Xie|Song|Tang|Han|Feng|Deng|Cao|Peng|Zeng|Xiao|Tian|Dong|Pan|Yuan|Cai|Jiang|Yu|Du|Ye|Cheng|Wei|Su|Lü|Ding|Ren|Lu|Yao|Shen|Zhong|Jiang|Cui|Tan|Fan|Jin|Shi|Qiu|Qin|Hou|Bai|Meng|Yan|Kong|Xue")

pool("asian_us_last", "", "",
 "Nguyen|Tran|Le|Pham|Kim|Lee|Park|Wong|Chen|Chang|Wu|Liu|Huang|Tanaka|Yamamoto|Nakamura|Santos|Reyes|Cruz|Patel|Shah|Chung|Choi|Lam|Ho|Ng|Chan|Yee|Ito|Sato|Vu|Dang|Truong|Do|Hoang")

pool("dutch",
 "Daan|Sem|Lucas|Levi|Milan|Thijs|Jesse|Bram|Ruben|Tim|Stijn|Niels|Rick|Koen|Joost|Sander|Bas|Jeroen|Wouter|Martijn|Dennis|Jordy|Kevin|Mike|Robin|Jasper|Teun|Gijs|Pieter|Hendrik|Jan|Willem|Arjan|Marco|Peter",
 "Emma|Sophie|Julia|Anna|Lisa|Eva|Sanne|Lotte|Femke|Fleur|Iris|Anouk|Maud|Lieke|Marloes|Denise|Kim|Esmee|Romy|Nikki|Germaine|Marieke",
 "de Jong|Jansen|de Vries|van den Berg|van Dijk|Bakker|Janssen|Visser|Smit|Meijer|de Boer|Mulder|de Groot|Bos|Vos|Peters|Hendriks|van Leeuwen|Dekker|Brouwer|de Wit|Dijkstra|Smits|de Graaf|van der Meer|van der Linden|Kok|Jacobs|de Haan|Vermeulen|van den Heuvel|van der Veen|van den Broek|de Bruijn|de Bruin|van der Heijden|Schouten|van Beek|Willems|van Vliet|Overeem|Hoost|Schilt|Ruiter|Kuipers|Verhoeven|Koster|Prins|van Wijk")

pool("surinamese",
 "Remy|Tyrone|Gilbert|Errol|Rayen|Jairzinho|Donovan|Clyde|Romano|Melvin|Ricardo|Ivan|Ernesto|Andy|Regilio|Humphrey|Ruggero|Kenneth|Glenn|Stanley|Patrick|Jurgen|Dwight|Delano|Quincy",
 "Germaine|Chantal|Shirley|Natasja|Jennifer|Denise|Priscilla|Rachelle|Sharon|Tamara|Kimberley|Naomi|Melissa|Jolanda",
 "Bonjasky|Hug|Yvel|Balrak|Ristie|Tuitel|Doest|Kluivert|Seedorf|Davids|Rijkaard|Gullit|Wijnaldum|Bosnie|Emanuelson|Fer|Promes|Menzo|Hooi|Tjon|Dors|Lachman|Karg|Amatdjais|Nunes|Pinas|Macnack|Rustenberg|Sabajo|Wolff")

pool("swedish",
 "Alexander|Erik|Karl|Johan|Anders|Lars|Oskar|Viktor|Emil|Filip|Gustav|Linus|Axel|Albin|Anton|Jesper|Mattias|Marcus|Niklas|Rasmus|Sebastian|Simon|Tobias|Andreas|Henrik|Joakim|Kristoffer|Magnus|Fredrik|Ludvig|Elias|Hugo|Isak|Melker",
 "Anna|Emma|Sara|Johanna|Elin|Linnea|Frida|Moa|Hanna|Matilda|Ida|Klara|Maja|Wilma|Ebba|Alva|Tove|Sanna|Josefin|Lina",
 "Andersson|Johansson|Karlsson|Nilsson|Eriksson|Larsson|Olsson|Persson|Svensson|Gustafsson|Pettersson|Jonsson|Jansson|Hansson|Bengtsson|Jönsson|Lindberg|Jakobsson|Magnusson|Lindström|Olofsson|Lindqvist|Lindgren|Berg|Axelsson|Bergström|Lundberg|Lundqvist|Lind|Mattsson|Berglund|Fredriksson|Sandberg|Henriksson|Forsberg|Sjöberg|Wallin|Engström|Eklund|Danielsson|Håkansson|Lundin|Björk|Bergman|Gunnarsson|Holm|Wikström|Samuelsson|Isaksson|Fransson")

pool("arab",
 "Ahmad|Mohammad|Ali|Hassan|Hussein|Khaled|Omar|Yousef|Ibrahim|Mahmoud|Mustafa|Karim|Rami|Samir|Tarek|Nabil|Fadi|Bassel|Ziad|Hadi|Jamal|Walid|Mazen|Anas|Majd|Firas|Amir|Adnan|Bilal|Rashid|Saleh|Nasser|Hamza|Tamer|Laith",
 "Fatima|Layla|Noor|Rana|Hiba|Dima|Lina|Maya|Rania|Salma|Yasmin|Zeina|Aya|Hala|Nour|Sara|Mariam|Amal|Reem|Dana",
 "Haddad|Khoury|Nasser|Saleh|Hamdan|Mansour|Barakat|Jaber|Khalil|Aziz|Hassan|Darwish|Farah|Habib|Issa|Kassem|Masri|Najjar|Qasim|Rahman|Sabbagh|Shaheen|Tamimi|Yassin|Zayed|Abboud|Awad|Bakri|Daher|Fakhoury|Ghanem|Hijazi|Karam|Maalouf|Obeid|Sayegh|Sleiman|Taha")

pool("somali",
 "Abdi|Ahmed|Mohamed|Abdullahi|Hassan|Ali|Omar|Yusuf|Ismail|Farah|Mahad|Hamza|Liban|Guled|Khalid|Bashir|Abdirahman|Mustafa|Idris|Nuur",
 "Hodan|Amina|Fadumo|Ifrah|Sahra|Hibo|Ayan|Nimco|Faiza|Ilhan|Leyla|Hamdi",
 "Abdi|Ahmed|Mohamed|Hassan|Ali|Omar|Yusuf|Farah|Warsame|Jama|Hersi|Aden|Egal|Samatar|Mohamud|Nur|Osman|Dahir|Elmi|Duale")

pool("fr_ca",
 "Jean-François|Marc-André|Jean-Philippe|Pierre-Luc|Olivier|Maxime|Simon|Mathieu|Alexandre|Vincent|Gabriel|Samuel|Félix|Étienne|Charles|Louis-Philippe|Guillaume|Francis|Patrick|Stéphane|Sébastien|Martin|David|Éric|Jonathan|Dominic|Frédéric|Kevin|William|Jérémie|Hugo|Antoine|Georges|Mathis|Émile",
 "Marie-Ève|Marie-Pier|Catherine|Geneviève|Isabelle|Julie|Mélanie|Stéphanie|Valérie|Audrey|Émilie|Karine|Joanie|Andréanne|Laurence|Rosalie|Camille|Alexandra|Noémie|Sarah",
 "Tremblay|Gagnon|Roy|Côté|Bouchard|Gauthier|Morin|Lavoie|Fortin|Gagné|Ouellet|Pelletier|Bélanger|Lévesque|Bergeron|Leblanc|Paquette|Girard|Simard|Boucher|Caron|Beaulieu|Cloutier|Dubé|Poirier|Fournier|Lapointe|Leclerc|Lefebvre|Poulin|Thibault|St-Pierre|Laflamme|Nadeau|Beaudoin|Deschênes|Desrosiers|Lachance|Mercier|Vaillancourt|Rivard|Arsenault|Charbonneau|Brassard|Villeneuve|Émond|Proulx|Parent|Dufour")

pool("med_au",
 "Nick|George|Con|Peter|Chris|Steve|Tony|Frank|Joe|Sam|Michael|Dimitri|Kostas|Angelo|Luca|Marco|Paul|Jason|Alex|Bilal|Ahmed|Jamal|Rob|Theo|Andrew",
 "Maria|Elena|Sophia|Christina|Anna|Katerina|Georgia|Angela|Rita|Lina|Nadia|Stella|Tina|Vanessa|Zoe",
 "Papadopoulos|Nikolaidis|Georgiou|Konstantinou|Ioannou|Dimitriou|Volkanovski|Rossi|Russo|Esposito|Romano|Ricci|Marino|Greco|Bruno|Gallo|Conti|Costa|Mancini|Lombardo|Moretti|Barbieri|Fontana|Kouris|Karagiannis|Alexiou|Makris|Pappas|Stavros|Haddad|Khoury|Nasser|Tuivasa|Salameh|Fakhoury")

pool("anglo_au_first",
 "Jack|Liam|Josh|Ben|Mitch|Brodie|Lachlan|Riley|Jayden|Kane|Bailey|Nathan|Daniel|Dylan|Tyson|Hayden|Callum|Jarrod|Brock|Kurt|Shaun|Damien|Craig|Luke|Jake|Aaron|Corey|Blake|Zac|Harrison|Cooper|Angus|Declan|Flynn|Toby",
 "Chloe|Jess|Emily|Brooke|Jade|Tahlia|Kayla|Sarah|Hannah|Georgia|Mia|Ruby|Tegan|Maddison|Shannon|Casey|Bec|Kirra|Brianna|Stacey",
 "")

# Sobrenomes/nomes muito ligados a pessoas reais (atletas, políticos): fora.
BLOCK = set("""Nurmagomedov|Makhachev|Magomedsharipov|Khalidov|Chimaev|Kadyrov|Dudaev|Tsarnaev|Basaev|Yandarbiev|Khasbulatov|Zavgaev|Alkhanov|Batukaev|Adesanya|Usman|Kamaru|Pacquiao|Ngannou|Eto'o|Mbappé|Mbia|Song|Nkoulou|Ekotto|Makoun|Moukandjo|Błachowicz|Jędrzejczyk|Kowalkiewicz|Materla|Pudzianowski|Emelianenko|Shlemenko|Vyazigin|Kharitonov|Tuivasa|Volkanovski|Topuria|Dvalishvili|Kvaratskhelia|Mamulashvili|Rigondeaux|Savón|Stevenson|Kindelán|Mijaín|La Cruz|Despaigne|Duvergel|Barthelemy|Veitía|Gamboa|Bonjasky|Hug|Overeem|Hoost|Schilt|Kluivert|Seedorf|Davids|Rijkaard|Gullit|Wijnaldum|Promes|Menzo|Emanuelson|Sakuraba|Horiguchi|Asakura|Kawajiri|Tokoro|Takanohana|Kamikaze|Uno|Aoki|Folayang|Belingon|Kiamco|Eustaquio|Nievera|Banario|Buakaw|Saenchai|Yodsanklai|Rodtang|Superbon|Petchpanomrung|Nong-O|Tawanchai|Yodkhunpon|Singdam|Sam-A|Petchmorakot|Jitmuangnon|Nong Stamp|Sor Kingstar|Por Pramuk|Sitsongpeenong|Petchyindee|Kiatmoo9|Banchamek|Evolve|Weili|Yan Xiaonan|Jingliang|Kenan|Yadong|Levit|Kulmanov|Alimkhanuly|Sapiyev|Yeleusinov|Zhumabekov|Tokayev|Nursultan|Gennadiy|Abdulmanap|Abdulmanapov|Khabib|Zabit|Makhach|Khamzat|Te Huna|Kosi|José Aldo|Julio César|Erislandy|Robeisy|Lovlina|Nikhat|Bajrang|Vinesh|Babita|Sushil|Phogat|Punia|Dahiya|Nemkov|Bader|Yoel|Mbarga|Atangana|Onana|Tchami|Nkono|Mvondo|Emenike|Iwobi|Nwankwo|Okocha|Kanu|Burjanadze|Tsereteli|Gvasalia|Shengelia|Chanturia|Ateba""".split("|"))
for p in P.values():
    for k in ("male", "female", "last"):
        p[k] = [n for n in dict.fromkeys(p[k]) if n not in BLOCK]
