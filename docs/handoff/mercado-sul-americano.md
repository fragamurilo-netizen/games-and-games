# Mercado e futebol sul-americano (05/10/2026)

Ramo: `claude/mercado-sulamericano-1ipxqh`, sobre a linha 1.0.0 (`claude/youthful-newton-hey7og`).

## O que mudou

- **Mercado parado de janeiro a março (bug).** Na carreira de calendário de ano civil (Brasil e
  América do Sul), os fins de semana dos estaduais não eram "fim de semana" para o jogo: o mercado,
  as propostas pelo elenco do usuário e a contagem das lesões só rodavam nas duas últimas datas da
  janela de janeiro. Era a suspeita antiga de "clubes da IA sem transferências em 3 rodadas".
  Agora o mercado e o departamento médico andam nesses fins de semana
  (`SeasonState.is_state_weekend`, `SeasonManager` no processamento da data).
- **Janela principal de cada clube.** O plano da janela era refeito no meio da janela de janeiro
  (o código achava que a data 10 era outra janela). Agora a janela é identificada pelo índice e
  cada clube monta o elenco na pré-temporada da própria liga: janeiro na América do Sul, julho na
  Europa (`MarketAI.window_index`, `MarketAI.is_main_window`).
- **Menores de 18** (`scripts/systems/transfer_rules.gd`). Ninguém se muda de país antes dos 18
  (dentro da UE, a partir dos 16). Clube estrangeiro pode comprar antes: paga na hora e o garoto
  fica emprestado ao clube de origem até a temporada em que faz 18 (`Player.loan["fut"]`). Vale para
  a IA, para as compras do usuário e para as propostas que o usuário aceita. Perfil, elenco e
  contratos mostram "Vendido ao X, chega em AAAA".
- **Garimpo de joias.** Clubes europeus de porte (reputação 64+, com rota sul-americana em
  `market.json`) às vezes buscam garotos de até 20 anos e potencial alto nos países de origem
  (`MarketAI.hunts_jewels`, `_draw_jewel`, índice `young`).
- **Mecanismo de solidariedade.** 5% das vendas internacionais vão para os clubes que registraram o
  jogador dos 12 aos 23 anos, descontados do vendedor. Entra nas finanças como "Solidariedade da
  FIFA" e o usuário recebe notícia quando ganha.
- **Promedios na Argentina.** `leagues.json` → `"promedios": true` no ARG1. Caem o pior promedio
  (pontos por jogo nas 3 últimas temporadas na elite) e o último da tabela anual. A tabela da liga
  mostra o quadro "Promedios" e a faixa de rebaixamento da tabela fica só no último.

## Como medir

`godot --headless --path . --script res://tools/market_sa_report.gd -- [--days=N] [--seasons=N] [--cal=eu]`
mostra negócios por data, para onde vão os sul-americanos, idades das vendas para a Europa, maiores
vendas, solidariedade, vendas antecipadas e o rebaixamento argentino.

## Saves antigos

Nada novo é obrigatório no save: a marca "we" dos estaduais é deduzida pelo dia da semana, os
campos novos de empréstimo têm padrão e os promedios usam o histórico que os clubes já guardam.
