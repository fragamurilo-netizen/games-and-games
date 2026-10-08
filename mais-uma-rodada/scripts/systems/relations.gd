class_name Relations
extends RefCounted
## A vida social do futebol, no mundo inteiro (não só no elenco do usuário).
##
## Laços entre jogadores (Player.bonds = {pid: [tipo, valor, desde]}, os 8 mais fortes):
##   amigo, inimigo, irmao, mentor/aprendiz, dupla (ataque que se entende).
##   Nascem de anos lado a lado, títulos juntos, compatriotas longe de casa, mesma língua, do
##   veterano líder que adota o garoto da posição, e azedam na briga por posição, entre dois
##   esquentados, em discussões e brigas depois de derrotas feias.
## Deduzidos do histórico (sem guardar): revelados juntos na mesma base, anos jogando juntos.
## Técnicos (Player.coach_rel = {id: valor}; -2 = o usuário): quem deu a primeira chance, quem
##   escalou e ganhou títulos sobe; quem deixou no banco sendo bom o bastante desce. Daí saem o
##   técnico favorito e o desafeto.
## Ídolo (Player.idol): o garoto se espelha num craque compatriota da posição ou na lenda do clube
##   do coração.
## Lendas dos clubes: maior artilheiro, recordista de jogos, mais títulos (ativos e aposentados).
##
## Efeitos: vontade de ir para um clube (amigos, irmão, técnico favorito, ídolo; inimigo e desafeto
## afastam), moral quando amigo chega ou sai, entrosamento do time titular, homens de confiança do
## técnico no mercado da IA e histórias (reencontro, briga no treino, irmãos no mesmo time).
##
## Sem sorteio de dados soltos: as "afinidades" saem de um hash fixo do par (a química entre duas
## pessoas não muda a cada vez que se olha), e os gatilhos são o que acontece em campo.

const AMIGO := "amigo"
const INIMIGO := "inimigo"
const IRMAO := "irmao"
const MENTOR := "mentor" # visto pelo aprendiz: "pid é o meu mentor"
const APRENDIZ := "aprendiz" # visto pelo mentor
const DUPLA := "dupla"
const MAX_BONDS := 8
const USER_COACH := -2
const NAMES := {AMIGO: "Amigo", INIMIGO: "Desafeto", IRMAO: "Irmão", MENTOR: "Mentor", APRENDIZ: "Aprendiz", DUPLA: "Dupla"}


# ---------------------------------------------------------------------------
# Química do par (fixa) e acesso aos laços
# ---------------------------------------------------------------------------

## Afinidade fixa entre duas pessoas (0..1): sem sorteio, a mesma a vida inteira.
static func chem(a: int, b: int, salt: String = "") -> float:
	var lo := mini(a, b)
	var hi := maxi(a, b)
	return float(hash([lo, hi, "chem", salt]) % 10000) / 10000.0


static func bond(p: Player, other: int) -> Array:
	return p.bonds.get(other, [])


static func value(p: Player, other: int) -> float:
	var b := bond(p, other)
	return float(b[1]) if not b.is_empty() else 0.0


static func kind(p: Player, other: int) -> String:
	var b := bond(p, other)
	return String(b[0]) if not b.is_empty() else ""


## Cria ou ajusta o laço dos dois lados. Tipo novo só substitui se fizer sentido (irmão é para sempre).
static func link(world: GameWorld, a: Player, b: Player, k: String, delta: float) -> void:
	if a == null or b == null or a.id == b.id:
		return
	_side(world, a, b.id, k, delta)
	var back := k
	if k == MENTOR:
		back = APRENDIZ
	elif k == APRENDIZ:
		back = MENTOR
	_side(world, b, a.id, back, delta)


static func _side(world: GameWorld, p: Player, other: int, k: String, delta: float) -> void:
	var cur: Array = p.bonds.get(other, [])
	if cur.is_empty():
		p.bonds[other] = [k, clampf(delta, -100.0, 100.0), world.year]
	else:
		var kk := String(cur[0])
		var v := clampf(float(cur[1]) + delta, -100.0, 100.0)
		if kk != IRMAO:
			if v <= -20.0:
				kk = INIMIGO
			elif kk == INIMIGO and v >= 15.0:
				kk = AMIGO # reconciliação
			elif k in [MENTOR, APRENDIZ, DUPLA] and kk == AMIGO:
				kk = k
		p.bonds[other] = [kk, v, int(cur[2])]
	_trim(p)


static func _trim(p: Player) -> void:
	if p.bonds.size() <= MAX_BONDS:
		return
	var ids := p.bonds.keys()
	ids.sort_custom(func(x, y): return _keep_score(p.bonds[x]) > _keep_score(p.bonds[y]))
	for id in ids.slice(MAX_BONDS):
		p.bonds.erase(id)


static func _keep_score(b: Array) -> float:
	return absf(float(b[1])) + (200.0 if String(b[0]) == IRMAO else 0.0)


static func friends_in(world: GameWorld, p: Player, club: Club) -> Array:
	var out: Array = []
	for oid in p.bonds:
		var q: Player = world.players.get(oid)
		if q != null and q.club_id == club.id and float(p.bonds[oid][1]) > 15.0:
			out.append(q)
	return out


## [amigos, desafetos] do jogador no clube (as contas de friends_in e enemies_in num passe só).
static func ties_in(world: GameWorld, p: Player, club: Club) -> Vector2i:
	var out := Vector2i.ZERO
	for oid in p.bonds:
		var q: Player = world.players.get(oid)
		if q != null and q.club_id == club.id:
			var v := float(p.bonds[oid][1])
			if v > 15.0:
				out.x += 1
			elif v < -15.0:
				out.y += 1
	return out


static func enemies_in(world: GameWorld, p: Player, club: Club) -> Array:
	var out: Array = []
	for oid in p.bonds:
		var q: Player = world.players.get(oid)
		if q != null and q.club_id == club.id and float(p.bonds[oid][1]) < -15.0:
			out.append(q)
	return out


# ---------------------------------------------------------------------------
# Deduzidos do histórico
# ---------------------------------------------------------------------------

## Revelados juntos: primeira passagem no mesmo clube, começando no mesmo ano (ou com um de
## diferença) ainda garotos.
static func came_up_together(a: Player, b: Player) -> bool:
	if a.spells.is_empty() or b.spells.is_empty():
		return false
	var sa: Dictionary = a.spells[0]
	var sb: Dictionary = b.spells[0]
	if int(sa["c"]) != int(sb["c"]):
		return false
	return absi(int(sa["from"]) - int(sb["from"])) <= 1 and int(sa["from"]) - a.birth_year <= 19 and int(sb["from"]) - b.birth_year <= 19


## Anos jogando no mesmo clube (soma das passagens que se cruzam).
static func years_together(world: GameWorld, a: Player, b: Player) -> int:
	var n := 0
	for sa: Dictionary in a.spells:
		for sb: Dictionary in b.spells:
			if int(sa["c"]) != int(sb["c"]):
				continue
			var a0 := int(sa["from"])
			var a1 := int(sa["to"]) if int(sa["to"]) > 0 else world.year
			var b0 := int(sb["from"])
			var b1 := int(sb["to"]) if int(sb["to"]) > 0 else world.year
			n += maxi(0, mini(a1, b1) - maxi(a0, b0))
	return n


# ---------------------------------------------------------------------------
# Técnicos
# ---------------------------------------------------------------------------

static func coach_value(p: Player, coach_id: int) -> float:
	return float(p.coach_rel.get(coach_id, 0.0))


static func add_coach(p: Player, coach_id: int, d: float) -> void:
	if coach_id == -1:
		return
	p.coach_rel[coach_id] = clampf(float(p.coach_rel.get(coach_id, 0.0)) + d, -100.0, 100.0)
	if p.coach_rel.size() > 6:
		var ids := p.coach_rel.keys()
		ids.sort_custom(func(x, y): return absf(float(p.coach_rel[x])) > absf(float(p.coach_rel[y])))
		for id in ids.slice(6):
			p.coach_rel.erase(id)


## Técnico favorito (id) ou -1; precisa de carinho de verdade (30+).
static func fav_coach(p: Player) -> int:
	var best := -1
	var bv := 30.0
	for id in p.coach_rel:
		if float(p.coach_rel[id]) > bv:
			bv = float(p.coach_rel[id])
			best = int(id)
	return best


static func bad_coach(p: Player) -> int:
	var worst := -1
	var wv := -25.0
	for id in p.coach_rel:
		if float(p.coach_rel[id]) < wv:
			wv = float(p.coach_rel[id])
			worst = int(id)
	return worst


## Id do técnico que comanda o clube (o usuário = -2; -1 se ninguém).
static func coach_id_of(world: GameWorld, club_id: int) -> int:
	if world.is_user_club(club_id):
		return USER_COACH
	var co := People.coach_of(world, club_id)
	return int(co.get("id", -1)) if not co.is_empty() else -1


static func coach_name(world: GameWorld, coach_id: int) -> String:
	if coach_id == USER_COACH:
		return world.manager_name
	if coach_id < 0:
		return ""
	for cid in People.data(world)["coaches"]:
		var co: Dictionary = People.data(world)["coaches"][cid]
		if int(co.get("id", -1)) == coach_id:
			return String(co.get("n", ""))
	for co: Dictionary in People.data(world)["free"]:
		if int(co.get("id", -1)) == coach_id:
			return String(co.get("n", ""))
	return ""


# ---------------------------------------------------------------------------
# Geração (mundo novo)
# ---------------------------------------------------------------------------

static func generate(world: GameWorld) -> void:
	_brothers(world)
	# Os laços de cada elenco só mexem nos jogadores daquele clube (ninguém está emprestado no
	# mundo novo) e a química do par é fixa: os clubes são processados em paralelo, mesmo resultado.
	Languages.primary("BRA") # tabela de línguas carregada antes das threads
	var clubs: Array = world.clubs
	Parallel.map_chunks(clubs.size(), func(a: int, b: int) -> Array:
		for i in range(a, b):
			_club_bonds(world, clubs[i], true)
		return [], 32)
	assign_idols(world)
	world.stats["rel_v"] = 1


## Irmãos: mesmo sobrenome e país, idade próxima. Sobrenome comum (Silva) quase nunca é parentesco.
static func _brothers(world: GameWorld) -> void:
	var groups := {}
	for p: Player in world.players.values():
		var k := "%s|%s" % [p.nationality, p.last_name]
		if not groups.has(k):
			groups[k] = []
		groups[k].append(p)
	for k in groups:
		var arr: Array = groups[k]
		if arr.size() < 2:
			continue
		# Alvo realista: ~1% dos jogadores com um irmão no futebol profissional.
		var bar := 0.0015 if arr.size() > 25 else (0.006 if arr.size() > 8 else 0.03)
		for i in arr.size():
			for j in range(i + 1, mini(arr.size(), i + 12)):
				var a: Player = arr[i]
				var b: Player = arr[j]
				if absi(a.birth_year - b.birth_year) <= 7 and chem(a.id, b.id, "irmao") < bar and kind(a, b.id) == "":
					link(world, a, b, IRMAO, 85.0)


## Laços dentro do elenco. `initial`: o mundo já vem com amizades e rixas formadas.
static func _club_bonds(world: GameWorld, c: Club, initial: bool) -> void:
	var squad := world.squad(c)
	var n := squad.size()
	for i in n:
		var a: Player = squad[i]
		for j in range(i + 1, n):
			var b: Player = squad[j]
			if a.bonds.has(b.id):
				continue
			var k := _affinity(world, c, a, b, initial)
			if k.is_empty():
				continue
			# [tipo, valor, quem vê, quem é visto]: no mentor, quem vê é o aprendiz.
			link(world, k[2], k[3], String(k[0]), float(k[1]))


## Que laço dois companheiros formam: [tipo, valor, jogador, outro] ou [] (nenhum), pela situação e
## pela química fixa do par.
static func _affinity(world: GameWorld, c: Club, a: Player, b: Player, initial: bool) -> Array:
	# A química fixa do par decide quais laços são possíveis (amizade e mentor pedem química baixa,
	# briga pede alta): as contas caras (anos juntos, histórico) só saem quando o laço ainda cabe.
	# Mesma ordem de decisão e mesmo resultado de antes, com muito menos trabalho por par.
	var ch := chem(a.id, b.id)
	if ch >= 0.55 and ch <= 0.7:
		return []
	var aa := a.age(world.year)
	var ab := b.age(world.year)
	var fam_a := TransferManager._family_of(a.position)
	var fam_b := TransferManager._family_of(b.position)
	if ch > 0.7:
		# Briga por posição: dois do mesmo setor, nível parecido, idades de quem quer jogar já
		if fam_a == fam_b and absi(a.overall - b.overall) <= 3 and aa >= 22 and ab >= 22 and ch > 0.86:
			if a.trait_sum("ambition") + b.trait_sum("ambition") > 20.0 or HiddenPersona.hot_head(a) or HiddenPersona.hot_head(b):
				return [INIMIGO, -35.0, a, b]
		# Dois esquentados no mesmo vestiário
		if HiddenPersona.hot_head(a) and HiddenPersona.hot_head(b):
			return [INIMIGO, -40.0, a, b]
		return []
	# Revelados juntos: amizade de infância
	if came_up_together(a, b):
		return [AMIGO, 45.0 + ch * 40.0, a, b]
	if ch < 0.35:
		# Compatriotas longe de casa se juntam
		if a.nationality == b.nationality and a.nationality != c.nation:
			return [AMIGO, 30.0 + ch * 30.0, a, b]
		if ch < 0.1 and a.nationality != c.nation and b.nationality != c.nation and Languages.primary(a.nationality) != Languages.primary(b.nationality):
			return [AMIGO, 25.0, a, b]
		# Veterano líder adota o garoto da posição
		if fam_a == fam_b and absi(aa - ab) >= 8 and ch < 0.3:
			var old := a if aa > ab else b
			var kid := b if aa > ab else a
			if old.has_trait("lider") or old.hid("det") >= 14:
				return [MENTOR, 50.0, kid, old]
		# Anos lado a lado
		var ya := years_together(world, a, b)
		if ya >= 3:
			return [AMIGO, 20.0 + ya * 6.0, a, b]
	if initial and ch < 0.04:
		return [AMIGO, 25.0, a, b]
	return []


## Ídolos dos garotos: o craque compatriota da mesma posição (ou a lenda do clube do coração).
static func assign_idols(world: GameWorld) -> void:
	var best := {}
	for p: Player in world.players.values():
		if p.club_id < 0 or p.age(world.year) < 26:
			continue
		var key := "%s|%d" % [p.nationality, TransferManager._family_of(p.position)]
		var arr: Array = best.get(key, [])
		arr.append([p.ovr_f + p.titles * 0.5, p.id])
		best[key] = arr
	for k in best:
		var arr: Array = best[k]
		arr.sort_custom(func(x, y): return x[0] > y[0])
		best[k] = arr.slice(0, 3)
	for p: Player in world.players.values():
		if p.age(world.year) > 21 or p.idol >= 0:
			continue
		var arr: Array = best.get("%s|%d" % [p.nationality, TransferManager._family_of(p.position)], [])
		if arr.is_empty():
			continue
		var pick: Array = arr[hash([p.id, "idolo"]) % arr.size()]
		if int(pick[1]) != p.id:
			p.idol = int(pick[1])


# ---------------------------------------------------------------------------
# Temporada
# ---------------------------------------------------------------------------

## Fim de temporada (antes de zerar os números): laços pelo ano vivido junto, técnicos pelo que
## fizeram com cada um, dupla de ataque que funcionou e ídolos para os novos garotos.
static func season_close(world: GameWorld, champions: Dictionary) -> void:
	for c: Club in world.clubs:
		var squad := world.squad(c)
		var coach := coach_id_of(world, c.id)
		var lvl := PlayerGenerator.club_level(c)
		var won := champions.has(c.id)
		var scorers: Array = []
		for p: Player in squad:
			var apps := p.stats[Player.S_APPS]
			var starts := p.stats[Player.S_STARTS]
			# Técnico: quem escalou sobe; quem deixou no banco um jogador pronto desce.
			if coach != -1:
				var d := 0.0
				if starts >= 20:
					d += 10.0
				elif starts >= 10:
					d += 5.0
				if apps >= 5 and p.age(world.year) <= 19 and p.career_apps <= apps + 2:
					d += 22.0 # deu a primeira chance
				if starts >= 20 and p.joined_year <= world.year - 2 and p.coach_rel.is_empty():
					d += 15.0 # anos de confiança com o técnico atual
				if starts <= 4 and p.ovr_f >= lvl - 2.0 and p.injury_weeks == 0 and p.joined_year < world.year:
					d -= 14.0 if p.trait_sum("ambition") > 10.0 else 9.0
				if won:
					d += 10.0
				if d != 0.0:
					add_coach(p, coach, d)
			if p.stats[Player.S_GOALS] >= 8 and Pos.group(p.position) == Pos.G_ATT:
				scorers.append(p)
		# Dupla de ataque: dois atacantes que marcaram juntos
		if scorers.size() >= 2:
			scorers.sort_custom(func(x: Player, y: Player): return x.stats[Player.S_GOALS] > y.stats[Player.S_GOALS])
			link(world, scorers[0], scorers[1], DUPLA, 18.0)
		# Ano juntos: laços existentes andam; títulos unem; rixas antigas esfriam.
		for i in squad.size():
			var a: Player = squad[i]
			for oid in a.bonds.keys():
				var b: Player = world.players.get(oid)
				if b == null:
					a.bonds.erase(oid)
					continue
				if oid < a.id:
					continue
				var v := float(a.bonds[oid][1])
				if b.club_id == c.id:
					var d2 := (4.0 if v > 0.0 else -2.0) + (8.0 if won else 0.0)
					link(world, a, b, String(a.bonds[oid][0]), d2)
				elif v < 0.0:
					link(world, a, b, INIMIGO, 6.0) # longe, a rixa esfria
		_club_bonds(world, c, false)
	assign_idols(world)


## Depois de cada data: derrota feia esquenta o vestiário (discussão, briga); vitória grande une.
static func after_matchday(world: GameWorld, entries: Array) -> void:
	for e in entries:
		var f: Fixture = e["f"]
		var res: Dictionary = e.get("res", {})
		if not f.played or not res.has("lines"):
			continue
		for side in 2:
			var cid := f.home if side == 0 else f.away
			var club := world.club(cid)
			if club == null:
				continue
			var gf := f.hg if side == 0 else f.ag
			var ga := f.ag if side == 0 else f.hg
			var played: Array = []
			for ln in res["lines"][side]:
				played.append(ln[QuickMatch.L_P])
			if ga - gf >= 3:
				_tension(world, club, played, f)
			elif gf - ga >= 3:
				for i in mini(played.size(), 11):
					for j in range(i + 1, mini(played.size(), 11)):
						var a: Player = played[i]
						var b: Player = played[j]
						if a.bonds.has(b.id) and float(a.bonds[b.id][1]) > 0.0:
							link(world, a, b, String(a.bonds[b.id][0]), 2.0)


## Goleada sofrida: entre quem jogou, desafetos discutem e esquentados podem brigar.
static func _tension(world: GameWorld, club: Club, played: Array, f: Fixture) -> void:
	for i in played.size():
		var a: Player = played[i]
		for j in range(i + 1, played.size()):
			var b: Player = played[j]
			var v := value(a, b.id)
			var hot := HiddenPersona.hot_head(a) or HiddenPersona.hot_head(b)
			var trigger := chem(a.id, b.id, "briga%d_%d" % [world.year, f.slot])
			if v < -30.0 and hot and trigger < 0.2:
				world.stat_add("fights")
				link(world, a, b, INIMIGO, -20.0)
				_incident(world, club, a, b, true)
				return
			if (v < -10.0 and trigger < 0.15) or (hot and v <= 0.0 and trigger < 0.025):
				world.stat_add("arguments")
				link(world, a, b, INIMIGO, -25.0)
				_incident(world, club, a, b, false)
				return


static func _incident(world: GameWorld, club: Club, a: Player, b: Player, fight: bool) -> void:
	a.morale = clampf(a.morale - (8.0 if fight else 4.0), 0.0, 100.0)
	b.morale = clampf(b.morale - (8.0 if fight else 4.0), 0.0, 100.0)
	club.cohesion = maxf(20.0, club.cohesion - (4.0 if fight else 1.5))
	var title := ("%s e %s brigam no vestiário" if fight else "%s e %s discutem depois da goleada") % [a.short_name(), b.short_name()]
	var body := ("Depois da derrota, %s e %s trocaram empurrões no vestiário do %s e precisaram ser separados pelos companheiros." if fight else
		"A goleada deixou o clima pesado: %s cobrou %s em voz alta no vestiário do %s.") % [a.display_name(), b.display_name(), club.short_name]
	if world.is_user_club(club.id):
		NewsManager.post_raw(world, title, body, club.id, a.id, NewsEvent.IMP_HIGH, "clube")
		InboxManager.send(world, "auxiliar", title, body + " Vale conversar com os dois.", {"k": "screen", "s": "dressing_room"}, a.id, club.id)
	elif fight and WorldEvents.newsworthy(world, club):
		NewsManager.post_raw(world, title, body, club.id, a.id, NewsEvent.IMP_NORMAL, "clube")


## Campeões da temporada (ligas e copas): {club_id: true}.
static func champions(world: GameWorld) -> Dictionary:
	var out := {}
	if world.season == null:
		return out
	for lid in world.season.leagues:
		var league: League = world.season.leagues[lid]
		var ids := CompetitionManager.sorted_ids(league)
		if not ids.is_empty():
			out[int(LeagueFormat.champion(league, ids))] = true
	for cid in world.season.cups:
		var cup: Cup = world.season.cups[cid]
		if cup.champion >= 0:
			out[cup.champion] = true
	return out


# ---------------------------------------------------------------------------
# Efeitos
# ---------------------------------------------------------------------------

## Quanto as relações puxam (ou empurram) o jogador para o clube comprador.
static func pull(world: GameWorld, p: Player, buyer: Club) -> float:
	var v := 0.0
	for oid in p.bonds:
		var q: Player = world.players.get(oid)
		if q == null or q.club_id != buyer.id:
			continue
		var b: Array = p.bonds[oid]
		match String(b[0]):
			IRMAO:
				v += 0.22
			INIMIGO:
				v -= 0.1 + absf(float(b[1])) / 600.0
			_:
				v += clampf(float(b[1]) / 600.0, 0.0, 0.12)
	var coach := coach_id_of(world, buyer.id)
	if coach != -1:
		var cv := coach_value(p, coach)
		if cv >= 30.0:
			v += 0.12 # quer trabalhar de novo com o técnico favorito
		elif cv <= -25.0:
			v -= 0.18 # não volta para quem o deixou no banco
	if p.idol >= 0:
		var idol: Player = world.players.get(p.idol)
		if idol != null and idol.club_id == buyer.id:
			v += 0.06 # jogar ao lado do ídolo
	return clampf(v, -0.35, 0.35)


## O técnico que acabou de chegar confia nesses jogadores (para o mercado da IA): bônus de alvo.
static func trust_bonus(p: Player, coach_id: int) -> float:
	if coach_id == -1:
		return 0.0
	var cv := coach_value(p, coach_id)
	return 2.5 if cv >= 30.0 else (-2.0 if cv <= -25.0 else 0.0)


## Transferência concluída: quem fica e quem chega reagem; reencontros viram notícia.
static func on_transfer(world: GameWorld, p: Player, seller: Club, buyer: Club) -> void:
	for oid in p.bonds:
		var q: Player = world.players.get(oid)
		if q == null:
			continue
		var b: Array = p.bonds[oid]
		var v := float(b[1])
		if q.club_id == buyer.id:
			q.morale = clampf(q.morale + (6.0 if v > 15.0 else (-6.0 if v < -15.0 else 0.0)), 0.0, 100.0)
			p.morale = clampf(p.morale + (4.0 if v > 15.0 else (-4.0 if v < -15.0 else 0.0)), 0.0, 100.0)
			if world.is_user_club(buyer.id) and (String(b[0]) == IRMAO or v >= 40.0):
				NewsManager.post_raw(world, ("Os irmãos %s e %s juntos no %s" if String(b[0]) == IRMAO else "%s reencontra o amigo %s no %s") % [p.short_name(), q.short_name(), buyer.short_name],
					"%s e %s voltam a dividir o vestiário. A amizade ajuda na adaptação." % [p.display_name(), q.display_name()], buyer.id, p.id, NewsEvent.IMP_NORMAL, "clube")
		elif seller != null and q.club_id == seller.id and v > 30.0:
			q.morale = clampf(q.morale - (8.0 if String(b[0]) == IRMAO else 4.0), 0.0, 100.0)


## Entrosamento: amigos no mesmo time titular jogam melhor juntos; inimigos, pior. Retorna o ajuste
## (pontos de coesão por semana).
static func cohesion_push(world: GameWorld, club: Club) -> float:
	if club.sheet == null:
		return 0.0
	var s := 0.0
	var xi: Array = club.sheet.starters
	for i in xi.size():
		var a: Player = world.players.get(int(xi[i]))
		if a == null:
			continue
		for j in range(i + 1, xi.size()):
			var v := value(a, int(xi[j]))
			if v != 0.0:
				s += v / 100.0
	return clampf(s * 0.15, -1.0, 0.8)


# ---------------------------------------------------------------------------
# Lendas dos clubes
# ---------------------------------------------------------------------------

## Lendas do clube: [{n, pid, why, v}] — maior artilheiro, recordista de jogos, mais títulos e os
## ídolos (muitos jogos e gols). Conta os ativos (passagens) e os aposentados notáveis.
static func legends(world: GameWorld, c: Club) -> Array:
	var rows: Array = []
	for p: Player in world.players.values():
		var a := 0
		var g := 0
		for s: Dictionary in p.spells:
			if int(s.get("c", -1)) == c.id:
				a += int(s.get("a", 0))
				g += int(s.get("g", 0))
		if a >= 30:
			rows.append({"n": p.display_name(), "pid": p.id, "a": a, "g": g, "t": p.titles, "active": true})
	for r: Dictionary in world.retired:
		var a2 := 0
		var g2 := 0
		for s: Dictionary in r.get("spells", []):
			if int(s.get("c", -1)) == c.id:
				a2 += int(s.get("a", 0))
				g2 += int(s.get("g", 0))
		if a2 >= 30:
			rows.append({"n": String(r.get("ka", r.get("name", ""))), "pid": int(r.get("id", -1)), "a": a2, "g": g2, "t": int(r.get("titles", 0)), "active": false})
	if rows.is_empty():
		return []
	var out: Array = []
	rows.sort_custom(func(x, y): return int(x["g"]) > int(y["g"]))
	out.append({"why": "Maior artilheiro", "r": rows[0], "txt": Fmt.n_of(int(rows[0]["g"]), "%d gol", "%d gols")})
	rows.sort_custom(func(x, y): return int(x["a"]) > int(y["a"]))
	out.append({"why": "Recordista de jogos", "r": rows[0], "txt": Fmt.n_of(int(rows[0]["a"]), "%d jogo", "%d jogos")})
	# Ídolos: muitos jogos e gols juntos (quem marcou época)
	rows.sort_custom(func(x, y): return int(x["a"]) + int(x["g"]) * 2 + int(x["t"]) * 15 > int(y["a"]) + int(y["g"]) * 2 + int(y["t"]) * 15)
	var named := {}
	for e in out:
		named[int(e["r"]["pid"])] = true
	for r3: Dictionary in rows:
		if out.size() >= 6:
			break
		if named.has(int(r3["pid"])):
			continue
		named[int(r3["pid"])] = true
		out.append({"why": "Ídolo", "r": r3, "txt": "%s, %s" % [Fmt.n_of(int(r3["a"]), "%d jogo", "%d jogos"), Fmt.n_of(int(r3["g"]), "%d gol", "%d gols")]})
	return out
