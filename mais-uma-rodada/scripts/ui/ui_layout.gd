class_name UILayout
extends RefCounted
## Layout responsivo: em que tipo de tela o jogo está (celular ou tablet, retrato ou
## paisagem) e quantas colunas cabem. As telas perguntam aqui em vez de medir sozinhas.
##
## Pontos de quebra, pela largura do viewport (em px lógicos; o celular em retrato tem 720):
##   compacto  < 1000  → uma coluna, navegação embaixo
##   médio     < 1500  → duas colunas, navegação lateral
##   amplo    >= 1500  → duas colunas mais largas (ou três nas telas que aproveitam)

const COMPACT := 0
const MEDIUM := 1
const EXPANDED := 2
const BP_MEDIUM := 1000.0
const BP_EXPANDED := 1500.0
## Largura máxima de uma coluna de cartões (texto longo fica ruim de ler além disso).
const COLUMN_MAX := 820.0
## Largura da navegação lateral.
const RAIL_W := 132.0
## Largura de conteúdo a partir da qual cabem três colunas de cartões.
const COL3_MIN := 2000.0

## Quem mede: a raiz da interface (main.gd) atualiza a cada mudança de tamanho.
static var viewport := Vector2(720, 1280)
## Forçar tablet (capturas e testes); no aparelho é detectado pelo tamanho físico da tela.
static var force_tablet := false


static func size_class() -> int:
	if viewport.x >= BP_EXPANDED:
		return EXPANDED
	if viewport.x >= BP_MEDIUM:
		return MEDIUM
	return COMPACT


static func is_wide() -> bool:
	return size_class() != COMPACT


static func is_landscape() -> bool:
	return viewport.x > viewport.y


## Colunas de cartões para a largura disponível `w` (a área de conteúdo, sem a navegação).
## Três colunas só cabem no tablet deitado (e em monitores muito largos).
static func columns_for(w: float, max_cols: int = 3) -> int:
	if w >= COL3_MIN and max_cols >= 3:
		return 3
	if w >= BP_MEDIUM - RAIL_W and max_cols >= 2:
		return 2
	return 1


## Tablet: tela física com 7 polegadas ou mais na diagonal, ou com o lado menor de 600 dp ou
## mais (a regra do Android para tablet), ou forçado.
static func is_tablet() -> bool:
	if force_tablet:
		return true
	if not OS.has_feature("mobile"):
		return false
	var px := Vector2(DisplayServer.screen_get_size())
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		# Sem DPI: tela grande em pixels já é tablet
		return minf(px.x, px.y) >= 1200.0
	var short_dp := minf(px.x, px.y) / (dpi / 160.0)
	return px.length() / dpi >= 7.0 or short_dp >= 600.0


## Escala extra da interface: no tablet tudo fica menor para aproveitar a tela (mais conteúdo
## por vez, como nos jogos de gestão em tablet). Em retrato a escala menor faz caber a navegação
## lateral e duas colunas.
static func device_scale() -> float:
	if not is_tablet():
		return 1.0
	var px := Vector2(DisplayServer.window_get_size())
	return 0.66 if px.y > px.x else 0.72


## Quanto as telas podem alargar além da largura máxima delas: no tablet deitado o conteúdo
## ocupa mais da tela; no retrato e no celular fica como está.
static func width_boost() -> float:
	return 1.25 if is_tablet() and is_landscape() else 1.0
