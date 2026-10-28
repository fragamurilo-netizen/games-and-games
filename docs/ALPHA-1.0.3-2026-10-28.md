# Alpha 1.0.3 (25) — estabilidade e memória

## Falhas reproduzidas e corrigidas

- O `DecalCache` entregava `ViewportTexture` e destruía o viewport ao expulsar a entrada, enquanto o cache de comandos dos retratos ainda guardava a textura. O teste anterior às alterações mostrou uma textura passando de 442 × 72 para 0 × 0, com erro `Viewport Texture must be set to use it`. Agora a estampa é copiada uma vez para `ImageTexture`; o render target é liberado depois da captura e a textura continua válida enquanto algum retrato a utiliza. A captura só é agendada após a entrada do viewport na árvore. Na retomada do app, as estampas do cache são restauradas a partir da imagem guardada.
- A tela inicial criava um card e seu contêiner interno mesmo quando mostrava o próximo jogo com outro componente. Os dois nós não eram anexados nem liberados. A criação agora acontece somente no ramo que usa o card. Dezoito atualizações consecutivas resultaram em crescimento zero de nós órfãos.
- O cache de fotos e imagens de mods não tinha limite nem liberava dados quando o Android avisava sobre pouca memória. Quarenta imagens de 1024 × 1024 mantinham 167.772.160 bytes de texturas no cache. O cache agora usa recência, teto estimado de 24 MiB de pixels RGBA8 e 192 entradas, incluindo referências a arquivos ausentes. No mesmo cenário, retém apenas seis imagens (24 MiB); as telas abertas preservam as próprias referências. Caminhos externos completos/relativos também recebem redução para até 1280 px antes da criação da textura, preservando proporção e arquivos originais. Os limites existentes dos atalhos de pacotes continuam valendo.

São correções comprovadas de ciclo de vida e retenção de memória. Não há evidência suficiente para associá-las individualmente aos SIGSEGV de Android vitals. Na consulta de 28/10, os quatro grupos continuavam somando 16 eventos das versões 22/23; nenhum foi marcado como resolvido.

## Validação

- Compilação: 464 scripts, zero erros.
- `render_lifecycle.gd`: zero falhas com renderer gráfico real. Três ciclos de expulsão do cache, oito estampas retidas por comandos reais de retrato, pixels e dimensões preservados, solicitações feitas durante `_draw`, consumidor destruído antes da captura e retomada do cache.
- `asset_cache_regression.gd`: zero falhas. Orçamento de bytes e entradas, recência, cache de arquivos ausentes, redução proporcional e validade de texturas em uso após a liberação do cache.
- `mobile_regression.gd`: zero falhas, incluindo rotação, retomada e liberação de imagens em aviso de pouca memória.
- `android_reliability.gd`: duas execuções gráficas aprovadas. Atualização repetida da tela inicial, Mercado em PT/EN/ES, paginação/filtros, save/load e partida completa. Capturas em 390×844, 844×390, 800×1280 e 1280×800. Nenhum crash nessas execuções. O encerramento do harness ainda informa três objetos RefCounted; os 12 CanvasItems e contêineres órfãos observados antes foram eliminados.
- `audio_regression.gd`: zero falhas.
- Suíte principal completa: em execução; resultado final será registrado antes da distribuição.

Testes locais em Godot 4.7.2 no Windows. Não havia Android físico conectado; a eliminação dos crashes nos celulares ainda precisa ser confirmada pelos testadores e pelos relatórios novos da Play.

## Pacote

`mais-uma-rodada/build/MaisUmaRodada-1.0.3-alpha.aab`: 52.024.229 bytes.

SHA-256: `4a7d8022b97646408980fbe5ec176e4ccaeab5061239425047b6c1b40101ace8`.

Validado com bundletool e jarsigner: pacote `mais.uma.rodada`, versão 1.0.3/código 25, SDK mínimo 24/alvo 36, ARM64 e alinhamento ELF de 16 KB. Mesmo certificado de upload das versões anteriores. Scripts corrigidos, 218 bandeiras e 14 bases de novas ligas presentes; testes/ferramentas temporárias excluídos. Mantido `sem_trava` apenas no Alpha, com saves existentes preservados.

O exportador concluiu o AAB e encerrou seu processo principal, mas o wrapper de console ficou aberto; ele foi encerrado somente depois das validações independentes do arquivo. O jarsigner informa os mesmos avisos do Alpha anterior sobre certificado autoassinado, ausência de timestamp e ordem do manifesto no ZIP.

Notas PT/EN: `store/release-notes/1.0.3.txt`, também acrescentadas aos textos locais da loja. As alterações preexistentes em `docs/ALPHA-1.0.1-2026-10-26.md`, a remoção local do bloco 1.0.2 em `store/play-store-pt-BR.txt` e as remoções das oito capturas da loja foram preservadas fora do commit. Por isso `release_check.py` mantém um erro referente às capturas ausentes no checkout; a ficha existente na Play não foi alterada.

## Distribuição

A versão 24 estava em análise na Play ao iniciar esta atualização. O envio do código 25 ainda está em preparação.
