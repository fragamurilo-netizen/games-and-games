# Referências para comportamento de luta — 29/09/2026

Base: Game Design Bible §6 e MMA Research Bible §§7,20–21. Esta análise usa
relatos oficiais, resultados e regras, não uma alegação de ter assistido a
filmagens completas. Atletas reais não são conteúdo do jogo.

| Evidência consultada | Observação | Tradução proposta para Corner Office |
|---|---|---|
| [Oliveira–Chandler, UFC 262](https://www.ufc.com/news/10-ufc-lightweight-title-fights-oliveira-mcgregor-nurmagomedov-penn) | Defesa de guilhotina, tomada das costas, knockdown sofrido e sobrevivência precederam uma virada por golpes no R2. | Dano e perigo não são vitória automática. Recuperação, posição defensiva, pressão e sequência de golpes devem importar. |
| [Makhachev–Poirier, UFC 302](https://www.ufc.com/news/main-card-results-highlights-winner-interviews-ufc-302-makhachev-vs-poirier) | Controle das costas no início não encerrou a luta. A defesa de quedas manteve a disputa; a finalização veio no R5 após mudança de guilhotina para D’Arce. | Finalizações passam por ameaça, defesa, progressão e possível troca de técnica. Controle isolado não garante finalização. |
| [Zhang–Jędrzejczyk, UFC 248](https://www.ufc.com/news/ufc-248-results-adesanya-romero-zhang-jedrzejczyk) e [retrospectiva oficial](https://www.ufc.com.br/news/the-10-standout-strawweight-title-fights) | Cinco rounds de trocas competitivas terminaram em decisão dividida. Os três cartões foram 48–47; apenas o terceiro round teve consenso dos três juízes. | Uma luta movimentada pode ir à decisão. Juízes leem os mesmos eventos e diferem ligeiramente na avaliação de rounds próximos; o resultado não é um sorteio separado. |
| [ABC, esclarecimento de julho de 2025](https://www.abcboxing.com/wp-content/uploads/2025/08/ABC-MMA-Scoring-Criteira-Clarification-7.2025.pdf) | O efeito ofensivo determina a avaliação de striking e grappling. Defesa, por si, não recebe pontuação ofensiva. | Acertos relevantes e ameaças efetivas pesam; posse de posição e agressividade não substituem impacto ofensivo. |
| [Regras unificadas — CSAC](https://www.dca.ca.gov/csac/forms_pubs/publications/unified_mma_rules.pdf) | Submissão, interrupção técnica e decisão são caminhos distintos para encerramento. | Razões finais distintas, interrupção do árbitro e fim imediato das trocas após resolução. |

As equações, probabilidades e tempos utilizados no protótipo são parâmetros de
design para teste, não estimativas médicas nem uma calibração estatística dessas
lutas. As referências orientam estrutura e variedade de comportamentos.

## Critérios de aceitação

- Sem combate por Overall; técnica enfrenta defesa específica e contexto.
- Cabeça: impacto, abalo recuperável e acúmulo. Corpo: reserva e recuperação.
  Pernas: mobilidade/base. Sangue/cortes são sinais visuais, não outro HP.
- Tentativas de finalização com defesa e progressão, em posições compatíveis.
- KO, TKO, submissão e decisões com reason codes e eventos reproduzíveis.
- Mesma seed e inputs produzem o mesmo resultado; velocidade/câmera não alteram.
- Pausas, fintas, entradas, contra-ataques, controle e escapes entre ofensivas.
- Articulações conectadas, comprimentos constantes, pés apoiados e mãos retornando
  à guarda; nenhum ataque visual em resultado que o motor marcou como erro.
