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
static func columns_for(w: float, max_cols: int = 2) -> int:
	if w >= COLUMN_MAX * 2.6 and max_cols >= 3:
		return 3
	if w >= BP_MEDIUM - RAIL_W and max_cols >= 2:
		return 2
	return 1


## Tablet: tela física com 7 polegadas ou mais na diagonal (ou forçado).
static func is_tablet() -> bool:
	if force_tablet:
		return true
	if not OS.has_feature("mobile"):
		return false
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		return false
	var px := Vector2(DisplayServer.screen_get_size())
	return px.length() / dpi >= 7.0


## Escala extra da interface: no tablet tudo fica um pouco menor para aproveitar a tela
## (mais conteúdo por vez, como nos jogos de gestão em tablet).
static func device_scale() -> float:
	return 0.8 if is_tablet() else 1.0
