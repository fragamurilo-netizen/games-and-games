class_name RngUtil
extends RefCounted
## Utilidades de aleatoriedade SEMPRE baseadas em um RandomNumberGenerator explícito.
## Nunca use randi()/randf()/Array.shuffle()/pick_random() globais na simulação:
## eles quebram o determinismo por seed.


static func chance(rng: RandomNumberGenerator, p: float) -> bool:
	return rng.randf() < p


static func pick(rng: RandomNumberGenerator, arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


## Retorna um índice sorteado proporcionalmente aos pesos (pesos <= 0 nunca são sorteados).
static func weighted_index(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for w in weights:
		if w > 0.0:
			total += w
	if total <= 0.0:
		return -1
	var r := rng.randf() * total
	for i in weights.size():
		var w: float = weights[i]
		if w <= 0.0:
			continue
		r -= w
		if r <= 0.0:
			return i
	# Arredondamento: último peso positivo.
	for i in range(weights.size() - 1, -1, -1):
		if weights[i] > 0.0:
			return i
	return -1


## Sorteia uma chave de um dicionário {chave: peso}.
static func weighted_key(rng: RandomNumberGenerator, table: Dictionary) -> Variant:
	var keys := table.keys()
	var weights: Array = []
	for k in keys:
		weights.append(float(table[k]))
	var i := weighted_index(rng, weights)
	return keys[i] if i >= 0 else null


## Fisher-Yates determinístico (in-place).
static func shuffle(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Normal truncada: média, desvio e limites.
static func gauss(rng: RandomNumberGenerator, mean: float, sd: float, lo: float = -INF, hi: float = INF) -> float:
	return clampf(rng.randfn(mean, sd), lo, hi)


static func range_i(rng: RandomNumberGenerator, lo: int, hi: int) -> int:
	return rng.randi_range(lo, hi)


static func range_f(rng: RandomNumberGenerator, lo: float, hi: float) -> float:
	return rng.randf_range(lo, hi)


## Hash estável de inteiros (para ruídos "fixos" por jogador que não consomem o RNG do mundo).
static func hash_i(a: int, b: int = 0, c: int = 0) -> int:
	var h := a * 73856093 ^ b * 19349663 ^ c * 83492791
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


## Ruído determinístico em [-1, 1] a partir de inteiros.
static func noise(a: int, b: int = 0, c: int = 0) -> float:
	return float(hash_i(a, b, c) % 20001) / 10000.0 - 1.0
