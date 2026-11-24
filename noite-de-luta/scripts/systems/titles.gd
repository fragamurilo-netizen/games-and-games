class_name Titles
extends RefCounted
## Cinturão interino e unificação. Quando o campeão fica fora de combate (lesão longa ou muito
## tempo parado), a categoria não para: os dois melhores disponíveis disputam o cinturão interino.
## Quando o campeão volta, a luta seguinte dele é a unificação contra o interino. Se o cinturão
## ficar vago (aposentadoria, tempo demais parado, perdeu na balança), o interino é promovido.
##
## No mundo que anda sozinho (papel de empresário) a liga marca essas lutas (`week`). No papel
## de presidente quem decide é o jogador: a opção "vale o cinturão interino" aparece na hora de
## oferecer a luta (`interim_reason`), e a unificação é uma disputa de cinturão normal entre o
## campeão e o interino (`Org.title_reason` deixa passar).
##
## O interino continua no ranking (é o primeiro da fila). Se perder uma luta que não vale
## cinturão, o interino fica vago.

## Lesão do campeão com pelo menos estas semanas pela frente abre o interino.
const OUT_WEEKS := 10
## Campeão sem lutar há tanto tempo, e sem luta marcada, abre o interino.
const IDLE_WEEKS := 34
## Bolsa de uma disputa de interino sobre a tabela.
const PURSE_K := 1.3


static func interim_of(w: GameWorld, div: String) -> Fighter:
	var f := w.fighter(int(w.interim.get(div, -1)))
	return f if f != null and not f.retired and f.division == div else null


## Por que o campeão está fora de combate ("" = está disponível, ou não há campeão).
static func champion_out(w: GameWorld, div: String) -> String:
	var c := w.fighter(int(w.champions.get(div, -1)))
	if c == null:
		return ""
	if not c.injury.is_empty() and int(c.injury.get("weeks", 0)) >= OUT_WEEKS:
		return "%s está fora por lesão (%d semanas)" % [c.short_name(), int(c.injury["weeks"])]
	if c.bout_id < 0 and w.week - c.last_fight_week >= IDLE_WEEKS:
		return "%s não luta há %d semanas" % [c.short_name(), w.week - c.last_fight_week]
	return ""


static func booked(w: GameWorld, div: String) -> Bout:
	for b: Bout in w.bouts.values():
		if b.division == div and b.status == "marcada" and (b.title or b.interim):
			return b
	return null


## Pode valer o interino? (vazio = pode)
static func interim_reason(w: GameWorld, fa: Fighter, fb: Fighter) -> String:
	var div := fa.division
	if int(w.champions.get(div, -1)) < 0:
		return "O cinturão está vago: a luta vale o cinturão de verdade."
	if interim_of(w, div) != null:
		return "A categoria já tem campeão interino."
	if champion_out(w, div) == "":
		return "Interino só quando o campeão está fora de combate."
	if booked(w, div) != null:
		return "Já há uma disputa de cinturão marcada nessa categoria."
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	if ra < 1 or ra > 8 or rb < 1 or rb > 8:
		return "Os dois precisam estar entre os 8 primeiros."
	return ""


## Marca a disputa de interino num evento (os dois já aceitaram).
static func make_interim(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter) -> Bout:
	var b := Matchmaker.make_bout(w, ev, fa, fb, false, true)
	mark_interim(w, b)
	return b


## Transforma uma luta marcada em disputa de interino: cinco rounds, luta principal, bolsa maior.
static func mark_interim(w: GameWorld, b: Bout) -> void:
	b.interim = true
	b.main_event = true
	b.rounds = 5
	for p: Dictionary in [b.purse_a, b.purse_b]:
		p["show"] = snappedf(float(p["show"]) * PURSE_K, 500.0)
		p["win"] = snappedf(float(p["win"]) * PURSE_K, 500.0)
	var ev := w.event(b.event_id)
	Card.refresh(w, ev)
	w.add_news("cinturao", "%s: %s e %s disputam o cinturão interino dos %s na %s." % [_cap(champion_out(w, b.division)), w.fighter(b.a).display_name(), w.fighter(b.b).display_name(), Matchmaker.division_name(b.division, true), ev.name if ev != null else ""], [b.a, b.b], true)


static func _cap(t: String) -> String:
	return "Campeão fora de combate" if t == "" else t.substr(0, 1).to_upper() + t.substr(1)


## Resultado de uma luta, do ponto de vista dos cinturões (chamado em Rankings.apply_result
## depois de o campeão ser definido).
static func on_result(w: GameWorld, b: Bout, win: int, champ_before: int) -> void:
	var div := b.division
	var cur := int(w.interim.get(div, -1))
	var ev := w.event(b.event_id)
	var ev_name := ev.name if ev != null else ""
	if b.title:
		# Disputa do cinturão de verdade com o interino no octógono: unificou (ou segue interino
		# se deu empate).
		if cur >= 0 and b.has(cur) and win >= 0 and (b.title_for < 0 or b.title_for == win):
			w.interim.erase(div)
			var wf := w.fighter(win)
			w.add_news("cinturao", "Cinturão unificado nos %s: %s é campeão sem discussão." % [Matchmaker.division_name(div, true), wf.display_name()], [b.a, b.b], true)
		return
	if b.interim:
		if win < 0:
			return
		var wf2 := w.fighter(win)
		var lf := w.fighter(b.other(win))
		w.interim[div] = win
		Org.record_title(w, div, wf2, "interino, venceu %s" % lf.display_name(), ev_name)
		w.add_news("cinturao", "%s vence %s e é campeão interino dos %s." % [wf2.display_name(), lf.display_name(), Matchmaker.division_name(div, true)], [win, lf.id], true)
		return
	# Luta comum: interino que perde fica sem o interino.
	if cur >= 0 and b.has(cur) and win >= 0 and win != cur:
		w.interim.erase(div)
		var old := w.fighter(cur)
		w.add_news("cinturao", "%s perde para %s e o cinturão interino dos %s fica vago." % [old.display_name(), w.fighter(win).display_name(), Matchmaker.division_name(div, true)], [cur, win], true)


## O cinturão ficou vago: o interino, se houver, é promovido. Devolve true se promoveu.
static func promote(w: GameWorld, div: String) -> bool:
	var f := interim_of(w, div)
	w.interim.erase(div)
	if f == null or int(w.champions.get(div, -1)) >= 0:
		return false
	w.champions[div] = f.id
	f.titles_won += 1
	f.title_defenses = 0
	Org.record_title(w, div, f, "interino promovido", "")
	w.add_news("cinturao", "%s, campeão interino, é promovido a campeão dos %s." % [f.display_name(), Matchmaker.division_name(div, true)], [f.id], true)
	return true


## Semana a semana: limpa interino que não vale mais, promove quando o cinturão vagou e, no
## mundo que anda sozinho, marca o interino e a unificação.
static func week(w: GameWorld) -> void:
	for div: String in w.interim.keys():
		if interim_of(w, div) == null:
			w.interim.erase(div)
	for div: String in w.belt_wait.keys():
		if champion_out(w, div) == "" or interim_of(w, div) != null:
			w.belt_wait.erase(div)
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var champ := w.fighter(int(w.champions.get(div, -1)))
		if champ == null or champ.retired:
			if w.interim.has(div):
				promote(w, div)
			continue
		if w.is_president():
			continue
		if booked(w, div) != null:
			continue
		var it := interim_of(w, div)
		if it != null:
			_unify(w, champ, it)
		elif champion_out(w, div) != "":
			_book_interim(w, div)


static func _events(w: GameWorld) -> Array:
	return Calendar.open_events(w, 2, w.week + 4, w.week + 9).filter(func(e: FightEvent) -> bool: return not Card.has_belt(w, e))


static func _unify(w: GameWorld, champ: Fighter, it: Fighter) -> void:
	if w.is_user_fighter(champ) or w.is_user_fighter(it):
		# Com lutador do jogador no meio a liga propõe (ver Matchmaker.user_offers).
		return
	if not Matchmaker.ready_to_book(w, champ, 4) or not Matchmaker.ready_to_book(w, it, 4):
		return
	var evs := _events(w)
	if evs.is_empty():
		return
	var ev: FightEvent = evs[0]
	Matchmaker.make_bout(w, ev, champ, it, true, true)
	w.add_news("cinturao", "Unificação nos %s: o campeão %s volta contra o interino %s na %s." % [Matchmaker.division_name(champ.division, true), champ.display_name(), it.display_name(), ev.name], [champ.id, it.id], true)


## A liga está esperando a resposta do jogador para a disputa de interino desta categoria?
static func waiting_user(w: GameWorld, div: String) -> bool:
	return w.belt_wait.has(div) and w.week <= int(w.belt_wait[div])


static func _book_interim(w: GameWorld, div: String) -> void:
	var lst: Array = w.rankings.get(div, [])
	# Lutador do jogador entre os quatro primeiros e pronto: a proposta vai para ele (ver
	# Matchmaker.user_offers) e a liga espera três semanas antes de chamar outros dois.
	for i in mini(4, lst.size()):
		var u := w.fighter(int(lst[i]))
		if u != null and w.is_user_fighter(u) and Matchmaker.ready_to_book(w, u, 4):
			if not w.belt_wait.has(div):
				w.belt_wait[div] = w.week + 3
			break
	if waiting_user(w, div):
		return
	var cands: Array = []
	for i in mini(6, lst.size()):
		var c := w.fighter(int(lst[i]))
		if c != null and Matchmaker.ready_to_book(w, c, 4) and not w.is_user_fighter(c):
			cands.append(c)
	if cands.size() < 2:
		return
	var fa: Fighter = cands[0]
	var fb: Fighter = null
	for i in range(1, cands.size()):
		var o: Fighter = cands[i]
		if fa.team_id < 0 or fa.team_id != o.team_id:
			fb = o
			break
	if fb == null:
		return
	var evs := _events(w)
	if evs.is_empty():
		return
	make_interim(w, evs[0], fa, fb)
