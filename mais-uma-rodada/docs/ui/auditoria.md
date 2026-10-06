# Auditoria da interface (Fase 0)

Mapa interno da reforma: tela atual → nova seção → componente → dependências → risco.
Regra da casa: simulação e dados não mudam; a interface só lê o mundo e chama sistemas.

## Navegação

| Hoje | Problema | Novo |
|---|---|---|
| Uma pilha só (`UIManager.stack`); `goto` apaga tudo | Trocar de aba perde filtro, rolagem e a tela aberta | Uma pilha por área (`UIManager.stacks`); a aba devolve a tela onde o jogador parou |
| Abas Jogar · Elenco · Mercado · Tabela · Clube | Tática fica a 2–3 toques; tabela ocupa uma aba | Início · Elenco · Tática · Mercado · Clube. Tabela vai para Clube › Competições e atalhos do Início |
| Telas internas escondem a barra de baixo | O jogador fica preso em uma pilha sem ver onde está | Barra visível em toda a carreira; só fluxos (partida, pré-jogo, fim de temporada, boas-vindas, paywall) a escondem |
| Menu ☰ com ladrilhos coloridos | Grade de ícones em quadrado, cara de painel | Lista agrupada por área (ListRow), sem ladrilhos |
| Caixa de entrada e notícias dentro do menu | Precisa de 2–3 toques | Sino na barra superior com contador discreto |
| Barra lateral já existe (`set_vertical`) | Cápsula colorida atrás do ícone | Trilho compacto, marca da aba ativa em filete |

## Telas

| Tela atual | Nova seção | Componentes | Dependências | Risco |
|---|---|---|---|---|
| hub | Início (raiz) | MatchRow, ListRow, NewsRow, SectionHeader | FixtureManager, InboxManager, news | Médio: muitos atalhos antigos |
| squad | Elenco (raiz) | DataTable, SegmentedControl, FilterPanel | Player stats, lineup | Médio |
| player_profile | Perfil único (qualquer área) | PlayerHeader, Tabs, AttributeTable, StatTable | negotiation, talk_dialog | Médio |
| prematch (edit) | Tática (raiz, tela `tactics`) | TacticalPitch, ListRow | lineup_board, TacticsManager | Alto: 700 linhas, arrastar |
| prematch | Pré-jogo (fluxo do Início) | TacticalPitch, MatchRow | idem | Alto |
| match | Partida (fluxo) | MatchHUD, BottomSheet, StatTable | MatchSimulation | Alto: 2.5k linhas |
| market | Mercado (raiz) | SearchField, FilterPanel (folha), DataTable | TransferManager | Médio |
| negotiation (comp.) | Negociação (folha/tela) | conversa com histórico | TransferManager | Médio |
| club | Clube (raiz) + perfil de clube | ClubHeader, ListRow, Tabs | FinanceManager | Médio |
| table | Clube › Competições | CompetitionHeader, DataTable (tabela clássica) | CompetitionManager | Médio: 1.3k linhas |
| round_results | Fluxo pós-rodada | MatchRow | — | Baixo |
| academy, graduates | Elenco › Base | DataTable (mesmo padrão do elenco) | YouthManager | Médio |
| training, numbers, contracts, dressing_room, relations, xray, compare | Elenco › … | DataTable, ListRow | sistemas de elenco | Baixo |
| coach, manager, reputation, achievements | Clube › Treinador | ListRow, StatTable | — | Baixo |
| kit, kit_history, past_squads, club_records, team_stats, rivalry | Clube › … | ListRow, DataTable | — | Baixo (kit: editor grande) |
| national | Clube › Seleções | DataTable, convocação rápida | NationalManager | Médio |
| history, nextgen, coach_moves | Clube › Mundo | DataTable | — | Baixo |
| inbox, news, social | Sino da barra superior | NewsRow editorial por tipo | InboxManager | Baixo |
| settings, load, editor | Menu da barra superior | ListRow | — | Baixo |
| menu, new_career, welcome, season_end, preseason, paywall | Fluxos fora das áreas | — | — | Baixo |

## Componentes

Existem e ficam: CrestView, KitView, FlagView, PortraitView, PitchView, LineupBoard, NewsRow,
TableRows, PlayerRowView, MatchHero, ScoreboardView, Negotiation, TalkDialog, SimDialog.

Novos (em `scripts/ui/kit/`): DataTable, ListRow, SectionHeader (UIKit.section), Popover,
EmptyState/ErrorState/LoadingState (UIKit.state), SegmentedControl (UIKit.segmented), sino da TopBar.

## Estados que precisam ser testados

Nome longo, dado ausente, 1000+ resultados no mercado, carregando, erro, lesionado, emprestado,
suspenso, elenco vazio da base, clube sem jogo marcado.
