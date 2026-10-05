# Continuar daqui (atualizado em 05/10/2026)

## Atenção: há duas linhas do jogo (05/10)

- `claude/youthful-newton-hey7og` (e este ramo, `claude/posicoes-escalacao-hbrnjt`, que parte dele): a UI 2.0, versão 1.0.0. É a que o dono e o Gregory estão jogando no celular (os prints de 02/10 são dela).
- `claude/project-thread-nzso8z`: versão 0.4.0 com o motor realista, base, negociações, eventos e estatísticas de 04 e 05/10. Ela não tem a UI 2.0, e a UI 2.0 não tem esse conteúdo. As duas se separaram em 29/09 (`2b8f81b`) e ainda precisam ser juntadas.

### Posições da escalação (05/10, ramo `claude/posicoes-escalacao-hbrnjt`)

- Mover posições não empilha mais ninguém. Antes, virar o centroavante em ponta-direita punha o jogador exatamente em cima do ponta que já existia. Agora `DatabaseManager._spread_custom` espaça as posições repetidas na mesma linha e afasta as vagas que se encostam.
- Na partida, companheiros ficam a pelo menos 4,2 m e adversários a 2,6 m (`PitchMotion.SEP_MATE` e `SEP_RIVAL`). Em barreira, escanteio e comemoração continua 1,3 m. Numa simulação de 6000 quadros, os pares de companheiros a menos de 3 m caíram de 639 para 107.
- No pré-jogo, o banco cabe acima de velocidade e Iniciar partida (`_fit_pitch`).
- Na partida, a narração tem altura mínima e não some mais atrás da barra quando há gols no placar. A tarja do gol fica por cima do campo, e Pausar, o ritmo e Mais ganharam nome como os outros botões.
- Para conferir: `design_shots -- --only=!lineup` (ou `!lineup=C:4-4-2|9=AM`).
- APK: `builds/MaisUmaRodada-1.0.0-posicoes-2026-10-05.apk` (mesmo certificado, instala por cima).


Esta é a nota para quem pegar o jogo depois: uma pessoa, o ChatGPT/Codex ou outra sessão do Claude.

## Onde está o jogo

- O ramo de trabalho é `claude/project-thread-nzso8z` e reúne tudo. O `main` ainda só tem o commit inicial e nada foi juntado nele (o dono pede para perguntar antes).
- A versão continua 0.4.0.
- O código do jogo fica em `mais-uma-rodada/` (Godot 4.7.2).
- O APK mais recente fica em `builds/` nesse ramo. Para instalar: abrir o link do GitHub no celular, logado, e tocar em Download.

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

## Feito na tarde de 29/09

- **Testes e ferramentas voltaram a rodar.** Com `--script`, o Godot compila o script principal antes de registrar os autoloads. Os sistemas passaram a depender de componentes de interface (`scouting` → `player_row_view` → `ui_kit` → `AudioManager`), e com isso `tests/run_tests.gd`, `tools/realism_report.gd` e as outras ferramentas paravam de compilar. Agora o som passa por `Sfx` (`scripts/core/sfx.gd`), que procura o autoload na hora. **Não escreva `AudioManager.` fora do próprio autoload.**
- **Ratings.** Meia dúzia de jogadores passa de 90 (antes o máximo era 89). Os titulares mudam de nível conforme a função (`STARTER_SHIFT`), e o craque do elenco quase nunca é lateral. Antes os três melhores do mundo eram laterais-esquerdos.
- **Estilos novos.** Volante líbero, armador itinerante, trequartista, intérprete de espaços, ponta de área e cabeceador. Cada um fica com 6 a 8% da função.

## Repercussão de mata-mata (05/10)

Pedido do Gregory: perder um título no agregado (Inter x Grêmio) saía com pós-jogo "positivo" porque tudo olhava só o placar do dia.

- `scripts/systems/tie_stakes.gd` (`TieStakes.of`) diz se o jogo decidiu um confronto (jogo único ou volta, copa ou playoff de liga): vencedor pelo agregado e pênaltis, se era final, se valia taça ou acesso, e o peso (1 = final com título).
- Com isso, no jogo decisivo vale o confronto: torcida e diretoria (`BoardManager.after_tie`), apoio e reputação do técnico, coluna de jornal (`People._tie_column`), coletiva (`PressRoom._tie_question`), manchete (`NewsManager._tie_news`) e eventos. Ganhar a volta e perder a taça agora é derrota, e mais pesada no clássico.
- Feitos do jogo (`ManagerFeats`) não dão bônus a quem ganhou o jogo e caiu. Técnicos da IA também sentem a final perdida.
- O motor de partida não mudou.

## Pedidos em andamento ou pendentes (pedido de 29/09, 01:35)

A ordem combinada:

1. Ratings, potenciais, atributos, valores e mais estilos de jogador. Primeira parte feita em 29/09 à tarde (veja acima). Os valores e o potencial dos jovens foram medidos e estão plausíveis. Depois de mexer, rodar `tools/realism_report.gd` e conferir que os gols continuam realistas.
2. Categorias de base: mais competições (sub-17, sub-20, Copinha, liga jovem europeia), academia e negociações mais profundas (parcelas, bônus, percentual de revenda, cláusula, empréstimo com opção de compra). Em andamento.
3. Interface.
   - Legibilidade, estados de hover e cores de destaque, a tela de números, paisagem e tablet.
   - Tirar a cara de "jogo feito às pressas por IA": nada de textos-propaganda cheios de superlativos e emojis, telas amontoadas ou visual genérico. O visual deve ser coerente e caprichado.
   - O jogo pode ficar maior em tamanho, isso não é problema.
4. Mais eventos no jogo, mais cabelos e barbas e mais estatísticas.

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
