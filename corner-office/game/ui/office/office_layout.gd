class_name OfficeLayout
extends RefCounted
## Planta da sede em coordenadas de projeto (1000 × 760). A cena escala para
## caber na tela; salas bloqueadas aparecem em obras com o nível exigido, para
## que o crescimento seja visível antes de acontecer (content/office.json).

const W := 1000.0
const H := 760.0
const ROW_A := Rect2(0, 36, 1000, 230)     # estúdio | reunião | presidência
const ROW_B := Rect2(0, 266, 1000, 290)    # salão das mesas
const ROW_C := Rect2(0, 556, 1000, 204)    # recepção | copa | médico | vídeo | hall
const LANE_A := 276.0                      # corredor entre A e B
const LANE_C := 546.0                      # corredor entre B e C

const ROOMS := {
	"studio": {"rect": Rect2(0, 36, 300, 230), "label": "Estúdio de mídia", "floor": "tile"},
	"meeting": {"rect": Rect2(300, 36, 350, 230), "label": "Sala de reunião", "floor": "wood"},
	"president": {"rect": Rect2(650, 36, 350, 230), "label": "Presidência", "floor": "wood"},
	"desks": {"rect": Rect2(0, 266, 1000, 290), "label": "Salão", "floor": "carpet"},
	"reception": {"rect": Rect2(0, 556, 200, 204), "label": "Recepção", "floor": "tile"},
	"pantry": {"rect": Rect2(200, 556, 250, 204), "label": "Copa", "floor": "tile"},
	"medical": {"rect": Rect2(450, 556, 250, 204), "label": "Departamento médico", "floor": "tile"},
	"film": {"rect": Rect2(700, 556, 150, 204), "label": "Sala de vídeo", "floor": "carpet"},
	"hall": {"rect": Rect2(850, 556, 150, 204), "label": "Hall dos cinturões", "floor": "wood"},
}
## Salas que existem desde o nível 1 mesmo sem aparecer na lista do conteúdo.
const ALWAYS := ["desks", "reception", "pantry", "president"]

const DOOR := Vector2(100, 740)             # entrada/saída de pessoas


static func unlocked(level_rooms: Array, room: String) -> bool:
	return room in ALWAYS or room in level_rooms


## Nível que libera a sala (para o aviso "em obras").
static func unlock_level(room: String) -> int:
	for l: Dictionary in Office.config().office_levels:
		if room in l.rooms:
			return int(l.level)
	return 1


## 24 posições de mesa: 3 fileiras × 8. As primeiras `desks(level)` estão mobiliadas.
static func desk_slot(i: int) -> Dictionary:
	var col := i % 8
	var row := i / 8
	var x := 70.0 + col * 118.0
	var y := 336.0 + row * 88.0
	# A pessoa senta atrás da mesa, de frente para quem olha a sede: a mesa
	# cobre as pernas e o rosto fica visível.
	return {"desk": Rect2(x - 40, y, 80, 30), "seat": Vector2(x, y + 8), "screen": Vector2(x, y + 4)}


static func meeting_seat(i: int) -> Vector2:
	var r: Rect2 = ROOMS.meeting.rect
	var positions := [Vector2(0.28, 0.42), Vector2(0.5, 0.36), Vector2(0.72, 0.42), Vector2(0.28, 0.8), Vector2(0.5, 0.86), Vector2(0.72, 0.8)]
	var p: Vector2 = positions[i % positions.size()]
	return r.position + r.size * p + Vector2(0, 8 * (i / positions.size()))


static func pantry_spot(i: int) -> Vector2:
	var r: Rect2 = ROOMS.pantry.rect
	var spots := [Vector2(0.3, 0.55), Vector2(0.52, 0.55), Vector2(0.72, 0.62), Vector2(0.4, 0.8), Vector2(0.62, 0.82), Vector2(0.2, 0.78)]
	return r.position + r.size * spots[i % spots.size()]


## Caminho em "L" pelos corredores, sem atravessar paredes.
static func path(from: Vector2, to: Vector2) -> Array:
	var lane_from := _lane(from)
	var lane_to := _lane(to)
	if absf(from.y - to.y) < 40 and _row(from) == _row(to):
		return [to]
	var pts: Array = [Vector2(from.x, lane_from)]
	if lane_from != lane_to:
		pts.append(Vector2(clampf(from.x, 60, 940), lane_from))
		pts.append(Vector2(clampf(from.x, 60, 940), lane_to))
	pts.append(Vector2(to.x, lane_to))
	pts.append(to)
	return pts


static func _row(p: Vector2) -> int:
	return 0 if p.y < ROW_B.position.y else (1 if p.y < ROW_C.position.y else 2)


static func _lane(p: Vector2) -> float:
	match _row(p):
		0: return LANE_A
		2: return LANE_C
	return LANE_A if p.y < (LANE_A + LANE_C) * 0.5 else LANE_C
