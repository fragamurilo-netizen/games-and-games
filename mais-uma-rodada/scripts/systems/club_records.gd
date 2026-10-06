class_name ClubRecords
extends RefCounted
## Memória longa dos clubes: melhor 11 de cada temporada e de sempre, e o histórico completo de
## transferências (o world.transfer_log só guarda duas temporadas; o resto vai para club.tr_hist).
## O técnico também guarda as próprias negociações em world.stats["mgr_tr"].

const KEEP_PER_SEASON := 16 # jogadores guardados por clube e temporada (os que mais jogaram)
const KEEP_TRANSFERS := 80 # transferências guardadas por clube (as mais recentes)
const MAX_SEASONS := 40

## Entrada compacta de temporada: [id, nome, posição, jogos, gols, assistências, nota×100, overall]
enum { E_ID, E_NAME, E_POS, E_APPS, E_GOALS, E_ASSISTS, E_RATING, E_OVR }


## Nota média da temporada somando liga e copas.
static func rating(p: Player, apps: int) -> float:
	if apps <= 0:
		return 0.0
	var rsum := float(p.stats[Player.S_RATING_SUM])
	for k in p.cup_stats:
		rsum += float((p.cup_stats[k] as PackedInt32Array)[Player.C_RATING])
	return rsum / 10.0 / apps


# ---------------------------------------------------------------------------
# Gravação
# ---------------------------------------------------------------------------

## Fim de temporada: guarda os principais jogadores de cada clube (antes de zerar os números).
static func snapshot_season(world: GameWorld) -> void:
	var key := str(world.year)
	for c: Club in world.clubs:
		if c == null or c.player_ids.is_empty():
			continue
		var rows: Array = []
		for p: Player in world.squad(c):
			var t := p.season_totals()
			if int(t[0]) <= 0:
				continue
			rows.append([p.id, p.display_name(), p.position, int(t[0]), int(t[1]), int(t[2]), int(round(rating(p, int(t[0])) * 100.0)), p.overall])
		rows.sort_custom(func(a, b): return int(a[E_APPS]) > int(b[E_APPS]) or (int(a[E_APPS]) == int(b[E_APPS]) and int(a[E_RATING]) > int(b[E_RATING])))
		if rows.size() > KEEP_PER_SEASON:
			rows = rows.slice(0, KEEP_PER_SEASON)
		c.xi_hist[key] = rows
		if c.xi_hist.size() > MAX_SEASONS:
			var ks: Array = c.xi_hist.keys()
			ks.sort()
			c.xi_hist.erase(ks[0])


## Antes de podar o transfer_log: o que vai sair passa para o histórico dos dois clubes.
static func archive_transfers(world: GameWorld, keep_from_year: int) -> void:
	for t: Transfer in world.transfer_log:
		if t.year >= keep_from_year:
			continue
		_push(world.club(t.from_id) if t.from_id >= 0 else null, t)
		_push(world.club(t.to_id) if t.to_id >= 0 else null, t)


static func _push(c: Club, t: Transfer) -> void:
	if c == null:
		return
	c.tr_hist.append(t.to_dict())
	if c.tr_hist.size() > KEEP_TRANSFERS:
		c.tr_hist = c.tr_hist.slice(c.tr_hist.size() - KEEP_TRANSFERS)


## Negociação concluída: se envolve o clube do técnico, entra na carreira dele.
static func on_transfer(world: GameWorld, t: Transfer) -> void:
	if not world.has_user():
		return
	var uid := world.user_club_id
	if t.from_id != uid and t.to_id != uid:
		return
	var d := t.to_dict()
	d["uc"] = uid
	var uc := world.user_club()
	d["ucn"] = uc.short_name if uc != null else ""
	var lst: Array = world.stats.get("mgr_tr", [])
	lst.append(d)
	world.stats["mgr_tr"] = lst


# ---------------------------------------------------------------------------
# Transferências
# ---------------------------------------------------------------------------

## Tudo o que o clube comprou e vendeu (mais recente primeiro).
static func club_transfers(world: GameWorld, c: Club) -> Array:
	var out: Array = []
	for d: Dictionary in c.tr_hist:
		out.append(Transfer.from_dict(d))
	for t: Transfer in world.transfer_log:
		if t.from_id == c.id or t.to_id == c.id:
			out.append(t)
	out.sort_custom(func(a: Transfer, b: Transfer): return a.year > b.year or (a.year == b.year and a.day > b.day))
	return out


## Negociações do técnico em todos os clubes que comandou: [[Transfer, id do clube dele]].
static func manager_transfers(world: GameWorld) -> Array:
	var out: Array = []
	for d: Dictionary in world.stats.get("mgr_tr", []):
		out.append([Transfer.from_dict(d), int(d.get("uc", -1)), String(d.get("ucn", ""))])
	out.sort_custom(func(a, b): return (a[0] as Transfer).year > (b[0] as Transfer).year or ((a[0] as Transfer).year == (b[0] as Transfer).year and (a[0] as Transfer).day > (b[0] as Transfer).day))
	return out


# ---------------------------------------------------------------------------
# Melhor 11
# ---------------------------------------------------------------------------

## Anos com dados do clube (mais recente primeiro), incluindo a temporada em andamento.
static func years(world: GameWorld, c: Club) -> Array:
	var ys := {}
	for k in c.xi_hist.keys():
		ys[int(k)] = true
	for k in c.squad_archive.keys():
		ys[int(k)] = true
	ys[world.year] = true
	var out: Array = ys.keys()
	out.sort()
	out.reverse()
	return out


## Entradas de uma temporada no formato compacto.
static func season_entries(world: GameWorld, c: Club, year: int) -> Array:
	if year == world.year:
		var rows: Array = []
		for p: Player in world.squad(c):
			var t := p.season_totals()
			if int(t[0]) > 0:
				rows.append([p.id, p.display_name(), p.position, int(t[0]), int(t[1]), int(t[2]), int(round(rating(p, int(t[0])) * 100.0)), p.overall])
		return rows
	var key := str(year)
	if c.squad_archive.has(key): # elenco completo do clube do usuário
		var rows: Array = []
		for d: Dictionary in c.squad_archive[key]:
			if int(d.get("a", 0)) > 0:
				rows.append([int(d.get("id", -1)), String(d.get("n", "")), int(d.get("pos", 0)), int(d.get("a", 0)), int(d.get("g", 0)), int(d.get("as", 0)), int(round(float(d.get("r", 0.0)) * 100.0)), int(d.get("o", 0))])
		return rows
	return c.xi_hist.get(key, [])


## Nota do jogador numa temporada para o 11 do ano: nota média, pesada pela regularidade.
static func _season_score(e: Array) -> float:
	var apps := float(e[E_APPS])
	return float(e[E_RATING]) / 100.0 + minf(apps, 30.0) / 30.0 * 0.8 + float(e[E_OVR]) * 0.01


## Soma de todas as temporadas por jogador: {id: {n, pos, seasons, a, g, as, rsum, best_o, score}}.
static func all_time(world: GameWorld, c: Club) -> Array:
	var agg := {}
	for y in years(world, c):
		for e: Array in season_entries(world, c, int(y)):
			var pid := int(e[E_ID])
			if not agg.has(pid):
				agg[pid] = {"id": pid, "n": e[E_NAME], "pos": int(e[E_POS]), "seasons": 0, "a": 0, "g": 0, "as": 0, "rsum": 0.0, "o": 0, "from": int(y), "to": int(y)}
			var a: Dictionary = agg[pid]
			a["seasons"] += 1
			a["a"] += int(e[E_APPS])
			a["g"] += int(e[E_GOALS])
			a["as"] += int(e[E_ASSISTS])
			a["rsum"] += float(e[E_RATING]) / 100.0 * int(e[E_APPS])
			a["o"] = maxi(int(a["o"]), int(e[E_OVR]))
			a["from"] = mini(int(a["from"]), int(y))
			a["to"] = maxi(int(a["to"]), int(y))
	var out: Array = []
	for a: Dictionary in agg.values():
		var apps := maxf(1.0, float(a["a"]))
		var avg := float(a["rsum"]) / apps
		a["r"] = avg
		# Lenda: regularidade acima da média, gols e assistências, anos de casa e o auge.
		a["score"] = apps * (avg - 6.2) + float(a["g"]) * 0.6 + float(a["as"]) * 0.4 + float(a["seasons"]) * 3.0 + float(a["o"]) * 0.3
		out.append(a)
	return out


## Monta o 4-3-3 (vagas do Moneyball) com os melhores candidatos: [[rótulo da vaga, candidato]].
## Candidato é um Dictionary {id, n, pos, a, g, as, r, score, ...}.
static func pick_xi(cands: Array) -> Array:
	var sorted := cands.duplicate()
	sorted.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var used := {}
	var slots: Array = []
	for sl: Array in Moneyball.SLOTS:
		for i in int(sl[2]):
			slots.append([String(sl[0]), sl[1], null])
	# Passadas: posição exata entre os regulares, mesma linha entre os regulares, posição exata
	# entre todos e, por fim, qualquer um (goleiro só no gol).
	var min_apps := 1
	for cd: Dictionary in sorted:
		min_apps = maxi(min_apps, int(int(cd["a"]) * 0.2))
	min_apps = mini(min_apps, 5)
	for pass_i in 4:
		for s: Array in slots:
			if s[2] != null:
				continue
			var positions: Array = s[1]
			var gk_slot := Pos.GK in positions
			for cd: Dictionary in sorted:
				if used.has(cd["id"]):
					continue
				var pos := int(cd["pos"])
				if (pos == Pos.GK) != gk_slot:
					continue
				var regular := int(cd["a"]) >= min_apps
				var ok := false
				match pass_i:
					0: ok = regular and pos in positions
					1: ok = regular and Pos.group(pos) == Pos.group(int(positions[0]))
					2: ok = pos in positions
					_: ok = true
				if ok:
					s[2] = cd
					used[cd["id"]] = true
					break
	return slots


## Candidatos de uma temporada no formato do pick_xi.
static func season_candidates(world: GameWorld, c: Club, year: int) -> Array:
	var out: Array = []
	for e: Array in season_entries(world, c, year):
		out.append({"id": int(e[E_ID]), "n": String(e[E_NAME]), "pos": int(e[E_POS]), "a": int(e[E_APPS]), "g": int(e[E_GOALS]),
			"as": int(e[E_ASSISTS]), "r": float(e[E_RATING]) / 100.0, "o": int(e[E_OVR]), "score": _season_score(e)})
	return out
