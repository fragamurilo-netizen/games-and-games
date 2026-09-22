# Validação 5.5.8 — Discover / AVIF

## Testes executados

- PHP lint em todos os arquivos `.php` do tema: **0 erros de sintaxe**.
- `tests/test-discover-image-deliverability.php`: **56 asserções passaram, 0 falharam**.
- `tests/static-integrity.php`: **169 asserções passaram, 0 falharam**.
- Suíte geral: todas as suítes relacionadas à alteração passaram. O runner local
  ainda registra uma falha preexistente em `turkish-channel-list-ranking-v48.php`
  porque o PHP do ambiente de teste não possui a extensão `mbstring`
  (`mb_strtolower()` indisponível). Essa falha é independente da correção AVIF.

## Fluxo esperado em produção

1. `.htaccess` entrega `.avif` como `Content-Type: image/avif`.
2. O tema testa `assets/img/avif-delivery-probe.avif` via HTTP.
3. AVIF antigo passa a ser aceito como imagem representativa de schema/Discover.
4. Se GD/Imagick também processar AVIF, o Media Library libera novos uploads.
5. Os recortes derivados continuam saindo em WebP pelo filtro
   `image_editor_output_format` já existente.
6. O backfill já existente em `inc/discover-recovery-38120.php` tenta gerar
   `go_hero` e `go_discover_16x9` ausentes em imagens recentes durante o admin.

## O que conferir depois da instalação

Em **Ferramentas → Saúde do site**, procure **Entrega de imagens AVIF**.

- Verde: HTTP `image/avif` + editor AVIF; upload/schema/Discover sincronizados.
- Amarelo: HTTP já está correto, mas GD/Imagick não processa AVIF. O acervo pode
  ser entregue ao Google, porém novos uploads permanecem bloqueados para evitar
  imagens sem recortes responsivos.
- Vermelho: o AVIF público ainda não responde como `image/avif`; limpe
  LiteSpeed/CDN e revise o `.htaccess`.

Depois, valide uma matéria afetada no HTML público:

- `meta[name="robots"]` contém `max-image-preview:large`;
- o JSON-LD `Article`/`NewsArticle` contém `image` com URL rastreável;
- `og:image` deve preferir um recorte WebP quando houver derivada disponível;
- a imagem escolhida tem pelo menos 1200 px de largura e mais de 300 mil pixels.
