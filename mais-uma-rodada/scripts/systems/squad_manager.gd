class_name SquadManager
extends RefCounted
## Gestão do elenco do usuário: papéis prometidos, profundidade por posição e rodízio.

const MAX_STARS := 3
const STATUS_DESC: Array[String] = [
	"A referência do time. Joga sempre e espera ser tratado como tal.",
	"Titular absoluto. Reclama quando fica fora.",
	"Divide minutos. Aceita o banco de vez em quando.",
	"Opção de banco. Joga quando precisa.",
	"Jovem em formação. Quer chances aos poucos.",
]
## Posições mostradas na profundidade (lados juntos para não repetir).
const DEPTH_ROWS: Array = [
	[Pos.GK], [Pos.RB], [Pos.CB], [Pos.LB], [Pos.DM], [Pos.CM], [Pos.AM],
	[Pos.RM, Pos.LM], [Pos.RW, Pos.LW], [Pos.ST],
]


## Muda o papel prometido ao jogador. Retorna "" ou o motivo da recusa.
## Promover anima; rebaixar quem se acha titular derruba a moral (mais nos voláteis e nas estrelas).
static func set_status(world: GameWorld, club: Club, p: Player, status: int) -> String:
	status = clampi(status, 0, Player.STATUS_NAMES.size() - 1)
	if p.club_id != club.id:
		return "Esse jogador não é do seu elenco."
	if status == p.squad_status:
		return ""
	if status == Player.STATUS_PROSPECT and p.age(world.year) > 21:
		return "Só jogadores de até 21 anos podem ser tratados como promessa."
	if status == Player.STATUS_STAR:
		var stars := 0
		for pid in club.player_ids:
			var o := world.player(pid)
			if o != null and o.id != p.id and o.squad_status == Player.STATUS_STAR:
				stars += 1
		if stars >= MAX_STARS:
			return "O elenco já tem %d estrelas. Rebaixe uma antes." % MAX_STARS
	var old := p.squad_status
	var delta := _status_rank(old) - _status_rank(status) # > 0 promoveu
	var vol := p.trait_mult("morale_volatility")
	if delta > 0:
		p.morale = clampf(p.morale + 4.0 * delta, 0.0, 100.0)
	elif old <= Player.STATUS_STARTER:
		p.morale = clampf(p.morale + 7.0 * delta * vol, 0.0, 100.0)
	else:
		p.morale = clampf(p.morale + 3.0 * delta * vol, 0.0, 100.0)
	p.squad_status = status
	return ""


## Ordem de importância (0 = mais importante). Promessa fica entre rotação e reserva.
static func _status_rank(s: int) -> int:
	match s:
		Player.STATUS_STAR:
			return 0
		Player.STATUS_STARTER:
			return 1
		Player.STATUS_ROTATION:
			return 2
		Player.STATUS_PROSPECT:
			return 3
	return 4


## Previsão da reação do jogador a um novo papel (para mostrar antes de confirmar).
static func status_reaction(p: Player, status: int) -> String:
	var delta := _status_rank(p.squad_status) - _status_rank(status)
	if delta > 0:
		return "Vai gostar."
	if delta == 0:
		return ""
	if p.squad_status <= Player.STATUS_STARTER:
		return "Vai ficar bem chateado."
	return "Não vai gostar."


## Profundidade: para cada linha de DEPTH_ROWS, os 3 melhores do elenco naquela posição.
## [{pos: Array, best: [[Player, rating]], weak: bool}]
static func depth(world: GameWorld, club: Club) -> Array:
	var squad := world.squad(club)
	var level := 0.0
	var n := 0
	for p in squad:
		n += 1
		level += p.ovr_f
	level = level / maxf(1.0, n)
	var out: Array = []
	for row in DEPTH_ROWS:
		var cands: Array = []
		for p: Player in squad:
			var r := 0.0
			var fam := 0.0
			for pos in row:
				r = maxf(r, p.rating_at(pos))
				fam = maxf(fam, Pos.familiarity(p.position, p.secondary, pos))
			if fam >= 0.85:
				cands.append([p, r])
		cands.sort_custom(func(a, b): return a[1] > b[1])
		var need := 2 if row[0] == Pos.GK or row[0] == Pos.CB or row.size() > 1 else 1
		if row[0] == Pos.CB:
			need = 3
		var good := 0
		for c in cands:
			if c[1] >= level - 6.0:
				good += 1
		out.append({"pos": row, "best": cands.slice(0, 3), "weak": good < need, "need": need})
	return out


## Poupa titulares cansados: troca quem está abaixo de `limit` de condição pelo melhor
## descansado para a mesma vaga, se não perder muito. Retorna mensagens do que mudou.
static func rest_tired(world: GameWorld, club: Club, sheet: TeamSheet, limit: float = 80.0, max_drop: float = 6.0) -> Array:
	var msgs: Array = []
	var slots: Array = DatabaseManager.formation(sheet.formation)["slots"]
	for i in mini(slots.size(), sheet.starters.size()):
		var cur := world.player(sheet.starters[i])
		if cur == null or cur.condition >= limit:
			continue
		var pos: int = slots[i]["pos"]
		var best: Player = null
		var best_v := -1.0
		for pid in club.player_ids:
			if sheet.starters.has(pid):
				continue
			var p := world.player(pid)
			if p == null or not p.is_available() or p.condition < limit:
				continue
			var v := p.rating_at(pos)
			if v > best_v:
				best_v = v
				best = p
		if best == null or best_v < cur.rating_at(pos) - max_drop:
			continue
		sheet.starters[i] = best.id
		var b := sheet.bench.find(best.id)
		if b >= 0:
			sheet.bench[b] = cur.id
		msgs.append("%s descansa, %s entra (%s)." % [cur.display_name(), best.display_name(), Pos.code(pos)])
	if not msgs.is_empty():
		for key in ["captain", "penalty_taker", "freekick_taker", "corner_taker"]:
			if not sheet.starters.has(sheet.get(key)):
				ClubAI.pick_set_pieces(world, sheet)
				break
	return msgs


## Jogadores que esperam jogar mais do que estão jogando (titulares/estrelas com poucos minutos).
static func wants_more_minutes(world: GameWorld, club: Club) -> Array:
	var out: Array = []
	var games := 0
	for pid in club.player_ids:
		var p := world.player(pid)
		if p != null:
			games = maxi(games, p.stats[Player.S_APPS])
	if games < 3:
		return out
	for pid in club.player_ids:
		var p := world.player(pid)
		if p == null or p.injury_weeks > 0 or p.squad_status > Player.STATUS_STARTER:
			continue
		if p.stats[Player.S_STARTS] < games * 0.5:
			out.append(p)
	return out
