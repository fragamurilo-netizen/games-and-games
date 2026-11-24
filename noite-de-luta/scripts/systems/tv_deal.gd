class_name TVDeal
extends RefCounted
## Contrato de TV da organização (papel de presidente). `GameWorld.tv` é o contrato em vigor:
## {partner, fee (por Fight Night), fee_ppv (por evento numerado), start, until, signed_rep}.
## O valor é travado na assinatura: fechar contrato longo com a organização pequena prende um
## valor baixo por anos; fechar curto dá a chance de renegociar melhor quando ela crescer.
##
## Três tipos de parceiro, com trocas diferentes (`PARTNERS`):
## - TV aberta: paga menos, mas todo mundo vê. Patrocínio maior, lutadores ficam famosos mais
##   rápido e a noite ganha um pouco de hype.
## - TV por assinatura: o meio-termo. O pay-per-view continua sendo da organização.
## - Streaming: paga mais e leva os eventos numerados para dentro da assinatura: a organização
##   troca o pay-per-view (que depende do hype) por um valor fixo alto por evento numerado.
## Todos pagam um bônus de audiência quando a noite passa de `BONUS_HYPE` de hype.
##
## Oito semanas antes do fim chegam três propostas (`make_offers`). O presidente assina uma ou
## pede mais (`ask`): com força na mesa (reputação e hype das últimas noites) o parceiro sobe;
## sem ela, mantém ou retira a proposta. Sem decisão até o fim, o contrato atual é renovado por
## seis meses com desconto (`week`).

const PARTNERS := {
	"aberta": {"name": "Rede Horizonte", "kind": "TV aberta", "fee_k": 0.78, "ppv_fee_k": 1.3, "ppv_k": 1.0, "sponsor_k": 1.45, "fame_k": 1.25, "hype": 3.0, "reach": 3.0,
		"help": "Paga menos, mas todo mundo vê: patrocínio maior, lutadores ficam famosos mais rápido e a noite ganha hype."},
	"cabo": {"name": "Arena Sports", "kind": "TV por assinatura", "fee_k": 1.0, "ppv_fee_k": 1.4, "ppv_k": 1.0, "sponsor_k": 1.0, "fame_k": 1.0, "hype": 0.0, "reach": 1.2,
		"help": "O meio-termo. O pay-per-view continua sendo seu."},
	"streaming": {"name": "Octo Play", "kind": "Streaming", "fee_k": 1.2, "ppv_fee_k": 3.1, "ppv_k": 0.0, "sponsor_k": 0.9, "fame_k": 0.95, "hype": 0.0, "reach": 1.7,
		"help": "Paga mais e leva os eventos numerados para dentro da assinatura: você troca o pay-per-view por um valor fixo alto."},
}
const ORDER := ["aberta", "cabo", "streaming"]
## Hype da noite a partir do qual o parceiro paga o bônus de audiência.
const BONUS_HYPE := 65.0
const BONUS_K := 0.15
## Semanas antes do fim em que as propostas chegam.
const NOTICE := 8
const ASK_STEPS := [0.1, 0.2]


static func partner(key: String) -> Dictionary:
	return PARTNERS.get(key, PARTNERS["cabo"])


static func current(w: GameWorld) -> Dictionary:
	return w.tv


static func partner_of(w: GameWorld) -> Dictionary:
	return partner(String(w.tv.get("partner", "cabo")))


static func weeks_left(w: GameWorld) -> int:
	return maxi(0, int(w.tv.get("until", w.week)) - w.week)


## Valor de referência por Fight Night para a reputação dada (antes do tipo de parceiro).
static func base_fee(rep: float, audience: float) -> float:
	return 1800000.0 * (0.6 + rep / 100.0 * 0.8) * (0.85 + audience / 100.0 * 0.4)


## Hype médio das últimas noites fechadas (a "audiência" que a organização leva para a mesa).
static func audience(w: GameWorld) -> float:
	var past := Org.past_events(w)
	if past.is_empty():
		return 45.0
	var sum := 0.0
	var n := 0
	for ev: FightEvent in past.slice(0, 6):
		sum += float(ev.report.get("draw", 45.0))
		n += 1
	return sum / float(maxi(1, n))


## Força na mesa (0 a 1): reputação e audiência recente.
static func leverage(w: GameWorld) -> float:
	var t := w.user_team()
	var rep := t.reputation if t != null else 50.0
	return clampf(rep / 100.0 * 0.6 + audience(w) / 100.0 * 0.5, 0.0, 1.0)


static func leverage_label(l: float) -> String:
	if l >= 0.75:
		return "forte"
	if l >= 0.55:
		return "boa"
	if l >= 0.4:
		return "razoável"
	return "fraca"


static func _deal(w: GameWorld, key: String, weeks: int, k: float = 1.0) -> Dictionary:
	var t := w.user_team()
	var rep := t.reputation if t != null else 50.0
	var p := partner(key)
	var base := base_fee(rep, audience(w)) * k
	return {"partner": key, "fee": snappedf(base * float(p["fee_k"]), 10000.0), "fee_ppv": snappedf(base * float(p["ppv_fee_k"]), 10000.0),
		"weeks": weeks, "asks": 0, "signed_rep": rep}


## Contrato herdado da gestão anterior (começo da carreira e saves antigos): TV por assinatura,
## curto, para a primeira renegociação chegar cedo.
static func ensure(w: GameWorld) -> void:
	if not w.is_president() or not w.tv.is_empty():
		return
	var d := _deal(w, "cabo", 22, 0.92)
	d["start"] = w.week
	d["until"] = w.week + 22
	d.erase("weeks")
	d.erase("asks")
	w.tv = d


## As três propostas da renovação (uma por tipo de parceiro), com durações diferentes.
static func make_offers(w: GameWorld) -> void:
	w.tv_offers = []
	var durs := [52, 104, 156]
	for key: String in ORDER:
		var weeks: int = durs[w.rng.randi_range(0, durs.size() - 1)]
		# Contrato longo paga um pouco mais por ano; o parceiro atual dá um agrado para ficar.
		var k := 1.0 + (weeks - 52) / 52.0 * 0.04 + w.rng.randf_range(-0.05, 0.05)
		if key == String(w.tv.get("partner", "")):
			k += 0.04
		var d := _deal(w, key, weeks, k)
		d["id"] = w.new_id()
		w.tv_offers.append(d)
	w.add_news("tv", "O contrato de TV com a %s termina em %s. Três propostas estão na mesa." % [String(partner_of(w)["name"]), Fmt.plural(weeks_left(w), "semana", "semanas")], [], true)


static func offer(w: GameWorld, id: int) -> Dictionary:
	for o: Dictionary in w.tv_offers:
		if int(o.get("id", -1)) == id:
			return o
	return {}


## Chance de o parceiro aceitar o pedido de aumento (0 a 1).
static func ask_chance(w: GameWorld, o: Dictionary, step: float) -> float:
	var p := 0.25 + leverage(w) * 0.75 - step * 2.2 - int(o.get("asks", 0)) * 0.22
	if w.tv_offers.size() <= 1:
		p -= 0.15
	return clampf(p, 0.03, 0.95)


## Pede `step` (0,1 = 10%) a mais. {ok, text, gone}
static func ask(w: GameWorld, o: Dictionary, step: float) -> Dictionary:
	var p := ask_chance(w, o, step)
	var name := String(partner(String(o["partner"]))["name"])
	o["asks"] = int(o.get("asks", 0)) + 1
	var roll := w.rng.randf()
	if roll < p:
		o["fee"] = snappedf(float(o["fee"]) * (1.0 + step), 10000.0)
		o["fee_ppv"] = snappedf(float(o["fee_ppv"]) * (1.0 + step), 10000.0)
		return {"ok": true, "gone": false, "text": "A %s aceitou: %d%% a mais em cada noite." % [name, int(round(step * 100.0))]}
	if roll < p + 0.3:
		var half := step * 0.5
		o["fee"] = snappedf(float(o["fee"]) * (1.0 + half), 10000.0)
		o["fee_ppv"] = snappedf(float(o["fee_ppv"]) * (1.0 + half), 10000.0)
		return {"ok": true, "gone": false, "text": "A %s chegou no meio do caminho: %d%% a mais." % [name, int(round(half * 100.0))]}
	if int(o["asks"]) >= 2 or roll > 0.9:
		w.tv_offers.erase(o)
		return {"ok": false, "gone": true, "text": "A %s retirou a proposta e saiu da mesa." % name}
	return {"ok": false, "gone": false, "text": "A %s não sobe: a proposta continua como está." % name}


## Assina a proposta: vale a partir do fim do contrato atual (ou de agora, se ele já acabou).
static func sign(w: GameWorld, o: Dictionary) -> void:
	var start := maxi(w.week, int(w.tv.get("until", w.week)))
	var p := partner(String(o["partner"]))
	var d := {"partner": o["partner"], "fee": o["fee"], "fee_ppv": o["fee_ppv"], "start": start, "until": start + int(o["weeks"]), "signed_rep": o.get("signed_rep", 50.0)}
	if start <= w.week:
		w.tv = d
	else:
		w.tv["next"] = d
	w.tv_offers = []
	w.add_news("tv", "Contrato de TV assinado com a %s (%s) por %s: %s por Fight Night e %s por evento numerado." % [String(p["name"]), String(p["kind"]).to_lower(), years_text(int(o["weeks"])), Fmt.money(float(o["fee"])), Fmt.money(float(o["fee_ppv"]))], [], true)


static func years_text(weeks: int) -> String:
	if weeks % 52 == 0:
		return Fmt.plural(weeks / 52, "ano", "anos")
	return Fmt.plural(weeks, "semana", "semanas")


## Semana a semana: propostas na hora certa, troca para o contrato novo e renovação de emergência.
static func week(w: GameWorld) -> void:
	if not w.is_president():
		return
	ensure(w)
	var left := int(w.tv.get("until", w.week)) - w.week
	if left <= 0:
		var nxt: Dictionary = w.tv.get("next", {})
		if not nxt.is_empty():
			w.tv = nxt
			return
		# Ninguém decidiu: o parceiro atual renova por seis meses, pagando menos.
		var key := String(w.tv.get("partner", "cabo"))
		var d := _deal(w, key, 26, 0.85)
		d["start"] = w.week
		d["until"] = w.week + 26
		d.erase("weeks")
		d.erase("asks")
		w.tv = d
		w.tv_offers = []
		w.add_news("tv", "Sem acordo novo, a %s renova o contrato de TV por seis meses pagando menos. Na próxima, negocie antes do fim." % String(partner(key)["name"]), [], true)
		return
	if left == NOTICE and not w.tv.has("next") and w.tv_offers.is_empty():
		make_offers(w)


## Tem decisão de TV esperando o presidente?
static func pending(w: GameWorld) -> bool:
	return w.is_president() and not w.tv_offers.is_empty()


# --- Na noite -----------------------------------------------------------------------------

## Quanto a TV paga pela noite: {fee, bonus}.
static func night_fee(w: GameWorld, ev: FightEvent, hype: float) -> Dictionary:
	ensure(w)
	var fee := float(w.tv.get("fee_ppv", 0.0)) if ev.ppv else float(w.tv.get("fee", 0.0))
	return {"fee": fee, "bonus": fee * BONUS_K if hype >= BONUS_HYPE else 0.0}


static func ppv_k(w: GameWorld) -> float:
	return float(partner_of(w)["ppv_k"])


static func sponsor_k(w: GameWorld) -> float:
	return float(partner_of(w)["sponsor_k"])


## Fama a mais (ou a menos) de quem luta nas noites da organização, pelo alcance da TV.
static func fame_k(w: GameWorld) -> float:
	if not w.is_president() or w.tv.is_empty():
		return 1.0
	return float(partner_of(w)["fame_k"])


static func hype_bonus(w: GameWorld) -> Array:
	if w.tv.is_empty():
		return ["", 0.0]
	var p := partner_of(w)
	return ["Chamada na %s" % String(p["kind"]), float(p["hype"])]


## Audiência da noite, em pessoas (para a tela: quem viu).
static func viewers(w: GameWorld, hype: float) -> int:
	var p := partner_of(w) if not w.tv.is_empty() else partner("cabo")
	return int(float(p["reach"]) * (0.3 + pow(clampf(hype, 0.0, 100.0) / 100.0, 1.5) * 2.2) * 1000000.0)
