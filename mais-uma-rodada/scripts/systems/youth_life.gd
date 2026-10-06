class_name YouthLife
extends RefCounted
## A vida do garoto na base do usuário, do jeito que acontece nos clubes de verdade. Quase tudo é
## escondido: a comissão só percebe sinais (texto), nunca números.
##
##   - Maturação biológica: uns ganham corpo cedo, outros tarde. O precoce domina os jogos da base
##     (mais minutos, nota melhor) e engana a avaliação; a vantagem some perto dos 19 anos. O tardio
##     parece pior do que é e pede paciência. Um coordenador bom erra menos.
##   - Família: presente, humilde (a proposta em dinheiro pesa), pai que cuida da carreira (cobra
##     minutos, ouve empresário) ou garoto que mora no alojamento, longe de casa (saudade).
##   - Contrato: até o primeiro contrato profissional (a partir dos 16) o vínculo é só de formação.
##     Empresários rondam quem tem talento de verdade; sem contrato profissional, o garoto pode sair
##     e o clube recebe apenas a compensação de formação.
##   - Desistência: alguns largam o futebol ou voltam para casa no fim do ano.
##   - Geração: quem divide a categoria vira amigo (ou desafeto) — e mais tarde "revelados juntos".
##
## Estado em world.youth["life"][str(id)] = {mt (anos de maturação: negativo = adiantado), fm
## (família), far, pc (fim do contrato profissional, 0 = só formação), ag (assédio de empresários
## 0..100), hs (saudade 0..100), pr (semanas de minutos prometidos), ev (ano do último aviso)}.

const FAMILIES := {
	"presente": "Mora com a família, que acompanha tudo de perto.",
	"humilde": "Família humilde: o futebol é a esperança da casa.",
	"pai": "O pai cuida da carreira e cobra muito.",
	"alojamento": "Mora no alojamento do clube, longe da família.",
}
const PRO_MIN_AGE := 16
const PRO_YEARS := 3
const KINDS := ["youth_agent", "youth_homesick", "youth_parent"]


static func data(world: GameWorld) -> Dictionary:
	if not world.youth.has("life") or typeof(world.youth["life"]) != TYPE_DICTIONARY:
		world.youth["life"] = {}
	return world.youth["life"]


## Ficha escondida do garoto (criada na primeira vez, sem mexer no RNG do mundo).
static func of(world: GameWorld, p: Player) -> Dictionary:
	var d := data(world)
	var key := str(p.id)
	if d.has(key):
		return d[key]
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, "base_vida"])
	var mt := r.randfn(0.0, 0.8)
	if p.dev_curve == Player.CURVE_PRECOCE:
		mt -= 0.9
	elif p.dev_curve == Player.CURVE_TARDIO:
		mt += 0.9
	var club := world.user_club()
	# Longe de casa de verdade: a cidade natal fica a mais de 350 km do clube (ou é de outro país).
	var hk := Geo.home_km(p, club)
	var far := p.nationality != club.nation or hk > 350.0 or (hk < 0.0 and r.randf() < 0.3)
	var fm := "alojamento" if far else String(RngUtil.weighted_key(r, {"presente": 4.0, "humilde": 3.5, "pai": 1.6}))
	var e := {"mt": snappedf(clampf(mt, -2.2, 2.2), 0.01), "fm": fm, "far": far, "pc": 0, "ag": 0.0, "hs": 0.0, "pr": 0, "ev": 0}
	d[key] = e
	return e


static func forget(world: GameWorld, pid: int) -> void:
	data(world).erase(str(pid))


# ---------------------------------------------------------------------------
# Maturação
# ---------------------------------------------------------------------------

## Vantagem física de agora em pontos de overall (precoce +, tardio −); some aos 19 anos.
static func maturity_edge(world: GameWorld, p: Player) -> float:
	var fade := clampf((19.0 - float(p.age(world.year))) / 5.0, 0.0, 1.0)
	return -float(of(world, p)["mt"]) * 1.8 * fade


## Quanto a avaliação de potencial erra por causa do corpo (coordenador bom enxerga através).
static func estimate_bias(world: GameWorld, p: Player, precision: float) -> float:
	return maturity_edge(world, p) * 1.4 * (1.0 - precision * 0.7)


## O que a comissão percebe do corpo (vazio se não percebe nada ainda).
static func maturity_text(world: GameWorld, p: Player) -> String:
	if YouthManager.precision(world, p) < 0.45:
		return ""
	var e := maturity_edge(world, p)
	if e >= 1.5:
		return "Corpo adiantado para a idade: parte do rendimento é físico e vai sumir."
	if e <= -1.5:
		return "Ainda não ganhou corpo: deve render mais quando amadurecer."
	return ""


# ---------------------------------------------------------------------------
# Contrato profissional
# ---------------------------------------------------------------------------

static func has_pro(world: GameWorld, p: Player) -> bool:
	return int(of(world, p)["pc"]) >= world.year


## Salário mensal do primeiro contrato (metade do que ganharia subindo ao elenco).
static func pro_wage(world: GameWorld, p: Player) -> int:
	var club := world.user_club()
	var w := Valuation.base_wage(p.ovr_f) * 0.3 * float(club.league_cfg().get("wage", 0.5))
	if String(of(world, p)["fm"]) == "pai" or float(of(world, p)["ag"]) >= 60.0:
		w *= 1.35 # empresário e pai negociam
	return Valuation.round_wage(w)


static func pro_block(world: GameWorld, p: Player) -> String:
	if not world.academy.has(p.id):
		return "Ele não está mais na base."
	if has_pro(world, p):
		return "Já tem contrato profissional até %d." % int(of(world, p)["pc"])
	if p.age(world.year) < PRO_MIN_AGE:
		return "O primeiro contrato profissional só a partir dos %d anos." % PRO_MIN_AGE
	return ""


static func sign_pro(world: GameWorld, p: Player) -> String:
	var why := pro_block(world, p)
	if why != "":
		return why
	var e := of(world, p)
	p.wage = pro_wage(world, p)
	e["pc"] = world.year + PRO_YEARS
	p.contract_end = int(e["pc"])
	e["ag"] = maxf(0.0, float(e["ag"]) - 70.0)
	p.morale = minf(100.0, p.morale + 10.0)
	return "%s assinou o primeiro contrato profissional até %d (%s/mês)." % [p.display_name(), int(e["pc"]), Fmt.money(p.wage)]


## Compensação de formação (regra da FIFA): por ano de base, conforme o porte de quem leva.
static func training_comp(world: GameWorld, p: Player, buyer: Club) -> int:
	var club := world.user_club()
	var years := clampi(YouthManager.years_in(world, p) + 1, 1, 6)
	var per := 10000.0
	if buyer != null:
		if buyer.tier == 1 and buyer.reputation >= 75.0:
			per = 90000.0
		elif buyer.tier == 1:
			per = 60000.0
		elif buyer.tier == 2:
			per = 30000.0
		if buyer.nation == club.nation:
			per *= 0.5
	return int(per * years)


# ---------------------------------------------------------------------------
# Semana
# ---------------------------------------------------------------------------

## Multiplicador de evolução da semana (saudade atrapalha).
static func growth_mult(world: GameWorld, p: Player) -> float:
	return 1.0 - float(of(world, p)["hs"]) / 250.0


## Vantagem na escolha do time da base: corpo e minutos prometidos ao pai.
static func pick_bonus(world: GameWorld, p: Player) -> float:
	var e := of(world, p)
	return maturity_edge(world, p) + (2.5 if int(e["pr"]) > 0 else 0.0)


static func weekly(world: GameWorld) -> void:
	if world.academy.is_empty():
		return
	var club := world.user_club()
	var lvl := PlayerGenerator.club_level(club)
	var left: Array = []
	for p: Player in world.academy.values():
		var e := of(world, p)
		var age := p.age(world.year)
		if int(e["pr"]) > 0:
			e["pr"] = int(e["pr"]) - 1
		# Empresários: farejam talento de verdade (o potencial real) de quem ainda não tem contrato.
		var ag := float(e["ag"])
		if age >= 15 and not has_pro(world, p) and float(p.potential) >= lvl - 3.0:
			var pull := 0.5 + maxf(0.0, float(p.potential) - lvl) * 0.12
			pull *= float({"pai": 1.8, "humilde": 1.3, "presente": 0.8, "alojamento": 1.0}.get(String(e["fm"]), 1.0))
			pull *= 0.6 + p.hid("amb") / 25.0
			pull *= 1.3 - p.hid("lea") / 30.0
			if p.morale < 45.0:
				pull *= 1.4
			ag += pull
		else:
			ag -= 1.0
		e["ag"] = clampf(ag, 0.0, 100.0)
		# Saudade: quem mora longe sofre mais quando está desanimado e se adapta mal.
		if bool(e["far"]):
			var hs := float(e["hs"])
			# O primeiro ano longe de casa é o mais duro; quem se adapta mal sofre mais.
			var push := maxf(0.0, 1.5 - p.hid("ada") / 12.0) * (1.6 if YouthManager.years_in(world, p) == 0 else 1.0)
			push *= (1.3 if age <= 15 else 1.0) * (1.4 if p.morale < 55.0 else 0.8)
			push -= Relations.friends_in(world, p, club).size() * 0.15
			e["hs"] = clampf(hs + push - 0.3, 0.0, 100.0)
			if float(e["hs"]) >= 45.0:
				p.morale = clampf(p.morale - 0.8, 0.0, 100.0)
		# Sem contrato profissional, com 18 anos e um empresário já fechado com outro clube: vai embora.
		if float(e["ag"]) >= 100.0 and age >= 18 and not has_pro(world, p):
			left.append([p, "agent"])
		elif float(e["hs"]) >= 100.0:
			left.append([p, "home"])
	for x in left:
		_leave(world, x[0], String(x[1]))
	# Salário de quem já tem contrato profissional (semana a semana).
	var pay := 0
	for p: Player in world.academy.values():
		if has_pro(world, p):
			pay += p.wage
	if pay > 0:
		club.add_ledger("salarios", -int(pay * 12 / 52))


## O garoto vai embora no meio do ano (empresário ou saudade).
static func _leave(world: GameWorld, p: Player, why: String) -> void:
	var club := world.user_club()
	if not world.academy.has(p.id):
		return
	if why == "agent":
		var buyer := YouthManager.bid_buyer(world, p)
		var comp := training_comp(world, p, buyer)
		world.academy.erase(p.id)
		forget(world, p.id)
		p.reset_season_stats()
		p.club_id = -1
		if buyer != null:
			PlayerGenerator.sign_to_club(world, world.rng, p, buyer, false)
			p.squad_status = Player.STATUS_PROSPECT
			p.contract_end = world.year + 3
			p.wage = Valuation.round_wage(Valuation.base_wage(p.ovr_f) * 0.6 * float(buyer.league_cfg().get("wage", 0.5)))
			club.add_ledger("vendas", comp)
			buyer.add_ledger("compras", -comp)
		else:
			p.contract_end = world.year
			world.add_player(p)
		var where := buyer.name if buyer != null else "outro clube"
		InboxManager.send(world, "base", "%s foi embora" % p.display_name(),
			"Sem contrato profissional, %s (%d anos) fechou com o %s pelas mãos do empresário. O clube recebe só a compensação de formação: %s." % [p.display_name(), p.age(world.year), where, Fmt.money(comp if buyer != null else 0)],
			{"k": "screen", "s": "academy"})
		NewsManager.post_raw(world, "%s perde %s para o %s" % [club.short_name, p.display_name(), where],
			"A joia da base do %s saiu sem contrato profissional. O clube fica apenas com a compensação de formação." % club.short_name,
			club.id, p.id, NewsEvent.IMP_HIGH, "base")
	else:
		world.academy.erase(p.id)
		forget(world, p.id)
		InboxManager.send(world, "base", "%s voltou para casa" % p.display_name(),
			"%s não aguentou a saudade da família e pediu para deixar o alojamento. Desistiu da base." % p.display_name(),
			{"k": "screen", "s": "academy"})


# ---------------------------------------------------------------------------
# Fim de ano: desistências e laços da geração
# ---------------------------------------------------------------------------

## Antes de envelhecer: quem larga o futebol. Retorna [[nome, motivo]].
static func dropouts(world: GameWorld) -> Array:
	var out: Array = []
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.year, world.user_club_id, "desistencia"])
	for p: Player in world.academy.values().duplicate():
		var e := of(world, p)
		var age := p.age(world.year)
		var chance := 0.04
		var why := "Preferiu largar o futebol e seguir os estudos."
		if age >= 17 and float(p.potential) - p.ovr_f < 4.0 and YouthManager.play_factor(world, p) < 0.9:
			chance += 0.15
			why = "Sem espaço e sem evolução, desistiu da carreira."
		if p.hid("pro") <= 6 or p.has_trait("festeiro"):
			chance += 0.05
			why = "A falta de compromisso pesou: foi desligado da base."
		if float(e["hs"]) >= 45.0:
			chance += 0.15
			why = "A saudade venceu: voltou para perto da família."
		if has_pro(world, p):
			chance *= 0.3
		if r.randf() < chance:
			world.academy.erase(p.id)
			forget(world, p.id)
			out.append([p.display_name(), why])
	return out


## Quem divide a categoria cria laços (a química do par decide se vira amizade ou rixa).
static func generation_bonds(world: GameWorld) -> void:
	var by_cat := {}
	for p: Player in world.academy.values():
		var cat := YouthManager.category(p, world.year)
		if not by_cat.has(cat):
			by_cat[cat] = []
		by_cat[cat].append(p)
	for cat in by_cat:
		var arr: Array = by_cat[cat]
		for i in arr.size():
			for j in range(i + 1, arr.size()):
				var a: Player = arr[i]
				var b: Player = arr[j]
				var ch := Relations.chem(a.id, b.id, "base")
				if ch >= 0.8:
					Relations.link(world, a, b, Relations.AMIGO, 12.0 + (ch - 0.8) * 60.0)
				elif ch <= 0.04:
					Relations.link(world, a, b, Relations.INIMIGO, 10.0)


## Limpa fichas de quem já não está na base.
static func prune(world: GameWorld) -> void:
	var d := data(world)
	for k in d.keys():
		if not world.academy.has(int(k)):
			d.erase(k)


# ---------------------------------------------------------------------------
# O que a comissão vê na ficha (texto, nunca número)
# ---------------------------------------------------------------------------

static func notes(world: GameWorld, p: Player) -> Array:
	var e := of(world, p)
	var out: Array = []
	if has_pro(world, p):
		out.append("Contrato profissional até %d (%s/mês)." % [int(e["pc"]), Fmt.money(p.wage)])
	elif p.age(world.year) >= PRO_MIN_AGE:
		out.append("Só tem contrato de formação: se sair, o clube recebe apenas a compensação.")
	else:
		out.append("Contrato de formação (o profissional só a partir dos %d anos)." % PRO_MIN_AGE)
	out.append(String(FAMILIES.get(String(e["fm"]), "")))
	var mt := maturity_text(world, p)
	if mt != "":
		out.append(mt)
	if float(e["ag"]) >= 40.0 and not has_pro(world, p):
		out.append("Empresários rondando: o assédio está crescendo.")
	if float(e["hs"]) >= 35.0:
		out.append("Anda com saudade de casa.")
	if int(e["pr"]) > 0:
		out.append("Minutos prometidos à família.")
	return out


# ---------------------------------------------------------------------------
# Dilemas (mesmo formato do EventManager; os tipos ficam em EventManager.KINDS)
# ---------------------------------------------------------------------------

static func handles(k: String) -> bool:
	return KINDS.has(k)


static func build(world: GameWorld, k: String, ev: Dictionary) -> Dictionary:
	var best: Player = null
	var best_v := 0.0
	for p: Player in world.academy.values():
		var e := of(world, p)
		if int(e["ev"]) == world.year * 10 + KINDS.find(k):
			continue # um aviso de cada tipo por garoto e temporada
		var v := 0.0
		match k:
			"youth_agent":
				if p.age(world.year) >= PRO_MIN_AGE and not has_pro(world, p):
					v = float(e["ag"]) if float(e["ag"]) >= 55.0 else 0.0
			"youth_homesick":
				v = float(e["hs"]) if float(e["hs"]) >= 50.0 else 0.0
			"youth_parent":
				if String(e["fm"]) == "pai" and YouthManager.category(p, world.year) != YouthManager.CAT_U15 and YouthManager.play_factor(world, p) < 0.92 and int(e["pr"]) <= 0:
					v = 50.0 + float(p.potential)
		if v > best_v:
			best_v = v
			best = p
	if best == null:
		return {}
	of(world, best)["ev"] = world.year * 10 + KINDS.find(k)
	ev["p"] = best.id
	if k == "youth_agent":
		var buyer := YouthManager.bid_buyer(world, best)
		ev["d"] = {"club": buyer.id if buyer != null else -1}
	return ev


static func describe(world: GameWorld, ev: Dictionary) -> Dictionary:
	var p: Player = world.player(int(ev.get("p", -1)))
	var pn := p.display_name() if p != null else "O garoto"
	var age := p.age(world.year) if p != null else 17
	match String(ev["k"]):
		"youth_agent":
			var buyer := world.club(int(ev["d"].get("club", -1)))
			var who := ("o %s" % buyer.name) if buyer != null else "um clube maior"
			return {"title": "Empresário quer levar %s" % pn, "def": 0,
				"body": "Um empresário conhecido está com %s (%d anos) e a família na mão e acena com %s. Ele só tem contrato de formação: se sair, o clube fica com a compensação de formação e mais nada." % [pn, age, who],
				"options": [
					{"t": "Assinar o primeiro contrato profissional", "hint": "%s/mês por %d anos · fica protegido" % [Fmt.money(pro_wage(world, p)) if p != null else "", PRO_YEARS]},
					{"t": "Conversar com a família", "hint": "Pode acalmar · depende da família"},
					{"t": "Não fazer nada", "hint": "O assédio continua"}]}
		"youth_homesick":
			return {"title": "%s sente falta de casa" % pn, "def": 0,
				"body": "O coordenador avisa que %s (%d anos) anda calado no alojamento e rende menos nos treinos. Ele está longe da família há muito tempo." % [pn, age],
				"options": [
					{"t": "Trazer a família para perto", "hint": "O clube paga moradia · %s" % Fmt.money(_family_cost(world))},
					{"t": "Psicólogo e um padrinho no elenco", "hint": "Ajuda aos poucos"},
					{"t": "Deixar passar duas semanas em casa", "hint": "Volta melhor · perde treinos"}]}
		"youth_parent":
			return {"title": "Pai de %s cobra minutos" % pn, "def": 0,
				"body": "O pai de %s apareceu no CT: acha que o filho joga pouco na categoria e fala em levá-lo para outro clube." % pn,
				"options": [
					{"t": "Prometer mais minutos", "hint": "Ganha espaço nos próximos jogos da base"},
					{"t": "Explicar o plano da comissão", "hint": "Pode convencer · pode irritar"},
					{"t": "Bater de frente", "hint": "Comissão manda · empresários se animam"}]}
	return {"title": "", "body": "", "options": [{"t": "Ok", "hint": ""}], "def": 0}


static func _family_cost(world: GameWorld) -> int:
	return int(Valuation.round_wage(Valuation.base_wage(PlayerGenerator.club_level(world.user_club()) - 20.0) * 6.0))


static func resolve(world: GameWorld, ev: Dictionary, opt: int) -> String:
	world.events.erase(ev)
	var p: Player = world.player(int(ev.get("p", -1)))
	if p == null or not world.academy.has(p.id):
		return "Ele já não está na base."
	var e := of(world, p)
	var club := world.user_club()
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, world.year, world.current_turn(), String(ev["k"])])
	match String(ev["k"]):
		"youth_agent":
			match opt:
				0:
					return sign_pro(world, p)
				1:
					var ok := r.randf() < float({"presente": 0.8, "humilde": 0.5, "pai": 0.3, "alojamento": 0.6}.get(String(e["fm"]), 0.5)) + (p.hid("lea") - 10) * 0.03
					if ok:
						e["ag"] = maxf(0.0, float(e["ag"]) - 35.0)
						return "A família confia no clube: %s fica tranquilo por enquanto." % p.display_name()
					e["ag"] = minf(100.0, float(e["ag"]) + 10.0)
					return "A conversa não convenceu. O empresário segue por perto."
				_:
					e["ag"] = minf(100.0, float(e["ag"]) + 8.0)
					return "Nada mudou. O empresário segue por perto."
		"youth_homesick":
			match opt:
				0:
					club.add_ledger("salarios", -_family_cost(world))
					e["hs"] = 5.0
					e["far"] = false
					e["fm"] = "presente"
					p.morale = minf(100.0, p.morale + 15.0)
					return "A família de %s se mudou para perto do CT." % p.display_name()
				1:
					e["hs"] = maxf(0.0, float(e["hs"]) - 30.0)
					var mentor := _mentor(world, p)
					if mentor != null:
						Relations.link(world, p, mentor, Relations.MENTOR, 25.0)
						return "%s vai apadrinhar %s, e o psicólogo acompanha o garoto." % [mentor.display_name(), p.display_name()]
					return "O psicólogo do clube passa a acompanhar %s." % p.display_name()
				_:
					e["hs"] = 15.0
					p.dev_acc -= 0.3
					p.morale = minf(100.0, p.morale + 10.0)
					return "%s passa duas semanas com a família." % p.display_name()
		"youth_parent":
			match opt:
				0:
					e["pr"] = 8
					return "Promessa feita: %s vai ganhar espaço na categoria." % p.display_name()
				1:
					if r.randf() < 0.55:
						p.morale = minf(100.0, p.morale + 4.0)
						return "O pai entendeu o plano e saiu mais calmo."
					e["ag"] = minf(100.0, float(e["ag"]) + 15.0)
					return "O pai não gostou da conversa e voltou a falar com empresários."
				_:
					e["ag"] = minf(100.0, float(e["ag"]) + 25.0)
					p.morale = clampf(p.morale - 8.0, 0.0, 100.0)
					return "A comissão manda na base. O clima com a família ficou ruim."
	return ""


## Padrinho no elenco: compatriota experiente, de preferência da mesma posição.
static func _mentor(world: GameWorld, p: Player) -> Player:
	var best: Player = null
	var best_s := -1.0
	for q: Player in world.squad(world.user_club()):
		if q.age(world.year) < 26:
			continue
		var s := q.hid("pro") + (8.0 if q.nationality == p.nationality else 0.0) + (4.0 if q.position == p.position else 0.0)
		if s > best_s:
			best_s = s
			best = q
	return best
