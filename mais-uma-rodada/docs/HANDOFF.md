# Passagem de trabalho (30/09/2026)

Branch: `claude/gallant-hawking-3csszp`. Versão 0.5.4 (código 20). A `main` não foi tocada.
Leia antes: `CLAUDE.md`, `DESIGN.md`, `docs/ui/quality-gates.md` e
`.claude/skills/godot-ui/SKILL.md`.

## Estado

- UI 2.0 ("Lousa e Giz") aplicada em todas as telas. Os registros ficam em
  `docs/ui/quality-gates.md`.
- O trabalho do Codex 0.5.1–0.5.3 (`feat/contextual-player-assessments`, PRs #60/#61) foi
  juntado com merge. Trouxe o formato novo de Champions/UEL/Conference, seleções e Nations
  League, origem e naturalização, avaliação por estrelas (o overall saiu da UI) e a fonte
  Saira. Relatórios dele: `docs/UI-MATCH-CHAMPIONS-0.5.1.md`, `docs/CAREER-MOBILE-0.5.2.md`,
  `docs/ASSESSMENTS-MOBILE-0.5.3.md`.
- 0.5.4: o toque foi corrigido (`scripts/ui/touch_scroll.gd`, `scripts/ui/main.gd`) e houve
  ajustes de corte com a Saira.
  - Medição: `design_shots -- --only=!taps` (variável `TAP_JITTER=px`).
  - Resultado: 89 de 92 toques funcionam com tremor de 14 px.
- APKs de teste ficam em `builds/`. A 0.5.4 é `MaisUmaRodada-0.5.4-toque-ui-2026-09-30.apk`.
  Todas são assinadas com o mesmo certificado (SHA-256 `1E:08:A9:…:59:53`) e instalam por cima.
  Gerar: `MODE=release tools/build_debug_apk.sh <saída>`.
- Testes: compilação com 362 scripts e 0 erros; `mobile_regression` e `smoke_boot` passando.
  A bateria completa (`tests/run_tests.gd`, cerca de 40 min) passou com 51/51 antes do merge
  do Codex. **Rodar de novo.**

## Pedidos do dono ainda abertos (em ordem)

### 1. Simulação mais rápida (em andamento)

Medição com `godot --headless --path . --script res://tools/sim_bench.gd -- --games=20`:
1,32 s por data do usuário. Mais de 60% é jogar os cerca de 155 jogos da IA de cada data,
um por um:

| etapa | por jogo |
|---|---|
| `ai_quick` | 2,5 ms |
| `aplicar` (`_apply_match`) | 1,5 ms |
| `ai_sheet` | 1,5 ms |

Também pesam o mercado (cerca de 3 s em 20 datas) e a evolução (cerca de 2 s).
`finish_matchday` agora separa os tempos `aplicar_premios`, `aplicar_eventos`,
`aplicar_nextgen` e `aplicar_memoria`.

O que já está no código, **desligado**:
- `SeasonManager.run_entries()` (`scripts/systems/season_manager.gd`) monta as escalações da
  IA em sequência, na ordem de sempre. Em seguida pré-aquece os caches preguiçosos
  (`QuickMatch._tactics`, `Referees.factors`/`pool`, `LeagueCulture`) e roda só
  `QuickMatch.play` em até 4 `Thread`s. Cada jogo usa a própria semente.
- O interruptor é `SeasonManager.parallel`, hoje `false`. Com ele desligado, tudo roda um por
  um, como antes.
- `GameManager._wait_ai()` e `sim_bench_runner` já passam por `run_entries`. Com a variável
  `SIM_SEQ=1`, o bench usa o caminho antigo.

Próximos passos:
1. Criar um teste de igualdade. Mesma semente de mundo, N datas com `parallel=false` e depois
   com `parallel=true`. Comparar placares, gols, cartões, lesões e o hash do estado dos
   jogadores. Tem de dar idêntico.
2. Se der idêntico, ligar `parallel=true` e medir o ganho no bench (`SIM_SEQ=1` contra sem).
   - Cuidado: qualquer escrita compartilhada dentro de `QuickMatch.play` quebra isso.
   - Já auditado: `_tac_cache`, `TacticsManager._deep_cache` (via `_tactics`), a lista de
     árbitros e `Player._pos_cache` (por jogador; cada jogador joga um jogo por data).
3. Outros cortes possíveis: `MatchStats.build` (cerca de 25 ms por data), mercado e evolução.
   Medir antes de mexer.

### 2. Histórico dos clubes: técnicos anteriores e mais informações

Tela: `club_screen.gd`, seção "history" (`_history_card`, `_idols_card`), mais
`club_records_screen.gd`. Técnicos: `People.coach_of`, `coach_moves_screen.gd`
("Dança das cadeiras"). Falta registrar e mostrar a lista de técnicos anteriores por clube,
com anos e campanha. Se precisar de campo novo no save, ele tem de ter valor padrão.

### 3. Títulos históricos reais das seleções

Pedido: "adicionar todos os títulos históricos das seleções" (Copas do Mundo, continentais…).
- Onde entra: `data/world/international.json` e `NationalTeamManager.titles_of`.
- Onde aparece: `national_screen.gd` (ranking e convocação) e no perfil do jogador.
- Regras:
  - Os títulos devem ser pré-carregados no começo da carreira, como histórico anterior ao
    save, sem virar título de jogador.
  - São seleções reais, não nomes de jogadores; a regra "mundo fictício" vale para pessoas.
  - Conferir os fatos em fontes oficiais antes de gravar.

### 4. Deixar pronto para publicar a 1ª versão

- Versão 1.0.0, código acima de 20.
- Release assinada com a chave de upload da Play (não a de debug). O projeto usa o plugin
  GodotGooglePlayBilling; `build_debug_apk.sh` o remove.
- Gerar AAB (Gradle).
- Ficha da loja (capturas: ver `tools/store_frames.gd`).
- Rodar a bateria completa, testar em aparelho físico (nunca foi feito) e escrever as notas
  de versão.
- Perguntar ao dono antes de juntar na `main`.

## Regras

- Falar em português com o dono.
- Save compatível: todo campo novo tem valor padrão.
- Mundo fictício para jogadores e pessoas.
- Commits sem identificador de modelo.
- Não juntar na `main` sem pedir.
- Para trabalho de UI, seguir o `DESIGN.md`: capturar as telas e conferir antes de dar por
  pronto.
