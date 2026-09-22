# Validação da 5.4.2

Base preservada: 5.4.1. Sem deploy, mudanças de conta ou requisições publicitárias em testes.

| Verificação executada | Resultado |
|---|---:|
| Contrato PHP do Masthead | 222/222, 17 cenários |
| Runtime com configuração emitida pelo PHP | 14/14 no fonte e 14/14 no minificado |
| Modos de entrega | 455/455 |
| Formatos manuais | 90/90 |
| Composer | 19/19 |
| Diagnóstico administrativo | 20/20 cenários |
| Integridade estática após versão 5.4.2 | 109/109 |
| Lint dos seis PHP modificados | Sem erro |

Cobertura: desktop/mobile/tablet e limites 1100/1101, breakpoint filtrado 1281, tipos editoriais explícitos/legados e especiais de pacote, consentimento tardio, unfilled, resposta silenciosa, resize e deduplicação. Diagnóstico: antes/entre/depois da prosa, auxiliares, P aninhados, estados separados, totais anteriores à amostra e nenhuma mutação/requisição durante a coleta.

O contrato novo do Masthead falhou em 36 asserções contra a base e passou depois da alteração. O coletor antigo passou os nove cenários legados e falhou nos 11 comportamentos novos; o coletor final passou os 20. Os testes são offline, com geometria simulada. Não medem receita, Active View ou Core Web Vitals. A matriz completa da 5.4.0 é histórica e não foi contada como nova execução nesta atualização.

## Reproduzir

Na pasta do tema, com PHP CLI disponível:

```sh
php tests/test-masthead-editorial.php
php tests/test-delivery-mode.php
php tests/test-manual-formats.php
php tests/test-composer.php
php tests/static-integrity.php
node tests/runtime-masthead-editorial.test.js
```

O teste de runtime aceita `GO_TEST_PHP` quando o binário não se chama `php`; consulte o cabeçalho do teste para selecionar fonte ou minificado. O runner `php tests/run.php` inclui os novos testes de Masthead e mantém a matriz existente.

Com jsdom disponível para o Node, executar separadamente:

```sh
node tests/diagnostics-position-review.cjs
```

Essa suíte aceita `GO_JSDOM_MODULE` e `GO_DIAGNOSTICS_SOURCE`. Dependências de laboratório não foram colocadas no tema nem são necessárias ao WordPress.

## Inspeção ao vivo separada

Em 21/09 foi possível ler o DOM e estilos computados de uma aba já existente, sem recarregar, rolar ou disparar anúncios. Uma raiz real tinha 68 P diretos, 740 px de largura, overflow visível e contain none. Novas consultas HTTP de duas matérias receberam 403 Bot Verification; home e style.css responderam 200. O bloqueio é comprovado para aquele cliente, não para Googlebot/Mediapartners-Google. Nenhuma conclusão de recuperação do Auto Ads ou do Discover foi produzida.
