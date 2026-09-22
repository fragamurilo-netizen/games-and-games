# Validação 5.4.0

A árvore final foi congelada antes da matriz. Nenhum arquivo de produção foi alterado durante a validação. Os registros completos e comandos estão no dossiê separado.

## Resultado

| Verificação | Resultado |
|---|---:|
| Suítes integradas | **44/44**, sendo 32 PHP e 12 JavaScript |
| Lint PHP | **267/267** arquivos |
| Guardas estáticas | **109/109** |
| Modos, consentimento, overrides, admin, cache, IDs e saúde | **455 asserções**, 12 casos/processos isolados |
| Limpeza inicial e preservação de conteúdo | **25/25** |
| Limpeza de parágrafos vazios e blocos protegidos | **20/20** |
| Cache de vídeo com SimpleXML | **29/29** |
| Worker com WP-CLI true/false | **6/6 + 6/6** |
| Coletor JavaScript de diagnóstico | **9/9** cenários |
| Disponibilidade PHP do diagnóstico | **30/30**, oito combinações |
| Scripts atuais contra HTML arquivado | **4/4** fixtures estruturais |
| Solicitações publicitárias reais durante os testes | **0** |
| Build do minificado | **Idêntico byte a byte** |

A suíte integrada de vídeos, no PHP sem SimpleXML carregado, executou 22 checks e registrou a extensão ausente. A rodada dirigida com a extensão executou todos os 29, mais 12 dos modos CLI. Não foram omitidas essas diferenças de ambiente.

Fonte e minificado do runtime 12.5.0 são idênticos à base 5.3.0. Rodadas direcionadas passaram também sobre o minificado: política única 15/15, auditoria 9/9, geometria responsiva 15/15 e regressões finais 5/5. Permanecem verificações de consentimento tardio, preenchimento/falha/atraso, ausência de duplicação, listagens, frequência, navegação, densidade, sitemaps, SEO, publicação e CTA.

## Ambiente e alcance

PHP CLI 8.3.6 com DOM/mbstring; extensão SimpleXML habilitada nas rodadas dirigidas. Node 24.19; fixtures HTML5 com jsdom 30.1.0/parse5, recursos externos desativados. Os testes PHP substituem funções WordPress e serviços externos. A produção capturada informou PHP 8.5.4; esta não foi uma instalação completa com seu banco, plugins e cache.

As fixtures exercitam mobile/desktop por dimensões declaradas e geometria simulada. Não constituem medição de layout real. Não houve execução do Google, teste de clique, leitura de iframe publicitário ou solicitação real de anúncio.

O navegador local não estava operacional. Uma tentativa remota de abrir HTML isolado sem rede foi recusada pela revisão automática, sem tentativa de contorno. Sem interceptação de rede disponível, o site não foi aberto em navegador automatizado. Portanto, não foram observados criativos reais, estilos computados em produção, LCP, INP, CLS ou Active View por esse caminho.

## Evidência versus conclusão

Os testes comprovam os casos de lógica executados. Não comprovam receita incremental, conclusão de leilão, preenchimento real, recuperação de Discover ou reconhecimento do corpo pelo pipeline proprietário do AdSense.

O coletor de diagnóstico foi validado como leitura local sob demanda, sem mutação editorial ou rede. Seus resultados futuros dependem da página e do navegador em que o administrador o executar. Um host, `push` ou `filled` não é comprovante de receita.

O relatório econômico foi recalculado pelos totais e conferido separadamente. Seus dados são exportações/capturas com períodos, fusos e limitações próprios; não equivalem a uma consulta atual ao painel AdSense.

## Registros no dossiê

- `bodylab/validation/release-validation-final.json`: matriz consolidada.
- `bodylab/validation/source-freeze.json`: hashes de 399 arquivos de produção.
- `bodylab/validation/release-build.json`: reconstrução do minificado.
- `bodylab/validation/package-final.json`: integridade do instalador e correspondência integral dos arquivos.
- `bodylab/analysis/validation.md`: evidência independente detalhada.
- `bodylab/analysis/primary-economics-independent-validation.json`: 313 verificações econômicas independentes.

Nenhuma implantação, mudança de conta ou submissão ao Google foi executada.
