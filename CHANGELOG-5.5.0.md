# Changelog 5.5.0 — reset e motor manual

Base preservada: tema completo 5.4.1 já entregue. Esta versão incorpora também a correção de Masthead e o diagnóstico revisado preparados na sequência, sem exigir instalar outro ZIP. Runtime: **12.6.0-manual-baseline**. Uma política de produção, sem experimento nem ajuste de volume por RPM.

## Arquivos de produção

| Arquivo | Alteração |
|---|---|
| `inc/ads/mode.php` | Contrato manual fixo; opções/constantes/filtros legados de arquitetura não selecionam outro motor; remove seletor/rota de alternância; migração administrativa com backup, histórico, validação de gravação e purge compartilhado |
| `inc/ads/config.php` | Reafirma manual/âncora/vinheta após filtros, in-page/side rails automáticos off como intenção de conta; aplica máximo de viewport do Masthead para os tipos editoriais solicitados |
| `inc/ads/context.php` | Predicate de review, crítica e especial no contexto do Masthead |
| `inc/ads/renderer.php` | Combina limite de viewport com demais media queries; remove reserva inicial desktop sem esconder anúncio já solicitado em largura menor |
| `inc/ads/composer.php` | Reivindicação em ordem editorial e contagem dos hosts realmente emitidos; metadados coerentes, recusas separadas no log, offsets preservados |
| `inc/ads/planner.php` | Apenas comentários: remove estimativas financeiras sem fonte e números desatualizados; tokens executáveis preservados |
| `assets/js/go-ads-runtime.js` | Corrige cobertura duplicada na prioridade; baseline de ritmo/expansão/antecipação independente de RPM; remove fetch financeiro; modelo histórico com validade; reserva alcançada aceita com zero primárias e capacidade segura restante |
| `assets/js/go-ads-runtime.min.js` | Gerado pelo build canônico a partir da fonte final |
| `inc/ads/yield.php` | Exporta política fixa e priors históricos; não lê intraday/totais do dia na emissão pública; endpoint compatível permanece; regimes financeiros administrativos rotulados como não aplicados à entrega; cache analítico v12 |
| `inc/ads/economics.php` | Documentação precisa de receita por solicitação e indicadores analíticos; preserva cálculo e integração GOAC |
| `inc/ads/topscroll.php` | Reset local ligado/6, imediato em memória; getter sem gravação; migração administrativa única e atômica no marcador, backup bruto, detecção de overrides inclusive prioridade zero, campos extras preservados |
| `inc/ads/topscroll-admin.php` | UI alinhada ao contrato manual; fonte efetiva de frequência e exceções visíveis |
| `inc/ads/dashboard.php` | Diagnóstico financeiro separado da política de entrega; índices legados identificados como analíticos |
| `inc/ads/health.php` | Contrato manual único; conferência do registro de side rails; pendência não bloqueia entrega |
| `inc/ads.php` | Documentação da arquitetura fixa, preservando bootstrap e integrações |
| `inc/ads-center/includes/class-goac-plugin.php` | Permite registrar side rails no espelho manual de controles; nenhuma alteração da conta Google |
| `inc/ads-center/includes/class-goac-view-delivery.php` | Remove alternância de motor e apresenta contrato/manual e diagnóstico coerentes |
| `inc/ads-center/includes/class-goac-view-optimization.php` | Registro de conta alinhado e campo side rails; relatórios preservados |
| `assets/js/go-ads-recovery-diagnostics.js` | Classifica antes/dentro/depois dos parágrafos; deduplica marcadores e mantém status separado de receita; execução administrativa sob demanda |
| `functions.php`, `style.css` | Identificação pública 5.5.0 |

## Testes

Novos: composer com recusas/IDs/reservas; política financeira fixa; migração manual; espelho side rails via handler real; reset administrativo Top Scroll; runtime baseline; Masthead editorial; diagnóstico de posição da prosa. Ampliação dos testes Top Scroll para janela móvel, outra aba, permissão de armazenamento e ausência de contabilização de nofill. Suítes antigas foram atualizadas para o contrato vigente, preservando guardas de entrega e consentimento.

Consulte `VALIDACAO-5.5.0.md` para a rodada final, contagens e limitações. Fonte/minificado, loader/consent e pacote foram conferidos separadamente. Nenhum teste carregou publicidade real.

## Preservado

IDs e formatos; loader oficial e consentimento; integrações GOAC e histórico; sem refresh; geometria/densidade; memória local autorizada de latência; F4/F5 e continuação; correções de conteúdo/publicação/sitemaps; feeds de vídeo em cache fora da resposta pública; CTA Games com jogos grátis/promoções e CTA Tecnologia contextual.

## Migração e rollback

- Modo: backup `go_verge_ads_manual_architecture_backup_v1`; marcador `go_verge_ads_manual_architecture_v1`.
- Top Scroll: backup `go_verge_topscroll_manual_baseline_backup_v1`; marcador `go_verge_topscroll_manual_baseline_v1`.
- O reset não apaga frequência/visitas/consentimento no navegador.
- Reinstalar arquivos antigos não desfaz a opção. Para rollback exato, preferir snapshot de arquivos e banco anterior; a versão antiga também pode ter sua própria migração de frequência. Consultar o guia antes de restaurar valores individualmente.

**Escopo econômico:** remoção de falhas/complexidade demonstrada, sem percentuais de ganho garantidos. A política fixa retira tanto freios quanto acelerações financeiras do motor anterior. Não foi executada implantação, mudança de conta, leilão real ou medição de receita da versão.
