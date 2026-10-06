class_name PlayStyle
extends RefCounted
## Estilo de jogo do jogador ("Falso 9", "Pivô", "Regista"...) e um traço secundário ("Jogo
## aéreo", "Passe vertical"...), deduzidos dos atributos em que ele mais se destaca em relação ao
## próprio overall (o rótulo descreve o *perfil*, não o nível).
##
## O estilo também muda o jeito de jogar no motor, com efeitos pequenos (MatchPlayer.apply_side e
## MatchTeam.recompute_units): quem recebe as bolas (pesos de escolha por modo) e que tipo de jogada
## o time cria ou deixa de sofrer. O talento continua decidindo; o estilo dá o sotaque.

## Modos de escolha do motor (MatchSimulation.PK_*): 0 chute, 1 cabeça, 2 chute de longe, 3 drible,
## 4 contra-ataque, 5 passe, 6 cruzamento, 7 meio, 8 defesa (erro).
## Tipos de jogada: through, cross, long, dribble, counter, scramble (MatchSimulation.CH_KEYS).
##
## Cada estilo: k = chave, n = nome, d = descrição, w = {atributo: peso} (média ponderada da
## diferença para o overall), b = bônus fixo (o estilo "padrão" da função vence quando nada se
## destaca), h = bônus por altura, inv = só ponta de pé invertido, fx = efeitos no motor
## (t = tipos de jogada do time, o = tipos de jogada do rival, k = pesos de escolha por modo,
## fat = cansaço, poss = posse, cards = cartões), ins = instrução individual que combina.
const BY_ROLE: Dictionary = {
	"GK": [
		{"k": "paredao", "n": "Paredão", "d": "Goleiro tradicional: fica no gol e resolve na colocação e no reflexo.", "w": {}, "b": 2.5, "fx": {}},
		{"k": "reflexo", "n": "Goleiro de reflexo", "d": "Defesas à queima-roupa. Cresce nos chutes de perto.", "w": {Attr.REF: 1.0}, "b": -2.5, "fx": {"o": {"scramble": -0.04}}},
		{"k": "libero", "n": "Goleiro-líbero", "d": "Sai da área para cortar lançamentos e ajuda na saída de bola. Combina com linha alta.", "w": {Attr.PAS: 0.6, Attr.TEC: 0.4, Attr.ACE: 0.4}, "b": 14.0, "fx": {"o": {"through": -0.06, "counter": -0.04}, "poss": 0.01}},
		{"k": "dono", "n": "Dono da área", "d": "Sai do gol nos cruzamentos e manda na pequena área.", "w": {Attr.CAB: 0.5, Attr.FOR: 0.5}, "b": 6.5, "h": 0.8, "fx": {"o": {"cross": -0.07}}},
		{"k": "colocado", "n": "Bem colocado", "d": "Sempre no lugar certo: chute de longe quase nunca o surpreende.", "w": {Attr.POS: 1.0, Attr.INT: 0.4}, "b": 0.0, "fx": {"o": {"long": -0.08}}},
		{"k": "penaltis", "n": "Pegador de pênalti", "d": "Frio e rápido nas cobranças: pênalti contra ele é drama.", "w": {Attr.REF: 0.5, Attr.FRI: 0.6}, "b": 0.5, "fx": {}},
		{"k": "seguro", "n": "Goleiro seguro", "d": "Encaixa quase tudo e não dá rebote: raramente falha.", "w": {Attr.GOL: 0.6, Attr.DEC: 0.4}, "b": -0.5, "fx": {"o": {"scramble": -0.03}}},
	],
	"CB": [
		{"k": "classico", "n": "Zagueiro clássico", "d": "Zagueiro sem firula: marca, cobre e rebate.", "w": {}, "b": 2.0, "fx": {}},
		{"k": "xerife", "n": "Xerife", "d": "Ganha tudo pelo alto e intimida o centroavante.", "w": {Attr.CAB: 0.6, Attr.FOR: 0.5, Attr.MAR: 0.3}, "b": -3.5, "h": 0.4, "fx": {"o": {"cross": -0.05}, "k": {1: 1.2}}},
		{"k": "construtor", "n": "Zagueiro construtor", "d": "Sai jogando e quebra linhas com passes verticais.", "w": {Attr.PAS: 0.7, Attr.VIS: 0.4, Attr.TEC: 0.4}, "b": 8.0, "fx": {"t": {"through": 0.03, "long": 0.03}, "poss": 0.01}},
		{"k": "libero", "n": "Líbero", "d": "Sobra atrás da linha e lê o lançamento antes de todo mundo.", "w": {Attr.INT: 0.6, Attr.POS: 0.5, Attr.PAS: 0.2, Attr.VEL: 0.3}, "b": 2.5, "fx": {"o": {"through": -0.05, "counter": -0.03}}},
		{"k": "stopper", "n": "Zagueiro stopper", "d": "Sai da linha para dar o bote antes do atacante girar. Às vezes chega atrasado.", "w": {Attr.DES: 0.7, Attr.FOR: 0.3, Attr.ACE: 0.3}, "b": -0.5, "fx": {"o": {"dribble": -0.07}, "t": {"scramble": 0.02}, "cards": 1.15}},
		{"k": "rapido", "n": "Zagueiro rápido", "d": "Corre atrás de qualquer um: cobre as costas da defesa.", "w": {Attr.VEL: 0.6, Attr.ACE: 0.6}, "b": 2.5, "fx": {"o": {"counter": -0.06}}},
		{"k": "artilheiro", "n": "Zagueiro artilheiro", "d": "Perigo nas bolas paradas: aparece na área para cabecear.", "w": {Attr.CAB: 0.6, Attr.FIN: 0.4, Attr.FRI: 0.2}, "b": 8.0, "fx": {"k": {1: 1.5}}},
		{"k": "antecipacao", "n": "Zagueiro de antecipação", "d": "Lê o passe e rouba a bola antes de ela chegar ao atacante.", "w": {Attr.INT: 0.5, Attr.DES: 0.4, Attr.ACE: 0.3}, "b": 3.5, "fx": {"o": {"through": -0.04}, "k": {8: 0.9}}},
	],
	"FB": [
		{"k": "equilibrado", "n": "Lateral equilibrado", "d": "Apoia e marca na medida certa.", "w": {}, "b": 3.5, "fx": {}},
		{"k": "marcador", "n": "Lateral marcador", "d": "Primeiro defende. Quase nunca é batido no seu lado.", "w": {Attr.MAR: 0.6, Attr.DES: 0.5, Attr.POS: 0.4}, "b": 0.5, "fx": {"o": {"cross": -0.05}}, "ins": "segurar"},
		{"k": "apoiador", "n": "Lateral apoiador", "d": "Vai e volta o jogo inteiro e cruza da linha de fundo.", "w": {Attr.CRU: 0.6, Attr.RES: 0.6, Attr.VEL: 0.3}, "b": 1.5, "fx": {"t": {"cross": 0.04}, "k": {6: 1.2}}, "ins": "avancar"},
		{"k": "ala", "n": "Ala ofensivo", "d": "Praticamente um ponta: parte para cima no drible.", "w": {Attr.CRU: 0.3, Attr.DRI: 0.6, Attr.ACE: 0.4}, "b": 2.0, "fx": {"t": {"dribble": 0.03, "cross": 0.03}, "k": {3: 1.25}}, "ins": "avancar"},
		{"k": "invertido", "n": "Lateral invertido", "d": "Fecha por dentro como um volante a mais e ajuda a ter a bola.", "w": {Attr.PAS: 0.6, Attr.TEC: 0.4, Attr.DEC: 0.4, Attr.VIS: 0.2}, "b": 4.5, "fx": {"t": {"through": 0.03}, "poss": 0.01, "k": {5: 1.2, 6: 0.8}}, "ins": "prender"},
		{"k": "veloz", "n": "Lateral veloz", "d": "Recupera na corrida e puxa contra-ataques pelo lado.", "w": {Attr.VEL: 0.6, Attr.ACE: 0.6}, "b": -2.0, "fx": {"o": {"counter": -0.04}, "t": {"counter": 0.03}}},
		{"k": "incansavel", "n": "Lateral incansável", "d": "Não para de correr: chega inteiro no fim do jogo.", "w": {Attr.RES: 1.0, Attr.DES: 0.2}, "b": -1.0, "fx": {"fat": 0.88, "t": {"cross": 0.02}}},
		{"k": "terceiro", "n": "Lateral zagueiro", "d": "Fecha por dentro como terceiro zagueiro quando o time ataca pelo outro lado.", "w": {Attr.MAR: 0.4, Attr.FOR: 0.4, Attr.CAB: 0.4}, "b": 5.0, "h": 0.2, "fx": {"o": {"cross": -0.03, "counter": -0.03}}, "ins": "segurar"},
	],
	"DM": [
		{"k": "primeiro", "n": "Primeiro volante", "d": "Protege a zaga e distribui simples.", "w": {}, "b": 2.5, "fx": {"o": {"through": -0.03}}},
		{"k": "guarda", "n": "Cão de guarda", "d": "Morde o tempo todo e não deixa o meia rival respirar. Faz faltas.", "w": {Attr.DES: 0.7, Attr.MAR: 0.5, Attr.FOR: 0.2}, "b": -3.0, "fx": {"o": {"dribble": -0.06, "through": -0.03}, "cards": 1.15}, "ins": "marcar"},
		{"k": "ancora", "n": "Âncora", "d": "Não sai da frente da área: fecha as linhas de passe por dentro.", "w": {Attr.POS: 0.7, Attr.INT: 0.6}, "b": -1.0, "fx": {"o": {"through": -0.06, "counter": -0.03}}, "ins": "segurar"},
		{"k": "regista", "n": "Regista", "d": "Organiza de trás: dita o ritmo e acha o passe que ninguém vê.", "w": {Attr.PAS: 0.7, Attr.VIS: 0.6, Attr.TEC: 0.2}, "b": 1.0, "fx": {"t": {"through": 0.05, "long": 0.02}, "poss": 0.015, "k": {5: 1.3}}, "ins": "prender"},
		{"k": "segundo", "n": "Segundo volante", "d": "Sai para o jogo e chega de trás para finalizar.", "w": {Attr.RES: 0.5, Attr.CHL: 0.4, Attr.VEL: 0.2, Attr.FIN: 0.2}, "b": 4.0, "fx": {"t": {"scramble": 0.03}, "k": {2: 1.2}}, "ins": "avancar"},
		{"k": "lancador", "n": "Volante lançador", "d": "Vira o jogo e acha o atacante com lançamentos longos.", "w": {Attr.PAS: 0.5, Attr.VIS: 0.3, Attr.CRU: 0.3, Attr.FOR: 0.2}, "b": 4.5, "fx": {"t": {"long": 0.07}, "k": {5: 1.1}}},
		{"k": "libero", "n": "Volante líbero", "d": "Desce entre os zagueiros para sair jogando e fecha o meio quando o time perde a bola.", "w": {Attr.POS: 0.5, Attr.PAS: 0.4, Attr.INT: 0.4}, "b": 0.6, "fx": {"o": {"counter": -0.04}, "poss": 0.01}, "ins": "segurar"},
		{"k": "recuado", "n": "Volante que recua", "d": "Baixa entre os zagueiros para sair jogando e ganha as bolas altas na frente da área.", "w": {Attr.CAB: 0.4, Attr.PAS: 0.4, Attr.POS: 0.3, Attr.FOR: 0.2}, "b": 2.0, "fx": {"o": {"cross": -0.03}, "poss": 0.01}},
	],
	"CM": [
		{"k": "meio", "n": "Meio-campista", "d": "Faz de tudo um pouco no meio.", "w": {}, "b": 3.0, "fx": {}},
		{"k": "box", "n": "Box-to-box", "d": "De área a área: defende, carrega e aparece para finalizar.", "w": {Attr.RES: 0.6, Attr.DES: 0.3, Attr.FIN: 0.2, Attr.VEL: 0.2}, "b": 1.0, "fx": {"t": {"scramble": 0.03}, "o": {"counter": -0.02}, "fat": 0.95}},
		{"k": "mezzala", "n": "Mezzala", "d": "Meia que ataca o corredor entre o lateral e o zagueiro.", "w": {Attr.DRI: 0.5, Attr.TEC: 0.3, Attr.FIN: 0.3, Attr.ACE: 0.2}, "b": 4.0, "fx": {"t": {"dribble": 0.04}, "k": {0: 1.25, 3: 1.2}}, "ins": "avancar"},
		{"k": "carrilero", "n": "Carrilero", "d": "Cobre o lado, fecha o corredor e dá equilíbrio ao time.", "w": {Attr.RES: 0.4, Attr.MAR: 0.4, Attr.PAS: 0.2, Attr.POS: 0.3}, "b": 3.0, "fx": {"o": {"cross": -0.04, "counter": -0.03}}, "ins": "segurar"},
		{"k": "maestro", "n": "Maestro", "d": "Pensa o jogo: tudo passa por ele.", "w": {Attr.PAS: 0.6, Attr.VIS: 0.6, Attr.DEC: 0.3}, "b": -2.0, "fx": {"t": {"through": 0.05}, "poss": 0.01, "k": {5: 1.3}}, "ins": "prender"},
		{"k": "chegador", "n": "Meia chegador", "d": "Aparece de surpresa na entrada da área para chutar.", "w": {Attr.CHL: 0.6, Attr.FIN: 0.4, Attr.POS: 0.2}, "b": 2.0, "fx": {"t": {"long": 0.04}, "k": {2: 1.3, 0: 1.1}}, "ins": "chutar"},
		{"k": "condutor", "n": "Condutor", "d": "Recebe, gira e carrega a bola pelo meio.", "w": {Attr.DRI: 0.6, Attr.ACE: 0.4, Attr.FOR: 0.2}, "b": 2.8, "fx": {"t": {"dribble": 0.04, "counter": 0.02}, "k": {3: 1.2}}},
		{"k": "itinerante", "n": "Armador itinerante", "d": "Aparece em todo o campo para receber: arma de trás, carrega e ainda chega na frente.", "w": {Attr.PAS: 0.4, Attr.DRI: 0.4, Attr.RES: 0.4}, "b": -0.2, "fx": {"t": {"through": 0.03, "dribble": 0.02}, "k": {5: 1.15, 3: 1.1}, "fat": 1.03}},
		{"k": "recuperador", "n": "Meia recuperador", "d": "Ganha a segunda bola e recupera a posse logo depois de perdê-la.", "w": {Attr.DES: 0.4, Attr.RES: 0.4, Attr.INT: 0.2, Attr.ACE: 0.2}, "b": 1.5, "fx": {"t": {"scramble": 0.03}, "o": {"counter": -0.02}, "fat": 1.03}},
	],
	"AM": [
		{"k": "meia", "n": "Meia-atacante", "d": "Liga o meio ao ataque.", "w": {}, "b": 3.0, "fx": {}},
		{"k": "dez", "n": "Camisa 10", "d": "Enxerga o passe entre as linhas. O time joga em volta dele.", "w": {Attr.VIS: 0.7, Attr.PAS: 0.5, Attr.TEC: 0.4}, "b": 0.5, "fx": {"t": {"through": 0.06}, "k": {5: 1.35}}, "ins": "prender"},
		{"k": "driblador", "n": "Meia driblador", "d": "Parte para cima no um contra um.", "w": {Attr.DRI: 0.7, Attr.TEC: 0.3, Attr.ACE: 0.2}, "b": -1.0, "fx": {"t": {"dribble": 0.05}, "k": {3: 1.25}}},
		{"k": "chutador", "n": "Meia chutador", "d": "Chute forte de fora da área.", "w": {Attr.CHL: 0.8, Attr.TEC: 0.2}, "b": -1.5, "fx": {"t": {"long": 0.05}, "k": {2: 1.4}}, "ins": "chutar"},
		{"k": "infiltrador", "n": "Infiltrador", "d": "Meia que vira atacante: ataca a área sem a bola.", "w": {Attr.POS: 0.5, Attr.FIN: 0.5, Attr.ACE: 0.3}, "b": 4.0, "fx": {"t": {"through": 0.03, "scramble": 0.02}, "k": {0: 1.3}}, "ins": "avancar"},
		{"k": "pressao", "n": "Meia de pressão", "d": "Primeiro a pressionar a saída do rival: rouba bolas perto do gol.", "w": {Attr.RES: 0.5, Attr.DES: 0.4, Attr.VEL: 0.2}, "b": 9.0, "fx": {"t": {"scramble": 0.05}, "fat": 1.05}},
		{"k": "trequartista", "n": "Trequartista", "d": "Livre para flutuar atrás dos atacantes. Cria muito e quase não volta para marcar.", "w": {Attr.TEC: 0.5, Attr.DRI: 0.4, Attr.VIS: 0.4}, "b": -0.4, "fx": {"t": {"through": 0.03, "dribble": 0.03}, "o": {"counter": 0.02}, "k": {3: 1.15, 5: 1.15}}},
		{"k": "enganche", "n": "Enganche", "d": "Camisa 10 à moda antiga: segura a bola, atrai a marcação e solta no tempo certo. Não corre, pensa.", "w": {Attr.TEC: 0.5, Attr.VIS: 0.4, Attr.FRI: 0.3, Attr.DEC: 0.2}, "b": 0.5, "fx": {"t": {"through": 0.03, "dribble": 0.02}, "poss": 0.01, "k": {5: 1.2, 3: 1.1}}, "ins": "prender"},
	],
	"W": [
		{"k": "ponta", "n": "Ponta", "d": "Ponta de ofício: abre o campo e busca o fundo.", "w": {}, "b": 4.0, "fx": {}},
		{"k": "invertido", "n": "Ponta invertido", "d": "Joga do lado trocado: corta para dentro e chuta com a perna boa.", "w": {Attr.FIN: 0.4, Attr.CHL: 0.4, Attr.DRI: 0.3}, "b": 7.0, "inv": true, "fx": {"t": {"dribble": 0.03, "long": 0.03, "cross": -0.03}, "k": {0: 1.2, 2: 1.2, 6: 0.75}}},
		{"k": "flecha", "n": "Flecha", "d": "Velocidade pura: ataca as costas do lateral.", "w": {Attr.ACE: 0.6, Attr.VEL: 0.6}, "b": -1.5, "fx": {"t": {"counter": 0.06}, "k": {4: 1.3}}, "ins": "infiltrar"},
		{"k": "driblador", "n": "Ponta driblador", "d": "Chama o marcador para o drible e cava faltas.", "w": {Attr.DRI: 0.7, Attr.TEC: 0.3}, "b": -1.5, "fx": {"t": {"dribble": 0.05}, "k": {3: 1.3}}},
		{"k": "garcom", "n": "Ponta garçom", "d": "Mais assistências que gols: acha o companheiro livre.", "w": {Attr.PAS: 0.5, Attr.VIS: 0.5, Attr.CRU: 0.2}, "b": 4.0, "fx": {"t": {"through": 0.04}, "k": {5: 1.3}}},
		{"k": "finalizador", "n": "Ponta finalizador", "d": "Ponta com faro de gol: fecha na segunda trave.", "w": {Attr.FIN: 0.7, Attr.FRI: 0.3, Attr.POS: 0.2}, "b": 4.0, "fx": {"k": {0: 1.3, 1: 1.1}}},
		{"k": "cruzador", "n": "Ponta cruzador", "d": "Chega à linha de fundo e põe a bola na cabeça do centroavante.", "w": {Attr.CRU: 0.9}, "b": -1.0, "fx": {"t": {"cross": 0.06}, "k": {6: 1.35}}, "ins": "abrir"},
		{"k": "incansavel", "n": "Ala incansável", "d": "Volta para marcar o lateral e ainda aparece no ataque.", "w": {Attr.RES: 0.6, Attr.DES: 0.3, Attr.MAR: 0.2}, "b": 4.5, "fx": {"o": {"cross": -0.04}, "fat": 0.9}},
		{"k": "espacos", "n": "Intérprete de espaços", "d": "Some do jogo e aparece livre na área na hora certa. Pouco drible, muito gol.", "w": {Attr.POS: 0.6, Attr.FIN: 0.4, Attr.INT: 0.4}, "b": 4.6, "fx": {"t": {"scramble": 0.03}, "k": {0: 1.25, 3: 0.85}}},
		{"k": "ponta_area", "n": "Ponta de área", "d": "Abre pela ponta e fecha na segunda trave para cabecear os cruzamentos do outro lado.", "w": {Attr.CAB: 0.6, Attr.FOR: 0.4}, "b": 4.0, "h": 0.3, "fx": {"t": {"cross": 0.03}, "k": {1: 1.3}}},
		{"k": "falso", "n": "Falso ponta", "d": "Parte da ponta para o meio e vira mais um meia: tabela, prende e deixa o corredor para o lateral.", "w": {Attr.PAS: 0.4, Attr.TEC: 0.4, Attr.DEC: 0.3}, "b": 4.0, "fx": {"t": {"through": 0.03}, "poss": 0.01, "k": {5: 1.2, 6: 0.85}}, "ins": "prender"},
	],
	"ST": [
		{"k": "tecnico", "n": "Atacante técnico", "d": "Centroavante completo, sem uma marca só.", "w": {}, "b": 3.5, "fx": {}},
		{"k": "area", "n": "Homem de área", "d": "Vive dentro da área: rebote, desvio e gol de oportunista.", "w": {Attr.POS: 0.7, Attr.FIN: 0.4, Attr.FRI: 0.2}, "b": 0.5, "fx": {"t": {"scramble": 0.04}, "k": {0: 1.3, 1: 1.15, 5: 0.8}}, "ins": "frente"},
		{"k": "cacador", "n": "Caçador de espaços", "d": "Vive na linha do impedimento esperando a bola nas costas da zaga.", "w": {Attr.ACE: 0.5, Attr.VEL: 0.4, Attr.POS: 0.3}, "b": -1.0, "fx": {"t": {"through": 0.04, "counter": 0.04}, "k": {4: 1.3}}, "ins": "infiltrar"},
		{"k": "pivo", "n": "Pivô", "d": "Segura a bola de costas, briga com os zagueiros e ganha pelo alto.", "w": {Attr.FOR: 0.6, Attr.CAB: 0.6, Attr.PAS: 0.2}, "b": 0.0, "h": 0.3, "fx": {"t": {"cross": 0.04, "long": 0.05}, "k": {1: 1.3, 5: 1.1}}},
		{"k": "falso9", "n": "Falso 9", "d": "Sai da área para armar: abre espaço para quem chega de trás.", "w": {Attr.PAS: 0.5, Attr.VIS: 0.5, Attr.DRI: 0.3, Attr.TEC: 0.2}, "b": 6.0, "fx": {"t": {"through": 0.08, "dribble": 0.02}, "poss": 0.01, "k": {0: 0.75, 5: 1.5}}, "ins": "recuar"},
		{"k": "matador", "n": "Matador", "d": "Não precisa de muitas: é chance e gol.", "w": {Attr.FIN: 0.7, Attr.FRI: 0.5}, "b": -1.5, "fx": {"k": {0: 1.25}}},
		{"k": "segundo", "n": "Segundo atacante", "d": "Circula atrás do centroavante, dribla e chuta de fora.", "w": {Attr.DRI: 0.4, Attr.CHL: 0.4, Attr.PAS: 0.3}, "b": 4.5, "fx": {"t": {"long": 0.03, "dribble": 0.03}, "k": {2: 1.2, 5: 1.15}}},
		{"k": "pressao", "n": "Atacante de pressão", "d": "Primeiro defensor do time: persegue zagueiro e goleiro até o erro.", "w": {Attr.RES: 0.5, Attr.DES: 0.3, Attr.ACE: 0.3}, "b": 10.0, "fx": {"t": {"scramble": 0.05}, "poss": 0.01, "fat": 1.05}},
		{"k": "cabeceador", "n": "Cabeceador", "d": "Gol de cabeça é a especialidade: o time procura a cabeça dele em todo cruzamento.", "w": {Attr.CAB: 0.8, Attr.POS: 0.2}, "b": -2.5, "h": 0.4, "fx": {"t": {"cross": 0.03}, "k": {1: 1.4, 0: 0.95}}},
		{"k": "movel", "n": "Atacante móvel", "d": "Cai pelos lados, puxa o zagueiro para fora e abre espaço para quem chega de trás.", "w": {Attr.VEL: 0.4, Attr.DRI: 0.4, Attr.CRU: 0.3}, "b": 4.5, "fx": {"t": {"dribble": 0.03, "cross": 0.02}, "k": {3: 1.15, 6: 1.1, 0: 0.9}}},
	],
}

## Traços secundários (qualquer função de linha, ou só goleiro): mesmo esquema, efeitos menores.
const TRAITS: Array = [
	{"k": "aereo", "n": "Jogo aéreo", "w": {Attr.CAB: 0.7, Attr.FOR: 0.3}, "h": 0.3, "fx": {"k": {1: 1.15}}},
	{"k": "arremate", "n": "Arremate de fora", "w": {Attr.CHL: 1.0}, "fx": {"k": {2: 1.2}}},
	{"k": "arranque", "n": "Arranque", "w": {Attr.ACE: 0.7, Attr.VEL: 0.3}, "b": -1.0, "fx": {"k": {4: 1.15}}},
	{"k": "drible", "n": "Drible curto", "w": {Attr.DRI: 0.8, Attr.TEC: 0.2}, "fx": {"k": {3: 1.15}}},
	{"k": "passe", "n": "Passe vertical", "w": {Attr.VIS: 0.6, Attr.PAS: 0.4}, "fx": {"k": {5: 1.12}}},
	{"k": "cruzamento", "n": "Bola cruzada", "w": {Attr.CRU: 1.0}, "fx": {"k": {6: 1.15}}},
	{"k": "folego", "n": "Fôlego", "w": {Attr.RES: 1.0}, "fx": {"fat": 0.93}},
	{"k": "roubo", "n": "Roubo de bola", "w": {Attr.DES: 0.7, Attr.INT: 0.3}, "fx": {"k": {8: 0.85}}},
	{"k": "frieza", "n": "Frieza", "w": {Attr.FRI: 0.7, Attr.DEC: 0.3}, "fx": {"k": {0: 1.08}}},
	{"k": "lideranca", "n": "Liderança", "w": {Attr.INT: 0.4, Attr.DEC: 0.3, Attr.DIS: 0.3}, "b": -1.5, "fx": {"k": {8: 0.9}}},
	{"k": "bolaparada", "n": "Bola parada", "w": {Attr.CHL: 0.5, Attr.CRU: 0.3, Attr.TEC: 0.2}, "b": -0.5, "fx": {"k": {2: 1.08, 6: 1.08}}},
	{"k": "leitura", "n": "Leitura de jogo", "w": {Attr.INT: 0.5, Attr.POS: 0.5}, "b": -0.5, "fx": {"k": {8: 0.92}}},
	{"k": "corpo", "n": "Força física", "w": {Attr.FOR: 1.0}, "b": -0.5, "fx": {"k": {1: 1.06}}},
]
const GK_TRAITS: Array = [
	{"k": "pes", "n": "Jogo com os pés", "w": {Attr.PAS: 0.7, Attr.TEC: 0.3}, "b": 12.0, "fx": {}},
	{"k": "reflexo", "n": "Reflexo rápido", "w": {Attr.REF: 1.0}, "fx": {}},
	{"k": "saida", "n": "Saída do gol", "w": {Attr.ACE: 0.5, Attr.VEL: 0.5}, "b": 14.0, "fx": {}},
	{"k": "comando", "n": "Comando de área", "w": {Attr.CAB: 0.3, Attr.FOR: 0.3, Attr.INT: 0.4}, "b": 6.0, "h": 0.4, "fx": {}},
	{"k": "penalti", "n": "Especialista em pênaltis", "w": {Attr.REF: 0.5, Attr.FRI: 0.5}, "fx": {}},
]
## Destaque mínimo (pontos acima do overall) para o jogador ganhar um traço.
const TRAIT_MIN := 3.0


static func _role(pos: int) -> String:
	match pos:
		Pos.GK:
			return "GK"
		Pos.CB:
			return "CB"
		Pos.RB, Pos.LB:
			return "FB"
		Pos.DM:
			return "DM"
		Pos.CM:
			return "CM"
		Pos.AM:
			return "AM"
		Pos.RM, Pos.LM, Pos.RW, Pos.LW:
			return "W"
	return "ST"


static func role_of(pos: int) -> String:
	return _role(pos)


static func _inverted(p: Player) -> bool:
	match p.position:
		Pos.RW, Pos.RM:
			return p.foot == Player.FOOT_LEFT
		Pos.LW, Pos.LM:
			return p.foot == Player.FOOT_RIGHT
	return false


static func _score(p: Player, e: Dictionary) -> float:
	var w: Dictionary = e.get("w", {})
	var o := float(p.overall)
	var s := 0.0
	var ws := 0.0
	for ai in w:
		s += (float(p.attrs[int(ai)]) - o) * float(w[ai])
		ws += float(w[ai])
	var v := (s / ws if ws > 0.0 else 0.0) + float(e.get("b", 0.0))
	if e.has("h"):
		v += clampf(float(p.height - 186), -8.0, 10.0) * float(e["h"])
	return v


## Estilo principal (dicionário de BY_ROLE) pela posição natural do jogador.
static func primary(p: Player) -> Dictionary:
	var list: Array = BY_ROLE[_role(p.position)]
	var best: Dictionary = list[0]
	var best_v := -1e9
	var inv := _inverted(p)
	for e: Dictionary in list:
		if bool(e.get("inv", false)) and not inv:
			continue
		var v := _score(p, e)
		if v > best_v:
			best_v = v
			best = e
	return best


## Traço secundário ({} se nada se destaca o bastante). Não repete o atributo que já define o estilo.
static func secondary(p: Player) -> Dictionary:
	var main := primary(p)
	var main_top := _top_attr(main)
	var list: Array = GK_TRAITS if p.position == Pos.GK else TRAITS
	var best: Dictionary = {}
	var best_v := TRAIT_MIN
	for e: Dictionary in list:
		if _top_attr(e) == main_top and main_top >= 0:
			continue
		if p.position == Pos.GK and String(e["k"]) == String(main["k"]):
			continue
		var v := _score(p, e)
		if v > best_v:
			best_v = v
			best = e
	return best


static func _top_attr(e: Dictionary) -> int:
	var w: Dictionary = e.get("w", {})
	var top := -1
	var tv := 0.0
	for ai in w:
		if float(w[ai]) > tv:
			tv = float(w[ai])
			top = int(ai)
	return top


## Nome do estilo principal (mostrado em todas as telas).
static func of(p: Player) -> String:
	return String(primary(p)["n"])


## "Falso 9 · Passe vertical" (estilo e traço, quando há traço).
static func full(p: Player) -> String:
	var sec := secondary(p)
	return of(p) if sec.is_empty() else "%s · %s" % [of(p), String(sec["n"])]


## Tudo para a interface (perfil, comparação): nome, traço, descrição, efeito no jogo e a
## instrução individual que combina com ele.
static func describe(p: Player) -> Dictionary:
	var e := primary(p)
	var sec := secondary(p)
	var ins := String(e.get("ins", ""))
	return {
		"key": String(e["k"]), "name": String(e["n"]), "desc": String(e["d"]),
		"trait": String(sec.get("n", "")), "trait_key": String(sec.get("k", "")),
		"effect": effect_text(e.get("fx", {})), "trait_effect": effect_text(sec.get("fx", {})),
		"instruction": ins, "instruction_name": String(TeamSheet.INSTRUCTIONS.get(ins, {}).get("name", "")),
	}


const _TYPE_NAMES := {"through": "passes em profundidade", "cross": "cruzamentos", "long": "chutes de fora", "dribble": "jogadas de drible",
	"counter": "contra-ataques", "scramble": "bolas roubadas no ataque"}
const _MODE_NAMES := ["finaliza mais", "cabeceia mais", "arrisca mais de longe", "dribla mais", "puxa mais contra-ataques", "dá mais passes decisivos",
	"cruza mais", "participa mais", "erra menos atrás"]


## Efeito no motor em uma frase curta ("Time cria mais passes em profundidade; dá mais passes decisivos").
static func effect_text(fx: Dictionary) -> String:
	var parts: Array = []
	var t: Dictionary = fx.get("t", {})
	var more: Array = []
	var less: Array = []
	for k in t:
		(more if float(t[k]) > 0.0 else less).append(String(_TYPE_NAMES.get(k, k)))
	if not more.is_empty():
		parts.append("time cria mais " + ", ".join(PackedStringArray(more)))
	if not less.is_empty():
		parts.append("menos " + ", ".join(PackedStringArray(less)))
	var o: Dictionary = fx.get("o", {})
	var opp: Array = []
	for k in o:
		if float(o[k]) < 0.0:
			opp.append(String(_TYPE_NAMES.get(k, k)))
	if not opp.is_empty():
		parts.append("rival consegue menos " + ", ".join(PackedStringArray(opp)))
	var km: Dictionary = fx.get("k", {})
	for m in km:
		var mv := float(km[m])
		if int(m) == 8:
			if mv < 1.0:
				parts.append(String(_MODE_NAMES[8]))
		elif mv > 1.0 and int(m) < _MODE_NAMES.size():
			parts.append(String(_MODE_NAMES[int(m)]))
		elif mv < 0.9 and int(m) == 0:
			parts.append("finaliza menos")
		elif mv < 0.9 and int(m) == 6:
			parts.append("cruza menos")
	if float(fx.get("fat", 1.0)) < 1.0:
		parts.append("cansa menos")
	elif float(fx.get("fat", 1.0)) > 1.0:
		parts.append("cansa mais")
	if float(fx.get("cards", 1.0)) > 1.0:
		parts.append("leva mais cartões")
	if parts.is_empty():
		return "Sem efeito especial: rende pelos atributos."
	var s := "; ".join(PackedStringArray(parts))
	return s.substr(0, 1).to_upper() + s.substr(1) + "."


# ---------------------------------------------------------------------------
# Treino de estilo (TrainingManager): estilos possíveis para o jogador e distância até cada um
# ---------------------------------------------------------------------------

## Estilos que o jogador pode desenvolver na função natural (o "ponta invertido" só para quem
## joga do lado trocado; os estilos-padrão da função, sem atributos, ficam de fora).
static func options_for(p: Player) -> Array:
	var out: Array = []
	var inv := _inverted(p)
	for e: Dictionary in BY_ROLE[_role(p.position)]:
		if Dictionary(e.get("w", {})).is_empty():
			continue
		if bool(e.get("inv", false)) and not inv:
			continue
		out.append(e)
	return out


static func find(p: Player, key: String) -> Dictionary:
	for e: Dictionary in BY_ROLE[_role(p.position)]:
		if String(e["k"]) == key:
			return e
	return {}


## Quanto falta para o estilo `key` virar o principal (pontos de perfil; 0 = já é).
static func gap_to(p: Player, key: String) -> float:
	var e := find(p, key)
	if e.is_empty():
		return 0.0
	var main := primary(p)
	if String(main["k"]) == key:
		return 0.0
	return maxf(0.0, _score(p, main) - _score(p, e))


## Atributos do estilo, do mais importante ao menos.
static func attrs_of(e: Dictionary) -> Array:
	var w: Dictionary = e.get("w", {})
	var ks: Array = w.keys()
	ks.sort_custom(func(a, b): return float(w[a]) > float(w[b]))
	var out: Array = []
	for k in ks:
		out.append(int(k))
	return out
