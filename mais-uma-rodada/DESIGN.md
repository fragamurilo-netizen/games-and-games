---
version: alpha
name: Mais Uma Rodada — Dia de jogo
description: >
  Sistema visual de um jogo de gestão de futebol. A referência é o dia de jogo: o gramado à
  noite sob o refletor, as linhas de cal, as cores do clube na camisa e na arquibancada, o
  cartão amarelo e o vermelho, e o grafismo da transmissão. Fundo de noite de estádio, texto de
  cal, grama de verdade na barra superior e no bloco do jogo, e a cor do clube marcando o que é seu.
colors:
  canvas: "#0E1318"
  surface: "#161D24"
  surface-raised: "#1F2831"
  surface-selected: "#2C3744"
  divider: "#35414E"
  chalk: "#F4F2EA"
  text-primary: "#F4F2EA"
  text-secondary: "#AAB2BC"
  text-muted: "#8892A0"
  disabled: "#565D65"
  success: "#3DBE7A"
  warning: "#F0A33A"
  danger: "#E5484D"
  info: "#4EA8DE"
  pitch: "#2A7A45"
  pitch-stripe: "#246D3D"
  pitch-line: "#F4F2EACC"
  rating-elite: "#3DBE7A"
  rating-good: "#9BCB4B"
  rating-fair: "#F2C230"
  rating-weak: "#F08A3C"
  rating-poor: "#E5484D"
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
    activeIndicator: "tarja inclinada em {colors.club-accent} atrás do ícone"
    height: 88px
  top-bar:
    backgroundColor: "{colors.pitch} em faixas com {colors.pitch-stripe}, escurecido 34%"
    textColor: "{colors.chalk}"
  control-selected:
    backgroundColor: "{colors.club-accent}"
    textColor: "a cor que lê sobre o destaque (quase preto ou branco)"
  toast:
    backgroundColor: "{colors.surface-raised}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.sm}"
    height: 108px
  sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg} {rounded.lg} 0 0"
---

# Mais Uma Rodada — Dia de jogo

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

**Direção: dia de jogo.** Noite de estádio, grama cortada em faixas sob o refletor, linha de
cal, a camisa e a bandeira nas cores do clube, cartão amarelo e vermelho, e o grafismo da
transmissão. A tela tem de parecer futebol antes de alguém ler uma palavra. Não é fintech,
SaaS, casa de apostas nem painel administrativo, e não é um painel escuro genérico com um
destaque colorido.

Palavras: futebol, vivo, direto, tátil, denso, rápido, do clube.
Densidade 8/10 · variação de composição 6/10 · movimento 3/10 · decoração 5/10.

**De onde vem a cara de futebol (e só daqui):**

1. **O gramado.** Grama de verdade (faixas de corte e marcações de cal, `Grass`) na barra
   superior de toda tela, no bloco do próximo jogo e nos campos. O escudo do clube fica no
   círculo central da barra. Texto sobre a grama é sempre de cal, no escuro e no claro.
2. **A cor do clube.** Tinge o fundo, veste os ícones dos ladrilhos, o friso de cada título de
   seção, a tarja da aba ativa e o controle selecionado. Trocar de clube troca a cara do jogo.
3. **As cores que o futebol já usa para dizer as coisas.** Verde de vitória, amarelo de cartão,
   vermelho de cartão, vivos como num placar. Nada de tons lavados "de bom gosto".
4. **O grafismo de TV.** Tarjas inclinadas (aba ativa, friso) e os pacotes de transmissão.

A ação principal continua de cal (botão claro, texto escuro), não da cor do clube.

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

Base de noite de estádio (`canvas`, `surface`, `surface-raised`, `surface-selected`, `divider`),
tingida com a cor do clube, e texto de cal (`text-primary`) em três níveis (`text-secondary`,
`text-muted`).

- **A cor do clube marca o que é seu.** `club-accent` (`UIColors.ACCENT`) aparece em: tarja da
  navegação ativa, sublinhado da aba ativa, controle selecionado (segmento e chip), ícone dos
  ladrilhos de destino, friso dos títulos de seção, bloco de identidade do clube, placar e
  detalhes editoriais. **Nunca** em número, valor positivo, atributo, físico ou no botão
  principal (que é de cal).
- **Estados** têm as cores do placar e do árbitro: `success` (vitória), `warning` (cartão
  amarelo), `danger` (cartão vermelho), `info`. Vivas, não lavadas. Cor nunca sozinha:
  sempre com texto ou valor (`100%`, `Lesionado · 3 sem.`, `+4`).
- **Notas** têm escala própria de placar (verde, limão, amarelo, laranja, vermelho): `rating-elite` ≥80,
  `rating-good` 70–79, `rating-fair` 60–69, `rating-weak` 50–59, `rating-poor` <50
  (`Fmt.rating_color`).
- **Gramado** (`pitch`, `pitch-stripe`, `pitch-line`): grama em faixas de corte com linhas de
  cal. Vive nos campos (tática, partida), na barra superior e no bloco do próximo jogo; nesses
  dois últimos escurece ~35% para o texto de cal ler por cima. Não vira fundo de lista, de
  tabela nem de cartão comum.
- Existe o modo claro (`UIColors.LIGHT`) com os mesmos papéis; tela não escreve cor solta.

Todas as 218 seleções usam a arte SVG em `assets/flags/` (flag-icons, licença MIT
preservada junto dos arquivos e mapeamento FIFA/ISO em `index.json`). O desenho
procedural fica apenas como compatibilidade para dados de mods. A arte mantém sua proporção
dentro do espaço 3:2 do `FlagView`, sem esticar ou cortar brasões. Cores de bandeira
pertencem à identidade do país, como as cores do clube e da transmissão.

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

- **Gramado** (`Grass`): desenha as faixas de corte e as marcações de cal para quem está "no
  campo". Barra superior (`TopBar`): grama de ponta a ponta, subindo por trás do entalhe; o
  escudo fica dentro do círculo central, com a linha do meio passando por ele; na base, a faixa
  nas duas cores do clube. Bloco do próximo jogo (`MatchHero` com `pitch`): o campo visto de
  cima, o "×" na marca do meio-campo, a cor de cada clube nascendo da sua borda como um véu.
  Sobre a grama todo texto é de cal (`MatchHero.chalk_text`), também no modo claro.
- **Friso do clube** (`UIKit.trim_mark`, dentro de `UIKit.section_header`): duas barras
  inclinadas, a cor de destaque e a outra cor do clube, como o friso de uma manga. Abre os
  títulos de seção das telas (não os títulos dentro de cartões).
- **Controle selecionado** (`SegmentButton`, `ChipButton`): o escolhido veste a cor do clube,
  com o texto na cor que lê por cima dela. Os outros ficam apagados.
  Segmento com cinco opções ou mais (`SegmentButtonDense`, escolhido sozinho pelo
  `UIKit.segment`): mesma peça na condensada, com a largura de cada opção seguindo o texto,
  para caber no celular sem cortar palavra.
- **Ícones** (`assets/icons/`): sólidos, 24 px de desenho. Para coisa de futebol, objeto de
  futebol: cone (treino), chuteira (base), apito (comissão), trave (estatísticas), bandeira
  (torcida), estádio (história), pódio (ranking), campo (tática). Ícone genérico só para ação
  genérica (buscar, salvar, fechar).
- **Superfície (objeto)**: `surface`, `rounded.sm`, margem 18. Só para entidade ou
  acontecimento real: próximo jogo, proposta recebida, relatório de scout, conversa, notícia
  de destaque, convocação, alerta da diretoria, cabeçalho de jogador/clube. Métrica pequena
  nunca vira superfície.
- **Linha de dados / DataTable**: sem fundo, `divider` embaixo, altura 84. Cabeçalho
  pequeno que ordena. Coluna do nome fixa. Poucas colunas em retrato, com **visão**
  (Geral · Forma · Temporada · Contrato) que troca as colunas.
- **Faixa de números** (`StatStrip`): a tela abre com números, não com uma frase. Valor em
  cima, rótulo embaixo, filete entre eles, direto no fundo (nunca um card por métrica). Quando
  o número tem teto (folha contra o limite, vagas, elenco), uma barra fina embaixo do rótulo
  mostra o quanto já foi usado: verde, laranja perto do teto, vermelha estourada
  (`StatStrip.load_color`). No máximo quatro valores. Frase só aparece quando algo estourou.
- **Ladrilho de destino** (`UIKit.link_tile` em `UIKit.link_grid`): ícone na cor do clube, nome e, embaixo, a
  informação viva do lugar ("20 garotos", "2º, 14 pontos"). `surface-raised`, raio `sm`, altura
  de linha (84). Duas colunas no celular, três ou quatro em tela larga. Usado no menu ☰ e nas
  áreas do Clube no lugar das listas de texto com seta.
- **Resposta ao toque**: apertar encolhe o alvo (`UIKit.press_fx`); a ação principal e a troca
  de aba vibram de leve (8–12 ms, respeitando Opções › vibração). Nada além disso vibra.
- **Cabeçalho de identidade** (`IdentityBand` → `ClubGradient`): degradê na cor do clube, funda
  atrás do escudo ou do retrato e sumindo na superfície antes do texto, com uma luz fraca da
  segunda cor no canto oposto e pontilhado fino (sem degraus). Cor clara demais (branco, amarelo)
  escurece para a cal continuar legível. **Sem faixas diagonais.** No perfil do jogador o
  recorte sai do degradê, encostado na base, como no FM.
- **Retrato** (`UIKit.portrait`, `CoachScreen.portrait`): quadrado do tamanho pedido, que nunca
  estica com a linha. A cabeça fica sempre na mesma altura e escala, com os olhos a 47% do quadro.
  E sempre tem chão: o busto encosta na base de um quadro de foto de ficha, sem raio. Até 64 px
  (linhas de lista) o quadro é `surface-raised` liso. Acima disso (cabeçalho, documento, comparação),
  o degradê do clube nasce atrás da cabeça e some para a base. Busto recortado solto, com o corte
  reto dos ombros flutuando, não existe. A exceção é o campo da seleção da rodada, onde a faixa do
  nome é o chão. Tamanhos: 56 nas linhas, 72 em diálogo de conversa, 104 no documento de contrato,
  118–132 em cabeçalho e comparação.
- **Bloco de jogo** (`MatchHero`): faixa da competição nas cores da transmissão; o corpo é o
  gramado no bloco do próximo jogo (ver Gramado) e, nos confrontos e comparações, o degradê duplo
  sobre a superfície (mandante nasce na borda esquerda, visitante na direita, escuro no meio onde
  fica o texto). Escudos, ação principal de cal.
- **Grafismo de TV** (`TvPackage` → `TvGraphics`, mostrado pela `TvLayer` na partida): cada
  competição tem o pacote da sua transmissão (Premier, EFL, FA Cup, LaLiga, Serie A, Bundesliga,
  Ligue 1, Liga Portugal, Eredivisie, Süper Lig, Brasileirão, Liga Profesional, MLS, J.League,
  Champions, Liga Europa, Conference, Libertadores, Sul-Americana, Mundial; as outras herdam o do
  país ou um genérico nas cores do placar). Paleta, cantos, inclinação e a palavra do gol na língua
  da TV ("GOAL", "GOL", "TOR", "BUT", "GOLO") vêm dos dados do pacote, não da paleta da interface: é
  a única exceção às cores e à caixa alta, e só dentro das peças de TV (placar `pacote`, faixa do
  gol, tarja do goleador com recorte, números com barra dividida, tabela ao vivo, substituição,
  cartão, informação do jogo, outro jogo, melhor em campo, titulares por setor). Pacote "papel"
  (Bundesliga, LaLiga, Brasileirão, Eredivisie, FA Cup): peças brancas com texto escuro. A cor do
  clube entra pelo `ClubGradient`. Sem brilho nem sombra. Uma peça por lugar (embaixo, meio, alto),
  some sozinha e some ao toque; o jogo não para por elas (só a faixa do gol segura a partida).
  Opções › Partidas: desligado, só os gols ou completo.
- **Melhores momentos** (velocidade `Momentos`, no pré-jogo, nas opções e no botão de ritmo da
  partida): o jogo corre no ritmo do Turbo e desce sozinho para o ritmo Rápido, com o lance
  encenado no campo, quando o minuto tem perigo (gol, bola na trave, pênalti, expulsão, VAR,
  chance clara). No lugar de "ao vivo", o selo da transmissão diz "MELHORES MOMENTOS" em
  `warning`. Nada de tela de transição entre um lance e outro: quem avisa é o relógio.
- **Mapa da partida** (`MatchMapView`, com dados de `MatchMaps`; no intervalo, na aba de números
  e no resumo final): um cartão "Mapa do jogo" com seletor (Finalizações, calor de cada time)
  sobre o campo deitado, no mesmo gramado do resto (`Grass`). O mandante ataca para a direita.
  Finalização: ponto na cor do time (time verde ou muito escuro clareia para não sumir na
  grama), tamanho pela qualidade da chance; gol é um alvo (miolo, aro grosso de contraste, aro
  fino), no gol é ponto cheio, para fora, na trave ou bloqueada é só o aro. Calor: amarelo, laranja,
  vermelho (as cores do placar), nunca azul nem arco-íris. A legenda fica embaixo do campo, uma
  linha só.
- **Acontecendo agora** (`LiveTicker`, no Início): o noticiário do mundo passando sozinho, uma
  manchete por vez (escudo de quem está na notícia, chapéu da editoria, título em até duas linhas)
  e uma barra fina na cor do clube marcando a próxima. Tocar abre a matéria. Para fora da tela.
- **Revelação da rodada** (Resultados): na primeira vez, os cartões entram em sequência (só
  opacidade, ~0,1 s entre eles) e, se o seu time mudou de posição, uma faixa na cor do clube
  desliza da linha antiga até a nova quando a tabela aparece. Animações reduzidas: nada disso.
- **Campo** (`PitchView`): mini camisas, sobrenome, condição discreta. Toque = painel
  rápido, arrastar = trocar, segurar = perfil.
- **Botão principal**: cal. **Secundário**: `surface-raised`. **Texto**: sem fundo.
  Uma ação principal por tela.
- **Navegação**: 5 destinos (Início, Elenco, Tática, Mercado, Clube). O ativo tem uma tarja
  inclinada na cor do clube atrás do ícone e o rótulo de cal; os inativos ficam apagados. Embaixo no
  celular, trilho estreito na lateral em tela larga.
- **Aviso / conquista**: 108 px (~72 dp), abaixo da barra superior, dentro da área segura,
  3,5 s, toque abre. Nunca cobre título e abas por mais que isso.
- **Folha**: `surface`, raio 12 em cima, alça. Nunca modal sobre modal: ação dentro de uma
  folha fecha a folha antes de abrir a próxima coisa.
- **Estados**: padrão, pressionado, selecionado, desativado, foco (contorno de cal de 2 px
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
- Preto + verde ácido como assinatura global; cor do clube em botão principal ou em número.
- Estados e notas em tons lavados (sálvia, ocre, tijolo): placar é cor viva.
- Grama como fundo de lista, tabela ou cartão comum; texto escuro em cima da grama.
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

Linhas selecionadas usam `surface-selected` em toda a largura, atrás do conteúdo, sem filete lateral. Pressionar uma linha não altera sua escala nem seus recuos. Foco por teclado mantém o contorno de cal. A avaliação de atletas usa estrelas douradas (`UIColors.GOLD`), com a parte incerta em texto secundário; CA/PA só aparecem mediante revelação explícita no editor.

## Tipografia 0.5.3

Saira substitui a família anterior em toda a interface. Fonte variável original da Omnibus-Type, sob SIL OFL 1.1: largura 100/pesos 400 e 600 para leitura; largura 87,5/pesos 600 e 750 para títulos e placares. A inspiração é a clareza e o desenho angular das interfaces de futebol; não é a fonte proprietária do EA FC. Entrelinha compacta no tema (`spacing_top = -2`, `spacing_bottom = -3`), sem comprimir os glifos. Preservar acentos portugueses, algarismos tabulares e áreas de toque ao ajustar quebras de linha. Origem e licença em `assets/fonts/SOURCE-Saira.txt` e `OFL-Saira.txt`.
