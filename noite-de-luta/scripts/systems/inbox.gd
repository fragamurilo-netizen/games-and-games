class_name Inbox
extends RefCounted
## Caixa de entrada: o que espera uma decisão do jogador e o que aconteceu com a equipe dele.
##
## Duas coisas moram aqui (`GameWorld.inbox`):
## - **pendências**: nascem do estado do mundo (`_manager`, `_president`): proposta na mesa,
##   lutador infeliz, contrato no fim, imprevisto da semana da luta, card incompleto, contrato de
##   TV. Cada uma tem uma chave; `scan` cria a mensagem quando a condição aparece, atualiza o
##   texto enquanto ela dura e fecha a mensagem quando a condição some. Nada disso usa sorteio.
## - **avisos**: as notícias que dizem respeito ao jogador (`_import_news`), já fechados.
##
## Estados (`st`): ABERTA (espera o jogador), VISTA (ele já mexeu; a condição continua, mas não
## cobra de novo) e FECHADA. A ação de cada mensagem (`act` + `arg`) é executada pela interface
## (`InboxKit`).

const OPEN := 0
const HANDLED := 1
const CLOSED := 2
const MAX := 90
## Semanas parado a partir das quais o lutador sem luta vira pendência.
const IDLE_WEEKS := 12
## Noites da liga a até tantas semanas entram como "card incompleto".
const CARD_WEEKS := 6

const CATS := {
	"luta": "Lutas", "equipe": "Equipe", "contrato": "Contratos", "olheiro": "Olheiro", "financas": "Finanças",
	"noite": "Noites", "tv": "TV", "cinturao": "Cinturões", "mundo": "Mundo",
}
const NEWS_TITLES := {
	"equipe": "Sua academia", "organizacao": "Sua organização", "olheiro": "Relatório do olheiro", "marco": "Marco de carreira",
	"cinturao": "Cinturão", "rivalidade": "Rivalidade", "resultado": "Resultado", "tv": "Contrato de TV", "premio": "Prêmios do ano",
	"hall": "Hall da Fama", "aposentadoria": "Aposentadoria", "categoria": "Troca de categoria", "mercado": "Mercado",
}
## Notícias que já viram pendência (não repetir como aviso).
const NEWS_SKIP := ["O contrato de ", "está infeliz na equipe", "Três propostas estão na mesa", "A organização precisa decidir"]


# --- Leitura -------------------------------------------------------------------------------

## Todas, da mais nova para a mais velha.
static func all(w: GameWorld) -> Array:
	var out := w.inbox.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["wk"]) != int(b["wk"]):
			return int(a["wk"]) > int(b["wk"])
		if Inbox.is_open(a) != Inbox.is_open(b):
			return Inbox.is_open(a)
		return int(a["id"]) > int(b["id"]))
	return out


## As que esperam o jogador, da mais urgente para a menos.
static func pending(w: GameWorld) -> Array:
	var out := w.inbox.filter(func(m: Dictionary) -> bool: return bool(m.get("pend", false)) and int(m["st"]) == OPEN)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["pri"]) != int(b["pri"]):
			return int(a["pri"]) > int(b["pri"])
		return int(a["id"]) > int(b["id"]))
	return out


static func unread(w: GameWorld) -> int:
	var n := 0
	for m: Dictionary in w.inbox:
		if not bool(m.get("rd", false)):
			n += 1
	return n


static func by_id(w: GameWorld, id: int) -> Dictionary:
	for m: Dictionary in w.inbox:
		if int(m["id"]) == id:
			return m
	return {}


static func is_open(m: Dictionary) -> bool:
	return bool(m.get("pend", false)) and int(m["st"]) == OPEN


static func mark_read(m: Dictionary) -> void:
	m["rd"] = true


static func mark_all_read(w: GameWorld) -> void:
	for m: Dictionary in w.inbox:
		m["rd"] = true


## O jogador já mexeu nisto: sai das pendências, mas a condição não cria outra mensagem.
static func handle(m: Dictionary) -> void:
	m["rd"] = true
	if int(m["st"]) == OPEN:
		m["st"] = HANDLED


# --- Sincronia com o mundo -----------------------------------------------------------------

## Cria, atualiza e fecha as pendências pelo estado do mundo e importa as notícias novas.
## Devolve quantas mensagens novas entraram.
static func scan(w: GameWorld) -> int:
	if w == null or w.user_team() == null:
		return 0
	var conds: Array = _president(w) if w.is_president() else _manager(w)
	var live := {}
	for c: Dictionary in conds:
		live[String(c["key"])] = c
	var seen := {}
	for m: Dictionary in w.inbox:
		# Aviso velho não fica cobrando leitura.
		if not bool(m.get("pend", false)) and int(m["wk"]) < w.week - 1:
			m["rd"] = true
		if not bool(m.get("pend", false)) or int(m["st"]) == CLOSED:
			continue
		var k := String(m["key"])
		if not live.has(k):
			m["st"] = CLOSED
			continue
		seen[k] = true
		var c: Dictionary = live[k]
		m["t"] = c["t"]
		m["x"] = c["x"]
		m["pri"] = c["pri"]
		m["arg"] = c["arg"]
	var added := 0
	for c: Dictionary in conds:
		if seen.has(String(c["key"])):
			continue
		_add(w, c, true)
		added += 1
	added += _import_news(w)
	_trim(w)
	return added


static func _add(w: GameWorld, c: Dictionary, pend: bool) -> void:
	w.inbox_seq += 1
	w.inbox.append({"id": w.inbox_seq, "wk": w.week, "key": c["key"], "cat": c["cat"], "from": c["from"], "t": c["t"], "x": c["x"],
		"f": c["f"], "act": c["act"], "arg": c["arg"], "pri": c["pri"], "pend": pend, "st": OPEN if pend else CLOSED, "rd": false})


static func _c(key: String, cat: String, from: String, title: String, text: String, ids: Array, act: String, arg: Dictionary, pri: int) -> Dictionary:
	return {"key": key, "cat": cat, "from": from, "t": title, "x": text, "f": ids, "act": act, "arg": arg, "pri": pri}


static func _trim(w: GameWorld) -> void:
	var over := w.inbox.size() - MAX
	if over <= 0:
		return
	var keep: Array = []
	for m: Dictionary in w.inbox:
		if over > 0 and int(m["st"]) == CLOSED:
			over -= 1
			continue
		keep.append(m)
	w.inbox = keep


static func _org_of(ev: FightEvent) -> String:
	if ev == null:
		return "Organização"
	var n := ev.name.rstrip("0123456789 ")
	return "Matchmaker · %s" % n if n != "" else "Organização"


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1)


# --- Empresário ----------------------------------------------------------------------------

static func _manager(w: GameWorld) -> Array:
	var out: Array = []
	var t := w.user_team()
	var mine := w.user_fighters()
	for b: Bout in Career.pending_user_bouts(w):
		var ev := w.event(b.event_id)
		var f := w.fighter(b.a) if w.is_user_fighter(w.fighter(b.a)) else w.fighter(b.b)
		var o := w.fighter(b.other(f.id))
		out.append(_c("noite:%d" % b.id, "luta", _org_of(ev), "Noite de luta: %s × %s" % [f.short_name(), o.short_name()],
			"%s, em %s. Monte o plano de luta e vá para o corner." % [ev.name if ev != null else "Evento", ev.city if ev != null else ""],
			[f.id, o.id], "fight_plan", {"bout": b.id}, 100))
	var with_offer := {}
	for o: Dictionary in w.offers:
		var f := w.fighter(int(o["fighter"]))
		var opp := w.fighter(int(o["opp"]))
		var ev := w.event(int(o["event"]))
		if f == null or opp == null:
			continue
		with_offer[f.id] = true
		var belt := bool(o.get("title", false))
		var interim := bool(o.get("interim", false))
		var left := int(o["expires"]) - w.week
		var head := "Cinturão" if belt else ("Cinturão interino" if interim else "Proposta")
		var text := "Bolsa de %s mais %s pela vitória. %s, %s. %s" % [Fmt.money(float(o["show"])), Fmt.money(float(o["win"])),
			ev.name if ev != null else "Evento", w.weeks_from_now(int(o["week"])),
			"Responda nesta semana ou ela expira." if left <= 0 else "Responda em até %s." % Fmt.plural(left, "semana", "semanas")]
		out.append(_c("offer:%d" % int(o["id"]), "luta", _org_of(ev), "%s: %s × %s" % [head, f.short_name(), opp.short_name()], text,
			[f.id, opp.id], "offer", {"id": int(o["id"])}, 92 if left <= 0 else (88 if belt or interim else 80)))
	if mine.is_empty():
		out.append(_c("vazio", "equipe", "Academia", "Sua academia ainda não tem lutadores",
			"Amadores custam pouco e aceitam fácil. Profissionais rendem bolsas maiores, mas querem uma academia com nome.", [], "market", {}, 85))
	for f: Fighter in mine:
		if Morale.tone(f) < 0:
			var why := ""
			var worst := 0.0
			for it: Array in Morale.factors(w, f):
				if float(it[1]) < worst:
					worst = float(it[1])
					why = String(it[0])
			var wait := Morale.talk_wait(w, f)
			var tail := "Dá para conversar agora." if wait == 0 else "Nova conversa em %s." % Fmt.plural(wait, "semana", "semanas")
			out.append(_c("moral:%d" % f.id, "equipe", f.short_name(), "%s está %s" % [f.short_name(), Morale.label(f).to_lower()],
				"%s%s" % [(_cap(why) + ". ") if why != "" else "", tail], [f.id], "talk" if wait == 0 else "fighter", {"id": f.id}, 62 if Morale.tone(f) <= -2 else 56))
		if f.contract.has("fights") and int(f.contract["fights"]) <= 0:
			out.append(_c("contrato:%d" % f.id, "contrato", f.short_name(), "O contrato de %s acabou" % f.short_name(),
				"Sem renovação, %s pode sair a qualquer semana e outra academia leva." % ("ela" if f.is_female() else "ele"), [f.id], "renew", {"id": f.id}, 75))
		elif int(f.contract.get("fights", 9)) == 1:
			out.append(_c("contrato1:%d" % f.id, "contrato", f.short_name(), "Última luta do contrato de %s" % f.short_name(),
				"Depois da próxima luta o contrato acaba. Dá para renovar antes na ficha %s." % ("dela" if f.is_female() else "dele"), [f.id], "fighter", {"id": f.id}, 34))
		var b := Camp.bout_of(w, f)
		if b != null and Camp.in_window(w, f):
			var opp := w.fighter(b.other(f.id))
			var c := Camp.ensure(w, f)
			out.append(_c("camp:%d" % b.id, "luta", "Comissão técnica", "Camp de %s: faltam %s" % [f.short_name(), Fmt.plural(Camp.weeks_left(w, f), "semana", "semanas")],
				"Contra %s. Treina %s, %s. Escolha o foco e veja o custo por semana." % [opp.short_name(),
				"em casa" if String(c.get("place", "casa")) == "casa" else "fora de casa", "com sparring contratado" if bool(c.get("spar", false)) else "sem sparring contratado"],
				[f.id, opp.id], "camp", {"id": f.id}, 40))
		if Matchmaker.shot_promised(w, f):
			var champ := w.fighter(int(w.champions.get(f.division, -1)))
			out.append(_c("shot:%d" % f.id, "cinturao", "Liga", "%s é o próximo na fila do cinturão" % f.short_name(),
				"A liga sinalizou a disputa contra %s. Vale esperar a proposta em vez de aceitar outra luta." % (champ.short_name() if champ != null else "o campeão"),
				[f.id], "fighter", {"id": f.id}, 45))
		var idle := w.week - f.last_fight_week
		if f.bout_id < 0 and f.available() and not with_offer.has(f.id) and idle >= IDLE_WEEKS and Matchmaker.ready_to_book(w, f, 0):
			out.append(_c("parado:%d" % f.id, "luta", "Comissão técnica", "%s está sem luta há %d semanas" % [f.short_name(), idle],
				"Lutador parado perde ritmo e moral. Desafie alguém pelo ranking ou espere uma proposta.", [f.id], "fighter", {"id": f.id}, 30))
	if t.balance < 0.0:
		out.append(_c("caixa", "financas", "Financeiro", "Caixa no vermelho: %s" % Fmt.money(t.balance),
			"Sem caixa, camp fora de casa e sparring param. Corte custos na Academia ou feche uma luta.", [], "gym", {}, 70))
	return out


# --- Presidente ----------------------------------------------------------------------------

static func _president(w: GameWorld) -> Array:
	var out: Array = []
	var t := w.user_team()
	var night := Org.night_this_week(w)
	var urgent := FightWeek.pending(w)
	for i: Dictionary in urgent:
		var ev := w.event(int(i["event"]))
		var hurt := String(i["kind"]) == "lesao"
		out.append(_c("inc:%d" % int(i["id"]), "noite", "Departamento médico" if hurt else "Comissão atlética", FightWeek.incident_title(w, i),
			"%s. %s" % [ev.name if ev != null else "Noite", FightWeek.incident_text(w, i)], [int(i["fighter"]), int(i["opp"])], "incident", {"id": int(i["id"])}, 98))
	if night != null:
		var lst := Org.event_bouts(w, night)
		var done := lst.filter(func(b: Bout) -> bool: return b.status == "feita").size()
		out.append(_c("noite:%d" % night.id, "noite", "Operações", "Noite de luta: %s" % night.name,
			"%s, em %s. %d de %d lutas feitas." % [GameWorld.fight_date_text(night.week, false), night.city, done, lst.size()], [], "night", {"id": night.id},
			94 if not urgent.is_empty() else 100))
	if TVDeal.pending(w):
		var left := TVDeal.weeks_left(w)
		out.append(_c("tv:%d" % int(w.tv.get("until", 0)), "tv", String(TVDeal.partner_of(w).get("name", "TV")),
			"Contrato de TV: %s na mesa" % Fmt.plural(w.tv_offers.size(), "proposta", "propostas"),
			"O contrato atual termina em %s. Sem decisão, ele renova por seis meses pagando menos." % Fmt.plural(left, "semana", "semanas"), [], "tv", {}, 90 if left <= 2 else 72))
	for ev: FightEvent in Org.upcoming_events(w):
		if ev == night or ev.done:
			continue
		var left := ev.week - w.week
		if left > CARD_WEEKS or left <= 0:
			continue
		var n := Org.event_bouts(w, ev).size()
		if n < ev.slots:
			var how := "O matchmaker completa sozinho quando a noite chegar perto." if w.delegate_cards else "Complete o card ou peça para o matchmaker fechar o que falta."
			out.append(_c("card:%d" % ev.id, "noite", "Matchmaker", "%s tem %d de %d lutas" % [ev.name, n, ev.slots],
				"Faltam %s. %s%s" % [Fmt.plural(left, "semana", "semanas"), "Ainda sem luta principal. " if n == 0 else "", how], [], "org_event", {"id": ev.id},
				64 if left <= 2 else (50 if n == 0 else 44)))
		if left == Venue.LOCK_WEEKS + 1 or left == Venue.LOCK_WEEKS + 2:
			out.append(_c("sede:%d" % ev.id, "noite", "Bilheteria", "Ingressos da %s vão à venda em %s" % [ev.name, Fmt.plural(left - Venue.LOCK_WEEKS, "semana", "semanas")],
				"Depois disso a sede e a arena não mudam mais. Hoje: %s, %s." % [ev.city, Venue.type_name(ev).to_lower()], [], "venue", {"id": ev.id}, 42))
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		var champ := w.fighter(int(w.champions.get(div, -1)))
		var name := Matchmaker.division_name(div, true)
		if champ == null:
			if Org.title_booked(w, div) == null and Titles.booked(w, div) == null:
				out.append(_c("vago:%s" % div, "cinturao", "Matchmaker", "Cinturão vago nos %s" % name,
					"Marque dois dos dez primeiros valendo o título.", [], "book_div", {"div": div}, 55))
			continue
		var it := Titles.interim_of(w, div)
		var out_why := Titles.champion_out(w, div)
		if out_why != "" and it == null and Titles.booked(w, div) == null:
			out.append(_c("interino:%s:%d" % [div, champ.id], "cinturao", "Matchmaker", "%s: campeão fora de combate" % _cap(name),
				"%s. Dá para marcar o cinturão interino entre dois dos oito primeiros." % _cap(out_why), [champ.id], "book_div", {"div": div}, 50))
		elif it != null and out_why == "" and Org.title_booked(w, div) == null:
			out.append(_c("unifica:%s:%d" % [div, it.id], "cinturao", "Matchmaker", "Hora da unificação nos %s" % name,
				"%s voltou e %s é o interino. A próxima disputa de cinturão da categoria é entre os dois." % [champ.short_name(), it.short_name()], [champ.id, it.id], "book_div", {"div": div}, 52))
	if t.balance < 0.0:
		out.append(_c("caixa", "financas", "Financeiro", "Caixa no vermelho: %s" % Fmt.money(t.balance),
			"As noites continuam, mas o prestígio cai. Veja as contas na Organização.", [], "gym", {}, 70))
	return out


# --- Avisos (notícias que dizem respeito ao jogador) ---------------------------------------

static func _import_news(w: GameWorld) -> int:
	var since := w.inbox_news_week
	w.inbox_news_week = w.week
	var have := {}
	for m: Dictionary in w.inbox:
		have[String(m["key"])] = true
	var pres := w.is_president()
	var added := 0
	for n: Dictionary in w.news:
		if int(n["week"]) < since:
			continue
		var kind := String(n.get("kind", ""))
		var text := String(n["text"])
		var ids: Array = n.get("fighters", [])
		var cat := ""
		var from := "Imprensa"
		var mine := false
		for id in ids:
			var f := w.fighter(int(id))
			if f != null and w.is_user_fighter(f):
				mine = true
		if kind == "olheiro":
			cat = "olheiro"
			from = Scouting.scout_name(w)
		elif kind == "premio" or kind == "hall":
			cat = "mundo"
		elif pres:
			if kind == "organizacao":
				cat = "noite"
				from = "Operações"
			elif kind == "tv":
				cat = "tv"
				from = String(TVDeal.partner_of(w).get("name", "TV"))
			elif bool(n.get("important", false)) and kind in ["cinturao", "rivalidade", "aposentadoria"]:
				cat = "cinturao" if kind == "cinturao" else "mundo"
		else:
			if kind == "equipe":
				cat = "equipe"
				from = "Academia"
			elif mine and kind in ["marco", "cinturao", "rivalidade", "resultado", "categoria", "aposentadoria"]:
				cat = "cinturao" if kind == "cinturao" else "luta"
		if cat == "":
			continue
		var skip := false
		for s: String in NEWS_SKIP:
			if text.contains(s):
				skip = true
		var key := "n:%d:%d" % [int(n["week"]), text.hash()]
		if skip or have.has(key):
			continue
		have[key] = true
		var c := _c(key, cat, from, String(NEWS_TITLES.get(kind, "Notícia")), text, ids, "fighter" if not ids.is_empty() else ("tv" if kind == "tv" else "none"),
			{"id": int(ids[0])} if not ids.is_empty() else {}, 10)
		_add(w, c, false)
		(w.inbox.back() as Dictionary)["wk"] = int(n["week"])
		added += 1
	return added
