# Overdrive 5.5.4 — inventário abaixo da prosa, Multiplex e escada longa

Base: 5.5.3. Runtime de entrega permanece `12.7.0-context-paint-gate` — nada
nesta versão altera o motor no navegador, só o que o contrato declara e onde o
tema oferece oportunidade.

## Unidades novas nesta versão

| Placement | Unidade | Formato | Onde |
|---|---|---|---|
| `post-content-multiplex` | `1889487031` | Multiplex `autorelaxed` | Fronteira de recirculação da matéria |
| `article-a7` | `1805726556` | Display responsivo | 8ª posição do corpo, ≥1800 palavras |
| `article-a8` | `6305400886` | Display responsivo | 9ª posição do corpo, ≥2600 palavras |
| `article-rail-mobile` | `9492644884` | Display responsivo | Coluna lateral empilhada, ≤1100px |

Todas entram como padrão do contrato. A constante de `wp-config.php` continua
existindo e sobrepõe — é como se faz rollback de uma posição sem editar o tema.
Zerar uma constante desabilita aquele placement.

## Zona pós-conteúdo da matéria

Um `single_post` terminava a publicidade em `article-end`, logo depois da prosa.
Abaixo dali vinham, sem nada: card do autor, "Continue", "Leia também", mais
reviews do autor, cluster do jogo, barra de assuntos, comentários e a trilha de
exploração. No celular isso é várias telas de conteúdo editorial rolado, e é o
trecho que o leitor de Discover alcança com frequência — chegar numa matéria e
seguir para outra é o que esse público faz.

São três âncoras em fronteiras editoriais: depois do card do autor, depois de
"Leia também" e antes dos comentários. As duas pontas são servidas pelo pool de
listagens F1–F5, que já existia, estava ativo e simplesmente não era gasto neste
template; a escada do corpo usa outro pool, então nada disputa slot com P1/A1–A6
nem com `article-end`. Cada âncora gasta no máximo uma unidade, uma vez por
documento.

A âncora do meio recebe o Multiplex, e ele **substitui** a unidade do pool ali em
vez de somar em cima: a grade é alta, e empilhar banner contra ela é exatamente a
densidade que o resto do motor existe para evitar. O cursor do pool não é gasto
nessa âncora, então "antes dos comentários" continua recebendo F2.

## Por que Multiplex

É o formato que faltava neste contrato em relação ao Auto Ads, e não é mais um
banner: Multiplex tem demanda própria — comprador de nativo e recirculação, que
não dá lance num 300x250. A página não estava entrando nesse leilão.

Fica na fronteira de recirculação porque é onde a forma é honesta. O leitor
terminou a matéria e está escolhendo o que ler em seguida; uma grade de itens
relacionados é a forma nativa desse momento, e é por isso que o formato precifica
diferente de uma interrupção entre parágrafos.

`tests/test-manual-formats.php` proibia a palavra `multiplex` no contrato. A
regra que o docblock dele descreve é mais estreita: o perigo é **uma constante do
wp-config trocar o TIPO de uma unidade VIVA** por trás do relatório dela, e o
próprio docblock diz que o caminho seguro é "unidades NOVAS, declaradas com o
formato que realmente são". A checagem passa a afirmar a regra de verdade —
nenhum placement decide `sizing`, `format` ou `ad_layout` por constante ou
condicional — e foi verificada contra as três formas do experimento antigo.

## O teto do corpo deixa de ser o número 7

A escada parava em sete oportunidades e parava de crescer em 1200 palavras. Um
guia de 3000 palavras recebia exatamente o que um de 1200 recebe, carregando duas
vezes e meia mais conteúdo entre as mesmas sete unidades.

Sete nunca foi regra sobre leitura nem densidade: era quantas unidades de corpo a
conta tinha (P1 + A1–A6), escrita como literal em seis pontos do planner. Por
isso criar A7 no AdSense não mudava nada — a contagem antiga estava compilada em
meia dúzia de lugares que precisavam concordar.
`go_verge_ads_planner_contract_capacity()` passa a ler do contrato.

A curva:

| Palavras | Antes | Agora |
|---|---|---|
| < 1200 | 0–6 | **idêntico** |
| 1200–1799 | 7 | 7 |
| 1800–2599 | 7 | 8 |
| ≥ 2600 | 7 | 9 |

Isso **não mexe em densidade**, e esse é o ponto: relação anúncio/conteúdo,
parcela local e teto por janela são medidos contra altura renderizada, então uma
unidade adicionada porque existem mais 600 palavras de artigo deixa as três
exatamente onde estavam. Adiciona alcance em matéria que ganhou isso, não pressão
em matéria que não ganhou.

Um buraco na escada (A8 declarado sem A7) é tratado como configuração errada, não
como escada maior: só o prefixo contínuo conta. Senão o planner entregaria a um
candidato o id `article-a7`, que não renderiza nada, e a oportunidade se perderia
em silêncio.

## Coluna lateral no celular

`sidebar-desktop` é `desktop_only`, o que está certo para um trilho fixo de
300px. O que isso não dizia é o que acontece com o trilho: em 1100px e abaixo,
`single-clean.css` transforma `.go-single__layout` em `display:block` e a coluna
inteira — ofertas, grupos de matérias, "Continue no Overdrive" — passa a
renderizar em largura total embaixo do artigo, em vez de sumir. No aparelho que
carrega a maior parte da audiência, essa coluna inteira era conteúdo do publisher
sem nenhum inventário.

É placement próprio e não um ajuste de viewport no `sidebar-desktop` porque um
trilho fixo de 300px e um bloco de largura total são produtos diferentes, e
juntar os dois deixaria o relatório dos dois ilegível. O portão é `max_viewport`
1100, que o renderer emite como media query tanto na regra de exibição quanto na
**solicitação** — unidade escondida por CSS que ainda faz `push()` é um request
com `availableWidth` 0, que queima a única solicitação daquele slot na página.
Um único HTML cacheado continua correto para qualquer user agent, e os dois nunca
solicitam no mesmo documento.

O relatório dessa unidade no AdSense será inteiramente móvel/tablet por
construção. É o desenho, não falha de entrega.

## UI

Os hosts novos falam a mesma linguagem visual dos intervalos do corpo, porque são
lidos na mesma coluna e o leitor não deve conseguir dizer que um intervalo foi
planejado pela escada e outro pelo pool:

- nada até a posição ser solicitada — altura zero, margem zero, sem fio. Uma zona
  que oferece três e preenche uma não pode deixar dois buracos;
- um fio **acima** no pedido, marcando o intervalo como publicidade sem desenhar
  uma caixa em volta de um criativo que o publisher não controla;
- um fio mais claro **abaixo** só quando existe criativo de verdade, para que
  unidade sem preenchimento nunca feche uma caixa em volta de espaço vazio.

Os dois viram `--go-ad-break-top` / `--go-ad-break-bottom`, com o mesmo
`color-mix` que `.go-article-revenue-slot` já usava. O trilho empilhado é a
exceção deliberada: ele já abre com o separador próprio do tema em ≤1100px, então
não carrega fio próprio — dois fios a poucos pixels um do outro leem como erro.

## Entrega

`usesStreamSpacing()` no runtime escolhe espaçamento de prosa (`min_gap_px`,
240px) ou de stream (`min_stream_gap_px`, 380px) por
`!/^article/.test(surface)`. O trilho empilhado é um bloco de largura total entre
cards de matéria e blocos de oferta, muito mais altos que um parágrafo: ele
precisa do vão largo para ler como intervalo editorial. A superfície é
`rail-stacked-mobile`, e o nome passa a ser travado por teste — ali um nome não é
rótulo, ele compra uma regra de espaçamento.

Foi verificado no runtime que a zona pós-conteúdo já é coberta pelas regras
locais de densidade (janela de ±0,9 viewport, teto de 3 unidades, 45% de área
local). Só a razão de artigo inteiro é exclusiva do corpo, o que está certo —
fora dele não existe coluna de prosa para medir.

## O que esta versão NÃO faz

Não sobe `max_ad_to_content_ratio` (0,45), `max_local_ad_ratio` (0,45) nem
`max_units_in_window` (3). Ali mora o risco de experiência de página, e subir
esses números é a forma mais rápida de ganhar impressão hoje e perder
distribuição depois.

Não mexe no Top Scroll, que abre acima do cabeçalho com ~383px num telefone de
390px, mais 106px de masthead. É decisão de publisher explícita e documentada, e
mexer sem dado de campo seria chute. Se o objetivo for recuperar Discover, é a
posição a revisar primeiro — pelo teste por dia de calendário que o motor já tem
(`go_verge_ads_trials`), que é a única forma honesta de comparar duas
configurações sem confundir com mix de tráfego.

Não altera o runtime, IDs existentes, densidade, frequência, loader ou
consentimento. Não executa nenhuma alteração de conta AdSense.

## Validação

Suíte completa (`php tests/run.php`): **todas as suítes passaram**, incluindo as
novas desta versão, rodando com as quatro unidades ligadas. `php -l` em todos os
arquivos PHP: sem erros. Chaves do CSS balanceadas.

Nenhuma solicitação real de anúncio foi feita, e nenhum navegador real foi usado.
Os testes provam lógica, contrato e markup — **não** provam preenchimento, Active
View, RPM, receita ou Core Web Vitals de campo. Isso só aparece na navegação
publicada, e a comparação confiável é por dia fechado, não antes/depois.

## Instalação

1. Guardar o ZIP anterior e um backup do banco/opções.
2. Aparência → Temas → Adicionar novo → Enviar tema, e substituir a versão do
   mesmo tema.
3. Limpar cache de página, LiteSpeed/CDN e assets. O HTML antigo carrega o
   contrato antigo.
4. Abrir uma matéria e conferir **Anúncios: diagnóstico**: versão 5.5.4, modo
   `manual_overlays`, motor inicializado.
5. Conferir `post-content-multiplex` com estado `filled` ou `unfilled` — **não**
   `template`. `unfilled` é normal nos primeiros dias de uma unidade nova; o
   Google leva tempo para começar a preencher inventário recém-criado.
6. Abrir uma matéria longa (≥2600 palavras) e conferir que a escada do corpo
   expõe até nove posições; abrir uma curta (<1200) e conferir que nada mudou.
7. Reduzir a janela para menos de 1100px e conferir o trilho empilhado abaixo dos
   comentários.

## Rollback

Reinstalar o ZIP anterior e invalidar as mesmas camadas de cache. Para desligar
uma posição isolada sem trocar o tema, zerar a constante correspondente em
`wp-config.php`:

```php
define( 'GO_VERGE_ADS_POST_CONTENT_MULTIPLEX_SLOT', '' );
define( 'GO_VERGE_ADS_ARTICLE_A7_SLOT', '' );
define( 'GO_VERGE_ADS_ARTICLE_A8_SLOT', '' );
define( 'GO_VERGE_ADS_ARTICLE_RAIL_MOBILE_SLOT', '' );
```

Zerar A7 e A8 devolve o teto do corpo a sete, porque o teto segue o contrato.
