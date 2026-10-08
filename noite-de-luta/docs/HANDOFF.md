# Noite de Luta — nota de passagem (08/10/2026)

Ramo: `claude/inspiring-wright-xx78jb` (parte do trabalho do colega em `claude/festive-maxwell-iuncob`,
já incorporado). O jogo **roda nos dois papéis**: empresário de academia e presidente da organização.

## Decisões do dono

- A ideia do jogo é **acompanhar carreiras como um fã acompanha o mundo do MMA**. O papel do
  jogador é a lente: **empresário** (academia, como no LEATHER) ou **presidente** da Liga Global
  (como um Dana White). Os dois existem; a escolha é na nova carreira.
- Muito inspirado no **LEATHER: Tactical Boxing Management**, levado para o MMA.
- **Não usar nada do Corner Office antigo** (`corner-office/`). Base técnica: Mais Uma Rodada.
- Pedidos em aberto do dono: presidente **realista e divertido** (ver `docs/PRESIDENTE.md`),
  **etnias e aparência** (ex.: daguestanês de barba sem bigode) e **estilos de luta com muito
  realismo** — os dois últimos foram feitos nesta rodada.

## O que está pronto

**Mundo e dados**
- 12 categorias, cerca de 1.000 lutadores, 50 academias rivais, campeões e linhagem dos cinturões.
- Nomes por cultura (`data/names/names.json` do MUR + `data/names/fight_names.json` do MMA).
  Culturas novas: **Daguestão, Chechênia, tártaros, Afeganistão** (além de Ásia Central, Cáucaso,
  Tailândia...). Na Rússia do MMA, ~24% vêm do Daguestão e ~10% da Chechênia (raros entre as
  mulheres: peso `fw` nas origens).
- **22 etnias** nos rostos: as 9 novas do MUR foram trazidas (eslava, balcânica, celta,
  Cáucaso/Anatólia/Irã, norte-africana, centro-asiática, nilótica, melanésia, saheliana).
- **Aparência de lutador** (`FighterGenerator._grooming` e `_marks`, tabela `grooming` em
  `data/world/mma.json`): cabelo na máquina e barba cheia **sem bigode** no Daguestão e na
  Chechênia, rosto limpo na Tailândia, cabelo curto de quem treina; **orelha de couve-flor** em quem
  vem da luta agarrada, **nariz torto** em quem trocou muito ou foi nocauteado, **cicatriz na
  sobrancelha** (cotovelada). As marcas também chegam depois das lutas (`battle_marks`).
  Chaves de `look`: `hs` cabelo, `bd` barba, `er` orelha, `ns` nariz, `sc` cicatriz, `wt` peso, `fem`.

**Rostos vindos do Mais Uma Rodada** (o gerador é o mesmo): a anatomia do Codex (72 perfis faciais,
volume, olhos, lábios e fios, ramo `codex/visual-escudos-uniformes-rostos`) já estava aqui; em
08/10 entrou também o commit `870169c` do MUR ("rostos mais bonitos e humanos": `_pleasant`, olhos
sem cara de réptil, sorriso de boca fechada, pele escura sem sombra preta, 11 penteados e 6 barbas
novos no fim das listas). Ficaram de fora só as partes que dependem de código que o Noite de Luta não
tem (máscara de lábio `_ml_masks` e o sombreamento novo de cabelo e roupa no `face_shade`).

**Estilos de luta** (`data/world/styles.json`, `scripts/systems/styles.gd`)
- **23 artes de base**: MMA, boxe, muay thai, kickboxing, kickboxing holandês, caratê tradicional,
  kyokushin, taekwondo, sanda, capoeira, savate, wrestling livre, wrestling universitário,
  greco-romana, judô, sambo esportivo, sambo de combate, jiu-jitsu, grappling sem kimono, luta livre
  esportiva, catch wrestling, kurash e luta senegalesa.
- Cada lutador tem a base e uma **segunda arte** (`Fighter.base2`, 45% nos atributos, 50% no
  repertório). Base por país e **por cultura** (o daguestanês vem do wrestling, o russo étnico do
  sambo e do boxe, o holandês do kickboxing holandês, o filipino do sanda...).
- O **motor usa o estilo**: golpes preferidos (inclusive giratório, joelhada voadora, chute na
  panturrilha, oblíquo), 15 técnicas de queda com lugar de queda e impacto (baiana, single, suplex,
  uchi mata, arremesso de cinturão...), 17 finalizações por posição (chave de calcanhar, d'arce,
  guilhotina na entrada da queda...) e **21 marcas de escola** (luta encadeada, controle por cima e
  "mat return", clinch tailandês, segura o chute, guarda perigosa, chaves de perna, entra e sai...).
  O plano sugerido pelo técnico também segue a escola. Narração com o nome do golpe da escola
  ("meia-lua de compasso", "teep", "mae-geri").
- Perfil do lutador: card "Estilo de luta" (descrição, marcas, quedas e finalizações favoritas).

**Motor de luta** (`fight_engine.gd`, `fight_plan.gd`): round a round, plano de 10 escolhas, três
juízes. Calibragem atual (`fight_soak`, 2.400 lutas): nocaute 24%, finalização 22%, decisão 54%.
Aproveitamento por base no mundo gerado (`style_lab --world`): wrestling ~60%, judô/sambo ~57-60%,
boxe ~50%, jiu-jitsu ~48%, MMA ~46%, muay thai/kickboxing ~42% (no MMA real o wrestling também é a
base que mais vence).

**Carreira** (`scripts/systems/`): Calendar, Matchmaker, Rankings (Elo), Signing, StaffMarket,
Development, Career, **Org** (modo Presidente: cards, ofertas com chance de aceite, bolsas, luta
principal em 5 rounds, PPV a cada 4 semanas, público, bônus, prestígio, finanças, delegar cards).

**Telas**: as da academia (Início, Equipe, Rankings, Mercado, Academia, plano e luta ao vivo) e as do
presidente (Início, Eventos, card, marcar luta, noite de luta com "Assistir"/"Simular", bônus e
relatório, Cinturões, Organização). Para os dois: **Seguir** lutadores, Resultados da semana e
Cinturões com linhagem.

## Verificação feita (nesta rodada)

- `tools/check_scripts.gd`: 83 scripts, 0 erros.
- `tools/world_sim.gd`: 52 semanas como empresário e como presidente, sem erro; save recarrega.
- `tools/fight_soak.gd` e `tools/style_lab.gd` (números acima).
- `tools/face_sheet.gd -- --nations=RUS,KAZ,... [--only=dag,chech]`: rostos por país conferidos.
- **Não refeito nesta rodada:** capturas de tela (`design_shots`) depois do card "Estilo de luta".
  **Não testado:** celular deitado e tablet, APK, carreira longa jogada à mão.

## Próximos passos (para o colega)

1. **Vida de presidente** — tarefa aberta do dono. Pesquisa e mecânicas em `docs/PRESIDENTE.md`;
   começar pela semana da luta (lesão → substituto, peso perdido → multa/peso combinado) e pela
   coletiva pós-luta.
2. Capturas das telas (`design_shots` nos dois papéis) e conferir o card "Estilo de luta".
3. Economia do presidente: a popularidade infla e satura público/PPV com o tempo (`Org.draw`).
4. Bandeiras que faltam no `nations.json` (THA, KAZ, UZB e outros aparecem como sigla).
5. Rostos: o renderizador mostra pouco nariz e boca em alguns tamanhos; conferir em 56–120 px.
6. Ideias do LEATHER que faltam: step-aside, mudar de categoria, torneios, comparar dois lutadores.

## APK de teste

- `releases/NoiteDeLuta-0.1.1.apk` (release, arm64, Android 7+; instala por cima da 0.1.0). Assinado com uma chave de teste
  local: um APK novo assinado com outra chave pede desinstalar o antigo antes.
- Para gerar de novo: modelos de exportação do Godot 4.7.2 (só `android_*.apk` e `version.txt` em
  `~/.local/share/godot/export_templates/4.7.2.stable`), Android SDK com `build-tools;34.0.0`
  (caminho em `export/android/android_sdk_path` nas configurações do editor) e o preset
  `export_presets.cfg` (sem gradle). Release:
  `GODOT_ANDROID_KEYSTORE_RELEASE_PATH=… _USER=… _PASSWORD=… godot --headless --path . --export-release Android build/NoiteDeLuta.apk`
  (ou `--export-debug` com a chave de debug do editor).

## Avisos

- **`trait` é palavra reservada no Godot 4.7** (por isso `Styles.mark`, não `Styles.trait`).
- Classe nova (`class_name`) precisa de `godot --headless --path . --import` antes do `check_scripts`.
- Há um `git stash` antigo ("wip-corner-office-tokens-e-motor"); não faz parte deste jogo.
- Não integrar ramos `codex/*`; perguntar ao dono antes de juntar na `main`.

## Comandos (na pasta `noite-de-luta`)

```
godot --headless --path . --import
godot --headless --path . --script res://tools/check_scripts.gd
godot --headless --path . --script res://tools/world_sim.gd -- --weeks=52 [--role=presidente]
godot --headless --path . --script res://tools/fight_soak.gd -- --n=300 --seed=7
godot --headless --path . --script res://tools/style_lab.gd -- --a=wrestling --b=muay_thai --log=1   # ou --world
xvfb-run -a -s "-screen 0 1600x1600x24" godot --path . --resolution 1400x1300 --script res://tools/face_sheet.gd -- --out=/tmp/rostos.png --nations=RUS,KAZ,GEO
xvfb-run -a -s "-screen 0 1400x1400x24" godot --path . --resolution 390x844 --script res://tools/design_shots.gd -- --out=/tmp/telas [--role=presidente]
```
