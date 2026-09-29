# Laboratório de rostos (protótipo web)

Protótipo do gerador procedural de retratos (Game Design Bible §5). Abra `index.html` no navegador; não precisa de build.

- **Editor**: sliders (idade, porte, rosto, mandíbula, queixo, nariz quebrado, couve-flor, calvície) e sorteio por população.
- **Catálogo**: 7 rostos, 15 tons de pele, 9 olhos, 6 íris, 8 sobrancelhas, 9 narizes, 9 bocas, 4 orelhas, 28 cabelos, 13 cores, 15 barbas, 18 marcas (sardas, pintas, cicatrizes, tatuagens, piercings).
- **Populações**: 15 distribuições + "misto". Faixas se sobrepõem de propósito (bíblia §13).
- **Estilos**: A Broadcast (padrão no jogo), B Recorte (peças de evento), C Facetado, D Scout.
- **JSON**: o formato exportado é o que `Fighter.appearance` deve guardar ao portar para `game/identity/face_generator.gd`.

Referência de porte: toda a geometria está em unidades normalizadas (cabeça ≈ 2 de altura, origem no centro do rosto), então a lógica de `drawFace` traduz direto para `CanvasItem.draw_*` / `Polygon2D` na Godot.
