class_name People
extends RefCounted
## Pessoas do futebol além dos jogadores e a teia de relações entre elas:
## técnicos de todos os clubes (com troca de comando), presidentes, a comissão técnica do
## usuário, a torcida organizada, os jornalistas e as relações entre tudo isso:
##   jogador → treinador (confiança), jogador ↔ jogador (amizades, mentores e rivalidades),
##   treinador ↔ técnicos rivais, comissão, presidente, torcida e imprensa.
##
## Tudo fica em world.people (dicionários simples, salvos com o mundo). O sistema usa um
## gerador próprio semeado pelo mundo: ligá-lo não muda a sequência de sorteios das partidas.

const VERSION := 1

const COACH_STYLES := {
	"ofensivo": {"name": "Ofensivo", "desc": "Time no ataque o tempo todo, mesmo correndo riscos."},
	"pragmatico": {"name": "Pragmático", "desc": "Resultado acima de tudo. Defesa sólida e contra-ataque."},
	"motivador": {"name": "Motivador", "desc": "Mexe com a cabeça do grupo. Vestiário fechado com ele."},
	"estrategista": {"name": "Estrategista", "desc": "Estuda cada adversário. Muda o time conforme o jogo."},
	"linha_dura": {"name": "Linha-dura", "desc": "Disciplina acima de tudo. Não passa a mão na cabeça de ninguém."},
	"formador": {"name": "Formador", "desc": "Aposta nos jovens e tem paciência com a base."},
}

const PRES_STYLES := {
	"paciente": {"name": "Paciente", "desc": "Acredita em projeto longo e demora a trocar o técnico.", "patience": 1.35, "shift": -5.0},
	"exigente": {"name": "Exigente", "desc": "Quer resultado já. Meta é meta.", "patience": 0.72, "shift": 6.0},
	"populista": {"name": "Populista", "desc": "Governa de olho na arquibancada: a torcida decide muito.", "patience": 1.0, "shift": 0.0},
	"empresario": {"name": "Empresário", "desc": "Olha a planilha antes da tabela. Odeia prejuízo.", "patience": 1.0, "shift": 2.0},
	"vaidoso": {"name": "Vaidoso", "desc": "Adora holofote: clássicos, títulos e contratações de impacto.", "patience": 0.9, "shift": 3.0},
}

const STAFF_ROLES := {
	"auxiliar": {"name": "Auxiliar técnico", "desc": "Entrosamento do time e leitura do vestiário.", "icon": "tactics"},
	"preparador": {"name": "Preparador físico", "desc": "Recuperação física entre os jogos.", "icon": "bolt"},
	"medico": {"name": "Médico", "desc": "Menos lesões e retornos mais rápidos.", "icon": "cross"},
	"goleiros": {"name": "Treinador de goleiros", "desc": "Evolução dos goleiros.", "icon": "shield"},
	"olheiro": {"name": "Olheiro-chefe", "desc": "Avaliações mais precisas de jogadores de outros clubes.", "icon": "search"},
	"base": {"name": "Coordenador da base", "desc": "Evolução dos garotos da base.", "icon": "up"},
}
const STAFF_ORDER: Array[String] = ["auxiliar", "preparador", "medico", "goleiros", "olheiro", "base"]

const PRESS_TONES := {
	"critico": "Crítico", "amigavel": "Simpático", "sensacionalista": "Sensacionalista", "analitico": "Analítico", "bairrista": "Bairrista",
}
const OUTLETS_PT: Array[String] = ["Diário do Esporte", "Rádio Arquibancada", "Portal Placar Vivo", "Canal Resenha", "Gazeta do Torcedor", "Jornal da Bola", "Revista Escanteio"]
const OUTLETS_INT: Array[String] = ["Sports Daily", "The Terrace", "Goal Line Radio", "Matchday TV", "Football Chronicle", "Pitchside", "The Final Whistle"]

## Países onde o técnico cai mais rápido (a "dança das cadeiras").
const TRIGGER_HAPPY := {"BRA": 1.7, "ARG": 1.4, "MEX": 1.3, "COL": 1.3, "CHI": 1.2, "PAR": 1.2, "ECU": 1.2, "TUR": 1.4, "GRE": 1.3, "ITA": 1.15, "ESP": 1.1}

const BOND_FRIEND := "amizade"
const BOND_MENTOR := "mentor"
const BOND_RIVAL := "rivalidade"


# ---------------------------------------------------------------------------
# Acesso e geração
# ---------------------------------------------------------------------------

static func data(world: GameWorld) -> Dictionary:
	ensure(world)
	return world.people


## Gerador próprio: determinístico pelo mundo e por um contador salvo.
static func rng(world: GameWorld, salt: int = 0) -> RandomNumberGenerator:
	var n := int(world.people.get("rc", 0)) + 1
	world.people["rc"] = n
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, n * 7919 + salt, 424242)
	return r


static func ensure(world: GameWorld) -> void:
	var pp: Dictionary = world.people
	if int(pp.get("v", 0)) >= VERSION:
		if world.has_user() and int(pp.get("uc", -1)) != world.user_club_id:
			_setup_user(world)
		return
	pp["v"] = VERSION
	pp["rc"] = 0
	pp["next"] = 1
	pp["coaches"] = {}
	pp["pres"] = {}
	pp["free"] = []
	pp["trust"] = {}
	pp["bonds"] = []
	pp["crel"] = {}
	pp["staff"] = {}
	pp["cands"] = {}
	pp["press"] = {}
	pp["fans"] = {}
	pp["talk"] = {}
	pp["reqs"] = []
	pp["log"] = []
	pp["mrep"] = 40.0
	pp["uc"] = -1
	var r := rng(world, 1)
	for c: Club in world.clubs:
		var coach := _new_coach(world, r, c.nation, c.reputation, c.archetype)
		coach["c"] = c.id
		coach["since"] = world.year - r.randi_range(0, 3)
		pp["coaches"][c.id] = coach
		pp["pres"][c.id] = _new_president(world, r, c)
	for i in maxi(12, world.clubs.size() / 12):
		var c: Club = world.clubs[r.randi_range(0, world.clubs.size() - 1)]
		var coach := _new_coach(world, r, c.nation, c.reputation - r.randf_range(0.0, 15.0), "")
		pp["free"].append(coach)
	if world.has_user():
		_setup_user(world)


## Tudo o que depende do clube do usuário: comissão, jornalistas, torcida e vestiário.
static func _setup_user(world: GameWorld) -> void:
	var pp: Dictionary = world.people
	var club := world.user_club()
	if club == null:
		return
	var prev := int(pp.get("uc", -1))
	pp["uc"] = club.id
	var r := rng(world, 2)
	# O técnico que estava no clube sai (vai para a lista de livres).
	var old: Dictionary = pp["coaches"].get(club.id, {})
	if not old.is_empty():
		old["c"] = -1
		pp["free"].append(old)
		pp["coaches"].erase(club.id)
	if prev < 0:
		pp["mrep"] = clampf(club.reputation * 0.75, 15.0, 70.0)
	var staff := {}
	for role in STAFF_ORDER:
		var s := _new_staff(world, r, club, role)
		s["rel"] = 50.0
		staff[role] = s
	pp["staff"] = staff
	pp["cands"] = {}
	var nat := club.nation
	var press: Dictionary = pp.get("press", {})
	if String(press.get("nat", "")) != nat:
		var outlets: Array = Array(OUTLETS_PT if _lang(nat) == "pt" else OUTLETS_INT).duplicate()
		RngUtil.shuffle(r, outlets)
		var js: Array = []
		var tones: Array = PRESS_TONES.keys()
		RngUtil.shuffle(r, tones)
		for i in 5:
			var nm := _person_name(r, nat)
			js.append({"id": _next_id(world), "n": nm, "o": outlets[i], "t": tones[i % tones.size()], "rel": 50.0})
		press = {"nat": nat, "j": js, "last": -99}
		pp["press"] = press
	pp["fans"] = {"group": _fan_group(r, club), "support": clampf(55.0 + (club.fan_mood - 60.0) * 0.3, 20.0, 80.0), "chants": [], "visit": -99, "leader": _person_name(r, club.nation)}
	pp["bonds"] = []
	pp["squad"] = club.player_ids.duplicate()
	pp["reqs"] = []
	pp["talk"] = {}
	pp.erase("grace")
	pp.erase("ult")
	pp.erase("offer")
	for p: Player in world.squad(club):
		trust_of(world, p)
	_refresh_bonds(world, r)


static func _next_id(world: GameWorld) -> int:
	var n := int(world.people.get("next", 1))
	world.people["next"] = n + 1
	return n


static func _lang(nation: String) -> String:
	return String(DatabaseManager.nation(nation).get("lang", "en"))


static func _person_name(r: RandomNumberGenerator, nation: String) -> String:
	var origin := NameGenerator.pick_origin(r, nation)
	var g := NameGenerator.generate(r, String(origin["c"]), {}, {})
	var first := String(g["first"]).get_slice(" ", 0)
	var known := String(g["known_as"])
	if known == String(g["nickname"]) and known != "" and r.randf() < 0.35:
		return known
	var last := String(g["last"])
	var main := last.get_slice(" ", last.get_slice_count(" ") - 1)
	if known != first and known.find(" ") < 0 and last.find(known) >= 0:
		main = known
	return "%s %s" % [first, main]


static func _new_coach(world: GameWorld, r: RandomNumberGenerator, nation: String, level: float, arch: String) -> Dictionary:
	var nat := nation
	if r.randf() < 0.18:
		nat = RngUtil.pick(r, ["ARG", "POR", "ESP", "ITA", "BRA", "URU", "GER", "NED", "FRA"])
	var style: String = RngUtil.pick(r, COACH_STYLES.keys())
	if arch.find("formador") >= 0 and r.randf() < 0.5:
		style = "formador"
	elif arch.find("retranca") >= 0 and r.randf() < 0.5:
		style = "pragmatico"
	var sk := clampf(RngUtil.gauss(r, level * 0.8 + 14.0, 9.0), 18.0, 96.0)
	return {"id": _next_id(world), "n": _person_name(r, nat), "nat": nat, "by": world.year - r.randi_range(36, 66),
		"sk": snappedf(sk, 0.1), "st": style, "rep": snappedf(clampf(sk + r.randf_range(-8.0, 6.0), 5.0, 99.0), 0.1),
		"c": -1, "since": world.year, "job": 60.0, "w": 0, "d": 0, "l": 0, "fired": 0}


static func _new_president(world: GameWorld, r: RandomNumberGenerator, c: Club) -> Dictionary:
	var styles: Array = PRES_STYLES.keys()
	var weights: Array = [1.0, 1.0, 1.0, 1.0, 1.0]
	var bp := ClubDNA.patience(c)
	weights[0] += (bp - 50.0) / 25.0
	weights[1] += (50.0 - bp) / 25.0
	for i in weights.size():
		weights[i] = maxf(0.2, weights[i])
	var st: String = styles[RngUtil.weighted_index(r, weights)]
	return {"id": _next_id(world), "n": _person_name(r, c.nation), "by": world.year - r.randi_range(42, 74), "st": st,
		"since": world.year - r.randi_range(0, 2), "term": world.year + r.randi_range(0, 2), "rel": 50.0}


static func _new_staff(world: GameWorld, r: RandomNumberGenerator, club: Club, role: String, boost: float = 0.0) -> Dictionary:
	var sk := clampf(RngUtil.gauss(r, club.reputation * 0.6 + 22.0 + boost, 11.0), 12.0, 95.0)
	var s := {"id": _next_id(world), "n": _person_name(r, club.nation if r.randf() < 0.85 else RngUtil.pick(r, ["BRA", "ARG", "POR", "ESP", "ITA"])),
		"r": role, "by": world.year - r.randi_range(29, 64), "sk": snappedf(sk, 0.1), "rel": 60.0}
	s["nat"] = club.nation
	s["w"] = staff_wage(club, sk)
	return s


## Salário mensal de um membro da comissão: fração da folha do clube, cresce com a qualidade.
static func staff_wage(club: Club, sk: float) -> int:
	var base := maxf(1500.0, club.wage_budget * 0.006)
	return Valuation.round_wage(base * (0.5 + pow(sk / 60.0, 2.0)))


static func _fan_group(r: RandomNumberGenerator, club: Club) -> String:
	var short := club.short_name
	var nick := club.nickname if club.nickname != "" else short
	var opts: Array
	if _lang(club.nation) == "pt":
		opts = ["Torcida Jovem do %s" % short, "Força Jovem %s" % short, "Garra %s" % short, "Império %s" % nick, "Fúria %s" % short, "Mancha %s" % short, "Gaviões do %s" % short]
	elif _lang(club.nation) == "es":
		opts = ["La Barra del %s" % short, "Los Fieles de %s" % short, "La Guardia %s" % short, "Hinchada %s" % short]
	elif _lang(club.nation) == "it":
		opts = ["Curva %s" % short, "Ultras %s" % short, "Brigate %s" % short, "Fedayn %s" % short]
	else:
		opts = ["%s Ultras" % short, "The %s Boys" % short, "%s Supporters Club" % short, "Brigada %s" % short, "Curva %s" % short]
	return RngUtil.pick(r, opts)


# ---------------------------------------------------------------------------
# Técnicos
# ---------------------------------------------------------------------------

## Técnico de um clube ({} = o próprio usuário).
static func coach_of(world: GameWorld, club_id: int) -> Dictionary:
	if world.is_user_club(club_id):
		return {}
	return data(world)["coaches"].get(club_id, {})


static func coach_name(world: GameWorld, club_id: int) -> String:
	if world.is_user_club(club_id):
		return world.manager_name
	return String(coach_of(world, club_id).get("n", "o treinador"))


static func style_name(st: String) -> String:
	return String(COACH_STYLES.get(st, {}).get("name", st))


## Relação do usuário com outro técnico (-100 rivalidade .. 100 amizade).
static func coach_rel(world: GameWorld, coach_id: int) -> float:
	return float(data(world)["crel"].get(coach_id, 0.0))


static func add_coach_rel(world: GameWorld, coach_id: int, d: float) -> void:
	var cr: Dictionary = data(world)["crel"]
	cr[coach_id] = clampf(float(cr.get(coach_id, 0.0)) + d, -100.0, 100.0)


static func coach_rel_label(v: float) -> String:
	if v >= 40.0:
		return "Amigo"
	if v >= 12.0:
		return "Respeito"
	if v > -12.0:
		return "Neutro"
	if v > -40.0:
		return "Estremecida"
	return "Desafeto"


## Reputação do usuário como treinador (1..100).
static func manager_rep(world: GameWorld) -> float:
	return float(data(world).get("mrep", 40.0))


## Troca de comando num clube da IA: o técnico vai para a lista de livres e outro assume.
static func replace_coach(world: GameWorld, club: Club, reason: String) -> Dictionary:
	var pp := data(world)
	var r := rng(world, 3)
	var old: Dictionary = pp["coaches"].get(club.id, {})
	if not old.is_empty():
		FootballMemory.on_coach_left(world, club, old)
		old["c"] = -1
		old["fired"] = int(old.get("fired", 0)) + 1
		old["rep"] = maxf(5.0, float(old.get("rep", 40.0)) - 4.0)
		pp["free"].append(old)
	var best: Dictionary = {}
	var best_score := -INF
	for f: Dictionary in pp["free"]:
		if int(f.get("id", -1)) == int(old.get("id", -2)):
			continue
		if float(f["rep"]) > club.reputation + 18.0:
			continue
		var score := -absf(float(f["rep"]) - club.reputation * 0.9) + (8.0 if String(f["nat"]) == club.nation else 0.0) + r.randf() * 10.0
		score += minf(20.0, FootballMemory.coach_bond(world, f, club.id) / 8.0) # ídolos da casa têm preferência
		if score > best_score:
			best_score = score
			best = f
	if best.is_empty() or r.randf() < 0.25:
		best = _new_coach(world, r, club.nation, club.reputation, club.archetype)
	else:
		pp["free"].erase(best)
	best["c"] = club.id
	best["since"] = world.year
	best["job"] = 65.0
	ClubDNA.on_coach_change(club)
	if not world.is_user_club(club.id):
		# O técnico novo traz a filosofia dele, mas a escola do clube costuma prevalecer.
		club.philosophy = ClubDNA.new_coach_philosophy(club, r, String(best.get("st", "")))
	best["w"] = 0
	best["d"] = 0
	best["l"] = 0
	pp["coaches"][club.id] = best
	while pp["free"].size() > maxi(40, world.clubs.size() / 8):
		pp["free"].pop_front()
	_announce_change(world, club, old, best, reason)
	return best


static func _announce_change(world: GameWorld, club: Club, old: Dictionary, new_coach: Dictionary, reason: String) -> void:
	if not world.has_user():
		return
	var u := world.user_club()
	var relevant := club.league_id == u.league_id or u.is_rival(club.id) or (club.nation == u.nation and club.tier == 1)
	if not relevant:
		return
	var why: String = {"resultados": "após a sequência ruim", "temporada": "depois de uma temporada abaixo da meta", "proposta": "que aceitou outro desafio", "usuario": "após a saída de %s" % world.manager_name}.get(reason, "")
	var title := "%s troca de técnico: sai %s, chega %s" % [club.short_name, String(old.get("n", "o treinador")), String(new_coach["n"])] if not old.is_empty() else "%s anuncia %s como técnico" % [club.short_name, String(new_coach["n"])]
	var body := "O %s anunciou %s (%s, %d anos) %s. O novo comandante tem perfil %s." % [club.name, String(new_coach["n"]), DatabaseManager.nation_name(String(new_coach["nat"])), world.year - int(new_coach["by"]), ("no lugar de %s, %s" % [String(old.get("n", "")), why]) if not old.is_empty() else "", style_name(String(new_coach["st"])).to_lower()]
	NewsManager.post_raw(world, title, body, club.id, -1, NewsEvent.IMP_HIGH if u.is_rival(club.id) or club.league_id == u.league_id else NewsEvent.IMP_NORMAL, "tecnicos")


# ---------------------------------------------------------------------------
# Presidente
# ---------------------------------------------------------------------------

static func president(world: GameWorld, club_id: int) -> Dictionary:
	var pr: Dictionary = data(world)["pres"]
	if not pr.has(club_id):
		var c := world.club(club_id)
		if c == null:
			return {}
		pr[club_id] = _new_president(world, rng(world, 4), c)
	return pr[club_id]


static func pres_style(world: GameWorld, club_id: int) -> Dictionary:
	return PRES_STYLES.get(String(president(world, club_id).get("st", "paciente")), PRES_STYLES["paciente"])


static func pres_rel(world: GameWorld) -> float:
	return float(president(world, world.user_club_id).get("rel", 50.0))


static func add_pres_rel(world: GameWorld, d: float) -> void:
	var p := president(world, world.user_club_id)
	p["rel"] = clampf(float(p.get("rel", 50.0)) + d, 0.0, 100.0)


static func rel_label(v: float) -> String:
	if v >= 80.0:
		return "Excelente"
	if v >= 62.0:
		return "Boa"
	if v >= 42.0:
		return "Cordial"
	if v >= 25.0:
		return "Fria"
	return "Péssima"


## Ajusta a variação de confiança da diretoria do usuário pelo presidente, torcida e relação.
static func board_delta(world: GameWorld, club: Club, d: float, derby: bool) -> float:
	if not world.is_user_club(club.id):
		return d
	var pr := president(world, club.id)
	var st := pres_style(world, club.id)
	var out := d
	if out < 0.0:
		out /= float(st["patience"]) * ManagerProfile.patience_mult(world)
		out *= 1.0 - (float(pr.get("rel", 50.0)) - 50.0) / 200.0
	else:
		out *= 1.0 + (float(pr.get("rel", 50.0)) - 50.0) / 250.0
	match String(pr.get("st", "")):
		"populista":
			out += (fan_support(world) - 50.0) * 0.02
		"empresario":
			if FinanceManager.in_trouble(club):
				out -= 0.3
		"vaidoso":
			if derby:
				out *= 1.3
	return out


## Promessa de meta feita ao presidente: cobrada (ou lembrada) no balanço da temporada.
static func pledge_delta(world: GameWorld, goal_met: bool) -> float:
	var pp := data(world)
	if int(pp.get("pledge", -1)) != world.year:
		return 0.0
	pp.erase("pledge")
	return 4.0 if goal_met else -8.0


## Deslocamento do limite de demissão (positivo = demite mais fácil).
static func fire_shift(world: GameWorld, club: Club) -> float:
	var st := pres_style(world, club.id)
	var s := float(st["shift"]) - (pres_rel(world) - 50.0) * 0.12
	var sup := fan_support(world)
	if sup >= 75.0:
		s -= 4.0 if String(president(world, club.id).get("st", "")) != "populista" else 8.0
	elif sup <= 25.0:
		s += 3.0 if String(president(world, club.id).get("st", "")) != "populista" else 6.0
	return s


# ---------------------------------------------------------------------------
# Comissão técnica
# ---------------------------------------------------------------------------

static func staff(world: GameWorld) -> Dictionary:
	return data(world).get("staff", {})


## Qualidade efetiva (0..1.2) de um cargo: habilidade e sintonia com o treinador.
static func staff_level(world: GameWorld, role: String) -> float:
	if not world.has_user():
		return 0.5
	var s: Dictionary = staff(world).get(role, {})
	if s.is_empty():
		return 0.3
	return float(s["sk"]) / 100.0 * (0.9 + float(s.get("rel", 50.0)) / 500.0)


## Multiplicadores da comissão (só para o clube do usuário; 1.0 ≈ comissão mediana).
static func recovery_mult(world: GameWorld) -> float:
	return 0.92 + staff_level(world, "preparador") * 0.18


static func injury_mult(world: GameWorld) -> float:
	return 1.1 - staff_level(world, "medico") * 0.25


static func growth_mult(world: GameWorld, p: Player) -> float:
	var m := 0.97 + staff_level(world, "auxiliar") * 0.06
	if p.position == Pos.GK:
		m *= 0.9 + staff_level(world, "goleiros") * 0.22
	return m


static func youth_mult(world: GameWorld) -> float:
	return 0.9 + staff_level(world, "base") * 0.22


static func staff_wage_bill(world: GameWorld) -> int:
	var t := 0
	for role in staff(world):
		t += int(staff(world)[role].get("w", 0))
	return t


## Teto mensal que a diretoria libera para a comissão.
static func staff_budget(world: GameWorld) -> int:
	var c := world.user_club()
	return int(maxf(12000.0, c.wage_budget * (0.07 + float(data(world).get("sbud", 0.0)))))


## Candidatos para um cargo (renovados a cada temporada ou após uma contratação).
static func candidates(world: GameWorld, role: String) -> Array:
	var cands: Dictionary = data(world)["cands"]
	if not cands.has(role):
		var r := rng(world, 5)
		var club := world.user_club()
		var list: Array = []
		for i in 3:
			var s := _new_staff(world, r, club, role, [12.0, 2.0, -8.0][i])
			s["rel"] = 62.0
			list.append(s)
		cands[role] = list
	return cands[role]


## Custo de rescisão: três salários do atual.
static func staff_severance(world: GameWorld, role: String) -> int:
	return int(staff(world).get(role, {}).get("w", 0)) * 3


## Contrata um candidato. Retorna mensagem de erro ou "".
static func hire_staff(world: GameWorld, role: String, cand_id: int) -> String:
	var club := world.user_club()
	var list := candidates(world, role)
	var cand: Dictionary = {}
	for c: Dictionary in list:
		if int(c["id"]) == cand_id:
			cand = c
	if cand.is_empty():
		return "Candidato não encontrado."
	var cur: Dictionary = staff(world).get(role, {})
	var new_bill := staff_wage_bill(world) - int(cur.get("w", 0)) + int(cand["w"])
	if new_bill > staff_budget(world):
		return "A diretoria não libera: a comissão passaria do teto de %s/mês." % Fmt.money(staff_budget(world))
	var sev := staff_severance(world, role)
	if sev > 0:
		club.add_ledger("rescisoes", -sev)
	staff(world)[role] = cand
	data(world)["cands"].erase(role)
	# Trocar a comissão mexe com quem fica: o auxiliar e o grupo reparam.
	for other in staff(world):
		if other != role:
			var o: Dictionary = staff(world)[other]
			o["rel"] = clampf(float(o.get("rel", 50.0)) - 2.0, 0.0, 100.0)
	log_event(world, "%s é o novo %s." % [String(cand["n"]), String(STAFF_ROLES[role]["name"]).to_lower()])
	NewsManager.post_raw(world, "%s chega à comissão técnica" % String(cand["n"]),
		"O %s contratou %s como %s%s." % [club.short_name, String(cand["n"]), String(STAFF_ROLES[role]["name"]).to_lower(), (" no lugar de %s" % String(cur["n"])) if not cur.is_empty() else ""], club.id, -1, NewsEvent.IMP_NORMAL, "clube")
	return ""


static func add_staff_rel(world: GameWorld, role: String, d: float) -> void:
	var s: Dictionary = staff(world).get(role, {})
	if not s.is_empty():
		s["rel"] = clampf(float(s.get("rel", 50.0)) + d, 0.0, 100.0)


# ---------------------------------------------------------------------------
# Vestiário: confiança e laços
# ---------------------------------------------------------------------------

## Confiança do jogador no treinador do usuário (0..100). Inicializa pela personalidade.
static func trust_of(world: GameWorld, p: Player) -> float:
	var tr: Dictionary = data(world)["trust"]
	if not tr.has(p.id):
		var t := 50.0 + (p.morale - 65.0) * 0.3
		if p.has_trait("leal"):
			t += 6.0
		if p.has_trait("profissional"):
			t += 3.0
		if p.has_trait("mercenario"):
			t -= 4.0
		if p.has_trait("temperamental"):
			t -= 3.0
		tr[p.id] = clampf(t, 20.0, 80.0)
	return float(tr[p.id])


static func has_trust(world: GameWorld, pid: int) -> bool:
	return data(world)["trust"].has(pid)


static func add_trust(world: GameWorld, p: Player, d: float) -> void:
	if p == null:
		return
	var vol := p.trait_mult("morale_volatility")
	data(world)["trust"][p.id] = clampf(trust_of(world, p) + d * vol, 0.0, 100.0)


static func trust_label(t: float) -> String:
	if t >= 80.0:
		return "Fecha com você"
	if t >= 62.0:
		return "Confia"
	if t >= 42.0:
		return "Neutro"
	if t >= 25.0:
		return "Desconfiado"
	return "Rompido"


static func bonds_of(world: GameWorld, pid: int) -> Array:
	var out: Array = []
	for b: Dictionary in data(world)["bonds"]:
		if int(b["a"]) == pid or int(b["b"]) == pid:
			out.append(b)
	return out


static func bond_other(b: Dictionary, pid: int) -> int:
	return int(b["b"]) if int(b["a"]) == pid else int(b["a"])


static func bond_between(world: GameWorld, a: int, b: int) -> Dictionary:
	for bd: Dictionary in data(world)["bonds"]:
		if (int(bd["a"]) == a and int(bd["b"]) == b) or (int(bd["a"]) == b and int(bd["b"]) == a):
			return bd
	return {}


static func bond_text(b: Dictionary) -> String:
	match String(b["k"]):
		BOND_MENTOR:
			return "Mentor"
		BOND_RIVAL:
			return "Rivalidade"
	return "Amizade"


## Laços novos para quem chegou (e limpeza de quem saiu do clube).
static func _refresh_bonds(world: GameWorld, r: RandomNumberGenerator) -> void:
	var club := world.user_club()
	var pp: Dictionary = world.people
	var ids := {}
	for pid in club.player_ids:
		ids[pid] = true
	var kept: Array = []
	var known := {}
	for b: Dictionary in pp["bonds"]:
		if ids.has(int(b["a"])) and ids.has(int(b["b"])):
			kept.append(b)
			known[int(b["a"])] = int(known.get(int(b["a"]), 0)) + 1
			known[int(b["b"])] = int(known.get(int(b["b"]), 0)) + 1
	pp["bonds"] = kept
	var squad := world.squad(club)
	var seen: Dictionary = pp.get("bseen", {})
	for p: Player in squad:
		if seen.has(p.id):
			continue
		seen[p.id] = true
		for q: Player in squad:
			if q.id == p.id or int(known.get(p.id, 0)) >= 3 or int(known.get(q.id, 0)) >= 3:
				continue
			if not bond_between(world, p.id, q.id).is_empty():
				continue
			var kind := ""
			var v := 0.0
			var ap := p.age(world.year)
			var aq := q.age(world.year)
			if p.nationality == q.nationality and p.nationality != club.nation and r.randf() < 0.5:
				kind = BOND_FRIEND
				v = r.randf_range(35.0, 70.0)
			elif (q.has_trait("lider") and aq >= 28 and ap <= 21 and r.randf() < 0.3) or (p.has_trait("lider") and ap >= 28 and aq <= 21 and r.randf() < 0.3):
				kind = BOND_MENTOR
				v = r.randf_range(40.0, 75.0)
			elif p.position == q.position and absi(p.overall - q.overall) <= 4 and p.squad_status <= Player.STATUS_ROTATION and q.squad_status <= Player.STATUS_ROTATION and r.randf() < 0.22:
				kind = BOND_RIVAL
				v = -r.randf_range(25.0, 55.0)
			elif p.has_trait("temperamental") and q.has_trait("temperamental") and r.randf() < 0.25:
				kind = BOND_RIVAL
				v = -r.randf_range(30.0, 60.0)
			elif p.nationality == q.nationality and absi(ap - aq) <= 3 and r.randf() < 0.07:
				kind = BOND_FRIEND
				v = r.randf_range(25.0, 55.0)
			if kind == "":
				continue
			var a := p.id
			var b := q.id
			if kind == BOND_MENTOR and aq > ap:
				a = q.id
				b = p.id
			pp["bonds"].append({"a": a, "b": b, "k": kind, "v": snappedf(v, 0.1)})
			known[p.id] = int(known.get(p.id, 0)) + 1
			known[q.id] = int(known.get(q.id, 0)) + 1
	pp["bseen"] = seen


static func add_bond(world: GameWorld, a: int, b: int, d: float) -> Dictionary:
	var bd := bond_between(world, a, b)
	if bd.is_empty():
		return bd
	bd["v"] = clampf(float(bd["v"]) + d, -100.0, 100.0)
	if String(bd["k"]) == BOND_RIVAL and float(bd["v"]) > 15.0:
		bd["k"] = BOND_FRIEND
	elif String(bd["k"]) != BOND_RIVAL and float(bd["v"]) < -15.0:
		bd["k"] = BOND_RIVAL
	return bd


# ---------------------------------------------------------------------------
# Torcida
# ---------------------------------------------------------------------------

## Apoio da torcida ao treinador (0..100), diferente do humor com o clube.
static func fan_support(world: GameWorld) -> float:
	return float(data(world)["fans"].get("support", 50.0))


static func add_support(world: GameWorld, d: float) -> void:
	var f: Dictionary = data(world)["fans"]
	f["support"] = clampf(float(f.get("support", 50.0)) + d, 0.0, 100.0)


static func support_label(v: float) -> String:
	if v >= 80.0:
		return "Ídolo"
	if v >= 62.0:
		return "Aprovado"
	if v >= 42.0:
		return "Dividida"
	if v >= 25.0:
		return "Contestado"
	return "Fora!"


static func _chant(world: GameWorld, r: RandomNumberGenerator, result: String, hero: Player) -> void:
	var f: Dictionary = data(world)["fans"]
	var sup := float(f.get("support", 50.0))
	var club := world.user_club()
	var m := world.manager_name
	var opts: Array = []
	if hero != null and result == "V":
		opts.append("\"Ão, ão, ão, %s é seleção!\"" % hero.display_name())
		opts.append("\"Uh, é %s!\"" % hero.display_name())
	if sup >= 70.0:
		opts.append_array(["\"Olê, olê, olê, %s, %s!\"" % [m, m], "\"Fica, %s!\"" % m, "Faixa na arquibancada: \"Confiamos em você, professor\""])
	elif sup <= 28.0:
		opts.append_array(["\"Fora, %s!\"" % m, "\"Ô, %s, pede pra sair!\"" % m, "Faixa na arquibancada: \"Chega de desculpas\""])
	if club.fan_mood <= 30.0:
		opts.append_array(["\"Time sem vergonha!\"", "\"Raça! Raça! Raça!\"", "\"Diretoria, cadê você?\""])
	elif club.fan_mood >= 75.0 and result == "V":
		opts.append_array(["\"Eu acredito!\"", "\"É campeão!\" (ainda é cedo, mas ninguém liga)", "\"Vamos, %s!\"" % club.short_name])
	if opts.is_empty():
		return
	var chants: Array = f.get("chants", [])
	chants.append({"t": RngUtil.pick(r, opts), "turn": world.current_turn()})
	while chants.size() > 5:
		chants.pop_front()
	f["chants"] = chants


# ---------------------------------------------------------------------------
# Imprensa
# ---------------------------------------------------------------------------

static func journalists(world: GameWorld) -> Array:
	return data(world).get("press", {}).get("j", [])


static func journalist(world: GameWorld, jid: int) -> Dictionary:
	for j: Dictionary in journalists(world):
		if int(j["id"]) == jid:
			return j
	return {}


static func add_journalist_rel(world: GameWorld, jid: int, d: float) -> void:
	var j := journalist(world, jid)
	if not j.is_empty():
		j["rel"] = clampf(float(j.get("rel", 50.0)) + d, 0.0, 100.0)


static func press_mood(world: GameWorld) -> float:
	var js := journalists(world)
	if js.is_empty():
		return 50.0
	var s := 0.0
	for j: Dictionary in js:
		s += float(j.get("rel", 50.0))
	return s / js.size()


## Coluna depois de um jogo do usuário: o tom depende do jornalista, da relação e do momento.
static func _column(world: GameWorld, r: RandomNumberGenerator, f: Fixture, result: String) -> void:
	var js := journalists(world)
	if js.is_empty():
		return
	var j: Dictionary = RngUtil.pick(r, js)
	var club := world.user_club()
	var opp := world.club(f.opponent_of(club.id))
	var m := world.manager_name
	var rel := float(j.get("rel", 50.0))
	var tone := String(j["t"])
	var title := ""
	var body := ""
	var score := "%d x %d" % [f.hg, f.ag]
	var bonds: Array = data(world)["bonds"]
	var rivals: Array = bonds.filter(func(b): return String(b["k"]) == BOND_RIVAL and float(b["v"]) <= -45.0)
	var unhappy: Player = null
	for p: Player in world.squad(club):
		if trust_of(world, p) < 28.0 and p.overall >= 60 and (unhappy == null or p.overall > unhappy.overall):
			unhappy = p
	match tone:
		"sensacionalista":
			if not rivals.is_empty() and r.randf() < 0.5:
				var b: Dictionary = RngUtil.pick(r, rivals)
				var pa := world.player(int(b["a"]))
				var pb := world.player(int(b["b"]))
				if pa != null and pb != null:
					title = "Racha no %s? %s e %s não se falam" % [club.short_name, pa.display_name(), pb.display_name()]
					body = "Fontes do vestiário garantem que o clima entre %s e %s azedou de vez. %s terá trabalho para apagar o incêndio." % [pa.display_name(), pb.display_name(), m]
			elif unhappy != null and r.randf() < 0.6:
				title = "%s pode deixar o %s, apuramos" % [unhappy.display_name(), club.short_name]
				body = "Pessoas próximas a %s dizem que a relação com %s está desgastada e que o jogador ouviria propostas." % [unhappy.display_name(), m]
			elif club.board_confidence < 40.0:
				title = "Cargo de %s balança no %s" % [m, club.short_name]
				body = "Nos bastidores, conselheiros já falam em nomes para o comando técnico. A diretoria nega."
			elif result == "V":
				title = "%s vira fenômeno e já é cobiçado por gigantes" % m
				body = "Depois do %s sobre o %s, o nome do treinador circula em clubes maiores. Ele desconversa." % [score, opp.short_name]
		"critico":
			if result == "D":
				title = "Falta padrão ao %s de %s" % [club.short_name, m]
				body = "O %s contra o %s expõe um time sem ideia clara. A paciência tem limite." % [score, opp.short_name]
			elif result == "E":
				title = "O %s empata e segue devendo" % club.short_name
				body = "O %s com o %s mostra um time que não sabe o que fazer com a bola." % [score, opp.short_name]
			elif rel < 40.0:
				title = "Vitória esconde os problemas do %s" % club.short_name
				body = "O placar agradou, mas o futebol continua pobre. %s ainda não convenceu." % m
		"amigavel":
			if result == "V" or rel >= 60.0:
				title = "O trabalho de %s começa a aparecer" % m
				body = "O %s contra o %s mostra um time com cara. Confiança no comandante." % [score, opp.short_name]
		"analitico":
			var l := world.league_of(club.id)
			if l != null and f.is_league():
				var row: Dictionary = l.table[club.id]
				var pl := maxi(1, int(row["pl"]))
				title = "Os números do %s após %d jogos" % [club.short_name, pl]
				body = "Média de %.1f gols marcados e %.1f sofridos por jogo, %d%% de aproveitamento. O %s contra o %s segue a tendência." % [float(row["gf"]) / pl, float(row["ga"]) / pl, int(round(float(row["pts"]) * 100.0 / (pl * 3.0))), score, opp.short_name]
		"bairrista":
			if MatchEngine.is_derby(world, f.home, f.away):
				title = "Clássico: %s" % ("a cidade é nossa!" if result == "V" else ("dia de luto" if result == "D" else "fica tudo igual"))
				body = "O %s contra o %s mexeu com a cidade. %s" % [score, opp.short_name, "O povo está com o treinador." if result == "V" else "A torcida quer respostas."]
			elif result != "E":
				title = "%s %s" % [club.short_name, "no caminho certo" if result == "V" else "precisa de reação"]
				body = "O %s diante do %s é assunto em toda esquina." % [score, opp.short_name]
	if title == "":
		return
	NewsManager.post_raw(world, title, "%s\n— %s, %s" % [body, String(j["n"]), String(j["o"])], club.id, -1, NewsEvent.IMP_NORMAL, "imprensa")


# ---------------------------------------------------------------------------
# Rodada
# ---------------------------------------------------------------------------

## Depois de cada data (todos os clubes): técnicos da IA sob pressão e trocas de comando.
static func after_matchday(world: GameWorld, entries: Array) -> void:
	var pp := data(world)
	var r := rng(world, 6)
	var coaches: Dictionary = pp["coaches"]
	for e in entries:
		var f: Fixture = e["f"]
		if not f.played:
			continue
		for cid in [f.home, f.away]:
			if world.is_user_club(cid):
				continue
			var co: Dictionary = coaches.get(cid, {})
			if co.is_empty():
				continue
			var c := world.club(cid)
			var res := f.result_for(cid)
			var derby := MatchEngine.is_derby(world, f.home, f.away)
			var key := "w" if res == "V" else ("d" if res == "E" else "l")
			co[key] = int(co.get(key, 0)) + 1
			var bp := ClubDNA.patience(c) # paciência com técnico é DNA do clube
			var pres_pat := float(PRES_STYLES.get(String(pp["pres"].get(cid, {}).get("st", "paciente")), PRES_STYLES["paciente"])["patience"])
			var d := 2.0 if res == "V" else (0.2 if res == "E" else -2.6)
			if derby:
				d *= 1.6
			if d < 0.0:
				d /= pres_pat * (0.6 + bp / 125.0)
				d *= float(TRIGGER_HAPPY.get(c.nation, 1.0))
			co["job"] = clampf(float(co.get("job", 60.0)) + d + (60.0 - float(co.get("job", 60.0))) * 0.02, 0.0, 100.0)
			var games := int(co.get("w", 0)) + int(co.get("d", 0)) + int(co.get("l", 0))
			if float(co["job"]) < 25.0 and c.streak_winless >= 3 and games >= 5 and r.randf() < 0.35 * float(TRIGGER_HAPPY.get(c.nation, 1.0)):
				replace_coach(world, c, "resultados")
				_maybe_offer_user(world, r, c)


## Clube que acabou de demitir pode sondar o usuário (se ele tiver moral para isso).
static func _maybe_offer_user(world: GameWorld, r: RandomNumberGenerator, c: Club) -> void:
	if not world.has_user() or world.stats.has("fired"):
		return
	var pp := data(world)
	if pp.has("offer"):
		return
	var u := world.user_club()
	if c.reputation <= u.reputation + 2.0 or c.reputation > manager_rep(world) + 22.0 or c.nation != u.nation and r.randf() < 0.6:
		return
	if r.randf() > 0.35:
		return
	pp["offer"] = {"c": c.id, "until": world.current_turn() + 3}
	InboxManager.on_job_offer(world, c)
	NewsManager.post_raw(world, "%s sonda %s" % [c.short_name, world.manager_name],
		"O %s procurou o staff de %s para saber se ele toparia assumir o clube. A resposta pode mudar a temporada." % [c.name, world.manager_name], c.id, -1, NewsEvent.IMP_HEADLINE, "tecnicos")


## Proposta de outro clube em aberto ({} se não houver).
static func job_offer(world: GameWorld) -> Dictionary:
	var o: Dictionary = data(world).get("offer", {})
	if o.is_empty():
		return o
	if int(o["until"]) < world.current_turn() or world.club(int(o["c"])) == null:
		data(world).erase("offer")
		return {}
	return o


static func decline_offer(world: GameWorld) -> void:
	var o := job_offer(world)
	data(world).erase("offer")
	if o.is_empty():
		return
	add_pres_rel(world, 6.0)
	add_support(world, 5.0)
	world.user_club().board_confidence = clampf(world.user_club().board_confidence + 3.0, 0.0, 100.0)
	log_event(world, "Você recusou o %s e ficou." % world.club(int(o["c"])).short_name)


static func accept_offer(world: GameWorld) -> void:
	var o := job_offer(world)
	if o.is_empty():
		return
	data(world).erase("offer")
	var old := world.user_club()
	BoardManager.take_job(world, int(o["c"]))
	NewsManager.post_raw(world, "%s deixa o %s" % [world.manager_name, old.short_name],
		"A torcida do %s não perdoou a saída no meio da temporada." % old.short_name, old.id, -1, NewsEvent.IMP_HIGH, "tecnicos")


## Depois de cada jogo do usuário. Retorna os pedidos de conversa novos.
static func after_user_turn(world: GameWorld, entry: Dictionary, result: String) -> Array:
	var pp := data(world)
	if not world.has_user() or entry.is_empty():
		return []
	var r := rng(world, 7)
	var club := world.user_club()
	var f: Fixture = entry["f"]
	var res: Dictionary = entry.get("res", {})
	var side := 0 if f.home == club.id else 1
	var derby := MatchEngine.is_derby(world, f.home, f.away)
	var turn := world.current_turn()
	# Quem jogou
	var started := {}
	var used := {}
	var hero: Player = null
	var best_r := 0.0
	if res.has("lines"):
		for ln in res["lines"][side]:
			var p: Player = ln[QuickMatch.L_P]
			used[p.id] = true
			if int(ln[QuickMatch.L_START]) == 0:
				started[p.id] = true
			var rt: float = ln[QuickMatch.L_R]
			if rt > best_r:
				best_r = rt
				hero = p
	_squad_changes(world, r)
	_refresh_bonds(world, r)
	# Confiança no treinador: quem joga fica satisfeito, titular esquecido reclama.
	var squad := world.squad(club)
	var ovrs: Array = []
	for p: Player in squad:
		ovrs.append(p.overall)
	ovrs.sort()
	var median: int = ovrs[ovrs.size() / 2] if not ovrs.is_empty() else 50
	for p: Player in squad:
		var amb := 1.0 + p.trait_sum("ambition") / 60.0
		if started.has(p.id):
			add_trust(world, p, 0.7)
		elif used.has(p.id):
			add_trust(world, p, 0.2)
		elif p.is_available() and p.overall >= median + 2:
			add_trust(world, p, -1.1 * amb)
		elif p.is_available() and p.overall >= median:
			add_trust(world, p, -0.4 * amb)
		if result == "V":
			add_trust(world, p, 0.2)
		var t := trust_of(world, p)
		p.morale = clampf(p.morale + (t - 50.0) * 0.012, 0.0, 100.0)
	_dressing_room(world, club, squad, r)
	# Laços em campo: amigos juntos entrosam, rivais juntos às vezes explodem.
	for b: Dictionary in pp["bonds"]:
		var both := started.has(int(b["a"])) and started.has(int(b["b"]))
		if not both:
			continue
		if String(b["k"]) != BOND_RIVAL:
			club.cohesion = minf(92.0, club.cohesion + 0.15)
		elif result == "D" and r.randf() < 0.18:
			var pa := world.player(int(b["a"]))
			var pb := world.player(int(b["b"]))
			if pa != null and pb != null:
				club.cohesion = maxf(30.0, club.cohesion - 1.5)
				add_bond(world, pa.id, pb.id, -6.0)
				NewsManager.post_raw(world, "Bate-boca em campo: %s x %s" % [pa.display_name(), pb.display_name()],
					"Na derrota, %s e %s discutiram feio. A rivalidade entre os dois já é pública." % [pa.display_name(), pb.display_name()], club.id, pa.id, NewsEvent.IMP_NORMAL, "clube")
	# Comissão
	club.cohesion = minf(92.0, club.cohesion + staff_level(world, "auxiliar") * 0.35)
	if r.randf() < staff_level(world, "medico") * 0.35:
		for p: Player in squad:
			if p.injury_weeks >= 2:
				p.injury_weeks -= 1
				break
	var scouted := 0
	var olheiro := staff_level(world, "olheiro")
	for tries in 12:
		if scouted >= int(olheiro * 6.0):
			break
		var q: Player = world.players.get(r.randi_range(1, maxi(1, world.next_player_id - 1)), null)
		if q != null and q.club_id != club.id and q.scout_noise != 0:
			q.scout_noise = int(q.scout_noise * 0.5)
			scouted += 1
	for role in staff(world):
		var s: Dictionary = staff(world)[role]
		if float(s.get("rel", 50.0)) < 18.0 and r.randf() < 0.1:
			_staff_quits(world, role)
			break
	# Técnico adversário
	var opp_id := f.opponent_of(club.id)
	var oc := coach_of(world, opp_id)
	if not oc.is_empty():
		var gd := (f.hg - f.ag) * (1 if side == 0 else -1)
		var d := -1.0 if absi(gd) >= 3 else 0.5
		if derby:
			d -= 2.0
		add_coach_rel(world, int(oc["id"]), d)
	# Torcida
	var sd := 1.6 if result == "V" else (-0.3 if result == "E" else -2.2)
	if derby:
		sd *= 1.8
	add_support(world, sd + (club.fan_mood - 55.0) * 0.015)
	_chant(world, r, result, hero)
	var sup := fan_support(world)
	if sup < 22.0 and r.randf() < 0.3:
		var mult := 2.0 if String(president(world, club.id).get("st", "")) == "populista" else 1.0
		club.board_confidence = clampf(club.board_confidence - 1.5 * mult, 0.0, 100.0)
		NewsManager.post_raw(world, "Protesto contra %s" % world.manager_name,
			"A %s estendeu faixas pedindo a saída do treinador. A diretoria acompanha de perto." % String(pp["fans"]["group"]), club.id, -1, NewsEvent.IMP_HIGH, "torcida")
	# Presidente
	if derby:
		add_pres_rel(world, 3.0 if result == "V" else (-3.0 if result == "D" else 0.0))
	# Reputação do treinador
	pp["mrep"] = clampf(manager_rep(world) + (0.25 if result == "V" else (-0.2 if result == "D" else 0.0)) * (club.reputation / 50.0), 5.0, 99.0)
	# Imprensa
	if r.randf() < 0.45:
		_column(world, r, f, result)
	# Ultimato e demissão no meio da temporada
	_check_job(world, r)
	# Pedidos de conversa
	return _requests(world, r)


## Vestiário como grupo, depois de cada jogo:
## - líderes (líder, cascudo, mentor) puxam o humor do grupo para o deles;
## - estrela ou titular muito insatisfeito contamina amigos e compatriotas;
## - estrangeiro com compatriotas (ou mesma língua) se adapta mais rápido; isolado no primeiro ano sofre.
static func _dressing_room(world: GameWorld, club: Club, squad: Array, r: RandomNumberGenerator) -> void:
	if squad.is_empty():
		return
	var leaders: Array = []
	for p: Player in squad:
		if (p.has_trait("lider") or p.has_trait("cascudo") or p.has_trait("mentor")) and p.squad_status <= Player.STATUS_STARTER:
			leaders.append(p)
	if not leaders.is_empty():
		var lm := 0.0
		for p: Player in leaders:
			lm += p.morale
		lm /= leaders.size()
		for p: Player in squad:
			if not leaders.has(p):
				p.morale = clampf(p.morale + (lm - p.morale) * 0.035, 0.0, 100.0)
	# Insatisfação que se espalha
	for p: Player in squad:
		if p.morale >= 28.0 or p.squad_status > Player.STATUS_STARTER:
			continue
		var hit := 0
		for q: Player in squad:
			if q.id == p.id:
				continue
			var b := bond_between(world, p.id, q.id)
			var friend := not b.is_empty() and String(b["k"]) != BOND_RIVAL
			if friend or (q.nationality == p.nationality and p.nationality != club.nation):
				q.morale = clampf(q.morale - 1.0 * q.trait_mult("morale_volatility"), 0.0, 100.0)
				hit += 1
		if hit >= 2 and r.randf() < 0.08:
			NewsManager.post_raw(world, "Clima pesado no %s" % club.short_name,
				"A insatisfação de %s já contagia parte do elenco, principalmente os mais próximos dele." % p.display_name(), club.id, p.id, NewsEvent.IMP_NORMAL, "clube")
	# Adaptação de estrangeiros: grupo de compatriotas ou mesma língua ajuda
	var langs := {}
	var nats := {}
	for p: Player in squad:
		nats[p.nationality] = int(nats.get(p.nationality, 0)) + 1
		var lg := String(DatabaseManager.nation(p.nationality).get("lang", ""))
		langs[lg] = int(langs.get(lg, 0)) + 1
	var club_lang := String(DatabaseManager.nation(club.nation).get("lang", ""))
	for p: Player in squad:
		if p.nationality == club.nation:
			continue
		var lg := String(DatabaseManager.nation(p.nationality).get("lang", ""))
		var company := int(nats.get(p.nationality, 0)) >= 2 or (lg != "" and (lg == club_lang or int(langs.get(lg, 0)) >= 2))
		if company:
			if p.morale < 62.0:
				p.morale = minf(62.0, p.morale + 0.4)
		elif world.year - p.joined_year <= 1 and p.morale > 50.0:
			p.morale = maxf(50.0, p.morale - 0.35 * p.trait_mult("morale_volatility"))


## Jogadores que saíram: amigos e pupilos sentem.
static func _squad_changes(world: GameWorld, r: RandomNumberGenerator) -> void:
	var pp := data(world)
	var club := world.user_club()
	var before: Array = pp.get("squad", [])
	var now := {}
	for pid in club.player_ids:
		now[pid] = true
	var posted := false
	for pid in before:
		if now.has(pid):
			continue
		for b: Dictionary in bonds_of(world, int(pid)):
			if String(b["k"]) == BOND_RIVAL:
				continue
			var other := world.player(bond_other(b, int(pid)))
			var gone := world.player(int(pid))
			if other == null or other.club_id != club.id:
				continue
			add_trust(world, other, -7.0 if String(b["k"]) == BOND_MENTOR else -5.0)
			other.morale = clampf(other.morale - 5.0, 0.0, 100.0)
			if not posted and gone != null:
				posted = true
				NewsManager.post_raw(world, "%s lamenta a saída de %s" % [other.display_name(), gone.display_name()],
					"\"Era mais que um companheiro\", disse %s nas redes. O vestiário sentiu a saída." % other.display_name(), club.id, other.id, NewsEvent.IMP_NORMAL, "clube")
	pp["squad"] = club.player_ids.duplicate()


static func _staff_quits(world: GameWorld, role: String) -> void:
	var s: Dictionary = staff(world).get(role, {})
	if s.is_empty():
		return
	var club := world.user_club()
	var r := rng(world, 8)
	var n := _new_staff(world, r, club, role, -10.0)
	n["rel"] = 50.0
	staff(world)[role] = n
	NewsManager.post_raw(world, "%s pede demissão" % String(s["n"]),
		"Sem sintonia com %s, %s deixou o cargo de %s. %s assume de forma interina." % [world.manager_name, String(s["n"]), String(STAFF_ROLES[role]["name"]).to_lower(), String(n["n"])], club.id, -1, NewsEvent.IMP_NORMAL, "clube")
	log_event(world, "%s (%s) saiu brigado com você." % [String(s["n"]), String(STAFF_ROLES[role]["name"]).to_lower()])


## Limite de confiança para a demissão no meio da temporada (por dificuldade; fácil nunca).
const MID_FIRE_LIMIT: Array[float] = [-1.0, 10.0, 16.0]


static func _check_job(world: GameWorld, r: RandomNumberGenerator) -> void:
	var pp := data(world)
	var club := world.user_club()
	var conf := club.board_confidence
	var turn := world.current_turn()
	if conf < BoardManager.ULTIMATUM:
		if not pp.has("ult"):
			pp["ult"] = turn
	elif conf >= BoardManager.ULTIMATUM + 6.0:
		pp.erase("ult")
	var limit: float = MID_FIRE_LIMIT[clampi(world.difficulty, 0, 2)]
	if limit < 0.0 or turn < 8 or not pp.has("ult") or turn - int(pp["ult"]) < 3:
		return
	if int(pp.get("grace", -1)) >= turn:
		return
	limit += fire_shift(world, club) * 0.6
	if conf >= limit:
		return
	if r.randf() > 0.55:
		return
	fire_user(world, "resultados")


## Demissão do usuário durante a temporada.
static func fire_user(world: GameWorld, reason: String) -> void:
	var club := world.user_club()
	var offers := BoardManager.job_offers(world, club)
	world.stats["fired"] = {"from": club.id, "offers": offers, "year": world.year, "mid": true}
	club.board_confidence = 50.0
	var pp := data(world)
	pp["mrep"] = maxf(5.0, manager_rep(world) - 6.0)
	NewsManager.post(world, "demissao", {"club": club.short_name, "manager": world.manager_name}, club.id, -1, NewsEvent.IMP_HEADLINE)
	log_event(world, "Demitido do %s (%s)." % [club.short_name, reason])


## Pedidos de conversa: jogador insatisfeito, convocação do presidente, coletiva antes de jogo grande.
static func _requests(world: GameWorld, r: RandomNumberGenerator) -> Array:
	var pp := data(world)
	var club := world.user_club()
	var turn := world.current_turn()
	var reqs: Array = pp.get("reqs", [])
	reqs = reqs.filter(func(q): return int(q["until"]) >= turn)
	var added: Array = []
	var has_kind := func(k: String, t: int) -> bool:
		for q in reqs:
			if String(q["k"]) == k and int(q.get("t", -1)) == t:
				return true
		return false
	# Jogador pede para conversar
	if reqs.size() < 3 and r.randf() < 0.35:
		var worst: Player = null
		for p: Player in world.squad(club):
			var t := trust_of(world, p)
			if t < 34.0 and p.overall >= 55 and not has_kind.call("player", p.id) and turn - int(pp["talk"].get("p%d" % p.id, -99)) >= 4:
				if worst == null or t < trust_of(world, worst):
					worst = p
		if worst != null:
			var q := {"k": "player", "t": worst.id, "until": turn + 3}
			reqs.append(q)
			added.append(q)
	# Presidente convoca
	if club.board_confidence < 38.0 and not has_kind.call("board", -1) and turn - int(pp["talk"].get("board", -99)) >= 5 and r.randf() < 0.4:
		var q := {"k": "board", "t": -1, "until": turn + 2, "summon": true}
		reqs.append(q)
		added.append(q)
	# Coletiva antes de jogo grande (ou a cada tanto)
	var nf := FixtureManager.next_fixture_for(world, club.id)
	if nf != null and not has_kind.call("press", -1) and turn - int(pp["press"].get("last", -99)) >= 3:
		var big := MatchEngine.is_derby(world, nf.home, nf.away) or club.streak_losses >= 2 or club.streak_wins >= 3 or club.board_confidence < 35.0
		if big or r.randf() < 0.25:
			var q := {"k": "press", "t": -1, "until": turn + 1}
			reqs.append(q)
			added.append(q)
	pp["reqs"] = reqs
	return added


static func requests(world: GameWorld) -> Array:
	var turn := world.current_turn()
	return Array(data(world).get("reqs", [])).filter(func(q): return int(q["until"]) >= turn)


static func clear_request(world: GameWorld, kind: String, target: int) -> void:
	var pp := data(world)
	pp["reqs"] = Array(pp.get("reqs", [])).filter(func(q): return not (String(q["k"]) == kind and int(q.get("t", -1)) == target))


## Diário das relações (o que aconteceu de marcante).
static func log_event(world: GameWorld, text: String) -> void:
	var lg: Array = data(world).get("log", [])
	lg.append({"y": world.year, "d": world.current_day(), "t": text})
	while lg.size() > 40:
		lg.pop_front()
	data(world)["log"] = lg


# ---------------------------------------------------------------------------
# Temporada
# ---------------------------------------------------------------------------

## Fim de temporada (antes da virada): balanço dos técnicos da IA, eleições, reputação do usuário.
static func on_season_end(world: GameWorld, summary: Dictionary) -> void:
	var pp := data(world)
	var r := rng(world, 9)
	for c: Club in world.clubs:
		if world.is_user_club(c.id):
			continue
		var co: Dictionary = pp["coaches"].get(c.id, {})
		if co.is_empty() or c.history.is_empty():
			continue
		var h: Dictionary = c.history.back()
		if int(h["y"]) != world.year:
			continue
		var goal := SeasonManager.goal_of(world, c.id)
		var diff := int(goal[1]) - int(h["p"])
		co["rep"] = clampf(float(co["rep"]) + clampf(diff * 0.8, -5.0, 6.0) + (6.0 if int(h["p"]) == 1 else 0.0), 5.0, 99.0)
		co["sk"] = clampf(float(co["sk"]) + r.randf_range(-1.0, 1.5), 15.0, 97.0)
		co["w"] = 0
		co["d"] = 0
		co["l"] = 0
		var pres_pat := float(PRES_STYLES.get(String(pp["pres"].get(c.id, {}).get("st", "paciente")), PRES_STYLES["paciente"])["patience"])
		var age := world.year - int(co["by"])
		if age >= 70 and r.randf() < 0.5:
			replace_coach(world, c, "")
		elif diff <= -3 and r.randf() < 0.55 / pres_pat:
			replace_coach(world, c, "temporada")
		else:
			co["job"] = clampf(float(co["job"]) * 0.5 + 35.0 + diff * 2.0, 20.0, 90.0)
	# Presidentes: fim de mandato e eleições
	for cid in pp["pres"]:
		var pr: Dictionary = pp["pres"][cid]
		if int(pr.get("term", 0)) > world.year:
			continue
		var c := world.club(int(cid))
		if c == null:
			continue
		var stays := r.randf() < (0.55 if c.fan_mood >= 50.0 else 0.3)
		if stays:
			pr["term"] = world.year + 3
			continue
		var np := _new_president(world, r, c)
		np["since"] = world.year + 1
		np["term"] = world.year + 3
		pp["pres"][cid] = np
		if world.is_user_club(int(cid)):
			NewsManager.post_raw(world, "%s é o novo presidente do %s" % [String(np["n"]), c.short_name],
				"Eleito com o discurso de um clube %s, %s substitui %s. Perfil: %s." % ["mais vencedor" if String(np["st"]) in ["exigente", "vaidoso"] else "mais equilibrado", String(np["n"]), String(pr["n"]), String(PRES_STYLES[np["st"]]["name"]).to_lower()],
				c.id, -1, NewsEvent.IMP_HEADLINE, "clube")
			log_event(world, "Eleição: %s assumiu a presidência." % String(np["n"]))
	if world.has_user():
		var u: Dictionary = summary.get("user", {})
		var d := 0.0
		if u.get("champion", false):
			d += 8.0
		elif u.get("promoted", false):
			d += 6.0
		elif u.get("goal_met", false):
			d += 3.0
		else:
			d -= 3.0
		if u.get("relegated", false):
			d -= 6.0
		for cu in u.get("cups", []):
			if cu.get("champion", false):
				d += 6.0
		pp["mrep"] = clampf(manager_rep(world) + d, 5.0, 99.0)
		# Relações esfriam um pouco nas férias; candidatos da comissão se renovam.
		for pid in pp["trust"].keys():
			var t := float(pp["trust"][pid])
			pp["trust"][pid] = t + (50.0 - t) * 0.15
		for cid in pp["crel"].keys():
			pp["crel"][cid] = float(pp["crel"][cid]) * 0.8
		pp["cands"] = {}
		pp["reqs"] = []
		pp.erase("ult")
		pp.erase("grace")
		pp.erase("offer")
		for role in staff(world):
			var s: Dictionary = staff(world)[role]
			s["sk"] = clampf(float(s["sk"]) + r.randf_range(-1.0, 2.0), 10.0, 97.0)


## Usuário assumiu outro clube (demissão ou proposta).
static func on_new_job(world: GameWorld, old_club_id: int) -> void:
	ensure(world) # monta comissão, vestiário e torcida do clube novo
	var old := world.club(old_club_id)
	if old != null and old_club_id != world.user_club_id:
		replace_coach(world, old, "usuario")
