# Continuar daqui (atualizado em 06/10/2026)

Esta é a nota para quem pegar o jogo depois: uma pessoa, o ChatGPT/Codex ou outra sessão do Claude.

## Onde está o jogo

- **Ramo mais novo (06/10, noite): `claude/hopeful-newton-8avbo4`.** Partiu de `claude/youthful-newton-hey7og`. APK: `builds/MaisUmaRodada-1.0.0-base-idiomas-geografia-2026-10-06-debug.apk` (certificado de depuração de sempre, instala por cima). Três rodadas de pedidos do dono, todas aqui (detalhes na seção "Mundo vivo, carreira de técnico e base profunda" logo abaixo).

### Mundo vivo, carreira de técnico e base profunda (06/10, ramo `claude/hopeful-newton-8avbo4`)

- **Carreira de técnico** (`job_market.gd`, tela `jobs`, menu ☰ › Mercado de técnicos): pedir demissão, ver vagas e "cargos por um fio", candidatar-se, entrevista (Talks "interview"); clubes ligam quando precisam. A língua conta: quem não fala a do vestiário perde cotação (`Languages.coach_comm`) e a vaga avisa.
- **Formas de jogo**: 17 formações e 27 modelos de jogo (`game_models.gd`, `data/gameplay/game_models.json`) no pré-jogo.
- **Mercado**: cada clube da IA (até a 2ª divisão) tem olheiros que assistem a jogos de verdade (`club_scout_net.gd`) e um cérebro de janela (`transfer_brain.gd`: diagnóstico do elenco, pressão da torcida, plano por necessidade, dominó quando vende). Sem sorteio. Calibrado com o Transfermarkt: brasileiros quase não trazem europeus (1%), repatriação ~16%. Acordos: CPLP (Brasil/Portugal), ACP na Espanha, permissão de trabalho inglesa (GBE).
- **Economia 2026** (`economy.gd`, `data/world/economy.json`): moedas e câmbio, receitas e dívidas reais dos clubes de referência, custo operacional por liga, recuperação judicial; reputação das ligas muda (`league_reputation.gd`).
- **Reputação escondida**: estrelas e rótulos no lugar do número (`UIKit.rep_stars`). Correções de reputação de clubes (Man United, Benfica/Porto/Sporting, Milan/Napoli etc.) e o Brasil um pouco abaixo no mundo (clubes e faixa da Série A −4: a força dentro do país não muda).
- **Auxiliar no comando** (`autopilot.gd`): simular escolhendo "tudo pelo auxiliar" ou "só me chame no importante".
- **Corpo**: garotos crescem e engordam até a idade adulta, alguns com tendência a peso (`body_growth.gd`), e o peso pesa nas lesões.
- **Relações** (`relations.gd`): amizades, desafetos, irmãos, revelados juntos, mentores, técnico favorito/odiado, ídolos, lendas do clube (tela do clube). Níveis nunca aparecem na interface (pedido do dono).
- **Lesões** (`injury_model.gd`): por parte do corpo, idade, cansaço, posição, recidiva, peso e departamento médico, e lesões de treino em todos os clubes. ~25 lesões de 1+ semana por clube da elite na temporada (Inglaterra, Espanha, Alemanha, Brasil), média ~4 semanas (`tools/injury_report.gd`).
- **Ingressos** (`ticket_office.gd`), clássicos corrigidos no mundo todo, prêmios com nomes do mundo e por liga (`data/gameplay/awards.json`).
- **Base profunda** (`youth_life.gd`, ficha do garoto › "Vida na base"): maturação biológica escondida (o precoce domina a base e engana a avaliação; o tardio parece pior), família (presente, humilde, pai que cuida da carreira, alojamento longe de casa pela distância real), primeiro contrato profissional aos 16, empresários que farejam talento de verdade, compensação de formação da FIFA, saudade, pai cobrando minutos, desistências no fim do ano e laços da geração. Dilemas novos: `youth_agent`, `youth_homesick`, `youth_parent`. Teste: `tools/youth_life_smoke.gd`.
- **Geografia** (`geo.gd`, `data/world/geo.json`): coordenadas das ~1.370 cidades de clubes e cidades natais. Viagem bem mais longa que a média da liga pesa no visitante (`Geo.travel_factor`, preparado antes das threads dos jogos); "a X km de casa" no perfil.
- **Idiomas** (`languages.gd`, `data/world/languages.json`, campo `Player.langs` salvo como "lng"): cada um fala a da terra (bilíngues com noção da outra) e o inglês do seu país, e aprende a do clube por mês. Pesa no isolamento do vestiário, nas panelinhas, no entrosamento, na vontade de ir para um país e no técnico. Perfil mostra "Português (nativo) · Espanhol (fluente)". Sem versão em alemão (pedido do dono).
- **Falta:** traduções EN/ES dos textos novos; testar no celular a ficha "Vida na base" e o mercado de técnicos; `tests/run_tests.gd` completo não foi rodado nesta rodada (só check_scripts, smokes e mobile_regression).

- **Junção de 06/10 à tarde: `claude/youthful-newton-hey7og`.** Partiu de `claude/bolinhas-narracao-5wp2pg` e juntou `claude/escudos-caprichados-i5l8y5`, `claude/scout-rodadascore-8c516x`, `claude/mundo-impacto-mtmev0` e `claude/historico-inicio-carreira` (seções de cada um abaixo). APK sem trava de compra: `builds/MaisUmaRodada-1.0.0-tudo-junto-sem-trava-2026-10-06.apk` (certificado de sempre). Conferido: `check_scripts` 0 erros, smoke, mobile_regression e toque no nome do elenco (18/18).
- **Ramo mais novo (06/10): `claude/bolinhas-narracao-5wp2pg`.** Tem tudo de `claude/posicoes-escalacao-hbrnjt` + elencos realistas + campo clássico 2D + mercado sul-americano, e por cima: bolinhas seguindo a narração, cores dos times no campinho, negociações realistas com mesa cara a cara, calvície por idade. Último APK: `builds/MaisUmaRodada-1.0.0-mesa-negociacao-2026-10-06-debug.apk` (certificado de depuração de sempre, instala por cima).
- **Para seguir neste ramo:** (1) testar no celular a mesa de negociação e o "Levantar da mesa" (a chamada de volta só acontece com clube que precisa vender; não foi vista num teste real); (2) rodar `tests/run_tests.gd` depois da junção do mercado sul-americano (só a compilação foi conferida); (3) as respostas novas do diretor ainda não têm tradução em `data/i18n/en.json`/`es.json`; (4) propostas que a IA faz pelos jogadores do usuário (`respond_offer`) já respondem na hora, mas ainda não usam a mesa de conversa; (5) "primeiro clube aparece como empréstimo" no histórico está com a thread "Elencos e overall realistas", em outro ramo.

- **As duas linhas foram juntadas em 05/10** no ramo `claude/posicoes-escalacao-hbrnjt`. Ele tem a UI 2.0 e a versão 1.0.0 (antes em `claude/youthful-newton-hey7og`, a que o dono e o Gregory jogam), mais todo o conteúdo da 0.4.0 de `claude/project-thread-nzso8z` (motor realista, base e negociações, eventos, estatísticas e recordes, repercussão do mata-mata). Trabalho novo deve partir desse ramo. O `nzso8z` ficou para trás e não tem a UI 2.0.
- Na junção, as telas seguiram a UI 2.0 (sem o overall na interface, só estrelas) e ganharam os plurais certos da 0.4.0. Os estilos de jogador das duas linhas foram somados. A evolução usa a fase de carreira da 1.0.0 (`_career_arc`), com o potencial assentado (`_settle_potential`) e a deriva da 0.4.0. O teto dos craques e o peso por posição vêm calibrados da 0.4.0. O aviso de conquista ficou no topo, compacto, como na UI 2.0. O menu ☰ continua na cor do clube do técnico.
- A evolução foi recalibrada depois da junção (`ARC_BIAS` e salto menor perto da elite em `_career_arc`, superestrelas mais raras em `STARTER_SHIFT`). Com `tools/ratings_report.gd -- --years=4`, o 90+ fica entre 3 e 4 e o 85+ perto de 100.
- Também entraram a repercussão do mata-mata (`claude/repercussao-titulo-qumdw2`) e as palestras e a narração de rádio (`claude/palestras-narracao-1b2sru`). APK com tudo: `builds/MaisUmaRodada-1.0.0-unificada-2026-10-05.apk`.
- O `main` ainda só tem o commit inicial (o dono pede para perguntar antes de juntar).
- O código do jogo fica em `mais-uma-rodada/` (Godot 4.7.2). Os APKs ficam em `builds/`: abrir o link do GitHub no celular, logado, e tocar em Download.

### Olheiros, tabelas que rolam de lado e RodadaScore (06/10, ramo `claude/scout-rodadascore-8c516x`)

- Parte de `claude/bolinhas-narracao-5wp2pg`. Outras threads trabalham em paralelo em ramos próprios a partir do mesmo ponto (partida/rostos/negociações, mundo mais real, elencos, escudos); este ramo mexe só em olheiros, tabelas e estatísticas. APK: `builds/MaisUmaRodada-1.0.0-scout-rodadascore-2026-10-06-debug.apk`.
- **Olheiros refeitos** (`scripts/systems/scouting.gd`, `scripts/ui/components/scout_report_view.gd`, aba Mercado › Olheiros):
  - Missões que duram rodadas: por perfil (foco Melhor disponível, Pronto para jogar, Jovem promessa ou Oportunidade; setor, origem, idade), uma liga inteira (4 rodadas) ou um jogador (botão "Observar de perto" no relatório; 1 rodada no país, 2 fora). A primeira leva de nomes chega na hora; `Scouting.tick` (chamado em `InboxManager.after_user_turn`) avança cada missão e, no fim, o olheiro manda mensagem na caixa de entrada.
  - Missões ao mesmo tempo: 1 a 3 (`Scouting.slots`: nível do olheiro ≥ 0,55 e reputação do clube ≥ 70).
  - Conhecimento 0–100% por jogador (`stats.scouting.know`). Ele encolhe o ruído do potencial (`scout_noise` a partir do original em `n0`) e sobe a confiança da avaliação (`PlayerAssessment.confidence` faz lerp entre a base e o teto do olheiro). Relatórios antigos valem 70%.
  - Relatório: letra A–D e rótulo (Contratar, Boa opção, Para compor elenco, Não recomendado; `Scouting.verdict`), nível hoje e até onde pode chegar, encaixe no elenco, estilo, pé, pontos fortes e fracos (mais itens quanto mais visto), personalidade a partir de 60% e lesões/regularidade a partir de 80%, números da temporada. A tabela de relatórios tem Recom., Visto e Potencial e filtros Todos/Recomendados/Novos.
  - `Scouting.send_mission` continua existindo (ferramentas de captura e tour usam).
- **Tabelas que rolam de lado** (`scripts/ui/kit/data_table.gd`): o nome fica preso e as colunas de números passam com o dedo; um trilho fino acima do cabeçalho mostra que há mais colunas e onde você está; a posição da rolagem fica guardada ao ordenar. `PlayerTable` agora mostra todas as colunas em toda visão (a visão só escolhe as primeiras; `REST` define a ordem do resto) e ganhou Min, RS (nota RodadaScore), Fin, PD, Des, Passe e Cartões. Colunas próprias da tela (mercado: Encaixe e Pede; treino) entram logo depois das da visão, também no celular. A classificação no celular em pé virou `TableRows.standings_table` (J, SG e PTS e, de lado, V, E, D, GP, GC, Últimos 5, Aproveitamento); no tablet segue a linha antiga.
- **RodadaScore** (`scripts/systems/league_stats.gd`, `scripts/ui/screens/league_stats_screen.gd`, rota `league_stats`): página de estatísticas da liga no estilo WhoScored, com "Powered by RodadaScore". Abas Resumo (melhores notas, times em destaque, a liga em números), Times (Geral/Ataque/Defesa/Disciplina; toque abre pontos fortes, fracos e estilo do time), Jogadores (Geral/Ataque/Defesa/Passe/Goleiros, setor, Regulares, Por 90 min) e Seleção da temporada (4-3-3 pela nota). Entradas: aba Números das Competições ("Estatísticas completas") e menu ☰ › Clube › Estatísticas da liga. Posse, finalizações sofridas e xG contra são somados a cada jogo de liga em `league.table[clube]["ts"]` (`LeagueStats.record`, chamado em `SeasonManager._apply_match`); save antigo cai nas somas dos jogadores e mostra "–" na posse até jogar.
- **Falta / ideias para seguir:** conferir a folha do relatório e a mensagem de fim de missão num celular de verdade; botão "Pedir relatório" também no perfil do jogador de outro clube (hoje só no relatório e no painel do mercado); os goleiros dominam as melhores notas porque a nota de partida do motor favorece goleiros (assunto do motor, não desta tela); mostrar o RodadaScore também para copas; a classificação em grupos (split) perde os rótulos de grupo no celular.
- Conferido com `tools/check_scripts.gd` (0 erros) e capturas 390x844 (`--only=league_stats:summary,league_stats:teams,league_stats:players,league_stats:xi,market:scout,table,squad --rounds=18 --lang=pt`). Testes completos não rodados.

### Mundo com mais impacto (06/10, ramo `claude/mundo-impacto-mtmev0`)

- Pedido do dono: "tornar o mundo mais real, mais impacto". Parte de `claude/bolinhas-narracao-5wp2pg` e já traz o mercado sul-americano (`claude/mercado-sulamericano-1ipxqh`) juntado: a IA voltou a negociar nos fins de semana de estadual, entram a regra dos menores de 18, a solidariedade da FIFA e os promedios. APK: `builds/MaisUmaRodada-1.0.0-mundo-impacto-2026-10-06-debug.apk`.
- **Marcas que ficam** (`scripts/systems/aftermath.gd`, classe `Aftermath`). Título, fim de jejum, copa, acesso, vice (dói mais para o rival ou por 1 a 3 pontos), final perdida, eliminação para o rival, rebaixamento, rival campeão e goleada em clássico viram marcas do clube em `world.stats["af"]`. Cada marca tem peso e meia-vida em semanas de temporada. Saves antigos começam sem marcas.
  - **Torcida.** O clima volta toda semana para `Aftermath.mood_target`, um patamar que as marcas e o jejum puxam (antes era sempre 60). Público e camisas já dependem do clima, então sentem junto.
  - **Jejum.** `drought_years` / `drought_pressure` (clube grande da 1ª divisão, a partir de 6 anos). Quebrar a fila ou ganhar o 1º título vira manchete. Fila em número redondo (10, 15, 20 anos...) vira notícia na virada do ano.
  - **Diretoria da IA.** `Aftermath.sting` entra no `People.on_season_end`: perder título ou final para o rival conta como posições abaixo da meta. O técnico demitido assim usa o motivo "ferida" ("não resistiu depois de perder a final para o X"). Estadual e supercopa quase não pesam.
  - **Virada do ano** (`Aftermath.season_open`, depois dos orçamentos e antes do mercado das férias). Presidente vaidoso, exigente ou populista que levou a pancada abre o cofre (verba +25 a 45%). O presidente do usuário cobra "Ninguém aqui esqueceu".
  - **Mercado.** Recém-rebaixado vende quem está acima do nível por ~78% (`sell_mult` em `MarketAI._seller_mult`) e esses jogadores querem sair (`exit_pull` em `player_interest`). O campeão atrai um pouco mais.
  - **Vestiário.** No mata-mata decidido a moral segue o confronto, não o placar do dia (`_apply_match`). Por semanas, a marca fresca puxa a moral do elenco (`_dressing_room`).
  - **Imprensa.** O assunto volta de 3 a 8 semanas depois (uma vez por clube a cada 6 semanas, e só se o clima ainda conta a história) e um ano depois, para o clube do usuário.
- **Ferramenta.** `godot --headless --path . --script res://tools/aftermath_report.gd -- --seasons=2 [--league=BRA1] [--cal=ano|eu]` mostra as marcas, clima × patamar, jejuns, vendas dos rebaixados e as notícias geradas. Em 2 temporadas no Brasil: Corinthians quebrou jejum de 9 anos, Palmeiras e São Paulo demitiram depois de finais perdidas para o rival, o Palmeiras abriu o cofre (+45%) e o Vasco rebaixado vendeu 3 titulares. A média ficou em 2,74 gols por jogo (motor rápido, todas as ligas; o motor não foi mexido).

**O que falta (próximos passos, nesta ordem):**
1. Mostrar as marcas na tela do clube, aba História: "Último título da liga: 2019 (há 7 anos)" e uma lista curta de marcas recentes (ano e texto). Usar `UIKit.kv` e as linhas do `_history_card` em `club_screen.gd`, seguindo o DESIGN.md, sem card novo.
2. Pré-jogo e ganchos: quando o próximo adversário é quem deixou a marca (final, vice), dar o gancho de reencontro em `StoryHooks` (`Rivalry.last_grudge` já cobre a revanche do clássico; conferir para não duplicar).
3. Calibrar com `aftermath_report` num calendário europeu (`--cal=eu --league=ENG1`). Ver se os técnicos demitidos por "ferida" ficam em 1 a 3 por temporada na 1ª divisão e se o clima não fica preso nos extremos.
4. Traduções EN/ES das notícias novas (o dono tinha deixado EN/ES em segundo plano).

### Bolinhas seguindo a narração (05/10, ramo `claude/bolinhas-narracao-5wp2pg`)

- Parte de `claude/elencos-realistas-k0e7o1` com o campo clássico 2D de `claude/palestras-narracao-1b2sru` juntado. É o ramo mais novo. APK: `builds/MaisUmaRodada-1.0.0-bolinhas-narracao-2026-10-05-debug.apk`.
- **Cada lance narrado vira jogada no campo, com os jogadores citados.** `match_screen._beats` lê os eventos do minuto em ordem (antes só o último lance era encenado: defesa seguida de escanteio mostrava só o escanteio). Falta + cartão + jogador caído é uma jogada; falta perigosa + cobrança sai do mesmo lugar (`PitchMotion._fk_spot`); escanteio que vira finalização é cobrado por quem foi para a bandeira (escanteio curto quando o passe final é de outro).
- **Minutos sem perigo** (`poss_*` da narração: ponta, virada, ligação direta, pressão, saída desde o goleiro, tiro de meta, lateral, recuo, tabela, condução, pivô, troca de passes, passe cortado, cruzamento afastado) têm roteiro próprio em `PitchMotion._script_poss`, com quem tem a bola (p), com quem joga (p2) e quem corta (d).
- **Narração presa ao campo.** O PitchMotion põe marcos na fila (`mark`, `on_mark`): começo da jogada, momento decisivo (chute chegou, apito, bandeira, passe recebido) e apito do pênalti. A tela segura cada linha até o marco dela (`_gate_for`; limite de 7 s). No normal tudo é sincronizado e o minuto espera a jogada; no rápido só chances, gols e faltas que valem algo; no turbo e em "Só narração" a narração corre solta.
- **Corredor da chance.** A simulação agora grava `ln` (0 esquerda, 1 meio, 2 direita) nas chances, o mesmo corredor que ela usou no confronto pelos lados; cruzamentos e jogadas saem desse lado. Só apresentação: placares não mudam (teste "partida ao vivo = partida instantânea" ok).
- **Postura tática no desenho** (`PitchMotion.set_tactics`): linha alta/baixa, largura, pressão e mentalidade mudam o bloco sem bola e a altura do time com bola.

### Cores no campinho, negociações e cabelos (06/10, mesmo ramo)

- APK: `builds/MaisUmaRodada-1.0.0-cabelos-negociacoes-2026-10-06-debug.apk`.
- **Cores**: `match_screen._team_colors` usa a cor que mais aparece no uniforme (`_dot_colors`) com anel de contraste; visitante escolhe o uniforme mais diferente (ΔE mínimo `DOT_MIN_DE`), goleiros por `_gk_color`.
- **Negociações** (`transfer_manager.gd`): preço pedido depende do tamanho de quem compra; multa rescisória paga à vista leva o jogador (perfil mostra a multa); jogador que quer sair barateia; clube honra a própria contraproposta na mesma janela e não sobe o valor; termos pessoais sem sorteio repetido.
- **Cabelos**: depois dos 28, quem tem entradas/coroa costuma passar máquina ou assumir a careca (sorteio à parte, `"calvo"`); careca rara abaixo dos 22. Conferir com `tools/hair_stats.gd` e `tools/squad_faces.gd`.

### Mesa de negociação (06/10, mesmo ramo; mercado sul-americano juntado)

- APK: `builds/MaisUmaRodada-1.0.0-mesa-negociacao-2026-10-06-debug.apk`. Ramo `claude/mercado-sulamericano-1ipxqh` juntado aqui.
- Compra vira reunião com o diretor do vendedor (`Negotiation._render_talk`): cada proposta tem resposta na hora, em voz direta (`TransferManager._director_line`), e ele cede um pouco a cada rodada até um piso (90% do pedido; 86% se precisa vender).
- Paciência por reunião (`meeting_patience`, 3 a 5) no lugar de 3 propostas por dia; proposta ofensiva gasta em dobro. Contraproposta vale até o fim da janela, mesmo com a reunião encerrada.
- "Levantar da mesa" (`walk_away`): clube que precisa vender (ou com jogador forçando saída) chama de volta uma vez por janela, com valor menor.

### Escudos e logos de competição (06/10, ramo `claude/escudos-caprichados-i5l8y5`)

Pedido do dono em 06/10: "Capriche bem mais nos escudos e logos de ligas". Parte de `claude/bolinhas-narracao-5wp2pg` e só mexe no desenho de escudos e logos (`scripts/ui/components/crest_view.gd`, `crest_art.gd`, `data/world/identity.json`, `data/world/clubs/*.json`, `tools/crest_sheet.gd`, `tools/crest_gen/`).

Feito:
- **Logos das 152 competições** (54 ligas, 19 continentais/estaduais, 71 copas nacionais, da liga e supercopas, 9 torneios de seleções; antes 82 tinham logo e o resto era um escudo dourado genérico). Cada logo é uma marca chapada (`"logo": true`): quadrado arredondado (`tile`), disco (`round`) ou escudo moderno (`badge`), com taça, bola em espiral, jogador chutando, leão, águia etc. Chaves novas do CrestView: `flag` (faixa com as cores da bandeira no alto), `num` (selo com o numeral da divisão), `wordmark` (nome embaixo, só com 72 px ou mais), `ring_c` (aro fino), `sym_top` (símbolo pequeno em cima, ex.: coroa do leão da Premier), `accent`.
- **Desenhos novos no CrestArt:** `trophy`, `trophy_ears`, `trophy_tall`, `trophy_globe`, `trophy_plate`, `trophy_lid` (com sombra `_d` e reflexo `_h`), `ball_swirl` (recortes `_c` na cor do fundo), `player_kick`, `globe`; `starball` é desenhado no código.
- **Escudos:** voltou o que se perdeu na junção de 27/09 (`2742294`): placa atrás do monograma em campo listrado (`plate`), filete interno, contorno escuro por fora, `canton`, `field: pale_cross`, `tc`, `hoops:2` com uma faixa só. Saíram o brilho e o degradê (DESIGN.md: sem brilho).
- Os louros agora ficam por baixo da faixa com o nome (antes as folhas comiam as letras).

Falta (nesta ordem):
1. Devolver os escudos de 27/09 que a junção trocou (98 clubes; lista: diferença entre `d3b4bed` e o ramo, menos os 13 refeitos depois: Grêmio, Flamengo, São Paulo, Internacional, Athletico, Barcelona, Liverpool, Chelsea, Tottenham, Man United, Ajax, Dortmund e Gladbach).
2. Mais capricho nos escudos de monograma genérico (muitos clubes menores só têm letras).
3. Folha antes/depois em `/mnt/project-files/escudos-caprichados/` e APK de teste em `builds/`.
4. PR para o dono olhar (perguntar antes de juntar).

Como conferir:
```
xvfb-run -a godot --path . --resolution 1420x1470 --script res://tools/crest_sheet.gd -- --logos --size=120 --cols=8 --h=1460 --out=/tmp/logos.png
xvfb-run -a godot --path . --resolution 1460x1480 --script res://tools/crest_sheet.gd -- --size=78 --cols=16 --h=1470 --offset=0 --out=/tmp/clubes.png
python3 tools/crest_gen/logos.py .          # refaz os logos em identity.json
python3 tools/crest_gen/logo_art.py scripts/ui/components/crest_art.gd   # refaz as taças/bola/jogador
```

### Posições da escalação (05/10)

- Mover posições não empilha mais ninguém. Antes, virar o centroavante em ponta-direita punha o jogador exatamente em cima do ponta que já existia. Agora `DatabaseManager._spread_custom` espaça as posições repetidas na mesma linha e afasta as vagas que se encostam.
- Na partida, companheiros ficam a pelo menos 4,2 m e adversários a 2,6 m (`PitchMotion.SEP_MATE` e `SEP_RIVAL`). Em barreira, escanteio e comemoração continua 1,3 m.
- No pré-jogo, o banco cabe acima do rodapé (`_fit_pitch`). Na partida, a narração tem altura mínima (`FEED_MIN_H`) e a tarja do gol fica por cima do campo. O layout da partida agora é da thread "Palestras e narração".
- Para conferir: `design_shots -- --only=!lineup` (ou `!lineup=C:4-4-2|9=AM`).

### Palestras e narração de rádio (05/10, ramo `claude/palestras-narracao-1b2sru`)

- Partiu da junção acima (`claude/posicoes-escalacao-hbrnjt`) e é o ramo mais novo.
- **Palestra.** As falas ficam em `scripts/systems/team_talk.gd` (`TeamTalk.LINES`), separadas por tom e por momento: antes do jogo (favorito, azarão, clássico, decisão, casa, fora) e no intervalo (vencendo por 1 ou 2+, empate, perdendo por 1 ou 2+, mandando no jogo sem vencer, sofrendo sem perder). A cada vez que o modal abre sai uma fala diferente por tom, com nomes do jogo ({star}, {their}, {gk}, {opp}). São 9 tons: os 6 antigos mais Mostrar confiança, Foco no plano e Mostrar decepção (`_talk_reaction` em `match_simulation.gd`, mesmo teto de ±5%). Repetir no intervalo o tom de antes do jogo rende 55%. Depois da escolha vem a "Reação no vestiário" com quem respondeu. Só o time do usuário dá palestra, então o motor calibrado não muda.
- **Narração de rádio.** Frases novas em `data/text/commentary.json`: categorias `radio_*` ("tempo e placar" nos minutos 8, 22, 38, 52, 68 e 83; tensão antes do chute; placar repetido depois do gol; abertura da fala do vestiário) e mais variações nas categorias de gol, chance, posse, falta etc. Elas só existem em português: em inglês e espanhol o `Commentary._allowed` usa só frases que têm tradução.
- **Tela da partida.** Em pé, o padrão é "Campo menor": campo deitado com ~20% da altura e a narração com o resto. O botão ao lado das abas alterna Campo menor, Campo grande (o vertical de antes) e Só narração (`AppSettings.match_view`, salvo nas opções). O lance mais recente entra com letra maior.
- **Campo no visual clássico 2D** (pedido de 05/10, "estilo FM 2008"). Padrão: campo liso sem estádio, bolinhas na cor do uniforme com número, bola branca com contorno e rastro, nome de quem conduz, sem zoom de câmera, e embaixo do campo uma barra com a frase da narração do lance que está sendo encenado (`PitchView.classic`, `_draw_match_classic`, `show_caption`). O botão ao lado das abas abre a folha "Campo e narração": espaço (menor, grande, só narração) e visual (Clássico 2D ou Transmissão, `AppSettings.match_gfx`).

## Como conferir e gerar o APK

Rode dentro de `mais-uma-rodada/`:

```
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd                  # deve dizer "com erro: 0"
godot --headless --path . --script res://tests/mobile_regression.gd             # deve dizer MOBILE_REGRESSION_OK
xvfb-run -a godot --path . --resolution 720x1280 --script res://tools/design_shots.gd -- --out=/tmp/shots --only=hub,squad
PATH=<pasta do godot>:$PATH tools/build_debug_apk.sh saida.apk                  # APK de teste assinado com a chave debug
```

Mais ferramentas:

- `tools/realism_report.gd` mede o realismo do motor numa temporada inteira. Use `--full` para o motor lance a lance e `--seasons=N` para várias temporadas.
- `tools/tactic_lab.gd` compara planos táticos.
- `tools/engine_report.gd` mostra gols, placares, cartões e gols por posição.

Os testes completos (`tests/run_tests.gd`) passam de 30 minutos, por isso rode só os testes da área que mudar.

## O que já foi feito (28 e 29/09)

- **Tablet e paisagem.** A base de desenho gira com a tela: 720x1280 no celular e 1100x1500 no tablet. As telas ficam mais largas, com até 3 colunas. Elenco, mercado e tabela ganharam colunas de números. O pré-jogo fica em 2 colunas e o menu é centralizado.
- **Correções do Codex** (`codex/mobile-performance-0.4.1-20260928`). A tela da partida aguenta girar o celular, o relayout na rotação foi agrupado, o cache de rostos é limpo quando o celular avisa que está com pouca memória, e o teste `tests/mobile_regression.gd` foi incluído.
- **Estabilidade.**
  - Simular, fim de partida, fim de temporada, carregar e começar carreira rodam em segundo plano, com o aviso `busy_note` e sem mexer na interface durante o trabalho.
  - Salvar ao pausar o app não bloqueia mais.
  - Os menus ficaram mais rápidos porque o tema é repintado de uma vez.
  - O jogo gasta menos memória e não sobram nós de interface depois das partidas.
  - A busca do mercado usa índice.
- **Varredura de bugs.** Telas mais largas que o celular, fechamento ao sair do app, posição errada na tabela, cerimônia presa na tela e textos cortados no tablet.
- **Motor de partida realista.**
  - Média de uns 2,6 gols por jogo, artilheiros entre 20 e 34 gols e líderes de assistência com até 15.
  - As táticas valem conforme o adversário.
  - A IA escolhe o plano antes do jogo e muda a postura a partir dos 55 minutos.
  - O modo rápido e o motor completo usam as mesmas regras (`state_mods`).
- **Seleções.**
  - Datas FIFA no calendário: as ligas europeias param e as brasileiras não.
  - Convocações anunciadas uma semana antes, clima de Copa e uniformes das seleções.
  - O técnico de seleção vem pelo mercado de técnicos (`scripts/systems/national_coach.gd`): vagas, candidaturas e escolha pela reputação. Não dá para escolher seleção no início da carreira.
  - O calendário europeu agora começa em 1º de agosto, sem pausa de inverno, e termina em 31 de maio. Isso ainda espera o OK do dono.

## Repercussão de mata-mata (05/10)

Pedido do Gregory: perder um título no agregado (Inter x Grêmio) saía com pós-jogo "positivo" porque tudo olhava só o placar do dia.

- `scripts/systems/tie_stakes.gd` (`TieStakes.of`) diz se o jogo decidiu um confronto (jogo único ou volta, copa ou playoff de liga): vencedor pelo agregado e pênaltis, se era final, se valia taça ou acesso, e o peso (1 = final com título).
- Com isso, no jogo decisivo vale o confronto: torcida e diretoria (`BoardManager.after_tie`), apoio e reputação do técnico, coluna de jornal (`People._tie_column`), coletiva (`PressRoom._tie_question`), manchete (`NewsManager._tie_news`) e eventos. Ganhar a volta e perder a taça agora é derrota, e mais pesada no clássico.
- Feitos do jogo (`ManagerFeats`) não dão bônus a quem ganhou o jogo e caiu. Técnicos da IA também sentem a final perdida.
- O motor de partida não mudou.

## Repercussão de mata-mata (05/10)

Pedido do Gregory: perder um título no agregado (Inter x Grêmio) saía com pós-jogo "positivo" porque tudo olhava só o placar do dia.

- `scripts/systems/tie_stakes.gd` (`TieStakes.of`) diz se o jogo decidiu um confronto (jogo único ou volta, copa ou playoff de liga): vencedor pelo agregado e pênaltis, se era final, se valia taça ou acesso, e o peso (1 = final com título).
- Com isso, no jogo decisivo vale o confronto: torcida e diretoria (`BoardManager.after_tie`), apoio e reputação do técnico, coluna de jornal (`People._tie_column`), coletiva (`PressRoom._tie_question`), manchete (`NewsManager._tie_news`) e eventos. Ganhar a volta e perder a taça agora é derrota, e mais pesada no clássico.
- Feitos do jogo (`ManagerFeats`) não dão bônus a quem ganhou o jogo e caiu. Técnicos da IA também sentem a final perdida.
- O motor de partida não mudou.

## Elencos com roteiro e overall coerente (05/10)

Ramo `claude/elencos-realistas-k0e7o1`, feito sobre a linha unificada (`claude/posicoes-escalacao-hbrnjt`). Só muda a criação do mundo: carreiras salvas não mudam, só carreira nova.

- **Roteiro do elenco** em `scripts/generation/squad_story.gd` (`SquadStory`), chamado por `PlayerGenerator.create_squad`:
  - Hierarquia dos titulares (`RANK_OFFSETS`): o melhor fica uns 4,5 acima da média do time e o elo fraco uns 4 abaixo; clube grande tem o topo mais aberto. `calibrate_xi` continua acertando a média do time pela força do clube.
  - Capitão (27-33 anos, traço Líder, 4 a 10 anos de casa), ídolo veterano no banco (32-36, traço Ídolo, às vezes cria que nunca saiu), joia da base (17-18 anos, teto alto conforme o clube), repatriado (cria que rodou fora e voltou; o passado começa no clube em `CareerBackfill`) e astros estrangeiros veteranos na Arábia, Catar, Emirados, EUA e China.
  - O estrangeiro chega mais novo nas vitrines (Portugal, Holanda, Bélgica) e mais velho no Golfo (`IMPORT_AGE`).
  - `SquadStory.roles` só existe durante a geração (o passado lê dali); não vai para o save.
- **Overall coerente.** O ponto forte do jogador passa no máximo uns 10 do overall (`PlayerGenerator.spike_cap`); garoto de 17-20 anos sempre tem margem de potencial; o status Titular é o melhor goleiro e os 10 melhores de linha (antes eram os 12 de maior overall, e o 2º goleiro podia virar titular). Nomes repetidos no mesmo elenco usam o nome completo.
- **Boas-vindas.** "A voz da experiência" prefere o ídolo ou o líder com mais anos de casa e mostra as temporadas no clube.
- **Escala.** A escala do overall não mudou: a média dos titulares por clube é a mesma. No começo há 3 jogadores 90+ (antes 4) e 85+ caiu de 104 para ~90. O topo de cada time ficou um pouco mais alto e o elo fraco um pouco mais baixo, o que pode mexer de leve em valores dos melhores de cada clube.
- **Motor.** Motor lance a lance (25 datas): 2,70 gols por jogo, contra 2,65 na base. No modo rápido, temporada inteira: 2,73 contra 2,70.
- **Ferramenta.** `tools/squad_report.gd` mostra elencos por extenso (papel, anos de casa, passagens) e a distribuição dos papéis: `godot --headless --path . --script res://tools/squad_report.gd -- --clubs=Flamengo,Real Madrid`.

## Passado sem começar emprestado (06/10)

Ramo `claude/historico-inicio-carreira`, feito sobre `claude/bolinhas-narracao-5wp2pg`. Só muda o passado gerado na criação do mundo (`CareerBackfill`), então vale para carreira nova.

- O passado é montado do presente para trás. O empréstimo podia cair no primeiro ano, e 5,6% dos jogadores começavam a carreira emprestados. Também podia vir depois de um clube que não era o dono do passe.
- Agora cada empréstimo guarda o clube dono (`plan[ano][6]`). O ano antes do empréstimo é sempre no dono, seja na base ou numa contratação. Se o primeiro ano era empréstimo, ele vira a estreia no dono. Empréstimo só a partir dos 18 anos.
- `tools/squad_report.gd` mostra a parte dos jogadores que começam emprestados (agora 0%) e a dos empréstimos entre duas passagens pelo mesmo clube (99,5%).
- **Falta.** Desta parte, nada. Para seguir, junte este ramo em `claude/bolinhas-narracao-5wp2pg` quando a conversa das negociações entre clubes terminar lá; os dois mexem em arquivos diferentes. O APK mais recente com este trabalho é `builds/MaisUmaRodada-1.0.0-historico-inicio-2026-10-06-debug.apk`.

## Uniformes com formato anatômico (06/10)

Pedido do dono: não refazer os uniformes, só deixar camisa, calção, meias e chuteiras mais anatômicos.
Branch `claude/project-thread-1j6fph` (a partir de `claude/hopeful-newton-8avbo4`). Só `scripts/ui/components/kit_view.gd` mudou:
- Camisa: tronco em trapézio (ombro caindo do pescoço, peito largo, cintura afinando), mangas caídas junto ao corpo com deltoide arredondado, luz no peitoral e no ombro.
- Calção com quadril arredondado, barra mais baixa por fora e gancho; faixas laterais e barras seguem a nova lateral (`_side_strip`, `_hem_strip`).
- Coxa e joelho com sombra da barra; meião com panturrilha e tornozelo; chuteira com bico virado para fora, solado e travas.
- Estampas, golas, estilos de manga/calção/meião, cores e chaves de save não mudaram.
- Antes/depois: /mnt/project-files/uniformes-anatomicos/. APK: builds/MaisUmaRodada-1.0.0-uniformes-anatomicos-2026-10-06-debug.apk.

## Pedidos em andamento ou pendentes (pedido de 29/09, 01:35)

A ordem combinada:

1. Ratings, potenciais, atributos, valores e mais estilos de jogador. Feito em 04/10: 8 estilos novos, 3 traços, 3 filosofias de clube, elite comprimida (2 jogadores 90+ estáveis em 4 temporadas, `tools/ratings_report.gd -- --years=4`), valores e salários com curva de idade e contrato. Os gols continuam em 2,63 por jogo. Ponto a observar: o valor do jogador mais caro cai de € 140M para € 75M em 4 temporadas só de evolução.
2. Categorias de base: mais competições (sub-17, sub-20, Copinha, liga jovem europeia), academia e negociações mais profundas (parcelas, bônus, percentual de revenda, cláusula, empréstimo com opção de compra). Feito.
3. Interface. Em andamento.
   - Legibilidade, estados de hover e cores de destaque, a tela de números, paisagem e tablet.
   - Tirar a cara de "jogo feito às pressas por IA": nada de textos-propaganda cheios de superlativos e emojis, telas amontoadas ou visual genérico. O visual deve ser coerente e caprichado.
   - O jogo pode ficar maior em tamanho, isso não é problema.
   - Feito numa primeira passada: aviso de conquista no pé da tela (não cobre mais a barra nem o "Pular"), fim do "Simular" sem vão, plurais certos (`Fmt.n_of`, sem "jogo(s)"), menos microcopy na negociação, seleção e base, anel de foco nos botões, menu ☰ sempre na cor do clube do técnico, quadro de líderes em grade na aba Números, tabela do elenco com colunas alinhadas, recorte e ordem do elenco numa fileira, menu inicial em lista e início deitado compacto. Capturas em `/mnt/project-files/interface-2026-09-29/antes` e `depois` (prefixos `f_`, `fl_` claro, `fland_` deitado, `ftab_` tablet).
   - Falta: varrer os textos explicativos que sobraram (tutorial, editor, regras de copa na base), os "(s)" das notícias geradas e as outras telas de estatística (perfil > Números, seleções).
4. Mais eventos no jogo, mais cabelos e barbas e mais estatísticas. Feito em 05/10:
   - **Eventos.** 15 dilemas novos em `scripts/systems/event_pack.gd` (tipos registrados em `EventManager.KINDS`): antecipar a volta de lesionado (com risco de recaída), renovação travada por luvas, rival assediando o craque, provocação antes do clássico, corte na folha, reunião com a diretoria (meta de pontos em 3 jogos), protesto no CT, despedida de ídolo, pedido de empréstimo, empresário cobrando comissão, série de bastidores, boato de demissão, alerta de desgaste, bicho por vitória e tratamento com médico particular. As consequências que chegam depois ficam em `world.stats["ev2"]` e são conferidas a cada jogo. `tools/events_smoke.gd` agora passa por todos os tipos.
   - **Rostos.** 14 penteados (211-224) e 8 barbas (141-148) no fim das listas. Os novos entram num sorteio à parte (`FaceGen._newer_pick`, `HS_V1`/`BD_V1`), então o rosto de quem já existia não muda. Saem em cerca de 6% dos cabelos e 4% das barbas; os chamativos (coque samurai cacheado, nagô com risco) em menos de 0,1%. Catálogo em `/mnt/project-files/rostos-2d/novos-2026-10/`.
   - **Estatísticas.** Duelos aéreos ganhos, faltas e gols sofridos pelo goleiro (`Player.S_AERIAL`, `S_FOULS`, `S_CONCEDED`; saves antigos completam com zero). Recordes do clube em `club.marks` (sequências de vitórias, invencibilidade e sem sofrer gol, maior vitória e maior derrota). Perfil > Números ganhou por 90 minutos, chutes no alvo, minutos por gol e o bloco do goleiro; Carreira ganhou gols por jogo, G+A por jogo, craque do jogo e jogos sem sofrer gol. Estatísticas da equipe ganhou novos destaques e o cartão de recordes; Tabela > Números ganhou duelos aéreos, jogos sem sofrer gol (goleiros) e craque do jogo. Os números novos são sorteados depois dos antigos, então placares e o realismo não mudam.
   - Capturas em `/mnt/project-files/conteudo-2026-10/`. Para capturar um evento específico: `--only=~event=tipo`.
   - Traduções en/es dos textos novos incluídas.

## Decisões pendentes com o dono

- Patrocinadores de casa de apostas: a recomendação é trocar por outros ramos, para a classificação da Play Store.
- Calendário europeu sem pausa de inverno: a recomendação é manter.

## Para publicar (só o dono consegue fazer)

- Criar a chave de envio e colocar os segredos no GitHub.
- Ligar o GitHub Pages (para o link da política de privacidade).
- Criar os 3 produtos no Play Console.
- Fazer o teste fechado com 12 testadores por 14 dias.
- Tirar prints novos para a loja.
- Confirmar que o target SDK é 36.

Mais detalhes em `docs/PUBLICAR.md`.

## Regras do projeto

- Falar com o dono em português.
- O mundo do jogo é fictício: nada de nome de jogador real.
- As listas de rostos, cabelos e barbas só crescem no fim, nunca são reordenadas, porque o save guarda índices.
- Os saves antigos precisam continuar abrindo: todo campo novo tem valor padrão.
- O dono não gosta de texto explicando a interface (microcopy).
- Perguntar antes de juntar no `main`.
