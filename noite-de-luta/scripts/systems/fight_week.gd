class_name FightWeek
extends RefCounted
## Vida de presidente: a semana da luta e a coletiva depois da noite.
##
## Semana da luta (imprevistos que viram decisão do presidente, guardados em `w.incidents`):
## - lesão nas semanas antes da noite: escolher um substituto (ele recebe um prêmio por aceitar em
##   cima da hora, e o adversário pode recusar), ou tirar a luta do card pagando ou não a bolsa de
##   quem ficou sem luta;
## - lutador que não bate o peso na pesagem (semana da noite): peso combinado com 20% da bolsa dele
##   indo para o adversário (que pode recusar), peso combinado com um extra pago pela organização,
##   ou cancelar. Campeão que não bate o peso perde o cinturão na balança (só o outro pode ganhá-lo);
##   desafiante que não bate o peso tira o cinturão da luta.
## O que o presidente não decidir antes da noite sai pelo padrão (`resolve_default`).
##
## Coletiva pós-luta (`presser_options`, `presser_pick`): até duas falas, cada uma com custo e manchete.

## Chance de lesão por lutador por semana nas três semanas antes da noite (além das de treino).
const INJURY_P := 0.008
const INJURIES := [["Lesão no joelho", 6, 14], ["Costela trincada", 4, 8], ["Mão quebrada", 6, 12],
	["Lesão no ombro", 5, 12], ["Corte no treino", 2, 4], ["Hérnia de disco", 8, 16], ["Gripe forte", 1, 2]]
## Prêmio por aceitar uma luta em cima da hora (fração da bolsa de entrada do substituto).
const SHORT_NOTICE := 0.3
## Quanto da bolsa de entrada vai para o adversário de quem não bate o peso.
const WEIGHT_FINE := 0.2
## Coletiva: quantas falas por noite.
const PRESSER_PICKS := 2


# --- Incidentes ----------------------------------------------------------------------------

static func pending(w: GameWorld, ev: FightEvent = null) -> Array:
	return w.incidents.filter(func(i: Dictionary) -> bool:
		return not bool(i.get("done", false)) and (ev == null or int(i["event"]) == ev.id))


static func has_incident(w: GameWorld, bout_id: int) -> bool:
	for i: Dictionary in w.incidents:
		if int(i["bout"]) == bout_id and not bool(i.get("done", false)):
			return true
	return false


## Começo de cada semana do presidente: lesões nas noites que estão chegando e a pesagem da noite
## desta semana.
static func roll(w: GameWorld) -> void:
	if not w.is_president():
		return
	_trim(w)
	for ev: FightEvent in Org.upcoming_events(w):
		var gap := ev.week - w.week
		if gap > 2:
			continue
		for b: Bout in Org.event_bouts(w, ev):
			if b.status != "marcada" or has_incident(w, b.id):
				continue
			for fid: int in [b.a, b.b]:
				if w.rng.randf() < INJURY_P:
					var inj: Array = INJURIES[w.rng.randi_range(0, INJURIES.size() - 1)]
					var f := w.fighter(fid)
					f.injury = {"name": inj[0], "weeks": w.rng.randi_range(int(inj[1]), int(inj[2]))}
					f.condition = minf(f.condition, 70.0)
					injury(w, b, f, String(inj[0]), "no camp")
					break
			if gap == 0 and not has_incident(w, b.id):
				_weigh(w, ev, b)
			if gap == 1 and b.main_event and b.status == "marcada":
				_presser_brawl(w, ev, b)


## Coletiva da semana da luta principal: com um falastrão ou encrenqueiro na mesa, pode sair
## provocação ou empurra-empurra. Vende a noite (hype) e dá fama; às vezes a comissão multa.
static func _presser_brawl(w: GameWorld, ev: FightEvent, b: Bout) -> void:
	if bool(ev.report.get("brawl_rolled", false)):
		return
	ev.report["brawl_rolled"] = true
	var fa := w.fighter(b.a)
	var fb := w.fighter(b.b)
	var hot := int(Persona.hothead(fa)) + int(Persona.hothead(fb))
	if hot == 0 or w.rng.randf() >= 0.3 + 0.25 * (hot - 1):
		return
	var loud := fa if Persona.hothead(fa) else fb
	var other := fb if loud == fa else fa
	var brawl := Persona.has(loud, "encrenqueiro") or hot == 2
	ev.hype += 8.0 if brawl else 4.0
	loud.popularity = minf(100.0, loud.popularity + 3.0)
	other.popularity = minf(100.0, other.popularity + 1.5)
	var txt := ""
	if brawl:
		txt = "Confusão na coletiva da %s: %s parte para cima de %s e os seguranças separam. A luta vira assunto e os ingressos voam." % [ev.name, loud.display_name(), other.display_name()]
		if w.rng.randf() < 0.4:
			txt += " A comissão multa %s." % loud.short_name()
	else:
		txt = "%s provoca %s na coletiva da %s e promete nocaute. A noite ganha interesse." % [loud.display_name(), other.display_name(), ev.name]
	w.add_news("organizacao" if w.is_president() else "resultado", txt, [loud.id, other.id], brawl)


## Lesão de um lutador com luta marcada numa noite da organização: vira decisão do presidente.
static func injury(w: GameWorld, b: Bout, f: Fighter, name: String, where: String) -> void:
	var ev := w.event(b.event_id)
	var other := w.fighter(b.other(f.id))
	var i := {"id": w.new_id(), "kind": "lesao", "event": b.event_id, "bout": b.id, "fighter": f.id, "opp": other.id,
		"week": w.week, "injury": name, "where": where, "refused": []}
	w.incidents.append(i)
	w.add_news("organizacao", "%s se machucou %s (%s) e está fora da luta contra %s na %s. A organização precisa decidir." % [f.display_name(), where, name.to_lower(), other.display_name(), ev.name], [f.id, other.id], true)


static func _weigh(w: GameWorld, ev: FightEvent, b: Bout) -> void:
	var wi := Career.weigh_in(w, b)
	var missed: Array = wi.get("missed", [])
	if missed.is_empty():
		return
	# Os dois fora do peso: a luta segue em peso combinado sem multa.
	if missed.size() == 2:
		b.title = false
		b.title_for = -1
		w.add_news("organizacao", "Pesagem da %s: %s e %s ficam fora do peso; a luta segue em peso combinado." % [ev.name, w.fighter(b.a).short_name(), w.fighter(b.b).short_name()], [b.a, b.b])
		return
	var fid := int(missed[0])
	var f := w.fighter(fid)
	var idx := 0 if fid == b.a else 1
	var limit := float(DataDB.division(b.division).get("limit_kg", 70.0)) + (0.5 if not b.title else 0.0)
	var kg := float((wi["kg"] as Array)[idx])
	var i := {"id": w.new_id(), "kind": "peso", "event": ev.id, "bout": b.id, "fighter": fid, "opp": b.other(fid),
		"week": w.week, "kg": kg, "limit": limit, "refused": []}
	w.incidents.append(i)
	var was_champ := b.title and int(w.champions.get(b.division, -1)) == fid
	var txt := "Pesagem da %s: %s bate %s kg, %s acima do limite de %s kg." % [ev.name, f.display_name(), _kg(kg), _kg(kg - limit), _kg(limit)]
	if was_champ:
		txt += " Perdeu o cinturão na balança."
		_strip(w, b, f)
	elif b.title:
		txt += " A luta não vale mais o cinturão."
		b.title = false
	w.add_news("organizacao", txt, [fid, b.other(fid)], true)


## Campeão fora do peso: o cinturão fica vago e só o adversário pode ganhá-lo nessa luta.
static func _strip(w: GameWorld, b: Bout, f: Fighter) -> void:
	w.champions[b.division] = -1
	b.title_for = b.other(f.id)


static func _o(f: Fighter) -> String:
	return "a" if f.is_female() else "o"


static func _kg(v: float) -> String:
	return ("%.1f" % v).replace(".", ",")


static func incident_title(w: GameWorld, i: Dictionary) -> String:
	var f := w.fighter(int(i["fighter"]))
	if String(i["kind"]) == "lesao":
		return "%s está machucad%s" % [f.short_name(), _o(f)]
	return "%s não bateu o peso" % f.short_name()


static func incident_text(w: GameWorld, i: Dictionary) -> String:
	var f := w.fighter(int(i["fighter"]))
	var o := w.fighter(int(i["opp"]))
	var ev := w.event(int(i["event"]))
	var when := GameWorld.fight_date_text(ev.week)
	if String(i["kind"]) == "lesao":
		return "%s se machucou %s (%s) e não luta contra %s na %s (%s)." % [f.display_name(), String(i["where"]), String(i["injury"]).to_lower(), o.display_name(), ev.name, when]
	var kg := float(i["kg"])
	var limit := float(i["limit"])
	return "%s bateu %s kg para um limite de %s kg (%s kg acima). A luta contra %s é no sábado." % [f.display_name(), _kg(kg), _kg(limit), _kg(kg - limit), o.display_name()]


# --- Lesão: substituto ou cancelamento -------------------------------------------------------

## Substitutos possíveis para enfrentar `keep` (o que ficou sem adversário): da mesma categoria,
## livres e sem lesão. Aviso curto: aceita quem não lutou nas últimas 5 semanas.
static func substitutes(w: GameWorld, i: Dictionary, limit: int = 6) -> Array:
	var b := w.bout(int(i["bout"]))
	var keep := w.fighter(int(i["opp"]))
	var refused: Array = i.get("refused", [])
	var rk := w.rank_of(keep)
	var out: Array = []
	if not keep.injury.is_empty() or keep.retired:
		return out
	for o: Fighter in Org.roster(w, b.division):
		if o.id == keep.id or o.id == int(i["fighter"]) or refused.has(o.id) or not o.available():
			continue
		if w.week - o.last_fight_week < 5 or o.condition < 80.0 or not Matchmaker.can_face(w, keep, o):
			continue
		if w.rank_of(o) == 0:
			continue
		var ro := w.rank_of(o)
		var d := absf(float(rk if rk >= 0 else 40) - float(ro if ro >= 0 else 40))
		out.append([d, o])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	return out.slice(0, limit).map(func(x: Array) -> Fighter: return x[1])


## Chance de o substituto aceitar e de o adversário aceitar o substituto: [p_sub, p_keep, motivo].
static func sub_chances(w: GameWorld, i: Dictionary, sub: Fighter) -> Array:
	var ev := w.event(int(i["event"]))
	var keep := w.fighter(int(i["opp"]))
	var notice := ev.week - w.week
	var rs := w.rank_of(sub)
	var rk := w.rank_of(keep)
	var ns := 60 if rs < 0 else rs
	var nk := 60 if rk < 0 else rk
	# O substituto: oportunidade de subir no ranking é ótima, aviso de dias é o que pesa.
	var ps := 0.72 + (0.12 if ns > nk else -0.1) - (0.2 if notice == 0 else (0.08 if notice == 1 else 0.0)) + Persona.accept_mod(sub, nk - ns, 1.3, true)
	# Quem ficou: não quer arriscar a posição contra alguém muito abaixo.
	var pk := 0.92 - maxf(0.0, ns - nk - 6) * 0.035 + Persona.accept_mod(keep, ns - nk, 1.0, true)
	var why := "%s não aceita: diz que não ganha nada enfrentando alguém tão abaixo no ranking." % keep.short_name()
	if ps < pk:
		why = "%s recusa: não dá para cortar o peso e se preparar com tão pouco tempo." % sub.short_name()
	return [clampf(ps, 0.1, 0.95), clampf(pk, 0.15, 0.97), why]


static func sub_bonus(w: GameWorld, b: Bout, sub: Fighter) -> float:
	return snappedf(float(Org.table_purse(w, sub, false)["show"]) * SHORT_NOTICE, 500.0)


## Oferece a luta ao substituto. {ok, text}
static func offer_sub(w: GameWorld, i: Dictionary, sub: Fighter) -> Dictionary:
	var b := w.bout(int(i["bout"]))
	var ev := w.event(int(i["event"]))
	var hurt := w.fighter(int(i["fighter"]))
	var keep := w.fighter(int(i["opp"]))
	var ch := sub_chances(w, i, sub)
	var r1 := w.rng.randf()
	var r2 := w.rng.randf()
	if r1 >= float(ch[0]) or r2 >= float(ch[1]):
		(i["refused"] as Array).append(sub.id)
		var why := String(ch[2])
		if r1 >= float(ch[0]):
			why = "%s recusa: não dá para cortar o peso e se preparar com tão pouco tempo." % sub.short_name()
		elif r2 >= float(ch[1]):
			why = "%s não aceita: diz que não ganha nada enfrentando %s." % [keep.short_name(), sub.short_name()]
		return {"ok": false, "text": why}
	# Troca o lutador machucado pelo substituto, com a bolsa da tabela e o prêmio por aceitar.
	var bonus := sub_bonus(w, b, sub)
	var p := Org.table_purse(w, sub, false)
	var purse := {"show": snappedf(float(p["show"]) + bonus, 500.0), "win": snappedf(float(p["win"]), 500.0)}
	var champ := int(w.champions.get(b.division, -1))
	if hurt.id == b.a:
		b.a = sub.id
		b.purse_a = purse
	else:
		b.b = sub.id
		b.purse_b = purse
	hurt.bout_id = -1
	sub.bout_id = b.id
	b.weigh = {}
	# Cinturão: campeão fora tira o cinturão da luta; substituto fora do top 15 também.
	if b.title and (hurt.id == champ or w.rank_of(sub) < 1 or w.rank_of(sub) > 15):
		b.title = false
		b.title_for = -1
	# Corner vermelho para o mais bem ranqueado.
	var ra := w.rank_of(w.fighter(b.a))
	var rb := w.rank_of(w.fighter(b.b))
	if ra < 0 or (rb >= 0 and rb < ra):
		var t := b.a
		b.a = b.b
		b.b = t
		var tp := b.purse_a
		b.purse_a = b.purse_b
		b.purse_b = tp
	i["done"] = true
	i["outcome"] = "sub"
	i["sub"] = sub.id
	sub.popularity = minf(100.0, sub.popularity + 2.0)
	w.add_news("organizacao", "%s aceita em cima da hora e substitui %s contra %s na %s." % [sub.display_name(), hurt.short_name(), keep.display_name(), ev.name], [sub.id, keep.id], true)
	return {"ok": true, "text": "Fechado: %s × %s. %s ganha %s por aceitar em cima da hora." % [keep.short_name(), sub.short_name(), sub.short_name(), Fmt.money(bonus)]}


## Tira a luta do card. Pagar a bolsa de entrada de quem ficou sem luta custa dinheiro mas segura
## o nome da organização com os lutadores; não pagar custa prestígio.
static func cancel_injury(w: GameWorld, i: Dictionary, pay: bool) -> Dictionary:
	var b := w.bout(int(i["bout"]))
	var ev := w.event(int(i["event"]))
	var keep := w.fighter(int(i["opp"]))
	var hurt := w.fighter(int(i["fighter"]))
	var t := w.user_team()
	var show := float(b.purse_of(keep.id)["show"])
	Career.cancel_bout(w, b, "%s se machucou" % hurt.display_name())
	hurt.bout_id = -1
	if pay and t != null:
		t.add_money(w.week, "%s: bolsa de %s (luta cancelada)" % [ev.name, keep.short_name()], -show)
	elif t != null:
		t.reputation = maxf(1.0, t.reputation - 0.5)
	Org.ensure_main(w, ev)
	i["done"] = true
	i["outcome"] = "cancelada_paga" if pay else "cancelada"
	var txt := "%s fica sem luta na %s%s." % [keep.display_name(), ev.name, "; a organização paga a bolsa mesmo assim" if pay else "; a equipe %s reclama da organização" % ("dela" if keep.is_female() else "dele")]
	w.add_news("organizacao", txt, [keep.id], true)
	return {"ok": true, "text": txt}


# --- Peso ----------------------------------------------------------------------------------

static func fine_of(w: GameWorld, i: Dictionary) -> float:
	var b := w.bout(int(i["bout"]))
	return snappedf(float(b.purse_of(int(i["fighter"]))["show"]) * WEIGHT_FINE, 100.0)


## Extra que a organização paga ao adversário para ele aceitar o peso combinado.
static func catch_extra(w: GameWorld, i: Dictionary) -> float:
	var b := w.bout(int(i["bout"]))
	return maxf(25000.0, snappedf(float(b.purse_of(int(i["opp"]))["show"]) * 0.25, 500.0))


static func catch_chance(w: GameWorld, i: Dictionary, extra: bool) -> float:
	var b := w.bout(int(i["bout"]))
	var miss := float(i["kg"]) - float(i["limit"])
	var p := 0.86 - miss * 0.12 - (0.15 if b.main_event else 0.0)
	if extra:
		p += 0.25
	return clampf(p, 0.2, 0.97)


## Peso combinado: a multa sai da bolsa de quem errou o peso (já cobrada no pagamento da luta).
static func catchweight(w: GameWorld, i: Dictionary, extra: bool) -> Dictionary:
	var b := w.bout(int(i["bout"]))
	var ev := w.event(int(i["event"]))
	var f := w.fighter(int(i["fighter"]))
	var o := w.fighter(int(i["opp"]))
	if bool(i.get("asked", false)) and not extra:
		return {"ok": false, "text": "%s já recusou. Só com um extra da organização." % o.short_name()}
	if w.rng.randf() >= catch_chance(w, i, extra):
		i["asked"] = true
		if extra:
			i["refused"] = [o.id]
		return {"ok": false, "text": "%s recusa lutar com alguém acima do peso%s." % [o.short_name(), ", nem com o extra" if extra else ""]}
	if extra:
		var x := catch_extra(w, i)
		var p := b.purse_of(o.id)
		p["show"] = float(p["show"]) + x
	i["done"] = true
	i["outcome"] = "combinado"
	var txt := "%s aceita o peso combinado contra %s na %s; %s da bolsa de %s vai para %s." % [o.display_name(), f.display_name(), ev.name, Fmt.money(fine_of(w, i)), f.short_name(), "ela" if o.is_female() else "ele"]
	if extra:
		txt += " A organização ainda paga um extra de %s." % Fmt.money(catch_extra(w, i))
	w.add_news("organizacao", txt, [o.id, f.id])
	return {"ok": true, "text": txt}


static func cancel_weight(w: GameWorld, i: Dictionary) -> Dictionary:
	var b := w.bout(int(i["bout"]))
	var ev := w.event(int(i["event"]))
	var f := w.fighter(int(i["fighter"]))
	var o := w.fighter(int(i["opp"]))
	var t := w.user_team()
	# Quem bateu o peso recebe a bolsa de entrada (a organização paga e cobra da equipe de quem errou).
	var show := float(b.purse_of(o.id)["show"])
	Career.cancel_bout(w, b, "%s não bateu o peso" % f.display_name())
	if t != null:
		t.add_money(w.week, "%s: bolsa de %s (luta cancelada na balança)" % [ev.name, o.short_name()], -show * 0.5)
	f.popularity = maxf(1.0, f.popularity - 3.0)
	Org.ensure_main(w, ev)
	i["done"] = true
	i["outcome"] = "cancelada"
	var txt := "Luta cancelada na balança: %s × %s fora da %s. %s recebe a bolsa de entrada." % [f.short_name(), o.short_name(), ev.name, o.short_name()]
	w.add_news("organizacao", txt, [f.id, o.id], true)
	return {"ok": true, "text": txt}


## O que acontece quando o presidente não decide: lesão tira a luta do card (sem pagar), peso
## combinado se o adversário topar, senão cancela.
static func resolve_default(w: GameWorld, ev: FightEvent = null) -> void:
	for i: Dictionary in pending(w, ev):
		if String(i["kind"]) == "lesao":
			cancel_injury(w, i, false)
		else:
			var r := catchweight(w, i, false)
			if not bool(r["ok"]):
				cancel_weight(w, i)


static func _trim(w: GameWorld) -> void:
	w.incidents = w.incidents.filter(func(i: Dictionary) -> bool:
		return not bool(i.get("done", false)) or w.week - int(i["week"]) < 12)


# --- Coletiva pós-luta -----------------------------------------------------------------------

## Falas possíveis na coletiva depois da noite: [{key, title, text, cost, ...}].
static func presser_options(w: GameWorld, ev: FightEvent) -> Array:
	var out: Array = []
	var r := ev.report
	var done := Org.event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "feita")
	if done.is_empty():
		return out
	var awarded: Array = (r.get("potn", []) as Array).map(func(v): return int(v))
	var fb := w.bout(int(r.get("fotn", -1)))
	if fb != null:
		awarded.append_array([fb.a, fb.b])
	# Bônus extra do bolso do presidente para quem venceu bonito e ficou sem bônus.
	var best: Fighter = null
	var best_s := -1.0
	for b: Bout in done:
		var wid := int(b.result.get("winner_id", -1))
		if wid < 0 or awarded.has(wid):
			continue
		var m := String(b.result.get("method", ""))
		var s := (100.0 if m in ["KO", "TKO", "FIN"] else 30.0) + w.fighter(wid).popularity * 0.3 + (60.0 if b.main_event else 0.0)
		if s > best_s:
			best_s = s
			best = w.fighter(wid)
	if best != null:
		out.append({"key": "extra", "fighter": best.id, "cost": Org.BONUS, "title": "Bônus extra para %s" % best.short_name(),
			"text": "Anunciar mais US$ %d mil, do bolso da organização, para %s pela vitória de hoje." % [int(Org.BONUS / 1000.0), best.display_name()]})
	# Decisão dividida: criticar os juízes, ou pagar o bônus de vitória a quem perdeu.
	for b: Bout in done:
		if String(b.result.get("method", "")) != "DEC" or not _split(b):
			continue
		var wid := int(b.result.get("winner_id", -1))
		if wid < 0:
			continue
		var lid := b.other(wid)
		var lf := w.fighter(lid)
		out.append({"key": "juizes", "bout": b.id, "cost": 0.0, "title": "Criticar os juízes",
			"text": "Dizer que %s ganhou a luta contra %s e que a comissão precisa de juízes melhores." % [lf.short_name(), w.fighter(wid).short_name()]})
		out.append({"key": "paga_derrota", "bout": b.id, "fighter": lid, "cost": float(b.purse_of(lid)["win"]), "title": "Pagar a vitória a %s" % lf.short_name(),
			"text": "Pagar o bônus de vitória a %s mesmo com a derrota na decisão dividida." % lf.display_name()})
		break
	# Próxima luta do cinturão: o campeão da principal contra o melhor desafiante livre.
	var main: Bout = done.back()
	var wid2 := int(main.result.get("winner_id", -1))
	if main.title and wid2 >= 0 and int(w.champions.get(main.division, -1)) == wid2:
		var champ := w.fighter(wid2)
		var nxt := _next_ppv(w, ev)
		var opp := _contender(w, champ, nxt)
		if nxt != null and opp != null and Org.book_reason(w, nxt, champ, opp) == "" and Org.title_reason(w, champ, opp) == "":
			out.append({"key": "anuncia", "fighter": champ.id, "opp": opp.id, "event": nxt.id, "cost": 0.0, "title": "Anunciar %s × %s" % [champ.short_name(), opp.short_name()],
				"text": "Anunciar na coletiva a próxima defesa de %s contra %s, na %s. Se as equipes não toparem, fica feio." % [champ.short_name(), opp.display_name(), nxt.name]})
	# Veterano em fase ruim: mandar pendurar as luvas.
	var y := w.year()
	var mo := w.month()
	for b: Bout in done:
		var wid := int(b.result.get("winner_id", -1))
		if wid < 0:
			continue
		var lf := w.fighter(b.other(wid))
		if lf.age(y, mo) >= 34 and lf.streak <= -2 and not lf.retired:
			out.append({"key": "aposenta", "fighter": lf.id, "cost": 0.0, "title": "Mandar %s se aposentar" % lf.short_name(),
				"text": "Dizer que %s (%d anos, %d derrotas seguidas) já deu o que tinha que dar." % [lf.display_name(), lf.age(y, mo), -lf.streak]})
			break
	# Casa cheia.
	if int(r.get("capacity", 0)) > 0 and float(r.get("crowd", 0)) >= float(r.get("capacity", 1)) * 0.95:
		out.append({"key": "casa_cheia", "cost": 0.0, "title": "Exaltar a casa cheia",
			"text": "Falar dos %s lugares vendidos em %s e prometer voltar maior." % [Fmt.thousands(int(r["crowd"])), ev.city]})
	else:
		out.append({"key": "elogio", "cost": 0.0, "title": "Elogiar o card",
			"text": "Dizer que foi uma das melhores noites do ano e agradecer aos lutadores."})
	return out


static func _split(b: Bout) -> bool:
	var cards: Array = b.result.get("cards", [])
	var a_wins := 0
	var b_wins := 0
	for c in cards:
		var arr: Array = c
		if arr.size() < 2:
			continue
		if float(arr[0]) > float(arr[1]):
			a_wins += 1
		elif float(arr[1]) > float(arr[0]):
			b_wins += 1
	return a_wins > 0 and b_wins > 0


static func _next_ppv(w: GameWorld, ev: FightEvent) -> FightEvent:
	for e: FightEvent in Org.upcoming_events(w):
		if e.ppv and e.week - w.week >= 6 and e.id != ev.id and Org.event_bouts(w, e).size() < e.slots:
			return e
	return null


static func _contender(w: GameWorld, champ: Fighter, ev: FightEvent) -> Fighter:
	if ev == null or Org.title_booked(w, champ.division) != null:
		return null
	for o: Fighter in Org.roster(w, champ.division):
		if o.id == champ.id or w.rank_of(o) < 1 or w.rank_of(o) > 5:
			continue
		if o.bout_id < 0 and o.injury.is_empty() and Matchmaker.can_face(w, champ, o) and Matchmaker.ready_to_book(w, o, ev.week - w.week):
			return o
	return null


static func presser_done(ev: FightEvent) -> bool:
	return bool(ev.report.get("presser_closed", false)) or (ev.report.get("presser", []) as Array).size() >= PRESSER_PICKS


## Fala escolhida na coletiva: aplica o efeito, escreve a manchete e guarda no relatório da noite.
static func presser_pick(w: GameWorld, ev: FightEvent, o: Dictionary) -> String:
	var t := w.user_team()
	var key := String(o["key"])
	var out := ""
	match key:
		"extra":
			var f := w.fighter(int(o["fighter"]))
			if t != null:
				t.add_money(w.week, "%s: bônus extra para %s" % [ev.name, f.short_name()], -float(o["cost"]))
				t.reputation = minf(100.0, t.reputation + 0.2)
			f.popularity = minf(100.0, f.popularity + 2.0)
			out = "Aplausos na sala: %s ganha mais %s e agradece a organização." % [f.short_name(), Fmt.money(float(o["cost"]))]
		"juizes":
			var b := w.bout(int(o["bout"]))
			if t != null:
				t.reputation = minf(100.0, t.reputation + 0.3)
			out = "Os fãs adoram. A crítica aos juízes de %s × %s vira manchete." % [w.fighter(b.a).short_name(), w.fighter(b.b).short_name()]
			if w.rng.randf() < 0.4 and t != null:
				t.add_money(w.week, "Multa da comissão atlética", -25000.0)
				out += " A comissão não gosta e multa a organização em US$ 25 mil."
		"paga_derrota":
			var f2 := w.fighter(int(o["fighter"]))
			if t != null:
				t.add_money(w.week, "%s: bônus de vitória para %s" % [ev.name, f2.short_name()], -float(o["cost"]))
				t.reputation = minf(100.0, t.reputation + 0.25)
			f2.popularity = minf(100.0, f2.popularity + 2.0)
			out = "%s recebe o bônus de vitória mesmo com a derrota. Os lutadores elogiam o gesto." % f2.short_name()
		"anuncia":
			var champ := w.fighter(int(o["fighter"]))
			var opp := w.fighter(int(o["opp"]))
			var nxt := w.event(int(o["event"]))
			var r := Org.offer_bout(w, nxt, champ, opp, true, true, 1.25)
			if bool(r["ok"]):
				if t != null:
					t.reputation = minf(100.0, t.reputation + 0.4)
				opp.popularity = minf(100.0, opp.popularity + 3.0)
				out = "Anunciado na hora: %s × %s pelo cinturão na %s, com bolsa 25%% acima da tabela." % [champ.short_name(), opp.short_name(), nxt.name]
			else:
				if t != null:
					t.reputation = maxf(1.0, t.reputation - 0.4)
				out = "Saia justa: a luta é anunciada, mas as equipes desmentem no dia seguinte. %s" % String(r["text"])
		"aposenta":
			var f3 := w.fighter(int(o["fighter"]))
			var pa := 0.8 if Persona.has(f3, "humilde") else (0.15 if Persona.hothead(f3) or Persona.has(f3, "guerreiro") else 0.45)
			if w.rng.randf() < pa:
				Development.retire(w, f3)
				out = "%s concorda: anuncia a aposentadoria no dia seguinte e é aplaudid%s." % [f3.short_name(), _o(f3)]
			else:
				f3.popularity = minf(100.0, f3.popularity + 3.0)
				if t != null:
					t.reputation = maxf(1.0, t.reputation - 0.2)
				out = "%s se ofende: \"Ninguém me aposenta.\" Promete provar que ainda tem lenha e a briga vira manchete." % f3.short_name()
		"casa_cheia":
			if t != null:
				t.reputation = minf(100.0, t.reputation + 0.3)
			out = "A casa cheia em %s vira manchete e os patrocinadores ligam na segunda." % ev.city
		_:
			if t != null:
				t.reputation = minf(100.0, t.reputation + 0.1)
			out = "Clima bom na sala. Os lutadores gostam do elogio."
	var lst: Array = ev.report.get("presser", [])
	lst.append({"key": key, "title": String(o["title"]), "result": out})
	ev.report["presser"] = lst
	w.add_news("organizacao", "Coletiva da %s: %s" % [ev.name, out], [int(o.get("fighter", -1))] if o.has("fighter") else [])
	return out
