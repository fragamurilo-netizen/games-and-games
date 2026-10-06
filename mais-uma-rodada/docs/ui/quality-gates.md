# UI 2.0: situação dos quality gates

Referência: `DESIGN.md` ("Lousa e Giz"). Capturas feitas com
`tools/design_shots.gd` em 390×844, 844×390, 800×1280 e 1280×800 (com `--ugly`: nomes enormes,
clube de nome comprido, lesão, suspensão, folha estourada).

| Gate | Situação |
|---|---|
| DESIGN.md criado | feito |
| CLAUDE.md aponta para DESIGN.md | feito (também `.claude/skills/godot-ui/SKILL.md`) |
| Tema central | feito: tokens em `ui_tokens.gd`/`ui_colors.gd`, tema gerado por `tools/build_theme_runner.gd` |
| Início | feito: data como manchete, dia de jogo nas cores dos clubes, pendências, mundo do futebol |
| Elenco | feito: tabela com visões (Geral, Forma, Temporada, Contrato), nome fixo, rosto; mestre/detalhe deitado; mais colunas no tablet em pé |
| Perfil | feito: cabeçalho com identidade do clube, ações no cabeçalho (sem rodapé fixo), faixa de números na Visão |
| Tática | feito: abre no campo com mini camisas, banco como faixa de camisas, plano de jogo em folhas; campo deitado no celular deitado |
| Clube | feito: começa pela instituição (escudo, cores, temporada, uniformes), áreas agrupadas com informação viva |
| Aviso de conquista | feito: ~96 px, abaixo da barra superior, 3,5 s |
| Retrato / deitado / tablet | capturados e revisados |
| Colisões conhecidas | resolvidas: coluna Moral cortada, nomes longos no campo, pílulas/caixa alta no jogo |
| Ações comuns | escalação: 1 toque (Tática); perfil: 1 toque; negociar contrato: 2 toques |

## Decisões registradas

- Canvas do celular passou de 720 para **600** de largura: com 720, o texto base dava ~13 dp e
  os alvos de toque ~39 dp num aparelho de 390 dp. Com 600, 1 dp ≈ 1,5 px (texto 16 dp, toque
  48 dp). Modais com largura mínima fixa são limitados à tela (`UIManager._clamp_width`).
- Botão principal é de **giz**, não da cor do clube. A cor do clube fica para identidade,
  seleção e indicadores.
- Clube de camisa clara usa a segunda cor no bloco de identidade.

## Telas já recompostas depois dos gates

- **Mercado**: abas Buscar, Lista, Olheiros, Vendas, Histórico; Livres, Fim de contrato e
  Moneyball como modos da busca; tabela com poucas colunas no celular; deitado, o jogador ao
  lado com "Fazer proposta" e "Acompanhar"; estados vazios que dizem o que fazer.
- **Partida**: campo vertical e grande no celular em pé; barra com Tática, Instruções e
  Substituir em destaque (Pausar, velocidade e "Mais" compactos); substituição em dois toques
  (quem sai, quem entra); painel de números numa folha (Mais › Painel da partida).
  Captura das folhas: `tools/match_shots.gd -- --sheets=1`.
- **Base**: abas Garotos, Torneios, Jogos, Estrutura, Captação; cabeçalho em frase; garotos por
  categoria na mesma tabela do elenco (Geral, Potencial em estrelas, Idade; mais colunas no
  tablet), duas categorias lado a lado deitado; "Revelados pela base" como atalho.

- **Treino**: resumo em frase; plano da semana em linhas que abrem folhas (cada opção com o
  efeito); efeito da semana em faixa de números; jogadores na tabela do elenco com a coluna do
  treino individual.
- **Finanças e diretoria**: caixa, temporada e patrocínios em blocos separados; diretoria,
  torcida e diretor de futebol em faixa de números; ultimato em texto, não em pílula.
- **Notícias**: país do portal num botão com bandeira (folha), não numa segunda fila de abas.
- **Caixa de entrada**: contadores viraram frase (as contagens seguem nas abas).
- **Seleções**: cabeçalho enxuto; convocação na tabela de jogadores (clube no lugar da
  situação, jogos e gols pela seleção); marcadores em texto.
- **Histórico**: desfecho (campeão, acesso, queda) em texto de cor; carreira em faixa de números.
- **Competições**: celular em pé mostra J, SG e PTS, e o nome do clube cabe inteiro; o resto
  das colunas volta deitado e no tablet.
- **Relações**: a grade de cartões-medidor virou faixa de números (vestiário, diretoria,
  torcida, imprensa) com abas comuns embaixo.
- **Olheiros** (Mercado): missão em linhas que abrem folhas; relatórios na tabela do mercado,
  jogador ao lado na tela larga e em folha no celular (com "Descartar relatório").
- **Folha de treino individual**: resumo com carga, foco, estilo e posição em linhas; cada uma
  abre a lista de opções dentro da própria folha, com volta. Sem grades de chips.
- **Foco de teclado**: botões, chips, abas e linhas tocáveis aceitam foco; o contorno é azul
  (info), 3 px, afastado 4 px (giz sumiria no botão principal). Toque e clique soltam o foco
  (`main.gd`), então o contorno só aparece navegando por teclado ou controle.
- **0.5.4 (sobre o trabalho do Codex 0.5.1–0.5.3)**: toque mais confiável (limiar de
  arrasto 18/28 px, apertar sem varrer a árvore, sem "hover" preso no toque, folhas não
  rolam sob o dedo); abas proporcionais ao texto; cortes da Saira no Elenco e no Mercado;
  moral máxima "Ótima"; faixa do clube longe do nome (perfil, resumo, clube); data do
  Início quebra em duas linhas no celular deitado. Medição: `design_shots -- --only=!taps`
  (TAP_JITTER=px) em 390×844 — 89/92 toques com tremor de 14 px (os 3 restantes são abas
  cortadas na borda de faixas roláveis), arrasto rola sem disparar botão.

## Pendente

- `tools/match_shots.gd` termina com erros de script ao fechar ("lock" em nulo, "main" liberado):
  a ferramenta sai enquanto a rodada ainda fecha na thread. Já acontecia antes da UI 2.0; a
  captura "fim" sai preta pelo mesmo motivo.
