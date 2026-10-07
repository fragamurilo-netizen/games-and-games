# Noite de Luta — nota de passagem (07/10/2026)

Trabalho interrompido no meio a pedido do dono, para outro colega continuar. Ramo:
`claude/festive-maxwell-iuncob` (parte do commit 9a1fbe9 do ramo `claude/inspiring-wright-xx78jb`).

## Decisões do dono

- O jogo é **muito inspirado no LEATHER: Tactical Boxing Management**, levado para o MMA. O
  jogador é o **empresário de uma academia/equipe**, não o dono de uma organização:
  - contrata amadores, profissionais e veteranos;
  - aceita propostas e desafia adversários perto no ranking (perder atrasa os desafios; o campeão
    só defende contra os primeiros da fila);
  - monta o **plano de luta** antes de cada round e assiste à luta em texto;
  - treina por prioridades, contrata staff, cuida da condição física, das lesões e do corte de peso;
  - ganha reputação. O jogo não tem fim.
- **Não usar nada do Corner Office antigo** (`corner-office/`): o dono considera que não funcionava.
- Base técnica: a do Mais Uma Rodada (interface, retratos, nomes, países).

## O que está feito

- Correção da chave de peso nos retratos: `look["wt"]` (0 a 1), porque `bw` já era a
  sobrancelha do editor. `tools/face_sheet.gd` converte a categoria em `wt`.
- Base de interface portada do MUR, sem o futebol: `UIKit`, `UIColors` (só modo escuro; destaque na
  cor da equipe; `CORNER_RED`/`CORNER_BLUE` só na luta), `UITokens`, `UILayout`, `TouchScroll`,
  `DataTable`, `BaseScreen` (o esqueleto da tela é montado em código, sem .tscn por tela),
  `UIManager`, `main.gd`/`scenes/main.tscn`, `TopBar`, `BottomNav` (Início, Equipe, Rankings,
  Mercado, Academia), `TeamBadge`, `StarsView`, `FlagView`, `Fmt` (US$), `Sfx`/`AudioManager`,
  `AppSettings`. Ícones novos: `belt.svg`, `glove.svg`. Ícone do app novo.
- Dados (`data/world/mma.json`):
  - 12 categorias (8 masculinas e 4 femininas), com limite de peso, físico do retrato e fator de nocaute;
  - peso de cada país na geração e arte marcial de base por país;
  - três camadas de evento (regional, continental, Liga Global de Combate — LGC);
  - nomes de equipes e apelidos;
  - lista de lutadores reais que nunca são gerados.
- `data/names/fight_names.json`:
  - culturas de nome que faltavam (Ásia Central, Daguestão/Cáucaso, Tailândia, Lituânia, Bulgária);
  - origens dos países que não tinham;
  - **nomes femininos** de todas as culturas (o `names.json` do MUR só tinha homens).
- Modelos com save em dicionário: `Fighter` (18 atributos de 1 a 100 em três grupos), `Team`,
  `Bout`, `FightEvent`, `GameWorld` (semana a semana; lutas no sábado).
- Geração: `NameGenerator` (portado), `FighterGenerator` (país → origem → base marcial →
  atributos → idade, potencial e cartel coerentes), `WorldGenerator` (cerca de 900 lutadores do
  campeão ao estreante, prospectos amadores, cerca de 50 equipes rivais, campeões).
- **Motor de luta** (`scripts/systems/fight_engine.gd`) e **plano de luta**
  (`fight_plan.gd`, 10 escolhas por round):
  - o motor roda round a round, para dá para mudar o plano no intervalo;
  - em pé: disputa de distância, combinações, contragolpe e base;
  - quedas, clinch na grade e posições no chão;
  - ground and pound e finalizações;
  - árbitro com critério próprio, médico e corner;
  - três juízes com gostos diferentes (10-9 e 10-8);
  - narração em português;
  - o plano da IA rival se ajusta quando ela está perdendo.
- Calibragem (`tools/fight_soak.gd`, 3600 lutas):

  | Grupo | Nocaute | Finalização | Decisão |
  |---|---|---|---|
  | Homens | 20% (mosca) a 42% (pesado) | ~18% | — |
  | Mulheres | ~15% | ~19% | ~65% |

  - O melhor (5 ou mais pontos de nível acima) vence cerca de 80%.
  - Há também uma "forma do dia" aleatória por lutador, que permite zebras.
- Começados, **ainda sem testar**: `Rankings`, `Calendar`, `Matchmaker`
  - `Rankings`: rating tipo Elo e as camadas por posição;
  - `Calendar`: LGC a cada duas semanas, uma noite continental e três regionais por semana;
  - `Matchmaker`: casamentos das equipes rivais, cinturão, propostas, desafios com chance de aceite e bolsas.

## Estado da compilação

`tools/check_scripts.gd` dá 2 erros:

- `world_generator.gd` chama `StaffMarket`, que **ainda não existe**.
- `matchmaker.gd` tem erros de inferência de tipo. Rodar `--import` antes, para registrar as classes novas (`Rankings`, `Calendar`, `Matchmaker`), e tipar `evs`/`tier`.

O tema `assets/theme/main_theme.tres` ainda não foi gerado:

```
godot --headless --path . --script res://tools/build_theme.gd
```

`GameManager` é só um esboço.

## Próximos passos (na ordem)

1. `StaffMarket`: técnicos de striking, wrestling e jiu-jitsu, preparador físico, fisioterapeuta, nutricionista e olheiro, com qualidade e salário semanal.
2. Treino e envelhecimento semanal (foco e intensidade; ganho pela idade, pelo potencial e pelo staff), lesões e condição física (sobe uns 7% por semana, como no LEATHER).
3. `Career`: avançar a semana, com estes passos:
   - lutas da CPU, pesagem e corte de peso, bolsas e a fatia da equipe;
   - finanças semanais;
   - propostas, rankings e campeões;
   - aposentadorias e novos prospectos;
   - contratação com negociação de fatia, lutas e luvas.
4. `GameManager`: nova carreira, salvar e carregar em JSON. Gerar o tema.
5. Telas: menu, nova carreira, Início (próximas lutas, propostas, avançar semana), Equipe,
   perfil do lutador, Rankings, Mercado (lutadores e staff), Academia (finanças, staff),
   proposta/desafio, **plano de luta**, **luta ao vivo** (narração, fôlego e dano, corner entre
   rounds), resultado e card do evento.
6. Ferramenta de capturas e testes; `CLAUDE.md` e `DESIGN.md` do Noite de Luta.

## Comandos (na pasta `noite-de-luta`)

```
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tools/fight_soak.gd -- --n=300 --seed=7   # calibragem
godot --headless --path . --script res://tools/fight_soak.gd -- --n=2 --log        # narração
xvfb-run -a -s "-screen 0 1600x1600x24" godot --path . --resolution 1500x900 --script res://tools/face_sheet.gd -- --out=/tmp/lutadores.png
```
