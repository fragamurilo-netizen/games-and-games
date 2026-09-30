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

- Formas em paralelogramo com a mesma inclinação do itálico (`Tokens.slanted_box`).
- Item selecionado = barra inteira acesa em `FIGHT_RED`; os demais em carvão com régua `STEEL` embaixo.
- Cabeçalho de tela: placa vermelha cortada na diagonal com o nome da aba, filete off-white e o contexto (organização / data) ao lado.
- Cabeçalho de seção: faixa carvão inclinada com entalhe vermelho à esquerda.
- Menu inicial: barras empilhadas, a selecionada mais longa; placa de descrição abaixo; faixa de dicas no rodapé.
- Só a linguagem é referência: nada de logos, fontes, arte ou nomes do jogo original.

## Regras de UX mobile

- Ações frequentes em até dois toques.
- Portrait: faixa de abas embaixo. Landscape/tablet: faixa de abas no alto, abaixo do cabeçalho.
- Bottom sheets para detalhes contextuais; nunca modal sobre modal.
- Listas densas para dados tabulares; superfícies só para entidades/eventos reais.
- Toque mínimo `Tokens.TOUCH_MIN` (88 px no viewport de 720 px ≈ 48 dp). Respeitar safe areas.
- Tela de luta: round a round em 1x, 2x, 5x e resultado instantâneo; mostra stamina, dano, estatísticas e eventos — sem controle de golpes.

## Marca

- Monograma **CO**: dois blocos que se encaram separados por uma linha central (divisória de fight card). Sem luvas, octógono literal ou silhuetas de lutador. `game/icon.svg` é um **placeholder** desse conceito.
- Aplicações a criar: logo + monograma, app icon, splash, key art, template de fight card, breaking news, scoreboard, cinturões fictícios por organização, ícones de categorias de peso, banners de evento, social cards.

## Implementado

Menu inicial com key art própria, cabeçalho recortado, cinco abas, tipografia local e transmissão CO Sports. A simulação visual é sempre o Fight Studio original, inclusive no Android via pacote offline. Ver `docs/VISUAL_IDENTITY.md` para referências e `docs/HANDOFF.md` para limites reais.
