# 5.5.1 — auditoria do motor manual

Tema 5.5.1; runtime `12.6.1-manual-baseline`. Continua a arquitetura de 5.5.0:
anúncios manuais nas páginas mais âncora e vinheta oficiais da conta. Nenhuma
opção, constante, filtro ou seletor da conta Google foi alterado, e nenhuma
unidade nova foi criada.

## 1. Identidade de listagem consumida e descartada

`go_verge_ads_render_listing_continuation()` aceitava apenas F4/F5 e usava
`break` para qualquer outro rank. Mas `go_verge_ads_listing_pool_next()` avança
o cursor em toda chamada: o rank recusado já tinha saído do pool e não era
renderizado em lugar nenhum.

O efeito aparecia em qualquer feed cuja primeira página gastasse menos de três
ranks — todo hub ou arquivo sem unidade pós-hero, e todo hub a partir da página
2. Nesses documentos F3 era destruído, a linha agendada dele ficava vazia, e
F4/F5 desciam das linhas 11/15 para 15/19. Reprodução antes da correção, em hub
com 10 linhas e agenda 3/7/11/15/19:

    inline      : F1 (linha 3), F2 (linha 7)
    escrow      : F4 (linha 15), F5 (linha 19)
    cursor      : 5 de 5
    nunca usado : F3

Depois: F3 (linha 11), F4 (linha 15), F5 (linha 19). O que o pool ainda tem no
rodapé está, por definição, sem dono — a reivindicação de slot por resposta do
renderer e o cursor já garantem um host por identidade por documento.

Isso recupera uma oportunidade de listagem por pageview afetado e devolve às
outras duas as linhas mais rasas da agenda. Não é uma promessa de impressão: o
preenchimento continua sendo do Google, e o runtime ainda aplica consentimento,
geometria, densidade e a regra de um pedido por posição.

## 2. Exposição local medida como o formato publicado define

O relógio local de exposição exigia 50% dos pixels para todo formato. O padrão
de display do Google é 50% por 1 segundo contínuo, e 30% por 1 segundo quando o
criativo é grande — 242.500 px² ou mais, marca que um masthead 970x250 atinge
exatamente. Medir tudo a 50% subestimava justamente as unidades a partir das
quais o operador tenderia a reajustar antecipação.

O relógio também lia `intersectionRatio` cru, contra a viewport inteira,
inclusive a faixa coberta por uma âncora da conta exibida. A entrega já havia
sido corrigida para isso em 12.x e roda sobre `usableViewportHeight()`; o
relógio não. Um criativo atrás da âncora acumulava exposição local que o leitor
não teve.

As duas continuam observações locais do DOM. Não são Active View, impressão
oficial nem receita, e nada no caminho de entrega lê esses campos.
`inspect()` passa a informar `requiredRatio`, `largeCreative` e
`maxVisibleShare`; `maxIntersectionRatio` permanece como apelido, porque
ferramentas do operador já leem essa chave.

## 3. Aquecimento da origem do criativo no primeiro pedido

`inc/ads/assets.php` faz preconnect de `pagead2.googlesyndication.com` e
`googleads.g.doubleclick.net` e deixa `tpc.googlesyndication.com` apenas com
dns-prefetch, para que um terceiro handshake especulativo no `<head>` não dispute
sockets e CPU com o recurso de LCP. Esse argumento vale enquanto ninguém precisa
da conexão.

Quando a primeira posição chega perto o bastante para pedir, o recurso de LCP já
foi buscado: ali o handshake é barato e se sobrepõe ao próprio round trip do
pedido. O que ele compra é pintura mais cedo do criativo, que é a única alavanca
do publisher sobre quanto da janela de um segundo um criativo servido passa de
fato na tela. Credenciado, como a navegação em iframe que vai usá-lo —
navegadores mantêm pools separados para sockets anônimos e credenciados.

É uma dica de conexão: não busca nada, não pede anúncio e não cria impressão.
Falha ao inserir não vira erro de entrega. `inspect().evolution` reporta
`creativeOriginWarmed`.

## Testes

`tests/runtime-viewability-proxy.test.js` é novo e cobre o relógio de exposição
e o aquecimento; o harness compartilhado não fornece `IntersectionObserver`, de
modo que esse caminho não tinha cobertura alguma. Ele fornece um duplo mínimo e
dirige o relógio sobre o arquivo de runtime de produção, sem rede e sem pedido
de anúncio.

`tests/test-listing-continuation.php` passa a exigir que os hosts recuperados
ocupem as primeiras linhas futuras da agenda, sem pular nenhuma — a invariante
que o filtro F4/F5 quebrava. Os cenários `hub-no-hero`, `hub-zero-ids`,
`hub-page-two`, `hub-desk-page-two` e `hub-query-page-two` mudaram de
`[15, 19]` para `[11, 15, 19]`.

Suíte completa verde: `php tests/run.php`.

## O que não foi verificado

Nenhum teste aqui prova receita maior, preenchimento real, Active View de campo
ou Core Web Vitals. Nada foi implantado por esta auditoria. Comparações
antes/depois sofrem influência de tráfego e demanda; compare dias fechados e
horários equivalentes, mantendo a mesma configuração de produção.

## Instalação e rollback

Como em 5.5.0. Substituir o tema pela versão 5.5.1, abrir uma página
administrativa como administrador, invalidar cache de página, LiteSpeed/CDN e
assets, e confirmar tema 5.5.1 com
`GOAdsRuntime.inspect().version === '12.6.1-manual-baseline'` em uma página
elegível. O rollback é reinstalar o ZIP anterior e invalidar as mesmas camadas;
nenhuma opção, ID, credencial, relatório GOAC ou escolha de consentimento é
tocada por esta versão.
