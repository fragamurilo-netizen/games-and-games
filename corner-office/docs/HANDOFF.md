# Continuidade — foco em grande liga e atletas realistas (Claude, 30/09/2026)

**Decisão do dono do projeto** (Game Design Bible §0): o jogo é um simulador do universo de uma grande liga no molde do UFC (fictícia). A liga é a nossa; as outras são pano de fundo. O núcleo é descobrir atletas, acompanhar carreiras e assistir às lutas.

Entregue na branch `claude/determined-clarke-dua3k2` (com `dreamy-carson` mesclada):

- Modo padrão `flagship` ("A Grande Liga"): Summit Fighting Championship (SFC), com cerca de 600 atletas nas 12 divisões e campeões; as 7 organizações viram ligas nacionais; circuito regional com 900 atletas (prospects e journeymen).
- Geração realista (`simulation/careers/`): país → grupo étnico → nome e rosto coerentes; altura, envergadura e peso por divisão; base marcial por país; modelo latente (pico, prime por divisão/estilo, desenvolvimento e declínio); cartel vindo de carreira pregressa simulada, com KO/SUB/DEC, rating público, sequência e últimas 10 lutas.
- Agentes, BATNA e memória de negociação (`simulation/contracts/agencies.gd`).
- Relatório de realismo: `godot --headless --path game -s res://tools/athlete_report.gd -- 2027`.
- CI: pushes em `claude/*` compilam o APK e o commitam em `releases/corner-office-<versão>-debug.apk` (0.3.0 nesta rodada).

Problemas conhecidos nesta build de teste:

- Save do modo liga está grande (~13 MB); autosave/carregamento podem ficar lentos no aparelho. Próximo passo: enxugar (histórico de ranking guarda placar de todos os atletas; `attr_noise` e resultados recentes por atleta).
- Telas nativas listam o elenco inteiro (600+ botões) — precisam de filtro por divisão, busca e paginação.
- Card da liga exige 10–14 lutas; alguns textos da UI ainda falam em "seis lutas".
- Ainda não existe evolução/declínio mensal, aposentadoria, surgimento de novos atletas, lutas do circuito durante o save, ranking top 15 por rating/inatividade nem matchmaker automático da liga (tarefas seguintes).

# Continuidade — carreira regional, Android e transmissão original

Branch compartilhada: `claude/dreamy-carson-628oai` em `fragamurilo-netizen/games-and-games`.

## Instrução mais recente do usuário

Usar **a simulação que já criamos no laboratório**. A alternativa nativa simplificada foi rejeitada e removida. Não reintroduzir `FightCanvas` ou bonecos de qualidade inferior. O jogo é para Android. Identidade de menus inspirada em UFC Undisputed 3; Chakra Petch é a alternativa tipográfica autorizada. Continuar a bíblia e publicar progresso para colegas.

## Entregue neste marco

- Carreira regional com 211 atletas fictícios (128 gerados + 70 de elenco extra das rivais + 13 canônicos), 30 no elenco inicial, free agency e divisões masculinas/femininas.
- Serviços Godot de contratação/renovação, proposta de luta, aceitação individual, scores esportivo/comercial separados e motivos de recusa.
- Eventos de 6–10 lutas: montar, remover confronto, anunciar, avançar até a data, simular, ver resultado e replay, repetir após repouso.
- P&L previsto/real, reserva de caixa de cards anunciados, pagamento e consumo de contratos uma única vez.
- Suspensão médica e validação do card no dia: indisponibilidade adia a noite inteira sem resultados/pagamentos parciais; reagendamento exige novo anúncio.
- Rankings oficial/mundial separados por elegibilidade, snapshots históricos e notícias disparadas pelo evento concluído/adiado.
- Cinco telas funcionais Godot, menu inicial, fonte local OFL, arte original, navegação portrait/landscape, autosave e confirmação/backup antes de nova carreira.
- Protótipo de carreira web chama os mesmos serviços Godot; salva de forma atômica; não implementa regras em JavaScript.
- Transmissão original do Fight Studio empacotada offline. `FightReplayView` entrega o registro ao mesmo código Canvas já existente; módulo Android Java e exportação Gradle no workflow.

## Rodar

Da pasta `corner-office`:

```sh
python tools/build_studio_bundle.py
godot --path game --editor
godot --path game
python tools/fight_lab_server.py --godot /caminho/absoluto/godot --port 8768
```

Carreira web: `http://127.0.0.1:8768/prototypes/promoter/`. Laboratório: `/prototypes/fight-lab/`. Transmissão sem ferramentas de autoria: `/prototypes/fight-lab/broadcast.html` (demonstração feminina quando nenhum replay da carreira foi solicitado).

O servidor guarda `.local/career.json` (ignorado). `--data-dir` permite outro slot. Não apagar saves durante QA. O save desktop Godot fica em `user://`; é separado do save web. O botão Assistir abre a transmissão dentro da tela do jogo: Android pelo módulo `CornerOfficeStudio`, desktop pela extensão `godot_wry`; sem WebView cai em `user://fight-studio.html` no navegador.

## Verificação

```sh
tools/run_tests.sh
node prototypes/fight-lab/tests/replay.cjs
node prototypes/fight-lab/tests/presentation.cjs
python tools/test_career_api.py --godot /caminho/absoluto/godot
python tools/build_motion_catalog.py
python tools/build_replay_examples.py
python tools/build_simulated_replays.py
python tools/build_studio_bundle.py
git diff --exit-code -- game/content game/presentation/fight/studio.cobundle
```

Última rodada de serviços: 20 testes sem falhas; amostra regional de 16 noites / 96 lutas, com lucros e prejuízos; amostra de combate de 160 lutas. A API foi testada em diretório temporário: seis lutas, seis replays imutáveis, reload, validação de origem e preservação do save em pedidos rejeitados. Isso ainda não é o soak de milhares de lutas da bíblia.

Capturas Godot portrait 720×1280 e landscape 1280×720: `godot --path game -s res://tools/capture_mobile.gd -- /destino capture`. O capturador cria mundo efêmero; não toca no autosave. Não usar capturas antigas de `native-fight.png` como produto: mostram a alternativa descartada. Transmissão original foi verificada no browser em 390×844 e em desktop; validar também no WebView de aparelho Android.

## IA das organizações rivais (Claude, 30/09/2026)

`simulation/organizations/org_ai.gd` roda uma vez por dia no `WorldSim` e na criação do mundo. Cada rival:

- agenda a próxima noite conforme a cadência dos traços executivos (`career_tuning.json › rival_ai.cadence_days`);
- monta o card com o **mesmo** `Matchmaking.evaluate/propose` do jogador, pareando pela ordem pública (ranking oficial; popularidade para `star_first`/`spectacle_first`), sem revanche imediata; contraproposta com prêmio de 1,3×;
- corta os confrontos menos comerciais até caber no caixa; cancela se não fechar 4 lutas; noites adiadas são consertadas ou canceladas;
- renova contratos no fim (libera quem tem 3+ derrotas a mais que vitórias; o atleta pode recusar) e contrata agentes livres quando o elenco fica abaixo de 20 (`aggressive_buyer` paga 1,2× e mantém elenco maior).

Só usa dados públicos (cartel, ranking, popularidade) — teste `test_rival_ai_ignores_hidden_skill`. Eventos rivais passam pelo mesmo `run_event`: resultados, balanço, WCI e notícias. A tela Início mostra a agenda do mercado.

Amostra de 2 anos (2 seeds): ~55 noites rivais, ~410 lutas, ~48 contratações rivais, elencos entre 12 e 30.

**Calibragem do combate (feita):** o soak `tools/soak_fights.gd` (3000 lutas geradas) mostrava ~50% de finalizações. As constantes de finalização, golpe limpo, peso da técnica (`skill_spread`) e dano por sexo agora vivem em `fight_tuning.json`. Resultado: masc. 20% finalização / 33% KO-TKO / 45% decisão; fem. 19% / 20% / 60%; favorito técnico vence ~57% das lutas equilibradas. `test_combat_calibration` trava regressões grosseiras.

## Fight Night (Claude, 30/09/2026)

`broadcast.html` virou uma noite completa no estilo UD3: abertura, walkouts, tale of the tape, locutor fictício Dario Valente (nunca usar locutores reais), HUD, câmera diretor, intervalos, replay em câmera lenta do final, cerimônia e tela de resultado. Dados extras em `replay.presentation`. Detalhes em `FIGHT_VISUALS.md`. Próximo passo natural: levar a mesma linguagem visual às telas Godot da carreira.

## Integração 0.4.0 (Claude, 30/09/2026)

`claude/dreamy-carson-628oai` agora junta as branches paralelas: determined-clarke (agências/BATNA, liga principal), project-thread-2uj2qo (gerador, tempo, progressão), klzt5i (artes marciais), 3etjpt (retratos, bandeiras, rankings/P4P), su2l5q (universo e enciclopédia), w8d3lp (central de notícias), 0sx6y9 (menus UD3 e hub) e 1vk3sj (noite inteira no Fight Studio). APK: `releases/corner-office-0.4.0-debug.apk`.

Decisões da junção: pedido do agente sobe para a proposta rival quando ela é maior; liga principal usa a própria capacidade e as demais escalam pelo patamar; migrações v1→v2 dos dois ramos unidas (`_backfill_progression`, também na v2→v3); regiões finas do gerador (China, Sudeste/Sul da Ásia, Caribe) + América do Sul; bandeiras novas para BD, CI, DO, GH, JM, MY, PK, PR, VN; cobertura da imprensa roda uma vez por noite.

Pendente: `test_player_progression` pede reputação +12 em 3 anos e a soma dá +9 (agências encarecem contratações). É balanceamento, não erro; ajustar metas/ganho de reputação ou o limiar do teste.

## Transmissão embutida no jogo — EM ANDAMENTO (Claude, 30/09/2026)

Pedido do usuário: a luta deve abrir **dentro da tela do jogo** (WebView nativo do jogo), não em diálogo por cima nem no navegador. Continua usando o mesmo Fight Studio (nada de renderer novo).

Feito:
- `game/ui/fight_replay_view.gd`: tela Fight Night com cabeçalho do jogo (bloco vermelho "‹ CARD", confronto e evento) e um palco onde a WebView é posicionada. Trata safe area, voltar do Android e fechamento pelo HTML.
- Android: `CornerOfficeStudio.java` não usa mais `Dialog`; a WebView entra como view filha do layout da activity no retângulo do palco (`show(html,x,y,w,h)`, `set_rect`, `set_visible`, `close`, sinal `closed`). AAR recompilado.
- Desktop: extensão `addons/godot_wry` (MIT, WebView2 no Windows, WebKitGTK no Linux) compilada aqui a partir do fonte; ver `addons/godot_wry/SOURCE.txt`. Sem ela a tela cai no navegador.
- `broadcast.html` em modo embutido (`body[data-embedded]`) esconde o próprio botão voltar; o voltar do resultado chama `CornerOffice.close()` (Android) ou `window.ipc.postMessage('close')` (desktop).
- **Bug corrigido:** o `aapt` do build Gradle descompactava `studio.html.gz` e tirava a extensão, então a transmissão nunca abria no Android. O pacote agora é `presentation/fight/studio.cobundle` (mesmo gzip).
- CI Android voltou a ficar verde (`setup-android` com `packages: ''`).
- APK de teste: `releases/corner-office-0.2.0-debug.apk` (com a WebView embutida).

Falta (próximo colega):
1. **Testar em aparelho Android**: posição/tamanho da WebView sob o cabeçalho, rotação (o `resized` chama `set_rect`), voltar, pausa/retorno, áudio após o toque em INICIAR.
2. **Testar no Windows**: `godot_wry.dll` foi cruzado com mingw (`x86_64-pc-windows-gnu`) e nunca rodou num Windows real; precisa do WebView2 Runtime. Se não carregar, compilar com `just build` numa máquina Windows (alvo msvc) e ajustar `WRY.gdextension`.
3. Linux: a `.so` exige `libwebkit2gtk-4.1`; o job `tests` do CI roda sem ela (a extensão só é usada fora do modo headless).
4. Tirar screenshot da tela embutida (a WebView é janela nativa: o `get_texture()` do Godot não a captura; usar captura do sistema).
5. Opcional: esconder também a marca/topbar do HTML em modo embutido se ficar redundante com o cabeçalho do jogo.

## Noite completa no motor 2D (Claude, 30/09/2026)

Pedido: integrar o motor 2D (Fight Studio em WebView) ao jogo real. A ponte já existia; agora a noite inteira passa por ela.

- **REALIZAR EVENTO** simula a noite e abre a transmissão na primeira luta do card; eventos concluídos têm **ASSISTIR À NOITE**, e "Assistir à luta" abre a noite a partir daquela luta.
- `FightReplayView.open_night(replays, start)` guarda a fila (preliminares → principal). O cabeçalho mostra `LUTA i/N`; a tela de resultado do HTML ganha **PRÓXIMA LUTA ›** (Android: `CornerOffice.next()` → sinal `next`; desktop: `ipc 'next'`). `open(data)` continua valendo para uma luta só (demonstração).
- `presentation.card_position` e `presentation.next_bout` são só apresentação; os replays não mudam (teste `test_night_queue_marks_card_position_without_touching_replays`).
- Verificado: 92 lutas reais de uma carreira gerada (seed 2027, 20 semanas) carregaram no `studio.cobundle` em Chromium 390×700 do portão ao resultado, sem erro de JS.
- Ainda falta testar em aparelho Android e no Windows (itens da seção anterior continuam valendo). AAR antigo sem `next()` cai no comportamento de fechar.

## Estilos reais, golpes assinatura, cabelos, barbas e corpos (Claude, 30/09/2026)

Pedidos: "estilos de luta reais + um número massivo de animações" e "muitos cabelos e barbas novos, corpos com muito mais variações".

- **Golpes:** `tools/build_motion_catalog.py` ganhou cerca de 170 golpes assinatura por arte marcial (boxe, muay thai, kickboxing, caratê, taekwondo, wrestling, judô, BJJ, sambo, MMA), com movimentos próprios (`shape_motion`: gancho, uppercut, superman, chute rodado, tornado, uchi-mata, seoi-nage, suplex, sumi-gaeshi, raspagens, chaves de perna…) e combinações. Catálogo: 328 técnicas, 1138 trilhas; os 158 clipes antigos não mudaram.
- **Motor:** `fight_tuning.json → signature` pesa o repertório pelo estilo do lutador (próprio 3.0, MMA 0.6, outros 0.12), renormalizado por categoria, então o equilíbrio de categorias não muda. `_by_position` indexa clipes por posição (a suíte sim ficou mais rápida). Cotoveladas cortam mais. Finalizações ~13% (antes ~20%; teste de calibração passa), decisões ~48%, KO/TKO ~37%.
- **Aparência:** `identity.js` ganhou 26 cabelos e 14 barbas (`novo:2`) e 20 tipos de corpo (`BODY_TYPES`, com `arms`, `neck`, `traps`, `belly` além dos parâmetros antigos); `studio.js` e `renderer.js` desenham os novos parâmetros.
- **Catálogo para o gerador:** `game/content/appearance_catalog.json`, gerado por `node tools/build_appearance_catalog.cjs` a partir de `identity.js` (82 cabelos, 33 barbas, 20 corpos, 15 populações). Cada tipo de corpo traz `generator_body_type` (lean/athletic/compact/muscular/heavy do gerador) e afinidade por categoria de peso. O CI regenera e confere o diff.

## Dano realista nas lutas (Claude, 30/09/2026)

Pedido: "deixar o dano nos personagens muito mais realista nas lutas". Só apresentação; resultados não mudam.

- `replay.js → woundMarks` cria um ferimento por golpe registrado: a gravidade é o delta de `damage`/`cuts` que o motor gravou naquele evento; posição e lado vêm de hashes fixos (lado do membro que bateu). Chutes bloqueados marcam o antebraço. `sample()` devolve `wounds` até o instante atual.
- `renderer.js`: o rosto ganha inchaço e olho roxo por lado (o olho fecha com castigo pesado), vermelhidão, galo na testa, lábio partido, sangramento nasal, cortes com sangue escorrendo aos poucos, e suor. Corpo e perna ganham manchas que nascem vermelhas e escurecem em hematoma, agrupadas por região (fígado/costelas, coxa, panturrilha). Também: sangue pingando no peito, luvas sujas de sangue de quem bate num corte, respingos de suor/sangue no golpe limpo, balanço quando abalado, respiração pesada com pouco gás.
- A escala visual segue a faixa real do motor (dano de cabeça ~0–0,3 numa luta inteira); os limites antigos (>0,35) quase nunca apareciam.
- Testes: `presentation.cjs` confere que ferimentos só vêm de dano/corte registrados, somam no máximo o dano final, acumulam e são determinísticos. O teste Godot de sangue agora escolhe um replay simulado que tenha corte.

## Próximas tarefas, por prioridade

1. Confirmar build do workflow Android, instalar APK e testar rotação, botão voltar, suspensão/retorno, save e desempenho da WebView. Sem SDK local nesta máquina; não afirmar teste em aparelho sem fazê-lo.
2. Sessão de jogo completa em aparelho: contratar, montar card misto, anunciar, assistir e organizar a segunda noite. Medir legibilidade e fluidez antes de expandir sistemas.
3. Melhorar perfis nativos com os retratos do gerador existente. Hoje as listas Godot são textuais; o protótipo web já usa os retratos.
4. Ofertas concorrentes/BATNA e memória de agentes sobre a IA rival já existente.
5. Separar modelos completos de ranking oficial e WCI: hoje listas/elegibilidade são distintas, mas compartilham uma fórmula inicial de resultados/oposição. Falta o composto completo e tratamento de inatividade da bíblia.
6. Popularidade dinâmica, campeões/títulos, peso/camp, lesões detalhadas e substituições. Suspensão atual é regra inicial de pós-luta, não um sistema médico completo.
7. Economia de longo prazo, contratos de mídia/sponsors, custos fixos e falência. Receitas atuais são parametrização regional inicial; não representam simulação econômica validada de décadas.
8. Milhares de lutas, anos de carreira, regens/aposentadorias, modos executivo/from-nothing completos, scouting e Hall da Fama.

Não marcar M1 completo enquanto arte/UX em aparelho e escala de simulação estiverem pendentes. Não mudar os resultados de combate para acomodar a animação. Sempre regenerar `studio.cobundle` após editar os arquivos compartilhados do Fight Studio.
