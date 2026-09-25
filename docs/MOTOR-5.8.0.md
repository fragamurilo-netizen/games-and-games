# Overdrive 5.8.0: motor 3.53 com controles ao vivo

## O que é

A 5.8.0 volta o motor de anúncios ao perfil da **versão 3.53**, que gerou o dia de referência (domingo, 30/08/2026):

| Receita | Pageviews | RPM de página | Impressões | RPM de impressão | Active View |
|---|---|---|---|---|---|
| US$ 199,16 | 41.574 | US$ 4,79 | 272.594 | US$ 0,73 | 54,84% |

A 5.7.0 foi descartada. Os números que a própria 3.53 registrou mostram que ela ia na direção errada (detalhes abaixo).

Tudo o que muda na 5.8.0 fica exposto num painel, para você mexer ao longo do dia. Um botão de refino lê os números do dia e dá um passo por vez.

## O que a 3.53 mediu na sua conta (e por que cada padrão é o que é)

Esses números estão escritos no código da 3.53. Cada um virou um padrão da 5.8.0:

| Fato medido | Padrão na 5.8.0 |
|---|---|
| Display no corpo do artigo: RPM de impressão de US$ 0,13–0,14 (20–26/08). As posições In-article nativas puxavam a média da escada para US$ 0,20. | Corpo do artigo com as **unidades In-article nativas** da conta: as 4 que a 3.53 usava e as 3 que a 5.x usou antes de trocar por Display. |
| Multiplex: 11.710 impressões em 7 dias por US$ 0,66, com 13,96% de Active View, a pior unidade da conta. | **Multiplex desligado.** |
| Pós-conteúdo e trilho empilhado do celular não existiam na 3.53. | **Desligados.** Podem ser ligados no painel. |
| 26/08: 3,88 impressões por página, 58% de Active View e RPM de US$ 2,11 (anúncios pedidos tarde demais). 13/08 e 19/08: 6,9–8,1 impressões por página, ~50% de Active View e RPM de US$ 4,65–5,97. | **Antecedência longa**, como na 3.53: 1,6 tela no P1 e 0,7 no fim do artigo, no celular. |
| Teto de 35% da altura do texto em anúncio. Os 520/600 px de distância valiam só do 10º degrau em diante; os 9 primeiros eram isentos. | Teto de **35%** (a 5.6.7 usava 45%) e piso de 240/300 px nas posições principais. |
| Topo do desktop: pedido como responsivo, o espaço vira um leaderboard de ~90 px. | Topo do desktop em **970×250 fixo**; em tablet, 728×90. |
| Active View explica pouco do preço nesta conta (r = 0,19). CTR (r = 0,90) e a fatia de anúncios de texto (r = 0,86) explicam quase tudo. | O refino não persegue Active View. Ele olha preço e volume. |

**Mantidos:** Top Scroll, Clever, listagens, home, fim do artigo e barra lateral fixa do desktop.

## O painel

Fica em **wp-admin → Ads Center → Motor de anúncios**. Se o Ads Center não estiver no menu, fica em **Ferramentas → Motor de anúncios**.

- **Cada alteração salva vale na hora.** O cache é limpo e as próximas visitas já recebem o motor novo. Se houver CDN além do LiteSpeed, limpe-a também.
- **Tudo fica no histórico**, com quem mudou, quando, o quê e por quê.
- **"Desfazer a última alteração"** e **"Restaurar perfil 3.53"** revertem com um clique.

O que dá para mexer:

- **Corpo do artigo:**
  - formato (In-article ou Display da 5.6.7);
  - número de posições (7 e 8 usam as unidades Display A7/A8);
  - distância mínima entre anúncios;
  - percentual máximo do artigo ocupado por anúncio;
  - anúncios por janela.
- **Antecedência** (quantas telas antes do leitor o anúncio é pedido):
  - por nível e por aparelho;
  - multiplicador geral de celular e de desktop;
  - teto para rolagem rápida;
  - antecedência antes do leitor interagir.
- **Posições:** topo 970×250, anúncio após a imagem de capa, Multiplex, pós-conteúdo, trilho do celular e distância nas listagens.
- **Refino:** mínimo de pageviews, intervalo entre refinos e máximo por dia.

## O botão "Refinar com os números de hoje"

O RPM cai ao longo do dia em qualquer versão do motor, porque o tráfego da noite vale menos e os anunciantes gastam o orçamento cedo. Por isso o botão **nunca compara com a manhã**. Ele compara **a última hora** com a **mesma hora em dias parecidos** (mesmo dia da semana quando há histórico), usando os dados que o Ads Center sincroniza a cada 15 minutos.

O painel mostra essa comparação e o que o botão faria antes de você clicar.

| O que ele vê | O que faz |
|---|---|
| RPM da última hora a menos de 3% do normal deste horário | Nada |
| Valor por impressão caiu e impressões por página subiram (padrão de 11/08) | **Menos densidade:** +60 px de distância, −3 pontos no teto do artigo, −10% de antecedência |
| Impressões por página caíram com preço normal (padrão de 26/08) | **Mais oferta:** −60 px, +3 pontos, +10% de antecedência |
| Preço e volume caíram juntos | Nada: é o mercado, e mais anúncio só compraria impressões mais baratas |
| Cobertura abaixo de 75% | Nada: o Google está recusando pedidos, e densidade não resolve |
| Active View acima de 58% com volume abaixo do normal | Mais oferta |
| Active View abaixo de 46% com volume acima do normal | Menos densidade |

**Travas:**

- dados com até 60 minutos;
- pelo menos 800 pageviews no dia e 150 na última hora;
- pelo menos 3 dias de histórico daquela hora;
- 90 minutos entre refinos, o tempo para a última hora refletir a mudança;
- no máximo 4 refinos por dia;
- limites próprios: distância entre 240 e 600 px no celular, teto do artigo entre 25% e 40%, multiplicador de antecedência entre 0,7 e 1,3.

Todas as travas, exceto esses limites, são ajustáveis no painel.

## Depois de instalar

1. Suba o zip e abra o painel do WordPress uma vez como administrador: isso limpa o cache. Limpe a CDN, se houver.
2. Confira em **Motor de anúncios** se a tabela "Hoje, comparado ao mesmo horário…" mostra números. Se aparecer "Sem números de hoje", a sincronização do Ads Center precisa estar conectada.
3. **Dê um dia inteiro ao perfil 3.53 antes do primeiro refino.** As unidades In-article voltam ao leilão, e o Google precisa de algumas horas para recalibrar os preços delas.
4. Compare o dia fechado com o **mesmo dia da semana** anterior, não com a manhã. O dia 30/08 era domingo, o pico da semana. Compare domingo com domingo.

## Limites honestos

- Nenhum código garante um número do AdSense num dia específico. A 5.8.0 devolve o site à configuração que já produziu os números que você quer e dá ferramentas para ajustar com dados, sem adivinhar.
- O dia 30/08 não tinha o Clever. Ele continua, por decisão sua, e é uma diferença em relação ao dia de referência.
- Se as unidades In-article da 3.53 tiverem sido arquivadas na conta do AdSense, elas voltam vazias. Nesse caso troque o formato do corpo para "Display" no painel.
