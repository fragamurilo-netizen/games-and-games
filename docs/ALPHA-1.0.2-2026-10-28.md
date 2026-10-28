# Alpha 1.0.2 (24) — correções, ligas e bandeiras

Data: 28/10/2026. Branch: `publicacao-android-20261022`. Pacote: `mais.uma.rodada`.

## Comportamento corrigido

- As metas da diretoria pertencem ao clube e ao ano. Mudar de emprego no mesmo ano invalida as metas e o histórico de confiança do emprego anterior. Saves com o cache antigo são reparados ao consultar as metas.
- A preparação da escalação da simulação roda no worker. Pedidos duplicados são rejeitados; uma simulação interrompida informa que foi pausada e permite continuar quando não há decisão pendente. O calendário avança até o próximo jogo ou o fim usando progresso real, sem o antigo limite fixo de 80 datas.
- Começar uma carreira durante outro trabalho não troca o mundo usado pela thread. Um pedido de save durante o trabalho é atendido pelo worker ou depois dele, sem serialização concorrente na interface.
- O carregamento assíncrono libera a carreira anterior antes de ler outra. Telas de navegação e índices estáticos de jogadores deixam de reter os elencos antigos. O fechamento e o carregamento são encadeados sem liberar a interface no intervalo.
- Seleções têm uma agenda persistida com data, mando, adversário e competição. A tela e o processamento usam os mesmos confrontos. Amistosos completam as janelas, com até dois jogos por seleção e sem dois jogos no mesmo dia. A agenda continua igual após save/load e uma janela não pode ser processada duas vezes.
- Eliminatórias novas consideram as janelas disponíveis, as folgas de grupos ímpares, as Ligas das Nações e campanhas concorrentes. A Copa do Mundo tem um ciclo de três temporadas no modelo da carreira.
- O calendário comporta a fase final da Romênia sem eliminar um turno da fase regular.

A agenda internacional é gerada pela carreira. Não é uma cópia do calendário real de confrontos futuros da FIFA. Torneios de verão continuam usando o sistema de grupos e mata-mata existente.

## Crash de áudio identificado no Android vitals

A consulta à Play Console em 28/10 mostrou quatro grupos de SIGSEGV. Um grupo também afetava a versão 23 e continha sete eventos de dois usuários. Exemplos disponíveis: Redmi 13C / Android 15 e Galaxy A57 5G / Android 17, ambos na versão 22 nos exemplos exibidos.

Os símbolos oficiais da Godot 4.7.2 foram obtidos e o Build ID foi conferido: `270121fef88100c19643517c328b5868e01d345c`.

A pilha de áudio foi decodificada localmente:

- `0x2cce234`: `AudioStreamPlaybackWAV::_mix_internal`, com leitura PCM mono de 16 bits em `decode_samples`, linha 194 de `scene/resources/audio_stream_wav.cpp`.
- `0x314e8a0`: `AudioStreamPlaybackResampled::mix`.
- `0x312ea44`: `AudioServer::_mix_step`.
- `0x312c8e4`: `AudioServer::_driver_process`.
- `0x120b3b8`: `AudioDriverOpenSL::_buffer_callback`.

Os loops sintetizados usavam a quantidade de frames como `loop_end`. O mixer dessa versão inclui o índice final na leitura. Agora o limite é o último índice válido (`frames - 1`), inclusive no cache de músicas antigas. Arquivos PCM com tamanho ímpar são rejeitados. Trocas rápidas de partida retêm os jobs de torcida em andamento e descartam a aplicação de uma torcida antiga à partida atual.

`tests/audio_regression.gd` exercita o mixer nativo com loops mono/estéreo de um frame, curtos, blocos inteiros e blocos parciais, e trocas rápidas de torcidas. A confirmação em aparelhos Android dependerá do novo teste distribuído; a execução local não prova a eliminação de todos os crashes de aparelho.

Fonte técnica: https://docs.godotengine.org/en/stable/tutorials/platform/android/resolving_crashes_on_android.html

Os dois grupos de renderização foram consultados em seguida: ambos mostravam Galaxy S23 / Android 16 na versão 22, com falha no driver Adreno durante `RasterizerCanvasGLES3::_render_batch`. O quarto grupo mostrava Galaxy S20 FE 5G / Android 13, versão 22, durante `_redraw_callback` e uma chamada GDScript a um método que retorna `Vector2`. Essas pilhas não identificam uma linha do jogo com informação suficiente para afirmar uma correção específica. Não foram marcadas como resolvidas nem ocultadas na Console.

## Expansão de ligas

14 países, 194 clubes: Índia (13), Indonésia (18), Nova Zelândia (11), Polônia (18), Suécia (16), Noruega (16), Romênia (16), Hungria (12), Irã (18), Tailândia (16), Malásia (12), Canadá (8), Costa Rica (10) e Irlanda (10).

Nomes de clubes são reais. Jogadores são fictícios; forças, finanças, capacidade de estádios não informada e demais valores derivados são parâmetros do jogo. As copas nacionais usam o modelo de mata-mata do jogo com os clubes disponíveis; não reproduzem todas as divisões e fases regionais reais. As equipes reservas de Auckland FC e Wellington Phoenix ficam fora da Chatham Cup.

- Costa Rica: adaptação com fase regular de 18 rodadas, semifinal e final; Apertura/Clausura separados e eventual grande final ainda não são reproduzidos.
- Nova Zelândia: composição da Championship 2026, turno único e final; a reforma nacional de 2027 ainda não é reproduzida.
- As competições seguem o calendário unificado da carreira. Não são réplicas de cada data do calendário civil das ligas reais.
- Carreiras novas recebem as ligas desde o início. Em carreiras antigas, clubes e elencos são acrescentados na virada de temporada, preservando IDs antigos e partidas já marcadas. O RNG da carreira não é consumido pela migração. Repetir a migração não duplica clubes.

Fontes de composição e formatos consultadas:

- Índia: https://www.indiansuperleague.com/Clubs
- Indonésia: https://www.ileague.id/table/index/BRI_SUPER_LEAGUE_2026-27
- Nova Zelândia: https://www.nzfootball.co.nz/newsarticle/170010?newsfeedId=1275538
- Polônia: https://ekstraklasa.org/tabela/2026-2027/
- Suécia: https://www.svenskfotboll.se/4af842/globalassets/svff/dokumentdokumentblock/tavling/arsplaner--seriesammansattningar/2026/faststalld-seriesammansattning-allsvenskan-och-superettan-2026.pdf
- Noruega: https://www.eliteserien.no/tabell
- Romênia: https://www.superliga.ro/
- Hungria: https://www.mlsz.hu/hir/otp-bank-liga-2026-2027-sorsolas-hetfon
- Irã: https://www.iranleague.ir/fa/MatchSchedule/1/1
- Tailândia: https://fathailand.org/news-detail/P_osx?language=th e composição em https://th.tips/thim (a tabela oficial não expôs os dados nesta consulta).
- Malásia: https://www.malaysianfootballleague.com/Content/Post/Watch/6000
- Canadá: https://www1.canpl.ca/standings/index e https://www.cplsoccer.com/news/cpl-to-use-four-team-playoff-format-in-2026
- Costa Rica: https://www.torosdelnorte.com/temporada/apertura-2026/ e https://crhoy.com/deportes/ya-hay-calendario-esta-es-la-jornada-inaugural-del-apertura-2026/ (o site da UNAFUT não respondeu).
- Irlanda: https://www.leagueofireland.ie/mens/sse-airtricity-mens-premier-division/ e https://d33kuhj6eu7i5b.cloudfront.net/6917/6587/7514/SSE_Airtricity_Mens_Premier_Division_-_2026_Fixtures_-_Final_release.pdf

## Todas as bandeiras

As 218 seleções usam SVGs completos. As bandeiras procedurais antigas ficam apenas como fallback para mods; nenhuma seleção da base depende delas. `assets/flags/index.json` registra o mapeamento FIFA/ISO e a versão da coleção flag-icons. Licença MIT e origem estão incluídas nos arquivos de exportação. Bonaire tem arte própria, distinta da bandeira genérica de ISO BQ.

Também foram completados os nomes de países em inglês. As bandeiras são consultadas nos dados globais e aparecem nas carreiras já salvas, sem exigir uma carreira nova.

## Validação e distribuição

- Suíte principal: 49 casos aprovados na execução completa (2.678,4 s). Quatro casos falharam inicialmente, com 17 mensagens de asserção, e passaram após as correções em execuções focadas: geração, temporada completa, cláusula de revenda com solidariedade e eventos de saudade. Total: 53 casos da suíte aprovados entre a execução completa e as reexecuções.
- Regressão específica dos relatos: migração idempotente das 14 ligas, metas após troca de clube, agenda persistida das seleções, simular três jogos e restante da temporada, exclusão de trabalho concorrente e save/load: zero falhas.
- Mixer de áudio nativo, loops PCM mono/estéreo e trocas rápidas de torcida: zero falhas.
- Regressão mobile de layout e ciclo de vida: zero falhas.
- Uma segunda execução gráfica com áudio habilitado repetiu Mercado, save/load e partida completa e também terminou com zero falhas. Os avisos no encerramento permaneceram.
- Fluxo gráfico com áudio habilitado: Mercado em PT/EN/ES, paginação, filtros, save/load, preparação e conclusão de partida; capturas em 390×844, 844×390, 800×1280 e 1280×800. Zero falhas. O carregamento com uma pausa entre os workers falhou inicialmente e passou após o encadeamento contínuo. Houve um crash nativo em uma execução gráfica anterior; a execução final concluiu sem crash. Persistem avisos de recursos no encerramento do harness de testes.
- `bundletool validate`, manifesto e assinatura: aprovados. Código 24, nome 1.0.2, pacote `mais.uma.rodada`, SDK mínimo 24/alvo 36, ARM64, segmentos ELF alinhados a 16 KB. Certificado de upload idêntico ao Alpha anterior. As 218 texturas de bandeiras, a licença/origem e os 14 arquivos de clubes estão no AAB. Testes, ferramentas e arquivos temporários ficaram fora.
- AAB: `mais-uma-rodada/build/MaisUmaRodada-1.0.2-alpha.aab`, 52.023.003 bytes. SHA-256: `f8e408dc08136279320ad1a2bbe7d10472b60ce445421c3563f8fd14f73d5420`.
- `release_check.py`: o único erro é a ausência das oito capturas da loja que já estavam removidas no checkout antes deste trabalho. Essas remoções não foram incluídas no commit; a ficha existente na Play foi preservada. As novidades 1.0.2 também foram registradas nos textos locais PT/EN.

Os testes foram executados na Godot 4.7.2 para Windows, com execução gráfica e headless. Não havia aparelho Android conectado. A confirmação nos aparelhos dos testadores e nos novos relatórios de Android vitals continua necessária.

O preset `Android Alpha` continua com `sem_trava`: tudo liberado no teste fechado. A faixa continua Alpha, sem publicação em produção.

Em 28/10, o AAB 24 foi aceito pela Play Console na faixa Alpha, com notas em português e inglês e o ZIP de símbolos nativos oficiais da Godot anexado. A revisão local da Console manteve a mesma cobertura de dispositivos. O único aviso foi a ausência de arquivo ReTrace para código Java ofuscado.

As verificações rápidas terminaram e o envio foi confirmado. A Console exibiu **“Alterações em análise”** para **“1.0.2 (24) - Alpha: correções, ligas e bandeiras”**, com a mensagem **“As mudanças estão sendo revisadas”**. A versão 23 continuava sendo a última publicada; o status em análise não confirma disponibilidade da versão 24 para download. A captura da confirmação foi salva localmente em `publicacao-local/alpha24-in-review.jpg`.
