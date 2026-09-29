class_name YouthAcademy
extends RefCounted
## A estrutura da base do usuário (complementa YouthManager):
##   - Estrutura: o nível da base (Club.youth_level) em faixas, com o que cada faixa rende; o
##     investimento é pedido ao presidente (BoardRequests, tipo "youth").
##   - Técnicos por categoria (sub-20, sub-17, sub-15), de 1 a 5 estrelas, com especialidade:
##     aceleram a evolução dos garotos da categoria e custam salário (cobrado na virada do ano).
##   - Plano individual de cada garoto: foco (físico, técnico, finalização...) e intensidade.
##   - Empréstimo de garotos (17+) para ganhar minutos num clube menor, já com contrato profissional.
##   - Histórico de cada garoto na base: temporada a temporada, com os números por competição.
## Estado em world.youth: coaches {cat: {n, l, sp, a}}, plans {id: {f, i}}, log {id: [linhas]},
## cs (números da temporada por competição) e shine (destaques em copas).

const COACH_LEVELS := 5
const COACH_GROWTH: Array[float] = [0.9, 0.97, 1.04, 1.11, 1.18]
const COACH_WAGE: Array[float] = [0.5, 1.0, 1.7, 2.7, 4.0]

## Especialidade do técnico: puxa a evolução para esses atributos quando o plano do garoto é "auto".
const SPECIALTIES := {
	"formador": {"name": "Formador", "desc": "Evolução equilibrada, cuida da parte mental", "bias": [[Attr.DEC, 1.6], [Attr.INT, 1.6], [Attr.DIS, 1.4]]},
	"tecnico": {"name": "Técnico", "desc": "Passe, domínio e drible", "bias": [[Attr.PAS, 1.7], [Attr.TEC, 1.8], [Attr.DRI, 1.6]]},
	"fisico": {"name": "Preparador", "desc": "Velocidade, força e fôlego", "bias": [[Attr.VEL, 1.6], [Attr.FOR, 1.7], [Attr.RES, 1.7], [Attr.ACE, 1.5]]},
	"tatico": {"name": "Estrategista", "desc": "Posicionamento, marcação e visão", "bias": [[Attr.POS, 1.8], [Attr.MAR, 1.5], [Attr.VIS, 1.6]]},
}
const SPEC_ORDER: Array[String] = ["formador", "tecnico", "fisico", "tatico"]

## Foco do plano individual.
const PLANS := {
	"auto": {"name": "Livre", "desc": "Segue a linha do técnico da categoria", "bias": []},
	"fisico": {"name": "Físico", "desc": "Velocidade, força, aceleração e fôlego", "bias": [[Attr.VEL, 2.4], [Attr.FOR, 2.4], [Attr.RES, 2.2], [Attr.ACE, 2.2]]},
	"tecnico": {"name": "Técnica", "desc": "Passe, técnica e drible", "bias": [[Attr.PAS, 2.4], [Attr.TEC, 2.6], [Attr.DRI, 2.4]]},
	"finalizacao": {"name": "Finalização", "desc": "Finalização, chute de longe e cabeceio", "bias": [[Attr.FIN, 2.8], [Attr.CHL, 2.2], [Attr.CAB, 2.0], [Attr.FRI, 1.6]]},
	"defesa": {"name": "Defesa", "desc": "Marcação, desarme e posicionamento", "bias": [[Attr.MAR, 2.6], [Attr.DES, 2.6], [Attr.POS, 2.0], [Attr.CAB, 1.6]]},
	"mental": {"name": "Leitura de jogo", "desc": "Decisão, visão, inteligência e frieza", "bias": [[Attr.DEC, 2.4], [Attr.VIS, 2.4], [Attr.INT, 2.2], [Attr.FRI, 2.0]]},
	"goleiro": {"name": "Goleiro", "desc": "Colocação, reflexos e saída do gol", "bias": [[Attr.GOL, 2.6], [Attr.REF, 2.6], [Attr.POS, 1.6]]},
}
const PLAN_ORDER: Array[String] = ["auto", "fisico", "tecnico", "finalizacao", "defesa", "mental", "goleiro"]
## Intensidade: evolução × moral por semana × chance de lesão por semana.
const INTENSITY: Array = [
	{"name": "Leve", "g": 0.9, "m": 0.6, "inj": 0.0},
	{"name": "Normal", "g": 1.0, "m": 0.0, "inj": 0.0},
	{"name": "Intensa", "g": 1.12, "m": -0.5, "inj": 0.006},
]

## Faixas da estrutura (Club.youth_level).
const TIERS: Array = [
	[0, "Precária", "Campo emprestado, pouca estrutura: poucos garotos e evolução lenta."],
	[35, "Básica", "Alojamento simples e campo próprio."],
	[55, "Boa", "CT da base com academia e análise de desempenho: um garoto a mais por ano."],
	[70, "Excelente", "Estrutura de clube grande: garotos melhores e evolução mais rápida."],
	[85, "Referência", "Uma das melhores do continente: dois garotos a mais e joias com frequência."],
]


# ---------------------------------------------------------------------------
# Estrutura
# ---------------------------------------------------------------------------

static func tier_index(club: Club) -> int:
	var idx := 0
	for i in TIERS.size():
		if club.youth_level >= int(TIERS[i][0]):
			idx = i
	return idx


static func tier_name(club: Club) -> String:
	return String(TIERS[tier_index(club)][1])


static func tier_desc(club: Club) -> String:
	return String(TIERS[tier_index(club)][2])


## Quanto a estrutura acelera a evolução semanal (mesma conta de YouthManager.weekly).
static func facility_growth(club: Club) -> float:
	return 0.75 + club.youth_level / 250.0


# ---------------------------------------------------------------------------
# Técnicos da base
# ---------------------------------------------------------------------------

static func coaches(world: GameWorld) -> Dictionary:
	var s := world.youth
	var cur: Dictionary = s.get("coaches", {})
	if cur.is_empty() or int(cur.get("club", -1)) != world.user_club_id:
		cur = {"club": world.user_club_id}
		var club := world.user_club()
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([world.world_seed, world.user_club_id, "ycoach"])
		var base := clampi(1 + int(club.youth_level / 25.0), 1, 4)
		for cat in [YouthManager.CAT_U20, YouthManager.CAT_U17, YouthManager.CAT_U15]:
			cur[cat] = _new_coach(rng, club, clampi(base + rng.randi_range(-1, 0), 1, COACH_LEVELS))
		s["coaches"] = cur
	return cur


static func _new_coach(rng: RandomNumberGenerator, club: Club, level: int) -> Dictionary:
	var o := NameGenerator.pick_origin(rng, club.nation)
	var n := NameGenerator.generate(rng, String(o["c"]), {}, {})
	return {"n": "%s %s" % [n["first"], n["last"]], "l": level, "sp": SPEC_ORDER[rng.randi_range(0, SPEC_ORDER.size() - 1)], "a": rng.randi_range(32, 66)}


static func coach_of(world: GameWorld, cat: String) -> Dictionary:
	return coaches(world).get(cat, {"n": "?", "l": 2, "sp": "formador", "a": 40})


static func coach_level(world: GameWorld, cat: String) -> int:
	return clampi(int(coach_of(world, cat).get("l", 2)), 1, COACH_LEVELS)


## Salário anual de um técnico da base desse nível.
static func coach_wage(world: GameWorld, level: int) -> int:
	var base := maxf(12000.0, FinanceManager.expected_revenue(world.user_club()) * 0.0009)
	return Valuation.round_wage(base * COACH_WAGE[clampi(level, 1, COACH_LEVELS) - 1])


static func coaches_cost(world: GameWorld) -> int:
	var t := 0
	for cat in [YouthManager.CAT_U20, YouthManager.CAT_U17, YouthManager.CAT_U15]:
		t += coach_wage(world, coach_level(world, cat))
	return t


## Três técnicos disponíveis para a categoria (mudam a cada temporada e a cada contratação).
static func coach_candidates(world: GameWorld, cat: String) -> Array:
	var cur := coach_level(world, cat)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, cat, int(world.youth.get("hires", 0))])
	var club := world.user_club()
	var out: Array = []
	for i in 3:
		var lvl := clampi(cur + [1, 2, 0][i] + (1 if club.youth_level >= 70 and i == 0 else 0), 1, COACH_LEVELS)
		out.append(_new_coach(rng, club, lvl))
	return out


## Multa para dispensar o técnico atual (um quarto do salário anual).
static func coach_severance(world: GameWorld, cat: String) -> int:
	return int(coach_wage(world, coach_level(world, cat)) * 0.25)


## Contrata: paga a multa do atual e metade do salário do novo na hora (o resto na virada do ano).
static func hire_coach(world: GameWorld, cat: String, cand: Dictionary) -> String:
	var club := world.user_club()
	var cost := coach_severance(world, cat) + int(coach_wage(world, int(cand["l"])) * 0.5)
	if cost > club.balance:
		return "Sem caixa para essa contratação (%s)." % Fmt.money(cost)
	club.add_ledger("salarios", -cost)
	coaches(world)[cat] = cand.duplicate()
	world.youth["hires"] = int(world.youth.get("hires", 0)) + 1
	NewsManager.post_raw(world, "%s assume o %s do %s" % [cand["n"], YouthManager.category_name(cat), club.short_name],
		"O novo técnico (%s) chega para acelerar a formação dos garotos." % String(SPECIALTIES[cand["sp"]]["name"]).to_lower(),
		club.id, -1, NewsEvent.IMP_LOW, "base")
	return "%s é o novo técnico do %s." % [cand["n"], YouthManager.category_name(cat)]


# ---------------------------------------------------------------------------
# Plano individual
# ---------------------------------------------------------------------------

static func plan_of(world: GameWorld, p: Player) -> Dictionary:
	return world.youth.get("plans", {}).get(str(p.id), {"f": "auto", "i": 1})


static func set_plan(world: GameWorld, p: Player, focus: String, intensity: int) -> void:
	if not PLANS.has(focus):
		return
	var plans: Dictionary = world.youth.get("plans", {})
	plans[str(p.id)] = {"f": focus, "i": clampi(intensity, 0, INTENSITY.size() - 1)}
	world.youth["plans"] = plans


## Viés de atributos da semana: o plano do garoto ou, sem plano, a linha do técnico.
static func growth_bias(world: GameWorld, p: Player) -> Array:
	var pl := plan_of(world, p)
	var f := String(pl.get("f", "auto"))
	if f != "auto":
		return PLANS[f]["bias"]
	var sp := String(coach_of(world, YouthManager.category(p, world.year)).get("sp", "formador"))
	return SPECIALTIES.get(sp, SPECIALTIES["formador"])["bias"]


## Multiplicador semanal: técnico da categoria × intensidade × encaixe do plano com a posição.
static func growth_mult(world: GameWorld, p: Player) -> float:
	var m := COACH_GROWTH[coach_level(world, YouthManager.category(p, world.year)) - 1]
	var pl := plan_of(world, p)
	m *= float(INTENSITY[clampi(int(pl.get("i", 1)), 0, 2)]["g"])
	var f := String(pl.get("f", "auto"))
	var grp := Pos.group(p.position)
	if (f == "goleiro") != (grp == Pos.G_GK) and f != "auto" and f != "fisico" and f != "mental":
		m *= 0.92 # treinar o que a posição não usa rende menos
	return m


## Efeitos semanais do plano: moral e o risco da carga intensa.
static func weekly_side(world: GameWorld, p: Player) -> void:
	var it: Dictionary = INTENSITY[clampi(int(plan_of(world, p).get("i", 1)), 0, 2)]
	p.morale = clampf(p.morale + float(it["m"]), 0.0, 100.0)
	if float(it["inj"]) > 0.0 and p.injury_weeks <= 0 and world.rng.randf() < float(it["inj"]):
		p.injury_weeks = world.rng.randi_range(1, 3)
		p.injury_name = "Sobrecarga muscular"


# ---------------------------------------------------------------------------
# Empréstimo de garotos
# ---------------------------------------------------------------------------

static func loan_block(world: GameWorld, p: Player) -> String:
	if not world.academy.has(p.id):
		return "Ele não está mais na base."
	if p.age(world.year) < 17:
		return "Só garotos a partir dos 17 anos podem ser emprestados."
	if not world.transfer_window_open():
		return "A janela de transferências está fechada."
	return ""


## Clube onde o garoto jogaria: nível um pouco acima do dele, de preferência no mesmo país.
static func loan_destination(world: GameWorld, p: Player) -> Club:
	var user := world.user_club()
	var best: Club = null
	var best_v := -1e9
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.world_seed, world.year, world.current_turn(), p.id, "yloan"])
	var max_p := int(DatabaseManager.squad_rules()["max_players"])
	for c: Club in world.clubs:
		if c.id == user.id or c.player_ids.size() >= max_p or user.is_rival(c.id):
			continue
		if YouthManager.min_foreign_age(p.nationality, c.nation) > p.age(world.year):
			continue
		var level := PlayerGenerator.club_level(c)
		if p.ovr_f < level - 9.0 or p.ovr_f > level + 6.0:
			continue
		var v := -absf(p.ovr_f - level + 3.0) + (5.0 if c.nation == user.nation else 0.0) + rng.randf_range(0.0, 3.0)
		if v > best_v:
			best_v = v
			best = c
	return best


## Assina o contrato profissional e empresta até o fim da temporada. Retorna {ok, msg}.
static func loan_kid(world: GameWorld, p: Player) -> Dictionary:
	var why := loan_block(world, p)
	if why != "":
		return {"ok": false, "msg": why}
	var dest := loan_destination(world, p)
	if dest == null:
		return {"ok": false, "msg": "Nenhum clube quis o garoto emprestado agora."}
	var user := world.user_club()
	YouthManager.promote(world, p, true)
	TransferManager._move_loan(world, p, user, dest)
	p.squad_status = Player.STATUS_ROTATION
	NewsManager.post_raw(world, "%s emprestado ao %s" % [p.display_name(), dest.short_name],
		"Cria da base do %s, %s (%d anos) assina o primeiro contrato profissional e vai ganhar minutos no %s até o fim da temporada." % [user.short_name, p.display_name(), p.age(world.year), dest.short_name],
		user.id, p.id, NewsEvent.IMP_NORMAL, "base")
	return {"ok": true, "msg": "%s foi emprestado ao %s." % [p.display_name(), dest.short_name]}


# ---------------------------------------------------------------------------
# Histórico na base
# ---------------------------------------------------------------------------

## Linhas do histórico: [{y, cat, a, g, as, r (nota × 10 somada), m (melhor em campo), c: {comp: [j, g, a]}}].
static func history(world: GameWorld, pid: int) -> Array:
	return world.youth.get("log", {}).get(str(pid), [])


## Números da temporada por competição: {comp: [jogos, gols, assistências]}.
static func season_by_comp(world: GameWorld, pid: int) -> Dictionary:
	return world.youth.get("cs", {}).get(str(pid), {})


static func comp_label(world: GameWorld, key: String) -> String:
	match key:
		"u20":
			return "Liga Sub-20"
		"u17":
			return "Liga Sub-17"
		"intl":
			var d := YouthCups.comp(world, "intl")
			return String(d.get("short", "Mundial"))
	var c := YouthCups.comp(world, key)
	if not c.is_empty():
		return String(c["short"])
	return {"cup20": "Copa Juniores", "cup17": "Copa Sub-17", "cont": "Liga Jovem"}.get(key, key)


## Virada do ano: guarda a temporada de cada garoto (antes de zerar os números).
static func log_season(world: GameWorld, year: int) -> void:
	var log: Dictionary = world.youth.get("log", {})
	var cs: Dictionary = world.youth.get("cs", {})
	for p: Player in world.academy.values():
		if p.stats[Player.S_APPS] <= 0 and not cs.has(str(p.id)):
			continue
		var rows: Array = log.get(str(p.id), [])
		rows.append({"y": year, "cat": YouthManager.category(p, year), "a": p.stats[Player.S_APPS], "g": p.stats[Player.S_GOALS],
			"as": p.stats[Player.S_ASSISTS], "r": p.stats[Player.S_RATING_SUM], "m": p.stats[Player.S_MOTM], "o": p.overall,
			"c": cs.get(str(p.id), {})})
		log[str(p.id)] = rows.slice(maxi(0, rows.size() - 6))
	# Quem saiu da base há tempo não precisa mais do histórico no save
	for k in log.keys():
		if not world.academy.has(int(k)) and not world.players.has(int(k)):
			log.erase(k)
	world.youth["log"] = log
	world.youth["cs"] = {}
	world.youth["shine"] = {}
	var plans: Dictionary = world.youth.get("plans", {})
	for k in plans.keys():
		if not world.academy.has(int(k)):
			plans.erase(k)
