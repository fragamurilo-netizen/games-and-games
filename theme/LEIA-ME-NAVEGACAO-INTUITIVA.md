# Navegação editorial intuitiva — 19/09/2026

Esta revisão separa visual e funcionalmente duas ações que antes pareciam iguais:

1. **Navegação real** — Plataformas e Seções abrem seus próprios arquivos (PC, PlayStation, Filmes, Séries, Celulares etc.).
2. **Tipo de matéria** — fica dentro de **Últimas publicações** e atualiza somente essa lista via AJAX, sem recarregar a página.

## Mudanças de UX

- O termo visível **Subeditorias** foi trocado por **Seções**.
- Saiu o chip ambíguo **Visão geral**. A página-mãe agora aparece como **Página principal**; nas páginas-filhas, surge **← Voltar para Games/Entretenimento/Tecnologia**.
- Games separa claramente **Plataformas** de **Seções**.
- As seções usam navegação em texto/tabs; os tipos de matéria usam botões de filtro. Assim, links que trocam de página não parecem controles AJAX.
- Em páginas que já são um tipo de matéria, como Dicas e Guias, Reviews, Rankings e Críticas, o filtro de tipos não é repetido. Isso evita mostrar “Dicas e Guias” e, logo abaixo, permitir trocar para Reviews mantendo o mesmo título da página.
- No offcanvas, **Tipos de matéria** continuam disponíveis e **Subeditorias** passa a ser **Seções**.

## Onde assistir

- Novo tipo oficial `onde-assistir` / **Onde assistir**.
- Aparece nos filtros de Entretenimento e automaticamente no offcanvas.
- Entra no vocabulário fechado de `go_content_type` e no seletor editorial.
- URLs/títulos com a expressão literal “onde assistir” passam a ser detectados com alta confiança.
- Foi incluída migração única e limitada para matérias antigas com `onde-assistir` no slug ou “onde assistir” no título, preservando tipos especialistas já definidos.
- Categorias/tags legadas `onde-assistir`, `onde-assistir-online` e `assistir-online` continuam elegíveis no filtro.

## AJAX

Os filtros e a paginação continuam solicitando apenas o fragmento `#od-desk-feed`. Hero, navegação, Guias de compra, sidebar e restante da página não são renderizados novamente.

## Refinamento visual

- removido o microcopy “Navegação” e “Filtra somente a lista abaixo”;
- removidas as linhas divisórias superior/inferior do bloco de navegação;
- “Tipo de matéria” deixou de usar card, fundo e contorno;
- filtros ficam diretamente sobre o fundo da página em todas as editorias e subeditorias;
- comportamento AJAX foi mantido sem alterações.
