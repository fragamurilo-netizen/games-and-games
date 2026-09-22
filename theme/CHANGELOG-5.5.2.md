# Overdrive 5.5.2 — contexto de chegada, primeira pintura e testes por dia

Tema 5.5.2; runtime `12.7.0-context-paint-gate`. A arquitetura de 5.5.x continua
valendo: anúncios manuais nas páginas, âncora e vinheta oficiais da conta, um
único loader, um request por posição por pageview. Nada aqui refresca, repete ou
re-solicita uma posição, e nada aqui esconde criativo pago.

Base: 5.5.1, sem nenhuma alteração na tabela de entrega. O que mudou é *quando* uma posição
pergunta, *quanto espaço* ela já ocupa quando o criativo chega, e — pela
primeira vez — se existe maneira de saber se uma mudança dessas valeu alguma
coisa.

---

## 1. Prior de profundidade pela origem da visita

**O problema.** O modelo de leitor exige três pageviews antes de dizer qualquer
coisa. A maioria das sessões deste site tem uma. Então, justamente nas pageviews
que mais importam, todo cálculo que consome um prior de profundidade caía no
neutro 0,5 — e tratava um leitor que abriu a matéria no Discover, e vai ler até
o fim, exatamente como um visitante de busca que sai em quatro segundos.

**O que passa a acontecer.** O runtime reduz `document.referrer` a um balde
grosso — `internal`, `google-app`, `aggregator`, `search`, `social`, `direct`,
`app`, `other` — e usa o prior daquele balde enquanto o leitor não se move.
Assim que ele rola, a profundidade medida domina, como sempre dominou.

**O que é guardado:** nada. O referrer é lido uma vez, em memória, e só o nome
do balde sobrevive à função. Nenhuma URL, termo de busca, parâmetro ou
identificador é retido, gravado ou transmitido, e por isso isto não depende de
consentimento: não cria armazenamento nem perfil. O diagnóstico mostra o balde,
nunca a origem.

**O que o prior não pode fazer.** Não abre as reservas do planner. A expansão
por "leitor que costuma ler fundo" continua exigindo o histórico do *próprio*
leitor: vir de uma origem que em média lê fundo não é evidência sobre a pessoa
que está lendo agora, e deixar uma média de população decidir isso seria trocar
uma medição por um palpite.

Os valores são conservadores e ficam presos entre 0,35 e 0,72, com peso 0,80
sobre o desvio em relação ao neutro. Ajuste-os contra a analytics do próprio
site pelo filtro `go_verge_ads_entry_context_priors` — quem tem tráfego social
que lê fundo deve dizer isso ali em vez de aceitar o padrão.

## 2. Portão de primeira pintura — **DESLIGADO por padrão**

> **Por que vem desligado.** Houve um relato de "os anúncios manuais não
> aparecem" nesta versão que **não consegui reproduzir**: em WordPress limpo, o
> HTML emitido é idêntico ao de 5.5.1 e o runtime se comporta igual no Chromium
> (mesmas unidades montadas, pedidas e preenchidas, zero erros). Como este é o
> único guarda da versão capaz de ADIAR um pedido, e o único cujo ganho (LCP)
> não foi medido no campo deste site, ele vem desligado. Ligue só depois de
> confirmar que os anúncios aparecem:
>
> ```php
> add_filter( 'go_verge_ads_cwv_guards', function ( $g ) {
>     $g['paint_gate'] = true;
>     return $g;
> } );
> ```

Uma posição **não crítica**, **fora da viewport** e a **mais de meia tela** da
dobra espera a primeira pintura assentar antes de pedir. É o único caso em que
um request de anúncio disputa soquetes, decodificador e main thread com o
elemento que decide o LCP e não ganha nada com isso: o leitor não vai ver aquele
criativo por vários segundos.

O portão solta no que vier primeiro — a entrada de `largest-contentful-paint`
mais uma carência de 250 ms, a primeira interação real (que é o que finaliza o
LCP para o navegador de qualquer forma), ou o teto de 1,2 s. Um navegador sem
`PerformanceObserver`, um documento que nunca pinta candidato e um observador
bloqueado se comportam todos igual: o teto solta.

**A oferta não muda.** É adiamento com prazo, nunca cancelamento. Passam
intactos: inventário crítico, qualquer host visível, qualquer host que chegue
antes do que um criativo levaria para renderizar, e tudo a menos de meia tela da
dobra — a mesma régua que o *critical hold* já usava, porque um portão mais
severo que o vizinho apenas atrasaria posições que o leitor está prestes a
alcançar.

Desligue com `go_verge_ads_cwv_guards` se precisar comparar contra 5.5.1.

## 3. Reserva no momento do pedido

A escada do corpo (P1, A1–A6) declara reserva zero de propósito: uma unidade que
não preenche não pode deixar buraco no meio da matéria. O efeito colateral era
que o host ficava com altura zero durante toda a ida e volta, então **a chegada
do criativo era a própria mudança de layout**. Invisível enquanto o host está
abaixo da dobra; um salto visível no instante em que o leitor alcança o host
antes da resposta — que é exatamente o que uma rolagem rápida numa conexão lenta
produz.

Agora o espaço previsto é reservado **no pedido**, e **somente enquanto o host
está inteiramente abaixo da viewport útil**, onde crescer não desloca nada que o
leitor possa ver. Quando o criativo chega, `fitFilled()` troca a estimativa pela
altura real; quando o Google responde `unfilled`, o host colapsa para nada como
sempre colapsou. Uma posição que ainda não pediu continua ocupando zero.

## 4. Limite de frequência vale onde foi declarado

`persistFill()` gravava o preenchimento de **qualquer** posição que declarasse um
limite de frequência, mas só o Top Scroll lia esse histórico de volta. Um limite
configurado em outra unidade acumulava dias de dados que nada jamais aplicava: a
opção existia na configuração e não existia na entrega. Leitura e escrita agora
concordam.

Isto **não muda nada hoje** — só o Top Scroll declara limite nesta configuração.
Muda o que acontece quando alguém declarar um segundo.

A chave de armazenamento mantém o nome legado (`go_adsense_topscroll_24h_<slot>`)
embora seja por slot: renomeá-la órfãozaria os contadores que leitores reais
estão carregando e daria a todos eles uma cota nova de 24 horas no dia da
atualização.

## 5. Testes por dia de calendário

**A lacuna.** O motor não tinha como responder à única pergunta que interessa
depois de um release: rendeu mais? Comparar "antes" e "depois" não responde,
porque mix de tráfego, demanda e sazonalidade se movem entre os dois períodos, e
nenhum cuidado separa isso da mudança. Sem um desenho que segure essas coisas
constantes, uma nota de versão só consegue dizer o que o código passou a fazer,
nunca quanto aquilo valeu.

**O que NÃO é.** Não é divisão de audiência. Não há sorteio de grupos, bucket por
leitor, cookie, canal de anúncio nem segundo bootstrap — aquele desenho foi
removido deste tema de propósito e continua removido. Dois leitores que abrirem a
mesma página no mesmo minuto recebem exatamente a mesma configuração.

**O que é.** O calendário é a unidade de atribuição. Um dia inteiro roda um
braço; o dia seguinte roda o próximo. Todo leitor daquele dia vê o mesmo motor, e
o relatório **por dia** do AdSense — que o Ads Center já sincroniza — separa os
braços sozinho, com a receita real do publisher, sem dimensão customizada e sem
nada para o tema contar.

Como o rodízio anda um dia por vez e a semana tem sete, dias consecutivos caem em
dias da semana diferentes: em catorze dias um teste de dois braços dá a cada
braço cada dia da semana exatamente uma vez, e o fim de semana entra nos dois
lados em vez de pertencer a um. Essa propriedade é a razão de o rodízio ser
diário e não semanal, e tem teste próprio.

**O que continua não podendo.** Os dias não são aleatorizados e um dia de
calendário não é unidade controlada: um ciclo de notícias, uma queda ou uma alta
no Discover pertencem ao braço dono daquela data. O desenho remove o que varia
devagar — dia da semana e, com rodadas suficientes, tendência e sazonalidade.
Não remove um evento de um dia só e **não estabelece causa**.

**Segurança.** Um braço só move chaves de tempo e espaçamento
(`rest_lead_vh`, `min_gap_px`, `request_spacing_ms`, `max_lookahead_vh`,
`flick_vh_s`, `engage_*`). O envelope de densidade — `max_units_in_window`,
`max_local_ad_ratio`, `max_ad_to_content_ratio` — **não é ajustável por um
teste**: um experimento não pode responder "mais aperto rende mais" apertando a
página. O runtime re-limita todo valor que recebe, venha de onde vier.

Um teste inválido não roda pela metade: sem data de início, com menos de dois
braços, com a linha de base alterada ou com dois testes habilitados ao mesmo
tempo, **nenhum** roda e a tabela publicada vale.

**Como usar.** Declare pelo filtro `go_verge_ads_trials` (há um exemplo
comentado e desligado em `inc/ads/calendar-trials.php`). O primeiro braço é a
linha de base e não sobrescreve nada. Leia o resultado em **Ads Center → Testes
por dia**: totais por braço e, mais importante, a **comparação emparelhada por
rodada**. A contagem de rodadas a favor vale mais que a média — perto de metade,
a diferença é ruído do dia a dia por maior que a média pareça.

**O pacote não vem com teste ligado.** Instalar 5.5.2 não muda a entrega por
conta disto.

## 6. Altura lembrada por unidade — o CLS do masthead

Medido em laboratório, num artigo real: **`site-masthead` reserva 132 px no
mobile e o criativo chega com 250 px**. Os 118 px de diferença empurram a
matéria inteira para baixo — **0,0362 de CLS, acima da dobra**, que era quase
todo o deslocamento da página (o total com anúncios era 0,0389; sem o motor de
anúncios, 0,0031).

Reservar 282 px sempre trocaria o deslocamento por um buraco de 182 px toda vez
que viesse criativo curto. Então o motor passa a **lembrar a altura que cada
unidade realmente recebe** e reservar essa na visita seguinte. Uma unidade que
serve 100 px mantém os 132 px; uma que serve 250 px para de empurrar a página.
Corrige-se sozinha quando o mix da conta muda.

Escopo deliberadamente estreito:

- **só** unidades que já declaram reserva no servidor — onde o publisher já
  decidiu que espaço reservado é aceitável. A escada do corpo mantém reserva
  zero e a reserva no momento do pedido;
- **só** com permissão de armazenamento, como toda memória aqui;
- **só** de respostas `filled` — unidade vazia não tem altura a ensinar;
- **só para cima**, a partir do valor declarado, e com teto: pode dar o tamanho
  certo a uma caixa que já existe, nunca criar um buraco onde não havia.

Muda **reserva**, nunca se/quando/o que uma unidade pede.

Medição, mesmo artigo, Slow 4G + CPU 4×:

| | CLS |
|---|---|
| 1ª visita (sem nada aprendido) | 0,0394 — igual ao anterior, sem regressão |
| 2ª visita em diante | **0,0031** |

Queda de **92%**, e zero custo enquanto não há o que aprender.

## 7. Cópia pública enxuta do runtime

O runtime é inlinado em todo documento monetizável — cada byte é reenviado e
re-parseado a cada pageview, antes do body. Medindo o `<head>` de uma matéria
real: **100 kB de JavaScript inline, dos quais 89 kB eram o motor de anúncios**.
É o maior custo de main thread que o tema controla.

E um sexto desse motor é `inspect()`, `explain()` e o snapshot de diagnóstico —
superfície de **operador**, que um leitor anônimo nunca consegue chamar.

O gerador passa a emitir **dois arquivos a partir da mesma fonte**:

| | arquivo | servido a |
|---|---|---|
| completa | `go-ads-runtime.min.js` | administrador logado |
| enxuta | `go-ads-runtime.lean.js` | todo o resto |

**92,0 kB → 77,9 kB: 15,3% menos para parsear em toda pageview anônima.**

A troca só é aceitável enquanto a cópia pública decidir a entrega exatamente
como a auditada — uma cópia que pedisse de menos seria invisível justamente por
ser a cópia sem diagnóstico. Então `tests/runtime-lean-parity.test.js` roda os
dois arquivos pelos mesmos cenários, em processos separados, e compara **o que
fizeram** lendo o DOM: pedido, ordem, status do provedor, colapso de vazio,
liberação por silêncio do provedor, rejeição por densidade. `inspect()` não
existe do lado enxuto por construção, então não há como comparar relatos — só
comportamento. Guardas estáticos exigem que todo portão de entrega
(`activate`, `densityAllows`, `exposureAllows`, `budgetAllows`, `paintHold`,
`criticalHold`, `pacingAllows`, `rangeInfo`, `evaluateGovernor`,
`reachedReserveAllows`, `topScrollSmartAllows`) continue inteiro na cópia
pública, e que só o diagnóstico saia.

A cópia enxuta ainda responde `GOAdsRuntime.inspect().version`, então a
verificação documentada de instalação continua funcionando numa página pública,
e diz onde está o detalhe. Rollback: `go_verge_ads_serve_full_runtime`.

## 8. Runtime menor

O runtime é inlinado em todo documento monetizável, então cada byte dele é
reenviado e re-parseado a cada pageview, não uma vez por cache. O gerador
(`tests/build-runtime-min.js`) ganhou um passe de compressão de espaços ciente
de literais: nenhum identificador é renomeado, nenhuma instrução se move, e nada
dentro de string, template ou regex é tocado.

| | 5.5.1 | 5.6.0 |
|---|---|---|
| Runtime de produção (bytes a parsear) | 93,3 kB | 92,0 kB |
| O mesmo, comprimido (bytes na rede) | 24,8 kB | 25,7 kB |

Os cinco itens acima entraram e o arquivo **a parsear** ainda encolheu 1,3 kB —
que é o número que custa main thread em telefone. **Comprimido ele cresceu
0,9 kB**, porque o código novo é código novo: a compressão do documento
aproveita bem a repetição, e o passe de espaços mexe pouco no que o gzip já
resolvia. Ou seja: o ganho aqui é de parse, não de rede, e a rede pagou um
pouco. Sem o passe de compressão o arquivo teria ido a 98,8 kB. A cópia gerada é
verificada contra a suíte inteira do runtime a cada release, além do guardião
estático que compara o caminho de request ignorando espaçamento.

---

## Verificação depois de instalar

1. Tema 5.5.2 e `GOAdsRuntime.inspect().version === '12.7.0-context-paint-gate'`
   numa página elegível.
2. `GOAdsRuntime.inspect().engine.governor.entryContext` — deve mostrar o balde
   da origem e nenhum fragmento de URL.
3. `GOAdsRuntime.inspect().paintGate.enabled` — deve ser `false` numa instalação
   limpa. Se for `true`, alguém ligou o portão por filtro.
4. `GOAdsRuntime.inspect().trial` — `null` enquanto nenhum teste estiver ligado.
5. Abrir uma matéria normal e uma review/crítica/especial no desktop: Masthead,
   texto, hero, CTA e ausência de sobreposição continuam como em 5.5.1.
6. Invalidar cache de página, LiteSpeed/CDN e assets: HTML antigo carrega o
   runtime antigo inline.

Nenhum teste de laboratório aqui prova mais receita, preenchimento real ou Core
Web Vitals de campo. Metas de campo seguem as mesmas: LCP ≤ 2,5 s, INP ≤ 200 ms
e CLS ≤ 0,1, no percentil 75 por dispositivo. O portão de primeira pintura e a
reserva no pedido atacam LCP e CLS por mecanismo, o que não é o mesmo que
medi-los em campo — meça.

## Rollback

Reinstalar o ZIP anterior e invalidar as mesmas camadas de cache. Nenhuma opção
nova é gravada por esta versão: prior de origem, portão de pintura, reserva no
pedido e testes por dia são todos configuração em código, via filtro. Voltar os
arquivos basta.

Para desligar item a item sem voltar de versão:
`go_verge_ads_entry_context_priors` (`enabled => false`),
`go_verge_ads_cwv_guards` (`paint_gate => false`, `reserve_on_request => false`),
`go_verge_ads_trials` (`enabled => false`).
