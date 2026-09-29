# Build Android 0.5.2 (18)

Checkpoint antes da mudança de overall para estrelas. Pacote `com.maisumarodada.futebol`, ARM64, Android API 24+.

Validação de 29/09/2026:
- 7 testes integrados aprovados, 0 falhas, 281,7 s: partida ao vivo/instantânea, temporada completa, virada de ano, memória, negociações, continentais e seleções.
- Expansão de carreira aprovada: 60 sorteios UEFA, copas de seleções, Nations League, cidadanias, migração e persistência.
- Revisão visual nativa em quatro orientações/tamanhos: 0 falhas. Capturas em `docs/images/career-mobile-0.5.2`.
- Lote nativo: 12 jogos concluídos em 7.693 ms, maior quadro de 58 ms, save confirmado. Medição com suíte de temporada simultânea; não é comparação de desempenho nem previsão para Android. No encerramento abrupto do harness, Godot reportou 2 CanvasItems/6 instâncias ainda vivas; nenhuma falha durante o lote.
- Aparelho Android físico não disponível. Assinatura e conteúdo do APK conferidos após exportação; arquivo sem override de QA nem ferramentas de teste.

Calendários, qualificatórias e naturalização têm as adaptações documentadas em `CAREER-MOBILE-0.5.2.md`.

## Artefato verificado

- Arquivo: `MaisUmaRodada-0.5.2-mobile-2026-09-29.apk` (35.559.400 bytes).
- Fonte: `28de702abadc1125de3ec1de4c278cef8397c398`, exportada de snapshot limpo, recompilado (357 scripts) e com a suíte de expansão novamente aprovada.
- SHA-256: `5a0f55ad06af0ab3fcab5e6eabe74a21a24e180506053ec56d158dc2d8dbcc04`.
- Certificado SHA-256: `1e08a903aef9c3a721510b64ec764d01d3d094eb954161b62544ea8f187b5953` (mesmo do APK anterior).
- Android 24+, target 36, `arm64-v8a`, versão 0.5.2 (18), pacote `com.maisumarodada.futebol`.
- Draft de revisão: https://github.com/fragamurilo-netizen/games-and-games/pull/60
