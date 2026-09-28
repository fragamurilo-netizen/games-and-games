class_name TacticsManager
extends RefCounted
## Entrosamento tático (o time aprende formações e estilos jogando com eles), planos de jogo
## automáticos e a leitura do auxiliar sobre o próximo adversário.

## Valor de quem nunca jogou naquela formação/estilo e de um clube que ainda não tem registro.
const FAM_FLOOR := 25.0
const FAM_START := 80.0
## Fração do que falta até 100 que se aprende a cada jogo (treino tático acelera).
const FAM_LEARN := 0.12
## Quanto se esquece por jogo do que não está sendo usado.
const FAM_DECAY := 1.5
## Peso no desempenho do time: de -1,5% (nada entrosado) a +3% (entrosamento total).
const FAM_MIN_F := 0.97
const FAM_SPAN := 0.06


## Entrosamento (0..100) do clube com uma formação.
static func formation_fam(club: Club, fname: String) -> float:
	# Variação personalizada: aproveita o que o time já sabe da base, com um pequeno custo por vaga mudada.
	var base := _fam_get(club, "f", DatabaseManager.formation_base(fname))
	return base * maxf(0.8, 1.0 - 0.04 * DatabaseManager.formation_overrides(fname).size())


## Entrosamento (0..100) do clube com um estilo de jogo.
static func style_fam(club: Club, style: int) -> float:
	return _fam_get(club, "s", str(style))


static func _fam_get(club: Club, kind: String, key: String) -> float:
	if club.tactic_fam.is_empty():
		return FAM_START
	var d: Dictionary = club.tactic_fam.get(kind, {})
	return float(d.get(key, FAM_FLOOR))


## Média de formação e estilo (0..100).
static func sheet_fam(club: Club, sheet: TeamSheet) -> float:
	return (formation_fam(club, sheet.formation) + style_fam(club, sheet.style)) * 0.5


## Multiplicador de desempenho do time pelo entrosamento tático.
static func fam_factor(club: Club, sheet: TeamSheet) -> float:
	return FAM_MIN_F + FAM_SPAN * sheet_fam(club, sheet) / 100.0


## Cria o registro do clube a partir da escalação atual (saves antigos e carreira nova).
static func ensure(club: Club) -> void:
	if not club.tactic_fam.is_empty() or club.sheet == null:
		return
	club.tactic_fam = {"f": {club.sheet.formation: FAM_START}, "s": {str(club.sheet.style): FAM_START}}


## Depois de cada jogo: aprende o que usou, esquece aos poucos o resto.
static func after_match(club: Club, sheet: TeamSheet, tactical_training: bool = false) -> void:
	if sheet == null:
		return
	ensure(club)
	var learn := FAM_LEARN * (1.5 if tactical_training else 1.0)
	_learn(club.tactic_fam["f"], DatabaseManager.formation_base(sheet.formation), learn)
	_learn(club.tactic_fam["s"], str(sheet.style), learn)


static func _learn(d: Dictionary, used: String, learn: float) -> void:
	for k in d.keys():
		if k != used:
			d[k] = maxf(FAM_FLOOR, float(d[k]) - FAM_DECAY)
	var v := float(d.get(used, FAM_FLOOR))
	d[used] = minf(100.0, v + (100.0 - v) * learn)


static func fam_label(v: float) -> String:
	if v >= 85.0:
		return "Dominado"
	if v >= 65.0:
		return "Entrosado"
	if v >= 45.0:
		return "Aprendendo"
	return "Novo"


static func fam_color(v: float) -> Color:
	if v >= 65.0:
		return UIColors.GREEN
	if v >= 45.0:
		return UIColors.ACCENT
	return UIColors.ORANGE


# ---------------------------------------------------------------------------
# Leitura do auxiliar
# ---------------------------------------------------------------------------

## Sugestão de mentalidade e estilo contra um adversário: {mentality, style, reasons}.
static func suggest(world: GameWorld, club: Club, opp: Club, is_home: bool) -> Dictionary:
	var reasons: Array = []
	var mine := ClubAI.team_strength(world, club)
	var theirs := ClubAI.team_strength(world, opp)
	var diff := mine - theirs + (1.5 if is_home else -1.5)
	var mentality := TeamSheet.MENT_EQUILIBRADA
	if diff >= 6.0:
		mentality = TeamSheet.MENT_OFENSIVA
		reasons.append("Somos claramente mais fortes: dá para mandar no jogo.")
	elif diff <= -8.0:
		mentality = TeamSheet.MENT_DEFENSIVA
		reasons.append("O adversário é bem mais forte: segurança primeiro.")
	elif diff <= -3.0:
		reasons.append("Jogo duro. Equilíbrio e paciência.")
	else:
		reasons.append("Forças parecidas: detalhes vão decidir.")
	var opp_sheet := opp.sheet
	var style := club.sheet.style if club.sheet != null else TeamSheet.STYLE_POSSE
	var scores := _style_scores(world, club)
	if opp_sheet != null:
		var width := _formation_width(opp_sheet.formation)
		# Rival que se lança ao ataque deixa espaço nas costas.
		if opp_sheet.mentality >= TeamSheet.MENT_OFENSIVA or opp_sheet.style == TeamSheet.STYLE_POSSE or opp_sheet.style == TeamSheet.STYLE_PRESSAO:
			scores[TeamSheet.STYLE_CONTRA] += 4.0
			reasons.append("Eles adiantam o time (%s): o contra-ataque encontra espaço." % _style_name(opp_sheet.style).to_lower())
		if width < 2.0:
			scores[TeamSheet.STYLE_LADOS] += 3.0
			reasons.append("O %s deles é estreito: os lados ficam livres." % opp_sheet.formation)
		if opp_sheet.style == TeamSheet.STYLE_PRESSAO:
			scores[TeamSheet.STYLE_LONGA] += 2.0
		if opp_sheet.mentality <= TeamSheet.MENT_DEFENSIVA:
			scores[TeamSheet.STYLE_POSSE] += 2.0
			scores[TeamSheet.STYLE_LADOS] += 1.5
			scores[TeamSheet.STYLE_CONTRA] -= 3.0
			reasons.append("Eles se fecham: vai precisar de paciência e amplitude.")
	# Entrosamento pesa: trocar para um estilo que o time não conhece custa caro.
	for i in scores.size():
		scores[i] += (style_fam(club, i) - 60.0) * 0.06
	var best := style
	var best_v := -1e9
	for i in scores.size():
		if scores[i] > best_v + 0.01:
			best_v = scores[i]
			best = i
	if best != style:
		reasons.append("Estilo indicado: %s." % _style_name(best).to_lower())
	return {"mentality": mentality, "style": best, "reasons": reasons}


## Quanto os titulares combinam com cada estilo (em pontos de atributo acima do overall).
static func _style_scores(world: GameWorld, club: Club) -> Array:
	var tac := DatabaseManager.tactics()
	var out: Array = []
	var sheet := club.sheet
	for st in tac["styles"]:
		var fit_sum := 0.0
		var n := 0
		if sheet != null:
			for i in sheet.starters.size():
				var p := world.player(sheet.starters[i])
				if p == null or i == 0:
					continue
				var s := 0.0
				for code in st["fit"]:
					s += p.attrs[DatabaseManager.attr_index(code)]
				fit_sum += s / st["fit"].size() - p.ovr_f
				n += 1
		out.append(fit_sum / maxf(1.0, n) * 0.5)
	return out


static func _formation_width(fname: String) -> float:
	var w := 0.0
	for s in DatabaseManager.formation(fname)["slots"]:
		w += float(s["wide"])
	return w


static func _style_name(i: int) -> String:
	return String(DatabaseManager.tactics()["styles"][clampi(i, 0, 5)]["name"])


# ---------------------------------------------------------------------------
# Instruções de equipe (ritmo, passe, marcação, perda da bola, foco, cera, escanteios)
# ---------------------------------------------------------------------------

## Propriedade do TeamSheet = lista de mesmo nome em tactics.json (ordem de TeamSheet.deep_values).
const DEEP: Array[String] = ["tempo", "passing", "marking", "transition", "focus", "time_waste", "corners"]
const DEEP_TITLES := {"tempo": "Ritmo", "passing": "Passe", "marking": "Marcação", "transition": "Na perda da bola",
	"focus": "Foco do ataque", "time_waste": "Ganhar tempo", "corners": "Escanteios"}
const DEEP_DEFAULT: Array[int] = [1, 1, 0, 1, 1, 0, 0]
## Peso do encaixe do elenco numa instrução: por ponto de atributo acima/abaixo do overall.
const DEEP_FIT_K := 0.004
const DEEP_FIT_MAX := 0.035

static var _deep_cache: Dictionary = {}


static func deep_options(key: String) -> Array:
	return DatabaseManager.tactics().get(key, [])


static func deep_option(key: String, i: int) -> Dictionary:
	var opts := deep_options(key)
	if opts.is_empty():
		return {}
	return opts[clampi(i, 0, opts.size() - 1)]


## Nome curto da opção escolhida ("Acelerado", "Contrapressão"...).
static func deep_name(key: String, i: int) -> String:
	return String(deep_option(key, i).get("name", ""))


## Multiplicadores somados das instruções de equipe (cacheado pela combinação). Os efeitos que
## dependem do elenco (encaixe "fit") e do placar (cera) ficam listados para o MatchTeam aplicar.
static func deep_mods(vals: Array) -> Dictionary:
	var key := str(vals)
	if _deep_cache.has(key):
		return _deep_cache[key]
	var out := {
		"rate": 1.0, "quality": 1.0, "opp_rate": 1.0, "opp_quality": 1.0, "poss": 0.0, "fatigue": 1.0, "fouls": 1.0,
		"offside": 1.0, "offside_own": 1.0, "lanes": [1.0, 1.0, 1.0], "lead_rate": 1.0, "lead_opp_rate": 1.0, "lead_cards": 1.0,
		"corner_ch": 1.0, "corner_q": 1.0, "aerial": 1.0, "fits": [],
		"types": PackedFloat32Array([1, 1, 1, 1, 1, 1]), "opp_types": PackedFloat32Array([1, 1, 1, 1, 1, 1]),
	}
	for k in DEEP.size():
		var v: int = int(vals[k]) if k < vals.size() else DEEP_DEFAULT[k]
		var o := deep_option(DEEP[k], v)
		if o.is_empty():
			continue
		for f in ["rate", "quality", "opp_rate", "opp_quality"]:
			out[f] = float(out[f]) * MatchSimulation.damp(float(o.get(f, 1.0)))
		out["poss"] = float(out["poss"]) + float(o.get("poss", 0.0)) * MatchSimulation.MOD_DAMP
		for f in ["fatigue", "fouls", "offside", "offside_own", "lead_rate", "lead_opp_rate", "lead_cards", "corner_ch", "corner_q", "aerial"]:
			out[f] = float(out[f]) * float(o.get(f, 1.0))
		if o.has("lanes"):
			var ln: Array = out["lanes"]
			for i in 3:
				ln[i] = float(ln[i]) * float(o["lanes"][i])
		for pair in [["types", "types"], ["opp_types", "opp_types"]]:
			var arr: PackedFloat32Array = out[pair[0]]
			var src: Dictionary = o.get(pair[1], {})
			for i in MatchSimulation.CH_KEYS.size():
				arr[i] *= float(src.get(MatchSimulation.CH_KEYS[i], 1.0))
			out[pair[0]] = arr
		if o.has("fit"):
			var ids: Array = []
			for code in o["fit"]:
				ids.append(DatabaseManager.attr_index(code))
			out["fits"].append([ids, String(o.get("fit_on", "quality"))])
	_deep_cache[key] = out
	return out


## Encaixe (pontos de atributo acima do overall, média) → ajuste de -3,5% a +3,5%.
static func fit_bonus(fit_points: float) -> float:
	return clampf(fit_points * DEEP_FIT_K, -DEEP_FIT_MAX, DEEP_FIT_MAX)


## Choque de ideias entre quem ataca (a) e quem defende (d): multiplicador da taxa de chances de
## quem ataca. Descrições: MatchTeam.clash_desc / QuickMatch (passing, pressing, line, marking,
## transition, tech, pace_att, pace_def, lane_rel).
static func clash(a: Dictionary, d: Dictionary) -> float:
	var m := 1.0
	var tech := float(a.get("tech", 64.0))
	var passing := int(a.get("passing", 1))
	# Passe curto contra pressão alta: o time técnico sai jogando e acha espaço; o sem técnica se enrola.
	if passing == 0 and int(d.get("pressing", 1)) == 2:
		m *= 1.0 - 0.05 * clampf((66.0 - tech) / 12.0, -0.6, 1.0)
	# Bola direta contra linha alta: velocidade dos atacantes contra a dos zagueiros.
	if passing == 2:
		var line := int(d.get("line", 1))
		if line == 2:
			m *= 1.0 + 0.05 * clampf((float(a.get("pace_att", 60.0)) - float(d.get("pace_def", 60.0))) / 12.0, -0.5, 1.0)
		elif line == 0:
			m *= 0.97
	# Marcação individual contra time técnico: o drible arrasta o marcador. Contra time sem técnica, sufoca.
	if int(d.get("marking", 0)) == 1:
		m *= 1.0 + 0.04 * clampf((tech - 64.0) / 10.0, -1.0, 1.0)
	# Contrapressão: a bola direta passa por cima; o passe curto cai na armadilha.
	if int(d.get("transition", 1)) == 2:
		m *= 1.03 if passing == 2 else (0.98 if passing == 0 else 1.0)
	# Foco num corredor: rende contra o lado fraco do rival, trava contra o forte.
	m *= clampf(1.0 + 0.25 * (float(a.get("lane_rel", 1.0)) - 1.0), 0.94, 1.06)
	return m


## Resumo das instruções de equipe fora do padrão ("Acelerado · Contrapressão · Foco: esquerda").
static func deep_summary(sheet: TeamSheet) -> String:
	var vals := sheet.deep_values()
	var parts: Array = []
	for k in DEEP.size():
		if int(vals[k]) == DEEP_DEFAULT[k]:
			continue
		var nm := deep_name(DEEP[k], int(vals[k]))
		match DEEP[k]:
			"focus":
				nm = "Foco: " + nm.to_lower()
			"corners":
				nm = "Escanteio " + nm.to_lower()
			"marking":
				nm = "Marcação " + nm.to_lower()
			"passing":
				nm = "Passe " + nm.to_lower()
		parts.append(nm)
	return " · ".join(PackedStringArray(parts))


## Instruções de equipe da IA a partir da filosofia (campos opcionais tempo/passing/marking/
## transition/corners em philosophies.json) e do jogo: azarão recompõe e faz cera, time cansado
## não faz contrapressão, time baixo não cruza no segundo pau. Determinístico.
static func ai_deep(world: GameWorld, club: Club, sheet: TeamSheet, ph: Dictionary, diff: float, roll: float) -> void:
	var adapt := float(ph.get("adapt", 0.3))
	sheet.tempo = clampi(int(ph.get("tempo", 1)), 0, 2)
	sheet.passing = clampi(int(ph.get("passing", 1)), 0, 2)
	sheet.marking = clampi(int(ph.get("marking", 0)), 0, 1)
	sheet.transition = clampi(int(ph.get("transition", 1)), 0, 2)
	sheet.focus = 1
	sheet.corners = clampi(int(ph.get("corners", 0)), 0, 3)
	sheet.time_waste = 0
	# Azarão pragmático: recompõe sempre e segura o resultado quando estiver na frente.
	if diff <= -6.0 and roll < adapt + 0.2:
		sheet.transition = 0
		sheet.time_waste = 1
		if sheet.tempo == 2 and diff <= -10.0:
			sheet.tempo = 1
	elif sheet.mentality <= TeamSheet.MENT_DEFENSIVA:
		sheet.time_waste = 1 if roll < adapt else 0
	# Sem fôlego, nada de contrapressão.
	if sheet.transition == 2 and ClubPhilosophy._avg_condition(world, sheet) < 82.0:
		sheet.transition = 1
	# Escanteio pelo tamanho do time: baixinhos batem curto ou no primeiro pau.
	var h := 0.0
	var n := 0
	for pid in sheet.starters:
		var p := world.player(pid)
		if p != null and p.position != Pos.GK:
			h += p.height
			n += 1
	h = h / n if n > 0 else 181.0
	if sheet.corners == 2 and h < 180.0:
		sheet.corners = 1
	elif sheet.corners == 0 and h >= 184.0 and roll < 0.6:
		sheet.corners = 2
