class_name Assistant
extends RefCounted
## O auxiliar técnico do usuário, presente o tempo todo:
##   - Pré-jogo: dossiê do rival (como joga, técnico, fase, onde sofre, onde é perigoso, como
##     deve vir contra nós) e o plano completo para o jogo, com os motivos.
##   - Durante o jogo: lê a partida e fala quando vê algo (mudança tática do rival, um lado que
##     só sofre, meio-campo perdido, linha alta sofrendo, cansaço, pendurado, placar no fim),
##     quase sempre com um ajuste que dá para aplicar na hora.
##   - Intervalo: as três leituras mais importantes do primeiro tempo.
##   - Caixa de entrada: análise tática depois do jogo e tendências do time a cada poucas rodadas.
## Quanto melhor o auxiliar (People.staff_level), mais coisa ele enxerga e mais cedo avisa.

const LIVE_CHECKS := {1: [12, 25, 38], 2: [55, 65, 75, 83], 3: [98], 4: [112]}
const SIDE_NAMES: Array[String] = ["esquerdo", "central", "direito"]


static func name_of(world: GameWorld) -> String:
	var s: Dictionary = People.staff(world).get("auxiliar", {})
	return String(s.get("n", "Auxiliar"))


static func level(world: GameWorld) -> float:
	return clampf(People.staff_level(world, "auxiliar"), 0.1, 1.2)


# ---------------------------------------------------------------------------
# Pré-jogo
# ---------------------------------------------------------------------------

## Dossiê do rival e plano para o jogo.
static func dossier(world: GameWorld, club: Club, opp: Club, is_home: bool) -> Dictionary:
	var depth := TacticalScout.study(world, club)
	var plan := TacticalScout.counter_plan(world, club, opp, is_home, depth)
	var prof: Dictionary = plan["profile"]
	var tac := DatabaseManager.tactics()
	var how: Array = []
	var n := int(prof["n"])
	var st := int(prof["style"])
	var desc := "Costumam jogar no %s, %s" % [DatabaseManager.formation_base(String(prof["formation"])), String(tac["styles"][st]["name"]).to_lower()]
	var extras: Array = []
	if float(prof["pressing"]) >= 1.6:
		extras.append("pressão alta")
	elif float(prof["pressing"]) <= 0.4:
		extras.append("marcação recuada")
	if float(prof["line"]) >= 1.6:
		extras.append("linha alta")
	elif float(prof["line"]) <= 0.4:
		extras.append("linha baixa")
	if not extras.is_empty():
		desc += ", " + " e ".join(extras)
	how.append(desc + ".")
	if n >= 3:
		how.append("Nos últimos %d jogos: %.1f gols a favor e %.1f contra por jogo, %d%% de posse." % [n, prof["gf"], prof["ga"], int(round(50.0 + float(prof["poss"])))])
	var co := People.coach_of(world, opp.id)
	var coach := ""
	if not co.is_empty():
		var adapt := float(ClubPhilosophy.of(opp).get("adapt", 0.4))
		var how_c := "muda muito conforme o rival" if adapt >= 0.7 else ("adapta-se às vezes" if adapt >= 0.4 else "fiel às suas ideias")
		coach = "Técnico: %s (%s), %s." % [String(co.get("n", "")), People.style_name(String(co.get("st", ""))).to_lower(), how_c]
	var e := TeamEvolution.ensure(world, opp)
	var evo_txt := "%s · %s." % [TeamEvolution.work_label(float(e["w"])), TeamEvolution.momentum_label(float(e["mo"]))]
	var sd := TeamEvolution.strength_delta(world, opp)
	if absf(sd) >= 1.0:
		evo_txt += " Elenco %s que no começo da temporada (%+.1f)." % ["mais forte" if sd > 0.0 else "mais fraco", sd]
	var weak: Array = []
	var danger: Array = []
	for w: Dictionary in plan["notes"]:
		if bool(w["bad"]):
			weak.append(String(w["text"]))
		else:
			danger.append(String(w["text"]))
	var scorer := _top_scorer(world, opp)
	if scorer != null and int(scorer.season_totals()[1]) >= 2:
		danger.append("%s é o artilheiro: %d gols na temporada." % [scorer.display_name(), int(scorer.season_totals()[1])])
	var pred_txt := ""
	if depth >= 0.3:
		var pr: Dictionary = plan["pred"]
		pred_txt = "Contra nós, devem vir no %s: %s, %s, pressão %s." % [DatabaseManager.formation_base(String(pr["formation"])),
			String(tac["mentalities"][int(pr["mentality"])]["name"]).to_lower(), String(tac["styles"][int(pr["style"])]["name"]).to_lower(),
			String(tac["pressing"][int(pr["pressing"])]["name"]).to_lower()]
	var blind := ""
	if n < 3:
		blind = "Pouco material sobre eles ainda: a leitura vale mais pelo elenco que pelos jogos."
	elif depth < 0.35:
		blind = "Nossa comissão não conseguiu estudar tudo: um auxiliar melhor enxergaria mais."
	return {"how": how, "coach": coach, "evo": evo_txt, "weak": weak, "danger": danger, "pred": pred_txt, "plan": plan, "blind": blind}


static func _top_scorer(world: GameWorld, club: Club) -> Player:
	var best: Player = null
	var bg := 0
	for p: Player in world.squad(club):
		var g := int(p.season_totals()[1])
		if g > bg:
			bg = g
			best = p
	return best


## Aplica o plano do auxiliar na escalação do usuário.
static func apply_plan(sheet: TeamSheet, plan: Dictionary) -> void:
	for k in ["mentality", "style", "pressing", "line", "width", "intensity"]:
		sheet.set(k, int(plan[k]))


## A escalação já segue o plano?
static func plan_matches(sheet: TeamSheet, plan: Dictionary) -> bool:
	for k in ["mentality", "style", "pressing", "line", "width", "intensity"]:
		if int(sheet.get(k)) != int(plan[k]):
			return false
	return true


static func plan_summary(plan: Dictionary) -> String:
	var tac := DatabaseManager.tactics()
	return "%s, %s, pressão %s, linha %s, largura %s" % [String(tac["mentalities"][int(plan["mentality"])]["name"]),
		String(tac["styles"][int(plan["style"])]["short"]).to_lower(), String(tac["pressing"][int(plan["pressing"])]["name"]).to_lower(),
		String(tac["line"][int(plan["line"])]["name"]).to_lower(), TeamSheet.WIDTH_NAMES[int(plan["width"])].to_lower()]


# ---------------------------------------------------------------------------
# Durante o jogo
# ---------------------------------------------------------------------------

## Leituras novas neste minuto (no máximo uma, a mais importante). `state` guarda o que já foi
## dito e até onde os eventos foram lidos. Cada leitura: {k, text, act}; act = {} ou
## {kind: "mentality"|"style"|"pressing"|"line"|"width"|"formation"|"instr"|"tactics", v, pid}.
static func live(world: GameWorld, sim: MatchSimulation, side: int, state: Dictionary) -> Array:
	if sim.finished or sim.shootout:
		return []
	var out: Array = []
	# Mudança tática do rival: fala na hora.
	var from := int(state.get("ev", 0))
	for i in range(from, sim.events.size()):
		var ev: Dictionary = sim.events[i]
		if int(ev["t"]) == MatchSimulation.EV_TACTIC and int(ev["s"]) == 1 - side:
			var x: Dictionary = ev.get("x", {})
			if not x.has("shout") and not x.has("talk"):
				var r := _opp_change(sim, side, x)
				var said: Dictionary = state.get("given", {})
				if not r.is_empty() and (not said.has(String(r["k"])) or sim.minute - int(said[String(r["k"])]) >= 15):
					out.append(r)
	state["ev"] = sim.events.size()
	var checks: Array = LIVE_CHECKS.get(sim.half, [])
	if out.is_empty() and checks.has(sim.minute) and int(state.get("last_m", -1)) != sim.minute:
		state["last_m"] = sim.minute
		# Auxiliar fraco deixa passar algumas leituras.
		var lv := level(world)
		var roll := float(absi(sim.minute * 7919 + side * 31 + int(state.get("seed", 0))) % 100) / 100.0
		if roll < 0.35 + lv * 0.6:
			var cands := read_game(sim, side)
			var given: Dictionary = state.get("given", {})
			for c: Dictionary in cands:
				if not given.has(String(c["k"])):
					out.append(c)
					break
	var given2: Dictionary = state.get("given", {})
	for c: Dictionary in out:
		given2[String(c["k"])] = sim.minute
	state["given"] = given2
	return out.slice(0, 1)


## Todas as leituras possíveis agora, da mais para a menos importante.
static func read_game(sim: MatchSimulation, side: int) -> Array:
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	var diff: int = sim.score[side] - sim.score[1 - side]
	var m := sim.minute
	var late := sim.half >= 2 and m >= 75
	var out: Array = []
	var tac := DatabaseManager.tactics()
	# Superioridade numérica
	if o.on_pitch_count < t.on_pitch_count and t.mentality < TeamSheet.MENT_OFENSIVA and diff <= 0:
		out.append({"k": "man_up", "text": "Eles estão com um a menos. É hora de ocupar o campo deles: mentalidade ofensiva.", "act": {"kind": "mentality", "v": TeamSheet.MENT_OFENSIVA}})
	# Placar no fim
	if late and diff < 0 and t.mentality <= TeamSheet.MENT_EQUILIBRADA:
		out.append({"k": "chase", "text": "Precisamos do gol e o tempo está acabando: mais gente na frente.", "act": {"kind": "mentality", "v": TeamSheet.MENT_TUDO if m >= 85 else TeamSheet.MENT_OFENSIVA}})
	elif late and diff == 1 and t.mentality >= TeamSheet.MENT_EQUILIBRADA and o.xg >= t.xg * 0.8:
		out.append({"k": "hold", "text": "Vencendo por um no fim e eles estão crescendo. Segurar: mentalidade defensiva.", "act": {"kind": "mentality", "v": TeamSheet.MENT_DEFENSIVA}})
	# Um lado que só sofre
	var conc: int = t.lane_conc[0] + t.lane_conc[1] + t.lane_conc[2]
	if conc >= 3:
		for l in [0, 2]:
			if t.lane_conc[l] >= 3 and float(t.lane_conc[l]) / conc >= 0.5:
				var who := sim._lane_player(t, l)
				var txt := "Eles estão chegando muito pelo nosso lado %s: %d das %d chances deles." % [SIDE_NAMES[l], t.lane_conc[l], conc]
				if who != null and String(who.instr.get("name", "")) != String(TeamSheet.INSTRUCTIONS["segurar"]["name"]):
					out.append({"k": "lane%d" % l, "text": txt + " Peça para %s segurar a posição." % who.p.display_name(), "act": {"kind": "instr", "v": "segurar", "pid": who.p.id}})
				else:
					out.append({"k": "lane%d" % l, "text": txt + " Vale reforçar o setor com uma troca.", "act": {"kind": "tactics"}})
	# Bolas nas costas da linha alta
	if t.line == 2 and t.ct_conc[MatchSimulation.CH_THROUGH] + t.ct_conc[MatchSimulation.CH_COUNTER] >= 2:
		out.append({"k": "line", "text": "Estão acertando bolas nas costas da nossa zaga. Com a linha alta, a velocidade deles machuca: baixar a linha.", "act": {"kind": "line", "v": 1}})
	# Pressão rival sufocando a saída
	var poss := sim.possession_pct(side)
	if (o.pressing == 2 or o.style == TeamSheet.STYLE_PRESSAO) and poss < 0.43 and t.style != TeamSheet.STYLE_LONGA and t.press_tech < o.press_tech + 3.0:
		out.append({"k": "press", "text": "A pressão deles está sufocando nossa saída (%d%% de posse). A bola longa pula a marcação." % int(round(poss * 100.0)), "act": {"kind": "style", "v": TeamSheet.STYLE_LONGA}})
	# Meio-campo perdido
	if poss < 0.40 and o.mid_mass > t.mid_mass + 0.4:
		var fname := _more_mid_formation(sim, t)
		if fname != "":
			out.append({"k": "mid", "text": "Perdemos o meio-campo: eles têm mais gente ali e a bola é deles (%d%%). No %s a gente equilibra." % [int(round((1.0 - poss) * 100.0)), fname], "act": {"kind": "formation", "v": fname}})
	# Na frente, mas sofrendo
	if diff > 0 and o.xg - t.xg >= 0.8 and t.line > 0:
		out.append({"k": "lucky", "text": "Estamos na frente, mas eles criam mais (xG %.1f x %.1f). Linha mais baixa para proteger a área." % [o.xg, t.xg], "act": {"kind": "line", "v": t.line - 1}})
	# Domínio sem gol
	if diff <= 0 and t.xg - o.xg >= 0.9:
		if t.width_i < 2 and o.width < 2.6:
			out.append({"k": "dominate", "text": "Criamos bem mais (xG %.1f x %.1f) e eles se fecham por dentro. Abrir o campo." % [t.xg, o.xg], "act": {"kind": "width", "v": 2}})
		else:
			out.append({"k": "dominate", "text": "Criamos bem mais (xG %.1f x %.1f). O gol vai sair: manter o plano." % [t.xg, o.xg], "act": {}})
	# Bloco baixo rival
	if diff <= 0 and o.line == 0 and o.mentality <= TeamSheet.MENT_DEFENSIVA and t.style == TeamSheet.STYLE_POSSE and t.xg < 0.5 and m >= 20:
		out.append({"k": "block", "text": "Eles se fecharam atrás e a posse não está furando. Jogo pelos lados, com cruzamentos.", "act": {"kind": "style", "v": TeamSheet.STYLE_LADOS}})
	# Bola aérea
	var aer: int = t.ct_conc[MatchSimulation.CH_CROSS] + t.ct_conc[MatchSimulation.CH_CORNER]
	if aer >= 3:
		out.append({"k": "aerial", "text": "Eles estão ganhando pelo alto: %d chances de cabeça. Fechar os cruzamentos: time mais compacto." % aer, "act": {"kind": "width", "v": 0} if t.width_i > 0 else {}})
	# Jogador perigoso
	var danger: MatchPlayer = null
	for mp: MatchPlayer in o.slots:
		if mp != null and mp.slot > 0 and mp.shots >= 3 and (danger == null or mp.shots > danger.shots):
			danger = mp
	if danger != null:
		var marker := _marker_for(sim, t, o, danger)
		var dtext := "%s já finalizou %d vezes. Não pode ter espaço" % [danger.p.display_name(), danger.shots]
		if marker != null:
			out.append({"k": "danger", "text": dtext + ": %s cola nele." % marker.p.display_name(), "act": {"kind": "instr", "v": "marcar", "pid": marker.p.id}})
		else:
			out.append({"k": "danger", "text": dtext + ": marcação em cima dele.", "act": {}})
	# Cansaço e cartões
	var tired: MatchPlayer = null
	var hot: MatchPlayer = null
	for mp: MatchPlayer in t.slots:
		if mp == null or mp.slot <= 0:
			continue
		if mp.cond < 62.0 and (tired == null or mp.cond < tired.cond):
			tired = mp
		if mp.yellow == 1 and mp.fouls >= 3:
			hot = mp
	var subs_left := t.max_subs - t.subs_used
	if hot != null and subs_left > 0:
		out.append({"k": "hot%d" % hot.p.id, "text": "%s está pendurado e já fez %d faltas. Risco de expulsão: melhor tirar." % [hot.p.display_name(), hot.fouls], "act": {"kind": "tactics"}})
	if tired != null and subs_left > 0 and sim.half >= 2:
		out.append({"k": "tired%d" % tired.p.id, "text": "%s está no limite (%d%% de fôlego). Vale uma troca." % [tired.p.display_name(), int(tired.cond)], "act": {"kind": "tactics"}})
	# Volume de jogo
	if o.shots >= t.shots + 4 and t.mentality > TeamSheet.MENT_DEFENSIVA and diff >= 0:
		out.append({"k": "shots", "text": "Eles finalizam muito mais (%d x %d). Fechar o meio antes que o gol saia: um passo atrás na mentalidade." % [o.shots, t.shots], "act": {"kind": "mentality", "v": t.mentality - 1}})
	if poss >= 0.6 and t.shots <= o.shots and m >= 20:
		out.append({"k": "sterile", "text": "A bola é nossa (%d%%), mas sem profundidade: %d finalizações. Jogo mais vertical." % [int(round(poss * 100.0)), t.shots], "act": {"kind": "style", "v": TeamSheet.STYLE_DIRETO} if t.style == TeamSheet.STYLE_POSSE else {}})
	if t.xg >= o.xg + 0.5 and diff >= 0 and m >= 20:
		out.append({"k": "working", "text": "O plano está funcionando: criamos mais (xG %.1f x %.1f). Manter." % [t.xg, o.xg], "act": {}})
	# Pressão que não se sustenta
	if t.pressing == 2 and sim.half >= 2:
		var cond := 0.0
		var n := 0
		for mp: MatchPlayer in t.slots:
			if mp != null and mp.slot > 0:
				cond += mp.cond
				n += 1
		if n > 0 and cond / n < 70.0:
			out.append({"k": "legs", "text": "O time não aguenta mais pressionar lá em cima (fôlego médio %d%%). Pressão média." % int(cond / n), "act": {"kind": "pressing", "v": 1}})
	return out


## Quem do nosso time marca o jogador perigoso deles (mesmo corredor, o mais defensivo).
static func _marker_for(sim: MatchSimulation, t: MatchTeam, o: MatchTeam, danger: MatchPlayer) -> MatchPlayer:
	var lane := 2 - o.lane_of(danger)
	var best: MatchPlayer = null
	for mp: MatchPlayer in t.slots:
		if mp == null or mp.slot <= 0 or t.lane_of(mp) != lane or mp.w_def < 0.4:
			continue
		if not mp.instr.is_empty() and String(mp.instr.get("name", "")) == String(TeamSheet.INSTRUCTIONS["marcar"]["name"]):
			return null
		if best == null or mp.c_def > best.c_def:
			best = mp
	return best


## Formação com mais meio-campo que o time já conhece razoavelmente.
static func _more_mid_formation(sim: MatchSimulation, t: MatchTeam) -> String:
	var cur := MatchSimulation.formation_weight(t.formation_name, "mid")
	var best := ""
	var best_v := cur + 0.4
	for fname in DatabaseManager.formation_names():
		if fname == t.formation_name:
			continue
		var mw := MatchSimulation.formation_weight(fname, "mid")
		var fam := TacticsManager.formation_fam(t.club, fname)
		if fam < 40.0:
			continue
		var v := mw + fam / 100.0 * 0.3
		if mw > cur + 0.3 and v > best_v:
			best_v = v
			best = fname
	return best


## O que dizer quando o rival muda.
static func _opp_change(sim: MatchSimulation, side: int, x: Dictionary) -> Dictionary:
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	var diff: int = sim.score[side] - sim.score[1 - side]
	if x.has("formation"):
		return {"k": "opp_f_" + String(x["formation"]), "text": "Eles mudaram o desenho para o %s. Atenção às marcações." % DatabaseManager.formation_base(String(x["formation"])), "act": {}}
	if (x.has("pressing") and int(x["pressing"]) == 2) or (x.has("style") and int(x["style"]) == TeamSheet.STYLE_PRESSAO):
		if t.press_tech < o.press_tech + 3.0 and t.style != TeamSheet.STYLE_LONGA:
			return {"k": "opp_press", "text": "Eles subiram a pressão. Se a saída sofrer, a bola longa pula a marcação.", "act": {"kind": "style", "v": TeamSheet.STYLE_LONGA}}
		return {"k": "opp_press", "text": "Eles subiram a pressão. Nosso time toca bem: saindo jogando, vai sobrar espaço nas costas deles.", "act": {}}
	if x.has("mentality") and int(x["mentality"]) == TeamSheet.MENT_TUDO:
		return {"k": "opp_all", "text": "Eles foram para o tudo ou nada. Muito espaço nas costas: um gol nosso mata o jogo.", "act": {"kind": "style", "v": TeamSheet.STYLE_CONTRA} if diff >= 0 and t.style != TeamSheet.STYLE_CONTRA else {}}
	if x.has("mentality") and int(x["mentality"]) >= TeamSheet.MENT_OFENSIVA:
		if diff >= 0 and t.style != TeamSheet.STYLE_CONTRA:
			return {"k": "opp_att", "text": "Eles se lançaram ao ataque. Vai sobrar espaço atrás: contra-ataque.", "act": {"kind": "style", "v": TeamSheet.STYLE_CONTRA}}
		return {"k": "opp_att", "text": "Eles se lançaram ao ataque. Cuidado com a nossa defesa.", "act": {}}
	if x.has("mentality") and int(x["mentality"]) <= TeamSheet.MENT_DEFENSIVA and diff <= 0 and t.width_i < 2:
		return {"k": "opp_def", "text": "Eles recuaram e fecharam a casinha. Precisamos de amplitude: abrir o campo.", "act": {"kind": "width", "v": 2}}
	if x.has("line") and int(x["line"]) < 1 and t.style == TeamSheet.STYLE_CONTRA:
		return {"k": "opp_low", "text": "Eles baixaram a linha: o contra-ataque perde espaço. Posse e paciência.", "act": {"kind": "style", "v": TeamSheet.STYLE_POSSE}}
	return {}


## Leituras do intervalo (até três, sem repetir o que já foi dito se possível).
static func halftime(sim: MatchSimulation, side: int) -> Array:
	var cands := read_game(sim, side)
	var out: Array = []
	var seen := {}
	for c: Dictionary in cands:
		var base := String(c["k"]).rstrip("0123456789")
		if seen.has(base) or base in ["working", "dominate"]: # o resumo do intervalo já diz isso
			continue
		seen[base] = true
		out.append(c)
		if out.size() >= 3:
			break
	if out.size() < 3:
		out.append(_half_summary(sim, side))
	return out


## Resumo do primeiro tempo e o que esperar do rival no segundo.
static func _half_summary(sim: MatchSimulation, side: int) -> Dictionary:
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	var diff: int = sim.score[side] - sim.score[1 - side]
	var adapt := float(ClubPhilosophy.of(o.club).get("adapt", 0.4))
	var nums := "(xG %.1f x %.1f, %d x %d finalizações)" % [t.xg, o.xg, t.shots, o.shots]
	if diff > 0:
		if adapt >= 0.4 and t.style != TeamSheet.STYLE_CONTRA:
			return {"k": "ht", "text": "Primeiro tempo nosso %s. Atrás no placar, eles vão se lançar: vai sobrar espaço para o contra-ataque." % nums, "act": {"kind": "style", "v": TeamSheet.STYLE_CONTRA}}
		return {"k": "ht", "text": "Primeiro tempo nosso %s. Controlar o jogo vale mais que buscar o próximo gol." % nums, "act": {}}
	if diff < 0:
		if t.mentality < TeamSheet.MENT_OFENSIVA:
			return {"k": "ht", "text": "Estamos atrás %s. Dá tempo, mas precisamos de mais gente perto da área." % nums, "act": {"kind": "mentality", "v": t.mentality + 1}}
		return {"k": "ht", "text": "Estamos atrás %s. O time já está ofensivo: paciência para não se expor ao contra-ataque." % nums, "act": {}}
	if t.xg > o.xg + 0.4:
		return {"k": "ht", "text": "Jogo empatado, mas estamos criando mais %s. Manter o plano." % nums, "act": {}}
	if o.xg > t.xg + 0.4:
		return {"k": "ht", "text": "Empate com sofrimento %s. Eles estão melhores: vale fechar mais o meio." % nums, "act": {"kind": "mentality", "v": maxi(1, t.mentality - 1)} if t.mentality > 1 else {}}
	return {"k": "ht", "text": "Primeiro tempo equilibrado %s. Detalhes vão decidir." % nums, "act": {}}


## Aplica o ajuste de uma leitura na partida. Retorna o texto de confirmação.
static func apply_live(sim: MatchSimulation, side: int, act: Dictionary) -> String:
	var tac := DatabaseManager.tactics()
	match String(act.get("kind", "")):
		"mentality":
			sim.set_mentality(side, int(act["v"]))
			return "Mentalidade: %s." % String(tac["mentalities"][int(act["v"])]["name"])
		"style":
			sim.set_style(side, int(act["v"]))
			return "Estilo: %s." % String(tac["styles"][int(act["v"])]["short"])
		"pressing":
			sim.set_pressing(side, int(act["v"]))
			return "Pressão %s." % String(tac["pressing"][int(act["v"])]["name"]).to_lower()
		"line":
			sim.set_line(side, int(act["v"]))
			return "Linha %s." % String(tac["line"][int(act["v"])]["name"]).to_lower()
		"width":
			sim.set_width(side, int(act["v"]))
			return "Largura: %s." % TeamSheet.WIDTH_NAMES[int(act["v"])].to_lower()
		"formation":
			sim.set_formation(side, String(act["v"]))
			return "Formação: %s." % String(act["v"])
		"instr":
			sim.set_instruction(side, int(act["pid"]), String(act["v"]))
			return "Instrução passada."
	return ""


static func act_label(act: Dictionary) -> String:
	var tac := DatabaseManager.tactics()
	match String(act.get("kind", "")):
		"mentality":
			return String(tac["mentalities"][int(act["v"])]["name"])
		"style":
			return String(tac["styles"][int(act["v"])]["short"])
		"pressing":
			return "Pressão %s" % String(tac["pressing"][int(act["v"])]["name"]).to_lower()
		"line":
			return "Linha %s" % String(tac["line"][int(act["v"])]["name"]).to_lower()
		"width":
			return TeamSheet.WIDTH_NAMES[int(act["v"])]
		"formation":
			return String(act["v"])
		"instr":
			return String(TeamSheet.INSTRUCTIONS.get(String(act["v"]), {}).get("name", "Instrução"))
		"tactics":
			return "Substituições"
	return ""


# ---------------------------------------------------------------------------
# Caixa de entrada
# ---------------------------------------------------------------------------

## Análise tática do jogo que passou (para o relatório do auxiliar).
static func match_lines(world: GameWorld, club: Club, entry: Dictionary) -> Array:
	var out: Array = []
	var sim: MatchSimulation = entry.get("sim", null)
	if sim == null or not sim.finished:
		return out
	var f: Fixture = entry["f"]
	var side := 0 if f.home == club.id else 1
	var t: MatchTeam = sim.teams[side]
	var o: MatchTeam = sim.teams[1 - side]
	out.append("Números: xG %.1f x %.1f, %d x %d finalizações, %d%% de posse." % [t.xg, o.xg, t.shots, o.shots, int(round(sim.possession_pct(side) * 100.0))])
	var conc: int = t.lane_conc[0] + t.lane_conc[1] + t.lane_conc[2]
	if conc >= 4:
		for l in [0, 2]:
			if float(t.lane_conc[l]) / conc >= 0.5:
				out.append("Sofremos principalmente pelo lado %s (%d de %d chances deles)." % [SIDE_NAMES[l], t.lane_conc[l], conc])
	var aer: int = t.ct_conc[MatchSimulation.CH_CROSS] + t.ct_conc[MatchSimulation.CH_CORNER]
	if aer >= 4:
		out.append("A bola aérea foi um problema: %d chances deles vieram de cruzamento ou escanteio." % aer)
	var back: int = t.ct_conc[MatchSimulation.CH_THROUGH] + t.ct_conc[MatchSimulation.CH_COUNTER]
	if back >= 4 and t.line == 2:
		out.append("A linha alta deu espaço: %d chances deles em bolas nas costas." % back)
	var diff: int = sim.score[side] - sim.score[1 - side]
	if diff <= 0 and t.xg - o.xg >= 0.8:
		out.append("Merecíamos mais: criamos bem mais do que eles. Com essa produção, os gols vêm.")
	elif diff > 0 and o.xg - t.xg >= 0.8:
		out.append("A vitória veio, mas eles criaram mais. Não dá para contar com isso sempre.")
	return out


## Tendências do nosso time (a cada poucas rodadas): fase, trabalho, onde sofremos e marcamos.
static func trend_message(world: GameWorld) -> void:
	var club := world.user_club()
	if club == null:
		return
	var prof := TacticalScout.profile(world, club)
	if int(prof["n"]) < 5:
		return
	var e := TeamEvolution.ensure(world, club)
	var lines: Array = []
	lines.append("Momento: %s. %s." % [TeamEvolution.momentum_label(float(e["mo"])).to_lower(), TeamEvolution.work_label(float(e["w"]))])
	lines.append("Últimos %d jogos: %.1f gols a favor e %.1f contra por jogo; xG %.1f x %.1f." % [int(prof["n"]), prof["gf"], prof["ga"], prof["xf"], prof["xa"]])
	var cv := TacticalScout.cat_vuln(prof)
	var ga_n := int(prof["ga_n"])
	for i in TacticalScout.CATS.size() - 1:
		if int(prof["conc"][i]) >= 3 and float(cv[i]) >= 1.3:
			var fix := {"aereo": "Zagueiros mais fortes no alto ou time mais compacto ajudam.", "contra": "Menos gente no ataque ou linha mais baixa diminuem o risco.",
				"jogada": "O meio está deixando passar: um volante a mais ou marcação forte.", "longe": "Estão chutando de fora à vontade: pressão média fecha esse espaço.",
				"sobra": "Muitos rebotes e erros: vale treino tático e uma zaga mais segura."}
			lines.append("Ponto fraco: %d dos últimos %d gols sofridos saíram de %s. %s" % [int(prof["conc"][i]), ga_n, TacticalScout.CAT_NAMES[i], String(fix.get(TacticalScout.CATS[i], ""))])
	var xd := float(prof["xf"]) - float(prof["xa"])
	var gd := float(prof["gf"]) - float(prof["ga"])
	if gd - xd >= 0.5:
		lines.append("Os resultados estão acima do que produzimos. A fase pode virar se nada mudar.")
	elif xd - gd >= 0.5:
		lines.append("Produzimos mais do que o placar mostra. Se mantivermos, os resultados vêm.")
	var sd := TeamEvolution.strength_delta(world, club)
	if absf(sd) >= 1.0:
		lines.append("Nosso time titular está %s que no começo da temporada (%+.1f)." % ["mais forte" if sd > 0.0 else "mais fraco", sd])
	# Quem cresceu e quem caiu na liga
	var league := world.league_of(club.id)
	if league != null:
		var up: Club = null
		var down: Club = null
		var up_v := 0.0
		var down_v := 0.0
		for cid in league.club_ids:
			if cid == club.id:
				continue
			var c := world.club(cid)
			var mo := float(TeamEvolution.ensure(world, c)["mo"])
			if mo > up_v:
				up_v = mo
				up = c
			if mo < down_v:
				down_v = mo
				down = c
		if up != null and up_v >= 0.35:
			lines.append("Na liga, o %s é o time mais embalado." % up.short_name)
		if down != null and down_v <= -0.35:
			lines.append("O %s vive crise: rival para aproveitar." % down.short_name)
	InboxManager.send(world, "auxiliar", "Tendências do time", "\n\n".join(lines), {"k": "screen", "s": "prematch", "args": {"edit": true}})
