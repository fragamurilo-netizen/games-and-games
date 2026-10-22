# Preparação da Google Play em 22/10/2026

Base: `claude/hopeful-newton-8avbo4`, commit `278ff7b3a2a3c9b9c76857dfc3ff947a060b4abf`.
O branch `main` contém somente o commit inicial; esta preparação não mescla branches no main.

## Aplicativo e build

- Conta: Game Overdrive Studios.
- Aplicativo existente: Mais Uma Rodada: Manager, ID `4976212753390751022`.
- Pacote do Console: `mais.uma.rodada`. Os presets foram alinhados a esse cadastro.
- Godot 4.7.2, versão 1.0.0, versionCode 22, ARM64, Android mínimo 24, target SDK 36.
- O preset **Android Alpha** acrescenta a feature existente `sem_trava`: todo o conteúdo
  fica liberado sem pagamento, conforme autorizado pelo dono para o teste fechado.
- O preset **Android** preserva as compras para a futura versão de produção.
- Exportar explicitamente o preset correto. Não promover este Alpha liberado para produção
  se a intenção continuar sendo cobrar pelas temporadas extras e pelo editor.

Arquivo preparado: `mais-uma-rodada/build/MaisUmaRodada-1.0.0-alpha.aab`.
SHA-256: `644cdc1d770402ce10a7fd0230f28cc33384c37160c93251b94e92709845f03b`.

## Verificação

- `tools/release_check.py`: OK.
- Compilação dos scripts: zero erros.
- Boot da base: `SMOKE_BOOT_OK`.
- Link de privacidade em Opções > Sobre; captura real em 390×844, 844×390,
  800×1280 e 1280×800. Traduções en/es incluídas.
- Bundletool 1.18.3: validate com saída 0; assinatura JAR verificada.
- Manifesto final: pacote, versionCode 22, SDK 36 e Play Billing 9.1.0 conferidos;
  sem flag debuggable e sem permissão AD_ID.
- Bibliotecas ARM64 com segmentos LOAD alinhados a 16 KB.
- Configuração de bundle com PAGE_ALIGNMENT_16K.
- A feature `sem_trava` está no project.binary do bundle Alpha.
- Sem teste em Android físico nesta preparação. Não há comprovação de uma campanha
  completa no Android nem de compras reais pela Play.

## Ambiente e assinatura

A chave de upload foi criada fora do repositório em
`%USERPROFILE%/.android/mais-uma-rodada-release/upload.jks`, alias `upload`.
A senha está protegida com DPAPI do usuário Windows em `password.dpapi`, na mesma pasta.
Nenhuma chave ou senha foi incluída no Git. A senha DPAPI depende deste usuário Windows:
fazer um backup recuperável da chave e da senha antes de migrar ou reinstalar a máquina.

Ferramentas Android locais em `%LOCALAPPDATA%/MaisUmaRodadaBuild`.
A licença do Android SDK foi aceita com autorização explícita do dono.
Ao extrair manualmente `android_source.zip`, criar `android/.gdignore` **antes** de
abrir/importar o projeto. Isso evita que o Godot importe os arquivos gerados do Gradle.
Os filtros de exportação também excluem `android/*` e `.claude/*`.

## Console e próximos passos

A política de privacidade foi publicada via GitHub Pages, branch
`claude/hopeful-newton-8avbo4`, pasta `/docs`, e o endereço foi conferido com HTTP 200:
https://fragamurilo-netizen.github.io/games-and-games/privacidade/

As declarações devem corresponder ao build efetivamente enviado. Para o Alpha com
`sem_trava`, o acesso é integral e não exige login ou pagamento. Antes de uma versão de
produção com paywall, atualizar os detalhes de acesso e fornecer um meio válido de revisão.

O lançamento público depende de teste fechado com **12 testadores reais inscritos
continuamente por pelo menos 14 dias** e posterior aprovação do Google. Na consulta inicial,
o Console mostrava zero testadores e nenhuma versão publicada. Não inventar inscrições,
feedback ou resultados de teste. Convidar 15–20 pessoas dá margem para desistências.

Convite pronto para compartilhar quando o teste e o link de adesão estiverem disponíveis:

> Estou procurando pessoas com Android para testar o Mais Uma Rodada, meu jogo de gestão
> de futebol. O Alpha libera todo o conteúdo de graça. Preciso que você entre pelo link
> oficial da Google Play, mantenha a participação por 14 dias e teste a criação de carreira,
> partidas e salvamento. Se encontrar travamento ou erro, me mande o modelo do celular,
> a versão do Android e os passos para reproduzir. Não precisa deixar avaliação positiva;
> quero feedback sincero para melhorar o jogo.

Após pedido explícito do proprietário, foram publicados três convites no Reddit em
22/10/2026 pela conta `u/muriloves`. Os textos informam que a versão está em análise,
o teste é limitado ao Brasil, o Alpha é gratuito e os interessados devem comentar
ou enviar mensagem privada. Não solicitaram e-mails em comentários públicos.

- JogosIndiesBR, flair Projetos Pessoais:
  https://www.reddit.com/r/JogosIndiesBR/comments/1xcqglg/procuro_testadores_no_brasil_para_o_mais_uma/
- AndroidClosedTesting:
  https://www.reddit.com/r/AndroidClosedTesting/comments/1xcqhnr/brazilbased_testers_wanted_for_mais_uma_rodada_a/
- alphaandbetausers:
  https://www.reddit.com/r/alphaandbetausers/comments/1xcqjbq/looking_for_brazilbased_android_players_to_test/

Os três posts foram conferidos nos endereços finais, sem aviso de remoção nessa
consulta. Capturas estão em `publicacao-local/reddit-*.png` (arquivos locais ignorados
pelo Git). Isso comprova divulgação, não adesões reais ao teste. Não houve promessa
de avaliação positiva, pagamento, acesso vitalício ou troca de testes.

## Estado final do envio

Em 22/10/2026, o Console confirmou **Alterações em análise** após o envio das 15 mudanças
associadas ao primeiro lançamento Alpha. As verificações rápidas automáticas ainda estavam
em execução (prazo mostrado: até 15 minutos), antes da revisão do Google. Isso não confirma
aprovação nem disponibilidade pública do aplicativo.

- Faixa: teste fechado Alpha, versão `1.0.0 (22) - Alpha sem trava`.
- Apenas o bundle 22 está na versão; o bundle 21 foi retirado do rascunho e continua na biblioteca.
- País inicial: Brasil. Com autorização posterior do proprietário, o Alpha foi ampliado
  para 20 países: Brasil, Estados Unidos, Canadá, Reino Unido, Irlanda, Índia, Austrália,
  Nova Zelândia, Portugal, Espanha, Argentina, México, Alemanha, França, Itália,
  Países Baixos, Polônia, Filipinas, Indonésia e África do Sul. A mudança foi enviada
  para revisão, com confirmação de reinício da análise, e aparece em Alterações em análise.
- Lista selecionada: `Alpha Mais Uma Rodada`, inicialmente somente com a conta do proprietário.
  Uma conta na lista não equivale a participação aceita nem inicia sozinha a contagem de 14 dias.
- Link de adesão exibido pelo Console: https://play.google.com/apps/testing/mais.uma.rodada
  (ainda desabilitado durante esta preparação; depende da publicação do teste).
- Canal de feedback: https://github.com/fragamurilo-netizen/games-and-games/issues
- Classificação IARC preenchida com autorização explícita para os termos e contato.
  Foram declaradas referências incidentais a apostas e referências a álcool nas marcas e
  narrativas; classificação calculada para o Brasil: **10 anos**. Público-alvo configurado: 13+.
  Na versão de produção com compras, atualizar também a declaração de compras da IARC.
- Todos os formulários de conteúdo necessários foram preenchidos, incluindo ID de publicidade.
- Validação da versão no Console: sem erros bloqueantes; avisos sobre ausência de arquivo de
  desofuscação e de símbolos de depuração nativos. Não houve upload desses arquivos.
- Mudanças de código: https://github.com/fragamurilo-netizen/games-and-games/pull/75 (rascunho).

Ainda não há confirmação de 12 participantes inscritos. Após os convites no Reddit,
é necessário organizar os interessados, habilitar acesso quando o teste estiver
publicado e obter uso real, feedback e os 14 dias contínuos. Nenhuma automação de
acompanhamento foi criada.

## Divulgação ampliada e adesão

Após novo pedido do proprietário, foram adicionadas capturas existentes do jogo aos
posts de JogosIndiesBR (partida, tática e negociação) e AndroidClosedTesting (partida e
tática). O post de alphaandbetausers, cujo editor não oferece upload de imagem, recebeu
link para a galeria. Os textos foram atualizados para explicar os 20 países, ainda
dependentes de aprovação; títulos antigos com Brasil não podem ser editados no Reddit.

Novas publicações confirmadas:

- X/Twitter, conta `@murilopsx`, com três imagens:
  https://x.com/murilopsx/status/2113338246797377855
- Comunidade oficial OneMoreMatch, com três imagens:
  https://www.reddit.com/r/OneMoreMatch/comments/1xcr527/android_alpha_update_looking_for_12_volunteer/
- Tópico de descoberta de testadores do GooglePlayDeveloper:
  https://www.reddit.com/r/GooglePlayDeveloper/comments/1x41xot/comment/19rhw4lpd3yo2/

Abordagens em ofertas públicas, sem compromisso de pagamento ou troca de testes:

- `u/indieMerlovian`, que oferece testes curtos gratuitos de jogos Android:
  https://www.reddit.com/r/playtesters/comments/1w2h6ec/comment/19rhva6yg4qn5/
- `u/Overall-Advice-9943`, que procura apps e jogos para conhecer/avaliar:
  https://www.reddit.com/r/appdev/comments/1xb4gv1/comment/19rhvcdxvaq4g/
- Resposta a `u/Undeon`, que comentou no convite AndroidClosedTesting com orientações
  sobre países, Google Groups e seu app Owlybooks:
  https://www.reddit.com/r/AndroidClosedTesting/comments/1xcqhnr/comment/19rhw4lvtckg1/

Uma resposta com dicas não é inscrição confirmada. Não houve adesão ao teste de
Owlybooks nem promessa de teste recíproco. Não há comprovação dos 12 participantes.

Tentativa de Google Group próprio: nome `Mais Uma Rodada - Android Alpha Testers`,
prefixo pretendido `mais-uma-rodada-testers`, adesão voluntária aberta, descoberta pública,
conversas para participantes e lista de membros/publicação restritas ao proprietário.
A criação não foi concluída: o Google mostrou CAPTCHA obrigatório em branco, com
Criar grupo desativado, em duas tentativas. O proprietário foi avisado e autorizou
nova tentativa. Não divulgar esse endereço como grupo existente nem vinculá-lo à Play
antes de confirmar a criação. A lista de e-mails original continua sendo a seleção
válida do Alpha até concluir essa configuração.

Na conferência final, a Play já mostrava as mudanças sendo revisadas, incluindo os
20 países. O controle do navegador passou a exigir atualização da extensão ChatGPT
no Chrome ao tentar salvar capturas adicionais; não foi possível concluir o vínculo
do grupo. O comprovante do post do X foi salvo antes desse bloqueio em
`publicacao-local/x-convite-publicado.png`.
