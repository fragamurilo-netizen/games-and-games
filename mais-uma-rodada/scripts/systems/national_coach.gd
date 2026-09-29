class_name NationalCoach
extends RefCounted
## O usuário também como técnico de seleção (acumulando com o clube, como já fizeram tantos
## treinadores): convites das federações conforme a reputação dele, escolha da seleção no início da
## carreira, a lista de convocados escolhida por ele, cobrança por resultados e demissão.
##
## Tudo em world.stats["intl"]["coach"]:
##   nation (""), since, w, d, l, gf, ga, sat (confiança da federação, 0..100), list [ids da lista],
##   titles [[torneio, ano]], offers [{n: nação, y: ano}], hist [{n, from, to, w, d, l, why, titles}]

## Degraus de campanha num torneio (maior é melhor).
const STAGE_LEVEL := {"Fase de grupos": 0, "16 avos de final": 1, "Oitavas de final": 2, "Quartas de final": 3, "Semifinal": 4, "Vice": 5, "Campeã": 6}


static func state(world: GameWorld) -> Dictionary:
	var d := NationalTeamManager.data(world)
	if not d.has("coach"):
		d["coach"] = {"nation": "", "offers": [], "hist": [], "list": []}
	return d["coach"]


## Seleção que o usuário comanda ("" se nenhuma).
static func nation(world: GameWorld) -> String:
	if not world.has_user():
		return ""
	var d := NationalTeamManager.data(world)
	return String(d.get("coach", {}).get("nation", ""))


static func offers(world: GameWorld) -> Array:
	return state(world).get("offers", [])


## Reputação que a federação pede do técnico: as grandes só chamam nome consagrado.
static func required_rep(world: GameWorld, code: String) -> float:
	var rank := NationalTeamManager.rank_of(world, code)
	return clampf(84.0 - rank * 0.8, 30.0, 84.0)


static func _rep(world: GameWorld) -> float:
	return People.manager_rep(world)


static func _add_rep(world: GameWorld, v: float) -> void:
	var pp := People.data(world)
	pp["mrep"] = clampf(float(pp.get("mrep", 40.0)) + v, 1.0, 100.0)


## O que a federação espera, pela força da seleção no ranking.
static func expectation(world: GameWorld, code: String) -> String:
	var rank := NationalTeamManager.rank_of(world, code)
	if rank <= 6:
		return "Brigar por títulos: semifinal é o mínimo numa Copa"
	if rank <= 16:
		return "Classificar com folga e passar das oitavas"
	if rank <= 32:
		return "Classificar para a Copa e passar de fase"
	if rank <= 50:
		return "Brigar pela vaga na Copa"
	return "Renovar o time e somar pontos nas eliminatórias"


# ---------------------------------------------------------------------------
# Convites
# ---------------------------------------------------------------------------

## Início de temporada: federações que trocaram de técnico sondam o usuário, se a reputação dele
## bate com o tamanho da seleção. Quem já comanda uma seleção só recebe convite de uma bem maior.
static func season_offers(world: GameWorld) -> void:
	if not world.has_user():
		return
	var st := state(world)
	st["offers"] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = RngUtil.hash_i(world.world_seed, world.year, 4242)
	var rep := _rep(world)
	var cur := String(st.get("nation", ""))
	var cur_rank := NationalTeamManager.rank_of(world, cur) if cur != "" else 999
	var home_nat := String(ManagerProfile.data(world).get("nat", ""))
	var flops := _flops(world)
	var cands: Array = []
	for code in DatabaseManager.nations():
		if code == cur:
			continue
		var rank := NationalTeamManager.rank_of(world, code)
		if cur != "" and rank > cur_rank - 12:
			continue
		var need := required_rep(world, code) - (6.0 if code == home_nat else 0.0)
		if rep < need:
			continue
		var p := 0.12 + (0.4 if flops.has(code) else 0.0) + (0.15 if code == home_nat else 0.0)
		if rng.randf() < p:
			cands.append([code, rank])
	cands.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
	for c in cands.slice(0, 2):
		var code: String = c[0]
		st["offers"].append({"n": code, "y": world.year})
		InboxManager.send(world, "federacao", "Convite da seleção: %s" % DatabaseManager.nation_name(code),
			"A federação da %s procura um técnico e quer você no comando, acumulando com o clube. A seleção é a %dª do ranking.\n\nMeta: %s.\n\nO convite vale até o fim da temporada." % [DatabaseManager.nation_name(code), int(c[1]), expectation(world, code).to_lower()],
			{"k": "screen", "s": "national", "args": {"tab": "coach", "nation": code}}, -1, -1, "Federação da %s" % DatabaseManager.nation_name(code))


## Seleções que decepcionaram no último torneio (trocam de técnico com mais frequência).
static func _flops(world: GameWorld) -> Dictionary:
	var out := {}
	var tours: Array = NationalTeamManager.data(world)["tours"]
	for i in range(tours.size() - 1, maxi(-1, tours.size() - 7), -1):
		var rec: Dictionary = tours[i]
		var stages: Dictionary = rec.get("stage", {})
		for code in stages:
			if STAGE_LEVEL.get(String(stages[code]), 0) < _expected_level(world, rec, String(code)) - 1:
				out[code] = true
	return out


static func has_offer(world: GameWorld, code: String) -> bool:
	for o in offers(world):
		if String(o["n"]) == code:
			return true
	return false


## Assume a seleção (convite aceito ou escolha no início da carreira).
static func accept(world: GameWorld, code: String, quiet: bool = false) -> void:
	var st := state(world)
	if String(st.get("nation", "")) != "":
		_close(world, "Saiu para a %s" % DatabaseManager.nation_name(code))
	st["nation"] = code
	st["since"] = world.year
	for k in ["w", "d", "l", "gf", "ga"]:
		st[k] = 0
	st["sat"] = 60.0
	st["list"] = []
	st["titles"] = []
	st["offers"] = []
	if quiet:
		return
	_add_rep(world, 1.0)
	var n := NewsManager.post_raw(world, "%s é o novo técnico da %s" % [world.manager_name, DatabaseManager.nation_name(code)],
		"A federação anunciou o treinador, que vai acumular o cargo com o %s. Meta: %s." % [world.user_club().short_name, expectation(world, code).to_lower()],
		world.user_club_id, -1, NewsEvent.IMP_HEADLINE, "selecao")
	n.media = {"type": "nation", "code": code}


static func decline(world: GameWorld, code: String) -> void:
	var st := state(world)
	st["offers"] = (st.get("offers", []) as Array).filter(func(o): return String(o["n"]) != code)


static func resign(world: GameWorld) -> void:
	var code := nation(world)
	if code == "":
		return
	_close(world, "Pediu demissão")
	NewsManager.post_raw(world, "%s deixa a %s" % [world.manager_name, DatabaseManager.nation_name(code)],
		"O treinador pediu para sair e agora se dedica só ao %s." % world.user_club().short_name, world.user_club_id, -1, NewsEvent.IMP_HIGH, "selecao")


static func _close(world: GameWorld, why: String) -> void:
	var st := state(world)
	var code := String(st.get("nation", ""))
	if code == "":
		return
	if not st.has("hist"):
		st["hist"] = []
	st["hist"].append({"n": code, "from": int(st.get("since", world.year)), "to": world.year, "w": int(st.get("w", 0)), "d": int(st.get("d", 0)),
		"l": int(st.get("l", 0)), "why": why, "titles": st.get("titles", []).duplicate()})
	st["nation"] = ""
	st["list"] = []


static func _fire(world: GameWorld, why: String) -> void:
	var code := nation(world)
	_close(world, "Demitido")
	_add_rep(world, -3.0)
	var n := NewsManager.post_raw(world, "%s é demitido da %s" % [world.manager_name, DatabaseManager.nation_name(code)],
		"%s A federação vai atrás de outro nome." % why, world.user_club_id, -1, NewsEvent.IMP_HEADLINE, "selecao")
	n.media = {"type": "nation", "code": code}
	InboxManager.send(world, "federacao", "Fim do trabalho na seleção", "%s\n\nObrigado pelo trabalho. O clube segue com você." % why,
		{}, -1, -1, "Federação da %s" % DatabaseManager.nation_name(code))


# ---------------------------------------------------------------------------
# Lista de convocados
# ---------------------------------------------------------------------------

## Convocáveis da seleção: jogadores da nacionalidade com clube, sem lesão (melhores primeiro).
static func eligible(world: GameWorld, code: String) -> Array:
	var out: Array = []
	for p: Player in world.players.values():
		if p.nationality == code and p.club_id >= 0 and not p.retiring:
			out.append(p)
	out.sort_custom(func(a, b): return a.ovr_f > b.ovr_f or (a.ovr_f == b.ovr_f and a.id < b.id))
	return out


## A lista atual do técnico (sem lista escolhida, a sugestão da comissão).
static func current_list(world: GameWorld) -> Array:
	var code := nation(world)
	var out: Array = []
	for pid in state(world).get("list", []):
		var p := world.player(int(pid))
		if p != null and p.nationality == code and p.club_id >= 0:
			out.append(p)
	return out


static func suggested(world: GameWorld, code: String) -> Array:
	return NationalTeamManager.call_up(eligible(world, code).filter(func(p: Player): return p.injury_weeks == 0))


static func fill_suggested(world: GameWorld) -> void:
	var code := nation(world)
	if code != "":
		state(world)["list"] = suggested(world, code).map(func(p: Player): return p.id)


## Chama ou dispensa um jogador. Retorna false se a lista já está cheia.
static func toggle(world: GameWorld, pid: int) -> bool:
	var st := state(world)
	if (st.get("list", []) as Array).is_empty():
		st["list"] = current_list(world).map(func(p: Player): return p.id)
	var list: Array = st["list"]
	if list.has(pid):
		list.erase(pid)
		return true
	if list.size() >= NationalTeamManager.SQUAD_SIZE:
		return false
	list.append(pid)
	return true


# ---------------------------------------------------------------------------
# Resultados e cobrança
# ---------------------------------------------------------------------------

static func on_result(world: GameWorld, r: Dictionary, tag: String) -> void:
	var code := nation(world)
	if code == "" or (r["a"] != code and r["b"] != code):
		return
	var st := state(world)
	var mine_a: bool = r["a"] == code
	var gf := int(r["ga"]) if mine_a else int(r["gb"])
	var ga := int(r["gb"]) if mine_a else int(r["ga"])
	var opp := String(r["b"]) if mine_a else String(r["a"])
	st["gf"] = int(st.get("gf", 0)) + gf
	st["ga"] = int(st.get("ga", 0)) + ga
	var gap := NationalTeamManager.rank_of(world, opp) - NationalTeamManager.rank_of(world, code) # > 0: adversário mais fraco
	var weight := 0.5 if tag == "Amistoso" else 1.0
	var d := 0.0
	var won := gf > ga or (gf == ga and String(r.get("w", "")) == code)
	var lost := gf < ga or (gf == ga and String(r.get("w", "")) != "" and String(r.get("w", "")) != code)
	if won:
		st["w"] = int(st.get("w", 0)) + 1
		d = 2.0 + (2.0 if gap < -10 else 0.0)
	elif lost:
		st["l"] = int(st.get("l", 0)) + 1
		d = -3.0 - (3.0 if gap > 15 else 0.0)
	else:
		st["d"] = int(st.get("d", 0)) + 1
		d = -1.0 if gap > 15 else 0.5
	st["sat"] = clampf(float(st.get("sat", 60.0)) + d * weight, 0.0, 100.0)


## Fim das eliminatórias: vaga garantida dá fôlego; ficar fora pode custar o cargo.
static func on_campaign_closed(world: GameWorld, camp: Dictionary) -> void:
	var code := nation(world)
	if code == "" or not NationalTeamManager._in_campaign(camp, code):
		return
	var st := state(world)
	if (camp["q"] as Array).has(code):
		st["sat"] = clampf(float(st.get("sat", 60.0)) + 15.0, 0.0, 100.0)
		_add_rep(world, 1.5)
		return
	st["sat"] = clampf(float(st.get("sat", 60.0)) - 35.0, 0.0, 100.0)
	_add_rep(world, -1.5)
	var favored := NationalTeamManager.rank_of(world, code) <= 24
	if float(st["sat"]) < 30.0 or favored:
		_fire(world, "A %s ficou fora da %s %d." % [DatabaseManager.nation_name(code), NationalTeamManager.tournament_name(camp["t"]), int(camp["y"])])


static func _expected_level(world: GameWorld, rec: Dictionary, code: String) -> int:
	var teams: Array = Array(rec.get("teams", [])).duplicate()
	teams.sort_custom(func(a, b): return NationalTeamManager.elo_of(world, a) > NationalTeamManager.elo_of(world, b))
	var i := teams.find(code)
	var ko: Array = rec.get("ko", [])
	var first_ko := 6 - ko.size() # 5 rodadas de mata-mata começam nos 16 avos (1)
	if i < 0:
		return 0
	if i == 0:
		return 5
	if i < 4:
		return 4
	if i < 8:
		return 3
	if i < 16:
		return maxi(first_ko, 2)
	return first_ko if i < teams.size() / 2 else 0


## Fim de torneio: campanha contra a expectativa; título vira troféu do técnico.
static func on_tournament(world: GameWorld, rec: Dictionary) -> void:
	var code := nation(world)
	if code == "" or not (rec["teams"] as Array).has(code):
		return
	var st := state(world)
	var stage := String(rec.get("stage", {}).get(code, "Fase de grupos"))
	var got: int = STAGE_LEVEL.get(stage, 0)
	var diff := got - _expected_level(world, rec, code)
	st["sat"] = clampf(float(st.get("sat", 60.0)) + diff * 10.0, 0.0, 100.0)
	_add_rep(world, diff * 1.5)
	if stage == "Campeã":
		if not st.has("titles"):
			st["titles"] = []
		st["titles"].append([String(rec["t"]), int(rec["y"])])
		_add_rep(world, 10.0 if String(rec["t"]) == "WC" else 6.0)
		world.manager_stats["titles"] = int(world.manager_stats.get("titles", 0)) + 1
		st["sat"] = 100.0
		return
	if float(st["sat"]) < 25.0 or diff <= -3:
		_fire(world, "A campanha na %s %d (%s) ficou muito abaixo do esperado." % [rec["name"], int(rec["y"]), stage.to_lower()])
