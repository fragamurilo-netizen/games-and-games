extends RefCounted
## Estatísticas de população usadas pelo relatório e pelos testes de realismo.


static func tier_of(world: WorldState, f: Fighter) -> String:
	if f.retired:
		return "retired"
	if f.organization_id.is_empty():
		return "circuit"
	return "flagship" if f.organization_id == world.player_org_id else "national"


static func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var t := 0.0
	for v in values:
		t += float(v)
	return t / values.size()


static func _sd(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var m := _mean(values)
	var t := 0.0
	for v in values:
		t += pow(float(v) - m, 2)
	return sqrt(t / (values.size() - 1))


static func _top(counts: Dictionary, n: int) -> Array:
	var keys: Array = counts.keys()
	keys.sort_custom(func(a, b): return counts[a] > counts[b] or (counts[a] == counts[b] and str(a) < str(b)))
	return keys.slice(0, n).map(func(k): return "%s %d" % [k, counts[k]])


static func summarize(world: WorldState) -> Dictionary:
	var tiers := {}
	var methods := {}
	var heights := {}
	for f: Fighter in world.fighters.values():
		var tier := tier_of(world, f)
		if not tiers.has(tier):
			tiers[tier] = {"ages": [], "bouts": [], "win_pct": [], "countries": {}, "bases": {}, "pops": {}, "women": 0, "divisions": {}, "undefeated": 0, "zero_bouts": 0, "max_wins": 0, "rating": []}
		var t: Dictionary = tiers[tier]
		var age := CareerModel.age_on(f, world.date)
		var bouts := CareerModel.pro_bouts(f)
		t.ages.append(age)
		t.bouts.append(bouts)
		t.rating.append(f.rating)
		if bouts > 0:
			t.win_pct.append(float(f.record.wins) / bouts)
		if bouts == 0:
			t.zero_bouts += 1
		elif int(f.record.losses) == 0:
			t.undefeated += 1
		t.max_wins = maxi(int(t.max_wins), int(f.record.wins))
		t.countries[f.country] = int(t.countries.get(f.country, 0)) + 1
		t.bases[f.martial_base] = int(t.bases.get(f.martial_base, 0)) + 1
		t.pops[f.appearance.get("pop", "?")] = int(t.pops.get(f.appearance.get("pop", "?"), 0)) + 1
		t.divisions[f.division] = int(t.divisions.get(f.division, 0)) + 1
		if f.sex == Fighter.Sex.FEMALE:
			t.women += 1
		if not methods.has(f.division):
			methods[f.division] = {"ko": 0, "sub": 0, "dec": 0}
		for k: String in ["ko", "sub", "dec"]:
			methods[f.division][k] += int(f.record.get(k + "_wins", 0))
		if not heights.has(f.division):
			heights[f.division] = []
		heights[f.division].append(f.height_cm)
	var out := {"tiers": {}, "finish_by_division": {}, "height_by_division": {}}
	for tier: String in tiers:
		var t: Dictionary = tiers[tier]
		out.tiers[tier] = {
			"count": t.ages.size(),
			"age_mean": snappedf(_mean(t.ages), 0.1), "age_sd": snappedf(_sd(t.ages), 0.1),
			"age_min": snappedf(t.ages.min(), 0.1), "age_max": snappedf(t.ages.max(), 0.1),
			"bouts_mean": snappedf(_mean(t.bouts), 0.1), "win_pct_mean": snappedf(_mean(t.win_pct), 0.01),
			"undefeated": t.undefeated, "zero_bouts": t.zero_bouts, "max_wins": t.max_wins,
			"rating_mean": roundi(_mean(t.rating)),
			"women_share": snappedf(float(t.women) / t.ages.size(), 0.01),
			"countries": t.countries.size(), "top_countries": _top(t.countries, 10),
			"bases": _top(t.bases, 10), "pops": _top(t.pops, 15), "divisions": t.divisions,
		}
	for d: String in methods:
		var m: Dictionary = methods[d]
		var total := maxf(1.0, m.ko + m.sub + m.dec)
		out.finish_by_division[d] = {"ko": snappedf(m.ko / total, 0.01), "sub": snappedf(m.sub / total, 0.01), "dec": snappedf(m.dec / total, 0.01)}
		out.height_by_division[d] = [snappedf(_mean(heights[d]), 0.1), snappedf(_sd(heights[d]), 0.1)]
	return out
