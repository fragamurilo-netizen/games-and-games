class_name Matchmaker
extends RefCounted
## Quem luta com quem. As equipes rivais casam lutas entre si toda semana (perto no ranking, na
## mesma camada, sem revanche imediata); os lutadores do jogador recebem propostas de
## adversários perto deles no ranking e podem desafiar, como no LEATHER: perder atrasa os
## desafios para cima, e o campeão só defende o cinturão contra os primeiros da fila.

## Semanas mínimas de descanso entre lutas.
const REST := 7
## Janela de ranking para casar uma luta, por camada.
const WINDOW := [26, 12, 5]


static func rest_weeks(f: Fighter) -> int:
	if f.history.is_empty():
		return REST
	var last: Dictionary = f.history.back()
	if String(last.get("res", "")) == "D" and String(last.get("method", "")) in ["KO", "TKO"]:
		return REST + 4
	return REST


static func ready_to_book(w: GameWorld, f: Fighter, margin: int = 0) -> bool:
	return f.available() and w.week + margin - f.last_fight_week >= rest_weeks(f) and f.condition >= 70.0


## Bolsa pela camada, pelo ranking e pela fama: {show, win}.
static func purse(w: GameWorld, f: Fighter, tier: int, title: bool) -> Dictionary:
	var base: float = [2500.0, 10000.0, 30000.0][tier]
	var r := w.rank_of(f)
	var mult := 1.0
	if tier == 2:
		if r == 0:
			mult = 7.0
		elif r <= 5:
			mult = 2.8
		elif r <= 15:
			mult = 1.7
	elif tier == 1 and r > 0 and r <= Rankings.lgc_size(f.division) + 10:
		mult = 1.4
	mult *= 1.0 + f.popularity / 70.0
	if title:
		mult *= 1.6
	if not f.is_pro():
		mult *= 0.6
	var show := maxf(1000.0, snappedf(base * mult, 500.0))
	return {"show": show, "win": show}


static func make_bout(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter, title: bool = false, main: bool = false) -> Bout:
	# Corner vermelho para o mais bem ranqueado (o campeão sempre).
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	var a_first := (ra >= 0 and (rb < 0 or ra <= rb))
	var x := Bout.new()
	x.id = w.new_id()
	x.event_id = ev.id
	x.week = ev.week
	x.a = fa.id if a_first else fb.id
	x.b = fb.id if a_first else fa.id
	x.division = fa.division
	x.title = title
	x.main_event = main or title
	x.rounds = 5 if (title or (main and ev.tier == 2)) else 3
	x.purse_a = purse(w, w.fighter(x.a), ev.tier, title)
	x.purse_b = purse(w, w.fighter(x.b), ev.tier, title)
	w.bouts[x.id] = x
	if x.main_event:
		ev.bouts.append(x.id)
	else:
		ev.bouts.insert(0, x.id)
	fa.bout_id = x.id
	fb.bout_id = x.id
	return x


static func _last_opp(f: Fighter) -> int:
	if f.history.is_empty():
		return -1
	return int((f.history.back() as Dictionary).get("opp", -1))


## Pode lutar contra? Mesma categoria, equipes diferentes, sem revanche imediata.
static func can_face(w: GameWorld, fa: Fighter, fb: Fighter) -> bool:
	if fa.id == fb.id or fa.division != fb.division:
		return false
	if fa.team_id >= 0 and fa.team_id == fb.team_id:
		return false
	if _last_opp(fa) == fb.id or _last_opp(fb) == fa.id:
		return false
	return true


## Casamentos das equipes rivais para os eventos das próximas semanas.
static func book_cpu(w: GameWorld) -> void:
	_title_fights(w)
	var pools := {}
	for f: Fighter in w.fighters.values():
		if f.retired or w.is_user_fighter(f) or not f.is_pro():
			continue
		if not ready_to_book(w, f, 3):
			continue
		var tier := Rankings.tier_of(w, f)
		var key := "%d|%s" % [tier, f.division]
		if not pools.has(key):
			pools[key] = []
		pools[key].append(f)
	# Amadores sem equipe também estreiam no regional, de vez em quando.
	for f: Fighter in w.fighters.values():
		if not f.retired and not f.is_pro() and f.team_id >= 0 and not w.is_user_fighter(f) and ready_to_book(w, f, 3):
			var key := "0|%s" % f.division
			if not pools.has(key):
				pools[key] = []
			pools[key].append(f)
	for tier in [2, 1, 0]:
		for ev: FightEvent in Calendar.open_events(w, tier, w.week + 2, w.week + 8):
			var guard := 0
			while ev.bouts.size() < ev.slots and guard < 40:
				guard += 1
				if not _fill_one(w, ev, tier, pools):
					break


static func _fill_one(w: GameWorld, ev: FightEvent, tier: int, pools: Dictionary) -> bool:
	var keys: Array = []
	var weights: Array = []
	for key: String in pools:
		if key.begins_with("%d|" % tier) and (pools[key] as Array).size() >= 2:
			keys.append(key)
			weights.append(float((pools[key] as Array).size()))
	if keys.is_empty():
		return false
	var key: String = keys[RngUtil.weighted_index(w.rng, weights)]
	var pool: Array = pools[key]
	# Quem está parado há mais tempo luta primeiro (com um pouco de sorte no meio).
	pool.sort_custom(func(x: Fighter, y: Fighter) -> bool: return x.last_fight_week < y.last_fight_week)
	var fa: Fighter = pool[mini(pool.size() - 1, w.rng.randi_range(0, 2))]
	var ra := w.rank_of(fa)
	var best: Fighter = null
	var best_d := 9999.0
	for fb: Fighter in pool:
		if not can_face(w, fa, fb):
			continue
		var rb := w.rank_of(fb)
		var d := absf(float(ra if ra >= 0 else 999) - float(rb if rb >= 0 else 999)) + w.rng.randf_range(0.0, 3.0)
		if d < best_d:
			best_d = d
			best = fb
	if best == null or best_d > WINDOW[tier] + 3.0:
		pool.erase(fa)
		return true
	var main := ev.bouts.size() == ev.slots - 1
	make_bout(w, ev, fa, best, false, main)
	pool.erase(fa)
	pool.erase(best)
	return true


## Disputas de cinturão nas noites da Liga Global: campeão contra o melhor desafiante disponível
## (ou os dois primeiros pelo cinturão vago).
static func _title_fights(w: GameWorld) -> void:
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		if _title_booked(w, div):
			continue
		var champ := w.fighter(int(w.champions.get(div, -1)))
		var lst: Array = w.rankings.get(div, [])
		var contenders: Array = []
		for i in mini(4, lst.size()):
			var c := w.fighter(int(lst[i]))
			if c != null and ready_to_book(w, c, 4) and not w.is_user_fighter(c):
				contenders.append(c)
		var evs := Calendar.open_events(w, 2, w.week + 4, w.week + 9)
		evs = evs.filter(func(e: FightEvent) -> bool: return not _has_main(w, e))
		if evs.is_empty():
			continue
		if champ == null:
			if contenders.size() >= 2 and can_face(w, contenders[0], contenders[1]):
				make_bout(w, evs[0], contenders[0], contenders[1], true, true)
				w.add_news("cinturao", "Cinturão vago dos %s: %s e %s disputam na %s." % [division_name(div, true), (contenders[0] as Fighter).display_name(), (contenders[1] as Fighter).display_name(), (evs[0] as FightEvent).name], [(contenders[0] as Fighter).id, (contenders[1] as Fighter).id])
			continue
		if w.is_user_fighter(champ) or not ready_to_book(w, champ, 4) or w.week - champ.last_fight_week < 12:
			continue
		for c: Fighter in contenders:
			if can_face(w, champ, c):
				make_bout(w, evs[0], champ, c, true, true)
				w.add_news("cinturao", "%s defende o cinturão dos %s contra %s na %s." % [champ.display_name(), division_name(div, true), c.display_name(), (evs[0] as FightEvent).name], [champ.id, c.id])
				break


static func _title_booked(w: GameWorld, div: String) -> bool:
	for b: Bout in w.bouts.values():
		if b.title and b.division == div and b.status == "marcada":
			return true
	return false


static func _has_main(w: GameWorld, e: FightEvent) -> bool:
	for bid: int in e.bouts:
		var b := w.bout(bid)
		if b != null and b.main_event:
			return true
	return false


## "peso-leve masculino" / "peso-palha feminino" (`plural`: "pesos-leves").
static func division_name(div: String, plural: bool = false) -> String:
	var d := DataDB.division(div)
	var n := String(d.get("name", div)).to_lower()
	var fem := String(d.get("sex", "m")) == "f"
	if plural:
		return "pesos-%s%s" % [_plural(n), " femininos" if fem else ""]
	return "peso-%s%s" % [n, " feminino" if fem else ""]


static func _plural(n: String) -> String:
	if n.ends_with("o") or n.ends_with("a") or n.ends_with("e"):
		return n + "s"
	if n == "leve":
		return "leves"
	return n


## Nome curto para listas: "Leve", "Palha (F)".
static func division_short(div: String) -> String:
	var d := DataDB.division(div)
	return String(d.get("name", div)) + (" (F)" if String(d.get("sex", "m")) == "f" else "")


# --- Propostas e desafios do jogador --------------------------------------------------------

## Propostas da semana para os lutadores do jogador (adversários perto no ranking).
static func user_offers(w: GameWorld) -> void:
	w.offers = w.offers.filter(func(o: Dictionary) -> bool: return int(o["expires"]) >= w.week and w.fighter(int(o["fighter"])) != null and w.fighter(int(o["fighter"])).bout_id < 0)
	var team := w.user_team()
	if team == null:
		return
	for f: Fighter in w.user_fighters():
		if not ready_to_book(w, f, 2):
			continue
		var mine := w.offers.filter(func(o: Dictionary) -> bool: return int(o["fighter"]) == f.id)
		if mine.size() >= 2:
			continue
		if w.rng.randf() > 0.38 + team.reputation / 350.0:
			continue
		var o := _make_offer(w, f)
		if not o.is_empty():
			w.offers.append(o)


static func _make_offer(w: GameWorld, f: Fighter, opp_override: Fighter = null) -> Dictionary:
	var tier := Rankings.tier_of(w, f)
	if not f.is_pro():
		tier = 0
	elif w.rng.randf() < 0.15 and tier < 2:
		tier += 1 # chance de subir de nível
	var evs := Calendar.open_events(w, tier, w.week + 3, w.week + 9)
	if evs.is_empty():
		return {}
	var ev: FightEvent = evs[w.rng.randi_range(0, mini(evs.size() - 1, 3))]
	var opp := opp_override
	if opp == null:
		var r := w.rank_of(f)
		var cands: Array = []
		for o: Fighter in w.in_division(f.division):
			if w.is_user_fighter(o) or not o.is_pro() and f.is_pro():
				continue
			if not ready_to_book(w, o, 2) or not can_face(w, f, o):
				continue
			var ro := w.rank_of(o)
			var gap := absf(float(r if r >= 0 else 999) - float(ro if ro >= 0 else 999))
			if not f.is_pro():
				gap = absf(o.fights() - 0.0) * 4.0 + absf(o.level() - f.level())
			if gap <= WINDOW[tier] + 2:
				cands.append([gap + w.rng.randf_range(0.0, 4.0), o])
		if cands.is_empty():
			return {}
		cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		opp = (cands[mini(cands.size() - 1, w.rng.randi_range(0, 2))] as Array)[1]
	var p := purse(w, f, ev.tier, false)
	return {"id": w.new_id(), "fighter": f.id, "opp": opp.id, "event": ev.id, "week": ev.week,
		"rounds": 3, "show": p["show"], "win": p["win"], "expires": w.week + 2, "kind": "proposta"}


## Aceita uma proposta: confere se o adversário e a vaga ainda existem. Devolve o erro ou "".
static func accept_offer(w: GameWorld, offer: Dictionary) -> String:
	var f := w.fighter(int(offer["fighter"]))
	var o := w.fighter(int(offer["opp"]))
	var ev := w.event(int(offer["event"]))
	w.offers.erase(offer)
	if f == null or o == null or ev == null:
		return "A proposta não vale mais."
	if not f.available():
		return "%s não está disponível." % f.short_name()
	if not o.available():
		return "%s já fechou outra luta. A proposta caiu." % o.display_name()
	if ev.bouts.size() >= ev.slots or ev.done:
		return "O card da %s fechou. A proposta caiu." % ev.name
	var b := make_bout(w, ev, f, o)
	b.purse_of(f.id)["show"] = float(offer["show"])
	b.purse_of(f.id)["win"] = float(offer["win"])
	w.offers = w.offers.filter(func(x: Dictionary) -> bool: return int(x["fighter"]) != f.id)
	w.add_news("equipe", "%s enfrenta %s na %s (%s)." % [f.display_name(), o.display_name(), ev.name, GameWorld.fight_date_text(ev.week)], [f.id, o.id])
	return ""


## Por que não dá para desafiar (vazio = pode).
static func challenge_block_reason(w: GameWorld, mine: Fighter, target: Fighter) -> String:
	if mine.division != target.division:
		return "Eles não são da mesma categoria."
	if target.retired:
		return "%s se aposentou." % target.display_name()
	if w.is_user_fighter(target):
		return "Os dois são da sua equipe."
	if not mine.available():
		return "%s não está disponível (luta marcada, lesão ou suspensão)." % mine.short_name()
	if not ready_to_book(w, mine, 4):
		return "%s ainda precisa descansar antes de outra luta." % mine.short_name()
	if not target.available():
		return "%s já tem luta marcada ou está machucado." % target.display_name()
	if not mine.is_pro():
		return "Amador não desafia: precisa estrear com uma proposta do circuito regional."
	var key := "%d:%d" % [mine.id, target.id]
	if int(w.challenge_block.get(key, -1)) > w.week:
		return "A equipe de %s já recusou. Tente de novo em %d semanas." % [target.short_name(), int(w.challenge_block[key]) - w.week]
	var rm := w.rank_of(mine)
	var rt := w.rank_of(target)
	if _last_opp(mine) == target.id:
		return "Revanche imediata ninguém aceita."
	if rt == 0:
		if rm < 1 or rm > 3:
			return "O campeão só defende o cinturão contra os três primeiros do ranking."
	var above := rt >= 0 and (rm < 0 or rt < rm)
	if above and w.week < mine.challenge_lock:
		return "Depois da derrota, ninguém de cima aceita por enquanto. Libera em %d semanas." % (mine.challenge_lock - w.week)
	if above and rt > 0:
		var window := 5 if rm >= 0 and rm <= 20 else 10
		if rm < 0 or rm - rt > window:
			return "%s está muito acima no ranking. Suba mais antes de chamar." % target.short_name()
	return ""


## Chance de a equipe do alvo aceitar (0–1), para a interface mostrar antes.
static func challenge_chance(w: GameWorld, mine: Fighter, target: Fighter) -> float:
	var rm := w.rank_of(mine)
	var rt := w.rank_of(target)
	var p := 0.82
	if rt >= 0 and rm >= 0 and rt < rm:
		p -= (rm - rt) * 0.07
	if rt == 0:
		p = 0.75 if rm == 1 else 0.45
	if rm >= 0 and rt >= 0 and rt > rm:
		p = 0.9
	p += (mine.popularity - target.popularity) / 250.0
	return clampf(p, 0.05, 0.95)


## Desafio: a equipe do alvo responde na hora. {ok, text, bout}
static func challenge(w: GameWorld, mine: Fighter, target: Fighter) -> Dictionary:
	var why := challenge_block_reason(w, mine, target)
	if why != "":
		return {"ok": false, "text": why}
	var p := challenge_chance(w, mine, target)
	if w.rng.randf() >= p:
		w.challenge_block["%d:%d" % [mine.id, target.id]] = w.week + 6
		var excuses := ["A equipe de %s diz que ele não ganha nada lutando com %s.", "%s tem outros planos para este ano, responde a equipe.", "A equipe de %s pede uma bolsa que nenhum evento paga. Recusado."]
		var t: String = excuses[w.rng.randi_range(0, excuses.size() - 1)]
		var txt := t % [target.short_name(), mine.short_name()] if t.count("%s") == 2 else t % target.short_name()
		return {"ok": false, "text": txt}
	var title := w.rank_of(target) == 0
	var tier := maxi(Rankings.tier_of(w, mine), Rankings.tier_of(w, target))
	if title:
		tier = 2
	var evs := Calendar.open_events(w, tier, w.week + 4, w.week + 10)
	if title:
		evs = evs.filter(func(e: FightEvent) -> bool: return not _has_main(w, e))
	if evs.is_empty():
		return {"ok": false, "text": "Aceitaram, mas não há data livre nos próximos eventos. Tente na semana que vem."}
	var ev: FightEvent = evs[0]
	var b := make_bout(w, ev, mine, target, title, title)
	w.add_news("equipe", "Desafio aceito: %s enfrenta %s na %s%s." % [mine.display_name(), target.display_name(), ev.name, " valendo o cinturão" if title else ""], [mine.id, target.id], title)
	return {"ok": true, "text": "Desafio aceito! %s × %s na %s, %s." % [mine.short_name(), target.short_name(), ev.name, GameWorld.fight_date_text(ev.week)], "bout": b.id}
