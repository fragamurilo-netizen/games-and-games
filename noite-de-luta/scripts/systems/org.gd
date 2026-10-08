class_name Org
extends RefCounted
## Papel de presidente (o "Dana White"): o jogador manda na Liga Global, a organização de elite.
## O mundo é o mesmo do modo empresário (as academias, os circuitos regional e continental, o
## ranking andando sozinho); o que muda é o que passa pela mão do jogador:
## - as noites da liga (a cada duas semanas; numeradas com pay-per-view a cada quatro);
## - o card: quem luta com quem, quem disputa o cinturão, quanto cada um ganha;
## - as academias respondem à oferta de luta (aceitam, recusam e dizem por quê);
## - o fechamento da noite: bônus da noite, público, pay-per-view, TV, patrocínio e custos.
## O matchmaker da organização pode completar sozinho as vagas que sobrarem (delegate_cards).

const START_FUNDS := [6000000.0, 12000000.0, 25000000.0]
## Folha da organização (escritório, staff, marketing) por semana.
const OVERHEAD := 250000.0
## Bônus da noite: luta da noite (para os dois) e duas performances.
const BONUS := 50000.0
## Multiplicadores da bolsa que o presidente pode oferecer sobre a tabela.
const PURSE_STEPS := [1.0, 1.25, 1.5, 2.0]
const PURSE_NAMES := ["Tabela", "+25%", "+50%", "Dobro"]
## Lugares nas arenas das cidades da liga (as que faltam usam CAP_DEFAULT).
const CITY_CAP := {"Las Vegas": 19000, "Nova York": 19500, "Rio de Janeiro": 15000, "São Paulo": 14000,
	"Londres": 17000, "Abu Dhabi": 12000, "Paris": 15500, "Toronto": 19000, "Sydney": 18000,
	"Cidade do México": 20000, "Tóquio": 16000, "Seul": 12000, "Xangai": 15000, "Varsóvia": 15000,
	"Moscou": 14000, "Dublin": 9500, "Houston": 17000, "Miami": 18000, "Chicago": 20000}
const CAP_DEFAULT := 14000
## Semanas antes da noite em que o matchmaker completa as vagas.
const DELEGATE_WEEKS := 3


# --- Começo ------------------------------------------------------------------------------

static func new_career(org_name: String, short: String, nation: String, c1: Color, c2: Color, funds: float, seed_v: int) -> GameWorld:
	var w := WorldGenerator.generate(seed_v)
	w.role = "presidente"
	var t := Team.new()
	t.id = w.new_id()
	t.kind = "organizacao"
	t.name = org_name
	t.short = short if short != "" else WorldGenerator.short_of(org_name)
	t.nation = nation
	var cities: Array = DataDB.cities(nation)
	t.city = String((cities[0] as Array)[0]) if not cities.is_empty() else ""
	t.color1 = c1
	t.color2 = c2
	t.reputation = 55.0
	t.balance = funds
	t.is_user = true
	w.teams[t.id] = t
	w.user_team_id = t.id
	t.ledger.append({"week": 0, "label": "Caixa inicial", "value": funds})
	# As noites já marcadas pela gestão anterior passam a ter o nome da organização.
	for e: FightEvent in w.events.values():
		if e.tier == 2:
			e.name = event_name(w, e.week)
			e.ppv = is_ppv_week(e.week)
	# A gestão anterior deixou as noites das próximas semanas fechadas (a primeira é já no sábado).
	for e: FightEvent in upcoming_events(w):
		if e.week - w.week < 4:
			auto_fill(w, e)
	w.add_news("organizacao", "Você assume a presidência da %s. Os primeiros cards já estão anunciados; os próximos são seus." % t.name, [], true)
	return w


static func is_ppv_week(wk: int) -> bool:
	return wk % 4 == 0


## "XYZ 41" nas numeradas (pay-per-view) e "XYZ Fight Night 17" nas outras.
static func event_name(w: GameWorld, wk: int) -> String:
	var short := w.league_short()
	if is_ppv_week(wk):
		var n := int(w.event_counters.get("ORG_PPV", 40)) + 1
		w.event_counters["ORG_PPV"] = n
		return "%s %d" % [short, n]
	var m := int(w.event_counters.get("ORG_FN", 10)) + 1
	w.event_counters["ORG_FN"] = m
	return "%s Fight Night %d" % [short, m]


static func capacity(city: String) -> int:
	return int(CITY_CAP.get(city, CAP_DEFAULT))


# --- Elenco e regras do card ---------------------------------------------------------------

## Pode lutar na liga: está entre os de elite da categoria, é o campeão ou vem do topo do circuito
## continental (estreia na liga).
static func eligible(w: GameWorld, f: Fighter) -> bool:
	if f == null or f.retired or not f.is_pro():
		return false
	var r := w.rank_of(f)
	return r == 0 or (r > 0 and r <= Rankings.lgc_size(f.division) + 15)


## Lutadores da liga numa categoria (campeão primeiro, depois o ranking).
static func roster(w: GameWorld, div: String) -> Array:
	var out: Array = []
	var champ := w.fighter(int(w.champions.get(div, -1)))
	if champ != null and not champ.retired:
		out.append(champ)
	for id: int in w.rankings.get(div, []):
		var f := w.fighter(id)
		if f != null and eligible(w, f):
			out.append(f)
	return out


## Noites da liga daqui para a frente (a desta semana inclusive, se ainda não foi fechada).
static func upcoming_events(w: GameWorld) -> Array:
	var out: Array = []
	for e: FightEvent in w.events.values():
		if e.tier == 2 and e.week >= w.week and not e.closed:
			out.append(e)
	out.sort_custom(func(a: FightEvent, b: FightEvent) -> bool: return a.week < b.week)
	return out


static func past_events(w: GameWorld) -> Array:
	var out: Array = []
	for e: FightEvent in w.events.values():
		if e.tier == 2 and e.closed:
			out.append(e)
	out.sort_custom(func(a: FightEvent, b: FightEvent) -> bool: return a.week > b.week)
	return out


static func event_bouts(w: GameWorld, ev: FightEvent) -> Array:
	var out: Array = []
	for bid: int in ev.bouts:
		var b := w.bout(bid)
		if b != null and b.status != "cancelada":
			out.append(b)
	return out


static func has_main(w: GameWorld, ev: FightEvent) -> bool:
	for b: Bout in event_bouts(w, ev):
		if b.main_event:
			return true
	return false


static func title_booked(w: GameWorld, div: String) -> Bout:
	for b: Bout in w.bouts.values():
		if b.title and b.division == div and b.status == "marcada":
			return b
	return null


## Pode valer cinturão? Campeão contra um dos 15 primeiros, ou cinturão vago entre dois dos 10.
static func title_reason(w: GameWorld, fa: Fighter, fb: Fighter) -> String:
	var champ := int(w.champions.get(fa.division, -1))
	if title_booked(w, fa.division) != null:
		return "Já há uma disputa de cinturão marcada nessa categoria."
	var ra := w.rank_of(fa)
	var rb := w.rank_of(fb)
	if champ >= 0:
		if fa.id != champ and fb.id != champ:
			return "Só vale cinturão com o campeão no octógono."
		var other := rb if fa.id == champ else ra
		if other < 1 or other > 15:
			return "O desafiante precisa estar entre os 15 primeiros."
		return ""
	if ra < 1 or ra > 10 or rb < 1 or rb > 10:
		return "Cinturão vago: os dois precisam estar entre os 10 primeiros."
	return ""


## Por que a luta não pode ser oferecida (vazio = pode).
static func book_reason(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter) -> String:
	if ev == null or ev.closed or ev.done:
		return "Essa noite já aconteceu."
	if event_bouts(w, ev).size() >= ev.slots:
		return "O card da %s está cheio." % ev.name
	if fa.division != fb.division:
		return "Os dois precisam ser da mesma categoria."
	for f: Fighter in [fa, fb]:
		if not eligible(w, f):
			return "%s não está no nível da liga." % f.display_name()
		if f.bout_id >= 0:
			var b := w.bout(f.bout_id)
			if b != null and b.status == "marcada":
				return "%s já tem luta marcada." % f.display_name()
		if not f.injury.is_empty() or f.suspension > ev.week - w.week:
			return "%s está machucado ou suspenso." % f.display_name()
		if not Matchmaker.ready_to_book(w, f, ev.week - w.week):
			return "%s precisa de mais tempo de descanso até essa data." % f.display_name()
	if not Matchmaker.can_face(w, fa, fb):
		return "Essa luta não pode: mesma academia ou revanche imediata."
	return ""


## Bolsa da tabela da liga para o lutador (antes do multiplicador do presidente).
static func table_purse(w: GameWorld, f: Fighter, title: bool) -> Dictionary:
	return Matchmaker.purse(w, f, 2, title)


## Chance de a academia de `f` aceitar a luta contra `opp` (0–1) e o motivo principal se recusar.
static func acceptance(w: GameWorld, ev: FightEvent, f: Fighter, opp: Fighter, title: bool, mult: float) -> Array:
	var p := 0.9
	var why := ""
	var rf := w.rank_of(f)
	var ro := w.rank_of(opp)
	var nf := 99 if rf < 0 else rf
	var no := 99 if ro < 0 else ro
	var gap := no - nf
	if gap > 5:
		p -= minf(0.5, (gap - 5) * 0.045)
		why = "A equipe de %s diz que ele não ganha nada lutando com alguém tão abaixo no ranking." % f.short_name()
	if rf == 0 and not title:
		p -= 0.35
		why = "Campeão só aceita luta valendo o cinturão."
	if rf == 0 and title and no > 5:
		p -= 0.3
		why = "O campeão quer defender o cinturão contra alguém do top 5."
	if title and rf != 0:
		p += 0.12
	var notice := ev.week - w.week
	if notice < 3:
		p -= 0.22 if notice == 2 else 0.4
		if why == "":
			why = "Aviso curto demais: a equipe de %s não tem tempo de preparar o camp." % f.short_name()
	if f.condition < 85.0:
		p -= 0.2
		if why == "":
			why = "%s ainda não está 100%% fisicamente." % f.short_name()
	if f.popularity > opp.popularity + 30.0 and mult < 1.5:
		p -= 0.15
		if why == "":
			why = "%s é estrela; para enfrentar alguém desconhecido, quer uma bolsa maior." % f.short_name()
	p += [0.0, 0.08, 0.14, 0.2][maxi(0, PURSE_STEPS.find(mult))]
	if why == "":
		why = "A equipe de %s pediu mais dinheiro e um adversário melhor." % f.short_name()
	return [clampf(p, 0.03, 0.97), why]


## Oferece a luta às duas academias. {ok, text, bout}
static func offer_bout(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter, title: bool, main: bool, mult: float) -> Dictionary:
	var why := book_reason(w, ev, fa, fb)
	if why != "":
		return {"ok": false, "text": why}
	if title:
		why = title_reason(w, fa, fb)
		if why != "":
			return {"ok": false, "text": why}
	var key := "%d:%d" % [mini(fa.id, fb.id), maxi(fa.id, fb.id)]
	var blk: Dictionary = w.bout_block.get(key, {})
	if not blk.is_empty() and int(blk.get("until", -1)) > w.week and mult <= float(blk.get("mult", 1.0)):
		return {"ok": false, "text": "As equipes já recusaram essa luta nesta semana. Só com uma bolsa maior."}
	for pair: Array in [[fa, fb], [fb, fa]]:
		var acc := acceptance(w, ev, pair[0], pair[1], title, mult)
		if w.rng.randf() >= float(acc[0]):
			w.bout_block[key] = {"until": w.week + 1, "mult": mult}
			return {"ok": false, "text": String(acc[1])}
	var b := book(w, ev, fa, fb, title, main or title, mult)
	return {"ok": true, "text": "Fechado: %s × %s na %s%s." % [fa.short_name(), fb.short_name(), ev.name, ", valendo o cinturão" if title else ""], "bout": b.id}


## Marca a luta (já aceita) no card, com a bolsa da tabela vezes `mult`.
static func book(w: GameWorld, ev: FightEvent, fa: Fighter, fb: Fighter, title: bool, main: bool, mult: float) -> Bout:
	if main:
		# Uma luta principal por noite: a anterior vira co-principal.
		for ob: Bout in event_bouts(w, ev):
			if ob.main_event and not ob.title:
				ob.main_event = false
				ob.rounds = 3
	var b := Matchmaker.make_bout(w, ev, fa, fb, title, main)
	if main and not title:
		b.rounds = 5
	for side: Array in [[b.a, b.purse_a], [b.b, b.purse_b]]:
		var p: Dictionary = side[1]
		p["show"] = snappedf(float(p["show"]) * mult, 500.0)
		p["win"] = snappedf(float(p["win"]) * mult, 500.0)
	_reorder(w, ev)
	if title:
		w.add_news("cinturao", "Luta pelo cinturão dos %s: %s × %s na %s (%s)." % [Matchmaker.division_name(b.division, true), w.fighter(b.a).display_name(), w.fighter(b.b).display_name(), ev.name, GameWorld.fight_date_text(ev.week)], [b.a, b.b], true)
	elif main:
		w.add_news("organizacao", "Luta principal da %s: %s × %s." % [ev.name, w.fighter(b.a).display_name(), w.fighter(b.b).display_name()], [b.a, b.b])
	return b


## Ordem do card: a principal por último, antes dela as de cinturão, depois por fama.
static func _reorder(w: GameWorld, ev: FightEvent) -> void:
	var lst := event_bouts(w, ev)
	lst.sort_custom(func(x: Bout, y: Bout) -> bool: return _weight(w, x) < _weight(w, y))
	ev.bouts = lst.map(func(b: Bout) -> int: return b.id)


static func _weight(w: GameWorld, b: Bout) -> float:
	var s := (w.fighter(b.a).popularity + w.fighter(b.b).popularity) * 0.5
	if b.title:
		s += 200.0
	if b.main_event:
		s += 400.0
	return s


## Tira a luta do card (as equipes não gostam: a organização perde um pouco de reputação).
static func cancel(w: GameWorld, b: Bout) -> void:
	Career.cancel_bout(w, b, "decisão da organização")
	var t := w.user_team()
	if t != null:
		t.reputation = maxf(1.0, t.reputation - 0.4)


## Adversários sugeridos para `f` numa noite: perto no ranking, disponíveis, sem revanche.
static func suggestions(w: GameWorld, ev: FightEvent, f: Fighter, limit: int = 12) -> Array:
	var rf := w.rank_of(f)
	var out: Array = []
	for o: Fighter in roster(w, f.division):
		if o.id == f.id or book_reason(w, ev, f, o) != "":
			continue
		var ro := w.rank_of(o)
		var d := absf(float(rf if rf >= 0 else 60) - float(ro if ro >= 0 else 60))
		out.append([d, o])
	out.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	return out.slice(0, limit).map(func(x: Array) -> Fighter: return x[1])


## Completa as vagas do card com lutas da tabela (o matchmaker da organização fecha direto).
static func auto_fill(w: GameWorld, ev: FightEvent) -> int:
	var made := 0
	var guard := 0
	var divs: Array = DataDB.divisions().map(func(d: Dictionary) -> String: return String(d["id"]))
	while event_bouts(w, ev).size() < ev.slots and guard < 80:
		guard += 1
		var div: String = divs[w.rng.randi_range(0, divs.size() - 1)]
		var pool := roster(w, div).filter(func(f: Fighter) -> bool:
			return f.bout_id < 0 and f.injury.is_empty() and Matchmaker.ready_to_book(w, f, ev.week - w.week) and w.rank_of(f) != 0)
		if pool.size() < 2:
			continue
		pool.sort_custom(func(x: Fighter, y: Fighter) -> bool: return x.last_fight_week < y.last_fight_week)
		var fa: Fighter = pool[mini(pool.size() - 1, w.rng.randi_range(0, 2))]
		var opts := suggestions(w, ev, fa, 4).filter(func(o: Fighter) -> bool: return w.rank_of(o) != 0)
		if opts.is_empty():
			continue
		var fb: Fighter = opts[w.rng.randi_range(0, mini(opts.size() - 1, 1))]
		book(w, ev, fa, fb, false, false, 1.0)
		made += 1
	ensure_main(w, ev)
	return made


## Card sem luta principal: a mais vendável vira a principal (5 rounds).
static func ensure_main(w: GameWorld, ev: FightEvent) -> void:
	var lst := event_bouts(w, ev)
	if lst.is_empty() or has_main(w, ev):
		return
	var best: Bout = lst[0]
	for b: Bout in lst:
		if _weight(w, b) > _weight(w, best):
			best = b
	best.main_event = true
	best.rounds = 5
	_reorder(w, ev)


## Semana a semana: o matchmaker completa os cards que estão chegando (se o presidente deixou).
static func delegate_fill(w: GameWorld) -> void:
	if not w.delegate_cards:
		return
	for ev: FightEvent in upcoming_events(w):
		if ev.week - w.week <= DELEGATE_WEEKS and ev.week > w.week:
			auto_fill(w, ev)


# --- Noite de luta ------------------------------------------------------------------------

## Noite da liga desta semana ainda aberta (com lutas por fazer ou por fechar), ou null.
static func night_this_week(w: GameWorld) -> FightEvent:
	for e: FightEvent in w.events.values():
		if e.tier == 2 and e.week == w.week and not e.closed:
			return e
	return null


static func pending_bouts(w: GameWorld) -> Array:
	var ev := night_this_week(w)
	if ev == null:
		return []
	return event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "marcada")


## Apelo da noite (0–100): a fama da luta principal pesa mais, cinturão e co-principal somam.
static func draw(w: GameWorld, ev: FightEvent) -> float:
	var lst := event_bouts(w, ev)
	if lst.is_empty():
		return 0.0
	var main: Bout = lst.back()
	var pa := w.fighter(main.a).popularity
	var pb := w.fighter(main.b).popularity
	var d := maxf(pa, pb) * 0.55 + minf(pa, pb) * 0.3
	if lst.size() > 1:
		var co: Bout = lst[lst.size() - 2]
		d += (w.fighter(co.a).popularity + w.fighter(co.b).popularity) * 0.5 * 0.15
	var belts := 0
	for b: Bout in lst:
		if b.title:
			d += 8.0 if belts == 0 else 3.0
			belts += 1
	if ev.ppv:
		d += 4.0
	d *= minf(1.0, 0.55 + lst.size() / float(maxi(1, ev.slots)) * 0.45)
	return clampf(d, 0.0, 100.0)


## Projeção das contas da noite (usada antes, na tela do card, e no fechamento).
static func projection(w: GameWorld, ev: FightEvent) -> Dictionary:
	var t := w.user_team()
	var rep := t.reputation if t != null else 50.0
	var dr := draw(w, ev)
	var cap := capacity(ev.city)
	var fill := clampf(0.42 + dr / 130.0 + rep / 400.0, 0.3, 1.0)
	var crowd := int(cap * fill)
	var ticket := 95.0 + dr * 1.6
	var gate := crowd * ticket
	var ppv_buys := 0
	if ev.ppv:
		ppv_buys = int(10000.0 + 300000.0 * pow(dr / 100.0, 3.0) * (0.5 + rep / 100.0 * 0.7))
	var ppv := ppv_buys * 64.99 * 0.5
	var tv := 1800000.0 * (0.6 + rep / 100.0 * 0.8)
	var sponsors := 400000.0 * (0.5 + rep / 100.0)
	var purses := 0.0
	for b: Bout in event_bouts(w, ev):
		for p: Dictionary in [b.purse_a, b.purse_b]:
			purses += float(p["show"])
			# Projeção: metade dos bônus de vitória (um dos dois ganha).
			purses += float(p["win"]) * 0.5
	var production := (1000000.0 if ev.ppv else 650000.0) + cap * 18.0
	return {"draw": dr, "crowd": crowd, "capacity": cap, "ticket": ticket, "gate": gate, "ppv_buys": ppv_buys, "ppv": ppv,
		"tv": tv, "sponsors": sponsors, "purses": purses, "production": production, "bonuses": BONUS * 4.0,
		"profit": gate + ppv + tv + sponsors - purses - production - BONUS * 4.0}


## Sugestão de bônus: a luta mais movimentada que foi para a decisão (ou a mais disputada) e as
## duas finalizações mais bonitas (mais rápidas, mais importantes no card).
static func auto_bonuses(w: GameWorld, ev: FightEvent) -> Dictionary:
	var lst := event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "feita")
	var fotn := -1
	var best := -1.0
	for b: Bout in lst:
		var st: Array = b.result.get("stats", [])
		var act := 0.0
		for s: Dictionary in st:
			act += float(s.get("sig_land", 0)) + float(s.get("kd", 0)) * 12.0 + float(s.get("sub_att", 0)) * 4.0
		if String(b.result.get("method", "")) == "DEC":
			act *= 1.0 + 0.1 * int(b.rounds)
		if act > best:
			best = act
			fotn = b.id
	var fins: Array = []
	for b: Bout in lst:
		var m := String(b.result.get("method", ""))
		if m in ["KO", "TKO", "FIN"] and b.id != fotn and int(b.result.get("winner_id", -1)) >= 0:
			var quick := float(b.result.get("round", 1)) * 300.0 + float(b.result.get("time", 0.0))
			var score := 2000.0 - quick + (_weight(w, b) * 2.0)
			fins.append([score, int(b.result["winner_id"])])
	fins.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	var potn: Array = []
	for it: Array in fins.slice(0, 2):
		potn.append(int(it[1]))
	return {"fotn": fotn, "potn": potn}


## Fecha a noite: paga bolsas e bônus, recebe bilheteria, pay-per-view, TV e patrocínio, ajusta a
## reputação da organização e a fama de quem levou bônus, e escreve as notícias. Uma vez só.
static func close_event(w: GameWorld, ev: FightEvent, bonuses: Dictionary) -> Dictionary:
	if ev.closed:
		return ev.report
	var t := w.user_team()
	var pr := projection(w, ev)
	# Bolsas de verdade (o bônus de vitória só de quem ganhou).
	var purses := 0.0
	var finishes := 0
	for b: Bout in event_bouts(w, ev):
		if b.status != "feita":
			continue
		var wid := int(b.result.get("winner_id", -1))
		purses += float(b.purse_a["show"]) + float(b.purse_b["show"])
		if wid == b.a:
			purses += float(b.purse_a["win"])
		elif wid == b.b:
			purses += float(b.purse_b["win"])
		if String(b.result.get("method", "")) in ["KO", "TKO", "FIN"]:
			finishes += 1
	var paid_bonus := 0.0
	var fotn := int(bonuses.get("fotn", -1))
	var potn: Array = bonuses.get("potn", [])
	var names: Array = []
	var fb := w.bout(fotn)
	if fb != null:
		paid_bonus += BONUS * 2.0
		for fid: int in [fb.a, fb.b]:
			var f := w.fighter(fid)
			f.popularity = minf(100.0, f.popularity + 3.0)
		names.append("luta da noite para %s e %s" % [w.fighter(fb.a).short_name(), w.fighter(fb.b).short_name()])
	for fid: int in potn:
		var f := w.fighter(int(fid))
		if f == null:
			continue
		paid_bonus += BONUS
		f.popularity = minf(100.0, f.popularity + 3.0)
		names.append("performance da noite para %s" % f.short_name())
	var rep := t.reputation if t != null else 50.0
	if event_bouts(w, ev).filter(func(b: Bout) -> bool: return b.status == "feita").is_empty():
		# Noite cancelada: só o prejuízo da produção montada e o prestígio que vai embora.
		var loss := float(pr["production"]) * 0.3
		if t != null:
			t.add_money(w.week, "%s cancelada" % ev.name, -loss)
			t.reputation = maxf(1.0, rep - 3.0)
		ev.closed = true
		ev.report = {"crowd": 0, "capacity": pr["capacity"], "gate": 0.0, "ppv_buys": 0, "ppv": 0.0, "tv": 0.0, "sponsors": 0.0,
			"purses": 0.0, "production": loss, "bonus": 0.0, "profit": -loss, "draw": 0.0, "finishes": 0, "fotn": -1, "potn": []}
		w.add_news("organizacao", "%s cancelada: sem lutas no card. A organização perde dinheiro e prestígio." % ev.name, [], true)
		return ev.report
	var income: float = float(pr["gate"]) + float(pr["ppv"]) + float(pr["tv"]) + float(pr["sponsors"])
	var cost: float = purses + float(pr["production"]) + paid_bonus
	if t != null:
		t.add_money(w.week, "%s: bilheteria (%s pessoas)" % [ev.name, Fmt.thousands(int(pr["crowd"]))], float(pr["gate"]))
		if ev.ppv:
			t.add_money(w.week, "%s: pay-per-view (%s compras)" % [ev.name, Fmt.thousands(int(pr["ppv_buys"]))], float(pr["ppv"]))
		t.add_money(w.week, "%s: direitos de TV" % ev.name, float(pr["tv"]))
		t.add_money(w.week, "%s: patrocínio" % ev.name, float(pr["sponsors"]))
		t.add_money(w.week, "%s: bolsas" % ev.name, -purses)
		t.add_money(w.week, "%s: produção e arena" % ev.name, -float(pr["production"]))
		if paid_bonus > 0.0:
			t.add_money(w.week, "%s: bônus da noite" % ev.name, -paid_bonus)
		# Reputação: noite cheia de estrelas e de finalizações faz a organização crescer.
		var n := event_bouts(w, ev).size()
		var gain := (float(pr["draw"]) - 50.0) / 60.0 + finishes * 0.06 - maxf(0.0, ev.slots - n) * 0.25
		gain *= 1.1 - rep / 110.0
		t.reputation = clampf(rep + gain, 1.0, 100.0)
	ev.closed = true
	ev.report = {"crowd": pr["crowd"], "capacity": pr["capacity"], "gate": pr["gate"], "ppv_buys": pr["ppv_buys"], "ppv": pr["ppv"],
		"tv": pr["tv"], "sponsors": pr["sponsors"], "purses": purses, "production": pr["production"], "bonus": paid_bonus,
		"profit": income - cost, "draw": pr["draw"], "finishes": finishes, "fotn": fotn, "potn": potn}
	var txt := "%s em %s: %s pessoas" % [ev.name, ev.city, Fmt.thousands(int(pr["crowd"]))]
	if ev.ppv:
		txt += ", %s compras de pay-per-view" % Fmt.thousands(int(pr["ppv_buys"]))
	txt += ". Resultado da noite: %s." % Fmt.money(income - cost)
	if not names.is_empty():
		txt += " Bônus: " + ", ".join(names) + "."
	w.add_news("organizacao", txt, [], true)
	return ev.report


## Folha semanal da organização.
static func weekly(w: GameWorld) -> void:
	var t := w.user_team()
	if t == null:
		return
	t.add_money(w.week, "Folha da organização", -OVERHEAD)
	# Fama não se sustenta sozinha: acima de 60 a reputação cai devagar sem noites boas.
	if t.reputation > 60.0:
		t.reputation -= 0.04


## Registra um campeão novo na história do cinturão.
static func record_title(w: GameWorld, div: String, f: Fighter, how: String, ev_name: String) -> void:
	if not w.title_history.has(div):
		w.title_history[div] = []
	(w.title_history[div] as Array).append({"week": w.week, "id": f.id, "name": f.display_name(), "how": how, "event": ev_name})
