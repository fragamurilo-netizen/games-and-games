class_name ClubAI
extends RefCounted
## Inteligência de escalação e tática (usada pela IA e pelo "escalar automaticamente" do usuário).

## Ordem de preenchimento das vagas: posições mais escassas primeiro.
const FILL_PRIORITY: Array[int] = [Pos.GK, Pos.CB, Pos.ST, Pos.RB, Pos.LB, Pos.DM, Pos.AM, Pos.RW, Pos.LW, Pos.RM, Pos.LM, Pos.CM]


static func selection_score(p: Player, pos: int) -> float:
	var cond_f := 0.72 + 0.28 * clampf(p.condition, 0.0, 100.0) / 100.0
	return p.rating_at(pos) * cond_f


## Monta os 11 titulares para uma formação. Retorna Array de ids na ordem das vagas.
## Usa uma matriz jogador×vaga pré-calculada (rápido o bastante para 80 clubes por rodada).
static func best_eleven(world: GameWorld, club: Club, fname: String, exclude: Array = []) -> Array:
	var slots: Array = DatabaseManager.formation(fname)["slots"]
	var n_slots := slots.size()
	var avail: Array = []
	for pid in club.player_ids:
		var p: Player = world.players.get(pid, null)
		if p != null and p.is_available() and not exclude.has(pid):
			avail.append(p)
	var n := avail.size()
	var slot_pos := PackedInt32Array()
	for i in n_slots:
		slot_pos.append(slots[i]["pos"])
	var m := PackedFloat32Array()
	m.resize(n * n_slots)
	for a in n:
		var p: Player = avail[a]
		var cond_f := 0.72 + 0.28 * clampf(p.condition, 0.0, 100.0) / 100.0
		for i in n_slots:
			m[a * n_slots + i] = p.rating_at(slot_pos[i]) * cond_f
	var assign := PackedInt32Array() # vaga -> índice em avail
	assign.resize(n_slots)
	assign.fill(-1)
	var used := PackedByteArray()
	used.resize(n)
	used.fill(0)
	var order: Array = []
	for pr in FILL_PRIORITY:
		for i in n_slots:
			if slot_pos[i] == pr and not order.has(i):
				order.append(i)
	for i in n_slots:
		if not order.has(i):
			order.append(i)
	for i in order:
		var best := -1
		var best_v := -1.0
		for a in n:
			if used[a] == 0 and m[a * n_slots + i] > best_v:
				best_v = m[a * n_slots + i]
				best = a
		if best >= 0:
			assign[i] = best
			used[best] = 1
	# Melhoria local: trocas entre vagas e com quem ficou de fora.
	for _pass in 2:
		var improved := false
		for i in n_slots:
			for j in range(i + 1, n_slots):
				var a1 := assign[i]
				var a2 := assign[j]
				if a1 < 0 or a2 < 0:
					continue
				if m[a2 * n_slots + i] + m[a1 * n_slots + j] > m[a1 * n_slots + i] + m[a2 * n_slots + j] + 0.5:
					assign[i] = a2
					assign[j] = a1
					improved = true
		for i in n_slots:
			var cur := assign[i]
			var cur_v := m[cur * n_slots + i] if cur >= 0 else -1.0
			for a in n:
				if used[a] == 0 and m[a * n_slots + i] > cur_v + 0.5:
					if cur >= 0:
						used[cur] = 0
					assign[i] = a
					used[a] = 1
					cur = a
					cur_v = m[a * n_slots + i]
					improved = true
		if not improved:
			break
	var result: Array = []
	for i in n_slots:
		result.append(avail[assign[i]].id if assign[i] >= 0 else -1)
	return result


static func lineup_strength(world: GameWorld, fname: String, ids: Array) -> float:
	var slots: Array = DatabaseManager.formation(fname)["slots"]
	var total := 0.0
	for i in slots.size():
		if i < ids.size() and ids[i] >= 0:
			total += selection_score(world.players[ids[i]], slots[i]["pos"])
	return total


## Banco: goleiro reserva + cobertura por setor + melhores restantes.
static func pick_bench(world: GameWorld, club: Club, starters: Array) -> Array:
	var size: int = DatabaseManager.squad_rules()["bench_size"]
	var rest: Array = []
	for pid in club.player_ids:
		var p: Player = world.players.get(pid, null)
		if p != null and p.is_available() and not starters.has(pid):
			rest.append(p)
	rest.sort_custom(func(a, b): return a.ovr_f * (0.7 + 0.3 * a.condition / 100.0) > b.ovr_f * (0.7 + 0.3 * b.condition / 100.0))
	var bench: Array = []
	for g in [Pos.G_GK, Pos.G_DEF, Pos.G_MID, Pos.G_ATT]:
		for p in rest:
			if Pos.group(p.position) == g and not bench.has(p.id):
				bench.append(p.id)
				break
	for p in rest:
		if bench.size() >= size:
			break
		if not bench.has(p.id):
			bench.append(p.id)
	return bench.slice(0, size)


static func pick_set_pieces(world: GameWorld, sheet: TeamSheet) -> void:
	var best := {"cap": [-1, -1e9], "pen": [-1, -1e9], "fk": [-1, -1e9], "ck": [-1, -1e9]}
	for pid in sheet.starters:
		var p: Player = world.player(pid)
		if p == null:
			continue
		var a := p.attrs
		var age := p.age(world.year)
		var cap := p.trait_sum("leadership") + age * 0.8 + p.ovr_f * 0.5 + minf(p.career_apps, 300) / 30.0
		var pen := a[Attr.FIN] * 0.6 + a[Attr.DEC] * 0.3 + a[Attr.INT] * 0.1 + p.trait_sum("clutch") * 20.0
		var fk := a[Attr.TEC] * 0.5 + a[Attr.FIN] * 0.3 + a[Attr.PAS] * 0.2
		var ck := a[Attr.CRU] * 0.7 + a[Attr.TEC] * 0.3
		if p.position == Pos.GK:
			pen -= 50.0
			fk -= 50.0
			ck -= 50.0
		for k in [["cap", cap], ["pen", pen], ["fk", fk], ["ck", ck]]:
			if k[1] > best[k[0]][1]:
				best[k[0]] = [pid, k[1]]
	sheet.captain = best["cap"][0]
	sheet.penalty_taker = best["pen"][0]
	sheet.freekick_taker = best["fk"][0]
	sheet.corner_taker = best["ck"][0]


## Formação ideal entre as preferidas do arquétipo (levemente favorecendo a primeira).
static func choose_formation(world: GameWorld, club: Club) -> String:
	var prefs: Array = club.arch().get("formations", ["4-4-2"])
	var best_f: String = prefs[0]
	var best_v := -1.0
	for i in prefs.size():
		var fname: String = prefs[i]
		var ids := best_eleven(world, club, fname)
		var v := lineup_strength(world, fname, ids) * (1.02 if i == 0 else 1.0)
		if v > best_v:
			best_v = v
			best_f = fname
	return best_f


static var _strength_cache: Dictionary = {}


## Força média dos titulares (para comparar com o adversário). Cacheada por dia de jogo.
static func team_strength(world: GameWorld, club: Club) -> float:
	var key := world.year * 1000 + (world.season.day if world.season != null else 0)
	var cached: Array = _strength_cache.get(club.id, [])
	if cached.size() == 2 and cached[0] == key:
		return cached[1]
	var v := _compute_strength(world, club)
	_strength_cache[club.id] = [key, v]
	return v


static func _compute_strength(world: GameWorld, club: Club) -> float:
	var squad := world.squad(club)
	squad.sort_custom(func(a, b): return a.ovr_f > b.ovr_f)
	var n := mini(11, squad.size())
	var s := 0.0
	for i in n:
		s += squad[i].ovr_f
	return s / maxf(1.0, n)


## Escalação completa da IA para um jogo.
static func prepare_ai_sheet(world: GameWorld, club: Club, opponent: Club, is_home: bool) -> TeamSheet:
	var sheet := club.sheet
	var key := world.year * 100 + world.season.day / 6
	var fresh := false
	if sheet == null or club.ai_formation_key != key or not DatabaseManager.has_formation(sheet.formation):
		sheet = TeamSheet.new()
		sheet.formation = choose_formation(world, club)
		club.ai_formation_key = key
		fresh = true
	# Reaproveita a escalação anterior se todos seguem disponíveis e descansados.
	if fresh or not _still_valid(world, club, sheet):
		sheet.starters = best_eleven(world, club, sheet.formation)
		sheet.bench = pick_bench(world, club, sheet.starters)
		pick_set_pieces(world, sheet)
	var arch := club.arch()
	sheet.style = int(arch.get("style", 0))
	var base := int(arch.get("mentality", 2))
	var mine := team_strength(world, club)
	var theirs := team_strength(world, opponent) if opponent != null else mine
	var diff := mine - theirs + (1.5 if is_home else -1.5)
	var m := base
	if diff >= 6.0:
		m = maxi(base, 3)
	elif diff <= -6.0:
		m = mini(base, 1)
	elif diff <= -3.0:
		m = mini(base, 2)
	sheet.mentality = clampi(m, 0, 4)
	sheet.intensity = 1
	sheet.pressing = 2 if sheet.style == TeamSheet.STYLE_PRESSAO else 1
	sheet.line = 2 if sheet.style == TeamSheet.STYLE_PRESSAO else (0 if sheet.mentality <= 1 else 1)
	sheet.auto_subs = true
	club.sheet = sheet
	return sheet


## Garante que a escalação do usuário é válida (lesionados/suspensos/vendidos são trocados).
## Retorna mensagens explicando as trocas automáticas.
static func validate_user_sheet(world: GameWorld, club: Club) -> Array:
	var msgs: Array = []
	if club.sheet == null or not DatabaseManager.has_formation(club.sheet.formation):
		club.sheet = auto_sheet(world, club, "")
		return msgs
	var sheet := club.sheet
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	sheet.starters.resize(slots.size())
	var used := {}
	for i in slots.size():
		var pid = sheet.starters[i]
		var p: Player = world.player(pid if pid != null else -1)
		var ok := p != null and p.club_id == club.id and p.is_available() and not used.has(p.id)
		if ok:
			used[p.id] = true
			continue
		if p != null and p.club_id == club.id:
			var why := "lesionado" if p.is_injured() else ("suspenso" if p.suspension > 0 else "indisponível")
			msgs.append("%s está %s." % [p.display_name(), why])
		sheet.starters[i] = -1
	# Preenche vagas vazias com o melhor disponível
	for i in slots.size():
		if sheet.starters[i] != null and sheet.starters[i] >= 0:
			continue
		var pos: int = slots[i]["pos"]
		var best: Player = null
		var best_v := -1.0
		for pid in club.player_ids:
			var p: Player = world.players.get(pid, null)
			if p == null or not p.is_available() or used.has(pid):
				continue
			var v := selection_score(p, pos)
			if v > best_v:
				best_v = v
				best = p
		if best != null:
			sheet.starters[i] = best.id
			used[best.id] = true
			msgs.append("%s entra como %s." % [best.display_name(), Pos.code(pos)])
		else:
			sheet.starters[i] = -1
	var bench: Array = []
	for pid in sheet.bench:
		var p: Player = world.player(pid)
		if p != null and p.club_id == club.id and p.is_available() and not used.has(pid) and not bench.has(pid):
			bench.append(pid)
	if bench.size() < int(DatabaseManager.squad_rules()["bench_size"]):
		for pid in pick_bench(world, club, sheet.starters):
			if bench.size() >= int(DatabaseManager.squad_rules()["bench_size"]):
				break
			if not bench.has(pid):
				bench.append(pid)
	sheet.bench = bench
	for key in ["captain", "penalty_taker", "freekick_taker", "corner_taker"]:
		if not sheet.starters.has(sheet.get(key)):
			pick_set_pieces(world, sheet)
			break
	return msgs


## Escalação sugerida para o usuário (mantém as instruções táticas se já existirem).
static func auto_sheet(world: GameWorld, club: Club, fname: String) -> TeamSheet:
	var old := club.sheet
	var sheet := TeamSheet.new()
	if old != null:
		sheet = old.duplicate_sheet()
	if fname != "":
		sheet.formation = fname
	elif old == null:
		sheet.formation = choose_formation(world, club)
		sheet.style = int(club.arch().get("style", 0))
		sheet.mentality = 2
	sheet.starters = best_eleven(world, club, sheet.formation)
	sheet.bench = pick_bench(world, club, sheet.starters)
	pick_set_pieces(world, sheet)
	return sheet


static func _still_valid(world: GameWorld, club: Club, sheet: TeamSheet) -> bool:
	if sheet.starters.size() != 11 or sheet.bench.is_empty():
		return false
	for pid in sheet.starters:
		var p := world.player(pid)
		if p == null or p.club_id != club.id or not p.is_available() or p.condition < 78.0:
			return false
	for pid in sheet.bench:
		var p := world.player(pid)
		if p == null or p.club_id != club.id or not p.is_available():
			return false
	return true
