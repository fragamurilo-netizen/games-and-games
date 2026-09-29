# Mais Uma Rodada

Jogo de gestão de futebol em Godot 4.7 (GDScript). Converse com o dono em português.
O mundo é fictício: nada de nomes reais de jogadores. Sistemas de jogo (simulação, save,
mercado, base, competições) já estão prontos; a interface consome esses sistemas e não
duplica lógica deles.

Read DESIGN.md before any visual or UI work.
DESIGN.md is the visual source of truth for this project.
Do not invent new colors, radius, spacing, typography or component styles outside the system without updating DESIGN.md first.

## UI / visual work

Before any UI, UX, visual, layout, typography, component or screen change:

1. Read DESIGN.md in full.
2. Use the frontend-design skill (`/mnt/skills/public/frontend-design/SKILL.md` when the Skill tool does not list it).
3. For Godot implementation, use the Godot UI skill (`.claude/skills/godot-ui/SKILL.md`).
4. Treat DESIGN.md as binding, not inspirational.
5. Run the game and visually inspect the result before considering UI work complete.
6. If code and DESIGN.md conflict, stop and resolve the design decision instead of inventing a third pattern.

## Comandos (dentro desta pasta)

- Importar: `godot --headless --path . --import`
- Compilar tudo: `godot --headless --script res://tools/check_scripts.gd` (tem de dar "com erro: 0")
- Tema: `godot --headless --path . --script res://tools/build_theme.gd`
- Testes: `godot --headless --path . --script res://tests/run_tests.gd` (≈40 min) e `tests/mobile_regression.gd`
- Capturas: `xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/design_shots.gd -- --out=DIR --only=hub,squad`
- APK: `tools/build_debug_apk.sh <saída>`

## Regras do código

- Autoloads (Store, GameManager, AudioManager, UIManager) não compilam em `--script`: fora do
  autoload, som é `Sfx.*`, nunca `AudioManager.*`.
- Save: campo novo sempre com padrão; listas de rosto/cabelo/barba só crescem no fim.
- Não integrar as branches `codex/*`. Perguntar antes de juntar na `main`.
