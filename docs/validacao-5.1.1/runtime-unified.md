# Runtime da versão única pronta para uso

## Resultado

O runtime em `ready/work/assets/js/go-ads-runtime.js` agora é **`12.3.0-unified-manual`**. Existe uma única política de entrega: usar o orçamento antecipado do governador e admitir também a reserva estruturalmente segura que o leitor alcançou, ou está prestes a alcançar, desde que passe pelas demais verificações de entrega.

Não há grupo, matrícula, atribuição, canal experimental ou necessidade de um bootstrap adicional no runtime. A configuração antiga `delivery_v2.reserve_admission='governor'`, se aparecer em um payload em cache, não muda a política da nova versão silenciosamente. O PHP da entrega descreve a política como `reached`; o JS implementa essa política diretamente.

As cópias `evolution/work`, `audit/work` e o anexo original foram preservados. Não houve alteração de conta, implantação ou solicitação publicitária real.

## Arquivos alterados neste escopo

| Arquivo em `ready/work` | Alteração |
| --- | --- |
| `assets/js/go-ads-runtime.js` | Versão 12.3.0; remove os hooks de infraestrutura experimental; promove admissão por chegada; remove contexto de grupos/canais dos snapshots; descreve o orçamento antecipado com precisão |
| `assets/js/go-ads-runtime.min.js` | Reconstruído pelo build canônico a partir da fonte final |
| `tests/runtime-evolution.test.js` | Mantém o nome usado pelo runner, mas agora reporta `runtime-unified`; 15 cenários da política única |
| `tests/runtime.test.js` | Atualiza o teste de orçamento para conferir reservas alcançadas, capacidade estrutural e caminho real de admissão |
| `tests/runtime-governor-600.test.js` | Distingue orçamento antecipado e teto estrutural; conserva testes dos estados e regras do governador |

Nenhum PHP foi editado neste escopo. A remoção do módulo administrativo e das ramificações do loader foi coordenada com a equipe responsável por PHP.

## Caminho efetivo de execução

### Política única de admissão

`bodyBudget()` em aproximadamente 724 continua retornando o orçamento antecipado do planejador, ampliado pelo estado `expansion` até os hosts seguros renderizados. `budgetAllows()` em 761 verifica esse orçamento primeiro. Quando ele está ocupado, `reachedReserveAllows()` em 741 pode admitir uma unidade adicional do corpo se:

1. Há telemetria do planejador e pelo menos uma posição efetivamente planejada.
2. O número de unidades ocupadas está abaixo do mínimo entre hosts renderizados e capacidade estrutural declarada.
3. A oportunidade está dentro da área útil de visualização; ou satisfaz todos os critérios de chegada iminente: prazo previsto dentro da latência mais margem, distância limitada à meia tela útil ou ao lead de repouso — o menor deles —, ritmo inferior ao limite de rolagem rápida e estimativa local de alcance de pelo menos 0,90.

A verificação explícita de `plannedBodyCount >= 1` impede que metadados inconsistentes, como zero posições planejadas com duas reservas declaradas, abram inventário sem um plano válido.

Esse método apenas autoriza a posição a continuar pelo caminho de execução. `activate()` em 1668 ainda aplica visibilidade da página, media query, consentimento publicitário quando exigido, proximidade, prioridade das posições críticas, exposição, densidade, ritmo, visibilidade do host, largura, tamanho permitido, frequência, engajamento do Top Scroll, propriedade única do ID e markup válido. Só então executa o único `adsbygoogle.push({})` daquela instância.

O estado `expansion` permanece útil à antecipação, mas deixou de ser requisito exclusivo para solicitar uma reserva já alcançada. Não foram aumentados o teto estrutural, a densidade, o número máximo de unidades na janela ou os espaçamentos globais.

### Remoções completas do caminho ativo

Foram removidas as chamadas de aplicação de configuração antes do runtime, modificação de opções na montagem, revalidação de opções em cada tentativa e leitura de snapshot de atribuição. Também foi removido o normalizador que anexava braços, canais e eventos de documento aos diagnósticos.

A busca na fonte e no minificado finais não encontrou referências a `GOAdsExperiment`, `experimentSnapshot`, `manualOptions`, `revalidateOptions`, `applyYield` ou `data-ad-channel`. O runtime não cria um script de provedor adicional nem adiciona canais às unidades. As opções normais de frequência vêm do PHP e continuam sendo respeitadas.

O diagnóstico informa `reserveAdmission: 'reached'` e conserva `budgetPath`: `planned`, `governor-expansion`, `reached-reserve` ou `waiting`. `explain()` chama `bodyBudget` de orçamento antecipado e explica que reservas alcançadas podem entrar dentro da capacidade segura; assim, quatro posições ocupadas com orçamento antecipado de duas não parecem uma inconsistência do relatório.

### Funcionalidades preservadas

- **Memória consentida de latência:** sessionStorage com TTL e isolamento por perfil; não lê nem grava armazenamento quando a permissão não existe. A falta de autorização de armazenamento não impede uma reserva segura quando o anúncio, pela política de consentimento publicitário aplicável, está autorizado a solicitar.
- **Consentimento publicitário:** uma posição com gate publicitário continua aguardando autorização. Eventos de concessão liberam a tentativa uma vez, sem repetir o pedido depois.
- **Continuidade F4/F5:** manifestos inertes do documento inicial, contagem dos cards reais, remoção de scripts antes da inserção e montagem única por ID. Nenhum incremento de inventário ocorre só por existir um manifesto no footer.
- **Geometria e exposição:** prioridade usa geometria atual; anúncios profundos frios seguem aguardando; largura, densidade e velocidade continuam limitando o pedido.
- **Ciclo de vida:** resposta tardia, unfilled, consentimento tardio e retorno de navegação mantêm as correções anteriores. Unidade já solicitada não é atualizada artificialmente.
- **Âncora e vinheta oficiais:** o runtime conserva a observação da geometria reconhecida da âncora para calcular área útil. Ele não cria nem substitui esses formatos.
- **Diagnóstico local:** amostra e buffer de RAM preservados, sem envio automático, receita presumida ou rótulo de Active View.

## Validação direcionada

As verificações locais executadas nesta etapa foram:

| Verificação | Resultado observado |
| --- | --- |
| Política única e funcionalidades de evolução, fonte | **15/15 cenários passaram** |
| Contratos básicos do runtime, fonte | **60 asserções passaram, zero falhas** |
| Regressões da auditoria, fonte | **9/9 cenários passaram** |
| Build canônico do minificado | Concluído com sucesso |
| Ausência dos hooks experimentais na fonte e no minificado | Confirmada pela busca estática |

Os 15 cenários cobrem mobile e desktop, admissão visível e iminente, posições frias, capacidade estrutural, plano ausente/inconsistente, densidade, consentimento negado e concedido depois, segundo plano, armazenamento negado e permitido, configuração antiga inerte, inexistência de bootstrap extra, ausência de canal inserido, deduplicação, memória de latência, respostas filled/unfilled/optimized, mudança de largura, priorização e F4/F5.

O teste de independência usa um getter que lança erro caso o runtime tente ler a infraestrutura removida, armazena zero acessos e confirma que nenhum script foi criado. Com armazenamento negado, os getters/setters de storage também lançariam erro; continuam com **zero acessos** enquanto as duas posições autorizadas pelo gate publicitário são solicitadas uma vez cada no provedor simulado.

A primeira execução do teste básico encontrou a expectativa antiga de somente duas posições ocupadas; a nova política entregou quatro. O teste foi atualizado para verificar precisamente o novo contrato: quatro posições ocupadas dentro da capacidade de quatro, orçamento antecipado ainda em duas e duas admissões identificadas como `reached-reserve`. Não foi ocultada uma falha de densidade ou solicitação duplicada.

A equipe de validação recebeu fonte e minificado congelados para a matriz final e os testes direcionados do arquivo servido. Seus resultados consolidados complementam esta nota. Todos os cenários locais usam DOM e provedor simulados; **zero requisições publicitárias reais**. Não representam validação visual em navegador, faturamento, Active View ou métricas de desempenho em campo.

## Integridade da fonte e do minificado

Build utilizado: `node tests/build-runtime-min.js`.

| Artefato | Bytes no arquivo | SHA-256 |
| --- | ---: | --- |
| Fonte | 116.704 | `5e20ac54798f7e230d8603971ce94852430efc4d3937094258efe065c7f4acef` |
| Minificado | 84.960 | `0ef1455326ff3244ddcbc28e5a5454b0b232f2b87d43abb43b07678ed965c4ad` |

## Efeito esperado, riscos e acompanhamento

A consequência técnica demonstrada é que uma reserva segura alcançada deixa de esperar exclusivamente o estado global de expansão. Isso pode aumentar pedidos úteis e impressões monetizadas, mas o ganho depende de alcance, preenchimento, valor marginal das impressões e continuidade das sessões. O número de pedidos, sozinho, não demonstra receita adicional nem garante Page RPM de US$ 4.

O principal risco econômico é abrir oportunidades cujo valor marginal não compense um eventual efeito sobre leitura e navegação. O principal risco de antecipação é o leitor mudar de direção ou abandonar a página depois da previsão. Os limites de exposição, distância, densidade e capacidade reduzem esses casos; não eliminam a necessidade de acompanhar dados reais.

Usar o diagnóstico para confirmar quantas admissões `reached-reserve` acontecem, sua distância no pedido, chegada/resposta e bloqueios restantes. Conciliar depois receita diária total, receita por sessão compatível, impressões por página, cobertura, Active View com sua mensurabilidade, continuidade da audiência e Core Web Vitals. Na versão única, comparações antes/depois exigem controles de tráfego, temas, dispositivos e dias da semana; não constituem atribuição causal automática.

Reversão operacional disponível: reinstalar o ZIP anterior preservado e limpar os caches correspondentes de tema/CDN, caso a revisão em produção identifique regressão material. Não há interface de grupos nem configuração experimental a administrar.
