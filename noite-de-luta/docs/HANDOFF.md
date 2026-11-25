# Noite de Luta — nota de passagem (24/11/2026)

## Rodada 19 de 25/11/2026: seis idiomas (APK 1.4.0)

O dono: "Acho que já vale fazer a tradução pro Ingles, Espanhol, Alemão, Frances, Russo e Chines". O português continua sendo o texto-fonte escrito no código e nos JSON; os outros idiomas são catálogos.

- **Catálogo** `data/i18n/<idioma>.json` (en, es, de, fr, ru, zh): chave = texto em português, valor = tradução. Chaves com `%s`/`%d`/`{nome}` viram moldes; no valor, `{1}`, `{2}` reordenam os trechos e `[[m|f]]` escolhe o gênero que o português marcou (`{o}`, `{ao}`, `Nascid%s`). Chave com contexto `ctx|texto` (lida por `I18n.tc`): `visual|Mosca` (barba) e `treino|Leve` (intensidade). Plural russo "2–4|5+"; adjetivos de nacionalidade "masc|fem".
- **Motor** `scripts/core/i18n.gd` + `pattern_translation.gd` (o auto-translate dos Controls chama sozinho). Para texto montado sem chave inteira, corta em " · ", ": ", ", ", ". " etc., guarda número, ponto e "(…)" do fim e número do começo; moldes quase sem texto fixo ("%s a %s") só por último. Texto desenhado à mão (placas da luta 2D, tabelas, gráfico) passa por `I18n.t`. `I18n.shutdown()` (chamado pelo GameManager) evita o abort na saída.
- **Formatos** (`Fmt`): dinheiro (M/K, Mio./Tsd., млн/тыс., 万/亿), separador decimal e de milhar, meses, datas, ordinais, plural russo. Pesos (`Matchmaker.division_name`) vêm do catálogo fora do português.
- **Fontes**: Noto Sans (cirílico) e um recorte do Noto Sans SC entram como fallback de cada Saira (`Fonts.add_fallbacks`). O recorte chinês só tem os caracteres usados em zh.json: mudou o zh, recorte de novo com `pyftsubset NotoSansSC.ttf --text-file=… --layout-features='*'`. Créditos e licenças com a entrada Noto.
- **Idioma**: o do aparelho na primeira vez (sem tradução, inglês), Opções › Idioma, ou `--lang=xx`. Rodando pelo editor/ferramentas sem `--lang` fica em português, para os `tools/*_runner.gd` (que acham botões pelo texto em português) continuarem funcionando.
- **Ferramentas**: `tools/i18n_check.py --lang=xx --list` (o que falta), `--i18n-miss=ARQ` nos passeios de tela grava todo texto que apareceu sem tradução, `tools/i18n_cover.py` confere um desses arquivos. Texto novo no código precisa de chave nos seis JSON.
- Conferido com os passeios de tela nos seis idiomas (início, ficha, card e sede do presidente, luta ao vivo com narração e gritos do corner, coletiva, visual).

**Não feito**: nomes de cidades natais ficam na grafia local (Roma, München); apelidos brasileiros ficam em português; algumas concordâncias de gênero em russo/francês foram resolvidas com frase neutra. Ninguém nativo revisou as traduções.

## Rodada 18 de 25/11/2026: cara de cartaz de luta (APK 1.3.0)

O dono, ao receber o 1.2.0: "deixar ui e UX com menos cara de ia por favor". Leitura: azul-escuro com dourado, cartões arredondados com filete empilhados, cápsulas, frases de apoio e slogan em três tempos são o que dá cara de coisa gerada. Resposta: identidade própria de cartaz e transmissão de luta. Nenhuma regra do jogo mudou.

- **Cor** (`UIColors`): preto neutro em degraus (sem azul), texto cor de papel, amarelo de cartaz `#FFCF0D` no lugar do dourado. `UITokens.HAIRLINE` e `BAR` acompanham.
- **Forma** (`UITokens`, `tools/build_theme_runner.gd`): nada arredondado. `R_*` valem zero; botões, etiquetas, destaques e retratos levam o corte em diagonal nos quatro cantos (`CUT_SM`, `CUT`, `CUT_LG`, feito com `corner_detail = 1`), que é o octógono do emblema. `sb(bg, cut, ...)` agora recebe o corte. Cartão é chapa lisa sem contorno; destaque é moldura amarela de 3 px. O retrato (`Portrait.SHADER_TILE`) corta os cantos no shader.
- **Letra**: títulos (`UIKit.HEADLINES`: Title, Screen, Section, H2, Display) em Saira comprimida pesada e caixa alta, com entrelinha fechada; botão primário e abas em caixa alta; etiquetas (`UIKit.pill`) em caixa alta; `UIKit.badge` é só o número grande, sem quadrinho.
- **Peças**: `UIKit.section_header` é título de cartaz sobre um fio grosso (sem a marquinha colorida); segmento escolhido é chapa clara; a aba ativa da navegação é uma barra amarela no alto (sem cápsula); fundo das telas quase liso (`main.gd › _add_night`).
- **Cartaz** (`FightKit.faceoff`): os dois lutadores recortados sobre o campo do corner, cortado em diagonal, "VS" no meio, sobrenome em letra de cartaz. Vale para Início, Noite de luta, propostas, card, gala. O cabeçalho da ficha (`FighterScreen._header`) segue a mesma ideia com um lutador só.
- **Texto**: slogan do menu desligado (`BrandLogo` com `with_tagline` falso por padrão); o guia do Início ficou só com o passo e o botão; frases que explicavam regra saíram ou viraram uma linha de dado na ficha, academia, camp, propostas, desafio, noite; subtítulos das linhas de menu do Início e da Equipe saíram; botões primários mais curtos.

**Não feito nesta rodada**: telas do presidente só passaram pela troca de tema e pela revisão visual, os textos de apoio delas (TV, sede, organização, temporada) continuam longos; ícones são os mesmos; a tela de visual (`look_screen`) não foi redesenhada.

## Rodada 17 de 25/11/2026: luta viva e vida dos lutadores (APK 1.2.0)

O dono, depois do 1.1.0: "ta rapido o jogo ta perfeito, mas nao é divertido, nem intuitivo, nem facil de jogar", "numeros e telas demais, clique demais", "animações absurdas", "mais personalidade, mais historico dos lutadores, mais vida deles", "sem microcopy", "chechenos e russos", "todos que refletem a vida real", "estilos diferentes, coisas raras".

**Luta 2D**
- `Rig2D`: pés plantados (`plant`, `feet`, `feet_up`, `feet_tap`, `free`), passos (`step_feet`, um pé de cada vez, o mais atrasado primeiro) e perna resolvida do quadril até o pé dentro de `joints()`; o quadril desce na passada larga e o calcanhar de trás levanta. Chute e joelhada soltam a perna (`free`, ligado pelo palco em `_free_legs`).
- `FightStage2D._spring`: cada junta é uma mola (tabela `SPRING`: frequência parado, no lance, amortecimento); cansado responde mais mole. `_jolt` soma velocidade no impacto, `_push` empurra o corpo e a dupla anda junto (`_cx`).
- `_life` por escola (`guard`: boxe, dutch, thai, karate, tkd, capoeira, wrestler, judo, bjj, mma) e por lutador (`Rig2D.manner`: ritmo, balanço, altura das mãos, cacoete, pressão, comemoração). Castigo aparece na postura (perna batida, costela, rosto).
- Nocaute cai de quatro jeitos (`_ko_kind`, pelo último golpe); comemoração pela personalidade (`manner.cele`: frio sai andando, humilde ajoelha, guerra grita, show pula).
- Calção de cada um (`kit_cut`, `kit_stripe`, `kit_band`, cores próprias para quem não tem equipe).
- Palco com 47% da altura da tela em pé; a câmera usa `tall` para fechar mais.

**Luta jogável**
- `FightEngine.begin_round()` / `step_round()`: o round corre aos poucos (mesma sequência do `run_round`). A tela gera os trechos conforme o relógio anda, então `set_plan` no meio do round vale dali em diante.
- `FightScreen.SHOUTS`: gritos do corner no rodapé (em pé, por cima, por baixo). Gritar de novo solta. Sem abas durante o round: só as três últimas linhas da narração. Números e placar ficam no intervalo; o plano completo abre por um botão.
- "Noite de luta" (antigo plano de luta): frente a frente, leitura do técnico, plano em uma linha, Simular e Ir para a luta. O resto abre em "Plano e detalhes".

**Vida dos lutadores**
- `PastFights`: lutas de antes do jogo, geradas na hora a partir do cartel (nunca gravadas), coerentes com sequência, cinturões e datas. `tools/past_probe.gd` confere.
- `Bio` + `data/world/bio.json`: terra por cultura (Daguestão, Chechênia, Tartaristão, Ossétia), herança de família, frases de vida, linha do tempo, dons raros (`Fighter.gift`, entram no `Styles.profile`) e artes raras para o país.
- Ficha: primeiro quem ele é (escola, dom, traços, história), depois três barras, pontos fortes e fracos; os dezoito atributos abrem em "Todos os atributos". Carreira: marcos, lutas (do jogo e de antes), depois curvas e médias.
- `TutorialKit.tip` desligado (`force_tips` liga de volta).

**Não feito nesta rodada**: revisão de todos os textos de apoio das outras telas; animações de chão continuam as antigas (só ganharam mola); 3D não foi tocado.

## Rodada 16 de 24/11/2026: interface 2.0 (APK 1.1.0)

Pedido do dono logo depois do 1.0.0, nas palavras dele: "Eu acho toda a UI lenta, feia e
demorada. UX também péssimo, repense toda ela e refaça". A rodada refaz a base da interface
(velocidade), o visual (tema) e os caminhos (menos toques e menos leitura). Nenhuma regra do
jogo mudou: `fight_soak` dá os mesmos números e os saves antigos abrem igual.

**O que estava lento (medido no servidor; celular fraco é 6 a 8 vezes mais):**

- Cada retrato era uma malha de ~30 mil triângulos, refeita em 90 a 180 ms e redesenhada em
  todo quadro. Doze retratos na tela custavam ~100 ms por quadro no desenho por software.
- Toda tela remontava todos os nós a cada vez que aparecia (30 a 70 ms já com tudo em cache).
- A virada da semana (~350 ms) rodava na linha principal, com a tela parada.
- Dicas grandes e avisos empilhados cobriam o conteúdo.

**Velocidade:**

- **Retratos em imagem** (`scripts/autoload/portraits.gd`, autoload `Portraits`, e
  `scripts/ui/components/portrait.gd`, classe `Portrait`). O `PortraitView` continua sendo quem
  desenha, mas uma vez só: as camadas são montadas numa linha de trabalho (`build_layers()`),
  fotografadas num `SubViewport` e guardadas como textura, na memória (até 80 MB, sai a menos
  usada) e no disco (`user://cache/retratos`, WebP, até 4000 arquivos). A tela mostra uma
  silhueta até a imagem chegar. Três tamanhos guardados (`SIZES`); `VERSION` entra na chave:
  **aumente quando o desenho do retrato mudar**, senão o disco devolve o retrato antigo.
  `FightKit.portrait`, `cutout` e `staff_portrait` já devolvem `Portrait`; `Portraits.prewarm`
  adianta a equipe e os campeões. Um `spec` com `"temp": true` não vai para o disco (miniaturas
  do editor de visual). Quem ainda usa `PortraitView` vivo: o retrato grande do editor de
  visual e as três caras do menu.
- **Telas em cache** (`BaseScreen.on_show`): a tela só é remontada se o carimbo mudou
  (`GameManager.rev`, a semana, o formato da janela, menos animação). `rev` sobe quando o mundo
  muda (`save_now`, virada de semana, abrir ou começar carreira) e a cada toque que não trocou
  de tela (`main.gd`, `_after_tap`): quem muda o mundo sem salvar precisa subir `rev`.
- **Virada de semana fora da tela** (`GameManager.advance_week_async`, `WorkerThreadPool`), com
  o aviso animado (`UIManager.busy`). Sem tela (`--headless`) roda direto. O fluxo inteiro dos
  dois Inícios está em `DashKit.close_week(screen, many)`.
- **Figura de corpo inteiro e editor de visual**: a cabeça do `BodyView` é montada em outra
  thread quando `live = false` (é assim em `FightKit.body`, o da ficha; o padrão `true` segue
  na hora, para as folhas de teste). No editor, o retrato grande troca por
  `PortraitView.set_face_async` (monta num retrato solto, guarda com `cache_store` e só então
  mostra) e as miniaturas são `Portrait` em imagem. **Toda tarefa do `WorkerThreadPool` precisa
  de `wait_for_task_completion`**: sem isso o jogo aborta ao fechar (aconteceu no teste).
- Scripts das telas carregados em segundo plano na abertura; transições de 0,07 a 0,14 s;
  entrada dos cartões mais curta (`Anim`); um aviso por vez, no alto, por cima da barra.

**Visual ("noite de arena"):** paleta nova em `UIColors` (azul quase preto, dourado da marca
como única cor de ação, estados vivos, cantos vermelho e azul), raios e fios em `UITokens` e o
tema inteiro refeito em `tools/build_theme_runner.gd` (**rodar `build_theme.gd` depois de
mexer nele**): cartões arredondados com fio, botão principal dourado com "lábio", fichas em
cápsula, abas com filete, rótulos `Kicker`. Fundo com brilho no alto e os dois cantos
(`main.gd`, `_add_night`), caixa numa cápsula na barra do topo, cápsula dourada no item ativo
da navegação. A cor da equipe saiu dos botões: fica no escudo e no fundo do retrato
(`FightKit.tone_of`). Peças novas no `UIKit`: `kicker`, `badge`, `pill` em cápsula.

**Caminhos:**

- **Início** (os dois papéis) na ordem do que a semana pede: a luta de hoje ou a próxima, o
  passo do guia, o que espera decisão; depois a casa, a equipe, a temporada, a agenda e as
  notícias. Com luta da casa na semana, o rodapé tem **Simular** e **Ir para a luta** (não há
  mais botão travado).
- **Adiantar** (ao lado de Avançar semana): fecha semanas até aparecer algo que peça o jogador
  (luta da casa ou noite da liga, novidade na caixa de entrada, gala, sócios, caixa no
  vermelho), no máximo 12, e para com um toque (`DashKit.needs_player`). O arquivo é gravado
  uma vez, no fim (`GameManager.batch`).
- **Ficha do lutador**: os 18 atributos num cartão só, em duas colunas, na primeira dobra
  (`FightKit.attr_card`); depois potencial e moral (o "o que pesa" abre com um toque), rivais,
  físico, estilo e personalidade. O mesmo cartão de atributos serve a proposta e o plano.
- **Plano de luta**: o plano e a leitura do técnico vêm logo abaixo do confronto; pesagem e
  camp viraram um cartão ("Como chegam").
- **Mercado**, **Equipe** e **Academia** com menos texto: uma linha no lugar de cada
  parágrafo, finanças em três números e cinco lançamentos, atalho para o Mercado na Equipe.
- **Dicas** em faixa de duas linhas (um toque abre, outro fecha); guia dos primeiros passos
  compacto; a faixa da semana virou o aviso do alto.
- **Editor de visual**: as miniaturas de cabelo e barba são imagens (eram trinta retratos
  vivos na tela).

**Ferramenta nova:** `tools/page_shots_runner.gd` abre um save e captura cada tela do topo ao
fim da rolagem (comando no fim desta nota). As rotas de captura que apertam "Avançar semana"
esperam a virada terminar (`DashKit.closing`, `GameManager.turning`).

**Verificação:**

- `check_scripts`: 164 scripts, 0 erros. `fight_soak --n=100`: KO 10,8%, TKO 10,6%, FIN 23,6%,
  DEC 53,6%, EMP 1,5% (igual à 1.0.0). `world_sim` de 52 semanas nos dois papéis, sem erro.
- As 23 rotas de captura (em pé, deitado e tablet), 0 erros de script. A gala deitada ganhou
  uma dobra (24 e 20 telas em `l_sea` e `l_seap`): as linhas com retrato ficaram mais altas.
- `screens_perf` no save de 60 semanas, tempo até a tela estar desenhada (dois quadros, desenho
  por software, cache de retratos vazio), 1.0.0 → 1.1.0: Início 2092 → 336 ms, Rankings 3900 →
  274, Mercado 1526 → 226, Resultados 3282 → 230, Cinturões 994 → 217, ficha de campeão 710 →
  289, ficha de lutador da casa 566 → 251, Equipe 254 → 181. A montagem do editor de visual
  caiu de 802 para 19 ms (o retrato grande chega depois, sem travar). O piso desse teste é de
  ~160 ms (a tela de opções), que é o custo de dois quadros no desenho por software.
- `save_flow_test`: virada pelo botão, Adiantar e Continuar (ver a saída do teste).

**Não testado em celular de verdade**; a velocidade em aparelho fraco continua estimativa.

**Em aberto:** o primeiro desenho de cada retrato ainda custa (a silhueta aparece antes); as
telas do presidente herdaram o tema e a ordem nova do Início, mas não foram redesenhadas uma
a uma; o dono ainda não disse qual celular usa.

## Rodada 15 de 24/11/2026: lançamento (APK 1.0.0)

Última etapa do roteiro: ícone, abertura, créditos, configurações finais e build. Nenhum
sistema do jogo mudou: é marca, interface e um caminho novo no `GameManager` (voltar à cópia
de antes da atualização).

- **Marca** (`tools/gera_marca.py`, Pillow e numpy; sai em `assets/brand/`). O emblema é o
  octógono com o anel metade vermelho e metade azul (os dois cantos), a lona escura e a lua
  dourada da "noite". Peças: `emblema.png` (768 px, usado no jogo; o `.import` dele tem
  `mipmaps/generate=true`), `icone.png` (512, `config/icon`), `icone_192.png`,
  `icone_frente_432.png`, `icone_fundo_432.png` e `icone_mono_432.png` (os quatro
  `launcher_icons/*` do preset: ícone antigo, adaptável e de uma cor), `abertura.png` (1024,
  `boot_splash/image`: o emblema ocupa 40% do lado) e `facho.png` (o facho de luz). Com uma
  segunda pasta o script gera também as peças da loja (`icone_loja_512.png` sem cantos e
  `destaque_1024x500.png`). O `icon.svg` antigo saiu do projeto.
- **Abertura** (`scripts/ui/brand/`). `BrandBackdrop` desenha o clarão e os dois fachos
  (`beam` de 0 a 1). `BrandLogo` põe emblema, "NOITE DE", "LUTA", filete e chamada à mão,
  medindo pela tinta da fonte (`ASCENT` e `CAP`), com `mix` (0 = só o emblema no meio) e
  `bar_grow` para animar e `side_by_side` para o celular deitado. `IntroOverlay` começa igual
  à imagem de abertura da engine (mesma cor, mesmo tamanho), traz os fachos, toca o gongo com
  vibração, pulso e eco do emblema, abre espaço para o nome e sai sozinho em 2,25 s (um toque
  pula). Toca uma vez por vez que o app abre (`MenuScreen.opened`); não toca com "Menos
  animação", sem tela, nem com `AppSettings.intro = false` (as ferramentas `design_shots`,
  `look_shots`, `save_flow_test` e `screens_perf` desligam; `--abertura` liga).
- **Tela inicial** (`menu_screen.gd`): a marca em cima, os três rostos no meio, os botões
  embaixo (o conteúdo tem a altura da tela como mínimo e dois espaçadores), "Opções" e
  "Créditos" lado a lado e a versão no rodapé. Deitado vira duas colunas. Os tamanhos mudam
  com a altura (`tall` a partir de 1200) e no tablet (`big`).
- **Créditos e licenças** (`credits_screen.gd` e `licenses_screen.gd`, telas `credits` e
  `licenses`): versão, o que é o jogo, a assinatura lida de `data/credits.json` (linha com
  nome vazio não aparece, e **hoje está vazia: o dono ainda não disse como quer assinar**),
  "Feito com" (Godot com o texto da licença MIT de `Engine.get_license_text()`; fonte Saira
  com `assets/fonts/OFL-Saira.txt`; os 102 componentes de `Engine.get_copyright_info()`, cada
  um com seus avisos e o texto das licenças de `Engine.get_license_info()`), universo fictício
  e privacidade (sem internet, sem anúncios, sem coleta de dados). `_reflow` desfaz as quebras
  de 80 colunas dos textos.
- **Opções** (`settings_screen.gd`): cartões de Som (efeitos, volume Baixo, Médio ou Alto =
  30, 60 ou 100, vibração), Luta ao vivo (velocidade e 2D, 3D ou texto), Tela (menos
  animação), com a carreira aberta a ajuda e "Sair para o menu", ou, no menu, "Carreira salva"
  (voltar à cópia de antes da atualização, com `GameManager.restore_backup()`, e apagar a
  carreira) e Sobre. As chaves
  de ligar e desligar ganharam desenho próprio (`UIKit.install_switches`, chamado em
  `main.gd`): a desligada do Godot quase sumia no fundo dos cartões.
- **Build**: versão 1.0.0, código 17. `armeabi-v7a` ligado: o APK serve também em celular de
  32 bits (passou de 35 para 61 MB). Descrição do projeto atualizada.
- **O AAB da loja não foi gerado.** O build com Gradle baixa o plugin do Android do Maven do
  Google (`dl.google.com`), que a rede deste ambiente não alcança, e montar o AAB por fora
  (bundletool) foi barrado pelas regras da sessão. Com o dono liberando o endereço (um
  ambiente da nuvem próprio para este repositório, com `dl.google.com` permitido) ou fazendo o
  build no PC dele, o que falta é: Android SDK com plataforma e build-tools, o modelo de build
  do Godot (`Projeto > Instalar modelo de build do Android`, ou `android_source.zip` dos
  modelos de exportação em `android/build`), e no preset `gradle_build/use_gradle_build=true`
  com `gradle_build/export_format=1`.
- **Antes de publicar** (tudo depende do dono): decidir se publica; chave de envio dele (a de
  teste tem senha fraca e está anotada); de onde vieram os sons herdados do Mais Uma Rodada,
  que não têm licença registrada aqui (`achievement`, `applause`, `boo`, `lose`, `title` e
  `win` em `.ogg`; `back`, `click`, `tab`, `toggle_on`, `toggle_off`, `notify`, `notify_good`,
  `notify_bad` e `sign` em `.wav`; os outros saem de `tools/gera_sons.py`); a assinatura dos
  créditos; a ficha da loja (capturas em 16:9, textos, classificação indicativa, política de
  privacidade). O nome do pacote, `com.noitedeluta.mma`, não pode mudar depois de publicado.
- **Verificado**: `check_scripts` (161 scripts, 0 com erro); os 20 passeios de telas da rodada
  14 de novo (dois papéis, atletas, eventos, `look_shots`, `ui_shots` e temporada, em pé,
  deitado e tablet) com as mesmas contagens e sem erro de script; o passeio novo
  `brand_shots_runner` com a abertura ligada em pé, deitado e tablet (21 telas cada) e sem ela
  em tela curta (720×1280) e tablet em pé, que também aperta de verdade "Sair para o menu",
  "Voltar à cópia" e "Apagar a carreira" e confere o resultado; `save_flow_test` com todas as
  conferências verdadeiras; ícones e imagem de abertura conferidos dentro do APK (as quatro
  peças em cada densidade e `assets/brand/abertura.png`). `fight_soak` e `world_sim` não foram
  rodados de novo: nenhum arquivo de `scripts/systems`, `scripts/models` ou do motor mudou
  desde a 0.9.0. **Não testado em celular de verdade** (a passagem da imagem
  de abertura do Android para a do jogo, o som do gongo e a vibração só dá para conferir no
  aparelho).
- **Ficou para depois**: música; levar o save de um aparelho para outro (exportar e importar);
  o que já estava na lista da rodada 14.

## Rodada 14 de 24/11/2026: equilíbrio e polimento (APK 0.9.0)

Quinta etapa da lista do dono rumo à 1.0: economia nos dois papéis em 10 anos ou mais,
desempenho em celular fraco, migração de saves e varredura de bugs. O resultado das lutas não
mudou (`fight_soak --n=100` dá os mesmos totais, linha por linha).

- **Achado principal da varredura: "Continuar" nunca abriu o save.** `GameManager.load_save`
  lia a primeira linha (o resumo do menu) e depois chamava `get_as_text()`, que no Godot 4
  devolve o arquivo inteiro sem olhar onde a leitura parou; o JSON vinha com duas raízes, a
  leitura falhava e o menu dizia "Não foi possível abrir o save". Estava assim desde a 0.1.
  Agora o resto do arquivo é lido como bytes. Nenhum passeio apertava "Continuar"; o teste novo
  `tools/save_flow_test.gd` aperta.
- **Academia: economia refeita** (`scripts/systems/career.gd`). Antes entravam US$ 70 a 290 mil
  por ano contra US$ 260 a 300 mil de custo (caixa de 250 mil para −827 mil em 12 anos). Agora:
  **mensalidades** (`FEE` 36 por aluno por semana) de `students(w) = min(procura, capacidade)`;
  a procura vem da reputação e do apoio da cidade (`student_demand`: 60 + rep × 2,2 + (apoio −
  50) × 0,8, de 45 a 400) e a capacidade do staff (`student_capacity`: 45 do dono mais 25 +
  qualidade × 0,4 por profissional). Despesas (`upkeep`): **aluguel que acompanha a reputação**
  (`rent` = 700 + 25 por ponto), 8 por aluno e 150 por lutador mais 20 por ponto de nível acima
  de 50 (`fighter_cost`). `weekly_net` é o saldo fixo, mostrado no Início ("Fixo por semana")
  e na Academia, com aviso de procura maior que a casa ou de staff com turma vazia.
  **Dívida** (`_debt`): caixa negativo paga 0,4% de juros por semana; passando de
  `debt_limit` (80 mil + 2,5 mil por ponto de reputação) o profissional mais caro sai a cada
  4 semanas; sem staff, um **investidor local** assume a dívida (`_bailout`: caixa volta a 20
  mil, reputação cai até 2 pontos com piso de 8, apoio −2). O patrocínio do comércio agora
  cresce com reputação e alunos (`Season.sponsor`).
- **Liga: economia refeita** (`scripts/systems/org.gd`, `season.gd`). Antes sobravam US$ 140
  milhões por ano (1,69 bilhão em 12 anos, prestígio 100 no quarto ano). Agora: folha e
  estrutura de `Org.overhead` (650 mil + 15 mil por ponto de prestígio, por semana); **os sócios
  retiram 40% do lucro do ano** em dividendos (`Org.DIVIDEND`, pago em `Season.year_end`, com
  linha na cerimônia) e ano no prejuízo custa confiança; prestígio sobe cada vez mais devagar
  (`Org.prestige_gain`), decai acima de 50 e se recupera abaixo de 40; piso de 30 nas punições
  dos sócios (`Season.REP_FLOOR`). **Campeão defende duas vezes por ano**: descanso de 24
  semanas depois de luta de cinturão (`Matchmaker.REST_TITLE`; 7 nas outras) e 40 semanas para
  ser destituído por inatividade (`Titles.IDLE_WEEKS`); com isso a noite de cinturão volta a
  ser rara (antes 75% das noites tinham uma). Interesse por ingresso recalibrado em `Venue`.
  Cinturão vago há 10 semanas sem disputa marcada é preenchido pelo matchmaker quando o
  jogador delega o card (`Org._fill_vacant_belts`): antes ficava vago para sempre.
- **Fama com teto** (`scripts/systems/fame.gd`, `class_name Fame`). Todo ganho de fama passa
  por `Fame.add`: o teto depende do ranking (campeão 88 + 4 por defesa até 100, interino 88,
  top 5 86, top 10 78, top 15 70, top 30 62, resto 52, fora do ranking 42) e quem está perto
  ou acima do teto ganha cada vez menos; acima dele a fama escorre toda semana (`Fame.week`).
  Em 12 anos a elite fica estável (43 a 57 lutadores com 75 ou mais, 14 a 25 com 90 ou mais;
  antes passava de 100 e de 50).
- **Metas e conquistas ao dinheiro novo**. `Season.FIRST` com alvos menores para o primeiro
  ano do presidente; meta de caixa da academia usa `Career.weekly_net`. Duas conquistas eram
  impossíveis (500 mil e 1 milhão de pay-per-view numa noite; a conta para perto de 370 mil):
  agora 200, 300 e 350 mil. Também mexidos: ingressos esgotados (75 noites), noites quentes
  (15 e 100), 10 lutadores com fama 95 e reserva de US$ 250 milhões.
- **Desempenho** (medido aqui; celular fraco é perto de 6 a 8 vezes mais lento):
  - **Salvar não trava mais o toque.** `GameManager.save_now` (47 chamadas nas telas) só marca
    que há o que salvar; o arquivo é escrito por `flush` depois de 2,5 s sem toque, ao pausar
    ou fechar o app, no botão voltar do menu e ao fechar a carreira. A virada da semana também
    espera a pausa do jogador, mas a segunda semana seguida grava na hora (no máximo uma
    semana fica sem ir para o arquivo). Antes cada toque que salvava custava 120 ms no começo
    e perto de 1 s numa carreira de 12 anos.
  - **Save de carreira longa**: em 12 anos caiu de 13,4 MB (academia) e 10,4 MB (liga) para
    5,8 MB, e leva perto de 300 ms. Histórico de lutas, números da luta, atributos e progresso
    viram listas curtas no arquivo (`Fighter._pack_hist`, `Bout._pack_stats`,
    `Fighter._packed_attrs`; a leitura aceita o formato antigo); o histórico e o resultado já
    convertidos ficam guardados (`_hist_pack`, `_res_pack`); números quebrados com poucas
    casas; `Career._trim` agora tira das noites antigas as lutas que não são de cinturão nem
    da equipe do jogador (antes a noite inteira ficava por causa de uma luta), e aposentado
    sem título sai depois de 2 anos (`Legacy.PRUNE_AFTER` 104). Chaves do JSON sem ordenar.
  - **Semana**: 244 ms no começo e 335 ms em média em 12 anos (antes 324 a 370). Luta sem
    narração não monta mais as frases (gasta o mesmo sorteio, ver `HIT_PICKS` em
    `fight_engine.gd`: quem mudar as frases de `_hit_text` mantém a tabela igual) e o treino
    tirou contas repetidas do laço. Avisos "Fechando a semana…" e "Abrindo a carreira…"
    (`UIManager.busy`) aparecem antes de a tela parar.
  - **Telas** (mundo de 12 anos): Início 37 ms, Mercado de 123 para 57 ms (a lista comprida
    chega em blocos, `UIKit.fill_rows`), Rankings 39, Cinturões 63, Resultados 45.
- **Migração de saves**. 16 saves de oito versões (0.1.2, 0.1.6, 0.2.0, 0.2.3, 0.3.0, 0.4.0,
  0.5.0 e 0.6.0, nos dois papéis, 60 semanas cada) abrem na 0.9.0 e jogam mais 30 semanas sem
  erro; o save sai menor do que entrou. As telas foram percorridas com saves da 0.1.2, 0.3.0 e
  0.6.0. Save aberto por outra versão do jogo ganha uma cópia em `user://carreira_anterior.json`
  antes de ser regravado (o resumo do save agora leva a versão do app).
- **Outros acertos**: bandeiras que faltavam em 19 países (Cazaquistão, Uzbequistão,
  Quirguistão, Tajiquistão, Azerbaijão, Armênia, Belarus, Moldávia, Lituânia, Bulgária,
  Tailândia, Filipinas, Cuba, República Dominicana, Porto Rico, Afeganistão, Índia, Taipé
  Chinês e Vietnã; `FlagView` ganhou cruz no padrão "quarters" e crescente sobre faixas);
  "cansada de cortar peso" para lutadora; dicas da Academia, de casar lutas e da Organização
  com as regras novas; card de noite antiga avisa que só ficaram as lutas de cinturão e as da
  equipe.
- **Ferramentas novas**: `tools/economy_probe.gd` (de onde o dinheiro vem e para onde vai, ano
  a ano, por categoria), `tools/perf_probe.gd` (tempo da semana, parte por parte, e do save),
  `tools/screens_perf.gd` (abre um save e mede a montagem de cada tela) e
  `tools/save_flow_test.gd` (o caminho real: botão de avançar, save adiado, pausa do app e
  "Continuar"). O robô do `season_probe` agora disputa cinturão vago, demite staff com turma
  vazia e recusa luta acima do nível.
- **Calibragem** (12 anos). Academia ativa em quatro mundos: primeiro ano de +22 a +65 mil;
  três chegam a US$ 1,2 a 3,2 milhões com reputação de 65 a 100; o mundo de elenco fraco
  (semente 99) perde de 30 a 60 mil por ano, corta o staff e estaciona perto de zero, sem
  quebrar. Liga ativa (semente 2027): lucro de US$ 13 a 35 milhões por ano depois dos
  dividendos, prestígio 63, 73, 77, 78, 82, 85, 87, 88, 89, 93, caixa de 291 milhões no fim,
  22 a 27 lutas de cinturão por ano. Liga parada (semente 7): caixa oscila entre −19 e +18
  milhões por ano e o prestígio escorre de 48 para 27. Temporada em 6 anos (sementes 2027 e
  7): academia com 3, 0, 3, 1, 1, 3 e 3, 2, 3, 3, 3, 3 metas, 10 conquistas no primeiro ano e
  22 a 23 em seis; presidente com 3, 3, 2, 0, 3, 2 e 3, 1, 2, 2, 3, 0 metas, 14 conquistas no
  primeiro ano (eram 18) e 32 em seis, sem ultimato.
- **Verificado**: `check_scripts` (155 scripts, 0 com erro); `fight_soak --n=100` igual linha por
  linha ao da 0.6.0; `world_sim --weeks=156` nos dois papéis sem erro de script (saves de 3,4 e
  3,6 MB reabrem); `economy_probe` de 12 anos em quatro sementes da academia e na liga ativa e
  parada; `season_probe` de 6 anos nos dois papéis; 16 saves de oito versões antigas (0.1.2 a
  0.6.0, dois papéis) abrem e jogam mais 30 semanas sem erro; `save_flow_test` com todas as
  conferências verdadeiras (botão de avançar, save adiado, pausa do app, "Continuar");
  `screens_perf` num mundo de 12 anos; os 20 passeios de telas (`design_shots` nos dois papéis,
  atletas, eventos, `look_shots`, `ui_shots` e temporada, em pé, deitado 1688×780 e tablet
  1280×800) sem erro de script, e o passeio da luta de novo depois do último ajuste. O único
  `ERROR` nos registros é o do driver de som do servidor (ALSA), que não existe aqui.
  **Não testado em celular de verdade.**
- **Ficou para depois**: o save ainda é remontado inteiro a cada gravação (perto de 300 ms aqui
  numa carreira de 12 anos, alguns segundos em celular fraco, agora só quando o jogador para);
  a primeira abertura do Início e da ficha de um lutador na sessão custa uns 250 ms aqui; a
  dica "No corner" (`fight`) continua sem tela; a academia rica tem pouco onde gastar no fim.
- **Próximo**: 1.0 (ícone, abertura, créditos, configurações finais e build pronto para loja,
  AAB, se o dono quiser publicar).

## Rodada 13 de 24/11/2026: viciar (APK 0.6.0)

Quarta etapa da lista do dono rumo à 1.0: motivo para jogar a próxima semana e o próximo ano.
O motor da luta não mudou (`fight_soak --n=100` dá os mesmos totais).

- **Metas da temporada** (`scripts/systems/season.gd`, `class_name Season`). Três metas por ano,
  escolhidas na virada com sorteio próprio (`hash([seed, ano, "metas"])`, não gasta o do mundo):
  uma esportiva, uma de resultados ou de público e uma da casa. Empresário: defender cinturão,
  degrau no ranking (o melhor da casa × 0,9), disputar cinturão, vitórias, vitórias antes do
  fim, saldo positivo, três seguidas, equipe, reputação, caixa na virada, bolsas, estrear na
  Liga Global. Presidente: disputas de cinturão, noites quentes, público, cards completos,
  pay-per-view, lucro das noites, prestígio. Modos: `c` conta no ano, `r` basta alcançar, `h`
  vale como o ano terminar. Meta batida paga na hora (`Season.check` e `_reward`: dinheiro,
  reputação e +6 no termômetro); meta perdida custa na virada (5 para o presidente, 3 para a
  academia); as três cumpridas dão +5. O alvo do presidente sai da média dos últimos três anos
  (`_base`) vezes 1,03 (0,97 com prestígio de 95 para cima), com piso de 80% do alvo do
  primeiro ano (`FIRST`) e teto do calendário. Contadores do ano em `w.goals["c"]`, da
  carreira em `w.life` (`Season.bump`, `peak`); os ganchos estão em `Career.resolve`
  (`on_bout`), `Org.close_event` (`on_night`), `Signing` e `Career._pay`.
- **Pressão** (mesmo arquivo). Um termômetro de 0 a 100 em `w.support["v"]`: **apoio da
  cidade** para a academia (começa em 42) e **confiança dos sócios** para o presidente (50).
  Faixas em 20, 40 e 75 (`LOW`, `COLD`, `WARM`), com cinco nomes (`level_name`). Cada mexida
  tem motivo guardado (`nudge`, junta o mesmo motivo por até 8 semanas; `reasons` para a
  tela) e toda semana o valor volta 1,2% em direção a 50. Academia: vitória sobe (mais em
  evento grande e em casa), derrota desce pouco, campeão segura, equipe vazia, academia parada
  e caixa negativo descem; de 40 para cima o comércio local paga patrocínio semanal
  (`sponsor`), de 75 para cima lutador da terra assina mais fácil (`sign_bonus`) e a prefeitura
  premia na virada; três semanas abaixo de 20 e a cidade vira as costas (−3 de reputação, sem
  patrocínio até voltar a 40). Presidente: cada noite é comparada com as últimas seis do mesmo
  tipo (lucro e hype), noite cancelada e no prejuízo pesam, cinturão vago há mais de 6 semanas
  sem disputa marcada desce, prestígio subindo ou caindo mexe; de 75 para cima os sócios
  liberam verba (+3 de hype em toda noite, `hype_bonus`), abaixo de 20 seguram (−2); três
  semanas abaixo de 20 e vem o **ultimato** (12 semanas para voltar a 35). Ultimato perdido:
  na primeira vez, **intervenção** (15% do caixa em dividendos, −6 de prestígio, volta a 42);
  na segunda, **fim do mandato** (`Season.fired`): o jogador escolhe "Começar novo mandato"
  (`new_term`: caixa volta ao mínimo ou perde um quarto, −8 de prestígio, termômetro em 50) ou
  sai para o menu. Uma semana sem escolher e o mandato novo começa sozinho.
- **Conquistas** (`scripts/systems/achievements.gd`). 82 no total: 46 para o empresário e 44
  para o presidente (8 valem para os dois), em cinco grupos (lutas, cinturões, noites, a casa,
  temporada) e três níveis (bronze 10, prata 25, ouro 50 pontos). Cada linha de `DEFS` é
  `[chave, papel, grupo, nível, título, texto, medida, alvo, escondida]`; a medida é um
  contador de carreira (`life:...`) ou `rep`, `cash`, `debt`, `roster`, `staff`, `champs`,
  `sup`, `stars95`. `Achievements.check` roda depois de cada luta, noite e semana. Os pontos
  dão o **título de gestor** (`RANKS`: Novato, Promessa, Profissional, Respeitado, Estrela aos
  500, Lenda aos 800).
- **Cerimônia de fim de ano** (`gala_screen.gd`, tela "gala"). `Season.year_end` roda depois de
  `Legacy.year_end`, fecha as metas, guarda o balanço em `w.goals["past"]` (até 15 anos),
  sorteia as metas novas e deixa `w.gala = {year, seen: false}`. Ao avançar a semana da virada,
  `SeasonKit.after_week` abre a noite de gala sozinha, em etapas: abertura com os números da
  casa, prêmios do ano (os da academia destacados), Hall da Fama, "Sua temporada" (veredito,
  metas, termômetro do ano e conquistas) e as metas do ano novo. Dá para rever em Temporada,
  aba Anos. Os avisos de conquista esperam a cerimônia acabar.
- **Tutorial guiado** (`scripts/systems/tutorial.gd`, `scripts/ui/tutorial_kit.gd`). Cartão
  "Primeiros passos" no Início com seis passos por papel, botão que leva à tela certa e
  "Pular o guia"; os passos se cumprem jogando (`Tutorial.sync`), o último rende US$ 3 mil à
  academia e a conquista. **Dica de primeira vez** no alto de 16 telas (`TutorialKit.tip`,
  textos em `Tutorial.TIPS`), com "Entendi" e "Não mostrar dicas"; em Opções dá para religar e
  rever todas. A nova carreira tem o interruptor "Tutorial guiado".
- **Telas e peças**: tela "season" (`season_screen.gd`) com as abas Metas, Cidade ou Sócios
  (termômetro grande, linha das últimas 26 semanas, o que cada faixa rende, os motivos),
  Conquistas e Anos; cartão da temporada no Início dos dois papéis; `scripts/ui/season_kit.gd`
  (termômetro, linha de meta, linha de conquista, cartão de título, comemorações, aviso de
  intervenção e de fim de mandato); `scripts/ui/components/support_bar.gd`;
  `UIManager.award_toast` (aviso dourado com fila: dois por vez). Caixa de entrada: grupo
  "Temporada" com pendências da cerimônia, das metas novas, do ultimato e do apoio baixo.
- **Save**: `GameWorld.goals`, `support`, `life`, `feats`, `gala`, `tut` (e `pops`, que não é
  salvo). Save antigo ganha metas proporcionais ao que falta do ano, o termômetro no valor
  inicial, as conquistas que já merece sem aviso, o guia desligado e só a dica da tela nova.
- **Acertos de carona**: estreante sem luta aparecia como "sem luta há 1000 semanas" na caixa
  de entrada; prêmio do ano dizia "nocauteia com nocaute"; texto do Hall da Fama repetia as
  vitórias.
- **Ferramentas novas**: `tools/season_probe.gd` (joga N anos sozinho, ativo ou parado com
  `--lazy`, e mostra metas, termômetro, contadores e conquistas ano a ano) e
  `tools/season_shots_runner.gd` (passeio pelas telas da etapa; `--part=presidente`).
  `save_migrate.gd` agora mostra o que a temporada preencheu no save antigo.
- **Calibragem** (6 anos, sementes 2027 e 7). Academia ativa: 3, 1, 3, 3, 1, 3 e 3, 0, 1, 2,
  1, 0 metas, cidade entre 23 e 93. Academia parada: 3, 0, 0, 2, 2, 0, cidade caindo até 18.
  Presidente ativo: 3, 3, 2, 3, 2, 1 e 3, 2, 3, 3, 1, 0, sem ultimato em 6 anos. Presidente
  parado: 0, 3, 1, 3, 0, 3, com uma intervenção no segundo ano.
- **Verificado**: `check_scripts` 148 scripts, 0 erros; `fight_soak --n=100` igual; `world_sim
  --weeks=156` nos dois papéis sem erro; saves da 0.5.0 migrados nos dois papéis; passeio da
  etapa em pé, deitado e tablet; `design_shots` nos dois papéis, atletas, eventos, `look_shots`
  e os passeios da 0.5 em pé, deitado e tablet sem erro. **Não testado em celular de verdade.**
- **Ficou para a 0.9**: a economia da academia é negativa de nascença (bolsas de uns US$ 10 a
  30 mil por ano contra mais de US$ 130 mil de custo; o patrocínio local só ajuda) e a do
  presidente é generosa demais (US$ 115 milhões de lucro no primeiro ano); por isso os alvos
  de `FIRST` e as conquistas de caixa precisam de outra passada depois do reequilíbrio. O
  presidente ativo ganha 18 conquistas no primeiro ano (muita coisa de uma vez). A fama infla
  com os anos. O save cresce cerca de 1,3 MB por ano de jogo. "Cansado de cortar peso" sai no
  masculino para lutadora.
- **Próximo**: 0.9 (equilíbrio e polimento: economia nos dois papéis em 10 anos ou mais,
  desempenho em celular fraco, migração de saves, varredura de bugs).

## Rodada 12 de 24/11/2026: UI e HUD profissionais (APK 0.5.0)

Terceira etapa da lista do dono rumo à 1.0. O motor da luta só ganhou dados para a tela (não
gasta sorteio: `fight_soak --n=100` dá os mesmos totais).

- **Caixa de entrada com ações** (`scripts/systems/inbox.gd`, `scripts/ui/inbox_kit.gd`, tela
  "inbox"). `Inbox.scan(w)` roda no fim de `Career.advance_week` e ao abrir o Início ou a caixa:
  calcula as condições vivas do papel (`_manager` ou `_president`), fecha a mensagem cuja chave
  sumiu, atualiza título, texto e prioridade das que continuam e cria as novas. Mensagem:
  `{id, wk, key, cat, from, t, x, f, act, arg, pri, pend, st, rd}`. Pendência (`pend`) pede
  decisão e some sozinha quando a causa acaba; informação é notícia importada do mundo
  (`_import_news`, sem repetir, lida sozinha depois de uma semana). Empresário: noite de luta,
  proposta, equipe vazia, moral, contrato, camp, vaga de cinturão sinalizada, lutador parado,
  caixa. Presidente: incidente da semana, noite, TV, card incompleto, sede, cinturão vago,
  interino, unificação, caixa. `InboxKit.run` leva à tela da ação e `InboxKit.buttons` resolve
  ali mesmo o que dá (aceitar ou recusar proposta, renovar por 5 lutas, completar o card,
  conversar). O envelope da barra superior mostra quantas pendências estão abertas.
- **Painel inicial novo** nos dois papéis (`hub_screen.gd`, `org_hub_screen.gd`, peças em
  `scripts/ui/dash_kit.gd`): cartão da casa (selo, estrelas com "subindo" ou "caindo", caixa com
  a diferença em 4 semanas e linha de tendência `Sparkline`, três números), a noite desta
  semana ou a próxima luta com a contagem e o camp, "Para resolver" (as 4 pendências de maior
  prioridade), agenda das próximas semanas, faixa da equipe (ou dos campeões) que rola para o
  lado e as notícias. `Team.cash_log` e `rep_log` guardam 26 semanas (`Team.log_week`). Em tela
  larga a casa e o caixa dividem a mesma linha.
- **HUD da luta** (`fight_screen.gd` refeita, peças em `scripts/ui/fight_hud.gd`). Placar de
  transmissão: nome, ranking e cartel, round com as marcas dos rounds, relógio, fôlego e dano
  com o rótulo no meio e a linha de números da luta inteira (golpes, quedas, controle). Embaixo
  do palco, três abas: **Lances** (a narração), **Números** (comparação completa, da luta
  inteira ou do round, com barra dividida vermelho e azul) e **Placar** (o placar não oficial
  da transmissão round a round, feito com `FightHud.broadcast_round`, e quem leva o round de
  agora). O motor manda em cada lance narrado os números do round até ali (`ev["ls"]`, só com
  `narrate`), e o resultado guarda os cartões round a round (`result["rcards"]`, 3 juízes).
  **Ficha dos juízes**: na decisão a tabela juiz por round aparece um juiz por vez (som
  `score`, botão "Ver o resultado" corta a espera) e só depois vem o anúncio; depois de nocaute
  ou finalização entra "Como estava nos cartões". O resultado ainda ganhou "Números da luta".
  Juízes têm nome fictício fixo por luta (`FightHud.judge_names`). Luta antiga (save da 0.4.0)
  não tem `rcards` e mostra os totais como antes.
- **Celular deitado e tablet**. A luta deitada põe placar e palco à esquerda e abas, conteúdo e
  rodapé numa coluna à direita (`FightScreen._layout`, chamada de novo quando o aparelho gira;
  `BaseScreen` agora guarda as peças do esqueleto por referência e tem `fit_content`). O palco
  limita a escala pela largura (`_U = min(h / 9,6, w / 12,5)`) e fica mais alto em tela alta
  (teto de 560). Em pé, o palco encolhe para 66% quando a luta acaba, para o resultado caber.
- **Transições e animações** (`scripts/ui/anim.gd`: `stagger`, `count`, `grow`, `pulse`,
  `flash`, tudo desligado por "Menos animação" e sem tela). Cartões entram em sequência na
  primeira vez e depois de avançar a semana (`BaseScreen.play_intro`); a tela que sai desliza e
  some (`UIManager._animate_out`); a janela desce ao fechar, com um escudo que engole toque
  repetido; o aviso chega assentando; avançar a semana mostra uma faixa com a data nova, a
  diferença do caixa e as novidades (`UIManager.banner`, `DashKit.week_turn`); o saldo da barra
  superior conta até o valor novo e pisca verde ou vermelho; o envelope pulsa quando chega
  pendência. `UIManager.back` agora chama `on_hide` da tela que sai.
- **Sons de interface** sintetizados em `tools/gera_sons.py`: `week` (semana que vira), `score`
  (cartão de juiz), `cash` (dinheiro entrando), `mail` (novidade para resolver) e `sheet` (folha
  que abre). Os sons da luta saem idênticos do mesmo script.
- **Save**: `GameWorld.inbox`, `inbox_seq`, `inbox_nw`; `Team.clog` e `rlog`; `rcards` dentro do
  resultado da luta. Save antigo abre com a caixa vazia e sem importar notícia velha.
- **Ferramenta nova**: `tools/ui_shots_runner.gd` (painel e caixa de entrada do empresário; com
  `--part=presidente` os do presidente; com `--part=luta` o HUD numa luta que vai à decisão e
  noutra que acaba antes). `--prefix=`, `--tablet` e a resolução dão as versões deitada e tablet.
- **Verificado**: `check_scripts` 138 scripts, 0 erros; `fight_soak --n=100` igual; `world_sim
  --weeks=156` nos dois papéis sem erro; saves da 0.4.0 migrados nos dois papéis; `design_shots`
  nos dois papéis em pé e deitado, passeio dos atletas, dos eventos, `look_shots` e os três
  passeios da etapa em pé, deitado (1688×780) e tablet (1280×800 e 800×1280) sem erro.
  **Não testado em celular de verdade** (os sons novos também não foram ouvidos em aparelho).
- **Ficou para depois**: no tablet em pé sobra espaço embaixo dos lances (dá para pôr lances e
  números lado a lado); som de torcida de fundo na luta; a economia do presidente (0.9).
- **Próximo**: 0.6 (viciar: metas da temporada, conquistas, pressão dos sócios ou da cidade,
  cerimônia de fim de ano, tutorial guiado nas primeiras semanas).

## Rodada 11 de 24/11/2026: montagem dos eventos (APK 0.4.0)

Segunda etapa da lista do dono rumo à 1.0. Sete sistemas novos em `scripts/systems/`, com as
telas nos dois papéis. O motor da luta não mudou (`fight_soak --n=100` dá os mesmos totais).

- **Card em blocos** (`card.gd`). `FightEvent.bouts` vai da abertura até a principal (a última).
  De trás para a frente: luta principal, co-principal, resto do card principal (3, 4 ou 5 lutas
  por camada, `MAIN_CARD`) e preliminares. A ordem sai sozinha pelo peso de cada luta (`weight`:
  fama, ranking, cinturão, rivalidade, lugar combinado) até o presidente mexer à mão (`move`,
  `set_main`; daí `FightEvent.manual`). Disputa de cinturão não sai do topo. O lugar muda a fama
  de quem vence (`fame_k`: principal 1,3, co 1,15, card 1,0, preliminar 0,8) e nome grande nas
  preliminares fica contrariado (`Morale`).
- **Termômetro de hype com motivo** (`hype.gd`). `Hype.pair` devolve o valor de 0 a 100 e a
  lista de motivos com os pontos: fama dos dois (30% do nome maior, 22% do menor, pela curva
  `fame_pull`), superluta, cinturão (12), unificação (16), interino (7), rivalidade, revanche e
  trilogia (com desconto quando o público já viu demais), duelo de ranqueados, sequência,
  invicto, finalizadores, falastrão, lutar em casa. `Hype.event` é a principal inteira, 12% da
  co-principal, 2% de cada luta do resto do card principal e o que cerca a noite (numerado, TV
  aberta, card incompleto esfria). Faixas: frio até 35, morno, aquecendo a partir de 52, quente a
  partir de 70, pegando fogo a partir de 85. É este número que enche a arena, vende pay-per-view e
  paga o bônus de audiência.
- **Sede, arena e ingresso** (`venue.gd`, presidente). Cada cidade tem tamanho de mercado e poder
  de compra (`MARKET`) e lotação (`CITY_CAP`). Três arenas (`TYPES`: ginásio com 36% da lotação,
  arena, estádio com três vezes) e cinco faixas de preço (`PRICE_K` de 0,6 a 1,8). A procura sai
  do hype, da reputação e dos fatores da cidade (`crowd_factors`: mercado, lutadores da casa,
  cidade cansada de receber a liga, cidade que não vê a liga há mais de um ano e meio). Casa
  cheia dá prestígio, casa vazia tira (`fill_rep`). Sede e arena travam 3 semanas antes
  (`LOCK_WEEKS`); o preço muda até a semana da luta. `Venue.preview` faz a conta de uma escolha
  sem mexer no evento (é o que enche as tabelas da tela).
- **Contrato de TV** (`tv_deal.gd`, presidente; `GameWorld.tv`, `tv_offers`). Três parceiros
  (`PARTNERS`): TV aberta (paga 78%, patrocínio +45%, fama 25% mais rápida, +3 de hype),
  assinatura (o meio-termo) e streaming (paga 120% e leva o pay-per-view por um fixo alto por
  evento numerado). Bônus de audiência de 15% quando a noite passa de 65 de hype. Oito semanas
  antes do fim chegam três propostas; dá para pedir 10% ou 20% a mais (`ask`, pela força na mesa:
  reputação e hype médio das últimas noites); no segundo "não" o parceiro sai da mesa. Sem
  decisão, o contrato atual renova por seis meses com desconto. Saves antigos ganham um contrato
  curto de assinatura (`ensure`).
- **Rivalidades e revanches** (`rivalry.gd`, `GameWorld.rivalries`). Par de lutadores com calor
  de 0 a 100 e o motivo que mais pesou: luta apertada, disputa de cinturão, zebra, peso perdido,
  provocação pública, briga na coletiva. Esfria com o tempo e depois de trilogia decidida. Vende
  a luta, mexe com a moral, facilita o aceite e libera a revanche imediata (`rematch_ok`: calor a
  partir de 34, luta apertada, ou ex-campeão com defesas). Limite: quatro lutas entre os mesmos
  dois (`Matchmaker.face_reason`). Só guarda rivalidade de quem importa (top 40, equipe do
  jogador, seguidos).
- **Cinturão interino e unificação** (`titles.gd`, `GameWorld.interim`, `Bout.interim`). Campeão
  com lesão de 10 semanas ou mais, ou parado há 34 sem luta marcada, abre o interino (bolsa 1,3
  vez a tabela, cinco rounds, luta principal). Na volta, a luta seguinte dele é a unificação. Se
  o cinturão vagar, o interino é promovido; se o interino perder luta que não vale cinturão, o
  interino fica vago. No mundo que anda sozinho a liga marca tudo (`Titles.week`); o presidente
  decide na oferta. Para isso existir, `development.gd` passou a sortear lesões sérias (ombro 6 a
  14 semanas, joelho 8 a 24): 16% das lesões de treino e 24% das de luta dura.
- **Empresário negocia bolsa e luta** (`negotiation.gd`). A proposta chega com hype, lugar no
  card e bolsa. Pedidos (`ASKS`): 15%, 30% ou 50% a mais, mais garantido e menos bônus, apostar
  na vitória, outra data (para o camp inteiro) e um lugar melhor no card. A organização responde
  pela força do lutador na mesa (`leverage`, com motivos: fama para aquela camada, ranking,
  sequência, hype da luta, aviso curto, reputação da academia; chance de cinturão tira 14
  pontos). Ela aceita, chega no meio, mantém ou perde a paciência (3) e retira a proposta. Cada
  assunto só uma vez. No desafio (`challenge_screen`) dá para pedir tabela, 20% ou 40% a mais.
- **Vaga reservada para o cinturão** (`Matchmaker.shot_promised`, `user_shot`). Lutador do
  jogador entre os quatro primeiros pode ter a próxima disputa sinalizada (85%, 55%, 30%, 15%
  pela posição, sorteio fixo pelo campeão): a liga não marca o campeão com outro enquanto isso e
  a proposta chega com 80% de chance por semana. A ficha e a proposta avisam que vale esperar.
  O mesmo vale para o interino (`Titles.waiting_user`, `GameWorld.belt_wait`, espera 3 semanas).
- **Telas**. Novas: `venue_screen` ("venue", sede e ingressos), `tv_screen` ("tv"). Refeitas:
  `org_event_screen` (termômetro, sede, previsão das contas, card em blocos, ficha da luta com
  subir, descer, virar principal), `event_screen`, `offer_screen` (com a folha "Negociar"),
  `challenge_screen`. Mexidas: `book_screen` (interino e unificação, hype e lugar no card na
  oferta), `titles_screen`, `fighter_screen` (cartão "Rivais"), os dois inícios, `org_screen`.
  Peças: `scripts/ui/event_kit.gd` (termômetro, etiqueta de hype, card em blocos, tabelas de
  escolha) e `scripts/ui/components/heat_bar.gd` (barra de cinco faixas).
- **Save**: `Bout.interim` e `billing`; `FightEvent.venue`, `ticket`, `manual`; `GameWorld`
  `rivalries`, `interim`, `belt_wait`, `tv`, `tv_offers` (tudo só quando diferente do padrão).
  Saves da 0.3.0 abrem nos dois papéis e seguem 30 semanas sem erro. Save de 3 anos: 5,6 MB.
- **Ferramentas novas**: `tools/events_probe.gd` (hype por faixa, revanches, interinos,
  negociações e contas em números) e `tools/events_shots_runner.gd` (21 telas do presidente e,
  com `--part=empresario`, 13 do empresário).
- **Verificado**: `check_scripts` 130 scripts, 0 erros; `fight_soak --n=100` igual; `world_sim
  --weeks=156` nos dois papéis sem erro; saves da 0.3.0 migrados nos dois papéis; `design_shots`
  nos dois papéis, passeio dos atletas, `look_shots`, os dois passeios da etapa e um passeio em
  tablet (1280×800) sem erro. **Não testado em celular de verdade.**
- **Ficou para depois (0.9)**: a economia do presidente continua frouxa (de US$ 12 mi para perto
  de US$ 200 mi em 2 anos; Fight Night dá perto de US$ 1,9 mi e numerado perto de US$ 6,6 mi de
  resultado): sede, ingresso e TV já mudam a conta de cada noite, mas o nível geral precisa de
  aperto. Na sonda do presidente quase toda noite fica de "aquecendo" para cima porque ela marca
  cinturão em toda noite; conferir jogando. O equilíbrio da negociação só foi visto por sonda.
- **Próximo**: 0.5 (UI e HUD profissionais: painel inicial novo, caixa de entrada com ações,
  transições e animações, HUD da luta com estatísticas ao vivo e ficha dos juízes, sons, celular
  deitado e tablet).

## Rodada 10 de 24/11/2026: atletas de verdade (APK 0.3.0)

Primeira etapa da lista do dono rumo à 1.0. Seis coisas, todas ligadas à simulação e às telas, nos
dois papéis. O motor da luta não mudou (`fight_soak --n=100` dá os mesmos totais).

- **Moral e humor** (`scripts/systems/morale.gd`, `Fighter.morale` 0 a 100, `mood_log`). A moral
  anda 7% por semana na direção de um alvo (`Morale.target`) feito de motivos com texto
  (`Morale.factors`: sequência, último resultado, luta marcada, tempo parado, ranking, qualidade
  da academia, contrato, lesão). Resultado de luta dá um tranco na hora (`after_fight`), pesado
  pelo jeito do lutador (frio sente menos, nervoso mais). Efeitos: treino de 0,88 a 1,10
  (`train_k`), coração e QI na luta (`fight_mods`), renovação (`renew_mod`); infeliz por muito
  tempo avisa e pode ir embora. **Conversa** (`TalkSheet`, a cada 4 semanas): elogiar, cobrar,
  prometer luta ou dar folga; cada traço reage de um jeito (`Morale.talk`). Cartão "Moral" na
  ficha, etiqueta ao lado do nome na Equipe, seção "Pedem atenção" no Início.
- **Potencial escondido e olheiro** (`scripts/systems/scouting.gd`, `Fighter.known` 0 a 1,
  `GameWorld.scouting`). O teto nunca aparece como número: `Scouting.estimate` devolve uma faixa
  (centro com erro fixo por lutador, largura pelo que falta conhecer) que vira estrelas com a
  parte duvidosa apagada (`FightKit.potential_stars`) e frases (`report_lines`). O conhecimento
  vem do olheiro contratado (até 40% de todo mundo), de mandar observar (2 a 4 semanas, custa a
  viagem, fecha até o limite do olheiro, no máximo 2 ao mesmo tempo) e da casa (quem treina na
  equipe é conhecido um pouco mais por semana). Todo mês o olheiro indica 1 ou 2 nomes livres
  (`month`, seção "Indicações do olheiro" no Mercado). O presidente tem o departamento da
  organização (qualidade pela reputação) e não recebe indicações.
- **Campo de treino** (`scripts/systems/camp.gd`, `Fighter.camp`). Vale nas 8 semanas antes da
  luta marcada: foco (estudar o adversário, afiar o ponto forte, fôlego, corte de peso), onde
  (em casa ou fora, 2% da bolsa por semana) e sparring contratado (1,2% da bolsa por semana, 20%
  mais forma, 0,6% de risco de corte por semana). Junta pontos de forma (`week_gain`, até 100) e
  na pesagem vira ajuste de atributo (`mods_for`) ou alívio do corte de peso (`cut_relief`).
  Durante o camp o treino normal rende 75%. As outras equipes fazem o camp sozinhas
  (`auto_points`, sorteio fixo pela luta). Aparece na aba Treino, na proposta ("Tempo de camp"),
  no plano de luta (cartão "Camp" dos dois) e no Início ("camp 42%").
- **Estatísticas de carreira por luta** (`career_stats.gd`): cada luta do histórico guarda os
  números dele (`h["st"]`: golpes certos e tentados, quedas, tentativas de finalização,
  knockdowns) e o perfil mostra 11 medidas contra a média da categoria (verde ou vermelho quando
  a diferença passa de 10%).
- **Gráfico de evolução** (`scripts/ui/components/evolution_chart.gd`): nível pela idade, lutas do
  jogo em cima da linha (vitória ponto cheio, derrota anel, cinturão losango), faixa do teto que
  o olheiro enxerga e idade do auge. O trecho de antes do jogo é reconstruído pela idade e vem
  apagado. A curva só é guardada para os lutadores do jogador, os seguidos e os perfis já
  abertos (`sample_all`); os outros são reconstruídos quando o perfil abre.
- **Marcos de carreira** (`CareerStats.check_marks`, `weekly_marks`, `Fighter.marks` com a
  semana): vitórias, lutas, nocautes, finalizações, sequências, estreia, primeira luta principal,
  disputa e cinturão, defesas, ranking. Viram notícia (chapéu "marco"), linha dourada no
  resultado da luta e cartão no perfil com data e "A seguir". O que veio de antes do jogo entra
  sem data, de uma vez (`ensure_all_marks`, na criação do mundo e ao carregar um save).
- **Save**: campos novos em `Fighter.to_dict` (`mor`, `mlog`, `talk`, `prom`, `push`, `known`,
  `camp`, só quando diferentes do padrão), números da carreira como lista de inteiros na ordem de
  `Fighter.STAT_KEYS`, marcos antigos numa cadeia só (`mk0`) e `GameWorld.scouting`. Saves da
  0.2.3 abrem nos dois papéis (`tools/save_dump.gd` gera, `tools/save_migrate.gd` abre, anda 20
  semanas e salva de novo). O save de 3 anos ficou em 5,6 MB (era 5,3 MB).
- **Acertos de tela na passagem**: pesagem mostra o limite com a tolerância de meio quilo e "no
  peso"; placar de luta simulada mostra onde ela acabou (antes ficava em R1 5:00 com as barras
  cheias); linhas do Início e da Equipe encurtadas para não cortar em celular estreito.
- **Ferramentas novas**: `tools/athletes_shots_runner.gd` (20 telas da etapa, pelo
  `design_shots.gd -- --runner=athletes_shots_runner`), `tools/athletes_probe.gd` (moral, camp e
  olheiro em números), `tools/save_dump.gd` e `tools/save_migrate.gd`.
- **Verificado**: `check_scripts` 117 scripts, 0 erros; `fight_soak --n=100` igual; `world_sim
  --weeks=156` nos dois papéis sem erro (58 s contra 50 s antes); `design_shots` nos dois papéis, `look_shots` e o passeio da etapa sem erro; saves da
  0.2.3 migrados nos dois papéis. **Não testado em celular de verdade.**
- **Ficou para depois**: a folha de salários do staff completo afunda o caixa da academia em um
  ano e o save cresce perto de 1 MB por ano (os dois para a etapa 0.9); lutas de saves antigos
  não têm os números por luta; o equilíbrio fino de moral e camp só foi conferido por sonda
  (`athletes_probe`: moral média perto de 60, camps de 41 a 100 pontos), não jogando.
- **Próximo**: 0.4 (montagem dos eventos: card com principal, co-principal e preliminares, sede
  e arena, ingresso, TV, termômetro de hype, rivalidades, revanches, cinturão interino e, no
  papel de empresário, negociar bolsa e luta).

## Rodada 9 de 24/11/2026: retratos mais bonitos, realistas e variados (APK 0.2.3)

Terceira entrega da ordem combinada na rodada 7. Arquivos: `scripts/ui/components/portrait_view.gd`,
`face_shade.gd` e `scripts/generation/face_gen.gd`. Nada mudou no motor nem no mundo.

- **Luz por relevo ligada para todos** (`PortraitView.mesh_light_default = true`). O `FaceShade`
  já existia como teste: o rosto vira um mapa de altura (crânio, órbitas, nariz com dorso, ponta e
  asas, maçãs, lábios, queixo) e dele saem a luz, a sombra projetada, a oclusão e o brilho. Antes
  o rosto era iluminado por manchas pintadas, fracas demais (o nariz quase não aparecia).
  Vale a partir de 50 px; abaixo disso segue a pele antiga (`_skin_px`).
- **Acertos no `FaceShade`**: a borda do rosto não cai no preto (o traço escuro de "máscara" na
  mandíbula sumiu: sem oclusão no contorno e piso de luz ali); luz mais de frente e sombra
  projetada mais leve nas mulheres (`_soft`); borda antisserrilhada mais larga.
- **Olhos** (`_eyes_finish`, por cima da luz): devolve luz ao branco, acende a metade de baixo
  da íris, refaz o reflexo (dois nas mulheres e nos homens) e a linha dos cílios.
- **Enquadramento de lutador mais perto** (`FIGHT_ZOOM` 1,2 e `FIGHT_EYE_Y` 0,385): a cabeça
  ocupa metade do quadro; pescoço um pouco mais curto (`_body_setup`).
- **Pele muito escura exposta mais alto** (`_setup`: sobe a luz de quem tem luminância < 0,24).
- **Sete formatos de rosto** (`FaceGen._face_shape`, sorteio próprio pela semente: oval, comprido,
  redondo, quadrado, coração, diamante, retangular). **Atenção**: o formato do rosto de quem já
  existe num save muda; cabelo, pele, barba e traços continuam os mesmos.
- **Sobrancelha**: cor própria (`brow_col`: embranquece bem depois da barba; nas mulheres não
  embranquece) e mais cheia nos homens. Lábio dos homens mais perto do tom da pele, linha da
  boca mais firme, narinas e asas do nariz mais marcadas.
- **Corpo no retrato**: clavículas desenhadas por cima (`_clavicles`; na malha em colunas elas
  viravam riscos na base do pescoço), trapézio, deltoide e peitoral com mais volume, sombra do
  queixo mais funda, malha do tronco mais densa, orelhas no tom da borda do rosto.
- **Custo**: a luz por relevo soma cerca de 10 ms por retrato pequeno e 125 ms por retrato grande
  (420 px) na primeira vez; depois vem do cache de comandos. **Não medido em celular.**
- **Verificado**: `check_scripts` 108 scripts, 0 erros; `fight_soak --n=100` igual; `world_sim
  --weeks=156` nos dois papéis sem erro; `design_shots` nos dois papéis e `look_shots` sem erro;
  folhas de 56, 72, 96, 128, 180 e 420 px conferidas. **Não testado em celular de verdade.**
- **Próximo**: 0.3 (atletas de verdade; `career_stats.gd` já começado). Ideias que ficaram nos
  retratos: barba por fazer menos granulada, cabelo com menos luz colorida de recorte no black
  power, mais marcas de luta (cicatrizes, orelha) por tempo de carreira.

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
  teste guardada em `chave-teste/` lá; o atual é o 1.0.0 (arm64 e armeabi-v7a).
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
python3 tools/gera_sons.py assets/audio/efeitos   # refaz os sons da luta e da interface (precisa de numpy)
xvfb-run -a -s "-screen 0 1700x1300x24" godot --path . --resolution 1600x1230 --script res://tools/looks_sheet.gd -- --out=/tmp/visuais.png [--3d] [--seed=9]
xvfb-run -a -s "-screen 0 1700x1000x24" godot --path . --resolution 1600x900 --script res://tools/rig2d_sheet.gd -- --out=/tmp/bonecos.png [--fem]
xvfb-run -a -s "-screen 0 1900x1500x24" godot --path . --resolution 1860x1080 --script res://tools/roster_sheet.gd -- --out=/tmp/elenco.png --fem --n=20 --cols=5 --size=240
xvfb-run -a -s "-screen 0 1700x1500x24" godot --path . --resolution 1640x1440 --script res://tools/fem_lab.gd -- --out=/tmp/lab.png --key=bu --vals=0.1,0.5,0.9 [--body] [--look=mk:2,lp:5]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/look_shots.gd -- --out=/tmp/editor
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=athletes_shots_runner --out=/tmp/atletas
godot --headless --path . --script res://tools/athletes_probe.gd -- --weeks=104
godot --headless --path . --script res://tools/save_dump.gd -- --out=/tmp/save.json --weeks=60 [--role=presidente]
godot --headless --path . --script res://tools/save_migrate.gd -- --in=/tmp/save.json [--weeks=20]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=events_shots_runner --out=/tmp/eventos [--part=empresario]
godot --headless --path . --script res://tools/events_probe.gd -- --weeks=104 [--role=presidente]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=ui_shots_runner --out=/tmp/ui [--part=presidente|luta] [--prefix=l_] [--tablet]   # deitado: --resolution 1688x780; tablet: 1280x800 com --tablet
godot --headless --path . --script res://tools/season_probe.gd -- --years=5 [--role=presidente] [--seed=2027] [--lazy]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=season_shots_runner --out=/tmp/temporada [--part=presidente] [--tablet]
godot --headless --path . --script res://tools/economy_probe.gd -- --years=12 [--role=presidente] [--seed=2027] [--lazy] [--funds=0|1|2] [--csv=ARQ]
godot --headless --path . --script res://tools/perf_probe.gd -- --weeks=104 [--role=presidente] [--seed=2027] [--save=ARQ]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/screens_perf.gd -- --in=SAVE.json
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/save_flow_test.gd -- --out=/tmp/fluxo
python3 tools/gera_marca.py assets/brand [PASTA_DA_LOJA]   # refaz emblema, ícones e abertura (Pillow e numpy); depois, --import
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=brand_shots_runner --out=/tmp/marca --abertura [--tablet] [--prefix=l_]
xvfb-run -a -s "-screen 0 1900x1900x24" godot --path . --resolution 780x1688 --script res://tools/design_shots.gd -- --runner=page_shots_runner --out=/tmp/paginas --in=SAVE.json [--only=hub,team]   # cada tela do topo ao fim da rolagem
godot --headless --path . --script res://tools/build_theme.gd   # refaz assets/theme/main_theme.tres
```
