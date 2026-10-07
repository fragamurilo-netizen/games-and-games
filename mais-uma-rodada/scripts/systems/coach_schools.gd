class_name CoachSchools
extends RefCounted
## Escolas de técnicos: a árvore genealógica do banco de reservas. Um técnico marcante forma uma
## escola (jeito de jogar e de trabalhar: posse, saída curta, pressão alta...). Quem foi auxiliar
## dele, ou jogou sob o comando dele e virou técnico, herda a escola com pequenas mudanças; os
## discípulos formam discípulos, e a escola vai mudando com quem vence. Escolas novas nascem no save
## quando um técnico de fora delas, ou um discípulo que já anda com as próprias pernas, acumula
## títulos grandes. O seu auxiliar também pode ser chamado para ser técnico — e aí nasce a sua escola.
## Só técnicos do mundo do jogo (nenhum nome real).
##
## Técnico (dict de People): "sch" id da escola (0 = sem escola), "mt" id de quem ele aprendeu
## (-2 = o usuário), "tr" [traços].
## world.people["sch"] = {"next": n, "list": {id: escola}, "ev": [[ano, texto]]}
## Escola: {id, n, f (fundador; -2 = usuário), fn, nat, y (fundação), par (escola de origem, 0),
##          tr (traços de hoje), tr0 (traços da fundação), t (títulos grandes dos membros), e (árvore:
##          [[id do mestre, nome, id do discípulo, nome, ano]]), fim (ano em que ficou sem ninguém)}

const TRAITS := {
	"posse": "Posse de bola", "saida": "Saída curta", "pressao": "Pressão alta", "transicao": "Contra-ataque",
	"direto": "Jogo direto", "bloco": "Bloco baixo", "pontas": "Jogo pelas pontas", "bola_parada": "Bola parada",
	"posicional": "Jogo posicional", "intensidade": "Intensidade", "base": "Aposta na base", "rodizio": "Gestão do elenco",
}
## Peso de cada traço pelo estilo de trabalho do técnico (People.COACH_STYLES).
const BY_STYLE := {
	"ofensivo": {"posse": 3.0, "pontas": 3.0, "pressao": 2.0, "posicional": 2.0, "intensidade": 1.0},
	"pragmatico": {"bloco": 3.0, "transicao": 3.0, "bola_parada": 2.0, "direto": 1.0, "rodizio": 1.0},
	"motivador": {"intensidade": 3.0, "pressao": 2.0, "transicao": 2.0, "rodizio": 2.0, "pontas": 1.0},
	"estrategista": {"posicional": 3.0, "posse": 2.0, "saida": 2.0, "bola_parada": 2.0, "rodizio": 1.0},
	"linha_dura": {"intensidade": 3.0, "bloco": 2.0, "direto": 2.0, "bola_parada": 2.0},
	"formador": {"base": 3.0, "saida": 2.0, "posse": 2.0, "posicional": 1.0, "rodizio": 1.0},
}
const FOUNDERS := 16
## Países com escola de técnicos garantida no começo do mundo (se tiverem alguém à altura).
const SCHOOL_NATIONS: Array[String] = ["ENG", "ESP", "ITA", "GER", "FRA", "POR", "NED", "BRA", "ARG", "URU", "MEX"]
const START_SHARE := 0.4 # técnicos do mundo inicial que já vêm de uma escola
const NEW_SHARE := 0.45 # técnico novo (sem mestre conhecido) que aprendeu com alguém
const KEEP := 0.8 # chance de cada traço do mestre passar para o discípulo
const MAX_SCHOOLS := 60
const EDGES_MAX := 220
## Copas que contam como título grande (continentais e o Mundial).
const BIG_CUPS: Array[String] = ["UCL", "UEL", "UECL", "LIB", "SUD", "CCC", "CAF", "AFC", "CWC"]


static func data(world: GameWorld) -> Dictionary:
	var pp := People.data(world)
	if not pp.has("sch"):
		pp["sch"] = {"next": 1, "list": {}, "ev": []}
		_seed(world)
	return pp["sch"]


static func school(world: GameWorld, id: int) -> Dictionary:
	if id <= 0:
		return {}
	return Dictionary(data(world)["list"]).get(str(id), {})


static func school_of(world: GameWorld, co: Dictionary) -> Dictionary:
	return school(world, int(co.get("sch", 0)))


static func trait_names(tr: Array) -> Array:
	var out: Array = []
	for t in tr:
		out.append(String(TRAITS.get(String(t), String(t))))
	return out


## Todos os técnicos vivos (empregados e livres).
static func all_coaches(world: GameWorld) -> Array:
	var pp := People.data(world)
	var out: Array = []
	for cid in pp.get("coaches", {}):
		out.append(pp["coaches"][cid])
	out.append_array(pp.get("free", []))
	return out


static func members(world: GameWorld, id: int) -> Array:
	var out: Array = []
	for co: Dictionary in all_coaches(world):
		if int(co.get("sch", 0)) == id:
			out.append(co)
	out.sort_custom(func(a: Dictionary, b: Dictionary): return float(a.get("rep", 0.0)) > float(b.get("rep", 0.0)))
	return out


## Discípulos diretos de um técnico (id; -2 = o usuário).
static func disciples(world: GameWorld, id: int) -> Array:
	var out: Array = []
	for co: Dictionary in all_coaches(world):
		if int(co.get("mt", 0)) == id and id != 0:
			out.append(co)
	return out


# ---------------------------------------------------------------------------
# Começo do mundo
# ---------------------------------------------------------------------------

static func _rng(world: GameWorld, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world.world_seed, world.year, salt])
	return r


## Os técnicos mais marcantes do mundo fundam as primeiras escolas; parte dos outros já aprendeu
## com um deles (mais provável do mesmo país ou da mesma confederação).
static func _seed(world: GameWorld) -> void:
	var r := _rng(world, "escolas")
	var all := all_coaches(world)
	for co: Dictionary in all:
		if not co.has("tr"):
			co["tr"] = _style_traits(r, String(co.get("st", "")))
	var ranked := all.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary): return _weight(a) > _weight(b))
	var founders: Array = []
	var per_nat := {}
	# Primeiro, o técnico mais marcante de cada grande escola de futebol do mundo; depois os melhores
	# do mundo, no máximo dois por país.
	for n in SCHOOL_NATIONS:
		for co: Dictionary in ranked:
			if String(co.get("nat", "")) == n and float(co.get("sk", 0.0)) >= 62.0:
				per_nat[n] = 1
				founders.append(co)
				break
	for co: Dictionary in ranked:
		if founders.size() >= FOUNDERS or float(co.get("sk", 0.0)) < 70.0:
			break
		var n2 := String(co.get("nat", ""))
		if founders.has(co) or int(per_nat.get(n2, 0)) >= 2:
			continue
		per_nat[n2] = int(per_nat.get(n2, 0)) + 1
		founders.append(co)
	for co: Dictionary in founders:
		_found(world, co, 0, mini(world.year - 4, _start_year(co, world.year - r.randi_range(6, 18))), false)
	if founders.is_empty():
		return
	for co: Dictionary in all:
		if int(co.get("sch", 0)) > 0 or r.randf() >= START_SHARE:
			continue
		var m := _pick_mentor(r, founders, co)
		if not m.is_empty():
			_learn(world, r, co, m)


## Ano da estreia como técnico principal (a carreira de CoachCareer), ou `fallback`.
static func _start_year(co: Dictionary, fallback: int) -> int:
	var best := 99999
	for sp in co.get("car", []):
		if String(sp.get("k", "")) == "":
			best = mini(best, int(sp.get("from", 99999)))
	return best if best < 99999 else fallback


static func _weight(co: Dictionary) -> float:
	return float(co.get("sk", 0.0)) * 0.6 + float(co.get("rep", 0.0)) * 0.4


static func _pick_mentor(r: RandomNumberGenerator, pool: Array, co: Dictionary) -> Dictionary:
	var nat := String(co.get("nat", ""))
	var conf := String(DatabaseManager.nation(nat).get("confed", ""))
	var weights: Array = []
	for m: Dictionary in pool:
		var wt := maxf(0.2, float(m.get("rep", 40.0)) / 50.0)
		var mn := String(m.get("nat", ""))
		if mn == nat:
			wt *= 4.0
		elif conf != "" and String(DatabaseManager.nation(mn).get("confed", "")) == conf:
			wt *= 1.6
		if int(m.get("id", -1)) == int(co.get("id", -2)):
			wt = 0.0
		weights.append(wt)
	var total := 0.0
	for x in weights:
		total += float(x)
	if total <= 0.0:
		return {}
	return pool[RngUtil.weighted_index(r, weights)]


## Três traços sorteados pelo estilo de trabalho.
static func _style_traits(r: RandomNumberGenerator, style: String) -> Array:
	var pool: Dictionary = BY_STYLE.get(style, BY_STYLE["ofensivo"]).duplicate()
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var k := String(RngUtil.weighted_key(r, pool))
		out.append(k)
		pool.erase(k)
	return out


## O discípulo leva a maior parte dos traços do mestre e completa com o próprio estilo.
static func _inherit(r: RandomNumberGenerator, parent: Array, style: String) -> Array:
	var out: Array = []
	for t in parent:
		if r.randf() < KEEP and not out.has(t):
			out.append(t)
	var own := _style_traits(r, style)
	for t in own:
		if out.size() >= 3:
			break
		if not out.has(t):
			out.append(t)
	return out.slice(0, 3)


static func _learn(world: GameWorld, r: RandomNumberGenerator, co: Dictionary, mentor: Dictionary) -> void:
	var mid := int(mentor.get("id", 0))
	co["mt"] = mid
	co["sch"] = int(mentor.get("sch", 0))
	co["tr"] = _inherit(r, mentor.get("tr", []), String(co.get("st", "")))
	var s := school(world, int(co["sch"]))
	if not s.is_empty():
		var e: Array = s["e"]
		var y := clampi(_start_year(co, world.year), int(s["y"]) + 1, world.year)
		e.append([mid, String(mentor.get("n", "")), int(co.get("id", 0)), String(co.get("n", "")), y])
		while e.size() > EDGES_MAX:
			e.pop_front()


static func _found(world: GameWorld, co: Dictionary, parent: int, year: int, announce: bool) -> Dictionary:
	var d: Dictionary = world.people["sch"]
	var id := int(d["next"])
	d["next"] = id + 1
	var name := String(co.get("n", "?"))
	var tr: Array = co.get("tr", [])
	var s := {"id": id, "n": "Escola %s" % _surname(name), "f": int(co.get("id", 0)), "fn": name, "nat": String(co.get("nat", "")),
		"y": year, "par": parent, "tr": tr.duplicate(), "tr0": tr.duplicate(), "t": 0, "e": [], "fim": 0}
	d["list"][str(id)] = s
	co["sch"] = id
	if announce:
		_event(world, "%s funda a %s" % [name, s["n"]])
	return s


static func _surname(full: String) -> String:
	var parts := full.split(" ", false)
	return parts[parts.size() - 1] if parts.size() > 1 else full


static func _event(world: GameWorld, text: String) -> void:
	var ev: Array = data(world)["ev"]
	ev.append([world.year, text])
	while ev.size() > 80:
		ev.pop_front()


# ---------------------------------------------------------------------------
# Técnicos novos no meio do save
# ---------------------------------------------------------------------------

## Técnico que acabou de surgir. `mentor`: o técnico com quem ele trabalhou (o chefe de quem era
## auxiliar, o técnico favorito do ex-jogador); vazio = alguém do mundo, às vezes ninguém.
## `from_user`: aprendeu com você (seu ex-auxiliar, seu ex-jogador).
static func on_new_coach(world: GameWorld, co: Dictionary, mentor: Dictionary = {}, from_user: bool = false) -> void:
	data(world)
	var r := _rng(world, "novo%d" % int(co.get("id", 0)))
	if from_user:
		var us := user_school(world, true)
		co["mt"] = -2
		co["sch"] = int(us["id"])
		co["tr"] = _inherit(r, us["tr"], String(co.get("st", "")))
		(us["e"] as Array).append([-2, world.manager_name, int(co.get("id", 0)), String(co.get("n", "")), world.year])
		_event(world, "%s, que aprendeu com você, vira técnico" % String(co.get("n", "")))
		return
	if mentor.is_empty() and r.randf() < NEW_SHARE:
		var pool: Array = []
		for c2: Dictionary in all_coaches(world):
			if float(c2.get("sk", 0.0)) >= 55.0 and int(c2.get("c", -1)) >= 0:
				pool.append(c2)
		mentor = _pick_mentor(r, pool, co)
	if mentor.is_empty():
		co["tr"] = _style_traits(r, String(co.get("st", "")))
		return
	if int(mentor.get("sch", 0)) <= 0:
		# O mestre não tinha escola: o discípulo herda o jeito, mas não há escola ainda.
		co["mt"] = int(mentor.get("id", 0))
		co["tr"] = _inherit(r, mentor.get("tr", _style_traits(r, String(mentor.get("st", "")))), String(co.get("st", "")))
		return
	_learn(world, r, co, mentor)


## A escola do usuário (criada no primeiro discípulo).
static func user_school(world: GameWorld, create: bool = false) -> Dictionary:
	var d := data(world)
	for id in d["list"]:
		if int(d["list"][id].get("f", 0)) == -2:
			return d["list"][id]
	if not create:
		return {}
	var tr := _user_traits(world)
	var fake := {"id": -2, "n": world.manager_name, "nat": world.user_nation() if world.has_user() else "", "tr": tr}
	var s := _found(world, fake, 0, world.year, true)
	return s


## Traços do usuário pelo que ele faz: formação/estilo do time e uso da base.
static func _user_traits(world: GameWorld) -> Array:
	var out: Array = []
	var club := world.user_club() if world.has_user() else null
	if club != null and club.sheet != null:
		var st := int(club.sheet.style)
		var map := {0: "posse", 1: "direto", 2: "transicao", 3: "pressao", 4: "pontas", 5: "direto"}
		if map.has(st):
			out.append(map[st])
	for t in ["posicional", "intensidade", "rodizio"]:
		if out.size() >= 3:
			break
		out.append(t)
	return out


# ---------------------------------------------------------------------------
# Fim de temporada
# ---------------------------------------------------------------------------

## Títulos grandes, escolas novas, seu auxiliar chamado para ser técnico e a escola mudando com
## quem vence. Chamado depois de CoachCareer.on_titles.
static func season_close(world: GameWorld, leagues: Dictionary, cups: Dictionary) -> void:
	var d := data(world)
	var r := _rng(world, "temporada")
	var pp := People.data(world)
	# Títulos grandes do ano (liga da elite e copas continentais/mundial)
	var champs := {}
	for lid in leagues:
		if int(DatabaseManager.league_cfg(String(lid)).get("tier", 1)) == 1:
			champs[int(leagues[lid].get("champion", -1))] = true
	for cup in cups:
		if BIG_CUPS.has(String(cup)):
			champs[int(cups[cup].get("champion", -1))] = true
	for cid in champs:
		var co: Dictionary = pp.get("coaches", {}).get(int(cid), {})
		if co.is_empty():
			continue
		co["bt"] = int(co.get("bt", 0)) + 1
		var s := school_of(world, co)
		if not s.is_empty():
			s["t"] = int(s["t"]) + 1
	# Escolas novas: quem ganha muito com jeito próprio passa a ser referência
	if (d["list"] as Dictionary).size() < MAX_SCHOOLS:
		for co: Dictionary in all_coaches(world):
			if int(co.get("bt", 0)) < 2 or float(co.get("sk", 0.0)) < 76.0 or _is_founder(world, co):
				continue
			if r.randf() >= 0.2:
				continue
			var parent := int(co.get("sch", 0))
			var ns := _found(world, co, parent, world.year, true)
			for dsc: Dictionary in disciples(world, int(co.get("id", 0))):
				dsc["sch"] = int(ns["id"])
			if parent > 0:
				_event(world, "A %s nasce da %s" % [ns["n"], school(world, parent).get("n", "")])
	# Seu auxiliar chamado para ser técnico
	_user_assistant(world, r)
	# A escola muda com quem está nela (os mais reconhecidos pesam mais)
	for id in d["list"]:
		var s2: Dictionary = d["list"][id]
		var ms := members(world, int(id))
		if ms.is_empty():
			if int(s2.get("fim", 0)) == 0 and int(s2["f"]) != -2:
				s2["fim"] = world.year
			continue
		s2["fim"] = 0
		var cnt := {}
		for co: Dictionary in ms:
			for t in co.get("tr", []):
				cnt[t] = float(cnt.get(t, 0.0)) + float(co.get("rep", 40.0)) / 50.0 + float(co.get("bt", 0)) * 0.5
		var keys := cnt.keys()
		keys.sort_custom(func(a, b): return float(cnt[a]) > float(cnt[b]))
		if keys.size() >= 3:
			s2["tr"] = keys.slice(0, 3)


static func _is_founder(world: GameWorld, co: Dictionary) -> bool:
	return int(school_of(world, co).get("f", 0)) == int(co.get("id", -1))


## O auxiliar do usuário que trabalhou bem com ele pode ser chamado para ser técnico em outro clube:
## sai da comissão (vem outro) e vai para o mercado de técnicos como alguém da sua escola.
static func _user_assistant(world: GameWorld, r: RandomNumberGenerator) -> void:
	if not world.has_user():
		return
	var staff := People.staff(world)
	var a: Dictionary = staff.get("auxiliar", {})
	if a.is_empty() or float(a.get("sk", 0.0)) < 55.0 or float(a.get("rel", 0.0)) < 55.0:
		return
	if world.year - int(a.get("hy", world.year - 3)) < 2 or r.randf() >= 0.22:
		return
	var club := world.user_club()
	var pp := People.data(world)
	var co := People._new_coach(world, r, String(a.get("nat", club.nation)), clampf(float(a["sk"]) + 6.0, 30.0, 85.0), "")
	co["n"] = String(a["n"])
	co["by"] = int(a.get("by", co["by"]))
	co["rep"] = snappedf(clampf(float(a["sk"]) * 0.7 + club.reputation * 0.25, 20.0, 80.0), 0.1)
	CoachCareer.fresh_past(world, r, co, club)
	on_new_coach(world, co, {}, true)
	pp["free"].append(co)
	var n := People._new_staff(world, r, club, "auxiliar", -5.0)
	n["rel"] = 50.0
	staff["auxiliar"] = n
	NewsManager.post_raw(world, "%s deixa a comissão para ser técnico" % String(a["n"]),
		"Auxiliar de %s, %s quer comandar o próprio time e está no mercado de técnicos. %s assume como auxiliar." % [world.manager_name, String(a["n"]), String(n["n"])],
		club.id, -1, NewsEvent.IMP_NORMAL, "clube")
	People.log_event(world, "Seu auxiliar %s saiu para ser técnico: é o começo da sua escola." % String(a["n"]))


## Linhas da árvore de uma escola, do fundador para baixo: [[geração (0 = fundador), nome, ano]].
static func tree(world: GameWorld, s: Dictionary) -> Array:
	var children := {}
	for e in s.get("e", []):
		var m := int(e[0])
		if not children.has(m):
			children[m] = []
		children[m].append([int(e[2]), String(e[3]), int(e[4])])
	var out: Array = [[0, String(s["fn"]), int(s["y"])]]
	var seen := {}
	_walk(children, int(s["f"]), 1, out, seen)
	return out


static func _walk(children: Dictionary, id: int, depth: int, out: Array, seen: Dictionary) -> void:
	if seen.has(id) or depth > 6:
		return
	seen[id] = true
	var kids: Array = children.get(id, []).duplicate()
	kids.sort_custom(func(a, b): return int(a[2]) < int(b[2]))
	for ch in kids:
		out.append([depth, String(ch[1]), int(ch[2])])
		_walk(children, int(ch[0]), depth + 1, out, seen)
