# Modo Presidente — como é a vida de quem manda numa organização (e o que falta no jogo)

Pesquisa para a próxima tarefa: deixar o modo Presidente **realista e divertido**. O jogador é
"o Dana White" da Liga Global. Tudo no jogo é fictício (nomes, organização, lutadores); a
referência é como o cargo funciona de verdade.

## Como o cargo funciona de verdade (resumo)

**História que vira mecânica**
- O presidente começa com uma organização quase falida e transforma em potência. Na vida real, a
  virada veio de um reality show de lutadores (a final virou uma guerra que salvou a empresa).
- Depois vêm a venda da empresa para um grupo de mídia, a fusão com outra marca de entretenimento
  e os contratos bilionários de TV/streaming. O presidente responde a donos com metas de receita.

**O dia a dia**
- **Casamento de lutas (matchmaking):** há casamenteiros, mas as lutas grandes são decisão do
  presidente. Regras informais: campeão tem que defender, quem para muito tempo perde o cinturão
  (cinturão interino quando o campeão se machuca), "a luta que faz sentido" vence o ranking.
- **Semana da luta:** treino aberto, dia de mídia, coletiva de imprensa, pesagem oficial de manhã e
  a pesagem cerimonial à tarde. Problemas típicos: lutador que **não bate o peso** (multa de 20 a
  30% da bolsa para o adversário, luta em peso combinado ou cancelada), **lesão na semana** (troca
  por substituto de última hora, que ganha bônus por aceitar), visto negado, doença, briga na
  coletiva. Já houve evento inteiro cancelado porque a luta principal caiu e ninguém aceitou trocar.
- **Coletiva pós-luta:** o presidente anuncia os bônus da noite (luta da noite e duas performances),
  às vezes dá dinheiro extra na hora, fala de público e renda recorde, critica os juízes, diz que
  alguém deveria se aposentar e anuncia a próxima luta grande. É o momento de "dar o tom".
- **Olheiro de luxo:** programa de verão em que prospectos do circuito regional lutam numa arena
  pequena e o presidente dá o contrato ali, ao vivo, para quem impressiona. Também assiste a
  eventos regionais atrás de talento.
- **Contratos:** exclusivos, por número de lutas, com bolsa fixa + bônus de vitória, cláusula de
  campeão (renova automaticamente quem tem o cinturão), direito de igualar oferta de rival.
  Brigas por pagamento são comuns; estrelas saem para ligas rivais quando não chegam a acordo.
- **Negócio:** renda de ingressos, pay-per-view (ou assinatura, quando o contrato de TV muda o
  modelo), patrocínios (inclusive o uniforme oficial), taxa paga por cidades/países que querem
  sediar eventos (Oriente Médio paga muito), arena própria para os eventos menores.
- **Datas fortes:** a "semana internacional da luta" no meio do ano, eventos numerados redondos
  (100, 200, 300) com cards empilhados, eventos em lugares inusitados (arena-espetáculo,
  locais históricos).
- **Abrir divisões:** a organização já disse "mulher nunca vai lutar aqui" e depois contratou uma
  estrela feminina que vendeu mais que todo mundo. Novas categorias nascem de um reality ou de um
  torneio.
- **Antidoping:** teste positivo suspende o lutador e anula a vitória (vira "sem resultado").
- **Holofote:** o presidente é celebridade, vive na beira do octógono, discute com lutadores pela
  imprensa (desafetos, rivalidades com estrelas que pedem demais).

## Mecânicas propostas (em ordem de impacto)

1. **Semana da luta com imprevistos** (o coração do modo). Cada noite tem uma chance de incidente
   antes do sábado, mostrado no Início do presidente como uma decisão:
   - *Lesão na semana:* escolher um substituto (lista dos que estão prontos, com chance de aceitar
     e um "prêmio por aceitar em cima da hora"), passar a luta para outra noite ou tirar do card.
     Hoje `Development._injure` chama `Career.cancel_bout` direto — no modo Presidente, trocar por
     um evento de decisão.
   - *Não bateu o peso:* seguir em peso combinado (multa de 20% vai para o adversário, que pode
     recusar), ou cancelar. `Career.weigh_in` já calcula o corte; falta a decisão.
   - *Briga na coletiva / declaração polêmica:* mais interesse (PPV sobe), risco de multa da
     comissão e de o lutador se irritar com a organização.
2. **Coletiva pós-luta** (tela depois da noite, em `night_screen.gd` › `_report`): 2 ou 3 falas para
   escolher, cada uma com efeito: dar bônus extra a alguém (custa, melhora a relação e a fama dele),
   criticar os juízes (fãs gostam, comissão não), anunciar a revanche/luta seguinte (marca a luta
   na hora), mandar alguém se aposentar (veterano pode se ofender ou aceitar).
3. **Programa de verão de olheiro** ("Contender"): 8 a 10 terças no meio do ano; o jogador vê 5
   lutas de prospectos do regional (motor já existe, modo espectador já existe) e escolhe a quem
   dar contrato. É o caminho natural do modo "acompanhar carreiras" de baixo para cima.
4. **Contratos da organização:** número de lutas, bolsa, cláusula de campeão, fim de contrato com
   renovação ou saída para a liga rival (criar uma "Liga Rival" no tier 1 que rouba estrelas).
   Humor/relação de cada lutador com o presidente (pagamento, cancelamentos, defesa da imagem).
5. **Cinturões vivos:** cinturão interino quando o campeão fica fora mais de ~20 semanas, tirar o
   cinturão de quem recusa lutas, superluta entre campeões de categorias vizinhas, campeão duplo.
6. **Metas dos donos e contrato de TV:** metas anuais (receita, compras, mercados novos); renovação
   do contrato de TV a cada N anos pelo prestígio; mudança de modelo de PPV para assinatura
   muda como a noite rende.
7. **Cidades que pagam para sediar** (taxa de sede por evento), arena própria barata para noites
   menores, evento numerado redondo com card empilhado e bônus de público.
8. **Reality show anual** com dois técnicos rivais (que lutam na final) e 16 prospectos: gera
   histórias, contratações e uma rivalidade pronta.
9. **Antidoping** (suspensão, resultado anulado) e **polêmicas de arbitragem** (o resultado não
   muda, mas dá para pagar o bônus de vitória mesmo assim).

**Princípio de diversão:** toda mecânica vira uma *escolha com custo* e uma *manchete*. O jogador
acompanha carreiras como fã; a função de presidente é o jeito de mexer nelas.

## Onde mexer no código

- Regras do modo: `scripts/systems/org.gd` (cards, ofertas, aceitação, finanças, fechamento da noite).
- Semana: `Career.advance_week` (já chama `Org.weekly`, `Org.delegate_fill`, `Org.close_event`).
- Lesão e cancelamento: `Development._injure` → `Career.cancel_bout`; pesagem: `Career.weigh_in`.
- Telas do presidente: `org_hub_screen.gd` (Início), `night_screen.gd` (noite, bônus e relatório),
  `book_screen.gd` (marcar luta), `org_event_screen.gd` (card), `titles_screen.gd` (cinturões).
- Kit de interface: `scripts/ui/org_kit.gd`. Simulação: `tools/world_sim.gd -- --role=presidente`.
  Capturas: `tools/design_shots.gd -- --role=presidente`.
