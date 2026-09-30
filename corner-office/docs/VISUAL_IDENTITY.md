# Corner Office — identidade de jogo e referências

Direção solicitada: Android primeiro; forte inspiração nos menus de **UFC Undisputed 3, THQ/Yuke's, 2012**. Universo, arte e marca continuam próprios. A referência não é EA Sports UFC 3.

## O que foi observado

Foram abertas e inspecionadas capturas de seleção de regras, opções pré-luta, premiações da carreira, loja e lista de técnicas. A galeria também contém cenas de academia e de luta, que não são evidência de menus.

| Tela de referência | Observação | Aplicação no Corner Office |
|---|---|---|
| Seleção de regras | Fundo com luta, cabeçalho vermelho cortado em diagonal, escolha central dominante | Key art própria, título grande e poucas ações no menu inicial |
| Opções pré-luta | Cantos vermelho/azul, linhas claras, hierarquia forte entre categoria e valor | Montagem de card com identificação dos dois corners |
| Premiações da carreira | Tabela horizontal densa, seleção vermelha, retratos junto ao resultado | Elenco, rankings e resultados como listas, sem uma grade de cartões |
| Loja | Painel claro sobre academia, item selecionado inequívoco, detalhes abaixo | Formulários com seleção persistente e informações próximas da decisão |
| Técnicas | Lista no alto, demonstração e explicações abaixo, navegação estável | Fight Studio mantém catálogo, reprodução e descrição da técnica |
| Transmissão | Placas sobrepostas ao combate e nomes com alto contraste | CO Sports: placar inferior, round, relógio e resultado factual |

Referências visuais consultadas:

- [Galeria MeriStation — imagens de carreira, loja e técnicas](https://as.com/meristation/2012/01/28/album/1326361980_000001.html)
- [GamePro — galeria de UFC Undisputed 3](https://www.gamepro.de/galerien/ufc_undisputed_3,56805.html)
- [Gamereactor — tela de seleção de regras](https://www.gamereactor.eu/media/grtv/44/24461_w926.jpg)
- [Opções pré-luta](https://images.cgames.de/images/gsgp/287/ufc-undisputed-3_2274285.jpg)
- [Guia oficial Prima — ações da carreira](https://primagames.com/eguides/ufc-undisputed-3-eguide/gameplay/career-mode/pre-fight-actions)

Não foram importados screenshots, logos ou atletas reais para os assets do jogo. Não se afirma ter assistido integralmente ao jogo ou ao trailer.

## Tipografia

**Chakra Petch Bold / Medium**, incorporadas localmente em `game/ui/theme/fonts/`. O usuário autorizou uma fonte próxima caso a original não pudesse ser usada. A escolha tem terminações angulares, boa distinção de algarismos e acentos em português. Não usa Barlow e não depende de Google Fonts em tempo de execução.

Não foi possível confirmar documentalmente a família exata utilizada em Undisputed 3. Créditos de **Undisputed 2010** citam United Fonts / House Industries; isso não prova que o jogo de 2012 use a mesma fonte. Por isso Chakra Petch é identificada como alternativa, nunca como a fonte original.

- [Arquivos oficiais da família no Google Fonts](https://github.com/google/fonts/tree/main/ofl/chakrapetch)
- Licença SIL OFL 1.1 incluída junto dos arquivos; manter `OFL.txt` ao redistribuir.
- [House Industries — termos de licença](https://houseindustries.com/license/) foi consultado durante a pesquisa; não foi adquirida uma licença de fonte proprietária.

## Marca e arte

Carvão, branco quente, vermelho queimado, cortes diagonais e regras metálicas finas. Dourado continua reservado a campeões e legado. A navegação oferece alvos de toque grandes e contraste estável. Portrait usa cinco abas inferiores; landscape usa navegação lateral. A tela inicial tem três ações claras sobre arte, e a carreira enfatiza a próxima noite.

Arte original gerada com a ferramenta ImageGen, sem referência a uma pessoa real. Asset final: `game/assets/brand/corner-office-menu.png`. Não é uma captura da simulação; é a ilustração do menu.

Brief da geração: key art cinematográfica de um jogo fictício de MMA, proporção horizontal, dois atletas adultos à direita; mulher brasileira atlética em top e shorts pretos com detalhes vermelhos em primeiro plano e homem negro atlético atrás; anatomia e pescoços naturais, mãos coerentes, cabelo e pele detalhados, pose séria; iluminação branca de arena e recorte vermelho discreto; área esquerda escura e livre para texto; textura sutil; sem texto, logotipos, interface, neon ou semelhança com pessoas reais. Os títulos são desenhados pela interface para permanecerem nítidos e traduzíveis.

## Uma única simulação visual

**Não criar um renderer nativo simplificado para substituir o Fight Studio.** A versão substituta foi rejeitada pelo usuário e removida. `broadcast.html` usa os mesmos `renderer.js`, `replay.js`, `appearance.js`, `studio.js` e `identity.js` já trabalhados. O pacote offline contém esses arquivos sem reescrever corpos, roupas, rostos ou movimentos. O motor de combate continua Godot; a apresentação só lê o replay.

Android: o módulo `CornerOfficeStudio` hospeda esse HTML em uma WebView offline dentro do jogo. Desktop de desenvolvimento: a mesma transmissão abre em HTML local no navegador. O Godot conserva a carreira. Não apresentar a abertura externa de desktop como a integração final de Android; conferir o APK em aparelho real.
