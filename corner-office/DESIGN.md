# DESIGN.md — Sistema visual

Resumo operacional de Game Design Bible §15, §16 e §24. Implementado em `game/ui/theme/tokens.gd`.

## Personalidade

| Queremos | Evitar |
|---|---|
| Brutalismo editorial controlado | Neon / cyberpunk |
| Tipografia forte e condensada | Glassmorphism |
| Preto, carvão, off-white e vermelho queimado | Gradiente roxo/azul |
| Fotografia recortada e textura sutil | Cards SaaS repetitivos |
| Tabelas e scoreboards esportivos | Bento grid |
| Acento metálico/dourado raro | Dourado "luxo" em excesso |

Mistura de broadcast esportivo, bastidores de promoção e sala de matchmaking. Por orientação do usuário, estudar a linguagem dos menus de UFC Undisputed 3 (2012); usar marca, arte e universo próprios. Ver [pesquisa visual](docs/VISUAL_IDENTITY.md).

## Cores (`Tokens`)

| Token | Hex | Uso |
|---|---|---|
| `CANVAS` | `#111417` | Fundo global |
| `SURFACE` | `#1B2025` | Navegação e painéis |
| `PAPER` | `#F1EEE6` | Conteúdo editorial, contratos, documentos |
| `INK` | `#F4F1E8` | Texto primário |
| `MUTED` | `#8A939C` | Metadados |
| `FIGHT_RED` | `#C83B3B` | Ação, perigo, evento, resultado e o item selecionado do menu (barra acesa, como em Undisputed 3); nunca fundo de tela |
| `TITLE_RED` | `#B51D22` | Faixas de título e de comandos |
| `PANEL` / `PANEL_ROW` / `PANEL_LINE` | `#E4E6E9` / `#D5D8DC` / `#BEC3C9` | Painéis claros, linhas listradas e divisórias |
| `PANEL_INK` / `PANEL_MUTED` | `#1C2025` / `#59616B` | Texto sobre painel claro |
| `HEADER_BAR` / `HEADER_TEXT` | `#4A4F56` / `#DADDE0` | Cabeçalhos de painel e de seção |
| `TABLE_BLUE` | `#2B55C4` | Rótulos de coluna e de campo |
| `HINT_TEXT` | `#E2D2A6` | Linha de descrição no rodapé |
| `STEEL` | `#46535E` | Estrutura e divisores |
| `CHAMP_GOLD` | `#B88B46` | **Só** cinturões, campeões, legado, Hall da Fama |

## Tipografia

- Display: **Chakra Petch Bold**, angular, incorporada em `game/ui/theme/fonts/` com licença SIL OFL. Alternativa próxima autorizada; não afirmar que é a fonte original do Undisputed 3.
- Menus, abas, títulos e cabeçalhos de seção: Chakra Petch Bold em **itálico sintético** (`Tokens.italic_font()`, inclinação `Tokens.SLANT`) e CAIXA ALTA, como nos menus de Undisputed 3.
- UI/Data: **Chakra Petch Medium**, local/offline, com acentos em português. Barlow não faz parte da identidade. Texto corrido e metadados continuam em caixa normal.

## Navegação

| Aba | Objeto dominante | Função |
|---|---|---|
| Início | Próximo evento + decisões | O que exige atenção agora |
| Lutadores | Roster / rankings | Gerir e explorar atletas |
| Eventos | Fight cards / calendário | Montar e operar noites |
| Mercado | Busca / scouting / free agency | Encontrar e contratar |
| Organização | Identidade / finanças / mídia / staff | Administrar a empresa |

## Linguagem de menus (referência: UFC Undisputed 3, 2012)

Implementada em `game/ui/ud3_chrome.gd`, `game/ui/theme/tokens.gd` e `game/ui/stat_widgets.gd`.

- Fundo: key art própria em tons de cinza, clareada (`Ud3Chrome.Backdrop`).
- Topo: faixa vermelha `TITLE_RED` com a ponta esquerda cortada e o nome da área em branco; contexto (promoção · data · caixa) à direita.
- Painéis claros `PANEL` com borda branca e sombra; cabeçalhos em faixa cinza-escura `HEADER_BAR` com texto claro centralizado.
- Listas: linhas claras com texto escuro; o item selecionado acende inteiro em `FIGHT_RED` com texto branco e pontas cortadas.
- Tabelas: colunas em azul `TABLE_BLUE`, linhas listradas, nota de elite em vermelho.
- Rodapé: faixa vermelha com a marca e os comandos (VOLTAR, MENU) e, embaixo, a linha de descrição em `HINT_TEXT` do item em foco.
- Landscape: menu de áreas num painel à esquerda e conteúdo à direita. Portrait: conteúdo em cima e faixa de áreas acima do rodapé.
- Só a linguagem é referência: nada de logos, fontes, arte ou nomes do jogo original.

## Regra dos 3 toques

Toda área abre em 1 toque (faixa de áreas ou cartão da central) e toda ação em até 3. Exemplos: ficha de atleta = Lutadores → atleta (2); escalar atleta = ficha → "Escalar em…" → Enviar proposta (3 a partir da ficha); contratar agente livre = Mercado → atleta → Enviar contrato (3); balanço de uma noite = Organização → noite (2). Toda tela nova precisa caber nessa regra; atalhos entre telas usam `Screen.navigate` e o VOLTAR refaz o caminho.

## Regras de UX mobile

- Ações frequentes em até dois toques.
- Portrait: faixa de áreas acima do rodapé. Landscape/tablet: menu de áreas à esquerda.
- Bottom sheets para detalhes contextuais; nunca modal sobre modal.
- Listas densas para dados tabulares; superfícies só para entidades/eventos reais.
- Toque mínimo `Tokens.TOUCH_MIN` (88 px no viewport de 720 px ≈ 48 dp). Respeitar safe areas.
- Tela de luta: round a round em 1x, 2x, 5x e resultado instantâneo; mostra stamina, dano, estatísticas e eventos — sem controle de golpes.

## Marca

- Monograma **CO**: dois blocos que se encaram separados por uma linha central (divisória de fight card). Sem luvas, octógono literal ou silhuetas de lutador. `game/icon.svg` é um **placeholder** desse conceito.
- Aplicações a criar: logo + monograma, app icon, splash, key art, template de fight card, breaking news, scoreboard, cinturões fictícios por organização, ícones de categorias de peso, banners de evento, social cards.

## Implementado

Menu inicial com key art própria, cabeçalho recortado, cinco abas, tipografia local e transmissão CO Sports. A simulação visual é sempre o Fight Studio original, inclusive no Android via pacote offline. Ver `docs/VISUAL_IDENTITY.md` para referências e `docs/HANDOFF.md` para limites reais.
