# Correções 0.5.1 — interface, simulação e Champions

Base: `3074775d2c371028fc98e7b1782ac26a429f2d81`, UI 2.0 / versão 0.5.0,
branch `claude/gallant-hawking-3csszp`. Não incorpora as branches `codex/*`.

## Simulação e ciclo de vida

- Pedidos repetidos de início/fechamento de rodada não executam outra mutação do mundo
  enquanto a thread de trabalho está ativa. O trabalhador usa uma entrada interna própria.
- Sair da folha de simulação agenda o encerramento do lote. A interface não espera
  a rodada inteira em `wait_for_task_completion`; o save continua após a conclusão.
- Avançar o calendário e encerrar a temporada também rejeitam reentrada durante trabalho.
- Retratos 3D: cache móvel reduzido de 260 para 48 texturas; descarte sob aviso de memória;
  pedidos duplicados por visualizador eliminados. Durante a partida, os retratos prontos
  continuam disponíveis, com fallback 2D para os demais, sem iniciar novas renderizações 3D.

O fechamento relatado no Android **não foi reproduzido**. Foram corrigidos caminhos
concretos de concorrência, bloqueio e pressão de memória; não há logcat nem aparelho
conectado para atribuir o fechamento original a uma causa específica.

## Interface móvel

- Uma implementação de rotação da partida, compartilhada pela tela base e móvel.
  Campo muda de orientação e recupera a altura correta ao voltar para retrato.
- Em paisagem curta, campo e comandos cabem; clima, xG e detalhes permanecem no painel.
- Navegação lateral ajusta a altura dos cinco destinos: antes excedia o canvas de
  600 px, deslocando a interface 22 px para cima e cortando o título.
- Classificações têm linhas com área de toque de 84 px; controles superiores de 72 px
  e navegação recebem foco por teclado. Nomes completos continuam nas dicas/perfis.
- Detalhes da partida e progresso de simulação abandonam larguras mínimas que estouravam
  a tela. A lista de resultados limita sua altura conforme o viewport.

## Champions

- 36 clubes, quatro potes de nove; oito adversários distintos, dois por pote,
  um jogo em casa e outro fora contra cada pote.
- Sem adversário da mesma associação e até dois da mesma associação adversária.
  Se um mod criar uma distribuição impossível, o sorteio avisa e preserva o calendário
  de 36 clubes com a melhor distribuição encontrada, relaxando somente essas restrições.
- Classificação única: 1–8 nas oitavas; 9–24 nos playoffs; 25–36 eliminados.
- Playoffs e oitavas com emparelhamento por posição. Chave mantida até a final,
  confrontos de ida e volta e final única neutra. Mandos protegidos por posição inicial.
- Desempates: pontos, saldo, gols, gols fora, vitórias, vitórias fora; ao fim da fase,
  desempenho dos adversários, disciplina e coeficiente do jogo.
- Classificação, jogos por rodada, tabela ao vivo, início e resumo da rodada usam o formato.
- A competição e seus critérios são gravados no save; copas antigas mantêm seu regulamento
  até terminar. A temporada seguinte recalcula as vagas dos três torneios em conjunto.

Adaptações do mundo do jogo: vagas por país continuam fixas; não foram implementadas as
eliminatórias de acesso ou vagas anuais por desempenho das associações. O coeficiente
usa reputação e força nacional existentes. As novas datas cabem no calendário unificado
do jogo; não reproduzem as datas reais da UEFA. Europa League e Conference não mudam.

Fontes oficiais consultadas em 29/09/2026:

- [Sorteio da fase de liga 2026/27](https://www.uefa.com/uefachampionsleague/news/02a8-216cd740d41f-fd3b45ac4a0f-1000--champions-league-league-phase-draw-all-36-teams-learn-their/)
- [Formato e classificação](https://www.uefa.com/news-media/news/0268-12157d69ce2d-9f011c70f6fa-1000--how-clubs-qualify-for-europe/)
- [Desempates da fase de liga](https://www.uefa.com/uefachampionsleague/news/0291-1bd88ae04870-e1e038c319e3-1000--champions-league-league-phase-standings-how-teams-level-on-/)

## Reprodução dos testes

Use uma pasta de dados separada ao rodar ferramentas que criam carreiras. Exemplo de
`mais-uma-rodada/override.cfg` temporário, removido antes da exportação:

```ini
[application]
config/use_custom_user_dir=true
config/custom_user_dir_name="MaisUmaRodada-QA-ui-match-champions"
```

Na pasta do projeto, com Godot 4.7.2:

```text
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tests/champions_regression.gd
godot --headless --path . --script res://tests/mobile_regression.gd
godot --headless --path . --script res://tools/sim_dialog_check.gd -- --games=12
godot --path . --script res://tools/mobile_match_review.gd -- --out=PASTA
godot --headless --path . --script res://tests/run_tests.gd
```

`mobile_match_review` visita classificação, jogos, detalhes, simulação, partida e painel
em 390×844, 844×390, 800×1280 e 1280×800. Verifica posição do cabeçalho, alcance dos
comandos, reentrada de rodada e encerramento assíncrono do lote. `champions_regression`
verifica 40 sorteios, duas copas completas, 189 partidas, desempates, disciplina,
save/recarga, legado e ambos os calendários. `mobile_regression` gira a partida 24 vezes.

As capturas e logs locais ficam em `output/fix-ui-match-champions`, fora do projeto.
Resultados de 29/09/2026:

- 350 scripts compilados, nenhum erro.
- Champions, regressão móvel, revisão visual/interação: zero falhas.
- 12 jogos em lote, save ao terminar; 3 partidas completas com recarga do save.
- Bateria geral: 50 passaram; um teste exigia que uma negociação aleatória sempre
  fechasse. A asserção agora verifica o teto de compra, o ágio quando há acordo e
  o motivo de recusa. Reexecução do teste de mercado: passou, sem alterar o sistema.
- As ferramentas de interface ainda emitem avisos de objetos/recursos retidos ao sair.
  Não houve erro de script durante os fluxos. Android físico não validado (ADB sem dispositivos).
- APK ARM64 0.5.1, versionCode 17, pacote `com.maisumarodada.futebol`, certificado
  idêntico ao APK 0.5.0 fornecido pelo usuário. `override.cfg` e ferramentas de QA ausentes.
- SHA-256 do APK: `be85034ea5686329fe251e1f01e5a2cfa9eba869db45d7905bff7a30676a98da`.

Capturas selecionadas em [images/ui-match-0.5.1](images/ui-match-0.5.1): tabela da liga
antes da revisão; classificação da Champions e partida depois, em celular/tablet.
