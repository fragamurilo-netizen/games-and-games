# Auditoria Discover + RPM — 22/09/2026

Base: tema Overdrive 5.5.3 (`news-magazine-x_43.zip`), runtime de anúncios
`12.7.0-context-paint-gate`.

Esta auditoria leu o código-fonte. Não houve acesso ao site publicado, ao painel
do AdSense, ao Search Console nem ao servidor. Tudo abaixo que é afirmado como
**medido** vem de medições que o próprio tema registra nos comentários, com
data; tudo que é afirmado como **encontrado** vem da leitura do código. As duas
coisas estão separadas de propósito.

---

## 1. Discover

### 1.1 O que foi descartado

Vale registrar o que **não** é a causa, porque são as hipóteses que normalmente
consomem o tempo primeiro.

**A cadeia de robots está correta.** Foram percorridos os 14 callbacks de
`wp_robots` e os 12 de `rank_math/frontend/robots`, na ordem de prioridade, para
o caso de uma matéria publicada (`is_singular('post')`):

- nenhum deles aplica `noindex` a uma matéria publicada;
- `max-image-preview:large` é reafirmado nos três provedores possíveis (motor
  nativo, Rank Math, Yoast), cada um com a convenção de valor correta — o nativo
  usa `'large'` porque `wp_robots()` monta `chave:valor`; Rank Math e Yoast usam
  a diretiva completa porque imprimem `implode(', ', $robots)`;
- as diretivas de preview são removidas **apenas** quando a URL é de fato
  `noindex`, em `PHP_INT_MAX`, que é o único ponto que enxerga a decisão final;
- `go_verge_desk_format_context()` devolve vazio em single posts, então o
  `noindex` de facetas em prioridade 10000 não alcança matérias;
- `go_verge_indexing_is_filtered_discovery_request()` exclui explicitamente
  singular de `post`, então nenhuma query string muda a política de uma matéria.

**Não há bloqueio por user-agent** em lugar nenhum do tema (`HTTP_USER_AGENT`
não aparece).

**O news sitemap está correto**: janela de 48 h medida pelo relógio imutável de
primeira publicação, roteamento em `template_redirect` com prioridade -2000,
cabeçalhos e cache coerentes.

**O canonical de matéria é autorreferente.** `editorial-parent-canonical.php`
só toca hubs (`/games/`, `/entretenimento/`, `/tecnologia/`), nunca posts.

**O módulo de integridade de cache está correto** e resolve um problema real
(`PHPSESSID` + `no-store` impedindo cache de borda).

### 1.2 O que foi encontrado

**Três respostas diferentes para a mesma pergunta: "o Google consegue buscar a
imagem desta matéria?"**

| Consumidor | Função | Resposta para AVIF |
|---|---|---|
| og:image | `go_verge_og_image_format_supported()` | recusa → matéria sai **sem og:image** |
| Article.image / schema | `go_verge_schema_image_format_supported()` | aceitava → aponta para arquivo quebrado |
| Site Health | `go_verge_discover_image_ready()` | só media pixels → **reportava verde** |

Cada uma se defende isoladamente. Juntas, num servidor específico, não podem
estar as três certas — e este é esse servidor. O próprio tema registra, medido
em produção:

- **18/08/2026** — "Every `.avif` is answered with `Content-Type: text/plain`
  next to `X-Content-Type-Options: nosniff`. Browsers still paint the image
  because they sniff the bytes; social crawlers and Google's image pipeline
  validate the header, so the article is shared with no preview and enters
  Discover with no large-image asset. **Discover is two thirds of this site's
  traffic.**" (`functions.php`)
- **03/09/2026** — "uploads AVIF **não geram nenhuma** subsize — `-1600x900.avif`,
  `-1280x720.avif` e `-768x432.avif` respondem 404. Sem subsize, o
  `go_discover_16x9` não existe, a cadeia de candidatos cai para `full`, e o
  `og:image` acaba sendo o AVIF original." (`inc/rank-math-compat.php`)

O resultado combinado, para uma matéria cuja imagem em destaque é AVIF: **sem
og:image, com `Article.image` apontando para um arquivo que o pipeline de
imagens do Google descarta, e com o painel dizendo que está tudo pronto.** O
Discover não distribui história sem imagem grande.

**A correção existente protege só metade do problema.** O bloqueio de upload de
AVIF entrou em 18/08/2026. Ele impede matérias **novas** de entrarem nesse
estado. Ele não faz nada pelo acervo: toda matéria publicada antes disso com
imagem AVIF continua exatamente como estava, porque nenhuma das duas falhas é
propriedade do upload — as duas são propriedades do servidor, e valem para
arquivos que já estão em disco. E **nada no tema reportava isso**.

### 1.3 A correção de verdade é uma linha no servidor

Nenhuma alteração de PHP conserta a causa. O `.htaccess` da raiz, **fora** do
bloco `# BEGIN WordPress`:

```apache
AddType image/avif .avif
```

O próprio tema já diz isso em `go_verge_avif_delivery_health_test()`. Enquanto
isso não for feito, a saída prática é reenviar as capas em JPEG ou PNG nas
matérias afetadas — o site gera os recortes em WebP sozinho.

### 1.4 O que esta auditoria não consegue afirmar

Não dá para provar causalidade a partir do código. O gráfico enviado mostra pico
em 09–10/08 e queda a zero até 06–08/09, o que é **compatível** com uma fração
crescente do acervo vivo em estado quebrado, mas é igualmente compatível com uma
ação de política ou uma atualização ampla do Google — e uma queda total e
abrupta é, francamente, mais típica disso do que de uma degradação técnica
gradual. O que o código pode fazer é remover as razões técnicas de exclusão, que
é o que foi feito. Se depois de corrigir o MIME e o acervo o Discover não
voltar, a resposta não está no tema, e vale checar Ações Manuais e Problemas de
Segurança no Search Console antes de mexer em mais código.

Nenhum código garante distribuição no Discover. O Google não expõe esse
controle.

### 1.5 Alterado

| Arquivo | Mudança |
|---|---|
| `inc/image-deliverability.php` (novo) | Resposta única sobre *chegada* do arquivo, derivada do mesmo sinal que governa o upload. Um filtro reabre upload, schema e prontidão juntos quando o servidor for corrigido. SVG e TIFF ficam fora de forma permanente: não são material de preview. |
| `inc/seo.php` | `go_verge_schema_image_format_supported()` passa a consultar a resposta única. A lista ampla continua fazendo seu trabalho separado. |
| `inc/rank-math-compat.php` | `go_verge_og_image_format_supported()` idem. Isso também removeu SVG e TIFF, que passavam porque a lista foi escrita sobre AVIF e nunca revisada. |
| `inc/discover-cwv.php` | `go_verge_discover_image_ready()` deixa de reportar verde para arquivo que não chega. Verificação nova em Site Health conta as matérias do acervo em estado quebrado e lista exemplos clicáveis. |
| `inc/search-freshness.php` | `go_verge_search_published_iso()` respondia `gmdate('c')` — o instante da requisição — quando não resolvia data nenhuma. Isso não é data ausente, é data errada, e diferente a cada rastreamento. Passa a usar a data própria do post e, em último caso, omitir o campo. |

53 asserções novas em `tests/test-discover-image-deliverability.php`.

---

## 2. Anúncios e RPM

### 2.1 Onde estava faltando inventário

**A zona pós-conteúdo da matéria.** Um `single_post` terminava a publicidade em
`article-end`, logo depois da prosa. Abaixo dali vinham, sem nada: card do autor,
"Continue", "Leia também", mais reviews do autor, cluster do jogo, barra de
assuntos, comentários e a trilha de exploração. No celular isso é várias telas
de conteúdo editorial real, rolado — e é justamente o trecho que o leitor de
Discover alcança com frequência, porque chegar numa matéria e seguir para outra
é o que esse público faz.

**A coluna lateral no celular.** `sidebar-desktop` é `desktop_only`, o que está
certo para um trilho fixo de 300px. O que isso não dizia é o que acontece com o
trilho: em 1100px e abaixo, `single-clean.css` transforma `.go-single__layout`
em `display:block` e a coluna inteira — ofertas, grupos de matérias, "Continue
no Overdrive" — passa a renderizar em largura total embaixo do artigo, em vez de
sumir. No aparelho que carrega a maior parte da audiência, essa coluna inteira
era conteúdo do publisher sem nenhum inventário.

**O leilão de Multiplex, inteiro.** O contrato não tinha nenhuma unidade
Multiplex. Não é "mais um banner": é demanda de comprador de nativo e
recirculação, que não dá lance num 300x250. A página simplesmente não estava
entrando nesse leilão.

**Matéria longa.** A escada do corpo parava em sete posições e parava de crescer
em 1200 palavras. Um guia de 3000 palavras recebia o mesmo que um de 1200,
carregando duas vezes e meia mais conteúdo entre as mesmas sete unidades. É a
diferença mais clara em relação ao Auto Ads, que continua colocando enquanto a
matéria continua.

### 2.2 Implementado e ativo agora

**Zona pós-conteúdo — sem unidade nova na conta.** Três âncoras em fronteiras
editoriais (depois do card do autor, depois de "Leia também", antes dos
comentários), servidas pelo pool de listagens F1–F5, que já existe, está ativo e
simplesmente não era gasto neste template. A escada do corpo usa outro pool,
então nada disputa slot com P1/A1–A6 nem com `article-end`.

**Multiplex na fronteira de recirculação — unidade `1889487031`.** O formato que
faltava contra o Auto Ads. Fica na âncora do meio porque é onde a forma é
honesta: o leitor terminou a matéria e está escolhendo o que ler em seguida, e
uma grade de itens relacionados é a forma nativa desse momento — é por isso que
o formato precifica diferente de uma interrupção entre parágrafos.

Ele **substitui** a unidade do pool naquela âncora, não soma em cima: a grade é
alta, e empilhar banner contra ela é exatamente a densidade que o resto do motor
existe para evitar. O cursor do pool não é gasto ali, então "antes dos
comentários" continua recebendo F2.

Entrou como placement do contrato, não como HTML solto no template. HTML solto
carregaria um segundo `adsbygoogle.js` (o tema já imprime um), faria `push()` no
parse ignorando o gate de consentimento, e ficaria fora da janela de densidade e
do diagnóstico. O `<ins>` emitido é idêntico ao snippet — mesmo client, mesmo
slot, mesmo `autorelaxed`.

`tests/test-manual-formats.php` proibia a palavra `multiplex` no contrato. A
regra que o docblock dele descreve é mais estreita: o perigo é **uma constante
do wp-config trocar o TIPO de uma unidade VIVA** por trás do relatório dela, e o
próprio docblock diz que o caminho seguro é "unidades NOVAS, declaradas com o
formato que realmente são" — que é exatamente este caso. A checagem passou a
afirmar a regra de verdade: nenhum placement decide `sizing`, `format` ou
`ad_layout` por constante ou condicional. Foi verificado que a guarda nova casa
com as três formas do experimento antigo e não dá falso positivo no caminho
seguro.

**O teto do corpo deixou de ser o número 7.** Sete nunca foi regra sobre leitura
nem densidade: era quantas unidades de corpo a conta tinha, escrita como literal
em seis pontos do planner — por isso criar A7 no AdSense não mudava nada.
`go_verge_ads_planner_contract_capacity()` passa a ler do contrato. Os degraus
acima de 1200 palavras continuam a mesma curva em vez de terminá-la: 1800 abre o
oitavo, 2600 abre o nono, sempre limitados pelo que o contrato consegue servir.

Isso **não mexe em densidade**, e esse é o ponto: relação anúncio/conteúdo,
parcela local e teto por janela são medidos contra altura renderizada, então uma
unidade adicionada porque existem mais 600 palavras de artigo deixa as três
exatamente onde estavam. Adiciona alcance em matéria que ganhou isso, não
pressão em matéria que não ganhou.

### 2.3 Pronto no código, esperando você criar a unidade

Nenhum ID foi inventado. Os três abaixo se declaram, ficam desabilitados e não
renderizam nada até a constante existir — e enquanto isso o comportamento é
idêntico ao de hoje.

| Constante | O que liga |
|---|---|
| `GO_VERGE_ADS_ARTICLE_RAIL_MOBILE_SLOT` | A coluna lateral empilhada abaixo de 1101px, hoje sem nenhum inventário |
| `GO_VERGE_ADS_ARTICLE_A7_SLOT` | Oitava posição do corpo, só em matéria ≥1800 palavras |
| `GO_VERGE_ADS_ARTICLE_A8_SLOT` | Nona posição do corpo, só em matéria ≥2600 palavras |

A7/A8 devem ser **Display responsivo**, o mesmo produto de A1–A6, para a escada
continuar sendo um formato só — é isso que torna as posições comparáveis entre
si. Definir só A7 eleva o teto para oito; o teto segue o contrato.

Um buraco na escada (A8 definido sem A7) é tratado como configuração errada, não
como escada maior: só o prefixo contínuo conta. Senão o planner entregaria a um
candidato o id `article-a7`, que não renderiza nada, e a oportunidade se perderia
em silêncio.

### 2.4 Sobre "venda e leilão", com honestidade

O tema não muda o que o Google paga. `data-full-width-responsive="true"`, Display
responsivo e `format: auto` já estavam corretos em todo o inventário; a camada de
markup não tinha folga.

O que o código controla é **em quantos leilões a página entra e em que
condição**. As mudanças acima atacam as duas pontas:

- **Mais leilões diferentes** — Multiplex traz demanda que não disputava nada
  aqui. Isso é aumento de receita sem custo de densidade, que é o tipo raro.
- **Mais posições onde o conteúdo paga por elas** — a escada longa adiciona
  inventário proporcional ao tamanho do artigo, deixando todas as razões de
  densidade intactas.

O que eu **não** fiz, de propósito: subir `max_ad_to_content_ratio` (0,45),
`max_local_ad_ratio` (0,45) ou `max_units_in_window` (3). Ali é onde mora o risco
de experiência de página, e vocês querem o Discover de volta — subir esses
números é a forma mais rápida de ganhar impressão hoje e perder distribuição
depois.

E há uma tensão que precisa ser dita: o Top Scroll abre **acima do cabeçalho**,
com reserva de `max(308px, min(83.334vw,360px) + 58px)` — cerca de 383px num
telefone de 390px, mais 106px de masthead. São ~489px antes de qualquer conteúdo
editorial. É caro em LCP e é exatamente o tipo de densidade acima da dobra que
pesa em avaliação de experiência de página. Não foi mexido, porque é decisão de
publisher explícita e documentada, e mexer sem dado de campo seria chute. Se o
objetivo é recuperar o Discover, é a posição que eu revisaria primeiro — e é
medível pelo teste por dia de calendário que o próprio motor já tem
(`go_verge_ads_trials`), que é a única forma honesta de comparar duas
configurações sem confundir com mix de tráfego.

**Nada disso prova receita.** Os testes provam lógica, contrato e markup. Fill,
Active View, RPM e receita só aparecem na navegação publicada, e a comparação
confiável é por dia fechado, não antes/depois.

## 3. Validação

- Suíte completa (`php tests/run.php`): **todas as suítes passaram** —
  147.742 asserções PHP, incluindo as 131 novas desta auditoria.
- A escada longa foi exercitada **com A7/A8 ligados** num processo próprio, e o
  buraco de escada (A8 sem A7) num segundo processo. Provar que o caminho
  desligado não muda nada não prova que o ligado funciona; os dois foram
  testados.
- `php -l` em todos os arquivos PHP do tema: sem erros.
- Nenhuma solicitação real de anúncio foi feita. Nenhuma alteração de conta
  AdSense, de servidor ou de publicação foi executada.
- Não houve navegador real nem medição de campo. Os testes provam lógica,
  contrato e markup — não provam preenchimento, Active View, receita ou Core Web
  Vitals.


## 4. Ordem sugerida

1. `AddType image/avif .avif` no `.htaccess` da raiz, fora do `# BEGIN WordPress`.
   É a causa técnica do lado do Discover, e é uma linha.
2. Instalar o tema e abrir **Ferramentas → Saúde do site**. A verificação nova
   diz quantas matérias do acervo estão em estado quebrado e quais.
3. Reenviar as capas dessas matérias em JPEG/PNG (ou regenerar as miniaturas,
   depois que o servidor estiver servindo AVIF corretamente).
4. Verificar Ações Manuais e Problemas de Segurança no Search Console antes de
   concluir que a causa era técnica.
5. Conferir o Multiplex numa matéria publicada: abrir "Anúncios: diagnóstico" e
   confirmar `post-content-multiplex` com estado `filled` ou `unfilled` — não
   `template`. O `unfilled` é normal nos primeiros dias de uma unidade nova.
6. Criar as três unidades da seção 2.3 e definir as constantes.
7. Só depois disso, e com pelo menos duas semanas de dias fechados, avaliar o
   Top Scroll pelo teste por dia de calendário.
