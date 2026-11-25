class_name Matchmaker
extends RefCounted
## Quem luta com quem. As equipes rivais casam lutas entre si toda semana (perto no ranking, na
## mesma camada, sem revanche imediata); os lutadores do jogador recebem propostas de
## adversários perto deles no ranking e podem desafiar, como no LEATHER: perder atrasa os
## desafios para cima, e o campeão só defende o cinturão contra os primeiros da fila.

## Semanas mínimas de descanso entre lutas. Depois de uma disputa de cinturão (cinco rounds e
## um camp inteiro) o descanso é bem maior: campeão defende duas vezes por ano, não seis. É o
## que faz disputa de cinturão ser rara: não cabe uma em cada noite.
const REST := 7
const REST_TITLE := 24
## Janela de ranking para casar uma luta, por camada.
const WINDOW := [26, 12, 5]


static func rest_weeks(f: Fighter) -> int:
	if f.history.is_empty():
		return REST
	var last: Dictionary = f.history.back()
	var base := REST_TITLE if bool(last.get("title", false)) or bool(last.get("interim", false)) else REST
	if String(last.get("res", "")) == "D" and String(last.get("method", "")) in ["KO", "TKO"]:
		return base + 4
	return base


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
	# A ordem do card sai pelo peso de cada luta. Nas noites do presidente quem escolhe a
	# principal é ele (Org.book); nas outras a mais pesada sobe sozinha.
	Card.refresh(w, ev)
	return x


static func _last_opp(f: Fighter) -> int:
	if f.history.is_empty():
		return -1
	return int((f.history.back() as Dictionary).get("opp", -1))


## Pode lutar contra? Mesma categoria, equipes diferentes, sem revanche imediata.
static func can_face(w: GameWorld, fa: Fighter, fb: Fighter) -> bool:
	return face_reason(w, fa, fb) == ""


## Por que os dois não podem se enfrentar ("" = podem).
static func face_reason(w: GameWorld, fa: Fighter, fb: Fighter) -> String:
	if fa.id == fb.id or fa.division != fb.division:
		return "Os dois precisam ser da mesma categoria."
	if fa.team_id >= 0 and fa.team_id == fb.team_id:
		return "Os dois são da mesma academia."
	var last := _last_opp(fa) == fb.id or _last_opp(fb) == fa.id
	if not last and fa.history.size() < 4 and fb.history.size() < 4:
		return ""
	var n := Rivalry.meetings(fa, fb.id)
	if n >= 4:
		return "Já se enfrentaram %d vezes: essa luta o público não compra mais." % n
	if last and not Rivalry.rematch_ok(w, fa, fb):
		return "Revanche imediata só com motivo: luta apertada, rivalidade quente ou cinturão que trocou de mão."
	return ""


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
		# Presidente: as noites da liga são do jogador (o matchmaker dele completa à parte, Org).
		if tier == 2 and w.is_president():
			continue
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
		# Rivalidade puxa a luta: quem tem história se encontra de novo.
		d -= Rivalry.heat(w, fa, fb) * 0.06
		if d < best_d:
			best_d = d
			best = fb
	if best == null or best_d > WINDOW[tier] + 3.0:
		pool.erase(fa)
		return true
	make_bout(w, ev, fa, best, false, false)
	pool.erase(fa)
	pool.erase(best)
	return true


## Disputas de cinturão nas noites da Liga Global: campeão contra o melhor desafiante disponível
## (ou os dois primeiros pelo cinturão vago).
## Chance (em 100) de a liga guardar a disputa de cinturão para um lutador do jogador, do 1º
## ao 4º do ranking, e por quantas semanas ela espera a resposta antes de chamar outro.
const SHOT_ODDS := [85, 55, 30, 15]
const SHOT_WINDOW := 6


## A liga quer este lutador do jogador contra o campeão? Decide uma vez por luta do campeão
## (sempre igual até ele lutar de novo), para o empresário poder esperar pela proposta.
static func shot_promised(w: GameWorld, f: Fighter) -> bool:
	if f == null or not w.is_user_fighter(f) or w.is_president():
		return false
	var champ := w.fighter(int(w.champions.get(f.division, -1)))
	if champ == null or w.is_user_fighter(champ) or Titles.interim_of(w, f.division) != null:
		return false
	var r := w.rank_of(f)
	if r < 1 or r > SHOT_ODDS.size():
		return false
	if w.week - champ.last_fight_week > maxi(12, rest_weeks(champ) - 4) + SHOT_WINDOW:
		return false
	if _last_opp(champ) == f.id and not Rivalry.rematch_ok(w, champ, f):
		return false
	return absi(hash([champ.id, champ.last_fight_week, f.id])) % 100 < int(SHOT_ODDS[r - 1])


## Lutador do jogador para quem a liga está segurando a disputa (pronto para lutar), ou null.
static func user_shot(w: GameWorld, champ: Fighter) -> Fighter:
	if champ == null:
		return null
	var lst: Array = w.rankings.get(champ.division, [])
	for i in mini(SHOT_ODDS.size(), lst.size()):
		var c := w.fighter(int(lst[i]))
		if c != null and shot_promised(w, c) and ready_to_book(w, c, 4):
			return c
	return null


static func _title_fights(w: GameWorld) -> void:
	if w.is_president():
		return # quem decide as disputas de cinturão é o presidente
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		if _title_booked(w, div):
			continue
		var champ := w.fighter(int(w.champions.get(div, -1)))
		# Com interino na categoria, a próxima luta do campeão é a unificação (ver Titles.week).
		if champ != null and Titles.interim_of(w, div) != null:
			continue
		var lst: Array = w.rankings.get(div, [])
		var contenders: Array = []
		for i in mini(4, lst.size()):
			var c := w.fighter(int(lst[i]))
			if c != null and ready_to_book(w, c, 4) and not w.is_user_fighter(c):
				contenders.append(c)
		# Ex-campeão com direito a revanche passa na frente da fila.
		if champ != null:
			var ex := w.fighter(_last_opp(champ))
			if ex != null and not ex.retired and not w.is_user_fighter(ex) and ex.division == div and ready_to_book(w, ex, 4) and Rivalry.rematch_ok(w, champ, ex) and absi(hash([champ.id, ex.id, "revanche"])) % 100 < 45:
				contenders.erase(ex)
				contenders.push_front(ex)
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
		# A vez é de um lutador do jogador: a liga espera a proposta ser respondida.
		if user_shot(w, champ) != null:
			continue
		for c: Fighter in contenders:
			if can_face(w, champ, c):
				make_bout(w, evs[0], champ, c, true, true)
				w.add_news("cinturao", "%s defende o cinturão dos %s contra %s na %s." % [champ.display_name(), division_name(div, true), c.display_name(), (evs[0] as FightEvent).name], [champ.id, c.id])
				break


static func _title_booked(w: GameWorld, div: String) -> bool:
	return Titles.booked(w, div) != null


## Já tem uma luta que não sai do topo do card (cinturão ou interino)?
static func _has_main(w: GameWorld, e: FightEvent) -> bool:
	return Card.has_belt(w, e)


## "peso-leve masculino" / "peso-palha feminino" (`plural`: "pesos-leves").
static func division_name(div: String, plural: bool = false) -> String:
	var d := DataDB.division(div)
	var fem := String(d.get("sex", "m")) == "f"
	if not I18n.is_pt():
		# Fora do português o nome vem do catálogo, já com a maiúscula do idioma.
		var nm := I18n.t(String(d.get("name", div)))
		return I18n.t("peso-%s feminino" if fem else "peso-%s") % nm
	var n := String(d.get("name", div)).to_lower()
	if plural:
		return "pesos-%s%s" % [_plural(n), " femininos" if fem else ""]
	return "peso-%s%s" % [n, " feminino" if fem else ""]


static func _plural(n: String) -> String:
	if n.ends_with("o") or n.ends_with("a") or n.ends_with("e"):
		return n + "s"
	if n == "leve":
		return "leves"
	return n


## "Peso-meio-médio" (título de tela).
static func division_title(div: String) -> String:
	var n := division_name(div)
	return n.substr(0, 1).to_upper() + n.substr(1)


## Nome curto para listas: "Leve", "Palha (F)".
static func division_short(div: String) -> String:
	var d := DataDB.division(div)
	return String(d.get("name", div)) + (" (F)" if String(d.get("sex", "m")) == "f" else "")


# --- Propostas e desafios do jogador --------------------------------------------------------

## Propostas da semana para os lutadores do jogador (adversários perto no ranking). Campeão da
## equipe recebe defesa de cinturão; quem está no alto da fila recebe disputa de cinturão, de
## interino ou a unificação quando é a vez dele.
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
		var belt := mine.filter(func(o: Dictionary) -> bool: return bool(o.get("title", false)) or bool(o.get("interim", false)))
		if belt.is_empty():
			var bo := _belt_offer(w, f)
			if not bo.is_empty():
				w.offers.append(bo)
				continue
		# Campeão só luta valendo o cinturão.
		if w.rank_of(f) == 0:
			continue
		if w.rng.randf() > 0.38 + team.reputation / 350.0:
			continue
		var o := _make_offer(w, f)
		if not o.is_empty():
			w.offers.append(o)


## Proposta que vale cinturão para o lutador do jogador, quando é a vez dele: defesa (ele é o
## campeão), unificação, disputa do cinturão vago ou do interino, ou a chance contra o campeão.
static func _belt_offer(w: GameWorld, f: Fighter) -> Dictionary:
	var div := f.division
	if not f.is_pro() or Titles.booked(w, div) != null:
		return {}
	var champ := w.fighter(int(w.champions.get(div, -1)))
	var it := Titles.interim_of(w, div)
	var r := w.rank_of(f)
	var opp: Fighter = null
	var title := false
	var interim := false
	var chance := 0.0
	if r == 0:
		# Defesa: contra o interino (unificação) ou o melhor da fila, de tempos em tempos.
		if w.week - f.last_fight_week < 10:
			return {}
		title = true
		chance = 0.45
		if it != null and it.id != f.id:
			opp = it
			chance = 0.7
		else:
			opp = _contender_for(w, f, 5)
	elif champ == null:
		# Cinturão vago: os dois primeiros disputam.
		if r >= 1 and r <= 3:
			title = true
			chance = 0.5
			opp = _contender_for(w, f, 4)
	elif it != null and it.id == f.id:
		# Interino da equipe: a unificação quando o campeão puder lutar.
		if not w.is_user_fighter(champ) and ready_to_book(w, champ, 4):
			title = true
			opp = champ
			chance = 0.7
	elif it == null and Titles.champion_out(w, div) != "":
		if r >= 1 and r <= 5:
			interim = true
			chance = 0.85 if Titles.waiting_user(w, div) and r <= 4 else 0.2
			opp = _contender_for(w, f, 6)
	elif r >= 1 and r <= 4 and it == null:
		# A chance contra o campeão.
		if not w.is_user_fighter(champ) and ready_to_book(w, champ, 4) and w.week - champ.last_fight_week >= 12 and can_face(w, f, champ):
			title = true
			opp = champ
			chance = 0.8 if shot_promised(w, f) else [0.0, 0.1, 0.08, 0.05, 0.03][r]
	if opp == null or w.rng.randf() >= chance:
		return {}
	var evs := Calendar.open_events(w, 2, w.week + 5, w.week + 10).filter(func(e: FightEvent) -> bool: return not Card.has_belt(w, e))
	if evs.is_empty():
		return {}
	var ev: FightEvent = evs[0]
	var p := purse(w, f, 2, title)
	var k := Titles.PURSE_K if interim else 1.0
	return {"id": w.new_id(), "fighter": f.id, "opp": opp.id, "event": ev.id, "week": ev.week,
		"rounds": 5, "show": snappedf(float(p["show"]) * k, 500.0), "win": snappedf(float(p["win"]) * k, 500.0), "expires": w.week + 3, "kind": "proposta",
		"title": title, "interim": interim}


## Melhor adversário disponível entre os `top` primeiros do ranking (fora a equipe do jogador).
static func _contender_for(w: GameWorld, f: Fighter, top: int) -> Fighter:
	var lst: Array = w.rankings.get(f.division, [])
	for i in mini(top, lst.size()):
		var c := w.fighter(int(lst[i]))
		if c != null and c.id != f.id and not w.is_user_fighter(c) and ready_to_book(w, c, 4) and can_face(w, f, c):
			return c
	return null


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
			if w.is_user_fighter(o) or (not o.is_pro() and f.is_pro()):
				continue
			if w.rank_of(o) == 0:
				continue # o campeão só luta valendo o cinturão (ver _belt_offer)
			if not ready_to_book(w, o, 2) or not can_face(w, f, o):
				continue
			var ro := w.rank_of(o)
			var gap := absf(float(r if r >= 0 else 999) - float(ro if ro >= 0 else 999))
			if not f.is_pro():
				# Estreia: contra outro amador ou um profissional de poucas lutas.
				gap = o.fights() * 2.5 + absf(o.level() - f.level()) * 0.6
			if gap <= WINDOW[tier] + 2:
				# Rival tem preferência: a organização quer vender a história.
				cands.append([gap + w.rng.randf_range(0.0, 4.0) - Rivalry.heat(w, f, o) * 0.08, o])
		if cands.is_empty():
			return {}
		cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		opp = (cands[mini(cands.size() - 1, w.rng.randi_range(0, 2))] as Array)[1]
	var p := purse(w, f, ev.tier, false)
	# Luta que o público quer ver paga mais.
	var hv := float(Hype.pair(w, f, opp, false, false, ev.nation)["value"])
	var k := 1.0 + maxf(0.0, hv - 40.0) / 150.0
	return {"id": w.new_id(), "fighter": f.id, "opp": opp.id, "event": ev.id, "week": ev.week,
		"rounds": 3, "show": snappedf(float(p["show"]) * k, 100.0), "win": snappedf(float(p["win"]) * k, 100.0), "expires": w.week + 2, "kind": "proposta"}


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
	var title := bool(offer.get("title", false))
	var interim := bool(offer.get("interim", false))
	if (title or interim) and Titles.booked(w, f.division) != null:
		return "Outra disputa de cinturão foi marcada antes. A proposta caiu."
	var b := make_bout(w, ev, f, o, title, title)
	if interim:
		Titles.mark_interim(w, b)
	b.billing = int(offer.get("billing", 0))
	b.purse_of(f.id)["show"] = float(offer["show"])
	b.purse_of(f.id)["win"] = float(offer["win"])
	Card.refresh(w, ev)
	w.offers = w.offers.filter(func(x: Dictionary) -> bool: return int(x["fighter"]) != f.id)
	var what := " valendo o cinturão" if title else (" valendo o cinturão interino" if interim else "")
	w.add_news("equipe", "%s enfrenta %s na %s (%s)%s." % [f.display_name(), o.display_name(), ev.name, GameWorld.fight_date_text(ev.week), what], [f.id, o.id], title or interim)
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
	if Rivalry.meetings(mine, target.id) >= 4:
		return "Já se enfrentaram %d vezes: essa luta o público não compra mais." % Rivalry.meetings(mine, target.id)
	if _last_opp(mine) == target.id and not Rivalry.rematch_ok(w, mine, target):
		return "Revanche imediata ninguém aceita sem motivo: só depois de luta apertada ou com rivalidade quente."
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


## Pedidos de bolsa que o empresário pode pôr no desafio: [nome, multiplicador, o que custa na chance].
const CHALLENGE_ASKS := [["Bolsa da tabela", 1.0, 0.0], ["Pedir 20% a mais", 1.2, 0.12], ["Pedir 40% a mais", 1.4, 0.28]]


## Chance de a equipe do alvo aceitar (0–1), para a interface mostrar antes. `ask` é o índice do
## pedido de bolsa (CHALLENGE_ASKS): pedir mais derruba a chance de o evento bancar a luta.
static func challenge_chance(w: GameWorld, mine: Fighter, target: Fighter, ask: int = 0) -> float:
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
	# Rival aceita mais fácil: os dois querem resolver.
	p += Rivalry.heat(w, mine, target) / 100.0 * 0.25
	p -= float((CHALLENGE_ASKS[clampi(ask, 0, CHALLENGE_ASKS.size() - 1)] as Array)[2])
	return clampf(p, 0.05, 0.95)


## O desafio valeria o cinturão interino? (campeão fora, sem interino, os dois no alto da fila)
static func challenge_interim(w: GameWorld, mine: Fighter, target: Fighter) -> bool:
	return w.rank_of(target) != 0 and Titles.interim_reason(w, mine, target) == ""


## Desafio: a equipe do alvo responde na hora. {ok, text, bout}
static func challenge(w: GameWorld, mine: Fighter, target: Fighter, ask: int = 0) -> Dictionary:
	var why := challenge_block_reason(w, mine, target)
	if why != "":
		return {"ok": false, "text": why}
	var p := challenge_chance(w, mine, target, ask)
	if w.rng.randf() >= p:
		w.challenge_block["%d:%d" % [mine.id, target.id]] = w.week + 6
		var excuses := ["A equipe de %s diz que ele não ganha nada lutando com %s.", "%s tem outros planos para este ano, responde a equipe.", "A equipe de %s pede uma bolsa que nenhum evento paga. Recusado."]
		var t: String = excuses[w.rng.randi_range(0, excuses.size() - 1)]
		if ask > 0 and w.rng.randf() < 0.6:
			t = "O evento não banca a bolsa que você pediu para %s. Recusado."
		var txt := t % [target.short_name(), mine.short_name()] if t.count("%s") == 2 else t % (mine.short_name() if t.begins_with("O evento") else target.short_name())
		return {"ok": false, "text": txt}
	var title := w.rank_of(target) == 0
	var interim := challenge_interim(w, mine, target)
	var tier := maxi(Rankings.tier_of(w, mine), Rankings.tier_of(w, target))
	if title or interim:
		tier = 2
	var evs := Calendar.open_events(w, tier, w.week + 4, w.week + 10)
	if title or interim:
		evs = evs.filter(func(e: FightEvent) -> bool: return not _has_main(w, e))
	if evs.is_empty():
		return {"ok": false, "text": "Aceitaram, mas não há data livre nos próximos eventos. Tente na semana que vem."}
	var ev: FightEvent = evs[0]
	var b := make_bout(w, ev, mine, target, title, title)
	if interim:
		Titles.mark_interim(w, b)
	var k := float((CHALLENGE_ASKS[clampi(ask, 0, CHALLENGE_ASKS.size() - 1)] as Array)[1])
	if k != 1.0:
		var pm := b.purse_of(mine.id)
		pm["show"] = snappedf(float(pm["show"]) * k, 100.0)
		pm["win"] = snappedf(float(pm["win"]) * k, 100.0)
	var what := " valendo o cinturão" if title else (" valendo o cinturão interino" if interim else "")
	w.add_news("equipe", "Desafio aceito: %s enfrenta %s na %s%s." % [mine.display_name(), target.display_name(), ev.name, what], [mine.id, target.id], title or interim)
	return {"ok": true, "text": "Desafio aceito! %s × %s na %s, %s%s." % [mine.short_name(), target.short_name(), ev.name, GameWorld.fight_date_text(ev.week), what], "bout": b.id}
