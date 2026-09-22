# Validação do Game Overdrive 5.2.0

Rodada final de 21/09/2026, realizada depois de congelar a correção `game-navigation-flow`. Base de execução: PHP CLI 8.3.6 e Node, com os módulos reais do tema carregados em fixtures locais. Não equivale a executar WordPress completo em PHP 8.5.4 do servidor observado.

## Resultado

| Verificação | Resultado |
|---|---:|
| Runner integrado | **37/37 suítes** |
| Composição do runner | 26 PHP + 11 JavaScript |
| Sintaxe PHP da árvore | **260/260 arquivos** |
| Geometria/âncora/sticky/jogos | **15/15 cenários na fonte e 15/15 no minificado** |
| Política única de reservas e continuidade | 15/15 no teste dirigido, também validado no minificado |
| Regressões anteriores de lifecycle | 9/9 no teste dirigido, também validado no minificado |
| CTA contextual e proteção estrutural | **82/82** no teste; revisão independente **84/84**, incluindo as 82 |
| SEO, datas, RSS e diagnóstico | **48/48** |
| News/sitemap/canonical, por provider | **53/53** com Yoast, Rank Math e nenhum provider |
| Modos adicionais News/HTTP/ETag | **11/11 verificações** |
| Emissor real OpenGraph do Rank Math | 3 verificações adicionais; 51/51 na execução suplementar com a suíte SEO |
| Active View SQL | 14/14 |
| Build do minificado | Idêntico byte a byte ao reconstruído |
| Produção alterada durante a rodada final | Não |
| Requisições publicitárias reais nos testes | **Zero** |
| Cenários executados em navegador real | **Zero** |

Totais repetidos em provedores/fonte/minificado são execuções de casos, não quantidade de bugs distintos. O sumário legível e os manifests desta rodada estão em `docs/validacao-5.2.0/`.

## Comportamentos exercitados

- Viewport inicialmente sem largura/altura, recuperação por resize e fallback às dimensões do documento.
- Preservação da identidade de INS/iframe e de um único pedido durante resize, troca de breakpoint e respostas tardias.
- Criativo alto em tela baixa, largura superior à permitida para sticky, saída horizontal, offset desconhecido e sequência de reflows sem oscilação.
- Âncora oficial no topo, rodapé ou lateral, com e sem interseção; entrada tardia depois de a fila esvaziar, alteração de status/geometria e retirada. Nenhuma alteração no formato oficial.
- Lateral de jogo com barra local `.od-game-nav` usa fluxo normal; ausência de barra permite a guarda normal de sticky. Sem novo pedido ou ocultação.
- Consentimento tardio, ausência de duplicação e regressões de preenchimento/ausência de resposta já presentes no runner.
- CTA por editoria, subeditoria/ancestrais e assunto, preservação de outros canais e convites manuais, escaping e deduplicação.
- Anúncio imediatamente seguido por H2: o convite procura outra fronteira válida. Anúncio separado por prosa não impede indiscriminadamente o convite. O host publicitário permanece idêntico byte a byte.
- OG/Article/WebPage com relógio editorial coerente, guardas de publicação/preview/proteção, preservação de AVIF Google e deduplicação de schema.
- News com provider ativo, title tokens e fallback, janela de 48 horas; Fresh com ETag/IMS; canonical distinto preservado; RSS com aspas/espaços/origem; robots diagnóstico por grupo.

## Regressões reproduzidas antes da correção

As fixtures foram executadas também contra a base 5.1.1 preservada. Exemplos documentados no dossiê técnico: SEO 27/48 antes e 48/48 depois; CTA inserido ao lado do anúncio apesar da guarda nominal; geometria insuficiente sem espera; sticky sob âncora tardia. Logs anteriores e posteriores foram preservados, sem converter falhas simuladas em receita perdida comprovada.

O teste adicional do plugin usa o método real `OpenGraph::tag()` da distribuição pública Rank Math 1.0.278 com WordPress substituído por stubs. Ele comprova o caminho dos três hooks nessa implementação pública, não a versão exata do plugin instalado no servidor.

## Reprodução básica

Na raiz do tema, com PHP CLI e Node disponíveis:

```bash
php tests/run.php
php tests/test-sitemap-indexing.php --provider=rank-math
php tests/test-sitemap-indexing.php --provider=none
php tests/test-sitemap-indexing.php --endpoint=news
php tests/test-sitemap-indexing.php --endpoint=fresh-ims
php tests/test-sitemap-indexing.php --endpoint=fresh-etag
php tests/test-sitemap-indexing.php --endpoint=changed-etag
php tests/test-sitemap-indexing.php --endpoint=stable-ims
node tests/runtime-responsive-geometry.test.js
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-responsive-geometry.test.js
```

## Limites

O ambiente não permitiu iniciar o Chrome real, por restrição de socket. Não foram simuladas visualmente as páginas como se fossem screenshots reais nem feitas chamadas de anúncio para preencher criativos em testes. As regras CSS foram verificadas por contrato e comportamento de fixtures; layout, criativo real, conta, CDN e concorrência completa de WordPress precisam de observação no ambiente publicado após instalação autorizada.

CrUX PHONE/DESKTOP estava indisponível no conector por falta de chave configurada. Não há medição p75 de campo nesta entrega. LCP≤2,5s, INP≤200ms e CLS≤0,1 permanecem metas de campo, não resultados certificados.

Simulação comprova os comportamentos exercitados. **Não comprova aumento de receita, retorno ao Discover, Active View oficial ou instalação no site.**

## Hashes finais do runtime

- Fonte: `7a003aa3cc95c1ba4076a09ef5f606eabc877a23ccbd6f3dccfe2d1ef45191c3`.
- Minificado: `617d697a7417567b1484526637395525760e679153869508e690c52049e9228d`.

O hash do ZIP final é registrado no manifesto de empacotamento externo, evitando uma referência circular dentro do próprio arquivo.
