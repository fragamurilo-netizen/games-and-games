# Laboratório de rostos (protótipo web)

Protótipo do gerador procedural de retratos (Game Design Bible §5). Abra `index.html` no navegador; não precisa de build.

- **Editor**: sliders (idade, porte, rosto, mandíbula, queixo, nariz quebrado, couve-flor, calvície) e sorteio por população.
- **Catálogo**: 7 rostos, 15 tons de pele, 9 olhos, 6 íris, 8 sobrancelhas, 9 narizes, 9 bocas, 4 orelhas, 56 cabelos, 20 cores, 19 barbas, 18 marcas (sardas, pintas, cicatrizes, tatuagens, piercings).
- **Populações**: 15 distribuições + "misto". Faixas se sobrepõem de propósito (bíblia §13).
- **Estilos**: A Broadcast (padrão no jogo), B Recorte (peças de evento), C Facetado, D Scout.
- **JSON**: o formato exportado é o que `Fighter.appearance` deve guardar ao portar para `game/identity/face_generator.gd`.

Referência de porte: toda a geometria está em unidades normalizadas (cabeça ≈ 2 de altura, origem no centro do rosto), então a lógica de `drawFace` traduz direto para `CanvasItem.draw_*` / `Polygon2D` na Godot.

## Rodada 2 — tendências do MMA atual

14 cortes e 3 cores adicionados a partir das tendências observadas no ranking UFC de 19/09/2026 (undercut, mullet moderno, crop francês, espetado, degradê com risca, high top, moicano cacheado, dreads presos, meio coque, duas tranças, trança única, coque baixo, pixie, lateral raspada; mechas coloridas, rosa, verde). Os nomes são genéricos e nenhum estilo reproduz um atleta real (Game Design Bible §22).

## Rodada 3 — fotos do ranking + corpo inteiro

Referência: fotos oficiais dos 200 atletas ranqueados em ufc.com.br/rankings (29/09/2026). Entraram 14 cortes (topete curto, franja longa, cogumelo, na altura do ombro, ondulado médio, cachos volumosos, dreads soltos, twists altos, afro puff, rabo alto, coque bagunçado, curto de lado, volumoso espetado, tranças nas laterais), 4 cores (duas cores, pontas descoloridas, acaju, prata) e 4 barbas (desenhada, longa sem bigode, bigode grosso, cavanhaque longo).

**Corpo inteiro** (`drawFigure`): reaproveita `drawFace` com `noBody` para a cabeça e desenha tronco, braços, luvas, calção e pernas. Poses sem cinturão: media day, guarda, braços cruzados, vitória. Com cinturão: no peito, no ombro, erguido, na cintura. O cinturão é fictício (placa dourada com o monograma CO) — nada de placa octogonal ou logos reais. `face.kit` guarda cor do calção e das luvas.

## Rodada 4 — corpo realista

`drawFigure` reescrito: membros com perfil anatômico (deltoide, bíceps/tríceps, braquiorradial, quadríceps, vasto medial, panturrilha), tronco com trapézio, dorsal em V, peitoral, abdômen, oblíquos, serrátil, linhas do V e clavículas, luz vinda da esquerda, luvas de MMA com dedos e velcro, pés, calção com fenda e cordão. Novo `face.body = {muscle, fat, hair, height}` e presets por categoria (mosca, leve, médio, pesado).


## Rodada 5 — mais cabelos, barbas e tipos de corpo

26 cabelos novos (waves 360, caesar, flat top, degradê com desenho, afro e cachos com degradê, samurai, undercut com coque, nagô, freeform, wolf cut, viking trançado, bob, shag, bantu knots, coques duplos…) e 14 barbas (lenhador, viking trançada, van dyke, balbo, garibaldi, guidão, chevron, fu manchu, degradê, falhada…), marcados `novo:2`. `BODY_TYPES` define 20 físicos (12 masculinos, 8 femininos) sobre 14 parâmetros de corpo; `genFace` sorteia um tipo coerente com sexo e categoria. `node ../../tools/build_appearance_catalog.cjs` exporta tudo para `game/content/appearance_catalog.json`.

## Estúdio — anatomia contínua e materiais

O novo modo **Estúdio** é o padrão do laboratório. A–D continuam disponíveis para
comparar a direção original. O Estúdio é uma ilustração procedural em Canvas 2D,
sem dependências de execução e sem imagens de atletas reais.

- Silhueta única para tronco, pescoço, braços e pernas, com volumes suaves em vez
  de peças articuladas desenhadas separadamente. Proporções e poses refeitas.
- Mãos abertas ou fechadas conforme a pose, quatro dedos e polegar; cinco dedos
  em cada pé. Escolha entre mãos livres e luvas de MMA com dedos aparentes.
- Fios de cabelo e barba determinísticos, stubble, sobrancelhas, poros, íris,
  sombras de pálpebra e variação de volume facial. Detalhe limitado pelo tamanho
  renderizado para preservar a legibilidade nos avatares pequenos.
- Silhuetas Natural, Atlética, Curvilínea e Potente. Controles independentes de
  cintura, quadril, tórax, pernas, ombros e alcance. Top esportivo com volume,
  costuras e caimento; calção com dobras, cós e material camuflado.
- Prévia de corpo inteiro, retrato, mão e pés. As duas vistas de detalhe são
  exclusivas do Estúdio. Exportação PNG em 1440 × 2088 (corpo) ou 1440 × 1656
  (demais enquadramentos), usando o mesmo estilo e os parâmetros atuais.

`studio.js` concentra os materiais e o novo corpo; `identity.js` contém a
biblioteca facial compartilhada com o Fight Studio; `index.html` mantém a interface. A geometria facial e o
seed permanecem a identidade do atleta ao longo da carreira.

O JSON continua em `v: 1`, com campos aditivos em `body`: `shoulders`, `reach`,
`legs`, `waist`, `hips`, `legMass` e `chest` (0–1). `kit.hands` aceita `bare` ou
`mma`. Aparências antigas recebem valores padrão. Luz e enquadramento não
alteram o JSON. Estes campos pertencem ao protótipo; o porte para a Godot ainda
é a tarefa indicada no roadmap.

### Verificação do renderer

O laboratório continua abrindo diretamente pelo `index.html`. Node é necessário
apenas para os testes opcionais:

```sh
npm install
npm test
```

Os testes verificam determinismo, ausência de mutação da aparência, resposta dos
controles anatômicos, ambos os sexos, limites do canvas nas oito poses e nos
biotipos extremos, todos os estilos, os dez atletas canônicos e os 56 cabelos.
A validação visual no navegador cobre também os controles, o PNG e o layout mobile.
