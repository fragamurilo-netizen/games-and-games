class_name InternationalCareer
extends RefCounted
## Dual club/national-team job; state is additive and survives existing saves.
const KEY := "intl_career_v1"
const MAX_SQUAD := 26
const ANNOUNCE_DAYS := 14 # game design deadline, not a universal FIFA rule

static func data(w: GameWorld) -> Dictionary:
	if not w.stats.has(KEY):
		w.stats[KEY] = {"nation":"", "trust":60.0, "games":0, "wins":0, "roster":[], "plans":{},
			"announced":{}, "processed":{}, "results":[], "hype":{}, "history":[], "announcements":[]}
	return w.stats[KEY]

static func nation(w: GameWorld) -> String:
	return String(data(w).get("nation", ""))

static func reputation(w: GameWorld) -> float:
	var club_rep := w.user_club().reputation if w.has_user() else 30.0
	return clampf(20.0 + club_rep * 0.40 + int(w.manager_stats.get("games", 0)) * 0.08
		+ int(w.manager_stats.get("titles", 0)) * 3.0 + int(data(w).get("wins", 0)) * 0.6, 15.0, 95.0)

static func requirement(code: String) -> float:
	return clampf(18.0 + float(DatabaseManager.nation(code).get("coef", 30)) * 0.45, 25.0, 65.0)

static func apply(w: GameWorld, code: String) -> String:
	if not DatabaseManager.has_nation(code): return "Seleção não encontrada."
	if nation(w) != "": return "Você já comanda uma seleção. Encerre o vínculo antes de trocar."
	if reputation(w) < requirement(code): return "A federação exige mais reputação. Construa sua carreira no clube ou em uma seleção menor."
	var pool := eligible(w, code)
	if pool.size() < 26: return "Esta seleção não tem 26 jogadores disponíveis no mundo deste save."
	var ids := auto_roster(pool, w.year)
	var error := validate(w, code, ids)
	if error != "": return error
	var d := data(w)
	d["nation"] = code
	d["trust"] = 60.0
	d["job_games"] = 0
	d["roster"] = ids
	d["appointed"] = InternationalCalendar.iso(InternationalCalendar.season_date(w))
	NewsManager.post_raw(w, "%s assume a seleção de %s" % [w.manager_name, DatabaseManager.nation_name(code)],
		"O treinador acumula o trabalho no clube com a seleção. Convocações, encaixe tático e resultados serão avaliados pela federação.", -1, -1, NewsEvent.IMP_HIGH, "selecao")
	return ""

static func resign(w: GameWorld, dismissed: bool = false) -> void:
	var d := data(w)
	if nation(w) == "": return
	d["history"].append({"nation":nation(w), "year":w.year, "games":d.get("job_games",0), "dismissed":dismissed})
	NewsManager.post_raw(w, "%s deixa o comando de %s" % [w.manager_name, DatabaseManager.nation_name(nation(w))],
		"A federação encerrou o vínculo pelos resultados abaixo da expectativa." if dismissed else "O treinador decidiu encerrar o vínculo com a seleção.", -1, -1, NewsEvent.IMP_HIGH, "selecao")
	d["nation"] = ""
	d["roster"] = []

static func eligible(w: GameWorld, code: String) -> Array:
	var pool: Array = []
	for p: Player in w.players.values():
		if p.nationality == code and p.injury_weeks <= 0 and not p.retiring:
			pool.append(p)
	pool.sort_custom(func(a,b):
		var av := selection_score(a, w.year)
		var bv := selection_score(b, w.year)
		return av > bv if not is_equal_approx(av,bv) else a.id < b.id)
	return pool

static func selection_score(p: Player, year: int) -> float:
	var evidence := clampf(float(p.stats[Player.S_MINUTES]) / 900.0, 0.0, 1.0)
	return (p.ovr_f + clampf(p.form() - 6.5, -1.2, 1.2) * 2.4 * evidence
		- maxf(0.0, 90.0 - p.condition) * 0.09 + evidence * 0.7)

static func auto_roster(pool: Array, year: int) -> Array:
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a,b): return selection_score(a,year) > selection_score(b,year) or (is_equal_approx(selection_score(a,year),selection_score(b,year)) and a.id < b.id))
	var result: Array = []
	var quota := [3, 9, 8, 6]
	for group in 4:
		for p: Player in sorted:
			if Pos.group(p.position) == group and quota[group] > 0:
				result.append(p.id)
				quota[group] -= 1
	for p: Player in sorted:
		if result.size() >= MAX_SQUAD: break
		if not result.has(p.id) and p.position != Pos.GK: result.append(p.id)
	return result

static func validate(w: GameWorld, code: String, ids: Array) -> String:
	if ids.size() != MAX_SQUAD: return "A lista precisa ter 26 jogadores."
	var seen := {}
	var groups := [0,0,0,0]
	for pid in ids:
		var p := w.player(int(pid))
		if p == null or p.nationality != code or p.injury_weeks > 0 or p.retiring: return "Há jogador indisponível ou de outra nacionalidade."
		if seen.has(p.id): return "A lista contém jogador repetido."
		seen[p.id] = true
		groups[Pos.group(p.position)] += 1
	if groups[0] != 3: return "Escolha exatamente três goleiros."
	if groups[1] < 6 or groups[2] < 4 or groups[3] < 3: return "A lista precisa ter cobertura: 6 defensores, 4 meias e 3 atacantes no mínimo."
	return ""

static func locked(w: GameWorld) -> bool:
	var now := InternationalCalendar.season_date(w)
	for win in InternationalCalendar.upcoming(now):
		if int(win["a"]) - now > ANNOUNCE_DAYS * 86400: return false
		return data(w)["announced"].get(win["id"], {}).has(nation(w))
	return false

static func toggle(w: GameWorld, pid: int) -> String:
	if locked(w): return "Convocação anunciada. A lista só terá reposição automática por indisponibilidade."
	var p := w.player(pid)
	if p == null or p.nationality != nation(w) or p.injury_weeks > 0: return "Jogador indisponível."
	var list: Array = data(w)["roster"]
	if list.has(pid): list.erase(pid)
	elif list.size() < MAX_SQUAD: list.append(pid)
	else: return "Retire um jogador antes de incluir outro."
	return ""

static func announce(w: GameWorld, window: Dictionary) -> void:
	var d := data(w)
	var id := String(window["id"])
	if d["announced"].has(id): return
	var pool := NationalTeamManager._pool(w)
	var lists := {}
	for code in pool:
		var ids := auto_roster(pool[code], w.year)
		if code == nation(w) and validate(w, code, d["roster"]) == "": ids = Array(d["roster"]).duplicate()
		lists[code] = ids
		if code == nation(w): d["roster"] = ids.duplicate()
		NationalTeamManager.data(w)["squads"][code] = ids.duplicate()
	d["announced"][id] = lists
	var focus := nation(w) if nation(w) != "" else (w.user_nation() if w.has_user() else "BRA")
	var names: Array = []
	for pid in lists.get(focus, []):
		var p := w.player(int(pid))
		if p != null: names.append(p.display_name())
	if not names.is_empty():
		NewsManager.post_raw(w, "%s anuncia convocação para a Data FIFA" % DatabaseManager.nation_name(focus),
			"Janela de %s a %s. Convocados: %s. As escolhas consideram forma, condição e cobertura de posições." % [window["start"],window["end"],", ".join(names)], -1,-1,NewsEvent.IMP_HIGH,"selecao")
	d["announcements"].append({"window":id,"nation":focus,"players":lists.get(focus,[]).duplicate()})
	if d["announcements"].size() > 12: d["announcements"].pop_front()

static func publish(w: GameWorld) -> String:
	var error := validate(w, nation(w), data(w)["roster"])
	if error != "": return error
	var upcoming := InternationalCalendar.upcoming(InternationalCalendar.season_date(w))
	if upcoming.is_empty(): return "Sem janela disponível."
	if int(upcoming[0]["a"]) - InternationalCalendar.season_date(w) > ANNOUNCE_DAYS * 86400:
		return "A convocação pode ser anunciada nos 14 dias anteriores à janela."
	announce(w, upcoming[0])
	return ""

static func squad_for(w: GameWorld, code: String, pool: Array) -> Array:
	var d := data(w)
	var ids: Array = []
	var id := String(d.get("active_window", ""))
	if id != "": ids = Array(d["announced"].get(id, {}).get(code, [])).duplicate()
	if ids.is_empty() and code == nation(w): ids = Array(d["roster"]).duplicate()
	if ids.is_empty(): ids = auto_roster(pool, w.year)
	var valid := {}
	for p: Player in pool: valid[p.id] = p
	var result: Array = []
	var taken := {}
	for pid in ids:
		if valid.has(int(pid)) and not taken.has(int(pid)):
			result.append(valid[int(pid)])
			taken[int(pid)] = true
	# Injury replacements retain existing players and prioritize the missing goalkeeper quota.
	var gk := result.filter(func(p): return p.position == Pos.GK).size()
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a,b): return selection_score(a,w.year) > selection_score(b,w.year))
	for p: Player in sorted:
		if result.size() >= MAX_SQUAD: break
		if taken.has(p.id) or (p.position == Pos.GK and gk >= 3): continue
		if gk < 3 and p.position != Pos.GK: continue
		result.append(p); taken[p.id] = true
		if p.position == Pos.GK: gk += 1
	for p: Player in sorted:
		if result.size() >= MAX_SQUAD: break
		if not taken.has(p.id) and p.position != Pos.GK:
			result.append(p); taken[p.id] = true
	if id != "" and d["announced"].has(id):
		var updated := result.map(func(p): return p.id)
		if code == nation(w) and updated != ids:
			NewsManager.post_raw(w,"Seleção anuncia reposições na convocação",
				"A lista de %s foi ajustada por indisponibilidade. A nova relação está no painel de comando da seleção." % DatabaseManager.nation_name(code),-1,-1,NewsEvent.IMP_HIGH,"selecao")
			d["roster"] = updated.duplicate()
		d["announced"][id][code] = updated
	return result

static func plan(w: GameWorld, code: String) -> Dictionary:
	var plans: Dictionary = data(w)["plans"]
	if not plans.has(code):
		plans[code] = {"formation":"4-3-3", "style":posmod(hash(code), DatabaseManager.tactics()["styles"].size()),
			"mentality":2,"pressing":1,"line":1,"width":1,"passing":1,"cohesion":52.0,"xi":[]}
	return plans[code]

static func set_plan(w: GameWorld, key: String, value: Variant) -> void:
	if nation(w) == "": return
	var p := plan(w,nation(w))
	if key == "formation":
		if not DatabaseManager.has_formation(String(value)): return
	elif key == "style": value = clampi(int(value),0,DatabaseManager.tactics()["styles"].size()-1)
	elif key in ["pressing","line","width","passing"]: value = clampi(int(value),0,2)
	elif key == "mentality": value = clampi(int(value),0,4)
	else: return
	if p.get(key) == value: return
	p[key] = value
	p["cohesion"] = maxf(35.0,float(p["cohesion"])-3.0)

static func sheet(w: GameWorld, code: String, squad: Array) -> TeamSheet:
	var config := plan(w,code)
	var s := TeamSheet.new()
	s.formation = String(config["formation"])
	for key in ["style","mentality","pressing","line","width","passing"]: s.set(key,int(config[key]))
	s.auto_subs = true
	var used := {}
	for slot: Dictionary in DatabaseManager.formation(s.formation)["slots"]:
		var best: Player = null
		var best_score := -1000.0
		for p: Player in squad:
			if used.has(p.id) or p.injury_weeks > 0 or p.retiring: continue
			if (int(slot["pos"]) == Pos.GK) != (p.position == Pos.GK): continue
			var rating := p.rating_at(int(slot["pos"])) + selection_score(p,w.year) - p.ovr_f
			if Array(config.get("xi",[])).has(p.id): rating += 120.0
			if rating > best_score:
				best = p; best_score = rating
		s.starters.append(best.id if best != null else -1)
		if best != null: used[best.id] = true
	for p: Player in squad:
		if not used.has(p.id) and p.injury_weeks <= 0 and not p.retiring: s.bench.append(p.id)
	return s

static func snapshot(w: GameWorld, code: String, squad: Array) -> Dictionary:
	var config := plan(w,code)
	var s := sheet(w,code,squad)
	var desc := {"style":s.style,"mentality":s.mentality,"pressing":s.pressing,"line":s.line,"width":s.width,"passing":s.passing,"mid":4.0,"cohesion":config["cohesion"]}
	var sums := {"tech":0.0,"decision":0.0,"stamina":0.0,"condition":0.0,"pace_att":0.0,"pace_def":0.0,"aerial_att":0.0,"aerial_def":0.0}
	var counts := {"all":0,"att":0,"def":0}
	for pid in s.starters:
		var p := w.player(int(pid))
		if p == null: continue
		counts["all"] += 1
		sums["tech"] += (p.attrs[Attr.TEC]+p.attrs[Attr.PAS])*0.5
		sums["decision"] += p.attrs[Attr.DEC]
		sums["stamina"] += p.attrs[Attr.RES]
		sums["condition"] += p.condition
		var group := "att" if Pos.group(p.position) >= 2 else "def"
		counts[group] += 1
		sums["pace_"+group] += p.attrs[Attr.VEL]
		sums["aerial_"+group] += (p.attrs[Attr.CAB]+p.attrs[Attr.FOR])*0.5
	for key in sums:
		var group := "att" if String(key).ends_with("_att") else ("def" if String(key).ends_with("_def") else "all")
		desc[key] = float(sums[key])/maxf(1.0,counts[group]) if counts[group] > 0 else NationalTeamManager._filler(code)
	return desc

static func after_result(w: GameWorld, result: Dictionary, expected: float) -> void:
	var code := nation(w)
	if code == "" or (result["a"] != code and result["b"] != code): return
	var d := data(w)
	var side := 0 if result["a"] == code else 1
	var goals := int(result["ga"] if side == 0 else result["gb"])
	var conceded := int(result["gb"] if side == 0 else result["ga"])
	var outcome := 1.0 if result["w"] == code else (0.5 if result["w"] == "" else 0.0)
	d["games"] += 1; d["job_games"] = int(d.get("job_games",0))+1
	if outcome == 1.0: d["wins"] += 1
	d["trust"] = clampf(float(d["trust"])+(outcome-expected)*11.0,0.0,100.0)
	plan(w,code)["cohesion"] = minf(85.0,float(plan(w,code)["cohesion"])+1.2)
	d["results"].append({"date":d.get("active_window", InternationalCalendar.iso(InternationalCalendar.season_date(w))),"a":result["a"],"b":result["b"],"ga":result["ga"],"gb":result["gb"],"w":result["w"],"xg":result.get("xg",[]),"engine":result.get("engine","quick"),"kits":result.get("kits",[])})
	if d["results"].size() > 50: d["results"].pop_front()
	if int(d.get("job_games",0)) >= 8 and float(d["trust"]) < 15.0: resign(w,true)

static func before_slot(w: GameWorld, slot: int) -> Array:
	var now := InternationalCalendar.season_date(w,slot)
	var y := int(Time.get_datetime_dict_from_unix_time(now)["year"])
	var first := InternationalCalendar.season_date(w,0)
	var out: Array = []
	var d := data(w)
	for win: Dictionary in InternationalCalendar.windows(y-1)+InternationalCalendar.windows(y):
		if int(win["b"]) < first: continue
		if now >= int(win["a"])-ANNOUNCE_DAYS*86400 and not d["announced"].has(win["id"]): announce(w,win)
		if now >= int(win["b"]) and not d["processed"].has(win["id"]):
			d["active_window"] = win["id"]
			out.append_array(NationalTeamManager.play_window(w,win))
			d["processed"][win["id"]] = true
			d["active_window"] = ""
	# Prune snapshots no longer needed by the current or next season.
	for id in d["announced"].keys():
		if InternationalCalendar.stamp(String(id)) < now-550*86400: d["announced"].erase(id)
	for id in d["processed"].keys():
		if InternationalCalendar.stamp(String(id)) < now-550*86400: d["processed"].erase(id)
	_hype(w,now)
	return out

static func _hype(w: GameWorld, now: int) -> void:
	var year := int(Time.get_datetime_dict_from_unix_time(now)["year"])
	var edition := NationalTeamManager.next_edition("WC",year)
	var approx := InternationalCalendar.stamp("%04d-06-01" % edition)
	var days := int((approx-now)/86400)
	if days < 0 or days > 365: return
	var stage := "preparação final" if days <= 30 else ("lista em observação" if days <= 90 else "ciclo de preparação")
	var key := str(edition)+":"+stage
	if data(w)["hype"].has(key): return
	data(w)["hype"][key] = true
	NewsManager.post_raw(w,"Copa do Mundo %d: %s" % [edition,stage],
		"As seleções acompanham forma, lesões e encaixe tático. O calendário do jogo usa junho como referência para a fase final, sem atribuir uma data oficial ainda não definida.",-1,-1,NewsEvent.IMP_HIGH,"selecao")

static func kit(code: String, kind: String = "home") -> Dictionary:
	# Original designs inspired by national colour identities; no licensed uniforms/logos.
	var colors: Array = DatabaseManager.nation(code).get("flag",{}).get("c",["#FFFFFF","#24324A"])
	var special := {"BRA":["#F7CE20","#17783F","#214CA0"],"ARG":["#81C8EE","#FFFFFF","#192347"],"ITA":["#185BBB","#FFFFFF","#183125"],"GER":["#FFFFFF","#151515","#7D1642"],"ESP":["#B71924","#EDCB35","#ECF3FF"],"FRA":["#123878","#FFFFFF","#F1F3F5"],"ENG":["#FFFFFF","#172941","#B61C35"],"NED":["#ED751A","#132138","#153365"],"POR":["#B31B30","#236648","#EAE7D2"],"JPN":["#1554BA","#FFFFFF","#EFEFEF"]}
	var palette: Array = special.get(code,[colors[0],colors[1] if colors.size()>1 else "#18253D","#F2F2F2"])
	var c1 := String(palette[0]); var c2 := String(palette[1])
	if kind == "away": c1 = String(palette[2]); c2 = String(palette[0])
	if kind == "gk": c1 = "#744CA7"; c2 = "#FFFFFF"
	return {"pattern":"stripes" if code == "ARG" and kind == "home" else "plain", "c1":c1,"c2":c2,"c3":c2,"collar":"v","sp":{},"sup":{}}


static func toggle_starter(w: GameWorld, pid: int) -> String:
	if not Array(data(w)["roster"]).has(pid): return "O jogador precisa estar convocado."
	var chosen: Array = plan(w,nation(w))["xi"]
	if chosen.has(pid): chosen.erase(pid)
	elif chosen.size() < 11:
		var p := w.player(pid)
		if p.position == Pos.GK and chosen.any(func(id): return w.player(int(id)) != null and w.player(int(id)).position == Pos.GK):
			return "Já há um goleiro entre os titulares preferidos."
		chosen.append(pid)
	else: return "Retire um titular antes de incluir outro."
	return ""
