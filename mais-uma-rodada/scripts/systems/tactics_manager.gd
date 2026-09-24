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
	return _fam_get(club, "f", fname)


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
	_learn(club.tactic_fam["f"], sheet.formation, learn)
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
