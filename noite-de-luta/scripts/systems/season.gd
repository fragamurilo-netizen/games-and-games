class_name Season
extends RefCounted
## A temporada do jogador: as três metas do ano, os contadores (do ano e da carreira) e o
## termômetro de quem cobra resultado: a cidade, para a academia; os sócios, para o presidente.
##
## - **Metas** (`GameWorld.goals`): três por ano, uma de ambição esportiva, uma de resultados e
##   uma da casa, sorteadas com semente própria (não mexem no sorteio do mundo) e medidas pelo
##   momento do jogador. Meta de contagem ou de marca paga na hora em que é batida; meta "de
##   fechamento" (caixa, lucro, saldo de vitórias) vale como o ano terminar.
## - **Apoio** (`GameWorld.support`, 0 a 100): sobe e desce com o que o jogador faz, sempre com o
##   motivo guardado (`why`), e volta devagar para 50 quando nada acontece. Alto, rende
##   (patrocínio do comércio, verba de marketing); baixo, cobra (a cidade vira as costas; os
##   sócios dão ultimato, intervêm e, na segunda vez, trocam o mandato).
## - **Virada do ano** (`year_end`): fecha as metas, guarda o balanço em `goals.past`, deixa a
##   cerimônia à espera (`GameWorld.gala`) e sorteia as metas do ano novo.

## Faixas do termômetro.
const LOW := 20.0
const COLD := 40.0
const WARM := 75.0
## Ultimato dos sócios: semanas de prazo e a confiança pedida.
const ULT_WEEKS := 12
const ULT_NEED := 35.0
const LEVELS_CITY := ["De costas para a academia", "Desconfiada", "De olho", "Do seu lado", "A cidade é sua"]
const LEVELS_BOARD := ["Querem a sua saída", "Inquietos", "De olho", "Satisfeitos", "Carta branca"]
const PAST_MAX := 15
## Contadores do ano que ficam guardados no balanço (o resto some na virada).
## Presidente, primeiro ano: os alvos ficam entre o que a liga faz sozinha (matchmaker completando
## os cards, nenhuma disputa de cinturão marcada) e o que um presidente presente consegue.
## Medidos com tools/season_probe.gd; rever quando a economia do presidente for rebalanceada.
const FIRST := {"title_bouts": 10.0, "hot": 12.0, "full": 16.0, "crowd": 450000.0, "ppv": 1600000.0, "profit": 95000000.0}
const KEEP := ["fights", "wins", "losses", "draws", "fin", "belts", "defs", "title_fights", "purse", "sponsor",
	"nights", "canceled", "profit", "crowd", "sold", "hot", "ppv", "title_bouts", "new_champs", "full"]


# --- Nomes -------------------------------------------------------------------------------

static func meter_name(w: GameWorld) -> String:
	return "Confiança dos sócios" if w.is_president() else "Apoio da cidade"


static func meter_short(w: GameWorld) -> String:
	return "Sócios" if w.is_president() else "Cidade"


## 0 (crise) a 4 (no auge).
static func level(v: float) -> int:
	if v < LOW:
		return 0
	if v < COLD:
		return 1
	if v < 60.0:
		return 2
	if v < WARM:
		return 3
	return 4


static func level_name(w: GameWorld, v: float) -> String:
	return String((LEVELS_BOARD if w.is_president() else LEVELS_CITY)[level(v)])


static func value_of(w: GameWorld) -> float:
	return float(w.support.get("v", 50.0))


## Quanto mudou nas últimas quatro semanas.
static func trend(w: GameWorld) -> float:
	var log: Array = w.support.get("log", [])
	if log.size() < 2:
		return 0.0
	return value_of(w) - float(log[maxi(0, log.size() - 5)])


# --- Começo e contadores -----------------------------------------------------------------

## Cria o que faltar (carreira nova ou save de antes das metas).
static func ensure(w: GameWorld) -> void:
	var t := w.user_team()
	if t == null:
		return
	if w.support.is_empty():
		w.support = {"v": 50.0 if w.is_president() else 42.0, "log": [], "why": [], "low": 0, "ult": {}, "strikes": 0, "terms": 1}
	if w.goals.is_empty():
		w.goals = {"year": w.year(), "c": {}, "past": [], "v0": value_of(w), "cash0": t.balance, "rep0": t.reputation}
		w.goals["items"] = _pick(w, w.year())


static func c(w: GameWorld, key: String) -> float:
	return float((w.goals.get("c", {}) as Dictionary).get(key, 0.0))


static func life(w: GameWorld, key: String) -> float:
	return float(w.life.get(key, 0.0))


## Soma no ano e na carreira.
static func bump(w: GameWorld, key: String, n: float = 1.0) -> void:
	if w.goals.is_empty():
		return
	var cc: Dictionary = w.goals["c"]
	cc[key] = float(cc.get(key, 0.0)) + n
	w.life[key] = float(w.life.get(key, 0.0)) + n


## Guarda o maior valor já visto (no ano e na carreira).
static func peak(w: GameWorld, key: String, v: float) -> void:
	if w.goals.is_empty():
		return
	var cc: Dictionary = w.goals["c"]
	cc[key] = maxf(float(cc.get(key, 0.0)), v)
	w.life[key] = maxf(float(w.life.get(key, 0.0)), v)


## Fila do que a interface ainda vai comemorar.
static func pop(w: GameWorld, kind: String, title: String, text: String) -> void:
	w.pops.append({"k": kind, "t": title, "x": text})
	if w.pops.size() > 12:
		w.pops = w.pops.slice(w.pops.size() - 12)


# --- Termômetro --------------------------------------------------------------------------

## Mexe no termômetro e guarda o motivo. Motivos com a mesma etiqueta nas últimas semanas se
## somam numa linha só (o semanal não enche a lista).
static func nudge(w: GameWorld, d: float, why: String, tag: String = "") -> void:
	if w.support.is_empty() or is_zero_approx(d):
		return
	var s := w.support
	s["v"] = clampf(float(s["v"]) + d, 0.0, 100.0)
	var log: Array = s["why"]
	if tag != "":
		# A linha soma até oito semanas do mesmo motivo; depois disso começa outra.
		for i in range(log.size() - 1, maxi(-1, log.size() - 8), -1):
			var e: Array = log[i]
			var first := int(e[4]) if e.size() > 4 else int(e[0])
			if String(e[3]) == tag and w.week - first < 8:
				log.remove_at(i)
				log.append([w.week, float(e[1]) + d, why, tag, first])
				return
	log.append([w.week, d, why, tag, w.week])
	if log.size() > 18:
		s["why"] = log.slice(log.size() - 18)


## Motivos recentes, do mais novo para o mais velho: [[semana, variação, texto]].
static func reasons(w: GameWorld, limit: int = 8) -> Array:
	var log: Array = (w.support.get("why", []) as Array).duplicate()
	log.reverse()
	var out: Array = []
	for e: Array in log:
		if absf(float(e[1])) >= 0.25:
			out.append(e)
		if out.size() >= limit:
			break
	return out


## Academia: patrocínio do comércio local por semana (só com a cidade do lado).
static func sponsor(w: GameWorld) -> float:
	var t := w.user_team()
	if t == null or w.is_president() or w.support.is_empty():
		return 0.0
	var v := value_of(w)
	if v < COLD or bool(w.support.get("cut", false)):
		return 0.0
	return snappedf((v - COLD) / 60.0 * (1200.0 + t.reputation * 60.0), 50.0)


## Presidente: verba de marketing liberada (ou segurada) pelos sócios, no hype das noites.
static func hype_bonus(w: GameWorld) -> Array:
	if not w.is_president() or w.support.is_empty():
		return ["", 0.0]
	var v := value_of(w)
	if v >= WARM:
		return ["Sócios liberaram verba de marketing", 3.0]
	if v < LOW:
		return ["Sócios seguraram a verba de marketing", -2.0]
	return ["", 0.0]


## Academia: lutador da terra assina mais fácil com a cidade do lado (e foge com ela de costas).
static func sign_bonus(w: GameWorld, f: Fighter) -> float:
	var t := w.user_team()
	if t == null or w.is_president() or w.support.is_empty():
		return 0.0
	if bool(w.support.get("cut", false)):
		return -0.08
	if value_of(w) >= WARM and f.nation == t.nation:
		return 0.08
	return 0.0


## O que o nível atual rende ou custa, em uma frase.
static func perk_text(w: GameWorld) -> String:
	var v := value_of(w)
	if w.is_president():
		if not (w.support.get("ult", {}) as Dictionary).is_empty():
			var ult: Dictionary = w.support["ult"]
			return "Ultimato: a confiança precisa estar em %d ou mais em %s." % [int(ULT_NEED), Fmt.plural(maxi(0, int(ult["until"]) - w.week), "semana", "semanas")]
		if v >= WARM:
			return "Verba de marketing liberada: +3 de hype em toda noite."
		if v < LOW:
			return "Verba de marketing segurada: −2 de hype em toda noite. Três semanas assim e vem o ultimato."
		if v < COLD:
			return "Abaixo de %d por três semanas, os sócios dão um ultimato." % int(LOW)
		return "Acima de %d os sócios liberam verba de marketing." % int(WARM)
	if bool(w.support.get("cut", false)):
		return "O comércio local retirou o patrocínio. Ele volta com o apoio em %d." % int(COLD)
	var sp := sponsor(w)
	if v >= WARM:
		return "Patrocínio local de %s por semana, e os lutadores da terra querem assinar." % Fmt.money(sp)
	if sp > 0.0:
		return "Patrocínio local de %s por semana. Cresce com o apoio e com a reputação." % Fmt.money(sp)
	return "Sem patrocínio local. Ele começa com o apoio em %d." % int(COLD)


# --- Ganchos do mundo --------------------------------------------------------------------

## Depois de cada luta resolvida (`Career.resolve`).
static func on_bout(w: GameWorld, b: Bout, winner_id: int, method: String, ra: int, rb: int, champ_before: int) -> void:
	if w.goals.is_empty():
		return
	var ev := w.event(b.event_id)
	var tier := ev.tier if ev != null else 0
	var finish := method in ["KO", "TKO", "FIN"]
	if w.is_president():
		if tier != 2:
			return
		bump(w, "fights")
		if finish:
			bump(w, "fin")
		if b.title:
			bump(w, "title_bouts")
			if winner_id >= 0 and champ_before != winner_id and int(w.champions.get(b.division, -1)) == winner_id:
				bump(w, "new_champs")
		check(w)
		return
	var t := w.user_team()
	var any := false
	for i in 2:
		var f := w.fighter(b.a if i == 0 else b.b)
		if f == null or not w.is_user_fighter(f):
			continue
		any = true
		var o := w.fighter(b.b if i == 0 else b.a)
		var r_me := ra if i == 0 else rb
		var r_opp := rb if i == 0 else ra
		var k: float = [1.0, 1.4, 1.8][clampi(tier, 0, 2)]
		var home := 1.25 if f.nation == t.nation else 1.0
		bump(w, "fights")
		if tier == 2:
			bump(w, "t2_fights")
		if b.main_event:
			bump(w, "main")
		if b.title:
			bump(w, "title_fights")
		w.support["last_fight"] = w.week
		if winner_id < 0:
			bump(w, "draws")
		elif winner_id == f.id:
			bump(w, "wins")
			if tier == 2:
				bump(w, "t2_wins")
			if finish:
				bump(w, "fin")
				bump(w, "ko" if method != "FIN" else "sub")
				if int(b.result.get("round", 9)) == 1:
					bump(w, "r1")
			if r_opp >= 0 and r_opp <= 30 and (r_me < 0 or r_me - r_opp >= 10) and not b.title:
				bump(w, "upsets")
			peak(w, "streak", float(f.streak))
			var d := (1.6 + (0.8 if finish else 0.0)) * k * home
			var why := "%s venceu %s" % [f.short_name(), o.short_name()]
			if b.title and int(w.champions.get(b.division, -1)) == f.id:
				if champ_before == f.id:
					bump(w, "defs")
					d += 4.0
					why = "%s defendeu o cinturão" % f.short_name()
				else:
					bump(w, "belts")
					d += 9.0
					why = "%s é campeão do mundo" % f.short_name()
			elif b.interim:
				d += 3.0
			nudge(w, d, why)
		else:
			bump(w, "losses")
			nudge(w, -1.0 * k - (2.0 if b.title and champ_before == f.id else 0.0), "%s perdeu para %s" % [f.short_name(), o.short_name()])
	if any:
		check(w)


## Presidente: depois de fechar (ou cancelar) uma noite da liga (`Org.close_event`).
static func on_night(w: GameWorld, ev: FightEvent, canceled: bool = false) -> void:
	if w.goals.is_empty() or not w.is_president():
		return
	var r := ev.report
	var profit := float(r.get("profit", 0.0))
	bump(w, "profit", profit)
	if canceled:
		bump(w, "canceled")
		nudge(w, -8.0, "%s cancelada" % ev.name)
		return
	var crowd := float(r.get("crowd", 0))
	var cap := maxf(1.0, float(r.get("capacity", 1)))
	var draw := float(r.get("draw", 0.0))
	var fill := crowd / cap
	bump(w, "nights")
	bump(w, "crowd", crowd)
	bump(w, "ppv", float(r.get("ppv_buys", 0)))
	peak(w, "ppv_best", float(r.get("ppv_buys", 0)))
	peak(w, "gate_best", float(r.get("gate", 0.0)))
	peak(w, "hype_best", draw)
	peak(w, "crowd_best", crowd)
	if fill >= 0.98:
		bump(w, "sold")
	if draw >= 70.0:
		bump(w, "hot")
	if draw >= 85.0:
		bump(w, "fire")
	if Card.bouts(w, ev).size() >= ev.slots:
		bump(w, "full")
	# Confiança: os sócios se acostumam. Vale o lucro e o hype contra a média das últimas noites
	# do mesmo tipo (numerada ou Fight Night); casa vazia e prejuízo pesam sempre.
	var sum_p := 0.0
	var sum_d := 0.0
	var n := 0
	for e: FightEvent in Org.past_events(w):
		if e.id == ev.id or e.ppv != ev.ppv or int(e.report.get("crowd", 0)) <= 0:
			continue
		sum_p += float(e.report.get("profit", 0.0))
		sum_d += float(e.report.get("draw", 0.0))
		n += 1
		if n >= 6:
			break
	var d := 0.0
	var notes: Array = []
	if profit < 0.0:
		d -= 2.5
		notes.append("prejuízo")
	if n >= 2:
		var rel := clampf((profit - sum_p / n) / maxf(absf(sum_p / n), 300000.0), -1.0, 1.0)
		d += rel * 2.0
		if rel >= 0.2:
			notes.append("lucro acima das últimas noites")
		elif rel <= -0.2 and profit >= 0.0:
			notes.append("lucro abaixo das últimas noites")
		var rel_h := clampf((draw - sum_d / n) / 12.0, -1.0, 1.0)
		d += rel_h * 1.5
		if rel_h >= 0.3:
			notes.append("card mais quente que os últimos")
		elif rel_h <= -0.3:
			notes.append("card mais frio que os últimos")
	else:
		d += clampf((draw - 60.0) / 15.0, -1.0, 1.0)
	if draw >= 85.0:
		d += 0.5
		notes.append("noite pegando fogo")
	if fill < 0.6:
		d -= 2.0
		notes.append("arena vazia")
	elif fill < 0.85:
		d -= 0.8
		notes.append("lugares sobrando")
	nudge(w, d, "%s: %s" % [ev.name, ", ".join(notes) if not notes.is_empty() else "noite dentro do esperado"])
	check(w)


## Empresário dispensou um lutador conhecido: a torcida sente.
static func on_release(w: GameWorld, f: Fighter) -> void:
	if w.is_president() or w.support.is_empty():
		return
	if f.popularity >= 45.0:
		nudge(w, -1.0 - (f.popularity - 45.0) / 12.0, "%s foi dispensado" % f.short_name())


# --- Semana ------------------------------------------------------------------------------

## Fim de cada semana (`Career.advance_week`), antes da caixa de entrada.
static func week(w: GameWorld) -> void:
	ensure(w)
	if w.support.is_empty():
		return
	var s := w.support
	# Mandato encerrado e ninguém decidiu (o jogo andou sozinho): o mandato novo começa.
	if s.has("fired") and w.week - int(s["fired"]) >= 1:
		new_term(w)
	# Sem novidade, o termômetro volta devagar para o meio.
	s["v"] = float(s["v"]) + (50.0 - float(s["v"])) * 0.012
	if w.is_president():
		_week_board(w)
	else:
		_week_city(w)
	var log: Array = s["log"]
	log.append(snappedf(float(s["v"]), 0.1))
	if log.size() > 26:
		s["log"] = log.slice(log.size() - 26)
	_pressure(w)
	check(w)


static func _week_city(w: GameWorld) -> void:
	var t := w.user_team()
	var mine := w.user_fighters()
	if mine.is_empty():
		if w.week >= 6:
			nudge(w, -0.4, "Academia sem lutadores", "vazia")
	else:
		var idle := w.week - int(w.support.get("last_fight", 0))
		if idle >= 10:
			nudge(w, -0.5, "Academia fora das noites de luta há %d semanas" % idle, "parada")
		var champs := 0
		for f: Fighter in mine:
			if w.rank_of(f) == 0:
				champs += 1
		if champs > 0:
			nudge(w, minf(0.6, 0.3 * champs), "Campeão do mundo em casa", "campeao")
	if t.balance < 0.0:
		nudge(w, -0.25, "Academia devendo na praça", "caixa")


static func _week_board(w: GameWorld) -> void:
	var t := w.user_team()
	# Cinturão vago há mais de seis semanas, sem disputa marcada: os sócios cobram.
	if not w.support.has("vac"):
		w.support["vac"] = {}
	var vac: Dictionary = w.support["vac"]
	var vacant := 0
	for d: Dictionary in DataDB.divisions():
		var div := String(d["id"])
		if int(w.champions.get(div, -1)) < 0 and Titles.booked(w, div) == null:
			if not vac.has(div):
				vac[div] = w.week
			elif w.week - int(vac[div]) >= 6:
				vacant += 1
		else:
			vac.erase(div)
	if vacant > 0:
		nudge(w, -minf(0.36, 0.12 * vacant), "Cinturão vago sem disputa marcada", "vago")
	if t.balance < 0.0:
		nudge(w, -1.5, "Caixa no vermelho", "caixa")
	var n := t.rep_log.size()
	if n >= 5:
		var d := t.reputation - float(t.rep_log[n - 5])
		if absf(d) >= 0.8:
			nudge(w, clampf(d * 0.25, -0.6, 0.6), "Prestígio da liga %s" % ("subindo" if d > 0.0 else "caindo"), "prestigio")


## Mudança de faixa, a cidade de costas e o ultimato dos sócios.
static func _pressure(w: GameWorld) -> void:
	var s := w.support
	var t := w.user_team()
	var v := float(s["v"])
	var pres := w.is_president()
	var lv := level(v)
	var old := int(s.get("lv", lv))
	s["lv"] = lv
	if lv != old and (lv == 4 or lv == 1 or lv == 0 or (lv == 3 and old < 3)):
		var name := level_name(w, v).to_lower()
		if pres:
			w.add_news("apoio", "Confiança dos sócios em %d: %s." % [int(round(v)), name], [], lv <= 1 or lv == 4)
		else:
			w.add_news("apoio", "Apoio da cidade em %d: %s." % [int(round(v)), name], [], lv <= 1 or lv == 4)
	s["low"] = int(s.get("low", 0)) + 1 if v < LOW else 0
	if not pres:
		if int(s["low"]) >= 3 and not bool(s.get("cut", false)):
			s["cut"] = true
			t.reputation = maxf(1.0, t.reputation - 3.0)
			w.add_news("apoio", "A cidade virou as costas para a %s: o comércio local retirou o patrocínio e a academia perdeu nome." % t.name, [], true)
		elif bool(s.get("cut", false)) and v >= COLD:
			s["cut"] = false
			w.add_news("apoio", "A cidade voltou a apoiar a %s: o patrocínio local está de volta." % t.name, [], true)
		return
	var ult: Dictionary = s.get("ult", {})
	if not ult.is_empty():
		if w.week >= int(ult["until"]):
			if v >= float(ult["need"]):
				s["ult"] = {}
				w.add_news("apoio", "Os sócios retiraram o ultimato: a confiança voltou a %d." % int(round(v)), [], true)
			else:
				_strike(w)
		elif v >= float(ult["need"]) + 10.0:
			s["ult"] = {}
			w.add_news("apoio", "Os sócios retiraram o ultimato antes do prazo: a confiança chegou a %d." % int(round(v)), [], true)
	elif int(s["low"]) >= 3 and not s.has("fired"):
		s["ult"] = {"until": w.week + ULT_WEEKS, "need": ULT_NEED, "from": w.week}
		w.add_news("apoio", "Ultimato dos sócios: a confiança precisa voltar a %d em %d semanas. Sem isso, eles intervêm na %s." % [int(ULT_NEED), ULT_WEEKS, t.name], [], true)


## Ultimato vencido: na primeira vez os sócios intervêm; na segunda, encerram o mandato.
static func _strike(w: GameWorld) -> void:
	var s := w.support
	var t := w.user_team()
	s["ult"] = {}
	s["low"] = 0
	s["strikes"] = int(s.get("strikes", 0)) + 1
	if int(s["strikes"]) == 1:
		var fee := snappedf(maxf(1000000.0, t.balance * 0.15), 10000.0) if t.balance > 0.0 else 0.0
		if fee > 0.0:
			t.add_money(w.week, "Intervenção dos sócios: dividendos extraordinários", -fee)
		t.reputation = maxf(1.0, t.reputation - 6.0)
		s["v"] = 42.0
		s["event"] = {"k": "interv", "week": w.week, "fee": fee}
		w.life["interv"] = float(w.life.get("interv", 0.0)) + 1.0
		w.add_news("apoio", "Intervenção na %s: o ultimato venceu e os sócios retiraram %s do caixa. Mais um ultimato perdido encerra o seu mandato." % [t.name, Fmt.money(fee)], [], true)
	else:
		s["fired"] = w.week
		s["event"] = {"k": "fired", "week": w.week}
		w.add_news("apoio", "Os sócios votaram pela sua saída da presidência da %s." % t.name, [], true)


static func fired(w: GameWorld) -> bool:
	return w.support.has("fired")


## Aviso que a interface ainda não mostrou (intervenção ou fim de mandato): {k, week, fee}.
static func event(w: GameWorld) -> Dictionary:
	return w.support.get("event", {})


static func clear_event(w: GameWorld) -> void:
	w.support.erase("event")


## Mandato novo: outro grupo compra a parte dos sócios antigos e mantém o presidente. O caixa
## volta ao mínimo de uma liga (ou perde um quarto, se estava cheio) e o prestígio sai arranhado.
static func new_term(w: GameWorld) -> void:
	var s := w.support
	var t := w.user_team()
	s.erase("fired")
	s.erase("event")
	s["strikes"] = 0
	s["terms"] = int(s.get("terms", 1)) + 1
	s["v"] = 50.0
	s["low"] = 0
	s["ult"] = {}
	var floor_cash: float = Org.START_FUNDS[0]
	if t.balance < floor_cash:
		t.add_money(w.week, "Aporte dos novos sócios", floor_cash - t.balance)
	else:
		t.add_money(w.week, "Saída dos antigos sócios", -snappedf(t.balance * 0.25, 10000.0))
	t.reputation = maxf(1.0, t.reputation - 8.0)
	w.life["terms"] = float(s["terms"])
	w.add_news("apoio", "Novo mandato na %s: outro grupo de investidores comprou a parte dos antigos sócios e manteve você na presidência." % t.name, [], true)


# --- Metas -------------------------------------------------------------------------------

static func items(w: GameWorld) -> Array:
	return w.goals.get("items", [])


static func _g(key: String, title: String, text: String, n: float, mode: String, money: float, rep: float, base: float = 0.0) -> Dictionary:
	return {"k": key, "t": title, "x": text, "n": n, "m": mode, "money": snappedf(money, 500.0), "rep": rep, "done": -1, "b": base}


## Valor de agora da medida de uma meta.
static func value(w: GameWorld, g: Dictionary) -> float:
	var t := w.user_team()
	match String(g["k"]):
		"rank":
			var best := 999
			for f: Fighter in w.user_fighters():
				var r := w.rank_of(f)
				if r >= 0:
					best = mini(best, r)
			return float(best)
		"rep":
			return t.reputation
		"cash":
			return t.balance
		"roster":
			return float(w.user_fighters().size())
		"streak":
			var s := 0
			for f: Fighter in w.user_fighters():
				s = maxi(s, f.streak)
			return float(s)
		"pos":
			return c(w, "wins") - c(w, "losses")
	return c(w, String(g["k"]))


## Estrelas da liga: lutadores da elite com fama de 75 para cima.
static func stars(w: GameWorld, min_pop: float = 75.0) -> int:
	var n := 0
	for f: Fighter in w.fighters.values():
		if not f.retired and f.popularity >= min_pop and Org.eligible(w, f):
			n += 1
	return n


static func _num(key: String, v: float) -> String:
	if key in ["cash", "profit", "purse"]:
		return Fmt.money(v)
	if key in ["crowd", "ppv"]:
		return _short(v)
	return str(int(floor(v + 0.001)))


## Número grande em poucas letras: 1,8 mi, 450 mil, 8.200.
static func _short(v: float) -> String:
	if v >= 1000000.0:
		return "%s mi" % Fmt.dec(v / 1000000.0, 1 if fmod(v, 1000000.0) >= 50000.0 else 0)
	if v >= 10000.0:
		return "%d mil" % int(round(v / 1000.0))
	return Fmt.thousands(int(round(v)))


## Andamento de uma meta: {ok, frac (0 a 1), text, final (já decidida), hold (vale no fim do ano)}.
static func progress(w: GameWorld, g: Dictionary) -> Dictionary:
	var key := String(g["k"])
	var mode := String(g["m"])
	var n := float(g["n"])
	var done := int(g.get("done", -1)) >= 0
	var val := value(w, g)
	if key == "rank":
		var ok := done or val <= n
		var base := float(g.get("b", 60.0))
		var now := "campeão" if val <= 0.0 else ("#%d" % int(val) if val < 900.0 else "sem ranking")
		return {"ok": ok, "frac": 1.0 if ok else clampf((base - val) / maxf(1.0, base - n), 0.0, 0.95), "text": "Melhor hoje: %s" % now, "final": done, "hold": false}
	if mode == "h":
		var base2 := float(g.get("b", 0.0))
		var span := n - base2
		var fr := clampf((val - base2) / span, 0.0, 1.0) if span > 0.0 else (1.0 if val >= n else 0.0)
		if key == "pos":
			return {"ok": val >= n, "frac": 1.0 if val >= n else 0.0, "text": "%d %s e %d %s" % [int(c(w, "wins")), "vitória" if int(c(w, "wins")) == 1 else "vitórias", int(c(w, "losses")), "derrota" if int(c(w, "losses")) == 1 else "derrotas"], "final": false, "hold": true}
		return {"ok": val >= n, "frac": fr, "text": "%s de %s" % [_num(key, val), _num(key, n)], "final": false, "hold": true}
	var ok2 := done or val >= n
	return {"ok": ok2, "frac": 1.0 if ok2 else clampf(val / maxf(0.001, n), 0.0, 1.0), "text": "%s de %s" % [_num(key, n if ok2 else val), _num(key, n)], "final": done, "hold": false}


static func reward_text(w: GameWorld, g: Dictionary) -> String:
	var parts: Array = []
	if float(g.get("money", 0.0)) > 0.0:
		parts.append(Fmt.money(float(g["money"])))
	if float(g.get("rep", 0.0)) > 0.0:
		parts.append("+%d de %s" % [int(g["rep"]), "prestígio" if w.is_president() else "reputação"])
	parts.append("+%d %s" % [int(sup_gain(w)), "de confiança" if w.is_president() else "de apoio"])
	return ", ".join(parts)


static func sup_gain(_w: GameWorld) -> float:
	return 6.0


static func sup_loss(w: GameWorld) -> float:
	return 5.0 if w.is_president() else 3.0


## Confere as metas de contagem e de marca: a que acabou de ser batida paga na hora.
static func check(w: GameWorld) -> void:
	if w.goals.is_empty():
		return
	for g: Dictionary in items(w):
		if int(g.get("done", -1)) >= 0 or String(g["m"]) == "h":
			continue
		if bool(progress(w, g)["ok"]):
			g["done"] = w.week
			_reward(w, g)


static func _reward(w: GameWorld, g: Dictionary) -> void:
	var t := w.user_team()
	var money := float(g.get("money", 0.0))
	if money > 0.0:
		t.add_money(w.week, "Meta cumprida: %s" % String(g["t"]), money)
	t.reputation = clampf(t.reputation + float(g.get("rep", 0.0)), 1.0, 100.0)
	w.life["goals_met"] = float(w.life.get("goals_met", 0.0)) + 1.0
	nudge(w, sup_gain(w), "Meta cumprida: %s" % String(g["t"]))
	w.add_news("meta", "Meta cumprida: %s. Recompensa: %s." % [String(g["t"]), reward_text(w, g)], [], true)
	pop(w, "goal", "Meta cumprida", String(g["t"]))


# --- Sorteio das metas -------------------------------------------------------------------

## As três metas do ano. `frac` encolhe as contagens quando o ano já está andando (save antigo).
static func _pick(w: GameWorld, year: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([w.seed, year, "metas"])
	var week_of_year := 0
	while week_of_year < 53 and w.week - week_of_year - 1 >= 0 and int(GameWorld.date_of(w.week - week_of_year - 1)["year"]) == year:
		week_of_year += 1
	var frac := clampf(1.0 - week_of_year / 52.0, 0.25, 1.0)
	var last: Dictionary = {}
	var past: Array = w.goals.get("past", [])
	if not past.is_empty():
		last = past.back()
	var out: Array = _pick_president(w, r, frac, last) if w.is_president() else _pick_manager(w, r, frac, last)
	for i in out.size():
		(out[i] as Dictionary)["slot"] = i
	return out


static func _last_keys(last: Dictionary) -> Array:
	var keys: Array = []
	for it: Dictionary in last.get("items", []):
		keys.append(String(it.get("k", "")))
	return keys


## Escolhe uma das opções, evitando repetir a meta do ano passado quando há outra.
static func _choose(r: RandomNumberGenerator, opts: Array, avoid: Array) -> Dictionary:
	var fresh := opts.filter(func(g: Dictionary) -> bool: return not avoid.has(String(g["k"])))
	var pool := fresh if not fresh.is_empty() else opts
	return pool[r.randi_range(0, pool.size() - 1)]


static func _count(n: float, frac: float, lo: float = 1.0) -> float:
	return maxf(lo, round(n * frac))


static func _pick_manager(w: GameWorld, r: RandomNumberGenerator, frac: float, last: Dictionary) -> Array:
	var t := w.user_team()
	var mine := w.user_fighters()
	var n := mine.size()
	var best := 999
	var champs := 0
	var top := 0
	for f: Fighter in mine:
		var rk := w.rank_of(f)
		if rk == 0:
			champs += 1
		if rk >= 0:
			best = mini(best, rk)
		if rk >= 0 and rk <= Rankings.lgc_size(f.division):
			top += 1
	var rep := t.reputation
	var prize := 4000.0 + rep * 320.0
	var avoid := _last_keys(last)
	var out: Array = []
	# 1. Ambição esportiva: o próximo degrau do melhor lutador da casa.
	if champs > 0:
		out.append(_g("defs", "Defender o cinturão", "Seu campeão precisa vencer uma disputa de cinturão até o fim do ano.", 1.0, "c", prize * 2.0, 2.0))
	elif best > 900:
		# Academia sem ninguém no ranking: o primeiro passo é aparecer nas noites de luta.
		var nf := _count(4.0, frac, 2.0)
		out.append(_g("fights", "Fazer %d lutas no ano" % int(nf), "Colocar a academia nas noites de luta: cada luta dá bolsa, ritmo e nome.", nf, "c", prize * 1.5, 2.0))
	else:
		var rung := 0
		for x: int in [80, 70, 60, 55, 50, 45, 40, 36, 32, 28, 24, 20, 16, 13, 10, 8, 5, 3]:
			if float(x) <= best * 0.9 or (best > 100 and x == 80):
				rung = x
				break
		if rung > 0:
			out.append(_g("rank", "Colocar um lutador no top %d" % rung, "Um lutador da academia entre os %d primeiros da categoria em qualquer momento do ano." % rung, float(rung), "r", prize * (1.5 + maxf(0.0, 40.0 - rung) / 40.0), 2.0, float(mini(best, 110))))
		else:
			out.append(_g("title_fights", "Disputar um cinturão", "Leve um lutador da academia a uma disputa de cinturão neste ano.", 1.0, "c", prize * 2.5, 3.0))
	# 2. Resultados: vitórias, finalizações, sequência ou saldo, pelo tamanho da equipe.
	var team := maxi(n, 2)
	var wins := _count(clampf(team * 1.15, 2.0, 14.0), frac, 1.0)
	var opts: Array = [
		_g("wins", "Vencer %s" % Fmt.plural(int(wins), "luta", "lutas"), "Vitórias dos lutadores da academia no ano, em qualquer evento.", wins, "c", prize * 1.2, 1.0),
		_g("fin", "Vencer %d antes do fim" % int(_count(maxf(1.0, wins * 0.5), 1.0)), "Vitórias por nocaute ou finalização: o público lembra de quem resolve.", _count(maxf(1.0, wins * 0.5), 1.0), "c", prize * 1.2, 1.0),
	]
	if n >= 2:
		opts.append(_g("pos", "Mais vitórias que derrotas no ano", "Vale o saldo das lutas da academia quando o ano terminar.", 1.0, "h", prize, 1.0))
	if n >= 1 and frac >= 0.6:
		opts.append(_g("streak", "Emplacar três vitórias seguidas", "Um lutador da academia com três vitórias em sequência.", 3.0, "r", prize * 1.3, 1.0))
	out.append(_choose(r, opts, avoid))
	# 3. A casa: equipe, nome ou caixa.
	var weekly := Career.RENT + Career.PER_FIGHTER * n + t.weekly_wages()
	var house: Array = []
	if n < 3:
		house.append(_g("roster", "Ter %d lutadores na equipe" % (n + 2 if n > 0 else 3), "Equipe maior luta mais vezes, e cada bolsa ajuda a pagar a academia.", float(n + 2 if n > 0 else 3), "r", prize * 0.8, 1.0))
	else:
		var rep_goal := floorf(rep + clampf(9.0 - rep / 11.0, 3.0, 8.0))
		if rep_goal <= 96.0:
			house.append(_g("rep", "Chegar a %d de reputação" % int(rep_goal), "A reputação sobe com vitórias em eventos grandes e abre portas no mercado.", rep_goal, "r", prize, 0.0))
		var cash_goal := snappedf(t.balance - weekly * 52.0 * frac * 0.6, 5000.0)
		if cash_goal >= 20000.0:
			house.append(_g("cash", "Virar o ano com %s em caixa" % Fmt.money(cash_goal), "Vale o caixa quando o ano terminar: a academia precisa se pagar.", cash_goal, "h", prize, 1.0, minf(0.0, t.balance - weekly * 52.0 * frac)))
		var purse_goal := snappedf(maxf(8000.0, float((last.get("c", {}) as Dictionary).get("purse", 0.0)) * 1.15) * frac, 1000.0)
		house.append(_g("purse", "Faturar %s em bolsas" % Fmt.money(purse_goal), "A fatia da academia nas bolsas do ano. Evento maior e luta de cinturão pagam muito mais.", purse_goal, "c", prize, 1.0))
		if top == 0 and best <= 45:
			house.append(_g("t2_fights", "Estrear na Liga Global", "Um lutador da academia numa noite da liga de elite.", 1.0, "c", prize * 1.5, 2.0))
	out.append(_choose(r, house, avoid))
	return out


## Alvo de contagem do presidente: o do primeiro ano, ou o do ano passado com um pouco mais,
## sem passar do que cabe no calendário.
static func _grow(last: float, first: float, cap: float, k: float) -> float:
	if last <= 0.0:
		return first
	return clampf(ceilf(last * k), ceilf(first * 0.8), cap)


## Média do contador nos últimos anos fechados (até três): um ano fora da curva, para cima ou
## para baixo, não vira sozinho a régua do ano seguinte.
static func _base(w: GameWorld, key: String) -> float:
	var past: Array = w.goals.get("past", [])
	var sum := 0.0
	var n := 0
	for i in range(past.size() - 1, maxi(-1, past.size() - 4), -1):
		var c: Dictionary = (past[i] as Dictionary).get("c", {})
		if c.has(key):
			sum += float(c[key])
			n += 1
	return sum / n if n > 0 else 0.0


static func _pick_president(w: GameWorld, r: RandomNumberGenerator, frac: float, last: Dictionary) -> Array:
	var t := w.user_team()
	var rep := t.reputation
	var divs := DataDB.divisions().size()
	var prize := 400000.0 + rep * 12000.0
	var avoid := _last_keys(last)
	# Os sócios pedem um pouco mais que a média recente; no topo do prestígio, manter o nível.
	var k := 0.97 if rep >= 95.0 else 1.03
	var out: Array = []
	# 1. O esporte: cinturões em jogo e noites quentes.
	var belts := _count(_grow(_base(w, "title_bouts"), float(FIRST["title_bouts"]), divs * 1.5, k), frac, 2.0)
	var hot := _count(_grow(_base(w, "hot"), float(FIRST["hot"]), 20.0, k), frac, 2.0)
	out.append(_choose(r, [
		_g("title_bouts", "Promover %d disputas de cinturão" % int(belts), "Cinturão em jogo vende a noite e mantém as categorias andando. O matchmaker não marca disputa sozinho.", belts, "c", prize, 1.0),
		_g("hot", "Fazer %d noites quentes" % int(hot), "Noites com hype de 70 para cima: luta principal de nome, rivalidade, cinturão.", hot, "c", prize * 1.2, 2.0),
	], avoid))
	# 2. O público: arenas, cards completos, pay-per-view.
	var full := _count(_grow(_base(w, "full"), float(FIRST["full"]), 22.0, k), frac, 4.0)
	var crowd_goal := snappedf(_grow(_base(w, "crowd"), float(FIRST["crowd"]), 900000.0, k) * frac, 5000.0)
	var ppv_goal := snappedf(_grow(_base(w, "ppv"), float(FIRST["ppv"]), 30000000.0, k) * frac, 10000.0)
	out.append(_choose(r, [
		_g("crowd", "Levar %s pessoas às arenas" % _short(crowd_goal), "A soma do público das noites do ano. Card quente pede arena maior; card morno em arena grande fica vazio.", crowd_goal, "c", prize, 1.0),
		_g("full", "Fazer %d noites de card completo" % int(full), "Todas as vagas do card preenchidas na hora da noite.", full, "c", prize * 0.8, 1.0),
		_g("ppv", "Vender %s de pay-per-view" % _short(ppv_goal), "A soma das compras dos eventos numerados do ano.", ppv_goal, "c", prize * 1.2, 1.0),
	], avoid))
	# 3. A casa: lucro ou prestígio.
	var house: Array = []
	var profit_last := _base(w, "profit")
	var profit_goal := snappedf((maxf(profit_last * k, float(FIRST["profit"]) * 0.9) if profit_last > 0.0 else float(FIRST["profit"])) * frac, 500000.0)
	house.append(_g("profit", "Lucrar %s com as noites" % Fmt.money(profit_goal), "A soma do resultado de todas as noites da liga. Vale como o ano terminar.", profit_goal, "h", prize, 1.0))
	if rep < 93.0:
		var rep_goal := floorf(rep + clampf(6.0 - rep / 20.0, 2.0, 5.0) * maxf(0.5, frac))
		house.append(_g("rep", "Chegar a %d de prestígio" % int(rep_goal), "O prestígio cresce com noites cheias de estrelas e de finalizações, e cai com cards vazios.", rep_goal, "r", prize, 0.0))
	out.append(_choose(r, house, avoid))
	return out


# --- Virada do ano -----------------------------------------------------------------------

## Fecha a temporada: metas de fechamento, balanço, cerimônia à espera e metas do ano novo.
## Chamado depois de `Legacy.year_end` (os prêmios do ano já existem).
static func year_end(w: GameWorld, year: int) -> void:
	ensure(w)
	if w.goals.is_empty():
		return
	var t := w.user_team()
	var pres := w.is_president()
	var res: Array = []
	var met := 0
	for g: Dictionary in items(w):
		var p := progress(w, g)
		var ok := bool(p["ok"])
		if ok and int(g.get("done", -1)) < 0:
			g["done"] = w.week
			_reward(w, g)
		if ok:
			met += 1
		else:
			nudge(w, -sup_loss(w), "Meta perdida: %s" % String(g["t"]))
		res.append({"k": g["k"], "t": g["t"], "ok": ok, "text": String(p["text"]), "reward": reward_text(w, g)})
	var bonus := {}
	if met == 3:
		nudge(w, 5.0, "Ano de ouro: as três metas cumpridas")
		w.life["gold"] = float(w.life.get("gold", 0.0)) + 1.0
	# Com a cidade (ou os sócios) do lado, o ano fecha com um prêmio.
	var v := value_of(w)
	if v >= WARM:
		if pres:
			var grant := snappedf(Org.OVERHEAD * 4.0, 10000.0)
			t.add_money(w.week, "Bônus dos sócios pelo ano", grant)
			t.reputation = minf(100.0, t.reputation + 1.0)
			bonus = {"money": grant, "text": "Os sócios aprovaram um bônus pelo ano e reforçaram a verba da liga."}
		else:
			var grant2 := snappedf(3000.0 + t.reputation * 220.0, 500.0)
			t.add_money(w.week, "Prêmio da prefeitura", grant2)
			bonus = {"money": grant2, "text": "A prefeitura homenageou a academia e o comércio local renovou o patrocínio."}
	w.life["years"] = float(w.life.get("years", 0.0)) + 1.0
	var keep := {}
	for k: String in KEEP:
		if (w.goals["c"] as Dictionary).has(k):
			keep[k] = float(w.goals["c"][k])
	var past: Array = w.goals.get("past", [])
	past.append({"year": year, "items": res, "met": met, "c": keep, "v0": float(w.goals.get("v0", 50.0)), "v1": v,
		"cash0": float(w.goals.get("cash0", t.balance)), "cash1": t.balance, "rep0": float(w.goals.get("rep0", t.reputation)), "rep1": t.reputation,
		"bonus": bonus, "term": int(w.support.get("terms", 1))})
	if past.size() > PAST_MAX:
		past = past.slice(past.size() - PAST_MAX)
	w.add_news("meta", "Temporada de %d: %s. %s" % [year, verdict(met), "%d de 3 metas cumpridas." % met], [], true)
	w.goals = {"year": year + 1, "c": {}, "past": past, "v0": v, "cash0": t.balance, "rep0": t.reputation}
	w.goals["items"] = _pick(w, year + 1)
	w.gala = {"year": year, "seen": false}


static func verdict(met: int) -> String:
	return String(["ano para esquecer", "ano irregular", "bom ano", "ano de ouro"][clampi(met, 0, 3)])


## Balanço de um ano fechado (ou {} se não houver).
static func review(w: GameWorld, year: int) -> Dictionary:
	for p: Dictionary in w.goals.get("past", []):
		if int(p["year"]) == year:
			return p
	return {}


static func gala_pending(w: GameWorld) -> bool:
	return not w.gala.is_empty() and not bool(w.gala.get("seen", false))
