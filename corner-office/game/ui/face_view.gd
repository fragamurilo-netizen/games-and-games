class_name FaceView
extends Control
## Rosto do lutador desenhado nativamente (Game Design Bible §5): o mesmo
## rosto do boneco do Fight Studio, sem WebView e sem espera. O desenho é
## gerado uma vez por rosto e proporção (PortraitPainter) e reaproveitado.

const BASE_W := 256.0
static var _cache: Dictionary = {}
static var _profiles: Dictionary = {}

var face: Dictionary = {}
var avatar := false
var _ops: Array = []


## Rosto de um atleta. avatar = enquadramento curto (listas).
static func of(f: Fighter, width: float, is_avatar: bool = false) -> FaceView:
	var v := FaceView.new()
	v.custom_minimum_size = Vector2(width, width * 1.25)
	v.avatar = is_avatar
	v.clip_contents = true
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_fighter(f)
	return v


## Rosto completo de um atleta (retrato autoral dos canônicos incluído).
static func face_of(f: Fighter, appearance: Dictionary = {}) -> Dictionary:
	if _profiles.is_empty():
		_profiles = ContentDB.load_json("combat_profiles.json").get("fighters", {})
	var a := f.appearance if appearance.is_empty() else appearance
	var canon: Variant = null
	if not a.has("pop"):
		canon = _profiles.get(f.id, {}).get("appearance_index", null)
	return FaceResolver.resolve(a, "f" if f.sex == Fighter.Sex.FEMALE else "m", canon)


## Operações de desenho em cache para um rosto e proporção.
static func ops_for(face_data: Dictionary, ratio: float, is_avatar: bool) -> Array:
	var key := "%s|%s|%.2f" % [JSON.stringify(face_data), is_avatar, ratio]
	if not _cache.has(key):
		if _cache.size() > 400:
			_cache.clear()
		_cache[key] = PortraitPainter.build(face_data, BASE_W, BASE_W * ratio, {"avatar": is_avatar})
	return _cache[key]


func set_fighter(f: Fighter) -> void:
	set_face(face_of(f))


func set_face(value: Dictionary) -> void:
	face = value
	_ops = ops_for(face, custom_minimum_size.y / maxf(1.0, custom_minimum_size.x), avatar)
	queue_redraw()


func _draw() -> void:
	PortraitPainter.draw(self, _ops, size.x / BASE_W)
