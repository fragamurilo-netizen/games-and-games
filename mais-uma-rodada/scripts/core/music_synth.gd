class_name MusicSynth
extends RefCounted
## Trilhas de fundo compostas e sintetizadas pelo próprio jogo (nenhum arquivo de áudio no APK,
## nada de licença de terceiros). Cada faixa é um loop de 16 compassos: acordes, baixo,
## bateria e uma melodia sorteada com semente fixa (sai sempre igual).
## A síntese é pesada para o GDScript, então roda numa thread e o resultado fica em cache.

const RATE := 22050
const TRACKS: Array[String] = ["Vestiário", "Arquibancada", "Noite de decisão"]
const BARS := 16

var _buf := PackedFloat32Array()
var _n := 0
var _beat := 0.5


## Gera a faixa `track` e devolve as amostras (mono, -1..1), prontas para tocar em loop.
func render(track: int) -> PackedFloat32Array:
	match track:
		1:
			_arquibancada()
		2:
			_noite()
		_:
			_vestiario()
	_master()
	return _buf


func _setup(bpm: float) -> void:
	_beat = 60.0 / bpm
	_n = int(round(_beat * 4.0 * BARS * RATE))
	_buf = PackedFloat32Array()
	_buf.resize(_n)


## Tempo (s) de um ponto da música: compasso, tempo e fração de tempo.
func _t(bar: int, beat: float) -> float:
	return (bar * 4.0 + beat) * _beat


static func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


# ---------------------------------------------------------------------------
# Faixas
# ---------------------------------------------------------------------------

## Lo-fi calmo em Fá maior, com swing: piano elétrico, baixo redondo e bateria abafada.
func _vestiario() -> void:
	_setup(84.0)
	var prog := [
		[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [48, 52, 55, 59],
		[46, 50, 53, 57], [45, 48, 52, 55], [43, 46, 50, 53], [48, 52, 55, 58],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	for bar in BARS:
		var ch: Array = prog[bar % prog.size()]
		for m in ch:
			_epiano(m + 12, _t(bar, 0.0), _beat * 1.6, 0.11)
			_epiano(m + 12, _t(bar, 2.5), _beat * 1.2, 0.07)
		_bass(ch[0] - 12, _t(bar, 0.0), _beat * 1.4, 0.34)
		_bass(ch[0] - 12, _t(bar, 2.5), _beat * 0.8, 0.26)
		_bass(ch[2] - 12, _t(bar, 3.5), _beat * 0.45, 0.2)
		_kick(_t(bar, 0.0), 0.5)
		_kick(_t(bar, 1.5 + 0.08), 0.28)
		_kick(_t(bar, 2.5), 0.42)
		_snare(_t(bar, 1.0), 0.16, true)
		_snare(_t(bar, 3.0), 0.16, true)
		for e in 8:
			var swing := 0.1 if e % 2 == 1 else 0.0
			_hat(_t(bar, e * 0.5 + swing), 0.05 if e % 2 == 0 else 0.03)
		# Melodia só na segunda metade: o loop "respira" antes de voltar ao começo.
		if bar >= 8:
			_melody(rng, bar, ch, [65, 67, 69, 72, 74, 76, 77], 0.1, 0.45)
	_vinyl(0.012)


## Samba-pop em Sol maior: surdo marcando o segundo tempo, ganzá em semicolcheias,
## cavaquinho (corda dedilhada) no balanço e baixo alternando tônica e quinta.
func _arquibancada() -> void:
	_setup(104.0)
	var prog := [
		[55, 59, 62, 67], [52, 55, 59, 64], [48, 52, 55, 60], [50, 54, 57, 62],
		[55, 59, 62, 67], [47, 50, 55, 59], [48, 52, 55, 60], [50, 54, 57, 60],
	]
	var strum := [0.0, 0.75, 1.5, 2.0, 2.75, 3.5]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for bar in BARS:
		var ch: Array = prog[bar % prog.size()]
		for k in strum.size():
			var accent := 0.085 if k % 3 == 0 else 0.06
			for i in ch.size():
				_pluck(ch[i] + 12, _t(bar, strum[k]) + i * 0.012, _beat * 0.6, accent, 0.62)
		_bass(ch[0] - 12, _t(bar, 0.0), _beat * 0.9, 0.34)
		_bass(ch[0] - 5, _t(bar, 2.0), _beat * 0.9, 0.3)
		_bass(ch[0] - 12, _t(bar, 3.5), _beat * 0.4, 0.22)
		_kick(_t(bar, 0.0), 0.35)
		_surdo(_t(bar, 1.0), 0.22)
		_surdo(_t(bar, 3.0), 0.45)
		_snare(_t(bar, 1.75), 0.08, true)
		_snare(_t(bar, 3.25), 0.07, true)
		for s in 16:
			_shaker(_t(bar, s * 0.25), 0.045 if s % 4 == 0 else (0.03 if s % 2 == 0 else 0.022))
		if bar >= 4:
			_melody(rng, bar, ch, [67, 69, 71, 74, 76, 79, 81], 0.07, 0.6, true)


## Tensão de noite de decisão em Lá menor: pad sustentado, arpejo em colcheias e bumbo reto.
func _noite() -> void:
	_setup(96.0)
	var prog := [
		[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62],
		[57, 60, 64], [53, 57, 60], [50, 53, 57], [52, 56, 59],
	]
	for bar in BARS:
		var ch: Array = prog[bar % prog.size()]
		for m in ch:
			_pad(m, _t(bar, 0.0), _beat * 4.0, 0.07)
		var arp := [ch[0] + 12, ch[1] + 12, ch[2] + 12, ch[1] + 24, ch[2] + 12, ch[1] + 12, ch[0] + 24, ch[2] + 12]
		for e in 8:
			_pluck(arp[e], _t(bar, e * 0.5), _beat * 0.9, 0.055 if bar < 4 else 0.075, 0.5)
		_bass(ch[0] - 12, _t(bar, 0.0), _beat * 1.8, 0.3)
		_bass(ch[0] - 12, _t(bar, 2.0), _beat * 1.8, 0.26)
		if bar >= 4:
			for b in 4:
				_kick(_t(bar, b), 0.36)
			for b in 4:
				_hat(_t(bar, b + 0.5), 0.035)
		if bar >= 8:
			_snare(_t(bar, 1.0), 0.1, false)
			_snare(_t(bar, 3.0), 0.1, false)


## Frase curta sobre o acorde: notas da escala, com preferência pelas do acorde.
func _melody(rng: RandomNumberGenerator, bar: int, chord: Array, scale: Array, vol: float, rest: float, pluck := false) -> void:
	var tones: Array = []
	for m in chord:
		tones.append(int(m) % 12)
	var b := 0.0
	var last: int = scale[rng.randi_range(0, scale.size() - 1)]
	while b < 4.0:
		var dur: float = [0.5, 0.5, 1.0, 1.5][rng.randi_range(0, 3)]
		if rng.randf() > rest:
			var cand: int = last
			for _try in 6:
				var i := clampi(scale.find(last) + rng.randi_range(-2, 2), 0, scale.size() - 1)
				cand = scale[i]
				if tones.has(cand % 12) or rng.randf() < 0.3:
					break
			last = cand
			if pluck:
				_pluck(last + 12, _t(bar, b), _beat * dur, vol, 0.7)
			else:
				_bell(last + 12, _t(bar, b), _beat * dur * 1.3, vol)
		b += dur


# ---------------------------------------------------------------------------
# Instrumentos: cada nota escreve só as próprias amostras (com volta ao início do loop).
# ---------------------------------------------------------------------------

func _add(i: int, v: float) -> void:
	var k := i % _n
	_buf[k] += v


func _epiano(midi: float, t0: float, dur: float, vol: float) -> void:
	var f := _hz(midi)
	var s0 := int(t0 * RATE)
	var n := int((dur + 0.25) * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.006) * exp(-t * 2.2)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / 0.25)
		var trem := 1.0 + 0.08 * sin(TAU * 4.5 * t)
		var w := TAU * f * t
		var s := sin(w) + 0.35 * sin(2.0 * w) * exp(-t * 6.0) + 0.1 * sin(3.0 * w) * exp(-t * 10.0)
		_add(s0 + i, s * env * vol * trem)


func _bell(midi: float, t0: float, dur: float, vol: float) -> void:
	var f := _hz(midi)
	var s0 := int(t0 * RATE)
	var n := int((dur + 0.4) * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 3.0)
		var w := TAU * f * t
		_add(s0 + i, (sin(w + 0.6 * sin(w * 2.0) * exp(-t * 4.0))) * env * vol)


func _pad(midi: float, t0: float, dur: float, vol: float) -> void:
	var f := _hz(midi)
	var s0 := int(t0 * RATE)
	var n := int((dur + 0.5) * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.6)
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / 0.5)
		var s := 0.0
		for d: float in [0.997, 1.0, 1.003]:
			var w := TAU * f * d * t
			s += sin(w) + 0.4 * sin(2.0 * w) + 0.18 * sin(3.0 * w)
		_add(s0 + i, s * env * vol * 0.33)


## Corda dedilhada (Karplus-Strong): cavaquinho, violão e arpejos.
func _pluck(midi: float, t0: float, dur: float, vol: float, bright: float) -> void:
	var f := _hz(midi)
	var period := maxi(2, int(RATE / f))
	var line := PackedFloat32Array()
	line.resize(period)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(midi * 1000.0 + t0 * 97.0)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var s0 := int(t0 * RATE)
	var n := int((dur + 0.15) * RATE)
	var idx := 0
	var prev := 0.0
	var damp := 0.5 * (0.985 + 0.013 * bright)
	for i in n:
		var cur := line[idx]
		var nxt := line[(idx + 1) % period]
		line[idx] = (cur + nxt) * damp
		var s := cur * (1.0 - (1.0 - bright) * 0.5) + prev * (1.0 - bright) * 0.5
		prev = cur
		idx = (idx + 1) % period
		var t := float(i) / RATE
		var env := 1.0 if t < dur else maxf(0.0, 1.0 - (t - dur) / 0.15)
		_add(s0 + i, s * env * vol)


func _bass(midi: float, t0: float, dur: float, vol: float) -> void:
	var f := _hz(midi)
	var s0 := int(t0 * RATE)
	var n := int((dur + 0.08) * RATE)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.008) * (0.55 + 0.45 * exp(-t * 5.0))
		if t > dur:
			env *= maxf(0.0, 1.0 - (t - dur) / 0.08)
		var w := TAU * f * t
		_add(s0 + i, (sin(w) + 0.25 * sin(2.0 * w)) * env * vol)


func _kick(t0: float, vol: float) -> void:
	var s0 := int(t0 * RATE)
	var n := int(0.32 * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 45.0 + 85.0 * exp(-t * 28.0)
		ph += TAU * f / RATE
		_add(s0 + i, sin(ph) * exp(-t * 9.0) * vol)


func _surdo(t0: float, vol: float) -> void:
	var s0 := int(t0 * RATE)
	var n := int(0.5 * RATE)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 62.0 + 30.0 * exp(-t * 18.0)
		ph += TAU * f / RATE
		_add(s0 + i, (sin(ph) + 0.3 * sin(ph * 2.02)) * exp(-t * 5.5) * vol)


func _snare(t0: float, vol: float, rim: bool) -> void:
	var s0 := int(t0 * RATE)
	var n := int((0.08 if rim else 0.18) * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t0 * 1000.0) + 7
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.35
		var noise := (x - lp) * (0.6 if rim else 1.0)
		var tone := sin(TAU * (330.0 if rim else 190.0) * t) * (0.6 if rim else 0.4)
		_add(s0 + i, (noise * exp(-t * (40.0 if rim else 18.0)) + tone * exp(-t * 30.0)) * vol)


func _hat(t0: float, vol: float) -> void:
	var s0 := int(t0 * RATE)
	var n := int(0.05 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t0 * 1000.0) + 13
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.6
		_add(s0 + i, (x - lp) * exp(-t * 70.0) * vol)


func _shaker(t0: float, vol: float) -> void:
	var s0 := int(t0 * RATE)
	var n := int(0.07 * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t0 * 1000.0) + 29
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.5
		var env := minf(1.0, t / 0.015) * exp(-t * 45.0)
		_add(s0 + i, (x - lp) * env * vol)


## Chiado leve de vinil para o clima lo-fi.
func _vinyl(vol: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var lp := 0.0
	for i in _n:
		var x := rng.randf_range(-1.0, 1.0)
		lp += (x - lp) * 0.2
		var crackle := 0.0
		if rng.randf() < 0.0004:
			crackle = rng.randf_range(-6.0, 6.0)
		_buf[i] += (lp + crackle) * vol


## Normaliza e suaviza os picos (saturação leve), deixando espaço para os efeitos sonoros.
func _master() -> void:
	var peak := 0.0001
	for i in _n:
		peak = maxf(peak, absf(_buf[i]))
	var g := 1.6 / peak
	var lp := 0.0
	for i in _n:
		var v := tanh(_buf[i] * g) * 0.55
		lp += (v - lp) * 0.55 # tira o chiado mais agudo da síntese
		_buf[i] = lp
