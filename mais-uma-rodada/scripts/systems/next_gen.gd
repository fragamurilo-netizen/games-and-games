class_name NextGen
extends RefCounted
## Listas anuais de joias, como as da imprensa de verdade:
##   Next Generation (do jornal inglês "The Albion Post", como a lista do Guardian): os 60 melhores
##     talentos que fazem 17 anos no ano, um por clube, sem ordem — publicada no começo da temporada.
##   NXGN (do portal "Golaço"): ranking dos 50 melhores jogadores sub-21 do mundo, com o eleito no
##     topo — publicada na segunda metade da temporada.
## Os olheiros da imprensa acertam e erram: a lista pesa o potencial real com ruído, o nível de hoje,
## os minutos na temporada e o tamanho da vitrine (clube grande aparece mais). Fica no currículo.
## Estado: world.stats["nextgen"] = {"<ano>": {"ng": [ids], "nx": [ids]}}.

const NG_SLOT := 8
const NX_SLOT := 34
const NG_SIZE := 60
const NX_SIZE := 50


static func after_matchday(world: GameWorld, slot: int) -> void:
	var all: Dictionary = world.stats.get("nextgen", {})
	var y := str(world.year)
	var cur: Dictionary = all.get(y, {})
	if slot >= NG_SLOT and not cur.has("ng"):
		cur["ng"] = _next_generation(world)
		all[y] = cur
		world.stats["nextgen"] = all
		_announce_ng(world, cur["ng"])
	if slot >= NX_SLOT and not cur.has("nx"):
		cur["nx"] = _nxgn(world)
		all[y] = cur
		world.stats["nextgen"] = all
		_announce_nx(world, cur["nx"])
	# Guarda só os últimos 12 anos
	if all.size() > 12:
		var ks := all.keys()
		ks.sort()
		all.erase(ks[0])


static func lists(world: GameWorld) -> Dictionary:
	return world.stats.get("nextgen", {})


## Nota da imprensa para um jovem: o olho erra (ruído estável por jogador e por ano).
static func _press_score(world: GameWorld, p: Player, salt: String) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash([p.id, world.year, salt])
	var noise := r.randf_range(-4.0, 4.0)
	var club := world.club(p.club_id)
	var shop := (club.reputation - 50.0) * 0.06 if club != null else -2.0
	var mins := minf(float(p.minutes_season) / 900.0, 3.0)
	return float(p.potential) * 0.62 + float(p.overall) * 0.38 + noise + shop + mins


static func _next_generation(world: GameWorld) -> Array:
	var born := world.year - 17
	var cands: Array = []
	for p: Player in world.players.values():
		if p.birth_year == born and p.club_id >= 0:
			cands.append([p, _press_score(world, p, "ng")])
	cands.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var out: Array = []
	var clubs := {}
	for c in cands:
		var p: Player = c[0]
		if clubs.has(p.club_id):
			continue # um por clube, como na lista original
		clubs[p.club_id] = true
		out.append(p.id)
		p.awards.append({"y": world.year, "k": "nextgen"})
		if out.size() >= NG_SIZE:
			break
	return out


static func _nxgn(world: GameWorld) -> Array:
	var cands: Array = []
	for p: Player in world.players.values():
		var age := p.age(world.year)
		if age <= 20 and age >= 16 and p.club_id >= 0:
			# NXGN é ranking de quem já joga: o nível atual pesa mais que na lista dos 17 anos
			var s := _press_score(world, p, "nx") + float(p.overall) * 0.35 + minf(float(p.minutes_season) / 450.0, 4.0)
			cands.append([p, s])
	cands.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var out: Array = []
	for i in mini(NX_SIZE, cands.size()):
		var p: Player = cands[i][0]
		out.append(p.id)
		p.awards.append({"y": world.year, "k": "nxgn_win" if i == 0 else "nxgn", "r": i + 1})
	return out


static func _announce_ng(world: GameWorld, ids: Array) -> void:
	var ours: Array = []
	for pid in ids:
		var p := world.player(int(pid))
		if p != null and world.has_user() and p.club_id == world.user_club_id:
			ours.append(p.display_name())
			p.morale = clampf(p.morale + 4.0, 0.0, 100.0)
	var body := "O Albion Post revelou a lista Next Generation %d: os %d melhores talentos nascidos em %d, um por clube." % [world.year, ids.size(), world.year - 17]
	if not ours.is_empty():
		body += " Do %s: %s." % [world.user_club().short_name, ", ".join(ours)]
	NewsManager.post_raw(world, "Next Generation %d: as joias de %d" % [world.year, world.year - 17], body, world.user_club_id if not ours.is_empty() else -1, -1,
		NewsEvent.IMP_HIGH if not ours.is_empty() else NewsEvent.IMP_NORMAL, "premio")


static func _announce_nx(world: GameWorld, ids: Array) -> void:
	if ids.is_empty():
		return
	var top := world.player(int(ids[0]))
	if top == null:
		return
	var tc := world.club(top.club_id)
	var ours := 0
	for pid in ids:
		var p := world.player(int(pid))
		if p != null and world.has_user() and p.club_id == world.user_club_id:
			ours += 1
			p.morale = clampf(p.morale + 5.0, 0.0, 100.0)
	var body := "%s, %d anos, do %s, lidera o NXGN %d, o ranking dos %d melhores jogadores sub-21 do mundo feito pelo portal Golaço." % [
		top.display_name(), top.age(world.year), tc.short_name if tc != null else "?", world.year, ids.size()]
	if ours > 0:
		body += " O %s tem %d nome(s) na lista." % [world.user_club().short_name, ours]
	NewsManager.post_raw(world, "NXGN %d: %s é o melhor jovem do mundo" % [world.year, top.display_name()], body, top.club_id, top.id,
		NewsEvent.IMP_HIGH if ours > 0 or world.is_user_club(top.club_id) else NewsEvent.IMP_NORMAL, "premio")
