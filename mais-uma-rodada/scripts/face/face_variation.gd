class_name FaceVariation
extends RefCounted
## Anatomia correlacionada, variação individual e assimetria do DNA facial.
##
## Em vez de sortear cada traço sozinho (o que dá combinações impossíveis e, ao mesmo tempo, rostos
## parecidos), três fatores latentes com distribuição quase normal puxam grupos de traços juntos,
## como num rosto de verdade:
##   largura     → largura do rosto, maçãs, mandíbula, boca, distância dos olhos, nariz
##   comprimento → altura do rosto, testa, nariz mais longo, boca mais baixa, queixo mais longo
##   robustez    → arco das sobrancelhas, olhos mais fundos, queixo quadrado, maçãs, dorso do nariz,
##                 sobrancelhas mais grossas e lábio de cima mais fino
## Por cima vem uma variação própria de cada traço (menor) e uma assimetria de 1–3 %, só para
## tirar o ar de rosto espelhado por computador.
## Tudo sai de um sorteio próprio (semente + "anatomia"): não mexe na sequência dos outros sorteios.

## Faixas plausíveis (unidades do FaceGen); o validador (FaceDNA.validate) usa as mesmas.
const LIMITS := {
	"fw": [0.16, 0.27], "fh": [0.24, 0.35], "jaw": [0.62, 0.98], "chin_sq": [1.0, 3.3],
	"eye_w": [0.17, 0.3], "eye_h": [0.06, 0.16], "eye_dx": [0.36, 0.52], "eye_y": [-0.11, 0.07],
	"nose_w": [0.14, 0.34], "nose_len": [0.22, 0.42], "mouth_w": [0.22, 0.44], "mouth_y": [0.5, 0.68],
	"lip_u": [0.015, 0.08], "lip_l": [0.025, 0.11], "brow_t": [0.03, 0.12], "ear": [0.8, 1.25],
	"chin_len": [-0.1, 0.12], "hairline": [-0.72, -0.4],
}


## Aproximadamente normal (soma de três uniformes), média 0, desvio 1, limitada a ±2,6.
static func normalish(r: RandomNumberGenerator) -> float:
	return clampf((r.randf() + r.randf() + r.randf() - 1.5) * 2.0, -2.6, 2.6)


static func apply(f: Dictionary, seed_value: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, "anatomia"])
	var wide := normalish(r)
	var long := normalish(r)
	var robust := normalish(r)
	f["dna_w"] = wide
	f["dna_l"] = long
	f["dna_r"] = robust
	# --- Largura
	f["fw"] = float(f["fw"]) * (1.0 + 0.04 * wide)
	f["cheek_w"] = float(f["cheek_w"]) * (1.0 + 0.012 * wide)
	f["jaw"] = float(f["jaw"]) + 0.035 * wide + 0.025 * robust
	f["mouth_w"] = float(f["mouth_w"]) * (1.0 + 0.04 * wide)
	f["eye_dx"] = float(f["eye_dx"]) + 0.01 * wide
	f["nose_w"] = float(f["nose_w"]) * (1.0 + 0.04 * wide)
	# --- Comprimento
	f["fh"] = float(f["fh"]) * (1.0 + 0.03 * long)
	f["hairline"] = float(f["hairline"]) - 0.025 * long
	f["nose_len"] = float(f["nose_len"]) * (1.0 + 0.055 * long)
	f["mouth_y"] = float(f["mouth_y"]) + 0.012 * long
	f["chin_len"] = float(f.get("chin_len", 0.0)) + 0.022 * long
	# --- Robustez
	f["ridge"] = float(f["ridge"]) * (1.0 + 0.14 * robust)
	f["deep"] = float(f["deep"]) * (1.0 + 0.1 * robust)
	f["chin_sq"] = float(f["chin_sq"]) + 0.22 * robust
	f["cheekbone"] = float(f["cheekbone"]) * (1.0 + 0.07 * robust)
	f["bridge"] = float(f["bridge"]) * (1.0 + 0.08 * robust)
	f["brow_t"] = float(f["brow_t"]) * (1.0 + 0.09 * robust)
	f["lip_u"] = float(f["lip_u"]) * (1.0 - 0.05 * robust)
	# --- Variação própria de cada traço (menor que a dos fatores)
	f["eye_w"] = float(f["eye_w"]) * (1.0 + 0.05 * normalish(r))
	f["eye_h"] = float(f["eye_h"]) * (1.0 + 0.07 * normalish(r))
	f["eye_y"] = float(f["eye_y"]) + 0.012 * normalish(r)
	f["eye_tilt"] = float(f["eye_tilt"]) + 0.008 * normalish(r)
	f["nose_tip"] = float(f["nose_tip"]) * (1.0 + 0.09 * normalish(r))
	f["bridge_w"] = float(f["bridge_w"]) * (1.0 + 0.09 * normalish(r))
	f["lip_l"] = float(f["lip_l"]) * (1.0 + 0.1 * normalish(r))
	f["bow"] = clampf(float(f["bow"]) + 0.15 * normalish(r), 0.0, 1.2)
	f["brow_arch"] = maxf(0.0, float(f["brow_arch"]) + 0.012 * normalish(r))
	f["brow_tilt"] = float(f["brow_tilt"]) + 0.01 * normalish(r)
	f["brow_gap"] = float(f["brow_gap"]) * (1.0 + 0.05 * normalish(r))
	f["brow_len"] = float(f["brow_len"]) * (1.0 + 0.05 * normalish(r))
	f["ear"] = float(f["ear"]) * (1.0 + 0.03 * normalish(r))
	f["chin_w"] = 1.0 + 0.07 * normalish(r)
	f["gonion_v"] = 0.02 * normalish(r)
	# --- Assimetria sutil (1–3 %): olhos, sobrancelhas, ponta do nariz, canto da boca, orelhas
	f["eye_asym"] = 0.012 * normalish(r)
	f["brow_asym"] = 0.006 * normalish(r)
	f["nose_dx_t"] = float(f.get("nose_dx_t", 0.0)) + 0.006 * normalish(r)
	f["mouth_tilt"] = float(f.get("mouth_tilt", 0.0)) + 0.08 * normalish(r)
	f["ear_asym"] = 0.02 * normalish(r)
	# --- Dentro das faixas plausíveis
	for key: String in LIMITS:
		if f.has(key):
			var lim: Array = LIMITS[key]
			f[key] = clampf(float(f[key]), float(lim[0]), float(lim[1]))
