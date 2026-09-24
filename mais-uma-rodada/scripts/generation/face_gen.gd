class_name FaceGen
extends RefCounted
## Traços do rosto de uma pessoa (jogador, técnico, dirigente), derivados da semente do rosto,
## da etnia e da idade — o mesmo jogador tem sempre o mesmo rosto e envelhece com ele.
## O editor pode fixar qualquer traço pelo dicionário `look` ({hs, hc, bd, sk, ey}).

const HAIR_STYLES: Array[String] = [
	"Raspado", "Curto", "Repartido", "Topete", "Degradê", "Cacheado", "Black power", "Dreads",
	"Longo", "Coque", "Moicano", "Careca", "Penteado para trás", "Tranças nagô", "Arrepiado", "Franja",
]
const H_BUZZ := 0
const H_SHORT := 1
const H_PART := 2
const H_QUIFF := 3
const H_FADE := 4
const H_CURLY := 5
const H_AFRO := 6
const H_DREADS := 7
const H_LONG := 8
const H_BUN := 9
const H_MOHAWK := 10
const H_BALD := 11
const H_SLICK := 12
const H_CORNROWS := 13
const H_SPIKY := 14
const H_FRINGE := 15

const BEARDS: Array[String] = ["Sem barba", "Por fazer", "Curta", "Cheia", "Cavanhaque", "Bigode", "Contorno", "Bigode e cavanhaque"]
const B_NONE := 0
const B_STUBBLE := 1
const B_SHORT := 2
const B_FULL := 3
const B_GOATEE := 4
const B_MUSTACHE := 5
const B_CHINSTRAP := 6
const B_VANDYKE := 7

const HAIR_COLOR_NAMES: Array[String] = ["Preto", "Castanho-escuro", "Castanho", "Castanho-claro", "Loiro-escuro", "Loiro", "Ruivo", "Platinado"]
const HAIR_COLORS: Array[Color] = [
	Color("#141010"), Color("#2E1E14"), Color("#4E3322"), Color("#7A5534"),
	Color("#A7834F"), Color("#D8BC7E"), Color("#9A4521"), Color("#E9E4D6"),
]
const SKIN_COLORS: Array[Color] = [
	Color("#FBE2D2"), Color("#F4D0B5"), Color("#EAC09E"), Color("#DDAB86"), Color("#C9956C"),
	Color("#B17B53"), Color("#946341"), Color("#784D31"), Color("#5D3A24"), Color("#442A1A"),
]
const EYE_COLORS: Array[Color] = [Color("#2E1C12"), Color("#553620"), Color("#7A6034"), Color("#4C7648"), Color("#4677AC"), Color("#7B8994")]

## Faixa de tom de pele por etnia (nor, eur, med, arb, lat, and, mix, afr, eas), em índices de SKIN_COLORS.
const ETH_SKIN_RANGE: Array = [[0.0, 2.2], [0.5, 3.2], [1.5, 4.3], [2.2, 5.2], [2.0, 6.0], [3.5, 6.6], [3.2, 8.2], [6.0, 9.0], [0.8, 3.4]]
const ETH_HAIR_COLOR: Array = [
	[0.3, 1.5, 1.5, 1.2, 1.2, 1.2, 0.35, 0.03],
	[0.8, 2.0, 1.5, 0.8, 0.5, 0.3, 0.15, 0.03],
	[2.0, 2.0, 1.0, 0.3, 0.1, 0.05, 0.05, 0.03],
	[3.0, 1.5, 0.4, 0.1, 0.0, 0.0, 0.03, 0.03],
	[2.5, 2.0, 0.6, 0.2, 0.1, 0.05, 0.03, 0.05],
	[4.0, 1.2, 0.2, 0.0, 0.0, 0.0, 0.0, 0.03],
	[3.0, 1.5, 0.4, 0.1, 0.05, 0.0, 0.02, 0.08],
	[5.0, 0.8, 0.1, 0.0, 0.0, 0.0, 0.0, 0.12],
	[4.0, 1.2, 0.3, 0.05, 0.0, 0.0, 0.0, 0.06],
]
const ETH_EYES: Array = [
	[0.5, 1.0, 0.8, 1.0, 2.2, 1.0],
	[1.5, 2.0, 1.0, 0.8, 1.0, 0.5],
	[2.0, 2.0, 0.8, 0.4, 0.3, 0.1],
	[3.0, 2.0, 0.5, 0.2, 0.05, 0.0],
	[3.0, 2.0, 0.4, 0.15, 0.1, 0.02],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[4.0, 2.0, 0.3, 0.1, 0.05, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
	[5.0, 1.0, 0.05, 0.0, 0.0, 0.0],
]
## Pesos dos penteados por grupo: 0 = europeu/latino/árabe, 1 = africano, 2 = leste asiático.
const STYLE_W: Array = [
	[1.0, 3.0, 2.0, 1.5, 2.5, 1.0, 0.0, 0.1, 0.6, 0.5, 0.2, 0.4, 1.0, 0.0, 0.8, 0.9],
	[3.0, 1.0, 0.1, 0.2, 2.5, 0.8, 1.0, 1.5, 0.0, 0.2, 0.4, 1.2, 0.0, 1.0, 0.2, 0.0],
	[1.0, 2.5, 2.0, 1.0, 1.5, 0.1, 0.0, 0.0, 0.5, 0.3, 0.1, 0.2, 1.0, 0.0, 1.5, 2.0],
]
const BEARD_W: Array = [3.0, 3.0, 2.0, 1.2, 0.8, 0.3, 0.5, 0.6]


static func style_group(eth: int) -> int:
	if eth == 7:
		return 1
	if eth == 8:
		return 2
	return 0


## Todos os traços de um rosto. `age` muda cabelos brancos, entradas, rugas e barba.
static func features(seed_value: int, eth: int, age: int, look: Dictionary = {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var e := clampi(eth, 0, ETH_SKIN_RANGE.size() - 1)
	var f := {}
	# Pele: posição contínua na paleta (triangular dentro da faixa da etnia)
	var rg: Array = ETH_SKIN_RANGE[e]
	var sk := lerpf(float(rg[0]), float(rg[1]), (rng.randf() + rng.randf()) * 0.5)
	if look.has("sk"):
		sk = float(look["sk"])
	f["skin_i"] = sk
	var skin := skin_at(sk)
	if e == 8:
		skin = skin.lerp(Color("#E9C79C"), 0.18)
	f["skin"] = skin
	# Formato do rosto
	f["fw"] = rng.randf_range(0.215, 0.245)
	f["fh"] = rng.randf_range(0.28, 0.31)
	f["jaw"] = rng.randf_range(0.72, 0.92) # largura da mandíbula em relação às maçãs
	f["sq"] = rng.randf_range(1.0, 1.5) # quão quadrado é o queixo
	f["ear"] = rng.randf_range(0.9, 1.15)
	# Olhos
	var ew: Array = ETH_EYES[e]
	var eye_i := RngUtil.weighted_index(rng, ew)
	if look.has("ey"):
		eye_i = clampi(int(look["ey"]), 0, EYE_COLORS.size() - 1)
	f["eye_i"] = eye_i
	f["eye"] = EYE_COLORS[eye_i]
	f["eye_w"] = rng.randf_range(0.21, 0.26)
	f["eye_h"] = rng.randf_range(0.085, 0.11) * (0.72 if e == 8 else 1.0)
	f["eye_dx"] = rng.randf_range(0.4, 0.47)
	f["eye_tilt"] = rng.randf_range(-0.01, 0.03) + (0.025 if e == 8 else 0.0)
	f["monolid"] = e == 8 and rng.randf() < 0.7
	f["gaze"] = rng.randf_range(-0.2, 0.2)
	# Sobrancelhas
	f["brow_t"] = rng.randf_range(0.035, 0.06)
	f["brow_arch"] = rng.randf_range(0.0, 0.05)
	f["brow_tilt"] = rng.randf_range(-0.03, 0.04)
	f["brow_len"] = rng.randf_range(0.38, 0.48)
	# Nariz e boca
	var nose_base := 0.2 if e == 7 else (0.17 if e >= 5 else 0.15)
	f["nose_w"] = rng.randf_range(nose_base, nose_base + 0.07)
	f["nose_len"] = rng.randf_range(0.26, 0.34)
	var lip_base := 1.3 if e == 7 else (1.1 if e == 6 else 1.0)
	f["mouth_w"] = rng.randf_range(0.28, 0.36)
	f["lip_u"] = rng.randf_range(0.03, 0.045) * lip_base
	f["lip_l"] = rng.randf_range(0.045, 0.065) * lip_base
	f["smile"] = rng.randf_range(-0.3, 0.8)
	# Cabelo
	var hc_i := RngUtil.weighted_index(rng, ETH_HAIR_COLOR[e])
	if look.has("hc"):
		hc_i = clampi(int(look["hc"]), 0, HAIR_COLORS.size() - 1)
	f["hair_i"] = hc_i
	var sw: Array = STYLE_W[style_group(e)].duplicate()
	if e == 6: # mistura: metade de cada
		var a: Array = STYLE_W[0]
		var b: Array = STYLE_W[1]
		for i in sw.size():
			sw[i] = (float(a[i]) + float(b[i])) * 0.5
	if e in [2, 3, 4]:
		sw[H_CURLY] = float(sw[H_CURLY]) * 1.6
	var style := RngUtil.weighted_index(rng, sw)
	# Entradas e calvície: tendência pessoal que aparece com a idade
	var rec_trait := rng.randf()
	var recession := clampf((age - 24) * 0.035 * rec_trait * 1.6, 0.0, 1.0)
	var balding := rec_trait > 0.82 and age >= 32
	if balding and style != H_BALD and style != H_BUZZ and not look.has("hs"):
		style = H_BUZZ if rng.randf() < 0.35 else style
	if look.has("hs"):
		style = clampi(int(look["hs"]), 0, HAIR_STYLES.size() - 1)
		balding = false
	if hc_i == 7 and not look.has("hc") and not (style in [H_BUZZ, H_FADE, H_SHORT, H_SPIKY, H_CURLY, H_AFRO, H_MOHAWK]):
		hc_i = 5 if e <= 1 else 1
		f["hair_i"] = hc_i
	f["style"] = style
	f["recession"] = recession
	f["balding"] = balding and style != H_BALD
	f["vol"] = rng.randf_range(0.0, 1.0)
	f["part_side"] = -1.0 if rng.randf() < 0.6 else 1.0
	# Cabelos brancos
	var gray_start := rng.randf_range(28.0, 42.0)
	var gray := clampf((age - gray_start) / 16.0, 0.0, 0.85)
	f["gray"] = gray
	var hair := HAIR_COLORS[hc_i]
	if hc_i != 7:
		hair = hair.lerp(Color("#C9C6C0"), gray * 0.7)
	f["hair"] = hair
	# Barba
	var bw: Array = BEARD_W.duplicate()
	if e in [2, 3]:
		bw[B_SHORT] = 3.0
		bw[B_FULL] = 2.2
	if e == 8:
		bw = [7.0, 1.5, 0.4, 0.1, 0.4, 0.3, 0.1, 0.2]
	if e == 5:
		bw = [5.0, 2.0, 0.6, 0.2, 0.5, 0.6, 0.1, 0.4]
	if age < 20:
		bw = [8.0, 1.2, 0.1, 0.0, 0.1, 0.0, 0.0, 0.0]
	elif age < 23:
		bw[B_FULL] = float(bw[B_FULL]) * 0.4
	elif age >= 32:
		bw[B_FULL] = float(bw[B_FULL]) * 1.4
	var beard := RngUtil.weighted_index(rng, bw)
	if look.has("bd"):
		beard = clampi(int(look["bd"]), 0, BEARDS.size() - 1)
	f["beard"] = beard
	var beard_col := HAIR_COLORS[hc_i if hc_i != 7 else 1].darkened(0.08)
	f["beard_col"] = beard_col.lerp(Color("#CFCCC6"), clampf(gray * 1.1, 0.0, 0.9))
	# Marcas do tempo e detalhes
	f["wrinkles"] = clampf((age - 29) / 14.0, 0.0, 1.0)
	f["freckles"] = e <= 1 and sk < 1.6 and rng.randf() < 0.22
	f["mole"] = rng.randf() < 0.12
	f["mole_pos"] = Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(0.1, 0.6))
	f["earring"] = rng.randf() < 0.07
	f["headband"] = (style in [H_LONG, H_DREADS, H_CURLY, H_AFRO]) and rng.randf() < 0.25
	f["collar"] = rng.randi_range(0, 2)
	f["texture_seed"] = rng.randi()
	return f


static func skin_at(v: float) -> Color:
	var i := clampi(int(floor(v)), 0, SKIN_COLORS.size() - 1)
	var j := mini(i + 1, SKIN_COLORS.size() - 1)
	return SKIN_COLORS[i].lerp(SKIN_COLORS[j], clampf(v - i, 0.0, 1.0))
