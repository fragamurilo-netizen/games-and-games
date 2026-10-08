class_name Career
extends RefCounted
## O relógio da carreira. Uma semana por vez: as lutas do sábado (as da equipe do jogador são
## jogadas na tela de luta antes de a semana fechar), pesagem, bolsas, ranking, treino,
## finanças, propostas novas e o calendário andando.

const START_FUNDS := [100000.0, 250000.0, 500000.0]
## Despesas fixas da academia por semana (aluguel, luz, material) e por lutador (camp).
const RENT := 1800.0
const PER_FIGHTER := 250.0


static func new_career(team_name: String, short: String, nation: String, city: String, c1: Color, c2: Color, funds: float, seed_v: int) -> GameWorld:
	var w := WorldGenerator.generate(seed_v)
	var t := Team.new()
	t.id = w.new_id()
	t.name = team_name
	t.short = short if short != "" else WorldGenerator.short_of(team_name)
	t.nation = nation
	t.city = city
	t.color1 = c1
	t.color2 = c2
	t.reputation = 15.0
	t.balance = funds
	t.is_user = true
	w.teams[t.id] = t
	w.user_team_id = t.id
	t.ledger.append({"week": 0, "label": "Caixa inicial", "value": funds})
	w.add_news("equipe", "Nasce a %s, em %s. Hora de montar a equipe." % [t.name, city if city != "" else DataDB.nation_name(nation)], [], true)
	return w


## Lutas do jogador nesta semana que ainda não foram feitas: as da equipe (empresário) ou as da
## noite da organização (presidente).
static func pending_user_bouts(w: GameWorld) -> Array:
	if w.is_president():
		return Org.pending_bouts(w)
	var out: Array = []
	for f: Fighter in w.user_fighters():
		var b := w.bout(f.bout_id)
		if b != null and b.status == "marcada" and b.week == w.week and not out.has(b):
			out.append(b)
	return out


# --- Pesagem ------------------------------------------------------------------------------

## Pesagem (uma vez por luta; o resultado fica guardado na luta). Corte grande cobra fôlego e
## queixo; quem passa do limite perde 20% da bolsa para o adversário.
static func weigh_in(w: GameWorld, b: Bout) -> Dictionary:
	if not b.weigh.is_empty():
		return b.weigh
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed, b.id, "pesagem"])
	var limit := float(DataDB.division(b.division).get("limit_kg", 70.0)) + (0.5 if not b.title else 0.0)
	var res := {"kg": [], "missed": [], "mods": [{}, {}], "cut": []}
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		var team := w.team(f.team_id)
		var nutri := team.staff_quality("nutri") if team != null else 30.0
		var cut := maxf(0.0, (f.natural_kg - limit) / f.natural_kg)
		res["cut"].append(cut)
		var miss_p := clampf((cut - 0.1) * 3.2 - nutri / 400.0 - f.a("qi") / 1000.0, 0.0, 0.6)
		var kg := limit - r.randf_range(0.0, 0.4)
		if r.randf() < miss_p:
			kg = limit + r.randf_range(0.3, 2.4)
			res["missed"].append(f.id)
		res["kg"].append(snappedf(kg, 0.1))
		# Corte pesado: fôlego e queixo cobram na luta.
		var harsh := maxf(0.0, cut - 0.1) * (1.0 - nutri / 200.0)
		var m := {}
		if harsh > 0.0:
			m["cardio"] = -harsh * 90.0
			m["queixo"] = -harsh * 40.0
		# Condição física abaixo de 100%.
		var cond := (100.0 - f.condition) / 100.0
		if cond > 0.0:
			m["cardio"] = float(m.get("cardio", 0.0)) - cond * 22.0
			m["queixo"] = float(m.get("queixo", 0.0)) - cond * 10.0
		res["mods"][i] = m
	b.weigh = res
	return res


# --- Lutas --------------------------------------------------------------------------------

static func engine_for(w: GameWorld, b: Bout, narrate: bool) -> FightEngine:
	var wi := weigh_in(w, b)
	var e := FightEngine.new()
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed, b.id, "luta"])
	e.setup(w.fighter(b.a), w.fighter(b.b), b.rounds, b.title, r, {"narrate": narrate, "mods": wi["mods"], "ko": float(DataDB.division(b.division).get("ko", 1.0))})
	return e


static func simulate(w: GameWorld, b: Bout) -> void:
	var e := engine_for(w, b, false)
	var res := e.run_all()
	resolve(w, b, res, e)


## Aplica o resultado: cartel, histórico, bolsas, ranking, cinturão, lesões e notícias.
static func resolve(w: GameWorld, b: Bout, res: Dictionary, e: FightEngine) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	var side := int(res.get("winner", -1))
	var winner_id := -1 if side < 0 else (b.a if side == 0 else b.b)
	var method := String(res.get("method", "DEC"))
	b.result = res.duplicate(true)
	b.result["winner_id"] = winner_id
	b.status = "feita"
	var ev := w.event(b.event_id)
	var champ_before := int(w.champions.get(b.division, -1))
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	Rankings.apply_result(w, b)
	for i in 2:
		var f := fa if i == 0 else fb
		var o := fb if i == 0 else fa
		var won := winner_id == f.id
		var res_code := "E" if winner_id < 0 else ("V" if won else "D")
		var rec := f.record
		if res_code == "E":
			rec["d"] = int(rec["d"]) + 1
		elif won:
			rec["w"] = int(rec["w"]) + 1
			var k := "ko_w" if method in ["KO", "TKO"] else ("sub_w" if method == "FIN" else "dec_w")
			rec[k] = int(rec[k]) + 1
		else:
			rec["l"] = int(rec["l"]) + 1
			var k2 := "ko_l" if method in ["KO", "TKO"] else ("sub_l" if method == "FIN" else "dec_l")
			rec[k2] = int(rec[k2]) + 1
			# Derrota atrasa os desafios para cima (LEATHER).
			f.challenge_lock = w.week + 8
		f.history.append({"week": w.week, "opp": o.id, "opp_name": o.display_name(), "res": res_code, "method": method,
			"detail": String(res.get("detail", "")), "round": int(res.get("round", b.rounds)), "time": float(res.get("time", 300.0)),
			"event": ev.name if ev != null else "", "title": b.title, "tier": ev.tier if ev != null else 0, "bout": b.id})
		f.last_fight_week = w.week
		f.bout_id = -1
		if f.contract.has("fights"):
			f.contract["fights"] = int(f.contract["fights"]) - 1
		# Fama: ganhar (e ganhar bonito) dá nome; perder tira um pouco.
		var tier := ev.tier if ev != null else 0
		if won:
			f.popularity = minf(100.0, f.popularity + 1.5 + tier * 1.5 + (2.0 if method != "DEC" else 0.0) + (8.0 if b.title else 0.0))
		elif res_code == "D":
			f.popularity = maxf(1.0, f.popularity - 1.0)
		var st: Dictionary = e.s[i] if e != null else {}
		Development.after_fight(w, f, float(st.get("head", 0.5)), float(st.get("body", 0.2)), float(st.get("legs", 0.2)), float(st.get("cut", 0.0)), res_code == "D" and method in ["KO", "TKO"])
	_pay(w, b, winner_id)
	_reputation(w, b, winner_id, ra, rb)
	_news(w, b, winner_id, method, champ_before, ra, rb)
	if not w.played_this_week.has(b.id):
		w.played_this_week.append(b.id)


static func _pay(w: GameWorld, b: Bout, winner_id: int) -> void:
	var wi := b.weigh
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		var p := b.purse_of(fid)
		var total := float(p["show"]) + (float(p["win"]) if winner_id == fid else 0.0)
		var missed: Array = wi.get("missed", [])
		if missed.has(fid):
			total -= float(p["show"]) * 0.2
		var other := b.other(fid)
		if missed.has(other):
			total += float(b.purse_of(other)["show"]) * 0.2
		var team := w.team(f.team_id)
		if team != null:
			var cut := float(f.contract.get("cut", 0.2))
			var label := "%s × %s" % [f.short_name(), w.fighter(other).short_name()]
			team.add_money(w.week, label, total * cut)


static func _reputation(w: GameWorld, b: Bout, winner_id: int, ra: int, rb: int) -> void:
	var ev := w.event(b.event_id)
	var tier := ev.tier if ev != null else 0
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		var team := w.team(f.team_id)
		if team == null:
			continue
		var r_opp := rb if fid == b.a else ra
		var gain := 0.0
		if winner_id == fid:
			gain = 0.6 + tier * 0.9 + (1.5 if r_opp >= 0 and r_opp <= 15 else 0.0) + (5.0 if b.title else 0.0)
		elif winner_id >= 0:
			gain = -0.4 - tier * 0.3
		# Equipe grande ganha pouco com vitória pequena.
		gain *= 1.2 - team.reputation / 120.0
		team.reputation = clampf(team.reputation + gain, 1.0, 100.0)


static func _news(w: GameWorld, b: Bout, winner_id: int, method: String, champ_before: int, ra: int, rb: int) -> void:
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	var ev := w.event(b.event_id)
	var mine := w.is_user_fighter(fa) or w.is_user_fighter(fb)
	var detail := String(b.result.get("detail", ""))
	var how := "%s no %dº round" % [detail, int(b.result.get("round", 1))] if method != "DEC" and method != "EMP" else detail
	if winner_id < 0:
		if mine or b.title:
			w.add_news("resultado", "%s e %s empatam na %s." % [fa.display_name(), fb.display_name(), ev.name], [fa.id, fb.id], b.title)
		return
	var wf := w.fighter(winner_id)
	var lf := w.fighter(b.other(winner_id))
	if b.title:
		if champ_before == winner_id:
			w.add_news("cinturao", "%s defende o cinturão dos %s: vence %s por %s." % [wf.display_name(), Matchmaker.division_name(b.division, true), lf.display_name(), how], [wf.id, lf.id], true)
		else:
			w.add_news("cinturao", "Novo campeão! %s vence %s por %s e leva o cinturão dos %s." % [wf.display_name(), lf.display_name(), how, Matchmaker.division_name(b.division, true)], [wf.id, lf.id], true)
		return
	var rw := ra if winner_id == b.a else rb
	var rl := rb if winner_id == b.a else ra
	var upset := rl >= 1 and (rw < 0 or rw - rl >= 8)
	if mine:
		w.add_news("resultado", "%s vence %s por %s na %s." % [wf.display_name(), lf.display_name(), how, ev.name], [wf.id, lf.id], true)
	elif upset and rl <= 15:
		w.add_news("resultado", "Zebra na %s: %s (%s) derruba %s (#%d) por %s." % [ev.name, wf.display_name(), "sem ranking" if rw < 0 else "#%d" % rw, lf.display_name(), rl, how], [wf.id, lf.id])
	elif ev != null and ev.tier == 2 and b.main_event:
		w.add_news("resultado", "Luta principal da %s: %s vence %s por %s." % [ev.name, wf.display_name(), lf.display_name(), how], [wf.id, lf.id])


static func cancel_bout(w: GameWorld, b: Bout, reason: String) -> void:
	b.status = "cancelada"
	var ev := w.event(b.event_id)
	if ev != null:
		ev.bouts.erase(b.id)
	for fid: int in [b.a, b.b]:
		var f := w.fighter(fid)
		if f != null and f.bout_id == b.id:
			f.bout_id = -1
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	if w.is_user_fighter(fa) or w.is_user_fighter(fb) or b.title:
		w.add_news("equipe", "Luta cancelada: %s × %s. %s." % [fa.display_name(), fb.display_name(), reason], [fa.id, fb.id], true)


# --- Semana -------------------------------------------------------------------------------

## Fecha a semana. As lutas do jogador desta semana já têm de estar feitas (ou são simuladas
## aqui, se `auto` = true).
static func advance_week(w: GameWorld, auto: bool = false) -> void:
	for ev: FightEvent in Calendar.events_in_week(w, w.week):
		var org_night := w.is_president() and ev.tier == 2
		for bid: int in ev.bouts.duplicate():
			var b := w.bout(bid)
			if b == null or b.status != "marcada":
				continue
			var mine := org_night or w.is_user_fighter(w.fighter(b.a)) or w.is_user_fighter(w.fighter(b.b))
			if mine and not auto:
				continue
			simulate(w, b)
		ev.done = true
		# Presidente que deixou a semana andar sem fechar a noite: os bônus saem pela sugestão.
		if org_night and not ev.closed:
			Org.close_event(w, ev, Org.auto_bonuses(w, ev))
	_finances(w)
	Development.week(w)
	_contracts(w)
	w.week += 1
	w.played_this_week = []
	if w.week % 4 == 0:
		Development.month(w)
		StaffMarket.refresh(w)
		Signing.cpu_signings(w)
	_vacate_idle_champions(w)
	Rankings.rebuild(w)
	Calendar.ensure_events(w)
	Matchmaker.book_cpu(w)
	if w.is_president():
		Org.delegate_fill(w)
	else:
		Matchmaker.user_offers(w)
	_trim(w)


static func _finances(w: GameWorld) -> void:
	if w.is_president():
		Org.weekly(w)
		return
	var t := w.user_team()
	if t == null:
		return
	var n := w.user_fighters().size()
	t.add_money(w.week, "Aluguel e despesas da academia", -(RENT + PER_FIGHTER * n))
	var wages := t.weekly_wages()
	if wages > 0.0:
		t.add_money(w.week, "Salários do staff", -wages)


## Fim de contrato: os da CPU renovam quase sempre; os do jogador avisam (renovação no perfil).
static func _contracts(w: GameWorld) -> void:
	for f: Fighter in w.fighters.values():
		if f.retired or f.team_id < 0 or not f.contract.has("fights") or int(f.contract["fights"]) > 0:
			continue
		if w.is_user_fighter(f):
			if not f.contract.has("warned"):
				f.contract["warned"] = true
				w.add_news("equipe", "O contrato de %s acabou. Renove no perfil dele antes que outra academia leve." % f.display_name(), [f.id], true)
			elif w.rng.randf() < 0.12 and f.bout_id < 0:
				Signing.release(w, f, false)
				w.add_news("equipe", "Sem renovação, %s deixou a equipe." % f.display_name(), [f.id], true)
		elif w.rng.randf() < 0.75:
			f.contract["fights"] = w.rng.randi_range(3, 6)
		elif f.bout_id < 0:
			f.team_id = -1
			f.contract = {}


static func _vacate_idle_champions(w: GameWorld) -> void:
	for div: String in w.champions:
		var c := w.fighter(int(w.champions[div]))
		if c != null and (c.retired or w.week - c.last_fight_week > 60) and c.bout_id < 0:
			w.champions[div] = -1
			w.add_news("cinturao", "%s fica longe do octógono e perde o cinturão dos %s." % [c.display_name(), Matchmaker.division_name(div, true)], [c.id], true)


## Tira do save o que não serve mais: eventos e lutas antigas sem a equipe do jogador.
static func _trim(w: GameWorld) -> void:
	if w.week % 8 != 0:
		return
	for e: FightEvent in w.events.values():
		if e.week < w.week - 30:
			var keep := w.is_president() and e.tier == 2 and e.week >= w.week - 104
			for bid: int in e.bouts:
				var b := w.bout(bid)
				if b != null and (w.is_user_fighter(w.fighter(b.a)) or w.is_user_fighter(w.fighter(b.b)) or b.title):
					keep = true
			if not keep:
				for bid: int in e.bouts:
					w.bouts.erase(bid)
				w.events.erase(e.id)
	for b: Bout in w.bouts.values():
		if b.status == "cancelada" and b.week < w.week - 4:
			w.bouts.erase(b.id)
