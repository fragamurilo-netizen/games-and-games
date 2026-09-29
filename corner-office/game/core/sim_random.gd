class_name SimRandom
extends RefCounted
## RNG determinístico da simulação. Todo sorteio de regra passa por aqui para
## que saves e testes sejam reproduzíveis a partir de uma seed.
## Nunca use randf()/randi() globais dentro de simulation/.

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func get_state() -> int:
	return _rng.state


func set_state(state: int) -> void:
	_rng.state = state


func chance(p: float) -> bool:
	return _rng.randf() < p


func range_f(a: float, b: float) -> float:
	return _rng.randf_range(a, b)


func range_i(a: int, b: int) -> int:
	return _rng.randi_range(a, b)


func normal(mean: float = 0.0, deviation: float = 1.0) -> float:
	return _rng.randfn(mean, deviation)


func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Sorteio ponderado. weights: { valor: peso }.
func weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for w in weights.values():
		total += float(w)
	var roll := _rng.randf() * total
	for key in weights:
		roll -= float(weights[key])
		if roll <= 0.0:
			return key
	return weights.keys().back()
