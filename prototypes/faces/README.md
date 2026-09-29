# Protótipo: rostos procedurais

Laboratório para decidir a abordagem visual dos retratos. Abra `index.html`
num navegador (arquivos locais funcionam).

- `faces-core.js`: genoma com seed, herança (alelos de olho/cabelo, calvície
  ligada à mãe), estilos (61 cabelos, 36 barbas) e geometria por idade/peso.
  Puro, sem DOM: é o que vai virar `packages/simulation` + `packages/ui`.
- `faces-render.js`: dois renderizadores em Canvas 2D sobre a mesma geometria.
  - `mode: "vector"`: opção 1, formas e gradientes.
  - `mode: "real"`: opção 4, relevo + luz por pixel, rugas como relevo,
    cabelo em mechas e fios. No app vira shader do Skia com cache do retrato.

Protótipo em JS puro para iterar rápido; não é código de produção.
Não usa `Math.random` no rosto (só o botão "Nova pessoa" da página).
