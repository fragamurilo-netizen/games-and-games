# Validação final — Game Overdrive 5.5.0

**Resultado: aprovado.** Tema 5.5.0, runtime `12.6.0-manual-baseline`. Execução offline em PHP CLI e Node com DOM/respostas simulados; não houve requisição publicitária real, implantação ou alteração de conta.

## Rodada consolidada

| Verificação | Resultado |
|---|---:|
| Suítes do runner principal | 52/52 — 38 PHP + 14 Node |
| Sintaxe de todos os arquivos PHP | 273/273 |
| Suítes dirigidas contra o minificado servido | 8/8 |
| Sintaxe dos JavaScript de produção alterados | 3/3 |
| Reconstrução canônica do minificado | Idêntica byte a byte; mtime elegível |
| Diagnóstico de posição na prosa | 20/20 |
| Agregação Active View via SQL | 14 verificações aprovadas |
| Top Scroll com DEFAULT externa | 7/7 |
| Reset administrativo com DEFAULT externa | 228/228 |
| Loader e consentimento | Idênticos byte a byte à 5.4.1 |
| Código e testes durante a rodada | Sem alterações |

Os conjuntos têm asserções e cenários de naturezas diferentes; não foram somados para anunciar um número único artificial de testes.

## Contratos novos e ampliados

- Composer: 462 asserções, nove cenários. Recusa, contexto, ID duplicado/pré-reivindicado, nenhuma unidade, reservas e idempotência. Nos casos normal e reserva sem recusas, o HTML completo é idêntico ao anterior.
- Reset Top Scroll: resolução padrão 130/130; migração administrativa 227/227; alternativa DEFAULT 228/228. Inclui falha na escrita de backup/opção/marcador, reentrada, corrida, campos extras e filtro na prioridade zero. Getter público não grava banco.
- Frequência Top Scroll: 31/31 asserções no fonte e no minificado, com janela móvel, outra aba, consentimento e sem contabilizar unfilled como fill. LocalStorage não fornece uma transação atômica de leilões simultâneos.
- Arquitetura manual: 365 asserções em 13 processos; migração 81 em 12 casos. Opção/constante/filtro legado não suspende manual; emergência global preservada.
- Registro de side rails: 50 asserções no caminho handler real → espelho → view, mantendo permissão/nonce e sem chamar Google.
- Política financeira fixa: 45 verificações. Export público não lê intraday/totais do dia; integração administrativa preservada. Priors inválidos/velhos neutros.
- Runtime baseline: dez cenários na fonte e dez no minificado. Oito rótulos financeiros com mesma entrega; uma vaga antecipada corretamente priorizada; nenhum GET de regime com payload legado; modelo com validade; reserva alcançada sem primárias e negativos de consentimento/telemetria/capacidade/densidade.
- Masthead editorial: 229 asserções PHP em 17 casos; 14 cenários de runtime em cada forma do JS. Desktop de reviews/críticas/especiais excluído; notícias e demais contextos preservados; sem descartar criativo já solicitado em largura menor.
- Evolução do runtime: 16/16 na fonte e no minificado. Cenário sem primárias exige orçamento antecipado zero e reserva alcançada válida; sem telemetria/capacidade não pede.
- Sessões geradas: 1.200 sessões e 27.802 verificações na fonte. O teste dirigido complementar também passou contra o minificado. Mantém limites, consentimento, densidade, dedupe e caminho reached-reserve.

## Primeira rodada e correção de testes antigos

A primeira execução completa encontrou quatro suítes com expectativas do contrato aposentado: Auto Ads suspendendo Masthead; versão antiga do cache/payload; zero anúncios quando nenhuma primária sobrevivia, mesmo com reserva válida alcançada. As expectativas foram atualizadas mantendo casos negativos e limites. Não foi necessário alterar a produção depois daquele congelamento. Logs da primeira rodada foram preservados no dossiê, assim como os resultados da segunda rodada aprovada.

O teste novo aplicado à versão antiga não significa que toda falha encontrada seja um bug histórico: parte verifica a mudança autorizada de arquitetura. A reprodução da dupla cobertura e das contagens incorretas do composer é documentada separadamente.

## Reproduzir

Com PHP CLI e Node disponíveis, executar na pasta do tema:

```bash
php tests/run.php
node tests/build-runtime-min.js
```

O runner usa PHP_BINARY para os testes-filhos. Para um teste Node que renderiza fixtures PHP, informar `GO_TEST_PHP` quando o executável não estiver no PATH. Os testes comuns usam o harness incluído e não requerem WordPress ou Google ao vivo.

O diagnóstico adicional usa jsdom instalado fora do tema:

```bash
GO_JSDOM_MODULE=/caminho/node_modules/jsdom node tests/diagnostics-position-review.cjs
python3 tests/test-active-view-sql.py
```

Não incluir `node_modules` no tema nem executar testes contra a publicidade real. O dossiê contém o script da validação consolidada e os logs. Recompilar o minificado só é necessário após editar a fonte; o pacote já contém o arquivo gerado.

## Limites

A simulação não executa o leilão Google, não comprova preenchimento real, receita incremental, Active View da nova versão, Core Web Vitals de campo ou retorno de Discover. Os testes de viewport/DOM validam a lógica e os contratos simulados; não são um novo ensaio visual em navegador móvel real.

A conta, o banco WordPress publicado e os caches externos não foram alterados. O reset ocorrerá localmente no WordPress instalado conforme o guia; conferir propagação de cache e versão do runtime no site.
