# Validação independente — versão única 5.1.1

**Resultado: aprovada para empacotamento local.** O tema 5.1.1 usa o runtime `12.3.0-unified-manual`, com uma política de entrega para todos os leitores. A infraestrutura de divisão em grupos, canais de tratamento e bootstrap experimental foi retirada. A validação não acessou o site publicado nem fez requisições reais ao AdSense.

Foram aprovadas **33 suítes**, compostas por 23 suítes PHP e dez JavaScript, após a correção de uma falha de empacotamento identificada pelo verificador estático. A sintaxe dos **257 arquivos PHP da árvore final** passou. A cópia minificada foi reconstruída em diretório temporário e ficou idêntica, byte a byte, à entregue.

## Resultado auditável e correção final

A corrida integrada inicial terminou com 32/33 suítes aprovadas. A única falha foi o guarda que exige a ausência dos arquivos exclusivos de A/B: os módulos já tinham sido retirados da integração, mas ainda havia arquivos órfãos na cópia de trabalho. A falha não foi ignorada nem removida do teste.

Depois da exclusão física, o mesmo verificador passou **109/109**. A ausência foi confirmada tanto pelo revisor quanto pelo agente que empacota o ZIP. Também foi concluído um ajuste da tela de Top Scroll para identificar e tornar somente leitura o limite determinado pela constante histórica `GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_MAX`, assim como já ocorre com a constante atual `...FREQUENCY_LIMIT`. O teste PHP correspondente foi repetido e passou **72/72**, mais **6/6** com um default explícito diferente de seis.

Os hashes confirmam que, após a corrida integrada, as únicas alterações de produção foram a exclusão dos dois arquivos experimentais e esse ajuste em `inc/ads/topscroll-admin.php`. A suíte exclusiva de configuração experimental também foi excluída. A matriz de runtime permaneceu válida e não foi repetida sem necessidade.

## Cobertura efetivamente executada

| Área | Resultado | Comportamento demonstrado em ambiente local |
|---|---:|---|
| Runner do tema | 33 suítes aprovadas após a correção dirigida | Planner, economia, renderização, formatos, carregamento, runtime, reservas e listagens |
| Integridade estática final | 109/109 | Versões 5.1.1/12.3.0, bootstrap preservado, ausência de infraestrutura experimental e contratos fundamentais |
| Sintaxe PHP | 257/257 arquivos | Nenhum erro de sintaxe na árvore final, incluindo Ads Center e tela de Top Scroll |
| Top Scroll unificado | 72/72 + 6/6 | Migração única, precedência das opções/constantes/filtros, idempotência, preservação de escolhas posteriores e HTML da tela administrativa |
| Loader PHP | 17/17 | Tag canônica uma vez, claim compartilhado, publisher correto, páginas inelegíveis, integração Site Kit e hard gate opcional |
| Gate do loader em JavaScript | 8/8 cenários | Consentimento tardio, eventos repetidos, provider pré-existente, fallback WP, exceção do CMP, revogação e nova concessão sem duplicação |
| Runtime unificado | 15/15 na fonte e 15/15 no minificado | Reservas alcançadas em mobile/desktop, limites estruturais, densidade, consentimento, aba oculta, latência, continuidade e ausência de dependência de grupos/storage |
| Regressões da auditoria | 9/9 na fonte e 9/9 no minificado | Casos dirigidos de consentimento, resposta do provedor, colapso e solicitações únicas |
| Runtime básico e Top Scroll inteligente | 60 asserções + 19 cenários | Comportamentos existentes preservados sob a nova política padrão |
| Listagens e hubs | 18 cenários, 216 asserções | Home, categorias, latest, pools, F4/F5, AJAX, páginas subsequentes, hero ausente, hooks repetidos e caminhos de fallback |
| Composer e fallback de unidade | 19/19 + 17/17 | Unidade desabilitada ou inelegível não desperdiça a oportunidade do mesmo host |
| Agregação SQL de visibilidade | 14/14 | Consultas reais sobre fixtures locais; nenhuma chamada ao Google |
| Discovery de conteúdo dinâmico | 25 eventos de scroll e um evento de conteúdo | Scroll não repete descoberta estrutural global; atualização explícita de conteúdo permite nova descoberta |
| Build de produção | Byte a byte idêntico | Fonte e minificado correspondem; o build foi feito em cópia temporária |

As suítes existentes de governor, densidade, viewport, liberação de posições e navegações simuladas também passaram. As quantidades de asserções dessas matrizes são condicionais; não representam pessoas, impressões ou observações econômicas independentes.

## O que as novas regras padrão demonstraram

### Uma política de entrega, com os mesmos critérios para todos

A admissão de uma reserva alcançada funciona sem `GOAdsExperiment`, sem canal de tratamento, sem um segundo provider e sem permissão para gravar storage. O teste injeta um getter que falha se o runtime tentar acessar a API experimental e implementações de storage que falham se forem chamadas sem permissão. Os dois casos passam.

Isso não elimina o consentimento publicitário configurado. Um placement com gate explícito aguarda consentimento; eventos posteriores liberam a mesma instância uma vez. A mesma política também mantém os limites de geometria, densidade, exposição, visibilidade da aba e capacidade estrutural. Leitores podem receber quantidades diferentes porque alcançam posições diferentes ou têm elegibilidade diferente; não há divisão aleatória entre versões do motor.

Reservas distantes continuam bloqueadas. O runtime não cria um plano quando a capacidade base do artigo é zero, e não ultrapassa a menor capacidade entre oportunidades renderizadas e capacidade estrutural. O governador continua influenciando antecipação e ritmo; a reserva efetivamente alcançada pode qualificar-se sem depender de entrar no estado de expansão.

### Top Scroll: migração persistente, sem reset recorrente

Um valor legado salvo de três ou quatro passa a seis quando a unidade está habilitada e não há override explícito. O novo marcador é independente do marcador da migração anterior. Uma segunda resolução não regrava a opção nem o marcador. Se o operador escolher três ou quatro depois da migração, a escolha permanece.

Os casos de unidade desabilitada, zero, valores não legados, default customizado, filtros e constantes mantêm sua autoridade. A constante histórica `...FREQUENCY_MAX` volta a ser reconhecida e a constante atual `...FREQUENCY_LIMIT` tem precedência. A tela mostra corretamente qual constante determina o limite e torna o campo correspondente somente leitura.

O contrato mantém quatro preenchimentos sem o requisito adicional de engajamento, a quinta elegível com três páginas ou 60 segundos ativos e a sexta com quatro páginas ou 120 segundos. São critérios da lógica do tema. Esta validação não demonstra que seis gera mais receita que quatro, nem transforma a medição interna de tempo em uma prova de leitura atenta.

### Listagens e hubs sem duplicação

F4/F5 só são materializados após limites reais de cards no feed original e a partir do manifesto original da página. Scripts em fragmentos são descartados antes de sua inserção no fixture. O mesmo host não recebe outra solicitação e um ID já registrado não é reciclado.

O hook após o hero editorial integra o caminho normal. Os testes cobrem hero inexistente, AJAX, segunda página real do documento/desk e acionamento repetido de hooks, além da sequência normal de unidades. A restrição atual de um ID de unidade por documento é uma escolha interna do tema; este relatório não a apresenta como proibição do Google de reutilizar o mesmo ID em oportunidades estruturais distintas.

### Loader preservado para manuais, âncora e vinheta

O HTML emitido pelo PHP contém o script oficial com o publisher esperado. Chamadas repetidas da integração não imprimem um segundo bootstrap. Quando o gate opcional é usado, o próprio script gerado pelo PHP foi executado em um DOM simulado, verificando a inserção única após consentimento.

Esses testes confirmam a preservação técnica do loader necessário aos anúncios manuais e aos formatos oficiais. Eles não verificam os controles da conta: âncora/vinheta, banners in-page, “encontrar mais posições” e “otimizar anúncios atuais” ainda dependem de observação do painel ou de relatório compatível.

## Limites da validação

Todos os requests de anúncio existentes nos testes são chamadas a stubs locais. Os fixtures não carregam a biblioteca do Google. Um `push`, um status de preenchimento simulado ou uma reserva admitida não representa receita.

Não foi executada uma página real em Chromium. A tentativa anterior com Chrome 153.0.8010.52 foi bloqueada pelo ambiente ao criar um socket (`Operation not permitted`); nenhuma nova tentativa de download ou lançamento foi feita nesta versão. Por isso, não houve observação real de CSS, CLS, LCP, INP, criativos, bfcache, rotação física do aparelho ou concorrência real entre abas. Os cenários de viewport, visibilidade e ciclo de vida descritos aqui são simulações.

Também não foram medidos ganho econômico, Active View do Google, cobertura real, RPM, conta AdSense ou experiência do site publicado. A aprovação significa que o código passou nos contratos e cenários locais descritos, com o pacote tecnicamente consistente. Não significa garantia de RPM de US$ 4 ou aumento de receita.

## Reprodução e evidências

Na pasta do tema, com PHP CLI com DOM e mbstring, além de Node:

```sh
php tests/run.php
php tests/test-topscroll-unified.php --custom-default
python3 tests/test-active-view-sql.py
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-evolution.test.js
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-audit-regressions.test.js
```

No ambiente desta auditoria, foi usado PHP 8.3.6 local com `allow_url_fopen=0`, Node 24.19.0 e SQLite via Python para o teste SQL. O script `ready/validation/run_release.py` registra a corrida reproduzível; `release-validation-final.json` consolida o resultado e distingue a falha inicial da repetição dirigida.

Evidências principais em `ready/validation/`: `release-suite.log`, `release-suite.json`, `static-integrity-root.log`, `topscroll-final.log`, `topscroll-custom-default-final.log`, `release-lint.json`, `runtime-unified-min.log`, `runtime-audit-min.log`, `active-view-sql.log`, `dom-scan-review.json`, `release-build.json`, `unified-absence.json` e `source-freeze-final.json`.

| Arquivo final | Bytes | SHA-256 |
|---|---:|---|
| `assets/js/go-ads-runtime.js` | 116.704 | `5e20ac54798f7e230d8603971ce94852430efc4d3937094258efe065c7f4acef` |
| `assets/js/go-ads-runtime.min.js` | 84.960 | `0ef1455326ff3244ddcbc28e5a5454b0b232f2b87d43abb43b07678ed965c4ad` |

**Decisão da revisão:** manter a versão única 5.1.1 para o empacotamento autorizado, com os testes e a documentação. Não há falha material aberta nos cenários executados. A confirmação de veiculação real, experiência no navegador e resultado financeiro exige observação após uma implantação autorizada.
