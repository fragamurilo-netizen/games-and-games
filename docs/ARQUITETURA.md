# Mais Uma Rodada — Documento Técnico de Arquitetura

> Simulador de gestão de futebol 2D para Android (APK), offline, leve e profundo.
> Nome de trabalho: **Mais Uma Rodada** — porque o objetivo do design é exatamente esse sentimento.

Este documento é a referência técnica do projeto. Ele descreve **como o jogo é construído**, não apenas
como ele poderia funcionar. Tudo aqui corresponde a código real dentro de `mais-uma-rodada/`.

---

## 1. Princípios que guiam cada decisão técnica

| Princípio | Consequência na arquitetura |
|---|---|
| Interface simples + decisões profundas | Poucas telas, cada uma com uma pergunta clara. A profundidade mora nos sistemas, não nos menus. |
| Histórias > números | Todo sistema registra *memória* (quem fez o gol, quem foi vendido, quem é ídolo). Números existem para gerar histórias. |
| Consequências visíveis | Toda decisão altera valores reais do save (moral, dinheiro, potencial, reputação). Nada cosmético. |
| Rápido de abrir, rápido de jogar | Carreira começa em ~30 s; uma rodada completa (instantânea) custa < 150 ms de CPU. |
| Retenção honesta | Sem timers, energia, loot boxes, FOMO. A curiosidade vem da própria simulação (ganchos da próxima rodada). |
| Determinismo | Mesmo seed + mesmas decisões = mesmo mundo. Essencial para testes e reprodução de bugs. |
| Testável sem interface | Toda a simulação roda em modo headless: 100 temporadas automáticas geram relatório de balanceamento. |

---

## 2. Decisões técnicas

| Tema | Decisão | Motivo |
|---|---|---|
| Engine | **Godot 4.7.2 stable** (última estável) | Leve, open source, export Android nativo, portável para PC. |
| Linguagem | **GDScript tipado** | Iteração rápida; tipagem estática dá desempenho e pega erros cedo. |
| Renderizador | `gl_compatibility` (OpenGL ES 3) | Máxima compatibilidade com celulares básicos, menor consumo de bateria. |
| Resolução base | 720×1280, retrato, stretch `canvas_items` + aspect `expand` | Adapta-se a qualquer proporção (16:9 a 21:9) sem distorção. |
| Economia de bateria | `low_processor_mode` ligado | A tela só é redesenhada quando algo muda. A partida 2D anima normalmente. |
| Dados estáticos | JSON em `res://data` | Nada de clubes/nomes/frases hardcoded na lógica. Editável sem programar. |
| Save | `Dictionary` versionado → `store_var` + compressão ZSTD, escrita atômica | Robusto, compacto (~300 KB), migrável entre versões. |
| Aleatoriedade | Um único `RandomNumberGenerator` por mundo, com seed e estado salvos | Reprodutibilidade total. Nunca usamos `randi()`/`shuffle()` globais na simulação. |
| Arte | 100% procedural (escudos, uniformes, rostos, campo) + ícones SVG | APK pequeno, milhares de jogadores visualmente distintos. |
| Áudio | Sintetizado em tempo de execução (`AudioStreamWAV`) | Zero arquivos de áudio pesados. |
| Fontes | Barlow e Barlow Condensed (SIL OFL), subconjunto latino, WOFF2 | Identidade esportiva/levemente retrô, ~100 KB no total. |

---

## 3. Estrutura de pastas

```text
mais-uma-rodada/                 ← projeto Godot (abra este diretório no editor)
├── project.godot
├── export_presets.cfg           ← preset Android (APK arm64 + armv7)
├── icon.svg
├── assets/
│   ├── fonts/                   ← Barlow (OFL) + licença
│   ├── icons/                   ← ícones SVG desenhados à mão
│   └── theme/main_theme.tres    ← tema gerado por tools/build_theme.gd
├── data/
│   ├── world/
│   │   ├── competitions.json    ← divisões, acesso/rebaixamento, prêmios, janelas
│   │   ├── clubs_default.json   ← os 80 clubes do "Mundo padrão"
│   │   └── cities.json          ← cidades/regiões para o "Mundo aleatório"
│   ├── names/names.json         ← culturas de nomes + nacionalidades
│   ├── gameplay/
│   │   ├── archetypes.json      ← perfis institucionais dos clubes
│   │   ├── personalities.json   ← traços de personalidade e seus efeitos
│   │   ├── formations.json      ← 8 formações, coordenadas e pesos por setor
│   │   └── tactics.json         ← mentalidades, estilos, intensidade, linha, pressão
│   └── text/
│       ├── commentary.json      ← narração procedural (centenas de frases)
│       └── news.json            ← modelos de notícias
├── scenes/
│   ├── main.tscn                ← raiz: barra superior, host de telas, navegação, overlays
│   ├── screens/*.tscn           ← uma cena por tela
│   └── components/*.tscn        ← linhas, diálogos, barras reutilizáveis
├── scripts/
│   ├── autoload/                ← GameManager, UIManager, AudioManager
│   ├── core/                    ← constantes, RNG, formatação, DatabaseManager, SaveManager
│   ├── models/                  ← Player, Club, TeamSheet, Fixture, League, SeasonState, GameWorld...
│   ├── generation/              ← NameGenerator, PlayerGenerator, ClubGenerator, WorldGenerator
│   ├── systems/                 ← SeasonManager, FixtureManager, CompetitionManager, MatchEngine,
│   │                              MatchSimulation, Commentary, TransferManager, FinanceManager,
│   │                              PlayerDevelopment, ClubAI, NewsManager, StoryHooks
│   └── ui/                      ← scripts das telas e componentes desenhados (Crest/Kit/Portrait/Pitch)
├── tests/
│   ├── run_tests.gd             ← testes unitários/integrados headless
│   └── season_simulator.gd      ← simula N temporadas e gera relatório
└── tools/
    ├── build_theme.gd           ← gera assets/theme/main_theme.tres
    └── screenshot_tour.gd       ← percorre as telas e salva PNGs (validação visual)
```

---

## 4. Camadas

```text
┌──────────────────────────────────────────────────────────────┐
│ UI (scenes/ + scripts/ui)                                    │
│  Telas leem o GameWorld e chamam ações do GameManager.       │
├──────────────────────────────────────────────────────────────┤
│ Orquestração (autoload GameManager)                          │
│  Carreira atual, fluxo de rodada, autosave, sinais para a UI │
├──────────────────────────────────────────────────────────────┤
│ Sistemas (scripts/systems) — puros, estáticos, determinísticos│
│  Recebem o GameWorld e o modificam. Não conhecem a UI.       │
├──────────────────────────────────────────────────────────────┤
│ Modelos (scripts/models) — dados + serialização to/from dict │
├──────────────────────────────────────────────────────────────┤
│ Dados estáticos (res://data/*.json) via DatabaseManager      │
└──────────────────────────────────────────────────────────────┘
          ▲
          └── tests/ e o simulador de temporadas usam direto as
              camadas de Sistemas/Modelos, sem nenhuma tela.
```

Regras:
1. **Sistemas nunca dependem de autoloads.** Assim o simulador headless roda 100 temporadas sem UI.
2. **Modelos só guardam estado** e métodos derivados baratos (idade, overall, nome de exibição).
3. **Toda aleatoriedade passa por `world.rng`** (ou por um RNG filho semeado a partir dele).
4. **A UI nunca altera o mundo diretamente** para ações relevantes: chama `GameManager`/sistemas, que validam.

---

## 5. Módulos

| Módulo | Tipo | Responsabilidade |
|---|---|---|
| `GameManager` | autoload | Carreira ativa, iniciar/carregar carreira, preparar e concluir rodadas, fim de temporada, autosave ao pausar o app. |
| `UIManager` | autoload | Pilha de telas, abas, diálogos, toasts, botão voltar do Android. |
| `AudioManager` | autoload | Sons sintetizados (toque, apito, gol, torcida, vitória, derrota, contratação, título) e vibração. |
| `DatabaseManager` | estático | Carrega e cacheia os JSON de `data/`. |
| `SaveManager` | estático | Slots, metadados, escrita atômica, backup `.bak`, migração de versões. |
| `AppSettings` | estático | Preferências do aparelho (som, vibração, velocidade padrão). |
| `NameGenerator` | estático | Nomes coerentes por cultura, apelidos, unicidade. |
| `PlayerGenerator` | estático | Atributos por posição/perfil, potencial, curva, personalidade, contrato. |
| `ClubGenerator` | estático | Clubes a partir de `clubs_default.json` ou proceduralmente; escudos e uniformes. |
| `WorldGenerator` | estático | Monta o universo inicial a partir do seed. |
| `FixtureManager` | estático | Turno e returno (método do círculo), 38 rodadas, mando equilibrado. |
| `CompetitionManager` | estático | Tabela, critérios de desempate, artilharia, assistências, zonas. |
| `MatchEngine` | estático | Monta `MatchSimulation` com escalações e contexto (clássico, mando, público). |
| `MatchSimulation` | instância | Simulação minuto a minuto incremental — permite pausar, substituir e mudar tática no meio do jogo. |
| `Commentary` | estático | Narração procedural sem repetição imediata. |
| `ClubAI` | estático | Escalação, formação, tática, mentalidade e substituições da IA. |
| `TransferManager` | estático | Valor, salário, negociação, propostas IA↔IA e IA→usuário, agentes livres, renovação. |
| `FinanceManager` | estático | Bilheteria, TV, patrocínio, salários, manutenção, prêmios, orçamentos. |
| `PlayerDevelopment` | estático | Evolução semanal/anual, curvas de envelhecimento, aposentadoria, geração da base. |
| `SeasonManager` | estático | Ciclo da rodada e da temporada: acesso/rebaixamento, contratos, nova temporada. |
| `NewsManager` | estático | Feed procedural a partir de dados reais do save. |
| `StoryHooks` | estático | Ganchos da próxima rodada ("clássico", "confronto direto", "retorno de lesão"...). |

Módulos planejados para MVPs seguintes (espaço já reservado nos modelos): `EventManager` (eventos com decisões),
`PlayerAI` (pedidos de transferência, conflitos), `CupManager` (Copa Nacional), `RecordsManager`, `HallOfFame`.

---

## 6. Modelo de dados

### 6.1 `Player`
| Grupo | Campos |
|---|---|
| Identidade | `id`, `first_name`, `last_name`, `nickname`, `known_as`, `birth_year`, `nationality`, `height`, `foot`, `position`, `secondary[]`, `shirt` |
| Atributos (1–100, `PackedByteArray`) | finalização, passe, técnica, velocidade, força, marcação, posicionamento, visão, cruzamento, cabeceio, resistência, goleiro, disciplina, inteligência, decisão |
| Ocultos | `potential`, `dev_curve` (precoce, normal, tardio, declínio precoce, longevo), `consistency`, `injury_prone`, `traits[]` (personalidade), `scout_noise` |
| Contrato | `club_id`, `wage` (mensal), `contract_end` (ano), `squad_status`, `transfer_listed`, `asking_price`, `joined_year` |
| Condição | `condition` (físico), `morale`, `recent_ratings` (forma), `injury_weeks`, `suspension`, `yellow_acc`, `retiring` |
| Estatísticas | `stats` da temporada (`PackedInt32Array`), `history[]` por temporada, `spells[]` por clube, totais de carreira |

O **overall** é uma média ponderada por posição (pesos em `Constants.POSITION_WEIGHTS`). O jogador pode atuar
fora da posição com penalidade de familiaridade (principal 100%, secundária 96%, mesmo setor 88%, fora 70%).
O potencial **nunca é exibido exatamente**: a UI mostra faixas (baixo, razoável, promissor, grande promessa,
extraordinário) com ruído que diminui para jogadores do próprio clube (e, no futuro, com scouts melhores).

### 6.2 `Club`
Identidade (`name`, `short_name`, `abbr`, `city`, `region`, `founded`), torcida (`fan_base`, `fan_mood`),
rivais (`rival_id`, `rival2_id`), estádio (`stadium`, `capacity`), finanças (`balance`, `transfer_budget`,
`wage_budget`, `ledger` da temporada), estrutura (`youth_level`, `facilities`), identidade visual (`colors`,
`kit_home`, `kit_away`, `crest`), `archetype` + `personality` institucional, `division`, `player_ids`,
`sheet` (escalação/tática), `cohesion` (entrosamento) e memória (`history`, `titles`).

### 6.3 Arquétipos (em `archetypes.json`)
Gigante endividado · Rico recém-promovido · Tradicional decadente · Clube formador · Clube vendedor ·
Equipe defensiva · Torcida impaciente · Projeto jovem · Contrata veteranos · Azarão · Cidade pequena ·
Estádio enorme · Boa base sem dinheiro · Dinheiro com gestão ruim · Tradicional equilibrado.

Cada arquétipo altera **valores reais**: reputação, torcida, caixa inicial (dívida), receitas, base,
estrutura, faixa etária preferida na IA de mercado, peso dado ao potencial, preço pedido nas vendas,
paciência da torcida/diretoria, taxa de "má gestão" (contratações ruins/sobrepreço), formação e estilo
preferidos e perfil etário do elenco inicial.

### 6.4 Competições
- `SeasonState`: `year`, `leagues[4]`, `calendar[]` (dias de jogo), `day` (próximo dia), `finished`.
- `League`: `division`, `club_ids[20]`, `rounds[38][10]` de `Fixture`, `table` (linhas por clube).
- `Fixture`: `home`, `away`, `played`, `hg`, `ag`, `goals[]` (minuto, lado, autor), `attendance`.
- O calendário é uma lista de dias de jogo (`{"type": "L", "round": n}`); a Copa (MVP 3) entra como
  dias extras `{"type": "C", ...}` sem alterar o resto do código.

### 6.5 `GameWorld`
Raiz do save: `seed`, estado do `rng`, `year`, `season_number`, `clubs[]`, `players{}` (ativos + livres),
`season`, `history` (campeões, acessos, artilheiros por ano), `news[]`, `offers[]` (propostas pendentes),
`transfer_log[]`, `user_club_id`, `manager`, `difficulty`, `stats` agregadas para o relatório.

---

## 7. Fluxos principais

### 7.1 Nova carreira (meta: 30 segundos)
`Nova carreira` → (Mundo padrão já gerado em thread) → escolhe divisão/clube → `Começar`.
O nome do treinador, seed e dificuldade têm valores padrão; ninguém é obrigado a preencher nada.

### 7.2 Loop da rodada
```text
Hub (notícias + ganchos) → JOGAR → Pré-jogo (escalação/tática já sugeridas)
  → GameManager.begin_matchday():
        - IA escala todos os outros clubes
        - partidas IA×IA simuladas por completo (rápido, sem narração)
        - partida do usuário devolvida como MatchSimulation "viva"
  → Tela da partida: step() por minuto (Instantâneo / Rápido ~30 s / Normal ~2 min),
     pausa → substituições e mentalidade → continua
  → GameManager.finish_matchday():
        - aplica resultados, tabela, estatísticas, cartões, suspensões, lesões
        - físico, moral, forma, finanças da rodada, evolução semanal
        - mercado IA (se janela aberta), propostas por jogadores do usuário
        - notícias + ganchos da próxima rodada + autosave
  → Resultados da rodada → Hub
```

### 7.3 Fim de temporada
Campeões e premiação → acesso/rebaixamento (parametrizável) → arquivamento de histórico →
contratos vencidos (IA renova ou libera) → envelhecimento/evolução anual → aposentadorias (anunciadas
durante a temporada) → base (novos jovens por clube conforme `youth_level`) → reputação/torcida →
orçamentos da diretoria → novo calendário.

---

## 8. Motor de partidas

O motor é **estatístico e incremental** (minuto a minuto). A animação 2D apenas ilustra os eventos.

### 8.1 Força efetiva de cada jogador em campo
`efetivo = rating_na_posição × familiaridade × físico × moral × forma × desempenho_do_dia × contexto`
- `desempenho_do_dia`: ruído gaussiano cujo desvio depende de `consistency`.
- `contexto`: traços de personalidade (jogos grandes, tímido, decisivo...) em clássicos e jogos decisivos.

### 8.2 Setores do time
Cada vaga da formação tem pesos em defesa/meio/ataque e flag de amplitude (`formations.json`).
- **DEF** = Σ(composto defensivo × peso_def) — marcação, posicionamento, força, cabeceio, velocidade, decisão
- **MEI** = Σ(composto de meio × peso_meio) — passe, visão, técnica, decisão, resistência
- **ATA** = Σ(composto ofensivo × peso_ata) — finalização, técnica, velocidade, decisão, posicionamento
- **GOL**, **AÉREO**, **AMPLITUDE**, **VELOCIDADE**, **TÉCNICA**, **DISCIPLINA**, **BOLA PARADA**
Os setores são recalculados a cada 5 minutos (fadiga) e após substituições, expulsões e lesões.

### 8.3 Cada minuto
1. Fadiga (resistência × intensidade).
2. Posse: disputa de meio-campo + estilos + mando + momento.
3. Rolagem de evento para quem tem a bola:
   `P(chance) = BASE × (ATA×mentalidade / DEF×mentalidade_adv)^α × estilo × linha × momento`
   ou falta (→ cartão, falta perigosa, pênalti) ou impedimento.
4. Chance → tipo (enfiada, cruzamento, chute de fora, jogada individual, contra-ataque, sobra,
   erro defensivo) → finalizador e assistente ponderados por posição/atributos → xG do tipo ×
   qualidade → `P(gol) = xG × finalizador / goleiro` → gol, defesa, fora, bloqueio, trave, escanteio.
5. Lesões, substituições automáticas (IA e, se ativado, assistente do usuário), ajustes de mentalidade
   da IA conforme placar e tempo.
6. Acréscimos proporcionais aos eventos.

### 8.4 Encaixe tático
- Mentalidade desloca ataque/defesa (retranca ↔ tudo ou nada).
- Estilos: posse (mais controle, chances melhores), direto (mais chutes, piores), contra-ataque (forte
  contra times ofensivos e com velocidade), pressão alta (roubadas, mais cansaço, vulnerável a velocidade),
  pelos lados (cruzamentos, aéreo, bom contra formações estreitas), bola longa (aéreo/força, ignora pressão).
- Linha alta sofre contra atacantes rápidos; linha baixa concede volume mas poucas chances claras.
- Modificadores moderados (±3–12%): talento decide, tática desempata.

### 8.5 Metas de calibração (verificadas pelo simulador)
| Métrica | Alvo |
|---|---|
| Gols por jogo | 2,5 – 2,9 |
| Vitória mandante / empate / visitante | ~45% / ~26% / ~29% |
| Chutes por time | ~11–14 |
| Amarelos por jogo | ~3,5 · vermelhos ~0,15 |
| Favorito com +10 de overall | vence ~65–75% |
| Time da 4ª contra 1ª divisão | vence ~3–8% (zebras de Copa existem!) |

### 8.6 Importância do gol
Cada gol recebe um peso narrativo: minuto, placar antes/depois (empate, virada, desempate),
clássico, rodada decisiva. A UI usa isso para escolher a celebração (banner, cor, som, vibração,
frase: "GOL DA VIRADA!", "NO ÚLTIMO LANCE!"). Um gol aos 90+4 nunca parece com o 5º gol de uma goleada.

---

## 9. Evolução e envelhecimento

- **Crescimento** usa orçamento em pontos de overall: `gap_até_potencial × taxa(idade, curva)` com mínimo por
  idade, multiplicado por minutos jogados, estrutura do clube, personalidade (profissional/esforçado ↑,
  festeiro/acomodado ↓) e sorte. É aplicado semanalmente (pequenos passos) e revisado no fim da temporada.
- **Potencial é dinâmico**: jovens que jogam e vão bem podem ganhar potencial; os que não jogam perdem.
  Pequena chance de "explosão" (salto de 3–6) e de estagnação.
- **Declínio** usa pontos de atributo, físicos primeiro. Por isso um ponta veloz cai rápido depois dos 31
  e um zagueiro inteligente dura mais. Goleiros começam a cair ~3 anos depois.
- Curvas: precoce, normal, tardio, declínio precoce, longevo (sorteadas por jogador, nunca iguais).
- **Aposentadoria**: probabilidade por idade/curva/nível; veteranos anunciam durante a temporada.
- **Base**: cada clube recebe 2–5 jovens por ano conforme `youth_level`; raras joias com potencial 80+.

---

## 10. Economia (simples de ler)

Receitas: bilheteria (público × ingresso), TV (por divisão), patrocínio (reputação), premiação (posição),
vendas. Despesas: salários, compras, manutenção (estádio + estrutura).
A tela do clube responde em segundos: **Saldo**, **Pode gastar em contratações**, **Folha atual / limite**.
Orçamentos são definidos pela diretoria no início da temporada conforme caixa, receita esperada, arquétipo e
dificuldade. A dificuldade nunca dá bônus de força à IA.

---

## 11. Transferências e IA de clubes

- Valor de mercado: exponencial no overall × idade × potencial × contrato.
- Salário pedido: valor, reputação do clube, personalidade (mercenário pede mais, leal aceita menos).
- Negociação do usuário: proposta → aceita / contraproposta / recusa → termos pessoais → assinatura.
- IA↔IA (`MarketAI`, perfis por país em `data/gameplay/market.json`): quando a janela abre, cada clube
  planeja quantos reforços busca (grandes 3 a 6, pequenos 1 a 3, inverno só remendos), anuncia quem sobra
  e empresta promessas sem espaço. A busca segue as rotas reais de talento (próprio país, países de
  garimpo, mercado mundial por nível) e a estratégia do arquétipo. Negociação clube × clube com proposta,
  contraproposta e recusa: o poder econômico da liga manda (ágio da liga inglesa, clube grande não vende
  titular para menor, pequeno não segura quem recebe proposta de gigante), multa rescisória paga à vista,
  e quem vende um titular vai atrás de reposição. Jogador cobiçado vira leilão (outro clube pode dar o
  "chapéu"), formadores guardam % da revenda, o comprador pode incluir um jogador na troca, negociações
  que ficam perto do acordo viram novela nas semanas seguintes (o comprador sobe a oferta, o vendedor
  cede) e quem não tem dinheiro pega emprestado com opção de compra, exercida no fim da temporada. Veteranos atraídos por Golfo, EUA e volta para casa.
  A maior parte dos negócios de meio de ano acontece nas férias (`MarketAI.offseason`); o último fim de
  semana da janela tem correria e preços mais altos. Recém-contratado não é revendido na mesma temporada.
- IA→usuário: propostas por jogadores em destaque chegam como notificações com prazo; quem precisa da
  posição e tem mais dinheiro faz a proposta, promessas atraem ágio.
- `tests/market_report.gd`: raio-x do mercado (fluxos entre regiões, maiores vendas, idades, empréstimos).

---

## 12. Save / Load

- Slots: 5 carreiras (`user://saves/slot_N.sav`) + metadados leves (`slot_N.meta.json`) para listar rápido.
- Formato: `Dictionary` com `version` → `FileAccess.open_compressed(..., COMPRESSION_ZSTD)` + `store_var`.
- Escrita atômica: grava `.tmp`, move o anterior para `.bak`, renomeia `.tmp` → `.sav`. Se o `.sav` estiver
  corrompido, o load tenta o `.bak`.
- Migração: `SaveManager.migrate(data)` aplica passos `v1→v2→…`; `from_dict` usa valores padrão para campos
  ausentes, então saves antigos continuam abrindo.
- Autosave: após cada rodada, no fim da temporada e quando o Android pausa/fecha o app.

---

## 13. Performance

| Item | Orçamento |
|---|---|
| Geração do mundo (80 clubes, ~1.950 jogadores) | < 1,5 s em celular intermediário (em thread) |
| Rodada instantânea (40 partidas + mercado + evolução) | < 150 ms |
| Fim de temporada | < 1 s |
| Save comprimido | ~250–400 KB mesmo após 50 temporadas |
| Memória | < 150 MB |

Estratégias: nada de simulação por frame; índices por posição reconstruídos por rodada; jogadores
aposentados viram registros compactos; notícias antigas são podadas; histórico de temporadas arquiva só o
essencial (tabela final, campeões, artilheiros); partidas IA×IA não geram narração.

---

## 14. Testes

- `tests/run_tests.gd`: geração (80 clubes, faixas de elenco, nomes únicos, seed determinístico), calendário
  (38 rodadas, cada par se enfrenta 2×, mando equilibrado), motor (médias de gols e mando em milhares de
  jogos), classificação, save/load (ida e volta idêntica), transferências e virada de temporada.
- `tests/season_simulator.gd`: `godot --headless --script res://tests/season_simulator.gd -- --seasons=100`
  gera relatório com média de gols, transferências, idade média, equilíbrio financeiro, campeões,
  rebaixamentos, distribuição de overall, inflação de valores, jovens gerados e aposentadorias.

---

## 15. Interface

Tela inicial da carreira: **próxima partida no centro** (adversário, rodada, competição, posição, moral,
ganchos) e cinco ações: **JOGAR · ELENCO · MERCADO · TABELA · CLUBE**. Nada de 30 botões.

Mapa de telas: Menu → Nova carreira → Hub → (Pré-jogo → Partida → Resultados) · Elenco → Perfil ·
Mercado → Perfil → Negociação · Tabela (classificação, artilharia, rodadas) · Clube (finanças, histórico,
salvar, opções) · Fim de temporada · Carregar.

O perfil do jogador responde primeiro: **"Esse jogador é bom para meu time?"** (overall, comparação com o
titular atual da posição, valor, salário, contrato, forma, moral) — depois atributos, histórico e
personalidade.

---

## 16. Roteiro

| MVP | Conteúdo | Status |
|---|---|---|
| **1** | 4 divisões, 80 clubes, ~1.950 jogadores procedurais, calendário, tabela, escalação, tática, motor, partida 2D com narração, mercado básico, evolução, save/load | **em desenvolvimento nesta versão** |
| 2 | Personalidades com eventos, moral completa, contratos avançados, notícias ampliadas, diretoria, finanças detalhadas, eventos com decisões | planejado |
| 3 | Copa Nacional, rivalidades com histórico, editores de uniforme/escudo, base, scouts, recordes, Hall da Fama, aposentadoria com novas funções | planejado |
| 4 | Refinamento, áudio, animações, balanceamento, tutorial, otimização, export Android final | planejado |
