class_name UIColors
extends RefCounted
## Paleta do jogo (escura, elegante, levemente retrô). Use estas constantes em vez de cores soltas.

const BG := Color("#0E1621")
const SURFACE := Color("#162231")
const SURFACE_2 := Color("#1D2B3C")
const SURFACE_3 := Color("#26374B")
const LINE := Color("#2A3B50")
const TEXT := Color("#EAF0F6")
const MUTED := Color("#8FA3B8")
const DIM := Color("#5D7189")
const ACCENT := Color("#FFC940")
const ACCENT_DARK := Color("#C99A1E")
const ON_ACCENT := Color("#1A1300")
const GREEN := Color("#3DBE7A")
const RED := Color("#E5484D")
const BLUE := Color("#4EA8DE")
const ORANGE := Color("#F0A35E")
const PITCH_A := Color("#2E7D4B")
const PITCH_B := Color("#2A7445")
const PITCH_LINE := Color(0.87, 0.95, 0.89, 0.75)


static func result_color(r: String) -> Color:
	match r:
		"V":
			return GREEN
		"D":
			return RED
		"E":
			return ORANGE
	return DIM


static func morale_color(m: float) -> Color:
	if m >= 75.0:
		return GREEN
	if m >= 55.0:
		return Color("#8FD694")
	if m >= 35.0:
		return ORANGE
	return RED


static func morale_label(m: float) -> String:
	if m >= 80.0:
		return "Excelente"
	if m >= 65.0:
		return "Boa"
	if m >= 45.0:
		return "Normal"
	if m >= 30.0:
		return "Baixa"
	return "Péssima"


static func fans_label(m: float) -> String:
	if m >= 85.0:
		return "Apaixonada"
	if m >= 70.0:
		return "Empolgada"
	if m >= 55.0:
		return "Satisfeita"
	if m >= 40.0:
		return "Indiferente"
	if m >= 25.0:
		return "Frustrada"
	return "Revoltada"


## Cor legível (preta ou branca) sobre um fundo.
static func on_color(bg: Color) -> Color:
	return Color("#111111") if bg.get_luminance() > 0.6 else Color.WHITE
