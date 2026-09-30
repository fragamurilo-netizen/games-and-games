GAME DESIGN BIBLE

CORNER OFFICE

MMA Promoter Simulator

**Build stars. Make fights. Own the night.**

| Documento-mestre de produto, mundo, sistemas, simulação, conteúdo, UX, arquitetura técnica e identidade. O jogo é um simulador mobile de presidente/promotor de MMA, focado em gestão, narrativa emergente e um ecossistema que continua vivo por décadas. |
|----|

Versão 1.0 • Setembro de 2026

NORTE

# 0. Foco do produto (revisão de 30/09/2026 — prevalece sobre o restante)

Decisão do dono do projeto: Corner Office é **um simulador do universo de uma grande liga de MMA, no molde do UFC**, e não um simulador de vários negócios ao mesmo tempo. A liga é **a nossa**. As demais organizações continuam existindo, mas são pano de fundo: circuito regional, celeiro de talentos e, de vez em quando, concorrência por um nome.

O coração do jogo:

1. **Descobrir atletas**: prospects surgem no circuito regional e em outras ligas, com cartel, idade, base marcial e origem coerentes. O jogador observa, contrata cedo ou espera.
2. **Acompanhar carreiras**: evolução, auge, declínio, lesões, sequências, cinturões, aposentadoria e eventuais retornos, sempre emergindo da simulação.
3. **Desenrolar das coisas**: rankings top 15 por divisão, campeões, title shots discutíveis, rivalidades e notícias com gatilho factual.
4. **Assistir às lutas**: a transmissão do Fight Studio é o momento de recompensa.

Estrutura da liga (fictícia, sem marcas, pessoas ou eventos reais — ver §22):

- 8 divisões masculinas (mosca a pesado) e 4 femininas (palha a pena), elenco total na casa de 550–650 atletas, distribuído por divisão como numa grande liga real.
- Um campeão e um ranking oficial top 15 por divisão; World Combat Index independente para o mundo inteiro.
- Eventos numerados (cards principais) e fight nights, com main event de 5 rounds.

Realismo é requisito, não enfeite: geração de atletas (demografia, etnia, nomes, biotipo, base marcial por país sem determinismo), curvas de idade por divisão, cartéis plausíveis, métodos de vitória por divisão e sexo, rankings com qualidade de oposição e inatividade. Economia, mídia, contratos e IA rival ficam em nível suficiente para sustentar esse núcleo, e não disputam prioridade com ele.

# 1. Visão do produto

Corner Office é um simulador de gestão de MMA em que o jogador assume a presidência de uma organização e controla matchmaking, contratos, eventos, negociações, finanças, mídia, rankings, scouting e expansão global. As lutas são simuladas; a habilidade do jogador está em construir o ecossistema, identificar talentos, criar confrontos, equilibrar risco e retorno e reagir a um mundo imprevisível.

| A fantasia não é “ser o lutador”. É ser a pessoa que decide quais carreiras se cruzam, onde, quando, por quanto e com quais consequências. |
|----|

## Pilares

| **Pilar** | **O que significa na prática** |
|----|----|
| Mundo vivo | Organizações rivais contratam, demitem, quebram, crescem, produzem campeões e disputam atletas sem depender do jogador. |
| Matchmaking profundo | Estilo, ranking, contexto comercial, agenda, lesões, rivalidade e contratos tornam cada luta uma decisão. |
| Narrativa emergente | Histórias surgem de sistemas: azarões, quedas de card, guerras contratuais, decisões polêmicas, superlutas e aposentadorias. |
| Mobile-first | Sessões curtas funcionam, mas há profundidade para saves de décadas. Ações frequentes ficam a poucos toques. |
| Identidade de personagem | Rostos procedurais do Mais Uma Rodada evoluem para atletas de MMA reconhecíveis, envelhecendo ao longo da carreira. |

## Modelo de sessão

- Micro: 2–5 minutos para responder mensagens, aprovar lutas, revisar scouting ou avançar alguns dias.

- Médio: 10–20 minutos para montar um evento, negociar contratos e simular uma noite de lutas.

- Longo: 45+ minutos para reorganizar divisões, atacar free agency, negociar mídia e planejar a temporada.

## Público

Jogadores de Football Manager, Motorsport Manager, TEW, Wrestling GM, simuladores esportivos, fantasy booking e fãs de MMA que preferem gestão a controle de combate.

UNIVERSO

# 2. O mundo: The Open Era

A campanha padrão começa em janeiro de 2027, no início da chamada The Open Era. O mercado global de MMA se fragmentou após a renegociação de grandes direitos de mídia, a entrada de capital privado e o vencimento simultâneo de contratos de dezenas de atletas. Nenhuma empresa controla sozinha o esporte. O resultado é um ecossistema agressivo, internacional e instável.

## Escala inicial sugerida

| **Camada** | **Quantidade** | **Função** |
|----|----|----|
| Organizações globais | 7 | Grandes marcas com TV/streaming, estrelas e disputa internacional. |
| Organizações nacionais | 24–30 | Operam em um ou mais países, alimentam a camada global e podem ascender. |
| Organizações regionais | 80–120 | Principal fonte de prospects; surgem e desaparecem com frequência. |
| Lutadores profissionais | 2.200–2.800 | Distribuídos por sexo, peso, região, nível, idade e organização. |
| Academias relevantes | 180–250 | Geram identidade técnica, relacionamentos e desenvolvimento. |
| Agentes/agências | 60–90 | Controlam clusters de talentos e têm memória das negociações. |
| Veículos de mídia | 12–20 | Geram reputação, narrativas, rankings independentes e pressão pública. |

## História anterior ao save

O banco de dados deve conter aproximadamente 30–35 anos de história fictícia. Campeões anteriores, grandes lutas, recordes, eventos clássicos e organizações extintas evitam a sensação de que o universo nasceu no dia 1. A primeira temporada precisa começar com mitologia já existente.

## Geografia do MMA

| **Região** | **Tendências probabilísticas** | **Valor para o gameplay** |
|----|----|----|
| Brasil | BJJ, Muay Thai, boxe agressivo, enorme profundidade regional | Prospects numerosos; forte apelo doméstico. |
| EUA | Wrestling colegial, boxe, academias completas, mídia | Maior mercado comercial inicial. |
| México | Boxe, cardio, pressão, fãs intensos | Mercado de estrelas e grandes arenas. |
| Europa | Kickboxing, grappling diverso, expansão regulatória | Crescimento rápido e circuitos nacionais. |
| Cáucaso/Ásia Central | Wrestling, sambo, grappling de controle | Talentos tecnicamente difíceis e menos comercializados. |
| Japão/Coreia | Judô, karate, kickboxing, tradição de eventos | Apresentação e formatos diferenciados. |
| Austrália/NZ | Striking, preparação física, mercado organizado | Hub do Pacífico. |
| Oriente Médio | Capital, eventos especiais e garantias elevadas | Mercado de eventos premium. |

MUNDO

# 3. As grandes organizações

| **Organização** | **Base** | **Rep.** | **Modelo** | **Tensão inicial** |
|----|----|----|----|----|
| Crown Combat | EUA / Las Vegas | 94 | PPV e superestrelas | Roster caro; contratos-chave vencendo entre 2027–29. |
| Ascend Fighting | EUA / Los Angeles | 87 | Streaming e volume | Agressiva em prospects e free agency. |
| Vale Combat | Brasil / São Paulo | 73 | Talentos latino-americanos | Quer deixar de ser feeder e virar potência global. |
| Shinsei | Japão / Tóquio | 78 | Grand Prix, tradição e megaeventos | Apelo cultural único e grandes noites de fim de ano. |
| Frontline | Reino Unido / Londres | 72 | Eventos europeus e produção | Busca uma superestrela global. |
| Iron Circle | Cazaquistão / Almaty | 69 | Grappling, sambo e atletas duros | Roster tecnicamente profundo e comercialmente subestimado. |
| Pacific Fight League | Austrália / Sydney | 65 | Pacífico e Ásia | Boa saúde financeira e pipeline regional. |

## Organizações como agentes autônomos

- Definem metas por temporada: crescimento, corte de custos, expansão geográfica, retenção de campeão ou entrada em novo mercado.

- Possuem personalidade executiva: conservadora, agressiva, prospect-first, star-first, financially disciplined, expansionist.

- Negociam arenas, mídia e atletas com orçamento limitado, evitando comportamento onisciente.

- Podem trocar presidente, vender participação, receber investimento, sofrer sanções, reduzir eventos ou encerrar operações.

- Aprendem com contexto de mercado: uma rival que perde seu campeão pode superpagar outro nome para preservar calendário.

## Modos de início

| **Modo** | **Situação inicial** | **Dificuldade** |
|----|----|----|
| From Nothing | US\$ 250 mil, sem atletas, sem mídia, reputação mínima. | Alta |
| Regional Promoter | 20–40 atletas, base local, um cinturão, caixa limitado. | Média |
| Executive | Assume organização global existente com pressão imediata. | Alta por complexidade |
| Sandbox | Configura caixa, reputação, regras e tamanho da organização. | Customizável |

PERSONAGENS

# 4. Lutadores: identidade, atributos e carreira

Cada lutador é um agente com corpo, técnica, personalidade, histórico, relações, ambição e trajetória própria. Overall existe apenas como resumo; a simulação nunca deve depender dele isoladamente.

## Ficha essencial

| **Grupo** | **Campos** |
|----|----|
| Identidade | Nome, apelido, país, cidade, idioma, academia, agente, personalidade pública. |
| Biometria | Idade, altura, envergadura, peso natural, postura, biotipo, categoria. |
| Carreira | Recorde, organização, ranking, cinturões, últimas lutas, suspensões, lesões. |
| Contrato | Lutas restantes, bolsa, win bonus, PPV points, garantias, cláusulas. |
| Mercado | Popularidade por região, carisma, social reach, draw estimado, sponsor value. |

## Atributos técnicos

| **Família** | **Exemplos** |
|----|----|
| Striking | Boxe, jab, combinações, defesa, precisão, potência, chutes, low kicks, joelhadas, cotoveladas, countering. |
| Grappling | Wrestling ofensivo, defesa de quedas, clinch, cage control, top control, scramble, ground-and-pound. |
| Jiu-Jitsu | Guarda, transições, ataques de submissão, defesa, back control, leg locks. |
| Físico | Força, explosão, velocidade, cardio, durabilidade, queixo, recuperação, mobilidade. |
| Mental | Fight IQ, disciplina, adaptação, compostura, agressividade, paciência, clutch. |

## Atributos ocultos

- Tolerância à pressão e resposta a adversidade.

- Propensão a aceitar guerras e tendência a lutar lesionado.

- Disciplina de camp e facilidade/dificuldade no corte de peso.

- Ambição, ego, lealdade, profissionalismo e volatilidade.

- Risco de lesão, recuperação entre lutas e sensibilidade a dano acumulado.

- Carisma natural, habilidade em entrevistas e potencial de popularidade.

- Preferência por atividade, money fights, ranking ou cinturão.

## Potencial dinâmico

Potencial não é um teto rígido. É uma distribuição influenciada por idade, academia, qualidade de treino, atividade, lesões, confiança, adversários e disciplina. Um prospect de elite pode estagnar; um atleta subestimado pode superar projeções.

ARTE DE PERSONAGEM

# 5. Sistema visual de rostos e corpos

O jogo deve reaproveitar o gerador facial do Mais Uma Rodada como base estrutural para preservar assinatura de estúdio. O objetivo não é trocar o estilo, mas ampliar a biblioteca e adaptar seus sinais visuais ao MMA.

## Camadas faciais novas

- Formatos adicionais de crânio, mandíbula, nariz e sobrancelha.

- Orelhas de couve-flor em múltiplos níveis.

- Narizes tortos, cicatrizes, cortes e marcas pós-luta.

- Buzz cut, cabeça raspada, afro, tranças, cornrows, dreadlocks, mullet e cabelo longo.

- Barba cheia, stubble, cavanhaque, bigodes e combinações.

- Tatuagens opcionais em rosto, pescoço, tronco e braços, com regras de densidade para não virar ruído.

- Hematomas e cortes temporários após lutas, desaparecendo com recuperação.

## Biotipos

| **Tipo** | **Características visuais** | **Distribuição típica** |
|----|----|----|
| Lean | Baixa massa, membros longos, definição moderada. | Mosca a pena |
| Athletic | Proporção equilibrada e atlética. | Todas |
| Compact | Tronco denso, centro de gravidade baixo. | Galo a médio |
| Muscular | Massa visível, ombros largos. | Pena a meio-pesado |
| Heavy | Volume corporal alto, variação de gordura/músculo. | Pesado |

## Envelhecimento e continuidade visual

Rostos devem envelhecer sem trocar identidade: rarefação capilar, fios grisalhos, pele mais madura, acúmulo de cicatrizes e mudanças de barba/cabelo. O jogador precisa reconhecer um atleta aos 19 e aos 35 anos.

SIMULAÇÃO

# 6. Motor de luta

A luta é uma simulação probabilística baseada em estados. O motor deve evitar o determinismo de Overall. Matchup, estratégia, dano, fadiga, alcance, idade, camp e comportamento moldam a luta round a round.

## Modelo de round

1\. Inicializar estado: energia, dano por zona, momentum, confiança e plano de luta.

2\. Escolher intenção do lutador de acordo com estilo, instruções, leitura do oponente e situação do round.

3\. Resolver exchanges discretas: striking, clinch, takedown, scramble, ground sequence.

4\. Aplicar consequências: dano, fadiga, posição, knockdown, cut, controle, risco de finalização.

5\. Atualizar adaptação entre rounds: corner advice, urgência, mudança de ritmo e exploração de fraquezas.

6\. Pontuar round por juiz individual, mantendo possibilidade de divergência.

## Resultados

| **Tipo**  | **Variantes**                                              |
|-----------|------------------------------------------------------------|
| KO/TKO    | Golpe limpo, sequência, ground-and-pound, doctor stoppage. |
| Submissão | Choke, arm lock, leg lock e outras famílias.               |
| Decisão   | Unânime, dividida, majoritária; cards 10-point must.       |
| Outros    | Empate, no contest, DQ, interrupção médica.                |

## Controvérsia como sistema

Decisões apertadas podem produzir percepção pública divergente do resultado oficial. Mídia, atletas e fãs podem tratar a luta como roubo, revanche necessária ou vitória convincente. O jogo não deve declarar que o juiz 'errou' sem base; ele simula percepção e desacordo.

## Matchup

- Striker de elite pode sofrer contra wrestler com excelente chain wrestling.

- Lutador de grappling pode ter dificuldades contra adversário de alta defesa de quedas e cardio superior.

- Alcance, stance e velocidade alteram frequência e eficiência de trocas.

- Queixo e dano acumulado tornam veteranos mais vulneráveis mesmo mantendo técnica alta.

- Camp curto aumenta variância e reduz execução estratégica.

- Atletas inteligentes adaptam entre rounds; atletas rígidos insistem no plano inicial.

CORE LOOP

# 7. Matchmaking e divisões

Matchmaking é o coração do jogo. Cada confronto deve equilibrar mérito esportivo, risco de negócio, narrativa, disponibilidade e contratos.

## Tela de proposta de luta

| **Informação**         | **Exemplo**                 |
|------------------------|-----------------------------|
| Ranking                | \#2 vs \#4                  |
| Recorde                | 20-2 vs 17-1                |
| Forma                  | W4 vs W3                    |
| Disponibilidade        | 82% / 100%                  |
| Camp                   | 8 semanas / 6 semanas       |
| Interesse esperado     | Muito alto                  |
| Consequência esportiva | Possível title eliminator   |
| Custo projetado        | US\$ 620 mil de bolsas      |
| Risco                  | Alto risco de recusa do \#2 |

## Recusa e negociação

- Atleta pode recusar por dinheiro, ranking, pouco camp, lesão, estratégia de carreira, adversário perigoso ou promessa anterior.

- Agente pode exigir extensão contratual junto com a luta.

- Atletas podem aceitar short notice em troca de bônus, promessa de title shot ou cláusula contratual.

- Repetidas decisões percebidas como injustas afetam relação com atleta e agente.

## Rankings

Cada organização mantém ranking por divisão e cinturões; o World Combat Index mantém ranking independente global e P4P. Os rankings devem considerar resultado, qualidade de oposição, sequência, atividade e posição anterior, com pequena margem subjetiva simulada.

PRODUÇÃO

# 8. Eventos, calendário e noite de lutas

## Tipos de evento

| **Formato** | **Uso** | **Economia** |
|----|----|----|
| PPV | Grandes cards e cinturões | Alta receita potencial, alto custo. |
| Fight Night | Desenvolvimento e frequência | Streaming/TV, custo controlado. |
| International Series | Construir mercados | Receita variável, forte ganho regional. |
| Stadium Event | Superlutas | Altíssimo risco e gate potencial. |
| Prospect Series | Descoberta de talentos | Baixo custo, geração de pipeline. |
| Grand Prix | Formato de torneio | Narrativa forte, logística e lesões elevadas. |

## Estrutura do card

- Main Event

- Co-Main Event

- Main Card

- Prelims

- Early Prelims

## Queda de luta

Lesões, problemas de visto, falha no peso ou doença podem derrubar lutas. O jogo deve abrir imediatamente uma tela de crise com candidatos a substituto, tempo restante, custo, risco e interesse estimado.

## Pesagem

- Bater peso, falhar, desistir do corte ou passar mal.

- Catchweight, multa percentual, cancelamento ou perda de elegibilidade ao cinturão.

- Histórico de cortes ruins influencia decisões futuras de matchmaking e mudança de divisão.

NEGÓCIO

# 9. Contratos, agentes e free agency

## Estrutura de contrato

| **Campo** | **Exemplos** |
|----|----|
| Prazo | Número de lutas + janela temporal. |
| Bolsa | Show money e win bonus. |
| Upside | PPV points, gate bonus, performance bonus. |
| Garantias | Signing bonus, minimum guarantee. |
| Cláusulas | Champion clause, extension, matching rights, exclusividade. |
| Relacionamento | Promessas de ranking, main event, local de luta ou frequência. |

## Agências

| **Agência** | **Perfil** | **Comportamento** |
|----|----|----|
| Blackstone Sports | Estrelas globais | Agressiva; maximiza garantias. |
| Northstar Management | Prospects | Busca atividade e desenvolvimento. |
| Morales Sports | América Latina | Relacionamentos regionais fortes. |
| Crown & King | Pequena e combativa | Usa competição entre promotoras. |

Agentes têm memória. Uma negociação hostil com um cliente pode reduzir confiança em negociações futuras com outros representados da mesma agência.

NARRATIVA

# 10. Mídia, popularidade e rivalidades

| **Veículo** | **Papel** | **Tom** |
|----|----|----|
| FightWire | Breaking news | Rápido, factual, movimentações de mercado. |
| The Combat Journal | Jornalismo de profundidade | Negócio, contexto e análise. |
| Inside Fighting | TV/mesa redonda | Entrevistas e debate. |
| The Clinch | Tabloide esportivo | Rivalidades, provocações, bastidores. |
| FightMetric | Dados | Rankings, estatísticas e histórico. |

## Popularidade

Popularidade é regional e independente de habilidade. Um atleta tecnicamente mediano pode ser enorme vendedor; um campeão dominante pode ter apelo comercial limitado. A simulação deve separar draw, merit e skill.

## Rivalidades emergentes

- Trash talk e entrevistas.

- Decisão apertada ou controversa.

- Ex-companheiros de academia.

- Problema em coletiva ou pesagem.

- Disputa salarial pública.

- Promessa de title shot quebrada.

- Confrontos repetidos ao longo dos anos.

DESENVOLVIMENTO

# 11. Academias, scouting e pipeline

| **Academia** | **Base** | **Identidade** |
|----|----|----|
| Forge MMA | Las Vegas | Completa; alto custo e grande infraestrutura. |
| São Paulo Combat Lab | São Paulo | BJJ + striking; forte pipeline brasileiro. |
| Mountain House | Ásia Central | Wrestling e controle. |
| Kingsway MMA | Manchester | Striking + preparação física. |
| Shinjuku Fight Institute | Tóquio | Karate, judô e kickboxing. |
| Blackwater MMA | Flórida | Equipe de estrelas e grande mídia. |
| Mexico Fight House | CDMX | Boxe, pressão e cardio. |

## Scouting

- Atributos desconhecidos aparecem como faixas e confiança do scout.

- Mais tape, lutas observadas e camp reports aumentam precisão.

- Prospects podem surgir de wrestling, BJJ, kickboxing, muay thai, sambo, judô e circuito amador.

- O jogador pode contratar cedo e barato ou esperar por maior certeza e enfrentar concorrência.

## Contender Series / Prospect Series

Eventos próprios de avaliação permitem colocar prospects frente a frente. Após cada luta, o jogador pode contratar, passar ou manter observação. Derrota não invalida prospect: desempenho, idade, matchup e atributos importam.

GESTÃO

# 12. Economia e expansão

## Receitas e custos

| **Receitas**              | **Custos**          |
|---------------------------|---------------------|
| PPV                       | Bolsas e bônus      |
| Direitos de TV/streaming  | Produção            |
| Ingressos/gate            | Arena               |
| Patrocínios               | Viagens/logística   |
| Merchandise/licenciamento | Staff e scouting    |
| Garantias regionais       | Marketing e seguros |

## P&L por evento

Cada card deve ter projeção pré-evento e resultado real pós-evento. O jogador enxerga receita estimada, gate, audiência, payroll, custo de produção e margem. Estrelas elevam receita e custo ao mesmo tempo.

## Mídia

- Contratos com duração, exclusividade, mínimo de eventos e bônus por audiência.

- Pacotes separados por território ou globais.

- Renegociação influenciada por audiência recente, estabilidade do calendário e força das estrelas.

## Expansão regional

A popularidade da organização é separada por região. Eventos repetidos, estrelas locais e distribuição de mídia constroem mercados. Crescer no Brasil não implica automaticamente crescer no Japão.

LONGEVITY

# 13. Sistemas de mundo persistente

## Geração de novos lutadores

Regen deve respeitar distribuição probabilística de estilos por região sem transformar nacionalidade em destino. Nomes, aparência, idioma, base marcial, altura e biotipo precisam ser coerentes entre si e variados.

## Aposentadoria e legado

- Aposentadoria por idade, lesão, queda de performance, dinheiro, família ou falta de motivação.

- Retorno é possível, com risco real de performance inferior.

- Ex-atletas podem virar treinador, dono de academia, comentarista ou empresário.

- Hall da Fama considera títulos, defesas, qualidade de oposição, popularidade e impacto histórico.

## Recordes

| **Categoria** | **Exemplos**                                      |
|---------------|---------------------------------------------------|
| Performance   | Mais vitórias, KOs, submissões, sequências.       |
| Campeonato    | Defesas, reinados, campeão mais jovem/velho.      |
| Comercial     | Maior gate, maior PPV, maior bolsa.               |
| Histórico     | Mais lutas, longevidade, rivalidades e trilogias. |

## Efeito Borboleta

Mudanças devem propagar-se: campeão lesionado cria interino; interino vira estrela; estrela exige novo contrato; rival oferece mais; divisão perde draw; mídia reduz interesse; organização muda estratégia. O save precisa gerar cadeias, não eventos isolados.

ROSTER CANÔNICO

# 14. Personagens e estrelas de 2027

| **Lutador** | **País** | **Div.** | **Rec.** | **Gancho** |
|----|----|----|----|----|
| Malik “The King” Carter | EUA | Leve | 24-1 | Campeão Crown; boxe elite; enorme PPV; contrato termina em 18 meses. |
| Rafael “Fúria” Moreira | Brasil | Leve | 20-2 | \#1; BJJ elite + pressão; rival natural de Carter. |
| Magomed Arsanov | Cazaquistão | Meio-médio | 18-0 | Campeão Iron Circle; grappling excepcional; pouco conhecido nos EUA. |
| Mateo “El Diablo” Reyes | México | Pena | 17-1 | 26 anos; boxe agressivo; potencial superstar. |
| Jack “Zero” Holloway | Reino Unido | Médio | 22-3 | Campeão Frontline; técnico e pouco midiático. |
| Kenji Sato | Japão | Galo | 29-5 | 35 anos; lenda Shinsei; reta final de carreira. |
| Darius Cole | EUA | Médio | 12-0 | 24 anos; enorme hype; ainda sem teste de elite. |
| Ana “Tempestade” Costa | Brasil | Mosca F | 16-1 | Campeã Vale Combat; enorme no Brasil. |
| Sofia Markovic | Sérvia | Galo F | 18-2 | Campeã mundial; wrestling e mentalidade competitiva. |
| Jessica Monroe | EUA | Palha F | 13-0 | 25 anos; grande carisma; ainda sem oposição de elite. |

## Lendas ativas

- Aleksandr Volkovic, 40: ex-campeão dos pesados, última corrida competitiva.

- Thiago “Caveira” Ramos, 39: lenda brasileira, possível despedida em casa.

- Marcus Reed, 38: antigo rei dos meio-médios, buscando uma última grande luta.

## Evento histórico canônico

| Carter vs. Mendes I — Crown 198 (2022). Cinco rounds, decisão dividida, uma das maiores audiências da história. A discussão sobre o resultado ainda alimenta mídia, rankings históricos e pedidos de revanche. |
|----|

INTERFACE

# 15. UX mobile e arquitetura de navegação

O jogo precisa parecer um produto de esporte e gestão, não um dashboard SaaS. Cada área tem um objeto visual dominante e um propósito.

| **Aba** | **Objeto dominante** | **Função** |
|----|----|----|
| Início | Próximo evento + decisões | O que exige atenção agora. |
| Lutadores | Roster / rankings | Gerir e explorar atletas. |
| Eventos | Fight cards / calendário | Montar e operar noites. |
| Mercado | Busca / scouting / free agency | Encontrar e contratar talentos. |
| Organização | Identidade / finanças / mídia / staff | Administrar empresa. |

## Regras de UX

- Ações frequentes em até dois toques.

- Bottom navigation no mobile; rail/side navigation compacta em tablet.

- Bottom sheets para detalhes contextuais; evitar modal sobre modal.

- Listas densas quando a informação é tabular; surfaces apenas para entidades/eventos reais.

- Landscape usa master-detail, não mobile esticado.

- Touch targets confortáveis e safe areas respeitadas.

## Tela de luta

A luta deve ser acompanhável round a round com velocidades 1x, 2x, 5x e resultado instantâneo. O jogador observa stamina, dano, estatísticas e eventos, mas não controla golpes diretamente.

| O combate é espetáculo e informação. O jogo de verdade acontece antes e depois: matchmaking, contratos, risco e consequência. |
|----|

IDENTIDADE

# 16. Direção visual do produto

A identidade deve misturar broadcast esportivo, bastidores de promoção e sala de matchmaking. Evitar cópia de marcas reais de MMA. O resultado precisa ser reconhecível como Corner Office mesmo sem logos de organizações.

## Personalidade

| **Quero**                                    | **Evitar**                |
|----------------------------------------------|---------------------------|
| Brutalismo editorial controlado              | Neon / cyberpunk          |
| Tipografia forte e condensada                | Glassmorphism             |
| Preto, carvão, off-white e vermelho queimado | Gradiente roxo/azul       |
| Fotografia recortada e textura sutil         | Cards SaaS repetitivos    |
| Tabelas e scoreboards esportivos             | Bento grid                |
| Acento metálico/dourado raro                 | Dourado “luxo” em excesso |

## Sistema de cores proposto

| **Token**  | **Cor**  | **Uso**                                    |
|------------|----------|--------------------------------------------|
| Canvas     | \#111417 | Fundo global.                              |
| Surface    | \#1B2025 | Superfícies de navegação e painéis.        |
| Paper      | \#F1EEE6 | Conteúdo editorial, contratos, documentos. |
| Ink        | \#F4F1E8 | Texto primário em dark.                    |
| Muted      | \#8A939C | Metadados.                                 |
| Fight Red  | \#C83B3B | Ação, perigo, evento, resultado.           |
| Steel      | \#46535E | Estrutura e divisores.                     |
| Champ Gold | \#B88B46 | Cinturões, legado, raros destaques.        |

## Tipografia sugerida

- Display: família condensada forte, para placares, nomes de evento, rankings e chamadas.

- UI/Data: sans humanista altamente legível, com numerais tabulares.

- Evitar usar CAIXA ALTA em tudo; reservar para placar, categoria, round e micro-labels.

IMPLEMENTAÇÃO

# 17. Arquitetura técnica em Godot

## Separação

| simulation/data → domain services/controllers → UI/view models → presentation |
|----|

- A UI não implementa regra de combate, ranking, contrato ou economia.

- Sistemas de mundo rodam por tick temporal e eventos agendados.

- Entidades devem possuir IDs estáveis para saves longos.

- Dados históricos são append-oriented: lutas, contratos, títulos e rankings preservam audit trail.

- Gerador visual é desacoplado do objeto de simulação: aparência pode evoluir sem alterar atributos.

## Módulos sugeridos

| **Módulo**  | **Responsabilidade**                              |
|-------------|---------------------------------------------------|
| WorldSim    | Tempo, eventos globais, geração e aposentadoria.  |
| FightEngine | Round simulation, judging, damage e resultado.    |
| Matchmaking | Elegibilidade, interesse, ranking e propostas.    |
| Contracts   | Ofertas, cláusulas, agentes e free agency.        |
| Economy     | Receitas, custos, P&L, mídia e sponsors.          |
| Popularity  | Mercados regionais, draw e growth.                |
| Media       | Notícias, entrevistas, rivalidades e repercussão. |
| Identity    | Faces, corpos, aging e cosmetics.                 |
| SaveSystem  | Versionamento, migração e integridade.            |

## Performance

- Simulação fora da tela em níveis de detalhe: full detail para eventos relevantes, abstract sim para organizações menores.

- Pooling/virtualização para listas extensas.

- Cache de retratos e atualização visual apenas quando necessário.

- Processos pesados distribuídos por frames/ticks para evitar travamento em celulares medianos.

ESPECIFICAÇÃO

# 18. Modelo de dados mínimo

| **Entidade** | **Campos críticos** |
|----|----|
| Fighter | id, identity, biometrics, skills, hidden traits, style, popularity, contract_id, gym_id, agent_id, health. |
| Organization | id, brand, finances, roster, titles, media_deals, markets, strategy, staff. |
| Fight | fighters, division, event, date, stakes, result, scorecards, stats, damage. |
| Event | venue, market, card, budget, projected/actual economics, broadcast. |
| Contract | term, bouts_remaining, pay, bonuses, clauses, expiry, promises. |
| Gym | reputation, specialties, coaches, roster, region. |
| Agent | clients, traits, reputation, relationship map. |
| Ranking | organization, division, ordered entries, snapshot date. |
| NewsItem | entities, topic, tone, reach, created_at, consequences. |

## Versionamento de save

O save precisa suportar migrações de schema. Cada versão guarda número explícito; novas versões migram dados antigos com testes automatizados. Saves longos não podem quebrar a cada atualização.

COMPORTAMENTO

# 19. IA de mundo e narrativa emergente

## Diretores executivos rivais

Cada organização possui uma estratégia com pesos e limites: star power, mérito esportivo, caixa, risco, expansão e frequência. A IA avalia decisões sem acesso a informação secreta do jogador.

## Atletas

Atletas possuem objetivos de carreira e tolerâncias. Um veterano pode priorizar dinheiro; um prospect, atividade; um campeão, legado; uma estrela, PPV e superlutas.

## Sistema de eventos

| **Família** | **Exemplos** |
|----|----|
| Saúde | Lesão, doença, concussão, corte ruim. |
| Carreira | Mudança de divisão, aposentadoria, retorno, troca de academia. |
| Negócio | Holdout, sponsor, mídia, free agency, disputa contratual. |
| Evento | Problema de visto, luta cai, short notice, arena indisponível. |
| Narrativa | Trash talk, briga verbal, rivalidade, pedido de revanche. |
| Mercado | Rival recebe investimento, organização quebra, nova promotora surge. |

Eventos devem nascer de pré-condições do mundo. Evitar roleta de acontecimentos sem relação causal.

PRODUÇÃO

# 20. Vertical slice e roadmap

## Milestone 1 — Loop jogável

1\. Gerar mundo com 100+ lutadores e 3 organizações.

2\. Abrir roster, perfil e rankings.

3\. Contratar ou renovar atleta.

4\. Montar um evento com 6–10 lutas.

5\. Simular toda a noite de luta.

6\. Atualizar recordes e rankings.

7\. Calcular receita/custos.

8\. Gerar notícias.

9\. Avançar semana e repetir.

## Milestone 2 — Mercado vivo

- Agentes

- Free agency concorrida

- Scouting

- Organizações rivais operacionais

- Lesões e substitutos

- Popularidade regional

## Milestone 3 — Mundo de longo prazo

- Regens

- Aposentadorias

- Hall da Fama

- Academias dinâmicas

- Novas organizações

- Histórico e recordes

- Mídia mais profunda

## Milestone 4 — Profundidade de produto

- Reality show

- Grand Prix

- Patrocinadores

- Direitos de mídia

- Expansion packs de regiões/formatos

- Modding

QUALIDADE

# 21. QA, balanceamento e telemetria

## Testes de simulação

- Executar milhares de lutas automatizadas para verificar distribuição de KO, submissão e decisões por categoria.

- Simular 20–50 anos para detectar inflação de recordes, rankings travados, colapso econômico e falta de novos talentos.

- Testar se lutadores 90+ não se tornam invencíveis.

- Verificar frequência de title shots, rematches e campeões longos.

- Auditar diversidade regional e de estilos.

## Métricas internas de balanceamento

| **Métrica** | **Faixa a observar** |
|----|----|
| Lutas por atleta/ano | Varia por organização, idade e contrato. |
| % decisões / KO / sub | Por divisão e estilo. |
| Mudança de campeão | Evitar tanto estabilidade absoluta quanto caos. |
| Taxa de falha no peso | Baixa, mas material. |
| Lesões que derrubam luta | Raras o suficiente para não frustrar; comuns o suficiente para criar crises. |
| Concentração de receita | Estrelas importam sem tornar elenco irrelevante. |

ESTRATÉGIA

# 22. Produto, modding e propriedade intelectual

## IP

Corner Office deve lançar com universo, marcas, atletas e cinturões fictícios. Não copiar UFC, ONE, PFL, Bellator, Dana White, logos, trade dress, nomes de eventos, likeness de atletas ou layouts protegidos.

## Modding

A arquitetura deve ser mod-friendly desde cedo: bancos de dados externos para nomes, organizações, lutadores, logos, regras e cores. Mods ficam sob responsabilidade do usuário e não fazem parte do conteúdo oficial.

## Monetização recomendada

Para preservar a fantasia de simulação, priorizar premium ou premium + expansões substanciais. Evitar energy timers, pay-to-win e monetização que interfira nos resultados esportivos.

## Expansões possíveis

- World Expansion: novas regiões, academias e regras locais.

- Broadcast & Media: negociação avançada, produção e branding de eventos.

- Amateur to Pro: circuitos amadores e desenvolvimento de talentos.

- Legends Database: décadas adicionais de história fictícia e cenários históricos.

APÊNDICE

# 23. Brief de implementação para Claude

Use este documento como source of truth. Antes de codar, audite o projeto Mais Uma Rodada e extraia apenas módulos reutilizáveis sem acoplamento destrutivo.

1\. Crie branch/projeto separado.

2\. Mapeie o sistema de rostos e sua licença/estrutura de assets.

3\. Crie DESIGN.md e CLAUDE.md para este projeto.

4\. Implemente o vertical slice antes de adicionar sistemas periféricos.

5\. Não gere placeholders visuais genéricos; respeite o sistema de identidade descrito.

6\. Não copie nomenclatura ou identidade visual de organizações reais.

7\. Faça o mundo simular sem o jogador.

8\. Use testes de simulação para validar balanceamento.

9\. Capture screenshots mobile portrait/landscape em cada milestone.

10\. Só expanda depois que o core loop estiver divertido e estável.

BRANDING

# 24. Identidade visual — especificação para criação

## Nome

CORNER OFFICE

## Descriptor

MMA Promoter Simulator

## Tagline

Build stars. Make fights. Own the night.

## Conceito de marca

A marca combina o ambiente de decisão executiva com a tensão física do cage. O símbolo deve evitar luvas, octógonos literais e silhuetas de lutadores, que são clichês do gênero. A ideia recomendada é um monograma CO construído como uma marca de matchmaking: dois blocos que se encaram, separados por uma linha central semelhante a uma divisão de fight card.

## Logo

- Wordmark condensado e agressivo, porém legível em 24–32 px.

- Monograma CO capaz de funcionar como ícone de app.

- Versões horizontal, empilhada, monocromática e ícone.

- Nenhum elemento deve lembrar diretamente UFC ou outras promoções.

## Paleta

| **Nome**        | **HEX**  | **Papel**           |
|-----------------|----------|---------------------|
| Canvas Black    | \#111417 | Base digital        |
| Corner Charcoal | \#1B2025 | Surfaces            |
| Fight Red       | \#C83B3B | Energia, ação       |
| Paper           | \#F1EEE6 | Contraste editorial |
| Steel           | \#46535E | Estrutura           |
| Champ Gold      | \#B88B46 | Legado e cinturões  |

## Sistema gráfico

- Linhas de match card, colunas de ranking, números grandes de round/evento.

- Recortes fotográficos duros e assimétricos.

- Textura de impressão esportiva muito sutil; nunca grunge pesado.

- Uso de vermelho como sinal de confronto, não como preenchimento constante.

- Dourado reservado a campeão, legado e Hall da Fama.

## Aplicações a criar

- Logo principal e monograma.

- App icon.

- Splash screen.

- Store key art.

- Template de fight card.

- Template de notícia/breaking news.

- Scoreboard de luta.

- Cinturões fictícios por organização.

- Ícones de categorias de peso.

- Sistema de banners de evento.

- Social cards e press conference background.

FECHAMENTO

# 25. Definição de sucesso

| O jogador deve conseguir chegar a 2041, abrir o Hall da Fama, ver um campeão que ele contratou aos 20 anos, lembrar das rivalidades, das negociações e das noites que construíram aquela carreira — e sentir que o mundo teria continuado existindo mesmo se ele tivesse tomado decisões diferentes. |
|----|

Corner Office não é um simulador de socos. É um simulador de poder, risco, reputação, dinheiro e legado dentro de um ecossistema de MMA. Quando os sistemas estiverem funcionando, a história não precisará ser escrita à mão: ela emergirá do save.
