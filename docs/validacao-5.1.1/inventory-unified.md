# Inventário unificado: hub e continuação de listagens

## Resultado

O posicionamento após o hero do hub editorial passa a ser parte normal da versão pronta. Ele usa a mesma função e o mesmo pool de F1–F5 dos arquivos editoriais. Não exige adesão a grupo, canal experimental, constante experimental ou ajuste posterior do usuário.

A integração fica em `ready/work/inc/ads/composer.php:407–430`. Nesta etapa, somente o composer e `tests/test-listing-continuation.php` foram alterados. A escada do corpo, densidade, IDs, cadência, renderer, templates e endpoints AJAX não foram modificados por esta frente. As bases em `evolution` e `audit/original` foram preservadas.

## Fronteira confirmada e correção da paginação

O template do hub renderiza um hero com posts reais e fecha o bloco antes de emitir `go_verge_editorial_hub_after_hero` (`inc/editorial-layouts.php:953–963`). O anúncio resultante fica em fluxo entre esse conjunto editorial e os módulos seguintes. Ele não é colocado sobre a imagem, dentro de um card ou dentro de um CTA.

Foi identificada uma sutileza que impedia simplesmente remover o bloqueio anterior: quando existe `desk_context`, o template passa `1` como página ao hook mesmo com o feed em página posterior. Esse contexto obtém a página de `pagina`, `paged` ou `page` (`inc/editorial-desk-formats.php:57–91`).

O composer agora exige todas as condições abaixo:

- Requisição inicial, fora do endpoint AJAX.
- Lista de IDs do hero com pelo menos um ID positivo após normalização.
- Primeira página no argumento do hook.
- Primeira página nas query vars reais do documento.
- Primeira página no contexto do desk, quando ele existe.
- Contexto monetizável e unidade elegível conforme os controles já aplicados pelo renderer.

Isso evita habilitar o posicionamento em uma fronteira inexistente ou em página posterior disfarçada pelo argumento fixo do template. O estado `hero` da requisição continua compartilhado entre o hook do arquivo e o hook do hub: repetir um deles, ou chamar os dois, não consome outra identidade.

## Distribuição resultante

| Página inicial | Distribuição do pool | Continuação |
|---|---|---|
| Home com 10 cards | F1/F2/F3 depois das linhas 3/6/9 | F4 depois da 12 e F5 depois da 15 |
| Hub válido com hero e 10 cards | F1 após hero; F2 na 3; F3 na 7 | F4 depois da 11 e F5 depois da 15 |
| Hub sem hero ou em página posterior, 10 cards | F1 na 3; F2 na 7 | F4 depois da 15 e F5 depois da 19, conforme manifesto existente |
| Hub válido com F1 desabilitado | F2 ocupa a fronteira do hero; F3 na 3; F4 na 7 | F5 depois da 11 |
| Pool já consumido | Nenhuma identidade adicional | Nenhum reinício de F1 |

A tabela descreve hosts manuais, não impressões garantidas. O runtime ainda decide se e quando cada host pode gerar uma solicitação.

O manifesto de F4/F5 continua sendo criado no documento inicial e permanece inerte até o número real de cards ser alcançado. O runtime mantém a vinculação à raiz original, identifica cards editoriais de verdade e preserva IDs já registrados. Os endpoints AJAX continuam sem unidades publicitárias; não foram acrescentados offsets publicitários do navegador nem reset de sequência.

## Referências removidas

A constante `GO_VERGE_ADS_HUB_HERO_EXPERIMENT`, o filtro `go_verge_ads_hub_hero_experiment`, a descrição experimental do hook e os cenários `hub-off`/`hub-on` foram removidos desta implementação. A busca em toda a árvore `ready/work` não encontrou referências restantes a esses controles ou a instruções de experimento específicas do hub.

Não foi criada uma nova chave operacional para esse posicionamento: a versão pronta aplica a integração normal e utiliza os mecanismos existentes de elegibilidade, estado e pool. O limite continua sendo de cinco identidades de listagem por documento.

## Validação executada

| Verificação | Resultado |
|---|---|
| `test-listing-continuation.php` | 18 cenários, 216 asserções aprovadas |
| `test-listing-fallback.php` | 17 asserções aprovadas |
| `test-composer.php` | 19 asserções aprovadas |
| Lint do composer e do teste alterado | Aprovado em PHP 8.3.6 |

Os cenários cobrem integração normal sem configuração, ausência de hero, IDs zero, página do hook, página real do desk, query vars, AJAX, hooks repetidos, F1 desabilitado, IDs duplicados, pool esgotado, reservas F4/F5 e rollback convencional da continuação. O consentimento original permanece serializado nas opções das unidades pendentes. O log está em `ready/analysis/listing-continuation-validation.txt`.

Nenhuma requisição publicitária real foi realizada. A validação comprova a lógica e a distribuição esperada no HTML simulado; não mede receita, preenchimento real, Active View, criativos ou Core Web Vitals de campo.
