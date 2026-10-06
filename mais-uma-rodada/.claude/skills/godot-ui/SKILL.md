---
name: godot-ui
description: Como implementar interface no Mais Uma Rodada em Godot 4 (Controls, tema, tokens, responsividade, área segura, capturas). Use em qualquer mudança de tela, componente ou tema, junto com DESIGN.md.
---

# Godot UI — Mais Uma Rodada

Leia `DESIGN.md` antes. Este skill diz **como** fazer em Godot o que o DESIGN.md decide.

## Onde as coisas moram

- Tokens: `scripts/ui/ui_tokens.gd` (tamanhos, espaço, raio, alturas) e
  `scripts/ui/ui_colors.gd` (paleta; `D_*` é a escura gravada no tema).
- Tema: gerado por `tools/build_theme_runner.gd` → `assets/theme/main_theme.tres`.
  Rode `godot --headless --path . --script res://tools/build_theme.gd` depois de mudar.
  O tema usa só cores da paleta (o modo claro e a cor do clube são repintados em tempo de
  execução comparando as cores originais; cor solta no tema não muda de modo).
- Casca: `scripts/ui/main.gd` (barra superior, navegação, área segura),
  `scripts/autoload/ui_manager.gd` (uma pilha por área: `goto`, `push`, `switch_area`,
  `back`; modais, folhas, `popover`, `toast`).
- Kit: `scripts/ui/ui_kit.gd` (UIKit), `scripts/ui/kit/` (DataTable, PlayerTable),
  `scripts/ui/components/` (PitchView, IdentityBand, MatchHero, NewsRow, retratos, escudos).
- Tela: `scripts/ui/screens/*_screen.gd` herda `BaseScreen`; conteúdo em `content()`,
  rodapé em `footer()`, rolagem em `scroll()`. `refresh()` reconstrói a partir do mundo.

## Regras

1. Containers nativos (VBox/HBox/Grid/Margin/Scroll/SplitContainer) com size flags.
   Posição manual só em campo, partida e visualização espacial (desenho em `_draw`).
2. Estilo vem de `theme_type_variation`. `add_theme_*_override` só para exceção pontual;
   exceção que se repete vira variação no tema.
3. Nada de cor literal em tela: use `UIColors.*` (e `Fmt.rating_color` para notas).
4. Tamanho de fonte pelas variações (`Title`, `Section`, `H3`, `Small`, `Caps`...). Número de
   tabela: `DataTable.tabular_font()`.
5. Alvo de toque ≥ 72 px no canvas. Linha de lista inteira clicável (`UIKit.tap_row`).
6. Largura decide o layout, não o aparelho: `content_width()`, `UILayout.is_wide()`,
   `UILayout.is_landscape()`. Mestre/detalhe com `UIKit.split(...)`.
7. Nenhum `Label` com texto crítico sem `text_overrun_behavior` ou quebra de linha; nome de
   jogador tem de ser recuperável (tooltip/perfil).
8. Área segura: sobreposições (aviso, folha, diálogo) usam `UIManager.main.safe_margins()`.
9. Folha nunca abre folha: feche (`UIManager.close_modal()`) antes de abrir a próxima.
10. Estados: pressionado/selecionado/desativado/foco no tema; vazio/erro/carregando com
    `UIKit.state_block(kind, ...)`.

## Verificar

```
godot --headless --script res://tools/check_scripts.gd            # "com erro: 0"
for r in 390x844 844x390 800x1280 1280x800; do
  xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution $r \
    --script res://tools/design_shots.gd -- --out=/tmp/shots/$r --only=hub,squad,player,tactics,club
done
```
Olhe cada captura (Read na imagem) e responda o checklist do fim do DESIGN.md.
