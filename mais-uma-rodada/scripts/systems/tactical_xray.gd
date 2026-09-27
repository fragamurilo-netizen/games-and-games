class_name TacticalXRay
extends RefCounted
## Raio-X tático: explica por que o jogo terminou como terminou, a partir do que o motor
## realmente calculou (corredor de cada ataque, lateral que estava no ataque, ponta que não
## voltou, 2 contra 1, trechos antes e depois das mudanças do técnico).
##
## Relatório (guardado em world.stats["xray"] depois de cada jogo do usuário):
##   {opp, score, side, for/against: {lanes[3], xg_l[3], shots, xg, goals, box, ft, poss},
##    insights: [{k, title, lines[], clips[índices em chances], fix{}}], segments[], chances[], names{}}
## Corredores sempre do ponto de vista do usuário: 0 esquerdo, 1 meio, 2 direito.

const LANE_NAMES := ["lado esquerdo", "meio", "lado direito"]
const CT_NAMES := ["passe em profundidade", "cruzamento", "chute de longe", "jogada individual", "contra-ataque", "bola espirrada", "escanteio", "falta", "pênalti", "erro na saída"]


## Número com vírgula decimal (padrão brasileiro).
static func dec(v: float, n: int = 2) -> String:
	return (("%." + str(n) + "f") % v).replace(".", ",")


static func analyze(world: GameWorld, sim: MatchSimulation) -> Dictionary:
	if sim == null or not sim.xray_on:
		return {}
	var side := 0 if sim.teams[0].is_user else 1
	var me: MatchTeam = sim.teams[side]
	var them: MatchTeam = sim.teams[1 - side]
	var rep := {"opp": them.club.id, "club": me.club.id, "side": side, "score": [sim.score[side], sim.score[1 - side]],
		"year": world.year, "chances": [], "names": {}}
	# Chances: corredor convertido para o ponto de vista do usuário
	for c in sim.xr_chances:
		var e: Dictionary = c.duplicate()
		var mine := int(c["s"]) == side
		e["mine"] = mine
		if int(c["l"]) >= 0:
			e["ul"] = int(c["l"]) if mine else 2 - int(c["l"]) # meu corredor
		else:
			e["ul"] = -1
		rep["chances"].append(e)
		for k in ["sh", "as", "fb", "wg"]:
			var pid := int(e.get(k, -1))
			if pid >= 0 and not rep["names"].has(pid):
				var p := world.player(pid)
				rep["names"][pid] = p.short_name() if p != null else "?"
	rep["for"] = _totals(sim, rep["chances"], side, true)
	rep["against"] = _totals(sim, rep["chances"], 1 - side, false)
	rep["adv"] = {}
	for pid in sim.xr_adv:
		var mp: MatchPlayer = me.by_id.get(pid, null)
		if mp != null:
			rep["adv"][pid] = int(sim.xr_adv[pid])
			rep["names"][pid] = mp.p.short_name()
	rep["segments"] = _segments(sim, side)
	rep["insights"] = _insights(world, sim, rep, me, them)
	return rep


static func _totals(sim: MatchSimulation, chances: Array, s: int, mine: bool) -> Dictionary:
	var lanes := [0, 0, 0]
	var xg_l := [0.0, 0.0, 0.0]
	for c in chances:
		if bool(c["mine"]) != mine or int(c["ul"]) < 0:
			continue
		lanes[int(c["ul"])] += 1
		xg_l[int(c["ul"])] += float(c["xg"])
	var t: MatchTeam = sim.teams[s]
	var total_poss := maxi(1, sim.teams[0].poss_ticks + sim.teams[1].poss_ticks)
	return {"lanes": lanes, "xg_l": xg_l, "shots": t.shots, "on": t.on_target, "xg": snappedf(t.xg, 0.01), "goals": sim.score[s],
		"box": sim.xr_box[s], "ft": sim.xr_ft[s], "poss": int(round(100.0 * t.poss_ticks / total_poss))}


static func _segments(sim: MatchSimulation, side: int) -> Array:
	var out: Array = []
	var segs: Array = sim.xr_segments
	var end_snap := sim._xr_snap()
	for i in segs.size():
		var a: Array = segs[i]["snap"]
		var b: Array = segs[i + 1]["snap"] if i + 1 < segs.size() else end_snap
		var m0 := int(segs[i]["m"])
		var m1 := int(segs[i + 1]["m"]) if i + 1 < segs.size() else maxi(90, sim.minute)
		var mine_a: Dictionary = a[side]
		var mine_b: Dictionary = b[side]
		var opp_b: Dictionary = b[1 - side]
		var opp_a: Dictionary = a[1 - side]
		var poss_me := int(mine_b["poss"]) - int(mine_a["poss"])
		var poss_them := int(opp_b["poss"]) - int(opp_a["poss"])
		out.append({"label": segs[i]["label"], "from": m0, "to": m1,
			"sh": int(mine_b["sh"]) - int(mine_a["sh"]), "xg": snappedf(float(mine_b["xg"]) - float(mine_a["xg"]), 0.01),
			"box": int(mine_b["box"]) - int(mine_a["box"]), "ft": int(mine_b["ft"]) - int(mine_a["ft"]),
			"poss": int(round(100.0 * poss_me / maxf(1.0, poss_me + poss_them))),
			"g": int(mine_b["g"]) - int(mine_a["g"]), "ga": int(opp_b["g"]) - int(opp_a["g"]),
			"sh_a": int(opp_b["sh"]) - int(opp_a["sh"]), "xg_a": snappedf(float(opp_b["xg"]) - float(opp_a["xg"]), 0.01)})
	return out


static func _insights(world: GameWorld, sim: MatchSimulation, rep: Dictionary, me: MatchTeam, them: MatchTeam) -> Array:
	var out: Array = []
	var chances: Array = rep["chances"]
	var ag: Dictionary = rep["against"]
	var fo: Dictionary = rep["for"]
	var names: Dictionary = rep["names"]
	# 1) Por onde o adversário entrou
	var lanes_a: Array = ag["lanes"]
	var total_a := int(lanes_a[0]) + int(lanes_a[1]) + int(lanes_a[2])
	if total_a >= 3:
		var worst := 0
		for l in 3:
			if int(lanes_a[l]) > int(lanes_a[worst]):
				worst = l
		var share := float(lanes_a[worst]) / total_a
		if share >= 0.45:
			var clips: Array = []
			var fb_up := 0
			var wg_off := 0
			var x2 := 0
			var fb_id := -1
			var wg_id := -1
			for i in chances.size():
				var c: Dictionary = chances[i]
				if bool(c["mine"]) or int(c["ul"]) != worst:
					continue
				clips.append(i)
				if bool(c.get("fb_up", false)):
					fb_up += 1
					fb_id = int(c.get("fb", -1))
				if bool(c.get("wg_off", false)):
					wg_off += 1
					wg_id = int(c.get("wg", -1))
				if bool(c.get("x2", false)):
					x2 += 1
			var lines: Array = ["%d dos %d ataques adversários entraram pelo seu %s." % [int(lanes_a[worst]), total_a, LANE_NAMES[worst]]]
			var fix := {}
			if worst != 1 and fb_id >= 0 and fb_up > 0:
				var adv := int(rep["adv"].get(fb_id, 0))
				var line := "Seu lateral %s avançou %d vezes" % [names.get(fb_id, "?"), adv] if adv > 0 else "Seu lateral %s estava no ataque em %d desses lances" % [names.get(fb_id, "?"), fb_up]
				if wg_off > 0 and wg_id >= 0:
					line += " e o ponta %s não recompôs." % names.get(wg_id, "?")
				else:
					line += "."
				lines.append(line)
				fix = {"type": "instr", "pid": fb_id, "instr": "segurar", "label": "Pedir para %s segurar a posição" % names.get(fb_id, "?")}
			elif worst != 1 and wg_off > 0 and wg_id >= 0:
				lines.append("O ponta %s não voltou para ajudar em %d desses lances." % [names.get(wg_id, "?"), wg_off])
				fix = {"type": "instr", "pid": wg_id, "instr": "marcar", "label": "Pedir marcação forte a %s" % names.get(wg_id, "?")}
			if x2 > 0:
				lines.append("O adversário criou %d situaç%s de 2 contra 1 nesse setor." % [x2, "ão" if x2 == 1 else "ões"])
				if fix.is_empty():
					fix = {"type": "width", "width": 0, "label": "Fechar o time (largura: fechado)"}
			if worst == 1:
				lines.append("Seu meio ficou com pouca proteção: a chance média por ali valeu %s de xG." % (dec(float(ag["xg_l"][1]) / maxf(1.0, float(lanes_a[1])))))
				fix = {"type": "formation", "slot_pos": "DM", "label": "Colocar um volante a mais"}
			out.append({"k": "against", "title": "Por que você sofreu", "lines": lines, "clips": clips.slice(0, 3), "fix": fix,
				"weight": share * total_a + float(ag["goals"]) * 2.0})
	# 2) Por que você não criou (ou por onde criou)
	var lanes_f: Array = fo["lanes"]
	var total_f := int(lanes_f[0]) + int(lanes_f[1]) + int(lanes_f[2])
	if int(fo["shots"]) <= 7 or float(fo["xg"]) < 0.8:
		var best := 1
		for l in 3:
			if int(lanes_f[l]) > int(lanes_f[best]):
				best = l
		var lines2: Array = ["Só %d finalizaç%s e %s de xG." % [int(fo["shots"]), "ão" if int(fo["shots"]) == 1 else "ões", dec(float(fo["xg"]))]]
		var fix2 := {}
		if total_f > 0:
			lines2.append("%d%% dos seus ataques foram pelo %s, onde o adversário estava mais protegido." % [int(round(100.0 * int(lanes_f[best]) / total_f)), LANE_NAMES[best]])
		lines2.append("Você chegou %d vezes ao último terço, mas só entrou na área %d." % [int(fo["ft"]), int(fo["box"])])
		if best == 1:
			fix2 = {"type": "formation", "slot_pos": "AM", "label": "Colocar um meia entrelinhas"}
		else:
			fix2 = {"type": "width", "width": 2, "label": "Abrir o time (largura: aberto)"}
		var clips2: Array = []
		for i in chances.size():
			if bool(chances[i]["mine"]):
				clips2.append(i)
		out.append({"k": "attack", "title": "Por que você não criou", "lines": lines2, "clips": clips2.slice(0, 3), "fix": fix2,
			"weight": 4.0 + maxf(0.0, 1.0 - float(fo["xg"])) * 4.0})
	elif total_f >= 4:
		var best2 := 0
		for l in 3:
			if float(fo["xg_l"][l]) > float(fo["xg_l"][best2]):
				best2 = l
		var clips3: Array = []
		for i in chances.size():
			if bool(chances[i]["mine"]) and int(chances[i]["ul"]) == best2:
				clips3.append(i)
		out.append({"k": "strength", "title": "Onde você machucou", "lines": [
			"O %s rendeu %s de xG em %d chances." % [LANE_NAMES[best2], dec(float(fo["xg_l"][best2])), int(lanes_f[best2])],
			"No total: %d finalizações, %s de xG e %d entradas na área." % [int(fo["shots"]), dec(float(fo["xg"])), int(fo["box"])]],
			"clips": clips3.slice(0, 3), "fix": {}, "weight": 2.0})
	# 3) Pontaria
	if float(fo["xg"]) >= 1.6 and int(fo["goals"]) == 0:
		out.append({"k": "finish", "title": "Faltou pontaria", "lines": [
			"Você criou %s de xG e não marcou: %d finalizações, só %d no alvo." % [dec(float(fo["xg"])), int(fo["shots"]), int(fo["on"])],
			"O jogo foi bem armado; o placar não reflete o volume."], "clips": [], "fix": {}, "weight": 3.0})
	# 4) Bola aérea
	var aerial := 0
	var aer_clips: Array = []
	for i in chances.size():
		var c: Dictionary = chances[i]
		if not bool(c["mine"]) and (int(c["ct"]) == MatchSimulation.CH_CROSS or int(c["ct"]) == MatchSimulation.CH_CORNER) and String(c["r"]) == "gol":
			aerial += 1
			aer_clips.append(i)
	if aerial >= 1:
		out.append({"k": "aerial", "title": "Bola aérea", "lines": [
			"Você sofreu %d gol%s de cruzamento ou escanteio." % [aerial, "" if aerial == 1 else "s"],
			"No alto o adversário levou vantagem (%d × %d no jogo aéreo)." % [int(round(them.aerial_att)), int(round(me.aerial_def))]],
			"clips": aer_clips, "fix": {}, "weight": 2.5 + aerial})
	# 5) Antes e depois das mudanças
	var segs: Array = rep["segments"]
	if segs.size() >= 2:
		var a: Dictionary = segs[segs.size() - 2]
		var b: Dictionary = segs[segs.size() - 1]
		out.append({"k": "change", "title": "Efeito da sua mudança", "lines": [
			"Antes (%d'–%d'): %d finalizações, %s de xG, %d%% de posse, %d entradas na área." % [int(a["from"]), int(a["to"]), int(a["sh"]), dec(float(a["xg"])), int(a["poss"]), int(a["box"])],
			"Depois de \"%s\" (%d'–%d'): %d finalizações, %s de xG, %d%% de posse, %d entradas na área." % [String(b["label"]).to_lower(), int(b["from"]), int(b["to"]), int(b["sh"]), dec(float(b["xg"])), int(b["poss"]), int(b["box"])]],
			"clips": [], "fix": {}, "weight": 5.0})
	out.sort_custom(func(x, y): return float(x["weight"]) > float(y["weight"]))
	return out


## Aplica a correção sugerida na escalação do usuário (vale para o próximo jogo).
static func apply_fix(world: GameWorld, fix: Dictionary) -> String:
	var club := world.user_club()
	if club.sheet == null or fix.is_empty():
		return ""
	var sheet := club.sheet
	match String(fix.get("type", "")):
		"instr":
			sheet.instr[int(fix["pid"])] = String(fix["instr"])
		"width":
			sheet.width = int(fix["width"])
		"formation":
			# Troca a vaga mais parecida (um meia central ou um atacante) pela posição pedida.
			var code := String(fix["slot_pos"])
			var base := DatabaseManager.formation_base(sheet.formation)
			var ov := DatabaseManager.formation_overrides(sheet.formation)
			var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
			var want := [Pos.CM, Pos.AM, Pos.ST] if code == "AM" else [Pos.CM, Pos.AM, Pos.RM, Pos.LM]
			var target := -1
			for pos in want:
				for i in range(1, slots.size()):
					if int(slots[i]["pos"]) == pos and not ov.has(i):
						target = i
						break
				if target >= 0:
					break
			if target < 0:
				return "Não achei uma vaga para mudar nesta formação."
			ov[target] = code
			sheet.formation = DatabaseManager.custom_formation_name(base, ov)
			ClubAI.validate_user_sheet(world, club)
	return "Ajuste aplicado: %s." % String(fix.get("label", "")).to_lower()
