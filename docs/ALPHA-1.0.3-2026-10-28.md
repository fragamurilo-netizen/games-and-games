# Alpha 1.0.3 (26) — divisões, traduções e estabilidade

## Divisões e traduções

Inglaterra com quatro divisões e 92 clubes. Mais seis segundas divisões (Holanda, Turquia, Escócia, Áustria, Suíça e Japão), totalizando oito novas competições e 148 clubes adicionais. Em saves existentes, a expansão ocorre na virada da temporada e completa também a Championship de 20 para 24 clubes. Ver [fontes, composição e adaptações](DIVISOES-2026-10-28.md).

116 entradas em inglês e 180 em espanhol acrescentadas. Nomes próprios de clubes ficam protegidos dos moldes de tradução; o placar traduz o título antes de desenhá-lo. Regulamentos das novas divisões traduzidos.

Rodadas extras de meio de semana têm marca explícita para não repetir salários/evolução semanal nem deslocar as pausas FIFA. Playoffs usam datas próprias, com byes turcos, vantagem do melhor colocado nos empates japoneses e bloqueio de acesso para reservas elegíveis apenas à disputa da liga.

## Falhas reproduzidas e corrigidas

- O `DecalCache` entregava `ViewportTexture` e destruía o viewport ao expulsar a entrada, enquanto o cache de comandos dos retratos ainda guardava a textura. O teste anterior às alterações mostrou uma textura passando de 442 × 72 para 0 × 0, com erro `Viewport Texture must be set to use it`. Agora a estampa é copiada uma vez para `ImageTexture`; o render target é liberado depois da captura e a textura continua válida enquanto algum retrato a utiliza. A captura só é agendada após a entrada do viewport na árvore. Na retomada do app, as estampas do cache são restauradas a partir da imagem guardada.
- A tela inicial criava um card e seu contêiner interno mesmo quando mostrava o próximo jogo com outro componente. Os dois nós não eram anexados nem liberados. A criação agora acontece somente no ramo que usa o card. Dezoito atualizações consecutivas resultaram em crescimento zero de nós órfãos.
- O cache de fotos e imagens de mods não tinha limite nem liberava dados quando o Android avisava sobre pouca memória. Quarenta imagens de 1024 × 1024 mantinham 167.772.160 bytes de texturas no cache. O cache agora usa recência, teto estimado de 24 MiB de pixels RGBA8 e 192 entradas, incluindo referências a arquivos ausentes. No mesmo cenário, retém apenas seis imagens (24 MiB); as telas abertas preservam as próprias referências. Caminhos externos completos/relativos também recebem redução para até 1280 px antes da criação da textura, preservando proporção e arquivos originais. Os limites existentes dos atalhos de pacotes continuam valendo.

São correções comprovadas de ciclo de vida e retenção de memória. Não há evidência suficiente para associá-las individualmente aos SIGSEGV de Android vitals. Na consulta de 28/10, os quatro grupos continuavam somando 16 eventos das versões 22/23; nenhum foi marcado como resolvido.

## Validação

- Compilação: 466 scripts, zero erros.
- `divisions_regression.gd`: zero falhas nos dois calendários, 552 jogos por divisão inglesa com 24 clubes, playoffs, repescagens, reservas, migração parcial/idempotência, IDs e resultados antigos preservados.
- `tester_feedback.gd`: zero falhas, incluindo três jogos exatos, simulação de 65 jogos do clube até o fim da temporada, seleções e save/load da carreira ampliada.
- `android_reliability.gd` com `--league=ENG4`: zero falhas. Abre as nove tabelas alteradas em EN/ES, alterna Mercado, carrega save e conclui partida. Dezoito reconstruções da tela inicial e reconstruções de cada tabela sem crescimento de nós órfãos. A correção do cartão vazio de destaques eliminou 54 CanvasItems retidos e os avisos de texturas no encerramento desse cenário. As repetições finais deixaram dois ou três RefCounted com contagem zero no encerramento do harness; nenhum crash foi observado.
- `render_lifecycle.gd`: zero falhas com renderer gráfico real. Três ciclos de expulsão do cache, oito estampas retidas por comandos reais de retrato, pixels e dimensões preservados, solicitações feitas durante `_draw`, consumidor destruído antes da captura e retomada do cache.
- `asset_cache_regression.gd`: zero falhas. Orçamento de bytes e entradas, recência, cache de arquivos ausentes, redução proporcional e validade de texturas em uso após a liberação do cache.
- `mobile_regression.gd`: zero falhas, incluindo rotação, retomada e liberação de imagens em aviso de pouca memória.
- `android_reliability.gd`: duas execuções gráficas aprovadas. Atualização repetida da tela inicial, Mercado em PT/EN/ES, paginação/filtros, save/load e partida completa. Capturas em 390×844, 844×390, 800×1280 e 1280×800. Nenhum crash nessas execuções. O encerramento do harness ainda informa três objetos RefCounted; os 12 CanvasItems e contêineres órfãos observados antes foram eliminados.
- `audio_regression.gd`: zero falhas.
- Suíte anterior às divisões: 53 testes aprovados, zero falhas (2.646,1 s).
- Suíte longa com as novas divisões: 52 casos aprovados e duas asserções em um caso com expectativas antigas (3.116,7 s). O caso esperava 40 clubes na FA Cup e contava as duas repescagens como rodadas da liga escocesa. As expectativas foram corrigidas para 92 clubes e 38 rodadas regulares mais repescagem. O cenário foi repetido e aprovado (223,2 s).
- Depois da marcação das rodadas extras sem ciclo semanal, foram repetidos juntos temporada completa, virada de ano e ranking/finanças: três casos aprovados, zero falhas (245,1 s). Calendário de ano civil e seleções também passaram com o ciclo atualizado. Duas tentativas de executar ranking sem todos os seus pré-requisitos (temporada completa + virada/arquivamento) foram descartadas como configuração inválida do filtro, e a cadeia completa foi validada no reteste citado. Assim, todos os 53 casos passaram entre a execução longa e os retestes; não houve uma segunda execução monolítica de toda a suíte após os últimos ajustes.
- A simulação paralela produziu os mesmos resultados da sequencial no cenário longo (139,8 s).

Testes locais em Godot 4.7.2 no Windows. Não havia Android físico conectado; a eliminação dos crashes nos celulares ainda precisa ser confirmada pelos testadores e pelos relatórios novos da Play.

## Pacote

O código 25 foi carregado como rascunho na Play, sem envio para análise. O pacote final desta expansão usa código 26, preparado para substituir o rascunho.

`mais-uma-rodada/build/MaisUmaRodada-1.0.3-alpha.aab`: 52.046.326 bytes.

SHA-256: `fab433a53b4efa8d81f2d34c8602ddf1efb4837b490c8fe25bac30f6b172d07f`.

Validado com bundletool e jarsigner: pacote `mais.uma.rodada`, versão 1.0.3/código 26, SDK mínimo 24/alvo 36, ARM64 e alinhamento ELF de 16 KB. Mesmo certificado de upload das versões anteriores. Conferidos no arquivo os nove conjuntos de clubes/divisões alterados, traduções, 218 bandeiras, licenças e os scripts compilados; testes e ferramentas ficam excluídos. Mantido `sem_trava` apenas no Alpha.

A geração final chamou diretamente o executável headless, com captura dos dois fluxos de saída e descarte das credenciais em memória ao encerrar. Concluiu com código de saída zero; não houve wrapper de console pendente. O jarsigner informa os mesmos avisos do Alpha anterior sobre certificado autoassinado, ausência de timestamp e ordem do manifesto no ZIP.

Notas PT/EN: `store/release-notes/1.0.3.txt`, também acrescentadas aos textos locais da loja. As alterações preexistentes em `docs/ALPHA-1.0.1-2026-10-26.md`, a remoção local do bloco 1.0.2 em `store/play-store-pt-BR.txt` e as remoções das oito capturas da loja foram preservadas fora do commit. Por isso `release_check.py` mantém um erro referente às capturas ausentes no checkout; a ficha existente na Play não foi alterada.

## Distribuição

A versão 24 foi aprovada e ficou disponível para os testadores em 28/10, durante este trabalho. O código 25 ficou como rascunho. O código 26 está assinado e validado localmente. O envio está impedido porque o navegador do Work foi desativado durante o trabalho; o usuário recebeu a solicitação para reativá-lo. Não houve envio do código 26 à Play nem submissão do rascunho 25.


## Retomada do envio

1. Abrir o rascunho do Alpha na [Play Console](https://play.google.com/console/u/0/developers/5519479914358930620/app/4976212753390751022/tracks/4697933041735381417/releases/4/review).
2. Voltar à edição, remover o código 25 da composição do rascunho e enviar `mais-uma-rodada/build/MaisUmaRodada-1.0.3-26-alpha.aab` (52.046.326 bytes). Não distribuir o código 25, que não contém a expansão das divisões.
3. Usar o nome `1.0.3 (26) - Alpha: divisões, traduções e estabilidade` e o conteúdo de `store/release-notes/1.0.3.txt` nas notas de lançamento. Os dois idiomas têm menos de 500 caracteres.
4. Em gerenciar artefatos, anexar ao código 26 `publicacao-local/native-debug-symbols-4.7.2-arm64.zip`. É o mesmo conjunto oficial de símbolos da versão do motor, já usado nos códigos 24/25.
5. Conferir a versão 1.0.3/código 26, avançar, salvar e enviar as alterações para análise pela visão geral de publicação. Confirmar o estado efetivo após o envio. O teste deve permanecer no Alpha com os países e o grupo de testadores já configurados.

Esses passos descrevem a pendência; não confirmam que o envio foi realizado.
