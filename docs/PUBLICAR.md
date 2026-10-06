# Publicar na Google Play

Modelo de negócio (ver `store/plano-de-lancamento.html`): grátis para começar, pago uma vez para ficar. A
primeira temporada inteira é grátis, sem anúncios e sem assinatura, nem na versão grátis. Nunca vender
dinheiro do clube, jogadores, atributos, recuperação, pacotes aleatórios nem anúncios.

## Compras

| ID na Play Console | Tipo | Preço | O que faz |
|---|---|---|---|
| `carreira_completa` | Produto único, não consumível | R$ 9,99 · US$ 2,99 · € 2,99 | Libera da 2ª temporada em diante e os mods |
| `editor_carreira` | Produto único, não consumível | R$ 3,99 · US$ 0,99 · € 0,99 | Editor de jogadores e clubes durante a carreira |
| `cafe` | Produto único, consumível | R$ 2,99 · US$ 0,99 | Gorjeta: só um agradecimento nos créditos |

Preço de lançamento: Carreira Completa a **R$ 7,99 nas duas primeiras semanas** (Play Console → o produto →
Preço → promoção com data de fim). Nos outros países, use os preços regionais sugeridos pela Play.

O código fica em `mais-uma-rodada/scripts/autoload/store.gd` (autoload `Store`):

- A primeira temporada de qualquer carreira é grátis. Da 2ª em diante (`GameWorld.season_number >= 2`), o hub
  mostra "Mais uma temporada?", e pré-jogo, partida, simulação e pré-temporada levam à tela de compra
  (`paywall_screen.gd`). O save fica guardado para quem comprar depois.
- A compra fica salva no aparelho (`user://store.cfg`, assinada com o id do aparelho) para funcionar offline e é
  conferida com a Play a cada abertura: restaura ao reinstalar e volta a travar se a compra for reembolsada.
- O Editor na carreira (`Store.editor_unlocked()`, `Store.career_edit_on()`) é vendido à parte: sem ele, o
  Editor com carreira aberta mostra só Meu clube, Competições, Treinador e Mods, mais o botão de compra; ao
  comprar, a edição já vem ligada (desliga em Opções → Partidas). O Editor do menu inicial (mundo padrão das
  novas carreiras) continua grátis. As três compras aparecem juntas em Opções → Sobre → Compras.
- O café conta quantas vezes foi pago (`Store.tips`) e os créditos passam a mostrar o agradecimento.
- Compras são confirmadas (acknowledge) na hora; o café é consumido para poder ser comprado de novo.
- Só a versão de loja cobra: no editor, no PC e em builds de debug tudo vem liberado
  (`Store.enforce_override` força um lado nos testes).

## Antes de gerar

```sh
cd mais-uma-rodada && python3 tools/release_check.py
```

Confere versão e `version/code` iguais nos presets, ícones, plugin de compras, textos da loja dentro dos
limites (título 30, curta 80, completa 4000, novidades 500), ícone 512, banner, 2 a 8 capturas em
`store/screenshots`, política de privacidade (e a cópia do GitHub Pages) e que nenhuma chave está no git.

A cada versão nova, aumente `version/code` nos dois presets de `export_presets.cfg` e `config/version` em
`project.godot`, e escreva as novidades nos dois arquivos `store/play-store-*.txt`.

## Gerar o AAB

**Pelo GitHub (recomendado):** `.github/workflows/android-release.yml`.

1. Uma vez só, em Settings → Secrets and variables → Actions, crie os segredos:
   `ANDROID_UPLOAD_KEYSTORE_BASE64` (saída de `base64 -w0 mais-uma-rodada-upload.jks`),
   `ANDROID_UPLOAD_KEY_ALIAS` e `ANDROID_UPLOAD_KEY_PASSWORD`.
2. Com o workflow no branch padrão, rode Actions → "Android release (AAB)" → Run workflow, ou crie a tag
   `v0.4.0`. O AAB sai como artefato `aab` da execução.

**Na sua máquina:**

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
godot --headless --export-release "Android" build/MaisUmaRodada-0.4.0.aab
```

O preset "Android" gera AAB só com ARM64 (menos de 30 MB; celulares só de 32 bits ficam de fora) e alvo no
SDK 36. O preset "Android arm64" gera um APK para instalar direto no celular; exporte-o com `--export-debug`
para jogar sem trava.

Sem Android SDK (ou sem acesso ao dl.google.com), `mais-uma-rodada/tools/build_debug_apk.sh` gera um APK de teste
arm64 com o modelo pronto do Godot, sem o plugin de compras, e o assina com a chave de debug pelo
[uber-apk-signer](https://github.com/patrickfav/uber-apk-signer). Serve para testar no celular, não para a loja.
O APK de teste mais recente fica em `builds/`.

## Política de privacidade

A Play pede um link público. `docs/privacidade/index.html` é uma cópia de `store/politica-de-privacidade.html`
(o `release_check.py` avisa se as duas ficarem diferentes). Para publicar: Settings → Pages → Deploy from a
branch → `main`, pasta `/docs`. O endereço fica
`https://fragamurilo-netizen.github.io/games-and-games/privacidade/`.

## Play Console, na ordem

1. Criar o app: nome "Mais Uma Rodada: Técnico", jogo, gratuito, idioma padrão português (Brasil).
2. Ativar a Assinatura de apps do Google Play e enviar o AAB num teste fechado.
3. Criar os três produtos acima em Monetizar → Produtos → Produtos no app, com os preços (e a promoção de
   lançamento da Carreira Completa).
4. Ficha da loja: textos de `store/play-store-pt-BR.txt` e `store/play-store-en-US.txt`, ícone
   `store/icon-512.png`, banner `store/feature-graphic-1024x500.png` e as capturas de `store/screenshots`.
   Categoria Jogos › Esportes; tags Simulação esportiva, Futebol, Estratégia, Offline, Um jogador.
5. Conteúdo do app: política de privacidade (link do GitHub Pages acima), Segurança dos dados (nenhum dado
   coletado nem compartilhado), classificação IARC (sem violência, apostas nem chat), público-alvo 13+,
   sem anúncios, compras no app de R$ 2,99 a R$ 9,99.
6. Contas pessoais novas: teste fechado com pelo menos 12 testadores por 14 dias seguidos antes de pedir a
   produção. Adicione os testadores também em Configurações → Teste de licença para testar as compras sem
   ser cobrado.
7. Lançar primeiro no Brasil (teste aberto, depois produção com o preço de lançamento); o inglês numa segunda etapa.
