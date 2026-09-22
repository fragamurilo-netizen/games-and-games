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

### 2.2 Implementado

**Zona pós-conteúdo — sem unidade nova na conta.** Três âncoras em fronteiras
editoriais (depois do card do autor, depois de "Leia também", antes dos
comentários), servidas pelo pool de listagens F1–F5, que já existe, está ativo e
simplesmente não era gasto neste template. A escada do corpo usa outro pool,
então nada disputa slot com P1/A1–A6 nem com `article-end`. Cada âncora gasta no
máximo uma unidade e apenas uma vez por documento.

Como em todo o resto do motor, o template oferece a **oportunidade**; quem
decide pedir é o runtime, contra o mesmo espaçamento de stream (380px no
celular), janela de densidade e relação anúncio/conteúdo que as outras posições
obedecem. Por isso uma matéria curta continua terminando com menos de três.

**Coluna lateral empilhada — placement novo, desligado.** `article-rail-mobile`,
com portão `max_viewport: 1100`. É placement próprio e não um ajuste de viewport
no `sidebar-desktop` porque um trilho fixo de 300px e um bloco de largura total
são produtos diferentes, e juntar os dois deixaria o relatório dos dois
ilegível. O portão é emitido pelo renderer como media query tanto na regra de
exibição quanto na solicitação, então um único HTML cacheado continua correto
para qualquer user agent, e os dois nunca solicitam no mesmo documento.

Não foi inventado nenhum ID de unidade. Crie uma unidade Display responsiva no
AdSense e ligue com:

```php
define( 'GO_VERGE_ADS_ARTICLE_RAIL_MOBILE_SLOT', '0000000000' );
```

Até lá o placement se declara, fica desabilitado e não renderiza nada.

O CSS dos dois segue o contrato dos outros hosts do arquivo: altura zero, margem
zero e sem borda até a posição ser efetivamente solicitada, para que uma zona que
oferece três e preenche uma não deixe dois buracos na página.

40 asserções novas em `tests/test-post-content-inventory.php`.

### 2.3 Recomendado, não implementado — precisa de decisão sua

**Multiplex (grade nativa) na fronteira de recirculação.** O renderer suporta
`sizing => 'multiplex'` desde que a arquitetura manual existe e **nenhuma
unidade jamais usou**. A zona abaixo do artigo é o único lugar do site onde uma
grade de itens relacionados é a forma nativa da superfície, e não uma
interrupção dela: o leitor já está escolhendo o que ler em seguida, o que é uma
transação diferente de um banner entre parágrafos e precifica diferente no
leilão. Para um site de notícias com audiência majoritariamente móvel, essa
costuma ser a adição de maior RPM que não acrescenta mais um banner.

**Foi implementado e depois revertido**, de propósito.
`tests/test-manual-formats.php` proíbe a palavra `multiplex` em
`inc/ads/config.php`, com a justificativa registrada de que "ambos os
experimentos sumiram e devem continuar sumidos". Lendo o docblock, a regra que
ele descreve é mais estreita do que o teste implementa: o perigo documentado é
**uma constante do wp-config trocar o TIPO de uma unidade viva** (Article End de
Display para Multiplex), porque o tipo faz parte da identidade de relatório da
unidade. O docblock diz explicitamente que o caminho seguro é o oposto —
"três unidades NOVAS, declaradas com o formato que realmente são".

Um placement novo, com ID próprio, desligado por padrão e incapaz de alterar o
tipo de qualquer outra unidade honra a regra descrita. Mas afrouxar em silêncio
uma guarda que alguém escreveu com a palavra "devem continuar sumidos" é decisão
sua, não minha — e não dá para saber, pelo código, se o experimento anterior foi
removido pelo risco de troca de tipo ou porque rendeu mal. Se a decisão for
seguir, o caminho é: criar a unidade Multiplex no AdSense, declarar
`post-content-multiplex` com `sizing => 'multiplex'` e `format => 'autorelaxed'`
e ID vindo de constante (padrão vazio, igual a F4/F5), preferi-la na âncora
`after-recirculation` com queda para o pool quando ausente, e **estreitar o teste
para o que ele de fato quer proibir** — troca de tipo por constante — em vez de
proibir a palavra.

### 2.4 Sobre "RPM de impressões, venda e leilão"

Vale ser direto: o tema não muda o que o Google paga. O `data-full-width-responsive="true"`,
o Display responsivo e o `format: auto` já estão corretos em todo o inventário; a
camada de markup não tem folga.

O que o código controla é **quantas impressões acontecem e em que condição**, e é
por aí que o RPM de impressão se move — não somando posições, mas mudando a razão
entre impressões e impressões realmente vistas. As duas adições acima seguem essa
lógica: são posições profundas, tier `deep`/`standard`, em superfície que o
leitor alcança por escolha própria, onde o runtime já decide sozinho se vale
pedir. Somar unidade rasa acima da dobra faria o contrário — mais impressões,
cada uma valendo menos, e com custo do lado do Discover.

E há uma tensão que precisa ser dita, porque os dois pedidos puxam em direções
opostas: o Top Scroll abre **acima do cabeçalho**, com reserva de
`max(308px, min(83.334vw,360px) + 58px)` — cerca de 383px num telefone de 390px
de largura, mais 106px de masthead. São ~489px antes de qualquer conteúdo
editorial. Isso é caro em LCP e é exatamente o tipo de densidade acima da dobra
que pesa em avaliação de experiência de página. Não foi mexido, porque é uma
decisão de publisher explícita e documentada e porque mexer nela sem dado de
campo seria chute. Mas se o objetivo é recuperar o Discover, essa é a posição que
eu revisaria primeiro — e é medível pelo teste por dia de calendário que o
próprio motor já tem (`go_verge_ads_trials`), que é a única forma honesta de
comparar as duas configurações sem confundir com mix de tráfego.

---

## 3. Validação

- Suíte completa (`php tests/run.php`): **todas as suítes passaram**, incluindo
  as 93 asserções novas.
- `php -l` em todos os arquivos PHP do tema: sem erros.
- Nenhuma solicitação real de anúncio foi feita. Nenhuma alteração de conta
  AdSense, de servidor ou de publicação foi executada.
- Não houve navegador real nem medição de campo. Os testes provam lógica,
  contrato e markup — não provam preenchimento, Active View, receita ou Core Web
  Vitals.

## 4. Ordem sugerida

1. `AddType image/avif .avif` no `.htaccess` da raiz. É a causa, e é uma linha.
2. Instalar o tema e abrir **Ferramentas → Saúde do site**. A verificação nova
   diz quantas matérias do acervo estão em estado quebrado e quais.
3. Reenviar as capas dessas matérias em JPEG/PNG (ou regenerar as miniaturas,
   depois que o servidor estiver servindo AVIF corretamente).
4. Verificar Ações Manuais e Problemas de Segurança no Search Console antes de
   concluir que a causa era técnica.
5. Criar a unidade de `article-rail-mobile` e definir a constante.
6. Decidir sobre o Multiplex (seção 2.3).
