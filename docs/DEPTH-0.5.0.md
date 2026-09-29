# Mais Uma Rodada 0.5.0: profundidade, seleções e base

## Base e segurança

Parte de `d34f194d10652be10e33b48c64090a1ec8176acf`: versão 0.4.0 original do usuário (`0721da80a98148912aa954101185cf6531633e5b`) mais as correções de desempenho/paisagem do PR #54, ainda não incorporadas à branch de origem. As opções experimentais de iluminação não foram integradas. Sem merge automático e sem sobrescrever releases.

A configuração de produção permanece `com.maisumarodada.futebol`. A compilação de avaliação é um aplicativo separado, `com.maisumarodada.futebol.depthtest`, versão 0.5.0, código 13. Não desinstalar o jogo original: a assinatura debug do CI é diferente e os dados do aplicativo de teste são independentes. A carreira original não é importada automaticamente.

## Alterações efetivas

### Partidas e adversários

- Remove a inflação oculta de força do adversário do usuário. Dificuldade altera a frequência e probabilidade das decisões do técnico adversário, não atributos ou força do dia.
- Remove equalizadores de placar: estar perdendo não aumenta automaticamente as chances, e vencer não reduz artificialmente a eficiência. Perder tempo ou mudar a postura continua possível por instruções explícitas.
- Confrontos táticos simétricos e limitados: velocidade contra linha alta, técnica/decisão contra pressão, preparação física, desgaste, jogo aéreo, blocos e transições. Não há uma tática que garanta vencer.
- O treinador adversário observa estatísticas já produzidas, condição e características dos times e pode mudar pressão, linha, amplitude, passe e mentalidade. A decisão e seu motivo ficam registrados. Substituições e ajustes anteriores foram preservados.
- O motor de partidas em lote também recebe descritores do elenco e perde os equalizadores de placar. Corrige colisões do cache quando o índice de estilo passa de 9. Esse motor continua sendo uma aproximação mais leve, não uma réplica minuto a minuto da IA nativa.

### Sete estilos coletivos adicionais (13 no total)

Jogo de posição; gegenpressing; bloco médio e transição; contra-ataque pelos lados; jogo de apoio e segunda bola; posse vertical; ataque relacional. Coeficientes incluem compromissos entre criação, qualidade, posse e desgaste; o elenco e o adversário importam. Identificadores antigos foram mantidos.

### Dezesseis playstyles individuais adicionais

Goleiro de apoio e lançador; zagueiro de cobertura lateral e quebra-linhas; lateral de associação e de linha de fundo; volante de cobertura e resistente à pressão; meia de terceiro homem e inversor de jogo; meia entrelinhas; ponta de pausa e de segundo poste; atacante pressionante, de apoio e do último defensor. São opções adicionais por função, com modificadores limitados e contrapartidas, não atributos super-humanos.

### Talento, atributos e mercado

- Jogadores novos combinam perfis atléticos, técnicos e de leitura do jogo, em vez de depender apenas de ruído independente em cada atributo.
- Parte dos jovens amadurece cedo e tem menor margem de crescimento. Potencial não significa crescimento garantido; lesões, condição, profissionalismo e minutos influenciam o desenvolvimento.
- A nova projeção de evolução e o valor de mercado não leem o teto oculto de potencial. Usam o que já é observável, com faixa de incerteza. Lesões prolongadas reduzem a avaliação; goleiros têm curva etária própria.
- Jogadores de saves existentes não são sorteados novamente. Os valores continuam estimativas internas do jogo, não cotações oficiais nem calibração contra uma base completa do Transfermarkt.

### Seleções

- Em **Seleções > Comando**, permite acumular clube e seleção. A federação exige reputação; há confiança, resultados, saída voluntária e possibilidade de demissão.
- Convocação editável de 26 jogadores com três goleiros, cobertura de posições, titulares preferidos e plano tático próprio. Forma e condição entram na seleção automática. Convocações anunciadas são preservadas; indisponíveis recebem reposição.
- Partidas da seleção comandada usam `MatchSimulation`, incluindo prorrogação, pênaltis e xG, sem creditar jogos/gols da seleção ao clube. As demais seleções usam o modelo leve com influência do plano e das características do elenco.
- **O comando de seleções é por convocação e preparação tática. Ainda não inclui transmissão jogável minuto a minuto, gritos ou substituições manuais durante cada partida internacional.**
- Datas masculinas FIFA de 2026 a 2030 e teto por janela de 2 ou 4 jogos no processamento normal. Janelas anunciadas são inseridas no calendário gerado e as rodadas de clubes são deslocadas para fora delas. Após 2030, as datas são projeções explicitamente identificadas.
- Notícias de convocação, reposições e preparação para a Copa; histórico de resultados e três uniformes autorais por seleção (titular, reserva e goleiro), inspirados nas cores nacionais. Não são uniformes licenciados de uma temporada real.
- As eliminatórias e formatos de torneio já existentes foram mantidos. O calendário global de temporadas continua adaptado; o acerto legado de eliminatórias pendentes no encerramento da temporada e o processamento agregado dos torneios de verão não foram substituídos por um calendário internacional completo dia a dia. As datas de fase final das próximas Copas não são apresentadas como oficiais quando ainda não definidas. Calendários de saves antigos não são remapeados retroativamente: a reserva de novas janelas vale para calendários gerados daqui em diante.

### Categorias de base

Três formatos autorais adicionais: Regional sub-15 (8 clubes, 14 rodadas), Copa Nacional sub-20 (16 clubes, mata-mata) e Copa Continental de Desenvolvimento sub-19 (8 clubes, mata-mata). Incluem calendário, classificação ou chaveamento, resultados, campeões, arquivo e minutos dos atletas da academia.

A elegibilidade considera idade; há controle para evitar a utilização do mesmo atleta em jogos sobrepostos e um intervalo mínimo no agendamento de suas participações. Oponentes são avaliados de forma agregada, com reposição anônima quando falta profundidade: ainda não são academias completas de todos os clubes com todos os jogadores individualmente simulados. Entradas nesses torneios são regras do jogo, não reprodução de todos os regulamentos de federações.

## Validação e limites

Godot 4.7.stable.official.5b4e0cb0f. `tests/depth_bootstrap.gd` carrega a suíte depois dos autoloads. Ela verifica compilação de todos os scripts; simetria tática; desgaste; suporte aos estilos; geração de atributos; projeção sem acesso ao potencial oculto; calendário e partidas agendadas; convocação, reposição e partidas internacionais; três competições de base; serialização em memória; e presença dos novos controles na interface.

Amostras: 160 partidas nativas entre dois clubes brasileiros com estilos variados; 260 partidas do motor em lote entre ligas; 20 pares de partidas nativas em modo detalhado/não detalhado, verificando mesmo resultado e estado do RNG para cada semente. Os limites de gols usados são checagens amplas de sanidade, não prova de fidelidade estatística ao futebol real. Os números finais estão no artefato `depth-validation.json` e são amostras deste mundo de teste, não estatísticas reais.

Também é executada `tests/mobile_regression.gd`, que preserva as verificações anteriores de orientação e ciclo de vida. Essa suíte ainda registra aviso de dois objetos retidos ao sair. Testes são headless: não houve teste físico em Android, medição de ganho de FPS, leitura visual das telas, campanha de vários anos nem migração de um save real do usuário. A serialização testada é um roundtrip em memória.

## Reproduzir

```sh
godot --headless --path mais-uma-rodada --import
DEPTH_REPORT=/tmp/depth-validation.json godot --headless --path mais-uma-rodada --script res://tests/depth_bootstrap.gd
godot --headless --path mais-uma-rodada --script res://tests/mobile_regression.gd
```

Qualquer `SCRIPT ERROR`, `Parse Error`, `DEPTH_FAIL` ou `MOBILE_FAIL` bloqueia a exportação no workflow de avaliação. Um marcador de sucesso isolado não basta.

## Referência de calendário

FIFA, Men's International Match Calendar 2023–2030, edição de abril de 2026:
https://digitalhub.fifa.com/m/3123d37097318f7f/original/Men-s-International-Match-Calendar-2023-2030_EN.pdf

O prazo de anúncio adotado pelo jogo é uma regra de design, não um prazo universal imposto pela FIFA. Sem alegação de licenciamento de nomes, logos ou uniformes.
