class_name TacticalMatchup
extends RefCounted
## Symmetric, bounded tactical interactions. No score, user flag or future RNG is consulted.
## Values are game-model calibration, not measured real-world probabilities.

static func edges(a: Dictionary, b: Dictionary) -> Dictionary:
	var pa := _press(a, b)
	var pb := _press(b, a)
	var ra := float(pa[1]) * float(pb[2]) * _space(a, b)
	var rb := float(pb[1]) * float(pa[2]) * _space(b, a)
	var poss := clampf((_v(a, "mid", 4.0) - _v(b, "mid", 4.0)) * 0.018, -0.035, 0.035)
	poss += float(pa[0]) - float(pb[0])
	return {"poss": clampf(poss, -0.09, 0.09), "rate_a": clampf(ra, 0.76, 1.28), "rate_b": clampf(rb, 0.76, 1.28)}

static func _v(d: Dictionary, key: String, fallback: float = 60.0) -> float:
	return float(d.get(key, fallback))

static func _press(p: Dictionary, r: Dictionary) -> Array:
	var presses := int(p.get("pressing", 1)) == 2 or int(p.get("style", 0)) in [3, 7]
	if not presses:
		return [0.0, 1.0, 1.0]
	var condition := _v(p, "condition", 90.0)
	var work := _v(p, "stamina") * 0.35 + _v(p, "decision") * 0.2 + _v(p, "cohesion", 60.0) * 0.15 + condition * 0.3
	var escape := _v(r, "tech") * 0.65 + _v(r, "decision") * 0.35
	var edge := clampf((work - escape) / 100.0, -0.38, 0.38)
	var direct := int(r.get("style", 0)) in [5, 10] or int(r.get("passing", 1)) == 2
	var tired := clampf((72.0 - condition) / 100.0, 0.0, 0.45)
	var recovery := maxf(0.0, edge) * (0.12 if direct else 0.38)
	var exposure := maxf(0.0, -edge) * 0.4 + tired * 0.35
	return [clampf(edge * (0.025 if direct else 0.09) - tired * 0.025, -0.035, 0.035),
		1.0 + recovery - tired * 0.18, 1.0 + exposure]

static func _space(a: Dictionary, b: Dictionary) -> float:
	var rate := 1.0
	var style := int(a.get("style", 0))
	var line := int(b.get("line", 1))
	var runs := clampf((_v(a, "pace_att") - _v(b, "pace_def")) / 80.0, -0.3, 0.3)
	var supply := clampf((_v(a, "tech") + _v(a, "decision")) / 140.0, 0.35, 1.2)
	# A high line gives up space only if runners and passers can exploit it.
	if line == 2:
		rate *= 1.0 + runs * supply * (0.65 if style in [1, 2, 8, 9] else 0.4)
	if style in [4, 5, 10]:
		var aerial := clampf((_v(a, "aerial_att") - _v(b, "aerial_def")) / 90.0, -0.22, 0.22)
		rate *= 1.0 + aerial * (0.65 if style in [5, 10] else 0.42)
	if _low_block(b):
		if style in [2, 8, 9]:
			rate *= 0.94 # there is no open field simply because the button says counterattack
		elif style in [0, 6, 11, 12]:
			var invention := (_v(a, "tech") + _v(a, "decision")) * 0.5 - _v(b, "decision")
			rate *= clampf(0.95 + invention * 0.0035, 0.87, 1.1)
	if _wide(a) and int(b.get("width", 1)) == 0:
		rate *= clampf(1.02 + (_v(a, "tech") - _v(b, "pace_def")) * 0.0015, 0.97, 1.08)
	# Patient build-up needs players who can actually retain the ball.
	if style in [6, 11, 12]:
		rate *= clampf(1.0 + (_v(a, "tech") - 65.0) * 0.002, 0.92, 1.055)
	if style == 7 and _v(a, "condition", 90.0) < 70.0:
		rate *= 0.94
	return clampf(rate, 0.82, 1.2)

static func _low_block(t: Dictionary) -> bool:
	return int(t.get("mentality", 2)) <= 1 and int(t.get("line", 1)) == 0

static func _proposes(t: Dictionary) -> bool:
	return int(t.get("style", 0)) in [0, 6, 11, 12] or int(t.get("mentality", 2)) >= 3

static func _wide(t: Dictionary) -> bool:
	return int(t.get("width", 1)) == 2 or int(t.get("style", 0)) in [4, 9]
