---
version: alpha
name: Mais Uma Rodada — Lousa e Giz
description: >
  Sistema visual de um jogo de gestão de futebol. A referência é a sala de futebol de um
  clube profissional: análise de desempenho, lousa tática do treinador, relatório de scout,
  central de operações do clube, grafismo da transmissão e a página de esporte. Fundo de
  ardósia, texto em giz, campo de grama, e a cor do clube só como contexto.
colors:
  canvas: "#15181B"
  surface: "#1C2024"
  surface-raised: "#24292E"
  surface-selected: "#30363C"
  divider: "#343A40"
  chalk: "#F1F0EC"
  text-primary: "#F1F0EC"
  text-secondary: "#A5ABB2"
  text-muted: "#747C85"
  disabled: "#565D65"
  success: "#57976B"
  warning: "#D39B45"
  danger: "#C75B5B"
  info: "#6F93B8"
  pitch: "#2F5A42"
  pitch-stripe: "#2B5440"
  pitch-line: "#F1F0EC8C"
  rating-elite: "#7FB28C"
  rating-good: "#9DB46C"
  rating-fair: "#C4AE5C"
  rating-weak: "#C98A4B"
  rating-poor: "#C75B5B"
  club-accent: DYNAMIC
  club-accent-muted: DYNAMIC
typography:
  display-score:
    fontFamily: Saira Semi Condensed
    fontSize: 60px
    fontWeight: 750
    lineHeight: 1.0
  entity-title:
    fontFamily: Saira Semi Condensed
    fontSize: 44px
    fontWeight: 750
    lineHeight: 1.05
  screen-title:
    fontFamily: Saira Semi Condensed
    fontSize: 36px
    fontWeight: 600
    lineHeight: 1.1
  section:
    fontFamily: Saira Semi Condensed
    fontSize: 28px
    fontWeight: 600
    lineHeight: 1.15
  body-strong:
    fontFamily: Saira
    fontSize: 24px
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: Saira
    fontSize: 24px
    fontWeight: 400
    lineHeight: 1.3
  body-small:
    fontFamily: Saira
    fontSize: 21px
    fontWeight: 400
    lineHeight: 1.3
  metadata:
    fontFamily: Saira
    fontSize: 20px
    fontWeight: 400
    lineHeight: 1.25
  caption:
    fontFamily: Saira
    fontSize: 18px
    fontWeight: 600
    lineHeight: 1.2
  data:
    fontFamily: Saira
    fontSize: 24px
    fontWeight: 400
    fontFeature: "tnum, lnum"
rounded:
  none: 0px
  sm: 6px
  lg: 12px
spacing:
  xs: 6px
  sm: 12px
  md: 18px
  lg: 24px
  xl: 36px
  xxl: 48px
  gutter: 24px
  gutter-dense: 18px
  touch: 72px
components:
  button-primary:
    backgroundColor: "{colors.chalk}"
    textColor: "{colors.canvas}"
    typography: "{typography.section}"
    rounded: "{rounded.sm}"
    height: 72px
  button-secondary:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.sm}"
    height: 72px
  button-text:
    backgroundColor: transparent
    textColor: "{colors.text-primary}"
    typography: "{typography.body-strong}"
  surface-object:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    padding: 18px
  data-row:
    backgroundColor: transparent
    divider: "{colors.divider}"
    height: 84px
    typography: "{typography.data}"
  table-head:
    textColor: "{colors.text-muted}"
    typography: "{typography.caption}"
  nav-item:
    textColor: "{colors.text-muted}"
    activeTextColor: "{colors.text-primary}"
    activeIndicator: "{colors.club-accent}"
    height: 88px
  toast:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    height: 108px
  sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg} {rounded.lg} 0 0"
---

# Mais Uma Rodada — Lousa e Giz

> Leia este arquivo inteiro antes de qualquer trabalho visual ou de UI. É contrato, não
> inspiração. Cor, tamanho, raio ou componente que não esteja aqui não existe até ser
> acrescentado aqui primeiro.

## Unidades

O canvas do Godot tem **600 px de largura em retrato** (1066 deitado; 1100/1500 no tablet).
Todo valor deste arquivo está em **px do canvas**. **1 dp ≈ 1,5 px** num celular de 390–411 dp: alvo de toque de
48 dp = **72 px**; texto de 16 dp = **24 px**. Onde os tokens moram no código:

| Token | Código |
|---|---|
| cores | `scripts/ui/ui_colors.gd` (`D_*`; escala de notas em `scripts/core/fmt.gd`) |
| tipografia, espaçamento, raio, alturas | `scripts/ui/ui_tokens.gd` |
| estilo dos componentes | `tools/build_theme_runner.gd` → `assets/theme/main_theme.tres` |

Depois de mudar tokens, gere o tema de novo:
`godot --headless --path . --script res://tools/build_theme.gd`.

## Overview

**Direção: a sala de futebol de um clube.** Paredes de ardósia, giz na lousa tática, grama
no campo, o papel do relatório de scout e o grafismo da transmissão de domingo. Software de
quem vive futebol. Não é fintech, SaaS, casa de apostas nem painel administrativo.

Palavras: preciso, esportivo, editorial, tátil, denso, maduro, rápido, funcional.
Densidade 8/10 · variação de composição 6/10 · movimento 3/10 · decoração 3/10.

**A ousadia fica num lugar só: giz sobre ardósia.** A ação principal é de giz (botão claro,
texto escuro), não da cor do clube. O campo é o único grande campo de cor do jogo. O resto
fica quieto.

### Três modos, um sistema

| Modo | Telas | Quem domina |
|---|---|---|
| **Gestão** | Elenco, Mercado, contrato, scouting, finanças, comissão, estatísticas | dados: tabela, lista, números alinhados, controles compactos |
| **Futebol** | Tática, escalação, partida, treino, bola parada | o campo: posições, uniformes, placar, diagramas, interação espacial |
| **Editorial** | Início, notícias, caixa de entrada, carreira, eventos, conquistas | a história: manchete, foto, escudo, acontecimento |

Os três dividem tokens e tipografia, mas nunca o mesmo molde de tela. Cada tela nasce do
**objeto que o treinador manipula**:

| Objeto | Componente |
|---|---|
| formação | campo (`PitchView`) |
| elenco | tabela (`DataTable` / `PlayerTable`) |
| contrato | documento / negociação |
| jogo | placar + campo + eventos |
| notícia | manchete (`NewsRow`) |
| clube | identidade + instituição (`IdentityBand`) |

## Colors

Base neutra de ardósia (`canvas`, `surface`, `surface-raised`, `surface-selected`, `divider`)
e texto de giz (`text-primary`) em três níveis (`text-secondary`, `text-muted`).

- **A cor do clube é contexto, não a marca do jogo.** `club-accent` (`UIColors.ACCENT`) pode
  aparecer em: indicador da navegação ativa, sublinhado da aba ativa, bloco de identidade do
  clube, placar, um estado selecionado e detalhes editoriais. **Nunca** em número, valor
  positivo, atributo, físico ou no botão principal.
- **Estados** têm cor própria: `success`, `warning`, `danger`, `info`. Cor nunca sozinha:
  sempre com texto ou valor (`100%`, `Lesionado · 3 sem.`, `+4`).
- **Notas** têm escala própria e moderada, nunca verde néon: `rating-elite` ≥80,
  `rating-good` 70–79, `rating-fair` 60–69, `rating-weak` 50–59, `rating-poor` <50
  (`Fmt.rating_color`).
- **Campo**: grama em duas faixas com linhas de giz. Só existe onde há futebol.
- Existe o modo claro (`UIColors.LIGHT`) com os mesmos papéis; tela não escreve cor solta.

## Typography

Duas larguras da mesma família, com papéis claros:

- **Saira Semi Condensed** (600/750) é o *futebol*: nome de clube, placar, competição, título de
  tela, número grande, partida.
- **Saira** (400/600) é *dado e texto*: tabela, rótulo, filtro, contrato, número pequeno.

Escala (variação do tema entre parênteses): `display-score` 60 (`Score`), `entity-title` 44
(`Title`), `screen-title` 36 (barra superior), `section` 28 (`Section`), `body` /
`body-strong` 24 (padrão / `H3`), `body-small` 21 (`Small`/`Muted`), `metadata` 20,
`caption` 18 (`Caps`, cabeçalho de tabela).

Regras:
- Números de tabela e estatística com algarismos tabulares (`DataTable.tabular_font()`).
- Nada de CAIXA ALTA em rótulo ou seção. Caixa alta só na sigla do placar (`FLA 1 × 0 PAL`).
- No máximo dois pesos por linha. Nada de monoespaçada para parecer "técnico".
- Não emendar metadado com ponto médio (`A · B · C`) como muleta: prefira estrutura (dois
  rótulos, coluna, linha embaixo do nome). Ponto só na 2ª linha de uma linha de lista e em
  metadado de partida, com no máximo dois itens.
- Tablet não aumenta letra: ganha **densidade** (mais colunas, telas divididas).

## Layout

- Margem no celular: `gutter` 24 (contexto denso 18). Separação entre seções: 36–48.
- Escala de espaço: 6, 12, 18, 24, 36, 48. Nada no meio.
- Alvo de toque ≥ 72 px (48 dp). Lista usa a linha inteira como alvo.
- **Retrato**: uma coluna; o objeto da tela vem primeiro.
- **Deitado / tablet**: mestre/detalhe (`UIKit.split`). Elenco: lista | jogador escolhido.
  Tática: campo grande | plano. Clube: identidade + operação | contexto. Nunca celular
  esticado, nunca colunas somadas até o nome sumir.
- O nome do jogador nunca some: na tabela a coluna do nome é fixa e só a área de números
  rola para o lado.
- Área segura: navegação, avisos, folhas e diálogos sempre dentro de `main.safe_margins()`.

## Elevation & Depth

Hierarquia vem de luminância, tipografia, espaço, escala, imagem, posição e divisor.
**Sem brilho, sem vidro, sem sombra decorativa, sem desfoque.**
Elevação de verdade (um degrau de tom; sombra leve só em sobreposição) só quando um objeto
está de fato acima de outro: folha, menu contextual, diálogo, aviso.

## Shapes

Raios: `none` 0 (tabela, linha, barra, campo), `sm` 6 (objeto, botão, campo de texto),
`lg` 12 (só o topo de folhas e diálogos). Chip/pílula só quando é, de fato, filtro ou
estado alternável.

## Components

- **Superfície (objeto)**: `surface`, `rounded.sm`, margem 18. Só para entidade ou
  acontecimento real: próximo jogo, proposta recebida, relatório de scout, conversa, notícia
  de destaque, convocação, alerta da diretoria, cabeçalho de jogador/clube. Métrica pequena
  nunca vira superfície.
- **Linha de dados / DataTable**: sem fundo, `divider` embaixo, altura 84. Cabeçalho
  pequeno que ordena. Coluna do nome fixa. Poucas colunas em retrato, com **visão**
  (Geral · Forma · Temporada · Contrato) que troca as colunas.
- **Cabeçalho de identidade** (`IdentityBand`): bloco na cor principal do clube com corte
  diagonal e faixa na segunda cor, só atrás do escudo ou do retrato. O texto fica sobre a
  superfície neutra.
- **Bloco de jogo** (`MatchHero`): faixa da competição nas cores da transmissão, lados nas
  cores dos clubes, escudos, ação principal de giz.
- **Campo** (`PitchView`): mini camisas, sobrenome, condição discreta. Toque = painel
  rápido, arrastar = trocar, segurar = perfil.
- **Botão principal**: giz. **Secundário**: `surface-raised`. **Texto**: sem fundo.
  Uma ação principal por tela.
- **Navegação**: 5 destinos (Início, Elenco, Tática, Mercado, Clube). O ativo tem rótulo e
  ícone em contraste total e barra na cor do clube; os inativos ficam apagados. Embaixo no
  celular, trilho estreito na lateral em tela larga.
- **Aviso / conquista**: 108 px (~72 dp), abaixo da barra superior, dentro da área segura,
  3,5 s, toque abre. Nunca cobre título e abas por mais que isso.
- **Folha**: `surface`, raio 12 em cima, alça. Nunca modal sobre modal: ação dentro de uma
  folha fecha a folha antes de abrir a próxima coisa.
- **Estados**: padrão, pressionado, selecionado, desativado, foco (contorno de giz de 2 px
  no teclado), carregando, vazio, erro (`UIKit.state_block`). Toque não tem hover: nada se
  descobre só passando o mouse.

## Do's and Don'ts

Fazer:
- Começar cada tela pelo objeto de futebol.
- Mostrar muito dado, bem alinhado.
- Usar escudo, uniforme, bandeira, retrato e campo como presença do jogo.
- Escrever futebol: "Três titulares abaixo de 80% de condição."

Não fazer:
- Card para métrica pequena, bento, painel de KPIs, sparkline decorativa.
- Tudo em tabela **ou** tudo em card: o componente segue o objeto.
- Preto + verde ácido como assinatura global; cor do clube pintando a tela inteira.
- Brilho, vidro, desfoque, sombra pesada, raio alto em tudo, pílula como enfeite.
- 10 colunas no celular; esconder o jogador para mostrar estatística.
- Gráfico sem decisão associada; métrica inventada.
- Rótulo em CAIXA ALTA, sobretítulo em cima de todo título, monoespaçada em rótulo, `→` em
  botão.
- Menu lateral gigante, cara de app de apostas, celular esticado no tablet.

## Verificação visual (obrigatória)

Depois de cada tela: rodar o jogo e capturar 390×844, 844×390, 800×1280 e 1280×800
(`tools/design_shots.gd`). Responder: videogame ou app administrativo? Futebol, de forma
específica? O objeto principal é óbvio? Hierarquia em 2 s? Excesso de divisor ou de
superfície? Colisão? Ação comum escondida? Parece molde de IA? Esta composição poderia
existir numa fintech? Se uma das duas últimas for "sim", refazer.

## Estados de seleção (0.5.3)

Linhas selecionadas usam `surface-selected` em toda a largura, atrás do conteúdo, sem filete lateral. Pressionar uma linha não altera sua escala nem seus recuos. Foco por teclado mantém o contorno de giz. A avaliação de atletas usa estrelas douradas (`UIColors.GOLD`), com a parte incerta em texto secundário; CA/PA só aparecem mediante revelação explícita no editor.

## Tipografia 0.5.3

Saira substitui a família anterior em toda a interface. Fonte variável original da Omnibus-Type, sob SIL OFL 1.1: largura 100/pesos 400 e 600 para leitura; largura 87,5/pesos 600 e 750 para títulos e placares. A inspiração é a clareza e o desenho angular das interfaces de futebol; não é a fonte proprietária do EA FC. Entrelinha compacta no tema (`spacing_top = -2`, `spacing_bottom = -3`), sem comprimir os glifos. Preservar acentos portugueses, algarismos tabulares e áreas de toque ao ajustar quebras de linha. Origem e licença em `assets/fonts/SOURCE-Saira.txt` e `OFL-Saira.txt`.
