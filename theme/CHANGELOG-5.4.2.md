# Changelog 5.4.2

## Anúncio Masthead

- `inc/ads/context.php`: resolve reviews, críticas e especiais pelo post consultado, incluindo especiais com pacote próprio e classificação legada sem sobrepor uma escolha editorial explícita.
- `inc/ads/config.php`: aplica `max_viewport` somente ao `site-masthead` desses artigos.
- `inc/ads/renderer.php`: compõe a media query de elegibilidade e emite CSS inicial escopado para remover a reserva na largura excluída. Preserva anúncios já solicitados durante redimensionamento.
- `tests/test-masthead-editorial.php` e `tests/runtime-masthead-editorial.test.js`: verificam tipo, contexto, largura, consentimento, resposta vazia, ausência de resposta e deduplicação. Incluídos no runner.

## Diagnóstico

- `assets/js/go-ads-recovery-diagnostics.js`: separa a posição antes/entre/depois dos parágrafos da região ampla `article-prose`; preserva estados do provedor separados; totais anteriores à amostra e vizinhos estruturais. Uso apenas administrativo, local e sob demanda.

## Identificação

- `functions.php`, `style.css`, verificação estática e guias identificam a 5.4.2.
- CTA Games da 5.4.1 preservado, com jogos grátis e promoções; canal Tech e contexto editorial preservados.
- Fonte/minificado do runtime, loader, consentimento, frequência, limites de densidade, artigo editorial e conta AdSense não foram alterados nesta atualização.

Não houve deploy, migração de banco, alteração de conta ou validação de ganho financeiro. A mudança do Masthead é uma escolha de apresentação/inventário solicitada, não uma promessa de elevar RPM.
