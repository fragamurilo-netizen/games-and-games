class_name UITokens
extends RefCounted
## Medidas do sistema de design: espaçamento, cantos, tipografia e alturas. As telas e o
## tema (tools/build_theme.gd) usam estes valores em vez de números soltos, para que tudo
## tenha o mesmo ritmo. As cores ficam em UIColors.

## Valores em px do canvas (600 de largura em retrato; 1 dp ≈ 1,5 px). Fonte da verdade:
## DESIGN.md. Não crie valores fora destas escalas.

## Espaçamento: 6, 12, 18, 24, 36, 48.
const S1 := 6
const S2 := 12
const S3 := 18
const S4 := 24
const S5 := 24
const S6 := 36
const S8 := 48
## Margem lateral das telas (contexto denso: GUTTER_DENSE).
const GUTTER := 20
const GUTTER_DENSE := 16

## Cantos: tudo reto. O que é botão, etiqueta ou destaque leva o corte em diagonal nos quatro
## cantos (o octógono da marca), com os tamanhos CUT_*. Os nomes R_* ficam para o código antigo e
## valem zero.
const R_NONE := 0
const R_XS := 0
const R_SM := 0
const R_MD := 0
const R_LG := 0
const R_PILL := 0
const CUT_SM := 5
const CUT := 9
const CUT_LG := 14

## Tipografia (DESIGN.md › Typography).
const F_SCORE := 60
const F_ENTITY := 44
const F_SCREEN := 36
const F_SECTION := 28
const F_BODY := 24
const F_BODY_SMALL := 21
const F_META := 20
const F_CAPTION := 18
## Apelidos antigos, apontando para a escala nova.
const F_DISPLAY := F_SCORE
const F_TITLE := F_ENTITY
const F_H2 := F_SECTION
const F_H3 := F_BODY
const F_SMALL := F_BODY_SMALL
const F_CAPS := F_CAPTION
const F_EYEBROW := F_CAPTION

## Alturas de toque (≥ 72 = 48 dp; compactos ≥ 66 = 44 dp).
const H_BUTTON := 72
const H_BUTTON_SM := 66
const H_CHIP := 66
const H_TAB := 72
const H_ROW := 84
const H_NAV := 96

## Divisor fino dentro de superfícies (mapeado no modo claro em UIColors.LIGHT_EXTRA).
const HAIRLINE := Color("#2A2725")
## Fundo das barras (superior, navegação, rodapés).
const BAR := Color("#050505")
