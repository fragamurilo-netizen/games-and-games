class_name CoachCareer
extends RefCounted
## Carreira dos técnicos da IA e a dança das cadeiras.
##
## Passado: quando o mundo nasce, cada clube ganha a sucessão de técnicos dos últimos anos (a
## galeria de técnicos históricos) e cada técnico ganha as passagens dele, com campanha, títulos
## (os campeões do histórico batem com quem estava no banco) e como terminou cada trabalho.
## Quem começa a carreira passa antes pela base e pelo cargo de auxiliar; boa parte foi jogador.
## Nas ligas que demitem muito, os trabalhos são curtos e o mesmo ano pode ter dois técnicos.
##
## Presente: cada troca de comando entra no registro de movimentações (quem saiu, por quê,
## quem chegou e de onde, com a multa paga quando o técnico foi tirado de outro clube).
##
## Tudo fica em world.people:
##   coaches[*]["car"] passagens [{c, cn, from, to (0 = atual), w, d, l, t [chaves], e, dst, k}]
##     k: "" técnico, "int" interino, "aux" auxiliar, "base" base; e: código de saída (END_TEXT)
##   coaches[*]["pl"] carreira de jogador {pos, cl [clubes], a, g, sel, to} ({} = não foi jogador)
##   moves  movimentações [{y, d, c, o, oi, n, ni, why, fr, fee, i}]
##   cc     versão deste módulo

const VERSION := 1
## Anos para trás na sucessão de técnicos de cada clube.
const PAST_YEARS := 14
const MOVES_MAX := 800
## Código de saída pelo motivo da troca (People.replace_coach).
const END_BY_REASON := {"resultados": "dem", "temporada": "dem", "": "apo", "proposta": "sai", "res": "res", "efetivo": "int", "perdeu": "sai"}
const END_TEXT := {"dem": "Demitido", "sai": "Saiu para o %s", "res": "Pediu demissão", "fim": "Fim de ciclo", "apo": "Aposentou-se",
	"usr": "Deu lugar a %s", "int": "Interino", "prom": "Promovido a técnico"}
const WHY_TEXT := {"resultados": "demitido", "temporada": "demitido", "": "aposentado", "proposta": "saiu", "res": "pediu demissão",
	"efetivo": "fim da interinidade", "perdeu": "tirado por outro clube", "usuario": "saída do técnico", "efe": "interino efetivado", "usr": "chegada de %s"}
const PLAYER_POS: Array[String] = ["goleiro", "zagueiro", "lateral", "volante", "meia", "ponta", "atacante"]


static func ensure(world: GameWorld) -> void:
	var pp: Dictionary = world.people
	if int(pp.get("cc", 0)) >= VERSION or not pp.has("coaches"):
		return
	pp["cc"] = VERSION
	pp["moves"] = []
	_build(world)


# ---------------------------------------------------------------------------
# Passado
# ---------------------------------------------------------------------------

static func _build(world: GameWorld) -> void:
	var pp: Dictionary = world.people
	var r := RandomNumberGenerator.new()
	r.seed = RngUtil.hash_i(world.world_seed, 8081, 31337)
	var ctx := _context(world)
	var y1 := world.year
	var y0 := y1 - PAST_YEARS
	var pool: Array = []
	for cid in pp["coaches"]:
		pool.append(pp["coaches"][cid])
	pool.append_array(pp["free"])
	var by_nat := {}
	var busy := {} # id do técnico -> {meia-temporada: true}
	var occ: Dictionary = ctx["occ"] # "clube:meia" -> true (um técnico por clube por vez)
	for co: Dictionary in pool:
		co["car"] = []
		_playing_career(world, r, ctx, co)
		var nat := String(co.get("nat", ""))
		if not by_nat.has(nat):
			by_nat[nat] = []
		by_nat[nat].append(co)
		var b := {}
		var cid := int(co.get("c", -1))
		if cid >= 0:
			var club := world.club(cid)
			for h in range(int(co["since"]) * 2, y1 * 2 + 2):
				b[h] = true
				occ["%d:%d" % [cid, h]] = true
			var cur_sp := _spell(club, int(co["since"]), 0)
			if int(co["since"]) < y1:
				_campaign(r, ctx, club, cur_sp, int(co["since"]) * 2, y1 * 2 - 1)
			co["car"].append(cur_sp)
		busy[int(co["id"])] = b
	# Sucessão de cada clube, dos grandes para os pequenos (os grandes escolhem primeiro).
	var clubs: Array = world.clubs.duplicate()
	clubs.sort_custom(func(a, b): return a.reputation > b.reputation)
	for club: Club in clubs:
		var cur: Dictionary = pp["coaches"].get(club.id, {})
		var h := (int(cur["since"]) if not cur.is_empty() else y1) * 2 - 1
		var gallery: Array = []
		var th := float(People.TRIGGER_HAPPY.get(club.nation, 1.0))
		var churn := clampf((th - 1.0) * 1.2 + (50.0 - ClubDNA.patience(club)) / 100.0, -0.3, 0.9)
		while h >= y0 * 2:
			# Duração em meias temporadas: nas ligas impacientes, meio ano já é muito.
			var span: int = [1, 2, 3, 4, 6, 8][RngUtil.weighted_index(r, [6.0 + churn * 30.0, 22.0 + churn * 10.0, 14.0, 22.0 - churn * 8.0, 18.0 - churn * 12.0, 12.0 - churn * 10.0])]
			var h0 := h - span + 1
			var co := _pick(r, world, by_nat, busy, club, h0, h, y1)
			var from := h0 / 2
			var to := h / 2
			var sp := _spell(club, from, to)
			_campaign(r, ctx, club, sp, h0, h)
			for k in range(h0, h + 1):
				occ["%d:%d" % [club.id, k]] = true
			var name := ""
			var id := -1
			if co.is_empty():
				name = People._person_name(r, club.nation if r.randf() < 0.85 else RngUtil.pick(r, ["ARG", "POR", "ESP", "ITA", "URU"]))
			else:
				name = String(co["n"])
				id = int(co["id"])
				for k in range(h0, h + 1):
					busy[id][k] = true
				co["car"].append(sp)
			gallery.push_front([name, from, to, int(sp["w"]), int(sp["d"]), int(sp["l"]), id, -1, (sp["t"] as Array).size()])
			h = h0 - 1
		var cr := FootballMemory.club_records(world, club.id)
		var all: Array = gallery + cr["coaches"]
		cr["coaches"] = all.slice(maxi(0, all.size() - FootballMemory.COACHES_MAX))
	# Cada técnico: começo de carreira (base, auxiliar, clubes menores) e como saiu de cada lugar.
	for co: Dictionary in pool:
		_early_career(world, r, ctx, co, y0)
		_endings(world, r, co)


## Campeões por ano e clube, clubes por país e nível médio das ligas.
static func _context(world: GameWorld) -> Dictionary:
	var champs := {}
	for s: Dictionary in world.history:
		var y := int(s.get("y", 0))
		var m := {}
		for lid in s.get("leagues", {}):
			var cid := int(s["leagues"][lid].get("champion", -1))
			if cid >= 0:
				if not m.has(cid):
					m[cid] = []
				m[cid].append("L:" + String(lid))
		for cup in s.get("cups", {}):
			var cid2 := int(s["cups"][cup].get("champion", -1))
			if cid2 >= 0:
				if not m.has(cid2):
					m[cid2] = []
				m[cid2].append(CupManager.title_key(String(cup)))
		champs[y] = m
	var nations := {}
	var lsum := {}
	for c: Club in world.clubs:
		if not nations.has(c.nation):
			nations[c.nation] = []
		nations[c.nation].append(c)
		var acc: Array = lsum.get(c.league_id, [0.0, 0])
		lsum[c.league_id] = [float(acc[0]) + c.reputation, int(acc[1]) + 1]
	var lmid := {}
	for lid in lsum:
		lmid[lid] = float(lsum[lid][0]) / maxf(1.0, float(lsum[lid][1]))
	return {"champs": champs, "nations": nations, "lmid": lmid, "occ": {}}


static func _spell(club: Club, from: int, to: int, kind: String = "") -> Dictionary:
	var sp := {"c": club.id if club != null else -1, "cn": club.short_name if club != null else "", "from": from, "to": to, "w": 0, "d": 0, "l": 0, "t": []}
	if kind != "":
		sp["k"] = kind
	return sp


## Técnico do passado para o clube entre duas meias temporadas ({} = alguém que já parou).
static func _pick(r: RandomNumberGenerator, world: GameWorld, by_nat: Dictionary, busy: Dictionary, club: Club, h0: int, h1: int, y1: int) -> Dictionary:
	# Quanto mais antigo, maior a chance de ser um técnico que já se aposentou.
	if r.randf() < 0.18 + float(y1 * 2 - h1) / 60.0:
		return {}
	var cands: Array = by_nat.get(club.nation, []).duplicate()
	var foreign: Array = []
	for nat in by_nat:
		if nat != club.nation:
			foreign.append(nat)
	for _i in 3:
		if foreign.is_empty():
			break
		var arr: Array = by_nat[RngUtil.pick(r, foreign)]
		if not arr.is_empty():
			cands.append(arr[r.randi_range(0, arr.size() - 1)])
	var best: Dictionary = {}
	var best_score := -18.0
	for co: Dictionary in cands:
		if world.year - int(co.get("by", 0)) - (y1 - h0 / 2) < 34:
			continue # jovem demais para ser técnico naquela época
		var b: Dictionary = busy[int(co["id"])]
		var free := true
		for k in range(h0, h1 + 1):
			if b.has(k):
				free = false
				break
		if not free:
			continue
		# A reputação cresce com a carreira: antes, ele valia menos.
		var rep_then := float(co.get("rep", 40.0)) - float(y1 - h1 / 2) * 0.7
		if rep_then > club.reputation + 12.0:
			continue
		var score := -absf(rep_then - club.reputation * 0.95) + (8.0 if String(co.get("nat", "")) == club.nation else 0.0) + r.randf() * 10.0
		if score > best_score:
			best_score = score
			best = co
	return best


## Campanha de um trabalho: jogos pela liga e copas, aproveitamento pelo tamanho do clube e títulos.
static func _campaign(r: RandomNumberGenerator, ctx: Dictionary, club: Club, sp: Dictionary, h0: int, h1: int) -> void:
	var rounds := CareerBackfill._rounds(club.league_id)
	var mid := float(ctx["lmid"].get(club.league_id, club.reputation))
	var base := clampf(0.36 + (club.reputation - mid) * 0.012 + r.randfn(0.0, 0.05), 0.14, 0.7)
	var w := 0
	var d := 0
	var l := 0
	var titles: Array = sp["t"]
	for h in range(h0, h1 + 1):
		var y := h / 2
		var won: Array = ctx["champs"].get(y, {}).get(club.id, [])
		var wp := base
		for k in won:
			if String(k).begins_with("L:"):
				wp = maxf(wp, r.randf_range(0.58, 0.72))
		var g := int(round((rounds + 8) / 2.0))
		var gw := int(round(g * clampf(wp + r.randfn(0.0, 0.04), 0.08, 0.8)))
		var gd := int(round((g - gw) * r.randf_range(0.35, 0.5)))
		w += gw
		d += gd
		l += maxi(0, g - gw - gd)
		# O título fica com quem estava no banco na reta final (a segunda metade do ano).
		if h % 2 == 1:
			for k in won:
				titles.append(k)
	sp["w"] = w
	sp["d"] = d
	sp["l"] = l


## Carreira de jogador de quem virou técnico (cerca de dois terços jogaram profissionalmente).
static func _playing_career(world: GameWorld, r: RandomNumberGenerator, ctx: Dictionary, co: Dictionary) -> void:
	if co.has("pl") or int(co.get("pid", -1)) >= 0:
		return
	if r.randf() > 0.68:
		co["pl"] = {}
		return
	var pos: String = PLAYER_POS[r.randi_range(0, PLAYER_POS.size() - 1)]
	var lvl := float(co.get("rep", 50.0)) * 0.85 + r.randf_range(-18.0, 14.0)
	var nat := String(co.get("nat", ""))
	var pool: Array = ctx["nations"].get(nat, [])
	var names: Array = []
	var n := r.randi_range(2, 5)
	for _i in n * 3:
		if names.size() >= n or pool.is_empty():
			break
		var c: Club = pool[r.randi_range(0, pool.size() - 1)]
		if absf(c.reputation - lvl) <= 14.0 and not names.has(c.short_name):
			names.append(c.short_name)
	if names.is_empty():
		var foreign: Dictionary = (DatabaseManager.get_data("foreign_clubs") as Dictionary).get("clubs", {}) if DatabaseManager.get_data("foreign_clubs") is Dictionary else {}
		var arr: Array = foreign.get(nat, [])
		for _i in mini(3, arr.size()):
			var e: Array = arr[r.randi_range(0, arr.size() - 1)]
			if not names.has(String(e[0])):
				names.append(String(e[0]))
	if names.is_empty():
		co["pl"] = {}
		return
	var apps := r.randi_range(110, 540)
	var per := {"goleiro": 0.0, "zagueiro": 0.05, "lateral": 0.05, "volante": 0.06, "meia": 0.18, "ponta": 0.25, "atacante": 0.42}
	var sel := 0
	if lvl >= 64.0 and r.randf() < 0.45:
		sel = r.randi_range(2, 45)
	co["pl"] = {"pos": pos, "cl": names, "a": apps, "g": int(round(apps * float(per[pos]) * r.randf_range(0.6, 1.3))), "sel": sel, "to": int(co.get("by", world.year - 50)) + r.randi_range(31, 37)}


## Antes do primeiro trabalho em que aparece: base, auxiliar e clubes menores (antes da janela
## reconstruída, sem esbarrar em outro técnico no mesmo clube).
static func _early_career(world: GameWorld, r: RandomNumberGenerator, ctx: Dictionary, co: Dictionary, y0: int) -> void:
	var car: Array = co["car"]
	car.sort_custom(func(a, b): return int(a["from"]) < int(b["from"]))
	var by := int(co.get("by", world.year - 50))
	var first := int(car[0]["from"]) if not car.is_empty() else world.year
	var pl: Dictionary = co.get("pl", {})
	var start := maxi(by + 30, int(pl.get("to", by + 33)) + r.randi_range(0, 2))
	var pre: Array = []
	var nat := String(co.get("nat", ""))
	var pool: Array = ctx["nations"].get(nat, [])
	# Técnico em clubes menores antes da janela
	var y := mini(first, y0) - 1
	var head_start := start + r.randi_range(2, 6)
	var rep := float(co.get("rep", 40.0))
	var occ: Dictionary = ctx["occ"]
	while y >= head_start and not pool.is_empty() and pre.size() < 5:
		var span := r.randi_range(1, 3)
		var from := maxi(head_start, y - span + 1)
		var lvl := rep - float(world.year - y) * 0.9 - 4.0
		var club: Club = null
		for _i in 8:
			var c: Club = pool[r.randi_range(0, pool.size() - 1)]
			if absf(c.reputation - lvl) > 12.0:
				continue
			var taken := false
			for k in range(from * 2, y * 2 + 2):
				if occ.has("%d:%d" % [c.id, k]):
					taken = true
					break
			if not taken:
				club = c
				break
		if club != null:
			var sp := _spell(club, from, y)
			_campaign(r, ctx, club, sp, from * 2, y * 2 + 1)
			for k in range(from * 2, y * 2 + 2):
				occ["%d:%d" % [club.id, k]] = true
			pre.push_front(sp)
		y = from - 1 - (r.randi_range(0, 1) if r.randf() < 0.3 else 0)
	# Antes de ser técnico: base e auxiliar (quase todos passam por um dos dois).
	var first_head := int(pre[0]["from"]) if not pre.is_empty() else first
	if first_head - start >= 2 and not pool.is_empty():
		var c2: Club = pool[r.randi_range(0, pool.size() - 1)]
		var aux_from := maxi(start, first_head - r.randi_range(2, 5))
		pre.push_front(_spell(c2, aux_from, first_head - 1, "aux" if r.randf() < 0.65 else "base"))
		if aux_from - start >= 2 and r.randf() < 0.5:
			var c3: Club = pool[r.randi_range(0, pool.size() - 1)]
			pre.push_front(_spell(c3, start, aux_from - 1, "base"))
	co["car"] = pre + car


## Como terminou cada trabalho: trocou por um clube maior, caiu, pediu para sair ou fechou o ciclo.
static func _endings(world: GameWorld, r: RandomNumberGenerator, co: Dictionary) -> void:
	var car: Array = co["car"]
	var fired := 0
	for i in car.size():
		var sp: Dictionary = car[i]
		if int(sp["to"]) == 0:
			continue
		var k := String(sp.get("k", ""))
		if k == "aux" or k == "base":
			sp["e"] = "prom" if i + 1 < car.size() else ""
			continue
		var games := int(sp["w"]) + int(sp["d"]) + int(sp["l"])
		var pct := (int(sp["w"]) * 3 + int(sp["d"])) / maxf(1.0, games * 3.0)
		var nxt: Dictionary = car[i + 1] if i + 1 < car.size() else {}
		var here := world.club(int(sp["c"]))
		var there := world.club(int(nxt.get("c", -1))) if not nxt.is_empty() else null
		if there != null and here != null and int(nxt["from"]) <= int(sp["to"]) + 1 and there.reputation > here.reputation + 4.0 and pct >= 0.45:
			sp["e"] = "sai"
			sp["dst"] = there.short_name
		elif pct < 0.42 or r.randf() < 0.45:
			sp["e"] = "dem"
			fired += 1
		elif not (sp["t"] as Array).is_empty() and int(sp["to"]) - int(sp["from"]) >= 2:
			sp["e"] = "fim"
		else:
			sp["e"] = "res" if r.randf() < 0.4 else "fim"
	co["fired"] = fired


## Técnico que surge agora (sem passado no mundo): jogador, base e auxiliar. `local` = auxiliar
## do próprio clube (o interino).
static func fresh_past(world: GameWorld, r: RandomNumberGenerator, co: Dictionary, club: Club, local: bool = false) -> void:
	var ctx := {"nations": {}}
	var arr: Array = []
	for c: Club in world.clubs:
		if c.nation == String(co.get("nat", "")):
			arr.append(c)
	ctx["nations"][String(co.get("nat", ""))] = arr
	_playing_career(world, r, ctx, co)
	var car: Array = []
	var by := int(co.get("by", world.year - 45))
	var pl: Dictionary = co.get("pl", {})
	var start := clampi(int(pl.get("to", by + 34)) + r.randi_range(0, 2), by + 28, world.year - 1)
	if local or arr.is_empty():
		car.append(_spell(club, maxi(start, world.year - r.randi_range(2, 8)), world.year, "aux"))
	else:
		var c: Club = arr[r.randi_range(0, arr.size() - 1)]
		var mid := clampi(start + r.randi_range(2, 6), start, world.year)
		if mid > start:
			car.append(_spell(c, start, mid - 1, "base"))
		car.append(_spell(arr[r.randi_range(0, arr.size() - 1)], mid, world.year, "aux"))
	for sp: Dictionary in car:
		sp["e"] = "prom"
	co["car"] = car


# ---------------------------------------------------------------------------
# Presente
# ---------------------------------------------------------------------------

static func _open(co: Dictionary) -> Dictionary:
	var car: Array = co.get("car", [])
	if not car.is_empty() and int(car.back()["to"]) == 0:
		return car.back()
	return {}


## Trabalho em andamento ({} se não tem).
static func current_spell(co: Dictionary) -> Dictionary:
	return _open(co)


## Novo trabalho (técnico, interino).
static func open_spell(world: GameWorld, co: Dictionary, club: Club, kind: String = "") -> void:
	if not co.has("car"):
		co["car"] = []
	co["car"].append(_spell(club, world.year, 0, kind))


## Soma a campanha da temporada ao trabalho atual (antes de zerar V-E-D no fim do ano).
static func bank(co: Dictionary) -> void:
	var sp := _open(co)
	if sp.is_empty():
		return
	for k in ["w", "d", "l"]:
		sp[k] = int(sp[k]) + int(co.get(k, 0))


## Fecha o trabalho atual com o motivo da saída.
static func close_spell(world: GameWorld, co: Dictionary, end: String, dst: String = "") -> void:
	var sp := _open(co)
	if sp.is_empty():
		return
	bank(co)
	sp["to"] = world.year
	sp["e"] = end
	if dst != "":
		sp["dst"] = dst


## Interino efetivado: o trabalho vira de técnico de verdade.
static func confirm_interim(co: Dictionary) -> void:
	var sp := _open(co)
	if not sp.is_empty():
		sp.erase("k")
		sp["ef"] = true


## Títulos do ano para quem está no banco dos campeões (chamado antes do balanço dos técnicos).
static func on_titles(world: GameWorld, leagues: Dictionary, cups: Dictionary) -> void:
	var pp: Dictionary = world.people
	if not pp.has("coaches"):
		return
	var won := {}
	for lid in leagues:
		var cid := int(leagues[lid].get("champion", -1))
		if cid >= 0:
			if not won.has(cid):
				won[cid] = []
			won[cid].append("L:" + String(lid))
	for cup in cups:
		var cid2 := int(cups[cup].get("champion", -1))
		if cid2 >= 0:
			if not won.has(cid2):
				won[cid2] = []
			won[cid2].append(CupManager.title_key(String(cup)))
	for cid in won:
		if world.is_user_club(int(cid)):
			continue
		var co: Dictionary = pp["coaches"].get(int(cid), {})
		var sp := _open(co)
		if sp.is_empty():
			continue
		for k in won[cid]:
			sp["t"].append(k)


## Registra uma troca de comando.
static func log_move(world: GameWorld, club: Club, old: Dictionary, new_coach: Dictionary, why: String, from_club: int = -1, fee: int = 0) -> void:
	var pp: Dictionary = world.people
	if not pp.has("moves"):
		pp["moves"] = []
	var mv: Array = pp["moves"]
	var e := {"y": world.year, "d": world.current_day(), "c": club.id, "o": String(old.get("n", "")), "oi": int(old.get("id", -1)),
		"n": String(new_coach.get("n", "")), "ni": int(new_coach.get("id", -1)), "why": why, "fr": from_club, "fee": fee}
	if world.season == null or world.season.finished:
		e["fim"] = true
	if bool(new_coach.get("int", false)):
		e["i"] = true
	mv.append(e)
	while mv.size() > MOVES_MAX:
		mv.pop_front()


static func moves(world: GameWorld) -> Array:
	return world.people.get("moves", [])


## Técnico pelo id, empregado ou livre ({} se não existe mais).
static func find(world: GameWorld, id: int) -> Dictionary:
	var pp := People.data(world)
	for cid in pp["coaches"]:
		if int(pp["coaches"][cid].get("id", -1)) == id:
			return pp["coaches"][cid]
	for co: Dictionary in pp["free"]:
		if int(co.get("id", -1)) == id:
			return co
	return {}


## Números da carreira (inclui a temporada em andamento): {g, w, d, l, t, clubs, dem}.
static func totals(co: Dictionary) -> Dictionary:
	var w := 0
	var d := 0
	var l := 0
	var t := 0
	var dem := 0
	var clubs := {}
	for sp: Dictionary in co.get("car", []):
		var k := String(sp.get("k", ""))
		if k == "aux" or k == "base":
			continue
		w += int(sp["w"])
		d += int(sp["d"])
		l += int(sp["l"])
		t += (sp["t"] as Array).size()
		clubs[String(sp["cn"])] = true
		if String(sp.get("e", "")) == "dem":
			dem += 1
	if not _open(co).is_empty():
		w += int(co.get("w", 0))
		d += int(co.get("d", 0))
		l += int(co.get("l", 0))
	return {"g": w + d + l, "w": w, "d": d, "l": l, "t": t, "clubs": clubs.size(), "dem": dem}


static func end_text(sp: Dictionary) -> String:
	var e := String(sp.get("e", ""))
	if e == "":
		return ""
	var t := String(END_TEXT.get(e, e))
	if t.find("%s") >= 0:
		t = t % String(sp.get("dst", "outro clube"))
	return t


static func role_text(sp: Dictionary) -> String:
	match String(sp.get("k", "")):
		"aux":
			return "Auxiliar técnico"
		"base":
			return "Técnico da base"
		"int":
			return "Técnico interino"
	return "Técnico" + (" (efetivado)" if bool(sp.get("ef", false)) else "")


static func player_text(co: Dictionary) -> String:
	var pl: Dictionary = co.get("pl", {})
	if pl.is_empty():
		return "Não foi jogador profissional."
	var cl: Array = pl.get("cl", [])
	var s := "Ex-%s, jogou por %s" % [String(pl["pos"]), ", ".join(cl.slice(0, cl.size() - 1)) + " e " + String(cl.back()) if cl.size() > 1 else String(cl[0])]
	s += ". %d jogos e %d gols; parou em %d" % [int(pl.get("a", 0)), int(pl.get("g", 0)), int(pl.get("to", 0))]
	if int(pl.get("sel", 0)) > 0:
		s += "; %d jogos pela seleção" % int(pl["sel"])
	return s + "."


static func why_text(world: GameWorld, e: Dictionary) -> String:
	var why := String(e.get("why", ""))
	var t := String(WHY_TEXT.get(why, why))
	if t.find("%s") >= 0:
		t = t % world.manager_name
	return t


## Fim de temporada: técnicos livres muito velhos ou esquecidos param.
static func retire_free(world: GameWorld, r: RandomNumberGenerator) -> void:
	var pp: Dictionary = world.people
	var keep: Array = []
	for co: Dictionary in pp["free"]:
		var age := world.year - int(co.get("by", world.year - 50))
		var idle := world.year - _last_job_year(co)
		if age >= 72 or (age >= 64 and r.randf() < 0.2) or (idle >= 4 and float(co.get("rep", 40.0)) < 40.0 and r.randf() < 0.4):
			if float(co.get("rep", 0.0)) >= 60.0 and world.has_user() and String(co.get("nat", "")) == world.user_club().nation:
				NewsManager.post_raw(world, "%s encerra a carreira de técnico" % String(co["n"]),
					"Aos %d anos, %s pendura a prancheta depois de %d trabalhos e %d título(s)." % [age, String(co["n"]), totals(co)["clubs"], totals(co)["t"]],
					-1, -1, NewsEvent.IMP_NORMAL, "tecnicos")
			continue
		keep.append(co)
	pp["free"] = keep


static func _last_job_year(co: Dictionary) -> int:
	var car: Array = co.get("car", [])
	if car.is_empty():
		return int(co.get("since", 0))
	return int(car.back()["to"]) if int(car.back()["to"]) > 0 else 9999
