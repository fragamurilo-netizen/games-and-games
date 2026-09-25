# Publicar na Google Play

## Compras

| ID na Play Console | Tipo | Preço | O que faz |
|---|---|---|---|
| `carreira_completa` | Produto único, não consumível | R$ 9,99 · US$ 2,99 | Libera da 2ª temporada em diante e os mods |
| `cafe` | Produto único, consumível | R$ 2,99 · US$ 0,99 | Gorjeta; não muda nada no jogo |

O código fica em `mais-uma-rodada/scripts/autoload/store.gd` (autoload `Store`):

- A primeira temporada de qualquer carreira é grátis. Da 2ª em diante (`GameWorld.season_number >= 2`), o hub
  mostra "Mais uma temporada?", e pré-jogo, partida, simulação e pré-temporada levam à tela de compra
  (`paywall_screen.gd`).
- A compra fica salva no aparelho (`user://store.cfg`, assinada com o id do aparelho) para funcionar offline e é
  conferida com a Play a cada abertura: restaura ao reinstalar e volta a travar se a compra for reembolsada.
- Compras são confirmadas (acknowledge) na hora; o café é consumido para poder ser comprado de novo.
- Só a versão de loja cobra: no editor, no PC e em builds de debug tudo vem liberado
  (`Store.enforce_override` força um lado nos testes).

## Gerar o AAB

1. Plugin de compras: `addons/GodotGooglePlayBilling` (versão 3.3.0, compilada do repositório oficial
   `godot-sdk-integrations/godot-google-play-billing`). Já está ligado em `project.godot`.
2. Modelo de build Android: extraia `android_source.zip` dos templates de exportação do Godot 4.7.2 em
   `mais-uma-rodada/android/build/` e grave `4.7.2.stable` em `mais-uma-rodada/android/.build_version`
   (ou use Projeto → Instalar modelo de build Android no editor). A pasta `android/` fica fora do git.
3. Exporte com a chave de upload (nunca no repositório):

```sh
GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/caminho/mais-uma-rodada-upload.jks \
GODOT_ANDROID_KEYSTORE_RELEASE_USER=upload \
GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD='senha' \
godot --headless --export-release "Android" build/MaisUmaRodada-0.3.2.aab
```

O preset "Android" gera AAB só com ARM64 (menos de 30 MB; celulares só de 32 bits ficam de fora) e alvo no SDK 36. O preset "Android arm64" gera um APK para
instalar direto no celular; exporte-o com `--export-debug` para jogar sem trava.

Sem Android SDK (ou sem acesso ao dl.google.com), `mais-uma-rodada/tools/build_debug_apk.sh` gera um APK de teste
arm64 com o modelo pronto do Godot, sem o plugin de compras, e o assina com a chave de debug pelo
[uber-apk-signer](https://github.com/patrickfav/uber-apk-signer). Serve para testar no celular, não para a loja.

A cada versão nova, aumente `version/code` nos dois presets de `export_presets.cfg` e `config/version` em
`project.godot`.

## Play Console, na ordem

1. Criar o app: nome "Mais Uma Rodada: Técnico", jogo, gratuito, idioma padrão português (Brasil).
2. Ativar a Assinatura de apps do Google Play e enviar o AAB num teste fechado.
3. Criar os dois produtos acima em Monetizar → Produtos → Produtos no app, com os preços.
4. Ficha da loja: textos de `store/play-store-pt-BR.txt` e `store/play-store-en-US.txt`, ícone
   `store/icon-512.png`, banner `store/feature-graphic-1024x500.png` e de 2 a 8 capturas de tela.
5. Conteúdo do app: política de privacidade (`store/politica-de-privacidade.html` publicada num link
   público), Segurança dos dados (nenhum dado coletado), classificação IARC, público-alvo 13+, sem anúncios.
6. Contas pessoais novas: teste fechado com pelo menos 12 testadores por 14 dias seguidos antes de pedir a
   produção. Adicione os testadores também em Configurações → Teste de licença para testar as compras sem
   ser cobrado.
