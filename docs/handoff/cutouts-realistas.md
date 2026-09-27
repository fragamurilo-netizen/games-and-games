# Handoff: cutouts mais realistas (PR #51)

Branch: `claude/cutouts-realistas-yll8lk`. Base: `claude/tela-jogador-rosto-pd1qgz` (PR #40, que corrige o rosto todo preto).
Estado: rascunho, esperando o ok do Calitos. A bateria de testes não foi rodada, como ele prefere.

## O que mudou (só `mais-uma-rodada/scripts/ui/components/portrait_view.gd`)

Só o desenho muda. Os valores do `FaceGen.features()` que os saves guardam continuam os mesmos.
**Nunca reordene** os índices de penteados e barbas.

### Luz sobre cabelo, barba e camisa
São camadas translúcidas desenhadas por cima das peças que já existem. Cada uma tem gerador próprio,
então os sorteios das outras peças não mudam.
- `_hair_light(hair)`, chamada logo depois de `_front_hair`: volume na calota (sombra lateral e
  embaixo, oclusão na raiz, luz no alto), mechas de reflexo (fios nos lisos e ondulados, voltinhas nos
  crespos) e luz de recorte no alto da silhueta. Com cabelo de trás volumoso (`bk` longo, afro,
  dreads, tranças), a borda da calota esmaece, para não formar um "capacete".
- `_volume_light(poly, center, hair, rim_light)`: volume do cabelo de trás (longo e afro).
- `_beard_px`: a barba tem volume (bochecha e queixo na luz; lado direito, parte de baixo, área sob o
  nariz e contorno da boca na sombra). Em `_beard_hairs`, os fios claros ficam do lado da luz.
- `_cloth_light(...)`, no fim de `_body`, antes da gola: dobras de tensão, peitoral, brilho do
  tecido e oclusão nas axilas, por cima da estampa, do escudo e do patrocínio. A partir de 150 px
  entra a trama de malha (`_knit_texture`). A ligação com o uniforme do editor (KitView, PR #30) foi
  mantida.
- `_light_pass`: a luz de recorte do rosto pula o cabelo e a barba (antes riscava os dois).

### Proporções e luz do rosto (medidas de retratos de estúdio de jogadores)
Medidas tiradas de retratos de referência (faces do FM24 no PC do Calitos). Nenhuma imagem foi
copiada. W = largura do rosto nas maçãs; H = altura da linha do cabelo ao queixo. Nas fotos,
H ≈ 1,35 W.

| Medida | Referência | Onde está no código |
|---|---|---|
| Olhos | 43–50% de H abaixo da linha do cabelo | `_E` em `_setup` |
| Olho → base do nariz | 0,26–0,30 H | `_N` |
| Nariz → meio da boca | 0,10–0,12 H | `_M` |
| Boca → queixo | 0,20–0,24 H | resultado dos anteriores |
| Largura do olho | 0,20–0,22 W; abertura 0,06–0,08 W | `ew`/`eh` em `_eyes` (×0,92 / ×0,85) |
| Íris | 0,45–0,5 do olho, pouco branco, reflexo pequeno | `_eyes` |
| Nariz (asas) | 0,26–0,32 W (0,34–0,38 em pele negra) | `_NW = nose_w * 1.5` |
| Boca | 0,38–0,45 W | `_MW = mouth_w * 1.25` |
| Mandíbula no ângulo | 0,85–0,95 W; ponta do queixo 0,35–0,45 W | `_hw` |
| Pescoço | 0,70–0,85 W, mais escuro que o rosto | `_body_setup`, `_neck_half` |
| Orelhas | da sobrancelha até a base do nariz | `_ears` |
| Sobrancelha | 0,08–0,10 H acima do olho, grossa e baixa | `_brows` (`brow_gap * 0.8`) |

Luz: uma fonte grande, frontal e alta (`LIGHT`). As sombras são quentes (marrom avermelhado, nunca
cinza ou azul). O reflexo forma um T (testa, dorso e ponta do nariz) e aparece também nas maçãs.
Sombra marcada só sob o nariz, o lábio e o queixo. Tudo isso fica no fim de `_skin_px`.
`HEAD_W = 0.87` deixa o rosto um pouco mais estreito.
`_dE` desce a linha de cima da barba nas bochechas junto com os olhos.

### Versão 2.0 (forma do rosto e realismo, mesma tecnologia)
Tudo continua sendo desenho procedural do `PortraitView`. A API e o modo cutout do PR #42 continuam iguais.
- **Relevo do rosto**: `_face_h(u, v)` é um mapa de altura (cúpula suave com norma p=5 e perfil
  `1 - th^3.4`, arco das sobrancelhas, órbitas, globo ocular, dorso/ponta/asas do nariz, maçãs,
  cavidade sob a maçã, focinho, dobra sob o lábio, queixo, têmporas). `_face_normal` tira a normal
  por diferenças centrais, e `_skin_px` usa essa normal em vez da cúpula radial. É daí que vem a forma
  real do nariz, das órbitas e das maçãs.
- **Pele**: `_skin_grain` põe poros e variação de tom (textura `_noise_texture(0)`, 256 px, em
  cache estático) e `_photo_grain` põe granulação de foto no fim. Nenhuma das duas roda em headless.
- **Detalhes**: colunas e sulco do filtro labial, borda clara do lábio, volume da pálpebra (a partir de
  90 px), sobrancelha em gradiente (não mais um bloco sólido), lábios sombreados pela luz.
- **Contorno**: maçã do rosto mais alta, leve ângulo na mandíbula para rostos quadrados, queixo mais
  definido (`_hw`). O afinamento para a mandíbula foi mantido como antes: alargar deixava a parte de
  baixo do rosto inchada.
- **Luz**: menos borda clara e menos rebatimento (menos cara de plástico), brilho especular mais largo e suave.
- **Cabelo e barba**: fios soltos na borda do cabelo curto e liso (a partir de 90 px). A barba tem
  textura de ruído na massa e o dobro de fios, então não fica mais um bloco sólido.
- `tools/cutout_closeup.gd --clean` gera 4 rostos sem barba para julgar só o rosto.

## O que ainda está aberto
- O Calitos ainda não aprovou a última rodada (proporções do FM). Numa rodada anterior, "nariz mais
  comprido e luz lateral forte", ele disse que piorou, e ela foi revertida.
- Com os olhos mais baixos a testa ficou maior. Se ele reclamar, o primeiro ajuste é o 0,43 em `_E`.
- Nas barbas cheias ficou uma faixa sem pelo no alto da bochecha. Confira no caso 0 do
  `cutout_closeup`.
- 2.0 esperando o ok do Calitos. Se ele achar o relevo forte demais, os pesos ficam em `_face_h`
  (maçã 0,035, focinho 0,03) e no expoente do perfil (3,4).
- Folhas 2.0 em `/mnt/project-files/cutouts-realistas/v2-*.png` (antes e depois).

## Como gerar as folhas de antes e depois
Precisa do Godot 4.7.2 (binário oficial para Linux) e de `xvfb-run`:

```
cd mais-uma-rodada
godot --headless --path . --import
xvfb-run -a godot --path . --resolution 1290x650 --script res://tools/cutout_closeup.gd -- --out=/tmp/depois.png
# grandes: --size=600 --only=1,7 com --resolution 1240x620
git stash   # ou faça checkout do commit anterior e gere o "antes" com o mesmo comando
```
Outras folhas: `tools/cutout_kits.gd` (uniforme do editor ao lado do cutout) e `tools/face_sheet.gd`
(várias etnias e idades em tamanho pequeno).
