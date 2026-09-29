class_name FightReplayPlayer
extends RefCounted
## Event-authoritative visual playback; never computes fight outcomes.
## Game Design Bible §§6,15,17; MMA Research Bible §20.
## Shares JSON keyframes and replay contract with prototypes/fight-lab/replay.js.

const GROUND := ["guard", "half_guard", "side_control", "mount_back", "scramble"]
var errors: Array[String] = []
var duration_ms := 0.0
var _log: Dictionary = {}
var _clips: Dictionary = {}
var _ends: Array = []
var _catalog: Dictionary = {}
var _arenas: Dictionary = {}

func _init() -> void:
	_catalog = ContentDB.load_json("fight_visuals.json")
	_arenas = ContentDB.load_json("arena_profiles.json")
	for clip: Dictionary in _catalog.clips:
		_clips[clip.id] = clip

func load_replay(data: Dictionary) -> bool:
	errors = validate(data)
	if not errors.is_empty():
		return false
	_log = data.duplicate(true)
	_ends.clear()
	duration_ms = 0.0
	for event: Dictionary in _log.events:
		duration_ms = maxf(duration_ms, event.at_ms + event.duration_ms)
		var last: Dictionary = _clips[event.technique_id].tracks[event.outcome][-1]
		var flip: bool = event.actor_id != _log.fighter_ids[0]
		_ends.append({event.actor_id: _reflect(last.a) if flip else last.a.duplicate(true), event.target_id: _reflect(last.b) if flip else last.b.duplicate(true)})
	return true

func validate(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if data.get("version") != 1 or data.get("source", "") not in ["authored_preview", "simulation"]:
		out.append("Unsupported version/source")
	var ids: Variant = data.get("fighter_ids")
	if not ids is Array or ids.size() != 2 or ids[0] == ids[1]:
		out.append("Two distinct fighter ids required")
		return out
	var arena := {}
	for profile: Dictionary in _arenas.arenas:
		if profile.id == data.get("organization_id"):
			arena = profile
	if arena.is_empty() or arena.get("ruleset_id") != data.get("ruleset_id"):
		out.append("Arena/ruleset mismatch")
	var events: Variant = data.get("events")
	if not events is Array or events.is_empty():
		out.append("Empty event log")
		return out
	var previous: Dictionary = data.get("initial_state", {})
	if not _state_valid(previous, ids, arena):
		out.append("Invalid initial state")
	var end := 0.0
	var round_number := 0
	var clock := 301.0
	var seen := {}
	for entry: Variant in events:
		if not entry is Dictionary:
			out.append("Invalid event")
			continue
		var event: Dictionary = entry
		var id: String = str(event.get("id", ""))
		if id.is_empty() or seen.has(id):
			out.append("Missing/duplicate event id")
		seen[id] = true
		var at: Variant = event.get("at_ms")
		var duration: Variant = event.get("duration_ms")
		if not _number(at) or not _number(duration) or at < end or duration <= 0:
			out.append("Invalid/overlapping timing: " + id)
		else:
			end = float(at + duration)
		var r: Variant = event.get("round")
		var time: Variant = event.get("clock_s")
		if not _number(r) or not _number(time) or r != floor(r) or r < maxi(1, round_number) or time < 0 or time > 300 or (r == round_number and time > clock):
			out.append("Invalid round/clock: " + id)
		else:
			round_number = int(r)
			clock = float(time)
		if event.get("actor_id") not in ids or event.get("target_id") not in ids or event.get("actor_id") == event.get("target_id"):
			out.append("Invalid actors: " + id)
		if event.get("rules_approved") != true or not event.get("reason_codes") is Array or event.get("reason_codes", []).is_empty():
			out.append("Missing rules/reason codes: " + id)
		var before: Dictionary = event.get("before", {})
		var after: Dictionary = event.get("after", {})
		if not _state_valid(before, ids, arena) or not _state_valid(after, ids, arena) or before != previous:
			out.append("Invalid/discontinuous states: " + id)
		previous = after
		var clip: Dictionary = _clips.get(event.get("technique_id", ""), {})
		if clip.is_empty():
			out.append("Unknown technique: " + id)
			continue
		if event.get("outcome") not in clip.outcomes or before.get("position") not in clip.from_positions or after.get("position") != expected_position(clip, event):
			out.append("Incompatible outcome/position: " + id)
		if before.get("position") in GROUND:
			if clip.actor_role == "top" and before.get("top_id") != event.get("actor_id"):
				out.append("Technique requires top fighter: " + id)
			if clip.actor_role == "bottom" and before.get("top_id") != event.get("target_id"):
				out.append("Technique requires bottom fighter: " + id)
	var result: Variant = data.get("result")
	if result is Dictionary:
		if result.get("method") not in ["ko_tko", "submission", "decision", "draw", "nc", "dq"] or (result.get("winner_id") != null and result.get("winner_id") not in ids):
			out.append("Invalid result")
		if result.get("method") in ["draw", "nc"] and result.get("winner_id") != null:
			out.append("Draw/NC cannot have a winner")
	return out

func _state_valid(state: Dictionary, ids: Array, arena: Dictionary) -> bool:
	if state.get("position") not in _catalog.positions or state.get("location") not in ["center", "cage", "ropes"]:
		return false
	if state.location != "center" and state.location != ("ropes" if arena.get("venue") == "ring" else "cage"):
		return false
	if state.position in GROUND:
		if state.get("top_id") not in ids:
			return false
	elif state.get("top_id") != null:
		return false
	for id: String in ids:
		var energy: Variant = state.get("stamina", {}).get(id)
		if not _number(energy) or energy < 0 or energy > 1:
			return false
		for zone: String in ["head", "body", "leg"]:
			var damage: Variant = state.get("damage", {}).get(id, {}).get(zone)
			if not _number(damage) or damage < 0 or damage > 1:
				return false
	return true

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func expected_position(clip: Dictionary, event: Dictionary) -> String:
	var outcome: String = event.get("outcome", "")
	var position: String = event.get("before", {}).get("position", "")
	if outcome == "knockdown":
		return "scramble"
	if outcome in ["stoppage", "tapped"]:
		return "reset"
	if outcome == "escaped" and clip.family == "control":
		return "pocket" if position in ["clinch", "cage_wrestling"] else "scramble"
	return clip.to_position if outcome in ["completed", "held", "threatened"] else position

func seek_ms(milliseconds: float) -> Dictionary:
	if _log.is_empty():
		return {}
	var time := clampf(milliseconds if is_finite(milliseconds) else 0.0, 0.0, duration_ms)
	var index := 0
	var high: int = _log.events.size() - 1
	while index < high:
		var mid := ceili((index + high) / 2.0)
		if _log.events[mid].at_ms <= time:
			index = mid
		else:
			high = mid - 1
	var event: Dictionary = _log.events[index]
	var clip: Dictionary = _clips[event.technique_id]
	var progress := clampf((time - event.at_ms) / event.duration_ms, 0.0, 1.0)
	var frames: Array = clip.tracks[event.outcome]
	var n := 0
	while n < frames.size() - 2 and frames[n + 1].t < progress:
		n += 1
	var weight := clampf((progress - frames[n].t) / (frames[n + 1].t - frames[n].t), 0.0, 1.0)
	weight = weight * weight * (3.0 - 2.0 * weight)
	var a: Dictionary = _blend(frames[n].a, frames[n + 1].a, weight)
	var b: Dictionary = _blend(frames[n].b, frames[n + 1].b, weight)
	if event.actor_id != _log.fighter_ids[0]:
		a = _reflect(a)
		b = _reflect(b)
	var poses := {event.actor_id: a, event.target_id: b}
	if index > 0 and progress < 0.26:
		var entry_weight := progress / 0.26
		entry_weight = entry_weight * entry_weight * (3.0 - 2.0 * entry_weight)
		for id: String in _log.fighter_ids:
			poses[id] = _blend(_ends[index - 1][id], poses[id], entry_weight)
	for id: String in _log.fighter_ids:
		poses[id].facing = 1 if id == _log.fighter_ids[0] else -1
		poses[id].bend = [-poses[id].facing, poses[id].facing, poses[id].facing, poses[id].facing]
	return {"time": time, "event_index": index, "event": event.duplicate(true), "clip_id": clip.id, "progress": progress, "poses": poses, "state": (event.after if progress >= 1.0 else event.before).duplicate(true), "finished": time >= duration_ms, "result": _log.get("result", {}).duplicate(true) if time >= duration_ms and _log.get("result") is Dictionary else null}

static func _blend(a: Variant, b: Variant, t: float) -> Variant:
	if a is Dictionary:
		var result := {}
		for key: String in a:
			result[key] = _blend(a[key], b[key], t)
		return result
	if a is Array:
		var result: Array = []
		for i in a.size():
			result.append(_blend(a[i], b[i], t))
		return result
	return lerpf(float(a), float(b), t)

static func _reflect(pose: Dictionary) -> Dictionary:
	var out := pose.duplicate(true)
	out.root[0] *= -1
	out.lean *= -1
	out.head *= -1
	out.facing *= -1
	for key: String in ["hands", "feet"]:
		for point: Array in out[key]:
			point[0] *= -1
	for i in out.bend.size():
		out.bend[i] *= -1
	return out
