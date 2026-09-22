# Overdrive 5.5.3: recuperação da inicialização dos anúncios manuais

## Escopo

Correção aplicada exclusivamente ao tema recebido em `ultimo.zip`, versão 5.5.2.
Base SHA-256: `52d8e4b68f8ff49dddf12f753744068a5d64a6f31192d503f01a167e051dc624`.

O objetivo desta atualização é recuperar a inicialização dos anúncios manuais quando o motor não fica disponível na página. O modo continua `manual_overlays`. Inventário, IDs de unidades, planner, renderer, motor de decisões, CSS e layout editorial foram preservados byte a byte em relação ao ZIP recebido.

## Evidência e defeito corrigido

A captura fornecida apresenta sete hosts manuais no corpo, 47 parágrafos editoriais, um script AdSense e a mensagem “Motor manual não carregado nesta página”. Os contadores manuais aparecem como `—`.

No código original, `inc/ads/renderer.php` coloca os elementos `ins.adsbygoogle` em `template[data-go-ad-pending]`. Cada posição só aguarda o evento `go:ads-runtime-ready` quando a API não existe. O único carregamento do motor era feito por `inc/ads/assets.php` no hook `wp_head`, prioridade 4. Se essa inicialização não ocorresse, não existia outro caminho para carregar o motor e montar os hosts.

A falha foi reproduzida em laboratório: sem executar o bootstrap do cabeçalho, os hosts continuaram inertes após DOMContentLoaded e dez segundos simulados, com zero solicitações. O código original das três variantes do motor inicializou normalmente nos testes de parsing HTML5. Portanto, não foi demonstrada uma falha intrínseca de sintaxe ou de ausência de document.body no motor.

A captura não identifica por que a inicialização original deixou de ocorrer naquela navegação. Ela não permite atribuir esse gatilho a um plugin, cache, CSP ou ao Google. Esta atualização corrige a dependência sem recuperação demonstrada no tema.

## Alteração de entrega

`inc/ads/assets.php` passa a emitir um bootstrap independente no rodapé, prioridade 1. Ele verifica a API e os hosts que realmente chegaram ao documento.

- Com o motor já inicializado, termina sem baixar outro runtime.
- Com hosts manuais e API ausente, tenta carregar uma vez o código fonte local do mesmo motor. A URL inclui versão do tema e hash do conteúdo.
- Reutiliza a configuração exata do cabeçalho. Se ela não foi emitida, usa a política produzida pelo próprio PHP.
- Delega montagem, consentimento, geometria, frequência e solicitação ao motor existente. A recuperação não executa push no AdSense e não adiciona o loader do Google.
- A API e os registros de montagem existentes impedem duplicidade quando a inicialização atrasada do cabeçalho encontra a recuperação.
- Uma falha de carregamento fica identificada em GOAdsRuntimeBoot; não inicia ciclos de tentativas.

O runtime de entrega permanece `12.7.0-context-paint-gate`. A versão do tema passa a `5.5.3`, permitindo identificar a instalação e acionar a rotina de invalidação de cache já existente no tema.

## Diagnóstico

O painel agora informa “Motor manual”, “Script do motor no HTML”, “Recuperação do motor”, “Hosts manuais no documento” e “Hosts ainda em template”. O JSON inclui `articleStructure.manualStartup`.

A presença da tag de script é separada da disponibilidade da API. Template pendente não é classificado como no-fill. O painel permanece somente de leitura e não dispara a recuperação.

## Validação

- 17 cenários de integração da recuperação: todos passaram.
- 22 cenários do diagnóstico: todos passaram.
- 14 suítes de referência de entrega: todas passaram.
- Revalidação final de contrato de modo, loader único e integridade estática: sem falhas. A suíte de loader teve 17 asserções aprovadas; a de integridade, 169.
- Sintaxe PHP dos arquivos verificados e sintaxe JavaScript do diagnóstico: sem erros.

A integração usa o PHP, a configuração, o renderer e os runtimes reais deste pacote, com parsing HTML5 e templates no jsdom. Geometria, relógio e respostas do provedor são simulados. Os testes cobrem inicialização ausente, variantes fonte/min/lean, configuração ausente, múltiplos hosts, leitura até a próxima posição, corridas de inicialização, consentimento, restrições de dispositivo, erro de download, hosts adicionados depois e chave global desligada.

Não houve solicitações reais de anúncios. Estes resultados comprovam a recuperação da inicialização e o encaminhamento dos pedidos nos cenários testados; preenchimento, impressões pagas e receita precisam ser observados na navegação publicada.

## Instalação e conferência

1. No WordPress, abra Aparência → Temas → Adicionar novo → Enviar tema e envie o ZIP desta versão, substituindo o tema existente.
2. Limpe o cache de página e o CDN usado pelo site, para que o HTML passe a carregar a versão 5.5.3.
3. Abra uma matéria e consulte “Anúncios: diagnóstico”. Confirme versão 5.5.3, modo manual_overlays e “Motor manual: inicializado”.
4. Os contadores “Montados” e “Solicitados” devem ser numéricos. Role a matéria para observar as posições elegíveis. Consulte o estado de cada unidade para distinguir espera, solicitação, resposta filled e unfilled.

Se o caminho normal funcionar, a recuperação aparece como `not-needed-or-not-started`. Quando usada com sucesso, aparece como `ready`. Em erro, o JSON registra o estágio: `runtime-load-failed`, `runtime-did-not-initialize`, `runtime-api-incomplete` ou `runtime-append-failed`.

## Reexecutar os testes adicionados

Com PHP, Node.js e jsdom instalados:

```bash
node tests/manual-startup.test.cjs
node tests/diagnostics-position-review.cjs
```

Use `GO_TEST_PHP` para informar outro executável PHP e `GO_JSDOM_MODULE` para informar o caminho do módulo jsdom. A integração aceita `GO_TEST_REPORT` para gravar o relatório JSON. Os relatórios desta execução estão em `docs/validacao-5.5.3/`.
