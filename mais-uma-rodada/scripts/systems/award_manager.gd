class_name AwardManager
extends RefCounted
## Prêmios da temporada. Por liga: craque, artilheiro, garçom, revelação, melhor goleiro,
## defensor, meio-campista e atacante, além da seleção do campeonato. Por copa: craque da copa.
## No mundo: melhor jogador (a "Bola de Ouro" do jogo), revelação mundial e Chuteira de Ouro.
## No clube do usuário: craque do clube. Tudo fica no histórico e no currículo do jogador.

## Ordem de exibição dos prêmios de liga.
const LEAGUE_KEYS: Array[String] = ["mvp", "scorer", "assist", "young", "gk", "def", "mid", "att"]
## Formação da seleção do campeonato: goleiro, defensores, meias, atacantes.
const TEAM_SHAPE: Array[int] = [1, 4, 3, 3]


## {liga: {mvp, scorer, assist, young, gk, def, mid, att}} — cada prêmio é {id, name, club, v (valor exibido)}.
static func league_awards(world: GameWorld) -> Dictionary:
	var s := world.season
	var best := {}
	for id in s.league_order:
		var league: League = s.leagues[id]
		best[id] = {"min": maxi(5, int(league.rounds.size() * 0.45))}
	for p: Player in world.players.values():
		if p.club_id < 0:
			continue
		var c: Club = world.clubs[p.club_id]
		var b: Dictionary = best.get(c.league_id, {})
		if b.is_empty():
			continue
		var apps := p.stats[Player.S_APPS]
		var goals := p.stats[Player.S_GOALS]
		var assists := p.stats[Player.S_ASSISTS]
		if assists > 0 and (not b.has("assist") or _beats(p, assists, b["assist"])):
			b["assist"] = [p, assists]
		if goals > 0 and (not b.has("scorer") or _beats(p, goals, b["scorer"])):
			b["scorer"] = [p, goals]
		if apps < int(b["min"]):
			continue
		var r := score(p)
		if not b.has("mvp") or r > float(b["mvp"][1]):
			b["mvp"] = [p, r]
		if p.age(world.year) <= 21 and (not b.has("young") or r > float(b["young"][1])):
			b["young"] = [p, r]
		var k := _group_key(p.position)
		if not b.has(k) or r > float(b[k][1]):
			b[k] = [p, r]
	var out := {}
	for id in best:
		var b: Dictionary = best[id]
		var aw := {}
		for k in LEAGUE_KEYS:
			if b.has(k):
				var p: Player = b[k][0]
				var v := "%.2f" % p.avg_rating()
				if k == "assist":
					v = "%d assist." % p.stats[Player.S_ASSISTS]
				elif k == "scorer":
					v = "%d gols" % p.stats[Player.S_GOALS]
				aw[k] = {"id": p.id, "name": p.display_name(), "club": world.club(p.club_id).short_name, "v": v}
		out[id] = aw
	return out


## Nota de temporada usada nas premiações (média + peso de gols e assistências).
static func score(p: Player) -> float:
	return p.avg_rating() + p.stats[Player.S_GOALS] * 0.012 + p.stats[Player.S_ASSISTS] * 0.006 + p.stats[Player.S_MOTM] * 0.01


## Desempate de artilharia/assistências: menos jogos vence (depois, id — determinístico).
static func _beats(p: Player, v: int, cur: Array) -> bool:
	var q: Player = cur[0]
	if v != int(cur[1]):
		return v > int(cur[1])
	if p.stats[Player.S_APPS] != q.stats[Player.S_APPS]:
		return p.stats[Player.S_APPS] < q.stats[Player.S_APPS]
	return p.id < q.id


static func _group_key(pos: int) -> String:
	match Pos.group(pos):
		Pos.G_GK:
			return "gk"
		Pos.G_DEF:
			return "def"
		Pos.G_MID:
			return "mid"
	return "att"


## Seleção do campeonato de cada liga: {liga: [ids em ordem GK, DEF×4, MEI×3, ATA×3]}.
static func teams_of_season(world: GameWorld) -> Dictionary:
	var s := world.season
	var pools := {}
	for id in s.league_order:
		var league: League = s.leagues[id]
		pools[id] = {"min": maxi(5, int(league.rounds.size() * 0.45)), "g": [[], [], [], []]}
	for p: Player in world.players.values():
		if p.club_id < 0:
			continue
		var pool: Dictionary = pools.get(world.clubs[p.club_id].league_id, {})
		if pool.is_empty() or p.stats[Player.S_APPS] < int(pool["min"]):
			continue
		pool["g"][Pos.group(p.position)].append(p)
	var out := {}
	for id in pools:
		var ids: Array = []
		var groups: Array = pools[id]["g"]
		for gi in 4:
			var arr: Array = groups[gi]
			arr.sort_custom(func(a: Player, b: Player):
				var sa := score(a)
				var sb := score(b)
				return sa > sb if sa != sb else a.id < b.id)
			for i in mini(TEAM_SHAPE[gi], arr.size()):
				ids.append(arr[i].id)
		if ids.size() == 11:
			out[id] = ids
	return out


## Craque de cada copa: {copa: {id, name, club, v}}.
static func cup_awards(world: GameWorld) -> Dictionary:
	var best := {}
	for p: Player in world.players.values():
		if p.club_id < 0 or p.cup_stats.is_empty():
			continue
		for cid in p.cup_stats:
			var st: PackedInt32Array = p.cup_stats[cid]
			if st[Player.C_APPS] < 3:
				continue
			var r := st[Player.C_RATING] / 10.0 / st[Player.C_APPS] + st[Player.C_GOALS] * 0.03 + st[Player.C_ASSISTS] * 0.015 + st[Player.C_APPS] * 0.01
			if not best.has(cid) or r > float(best[cid][1]):
				best[cid] = [p, r]
	var out := {}
	for cid in best:
		var p: Player = best[cid][0]
		var st: PackedInt32Array = p.cup_stats[cid]
		out[cid] = {"id": p.id, "name": p.display_name(), "club": world.club(p.club_id).short_name,
			"v": "%.2f · %d g" % [st[Player.C_RATING] / 10.0 / st[Player.C_APPS], st[Player.C_GOALS]]}
	return out


## Melhor jogador do mundo: nota, gols, nível da liga e títulos da temporada.
static func world_player(world: GameWorld) -> Dictionary:
	return _world_best(world, 74, 99)


## Revelação mundial: o melhor jogador de até 21 anos.
static func world_young(world: GameWorld) -> Dictionary:
	return _world_best(world, 60, 21)


## Votação da Bola de Ouro: os `n` mais votados [{id, name, club, nat, goals, apps, pts}].
static func ballon_ranking(world: GameWorld, n: int = 10) -> Array:
	var arr: Array = []
	for p: Player in world.players.values():
		var v := _world_value(world, p, 74, 99)
		if v > 0.0:
			arr.append([p, v])
	arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else (a[0] as Player).id < (b[0] as Player).id)
	var out: Array = []
	var top := float(arr[0][1]) if not arr.is_empty() else 1.0
	for i in mini(n, arr.size()):
		var p: Player = arr[i][0]
		var tot := p.season_totals()
		# Pontos de votação: o vencedor fica perto de 1.000 e a distância para os demais aparece.
		var pts := int(round(1000.0 * pow(float(arr[i][1]) / top, 6.0)))
		out.append({"id": p.id, "name": p.display_name(), "club": world.club(p.club_id).short_name, "nat": p.nationality,
			"goals": int(tot[1]), "apps": int(tot[0]), "pts": pts})
	return out


static func _world_value(world: GameWorld, p: Player, min_ovr: int, max_age: int) -> float:
	if p.club_id < 0 or p.overall < min_ovr or p.age(world.year) > max_age:
		return -1.0
	var tot := p.season_totals()
	if int(tot[0]) < 18:
		return -1.0
	var c: Club = world.clubs[p.club_id]
	var level := float(DatabaseManager.league_cfg(c.league_id).get("level", [60, 70])[1])
	var v := p.avg_rating() * 10.0 + int(tot[1]) * 0.35 + int(tot[2]) * 0.2 + (level - 70.0) * 0.6 + p.overall * 0.4
	for k in p.cup_stats:
		v += int(p.cup_stats[k][Player.C_GOALS]) * 0.15
	return maxf(0.01, v)


static func _world_best(world: GameWorld, min_ovr: int, max_age: int) -> Dictionary:
	var best: Player = null
	var best_v := -1.0
	for p: Player in world.players.values():
		var v := _world_value(world, p, min_ovr, max_age)
		if v > best_v:
			best_v = v
			best = p
	if best == null:
		return {}
	var tot := best.season_totals()
	return {"id": best.id, "name": best.display_name(), "full": best.first_name + " " + best.last_name, "club": world.club(best.club_id).short_name,
		"nat": best.nationality, "goals": int(tot[1]), "apps": int(tot[0])}


## Chuteira de Ouro: gols de liga ponderados pela força da liga (como no futebol de verdade).
static func golden_boot(world: GameWorld) -> Dictionary:
	var best: Player = null
	var best_v := 0.0
	for p: Player in world.players.values():
		if p.club_id < 0 or p.stats[Player.S_GOALS] < 5:
			continue
		var c: Club = world.clubs[p.club_id]
		var level := float(DatabaseManager.league_cfg(c.league_id).get("level", [60, 70])[1])
		var v := p.stats[Player.S_GOALS] * clampf(1.0 + (level - 75.0) * 0.04, 0.5, 1.5)
		if v > best_v or (v == best_v and best != null and p.id < best.id):
			best_v = v
			best = p
	if best == null:
		return {}
	return {"id": best.id, "name": best.display_name(), "club": world.club(best.club_id).short_name, "nat": best.nationality,
		"goals": best.stats[Player.S_GOALS], "pts": snappedf(best_v, 0.1)}


## Craque do clube na temporada (usado para o clube do usuário).
static func club_player(world: GameWorld, club_id: int) -> Dictionary:
	var c := world.club(club_id)
	if c == null:
		return {}
	var best: Player = null
	var best_v := -1.0
	for pid in c.player_ids:
		var p := world.player(pid)
		if p == null or p.stats[Player.S_APPS] < 8:
			continue
		var v := score(p)
		if v > best_v:
			best_v = v
			best = p
	if best == null:
		return {}
	return {"id": best.id, "name": best.display_name(), "club": c.short_name, "v": "%.2f" % best.avg_rating()}


static func award_name(k: String) -> String:
	match k:
		"mvp":
			return "Craque"
		"scorer":
			return "Artilheiro"
		"young":
			return "Revelação"
		"gk":
			return "Melhor goleiro"
		"def":
			return "Melhor defensor"
		"mid":
			return "Melhor meio-campista"
		"att":
			return "Melhor atacante"
		"assist":
			return "Garçom"
		"team":
			return "Seleção do campeonato"
		"cup_mvp":
			return "Craque da copa"
		"ballon":
			return "Bola de Ouro"
		"potm":
			return "Craque do mês"
		"world_young":
			return "Revelação mundial"
		"boot":
			return "Chuteira de Ouro"
		"club":
			return "Craque do clube"
	return k


## Onde o prêmio foi ganho (sigla curta da liga ou da copa; vazio para prêmios mundiais).
static func award_where(world: GameWorld, a: Dictionary) -> String:
	var l := String(a.get("l", ""))
	if l == "":
		return ""
	if String(a.get("k", "")) == "cup_mvp":
		return CupManager.cup_short(l)
	if String(a.get("k", "")) == "club":
		var c := world.club(int(l)) if l.is_valid_int() else null
		return c.short_name if c != null else ""
	return world.league_short(l)


## Peso de um prêmio no currículo (usado para destacar os mais importantes e na moral).
static func award_weight(k: String) -> int:
	match k:
		"potm":
			return 2
		"ballon":
			return 10
		"boot", "world_young":
			return 6
		"mvp":
			return 5
		"scorer", "young", "cup_mvp":
			return 3
		"team", "club":
			return 1
	return 2


## Registra os prêmios no currículo dos jogadores. `extra`: {teams, cups, world_young, boot, club}.
static func credit(world: GameWorld, awards: Dictionary, ballon: Dictionary, extra: Dictionary = {}) -> void:
	for id in awards:
		for k in awards[id]:
			_give(world, int(awards[id][k]["id"]), k, id)
	for id in extra.get("teams", {}):
		for pid in extra["teams"][id]:
			_give(world, int(pid), "team", id)
	var cups: Dictionary = extra.get("cups", {})
	for cid in cups:
		_give(world, int(cups[cid]["id"]), "cup_mvp", cid)
	if not ballon.is_empty():
		_give(world, int(ballon["id"]), "ballon", "")
	for k in ["world_young", "boot"]:
		var d: Dictionary = extra.get(k, {})
		if not d.is_empty():
			_give(world, int(d["id"]), k, "")
	var cl: Dictionary = extra.get("club", {})
	if not cl.is_empty():
		_give(world, int(cl["id"]), "club", str(world.user_club_id))


static func _give(world: GameWorld, pid: int, k: String, where: String) -> void:
	var p := world.player(pid)
	if p == null:
		return
	p.awards.append({"y": world.year, "k": k, "l": where})
	# Reconhecimento levanta a moral (e o ego).
	p.morale = clampf(p.morale + 2.0 + award_weight(k), 0.0, 100.0)
	if p.awards.size() > 60:
		p.awards = p.awards.slice(p.awards.size() - 60)
