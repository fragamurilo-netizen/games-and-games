class_name Parallel
extends RefCounted
## Divide um trabalho independente por item (um jogador, um bloco do save) entre os núcleos do
## aparelho. `fn(de, até)` processa os itens [de, até) e devolve um Array; os resultados voltam
## juntos na ordem dos itens, então o resultado é o mesmo com 1 ou 8 núcleos.
## Regra para quem usa: `fn` só pode ler dados compartilhados (dados do jogo, outros objetos) e
## escrever no que é só daquele item. Caches preguiçosos precisam ser aquecidos antes.

## Threads no máximo (o celular também precisa de um núcleo para a tela e o som).
const MAX_THREADS := 6


static func threads_for(count: int, min_chunk: int) -> int:
	if count < min_chunk * 2 or not OS.has_feature("threads"):
		return 1
	return clampi(mini(OS.get_processor_count() - 1, count / min_chunk), 1, MAX_THREADS)


## Roda `fn` em pedaços contíguos e devolve a concatenação dos Arrays que ela retornar.
static func map_chunks(count: int, fn: Callable, min_chunk: int = 256) -> Array:
	var n := threads_for(count, min_chunk)
	if n <= 1:
		var only: Variant = fn.call(0, count)
		return only if only is Array else []
	var size := ceili(float(count) / n)
	var threads: Array = []
	for i in range(1, n):
		var a := i * size
		var b := mini(count, a + size)
		if a >= b:
			break
		var t := Thread.new()
		t.start(fn.bind(a, b))
		threads.append(t)
	var out: Array = []
	var first: Variant = fn.call(0, mini(count, size)) # o primeiro pedaço roda aqui mesmo
	if first is Array:
		out.append_array(first)
	for t: Thread in threads:
		var r: Variant = t.wait_to_finish()
		if r is Array:
			out.append_array(r)
	return out
