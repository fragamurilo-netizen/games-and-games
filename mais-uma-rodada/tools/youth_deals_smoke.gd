extends SceneTree
## Base e negociações sem interface: monta as competições de base, joga todas as datas da
## temporada só com a base, fecha o ano e exercita as condições de negócio (pega erro de execução).
## godot --headless --path . --script res://tools/youth_deals_smoke.gd [-- --club=Nome]


func _initialize() -> void:
	process_frame.connect(func(): root.add_child(load("res://tools/youth_deals_smoke_runner.gd").new()), CONNECT_ONE_SHOT)
