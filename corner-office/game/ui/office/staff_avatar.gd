class_name StaffAvatar
extends Control
## Busto do funcionário (mesmas peças do sprite da sede). Ponto de alerta no
## canto quando há problema, para leitura em três segundos.

var staff: StaffMember
var show_alert := true


static func make(s: StaffMember, width: float) -> StaffAvatar:
	var a := StaffAvatar.new()
	a.staff = s
	a.custom_minimum_size = Vector2(width, width * 1.1)
	a.mouse_filter = MOUSE_FILTER_IGNORE
	return a


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if staff == null:
		return
	PeopleArt.draw_bust(self, Rect2(Vector2.ZERO, size), staff)
	if show_alert:
		var problem := Office.problem(staff)
		if not problem.is_empty():
			var c := Tokens.FIGHT_RED if problem in ["stress", "unhappy"] else Tokens.WARN
			draw_circle(Vector2(size.x - 10, 10), 8, c)
			draw_string(Tokens.DISPLAY_FONT, Vector2(size.x - 13, 15), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Tokens.INK)
	draw_rect(Rect2(Vector2.ZERO, size), Tokens.CANVAS, false, 2.0)
