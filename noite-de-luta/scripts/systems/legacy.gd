class_name Legacy
extends RefCounted
## O mundo que fica: prêmios do ano (lutador e lutadora do ano, revelação, luta, nocaute e
## finalização do ano), Hall da Fama de quem se aposentou com história, recordes da liga e a
## limpeza do save (aposentados sem história saem depois de alguns anos).
##
## Durante o ano cada luta feita passa por `on_bout`, que guarda só os melhores candidatos
## (as lutas antigas saem do save, os candidatos não). Na virada do ano, `year_end` entrega os
## prêmios, faz a cerimônia do Hall da Fama, envelhece o visual de todo mundo e limpa o save.

## Pontos de legado para entrar no Hall da Fama (ver `legacy_score`).
const HOF_MIN := 46.0
const HOF_PER_YEAR := 3
## Aposentado sem história sai do save depois disso (semanas).
const PRUNE_AFTER := 156

const AWARDS := [
	["lutador", "Lutador do ano"],
	["lutadora", "Lutadora do ano"],
	["revelacao", "Revelação do ano"],
	["luta", "Luta do ano"],
	["nocaute", "Nocaute do ano"],
	["finalizacao", "Finalização do ano"],
]


# --- Durante o ano ---------------------------------------------------------------------

## Depois de cada luta: guarda a luta, o nocaute e a finalização mais marcantes do ano.
static func on_bout(w: GameWorld, b: Bout, e: FightEngine) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	if fa == null or fb == null:
		return
	var ev := w.event(b.event_id)
	var tier := ev.tier if ev != null else 0
	var res := b.result
	var method := String(res.get("method", "DEC"))
	var winner := int(res.get("winner_id", -1))
	var rnd := int(res.get("round", b.rounds))
	var tm := float(res.get("time", 300.0))
	var lv := (fa.level() + fb.level()) * 0.5
	var stage := tier * 6.0 + (8.0 if b.title else 0.0) + (2.0 if b.main_event else 0.0) + maxf(0.0, lv - 60.0) * 0.4
	var ta: Dictionary = e.s[0]["total"] if e != null else {}
	var tb: Dictionary = e.s[1]["total"] if e != null else {}
	var kd_a := int(ta.get("kd", 0))
	var kd_b := int(tb.get("kd", 0))
	var land_a := int(ta.get("sig_land", 0))
	var land_b := int(tb.get("sig_land", 0))
	# Luta do ano: os dois machucaram, virada, guerra até o fim.
	var war := (kd_a + kd_b) * 3.0 + minf(land_a, land_b) * 0.09 + (7.0 if kd_a > 0 and kd_b > 0 else 0.0)
	war += float(int(ta.get("sub_att", 0)) + int(tb.get("sub_att", 0))) * 0.8 + float(int(ta.get("rev", 0)) + int(tb.get("rev", 0))) * 0.6
	if method in ["KO", "TKO", "FIN"]:
		war += 3.0 + (4.0 if rnd >= 3 else 0.0)
		if winner >= 0:
			# Virada: quem venceu tinha ido ao chão antes.
			var w_down := int((e.s[0] if winner == b.a else e.s[1]).get("kd", 0)) if e != null else 0
			if w_down > 0:
				war += 9.0
	elif method == "DEC":
		var cards: Array = res.get("cards", [])
		var split := false
		if cards.size() == 3:
			var va := 0
			for c: Array in cards:
				if float(c[0]) > float(c[1]):
					va += 1
			split = va == 1 or va == 2
		war += 4.0 if split else 0.0
		war += 2.0 if b.rounds == 5 else 0.0
	_candidate(w, "luta", war + stage, b, winner, "%s × %s, %s" % [fa.display_name(), fb.display_name(), _how(b)])
	if winner < 0:
		return
	var wf := w.fighter(winner)
	var lf := w.fighter(b.other(winner))
	var detail := String(res.get("detail", "")).to_lower()
	if method in ["KO", "TKO"]:
		var flair := 0.0
		for k: String in ["girat", "rodado", "voador", "alto", "joelhada voadora", "superman", "cotovelada", "backfist"]:
			if detail.contains(k):
				flair = 6.0
				break
		var speed := 8.0 if rnd == 1 and tm < 45.0 else (4.0 if rnd == 1 and tm < 120.0 else 0.0)
		var score := stage + flair + speed + maxf(0.0, lf.level() - 55.0) * 0.5 + (5.0 if method == "KO" else 0.0)
		_candidate(w, "nocaute", score, b, winner, "%s nocauteia %s com %s, %s" % [wf.display_name(), lf.display_name(), detail, _round_time(rnd, tm)])
	elif method == "FIN":
		var rare := 0.0
		for k: String in ["calcanhar", "d'arce", "gogoplata", "tarântula", "omoplata", "twister", "triângulo de braço", "joelho", "estrela", "chave de pé", "triângulo"]:
			if detail.contains(k):
				rare = 6.0
				break
		var score2 := stage + rare + maxf(0.0, lf.level() - 55.0) * 0.5 + (5.0 if rnd >= 3 else 0.0) + (4.0 if rnd == 1 and tm < 90.0 else 0.0)
		_candidate(w, "finalizacao", score2, b, winner, "%s finaliza %s com %s, %s" % [wf.display_name(), lf.display_name(), detail, _round_time(rnd, tm)])


static func _how(b: Bout) -> String:
	var res := b.result
	var method := String(res.get("method", "DEC"))
	var detail := String(res.get("detail", ""))
	if method in ["DEC", "EMP"]:
		return detail.to_lower() if detail != "" else "decisão"
	return "%s no %dº round" % [detail.to_lower(), int(res.get("round", 1))]


static func _round_time(rnd: int, tm: float) -> String:
	return "%dº round, %d:%02d" % [rnd, int(tm) / 60, int(tm) % 60]


static func _candidate(w: GameWorld, key: String, score: float, b: Bout, winner: int, text: String) -> void:
	var y := str(w.year())
	if String(w.season.get("year", "")) != y:
		w.season = {"year": y}
	var cur: Dictionary = w.season.get(key, {})
	if not cur.is_empty() and float(cur.get("score", 0.0)) >= score:
		return
	var ev := w.event(b.event_id)
	w.season[key] = {"score": snappedf(score, 0.1), "a": b.a, "b": b.b, "winner": winner, "text": text,
		"event": ev.name if ev != null else "", "week": b.week, "div": b.division, "title": b.title}


# --- Virada do ano -----------------------------------------------------------------------

## Chamado na primeira semana de cada ano (antes das lutas dela): fecha o ano anterior.
static func year_end(w: GameWorld, year: int) -> void:
	var items := _awards(w, year)
	if not items.is_empty():
		w.awards.append({"year": year, "items": items})
		var lines: Array = []
		for it: Dictionary in items:
			if it.has("id"):
				lines.append("%s: %s" % [String(it["title"]), String(it["name"])])
		w.add_news("premio", "Prêmios de %d. %s." % [year, ". ".join(lines)], _award_ids(items), true)
	_induct(w, year)
	Development.yearly_look(w)
	_prune(w)
	w.season = {"year": str(year + 1)}


static func _award_ids(items: Array) -> Array:
	var ids: Array = []
	for it: Dictionary in items:
		for k: String in ["id", "a", "b"]:
			if it.has(k) and int(it[k]) >= 0 and not ids.has(int(it[k])):
				ids.append(int(it[k]))
	return ids


static func _awards(w: GameWorld, year: int) -> Array:
	var items: Array = []
	var best := {"lutador": [null, 0.0, ""], "lutadora": [null, 0.0, ""], "revelacao": [null, 0.0, ""]}
	for f: Fighter in w.fighters.values():
		if f.history.is_empty():
			continue
		var wins := 0
		var losses := 0
		var score := 0.0
		var belts := 0
		var fins := 0
		var first_year := 9999
		for h: Dictionary in f.history:
			var hy := int(GameWorld.date_of(int(h["week"]))["year"])
			first_year = mini(first_year, hy)
			if hy != year:
				continue
			var res := String(h["res"])
			var tier := int(h.get("tier", 0))
			if res == "V":
				wins += 1
				score += 3.0 + tier * 1.6
				if String(h["method"]) != "DEC":
					score += 1.5
					fins += 1
				if bool(h.get("title", false)):
					score += 7.0
					belts += 1
				var o := w.fighter(int(h["opp"]))
				if o != null:
					score += maxf(0.0, o.level() - 60.0) * 0.25
			elif res == "D":
				losses += 1
				score -= 4.0
		if wins < 2:
			continue
		var why := "%d %s em %d%s%s" % [wins, "vitória" if wins == 1 else "vitórias", year, ", %d %s" % [belts, "luta de cinturão vencida" if belts == 1 else "lutas de cinturão vencidas"] if belts > 0 else "", ", %d antes do fim" % fins if fins > 0 else ""]
		if losses > 0:
			why += ", %d %s" % [losses, "derrota" if losses == 1 else "derrotas"]
		var key := "lutadora" if f.is_female() else "lutador"
		if score > float(best[key][1]):
			best[key] = [f, score, why]
		# Revelação: primeiro ou segundo ano de profissional, sem derrota no ano.
		if year - first_year <= 1 and losses == 0 and wins >= 2 and score > float(best["revelacao"][1]):
			best["revelacao"] = [f, score, why]
	for a: Array in AWARDS:
		var key2 := String(a[0])
		if best.has(key2):
			var f2: Fighter = best[key2][0]
			if f2 == null:
				continue
			if key2 == "revelacao" and (best["lutador"][0] == f2 or best["lutadora"][0] == f2):
				continue
			items.append({"key": key2, "title": String(a[1]), "id": f2.id, "name": f2.display_name(), "text": String(best[key2][2])})
		elif w.season.has(key2) and String(w.season.get("year", "")) == str(year):
			var c: Dictionary = w.season[key2]
			var it := {"key": key2, "title": String(a[1]), "a": int(c["a"]), "b": int(c["b"]), "text": String(c["text"]), "event": String(c.get("event", "")), "week": int(c.get("week", 0))}
			var wid := int(c.get("winner", -1))
			if wid >= 0:
				it["id"] = wid
				var wf := w.fighter(wid)
				it["name"] = wf.display_name() if wf != null else ""
			else:
				it["name"] = String(c["text"]).get_slice(",", 0)
			items.append(it)
	return items


## Pontos de legado de uma carreira (Hall da Fama).
static func legacy_score(f: Fighter) -> float:
	var r := f.record
	var s := f.titles_won * 14.0 + f.title_defenses * 7.0 + int(r["w"]) * 0.9 - int(r["l"]) * 0.3
	s += (int(r.get("ko_w", 0)) + int(r.get("sub_w", 0))) * 0.35 + f.popularity * 0.18
	return s


static func in_hall(w: GameWorld, fid: int) -> bool:
	for h: Dictionary in w.hall:
		if int(h["id"]) == fid:
			return true
	return false


## Cerimônia do Hall da Fama: até 4 aposentados por ano, os de mais legado primeiro.
static func _induct(w: GameWorld, year: int) -> void:
	var cands: Array = []
	for f: Fighter in w.fighters.values():
		if f.retired and not in_hall(w, f.id) and legacy_score(f) >= HOF_MIN and w.week - f.retired_week >= 26:
			cands.append(f)
	cands.sort_custom(func(x: Fighter, y: Fighter) -> bool: return legacy_score(x) > legacy_score(y))
	var names: Array = []
	for f: Fighter in cands.slice(0, HOF_PER_YEAR):
		var why := "%s, %s" % [f.record_text(), "%d %s" % [f.titles_won, "cinturão" if f.titles_won == 1 else "cinturões"] if f.titles_won > 0 else "%d vitórias" % int(f.record["w"])]
		if f.title_defenses > 0:
			why += ", %d %s" % [f.title_defenses, "defesa" if f.title_defenses == 1 else "defesas"]
		w.hall.append({"id": f.id, "name": f.display_name(), "year": year, "div": f.division, "nation": f.nation, "text": why, "score": snappedf(legacy_score(f), 0.1)})
		names.append(f.display_name())
	if not names.is_empty():
		var ids: Array = cands.slice(0, HOF_PER_YEAR).map(func(f: Fighter) -> int: return f.id)
		w.add_news("hall", "Hall da Fama, turma de %d: %s." % [year, ", ".join(names)], ids, true)


## Tira do save os aposentados sem história, alguns anos depois (o save não cresce para sempre).
static func _prune(w: GameWorld) -> void:
	var keep := {}
	for b: Bout in w.bouts.values():
		keep[b.a] = true
		keep[b.b] = true
	for o: Dictionary in w.offers:
		keep[int(o.get("fighter", -1))] = true
		keep[int(o.get("opp", -1))] = true
	for i: Dictionary in w.incidents:
		for k: String in ["fighter", "opp", "sub"]:
			keep[int(i.get(k, -1))] = true
	for fid: int in w.followed:
		keep[fid] = true
	for h2: Dictionary in w.hall:
		keep[int(h2["id"])] = true
	for a: Dictionary in w.awards:
		for id: int in _award_ids(a["items"]):
			keep[id] = true
	var gone: Array = []
	for f: Fighter in w.fighters.values():
		if not f.retired or keep.has(f.id) or w.week - f.retired_week < PRUNE_AFTER:
			continue
		if f.titles_won > 0:
			continue
		gone.append(f.id)
	for fid: int in gone:
		w.fighters.erase(fid)


# --- Para as telas -----------------------------------------------------------------------

## Recordes da liga entre todos os lutadores que o mundo ainda lembra.
static func records(w: GameWorld) -> Array:
	var defs := [
		["Mais vitórias", func(f: Fighter) -> int: return int(f.record["w"])],
		["Mais nocautes", func(f: Fighter) -> int: return int(f.record.get("ko_w", 0))],
		["Mais finalizações", func(f: Fighter) -> int: return int(f.record.get("sub_w", 0))],
		["Mais defesas de cinturão", func(f: Fighter) -> int: return f.title_defenses],
		["Mais cinturões conquistados", func(f: Fighter) -> int: return f.titles_won],
		["Maior sequência de vitórias", func(f: Fighter) -> int: return best_streak(f)],
	]
	var out: Array = []
	for d: Array in defs:
		var getter: Callable = d[1]
		var top: Array = []
		for f: Fighter in w.fighters.values():
			var v := int(getter.call(f))
			if v > 0:
				top.append([v, f])
		top.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) > int(y[0]) or (int(x[0]) == int(y[0]) and (x[1] as Fighter).id < (y[1] as Fighter).id))
		out.append({"title": String(d[0]), "top": top.slice(0, 3)})
	return out


static func best_streak(f: Fighter) -> int:
	var best := 0
	var cur := 0
	for h: Dictionary in f.history:
		if String(h["res"]) == "V":
			cur += 1
			best = maxi(best, cur)
		elif String(h["res"]) in ["D", "E"]:
			cur = 0
	return best


## Prêmios que um lutador ganhou (para o perfil): ["Lutador do ano 2028", ...]
static func honors(w: GameWorld, f: Fighter) -> Array:
	var out: Array = []
	for a: Dictionary in w.awards:
		for it: Dictionary in a["items"]:
			if int(it.get("id", -1)) == f.id:
				out.append("%s %d" % [String(it["title"]), int(a["year"])])
	for h: Dictionary in w.hall:
		if int(h["id"]) == f.id:
			out.push_front("Hall da Fama (turma de %d)" % int(h["year"]))
	return out
