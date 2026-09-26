class_name CrowdSynth
extends RefCounted
## Torcida sintetizada (nenhum arquivo de áudio): um loop de 4 compassos com o "chão" de vozes,
## a bateria e os cantos no jeito de cada cultura de arquibancada, e a variação de cada clube
## (andamento, tom e melodia do canto saem do id dele). Só faz conta: roda numa thread.
##
## Estilos:
##   samba    — batucada: surdo, caixa em semicolcheias e tamborim sincopado; canto agudo contínuo
##   hinchada — bombo e prato, trompetes e canto forte sem parar (Argentina, Uruguai, Chile...)
##   terrace  — palmas "clap-clap-clap" e cânticos em rajadas, sem bateria (Inglaterra, Escócia)
##   ultras   — tambor grave lento, apitos e coro médio (Itália, Turquia, Grécia, Portugal...)
##   curva    — tambor em todos os tempos e o "hey!" grave e organizado (Alemanha, Holanda...)
##   taiko    — tambores taiko, palmas marcadas e trompete de banda (Japão, Coreia, China)
##   africa   — polirritmia, chocalho e cornetas (vuvuzela na África do Sul)
##   banda    — banda com trompete e o "uuuh" (México, EUA, Canadá)

const RATE := 22050
const FADE := 0.3 # s de emenda do loop

const PENTA := [0, 2, 4, 7, 9, 12, 14] # escala pentatônica maior (semitons)


static func render(prof: Dictionary) -> PackedFloat32Array:
	var bpm := float(prof.get("bpm", 110.0))
	var beat := 60.0 / bpm
	var loop_s := beat * 16.0
	var n := int(loop_s * RATE)
	var f := int(FADE * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n + f)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(prof.get("seed", 1))
	var style := String(prof.get("style", "terrace"))
	var pitch := float(prof.get("pitch", 210.0))
	var leg := float(prof.get("legato", 1.0))
	var sing := float(prof.get("sing", 1.0)) # volume do canto
	_bed(buf, rng, 0.22, loop_s)
	match style:
		"samba":
			_pattern(buf, beat, [0, 8], "surdo", 0.5)
			_pattern(buf, beat, [4, 12], "surdo", 0.75)
			_pattern(buf, beat, range(16), "caixa", 0.1)
			_pattern(buf, beat, [2, 6, 10, 14], "caixa", 0.16)
			_pattern(buf, beat, [0, 3, 6, 10, 12], "tamborim", 0.16)
			_chant(buf, rng, beat, pitch * 1.12, 0.3 * sing, [0, 2], 1.0 * leg)
		"hinchada":
			_pattern(buf, beat, [0, 3, 6, 8, 11, 14], "bombo", 0.65)
			_pattern(buf, beat, [4, 12], "prato", 0.18)
			_chant(buf, rng, beat, pitch, 0.34 * sing, [0, 2], 1.0 * leg)
			_trumpet(buf, rng, beat, pitch * 2.0, 0.12, [0, 2])
		"terrace":
			_pattern(buf, beat, [0, 4, 8], "palma", 0.42, [0, 2])
			_chant(buf, rng, beat, pitch * 0.92, 0.36 * sing, [2], 0.8 * leg)
		"ultras":
			_pattern(buf, beat, [0, 8], "bombo", 0.75)
			_pattern(buf, beat, [4, 12], "bombo", 0.35)
			_chant(buf, rng, beat, pitch, 0.3 * sing, [0, 2], 0.9 * leg)
			_whistles(buf, rng, loop_s, float(prof.get("whistle", 0.3)))
		"curva":
			_pattern(buf, beat, [0, 4, 8, 12], "bombo", 0.6)
			_chant(buf, rng, beat, pitch * 0.8, 0.32 * sing, [0, 2], 1.0 * leg)
			_hey(buf, beat, pitch * 0.7, [1, 3])
		"taiko":
			_pattern(buf, beat, [0, 6, 8, 12], "taiko", 0.7)
			_pattern(buf, beat, [4, 12], "palma", 0.3)
			_chant(buf, rng, beat, pitch * 1.05, 0.26 * sing, [0, 2], 0.7 * leg)
			_trumpet(buf, rng, beat, pitch * 2.2, 0.12, [1, 3])
		"africa":
			_pattern(buf, beat, [0, 3, 6, 8, 10, 13], "bombo", 0.5)
			_pattern(buf, beat, range(16), "chocalho", 0.08)
			_chant(buf, rng, beat, pitch * 1.05, 0.28 * sing, [0, 2], 1.0 * leg)
			if bool(prof.get("vuvuzela", false)):
				_vuvuzela(buf, rng, 0.1)
		"banda":
			_pattern(buf, beat, [0, 8], "bombo", 0.5)
			_trumpet(buf, rng, beat, pitch * 2.0, 0.14, [0, 1, 2, 3])
			_chant(buf, rng, beat, pitch, 0.24 * sing, [2], 0.9 * leg)
	# Emenda: o fim continua o começo, sem estalo no loop
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = buf[i]
	for i in f:
		var a := float(i) / f
		out[i] = buf[i] * a + buf[n + i] * (1.0 - a)
	var peak := 0.001
	for v in out:
		peak = maxf(peak, absf(v))
	var k := 0.85 / peak
	for i in n:
		out[i] *= k
	return out


## Chão de vozes: ruído passado em dois filtros, respirando no ritmo do loop.
static func _bed(buf: PackedFloat32Array, rng: RandomNumberGenerator, vol: float, loop_s: float) -> void:
	var lp := 0.0
	var lp2 := 0.0
	for i in buf.size():
		var t := float(i) / RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.16
		lp2 += (lp - lp2) * 0.16
		var sw := 0.8 + 0.2 * sin(TAU * t * 2.0 / loop_s) + 0.08 * sin(TAU * t * 7.0 / loop_s)
		buf[i] += lp2 * 3.0 * vol * sw


## Batida nos passos (16 por compasso, 4 compassos). `bars` limita a alguns compassos.
static func _pattern(buf: PackedFloat32Array, beat: float, steps: Array, kind: String, vol: float, bars: Array = [0, 1, 2, 3]) -> void:
	var step := beat / 4.0
	for bar in bars:
		for s in steps:
			var at := int((float(bar) * 16.0 * step + float(s) * step) * RATE)
			_hit(buf, at, kind, vol)


static func _hit(buf: PackedFloat32Array, at: int, kind: String, vol: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = at * 31 + kind.length()
	var dur := 0.2
	match kind:
		"surdo":
			dur = 0.45
		"bombo", "taiko":
			dur = 0.5
		"caixa", "chocalho":
			dur = 0.09
		"tamborim":
			dur = 0.06
		"prato":
			dur = 0.6
		"palma":
			dur = 0.14
	var n := int(dur * RATE)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var j := at + i
		if j >= buf.size():
			return
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"surdo":
				ph += TAU * lerpf(95.0, 62.0, minf(1.0, t / 0.12)) / RATE
				v = sin(ph) * exp(-t * 7.0)
			"bombo":
				ph += TAU * lerpf(120.0, 55.0, minf(1.0, t / 0.08)) / RATE
				v = sin(ph) * exp(-t * 9.0) + rng.randf_range(-0.3, 0.3) * exp(-t * 60.0)
			"taiko":
				ph += TAU * lerpf(90.0, 48.0, minf(1.0, t / 0.1)) / RATE
				v = sin(ph) * exp(-t * 5.0) + rng.randf_range(-0.4, 0.4) * exp(-t * 40.0)
			"caixa", "chocalho":
				var x := rng.randf_range(-1.0, 1.0)
				lp += (x - lp) * 0.5
				v = (x - lp) * exp(-t * (38.0 if kind == "caixa" else 55.0))
			"tamborim":
				ph += TAU * 1250.0 / RATE
				v = sin(ph) * exp(-t * 60.0)
			"prato":
				var x2 := rng.randf_range(-1.0, 1.0)
				lp += (x2 - lp) * 0.7
				v = (x2 - lp) * 0.6 * exp(-t * 6.0)
			"palma":
				# Várias mãos: três estalos em 25 ms
				var x3 := rng.randf_range(-1.0, 1.0)
				lp += (x3 - lp) * 0.35
				var e := exp(-t * 30.0) + 0.7 * exp(-maxf(0.0, t - 0.012) * 34.0) * float(t > 0.012) + 0.5 * exp(-maxf(0.0, t - 0.025) * 36.0) * float(t > 0.025)
				v = lp * 1.8 * e
		buf[j] += v * vol


## Canto: melodia pentatônica do clube (sai do seed) em frases de dois compassos, três vozes
## levemente desafinadas, vibrato e o ar da multidão. `phrases` são os compassos onde cada frase
## começa (0 e/ou 2); `legato` alonga ou encurta as notas.
static func _chant(buf: PackedFloat32Array, rng: RandomNumberGenerator, beat: float, base: float, vol: float, phrases: Array, legato: float) -> void:
	var motif: Array = []
	var durs: Array = []
	var total := 0.0
	while total < 8.0:
		var d: float = [1.0, 1.0, 2.0, 0.5, 1.5][rng.randi_range(0, 4)]
		d = minf(d, 8.0 - total)
		motif.append(PENTA[rng.randi_range(0, PENTA.size() - 1)])
		durs.append(d)
		total += d
	var detune := [1.0, 1.012, 0.989]
	for bar in phrases:
		var off := float(bar) * 4.0
		for k in motif.size():
			var freq: float = base * pow(2.0, float(motif[k]) / 12.0)
			var at := int(off * beat * RATE)
			var n := int(float(durs[k]) * beat * legato * RATE)
			var dur := float(n) / RATE
			var phs := [0.0, 0.0, 0.0]
			var lp := 0.0
			for i in n:
				var j := at + i
				if j >= buf.size():
					break
				var t := float(i) / RATE
				var env := minf(1.0, t / 0.06) * minf(1.0, (dur - t) / 0.08)
				var vib := 1.0 + 0.006 * sin(TAU * 5.2 * t)
				var s := 0.0
				for vi in 3:
					phs[vi] += TAU * freq * float(detune[vi]) * vib / RATE
					var p: float = phs[vi]
					s += sin(p) + 0.45 * sin(2.0 * p) + 0.2 * sin(3.0 * p)
				lp += (s - lp) * 0.35 # suaviza: vozes, não sintetizador
				buf[j] += (lp * 0.22 + rng.randf_range(-0.12, 0.12)) * env * vol
			off += float(durs[k])


## "Hey!" grave e curto no fim de um compasso (curva alemã).
static func _hey(buf: PackedFloat32Array, beat: float, base: float, bars: Array) -> void:
	for bar in bars:
		var at := int((float(bar) * 4.0 + 3.0) * beat * RATE)
		var n := int(0.28 * RATE)
		var ph := 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = at
		for i in n:
			var j := at + i
			if j >= buf.size():
				break
			var t := float(i) / RATE
			ph += TAU * base * (1.0 - t * 0.4) / RATE
			var env := minf(1.0, t / 0.02) * exp(-t * 7.0)
			buf[j] += (sin(ph) + 0.6 * sin(2.0 * ph) + rng.randf_range(-0.5, 0.5)) * env * 0.5


static func _trumpet(buf: PackedFloat32Array, rng: RandomNumberGenerator, beat: float, base: float, vol: float, bars: Array) -> void:
	var notes: Array = []
	for i in 6:
		notes.append(PENTA[rng.randi_range(0, 4)])
	for bar in bars:
		for k in notes.size():
			var at := int((float(bar) * 4.0 + float(k) * 0.5) * beat * RATE)
			var n := int(beat * 0.45 * RATE)
			var freq: float = base * pow(2.0, float(notes[k]) / 12.0)
			var ph := 0.0
			for i in n:
				var j := at + i
				if j >= buf.size():
					break
				var t := float(i) / RATE
				ph += TAU * freq / RATE
				var env := minf(1.0, t / 0.015) * minf(1.0, (float(n) / RATE - t) / 0.04)
				var s := sin(ph) + 0.5 * sin(2.0 * ph) + 0.35 * sin(3.0 * ph) + 0.2 * sin(4.0 * ph) + 0.12 * sin(5.0 * ph)
				buf[j] += s * env * vol


## Apitos agudos espalhados (ultras; a Turquia apita muito mais).
static func _whistles(buf: PackedFloat32Array, rng: RandomNumberGenerator, loop_s: float, amount: float) -> void:
	var count := int(amount * 12.0)
	for w in count:
		var at := int(rng.randf_range(0.0, loop_s - 0.8) * RATE)
		var n := int(rng.randf_range(0.3, 0.8) * RATE)
		var f0 := rng.randf_range(2400.0, 3300.0)
		var ph := 0.0
		for i in n:
			var j := at + i
			if j >= buf.size():
				break
			var t := float(i) / RATE
			ph += TAU * (f0 + sin(TAU * 26.0 * t) * 140.0) / RATE
			var env := minf(1.0, t / 0.03) * minf(1.0, (float(n) / RATE - t) / 0.06)
			buf[j] += sin(ph) * env * 0.05


## Vuvuzela: zumbido contínuo em Si bemol com batimento de várias cornetas.
static func _vuvuzela(buf: PackedFloat32Array, rng: RandomNumberGenerator, vol: float) -> void:
	var ph := [0.0, 0.0, 0.0]
	var fr := [233.0, 235.5, 231.2]
	for i in buf.size():
		var s := 0.0
		for k in 3:
			ph[k] += TAU * float(fr[k]) / RATE
			var p: float = ph[k]
			s += sin(p) + 0.6 * sin(2.0 * p) + 0.4 * sin(3.0 * p)
		buf[i] += s * vol * 0.33


## PCM de 16 bits pronto para o AudioStreamWAV (feito na thread, junto com o render).
static func to_pcm16(samples: PackedFloat32Array) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	return data
