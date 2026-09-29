# Avaliações, perfil e tipografia — 0.5.3

Esta alteração continua a 0.5.2 do PR #60. A base de revisão é `fix/ui-match-champions-0.5.0`, não `main`. Não altera os formatos de competições nem a migração de nacionalidades daquela entrega.

## Como o jogador é avaliado

A interface passa de uma nota pública de overall para estrelas relativas ao elenco do usuário e à posição avaliada. `PlayerAssessment` usa atributos observados, familiaridade na posição, lacunas em atributos essenciais e qualidade da observação. As estrelas claras representam incerteza. O mesmo atleta pode ter uma avaliação diferente em outro elenco ou função.

A projeção usa idade e evolução recente observável. É uma estimativa heurística, não uma leitura do potencial oculto nem uma promessa de desenvolvimento. CA/PA continuam nos modelos e saves existentes, para manter a simulação compatível; só o editor permite revelá-los por uma ação explícita. Notas de partida e valores dos atributos permanecem numéricos.

O padrão foi aplicado a elenco, mercado, base, contratos, comparação, seleção, scout, pré-jogo/substituições, notícias e relatórios. Histórico passa a enfatizar jogos, gols, assistências e notas; mensagens já gravadas em saves antigos não são reescritas.

## Interface

- Perfil: identidade e ações primeiro; disponibilidade e condição; avaliação com pontos fortes e limitações. Atributos individuais aparecem antes do gráfico, que pode ser expandido. Cabeçalho compacto em paisagem.
- Número de camisa: mini uniforme visto de costas, com o número real e a cor/estampa do clube. Goleiros usam seu uniforme específico. O nome acessível continua sendo “Camisa N”.
- Nacionalidade, nascimento, cidadanias e seleção ficam organizados em Origem, sem repetição do país no cabeçalho.
- Linhas pressionadas/selecionadas cobrem a largura completa com uma superfície neutra, sem a barra lateral colorida ou alteração de escala. Corrigida a conexão de redimensionamento das tabelas ao reconstruir linhas.
- Seleções: país pode ser trocado em todas as abas. Consulta e cargo real são distintos. Clube francês não atribui o comando da França. Aceitar uma oferta pede confirmação e a camada de domínio rejeita atribuição sem oferta; cargos existentes não são apagados.

## Tipografia

Saira substitui Barlow em todo o tema: largura normal para dados e textos, semicomprimida para títulos e placares, com quatro combinações de peso/largura. Mantidos acentos, cifras e números tabulares. Créditos, gerador do tema e ferramentas de captura usam a mesma família.

É uma alternativa livre escolhida pelo usuário, não a fonte oficial do FC 27. A F37 documenta Cruyff Sans como uma fonte personalizada de EA SPORTS FC: https://f37.com/modifications/ea-sports-fc-pro . Não foi confirmada uma especificação pública de todas as fontes do FC 27.

Fonte Saira original, sem alteração do arquivo: https://github.com/Omnibus-Type/Saira . Origem fixada em commit, checksum e licença SIL OFL 1.1 em `mais-uma-rodada/assets/fonts/`. A licença acompanha o APK.

## Simulação e validação

QuickMatch deixa de recontar jogadores ativos a cada minuto: atualiza as contagens em substituições, lesões e expulsões. A seleção tática resolve jogadores e índices dos atributos uma vez por avaliação, preservando a ordem das somas. Tempos por etapa foram adicionados para diagnosticar o restante do avanço de rodada.

- Comparação pareada de 600 partidas: resultados exatamente iguais; 103 cartões vermelhos, 89 prorrogações e 155 lesões. QuickMatch anterior: 1.244.405 µs; novo: 971.251 µs (aproximadamente 22% menos tempo **nesse cálculo**, no PC).
- Esse ganho isolado não demonstra ganho de 22% no lote completo. Lotes de 12 jogos oscilaram entre 7,6 e 9,6 s; a última medição foi 9,583 s, com save confirmado. Preparação de escalações, mercado e fechamento de rodada ainda pesam no total. Não há medição em Android físico.
- Compilação: 362 scripts, 0 erros. Regressão mobile de layout e ciclo de vida: 0 falhas. Revisão visual completa e revisão de tabelas após ajuste de tipografia: 0 falhas.
- Três regressões integradas de partida, conversas/coletiva e caixa de entrada: 0 falhas (95,7 s).
- Duas regressões de táticas, formação personalizada, instruções e estrangeiros: 0 falhas (41,7 s), após a otimização tática.
- Avaliação: alterar CA/PA não altera o relatório; mudar atributos altera; olheiro melhora confiança; posição muda avaliação; cálculo não consome RNG do mundo; persistência mantém os dados internos.
- Revisão nativa em 390×844, 844×390, 800×1280 e 1280×800. Capturas finais em `docs/images/assessments-mobile-0.5.3`. Referência anterior em `docs/images/career-mobile-0.5.2`.

Os harnesses usam diretório de usuário isolado por `override.cfg` e slots de QA; o override e as ferramentas são excluídos do APK. Há avisos de objetos/CanvasItems ainda vivos no encerramento forçado do harness visual, sem falha de execução durante os fluxos. Validação de toque, desempenho e estabilidade em aparelho Android físico continua pendente.

## Reproduzir

Na pasta do projeto, com Godot 4.7.2 e dados de usuário de QA:

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tools/check_scripts.gd
godot --path . --resolution 390x844 --script res://tools/assessment_mobile_review.gd -- --out=CAMINHO_ABSOLUTO
godot --headless --path . --script res://tests/run_tests.gd -- --only=táticas: entrosamento,formação personalizada
```

Para comparar QuickMatch, extraia a versão anterior de `scripts/systems/quick_match.gd` da base da branch, remova apenas `class_name QuickMatch` e execute `tools/quick_parity.gd -- --reference=CAMINHO_ABSOLUTO`.
