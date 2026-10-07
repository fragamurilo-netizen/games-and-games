extends SceneTree
## Gera assets/theme/main_theme.tres a partir do código (fonte da verdade do visual).
## Uso: godot --headless --path . --script res://tools/build_theme.gd
##
## A geração fica em build_theme_runner.gd, carregado só depois do primeiro quadro: scripts usados
## direto por um --script são compilados antes dos autoloads existirem (e as cores dependem deles).


func _initialize() -> void:
	process_frame.connect(_start, CONNECT_ONE_SHOT)


func _start() -> void:
	# O tema é gravado com a paleta escura e o dourado (as cores de referência de UIColors.themed).
	var ui_colors: GDScript = load("res://scripts/ui/ui_colors.gd")
	if bool(ui_colors.get("light")) or ui_colors.get("_applied") != "":
		push_warning("paleta já alterada ao gerar o tema")
	load("res://tools/build_theme_runner.gd").new().build()
	quit()
