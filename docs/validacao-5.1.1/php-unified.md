# PHP — versão única pronta para uso

Estado final: uma única política manual, sem grupos, canais de experimento, matrícula ou etapa posterior para ativar recursos. Trabalho restrito a `ready/work`; `evolution/work`, o tema original e os arquivos enviados continuam preservados. Não houve implantação, alteração da conta AdSense nem requisição publicitária real.

## Mudanças efetivas

- `inc/ads.php` deixa de incluir o módulo de experimentos.
- Removidos os três arquivos novos de A/B: `inc/ads/experiment.php`, `assets/js/go-ads-experiment.js` e `tests/test-experiment-config.php`.
- `inc/ads/loader.php` volta ao provider oficial canônico. Removidos loader com canal e chamadas a `GOAdsExperiment`. O caminho de consentimento rígido opcional continua quando explicitamente configurado; segue desligado por padrão. Continua um loader para anúncios manuais, âncora e vinheta oficiais, com a proteção existente contra tag duplicada do Site Kit.
- `inc/ads/consent.php` perde somente a dependência experimental. Não exige statistics, GA4, gtag, matrícula ou canais para veicular anúncios normais. O consentimento necessário ao armazenamento local continua respeitado.
- `inc/ads/yield.php` emite `delivery_v2.reserve_admission = reached` como descrição da política única do runtime. O agente do runtime removeu a atribuição por braço e aplica essa regra com os demais gates estruturais preservados.
- A interface A/B e seu contador GA4 opcional foram removidos. GOAC/Ads Center e integrações de relatório anteriores foram preservados.

## Top Scroll: padrão pronto de até seis/24h

A configuração padrão é até seis preenchimentos na janela móvel de24horas. Os quatro primeiros não dependem do gate adicional de engajamento; a quinta exige três páginas na sessão local **ou**60segundos ativos, e a sexta quatro páginas **ou**120segundos ativos. A sessão local tem inatividade de30minutos; não é uma sessão GA4. Continua sendo frequência entre navegações, sem refresh do anúncio.

O histórico local é condicionado à permissão de armazenamento. Assim, o número é uma cota local quando o histórico pode ser lido, não promessa de rastreamento entre navegações sem consentimento. A concorrência entre abas na quota de preenchimentos não recebeu um lock novo nesta etapa.

### Migração única

Código: `inc/ads/topscroll.php`, funções `go_verge_adsense_topscroll_has_ready_override`, `go_verge_adsense_topscroll_maybe_migrate_ready_cap` e `go_verge_adsense_topscroll_config`.

Novo marcador WordPress: **`go_verge_topscroll_ready_20260921_v1`**. Ele é independente de `go_verge_topscroll_revenue_20260921`, que migrava somente quatro. Não altera nenhum controle da conta AdSense.

| Estado antes da primeira resolução | Resultado |
|---|---|
| Opção inexistente | Padrão efetivo6; grava somente o marcador. |
| Habilitado, frequência salva3 ou4, sem override | Persiste6; preserva os demais campos da opção; grava marcador. |
| Frequência salva6 | Mantém6; grava somente marcador. |
| Frequência salva0 | Mantém0, cuja semântica existente é sem cota local; grava somente marcador. |
| Outros valores explícitos2 ou5 | Preserva o valor; grava somente marcador. |
| Desabilitado | Mantém desabilitado e a frequência salva; grava somente marcador. |
| Constante explícita de frequência, default customizado ou constante que desabilita | Preserva a opção e o override; grava somente marcador. |
| Filtro registrado de configuração ou de habilitação Top Scroll | Preserva a opção e a autoridade do filtro; grava somente marcador. |
| Resolução seguinte | Não grava novamente nem repete a migração. |
| Operador escolhe3/4 depois da migração | Respeita a escolha; não volta a seis. |
| Override removido depois da primeira resolução | Não faz uma migração tardia escondida. |

Um filtro pode devolver o mesmo valor que já estava salvo. Não é possível inferir ausência de override apenas pela igualdade do resultado. Por isso, um filtro registrado nesses dois hooks impede a alteração persistente da preferência durante essa migração, mesmo que altere outro campo. Essa escolha conservadora foi deliberada para preservar configurações explícitas.

### Precedência de configuração

A frequência usa, nesta ordem: constante atual `GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT`; alias legado `GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX`; opção salva ou default; filtro de configuração aplicado ao resultado. A faixa continua limitada a0–6. O alias legado é realmente consumido, com fonte `legacy-constant`; não é apenas detectado e ignorado.

A configuração informa fonte `default`, `option`, `constant`, `legacy-constant` ou `filter` quando o filtro muda o valor. `topscroll-admin.php` foi alinhado: MAX legado e LIMIT atual deixam a frequência somente para leitura e identificam a constante efetiva. Sem override por constante, o campo normal continua editável.

## Reversão e persistência

Trocar novamente os arquivos do tema não desfaz a preferência6 que já tiver sido persistida no banco. Para uma redução posterior, usar a tela existente **Aparência → Top Scroll**, ou o override explícito já utilizado pelo site. Manter o marcador evita que uma escolha posterior seja reescrita. Não há migração de conta nem remoção de dados históricos GOAC.

## Validação executada nesta frente

- `tests/test-topscroll-unified.php`: **72/72**. Default;3/4→6; marcador antigo; opções6/0/2/5; desabilitado; campos extras; contagem de writes; reexecução; escolha posterior; filtros com valor igual e diferente; retirada de filtro; MAX legado; precedência LIMIT; constante desabilitada; HTML administrativo editável/readonly e nome da constante correta.
- `tests/test-topscroll-unified.php --custom-default`: **6/6**. Constante de default explícita, precedência da opção, ausência de migração e gravação apenas do marcador.
- `tests/test-yield.php`: **207/207**.
- `tests/test-economics-readiness.php`: **26/26**.
- `tests/test-economics-contract.php`: **18/18**.
- PHP lint de `topscroll.php` e `topscroll-admin.php`: sem erro.
- O agente de validação informou testes independentes do loader: **17asserções PHP +8cenários Node**; a matriz central final é registrada por ele.

As verificações são de lógica/sintaxe e simulações locais. Não demonstram aumento de receita nem substituem a observação posterior do site publicado.

### Nota de empacotamento

A exclusão inicial por patch não apareceu em todos os contextos dos agentes, embora os includes e os demais arquivos tenham sido atualizados. A exclusão explícita local foi executada e o responsável principal foi avisado para confirmar os três paths ausentes no seu contexto e no ZIP final. O critério de entrega é ausência física no pacote, além de ausência de chamadas no runtime e loader.
