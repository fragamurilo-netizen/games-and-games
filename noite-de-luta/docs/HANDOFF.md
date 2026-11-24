# Noite de Luta — nota de passagem (24/11/2026)

## Rodada 8 de 24/11/2026: salto grande na luta 2D (APK 0.2.2)

Segunda entrega da ordem combinada na rodada 7 ("Vamos deixar o 3d de lado e evoluir de forma
ABSURDA o 2d"). Tudo em `scripts/ui/fight2d/fight_stage_2d.gd` (o "cérebro" que o 3D também usa),
`rig2d.gd` e `fight_screen.gd`. **Nada mudou no motor da luta**: o `fight_soak` dá os mesmos números.

- **Câmera**: o desenho inteiro passa por `_view()` (transformação do canvas: zoom em volta do
  centro da linha do chão, quadro descendo `_vy`, tremor). `_shot()` devolve `[zoom máximo, quanto
  o chão pode descer]` por momento (em pé por distância, clinch, chão, finalização encaixada,
  queda, replay, intervalo, fim) e `_camera()` enquadra a caixa de quem está em cena, sem cortar
  cabeça nem quem está na lona (`down`). O zoom nunca fica abaixo de 1 (a arena só cobre [0, w]).
  Fecha devagar (2/s) e abre depressa (6/s). `AppSettings.reduce_motion` trava o zoom em 1.
- **Palco maior**: `FightStage2D.stage_height()` = 36% da altura lógica (300 a 440).
- **Impacto** (`_impact`): parada no golpe (`_hitstop`), tranco de zoom (`_punch`), clarão
  (`_flash`), faísca com pontas, onda (`ring`), suor (`sweat`), faísca de bloqueio (`block`),
  protetor bucal voando (`mouth`), rastro do golpe na cor do canto (`_trail`), quadro de impacto
  com linhas de velocidade para dano ≥ 1,3 (`_slam`), torcida reagindo (`_hype`, flashes).
  A parada só entra com `time_scale < 2` e fila curta, para não atrasar a luta rápida.
- **Marcas de dano no boneco**: `Rig2D.leg_dmg` (coxa da frente) e `body_dmg` (costelas).
- **Apresentação do round 1** (só no 2D, `INTRO_S` 4,4 s): cada lutador no seu canto com placa
  (canto, apelido, nome, cartel, país, estilo), árbitro chama, toque de luvas, "ROUND 1".
  `holding()` segura o relógio da tela da luta enquanto isso.
- **Intervalo no canto** (só no 2D, `_corner_on()`): banquinho, treinador (um `Rig2D.referee` com
  a camisa da equipe e `hand` cor de pele), cortes de câmera entre os cantos a cada 3,8 s e placa
  com os números do round (`_stat`: golpes certos e quedas).
- **Legendas**: faixa presa no alto (`_draw_caption`), com entrada grande no meio só para
  KNOCKDOWN!, ENCAIXOU! e as de fim de luta. Placas no terço de baixo (`_plate`).
- **Lona com o nome do evento**: `FightStage2D.logo` (a tela da luta passa o nome sem o número).
- **Sons** (`assets/audio/efeitos/`: soco, soco_forte, chute, bloqueio, queda, gongo): feitos por
  código em `tools/gera_sons.py` (numpy). **Ninguém ouviu ainda**: só conferi duração, pico e
  espectro. `_sound()` só toca com o palco visível e limita a repetição.
- **No 3D** o cérebro é filho escondido (`is_visible_in_tree()` falso): câmera 2D, apresentação,
  intervalo no canto e sons 2D ficam desligados; o 3D continua como estava.
- **Ferramenta nova**: `tools/fight_strip.gd` (tira de quadros da luta em movimento, por caso:
  intro, troca, clinch, chao, intervalo, ko; `--at=` escolhe quadros exatos). `stage_sheet` agora
  usa células de 500×384.
- **Verificado**: `check_scripts` 108 scripts, 0 erros; `fight_soak --n=100` igual (KO 10,8% TKO
  10,6% FIN 23,6% DEC 53,6% EMP 1,5%); `world_sim --weeks=156` nos dois papéis sem erro;
  `design_shots` nos dois papéis sem erro (23 e 30 telas); `fight_strip` de todos os casos e
  `stage_sheet` (2D e 3D) conferidos. **Não testado em celular de verdade** (desempenho da câmera
  e volume dos sons são as dúvidas).
- **Próximo**: 0.2.3, retratos mais bonitos, realistas e variados para todo mundo. Ideias que
  ficaram para a luta 2D: entrada dos lutadores andando até o cage, árbitro levantando o braço
  do vencedor na decisão, replay com outro ângulo de zoom, narração curta por cima.

## Rodada 7 de 23/11/2026: lutadoras mais bonitas e editor de visual (APK 0.2.1)

Mudança de direção do dono ("Quero poder deixar as mulheres bonitas, gostosas" e "Vamos deixar o
3d de lado e evoluir de forma ABSURDA o 2d"). Ordem combinada: 0.2.1 (esta), 0.2.2 salto grande
na luta 2D, 0.2.3 retratos melhores para todo mundo, depois 0.3 em diante. **Sem tempo novo no
3D por enquanto.** Limite de conteúdo: atletas adultas em roupa de luta (top e shorts), sem nudez.

- **Rosto feminino** (`FaceGen._apply_female`, `_apply_glam`, `_fem_finish`): rosto oval
  (`jaw_soft`, mistura em `PortraitView._hw`), olhos amendoados maiores, cílios, delineado com
  gatinho, sombra, sobrancelha limpa e preenchida, batom com brilho, blush, luz de beleza
  (`soft_light`: refletor mais de frente e sombras macias), linhas de expressão mais tardias.
  `_fem_finish` roda por último e segura pescoço, largura do rosto, bochecha e ombro, para a
  categoria e o físico não deixarem a lutadora com cara de peso-pesado. `FEM_STYLE_W` agora
  prefere cabelo solto e comprido.
- **Chaves novas de `look`**: `mk` maquiagem 0–3, `lp` batom 0–8, `sd` sombra 0–7, `bu` busto,
  `ws` cintura (0 = fina), `hp` quadril (todas 0–1), `fm` massa do rosto (-1 a 1) e `ed` (marca de
  "editado": `Development.yearly_look` não troca cabelo nem barba de quem tem).
- **Erro antigo corrigido**: `_apply_mass` lia `ms` como massa do rosto, mas no lutador `ms` é o
  músculo do físico. Todo lutador forte saía de rosto gordo, olho pequeno e pescoço largo. A massa
  do rosto agora é `fm`; os rostos de homens e mulheres do elenco ficaram mais secos.
- **Corpo feminino**: `BodyView` com ampulheta por `bust`/`waist`/`hips`, shorts justo
  (`_shorts_fem`) e top esportivo com volume (`_top_fem`); `Body3D.torso_row` ganhou busto, cintura
  e quadril (vale para o 2D e o 3D); `Rig2D` tem perna, shorts, pescoço e detalhes de rosto
  femininos. A cabeça do `BodyView` são dois `PortraitView` (`layers`): o cabelo de trás fica
  atrás do corpo, não por cima do pescoço. No gerador, a gordura delas usa `wt * 0.55`.
- **Editor de visual** (`scripts/ui/screens/look_screen.gd`, tela `look`): aberto pelo perfil
  ("Visual" no cabeçalho e "Editar visual" no Físico), para qualquer lutador. Quadro fixo com
  retrato, corpo inteiro e boneco da luta; abas Cabelo (cor e miniaturas por tipo), Rosto (beleza,
  pele, olhos, formato, nariz, boca...), Maquiagem (elas) ou Barba (eles) e Corpo (barras). Cada
  ajuste vai direto para `Fighter.look`; `Fighter.look0` guarda o visual de antes ("Original").
  "Sortear" troca penteado e maquiagem/barba. Salva ao sair.
- **Ferramentas novas**: `fem_lab` (a mesma pessoa variando uma chave do `look`), `roster_sheet`
  (elenco como o jogo gera, retrato e corpo), `look_shots` (capturas do editor),
  `rig2d_sheet --fem`.
- **Verificado**: `check_scripts` 108 scripts, 0 erros; `fight_soak --n=100` igual (KO 10,8% TKO
  10,6% FIN 23,6% DEC 53,6%); `world_sim --weeks=156` nos dois papéis sem erro; `design_shots`
  nos dois papéis sem erro; `looks_sheet`, `roster_sheet` e `look_shots` conferidos.
  **Não testado em celular de verdade.**
- **Próximo**: 0.2.2 (salto na luta 2D). Ideias que ficaram: penteados novos de luta para elas
  (duas tranças boxeadoras, rabo alto); `BodyView._top` antigo não é mais usado.

## Rodada 6 de 23/11/2026: mundo vivo e realismo do 2D e do 3D (APK 0.2.0)

Primeira etapa do roteiro da 1.0 (documento "Noite de Luta: roteiro para a versão 1.0", nos
artefatos do projeto) mais a rodada de realismo que o dono pediu ("melhorar o 2D, 3D e o
realismo do jogo todo").

- **Mundo vivo** (`scripts/systems/legacy.gd`): `on_bout` guarda os candidatos a luta, nocaute e
  finalização do ano; `year_end` (primeira semana do ano) entrega os prêmios, faz a cerimônia do
  Hall da Fama (`legacy_score`, até 4 por ano), envelhece o visual de todo mundo
  (`Development.yearly_look`: cabelo, barba, entradas, grisalho, gordura depois de aposentar) e
  tira do save os aposentados sem história (`_prune`). Tela `legacy` (Prêmios, Hall da Fama,
  Recordes), aberta pelo Início nos dois papéis; honrarias no perfil do lutador (`honors`).
- **Corpo 3D** (`scripts/ui/fight2d/body3d.gd`): malha anatômica com pele (`ARM_TAB`, `LEG_TAB`,
  `TORSO_TAB`, `torso_row`, `arm_scale`, `leg_scale`), no lugar das formas simples. `skin_tone`
  segura a pele clara para não estourar na luz.
- **Lutador 2D redesenhado** (`Rig2D`): cada parte é uma tira com o mesmo perfil anatômico do 3D
  (frente = bíceps/quadríceps), leque na junta, volume por textura de sombreado (`_shading`),
  contorno em uma passada e desenho na outra (`_parts` guarda as tiras entre as duas). Giro de
  ombros e quadril, músculos que aparecem conforme o giro, tatuagens em traço, pé que dobra na
  bola. `joints()` usa tornozelo e joelho para o chão e puxa o pé perto da lona com IK.
- **Malha única** (seção "Malha única" do `Rig2D`): tudo que o lutador desenha (`_emit`, `_ov`,
  `_dot`, `_ln`, `_pl`, `_push_flat`...) entra em uma fita só de linhas de dois vértices, emendada
  por linhas sem área, e `_flush` manda uma chamada por lutador. Peças chapadas apontam para a
  faixa branca da textura (`UV_FLAT`). **Toda peça tem que ter número par de vértices.** A arena
  2D é pré-montada (`FightStage2D._bake_arena`: torcida em três camadas, grade, flashes). O quadro
  do palco 2D caiu de 7,96 ms para 2,1 ms nesta máquina.
- **Cabelo e barba na luta** (`scripts/ui/fight2d/hair_shape.gd`): lê o nome do penteado e da
  barba (`FaceGen.HAIR_STYLES`, `FaceGen.BEARDS`) e devolve um volume (alto, lados, nuca, franja,
  topete, coque/rabo/puffs, tranças, moicano, cacheado; barba por fazer, bigode, cavanhaque,
  curta, média, longa). Usado no 2D (`Rig2D._prep_head`) e no 3D (`FightView3D._pose_fighter`).
  Penteado novo entra sozinho pelo nome.
- **Arenas**: 2D com torcida de gente, treliça de luz, placas e lona pintada; 3D com arquibancada,
  torcida em `MultiMesh` (corpo e cabeça), três telões com o nome do evento, pintura da lona,
  base da grade na cor da organização, luz de contorno e tonemap mais contido.
- **Ferramentas novas**: `rig2d_sheet` (bonecos 2D soltos), `looks_sheet` (12 duplas variadas em
  guarda, 2D ou `--3d`), `body3d_sheet` (corpos 3D de frente, lado e costas), `aging_sheet` (o
  mesmo lutador aos 23, 31 e 39). `design_shots` agora avança um ano e captura a tela de Legado.
- **Verificado**: `check_scripts` 101 scripts, 0 erros; `fight_soak --n=100` igual ao de antes
  (KO 10,8% TKO 10,6% FIN 23,6% DEC 53,6%); `world_sim --weeks=156` nos dois papéis sem erro;
  `design_shots` completo; folhas 2D e 3D conferidas. **Não testado em celular de verdade.**
- **Próximo**: etapas 0.3 em diante do roteiro. No 2D ainda dá para pré-montar a arena em um nó
  filho (hoje a geometria é reenviada a cada quadro) se o celular pedir.

## Rodada 5 de 23/11/2026: segunda rodada da luta animada (APK 0.1.6)

- **3D**: giro de ombros e quadril (`tw` na tabela `STRIKE`; o soco esticado e a perna que sobe
  fecham no centro), antebraço, dorsais, abdômen em gomos (some com barriga), faixa lateral no
  calção, luva com dedos dobrados, rosto com maçãs, queixo, lábios, branco dos olhos; pele com
  rim light. Grid de luz com refletores, fachos no ar, dois spots e o nome do evento na lona
  (`Label3D`, passado pela tela da luta).
- **Direção de TV** (`FightView3D._direct`): planos aberto, lateral, fechado e de cima (no chão),
  corte a cada 4,5–7,5 s, fechado no knockdown e no fim; enquadra a caixa das juntas dos dois
  (cabeça e pés dentro). Lados da grade entre a câmera e a luta somem (`_fence`).
- **2D**: contorno escuro em cada boneco (passada `_ol` em `Rig2D`, primitivas `_cap/_circ/_poly/
  _cpoly/_line`), cem quilos e costas redesenhados; nas costas a perna e o braço de cá de quem
  pega por trás ficam por cima (`layer` 2).
- **Árbitro**: abre o round com o braço, chega perto de quem balança; no 3D tem gola, distintivo
  e luvas de látex. **Sangue**: nariz sangra com dano alto na cabeça, luva de quem bate em
  alguém cortado escurece (`glove_blood`), olhos fecham no knockdown/nocaute (`ko`).
- **Replay** em dois takes (inteiro a 0,5× e o golpe final a 0,22×, outro ângulo no 3D); no 2D
  faixas de cinema em vez de zoom.

## Rodada 4 de 23/11/2026: refinamento da luta animada (APK 0.1.5)

- **Bonecos 3D** (`FightView3D._build_fighter/_pose_fighter`): membros em cilindros que afinam
  (malhas compartilhadas por afinamento), deltoide, bíceps, quadríceps, panturrilha, joelho e
  cotovelo, peitorais, trapézio, abdômen (barriga), calção com barra e cós, luvas com polegar e
  punho na cor do corner, pés; rosto com mandíbula, orelhas, olhos, sobrancelhas, nariz, cabelo e
  barba. Músculo pelo físico (`arm_k`). Bases sempre destras (`_ell`), senão a malha vira do avesso.
- **Chão sem embolar**: chaves de pose só do 3D, `lz`/`az` (abrem pernas/braços para os lados) e
  `zz` (tira o corpo do plano); usadas em guarda, meia, cem quilos, montada e costas. No 2D, `zz`
  desce o boneco um pouco na tela (fica na frente).
- **Árbitro** (`FightStage2D.ref`, `Rig2D.referee`): camisa e calça escuras; acompanha pelo lado
  com mais espaço, agacha no chão, separa o clinch, aponta no knockdown, entra para parar a luta e
  levanta a mão do vencedor (também na decisão). No 3D fica atrás (z −3.4).
- **Sangue**: os lances trazem `cut` e `head` dos dois; o rosto ganha corte escorrendo e olho
  inchado (2D e 3D), golpe forte na cabeça de quem está cortado respinga gotas e deixa mancha na
  lona (`stains`, até 30).
- **Replay do nocaute**: o cérebro grava ~4 s de quadros (`_record`); depois do fim por KO/TKO
  toca de novo a 0,4× com zoom (2D) ou câmera baixa girando (3D) e selo REPLAY. `skip()` cancela.

## Rodada 3 de 23/11/2026: luta animada 2D e 3D (APK 0.1.4)

- **Lances estruturados** (`FightEngine.beats`, só com `narrate`): cada ação vira um dicionário
  `{r, t, type, side, pos, g, top, cage, dist, ...}` — golpe (técnica, zona, acertou, dano,
  contra-ataque), balança, knockdown, clinch/solta, queda (técnica, deu certo), puxar guarda,
  segurar chute, pegar o pescoço, ground and pound, passagem, levantar, raspagem, repor guarda,
  finalização (encaixou ou não), escapar, fim e fim de round. Não usa RNG (soak igual).
  `tools/beat_dump.gd -- --seed=3` imprime os lances de uma luta.
- **2D** (`scripts/ui/fight2d/`): `Rig2D` é o boneco de lado (cinemática direta; pose = ângulos;
  físico, rosto, cores da equipe, guarda por escola: boxe, thai, caratê, wrestler, MMA; canhoto
  troca a frente). `FightStage2D` é o "cérebro" e o palco: fila de lances, pose de base por
  posição (em pé por distância, clinch/plum, grade, guarda, meia, cem quilos, montada, costas,
  intervalo, fim) + o movimento de cada lance (tabela `STRIKE`/`CHAMBER`, reações de quem apanha,
  quedas de entrada e arremesso, sprawl, gnp, finalizações com tapinha), brilho do impacto,
  tremida, câmera lenta no nocaute, legenda. A fila acelera quando acumula e `skip()` resume.
- **3D** (`FightView3D`): o mesmo cérebro escondido dentro; a vista monta bonecos de cápsulas e
  esferas a partir das juntas 2D (profundidade nos ombros/quadril), octógono com alambrado
  (textura gerada), postes dos corners, lona, torcida (MultiMesh), luz com sombra e câmera de TV
  que acompanha e chega perto no chão. Renderizador de compatibilidade (mesmo do celular).
- **Tela da luta**: a vista fica entre o placar e a narração; botão no rodapé alterna 2D → 3D →
  Texto (`AppSettings.fight_view`, salvo no aparelho). O fim do round espera a animação acabar.
- Folha de poses: `tools/stage_sheet.gd -- --out=... [--3d] [--a=boxe --b=muay_thai]`.
- Ideias seguintes: árbitro, cortes/sangue no rosto, mais variação de passagens e raspagens,
  replay do nocaute, câmera 3D com cortes (close/aberta) e bonecos 3D com malha de verdade.

## Rodada 2 de 23/11/2026: rostos, corpos e personalidade

- **Rostos pequenos legíveis** (`PortraitView`): no recorte FM abaixo de 96 px o enquadramento chega
  mais perto (`FM_ZOOM_SMALL`), e abaixo de ~165 px `_small_cues()` reforça sombra sob o nariz,
  narinas, linha da boca e sombra sob o lábio.
- **Físico** (`FighterGenerator.physique`, chaves de `look`): `ms` músculo (força + luta agarrada),
  `bf` gordura (categoria, fôlego, idade; alguns pesados de barriga), `tr` trapézio/pescoço de
  wrestler, `tt` tatuagens 0–3 pela cultura (raras no Cáucaso e no Leste Asiático).
  `FaceGen._apply_physique` leva isso ao retrato (ombros mais largos por categoria, trapézio alto,
  pescoço grosso, tatuagens no tronco em `_body_tattoos`). Saves antigos ganham físico ao carregar.
- **Corpo inteiro** (`scripts/ui/components/body_view.gd`, `BodyView`): de frente, como na pesagem,
  com shorts nas cores da equipe e luvas; altura real em escala (`ref_cm`). A cabeça é um
  `PortraitView` com `head_only`. Aparece no perfil (card Físico, com o texto de
  `FightKit.physique_text`) e no alto da ficha de comparação (`FightKit.tape` → `bodies`).
  Folha de teste: `tools/body_sheet.gd -- --out=... [--fem] [--nations=BRA,RUS] [--h=700]`.
- **Personalidade** (`scripts/systems/persona.gd`, `Fighter.traits`): dois traços entre falastrão,
  humilde, disciplinado, preguiçoso, encrenqueiro, frio, nervoso, mercenário, guerreiro e showman.
  Pesam na balança, no treino, na fama, em aceitar luta (Org e substituto), na noite grande
  (mods do motor), na coletiva pós-luta (aposentar) e numa **coletiva pré-luta** nova: com um
  esquentado na luta principal pode sair provocação ou briga (`FightEvent.hype` soma no apelo).
  A expressão da foto segue o primeiro traço (`look.ex`). Card "Personalidade" no perfil.
- Ideias seguintes: corpo em guarda/de lado, mulheres no corpo inteiro com mais variação,
  rivalidades entre lutadores (falastrão × falastrão), humor do lutador com a equipe/organização.

## Rodada de 23/11/2026: vida de presidente (semana da luta e coletiva)

Ramo de trabalho: `claude/project-thread-cbowjz` (sai de `claude/inspiring-wright-xx78jb`).

- **Semana da luta** (`scripts/systems/fight_week.gd`, imprevistos em `GameWorld.incidents`):
  - **Lesão** nas 3 semanas antes da noite (chance própria `INJURY_P` + as lesões de treino do
    `Development._injure`, que no modo presidente viram decisão em vez de cancelar direto).
    Decisão: substituto em cima da hora (lista com chance de fechar e prêmio por aceitar de 30% da
    bolsa; o adversário pode recusar alguém muito abaixo), cancelar pagando a bolsa de quem ficou
    sem luta, ou cancelar sem pagar (perde prestígio). Campeão machucado tira o cinturão da luta.
  - **Balança** na semana da noite (a pesagem foi antecipada para segunda): peso combinado com
    20% da bolsa para o adversário (que pode recusar), peso combinado com extra da organização, ou
    cancelar. Campeão fora do peso **perde o cinturão na balança** (`Bout.title_for`: só o outro
    pode ganhar); desafiante fora do peso tira o cinturão da luta.
  - A chance de errar o peso em `Career.weigh_in` foi recalibrada: antes quase ninguém errava;
    agora ~3% por lutador (perto de uma luta a cada 2–3 noites).
  - O que o presidente não decide sai pelo padrão (`FightWeek.resolve_default`) antes das lutas.
  - Telas: cartões "Problemas da semana" no Início do presidente e na noite (a noite não começa
    com problema aberto), folha de decisão em `scripts/ui/week_kit.gd`. O card mostra "Peso
    combinado" e "Cinturão vago".
- **Coletiva pós-luta** (no relatório da noite): até 2 falas entre bônus extra do bolso, criticar
  os juízes de uma decisão dividida (multa possível), pagar a vitória a quem perdeu a dividida,
  anunciar a próxima defesa do campeão na próxima PPV (pode dar saia justa), mandar um veterano
  em fase ruim se aposentar (aceita ou se ofende) e exaltar a casa cheia. Tudo vira notícia.
- Verificado: `check_scripts` (85, 0 erros), `world_sim` de 52 semanas nos dois papéis com save,
  capturas `design_shots --role=presidente` (novas: `p09a`, `p09b_decidir_*`, `p17b_coletiva`).
- **APK** em `releases/` (0.1.2 código 3; depois 0.1.3 código 4 na rodada 2, mesma chave). A chave de teste fica nos arquivos do projeto, em `noite-de-luta/chave-teste/` (fora do git), para os próximos APKs instalarem por cima. Assinado com uma **chave de teste nova** (a da 0.1.1 não
  estava no repositório): no celular, desinstalar a 0.1.1 antes de instalar. Sem acesso ao
  `dl.google.com`, o `apksigner` veio do `uber-apk-signer` (GitHub) dentro de um SDK mínimo
  (`build-tools/34.0.0/apksigner` + um `platform-tools/adb` vazio só para passar na checagem).
- Próximos passos da vida de presidente: briga/declaração na coletiva **pré-luta**, cinturão
  interino quando o campeão fica muito tempo fora, programa de verão de olheiro, contratos e
  humor dos lutadores com a organização (ver `docs/PRESIDENTE.md`).

---

# Nota anterior (08/10/2026)

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

- APKs novos (0.1.2+) ficam nos arquivos do projeto (`noite-de-luta/`), assinados com a chave de
  teste guardada em `chave-teste/` lá; o atual é o 0.2.2.
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
xvfb-run -a -s "-screen 0 2100x3200x24" godot --path . --resolution 2020x3110 --script res://tools/stage_sheet.gd -- --out=/tmp/palco.png [--3d]
xvfb-run -a -s "-screen 0 700x520x24" godot --path . --resolution 600x420 --script res://tools/fight_strip.gd -- --out=/tmp/tira.png --case=troca [--every=5] [--at=30,90] [--cols=6] [--scale=0.5] [--tail=1.2] [--fem]   # intro, troca, clinch, chao, intervalo, ko
python3 tools/gera_sons.py assets/audio/efeitos   # refaz os sons da luta (precisa de numpy)
xvfb-run -a -s "-screen 0 1700x1300x24" godot --path . --resolution 1600x1230 --script res://tools/looks_sheet.gd -- --out=/tmp/visuais.png [--3d] [--seed=9]
xvfb-run -a -s "-screen 0 1700x1000x24" godot --path . --resolution 1600x900 --script res://tools/rig2d_sheet.gd -- --out=/tmp/bonecos.png [--fem]
xvfb-run -a -s "-screen 0 1900x1500x24" godot --path . --resolution 1860x1080 --script res://tools/roster_sheet.gd -- --out=/tmp/elenco.png --fem --n=20 --cols=5 --size=240
xvfb-run -a -s "-screen 0 1700x1500x24" godot --path . --resolution 1640x1440 --script res://tools/fem_lab.gd -- --out=/tmp/lab.png --key=bu --vals=0.1,0.5,0.9 [--body] [--look=mk:2,lp:5]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/look_shots.gd -- --out=/tmp/editor
```
