# games-and-games

Tema WordPress **Overdrive** (gameoverdrive.com.br) e o motor de anúncios manuais do AdSense.

- `theme/`: o tema, no mesmo formato do pacote enviado (arquivos na raiz do zip).
- `docs/PLANO-MONETIZACAO-5.7.0.md`: o que mudou na 5.7.0, o que verificar e como reverter.
- `tools/`: bancadas locais que usam o código do próprio tema.
  - `php tools/plan-bench.php theme [--positions]`: planejador do artigo num corpus fixo.
  - `php tools/render-bench.php theme <single_post|home|category|single_game>`: unidades emitidas por template.
  - `tools/sim/page.php` + `tools/sim/run.cjs`: simulação no Chromium com o runtime real e leitores sintéticos.
  - `node tools/build-ads-runtime.cjs [--check]`: gera `go-ads-runtime.min.js` e `.lean.js` a partir do fonte (precisa de `terser` no `NODE_PATH`).
