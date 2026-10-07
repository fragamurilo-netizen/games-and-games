class_name BrandLogo
extends RefCounted
## Logo completo de uma marca do mundo do jogo: o símbolo (BrandMark) e o nome desenhado com a
## tipografia dela. Cada marca tem estilo próprio, tirado do setor e do nome (sempre o mesmo):
## peso, largura e inclinação da Saira variável, caixa, espaçamento, palavra genérica menor
## ("banco", "seguros", "motors"...), composição (símbolo ao lado, em cima, só o nome com um
## detalhe, ou o nome vazado num selo) e detalhes (ponto, barra, traço curvo, barra inclinada).
## Tudo vetorial (contornos das letras da fonte), em cache por marca: nítido em qualquer tamanho,
## e o mesmo no peito da camisa, na placa do estádio, no cartão do patrocínio e no retrato.
##
## Unidades da composição: altura das maiúsculas do nome = 1.

## Palavras que viram descritor (menores, mais leves) quando a marca tem mais de uma palavra.
const DESCRIPTORS := ["banco", "bank", "banca", "banque", "seguros", "seguradora", "assurances", "assicurazioni",
	"insurance", "versicherung", "supermercados", "supermercado", "construtora", "construcciones", "constructora",
	"motors", "auto", "garage", "taller", "telecom", "telefonía", "telefonia", "mobile", "energia", "energy", "energía",
	"énergie", "energi", "foods", "alimentos", "cerveja", "cervejaria", "brewery", "cervecería", "airways", "airlines",
	"air", "hospital", "faculdade", "university", "universidad", "imobiliária", "inmobiliaria", "rádio", "radio", "taxis",
	"glass", "carpets", "homes", "logistics", "plumbing", "tiles", "mining", "health", "tourism", "realty", "credit union",
	"group", "grupo", "bet", "club", "lager", "ale", "brewing", "banka", "pivovara", "pivovar", "osiguranje", "pojišťovna",
	"autoservis", "stavby", "energie", "mobil", "sport", "kit", "deportes", "trikot"]

## Estilos por setor: [caixa, peso, largura, inclinação, espaçamento (em), composição, detalhe, descritor].
const SECTOR := {
	"aposta": [["upper", 880, 70, 0.2, 0.01, "left", "none", false], ["lower", 820, 84, 0.14, 0.0, "word", "dot", false],
		["upper", 900, 62, 0.18, 0.03, "badge_slant", "none", false]],
	"banco": [["title", 640, 100, 0.0, 0.0, "left", "none", true], ["upper", 580, 115, 0.0, 0.12, "top", "none", true],
		["upper", 760, 92, 0.0, 0.04, "left", "none", true]],
	"fintech": [["lower", 760, 96, 0.0, -0.01, "left", "dot", false], ["lower", 700, 100, 0.0, 0.0, "word", "none", false]],
	"cripto": [["upper", 640, 118, 0.0, 0.18, "left", "none", false], ["lower", 720, 100, 0.0, 0.0, "left", "dot", false]],
	"seguro": [["title", 660, 100, 0.0, 0.0, "left", "none", true], ["upper", 720, 104, 0.0, 0.06, "left", "none", true],
		["upper", 600, 116, 0.0, 0.14, "top", "none", true]],
	"montadora": [["upper", 640, 122, 0.0, 0.2, "top", "none", true], ["upper", 800, 116, 0.12, 0.06, "left", "none", true],
		["upper", 560, 125, 0.0, 0.26, "word", "bar", true]],
	"telecom": [["lower", 780, 98, 0.0, 0.0, "left", "none", false], ["lower", 660, 108, 0.0, 0.0, "left", "none", true],
		["title", 820, 90, 0.0, 0.0, "word", "swoosh", false]],
	"aerea": [["upper", 580, 122, 0.12, 0.16, "left", "none", true], ["title", 720, 110, 0.1, 0.02, "left", "swoosh", true]],
	"cerveja": [["upper", 900, 58, 0.0, 0.03, "badge_oval", "none", true], ["upper", 860, 66, 0.0, 0.05, "top", "none", true],
		["title", 820, 80, 0.08, 0.0, "word", "bar", true]],
	"bebida": [["title", 800, 86, 0.1, 0.0, "word", "swoosh", false], ["upper", 840, 76, 0.0, 0.02, "left", "none", false]],
	"energia": [["upper", 820, 88, 0.12, 0.02, "left", "none", true], ["lower", 760, 100, 0.0, 0.0, "left", "none", true]],
	"petroleo": [["upper", 860, 96, 0.08, 0.04, "left", "none", true], ["upper", 760, 110, 0.0, 0.1, "top", "none", true]],
	"construcao": [["upper", 800, 104, 0.0, 0.06, "left", "none", true], ["upper", 900, 80, 0.0, 0.02, "top", "none", true]],
	"imobiliaria": [["upper", 700, 110, 0.0, 0.1, "left", "none", true], ["title", 640, 100, 0.0, 0.0, "top", "none", true]],
	"alimentos": [["title", 760, 96, 0.0, 0.0, "left", "none", true], ["title", 840, 84, 0.08, 0.01, "badge_pill", "none", true],
		["upper", 720, 100, 0.0, 0.08, "top", "none", true]],
	"varejo": [["lower", 860, 92, 0.0, 0.0, "word", "dot", true], ["upper", 880, 74, 0.0, 0.03, "badge_rect", "none", true]],
	"logistica": [["upper", 860, 96, 0.16, 0.02, "left", "slash", true], ["upper", 760, 110, 0.1, 0.08, "left", "none", true]],
	"tecnologia": [["lower", 680, 104, 0.0, 0.02, "left", "none", false], ["upper", 620, 120, 0.0, 0.22, "left", "none", false]],
	"saude": [["title", 620, 100, 0.0, 0.0, "left", "none", true], ["lower", 700, 96, 0.0, 0.0, "left", "none", true]],
	"educacao": [["title", 600, 100, 0.0, 0.0, "left", "none", true], ["upper", 640, 108, 0.0, 0.12, "top", "none", true]],
	"turismo": [["title", 720, 104, 0.1, 0.0, "left", "swoosh", true], ["lower", 700, 100, 0.0, 0.0, "word", "swoosh", true]],
	"midia": [["upper", 900, 82, 0.0, 0.02, "badge_rect", "none", true], ["lower", 820, 90, 0.0, 0.0, "left", "none", true]],
	"mineracao": [["upper", 820, 110, 0.0, 0.1, "top", "none", true], ["upper", 880, 90, 0.0, 0.04, "left", "none", true]],
	"luxo": [["upper", 420, 125, 0.0, 0.32, "top", "none", true], ["upper", 520, 120, 0.0, 0.24, "word", "bar", true]],
}
const DEFAULT := [["title", 720, 100, 0.0, 0.0, "left", "none", true], ["upper", 760, 104, 0.0, 0.06, "left", "none", true]]

static var _styles: Dictionary = {}
static var _lockups: Dictionary = {}


static func _full(b: Dictionary) -> Dictionary:
	if b.has("s") or String(b.get("n", "")) == "":
		return b
	var e := BrandCatalog.find(String(b.get("n", "")))
	if e.is_empty():
		return b
	var full := b.duplicate()
	for k in ["s", "m", "logo"]:
		if String(full.get(k, "")) == "" and e.has(k):
			full[k] = e[k]
	return full


static func style(b: Dictionary) -> Dictionary:
	var name := String(b.get("n", ""))
	if _styles.has(name):
		return _styles[name]
	var sector := String(b.get("s", ""))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name + "#logo")
	var opts: Array = SECTOR.get(sector, DEFAULT)
	var p: Array = opts[rng.randi() % opts.size()]
	var st := {"case": p[0], "w": float(p[1]) + rng.randf_range(-40.0, 40.0), "wd": clampf(float(p[2]) + rng.randf_range(-6.0, 6.0), 50.0, 125.0),
		"sl": float(p[3]), "tr": float(p[4]), "lay": p[5], "acc": p[6], "desc": bool(p[7])}
	_styles[name] = st
	return st


## Desenha o logo centrado no retângulo, do maior tamanho que couber. `ink` pinta o nome e o
## símbolo; `ink2`, os detalhes e as partes de destaque (vazio = ink). `cut` é a cor que aparece
## nos vazados do selo (o fundo; vazio = transparente). opts: "emb" (bordado: relevo e sombra),
## "outline" (Color: contorno de impressão), "symbol" (força só o símbolo).
static func draw(ci: CanvasItem, brand: Dictionary, rect: Rect2, ink: Color, ink2: Color = Color(0, 0, 0, 0), opts: Dictionary = {}) -> void:
	var b := _full(brand)
	if String(b.get("n", "")) == "":
		return
	if ink2.a <= 0.0:
		ink2 = ink
	var best: Dictionary = {}
	var best_k := 0.0
	if not bool(opts.get("symbol", false)):
		for mode: String in ["wide", "compact"]:
			var lk := lockup(b, mode)
			var bb: Rect2 = lk["bounds"]
			if bb.size.x <= 0.0 or bb.size.y <= 0.0:
				continue
			var k := minf(rect.size.x / bb.size.x, rect.size.y / bb.size.y)
			# A composição compacta (símbolo em cima) só ganha se ficar bem maior que a larga
			if best.is_empty() or (mode == "compact" and k > best_k * 1.35):
				best = lk
				best_k = k
		# O nome tem de ser legível: abaixo de ~5 px de maiúscula, fica só o símbolo
		if best_k < 5.0:
			best = {}
	if best.is_empty():
		best = lockup(b, "symbol")
		var bs: Rect2 = best["bounds"]
		if bs.size.x <= 0.0:
			return
		best_k = minf(rect.size.x / bs.size.x, rect.size.y / bs.size.y)
	if best.is_empty():
		return
	var bb2: Rect2 = best["bounds"]
	var pos := rect.get_center() - bb2.get_center() * best_k
	var key := "%s|%s" % [String(b.get("n", "")), String(best["mode"])]
	var items: Array = best["items"]
	if bool(opts.get("emb", false)):
		var lift := Vector2(0.0, maxf(0.6, best_k * 0.07))
		var shade := Color(0, 0, 0, 0.3 if ink.get_luminance() > 0.5 else 0.22)
		for i in items.size():
			LogoGeom.draw(ci, items[i][0], pos + lift, best_k, shade, "%s|%d" % [key, i])
	var oc: Color = opts.get("outline", Color(0, 0, 0, 0))
	if oc.a > 0.0:
		for it: Array in items:
			for p: PackedVector2Array in it[0]:
				var e := PackedVector2Array()
				for q in p:
					e.append(pos + q * best_k)
				e.append(e[0])
				ci.draw_polyline(e, oc, maxf(1.5, best_k * 0.1), true)
	for i in items.size():
		var it: Array = items[i]
		LogoGeom.draw(ci, it[0], pos, best_k, ink if int(it[1]) == 0 else ink2, "%s|%d" % [key, i])


## Proporção (largura / altura) da composição larga: para reservar a textura certa (DecalCache).
static func aspect(brand: Dictionary) -> float:
	var lk := lockup(_full(brand), "wide")
	var bb: Rect2 = lk["bounds"]
	return bb.size.x / maxf(0.01, bb.size.y)


## Composição em cache: {"items": [[forma, tom]], "bounds": Rect2, "mode": modo}.
static func lockup(b: Dictionary, mode: String) -> Dictionary:
	var name := String(b.get("n", ""))
	var ck := "%s|%s" % [name, mode]
	if _lockups.has(ck):
		return _lockups[ck]
	var st := style(b)
	var items: Array = []
	var mark_layers := BrandMark.layers(b)
	if mode == "symbol":
		for l: Array in mark_layers:
			items.append([l[0], l[1]])
		var out := {"items": items, "bounds": _bounds(items), "mode": mode}
		_lockups[ck] = out
		return out
	var split := _split(name, bool(st["desc"]))
	var main_txt := _case(String(split[0]), String(st["case"]))
	var desc_txt := _case(String(split[1]), "lower" if String(st["case"]) == "lower" else "upper")
	var ts := LogoGeom.text_shape(main_txt, st["w"], st["wd"], st["tr"], st["sl"])
	var main_shape: Array = ts[0]
	var main_w: float = ts[1]
	var lay := String(st["lay"])
	if mode == "compact" and lay in ["left", "word"]:
		lay = "top"
	var desc_shape: Array = []
	var desc_w := 0.0
	if desc_txt != "":
		# No selo o descritor vem vazado: maior e mais pesado para o vazado não fechar
		var badge := String(st["lay"]).begins_with("badge")
		var dk := 0.5 if badge else 0.42
		var dw := float(st["w"]) - (120.0 if badge else 320.0)
		var dt := LogoGeom.text_shape(desc_txt, maxf(300.0, dw), clampf(float(st["wd"]) + 8.0, 50.0, 125.0), 0.12 if badge else 0.16, st["sl"])
		desc_shape = LogoGeom.xf_all(dt[0], Vector2.ZERO, 0.0, Vector2(dk, dk))
		desc_w = float(dt[1]) * dk
	# Texto: o nome e, se houver, o descritor pequeno em cima dele (alinhados à esquerda)
	var text_items: Array = []
	if desc_shape.is_empty():
		text_items.append([main_shape, 0])
	else:
		text_items.append([LogoGeom.xf_all(desc_shape, Vector2(0.03, -1.32)), 0])
		text_items.append([main_shape, 0])
	var tw := maxf(main_w, desc_w)
	var text_top := -1.32 - 0.42 if not desc_shape.is_empty() else -1.0
	match lay:
		"badge_slant", "badge_oval", "badge_pill", "badge_rect":
			items = _badge(lay, main_shape, main_w, desc_shape, desc_w)
		"top":
			var ms := 1.9
			for l: Array in mark_layers:
				items.append([LogoGeom.xf_all(l[0], Vector2(tw * 0.5, text_top - 0.38 - ms * 0.5), 0.0, Vector2(ms * 0.5, ms * 0.5)), l[1]])
			for t: Array in text_items:
				items.append(t)
		"word":
			for t: Array in text_items:
				items.append(t)
		_:
			# Símbolo à esquerda, da altura do bloco de texto
			var th := 1.0 - text_top
			var ms2 := maxf(1.45, th * 1.12)
			var cy := (text_top + 0.0) * 0.5
			for l: Array in mark_layers:
				items.append([LogoGeom.xf_all(l[0], Vector2(-0.42 - ms2 * 0.5, cy), 0.0, Vector2(ms2 * 0.5, ms2 * 0.5)), l[1]])
			for t: Array in text_items:
				items.append(t)
			if String(st["acc"]) == "slash":
				items.append([[_slash(Vector2(-0.18, cy), th)], 1])
	_accent(items, String(st["acc"]), main_w, lay)
	var out2 := {"items": items, "bounds": _bounds(items), "mode": mode}
	_lockups[ck] = out2
	return out2


## [nome principal, descritor] (o descritor só quando a marca tem mais de uma palavra).
static func _split(name: String, use_desc: bool) -> Array:
	var words := name.split(" ", false)
	if not use_desc or words.size() < 2:
		return [name, ""]
	var first := String(words[0]).to_lower()
	var last := String(words[words.size() - 1]).to_lower()
	if first in DESCRIPTORS:
		return [" ".join(words.slice(1)), String(words[0])]
	if last in DESCRIPTORS:
		return [" ".join(words.slice(0, words.size() - 1)), String(words[words.size() - 1])]
	if words.size() >= 3 and (" ".join(words.slice(words.size() - 2)).to_lower() in DESCRIPTORS):
		return [" ".join(words.slice(0, words.size() - 2)), " ".join(words.slice(words.size() - 2))]
	return [name, ""]


static func _case(t: String, c: String) -> String:
	match c:
		"upper":
			return t.to_upper()
		"lower":
			return t.to_lower()
	return t


static func _bounds(items: Array) -> Rect2:
	var all: Array = []
	for it: Array in items:
		all.append_array(it[0])
	return LogoGeom.bounds_all(all)


## Selo: a placa na cor da marca com o nome vazado (as letras viram furos da placa).
static func _badge(kind: String, main_shape: Array, main_w: float, desc_shape: Array, desc_w: float) -> Array:
	var pad_x := 0.55
	var top := -1.0 - 0.38
	var bot := 0.38
	var wmax := maxf(main_w, desc_w)
	var inner: Array = LogoGeom.xf_all(main_shape, Vector2((wmax - main_w) * 0.5, 0.0))
	if not desc_shape.is_empty():
		inner.append_array(LogoGeom.xf_all(desc_shape, Vector2((wmax - desc_w) * 0.5, 0.82)))
		bot += 0.66
	main_w = wmax
	var r := Rect2(-pad_x, top, main_w + pad_x * 2.0, bot - top)
	var plate: PackedVector2Array
	match kind:
		"badge_slant":
			var sk := r.size.y * 0.22
			plate = PackedVector2Array([Vector2(r.position.x + sk, r.position.y), Vector2(r.end.x + sk, r.position.y), Vector2(r.end.x - sk, r.end.y), Vector2(r.position.x - sk, r.end.y)])
		"badge_oval":
			plate = LogoGeom.ellipse(r.get_center(), r.size.x * 0.5 + 0.35, r.size.y * 0.5 + 0.28, 64)
		"badge_pill":
			plate = LogoGeom.rrect(r, r.size.y * 0.5, 10)
		_:
			plate = LogoGeom.rrect(r, 0.12, 4)
	return [[[plate] + inner, 0]]


static func _slash(c: Vector2, h: float) -> PackedVector2Array:
	var w := 0.16
	return PackedVector2Array([c + Vector2(0.08, -h * 0.5), c + Vector2(0.08 + w, -h * 0.5), c + Vector2(-0.08 + w, h * 0.5), c + Vector2(-0.08, h * 0.5)])


## Detalhes de marca (na cor de destaque): ponto depois do nome, barra ou traço curvo embaixo.
static func _accent(items: Array, acc: String, w: float, lay: String) -> void:
	if lay.begins_with("badge"):
		return
	match acc:
		"dot":
			items.append([[LogoGeom.circle(Vector2(w + 0.26, -0.13), 0.14, 20)], 1])
		"bar":
			items.append([[LogoGeom.rrect(Rect2(0.0, 0.24, w, 0.11), 0.02)], 1])
		"swoosh":
			var path := LogoGeom.quad(Vector2(-0.05, 0.5), Vector2(w * 0.5, 0.22), Vector2(w + 0.1, 0.24), 20)
			items.append([[LogoGeom.taper(path, 0.02, 0.17)], 1])
