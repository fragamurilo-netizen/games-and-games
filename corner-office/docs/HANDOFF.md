# Continuidade — carreira regional, Android e transmissão original

Branch compartilhada: `claude/dreamy-carson-628oai` em `fragamurilo-netizen/games-and-games`.

## Instrução mais recente do usuário

Usar **a simulação que já criamos no laboratório**. A alternativa nativa simplificada foi rejeitada e removida. Não reintroduzir `FightCanvas` ou bonecos de qualidade inferior. O jogo é para Android. Identidade de menus inspirada em UFC Undisputed 3; Chakra Petch é a alternativa tipográfica autorizada. Continuar a bíblia e publicar progresso para colegas.

## Entregue neste marco

- Carreira regional com 141 atletas fictícios (128 gerados + 13 canônicos), 30 no elenco inicial, free agency e divisões masculinas/femininas.
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

O servidor guarda `.local/career.json` (ignorado). `--data-dir` permite outro slot. Não apagar saves durante QA. O save desktop Godot fica em `user://`; é separado do save web. O botão Assistir no desktop abre `user://fight-studio.html`, autocontido. No Android abre dentro do app pelo módulo `CornerOfficeStudio`.

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
git diff --exit-code -- game/content game/presentation/fight/studio.html.gz
```

Última rodada de serviços: 20 testes sem falhas; amostra regional de 16 noites / 96 lutas, com lucros e prejuízos; amostra de combate de 160 lutas. A API foi testada em diretório temporário: seis lutas, seis replays imutáveis, reload, validação de origem e preservação do save em pedidos rejeitados. Isso ainda não é o soak de milhares de lutas da bíblia.

Capturas Godot portrait 720×1280 e landscape 1280×720: `godot --path game -s res://tools/capture_mobile.gd -- /destino capture`. O capturador cria mundo efêmero; não toca no autosave. Não usar capturas antigas de `native-fight.png` como produto: mostram a alternativa descartada. Transmissão original foi verificada no browser em 390×844 e em desktop; validar também no WebView de aparelho Android.

## Próximas tarefas, por prioridade

1. Confirmar build do workflow Android, instalar APK e testar rotação, botão voltar, suspensão/retorno, save e desempenho da WebView. Sem SDK local nesta máquina; não afirmar teste em aparelho sem fazê-lo.
2. Sessão de jogo completa em aparelho: contratar, montar card misto, anunciar, assistir e organizar a segunda noite. Medir legibilidade e fluidez antes de expandir sistemas.
3. Melhorar perfis nativos com os retratos do gerador existente. Hoje as listas Godot são textuais; o protótipo web já usa os retratos.
4. Rival AI: organizações já possuem elencos, mas não organizam eventos autonomamente. Depois: ofertas concorrentes/BATNA e memória de agentes.
5. Separar modelos completos de ranking oficial e WCI: hoje listas/elegibilidade são distintas, mas compartilham uma fórmula inicial de resultados/oposição. Falta o composto completo e tratamento de inatividade da bíblia.
6. Popularidade dinâmica, campeões/títulos, peso/camp, lesões detalhadas e substituições. Suspensão atual é regra inicial de pós-luta, não um sistema médico completo.
7. Economia de longo prazo, contratos de mídia/sponsors, custos fixos e falência. Receitas atuais são parametrização regional inicial; não representam simulação econômica validada de décadas.
8. Milhares de lutas, anos de carreira, regens/aposentadorias, modos executivo/from-nothing completos, scouting e Hall da Fama.

Não marcar M1 completo enquanto arte/UX em aparelho e escala de simulação estiverem pendentes. Não mudar os resultados de combate para acomodar a animação. Sempre regenerar `studio.html.gz` após editar os arquivos compartilhados do Fight Studio.
