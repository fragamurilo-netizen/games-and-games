class_name WeeklyAwards
extends RefCounted
## Seleção da rodada e seleção do mês da liga do usuário (com o craque do mês).
## Estado em `world.stats`:
##   "totw"      última seleção da rodada {y, r (rodada), ids, rt (notas), best}
##   "totw_n"    {"id": vezes na seleção da rodada} na temporada
##   "totm_acc"  acumulado do mês em curso {"id": [soma notas ×10, jogos, gols, assist.]}
##   "totm_m"    mês em curso (ano × 12 + mês)
##   "totm_list" seleções do mês já fechadas na temporada [{y, m, ids, rt, best}]

const MONTHS: Array[String] = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto",
	"setembro", "outubro", "novembro", "dezembro"]


## Chamado depois de aplicar os jogos da data.
static func after_matchday(world: GameWorld, md: Dictionary, slot: int) -> void:
	if not world.has_user():
		return
	var lid := world.user_league_id()
	var cands: Array = [] # [player, nota, gols, assist.]
	var round := -1
	for e in md["entries"]:
		var f: Fixture = e["f"]
		if f.comp != lid or not f.is_league():
			continue
		round = f.round
		var res: Dictionary = e["res"]
		for side in 2:
			for ln in res["lines"][side]:
				var p: Player = ln[QuickMatch.L_P]
				if int(ln[QuickMatch.L_MINS]) < 45:
					continue
				cands.append([p, float(ln[QuickMatch.L_R]), int(ln[QuickMatch.L_G]), int(ln[QuickMatch.L_A])])
	if cands.is_empty():
		return
	# Mês: fecha o anterior quando o calendário vira
	var month := world.season.month_of(slot)
	var cur := int(world.stats.get("totm_m", 0))
	if cur != 0 and cur != month:
		close_month(world)
	world.stats["totm_m"] = month
	var acc: Dictionary = world.stats.get("totm_acc", {})
	for cnd in cands:
		var p: Player = cnd[0]
		var k := str(p.id)
		var a: Array = acc.get(k, [0, 0, 0, 0])
		acc[k] = [int(a[0]) + int(round(float(cnd[1]) * 10.0)), int(a[1]) + 1, int(a[2]) + int(cnd[2]), int(a[3]) + int(cnd[3])]
	world.stats["totm_acc"] = acc
	# Seleção da rodada
	var scored: Array = []
	for cnd in cands:
		scored.append([cnd[0], float(cnd[1]) + int(cnd[2]) * 0.15 + int(cnd[3]) * 0.08, float(cnd[1])])
	var xi := _pick_xi(scored)
	if xi.is_empty():
		return
	var ids: Array = []
	var rts: Array = []
	var best: Array = xi[0]
	for x in xi:
		ids.append((x[0] as Player).id)
		rts.append(snappedf(float(x[2]), 0.1))
		if float(x[1]) > float(best[1]):
			best = x
	world.stats["totw"] = {"y": world.year, "r": round + 1, "ids": ids, "rt": rts, "best": (best[0] as Player).id}
	var n: Dictionary = world.stats.get("totw_n", {})
	for pid in ids:
		n[str(pid)] = int(n.get(str(pid), 0)) + 1
		var p := world.player(int(pid))
		if p != null:
			p.morale = clampf(p.morale + 1.5, 0.0, 100.0)
	world.stats["totw_n"] = n


## [[player, pontuação, nota]] → os 11 melhores respeitando 1-4-3-3 (ordem GK, DEF, MEI, ATA).
static func _pick_xi(scored: Array) -> Array:
	var groups: Array = [[], [], [], []]
	for s in scored:
		groups[Pos.group((s[0] as Player).position)].append(s)
	var out: Array = []
	for gi in 4:
		var arr: Array = groups[gi]
		arr.sort_custom(func(a, b): return float(a[1]) > float(b[1]) if a[1] != b[1] else (a[0] as Player).id < (b[0] as Player).id)
		if arr.size() < AwardManager.TEAM_SHAPE[gi]:
			return []
		out.append_array(arr.slice(0, AwardManager.TEAM_SHAPE[gi]))
	return out


## Fecha o mês em curso: seleção do mês e craque do mês (vira prêmio no currículo).
static func close_month(world: GameWorld) -> void:
	var acc: Dictionary = world.stats.get("totm_acc", {})
	var month := int(world.stats.get("totm_m", 0))
	world.stats["totm_acc"] = {}
	if acc.is_empty() or month == 0:
		return
	var scored: Array = []
	for k in acc:
		var a: Array = acc[k]
		if int(a[1]) < 2:
			continue
		var p := world.player(int(k))
		if p == null:
			continue
		var avg := float(a[0]) / 10.0 / float(a[1])
		scored.append([p, avg + int(a[2]) * 0.06 + int(a[3]) * 0.03 + int(a[1]) * 0.02, avg])
	var xi := _pick_xi(scored)
	if xi.is_empty():
		return
	var ids: Array = []
	var rts: Array = []
	var best: Array = xi[0]
	for x in xi:
		ids.append((x[0] as Player).id)
		rts.append(snappedf(float(x[2]), 0.01))
		if float(x[1]) > float(best[1]):
			best = x
	var bp: Player = best[0]
	var entry := {"y": world.year, "m": month, "ids": ids, "rt": rts, "best": bp.id}
	var list: Array = world.stats.get("totm_list", [])
	list.append(entry)
	world.stats["totm_list"] = list
	bp.awards.append({"y": world.year, "k": "potm", "l": world.user_league_id(), "m": month})
	bp.morale = clampf(bp.morale + 5.0, 0.0, 100.0)
	var label := month_label(month)
	var club := world.club(bp.club_id)
	NewsManager.post_raw(world, "%s é o craque do mês" % bp.display_name(),
		"%s, do %s, foi eleito o melhor jogador da %s em %s. A seleção do mês tem %d jogador(es) do %s." % [
			bp.display_name(), club.short_name if club != null else "?", world.league_name(world.user_league_id()), label,
			_count_club(world, ids, world.user_club_id), world.user_club().short_name],
		bp.club_id, bp.id, NewsEvent.IMP_HIGH if world.is_user_club(bp.club_id) else NewsEvent.IMP_NORMAL, "premio")


static func _count_club(world: GameWorld, ids: Array, club_id: int) -> int:
	var n := 0
	for pid in ids:
		var p := world.player(int(pid))
		if p != null and p.club_id == club_id:
			n += 1
	return n


## Encerra a temporada: fecha o último mês e devolve o arquivo do ano {months, totw_n}.
static func season_close(world: GameWorld) -> Dictionary:
	close_month(world)
	var out := {"months": world.stats.get("totm_list", []), "totw_n": world.stats.get("totw_n", {})}
	for k in ["totw", "totw_n", "totm_acc", "totm_m", "totm_list"]:
		world.stats.erase(k)
	return out


## Jogador mais vezes na seleção da rodada: [id, vezes] ou [].
static func most_selected(totw_n: Dictionary) -> Array:
	var best := []
	for k in totw_n:
		var v := int(totw_n[k])
		if best.is_empty() or v > int(best[1]) or (v == int(best[1]) and int(k) < int(best[0])):
			best = [int(k), v]
	return best


static func month_label(m: int) -> String:
	var mm := (m - 1) % 12
	return "%s de %d" % [MONTHS[mm], (m - 1) / 12]
