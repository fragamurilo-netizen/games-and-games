class_name TacticalScout
extends RefCounted
## Os times se estudam. Cada clube guarda um diário tático dos últimos jogos (`Club.tac_log`):
## desenho, estilo, pressão, linha, gols e xG a favor e contra, posse e de que tipo de jogada
## saíram os gols marcados e sofridos. Com isso qualquer um pode ler o adversário:
##   - `profile()`: como o time joga e onde sofre (bola aérea, contra-ataque, chute de fora...).
##   - `vulnerability()`: por tipo de jogada, quanto o adversário sofre acima ou abaixo da média.
##   - `exploit()`: quanto um plano de jogo aproveita essas brechas, na medida do estudo de quem
##     prepara o time (técnico da IA ou auxiliar do usuário). Vale nos dois motores de partida.
##   - `counter_plan()`: o plano completo (mentalidade, estilo, pressão, linha, largura,
##     intensidade) com os motivos — usado pelo auxiliar do usuário e pela IA.
##   - `ai_adjust()`: a IA muda o plano para cada jogo conforme o rival, sem perder a identidade.

const LOG_MAX := 12

## Categorias de gol pelo tipo de chance do motor (MatchSimulation.CH_*).
const CATS: Array[String] = ["jogada", "aereo", "longe", "contra", "sobra", "penalti"]
const CAT_OF_CT: Array[int] = [0, 1, 2, 0, 3, 4, 1, 2, 5, 4] # através, cruz., longe, drible, contra, sobra, esc., falta, pên., erro
## Parte média de cada categoria nos gols (medida nos motores; serve de referência).
const CAT_BASE: Array[float] = [0.37, 0.27, 0.06, 0.15, 0.08, 0.07]
const CAT_NAMES: Array[String] = ["jogadas trabalhadas", "bola aérea", "chutes de fora", "contra-ataque", "rebotes e erros", "pênaltis"]
## Peso do "palpite" na estimativa (gols a priori): poucos jogos dizem pouco.
const PRIOR := 6.0


# ---------------------------------------------------------------------------
# Diário tático
# ---------------------------------------------------------------------------

## Registra um jogo no diário dos dois clubes. `res` = resultado comum (QuickMatch/MatchSimulation).
static func record(world: GameWorld, f: Fixture, res: Dictionary, home_sheet: TeamSheet, away_sheet: TeamSheet) -> void:
	var tac: Dictionary = res.get("tac", {})
	var cts: Array = tac.get("ct", [])
	var xg: Array = tac.get("xg", [0.0, 0.0])
	var poss := float(res.get("poss", 0.5))
	for side in 2:
		var club := world.club(f.home if side == 0 else f.away)
		var sheet := home_sheet if side == 0 else away_sheet
		if club == null:
			continue
		var gt: Array = []
		var ct: Array = []
		var late := 0
		for g in cts:
			var c := CAT_OF_CT[clampi(int(g[1]), 0, CAT_OF_CT.size() - 1)]
			if int(g[0]) == side:
				gt.append(c)
			else:
				ct.append(c)
				if int(g[2]) >= 75 and int(g[3]) == 2:
					late += 1
		var e := {
			"o": f.away if side == 0 else f.home, "h": 1 if side == 0 else 0,
			"gf": f.hg if side == 0 else f.ag, "ga": f.ag if side == 0 else f.hg,
			"xf": snappedf(float(xg[side]), 0.01), "xa": snappedf(float(xg[1 - side]), 0.01),
			"ps": int(round((poss if side == 0 else 1.0 - poss) * 100.0)), "gt": gt, "ct": ct, "lt": late,
		}
		if sheet != null:
			e["f"] = DatabaseManager.formation_base(sheet.formation)
			e["st"] = sheet.style
			e["m"] = sheet.mentality
			e["p"] = sheet.pressing
			e["l"] = sheet.line
			e["w"] = sheet.width
		club.tac_log.append(e)
		if club.tac_log.size() > LOG_MAX:
			club.tac_log = club.tac_log.slice(club.tac_log.size() - LOG_MAX)


# ---------------------------------------------------------------------------
# Leitura de um time
# ---------------------------------------------------------------------------

static var _pcache: Dictionary = {}


## Como o time joga e onde sofre, pelo diário. Sem jogos, usa a filosofia e o elenco.
## Guardado em cache até o diário mudar (é lido centenas de vezes por rodada).
static func profile(world: GameWorld, club: Club) -> Dictionary:
	var stamp := [world.get_instance_id(), club.tac_log.size(), hash(club.tac_log.back()) if not club.tac_log.is_empty() else 0]
	var hit: Array = _pcache.get(club.id, [])
	if hit.size() == 2 and hit[0] == stamp:
		return hit[1]
	var prof := _build_profile(world, club)
	if _pcache.size() > 4000:
		_pcache.clear()
	_pcache[club.id] = [stamp, prof]
	return prof


static func _build_profile(world: GameWorld, club: Club) -> Dictionary:
	var log: Array = club.tac_log
	var n := log.size()
	var out := {"n": n, "gf": 0.0, "ga": 0.0, "xf": 0.0, "xa": 0.0, "poss": 0.0,
		"conc": [0, 0, 0, 0, 0, 0], "scor": [0, 0, 0, 0, 0, 0], "late": 0, "ga_n": 0, "gf_n": 0,
		"home_pts": 0.0, "home_n": 0, "away_pts": 0.0, "away_n": 0}
	var forms := {}
	var styles := {}
	var press := 0.0
	var line := 0.0
	var ment := 0.0
	var width := 0.0
	var tac_n := 0
	for e: Dictionary in log:
		out["gf"] += float(e.get("gf", 0))
		out["ga"] += float(e.get("ga", 0))
		out["xf"] += float(e.get("xf", 0.0))
		out["xa"] += float(e.get("xa", 0.0))
		out["poss"] += float(e.get("ps", 50))
		for c in e.get("ct", []):
			out["conc"][int(c)] += 1
			out["ga_n"] += 1
		for c in e.get("gt", []):
			out["scor"][int(c)] += 1
			out["gf_n"] += 1
		out["late"] += int(e.get("lt", 0))
		var pts := 3.0 if int(e["gf"]) > int(e["ga"]) else (1.0 if int(e["gf"]) == int(e["ga"]) else 0.0)
		if int(e.get("h", 1)) == 1:
			out["home_pts"] += pts
			out["home_n"] += 1
		else:
			out["away_pts"] += pts
			out["away_n"] += 1
		if e.has("f"):
			forms[e["f"]] = int(forms.get(e["f"], 0)) + 1
			styles[int(e["st"])] = int(styles.get(int(e["st"]), 0)) + 1
			press += float(e["p"])
			line += float(e["l"])
			ment += float(e["m"])
			width += float(e.get("w", 1))
			tac_n += 1
	if n > 0:
		for k in ["gf", "ga", "xf", "xa"]:
			out[k] = out[k] / n
		out["poss"] = out["poss"] / n - 50.0 # desvio em relação a 50%
	var ph := ClubPhilosophy.of(club)
	out["formation"] = _top(forms, club.sheet.formation if club.sheet != null else String(ClubPhilosophy.formations(club)[0]))
	out["style"] = int(_top(styles, club.sheet.style if club.sheet != null else int(ph.get("style", 0))))
	out["pressing"] = press / tac_n if tac_n > 0 else float(ph.get("pressing", 1))
	out["line"] = line / tac_n if tac_n > 0 else float(ph.get("line", 1))
	out["mentality"] = ment / tac_n if tac_n > 0 else float(ph.get("mentality", 2))
	out["width"] = width / tac_n if tac_n > 0 else 1.0
	return out


static func _top(d: Dictionary, fallback: Variant) -> Variant:
	var best: Variant = fallback
	var bv := 0
	for k in d:
		if int(d[k]) > bv:
			bv = int(d[k])
			best = k
	return best


## Quanto o time sofre de cada categoria em relação à média (1 = normal), já com o "palpite".
static func cat_vuln(prof: Dictionary) -> Array:
	var total := float(prof["ga_n"])
	var out: Array = []
	for i in CATS.size():
		var share := (float(prof["conc"][i]) + PRIOR * CAT_BASE[i]) / (total + PRIOR)
		out.append(clampf(share / CAT_BASE[i], 0.6, 1.8))
	return out


## Vulnerabilidade por tipo de chance de jogada (CH_THROUGH..CH_SCRAMBLE), temperada pelo
## volume: quem sofre muitos gols no geral é mais explorável.
static func vulnerability(world: GameWorld, club: Club) -> PackedFloat32Array:
	var prof := profile(world, club)
	if prof.has("_v"):
		return prof["_v"]
	var cv := cat_vuln(prof)
	var out := PackedFloat32Array()
	for ct in 6:
		out.append(clampf(float(cv[CAT_OF_CT[ct]]), 0.7, 1.5))
	prof["_v"] = out
	return out


## Qualidade do estudo de quem prepara o time (0..1): o técnico da IA ou o auxiliar do usuário.
static func study(world: GameWorld, club: Club) -> float:
	if world.is_user_club(club.id):
		return clampf(People.staff_level(world, "auxiliar") * 0.9 + 0.1, 0.1, 1.0)
	var co := People.coach_of(world, club.id)
	if co.is_empty():
		return 0.4
	var sk := float(co.get("sk", 50.0)) / 100.0
	var mult := {"estrategista": 1.3, "pragmatico": 1.1, "linha_dura": 1.0, "formador": 0.95, "motivador": 0.85, "ofensivo": 0.85}
	return clampf(sk * float(mult.get(String(co.get("st", "")), 1.0)), 0.1, 1.0)


## O que o plano aproveita das brechas do rival: [pesos por tipo, qualidade por tipo, ganho médio].
## O estilo escolhe os tipos de jogada; o estudo decide o quanto se mira no ponto fraco.
static func exploit(style_types: PackedFloat32Array, vuln: PackedFloat32Array, stu: float) -> Array:
	var w := PackedFloat32Array()
	var q := PackedFloat32Array()
	var base_sum := 0.0
	var new_sum := 0.0
	for i in 6:
		var v := float(vuln[i]) if i < vuln.size() else 1.0
		var wi := 1.0 + stu * 0.35 * (v - 1.0)
		var qi := clampf(1.0 + stu * 0.12 * (v - 1.0), 0.95, 1.06)
		w.append(wi)
		q.append(qi)
		var bw := MatchSimulation.BASE_TYPE_W[i] * float(style_types[i]) * MatchSimulation.BASE_XG[i]
		base_sum += bw
		new_sum += bw * wi * qi
	# Ganho sobre a mesma quantidade de chances: a média ponderada de pesos fica em 1.
	var wsum := 0.0
	var wn := 0.0
	for i in 6:
		var bw2 := MatchSimulation.BASE_TYPE_W[i] * float(style_types[i])
		wsum += bw2 * w[i]
		wn += bw2
	var norm := wsum / maxf(0.001, wn)
	for i in 6:
		w[i] = w[i] / maxf(0.001, norm)
	return [w, q, clampf(new_sum / maxf(0.001, base_sum) / maxf(0.001, norm), 0.95, 1.08)]


static func style_types(style: int) -> PackedFloat32Array:
	var s: Dictionary = DatabaseManager.tactics()["styles"][clampi(style, 0, 5)]
	var t: Dictionary = s["types"]
	return PackedFloat32Array([float(t.get("through", 1.0)), float(t.get("cross", 1.0)), float(t.get("long", 1.0)),
		float(t.get("dribble", 1.0)), float(t.get("counter", 1.0)), float(t.get("scramble", 1.0))])


# ---------------------------------------------------------------------------
# Elenco em campo (para ler velocidade, técnica, jogo aéreo)
# ---------------------------------------------------------------------------

static func starters(world: GameWorld, club: Club) -> Array:
	var out: Array = []
	if club.sheet != null and club.sheet.starters.size() == 11:
		for pid in club.sheet.starters:
			var p := world.player(pid if pid != null else -1)
			if p != null and p.club_id == club.id:
				out.append(p)
	if out.size() >= 10:
		return out
	out = world.squad(club).duplicate()
	out.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	return out.slice(0, 11)


## Traços do time titular: velocidade do ataque e da defesa, técnica, jogo aéreo, fôlego.
static func traits(world: GameWorld, club: Club) -> Dictionary:
	var xi := starters(world, club)
	var att_v := 0.0
	var att_n := 0
	var def_v := 0.0
	var def_n := 0
	var tech := 0.0
	var aer := 0.0
	var res := 0.0
	var cond := 0.0
	var n := 0
	for p: Player in xi:
		if p.position == Pos.GK:
			continue
		n += 1
		var a := p.attrs
		tech += a[Attr.TEC] * 0.45 + a[Attr.PAS] * 0.35 + a[Attr.DEC] * 0.2
		aer += a[Attr.CAB]
		res += a[Attr.RES]
		cond += p.condition
		if p.position in [Pos.ST, Pos.LW, Pos.RW, Pos.AM]:
			att_v += a[Attr.VEL]
			att_n += 1
		elif p.position in [Pos.CB, Pos.LB, Pos.RB]:
			def_v += a[Attr.VEL]
			def_n += 1
	var k := maxf(1.0, n)
	return {"pace_att": att_v / att_n if att_n > 0 else 55.0, "pace_def": def_v / def_n if def_n > 0 else 55.0,
		"tech": tech / k, "aerial": aer / k, "stamina": res / k, "cond": cond / k}


# ---------------------------------------------------------------------------
# Plano de jogo contra um rival
# ---------------------------------------------------------------------------

## Como o rival deve vir para o jogo (o que o estudo consegue prever).
static func predict(world: GameWorld, opp: Club, vs: Club, opp_home: bool) -> Dictionary:
	var prof := profile(world, opp)
	var sheet := TeamSheet.new()
	sheet.formation = String(prof["formation"])
	if opp.sheet != null:
		# Cópia leve: só o que o plano de jogo lê.
		for k in ["formation", "style", "mentality", "pressing", "line", "width", "intensity"]:
			sheet.set(k, opp.sheet.get(k))
		sheet.starters = opp.sheet.starters
	if not world.is_user_club(opp.id):
		ClubPhilosophy.apply_match_plan(world, opp, vs, opp_home, sheet, false)
	return {"formation": sheet.formation, "style": sheet.style, "mentality": sheet.mentality,
		"pressing": sheet.pressing, "line": sheet.line, "width": sheet.width}


## Plano completo contra `opp`, com os motivos. `depth` (0..1) limita quanto o estudo enxerga.
static func counter_plan(world: GameWorld, club: Club, opp: Club, is_home: bool, depth: float = 1.0) -> Dictionary:
	var reasons: Array = []
	var mine := ClubAI.team_strength(world, club)
	var theirs := ClubAI.team_strength(world, opp)
	var diff := mine - theirs + (1.5 if is_home else -1.5)
	var me := traits(world, club)
	var them := traits(world, opp)
	var pred := predict(world, opp, club, not is_home)
	var prof := profile(world, opp)
	var cv := cat_vuln(prof)
	# Mentalidade pela diferença de forças
	var mentality := TeamSheet.MENT_EQUILIBRADA
	if diff >= 6.0:
		mentality = TeamSheet.MENT_OFENSIVA
		reasons.append("Somos mais fortes: dá para mandar no jogo.")
	elif diff <= -8.0:
		mentality = TeamSheet.MENT_DEFENSIVA
		reasons.append("Eles são bem mais fortes: segurança primeiro, sem abrir espaço.")
	elif diff <= -3.0:
		reasons.append("Jogo duro: equilíbrio e paciência.")
	else:
		reasons.append("Forças parecidas: detalhes vão decidir.")
	# Estilo: encaixe do elenco + entrosamento + brechas do rival + como eles devem jogar
	var scores := TacticsManager._style_scores(world, club)
	for i in scores.size():
		scores[i] += (TacticsManager.style_fam(club, i) - 60.0) * 0.06
	var vuln := vulnerability(world, opp)
	for i in scores.size():
		var types := style_types(i)
		var gain: float = exploit(types, vuln, depth)[2]
		scores[i] += (gain - 1.0) * 60.0
	var p_style := int(pred["style"])
	var p_ment := int(pred["mentality"])
	if p_ment >= TeamSheet.MENT_OFENSIVA or p_style == TeamSheet.STYLE_POSSE or p_style == TeamSheet.STYLE_PRESSAO or int(pred["line"]) == 2:
		scores[TeamSheet.STYLE_CONTRA] += 2.0 + maxf(0.0, (me["pace_att"] - them["pace_def"]) * 0.1)
	if p_style == TeamSheet.STYLE_PRESSAO or int(pred["pressing"]) == 2:
		if me["tech"] < them["tech"] - 3.0:
			scores[TeamSheet.STYLE_LONGA] += 3.0
		else:
			scores[TeamSheet.STYLE_POSSE] += 1.0
	if p_ment <= TeamSheet.MENT_DEFENSIVA:
		scores[TeamSheet.STYLE_POSSE] += 2.0
		scores[TeamSheet.STYLE_LADOS] += 2.0
		scores[TeamSheet.STYLE_CONTRA] -= 4.0
	var p_width := MatchSimulation.formation_weight(String(pred["formation"]), "wide")
	if p_width < 2.0:
		scores[TeamSheet.STYLE_LADOS] += 2.5
	if me["aerial"] > them["aerial"] + 5.0:
		scores[TeamSheet.STYLE_LADOS] += 1.5
		scores[TeamSheet.STYLE_LONGA] += 1.0
	var cur := club.sheet.style if club.sheet != null else TeamSheet.STYLE_POSSE
	var style := cur
	var best_v := float(scores[cur]) + 0.8 # trocar precisa valer a pena
	for i in scores.size():
		if float(scores[i]) > best_v:
			best_v = float(scores[i])
			style = i
	# Pressão
	var pressing := 1
	if them["tech"] < me["tech"] - 2.0 and p_style != TeamSheet.STYLE_LONGA and me["cond"] >= 82.0:
		pressing = 2
	elif them["tech"] > me["tech"] + 5.0 or me["cond"] < 76.0 or mentality <= TeamSheet.MENT_DEFENSIVA:
		pressing = 0 if mentality <= TeamSheet.MENT_DEFENSIVA else 1
	# Linha
	var line := 1
	var pace_gap: float = them["pace_att"] - me["pace_def"]
	if pace_gap >= 6.0:
		line = 0
	elif pace_gap <= -5.0 and mentality >= TeamSheet.MENT_EQUILIBRADA and p_style != TeamSheet.STYLE_LONGA:
		line = 2
	if mentality <= TeamSheet.MENT_DEFENSIVA:
		line = 0
	# Largura
	var width := 1
	if style == TeamSheet.STYLE_LADOS or p_width < 2.0:
		width = 2
	elif float(cv[3]) >= 1.3 and style == TeamSheet.STYLE_CONTRA:
		width = 1
	# Intensidade
	var intensity := 1
	if me["cond"] < 78.0:
		intensity = 0
	elif MatchEngine.is_derby(world, club.id, opp.id) and me["cond"] >= 85.0:
		intensity = 2
	# Motivos concretos (o que o estudo viu)
	var notes := weaknesses(prof, depth)
	if style != cur:
		reasons.append("Estilo indicado: %s." % TacticsManager._style_name(style).to_lower())
	if style == TeamSheet.STYLE_CONTRA and scores[TeamSheet.STYLE_CONTRA] > scores[cur]:
		reasons.append("Eles adiantam o time: o contra-ataque encontra espaço nas costas.")
	if style == TeamSheet.STYLE_LADOS and float(cv[1]) >= 1.25:
		reasons.append("Sofrem muito pelo alto: cruzamentos e bolas na área.")
	if style == TeamSheet.STYLE_LONGA and p_style == TeamSheet.STYLE_PRESSAO:
		reasons.append("Contra a pressão deles, a ligação direta pula o meio-campo.")
	if pressing == 2:
		reasons.append("A saída de bola deles é fraca: pressão alta rouba bolas perto do gol.")
	elif pressing == 0 and them["tech"] > me["tech"] + 5.0:
		reasons.append("Eles tocam bem demais para pressionar: melhor esperar.")
	if line == 0 and pace_gap >= 6.0:
		reasons.append("Atacantes rápidos do lado de lá: linha baixa para não dar espaço nas costas.")
	elif line == 2:
		reasons.append("O ataque deles é lento: linha alta comprime o campo.")
	if width == 2 and p_width < 2.0:
		reasons.append("O %s deles é estreito: abrir o campo." % DatabaseManager.formation_base(String(pred["formation"])))
	if intensity == 0:
		reasons.append("Elenco cansado: intensidade baixa para aguentar os 90 minutos.")
	# O que o diário deles mostra e como aproveitar (vale mesmo sem trocar o estilo)
	if int(prof["n"]) >= 3 and depth >= 0.3:
		if float(cv[1]) >= 1.3 and style != TeamSheet.STYLE_LADOS:
			reasons.append("Eles sofrem pelo alto: capricho nos escanteios e nas bolas na área.")
		if float(cv[3]) >= 1.3 and style != TeamSheet.STYLE_CONTRA:
			reasons.append("Sofrem em contra-ataque: transição rápida sempre que recuperarmos a bola.")
		if int(prof["ga_n"]) >= 5 and int(prof["late"]) * 3 >= int(prof["ga_n"]):
			reasons.append("Eles caem no fim: guardar as substituições para o segundo tempo.")
		if p_style == TeamSheet.STYLE_CONTRA and mentality >= TeamSheet.MENT_EQUILIBRADA:
			reasons.append("Eles vivem de contra-ataque: não perder a bola no meio e manter os laterais atentos.")
		if float(cv[2]) >= 1.4 and style != TeamSheet.STYLE_LONGA:
			reasons.append("O goleiro e a zaga deles deixam chutar de fora: vale arriscar da entrada da área.")
	return {"mentality": mentality, "style": style, "pressing": pressing, "line": line, "width": width,
		"intensity": intensity, "reasons": reasons, "notes": notes, "pred": pred, "profile": prof}


## Pontos fracos e fortes que o diário mostra: [{k, text, bad}]. `depth` corta o que o estudo não vê.
static func weaknesses(prof: Dictionary, depth: float = 1.0) -> Array:
	var out: Array = []
	var n := int(prof["n"])
	if n < 3:
		return out
	var cv := cat_vuln(prof)
	var ga_n := int(prof["ga_n"])
	for i in CATS.size():
		if i == 5:
			continue
		var c := int(prof["conc"][i])
		if c >= 3 and float(cv[i]) >= 1.3:
			out.append({"k": "conc_" + CATS[i], "bad": true,
				"text": "Sofrem muito em %s: %d dos últimos %d gols." % [CAT_NAMES[i], c, ga_n]})
	if ga_n >= 5 and int(prof["late"]) * 3 >= ga_n:
		out.append({"k": "late", "bad": true, "text": "Caem no fim: %d dos %d gols sofridos saíram depois dos 75'." % [int(prof["late"]), ga_n]})
	var sc := prof["scor"] as Array
	var gf_n := int(prof["gf_n"])
	if gf_n >= 4:
		for i in CATS.size() - 1:
			if int(sc[i]) >= 3 and float(sc[i]) / gf_n >= CAT_BASE[i] * 1.6:
				out.append({"k": "scor_" + CATS[i], "bad": false,
					"text": "Perigo em %s: %d dos últimos %d gols deles." % [CAT_NAMES[i], int(sc[i]), gf_n]})
	var hn := int(prof["home_n"])
	var an := int(prof["away_n"])
	if hn >= 3 and an >= 3:
		var hp := float(prof["home_pts"]) / hn
		var ap := float(prof["away_pts"]) / an
		if hp - ap >= 1.2:
			out.append({"k": "home", "bad": false, "text": "Muito mais fortes em casa (%.1f pontos por jogo contra %.1f fora)." % [hp, ap]})
		elif ap < 0.8:
			out.append({"k": "away", "bad": true, "text": "Fora de casa rendem pouco: %.1f ponto por jogo." % ap})
	if n >= 4:
		var xd := float(prof["xf"]) - float(prof["xa"])
		var gd := float(prof["gf"]) - float(prof["ga"])
		if gd - xd >= 0.6:
			out.append({"k": "lucky", "bad": true, "text": "Os resultados estão acima do que criam (xG %.1f x %.1f por jogo): a fase pode virar." % [prof["xf"], prof["xa"]]})
		elif xd - gd >= 0.6:
			out.append({"k": "unlucky", "bad": false, "text": "Criam mais do que o placar mostra (xG %.1f x %.1f por jogo)." % [prof["xf"], prof["xa"]]})
	# Quanto menos estudo, menos coisa o auxiliar consegue ver.
	var keep := clampi(int(round(depth * 5.0)), 1, 5)
	return out.slice(0, keep)


# ---------------------------------------------------------------------------
# IA: muda o plano para cada jogo
# ---------------------------------------------------------------------------

## Depois da filosofia: técnicos que estudam o rival ajustam pressão, linha, largura e (os
## pragmáticos) o estilo. Determinístico (sem o RNG do mundo).
static func ai_adjust(world: GameWorld, club: Club, opp: Club, is_home: bool, sheet: TeamSheet, adapt: float, roll: float) -> void:
	if opp == null:
		return
	var stu := study(world, club)
	if roll > adapt * 0.5 + stu * 0.5:
		return
	var plan := counter_plan(world, club, opp, is_home, stu)
	# Idealistas mudam só detalhes; pragmáticos mudam o jeito de jogar.
	var ph := ClubPhilosophy.of(club)
	var own := [int(ph.get("style", sheet.style)), int(ph.get("style2", sheet.style))]
	var st := int(plan["style"])
	if adapt >= 0.55 or own.has(st):
		if TacticsManager.style_fam(club, st) >= 45.0 or own.has(st):
			sheet.style = st
	if adapt >= 0.4 or int(plan["pressing"]) < sheet.pressing:
		sheet.pressing = int(plan["pressing"])
	sheet.line = int(plan["line"]) if adapt >= 0.4 or int(plan["line"]) < sheet.line else sheet.line
	sheet.width = int(plan["width"])
	if sheet.mentality <= TeamSheet.MENT_DEFENSIVA:
		sheet.line = mini(sheet.line, 1)
