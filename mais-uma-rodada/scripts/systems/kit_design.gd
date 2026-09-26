class_name KitDesign
extends RefCounted
## Leitura "de arquibancada" dos uniformes: quais cores aparecem e em que proporção (a estampa
## conta pela área que ocupa na camisa), e quão diferentes dois uniformes parecem em campo.
## Garante que titular, reserva e terceiro de um clube nunca sejam da mesma cor, renova os
## uniformes dos clubes da IA a cada temporada e guarda o histórico de uniformes do clube.

## Distância mínima (ΔE médio, escala CIELAB) entre os uniformes de linha de um mesmo clube.
const MIN_OWN := 42.0
## Distância mínima para dois times entrarem em campo sem confusão.
const MIN_MATCH := 34.0

static var _cov_cache := {}


# ---------------------------------------------------------------------------
# Cores
# ---------------------------------------------------------------------------

static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0


## Cor em CIELAB (D65).
static func lab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var b := _lin(c.b)
	var x := (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
	var y := r * 0.2126 + g * 0.7152 + b * 0.0722
	var z := (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
	var fx := _f(x)
	var fy := _f(y)
	var fz := _f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


## Diferença percebida entre duas cores (ΔE76: ~2 mal se nota, ~25 é outra cor, 100+ opostas).
static func delta_e(a: Color, b: Color) -> float:
	return lab(a).distance_to(lab(b))


## Fração do corpo da camisa coberta pela estampa (c2) e pela terceira cor (c3 das tricolores).
static func coverage(pattern: String) -> Vector2:
	if _cov_cache.has(pattern):
		return _cov_cache[pattern]
	var body := PackedVector2Array(KitView.BODY)
	var total := _area(body)
	var out := Vector2.ZERO
	if pattern in KitView.GRADIENTS:
		out = Vector2(0.4, 0.0)
	elif pattern != "plain":
		out = Vector2(_covered(KitView.pattern_bands(pattern), body) / total, _covered(KitView.pattern_bands3(pattern), body) / total)
		out.x = clampf(out.x, 0.0, 0.9)
		out.y = clampf(out.y, 0.0, 0.9)
	_cov_cache[pattern] = out
	return out


static func _covered(bands: Array, body: PackedVector2Array) -> float:
	var a := 0.0
	for band: PackedVector2Array in bands:
		for piece in Geometry2D.intersect_polygons(band, body):
			a += _area(piece)
	return a


static func _area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		s += p.x * q.y - q.x * p.y
	return absf(s) * 0.5


## Cores do uniforme como se vê de longe: [[Color, peso], ...] somando 1 (camisa 80%, calção 20%).
static func swatches(k: Dictionary) -> Array:
	var c1 := Color(String(k.get("c1", "#FFFFFF")))
	var c2 := Color(String(k.get("c2", "#000000")))
	var c3 := Color(String(k.get("c3", k.get("c2", "#000000"))))
	var out: Array = []
	var shirt := 0.8
	if bool(k.get("tonal", false)):
		out.append([c1, shirt])
	else:
		var cov := coverage(String(k.get("pattern", "plain")))
		var w2 := cov.x
		var w3 := cov.y
		# Mangas de outra cor pesam na camisa
		if String(k.get("sleeve", "same")) in ["contrast", "raglan"]:
			w2 = minf(0.9, w2 + 0.15)
		out.append([c1, shirt * maxf(0.1, 1.0 - w2 - w3)])
		if w2 > 0.0:
			out.append([c2, shirt * w2])
		if w3 > 0.0:
			out.append([c3, shirt * w3])
	out.append([Color(String(k.get("shorts", k.get("c2", "#111111")))), 1.0 - shirt])
	var tot := 0.0
	for s in out:
		tot += float(s[1])
	for s in out:
		s[1] = float(s[1]) / tot
	return out


## Cor que domina o uniforme (a de maior área).
static func dominant(k: Dictionary) -> Color:
	var best: Array = [Color.WHITE, -1.0]
	for s in swatches(k):
		if float(s[1]) > float(best[1]):
			best = s
	return best[0]


## Quão diferentes dois uniformes parecem em campo: quanto de "tinta" é preciso trocar para
## transformar um no outro (distância de transporte entre as cores, pesada pela área). Vermelho com
## detalhe branco contra branco com detalhe vermelho dá longe; as mesmas cores na mesma
## proporção, com outra estampa, dá perto. 0 = iguais.
static func distance(a: Dictionary, b: Dictionary) -> float:
	var sa := swatches(a)
	var sb := swatches(b)
	var pairs: Array = []
	for i in sa.size():
		for j in sb.size():
			pairs.append([delta_e(sa[i][0], sb[j][0]), i, j])
	pairs.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var ra: Array = []
	for s in sa:
		ra.append(float(s[1]))
	var rb: Array = []
	for s in sb:
		rb.append(float(s[1]))
	var d := 0.0
	for p in pairs:
		var f := minf(float(ra[p[1]]), float(rb[p[2]]))
		if f <= 0.0:
			continue
		d += f * float(p[0])
		ra[p[1]] = float(ra[p[1]]) - f
		rb[p[2]] = float(rb[p[2]]) - f
	return d


## As cores principais dos dois uniformes batem (mesmo que a estampa mude)?
## Azul-royal e azul-claro contam como "a mesma cor" (mesmo matiz, os dois bem coloridos).
static func same_main_color(a: Dictionary, b: Dictionary) -> bool:
	return same_family(dominant(a), dominant(b))


static func same_family(ca: Color, cb: Color) -> bool:
	var la := lab(ca)
	var lb := lab(cb)
	var d := la.distance_to(lb)
	if d < 30.0:
		return true
	var cha := Vector2(la.y, la.z)
	var chb := Vector2(lb.y, lb.z)
	if cha.length() < 25.0 or chb.length() < 25.0:
		return false
	return absf(rad_to_deg(cha.angle_to(chb))) < 22.0 and d < 60.0


## Dois uniformes do mesmo clube estão parecidos demais?
static func clash(a: Dictionary, b: Dictionary) -> bool:
	return distance(a, b) < MIN_OWN or same_main_color(a, b)


## Nota de 0 a 100 de quão diferentes são (para o editor mostrar).
static func contrast_score(a: Dictionary, b: Dictionary) -> int:
	return clampi(int(round(distance(a, b) / 80.0 * 100.0)), 0, 100)


# ---------------------------------------------------------------------------
# Uniformes do clube
# ---------------------------------------------------------------------------

## Qual uniforme o visitante usa contra o mandante: "home", "away" ou "third" (ou "" se nenhum serve).
static func away_choice(home: Club, away: Club) -> String:
	var hk := home.kit_home
	var best := ""
	var best_d := -1.0
	for which in ["home", "away", "third"]:
		var k: Dictionary = away.kit_home if which == "home" else (away.kit_away if which == "away" else away.third_kit())
		if k.is_empty():
			continue
		var d := distance(hk, k)
		if d >= MIN_MATCH and not same_main_color(hk, k):
			return which
		if d > best_d:
			best_d = d
			best = which
	return best if best_d >= MIN_MATCH * 0.6 else ""


## Conserta reserva (e terceiro) que ficaram da cor do titular. Retorna true se mudou algo.
static func ensure_distinct(c: Club) -> bool:
	var changed := false
	if c.kit_home.is_empty():
		return false
	if c.kit_away.is_empty() or clash(c.kit_home, c.kit_away):
		var kr := RandomNumberGenerator.new()
		kr.seed = hash(c.key + ":away_fix")
		var keep := _sponsor_keys(c.kit_away)
		c.kit_away = ClubGenerator.away_kit(kr, c, c.kit_home)
		c.kit_away.merge(keep, true)
		changed = true
	if not c.kit_third.is_empty() and (clash(c.kit_home, c.kit_third) or clash(c.kit_away, c.kit_third)):
		c.kit_third = {}
		c.kit_third = ClubGenerator.make_third_kit(c)
		changed = true
	return changed


static func _sponsor_keys(k: Dictionary) -> Dictionary:
	var out := {}
	for key in k:
		if String(key).begins_with("sp") or key == "sup":
			out[key] = k[key]
	return out


## Todos os clubes do mundo (saves antigos, e depois de mudar as cores do clube).
static func ensure_all(world: GameWorld) -> int:
	var n := 0
	for c: Club in world.clubs:
		if ensure_distinct(c):
			n += 1
	return n


## Virada de temporada: os clubes da IA lançam uniformes novos. O titular mantém a identidade
## (a estampa tradicional volta na maioria dos anos); reserva e terceiro mudam mais.
static func renew_ai(world: GameWorld, c: Club) -> void:
	if world.is_user_club(c.id) or c.kit_home.is_empty():
		return
	var kr := RandomNumberGenerator.new()
	kr.seed = hash([c.key, world.year, "kits"])
	var old_pat := String(c.kit_home.get("pattern", "plain"))
	if bool(c.kit_home.get("tonal", false)):
		old_pat = "plain"
	var hint := old_pat if kr.randf() < 0.75 else ""
	var sp_h := _sponsor_keys(c.kit_home)
	var sp_a := _sponsor_keys(c.kit_away)
	c.kit_home = ClubGenerator.home_kit(kr, c, hint)
	c.kit_home.merge(sp_h, true)
	c.kit_away = ClubGenerator.away_kit(kr, c, c.kit_home)
	c.kit_away.merge(sp_a, true)
	c.kit_third = {}
	c.kit_gk = {}


# ---------------------------------------------------------------------------
# Propostas para o editor
# ---------------------------------------------------------------------------

## As três linhas de coleção que a fornecedora apresenta todo ano: [nome, descrição].
const COLLECTIONS: Array = [
	["Raízes", "O desenho tradicional do clube, com acabamento clássico."],
	["Contemporânea", "Linhas limpas, estampa discreta tom sobre tom e detalhes finos."],
	["Ousada", "Estampa forte na titular e um terceiro uniforme feito para vender camisa."],
]
const BOLD_PATTERNS := ["chevron", "v_big", "diagonal_split", "sash_double", "harlequin", "shatter", "sunburst", "halves",
	"quarters", "hoop_fade", "center_panel", "tricolor_v", "wide_stripes", "zigzag", "side_panels", "double_band"]


## Coleção `idx` da temporada: {name, desc, h, a, t}. Titular, reserva e terceiro saem do mesmo
## molde (gola, mangas e acabamento) e nunca repetem a cor entre si.
static func collection(c: Club, year: int, idx: int) -> Dictionary:
	var kr := RandomNumberGenerator.new()
	kr.seed = hash([c.key, year, "colecao", idx])
	var style := idx % COLLECTIONS.size()
	var cur := String(c.kit_home.get("pattern", "plain"))
	if bool(c.kit_home.get("tonal", false)):
		cur = "plain"
	var hint := cur
	match style:
		1:
			hint = "plain"
		2:
			hint = String(RngUtil.pick(kr, BOLD_PATTERNS))
	if style == 0 and idx >= COLLECTIONS.size() and kr.randf() < 0.5:
		hint = String(RngUtil.pick(kr, ClubGenerator.HOME_PATTERNS.keys()))
	var h := ClubGenerator.home_kit(kr, c, hint)
	match style:
		0:
			h["collar"] = RngUtil.pick(kr, ["round", "polo", "ringer", "retro", "v", "henley"])
			h["sleeve"] = RngUtil.pick(kr, ["cuff", "same", "tipped"])
			h.erase("tonal")
			h["pattern"] = hint
		1:
			h["pattern"] = RngUtil.pick(kr, ClubGenerator.TONAL)
			h["tonal"] = true
			h["collar"] = RngUtil.pick(kr, ["v", "crossover", "round", "mandarin"])
			h["sleeve"] = RngUtil.pick(kr, ["same", "cuff_double", "shoulder_stripe"])
			h["trim"] = RngUtil.pick(kr, ["none", "sides", "shoulders"])
		2:
			h.erase("tonal")
			h["collar"] = RngUtil.pick(kr, ["v", "crossover", "zip", "mandarin", "wide"])
			h["trim"] = RngUtil.pick(kr, ["sides", "both", "none"])
	var a := ClubGenerator.away_kit(kr, c, h)
	var t := ClubGenerator.third_for(kr, c, h, a)
	for i in 2:
		var k: Dictionary = a if i == 0 else t
		var fam := k.duplicate()
		for key in ["collar", "sleeve", "sleeve_len", "trim"]:
			if h.has(key):
				fam[key] = h[key]
		if String(fam.get("sleeve", "same")) in ["contrast", "raglan"]:
			fam["sleeve"] = "cuff"
		if not clash(h, fam) and (i == 0 or not clash(a, fam)):
			k.merge(fam, true)
	recolor_distinct(c, a, [h])
	recolor_distinct(c, t, [h, a])
	return {"name": String(COLLECTIONS[style][0]), "desc": String(COLLECTIONS[style][1]), "h": h, "a": a, "t": t}


## Combinações de cores prontas para o uniforme `which`, nas cores do clube (e, para reserva e
## terceiro, algumas da moda). As que deixariam o uniforme igual ao titular ficam de fora.
## Cada item: {c1, c2, c3, shorts, shorts2, socks, socks2}.
static func colourways(c: Club, which: String, k: Dictionary) -> Array:
	var p := c.color1
	var s := c.color2
	var pairs: Array = []
	match which:
		"home":
			pairs = [[p, s, s], [p, s, "w"], [p, "w", s], [s, p, p], [p, p, s], [p, s, "k"]]
		"gk":
			for g in ClubGenerator.GK_COLORS:
				pairs.append([g[0], g[1], g[0]])
		_:
			pairs = [["w", p, "w"], ["k", p, "k"], [s, p, s], ["n", p, "n"], ["w", s, p], ["#E8DCC4", p, "#E8DCC4"]]
			for tc in ["#2BB3A3", "#B8A1E3", "#F28C28", "#C7F464", "#7A1F3D", "#9AD1F5"]:
				pairs.append([tc, "", tc])
	var out: Array = []
	var seen := {}
	for pr in pairs:
		var c1 := _hex(String(pr[0]))
		var c2 := _hex(String(pr[1])) if String(pr[1]) != "" else ClubGenerator._accent(c1, [p, s])
		if delta_e(Color(c1), Color(c2)) < 25.0:
			c2 = ClubGenerator._accent(c1, [s, p])
		var sh := _hex(String(pr[2]))
		var cw := {"c1": c1, "c2": c2, "c3": c2, "shorts": sh, "shorts2": c2 if delta_e(Color(sh), Color(c2)) > 25.0 else c1,
			"socks": c1, "socks2": c2}
		var key := "%s|%s|%s" % [c1, c2, sh]
		if seen.has(key):
			continue
		seen[key] = true
		if which in ["away", "third"]:
			var test := k.duplicate()
			test.merge(cw, true)
			if clash(c.kit_home, test):
				continue
			if which == "third" and clash(c.kit_away, test):
				continue
		out.append(cw)
		if out.size() >= 8:
			break
	return out


static func _hex(role: String) -> String:
	match role:
		"w":
			return "#FFFFFF"
		"k":
			return "#111111"
		"n":
			return "#0B1F4B"
	return "#" + Color(role).to_html(false).to_upper()


## Recolore `k` (mantendo o desenho) para não bater com nenhum dos `others`. Retorna true se mudou.
static func recolor_distinct(c: Club, k: Dictionary, others: Array) -> bool:
	var bad := false
	for o: Dictionary in others:
		if clash(o, k):
			bad = true
	if not bad:
		return false
	var cands: Array = ["#FFFFFF", "#15181D", c.color2, c.color1, "#0B1F4B", "#E8DCC4"]
	cands.append_array(ClubGenerator.THIRD_COLORS)
	var best: Dictionary = {}
	var best_d := -1.0
	for c1x in cands:
		var c1 := _hex(String(c1x))
		var c2 := ClubGenerator._accent(c1, [c.color1, c.color2])
		var test := k.duplicate()
		test.merge({"c1": c1, "c2": c2, "c3": c2, "shorts": c1, "shorts2": c2, "socks": c1, "socks2": c2}, true)
		test.erase("nc")
		var worst := INF
		var ok := true
		for o: Dictionary in others:
			worst = minf(worst, distance(o, test))
			if clash(o, test):
				ok = false
		if ok:
			best = test
			break
		if worst > best_d:
			best_d = worst
			best = test
	k.clear()
	k.merge(best)
	return true


# ---------------------------------------------------------------------------
# Lançamento e histórico (clube do usuário)
# ---------------------------------------------------------------------------

## O jogo ainda não perguntou sobre os uniformes desta temporada?
## (O convite aparece uma vez por pré-temporada.)
static func launch_pending(world: GameWorld) -> bool:
	return world != null and world.has_user() and SponsorManager.is_preseason(world) \
		and int(world.stats.get("kit_ask", -1)) != world.year and not launched(world)


static func mark_asked(world: GameWorld) -> void:
	world.stats["kit_ask"] = world.year


## Os uniformes desta temporada já foram apresentados (ou mantidos)?
static func launched(world: GameWorld) -> bool:
	return world != null and int(world.stats.get("kit_launch", -1)) == world.year


static func mark_launched(world: GameWorld) -> void:
	world.stats["kit_ask"] = world.year
	world.stats["kit_launch"] = world.year
	record(world, world.user_club())


## Guarda os quatro uniformes da temporada no histórico do clube (substitui o do mesmo ano).
static func record(world: GameWorld, c: Club) -> void:
	if c == null or c.kit_home.is_empty():
		return
	c.kit_history[str(world.year)] = {
		"h": c.kit_home.duplicate(true), "a": c.kit_away.duplicate(true),
		"t": c.third_kit().duplicate(true), "g": c.gk_kit().duplicate(true),
		"coach": world.manager_name,
	}


## Temporadas do histórico, da mais recente para a mais antiga: [[ano, {h, a, t, g}], ...].
static func history(c: Club) -> Array:
	var out: Array = []
	for y in c.kit_history:
		out.append([int(y), c.kit_history[y]])
	out.sort_custom(func(a, b): return int(a[0]) > int(b[0]))
	return out
