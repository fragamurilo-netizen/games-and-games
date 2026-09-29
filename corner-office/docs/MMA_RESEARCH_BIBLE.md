CORNER OFFICE

MMA REAL-WORLD RESEARCH & SIMULATION BIBLE

História, regras, regulação, matchmaking, economia, contratos, camps e tradução para sistemas de jogo

**Pesquisa factual atualizada em 29 de setembro de 2026**

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>FUNÇÃO DO DOCUMENTO<br />
Este documento não substitui a Game Design Bible. Ele define o que o mundo real do MMA ensina ao simulador e quais simplificações preservam a autenticidade sem transformar o jogo em burocracia.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

Versão 1.0 • Documento para design, engenharia, balanceamento e conteúdo

LEITURA RÁPIDA

# Sumário executivo

O MMA moderno é menos uma liga esportiva tradicional e mais um ecossistema de promotoras, atletas contratados individualmente, comissões ou órgãos sancionadores, academias, managers, broadcasters, patrocinadores, médicos, árbitros, juízes e mercados regionais. A autenticidade de Corner Office depende de simular as tensões entre esses atores - e não de copiar a aparência ou o calendário de uma organização real.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>PRINCÍPIO MAIS IMPORTANTE<br />
A regra de ouro do simulador: quando algo acontece, o jogador deve conseguir entender POR QUE aconteceu. Recusa de luta, title shot, queda de card, mudança de ranking, contrato caro, upset ou decisão dividida precisam nascer de causas observáveis.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## O que fãs perceberão imediatamente se estiver errado

- Tratar striker, wrestler e jiu-jiteiro como classes rígidas de RPG, em vez de bases que se integram ao MMA.

- Fazer Overall decidir lutas e carreira de forma linear.

- Dar title shots apenas pelo ranking, ignorando timing, draw, lesão, atividade e política da organização.

- Contar takedown bruto como pontuação automática, sem considerar resultado ofensivo.

- Transformar weight cut em um atributo único e inofensivo.

- Tratar toda organização como UFC com logo diferente.

- Fazer PPV ser obrigatoriamente a principal fonte de receita de qualquer empresa.

- Ignorar comissões, medicals, jurisdições, suspensões e alterações de regras.

- Fazer popularidade derivar diretamente de habilidade ou ranking.

- Apagar o histórico: o fã de MMA lembra da maneira como uma luta aconteceu, não apenas do W/L.

## Arquitetura conceitual recomendada

| **Camada** | **Pergunta que responde** |
|----|----|
| Sport layer | O que aconteceu fisicamente e esportivamente na luta? |
| Institution layer | Que regras, comissão e promoção governam o confronto? |
| Career layer | Por que o atleta aceitou, recusou ou mudou de divisão? |
| Business layer | Por que essa luta/evento faz sentido financeiramente? |
| Narrative layer | Como mídia, fãs e atletas interpretam o que aconteceu? |
| History layer | Como a consequência entra na memória permanente do mundo? |

SUMÁRIO

# Mapa do documento

**PARTE I** Como o MMA se tornou MMA

**1** As raízes brasileiras e o vale-tudo

**2** Japão: Shooto, Pancrase e PRIDE

**3** UFC e a transição para esporte regulado

**4** MMA feminino e expansão do roster moderno

**PARTE II** Como uma luta realmente funciona

**5** Unified Rules e a lógica de julgamento

**6** Regras diferentes: ONE, RIZIN e torneios

**7** Matchups, estilos e adaptação

**PARTE III** O ecossistema institucional

**8** Comissões, licenças, medicals e oficiais

**9** Antidoping e elegibilidade

**10** Academias, camps, corners e coaches

**PARTE IV** Carreira e mercado de atletas

**11** Matchmaking real

**12** Rankings e title shots

**13** Contratos, leverage e free agency

**14** Corte de peso e mudança de categoria

**15** Lesões, dano acumulado e aposentadoria

**PARTE V** Negócio de uma promoção

**16** Direitos de mídia, gate, site fees e patrocínio

**17** Economia do evento

**18** Popularidade, draw e mercados regionais

**19** Organizações com filosofias próprias

**PARTE VI** Tradução para Corner Office

**20** Fight Engine

**21** Judging Engine

**22** Matchmaking Engine

**23** Ranking Engine

**24** Weight & Camp Engine

**25** Contract & Leverage Engine

**26** Organization AI

**27** Media & Narrative Engine

**28** História, eras e memória do save

**29** Realism tiers e UX mobile

**30** Checklist para Claude

**APÊNDICES** Glossário, parâmetros e fontes

HISTÓRIA

# PARTE I — Como o MMA se tornou MMA

## 1. As raízes brasileiras e o vale-tudo

O Brasil é uma das raízes centrais do MMA moderno, mas a história real é mais complexa do que uma linha simples “Gracie criou o vale-tudo e depois nasceu o UFC”. Pesquisas historiográficas brasileiras mostram que confrontos intermodalidades e narrativas sobre a origem do vale-tudo são disputados; o mais seguro para o design é tratar o Brasil como um ambiente em que desafios entre estilos, jiu-jitsu, luta livre, muay thai e outras tradições contribuíram para uma cultura de combate híbrido ao longo do século XX.

A passagem do vale-tudo para o MMA moderno envolveu profissionalização, aceitação midiática, maior regulação, códigos corporais e de conduta mais rígidos e, sobretudo, uma mudança de identidade: o atleta deixou de ser apenas “representante de uma arte” e passou a ser treinado como lutador de MMA.

**Base de pesquisa:** R1, R2, R3

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
No banco de dados moderno, “base marcial” é origem técnica, não classe. Um wrestler de elite precisa também ter striking defensivo, cage work, submissão defensiva e integração de MMA.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 2. Japão: Shooto, Pancrase e PRIDE

### Shooto

Em 1985, Satoru Sayama formulou o Shooting, mais tarde associado ao Shooto, reunindo elementos de boxe, kickboxing, wrestling, sambo e outras artes num sistema competitivo híbrido. Para design, isso mostra que a especialização em “lutar de maneira mista” começou antes de a marca MMA se consolidar mundialmente.

**Base de pesquisa:** R4

### Pancrase

O Pancrase estreou em 21 de setembro de 1993, antes do UFC 1. Foi criado por Masakatsu Funaki e Minoru Suzuki com a ideia de pro-wrestling “real”. Historicamente usou ringue, palm strikes em vez de punho fechado na cabeça, rope escapes e formatos de tempo muito diferentes das Unified Rules. Mais tarde aproximou suas regras das normas modernas.

**Base de pesquisa:** R5

### PRIDE

O PRIDE estreou em 1997 diante de dezenas de milhares de fãs no Tokyo Dome e se tornou um dos grandes centros mundiais do MMA até 2007. Sua apresentação, uso de ringue, torneios e cultura de espetáculo ajudaram a mostrar que o produto MMA pode ter identidades institucionais radicalmente diferentes.

**Base de pesquisa:** R7, R8

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Shinsei, no universo fictício, não deve ser “Crown Combat japonesa”. Ela precisa ter regras, cadência de eventos, cerimônias, relação com torneios e critérios de contratação próprios.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 3. UFC e a transição para esporte regulado

O UFC 1 ocorreu em 12 de novembro de 1993, em Denver, como torneio de oito atletas desenhado para colocar estilos diferentes em confronto. Royce Gracie venceu três vezes na mesma noite, popularizando o valor do grappling para um público que ainda via o evento pela lente “qual arte marcial vence?”.

**Base de pesquisa:** R6

A evolução posterior não foi apenas técnica; foi institucional. O esporte ganhou rounds, categorias de peso, luvas, regras de faltas, critérios de julgamento, comissões e protocolos médicos. As Unified Rules foram aprovadas em 2001 e continuaram recebendo revisões, inclusive mudanças de regra em 2024 e ajustes em 2025.

**Base de pesquisa:** R9

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
O save pode registrar “eras regulatórias”. Quando uma jurisdição ou organização muda regras, o metagame dos atletas e do matchmaking também pode mudar ao longo dos anos.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 4. MMA feminino e expansão do roster moderno

O MMA feminino possui história anterior à adoção pelo UFC. No UFC, o marco foi o UFC 157, em 23 de fevereiro de 2013, quando Ronda Rousey e Liz Carmouche fizeram a primeira luta feminina da organização. Para um universo fictício ambientado em 2027, divisões femininas devem existir como parte orgânica do ecossistema desde o início, não como “feature desbloqueada”.

**Base de pesquisa:** R26

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Profundidade de roster, categorias e força comercial podem variar por organização e região; igualdade de existência não exige que todas as divisões tenham a mesma densidade competitiva.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

ESPORTE

# PARTE II — Como uma luta realmente funciona

## 5. Unified Rules e a lógica de julgamento

Nas Unified Rules, rounds profissionais têm cinco minutos e o combate não pode exceder cinco rounds/25 minutos. Três juízes aplicam o 10-Point Must System. O ponto decisivo para o Fight Engine é que os critérios são priorizados, não somados como uma planilha de volume.

**Base de pesquisa:** R9, R10

### Prioridade dos critérios

| **Prioridade** | **Critério** | **Como interpretar no simulador** |
|----|----|----|
| 1 | Effective Striking / Grappling | Resultado ofensivo: impacto imediato ou cumulativo, ameaça de fim de luta, posições e grappling produtivos. |
| 2 | Effective Aggressiveness | Só entra se o critério 1 estiver efetivamente empatado. |
| 3 | Fighting Area Control | Desempate raro: quem dita pace, place e position quando o resto está igual. |

O handbook da ABC enfatiza que um takedown não deve ser tratado apenas como mudança de posição. Para ter valor esportivo relevante, a sequência precisa estabelecer ataque ou resultado efetivo. A clarificação de 2025 reforça que striking e grappling são medidos pelo resultado e que defesa, por si só, não pontua ofensivamente.

**Base de pesquisa:** R10, R11

### 10-9, 10-8 e 10-7

O jogo precisa representar margem, não apenas vencedor do round. Um 10-8 deve surgir de uma diferença clara de impacto, domínio e duração; 10-7 é reservado a casos extremos. Em vez de “chance de 10-8”, o motor deve observar o que ocorreu.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Não gere “roubo de juiz” aleatoriamente. Gere rounds apertados, ações ambíguas e perfis de juiz que pesam o mesmo regulamento com pequenas diferenças. A controvérsia emerge da luta.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 6. Regras diferentes: ONE, RIZIN e torneios

### ONE: hidratação e pesagem

A ONE utiliza protocolo combinado de hidratação e pesagem. O atleta precisa atingir limite de urina específico (≤1.025) e peso contratado, com regras para retestes e catchweight. Isso demonstra que “weight class” e “processo de bater peso” podem ser desenhados institucionalmente de formas muito diferentes.

**Base de pesquisa:** R12

### RIZIN: ringue e avaliação do combate inteiro

A RIZIN usa ringue e regras próprias. Seu regulamento atual contempla formatos como 5x3 e, em alguns casos, 10+5, e avalia a luta como um todo com prioridade para dano/impacto e agressividade, em vez de simplesmente somar três cartões de rounds no modelo Unified Rules.

**Base de pesquisa:** R13

### PFL: torneio e substitutos

O World Tournament de 2025 exemplifica uma lógica de temporada por eliminação: oito atletas por divisão, chave, semifinais e final; regras específicas para missing weight, alternates, walkovers e resultados que afetam avanço. A comissão local continua prevalecendo quando houver conflito regulatório.

**Base de pesquisa:** R14

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Corner Office deve separar “ruleset” de “promotion”. Uma organização escolhe um conjunto regulatório permitido pela jurisdição. Isso abre espaço para cage/ringue, scoring por rounds ou luta inteira, formatos de torneio, hidratação e regras especiais.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 7. Matchups, estilos e adaptação

MMA moderno é integração. O motor deve modelar fases e transições: distância, pocket, clinch, cage, takedown entry, scramble, top/bottom, stand-up. Estilo não é uma etiqueta; é uma distribuição de preferências, competências e respostas.

| **Exemplo** | **Não modelar como** | **Modelar como** |
|----|----|----|
| Wrestler pressão | “+20% contra striker” | Frequência de entradas, chain wrestling, cage finish, cardio, controle, ground offense e reação do rival. |
| Counter striker | “classe counter” | Baixa iniciativa, alta precisão reativa, leitura de timing, defesa de entrada e risco quando obrigado a liderar. |
| Submission hunter | “BJJ 95” | Ameaça de finalização por posições específicas, transições, risco assumido e capacidade de criar scramble. |
| Veterano completo | “Overall alto” | Boa integração, leitura, economia de energia, adaptação, mas possível queda de explosão e durabilidade. |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Upset bom é explicável. O jogador deve conseguir abrir a luta depois e enxergar: “o campeão perdeu porque não conseguiu defender a grade, gastou energia, entrou cansado no R4 e foi finalizado”.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

REGULAÇÃO

# PARTE III — O ecossistema institucional

## 8. Comissões, licenças, medicals e oficiais

Nos EUA, a organização não é a autoridade absoluta sobre o evento. Comissões estaduais licenciam atores, aprovam ou rejeitam aspectos da competição e escalam oficiais. A Califórnia, por exemplo, exige pelo menos US\$ 50 mil em ativos líquidos de promotores profissionais e mantém regras e licenças próprias.

**Base de pesquisa:** R15

A operação também tem custos de oficiais. A CSAC publica escalas mínimas para árbitros, juízes, cronometristas e médicos; seus eventos recebem no mínimo dois médicos de ringside. Isso mostra que “event operations” é um sistema real e separável do fight card.

**Base de pesquisa:** R16

### O que uma jurisdição pode controlar

- Licença do promotor e bond/garantias.

- Licença ou clearance de atletas, corners, managers e oficiais.

- Medical exams e requisitos adicionais.

- Aprovação do matchup.

- Ruleset aplicável ou variâncias autorizadas.

- Designação de juízes, árbitro e médicos.

- Suspensões médicas após a luta.

- Procedimentos de apelação e revisão.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Crie “jurisdiction templates”. Em casual, o sistema resolve automaticamente. Em Simulation Mode, medicals pendentes, licenças e diferenças regulatórias podem virar risco operacional sem virar paperwork tedioso.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 9. Antidoping e elegibilidade

O UFC mantém desde 2024 programa próprio administrado pela Combat Sports Anti-Doping, com coletas da Drug Free Sport International e testes sem aviso ao longo do ano para atletas contratados. Isso é diferente da regulação de cada comissão e mostra que antidoping pode existir em duas camadas: órgão local + programa da promoção.

**Base de pesquisa:** R17

| **Camada** | **Possíveis sistemas no jogo** |
|----|----|
| Commission testing | Testes próximos ao evento, sanção jurisdicional, NC, suspensão. |
| Promotion program | Pool anual, testes surpresa, política de contratação, reputação da marca. |
| Tournament policy | Regras próprias para substituição/avanço após teste positivo. |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Não transforme doping em evento cômico aleatório. Precisa ter processo: teste, possível provisional suspension, decisão, impacto no resultado e consequências contratuais/esportivas.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 10. Academias, camps, corners e coaches

O MMA é um esporte individual praticado em estruturas coletivas. Academias produzem estilos, sparring partners, conexões, conflitos e reputação. Camp não é “treino +5”: é preparação específica para um adversário, com risco de overtraining, lesão, adaptação, custo e escolha de parceiros.

| **Elemento** | **Variáveis úteis** |
|----|----|
| Head coach | game planning, liderança, relação, adaptação entre rounds |
| Striking coach | boxe/kickboxing, defense, pads, opponent-specific prep |
| Wrestling coach | entries, chain wrestling, cage wrestling, anti-wrestling |
| BJJ coach | submissions, escapes, positional systems |
| S&C / nutrition | cardio, peak, cut, recovery |
| Training partners | estilo semelhante ao rival, nível, disponibilidade, relação |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Uma luta entre atletas da mesma academia deve gerar dilema real. Eles podem recusar, mudar de gym, treinar separadamente ou criar ruptura que afeta uma rede inteira.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

TALENT

# PARTE IV — Carreira e mercado de atletas

## 11. Matchmaking real

O matchmaker organiza um problema multidimensional: qualidade esportiva, divisões, disponibilidade, lesão, desejo do atleta, contrato, timing do evento, local, televisão, narrativa e substituições. Joe Silva atuou como matchmaker do UFC entre 1997 e 2016 e foi creditado por mais de 3.000 lutas, ilustrando como essa função é central numa promoção.

**Base de pesquisa:** R27

### Variáveis mínimas de aceitação

| **Dimensão** | **Exemplos**                                                |
|--------------|-------------------------------------------------------------|
| Sport        | ranking, forma, estilo, title implications, rematch recency |
| Body         | lesão, medical suspension, camp length, weight cut          |
| Career       | ambição, idade, risco percebido, legado, atividade desejada |
| Contract     | lutas restantes, pay, extension, leverage                   |
| Event        | data, local, travel, visa, main/co-main status              |
| Relationship | promoter trust, agent relationship, promises                |
| Commercial   | draw, local star, broadcast need, sponsor/storyline         |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
“BOOK” não pode ser botão garantido. O ato de tentar fechar a luta já é gameplay.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 12. Rankings e title shots

Rankings não são uma verdade matemática. Em junho de 2026, o UFC anunciou transição do painel tradicional de mídia para o Meta UFC Rankings, determinado por dados de luta. A própria mudança mostra que diferentes instituições podem legitimar diferentes formas de ordenar atletas.

**Base de pesquisa:** R24

### Modelos que o jogo deve suportar

- Media panel

- Algorithmic/data-driven

- Promotion-controlled / advisory

- Tournament bracket

- Independent world ranking

Title shot deve ser decisão com legitimidade, não consequência automática do ranking. O jogo precisa equilibrar mérito, sequência, atividade, lesões, timing do campeão, revanche, draw, substituto de última hora e compromissos já prometidos.

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
A mídia pode discordar: “#5 recebe title shot sobre #2”. Isso cria pressão, não um erro de sistema.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 13. Contratos, leverage e free agency

O MMA profissional não opera como uma grande liga norte-americana com contrato coletivo uniforme. Termos variam por atleta, promoção e contexto. A disputa econômica entre atletas e promotores é parte relevante da história recente; em março de 2025, o tribunal aprovou acordo de US\$ 375 milhões no caso Le v. Zuffa para uma classe de atletas coberta pelo período definido no processo.

**Base de pesquisa:** R25

### Contrato de jogo precisa separar

| **Campo** | **Por que importa** |
|----|----|
| Bouts remaining | Cria urgência e leverage antes da free agency. |
| Show / win / flat purse | Modelos de remuneração diferentes. |
| Signing/guarantee | Atrai atleta ou reduz risco. |
| Revenue/PPV points | Upside para stars. |
| Champion clause | Risco de extensão e poder da promoção. |
| Matching rights | Afeta free agency. |
| Exclusivity | Impede luta em rivais. |
| Promises | Main event, local, activity, title pathway; quebrar promessa afeta confiança. |

### Leverage

Leverage é calculado por alternativas. Um campeão 29-0 com contrato perto do fim, draw alto e oferta rival forte tem poder. Um prospect 5-1 desconhecido, sem outras propostas e precisando de atividade, tem menos. A IA precisa saber o BATNA de cada lado, mesmo sem expor esse termo ao jogador.

## 14. Corte de peso e mudança de categoria

Perda rápida de peso é recorrente em esportes de combate. Revisão sistemática com 4.432 participantes encontrou em coortes de MMA mudanças próximas de 10% de massa corporal na perda rápida e cerca de 11,7% no regain em um dos estudos. A literatura também mostra incerteza: alguns marcadores de performance se recuperam após reidratação e outros efeitos podem persistir, por isso o jogo não deve usar penalidade fixa simples.

**Base de pesquisa:** R18, R19, R20, R21

### Quatro pesos por atleta

| **Peso**           | **Exemplo 155 lb** |
|--------------------|--------------------|
| Natural / off-camp | 181 lb             |
| Early camp         | 174 lb             |
| Official weigh-in  | 155 lb             |
| Fight-night        | 170–176 lb         |

### Estado do corte

- discipline

- chronic descent rate

- glycogen/carbohydrate restriction

- fluid cut

- rehydration quality

- kidney/physiological stress proxy

- history of misses

- confidence of nutrition staff

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Weight cut é uma decisão de risco, não um minigame de desidratação. O jogador influencia divisão, camp, equipe e política; o atleta e o staff executam.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 15. Lesões, dano acumulado e aposentadoria

O jogo deve separar “injury” de “damage history”. Uma lesão de joelho pode limitar explosão ou wrestling; repetidas guerras podem reduzir durabilidade e recuperação mesmo quando técnica permanece alta. Suspensão médica pós-luta impede booking até clearance.

| **Camada**         | **Exemplos**                                           |
|--------------------|--------------------------------------------------------|
| Acute injury       | mão, joelho, ombro, costela, corte, concussão          |
| Medical suspension | prazo + clearance                                      |
| Chronic wear       | queixo, recuperação, mobilidade, confiança             |
| Career decision    | subir peso, mudar estilo, reduzir atividade, aposentar |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Aposentadoria deve ser decisão emergente. Um atleta pode parar por idade, dano, dinheiro, perda de motivação ou família - e pode tentar voltar anos depois.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

ECONOMIA

# PARTE V — Negócio de uma promoção

## 16. Direitos de mídia, gate, site fees e patrocínio

O modelo econômico moderno não pode ser reduzido a PPV. No relatório anual de 2025, o segmento UFC da TKO registrou US\$ 907,7 milhões em media rights/production/content, US\$ 232,9 milhões em live events/hospitality e US\$ 314,3 milhões em partnerships/marketing. O filing também descreve site fees, hospitalidade e licensing como fontes relevantes. Em 2026, o novo acordo da Paramount passou a distribuir a programação UFC nos EUA sob um modelo diferente do antigo ciclo ESPN/PPV.

**Base de pesquisa:** R22, R23

| **Receita** | **Motor no jogo** |
|----|----|
| Media rights | garantia, duração, território, quantidade de eventos, exclusividade |
| Live gate | arena, ticket price, market demand, star power |
| Site fee | cidade/país paga para receber evento |
| Hospitality | VIP, travel, premium inventory |
| Partnerships | sponsors, integrations, category exclusivity |
| Licensing | merch, collectibles, games, branded products |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Uma promoção fictícia pode ser PPV-heavy, streaming-guaranteed, free-TV + sponsor ou híbrida. O modelo muda o tipo de card que faz sentido.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 17. Economia do evento

Cada evento deve ter projeção e fechamento. Receitas e custos precisam reagir ao card, não a uma fórmula fixa por tier.

| **Antes do evento**       | **Depois do evento**                    |
|---------------------------|-----------------------------------------|
| Projected audience / gate | Actual audience / gate                  |
| Contracted purses         | Paid purses + bonuses                   |
| Venue + production        | Actual operational cost                 |
| Sponsor commitments       | Delivered sponsor value                 |
| Travel / visa / officials | Final logistics                         |
| Risk reserve              | Cancellations/refunds/insurance effects |

### Local como decisão estratégica

Venue escolha envolve gate, site fee, crescimento de mercado, fuso, viagem, disponibilidade, custos e apelo de atletas locais. Um local que paga mais pode construir menos audiência orgânica; outro pode ser investimento de longo prazo.

## 18. Popularidade, draw e mercados regionais

Skill, ranking e draw precisam ser eixos independentes. Um atleta 82 pode ser grande vendedor; um campeão 94 pode ter baixa popularidade. Popularidade também é regional: Brasil, México, Reino Unido, Japão e EUA podem reagir de maneiras diferentes ao mesmo atleta.

| **Variável**  | **Não derivar diretamente de** |
|---------------|--------------------------------|
| Popularity    | Overall                        |
| Drawing power | Ranking                        |
| Fan affinity  | Vitórias                       |
| Controversy   | Carisma                        |
| Sponsor value | Skill                          |
| Reliability   | Popularity                     |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
A melhor estrela para headliner não é necessariamente o melhor lutador. Esse conflito é parte da fantasia de ser promoter.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 19. Organizações com filosofias próprias

A história de PRIDE, RIZIN, ONE, PFL, Shooto e Pancrase mostra que MMA não exige um único formato institucional. O mundo fictício deve refletir isso em decisões persistentes.

| **Dimensão**    | **Possíveis identidades**                        |
|-----------------|--------------------------------------------------|
| Scoring         | round-based / whole-fight                        |
| Venue           | cage / ring                                      |
| Schedule        | weekly / monthly / tentpole                      |
| Competition     | ranking / tournament / hybrid                    |
| Weight policy   | traditional / hydration-focused                  |
| Talent strategy | stars / prospects / regional / technical         |
| Business model  | PPV / rights guarantee / subscription / hybrid   |
| Presentation    | sports-first / spectacle-first / tradition-first |

GAME SYSTEMS

# PARTE VI — Tradução para Corner Office

## 20. Fight Engine

O motor deve ser state-based. Ele não precisa simular cada frame; precisa simular decisões e consequências em granularidade suficiente para produzir histórico explicável.

### Estados espaciais

- long range

- boxing range/pocket

- cage striking

- clinch

- open-mat wrestling

- cage wrestling

- top/bottom guard

- half guard

- side control

- mount/back

- scramble

- reset

### Loop de exchange

1.  Escolher intenção com base em gameplan, estilo, round state, corner advice e leitura do rival.

2.  Resolver técnica versus defesa usando atributos específicos, reach/stance, fadiga e timing.

3.  Gerar resultado: landed/avoided, positional change, damage, cut, knockdown, takedown, submission threat.

4.  Atualizar energia, damage map, confidence, urgency e opponent model.

5.  Permitir adaptação progressiva; lutadores de alto Fight IQ mudam frequência e escolha de ação.

### Outputs persistentes

| **Output**       | **Uso posterior**         |
|------------------|---------------------------|
| Detailed stats   | UI, analytics, media      |
| Damage & cuts    | medical/next camp         |
| Round state      | judging                   |
| Momentum moments | highlights/news           |
| Gameplan success | coach/fighter development |
| Near finishes    | fan perception, awards    |

## 21. Judging Engine

Cada juiz recebe o mesmo event log e o interpreta sob o ruleset. Não deve existir “roubo = RNG”. A variação vem de rounds realmente próximos, percepção relativa de impacto e pequena diferença de limiar.

| **Variable** | **Descrição** |
|----|----|
| impact_weight | sensibilidade a dano/ameaça imediata dentro do critério permitido |
| grappling_result_weight | quanto reconhece grappling produtivo quando comparável |
| round_closeness_threshold | quando considera margem suficiente |
| 10-8 threshold | limiar para grande domínio |
| consistency | reduz variação aleatória entre rounds |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Qualquer decisão controversa precisa ser replayable: abrir scorecards + momentos do round e entender por que cada juiz chegou lá.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 22. Matchmaking Engine

Para cada atleta candidato, calcule três scores separados: Sporting Fit, Acceptance Probability e Commercial Fit. Nunca colapse tudo em um único “match score” exibido ao jogador.

| **Score** | **Entradas** |
|----|----|
| Sporting Fit | rank proximity, recent form, rematch logic, divisional needs, style novelty |
| Acceptance | pay, risk, notice, injury, career goals, promises, agent stance |
| Commercial Fit | draw, market, event role, narrative, local hero, broadcaster need |

A decisão final do matchmaker pode priorizar pesos diferentes por organização. Uma promotion merit-first usa Sporting Fit alto; uma star-first aceita mismatch comercialmente atraente com backlash de mídia.

## 23. Ranking Engine

Manter ranking oficial por promoção e World Combat Index independente. Cada snapshot fica salvo por data para histórico.

6.  Atualizar score esportivo após luta considerando resultado, opponent quality, recency e activity.

7.  Aplicar modelo institucional: panel, algorithmic ou promoter-assisted.

8.  Limitar saltos absurdos sem vitória excepcional.

9.  Permitir inatividade reduzir posição sem apagar resume.

10. Gerar explicação textual de mudanças relevantes.

## 24. Weight & Camp Engine

A preparação precisa rodar por semanas, não apenas no dia da pesagem. A perda crônica mais controlada reduz necessidade de corte agudo; cut extremo aumenta risco de miss/medical/performance sem tornar resultado determinístico.

| **Fase** | **Principais estados** |
|----|----|
| 8–12 semanas | body mass, injury, conditioning base, gameplan |
| 4–8 | technical specificity, sparring quality, fatigue |
| fight week | travel, weight, hydration, stress, media obligations |
| weigh-in | official weight, hydration if ruleset requires, catchweight negotiation |
| post weigh-in | rehydration/refuel quality, sleep, residual stress |

## 25. Contract & Leverage Engine

Negociação é utilidade esperada, não sliders arbitrários. Cada lado calcula valor do acordo versus alternativas.

- Fighter BATNA: rival offer, waiting, free agency, retirement, different division.

- Promotion BATNA: alternative opponent, replacement star, postpone, interim title.

- Agent utility: guaranteed money, upside, activity, client portfolio and relationship.

- Reputation cost: quebrar promessa hoje aumenta custo de deals futuros.

## 26. Organization AI

Cada rival precisa de budget, calendário, roster needs, brand philosophy e risk tolerance. A IA não pode saber hidden potential sem scouting próprio.

| **Trait**        | **Efeito**                                           |
|------------------|------------------------------------------------------|
| Aggressive buyer | superpaga para preencher necessidades e roubar stars |
| Prospect-first   | contratos baratos e pipeline amplo                   |
| Cash disciplined | corta veteranos caros cedo                           |
| Regionalist      | valoriza atletas capazes de abrir mercado local      |
| Merit-first      | ranking pesa mais no matchmaking                     |
| Spectacle-first  | draw/rivalry pesa mais                               |

## 27. Media & Narrative Engine

Notícia deve ser consequência de estado do mundo, não texto procedural vazio. Cada story tem facts, angle, entities, outlet bias/tone, reach e aftereffects.

| **Story** | **Trigger factual** |
|----|----|
| “Champion is ducking \#1” | recusou duas propostas + contender publicamente cobra luta |
| “Robbery debate” | split/close cards + media scoring diverge |
| “Promotion losing control of division” | champion inactive + interim + failed booking |
| “New star emerges” | finish streak + audience growth + social traction |
| “Weight-cut problem” | multiple misses + difficult cuts + commission warning |

## 28. História, eras e memória do save

O jogo deve produzir retrospectiva. Uma “era” é detectada a posteriori por dominância, mudança geográfica, star cluster, ruleset trend ou organização dominante. O label é narrativa, não bônus.

- The Carter Era

- Rise of Central Asian MMA

- Shinsei Resurgence

- The Streaming Boom

- Brazilian Flyweight Golden Age

Todo atleta precisa de fight history com event, opponent, result, method, round/time, scorecards, significant moments, weight issue, title stakes e media aftermath. Em revanche, o jogo deve mostrar o passado sem o usuário precisar lembrar de cabeça.

## 29. Realism tiers e UX mobile

Autenticidade não exige obrigar o jogador a preencher papelada. Use três camadas de complexidade.

| **Modo** | **Comportamento** |
|----|----|
| Accessible | commissions, medicals e logistics automáticos; jogador recebe só exceções importantes. |
| Promoter | decisões importantes aparecem: venue, medical issue, replacement, contract, media. |
| Simulation | jurisdictions, detailed clearances, officials cost, advanced contract clauses e policies visíveis. |

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>IMPLICAÇÃO PARA O JOGO<br />
Complexidade boa é decisão; complexidade ruim é digitação. O mobile precisa esconder burocracia normal e revelar exceções que mudam o card.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>

## 30. Checklist para Claude

11. Não implemente um sistema novo sem apontar qual fenômeno real ele representa.

12. Para cada cálculo importante, registre reason codes legíveis para debug e UI.

13. Nunca use Overall como input direto dominante do Fight Engine.

14. Não misture official ranking, world ranking e matchmaking priority.

15. Separe ruleset, promotion e jurisdiction em entidades distintas.

16. Weight management ocorre ao longo do camp; não só na tela de weigh-in.

17. Fight history é append-only e precisa sobreviver a décadas de save.

18. AI rivals só usam informação que teriam acesso.

19. Popularidade é regional e separada de skill.

20. Eventos de mídia exigem triggers factuais; não gerar drama do nada.

21. Após cada sistema, simular 10–30 anos e procurar colapso, inflação, loops e comportamento anti-MMA.

BALANCEAMENTO

# APÊNDICE A — Parâmetros iniciais para protótipo

Os valores abaixo são seeds de protótipo, não “verdades do MMA”. Devem ser calibrados por simulação e playtest. A finalidade é impedir que o Claude invente parâmetros incoerentes a cada sistema.

| **Sistema** | **Seed sugerido** |
|----|----|
| Fight frequency | 2–4 lutas/ano para atletas saudáveis; stars/champions podem lutar menos. |
| Camp ideal | 6–10 semanas; short notice abaixo de ~4 aumenta variância. |
| Ranking inactivity | efeito gradual após longos períodos; sem queda automática brutal. |
| Medical KO/TKO | suspensão variável por dano e jurisdição. |
| Weight miss | evento raro, mas material; chance aumenta com cut stress + history. |
| Upset rate | calibrar por faixa de skill/matchup; nunca zero. |
| Prime window | varia por peso, estilo, dano e biologia; não usar idade fixa universal. |
| Contract talks | probabilidade cresce conforme bouts_remaining cai e leverage aumenta. |

LINGUAGEM

# APÊNDICE B — Glossário de domínio

| **Termo** | **Uso** |
|----|----|
| Camp | Período de preparação específica para a luta. |
| Corner | Equipe autorizada a acompanhar o atleta e orientar entre rounds. |
| Cut / weight cut | Processo de redução de peso, especialmente fase aguda pré-pesagem. |
| Rehydration / regain | Recuperação de líquidos e massa após pesagem. |
| Catchweight | Peso negociado fora do limite padrão de uma categoria. |
| Short notice | Luta aceita com preparação reduzida. |
| Walkover | Avanço sem luta em formato de torneio conforme regras. |
| Site fee | Pagamento/garantia oferecido por anfitrião para receber evento. |
| Gate | Receita de ingressos do evento. |
| Draw | Capacidade comercial de atrair audiência/receita. |
| Leverage | Poder negocial relativo dado pelas alternativas e importância. |
| Interim title | Cinturão temporário quando campeão principal está indisponível. |
| 10-Point Must | Sistema em que o vencedor do round normalmente recebe 10 e o outro 9 ou menos. |
| Whole-fight scoring | Julgamento da luta como conjunto em vez da soma de rounds. |
| Medical suspension | Período em que atleta não pode competir sem tempo/clearance exigido. |
| P4P | Pound-for-pound; ranking comparativo entre categorias. |

REFERÊNCIAS

# APÊNDICE C — Matriz de fontes

Prioridade usada: regras/regulação e filings financeiros \> fonte primária da organização \> literatura científica \> estudos historiográficos \> material editorial. Quando uma fonte de promoção descreve a própria história, tratamos como fonte primária com viés institucional natural.

**R1** Do Vale Tudo ao MMA, do analógico ao digital — Recorde/UFRJ — [<u>abrir fonte</u>](https://revistas.ufrj.br/index.php/Recorde/article/view/48970/)

**R2** Primórdios do jiu-jitsu e dos confrontos intermodalidades no Brasil — SciELO — [<u>abrir fonte</u>](https://www.scielo.br/j/rbce/a/hsWF8YZRffJBdgPhf8DtQ8B/)

**R3** Artes marciais mistas: luta por afirmação e mercado da luta — SciELO — [<u>abrir fonte</u>](https://www.scielo.br/j/rbce/a/F5bRPPjSD5YyjnFBG7VPXHp/)

**R4** PRO SHOOTO MMA Japan — origem do Shooting/Shooto em 1985 — [<u>abrir fonte</u>](https://shooto-mma.com/topics/?id=2800)

**R5** UFC — história do Pancrase — [<u>abrir fonte</u>](https://www.ufc.com/news/pancrase-be-streamed-live-ufc-fight-pass)

**R6** UFC — Revisiting UFC 1 — [<u>abrir fonte</u>](https://www.ufc.com/news/revisiting-ufc-1)

**R7** UFC — PRIDE / Takanori Gomi e contexto japonês — [<u>abrir fonte</u>](https://jp.ufc.com/news/quintet-ultra-takanori-gomi)

**R8** UFC — PRIDE 1997–2007 — [<u>abrir fonte</u>](https://jp.ufc.com/news/spike-tv-feature-best-pride-new-weekly-series)

**R9** ABC — Unified Rules of MMA, edição 2025 — [<u>abrir fonte</u>](https://www.abcboxing.com/wp-content/uploads/2025/08/Unified-Rules-of-MMA-8.2025.pdf)

**R10** ABC — MMA Officials Handbook / judging criteria — [<u>abrir fonte</u>](https://www.abcboxing.com/wp-content/uploads/2025/02/ABC-MMA-Officials-Handbook.pdf)

**R11** ABC — MMA Scoring Criteria Clarification 2025 — [<u>abrir fonte</u>](https://www.abcboxing.com/wp-content/uploads/2025/08/ABC-MMA-Scoring-Criteira-Clarification-7.2025.pdf)

**R12** ONE Championship — rules, weigh-in and hydration protocol — [<u>abrir fonte</u>](https://www.onefc.com/martial-arts/)

**R13** RIZIN — MMA rules — [<u>abrir fonte</u>](https://jp.rizinff.com/rule)

**R14** PFL — 2025 World Tournament Rules — [<u>abrir fonte</u>](https://pflmma.com/index.php/wtrules)

**R15** California State Athletic Commission — promoter licensing — [<u>abrir fonte</u>](https://www.dca.ca.gov/csac/applicants/promoter.html)

**R16** California State Athletic Commission — officials pay scale — [<u>abrir fonte</u>](https://www.dca.ca.gov/csac/forms_pubs/publications/official_payscale.html)

**R17** UFC Athlete Health and Performance — anti-doping program — [<u>abrir fonte</u>](https://www.ufc.com/ufc-athlete-health-and-performance)

**R18** PubMed — Rapid Weight Loss/Rapid Weight Gain systematic review — [<u>abrir fonte</u>](https://pubmed.ncbi.nlm.nih.gov/30299200/)

**R19** PubMed — Effects of Weight Cutting on Exercise Performance meta-analysis — [<u>abrir fonte</u>](https://pubmed.ncbi.nlm.nih.gov/35523423/)

**R20** PubMed — Acute and Chronic Weight-Making in Professional MMA athletes — [<u>abrir fonte</u>](https://pubmed.ncbi.nlm.nih.gov/38871343/)

**R21** PubMed — ISSN position stand on nutrition and weight cuts — [<u>abrir fonte</u>](https://pubmed.ncbi.nlm.nih.gov/40059405/)

**R22** TKO 2025 Form 10-K / SEC — [<u>abrir fonte</u>](https://www.sec.gov/Archives/edgar/data/1973266/000119312526071651/tko-20251231.htm)

**R23** TKO Q2 2026 results / SEC — [<u>abrir fonte</u>](https://www.sec.gov/Archives/edgar/data/1973266/000119312526330561/tko-ex99_1.htm)

**R24** UFC — Meta UFC Rankings announcement, 2026 — [<u>abrir fonte</u>](https://www.ufc.com/news/ufc-and-meta-unveil-meta-ufc-rankings)

**R25** Le v. Zuffa settlement information — [<u>abrir fonte</u>](https://ufcfighterclassaction.com/)

**R26** UFC — women in UFC / UFC 157 history — [<u>abrir fonte</u>](https://www.ufc.com/news/ufc-157-main-card-results-ronda-makes-history)

**R27** UFC — Joe Silva Hall of Fame / matchmaker history — [<u>abrir fonte</u>](https://www.ufc.com/hof/joe-silva-hall-of-fame)

## Notas de cautela

- Não existe uma única narrativa historiográfica incontestada sobre a origem do vale-tudo brasileiro; o documento evita simplificações fortes.

- Rulesets mudam. O jogo deve guardar versão/data de regra em vez de assumir que “MMA rules” é constante.

- Efeitos de weight cutting sobre performance têm literatura heterogênea; o simulador deve trabalhar com risco/distribuição, não penalidade determinística.

- Termos contratuais reais podem ser confidenciais e variam; o sistema proposto é uma abstração informada, não reprodução de contratos específicos.

- Dados econômicos da TKO ajudam a entender modelos contemporâneos, mas uma promoção fictícia não precisa replicar a mesma composição de receita.

QUALITY GATE

# APÊNDICE D — O teste do fã

Antes de aprovar um sistema, faça estas perguntas com alguém que acompanha MMA regularmente:

22. Ele consegue explicar por que o atleta recusou a luta?

23. Ele consegue olhar o matchup e imaginar caminhos de vitória diferentes?

24. A decisão dos juízes é compreensível olhando rounds e scorecards?

25. Rankings e title shots podem ser discutíveis sem parecer bug?

26. O weight cut parece risco de carreira e performance, não stat de videogame?

27. Cada organização parece ter identidade real?

28. O evento pode cair e ser salvo de formas plausíveis?

29. O atleta tem motivos econômicos e esportivos distintos?

30. O histórico permite lembrar como rivalidades nasceram?

31. Depois de 15 anos de save, o mundo parece ter desenvolvido sua própria história?

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<thead>
<tr>
<th><strong>META DE AUTENTICIDADE<br />
Se a resposta for “sim” para esses dez pontos, Corner Office começa a sair da categoria “manager genérico com skin de MMA” e entrar na de simulador que fãs reconhecem como feito por gente que entende o esporte.</strong></th>
</tr>
</thead>
<tbody>
</tbody>
</table>
