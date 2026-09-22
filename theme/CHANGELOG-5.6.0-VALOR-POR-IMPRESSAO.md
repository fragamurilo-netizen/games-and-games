# Overdrive 5.6.0 — motor de anúncios focado em valor por impressão

Tema `5.6.0` · runtime `13.0.0-value-first` · planner/contrato `20.0.0-value-first`.
Instale por cima da 5.5.14 (mesmo tema). Não muda IDs, conta AdSense, consentimento nem Top Scroll.

## 1. Correção crítica: o runtime inline estava quebrado em produção

O plugin **Burst Statistics** procura a primeira ocorrência de `<body` no HTML e injeta
`data-burst_id="…" data-burst_type="…"` antes do próximo `>`. O runtime minificado da 5.5.14
continha `countOccupied(isBodyRecord)<bodyBudget()`: o plugin escrevia os atributos **dentro do
JavaScript** do motor. Resultado, conferido no HTML público de 22/09/2026 (home e 10 matérias):

- `SyntaxError: Unexpected identifier 'data'` em toda página pública;
- o motor inline nunca iniciava; os anúncios só começavam depois que o script de recuperação do
  rodapé baixava o arquivo-fonte de 150 KB — atraso em todas as posições, justamente as do topo,
  que são as de maior valor;
- a tag `<body>` real ficava sem os atributos do Burst (estatística por post também afetada).

Correções:

- Novo build (`tools/build-runtime.js`, fora do ZIP) com terser: runtime público **53 KB** (antes
  80 KB) e o build **falha** se sobrar qualquer `<` seguido de letra, `/`, `!` ou `?`.
- `assets.php` só imprime inline um runtime que passe nessa mesma regra; caso contrário serve o
  arquivo externo — nunca mais um runtime corrompível no `<head>`.
- O tema não usa mais o arquivo-fonte comentado como fallback inline por causa de data de
  modificação (upload por FTP/gerenciador bagunça mtime). A recuperação no rodapé usa a cópia
  gerada (3x menor).
- Nova verificação em **Ads Center → Entrega & Saúde**: “O runtime de anúncios chega intacto aos
  leitores” — lê a home anônima e compara o JavaScript publicado com o arquivo do tema; aponta
  crítico se algum plugin voltar a alterá-lo.

Na simulação local com as páginas reais, o motor fica pronto em ~50–130 ms após o início da
página, em vez de ~1–2 s pelo caminho de recuperação.

## 2. Menos impressões desperdiçadas durante rolagem rápida (Active View)

A previsão de chegada multiplicava a velocidade instantânea do dedo (2.000–4.000 px/s num
“flick”) por toda a latência do provedor (~1,6 s) e pedia anúncios **2 a 3 telas à frente**. O
leitor para bem antes: na simulação, esses anúncios eram preenchidos e **nunca apareciam na tela**.
Impressão servida e não vista reduz o Active View da unidade e o lance que os compradores fazem
nela — é perda de preço, não só de uma impressão.

- A previsão agora projeta **onde o gesto vai parar** (velocidade × constante de desaceleração:
  `fling_tau_s` 0,35 s no celular, 0,30 s no desktop) e aplica a antecedência normal a partir desse
  ponto.
- Teto preditivo: 1,8 tela no celular (antes 3,0) e 1,6 no desktop (antes 2,6).
- Leitor parado ou lendo continua recebendo o anúncio antes de chegar (antecedência por tier
  inalterada); posições críticas do topo inalteradas.

## 3. Escada do corpo onde os leitores estão (sem aumentar a quantidade)

O teto continua **P1 + A1–A6** (A7/A8 seguem desligados — valor antes de volume). O que muda é a
posição em matérias longas. A 19.x espalhava as sete posições por percentuais do texto: num guia de
3.600 palavras, o primeiro quinto (≈ 5 telas, lido por quase todos) tinha só o P1, e A4–A6 ficavam
depois da metade, onde poucos chegam.

Agora cada alvo é o **mais cedo** entre o percentual antigo e uma cadência de leitura de
240 palavras (≈ 1,8 tela de celular; filtro `go_verge_ads_planner_reach_spacing_words`). Matérias
até ~1.600 palavras ficam **idênticas** à 5.5.14. Exemplo real (`quanto-custa-ter-carro-eletrico-2026`):

| | P1 | A1 | A2 | A3 | A4 | A5 | A6 |
|---|---|---|---|---|---|---|---|
| 5.5.14 (palavras) | 65 | 780 | 1261 | 1553 | 2074 | 2451 | 2914 |
| 5.6.0 (palavras) | 65 | 190 | 593 | 780 | 1019 | 1261 | 1489 |

Todas as regras de densidade (espaçamento mínimo, janela, proporção) continuam valendo no navegador.

## Instalação

1. Backup do tema atual. Aparência → Temas → Adicionar → Enviar o ZIP e substituir (ou enviar os
   arquivos para a mesma pasta do tema, como vem sendo feito).
2. **Limpar cache de página do LiteSpeed/CDN** — o runtime é inline; HTML antigo em cache mantém o
   runtime quebrado.
3. Conferir numa matéria anônima (aba anônima): console sem `SyntaxError`, e
   `GOAdsRuntime.inspect().version === '13.0.0-value-first'`.
4. Ads Center → Entrega & Saúde → executar verificações: o item de integridade do runtime deve ficar
   verde.

## O que acompanhar

Compare dias fechados equivalentes (mesmo dia da semana) antes/depois: **Active View**, RPM de
impressão, Page RPM e impressões/PV, separando mobile e desktop. Espera-se Active View e RPM de
impressão mais altos; impressões/PV podem ficar estáveis ou cair levemente em leitores rápidos
(eram impressões não vistas) e subir em guias longos. Simulações validam lógica e timing, não
leilão real.

## Rollback

Reinstalar o ZIP 5.5.14 e limpar o cache. Não há migração de banco nesta versão.
