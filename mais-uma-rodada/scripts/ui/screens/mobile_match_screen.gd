extends "res://scripts/ui/screens/match_screen.gd"
## Mantém o motor da 0.4.0; corrige somente apresentação e ciclo de vida da tela.

# The base owns one responsive layout; duplicating it here left the pitch in
# its previous orientation and retained landscape height after rotation.
func _responsive_layout() -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_pitch):
		return
	if not is_instance_valid(_stats_box) or not is_instance_valid(_tabs_row):
		return
	if not is_instance_valid(_feed_scroll) or not is_instance_valid(_tab_scroll):
		return
	super._responsive_layout()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or is_queued_for_deletion():
		return
	# Um retorno do Android não deve despejar segundos de eventos num único quadro.
	super._process(minf(delta, 0.1))


func on_show() -> void:
	super.on_show()
	# _build pode redirecionar ao hub se o jogo não existir mais; não deixar o nó
	# que já foi descartado processar nem reativar a renderização contínua.
	if is_queued_for_deletion() or _sim == null or _fx == null:
		set_process(false)
		_set_live(false)
