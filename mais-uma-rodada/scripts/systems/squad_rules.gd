class_name SquadRules
extends RefCounted
## Regras reais de inscrição por liga (leagues.json → "foreign_limit"): quantos estrangeiros podem
## estar entre os relacionados de um jogo (titulares + banco). scope "all" conta todo estrangeiro;
## "non_eu" só os de fora da União Europeia/EEE (a regra dos três extracomunitários da Espanha).
## Vale para o usuário (com aviso na escalação) e para a IA.

const EU := ["ESP", "POR", "FRA", "GER", "ITA", "NED", "BEL", "AUT", "CRO", "CZE", "DEN", "GRE", "POL", "SWE", "IRL", "HUN",
	"ROU", "SVK", "SVN", "FIN", "BUL", "LUX", "EST", "LVA", "LTU", "CYP", "MLT", "NOR", "ISL", "SUI", "LIE"]


static func limit(club: Club) -> Dictionary:
	return club.league_cfg().get("foreign_limit", {})


static func is_foreign(p: Player, club: Club, scope: String) -> bool:
	if p.nationality == club.nation:
		return false
	if scope == "non_eu":
		return not EU.has(p.nationality)
	return true


static func count(world: GameWorld, club: Club, ids: Array) -> int:
	var lim := limit(club)
	if lim.is_empty():
		return 0
	var scope := String(lim.get("scope", "all"))
	var n := 0
	for pid in ids:
		var p: Player = world.player(int(pid)) if pid != null else null
		if p != null and is_foreign(p, club, scope):
			n += 1
	return n


static func describe(club: Club) -> String:
	var lim := limit(club)
	if lim.is_empty():
		return ""
	if String(lim.get("scope", "all")) == "non_eu":
		return "Até %d extracomunitários entre os relacionados" % int(lim["max"])
	return "Até %d estrangeiros entre os relacionados" % int(lim["max"])


## Ajusta a escalação à regra: tira primeiro estrangeiros do banco e depois troca os titulares
## estrangeiros de menor impacto pelo melhor nacional disponível para a vaga. Retorna os avisos.
static func fix(world: GameWorld, club: Club, sheet: TeamSheet) -> Array:
	var msgs: Array = []
	var lim := limit(club)
	if lim.is_empty() or sheet == null:
		return msgs
	var mx := int(lim.get("max", 99))
	var scope := String(lim.get("scope", "all"))
	var excess := count(world, club, sheet.starters + sheet.bench) - mx
	if excess <= 0:
		return msgs
	# Banco: sai o estrangeiro mais fraco
	var bench_f: Array = []
	for pid in sheet.bench:
		var p: Player = world.player(int(pid))
		if p != null and is_foreign(p, club, scope):
			bench_f.append(p)
	bench_f.sort_custom(func(a: Player, b: Player): return a.overall < b.overall)
	for p: Player in bench_f:
		if excess <= 0:
			break
		sheet.bench.erase(p.id)
		excess -= 1
	if excess <= 0:
		msgs.append("Regra de estrangeiros: banco ajustado.")
		return msgs
	# Titulares: troca quem perde menos ao sair
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	var used := {}
	for pid in sheet.starters + sheet.bench:
		if pid != null:
			used[int(pid)] = true
	var cands: Array = []
	for i in mini(slots.size(), sheet.starters.size()):
		var p: Player = world.player(int(sheet.starters[i])) if sheet.starters[i] != null else null
		if p != null and is_foreign(p, club, scope):
			cands.append([i, p.rating_at(int(slots[i]["pos"]))])
	cands.sort_custom(func(a, b): return float(a[1]) < float(b[1]))
	for c in cands:
		if excess <= 0:
			break
		var i: int = c[0]
		var pos: int = slots[i]["pos"]
		var best: Player = null
		for pid in club.player_ids:
			var q: Player = world.players.get(pid, null)
			if q == null or used.has(pid) or not q.is_available() or is_foreign(q, club, scope):
				continue
			if best == null or q.rating_at(pos) > best.rating_at(pos):
				best = q
		if best == null:
			break
		var out: Player = world.player(int(sheet.starters[i]))
		sheet.starters[i] = best.id
		used[best.id] = true
		excess -= 1
		msgs.append("Regra de estrangeiros: %s entra no lugar de %s." % [best.display_name(), out.display_name()])
	return msgs
