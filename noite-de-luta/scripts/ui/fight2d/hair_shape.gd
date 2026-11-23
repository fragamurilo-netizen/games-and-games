class_name HairShape
extends RefCounted
## Silhueta do cabelo e da barba na luta (2D e 3D). O retrato desenha cada um dos mais de 200
## penteados; na luta o boneco é pequeno, então o penteado vira um volume: quanto cabelo tem no
## alto, nos lados e na nuca, se é crista, coque, rabo, tranças ou black power. A leitura sai do
## nome do penteado (`FaceGen.HAIR_STYLES`), então penteado novo entra sozinho.
##
## Chaves: bald, top (altura no alto, em raios da cabeça), side (grossura nos lados e atrás),
## back (comprimento caindo da nuca), front (franja na testa, 0–1), lift (topete: sobe na frente),
## bun (0 nada, 1 coque no alto, 2 coque baixo, 3 rabo, 4 dois puffs), strands (dreads/tranças),
## ridge (moicano: só uma crista no meio), curly (contorno ondulado).

const BUN_NONE := 0
const BUN_TOP := 1
const BUN_LOW := 2
const BUN_TAIL := 3
const BUN_PUFFS := 4

## Barba: sem, por fazer (sombra), só bigode, cavanhaque, curta, média e longa.
const BD_NONE := 0
const BD_STUBBLE := 1
const BD_MUSTACHE := 2
const BD_GOATEE := 3
const BD_SHORT := 4
const BD_MEDIUM := 5
const BD_LONG := 6

static var _cache := {}
static var _bcache := {}


static func _has(s: String, words: Array) -> bool:
	for w: String in words:
		if s.contains(w):
			return true
	return false


static func of(style: int) -> Dictionary:
	if _cache.has(style):
		return _cache[style]
	var n := ""
	if style >= 0 and style < FaceGen.HAIR_STYLES.size():
		n = FaceGen.HAIR_STYLES[style].to_lower()
	var s := {"bald": false, "top": 0.1, "side": 0.07, "back": 0.0, "front": 0.12, "lift": 0.0, "bun": BUN_NONE, "strands": false, "ridge": false, "curly": false}
	if style == FaceGen.H_BALD or n.contains("careca"):
		s["bald"] = true
		s["top"] = 0.0
		s["side"] = 0.0
		s["front"] = 0.0
	elif _has(n, ["moicano", "hawk", "crista"]):
		s["ridge"] = true
		s["top"] = 0.42 if _has(n, ["alta", "espetado", "dreads"]) else 0.3
		s["side"] = 0.0
		s["back"] = 0.12
		s["curly"] = _has(n, ["cachead", "fro"])
	elif _has(n, ["puff"]):
		s["top"] = 0.05
		s["side"] = 0.04
		s["bun"] = BUN_PUFFS if n.contains("dois") else BUN_TOP
		s["curly"] = true
	elif _has(n, ["black power", "afro", "blowout", "armados", "esponja"]):
		s["curly"] = true
		if _has(n, ["gigante"]):
			s["top"] = 0.62
			s["side"] = 0.5
		elif _has(n, ["alto", "redondo"]) and not n.contains("degradê alto"):
			s["top"] = 0.46
			s["side"] = 0.34
		elif _has(n, ["curto", "baixo", "esponja"]):
			s["top"] = 0.16
			s["side"] = 0.11
		else:
			s["top"] = 0.32
			s["side"] = 0.26
		s["front"] = 0.3
	elif _has(n, ["nagô"]):
		s["top"] = 0.045
		s["side"] = 0.04
		s["front"] = 0.0
		if _has(n, ["rabo"]):
			s["bun"] = BUN_TAIL
	elif _has(n, ["dreads", "locs", "tranças", "braids", "twist", "freeform", "tufinhos"]):
		s["strands"] = true
		s["top"] = 0.13
		s["side"] = 0.11
		s["front"] = 0.25
		if _has(n, ["presos", "presas", "rabo", "coque"]):
			s["bun"] = BUN_TAIL if _has(n, ["rabo", "presos"]) else BUN_TOP
			s["back"] = 0.1
		elif _has(n, ["curto", "curtos", "freeform", "twist out", "tufinhos", "médios"]):
			s["back"] = 0.22
		elif n == "twists":
			s["back"] = 0.3
		else:
			s["back"] = 0.95
	elif _has(n, ["coque", "samurai"]):
		s["top"] = 0.05
		s["side"] = 0.05
		s["front"] = 0.0
		s["bun"] = BUN_LOW if n.contains("baixo") else BUN_TOP
		s["curly"] = n.contains("cachead")
	elif _has(n, ["rabo", "rabinho", "meio preso", "preso para trás"]):
		s["top"] = 0.06
		s["side"] = 0.06
		s["front"] = 0.0
		s["bun"] = BUN_TAIL
	elif _has(n, ["mullet"]):
		s["top"] = 0.13
		s["side"] = 0.06
		s["back"] = 0.6
		s["curly"] = n.contains("cachead")
	elif _has(n, ["longo", "longa", "ombro", "chanel"]):
		s["top"] = 0.12
		s["side"] = 0.13
		s["back"] = 0.6 if n.contains("chanel") else 1.0
		s["front"] = 0.5 if _has(n, ["franja"]) else 0.15
		s["curly"] = _has(n, ["cachead", "ondulado"])
	elif _has(n, ["surfista", "flow", "nuca", "wolf", "orelhas"]):
		s["top"] = 0.14
		s["side"] = 0.13
		s["back"] = 0.55
		s["front"] = 0.2
	elif _has(n, ["raspado", "máquina", "buzz", "militar", "waves", "rente", "crespo baixo", "crespo curto"]):
		s["top"] = 0.03
		s["side"] = 0.026
		s["front"] = 0.0
	elif _has(n, ["topete", "pompadour", "high top", "flat top", "arrepiado", "espetado", "blowout"]):
		s["top"] = 0.4 if _has(n, ["alto", "high top", "flat top", "volume"]) else 0.26
		s["side"] = 0.06
		s["lift"] = 0.0 if _has(n, ["high top", "flat top"]) else 1.0
		s["front"] = 0.0
		s["curly"] = n.contains("cachead")
	elif _has(n, ["cachead", "cachos", "cachinhos", "ondulado", "permanente", "crespo"]):
		s["curly"] = true
		s["top"] = 0.22
		s["side"] = 0.15
		s["front"] = 0.35
		if _has(n, ["curto"]):
			s["top"] = 0.14
			s["side"] = 0.09
		elif _has(n, ["médio", "médios", "soltos", "volumoso"]):
			s["back"] = 0.3
	elif _has(n, ["franja", "tigela", "cortina", "edgar", "césar", "crop", "meia-lua"]):
		s["top"] = 0.13
		s["side"] = 0.09
		s["front"] = 0.7
	elif _has(n, ["médio", "desarrumado", "bagunçado", "volumoso"]):
		s["top"] = 0.17
		s["side"] = 0.12
		s["back"] = 0.25
		s["front"] = 0.3
	elif _has(n, ["para trás", "molhado", "gel"]):
		s["top"] = 0.1
		s["side"] = 0.07
		s["front"] = 0.0
		s["back"] = 0.1
	# Laterais raspadas ou em degradê: o cabelo fica só no alto.
	if _has(n, ["degradê", "fade", "undercut", "navalhad", "sidecut", "taper", "laterais curtas", "two block", "edgar"]) and float(s["side"]) > 0.0:
		s["side"] = maxf(0.015, float(s["side"]) * 0.28)
	_cache[style] = s
	return s


static func beard(i: int) -> int:
	if _bcache.has(i):
		return _bcache[i]
	var n := ""
	if i >= 0 and i < FaceGen.BEARDS.size():
		n = FaceGen.BEARDS[i].to_lower()
	var k := BD_SHORT
	if i <= 0 or n == "" or n.contains("sem barba"):
		k = BD_NONE
	elif _has(n, ["por fazer", "três dias", "penugem", "sombra", "buço", "falhada", "sombreado"]) or n == "rala" or n == "rala desigual":
		k = BD_STUBBLE
	elif _has(n, ["longa", "lenhador", "garibaldi", "verdi", "bifurcada", "comprida", "volumosa", "desgrenhada"]) and not _has(n, ["cavanhaque", "mosca", "costeletas"]):
		k = BD_LONG
	elif _has(n, ["cavanhaque", "mosca", "âncora", "balbo", "imperial", "queixo", "tufo", "círculo"]) and not _has(n, ["mandíbula", "cheio", "curta com"]):
		k = BD_GOATEE
	elif _has(n, ["bigode", "fu manchu", "ferradura", "guidão", "morsa"]) and not _has(n, ["barba"]):
		k = BD_MUSTACHE
	elif _has(n, ["costeletas"]):
		k = BD_NONE
	elif _has(n, ["cheia", "média", "quadrada", "cerrada", "arredondada", "dez dias", "duas semanas", "crespa longa", "alta"]):
		k = BD_MEDIUM
	_bcache[i] = k
	return k
