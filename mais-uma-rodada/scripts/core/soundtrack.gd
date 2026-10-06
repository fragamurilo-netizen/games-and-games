class_name Soundtrack
extends RefCounted
## Músicas de fundo do jogo. Compostas e geradas por tools/audio/gerar_trilha.py (notas escritas à
## mão, timbres sintetizados): nada de gravação ou música de terceiros. Se um arquivo faltar, o
## AudioManager cai na síntese antiga (MusicSynth).

const TRACKS: Array[String] = ["Dia de jogo", "Arquibancada", "Noite de final", "Vestiário", "Prancheta", "Todas, em sequência"]
const FILES: Array[String] = ["dia_de_jogo", "arquibancada", "noite_de_final", "vestiario", "prancheta"]
## Opção "Todas": toca uma faixa depois da outra.
const ROTATION := 5


static func load_track(i: int) -> AudioStream:
	if i < 0 or i >= FILES.size():
		return null
	var p := "res://assets/audio/musica/%s.ogg" % FILES[i]
	return load(p) if ResourceLoader.exists(p) else null
