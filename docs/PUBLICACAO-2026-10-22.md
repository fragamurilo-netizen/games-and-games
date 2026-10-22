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

Nenhum convite foi enviado a terceiros nesta preparação.

## Estado final do envio

Em 22/10/2026, o Console confirmou **Alterações em análise** após o envio das 15 mudanças
associadas ao primeiro lançamento Alpha. As verificações rápidas automáticas ainda estavam
em execução (prazo mostrado: até 15 minutos), antes da revisão do Google. Isso não confirma
aprovação nem disponibilidade pública do aplicativo.

- Faixa: teste fechado Alpha, versão `1.0.0 (22) - Alpha sem trava`.
- Apenas o bundle 22 está na versão; o bundle 21 foi retirado do rascunho e continua na biblioteca.
- País selecionado: Brasil.
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

Não foram recrutados nem simulados os 12 participantes. Recrutamento, uso real do jogo, feedback
e os 14 dias contínuos ainda são necessários. Nenhuma automação de acompanhamento foi criada.
