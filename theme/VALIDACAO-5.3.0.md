# Validação 5.3.0

Rodada final de 21/09/2026, depois do congelamento das fontes. Ambiente: PHP CLI 8.3.6, Node 24.19.0 e SQLite via Python. Os módulos reais do tema foram executados com fixtures locais; não foi iniciado um WordPress completo da hospedagem.

## Resultado

| Verificação | Resultado |
|---|---:|
| Runner integrado | **40/40 suítes**, 28 PHP + 12 JavaScript |
| Sintaxe PHP | **262/262 arquivos** |
| Integridade estática | **109/109 verificações** |
| Revisões, intervalos e atualização econômica | **84/84** |
| Contrato econômico / yield | 18/18 e 207/207 |
| Dashboard em seis estados, warnings como exceção | **26/26** |
| Perfil horário PHP | 11/11 |
| Perfil horário com PHP e runtime reais | **24 horas × dois dispositivos; 480/480 na fonte e no minificado** |
| Novas regressões do runtime | **5/5 na fonte e no minificado** |
| Geometria responsiva, sticky e âncora | 15/15 na fonte e no minificado |
| Política unificada / regressões anteriores | 15/15 e 9/9, também no minificado |
| Primeira publicação e invalidação | **32/32** |
| SEO/feed/diagnóstico | 48/48 |
| Sitemaps | 53/53 em cada um de três providers; cinco modos extras de endpoint aprovados |
| CTA Tech / integração independente | 82/82 e 84/84 |
| Loader oficial | 17 asserções PHP e oito cenários JS |
| Top Scroll | 72/72 + 6/6 com default explícito |
| Continuação de listagens/hubs | 18 cenários, 216 asserções |
| SQL de Active View | 14/14 |
| Minificado reconstruído | **Idêntico byte a byte** |
| Produção alterada durante a rodada | **Não** |
| Requisições publicitárias reais | **Zero** |
| Páginas executadas em navegador real | **Zero** |

Os manifests sem dados privados estão em `docs/validacao-5.3.0/`. Contagens de fonte/minificado e providers são execuções de verificações, não números de bugs ou pessoas.

## Regressões demonstradas

O mesmo teste econômico passou 43/84 na base 5.2.0 e 84/84 na versão corrigida. Revisão de receita com denominadores estáveis, correção intermediária e ponto inicial ausente deixaram de ser interpretados como preço acionável.

A equivalência de horário passou de 416/480 para 480/480 no fixture independente, com o mesmo dispositivo, comportamento e latência. O teste de primeira publicação reproduziu 11 falhas na base anterior e passou 32/32 depois. A suíte nova do runtime passou de 1/5 para 5/5, preservando o controle que impede acrescentar uma quarta unidade à janela afetada.

As verificações exercitaram unfilled, tratamento otimizado oficial, silêncio, resposta tardia, consentimento tardio/revogado, uma solicitação por posição, retorno pelo histórico, memória consentida, resize e conteúdo dinâmico. A simulação adicional de duas horas/500 eventos manteve um único fetch de diagnóstico e estabilizou os frames, sem polling autossustentado no caso verificado.

## Reprodução básica

Na raiz do tema:

```sh
php tests/run.php
php tests/test-topscroll-unified.php --custom-default
python3 tests/test-active-view-sql.py
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-final-regressions.test.js
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-responsive-geometry.test.js
```

O executor completo e os logs complementares estão no dossiê técnico separado. Eles podem registrar caminhos específicos do ambiente original, que devem ser adaptados numa reprodução local.

## Limites

DOM, observer, consentimento e respostas do provedor foram simulados. A limitação do ambiente para iniciar Chrome impediu QA visual real; não foi apresentada simulação como screenshot. Criativo real, bfcache do navegador, concorrência real de abas, CSP/CDN, CMP específica e o WordPress completo não foram certificados por esses testes.

Não houve requisição à biblioteca publicitária para gerar impressões. `filled` em uma fixture comprova transição lógica, não receita. A conta do Google e o servidor publicado não foram alterados por esta validação.

Não foi medida capacidade de hospedagem, uptime, saturação SQL/PHP ou Core Web Vitals de campo. As metas p75 LCP≤2,5s, INP≤200ms e CLS≤0,1 permanecem metas. **Aprovação lógica não comprova ganho econômico, Active View nem distribuição no Discover.**

## Hashes do runtime

- Fonte, 126.598 bytes: `9fc0e1d4edff8195f63c45de932003d25180e13efe55b690a827bbbf81259216`.
- Minificado, 91.934 bytes: `9a73e55aa104824af85369f97aa4753319fdfd8c05099f6db6ce3680d52affa4`.

O SHA-256 do instalador final é registrado no manifesto externo de empacotamento, evitando referência circular dentro do próprio ZIP.
