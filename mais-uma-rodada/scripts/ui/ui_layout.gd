class_name UILayout
extends RefCounted
## Coordenadas lógicas responsivas. Rotacionar não reduz texto nem alvos de toque.

const COMPACT := 0
const MEDIUM := 1
const EXPANDED := 2
const BP_MEDIUM := 1000.0
const BP_EXPANDED := 1500.0
const COLUMN_MAX := 820.0
const RAIL_W := 132.0
const COL3_MIN := 2000.0
static var viewport := Vector2(600, 1066)
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


static func columns_for(w: float, max_cols: int = 3) -> int:
	if w >= COL3_MIN and max_cols >= 3:
		return 3
	if w >= BP_MEDIUM - RAIL_W and max_cols >= 2:
		return 2
	return 1


static func is_tablet() -> bool:
	if force_tablet:
		return true
	if not OS.has_feature("mobile"):
		return false
	var px := Vector2(DisplayServer.screen_get_size())
	var dpi := float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		return minf(px.x, px.y) >= 1200.0
	var short_dp := minf(px.x, px.y) / (dpi / 160.0)
	return px.length() / dpi >= 7.0 or short_dp >= 600.0


## Função pura para testar rotação sem depender do sensor ou do monitor da máquina.
## A base também gira; manter 720x1280 deitado encolhia a interface para caber na altura.
## No tablet a base é maior que a do celular: mais conteúdo por tela, com texto ainda maior
## (em milímetros) que no celular.
static func base_size_for(window_size: Vector2i, tablet: bool = false) -> Vector2i:
	# Celular: 600 de largura (1 dp ≈ 1,5 px nos aparelhos de 390–411 dp; DESIGN.md › Unidades).
	var portrait := Vector2i(1100, 1500) if tablet else Vector2i(600, 1066)
	if window_size.x > window_size.y:
		return Vector2i(portrait.y, portrait.x)
	return portrait


## O tamanho escolhido em Opções é respeitado. Não há mais fator oculto 0.66/0.72.
static func device_scale() -> float:
	return 1.0


static func width_boost() -> float:
	return 1.25 if is_tablet() and is_landscape() else 1.0
