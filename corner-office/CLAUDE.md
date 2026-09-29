# CLAUDE.md — Corner Office

Instruções para agentes (Claude e afins) e para quem revisa o trabalho deles.

## Fontes de verdade

1. `docs/GAME_DESIGN_BIBLE.md` — produto e sistemas. Em conflito, ela vence.
2. `docs/MMA_RESEARCH_BIBLE.md` — autenticidade; em especial §20–30 (tradução para sistemas) e Apêndice A (parâmetros seed).
3. `docs/ARCHITECTURE.md` e `DESIGN.md` — como o código e a UI se organizam.

Cite a seção da bíblia em comentários de módulo (ex.: `## (Game Design Bible §7; MMA Bible §22)`).

## Comandos

```bash
tools/run_tests.sh          # importa + roda unit e sim; falha em SCRIPT ERROR
godot --path game --editor  # editor
```

Rode os testes antes de todo commit. Um sistema novo precisa de teste em `tests/unit/` e, se afeta balanceamento, em `tests/sim/`.

## Regras de arquitetura (não negociáveis)

- `simulation/` não conhece `ui/`. A UI nunca implementa regra de combate, ranking, contrato ou economia.
- Comunicação sim → UI via `EventBus` (sinais) e leitura de `Game.world`.
- Todo sorteio passa por `world.rng` (`SimRandom`). Nunca `randf()`/`randi()` globais em `simulation/`.
- Entidades herdam `Entity`, têm `id` estável e só campos serializáveis; referências a outras entidades são por id.
- Históricos (lutas, contratos, títulos, rankings, notícias) são append-only.
- Mudou o formato do save? Suba `WorldState.SCHEMA_VERSION` e escreva migração + teste (`save/save_system.gd`).
- Conteúdo (nomes, organizações, regras, cores) vive em `content/*.json`, não em código.

## Regras de design do MMA Bible §30

- Nunca use Overall como input dominante do Fight Engine.
- Registre reason codes (`Reason.make(...)`) em todo cálculo importante — a UI precisa explicar *por que*.
- Não misture ranking oficial, World Combat Index e prioridade de matchmaking.
- Separe ruleset, promoção e jurisdição.
- Weight management acontece ao longo do camp, não só na pesagem.
- IA rival só usa informação que teria acesso (sem ver potencial oculto sem scouting).
- Popularidade é regional e separada de skill.
- Notícias precisam de trigger factual.
- Matchmaking mostra três scores separados (sporting fit, acceptance, commercial fit).

## Propriedade intelectual

Universo 100% fictício. Não copiar UFC, ONE, PFL, Bellator, RIZIN, pessoas reais, logos, trade dress ou nomes de eventos reais.

## UI

Siga `DESIGN.md`. Cores só via `Tokens`. Nada de neon, glassmorphism, gradiente roxo/azul, bento grid ou cards SaaS repetitivos. Toque mínimo `Tokens.TOUCH_MIN`. Capture screenshots portrait e landscape a cada milestone.

## Git

- Commits pequenos e descritivos; um sistema por PR quando possível.
- Não commitar `.godot/`, builds (`*.apk`, `*.aab`) nem keystores.
