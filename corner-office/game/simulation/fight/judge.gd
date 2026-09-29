class_name Judge
extends RefCounted
## Judging Engine (MMA Bible §5, §21). Cada juiz lê o MESMO round_log e aplica
## o ruleset com pequenas diferenças de limiar. Controvérsia emerge de rounds
## apertados — nunca de "roubo = RNG".
##
## Critérios priorizados (Unified Rules): 1) striking/grappling efetivo;
## 2) agressividade efetiva (só se 1 empatar); 3) controle de área.

var impact_weight := 1.0
var grappling_result_weight := 1.0
var round_closeness_threshold := 0.1
var ten_eight_threshold := 0.6
var consistency := 0.9


static func random_profile(rng: SimRandom) -> Judge:
	var j := Judge.new()
	j.impact_weight = rng.range_f(0.9, 1.1)
	j.grappling_result_weight = rng.range_f(0.85, 1.15)
	j.round_closeness_threshold = rng.range_f(0.05, 0.15)
	j.ten_eight_threshold = rng.range_f(0.5, 0.7)
	j.consistency = rng.range_f(0.8, 0.98)
	return j


## Retorna [pontos_a, pontos_b] para um round, ex.: [10, 9].
func score_round(round_log: Dictionary, _rng: SimRandom) -> Array:
	var ids: Array = round_log.get("fighter_ids", [])
	if ids.size() != 2:
		return [10, 10]
	var a: Dictionary = round_log.stats[ids[0]]
	var b: Dictionary = round_log.stats[ids[1]]
	var effect_a: float = a.striking_impact * impact_weight + a.grappling_impact * grappling_result_weight
	var effect_b: float = b.striking_impact * impact_weight + b.grappling_impact * grappling_result_weight
	var difference := effect_a - effect_b
	# Fixed judge profiles can disagree about a close round. No random winner roll.
	if absf(difference) < 0.00001:
		difference = float(a.aggression - b.aggression) * 0.001
	if absf(difference) < 0.00001:
		difference = float(a.control_s - b.control_s) * 0.00001
	if absf(difference) < 0.00001:
		return [10, 10]
	var winner: Dictionary = a if difference > 0 else b
	var loser: Dictionary = b if difference > 0 else a
	var total := maxf(0.001,effect_a+effect_b)
	var separation := absf(effect_a-effect_b)/total
	var domination: float = winner.dominant_s/maxf(1.0,float(round_log.get("elapsed_s",300)))
	var losing_score := 9
	if separation > ten_eight_threshold and (maxf(effect_a,effect_b) > 0.35 or domination > .35 or winner.knockdowns > loser.knockdowns + 1):
		losing_score = 8
	if separation > .94 and domination > .80 and maxf(effect_a,effect_b) > 1.2:
		losing_score = 7
	return [10,losing_score] if difference > 0 else [losing_score,10]
