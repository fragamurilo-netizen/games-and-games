class_name AwardManager
extends RefCounted
## Prêmios da temporada: craque, revelação, goleiro e garçom de cada liga, e o melhor
## jogador do mundo (a "Bola de Ouro" do jogo). Ficam no histórico e no currículo do jogador.


## {liga: {mvp, young, gk, assist}} — cada prêmio é {id, name, club, v (valor exibido)}.
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
		var assists := p.stats[Player.S_ASSISTS]
		if assists > 0 and (not b.has("assist") or assists > int(b["assist"][1])):
			b["assist"] = [p, assists]
		if apps < int(b["min"]):
			continue
		var r := p.avg_rating() + p.stats[Player.S_GOALS] * 0.012 + assists * 0.006
		if not b.has("mvp") or r > float(b["mvp"][1]):
			b["mvp"] = [p, r]
		if p.age(world.year) <= 21 and (not b.has("young") or r > float(b["young"][1])):
			b["young"] = [p, r]
		if p.position == Pos.GK and (not b.has("gk") or r > float(b["gk"][1])):
			b["gk"] = [p, r]
	var out := {}
	for id in best:
		var b: Dictionary = best[id]
		var aw := {}
		for k in ["mvp", "young", "gk", "assist"]:
			if b.has(k):
				var p: Player = b[k][0]
				var v := "%.2f" % p.avg_rating() if k != "assist" else "%d assist." % p.stats[Player.S_ASSISTS]
				aw[k] = {"id": p.id, "name": p.display_name(), "club": world.club(p.club_id).short_name, "v": v}
		out[id] = aw
	return out


## Melhor jogador do mundo: nota, gols, nível da liga e títulos da temporada.
static func world_player(world: GameWorld) -> Dictionary:
	var best: Player = null
	var best_v := -1.0
	for p: Player in world.players.values():
		if p.club_id < 0 or p.overall < 74:
			continue
		var tot := p.season_totals()
		if int(tot[0]) < 18:
			continue
		var c: Club = world.clubs[p.club_id]
		var level := float(DatabaseManager.league_cfg(c.league_id).get("level", [60, 70])[1])
		var v := p.avg_rating() * 10.0 + int(tot[1]) * 0.35 + int(tot[2]) * 0.2 + (level - 70.0) * 0.6 + p.overall * 0.4
		for k in p.cup_stats:
			v += int(p.cup_stats[k][Player.C_GOALS]) * 0.15
		if v > best_v:
			best_v = v
			best = p
	if best == null:
		return {}
	var tot := best.season_totals()
	return {"id": best.id, "name": best.display_name(), "full": best.first_name + " " + best.last_name, "club": world.club(best.club_id).short_name,
		"nat": best.nationality, "goals": int(tot[1]), "apps": int(tot[0])}


static func award_name(k: String) -> String:
	match k:
		"mvp":
			return "Craque"
		"young":
			return "Revelação"
		"gk":
			return "Melhor goleiro"
		"assist":
			return "Garçom"
		"ballon":
			return "Melhor do mundo"
	return k


## Registra os prêmios no currículo dos jogadores.
static func credit(world: GameWorld, awards: Dictionary, ballon: Dictionary) -> void:
	for id in awards:
		for k in awards[id]:
			var p := world.player(int(awards[id][k]["id"]))
			if p != null:
				p.awards.append({"y": world.year, "k": k, "l": id})
	if not ballon.is_empty():
		var bp := world.player(int(ballon["id"]))
		if bp != null:
			bp.awards.append({"y": world.year, "k": "ballon", "l": ""})
