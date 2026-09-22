> Histórico da versão anterior. A distribuição para uso é a 5.1.1; sua política única substitui os ensaios descritos abaixo. Consulte LEIA-ME-MOTOR-DE-ANUNCIOS.md.

# 5.1.0 | Eficiência do motor manual

Candidata local preparada em 21/09/2026 sobre a primeira entrega auditada do tema 5.0.3. Não implantada. Runtime 12.2.0-reached-delivery; bootstrap experimental 1.1.0.

## Execução

- Priorização pela geometria atual da varredura.
- Memória de latência de preenchimentos em primeiro plano, consentida, isolada por perfil e com expiração de 30 min.
- Manifesto inerte F4/F5 para continuidade do feed inicial quando cards reais são acrescentados; endpoint AJAX continua sem anúncios e o pool não reinicia.
- Scan de fragmentos com opções JSON canônicas; scripts do manifesto não são executados; deduplicação por documento preservada.
- Diagnóstico técnico local amostrado, sem envio automático de dados.

## Controle econômico

- Revisão negativa de receita preservada como dado não acionável, em vez de preço zero.
- Janelas revisadas excluídas das referências; dados stale/revisados produzem sinal neutro de timing/supply, mantendo o planejamento base.
- Cache do estado econômico versionado para não reutilizar estado anterior à correção.

## Experimentos desligados por padrão

- Aparência → Experimento de anúncios: canais, datas, identificador e variável exclusiva.
- Corpo: governador versus reserva já alcançada/iminente, preservando teto e densidade.
- Top Scroll: controle 4 versus até 6 com os critérios existentes, sem gravar a opção normal.
- Canal no INS antes de push e no loader oficial antes de carregar; documento excluído se o provider já existir ou permissão/atribuição faltar.
- Matrícula estável entre abas via Web Locks; primeira navegação fica fora do ensaio. Isso não é um lock da quota de preenchimentos Top Scroll.
- Contador GA4 opcional por documento, somente com marketing/statistics/gtag prévios, sem carregar Analytics novo. Diagnóstico distingue queued de recebimento confirmado.
- Revalidação das opções pendentes em revogação/término; criativos já solicitados permanecem intocados.
- Hook pós-hero de hubs preparado e desligado por padrão.

## Preservação e limites

Mantidos os anúncios manuais atuais, IDs, âncora e vinheta oficiais, loader único, ausência de refresh e todas as correções da auditoria anterior. Não houve reativação de IDs arquivados nem Auto Ads in-page.

O teto global do corpo e as regras gerais de densidade não foram elevados. O modo reached é um ensaio, não uma mudança para toda a audiência. Dados locais de exposição não são Active View ou receita. Ganho exige relatório financeiro e denominadores comparáveis.

Rollback: desabilitar ensaios e invalidar os caches relevantes; para o pacote, restaurar a versão anterior e registrar também opções persistidas. Abas abertas preservam seu contrato até término/consentimento/navegação; não há rollback remoto retroativo de um anúncio já solicitado.
