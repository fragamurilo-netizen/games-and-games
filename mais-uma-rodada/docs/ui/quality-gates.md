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

## Pendente

- Foco visível por teclado nos botões (hoje só nos campos de texto): o Godot não separa foco
  de toque e de teclado; precisa de um controle no `main.gd`.
- Mercado, Partida, Base, Treino, Finanças, Diretoria, Notícias, Conversas, Seleções,
  Competições e Histórico ainda usam o sistema, mas não foram recompostos (fase seguinte).
