# Changelog 5.3.0

Base preservada: 5.2.0. Runtime: 12.5.0-delivery-integrity. Uma única política de produção, sem A/B.

## Correções novas

1. `inc/ads/economics.php`: preserva revisões negativas em intervalos com volume zero/negativo e em janelas sem ponto inicial utilizável. Deltas desconhecidos ficam nulos; revisão não cai em fallback acionável de preço diário.
2. `inc/ads/yield.php`: uniformiza os parâmetros de engajamento e antecipação entre horários usando a base diurna existente. Mantém os mínimos por dispositivo. Remove `request_spacing_ms` do perfil horário, que não era consumido pelo runtime.
3. `assets/js/go-ads-runtime.js`: `unfill-optimized` deixa de contar como preenchimento forte em `auctionSignal()`, sem alterar a apresentação oficial controlada pelo Google.
4. `assets/js/go-ads-runtime.js`: verifica densidade nas janelas afetadas pela candidata; uma janela remota não alterada deixa de vetar a posição.
5. `assets/js/go-ads-runtime.js`: agenda uma reconciliação de layout após materializar/solicitar um host quando ainda há posições pendentes. Mantém uma solicitação por registro e não cria polling de candidatas recusadas.
6. `inc/sitemap-news.php` e `inc/sitemap-smart.php`: adicionam primeira publicação pública à busca limitada de candidatos News/Fresh, com deduplicação, ordenação e validação final. Invalidam cache quando dependências relevantes de publicação/privacidade mudam.
7. `inc/ads/dashboard.php`: distingue acumulado estimado, intervalo, revisão e falta de volume; remove afirmações de piso real, dinheiro recuperável e causalidade de formato sem evidência.
8. `inc/ads/config.php`: comentários descrevem o contrato de conta e o tratamento de geometria dos formatos oficiais com precisão.

## Preservado

Loader oficial, consentimento, âncora/vinheta, inventário e IDs existentes; reservas alcançadas; continuação F4/F5; Top Scroll até seis com critérios adicionais; memória consentida de latência; geometria responsiva/sticky; correções de SEO da 5.2.0; CTA contextual de Tecnologia.

## Validação

Regressões novas reproduzidas na base preservada e verificadas na versão corrigida. Fonte/minificado derivados pelo build canônico. Matriz completa e limites da simulação registrados em `VALIDACAO-5.3.0.md`.

## Implantação

Pacote completo local. Nenhuma alteração de conta, publicação no WordPress ou submissão manual ao Google foi executada. Rollback: tema anterior mais invalidação de cache, com restauração explícita de opções persistidas quando desejada.
