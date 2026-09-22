# Changelog 5.4.0

Base preservada: 5.3.0. Runtime: 12.5.0-delivery-integrity, sem alterações em fonte/minificado nesta revisão. O instalador completo também inclui as correções acumuladas das versões auditadas anteriores.

## Integridade editorial e disponibilidade

- `inc/single-clean.php`: preserva integralmente o conteúdo original quando a limpeza inicial encontra erro de expressão regular; reduz retrocesso desnecessário e trata o BOM UTF-8 corretamente.
- `inc/template-helpers.php`: a normalização de parágrafos vazios protege comentários, script, style, textarea, template, pre e code; evita reserialização global do HTML e preserva o conteúdo em falhas.
- `inc/editorial-layouts.php`: retira as chamadas síncronas de feeds YouTube da resposta pública de `/videos/`; usa cache por canal, atualização agendada, bloqueio temporário compartilhado, deduplicação e fallback editorial. O worker aceita cron ou WP-CLI explicitamente ativo.

## Entrega e diagnóstico

- **Novo** `inc/ads/mode.php`: oferece `manual_overlays` como padrão e `auto_overlays` como alternativa explícita. Implementa precedência de opção/constante/filtro, salvamento administrativo com permissão e nonce, histórico limitado de mudanças e solicitação de invalidação dos caches compatíveis.
- `inc/ads.php`, `inc/ads/config.php`, `inc/ads/context.php`, `inc/ads/renderer.php`, `inc/ads/composer.php` e `inc/ads/assets.php`: integram o modo antes da materialização de hosts, reservas, turnos e assets manuais. Loader e consentimento compartilhados continuam disponíveis.
- `inc/ads/health.php`: aceita IDs personalizados válidos; separa controles declarados de verificação efetiva; qualifica ausência de provider em respostas remotas e situações de consentimento/HTTP.
- `inc/ads/dashboard.php` e `inc/ads/topscroll-admin.php`: mostram o modo efetivo e qualificam evidência local, frequência e receita residual.
- `inc/ads-center/includes/class-goac-view-delivery.php` e `class-goac-view-optimization.php`: preservam as integrações de relatório e deixam explícitos os limites de atribuição por formato e da configuração local.
- `inc/ads/diagnostics.php` e `assets/js/go-ads-recovery-diagnostics.js`: diagnóstico administrativo sob demanda nos dois modos. O coletor examina estrutura, raízes e marcadores; não faz requisições, não altera o artigo nem inventa confirmação de receita.

## Metadados e validação

- `style.css` e `functions.php`: versão do tema 5.4.0.
- Novos testes: `test-content-cleanup.php`, `test-video-feed-cache.php`, `test-delivery-mode.php` e `test-article-empty-paragraph-integrity.php`.
- `tests/run.php` e `tests/static-integrity.php`: integração das novas verificações e versão atual.
- Novos guia, changelog e resumo de validação 5.4.0; manual principal atualizado. Guias anteriores mantidos como histórico.

## Preservado

Âncora/vinheta oficiais, publisher/IDs, carregamento canônico, consentimento, GOAC/Ads Center, CTA contextual Tech, sitemaps/primeira publicação, ausência de refresh e política manual de oportunidades editoriais. Não foram criados slots AdSense fictícios nem aplicadas configurações remotas.

## Limites e reversão

O laboratório reproduziu os bugs descritos e validou a lógica corrigida. Não executou o algoritmo de inserção Google, não mediu Core Web Vitals de campo e não identificou uma causa única comprovada para o Discover e o Auto Ads. O modo alternativo permite uma verificação operacional coordenada, sem afirmar que ela já ocorreu.

Rollback: versão anterior mais invalidação de cache, com restauração das opções e dos controles da conta que tiverem sido alterados. Consulte o guia de instalação e o dossiê para o patch exato e seus hashes.
