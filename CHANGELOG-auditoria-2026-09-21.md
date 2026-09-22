# Correções locais da auditoria de 21/09/2026

Base: tema 5.0.3 do ZIP news-magazine-x (37)(1).zip, SHA-256 0720c3125edd42c3b37fec831fc3fb633fa8e1ada34aa97941401152c8c79c75.

## Comportamento corrigido

- O pool de listagens tenta outra unidade válida na mesma oportunidade se encontrar uma unidade desabilitada, com contexto incompatível ou ID já usado. Mantém pool finito, contexto, deduplicação e no máximo uma unidade por host.
- Runtime 12.1.1-audit-lifecycle: reserva da âncora reconhecida é revalidada a cada varredura; a viewport útil participa do cálculo de alcance/prioridade.
- A mudança tardia de consentimento relê o prior quando permitido, deixa de usar o prior após revogação e abre a sessão do Top Scroll sem uma nova solicitação. O tempo da sessão não retroage à autorização.
- Pagehide/pageshow pausam/retomam relógios e atualizam checkpoints após BFcache. Longa inatividade revalida a sessão da aba; o mesmo documento não é contado de novo no checkpoint local.
- Agregação de Active View em economics e GOAC usa peso reconstruído de impressões mensuráveis quando os dados são válidos. Relata a reconstrução, preserva ausência de dados e muda o cache do modelo de slots para v2.
- O espelho administrativo inclui âncora e vinheta individualmente. A verificação de saúde deixa pendente um registro incompleto e esclarece que não é consulta ao vivo da configuração Google.
- README e comentários deixam de alegar zero histórico dos antigos A1–A3, corrigem limiares efetivos e registram o teto três visto no HTML público.

## Instrumentação opcional

O objeto GOAdsYieldConfig pode receber diagnostics.gate_timings=true antes do runtime. A inspeção local registra entradas, checks, tempo em primeiro plano e checks em viewport por gate; sem rede ou PII. Padrão desligado. nearMax é indicado como inerte; o patch não o transforma em controle de entrega. providerPresent pode incluir fallback otimizado, sem representar anúncios pagos.

## O que esta versão não determina

Não ativa experimento nem muda IDs, formato, espaçamento, densidade, frequência ou loader. O default seis e a migração quatro→seis já existem na base. A captura pública tinha três, cuja origem precisa ser conciliada com opções/constantes/filtros/cache. A troca de arquivos não reverte opções persistidas. Nenhuma alteração de conta/publicação foi executada.

## Validação realizada

Baseline original 23/23 suítes. Patch: 19/19 PHP; 14/14 verificações SQL Python; nove casos dirigidos de runtime na fonte e no min; sete suítes JS anteriores passam (44.059 checks nesta execução); 253/253 PHP com sintaxe válida. Fonte/min compilados e equivalentes. Testes novos também expõem falhas no original em cópia descartável.

PHP local 8.3.6; produção exportada 8.5.4. SQL executado em SQLite local, não no MySQL de produção. Não houve navegador real: Chromium indisponível e download expirado. Não houve solicitação publicitária real. Simulação valida lógica, não ganho financeiro, criativo real, Active View ou CWV de campo.

## Reprodução e reversão

Na pasta do tema, com PHP e Node disponíveis:

```sh
node tests/build-runtime-min.js
php tests/run.php
python3 tests/test-active-view-sql.py
GO_RUNTIME_SOURCE="$PWD/assets/js/go-ads-runtime.min.js" node tests/runtime-audit-regressions.test.js
```

Para reversão, restaurar o ZIP original e os caches relevantes; restaurar também as opções alteradas se houver uma mudança de configuração separada. Fonte e minificado devem voltar juntos. O tema original foi preservado.
