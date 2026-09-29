extends "res://scripts/ui/screens/match_screen.gd"
## Mantém o motor da 0.4.0; corrige somente apresentação e ciclo de vida da tela.

var _mobile_left: Array[Control] = []
var _mobile_right: Array[Control] = []
var _mobile_portrait_pitch_height := 330.0
var _mobile_rotation_ready := false


func _responsive_layout() -> void:
	if not is_instance_valid(_root) or not is_instance_valid(_pitch):
		return
	if not is_instance_valid(_stats_box) or not is_instance_valid(_tabs_row):
		return
	if not is_instance_valid(_feed_scroll) or not is_instance_valid(_tab_scroll):
		return
	var pitch_box := _pitch.get_parent() as Control
	var stats_box := _stats_box.get_parent() as Control
	if not _mobile_rotation_ready:
		# Captura TODOS os blocos entre campo e números (inclui tarja e placares).
		# Depois de reparentear, índices locais já não identificam filhos da raiz.
		if pitch_box.get_parent() != _root or stats_box.get_parent() != _root:
			return
		var first := pitch_box.get_index()
		var last := stats_box.get_index()
		if first > last:
			return
		for i in range(first, last + 1):
			var node := _root.get_child(i) as Control
			if node != null:
				_mobile_left.append(node)
		_mobile_right.assign([_tabs_row.get_parent(), _feed_scroll, _tab_scroll])
		_mobile_portrait_pitch_height = _pitch.custom_minimum_size.y
		_mobile_rotation_ready = true
	# Duas colunas só deitado: no tablet em pé o campo esticava na coluna estreita (arquibancada
	# ocupando meia tela) e a faixa de placares cortava; em pé fica empilhado como no celular.
	var wide := UILayout.is_wide() and UILayout.is_landscape()
	if wide == is_instance_valid(_wide_body):
		if not wide:
			_pitch.custom_minimum_size.y = _portrait_pitch_height()
		return
	if wide:
		var at := pitch_box.get_index()
		_wide_body = UIKit.hbox(0)
		_wide_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var left := UIKit.vbox(0)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.size_flags_stretch_ratio = 1.25
		var right := UIKit.vbox(0)
		right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_wide_body.add_child(left)
		var separator := ColorRect.new()
		separator.color = UITokens.HAIRLINE if not UIColors.light else UIColors.LINE
		separator.custom_minimum_size.x = 1
		separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_wide_body.add_child(separator)
		_wide_body.add_child(right)
		_root.add_child(_wide_body)
		_root.move_child(_wide_body, at)
		for node in _mobile_left:
			node.reparent(left, false)
		for node in _mobile_right:
			node.reparent(right, false)
		pitch_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		# Libera altura para os controles, sem diminuir a tipografia da narração.
		_pitch.custom_minimum_size.y = 220.0
	else:
		var at := _wide_body.get_index()
		for node in _mobile_left + _mobile_right:
			node.reparent(_root, false)
			_root.move_child(node, at)
			at += 1
		pitch_box.size_flags_vertical = Control.SIZE_FILL
		_pitch.custom_minimum_size.y = _portrait_pitch_height()
		var old := _wide_body
		_wide_body = null
		_root.remove_child(old)
		old.queue_free()


## Tablet em pé: a tela é mais larga, então o campo empilhado pode crescer.
func _portrait_pitch_height() -> float:
	if UILayout.is_wide():
		return maxf(_mobile_portrait_pitch_height, 560.0)
	return _mobile_portrait_pitch_height


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
