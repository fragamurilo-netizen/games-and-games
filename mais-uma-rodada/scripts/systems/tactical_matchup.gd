class_name TacticalMatchup
extends RefCounted
## Confronto de ideias de jogo, igual nos dois motores (MatchSimulation e QuickMatch).
## Cada lado é descrito por: tech (qualidade com a bola sob pressão), mid (massa de meio-campo),
## pressing, style, mentality, line, width. Retorna quanto a posse pende para `a` e os
## multiplicadores da taxa de chances de cada lado. Valores moderados, quase simétricos:
##   - Meio-campo com mais gente fica mais com a bola (3 contra 2 no meio).
##   - Pressão alta contra quem sai mal jogando rouba bolas perto do gol; contra quem toca bem,
##     é driblada e deixa espaço atrás. A bola longa pula a pressão.
##   - Bloco baixo (retranca, linha baixa) tira chances de quem quer a bola; o contra-ataque dele
##     já é tratado pelo estilo.
##   - Time aberto contra time fechado por dentro acha os lados.


static func edges(a: Dictionary, b: Dictionary) -> Dictionary:
	var poss := 0.0
	var ra := 1.0
	var rb := 1.0
	# Meio-campo
	poss += clampf((float(a["mid"]) - float(b["mid"])) * 0.02, -0.03, 0.03)
	# Pressão contra saída de bola
	var pa := _press(a, b)
	var pb := _press(b, a)
	poss += pa[0] - pb[0]
	ra *= pa[1] * pb[2]
	rb *= pb[1] * pa[2]
	# Bloco baixo contra quem propõe
	if _low_block(b) and _proposes(a):
		ra *= 0.93
	if _low_block(a) and _proposes(b):
		rb *= 0.93
	# Amplitude contra time fechado
	if _wide(a) and int(b["width"]) == 0:
		ra *= 1.03
	if _wide(b) and int(a["width"]) == 0:
		rb *= 1.03
	return {"poss": poss, "rate_a": ra, "rate_b": rb}


## [posse para quem pressiona, chances de quem pressiona, chances do pressionado].
static func _press(p: Dictionary, r: Dictionary) -> Array:
	var presses := int(p["pressing"]) == 2 or int(p["style"]) == TeamSheet.STYLE_PRESSAO
	if not presses or int(r["style"]) == TeamSheet.STYLE_LONGA:
		return [0.0, 1.0, 1.0]
	# Pressionar funciona contra quem tem menos qualidade com a bola do que você (e não por um número
	# absoluto): o favorito que pressiona o fraco rouba bolas perto do gol; o fraco que pressiona um
	# time mais técnico é driblado e deixa espaço atrás.
	var edge := (float(p["tech"]) - float(r["tech"]) + 2.0) / 100.0
	if edge >= 0.0:
		return [minf(0.025, edge * 0.3), 1.0 + minf(0.07, edge * 0.7), 1.0]
	return [0.0, 1.0, 1.0 + minf(0.06, -edge * 0.6)]


static func _low_block(t: Dictionary) -> bool:
	return int(t["mentality"]) <= TeamSheet.MENT_DEFENSIVA and int(t["line"]) == 0


static func _proposes(t: Dictionary) -> bool:
	return int(t["style"]) == TeamSheet.STYLE_POSSE or int(t["mentality"]) >= TeamSheet.MENT_OFENSIVA


static func _wide(t: Dictionary) -> bool:
	return int(t["width"]) == 2 or int(t["style"]) == TeamSheet.STYLE_LADOS
