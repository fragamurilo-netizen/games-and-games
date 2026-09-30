# Arquitetura

Base: Game Design Bible §17–18 e MMA Bible §20–30.

## Camadas

```
content/*.json ─► simulation (models + systems) ─► EventBus / Game.world ─► ui (screens)
                         ▲                                                   │
                         └──────────── ações do jogador (chamadas de serviço) ┘
```

- **simulation/models** — dados puros (`Entity` e subclasses). Sem lógica de regra além de helpers de exibição.
- **simulation/<sistema>** — serviços sem estado próprio (`RefCounted`) que recebem `WorldState` e mutam entidades. Retornam dicionários com `reasons` (reason codes).
- **simulation/world** — `WorldState` (todo o estado persistente), `WorldGenerator` (novo save), `WorldSim` (relógio: `advance_day`, `advance_week`, `run_event`).
- **autoload** — `EventBus` (sinais), `Game` (segura o `WorldState` e o `WorldSim` atuais; new/load/save).
- **ui** — telas lêem `Game.world`, chamam serviços em `Game.sim` e reagem a sinais. Nenhuma regra aqui.
- **identity** — aparência desacoplada dos atributos.
- **save** — JSON versionado com migrações e escrita atômica.

## Módulos (Game Design Bible §17)

| Módulo | Arquivo | Responsabilidade | Status |
|---|---|---|---|
| WorldSim | `simulation/world/world_sim.gd` | Relógio: dia a dia, dia 1º (mês) e 1º de janeiro (temporada) | pronto |
| LifeCycle | `simulation/world/life_cycle.gd` | Idade e evolução de atributos, lesões pós-luta, aposentadoria, nova safra | pronto; retorno de aposentados TODO |
| OrgStanding | `simulation/organizations/org_standing.gd` | Reputação, patamar regional/nacional/global, mercados regionais, metas e balanço da temporada | pronto |
| FightEngine | `simulation/fight/fight_engine.gd` | Simulação por trocas, dano, resultados e histórico | protótipo funcional + testes de distribuição |
| Judge | `simulation/fight/judge.gd` | 10-point must / avaliação global, perfis de juiz | funcional + testes de prioridade de critérios |
| Matchmaking | `simulation/matchmaking/matchmaking.gd` | Elegibilidade, 3 scores, propostas | pronto (M1) |
| OrgAI | `simulation/organizations/org_ai.gd` | Rivais autônomas: agenda, cards, caixa, adiamentos, renovações, free agency e propostas por atletas do jogador | pronto (M1); BATNA/memória M2 |
| Rankings | `simulation/rankings/rankings.gd` | Rankings por org + World Combat Index | TODO(M1) |
| Contracts | `simulation/contracts/contracts.gd` | Ofertas, BATNA, agentes, free agency | `sign()` pronto; resto TODO |
| Economy | `simulation/economy/economy.gd` | P&L projetado/real, mídia, sponsors | TODO(M1) |
| Popularity | `simulation/popularity/popularity.gd` | Mercados regionais, draw | resultado move popularidade regional; draw TODO |
| Media | `simulation/media/media.gd` | Notícias com triggers factuais | `publish()` pronto; triggers TODO |
| Identity | `identity/face_generator.gd` | Rostos, corpos, envelhecimento | TODO(M1) — depende do gerador do Mais Uma Rodada |
| SaveSystem | `save/save_system.gd` | Versionamento, migração, integridade | pronto |

## Modelo de dados (Game Design Bible §18)

| Entidade | Classe | Coleção em `WorldState` |
|---|---|---|
| Fighter | `Fighter` | `fighters` |
| Organization | `Organization` | `organizations` |
| Fight | `Fight` | `fights` |
| Event | `FightEvent` | `events` |
| Contract | `Contract` | `contracts` |
| Gym | `Gym` | `gyms` |
| Agent | `Agent` | `agents` |
| Ranking | `Ranking` | `rankings["org:division"]` → lista de snapshots |
| NewsItem | `NewsItem` | `news` |

Faltam (criar quando o sistema precisar): `Ruleset`, `Jurisdiction`, `MediaDeal`, `Venue`, `Sponsor`, `Camp`.

### Adicionando um campo

1. Declare `var campo := <default>` na classe — `Entity.to_dict/load_dict` serializa automaticamente toda variável de script.
2. Use só tipos serializáveis em JSON. Referência a outra entidade = id `String`.
3. Saves antigos carregam com o default. Se o default não basta, suba `SCHEMA_VERSION` e escreva a migração.

### Adicionando uma entidade

1. `class_name X extends Entity` em `simulation/models/`.
2. Registre em `WorldState.collections()` + `var x := {}`.
3. Teste de roundtrip em `tests/unit/`.

## Fluxo de uma noite de lutas (alvo do M1)

1. Jogador cria `FightEvent` (Eventos) e propõe lutas → `Matchmaking.evaluate` / `propose`.
2. Aceita → `Fight.status = "booked"`, `EventBus.fight_booked`.
3. Semanas passam (`WorldSim.advance_week`, ou `advance_month` em `CareerActions`) — lesões cicatrizam; no dia 1º, `LifeCycle.monthly` e `OrgStanding.monthly`; camps (M2).
4. Na data: `WorldSim.run_event` → `FightEngine.simulate` (+`Judge`) para cada luta.
5. `Popularity.apply_fight_result` e `LifeCycle.after_fight` (lesão) por luta; `Economy.settle_event`, `OrgStanding.after_event` (reputação), `Rankings.update`, `Media.event_report`.
6. UI escuta `event_completed` e mostra resultados/P&L/notícias.

## Convenções

- GDScript tipado (`var x: int`, `:=`), tabs, `snake_case`, `class_name` em PascalCase.
- Comentários de documentação com `##` e referência à seção da bíblia.
- `TODO(Mn)` indica milestone do roadmap.
- ids: `prefixo_000001` via `world.new_id("prefixo")`; conteúdo canônico usa ids legíveis (`ftr_carter`, `org_crown`).
- Nada de `randf()` global em `simulation/` — use `world.rng`.

## Performance mobile (Game Design Bible §17)

- Níveis de detalhe: simulação completa para eventos relevantes, abstrata para organizações menores.
- Listas longas com virtualização/pooling.
- Cache de retratos; re-render só quando a aparência muda.
- Processos pesados (avançar semanas, gerar mundo) distribuídos por frames — ou em `WorkerThreadPool` desde que não toquem na SceneTree.

## Apresentação de luta

`presentation/fight/FightReplayPlayer` consome o contrato descrito em
[FIGHT_VISUALS.md](FIGHT_VISUALS.md), utilizando keyframes JSON compartilhados
com o Fight Studio web. Valida continuidade, faz seek determinístico e nunca
resolve ações nem modifica o mundo. `FightReplayView` entrega o replay ao renderer Canvas original empacotado; no Android o plugin Java hospeda a transmissão offline. Não há um renderer nativo alternativo.

## Serviços da carreira regional

`CareerActions.perform` é a porta comum para UI Godot e adaptador HTTP (`tools/career_session.gd`). `WorldSim` executa cards anunciados, valida disponibilidade antes de qualquer luta e liquida uma vez. `PopulationGenerator` cria o mercado; contratos, matchmaking, economia, rankings e mídia possuem implementação inicial testada. A tabela de módulos acima descreve responsabilidades de longo prazo; o estado detalhado atual está em [HANDOFF.md](HANDOFF.md).

`tools/build_studio_bundle.py` incorpora os arquivos originais do laboratório sem tradução do renderer, fontes e catálogo em gzip determinístico. O replay é inserido como JSON inerte com `<` escapado. `android-studio-plugin` bloqueia navegação externa, acesso a arquivos e rede. JavaScript só pode solicitar o fechamento da transmissão; não tem acesso de escrita à carreira.
