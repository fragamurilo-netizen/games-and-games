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

### 2026-10-07 — revisão visual implementada no ramo do Codex

- Escudos: `825a8f9`, `a09b1af`, `2fba351`. Redesenhei 38 escudos de clubes: canhão/roda, navio/rios/rosa, torre, árvore/ondas, martelos, lobo frontal, abelha, cabeceador e monogramas brasileiros. Arte vetorial própria. Contorno com antialiasing, anel do nome corrigido e miniaturas com simplificação limitada a 0,4 pixel. Vazados estruturais sobrevivem nas marcas pequenas.
- Logos: `8a0231e`, `ca725fb`. Nove identidades de competição: ENG1, ESP1/2, GER1/2, ITA1/2, FRA1/2. Leão coroado, atleta em voleio e letras vetoriais, com cores e composição mais reconhecíveis. Apenas `identity.json.logos` mudou; 153 IDs preservados.
- Uniformes: `38697d1`. Dobras curvas, trama fosca compartilhada (somente em peças grandes), barra dupla, junção das mangas e contraste na impressão. Listas públicas e índices iguais à base.
- Rostos: `08ce629`, `c25f55b`, `4490000`. Mantive o renderizador 2D. Volume facial por normais analíticas, pálpebras, íris, lábios e fios mais suaves. Acrescentei ao fim 12 formatos de rosto, 16 olhos, 16 narizes, 16 bocas e 12 orelhas (72 perfis). Curvas independentes, microvariações estáveis por pessoa/idade e anatomia detalhada das orelhas. Catálogos agora: rosto 30, olhos 46, nariz 48, boca 42, orelhas 24. Os retratos continuam ilustrados; não são fotografias.
- Compatibilidade: catálogos anteriores mantêm ordem e valores; cabelo/barba/pele mantêm sua sequência aleatória. Chamadas públicas, cache e preferência por imagens importadas preservados. Nos JSON de clubes só `crest` mudou; todos os demais campos iguais à base.
- Campos opcionais de escudo: `charge_layers` (até oito símbolos com posição/escala), `dc` (tinta de detalhe) e `ring_bg` (tinta do anel). Todos têm padrão e não exigem migração de save. Nenhum campo novo de uniforme.
- Ferramentas: `face_anatomy.gd` compara cada tipo na mesma pessoa, com ampliação nativa; `face_contract.gd` verifica determinismo/índices e aceita `--baseline=SCRIPT`; `face_bench.gd` mede geração e redesenho com cache. Geradores Python de arte e dados são idempotentes. `crest_sheet.gd --small=40` permite comparar clubes e miniaturas.

Conferência concluída com Godot 4.7.2 / Compatibility / Windows RTX 3060:

- `check_scripts.gd`: 434 scripts, **com erro: 0**.
- `face_contract.gd`: **814 casos, com erro: 0**, incluindo comparação de todos os índices antigos contra FaceGen do commit `673e5d6` e estabilidade de cabelo/barba/pele nas novas combinações.
- `tools/crest_gen/check.gd`: **2.656 contornos**, quatro tamanhos, zero falhas; 54.088 pontos passam a 21.657 em miniaturas, sem alterar o catálogo original.
- Folhas de escudos ingleses/brasileiros, logos, uniformes frente/costas, 104 retratos de 13 grupos, 72 novas anatomias, cabelos, envelhecimento e seis moods de fotos capturados e inspecionados.
- Hub, clube, jogador, elenco e uniforme capturados em **390×844, 844×390, 800×1280 e 1280×800**, sem erro de script. Passe com duas rodadas em 390×844 também concluído.
- A ferramenta de TV gerou 12 capturas, mas falhou ao encerrar com `-1073741819`. Reproduzi a mesma falha no commit-base `673e5d6`, após importar o projeto corretamente. As duas últimas capturas ficam escuras na transição final; não considero essa parte validada. Os retratos dos titulares por setor foram conferidos. Não alterei telas ou sistemas para corrigir a ferramenta.
- As ferramentas de telas deixam avisos de CanvasItem/ObjectDB/recurso ao encerrar; a mesma sequência aparece no commit-base. Sem erros GDScript.
- Medição pareada de 12 retratos, em uma execução: 90 px, geração 589→620 ms e redesenho em cache 82→80 ms; 320 px, geração 1.079→1.313 ms e cache 167→134 ms. O custo inicial de retratos grandes aumentou cerca de 22%; não são medições de FPS. Cache continua limitado a 720 entradas. **Android médio ainda precisa de medição no aparelho.**

Pendências para integração: revisão do dono antes de juntar a branch; medir Android e investigar o encerramento de `tv_shots.gd` fora desta frente visual. Não foi necessário pedir alteração de tela ou regra do DESIGN.md. Nada foi integrado na main ou no ramo do Claude.
