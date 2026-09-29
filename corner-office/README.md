# Corner Office — MMA Promoter Simulator

> Build stars. Make fights. Own the night.

Simulador mobile (Android primeiro) em que o jogador preside uma organização de MMA: matchmaking, contratos, eventos, finanças, mídia, rankings, scouting e expansão. As lutas são simuladas; o jogo está nas decisões antes e depois delas.

**Status:** estrutura inicial e laboratórios visuais prontos para iteração; motor de combate ainda pendente. Próximo passo: Milestone 1 (ver [docs/ROADMAP.md](docs/ROADMAP.md)).

## Documentos (leia antes de codar)

| Documento | Para quê |
|---|---|
| [docs/GAME_DESIGN_BIBLE.md](docs/GAME_DESIGN_BIBLE.md) | **Source of truth** do produto: mundo, sistemas, UX, identidade, roadmap. |
| [docs/MMA_RESEARCH_BIBLE.md](docs/MMA_RESEARCH_BIBLE.md) | Como o MMA real funciona e como traduzir para sistemas (regras, judging, contratos, weight cut…). |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Camadas, módulos, fluxo de dados, convenções de código. |
| [DESIGN.md](DESIGN.md) | Sistema visual: cores, tipografia, regras de UI mobile. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Milestones em checklist — pegue tarefas daqui. |
| [docs/ANDROID.md](docs/ANDROID.md) | Como gerar e instalar o APK. |
| [CLAUDE.md](CLAUDE.md) | Regras para agentes de IA trabalhando no projeto. |

Os `.docx` originais das bíblias estão em `docs/bible/`. Os `.md` foram convertidos deles — se atualizar um, atualize o outro.

## Laboratórios visuais

- [Face Lab](prototypes/face-lab/): identidade, materiais e anatomia.
- [Fight Studio](prototypes/fight-lab/): movimentos pareados, sete arenas e player de replay.
- [Guia para continuar](docs/FIGHT_VISUALS.md): contrato, testes, limites e integração com o motor.

## Stack

- **Godot 4.4** (GDScript), renderer *Compatibility* (roda em Android de entrada).
- Alvo: Android (arm64-v8a + armeabi-v7a), minSdk 21 / targetSdk 34. Portrait + landscape.
- Sem dependências externas / addons.

## Rodando

```bash
# Editor
godot --path game --editor

# Jogo no desktop (janela em proporção de celular)
godot --path game

# Testes headless (unit + sim). Falha também se houver SCRIPT ERROR no log.
tools/run_tests.sh
tools/run_tests.sh unit            # só unit
GODOT=/caminho/godot tools/run_tests.sh
```

## Estrutura

```
corner-office/
├── CLAUDE.md  DESIGN.md  README.md
├── docs/                    bíblias (.md + .docx), arquitetura, roadmap, android
├── tools/                   run_tests.sh (usado também pela CI)
├── prototypes/face-lab/     laboratório de rostos (HTML) — referência para o FaceGenerator
└── game/                    projeto Godot (abra esta pasta no editor)
    ├── project.godot  export_presets.cfg  icon.svg
    ├── autoload/            EventBus (sinais globais), Game (estado atual)
    ├── core/                SimRandom, Reason, GameDate, ContentDB
    ├── content/             dados JSON mod-friendly (orgs, lutadores, regras…)
    ├── simulation/
    │   ├── models/          entidades serializáveis (Fighter, Organization, Fight…)
    │   ├── world/           WorldState, WorldGenerator, WorldSim (relógio)
    │   ├── fight/           FightEngine, Judge
    │   ├── matchmaking/     Matchmaking
    │   ├── rankings/        Rankings
    │   ├── contracts/       Contracts
    │   ├── economy/         Economy
    │   ├── popularity/      Popularity
    │   └── media/           Media
    ├── identity/            FaceGenerator (rostos/corpos/envelhecimento)
    ├── save/                SaveSystem (versionado + migrações)
    ├── ui/                  main.tscn, theme/tokens.gd, screens/
    └── tests/               runner headless, unit/, sim/
```

Todo ponto pendente está marcado no código como `TODO(M1)`, `TODO(M2)`… (milestone do roadmap):

```bash
grep -rn "TODO(M" game/
```
