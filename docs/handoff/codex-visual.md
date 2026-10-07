# Pedido para o Codex: escudos, logos, uniformes e rostos

Esta frente roda **em paralelo** com o trabalho do Claude no ramo `claude/hopeful-newton-8avbo4`. O Claude está mexendo no mercado de técnicos, nas escolas de técnicos, nas gerações dos países, nos empresários, no vestiário e no histórico. A sua parte é só o **visual**. Siga as regras abaixo para os dois trabalhos se juntarem depois sem conflito.

## Como começar

- Parta do ramo `claude/hopeful-newton-8avbo4`, no commit em que este arquivo entrou (ou depois dele). Crie o ramo **`codex/visual-escudos-uniformes-rostos`**.
- Não junte nada na `main` nem no ramo do Claude. A junção depende de um OK explícito do dono do jogo. O `mais-uma-rodada/CLAUDE.md` diz "Não integrar as branches `codex/*`", e essa regra só cai com a palavra dele.
- Faça commits pequenos, um assunto por vez: escudos, logos, uniformes ou rostos.
- O jogo está em `mais-uma-rodada/` (Godot 4.7.2, GDScript). Antes de qualquer coisa visual, leia `mais-uma-rodada/DESIGN.md` (é contrato), `mais-uma-rodada/CLAUDE.md` e `mais-uma-rodada/.claude/skills/godot-ui/SKILL.md`.

## O que é seu (pode mexer à vontade)

| Assunto | Arquivos |
|---|---|
| Escudos | `scripts/ui/components/crest_view.gd`, `crest_art.gd`, `tools/crest_gen/`, `tools/crest_sheet.gd` |
| Logos de competição | `scripts/ui/components/comp_text.gd` (só `logo()` e `colors()`), `data/world/identity.json` → `"logos"` |
| Uniformes | `scripts/ui/components/kit_view.gd`, `kit_stage.gd`, `data/world/kits/*.json`, `tools/kit_*.gd`, `tools/kits_*.py`, `tools/cutout_kits.gd` |
| Rostos e fotos | `scripts/ui/components/portrait_view.gd`, `scripts/generation/face_gen.gd`, `scripts/ui/components/photo_portrait.gd`, `photo_look.gdshader`, `decal_cache.gd`, `assets/portrait/`, `assets/face3d/`, `tools/face*.gd`, `tools/face3d/`, `tools/portrait_textures/`, `tools/squad_faces.gd`, `tools/photo_shots.gd`, `tools/cutout_photo_fx*.py` |
| Bandeiras e troféus (se quiser) | `scripts/ui/components/flag_view.gd`, `trophy_view.gd` |

Em `data/world/clubs/*.json` você só pode mudar os campos **`crest`**, **`colors`** e **`kit`** de cada clube. O resto desses arquivos é do Claude.

## O que não é seu (não mexa: é onde o Claude está trabalhando)

- `scripts/systems/`, `scripts/models/`, `scripts/autoload/`, `scripts/core/` (menos o que estiver listado acima) e `scripts/generation/` (menos `face_gen.gd`).
- As telas em `scripts/ui/screens/`. Se uma tela precisar de um ajuste por causa do visual novo, anote no diário (fim deste arquivo) e o Claude faz.
- `DESIGN.md`. Se precisar de uma regra nova, proponha no diário.
- `docs/handoff/continuar-daqui.md` é do Claude. As suas notas vão no diário deste arquivo.

## Contratos que não podem mudar

O resto do jogo chama essas peças assim. Você pode trocar tudo por dentro, mas os nomes e o formato têm de continuar valendo:

- `UIKit.crest(club, px)` → `CrestView.new()` + `set_club(c)`. Também `CrestView.spec(crest_dict)`, `CrestArt.has(name)` e `CrestArt.polys(name)`.
- `UIKit.kit(kit_dict, px, number, crest_spec)` → `KitView`. As constantes `PATTERNS`, `COLLARS`, `SLEEVES`, `SHORTS_STYLES`, `SOCKS_STYLES`, `PATTERN_GROUPS` e `FULL_ASPECT`, e as funções `pattern_name`, `pattern_bands`, `tone_of` e `group_patterns`, são usadas pelo Editor e pelo gerador de uniformes. Pode acrescentar; não remova nem renomeie.
- `PortraitView`:
  - `set_player(p, club, year)` e `set_person(seed, eth, age, club)`.
  - As variáveis `kit`, `crest`, `look`, `photo`, `cutout` e `framing`.
  - `is_fm()`, `default_framing`, `FRAME_FM` e `FRAME_CLASSIC`.
  - O cache `_cmd_cache` / `_cmd_cache_order` (usado em `PhotoPortrait` e nas ferramentas).
- `FaceGen.features(seed, eth, age, look)` e as listas `HAIR_STYLES`, `BEARDS`, `BEARD_PARTS`, `FACE_SHAPES`, `NOSE_TYPES` e `MOUTH_TYPES`, mais `H_BALD`, `B_NONE`, `B_STUBBLE`, `SKIN_MIN` e `SKIN_MAX`.
- **Saves:** o índice de cabelo, barba, rosto, olhos, nariz e boca fica gravado nos saves. Essas listas **só crescem no fim**: nunca reordene nem apague itens.
- `PhotoPortrait`: `for_moment(moment, wx)`, `of_player(...)`, `set_player(p, club, year, kit_override)`, `set_person(...)`, os moods (`STUDIO`, `PRESS`, `TUNNEL`, `FILM`, `RAIN`, `SUN`) e as variáveis `transparent`, `bust`, `mood`, `focus_x` e `corner_px`.
- `CompText.logo(comp)`: devolve um dicionário no formato do escudo, com `"logo": true`. `UIKit.comp_logo(comp, px)` usa esse dicionário, a não ser que haja imagem importada pelo Editor ou pelo pacote de escudos reais (`Overrides.logo_of` / `DropIns`).
- **Escudos e logos reais (imagens de pacotes do jogador):** continuam ganhando do desenho. `DropIns` e `FmLogoImport` são do Claude. O seu trabalho é o desenho que aparece quando não há imagem.
- **Campos novos em escudo e uniforme:** sempre com padrão. Um save antigo sem o campo tem de abrir igual.

## Regras do dono

- Nada de logo ou escudo real copiado (marca registrada). O desenho é próprio, "inspirado". Nome real de clube e liga pode.
- Jogadores são fictícios: nada de rosto de jogador real.
- Visual de profissional, nada de "designer amador". Nada de faixas diagonais (o dono pediu para trocar por degradê: veja `ClubGradient` no DESIGN.md). Sem brilho e sem vidro.
- Tem de rodar bem num celular Android médio. `PortraitView` já tem 4,7 mil linhas: desenhe com custo baixo e use o cache.

## Ideias do dono para esta frente

- **Escudos mais fiéis ao espírito de cada clube:** formato, símbolo, faixas, estrelas, ano.
- **Logos de competição com mais cara de marca de TV:** as cores dos pacotes de transmissão estão em `scripts/ui/components/tv_package.gd`. Não mexa nesse arquivo; use as cores como referência.
- **Uniformes com cara de temporada de verdade:** padrões, golas e patrocínio (`data/world/brands.json` é só leitura).
- **Rostos:**
  - mais variedade por etnia e idade;
  - cabelo e barba realistas;
  - envelhecimento ao longo da carreira;
  - recorte no estilo do FM, que é o que aparece no perfil, no cartão do goleador e nos titulares por setor.

## Como conferir

- Compilar: `godot --headless --path . --script res://tools/check_scripts.gd`. Tem de dar `com erro: 0`.
- Folhas de conferência:
  - `tools/crest_sheet.gd`, `tools/kit_sheet.gd`, `tools/face_sheet.gd` e `tools/squad_faces.gd`;
  - `tools/photo_shots.gd -- --out=/tmp/photos.png`;
  - `tools/tv_shots.gd -- --out=DIR --league=ENG1`, para ver os recortes nas peças de TV.
- Telas: `xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/design_shots.gd -- --out=DIR --only=hub,club,player,squad,kit --rounds=2 --lang=pt`.

## Diário do Codex

Escreva aqui o que fez, o que ficou pela metade e o que precisa do Claude: ajuste numa tela, regra nova no DESIGN.md, campo novo em dado. Ponha data e commit.

- (vazio)
