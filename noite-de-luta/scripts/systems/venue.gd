class_name Venue
extends RefCounted
## Sede, arena e ingresso das noites da organização (papel de presidente).
##
## - **Sede**: cada cidade da liga tem um tamanho de mercado (quanta gente quer ir) e um poder de
##   compra (quanto aceita pagar). Lutador da casa no card enche mais; voltar demais à mesma
##   cidade cansa o público; cidade que não recebe a liga há muito tempo responde melhor.
## - **Arena**: ginásio (pequeno e barato, lota fácil), arena (o padrão) ou estádio (três vezes
##   a arena, caro: só fecha a conta com uma noite muito quente).
## - **Ingresso**: cinco faixas de preço. Mais caro rende mais por pessoa e afasta gente.
## A procura (`demand`) sai do hype da noite (`Hype.event`), da reputação da organização e desses
## fatores; o público é a procura limitada pela lotação. Casa cheia dá prestígio, casa vazia
## tira (`fill_rep`).
## A sede e a arena travam quando os ingressos vão à venda (`LOCK_WEEKS` antes da noite); o
## preço pode mudar até a semana da luta.

const TYPES := {
	"ginasio": {"name": "Ginásio", "cap_k": 0.36, "fixed": 230000.0, "seat": 14.0, "help": "Pequeno e barato. Lota fácil e esquenta, mas a bilheteria tem teto."},
	"arena": {"name": "Arena", "cap_k": 1.0, "fixed": 650000.0, "seat": 18.0, "help": "O padrão da liga."},
	"estadio": {"name": "Estádio", "cap_k": 3.0, "fixed": 1500000.0, "seat": 20.0, "help": "Três vezes a arena. Só fecha a conta com uma noite muito quente."},
}
const ORDER := ["ginasio", "arena", "estadio"]
const PRICE_K := [0.6, 0.8, 1.0, 1.35, 1.8]
const PRICE_NAMES := ["Popular", "Acessível", "Padrão", "Premium", "Luxo"]
## Semanas antes da noite em que os ingressos vão à venda (sede e arena não mudam mais).
const LOCK_WEEKS := 3
## Lugares na arena de cada cidade da liga.
const CITY_CAP := {"Las Vegas": 19000, "Nova York": 19500, "Rio de Janeiro": 15000, "São Paulo": 14000,
	"Londres": 17000, "Abu Dhabi": 12000, "Paris": 15500, "Toronto": 19000, "Sydney": 18000,
	"Cidade do México": 20000, "Tóquio": 16000, "Seul": 12000, "Xangai": 15000, "Varsóvia": 15000,
	"Moscou": 14000, "Dublin": 9500, "Houston": 17000, "Miami": 18000, "Chicago": 20000,
	"Riad": 11000, "Belo Horizonte": 13000, "Manchester": 16000}
const CAP_DEFAULT := 14000
## [tamanho do mercado, poder de compra] de cada cidade (as que faltam usam 0,9 e 1,0).
const MARKET := {"Las Vegas": [1.3, 1.4], "Nova York": [1.35, 1.45], "Rio de Janeiro": [1.15, 0.8], "São Paulo": [1.2, 0.85],
	"Londres": [1.25, 1.3], "Paris": [1.1, 1.2], "Abu Dhabi": [0.8, 1.6], "Tóquio": [1.1, 1.2], "Sydney": [1.05, 1.2],
	"Cidade do México": [1.2, 0.75], "Toronto": [1.1, 1.15], "Varsóvia": [0.9, 0.8], "Dublin": [0.85, 1.05],
	"Xangai": [1.0, 1.0], "Houston": [1.0, 1.1], "Chicago": [1.1, 1.15], "Miami": [1.05, 1.2], "Riad": [0.75, 1.7],
	"Belo Horizonte": [0.85, 0.7], "Manchester": [0.95, 1.05]}


static func market(city: String) -> float:
	return float((MARKET.get(city, [0.9, 1.0]) as Array)[0])


static func wealth(city: String) -> float:
	return float((MARKET.get(city, [0.9, 1.0]) as Array)[1])


static func arena_cap(city: String) -> int:
	return int(CITY_CAP.get(city, CAP_DEFAULT))


static func type_of(ev: FightEvent) -> Dictionary:
	return TYPES.get(ev.venue, TYPES["arena"])


static func cap_for(city: String, type: String) -> int:
	var t: Dictionary = TYPES.get(type, TYPES["arena"])
	return int(snappedf(arena_cap(city) * float(t["cap_k"]), 100.0))


static func capacity(ev: FightEvent) -> int:
	return cap_for(ev.city, ev.venue)


static func cost_for(city: String, type: String, ppv: bool) -> float:
	var t: Dictionary = TYPES.get(type, TYPES["arena"])
	return float(t["fixed"]) * (0.8 + wealth(city) * 0.2) + cap_for(city, type) * float(t["seat"]) + (350000.0 if ppv else 0.0)


## Aluguel e produção da noite.
static func cost(ev: FightEvent) -> float:
	return cost_for(ev.city, ev.venue, ev.ppv)


static func type_name(ev: FightEvent) -> String:
	return String(type_of(ev)["name"])


static func cities() -> Array:
	return DataDB.mma()["lgc_cities"]


static func locked(w: GameWorld, ev: FightEvent) -> bool:
	return ev.done or ev.closed or ev.week - w.week <= LOCK_WEEKS


## Lutadores da casa no card: {n, bonus (fração a mais na procura), names}.
static func locals(w: GameWorld, ev: FightEvent, nation: String = "") -> Dictionary:
	var nat := nation if nation != "" else ev.nation
	var lst := Card.bouts(w, ev)
	var n := 0
	var bonus := 0.0
	var names: Array = []
	for i in lst.size():
		var b: Bout = lst[i]
		for fid: int in [b.a, b.b]:
			var f := w.fighter(fid)
			if f != null and f.nation == nat:
				n += 1
				bonus += f.popularity / 100.0 * (0.16 if i == lst.size() - 1 else 0.07)
				names.append(f.short_name())
	return {"n": n, "bonus": minf(0.35, bonus), "names": names}


## Noites recentes da liga na mesma cidade (últimos seis meses): {n, k (fração a menos)}.
static func saturation(w: GameWorld, ev: FightEvent, city: String = "") -> Dictionary:
	var c := city if city != "" else ev.city
	var n := 0
	for e: FightEvent in w.events.values():
		if e.tier == 2 and e.id != ev.id and e.city == c and absi(e.week - ev.week) <= 26 and e.week < ev.week:
			n += 1
	return {"n": n, "k": minf(0.36, n * 0.12)}


## A liga não passa pela cidade há mais de um ano e meio (só conta com a carreira já andando).
static func novelty(w: GameWorld, ev: FightEvent, city: String = "") -> bool:
	var c := city if city != "" else ev.city
	if w.week < 26:
		return false
	for e: FightEvent in w.events.values():
		if e.tier == 2 and e.id != ev.id and e.city == c and e.week < ev.week and ev.week - e.week <= 78:
			return false
	return true


## O que mexe com a procura além do hype: [[texto, fração], ...] (para a tela).
static func crowd_factors(w: GameWorld, ev: FightEvent, city: String = "", nation: String = "") -> Array:
	var c := city if city != "" else ev.city
	var out: Array = []
	var m := market(c)
	if m >= 1.15:
		out.append(["Mercado grande", m - 1.0])
	elif m <= 0.9:
		out.append(["Mercado pequeno", m - 1.0])
	var lc := locals(w, ev, nation)
	if int(lc["n"]) > 0:
		out.append(["%s da casa no card" % Fmt.plural(int(lc["n"]), "lutador", "lutadores"), float(lc["bonus"])])
	var sat := saturation(w, ev, c)
	if int(sat["n"]) > 0:
		out.append(["%s aqui nos últimos seis meses" % Fmt.plural(int(sat["n"]), "noite", "noites"), -float(sat["k"])])
	if novelty(w, ev, c):
		out.append(["A liga não vem aqui há mais de um ano", 0.08])
	return out


static func base_price(city: String, hype: float) -> float:
	return (95.0 + hype * 1.6) * wealth(city)


## Preço médio do ingresso na faixa escolhida.
static func price(ev: FightEvent, hype: float, level: int = -1) -> float:
	var lv := clampi(ev.ticket if level < 0 else level, 0, PRICE_K.size() - 1)
	return snappedf(base_price(ev.city, hype) * float(PRICE_K[lv]), 1.0)


## Quanta gente quer ir, no preço escolhido (sem o limite da lotação).
static func demand(w: GameWorld, ev: FightEvent, hype: float, level: int = -1, city: String = "", nation: String = "") -> float:
	var c := city if city != "" else ev.city
	var t := w.user_team()
	var rep := t.reputation if t != null else 50.0
	var interest := 0.25 + pow(clampf(hype, 0.0, 100.0) / 100.0, 1.6) * 2.6 + rep / 300.0
	var d := 16000.0 * interest
	for f: Array in crowd_factors(w, ev, c, nation):
		d *= 1.0 + float(f[1])
	var lv := clampi(ev.ticket if level < 0 else level, 0, PRICE_K.size() - 1)
	return d * pow(float(PRICE_K[lv]), -1.35)


## Prestígio que a casa cheia dá (ou a casa vazia tira), por noite.
static func fill_rep(ev: FightEvent, crowd: int) -> float:
	var cap := maxi(1, capacity(ev))
	var fill := float(crowd) / float(cap)
	var big := {"ginasio": 0.5, "arena": 1.0, "estadio": 2.5}.get(ev.venue, 1.0) as float
	if fill >= 0.98:
		return 0.15 * big
	if fill < 0.55:
		return -0.35 * big
	if fill < 0.75:
		return -0.12 * big
	return 0.0


static func fill_text(ev: FightEvent, crowd: int) -> String:
	var fill := float(crowd) / float(maxi(1, capacity(ev)))
	if fill >= 0.98:
		return "Casa cheia"
	if fill >= 0.75:
		return "Bom público"
	if fill >= 0.55:
		return "Lugares vazios aparecem na transmissão"
	return "Arena vazia: pega mal para a organização"


# --- Na mão do presidente -------------------------------------------------------------------

static func set_city(w: GameWorld, ev: FightEvent, city: String, nation: String) -> String:
	if locked(w, ev):
		return "Os ingressos já estão à venda: a sede não muda mais."
	ev.city = city
	ev.nation = nation
	return ""


static func set_type(w: GameWorld, ev: FightEvent, type: String) -> String:
	if locked(w, ev):
		return "Os ingressos já estão à venda: a arena não muda mais."
	if not TYPES.has(type):
		return "Arena desconhecida."
	ev.venue = type
	return ""


static func set_ticket(w: GameWorld, ev: FightEvent, level: int) -> String:
	if ev.done or ev.closed or ev.week <= w.week:
		return "Na semana da luta o preço não muda mais."
	ev.ticket = clampi(level, 0, PRICE_K.size() - 1)
	return ""
