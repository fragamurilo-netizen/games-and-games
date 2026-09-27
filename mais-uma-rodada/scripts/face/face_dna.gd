class_name FaceDNA
extends RefCounted
## DNA facial determinístico: semente + etnia + idade (+ ajustes do editor) → traços do rosto.
## O mesmo jogador tem sempre o mesmo DNA e, portanto, o mesmo retrato em todas as telas.
##
## O dicionário é gerado por FaceGen.features (formato, olhos, nariz, boca, cabelo, barba, pele,
## idade) e refinado por FaceVariation (anatomia correlacionada e assimetria). Saves antigos
## guardam só face_seed/eth/idade, então tudo continua derivável do jogador (nenhum dado novo
## no save).
##
## `landmarks` é a única fonte das posições do rosto (o PortraitView desenha com elas e o
## validador confere com elas); `validate` aponta combinações impossíveis; `vector` resume a
## estrutura do rosto para medir diversidade.

## Versão do gerador: entra na chave dos caches de retrato; subir quando o desenho mudar.
const VERSION := 3


static func from_seed(seed_value: int, eth: int, age: int, look: Dictionary = {}) -> Dictionary:
	return FaceGen.features(seed_value, eth, age, look)


static func from_player(p: Player, year: int) -> Dictionary:
	return FaceGen.features(p.face_seed, p.eth, p.age(year), p.look)


## Marcos do rosto em unidades normalizadas (u = x / fw a partir do centro da cabeça, v = y / fh;
## v = -1,02 no alto do crânio, 0 no meio, ~1 no queixo). E = olhos, X = meia distância entre os
## olhos, N = base do nariz, M = boca; NW/BW/MW = larguras do nariz, do dorso e meia boca.
static func landmarks(f: Dictionary) -> Dictionary:
	var hl := float(f["hairline"])
	var H := 1.0 - hl
	var E := hl + H * 0.43 + (float(f["eye_y"]) + 0.02) * 0.5
	var N := E + H * 0.26 * (float(f["nose_len"]) / 0.305)
	return {
		"E": E,
		"X": float(f["eye_dx"]) * 1.02,
		"dE": (E - float(f["eye_y"])) * 0.8,
		"N": N,
		"M": N + H * 0.105 * (1.0 + (float(f["mouth_y"]) - 0.58) * 2.0),
		"NW": float(f["nose_w"]) * 1.5,
		"BW": float(f["bridge_w"]) * 1.1,
		"MW": float(f["mouth_w"]) * 1.25,
		"vb": 1.0 + float(f.get("chin_len", 0.0)),
	}


## Até onde o cabelo pode subir, a partir do centro do retrato (o círculo tem raio 0,5): um
## black power alto pode ser cortado pela borda, como numa foto de ficha, mas não passa disso.
const HAIR_TOP_MAX := 0.58


## Topo do cabelo em unidades do retrato (0 = centro, 0,5 = borda do círculo), com as mesmas contas
## do PortraitView: calota (volume de cima do penteado) e volume de trás (black power).
static func hair_top(f: Dictionary) -> float:
	var style := clampi(int(f["style"]), 0, PortraitView.STYLE_P.size() - 1)
	var sp: Dictionary = PortraitView.STYLE_P[style]
	var vol := float(f.get("vol", 0.5))
	var fh := float(f["fh"]) * PortraitView.HEAD_SCALE
	var fw := float(f["fw"]) * PortraitView.HEAD_SCALE * PortraitView.HEAD_W
	var thin: bool = String(sp.get("tx", "")) in ["dots", "braid", "braid_zig", "waves"] or int(sp.get("fd", 0)) == 3
	var tp := (float(sp.get("tp", 0.08)) + (0.0 if thin else 0.07)) * (0.85 + vol * 0.3)
	var top := 0.1 + (1.03 + tp) * fh
	if String(sp.get("bk", "")) == "afro":
		var r := (1.5 + vol * 0.2) * float(sp.get("ar", 1.0))
		top = maxf(top, 0.1 + 0.32 * fh + 0.95 * r * fw)
	return top


## Problemas de anatomia (lista vazia = rosto plausível). Confere olhos sobrepostos ou fora do
## rosto, nariz fora do lugar, boca encostando no nariz, orelhas fora da cabeça, escalas e cores
## inválidas e a sombra do nariz acima do limite.
static func validate(f: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var lm := landmarks(f)
	var E: float = lm["E"]
	var X: float = lm["X"]
	var N: float = lm["N"]
	var M: float = lm["M"]
	var NW: float = lm["NW"]
	var MW: float = lm["MW"]
	var cw := float(f["cheek_w"])
	var ew := float(f["eye_w"])
	var eh := float(f["eye_h"]) * 1.1
	var fw := float(f["fw"])
	var fh := float(f["fh"])
	for key in ["fw", "fh", "cheek_w", "eye_w", "eye_h", "nose_w", "nose_len", "mouth_w", "lip_u", "lip_l", "ear"]:
		if float(f[key]) <= 0.0:
			out.append("escala negativa ou zero: %s" % key)
	if fw / fh < 0.62 or fw / fh > 0.9:
		out.append("proporção largura/altura fora do humano (%.2f)" % (fw / fh))
	# Olhos: não se sobrepõem, não encostam no nariz, não saem do rosto, não sobem na testa
	if X - ew < 0.06:
		out.append("olhos sobrepostos ou colados (canto interno a %.3f)" % (X - ew))
	if X + ew > cw * 1.0:
		out.append("olho fora do rosto (canto externo %.2f > %.2f)" % [X + ew, cw])
	if E < -0.25 or E > 0.2:
		out.append("olhos fora da altura (E = %.2f)" % E)
	if eh * 1.52 / (2.0 * ew) > 0.55:
		out.append("olho redondo demais (abertura/largura %.2f)" % (eh * 1.52 / (2.0 * ew)))
	# Nariz: entre os olhos e a boca, mais estreito que a distância entre as pupilas
	if N - E < 0.24 or N - E > 0.6:
		out.append("nariz com comprimento impossível (%.2f)" % (N - E))
	if NW * 0.8 > X * 1.05:
		out.append("nariz mais largo que a distância dos olhos")
	# Boca: abaixo do nariz (o lábio de cima não encosta na base do nariz) e dentro do rosto
	var lip_top := M - float(f["lip_u"]) * 1.7
	if lip_top - N < FaceVariation.PHILTRUM_MIN - 0.005:
		out.append("boca encostando no nariz (folga %.3f)" % (lip_top - N))
	if MW > cw * 0.62:
		out.append("boca mais larga que o rosto")
	if M + float(f["lip_l"]) * 1.55 > float(lm["vb"]) - (FaceVariation.CHIN_MIN - 0.005):
		out.append("boca baixa demais (sem queixo)")
	# Orelhas
	if float(f["ear"]) > 1.3 or float(f.get("ear_out", 0.0)) > 1.25:
		out.append("orelha fora da cabeça")
	# Cabelo: o volume pode encostar na borda do retrato (como numa foto), mas não sair dele
	var top := hair_top(f)
	if top > HAIR_TOP_MAX:
		out.append("cabelo fora do retrato (topo a %.2f)" % top)
	# Cores
	for key in ["skin", "hair", "eye", "beard_col"]:
		var c: Color = f[key]
		if c.r < 0.0 or c.g < 0.0 or c.b < 0.0 or c.r > 1.0 or c.g > 1.0 or c.b > 1.0 or c.a < 0.99:
			out.append("cor inválida: %s" % key)
	# Luz: a sombra do nariz nunca passa da sombra da borda do rosto/mandíbula
	if FaceLighting.NOSE_SHADOW_MAX > FaceLighting.JAW_EDGE_AO:
		out.append("sombra do nariz mais forte que a da mandíbula")
	return out


## Estrutura do rosto num vetor normalizado (desvios típicos ~1): mede o quanto dois rostos se
## parecem além de cabelo e barba.
static func vector(f: Dictionary) -> PackedFloat32Array:
	var lm := landmarks(f)
	return PackedFloat32Array([
		(float(f["fw"]) / float(f["fh"]) - 0.76) / 0.04,
		(float(f["fh"]) - 0.293) / 0.012,
		(float(f["jaw"]) - 0.8) / 0.08,
		(float(f["chin_sq"]) - 1.8) / 0.45,
		(float(f["cheekbone"]) - 0.95) / 0.2,
		(float(f.get("chin_len", 0.0))) / 0.03,
		(float(f["eye_w"]) - 0.225) / 0.015,
		(float(f["eye_h"]) - 0.1) / 0.015,
		(float(lm["X"]) - 0.45) / 0.022,
		(float(lm["E"]) + 0.03) / 0.03,
		(float(f["eye_tilt"]) - 0.015) / 0.02,
		(float(lm["NW"]) - 0.32) / 0.05,
		(float(lm["N"]) - float(lm["E"]) - 0.4) / 0.04,
		(float(f["bridge"]) - 0.9) / 0.25,
		(float(lm["MW"]) - 0.4) / 0.04,
		(float(f["lip_u"]) - 0.04) / 0.01,
		(float(f["lip_l"]) - 0.06) / 0.012,
		(float(f["brow_t"]) - 0.068) / 0.015,
		(float(f["hairline"]) + 0.55) / 0.04,
		(float(f["skin_i"]) - 4.0) / 2.0,
	])


## Texto curto do DNA para o laboratório de rostos.
static func summary(f: Dictionary) -> String:
	var lm := landmarks(f)
	return "\n".join(PackedStringArray([
		"Formato: %s · largura/altura %.2f · mandíbula %.2f · queixo %.1f" % [FaceGen.FACE_SHAPES[clampi(int(f.get("face_shape", 0)), 0, FaceGen.FACE_SHAPES.size() - 1)], float(f["fw"]) / float(f["fh"]), float(f["jaw"]), float(f["chin_sq"])],
		"Fatores: largura %+.1f · comprimento %+.1f · robustez %+.1f" % [float(f.get("dna_w", 0.0)), float(f.get("dna_l", 0.0)), float(f.get("dna_r", 0.0))],
		"Olhos: %.3f × %.3f · distância %.2f · altura %.2f" % [float(f["eye_w"]), float(f["eye_h"]), float(lm["X"]), float(lm["E"])],
		"Nariz: largura %.2f · comprimento %.2f · dorso %.2f" % [float(lm["NW"]), float(lm["N"]) - float(lm["E"]), float(f["bridge"])],
		"Boca: meia largura %.2f · lábios %.3f/%.3f" % [float(lm["MW"]), float(f["lip_u"]), float(f["lip_l"])],
		"Pele %.1f · %s · cabelo %s · barba %s" % [float(f["skin_i"]), FaceColorSystem.UNDERTONES[clampi(int(f.get("undertone", 1)), 0, 3)], FaceGen.HAIR_STYLES[clampi(int(f["style"]), 0, FaceGen.HAIR_STYLES.size() - 1)], FaceGen.BEARDS[clampi(int(f["beard"]), 0, FaceGen.BEARDS.size() - 1)]],
	]))
