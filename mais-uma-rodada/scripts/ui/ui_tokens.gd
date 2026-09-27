class_name UITokens
extends RefCounted
## Medidas do sistema de design: espaçamento, cantos, tipografia e alturas. As telas e o
## tema (tools/build_theme.gd) usam estes valores em vez de números soltos, para que tudo
## tenha o mesmo ritmo. As cores ficam em UIColors.

## Espaçamento (grade de 4 px).
const S1 := 4
const S2 := 8
const S3 := 12
const S4 := 16
const S5 := 20
const S6 := 24
const S8 := 32
## Margem lateral das telas.
const GUTTER := 20

## Cantos: pequenos e retos, no estilo das transmissões esportivas.
const R_XS := 6
const R_SM := 8
const R_MD := 12
const R_LG := 16

## Tipografia (px no viewport de 720 de largura).
const F_DISPLAY := 56
const F_TITLE := 40
const F_H2 := 30
const F_H3 := 24
const F_BODY := 24
const F_SMALL := 19
const F_CAPS := 16
const F_EYEBROW := 17

## Alturas de toque.
const H_BUTTON := 72
const H_BUTTON_SM := 56
const H_CHIP := 48
const H_TAB := 64
const H_ROW := 84
const H_NAV := 96

## Linha fina que separa cartões do fundo (mapeada no modo claro em UIColors.LIGHT_EXTRA).
const HAIRLINE := Color("#1E232C")
## Fundo das barras (superior, inferior, rodapés).
const BAR := Color("#0D1015")
