# Overdrive 5.7.0: plano de monetização (viewability-first)

Metas: **Active View entre 50% e 70%**, **RPM de impressão acima de 0,50** e **RPM de página acima de 4**.

## Como as três metas se ligam

- **RPM de página = RPM de impressão × impressões por página.** Com RPM de impressão de 0,50, são precisas 8 impressões por página para chegar a 4. Com 0,59 (a melhor semana registrada no próprio tema, 13–19/08), bastam 6,8.
- **O RPM de impressão depende do Active View.** As campanhas de CPM do Google Ads compram impressão *visível* (vCPM). Uma impressão servida e nunca vista quase não paga nada, mas entra no denominador do RPM de impressão e do Active View. O Google também prevê a viewability de cada unidade pelo histórico dela e ajusta os lances. Uma unidade com muita impressão não vista passa a receber lances menores até nas impressões que o leitor vê.
- Conclusão: a alavanca não é mais anúncio. É **tirar as impressões que ninguém vê e manter, ou aumentar, as que são vistas**.

## Diagnóstico do motor 5.6.7

1. **Pedidos cedo demais.** Cada unidade pedia o criativo com até 1 tela de antecedência (1,8 tela durante um flick). Todo leitor que parava dentro dessa tela deixava para trás uma impressão servida e não vista.
2. **O leitor que "folheia" não era detectado.** O runtime zera a velocidade 170 ms depois que a rolagem para. Em quem rola uma tela, olha meio segundo e rola de novo, cada pausa liberava pedidos. O criativo chegava cerca de 1 s depois, com o leitor já longe. Na simulação, esse leitor gerava **10 impressões preenchidas e só 2 vistas**.
3. **O Active View por unidade era quase ignorado.** O Ads Center já sincroniza o Active View de 7 dias de cada unidade e o tema já o manda para o navegador. O runtime só mexia ±15% na antecedência.
4. **Artigos longos no teto.** Todo artigo acima de ~760 palavras recebia exatamente P1 + A1–A6 e **nenhuma reserva**. Um guia de 3.600 palavras tinha o mesmo que uma notícia de 760, e um no-fill ali era perdido. A7 e A8 existiam na conta, mas estavam desligados.
5. **Inventário configurado e nunca usado.** F3–F5 ficavam ociosos em todo post. O Multiplex só existia em posts. A unidade de trilho mobile estava configurada para páginas de jogo, mas nunca era renderizada nelas.
6. **Âncora do Clever no mobile.** O próprio `clever.php` documenta que ela redireciona o primeiro clique do leitor para o patrocinador. Esse é o clique que dispararia o **vinheta do AdSense**, o formato mais caro e mais visível. Ela também encurtava a sessão e expunha a conta a risco de política.

## O que mudou na 5.7.0

| # | Mudança | Arquivo | Efeito esperado |
|---|---|---|---|
| 1 | **Antecedência viewability-first.** Mobile: 0,62/0,55/0,48/0,42/0,38 tela por tier (antes 1,00/0,90/0,75/0,60/0,52). Lookahead máximo 1,25 tela (antes 1,8). O leitor que ainda não se mexeu recebe só 0,62 tela preparada. Desktop proporcional. | `inc/ads/config.php` | Menos impressões pedidas para quem não chega. Sobe Active View e RPM de impressão. |
| 2 | **Controlador de Active View por unidade.** Antecedência × (AV da unidade ÷ 62%), com piso em 50%. Unidade dentro da faixa mantém a tabela; acima de 70% ganha +8%. Converge sozinho a cada atualização do modelo (a cada 3 h). Unidade com AV abaixo de 45% não pede durante flick, qualquer que seja o tier. | `assets/js/go-ads-runtime.js`, `inc/ads/yield.php` | Cada unidade é puxada para dentro da faixa de 50–70%. |
| 3 | **Trava de folheio.** Mais de 1,5 tela percorrida em 2,5 s, com pausas incluídas, conta como folheio. Nesse estado nada é pedido à frente do leitor, e o que está na tela só é pedido depois de 0,8 s parado. | runtime | Corta a maior fonte de impressão não vista. |
| 4 | **A7/A8 ligados** (`GO_VERGE_ADS_ARTICLE_MAX_RUNG` 8). | `inc/ads/config.php` | Artigos com mais de 1.200 palavras: de 7,0 para 8,8 posições. Reservas: de 18 para 40 no corpus de teste. Artigos abaixo de ~1.200 palavras ficam idênticos. |
| 5 | **Zona pós-conteúdo com F3/F4** (`after-comments`, `after-article-sections`). | `composer.php`, `article.php` | +2 posições profundas, pedidas só quando o leitor chega. |
| 6 | **Multiplex no fim de toda página** (home, listagens, hubs, busca, jogo, produção, entidade). Uma vez por documento; no post continua na recirculação. | `composer.php`, `config.php` | Um leilão nativo a mais onde não existia nenhum. |
| 7 | **Trilho mobile nas páginas de jogo.** | `single-games.php` | Unidade que estava configurada e nunca era renderizada. |
| 8 | **Clever só no desktop** (`GO_VERGE_CLEVER_MOBILE` passa a `false`). | `inc/ads/clever.php` | Volta o vinheta no primeiro clique. Top Scroll em tamanho cheio no primeiro acesso. Menos JS no celular. |
| 9 | **Teste por calendário.** O teste de antecipação do tier standard foi encerrado, porque antecipava pedidos em dias alternados. No lugar fica um teste pronto e **desligado** que compara a tabela 5.7.0 com a 5.6.7. | `calendar-trials.php` | Prova causal quando você quiser ligar. |
| 10 | **Limpeza de cache automática** na primeira visita de um admin ao painel. | `inc/ads/mode.php` | Leitores passam a receber o motor novo sem esperar o cache expirar. |

Nada disso atualiza, repete ou esconde anúncio. A regra de um pedido por posição por pageview continua, e os limites de densidade não mudaram.

## Evidência antes do deploy

Tudo roda localmente, com o código do próprio tema (em `tools/`):

- `php tools/plan-bench.php theme`: planejador em 66 artigos sintéticos. Hosts no corpo de 423 para 514; artigos longos de 7,0 para 8,8 posições.
- `php tools/render-bench.php theme <contexto>`: o que é emitido em cada template. Nenhum ID de unidade duplicado.
- `tools/sim/`: Chromium com o runtime real, um `adsbygoogle` falso (latência de 700 ms, 7 de cada 8 preenchidos) e 4 leitores por página (abandona em 20%, para na metade, lê até o fim, folheia até 60%), numa notícia de 650 e num guia de 2.800 palavras:

| | 5.6.7 | 5.7.0 |
|---|---|---|
| Impressões preenchidas | 70 | 64 |
| Impressões vistas (50% por 1 s) | 53 | **58** |
| Proxy de Active View | 75,7% | **90,6%** |

A simulação mede o comportamento do motor, não a receita. O leitor simulado é mais comportado que o real, então o Active View real será bem menor que 90%. O que vale é a direção: **menos impressões desperdiçadas e mais impressões vistas.**

## Depois do upload (hoje)

1. Suba o tema e entre no painel como administrador uma vez: isso limpa o cache do LiteSpeed. **Se houver CDN (Cloudflare etc.), limpe-o também.**
2. Confirme numa matéria, aberta como administrador, no console: `GOAdsRuntime.inspect().version` deve responder `13.3.0-viewability-first`.
3. No Ads Center, confirme que a sincronização está rodando. O controlador por unidade depende do modelo de 7 dias; se ele tiver mais de 24 h, o controlador fica neutro e só a tabela nova vale.

## Na conta AdSense (maior impacto, fora do alcance do código)

- **Anúncios automáticos:** mantenha **Âncora** e **Vinheta** ligados. São os formatos com maior Active View, e o vinheta volta a ter o primeiro clique no mobile. **Trilhos laterais** ligados no desktop.
- **In-page automático:** no relatório por formato, compare o Active View e o RPM de impressão do in-page automático com os das unidades manuais. O motor manual já cobre o miolo da página. Se o in-page automático ficar abaixo de 50% de Active View, reduza a carga de anúncios ou desligue só o in-page.
- **Controles de bloqueio:** revise categorias gerais e sensíveis e anunciantes bloqueados. Cada bloqueio tira compradores do leilão e reduz o preço.
- **ads.txt** com status "Autorizado", incluindo as linhas do Clever para o desktop.
- **Search Console → Relatório de experiência de anúncios** precisa estar "Aprovado". O motor permite até 45% de anúncio sobre a altura do artigo, e o Better Ads Standard considera violação densidade acima de 30% no mobile. Se aparecer aviso, reduza `max_ad_to_content_ratio` do mobile para 0,30 em `inc/ads/config.php`.

## O que olhar amanhã e nos próximos dias

- **Amanhã:** o AdSense mostra o dia anterior consolidado; o dia corrente ainda é estimativa. Olhe o **Active View por unidade** no Ads Center. As unidades que estavam abaixo de 50% devem subir primeiro: o controlador age nelas desde a primeira pageview.
- **Dias 2 a 4:** o RPM de impressão reage com atraso, porque o Google reaprende a viewability prevista de cada unidade. O esperado é o RPM de impressão subir e as impressões por página caírem um pouco entre leitores que folheiam e subirem entre os que leem até o fim.
- **Ajuste fino** por filtro, sem editar o tema. Exemplo em um mu-plugin:

```php
add_filter( 'go_verge_ads_viewability_policy', function ( $p ) {
	$p['target'] = 0.65;          // centro da faixa desejada
	$p['skim_settle_ms'] = 700;   // menos rígido com quem folheia
	return $p;
} );
```

- Se o Active View passar de 70% e as impressões por página caírem demais, afrouxe (`target` 0,58 ou `skim_vh` 1,8). Se ficar abaixo de 50%, aperte (`target` 0,66, `floor` 0,40).
- Para medir com rigor: em `inc/ads/calendar-trials.php`, ligue o teste `viewability-first-v1` com início no dia seguinte e 1 dia por braço. Depois de 14 dias, cada braço terá rodado uma vez em cada dia da semana.

## Como reverter cada item (wp-config.php ou mu-plugin)

```php
define( 'GO_VERGE_ADS_ARTICLE_MAX_RUNG', 6 );   // desliga A7/A8
define( 'GO_VERGE_CLEVER_MOBILE', true );       // Clever volta ao celular
add_filter( 'go_verge_ads_viewability_policy', function ( $p ) { $p['enabled'] = false; return $p; } ); // controlador e trava de folheio
add_filter( 'go_verge_ads_page_end_multiplex', '__return_false' );     // Multiplex de fim de página
add_filter( 'go_verge_ads_post_content_anchors', function () { return array( 'after-author', 'after-recirculation', 'before-comments' ); } );
```

A tabela de antecedência antiga está inteira no braço `legado` do teste por calendário.

## Limites

Nenhum código garante um número do AdSense num dia específico: demanda, sazonalidade e mix de tráfego mudam o preço de um dia para o outro. Este release remove, pelo lado do site, os mecanismos que seguravam Active View e RPM de impressão para baixo, e deixa um controlador que continua corrigindo unidade por unidade com dados reais. O quarto trimestre começa em outubro, e os CPMs costumam subir. Isso ajuda, mas não foi considerado nas contas acima.
