class_name Fonts
extends RefCounted
## Fontes de reserva para as letras que a Saira não tem: cirílico (Noto Sans) e chinês
## (Noto Sans SC, só com os caracteres que as traduções usam; tools/i18n_fonts.py refaz).
## Cada variação da Saira ganha reservas com o mesmo peso e a largura mais perto, para o
## título em russo continuar pesado e comprimido.

const CYRILLIC := "res://assets/fonts/NotoSans-Cyrillic.ttf"
const CHINESE := "res://assets/fonts/NotoSansSC-Jogo.ttf"


## Liga as reservas numa variação da Saira (`weight` 100 a 900, `width` em %).
static func add_fallbacks(fv: FontVariation, weight: float, width: float) -> FontVariation:
	var list: Array[Font] = []
	if ResourceLoader.exists(CYRILLIC):
		var cyr := FontVariation.new()
		cyr.base_font = load(CYRILLIC)
		cyr.variation_opentype = {"weight": weight, "width": clampf(width, 62.5, 100.0)}
		list.append(cyr)
	if ResourceLoader.exists(CHINESE):
		var zh := FontVariation.new()
		zh.base_font = load(CHINESE)
		# O chinês desenha maior e mais escuro que a Saira no mesmo tamanho.
		zh.variation_opentype = {"weight": clampf(weight - 80.0, 300.0, 800.0)}
		list.append(zh)
	fv.fallbacks = list
	return fv
