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
