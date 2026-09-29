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
func score_round(_round_log: Dictionary, _rng: SimRandom) -> Array:
	# TODO(M1): pontuar por resultado ofensivo, não por volume bruto.
	return [10, 10]
