extends Control
## Prova visual real do Godot. Não é mockup: esta cena monta Controls, carrega os SVGs
## de res://assets/visual_proof e salva o próprio Viewport quando executada com --render-proof.

@export_enum("dashboard", "crests") var mode: String = "dashboard"

const W := 900.0
const H := 1600.0
const BG := Color("#07111F")
const SURFACE := Color("#0E1B2B")
const CARD := Color("#F5F7FA")
const CARD_2 := Color("#E9EEF3")
const TEXT := Color("#101827")
const MUTED := Color("#657286")
const WHITE := Color("#F7FAFC")
const GREEN := Color("#20C878")
const GOLD := Color("#E3B54B")
const RED := Color("#EA5B5B")
const BLUE := Color("#3CB6F0")

const CRESTS := [
	["Aurora FC", "res://assets/visual_proof/aurora_fc.svg", Color("#F4B942")],
	["Vale Unido", "res://assets/visual_proof/vale_unido.svg", Color("#2F7A4D")],
	["Ferro Azul", "res://assets/visual_proof/ferro_azul.svg", Color("#45B9F4")],
	["Estrela do Sul", "res://assets/visual_proof/estrela_sul.svg", Color("#D9A441")],
	["Monte Verde", "res://assets/visual_proof/monte_verde.svg", Color("#2D7A46")],
]

func _ready() -> void:
	get_window().size = Vector2i(int(W), int(H))