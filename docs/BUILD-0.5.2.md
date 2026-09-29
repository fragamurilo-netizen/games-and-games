# Build Android 0.5.2 (18)

Checkpoint antes da mudança de overall para estrelas. Pacote `com.maisumarodada.futebol`, ARM64, Android API 24+.

Validação de 29/09/2026:
- 7 testes integrados aprovados, 0 falhas, 281,7 s: partida ao vivo/instantânea, temporada completa, virada de ano, memória, negociações, continentais e seleções.
- Expansão de carreira aprovada: 60 sorteios UEFA, copas de seleções, Nations League, cidadanias, migração e persistência.
- Revisão visual nativa em quatro orientações/tamanhos: 0 falhas. Capturas em `docs/images/career-mobile-0.5.2`.
- Lote nativo: 12 jogos concluídos em 7.693 ms, maior quadro de 58 ms, save confirmado. Medição com suíte de temporada simultânea; não é comparação de desempenho nem previsão para Android. No encerramento abrupto do harness, Godot reportou 2 CanvasItems/6 instâncias ainda vivas; nenhuma falha durante o lote.
- Aparelho Android físico não disponível. Assinatura e conteúdo do APK serão conferidos após exportação.

Calendários, qualificatórias e naturalização têm as adaptações documentadas em `CAREER-MOBILE-0.5.2.md`.
