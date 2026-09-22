# Revisão independente — versão única 5.1.1

**Resultado:** a transição da 5.1.0 para a 5.1.1 conserva o loader e os controles necessários à distribuição manual, âncora e vinheta; transforma a admissão de reservas alcançadas em regra normal; elimina o mecanismo de divisão de público; e aplica a migração de frequência autorizada sem sobrescrever as exceções explícitas examinadas. Não encontrei defeito bloqueante nos caminhos finais revisados.

Revisão estática independente de `ready/work`, após congelamento de PHP, composer e runtime. Runtime final: `12.3.0-unified-manual`; versão declarada do tema: `5.1.1`. Não editei arquivos do tema, não alterei a conta e não fiz implantação. Reaproveitei os verificadores executados na validação central e examinei seus casos e resultados; os testes de software não solicitam anúncios reais.

## 1. “Sem experimentos” verificado

A inspeção final confirmou:

- `inc/ads.php` deixou de importar o módulo experimental.
- `loader.php` voltou ao loader canônico, com o caminho opcional de consentimento, sem seleção de canal ou braço.
- `consent.php` não depende mais de configuração experimental para manter o leitor necessário ao Top Scroll/hard gate.
- Fonte e minificado do runtime não chamam `GOAdsExperiment`, `applyYield`, `manualOptions` ou `revalidateOptions`; não emitem diagnóstico de braço.
- O hook de hubs não consulta constante/filtro experimental.
- Os três arquivos específicos da infraestrutura retirada estão ausentes: `inc/ads/experiment.php`, `assets/js/go-ads-experiment.js` e `tests/test-experiment-config.php`.

A varredura final dos entrypoints e ativos relevantes não encontrou `GOAdsExperiment`, `go_verge_ads_experiment`, `go_ads_experiment_v1`, `go_adexp_`, `HUB_HERO_EXPERIMENT`, `hub_hero_experiment` ou `data-ad-channel`. As opções antigas eventualmente existentes no WordPress não têm consumidor nessa cadeia. Não é necessário apagar histórico do banco para impedir a aplicação dos grupos antigos.

Houve uma inconsistência de empacotamento durante a revisão: os entrypoints já não utilizavam A/B, mas os três arquivos órfãos permaneciam fisicamente. A exclusão foi concluída no contexto responsável pelo pacote e posteriormente confirmada também nesta revisão. O registro `ready/validation/root-removal-check.json` documenta ausência e aprovação do verificador estático. A checagem final do ZIP deve conservar essa ausência.

## 2. Loader e consentimento preservados

`inc/ads/loader.php` conserva um script assíncrono oficial com o publisher `ca-pub-3687004010207904`, `crossorigin="anonymous"` e proteção contra emissão repetida pelo tema. O filtro do Site Kit permanece para evitar a segunda tag quando o tema é responsável pelo loader; a integração de relatórios não foi removida.

O gate adicional do tema continua opcional e desligado por padrão. Quando explicitamente ativo, o caminho JavaScript espera a permissão, aceita os eventos de atualização e cria somente uma tag. A remoção da infraestrutura A/B não introduziu a necessidade de consentimento para medição antes de liberar todos os anúncios normais.

No runtime, `allowed(rec)` continua sendo `!rec.options.gate || permission()`. A função de permissão é usada separadamente para persistir histórico de frequência, sessão local e memória de latência. Portanto, quando não existe permissão local de armazenamento e o gate adicional não está ativo, o motor normal pode trabalhar com as informações do documento atual. Isso preserva a responsabilidade da CMP e do Google por seus próprios sinais; não significa inventar uma autorização do usuário.

Não conferi novamente os controles autenticados da conta. Preservar o loader possibilita âncora/vinheta, mas não demonstra que suas opções estejam ligadas no painel. A versão não muda nem substitui os formatos oficiais.

## 3. Reserva alcançada agora é política normal e mantém os controles de entrega

O contrato de `yield.php` declara `reserve_admission='reached'`. O runtime aplica a política diretamente, inclusive se houver um valor antigo `governor` em metadado recebido: não depende de grupo, canal, bootstrap separado, armazenamento ou visita anterior.

`bodyBudget()` ainda abre o orçamento inicial e permite antecipação mais ampla quando o governador entra em expansão. Quando esse orçamento está ocupado, `reachedReserveAllows()` pode admitir outra posição já renderizada e estruturalmente válida. A função exige plano real com pelo menos uma posição de corpo e limita a ocupação ao menor valor entre posições renderizadas e capacidade estrutural. Metadado incoerente com `plannedBodyCount=0` não abre inventário.

A posição precisa estar na viewport útil ou ter chegada iminente compatível com a latência estimada. Para antecipação, há limite de meia viewport útil, probabilidade local de alcance elevada e restrição contra rolagem rápida. Essa etapa só libera o orçamento; a unidade continua passando por exposição, densidade, ritmo, host visível, largura, formato elegível, frequência quando aplicável e deduplicação. Uma unidade que falha nas condições permanece pendente ou inelegível conforme o motivo.

As guardas `requested`, `closed`, conexão ao documento e `slotOwners` permanecem no caminho de solicitação. Uma resposta silenciosa pode liberar participação no orçamento após o prazo existente; isso não apaga o fato de o próprio slot já ter sido solicitado nem autoriza novo push. `unfilled`, `unfill-optimized` e `filled` continuam com significados distintos. A memória de latência considera preenchimentos observados em primeiro plano, sem transformar no-fill rápido em estimativa otimista de criativo.

**Limite econômico:** liberar uma oportunidade realmente alcançada pode recuperar entrega útil, mas o código não mede lance nem assegura que essa oportunidade será preenchida ou terá contribuição positiva suficiente para elevar o RPM à meta.

## 4. Hub em fluxo e na fronteira correta

O handler `go_verge_ads_render_editorial_hub_hero_unit()` agora é uma integração normal. Ele rejeita AJAX, IDs de Hero vazios, argumento de página diferente de 1, `paged/page` efetivos maiores que 1 e paginação posterior do desk.

Essa última verificação é relevante: o template de desk pode manter o Hero visível e passar 1 ao hook mesmo quando o feed está em página posterior. Consultar a paginação efetiva impede gastar novamente a posição após Hero nesse cenário.

A chamada acontece depois do fechamento do bloco Hero, no fluxo do documento, sem cobrir a imagem. Usa o mesmo pool F1–F5 e o mesmo marcador de Hero das listagens; não cria um novo conjunto de IDs nem solicita novamente uma unidade já consumida. O slot específico `game-hub-mid` continua no seu template de jogo, separado da integração editorial de listagens. GOAC/Ads Center e relatórios úteis permanecem presentes.

## 5. Top Scroll: migração, precedência e limitações

O padrão é até seis preenchimentos sinalizados pelo provedor em janela local móvel de 24 horas, com quatro sem o gate adicional de engajamento. A quinta oportunidade exige três páginas na sessão local ou 60 segundos acumulados em aba ativa; a sexta exige quatro páginas ou 120 segundos. O tempo pausa em segundo plano. O mecanismo não mede atenção humana, e páginas acumuladas não comprovam leitura profunda.

A migração nova usa `go_verge_topscroll_ready_20260921_v1`, independente do marcador anterior. Ela muda somente opções salvas 3/4 de unidade habilitada sem override. Preserva campos adicionais, unidade desabilitada, zero, demais valores, default customizado, constantes e filtros registrados. O marcador é registrado também nas exceções: remover posteriormente um override ou reativar a unidade não dispara uma migração atrasada que sobrescreva a preferência preservada.

A precedência examinada é: `GO_VERGE_ADSENSE_TOPSCROLL_FREQUENCY_LIMIT`; depois a constante histórica `...FREQUENCY_MAX`; depois opção/default; finalmente filtros, dentro da faixa validada. A interface administrativa identifica tanto a constante atual quanto a histórica e deixa o campo somente de leitura nos dois casos. Assim, o valor mostrado não convida o operador a salvar uma alteração que o código ignoraria.

**Limites que permanecem:** sem armazenamento autorizado/utilizável, não existe histórico persistente confiável entre navegações. A gravação local não constitui quota absoluta por pessoa, dispositivo ou conjunto de abas simultâneas. O contador usa o sinal `filled`, não receita confirmada. A 5.1.1 não promete uma sexta impressão para todo visitante e não atualiza artificialmente o anúncio da página atual.

**Reversão:** a migração grava uma opção WordPress. Reinstalar o ZIP anterior não desfaz essa gravação; para voltar ao valor anterior, restaure a opção ou ajuste o controle administrativo correspondente. O marcador evita que uma preferência posterior seja novamente forçada a seis.

## 6. Validação reutilizada e limites de observação

Os registros de validação central cobrem os caminhos revisados:

| Área | Evidência relevante |
|---|---|
| Política única e reservas | 15 cenários do runtime, em fonte e minificado; inclui mobile/desktop, ausência de storage/bootstrap, flag antiga ignorada, capacidade inválida, densidade, consentimento e aba oculta |
| Migração e interface Top Scroll | 72 asserções principais e 6 de default customizado; constantes, filtros, zero, disabled, idempotência, marcador anterior e interface readonly para constantes |
| Loader | 17 asserções PHP e 8 cenários JavaScript do gate real emitido pelo PHP; nenhuma carga publicitária real |
| Listagens/hubs | 18 cenários, 216 asserções de pool, Hero, páginas posteriores e fronteiras |
| Regressões | 9 cenários específicos em fonte e minificado; continuidade F4/F5 e deduplicação incluídas nas suítes |
| Build | Minificado reconstruído byte a byte igual ao servido no pacote |

O resumo consolidado em `ready/validation/release-validation-final.json` informa **33 suítes aprovadas após a correção dirigida**, 257 arquivos PHP sem erro de sintaxe e zero requisições publicitárias reais. A primeira corrida detectou os arquivos órfãos; a correção foi seguida de 109 asserções estáticas aprovadas e da nova validação administrativa, sem tratar o resultado inicial como aprovação. Não reexecutei toda a matriz para inflar contagens.

Não houve observação de criativos reais, novo acesso à conta, mensuração de receita pós-implantação ou teste visual em navegador real nesta revisão. Os simuladores validam encadeamento e estados; não comprovam Active View, Core Web Vitals de campo ou ganho financeiro. O acompanhamento da versão única deve usar os relatórios normais, com receita e denominadores conciliados, sem atribuir automaticamente toda variação posterior ao código.

## Decisão final

**Manter as mudanças da versão única.** A regra de reservas alcançadas e o Hero das listagens estão integrados ao funcionamento normal; loader e consentimento permanecem independentes de A/B; migração e interface respeitam os overrides examinados. **Manter a conferência de cache/versão na instalação** e o acompanhamento financeiro usual. Nenhuma divisão de visitantes ou criação de canais é requisito desta versão, e nenhuma implantação ou mudança de conta foi executada por esta revisão.
