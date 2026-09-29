class_name TalentAssessment
extends RefCounted
## Observable projection, deliberately independent of the hidden development ceiling.
static func projection(p: Player, year: int) -> Dictionary:
	var age := p.age(year)
	var exposure := clampf(float(p.stats[Player.S_MINUTES]) / 2200.0, 0.0, 1.0)
	var growth_seen := clampf(float(p.overall - p.ovr_start), -2.0, 5.0)
	var headroom := maxf(0.0, 25.0 - age) * 0.68
	var current_form := clampf(p.form() - 6.6, -0.8, 0.8) * exposure
	var center := p.ovr_f + headroom + growth_seen * 0.5 + current_form
	var uncertainty := clampf((25.0 - age) * 0.65 + 2.0 - exposure * 2.0, 1.0, 10.0)
	return {"low": clampf(center - uncertainty, p.ovr_f - 3.0, 96.0),
		"high": clampf(center + uncertainty, p.ovr_f, 98.0), "center": clampf(center, 1.0, 96.0),
		"confidence": 0.35 + 0.55 * exposure, "uncertainty": uncertainty}

static func growth_environment(p: Player, minutes: int) -> float:
	if p.injury_weeks > 0:
		return 0.12 # rehabilitation is not a normal training week
	var professional := clampf(0.78 + p.hid("pro") * 0.022, 0.78, 1.22)
	var fatigue := clampf((p.condition - 30.0) / 65.0, 0.45, 1.0)
	var opportunity := 1.0
	if minutes == 0:
		opportunity = 0.86
	return clampf(professional * fatigue * opportunity, 0.3, 1.22)
